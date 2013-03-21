--  
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2013 OpenLink Software
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

create procedure WS.SOAP.RequestSecurityToken
(
in  "RequestSecurityToken" any := null __soap_type 'http://schemas.xmlsoap.org/ws/2002/12/secext:RequestSecurityToken',
out RequestSecurityTokenResponse any __soap_type 'http://schemas.xmlsoap.org/ws/2002/12/secext:RequestSecurityTokenResponse',
inout "From" any __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:From',
inout "MessageID" any __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:MessageID',
  out "RelatesTo" any __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:RelatesTo',
  out "Timestamp" any __soap_header 'http://schemas.xmlsoap.org/ws/2002/07/utility:Timestamp',
inout "To" any __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:To'
) __soap_doc '__VOID__'

{
   declare ret any;
   declare in_m_id any;
   declare param any;
   declare mid, bsc_any any;
   declare wsa_from, wsu_time, par, created, expr, m_id, a_to, releates_to, bsc, resp, headers soap_parameter;

   bsc_any := ws_trust_token_gen ("From", "MessageID", "RequestSecurityToken", "Timestamp", "To");
   in_m_id := cast ("MessageID"[1][1] as varchar);

   wsa_from := new soap_parameter ();
   wsa_from.set_xsd ('http://schemas.xmlsoap.org/ws/2003/03/addressing:From');
   wsa_from.add_member ('Address', 'http://' || sys_connected_server_address () || http_map_get ('domain'));
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

   a_to := new soap_parameter ('http://schemas.xmlsoap.org/ws/2003/03/addressing/role/anonymous');
   a_to.set_xsd ('http://schemas.xmlsoap.org/ws/2003/03/addressing:To');
   a_to.set_attribute ('Id', 'Id-' || uuid());

   releates_to := new soap_parameter (in_m_id);
   releates_to.set_xsd ('http://schemas.xmlsoap.org/ws/2003/03/addressing:RelatesTo');
   releates_to.set_attribute ('RelationshipType', 'wsa:Response' || uuid());
   releates_to.set_attribute ('Id', 'Id-' || uuid());

   bsc := new soap_parameter (bsc_any);
   bsc.set_xsd ('http://schemas.xmlsoap.org/ws/2002/12/secext:BinarySecurityTokenType');
   bsc.set_attribute ('ValueType', 'wsse:X509v3');
   bsc.set_attribute ('EncodingType', 'wsse:Base64Binary');
   bsc.set_attribute ('Id', 'Id-' || uuid());

   resp := new soap_parameter ();
   resp.set_xsd ('http://schemas.xmlsoap.org/ws/2002/12/secext:RequestSecurityTokenResponse');
   resp.add_member ('TokenType', 'wsse:X509v3');
   resp.add_member ('RequestedSecurityToken', vector (bsc.s));

  RequestSecurityTokenResponse := resp.s;
  "From" := wsa_from.s;
  "MessageID" := m_id.s;
  "Timestamp" := wsu_time.s;
  "RelatesTo" := releates_to.s;
  "To" := a_to.s;
}
;

SOAP_LOAD_SCH (WSRM_WSS0212_XSD (), null, 0, 0)
;

create procedure  DB.DBA.WS_TRUST_TOKEN_GEN (in "From" any, in "MessageID" any, in "RequestSecurityToken" any,
					     in "Timestamp" any, in "To" any)
{
   declare ret any;
   declare t_type, r_type, l_from varchar;

   if (__proc_exists ('DB.DBA.WST_GET_SECURITY_TOKEN'))
     {
       ret := call ('DB.DBA.WST_GET_SECURITY_TOKEN') ("From", "MessageID", "RequestSecurityToken", "Timestamp", "To");
       return ret;
     }

   t_type := cast ("RequestSecurityToken"[3] as varchar);
   r_type := cast ("RequestSecurityToken"[5] as varchar);
   l_from := cast ("From"[3] as varchar);

   select WSK_TOKEN into ret from WST_SERVER_ISSUER_TOKENS
		where WSK_TOKEN_TYPE = t_type and WSK_REQUEST_TYPE = r_type and WSK_FROM = l_from;

   return ret;
}
;

