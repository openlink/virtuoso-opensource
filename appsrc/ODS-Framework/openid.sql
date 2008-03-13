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
 SS_ASSOCIATION_TYPE varchar,
 SS_SESSION_TYPE varchar,
 primary key (SS_HANDLE)
)');

DB.DBA.wa_add_col ('OPENID.DBA.SERVER_SESSIONS', 'SS_ASSOCIATION_TYPE', 'varchar');
DB.DBA.wa_add_col ('OPENID.DBA.SERVER_SESSIONS', 'SS_SESSION_TYPE', 'varchar');

insert soft "DB"."DBA"."SYS_SCHEDULED_EVENT" (SE_INTERVAL, SE_LAST_COMPLETED, SE_NAME, SE_SQL, SE_START)
  values (10, NULL, 'OPENID_SESSION_EXPIRE', 'delete from OPENID.DBA.SERVER_SESSIONS where SS_EXPIRY < now ()', now());

create procedure OPENID_INIT ()
{
  if (exists (select 1 from "DB"."DBA"."SYS_USERS" where U_NAME = 'OpenID'))
    return;
  DB.DBA.USER_CREATE ('OpenID', uuid(), vector ('DISABLED', 1, 'LOGIN_QUALIFIER', 'OPENID'));
}
;

OPENID_INIT ();

create procedure yadis (in uname varchar, in tp varchar := null)
{
  declare url, srv varchar;
  if (tp not in ('person/', 'organization/'))
    tp := '';
  url := db.dba.wa_link (1, '/dataspace/'||tp||uname);
  srv := db.dba.wa_link (1, '/openid');
  for select WAUI_OPENID_URL, WAUI_OPENID_SERVER, WAUI_NICK
    from DB.DBA.WA_USER_INFO, DB.DBA.SYS_USERS where WAUI_U_ID = U_ID and U_NAME = uname
    do
      {
	if (length (WAUI_OPENID_URL) * length (WAUI_OPENID_SERVER))
	  {
	    url := WAUI_OPENID_URL;
	    srv := WAUI_OPENID_SERVER;
	  }
	else if (uname <> WAUI_NICK)
	  url := db.dba.wa_link (1, '/dataspace/'||tp||WAUI_NICK);

      }
  http ('<?xml version="1.0" encoding="UTF-8"?>\n');
  http ('<xrds:XRDS \n');
  http ('  xmlns:xrds="xri://\044xrds" \n');
  http ('  xmlns:openid="http://openid.net/xmlns/1.0"   \n');
  http ('  xmlns="xri://\044xrd*(\044v*2.0)">\n');
  http ('  <XRD>\n');
  if (1)
    {
  http ('    <Service priority="0">\n');
  http ('      <Type>http://specs.openid.net/auth/2.0/signon</Type>\n');
  http ('      <Type>http://openid.net/sreg/1.0</Type>\n');
  http (sprintf ('      <URI>%V</URI>\n', srv));
  http (sprintf ('      <LocalID>%V</LocalID>\n', url));
  http ('    </Service>\n');
    }
  http ('    <Service priority="1">\n');
  http ('      <Type>http://openid.net/signon/1.0</Type>\n');
  http ('      <Type>http://openid.net/sreg/1.0</Type>\n');
  http (sprintf ('      <URI>%V</URI>\n', srv));
  http (sprintf ('      <openid:Delegate>%V</openid:Delegate>\n', url));
  http ('    </Service>\n');
  http ('  </XRD>\n');
  http ('</xrds:XRDS>\n');
};

create procedure ns_v2 ()
{
  return 'http://specs.openid.net/auth/2.0';
}
;

create procedure sreg_ns_v1 ()
{
  return 'http://openid.net/extensions/sreg/1.1';
}
;
create procedure server
	(
	 in "openid.mode" varchar := 'unknown'
	)
	__SOAP_HTTP 'text/html'
{
  declare ret, lines, params, oid_sid, cookies_vec any;
  declare ns varchar;
  declare ver int;

  params := http_param ();
  lines := http_request_header ();
--  dbg_obj_print ('req:', lines[0]);
--  dbg_obj_print ('=====================================');
--  dbg_obj_print (user, ' ', "openid.mode", ' openid server params=', params);

  cookies_vec := DB.DBA.vsp_ua_get_cookie_vec (lines);
  oid_sid := get_keyword ('openid.sid', cookies_vec);
  ns := get_keyword ('openid.ns', params, 'http://openid.net/signon/1.1');

  if (ns = ns_v2 ())
    ver := 2;
  else
    ver := 1;

  if ("openid.mode" = 'associate')
    ret := associate (ver,
    	get_keyword ('openid.assoc_type', params, 'HMAC-SHA1'),
    	get_keyword ('openid.session_type', params),
    	get_keyword ('openid.dh_modulus', params),
    	get_keyword ('openid.dh_gen', params),
    	get_keyword ('openid.dh_consumer_public', params));
  else if ("openid.mode" = 'checkid_immediate')
    ret := checkid_immediate (
    	ver,
    	get_keyword ('openid.identity', params),
    	get_keyword ('openid.assoc_handle', params),
    	get_keyword ('openid.return_to', params),
    	get_keyword ('openid.trust_root', params),
	oid_sid,
	0,
	get_keyword ('openid.sreg.required', params),
	get_keyword ('openid.sreg.optional', params),
	get_keyword ('openid.sreg.policy_url', params)
	);
  else if ("openid.mode" = 'checkid_setup')
    ret := checkid_setup (
    	ver,
    	get_keyword ('openid.identity', params),
    	get_keyword ('openid.assoc_handle', params),
    	get_keyword ('openid.return_to', params),
    	get_keyword ('openid.trust_root', params),
	oid_sid,
	get_keyword ('openid.sreg.required', params),
	get_keyword ('openid.sreg.optional', params),
	get_keyword ('openid.sreg.policy_url', params)
	);
  else if ("openid.mode" = 'check_authentication')
    ret := check_authentication (
    	ver,
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
          in ver int := 1,
	  in assoc_type varchar := 'HMAC-SHA1',
	  in session_type varchar := '',
	  in dh_modulus varchar := null,
	  in dh_gen varchar := null,
	  in dh_consumer_public varchar := null
	)
{
  declare assoc_handle, ses, ss_key, ss_key_data any;
  declare sha_ver int;

  ses := string_output ();

  assoc_handle := md5 (datestring (now()));
  ss_key := 'OpenID_' || assoc_handle;
  xenc_key_3DES_rand_create (ss_key);
  ss_key_data := xenc_key_serialize (ss_key);
  insert into SERVER_SESSIONS (SS_HANDLE, SS_KEY_NAME, SS_KEY, SS_KEY_TYPE, SS_EXPIRY, SS_ASSOCIATION_TYPE, SS_SESSION_TYPE)
      values (assoc_handle, ss_key, ss_key_data, '3DES', dateadd ('hour', 1, now()), assoc_type, session_type);

  if (assoc_type not in ('HMAC-SHA1', 'HMAC-SHA256'))
    signal ('22023', 'Not supported assoc_type '||assoc_type);

  if (__proc_exists ('xenc_sha256_digest',2) is null and assoc_type = 'HMAC-SHA256')
    signal ('22023', 'Not supported assoc_type '||assoc_type);

  if (ver = 2)
    http (sprintf ('ns:%s\x0A', ns_v2 ()), ses);
  http (sprintf ('assoc_handle:%s\x0A', assoc_handle), ses);
  http (sprintf ('assoc_type:%s\x0A', assoc_type), ses);
  http (sprintf ('expires_in:%d\x0A', 60*60), ses);

  if (length (session_type) = 0)
    {
      http (sprintf ('mac_key:%s\x0A', ss_key_data), ses);
    }
  else if (session_type = 'DH-SHA1')
    {
      declare dh_key varchar;
      declare p, g, pub, sec, enc_sec, sha1_sec, bin_key any;
      dh_key := 'OpenID_DH_'||assoc_handle;
      if (not xenc_key_exists (dh_key))
	{
	  if (dh_modulus is null)
	    p := encode_base64 (dh_defaut_p ());
	  else
	    p := dh_modulus;
	  if (dh_gen is null)
	    g := 2;
	  else
            g := aref(decode_base64(dh_gen), 0);
	  xenc_key_DH_create (dh_key, g, p);
	}
      pub := xenc_DH_get_params (dh_key, 3);
      sec := xenc_DH_compute_key (dh_key, dh_consumer_public);
--      dbg_obj_print ('================');
--      dbg_obj_print ('sec=',sec);

      if (decode_base64 (sec)[0] > 127)
	sha1_sec := xenc_sha1_digest ('\x0'||decode_base64 (sec));
      else
	sha1_sec := xenc_sha1_digest (decode_base64 (sec));
--      dbg_obj_print ('sha1_sec=',sha1_sec);

      bin_key := substring (decode_base64 (ss_key_data), 1, 20);
      bin_key := encode_base64 (bin_key);
      xenc_key_remove (ss_key);
--      dbg_obj_print (ss_key, bin_key);
      xenc_key_RAW_read (ss_key, bin_key);
      update SERVER_SESSIONS set SS_KEY = bin_key, SS_KEY_TYPE = 'RAW' where SS_HANDLE = assoc_handle;
--      dbg_obj_print (sha1_sec, bin_key);
      enc_sec := xenc_xor (sha1_sec, bin_key);
--      dbg_obj_print ('enc_sec=',enc_sec);
--      dbg_obj_print ('bin_key=',bin_key);
--      dbg_obj_print ('================');

      if (decode_base64 (pub)[0] > 127)
	{
          pub := concat ('\x0', decode_base64 (pub));
	  pub := encode_base64 (pub);
	  pub := replace (pub, '\r\n', '');
	}
      http (sprintf ('dh_server_public:%s\x0A', pub), ses);
      http (sprintf ('enc_mac_key:%s\x0A', enc_sec), ses);
      http ('session_type:DH-SHA1\x0A', ses);
--      dbg_obj_print (string_output_string (ses));
    }
  else if (session_type = 'DH-SHA256' and __proc_exists ('xenc_sha256_digest',2) is not null)
    {
      declare dh_key varchar;
      declare p, g, pub, sec, enc_sec, sha256_sec, bin_key any;
      dh_key := 'OpenID_DH_'||assoc_handle;
      if (not xenc_key_exists (dh_key))
	{
	  if (dh_modulus is null)
	    p := encode_base64 (dh_defaut_p ());
	  else
	    p := dh_modulus;
	  if (dh_gen is null)
	    g := 2;
	  else
            g := aref(decode_base64(dh_gen), 0);
	  xenc_key_DH_create (dh_key, g, p);
	}
      pub := xenc_DH_get_params (dh_key, 3);
      sec := xenc_DH_compute_key (dh_key, dh_consumer_public);
--      dbg_obj_print ('================');
--      dbg_obj_print ('sec=',sec);

      if (decode_base64 (sec)[0] > 127)
	sha256_sec := xenc_sha256_digest ('\x0'||decode_base64 (sec));
      else
	sha256_sec := xenc_sha256_digest (decode_base64 (sec));
--      dbg_obj_print ('sha1_sec=',sha1_sec);

      xenc_key_remove (ss_key);
      xenc_key_RAW_rand_create (ss_key, 32);
      bin_key := xenc_key_serialize (ss_key);
--      dbg_obj_print (ss_key, bin_key);
      update SERVER_SESSIONS set SS_KEY = bin_key, SS_KEY_TYPE = 'RAW' where SS_HANDLE = assoc_handle;
--      dbg_obj_print (sha1_sec, bin_key);
      enc_sec := xenc_xor (sha256_sec, bin_key);
--      dbg_obj_print ('enc_sec=',enc_sec);
--      dbg_obj_print ('bin_key=',bin_key);
--      dbg_obj_print ('================');

      if (decode_base64 (pub)[0] > 127)
	{
          pub := concat ('\x0', decode_base64 (pub));
	  pub := encode_base64 (pub);
	  pub := replace (pub, '\r\n', '');
	}
      http (sprintf ('dh_server_public:%s\x0A', pub), ses);
      http (sprintf ('enc_mac_key:%s\x0A', enc_sec), ses);
      http ('session_type:DH-SHA256\x0A', ses);
--      dbg_obj_print (string_output_string (ses));
    }
  else
    signal ('22023', 'Session type '||session_type||' is not supported');

  return string_output_string (ses);
};


create procedure checkid_immediate
	(
	 in ver int := 1,
	 in _identity varchar,
	 in assoc_handle varchar := null,
	 in return_to varchar,
	 in trust_root varchar := null,
	 in sid varchar,
	 in flag int := 0, -- called via checkid_setup
	 in sreg_required varchar := null,
	 in sreg_optional varchar := null,
	 in policy_url varchar := null
    	)
{
  declare signature, rhf, delim any;
  declare login, hdr, usr, ns, ns_sign varchar;

  if (trust_root is null)
    trust_root := _identity;

  if (length (_identity) = 0)
    return 'error:no_identity';
  if (length (return_to) = 0)
    return 'error:no_return_to';

--  dbg_obj_print ('checkid_immediate', sid, ' ver ', ver);
  ns := '';
  ns_sign := '';
  if (isstring (ver))
    ver := atoi (ver);
  if (ver = 2)
    {
      ns := sprintf ('&openid.ns=%U', ns_v2 ());
    }

  http_request_status ('HTTP/1.1 302 Found');
  if (not exists (select 1 from DB.DBA.VSPX_SESSION where VS_SID = sid and VS_REALM = 'wa'))
    {
      auth:
      rhf := WS.WS.PARSE_URI (return_to);
      if (rhf[4] <> '')
	delim := '&';
      else
        delim := '?';
      login :=
      sprintf ('%s?return_to=%U&identity=%U&assoc_handle=%U&trust_root=%U&sreg_required=%U&sreg_optional=%U&policy_url=%U&ver=%d',
	    DB.DBA.wa_link(1, 'openid_login.vspx'), return_to, _identity, coalesce (assoc_handle, ''), trust_root,
	    coalesce (sreg_required, ''), coalesce (sreg_optional, ''), coalesce (policy_url, ''), ver);
      --dbg_obj_print (sprintf ('Location: %s?openid.mode=id_res&openid.user_setup_url=%U\r\n', return_to, login));
      http_header (http_header_get () || sprintf ('Location: %s%sopenid.mode=id_res%s&openid.user_setup_url=%U\r\n',
	    return_to, delim, ns, login));
    }
  else
    {
      declare ses, ss_key, ss_key_data, inv, sreg, sarr, svec, sregf, algo any;
      declare nickname, email, fullname, dob, gender, postcode, country, lang, timezone any;

      algo := null;
      whenever not found goto auth;
      select WAUI_NICK, U_E_MAIL, U_FULL_NAME, WAUI_BIRTHDAY, WAUI_GENDER, WAUI_HCODE, WAUI_HCOUNTRY, WAUI_HTZONE
	 into nickname, email, fullname, dob, gender, postcode, country, timezone
	 from DB.DBA.SYS_USERS, DB.DBA.WA_USER_INFO, DB.DBA.VSPX_SESSION where
	 WAUI_U_ID = U_ID and U_NAME = VS_UID and VS_SID = sid and VS_REALM = 'wa';

      if (dob is not null)
	dob := substring (datestring (dob), 1, 10);

      if (gender = 'male')
        gender := 'M';
      else if (gender = 'female')
        gender := 'F';
      else
        gender := null;

      if (length (country))
        country := (select WC_ISO_CODE from DB.DBA.WA_COUNTRY where WC_NAME = country);

      svec := vector (
      			'nickname', nickname,
			'email', email,
			'fullname', fullname,
			'dob', dob,
			'gender', gender,
			'postcode', postcode,
			'country', country,
			'language', 'en',
			'timezone', null -- until fix the format
		    );

      -- XXX should check is assoc_handle is valid !!!
      inv := '';
      if (length (assoc_handle) and exists (select 1 from SERVER_SESSIONS where SS_HANDLE = assoc_handle))
	{
	  declare key_data, ktype any;
	  select SS_KEY_NAME, SS_KEY, SS_KEY_TYPE, SS_ASSOCIATION_TYPE
	      into ss_key, key_data, ktype, algo from SERVER_SESSIONS where SS_HANDLE = assoc_handle;
	  if (user <> 'OpenID')
	    set_user_id ('OpenID');
	  if (not xenc_key_exists (ss_key))
	    {
	      key_data := cast (key_data as varchar);
	      if (ktype = '3DES')
		xenc_key_3DES_read (ss_key, key_data);
              else
		xenc_key_RAW_read (ss_key, key_data);
	    }
	}
      else
	{
	  if (length (assoc_handle))
	    {
	      inv := sprintf ('&openid.invalidate_handle=%U', assoc_handle);
	    }
	  assoc_handle := sid; --md5 (http_client_ip () || cast (msec_time () as varchar));
	  ss_key := 'OpenID_' || assoc_handle;
	  if (user <> 'OpenID')
  	    set_user_id ('OpenID');
	  --if (xenc_key_exists (ss_key))
	  --xenc_key_remove (ss_key);

	  if (not xenc_key_exists (ss_key))
	    {
	      xenc_key_3DES_rand_create (ss_key);
	    }
	  ss_key_data := xenc_key_serialize (ss_key);
	  --set_user_id ('dba');
	  if (not exists (select 1 from SERVER_SESSIONS where SS_HANDLE = assoc_handle))
	    {
	      insert into SERVER_SESSIONS (SS_HANDLE, SS_KEY_NAME, SS_KEY, SS_KEY_TYPE, SS_EXPIRY)
		  values (assoc_handle, ss_key, ss_key_data, '3DES', dateadd ('hour', 1, now()));
	    }
	}

      rhf := WS.WS.PARSE_URI (return_to);
      if (rhf[4] <> '')
	delim := '&';
      else
        delim := '?';

--      dbg_obj_print ('sreg_required',sreg_required);
--      dbg_obj_print ('sreg_optional',sreg_optional);

      sarr := split_and_decode (sreg_required||','||sreg_optional, 0, '\0\0,');
      sreg := '';
      sregf := '';

      ses := string_output ();

      if (ver = 2)
	{
	  declare op, nonce varchar;
	  op := db.dba.wa_link (1, '/openid');
	  nonce := DB.DBA.date_iso8601 (dt_set_tz (curdatetime (0), 0)) || cast (msec_time () as varchar);
	  ns := sprintf ('&openid.ns=%U&openid.ns.sreg=%U&openid.op_endpoint=%U&openid.response_nonce=%U&openid.claimed_id=%U',
	  ns_v2 (), sreg_ns_v1 (), op, nonce, _identity);
	  ns_sign := 'ns,op_endpoint,response_nonce,claimed_id';
	  ns_sign := ns_sign || ',';
	  http (sprintf ('ns:%s\x0A', ns_v2 ()), ses);
	  http (sprintf ('op_endpoint:%s\x0A', op), ses);
	  http (sprintf ('response_nonce:%s\x0A', nonce), ses);
	  http (sprintf ('claimed_id:%s\x0A', _identity), ses);
	}
      http ('mode:id_res\x0A', ses);
      http (sprintf ('identity:%s\x0A', _identity), ses);
      http (sprintf ('return_to:%s\x0A', return_to), ses);
      http (sprintf ('assoc_handle:%s\x0A', assoc_handle), ses);

      foreach (any elm in sarr) do
	{
	  elm := trim(elm);
	  if (length (elm))
	    {
	      declare val any;
	      val := get_keyword (elm, svec, '');
	      if (length (val))
		{
		  sregf := sregf || ',sreg.' || elm;
		  sreg := sreg || '&openid.sreg.'||elm||'='||sprintf ('%U', val);
		  http (sprintf ('sreg.%s:%s\x0A', elm, val), ses);
		}
	    }
	}


      if (user <> 'OpenID')
        set_user_id ('OpenID');

--      dbg_obj_print (ss_key, string_output_string (ses));
      if (algo = 'HMAC-SHA256')
	signature := xenc_hmac_sha256_digest (string_output_string (ses), ss_key);
      else
	signature := xenc_hmac_sha1_digest (string_output_string (ses), ss_key);
--      dbg_obj_print (signature);
      if (length (assoc_handle) = 0)
	assoc_handle := '';
      hdr :=  sprintf ('Location: %s%sopenid.mode=id_res%s&openid.identity=%U&openid.return_to=%U'||
      			'&openid.assoc_handle=%U&openid.signed=%U&openid.sig=%U%s%s\r\n',
	    		return_to, delim, ns, _identity, return_to, coalesce (assoc_handle, ''),
			ns_sign||'mode,identity,return_to,assoc_handle'||sregf, signature, inv, sreg);
--      dbg_obj_print ('hdr:', hdr);
      http_header (http_header_get () || hdr);
    }
  return '';
};


create procedure checkid_setup
	(
	 in ver int := 1,
	 in _identity varchar,
	 in assoc_handle varchar := null,
	 in return_to varchar,
	 in trust_root varchar := null,
	 in sid varchar,
	 in sreg_required varchar := null,
	 in sreg_optional varchar := null,
	 in policy_url varchar := null
	 )
{
  declare rhf, delim, login, ss_key any;
  if (not exists (select 1 from DB.DBA.VSPX_SESSION where VS_SID = sid and VS_REALM = 'wa'))
    {
      rhf := WS.WS.PARSE_URI (return_to);
      if (rhf[4] <> '')
	delim := '&';
      else
        delim := '?';
      http_request_status ('HTTP/1.1 302 Found');

      login :=
      sprintf ('%s?return_to=%U&identity=%U&assoc_handle=%U&trust_root=%U&sreg_required=%U&sreg_optional=%U&policy_url=%U&ver=%d',
	    DB.DBA.wa_link(1, 'openid_login.vspx'), return_to, _identity, coalesce (assoc_handle, ''), trust_root,
	    coalesce (sreg_required, ''), coalesce (sreg_optional, ''), coalesce (policy_url, ''), ver);
      http_header (http_header_get () || sprintf ('Location: %s\r\n', login));
      --http_header (http_header_get () || sprintf ('Location: %s%sopenid.mode=cancel\r\n', return_to, delim));
      return '';
    }
  return checkid_immediate (ver, _identity, assoc_handle, return_to, trust_root, sid, 1, sreg_required, sreg_optional, policy_url);
};

create procedure cancel (in ver int := 1, in return_to varchar)
{
  declare rhf, delim, ns any;
  rhf := WS.WS.PARSE_URI (return_to);
  if (rhf[4] <> '')
    delim := '&';
  else
    delim := '?';
  ns := '';
  if (ver = 2)
    {
      ns := sprintf ('&openid.ns=%U', ns_v2 ());
    }
  http_request_status ('HTTP/1.1 302 Found');
  http_header (http_header_get () || sprintf ('Location: %s%sopenid.mode=cancel%s\r\n', return_to, delim, ns));
  return '';
};


create procedure check_authentication
	(
	  in ver int := 1,
	  in assoc_handle varchar,
	  in sig varchar,
	  in signed varchar,
	  in invalidate_handle varchar := null,
	  in params any := null,
	  in sid varchar
	 )
{
  declare arr, ses, signature any;
  declare key_val, val, ss_key, algo any;
  declare uname, nickname, email, fullname, dob, gender, postcode, country, lang, timezone, svec, idn, iarr any;

  svec := vector ();

  algo := null;
  idn := get_keyword ('openid.identity', params, '');
  iarr := sprintf_inverse (idn, 'http://%s/dataspace/%s', 1);

  uname := null;
  nickname := null;
  if (length (iarr) = 2)
    {
      uname := iarr[1];
      uname := rtrim(nickname, '/');
    }

  whenever not found goto nf;
  select U_E_MAIL, U_FULL_NAME, WAUI_BIRTHDAY, WAUI_GENDER, WAUI_HCODE, WAUI_HCOUNTRY, WAUI_HTZONE, WAUI_NICK
     into email, fullname, dob, gender, postcode, country, timezone, nickname
     from DB.DBA.SYS_USERS, DB.DBA.WA_USER_INFO where
     WAUI_U_ID = U_ID and U_NAME = uname;

  if (dob is not null)
    dob := substring (datestring (dob), 1, 10);

  if (gender = 'male')
    gender := 'M';
  else if (gender = 'female')
    gender := 'F';
  else
    gender := null;

  if (length (country))
    country := (select WC_ISO_CODE from DB.DBA.WA_COUNTRY where WC_NAME = country);

  svec := vector (
		    'sreg.nickname', nickname,
		    'sreg.email', email,
		    'sreg.fullname', fullname,
		    'sreg.dob', dob,
		    'sreg.gender', gender,
		    'sreg.postcode', postcode,
		    'sreg.country', country,
		    'sreg.language', 'en',
		    'sreg.timezone', null -- until fix the format
		);

  nf:;

  if (exists (select 1 from SERVER_SESSIONS where SS_HANDLE = assoc_handle))
    {
      select SS_KEY_NAME, SS_ASSOCIATION_TYPE into ss_key, algo from SERVER_SESSIONS where SS_HANDLE = assoc_handle;
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
      val := get_keyword (key_val, params, null);
      if (key_val = 'openid.mode')
	val := 'id_res';
      if (val is null and item like 'sreg.%')
	{
	  val := get_keyword (item, svec, '');
	}
      if (val is null)
	val := '';

      http (sprintf ('%s:%s\x0A',item,val), ses);
    }
  if (user <> 'OpenID')
    set_user_id ('OpenID');
  if (algo = 'HMAC-SHA256')
    signature := xenc_hmac_sha256_digest (string_output_string (ses), ss_key);
  else
    signature := xenc_hmac_sha1_digest (string_output_string (ses), ss_key);

  if (signature = sig)
    http ('mode:id_res\x0Ais_valid:true\x0A');
  else
    http ('mode:id_res\x0Ais_valid:false\x0A');


  return '';
};

create procedure check_signature (in params varchar)
{
  declare nsig, arr, sig, pars, lst, ses, mkey, kname any;

  declare exit handler for sqlstate '*'
    {
      return 0;
    };

  pars := split_and_decode (blob_to_string (params), 0);
  lst := get_keyword ('openid.signed', pars, null);
  mkey := get_keyword ('mac_key', pars, null);
  sig := get_keyword ('openid.sig', pars, null);

  if (lst is null or mkey is null or sig is null)
    return 0;

  ses := string_output ();
  arr := split_and_decode (lst, 0, '\0\0,');
  foreach (any item in arr) do
    {
       declare key_val, val any;
       key_val := 'openid.'||item;
       val := get_keyword (key_val, pars, '');
       http (sprintf ('%s:%s\x0A',item,val), ses);
    }
  kname := xenc_key_RAW_read (null, mkey);
  nsig := xenc_hmac_sha1_digest (string_output_string (ses), kname);
  xenc_key_remove (kname);
  if (nsig = sig)
    return 1;
  return 0;
};

create procedure dh_defaut_p ()
{
  declare str any;

  str := '\xDC\xF9\x3A\x0B\x88\x39\x72\xEC\x0E\x19\x98\x9A\xC5\xA2\xCE\x31'||
  '\x0E\x1D\x37\x71\x7E\x8D\x95\x71\xBB\x76\x23\x73\x18\x66\xE6\x1E\xF7\x5A'||
  '\x2E\x27\x89\x8B\x05\x7F\x98\x91\xC2\xE2\x7A\x63\x9C\x3F\x29\xB6\x08\x14'||
  '\x58\x1C\xD3\xB2\xCA\x39\x86\xD2\x68\x37\x05\x57\x7D\x45\xC2\xE7\xE5\x2D'||
  '\xC8\x1C\x7A\x17\x18\x76\xE5\xCE\xA7\x4B\x14\x48\xBF\xDF\xAF\x18\x82\x8E'||
  '\xFD\x25\x19\xF1\x4E\x45\xE3\x82\x66\x34\xAF\x19\x49\xE5\xB5\x35\xCC\x82'||
  '\x9A\x48\x3B\x8A\x76\x22\x3E\x5D\x49\x0A\x25\x7F\x05\xBD\xFF\x16\xF2\xFB\x22\xC5\x83\xAB';

  return str;
};

use DB;
