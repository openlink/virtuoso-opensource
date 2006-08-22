--
--  $Id$
--
--  OpenID protocol support.
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


use OPENID;

DB.DBA.wa_exec_no_error_log (
'create table SERVER_SESSIONS
(
 SS_HANDLE varchar,
 SS_KEY_NAME varchar,
 SS_KEY varbinary,
 SS_KEY_TYPE varchar,
 SS_EXPIRY datetime,
 primary key (SS_HANDLE)
)');

insert soft "DB"."DBA"."SYS_SCHEDULED_EVENT" (SE_INTERVAL, SE_LAST_COMPLETED, SE_NAME, SE_SQL, SE_START)
  values (10, NULL, 'OPENID_SESSION_EXPIRE', 'delete from OPENID.DBA.SERVER_SESSIONS where SS_EXPIRY < now ()', now());

create procedure OPENID_INIT ()
{
  if (exists (select 1 from "DB"."DBA"."SYS_USERS" where U_NAME = 'OpenID'))
    return;
  DB.DBA.USER_CREATE ('OpenID', uuid(), vector ('DISABLED', 1, 'LOGIN_QUALIFIER', 'OPENID'));
  DB.DBA.VHOST_REMOVE (lpath=>'/openid');
  DB.DBA.VHOST_DEFINE (lpath=>'/openid', ppath=>'/SOAP/Http/server', soap_user=>'OpenID');
}
;

OPENID_INIT ();

create procedure server
	(
	 in "openid.mode" varchar := 'unknown'
	)
	__SOAP_HTTP 'text/html'
{
  declare ret, lines, params, oid_sid, cookies_vec any;
  params := http_param ();
  lines := http_request_header ();

--  dbg_obj_print ('openid server lines=', lines);

  cookies_vec := DB.DBA.vsp_ua_get_cookie_vec (lines);
  oid_sid := get_keyword ('openid.sid', cookies_vec);

  if ("openid.mode" = 'associate')
    ret := associate (
    	get_keyword ('openid.assoc_type', params, 'HMAC-SHA1'),
    	get_keyword ('openid.session_type', params),
    	get_keyword ('openid.dh_modulus', params),
    	get_keyword ('openid.dh_gen', params),
    	get_keyword ('openid.dh_consumer_public', params));
  else if ("openid.mode" = 'checkid_immediate')
    ret := checkid_immediate (
    	get_keyword ('openid.identity', params),
    	get_keyword ('openid.assoc_handle', params),
    	get_keyword ('openid.return_to', params),
    	get_keyword ('openid.trust_root', params),
	oid_sid
	);
  else if ("openid.mode" = 'checkid_setup')
    ret := checkid_setup (
    	get_keyword ('openid.identity', params),
    	get_keyword ('openid.assoc_handle', params),
    	get_keyword ('openid.return_to', params),
    	get_keyword ('openid.trust_root', params),
	oid_sid
	);
  else if ("openid.mode" = 'check_authentication')
    ret := check_authentication (
    	get_keyword ('openid.assoc_handle', params),
    	get_keyword ('openid.sig', params),
    	get_keyword ('openid.signed', params),
    	get_keyword ('openid.invalidate_handle', params),
    	params,
	oid_sid);
  else
    ret := 'error:Unknown mode';
  return ret;
};

grant execute on server to "OpenID";

create procedure associate
    	(
	  in assoc_type varchar := 'HMAC-SHA1',
	  in session_type varchar := '',
	  in dh_modulus varchar := null,
	  in dh_gen varchar := null,
	  in dh_consumer_public varchar := null
	)
{
  declare assoc_handle, ses, ss_key, ss_key_data any;

  ses := string_output ();

  assoc_handle := md5 (datestring (now()));
  ss_key := 'OpenID_' || assoc_handle;
  xenc_key_3DES_rand_create (ss_key);
  ss_key_data := xenc_key_serialize (ss_key);
  insert into SERVER_SESSIONS (SS_HANDLE, SS_KEY_NAME, SS_KEY, SS_KEY_TYPE, SS_EXPIRY)
      values (assoc_handle, ss_key, ss_key_data, '3DES', dateadd ('hour', 1, now()));

  http (sprintf ('assoc_handle:%s\x0A', assoc_handle), ses);
  http ('assoc_type:HMAC-SHA1\x0A', ses);
  http (sprintf ('expires_in:%d\x0A', 60*60), ses);
  http (sprintf ('mac_key:%s\x0A', ss_key_data), ses);

  return string_output_string (ses);
};


create procedure checkid_immediate
	(
	 in _identity varchar,
	 in assoc_handle varchar := null,
	 in return_to varchar,
	 in trust_root varchar := null,
	 in sid varchar,
	 in flag int := 0 -- called via checkid_setup
    	)
{
  declare signature any;
  declare login varchar;

  if (trust_root is null)
    trust_root := _identity;

  if (length (_identity) = 0)
    return 'error:no_identity';
  if (length (return_to) = 0)
    return 'error:no_return_to';

--  dbg_obj_print ('checkid_immediate', sid);

  http_request_status ('HTTP/1.1 302 Found');
  if (not exists (select 1 from DB.DBA.VSPX_SESSION where VS_SID = sid and VS_REALM = 'wa'))
    {
      login := sprintf ('%s?return_to=%U&identity=%U&assoc_handle=%U&trust_root=%U',
	    DB.DBA.wa_link(1, 'login.vspx'), return_to, _identity, coalesce (assoc_handle, ''), trust_root);
      --dbg_obj_print (sprintf ('Location: %s?openid.mode=id_res&openid.user_setup_url=%U\r\n', return_to, login));
      http_header (http_header_get () || sprintf ('Location: %s?openid.mode=id_res&openid.user_setup_url=%U\r\n', return_to, login));
    }
  else
    {
      declare ses, ss_key, ss_key_data any;


      -- XXX should check is assoc_handle is valid !!!
      if (length (assoc_handle) and exists (select 1 from SERVER_SESSIONS where SS_HANDLE = assoc_handle))
	{
	  select SS_KEY_NAME into ss_key from SERVER_SESSIONS where SS_HANDLE = assoc_handle;
	}
      else
	{
	  assoc_handle := sid;
	  ss_key := 'OpenID_' || sid;
	  xenc_key_3DES_rand_create (ss_key);
	  ss_key_data := xenc_key_serialize (ss_key);
	  insert into SERVER_SESSIONS (SS_HANDLE, SS_KEY_NAME, SS_KEY, SS_KEY_TYPE, SS_EXPIRY)
	      values (assoc_handle, ss_key, ss_key_data, '3DES', dateadd ('hour', 1, now()));
	}

      ses := string_output ();

      http ('mode:id_res\x0A', ses);
      http (sprintf ('identity:%s\x0A', _identity), ses);
      http (sprintf ('return_to:%s\x0A', return_to), ses);

      set_user_id ('OpenID');

      signature := xenc_hmac_sha1_digest (string_output_string (ses), ss_key);
      if (length (assoc_handle) = 0)
	assoc_handle := '';
      http_header (http_header_get () || sprintf ('Location: %s?openid.mode=id_res&openid.identity=%U&openid.return_to=%U&openid.assoc_handle=%U&openid.signed=mode,identity,return_to&openid.sig=%U\r\n',
	    return_to, _identity, return_to, coalesce (assoc_handle, ''), signature));
      ;
    }
  return '';
};


create procedure checkid_setup
	(
	 in _identity varchar,
	 in assoc_handle varchar := null,
	 in return_to varchar,
	 in trust_root varchar := null,
	 in sid varchar
	 )
{
  if (not exists (select 1 from DB.DBA.VSPX_SESSION where VS_SID = sid and VS_REALM = 'wa'))
    {
      http_request_status ('HTTP/1.1 302 Found');
      http_header (http_header_get () || sprintf ('Location: %s?openid.mode=cancel\r\n', return_to));
      return;
    }
  return checkid_immediate (_identity, assoc_handle, return_to, trust_root, sid, 1);
};


create procedure check_authentication
	(
	  in assoc_handle varchar,
	  in sig varchar,
	  in signed varchar,
	  in invalidate_handle varchar := null,
	  in params any := null,
	  in sid varchar
	 )
{
  declare arr, ses, signature any;
  declare key_val, val, ss_key any;

  if (exists (select 1 from SERVER_SESSIONS where SS_HANDLE = assoc_handle))
    {
      select SS_KEY_NAME into ss_key from SERVER_SESSIONS where SS_HANDLE = assoc_handle;
    }
  else
    {
      http ('mode:id_res\x0Ais_valid:false\x0Ainvalidate_handle:'||assoc_handle||'\x0A');
      return '';
    }

  arr := split_and_decode (signed, 0, '\0\0,');
  ses := string_output ();
  foreach (any item in arr) do
    {
      key_val := 'openid.'||item;
      val := get_keyword (key_val, params, '');
      http (sprintf ('%s:%s\x0A',key_val,val), ses);
    }

  signature := xenc_hmac_sha1_digest (string_output_string (ses), ss_key);
  if (signature = sig)
    http ('mode:id_res\x0Ais_valid:true\x0A');
  else
    http ('mode:id_res\x0Ais_valid:false\x0A');


  return '';
};

use DB;
