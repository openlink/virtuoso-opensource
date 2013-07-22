--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2013 OpenLink Software
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

-- RDF Import API
--
create procedure rdf_import (
  in pURL varchar,
  in pMode integer := 1,
  in pGraph varchar := null,
  in pUser varchar := null,
  in pPassword varchar := null,
  in pFolder varchar := null)
{
  declare retValue, rc, user_id integer;
	declare S, content, hdr any;

  user_id := null;
  if (not isnull (pUser)) {
    user_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = pUser and pwd_magic_calc (U_NAME, U_PASSWORD, 1) = pPassword);
    if (isnull (user_id))
  	  signal ('ODS11', 'Bad user name or password');
  }
  if (isnull (pGraph))
    pGraph := pURL;
  if (not isnull (user_id)) {
    if (isnull (pFolder)) {
      pFolder := DB.DBA.DAV_HOME_DIR(pUser);
      if (isstring (pFolder)) {
        pFolder := pFolder || 'Uploads/';
        DB.DBA.DAV_MAKE_DIR (pFolder, user_id, user_id, '110100100NN');

        pFolder := pFolder || 'RDF/';
        DB.DBA.DAV_MAKE_DIR (pFolder, user_id, user_id, '110100100NN');
      }
    }
    -- RDF
    pFolder := pFolder || replace ( replace ( replace ( replace ( replace ( replace ( replace (pUrl, '/', '_'), chr(92), '_'), ':', '_'), '+', '_'), '\"', '_'), '[', '_'), ']', '_') || '.RDF';
    DB.DBA.DAV_DELETE_INT (pFolder, 1, null, null, 0);

    content := '';
    S := sprintf ('http://%s/sparql?default-graph-uri=%U&query=%U&format=%U', DB.DBA.wa_cname (), pGraph, 'CONSTRUCT { ?s ?p ?o} WHERE {?s ?p ?o}', 'text/xml');
    rc := DB.DBA.DAV_RES_UPLOAD_STRSES_INT (pFolder, content, 'text/xml', '111101101NN', user_id, user_id, pUser, pPassword, 1);
    if (isnull (DAV_HIDE_ERROR (rc)))
  	  signal ('ODS12', DAV_PERROR (rc));
    rc := DB.DBA.DAV_PROP_SET_INT (pFolder, 'redirectref', S, pUser, pPassword, 1, 0, 1);
    if (isnull (DAV_HIDE_ERROR (rc)))
  	  signal ('ODS12', DAV_PERROR (rc));
  }
  retValue := (select count(*) from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (pGraph));
  if (pMode) {
    exec (sprintf ('SPARQL define get:soft "soft" define get:uri "%s" SELECT * FROM <%s> WHERE { ?s ?p ?o }', pURL, pGraph));
  } else {
    commit work;
  	content := http_get (pURL, hdr, 'GET');
  	if (hdr[0] not like 'HTTP%200%')
  	  signal ('22023', hdr[0]);

  	declare is_ttl, is_xml integer;
    {
      declare continue handler for SQLSTATE '*' {
        is_ttl := 0;
      };
      is_ttl := 1;
      DB.DBA.RDF_TTL2HASH (content, pGraph, pGraph);
    }
    if (not is_ttl) {
      {
        declare continue handler for SQLSTATE '*' {
          is_xml := 0;
        };
        is_xml := 1;
        xtree_doc (content, 0, pGraph);
      }
    }
    if (is_xml = 0 and is_ttl = 0) {
      if (not isnull (pFolder))
        DB.DBA.DAV_DELETE_INT (pFolder, 1, null, null, 0);
      signal ('ODS10', 'You have attempted to upload invalid data. You can only upload RDF, Turtle, N3 serializations of RDF Data to the RDF Data Store!');
    }

    if (is_ttl) {
      DB.DBA.TTLP (content, pGraph, pGraph);
    } else {
      DB.DBA.RDF_LOAD_RDFXML (content, pGraph, pGraph);
    }
  }
  retValue := (select count(*) from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (pGraph)) - retValue;
  if (retValue < 0)
    retValue := 0;

  return retValue;
}
;

--
--
create procedure rdf_import_ext (
  in pSource varchar,
  in pSourceMimeType varchar := null,
  in pSourceType varchar := 'URL',
  in pSpongerMode integer := 1,
  in pGraph varchar := null,
  in pUser varchar := null,
  in pPassword varchar := null,
  in pFolder varchar := null)
{
  declare retValue, rc, user_id integer;
	declare S, content, hdr any;

  if (pSourceType not in ('string', 'URL'))
	  signal ('ODS13', 'Content source must be \'string\' or \'URL\'');
  if ((pSourceType = 'string') and isnull (pSourceMimeType))
	  signal ('ODS13', 'Mime Type must be set when content is string');
  if ((pSourceType = 'string') and isnull (pGraph))
	  signal ('ODS13', 'Graph must be set when content is string');

  user_id := null;
  if (not isnull (pUser)) {
    user_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = pUser and pwd_magic_calc (U_NAME, U_PASSWORD, 1) = pPassword);
    if (isnull (user_id))
  	  signal ('ODS11', 'Bad user name or password');
  }
  if (isnull (pGraph))
    pGraph := pSource;
  if (not isnull (user_id)) {
    if (isnull (pFolder)) {
      pFolder := DB.DBA.DAV_HOME_DIR(pUser);
      if (isstring (pFolder)) {
        pFolder := pFolder || 'Uploads/';
        DB.DBA.DAV_MAKE_DIR (pFolder, user_id, user_id, '110100100NN');

        pFolder := pFolder || 'RDF/';
        DB.DBA.DAV_MAKE_DIR (pFolder, user_id, user_id, '110100100NN');
      }
    }
    -- RDF
    pFolder := pFolder || replace ( replace ( replace ( replace ( replace ( replace ( replace (pGraph, '/', '_'), chr(92), '_'), ':', '_'), '+', '_'), '\"', '_'), '[', '_'), ']', '_') || '.RDF';
    DB.DBA.DAV_DELETE_INT (pFolder, 1, null, null, 0);

    content := '';
    S := sprintf ('http://%s/sparql?default-graph-uri=%U&query=%U&format=%U', DB.DBA.wa_cname (), pGraph, 'CONSTRUCT { ?s ?p ?o} WHERE {?s ?p ?o}', 'text/xml');
    rc := DB.DBA.DAV_RES_UPLOAD_STRSES_INT (pFolder, content, 'text/xml', '111101101NN', user_id, user_id, pUser, pPassword, 1);
    if (isnull (DAV_HIDE_ERROR (rc)))
  	  signal ('ODS12a', DAV_PERROR (rc));
    rc := DB.DBA.DAV_PROP_SET_INT (pFolder, 'redirectref', S, pUser, pPassword, 1, 0, 1);
    if (isnull (DAV_HIDE_ERROR (rc)))
  	  signal ('ODS12b', DAV_PERROR (rc));
  }

  -- get count before
  retValue := (select count(*) from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (pGraph));

  if (pSourceType = 'URL' and pSpongerMode) {
    exec (sprintf ('SPARQL define get:soft "soft" define get:uri "%s" SELECT * FROM <%s> WHERE { ?s ?p ?o }', pSource, pGraph));
  } else {
    if (pSourceType = 'URL') {
      commit work;
    	content := http_get (pSource, hdr, 'GET');
    	if (hdr[0] not like 'HTTP%200%')
    	  signal ('22023', hdr[0]);
    	if (isnull (pSourceMimeType))
        pSourceMimeType := http_request_header (hdr, 'Content-Type');
    }	else {
    	content := pSource;
    }

    if (pSourceMimeType in ('application/rdf+xml', 'application/foaf+xml')) {
      if (pSpongerMode) {
        declare xt any;

        xt := xtree_doc (content);
        if (xpath_eval ('[ xmlns:dv="http://www.w3.org/2003/g/data-view#" ] /*[1]/@dv:transformation', xt) is not null)
          goto _sponger;
      }
      DB.DBA.RDF_LOAD_RDFXML (content, pGraph, pGraph);
      goto _end;
    }
    if (pSourceMimeType in ('text/rdf+n3', 'text/rdf+ttl', 'application/rdf+n3', 'application/rdf+turtle', 'application/turtle', 'application/x-turtle')) {
      DB.DBA.TTLP (content, pGraph, pGraph);
      goto _end;
    }

  _sponger:;
    if (pSpongerMode) {
      declare aq, ps, xrc any;

      aq := null;
      ps := cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'PingService');
      if (length (ps))
        aq := async_queue (1);

      for select RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_OPTIONS from DB.DBA.SYS_RDF_MAPPERS where RM_ENABLED = 1 order by RM_ID do {
        declare val_match, pcols, npars any;

        if (RM_TYPE = 'MIME') {
          val_match := pSourceMimeType;
        } else {
          val_match := null;
        }
        if (isstring (val_match) and regexp_match (RM_PATTERN, val_match) is not null)	{
          if (__proc_exists (RM_HOOK) is null)
            goto _next_mapper;

          declare exit handler for sqlstate '*' {
            goto _next_mapper;
          };

          pcols := DB.DBA.RDF_PROC_COLS (RM_HOOK);
          npars := 8;
          if (isarray (pcols))
            npars := length (pcols);
  	      if (npars = 7) {
            xrc := call (RM_HOOK) (pGraph, pGraph, null, content, aq, ps, RM_KEY);
          } else {
            xrc := call (RM_HOOK) (pGraph, pGraph, null, content, aq, ps, RM_KEY, RM_OPTIONS);
          }
  	      if (xrc > 0)
            goto _end;
        }
      _next_mapper:;
      }
    }
  }

_end:;
  -- get count after
  retValue := (select count(*) from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (pGraph)) - retValue;
  if (retValue <= 0) {
    retValue := 0;
    if (not isnull (pFolder))
      DB.DBA.DAV_DELETE_INT (pFolder, 1, null, null, 0);
  }
  return retValue;
}
;

-- Helpers
--
create procedure ODS_SPARQL_QM_RUN (in txt varchar, in sig int := 1, in fl int := 0)
{
  declare REPORT, stat, msg, sqltext varchar;
  declare metas, rowset any;
  if (fl)
    result_names (REPORT);
  txt := '
    prefix sioc: <http://rdfs.org/sioc/ns#>
    prefix sioct: <http://rdfs.org/sioc/types#>
    prefix atom: <http://atomowl.org/ontologies/atomrdf#>
    prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    prefix foaf: <http://xmlns.com/foaf/0.1/>
    prefix dc: <http://purl.org/dc/elements/1.1/>
    prefix dct: <http://purl.org/dc/terms/>
    prefix skos: <http://www.w3.org/2004/02/skos/core#>
    prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
    prefix bm: <http://www.w3.org/2002/01/bookmark#>
    prefix exif: <http://www.w3.org/2003/12/exif/ns/>
    prefix ann: <http://www.w3.org/2000/10/annotation-ns#>
    prefix wikiont: <http://sw.deri.org/2005/04/wikipedia/wikiont.owl#>
    prefix calendar: <http://www.w3.org/2002/12/cal#>
' || txt;
  --dbg_printf ('%s', txt);
  -- string_to_file ('ods_sparql_qm_run.sql', '\nSPARQL ' || txt || '\n;\n', -1);
  sqltext := string_output_string (sparql_to_sql_text (txt));
  -- dump_large_text_impl (sqltext);
  stat := '00000';
  msg := '';
  rowset := null;
  exec (sqltext, stat, msg, vector (), 1000, metas, rowset);
  if (sig and stat <> '00000')
    {
      signal (stat, msg);
    }
  if (fl)
    {
      result ('STATE=' || stat || ': ' || msg);
      if (193 = __tag (rowset))
      	{
      	  foreach (any r in rowset) do
      	    result (r[0] || ': ' || r[1]);
      	}
    }
}
;

-- Common ODS data

wa_exec_no_error ('drop view SIOC_SITE');
wa_exec_no_error ('drop view SIOC_USERS');
wa_exec_no_error ('drop view SIOC_ODS_FORUMS');
wa_exec_no_error ('drop view SIOC_ROLES');
wa_exec_no_error ('drop view SIOC_ROLE_GRANTS');
wa_exec_no_error ('drop view SIOC_GROUPS');
wa_exec_no_error ('drop view SIOC_KNOWS');
wa_exec_no_error ('drop view ODS_FOAF_PERSON');

create view SIOC_SITE as select top 1
	coalesce (WS_WEB_TITLE, sys_stat ('st_host_name')) as WS_WEB_TITLE,
	sioc..get_ods_link () as WS_LINK,
	'' as WS_DUMMY
	from DB.DBA.WA_SETTINGS;

create view SIOC_USERS as select U_ID, U_NAME, U_FULL_NAME,
	case when length (U_E_MAIL) then U_E_MAIL else null end as E_MAIL,
	case when length (U_E_MAIL) then sha1_digest (U_E_MAIL) else null end as E_MAIL_SHA1,
	sioc..user_obj_iri (U_NAME) || '/sioc.rdf' as SEE_ALSO,
	'sioc:User' as CLS,
	iri_id_num (iri_to_id (sioc..user_obj_iri (U_NAME))) as OBJ_IRI
	from DB.DBA.SYS_USERS
	where U_IS_ROLE = 0 and U_ACCOUNT_DISABLED = 0 and U_DAV_ENABLE = 1 and U_ID <> http_nobody_uid ();

create view SIOC_GROUPS as select U_ID, U_NAME from DB.DBA.SYS_USERS where U_IS_ROLE = 1 and U_ID <> http_nogroup_gid ();

create view SIOC_ODS_FORUMS as select
	U_NAME,
	WAM_INST,
	WAI_DESCRIPTION,
	DB.DBA.wa_type_to_app (WAM_APP_TYPE) as APP_TYPE,
        sioc..forum_iri (WAM_APP_TYPE, WAM_INST) as LINK,
        sioc..forum_iri (WAM_APP_TYPE, WAM_INST) || '/sioc.rdf' as SEE_ALSO,
	WAM_APP_TYPE as WAM_APP_TYPE,
	sioc..cls_short_print (sioc..ods_sioc_forum_ext_type (WAM_APP_TYPE)) as CLS,
	iri_id_num (iri_to_id (sioc..forum_iri (WAM_APP_TYPE, WAM_INST))) as OBJ_IRI
	from DB.DBA.SYS_USERS, DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where
	U_ID = WAM_USER and WAM_INST = WAI_NAME and WAM_MEMBER_TYPE = 1 and (WAM_IS_PUBLIC = 1 or WAI_TYPE_NAME = 'oDrive');

create view SIOC_ROLES as
	select
	WAM_INST,
	DB.DBA.wa_type_to_app (WAM_APP_TYPE) as APP_TYPE,
	U_NAME,
	WMT_NAME
	from
	DB.DBA.SYS_USERS, DB.DBA.WA_MEMBER,
	(select WMT_NAME, WMT_ID, WMT_APP from DB.DBA.WA_MEMBER_TYPE union all
	 select 'owner', 1, WAT_NAME from DB.DBA.WA_TYPES) roles
	where
	U_ID = WAM_USER and WMT_APP = WAM_APP_TYPE and WMT_ID = WAM_MEMBER_TYPE and WAM_IS_PUBLIC;

create view SIOC_ROLE_GRANTS as
	select
	sub.U_NAME as G_NAME,
	super.U_NAME as U_NAME
	from DB.DBA.SYS_ROLE_GRANTS, DB.DBA.SYS_USERS sub, DB.DBA.SYS_USERS super
	where
	GI_DIRECT = 1 and GI_SUB = sub.U_ID and GI_SUPER = super.U_ID and super.U_DAV_ENABLE;

create view SIOC_KNOWS as
	select f.sne_name as FROM_NAME, t.sne_name as TO_NAME from DB.DBA.sn_related, DB.DBA.sn_person f, DB.DBA.sn_person t
	where snr_from = f.sne_id and snr_to = t.sne_id;

create procedure ods_filter_uinf (in val any, in flags varchar, in fld int, in fmt varchar := null)
{
  declare r any;
  if (length (flags) <= fld)
    return null;
  r := atoi (chr (flags[fld]));
  if (r = 1)
    {
      if (isstring (val) and not length (val))
        return null;
      if (fmt is not null and val is not null)
	return sprintf (fmt, val);
      return val;
    }
  return null;
};

create view ODS_FOAF_PERSON as select
	U_NAME,
	case when length (U_E_MAIL) then U_E_MAIL else null end as E_MAIL,
	case when length (U_E_MAIL) then sha1_digest (U_E_MAIL) else null end as E_MAIL_SHA1,
	sioc..user_obj_iri (U_NAME) || '/about.rdf' as SEE_ALSO,
	DB.DBA.ods_filter_uinf (WAUI_FIRST_NAME, WAUI_VISIBLE, 1) as FIRST_NAME,
	DB.DBA.ods_filter_uinf (WAUI_LAST_NAME, WAUI_VISIBLE, 2) as LAST_NAME,
	U_FULL_NAME,
	DB.DBA.ods_filter_uinf (WAUI_GENDER, WAUI_VISIBLE, 5) as GENDER,
	DB.DBA.ods_filter_uinf (WAUI_ICQ, WAUI_VISIBLE, 10) as ICQ,
	DB.DBA.ods_filter_uinf (WAUI_MSN, WAUI_VISIBLE, 14) as MSN,
	DB.DBA.ods_filter_uinf (WAUI_AIM, WAUI_VISIBLE, 12) as AIM,
	DB.DBA.ods_filter_uinf (WAUI_YAHOO, WAUI_VISIBLE, 13) as YAHOO,
	DB.DBA.ods_filter_uinf (
	    substring (datestring(coalesce (WAUI_BIRTHDAY, now ())), 6, 5)
	    , WAUI_VISIBLE, 6) as BIRTHDAY,
	DB.DBA.ods_filter_uinf (WAUI_BORG, WAUI_VISIBLE, 20) as ORG,
	U_NAME||'%23this' as LABEL,
	U_NAME||'%23geo' as GEO_LABEL,
	case when length (WAUI_HPHONE) and sioc..wa_user_pub_info (WAUI_VISIBLE, 18) then WAUI_HPHONE
	when length (WAUI_HMOBILE) and sioc..wa_user_pub_info (WAUI_VISIBLE, 18) then WAUI_HMOBILE else  WAUI_BPHONE end as PHONE,
	DB.DBA.ods_filter_uinf (WAUI_LAT, WAUI_VISIBLE, 39, '%.06f') as LAT,
	DB.DBA.ods_filter_uinf (WAUI_LNG, WAUI_VISIBLE, 39, '%.06f') as LNG,
	WAUI_WEBPAGE as WEBPAGE,
	'foaf:User' as CLS,
	iri_id_num (iri_to_id (sioc..person_iri (sioc..user_obj_iri (U_NAME)))) as OBJ_IRI
	from DB.DBA.WA_USER_INFO, DB.DBA.SYS_USERS
	where WAUI_U_ID = U_ID;


-- ODS RDF VIEW

create procedure ODS_RDF_VIEW_INIT (in fl int := 0)
{
  return;
};

create procedure ODS_RDF_VIEW_INIT_1 (in fl int := 0)
{

--    delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (JSO_SYS_GRAPH());
--    DB.DBA.SPARQL_RELOAD_QM_GRAPH ();

    sioc..ods_sioc_result ('Dropping old graph.');
    ODS_SPARQL_QM_RUN ('
    drop quad map graph iri("http://^{URIQADefaultHost}^/dataspace_v") .
    ', 0, 0);

    sioc..ods_sioc_result ('Old graph dropped.');
    commit work;
    sioc..ods_sioc_result ('Dropping virtrdf:ODSDataspace storage.');

    for select DB.DBA.wa_type_to_app (WAT_NAME) as suffix from DB.DBA.WA_TYPES do
      {
	ODS_SPARQL_QM_RUN ('drop quad map virtrdf:ODSDataspace-'||suffix||' .', 0, 0);
      }
    ODS_SPARQL_QM_RUN ('drop quad map virtrdf:ODSDataspace-discussion .', 0, 0);
    ODS_SPARQL_QM_RUN ('drop quad map virtrdf:ODSDataspace .', 0, 0);

    sioc..ods_sioc_result ('virtrdf:ODSDataspace storage dropped.');

    ODS_SPARQL_QM_RUN ('
    drop quad storage virtrdf:ODS .
    ', 0, 0);

    ODS_SPARQL_QM_RUN ('
    create quad storage virtrdf:ODS {
      create virtrdf:DefaultQuadMap using storage virtrdf:DefaultQuadStorage .
    } .
    ', 1, fl);
    sioc..ods_sioc_result ('Creating IRI classes.');

    ODS_SPARQL_QM_RUN ('
    create iri class sioc:proxy_iri "http://^{URIQADefaultHost}^/proxy/%U" (in url varchar not null) .
    create iri class sioc:default_site "http://^{URIQADefaultHost}^/dataspace%U" (in dummy varchar not null) .
    create iri class sioc:user_iri "http://^{URIQADefaultHost}^/dataspace/%U" (in uname varchar not null) .
    create iri class foaf:person_iri "http://^{URIQADefaultHost}^/dataspace/%U#person" (in uname varchar not null) .
    create iri class foaf:person_geo_iri "http://^{URIQADefaultHost}^/dataspace/%U#person_based" (in uname varchar not null) .
    create iri class sioc:user_group_iri "http://^{URIQADefaultHost}^/dataspace/%U" (in uname varchar not null) .
    create iri class sioc:user_site_iri "http://^{URIQADefaultHost}^/dataspace/%U#site" (in uname varchar not null) .
    create iri class sioc:forum_iri "http://^{URIQADefaultHost}^/dataspace/%U/%U/%U"
	    ( in uname varchar not null, in forum_type varchar not null, in forum_name varchar not null) .
    create iri class sioc:role_iri "http://^{URIQADefaultHost}^/dataspace/%U/%U/%U#%U"
	    (in uname varchar not null, in tp varchar not null, in inst varchar not null, in role_name varchar not null) .
    create iri class atom:person_iri "http://^{URIQADefaultHost}^/dataspace/%U#person" (in uname varchar not null) .
    # Blog
    create iri class sioc:blog_forum_iri "http://^{URIQADefaultHost}^/dataspace/%U/weblog/%U"
	    ( in uname varchar not null, in forum_name varchar not null) .
    create iri class sioc:blog_post_iri "http://^{URIQADefaultHost}^/dataspace/%U/weblog/%U/%U"
	    ( in uname varchar not null, in forum_name varchar not null, in postid varchar not null) .
    create iri class sioc:blog_comment_iri "http://^{URIQADefaultHost}^/dataspace/%U/weblog/%U/%U/%d"
	    ( in uname varchar not null, in forum_name varchar not null, in postid varchar not null, in comment_id int not null) .
    create iri class sioc:tag_iri "http://^{URIQADefaultHost}^/dataspace/%U/concept#%U"
	    (in uname varchar not null, in tag varchar not null) .
    create iri class sioc:blog_post_text_iri "http://^{URIQADefaultHost}^/dataspace/%U/weblog-text/%U/%U"
	    ( in uname varchar not null, in forum_name varchar not null, in postid varchar not null) .
    #Feeds
    create iri class sioc:feed_iri "http://^{URIQADefaultHost}^/dataspace/feed/%d" (in feed_id integer not null) .
    create iri class sioc:feed_item_iri "http://^{URIQADefaultHost}^/dataspace/feed/%d/%d" (in feed_id integer not null, in item_id integer not null) .
    create iri class sioc:feed_item_text_iri "http://^{URIQADefaultHost}^/dataspace/feed/%d/%d/text" (in feed_id integer not null, in item_id integer not null) .
    create iri class sioc:feed_mgr_iri "http://^{URIQADefaultHost}^/dataspace/%U/subscriptions/%U" (in uname varchar not null, in inst_name varchar not null) .
    create iri class sioc:feed_comment_iri "http://^{URIQADefaultHost}^/dataspace/%U/subscriptions/%U/%d/%d"
	    (in uname varchar not null, in inst_name varchar not null, in item_id integer not null, in comment_id integer not null) .
    # Bookmark
    create iri class sioc:bmk_post_iri "http://^{URIQADefaultHost}^/dataspace/%U/bookmark/%U/%d"
	    (in uname varchar not null, in inst_name varchar not null, in bmk_id integer not null) .
    create iri class sioc:bmk_post_text_iri "http://^{URIQADefaultHost}^/dataspace/%U/bookmark/%U/%d/text"
	    (in uname varchar not null, in inst_name varchar not null, in bmk_id integer not null) .
    create iri class sioc:bmk_forum_iri "http://^{URIQADefaultHost}^/dataspace/%U/bookmark/%U"
	    ( in uname varchar not null, in forum_name varchar not null) .
    # Photo
    create iri class sioc:photo_forum_iri "http://^{URIQADefaultHost}^/dataspace/%U/photos/%U"
	    (in uname varchar not null, in inst_name varchar not null) .
    create iri class sioc:photo_post_iri "http://^{URIQADefaultHost}^%s"
	    (in path varchar not null) option (returns "http://^{URIQADefaultHost}^/DAV/%s") .
    create iri class sioc:photo_post_text_iri "http://^{URIQADefaultHost}^%s/text"
	    (in path varchar not null) option (returns "http://^{URIQADefaultHost}^/DAV/%s/text") .
    create iri class sioc:photo_comment_iri "http://^{URIQADefaultHost}^%s:comment_%d"
	    (in path varchar not null, in comment_id int not null) option (returns "http://^{URIQADefaultHost}^/DAV/%s:comment_%d") .
    # Community
    create iri class sioc:community_forum_iri "http://^{URIQADefaultHost}^/dataspace/%U/community/%U"
	    (in uname varchar not null, in forum_name varchar not null) .
    # Briefcase
    create iri class sioc:odrive_forum_iri "http://^{URIQADefaultHost}^/dataspace/%U/briefcase/%U"
	    (in uname varchar not null, in inst_name varchar not null) .
    create iri class sioc:odrive_post_iri "http://^{URIQADefaultHost}^%s"
	    (in path varchar not null) option (returns "http://^{URIQADefaultHost}^/DAV/%s") .
    create iri class sioc:odrive_post_text_iri "http://^{URIQADefaultHost}^%s/text"
	    (in path varchar not null) option (returns "http://^{URIQADefaultHost}^/DAV/%s/text") .
    # Wiki
    create iri class sioc:wiki_post_iri "http://^{URIQADefaultHost}^/dataspace/%U/wiki/%U/%U"
	    (in uname varchar not null, in inst_name varchar not null, in topic_id varchar not null) .
    create iri class sioc:wiki_post_text_iri "http://^{URIQADefaultHost}^/dataspace/%U/wiki/%U/%U/text"
	    (in uname varchar not null, in inst_name varchar not null, in topic_id varchar not null) .
    create iri class sioc:wiki_forum_iri "http://^{URIQADefaultHost}^/dataspace/%U/wiki/%U"
	    ( in uname varchar not null, in forum_name varchar not null) .
    # Calendar
    create iri class sioc:calendar_event_iri "http://^{URIQADefaultHost}^/dataspace/%U/calendar/%U/%d"
	    (in uname varchar not null, in inst_name varchar not null, in calendar_id integer not null) .
    create iri class sioc:calendar_event_text_iri "http://^{URIQADefaultHost}^/dataspace/%U/calendar/%U/%d/text"
	    (in uname varchar not null, in inst_name varchar not null, in calendar_id integer not null) .
    create iri class sioc:calendar_forum_iri "http://^{URIQADefaultHost}^/dataspace/%U/calendar/%U"
	    ( in uname varchar not null, in forum_name varchar not null) .
    # Polls
    create iri class sioc:poll_post_iri "http://^{URIQADefaultHost}^/dataspace/%U/polls/%U/%d"
	    (in uname varchar not null, in inst_name varchar not null, in poll_id integer not null) .
    create iri class sioc:poll_post_text_iri "http://^{URIQADefaultHost}^/dataspace/%U/polls/%U/%d/text"
	    (in uname varchar not null, in inst_name varchar not null, in poll_id integer not null) .
    create iri class sioc:poll_forum_iri "http://^{URIQADefaultHost}^/dataspace/%U/polls/%U"
	    ( in uname varchar not null, in forum_name varchar not null) .
    # AddressBook
    create iri class sioc:addressbook_contact_iri "http://^{URIQADefaultHost}^/dataspace/%U/addressbook/%U/%d"
	    (in uname varchar not null, in inst_name varchar not null, in contact_id integer not null) .
    create iri class sioc:addressbook_contact_text_iri "http://^{URIQADefaultHost}^/dataspace/%U/addressbook/%U/%d/text"
	    (in uname varchar not null, in inst_name varchar not null, in contact_id integer not null) .
    create iri class sioc:addressbook_forum_iri "http://^{URIQADefaultHost}^/dataspace/%U/addressbook/%U"
	    ( in uname varchar not null, in forum_name varchar not null) .
    # NNTPF
    create iri class sioc:nntp_forum_iri "http://^{URIQADefaultHost}^/dataspace/discussion/%U"
	    ( in forum_name varchar not null) .
    create iri class sioc:nntp_post_iri "http://^{URIQADefaultHost}^/dataspace/discussion/%U/%U"
	    ( in group_name varchar not null, in message_id varchar not null) .
    create iri class sioc:nntp_post_text_iri "http://^{URIQADefaultHost}^/dataspace/discussion/%U/%U/text"
	    ( in group_name varchar not null, in message_id varchar not null) .
    create iri class sioc:nntp_role_iri "http://^{URIQADefaultHost}^/dataspace/discussion/%U#reader"
	    ( in forum_name varchar not null) .
    ', 1, fl);
    sioc..ods_sioc_result ('IRI classes are created.');

    commit work;
    sioc..ods_sioc_result ('Creating the virtrdf:ODSDataspace storage.');
    ODS_CREATE_APP_RDF_VIEWS ();
    ODS_SPARQL_QM_RUN ('
    alter quad storage virtrdf:DefaultQuadStorage
    #alter quad storage virtrdf:ODS
    {
	create virtrdf:ODSDataspace as graph iri ("http://^{URIQADefaultHost}^/dataspace_v") option (exclusive)
	  {

	    # Default ODS Site

	    sioc:default_site (DB.DBA.SIOC_SITE.WS_DUMMY) a sioc:Space ;
	    sioc:link sioc:proxy_iri (WS_LINK) ;
	    dc:title WS_WEB_TITLE .

	    # Forum
	    sioc:forum_iri (DB.DBA.SIOC_ODS_FORUMS.U_NAME, DB.DBA.SIOC_ODS_FORUMS.APP_TYPE, DB.DBA.SIOC_ODS_FORUMS.WAM_INST)
		    a sioc:Container option (EXCLUSIVE);
		    sioc:id WAM_INST ;
		    sioc:type APP_TYPE option (EXCLUSIVE) ;
		    sioc:description WAI_DESCRIPTION ;
		    sioc:link sioc:proxy_iri (LINK) ;
		    rdfs:seeAlso sioc:proxy_iri (SEE_ALSO) ;
		    sioc:has_space sioc:user_site_iri (U_NAME)
	    .
	    sioc:forum_iri (DB.DBA.SIOC_ODS_FORUMS.U_NAME, DB.DBA.SIOC_ODS_FORUMS.APP_TYPE, DB.DBA.SIOC_ODS_FORUMS.WAM_INST)
		    a sioct:Weblog
	            where (^{alias}^.WAM_APP_TYPE = ''WEBLOG2'') option (EXCLUSIVE) .

	    sioc:forum_iri (DB.DBA.SIOC_ODS_FORUMS.U_NAME, DB.DBA.SIOC_ODS_FORUMS.APP_TYPE, DB.DBA.SIOC_ODS_FORUMS.WAM_INST)
		    a sioct:BookmarkFolder
	            where (^{alias}^.WAM_APP_TYPE = ''Bookmark'') option (EXCLUSIVE) .

	    sioc:forum_iri (DB.DBA.SIOC_ODS_FORUMS.U_NAME, DB.DBA.SIOC_ODS_FORUMS.APP_TYPE, DB.DBA.SIOC_ODS_FORUMS.WAM_INST)
		    a sioct:Calendar
	            where (^{alias}^.WAM_APP_TYPE = ''Calendar'') option (EXCLUSIVE) .

	    sioc:forum_iri (DB.DBA.SIOC_ODS_FORUMS.U_NAME, DB.DBA.SIOC_ODS_FORUMS.APP_TYPE, DB.DBA.SIOC_ODS_FORUMS.WAM_INST)
		    a sioc:Community
	            where (^{alias}^.WAM_APP_TYPE = ''Community'') option (EXCLUSIVE) .

	    sioc:forum_iri (DB.DBA.SIOC_ODS_FORUMS.U_NAME, DB.DBA.SIOC_ODS_FORUMS.APP_TYPE, DB.DBA.SIOC_ODS_FORUMS.WAM_INST)
		    a sioct:SubscriptionList
	            where (^{alias}^.WAM_APP_TYPE = ''eNews2'') option (EXCLUSIVE) .

	    sioc:forum_iri (DB.DBA.SIOC_ODS_FORUMS.U_NAME, DB.DBA.SIOC_ODS_FORUMS.APP_TYPE, DB.DBA.SIOC_ODS_FORUMS.WAM_INST)
		    a sioct:Briefcase
	            where (^{alias}^.WAM_APP_TYPE = ''oDrive'') option (EXCLUSIVE) .

	    sioc:forum_iri (DB.DBA.SIOC_ODS_FORUMS.U_NAME, DB.DBA.SIOC_ODS_FORUMS.APP_TYPE, DB.DBA.SIOC_ODS_FORUMS.WAM_INST)
		    a sioct:ImageGallery
	            where (^{alias}^.WAM_APP_TYPE = ''oGallery'') option (EXCLUSIVE) .

	    sioc:forum_iri (DB.DBA.SIOC_ODS_FORUMS.U_NAME, DB.DBA.SIOC_ODS_FORUMS.APP_TYPE, DB.DBA.SIOC_ODS_FORUMS.WAM_INST)
		    a sioct:Wiki
	            where (^{alias}^.WAM_APP_TYPE = ''oWiki'') option (EXCLUSIVE) .

	    sioc:forum_iri (DB.DBA.SIOC_ODS_FORUMS.U_NAME, DB.DBA.SIOC_ODS_FORUMS.APP_TYPE, DB.DBA.SIOC_ODS_FORUMS.WAM_INST)
		    a sioct:Polls
	            where (^{alias}^.WAM_APP_TYPE = ''Polls'') option (EXCLUSIVE) .

	    sioc:forum_iri (DB.DBA.SIOC_ODS_FORUMS.U_NAME, DB.DBA.SIOC_ODS_FORUMS.APP_TYPE, DB.DBA.SIOC_ODS_FORUMS.WAM_INST)
		    a sioct:AddressBook
	            where (^{alias}^.WAM_APP_TYPE = ''AddressBook'') option (EXCLUSIVE) .

	    #sioc:forum_iri (DB.DBA.SIOC_ODS_FORUMS.U_NAME, DB.DBA.SIOC_ODS_FORUMS.APP_TYPE, DB.DBA.SIOC_ODS_FORUMS.WAM_INST)
	    #	    a sioct:MailingList
            #        where (^{alias}^.WAM_APP_TYPE = ''oMail'') option (EXCLUSIVE) .

	    # AtomOWL Feed
	    sioc:forum_iri (DB.DBA.SIOC_ODS_FORUMS.U_NAME, DB.DBA.SIOC_ODS_FORUMS.APP_TYPE, DB.DBA.SIOC_ODS_FORUMS.WAM_INST)
		    a atom:Feed ;
		    atom:link sioc:proxy_iri (LINK) ;
		    atom:title WAM_INST .

	    # User
	    sioc:user_iri (DB.DBA.SIOC_USERS.U_NAME)
		    a sioc:User option (EXCLUSIVE);
		    sioc:id U_NAME ;
		    sioc:name U_FULL_NAME ;
		    sioc:email sioc:proxy_iri (E_MAIL) ;
		    sioc:email_sha1 E_MAIL_SHA1 ;
		    rdfs:seeAlso sioc:proxy_iri (SEE_ALSO) ;
		    sioc:account_of foaf:person_iri (U_NAME) .

	    # Usergroup
	    sioc:user_iri (DB.DBA.SIOC_GROUPS.U_NAME) a sioc:Usergroup option (EXCLUSIVE);
		    sioc:id U_NAME
		    #where (^{alias}^.U_IS_ROLE = 1) XXX
	    .

	    # User Site
	    sioc:user_site_iri (DB.DBA.SIOC_USERS.U_NAME) a sioc:Space option (EXCLUSIVE);
		    sioc:link sioc:user_iri (U_NAME)
	    .

	    # Site - Forum relation
	    sioc:user_site_iri (DB.DBA.SIOC_ODS_FORUMS.U_NAME)
		    sioc:space_of sioc:forum_iri (U_NAME, APP_TYPE, WAM_INST)
	    .

	    # Roles & Membership
	    sioc:role_iri (DB.DBA.SIOC_ROLES.U_NAME, DB.DBA.SIOC_ROLES.APP_TYPE, DB.DBA.SIOC_ROLES.WAM_INST, DB.DBA.SIOC_ROLES.WMT_NAME)
		    sioc:has_scope sioc:forum_iri (U_NAME, APP_TYPE, WAM_INST) .

	    sioc:forum_iri (DB.DBA.SIOC_ROLES.U_NAME, DB.DBA.SIOC_ROLES.APP_TYPE, DB.DBA.SIOC_ROLES.WAM_INST)
		    sioc:scope_of  sioc:role_iri (U_NAME, APP_TYPE, WAM_INST, WMT_NAME) .

	    sioc:user_iri (DB.DBA.SIOC_ROLES.U_NAME)
		    sioc:has_function sioc:role_iri (U_NAME, APP_TYPE, WAM_INST, WMT_NAME) .

	    sioc:role_iri (DB.DBA.SIOC_ROLES.U_NAME, DB.DBA.SIOC_ROLES.APP_TYPE, DB.DBA.SIOC_ROLES.WAM_INST, DB.DBA.SIOC_ROLES.WMT_NAME)
		    sioc:function_of sioc:user_iri (U_NAME) .

	    sioc:user_iri (DB.DBA.SIOC_ROLE_GRANTS.U_NAME)
		    sioc:member_of sioc:user_group_iri (G_NAME) .

	    sioc:user_group_iri (DB.DBA.SIOC_ROLE_GRANTS.G_NAME)
		    sioc:has_member sioc:user_iri (U_NAME) .

	    # Person
	    foaf:person_iri (DB.DBA.ODS_FOAF_PERSON.U_NAME) a foaf:Person ;
		    foaf:mbox sioc:proxy_iri(E_MAIL) ;
		    foaf:mbox_sha1sum E_MAIL_SHA1 ;
		    rdfs:seeAlso sioc:proxy_iri (SEE_ALSO) ;
		    foaf:nick U_NAME ;
		    foaf:name U_FULL_NAME ;
		    foaf:holdsAccount sioc:user_iri (U_NAME) ;
		    foaf:firstName FIRST_NAME ;
		    foaf:family_name LAST_NAME ;
		    foaf:gender GENDER ;
		    foaf:icqChatID ICQ ;
		    foaf:msnChatID MSN ;
		    foaf:aimChatID AIM ;
		    foaf:yahooChatID YAHOO ;
		    foaf:birthday BIRTHDAY ;
		    foaf:organization ORG ;
		    foaf:phone PHONE ;
		    foaf:based_near foaf:person_geo_iri (U_NAME) .

	    foaf:person_geo_iri (DB.DBA.ODS_FOAF_PERSON.U_NAME) a geo:Point option (EXCLUSIVE) ;
		    geo:lat LAT ;
		    geo:lng LNG .

	    # AtomOWL Person
	    atom:person_iri (DB.DBA.ODS_FOAF_PERSON.U_NAME) a atom:Person option (EXCLUSIVE) ;
		    atom:personName U_NAME ;
		    atom:personEmail E_MAIL .


	    # Social Networking
	    foaf:person_iri (DB.DBA.SIOC_KNOWS.FROM_NAME)
	    foaf:knows
	    foaf:person_iri (TO_NAME).

	    foaf:person_iri (DB.DBA.SIOC_KNOWS.TO_NAME)
	    foaf:knows
	    foaf:person_iri (FROM_NAME).


	  }
      } .
    ', 1, fl);

    sioc..ods_sioc_result ('The virtrdf:ODSDataspace storage is created.');
}
;

-- 'Compose the apps graphs

create procedure ODS_CREATE_APP_RDF_VIEWS ()
{
  declare tmp any;
  for select DB.DBA.wa_type_to_app (WAT_NAME) as suffix from DB.DBA.WA_TYPES do
    {
      declare p_name varchar;
      p_name := sprintf ('sioc.DBA.rdf_%s_view_str', suffix);
      if (__proc_exists (p_name))
	  {
	    tmp := call (p_name) ();
            ODS_SPARQL_QM_RUN ('
alter quad storage virtrdf:DefaultQuadStorage
#alter quad storage virtrdf:ODS
  {
    create virtrdf:ODSDataspace-' || suffix || ' as graph iri ("http://^{URIQADefaultHost}^/dataspace_v") {
    '|| tmp || '\n} }' );
	  }
    }
  if (__proc_exists ('sioc.DBA.rdf_nntpf_view_str'))
    {
      tmp := sioc.DBA.rdf_nntpf_view_str ();
            ODS_SPARQL_QM_RUN ('
alter quad storage virtrdf:DefaultQuadStorage
#alter quad storage virtrdf:ODS
  {
    create virtrdf:ODSDataspace-discussion as graph iri ("http://^{URIQADefaultHost}^/dataspace_v") {
    ' || tmp || '\n} }' );
    }
};


grant select on SIOC_SITE to SPARQL_SELECT;
grant select on SIOC_USERS to SPARQL_SELECT;
grant select on SIOC_ODS_FORUMS to SPARQL_SELECT;
grant select on SIOC_ROLES to SPARQL_SELECT;
grant select on SIOC_ROLE_GRANTS to SPARQL_SELECT;
grant select on SIOC_GROUPS to SPARQL_SELECT;
grant select on SIOC_KNOWS to SPARQL_SELECT;
grant select on ODS_FOAF_PERSON to SPARQL_SELECT;
grant execute on wa_type_to_app to SPARQL_SELECT;
grant select on DB.DBA.NEWS_GROUPS to SPARQL_SELECT;
grant execute on sioc.DBA.get_ods_link to SPARQL_SELECT;
grant execute on DB.DBA.WA_LINK to SPARQL_SELECT;
grant execute on sioc.DBA.sioc_date to SPARQL_SELECT;
grant execute on sioc.DBA.user_obj_iri to SPARQL_SELECT;
grant execute on sioc.DBA.forum_iri to SPARQL_SELECT;
grant execute on sioc.DBA.post_iri to SPARQL_SELECT;
grant execute on DB.DBA.ods_filter_uinf to SPARQL_SELECT;
grant execute on sioc.DBA.wa_user_pub_info to SPARQL_SELECT;
grant execute on sioc.DBA.ods_sioc_forum_ext_type to SPARQL_SELECT;
grant execute on sioc..person_iri to SPARQL_SELECT;
grant execute on sioc..cls_short_print to SPARQL_SELECT;

ODS_RDF_VIEW_INIT ();

