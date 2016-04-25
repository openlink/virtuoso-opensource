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

use DB
;

create procedure blog2_exec_no_error(in expr varchar) {
  declare state, message, meta, result any;
  exec(expr, state, message, vector(), 0, meta, result);
}
;

-- eliminate old 'blog' application from WA
delete from DB.DBA.WA_TYPES where WAT_NAME = 'WEBLOG'
;

delete from DB.DBA.WA_MEMBER_TYPE where WMT_APP = 'db.dba.wa_blog'
;

delete from DB.DBA.WA_INSTANCE where WAI_NAME = 'db.dba.wa_blog'
;

-- create new blog2 application in WA
blog2_exec_no_error('
  create type wa_blog2 under web_app as (
    blogid varchar,
    owner  int
  )
  constructor method wa_blog2(stream any),
  overriding method wa_id_string() returns any,
  overriding method wa_new_inst(login varchar) returns any,
  overriding method wa_join_request(login varchar) returns any,
  overriding method wa_leave_notify(login varchar) returns any,
  overriding method wa_membership_edit_form (stream any) returns any,
  overriding method wa_front_page (stream any) returns any,
  overriding method wa_state_edit_form(stream any) returns any,
  overriding method wa_state_posted(post any, stream any) returns any,
  overriding method wa_home_url() returns varchar,
  overriding method wa_periodic_activity() returns any,
  overriding method wa_drop_instance() returns any,
  overriding method wa_private_url() returns any,
  overriding method wa_join_approve(login varchar) returns any,
  overriding method wa_member_data (u_id int, stream any) returns any,
  overriding method wa_member_data_edit_form (u_id int, stream any) returns any,
  overriding method wa_class_details () returns varchar,
  overriding method wa_https_supported () returns int,
  overriding method wa_dashboard () returns any,
  overriding method wa_addition_urls () returns any,
  overriding method wa_addition_instance_urls () returns any,
  method wa_vhost_options () returns any,
  method wa_new_inst_from_old_blog(login varchar, blogid varchar) returns any,
  method wa_dashboard_last_item () returns any
  '
)
;

wa_exec_no_error('alter type wa_blog2 add overriding method wa_front_page_as_user(inout stream any, in user_name varchar) returns any');

wa_exec_no_error('alter type wa_blog2 add overriding method wa_size() returns int');
wa_exec_no_error('alter type wa_blog2 add method wa_vhost_options () returns any');
wa_exec_no_error('alter type wa_blog2 add method wa_dashboard_last_item () returns any');
wa_exec_no_error('alter type wa_blog2 add overriding method wa_rdf_url (in vhost varchar, in lhost varchar) returns varchar');
wa_exec_no_error('alter type wa_blog2 add overriding method wa_post_url (in vhost varchar, in lhost varchar, in inst_name varchar, in post any) returns varchar');


insert replacing DB.DBA.WA_TYPES(WAT_NAME, WAT_DESCRIPTION, WAT_TYPE, WAT_REALM) values ('WEBLOG2', 'Blog', 'db.dba.wa_blog2', 'wa')
;

insert soft DB.DBA.WA_MEMBER_TYPE (WMT_APP, WMT_NAME, WMT_ID, WMT_IS_DEFAULT) values ('WEBLOG2', 'author', 2, 0)
;

insert soft DB.DBA.WA_MEMBER_TYPE (WMT_APP, WMT_NAME, WMT_ID, WMT_IS_DEFAULT) values ('WEBLOG2', 'reader', 3, 0)
;

-- upgrade from previous versions
delete from DB.DBA.WA_MEMBER_TYPE where WMT_ID < 2
;



create method wa_id_string () for wa_blog2 {
  return 'weblog2_' || self.blogid || '_' || cast (self.owner as varchar);
}
;

create constructor method wa_blog2 (inout stream any) for wa_blog2 {
  ;
}
;

create method wa_member_data (in u_id int, inout stream any) for wa_blog2 {
  return 'N/A';
}
;

create method wa_member_data_edit_form (in u_id int, inout stream any) for wa_blog2 {
  declare home, sid varchar;
  select BI_HOME into home from BLOG.DBA.SYS_BLOG_INFO, "DB"."DBA"."SYS_USERS"
  where BI_BLOG_ID = self.blogid and BI_OWNER = self.owner;

  sid := connection_get ('wa_sid');

  if (sid is null)
    {
      sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
      insert into DB.DBA.VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
      values ('wa', sid, connection_get ('vspx_user'),
      serialize (
	vector (
	  'vspx_user', connection_get ('vspx_user'),
	  'blogid' , self.blogid,
	  'uid', connection_get ('vspx_user')
	  )
	), now());
    }
  http_request_status ('HTTP/1.1 302 Found');
  http_header(sprintf('Location: %sindex.vspx?page=member_data&member_id=%d&sid=%s&realm=wa\r\n', home, u_id, sid));
  return;
}
;

create method wa_drop_instance () for wa_blog2 {
  declare blog_home, blog_path any;
  blog_home := (select BI_HOME from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = self.blogid);
  blog_path := (select BI_P_HOME from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = self.blogid);
  blog_home := subseq(blog_home, 0, length(blog_home) - 1);
  for select BI_P_HOME from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = self.blogid do {
    delete from WS.WS.SYS_DAV_RES where RES_FULL_PATH like BI_P_HOME||'%';
    delete from WS.WS.SYS_DAV_COL where WS.WS.COL_PATH (COL_ID) like BI_P_HOME||'%';
  }
  delete from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = self.blogid;
  (self as web_app).wa_drop_instance();
  DB.DBA.VHOST_REMOVE(lpath => blog_home);
  DB.DBA.VHOST_REMOVE(lpath => blog_home || '/templates');
  DB.DBA.VHOST_REMOVE(lpath => blog_home || '/gems');
  DB.DBA.VHOST_REMOVE(lpath => blog_home || '/images');
  DB.DBA.VHOST_REMOVE(lpath => blog_home || '/audio');
  for select HP_HOST, HP_LISTEN_HOST, HP_LPATH from DB.DBA.HTTP_PATH where
      HP_PPATH = blog_path and
      HP_HOST not like '%ini%'and HP_HOST not like '*sslini*'
  do
  {
    DB.DBA.VHOST_REMOVE(vhost=>HP_HOST, lhost=>HP_LISTEN_HOST, lpath=>HP_LPATH);
  }
  -- call parent method to make wa level application and membership management action
}
;

create method wa_join_request (in login varchar) for wa_blog2 {
  -- empty one
  ;
}
;

create method wa_join_approve (in login varchar) for wa_blog2 {
  -- empty one
  ;
}
;

create procedure blog_ensure_domain (inout inst wa_blog2, in vhost any, in lhost any)
{
  declare dirs any;
  dirs := inst.wa_addition_urls ();
  foreach (any dir in dirs) do
    {
      if (not exists (select 1 from DB.DBA.HTTP_PATH where HP_HOST = vhost and HP_LISTEN_HOST = lhost and HP_LPATH = dir[2]))
  {
    VHOST_DEFINE(
        vhost=>vhost,
        lhost=>lhost,
        lpath=>dir[2],
        ppath=>dir[3],
        is_dav=>dir[4],
        is_brws=>dir[5],
        def_page=>dir[6],
        auth_fn=>dir[7],
        realm=>dir[8],
        ppr_fn=>dir[9],
        vsp_user=>dir[10],
        soap_user=>dir[11],
        sec=>dir[12],
        ses_vars=>dir[13],
        soap_opts=>dir[14],
        auth_opts=>dir[15],
        opts=>dir[16],
        is_default_host=>dir[17]);
  }
    }
}
;

-- owner makes a new blog
create method wa_new_inst (in login varchar) for wa_blog2 {
  declare uid, id, num, _mem_model int;
  declare inst_name, descr, folder, home, blogid, path varchar;
  declare inst wa_blog;

  home := connection_get('blog2_home');
  uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = login);

  num := (select count(*) from BLOG.DBA.SYS_BLOG_INFO where BI_OWNER = uid);

again:
  blogid := sprintf ('%s-blog-%d', login, num);
  if (exists (select 1 from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = blogid))
    {
      num := num + 1;
      goto again;
    }

  folder := sprintf ('/DAV/home/%s/%s/', login, blogid);

  path := sprintf ('/DAV/home/%s/Blogs/', login);
  DB.DBA.DAV_MAKE_DIR (path, uid, null, '110100000N');
  update WS.WS.SYS_DAV_COL set COL_DET = 'Blog' where COL_ID = DAV_SEARCH_ID (path, 'C');

  BLOG.DBA.BLOG2_HOME_CREATE (uid, blogid, folder, home);

  self.blogid := blogid;
  self.owner := uid;

  if(self.wa_name is null or length(self.wa_name) = 0) {
    signal('WA002', 'self.wa_name can not be empty');
  }

  select BI_TITLE, BI_WAI_MEMBER_MODEL into descr, _mem_model from BLOG.DBA.SYS_BLOG_INFO
  where BI_BLOG_ID = self.blogid;
  if (_mem_model is null)
    _mem_model := 0;
  update BLOG.DBA.SYS_BLOG_INFO set BI_WAI_NAME=self.wa_name, BI_WAI_MEMBER_MODEL=_mem_model
  where  BI_BLOG_ID = self.blogid;

  insert into DB.DBA.WA_INSTANCE (WAI_NAME, WAI_TYPE_NAME, WAI_INST, WAI_DESCRIPTION, WAI_MEMBER_MODEL)
    values (self.wa_name, 'WEBLOG2', self, descr, _mem_model);

  -- call parent method to make wa level membership management action
  return (self as web_app).wa_new_inst(login);
}
;

create method wa_new_inst_from_old_blog(in login varchar, in old_blogid varchar) for wa_blog2 {
  declare uid, id, blogid, num int;
  declare inst_name, blog_name, descr, folder varchar;
  declare inst wa_blog;

  uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = login);

  if (not exists (select 1 from BLOG.DBA.SYS_BLOG_INFO where BI_OWNER = uid)) {
    num := 0;
  }
  else {
    num := (select count(*) from BLOG.DBA.SYS_BLOG_INFO where BI_OWNER = uid);
  }

  -- determine old blog physical path in DAV
  declare old_p_path any;
  old_p_path := (select BI_P_HOME from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = old_blogid);

  -- determine old photo path in DAV
  declare _photo, descrip, oldopts any;
  whenever not found goto nfb;
  select BI_PHOTO, BI_ABOUT, BI_TITLE, deserialize (blob_to_string (BI_OPTIONS))
      into _photo, descrip, descr, oldopts from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = old_blogid;
  nfb:

  folder := sprintf ('/DAV/home/%s/%s/', login, old_blogid);
  self.blogid := old_blogid;

  BLOG.DBA.BLOG2_HOME_CREATE(uid, self.blogid, folder);
  BLOG..BLOG2_SET_OPTION ('WelcomeMessage', oldopts, descrip);

  if(self.wa_name is null or length(self.wa_name) = 0) {
    signal('WA002', 'self.wa_name can not be empty');
  }

  self.wa_member_model := 0;
  self.owner := uid;

  insert into DB.DBA.WA_INSTANCE (WAI_NAME, WAI_TYPE_NAME, WAI_INST, WAI_DESCRIPTION)
    values (self.wa_name, 'WEBLOG2', self, descr);

  -- determine new blog physical path in DAV
  declare new_p_path, vhosts any;
  new_p_path := (select BI_P_HOME from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = self.blogid);

  -- keep an analogue of old one to preserve foreign references
  DB.DBA.VHOST_DEFINE (lpath=>sprintf ('/blog/%s/blog', login), ppath=>new_p_path, vsp_user=>'dba', is_dav=>1,
      def_page => 'index.vspx', is_brws=>0, ppr_fn=>'BLOG.DBA.BLOG2_RSS2WML_PP', ses_vars=>1);

  -- remove old VDs
  for select p.HP_HOST as HOST, p.HP_LISTEN_HOST as LISTEN_HOST, p.HP_LPATH as LPATH
    from DB.DBA.HTTP_PATH p where p.HP_PPATH = old_p_path do
    {
      http_map_del (LPATH, HOST, LISTEN_HOST);
      -- remove descendant gems directory
      if (exists (select 1 from DB.DBA.HTTP_PATH p1 where p1.HP_PPATH = concat (old_p_path, 'gems/')
      and p1.HP_LISTEN_HOST = LISTEN_HOST and p1.HP_HOST = HOST and p1.HP_LPATH = concat (LPATH, '/gems')))
        VHOST_REMOVE (HOST, LISTEN_HOST, concat (LPATH,'/gems'));
    }

  vhosts := vector ();
  for select distinct HP_HOST, HP_LISTEN_HOST from DB.DBA.HTTP_PATH where HP_PPATH = old_p_path do
    {
      vhosts := vector_concat (vhosts, vector (vector (HP_HOST, HP_LISTEN_HOST)));
    }

  -- update the old VDs with new physical location
  update DB.DBA.HTTP_PATH set HP_PPATH = new_p_path, HP_POSTPROCESS_FUNC = 'BLOG.DBA.BLOG2_RSS2WML_PP'
  where HP_PPATH = old_p_path;

  -- put the new VDs in the set
  for select HP_LPATH, HP_PPATH, HP_HOST, HP_LISTEN_HOST, HP_STORE_AS_DAV, HP_DIR_BROWSEABLE,
           HP_DEFAULT, HP_SECURITY, HP_REALM, HP_AUTH_FUNC, HP_POSTPROCESS_FUNC, HP_RUN_VSP_AS,
             HP_RUN_SOAP_AS, HP_PERSIST_SES_VARS, HP_SOAP_OPTIONS, HP_AUTH_OPTIONS, HP_OPTIONS, HP_IS_DEFAULT_HOST
       from DB.DBA.HTTP_PATH where HP_PPATH = new_p_path do
    {
      http_map_table (HP_LPATH, HP_PPATH, HP_HOST, HP_LISTEN_HOST, HP_STORE_AS_DAV,
    HP_DIR_BROWSEABLE, HP_DEFAULT, HP_SECURITY, HP_REALM, HP_AUTH_FUNC, HP_POSTPROCESS_FUNC, HP_RUN_VSP_AS,
    HP_RUN_SOAP_AS, HP_PERSIST_SES_VARS,
    deserialize (HP_SOAP_OPTIONS), deserialize (HP_AUTH_OPTIONS), deserialize (HP_OPTIONS), HP_IS_DEFAULT_HOST);
    }

  foreach (any vd in vhosts) do
    {
      blog_ensure_domain (self, vd[0], vd[1]);
    }

  -- change old blog's resources path in DAV to new one
  declare _resources any;
  _resources := vector();

  for select RES_FULL_PATH, RES_PERMS, RES_OWNER, RES_GROUP
    from WS.WS.SYS_DAV_RES where RES_FULL_PATH like concat(old_p_path, '%')  do
      {
        _resources := vector_concat(_resources, vector(vector (RES_FULL_PATH, RES_PERMS, RES_OWNER, RES_GROUP)));
      }

  declare _idx, _old_res, _new_res, _dav_name, _dav_uid, _dav_pwd any;
  _dav_uid := http_dav_uid();
  _dav_name := (select U_NAME from WS.WS.SYS_DAV_USER where U_ID = _dav_uid);
  _dav_pwd := (select pwd_magic_calc (U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = _dav_uid);
  _idx := 0;
  while(_idx < length(_resources)) {
    declare res_mime any;
    _old_res := _resources[_idx][0];
    res_mime := http_mime_type (_old_res);
    if (res_mime like 'image/%' or res_mime like 'audio/%' or res_mime like 'video/%' or lower (_old_res) like '%.wma')
      {
        if(_old_res not like concat(old_p_path, '%/%.%')) {
        -- additional directory level doesn't exists
        _new_res := replace(_old_res, old_p_path, concat(new_p_path, 'images/'));
      }
      else {
        -- additional directory level exists and equal 'images'
        if(_old_res like concat(old_p_path, 'images/%.%')) {
          _new_res := replace(_old_res, old_p_path, new_p_path);
        }
        else {
          -- skip unknown resource
          goto skip;
        }
      }
      DAV_COPY (_old_res, _new_res, 0, _resources[_idx][1], _resources[_idx][2], _resources[_idx][3], _dav_name, _dav_pwd);
    }
    skip:
    _idx := _idx + 1;
  }
  -- update personal photo position
  if(_photo is not null and length(_photo) > 0)
    {
      _photo := concat('images/', _photo);
    }
  update BLOG.DBA.SYS_BLOG_INFO
    set BI_PHOTO = _photo, BI_OPTIONS = serialize (oldopts) where BI_BLOG_ID = self.blogid;

  -- call parent method to make wa level membership management action
  return (self as web_app).wa_new_inst(login);
}
;

-- owner makes a new blog
create method wa_class_details () for wa_blog2
{
  declare info varchar;
  info := 'The Virtuoso Weblog Application allows you to run an online diary system. Like a diary it can be a private system, however in the spirit of weblog these are often public for outsides to pass comment.  Weblog supports community based operation to keep groups of weblogs together for collaboration of friends or fellow members of an organization department.';
  return info;
}
;

-- owner makes a new blog
create method wa_https_supported () for wa_blog2
{
  return 0;
}
;

create method wa_membership_edit_form (inout stream any) for wa_blog2
{
  declare home, sid varchar;
  select BI_HOME into home from BLOG.DBA.SYS_BLOG_INFO, DB.DBA.SYS_USERS
  where BI_BLOG_ID = self.blogid and BI_OWNER = self.owner;
  sid := connection_get ('wa_sid');

  if (sid is null)
    {
      sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
      insert into DB.DBA.VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
	  values ('wa', sid, connection_get ('vspx_user'),
	      serialize (
		vector (
		  'vspx_user', connection_get ('vspx_user'),
		  'blogid' , self.blogid,
		  'uid', connection_get ('vspx_user')
		  )
		), now());
    }
  http_request_status ('HTTP/1.1 302 Found');
  http_header(sprintf('Location: %sindex.vspx?page=membership&sid=%s&realm=wa\r\n', home, sid));
  return;
}
;

create method wa_front_page (inout stream any) for wa_blog2
{
  declare home, sid, phome varchar;
  select BI_HOME, BI_P_HOME into home, phome from BLOG.DBA.SYS_BLOG_INFO
  where BI_BLOG_ID = self.blogid and BI_OWNER = self.owner;

  if (is_http_ctx ())
    {
      declare vh, lh any;
      vh := http_map_get ('vhost');
      lh := http_map_get ('lhost');
      declare exit handler for not found
        {
          signal ('NOPAT', 'You do not have any virtual directory defined within current domain. Please define one.');
        };
      select HP_LPATH into home from DB.DBA.HTTP_PATH where HP_HOST = vh and HP_LISTEN_HOST = lh and HP_PPATH = phome;
      if (home not like '%/' and home <> '/')
        home := home || '/';
    }

  sid := connection_get ('wa_sid');

  if (sid is null)
    {
      sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
      insert into DB.DBA.VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
      values ('wa', sid, connection_get ('vspx_user'),
      serialize (
	vector (
	  'vspx_user', connection_get ('vspx_user'),
	  'blogid' , self.blogid,
	  'uid', connection_get ('vspx_user'),
	  'go_to_wa', 'yes'
	  )
	), now());
    }
  http_request_status ('HTTP/1.1 302 Found');
  http_header (sprintf('Location: %sindex.vspx?page=index&sid=%s&realm=wa\r\n', home, sid));
  return;
}
;

create method wa_front_page_as_user (inout stream any, in user_name varchar) for wa_blog2
{
  declare home, sid, phome, owner_name varchar;
  select BI_HOME, BI_P_HOME, U_NAME into home, phome, owner_name from BLOG.DBA.SYS_BLOG_INFO, "DB"."DBA"."SYS_USERS"
  where BI_BLOG_ID = self.blogid and BI_OWNER = self.owner and U_ID = BI_OWNER;


  if (is_http_ctx ())
    {
      declare vh, lh any;
      vh := http_map_get ('vhost');
      lh := http_map_get ('lhost');
      declare exit handler for not found
        {
          signal ('NOPAT', 'You do not have any virtual directory defined within current domain. Please define one.');
        };
      select HP_LPATH into home from DB.DBA.HTTP_PATH where HP_HOST = vh and HP_LISTEN_HOST = lh and HP_PPATH = phome;
      if (home not like '%/' and home <> '/')
        home := home || '/';
    }

  sid := connection_get ('wa_sid');

  if (sid is null)
    {
      sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
      insert into DB.DBA.VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
      values ('wa', sid, owner_name,
      serialize (
	vector (
	  'vspx_user', user_name,
	  'blogid' , self.blogid,
	  'uid', user_name
	  )
	), now());
    }
  http_request_status ('HTTP/1.1 302 Found');
  http_header (sprintf('Location: %sindex.vspx?page=index&sid=%s&realm=wa\r\n', home, sid));
  return;
}
;

create method wa_state_edit_form (inout stream any) for wa_blog2 {
  declare home, sid, phome varchar;

  select BI_HOME, BI_P_HOME into home, phome from BLOG.DBA.SYS_BLOG_INFO
  where BI_BLOG_ID = self.blogid and BI_OWNER = self.owner;

  if (is_http_ctx ())
    {
      declare vh, lh any;
      vh := http_map_get ('vhost');
      lh := http_map_get ('lhost');
      declare exit handler for not found
        {
          signal ('NOPAT', 'You do not have any virtual directory defined within current domain. Please define one.');
        };
      select HP_LPATH into home from DB.DBA.HTTP_PATH where HP_HOST = vh and HP_LISTEN_HOST = lh and HP_PPATH = phome;
      if (home not like '%/' and home <> '/')
        home := home || '/';
    }

  sid := connection_get ('wa_sid');

  if (sid is null)
    {
      sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
      insert into DB.DBA.VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
      values ('wa', sid, connection_get ('vspx_user'),
      serialize (
	vector (
	  'vspx_user', connection_get ('vspx_user'),
	  'blogid' , self.blogid,
	  'uid', connection_get ('vspx_user')
	  )
	), now());
    }
  http_request_status ('HTTP/1.1 302 Found');
  http_header (sprintf('Location: %sindex.vspx?page=ping&sid=%s&realm=wa\r\n', home, sid));
  return;
}
;

create method wa_state_posted (in post any, inout stream any) for wa_blog2 {
  -- empty one
  ;
}
;

create method wa_home_url () for wa_blog2 {
  declare uri varchar;
  uri := null;
  whenever not found goto endf;
  select BI_HOME into uri from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = self.blogid;
  endf:
  return uri;
}
;


create method wa_rdf_url (in vhost varchar, in lhost varchar) for wa_blog2
{
  declare p_path_str, l_path_str, full_path varchar;
  p_path_str := (select BI_P_HOME from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = self.blogid);
  if (p_path_str is null)
    signal ('22023', 'No such blog');
  l_path_str := (select top 1 HP_LPATH from DB.DBA.HTTP_PATH where HP_PPATH = p_path_str and HP_HOST = vhost and HP_LISTEN_HOST = lhost);
  if (l_path_str is null)
    signal ('22023', 'No virtual directory found.');
  full_path := concat (l_path_str, '/gems/index.rdf');
  return full_path;
}
;

create method wa_post_url (in vhost varchar, in lhost varchar, in inst_name varchar, in post any) for wa_blog2
{
  declare p_path_str, l_path_str, full_path varchar;
  p_path_str := (select BI_P_HOME from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = self.blogid);
  if (p_path_str is null)
    signal ('22023', 'No such blog');
  l_path_str := (select top 1 HP_LPATH from DB.DBA.HTTP_PATH where HP_PPATH = p_path_str and HP_HOST = vhost and HP_LISTEN_HOST = lhost);
  if (l_path_str is null)
    signal ('22023', 'No virtual directory found.');
  full_path := concat (rtrim (l_path_str, '/'), '/?id=', post);
  return full_path;
};

create method wa_private_url () for wa_blog2 {
  declare uri varchar;
  uri := null;
  whenever not found goto endf;
  select BI_HOME into uri from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = self.blogid;
  endf:
  return uri;
}
;

create method wa_periodic_activity () for wa_blog2 {
  return;
}
;

create procedure DB.DBA.BLOG2_GET_USER_ACCESS(in blogid varchar, in usr varchar, in pwd varchar default null)
{
  declare _is_public, _role, _status any;
  _is_public := 0;
  _role := 0;
  _status := 0;
  -- check if blog instance exists
  declare _wai_name any;
  _wai_name := (select BI_WAI_NAME from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = blogid);
  if(_wai_name is null) signal('WA001', 'Application instance not found.');
  -- check if blog instance is public
  _is_public := (select WAI_IS_PUBLIC from DB.DBA.WA_INSTANCE where WAI_NAME = _wai_name);
  if(_is_public is null) _is_public := 0;
  if(usr is not null)
  {
    if(exists(select 1 from DB.DBA.SYS_USERS where U_NAME = usr and U_DAV_ENABLE = 1 and U_IS_ROLE = 0)) {
      declare _user_id any;
      _user_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = usr);
      -- validate password if necessary
      if(pwd is not null) {
        declare _real_pwd any;
        _real_pwd := (select pwd_magic_calc(U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_ID = _user_id);
        if(pwd <> _real_pwd) return 0;
      }
      -- if it's registered user - check his role against current blog
      -- if several roles assigned to one user - use the best one (minimum value)
      _role := (select min(WAM_MEMBER_TYPE) from DB.DBA.WA_MEMBER
  where WAM_STATUS <= 2 and WAM_USER = _user_id and WAM_INST = _wai_name
    and (WAM_MEMBER_SINCE < now() or WAM_MEMBER_SINCE is null) and (WAM_EXPIRES > now() or WAM_EXPIRES is null));
      _status := (select WAM_STATUS from DB.DBA.WA_MEMBER where WAM_USER = _user_id
  and WAM_INST = _wai_name and (WAM_MEMBER_SINCE < now() or WAM_MEMBER_SINCE is null)
     and (WAM_EXPIRES > now() or WAM_EXPIRES is null));
      if(_status = 1) _role := 1;  -- owner
      if(_role is null) _role := 0;
    }
  }
  commit work;
  -- return 0 in no access, 1 if owner, 2 if author, 3 if can read (reader or blog is public);
  if(_role in (1, 2)) return _role;
  if(_is_public) return 3;
  return _role;
}
;

create procedure DB.DBA.BLOG2_CREATE_SID() {
  return md5(concat(datestring(now()), http_client_ip (), http_path ()));
}
;

create procedure DB.DBA.BLOG2_GET_USER_BY_SESSION(in sid varchar, in realm varchar, in minutes integer default 30) {
  declare _last_ip, _cookie_use, _opts, _date_exp, _usr any;
  _usr := NULL;
  _cookie_use := 0;
  whenever not found goto not_found;
  select
    VS_UID,
    VS_EXPIRY,
    deserialize(blob_to_string(VS_STATE))
  into
    _usr,
    _date_exp,
    _opts
  from
    DB.DBA.VSPX_SESSION
  where
    VS_REALM = realm and
    VS_SID = sid;
  if(_opts is not null) {
    _cookie_use := get_keyword('cookie_use', _opts, 0);
    _last_ip := get_keyword('last_ip', _opts, '');
  }
  if(_cookie_use = 0) {
    -- take into account session expiration
    if(datediff('minute', _date_exp, now()) > minutes) {
      _usr := NULL;
    }
  }
  else {
    -- take into account initial ip
    if(_last_ip <> http_client_ip()) {
      _usr := NULL;
    }
  }
not_found:
  return _usr;
}
;

create procedure DB.DBA.BLOG2_GET_ACCESS(in blogid varchar, inout sid varchar, in realm varchar, in minutes integer default 30) {
  declare _usr, _rights, _new_sid any;
  _usr := DB.DBA.BLOG2_GET_USER_BY_SESSION(sid, realm, minutes);
  _rights := DB.DBA.BLOG2_GET_USER_ACCESS(blogid, _usr);
  if(_usr is not null and _rights > 0)
  {
    -- change sid to new one at each access if it necessary
    declare _opts, _sid_mutation any;
    _sid_mutation := 0;
    _opts := (select
                deserialize (blob_to_string (BI_OPTIONS))
              from
                BLOG.DBA.SYS_BLOG_INFO
              where
                BI_BLOG_ID = blogid);
    if(_opts is not null)
    {
      _sid_mutation := get_keyword('EnableSIDMutation', _opts, 0);
    }
    if(_sid_mutation > 0)
    {
      _new_sid := DB.DBA.BLOG2_CREATE_SID();
      update DB.DBA.VSPX_SESSION set VS_SID = _new_sid where VS_SID = sid and VS_REALM = realm and VS_UID = _usr;
      sid := _new_sid;
    }
  }
  else if (length (sid))
  {
    delete from DB.DBA.VSPX_SESSION where VS_SID = sid and VS_REALM = realm;
    sid := null;
  }
  return _rights;
}
;

create procedure DB.DBA.BLOG2_GEMS_AUTH(in realm varchar) {
  declare hdr, lines, auth, usr, pwd, domain, blogid any;
  blogid := (select
               BI_BLOG_ID
             from
               BLOG.DBA.SYS_BLOG_INFO
             where
               BI_HOME = subseq(http_path(), 0, strrchr(http_path(), '/gems/') - 4));
  --check if blog is public
  if(DB.DBA.BLOG2_GET_USER_ACCESS(blogid, '', '') > 0) {
    return 1;
  }
  -- check if auth data are received
  lines := http_request_header();
  domain := http_path();
  domain := subseq(domain, 0, strstr(domain, '/gems/') + 6);
  auth := vsp_auth_vec(lines);
  if(0 <> auth) {
    usr := get_keyword ('username', auth, '');
    pwd := get_keyword ('pass', auth, '');
    if(DB.DBA.BLOG2_GET_USER_ACCESS(blogid, usr, pwd) > 0) {
      return 1;
    }
  }
  vsp_auth_get('Weblog authentication',
               domain,
               md5(datestring (now ())),
               md5('IfYouWantSomethingDoneDoItYourself'),
               'false',
               lines,
               1);
  http('<HTML><HEAD><TITLE>Unauthorized</TITLE></HEAD><BODY><H2>XML Resource</H2>You are not authorized</BODY></HTML>');
  return 0;
}
;

create method wa_dashboard () for wa_blog2 {
  declare url varchar;
  url := sioc..forum_iri ('weblog', self.wa_name);
  return ( select
              XMLAGG(XMLELEMENT('dash-row',
                         XMLATTRIBUTES('normal' as "class", BLOG.DBA.BLOG2_DATE_FOR_HUMANS(B_TS) as "time", self.wa_name as "application"),
                         XMLELEMENT('dash-data',
	    XMLATTRIBUTES(

	      concat ( N'<a href="' , cast (url as nvarchar),
	       	       N'/', cast (B_POST_ID as nvarchar), N'">',
		       charset_recode (BLOG.DBA.BLOG2_GET_TITLE (B_META, B_CONTENT), 'UTF-8', '_WIDE_'), N'</a>')

	      "content", B_COMMENTS_NO "comments")
                         )
                    )
              )
            from
      (select top 10 * from BLOG.DBA.SYS_BLOGS where B_STATE = 2 and B_BLOG_ID = self.blogid order by B_TS desc) T);
}
;

create method wa_size () for wa_blog2
{
  declare tot, tot2 int;
  declare path varchar;
  tot := 0;
  path := '';
  whenever not found goto endf;
  select sum (length (B_CONTENT)) into tot from BLOG.DBA.SYS_BLOGS where B_BLOG_ID = self.blogid;
  select BI_P_HOME into path from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = self.blogid;
  tot2 := coalesce ((select sum (length (RES_CONTENT)) from WS.WS.SYS_DAV_RES where RES_FULL_PATH like path || '%'), 0);
  tot := (tot + tot2)/1024;
  endf:
  return tot;
}
;

create method wa_dashboard_last_item () for wa_blog2
{
  declare ret any;
  whenever not found goto nf;
  ret := null;
  select BI_DASHBOARD into ret from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = self.blogid;
  nf:;
  return ret;
};

create method wa_addition_urls () for wa_blog2 {
  return vector(
    vector(null, null, '/weblog/public', registry_get('_blog2_path_') || 'public', 1, 0, null, null, null, null, 'dba', null, null, 1, null, null, null, 0),
    vector(null, null, '/weblog/templates', registry_get('_blog2_path_') || 'templates', 1, 0, null, null, null, null, 'dba', null, null, 1, null, null, null, 0),
    vector(null, null, '/RPC2', '/SOAP/', 0, 0, null, null, null, null, null, 'MT', null, 1, vector('XML-RPC', 'yes'), null, null, 0),
    vector(null, null, '/Atom', '/SOAP/Http/gdata', 0, 0, null, null, null, null, null, 'MT', null, 1, vector ('atom-pub', 1), null, null, 0),
    vector(null, null, '/mt-tb', '/SOAP/', 0, 0, null, null, null, null, null, 'MT', null, 1, vector('XML-RPC', 'yes'), null, null, 0),

    vector(null, null, '/BlogAPI', '/SOAP/', 0, 0, null, null, null, null, null, 'BLOG_API', null, 1,
      vector (
      'Namespace','http://www.openlinksw.com/weblog/api', 'SchemaNS', 'http://www.openlinksw.com/weblog/api',
      'MethodInSoapAction','only',
      'ServiceName', 'BlogAPI', 'elementFormDefault', 'qualified', 'Use', 'literal'
      ),
      null, null, 0)
  );
}
;

create method wa_vhost_options () for wa_blog2
{
  declare p_home any;
  whenever not found goto nfb;
  select BI_P_HOME into p_home from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = self.blogid;

  return
      vector
       (
	 p_home,        		-- physical home
	 'index.vspx',  		-- default page
	 'dba',         		-- user for execution
	 0,             		-- directory browsing enabled
	 1,				-- WebDAV repository
	 vector (),			-- virtual directory options
	 'BLOG.DBA.BLOG2_RSS2WML_PP',	-- post-processing function
	 null				-- pre-processing (authentication) function
       );

  nfb:
  return null;
};

create method wa_addition_instance_urls () for wa_blog2 {
  if (0)
    {
      -- disabled
      declare p_home any;
      whenever not found goto nfb;
      select BI_P_HOME into p_home from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = self.blogid;
      return vector (
        vector(null, null, '/tag/'||self.blogid, p_home || 'index.vspx', 1, 0, null, null, null, null,
          'dba', null, null, 1, null, null, vector ('noinherit', 'yes'), 0)
          );
      nfb:;
    }
  return null;
}
;

create procedure BLOG2_UPGRADE_FROM_BLOG ()
{
  -- collect all existing blog's ids and owner's ids
  declare _blogs any;

  if (registry_get ('__BLOG2_UPGRADE_FROM_BLOG1') = 'done')
    return 0;

  if (exists (select 1 from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'WEBLOG2'))
    {
      registry_set ('__BLOG2_UPGRADE_FROM_BLOG1', 'done');
      return 0;
    }
  _blogs := vector();
  for select BI_BLOG_ID, BI_OWNER from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID <> '*weblog-root*' do
    {
      _blogs := vector_concat(_blogs, vector(BI_BLOG_ID, BI_OWNER));
    }
  -- return if no previous version blogs exists
  if (length (_blogs) = 0)
    return 0;
  -- create new wa instances for each old blog
  declare _idx, _blog_id, _blog_owner, _blog_owner_name any;
  declare _inst wa_blog2;
  _idx := 0;
  while(_idx <= length(_blogs) - 2) {
    _blog_id := _blogs[_idx];
    _blog_owner := _blogs[_idx + 1];
    _idx := _idx + 2;
    -- create new class instance
    _inst := new wa_blog2();
    -- generate unique instance name
    _blog_owner_name := (select U_NAME from DB.DBA.SYS_USERS where U_ID = _blog_owner);
    _inst.wa_name := _blog_owner_name || '\'s Weblog [' || _blog_id || ']';
    -- Closed member model as default
    _inst.wa_member_model := 1;
    _inst.blogid := _blog_id;
    -- Final touch
    declare _id any;
    _id := _inst.wa_new_inst_from_old_blog(_blog_owner_name, _blog_id);
    update
      DB.DBA.WA_INSTANCE
    set
      WAI_IS_PUBLIC = 1,
      WAI_DESCRIPTION = _inst.wa_name
    where
      WAI_ID = _id;
  }
  -- delete old blog's home
  -- DB.DBA.VHOST_REMOVE(lpath=>'/blog');
  update BLOG.DBA.SYS_BLOG_INFO set BI_INCLUSION = 1;
  registry_set ('__BLOG2_UPGRADE_FROM_BLOG1', 'done');
  return _idx;
}
;


-- called via vad_install
create procedure BLOG2_UPGRADE_FROM_BLOG2 ()
{
  declare home, blog_home, exec_path, fpath, content, dav_pwd, ver any;

  -- XXX: change this when gems etc are changed
  ver := '1.10';

  if (registry_get ('__BLOG2_UPGRADE_FROM_BLOG2_ver') = ver)
    return;

  dav_pwd := (select pwd_magic_calc (U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = http_dav_uid ());

  for select BI_HOME, BI_P_HOME, BI_OWNER, BI_BLOG_ID, BI_OPTIONS from BLOG.DBA.SYS_BLOG_INFO
    where BI_BLOG_ID <> '*weblog-root*'
    do
      {
    home := subseq(BI_HOME, 0, length(BI_HOME) - 1);
    exec_path := BI_P_HOME;
    DAV_MAKE_DIR (exec_path, http_dav_uid(), http_dav_uid()+1, '110110100N');
    fpath := exec_path || 'index.vspx';
    content := (select RES_CONTENT from WS.WS.SYS_DAV_RES where RES_FULL_PATH = registry_get('_blog2_path_') || 'index.vspx');
    DB.DBA.DAV_RES_UPLOAD(fpath, content, 'text/html', '111101101N', 'dav', null, 'dav', dav_pwd);

    /* upgrade the gems with latest fixes */

    BLOG..BLOG2_UPGRADE_BLOG2_GEMS (BI_P_HOME, BI_BLOG_ID, dav_pwd, deserialize(blob_to_string (BI_OPTIONS)), BI_OWNER);

    /* the rest is upgrade from an alfa code of blog2 */
    if (registry_get ('__BLOG2_UPGRADE_FROM_BLOG2_ALFA_upgrade') = 'done')
      goto end_upg;


    DB.DBA.VHOST_REMOVE(lpath=>home);
    DB.DBA.VHOST_DEFINE(ses_vars=>1,
                 is_dav=>1,
                 lpath=>home,
                 ppath=>BI_P_HOME,
                 vsp_user=>'dba',
                 is_brws=>0,
                 def_page=>'index.vspx',
                 ppr_fn=>'BLOG.DBA.BLOG2_RSS2WML_PP'
                );

    -- some special VDs that not needed
    DB.DBA.VHOST_REMOVE(lpath=>home || '/gems');
    DB.DBA.VHOST_REMOVE(lpath=>home || '/images');
    DB.DBA.VHOST_REMOVE(lpath=>home || '/audio');
    DB.DBA.VHOST_REMOVE(lpath=>home || '/templates');

    -- the old home directory
    blog_home := subseq (BI_P_HOME, 0, length(BI_P_HOME) - 1) || '_exec/';
    for select HP_HOST, HP_LISTEN_HOST, HP_LPATH from DB.DBA.HTTP_PATH where
      HP_PPATH = blog_home and
      HP_HOST not like '%ini%'and HP_HOST not like '*sslini*'
    do
    {
      DB.DBA.VHOST_REMOVE(vhost=>HP_HOST, lhost=>HP_LISTEN_HOST, lpath=>HP_LPATH);
      DB.DBA.VHOST_DEFINE(vhost=>HP_HOST,
                   lhost=>HP_LISTEN_HOST,
                   ses_vars=>1,
                   is_dav=>1,
                   lpath=>HP_LPATH,
                   ppath=>BI_P_HOME,
                   vsp_user=>'dba',
                   is_brws=>0,
                   def_page=>'index.vspx',
                   ppr_fn=>'BLOG.DBA.BLOG2_RSS2WML_PP'
                  );
    }

    for select HP_HOST, HP_LISTEN_HOST, HP_LPATH from DB.DBA.HTTP_PATH where
      (HP_PPATH = BI_P_HOME || 'gems/' or
       HP_PPATH = BI_P_HOME || 'images/' or
       HP_PPATH = BI_P_HOME || 'audio/' or
       HP_PPATH = BI_P_HOME || 'templates/')
       and
       HP_HOST not like '%ini%'and HP_HOST not like '*sslini*'
      do
    {
      DB.DBA.VHOST_REMOVE(vhost=>HP_HOST, lhost=>HP_LISTEN_HOST, lpath=>HP_LPATH);
    }
      end_upg:;
  }
  registry_set ('__BLOG2_UPGRADE_FROM_BLOG2_ALFA_upgrade', 'done');
  registry_set ('__BLOG2_UPGRADE_FROM_BLOG2_ver', ver);
}
;

create procedure BLOG2_ATTACHED_ROOT(in path varchar) {
  declare root any;
  root := vector();
  for select
    BI_BLOG_ID
  from
    BLOG.DBA.SYS_BLOG_INFO,
    BLOG.DBA.SYS_BLOG_ATTACHES
  where
    BI_BLOG_ID = BA_C_BLOG_ID and
    BA_M_BLOG_ID = path
  do {
    if ((select WAI_IS_PUBLIC from DB.DBA.WA_INSTANCE
  where WAI_TYPE_NAME = 'WEBLOG2' and (WAI_INST as wa_blog2).blogid = BI_BLOG_ID) > 0)
      root := vector_concat(root, vector(BI_BLOG_ID));
  }
  return root;
}
;

create procedure BLOG2_ATTACHED_CHILD(in path varchar, in node any) {
  declare childs any;
  childs := vector();
  for select
    BI_BLOG_ID
  from
    BLOG.DBA.SYS_BLOG_INFO,
    BLOG.DBA.SYS_BLOG_ATTACHES
  where
    BI_BLOG_ID = BA_C_BLOG_ID and
    BA_M_BLOG_ID = node
  do {
    if ((select WAI_IS_PUBLIC from DB.DBA.WA_INSTANCE
  where WAI_TYPE_NAME = 'WEBLOG2' and (WAI_INST as wa_blog2).blogid = BI_BLOG_ID) > 0)
       childs := vector_concat(childs, vector(BI_BLOG_ID));
  }
  return childs;
}
;

create procedure BLOG2_INCLUDE_ROOT(in path varchar) {
  declare root any;
  root := vector();
  for select
    BI_BLOG_ID
  from
    BLOG.DBA.SYS_BLOG_INFO,
    BLOG.DBA.SYS_BLOG_ATTACHES
  where
    BI_BLOG_ID = BA_M_BLOG_ID and
    BA_C_BLOG_ID = path
  do
  {
    if ((select WAI_IS_PUBLIC from DB.DBA.WA_INSTANCE
  where WAI_TYPE_NAME = 'WEBLOG2' and (WAI_INST as wa_blog2).blogid = BI_BLOG_ID) > 0)
      root := vector_concat(root, vector(BI_BLOG_ID));
  }
  return root;
}
;

create procedure BLOG2_INCLUDE_CHILD(in path varchar, in node any) {
  declare childs any;
  childs := vector();
  for select
    BI_BLOG_ID
  from
    BLOG.DBA.SYS_BLOG_INFO,
    BLOG.DBA.SYS_BLOG_ATTACHES
  where
    BI_BLOG_ID = BA_M_BLOG_ID and
    BA_C_BLOG_ID = node
  do
  {
    if ((select WAI_IS_PUBLIC from DB.DBA.WA_INSTANCE
  where WAI_TYPE_NAME = 'WEBLOG2' and (WAI_INST as wa_blog2).blogid = BI_BLOG_ID) > 0)
    childs := vector_concat(childs, vector(BI_BLOG_ID));
  }
  return childs;
}
;

create procedure BLOG2_MOBLOG_PROCESS_PARTS (in parts any, inout body varchar, inout amime any, out result any, in any_part int) {
  declare name1, mime1, name, mime, enc, content, charset varchar;
  declare i, l, i1, l1, is_allowed int;
  declare part any;

  if (not isarray (result))
    result := vector ();

  if (not isarray (parts) or not isarray (parts[0]))
    return 0;
  -- test if there is an moblog compliant image
  part := parts[0];
--  dbg_obj_print ('part=', part);

  name1 := get_keyword_ucase ('filename', part, '');
  if (name1 = '')
    name1 := get_keyword_ucase ('name', part, '');

  mime1 := get_keyword_ucase ('Content-Type', part, '');
  charset := get_keyword_ucase ('charset', part, '');

  if (mime1 = 'application/octet-stream' and name1 <> '') {
    mime1 := http_mime_type (name1);
  }

  is_allowed := 0;
  i1 := 0;
  l1 := length (amime);
  while (i1 < l1) {
    declare elm any;
    elm := trim(amime[i1]);
    if (mime1 like elm) {
      is_allowed := 1;
      i1 := l1;
    }
    i1 := i1 + 1;
  }

  declare _cnt_disp any;
  _cnt_disp := get_keyword_ucase('Content-Disposition', part, '');

  if(is_allowed and (any_part or (name1 <> '' and _cnt_disp in ('attachment', 'inline')))) {
    name := name1;
    mime := mime1;
    enc := get_keyword_ucase ('Content-Transfer-Encoding', part, '');
    content := subseq (body, parts[1][0], parts[1][1]);
    if(enc = 'base64') content := decode_base64 (content);
    result := vector_concat (result, vector (vector (name, mime, content, _cnt_disp, enc, charset)));
    return 1;
  }
  -- process the parts
  if(not isarray (parts[2]))
    return 0;
  i := 0;
  l := length (parts[2]);
  while (i < l) {
    BLOG2_MOBLOG_PROCESS_PARTS (parts[2][i], body, amime, result, any_part);
    i := i + 1;
  }
  return 0;
}
;

create procedure BLOG2_MOBBLOGGING_GET_MOB_MESSAGE(in _msg any, in opts any) {
  declare parsed_message, amime, res any;
  declare rc integer;

  parsed_message := mime_tree (_msg);
  if (not isarray (opts)) return;
  amime := split_and_decode(get_keyword ('MoblogMIMETypes', opts, ''), 0, '\0\0,');
  if(amime is null or not isarray (amime) or length(amime) = 0) return null;

  res := null;
  BLOG2_MOBLOG_PROCESS_PARTS(parsed_message, _msg, amime, res, 0);
  return res;
}
;

create procedure BLOG2_UPLOAD_IMAGES_TO_BLOG_HOME(in _owner_id integer, in _blog_id varchar, in _image_body varchar, in _image_name varchar, out thumb_path varchar)
{
  declare _blog_home, _folder, _path, thumb any;
  declare mime_type varchar;

  thumb_path := null;

  _blog_home := (select BI_P_HOME from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = _blog_id);
  _folder := _blog_home || 'media/';
  DB.DBA.DAV_MAKE_DIR(_folder, _owner_id, http_dav_uid()+1, '110110100N');
  DB.DBA.DAV_MAKE_DIR(_folder||'thumbnail/', _owner_id, http_dav_uid()+1, '110110100N');
  _path := _folder || _image_name;
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT(_path, _image_body, '', '110100100N', _owner_id, null, null, null, 0);
  mime_type := http_mime_type (_image_name);
  if (__proc_exists ('IM ThumbnailImageBlob', 2) and mime_type like 'image/%')
    {
      declare path1 varchar;
      thumb := BLOG2_MAKE_THUMB (_image_body, mime_type, 200);
      path1 := _folder || 'thumbnail/' || _image_name;
      thumb_path := path1;
      DB.DBA.DAV_RES_UPLOAD_STRSES_INT(path1, thumb, '', '110100100N', _owner_id, null, null, null, 0);
    }
  return _path;
}
;

create procedure BLOG2_MAKE_THUMB (in _image_body any, in mime_type any, in width1 int, in flag int := 1)
{
  declare thumb any;
  thumb := null;
  if (__proc_exists ('IM ThumbnailImageBlob', 2) and mime_type like 'image/%')
    {
      declare width, height int;

      _image_body := blob_to_string (_image_body);

      width := "IM GetImageBlobWidth" (_image_body, length (_image_body));
      height := "IM GetImageBlobHeight" (_image_body, length (_image_body));

      if (width > width1)
	{
	  declare height1 int;
	  height1 := (width1 * height) / width;
	  thumb := "IM ThumbnailImageBlob" (_image_body, length (_image_body), width1, height1, 1);
        }
      else
	thumb := _image_body;
    }
  else if (flag)
    thumb := _image_body;
  return thumb;
}
;

create procedure BLOG_GET_MEDIA_URL (in _path varchar)
{
  declare _host, _intf, suff, chost varchar;
  declare _pos int;

  chost := BLOG.DBA.BLOG_GET_HOST ();
  _host := chost;
  _pos := strchr (_host, ':');

  if (_pos is not null)
    {
      _intf := subseq (_host, _pos, length (_host));
      _host := subseq (_host, 0, _pos);
    }
  else
    _intf := ':80';

  for select max (HP_LPATH) as lpath, max (HP_PPATH) as ppath
    from HTTP_PATH where HP_HOST = _host and HP_LISTEN_HOST like '%'||_intf and
	_path like HP_PPATH||'%' do
  {
    if (lpath is not null and ppath is not null)
      {
	suff := substring (_path, length (ppath), length (_path));
	return sprintf ('http://%s%s%s%s', _host, _intf, lpath, suff);
      }
  }
  return sprintf ('http://%s%s', chost, _path);
};


create procedure BLOG2_INSERT_MEDIA_MESSAGE (in _caller_name varchar, in _params any, in _blog_id varchar, in _path varchar, in _mime any, in thumb_path varchar, in _bi_owner int, in _bi_home varchar)
{
  -- determine next post_id number from sequence
  declare _post_id any;
  declare _content, _texts any;
  declare  iurl, turl varchar;

  _post_id := cast(sequence_next ('blogger.postid') as varchar);
  if (_post_id = '0')
    _post_id := cast (sequence_next ('blogger.postid') as varchar);

  -- create post object
  declare _res BLOG.DBA."MTWeblogPost";
  _res := new BLOG.DBA."MTWeblogPost" ();
  _res.postid := _post_id;
  _res.title := get_keyword('subj2', _params, '');
  _res.author := _caller_name;
  _res.userid := _res.author;
  _res.dateCreated := now ();
  _texts := get_keyword('description', _params, '');

  -- create message body
  iurl := BLOG_GET_MEDIA_URL (_path);
  if (thumb_path is not null)
    turl := BLOG_GET_MEDIA_URL (thumb_path);
  else
    turl := iurl;

  if(_mime like 'image/%') {
    _content := '<div><a href="' || iurl || '">' ||
                '<img src="' || turl ||
                '" width="200" border="0" /></a></div><div><pre>' ||
                get_keyword ('changed_name', _params, '') || ' </pre></div><div>' || _texts || '</div>';
  }
  else {
    _content := '<div><a href="' || iurl || '">' ||
                _res.title || '</a></div><div><pre>' ||
                get_keyword ('changed_name', _params, '') || ' </pre></div>';
  }
  insert into BLOG.DBA.SYS_BLOGS (B_APPKEY, B_BLOG_ID, B_CONTENT, B_POST_ID, B_USER_ID, B_TS, B_META, B_STATE, B_TITLE)
  values('', _blog_id, _content, _post_id, _bi_owner, now(), _res, 2, _res.title);
}
;

create procedure MOB_GET_BLOG_ID (in _msg any, in tag varchar := 'blogId')
{
  declare parsed_message, amime, res, tok any;
  declare rc integer;

  _msg := blob_to_string (_msg);
  parsed_message := mime_tree (_msg);
  res := null;
  MOB_PROCESS_PARTS (parsed_message, _msg, res);

  foreach (any elm in res) do
    {
      --dbg_obj_print_vars (elm);
      tok := regexp_match(sprintf ('@%s=[^@]+@', tag), elm);
      if (tok is not null)
  {
    goto extr;
  }
    }

  tok := regexp_match(sprintf ('@%s=[^@]+@', tag), _msg);
  extr:
  if (tok is not null)
    {
      tok := substring (tok, 9, length (tok));
      tok := rtrim (tok, '@');
    }

  return tok;
}
;

create procedure decode_uuencoded_attachement (in _data any, inout attaches any, inout opts any)
{
  declare data, outp, att any;
  declare line, nam, amime varchar;
  declare in_UU integer;

  if (not isarray (opts)) return;
  amime := split_and_decode(get_keyword ('MoblogMIMETypes', opts, ''), 0, '\0\0,');
  if(amime is null or not isarray (amime) or length(amime) = 0) return null;

  data := string_output (http_strses_memory_size ());
  http (_data, data);

  outp := string_output (http_strses_memory_size ());
  att := string_output (http_strses_memory_size ());

  if (attaches is null)
    attaches := vector ();

  in_UU := 0;
  while (1)
    {
      line := ses_read_line (data, 0);
      if (line is null or isstring (line) = 0)
  return;

      if (in_UU = 0 and subseq (line, 0, 6) = 'begin ' and length (line) > 6)
  {
          in_UU := 1;
    nam := split_and_decode (line, 0, '\0\0 ');
    if (length (nam) > 2)
      nam := nam[2];
    else
      nam := 'unknown';
    string_output_flush (att);
    http (line, att);
    http ('\r\n', att);
  }
      else if (in_UU = 1 and subseq (line, 0, 3) = 'end')
  {
    declare atta any;
          in_UU := 0;
    http (line, att);
    atta := uudecode (string_output_string (att), 1);
    foreach (any elm in amime) do
      {
        elm := trim(elm);
        if (http_mime_type (nam) like elm)
    {
            attaches := vector_concat (attaches, vector (vector (nam, http_mime_type (nam), atta)));
      goto donep;
    }
      }
    donep:;
  }
      else if (in_UU = 1)
  {
    http (line, att);
    http ('\r\n', att);
  }
      else if (in_UU = 0)
  {
    http (line, outp);
    http ('\n', outp);
  }
    }
  return;
}
;

create procedure MOB_PROCESS_PARTS (in parts any, inout body varchar, out result any)
{
  declare name1, mime1, name, mime, enc, content varchar;
  declare i, l, i1, l1, is_allowed int;
  declare part any;

  if (not isarray (result))
    result := vector ();

  if (not isarray (parts) or not isarray (parts[0]))
    return 0;
  -- test if there is an moblog compliant image
  part := parts[0];

  mime1 := get_keyword_ucase ('Content-Type', part, '');

  declare _cnt_disp any;
  _cnt_disp := get_keyword_ucase('Content-Disposition', part, 'inline');

  if (mime1 like 'text/%' and _cnt_disp = 'inline' and parts[1][0] < parts[1][1])
    {
      mime := mime1;
      enc := get_keyword_ucase ('Content-Transfer-Encoding', part, '');
      content := subseq (body, parts[1][0], parts[1][1]);

      if (enc = 'base64')
  content := decode_base64 (content);
      else if (enc = 'quoted-printable')
        content := uudecode (content, 12);
      result := vector_concat (result, vector (content));
      --return 1;
    }

  -- process the parts
  if(not isarray (parts[2]))
    return 0;

  i := 0;
  l := length (parts[2]);
  while (i < l)
    {
      MOB_PROCESS_PARTS (parts[2][i], body, result);
      i := i + 1;
    }
  return 0;
}
;

create procedure DB.DBA.BLOG2_MOBLOG_PROCESS_MSG(in _caller_user_name varchar, in _ma_m_id int,
             in _ma_m_fld varchar, in _msg_body any, in is_mb any) {

  -- return if message was already processed
  if(is_mb is not null and length(is_mb) > 0) {
    return;
  }

  -- determine caller user id
  declare _caller_user_id, _state, _special_mail any;
  declare _post_id any;
  declare _blog_id1, _blog_id, _mbody any;
  declare _opts, _bi_home, _bi_owner, _u_name any;
  declare cr cursor for select BI_OPTIONS, BI_HOME, BI_OWNER, U_NAME, BI_BLOG_ID
      from BLOG.DBA.SYS_BLOG_INFO, DB.DBA.SYS_USERS
      where  (_blog_id1 is not null and BI_BLOG_ID = _blog_id1 and BI_OWNER = U_ID) or
      (_blog_id1 is null and BI_OWNER = U_ID and U_ID = _caller_user_id);

  _mbody := blob_to_string (_msg_body);
  _blog_id := null;
  _post_id := null;

  -- first case is to have special moblog account
  if (regexp_match ('^[A-Za-z0-9 _@\.]+-blog-[0-9]+\$', _caller_user_name) is not null)
    {
      _special_mail := 1;
      _blog_id1 := _caller_user_name;
      _caller_user_id := null;
    }
  else
    {
      _special_mail := 0;
      _caller_user_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = _caller_user_name);
      if (_caller_user_id is null)
      return;

      -- detect blogId from message body
      _blog_id1 := MOB_GET_BLOG_ID (_msg_body);
    }

  -- detect postId from message body
  _post_id := MOB_GET_BLOG_ID (_msg_body, 'postId');

  -- if no blogId founded - do nothing
  if (_post_id is not null and _blog_id1 is null) return;


  whenever not found goto set_and_exit;
  open cr (prefetch 1);

  while (1)
    {
      -- determine options and other parameters for called blog
      fetch cr into _opts, _bi_home, _bi_owner, _u_name, _blog_id;
      _opts := deserialize (blob_to_string(_opts));

      if (_special_mail)
        _caller_user_id := _bi_owner;

      -- determine caller's membership for the blog instance
      whenever not found goto nf;
      declare _role, _status any;
      select min(WAM_MEMBER_TYPE), min(WAM_STATUS)
      into _role, _status
      from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE
      where WAM_STATUS <= 2 and WAI_TYPE_NAME = 'WEBLOG2' and WAM_USER = _caller_user_id and
      (WAI_INST as wa_blog2).blogid = _blog_id and WAM_INST = WAI_NAME and
      (WAM_MEMBER_SINCE < now() or WAM_MEMBER_SINCE is null) and ( WAM_EXPIRES > now() or WAM_EXPIRES is null);

      if (_status = 1)
        _role := 1;
    nf:
      -- if caller is not blog owner or blog author do nothing
      if (_role is null or _role not in (1,2))
        return;

      -- blog processing starts

    blog_processing:

      -- if _post_id is determined - create new comment to message
      if(_post_id is not null)
        goto new_comment;
      -- else - new message creation (one message for each attachment)

    new_message:

      -- retrieve attachments with allowed mime types from mail
      declare _attaches, res, parsed_message, texts any;
      _attaches := BLOG2_MOBBLOGGING_GET_MOB_MESSAGE(_mbody, _opts);
      decode_uuencoded_attachement (_mbody, _attaches, _opts);

      parsed_message := mime_tree (_mbody);
      res := null;
      MOB_PROCESS_PARTS (parsed_message, _mbody, res);
      
      texts := '';
      foreach (any elm in res) do
	{
	  texts := texts || elm;
	}

      -- if attaches was not founded - skip next block
      if(_attaches is null or not isarray(_attaches) or length(_attaches) = 0) goto _endmark;

      -- if attaches with allowed mime type founded, place it into MAIL_ATTACHMENTS
      declare _i, _l, _subject, _media_path any;
      declare _a_name, _a_mime, _a_content, _publ, secret any;
      _i := 0;
      _l := length(_attaches);
      _subject := substring(mail_header(_mbody, 'Subject'), 1, 512);
      _subject := BLOG.DBA.BLOG2_DECODE_SUBJECT (_subject);
      _state := null;

      if (get_keyword('MoblogAutoPublish', _opts, 0) = 1)
	_state := 'mob-pub';
      else
	_state := 'mob-new';

      while (_i < _l)
	{
	  _a_name := _attaches[_i][0];
	  _a_mime := _attaches[_i][1];
	  _a_content := _attaches[_i][2];
--	  dbg_obj_print_vars (_a_name, _a_mime, _a_content);
	  _publ := 0;
	  if (_state = 'mob-pub')
	    {
	        -- if auto creation of blog is allowed (even if this mail contains comment to some post_id)
		-- place attached resources in corresponded blog physical home and create new blog
		secret := get_keyword ('MoblogAutoSecret', _opts, '');
		if (length (secret) = 0 or regexp_match ('([[:space:]]|^)'||secret||'([[:space:]]|\$)', subseq (_mbody, 0, 10000))
		    is not null)
		  {
		    -- matching secret
	            declare thumb_path varchar;
		    _media_path := BLOG2_UPLOAD_IMAGES_TO_BLOG_HOME(_caller_user_id, _blog_id, _a_content, _a_name, thumb_path);
		    BLOG2_INSERT_MEDIA_MESSAGE (_u_name, vector('subj2', _subject, 'description', texts), _blog_id, _media_path, _a_mime, thumb_path,
			_bi_owner, _bi_home);
		    _publ := 1;
		  }
	    }
	  insert soft DB.DBA.MAIL_ATTACHMENT (MA_M_ID, MA_M_OWN, MA_M_FLD, MA_NAME, MA_MIME, MA_CONTENT, MA_PUBLISHED, MA_BLOG_ID)
	      values (_ma_m_id, _caller_user_name, _ma_m_fld, _a_name, _a_mime, _a_content, _publ, _blog_id);
	  _i := _i + 1;
	}

    goto _endmark;
      -- new comment for message creation
    new_comment:

      declare _mime_tree, _content_type any;
      _mime_tree := mime_tree (_mbody);
      _content_type := substring (mail_header(_mbody, 'Content-Type'), 1, 512);
      if (isarray(_mime_tree[1]))
	{
	  declare _mm_body, _mm_mail_id, _mm_from, _mm_subject varchar;
	  _mm_body := subseq(_mbody, _mime_tree[1][0], _mime_tree[1][1]);
	  if (exists(select 1 from BLOG.DBA.SYS_BLOGS where B_STATE = 2 and B_POST_ID = _post_id and B_BLOG_ID = _blog_id))
	    {
	      _mm_from := substring(mail_header(_mbody, 'From'), 1, 512);
	      _mm_subject := substring(mail_header(_mbody, 'Subject'), 1, 512);
	      _mm_subject := BLOG.DBA.BLOG2_DECODE_SUBJECT (_mm_subject);
	      --_mm_body := replace(_mm_body, _blog_token, '');
	      --_mm_body := replace(_mm_body, _post_token, '');
	      if (_content_type <> 'text/html') _mm_body := '<pre>' || _mm_body || '</pre>';
	      insert into BLOG.DBA.BLOG_COMMENTS (
		  BM_BLOG_ID, BM_POST_ID, BM_COMMENT, BM_NAME, BM_E_MAIL, BM_HOME_PAGE, BM_ADDRESS, BM_TS)
		  values( _blog_id, _post_id, _mm_body, _mm_subject, _mm_from, '', '127.0.0.1', now());
	    }
	}
     _endmark:;
    }
  set_and_exit:
  close cr;
  set triggers off;
  update MAIL_MESSAGE set MM_MOBLOG = _state where MM_OWN = _caller_user_name and MM_ID = _ma_m_id;
  set triggers on;
  return;
}
;

create procedure BLOG.DBA.BLOG2_DECODE_SUBJECT (in subject varchar)
{
  declare sub any;
  if (subject like '=?UTF-8?B?%?=')
    {
      sub := substring (subject, 11, length (subject) - 12);
      sub := decode_base64 (sub);
      return sub;
    }
  else
    return subject;
};

create procedure
BLOG.DBA.BLOG2_UPDATE_SYS_BLOG_INFO ()
{
  if (registry_get ('__BLOG2_UPDATE_SYS_BLOG_INFO') = 'done')
    return;

  if (exists (select 1 from BLOG.DBA.SYS_BLOG_INFO where BI_WAI_MEMBER_MODEL is NULL))
    {
      for (select WAI_NAME, WAI_MEMBER_MODEL, (WAI_INST as wa_blog2).blogid as temp_id
        from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'WEBLOG2') do
   {
      update BLOG.DBA.SYS_BLOG_INFO set BI_WAI_NAME = WAI_NAME,
        BI_WAI_MEMBER_MODEL = WAI_MEMBER_MODEL where BI_BLOG_ID = temp_id;
   }
    }

  update BLOG.DBA.SYS_BLOG_INFO set BI_HAVE_COMUNITY_BLOG = 0 where BI_HAVE_COMUNITY_BLOG is NULL;
  registry_set ('__BLOG2_UPDATE_SYS_BLOG_INFO', 'done');
}
;

BLOG.DBA.BLOG2_UPDATE_SYS_BLOG_INFO ()
;


create trigger SYS_USERS_BLOG_INFO_UP after update (U_E_MAIL) on DB.DBA.SYS_USERS referencing old as O, new as N
{
  set triggers off;
  update BLOG..SYS_BLOG_INFO set BI_E_MAIL = N.U_E_MAIL where BI_OWNER = N.U_ID;
  set triggers on;
};


create trigger BI_WAI_MEMBER_MODEL_UPD after update on DB.DBA.WA_INSTANCE referencing old as O, new as N
{
  declare inst wa_blog2;
  declare blogid any;

  if (udt_instance_of (O.WAI_INST, 'DB.DBA.wa_blog2'))
    {
      inst := N.WAI_INST;
      blogid := inst.blogid;

      update BLOG.DBA.SYS_BLOG_INFO set BI_WAI_NAME = N.WAI_NAME, BI_WAI_MEMBER_MODEL = N.WAI_MEMBER_MODEL
	where BI_BLOG_ID = blogid;
    }
}
;

-- XXX: put a check
-- called via vad_install
create procedure
BLOG2_UPDATE_SYS_BLOG_INFO_DEL ()
{
  if (registry_get ('__BLOG2_UPDATE_SYS_BLOG_INFO_DEL_done') = 'done')
    return;
  if (exists (select 1 from BLOG.DBA.SYS_BLOG_INFO where BI_WAI_MEMBER_MODEL is NULL))
    {
      for (select WAI_NAME, WAI_MEMBER_MODEL, (WAI_INST as DB.DBA.wa_blog2).blogid as temp_id
	  from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'WEBLOG2') do
	{
	  update BLOG.DBA.SYS_BLOG_INFO set BI_WAI_NAME = WAI_NAME,
		 BI_WAI_MEMBER_MODEL = WAI_MEMBER_MODEL where BI_BLOG_ID = temp_id;
	}
    }

  if (exists (select 1 from BLOG.DBA.SYS_BLOG_INFO where BI_HAVE_COMUNITY_BLOG is NULL))
    {
      for (select (WAI_INST as DB.DBA.wa_blog2).blogid as temp_id from DB.DBA.WA_INSTANCE
	  where WAI_TYPE_NAME = 'WEBLOG2') do
	{
	  update BLOG.DBA.SYS_BLOG_INFO set BI_HAVE_COMUNITY_BLOG = 0 where BI_BLOG_ID = temp_id and BI_HAVE_COMUNITY_BLOG is NULL;
	}
    }
  set triggers off;
  update BLOG..BLOG_COMMENTS set BM_IS_PUB = 1, BM_IS_SPAM = 0 where BM_IS_PUB is null;
  set triggers on;
  registry_set ('__BLOG2_UPDATE_SYS_BLOG_INFO_DEL_done', 'done');
}
;


USE "DB"
;

create procedure BLOG_DAV_CHECK (in rc int)
{
  declare msg any;
  if (rc >= 0)
    return;
  msg := DAV_PERROR (rc);
  signal ('42000', msg);
};

create procedure BLOG_MAKE_ALL_BLOGS_IN_ONE ()
{
  declare _inst wa_blog2;
  declare hosts, chome, default_community, ndone any;

  ndone := BLOG2_UPGRADE_FROM_BLOG();

  -- One initial blog is needed, the test suite otherwise will fail
  --if (ndone = 0)
  --  return;

  _inst := new wa_blog2();
  _inst.wa_name := 'Community blog';
  _inst.wa_member_model := 0;

  if (exists (select 1 from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = 'dav-blog-1'))
    return;

  if (exists (select 1 from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = 'dav-blog-0'))
    return;

  if (registry_get ('__BLOG_MAKE_ALL_BLOGS_IN_ONE') = 'done')
    return;

  DAV_MAKE_DIR ('/DAV/home/dav/', http_dav_uid (), null, '110100100R');
  _inst.wa_new_inst('dav');

  hosts := vector ();
  for select distinct HP_HOST, HP_LISTEN_HOST, HP_LPATH
    from DB.DBA.HTTP_PATH where HP_PPATH = '/DAV/' and HP_LPATH in ('/', '/blog') and
    HP_STORE_AS_DAV  = 1 and (HP_DEFAULT = 'index.vspx' or HP_DEFAULT like 'index.vspx;%') do
      {
        hosts := vector_concat (hosts, vector (vector (HP_HOST, HP_LISTEN_HOST, HP_LPATH)));
      }

  default_community := 0;
  if (length (hosts))
    {
      whenever not found goto nfdf;
      declare exit handler for sqlstate '*' {
	goto nfdf;
      };
      select blob_to_string (RES_CONTENT) into chome from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/index.vspx';
      chome := xtree_doc (chome);
      if (xpath_eval ('/page[@name="blog-home-page"]', chome) is not null)
	default_community := 1;
      nfdf:;
    }

  if (default_community)
    {
      foreach (any vd in hosts) do
	 {
	   DB.DBA.VHOST_REMOVE (vd[0], vd[1], vd[2]);
	   blog_ensure_domain (_inst, vd[0], vd[1]);
	   DB.DBA.VHOST_DEFINE(
	              vhost=>vd[0],
		      lhost=>vd[1],
	              ses_vars=>1,
	              is_dav=>1,
	              lpath=>vd[2],
	              ppath=>'/DAV/home/dav/dav-blog-1/',
	              vsp_user=>'dba',
	              is_brws=>0,
	              def_page=>'index.vspx',
	              ppr_fn=>'BLOG.DBA.BLOG2_RSS2WML_PP'
	             );
	 }
    }

  --DB.DBA.DAV_DELETE_INT ('/DAV/index.vspx', 0, null, null, 0);

  if (exists (select 1 from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID = 'dav-blog-1'))
    {
      update BLOG.DBA.SYS_BLOG_INFO set BI_HAVE_COMUNITY_BLOG = 1 where BI_BLOG_ID = 'dav-blog-1';

      for (select BI_HOME, BI_BLOG_ID from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID <> 'dav-blog-1') do
	BLOG..BLOG2_BLOG_ATTACH ('dav-blog-1', BI_BLOG_ID);
    }
  registry_set ('__BLOG_MAKE_ALL_BLOGS_IN_ONE', 'done');
}
;

create trigger WA_USER_INFO_GEO_U after update (WAUI_LAT) on WA_USER_INFO referencing new as N
{
  for select BI_WAI_NAME from BLOG.DBA.SYS_BLOG_INFO where BI_OWNER = N.WAUI_U_ID do
    {
      ODS..APP_PING (BI_WAI_NAME, null, null, 'GeoURL');
    }
  return;
};

BLOG..blog2_exec_no_error ('DB.DBA.BLOG_MAKE_ALL_BLOGS_IN_ONE ()')
;


create procedure wa_collect_blog_tags (in id int)
{
   for (select BT_TAGS from BLOG..BLOG_TAG) do
	wa_add_tag_to_count (BT_TAGS, id);
}
;

create procedure collect_blog_rel_tags ()
{
  declare tags any;

  for (select BT_TAGS from BLOG..BLOG_TAG) do
     {
	tags := split_and_decode (BT_TAGS, 0, '\0\0,');
	add_tag_to_rel_count (__vector_sort (tags));
     }

  return;
}
;
