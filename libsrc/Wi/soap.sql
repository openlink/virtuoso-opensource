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
--
--!AWK PUBLIC
create procedure
SOAP_CLIENT (
    in url varchar,
    in operation varchar,
    in target_namespace varchar := null,
    in parameters any := null,
    in headers any := null,
    in soap_action varchar := '',
    in attachments any := null,
    in ticket any := null,
    in passwd varchar := null,
    in user_name varchar := null,
    in user_password varchar := null,
    in auth_type varchar := 'none',
    in security_type varchar := 'sign',
    in debug integer := 0,
    in template varchar := null,
    in style integer := 0,
    in version integer := 11,
    in direction integer := 0,
    in http_header any := null,
    in security_schema any := null,
    in time_out int := 100)
{
  declare conn, ret any;
  conn := null;
  ret := SOAP_ASYNC_CLIENT (
		url,
		operation,
		target_namespace,
		parameters,
		headers,
		soap_action,
		attachments,
		ticket,
		passwd,
		user_name,
		user_password,
		auth_type,
		security_type,
		debug,
		template,
		style,
		version,
		direction,
		http_header,
		security_schema,
		time_out,
		conn
		);
   return ret;
}
;

--!AWK PUBLIC
create procedure
SOAP_ASYNC_CLIENT
    (
    in url varchar,
    in operation varchar,
    in target_namespace varchar := null,
    in parameters any := null,
    in headers any := null,
    in soap_action varchar := '',
    in attachments any := null,
    in ticket any := null,
    in passwd varchar := null,
    in user_name varchar := null,
    in user_password varchar := null,
    in auth_type varchar := 'none',
    in security_type varchar := 'sign',
    in debug integer := 0,
    in template varchar := null,
    in style integer := 0,
    in version integer := 11,
    in direction integer := 0,
    in http_header any := null,
    in security_schema any := null,
    in time_out int := 100,
    inout conn any
    )
{
  declare host, path varchar;
  declare hinfo, resp, ver, skeys any;
  declare security_tp int;

  hinfo := rfc1808_parse_uri (url);
  host := hinfo [1];
  if (lower (hinfo[0]) = 'https' and ticket is null)
    ticket := '1';
  path := vspx_uri_compose (vector ('','', hinfo [2], hinfo[3], hinfo[4], hinfo[5]));
  if (parameters is null)
    parameters := vector ();

  if (auth_type = 'x509' or auth_type = 'kerberos' or auth_type = 'key')
    security_tp := case security_type when 'sign' then 1 else 2 end;
  else
    {
      security_tp := 0;
      if (lower (hinfo[0]) <> 'https')
        ticket := null;
    }

  if (debug)
    ver := -1 * version;
  else
    ver := version;

  soap_action := '"' || trim (soap_action, '"') || '"';

  if (lower (hinfo[0]) = 'https' and strchr (host, ':') is null)
    host := host || ':443';

  skeys := null;

  if (connection_get ('wssc-keys') is not null)
    connection_set ('wssc-keys', null);

  resp := soap_call_new (host, path, target_namespace, operation, parameters,
      ver, ticket, passwd, soap_action, style, -- rpc/doclit
      user_name, user_password, security_tp, ticket, template, headers, http_header,
      direction, security_schema, conn, time_out, skeys);

  if (skeys is not null)
    connection_set ('wssc-keys', skeys);

  return resp;
}
;

create procedure WSSE_GET_NS_INFO (inout doc any, inout ns any)
{
   declare wsse any;
   wsse := vector (
	'http://schemas.xmlsoap.org/ws/2002/12/secext',
	'http://schemas.xmlsoap.org/ws/2002/04/secext',
	'http://schemas.xmlsoap.org/ws/2002/07/secext',
	'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
	);
   foreach (varchar uri in wsse) do
     {
       if (xpath_eval (sprintf ('[ xmlns:wsse="%s" ] //wsse:Security', uri), doc) is not null)
         {
           if (uri like 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-%')
             ns := vector ('wsse', uri,
		'wsu', 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd');
           else
             ns := vector ('wsse', uri);
	 }
     }
}
;

--!AWK PUBLIC
create procedure WSSE_OASIS_URI () returns varchar
{
  return 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd';
}
;

--!AWK PUBLIC
create procedure WSSU_OASIS_URI () returns varchar
{
  return 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd';
}
;

create procedure
SOAP_DEFAULT_XENC_TEMPLATE (in body varchar, in key_name varchar, in ns any)
{
  declare tmpl, algo varchar;
  algo := xenc_get_key_algo (key_name);
  if (algo is null)
    return NULL;

  tmpl := sprintf ('<?xml version="1.0" encoding="UTF-8"?>
<Signature xmlns="http://www.w3.org/2000/09/xmldsig#" >
  <SignedInfo>
    <CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#" />
    <SignatureMethod Algorithm="%s" />
  </SignedInfo>
  <SignatureValue></SignatureValue>
  <KeyInfo>
    <KeyName>%s</KeyName>
  </KeyInfo>
</Signature>', algo, key_name);

  return dsig_template_ext (xtree_doc (body), tmpl, ns,
      'http://schemas.xmlsoap.org/soap/envelope/', 'Body',
       -- WS-Addressing 2004
      'http://schemas.xmlsoap.org/ws/2004/03/addressing', 'Action',
      'http://schemas.xmlsoap.org/ws/2004/03/addressing', 'From',
      'http://schemas.xmlsoap.org/ws/2004/03/addressing', 'To',
      'http://schemas.xmlsoap.org/ws/2004/03/addressing', 'MessageID',
      'http://schemas.xmlsoap.org/ws/2004/03/addressing', 'ReplyTo',
      'http://schemas.xmlsoap.org/ws/2004/03/addressing', 'FaultTo',
      'http://schemas.xmlsoap.org/ws/2004/03/addressing', 'RelatesTo',
      -- WS-Addressing 2003
      'http://schemas.xmlsoap.org/ws/2003/03/addressing', 'Action',
      'http://schemas.xmlsoap.org/ws/2003/03/addressing', 'From',
      'http://schemas.xmlsoap.org/ws/2003/03/addressing', 'To',
      'http://schemas.xmlsoap.org/ws/2003/03/addressing', 'MessageID',
      'http://schemas.xmlsoap.org/ws/2003/03/addressing', 'ReplyTo',
      'http://schemas.xmlsoap.org/ws/2003/03/addressing', 'FaultTo',
      'http://schemas.xmlsoap.org/ws/2003/03/addressing', 'RelatesTo',
      -- WS-Routing
      'http://schemas.xmlsoap.org/rp', 'action',
      'http://schemas.xmlsoap.org/rp', 'to',
      'http://schemas.xmlsoap.org/rp', 'id',
      -- WS-Utility
      'http://schemas.xmlsoap.org/ws/2002/07/utility', 'Created',
      'http://schemas.xmlsoap.org/ws/2002/07/utility', 'Expires'
      );

}
;

create procedure
SOAP_CLIENT_WSS (INOUT BODY ANY, INOUT KEYI ANY, INOUT TEMPLATE VARCHAR, INOUT SIGN INT, INOUT NS ANY)
{
  declare resp varchar;
  declare request varchar;
  declare _template varchar;
  declare _ns any;

  if (not sign)
    return;

  request := string_output_string (BODY);
  _template := TEMPLATE;

  if (isarray (NS) and not isstring (NS))
    _ns := NS;
  else
    _ns := vector ();


  if (_template like '^[%^]' escape '^')
    {
       _template := trim (_template, '[]');
       if ("LEFT" (_template, 5) = 'func:')
	 {
	    declare mdata any;
	    _template := subseq (_template, 5);
	    _template := call (_template)(request);
	 }
       else
         _template := SOAP_DEFAULT_XENC_TEMPLATE (request, _template, _ns);
    }

  if (sign = 1 or keyi is null)
    {
      resp := xenc_encrypt (request, 11, _template, _ns);
    }
  else if (sign = 2)
    resp := xenc_encrypt (request, 11, _template, _ns, '//Envelope/Body', keyi, 'Content');
  string_output_flush (BODY);
  http (resp, BODY);
}
;

--!AWK PUBLIC
create procedure
wsrp_error (in code integer, in reason varchar, in endpoint varchar, inout soap_xml any)
{
   declare errm any;
   http_rewrite ();
   errm := xslt ('http://local.virt/wsrp_error', soap_xml, vector ('code', cast (code as varchar), 'reason', reason, 'endpoint', endpoint, 'id', lower(uuid())));
   http_value (errm);
   http_request_status ('HTTP/1.1 500 Server Error');
   signal ('SOAP', sprintf ('%d %s', code, reason));
}
;

create procedure
WS_SOAP_GET_KEYINFO (inout soap_xml any, inout lines any)
{
  declare tkt any;
  declare tp, enc varchar;
  declare ser, own, issuer, stard, endd, usr any;
  declare sec, pos1, pos2 any;

  sec := xpath_eval
	      ('[xmlns:S="http://schemas.xmlsoap.org/soap/envelope/"] /S:Envelope/S:Header/*:Security',
       soap_xml, 1);


  if (sec is null)
    return ;

  --dbg_obj_print (sec);

  tkt := xpath_eval ('BinarySecurityToken/text()', sec, 1);
  tp := xpath_eval  ('BinarySecurityToken/@ValueType', sec, 1);
  enc := xpath_eval ('BinarySecurityToken/@EncodingType', sec, 1);
  usr := xpath_eval ('UsernameToken/Username/text()', sec, 1);

  if (usr is not null)
    {
      connection_set ('wss-user', cast (usr as varchar));
    }

  if (tkt is null)
    return;

  tp := cast (tp as varchar);
  enc := cast (enc as varchar);
  tkt := cast (tkt as varchar);

  pos1 := strrchr (tp,  '#');
  pos2 := strrchr (enc, '#');
  if (pos1 is null)
    {
      pos1 := strrchr (tp, ':');
      pos2 := strrchr (enc, ':');
    }

  if (pos1 is not null)
    tp := subseq (tp, pos1 + 1, length (tp));
  if (pos2 is not null)
    enc := subseq (enc, pos2 + 1, length (enc));

  ser := own := issuer := stard := endd := NULL;
  if (tp = 'X509v3')
    {
      if (enc = 'Base64Binary')
	{
	  declare cert any;
          cert := decode_base64 (tkt);
          ser := get_certificate_info (1, cert, 1);
          own := get_certificate_info (2, cert, 1);
          issuer := get_certificate_info (3, cert, 1);
          stard := get_certificate_info (4, cert, 1);
          endd := get_certificate_info (5, cert, 1);
	}
    }
  else if (tp = 'Kerberosv5ST')
    {
      if (enc = 'Base64Binary')
	{
	  declare cert, ctx, cip, cnt any;
          cert := decode_base64 (tkt);
          declare exit handler for sqlstate '*'
           {
	     dbg_obj_print (__SQL_MESSAGE);
	     resignal;
	   };
          ctx := krb_init_srv_ctx ('host', cert);
	  ser := krb_inquire_ctx (ctx, 1);
	  own := krb_inquire_ctx (ctx, 2);
	  issuer := krb_inquire_ctx (ctx, 3);
	  stard := krb_inquire_ctx (ctx, 4);
	  endd := krb_inquire_ctx (ctx, 5);
	  -- DELME , just to test
          cip := cast (xpath_eval ('//CipherValue/text()', soap_xml, 1) as varchar);
          cnt := kerberos_unseal (ctx, cip);
          dbg_obj_print (cnt);
	}
    }
  connection_set ('wss-token-owner', own);
  connection_set ('wss-token-issuer', issuer);
  connection_set ('wss-token-serial', ser);
  connection_set ('wss-token-start', stard);
  connection_set ('wss-token-end', endd);
}
;

create procedure
WS_SECURITY_CHECK (inout body varchar, inout soap_xml any, inout lines any, inout ns any)
{
  declare decoded varchar;
  declare body_str varchar;
  declare validate_sign int;
  declare opts, uhook, ekeys any;

  body_str := string_output_string (body);

  if (0)
    log_message ('Calling security pre-processing');

  opts := http_map_get ('soap_opts');
  validate_sign := get_keyword ('WSS-Validate-Signature', opts, 2);

  if (isstring (validate_sign))
    validate_sign := cast (validate_sign as integer);

  -- first decode the message
  {
   declare exit handler for sqlstate '*' {
      if (1)
        log_message (sprintf ('WSS: %s', __SQL_MESSAGE));
      resignal;
      -- XXX: for tests only
      --goto nxt;
   };
   --string_to_file ('soap_trace.txt', body_str, -2);
   decoded := xenc_decrypt_soap (body_str, 11, validate_sign, 'UTF-8', 'x-any', opts, ekeys);
   connection_set ('wss-keys', ekeys);
   if (isstring (decoded))
     soap_xml := xml_tree_doc (decoded);
  }

  WSSE_GET_NS_INFO (soap_xml, ns);

  -- Timestamp utility handler
  {
    declare created, expires, timenow datetime;
    declare _created, _expires any;
    timenow := now ();
    _created := xpath_eval ('[xmlns:S="http://schemas.xmlsoap.org/soap/envelope/" xmlns:u="http://schemas.xmlsoap.org/ws/2002/07/utility"] /S:Envelope/S:Header/u:Timestamp/u:Created', soap_xml);
    _expires := xpath_eval ('[xmlns:S="http://schemas.xmlsoap.org/soap/envelope/" xmlns:u="http://schemas.xmlsoap.org/ws/2002/07/utility"] /S:Envelope/S:Header/u:Timestamp/u:Expires', soap_xml);

    if (_expires is not null and _created is not null)
      {
        created := soap_box_xml_entity (_created, timenow, 11);
        expires := soap_box_xml_entity (_expires, timenow, 11);
--	created := dt_set_tz (created, 0);
--	expires := dt_set_tz (expires, 0);
        if ((dateadd('second', -1, created) > timenow or timenow > expires))
          signal ('SOAP', sprintf ('300 Message Expired (created %s expires %s, time now is %s)',
              __rdf_strsqlval (created), __rdf_strsqlval (expires), __rdf_strsqlval (timenow) ) );
      }
  }
  -- get info, and make connection_set

nxt:
  WS_SOAP_GET_KEYINFO (soap_xml, lines);

  uhook := get_keyword ('WSS-SecurityCheck', opts, NULL);
  -- call user hook

  if (length (uhook) > 0 and __proc_exists (uhook))
    {
       call (uhook) (soap_xml);
    }

  if (__proc_exists ('DB.DBA.WS_SOAP_ACCOUNTING'))
    {
      declare rc int;
      rc := call ('DB.DBA.WS_SOAP_ACCOUNTING') (); -- we need to specify what to get & return
      if (not rc)
	{
	  http_rewrite ();
	  http (soap_make_error ('300', '42000', 'Accounting failed'));
          http_request_status ('HTTP/1.1 500 Server Error');
	  signal ('SOAP', sprintf ('%d %s', 300, 'Accounting failed'));
	}
    }

}
;

create procedure
WS_SECURITY_ADD (inout body any, inout ns any)
{
  declare _body any;
  declare _ns any;

  if (0)
    log_message ('Calling security post-processing');
  declare templ, tempf, kname, ktype, tp varchar;
  declare keyinst, ses, opts any;

  opts := http_map_get ('soap_opts');
  templ := get_keyword ('WSS-Template', opts, NULL);
  tempf := get_keyword ('WSS-Func-Template', opts, NULL);
  kname := get_keyword ('WSS-KEY', opts, NULL);

  if (isarray (ns) and not isstring (ns))
    _ns := ns;
  else
    _ns := vector ();

  -- get a key instance
  if (isstring (kname) and __proc_exists (kname))
    keyinst := call (kname) ();
  else
    keyinst := NULL;

  -- make a response
  ses := string_output ();
  http_value (body, null, ses);
  _body := string_output_string (ses);

  -- get a template
  if (tempf is not null)
    {
	templ := call (tempf)(body);
    }
  else if (templ is not null)
    {
      if (templ like '^[%^]' escape '^')
	{
           templ := trim (templ, '[]');
	   if ("LEFT" (templ, 5) = 'func:')
	     {
		templ := subseq (templ, 5);
		templ := call (templ)(_body);
	     }
	   else
	     templ := SOAP_DEFAULT_XENC_TEMPLATE (_body, templ, _ns);
        }
      else
	templ := file_to_string (templ);
    }
  else
    templ := null;

  if (keyinst is not null)
    body := xenc_encrypt (_body, 11, templ, _ns,
                '//Envelope/Body[*]', keyinst, 'Content');
  else if (templ is not null)
    body := xenc_encrypt (_body, 11, templ, _ns);
  else
    return 0;
  return 1;
}
;

--!AWK PUBLIC
create procedure
WS_SOAP (in path any, in params any, in lines any)
{
    declare content_type, soap_method, soap_xml varchar;
    declare res any;
    declare rp, soap_header any;
    declare rp_act, wssec, wsrpe integer;
    declare req_body varchar;
    declare wss, attachments, ns any;
    declare soap_ver int;

    soap_ver := 11;
    ns := vector ();

    if (length (params) < 1) params := __http_stream_params ();

    if (isstring({?'content'}) and lower(trim({?'content'})) = 'wsdl')
      {
	http (soap_wsdl ());
	return;
      }

    -- rp_act is flag for WS-routing protocol
    -- 1 - intermediary
    -- 2 - ultimate

    rp_act := 0; wssec := 0; wsrpe := 0;
    content_type := http_request_header (lines, 'Content-Type');
    soap_method := trim (http_request_header (lines, 'SOAPAction', null, ''), '"');
    soap_xml := NULL; attachments := NULL;
    if (isstring (content_type))
       content_type := lower (content_type);

    if (content_type = 'text/xml')
      {
        req_body := http_body_read ();
	soap_xml := xml_tree_doc (xml_tree (req_body));
        -- DELME
        --{
	--  declare r1, r2 any;
          --r1 := string_output_string (req_body);
          --r1 := xml_tree_doc (r1);
          --r1 := xslt ('file:/db/raw.xsl', r1);
          --r2 := string_output ();
          --http_value (r1, null, r2);
          --string_to_file ('wsdump.xml', string_output_string (req_body), -1);
          --dbg_obj_print ('REQUEST:', soap_xml);
	--}
      }
    else if (content_type = 'application/dime') -- TODO: add code for making dime after that
      {
	declare dime_arr any;
        req_body := http_body_read ();
        req_body := string_output_string (req_body);
        dime_arr := dime_tree (req_body);
        --dbg_obj_print (dime_arr);
        req_body := dime_arr [0][2];
        attachments := dime_arr;
        aset (attachments, 0, NULL);
        soap_xml := xml_tree_doc (xml_tree (req_body));
      }
--  else if (content_type = 'multipart/related')
--    {
--      req_body := params[1];
--      soap_xml := xml_tree_doc (xml_tree (req_body));
--    }
--    else if (content_type = 'application/soap+xml')
--      {
--	declare rol, route varchar;
--	soap_method := trim (http_request_header (lines, 'Content-Type', 'action', ''), '"');
--        req_body := http_body_read ();
--	soap_xml := xml_tree_doc (xml_tree (req_body));
--	soap_ver := 12;
--      }
    else
      {
	http_request_status ('HTTP/1.1 400 Bad request');
        signal ('42000', 'Unsupported media type');
      }

    http_header ('Content-Type: text/xml; charset="utf-8"\r\n');

    -- XXX: trailing slash on NS
    rp := xpath_eval ('[xmlns:S="http://schemas.xmlsoap.org/soap/envelope/" xmlns:rp="http://schemas.xmlsoap.org/rp"] /S:Envelope/S:Header/rp:path', soap_xml, 1);
    soap_header := xpath_eval ('[xmlns:S="http://schemas.xmlsoap.org/soap/envelope/"] /S:Envelope/S:Header', soap_xml, 1);

    wss := xpath_eval ('[xmlns:S="http://schemas.xmlsoap.org/soap/envelope/" xmlns:wss="http://schemas.xmlsoap.org/ws/2002/07/secext"] /S:Envelope/S:Header/wss:Security', soap_xml, 1);
    if (wss is null)
      wss := xpath_eval ('[xmlns:S="http://schemas.xmlsoap.org/soap/envelope/" xmlns:wss="http://schemas.xmlsoap.org/ws/2002/04/secext"] /S:Envelope/S:Header/wss:Security', soap_xml, 1);

  if (http_map_get ('soap_opts'))
    {
      if (lower (get_keyword ('WS-SEC', http_map_get ('soap_opts'), 'no')) like 'y%')
	{
	  -- this is a security related message do process it
	   wssec := 1;
	}

       if (lower (get_keyword ('WS-RP', http_map_get ('soap_opts'), 'no')) like 'y%')
	 wsrpe := 1;
    }

   declare this_point, send_to, _action, _id, _to, newfwd varchar;
   declare _rev any;
   declare errm any;
   if (rp is not null and wsrpe)
    {
      declare _actor, _mustund nvarchar;
      --declare this_host, this_path varchar;
      declare _fwd any;

      _action := xpath_eval ('string(action)', rp, 1);
      _id := xpath_eval ('string(id)', rp, 1);
      _actor := xpath_eval ('@actor', rp, 1);
      _mustund := xpath_eval ('@mustUnderstand', rp, 1);
      if (_actor <> N'http://schemas.xmlsoap.org/soap/actor/next' or _mustund <> N'1')
        db..wsrp_error (701, 'WS-Routing Header Required', '', soap_xml);

      _to := xpath_eval ('string(to)', rp, 1);
      _fwd := xpath_eval ('fwd', rp, 1);
      _rev := xpath_eval ('rev', rp, 1);
      --this_host := http_request_header (lines, 'Host', null, 'localhost');
      --this_host := 'imitko:6666'; -- find out how to get port if not supplied
      --this_path := http_path();
      --this_point := sprintf ('http://%s%s', this_host, this_path);
      this_point := soap_current_url ();
      if (this_point not like '%/' and http_path() like '%/')
        this_point := concat (this_point, '/');
      send_to := NULL;
      _to := cast (_to as varchar);
      if (_fwd is null or xpath_eval('via[1]', _fwd, 1) is null)
	{
	  -- there is no fwd or fwd/via, test the to
	  if (_to <> this_point)
	    {
	      db..wsrp_error (800, 'WS-Routing receiver fault', _to, soap_xml);
	    }
	  -- else we are ultimate destination
	  rp_act := 2;
	}
      else
	{
	  declare _to1 varchar;
          send_to := xpath_eval('via[2]', _fwd, 1);
	  if (send_to is not null)
	    send_to := xpath_eval('string()', send_to, 1);
          _to1 := xpath_eval('string(via[1])', _fwd, 1);
          _to1 := cast (_to1 as varchar);

          -- in all cases the fwd/via[1] must be this point
	  if (_to1 <> this_point)
	    {
	      db..wsrp_error (800, 'WS-Routing receiver fault', _to, soap_xml);
	    }

          if (send_to is null)
	    {
	      if (xpath_eval ('to', rp, 1) is null)
		{
		  -- if no to, then we are ultimate destination
		  _to := _to1;
		  rp_act := 2;
		}
	      else
		{
		  -- else send to the ultimate, we are a last hop to it
                  send_to := _to;
	          rp_act := 1;
		}
	    }
	  else
	    {
	      -- in all other cases we are a router
              rp_act := 1;
	    }
	}

    }
  else if (wsrpe)
    db..wsrp_error (701, 'WS-Routing Header Required', '', soap_xml);

  newfwd := '';
  if (__proc_exists ('DB.DBA.WS_SOAP_RF_HEADER'))
    {
      newfwd := call ('DB.DBA.WS_SOAP_RF_HEADER') (soap_header, lines, this_point, send_to);
      if (newfwd <> '')
	{
          send_to := newfwd;
	  rp_act := 1;
	}
    }

   if (rp_act = 1) -- act as router
    {		   -- XXX: there should be verification also, for now only at endpoint
      declare hdr, body, hl, ses, hinfo varchar;
      declare hst varchar;
      send_to := cast (send_to as varchar);
      hinfo := rfc1808_parse_uri (send_to);
      if (hinfo [0] = '' or hinfo [1] = '' or hinfo [2] = '' or hinfo [5] <> '')
        {
	  db..wsrp_error (713, 'Endpoint Invalid', send_to, soap_xml);
	}
      if (hinfo [0] <> 'http')
	{
	  db..wsrp_error (712, 'Endpoint Not Supported', send_to, soap_xml);
	}
      body := xslt ('http://local.virt/wsrp_interm', soap_xml, vector ('newrev', '', 'newfwd', newfwd));
      ses := string_output ();
      http_value (body, NULL, ses);
      body := string_output_string (ses);
      hdr := sprintf ('SOAPAction: "%s"\r\nContent-Type: text/xml; charset="utf-8"', _action);
      {
         declare exit handler for sqlstate '*' {
	  db..wsrp_error (820, 'Endpoint Not Reachable', send_to, soap_xml);
         };
         declare exit handler for sqlstate '22023' {
	  db..wsrp_error (730, 'Endpoint Too Long', send_to, soap_xml);
         };
         declare exit handler for sqlstate '08006' {
	  db..wsrp_error (740, 'Message Timeout', send_to, soap_xml);
         };
	if (registry_get ('__SOAP_WSRP_LOG') = '1')
	  log_message ('Forwarding request to: ' || send_to);
        res := http_get (send_to, hl, 'POST', hdr, body);
      }

      -- once result is got a XSLT must be to add path & friends
      hst := trim(hl[0], '\r\n ');

      if (hst like 'HTTP/1.1 4%')
        db..wsrp_error (820, 'Endpoint Not Reachable', send_to, soap_xml);

      http_request_status (hst);

      rp_act := 0;
      if (('text/xml' = http_request_header (hl, 'Content-Type')) and atoi (http_request_header (hl, 'Content-Length', null, '0')))
        {
	  soap_xml := xml_tree_doc (xml_tree (res));
          -- transform the result
          res := xslt ('http://local.virt/wsrp_interm', soap_xml, vector ('newrev', this_point, 'newfwd', ''));
        }

    }
   else -- we are ultimate destination
    {
      declare soap_res any;
      declare new_xml any;

	declare exit handler for SQLSTATE '*' {
	  declare err_msg varchar;
	  err_msg := soap_make_error ('300', __SQL_STATE, __SQL_MESSAGE);
	  http (err_msg);
	  if (wssec and length (http_pending_req ()) = 1)
            xenc_delete_temp_keys ();
	  resignal 'VSPRT';
	};

      if (wssec)
        {
          WS_SECURITY_CHECK (req_body, soap_xml, lines, ns);
	}

      new_xml := xslt ('http://local.virt/wsrp_ultim', soap_xml);
      --dbg_obj_print ('before soap_server: ', new_xml);
      if (__proc_exists ('DB.DBA.WS_SOAP_RF_MESSAGE'))
        res := call ('DB.DBA.WS_SOAP_RF_MESSAGE') (new_xml, lines, _action, this_point);
      if (res is null)
        res := soap_server (new_xml, soap_method, lines, soap_ver, null, null, attachments);
      -- there we must add SOAP:Header and friends
      if (wsrpe)
        {
	  declare _from_mail varchar;
          _from_mail := get_keyword ('wsrp-from',http_map_get ('soap_opts'), '');
          soap_res := xml_tree_doc (res);
          --dbg_obj_print ('result1:',res);
          res := xslt ('http://local.virt/wsrp_resp', soap_res, vector ('id', lower(uuid()), 'relatesTo', _id, 'action', _action, 'fwd', _rev, 'to', _to, 'from', _from_mail));
       }
      else
       {
         soap_res := xml_tree_doc (res);
         res := xslt ('http://local.virt/wsrp_resp', soap_res, vector ('routing', 0, 'b_id', lower(uuid())));
       }

      if (wssec)
	{
	  WS_SECURITY_ADD (res, ns);
	  if (length (http_pending_req ()) = 1)
            xenc_delete_temp_keys ();
        }
   }

   if (registry_get ('__SOAP_WSRP_LOG') = '1')
     log_message ('Sending response to: ' || http_client_ip ());
   --dbg_obj_print ('result:',res);
   if (isstring (res))
     http (res);
   else
     http_value (res);
}
;

create table DB.DBA.WS_REFERRALS (
    R_ID  	varchar,
    R_FOR 	varchar,
    R_GO  	long varchar,
    R_EXPIRY 	datetime,
    R_URL	varchar,
    R_STATIC	varchar default NULL,
    primary key (R_ID, R_FOR)
    )
;

alter table DB.DBA.WS_REFERRALS add R_STATIC varchar default NULL
;

create procedure
DB.DBA.WS_SOAP_RF_HEADER (in soap_xml any, in lines any, in this_point varchar, in next_hop varchar)
{
  declare referrals any;
  declare matches any;

  if (soap_xml is null)
    return '';

  referrals := xpath_eval ('[xmlns:S="http://schemas.xmlsoap.org/soap/envelope/" xmlns:r="http://schemas.xmlsoap.org/ws/2001/10/referral"] /S:Envelope/S:Header/r:referrals', soap_xml, 1);

  matches := vector ();
  if (referrals is null)
    {
      for select R_ID, R_FOR, R_GO, R_EXPIRY from DB.DBA.WS_REFERRALS where R_URL = this_point and
	(this_point like R_FOR or next_hop like R_FOR)
	and datediff ('second', now(), R_EXPIRY) > 0 do
	  {
            matches := vector_concat (matches, vector (vector (R_FOR, R_GO, R_ID, R_EXPIRY)));
	  }
      goto choose;
    }
--    return '';

  declare _refs, _ref, _for_pref, _for_exact, _go, _if_ttl, go_via any;
  declare _refid, _if_inv varchar;
  declare len, inx, i, l integer;

  _refs := xpath_eval ('ref[*]', referrals, 0);
  inx := 0; len := length(_refs);

  if (not len) -- for now we'll process only header referrals
    return '';
  while (inx < len)
    {
      _ref := _refs[inx];
      inx := inx + 1;
      _refid := cast (xpath_eval ('string(refId)', _ref, 1) as varchar);
      _if_ttl := cast (xpath_eval ('string(if/ttl)', _ref, 1) as integer);
      _if_inv := xpath_eval ('if/invalidates/rid/text()', _ref, 0);
      _go := xpath_eval ('go/via/text()', _ref, 0);
      _for_pref := xpath_eval ('for/prefix/text()', _ref, 0);
      _for_exact := xpath_eval ('for/exact/text()', _ref, 0);
      i := 0; l := length (_if_inv);
      while (i < l)
	{
	  declare elm varchar;
	  elm := cast (_if_inv[i] as varchar);
	  delete from WS_REFERRALS where R_ID = elm;
	  i := i + 1;
	}
      i := 0; l := length (_go);
      go_via := vector ();
      while (i < l)
	{
	  go_via := vector_concat (go_via, vector (cast (_go[i] as varchar)));
	  i := i + 1;
	}
      if (i)
	go_via := serialize (go_via);
      else
	go_via := NULL;
      declare expiry datetime;
      _if_ttl := _if_ttl / 1000; -- make it seconds
      if (_if_ttl <= 0)
	_if_ttl := 3600*24; -- one day
      expiry := dateadd ('second', _if_ttl, now());
      declare exit handler for sqlstate '23000' {
	   rollback work;
	 return '';
       };
      i := 0; l := length (_for_pref);
      while (go_via is not null and (i < l))
	{
	  declare elm varchar;
	  elm := cast (_for_pref[i] as varchar);
	  elm := concat (elm, '%');
          if (this_point like elm)
            {
              matches := vector_concat (matches, vector (vector (elm, go_via, _refid, expiry)));
	      --insert into WS_REFERRALS (R_ID, R_FOR, R_GO, R_EXPIRY) values (_refid, elm, go_via, expiry);
	    }
	  i := i + 1;
	}
      i := 0; l := length (_for_exact);
      while (go_via is not null and (i < l))
	{
	  declare elm varchar;
	  elm := cast (_for_exact[i] as varchar);
          if (this_point = elm)
            {
              matches := vector_concat (matches, vector (vector (elm, go_via, _refid, expiry)));
	      --insert into WS_REFERRALS (R_ID, R_FOR, R_GO, R_EXPIRY) values (_refid, elm, go_via, expiry);
	    }
	  i := i + 1;
	}
    }
choose:
  commit work;
  i := 0; l := length (matches);
  declare choice any;
  choice := vector ('', vector (''));
  while (i < l)
    {
      declare elm any;
      declare via, host varchar;
      elm := matches[i];
      host := elm[0];
      via := deserialize(elm[1]);
      if (length (via) and length (host) > length (choice[0]))
        choice := vector (host, via);
      i := i + 1;
    }

  if (choice[0] <> '')
    return choice[1][0];
  return '';
}
;

create procedure
DB.DBA.WS_SOAP_RF_MESSAGE (in soap_xml any, in lines any, inout action varchar, inout this_url varchar)
{
  declare query, queryresp, register, register_resp, refresp, referrals, _for_pref, _for_exact any;
  declare _go, _if, _refid any;
  declare i, l integer;
  query := NULL; queryresp := NULL; register := NULL; register_resp := NULL; refresp := NULL;
  referrals := NULL;
  if (action = 'http://schemas.xmlsoap.org/ws/2001/10/referral#query')
    query := xpath_eval ('[xmlns:S="http://schemas.xmlsoap.org/soap/envelope/" xmlns:r="http://schemas.xmlsoap.org/ws/2001/10/referral"] /S:Envelope/S:Body/r:query', soap_xml, 1);
  else if (action = 'http://schemas.xmlsoap.org/ws/2001/10/referral#queryResponse')
    queryresp := xpath_eval ('[xmlns:S="http://schemas.xmlsoap.org/soap/envelope/" xmlns:r="http://schemas.xmlsoap.org/ws/2001/10/referral"] /S:Envelope/S:Body/r:queryResponse', soap_xml, 1);
  else if (action = 'http://schemas.xmlsoap.org/ws/2001/10/referral#register')
    register := xpath_eval ('[xmlns:S="http://schemas.xmlsoap.org/soap/envelope/" xmlns:r="http://schemas.xmlsoap.org/ws/2001/10/referral"] /S:Envelope/S:Body/r:register', soap_xml, 1);
  else if (action = 'http://schemas.xmlsoap.org/ws/2001/10/referral#registrationResponse')
    register_resp := xpath_eval ('[xmlns:S="http://schemas.xmlsoap.org/soap/envelope/" xmlns:r="http://schemas.xmlsoap.org/ws/2001/10/referral"] /S:Envelope/S:Body/r:registrationResponse', soap_xml, 1);

  if (query is not null or queryresp is not null or register is not null or register_resp is not null)
    {
      delete from WS_REFERRALS where datediff ('second', now(), R_EXPIRY) <= 0;
      commit work;
    }

  if (query is not null)
    {
      declare ses, _for any;
      declare pt varchar;
      ses := string_output ();
      _for_pref := xpath_eval ('for/prefix/text()', query, 0);
      _for_exact := xpath_eval ('for/exact/text()', query, 0);
      http ('<S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/">', ses);
      http ('<S:Body xmlns:r="http://schemas.xmlsoap.org/ws/2001/10/referral">', ses);
      http ('<r:queryResponse>', ses);

      pt := 'exact';
      _for := _for_exact;
again:
      i := 0; l := length (_for);
      while (i < l)
        {
	  declare elm, velm varchar;
	  declare j, k, ttl integer;
	  declare via any;
          elm := cast (_for[i] as varchar);
	  for select R_ID, R_FOR, R_GO, R_EXPIRY from WS_REFERRALS where elm like R_FOR and R_URL = this_url do
	    {
              ttl := datediff ('second', now(), R_EXPIRY);
              ttl := ttl * 1000;
              R_FOR := trim (R_FOR, '%');
	      http ('<r:ref>', ses);
	      http ('<r:for>', ses);
	      http (sprintf ('<r:%s>%s</r:%s>', pt, R_FOR, pt), ses);
	      http ('</r:for>', ses);
	      http ('<r:if>', ses);
	      http (sprintf ('<r:ttl>%d</r:ttl>', ttl), ses);
	      http ('</r:if>', ses);
              via := deserialize (R_GO);
              j := 0; k := length (via);
	      http ('<r:go>', ses);
	      -- may be there THIS HOST should be added to the via list ?!?
              while (j < k)
                {
                  velm := sprintf ('<r:via>%s</r:via>', via[j]);
                  http (velm, ses);
                  j := j + 1;
		}
	      http ('</r:go>', ses);
	      http (sprintf ('<r:refId>%s</r:refId>', R_ID), ses);
	      http ('</r:ref>', ses);
	    }
	  i := i + 1;
	}
      if (pt = 'exact')
	{
	  pt := 'prefix';
          _for := _for_pref;
	  goto again;
	}
      http ('</r:queryResponse>', ses);
      http ('</S:Body>', ses);
      http ('</S:Envelope>', ses);
      action := 'http://schemas.xmlsoap.org/ws/2001/10/referral#queryResponse';
      return string_output_string (ses);
    }
  else if (register is not null or queryresp is not null)
    {
      declare _ref, _refs, go_via, _if_ttl, _if_inv any;
      declare is_reg integer;
      declare inx, len integer;
      is_reg := 1;
      if (register is null)
        {
          is_reg := 0;
          register := queryresp;
	}
      _refs := xpath_eval ('ref[*]', register, 0);
      inx := 0; len := length(_refs);

      if (not len)
        return NULL;

      while (inx < len)
        {
          _ref := _refs[inx];
          inx := inx + 1;
	  _refid := cast (xpath_eval ('string(refId)', _ref, 1) as varchar);
	  _if_ttl := cast (xpath_eval ('string(if/ttl)', _ref, 1) as integer);
	  _if_inv := xpath_eval ('if/invalidates/rid/text()', _ref, 0);
	  _go := xpath_eval ('go/via/text()', _ref, 0);
	  _for_pref := xpath_eval ('for/prefix/text()', _ref, 0);
	  _for_exact := xpath_eval ('for/exact/text()', _ref, 0);
	  i := 0; l := length (_if_inv);
	  while (i < l)
	    {
	      declare elm varchar;
	      elm := cast (_if_inv[i] as varchar);
	      delete from WS_REFERRALS where R_ID = elm;
	      i := i + 1;
	    }
	  i := 0; l := length (_go);
	  go_via := vector ();
	  while (i < l)
	    {
	      go_via := vector_concat (go_via, vector (cast (_go[i] as varchar)));
	      i := i + 1;
	    }
	  if (i)
	    go_via := serialize (go_via);
	  else
	    go_via := NULL;
	  i := 0; l := length (_for_pref);
	  declare expiry datetime;
	  _if_ttl := _if_ttl / 1000; -- make it seconds
	  if (_if_ttl <= 0)
	    _if_ttl := 3600*24; -- one day
	  expiry := dateadd ('second', _if_ttl, now());
	  declare exit handler for sqlstate '23000' {
	       rollback work;
	       if (is_reg)
		 {
		   action := 'http://schemas.xmlsoap.org/ws/2001/10/referral#registrationResponse';
		   return (
		    '<S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/">
		    <S:Body>
		    <S:Fault xmlns:r="http://schemas.xmlsoap.org/ws/2001/10/referral">
		    <faultcode>r:registrationFault</faultcode>
		    <faultstring>Registration Fault</faultstring>
		    <detail>
		    <r:duplicate />
		    </detail>
		    </S:Fault>
		    </S:Body>
		    </S:Envelope>');
		 }
	     return NULL;
	   };
	  while (go_via is not null and (i < l))
	    {
	      declare elm varchar;
	      elm := cast (_for_pref[i] as varchar);
	      elm := concat (elm, '%');
	      insert into WS_REFERRALS (R_ID, R_FOR, R_GO, R_EXPIRY, R_URL)
		  values (_refid, elm, go_via, expiry, this_url);
	      i := i + 1;
	    }
	  i := 0; l := length (_for_exact);
	  while (go_via is not null and (i < l))
	    {
	      declare elm varchar;
	      elm := cast (_for_exact[i] as varchar);
	      insert into WS_REFERRALS (R_ID, R_FOR, R_GO, R_EXPIRY, R_URL)
		  values (_refid, elm, go_via, expiry, this_url);
	      i := i + 1;
	    }
	}
       -- if all is OK
       if (is_reg)
         {
	   action := 'http://schemas.xmlsoap.org/ws/2001/10/referral#registrationResponse';
	   return ('<S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/">
	      <S:Body>
	       <r:registrationResponse xmlns:r="http://schemas.xmlsoap.org/ws/2001/10/referral"/>
	      </S:Body>
	    </S:Envelope>');
	 }

    }

  return NULL;
}
;

create procedure
SOAP_LOAD_SCH (in sch varchar, in udts any := null, in "array" int := 0, in do_result int := 1)
{
  declare ents, xte, xt, arr, xarr any;
  declare i, l int;
  declare name, udt, name1, tns1 varchar;
  if (isentity (sch))
    xte := sch;
  else
    xte := xml_tree_doc (sch);
  xt := xslt ('http://local.virt/soap_import_sch', xte);
  arr := xpath_eval ('/complexType|/element|/simpleType|/attribute', xt, 0);
  l := length (arr);
  if (not "array")
    {
      if (do_result)
        result_names (name, udt);
    }
  else
    xarr := make_array (l, 'any');
  if (isnull (udts))
    udts := vector ();
  while (i < l)
    {
      declare frag, udtn any;
      frag := xml_cut (arr[i]);
      frag := xslt ('http://local.virt/xslt_copy', frag);
      name1 := cast(xpath_eval ('string(/@name)', frag, 1) as varchar);
      tns1 := cast(xpath_eval ('string(/@targetNamespace)', frag, 1) as varchar);
      if (tns1 is not null and tns1 <> '')
	name1 := sprintf ('%s:%s', tns1, name1);
      udt := null;
      if (not "array")
	{
	  if (get_keyword (name1, udts, '') <> '')
	    {
	      udtn := get_keyword (name1, udts, '');
	      udt := udtn;
	      name := soap_dt_define ('', frag, udtn);
	    }
	  else
	    name := soap_dt_define ('', frag);
	  if (do_result)
	    result (name, udt);
	}
      else if ("array" < 0)
        {
	  aset (xarr, i, frag);
        }
      else
	{
	  declare xte1 any;

          xte1 := xslt ('http://local.virt/soap_sch', frag, vector ('udt_struct', 0, 'any_type', 1));
	  aset (xarr, i, xte1);
	}
      i := i + 1;
    }
  return xarr;
}
;

--!AWK PUBLIC
create procedure
DB.DBA.WSDL_SPLIT_NAME (in url varchar, in part int)
{
  declare pos int;
  declare ret varchar;
  if (not isstring (url))
    return '';
  pos := strrchr (url, ':');
  if (pos is not null)
    {
      if (part)
        {
          ret := substring (url, pos + 2, length (url));
        }
      else
        {
          ret := substring (url, 1, pos);
        }
    }
  else
    return url;
  return ret;
}
;

insert soft DB.DBA.SYS_XPF_EXTENSIONS (XPE_NAME, XPE_PNAME) VALUES ('http://www.openlinksw.com/wsdl/:split-name',
'DB.DBA.WSDL_SPLIT_NAME')
;

xpf_extension ('http://www.openlinksw.com/wsdl/:split-name', 'DB.DBA.WSDL_SPLIT_NAME', 0)
;

create procedure
WSDL_IMPORT_TYPES (inout mid any)
{
  declare xp, tp any;
  declare i, l, inx, len int;
  xp := xpath_eval ('[ xmlns:xsd="http://www.w3.org/2001/XMLSchema" ] //xsd:schema', mid, 0);
  i := 0; l := length (xp);
  while (i < l)
    {
      declare ent any;
      ent := xml_cut (xp[i]);
      tp := SOAP_LOAD_SCH (ent, null, -1);
      inx := 0; len := length (tp);
      while (inx < len)
        {
          declare elm any;
          declare name1, tns1, name2, is_elem varchar;
          elm := tp[inx];
          name1 := cast(xpath_eval ('string(/@name)', elm, 1) as varchar);
          tns1 := cast(xpath_eval ('string(/@targetNamespace)', elm, 1) as varchar);
          is_elem := xpath_eval ('boolean (element)', elm, 1);
          if (tns1 is not null and tns1 <> '')
            name1 := sprintf ('%s:%s', tns1, name1);
	  if (not exists (select 1 from SYS_SOAP_DATATYPES where SDT_NAME = name1 and SDT_TYPE = is_elem))
	    {
	      name2 := soap_dt_define ('', elm);
              --dbg_obj_print (name1, '->', name2, ' is elem: ', is_elem);
	    }
          inx := inx + 1;
        }
      i := i + 1;
    }
}
;

create procedure
EXECUTE_SCRIPT (inout ses any)
{
  declare cmd, dbg any;
  declare line varchar;
  declare i, is_drop, ctr, offs int;
  commit work;
  cmd := null;
  ctr := 0;
  while (1)
    {
      line := ses_read_line (ses, 0);
      ctr := ctr + 1;
      if (not isstring (line))
	return;
      if (cmd is null and (line like 'create %' or line like 'drop %'))
	{
          cmd := string_output ();
          dbg := string_output ();
          is_drop := 0;
          if (line like 'drop %')
            is_drop := 1;
          i := 1;
          offs := ctr;
        }
      if (rtrim(line) = ';')
	{
	  declare stmt, stat, msg varchar;
          stmt := string_output_string (cmd);
          stat := '00000'; msg := '';
          exec (stmt, stat, msg);
          if (stat = '00000')
	    {
	      commit work;
	    }
          else
	    {
	      rollback work;
	      if (not is_drop)
		{
		  log_message (sprintf ('VSPX: %s %s',stat, msg));
		  dbg_obj_print (string_output_string (dbg));
		}
	      if (not (stmt like 'drop %'))
		signal (stat, concat (msg, sprintf ('; at offset: %d', offs), '\nwhile executing the following statement:\n', stmt));
	    }
          cmd := null;
          dbg := null;
	}
      if (cmd is not null)
	{
          http (line, cmd);
          http ('\n', cmd);
	  http (sprintf ('%03d ', i), dbg);
          http (line, dbg);
          http ('\n', dbg);
          i := i + 1;
	}
    }
  return NULL;
}
;

create procedure
WSDL_IMPORT_UDT (in url varchar, in f varchar := null, in exec int := 0)
{
  declare res, ses, xe, mid any;
  declare resource_text, src varchar;

  resource_text := XML_URI_GET ('', url);
  xe := xtree_doc (resource_text, 0, url);
  res := xslt ('http://local.virt/wsdl_expand', xe);

  mid := xslt ('http://local.virt/wsdl_parts', res);

  -- Generate UDT
  res := xslt ('http://local.virt/wsdl_import', mid, vector ('wsdlURI', url));
  ses := string_output ();
  http_value (res, null, ses);
  src := string_output_string (ses);

  if (f is not null)
    string_to_file (f, src, -2);

  -- define types
  WSDL_IMPORT_TYPES (mid);
  -- replay the file
  if (exec)
    EXECUTE_SCRIPT (ses);

  return src;
}
;

-- XML-RPC filters

--!AWK PUBLIC
create procedure
DB.DBA.XML_RPC_GET_PARAM_NAME (in proc varchar, in ordinal int)
{
  declare pars, proc1 any;
  declare elm any;
  proc1 := __proc_exists (proc);
  if (proc1 is not null)
    pars := procedure_cols (proc1);
  else
    pars := procedure_cols (complete_proc_name (proc,1));
  if (not isarray(pars) or length (pars) < ordinal)
    return 'param';
  if (pars[0][3] = '')
    ordinal := ordinal + 1;
  elm := pars[ordinal - 1];
  return elm[3];
}
;

--!AWK PUBLIC
create procedure
DB.DBA.XML_RPC_MAKE_ELT_NAME (in val varchar)
{
  if (val like '[0-9]%')
    val := '_'||val;
  val := sprintf ('%U', val);
  val := replace (val, '/', '%2F');
  val := replace (val, '%', '_x');
  return val;
}
;

--grant execute on DB.DBA.XML_RPC_GET_PARAM_NAME to public
--;

insert soft DB.DBA.SYS_XPF_EXTENSIONS (XPE_NAME, XPE_PNAME)
       VALUES ('http://www.openlinksw.com/xmlrpc/:getParamName', 'DB.DBA.XML_RPC_GET_PARAM_NAME')
;

xpf_extension ('http://www.openlinksw.com/xmlrpc/:getParamName', 'DB.DBA.XML_RPC_GET_PARAM_NAME', 0)
;

insert soft DB.DBA.SYS_XPF_EXTENSIONS (XPE_NAME, XPE_PNAME)
       VALUES ('http://www.openlinksw.com/xmlrpc/:makeElementName', 'DB.DBA.XML_RPC_MAKE_ELT_NAME')
;

xpf_extension ('http://www.openlinksw.com/xmlrpc/:makeElementName', 'DB.DBA.XML_RPC_MAKE_ELT_NAME', 0)
;

--!AWK PUBLIC
create procedure DB.DBA.XML_RPC_DATE_CVT (in dt varchar)
{
  declare ts any;
  if (dt not like '____-__-__T__:__:__.%')
    return dt;
  ts := stringdate (dt);
  ts := dt_set_tz (ts, 0);
  return soap_print_box (ts, '', 0);
}
;

insert soft DB.DBA.SYS_XPF_EXTENSIONS (XPE_NAME, XPE_PNAME)
       VALUES ('http://www.openlinksw.com/xmlrpc/:getGMTtime', 'DB.DBA.XML_RPC_DATE_CVT')
;

xpf_extension ('http://www.openlinksw.com/xmlrpc/:getGMTtime', 'DB.DBA.XML_RPC_DATE_CVT', 0)
;


create procedure
XMLRPC_MAKE_ERROR (in code varchar, in state varchar, in message varchar)
{
return
'<?xml version="1.0"?>\n' ||
'  <methodResponse>\n' ||
'   <fault>\n' ||
'    <value>\n' ||
'      <struct>\n' ||
'         <member>\n' ||
'            <name>faultCode</name>\n' ||
'            <value><int>' || code || '</int></value>\n' ||
'         </member>\n' ||
'      <member>\n' ||
'        <name>faultString</name>\n' ||
'        <value>\n' ||
'          <string>' || sprintf ('%V', message) ||'</string>\n' ||
'        </value>\n' ||
'      </member>\n' ||
'    </struct>\n' ||
'  </value>\n' ||
'</fault>\n' ||
'</methodResponse>' ;
}
;

-- XMLRPC Server wrapper

--!AWK PUBLIC
create procedure
XMLRPC_SERVER (in path any, in params any, in lines any)
{
  declare content_type, soap_xml varchar;
  declare req_body, resp_body varchar;
  declare soap_req any;
  declare soap_resp any;
  declare result any;

  if (length (params) < 1) params := __http_stream_params ();

  content_type := http_request_header (lines, 'Content-Type');
  --dbg_obj_print (lines);

  if (content_type = 'text/xml')
    {
      req_body := http_body_read ();
      soap_xml := xml_tree_doc (xml_tree (req_body));
    }
  else
    {
      http_request_status ('HTTP/1.1 400 Bad request');
      signal ('42000', 'Unsupported media type');
    }

  http_header ('Content-Type: text/xml; charset="utf-8"\r\n');

  set http_charset='UTF-8';

  declare exit handler for SQLSTATE '*' {
    declare err_msg varchar;
    http_rewrite ();
    rollback work;
    err_msg := xmlrpc_make_error ('300', __SQL_STATE, __SQL_MESSAGE);
    if (registry_get ('__debug_xmlrpc') = '1')
      dbg_obj_print (err_msg);
    http (err_msg);
    resignal 'VSPRT';
  };

   set_user_id (http_map_get ('soap_uid'), 0);
   if (registry_get ('__debug_xmlrpc') = '1')
     dbg_obj_print ('XML-RPC request:', soap_xml);
   soap_req := xslt ('http://local.virt/xmlrpc_soap', soap_xml);
   --dbg_obj_print ('req', soap_xml);
   resp_body := soap_server (soap_req, '', lines, 11);
   --dbg_obj_print (replace (resp_body, '\r', '\n'));
   soap_resp := xml_tree_doc (resp_body);
   result := xslt ('http://local.virt/soap_xmlrpc', soap_resp);
   if (registry_get ('__debug_xmlrpc') = '1')
     dbg_obj_print ('XML-RPC response:', result);
   http_value (result);
}
;

-- XMLRPC converters

create procedure
XMLRPC2SOAP (INOUT BODY VARCHAR)
{
  declare tmp, ret, ses any;
  {
    declare exit handler for sqlstate '*'
      {
	signal ('42000', 'Not well formed XMLRPC response.', 'SP036');
      };
    if (registry_get ('__debug_xmlrpc') = '1')
      dbg_obj_print (BODY);
    tmp := xml_tree_doc (BODY);
  }
  ret := xslt ('http://local.virt/xmlrpc_soap', tmp, vector ('call', '1'));
  ses := string_output ();
  http_value (ret, null, ses);
  BODY := string_output_string (ses);
}
;

create procedure
SOAP2XMLRPC (INOUT BODY VARCHAR)
{
  declare tmp, ret, body_str any;
  body_str := string_output_string (BODY);
  if (registry_get ('__debug_xmlrpc') = '1')
    dbg_obj_print (body_str);
  tmp := xml_tree_doc (body_str);
  ret := xslt ('http://local.virt/soap_xmlrpc', tmp, vector ('call', '1'));
  if (registry_get ('__debug_xmlrpc') = '1')
    dbg_obj_print (ret);
  string_output_flush (BODY);
  http_value (ret, null, BODY);
}
;

-- XMLRPC CLIENT WRAPPER

--!AWK PUBLIC
create procedure
XMLRPC_CALL (in uri varchar, in meth varchar, in params any, in id any := null)
{
  declare i, l int;
  declare pars, ret, hinfo, res any;

  l := length (params);
  i := 0;
  pars := vector ();

  while (i < l)
    {
      pars := vector_concat (pars, vector (sprintf ('param%d', i), params[i]));
      i := i + 1;
    }
  hinfo := rfc1808_parse_uri (uri);
  res := soap_call_new (hinfo[1], hinfo[2], null, meth, pars, 11, null, null, null, 32, null, null, 0, null, null, null, id);
  return res;
}
;

--!AWK PUBLIC
create procedure
SOAP12_ROUTER (in uri varchar, in this_url varchar, in header any, in body any)
{
  declare req varchar;
  declare resp varchar;
  declare hd, head any;
  declare host varchar;
  declare ss any;
  ss := string_output ();

  req := xml_tree_doc (xmlconcat (xml_tree_doc (header), xml_tree_doc (body)));
  req := xslt ('http://local.virt/soap12_router', req, vector ('this', this_url));
  req := serialize_to_UTF8_xml (req);
  http (req, ss);

  hd := rfc1808_parse_uri (uri);

  host := hd[1];

  head := vector (
  sprintf ('POST %s HTTP/1.1\r\n', hd[2]),
  'Content-Type: application/soap+xml; charset="utf-8"\r\n',
  sprintf ('Content-Length: %d\r\n', length (req))
  );

  http_proxy (host, head, ss);
}
;

create procedure
DB.DBA.SOAP_WS_TRUST_XENC_TEMPLATE (in body varchar)
{
  declare tmpl, _user, _pass varchar;
  _user := cast (connection_get ('__soap_ws_trust_user') as varchar);
  _pass := cast (connection_get ('__soap_ws_trust_pass') as varchar);
  tmpl := sprintf ('<?xml version="1.0" encoding="utf-8"?><Signature xmlns="http://www.w3.org/2000/09/xmldsig#" xmlns:wsu="http://schemas.xmlsoap.org/ws/2002/07/utility" xmlns:wsse="http://schemas.xmlsoap.org/ws/2002/12/secext"> <SignedInfo><CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/><SignatureMethod Algorithm="http://www.w3.org/2000/09/xmldsig#hmac-sha1"/></SignedInfo><SignatureValue /><KeyInfo><KeyValue><wsse:UsernameToken><wsse:Username>%s</wsse:Username><wsse:Password Type="wsse:PasswordText">%s</wsse:Password></wsse:UsernameToken></KeyValue></KeyInfo></Signature>', _user, _pass);
    return dsig_template_ext (xtree_doc (body), tmpl,
	'http://schemas.xmlsoap.org/soap/envelope/', 'Body',
	'http://schemas.xmlsoap.org/ws/2002/07/utility', 'Expires',
	'http://schemas.xmlsoap.org/ws/2002/07/utility', 'Created',
	'http://schemas.xmlsoap.org/ws/2003/03/addressing', 'To',
	'http://schemas.xmlsoap.org/ws/2003/03/addressing', 'MessageID',
	'http://schemas.xmlsoap.org/ws/2003/03/addressing', 'From',
	'http://schemas.xmlsoap.org/ws/2003/03/addressing', 'Action');
}
;

create table SYS_SOAP_UDT_PUB (SUP_CLASS varchar,
			   SUP_LHOST varchar,
			   SUP_HOST varchar,
			   SUP_END_POINT varchar,
			   primary key (SUP_LHOST, SUP_HOST, SUP_END_POINT, SUP_CLASS))
;

create trigger HTTP_PATH_D_UDT_PUB after delete on DB.DBA.HTTP_PATH
{
  delete from SYS_SOAP_UDT_PUB where SUP_LHOST = HP_LISTEN_HOST and
           SUP_HOST = HP_HOST and SUP_END_POINT = HP_LPATH;
}
;

create trigger SOAP_UDT_PUB_I before insert on SYS_SOAP_UDT_PUB
{
  if (not exists
	(select 1 from DB.DBA.HTTP_PATH
	where SUP_LHOST = HP_LISTEN_HOST and SUP_HOST = HP_HOST and SUP_END_POINT = HP_LPATH
	))
    signal ('22023', 'No such virtual directory defined');
  __soap_udt_publish (SUP_HOST, SUP_LHOST, SUP_END_POINT, SUP_CLASS);
}
;


create trigger SOAP_UDT_PUB_U before update on SYS_SOAP_UDT_PUB referencing old as O, new as N
{
  __soap_udt_unpublish (O.SUP_HOST, O.SUP_LHOST, O.SUP_END_POINT, O.SUP_CLASS);
  __soap_udt_publish (O.SUP_HOST, O.SUP_LHOST, N.SUP_END_POINT, N.SUP_CLASS);
}
;


create trigger SOAP_UDT_PUB_D before delete on SYS_SOAP_UDT_PUB
{
  __soap_udt_unpublish (SUP_HOST, SUP_LHOST, SUP_END_POINT, SUP_CLASS);
}
;

--!AWK PUBLIC
create procedure GET_XSD_EXTENSION (in nam varchar)
{
  declare ext any;
  ext := (select xslt('http://local.virt/soap_sch', xml_tree_doc (sdt_sch)) from sys_soap_datatypes where sdt_name = nam and sdt_type = 0);
  if (ext is null)
    return xml_tree_doc ('<fake/>');
  return ext;
}
;

insert soft DB.DBA.SYS_XPF_EXTENSIONS (XPE_NAME, XPE_PNAME) VALUES
('http://www.openlinksw.com/virtuoso/soap:getExtension', 'DB.DBA.GET_XSD_EXTENSION')
;


xpf_extension ('http://www.openlinksw.com/virtuoso/soap:getExtension', 'DB.DBA.GET_XSD_EXTENSION', 0)
;


create procedure DB.DBA.WS_MIME_ENV (in _all any, in call_mode integer)
{
  declare _inx, _len integer;
  declare _res, _bnd, _c_type varchar;
  declare _part, temp, hdr any;

  _bnd := concat ('-','-','-','-', md5 (cast (now () as varchar)));

  temp := '<uuid:' || uuid () || '>';
  temp := '<' || uuid () || '>';

  _c_type := sprintf ('multipart/related; boundary="%s"; type="text/xml"; start="%s"', _bnd, temp);

  if (call_mode)
    {
       hdr := (concat ('Content-Type: ', _c_type, '\r\n'));
       _res := '\r\n\r\n';
    }
  else
    {
       hdr := _c_type;
       _res := '';
    }

  _inx := 0;
  _len := length (_all);

  while (_inx < _len)
    {
      declare c_id, c_type any;

      _part := aref (_all, _inx);

      if (_inx = 0)
        {
          c_id := temp;
          c_type := 'text/xml';
        }
      else
        {
          c_id := '<' || replace (_part[0], 'cid:', '', 1) || '>';
          c_type := _part[1];
        }

      _res := concat (_res, '-','-', _bnd, '\r\n');
      _res := concat (_res, 'Content-Type: ', c_type, '\r\n');
      _res := concat (_res, 'Content-Transfer-Encoding: binary\r\n');
      _res := concat (_res, 'Content-ID: ', c_id, '\r\n\r\n');
      _res := concat (_res, aref (_part, 2), '\r\n');
      _inx := _inx + 1;
    }
  _res := concat (_res, '-','-', _bnd, '-','-\r\n');

  return vector (_res, hdr);
}
;


create procedure DB.DBA.WS_MIME_RESP_C (in _all any)
{
  return DB.DBA.WS_MIME_ENV (_all, 0);
}
;

create procedure DB.DBA.WS_MIME_RESP (in _all any)
{
  return DB.DBA.WS_MIME_ENV (_all, 1);
}
;

grant execute on DB.DBA.WS_MIME_RESP to public
;

grant execute on DB.DBA.WS_MIME_RESP_C to public
;

create procedure vsmx_user_check (in name varchar, in pass varchar)
{
  return 1;
}
;

--!AWK PUBLIC
create procedure
DB.DBA.SOAP_VSMX (in path any, in params any, in lines any)
{ ?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN"
 "http://www.w3.org/TR/1999/REC-html401-19991224/loose.dtd">
<HTML>
 <HEAD>
<STYLE>
BODY
{
    MARGIN-TOP: 0px;
    FONT-SIZE: 80%;
    MARGIN-LEFT: 0em;
    COLOR: #000000;
    MARGIN-RIGHT: 0em;
    FONT-FAMILY: Verdana, 'MS Serif', Serif;
    BACKGROUND-COLOR: #ffffff
}
.head1
{
    PADDING-BOTTOM: 5px;
    MARGIN-LEFT: -3em;
    COLOR: #191970;
    LINE-HEIGHT: normal;
    MARGIN-RIGHT: -3em;
    PADDING-TOP: 5px;
    BORDER-BOTTOM: navy thin solid;
    FONT-FAMILY: Verdana, Arial, Helvetica, Lucida, Sans-Serif;
    BACKGROUND-COLOR: skyblue;
    TEXT-ALIGN: right
}
DIV.foot
{
    CLEAR: left;
    BORDER-TOP: lightslategray thin solid;
    FONT-SIZE: 10px;
    LINE-HEIGHT: normal;
    FONT-FAMILY: Verdana, Arial, Helvetica, Lucida, Sans-Serif;
    TEXT-ALIGN: right
}
H1
{
    PADDING-RIGHT: 3em;
    MARGIN-TOP: 5px;
    FONT-SIZE: 185%;
    MARGIN-BOTTOM: 5px;
    MARGIN-LEFT: 0em
}
A
{
    COLOR: blue;
    TEXT-DECORATION: none
}
A:hover
{
    TEXT-DECORATION: underline
}
.operation
{
    PADDING-RIGHT: 10px;
    PADDING-LEFT: 30px;
    PADDING-BOTTOM: 10px;
    PADDING-TOP: 10px;
    VERTICAL-ALIGN: top;
}
.soaplist
{
    VERTICAL-ALIGN: top;
    PADDING-RIGHT: 5px;
    PADDING-LEFT: 25px;
    PADDING-BOTTOM: 10px;
    MARGIN: 0px;
    WIDTH: 225px;
    PADDING-TOP: 10px;
    BACKGROUND-COLOR: gainsboro
}
.soapdesc
{
    FONT-SIZE: 90%;
    FONT-FAMILY: Tahoma
}
INPUT
{
    BORDER-RIGHT: silver 1px solid;
    BORDER-TOP: silver 1px solid;
    BORDER-LEFT: silver 1px solid;
    BORDER-BOTTOM: silver 1px solid;
    FONT-FAMILY: Tahoma
}
.btns
{
    TEXT-ALIGN: right
}
TABLE.service
{
    BORDER-RIGHT: #ebebeb 1px solid;
    BORDER-TOP: #ebebeb 1px solid;
    BORDER-LEFT: #ebebeb 1px solid;
    BORDER-BOTTOM: #ebebeb 1px solid;
    FONT-FAMILY: Tahoma
}
TH.service
{
    BACKGROUND-COLOR: silver;
    TEXT-ALIGN: left
}
H2
{
    FONT-SIZE: 150%;
    MARGIN-LEFT: -20px
}
H3
{
    FONT-SIZE: 120%;
    MARGIN-BOTTOM: 0px;
    MARGIN-LEFT: -10px
}
.soapli
{
    PADDING-BOTTOM: 5px;
    TEXT-INDENT: -20px
}
TD.service
{
    BACKGROUND-COLOR: #f0f0f0
}
.response
{
    BORDER-RIGHT: #f0f0f0 1px solid;
    PADDING-RIGHT: 2px;
    BORDER-TOP: #f0f0f0 1px solid;
    PADDING-LEFT: 2px;
    PADDING-BOTTOM: 2px;
    BORDER-LEFT: #f0f0f0 1px solid;
    PADDING-TOP: 2px;
    BORDER-BOTTOM: #f0f0f0 1px solid
}
.details
{
    PADDING-RIGHT: 2px;
    PADDING-LEFT: 30px;
    PADDING-BOTTOM: 2px;
    PADDING-TOP: 10px;
    BACKGROUND-COLOR: #f0f0f0;
    TEXT-ALIGN: left
}
.level1
{
    COLOR: blue
}
.level2
{
    COLOR: red
}
.level3
{
    COLOR: green
}
.level4
{
    COLOR: teal
}
.attribname
{
    TEXT-ALIGN: right;
}
.attrib
{
    COLOR: #990000
}
</STYLE>
<TITLE>Web Service Testing</TITLE>
 </HEAD>
 <BODY>
<DIV class="head1"><H1>Web Services Test Page (VSMX)</H1></DIV>
<?vsp
 declare this_page varchar;
 declare wsdl any;
 declare inx, len, _u_id integer;
 this_page := 'services.vsmx';
 set http_charset='UTF-8';
 http_header ('Cache-Control: no-cache, must-revalidate\r\nPragma: no-cache\r\nExpires: Thu, 01 Dec 1994 01:02:03 GMT\r\n');

?>
<DIV class="soappage">
<TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0">
<TR><TD class="soaplist">
<H2>Services Available</H2>
<?vsp
     declare xt any;
     wsdl := soap_wsdl();
     if (not (registry_get ('old_vsmx') = '1') and isstring (file_stat (http_root()||'/vsmx/oper.vspx')))
       {
         declare sid any;
         sid := vspx_sid_generate ();
         insert into VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
		values ('vsmx', sid, null,
		serialize (vector ('wsdl', wsdl, 'loc', WS.WS.EXPAND_URL (HTTP_REQUESTED_URL(),'services.wsdl'))),
		now ());
         http_request_status ('HTTP/1.1 302 Found');
         http_header (sprintf ('Location: /vsmx/oper.vspx?sid=%s&realm=vsmx\r\n', sid));
         http_rewrite ();
         return;
       }
     xt := xml_tree_doc (wsdl);
     inx := 0;
     _u_id := (select top 1 U_ID from DB.DBA.SYS_USERS where U_NAME = http_map_get ('soap_uid'));
     for select 0 as TP, P_NAME as operation, coalesce (P_TEXT, blob_to_string (P_MORE)) as content
       from DB.DBA.SYS_PROCEDURES where (name_part (P_NAME, 0) = http_map_get ('soap_qual')
	   and name_part (P_NAME,1) = http_map_get ('soap_uid'))
	   or exists (select 1 from DB.DBA.SYS_GRANTS where G_USER = _u_id and G_OP = 32 and G_OBJECT = P_NAME)

	   union select 0 as TP, G_OBJECT as operation, '' as content from DB.DBA.SYS_GRANTS where
	   G_USER = _u_id and G_OP = 32 and __proc_exists (G_OBJECT) is not null
	   and not exists (select 1 from DB.DBA.SYS_PROCEDURES where G_OBJECT = P_NAME)

           union select 1 as TP, M_NAME as operation, blob_to_string (M_TEXT) as content
		from DB.DBA.SYS_METHODS, DB.DBA.SYS_USER_TYPES where M_ID = UT_ID and
	   exists (select 1 from DB.DBA.SYS_GRANTS where G_USER = _u_id and G_OP = 32 and G_OBJECT = UT_NAME)
	   do
       {
	 declare comments, title, elm, operation1, q, o varchar;

	 q := name_part (operation, 0);
	 o := name_part (operation, 1);

         if (TP = 1)
           operation1 := operation;
	 else if ((length (q) + length (o) + 3) < length (operation))
	   operation1 := substring (operation, length (q) + length (o) + 3, length (operation));
	 else
	   goto nxt;

	 operation := operation1;

         elm := xpath_eval (sprintf ('/definitions/portType/operation[@name = \'%s\']', operation), xt);
	 if (elm is null)
	   goto nxt;
         title := regexp_match ('--##.*', content);
         if (title is null)
           title := '';
	 else
	   title := substring (title, 5, length (title));
?>
    <DIV class="soapli"><A href="<?=this_page?>?operation=<?=operation?>"><?=operation?></A><BR />
    <SPAN class="soapdesc"><?=title?></SPAN></DIV>
<?vsp
        inx := inx + 1;
nxt:;
       }
?>
</TD>
<TD class="operation">
<?vsp

   if ({?'operation'} is not null )
   {
     declare xe, pars any;
     declare xps, url varchar;
     wsdl := soap_wsdl();
     xe := xml_tree_doc (wsdl);
     if (xpath_eval (sprintf ('/definitions/binding/operation[@name="%s"]/operation[@style="document"]', {?'operation'}), xe) is null)
       {
         xps := sprintf ('/definitions/message[@name = \'%sRequest\']/part', {?'operation'});
       }
     else if (xpath_eval (sprintf ('/definitions/message[@name = \'%sRequest\']/part[@name="parameters"]', {?'operation'}), xe) is not null)
       {
         declare elm_name any;
         declare pos int;

         xps := sprintf ('/definitions/message[@name = \'%sRequest\']/part/@element', {?'operation'});
         elm_name := cast (xpath_eval (xps, xe) as varchar);
         pos := strrchr (elm_name, ':');
         if (pos is not null)
           {
             elm_name := subseq (elm_name, pos + 1, length (elm_name));
           }
         xps := sprintf ('/definitions/types/schema/element[@name = "%s"]//element', elm_name);
       }
     else
       {
         xps := sprintf ('/definitions/message[@name = \'%sRequest\']/part', {?'operation'});
       }

     pars := xpath_eval (xps, xe, 0);
     url := cast (xpath_eval ('/definitions/service/port/address/@location', xe, 1) as varchar);
     len := length (pars);
     inx := 0;
?>
<H2><?={?'operation'}?></H2>
<H3>Details</H3>
<P>The service end point is: <?=url?></P>
<P>The WSDL end point is: <A href="<?=url?>/services.wsdl"><?=url?>/services.wsdl</A></P>
<H3>Test</H3>
    <FORM method="POST" action="<?=this_page?>">
    <INPUT type="hidden" name="operation" value="<?={?'operation'}?>" >
    <INPUT type="hidden" name="url" value="<?=url?>" >
<TABLE class="service" border="0" cellpadding="2" cellspacing="2">
<TR>
  <TH class="service">Parameter</TH>
  <TH class="service">Value</TH>
  <TH class="service">Type</TH>
</TR>
<?vsp
     while (inx < len)
       {
	 declare n, t varchar;
         n := xpath_eval ('@name', pars[inx], 1);
         t := xpath_eval ('@type', pars[inx], 1);
         n := cast (n as varchar); t := cast (t as varchar);
         if (t like 'http://www.w3.org/____/XMLSchema:%')
	   {
	     t := substring (t, length ('http://www.w3.org/____/XMLSchema:') + 1, length (t));
	     t := concat ('xsd:', t);
	   }
	 else if (strchr (t, ':') is not null and t not like 'xsd:%')
	   {
	     declare colon integer;
             colon := strrchr (t, ':');
             t := substring (t, colon + 1, length (t));
	     t := concat ('s', t);
	   }
?>
    <TR>
      <TD class="service"><?=n?></TD>
      <?vsp if (t like 'xsd:%') { ?>
      <TD class="service"><input type="text" name="<?=n?>" size="40" /></TD>
      <?vsp } else { ?>
      <TD class="service"><textarea name="<?=n?>" rows=10 cols="40"><?vsp
	 if (t like '_:%' and t not like '_:ArrayOf%')
	   {
	     declare struct, t1 any;
	     declare i, l integer;
             t1 := substring (t, 3, length (t));
             xps :=
        sprintf ('/definitions/types/schema/complexType[@name = ''%s'']/*/element/@name', t1);
             struct := xpath_eval (xps, xe, 0);
             i := 0; l := length (struct);
	     while (i < l)
	       {
		 http (cast (struct[i] as varchar));
		 http ('=\r\n');
                 i := i + 1;
	       }
	   }
      ?></textarea></TD>
      <?vsp } ?>
      <TD class="service"><SPAN class="datatype"><?=t?></SPAN>
        <input type="hidden" name="<?=n?>_type" value="<?=t?>"></TD>
    </TR>
<?vsp
         inx := inx + 1;
       }
     if (not inx)
       {
?>
    <TR><TD class="service" colspan="2">No input parameters are required for this service.</TD></TR>
<?vsp
       }
?>
    <TR><TD class="btns" colspan="2"><input type="submit" name="callit" value="Invoke"></TD></TR>
    </TABLE>
    </form>
<?vsp
   }

  if ({?'operation'} is not null and {?'callit'} is not null)
  {
    declare hinfo, result, ver, pars1, _url any;
    declare xe, xps, pars any;
    wsdl := soap_wsdl();
    xe := xml_tree_doc (wsdl);
    _url := {?'url'};
    hinfo := rfc1808_parse_uri ({?'url'});

    if (xpath_eval (sprintf ('/definitions/binding/operation[@name="%s"]/operation[@style="document"]', {?'operation'}), xe) is null)
      {
        xps := sprintf ('/definitions/message[@name = \'%sRequest\']/part', {?'operation'});
      }
    else if (xpath_eval (sprintf ('/definitions/message[@name = \'%sRequest\']/part[@name="parameters"]', {?'operation'}), xe) is not null)
      {
        declare elm_name any;
        declare pos int;

        xps := sprintf ('/definitions/message[@name = \'%sRequest\']/part/@element', {?'operation'});
        elm_name := cast (xpath_eval (xps, xe) as varchar);
        pos := strrchr (elm_name, ':');
        if (pos is not null)
          {
            elm_name := subseq (elm_name, pos + 1, length (elm_name));
          }
        xps := sprintf ('/definitions/types/schema/element[@name = "%s"]//element', elm_name);
      }
    else
      {
        xps := sprintf ('/definitions/message[@name = \'%sRequest\']/part', {?'operation'});
      }
    pars := xpath_eval (xps, xe, 0);
    len := length (pars);
    inx := 0;
    pars1 := vector ();
    while (inx < len)
      {
      declare exit handler for sqlstate '*' {
        result := xml_tree_doc (sprintf ('<Error>
		      <Code>%V
		      </Code>
		      <Message>%V
		      </Message>
		      </Error>', __SQL_STATE, __SQL_MESSAGE));
	goto err;
      };
	 declare n, t, v, va varchar;
         n := xpath_eval ('@name', pars[inx], 1);
         t := xpath_eval ('@type', pars[inx], 1);
         n := cast (n as varchar); t := cast (t as varchar);
         if (t like 'http://www.w3.org/____/XMLSchema:%')
	   {
	     t := substring (t, length ('http://www.w3.org/____/XMLSchema:') + 1, length (t));
	     t := concat ('xsd:', t);
	   }
	 else if (strchr (t, ':') is not null and t not like 'xsd:%')
	   {
	     declare colon integer;
             colon := strrchr (t, ':');
             t := substring (t, colon + 1, length (t));
	     t := concat ('s', t);
	   }
         v := get_keyword (n, params);
	 if (t like '_:ArrayOf%')
	   {
             v := replace (v, '\r\n', '\n');
             va := split_and_decode (v, 0, '\0\0\n');
	     pars1 := vector_concat (pars1, vector (n, va));
	   }
	 else if (t like '_:%')
	   {
	     declare r, struct, rstr any;
	     declare i, l integer;
             v := replace (v, '\r\n', '\n');
             va := coalesce (split_and_decode (v, 0, '\0\0\n='), vector ());
             t := substring (t, 3, length (t));
             xps :=
        sprintf ('/definitions/types/schema/complexType[@name = ''%s'']/*/element/@name', t);
             struct := xpath_eval (xps, xe, 0);
             i := 0; l := length (struct);
	     rstr := vector (composite(), '<soap_box_structure>');
	     while (i < l)
	       {
		 declare part nvarchar;
                 part := get_keyword (struct[i], va);
                 part := charset_recode (part,'UTF-8','_WIDE_');
                 rstr := vector_concat (rstr, vector (cast (struct[i] as varchar), part));
                 i := i + 1;
	       }
	     pars1 := vector_concat (pars1, vector (n, rstr));
	   }
	 else if (t like '%:dateTime')
	   {
             v := charset_recode (v,'UTF-8','_WIDE_');
	     v := cast (v as varchar);
	     v := cast (v as datetime);
	     pars1 := vector_concat (pars1, vector (n, v));
	   }
	 else
	   {
             v := charset_recode (v,'UTF-8','_WIDE_');
	     pars1 := vector_concat (pars1, vector (n, v));
	   }
         inx := inx + 1;
      }

    ver := 11;
    {
      declare exit handler for sqlstate '*' {
        result := xml_tree_doc (sprintf ('<Error>
		      <Code>%V
		      </Code>
		      <Message>%V
		      </Message>
		      </Error>', __SQL_STATE, __SQL_MESSAGE));
	goto err;
      };
      if (atoi (virtuoso_ini_item_value ('HTTPServer', 'ServerThreads')) < 2)
	{
	    result := xml_tree_doc (sprintf ('<Error>
			  <Code>%V
			  </Code>
			  <Message>%V
			  </Message>
			  </Error>', '42000', 'At least two HTTP threads must be available'));
	    goto err;
	}
      else
	{
          result := DB.DBA.SOAP_CLIENT (url=>_url, operation=>{?'operation'}, parameters=>pars1, version=>ver);
	}
    }

    if (ver = 11)
      {
	if (result[0][0] <> ' root')
	  result := vector (vector(' root'), result);
        result := xml_tree_doc (result);
      }
    else
      {
        result := xml_tree_doc (sprintf ('<Error>
		      <Code>%V
		      </Code>
		      <Message>%V
		      </Message>
		      </Error>', ver[1], ver[2]));
      }
err:;
    declare ses any;
    ses := xslt ('__soap_vsmx', result, vector ('service', {?'operation'}));
    http_value (ses);
  }

?>
</TD></TR></TABLE>
</DIV>
<DIV class="foot"><SPAN class="foot">Virtuoso Universal Server <?=sys_stat('st_dbms_ver')?> - Copyright&copy; 1998-2016 OpenLink Software.</SPAN></DIV>
 </BODY>
</HTML>
<?vsp
}
;

--!AFTER
xslt_sheet ('__soap_vsmx', xml_tree_doc('<?xml version="1.0"?>
     <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
      <xsl:output method="html" indent="yes" encoding="UTF-8" />
      <xsl:param name="service" select="''''" />
      <xsl:param name="ret_uri" select="''services.vsmx''" />
      <xsl:template match="/">
      <H3>Response</H3>
        <BR />
	<DIV class="response"><xsl:apply-templates select="*">
	  <xsl:with-param name="level">1</xsl:with-param></xsl:apply-templates></DIV>
      </xsl:template>

      <xsl:template match="*"><xsl:param name="level" />
	  <DIV class="details">
	    <SPAN><xsl:attribute name="class">level<xsl:value-of select="$level" /></xsl:attribute>
	      <xsl:value-of select="local-name()"/>:</SPAN>
	    <xsl:if test="$level > 1">
	    <SPAN class="data"><xsl:value-of select="text()"/>
	      <xsl:if test="@*">
	        <BR /><TABLE border="0" cellpadding="0" cellspacing="2">
	        <xsl:for-each select="@*">
	         <xsl:if test="(namespace-uri(.) != ''urn:schemas-microsoft-com:datatypes'')
		   and (namespace-uri(.) != ''http://www.w3.org/2001/XMLSchema-instance'')
		   and (namespace-uri(.) != ''http://schemas.xmlsoap.org/soap/encoding/'')
		   and (namespace-uri(.) != ''urn:schemas-openlink-com:xml-sql'')">
	            <TR><TD class="attribname"><xsl:value-of select="local-name()" />=</TD>
		      <TD class="attrib">"<xsl:value-of select="." />"</TD></TR>
	         </xsl:if>
	        </xsl:for-each>
	        </TABLE>
              </xsl:if>
	    </SPAN>
	    </xsl:if>
            <xsl:apply-templates select="*">
	      <xsl:with-param name="level"><xsl:value-of select="$level+1" /></xsl:with-param>
	    </xsl:apply-templates>
	  </DIV>
	</xsl:template>
    </xsl:stylesheet>')
)
;

create procedure WSDL_EXPAND (in _base_url any, in rsv any, inout schem any, inout defs any, inout ret any)
{
  declare idx, len, idx1, len1, use_cache integer;
  declare _location, _what varchar;
  declare _new, _import, _base, sch, t1, t2 any;

  if (not isarray (schem)) schem := vector ();
  if (not isarray (defs))  defs := vector ();
  if (not rsv is NULL)  _base_url := WS.WS.EXPAND_URL (_base_url, rsv);

  use_cache := 0;

  _base := WSDL_GET (_base_url, use_cache);

  if (rsv is NULL)  ret := _base;

  sch := xpath_eval ('/definitions/import', _base, 0);

  if (length (t1 := xpath_eval ('/definitions/types/schema', _base, 0)) > 0) schem := vector_concat (t1, schem);
  if (length (t2 := xpath_eval ('/definitions', _base, 0)) > 0) defs := vector_concat (defs, t2);

  idx := 0; len := length (sch);
  while (idx < len)
    {
      _location := cast (xpath_eval ('@location', sch[idx], 1) as varchar);
      _import := WSDL_GET (WS.WS.EXPAND_URL (_base_url, _location), use_cache);
      _new := xpath_eval ('/definitions/import', _import, 0);
      if (length (t1 := xpath_eval ('/definitions/types/schema', _import, 0))>0) schem := vector_concat (schem, t1);
      if (length (t2 := xpath_eval ('/definitions', _import, 0)) > 0) defs := vector_concat (defs, t2);
      len1 := length (_new); idx1 := 0;
      if (length (_new) > 0)
        {
           while (idx1 < len1)
             {
		_what := cast (xpath_eval ('@location', _new[0], 1) as varchar);
		_base_url := WS.WS.EXPAND_URL (_base_url, _location);
		WSDL_EXPAND (_base_url, _what, schem, defs, ret);
                idx1 := idx1 + 1;
             }
        }
      idx := idx + 1;
    }
}
;


--!AWK PUBLIC
create procedure
DB.DBA.SOAP_WSDL_IMPORT (in url varchar, in mode_wsdl integer := 1, in wire_dump integer := 0, in drop_module integer := 0)
{
  declare wsdl, xp, xt, uri, hinfo, sch, ret, pt any;
  declare i, l, i1, l1, is_literal integer;
  declare err, name, tns, mname, stmt, transport varchar;
  declare port_name, port_name_last any;
  declare tt, dmod varchar;

  WSDL_EXPAND (url, NULL, sch, pt, wsdl);

  i1 := 0; l1 := length (sch);
  while (i1 < l1)
    {
      xp := xpath_eval ('complexType', sch[i1], 0);
      tns := xpath_eval ('@targetNamespace', sch[i1], 1);
      if (tns is not null)
	{
	  tns := cast (tns as varchar);
	  tns := concat (tns, ':');
	}
      else
	 tns := '';

      i := 0; l := length (xp);
      while (i < l)
	{
	  xt := xslt ('http://local.virt/soap_sch', xp[i]);
	  err := xpath_eval ('string(//@error)', xt, 1);
	  err := cast (err as varchar);
	  if (err <> '')
	    {
	      rollback work;
	      signal ('22023', err, 'SODT1');
	    }
	  name := cast(xpath_eval ('string(/complexType/@name)', xt, 1) as varchar);
	  if (not exists (select 1 from DB.DBA.SYS_SOAP_DATATYPES where SDT_NAME = concat (tns, name) and SDT_TYPE = 0))
	    {
	      insert soft DB.DBA.SYS_SOAP_DATATYPES (SDT_NAME,SDT_SCH,SDT_TYPE) values (concat(tns, name), xt, 0);
	      __soap_dt_define (concat(tns, name), xt);
	    }
	  i := i + 1;
	}
      xp := xpath_eval ('element', sch[i1], 0);
      i := 0; l := length (xp);
      while (i < l)
	{
          xt := xslt ('http://local.virt/soap_sch', xp[i], vector ('target_Namespace', rtrim(tns, ':')));
	  err := xpath_eval ('string(//@error)', xt, 1);
	  err := cast (err as varchar);
	  if (err <> '')
	    {
	      rollback work;
	      signal ('22023', err, 'SODT1');
	    }
	  name := cast(xpath_eval ('string(/element/@name)', xt, 1) as varchar);
	  if (not exists (select 1 from DB.DBA.SYS_SOAP_DATATYPES where SDT_NAME = concat (tns, name) and SDT_TYPE = 1))
	    {
	      insert soft DB.DBA.SYS_SOAP_DATATYPES (SDT_NAME,SDT_SCH,SDT_TYPE) values (concat(tns, name), xt, 1);
	      __soap_dt_define (concat(tns, name), xt, NULL, 1);
	    }
	  -- type of elements
	  {
	    declare cmpl, cname, cname2,  sch2 varchar;
	    cmpl := xpath_eval (sprintf ('element[%d]/complexType[*]', (i+1)), sch[i1], 1);
	    -- must test for child elements
	    if (cmpl is not null)
	      {
		declare name1 varchar;
                name1 := cast(xpath_eval (sprintf ('string(element[%d]/@name)' , (i+1)), sch[i1], 1) as varchar);
		cname := sprintf ('elementType__%s', name1);
		if (tns is null or tns = '')
		  cname2 := cname;
		else
		  cname2 := sprintf ('%s%s', tns, cname);
                sch2 := xslt ('http://local.virt/soap_sch', cmpl,
			  vector ('type_name', cname, 'target_Namespace', rtrim(tns, ':')));
		__soap_dt_define (cname2, sch2, sch2, 0);
		insert replacing DB.DBA.SYS_SOAP_DATATYPES (SDT_NAME,SDT_SCH, SDT_TYPE) values (cname2, sch2, 0);
	      }
	  }
	  i := i + 1;
	}
      i1 := i1 + 1;
    }
  declare extens any;
  declare ns_ext nvarchar;
  extens := xpath_eval ('[xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"] //*[@wsdl:required = "true"]', wsdl, 0);
  i1 := 0; l1 := length (extens);
  while (i1 < l1)
    {
      ns_ext := xpath_eval ('namespace-uri(.)', extens[i1], 1);
      if (ns_ext <> N'http://schemas.xmlsoap.org/wsdl/soap/')
	{
	  rollback work;
          signal ('22023', 'Not supported extensibility element', 'SODT2');
	}
      i1 := i1 + 1;
    }

  -- PL module generation
  mname := cast (xpath_eval ('/definitions/service/@name', wsdl, 1) as varchar);
  uri := cast (xpath_eval ('[xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"] /definitions/service/port/soap:address/@location', wsdl, 1) as varchar);
  hinfo := rfc1808_parse_uri (uri);

  stmt := concat ('CREATE MODULE ', DB.DBA.SYS_ALFANUM_NAME (mname), ' {\r\n');
  dmod := concat ('DROP MODULE ', DB.DBA.SYS_ALFANUM_NAME (mname));
  ret := vector (mname);
  i1 := 0; l1 := length (pt);
  while (i1 < l1)
    {
      if (not port_name is NULL or port_name <> 0) port_name_last := port_name;
      port_name := cast (xpath_eval ('/definitions/portType/@name', pt[i1], 1) as varchar);
      if (port_name is NULL) goto new_loop;
      if ((port_name_last <> port_name) and
          (port_name_last <> '0') and
          (port_name_last <> 0) and
          (not port_name_last is NULL))
            port_name := port_name_last;
      tt := sprintf ('[xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"] /definitions/binding[@type like ''%s'']/soap:binding/@transport', concat ('%', port_name));
      if (transport := FIND_WSDL (pt, tt) is NULL) goto new_loop;
      tt := sprintf ('/definitions/portType[@name like ''%s'']/operation', port_name);
      xp := xpath_eval (tt, pt[i1], 0);
      i := 0; l := length (xp);
      while (i < l)
	{
	  declare i_message, o_message, i_parm, o_parm any;
	  declare o_name, o_ns, soap_action, _ins, _out varchar;
	  declare colon, j, k integer;
	  declare ppars, res_pars varchar;
	  declare encoded any;

	  o_name := cast (xpath_eval ('@name', xp[i], 1) as varchar);

	  i_message := cast (xpath_eval ('input/@message', xp[i], 1) as varchar);
	  o_message := cast (xpath_eval ('output/@message', xp[i], 1) as varchar);

	  colon := strrchr (i_message, ':');
	  if (colon is not null)
	    i_message := substring (i_message, colon+2, length (i_message));
	  colon := strrchr (o_message, ':');
	  if (colon is not null)
	    o_message := substring (o_message, colon+2, length (o_message));

          tt := sprintf ('/definitions/message[@name like ''%s'']/part', concat ('%', i_message));
          i_parm := FIND_WSDL(pt ,tt);

          tt := sprintf ('/definitions/message[@name like ''%s'']/part', concat ('%', o_message));
          o_parm := FIND_WSDL(pt ,tt);

          ppars := ''; res_pars := vector ();
	  _ins := ''; _out := '';
--
--        INPUTS
--
          declare have_in_par integer;
          j := 0; k := length (i_parm); have_in_par := 0;
	  is_literal := 0;
	  while (j < k)
	    {
	      declare par, typ varchar;
	      par := cast (xpath_eval ('@name', i_parm[j]) as varchar);
	      typ := cast (xpath_eval ('@type', i_parm[j]) as varchar);
	      if (typ is NULL)
                {
                  typ := cast (xpath_eval ('@element', i_parm[j]) as varchar);
	  	  --colon := strchr (typ, ':');
	  	  --if (colon is not null) typ := substring (typ, colon+2, length (typ));
		  --tt := sprintf ('/definitions/types/schema/element[@name = ''%s'']/@type', typ);
                  --if (typ := FIND_WSDL(pt ,tt) is NULL)  goto new_loop;
	          --typ := cast (typ[0] as varchar);
		  is_literal := 1;
	 	}
	      if (j > 0)
		{
		  _ins := concat (_ins, ',');
		  ppars := concat (ppars, ',');
		}
	      _ins := concat (_ins, 'IN _', par, ' any __soap_type ''',typ ,'''');
	      ppars := concat (ppars, sprintf ('vector(''%s'', ''%s''), _', par, typ), par);
              res_pars := vector_concat (res_pars, vector (concat ('_', par), typ));
	      j := j + 1;
	    }
          have_in_par := j;
--
--        OUTPUTS
--
	  j := 0; k := length (o_parm);
	  while (j < k)
	    {
	      declare par, typ varchar;
	      par := cast (xpath_eval ('@name', o_parm[j]) as varchar);
	      typ := cast (xpath_eval ('@type', o_parm[j]) as varchar);
	      if (j > 0 or have_in_par > 0)
		{
		  _out := concat (_out, ',');
		}
	      _out := concat (_out, 'OUT _', par ,' any __soap_type ''',typ ,'''');

	      j := j + 1;
	    }

	  stmt := concat (stmt, '\r\n PROCEDURE ', o_name, ' (', _ins);

	  ret := vector_concat (ret, vector(o_name, res_pars));
	  o_ns := cast (xpath_eval (
		    sprintf ('/definitions/binding/operation[@name = ''%s'']/input/body/@namespace',
		      o_name), wsdl, 1) as varchar);
	  soap_action :=
		    cast (xpath_eval (
			  sprintf ('/definitions/binding/operation[@name = ''%s'']/operation/@soapAction',
			    o_name), wsdl, 1) as varchar);

          encoded := cast (xpath_eval (
                    sprintf ('[xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"] /definitions/binding/operation[@name = ''%s'']/input/soap:body/@use',
                    o_name), wsdl, 1) as varchar);

	  if (encoded is not null and encoded = 'literal')
	    {
	      encoded := 1;
              is_literal := 1;
	    }
	  else
	    encoded := 0;

          if (wire_dump)
            encoded := encoded + 2;

	  if (soap_action is null or soap_action = '')
	    {
	      soap_action := '""';
	    }
	  else
	    {
              soap_action := concat ('"',trim (soap_action, '" '),'"');
	    }

	  if (length (o_ns))
	    o_ns := sprintf ('''%s''', o_ns);
	  else
	    o_ns := 'NULL';

	  soap_action := sprintf ('''%s''', soap_action);

          if (not mode_wsdl)
            stmt := concat (stmt, _out);

	  if (is_literal)
	    stmt := concat (stmt, ') \n returns any __soap_doc ''__VOID__''\n');
	  else
	    stmt := concat (stmt, ') \n returns any __soap_type ''__VOID__''\n');

          if (mode_wsdl)
            {
	       stmt := concat (stmt, '{\n  declare res, ver any;\n  ver:=11;\n  ');
	       stmt := concat (stmt,
                   sprintf ('res := soap_call_new (''%s'',''%s'',\n    %s, ''%s'', vector (%s), ver, NULL, NULL, %s, %d);\n',
		   hinfo[1], hinfo[2], o_ns, o_name, ppars, soap_action, encoded));
	       stmt := concat (stmt, '  if (ver <> 11) signal (ver[1], ver[2]); \r\n return res; };  ');
	    }
	  else
	    {
              stmt := concat (stmt, '{ \n declare ret any; \n return ret; \n} ;\n');
	    }

	  i := i + 1;
	}
new_loop:
       i1 := i1 + 1;
    }
  stmt := concat (stmt, '  \r\n} \n');
--dbg_obj_print (stmt);
  if (length (stmt) > 7)
    {
      if (drop_module)
	{
	  declare st1, ms1 varchar;
          st1 := '00000';
	  exec (dmod, st1, ms1);
	}
      DB.DBA.EXEC_STMT (stmt, 0);
    }
  else
    ret := NULL;
  return ret;
}
;

create procedure FIND_WSDL (in _all any, in _what varchar)
{
  declare idx, len integer;
  declare ret any;

  len := length (_all);
  idx := 0;

  while (idx < len)
    {
       ret := xpath_eval (_what, _all[idx], 0);
       if (length (ret) > 0)
         return ret;
       idx := idx + 1;
    }

  return NULL;
}
;


create procedure WSDL_GET (in uri varchar, in _mode integer)
{
  declare _hdr, _ret any;

--  _ret := http_get (uri, _hdr);
  _ret := xml_uri_get (uri, '');
  _ret := xml_tree_doc (_ret);
  return _ret;
}
;

