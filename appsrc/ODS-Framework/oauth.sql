--
--  $Id$
--
--  OAuth protocol support.
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
use OAUTH;

-- Application registrations, via UI
DB.DBA.wa_exec_no_error_log(
'create table APP_REG (
    	a_id int identity,
	a_name varchar primary key,
	a_descr long varchar,
	a_url varchar,
	a_cb_url varchar,
	a_help_url varchar,
	a_key varchar,
	a_secret varchar,
	a_owner int
	)');
DB.DBA.wa_exec_no_error_log(
'create unique index APP_REG_K1 on APP_REG (a_key)');


-- OAuth sessions
DB.DBA.wa_exec_no_error_log(
'create table SESSIONS (
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
	primary key (s_req_key))');

db.dba.wa_add_col ('OAUTH.DBA.SESSIONS', 's_access_mode', 'int default 1');

create procedure app_register
(in aname varchar, in owner int)
{
  declare k, sec any;
  get_key_and_secret (k, sec);
  --k := 'key';
  --sec := 'secret';
  insert into APP_REG (a_name,a_key,a_secret,a_owner)
      values (aname, k, sec, owner);
  return identity_value ();
}
;

create procedure OAUTH_INIT ()
{
  if (exists (select 1 from "DB"."DBA"."SYS_USERS" where U_NAME = 'OAuth'))
    return;
  DB.DBA.USER_CREATE ('OAuth', uuid(), vector ('DISABLED', 1, 'LOGIN_QUALIFIER', 'OAUTH'));
}
;


DB.DBA.VHOST_REMOVE (lpath=>'/OAuth');
DB.DBA.VHOST_DEFINE (lpath=>'/OAuth', ppath=>'/SOAP/Http', soap_user=>'OAuth');


OAUTH_INIT ();

create procedure normalize_params (in params any)
{
  declare arr, newarr any;
  declare str varchar;
  arr := split_and_decode (params, 0, '%+&');
  arr := __vector_sort (arr);
  str := '';
  foreach (any elm in arr) do
    {
      if (elm not like 'oauth_signature=%')
	str := str || '&' || elm;
    }
  return ltrim (str, '&');
}
;

create procedure normalize_url (in url any, in lines any)
{
  declare hf any;
  hf := rfc1808_parse_uri (url);
  hf[0] := lower (hf[0]);
  hf[1] := lower (hf[1]);
  return sprintf ('%s://%s%s', hf[0], hf[1], hf[2]);
}
;


create procedure sign_hmac_sha1
(in meth varchar, in url varchar, in params varchar, in consumer_secret varchar, in token_secret varchar)
{
  declare str, k, kname, ret varchar;
  str := meth || '&' || replace (sprintf ('%U', url), '/', '%2F') || '&' || sprintf ('%U', params);
--  dbg_obj_print ('str=',str);
  k := sprintf ('%U', consumer_secret) || '&' || sprintf ('%U', token_secret);
  kname := md5 (cast (now () as varchar));
  xenc_key_RAW_read (kname, encode_base64 (k));
  ret := xenc_hmac_sha1_digest (str, kname);
  xenc_key_remove (kname);
  return ret;
}
;

create procedure sign_plaintext
(in meth varchar, in url varchar, in params varchar, in consumer_secret varchar, in token_secret varchar)
{
  return sprintf ('%U', consumer_secret||'&'||token_secret);
}
;

create procedure check_signature
(in algo varchar, in sig varchar,
 in meth varchar, in url varchar, in params varchar, in lines any,  in consumer_secret varchar, in token_secret varchar)
{
  declare c_sig varchar;
  url := normalize_url (url, lines);
  params := normalize_params (params);
  if (algo = 'HMAC-SHA1')
    c_sig := sign_hmac_sha1 (meth, url, params, consumer_secret, token_secret);
  else
    c_sig := sign_plaintext (meth, url, params, consumer_secret, token_secret);

--  dbg_obj_print ('algo=', algo);
--  dbg_obj_print ('sig=', sig, ' calculated=', c_sig);
--  dbg_obj_print ('meth=', meth);
--  dbg_obj_print ('url=', url);
--  dbg_obj_print ('params=', params);
--  dbg_obj_print ('consumer_secret=', consumer_secret);
--  dbg_obj_print ('token_secret=', token_secret);

  if (sig = c_sig)
    return 1;
  return 0;
}
;

create procedure get_req_url (in path varchar, in lines any)
{
  return;
}
;

create procedure get_key_and_secret (out k any, out s any)
{
  k := xenc_rand_bytes (20, 1);
  s := xenc_rand_bytes (16, 1);
}
;

create procedure request_token (
    in oauth_consumer_key varchar,
    in oauth_signature_method varchar,
    in oauth_signature varchar,
    in oauth_timestamp varchar,
    in oauth_nonce varchar,
    in oauth_version varchar := '1.0'
    )
    --__SOAP_HTTP 'application/x-www-form-urlencoded'
    __SOAP_HTTP 'text/plain'
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
  select a_secret, a_id into app_sec, app_id from APP_REG where a_key = oauth_consumer_key;

  if (exists (select 1 from SESSIONS where s_nonce = oauth_nonce))
    {
      http_header ('Content-Type: text/plain\r\n');
      return 'OAuth Verification Failed\n';
    }

  url := http_requested_url ();
  lines := http_request_header ();
  params := http_request_get ('QUERY_STRING');
  meth := http_request_get ('REQUEST_METHOD');

  if (not check_signature (oauth_signature_method, oauth_signature, meth, url, params, lines, app_sec, ''))
    {
      http_header ('Content-Type: text/plain\r\n');
      return 'OAuth Verification Failed: bad signature\n';
    }

  get_key_and_secret (tok, sec);
  --tok := 'requestkey';
  --sec := 'requestsecret';

  insert into SESSIONS (s_nonce, s_timestamp, s_req_key, s_req_secret, s_a_id, s_method, s_state, s_ip)
      values (oauth_nonce, oauth_timestamp, tok, sec, app_id, meth, 1, http_client_ip ());
  commit work;
  ret := sprintf ('oauth_token=%U&oauth_token_secret=%U', tok, sec);
  return ret;
}
;

create procedure access_token (
    in oauth_consumer_key varchar,
    in oauth_token varchar,
    in oauth_signature_method varchar,
    in oauth_signature varchar,
    in oauth_timestamp varchar,
    in oauth_nonce varchar,
    in oauth_version varchar := '1.0'
    )
    --__SOAP_HTTP 'application/x-www-form-urlencoded'
    __SOAP_HTTP 'text/plain'
{
  declare ret, tok, sec varchar;
  declare sid, app_sec, url, meth, params, cookie, req_sec varchar;
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
  select a_secret, a_id into app_sec, app_id from APP_REG where a_key = oauth_consumer_key;

  if (exists (select 1 from SESSIONS where s_nonce = oauth_nonce))
    {
      http_header ('Content-Type: text/plain\r\n');
      return 'OAuth Verification Failed\n';
    }

  declare exit handler for not found {
    http_header ('Content-Type: text/plain\r\n');
    return 'OAuth Verification Failed\n';
  };

  select s_req_secret into req_sec from SESSIONS where s_req_key = oauth_token and s_ip = http_client_ip () and s_state = 2;

  url := http_requested_url ();
  lines := http_request_header ();
  params := http_request_get ('QUERY_STRING');
  meth := http_request_get ('REQUEST_METHOD');

  if (not check_signature (oauth_signature_method, oauth_signature, meth, url, params, lines, app_sec, req_sec))
    {
      http_header ('Content-Type: text/plain\r\n');
      return 'OAuth Verification Failed: bad signature\n';
    }

  get_key_and_secret (tok, sec);
  --tok := 'accesskey';
  --sec := 'accesssecret';

  update SESSIONS set s_nonce = oauth_nonce, s_timestamp = oauth_timestamp, s_access_key = tok, s_access_secret = sec, s_state = 3
      where s_req_key = oauth_token and s_ip = http_client_ip () and s_state = 2;

  ret := sprintf ('oauth_token=%U&oauth_token_secret=%U', tok, sec);
  return ret;
}
;

create procedure authorize (
    in oauth_token varchar,
    in oauth_callback varchar
    )
    __SOAP_HTTP 'text/plain'
{
  declare url any;
  if (not exists (select 1 from SESSIONS where s_req_key = oauth_token and s_ip = http_client_ip () and s_state = 1))
    {
      http_header ('Content-Type: text/plain\r\n');
      return 'OAuth Verification Failed\n';
    }
  url := sprintf ('/ods/oauth_authorize.vspx?token=%U&cb=%U', oauth_token, oauth_callback);
  http_status_set (301);
  http_header (sprintf ('Location: %s\r\n', url));
  return '';
}
;

create procedure check_authentication_safe (in inparams any := null, in lines any := null)
{
  if (inparams is null)
    inparams := http_param ();
  if (lines is null)
    lines := http_request_header ();
  declare exit handler for sqlstate '*' {
    return 0;
  };
  return check_authentication (inparams, lines);
}
;

create procedure check_authentication (in inparams any, in lines any)
{
  declare oauth_consumer_key varchar;
  declare oauth_token varchar;
  declare oauth_signature_method varchar;
  declare oauth_signature varchar;
  declare oauth_timestamp varchar;
  declare oauth_nonce varchar;
  declare oauth_version varchar;

  declare ret, tok, sec, ahead, params varchar;
  declare sid, app_sec, url, meth, cookie, req_sec varchar;
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

  declare exit handler for not found {
    signal ('22023', 'Can\'t verify request, missing oauth_consumer_key or oauth_token');
  };

  declare exit handler for sqlstate '*' {
    resignal;
  };
  select a_secret, a_id into app_sec, app_id from APP_REG where a_key = oauth_consumer_key;

  if (exists (select 1 from SESSIONS where s_nonce = oauth_nonce))
    {
      signal ('42000', 'OAuth Verification Failed');
    }

  declare exit handler for not found {
    signal ('42000', 'OAuth Verification Failed');
  };

  select s_access_secret into req_sec from SESSIONS where s_access_key = oauth_token and s_ip = http_client_ip () and s_state = 3;

  url := http_requested_url ();
  lines := http_request_header ();
  params := http_request_get ('QUERY_STRING');
  meth := http_request_get ('REQUEST_METHOD');

  if (not check_signature (oauth_signature_method, oauth_signature, meth, url, params, lines, app_sec, req_sec))
    {
      signal ('42000', 'OAuth Verification Failed: bad signature');
    }

  update SESSIONS set s_nonce = oauth_nonce, s_timestamp = oauth_timestamp
      where s_access_key = oauth_token and s_ip = http_client_ip () and s_state = 2;

  return 1;
}
;

grant execute on request_token to "OAuth";
grant execute on access_token to "OAuth";
grant execute on authorize to "OAuth";

use DB;
