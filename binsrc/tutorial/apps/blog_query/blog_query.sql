--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2016 OpenLink Software
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
  if (not exists (select 1 from HTTP_PATH where HP_LPATH = '/RPC2' and HP_HOST = '*ini*'))
    {
	  declare bapi, i, l any;
	  declare grant_stmt, gst, gmsg varchar;
	  VHOST_DEFINE (lpath=>'/RPC2', ppath=>'/SOAP/', soap_user=>'MT', soap_opts=>vector ('XML-RPC', 'yes'));
	  bapi := BLOG.."mt.supportedMethods" ();
          i := 0; l := length (bapi);
 	  while (i < l)
	    {
	      grant_stmt := 'grant execute on BLOG.DBA."'||bapi[i]||'" to "MT"';
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
    declare req BLOG.."blogRequest";
    declare stru BLOG.."MTWeblogPost";
    req := new BLOG.."blogRequest" ();

    req.appkey := 'appKey';
    req.blogid := bid;
    req.user_name := 'bloguser';
    req.passwd := 'bloguserpass';
    stru := new BLOG.."MTWeblogPost" ();
    stru.title := 'select CompanyName from Demo.demo.Shippers';
    stru.description := '<table border="1">
    <sql:query xmlns:sql="urn:schemas-openlink-com:xml-sql" >
    select 1 as tag , null as parent, CompanyName as [tr!1!td!element] from Demo.demo.Shippers for
    xml explicit
    </sql:query>
    </table>';
    req.struct := stru;
    BLOG.metaweblog.new_Post (blog_rpc_uri (), req);
  }
;

create procedure xquery_demo (in bid varchar)
  {
    declare req BLOG.."blogRequest";
    declare stru BLOG.."MTWeblogPost";
    req := new BLOG.."blogRequest" ();

    req.appkey := 'appKey';
    req.blogid := bid;
    req.user_name := 'bloguser';
    req.passwd := 'bloguserpass';
    stru := new BLOG.."MTWeblogPost" ();
    stru.title := 'XQuery';
    stru.description :=
    '<div>
    <sql:xquery  xmlns:sql="urn:schemas-openlink-com:xml-sql"
    sql:context="http://localhost:'|| server_http_port () ||'/tutorial/apps/blog_query/">
    <![CDATA[
    <table border="1"> { for $o in document ("opml.xml")//outline
    return <tr><td>{ string ($o/@text) }</td></tr>
    }
    </table>
    ]]>
    </sql:xquery>
    </div>';
    req.struct := stru;
    BLOG.metaweblog.new_Post (blog_rpc_uri (), req);
  }
;

create procedure make_user_blog_and_posts ()
  {
    declare uid int;
    declare id any;
    declare inst DB.DBA.wa_blog2;

    if (exists (select 1 from SYS_USERS where U_NAME = 'bloguser'))
      return;
    uid := USER_CREATE ('bloguser', 'bloguserpass',
      vector ('DAV_ENABLE', 1, 'E-MAIL', 'example@domain', 'FULL_NAME', 'XML templates demo'));

    inst := new DB.DBA.wa_blog2 ();
    inst.wa_name := 'bloguser_blog';

    id := inst.wa_new_inst ('bloguser');

    whenever not found goto nf;
    select bi_blog_id into id from blog..sys_blog_info, sys_users where bi_owner = u_id and u_name = 'bloguser';

    exec ('grant select on Demo.demo.Shippers to bloguser');
    exec ('grant execute on DB.DBA.XML_URI_GET_STRING to bloguser');
    exec ('grant execute on DB.DBA.XML_URI_GET_STRING_OR_ENT to bloguser');
    commit work;
    sql_demo (id);
    xquery_demo (id);
    nf:;
  }
;

make_wwwroot ()
;

make_user_blog_and_posts ()
;

