--
--  $Id$
--
--  OAuth protocol support.
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
use OAUTH;

-- Application registrations, via UI
DB.DBA.EXEC_STMT(
'create table OAUTH..APP_REG (
 	a_id int identity,
	a_name varchar,
	a_descr long varchar,
	a_url varchar,
	a_cb_url varchar,
	a_help_url varchar,
	a_key varchar,
	a_secret varchar,
	a_owner int,
	a_status int default 0,
	primary key (a_owner, a_name)
	)',0);

DB.DBA.EXEC_STMT(
  'create unique index APP_REG_K1 on OAUTH..APP_REG (a_key)'
, 0);

-- OAuth sessions
DB.DBA.EXEC_STMT(
'create table OAUTH..SESSIONS (
	s_sid varchar,
	s_nonce varchar,
	s_timestamp int,
	s_a_id int,
	s_req_key varchar,
  s_req_secret varchar,
	s_access_key varchar,
	s_access_secret varchar,
	s_url_cb varchar,
	s_user_data any,
	s_state int,
	s_method varchar,
	s_access_mode int default 1,
	s_ip varchar,
	primary key (s_req_key))', 0);

DB.DBA.EXEC_STMT(
'create table OAUTH..CLI_SESSIONS (
	cs_sid varchar,
	cs_token varchar,
	cs_key varchar,
	cs_secret varchar,
	cs_user_data any,
	cs_ip varchar,
	primary key (cs_sid, cs_token))', 0);

create procedure OAUTH..app_register (
  in aname varchar,
  in owner int)
{
  declare k, sec any;
  get_key_and_secret (k, sec);
  --k := 'key';
  --sec := 'secret';
  insert into OAUTH..APP_REG (a_name,a_key,a_secret,a_owner)
    values (aname, k, sec, owner);
  return identity_value ();
}
;

create procedure OAUTH..OAUTH_INIT ()
{
  if (exists (select 1 from "DB"."DBA"."SYS_USERS" where U_NAME = 'OAuth'))
    return;
  DB.DBA.USER_CREATE ('OAuth', uuid(), vector ('DISABLED', 1, 'LOGIN_QUALIFIER', 'OAUTH'));
}
;

DB.DBA.VHOST_REMOVE (lpath=>'/OAuth');
DB.DBA.VHOST_DEFINE (lpath=>'/OAuth', ppath=>'/SOAP/Http', soap_user=>'OAuth');

DB.DBA.VHOST_REMOVE (lpath=>'/sparql-oauth');
DB.DBA.VHOST_DEFINE (lpath=>'/sparql-oauth', ppath=>'/DAV/VAD/wa/oauth/', vsp_user=>'dba', is_dav=>1, is_brws=>0, def_page=>'sparql.vsp');

OAUTH..OAUTH_INIT ();

create procedure OAUTH..normalize_params (
  in params any)
{
  declare arr, newarr any;
  declare str varchar;
  arr := split_and_decode (params, 0, '\0\0&');
  arr := __vector_sort (arr);
  str := '';
  foreach (any elm in arr) do
  {
    if ((elm not like 'oauth_signature=%'))
      str := str || '&' || elm;
  }
  return ltrim (str, '&');
}
;

create procedure OAUTH..normalize_url (in url any, in lines any)
{
  declare hf any;
  hf := rfc1808_parse_uri (url);
  hf[0] := lower (hf[0]);
  hf[1] := lower (hf[1]);
  return sprintf ('%s://%s%s', hf[0], hf[1], hf[2]);
}
;

create procedure OAUTH..get_requested_url ()
{
  declare url varchar;

  url := http_requested_url ();
  if (server_http_port () = '80')
    url := replace (url, ':80/', '/');

  return url;
}
;

create procedure OAUTH..sign_hmac_sha1 (
  in meth varchar,
  in url varchar,
  in params varchar,
  in consumer_secret varchar,
  in token_secret varchar)
{
  declare str, k, kname, ret varchar;
  str := meth || '&' || replace (sprintf ('%U', url), '/', '%2F') || '&' || sprintf ('%U', params);
  -- dbg_obj_print ('str=',str);
  k := sprintf ('%U', consumer_secret) || '&' || sprintf ('%U', coalesce (token_secret, ''));
  -- dbg_printf ('k=[%s]', k);
  -- dbg_printf ('s=[%s]', str);
  kname := md5 (cast (now () as varchar));
  xenc_key_RAW_read (kname, encode_base64 (k));
  ret := xenc_hmac_sha1_digest (str, kname);
  xenc_key_remove (kname);
  return ret;
}
;

create procedure OAUTH..sign_plaintext (
  in meth varchar,
  in url varchar,
  in params varchar,
  in consumer_secret varchar,
  in token_secret varchar)
{
  return sprintf ('%U', consumer_secret||'&'||token_secret);
}
;

create procedure OAUTH..check_signature (
  in algo varchar,
  in sig varchar,
  in meth varchar,
  in url varchar,
  in params varchar,
  in lines any,
  in consumer_secret varchar,
  in token_secret varchar)
{
  declare c_sig varchar;

  url := OAUTH..normalize_url (url, lines);
  params := OAUTH..normalize_params (params);
  if (algo = 'HMAC-SHA1')
    c_sig := OAUTH..sign_hmac_sha1 (meth, url, params, consumer_secret, token_secret);
  else
    c_sig := OAUTH..sign_plaintext (meth, url, params, consumer_secret, token_secret);

  -- dbg_obj_print ('sig=', sig, ' calculated=', c_sig);
  -- dbg_obj_print ('algo=', algo);
  -- dbg_obj_print ('meth=', meth);
  -- dbg_obj_print ('url=', url);
  -- dbg_obj_print ('params=', params);
  -- dbg_obj_print ('consumer_secret=', consumer_secret);
  -- dbg_obj_print ('token_secret=', token_secret);

  if (sig = c_sig)
    return 1;
  return 0;
}
;

create procedure OAUTH..get_req_url (
  in path varchar,
  in lines any)
{
  return;
}
;

create procedure OAUTH..get_key_and_secret (
  out k any,
  out s any)
{
  k := xenc_rand_bytes (20, 1);
  s := xenc_rand_bytes (16, 1);
}
;

create procedure OAUTH..request_token (
  in oauth_consumer_key varchar,
  in oauth_signature_method varchar,
  in oauth_signature varchar,
  in oauth_timestamp varchar,
  in oauth_nonce varchar,
  in oauth_version varchar := '1.0',
  in oauth_client_ip varchar := null) __SOAP_HTTP 'text/plain'
{
  declare ret, tok, sec varchar;
  declare sid, app_sec, url, meth, params, cookie varchar;
  declare lines any;
  declare app_id int;

  declare exit handler for not found {
    http_header ('Content-Type: text/plain\r\n');
    return 'Can\'t verify request, missing oauth_consumer_key or oauth_token\n';
  };

  declare exit handler for sqlstate '*' {
    http_header ('Content-Type: text/plain\r\n');
    return 'Server error: '||__SQL_MESSAGE||'\n';
  };
  select a_secret, a_id into app_sec, app_id from OAUTH..APP_REG where a_key = oauth_consumer_key;

  if (exists (select 1 from OAUTH..SESSIONS where s_nonce = oauth_nonce))
  {
    http_header ('Content-Type: text/plain\r\n');
    return 'OAuth Verification Failed\n';
  }

  url := get_requested_url ();
  lines := http_request_header ();
  params := http_request_get ('QUERY_STRING');
  meth := http_request_get ('REQUEST_METHOD');

  if (not OAUTH..check_signature (oauth_signature_method, oauth_signature, meth, url, params, lines, app_sec, ''))
  {
    http_header ('Content-Type: text/plain\r\n');
    return 'OAuth Verification Failed: Bad Signature\n';
  }

  get_key_and_secret (tok, sec);

  if (isnull (oauth_client_ip))
    oauth_client_ip := http_client_ip ();

  insert into OAUTH..SESSIONS (s_nonce, s_timestamp, s_req_key, s_req_secret, s_a_id, s_method, s_state, s_ip)
    values (oauth_nonce, oauth_timestamp, tok, sec, app_id, meth, 1, oauth_client_ip);
  commit work;
  ret := sprintf ('oauth_token=%U&oauth_token_secret=%U', tok, sec);
  return ret;
}
;

create procedure OAUTH..hybrid_request_token (in sid varchar, in oauth_consumer_key varchar)
{
  declare ret, tok, sec varchar;
  declare app_sec, url, meth, params, cookie, oauth_client_ip, timest, nonce varchar;
  declare lines any;
  declare app_id int;

  declare exit handler for not found {
    signal ('22023', 'Can not verify request, missing oauth_consumer_key or oauth_token');
  };

  select a_secret, a_id into app_sec, app_id from OAUTH..APP_REG where a_key = oauth_consumer_key;

  url := get_requested_url ();
  params := http_request_get ('QUERY_STRING');
  meth := http_request_get ('REQUEST_METHOD');

  get_key_and_secret (tok, sec);
  sec := '';

  oauth_client_ip := http_client_ip ();
  timest := datediff ('second', stringdate ('1970-1-1'), now ());
  nonce := xenc_rand_bytes (8, 1);

  insert into OAUTH..SESSIONS (s_sid, s_nonce, s_timestamp, s_req_key, s_req_secret, s_a_id, s_method, s_state, s_ip)
    values (sid, nonce, timest, tok, sec, app_id, meth, 2, oauth_client_ip);
  commit work;
  return tok;
}
;

create procedure OAUTH..access_token (
  in oauth_consumer_key varchar,
  in oauth_token varchar,
  in oauth_signature_method varchar,
  in oauth_signature varchar,
  in oauth_timestamp varchar,
  in oauth_nonce varchar,
  in oauth_version varchar := '1.0',
  in oauth_client_ip varchar := null) __SOAP_HTTP 'text/plain'
{
  declare ret, tok, sec varchar;
  declare sid, app_sec, url, meth, params, cookie, req_sec, uname varchar;
  declare lines any;
  declare app_id, owner int;

  declare exit handler for not found {
    http_header ('Content-Type: text/plain\r\n');
    return 'Can\'t verify request, missing oauth_consumer_key or oauth_token\n';
  };

  declare exit handler for sqlstate '*' {
    http_header ('Content-Type: text/plain\r\n');
    return 'Server error: '||__SQL_MESSAGE||'\n';
  };
  select a_secret, a_id, a_owner into app_sec, app_id, owner from OAUTH..APP_REG where a_key = oauth_consumer_key;
  select U_NAME into owner from DB.DBA.SYS_USERS where U_ID = owner;

  if (exists (select 1 from OAUTH..SESSIONS where s_nonce = oauth_nonce))
  {
    http_header ('Content-Type: text/plain\r\n');
    return 'OAuth Verification Failed\n';
  }

  declare exit handler for not found {
    http_header ('Content-Type: text/plain\r\n');
    return 'OAuth Verification Failed\n';
  };

  if (isnull (oauth_client_ip))
    oauth_client_ip := http_client_ip ();
  select s_req_secret, s_sid
    into req_sec, sid
    from OAUTH..SESSIONS
   where s_req_key = oauth_token and s_ip = oauth_client_ip and s_state = 2;

  url := get_requested_url ();
  lines := http_request_header ();
  params := http_request_get ('QUERY_STRING');
  meth := http_request_get ('REQUEST_METHOD');

  if (not check_signature (oauth_signature_method, oauth_signature, meth, url, params, lines, app_sec, req_sec))
  {
    http_header ('Content-Type: text/plain\r\n');
    return 'OAuth Verification Failed: Bad Signature\n';
  }

  get_key_and_secret (tok, sec);

  update OAUTH..SESSIONS
     set s_nonce = oauth_nonce, s_timestamp = oauth_timestamp, s_access_key = tok, s_access_secret = sec, s_state = 3
   where s_req_key = oauth_token and s_ip = oauth_client_ip and s_state = 2;

  ret := sprintf ('oauth_token=%U&oauth_token_secret=%U', tok, sec);
  return ret;
}
;

create procedure OAUTH..authorize (
  in oauth_token varchar,
  in oauth_callback varchar) __SOAP_HTTP 'text/plain'
{
  if (not exists (select 1 from OAUTH..SESSIONS where s_req_key = oauth_token and s_ip = http_client_ip () and s_state = 1))
  {
    http_header ('Content-Type: text/plain\r\n');
    return 'OAuth Verification Failed\n';
  }
  declare url any;

  url := sprintf ('/oauth/oauth_authorize.vspx?token=%U&cb=%U', oauth_token, oauth_callback);
  http_status_set (301);
  http_header (sprintf ('Location: %s\r\n', url));
  return '';
}
;

create procedure OAUTH..check_authentication_by_name_safe (
  in inparams any := null,
  in lines any := null,
  out uname varchar,
  in app_inst varchar)
{
  if (inparams is null)
    inparams := http_param ();
  if (lines is null)
    lines := http_request_header ();
  declare exit handler for sqlstate '*' {
    return 0;
  };
  return check_authentication_by_name (inparams, lines, uname, app_inst);
}
;

create procedure OAUTH..get_sid (in inparams any, in lines any)
{
  declare oauth_token varchar;
  declare ret, tok, sec, ahead, params varchar;

  ahead := http_request_header (lines, 'Authorization', null, null);
  params := null;
  if (ahead is not null)
  {
    declare tmp, newpars any;
    tmp := split_and_decode (ahead, 0, '\0\0,');
    newpars := vector ();
    if (length (tmp) and trim(tmp[0]) like 'OAuth %')
	  {
	    for (declare i, l int, i := 1, l := length (tmp); i < l; i := i + 1)
	    {
	      declare par any;
	      par := split_and_decode (trim(tmp[0]), 0, '\0\0=');
	      newpars := vector_concat (newpars, par);
	    }
	    if (length (newpars))
	      params := newpars;
	  }
  }
  if (params is null)
    params := inparams;

  oauth_token := get_keyword ('oauth_token', params);
  return (select s_sid from OAUTH..SESSIONS where s_access_key = oauth_token and s_ip = http_client_ip () and s_state = 3);
}
;

create procedure OAUTH..check_authentication_by_name (in inparams any, in lines any, out uname varchar, in app_inst varchar)
{
  declare oauth_consumer_key varchar;
  declare oauth_token varchar;
  declare oauth_signature_method varchar;
  declare oauth_signature varchar;
  declare oauth_timestamp varchar;
  declare oauth_nonce varchar;
  declare oauth_version varchar;
  declare oauth_client_ip varchar;

  declare ret, tok, sec, ahead, params varchar;
  declare sid, app_sec, url, meth, cookie, req_sec, app_name varchar;
  declare app_id int;

  ahead := http_request_header (lines, 'Authorization', null, null);
  params := null;
  if (ahead is not null)
  {
    declare tmp, newpars any;
    tmp := split_and_decode (ahead, 0, '\0\0,');
    newpars := vector ();
    if (length (tmp) and trim(tmp[0]) like 'OAuth %')
	  {
	    for (declare i, l int, i := 1, l := length (tmp); i < l; i := i + 1)
	    {
	      declare par any;
	      par := split_and_decode (trim(tmp[0]), 0, '\0\0=');
	      newpars := vector_concat (newpars, par);
	    }
	    if (length (newpars))
	      params := newpars;
	  }
  }
  if (params is null)
    params := inparams;

  oauth_consumer_key := get_keyword ('oauth_consumer_key', params);
  oauth_token := get_keyword ('oauth_token', params);
  oauth_signature_method := get_keyword ('oauth_signature_method', params);
  oauth_signature := get_keyword ('oauth_signature', params);
  oauth_timestamp := get_keyword ('oauth_timestamp', params);
  oauth_nonce := get_keyword ('oauth_nonce', params);
  oauth_version := get_keyword ('oauth_version', params, '1.0');
  oauth_client_ip := get_keyword ('oauth_client_ip', params, http_client_ip ());

  declare exit handler for not found {
    signal ('22023', 'Can\'t verify request, missing oauth_consumer_key or oauth_token');
  };

  declare exit handler for sqlstate '*' {
    resignal;
  };
  select a_secret, a_id, U_NAME, a_name
    into app_sec, app_id, uname, app_name
    from OAUTH..APP_REG, DB.DBA.SYS_USERS
   where a_owner = U_ID and a_key = oauth_consumer_key;

  if (exists (select 1 from OAUTH..SESSIONS where s_nonce = oauth_nonce))
    signal ('42000', 'OAuth Verification Failed');

  if (app_inst <> app_name)
    signal ('42000', 'OAuth Verification Failed');

  declare exit handler for not found {
    signal ('42000', 'OAuth Verification Failed');
  };

  select s_access_secret into req_sec from OAUTH..SESSIONS where s_access_key = oauth_token and s_ip = oauth_client_ip and s_state = 3;

  url := get_requested_url ();
  lines := http_request_header ();
  params := http_request_get ('QUERY_STRING');
  meth := http_request_get ('REQUEST_METHOD');

  if (not OAUTH..check_signature (oauth_signature_method, oauth_signature, meth, url, params, lines, app_sec, req_sec))
  {
    signal ('42000', 'OAuth Verification Failed: Bad Signature');
  }
  return 1;
}
;

create procedure OAUTH..get_auth_token (in sid varchar) __SOAP_HTTP 'text/plain'
{
  if (sid is null)
    return null;
  return (select cs_token from OAUTH..CLI_SESSIONS where cs_sid = sid);
}
;

create procedure OAUTH..get_consumer_key (in sid varchar) __SOAP_HTTP 'text/plain'
{
  if (sid is null)
    return null;
  return (select cs_key from OAUTH..CLI_SESSIONS where cs_sid = sid);
}
;

create procedure OAUTH..set_session_data (in sid varchar := null, in data any)
{
  if (sid is null)
    return;
  update OAUTH..CLI_SESSIONS set cs_user_data = data where cs_sid = sid;
}
;

create procedure OAUTH..get_session_data (in sid varchar)
{
  if (sid is null)
    return;
  return (select cs_user_data from OAUTH..CLI_SESSIONS where cs_sid = sid);
}
;

create procedure OAUTH..session_terminate (in sid varchar) __SOAP_HTTP 'text/plain'
{
  delete from OAUTH..CLI_SESSIONS where cs_sid = sid;
}
;

create procedure OAUTH..parse_response (in sid any := null, in consumer_key varchar, in ret any)  __SOAP_HTTP 'text/plain'
{
  declare oauth_token, oauth_secret varchar;
  declare tmp, data, client any;

  if (sid is not null)
  {
    data := OAUTH..get_session_data (sid);
    delete from OAUTH..CLI_SESSIONS where cs_sid = sid;
  }
  tmp := split_and_decode (ret);
  oauth_token := get_keyword ('oauth_token', tmp);
  oauth_secret := get_keyword ('oauth_token_secret', tmp);
  if (oauth_token is null or oauth_secret is null)
    signal ('OAUTH', ret);
  client := coalesce (connection_get ('client_ip'), client_attr ('client_ip'));
  if (sid is null)
    sid := md5 (concat (datestring (now ()), client));
  insert into OAUTH..CLI_SESSIONS (cs_sid, cs_key, cs_token, cs_secret, cs_ip, cs_user_data)
    values (sid, consumer_key, oauth_token, oauth_secret, client, data);
  return sid;
}
;

create procedure OAUTH..sign_request (in meth varchar := 'GET', in url varchar, in params varchar := '', in consumer_key varchar, in sid varchar := null, in tz int := 0) __SOAP_HTTP 'text/plain'
{
  declare signature, timest, nonce varchar;
  declare ret varchar;
  declare consumer_secret, oauth_token, oauth_secret varchar;

  nonce := xenc_rand_bytes (8, 1);
  timest := datediff ('second', stringdate ('1970-1-1'), now ());
  if (tz)
    timest := timest - timezone (now()) * 60; 
  if (length (params) and params not like '%&')
    params := params || '&';

  params := params ||
            sprintf ('oauth_consumer_key=%s&oauth_signature_method=HMAC-SHA1&oauth_timestamp=%d&oauth_nonce=%s&oauth_version=1.0',
                  	 consumer_key,
                 		 timest,
                 		 nonce);
  oauth_token := get_auth_token (sid);
  if (length (oauth_token))
    params := params || sprintf ('&oauth_token=%s', oauth_token);
  url := OAUTH..normalize_url (url, vector ());
  params := OAUTH..normalize_params (params);

  declare exit handler for not found {signal ('OAUTH', 'Cannot find secret');};
  select a_secret into consumer_secret from OAUTH..APP_REG where a_key = consumer_key;
  oauth_secret := '';
  if (length (sid))
    select cs_token, cs_secret into oauth_token, oauth_secret from OAUTH..CLI_SESSIONS where cs_sid = sid;
  signature := OAUTH..sign_hmac_sha1 (meth, url, params, consumer_secret, oauth_secret);
  if (meth = 'GET')
    ret := url||'?'||params||'&oauth_signature='||sprintf ('%U', signature);
  else
    ret := params||'&oauth_signature='||sprintf ('%U', signature);
  return ret;
}
;

create procedure OAUTH..signed_request_header (in meth varchar := 'GET', in url varchar, in params varchar := '', in consumer_key varchar, in oauth_secret varchar := '', in sid varchar := null, in tz int := 0) __SOAP_HTTP 'text/plain'
{
  declare signature, timest, nonce varchar;
  declare ret varchar;
  declare consumer_secret, oauth_token varchar;
  declare inx int;
  declare arr, hf any;

  nonce := xenc_rand_bytes (8, 1);
  timest := datediff ('second', stringdate ('1970-1-1'), now ()) - (timezone (now()) * 60);
  if (tz)
    timest := timest - timezone (now()) * 60; 
  if (length (params) and params not like '%&')
    params := params || '&';

  params := params ||
            sprintf ('oauth_consumer_key=%s&oauth_signature_method=HMAC-SHA1&oauth_timestamp=%ld&oauth_nonce=%s&oauth_version=1.0',
                  	 consumer_key,
                 		 timest,
                 		 nonce);
  oauth_token := get_auth_token (sid);
  if (length (oauth_token))
    params := params || sprintf ('&oauth_token=%s', oauth_token);
  hf := rfc1808_parse_uri (url);
  if (hf[4] <> '')
    params := hf[4] || '&' || params;
  params := OAUTH..normalize_params (params);
  url := OAUTH..normalize_url (url, vector ());
  --dbg_obj_print (params);

  declare exit handler for not found {signal ('OAUTH', 'Cannot find secret');};
  select a_secret into consumer_secret from OAUTH..APP_REG where a_key = consumer_key;
  if (length (sid))
    select cs_token, cs_secret into oauth_token, oauth_secret from OAUTH..CLI_SESSIONS where cs_sid = sid;
  signature := OAUTH..sign_hmac_sha1 (meth, url, params, consumer_secret, oauth_secret);
  ret := params||'&oauth_signature='||sprintf ('%U', signature);
  arr := split_and_decode (ret, 0);
  ret := 'Authorization: OAuth';
  for (inx := 0; inx < length (arr); inx := inx + 2) 
     {
       if (arr[inx] like 'oauth_%')
	 ret := ret || ' ' || arr[inx] || '="' || sprintf ('%U', arr[inx+1]) || '"' || ','; 
     }
  ret := rtrim (ret, ',');   
  --dbg_obj_print (ret);
  return ret;
}
;

create procedure OAUTH..keys_request (in consumer varchar) __SOAP_HTTP 'text/plain'
{
  declare options varchar;

  options := '';
  for (select A_NAME, A_KEY from OAUTH..APP_REG, DB.DBA.SYS_USERS where A_OWNER = U_ID and U_NAME = consumer) do
  {
    options := options || sprintf ('<option value="%V">%V</option>', A_KEY, A_NAME);
  }
  return options;
}
;

grant execute on OAUTH..request_token to "OAuth";
grant execute on OAUTH..access_token to "OAuth";
grant execute on OAUTH..authorize to "OAuth";
grant execute on OAUTH..parse_response to "OAuth";
grant execute on OAUTH..sign_request to "OAuth";
grant execute on OAUTH..keys_request to "OAuth";

-- UI
create procedure
web_user_password_check (in name varchar, in pass varchar)
{
  declare rc int;
  if (length (name))
    {
      declare exit handler for sqlstate '*' {
	rollback work;
	return 0;
      };
      rc := DB.DBA.LDAP_LOGIN (name, null, vector ('authtype','basic','pass',pass));
      if (rc <> -1)
	{
          commit work;
	return rc;
    }
    }
  rc := 0;
  if (exists (select 1 from DB.DBA.SYS_USERS where U_NAME = name and U_DAV_ENABLE = 1 and U_IS_ROLE = 0 and
        pwd_magic_calc (U_NAME, U_PASSWORD, 1) = pass and U_ACCOUNT_DISABLED = 0))
    {
      update WS.WS.SYS_DAV_USER set U_LOGIN_TIME = now () where U_NAME = name
	  and (U_LOGIN_TIME is null or U_LOGIN_TIME < dateadd ('minute', -2, now ()));
      rc := 1;
    }
  commit work;
  return rc;
}
;

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
WA_USER_OAUTH_UPGRADE ();

