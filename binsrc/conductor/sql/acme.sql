--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2024 OpenLink Software
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

create table ACME.DBA.ACME_SERVER (AC_URL varchar primary key, AC_DIR any, AC_EXPIRATION datetime) if not exists
;

create table ACME.DBA.ACME_ACCOUNT (AA_KEY_NAME varchar primary key, AA_KID varchar, AA_SRV varchar, AA_USER varchar, AA_EMAIL varchar) if not exists
;

create table ACME.DBA.ACME_ORDERS (AO_DNS varchar, AO_SID varchar, AO_OID varchar, AO_ACCT varchar, AO_STATE varchar,
    AO_KEY varchar, AO_CSR long varchar, AO_CRT long varchar, AO_EXPIRES datetime,
    primary key (AO_DNS, AO_OID)) if not exists
create index ACME_ORDERS_KEY on ACME.DBA.ACME_ORDERS (AO_KEY) if not exists
;

create table ACME.DBA.ACME_AUTH_TOKEN (AT_TOKEN varchar primary key, AT_DNS varchar, AT_AID varchar, AT_KEY varchar, AT_EXPIRY datetime) if not exists
create unique index ACME_AUTH_TOKEN_AID on ACME.DBA.ACME_AUTH_TOKEN (AT_AID) if not exists
;

create table ACME.DBA.ACME_SESSION (AS_SID varchar primary key, AS_KEY varchar, AS_URL varchar, AS_NONCE varchar,
    AS_OP varchar, AS_TS timestamp) if not exists
;

create procedure ACME.DBA.make_csr (in sid varchar, in dns varchar, in oid varchar, in kname varchar)
{
  declare key_name, csr varchar;
  if (sid is null)
    signal ('42000', 'Can not make csr for non existing acme session');
  key_name := concat ('key_', sid);
  xenc_key_RSA_create (key_name, 2048);
  csr := xenc_x509_csr_generate (key_name, vector ('CN', dns), vector ('subjectAltName', concat ('DNS:', dns)), 'sha256', 1);
  csr := encode_base64url (csr);
  USER_KEY_STORE (user, key_name);
  insert replacing ACME.DBA.ACME_ORDERS (AO_DNS, AO_SID, AO_OID, AO_STATE, AO_CSR, AO_KEY, AO_ACCT)
      values (dns, sid, oid, 'pending', csr, key_name, kname);
  commit work;
  return csr;
}
;

create procedure ACME.DBA.jwk (in kname varchar)
{
  declare jwk, ks any;
  declare ex varbinary;
  declare e varchar;

  set_user_id ('dba', 1);
  ks := xenc_pubkey_export (kname);
  if (ks[0] <> 'RSAPublicKey')
    signal ('42000', 'Not supported');
  e := sprintf ('%x', ks[1]);
  if (mod (length (e), 2))
    e := concat ('0', e);
  ex := hex2bin (e);
  jwk := soap_box_structure ('e', encode_base64url (ex), 'kty', 'RSA', 'n', encode_base64url (ks[2]));
  return jwk;
}
;

create procedure ACME.DBA.jwk_plain (in kname varchar)
{
  declare jwk, ks any;
  declare ex varbinary;
  declare e varchar;

  set_user_id ('dba', 1);
  ks := xenc_pubkey_export (kname);
  if (ks[0] <> 'RSAPublicKey')
    signal ('42000', 'Not supported');
  e := sprintf ('%x', ks[1]);
  if (mod (length (e), 2))
    e := concat ('0', e);
  ex := hex2bin (e);
  jwk := sprintf ('{"%s":"%s","%s":"%s","%s":"%s"}', 'e', encode_base64url (ex), 'kty', 'RSA', 'n', encode_base64url (ks[2]));
  return jwk;
}
;

create procedure ACME.DBA.sign_request (in kname varchar, in nonce varchar, in url varchar, in payload any, in algo varchar := 'RSA-SHA256')
{
  declare jwk, jws, protected, bprotected, bpayload, spayload, signature any;
  if (isvector (payload))
    spayload := obj2json (payload);
  else
    spayload := payload;
  if (payload is null)
    bpayload := '';
  else
    bpayload := encode_base64url (spayload);
  protected := null;
  for select AA_KID from ACME.DBA.ACME_ACCOUNT where AA_KEY_NAME = kname do
    {
      protected := soap_box_structure ('alg', 'RS256', 'kid', AA_KID, 'nonce', nonce, 'url', url);
    }
  if (protected is null)
    {
      jwk := ACME.DBA.jwk (kname);
      protected := soap_box_structure ('alg', 'RS256', 'jwk', jwk, 'nonce', nonce, 'url', url);
    }
  bprotected := encode_base64url (obj2json (protected));
  -- TODO: alg value
  signature := xenc_sign (concat (bprotected, '.', bpayload), kname, algo);
  jws := soap_box_structure ('protected', bprotected, 'signature', encode_base64url (signature), 'payload', bpayload);
  return obj2json (jws);
}
;

-- https://acme-v02.api.letsencrypt.org/directory
create procedure ACME.DBA.server_url (in url varchar, in op varchar)
{
  declare dir, response, jt, ret any;
  declare expiration datetime;
  for select AC_DIR from ACME.DBA.ACME_SERVER where AC_URL = url do
    {
      ret := get_keyword (op, AC_DIR);
      if (ret is not null)
        return ret;
    }
  dir := HTTP_CLIENT_EXT (url=>url, http_headers=>'Accept: application/json', http_method=>'GET', headers=>response);
  jt := json_parse (dir);
  insert replacing ACME.DBA.ACME_SERVER (AC_URL, AC_DIR, AC_EXPIRATION) values (url, jt, curdatetime ());
  return get_keyword (op, jt);
}
;

--url0 := 'https://acme-v02.api.letsencrypt.org/directory';
create procedure ACME.DBA.new_nonce (in sid varchar := null, in url0 varchar := null, in kname varchar := null)
{
  declare nonce, url varchar;
  declare response, ret any;
  for select AA_SRV from ACME.DBA.ACME_ACCOUNT where AA_KEY_NAME = kname do
    {
      url0 := AA_SRV;
    }
  if (url0 is null)
    url0 := 'https://acme-staging-v02.api.letsencrypt.org/directory';
  url := ACME.DBA.server_url (url0, 'newNonce');
  HTTP_CLIENT_EXT (url=>url,  http_method=>'HEAD', headers=>response);
  nonce := http_request_header (response, 'Replay-Nonce', null, null);
  if (sid is null)
    sid := bin2hex(xenc_digest (uuid(), 'sha1'));
  insert replacing ACME.DBA.ACME_SESSION (AS_SID, AS_URL, AS_NONCE, AS_TS) values (sid, url0, nonce, curdatetime());
  commit work;
  return sid;
}
;

-- http://host:port/.well-known/acme-challenge/<token> content <token>.<thumbnail>
create procedure WS.WS."acme-challenge" () __soap_http 'application/octet-stream'
{
  declare split any;
  declare token any;
  split := split_and_decode (http_path (), 0, '\0\0/');
  if (length (split) <> 4)
    {
      http_status_set (400);
      return '';
    }
  token := split[3];
  for select AT_KEY from ACME.DBA.ACME_AUTH_TOKEN where AT_TOKEN = token do
    {
      declare thumbnail varchar;
      thumbnail := encode_base64url (xenc_digest (ACME.DBA.jwk_plain (AT_KEY), 'sha256'));
      return concat (token, '.', thumbnail);
    }
  http_status_set (404);
  return '';
}
;

grant execute on WS.WS."acme-challenge" to WebMeta
;


-- XXX: make common call to sign an call http_get, ck HTTP code
create procedure ACME.DBA.new_order (in sid varchar, in kname varchar, in identifiers0 any)
{
  declare nonce, url0, url, payload, request, json, pem, oid, jt varchar;
  declare response, ret, identifiers, authorizations, finalize, challenges, thumbnail, token, cha_url, auth_url, state any;
  declare csr, loc, certificate_url varchar;
  declare dns, identifier, expires any;
  declare start_ts int;

  url0 := null;
  for select * from ACME.DBA.ACME_SESSION where AS_SID = sid for update do
    {
      url0 := AS_URL;
      nonce := AS_NONCE;
      if (AS_KEY is not null and kname <> AS_KEY)
        signal ('42000', 'Cannot resume session with another account');
    }

  if (url0 is null)
    signal ('22023', 'Non existing session');
  if (not xenc_key_exists (kname))
    signal ('42000', 'Key does not exists');
  if (not isvector (identifiers0) or length (identifiers0) <> 1)
    signal ('22023', 'Only one identifier is supported per request');

  dns := identifiers0[0];
  url := ACME.DBA.server_url (url0, 'newOrder');
  identifiers := vector ();
  foreach (varchar id in identifiers0) do
    {
      identifiers := vector_concat (identifiers, vector (soap_box_structure ('type', 'dns', 'value', id)));
    }
  payload := obj2json (soap_box_structure ('identifiers', identifiers));
  request := ACME.DBA.sign_request (kname, nonce, url, payload);
  json := HTTP_CLIENT_EXT (url=>url,  http_method=>'POST', headers=>response,
                           http_headers=>'Accept: application/json\r\nContent-Type: application/jose+json',
                           body=>request);
  nonce := http_request_header (response, 'Replay-Nonce', null, null);
  oid := http_request_header (response, 'Location', null, null);
  jt := json_parse (json);
  state := get_keyword ('status', jt);
  authorizations := get_keyword ('authorizations', jt, vector ());
  finalize := get_keyword ('finalize', jt);

  if (length (authorizations) < 1 or finalize is null)
    signal ('42000', 'No authorizations or finalize URLs');

  auth_url := authorizations[0];

  if (state = 'ready')
    goto finalize;

  if (state <> 'pending')
    signal ('42000', 'Order registration failed (01)');

  update ACME.DBA.ACME_SESSION set AS_NONCE = nonce, AS_KEY = kname, AS_OP = 'newOrder' where AS_SID = sid;
  insert replacing ACME.DBA.ACME_ORDERS (AO_DNS, AO_SID, AO_OID, AO_STATE, AO_ACCT) values (dns, sid, oid, state, kname);
  commit work;

  request := ACME.DBA.sign_request (kname, nonce, auth_url, null);
  json := HTTP_CLIENT_EXT (url=>auth_url,  http_method=>'POST', headers=>response,
                           http_headers=>'Accept: application/json\r\nContent-Type: application/jose+json',
                           body=>request);
  nonce := http_request_header (response, 'Replay-Nonce', null, null);
  jt := json_parse (json);
  state := get_keyword ('status', jt);
  if (state  <> 'pending')
    {
      --bing ();
      update ACME.DBA.ACME_ORDERS set AO_STATE = state where AO_DNS = dns and AO_OID = oid;
      commit work;
      signal ('42000', 'Order registration failed (02)');
    }

  identifier := get_keyword ('identifier', jt);
  expires := get_keyword ('expires', jt);
  if (expires is not null)
    expires := cast (expires as datetime);
  -- XXX: ck `type`
  dns := get_keyword ('value', identifier);
  challenges := get_keyword ('challenges', jt, vector ());
  token := cha_url := null;
  foreach (any cha in challenges) do
    {
      if (get_keyword ('status', cha) = 'pending' and get_keyword ('type', cha) = 'http-01')
        {
          token := get_keyword ('token', cha);
          cha_url := get_keyword ('url', cha);
        }
    }
  if (token is null or cha_url is null)
    {
      update ACME.DBA.ACME_ORDERS set AO_STATE = 'error' where AO_DNS = dns and AO_OID = oid;
      commit work;
      signal ('42000', 'Cannot find pending token');
    }

  update ACME.DBA.ACME_ORDERS set AO_EXPIRES = expires where AO_DNS = dns and AO_OID = oid;
  update ACME.DBA.ACME_SESSION set AS_NONCE = nonce where AS_SID = sid;
  commit work;
  thumbnail := encode_base64url (xenc_digest (obj2json (ACME.DBA.jwk (kname)), 'sha256'));
  insert replacing ACME.DBA.ACME_AUTH_TOKEN (AT_TOKEN, AT_KEY, AT_EXPIRY, AT_DNS, AT_AID)
      values (token, kname, expires, dns, auth_url);
  commit work;

  request := ACME.DBA.sign_request (kname, nonce, cha_url, '{}');
  json := HTTP_CLIENT_EXT (url=>cha_url,  http_method=>'POST', headers=>response,
                           http_headers=>'Accept: application/json\r\nContent-Type: application/jose+json',
                           body=>request);
  nonce := http_request_header (response, 'Replay-Nonce', null, null);
  jt := json_parse (json);
  state := get_keyword ('status', jt);

  if (state <> 'pending')
    {
      --bing ();
      update ACME.DBA.ACME_ORDERS set AO_STATE = state where AO_DNS = dns and AO_OID = oid;
      commit work;
      signal ('42000', 'Order registration failed (03)');
    }

  update ACME.DBA.ACME_SESSION set AS_NONCE = nonce where AS_SID = sid;
  commit work;
  request := ACME.DBA.sign_request (kname, nonce, auth_url, null);
  json := HTTP_CLIENT_EXT (url=>auth_url,  http_method=>'POST', headers=>response,
                           http_headers=>'Accept: application/json\r\nContent-Type: application/jose+json',
                           body=>request);
  nonce := http_request_header (response, 'Replay-Nonce', null, null);
  jt := json_parse (json);
  state := get_keyword ('status', jt);
  start_ts := msec_time ();
  while (state = 'pending')
    {
      dbg_obj_print ('Authorization retry, please wait...');
      --bing();
      delay (2);
      request := ACME.DBA.sign_request (kname, nonce, auth_url, null);
      json := HTTP_CLIENT_EXT (url=>auth_url,  http_method=>'POST', headers=>response,
                           http_headers=>'Accept: application/json\r\nContent-Type: application/jose+json',
                           body=>request);
      nonce := http_request_header (response, 'Replay-Nonce', null, null);
      update ACME.DBA.ACME_SESSION set AS_NONCE = nonce where AS_SID = sid;
      commit work;
      jt := json_parse (json);
      state := get_keyword ('status', jt);
      if ((msec_time() - start_ts) > 1200000)
        signal ('42000', 'Authorization timedout');
    }
  if (state <> 'valid')
    {
      declare xt, error, code any;
      xt := xtree_doc (json2xml (json));
      --bing ();
      error := cast (xpath_eval ('//error/detail/text()', xt) as varchar);
      update ACME.DBA.ACME_ORDERS set AO_STATE = state where AO_DNS = dns and AO_OID = oid;
      commit work;
      signal ('42000', concat ('Order registration failed (04) : ', error));
    }

  update ACME.DBA.ACME_SESSION set AS_NONCE = nonce where AS_SID = sid;
  update ACME.DBA.ACME_ORDERS set AO_STATE = 'valid' where AO_DNS = dns and AO_OID = oid;
  commit work;

finalize:
  csr := ACME.DBA.make_csr (sid, dns, oid, kname);
  request := ACME.DBA.sign_request (kname, nonce, finalize, obj2json (soap_box_structure ('csr', csr)));
  json := HTTP_CLIENT_EXT (url=>finalize,  http_method=>'POST', headers=>response,
                           http_headers=>'Accept: application/json\r\nContent-Type: application/jose+json',
                           body=>request);
  nonce := http_request_header (response, 'Replay-Nonce', null, null);
  loc := http_request_header (response, 'Location', null, null);
  jt := json_parse (json);
  state := get_keyword ('status', jt);
  state := cast (state as varchar);
  update ACME.DBA.ACME_SESSION set AS_NONCE = nonce where AS_SID = sid;

  if (state = 'invalid')
    {
      declare xt, error, code any;
      --bing();
      update ACME.DBA.ACME_ORDERS set AO_STATE = state where AO_DNS = dns and AO_OID = oid;
      commit work;
      xt := xtree_doc (json2xml (json));
      error := cast (xpath_eval ('//error/detail/text()', xt) as varchar);
      signal ('42000', concat ('Order registration failed (05) : ', error));
    }

  while (state in ('pending', 'processing'))
    {
      delay (2);
      request := ACME.DBA.sign_request (kname, nonce, loc, null);
      json := HTTP_CLIENT_EXT (url=>loc,  http_method=>'POST', headers=>response,
                           http_headers=>'Accept: application/json\r\nContent-Type: application/jose+json',
                           body=>request);
      nonce := http_request_header (response, 'Replay-Nonce', null, null);
      update ACME.DBA.ACME_SESSION set AS_NONCE = nonce where AS_SID = sid;
      commit work;
      loc := http_request_header (response, 'Location', null, null);
      jt := json_parse (json);
      state := get_keyword ('status', jt);
      --bing();
      if ((msec_time() - start_ts) > 1200000)
        signal ('42000', 'Authorization timedout');
    }

  certificate_url := get_keyword ('certificate', jt);
  if (state = 'valid')
    {
      declare certs varchar;
      request := ACME.DBA.sign_request (kname, nonce, certificate_url, null);
      certs := HTTP_CLIENT_EXT (url=>certificate_url,  http_method=>'POST', headers=>response,
                           http_headers=>'Accept: application/pem-certificate-chain\r\nContent-Type: application/jose+json',
                           body=>request);
      nonce := http_request_header (response, 'Replay-Nonce', null, null);
      update ACME.DBA.ACME_SESSION set AS_NONCE = nonce where AS_SID = sid;
      update ACME.DBA.ACME_ORDERS set AO_CRT = certs, AO_STATE = 'valid' where AO_DNS = dns and AO_OID = oid;
      commit work;
    }
  else
    signal ('42000', 'Certificate cannot be issued');
  return oid;
}
;

create procedure ACME.DBA.new_account (in sid varchar, in kname varchar, in email varchar)
{
  declare nonce, url0, url, payload, request, json, pem, kid, jt varchar;
  declare response, ret any;
  url0 := null;
  for select * from ACME.DBA.ACME_SESSION where AS_SID = sid for update do
    {
      url0 := AS_URL;
      nonce := AS_NONCE;
    }
  if (url0 is null)
    signal ('22023', 'Non existing session');
  if (xenc_key_exists (kname))
    signal ('42000', 'Key already exists');
  url := ACME.DBA.server_url (url0, 'newAccount');
  xenc_key_RSA_create (kname, 2048);
  --payload := obj2json (soap_box_structure ('contact', vector (concat ('mailto:', email)), 'termsOfServiceAgreed', soap_boolean(1)));
  payload := sprintf ('{"contact":["mailto:%s"],"termsOfServiceAgreed":true}', email);
  request := ACME.DBA.sign_request (kname, nonce, url, payload);
  json := HTTP_CLIENT_EXT (url=>url,  http_method=>'POST', headers=>response,
                           http_headers=>'Accept: application/json\r\nContent-Type: application/jose+json',
                           body=>request);
  nonce := http_request_header (response, 'Replay-Nonce', null, null);
  kid := http_request_header (response, 'Location', null, null);
  jt := json_parse (json);
  if (get_keyword ('status', jt) <> 'valid')
    {
      xenc_key_remove (kname);
      signal ('42000', 'Account registration failed');
    }
  insert into ACME.DBA.ACME_ACCOUNT (AA_KEY_NAME, AA_KID, AA_USER, AA_SRV, AA_EMAIL) values (kname, kid, user, url0, email);
  USER_KEY_STORE (user, kname);
  update ACME.DBA.ACME_SESSION set AS_NONCE = nonce, AS_OP = 'newAccount' where AS_SID = sid;
  commit work;
  return kid;
}
;

-- XXX: ck: certs, authorization, tokens etc.
create procedure ACME.DBA.deactivate_acct (in sid varchar, in kname varchar)
{
  declare nonce, url0, url, payload, request, json, pem, kid, jt varchar;
  declare response, ret any;
  url0 := null;
  for select * from ACME.DBA.ACME_SESSION where AS_SID = sid for update do
    {
      url0 := AS_URL;
      nonce := AS_NONCE;
    }
  if (url0 is null)
    signal ('22023', 'Non existing session');
  if (not xenc_key_exists (kname))
    signal ('42000', 'Key do not exists');
  payload := '{"status":"deactivated"}';
  for select * from ACME.DBA.ACME_ACCOUNT where AA_KEY_NAME = kname do
    {
      url := AA_KID;
    }
  if (url0 is null)
    signal ('22023', 'Non existing account');
  request := ACME.DBA.sign_request (kname, nonce, url, payload);
  json := HTTP_CLIENT_EXT (url=>url,  http_method=>'POST', headers=>response,
                           http_headers=>'Accept: application/json\r\nContent-Type: application/jose+json',
                           body=>request);
  nonce := http_request_header (response, 'Replay-Nonce', null, null);
  kid := http_request_header (response, 'Location', null, null);
  jt := json_parse (json);
  if (get_keyword ('status', jt) <> 'deactivated')
    {
      xenc_key_remove (kname);
      signal ('42000', 'Account deactivation failed');
    }
  delete from ACME.DBA.ACME_ACCOUNT where AA_KEY_NAME = kname;
  xenc_key_remove (kname);
  update ACME.DBA.ACME_SESSION set AS_NONCE = nonce, AS_OP = 'deactivateAccount' where AS_SID = sid;
  commit work;
  return nonce;
}
;

create procedure ACME.DBA.deactivate_auth (in sid varchar, in aid varchar)
{
  declare nonce, url0, url, payload, request, json, pem, id, jt, kname varchar;
  declare response, ret any;
  url := url0 := null;
  for select * from ACME.DBA.ACME_SESSION where AS_SID = sid for update do
    {
      url0 := AS_URL;
      nonce := AS_NONCE;
    }
  if (url0 is null)
    signal ('22023', 'Non existing session');
  payload := '{"status":"deactivated"}';
  for select * from ACME.DBA.ACME_AUTH_TOKEN where AT_AID = aid  do
    {
      url := AT_AID;
      kname := AT_KEY;
    }
  if (not xenc_key_exists (kname))
    signal ('42000', 'Key do not exists');
  if (url is null)
    signal ('22023', 'Non existing account');
  request := ACME.DBA.sign_request (kname, nonce, url, payload);
  json := HTTP_CLIENT_EXT (url=>url,  http_method=>'POST', headers=>response,
                           http_headers=>'Accept: application/json\r\nContent-Type: application/jose+json',
                           body=>request);
  nonce := http_request_header (response, 'Replay-Nonce', null, null);
  id := http_request_header (response, 'Location', null, null);
  jt := json_parse (json);
  if (get_keyword ('status', jt) <> 'deactivated')
    {
      signal ('42000', 'Deactivation failed');
    }
  update ACME.DBA.ACME_SESSION set AS_NONCE = nonce, AS_OP = 'deactivateAuth' where AS_SID = sid;
  delete from ACME.DBA.ACME_AUTH_TOKEN where AT_AID = aid;
  commit work;
  return nonce;
}
;

create procedure ACME.DBA.make_cert (in dns varchar, in oid varchar, in kname varchar := null, in force int := 0)
{
  declare pem_key, okey varchar;
  declare cchain any;
  if (kname is null)
    kname := concat ('key_', replace (dns, '.', '_'));
  if (xenc_key_exists (kname))
    signal ('22023', sprintf ('Key name `%s` alredy used, please give a unique name', kname));
  cchain := vector ();
  for select * from ACME.DBA.ACME_ORDERS where AO_DNS = dns and AO_OID = oid do
    {
      declare certs, cert0 any;
      declare i int;
      if (AO_STATE in ('issued', 'revoked') and force = 0)
        signal ('22023', 'Key already registered');
      certs := pem_certificates_to_array (blob_to_string (AO_CRT));
      if (length (certs) < 1)
        signal ('42000', 'Certificate(s) are not retrieved');
      cert0 := certs[0];
      okey := AO_KEY;
      if (okey = kname)
        signal ('22023', 'Key alredy registered');
      pem_key := xenc_pem_export (AO_KEY, 1);
      xenc_key_create_cert (kname, cert0, 'X.509', 1, pem_key, '');
      xenc_set_primary_key (kname);
      USER_KEY_STORE (user, kname);
      cchain := vector_concat (cchain, vector (kname));
      for (i := 1; i < length (certs); i := i + 1)
        {
          declare cert_name varchar;
          cert_name := sprintf ('%s_c%d', kname, i);
          xenc_key_create_cert (cert_name, certs[i], 'X.509', 1);
          USER_KEY_STORE (user, cert_name, 'X.509', 1, '', certs[i]);
          cchain := vector_concat (cchain, vector (cert_name));
        }
    }
  if (okey is null)
    signal ('22023', 'No such order');
  xenc_key_remove (okey);
  update ACME.DBA.ACME_ORDERS set AO_KEY = kname, AO_STATE = 'issued' where AO_DNS = dns and AO_OID = oid;
  commit work;
  return cchain;
}
;


create procedure ACME.DBA.revoke_cert (in sid varchar, in kname varchar)
{
  declare nonce, url0, url, payload, request, json, pem, jt varchar;
  declare response, cert any;
  url0 := null;
  for select * from ACME.DBA.ACME_SESSION where AS_SID = sid for update do
    {
      url0 := AS_URL;
      nonce := AS_NONCE;
    }
  if (url0 is null)
    signal ('22023', 'Non existing session');
  if (not xenc_key_exists (kname))
    signal ('42000', 'Key does not exists');
  url := ACME.DBA.server_url (url0, 'revokeCert');
  cert := encode_base64url (decode_base64 (xenc_X509_certificate_serialize (kname)));
  payload := sprintf ('{"certificate":"%s","reason":4}', cert);
  request := ACME.DBA.sign_request (kname, nonce, url, payload);
  json := HTTP_CLIENT_EXT (url=>url,  http_method=>'POST', headers=>response,
                           http_headers=>'Accept: application/json\r\nContent-Type: application/jose+json',
                           body=>request);
  nonce := http_request_header (response, 'Replay-Nonce', null, null);
  update ACME.DBA.ACME_SESSION set AS_NONCE = nonce, AS_OP = 'revokeCert' where AS_SID = sid;
  update ACME.DBA.ACME_ORDERS set AO_STATE = 'revoked' where AO_KEY = kname;
  commit work;
  return json;
}
;
