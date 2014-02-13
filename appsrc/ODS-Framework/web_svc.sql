--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2014 OpenLink Software
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


use ODS;


DB.DBA.wa_exec_no_error_log(
'create table SVC_HOST
(
  SH_ID integer identity,
  SH_URL varchar,
  SH_NAME varchar,
  SH_PROTO varchar,
  SH_METHOD varchar default ''weblogUpdates.ping'',
  primary key (SH_ID)
)');

DB.DBA.wa_exec_no_error_log(
'create table APP_PING_REG
(
 AP_HOST_ID int references SVC_HOST (SH_ID) on update cascade on delete cascade,
 AP_WAI_ID int references DB.DBA.WA_INSTANCE (WAI_ID) on update cascade on delete cascade,
 primary key (AP_WAI_ID, AP_HOST_ID)
)');

-- keeps one entry with APL_STAT = 0 and many other either with error or done, hence time is part of pk.
DB.DBA.wa_exec_no_error_log(
'create table APP_PING_LOG
(
 APL_HOST_ID int references SVC_HOST (SH_ID) on update cascade on delete cascade,
 APL_WAI_ID int references DB.DBA.WA_INSTANCE (WAI_ID) on update cascade on delete cascade,
 APL_P_TITLE varchar default null,
 APL_P_URL varchar default null,
 APL_FEED_URL varchar default null,
 APL_STAT int default 0, -- 1 sent, 2 error, 0 pending
 APL_TS timestamp,
 APL_SENT datetime,
 APL_ERROR long varchar,
 APL_SEQ integer identity,
 primary key (APL_WAI_ID, APL_HOST_ID, APL_STAT, APL_SEQ)
)');

DB.DBA.wa_add_col ('ODS.DBA.APP_PING_LOG', 'APL_FEED_URL', 'varchar default null');

DB.DBA.wa_exec_no_error_log('create index APP_PING_LOG_IDX1 on ODS.DBA.APP_PING_LOG (APL_STAT, APL_WAI_ID)');

DB.DBA.wa_exec_no_error_log(
'create table ACT_PING_LOG (
    APL_HOST_ID int references SVC_HOST (SH_ID) on update cascade on delete cascade,
    APL_URI IRI_ID,
    APL_WA_ID int references DB.DBA.WA_ACTIVITIES (WA_ID) on update cascade on delete cascade,
    APL_STAT int default 0,
    APL_TS timestamp,
    APL_SENT datetime,
    APL_ERROR long varchar,
    APL_SEQ integer identity,
    primary key (APL_URI, APL_HOST_ID, APL_STAT, APL_SEQ))');

insert soft SVC_HOST (SH_ID, SH_URL, SH_NAME, SH_PROTO) values (0, '', '--', '');

insert soft SVC_HOST (SH_ID, SH_URL, SH_NAME, SH_PROTO) values (1, 'http://rpc.weblogs.com/RPC2', 'Weblog.com', 'xml-rpc');

insert soft SVC_HOST (SH_ID, SH_URL, SH_NAME, SH_PROTO) values (2, 'http://rpc.weblogs.com/weblogUpdates', 'Weblog.com (soap)', 'soap');

insert soft SVC_HOST (SH_ID, SH_URL, SH_NAME, SH_PROTO) values (3, 'http://ping.blo.gs/', 'blo.gs', 'xml-rpc');

insert soft SVC_HOST (SH_ID, SH_URL, SH_NAME, SH_PROTO) values (4, 'http://rpc.technorati.com/rpc/ping', 'Technorati', 'xml-rpc');

--insert soft SVC_HOST (SH_ID, SH_URL, SH_NAME, SH_PROTO) values (5, 'http://ping.rootblog.com/rpc.php', 'RootBlog', 'xml-rpc');

insert soft SVC_HOST (SH_ID, SH_URL, SH_NAME, SH_PROTO) values (6, 'http://rpc.blogrolling.com/pinger/', 'Blogrolling', 'xml-rpc');

insert soft SVC_HOST (SH_ID, SH_URL, SH_NAME, SH_PROTO) values (7, 'http://www.blogshares.com/rpc.php', 'Blogshares', 'xml-rpc');

insert soft SVC_HOST (SH_ID, SH_URL, SH_NAME, SH_PROTO) values (8, 'http://api.my.yahoo.com/RPC2', 'My Yahoo', 'xml-rpc');

insert soft SVC_HOST (SH_ID, SH_URL, SH_NAME, SH_PROTO) values (9, 'http://api.moreover.com/RPC2', 'Moreover', 'xml-rpc');

insert soft SVC_HOST (SH_ID, SH_URL, SH_NAME, SH_PROTO, SH_METHOD) values (10, 'http://rpc.weblogs.com/RPC2', 'Weblog.com (extended)', 'xml-rpc', 'weblogUpdates.extendedPing');

insert soft SVC_HOST (SH_ID, SH_URL, SH_NAME, SH_PROTO, SH_METHOD) values (11, 'http://geourl.org/ping/?p=', 'GeoURL', 'REST', 'ping');

insert soft SVC_HOST (SH_ID, SH_URL, SH_NAME, SH_PROTO) values (12, 'http://rpc.pingthesemanticweb.com/', 'The Semantic Web.com', 'xml-rpc');

create procedure SVC_HOST_INIT ()
{
  if (DB.DBA.GET_IDENTITY_COLUMN ('ODS.DBA.SVC_HOST', 'SH_ID') < 14)
    DB.DBA.SET_IDENTITY_COLUMN ('ODS.DBA.SVC_HOST', 'SH_ID', 14);
};

SVC_HOST_INIT ();

create procedure SVC_PROCESS_PINGS ()
{
  declare _host_id, _wai_id, dedl, seq int;
  declare nam, use_pings, _url, _title, _feed_url varchar;
  declare _inst DB.DBA.web_app;

  declare cr cursor for select APL_HOST_ID, APL_WAI_ID, WAI_DESCRIPTION, WAI_INST, APL_P_TITLE, APL_P_URL, APL_SEQ, APL_FEED_URL from
      APP_PING_LOG, DB.DBA.WA_INSTANCE where WAI_ID = APL_WAI_ID and APL_STAT = 0;

  dedl := 0;

  declare exit handler for sqlstate '40001'
    {
      rollback work;
      close cr;
      dedl := dedl + 1;
      if (dedl < 5)
	goto again;
    };

again:
  whenever not found goto ret;
  open cr (prefetch 1);
  while (1)
    {
      _inst := null;
      fetch cr into _host_id, _wai_id, nam, _inst, _title, _url, seq, _feed_url;
      commit work;
      for select SH_URL, SH_PROTO, SH_METHOD, SH_NAME from SVC_HOST where SH_ID = _host_id do
	  {

	    if (isstring (SH_PROTO) and SH_PROTO <> '' and _inst is not null)
	      {
		declare url, rc varchar;
		rc := null;

		if (length (_url) = 0)
		  {
		    url := _inst.wa_home_url ();
		    url := DB.DBA.WA_LINK (1, url);
		  }
		else
		  url := DB.DBA.WA_LINK (1, _url);

		if (length (_feed_url))
		  _feed_url := DB.DBA.WA_LINK (1, _feed_url);  

		if (length (_title))
		  nam := _title;

		{
		  declare exit handler for sqlstate '*' {
		    rollback work;
		    update APP_PING_LOG set APL_ERROR = __SQL_MESSAGE, APL_STAT = 2, APL_SENT = now ()
			       where APL_WAI_ID = _wai_id and APL_HOST_ID = _host_id and APL_STAT = 0 and APL_SEQ = seq;
		    commit work;
		    goto next;
		  };

		  commit work;
--		  dbg_printf ('[%s] [%s] [%s] [%s] [%s]', SH_PROTO, SH_URL, SH_METHOD, url, nam);
		  if (SH_PROTO = 'soap')
		    {
		      rc := DB.DBA.SOAP_CLIENT (url=>SH_URL,
		      operation=>'ping',
		      parameters=>vector ('weblogname',nam,'weblogurl',url),
		      soap_action=>'/weblogUpdates'
		      );
		    }
		  else if (SH_PROTO = 'xml-rpc')
		    {
		      if (SH_METHOD = 'weblogUpdates.ping')
			{
			  rc := DB.DBA.XMLRPC_CALL (SH_URL, 'weblogUpdates.ping', vector (nam, url));
			}
		      else if (length (_feed_url))
			{
			  rc := DB.DBA.XMLRPC_CALL (SH_URL, 'weblogUpdates.extendedPing', vector (nam, url, url, _feed_url));
			}
		    }
		  else if (SH_PROTO = 'REST' and lower (SH_NAME) = 'twitter')
		    {
		      declare sid any;
		      sid := (select WUO_OAUTH_SID from DB.DBA.WA_USER_OL_ACCOUNTS, DB.DBA.WA_MEMBER 
		      	where WAM_USER = WUO_U_ID and WAM_INST = _inst and WUO_NAME = 'Twitter');
	              if (length (sid))
 		        ODS.ODS_API.twitter_status_update (_title, sid);	
		    }
		  else if (SH_PROTO = 'REST')
		    {
		      declare hf, ping_url any;
		      ping_url := sprintf ('%s%U', SH_URL, url);
		      http_get (ping_url, hf);
		      if (isarray (hf) and length (hf) and hf[0] not like 'HTTP/1._ 200 %')
			{
			  rc := xml_tree (sprintf ('<response><flerror>1</flerror><message>%V</message></response>', hf[0]));
			}
		    }
		  else if (SH_PROTO = 'PubSubHub' and length (_feed_url))
		    {
		      declare hf any;
		      http_get (SH_URL, hf, 'POST', null, sprintf ('hub.mode=publish&hub.url=%U', _feed_url));
		      if (isarray (hf) and length (hf) and hf[0] not like 'HTTP/1._ 204 %')
			{
			  rc := xml_tree (sprintf ('<response><flerror>1</flerror><message>%V</message></response>', hf[0]));
			}
		    }
		}

	      if (isarray(rc))
		{
		  declare xt any;
		  declare err, msg any;
		  xt := xml_tree_doc (rc);
		  err := cast (xpath_eval ('//flerror/text()', xml_cut(xt), 1) as varchar);
		  msg := cast (xpath_eval ('//message/text()', xml_cut(xt), 1) as varchar);
		  if (err <> '0')
		    {
		      update APP_PING_LOG set APL_ERROR = msg, APL_STAT = 2, APL_SENT = now ()
			       where APL_WAI_ID = _wai_id and APL_HOST_ID = _host_id and APL_STAT = 0 and APL_SEQ = seq;
		      commit work;
		      goto next;
		    }
		}
	      }
	  }
      update APP_PING_LOG set APL_STAT = 1, APL_SENT = now () where APL_WAI_ID = _wai_id and APL_HOST_ID = _host_id and APL_STAT = 0 and APL_SEQ = seq;
      commit work;
      next:;
    }
  ret:
  close cr;
  return;
};

create procedure APP_PING
	(
	in _wai_name varchar,
	in _post_title varchar := null,
	in _post_url varchar := null,
	in svc_name varchar := null,
	in _feed_url varchar := null
	)
{
  if (_feed_url is null) 
    _feed_url := '';
  if (svc_name is null)
    {
      for select AP_HOST_ID, WAI_ID from APP_PING_REG, DB.DBA.WA_INSTANCE where WAI_ID = AP_WAI_ID and WAI_NAME = _wai_name do
	{
	  if (not exists 
	      (select 1 from APP_PING_LOG where APL_WAI_ID = WAI_ID and APL_HOST_ID = AP_HOST_ID and APL_STAT = 0 and APL_FEED_URL = _feed_url))
	    insert into APP_PING_LOG (APL_WAI_ID, APL_HOST_ID, APL_STAT, APL_P_TITLE, APL_P_URL, APL_FEED_URL)
		values (WAI_ID, AP_HOST_ID, 0, _post_title, _post_url, _feed_url);
	}
    }
  else
    {
      declare s_id, _wai_id int;
      s_id := (select SH_ID from SVC_HOST where SH_NAME = svc_name);
      _wai_id := (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_NAME = _wai_name);
      if (s_id is not null and _wai_id is not null and
	  not exists (select 1 from APP_PING_LOG where APL_WAI_ID = _wai_id and APL_HOST_ID = s_id and APL_STAT = 0 and APL_FEED_URL = _feed_url)
	  )
	insert into APP_PING_LOG (APL_WAI_ID, APL_HOST_ID, APL_STAT, APL_P_TITLE, APL_P_URL, APL_FEED_URL)
	    values (_wai_id, s_id, 0, _post_title, _post_url, _feed_url);

    }
};

create procedure PSH_HEADER_LINKS (in inst_id integer)
{
  declare psh, links varchar;

  links := '';
  for select SH_URL
        from ODS.DBA.SVC_HOST,
             ODS.DBA.APP_PING_REG
	     where SH_PROTO = 'PubSubHub'
	       and SH_ID = AP_HOST_ID
	       and AP_WAI_ID = inst_id do
	{
	  psh := SH_URL;
	  if (length (psh))
      links := links || sprintf (' <%s>; rel="hub"; title="PubSubHub",\r\n', psh);
	}
  return rtrim (links, ',\r\n');
};

create procedure PSH_ATOM_LINKS (in inst_id integer)
{
  declare psh, links varchar;

  links := '';
  for select SH_URL
        from ODS.DBA.SVC_HOST,
             ODS.DBA.APP_PING_REG
	     where SH_PROTO = 'PubSubHub'
	       and SH_ID = AP_HOST_ID
	       and AP_WAI_ID = inst_id do
	{
	  psh := SH_URL;
	  if (length (psh))
      links := links || sprintf ('<atom:link xmlns:atom="http://www.w3.org/2005/Atom" href="%s" rel="hub" title="PubSubHub" />', psh);
	}
  return links;
};

create procedure PSH_CALLBACK_LINK ()
{
  return 'http://' || DB.DBA.WA_CNAME() || '/psh/callback.vsp';
};

create procedure PSH_SUBSCRIBE_LINK ()
{
  return 'http://' || DB.DBA.WA_CNAME() || '/psh/subscribe.vsp';
};

create procedure PSH_ACTIVITY_PING (in ep_url varchar, in _feed_url varchar)
{
  declare hf, rc any;
  rc := null;
  declare exit handler for sqlstate '*'
    {
      return __SQL_MESSAGE;
    };
  http_get (ep_url, hf, 'POST', null, sprintf ('hub.mode=publish&hub.url=%U', _feed_url));
  if (isarray (hf) and length (hf) and hf[0] not like 'HTTP/1._ 204 %')
    {
      rc := hf[0];
    }
  return rc;
}
;

create procedure SVC_PROCESS_ACT_PINGS ()
{
  declare _host_id, rc, dedl, seq int;
  declare nam, use_pings, _url, _title, _feed_url varchar;
  declare _inst DB.DBA.web_app;

  declare cr cursor for select APL_HOST_ID, APL_URI, APL_SEQ from ACT_PING_LOG where APL_STAT = 0;

  dedl := 0;

  declare exit handler for sqlstate '40001'
    {
      rollback work;
      close cr;
      dedl := dedl + 1;
      if (dedl < 5)
	goto again;
    };

again:
  whenever not found goto ret;
  open cr (prefetch 1);
  while (1)
    {
      _inst := null;
      fetch cr into _host_id, _feed_url, seq;
      commit work;
      for select SH_URL, SH_PROTO, SH_METHOD, SH_NAME from SVC_HOST where SH_ID = _host_id and SH_PROTO = 'PubSubHub' do
	  {
	    rc := PSH_ACTIVITY_PING (SH_URL, id_to_iri (_feed_url));
	    if (rc is not null)
	      {
		update ACT_PING_LOG set APL_ERROR = rc, APL_STAT = 2, APL_SENT = now ()
		    where APL_URI = _feed_url and APL_HOST_ID = _host_id and APL_STAT = 0 and APL_SEQ = seq;
		commit work;
	      }
	  }
      update ACT_PING_LOG set APL_STAT = 1, APL_SENT = now () where APL_URI = _feed_url and APL_HOST_ID = _host_id and APL_STAT = 0 and APL_SEQ = seq;
      commit work;
      next:;
    }
  ret:
  close cr;
  return;
};

create trigger WA_ACTIVITIES_I after insert on DB.DBA.WA_ACTIVITIES referencing new as N
{
  declare url, cname, uid any;
  cname := DB.DBA.WA_CNAME ();
  uid := (select U_NAME from DB.DBA.SYS_USERS where U_ID = N.WA_U_ID);
  url := sprintf ('http://%s/activities/feeds/activities/user/%s/source/%d', cname, uid, N.WA_SRC_ID);
  ACT_PING (N.WA_ID, url);
}
;

create trigger WA_ACTIVITIES_U after update on DB.DBA.WA_ACTIVITIES referencing old as O, new as N
{
  declare url, cname, uid any;
  cname := DB.DBA.WA_CNAME ();
  uid := (select U_NAME from DB.DBA.SYS_USERS where U_ID = N.WA_U_ID);
  url := sprintf ('http://%s/activities/feeds/activities/user/%s', cname, uid);
  ACT_PING (N.WA_ID, url);
}
;


create procedure ACT_PING (in act_id varchar, in act_url varchar)
{
  declare act_iri any;
  act_iri := iri_to_id (act_url);
  for select SH_ID from ODS.DBA.SVC_HOST where SH_PROTO = 'PubSubHub' do 
    {
      if (not exists (select 1 from ACT_PING_LOG where APL_WA_ID = act_id and APL_HOST_ID = SH_ID and APL_STAT = 0 and APL_URI = act_iri))
	insert into ACT_PING_LOG (APL_URI, APL_HOST_ID, APL_STAT, APL_WA_ID)
	    values (act_iri, SH_ID, 0, act_id);
    }
};


use DB;

create function WA_APP_PING_TGT_AGG_init (inout _agg any)
{
  _agg := null;
};

create function WA_APP_PING_TGT_AGG_acc (inout _agg any, in _val varchar)
{
  if (_agg is null)
    _agg := _val;
  else
    _agg := _agg || ', ' || _val;
};


create function WA_APP_PING_TGT_AGG_final (inout _agg any)
{
  return coalesce (_agg, '');
};

create aggregate WA_APP_PING_TGT_AGG (in _val varchar) returns varchar
  from WA_APP_PING_TGT_AGG_init, WA_APP_PING_TGT_AGG_acc, WA_APP_PING_TGT_AGG_final;

insert soft "DB"."DBA"."SYS_SCHEDULED_EVENT" (SE_INTERVAL, SE_LAST_COMPLETED, SE_NAME, SE_SQL, SE_START)
  values (10, NULL, 'ODS NOTIFICATIONS', 'ODS.DBA.SVC_PROCESS_PINGS()', now());

use DB;

create procedure WA_USER_OAUTH_UPGRADE ()
{
  declare params any;

  if (registry_get ('__WA_USER_OAUTH_UPGRADE') = 'done')
    return;

  declare exit handler for sqlstate '*' {return; };

  params := (select US_KEY from WA_USER_SVC where US_U_ID = 2 and US_SVC = 'FBKey');
  if (length (params))
  {
    params := replace (params, '\r\n', '&');
    params := replace (params, '\n', '&');
    params := split_and_decode (params);
    if (params is not null and length (trim (get_keyword ('key', params))) > 4 and length (trim (get_keyword ('secret', params))) > 4)
    {
      insert into OAUTH..APP_REG (A_OWNER, A_NAME, A_KEY, A_SECRET)
        values (0, 'Facebook API', trim(get_keyword('key', params)), trim (get_keyword ('secret', params)));

      delete from WA_USER_SVC where US_SVC = 'FBKey';
    }
  }
  registry_set ('__WA_USER_OAUTH_UPGRADE', 'done');
}
;

DB.DBA.WA_USER_OAUTH_UPGRADE ();
