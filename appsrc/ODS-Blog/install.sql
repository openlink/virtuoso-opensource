--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2012 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--

--
-- select top %d, %d  B_CONTENT, B_TS, B_POST_ID, B_COMMENTS_NO as comments, B_TRACKBACK_NO as trackbacks, B_USER_ID, B_META, B_MODIFIED, B_STATE from SYS_BLOGS, (select BI_BLOG_ID as BA_C_BLOG_ID, BI_BLOG_ID as BA_M_BLOG_ID from SYS_BLOG_INFO where BI_BLOG_ID = ''%s'' union all select * from (select top 10 BA_C_BLOG_ID, BA_M_BLOG_ID from SYS_BLOG_ATTACHES where BA_M_BLOG_ID = ''%s'' order by BA_LAST_UPDATE desc) name1) name2 where B_BLOG_ID = BA_C_BLOG_ID order by B_TS desc;

--set MACRO_SUBSTITUTION off;
--set IGNORE_PARAMS on;

USE "BLOG"
;

create procedure
WEBLOG_DAV_MOVE (in path varchar,
                  in destination varchar,
                  in overwrite integer)
{
  declare pwd1 any;
  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = 'dav');
  return DB.DBA.DAV_MOVE(path, destination, overwrite, 'dav', pwd1);
}
;

create procedure
WEBLOG_DAV_COPY (in path varchar,
                  in destination varchar,
                  in uid2 varchar,
                  in overwrite integer,
		  in file_list any := null)
{
  declare pwd1 any;
  declare _res_id, u_id2 int;
  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = 'dav');
  DB.DBA.DAV_COL_CREATE(left(destination, strrchr(rtrim(destination, '/'), '/') + 1), '111100100N', uid2, null, 'dav', pwd1);

  if (file_list is null)
    {
      _res_id := DB.DBA.DAV_COPY(path, destination, overwrite, '110100100N', uid2, null, 'dav', pwd1);
    }
  else
    {
      declare copy_list any;
      DB.DBA.DAV_DELETE (destination, 1, 'dav', pwd1);
      DB.DBA.DAV_COL_CREATE(destination, '111100100N', uid2, null, 'dav', pwd1);
      copy_list := DB.DBA.DAV_DIR_LIST (path, 0, 'dav', pwd1);
      foreach (any entry in copy_list) do
	{
	  declare dest_file any;
	  dest_file := entry[10];
	  if (regexp_match (file_list, dest_file) is not null)
	    {
	      --dbg_obj_print ('path||dest_file', path||dest_file, ' to ', destination||dest_file);
	      _res_id := DB.DBA.DAV_COPY(path||dest_file, destination||dest_file,
	      		overwrite, '110100100N', uid2, null, 'dav', pwd1);
              if (_res_id < 0)
                signal ('42000', 'Internal error: Cannot copy WebDAV resource : ' || dest_file);
	      --dbg_obj_print (_res_id);
	    }
	}
    }

  u_id2 := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uid2);

  if (_res_id > 0)
  {
    declare cur_type, cur_perms varchar;
    declare res_cur cursor for
      select RES_PERMS, RES_TYPE
        from WS.WS.SYS_DAV_RES
        where substring (RES_FULL_PATH, 1, length (destination)) = destination;
    whenever not found goto next_one;
    open res_cur (prefetch 1, exclusive);
    while (1)
    {
      fetch res_cur into cur_type, cur_perms;
      update WS.WS.SYS_DAV_RES set RES_OWNER = u_id2, RES_GROUP = null where current of res_cur;
      if (cur_perms <> '110100100N')
        update WS.WS.SYS_DAV_RES set RES_PERMS = '110100100N' where current of res_cur;
      commit work;
    }
    next_one:
    close res_cur;
  }
  return _res_id;
}
;

create procedure
WEBLOG_DAV_PROP_SET(in path varchar,
                  in propname varchar,
                  in propvalue any)
{
  declare pwd1 any;
  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = 'dav');
  DB.DBA.DAV_PROP_REMOVE(path, propname, 'dav', pwd1);
  return DB.DBA.DAV_PROP_SET(path, propname, propvalue, 'dav', pwd1);
}
;


-- 0 - Preview (visible one time only in POST preview mode)
-- 1 - Draft (visible for author only 'with remarks - < not published >')
-- 2 - Published (visible for all)

create procedure SYS_BLOGS_B_STATE_UPDATE ()
{
  if (registry_get ('__SYS_BLOGS_B_STATE_UPDATE') = 'done')
    return;
  update BLOG.DBA.SYS_BLOGS set B_STATE = 2 where B_STATE is null;
  update BLOG.DBA.SYS_BLOG_INFO set BI_INCLUSION = 1;
  registry_set ('__SYS_BLOGS_B_STATE_UPDATE', 'done');
};

SYS_BLOGS_B_STATE_UPDATE ()
;

log_enable (1)
;

create procedure BLOG_PODCAST_UPGRADE ()
{
  if (registry_get ('__BLOG_PODCAST_UPGRADE1') = 'done')
    return;
  declare meta "MWeblogPost";
  declare enc BLOG.DBA."MWeblogEnclosure";
  for select B_POST_ID id, B_BLOG_ID bid, B_META mt from SYS_BLOGS do
    {
      meta := mt;
      if (mt is not null and meta.enclosure is not null)
	{
	  enc := meta.enclosure;
	  set triggers off;
	  if (udt_instance_of (meta.enclosure, 'BLOG.DBA.MWeblogEnclosure'))
	    update SYS_BLOGS set B_HAVE_ENCLOSURE = 1, B_ENCLOSURE_TYPE = enc."type" where B_BLOG_ID = bid and B_POST_ID = id;
	  else if (udt_instance_of (meta.enclosure, 'DB.DBA.MWeblogEnclosure'))
	    {
	      enc := new BLOG.DBA."MWeblogEnclosure" ();
	      enc."url" := udt_get (meta.enclosure, 'url');
	      enc."type" := udt_get (meta.enclosure, 'type');
	      enc."length" := udt_get (meta.enclosure, 'length');
	      meta.enclosure := enc;
	      update SYS_BLOGS set B_HAVE_ENCLOSURE = 1, B_ENCLOSURE_TYPE = enc."type", B_META = meta
	      where B_BLOG_ID = bid and B_POST_ID = id;
	}
	  set triggers on;
    }
    }
  registry_set ('__BLOG_PODCAST_UPGRADE1', 'done');
};


BLOG_PODCAST_UPGRADE ();

--blog2_exec_no_error ('create index "BI_WAI_NAME_INX" on BLOG..SYS_BLOG_INFO ("BI_WAI_NAME")')
--;

create procedure BLOG2_RSSSEARCH_XML_SQLX()
{
  declare ses any;
  ses := string_output();
  http('<?xml version =\'1.0\' encoding=\'UTF-8\'?>\n', ses);
  http('<rss version="2.0">\n', ses);
  http('<channel xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'>\n', ses);
  http('<sql:header><sql:param name=":n"> </sql:param><sql:param name=":s"> </sql:param><sql:param name=":bi"> </sql:param></sql:header>\n', ses);
  http('<sql:sqlx><![CDATA[\n', ses);
  http('select \n', ses);
  http('XMLELEMENT(\'title\', \'Search in \' || BI_TITLE), \n', ses);
  http('XMLELEMENT(\'link\', \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()||BI_HOME), \n', ses);
  http('XMLELEMENT(\'description\', BI_ABOUT), \n', ses);
  http('XMLELEMENT(\'managingEditor\', BI_E_MAIL), \n', ses);
  http('XMLELEMENT(\'pubDate\', BLOG.DBA.date_rfc1123(now())), \n', ses);
  http('XMLELEMENT(\'generator\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', ses);
  http('XMLELEMENT(\'webMaster\', BI_E_MAIL), \n', ses);
  http('XMLELEMENT(\'image\', \n', ses);
  http('XMLELEMENT(\'title\', BI_TITLE), \n', ses);
  http('XMLELEMENT(\'url\', \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || \'/weblog/public/images/vbloglogo.gif\'), \n', ses);
  http('XMLELEMENT(\'link\', \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)), \n', ses);
  http('XMLELEMENT(\'description\', BI_ABOUT), \n', ses);
  http('XMLELEMENT(\'width\', \'88\'), \n', ses);
  http('XMLELEMENT(\'height\', \'31\')) \n', ses);
  http('from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = :bi\n', ses);
  http(']]></sql:sqlx>\n', ses);
  http('<sql:sqlx><![CDATA[\n', ses);
  http('select \n', ses);
  http('XMLAGG(XMLELEMENT(\'item\',\n', ses);
  http('XMLELEMENT(\'title\', BLOG.DBA.BLOG2_GET_TITLE(B_META, B_CONTENT)),\n', ses);
  http('XMLELEMENT(\'guid\', \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()||BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'||B_POST_ID),\n', ses);
  http('XMLELEMENT(\'comments\', \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()||BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'||B_POST_ID||\'#comments\'),\n', ses);
  http('XMLELEMENT(\'pubDate\', BLOG.DBA.date_rfc1123 (B_TS)),\n', ses);
  http('XMLELEMENT(\'description\', B_CONTENT)))\n', ses);
  http('from\n', ses);
  http('(select TOP (cast (:n as integer)) B_CONTENT, B_TS, B_META, BI_HOME, B_POST_ID from\n', ses);
  http('BLOG..SYS_BLOGS, BLOG..SYS_BLOG_INFO where B_STATE = 2 and B_BLOG_ID = :bi and BI_BLOG_ID = B_BLOG_ID\n', ses);
  http('and contains (B_CONTENT,  FTI_MAKE_SEARCH_STRING (:s)) order by B_TS desc\n', ses);
  http(') sub\n', ses);
  http(']]>\n', ses);
  http('</sql:sqlx>\n', ses);
  http('</channel>\n', ses);
  http('</rss>\n', ses);
  ses := string_output_string (ses);
  return ses;
}
;

create procedure BLOG2_RSSSEARCH_XML() {
  declare str any;
  str :=
    '<?xml version =\'1.0\' encoding=\'UTF-8\'?>\n
    <rss version="2.0" xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'>\n
    <sql:header><sql:param name=":n"> </sql:param></sql:header>\n
    <sql:header><sql:param name=":s"> </sql:param></sql:header>\n
    <sql:header><sql:param name=":bi"> </sql:param></sql:header>\n
    <sql:query>\n
    select\n
      1 as tag,\n
      null as parent,\n
      concat (\'Search in \', BI_TITLE) as [channel!1!title!element],\n
      \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()||BI_HOME as [channel!1!link!element],\n
      BI_ABOUT as [channel!1!description!element],\n
      BI_E_MAIL as [channel!1!managingEditor!element],\n
      BLOG.DBA.date_rfc1123(now ()) as [channel!1!pubDate!element],\n
      \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\') as [channel!1!generator!element],\n
      BI_E_MAIL as [channel!1!webMaster!element],\n
      null as [image!2!title!element],\n
      null as [image!2!url!element],\n
      null as [image!2!link!element],\n
      null as [image!2!description!element],\n
      null as [image!2!width!element],\n
      null as [image!2!height!element],\n
      null as [item!3!description!element],\n
      null as [item!3!pubDate!element],\n
      null as [item!3!title!element],\n
      null as [item!3!guid!element],\n
      null as [item!3!comments!element],\n
      null as [item!3!ts!hide]\n
      from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = :bi\n
          \n
    union all\n
    select\n
      2,\n
      1,\n
      null,\n
      null,\n
      null,\n
      null,\n
      null,\n
      null,\n
      null,\n
      BI_TITLE,\n
      \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || \'/weblog/public/images/vbloglogo.gif\',\n
      \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || BLOG.DBA.BLOG2_GET_HOME_DIR(BI_HOME),\n
      BI_ABOUT,\n
      88,\n
      31,\n
      null,\n
      null,\n
      null,\n
      null,\n
      null,\n
      null\n
      from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = :bi \n
          union all\n
    select\n
      3,\n
      1,\n
      null,\n
      null,\n
      null,\n
      null,\n
      null,\n
      null,\n
      null,\n
      null,\n
      null,\n
      null,\n
      null,\n
      null,\n
      null,\n
      B_CONTENT,\n
      BLOG.DBA.date_rfc1123 (B_TS),\n
      BLOG.DBA.BLOG2_GET_TITLE (B_META, B_CONTENT),\n
      \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()|| BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'||B_POST_ID,\n
      \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()|| BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'||B_POST_ID||\'#comments\',\n
      B_TS\n
      from\n
      (select TOP (cast (:n as integer)) B_CONTENT, B_TS, B_META, BI_HOME, B_POST_ID from\n
      BLOG..SYS_BLOGS, BLOG..SYS_BLOG_INFO where B_STATE = 2 and B_BLOG_ID = :bi and BI_BLOG_ID = B_BLOG_ID\n
      and contains (B_CONTENT,  FTI_MAKE_SEARCH_STRING (:s))\n
      order by B_TS desc\n
      ) sub\n
          \n
    for xml explicit\n
      </sql:query>\n
  </rss>\n';
  return str;
}
;


USE "DB"
;

create procedure
BLOG2_MAIN_PAGE_DATA (inout e vspx_event, inout dss vspx_data_source, in  _fordate date, in _blogid varchar,
          in have_comunity_blog integer, in user_tz int, in fordate_n int, in ord varchar := 'desc',
          in is_link int := 0, in search_str varchar := null, in cat varchar := null,
	  in tag varchar := null, in arch varchar := null)
{
  if (arch is null)
    arch := '';
  if (fordate_n = 0 or fordate_n = -1)
  {
    arch := '';
  }
  declare meta, data any;
  declare col vspx_column;
  declare sql, sql1, sql2, sqlc, pars, time_cond, pred1, cont_col, search, cat_pred, cat_tbl, tzo any;
  declare d1, d2 timestamp;

  --dbg_obj_print ('calling BLOG2_MAIN_PAGE_DATA', _fordate, fordate_n);
  d1 := stringdate (sprintf ('%i-%i-%i', year (_fordate), month (_fordate), dayofmonth (_fordate)));
  if (fordate_n = -1)
    d2 := dateadd('month', 1, d1);
  else
    d2 := dateadd('day', 1, d1);

  tzo := timezone (now());

  --d1 := dateadd ('minute', tzo, d1);
  --d1 := dt_set_tz (d1, 0);

  --d2 := dateadd ('minute', tzo, d2);
  --d2 := dt_set_tz (d2, 0);


  pars := vector ();
  time_cond := '';
  if (fordate_n = 0 or fordate_n = -1)
  {
    time_cond := ' and B_TS >= ? and B_TS < ? ';
    pars := vector (d1, d2);
  }
  pred1 := '';
  cont_col := 'B_CONTENT';

  search := '';
  if (length (search_str) and is_link)
    {
      search := replace (search_str, '\'', '&apos;');
      search := replace (search, '"', '&quot;');
      search := sprintf (' and contains (., "%s")', search);
    }
  else if (length (search_str) and not is_link)
    {
      pars := vector_concat (pars, vector (FTI_MAKE_SEARCH_STRING (search_str)));
      pred1 := 'and contains (B_CONTENT, ?)';
    }

--  select ... from BLOG.DBA.SYS_BLOGS, BLOG.DBA.MTYPE_BLOG_CATEGORY
--  where B_STATE = 2 and B_BLOG_ID = ?
--  and MTB_BLOG_ID = B_BLOG_ID and MTB_POST_ID = B_POST_ID and MTB_CID = ?
--  order by B_TS ...

  if (is_link)
  {
    cont_col := ' serialize_to_UTF8_xml (CONTENT) as CONTENT ';
    pred1 := sprintf ('and xpath_contains (B_CONTENT, \'[__quiet BuildStandalone=ENABLE] //a[starts-with (@href,"http") and not(img) %s]\', CONTENT)' , search);
  }

  cat_pred := '';
  cat_tbl := '';

  if (length (cat) and regexp_match ('^[0-9]+\$', cat) is not null)
    {
      cat_tbl := ', BLOG.DBA.MTYPE_BLOG_CATEGORY ';
      cat_pred := sprintf (' and MTB_BLOG_ID = B_BLOG_ID and MTB_POST_ID = B_POST_ID and MTB_CID = %s ', cast (cat as varchar));
    }
  else if (length (tag))
    {
      declare blog_cond any;

      tag := replace (tag, ' ', '_');
      tag := '"' || tag || '"';

      if (have_comunity_blog is null or have_comunity_blog = 0)
        blog_cond := 'and b'||replace(_blogid, '-', '_');
      else
	blog_cond := '';

      cat_tbl := ', BLOG..BLOG_TAG ';
      cat_pred := sprintf (' and contains (BT_TAGS, ''[__lang "x-ViDoc"] %s %s'', offband, BT_POST_ID) and BT_POST_ID = B_POST_ID ', tag, blog_cond);
    }

    sql1 := sprintf ('select top %d, %d ', dss.ds_rows_offs, dss.ds_nrows);

    if (have_comunity_blog is NULL or have_comunity_blog = 0)
      {
        sql2 := sprintf (' %s, B_TS, B_POST_ID, B_COMMENTS_NO as comments, B_TRACKBACK_NO as trackbacks, B_USER_ID, B_META, B_MODIFIED, B_STATE, B_TITLE, B_BLOG_ID, B_IS_ACTIVE from BLOG..SYS_BLOGS as item %s where B_BLOG_ID = ''%s'' %s %s %s %s order by B_TS %s',
        cont_col, cat_tbl, _blogid, time_cond, cat_pred, pred1, arch, ord);
      }
    else
      {
        sql2 := sprintf (' %s, B_TS, B_POST_ID, B_COMMENTS_NO as comments, B_TRACKBACK_NO as trackbacks, B_USER_ID, B_META, B_MODIFIED, B_STATE, B_TITLE, B_BLOG_ID, B_IS_ACTIVE from BLOG..SYS_BLOGS, (select BI_BLOG_ID as BA_C_BLOG_ID, BI_BLOG_ID as BA_M_BLOG_ID from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = ''%s'' union all select * from (select BA_C_BLOG_ID, BA_M_BLOG_ID from BLOG.DBA.SYS_BLOG_ATTACHES where BA_M_BLOG_ID = ''%s'' order by BA_LAST_UPDATE desc) name1) name2 %s where B_BLOG_ID = BA_C_BLOG_ID %s %s %s %s order by B_TS %s',
        cont_col, _blogid, _blogid, cat_tbl, time_cond, cat_pred, pred1, arch, ord);
      }

  sql := sql1 || sql2;
  sqlc := sprintf ('select count(*) from (select top %d', ((dss.ds_rows_offs/dss.ds_nrows) * 10) + 100) || sql2 ||') name3';

  -- OLD need for tests for now.
  --     sql := sprintf (' select  top %d, %d B_CONTENT, B_TS, B_POST_ID, B_COMMENTS_NO as comments, B_TRACKBACK_NO as trackbacks, B_USER_ID, B_META, B_MODIFIED, B_STATE from SYS_BLOGS as item where (B_BLOG_ID = ''%s'' or B_BLOG_ID in (select BA_C_BLOG_ID from SYS_BLOG_ATTACHES where BA_M_BLOG_ID = 5 and ((select WAI_IS_PUBLIC from WA_INSTANCE where (BA_C_BLOG_ID) > 0)))) and year(B_TS) = %i and month(B_TS) = %i and dayofmonth (B_TS) = %i order by B_TS desc ',dss.ds_rows_offs, dss.ds_nrows, _blogid, year (_fordate), month (_fordate), dayofmonth(_fordate));
  --dbg_obj_print (sql);
  exec (sql, null, null, pars, 0, meta, data);
  for (declare xx any, xx := 0; xx < length (dss.ds_columns) ; xx := xx + 1)
  {
    col :=  dss.ds_columns[xx];
    col.ufl_col_offs := xx;
  }
  dss.ds_rows_fetched := length (data);
  dss.ds_row_data := data;
  dss.ds_row_meta := meta;
--  if (not dss.ds_total_rows)
    {
      exec (sqlc, null, null, pars, 0, meta, data);
      if (isarray(data) and length (data))
        dss.ds_total_rows := data[0][0];
    }
}
;

USE "BLOG"
;

create procedure BLOG2_GET_PPATH_URL (in f any)
{
  return concat (
      'virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:',
       registry_get('_blog2_path_'), f);
}
;


create procedure BLOG2_RSS2WML_PP () 
{
  declare accept, upar, pars any;
  declare lines any;
  declare bid, rss, modif, match, stag, ohdr varchar;
  declare xt, xp, ss, psh any;
  declare xsl any;

  set isolation='committed';
  lines := http_request_header ();
  accept := http_request_header (lines, 'Accept');
  if (not isstring (accept)) 
    accept := '';
  upar := http_request_get ('QUERY_STRING');
  if (regexp_match ('text/vnd\.wap\.wml', accept) is not null) 
    {
      if (http_path () like '%/rss.xml') 
	{
	  declare opts, filt any;
      whenever not found goto exitp;
	  select top 1 BI_BLOG_ID into bid from BLOG..SYS_BLOG_INFO where http_path () like BI_HOME || '%' order by length(BI_HOME) desc;
	  select deserialize (blob_to_string (BI_OPTIONS)) into opts from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = bid;

      if (not isarray(opts)) opts := vector ();
      filt := get_keyword ('RSSFilter', opts, '');
	  if (filt = '*wml-default*') 
	    filt := BLOG2_GET_PPATH_URL ('widgets/rss2wml.xsl');
	  if (not isstring (filt) or not xslt_is_sheet (filt)) 
	    goto exitp;
	  if (length(upar) = 0) 
	    {
        http_xslt (filt);
      }
	  else 
	    {
        rss := http_get_string_output ();
        xt := xml_tree_doc (rss);
        http_rewrite ();
        xsl := xslt (filt, xt, vector ('id', upar));
        http_value (xsl, null);
      }
      set http_charset='utf-8';
      http_header ('Content-Type: text/vnd.wap.wml\r\n');
      exitp:;
    }
  }
  else if (http_path () like '%/rss%.xml' or http_path () like '%/atom%.xml') 
    {
    -- Get the body and calculate md5 over the 1-st item
    rss := http_get_string_output ();
    xt := xml_tree_doc (rss);
    xp := xpath_eval ('//item[1]', xt);
      if (xp is null)
        xp := xpath_eval ('//entry[1]', xt);	
    ss := string_output ();
    http_value (xp, null, ss);
    stag := md5(ss);

    -- prepare standard header
    ohdr := http_header_get ();
      --psh := (select WS_FEEDS_HUB from DB.DBA.WA_SETTINGS);
      declare links varchar;
      links := '';
      for select SH_URL from ODS.DBA.SVC_HOST, ODS.DBA.APP_PING_REG, DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER 
	where SH_PROTO = 'PubSubHub' and SH_ID = AP_HOST_ID and AP_WAI_ID = WAI_ID 
	    and WAI_NAME = WAM_INST and http_path () like WAM_HOME_PAGE || '%' do
	{ 
	  psh := SH_URL;
      if (length (psh))
	{
	      links := links || sprintf (' <%s>; rel="hub"; title="PubSubHub",\r\n', psh);
	    }
	}
      links := rtrim (links, ',\r\n');
      if (links <> '')
	{
	  http_header (ohdr || sprintf ('Link:%s\r\n', links));
	  ohdr := http_header_get ();
	}
    if (strcasestr (ohdr, 'Content-Type:') is not null)
      {
	http_header (ohdr || sprintf ('ETag: %s\r\nLast-Modified: %s\r\n',
                          stag, BLOG.DBA.date_rfc1123 (now ())));
      }
    else
      {
	http_header (sprintf ('Content-Type: text/xml\r\nETag: %s\r\nLast-Modified: %s\r\n',
                          stag, BLOG.DBA.date_rfc1123 (now ())));
      }
      match := http_request_header (lines, 'If-None-Match', null, null);
      modif := http_request_header (lines, 'If-Modified-Since', null, null);

    -- if Etag is same; do nothing
      if (match = stag) 
	{
	  http_xslt (null);
      http_request_status ('HTTP/1.1 304 Not Modified');
      http_rewrite ();
    }
      else if (match is null and isstring (modif)) 
	{
      declare modifd datetime;
      modifd := http_string_date (modif);
      whenever not found goto exitp1;
	  select top 1 BI_BLOG_ID into bid from BLOG..SYS_BLOG_INFO where http_path () like BI_HOME || '%' order by length (BI_HOME) desc;
      -- if no newest items; do nothing
	  if (not exists (select 1 from BLOG..SYS_BLOGS where B_STATE = 2 and B_BLOG_ID = bid and B_MODIFIED > modifd)) 
	    {
	      http_xslt (null);
        http_request_status ('HTTP/1.1 304 Not Modified');
        http_rewrite ();
      }
      exitp1:;
    }
  }
  return;
}
;

create procedure BLOG2_HOME_GENERATE_RSS_CAT_XML_SQLX(in blogid varchar)
{
  declare ses any;
  ses := string_output();
  http('<?xml version =\'1.0\' encoding=\'UTF-8\'?>\n', ses);
  http('<rss version="2.0">\n', ses);
  http('<channel xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'>\n', ses);
  http('<sql:header><sql:param name=":bid"> </sql:param><sql:param name=":cid"> </sql:param></sql:header>\n', ses);
  http('<sql:sqlx><![CDATA[\n', ses);
  http('select \n', ses);
  http('XMLELEMENT(\'title\', BLOG..blog_utf2wide (BI_TITLE)), \n', ses);
  http('XMLELEMENT(\'link\', \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()||BI_HOME), \n', ses);
  http('XMLELEMENT(\'description\', BLOG..blog_utf2wide (BI_ABOUT)), \n', ses);
  http('XMLELEMENT(\'managingEditor\', BI_E_MAIL), \n', ses);
  http('XMLELEMENT(\'pubDate\', BLOG.DBA.date_rfc1123(now())), \n', ses);
  http('XMLELEMENT(\'generator\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', ses);
  http('XMLELEMENT(\'webMaster\', BI_E_MAIL), \n', ses);
  http('XMLELEMENT(\'image\', \n', ses);
  http('XMLELEMENT(\'title\', BLOG..blog_utf2wide (BI_TITLE)), \n', ses);
  http('XMLELEMENT(\'url\', \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || \'/weblog/public/images/vbloglogo.gif\'), \n', ses);
  http('XMLELEMENT(\'link\', \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)), \n', ses);
  http('XMLELEMENT(\'description\', BLOG..blog_utf2wide (BI_ABOUT)), \n', ses);
  http('XMLELEMENT(\'width\', \'88\'), \n', ses);
  http('XMLELEMENT(\'height\', \'31\')) \n', ses);
  http('from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = :bid\n', ses);
  http(']]></sql:sqlx>\n', ses);
  http('<sql:sqlx><![CDATA[\n', ses);
  http('select \n', ses);
  http('XMLAGG(XMLELEMENT(\'item\',\n', ses);
  http('XMLELEMENT(\'title\', BLOG..blog_utf2wide (B_TITLE)),\n', ses);
  http('XMLELEMENT(\'guid\', \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()||BI_HOME||\'?date=\'||substring (datestring (B_TS), 1, 10)||\'#\'||B_POST_ID),\n', ses);
  http('XMLELEMENT(\'comments\', \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()||BI_HOME||\'?id=\'||B_POST_ID||\'#comments\'),\n', ses);
  http('XMLELEMENT(\'pubDate\', BLOG.DBA.date_rfc1123 (B_TS)),\n', ses);
  http('XMLELEMENT(\'description\', BLOG..blog_utf2wide (BLOG.DBA.BLOG2_POST_RENDER(B_CONTENT, \'*default*\', B_USER_ID, null, B_IS_ACTIVE)))))\n', ses);
  http('from\n', ses);
  http('(select TOP 15 B_CONTENT, B_TS, B_META, BI_HOME, B_POST_ID, B_USER_ID, B_IS_ACTIVE, B_TITLE from\n', ses);
  http('BLOG..SYS_BLOGS, BLOG..SYS_BLOG_INFO where B_STATE = 2 and B_BLOG_ID = :bid and BI_BLOG_ID = B_BLOG_ID and\n', ses);
  http('exists (select 1 from BLOG..MTYPE_BLOG_CATEGORY where MTB_CID = :cid and MTB_BLOG_ID = B_BLOG_ID and MTB_POST_ID = B_POST_ID) order by B_TS desc\n', ses);
  http(') sub\n', ses);
  http(']]>\n', ses);
  http('</sql:sqlx>\n', ses);
  http('</channel>\n', ses);
  http('</rss>\n', ses);
  ses := string_output_string (ses);
  return ses;
}
;

create procedure BLOG2_HOME_GENERATE_RSS_CAT_XML(in blogid varchar) {
  declare str any;
  str := '<?xml version =\'1.0\' encoding=\'UTF-8\'?>\n
<rss version="2.0" xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'>\n
<sql:header><sql:param name=":bid"> </sql:param></sql:header>\n
<sql:header><sql:param name=":cid"> </sql:param></sql:header>\n
<sql:query>\n
select\n
  1 as tag,\n
  null as parent,\n
  BI_TITLE as [channel!1!title!element],\n
  \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()||BI_HOME as [channel!1!link!element],\n
  BI_ABOUT as [channel!1!description!element],\n
  BI_E_MAIL as [channel!1!managingEditor!element],\n
  BLOG.DBA.date_rfc1123(now ()) as [channel!1!pubDate!element],\n
  \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\') as [channel!1!generator!element],\n
  BI_E_MAIL as [channel!1!webMaster!element],\n
        null as [image!2!title!element],\n
        null as [image!2!url!element],\n
        null as [image!2!link!element],\n
        null as [image!2!description!element],\n
        null as [image!2!width!element],\n
        null as [image!2!height!element],\n
  null as [item!3!description!element],\n
  null as [item!3!pubDate!element],\n
  null as [item!3!title!element],\n
  null as [item!3!guid!element],\n
  null as [item!3!comments!element],\n
  null as [item!3!ts!hide]\n
  from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = :bid\n
\n
 union all\n
 select\n
        2,\n
  1,\n
  null,\n
        null,\n
  null,\n
  null,\n
  null,\n
  null,\n
  null,\n
        BI_TITLE,\n
  \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || \'/weblog/public/images/vbloglogo.gif\',\n
  \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || BI_HOME,\n
  BI_ABOUT,\n
  88,\n
  31,\n
  null,\n
  null,\n
  null,\n
  null,\n
  null,\n
  null\n
   from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = :bid\n
\n
union all\n
\n
select\n
  3,\n
  1,\n
  null,\n
  null,\n
  null,\n
  null,\n
  null,\n
  null,\n
  null,\n
  null,\n
  null,\n
  null,\n
  null,\n
  null,\n
  null,\n
  B_CONTENT,\n
  BLOG.DBA.date_rfc1123 (B_TS),\n
  BLOG.DBA.BLOG2_GET_TITLE (B_META, B_CONTENT),\n
        \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()||BI_HOME||\'?date=\'||substring (datestring (B_TS), 1, 10)||\'#\'||B_POST_ID,\n
        \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()||BI_HOME||\'?id=\'||B_POST_ID||\'#comments\',\n
  B_TS\n
  from\n
  (select TOP 15 B_CONTENT, B_TS, B_META, BI_HOME, B_POST_ID from\n
    BLOG..SYS_BLOGS, BLOG..SYS_BLOG_INFO where B_STATE = 2 and B_BLOG_ID = :bid and BI_BLOG_ID = B_BLOG_ID and \n
    exists (select 1 from BLOG..MTYPE_BLOG_CATEGORY \n
    where MTB_CID = :cid and MTB_BLOG_ID = :bid and MTB_POST_ID = B_POST_ID)\n
    order by B_TS desc\n
  ) sub\n
\n
for xml explicit\n
   </sql:query>\n
</rss>\n';
  return str;
}
;

create procedure BLOG2_HOME_GENERATE_OPML_XML_SQLX(in blogid varchar, in rep int := 1)
{
  declare ses any;
  ses := string_output ();
  http('<?xml version =\'1.0\' encoding=\'UTF-8\'?>\n', ses);
  http('<opml version="1.0" xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'>\n', ses);
  http('<sql:header><sql:param name=":c"> </sql:param></sql:header>\n', ses);
  http ('<head>\n', ses);
  http ('<sql:sqlx xmlns:sql=\'urn:schemas-openlink-com:xml-sql\' sql:xsl=""><![CDATA[\n', ses);
  http ('select XMLELEMENT (\'title\', BLOG..blog_utf2wide(BI_TITLE)) from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = <UID>\n', ses);
  http (']]></sql:sqlx>\n', ses);
  http ('</head>\n', ses);
  http('<body xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'>\n', ses);
  http('<sql:sqlx sql:xsl=""><![CDATA[\n', ses);
  http('select \n', ses);
  http('XMLAGG(XMLELEMENT(\'outline\',\n', ses);
  http('XMLATTRIBUTES(BLOG..blog_utf2wide(BCD_TITLE) as \'title\', BLOG..blog_utf2wide(BCD_TITLE) as \'text\', \'rss\' as \'type\', BCD_HOME_URI as \'htmlUrl\', BCD_CHANNEL_URI as \'xmlUrl\')))\n', ses);
  http('from BLOG.DBA.SYS_BLOG_CHANNELS, BLOG..SYS_BLOG_CHANNEL_INFO where BCD_CHANNEL_URI = BC_CHANNEL_URI and BC_BLOG_ID = <UID> and length(BC_CHANNEL_URI) and BC_CAT_ID = :c\n', ses);
  http(']]></sql:sqlx>\n', ses);
  http('</body>\n', ses);
  http('</opml>\n', ses);
  ses := string_output_string (ses);
  if (rep)
    ses := replace (ses, 'sql:xsl=""', '');
  ses := replace(ses, '<UID>', WS.WS.STR_SQL_APOS(blogid));
  return ses;
}
;

create procedure BLOG2_HOME_GENERATE_OCS_XML_SQLX (in blogid varchar)
{
  declare ret any;
  ret := BLOG2_HOME_GENERATE_OPML_XML_SQLX (blogid, 0);
  ret := replace (ret, 'sql:xsl=""', 'sql:xsl="/DAV/VAD/blog2/widgets/opml2ocs.xsl"');
  return ret;
}
;

create procedure BLOG2_HOME_GENERATE_XOXO (in blogid varchar)
{
  declare ret any;
  ret := BLOG2_HOME_GET_OPML_SQLX (blogid, 0);
  ret := replace (ret, 'sql:xsl=""', 'sql:xsl="/DAV/VAD/blog2/widgets/opml2xoxo.xsl"');
  return ret;
};

create procedure BLOG2_HOME_GET_OCS_SQLX (in blogid varchar)
{
  declare ret any;
  ret := BLOG2_HOME_GET_OPML_SQLX (blogid, 0);
  ret := replace (ret, 'sql:xsl=""', 'sql:xsl="/DAV/VAD/blog2/widgets/opml2ocs.xsl"');
  return ret;
};


create procedure BLOG2_HOME_GENERATE_OPML_XML(in blogid varchar, in rep int := 1)
{
declare str any;
str := '<?xml version =\'1.0\' encoding=\'UTF-8\'?>\n
<opml xmlns:sql=\'urn:schemas-openlink-com:xml-sql\' version="1.0" sql:xsl="">\n
  <head>\n
  </head>\n
  <body>\n
      <sql:header>\n
    <sql:param name=":c">0</sql:param>\n
    <sql:param name=":b"><UID></sql:param>\n
      </sql:header>\n
    <sql:query>\n
    select\n
  1 as tag,\n
  null as parent,\n
  BLOG..blog_utf2wide(BCD_TITLE) as [outline!1!title],\n
  BLOG..blog_utf2wide(BCD_TITLE) as [outline!1!text],\n
  \'rss\' as [outline!1!type],\n
  BCD_HOME_URI as [outline!1!htmlUrl],\n
  BCD_CHANNEL_URI as [outline!1!xmlUrl]\n
    from BLOG.DBA.SYS_BLOG_CHANNELS, BLOG..SYS_BLOG_CHANNEL_INFO\n
      where BCD_CHANNEL_URI = BC_CHANNEL_URI and BC_BLOG_ID = :b \n
            and length(BC_CHANNEL_URI) and BC_CAT_ID = :c\n
    for xml explicit\n
    </sql:query>\n
  </body>\n
</opml>\n';
if (rep)
  str := replace (str, 'sql:xsl=""', '');
str := replace (str, '<UID>', blogid);
return str;
}
;

create procedure BLOG2_GENERATE_RSD_SQL_SQLX(in blogid varchar)
{
  declare ses any;
  ses := string_output();
  http('<?xml version =\'1.0\' encoding=\'UTF-8\'?>\n', ses);
  http('<rsd version="1.0" xmlns="http://archipelago.phrasewise.com/rsd">\n', ses);
  http('<service>\n', ses);
  http('<sql:sqlx xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'><![CDATA[\n', ses);
  http('select \n', ses);
  http('XMLELEMENT(\'engineName\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', ses);
  http('XMLELEMENT(\'engineLink\', \'http://www.openlinksw.com/virtuoso/\'), \n', ses);
  http('XMLELEMENT(\'homePageLink\', \'http://\'||BLOG..BLOG_GET_HOST ()|| BLOG..BLOG_GET_HOME_DIR (BI_HOME))\n', ses);
  http('from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = <UID>\n', ses);
  http(']]></sql:sqlx>\n', ses);
  http('<apis>\n', ses);
  http('<sql:sqlx xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'><![CDATA[\n', ses);
  http('select \n', ses);
  http('XMLAGG(XMLELEMENT(\'api\', \n', ses);
  http('XMLATTRIBUTES(RP_NAME as \'name\' , \n', ses);
  http('case when RP_ID = 3 then \'true\' else \'false\' end as \'preferred\', \n', ses);
  http('\'http://\'||BLOG..BLOG_GET_HOST()||\'/RPC2\' as \'apiLink\', \n', ses);
  http('BI_BLOG_ID as \'blogID\')))\n', ses);
  http('from BLOG..SYS_BLOG_INFO, BLOG..SYS_ROUTING_PROTOCOL where BI_BLOG_ID = <UID> and RP_ID in (1,2,3)\n', ses);
  http(']]></sql:sqlx>\n', ses);
  http('</apis>\n', ses);
  http('</service>\n', ses);
  http('</rsd>\n', ses);
  ses := string_output_string (ses);
  ses := replace(ses, '<UID>', WS.WS.STR_SQL_APOS(blogid));
  return ses;
}
;


create procedure BLOG2_GENERATE_RSD_SQL(in blogid varchar) {
declare sql any;
sql := '
select  1 as Tag,\n
      NULL as Parent,\n
  \'1.0\' as [rsd!1!version],\n
  \'http://archipelago.phrasewise.com/rsd\' as [rsd!1!xmlns],\n
  null as [service!2!engineName!element],\n
  null as [service!2!engineLink!element],\n
  null as [service!2!homePageLink!element],\n
  null as [apis!3!api!hide],\n
  null as [api!4!name],\n
  null as [api!4!preferred],\n
  null as [api!4!apiLink],\n
  null as [api!4!blogID]\n
    from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = \'<UID>\'\n
union all\n
select 2, 1,\n
       null, null,\n
       \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\'), \'http://www.openlinksw.com/virtuoso/\', \'http://\'||BLOG..BLOG_GET_HOST ()|| BLOG..BLOG_GET_HOME_DIR (BI_HOME),\n
       null,\n
       null, null, null, null\n
       from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = \'<UID>\'\n
union all\n
select 3, 2,\n
       null, null,\n
       null, null, null,\n
       \'\',\n
       null, null, null, null\n
       from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = \'<UID>\'\n
union all\n
select  4, 3,\n
        null, null,\n
  null, null, null,\n
  null,\n
  RP_NAME, case when RP_ID = 3 then \'true\' else \'false\' end, \'http://\'||BLOG..BLOG_GET_HOST()||\'/RPC2\', \n
  BI_BLOG_ID\n
        from BLOG..SYS_BLOG_INFO, BLOG..SYS_ROUTING_PROTOCOL where BI_BLOG_ID = \'<UID>\' and RP_ID in (1,2,3)\n
for xml explicit\n';
  sql := replace(sql, '<UID>', blogid);
  return sql;
}
;

create procedure BLOG2_HOME_GENERATE_OCS_XML(in blogid varchar)
{
  declare r any;
  r := BLOG2_HOME_GENERATE_OPML_XML (blogid, 0);
  r := replace (r, 'sql:xsl=""', 'sql:xsl="/DAV/VAD/blog2/widgets/opml2ocs.xsl"');
  return r;
}
;

create procedure BLOG2_HOME_GET_RSS11_SQLX(in blogid varchar)
{
  declare r any;
  r := BLOG2_HOME_GET_RDF_SQLX (blogid);
  r := replace (r, 'rss2rdf', 'rss11');
  return r;
}
;

create procedure BLOG2_HOME_GET_RDF_SQLX(in blogid varchar)
{
  declare r any;
  r := BLOG2_HOME_GET_RSS_SQLX (blogid, 0);
  r := replace (r, 'sql:xsl=""', 'sql:xsl="/DAV/VAD/blog2/widgets/rss2rdf.xsl"');
  return r;
}
;

create procedure BLOG2_HOME_GET_MRSS_SQLX(in blogid varchar)
{
  declare r any;
  r := BLOG2_HOME_GET_PODCASTS_SQLX (blogid, 0);
  r := replace (r, 'sql:xsl=""', 'sql:xsl="/DAV/VAD/blog2/widgets/rss2mrss.xsl"');
  return r;
}
;

create procedure BLOG2_HOME_GET_RSSCOMMENT_SQLX()
{
  declare ses any;
  ses := string_output();
  http('<?xml version =\'1.0\' encoding=\'UTF-8\'?>\n', ses);
  http('<rss version="2.0" xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'>\n', ses);
  http('<channel xmlns:wfw="http://wellformedweb.org/CommentAPI/" xmlns:dc="http://purl.org/dc/elements/1.1/">\n', ses);
  http('<sql:header><sql:param name=":id"> </sql:param></sql:header>\n', ses);
  http('<sql:sqlx><![CDATA[\n', ses);
  http('select \n', ses);
  http('XMLELEMENT(\'title\', BLOG..blog_utf2wide (B_TITLE)), \n', ses);
  http('XMLELEMENT(\'link\', \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()||BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'|| B_POST_ID), \n', ses);
  http('XMLELEMENT(\'description\', BLOG..blog_utf2wide (BLOG..BLOG2_MAKE_SUMMARY (B_CONTENT, B_META, 1))), \n', ses);
  http('XMLELEMENT(\'pubDate\', BLOG.DBA.date_rfc1123 (B_TS)), \n', ses);
  http('XMLELEMENT(\'generator\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', ses);
  http('XMLELEMENT(\'http://purl.org/dc/elements/1.1/:creator\', U_FULL_NAME), \n', ses);
  http('XMLELEMENT(\'image\', \n', ses);
  http('XMLELEMENT(\'title\', BLOG.DBA.BLOG2_GET_TITLE (B_META, B_CONTENT)), \n', ses);
  http('XMLELEMENT(\'url\', \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || \'/weblog/public/images/vbloglogo.gif\'), \n', ses);
  http('XMLELEMENT(\'link\', \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'||B_POST_ID), \n', ses);
  http('XMLELEMENT(\'description\', BI_ABOUT), \n', ses);
  http('XMLELEMENT(\'width\', \'88\'), \n', ses);
  http('XMLELEMENT(\'height\', \'31\')) \n', ses);
  http('from BLOG..SYS_BLOGS, BLOG..SYS_BLOG_INFO, "DB"."DBA"."SYS_USERS" where B_STATE = 2 and B_POST_ID = :id and BI_BLOG_ID = B_BLOG_ID and U_ID = B_USER_ID\n', ses);
  http(']]></sql:sqlx>\n', ses);
  http('<sql:sqlx><![CDATA[\n', ses);
  http('select \n', ses);
  http('XMLAGG(XMLELEMENT(\'item\',\n', ses);
  http('XMLELEMENT(\'title\', charset_recode (BM_NAME, \'UTF-8\', \'_WIDE_\')),\n', ses);
  http('XMLELEMENT(\'guid\', \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()||BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'||B_POST_ID||\'#\'||cast (BM_ID as varchar)),\n', ses);
  http('XMLELEMENT(\'link\', \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()||BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'||B_POST_ID||\'#\'||cast (BM_ID as varchar)),\n', ses);
  http('XMLELEMENT(\'http://purl.org/dc/elements/1.1/:creator\', BM_E_MAIL),\n', ses);
  http('XMLELEMENT(\'pubDate\', BLOG.DBA.date_rfc1123 (BM_TS)),\n', ses);
  http('XMLELEMENT(\'description\', charset_recode (blob_to_string (BM_COMMENT), \'UTF-8\', \'_WIDE_\'))))\n', ses);
  http('from\n', ses);
  http('(select TOP 15 BM_COMMENT, BM_NAME, B_META, B_CONTENT, BM_E_MAIL, BM_ID, BM_HOME_PAGE, BI_HOME, B_POST_ID, BM_TS from\n', ses);
  http('BLOG..SYS_BLOGS, BLOG..SYS_BLOG_INFO, BLOG..BLOG_COMMENTS\n', ses);
  http('where B_STATE = 2 and B_POST_ID = :id and BI_BLOG_ID = B_BLOG_ID and BM_POST_ID = B_POST_ID and BM_IS_PUB = 1 order by BM_TS desc\n', ses);
  http(') sub\n', ses);
  http(']]>\n', ses);
  http('</sql:sqlx>\n', ses);
  http('</channel>\n', ses);
  http('</rss>\n', ses);
  ses := string_output_string (ses);
  return ses;
}
;

create procedure BLOG2_HOME_GET_RSSCOMMENT()
{
  return '
    <?xml version =\'1.0\' encoding=\'UTF-8\'?>\n
    <rss version="2.0" xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'>\n
    <sql:header><sql:param name=":id"> </sql:param></sql:header>\n
    <sql:query>\n
      select\n
        1 as tag, null as parent,\n
        \'http://wellformedweb.org/CommentAPI/\' as [channel!1!xmlns:wfw],\n
        \'http://purl.org/dc/elements/1.1/\' as [channel!1!xmlns:dc],\n
          BLOG.DBA.BLOG2_GET_TITLE (B_META, B_CONTENT) as [channel!1!title!element],\n
          \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()||BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'|| B_POST_ID as [channel!1!link!element],\n
          B_CONTENT as [channel!1!description!element],\n
          BLOG.DBA.date_rfc1123 (B_TS) as [channel!1!pubDate!element],\n
          U_FULL_NAME as [channel!1!dc:creator!element],\n
          \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\') as [channel!1!generator!element],\n
                null as [image!2!title!element],\n
                null as [image!2!url!element],\n
                null as [image!2!link!element],\n
                null as [image!2!description!element],\n
                null as [image!2!width!element],\n
                null as [image!2!height!element],\n
          null as [item!3!title!element],\n
          null as [item!3!guid!element],\n
          null as [item!3!link!element],\n
          null as [item!3!pubDate!element],\n
          null as [item!3!dc:creator!element],\n
          null as [item!3!description!element],\n
          null as [item!3!ts!hide]\n
          from BLOG..SYS_BLOGS, BLOG..SYS_BLOG_INFO, "DB"."DBA"."SYS_USERS"
    where B_STATE = 2 and B_POST_ID = :id and BI_BLOG_ID = B_BLOG_ID and U_ID = B_USER_ID\n
        \n
        union all\n
        \n
         select\n
                2, 1,\n
          null, null, null, null, null, null, null, null,\n
          B_TITLE,\n
          \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || \'/weblog/public/images/vbloglogo.gif\',\n
          \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'||B_POST_ID,\n
          BI_ABOUT,\n
          88,\n
          31,\n
          null, null, null, null, null, null, null\n
           from BLOG..SYS_BLOGS, BLOG..SYS_BLOG_INFO where B_STATE = 2 and B_POST_ID = :id and BI_BLOG_ID = B_BLOG_ID\n
        \n
        union all\n
        \n
        select\n
          3, 1,\n
          null, null, null, null, null, null, null, null,\n
                null, null, null, null, null, null,\n
          BLOG..blog_utf2wide (BM_NAME),\n
                \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()||BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'||B_POST_ID||\'#\'||cast (BM_ID as varchar),\n
                \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()||BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'||B_POST_ID||\'#\'||cast (BM_ID as varchar),\n
          BLOG.DBA.date_rfc1123 (BM_TS),\n
          BM_E_MAIL,\n
          BLOG..blog_utf2wide (blob_to_string (BM_COMMENT)),\n
          BM_TS\n
          from\n
          (select TOP 15 BM_COMMENT, BM_NAME, B_META, B_CONTENT, BM_E_MAIL, BM_ID, BM_HOME_PAGE,\n
              BI_HOME, B_POST_ID, BM_TS from\n
            BLOG..SYS_BLOGS, BLOG..SYS_BLOG_INFO, BLOG..BLOG_COMMENTS
    where B_STATE = 2 and B_POST_ID = :id and BI_BLOG_ID = B_BLOG_ID\n
            and BM_POST_ID = B_POST_ID and BM_IS_PUB = 1\n
            order by BM_TS desc\n
          ) sub\n
        \n
        for xml explicit\n
           </sql:query>\n
        </rss>\n';
}
;

create procedure
BLOG_ENCLOSURE_RENDER_SQLX (inout meta any)
{
  declare mt BLOG.DBA."MWeblogPost";
  declare enc BLOG.DBA."MWeblogEnclosure";
  mt := meta;
  if (meta is null or mt.enclosure is null)
    return '';
  enc := mt.enclosure;
  return xmlelement ('enclosure', xmlattributes (enc.url as url, enc."length" as "length", enc."type" as "type"));

}
;

create procedure BLOG2_MAKE_SUMMARY (in str any, inout meta any, in force int := 0)
{
  declare mt BLOG.DBA."MWeblogPost";
  mt := meta;
  if (force = 0 and (meta is null or mt.enclosure is null))
    return '';
  str := blob_to_string (str);
  str := trim(regexp_replace (str, '<[^>]+>', '', 1, null));
  str := replace (str, '&#39;', '\'');
  return str;
};

create procedure BLOG_GET_BLOG_KWDSP (in kwds varchar)
{
  declare BI_KWD varchar;
  declare arr any;
  result_names (BI_KWD);
  if (not length (kwds))
    return;
  arr := split_and_decode (kwds, 0, '\0\0 ');
  foreach (any kwd in arr) do
    {
      kwd := trim (kwd);
      if (length (kwd) > 1)
        result (kwd);
    }
};

blog2_exec_no_error(
  'create procedure view BLOG.DBA.BLOG_GET_BLOG_KWDS as BLOG.DBA.BLOG_GET_BLOG_KWDSP(kwds) (BI_KWD varchar)'
)
;

create procedure BLOG2_HOME_GET_RSS_SQLX(in blogid varchar, in rep int := 1)
{
  declare ses any;
  ses := string_output();
http ('<?xml version =\'1.0\' encoding=\'UTF-8\'?>\n', ses);
http ('<rss version="2.0" xmlns:wfw="http://wellformedweb.org/CommentAPI/" \n', ses);
http ('    xmlns:slash="http://purl.org/rss/1.0/modules/slash/" \n', ses);
http ('    xmlns:sql="urn:schemas-openlink-com:xml-sql">\n', ses);
http ('<channel>\n', ses);
http ('<sql:sqlx sql:xsl=""><![CDATA[\n', ses);
http ('select \n', ses);
http ('XMLELEMENT(\'title\', BLOG..blog_utf2wide (BI_TITLE)), \n', ses);
http ('XMLELEMENT(\'link\', \'http://\' || BLOG.DBA.BLOG2_GET_HOST() || BLOG.DBA.BLOG2_GET_HOME_DIR(BI_HOME)), \n', ses);
http ('XMLELEMENT(\'description\', BLOG..blog_utf2wide (BI_ABOUT)), \n', ses);
http ('XMLELEMENT(\'managingEditor\', BLOG..blog_utf2wide (U_FULL_NAME || \' <\'||BI_E_MAIL||\'>\')), \n', ses);
http ('XMLELEMENT(\'pubDate\', BLOG.DBA.date_rfc1123(now())), \n', ses);
http ('XMLELEMENT(\'generator\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', ses);
http ('XMLELEMENT(\'webMaster\', BI_E_MAIL), \n', ses);
http ('XMLELEMENT(\'copyright\', BLOG..blog_utf2wide (BI_COPYRIGHTS)), \n', ses);
http ('XMLELEMENT(\'http://www.w3.org/2005/Atom:link\', XMLATTRIBUTES (\'http://\' || BLOG.DBA.BLOG2_GET_HOST () || http_path() as "href", \'self\' as "rel", \'application/rss+xml\' as "type", BLOG..blog_utf2wide (BI_TITLE) as "title")), \n', ses);
http ('(select XMLAGG (XMLELEMENT(\'http://www.w3.org/2005/Atom:link\', XMLATTRIBUTES (SH_URL as "href", \'hub\' as "rel", \'PubSubHub\' as "title"))) from ODS.DBA.SVC_HOST, ODS.DBA.APP_PING_REG, DB.DBA.WA_INSTANCE where SH_PROTO = \'PubSubHub\' and SH_ID = AP_HOST_ID and AP_WAI_ID = WAI_ID and WAI_NAME = BI_WAI_NAME), \n', ses);
http ('XMLELEMENT(\'http://www.w3.org/2005/Atom:link\', XMLATTRIBUTES (sprintf (\'http://%{WSHost}s/ods/salmon\') as "href", \'salmon\' as "rel")), \n', ses);
http ('(select XMLAGG (XMLELEMENT (\'category\', BI_KWD)) from BLOG.DBA.BLOG_GET_BLOG_KWDS where kwds = BI_KEYWORDS) ,\n', ses);
http ('\n', ses);
http ('XMLELEMENT(\'language\', \'en-us\'), \n', ses);
http ('\n', ses);
http ('XMLELEMENT(\'image\', \n', ses);
http ('XMLELEMENT(\'title\', BLOG..blog_utf2wide (BI_TITLE)), \n', ses);
http ('XMLELEMENT(\'url\', \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || \'/weblog/public/images/vbloglogo.gif\'), \n', ses);
http ('XMLELEMENT(\'link\', \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)), \n', ses);
http ('XMLELEMENT(\'description\', BLOG..blog_utf2wide (BI_ABOUT)), \n', ses);
http ('XMLELEMENT(\'width\', \'88\'), \n', ses);
http ('XMLELEMENT(\'height\', \'31\')) \n', ses);
http ('from BLOG..SYS_BLOG_INFO, DB.DBA.SYS_USERS where BI_BLOG_ID = <UID> and BI_OWNER = U_ID\n', ses);
http (']]></sql:sqlx>\n', ses);
http ('<sql:sqlx><![CDATA[\n', ses);
http ('select \n', ses);
http ('XMLELEMENT(\'cloud\', \n', ses);
http ('XMLATTRIBUTES(sys_stat(\'st_host_name\') as \'domain\' , \n', ses);
http ('server_http_port() as \'port\' , \n', ses);
http ('\'/RPC2\' as \'path\', \n', ses);
http ('\'xmlStorageSystem.requestNotification\' as \'registerProcedure\', \n', ses);
http ('\'xml-rpc\' as \'protocol\'))\n', ses);
http (']]></sql:sqlx>\n', ses);
http ('<sql:sqlx><![CDATA[\n', ses);
http ('select \n', ses);
http ('XMLAGG(\n', ses);
http ('XMLELEMENT (\'item\',\n', ses);
http ('XMLELEMENT (\'title\', BLOG..blog_utf2wide (B_TITLE)),\n', ses);
http ('XMLELEMENT (\'guid\', \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()||BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'||B_POST_ID),\n', ses);
http ('XMLELEMENT (\'link\', \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()||BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'||B_POST_ID),\n', ses);
http ('XMLELEMENT (\'comments\', \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()||BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'||B_POST_ID||\'#comments\'),\n', ses);
http ('case when B_COMMENTS_NO then XMLELEMENT(\'http://purl.org/rss/1.0/modules/slash/:comments\', B_COMMENTS_NO) else null end,\n', ses);
http ('XMLELEMENT(\'http://wellformedweb.org/CommentAPI/:comment\', \'http://\' || BLOG.DBA.BLOG2_GET_HOST() || \'/mt-tb/Http/comments?id=\' || B_POST_ID),\n', ses);
http ('XMLELEMENT(\'http://wellformedweb.org/CommentAPI/:commentRss\', \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()||BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'gems/rsscomment.xml?:id=\' || B_POST_ID),\n', ses);
http ('XMLELEMENT(\'pubDate\', BLOG.DBA.date_rfc1123 (B_TS)),\n', ses);
http ('XMLELEMENT(\'description\', BLOG..blog_utf2wide (BLOG.DBA.BLOG2_POST_RENDER(B_CONTENT, \'*default*\', B_USER_ID, null, B_IS_ACTIVE))),\n', ses);
http ('XMLELEMENT(\'author\', BLOG..blog_utf2wide (U_FULL_NAME || \' <\'||U_E_MAIL||\'>\')),\n', ses);
http (' (select XMLAGG (XMLELEMENT (\'category\', BT_TAG)) from BLOG..BLOG_POST_TAGS_STAT_2 where blogid = B_BLOG_ID and postid = B_POST_ID) ,\n', ses);
http ('XMLELEMENT(\'http://www.openlinksw.com/weblog/:version\', B_VER),\n', ses);
http ('XMLELEMENT(\'http://www.openlinksw.com/weblog/:modified\', BLOG..date_iso8601 (B_MODIFIED)),\n', ses);
http ('BLOG..BLOG_ENCLOSURE_RENDER_SQLX (B_META) ))\n', ses);
http ('from\n', ses);
http ('(select TOP 15 B_CONTENT, B_TS, B_META, BI_HOME, B_POST_ID, B_COMMENTS_NO, BI_FILTER, B_USER_ID, B_TITLE,\n', ses);
http ('        U_FULL_NAME, U_E_MAIL, B_BLOG_ID, B_MODIFIED, B_IS_ACTIVE, B_VER\n', ses);
http ('  from\n', ses);
http ('BLOG..SYS_BLOGS, BLOG..SYS_BLOG_INFO,\n', ses);
http ('        (select BI_BLOG_ID as BA_C_BLOG_ID, BI_BLOG_ID as BA_M_BLOG_ID from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = <UID>\n', ses);
http ('        union all select * from (select top 15 BA_C_BLOG_ID, BA_M_BLOG_ID from BLOG.DBA.SYS_BLOG_ATTACHES\n', ses);
http ('          where BA_M_BLOG_ID = <UID> order by BA_LAST_UPDATE desc) name1) name2, DB.DBA.SYS_USERS\n', ses);
http ('      where B_BLOG_ID = BA_C_BLOG_ID and B_STATE = 2 and BI_BLOG_ID = B_BLOG_ID and U_ID = B_USER_ID order by B_TS desc\n', ses);
http (') sub\n', ses);
http (']]></sql:sqlx>\n', ses);
http ('</channel>\n', ses);
http ('</rss>\n', ses);
  ses := string_output_string (ses);
  if (rep)
    ses := replace (ses, 'sql:xsl=""', '');
  ses := replace(ses, '<UID>', WS.WS.STR_SQL_APOS(blogid));
  return ses;
}
;

create procedure BLOG2_HOME_GET_PODCASTS_SQLX(in blogid varchar, in rep int := 1)
{
  declare ses any;
  ses := string_output();
http ('<?xml version =\'1.0\' encoding=\'UTF-8\'?>\n', ses);
http ('<rss version="2.0" xmlns:wfw="http://wellformedweb.org/CommentAPI/" \n', ses);
http ('    xmlns:slash="http://purl.org/rss/1.0/modules/slash/" \n', ses);
http ('    xmlns:sql="urn:schemas-openlink-com:xml-sql">\n', ses);
http ('<channel>\n', ses);
http ('    <sql:header>\n', ses);
http ('        <sql:param name=":media">%</sql:param>\n', ses);
http ('    </sql:header>\n', ses);
http ('<sql:sqlx sql:xsl=""><![CDATA[\n', ses);
http ('select \n', ses);
http ('XMLELEMENT(\'title\', BLOG..blog_utf2wide (BI_TITLE)), \n', ses);
http ('XMLELEMENT(\'link\', \'http://\' || BLOG.DBA.BLOG2_GET_HOST() || BLOG.DBA.BLOG2_GET_HOME_DIR(BI_HOME)), \n', ses);
http ('XMLELEMENT(\'description\', BLOG..blog_utf2wide (BI_ABOUT)), \n', ses);
http ('XMLELEMENT(\'managingEditor\', BLOG..blog_utf2wide (U_FULL_NAME || \' <\'||BI_E_MAIL||\'>\')), \n', ses);
http ('XMLELEMENT(\'pubDate\', BLOG.DBA.date_rfc1123(now())), \n', ses);
http ('XMLELEMENT(\'generator\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', ses);
http ('XMLELEMENT(\'webMaster\', BI_E_MAIL), \n', ses);
http ('XMLELEMENT(\'copyright\', BLOG..blog_utf2wide (BI_COPYRIGHTS)), \n', ses);
http ('XMLELEMENT(\'category\', BI_KEYWORDS), \n', ses);
http ('\n', ses);
http ('XMLELEMENT(\'http://www.itunes.com/DTDs/Podcast-1.0.dtd:author\', BLOG..blog_utf2wide (U_FULL_NAME)), \n', ses);
http ('XMLELEMENT(\'http://www.itunes.com/DTDs/Podcast-1.0.dtd:subtitle\', BLOG..blog_utf2wide (BI_ABOUT)), \n', ses);
http ('XMLELEMENT(\'http://www.itunes.com/DTDs/Podcast-1.0.dtd:owner\', \n', ses);
http ('            XMLELEMENT(\'http://www.itunes.com/DTDs/Podcast-1.0.dtd:name\', BLOG..blog_utf2wide (U_FULL_NAME)),\n', ses);
http ('            XMLELEMENT(\'http://www.itunes.com/DTDs/Podcast-1.0.dtd:email\', BI_E_MAIL) \n', ses);
http ('            ), \n', ses);
http ('XMLELEMENT(\'language\', \'en-us\'), \n', ses);
http ('XMLELEMENT(\'http://www.itunes.com/DTDs/Podcast-1.0.dtd:category\', XMLATTRIBUTES (\'News\' as \'text\')), \n', ses);
http ('XMLELEMENT(\'http://www.itunes.com/DTDs/Podcast-1.0.dtd:explicit\', \'no\'), \n', ses);
http ('	    \n', ses);
http ('XMLELEMENT(\'image\', \n', ses);
http ('XMLELEMENT(\'title\', BLOG..blog_utf2wide (BI_TITLE)), \n', ses);
http ('XMLELEMENT(\'url\', \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || \'/weblog/public/images/vbloglogo.gif\'), \n', ses);
http ('XMLELEMENT(\'link\', \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)), \n', ses);
http ('XMLELEMENT(\'description\', BLOG..blog_utf2wide (BI_ABOUT)), \n', ses);
http ('XMLELEMENT(\'width\', \'88\'), \n', ses);
http ('XMLELEMENT(\'height\', \'31\')) \n', ses);
http ('from BLOG..SYS_BLOG_INFO, DB.DBA.SYS_USERS where BI_BLOG_ID = <UID> and BI_OWNER = U_ID\n', ses);
http (']]></sql:sqlx>\n', ses);
http ('<sql:sqlx><![CDATA[\n', ses);
http ('select \n', ses);
http ('XMLELEMENT(\'cloud\', \n', ses);
http ('XMLATTRIBUTES(sys_stat(\'st_host_name\') as \'domain\' , \n', ses);
http ('server_http_port() as \'port\' , \n', ses);
http ('\'/RPC2\' as \'path\', \n', ses);
http ('\'xmlStorageSystem.requestNotification\' as \'registerProcedure\', \n', ses);
http ('\'xml-rpc\' as \'protocol\'))\n', ses);
http (']]></sql:sqlx>\n', ses);
http ('<sql:sqlx><![CDATA[\n', ses);
http ('select \n', ses);
http ('XMLAGG(\n', ses);
http ('XMLELEMENT (\'item\',\n', ses);
http ('XMLELEMENT (\'title\', BLOG..blog_utf2wide (B_TITLE)),\n', ses);
http ('XMLELEMENT (\'guid\', \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()||BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'||B_POST_ID),\n', ses);
http ('XMLELEMENT (\'link\', \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()||BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'||B_POST_ID),\n', ses);
http ('XMLELEMENT (\'comments\', \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()||BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'||B_POST_ID||\'#comments\'),\n', ses);
http ('case when B_COMMENTS_NO then XMLELEMENT(\'http://purl.org/rss/1.0/modules/slash/:comments\', B_COMMENTS_NO) else null end,\n', ses);
http ('XMLELEMENT(\'http://wellformedweb.org/CommentAPI/:comment\', \'http://\' || BLOG.DBA.BLOG2_GET_HOST() || \'/mt-tb/Http/comments?id=\' || B_POST_ID),\n', ses);
http ('XMLELEMENT(\'http://wellformedweb.org/CommentAPI/:commentRss\', \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()||BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'gems/rsscomment.xml?:id=\' || B_POST_ID),\n', ses);
http ('XMLELEMENT(\'pubDate\', BLOG.DBA.date_rfc1123 (B_TS)),\n', ses);
http ('XMLELEMENT(\'description\', BLOG..blog_utf2wide (BLOG.DBA.BLOG2_POST_RENDER(B_CONTENT, \'*default*\', B_USER_ID, null, B_IS_ACTIVE))),\n', ses);
http ('XMLELEMENT(\'author\', BLOG..blog_utf2wide (U_FULL_NAME || \' <\'||U_E_MAIL||\'>\')),\n', ses);
--http ('XMLELEMENT(\'http://purl.org/dc/elements/1.1/:subject\', BLOG..BLOG_GET_SUBJECT (B_POST_ID,B_BLOG_ID)),\n', ses);
http ('(select XMLAGG (XMLELEMENT (\'category\', BT_TAG)) from BLOG..BLOG_POST_TAGS_STAT_2 where blogid = B_BLOG_ID and postid = B_POST_ID) ,\n', ses);
http ('XMLELEMENT(\'http://www.openlinksw.com/weblog/:modified\', BLOG..date_iso8601 (B_MODIFIED)),\n', ses);
http ('XMLELEMENT (\'http://www.itunes.com/DTDs/Podcast-1.0.dtd:author\', BLOG..blog_utf2wide (U_FULL_NAME)),\n', ses);
http ('XMLELEMENT (\'http://www.itunes.com/DTDs/Podcast-1.0.dtd:subtitle\', BLOG..blog_utf2wide (B_TITLE)),\n', ses);
http ('XMLELEMENT (\'http://www.itunes.com/DTDs/Podcast-1.0.dtd:summary\', BLOG..blog_utf2wide (BLOG..BLOG2_MAKE_SUMMARY (B_CONTENT, B_META))),\n', ses);
http ('XMLELEMENT (\'http://www.itunes.com/DTDs/Podcast-1.0.dtd:explicit\', \'no\'),\n', ses);
http ('XMLELEMENT (\'http://www.itunes.com/DTDs/Podcast-1.0.dtd:keywords\', BLOG..BLOG_GET_TAGS (B_BLOG_ID, B_POST_ID)),\n', ses);
http ('BLOG..BLOG_ENCLOSURE_RENDER_SQLX (B_META) ))\n', ses);
http ('from\n', ses);
http ('(select TOP 15 B_CONTENT, B_TS, B_META, BI_HOME, B_POST_ID, B_COMMENTS_NO, BI_FILTER, B_USER_ID, B_TITLE,\n', ses);
http ('        U_FULL_NAME, U_E_MAIL, B_BLOG_ID, B_MODIFIED, B_IS_ACTIVE\n', ses);
http ('  from\n', ses);
http ('BLOG..SYS_BLOGS, BLOG..SYS_BLOG_INFO,\n', ses);
http ('        (select BI_BLOG_ID as BA_C_BLOG_ID, BI_BLOG_ID as BA_M_BLOG_ID from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = <UID>\n', ses);
http ('        union all select * from (select top 15 BA_C_BLOG_ID, BA_M_BLOG_ID from BLOG.DBA.SYS_BLOG_ATTACHES\n', ses);
http ('          where BA_M_BLOG_ID = <UID> order by BA_LAST_UPDATE desc) name1) name2, DB.DBA.SYS_USERS\n', ses);
http ('      where B_BLOG_ID = BA_C_BLOG_ID and B_HAVE_ENCLOSURE = 1 and B_ENCLOSURE_TYPE like :media||\'%\' and B_STATE = 2 and BI_BLOG_ID = B_BLOG_ID and U_ID = B_USER_ID order by B_TS desc\n', ses);
http (') sub\n', ses);
http (']]></sql:sqlx>\n', ses);
http ('</channel>\n', ses);
http ('</rss>\n', ses);
  ses := string_output_string (ses);
  if (rep)
    ses := replace (ses, 'sql:xsl=""', '');
  ses := replace(ses, '<UID>', WS.WS.STR_SQL_APOS(blogid));
  return ses;
}
;

create procedure BLOG2_HOME_GET_RSS(in blogid varchar) {
declare sql any;
sql := 'select
  1 as tag,
  null as parent,
  \'2.0\' as [rss!1!version],
  \'http://purl.org/dc/elements/1.1/\' as [rss!1!"xmlns:dc"],
  \'http://wellformedweb.org/CommentAPI/\' as [rss!1!xmlns:wfw],
  \'http://purl.org/rss/1.0/modules/slash/\' as [rss!1!xmlns:slash],
  \'http://www.openlinksw.com/weblog/\' as [rss!1!xmlns:vi],
  null as [channel!2!title!element],
  null as [channel!2!link!element],
  null as [channel!2!description!element],
  null as [channel!2!managingEditor!element],
  null as [channel!2!pubDate!element],
  null as [channel!2!generator!element],
  null as [channel!2!webMaster!element],
        null as [image!3!title!element],
        null as [image!3!url!element],
        null as [image!3!link!element],
        null as [image!3!description!element],
        null as [image!3!width!element],
        null as [image!3!height!element],
  null as [cloud!4!domain],
  null as [cloud!4!port],
  null as [cloud!4!path],
  null as [cloud!4!registerProcedure],
  null as [cloud!4!protocol],
  null as [item!5!title!element],
  null as [item!5!guid!element],
  null as [item!5!link!element],
  null as [item!5!comments!element],
  null as [item!5!!xmltext],
  null as [item!5!wfw:comment!element],
  null as [item!5!wfw:commentRss!element],
  null as [item!5!pubDate!element],
  null as [item!5!description!element],
  null as [item!5!author!element],
  null as [item!5!!xmltext],
  null as [item!5!!xmltext],
  null as [item!5!vi:version!element],
  null as [item!5!vi:modified!element]
  from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = <UID>
union all
select
  2,
  1,
  null, null, null, null, null,
  BI_TITLE,
  \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()|| BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME),
  BI_ABOUT,
  BI_E_MAIL,
  BLOG.DBA.date_rfc1123(now ()),
  \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\'),
  BI_E_MAIL,
  null, null, null, null, null, null,
  null, null, null, null, null,
  null, null, null, null, null, null, null, null, null, null, null, null, null, null
  from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = <UID>
union all
select
  3,
  2,
  null, null, null, null, null,
  null, null, null, null, null, null, null,
  BI_TITLE,
  \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || \'/weblog/public/images/vbloglogo.gif\',
  \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME),
  BI_ABOUT,
  88,
  31,
  null, null, null, null, null,
  null, null, null, null, null, null, null, null, null, null, null, null, null, null
  from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = <UID>
union all
select
  4,
  2,
  null, null, null, null, null,
  null, null, null, null, null, null, null,
  null, null, null, null, null, null,
  sys_stat (\'st_host_name\'),
  server_http_port (),
  \'/RPC2\',
  \'xmlStorageSystem.requestNotification\',
  \'xml-rpc\',
  null, null, null, null, null, null, null, null, null, null, null, null, null, null
  from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = <UID>
union all
select
  5,
  2,
  null, null, null, null, null,
  null, null, null, null, null, null, null,
  null, null, null, null, null, null,
  null, null, null, null, null,
  B_TITLE,
  \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()||BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'||B_POST_ID,
  \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()||BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'||B_POST_ID,
  \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()||BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'||B_POST_ID||\'#comments\',
  case when B_COMMENTS_NO then sprintf (\'<slash:comments>%d</slash:comments>\', B_COMMENTS_NO) else \'\' end,
  \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()||\'/mt-tb/Http/comments?id=\'||B_POST_ID,
  \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()||BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'gems/rsscomment.xml?:id=\'||B_POST_ID,
  BLOG.DBA.date_rfc1123 (B_TS),
  BLOG.DBA.BLOG2_POST_RENDER (B_CONTENT, BI_FILTER, B_USER_ID, null, B_IS_ACTIVE),
  U_FULL_NAME || \' <\'||U_E_MAIL||\'>\',
  BLOG..BLOG_TAGS_RENDER (B_POST_ID,B_BLOG_ID),
  BLOG..BLOG_ENCLOSURE_RENDER (B_META),
  B_VER,
  BLOG.DBA.date_iso8601 (B_MODIFIED)
  from
  (select TOP 15 B_CONTENT, B_TS, B_META, BI_HOME, B_POST_ID, B_COMMENTS_NO, BI_FILTER, B_TITLE, B_USER_ID,
   U_FULL_NAME, U_E_MAIL, B_BLOG_ID, B_IS_ACTIVE, B_MODIFIED, B_VER from
    BLOG..SYS_BLOGS, BLOG..SYS_BLOG_INFO,
    (select BI_BLOG_ID as BA_C_BLOG_ID, BI_BLOG_ID as BA_M_BLOG_ID from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = <UID>
     union all select * from (select top 15 BA_C_BLOG_ID, BA_M_BLOG_ID from BLOG.DBA.SYS_BLOG_ATTACHES
       where BA_M_BLOG_ID = <UID> order by BA_LAST_UPDATE desc) name1) name2, DB.DBA.SYS_USERS
  where B_BLOG_ID = BA_C_BLOG_ID and B_STATE = 2 and BI_BLOG_ID = B_BLOG_ID and B_USER_ID = U_ID order by B_TS desc
  ) sub
for xml explicit';
  sql := replace(sql, '<UID>', WS.WS.STR_SQL_APOS(blogid));
  return serialize_to_UTF8_xml(sql);
}
;

-- atom.xml
create procedure BLOG2_HOME_GET_ATOM_SQLX(in blogid varchar)
{
  declare r any;
  declare xsl any;
  xsl := BLOG_GET_ATOM_XSL ();
  r := BLOG2_HOME_GET_RSS_SQLX (blogid, 0);
  r := replace (r, 'sql:xsl=""', 'sql:xsl="/DAV/VAD/blog2/widgets/'||xsl||'"');
  return r;
}
;


create procedure BLOG2_HOME_GET_OPML_SQLX (in blogid varchar, in rep int := 1) {
  declare ses any;
  ses := string_output ();
  http ('<?xml version="1.0" encoding="UTF-8" ?>\n', ses);
  http ('<opml version="1.0">\n', ses);
  http ('<head>\n', ses);
  http ('<sql:sqlx xmlns:sql=\'urn:schemas-openlink-com:xml-sql\' sql:xsl=""><![CDATA[\n', ses);
  http ('select XMLELEMENT (\'title\', BLOG..blog_utf2wide(BI_TITLE)) from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = <UID>\n', ses);
  http (']]></sql:sqlx>\n', ses);
  http ('</head>\n', ses);
  http ('<body>\n', ses);
  http ('<sql:sqlx xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'><![CDATA[\n', ses);
  http ('select \n', ses);
  http ('XMLAGG(XMLELEMENT(\'outline\',\n', ses);
  http ('XMLATTRIBUTES(BLOG..blog_utf2wide(BC_TITLE) as \'text\', BLOG..blog_utf2wide(BC_TITLE) as \'title\', \'rss\' as \'type\', BC_HOME_URI as \'htmlUrl\', BC_RSS_URI as \'xmlUrl\')))\n', ses);
  http ('from BLOG.DBA.BLOG_CHANNELS where BC_BLOG_ID = <UID> and length(BC_RSS_URI)\n', ses);
  http (']]></sql:sqlx>\n', ses);
  http ('</body>\n', ses);
  http ('</opml>\n', ses);
  ses := string_output_string (ses);
  if (rep)
    ses := replace (ses, 'sql:xsl=""', '');
  ses := replace(ses, '<UID>', WS.WS.STR_SQL_APOS(blogid));
  return ses;
}
;

create procedure BLOG2_HOME_GET_OPML(in blogid varchar) {
  declare sql any;
sql := 'select
  1 as tag, null as parent,
  \'\' as [opml!1!head!element], \'1.0\' as [opml!1!version],
  null as [body!2!!hide],
  null as [outline!3!title],
  null as [outline!3!text],
  null as [outline!3!type],
  null as [outline!3!htmlUrl],
  null as [outline!3!xmlUrl]
  from "DB"."DBA"."SYS_USERS" where U_ID = http_dav_uid ()
union all
select
  2, 1,
  null, null,
  1,
  null,
  null,
  null,
  null,
  null
  from "DB"."DBA"."SYS_USERS" where U_ID = http_dav_uid ()
union all
select
  3, 2,
  null, null,
  1,
  BC_TITLE,
  BC_TITLE,
  \'rss\',
  BC_HOME_URI,
  BC_RSS_URI
  from BLOG.DBA.BLOG_CHANNELS
  where BC_BLOG_ID = <UID> and length(BC_RSS_URI)
  for xml explicit';
  sql := replace(sql, '<UID>', WS.WS.STR_SQL_APOS(blogid));
  return sql;
}
;


create procedure BLOG2_HOME_GET_FOAF(in blogid varchar) {
  declare sql any;
sql := 'select  1 as tag, null as parent,
        \'http://www.w3.org/1999/02/22-rdf-syntax-ns#\' as ["rdf:RDF"!1!"xmlns:rdf"],
        \'http://www.w3.org/2000/01/rdf-schema#\' as ["rdf:RDF"!1!"xmlns:rdfs"],
        \'http://xmlns.com/foaf/0.1/\' as ["rdf:RDF"!1!"xmlns:foaf"],
        \'http://purl.org/dc/elements/1.1/\' as ["rdf:RDF"!1!"xmlns:dc"],
        \'http://usefulinc.com/ns/scutter/0.1#\' as ["rdf:RDF"!1!"xmlns:plan"],
  null as ["foaf:Person"!2!"rdf:ID"],
  null as ["foaf:Person"!2!"foaf:name"!element],
  null as ["foaf:Person"!2!"foaf:nick"!element],
  null as ["foaf:mbox"!3!"rdf:resource"],
  null as ["foaf:homepage"!4!"rdf:resource"],
  null as ["foaf:weblog"!5!"rdf:resource"],
  null as ["rdf:seeAlso"!6!"rdf:resource"],
  null as ["foaf:knows"!7!!xmltext],
  null as ["foaf:knows"!7!id!hide],
  null as ["foaf:Person"!8!"foaf:name"!element],
  null as ["foaf:Person"!8!"foaf:nick"!element],
  null as ["foaf:mbox"!9!"rdf:resource"],
  null as ["rdfs:seeAlso"!10!"rdf:resource"],
  null as ["foaf:weblog"!11!"rdf:resource"],
  null as ["foaf:homepage"!12!"rdf:resource"]
from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = <UID>
union all
select  2,1,
  null, null, null, null, null,
  BI_BLOG_ID, U_FULL_NAME, U_NAME,
  null, null, null, null,
  null, null,
  null, null,
  null, null, null, null
from BLOG..SYS_BLOG_INFO, "DB"."DBA"."SYS_USERS" where BI_OWNER = U_ID and BI_BLOG_ID = <UID>
union all
select  3,2,
  null, null, null, null, null,
  null, null, null,
  \'mailto:\'||BI_E_MAIL, BI_HOME_PAGE, BI_HOME, BI_HOME || \'gems/rss.xml\',
  null, null,
  null, null,
  null, null, null, null
from BLOG..SYS_BLOG_INFO, "DB"."DBA"."SYS_USERS" where BI_OWNER = U_ID and BI_BLOG_ID = <UID>
union all
select  4,2,
  null, null, null, null, null,
  null, null, null,
  BI_E_MAIL, BI_HOME_PAGE, BI_HOME, BI_HOME || \'gems/rss.xml\',
  null, null,
  null, null,
  null, null, null, null
from BLOG..SYS_BLOG_INFO, "DB"."DBA"."SYS_USERS" where BI_OWNER = U_ID and BI_BLOG_ID = <UID>
union all
select  5,2,
  null, null, null, null, null,
  null, null, null,
  BI_E_MAIL, BI_HOME_PAGE, BI_HOME, BI_HOME || \'gems/rss.xml\',
  null, null,
  null, null,
  null, null, null, null
from BLOG..SYS_BLOG_INFO, "DB"."DBA"."SYS_USERS" where BI_OWNER = U_ID and BI_BLOG_ID = <UID>
union all
select  6,2,
  null, null, null, null, null,
  null, null, null,
  BI_E_MAIL, BI_HOME_PAGE, BI_HOME, BI_HOME || \'gems/rss.xml\',
  null, null,
  null, null,
  null, null, null, null
from BLOG..SYS_BLOG_INFO, "DB"."DBA"."SYS_USERS" where BI_OWNER = U_ID and BI_BLOG_ID = <UID>
union all
select  7,1,
  null,  null, null, null, null,
  null, null, null,
  null, null, null, null,
  \'\', BF_ID,
  null, null,
  null, null, null, null
from BLOG..SYS_BLOG_CONTACTS where BF_BLOG_ID = <UID>
union all
select  8,7,
  null, null, null, null, null,
  null, null, null,
  null, null, null, null,
  \'\', BF_ID,
  BF_NAME, BF_NICK,
  null, null, null, null
from BLOG..SYS_BLOG_CONTACTS where BF_BLOG_ID = <UID>
union all
select  9,8,
  null, null, null, null, null,
  null, null, null,
  null, null, null, null,
  \'\', BF_ID,
  BF_NAME, BF_NICK,
  \'mailto:\'||BF_MBOX, BF_RSS, BF_WEBLOG, BF_HOMEPAGE
from BLOG..SYS_BLOG_CONTACTS where BF_BLOG_ID = <UID>
union all
select  10,8,
  null, null, null, null, null,
  null, null, null,
  null, null, null, null,
  \'\', BF_ID,
  BF_NAME, BF_NICK,
  BF_MBOX, BF_RSS, BF_WEBLOG, BF_HOMEPAGE
from BLOG..SYS_BLOG_CONTACTS where BF_BLOG_ID = <UID>
union all
select  11,8,
  null, null, null, null, null,
  null, null, null,
  null, null, null, null,
  \'\', BF_ID,
  BF_NAME, BF_NICK,
  BF_MBOX, BF_RSS, BF_WEBLOG, BF_HOMEPAGE
from BLOG..SYS_BLOG_CONTACTS where BF_BLOG_ID = <UID>
union all
select  12,8,
  null, null, null, null, null,
  null, null, null,
  null, null, null, null,
  \'\', BF_ID,
  BF_NAME, BF_NICK,
  BF_MBOX, BF_RSS, BF_WEBLOG, BF_HOMEPAGE
from BLOG..SYS_BLOG_CONTACTS where BF_BLOG_ID = <UID>
order by [foaf:knows!7!id!hide]
for xml explicit';
  sql := replace(sql, '<UID>', WS.WS.STR_SQL_APOS(blogid));
  return sql;
}
;


create procedure BLOG2_MAKE_CSS_LPATH(in ppath varchar, in home_path varchar := null, in p_home_path varchar := null) {
  -- if css is not defined at all : use default one /weblog/public/css/default.css
  if(ppath is null or length(ppath) = 0) return '/weblog/public/css/default.css';
  -- important:
  -- if it css defined in home directory : use use relative path like templates/template_name/css_name.css
  -- this is to work in sub domains
  declare dav_home any;
  dav_home := '/DAV/home/';
  if(strstr(ppath, dav_home) = 0)
  {
    return subseq(ppath, length(p_home_path));
  }
  -- if it is system defined css : use absolute path like /weblog/templates/template_name/css_name.css
  return '/weblog/' || subseq(ppath, strstr(ppath, 'templates/'));
}
;

create procedure BLOG2_TEMPLATE_SETTINGS(in blogid any) {
  declare template_name, css_name varchar;
  template_name := NULL;
  css_name := NULL;
  select
    BI_TEMPLATE,
    BI_CSS
  into
    template_name,
    css_name
  from
    BLOG..SYS_BLOG_INFO
  where
    BI_BLOG_ID = blogid;
  if(template_name is NULL or length(template_name) = 0) template_name := registry_get('_blog2_path_') || 'templates/openlink';
  result_names(template_name, css_name);
  result(template_name, css_name);
}
;

blog2_exec_no_error(
  'create procedure view BLOG.DBA.BLOG2_TEMPLATE_SETTINGS as BLOG.DBA.BLOG2_TEMPLATE_SETTINGS(blogid) (template_name varchar, css_name varchar)'
)
;

create procedure BLOG.DBA.BLOG2_GET_BLOG_ID() {
  declare p_path, pos any;
  p_path := http_physical_path();
  pos := strrchr(p_path, '/');
  p_path := subseq(p_path, 0, pos);
  return subseq(p_path, strrchr(p_path, '/') + 1);
}
;

create procedure BLOG.DBA.SYS_BLOG2_EXEC(in params any, in lines any) {
  -- determine blogid
  declare blog_id any;
  declare vd_opts any;

  blog_id := BLOG2_GET_BLOG_ID();
  -- determine page name
  declare page_name varchar;
  page_name := get_keyword('page', params, 'index') || '.vspx';
  if (page_name = '.vspx')
    page_name := 'index.vspx';

  if (0)
  {
  -- disabled
  vd_opts := http_map_get ('options');
  if (isarray (vd_opts) and get_keyword ('noinherit', vd_opts) = 'yes' and get_keyword('page', params) is null)
    {
      declare pat, tag any;
      pat := split_and_decode (http_path (), 0, '\0\0/');
      if (pat[1] = 'tag')
  page_name := 'summary.vspx';
      if (length (pat) > 3)
  {
    tag := pat[3];
    params := vector_concat (params, vector ('tag', tag));
  }
    }
  }

  -- determine home_path, template_path, css_path
  declare home_path, template_path, css_path, p_home_path, _wai_name, _vspx_user varchar;
  declare frozen, _vspx_user_group int;
  _vspx_user_group := -1;
  frozen := 0;
  template_path := NULL;
  css_path := NULL;
  p_home_path := NULL;
  _wai_name := null;
  declare preview_mode, _state, _params any;
whenever not found goto blog_not_found;
  select
    BI_HOME,
    BI_TEMPLATE,
    BI_CSS,
    BI_P_HOME,
    BI_WAI_NAME
  into
    home_path,
    template_path,
    css_path,
    p_home_path,
    _wai_name
  from
    BLOG..SYS_BLOG_INFO
  where
    BI_BLOG_ID = blog_id;
  -- determine preview mode
whenever not found goto session_not_found;
  select
    VS_STATE
  into
    _state
  from
    DB.DBA.VSPX_SESSION
  where
    VS_REALM = cast(get_keyword('realm', params) as varchar) and
    VS_SID = cast(get_keyword('sid', params) as varchar);
  _params := deserialize(cast(_state as varchar));
  _vspx_user := get_keyword('vspx_user', _params);
  _vspx_user_group := (select U_GROUP from DB.DBA.SYS_USERS where U_NAME = _vspx_user);
  preview_mode := get_keyword('template_preview_mode', _params);
  if(preview_mode = '1') {
    template_path := cast(get_keyword('preview_template_name', _params) as varchar);
    css_path := cast(get_keyword('preview_css_name', _params) as varchar);
  }
session_not_found:
  frozen := (select WAI_IS_FROZEN from DB.DBA.WA_INSTANCE where WAI_NAME = _wai_name);
  if (_vspx_user <> 'dba' and _vspx_user <> 'dav' and _vspx_user_group <> 0)
  {
    if (frozen = 1)
    {
      declare redir varchar;
      redir := (select WAI_FREEZE_REDIRECT from DB.DBA.WA_INSTANCE where WAI_NAME = _wai_name);
      if (redir is null or redir = '' or redir = 'default')
      {
        http_request_status ('HTTP/1.1 404 Not found');
        http ( concat ('<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">',
        '<HTML><HEAD>',
        '<TITLE>404 Not Found</TITLE>',
        '</HEAD><BODY>', '<H1>Not Found</H1>',
        'Resource ', http_path (page_name), ' not found.</BODY></HTML>'));
        return;
      }
      else
      {
        http_request_status ('HTTP/1.1 302 Found');
        http_header(sprintf('Location: %s\r\n\r\n', redir));
        return;
      }
    }
  }
  -- determine full template and css path
  css_path := BLOG2_MAKE_CSS_LPATH(css_path, home_path, p_home_path);
  if(template_path is null)
   template_path := registry_get('_blog2_path_') || 'templates/openlink';
  template_path := template_path || '/' || page_name;
  -- add css_name and blog_id as additional parameters
  params := vector_concat(params, vector('css_name', css_path, 'blog_id', blog_id));

  -- directly invoke necessary resource
  declare error_message any;
  error_message := NULL;
  if(not exists(select 1 from WS.WS.SYS_DAV_RES where RES_FULL_PATH = template_path)) {
    -- template disposition doesn't found, use default one
    template_path := registry_get('_blog2_path_') || 'templates/openlink'  || '/' || page_name;
    if(not exists(select 1 from WS.WS.SYS_DAV_RES where RES_FULL_PATH = template_path)) {
      -- page was not found even in default template
      error_message := sprintf('Page: \'%s\' doesn\'t exists even in default template.', page_name);
      goto endproc;
    }
    css_path := BLOG2_MAKE_CSS_LPATH('');
    params := vector_concat(vector('css_name', css_path), params);
  }
  -- whenever not found goto blog_not_found;
  whenever SQLSTATE '*' goto error_handler;
  whenever not found goto error_handler;
  declare home_path2 varchar;
  home_path2 := http_path();
  if (length(home_path2) > 0)
    home_path2 := subseq(home_path2, 0, strrchr(home_path2, '/') + 1);
  if (home_path2 is not null and length(home_path2) > 0)
    home_path := home_path2;

  params := vector_concat(vector('detected_bi_home', home_path), params);
  {
    declare vspx_dbname, vspx_user, signature varchar;
    DB.DBA.vspx_get_user_info (vspx_dbname, vspx_user);
    signature := DB.DBA.vspx_get_signature (vspx_dbname, vspx_user, template_path);
    if (registry_get (template_path) <> signature)
      {
	declare tmpl, xt, xs, ses any;
	whenever not found goto nft;
	select RES_CONTENT into tmpl from WS.WS.SYS_DAV_RES where RES_FULL_PATH = template_path
	    and RES_OWNER <> http_dav_uid ();
        xt := xtree_doc (tmpl, 256, DB.DBA.vspx_base_url (template_path));
	xslt (BLOG2_GET_PPATH_URL ('widgets/blog_template_check.xsl'), xt);
	nft:;
      }
  }
  if (
      page_name in ('index.vspx', 'linkblog.vspx', 'summary.vspx', 'archive.vspx')
      --page_name = 'index.vspx'
      and registry_get ('__blog_template') = 'interpret')
    {
      if (page_name = 'linkblog.vspx')
	params := vector_concat(params, vector ('dataset-n-rows', '25'));
      BLOG.DBA.template_exec (template_path, home_path, params, lines);
    }
  else
    {
      DB.DBA.vspx_dispatch(template_path, home_path, params, lines);
    }
  return 0;
  -- errors handling
blog_not_found:
  error_message := sprintf('Blog ID for home directory: \'%s\' doesn\'t exists.', home_path);
  goto endproc;
error_handler:
  if (__SQL_STATE = 100)
    error_message := 'CAUGHT SQL not found exception.';
  else
    error_message := __SQL_MESSAGE;
endproc:
  if(error_message) {
    http_rewrite();
    template_path := registry_get('_blog2_path_') || 'templates/openlink/errors.vspx';
    params := vector_concat(params, vector('error_message', error_message));
    whenever SQLSTATE '*' goto error_error_handler;
    DB.DBA.vspx_dispatch(template_path, home_path, params, lines);
  }
  return;
error_error_handler:
  http_value(__SQL_MESSAGE, 'pre');
}
;

create procedure BLOG2_ADMIN_USER() returns integer {
  return 1;
}
;

create procedure BLOG2_MENU_TREE() {
  return '<?xml version="1.0" ?>
  <blog_menu_tree>
  <!--
  <node name="Home" id="13" tip="Home" url="index.vspx?page=index"/>
  -->
  <node name="Settings" id="14" tip="Settings">
    <node name="Channel Subscriptions" url="index.vspx?page=channels" id="1400"/>
    <node name="Bridges/Upstreams" url="index.vspx?page=bridge" id="1401"/>
    <node name="Preferences" url="index.vspx?page=ping" id="1402"/>
    <node name="Related Blogs" url="index.vspx?page=community" id="1403"/>
  <!--
    <node name="Member Data" url="index.vspx?page=member_data" id="1404"/>
  -->
    <node name="Membership" url="index.vspx?page=membership" id="1405"/>
    <node name="Templates" url="index.vspx?page=templates" id="1406"/>
    <node name="Moblog Settings" url="index.vspx?page=moblog_msg" id="1407"/>
    <node name="Categories" url="index.vspx?page=category" id="1408"/>
  </node>
  </blog_menu_tree>';
}
;

create procedure BLOG2_NAVIGATION_ROOT(in path varchar) {
  if(path is not null and length(path) > 0) {
    return xpath_eval(sprintf('/blog_menu_tree/%s/*', path), xml_tree_doc(BLOG2_MENU_TREE()), 0);
  }
  else {
    return xpath_eval('/blog_menu_tree/*', xml_tree_doc(BLOG2_MENU_TREE()), 0);
  }
}
;

create procedure BLOG2_NAVIGATION_CHILD(in path varchar, in node any) {
  path := concat(path, '[not @place]');
  return xpath_eval(path, node, 0);
}
;

create procedure BLOG2_GET_PAGE_NAME() {
  declare path, url, elm varchar;
  declare arr any;
  path := http_path();
  arr := split_and_decode(path, 0, '\0\0/');
  elm := arr[length(arr) - 1];
  url := xpath_eval('//*[@url = "'|| elm ||'"]', xml_tree_doc(BLOG2_MENU_TREE()));
  if (url is not null)
    return elm;
  else {
    return '';
  }
}
;

create procedure BLOG2_GET_HOME_DIR (inout home varchar) {

  return home;

-- !!! very bad kludge
  if (is_http_ctx ()) {
    declare p varchar;
    p := http_path ();
    if(concat (home , 'gems/rss.xml') = p)
      return home;
    if(p like '%/gems/rss.xml')
      return substring (p, 1, length (p) - 12);
    else
      return home;
  }
  else
    return home;
}
;

create procedure BLOG2_MAKE_TITLE(inout _content any) {

  declare cont, tit, content varchar;
  declare xt any;

  content := blob_to_string (_content);
  cont := substring (content, 1, 50);

  xt := xml_tree_doc (xml_tree (content, 2));
  tit := xpath_eval ('//*[ text() != "" and not descendant::*[ text() != "" ] ]', xt, 1);
  if (tit is null)
    tit := regexp_match ('<[^<]+[^<]+</[^>]+>', content);
  else {
    declare ss any;
    ss := string_output ();
    http_value (tit, null, ss);
    tit := string_output_string (ss);
  }
  if (tit is null)
    tit := regexp_match ('[^\\r\\n]+', content);
  if (tit is null)
    tit := cont;

  return substring (tit, 1, 512);
}
;


create procedure
BLOG2_GET_TITLE (inout meta any, inout content any)
{
  return BLOG_GET_TITLE (meta, content);
}
;

-- an alias of BLOG_GET_HOST
create procedure BLOG2_GET_HOST()
{
  return BLOG_GET_HOST ();
}
;

create procedure BLOG2_GET_CURRENT_BLOG_HOME(in postfix varchar) {
  declare path, home any;
  path := http_path();
  home := subseq(path, 0, strstr(path, postfix));
  return home;
}
;

create procedure BLOG2_GET_CURRENT_BLOG_ID(in postfix varchar) {
  declare blog_id any;
  blog_id := '';
  blog_id := (select BI_BLOG_ID from BLOG.DBA.SYS_BLOG_INFO where BI_HOME = BLOG2_GET_CURRENT_BLOG_HOME(postfix));
  return blog_id;
}
;

/* blog common VDs */

create procedure DB.DBA.BLOG2_MAKE_RESOURCES(in path varchar)
{
  declare bapi, i, l any;
  declare grant_stmt, gst, gmsg varchar;
  declare def_host, def_port varchar;
  declare ini_host, ini_port, tmp, listen, ext_inet varchar;
  declare cnt_inet int;

  def_host := cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost');
  ini_host := server_http_port ();

  if (def_host is not null)
    {
      if (strchr (def_host, ':') is null)
	{
	  def_port := '80';
	  def_host := def_host || ':' || def_port;
	}
      else
	{
	  tmp := split_and_decode (def_host, 0, '\0\0:');
	  def_port := tmp[1];
	}

      if (strchr (ini_host, ':') is null)
	{
	  ini_port := ini_host;
	  ini_host := null;
	}
      else
	{
	  tmp := split_and_decode (ini_host, 0, '\0\0:');
	  ini_port := tmp[1];
	}

      -- If the default host is not a default http port
      if (ini_port <> def_port)
	{
	  listen := ':'||def_port;

	  cnt_inet := (select count(distinct HP_LISTEN_HOST) from DB.DBA.HTTP_PATH where HP_LISTEN_HOST like '%'||listen);
	  if (cnt_inet = 1)
	    {
	      ext_inet := (select distinct HP_LISTEN_HOST from DB.DBA.HTTP_PATH where HP_LISTEN_HOST like '%'||listen);
	      listen := ext_inet;
	    }

	  if (cnt_inet < 2)
	    {
	  DB.DBA.VHOST_REMOVE (lhost=>listen, vhost=>def_host, lpath=>'/weblog/public');
	  DB.DBA.VHOST_REMOVE (lhost=>listen, vhost=>def_host, lpath=>'/weblog/templates');
	  DB.DBA.VHOST_REMOVE (lhost=>listen, vhost=>def_host, lpath=>'/RPC2');
	  DB.DBA.VHOST_REMOVE (lhost=>listen, vhost=>def_host, lpath=>'/mt-tb');
	  DB.DBA.VHOST_REMOVE (lhost=>listen, vhost=>def_host, lpath=>'/Atom');
	  DB.DBA.VHOST_REMOVE (lhost=>listen, vhost=>def_host, lpath=>'/GData');

	  DB.DBA.VHOST_DEFINE (lhost=>listen, vhost=>def_host, ses_vars=>1, is_dav=>1,
	      lpath=>'/weblog/public', ppath=>path || 'public', vsp_user=>'dba', is_brws=>0);
	  DB.DBA.VHOST_DEFINE (lhost=>listen, vhost=>def_host, ses_vars=>1, is_dav=>1,
	      lpath=>'/weblog/templates', ppath=>path||'templates', vsp_user=>'dba', is_brws=>0);
	  DB.DBA.VHOST_DEFINE(lhost=>listen, vhost=>def_host,
	      lpath=>'/RPC2', ppath=>'/SOAP/', soap_user=>'MT', soap_opts=>vector ('XML-RPC', 'yes'));
	  DB.DBA.VHOST_DEFINE (lhost=>listen, vhost=>def_host,
	      lpath=>'/mt-tb', ppath=>'/SOAP/', soap_user=>'MT', soap_opts=>vector ('XML-RPC', 'yes'));
	  DB.DBA.VHOST_DEFINE (lhost=>listen, vhost=>def_host,
	      lpath=>'/Atom', ppath=>'/SOAP/Http/gdata', soap_user=>'ATOM', opts=>vector ('atom-pub', 1));
	  DB.DBA.VHOST_DEFINE (lhost=>listen, vhost=>def_host,
	      lpath=>'/GData', ppath=>'/SOAP/Http/gdata', soap_user=>'ATOM', opts=>vector ('atom-pub', 0));
	}
	  else
	    {
	      log_message ('The DefaultHost has defined two or more listeners, please configure the default blog virtual directories.');
	    }
	}
    }

  DB.DBA.VHOST_REMOVE (lpath=>'/weblog/public');
  DB.DBA.VHOST_DEFINE (ses_vars=>1, is_dav=>1, lpath=>'/weblog/public', ppath=>path || 'public', vsp_user=>'dba', is_brws=>0);
  DB.DBA.VHOST_REMOVE (lpath=>'/weblog/templates');
  DB.DBA.VHOST_DEFINE (ses_vars=>1, is_dav=>1, lpath=>'/weblog/templates', ppath=>path||'templates', vsp_user=>'dba', is_brws=>0);

  if (not exists (select 1 from "DB"."DBA"."HTTP_PATH" where HP_LPATH = '/RPC2' and HP_HOST = '*ini*'))
    {
      DB.DBA.VHOST_DEFINE(lpath=>'/RPC2', ppath=>'/SOAP/', soap_user=>'MT', soap_opts=>vector ('XML-RPC', 'yes'));
    }
  bapi := "mt.supportedMethods"();
  i := 0; l := length (bapi);
  while (i < l)
    {
      grant_stmt := 'grant execute on BLOG.."' || bapi[i] || '" to "MT"';
      gst := '00000';
      exec (grant_stmt, gst, gmsg);
      i := i + 1;
    }
  if(not exists (select 1 from "DB"."DBA"."HTTP_PATH" where HP_LPATH = '/mt-tb' and HP_HOST = '*ini*'))
    DB.DBA.VHOST_DEFINE (lpath=>'/mt-tb', ppath=>'/SOAP/', soap_user=>'MT', soap_opts=>vector ('XML-RPC', 'yes'));
  if(not exists (select 1 from "DB"."DBA"."HTTP_PATH" where HP_LPATH = '/Atom' and HP_HOST = '*ini*'))
    DB.DBA.VHOST_DEFINE (lpath=>'/Atom', ppath=>'/SOAP/Http/gdata', soap_user=>'ATOM', opts=>vector ('atom-pub', 1));
  if(not exists (select 1 from "DB"."DBA"."HTTP_PATH" where HP_LPATH = '/GData' and HP_HOST = '*ini*'))
    DB.DBA.VHOST_DEFINE (lpath=>'/GData', ppath=>'/SOAP/Http/gdata', soap_user=>'ATOM', opts=>vector ('atom-pub', 0));

  declare vhosts any;
  vhosts := vector ();
  for select distinct HP_HOST, HP_LISTEN_HOST from DB.DBA.HTTP_PATH where  HP_LPATH = '/RPC2' do
    {
      vhosts := vector_concat (vhosts, vector (vector (HP_HOST, HP_LISTEN_HOST)));
    }
  foreach (any vd in vhosts) do
    {
      if(not exists (select 1 from "DB"."DBA"."HTTP_PATH" where HP_LPATH = '/BlogAPI'
	    and HP_HOST = vd[0] and HP_LISTEN_HOST = vd[1]))
	{
	  DB.DBA.VHOST_DEFINE (
	  vhost=>vd[0],
          lhost=>vd[1],
	  lpath=>'/BlogAPI', ppath=>'/SOAP/', soap_user=>'BLOG_API',
	  soap_opts => vector (
	    'Namespace','http://www.openlinksw.com/weblog/api', 'SchemaNS', 'http://www.openlinksw.com/weblog/api',
	    'MethodInSoapAction','only',
	    'ServiceName', 'BlogAPI', 'elementFormDefault', 'qualified', 'Use', 'literal'
	  )
	);
      }
    }

}
;

/* blog generation/update */

create procedure BLOG2_CREATE_DEFAULT_SITE(in folder varchar, in uid int, in blogid varchar,
  in uname varchar, in pwd varchar, in grp any, in home varchar := null)
{

  declare fpath, tit varchar;
  declare blog_home_ver, cur_ver varchar;
  declare dav_pwd any;
  declare path, vd_tags any;
  declare def_host, def_port varchar;
  declare ini_host, ini_port, tmp, listen, vhost varchar;
  declare cnt_inet, ext_inet any;

  def_host := cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost');
  ini_host := server_http_port ();

  listen := '*ini*';
  vhost := '*ini*';

  -- contradict with logic in the ODS
  if (0 and def_host is not null)
    {
      if (strchr (def_host, ':') is null)
	{
	  def_port := '80';
	  def_host := def_host || ':' || def_port;
	}
      else
	{
	  tmp := split_and_decode (def_host, 0, '\0\0:');
	  def_port := tmp[1];
	}

      if (strchr (ini_host, ':') is null)
	{
	  ini_port := ini_host;
	  ini_host := null;
	}
      else
	{
	  tmp := split_and_decode (ini_host, 0, '\0\0:');
	  ini_port := tmp[1];
	}
      if (ini_port <> def_port)
	{
	  listen := ':'||def_port;
	  vhost := def_host;

	  cnt_inet := (select count(distinct HP_LISTEN_HOST) from DB.DBA.HTTP_PATH where HP_LISTEN_HOST like '%'||listen);
	  if (cnt_inet = 1)
	    {
	      ext_inet := (select distinct HP_LISTEN_HOST from DB.DBA.HTTP_PATH where HP_LISTEN_HOST like '%'||listen);
	      listen := ext_inet;
	    }
	  else
	    {
	      listen := '*ini*';
	      vhost := '*ini*';
	    }
	}
    }

  path := registry_get('_blog2_path_');
  if (uname is null)
    uname := 'dav';

  dav_pwd := (select pwd_magic_calc (U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = http_dav_uid ());
  cur_ver := registry_get ('Weblog_version');
  blog_home_ver := DB.DBA.DAV_PROP_GET(folder, 'Weblog version', 'dav', dav_pwd);
  if(isstring(blog_home_ver) and blog_home_ver <> '') {
    return;
  }

  declare _U_FULL_NAME, _U_E_MAIL, _U_NAME varchar;
  select U_FULL_NAME, U_E_MAIL, U_NAME into _U_FULL_NAME, _U_E_MAIL, _U_NAME from DB.DBA.SYS_USERS where U_ID = uid;
  if (length (_U_FULL_NAME))
    tit := _U_FULL_NAME || '\'s Weblog';
  else
    tit := _U_NAME || '\'s Weblog';

  if (blogid is null)
  {
    blogid := cast(uid as varchar);
  }
  if (home is null)
  {
    home := '/weblog/' || uname || '/' || blogid;
  }
  vd_tags := '/tag/'|| blogid;

  -- when we upgrade some old blog keep it's options as is
  if (exists (select 1 from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = blogid))
    {
      update BLOG..SYS_BLOG_INFO set
	  BI_INCLUSION = 1,
		       BI_OWNER = uid,
		       BI_HOME = home || '/',
		       BI_P_HOME = folder,
		       BI_HOME_PAGE = DB.DBA.USER_GET_OPTION(_U_NAME, 'URL')
			   where BI_BLOG_ID = blogid;
    }
  else
    {
      insert replacing BLOG..SYS_BLOG_INFO (BI_INCLUSION, BI_BLOG_ID, BI_OWNER, BI_TITLE, BI_HOME,
	  BI_P_HOME, BI_E_MAIL, BI_HOME_PAGE)
	  values(1, blogid, uid, tit, home || '/', folder, _U_E_MAIL,
	      DB.DBA.USER_GET_OPTION(_U_NAME, 'URL'));

       declare opts any;
       opts := BLOG2_SET_OPTION('ShowName', opts, 1);
       opts := BLOG2_SET_OPTION('ShowPhoto', opts, 1);
       opts := BLOG2_SET_OPTION('ShowAudio', opts, 1);
       opts := BLOG2_SET_OPTION('ShowEmail', opts, 1);
       opts := BLOG2_SET_OPTION('ShowAim', opts, 1);
       opts := BLOG2_SET_OPTION('ShowIcq', opts, 1);
       opts := BLOG2_SET_OPTION('ShowYahoo', opts, 1);
       opts := BLOG2_SET_OPTION('ShowMsn', opts, 1);
       opts := BLOG2_SET_OPTION('ShowWeb', opts, 1);
       opts := BLOG2_SET_OPTION('ShowLoc', opts, 1);
       opts := BLOG2_SET_OPTION('ShowBio', opts, 1);
       opts := BLOG2_SET_OPTION('ShowInt', opts, 1);
       opts := BLOG2_SET_OPTION('ShowFav', opts, 1);
       opts := BLOG2_SET_OPTION('ShowAmazon', opts, 1);
       opts := BLOG2_SET_OPTION('ShowEbay', opts, 1);
       opts := BLOG2_SET_OPTION('ShowAss', opts, 1);
       opts := BLOG2_SET_OPTION('ShowFish', opts, 1);
       update BLOG..SYS_BLOG_INFO set BI_OPTIONS = serialize(opts) where BI_BLOG_ID = blogid;
    }

  -- index.vspx
  declare content any;
  DB.DBA.DAV_MAKE_DIR(folder, uid, grp, '110110100N');
  DB.DBA.DAV_MAKE_DIR(folder || 'images/', uid, grp, '110110100N');
  DB.DBA.DAV_MAKE_DIR(folder || 'audio/', uid, grp, '110110100N');
  DB.DBA.DAV_MAKE_DIR(folder || 'templates/', uid, grp, '110110100N');
  -- execution dir with write access for dav only
  DB.DBA.DAV_MAKE_DIR(folder, uid, null, '110110100N');
  fpath := folder || 'index.vspx';
  content := (select RES_CONTENT from WS.WS.SYS_DAV_RES where RES_FULL_PATH = path || 'index.vspx');
  DB.DBA.DAV_RES_UPLOAD(fpath, content, 'text/html', '111101101N', 'dav', 'administrators', 'dav', dav_pwd);

  -- This should be really in ODS
  DB.DBA.VHOST_REMOVE(vhost=>vhost, lhost=>listen, lpath=>home);
  DB.DBA.VHOST_DEFINE(
               vhost=>vhost,
	       lhost=>listen,
               ses_vars=>1,
               is_dav=>1,
               lpath=>home,
               ppath=>folder,
               vsp_user=>'dba',
               is_brws=>0,
               def_page=>'index.vspx',
               ppr_fn=>'BLOG.DBA.BLOG2_RSS2WML_PP'
              );

  -- default gems are SQLX
  BLOG_SET_SQLX_GEMS (blogid, folder, uid, grp);
}
;

create procedure BLOG_SET_SQL_XML_GEMS (in blogid any, in folder any, in uid int, in grp any)
{
  declare perm_r, perm_e, atomxsl varchar;
  declare path, content any;
  atomxsl := BLOG_GET_ATOM_XSL ();

  if (grp is not null) {
    perm_r := '110110100N';
    perm_e := '111101101N';
    --DB.DBA.DAV_MAKE_DIR (folder || 'gems/', http_dav_uid (), grp, perm_r);
    DB.DBA.DAV_MAKE_DIR (folder || 'gems/', uid, grp, perm_r);
  }
  else {
    perm_r := '110100100N';
    perm_e := '111101101N';
    --DB.DBA.DAV_MAKE_DIR (folder || 'gems/', http_dav_uid (), grp, perm_r);
    DB.DBA.DAV_MAKE_DIR (folder || 'gems/', uid, grp, perm_r);
  }

  -- RSS
  path := folder || 'gems/rss.xml';
  content := '';
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'sql/xml', perm_r, http_dav_uid (), null, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql', BLOG2_HOME_GET_RSS(blogid), 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RSS based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  -- RSS with USM support
  path := folder || 'gems/rss-usm.xml';
  content := BLOG2_HOME_GET_RSS_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-mime-type', 'application/rss+xml', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RSS based XML document generated By OpenLink Virtuoso', 'dav', null, 0);


  -- RSS 2.0 with iTunes
  path := folder || 'gems/podcasts.xml';
  content := BLOG2_HOME_GET_PODCASTS_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RSS based XML document generated By OpenLink Virtuoso', 'dav', null, 0);

  -- RSS 2.0 with Yahoo Media
  path := folder || 'gems/mrss.xml';
  content := BLOG2_HOME_GET_MRSS_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RSS based XML document generated By OpenLink Virtuoso', 'dav', null, 0);

  -- RSS 1.1
  path := folder || 'gems/rss11.xml';
  content := '';
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'sql/xml', perm_r, http_dav_uid (), null, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-stylesheet', BLOG2_GET_PPATH_URL ('widgets/rss11.xsl'), 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql', BLOG2_HOME_GET_RSS(blogid), 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  -- RDF
  path := folder || 'gems/index.rdf';
  content := '';
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'sql/xml', perm_r, http_dav_uid (), null, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-stylesheet', BLOG2_GET_PPATH_URL ('widgets/rss2rdf.xsl'), 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql', BLOG2_HOME_GET_RSS(blogid), 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RDF based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  -- Linkblog RSS
  path := folder || 'gems/rss-linkblog.xml';
  content := '';
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'sql/xml', perm_r, http_dav_uid (), null, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql', BLOG2_HOME_GET_LINKRSS(blogid), 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RSS based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  -- Linkblog RDF
  path := folder || 'gems/index-linkblog.rdf';
  content := '';
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'sql/xml', perm_r, http_dav_uid (), null, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-stylesheet', BLOG2_GET_PPATH_URL ('widgets/rss2rdf.xsl'), 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql', BLOG2_HOME_GET_LINKRSS(blogid), 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RDF based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  -- Linkblog ATOM
  path := folder || 'gems/atom-linkblog.xml';
  content := '';
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'sql/xml', perm_r, http_dav_uid (), null, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-stylesheet', BLOG2_GET_PPATH_URL ('widgets/' || atomxsl), 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql', BLOG2_HOME_GET_LINKRSS(blogid), 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'ATOM based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  -- ATOM
  path := folder || 'gems/atom.xml';
  content := '';
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'sql/xml', perm_r, http_dav_uid(), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-stylesheet', BLOG2_GET_PPATH_URL ('widgets/'||atomxsl), 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql', BLOG2_HOME_GET_RSS(blogid), 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'ATOM based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  -- OCS
  path := folder || 'gems/index.ocs';
  content := '';
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'sql/xml', perm_r, http_dav_uid (), null, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql', BLOG2_HOME_GET_OPML (blogid), 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-stylesheet', BLOG2_GET_PPATH_URL ('widgets/opml2ocs.xsl'), 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'OCS based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  -- OPML
  path := folder || 'gems/index.opml';
  content := '';
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'sql/xml', perm_r, http_dav_uid (), null, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql', BLOG2_HOME_GET_OPML(blogid), 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'OPML based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  -- RSD
  path := folder || 'gems/rsd.xml';
  content := '';
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'sql/xml', perm_r, http_dav_uid (), null, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql', BLOG2_GENERATE_RSD_SQL(blogid), 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-description',
  'RSD based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  -- FOAF
  path := folder || 'gems/blogroll.rdf';
  content := BLOG2_HOME_GET_FOAF_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'FOAF based XML document generated By OpenLink Virtuoso', 'dav', null, 0);

  -- RSSCOMMENT
  path := folder || 'gems/rsscomment.xml';
  content := BLOG2_HOME_GET_RSSCOMMENT();
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RSS based XML document generated By OpenLink Virtuoso', null, null, 0, 0, 1);

  -- ocs.xml
  path := folder || 'gems/ocs.xml';
  content := BLOG2_HOME_GENERATE_OCS_XML(blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'OCS based XML document generated By OpenLink Virtuoso', null, null, 0, 0, 1);

  -- opml.xml
  path := folder || 'gems/opml.xml';
  content := BLOG2_HOME_GENERATE_OPML_XML(blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'OPML based XML document generated By OpenLink Virtuoso', null, null, 0, 0, 1);

  -- xoxo.xml
  path := folder || 'gems/xoxo.xml';
  content := BLOG2_HOME_GENERATE_XOXO (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'XOXO based XML document generated By OpenLink Virtuoso', null, null, 0);

  path := folder || 'gems/rss_cat.xml';
  content := BLOG2_HOME_GENERATE_RSS_CAT_XML(blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RSS based XML document generated By OpenLink Virtuoso', null, null, 0, 0, 1);

  -- rsssearch.xsl
  path := folder || 'gems/rsssearch.xml';
  content := BLOG2_RSSSEARCH_XML();
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RSS XML document generated By OpenLink Virtuoso', null, null, 0, 0, 1);

  -- XBEL
  path := folder || 'gems/xbel.xml';
  content := BLOG2_HOME_GET_XBEL_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'XBEL based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  -- Summary XBEL
  path := folder || 'gems/xbel-summary.xml';
  content := BLOG2_HOME_GET_XBEL_SUMMARY_XML (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'XBEL based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  -- Summary OPML
  path := folder || 'gems/opml-summary.xml';
  content := BLOG2_HOME_GET_OPML_SUMMARY_XML (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'OPML based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  -- Summary OCS
  path := folder || 'gems/ocs-summary.xml';
  content := BLOG2_HOME_GET_OCS_SUMMARY_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'OCS based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  -- Linkblog XBEL
  path := folder || 'gems/xbel-linkblog.xml';
  content := BLOG2_HOME_GET_XBEL_LINKBLOG_XML (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'XBEL based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  path := folder || 'gems/foaf-members.xml';
  content := BLOG2_FOAF_MEMBERS_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'FOAF based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  path := folder || 'gems/opml-members.xml';
  content := BLOG2_HOME_GET_OPML_MEMBER_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'OPML based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  path := folder || 'gems/ocs-members.xml';
  content := BLOG2_HOME_GET_OCS_MEMBER_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'OCS based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  -- Archive GEMS
  path := folder || 'gems/rss_cat_arch.xml';
  content := BLOG2_HOME_GENERATE_RSS_ARCH_CAT_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RSS based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  path := folder || 'gems/rss_date_arch.xml';
  content := BLOG2_HOME_GENERATE_RSS_ARCH_DATE_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RSS based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  path := folder || 'gems/atom_cat_arch.xml';
  content := BLOG2_HOME_GENERATE_ATOM_ARCH_CAT_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/atom_date_arch.xml';
  content := BLOG2_HOME_GENERATE_ATOM_ARCH_DATE_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/rdf_cat_arch.xml';
  content := BLOG2_HOME_GENERATE_RDF_ARCH_CAT_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/rdf_date_arch.xml';
  content := BLOG2_HOME_GENERATE_RDF_ARCH_DATE_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/opml_date_arch.xml';
  content := BLOG2_HOME_GENERATE_OPML_ARCH_DATE_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/ocs_date_arch.xml';
  content := BLOG2_HOME_GENERATE_OCS_ARCH_DATE_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/opml_year_arch.xml';
  content := BLOG2_HOME_GENERATE_OPML_ARCH_YEAR_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/ocs_year_arch.xml';
  content := BLOG2_HOME_GENERATE_OCS_ARCH_YEAR_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/opml_cat_arch.xml';
  content := BLOG2_HOME_GENERATE_OPML_ARCH_CAT_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/ocs_cat_arch.xml';
  content := BLOG2_HOME_GENERATE_OCS_ARCH_CAT_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/rss_tag_arch.xml';
  content := BLOG2_HOME_GENERATE_RSS_ARCH_TAG_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RSS based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  path := folder || 'gems/atom_tag_arch.xml';
  content := BLOG2_HOME_GENERATE_ATOM_ARCH_TAG_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/rdf_tag_arch.xml';
  content := BLOG2_HOME_GENERATE_RDF_ARCH_TAG_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/opml_tag_arch.xml';
  content := BLOG2_HOME_GENERATE_OPML_ARCH_TAG_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/ocs_tag_arch.xml';
  content := BLOG2_HOME_GENERATE_OCS_ARCH_TAG_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

}
;

create procedure BLOG_SET_SQLX_GEMS (in blogid any, in folder any, in uid int, in grp any)
{
  declare perm_r, perm_e varchar;
  declare path, content any;

  if (grp is not null) {
    perm_r := '110110100N';
    perm_e := '111101101N';
    DB.DBA.DAV_MAKE_DIR (folder || 'gems/', http_dav_uid (), grp, perm_r);
  }
  else {
    perm_r := '110100100N';
    perm_e := '111101101N';
    DB.DBA.DAV_MAKE_DIR (folder || 'gems/', http_dav_uid (), grp, perm_r);
  }

  -- RSS 2.0
  path := folder || 'gems/rss.xml';
  content := BLOG2_HOME_GET_RSS_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RSS based XML document generated By OpenLink Virtuoso', 'dav', null, 0);

  -- RSS with USM support
  path := folder || 'gems/rss-usm.xml';
  content := BLOG2_HOME_GET_RSS_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-mime-type', 'application/rss+xml', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RSS based XML document generated By OpenLink Virtuoso', 'dav', null, 0);

  -- RSS 2.0 with iTunes
  path := folder || 'gems/podcasts.xml';
  content := BLOG2_HOME_GET_PODCASTS_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RSS based XML document generated By OpenLink Virtuoso', 'dav', null, 0);

  -- RSS 2.0 with Yahoo Media
  path := folder || 'gems/mrss.xml';
  content := BLOG2_HOME_GET_MRSS_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RSS based XML document generated By OpenLink Virtuoso', 'dav', null, 0);

  -- RSS 1.1
  path := folder || 'gems/rss11.xml';
  content := BLOG2_HOME_GET_RSS11_SQLX (blogid);
  DB.DBA.DAV_PROP_REMOVE_INT (path, 'xml-stylesheet', null, null, 0, 0, 1);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RDF based XML document generated By OpenLink Virtuoso', 'dav', null, 0);


  -- RDF
  path := folder || 'gems/index.rdf';
  content := BLOG2_HOME_GET_RDF_SQLX (blogid);
  DB.DBA.DAV_PROP_REMOVE_INT (path, 'xml-stylesheet', null, null, 0, 0, 1);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RDF based XML document generated By OpenLink Virtuoso', 'dav', null, 0);

  -- Linkblog RSS 2.0
  path := folder || 'gems/rss-linkblog.xml';
  content := BLOG2_HOME_GET_LINKRSS_SQLX(blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RSS based XML document generated By OpenLink Virtuoso', 'dav', null, 0);

  -- Linkblog RDF
  path := folder || 'gems/index-linkblog.rdf';
  content := BLOG2_HOME_GET_LINKRDF_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-stylesheet', BLOG2_GET_PPATH_URL ('widgets/rss2rdf.xsl'), 'dav', null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RDF based XML document generated By OpenLink Virtuoso', 'dav', null, 0);

  -- Linkblog ATOM 0.3
  path := folder || 'gems/atom-linkblog.xml';
  content := BLOG2_HOME_GET_LINKATOM (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'ATOM based XML document generated By OpenLink Virtuoso', 'dav', null, 0);

  -- ATOM 0.3
  path := folder || 'gems/atom.xml';
  content := BLOG2_HOME_GET_ATOM_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'ATOM based XML document generated By OpenLink Virtuoso', 'dav', null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-mime-type', 'application/atom+xml', null, null, 0);

  -- OCS
  path := folder || 'gems/index.ocs';
  content := BLOG2_HOME_GET_OCS_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'OCS based XML document generated By OpenLink Virtuoso', 'dav', null, 0);

  -- OPML
  path := folder || 'gems/index.opml';
  content := BLOG2_HOME_GET_OPML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'OPML based XML document generated By OpenLink Virtuoso', 'dav', null, 0);

  -- RSD
  path := folder || 'gems/rsd.xml';
  content := BLOG2_GENERATE_RSD_SQL_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-description',
  'RSD based XML document generated By OpenLink Virtuoso', 'dav', null, 0);

  -- FOAF
  path := folder || 'gems/blogroll.rdf';
  content := BLOG2_HOME_GET_FOAF_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'FOAF based XML document generated By OpenLink Virtuoso', 'dav', null, 0);

  -- RSSCOMMENT 2.0
  path := folder || 'gems/rsscomment.xml';
  content := BLOG2_HOME_GET_RSSCOMMENT_SQLX();
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RSS based XML document generated By OpenLink Virtuoso', null, null, 0);

  -- ocs.xml
  path := folder || 'gems/ocs.xml';
  content := BLOG2_HOME_GENERATE_OCS_XML_SQLX(blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'OCS based XML document generated By OpenLink Virtuoso', null, null, 0);

  -- opml.xml
  path := folder || 'gems/opml.xml';
  content := BLOG2_HOME_GENERATE_OPML_XML_SQLX(blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'OPML based XML document generated By OpenLink Virtuoso', null, null, 0);

  -- xoxo.xml
  path := folder || 'gems/xoxo.xml';
  content := BLOG2_HOME_GENERATE_XOXO (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'XOXO based XML document generated By OpenLink Virtuoso', null, null, 0);

  -- rss_cat.xml 2.0
  path := folder || 'gems/rss_cat.xml';
  content := BLOG2_HOME_GENERATE_RSS_CAT_XML_SQLX(blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RSS based XML document generated By OpenLink Virtuoso', null, null, 0);

  -- rsssearch.xsl 2.0
  path := folder || 'gems/rsssearch.xml';
  content := BLOG2_RSSSEARCH_XML_SQLX();
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, 'dav', grp, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RSS XML document generated By OpenLink Virtuoso', null, null, 0);

  -- XBEL
  path := folder || 'gems/xbel.xml';
  content := BLOG2_HOME_GET_XBEL_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'XBEL based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  -- Summary XBEL
  path := folder || 'gems/xbel-summary.xml';
  content := BLOG2_HOME_GET_XBEL_SUMMARY_XML (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'XBEL based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  -- Summary OPML
  path := folder || 'gems/opml-summary.xml';
  content := BLOG2_HOME_GET_OPML_SUMMARY_XML (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'OPML based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  -- Summary OCS
  path := folder || 'gems/ocs-summary.xml';
  content := BLOG2_HOME_GET_OCS_SUMMARY_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'OCS based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  -- Linkblog XBEL
  path := folder || 'gems/xbel-linkblog.xml';
  content := BLOG2_HOME_GET_XBEL_LINKBLOG_XML (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'XBEL based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  -- community FOAF
  path := folder || 'gems/foaf-members.xml';
  content := BLOG2_FOAF_MEMBERS_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'FOAF based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  path := folder || 'gems/opml-members.xml';
  content := BLOG2_HOME_GET_OPML_MEMBER_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'OPML based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  path := folder || 'gems/ocs-members.xml';
  content := BLOG2_HOME_GET_OCS_MEMBER_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'OCS based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  -- Archive GEMS 2.0
  path := folder || 'gems/rss_cat_arch.xml';
  content := BLOG2_HOME_GENERATE_RSS_ARCH_CAT_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RSS based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  -- RSS 2.0

  path := folder || 'gems/rss_date_arch.xml';
  content := BLOG2_HOME_GENERATE_RSS_ARCH_DATE_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RSS based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  -- ATOM 1.0
  path := folder || 'gems/atom_cat_arch.xml';
  content := BLOG2_HOME_GENERATE_ATOM_ARCH_CAT_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/atom_date_arch.xml';
  content := BLOG2_HOME_GENERATE_ATOM_ARCH_DATE_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  -- RDF
  path := folder || 'gems/rdf_cat_arch.xml';
  content := BLOG2_HOME_GENERATE_RDF_ARCH_CAT_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/rdf_date_arch.xml';
  content := BLOG2_HOME_GENERATE_RDF_ARCH_DATE_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/opml_date_arch.xml';
  content := BLOG2_HOME_GENERATE_OPML_ARCH_DATE_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/ocs_date_arch.xml';
  content := BLOG2_HOME_GENERATE_OCS_ARCH_DATE_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/opml_year_arch.xml';
  content := BLOG2_HOME_GENERATE_OPML_ARCH_YEAR_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/ocs_year_arch.xml';
  content := BLOG2_HOME_GENERATE_OCS_ARCH_YEAR_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/opml_cat_arch.xml';
  content := BLOG2_HOME_GENERATE_OPML_ARCH_CAT_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/ocs_cat_arch.xml';
  content := BLOG2_HOME_GENERATE_OCS_ARCH_CAT_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/rss_tag_arch.xml';
  content := BLOG2_HOME_GENERATE_RSS_ARCH_TAG_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-sql-description',
  'RSS based XML document generated By OpenLink Virtuoso', 'dav', null, 0, 0, 1);

  path := folder || 'gems/atom_tag_arch.xml';
  content := BLOG2_HOME_GENERATE_ATOM_ARCH_TAG_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/rdf_tag_arch.xml';
  content := BLOG2_HOME_GENERATE_RDF_ARCH_TAG_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/opml_tag_arch.xml';
  content := BLOG2_HOME_GENERATE_OPML_ARCH_TAG_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);

  path := folder || 'gems/ocs_tag_arch.xml';
  content := BLOG2_HOME_GENERATE_OCS_ARCH_TAG_XML_SQLX (blogid);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path, content, 'text/xml', perm_e, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.BLOG2_DAV_PROP_SET(path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.BLOG2_DAV_PROP_SET (path, 'xml-sql-encoding', 'utf-8', null, null, 0, 0, 1);
}
;

create procedure BLOG_GET_ATOM_XSL ()
{
  declare ver any;
  ver := connection_get ('BLOG_ATOM_VERSION');
  if (ver = '0.3')
    return 'rss2atom03.xsl';
  return 'rss2atom.xsl';
};

create procedure BLOG_SET_GEMS (in blogid any, in tp any := 'SQLX', in atom_ver varchar := '1.0')
{
  declare dav_pwd, nam, uid, folder any;
  declare exit handler for not found signal ('22023', 'No such blog');
  dav_pwd := (select pwd_magic_calc (U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = http_dav_uid ());
  select U_NAME, U_ID into nam, uid from DB.DBA.SYS_USERS, SYS_BLOG_INFO where BI_OWNER = U_ID and BI_BLOG_ID = blogid;
  folder := '/DAV/home/' || nam || '/' || blogid || '/';

  connection_set ('BLOG_ATOM_VERSION', atom_ver);

  if (tp = 'SQL-XML')
    BLOG_SET_SQL_XML_GEMS (blogid, folder, uid, null);
  else if (tp = 'SQLX')
    BLOG_SET_SQLX_GEMS (blogid, folder, uid, null);

  connection_set ('BLOG_ATOM_VERSION', NULL);
}
;



create procedure BLOG2_HOME_CREATE(in uid int, in blogid varchar, in folder varchar := null, in home varchar := null)
{
  declare nam, pwd, grp, grpn any;
  whenever not found goto ef;
  select U_NAME, pwd_magic_calc (U_NAME, U_PASSWORD, 1), U_IS_ROLE into nam, pwd, grp
  from "DB"."DBA"."SYS_USERS" where U_ID = uid;
  if (folder is null) {
    folder := '/DAV/home/' || nam || '/' || blogid || '/';
  }
  grpn := null;
  if(grp) {
    grpn := nam;
    nam := null;
  }
  else
    grpn := http_dav_uid () + 1;
  BLOG2_CREATE_DEFAULT_SITE(folder, uid, blogid, nam, pwd, grpn, home);
ef:;
  return;
}
;

/* gems upgrade */

create procedure BLOG2_UPGRADE_BLOG2_GEMS (in folder varchar, in blogid any, in dav_pwd any, in opts any, in uid any)
{
  declare perm_e, content, path any;
  if (not isstring (folder))
    {
      return;
    }
  if (isarray (opts) and get_keyword('FeedGen', opts, 'SQLX') = 'SQL-XML')
    {
      BLOG_SET_GEMS (blogid, 'SQL-XML');
    }
  else
    {
      BLOG_SET_GEMS (blogid, 'SQLX');
    }
}
;

create procedure BLOG2_BLOG_IS_ATTACHED(in _m_blog_id varchar, in _c_blog_id varchar) {
  for select BA_C_BLOG_ID from BLOG.DBA.SYS_BLOG_ATTACHES where BA_M_BLOG_ID = _c_blog_id do {
    if(BA_C_BLOG_ID = _m_blog_id) {
      return 1;
    }
    else {
      return BLOG2_BLOG_IS_ATTACHED(_m_blog_id, BA_C_BLOG_ID);
    }
  }
  return 0;
}
;

create procedure BLOG2_BLOG_IS_UPSTREAMED(in _m_blog_id varchar, in _c_blog_id varchar) {
  if(_m_blog_id = _c_blog_id) return 1;
  for select R_DESTINATION_ID from SYS_ROUTING where R_ITEM_ID = _c_blog_id do {
    if(R_DESTINATION_ID = _m_blog_id) {
      return 1;
    }
    else {
      return BLOG2_BLOG_IS_UPSTREAMED(_m_blog_id, R_DESTINATION_ID);
    }
  }
  return 0;
}
;

create procedure BLOG2_BLOG_ATTACH(in _m_blog_id varchar, in _c_blog_id varchar) {
  -- check to avoid circular attachment
  if (BLOG2_BLOG_IS_ATTACHED(_m_blog_id, _c_blog_id)) return 0;
  insert into BLOG.DBA.SYS_BLOG_ATTACHES (BA_M_BLOG_ID, BA_C_BLOG_ID) values(_m_blog_id, _c_blog_id);
  update BLOG.DBA.SYS_BLOG_INFO set BI_HAVE_COMUNITY_BLOG = 1 where BI_BLOG_ID = _m_blog_id;
  return 1;
}
;

create procedure BLOG2_DATE_FOR_HUMANS(in d datetime) {

  declare date_part varchar;
  declare time_part varchar;

  declare min_diff integer;
  declare day_diff integer;


  day_diff := datediff ('day', d, now ());

  if (day_diff < 1)
    {
      min_diff := datediff ('minute', d, now ());

      if (min_diff = 1)
        {
          return ('a minute ago');
  }
      else if (min_diff < 1)
        {
          return ('less than a minute ago');
        }
      else if (min_diff < 60)
  {
    return (sprintf ('%d minutes ago', min_diff));
  }
      else return (sprintf ('today at %d:%02d', hour (d), minute (d)));
    }

  if (day_diff < 2)
    {
      return (sprintf ('yesterday at %d:%02d', hour (d), minute (d)));
    }

  return (sprintf ('%d/%d/%d %d:%02d', year (d), month (d), dayofmonth (d), hour (d), minute (d)));
}
;

create procedure BLOG2_POST_RENDER (inout cnt any, in filter varchar := null, in owner int := null,
		in opts1 any := null, in active int := 1, in media int := 0)
{
  declare ss any;
  declare xt any;
  declare davacc, opts any;
  declare add_table int;

  -- no filter and no need to execute the content
  if (active = 0 and length (filter) = 0)
    return cnt;

  if (not isarray (opts1))
    opts := vector ('media', media);
  else
    opts := vector_concat (opts1, vector ('media', media));

  add_table := 0;
  davacc := connection_get ('DAVUserID');
  ss := string_output ();
  xt := xml_tree_doc (xml_tree (cnt, 2, '', 'UTF-8'));
  if (filter = '*default*')
    xt := xslt (BLOG2_GET_PPATH_URL ('widgets/blog_tidy.xsl'), xt, opts);
  else if (isstring (filter) and filter <> '' and xslt_is_sheet (filter))
    xt := xslt (filter, xt);

--  This is already done in the insert trigger
--  if (xpath_eval ('//tr[not ancestor::table]|//td[not ancestor::table]', xt) is not null)
--    add_table := 1;

  xml_tree_doc_set_output (xt, 'xhtml');
  xml_tree_doc_set_ns_output (xt, 1);
  if (is_http_ctx ())
    {
      set http_charset='UTF-8';
    }
  if (owner is null or active = 0)
    {
      http_value (xt, null, ss);
    }
  else
   {
     declare dummy int;
     declare exit handler for sqlexception, not found
       {
	 http_value (xt, null, ss);
	 goto endprint;
       };

     select set_user_id (U_NAME, 1) into dummy from "DB"."DBA"."SYS_USERS" where U_ID = owner;
     connection_set ('DAVUserID', owner);
     xml_template (xt, null, ss);
   }
endprint:
  connection_set ('DAVUserID', davacc);
-- see above
--  if (add_table)
--    return '<table>'||string_output_string (ss)||'</table>';
--  else
    return string_output_string(ss);
}
;

create procedure BLOG2_BLOG_IT(in blogid any, in sid any, in realm any, in user_id any, in subj any, in mbid integer, in mset any default '') {
  declare img_path varchar;
  declare content, file, mime, tmp varchar;
  declare i, l int;
  declare base, bi_home2, bi_phome2, path, mm_id2, b_own any;
  declare m_cont any;
  declare thumb_path varchar;
  declare res "MTWeblogPost";

  mset := deserialize(decode_base64(mset));
  if (not isarray (mset))
    mset := vector (mbid);
  tmp := '';

  whenever not found goto nfbm;
  select BI_HOME, BI_P_HOME, BI_OWNER into bi_home2, bi_phome2, b_own from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = blogid;
  i := 0;
  l := length (mset);

  while (i < l)
    {
      select MA_M_ID, MA_NAME, MA_MIME, MA_CONTENT into mm_id2, file, mime, m_cont from "DB"."DBA"."MAIL_ATTACHMENT"
	  where MA_ID = mset[i] and MA_BLOG_ID = blogid;

      path := bi_home2 || 'media/' || file;
      DB.DBA.DAV_MAKE_DIR(bi_phome2 || 'media/thumbnail/', b_own, http_dav_uid()+1, '110110100N');
      -- create message body
      res := new "MTWeblogPost" ();
      res.postid := cast (sequence_next ('blogger.postid') as varchar);
      res.title := coalesce ((select MM_SUBJ from "DB"."DBA"."MAIL_MESSAGE", DB.DBA.SYS_USERS
      where U_NAME = MM_OWN and U_ID = user_id and MM_ID = mm_id2), '[no title]');
      res.author := (select MM_FROM from "DB"."DBA"."MAIL_MESSAGE", DB.DBA.SYS_USERS
      where U_NAME = MM_OWN and U_ID = user_id and MM_ID = mm_id2);
      res.userid := res.author;
      res.dateCreated := now ();
      if (mime like 'image/%')
	{
	  declare thumb, path1, rc any;
	  thumb := DB.DBA.BLOG2_MAKE_THUMB (m_cont, mime, 200, 0);
	  path1 := path;
	  if (thumb is not null)
	    {
	      path1 := bi_phome2 || 'media/thumbnail/' || file;
	      rc := DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path1, thumb, '', '110100100N', b_own, null, null, null, 0);
	      path1 := bi_home2 || 'media/thumbnail/' || file;
	    }
	  content := sprintf ('<div><a href="http://%s%V">', BLOG_GET_HOST(), path) ||
	  sprintf ('<img src="http://%s%V" width="200" border="0" />', BLOG_GET_HOST(), path1) ||
	  '</a></div>';
	}
      else
	{
	  content := sprintf ('<div><a href="%V" >', path) || res.title || '</a></div>';
	}

      DB.DBA.DAV_RES_UPLOAD_STRSES_INT (bi_phome2||'media/' || file, m_cont, '', '110100100N', b_own, null, null, null, 0);
      insert into BLOG..SYS_BLOGS (B_APPKEY, B_BLOG_ID, B_CONTENT, B_POST_ID, B_USER_ID, B_TS, B_META, B_STATE, B_TITLE)
	  values ('', blogid, content, res.postid, user_id, now(), res, 2, res.title);
      i := i + 1;
    }
  nfbm:;
  return;
}
;

create procedure BLOG2_SET_OPTION (in name varchar, in opts any, in value any)
{
  if (__tag (opts) <> 193)
    opts := vector ();
  if (position (name, opts)) {
    aset (opts, position (name, opts), value);
  }
  else {
    opts := vector_concat (opts, vector (name, value));
  }
  return opts;
}
;

create procedure BLOG2_VIRTUAL_REPLACING(in string any, in what any, in repl_with any) {
  return replace(blob_to_string(string), what, '<span class="replacing">' || repl_with || ' [ Old value: ' || what || ']</span>');
}
;

create trigger SYS_BLOG2_INFO_D before delete on BLOG..SYS_BLOG_INFO
{
  delete from BLOG.DBA.SYS_BLOG_ATTACHES where BA_M_BLOG_ID = BI_BLOG_ID;
  delete from BLOG.DBA.SYS_BLOG_ATTACHES where BA_C_BLOG_ID = BI_BLOG_ID;
  delete from BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY where BCC_BLOG_ID = BI_BLOG_ID;
  for select TT_ID from BLOG.DBA.SYS_BLOGS_B_CONTENT_QUERY where TT_CD = BI_BLOG_ID do
  {
    delete from BLOG..SYS_BLOGS_B_CONTENT_USER where TTU_T_ID = TT_ID;
    delete from BLOG..SYS_BLOGS_B_CONTENT_HIT where TTH_T_ID = TT_ID;
  }
  delete from BLOG.DBA.SYS_BLOGS_B_CONTENT_QUERY where TT_CD = BI_BLOG_ID;
}
;


create procedure
BLOG2_GET_TEXT_TITLE_INT (in post_id any)
{
  declare ret any;
  ret := (select B_TITLE from BLOG.DBA.SYS_BLOGS where B_POST_ID = post_id);
  if (ret is NULL)
  ret := '';

  return ret;
}
;

create procedure
BLOG_GET_TITLE_UPD (inout meta DB.DBA."MWeblogPost", inout content any)
{
  if (meta is not null and length (meta.title) > 0)
    return meta.title;
  return BLOG_MAKE_TITLE (content);
}
;

create procedure udt_inst_upgrade (inout o DB.DBA."MTWeblogPost")
{
  declare n "MTWeblogPost";
  if (o is null)
    return null;
  if (udt_instance_of (o, 'BLOG.DBA.MTWeblogPost'))
    {
      n := o;
      return n;
    }
  n := new "MTWeblogPost" ();

  n.categories            :=    o.categories    ;
  n.dateCreated           :=    o.dateCreated   ;
  n.description           :=    o.description   ;
  n.enclosure             :=    o.enclosure   ;
  n.permaLink             :=    o.permaLink   ;
  n.postid                :=    o.postid    ;
  n.source                :=    o.source    ;
  n.title                 :=    o.title     ;
  n.userid                :=    o.userid    ;
  n.link                  :=    o.link      ;
  n.author                :=    o.author    ;
  n.comments              :=    o.comments    ;
  n.guid                  :=    o.guid      ;
  n.mt_allow_comments     :=    o.mt_allow_comments ;
  n.mt_allow_pings        :=    o.mt_allow_pings  ;
  n.mt_convert_breaks     :=    o.mt_convert_breaks ;
  n.mt_excerpt            :=    o.mt_excerpt    ;
  n.mt_tb_ping_urls       :=    o.mt_tb_ping_urls ;
  n.mt_text_more          :=    o.mt_text_more    ;
  n.mt_keywords           :=    o.mt_keywords   ;

  return n;
}
;

create procedure
BLOG2_UPDATE_TEXT_TITLE_INT ()
{
   if (registry_get ('__weblog_tytle_is_updated') = 'OK')
     return;

   set triggers off;
   update BLOG.DBA.SYS_BLOGS set B_TITLE = BLOG_GET_TITLE_UPD (B_META, B_CONTENT), B_META=udt_inst_upgrade(B_META);
   set triggers on;
   registry_set ('__weblog_tytle_is_updated', 'OK');
}
;

BLOG2_UPDATE_TEXT_TITLE_INT ()
;

create procedure BLOG.DBA.CONTENT_ANNOTATE (in ap_uid any, in source_UTF8 varchar)
{
  declare ap_set_ids any;
  declare res_out, script_out, match_list any;
  declare m_apc, m_aps, m_app, m_apa, m_apa_w, m_aph any;
  declare apa_w_ctr, apa_w_count integer;
  declare app_ctr, app_count integer;
  declare prev_end, prev_apa_id, prev_idx integer;
  declare done any;

  ap_set_ids := (select vector (APS_ID) from DB.DBA.SYS_ANN_PHRASE_SET where
  	APS_OWNER_UID = ap_uid and APS_NAME = sprintf ('Hyperlinking-%d', ap_uid));

  if (not length (ap_set_ids))
    return source_UTF8;

  match_list := ap_build_match_list ( ap_set_ids, source_UTF8, 'x-any', 2, 0);
  m_apc   := aref_set_0 (match_list, 0);
  m_aps   := aref_set_0 (match_list, 1);
  m_app   := aref_set_0 (match_list, 2);
  m_apa   := aref_set_0 (match_list, 3);
  m_apa_w := aref_set_0 (match_list, 4);
  m_aph   := aref_set_0 (match_list, 5);

--  dbg_obj_print ('apc:', m_apc);
--  dbg_obj_print ('aps:', m_aps);
--  dbg_obj_print ('app:', m_app);
--  dbg_obj_print ('apa:', m_apa);
--  dbg_obj_print ('apa_w:', m_apa_w);
--  dbg_obj_print ('aph:', m_aph);

  apa_w_count := length (m_apa_w);
  app_count := length (m_app);
  done := make_array (app_count, 'any');
  if (0 = app_count)
    {
      return source_UTF8;
    }
  res_out := string_output ();
  prev_apa_id := -1;
  for (apa_w_ctr := 0; apa_w_ctr < apa_w_count; apa_w_ctr := apa_w_ctr + 1)
    {
      declare apa_idx, is_single_word integer;
      declare apa any;
      apa_idx := m_apa_w [apa_w_ctr];
      apa := aref_set_0 (m_apa, apa_idx);

      -- if current apa idex is not next by previous, then we already in new match
      if (apa_idx > 0 and (prev_idx + 1) <> apa_idx)
	prev_apa_id := -1;

      if (6 = length (apa))
        {
          declare apa_beg, apa_end, apa_hpctr, apa_hpcount, add_href, inside_href, this_apa_id integer;
          declare arr, dta any;

--	  dbg_obj_print (apa);

	  if (position (prev_apa_id, apa[5]))
	    this_apa_id := prev_apa_id;
	  else
	    this_apa_id := apa[5][0];

	  -- if phrase has space inside, then we do multiple words
	  if (strchr (m_app[this_apa_id][2], ' ') is not null)
	    is_single_word := 0;
	  else
	    is_single_word := 1;


          apa_beg := apa [1];
	  apa_end := apa [2];
	  apa_hpcount := length (apa[5]);
	  http (subseq (source_UTF8, prev_end, apa_beg), res_out);

	  if (bit_and (0hex00000004, apa[3]) or bit_and (0hex80000000, apa[3])) -- inside HREF or XMP
	    {
	    add_href := 0;
	      inside_href := 1;
	      -- this phrase already is hyperlinked
	      if (bit_and (0hex00000004, apa[3]))
		done [this_apa_id] := 1;
	    }
	  else
	    {
	    add_href := 1;
	      inside_href := 0;
	    }

	  -- if we are already on next word in phrase do not print start of HREF
	  if (is_single_word = 0 and position (prev_apa_id, apa[5]))
	    add_href := 0;


	  if (add_href and not done[this_apa_id]) -- if to print start and not already done with this phrase
	    {
	      arr := m_app[this_apa_id];
	      dta := arr [3];
	      http (sprintf ('<a class="auto-href" href="%V">', dta), res_out);
	      --http ('[', res_out);
	    }

	  -- print the matched content
	  http (subseq (source_UTF8, apa_beg, apa_end), res_out);

	  -- if we have next match and current match is not single word
	  if ((apa_idx + 1) < length (m_apa) and is_single_word = 0)
	    {
	      declare n_apa any;
	      n_apa := m_apa [apa_idx + 1];
	      -- if next match is for same phrase do not print HREF closing tag
	      if (length (n_apa) = 6 and position (this_apa_id, n_apa [5]))
                add_href := 0;
              else if (not inside_href) -- if next match is some other phrase and we are not inside existing HREF, print closing tag
		add_href := 1;
	    }
	  else if (not inside_href) -- if this is a last match, and no inside HREF, print closing tag
            add_href := 1;


	  prev_apa_id := this_apa_id;
	  if (add_href and not done[this_apa_id]) -- if this phrase is not printed yet
	    {
	      http ('</a>', res_out);
	      done [this_apa_id] := 1;
	      prev_apa_id := -1;
	    }
	  --if (add_href) http (']', res_out);

          prev_end := apa_end;
        }
      else
	prev_apa_id := -1;
      prev_idx := apa_idx;
    }
  http (subseq (source_UTF8, prev_end), res_out);
  return string_output_string (res_out);
}
;

create trigger SYS_SYS_BLOGS_IN_SYS_BLOG_ATTACHES after insert on BLOG.DBA.SYS_BLOGS order 1 referencing new as N
{
  declare xt, ss, tags, tagstr, is_act, have_encl any;
  declare title, author, authorid, home varchar;
  declare mid, rfc, author_mail, enc_type, _wai_name varchar;
  declare post_iri varchar;
  declare inst_id, auto_tag, auto_href int;

  update BLOG.DBA.SYS_BLOG_ATTACHES set BA_M_BLOG_ID = N.B_BLOG_ID
  where BA_M_BLOG_ID = N.B_BLOG_ID; -- Only for timestamp

  if (N.B_RFC_ID is null)
    mid := BLOG..MAKE_RFC_ID (N.B_POST_ID);
  else
    mid := N.B_RFC_ID;

  whenever not found goto nf;
  select BI_HOME, BI_WAI_NAME, WAI_ID, BI_AUTO_TAGGING into home, _wai_name, inst_id, auto_tag
      from BLOG..SYS_BLOG_INFO, DB.DBA.WA_INSTANCE
      where BI_BLOG_ID = N.B_BLOG_ID and BI_WAI_NAME = WAI_NAME;
  select coalesce (U_FULL_NAME, U_NAME), U_NAME, U_E_MAIL into author, authorid, author_mail
      from DB.DBA.SYS_USERS where U_ID = N.B_USER_ID;
  nf:

  xt := xml_tree_doc (xml_tree (N.B_CONTENT, 2, '', 'UTF-8'));
  auto_href := 1;
  if (xpath_eval ('//no-auto-href', xt, 1) is not null)
    auto_href := 0;

  RE_TAG_POST (N.B_BLOG_ID, N.B_POST_ID, N.B_USER_ID, inst_id, N.B_CONTENT, 0, xt, null, null, auto_tag);

  xt := xslt (BLOG2_GET_PPATH_URL ('widgets/store_post.xsl'), xt);
  xml_tree_doc_set_output (xt, 'xhtml');
  xml_tree_doc_set_ns_output (xt, 1);

  ss := string_output ();
  http_value (xt, null, ss);

  is_act := 0;

  if (xpath_eval ('[ xmlns:sql="urn:schemas-openlink-com:xml-sql" ] //sql:*', xt, 1) is not null)
    is_act := 1;

  ss := string_output_string (ss);
  if (auto_href)
  ss := BLOG.DBA.CONTENT_ANNOTATE (N.B_USER_ID, ss);
  BLOG_ADD_LINKS (N.B_BLOG_ID, N.B_POST_ID, xml_tree_doc (xml_tree (ss, 2, '', 'UTF-8')));

  title := BLOG_GET_TITLE (N.B_META, N.B_CONTENT);
  enc_type := null;

  if (N.B_META is not null and (N.B_META as "MWeblogPost").enclosure is not null)
    {
      declare enc BLOG.DBA."MWeblogEnclosure";
      enc := (N.B_META as "MWeblogPost").enclosure;
      if (udt_instance_of ((N.B_META as "MWeblogPost").enclosure, 'BLOG.DBA.MWeblogEnclosure'))
	{
	enc_type := enc."type";
	  insert into BLOG_POST_ENCLOSURES (PE_BLOG_ID,PE_POST_ID,PE_URL,PE_TYPE,PE_LEN)
	     values (N.B_BLOG_ID, N.B_POST_ID, enc."url", enc_type, enc."length");
	}
    have_encl := 1;
    }
  else
    have_encl := 0;

  post_iri := sioc..post_iri (authorid, 'weblog', _wai_name, N.B_POST_ID);

  if (N.B_RFC_HEADER is null)
    rfc := MAKE_POST_RFC_HEADER (mid, null, N.B_BLOG_ID, title, N.B_TS, author_mail);
  else
    rfc := N.B_RFC_HEADER;


  set triggers off;
  update BLOG.DBA.SYS_BLOGS set B_TITLE = title,
   B_CONTENT = ss, --serialize_to_UTF8_xml (xt)
   B_IS_ACTIVE = is_act,
   B_HAVE_ENCLOSURE = have_encl,
   B_ENCLOSURE_TYPE = enc_type,
   B_RFC_ID = mid, B_RFC_HEADER = rfc
     where B_BLOG_ID = N.B_BLOG_ID and B_POST_ID = N.B_POST_ID;
  set triggers on;

  update BLOG.DBA.SYS_BLOG_INFO
  set BI_LAST_UPDATE = now (),
      BI_DASHBOARD =
	  make_dasboard_item ('post', N.B_TS, title, author, post_iri, '', BI_DASHBOARD, N.B_POST_ID,
	      'insert', authorid, null)
  where BI_BLOG_ID = N.B_BLOG_ID;

  if (not exists (select 1 from BLOG.DBA.MTYPE_BLOG_CATEGORY where MTB_BLOG_ID = N.B_BLOG_ID and MTB_POST_ID = N.B_POST_ID))
    {
      for select MTC_ID from BLOG.DBA.MTYPE_CATEGORIES where MTC_BLOG_ID = N.B_BLOG_ID and MTC_DEFAULT = 1 do
	{
	  insert soft BLOG.DBA.MTYPE_BLOG_CATEGORY (MTB_CID, MTB_POST_ID, MTB_BLOG_ID, MTB_IS_AUTO)
	      values (MTC_ID, N.B_POST_ID, N.B_BLOG_ID, 1);
	}
    }

  ODS..APP_PING (_wai_name, title, home, null, home || 'gems/rss.xml');
  ODS..APP_PING (_wai_name, title, home, null, home || 'gems/atom.xml');

  -- WA widgets
  if (__proc_exists ('DB.DBA.WA_NEW_BLOG_IN') and N.B_STATE = 2)
    {
      DB.DBA.WA_NEW_BLOG_IN (title, post_iri, N.B_POST_ID);
    }
}
;

create trigger SYS_SYS_BLOGS_UP_SYS_BLOG_ATTACHES after update on BLOG.DBA.SYS_BLOGS order 1 referencing old as O, new as N
{
  declare xt, ss, tags, tagstr, is_act, home, author, authorid, title, have_encl, enc_type, _wai_name any;
  declare ver int;
  declare post_iri, graph_iri varchar;
  declare inst_id, auto_tag, auto_href int;

  update BLOG.DBA.SYS_BLOG_ATTACHES set BA_M_BLOG_ID = N.B_BLOG_ID where BA_M_BLOG_ID = N.B_BLOG_ID; -- Only for timestamp

  whenever not found goto nf;
  select BI_HOME, BI_WAI_NAME, WAI_ID, BI_AUTO_TAGGING into home, _wai_name, inst_id, auto_tag
      from BLOG..SYS_BLOG_INFO, DB.DBA.WA_INSTANCE where BI_BLOG_ID = N.B_BLOG_ID and BI_WAI_NAME = WAI_NAME;
  select coalesce (U_FULL_NAME, U_NAME), U_NAME into author, authorid from DB.DBA.SYS_USERS where U_ID = N.B_USER_ID;
  nf:

  post_iri := sioc..post_iri (authorid, 'weblog', _wai_name, N.B_POST_ID);

  if (is_http_ctx ())
    {
      xt := xml_tree_doc (xml_tree (N.B_CONTENT, 2, '', 'UTF-8'));
      auto_href := 1;
      if (xpath_eval ('//no-auto-href', xt, 1) is not null)
	auto_href := 0;

      graph_iri := sioc..get_graph ();
      sioc.DBA.delete_quad_s_or_o (graph_iri, post_iri, post_iri);
      RE_TAG_POST (N.B_BLOG_ID, N.B_POST_ID, N.B_USER_ID, inst_id, N.B_CONTENT, 0, xt, null, null, auto_tag);

      xt := xslt (BLOG2_GET_PPATH_URL ('widgets/store_post.xsl'), xt);
      xml_tree_doc_set_output (xt, 'xhtml');
      xml_tree_doc_set_ns_output (xt, 1);

      ss := string_output ();
      http_value (xt, null, ss);
      is_act := 0;

      if (xpath_eval ('[ xmlns:sql="urn:schemas-openlink-com:xml-sql" ] //sql:*', xt, 1) is not null)
	is_act := 1;

      ss := string_output_string (ss);
      if (auto_href)
      ss := BLOG.DBA.CONTENT_ANNOTATE (N.B_USER_ID, ss);
      BLOG_ADD_LINKS (N.B_BLOG_ID, N.B_POST_ID, xml_tree_doc (xml_tree (ss, 2, '', 'UTF-8')));

      title := BLOG_GET_TITLE (N.B_META, N.B_CONTENT);
      enc_type := null;
      -- delete old enclosures
      if (O.B_HAVE_ENCLOSURE = 1)
	{
	  delete from BLOG_POST_ENCLOSURES where PE_BLOG_ID = O.B_BLOG_ID and PE_POST_ID = O.B_POST_ID;
	}
      if (N.B_META is not null and (N.B_META as "MWeblogPost").enclosure is not null)
	{
	  declare enc BLOG.DBA."MWeblogEnclosure";
	  enc := (N.B_META as "MWeblogPost").enclosure;
	  if (udt_instance_of ((N.B_META as "MWeblogPost").enclosure, 'BLOG.DBA.MWeblogEnclosure'))
	    {
	    enc_type := enc."type";
	      insert into BLOG_POST_ENCLOSURES (PE_BLOG_ID,PE_POST_ID,PE_URL,PE_TYPE,PE_LEN)
	        values (N.B_BLOG_ID, N.B_POST_ID, enc."url", enc_type, enc."length");
	    }
	have_encl := 1;
	}
      else
	{
	have_encl := 0;
	}

      ver := coalesce (O.B_VER, 1) + 1;

      --dbg_printf ('o.ver=%d n.ver=%d ver=%d', O.B_VER, N.B_VER, ver);

      if (O.B_VER <> N.B_VER)
	signal ('BLOGV', 'Specified version number doesn''t match resource''s latest version number.');


      set triggers off;
      update BLOG.DBA.SYS_BLOGS set
	  B_TITLE = title,
	  B_CONTENT = ss, --serialize_to_UTF8_xml (xt)
	  B_IS_ACTIVE = is_act,
	  B_HAVE_ENCLOSURE = have_encl,
	  B_ENCLOSURE_TYPE = enc_type,
	  B_VER = ver
	  where B_BLOG_ID = N.B_BLOG_ID and B_POST_ID = N.B_POST_ID;
      set triggers on;
    }


  update BLOG.DBA.SYS_BLOG_INFO set
	BI_LAST_UPDATE = now (),
      	BI_DASHBOARD =
	    make_dasboard_item ('post', N.B_TS, N.B_TITLE, author, post_iri, '', BI_DASHBOARD, N.B_POST_ID, 'update', authorid, null)
  where BI_BLOG_ID = N.B_BLOG_ID;

  ODS..APP_PING (_wai_name, title, home, null, home || 'gems/rss.xml');
  ODS..APP_PING (_wai_name, title, home, null, home || 'gems/atom.xml');

  if (__proc_exists ('DB.DBA.WA_NEW_BLOG_IN') and N.B_STATE = 2)
    {
      DB.DBA.WA_NEW_BLOG_IN (N.B_TITLE, post_iri, N.B_POST_ID);
    }
}
;

create trigger SYS_SYS_BLOGS_RM_SYS_BLOG_ATTACHES after delete on BLOG.DBA.SYS_BLOGS
{
  update BLOG.DBA.SYS_BLOG_ATTACHES set BA_M_BLOG_ID = B_BLOG_ID where BA_M_BLOG_ID = B_BLOG_ID; -- Only for timestamp
  set triggers off;
  update BLOG.DBA.SYS_BLOG_INFO
  set BI_DASHBOARD =
	  make_dasboard_item ('post', null, null, null, null, '', BI_DASHBOARD, B_POST_ID, 'delete')
  where BI_BLOG_ID = B_BLOG_ID;
  set triggers on;
  if (__proc_exists ('DB.DBA.WA_NEW_BLOG_RM'))
    {
      DB.DBA.WA_NEW_BLOG_RM (B_POST_ID);
    }
}
;

blog2_exec_no_error ('create index SYS_SYS_BLOG_ATTACHES_BA_M_BLOG_ID on SYS_BLOG_ATTACHES (BA_M_BLOG_ID)')
;

blog2_exec_no_error ('create index SYS_SYS_BLOG_ATTACHES_BA_LAST_UPDATE on SYS_BLOG_ATTACHES (BA_LAST_UPDATE)')
;

create procedure BLOG2_HOME_GET_LINKRSS_SQLX(in blogid varchar, in rep int := 1)
{
  declare ses any;
  ses := string_output();
  http('<?xml version =\'1.0\' encoding=\'UTF-8\'?>\n', ses);
  http('<rss version="2.0" xmlns:wfw="http://wellformedweb.org/CommentAPI/" xmlns:slash="http://purl.org/rss/1.0/modules/slash/">\n', ses);
  http('<channel>\n', ses);
  http('<sql:sqlx xmlns:sql=\'urn:schemas-openlink-com:xml-sql\' sql:xsl=""><![CDATA[\n', ses);
  http('select \n', ses);
  http('XMLELEMENT(\'title\', BLOG..blog_utf2wide (BI_TITLE)), \n', ses);
  http('XMLELEMENT(\'link\', \'http://\' || BLOG.DBA.BLOG2_GET_HOST() || BLOG.DBA.BLOG2_GET_HOME_DIR(BI_HOME) || \'?linkblog\'), \n', ses);
  http('XMLELEMENT(\'description\', BLOG..blog_utf2wide (BI_ABOUT)), \n', ses);
  http('XMLELEMENT(\'managingEditor\', BI_E_MAIL), \n', ses);
  http('XMLELEMENT(\'pubDate\', BLOG.DBA.date_rfc1123(now())), \n', ses);
  http('XMLELEMENT(\'generator\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', ses);
  http('XMLELEMENT(\'webMaster\', BI_E_MAIL), \n', ses);
  http('XMLELEMENT(\'image\', \n', ses);
  http('XMLELEMENT(\'title\', BLOG..blog_utf2wide (BI_TITLE)), \n', ses);
  http('XMLELEMENT(\'url\', \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || \'/weblog/public/images/vbloglogo.gif\'), \n', ses);
  http('XMLELEMENT(\'link\', \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME) || \'?linkblog\'), \n', ses);
  http('XMLELEMENT(\'description\', BLOG..blog_utf2wide (BI_ABOUT)), \n', ses);
  http('XMLELEMENT(\'width\', \'88\'), \n', ses);
  http('XMLELEMENT(\'height\', \'31\')) \n', ses);
  http('from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = <UID>\n', ses);
  http(']]></sql:sqlx>\n', ses);
  http('<sql:sqlx xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'><![CDATA[\n', ses);
  http('select \n', ses);
  http('XMLAGG(XMLELEMENT(\'item\',\n', ses);
  http('XMLELEMENT(\'title\', BLOG..blog_utf2wide(B_TITLE)),\n', ses);
--  http('XMLELEMENT(\'guid\', \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()||BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?linkblog&id=\'||B_POST_ID||sprintf(\'#%U\',B_TITLE)),\n', ses);
  http('XMLELEMENT(\'guid\', B_LINK),\n', ses);
  http('XMLELEMENT(\'link\', B_LINK),\n', ses);
  http('XMLELEMENT(\'pubDate\', BLOG.DBA.date_rfc1123 (B_TS)),\n', ses);
--  http('XMLELEMENT(\'description\', deserialize(B_CONTENT)),\n', ses);
  http('XMLELEMENT(\'http://www.openlinksw.com/weblog/:modified\', BLOG..date_iso8601 (B_MODIFIED))))\n', ses);
  http('from\n', ses);
  http('(select TOP 35 cast (CONTENT as varchar) as B_TITLE, xpath_eval (\'@href\', CONTENT) as B_LINK , B_TS, BI_HOME, B_POST_ID, B_USER_ID, B_MODIFIED from\n', ses);
  http ('BLOG..SYS_BLOGS, BLOG..SYS_BLOG_INFO,
        (select BI_BLOG_ID as BA_C_BLOG_ID, BI_BLOG_ID as BA_M_BLOG_ID from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = <UID>
        union all select * from (select top 15 BA_C_BLOG_ID, BA_M_BLOG_ID from BLOG.DBA.SYS_BLOG_ATTACHES
          where BA_M_BLOG_ID = <UID> order by BA_LAST_UPDATE desc) name1) name2
      where B_BLOG_ID = BA_C_BLOG_ID and B_STATE = 2 and BI_BLOG_ID = B_BLOG_ID \n', ses);

  http('and xpath_contains (B_CONTENT, \'[__quiet BuildStandalone=ENABLE] //a[starts-with (@href,"http") and not(img)]\', CONTENT)\n', ses);
  http('order by B_TS desc\n', ses);
  http(') sub\n', ses);
  http(']]></sql:sqlx>\n', ses);
  http('</channel>\n', ses);
  http('</rss>\n', ses);
  ses := string_output_string (ses);
  if (rep)
    ses := replace (ses, 'sql:xsl=""', '');
  ses := replace(ses, '<UID>', WS.WS.STR_SQL_APOS(blogid));
  return serialize_to_UTF8_xml(ses);
}
;

create procedure BLOG2_HOME_GET_LINKRDF_SQLX(in blogid varchar)
{
  declare r any;
  r := BLOG2_HOME_GET_LINKRSS_SQLX (blogid, 0);
  r := replace (r, 'sql:xsl=""', 'sql:xsl="/DAV/VAD/blog2/widgets/rss2rdf.xsl"');
  return r;
}
;

create procedure BLOG2_HOME_GET_LINKRSS(in blogid varchar) {
declare sql any;
sql := 'select
  1 as tag,
  null as parent,
  \'2.0\' as [rss!1!version],
  \'http://wellformedweb.org/CommentAPI/\' as [rss!1!xmlns:wfw],
  \'http://purl.org/rss/1.0/modules/slash/\' as [rss!1!xmlns:slash],
  \'http://www.openlinksw.com/weblog/\' as [rss!1!xmlns:vi],
  null as [channel!2!title!element],
  null as [channel!2!link!element],
  null as [channel!2!description!element],
  null as [channel!2!managingEditor!element],
  null as [channel!2!pubDate!element],
  null as [channel!2!generator!element],
  null as [channel!2!webMaster!element],
        null as [image!3!title!element],
        null as [image!3!url!element],
        null as [image!3!link!element],
        null as [image!3!description!element],
        null as [image!3!width!element],
        null as [image!3!height!element],
  null as [item!5!title!element],
  null as [item!5!link!element],
  null as [item!5!pubDate!element],
  null as [item!5!vi:modified!element],
  null as [item!5!ts!hide]
  from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = <UID>
union all
select
  2,
  1,
  null, null, null, null,
  BI_TITLE,
  \'http://\'||BLOG.DBA.BLOG2_GET_HOST ()|| BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME) ||\'?linkblog\',
  BI_ABOUT,
  BI_E_MAIL,
  BLOG.DBA.date_rfc1123(now ()),
  \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\'),
  BI_E_MAIL,
  null, null, null, null, null, null,
  null, null, null, null, null
  from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = <UID>
union all
select
  3,
  2,
  null, null, null, null,
  null, null, null, null, null, null, null,
  BI_TITLE,
  \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || \'/weblog/public/images/vbloglogo.gif\',
  \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME),
  BI_ABOUT,
  88,
  31,
  null, null, null, null, null
  from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = <UID>
union all
select
  5,
  2,
  null, null, null, null,
  null, null, null, null, null, null, null,
  null, null, null, null, null, null,
  B_TITLE,
  B_LINK,
  BLOG.DBA.date_rfc1123 (B_TS),
  BLOG.DBA.date_iso8601 (B_MODIFIED),
  B_TS
  from
  (select TOP 35 xpath_eval (\'@href\', CONTENT) as B_LINK, cast (CONTENT as varchar) as B_TITLE, B_TS, BI_HOME, B_POST_ID, B_USER_ID, B_MODIFIED from
    BLOG..SYS_BLOGS, BLOG..SYS_BLOG_INFO
  where B_STATE = 2 and B_BLOG_ID = <UID> and BI_BLOG_ID = B_BLOG_ID
  and xpath_contains (B_CONTENT, \'[__quiet BuildStandalone=ENABLE] //a[starts-with (@href,"http") and not(img)]\', CONTENT)
  order by B_TS desc
  ) sub
for xml explicit';
  sql := replace(sql, '<UID>', WS.WS.STR_SQL_APOS(blogid));
  return serialize_to_UTF8_xml(sql);
}
;

CREATE PROCEDURE BLOG2_HOME_GET_LINKATOM (in blogid varchar)
{
  declare r any;
  declare xsl any;
  xsl := BLOG_GET_ATOM_XSL ();
  r := BLOG2_HOME_GET_LINKRSS_SQLX (blogid, 0);
  r := replace (r, 'sql:xsl=""', 'sql:xsl="/DAV/VAD/blog2/widgets/'|| xsl ||'"');
  return r;
}
;

-- xbel.xml

CREATE PROCEDURE BLOG2_HOME_GET_XBEL_SQLX (IN UID INTEGER)
{
  declare ses any;
  ses := string_output ();
  http ('<?xml version =\'1.0\' encoding=\'UTF-8\'?>\n', ses);
  http ('<!DOCTYPE xbel PUBLIC "+//IDN python.org//DTD XML Bookmark Exchange Language 1.0//EN//XML" "http://pyxml.sourceforge.net/topics/dtds/xbel-1.0.dtd">\n', ses);
  http ('<xbel xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'>\n', ses);
  http ('    <sql:header>\n', ses);
  http (' <sql:param name=":bid"><UID></sql:param>\n', ses);
  http ('    </sql:header>\n', ses);
  http ('    <sql:sqlx sql:xsl="/DAV/VAD/blog2/widgets/xbel.xsl"><![CDATA[\n', ses);
  http (' select xmlelement (title, BI_TITLE) from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = :bid\n', ses);
  http (' ]]></sql:sqlx>\n', ses);
  http ('    <sql:sqlx><![CDATA[\n', ses);
  http (' select xmlelement (\'folder\', \n', ses);
  http ('   xmlattributes (BCC_ID as id), \n', ses);
  http ('   xmlelement (\'title\', BLOG..blog_utf2wide (BCC_NAME)), \n', ses);
  http ('     (select xmlagg (xmlelement (\'bookmark\', \n', ses);
  http ('       xmlattributes (BC_CHANNEL_URI as href, md5(BC_CHANNEL_URI) as id), \n', ses);
  http ('       xmlelement (\'title\', BLOG..blog_utf2wide (BCD_TITLE)))) \n', ses);
  http ('       from BLOG..SYS_BLOG_CHANNEL_INFO, BLOG..SYS_BLOG_CHANNELS \n', ses);
  http ('       where BCD_CHANNEL_URI = BC_CHANNEL_URI and \n', ses);
  http ('         BC_CAT_ID = BCC_ID and BC_BLOG_ID = BCC_BLOG_ID)) \n', ses);
  http ('         from BLOG..SYS_BLOG_CHANNEL_CATEGORY where BCC_BLOG_ID = :bid\n', ses);
  http (' ]]></sql:sqlx>\n', ses);
  http ('</xbel>\n', ses);
  ses := string_output_string (ses);
  ses := replace (ses, '<UID>', cast (UID as varchar));
  return ses;
}
;

CREATE PROCEDURE BLOG2_HOME_GET_XBEL_OLD_SQLX (IN UID INTEGER)
{
  declare ses any;
  ses := string_output ();
http ('<?xml version =\'1.0\' encoding=\'UTF-8\'?>\n', ses);
http ('<!DOCTYPE xbel PUBLIC "+//IDN python.org//DTD XML Bookmark Exchange Language 1.0//EN//XML" "http://pyxml.sourceforge.net/topics/dtds/xbel-1.0.dtd">\n', ses);
http ('<xbel xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'>\n', ses);
http ('    <sql:header>\n', ses);
http (' <sql:param name=":bid"><UID></sql:param>\n', ses);
http (' <sql:param name=":from">2000-01-01</sql:param>\n', ses);
http (' <sql:param name=":to">2000-01-01</sql:param>\n', ses);
http ('    </sql:header>\n', ses);
http ('    <sql:sqlx sql:xsl="/DAV/VAD/blog2/widgets/xbel.xsl"><![CDATA[\n', ses);
http (' select xmlelement (title, BI_TITLE) from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = :bid\n', ses);
http (' ]]></sql:sqlx>\n', ses);
http ('    <sql:sqlx><![CDATA[\n', ses);
http ('select\n', ses);
http (' xmlelement (\'folder\',\n', ses);
http ('             xmlattributes (MTC_ID as id),\n', ses);
http ('             xmlelement (\'title\', MTC_NAME),\n', ses);
http ('                 (\n', ses);
http ('                  select\n', ses);
http ('                  xmlagg (xmlelement (\'bookmark\', xmlattributes (\n', ses);
http ('                  \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()|| BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'||B_POST_ID \n', ses);
http ('                  as href, B_POST_ID as id),\n', ses);
http ('                                 xmlelement (\'title\', BLOG..blog_utf2wide (B_TITLE))))\n', ses);
http ('\n', ses);
http ('                                 from BLOG..SYS_BLOGS,\n', ses);
http ('                                 \n', ses);
http ('                                 (select BI_BLOG_ID as BA_C_BLOG_ID, BI_BLOG_ID as BA_M_BLOG_ID from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = :bid union all select * from (select top 10 BA_C_BLOG_ID, BA_M_BLOG_ID from BLOG.DBA.SYS_BLOG_ATTACHES where BA_M_BLOG_ID = :bid order by BA_LAST_UPDATE desc) sname1) sname2, BLOG..MTYPE_BLOG_CATEGORY, BLOG..SYS_BLOG_INFO \n', ses);
http ('                                 where B_BLOG_ID = BA_C_BLOG_ID\n', ses);
http ('                                 \n', ses);
http ('                                 and BI_BLOG_ID = B_BLOG_ID\n', ses);
http ('                                 and MTB_BLOG_ID = B_BLOG_ID and MTB_POST_ID = B_POST_ID \n', ses);
http ('                                 and MTB_CID = MTC_ID\n', ses);
http ('                                 and B_TS >= :from and B_TS < :to\n', ses);
http ('                 )\n', ses);
http ('             )\n', ses);
http ('             from BLOG..MTYPE_CATEGORIES where MTC_BLOG_ID = :bid\n', ses);
http (' ]]></sql:sqlx>\n', ses);
http ('    <sql:sqlx><![CDATA[\n', ses);
http ('select\n', ses);
http (' xmlelement (\'folder\',\n', ses);
http ('             xmlattributes (\'0\' as id),\n', ses);
http ('             xmlelement (\'title\', \'default\'),\n', ses);
http ('                 (\n', ses);
http ('                  select\n', ses);
http ('                  xmlagg (xmlelement (\'bookmark\', xmlattributes (\n', ses);
http ('                  \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()|| BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'||B_POST_ID \n', ses);
http ('                  as href, B_POST_ID as id),\n', ses);
http ('                                 xmlelement (\'title\', BLOG..blog_utf2wide (B_TITLE))))\n', ses);
http ('\n', ses);
http ('                         from (select top 15 B_POST_ID, B_TITLE, BI_HOME\n', ses);
http ('                         from BLOG..SYS_BLOGS, \n', ses);
http ('                         (select BI_BLOG_ID as BA_C_BLOG_ID, BI_BLOG_ID as BA_M_BLOG_ID from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = :bid union all select * from (select top 10 BA_C_BLOG_ID, BA_M_BLOG_ID from BLOG.DBA.SYS_BLOG_ATTACHES where BA_M_BLOG_ID = :bid order by BA_LAST_UPDATE desc) sname1) sname2, \n', ses);
http ('                                 BLOG..SYS_BLOG_INFO \n', ses);
http ('                                 where B_BLOG_ID = BA_C_BLOG_ID\n', ses);
http ('                                 and BI_BLOG_ID = B_BLOG_ID\n', ses);
http ('                                 and B_TS >= :from and B_TS < :to\n', ses);
http ('                                 and not exists (select 1 from BLOG..MTYPE_BLOG_CATEGORY where MTB_POST_ID = B_POST_ID)\n', ses);
http ('                         ) name1\n', ses);
http ('                 )\n', ses);
http ('             )\n', ses);
http ('             from DB.DBA.SYS_USERS where U_ID = 0\n', ses);
http ('             ]]></sql:sqlx>\n', ses);
http ('</xbel>\n', ses);
  ses := string_output_string (ses);
  ses := replace (ses, '<UID>', cast (UID as varchar));
  return ses;
}
;

-- xbel-summary.xml

CREATE PROCEDURE BLOG2_HOME_GET_XBEL_SUMMARY_XML (IN UID INTEGER)
{
  declare ses any;
  ses := string_output ();
    http ('<?xml version="1.0" encoding="UTF-8"?>\n', ses);
    http ('<xbel xmlns:sql="urn:schemas-openlink-com:xml-sql">\n', ses);
    http ('  <sql:header>\n', ses);
    http ('      <sql:param name=":bid"><UID></sql:param>\n', ses);
    http ('      <sql:param name=":posts">wbwA</sql:param>\n', ses);
    http ('  </sql:header>\n', ses);
    http ('  <sql:sqlx sql:xsl="/DAV/VAD/blog2/widgets/xbel.xsl"><![CDATA[\n', ses);
    http (' select xmlelement (title, BI_TITLE) from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = :bid\n', ses);
    http (' ]]></sql:sqlx>\n', ses);
    http ('  <sql:sqlx><![CDATA[\n', ses);
    http ('select\n', ses);
    http (' xmlelement (\'folder\',\n', ses);
    http ('             xmlattributes (\'0\' as id),\n', ses);
    http ('             xmlelement (\'title\', \'Blog Summary\'),\n', ses);
    http ('                 (\n', ses);
    http ('                  select\n', ses);
    http ('                  xmlagg (xmlelement (\'bookmark\', xmlattributes (\n', ses);
    http ('                  \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()|| BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'||B_POST_ID\n', ses);
    http ('                  as href, B_POST_ID as id),\n', ses);
    http ('                                 xmlelement (\'title\', BLOG..blog_utf2wide (B_TITLE))))\n', ses);
    http ('                         from BLOG..SYS_BLOGS,\n', ses);
    http ('                                 BLOG..SYS_BLOG_INFO\n', ses);
    http ('                                 where BI_BLOG_ID = B_BLOG_ID\n', ses);
    http ('                                 and position (B_POST_ID, deserialize (decode_base64 (:posts))) \n', ses);
    http ('                                 \n', ses);
    http ('                 )\n', ses);
    http ('             )\n', ses);
    http ('             from DB.DBA.SYS_USERS where U_ID = 0\n', ses);
    http ('             ]]></sql:sqlx>\n', ses);
    http ('</xbel>\n', ses);
  ses := string_output_string (ses);
  ses := replace (ses, '<UID>', cast (UID as varchar));
  return ses;
}
;

create procedure BLOG2_XBEL_LINKBLOG_P (in blogid any, in topn any, in offs any, in dat any, in ord any := 'desc', in comm int := 0)
{
    declare sql, h, time_cond, dta, mdta, pars, fro any;

    declare TITLE, HREF varchar;
    declare B_POST_ID varchar;
    declare B_TS datetime;
    declare d1, d2 timestamp;

    pars := vector ();
    time_cond := '';
    if (length (trim (dat)))
      {
	 d1 := stringdate (dat);
	 d2 := dateadd('day', 1, d1);
         time_cond := ' and B_TS >= ? and B_TS < ? ';
         pars := vector_concat  (pars, vector (d1, d2));
      }

    if (comm)
     fro := sprintf (' from BLOG..SYS_BLOGS, (select BI_BLOG_ID as BA_C_BLOG_ID, BI_BLOG_ID as BA_M_BLOG_ID from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = ''%s'' union all select * from (select top 10 BA_C_BLOG_ID, BA_M_BLOG_ID from BLOG.DBA.SYS_BLOG_ATTACHES where BA_M_BLOG_ID = ''%s'' order by BA_LAST_UPDATE desc) name1) name2 where B_BLOG_ID = BA_C_BLOG_ID ', blogid, blogid);
    else
      fro := sprintf (' from BLOG..SYS_BLOGS where B_BLOG_ID = ''%s'' ', blogid);

    result_names (TITLE, HREF, B_POST_ID);

    sql:='select top '||offs || ',' ||topn ||' cast (xpath_eval (\'string(.)\', CONTENT) as varchar) as TITLE, cast (xpath_eval (\'@href\', CONTENT) as varchar) as HREF, B_POST_ID' ||
    --'  from BLOG..SYS_BLOGS ' ||
    --' where B_BLOG_ID = ?  \n' ||
    fro ||

    ' and xpath_contains (B_CONTENT, \'[__quiet BuildStandalone=ENABLE] //a[starts-with (@href,"http") and not(img) ]\', CONTENT) '
    || time_cond || 'order by B_TS ' || ord ;

    --dbg_obj_print (sql, pars);

    exec (sql, null, null, pars, 0, null, null, h);
    while (0 = exec_next (h, null, null, dta))
      exec_result (dta);
    exec_close (h);
}
;

CREATE PROCEDURE BLOG2_HOME_GET_XBEL_LINKBLOG_XML (IN UID INTEGER)
{
  declare ses any;
  ses := string_output ();
    http ('<?xml version="1.0" encoding="UTF-8"?>\n', ses);
    http ('<xbel xmlns:sql="urn:schemas-openlink-com:xml-sql">\n', ses);
    http ('  <sql:header>\n', ses);
    http ('      <sql:param name=":bid"><UID></sql:param>\n', ses);
    http ('      <sql:param name=":top">10</sql:param>\n', ses);
    http ('      <sql:param name=":ord">desc</sql:param>\n', ses);
    http ('      <sql:param name=":offs">0</sql:param>\n', ses);
    http ('      <sql:param name=":dat"> </sql:param>\n', ses);
    http ('      <sql:param name=":comm">0</sql:param>\n', ses);
    http ('  </sql:header>\n', ses);
    http ('  <sql:sqlx sql:xsl="/DAV/VAD/blog2/widgets/xbel.xsl"><![CDATA[\n', ses);
    http (' select xmlelement (title, BI_TITLE) from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = :bid\n', ses);
    http (' ]]></sql:sqlx>\n', ses);
    http ('  <sql:sqlx><![CDATA[\n', ses);
    http ('select\n', ses);
    http (' xmlelement (\'folder\',\n', ses);
    http ('             xmlattributes (\'0\' as id),\n', ses);
    http ('             xmlelement (\'title\', \'LinkBlog\'),\n', ses);
    http ('                 (\n', ses);
    http ('                  select\n', ses);
    http ('                  xmlagg (xmlelement (\'bookmark\', xmlattributes (\n', ses);
    http ('                  HREF \n', ses);
    http ('                  as href, B_POST_ID as id),\n', ses);
    http ('                                 xmlelement (\'title\', TITLE ) ))\n', ses);
    http ('                  	    from BLOG..BLOG2_XBEL_LINKBLOG_P (blogid, topn, offs, dat, ord, comm) (TITLE varchar, HREF varchar, B_POST_ID varchar) BLOG2_XBEL_LINKBLOG_T where blogid = :bid and topn = :top and offs = :offs and dat = :dat and ord = :ord and comm = :comm\n', ses);
    http ('                               \n', ses);
    http ('                 )\n', ses);
    http ('             )\n', ses);
    http ('             from DB.DBA.SYS_USERS where U_ID = 0\n', ses);
    http ('             ]]></sql:sqlx>\n', ses);
    http ('</xbel>\n', ses);
  ses := string_output_string (ses);
  ses := replace (ses, '<UID>', cast (UID as varchar));
  return ses;
}
;


-- foaf-members.xml

CREATE PROCEDURE BLOG2_FOAF_MEMBERS_XML_SQLX (IN UID INTEGER)
{
  declare ses any;
  ses := string_output ();
http ('<?xml version =\'1.0\' encoding=\'UTF-8\'?>\n', ses);
http ('<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:foaf="http://xmlns.com/foaf/0.1/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:plan="http://usefulinc.com/ns/scutter/0.1#"\n', ses);
http ('xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'>\n', ses);
http ('    <sql:header>\n', ses);
http ('	<sql:param name=":bid"><UID></sql:param>\n', ses);
http ('    </sql:header>\n', ses);
http ('    <sql:sqlx><![CDATA[ \n', ses);
http ('	select\n', ses);
http ('	XMLELEMENT(\'http://xmlns.com/foaf/0.1/:Person\',\n', ses);
http ('	XMLATTRIBUTES(BI_BLOG_ID as \'http://www.w3.org/1999/02/22-rdf-syntax-ns#:ID\'),\n', ses);
http ('	XMLELEMENT(\'http://xmlns.com/foaf/0.1/:name\', BLOG..blog_utf2wide(U_FULL_NAME)),\n', ses);
http ('	XMLELEMENT(\'http://xmlns.com/foaf/0.1/:nick\', U_NAME),\n', ses);
http ('	XMLELEMENT(\'http://xmlns.com/foaf/0.1/:mbox\',\n', ses);
http ('	XMLATTRIBUTES(\'mailto:\'||BI_E_MAIL as \'http://www.w3.org/1999/02/22-rdf-syntax-ns#:resource\')),\n', ses);
http ('	XMLELEMENT(\'http://xmlns.com/foaf/0.1/:homepage\',\n', ses);
http ('	XMLATTRIBUTES(BI_HOME_PAGE as \'http://www.w3.org/1999/02/22-rdf-syntax-ns#:resource\')),\n', ses);
http ('	XMLELEMENT(\'http://xmlns.com/foaf/0.1/:weblog\',\n', ses);
http ('	XMLATTRIBUTES(BI_HOME as \'http://www.w3.org/1999/02/22-rdf-syntax-ns#:resource\')),\n', ses);
http ('	XMLELEMENT(\'http://xmlns.com/foaf/0.1/:seeAlso\',\n', ses);
http ('	XMLATTRIBUTES(BI_HOME || \'gems/rss.xml\' as \'http://www.w3.org/1999/02/22-rdf-syntax-ns#:resource\')))\n', ses);
http ('	from BLOG..SYS_BLOG_INFO, "DB"."DBA"."SYS_USERS" where BI_OWNER = U_ID and BI_BLOG_ID = :bid \n', ses);
http ('	]]></sql:sqlx>\n', ses);
http ('    <sql:sqlx><![CDATA[ \n', ses);
http ('	select XMLAGG(XMLELEMENT(\'http://xmlns.com/foaf/0.1/:knows\', \n', ses);
http ('			XMLELEMENT(\'http://xmlns.com/foaf/0.1/:Person\', \n', ses);
http ('			XMLELEMENT(\'http://xmlns.com/foaf/0.1/:name\', BLOG..blog_utf2wide(U_FULL_NAME)), \n', ses);
http ('			XMLELEMENT(\'http://xmlns.com/foaf/0.1/:nick\', BLOG..blog_utf2wide(U_NAME)), \n', ses);
http ('			XMLELEMENT(\'http://xmlns.com/foaf/0.1/:mbox\', XMLATTRIBUTES(\'mailto:\'||U_E_MAIL as \'http://www.w3.org/1999/02/22-rdf-syntax-ns#:resource\')), \n', ses);
http ('			XMLELEMENT(\'http://xmlns.com/foaf/0.1/:homepage\', \n', ses);
http ('				XMLATTRIBUTES(BI_HOME_PAGE as \'http://www.w3.org/1999/02/22-rdf-syntax-ns#:resource\')), \n', ses);
http ('				XMLELEMENT(\'http://xmlns.com/foaf/0.1/:weblog\', \n', ses);
http ('					XMLATTRIBUTES(BI_HOME as \'http://www.w3.org/1999/02/22-rdf-syntax-ns#:resource\')), \n', ses);
http ('					XMLELEMENT(\'http://xmlns.com/foaf/0.1/:seeAlso\', \n', ses);
http ('					XMLATTRIBUTES(BI_HOME||\'gems/rss.xml\' as \'http://www.w3.org/1999/02/22-rdf-syntax-ns#:resource\'))))) \n', ses);
http ('			from BLOG..SYS_BLOG_INFO, DB.DBA.SYS_USERS, BLOG..SYS_BLOG_ATTACHES \n', ses);
http ('			where BA_C_BLOG_ID = BI_BLOG_ID and BA_M_BLOG_ID = :bid and BI_OWNER = U_ID\n', ses);
http ('	]]></sql:sqlx>\n', ses);
http ('</rdf:RDF>\n', ses);
  ses := string_output_string (ses);
  ses := replace (ses, '<UID>', cast (UID as varchar));
  return ses;
}
;


-- foaf.xml

CREATE PROCEDURE BLOG2_HOME_GET_FOAF_SQLX (IN UID INTEGER)
{
  declare ses any;
  ses := string_output ();
http ('<?xml version =\'1.0\' encoding=\'UTF-8\'?>\n', ses);
http ('<rdf:RDF xmlns:rdf=\'http://www.w3.org/1999/02/22-rdf-syntax-ns#\' xmlns:rdfs=\'http://www.w3.org/2000/01/rdf-schema#\' xmlns:foaf=\'http://xmlns.com/foaf/0.1/\' xmlns:dc=\'http://purl.org/dc/elements/1.1/\' xmlns:plan=\'http://usefulinc.com/ns/scutter/0.1#\'>\n', ses);
http ('<foaf:Person rdf:about="">\n', ses);
http ('<sql:sqlx xmlns:sql=\'urn:schemas-openlink-com:xml-sql\' sql:xsl="/DAV/VAD/blog2/widgets/foaf.xsl"><![CDATA[\n', ses);
http ('select\n', ses);
http ('XMLELEMENT(\'http://xmlns.com/foaf/0.1/:name\', BLOG..blog_utf2wide(U_FULL_NAME)),\n', ses);
http ('XMLELEMENT(\'http://xmlns.com/foaf/0.1/:nick\', U_NAME),\n', ses);
http ('XMLELEMENT(\'http://xmlns.com/foaf/0.1/:mbox\',\n', ses);
http ('XMLATTRIBUTES(\'mailto:\'||BI_E_MAIL as \'http://www.w3.org/1999/02/22-rdf-syntax-ns#:resource\')),\n', ses);
http ('XMLELEMENT(\'http://xmlns.com/foaf/0.1/:homepage\',\n', ses);
http ('XMLATTRIBUTES(\'http://\'||BLOG..BLOG_GET_HOST () ||BI_HOME_PAGE as \'http://www.w3.org/1999/02/22-rdf-syntax-ns#:resource\')),\n', ses);
http ('XMLELEMENT(\'http://xmlns.com/foaf/0.1/:weblog\',\n', ses);
http ('XMLATTRIBUTES(\'http://\'||BLOG..BLOG_GET_HOST () ||BI_HOME as \'http://www.w3.org/1999/02/22-rdf-syntax-ns#:resource\')),\n', ses);
http ('XMLELEMENT(\'http://xmlns.com/foaf/0.1/:seeAlso\',\n', ses);
http ('XMLATTRIBUTES(\'http://\'||BLOG..BLOG_GET_HOST () ||BI_HOME || \'gems/rss.xml\' as \'http://www.w3.org/1999/02/22-rdf-syntax-ns#:resource\'))\n', ses);
http ('from BLOG..SYS_BLOG_INFO, "DB"."DBA"."SYS_USERS" where BI_OWNER = U_ID and BI_BLOG_ID = \'<UID>\'\n', ses);
http (']]></sql:sqlx>\n', ses);
http ('<sql:sqlx xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'><![CDATA[\n', ses);
http ('select \n', ses);
http ('XMLELEMENT(\'http://www.w3.org/2000/01/rdf-schema#:seeAlso\',\n', ses);
http ('XMLELEMENT(\'http://purl.org/rss/1.0/:channel\',\n', ses);
http ('XMLATTRIBUTES(BCD_CHANNEL_URI as \'http://www.w3.org/1999/02/22-rdf-syntax-ns#:about\'), \n', ses);
http ('XMLELEMENT(\'http://purl.org/dc/elements/1.1/:title\', BLOG..blog_utf2wide (BCD_TITLE)), \n', ses);
http ('XMLELEMENT(\'http://purl.org/dc/elements/1.1/:description\', BLOG..blog_utf2wide (BCD_AUTHOR_NAME)) \n', ses);
http (' )) \n', ses);
http ('from BLOG..SYS_BLOG_CHANNELS, BLOG..SYS_BLOG_CHANNEL_INFO, BLOG..SYS_BLOG_CHANNEL_CATEGORY where BC_BLOG_ID = \'<UID>\' and BC_CHANNEL_URI = BCD_CHANNEL_URI and BC_CAT_ID = BCC_ID and BCC_BLOG_ID = BC_BLOG_ID and BCC_IS_BLOG = 1\n', ses);
http (']]></sql:sqlx>\n', ses);
http ('</foaf:Person>\n', ses);
http ('</rdf:RDF>\n', ses);
  ses := string_output_string (ses);
  ses := replace (ses, '<UID>', cast (UID as varchar));
  return ses;
}
;
-- opml.xml

CREATE PROCEDURE BLOG2_HOME_GET_OPML_MEMBER_SQLX (IN UID INTEGER, in rep int := 1)
{
  declare ses any;
  ses := string_output ();
http ('<opml version="1.0"><head></head>\n', ses);
http ('    <body xmlns:sql=\'urn:schemas-openlink-com:xml-sql\' sql:xsl="">\n', ses);
http ('	<sql:sqlx><![CDATA[\n', ses);
http ('	    select\n', ses);
http ('	    XMLAGG(XMLELEMENT(\'outline\',\n', ses);
http ('	    XMLATTRIBUTES(BLOG..blog_utf2wide(BI_TITLE) as \'title\', BLOG..blog_utf2wide(BI_TITLE) as \'text\', \'rss\' as \'type\', \'http://\'||BLOG..BLOG_GET_HOST () || BI_HOME as \'htmlUrl\', \n', ses);
http ('	    	\'http://\'||BLOG..BLOG_GET_HOST () || BI_HOME || \'gems/rss.xml\'  as \'xmlUrl\')))\n', ses);
http ('	    from BLOG.DBA.SYS_BLOG_INFO, BLOG.DBA.SYS_BLOG_ATTACHES where BI_BLOG_ID = BA_C_BLOG_ID and BA_M_BLOG_ID = \'<UID>\' \n', ses);
http ('		]]></sql:sqlx>\n', ses);
http ('	</body>\n', ses);
http ('</opml>\n', ses);
  ses := string_output_string (ses);
  if (rep)
    ses := replace (ses, 'sql:xsl=""', '');
  ses := replace (ses, '<UID>', cast (UID as varchar));
  return ses;
}
;
-- ocs.xml

CREATE PROCEDURE BLOG2_HOME_GET_OCS_MEMBER_SQLX (IN UID INTEGER)
{
  declare r any;
  r := BLOG2_HOME_GET_OPML_MEMBER_SQLX (UID, 0);
  r := replace (r, 'sql:xsl=""', 'sql:xsl="/DAV/VAD/blog2/widgets/opml2ocs.xsl"');
  return r;
}
;


-- opml-summary.xml

CREATE PROCEDURE BLOG2_HOME_GET_OPML_SUMMARY_XML (in uid integer, in rep int := 1)
{
  declare ses any;
  ses := string_output ();
    http ('<?xml version="1.0" encoding="UTF-8"?>\n', ses);
    http ('<opml xmlns:sql="urn:schemas-openlink-com:xml-sql" version="1.0" sql:xsl="">\n<head></head><body>\n', ses);
    http ('  <sql:header>\n', ses);
    http ('      <sql:param name=":bid"><UID></sql:param>\n', ses);
    http ('      <sql:param name=":posts">wbwA</sql:param>\n', ses);
    http ('  </sql:header>\n', ses);
    http ('  <sql:sqlx><![CDATA[\n', ses);
    http ('select \n', ses);
    http (' xmlelement (\'outline\',\n', ses);
    http (' xmlattributes (BLOG..blog_utf2wide(B_TITLE) as title, BLOG..blog_utf2wide(B_TITLE) as text, \'link\' as \'type\', \n', ses);
    http ('  \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()|| BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'?id=\'||B_POST_ID\n', ses);
    http ('                  as url))\n', ses);
    http ('                         from BLOG..SYS_BLOGS,\n', ses);
    http ('                                 BLOG..SYS_BLOG_INFO\n', ses);
    http ('                                 where BI_BLOG_ID = B_BLOG_ID\n', ses);
    http ('                                 and position (B_POST_ID, deserialize (decode_base64 (:posts))) \n', ses);
    http ('                                 \n', ses);
    http ('             ]]></sql:sqlx>\n', ses);
    http ('</body>\n</opml>\n', ses);
  ses := string_output_string (ses);
  if (rep)
    ses := replace (ses, 'sql:xsl=""', '');
  ses := replace (ses, '<UID>', cast (uid as varchar));
  return ses;
}
;

CREATE PROCEDURE BLOG2_HOME_GET_OCS_SUMMARY_SQLX (IN UID INTEGER)
{
  declare r any;
  r := BLOG2_HOME_GET_OPML_SUMMARY_XML (UID, 0);
  r := replace (r, 'sql:xsl=""', 'sql:xsl="/DAV/VAD/blog2/widgets/opml2ocs.xsl"');
  return r;
}
;

-- /* Archive GEMS */
create procedure BLOG2_HOME_GENERATE_RSS_ARCH_CAT_XML_SQLX(in blogid varchar,in rep int := 1)
{
  declare ses any;
  ses := string_output();
  http('<?xml version =\'1.0\' encoding=\'UTF-8\'?>\n', ses);
  http('<rss version="2.0">\n', ses);
  http('<channel xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'>\n', ses);
  http('<sql:header><sql:param name=":bid"> </sql:param><sql:param name=":cid"> </sql:param></sql:header>\n', ses);
  http('<sql:sqlx sql:xsl=\'\'><![CDATA[\n', ses);
  http('select \n', ses);
  http('XMLELEMENT(\'title\', BLOG..blog_utf2wide (BI_TITLE)), \n', ses);
  http('XMLELEMENT(\'link\', \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()||BI_HOME), \n', ses);
  http('XMLELEMENT(\'description\', BLOG..blog_utf2wide (BI_ABOUT)), \n', ses);
  http('XMLELEMENT(\'managingEditor\', BI_E_MAIL), \n', ses);
  http('XMLELEMENT(\'pubDate\', BLOG.DBA.date_rfc1123(now())), \n', ses);
  http('XMLELEMENT(\'generator\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', ses);
  http('XMLELEMENT(\'webMaster\', BI_E_MAIL), \n', ses);
  http('XMLELEMENT(\'image\', \n', ses);
  http('XMLELEMENT(\'title\', BLOG..blog_utf2wide (BI_TITLE)), \n', ses);
  http('XMLELEMENT(\'url\', \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || \'/weblog/public/images/vbloglogo.gif\'), \n', ses);
  http('XMLELEMENT(\'link\', \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)), \n', ses);
  http('XMLELEMENT(\'description\', BLOG..blog_utf2wide (BI_ABOUT)), \n', ses);
  http('XMLELEMENT(\'width\', \'88\'), \n', ses);
  http('XMLELEMENT(\'height\', \'31\')) \n', ses);
  http('from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = :bid\n', ses);
  http(']]></sql:sqlx>\n', ses);
  http('<sql:sqlx><![CDATA[\n', ses);
  http('select \n', ses);
  http('XMLAGG(XMLELEMENT(\'item\',\n', ses);
  http('XMLELEMENT(\'title\', BLOG..blog_utf2wide (B_TITLE)),\n', ses);
  http('XMLELEMENT(\'guid\', \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()||BI_HOME||\'?date=\'||substring (datestring (B_TS), 1, 10)||\'#\'||B_POST_ID),\n', ses);
  http('XMLELEMENT(\'comments\', \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()||BI_HOME||\'?id=\'||B_POST_ID||\'#comments\'),\n', ses);
  http('XMLELEMENT(\'pubDate\', BLOG.DBA.date_rfc1123 (B_TS)),\n', ses);
  http('XMLELEMENT(\'description\', BLOG..blog_utf2wide (B_CONTENT)), \n', ses);
  http('XMLELEMENT(\'http://www.openlinksw.com/weblog/:modified\', BLOG..date_iso8601 (B_MODIFIED)) )) \n', ses);
  http('from\n', ses);

  http('(select B_CONTENT, B_TS, B_TITLE, BI_HOME, B_POST_ID, B_MODIFIED from\n', ses);
  http ('BLOG..SYS_BLOGS, BLOG..SYS_BLOG_INFO,
        (select BI_BLOG_ID as BA_C_BLOG_ID, BI_BLOG_ID as BA_M_BLOG_ID from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = :bid
        union all select * from (select BA_C_BLOG_ID, BA_M_BLOG_ID from BLOG.DBA.SYS_BLOG_ATTACHES
          where BA_M_BLOG_ID = :bid) name1) name2
      where B_BLOG_ID = BA_C_BLOG_ID and B_STATE = 2 and BI_BLOG_ID = B_BLOG_ID and \n', ses);
  http('exists (select 1 from BLOG..MTYPE_BLOG_CATEGORY where MTB_CID = :cid and MTB_BLOG_ID = B_BLOG_ID and MTB_POST_ID = B_POST_ID) order by B_TS desc\n', ses);
  http(') sub\n', ses);

  http(']]>\n', ses);
  http('</sql:sqlx>\n', ses);
  http('</channel>\n', ses);
  http('</rss>\n', ses);
  ses := string_output_string (ses);
  if (rep)
  ses := replace (ses, 'sql:xsl=\'\'', '');
  return ses;
}
;

create procedure BLOG2_HOME_GENERATE_RSS_ARCH_DATE_XML_SQLX(in blogid varchar,in rep int := 1)
{
  declare ses any;
  ses := string_output();
  http('<?xml version =\'1.0\' encoding=\'UTF-8\'?>\n', ses);
  http('<rss version="2.0">\n', ses);
  http('<channel xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'>\n', ses);
  http('<sql:header><sql:param name=":bid"> </sql:param><sql:param name=":sel"> </sql:param></sql:header>\n', ses);
  http('<sql:sqlx sql:xsl=\'\'><![CDATA[\n', ses);
  http('select \n', ses);
  http('XMLELEMENT(\'title\', BLOG..blog_utf2wide (BI_TITLE)), \n', ses);
  http('XMLELEMENT(\'link\', \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()||BI_HOME), \n', ses);
  http('XMLELEMENT(\'description\', BLOG..blog_utf2wide (BI_ABOUT)), \n', ses);
  http('XMLELEMENT(\'managingEditor\', BI_E_MAIL), \n', ses);
  http('XMLELEMENT(\'pubDate\', BLOG.DBA.date_rfc1123(now())), \n', ses);
  http('XMLELEMENT(\'generator\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', ses);
  http('XMLELEMENT(\'webMaster\', BI_E_MAIL), \n', ses);
  http('XMLELEMENT(\'image\', \n', ses);
  http('XMLELEMENT(\'title\', BLOG..blog_utf2wide (BI_TITLE)), \n', ses);
  http('XMLELEMENT(\'url\', \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || \'/weblog/public/images/vbloglogo.gif\'), \n', ses);
  http('XMLELEMENT(\'link\', \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)), \n', ses);
  http('XMLELEMENT(\'description\', BLOG..blog_utf2wide (BI_ABOUT)), \n', ses);
  http('XMLELEMENT(\'width\', \'88\'), \n', ses);
  http('XMLELEMENT(\'height\', \'31\')) \n', ses);
  http('from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = :bid\n', ses);
  http(']]></sql:sqlx>\n', ses);
  http('<sql:sqlx><![CDATA[\n', ses);
  http('select \n', ses);
  http('XMLAGG(XMLELEMENT(\'item\',\n', ses);
  http('XMLELEMENT(\'title\', BLOG..blog_utf2wide (B_TITLE)),\n', ses);
  http('XMLELEMENT(\'guid\', \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()||BI_HOME||\'?date=\'||substring (datestring (B_TS), 1, 10)||\'#\'||B_POST_ID),\n', ses);
  http('XMLELEMENT(\'comments\', \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()||BI_HOME||\'?id=\'||B_POST_ID||\'#comments\'),\n', ses);
  http('XMLELEMENT(\'pubDate\', BLOG.DBA.date_rfc1123 (B_TS)),\n', ses);
  http('XMLELEMENT(\'description\', BLOG..blog_utf2wide (BLOG.DBA.BLOG2_POST_RENDER(B_CONTENT, \'*default*\'))), \n', ses);
  http('XMLELEMENT(\'http://www.openlinksw.com/weblog/:modified\', BLOG..date_iso8601 (B_MODIFIED)) )) \n', ses);
  http('from\n', ses);

  http('(select p.B_CONTENT, ar.B_TS, ar.B_TITLE, BI_HOME, ar.B_POST_ID, p.B_MODIFIED from\n', ses);
  http (' BLOG..BLOG_ARCH_DATE_POSTS ar, BLOG..SYS_BLOGS p, BLOG..SYS_BLOG_INFO where blogid = :bid and community = 1
        and sel = :sel and ar.B_POST_ID = p.B_POST_ID and BI_BLOG_ID = p.B_BLOG_ID
        \n', ses);
  http(' order by ar.B_TS desc option (order)\n', ses);
  http(') sub\n', ses);

  http(']]>\n', ses);
  http('</sql:sqlx>\n', ses);
  http('</channel>\n', ses);
  http('</rss>\n', ses);
  ses := string_output_string (ses);
  if (rep)
  ses := replace (ses, 'sql:xsl=\'\'', '');
  return ses;
}
;

create procedure BLOG2_HOME_GENERATE_ATOM_ARCH_CAT_XML_SQLX(in blogid varchar)
{
  declare r any;
  declare xsl any;
  xsl := BLOG_GET_ATOM_XSL ();
  r := BLOG2_HOME_GENERATE_RSS_ARCH_CAT_XML_SQLX (blogid,0);
  r := replace (r, 'sql:xsl=\'\'', 'sql:xsl="/DAV/VAD/blog2/widgets/'||xsl||'"');
  return r;
};

create procedure BLOG2_HOME_GENERATE_ATOM_ARCH_DATE_XML_SQLX(in blogid varchar)
{
  declare r any;
  declare xsl any;
  xsl := BLOG_GET_ATOM_XSL ();
  r := BLOG2_HOME_GENERATE_RSS_ARCH_DATE_XML_SQLX (blogid,0);
  r := replace (r, 'sql:xsl=\'\'', 'sql:xsl=\'/DAV/VAD/blog2/widgets/'||xsl||'\'');
  return r;
};

create procedure BLOG2_HOME_GENERATE_RDF_ARCH_CAT_XML_SQLX(in blogid varchar)
{
  declare r any;
  declare xsl any;
  xsl := BLOG_GET_ATOM_XSL ();
  r := BLOG2_HOME_GENERATE_RSS_ARCH_CAT_XML_SQLX (blogid,0);
  r := replace (r, 'sql:xsl=\'\'', 'sql:xsl=\'/DAV/VAD/blog2/widgets/rss2rdf.xsl\'');
  return r;
};

create procedure BLOG2_HOME_GENERATE_RDF_ARCH_DATE_XML_SQLX(in blogid varchar)
{
  declare r any;
  r := BLOG2_HOME_GENERATE_RSS_ARCH_DATE_XML_SQLX (blogid,0);
  r := replace (r, 'sql:xsl=\'\'', 'sql:xsl=\'/DAV/VAD/blog2/widgets/rss2rdf.xsl\'');
  return r;
};


CREATE PROCEDURE BLOG2_HOME_GENERATE_OPML_ARCH_DATE_XML_SQLX (in UID any, in rep int := 1)
{
  declare ses any;
  ses := string_output ();
    http ('<?xml version="1.0" encoding="UTF-8"?>\n', ses);
    http ('<opml xmlns:sql="urn:schemas-openlink-com:xml-sql" sql:xsl=\'\' version="1.0">\n', ses);
    http ('  <sql:header>\n', ses);
    http ('      <sql:param name=":bid"><UID></sql:param>\n', ses);
    http ('  </sql:header>\n<head>\n', ses);
    http ('  <sql:sqlx><![CDATA[\n', ses);
    http (' select xmlelement (title, BI_TITLE) from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = :bid\n', ses);
    http (' ]]></sql:sqlx></head><body>\n', ses);
    http ('  <sql:sqlx><![CDATA[\n', ses);
    http ('select \n', ses);
    http (' xmlelement (\'outline\',\n', ses);
    http ('             xmlattributes (monthname||\', \'||cast (year as varchar) as title, \n', ses);
    http ('                  \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()||
      			     BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'gems/rss_date_arch.xml?:bid=\' ||
			        BI_BLOG_ID || sprintf (\'&:sel=%d-%d\', year, month) \n', ses);
    http ('                  as xmlUrl, \'rss\' as \'type\', monthname||\', \'||cast (year as varchar) as text))\n', ses);
    http ('                  from
				(select distinct BI_BLOG_ID, BI_HOME, year (B_TS) as year, month (B_TS) as month, monthname(B_TS) as monthname
				 from BLOG..BLOG_ARCH_DATE_POSTS, BLOG..SYS_BLOG_INFO where blogid = :bid and community = 1
				 and BI_BLOG_ID = blogid
				 ) sub
				\n', ses);
    http ('             ]]></sql:sqlx>\n', ses);
    http ('</body>\n</opml>\n', ses);
  ses := string_output_string (ses);
  ses := replace (ses, '<UID>', cast (UID as varchar));
  if (rep)
  ses := replace (ses, 'sql:xsl=\'\'', '');
  return ses;
}
;

CREATE PROCEDURE BLOG2_HOME_GENERATE_OPML_ARCH_YEAR_XML_SQLX (IN UID any, in rep int := 1)
{
  declare ses any;
  ses := string_output ();
    http ('<?xml version="1.0" encoding="UTF-8"?>\n', ses);
    http ('<opml xmlns:sql="urn:schemas-openlink-com:xml-sql" sql:xsl=\'\' version="1.0">\n', ses);
    http ('  <sql:header>\n', ses);
    http ('      <sql:param name=":bid"><UID></sql:param>\n', ses);
    http ('  </sql:header>\n<head>\n', ses);
    http ('  <sql:sqlx><![CDATA[\n', ses);
    http (' select xmlelement (title, BI_TITLE) from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = :bid\n', ses);
    http (' ]]></sql:sqlx></head><body>\n', ses);
    http ('  <sql:sqlx><![CDATA[\n', ses);
    http ('select \n', ses);
    http (' xmlelement (\'outline\',\n', ses);
    http ('             xmlattributes (cast (year as varchar) as title, cast (year as varchar) as text, \'rss\' as \'type\', \n', ses);
    http ('                  \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()||
      			     BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'gems/rss_date_arch.xml?:bid=\' ||
			        BI_BLOG_ID || sprintf (\'&:sel=%d\', year) \n', ses);
    http ('                  as xmlUrl))\n', ses);
    http ('                  from
				(select distinct BI_BLOG_ID, BI_HOME, year (B_TS) as year
				 from BLOG..BLOG_ARCH_DATE_POSTS, BLOG..SYS_BLOG_INFO where blogid = :bid and community = 1
				 and BI_BLOG_ID = blogid
				 ) sub
				\n', ses);
    http ('             ]]></sql:sqlx>\n', ses);
    http ('</body>\n</opml>\n', ses);
  ses := string_output_string (ses);
  ses := replace (ses, '<UID>', cast (UID as varchar));
  if (rep)
  ses := replace (ses, 'sql:xsl=\'\'', '');
  return ses;
}
;


CREATE PROCEDURE BLOG2_HOME_GENERATE_OPML_ARCH_CAT_XML_SQLX (IN UID any, in rep int := 1)
{
  declare ses any;
  ses := string_output ();
    http ('<?xml version="1.0" encoding="UTF-8"?>\n', ses);
    http ('<opml xmlns:sql="urn:schemas-openlink-com:xml-sql" sql:xsl=\'\' version="1.0">\n', ses);
    http ('  <sql:header>\n', ses);
    http ('      <sql:param name=":bid"><UID></sql:param>\n', ses);
    http ('  </sql:header>\n<head>\n', ses);
    http ('  <sql:sqlx><![CDATA[\n', ses);
    http (' select xmlelement (title, BI_TITLE) from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = :bid\n', ses);
    http (' ]]></sql:sqlx></head><body>\n', ses);
    http ('  <sql:sqlx><![CDATA[\n', ses);
    http ('select \n', ses);
    http (' xmlelement (\'outline\',\n', ses);
    http ('             xmlattributes (MTC_NAME as title, MTC_NAME as text, \'rss\' as type, \n', ses);
    http ('                  \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()||
      			     BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'gems/rss_cat_arch.xml?:bid=\' ||
			        BI_BLOG_ID || sprintf (\'&:cid=%s\', MTC_ID) \n', ses);
    http ('                  as xmlUrl))\n', ses);
    http ('                  from
				(
	  select distinct BI_HOME, BI_BLOG_ID, MTC_ID, MTC_NAME
	  from BLOG..SYS_BLOGS,
	  (select BI_BLOG_ID as BA_C_BLOG_ID, BI_BLOG_ID as BA_M_BLOG_ID from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = :bid
	  union all
	  select * from (select BA_C_BLOG_ID, BA_M_BLOG_ID from BLOG.DBA.SYS_BLOG_ATTACHES where BA_M_BLOG_ID = :bid
	  ) name1) name2,
	  BLOG..SYS_BLOG_INFO,
	  BLOG..MTYPE_CATEGORIES, BLOG..MTYPE_BLOG_CATEGORY where  B_BLOG_ID = BA_C_BLOG_ID and BI_BLOG_ID = B_BLOG_ID and
	  MTB_BLOG_ID = B_BLOG_ID and MTB_POST_ID = B_POST_ID and MTB_CID = MTC_ID and MTC_BLOG_ID = MTB_BLOG_ID
				 ) sub
				\n', ses);
    http ('             ]]></sql:sqlx>\n', ses);
    http ('</body>\n</opml>\n', ses);
  ses := string_output_string (ses);
  ses := replace (ses, '<UID>', cast (UID as varchar));
  if (rep)
  ses := replace (ses, 'sql:xsl=\'\'', '');
  return ses;
}
;

create procedure BLOG2_HOME_GENERATE_OCS_ARCH_DATE_XML_SQLX (in blogid varchar)
{
  declare r any;
  r := BLOG2_HOME_GENERATE_OPML_ARCH_DATE_XML_SQLX (blogid,0);
  r := replace (r, 'sql:xsl=\'\'', 'sql:xsl=\'/DAV/VAD/blog2/widgets/opml2ocs.xsl\'');
  return r;
};

create procedure BLOG2_HOME_GENERATE_OCS_ARCH_YEAR_XML_SQLX (in blogid varchar)
{
  declare r any;
  r := BLOG2_HOME_GENERATE_OPML_ARCH_YEAR_XML_SQLX (blogid,0);
  r := replace (r, 'sql:xsl=\'\'', 'sql:xsl=\'/DAV/VAD/blog2/widgets/opml2ocs.xsl\'');
  return r;
};


create procedure BLOG2_HOME_GENERATE_OCS_ARCH_CAT_XML_SQLX (in blogid varchar)
{
  declare r any;
  r := BLOG2_HOME_GENERATE_OPML_ARCH_CAT_XML_SQLX (blogid,0);
  r := replace (r, 'sql:xsl=\'\'', 'sql:xsl=\'/DAV/VAD/blog2/widgets/opml2ocs.xsl\'');
  return r;
};

create procedure BLOG.DBA.IS_REGULAR_FEED ()
{
  if (connection_get ('Atom_Self_URI') is null)
    return 1;
  return 0;
};

create procedure BLOG.DBA.GET_HTTP_URL ()
{
  declare host, path, qstr, conn any;

  conn := connection_get ('Atom_Self_URI');

  if (conn is not null)
    return conn;

  host := BLOG_GET_HOST ();
  path := http_path ();
  qstr := http_request_get ('QUERY_STRING');
  if (length (qstr))
    qstr := '?' || qstr;
  return 'http://' || host || path || qstr;
};

create procedure BLOG.DBA.EXPAND_URL (in url varchar)
{
  declare base, ret varchar;
  --dbg_obj_print ('url:',url);
  base := soap_current_url ();
  if (base is not null)
    {
      base := WS.WS.EXPAND_URL (base, http_path ());
    ret := WS.WS.EXPAND_URL (base, url);
    }
  else
    ret := url;
  return ret;
};

grant execute on BLOG.DBA.GET_HTTP_URL to public;
grant execute on BLOG.DBA.EXPAND_URL to public;
grant execute on BLOG.DBA.BLOG2_GET_HOST to public;
grant execute on BLOG.DBA.IS_REGULAR_FEED to public;

xpf_extension ('http://www.openlinksw.com/weblog/:getHttpUrl', 'BLOG.DBA.GET_HTTP_URL');
xpf_extension ('http://www.openlinksw.com/weblog/:getExpandUrl', 'BLOG.DBA.EXPAND_URL');
xpf_extension ('http://www.openlinksw.com/weblog/:getHost', 'BLOG.DBA.BLOG2_GET_HOST');
xpf_extension ('http://www.openlinksw.com/weblog/:isRegularFeed', 'BLOG.DBA.IS_REGULAR_FEED');

create procedure BLOG2_HOME_GENERATE_RSS_ARCH_TAG_XML_SQLX(in blogid varchar,in rep int := 1)
{
  declare ses any;
  ses := string_output();
  http('<?xml version =\'1.0\' encoding=\'UTF-8\'?>\n', ses);
  http('<rss version="2.0">\n', ses);
  http('<channel xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'>\n', ses);
  http('<sql:header><sql:param name=":bid"> </sql:param><sql:param name=":tag"> </sql:param></sql:header>\n', ses);
  http('<sql:sqlx sql:xsl=\'\'><![CDATA[\n', ses);
  http('select \n', ses);
  http('XMLELEMENT(\'title\', BI_TITLE), \n', ses);
  http('XMLELEMENT(\'link\', \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()||BI_HOME), \n', ses);
  http('XMLELEMENT(\'description\', BI_ABOUT), \n', ses);
  http('XMLELEMENT(\'managingEditor\', BI_E_MAIL), \n', ses);
  http('XMLELEMENT(\'pubDate\', BLOG.DBA.date_rfc1123(now())), \n', ses);
  http('XMLELEMENT(\'generator\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', ses);
  http('XMLELEMENT(\'webMaster\', BI_E_MAIL), \n', ses);
  http('XMLELEMENT(\'image\', \n', ses);
  http('XMLELEMENT(\'title\', BI_TITLE), \n', ses);
  http('XMLELEMENT(\'url\', \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || \'/weblog/public/images/vbloglogo.gif\'), \n', ses);
  http('XMLELEMENT(\'link\', \'http://\' || BLOG.DBA.BLOG2_GET_HOST () || BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)), \n', ses);
  http('XMLELEMENT(\'description\', BI_ABOUT), \n', ses);
  http('XMLELEMENT(\'width\', \'88\'), \n', ses);
  http('XMLELEMENT(\'height\', \'31\')) \n', ses);
  http('from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = :bid\n', ses);
  http(']]></sql:sqlx>\n', ses);
  http('<sql:sqlx><![CDATA[\n', ses);
  http('select \n', ses);
  http('XMLAGG(XMLELEMENT(\'item\',\n', ses);
  http('XMLELEMENT(\'title\', BLOG..blog_utf2wide (B_TITLE)),\n', ses);
  http('XMLELEMENT(\'guid\', \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()||BI_HOME||\'?date=\'||substring (datestring (B_TS), 1, 10)||\'#\'||B_POST_ID),\n', ses);
  http('XMLELEMENT(\'comments\', \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()||BI_HOME||\'?id=\'||B_POST_ID||\'#comments\'),\n', ses);
  http('XMLELEMENT(\'pubDate\', BLOG.DBA.date_rfc1123 (B_TS)),\n', ses);
  http('XMLELEMENT(\'http://www.openlinksw.com/weblog/:modified\', BLOG..date_iso8601 (B_MODIFIED)),\n', ses);
  http('XMLELEMENT(\'description\', BLOG..blog_utf2wide (B_CONTENT))))\n', ses);
  http('from\n', ses);

  http('(select B_CONTENT, B_TS, B_TITLE, BI_HOME, B_POST_ID, B_MODIFIED from\n', ses);
  http (' BLOG..BLOG_TAGS_STAT_EXT, BLOG..SYS_BLOGS, BLOG..SYS_BLOG_INFO where blogid = :bid and community = 1
        and BT_TAG = :tag and B_POST_ID = BT_POST_ID and BI_BLOG_ID = B_BLOG_ID
        \n', ses);
  http(' order by B_TS desc option (order)\n', ses);
  http(') sub\n', ses);

  http(']]>\n', ses);
  http('</sql:sqlx>\n', ses);
  http('</channel>\n', ses);
  http('</rss>\n', ses);
  ses := string_output_string (ses);
  if (rep)
  ses := replace (ses, 'sql:xsl=\'\'', '');
  return ses;
}
;

create procedure BLOG2_HOME_GENERATE_ATOM_ARCH_TAG_XML_SQLX(in blogid varchar)
{
  declare r any;
  r := BLOG2_HOME_GENERATE_RSS_ARCH_TAG_XML_SQLX (blogid,0);
  r := replace (r, 'sql:xsl=\'\'', 'sql:xsl=\'/DAV/VAD/blog2/widgets/rss2atom.xsl\'');
   return r;
};

create procedure BLOG2_HOME_GENERATE_RDF_ARCH_TAG_XML_SQLX(in blogid varchar)
{
  declare r any;
  r := BLOG2_HOME_GENERATE_RSS_ARCH_TAG_XML_SQLX (blogid,0);
  r := replace (r, 'sql:xsl=\'\'', 'sql:xsl=\'/DAV/VAD/blog2/widgets/rss2rdf.xsl\'');
  return r;
};

CREATE PROCEDURE BLOG2_HOME_GENERATE_OPML_ARCH_TAG_XML_SQLX (IN UID INTEGER, in rep int := 1)
{
  declare ses any;
  ses := string_output ();
    http ('<?xml version="1.0" encoding="UTF-8"?>\n', ses);
    http ('<opml xmlns:sql="urn:schemas-openlink-com:xml-sql" sql:xsl=\'\' version="1.0">\n', ses);
    http ('  <sql:header>\n', ses);
    http ('      <sql:param name=":bid"><UID></sql:param>\n', ses);
    http ('  </sql:header>\n<head>\n', ses);
    http ('  <sql:sqlx><![CDATA[\n', ses);
    http (' select xmlelement (title, BI_TITLE) from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = :bid\n', ses);
    http (' ]]></sql:sqlx></head><body>\n', ses);
    http ('  <sql:sqlx><![CDATA[\n', ses);
    http ('select \n', ses);
    http (' xmlelement (\'outline\',\n', ses);
    http ('             xmlattributes (BT_TAG as title, BT_TAG as text, \'rss\' as \'type\', \n', ses);
    http ('                  \'http://\'|| BLOG.DBA.BLOG2_GET_HOST ()||
      			     BLOG.DBA.BLOG2_GET_HOME_DIR (BI_HOME)||\'gems/rss_tag_arch.xml?:bid=\' ||
			        BI_BLOG_ID || sprintf (\'&:tag=%s\', BT_TAG) \n', ses);
    http ('                  as xmlUrl))\n', ses);
    http ('                  from
				(select distinct BI_BLOG_ID, BI_HOME, BT_TAG
				 from BLOG..BLOG_TAGS_STAT_EXT, BLOG..SYS_BLOG_INFO where blogid = :bid and community = 1
				 and BI_BLOG_ID = blogid
				 ) sub
				\n', ses);
    http ('             ]]></sql:sqlx>\n', ses);
    http ('</body>\n</opml>\n', ses);
  ses := string_output_string (ses);
  ses := replace (ses, '<UID>', cast (UID as varchar));
  if (rep)
  ses := replace (ses, 'sql:xsl=\'\'', '');
  return ses;
}
;

create procedure BLOG2_HOME_GENERATE_OCS_ARCH_TAG_XML_SQLX (in blogid any)
{
  declare r any;
  r := BLOG2_HOME_GENERATE_OPML_ARCH_TAG_XML_SQLX (blogid,0);
  r := replace (r, 'sql:xsl=\'\'', 'sql:xsl=\'/DAV/VAD/blog2/widgets/opml2ocs.xsl\'');
  return r;
};

create procedure
BLOG_SET_WA_OPTS (in uname varchar, inout user_opts any, inout data any, inout _opts any, inout photo any, inout audio any, inout fname any, inout addr any)
{
  declare opts, inter any;
  opts := _opts;
  inter := DB.DBA.WA_USER_TAG_GET (uname);
  opts := BLOG.DBA.BLOG2_SET_OPTION('ShowName',  opts, length (data[3]));
  opts := BLOG.DBA.BLOG2_SET_OPTION('ShowPhoto', opts, length (data[37]));
  opts := BLOG.DBA.BLOG2_SET_OPTION('ShowAudio', opts, length (data[43]));
  opts := BLOG.DBA.BLOG2_SET_OPTION('ShowEmail', opts, length (data[4]));
  opts := BLOG.DBA.BLOG2_SET_OPTION('ShowAim',   opts, length (data[12]));
  opts := BLOG.DBA.BLOG2_SET_OPTION('ShowIcq',   opts, length (data[10]));
  opts := BLOG.DBA.BLOG2_SET_OPTION('ShowYahoo', opts, length (data[13]));
  opts := BLOG.DBA.BLOG2_SET_OPTION('ShowMsn',   opts, length (data[14]));
  opts := BLOG.DBA.BLOG2_SET_OPTION('ShowWeb',   opts, length (data[7]));
  opts := BLOG.DBA.BLOG2_SET_OPTION('ShowLoc',   opts, length (data[16][2]));
  opts := BLOG.DBA.BLOG2_SET_OPTION('ShowBio',   opts, length (data[34]));
  opts := BLOG.DBA.BLOG2_SET_OPTION('ShowInt',   opts, length (inter));
  opts := BLOG.DBA.BLOG2_SET_OPTION('ShowFav',   opts, length (data[44]));

  --opts := BLOG.DBA.BLOG2_SET_OPTION('Biography', opts, data[34]);

  if (__proc_exists ('DB.DBA.WA_USER_SVC_KEYS') is not null and isarray (opts))
    {
      declare keys, uid any;
      uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);
      keys := DB.DBA.WA_USER_SVC_KEYS (uid);
      for (declare i, l int, i := 0, l := length (keys); i < l; i := i + 2)
      {
	opts := BLOG.DBA.BLOG2_SET_OPTION (keys[i], opts, keys[i+1]);
      }
    }
  else
    {
  opts := BLOG.DBA.BLOG2_SET_OPTION('GoogleKey', opts, get_keyword ('GoogleKey', user_opts));
  opts := BLOG.DBA.BLOG2_SET_OPTION('GoogleAdsenseID', opts, get_keyword ('GoogleAdsenseID', user_opts));
  opts := BLOG.DBA.BLOG2_SET_OPTION('AmazonKey', opts, get_keyword ('AmazonKey', user_opts));
  opts := BLOG.DBA.BLOG2_SET_OPTION('AmazonID', opts, get_keyword ('AmazonID', user_opts));
  opts := BLOG.DBA.BLOG2_SET_OPTION('EbayID', opts, get_keyword ('EbayID', user_opts));
  opts := BLOG.DBA.BLOG2_SET_OPTION('AssociateID', opts, get_keyword ('AssociateID', user_opts));
  opts := BLOG.DBA.BLOG2_SET_OPTION('Vendor', opts, get_keyword ('Vendor', user_opts));
    }

  photo := data[37];
  audio := data[43];
  fname := data[3];
  addr  := data[16][0];
  if (length (addr) and length (data[16][2]))
    addr := addr || ', ' || data[16][2];
  else if (length (data[16][2]))
    addr := data[16][2];
  _opts := opts;
}
;

create procedure cm_root_node (in postid varchar)
{
  declare xt any;
  xt := (select xmlagg (xmlelement ('node', xmlattributes (BM_ID as id, BM_ID as name, BM_POST_ID as post)))
  	from BLOG..BLOG_COMMENTS where BM_POST_ID = postid and BM_REF_ID is null order by BM_TS);
--  dbg_printf ('postid=%s', postid);
  return xpath_eval ('//node', xt, 0);
};

create procedure cm_child_node (in postid varchar, inout node any)
{
  declare cm_ref_id int;
  declare xt any;
  cm_ref_id := xpath_eval ('number (@id)', node);
  postid := xpath_eval ('@post', node);
--  dbg_printf ('postid=[%s] cm_ref_id=[%d]', postid, cm_ref_id);

  xt := (select xmlagg (xmlelement ('node', xmlattributes (BM_ID as id, BM_ID as name, BM_POST_ID as post)))
  	from BLOG..BLOG_COMMENTS where BM_POST_ID = postid and BM_REF_ID = cm_ref_id order by BM_TS);
  return xpath_eval ('//node', xt, 0);
};
