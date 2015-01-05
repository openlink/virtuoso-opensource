--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2015 OpenLink Software
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

make_wwwroot ()
;

drop table blog_cache
;

drop table blog_settings
;

create table blog_cache (bc_key varchar, bc_id varchar, bc_post_id varchar, bc_created datetime,
             primary key (bc_key,bc_id,bc_post_id))
;

create index blog_cache_dt on blog_cache (bc_created)
;

create table blog_settings (bs_uid varchar primary key, bs_appkey varchar, bs_blogid varchar, bs_endpoint varchar)
;

create procedure
cal_icell (inout control vspx_control, in inx int)
{
  return (control.vc_parent as vspx_row_template).te_rowset[inx];
}
;

create procedure b_get_posts (in f date)
{
 declare arr any;
 declare i, l int;
 declare mblog BLOG.DBA.blogPost;
 declare content, postid varchar;
 declare dateCreated, n datetime;
 declare appkey, blogid, uid, pwd varchar;
 appkey := connection_get('appkey');
 blogid := connection_get('blogid');
 uid := connection_get('uid');
 pwd := connection_get('pwd');
 n := now ();
 if (f is null or (year (f) = year (n) and month (f) = month (n) and dayofmonth (f) = dayofmonth (n)))
   {
     arr := BLOG.blogger.get_Recent_Posts (connection_get('endpoint'),
			      BLOG.DBA.blogRequest (appkey, blogid, '', uid, pwd),
			      60);
     i := 0; l := length (arr);
     result_names (content, dateCreated, postid);
     while (i < l)
       {
	 mblog := arr[i];
	 if (i < 10)
	   result (mblog.content, mblog.dateCreated, mblog.postid);
	 insert soft blog_cache (bc_key, bc_id, bc_post_id, bc_created)
		values (appkey, blogid, mblog.postid, mblog.dateCreated);
	 i := i + 1;
       }
  }
 else
  {
    declare sdate, edate datetime;
    sdate := f;
    edate := dateadd ('day', 1, f);
    result_names (content, dateCreated, postid);
    for select bc_post_id from blog_cache where bc_key = appkey and bc_id = blogid and
        bc_created >= sdate and bc_created < edate order by 1 desc
       do
         {
           {
             declare exit handler for sqlstate '*' { goto nexti; };
             mblog := BLOG.blogger.get_Post (connection_get('endpoint'),
			      BLOG.DBA.blogRequest (appkey, blogid, bc_post_id, uid, pwd));
             result (mblog.content, mblog.dateCreated, mblog.postid);
           }
           nexti:;
         }
  }
}
;

create procedure bb_get (in f date)
{
  declare mtd, dta any;
  declare st, msg varchar;
  st := '00000';
  exec ('b_get_posts (?)', st, msg, vector (f), 0, mtd, dta);
  if (dta = 0)
    return vector ();
  return dta;
}
;

create procedure bb_meta (in f date)
{
  declare mtd, dta any;
  declare st, msg varchar;
  st := '00000';
  exec ('b_get_posts (?)', st, msg, vector (f), -1, mtd, dta );
  if (st = '00000')
   return mtd[0];
  else
   return vector ();
}
;

create procedure
b_date_fmt (in d datetime)
returns varchar
{
  declare n date;
  n := now ();
  if (d is null)
    return '';
  if (year (d) = year (n) and month (d) = month (n) and dayofmonth (d) = dayofmonth (n))
    return sprintf ('%02d:%02d:%02d', hour (d), minute (d), second (d));
  else
    return sprintf ('%d/%d/%d', month (d), dayofmonth (d), year (d));
}
;

create procedure
b_tit_fmt (in d datetime)
returns varchar
{
  declare n date;
  n := now ();
  if (d is null or (year (d) = year (n) and month (d) = month (n) and dayofmonth (d) = dayofmonth (n)))
    return 'Previous 10 posts...';
  else
    return sprintf ('Posts for %d/%d/%d...', month (d), dayofmonth (d), year (d));
}
;

create procedure
blog_user_password (in name varchar)
{
  declare pass varchar;
  pass := NULL;
  whenever not found goto none;
  select pwd_magic_calc (U_NAME, U_PASSWORD, 1) into pass
      from SYS_USERS where U_NAME = name and U_DAV_ENABLE = 1 and U_IS_ROLE = 0;
none:
  return pass;
}
;


create procedure
cell_fmt (in x any, in y any)
{
  return BLOG..cell_fmt (x, y);
}
;
