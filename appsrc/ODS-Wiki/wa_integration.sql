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
-- create new wikiv application in WA

wa_exec_no_error_log (
 'create type wa_wikiv under web_app as (
    cluster_id integer,
	  owner  int
	)
  constructor method wa_wikiv(stream any),
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
  overriding method wa_dashboard_last_item () returns any,
  overriding method wa_https_supported () returns int')
;

wa_exec_no_error(
  'alter type wa_wikiv add overriding method wa_front_page_as_user(inout stream any, in user_name varchar) returns any'
)
;

wa_exec_no_error(
  'alter type wa_wikiv add method app_id () returns any'
)
;

wa_exec_no_error(
  'alter type wa_wikiv add overriding method wa_addition_urls () returns any'
)
;

 wa_exec_no_error(
  'alter type wa_wikiv add overriding method wa_dashboard_last_item () returns any'
)
;

wa_exec_no_error(
  'alter type wa_wikiv add overriding method wa_vhost_options () returns any'
)
;

wa_exec_no_error(
  'alter type wa_wikiv add overriding method wa_dashboard_last_item  () returns any'
)
;

wa_exec_no_error(
  'alter type wa_wikiv add overriding method wa_addition_instance_urls (in _lpath varchar) returns any'
)
;

wa_exec_no_error(
  'alter type wa_wikiv add overriding method wa_rdf_url (in vhost varchar, in lhost varchar) returns varchar'
)
;
wa_exec_no_error(
  'alter type wa_wikiv add overriding method wa_post_url (in vhost varchar, in lhost varchar, in inst_name varchar, in post any) returns varchar'
)
;

wa_exec_no_error(
  'alter type wa_wikiv add overriding method wa_update_instance (in oldValues any, in newValues any) returns any'
)
;


insert soft WA_TYPES(WAT_NAME, WAT_DESCRIPTION, WAT_TYPE, WAT_REALM) values ('oWiki', 'oWiki', 'db.dba.wa_wikiv', 'wikiv')
;

insert replacing WA_MEMBER_TYPE (WMT_APP, WMT_NAME, WMT_ID, WMT_IS_DEFAULT) values ('oWiki', 'author', 2, 0)
;

insert replacing WA_MEMBER_TYPE (WMT_APP, WMT_NAME, WMT_ID, WMT_IS_DEFAULT) values ('oWiki', 'reader', 3, 1)
;

delete from DB.DBA.WA_MEMBER_TYPE where WMT_ID < 2
;

create method wa_id_string () for wa_wikiv {
  return 'wikiv_' || self.cluster_id || '_' || cast (self.owner as varchar);
}
;

create constructor method wa_wikiv (inout stream any) for wa_wikiv {
  ;
}
;

create method wa_member_data (in u_id int, inout stream any) for wa_wikiv {
  return 'N/A';
}
;

create method wa_member_data_edit_form (in u_id int, inout stream any) for wa_wikiv {
  return;
}
;

create method wa_state_edit_form (inout stream any) for wa_wikiv {
  declare _home varchar;
  _home := sprintf('http://%s/wiki/resources/', sioc..get_cname());

  declare  sid varchar;
  sid := connection_get ('wa_sid');
  http_request_status ('HTTP/1.1 302 Found');
  http_header(sprintf('Location: %s/settings.vspx?sid=%s&realm=wa&cluster=%s\r\n', _home, sid, WV.WIKI.GETCLUSTERNAME (self.cluster_id)));
  return;
}
;

create method wa_drop_instance () for wa_wikiv {
  WV.WIKI.DROPCLUSTERUPSTREAM (self.cluster_id);
  WV.WIKI.DROPCLUSTERCONTENT (self.cluster_id);
  WV.WIKI.DELETECLUSTER (self.cluster_id);
  delete from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'oWiki' and (WAI_INST as wa_wikiv).cluster_id = self.cluster_id;
}
;

create method wa_join_request (in login varchar) for wa_wikiv {
   --dbg_obj_print ('login=' , login);
  declare _full_name varchar;
  _full_name := coalesce((select U_FULL_NAME from SYS_USERS where U_NAME = login), login);
  WV.WIKI.CREATEUSER(login, _full_name, 'WikiUser', '', 1);
  return;
}
;

create method wa_join_approve (in login varchar) for wa_wikiv {
   --dbg_obj_print ('login2=' , login);
  return;
}
;

create method wa_new_inst (in login varchar) for wa_wikiv {
  declare exit handler for sqlstate '*' {
  	  -- dbg_obj_print (__SQL_STATE, __SQL_MESSAGE);
  	  resignal;
  };
  declare exit handler for not found {
  	  -- dbg_obj_print ('nf');
  	  resignal;
  };
  declare _home varchar;
  _home := connection_get ('wiki_home');
  --dbg_obj_print ('home: ', self);
  declare _full_name varchar;
  _full_name := coalesce((select U_FULL_NAME from SYS_USERS where U_NAME = login), login);

  -- determine group id
  declare _group_id any;
  _group_id := (select U_ID from SYS_USERS where U_NAME = 'WikiUser');

  -- determine user id
  declare _owner_id any;
  _owner_id := (select U_ID from SYS_USERS where U_NAME = login);

  -- add user into WikiUser group if he still is not a member
  if(not exists (select 1 from SYS_ROLE_GRANTS where GI_SUPER = _owner_id and GI_GRANT = _group_id))
  {
    DB.DBA.USER_GRANT_ROLE(login, 'WikiUser', 1);
  }

  if (not exists (select 1 from WV.WIKI.USERS, DB.DBA.SYS_USERS where UserId = U_ID and U_NAME = login))
  {
	WV.WIKI.CREATEUSER(login, _full_name, 'WikiUser', '', 1);
  }
  
  -- calculate new cluster name
  declare _cluster_name varchar;

  if (exists (select * from WV.WIKI.CLUSTERS where ClusterName = self.wa_name))
    signal ('WIKI02', 'Cluster "' || self.wa_name || '" exists already');
  _cluster_name := self.wa_name;
  
  if (self.wa_member_model is null)
  {
    self.wa_member_model := 0;
  }
  connection_set ('WikiMemberModel', self.wa_member_model);

  -- create new cluster
  WV.WIKI.CREATECLUSTER(_cluster_name, 0, _owner_id, _group_id);

  declare _col_id int;
  -- determine cluster id;
  select Clusterid, ColId into self.cluster_id, _col_id from WV.WIKI.CLUSTERS where ClusterName = _cluster_name;

  -- determine instance name
  declare inst_name varchar;
  if (self.wa_name is null)
  {
    inst_name := sprintf ('Wiki_%s' , _cluster_name);
    self.wa_name := inst_name;
  } else {
    inst_name := self.wa_name;
  }

  -- uploading new initial content
  WV.WIKI.CREATEINITIALPAGE ('WelcomeVisitors.txt', _col_id, _owner_id, 'Template');
  
  -- finishing
  declare _wai_id any;
  self.owner := _owner_id;
  insert into DB.DBA.WA_INSTANCE (WAI_NAME, WAI_TYPE_NAME, WAI_INST, WAI_DESCRIPTION)
  	values (inst_name, 'oWiki', self, '');
--  insert into WA_MEMBER (WAM_USER, WAM_INST, WAM_MEMBER_TYPE) values (_owner_id, inst_name, 1);
--  _wai_id := (select WAI_ID from WA_INSTANCE where WAI_NAME = inst_name);

  if (_home is not null)
    {
    declare _base varchar;

      _base := registry_get('WIKI BASE');
    if (not isstring (_base))
    {
      _base := _home ;
    }
      WV.WIKI.SETCLUSTERPARAM (_cluster_name, 'home', _base);
    }
  declare is_public any;
  is_public := (select WAI_IS_PUBLIC from WA_INSTANCE where WAI_NAME = inst_name);
  if ((is_public >= 1) and 
      (not exists (select 1 from  SYS_ROLE_GRANTS, SYS_USERS g, SYS_USERS l
                    where g.U_NAME = inst_name || 'Readers'
							        and l.U_NAME = 'WikiGuest'
							        and gi_super = l.U_ID
							        and gi_grant = g.u_id)))
  {
	  DB.DBA.USER_GRANT_ROLE ('WikiGuest', inst_name || 'Readers');
  }
  if ((is_public < 1) and 
      (exists (select 1 from  SYS_ROLE_GRANTS, SYS_USERS g, SYS_USERS l
                where g.U_NAME = inst_name || 'Readers'
					        and l.U_NAME = 'WikiGuest'
					        and gi_super = l.U_ID
					        and gi_grant = g.u_id)))
  {
    DB.DBA.USER_REVOKE_ROLE ('WikiGuest', inst_name || 'Readers');
  }
  
  declare _id int;
  _id := (self as web_app).wa_new_inst(login);

  --  SIOC service
  declare  graph_iri, iri, w_iri varchar;
  graph_iri := SIOC..get_graph ();
  iri := sprintf ('http://%s/dataspace/doc/%s/wiki/%s/atom-pub/', SIOC..get_cname(), login, inst_name);
  w_iri := SIOC..wiki_iri (inst_name);
  SIOC..ods_sioc_service (graph_iri, iri, w_iri, null, null, null, iri, 'Atom');

  return _id;
}
;


create method wa_membership_edit_form (inout stream any) for wa_wikiv
{
  return;
}
;

create method wa_front_page (inout stream any) for wa_wikiv
{
  declare sid varchar;  
  sid := connection_get ('wa_sid');

  if (connection_get('vspx_user') is null)
  {
	  http_request_status ('HTTP/1.1 302 Found');
	  http_header (sprintf('Location: %s\r\n', self.wa_home_url()));
  } else {
	  http_request_status ('HTTP/1.1 302 Found');
	  http_header (sprintf('Location: %s?sid=%s&realm=wa\r\n', self.wa_home_url(), sid));
  }
}
;

create method wa_state_posted (in post any, inout stream any) for wa_wikiv
{
  declare login varchar;
  login := connection_get ('vspx_user');
  if (get_keyword ('save_new', post) is not null) {
    return self.wa_new_inst (login);
  }
  if (get_keyword ('join_request', post) is not null) {
    return self.wa_join_request (login);
  }
}
;

create method wa_home_url () for wa_wikiv
{
 declare _home, _cluster varchar;

 _home := WV.WIKI.CLUSTERPARAM (self.cluster_id, 'home');
 _cluster := (select ClusterName from WV.WIKI.CLUSTERS where ClusterId = self.cluster_id);
 if (_home is null)
  {
    _home := (select DP_PATTERN from WV.WIKI.DOMAIN_PATTERN_1 where DP_HOST = '%' and DP_CLUSTER = self.cluster_id);
    if (_home is null)
    {
      if (exists (select 1 from WV.WIKI.DOMAIN_PATTERN_1 where DP_HOST = '%' and DP_PATTERN = '/wiki/main'))
        return sprintf('http://%s/wiki/main/%U', sioc..get_cname(), _cluster);
      return sprintf('http://%s/wiki/%U/', sioc..get_cname(), _cluster);
    }
  }
 return _home || '/' ||  WV.WIKI.READONLYWIKIWORDLINK (_cluster, '');
}
;

create method wa_private_url () for wa_wikiv
{
  return self.wa_home_url();
}
;

create method wa_periodic_activity () for wa_wikiv
{
  return;
}
;

create method wa_class_details () for wa_wikiv
{
  declare info varchar;
	info := 'The Virtuoso Wiki Application allows you to run an wiki system.';
	return info;
}
;

create method wa_https_supported () for wa_wikiv
{
	return 0;
}
;

create trigger WIKI_WA_MEMBERSHIP after update  on DB.DBA.WA_MEMBER order 100 referencing new as N, old as O
{
  if (N.WAM_APP_TYPE <> 'oWiki')
    return;
  declare _cluster_id integer;
  _cluster_id := (select (wai_inst as wa_wikiv).cluster_id from DB.DBA.WA_INSTANCE where WAI_NAME = N.WAM_INST and WAI_TYPE_NAME = 'oWiki');
  if (_cluster_id is null)
    return;
  declare _user varchar;
  if (not exists (select 1 from WV.WIKI.USERS where UserId = N.WAM_USER))
    {
      declare _group_id any;
      _group_id := (select U_ID from SYS_USERS where U_NAME = 'WikiUser');

      declare _full_name varchar;
    select coalesce (U_FULL_NAME, U_NAME), U_NAME into _full_name, _user
	from DB.DBA.SYS_USERS where U_ID = N.WAM_USER;
      if(not exists (select 1 from SYS_ROLE_GRANTS where GI_SUPER = N.WAM_USER and GI_GRANT = _group_id)) {
	DB.DBA.USER_GRANT_ROLE(_user, 'WikiUser', 1);
      }
      WV.WIKI.CREATEUSER(_user, _full_name, 'WikiUser', '', 1);
    }
  else
    _user := (select U_NAME from DB.DBA.SYS_USERS where U_ID = N.WAM_USER);
  declare _cluster_name varchar;
  _cluster_name := (select ClusterName from WV.WIKI.CLUSTERS where ClusterId = _cluster_id);
  if (_cluster_name is null)
    return;
  declare _role, _role_revoke varchar;
  if (N.WAM_MEMBER_TYPE in (1,2) and N.WAM_STATUS <= 2) -- author
  {
    _role := _cluster_name || 'Writers';
    _role_revoke := _cluster_name || 'Readers';
  }
  else if (N.WAM_MEMBER_TYPE = 3 and N.WAM_STATUS = 2) -- reader
  {
    _role := _cluster_name || 'Readers';
    _role_revoke := _cluster_name || 'Writers';
  }
  else
    signal ('WK001', 'Such membership is not supported ' || cast (N.WAM_MEMBER_TYPE as varchar));
  if (not exists (select 1 from  SYS_ROLE_GRANTS, SYS_USERS g 
	where g.U_NAME = _role and gi_super = N.WAM_USER and gi_grant = g.u_id))
  {
    DB.DBA.USER_GRANT_ROLE (_user, _role);
}
  if (exists (select 1 from  SYS_ROLE_GRANTS, SYS_USERS g
                   where g.U_NAME = _role_revoke and gi_super = N.WAM_USER and gi_grant = g.u_id))
  {
    DB.DBA.USER_REVOKE_ROLE (_user, _role_revoke);
  }
  if (N.WAM_INST <> O.WAM_INST)
  {
    update DB.DBA.WA_MEMBER set WAM_HOME_PAGE = replace	(N.WAM_HOME_PAGE, O.WAM_INST, N.WAM_INST) where WAM_INST = N.WAM_INST;
  }
}
;
  
create trigger WIKI_WA_MEMBERSHIP_OPEN after insert on DB.DBA.WA_MEMBER order 100 referencing new as N
{
  --dbg_obj_princ ('WIKI_WA_MEMBERSHIP_OPEN: ', N.WAM_STATUS);
  if (N.WAM_APP_TYPE <> 'oWiki')
    return;
  if (N.WAM_STATUS <> 2)
    return;
   declare _cluster_id integer;
  _cluster_id := (select (wai_inst as wa_wikiv).cluster_id from DB.DBA.WA_INSTANCE where WAI_NAME = N.WAM_INST and WAI_TYPE_NAME = 'oWiki');
  if (_cluster_id is null)
    return;
  --dbg_obj_princ ('WIKI_WA_MEMBERSHIP_OPEN: cl', _cluster_id);
  declare _user varchar;
  if (not exists (select * from WV.WIKI.USERS where UserId = N.WAM_USER))
    {
      declare _group_id any;
      _group_id := (select U_ID from SYS_USERS where U_NAME = 'WikiUser');

      declare _full_name varchar;
      select coalesce (U_FULL_NAME, U_NAME), U_NAME into
	_full_name, _user
	from DB.DBA.SYS_USERS where U_ID = N.WAM_USER;
      if(not exists (select 1 from SYS_ROLE_GRANTS where GI_SUPER = N.WAM_USER and GI_GRANT = _group_id)) {
	DB.DBA.USER_GRANT_ROLE(_user, 'WikiUser', 1);
      }
      --dbg_obj_princ ('Create user ', _full_name);
      WV.WIKI.CREATEUSER(_user, _full_name, 'WikiUser', '', 1);
    }
  else
    _user := (select U_NAME from DB.DBA.SYS_USERS where U_ID = N.WAM_USER);
  declare _cluster_name varchar;
  _cluster_name := (select ClusterName from WV.WIKI.CLUSTERS where ClusterId = _cluster_id);

  declare _role, _role_revoke varchar;
  if (N.WAM_MEMBER_TYPE in (1,2) and N.WAM_STATUS <= 2) -- author
  {
    _role := _cluster_name || 'Writers';
    _role_revoke := _cluster_name || 'Readers';
  }
  else if (N.WAM_MEMBER_TYPE = 3 and N.WAM_STATUS = 2) -- reader
  {
    _role := _cluster_name || 'Readers';
    _role_revoke := _cluster_name || 'Writers';
  }
  else
    signal ('WK001', 'Such membership is not supported ' || cast (N.WAM_MEMBER_TYPE as varchar) );
  if (not exists (select 1 from  SYS_ROLE_GRANTS, SYS_USERS g 
	where g.U_NAME = _role and gi_super = N.WAM_USER and gi_grant = g.u_id))
  {
  DB.DBA.USER_GRANT_ROLE (_user, _role);
}
  if (exists (select 1 from  SYS_ROLE_GRANTS, SYS_USERS g
                   where g.U_NAME = _role_revoke and gi_super = N.WAM_USER and gi_grant = g.u_id))
  {
    DB.DBA.USER_REVOKE_ROLE (_user, _role_revoke);
  }
}
;

create trigger WIKI_WA_MEMBERSHIP_CLOSE after delete on DB.DBA.WA_MEMBER order 100 referencing old as O
{
  -- dbg_obj_princ ('WIKI_WA_MEMBERSHIP_OPEN: ', O.WAM_STATUS);
  if (O.WAM_APP_TYPE <> 'oWiki')
    return;
  if (O.WAM_STATUS > 2)
    return;
   declare _cluster_id integer;
  _cluster_id := (select (wai_inst as wa_wikiv).cluster_id from DB.DBA.WA_INSTANCE where WAI_NAME = O.WAM_INST and WAI_TYPE_NAME = 'oWiki');
  if (_cluster_id is null)
    return;
  -- dbg_obj_princ ('WIKI_WA_MEMBERSHIP_OPEN: cl', _cluster_id);
  declare _user varchar;
  _user := (select U_NAME from DB.DBA.SYS_USERS where U_ID = O.WAM_USER);
  declare _cluster_name varchar;
  _cluster_name := (select ClusterName from WV.WIKI.CLUSTERS where ClusterId = _cluster_id);

  declare _role_revoke varchar;
  if (O.WAM_MEMBER_TYPE in (1,2)) -- author
    _role_revoke := _cluster_name || 'Writers';
  else if (O.WAM_MEMBER_TYPE = 3) -- reader
    _role_revoke := _cluster_name || 'Readers';
  else
    return;
  if (exists (select 1 from  SYS_ROLE_GRANTS, SYS_USERS g
                   where g.U_NAME = _role_revoke and gi_super = O.WAM_USER and gi_grant = g.u_id))
  {
    DB.DBA.USER_REVOKE_ROLE (_user, _role_revoke);
  }
}
;
WV.WIKI.SILENT_EXEC('drop trigger DB.DBA.WIKI_WA_INSTANCE_U');
WV.WIKI.SILENT_EXEC('drop trigger DB.DBA.WIKI_WA_INSTANCE_D');

create method wa_front_page_as_user (inout stream any, in user_name varchar) for wa_wikiv
{
  declare sid varchar;
  declare owner varchar;
  owner := (select U_NAME from DB.DBA.SYS_USERS where U_ID = self.owner);
  sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
  insert into VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
    values ('wa', sid, owner, serialize ( vector ( 'vspx_user', owner )), now());
  http_request_status ('HTTP/1.1 302 Found');
  http_header(sprintf('Location: %s?sid=%s&realm=wa\r\n', self.wa_home_url(), sid));
}
;  

create method app_id () for wa_wikiv
{
  return (select wai_id from DB.DBA.WA_INSTANCE where udt_instance_of (WAI_INST, fix_identifier_case ('DB.DBA.wa_wikiv')) and WAI_NAME = self.wa_name);
}
;
  
create method wa_addition_urls () for wa_wikiv
{
  return vector (
    vector (null, null, '/wiki/resources', '/DAV/VAD/wiki/Root/', 1, 0, null, null, null, null, 'Wiki', null, null, 0, null, null, null, 0),
    vector (null, null, '/wiki', '/DAV/VAD/wiki/Root/main.vsp', 1, 0, null, null, null, null, 'Wiki', null, null, 0, null, null, vector ('noinherit', 1, 'executable', 'yes'), 0),
    vector (null, null, '/wiki/main', '/DAV/VAD/wiki/Root/main.vsp', 1, 0, null, null, null, null, 'Wiki', null, null, 0, null, null, vector ('noinherit', 1, 'executable', 'yes'), 0),
    vector (null, null, '/wiki/Atom', '/SOAP/Http/gdata', 0, 0, null, null, null, null,  null, 'Wiki', null, 1, vector ('atom-pub', 1), null, null, 0)
  );
}
;

create method wa_addition_instance_urls (in _lpath varchar) for wa_wikiv
{  
  --! dirty hack
  declare _vhost, port varchar;
  _vhost := connection_get ('vhost');
  port := connection_get ('port');
--  dbg_obj_princ ('>>>>>>', _vhost);
  if (_vhost is null or _vhost like '*ini*%')
    _vhost := '%';
  else if (port <> '80')
    _vhost := _vhost || ':' || port;

  insert replacing WV.WIKI.DOMAIN_PATTERN_1 (DP_HOST, DP_PATTERN, DP_CLUSTER) 
	values (_vhost, WV.WIKI.CANONICAL_PATH(_lpath, 3), self.cluster_id);
  return null;
  if (_vhost <> '%')
    {
      WV.WIKI.SETCLUSTERPARAM (self.cluster_id, 'home', 'http://' || _vhost || WV.WIKI.CANONICAL_PATH(_lpath, 0));
      update DB.DBA.WA_MEMBER set WAM_HOME_PAGE = self.wa_home_url() 
      	where WAM_INST = self.wa_name
	and WAM_USER = (select U_ID from DB.DBA.SYS_USERS where U_NAME = WV.WIKI.CLUSTERPARAM (self.cluster_id, 'creator', 'dav'));
    }
  return null;
  return vector ( 
      vector (
	null, null,
	rtrim (_lpath),
      	'/DAV/VAD/wiki/Root/main.vsp',		-- phys_path
	1, -- is dav
	0, -- is brws
	null, -- def page
	null, -- auth func
	null, --		  realm=>cur_add_url[8],
	null, --		  ppr_fn=>cur_add_url[9],
	'Wiki', --		  vsp_user=>cur_add_url[10],
	null, --		  soap_user=>cur_add_url[11],
	null, --		  sec=>cur_add_url[12],
	0, --	  ses_vars=>cur_add_url[13],
	null, --	  soap_opts=>cur_add_url[14],
	null, --	  auth_opts=>cur_add_url[15],
	vector ('noinherit', 1, 'executable','yes'), -- opts
	0)
--    ,
--      vector (
--	null, null,
--	rtrim (_lpath, '/') || '/resources',
--      	'/DAV/VAD/wiki/Root/',		-- phys_path
--	1, -- is dav
--	0, -- is brws
--	null, -- def page
--	null, -- auth func
--	null, --		  realm=>cur_add_url[8],
--	null, --		  ppr_fn=>cur_add_url[9],
--	'Wiki', --		  vsp_user=>cur_add_url[10],
--	null, --		  soap_user=>cur_add_url[11],
--	null, --		  sec=>cur_add_url[12],
--	0, --	  ses_vars=>cur_add_url[13],
--	null, --	  soap_opts=>cur_add_url[14],
--	null, --	  auth_opts=>cur_add_url[15],
--	vector ('executable','yes'), -- opts
--	0)
     );
}
;

create method wa_vhost_options () for wa_wikiv {
  return vector(
      	'/DAV/VAD/wiki/Root/main.vsp',		-- phys_path
	null,
	'Wiki',				-- user
	0,				-- is brws
	1,				-- is dav
	vector ('noinherit', 1, 'executable','yes'), -- opts
	null,				-- pprs_fn
	null				-- auth_fn
	);
}
;

create procedure WV.WIKI.MAKE_DASHBOARD_ITEM
        (in tim datetime, in title varchar, in uname varchar, in uid varchar, in url varchar, in comment varchar := '')
{
  declare ret any;

  if (not __proc_exists ('DB.DBA.WA_NEW_WIKI_IN'))
    return null;

  ret := null;
      ret := sprintf ('<wiki-db>'||
      '<post>'||
      '<title><![CDATA[%s]]></title>'||
      '<dt>%s</dt>'||
      '<link>%V</link>'||
      '<from><![CDATA[%s]]></from>'||
      '<uid><![CDATA[%s]]></uid>' ||
      '</post>'||
      '</wiki-db>', title, date_iso8601 (tim), url, uname);
--  dbg_obj_princ (ret);
  return ret;
}
;


create method wa_dashboard_last_item () for wa_wikiv {
  declare _cluster_id int;
  _cluster_id := self.cluster_id;
 declare _doc, _ent any;
 _doc := XMLELEMENT ('wiki-db');
 _ent := xpath_eval ('/wiki-db', _doc);
 for select top 5 C_DATE, C_ID, C_AUTHOR, C_EMAIL, C_TOPIC_ID
   from WV.WIKI.COMMENT 
   order by C_DATE desc
 do {
    declare _topic WV.WIKI.TOPICINFO;
    _topic := WV.WIKI.TOPICINFO();
    _topic.ti_id := C_TOPIC_ID;
    _topic.ti_find_metadata_by_id();
    
    XMLAppendChildren (_ent,
      XMLELEMENT ('comment',
        XMLELEMENT ('dt', WV.WIKI.DATEFORMAT (C_DATE)),
	XMLELEMENT ('from', C_AUTHOR || case when C_EMAIL <> '' then '<' || C_EMAIL || '>' else '' end),
	XMLELEMENT ('for-post', _topic.ti_full_name()),
	--XMLELEMENT ('url', _topic.ti_fill_url() || '#wiki' || cast (C_ID as varchar))));
  --XMLELEMENT ('url', SIOC..wiki_post_iri (_topic.ti_cluster_name, _topic.ti_cluster_id, _topic.ti_local_name) || '#wiki' || cast (C_ID as varchar))));
  XMLELEMENT ('url', WV.WIKI.wiki_post_uri (_topic.ti_cluster_name, _topic.ti_cluster_id, _topic.ti_local_name) || '#wiki' || cast (C_ID as varchar))));
 }	
 for select top 5 RES_MOD_TIME, TopicId 
    from WV.WIKI.TOPIC, WS.WS.SYS_DAV_RES 
  	where ClusterId = _cluster_id
	  and RES_ID = ResId
	order by RES_MOD_TIME desc
 do {
    declare _topic WV.WIKI.TOPICINFO;
    _topic := WV.WIKI.TOPICINFO();
    _topic.ti_id := TopicId;
    _topic.ti_find_metadata_by_id();
    
    XMLAppendChildren (_ent, 
      XMLELEMENT ('post',
        XMLELEMENT ('title', _topic.ti_full_name()),
	XMLELEMENT ('from', _topic.ti_author),
	XMLELEMENT ('dt', WV.WIKI.DATEFORMAT (RES_MOD_TIME)),
	XMLELEMENT ('uid', _topic.ti_author),
	--XMLELEMENT ('link', _topic.ti_fill_url() || '?')));
  --XMLELEMENT ('link', SIOC..wiki_post_iri (_topic.ti_cluster_name, _topic.ti_cluster_id, _topic.ti_local_name) || '?')));
  XMLELEMENT ('link', WV.WIKI.wiki_post_uri (_topic.ti_cluster_name, _topic.ti_cluster_id, _topic.ti_local_name) || '?')));
 }
 return serialize_to_UTF8_xml(_doc);
}
;


create procedure WV.WIKI.ERROR (in err_code int, in signal_err int)
{
  if (signal_err) 
    {
      declare err_msg varchar;
      err_msg := 'Unknown error';
      if (err_code = -1000)
        err_msg := 'Instance exists already';
      signal ('WV000', err_msg);
    }
  return err_code;
}
;

create procedure WV.WIKI.CREATEINSTANCE (
  in cluster_name varchar,
  in _owner int,
  in _group int,
  in signal_err int := 1)
{
--dbg_obj_print (cluster_name);
  if (exists (select 1 from DB.DBA.WA_INSTANCE where WAI_NAME = cluster_name))
    return WV.WIKI.ERROR (-1000, signal_err);
--dbg_obj_print(1, (select ClusterId from WV.WIKI.CLUSTERS where ClusterName = cluster_name));
  if (exists (select 1 from WV.WIKI.CLUSTERS where ClusterName  = cluster_name))
    return WV.WIKI.ERROR (-1002, signal_err);
  declare inst wa_wikiv;
  inst := (select __udt_instantiate_class (fix_identifier_case (WAT_TYPE), 0) from WA_TYPES where WAT_NAME = 'oWiki');
--dbg_obj_print (inst);
  if (inst is null)
    return WV.WIKI.ERROR (-1001, signal_err);
  inst := inst.wa_name := cluster_name;
  inst := inst.wa_member_model := 2; -- approved based
--dbg_obj_print(inst);
  declare h, id any;
  h := udt_implements_method (inst, fix_identifier_case ('wa_new_inst'));
--dbg_obj_print(h);
  if (h)
    id := call (h) (inst, (select U_NAME from DB.DBA.SYS_USERS where U_ID = _owner));
  else 
    return;

  update DB.DBA.WA_INSTANCE
    set WAI_MEMBER_MODEL = 2,
      WAI_IS_PUBLIC = 1,
      WAI_MEMBERS_VISIBLE = 1,
      WAI_NAME = cluster_name,
      WAI_DESCRIPTION = ''
   where WAI_ID = id;
  return id;
}
;


create method wa_rdf_url (in vhost varchar, in lhost varchar) for wa_wikiv
{
  -- dbg_aobj_princ (full_path, ' => ', pattern, ' ', _host);
  declare _cluster_name varchar;

  _cluster_name := (select CLUSTERNAME from WV.WIKI.CLUSTERS where CLUSTERID = self.cluster_id);
  return sprintf ('/wiki/resources/gems.vsp?type=rdf&cluster=%U', _cluster_name);
}
;


create method wa_post_url (in vhost varchar, in lhost varchar, in inst_name varchar, in post any) for wa_wikiv
{
  declare url varchar;
  url := WV.WIKI.CLUSTERPARAM (self.cluster_id, 'home', '/wiki/main');
  return url || '/' || post;
}
;

create method wa_update_instance (in oldValues any, in newValues any) for wa_wikiv
{
  if (newValues[0] <> oldValues[0])
  {
    declare owner, home, srcPath, dstPath varchar;

    owner := (select U_NAME from DB.DBA.SYS_USERS A, DB.DBA.WA_MEMBER B where U_ID = WAM_USER and WAM_INST = oldValues[0] and WAM_MEMBER_TYPE = 1);
    home := DB.DBA.DAV_HOME_DIR(owner);
    srcPath := home || 'wiki/' || oldValues[0]||'/';
    dstPath := home || 'wiki/' || newValues[0]||'/';
    DB.DBA.DAV_MOVE_INT (srcPath, dstPath, 1, null, null, 0);

    update WV.WIKI.CLUSTERS
       set ClusterName = newValues[0]
     where ClusterName = oldValues[0];

    WV.WIKI.CREATEROLES (newValues[0]);
    WV.WIKI.USERROLE_DROP (oldValues[0]||'Readers');
    WV.WIKI.USERROLE_DROP (oldValues[0]||'Writers');
  }

  if ((newValues[1] >= 1) and 
      (not exists (select 1 from  SYS_ROLE_GRANTS, SYS_USERS g, SYS_USERS l
                    where g.U_NAME = newValues[0] || 'Readers'
							        and l.U_NAME = 'WikiGuest'
							        and gi_super = l.U_ID
							        and gi_grant = g.u_id)))
  {
	  DB.DBA.USER_GRANT_ROLE ('WikiGuest', newValues[0] || 'Readers');
  }
  if ((newValues[1] < 1) and 
      (exists (select 1 from  SYS_ROLE_GRANTS, SYS_USERS g, SYS_USERS l
                where g.U_NAME = newValues[0] || 'Readers'
					        and l.U_NAME = 'WikiGuest'
					        and gi_super = l.U_ID
					        and gi_grant = g.u_id)))
  {
    DB.DBA.USER_REVOKE_ROLE ('WikiGuest', newValues[0] || 'Readers');
  }
  return (self as web_app).wa_update_instance (oldValues, newValues);
}
;
