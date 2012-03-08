--
--  $Id$
--
--  WA Dashboard support
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

EXEC_STMT (
'create table wa_n_login (
    nlog_count int,
    nlog_day int,
    nlog_max int,
    nlog_max_time datetime,
    nlog_week int,
    nlog_month int,
    nlog_last_time timestamp
    )', 0)
;

EXEC_STMT (
'create table wa_new_user (
    nu_row_id int identity,
    nu_name varchar,
    nu_u_id int, -- ref sys_users
    nu_since datetime,
    primary key (nu_row_id))', 0)
;

EXEC_STMT (
'create table wa_new_reg (
    nr_row_id int identity,
    nr_name varchar,
    nr_u_id int, -- ref sys_users
    nr_since datetime,
    primary key (nr_row_id))', 0)
;

EXEC_STMT (
'create table wa_new_blog (
    wnb_row_id int identity,
    wnb_post_id varchar,
    wnb_title varchar,
    wnb_link varchar,
    wnb_dt datetime,
    primary key (wnb_row_id))', 0)
;

wa_add_col ('DB.DBA.wa_new_blog', 'wnb_post_id', 'varchar');

EXEC_STMT ('create index wa_new_blog_id on wa_new_blog (wnb_post_id)', 0);

EXEC_STMT (
'create table wa_new_wiki (
    wnw_row_id int identity,
    wnw_topic_id int,
    wnw_title varchar,
    wnw_link varchar,
    wnw_dt datetime,
    primary key (wnw_row_id))', 0)
;


wa_add_col ('DB.DBA.wa_new_wiki', 'wnw_topic_id', 'int');

EXEC_STMT ('create index wa_new_wiki_id on wa_new_wiki (wnw_topic_id)', 0);

EXEC_STMT (
'create table wa_new_news (
    wnn_row_id int identity,
    wnn_efi_id int,
    wnn_title varchar,
    wnn_link varchar,
    wnn_dt datetime,
    primary key (wnn_row_id))', 0)
;

wa_add_col ('DB.DBA.wa_new_news', 'wnn_efi_id', 'int');

EXEC_STMT ('create index wa_new_news_id on wa_new_news (wnn_efi_id)', 0);

EXEC_STMT (
'create table wa_new_bookmarks (
    wnb_row_id int identity,
    wnb_id integer,
    wnb_title varchar,
    wnb_link varchar,
    wnb_dt datetime,
    primary key (wnb_row_id))', 0)
;

EXEC_STMT ('create index wa_new_bookmarks_id on wa_new_bookmarks (wnb_id)', 0);

create procedure wa_clear_stats ()
{
  delete from wa_n_login;
  delete from wa_new_user;
  delete from wa_new_reg;
  delete from vspx_session where vs_realm = 'wa';
};

create procedure wa_reg_register (in u_id int, in u_full_name varchar)
{
  declare id int;
  insert into wa_new_reg (nr_name, nr_u_id, nr_since) values (u_full_name, u_id, now());
  id := identity_value ();
  delete from wa_new_reg where nr_row_id < (id - 10);
};

create trigger vspx_wa_session_start_i after insert on vspx_session referencing new as N
{
  vspx_wa_session_start (N.VS_UID, null, N.VS_SID);
};

create trigger vspx_wa_session_start_u after update on vspx_session referencing old as O, new as N
{
  vspx_wa_session_start (N.VS_UID, O.VS_UID, N.VS_SID);
};

create procedure vspx_wa_session_start (in N_VS_UID any, in O_VS_UID any, in N_VS_SID any)
{
  declare log_count, log_day, log_max, log_week, log_month, max_time, last_time any;
  declare id, u_id int;



  if (length (N_VS_UID) = 0 or length (O_VS_UID) > 0)
    return;

again:

  whenever not found goto newrec;
  select nlog_count, nlog_day, nlog_max, nlog_week, nlog_month, nlog_max_time, nlog_last_time
      into log_count, log_day, log_max, log_week, log_month, max_time, last_time
      from wa_n_login;


  log_count := log_count + 1;
  log_day := log_day + 1;
  log_week := log_week + 1;
  log_month := log_month + 1;

  if (log_count > log_max)
    {
      log_max := log_count;
      max_time := now ();
    }

  if (dayofyear(now ()) > dayofyear(last_time) or year (now()) > year (last_time))
    log_day := 0;

  if (week (now()) > week (last_time) or year (now()) > year (last_time))
    log_week := 0;

  if (month (now ()) > month (last_time) or year (now()) > year (last_time))
    log_month := 0;

  update wa_n_login set nlog_count = log_count,
	 nlog_day = log_day,
	 nlog_max = log_max,
	 nlog_week = log_week,
	 nlog_month = log_month,
	 nlog_max_time = max_time
    ;

  u_id := (select u.U_ID from SYS_USERS u where u.U_NAME = N_VS_UID);
  insert into wa_new_user (nu_u_id, nu_name, nu_since) values (u_id, N_VS_UID, now());

  id := identity_value ();
  delete from wa_new_user where nu_row_id < (id - 10);

  return;

  newrec:
  -- XXX: to be done at init time
  insert into wa_n_login (nlog_count,nlog_day,nlog_max,nlog_week, nlog_month, nlog_max_time)
      values (0,0,0,0,0,now());
  goto again;
};

create trigger vspx_wa_session_end after delete on vspx_session referencing old as O
{
  declare log_count, log_day, log_max, log_week, log_month, max_time, last_time any;

  if (O.VS_UID is null)
    return;

  whenever not found goto endu;
  select nlog_count,nlog_day,nlog_max,nlog_week, nlog_month, nlog_max_time, nlog_last_time
      into log_count, log_day, log_max, log_week, log_month, max_time, last_time
      from wa_n_login;

  log_count := log_count - 1;
  if (log_count < 0)
    log_count := 0;

  if (dayofyear(now ()) > dayofyear(last_time) or year (now()) > year (last_time))
    log_day := 0;

  if (week (now()) > week (last_time) or year (now()) > year (last_time))
    log_week := 0;

  if (month (now ()) > month (last_time) or year (now()) > year (last_time))
    log_month := 0;

  update wa_n_login set nlog_count = log_count,
	 nlog_day = log_day,
	 nlog_week = log_week,
	 nlog_month = log_month
    ;

  endu:
  return;
};


create procedure WA_NEW_BLOG_IN (in title varchar, in link varchar, in iid varchar := null)
{
  declare id, rc int;
  delete from wa_new_blog where wnb_post_id = iid;
  rc := row_count ();
  insert into wa_new_blog (wnb_title, wnb_link, wnb_dt, wnb_post_id) values (title, link, now(), iid);
  id := identity_value ();
  if (not rc)
    delete from wa_new_blog where wnb_row_id < (id - 10);
};

create procedure WA_NEW_BLOG_RM (in id varchar)
{
  delete from wa_new_blog where wnb_post_id = id;
};

create procedure WA_NEW_NEWS_IN (in title varchar, in link varchar, in iid int := null)
{
  declare id, rc int;
  delete from wa_new_news where wnn_efi_id = iid;
  rc := row_count ();
  insert into wa_new_news (wnn_title, wnn_link, wnn_dt, wnn_efi_id) values (title, link, now(), iid);
  id := identity_value ();
  if (not rc)
    delete from wa_new_news where wnn_row_id < (id - 10);
};

create procedure WA_NEW_NEWS_RM (in id varchar)
{
  delete from wa_new_news where wnn_efi_id = id;
};


create procedure WA_NEW_WIKI_IN (in title varchar, in link varchar, in iid int := null)
{
  declare id, rc int;
  delete from wa_new_wiki where wnw_topic_id = iid;
  rc := row_count ();
  insert into wa_new_wiki (wnw_title, wnw_link, wnw_dt, wnw_topic_id) values (title, link, now(), iid);
  id := identity_value ();
  if (not rc)
    delete from wa_new_wiki where wnw_row_id < (id - 10);
};

create procedure WA_NEW_WIKI_RM (in id varchar)
{
  delete from wa_new_wiki where wnw_topic_id = id;
};


create procedure WA_NEW_BOOKMARKS_IN (in title varchar, in link varchar, in id integer)
{
  declare rc, row_id int;

  delete from wa_new_bookmarks where wnb_id = id;
  rc := row_count ();
  insert into wa_new_bookmarks (wnb_title, wnb_link, wnb_dt, wnb_id) values (title, link, now(), id);
  row_id := identity_value ();
  if (not rc)
    delete from wa_new_bookmarks where wnb_row_id < (row_id - 10);
};

create procedure WA_NEW_BOOKMARKS_RM (in id integer)
{
  delete from wa_new_bookmarks where wnb_id = id;
};


create procedure WA_USER_DASHBOARD_SP (in uid int, in inst_type varchar)
{
  declare inst_name, title, author, url nvarchar;
  declare ts datetime;
  declare uname, email varchar;
  declare inst web_app;
  declare h, ret any;

  result_names (inst_name, title, ts, author, url, uname, email);
  for select WAM_INST,
             WAI_INST,
             WAM_HOME_PAGE
        from WA_MEMBER, WA_INSTANCE
       where WAI_NAME = WAM_INST
         and WAM_USER = uid
         and WAM_APP_TYPE = inst_type do
    {
      ret := '';
    	inst := WAI_INST;
    	h := udt_implements_method (inst, fix_identifier_case ('wa_dashboard_user_items'));
    	if (h)
    	  {
    	    ret := call (h) (inst);
    	  }
    	else
    	  {
    	    h := udt_implements_method (inst, fix_identifier_case ('wa_dashboard_last_item'));
    	    if (h)
    	      {
    	        ret := call (h) (inst);
    	      }
    	  }
	    if (length (ret))
	      {
      		declare xp any;
      		ret := xtree_doc (ret);

      		xp := xpath_eval ('//*[title]', ret, 0);
      		foreach (any ret1 in xp) do
      		  {
      		    title := substring (xpath_eval ('string(title/text())', ret1), 1, 1024);
      		    ts := xpath_eval ('string (dt/text())', ret1);
      		    author := xpath_eval ('string (from/text())', ret1);
      		    url := xpath_eval ('string (link/text())', ret1);
      		    uname := cast(xpath_eval ('string (uid/text())', ret1) as varchar);
      		    email := cast(xpath_eval ('string (email/text())', ret1) as varchar);

      		    ts := cast (ts as datetime);
      		    result (WAM_INST, title, ts, author, url, uname, email);
		        }
	      }
    }
};


create procedure WA_COMMON_DASHBOARD_SP (in inst_type varchar)
{
  declare inst_name, title, author, url nvarchar;
  declare ts datetime;
  declare uname, email varchar;
  declare inst web_app;
  declare h, ret any;

  result_names (inst_name, title, ts, author, url, uname, email);
  for select WAM_INST, WAI_INST, WAM_HOME_PAGE from WA_MEMBER, WA_INSTANCE where WAI_NAME = WAM_INST
    and WAI_IS_PUBLIC=1 and WAM_APP_TYPE = inst_type option (loop) do
      {
	inst := WAI_INST;
	h := udt_implements_method (inst, fix_identifier_case ('wa_dashboard_last_item'));
	if (h)
	  {
	    ret := call (h) (inst);
	    if (length (ret))
	      {
		declare xp any;
		ret := xtree_doc (ret);

		xp := xpath_eval ('//*[title]', ret, 0);
		foreach (any ret1 in xp) do
		  {
		    title := substring (xpath_eval ('string(title/text())', ret1), 1, 1024);
		    ts := xpath_eval ('string (dt/text())', ret1);
		    author := xpath_eval ('string (from/text())', ret1);
		    url := xpath_eval ('string (link/text())', ret1);
		    uname := cast(xpath_eval ('string (uid/text())', ret1) as varchar);
		    email := cast(xpath_eval ('string (email/text())', ret1) as varchar);

		    ts := cast (ts as datetime);
		    result (WAM_INST, title, ts, author, url, uname, email);
		  }
	     }
	  }
      }
};



create procedure wa_abs_date (in  dt datetime)
{
  declare diff, ddiff int;
  declare ret any;

  if (dt is null)
    return 'never';

  diff := datediff ('minute', dt, now ());
  ddiff := datediff ('day', dt, now ());
  if (diff <= 1)
    {
      ret := '1 minute ago';
    }
  else if (diff < 60)
    {
      ret := sprintf ('%d minutes ago', diff);
    }
  else if (diff < 120)
    {
      ret := 'Less than 2 hours ago';
    }
  else if (diff < 60*24)
    {
      ret := sprintf ('%d hours ago', datediff ('hour', dt, now ()));
    }
  else if (ddiff = 1)
    {
      ret := sprintf ('Yesterday at %d:%d', hour(dt), minute(dt));
    }
  else if (ddiff < 7)
    {
      ret := sprintf ('%d days ago', ddiff);
    }
  else if (ddiff < 30)
    {
      ret := sprintf ('%d week(s) ago', ddiff/7);
    }
  else if (ddiff < 365)
    {
      ret := sprintf ('%d month(s) ago', ddiff/30);
    }
  else
    {
      ret := sprintf ('%d year(s) ago', ddiff/365);
    }
  return ret;
};

create procedure wa_user_have_mailbox (in uname varchar)
{
  return (select WAI_ID from WA_INSTANCE, WA_MEMBER, SYS_USERS where WAM_APP_TYPE = 'oMail' and WAM_INST = WAI_NAME and WAM_USER = U_ID and WAM_MEMBER_TYPE = 1 and U_NAME = uname);
};

create procedure wa_expand_url (in url varchar, in pars varchar)
{
  declare ret any;
  declare hf any;
  url := cast (url as varchar);
  hf := WS.WS.PARSE_URI (url);

  if (pars is not null)
    pars := trim (pars, '&');
  if (hf[0] <> '' and hf[1] <> WA_GET_HOST ())
    ret := url;
  else
    ret := vspx_uri_add_parameters (url, pars);
  return ret;
};

