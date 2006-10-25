--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2006 OpenLink Software
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
 APL_STAT int default 0, -- 1 sent, 2 error, 0 pending
 APL_TS timestamp,
 APL_SENT datetime,
 APL_ERROR long varchar,
 APL_SEQ integer identity,
 primary key (APL_WAI_ID, APL_HOST_ID, APL_STAT, APL_SEQ)
)');


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
  declare nam, use_pings, _url, _title varchar;
  declare _inst DB.DBA.web_app;

  declare cr cursor for select APL_HOST_ID, APL_WAI_ID, WAI_DESCRIPTION, WAI_INST, APL_P_TITLE, APL_P_URL, APL_SEQ from
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
      fetch cr into _host_id, _wai_id, nam, _inst, _title, _url, seq;
      commit work;
      for select SH_URL, SH_PROTO, SH_METHOD from SVC_HOST where SH_ID = _host_id do
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
		      else
			{
			  rc := DB.DBA.XMLRPC_CALL (SH_URL, 'weblogUpdates.extendedPing',
			  vector (nam, url, url, url || 'gems/rss.xml'));
			}
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
	in svc_name varchar := null
	)
{
  if (svc_name is null)
    {
      for select AP_HOST_ID, WAI_ID from APP_PING_REG, DB.DBA.WA_INSTANCE where WAI_NAME = _wai_name do
	{
	  if (not exists (select 1 from APP_PING_LOG where APL_WAI_ID = WAI_ID and APL_HOST_ID = AP_HOST_ID and APL_STAT = 0))
	    insert into APP_PING_LOG (APL_WAI_ID, APL_HOST_ID, APL_STAT, APL_P_TITLE, APL_P_URL)
		values (WAI_ID, AP_HOST_ID, 0, _post_title, _post_url);
	}
    }
  else
    {
      declare s_id, _wai_id int;
      s_id := (select SH_ID from SVC_HOST where SH_NAME = svc_name);
      _wai_id := (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_NAME = _wai_name);
      if (s_id is not null and _wai_id is not null and
	  not exists (select 1 from APP_PING_LOG where APL_WAI_ID = _wai_id and APL_HOST_ID = s_id and APL_STAT = 0)
	  )
	insert into APP_PING_LOG (APL_WAI_ID, APL_HOST_ID, APL_STAT, APL_P_TITLE, APL_P_URL)
	    values (_wai_id, s_id, 0, _post_title, _post_url);

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
