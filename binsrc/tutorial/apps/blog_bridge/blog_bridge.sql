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

make_wwwroot ()
;

drop table blog_types
;

drop table blog_bridge_messages
;

drop table blog_bridge
;


create table blog_bridge (
   	bb_blog_id varchar,
	bb_endpoint varchar,
	bb_type varchar,
	bb_user varchar,
	bb_pwd varchar,
	bb_self_id varchar,
	primary key (bb_endpoint, bb_blog_id, bb_self_id)
)
;

create table blog_bridge_messages
	(
	bm_blog_id varchar,
	bm_endpoint varchar,
	bm_self_id varchar,
	bm_post_id varchar,
	bm_self_post_id varchar,
	bm_error long varchar,
	foreign key (bm_endpoint, bm_blog_id, bm_self_id) references
		blog_bridge (bb_endpoint, bb_blog_id, bb_self_id) on update cascade on delete cascade,
	primary key (bm_blog_id, bm_endpoint, bm_post_id)
	)
;


create procedure message_or_meta_data (inout meta any,
				       inout uid int, inout content any, inout postid varchar,
				       inout tms datetime)
{
  if (meta is not null)
    return meta;
  declare res BLOG.."MTWeblogPost";
  res := new BLOG.."MTWeblogPost" ();
  res.userid := (select U_NAME from SYS_USERS where U_ID = uid);
  res.description := blob_to_string (content);
  res.author := (select U_E_MAIL from SYS_USERS where U_ID = uid);
  res.dateCreated := tms;
  res.mt_allow_pings := 0;
  res.mt_allow_comments := 0;
  res.postid := postid;
  return res;
}
;


create trigger SYS_BLOGS_I1 after insert on BLOG..SYS_BLOGS order 90
{
  declare postid, fpostid varchar;
  postid := B_POST_ID;
  if (B_APPKEY = 'appKey_bridge')
    return;
  commit work;
  for select bb_endpoint, bb_blog_id, bb_type, bb_user, bb_pwd from blog_bridge where bb_self_id = B_BLOG_ID do
     {
       declare req BLOG.."blogRequest";
       req := new BLOG.."blogRequest" ('appKey_bridge', bb_blog_id, '', bb_user, bb_pwd);
       declare exit handler for sqlstate '*' {
	 insert into blog_bridge_messages values
	    (bb_blog_id, bb_endpoint, B_BLOG_ID, postid, postid, __SQL_MESSAGE);
	 goto next;
       };
       if (bb_type = 'Blogger')
	 {
           fpostid := BLOG.blogger.new_Post (bb_endpoint, req, B_CONTENT);
         }
       else if (bb_type = 'MetaWeblog' or bb_type = 'Moveable Type')
         {
           req.struct := message_or_meta_data (B_META, B_USER_ID, B_CONTENT, postid, B_TS);
           fpostid := BLOG.metaweblog.new_Post (bb_endpoint, req);
         }
       insert into blog_bridge_messages values (bb_blog_id, bb_endpoint, B_BLOG_ID, fpostid, postid, null);
       next: ;
     }
}
;

create trigger SYS_BLOGS_U1 after update on BLOG..SYS_BLOGS order 90 referencing old as O , new as N
{
  declare postid, fpostid varchar;
  postid := O.B_POST_ID;
  if (O.B_APPKEY = 'appKey_bridge')
    return;
  commit work;
  for select bb_endpoint, bb_blog_id, bb_type, bb_user, bb_pwd from blog_bridge where bb_self_id = O.B_BLOG_ID do
     {
       declare req BLOG.."blogRequest";
       for select bm_post_id from blog_bridge_messages where
	    bm_self_post_id = postid and
	    bm_endpoint = bb_endpoint and
	    bm_self_id = O.B_BLOG_ID and
	    bm_blog_id = bb_blog_id and
	    bm_error is null
       do
	 {
	    req := new BLOG.."blogRequest" ('appKey_bridge', bb_blog_id, bm_post_id, bb_user, bb_pwd);
	    declare exit handler for sqlstate '*'
	     {
	       update blog_bridge_messages set bm_error = __SQL_MESSAGE where
		   bm_self_post_id = postid and
		   bm_endpoint = bb_endpoint and
		   bm_self_id = O.B_BLOG_ID and
		   bm_blog_id = bb_blog_id ;
	       goto next;
	     };
	   if (bb_type = 'Blogger')
	     {
	       BLOG.blogger.edit_Post (bb_endpoint, req, N.B_CONTENT);
	     }
	   else if (bb_type = 'MetaWeblog' or bb_type = 'Moveable Type')
	     {
               req.struct := message_or_meta_data (N.B_META, N.B_USER_ID, N.B_CONTENT, postid, N.B_TS);
	       BLOG.metaweblog.edit_Post (bb_endpoint, req);
	     }
         }
       next: ;
     }
}
;

create trigger SYS_BLOGS_D1 after delete on BLOG..SYS_BLOGS order 90 referencing old as O
{
  declare postid, fpostid varchar;
  postid := O.B_POST_ID;
  if (O.B_APPKEY = 'appKey_bridge')
    return;
  commit work;
  for select bb_endpoint, bb_blog_id, bb_type, bb_user, bb_pwd from blog_bridge where bb_self_id = O.B_BLOG_ID do
     {
       declare req BLOG.."blogRequest";
       for select bm_post_id from blog_bridge_messages where
	    bm_self_post_id = postid and
	    bm_endpoint = bb_endpoint and
	    bm_self_id = O.B_BLOG_ID and
	    bm_blog_id = bb_blog_id and
	    bm_error is null
       do
	 {
	   req := new BLOG.."blogRequest" ('appKey_bridge', bb_blog_id, bm_post_id, bb_user, bb_pwd);
	   declare exit handler for sqlstate '*' { goto next; };
	   if (bb_type = 'Blogger' or bb_type = 'MetaWeblog' or bb_type = 'Moveable Type')
	     {
	       BLOG.blogger.delete_Post (bb_endpoint, req);
	     }
         }
	next:
	delete from blog_bridge_messages where
	     	bm_self_post_id = postid and
		bm_endpoint = bb_endpoint and
		bm_self_id = O.B_BLOG_ID and
		bm_blog_id = bb_blog_id;
     }
}
;

create table blog_types (
 	bt_name varchar primary key
)
;

insert into blog_types values ('Blogger')
;

insert into blog_types values ('MetaWeblog')
;

insert into blog_types values ('Moveable Type')
;

create procedure
cal_icell (inout control vspx_control, in inx int)
{
  return (control.vc_parent as vspx_row_template).te_rowset[inx];
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


create procedure blog_get_user_blogs (in uri varchar, in name varchar, in passwd varchar)
{
  declare i, l int;
  declare blogid, blogname, url varchar;
  declare arr any;
  arr := BLOG.blogger.get_Users_Blogs (uri, BLOG..blogRequest ('appKey', '', '', name, passwd));
  i := 0; l := length (arr);
  result_names (blogid, blogname, url);
  while (i < l)
    {
      blogid := get_keyword ('blogid', arr[i]);
      blogname := get_keyword ('blogname', arr[i]);
      url := get_keyword ('url', arr[i]);
      result (blogid, blogname, url);
      i := i + 1;
    }
}
;

drop view blog_user_blogs
;

create procedure view blog_user_blogs as blog_get_user_blogs (uri, name, passwd) (blogid varchar, blogname varchar, url varchar)
;
