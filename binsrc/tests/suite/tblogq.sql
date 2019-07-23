--
--  $Id: tblogq.sql,v 1.3.10.1 2013/01/02 16:15:00 source Exp $
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
--

create procedure make_wwwroot ()
{
  if (not exists (select 1 from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = '*weblog-root*'))
    {
      insert into
	  BLOG..SYS_BLOG_INFO (BI_BLOG_ID, BI_OWNER, BI_HOME, BI_TITLE, BI_COPYRIGHTS,
			       BI_DISCLAIMER, BI_ABOUT, BI_E_MAIL)
	  values ('*weblog-root*', http_dav_uid (), '/blog/', 'Welcome', '', '', 'Virtuoso Weblog', '');
      BLOG_WWWROOT ();
      BLOG_WWWROOT ();
     }
  if (not exists (select 1 from HTTP_PATH where HP_LPATH = '/RPC2' and HP_HOST = '*ini*'))
    {
	  declare bapi, i, l any;
	  declare grant_stmt, gst, gmsg varchar;
	  VHOST_DEFINE (lpath=>'/RPC2', ppath=>'/SOAP/', soap_user=>'MT', soap_opts=>vector ('XML-RPC', 'yes'));
	  bapi := "mt.supportedMethods" ();
          i := 0; l := length (bapi);
 	  while (i < l)
	    {
	      grant_stmt := 'grant execute on "'||bapi[i]||'" to "MT"';
	      gst := '00000';
	      exec (grant_stmt, gst, gmsg);
	      i := i + 1;
	    }
    }
}
;

create procedure blog_rpc_uri ()
{
  return 'http://localhost:'||server_http_port ()||'/RPC2';
}
;

create procedure sql_demo (in bid varchar)
  {
    declare req "blogRequest";
    declare stru "MTWeblogPost";
    req := new "blogRequest" ();
    req.appkey := 'appKey';
    req.blogid := bid;
    req.user_name := 'bloguser';
    req.passwd := 'bloguserpass';
    stru := new "MTWeblogPost" ();
    stru.title := 'select CompanyName from Demo.demo.Shippers';
    stru.description := '<table border="1">
    <sql:query xmlns:sql="urn:schemas-openlink-com:xml-sql" >
    select 1 as tag , null as parent, CompanyName as [tr!1!td!element] from Demo.demo.Shippers for
    xml explicit
    </sql:query>
    </table>';
    req.struct := stru;
    metaweblog.new_Post (blog_rpc_uri (), req);
  }
;

create procedure xquery_demo (in bid varchar)
  {
    declare req "blogRequest";
    declare stru "MTWeblogPost";
    req := new "blogRequest" ();
    req.appkey := 'appKey';
    req.blogid := bid;
    req.user_name := 'bloguser';
    req.passwd := 'bloguserpass';
    stru := new "MTWeblogPost" ();
    stru.title := 'XQuery';
    stru.description :=
    '<div>
    <sql:xquery  xmlns:sql="urn:schemas-openlink-com:xml-sql"
    sql:context="http://localhost:'|| server_http_port () ||'/">
    <![CDATA[
    <table border="1"> { for \$o in document ("opml.xml")//outline
    return <tr><td>{ string (\$o/@text) }</td></tr>
    }
    </table>
    ]]>
    </sql:xquery>
    </div>';
    req.struct := stru;
    metaweblog.new_Post (blog_rpc_uri (), req);
  }
;

create procedure make_user_blog_and_posts ()
  {
    declare uid int;
    if (exists (select 1 from SYS_USERS where U_NAME = 'bloguser'))
      return;
    uid := USER_CREATE ('bloguser', 'bloguserpass',
      vector ('DAV_ENABLE', 1, 'E-MAIL', 'example@domain', 'FULL_NAME', 'XML templates demo'));
    BLOG_HOME_CREATE (uid);
    exec ('grant select on Demo.demo.Shippers to bloguser');
    exec ('grant execute on DB.DBA.XML_URI_GET_STRING to bloguser');
    exec ('grant execute on DB.DBA.XML_URI_GET_STRING_OR_ENT to bloguser');
    commit work;
    sql_demo (cast (uid as varchar));
    xquery_demo (cast (uid as varchar));
  }
;

make_wwwroot ()
;

make_user_blog_and_posts ()
;

