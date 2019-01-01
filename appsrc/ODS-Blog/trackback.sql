--
--  $Id$
--
--  MT Trackback support.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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

USE "BLOG"
;

create procedure TRACKBACK_INIT ()
{
  if (exists (select 1 from "DB"."DBA"."SYS_USERS" where U_NAME = 'MT'))
    return;
  DB.DBA.USER_CREATE ('MT', uuid(), vector ('DISABLED', 1, 'LOGIN_QUALIFIER', 'BLOG'));
}
;

TRACKBACK_INIT ()
;

create procedure
MT.MT.trackback (
    in id varchar := '',
    in url varchar := '',
    in title varchar := '',
    in excerpt varchar := '',
    in blog_name varchar := '',
    in __mode varchar := '',
    in __xsl varchar := ''
    )
__SOAP_HTTP 'text/xml'
{
  declare rc, post int;
  declare msg varchar;
  declare item any;
  declare host, hdr varchar;

  msg := '';
  rc := 0;

  hdr := http_request_header ();
  host := sys_connected_server_address ();
  host := http_request_header (hdr, 'Host', null, host);

  if (upper(http_request_get ('REQUEST_METHOD')) = 'POST')
    post := 1;
  else
    post := 0;

  if (id = '' or not exists (select 1 from BLOG.DBA.SYS_BLOGS where B_POST_ID = id))
    {
      rc := 1;
      msg := 'Invalid request';
    }
  else if (post and lower (url) not like 'http://%')
   {
     rc := 1;
     msg := 'Invalid URL';
   }
  else if (post)
   {
     declare opts any;
     select deserialize (blob_to_string (BI_OPTIONS)) into opts from BLOG..SYS_BLOG_INFO, BLOG.DBA.SYS_BLOGS
        where BI_BLOG_ID = B_BLOG_ID and B_POST_ID = id;
     if (not isarray(opts))
       opts := vector ();

     if (get_keyword ('EnableTrackback', opts, 0) = 1)
       {
	 insert into BLOG.DBA.MTYPE_TRACKBACK_PINGS (MP_POST_ID, MP_URL, MP_TITLE, MP_EXCERPT, MP_BLOG_NAME, MP_IP, MP_VIA_DOMAIN)
	     values (id, url, title, excerpt, blog_name, http_client_ip (), host);
       }
     else
       {
	 rc := 1;
	 msg := 'Prohibited';
       }
   }
  else if (lower(__mode) = 'rss' or lower(__mode) = 'view')
   {
     declare ses, blogid any;
     blogid := (select B_BLOG_ID from SYS_BLOGS where B_POST_ID = id);
     ses := string_output ();
     if (lower(__mode) = 'rss')
     xml_auto (
  'select\n' ||
  ' 1 as tag,\n' ||
  ' null as parent,\n' ||
  ' \'0.91\' as [rss!1!version],\n' ||
  '   null as [channel!2!title!element],\n' ||
  '   null as [channel!2!link!element],\n' ||
  '   null as [channel!2!description!element],\n' ||
  ' null as [item!3!description!element],\n' ||
  ' null as [item!3!title!element],\n' ||
  ' null as [item!3!link!element]\n' ||
  '  from SYS_BLOG_INFO where BI_BLOG_ID = ?\n' ||
  'union all\n' ||
  'select\n' ||
  '       2,\n' ||
  ' 1,\n' ||
  ' null,\n' ||
  ' B_TITLE,\n' ||
  ' \'http://\' || ? || BI_HOME || \'?date=\' \n' ||
  '   || substring (datestring (B_TS), 1, 10) || \'#\' || B_POST_ID,\n' ||
  ' substring (blob_to_string (B_CONTENT), 1, 128) || \'...\',\n' ||
  ' null,\n' ||
  ' null,\n' ||
  ' null\n' ||
  '  from SYS_BLOGS, SYS_BLOG_INFO where \n' ||
  ' BI_BLOG_ID = ? and B_BLOG_ID = BI_BLOG_ID and B_POST_ID = ?\n' ||
  'union all\n' ||
  'select\n' ||
  ' 3,\n' ||
  ' 2,\n' ||
  ' null,\n' ||
  ' null,\n' ||
  ' null,\n' ||
  ' null,\n' ||
  ' MP_EXCERPT,\n' ||
  ' MP_TITLE,\n' ||
  ' MP_URL\n' ||
  ' from MTYPE_TRACKBACK_PINGS where \n' ||
  '   MP_POST_ID = ?\n' ||
  'for xml explicit'
       , vector (blogid, host, blogid, id, id), ses);
    else
     xml_auto (
  'select\n' ||
  ' 1 as tag,\n' ||
  ' null as parent,\n' ||
  ' \'2.0\' as [rss!1!version],\n' ||
  ' \'http://www.openlinksw.com/weblog/tb/\' as [rss!1!xmlns:vtb],\n' ||
  '   null as [channel!2!title!element],\n' ||
  '   null as [channel!2!link!element],\n' ||
  '   null as [channel!2!description!element],\n' ||
  '   null as [channel!2!vtb:blog-title!element],\n' ||
  '   null as [channel!2!vtb:blog-url!element],\n' ||
  '   null as [channel!2!vtb:trackback-url!element],\n' ||
  ' null as [item!3!description!element],\n' ||
  ' null as [item!3!title!element],\n' ||
  ' null as [item!3!vtb:blog!element],\n' ||
  ' null as [item!3!pubDate!element],\n' ||
  ' null as [item!3!link!element]\n' ||
  '  from SYS_BLOG_INFO where BI_BLOG_ID = ?\n' ||
  'union all\n' ||
  'select\n' ||
  '       2,\n' ||
  ' 1,\n' ||
  ' null,\n' ||
  ' null,\n' ||
  ' B_TITLE,\n' ||
  ' \'http://\' || ? || BI_HOME || \'?date=\' \n' ||
  '   || substring (datestring (B_TS), 1, 10) || \'#\' || B_POST_ID,\n' ||
  ' substring (blob_to_string (B_CONTENT), 1, 128) || \'...\',\n' ||
  ' BI_TITLE,\n' ||
  ' \'http://\' || ? || BI_HOME,\n' ||
  ' \'http://\' || ? || \'/mt-tb/Http/trackback?id=\'||B_POST_ID, \n' ||
  ' null,\n' ||
  ' null,\n' ||
  ' null,\n' ||
  ' null,\n' ||
  ' null\n' ||
  '  from SYS_BLOGS, SYS_BLOG_INFO where \n' ||
  ' BI_BLOG_ID = ? and B_BLOG_ID = BI_BLOG_ID and B_POST_ID = ?\n' ||
  'union all\n' ||
  'select\n' ||
  ' 3,\n' ||
  ' 2,\n' ||
  ' null,\n' ||
  ' null,\n' ||
  ' null,\n' ||
  ' null,\n' ||
  ' null,\n' ||
  ' null,\n' ||
  ' null,\n' ||
  ' null,\n' ||
  ' MP_EXCERPT,\n' ||
  ' MP_TITLE,\n' ||
  ' MP_BLOG_NAME,\n' ||
  ' date_rfc1123 (MP_TS),\n' ||
  ' MP_URL\n' ||
  ' from MTYPE_TRACKBACK_PINGS where \n' ||
  '   MP_POST_ID = ?\n' ||
  'for xml explicit'
       , vector (blogid, host, host, host, blogid, id, id), ses);
     item := string_output_string (ses);
   }
 else
   {
     rc := 1;
     msg := 'Invalid request';
   }

 if (lower(__mode) = 'view' and __xsl <> '')
   {
     declare base varchar;
     base := (select BI_HOME from SYS_BLOG_INFO, SYS_BLOGS where B_BLOG_ID = BI_BLOG_ID and B_POST_ID = id);
     base := http_physical_path_resolve (base);
     if (base like '/DAV/%')
       http_xslt ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:'||base||'/'||__xsl);
     else
       http_xslt (__xsl);
     http_header ('Content-Type: text/html\r\n');
   }

 return '<?xml version="1.0" encoding="' || current_charset() || '"?>\n' ||
   '<response>\n' ||
    sprintf ('<error>%d</error>\n', rc) ||
    case when rc = 1 then sprintf ('<message>%V</message>\n', msg)
    when post = 0 then item
    else '' end ||
    '</response>\n';

}
;


-- take out further
--VHOST_REMOVE (lpath=>'/mt-tb')
--;

--VHOST_DEFINE (lpath=>'/mt-tb', ppath=>'/SOAP', soap_user=>'MT')
--;

create procedure MT.MT.comments (in id varchar,
         in title varchar := '',
         in author varchar := '',
         in link varchar := '',
         in description varchar := ''
        )
__SOAP_HTTP 'text/plain'
{
  declare content_type, content varchar;
  declare ena int;

  ena := 1;

  content_type := http_request_header (http_request_header (), 'Content-Type');
  if (content_type = 'text/xml')
    {
      declare bid, comm, name, email, home, xt varchar;
      content := http_body_read ();
      xt := xml_tree_doc (xml_tree (content));
      whenever not found goto err;
      select B_BLOG_ID, BI_COMMENTS into bid, ena from SYS_BLOGS, SYS_BLOG_INFO where B_POST_ID = id and BI_BLOG_ID = B_BLOG_ID;

      if (ena = 0)
	goto err;

      name := cast (xpath_eval ('/item/title',xt,1) as varchar);
      email := cast (xpath_eval ('/item/author',xt,1) as varchar);
      home := cast (xpath_eval ('/item/link',xt,1) as varchar);
      comm := cast (xpath_eval ('/item/description',xt,1) as varchar);

      insert into BLOG_COMMENTS
	  (BM_BLOG_ID, BM_POST_ID, BM_COMMENT, BM_NAME, BM_E_MAIL, BM_HOME_PAGE, BM_ADDRESS, BM_TS)
	  values
	  (bid, id, comm, name, email, home, http_client_ip (), now ());
    }
  else if (id <> '' and title <> '' and author <> '' and link <> '' and description <> '')
    {
      declare bid, comm, name, email, home varchar;
      whenever not found goto err;
      select B_BLOG_ID, BI_COMMENTS into bid, ena from SYS_BLOGS, SYS_BLOG_INFO where B_POST_ID = id and BI_BLOG_ID = B_BLOG_ID;

      if (ena = 0)
	goto err;

      name := title;
      email := author;
      home := link;
      comm := description;

      insert into BLOG_COMMENTS
	  (BM_BLOG_ID, BM_POST_ID, BM_COMMENT, BM_NAME, BM_E_MAIL, BM_HOME_PAGE, BM_ADDRESS, BM_TS)
	  values (bid, id, comm, name, email, home, http_client_ip (), now ());

    }
  else
    {
      http_request_status ('HTTP/1.1 406 Not Acceptable');
      return '<pre>The request can\'t be processed, because content is invalid</pre>';
    }
  return 'The comment was posted successfully.';
  err:
  http_request_status ('HTTP/1.1 404 Not found');
  return sprintf ('<pre>The requested article #"%s" not found<pre>', id);
}
;

grant execute on MT.MT.comments to MT
;

grant execute on MT.MT.trackback to MT
;

grant select on SYS_BLOGS to MT
;

grant select on SYS_BLOG_INFO to MT
;

grant select on MTYPE_TRACKBACK_PINGS to MT
;

CREATE PROCEDURE MT_TRACKBACK_DISCO (
      in postid varchar,
  in home varchar := null,
  in ts any := null,
  in title any := null)
{
  declare ses any;
  declare host, hdr, ts1 varchar;

  hdr := http_request_header ();
  host := sys_connected_server_address ();
  host := http_request_header (hdr, 'Host', null, host);

  ses := string_output ();

  if (home is null or ts is null)
    {
      whenever not found goto endf;
      select B_TS, BI_HOME, B_TITLE into ts, home, title
    from SYS_BLOGS, SYS_BLOG_INFO where B_POST_ID = postid and BI_BLOG_ID = B_BLOG_ID;
    }

  if (title is null)
    title := '';

  ts1 := substring (datestring (ts), 1, 10);

  http ('<!--\n', ses);

  http ('<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"', ses);
  http (' xmlns:dc="http://purl.org/dc/elements/1.1/"', ses);
  http (' xmlns:trackback="http://madskills.com/public/xml/rss/module/trackback/">', ses);
  http (sprintf ('<rdf:Description rdf:about="http://%s%s?date=%s#%s"', host, home, ts1, postid), ses);
  http (sprintf (' dc:identifer="http://%s%s?date=%s#%s"', host, home, ts1, postid), ses);
  http (sprintf (' dc:title="%s" trackback:ping="http://%s/mt-tb/Http/trackback?id=%s">', title, host, postid),ses);
  http ('</rdf:Description></rdf:RDF>', ses);

  http ('\n-->', ses);
  endf:
  return string_output_string (ses);
}
;

insert replacing DB.DBA.SYS_XPF_EXTENSIONS (XPE_NAME, XPE_PNAME)
  VALUES ('http://www.openlinksw.com/weblog/:mt_track_back_discovery', 'BLOG.DBA.MT_TRACKBACK_DISCO')
;

grant execute on BLOG.DBA.MT_TRACKBACK_DISCO to public
;

xpf_extension ('http://www.openlinksw.com/weblog/:mt_track_back_discovery', 'BLOG.DBA.MT_TRACKBACK_DISCO', 0)
;

insert replacing DB.DBA.SYS_XPF_EXTENSIONS (XPE_NAME, XPE_PNAME)
  VALUES ('http://www.openlinksw.com/weblog/:tidy_xhtml', 'BLOG.DBA.BLOG_TIDY_HTML')
;

grant execute on BLOG.DBA.BLOG_TIDY_HTML to public
;

xpf_extension ('http://www.openlinksw.com/weblog/:tidy_xhtml', 'BLOG.DBA.BLOG_TIDY_HTML', 0)
;


grant execute on DB.DBA.XML_URI_GET_STRING to MT
;

grant execute on DB.DBA.XML_URI_GET_STRING_OR_ENT to MT
;

grant select on WS.WS.SYS_DAV_RES to MT
;


create procedure "pingback.ping" (in sourceURI varchar, in targetURI varchar)
{
  declare cnt, xt, title, id, hfo, pars, opts any;

  cnt := http_get (sourceURI);
  xt := xml_tree_doc (xml_tree (cnt, 2));
  title := coalesce (xpath_eval ('//title[1]', xt, 1), sourceURI);
  title := cast (title as varchar);
  hfo := WS.WS.PARSE_URI (targetURI);
  pars := coalesce (split_and_decode (hfo[4]), vector ());

  id := get_keyword ('id', pars, null);

  if (not exists (select 1 from SYS_BLOGS where B_POST_ID = id))
    signal ('22023', 'No such article');

  select deserialize (blob_to_string (BI_OPTIONS)) into opts from BLOG..SYS_BLOG_INFO, BLOG.DBA.SYS_BLOGS
        where BI_BLOG_ID = B_BLOG_ID and B_POST_ID = id;
  if (not isarray(opts))
    opts := vector ();

  if (get_keyword ('EnableTrackback', opts, 0) = 1)
    {
      insert into BLOG.DBA.MTYPE_TRACKBACK_PINGS (MP_POST_ID, MP_URL, MP_TITLE, MP_EXCERPT, MP_BLOG_NAME, MP_IP)
         values (id, sourceURI, '', '', title, http_client_ip ());

    }
  else
    {
      signal ('22023', 'Prohibited');
    }

  return 'Success';
}
;

grant execute on "pingback.ping" to MT
;


