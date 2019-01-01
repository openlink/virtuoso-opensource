--  
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2019 OpenLink Software
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
create procedure WST_CLI (in req SOAP_CLIENT_REQ, in policy POLICY_STRUCT)
{
   declare ret any;

   ret := WST_GETRST (req, policy);

   if (policy.debug = 1)
     return ret;

   policy.token := ret;

   ret := WS_TRUST_REQ (req, policy);

   return ret;
}
;

create procedure WST_GETRST (in req SOAP_CLIENT_REQ, in policy POLICY_STRUCT)
{
   declare ret any;
   declare headers, param any;
   declare wsa_from, wsu_time, par, created, expr, m_id, a_to, act soap_parameter;
   declare rst SOAP_CLIENT_REQ;
   declare style integer;

   rst := new SOAP_CLIENT_REQ ();

   rst.url := policy.token_issuer;
   rst.operation := 'RequestSecurityToken';

   wsa_from := new soap_parameter ();
   wsa_from.set_xsd ('http://schemas.xmlsoap.org/ws/2003/03/addressing:From');
   wsa_from.add_member ('Address', 'http://schemas.xmlsoap.org/ws/2003/03/addressing/role/anonymous');
   wsa_from.set_attribute ('Id', 'Id-' || uuid());

   created := new soap_parameter (dt_set_tz (now (), 0));
   created.set_xsd ('http://schemas.xmlsoap.org/ws/2002/07/utility:Created');
   created.set_attribute ('Id', 'Id-' || uuid());

   expr := new soap_parameter (dt_set_tz (dateadd ('minute', 5, now ()), 0));
   expr.set_xsd ('http://schemas.xmlsoap.org/ws/2002/07/utility:Expires');
   expr.set_attribute ('Id', 'Id-' || uuid());

   wsu_time := new soap_parameter ();
   wsu_time.set_xsd ('http://schemas.xmlsoap.org/ws/2002/07/utility:Timestamp');
   wsu_time.add_member ('Created', created);
   wsu_time.add_member ('Expires', expr);

   m_id := new soap_parameter (lower ('UUID:'||uuid ()));
   m_id.set_xsd ('http://schemas.xmlsoap.org/ws/2003/03/addressing:MessageID');
   m_id.set_attribute ('Id', 'Id-' || uuid());

   a_to := new soap_parameter (rst.url);
   a_to.set_xsd ('http://schemas.xmlsoap.org/ws/2003/03/addressing:To');
   a_to.set_attribute ('Id', 'Id-' || uuid());

   act := new soap_parameter ('http://schemas.xmlsoap.org/security/RequestSecurityToken');
   act.set_xsd ('http://schemas.xmlsoap.org/ws/2003/03/addressing:Action');
   act.set_attribute ('Id', 'Id-' || uuid());

   headers := vector_concat (act.get_call_param (''), wsa_from.get_call_param (''), m_id.get_call_param (''),
			     a_to.get_call_param (''), wsu_time.get_call_param (''));

   connection_set ('__soap_ws_trust_user', policy.user_name);
   connection_set ('__soap_ws_trust_pass', policy.user_pass);

   if (policy.debug = 1)
      style := 1 + 2 + 16;
   else
      style := 1 + 16;

   param := vector (vector (
	'RequestSecurityToken', 'http://schemas.xmlsoap.org/ws/2002/12/secext:RequestSecurityToken'),
		soap_box_structure ('TokenType', 'wsse:' || policy.token_type,
				    'RequestType', 'wsse:' || policy.usage));

   ret := SOAP_CLIENT (url=>rst.url, operation=>rst.operation, headers=>headers,
   style=>style,
   parameters=>param,
   auth_type=>'key',
   soap_action=>'http://schemas.xmlsoap.org/security/RequestSecurityToken',
   template=>'[func:DB.DBA.SOAP_WS_TRUST_XENC_TEMPLATE]',
   --http_header=>'Expect: 100-continue\r\n',
   security_type=>'sign');

   if (policy.debug = 1)
     return ret;
   --dbg_obj_print (ret);
   return cast(xpath_eval ('/RequestSecurityTokenResponse/RequestedSecurityToken/BinarySecurityToken/text()'
   , xml_tree_doc (ret)) as varchar);
}
;


create procedure WS_TRUST_REQ (in rst SOAP_CLIENT_REQ, in policy POLICY_STRUCT)
{
   declare headers, ret, cli_cert_name any;
   declare wsa_from, wsu_time, par, created, expr, m_id, a_to, act soap_parameter;
   declare style integer;

   wsa_from := new soap_parameter ();
   wsa_from.set_xsd ('http://schemas.xmlsoap.org/ws/2003/03/addressing:From');
   wsa_from.add_member ('Address', 'http://schemas.xmlsoap.org/ws/2003/03/addressing/role/anonymous');
   wsa_from.set_attribute ('Id', 'Id-' || uuid());

   created := new soap_parameter (dt_set_tz (now (), 0));
   created.set_xsd ('http://schemas.xmlsoap.org/ws/2002/07/utility:Created');
   created.set_attribute ('Id', 'Id-' || uuid());

   expr := new soap_parameter (dt_set_tz (dateadd ('minute', 500, now ()), 0));
   expr.set_xsd ('http://schemas.xmlsoap.org/ws/2002/07/utility:Expires');
   expr.set_attribute ('Id', 'Id-' || uuid());

   wsu_time := new soap_parameter ();
   wsu_time.set_xsd ('http://schemas.xmlsoap.org/ws/2002/07/utility:Timestamp');
   wsu_time.add_member ('Created', created);
   wsu_time.add_member ('Expires', expr);

   m_id := new soap_parameter (lower ('UUID:'||uuid ()));
   m_id.set_xsd ('http://schemas.xmlsoap.org/ws/2003/03/addressing:MessageID');
   m_id.set_attribute ('Id', 'Id-' || uuid());

   a_to := new soap_parameter (rst.url);
   a_to.set_xsd ('http://schemas.xmlsoap.org/ws/2003/03/addressing:To');
   a_to.set_attribute ('Id', 'Id-' || uuid());

   act := new soap_parameter ('http://weblogs.contoso.com/wse/samples/2003/07/AddEntry');
   act.set_xsd ('http://schemas.xmlsoap.org/ws/2003/03/addressing:Action');
   act.set_attribute ('Id', 'Id-' || uuid());

   if (policy.debug = 2)
      style := 1 + 2 + 16;
   else
      style := 1 + 16;

   cli_cert_name := get_certificate_info (8, decode_base64 (policy.token), 1);

   if (cli_cert_name is null)
     signal ('42000', 'Cannot resolve issued security token.');

   headers := vector_concat (act.get_call_param (''), wsa_from.get_call_param (''), m_id.get_call_param (''),
			     a_to.get_call_param (''), wsu_time.get_call_param (''));

   return SOAP_CLIENT (url=>rst.url, operation=>rst.operation, headers=>headers, style=>style, security_type=>'sign',
		       parameters=>rst.parameters, auth_type=>'key', template=>'[' || cli_cert_name || ']');
}
;
