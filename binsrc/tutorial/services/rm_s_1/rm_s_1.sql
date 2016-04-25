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

-- Sender
vhost_remove (lpath=>'/replyto');

vhost_define (lpath=>'/replyto', ppath=>'/SOAP/', soap_user=>'WSRMS');

-- Reply
vhost_remove (lpath=>'/wsrm');

vhost_define (lpath=>'/wsrm', ppath=>'/SOAP/', soap_user=>'WSRMR', soap_opts=>vector ('WSRM-Callback', 'RM.RM.WSRMCBK'));

create user WSRMR;

create user WSRMS;

grant execute on WSRMSequence to WSRMR;

grant execute on WSRMSequenceTerminate to WSRMR;

grant execute on WSRMAckRequested to WSRMR;

grant execute on WSRMCreateSequence to WSRMR;

grant execute on WSRMTerminateSequence to WSRMR;

grant execute on TerminateSequence to WSRMR;

grant execute on WSRMSequenceAcknowledgement to WSRMS;


soap_dt_define ('', '<element  xmlns="http://www.w3.org/2001/XMLSchema" name="Ping" type="test:Ping_t" targetNamespace = "http://tempuri.org/" xmlns:test="http://tempuri.org/" />');

soap_dt_define ('', '<complexType xmlns="http://www.w3.org/2001/XMLSchema" name="Ping_t" targetNamespace = "http://tempuri.org/"><sequence><element minOccurs="1" maxOccurs="1" name="Text" type="string"/></sequence></complexType>');


create procedure WSRMTest_Ping (in _to varchar, in _from varchar, in ntimes int := 3, in reply_to varchar := null, in fault_to varchar := null)
  {
    declare addr wsa_cli;
    declare test wsrm_cli;
    declare req soap_client_req;
    declare finish any;
    declare ping soap_parameter;
    declare i int;
    ping := new soap_parameter (1);
    ping.set_xsd ('http://tempuri.org/:Ping');
    ping.s := vector ('Hello World');
    addr := new wsa_cli ();
    addr."to" := _to;
    addr."from" := _from;
    addr.reply_to := reply_to;
    addr.fault_to := fault_to;
    addr.action := 'urn:wsrm:Ping';
    req := new soap_client_req ();
    req.url := _to;
    req.operation := 'Ping';
    req.parameters := ping.get_call_param ('');
    test := new wsrm_cli (addr, _to);
    i := 0;
    while (i < (ntimes - 1))
      {
    	test.send_message (req);
    	i := i + 1;
      }
    test.finish (req);
    return test.seq;
  }
;


create procedure WSRMCheckState (in seq varchar, in _to varchar, in _from varchar)
  {
    declare test wsrm_cli;
    declare finish any;
    declare addr wsa_cli;
    addr := new wsa_cli ();
    addr."to" := _to;
    addr."from" := _from;
    test := new wsrm_cli (addr, _to, seq);
    finish := test.check_state ();
    return finish;
  }
;

create procedure WSRMTEST_ECHO_STRING_SES_DROP_TABLE ()
{
  declare state, message, meta, result any;
  exec ('drop table WSRMTEST_ECHO_STRING_SES', state, message, vector(), 0, meta, result);
}
;

WSRMTEST_ECHO_STRING_SES_DROP_TABLE ()
;

create table WSRMTEST_ECHO_STRING_SES (sid varchar, txt varchar, primary key (sid))
;

soap_dt_define ('', '<element  xmlns="http://www.w3.org/2001/XMLSchema" name="echoString" type="test:echoString_t" targetNamespace = "http://tempuri.org/" xmlns:test="http://tempuri.org/" />')
;

soap_dt_define ('', '<complexType xmlns="http://www.w3.org/2001/XMLSchema" name="echoString_t" targetNamespace = "http://tempuri.org/"><sequence><element minOccurs="1" maxOccurs="1" name="Text" type="string"/><element minOccurs="1" maxOccurs="1" name="Session" type="string"/></sequence></complexType>')
;


create procedure RM.RM.echoString (in "Text" varchar, in "Session" varchar)
__soap_options (__soap_doc := 'http://www.w3.org/2001/XMLSchema:string', PartName:='Text')
{
  declare txt, ses any;
  ses := "Session";
  txt := coalesce ((select txt from WSRMTEST_ECHO_STRING_SES where sid = ses), '');
  txt := txt || "Text";
  insert replacing WSRMTEST_ECHO_STRING_SES (sid, txt) values (ses, txt);
  return txt;
}
;


create procedure RM.RM.WSRMCBK (in req any, in seq_id any, in msg_id any)
{
  declare xe, res, ret, xp any;
  declare exit handler for sqlstate '*'
  {
    return null;
  };
  if (not xslt_is_sheet ('__rm_s_1_xsl'))
    {
      xslt_sheet ('__rm_s_1_xsl', xml_tree_doc (
	'<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
	   xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/">
	   <xsl:template match="SOAP:Header"/>
	   <xsl:template match="*">
             <xsl:copy>
		<xsl:copy-of select="@*"/>
		<xsl:apply-templates />
	     </xsl:copy>
           </xsl:template>
	 </xsl:stylesheet>')
	);
    }
  xe := xslt ('__rm_s_1_xsl', req);
  res := soap_server (xe, '', null, 11, null, vector ('Use', 'literal', 'elementFormDefault', 'qualified'));
  xe := xml_tree_doc (res);
  xp := xpath_eval ('/Envelope/Body/*', xe);
  if (xp is not null)
    ret := xml_cut (xp);
  else
    ret := null;
  return ret;
}
;

grant execute on RM.RM.WSRMCBK to WSRMR
;

grant execute on RM.RM.echoString to WSRMR
;

create procedure WSRMTest_echoString (in _to varchar, in _from varchar, in ntimes int := 3,
				      in reply_to varchar := null, in fault_to varchar := null)
  {
    declare addr wsa_cli;
    declare test wsrm_cli;
    declare req soap_client_req;
    declare finish, sid any;
    declare echostr soap_parameter;
    declare i int;
    declare rc any;
    addr := new wsa_cli ();
    addr."to" := _to;
    addr."from" := _from;
    addr.reply_to := reply_to;
    addr.fault_to := fault_to;
    addr.action := 'urn:wsrm:echoString';
    test := new wsrm_cli (addr, _to);
    req := new soap_client_req ();
    req.url := _to;
    req.operation := 'echoString';
    sid := uuid ();
    i := 0;
    while (i < (ntimes - 1))
      {
         echostr := new soap_parameter ();
	 echostr.set_xsd ('http://tempuri.org/:echoString');
	 echostr.add_member ('Text', sprintf ('STR-%d', i+1));
	 echostr.add_member ('Session', sid);
	 req.parameters := echostr.get_call_param ('');
    	 rc := test.send_message (req);
    	 i := i + 1;
      }
    echostr := new soap_parameter ();
    echostr.set_xsd ('http://tempuri.org/:echoString');
    echostr.add_member ('Text', sprintf ('STR-%d', i+1));
    echostr.add_member ('Session', sid);
    req.parameters := echostr.get_call_param ('');
    rc := test.finish (req);
    return test.seq;
  }
;

vhost_remove (lpath=>'/wsrmsec')
;

vhost_define (lpath=>'/wsrmsec',
		ppath=>'/SOAP/',
		soap_user=>'WSRMR',
		soap_opts=>vector ('WSRM-Callback', 'RM.RM.WSRMCBK',
		'WS-SEC','yes',
		'WSS-KEY', 'DB.DBA.WSRM_GET_KEY',
		'WSS-Template', '[func:DB.DBA.WSRM_INTEROP_TMPL_SRV]',
		'WSS-Validate-Signature', 1,
		'wsse', wsse_oasis_uri (),
		'wsu', wssu_oasis_uri ()
		 ))
;


create procedure WSRMTest_PingSec (in _to varchar, in _from varchar, in ntimes int, in reply_to varchar := null, in fault_to varchar := null)
  {
    declare addr wsa_cli;
    declare test wsrm_cli;
    declare req soap_client_req;
    declare finish any;
    declare ping soap_parameter;
    declare i int;
    ping := new soap_parameter (1);
    ping.set_xsd ('http://tempuri.org/:Ping');
    ping.s := vector ('Hello World');
    addr := new wsa_cli ();
    addr."to" := _to;
    addr."from" := _from;
    addr.reply_to := reply_to;
    addr.fault_to := fault_to;
    addr.action := 'urn:wsrm:Ping';
    req := new soap_client_req ();
    req.url := _to;
    req.operation := 'Ping';
    req.parameters := ping.get_call_param ('');
    req.security_schema := vector ('wsse', WSSE_OASIS_URI (),'wsu', WSSU_OASIS_URI());
    req.security_type := 'encrypt';
    req.template := '[func:DB.DBA.WSRM_INTEROP_TMPL]';
    req.auth_type := 'key';
    if (not xenc_key_exists ('wss-3des'))
      xenc_key_3DES_rand_create ('wss-3des', '!sec!');
    req.ticket := xenc_key_inst_create ('wss-3des', xenc_key_inst_create ('WSSTest2'));
    test := new wsrm_cli (addr, _to);
    i := 0;
    while (i < (ntimes - 1))
      {
    	test.send_message (req);
    	i := i + 1;
      }
    test.finish (req);
    return test.seq;
  }
;

create procedure WSE.WSRMR.Ping
(
  inout  Sequence any __soap_header 'http://schemas.xmlsoap.org/ws/2005/02/rm:Sequence',
  in  MessageID any := null __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:MessageID',
  inout "To" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:To',
  inout  Action any := null __soap_header 'http://schemas.xmlsoap.org/ws/2004/08/addressing:Action'
)
  __soap_options (__soap_doc := '__VOID__', DefaultOperation := 1)
{
  declare identifier any;

  declare ping soap_parameter;
  declare i int;
  ping := new soap_parameter (1);
  ping.set_xsd ('http://tempuri.org/:Ping');
  ping.s := vector (composite (), 'Text', 'Hello World');

  return vector (ping.s);
}
;

grant execute on WSE.WSRMR.Ping to WSRMR
;

create procedure DB.DBA.WSRM_INTEROP_TMPL (in body any)
{
  return WSRM_XENC_TEMPLATE (body, 'WSSTest1');
}
;

create procedure DB.DBA.WSRM_INTEROP_TMPL_SRV (in body any)
{
  return WSRM_XENC_TEMPLATE (body, 'WSSTest2');
}
;

create procedure DB.DBA.WSRM_GET_KEY ()
{
  if (not xenc_key_exists ('wss-3des'))
    xenc_key_3DES_rand_create ('wss-3des', '!sec!');
  return xenc_key_inst_create ('wss-3des', xenc_key_inst_create ('WSSTest1'));
}
;

grant execute on DB.DBA.WSRM_GET_KEY to WSRMR
;

grant execute on DB.DBA.WSRM_INTEROP_TMPL_SRV to  WSRMR
;


create procedure
WSRM_XENC_TEMPLATE (in body varchar, in key_name varchar, in ns any := null)
{
  declare tmpl, algo varchar;
  algo := xenc_get_key_algo (key_name);
  if (algo is null)
    return NULL;
  if (ns is null)
    ns := vector ('wsse', WSSE_OASIS_URI (),'wsu', WSSU_OASIS_URI ());
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
	'http://schemas.xmlsoap.org/ws/2004/03/rm', 'Sequence',
	'http://schemas.xmlsoap.org/ws/2004/03/rm', 'SequenceAcknowledgment',
	'http://schemas.xmlsoap.org/ws/2004/03/rm', 'CreateSequence',
	'http://schemas.xmlsoap.org/ws/2004/03/rm', 'CreateSequenceResponse',
	'http://schemas.xmlsoap.org/ws/2004/03/rm', 'TerminateSequence',
	'http://schemas.xmlsoap.org/soap/envelope/', 'Body',
	'http://schemas.xmlsoap.org/ws/2004/03/addressing', 'MessageID',
	'http://schemas.xmlsoap.org/ws/2004/03/addressing', 'To',
	'http://schemas.xmlsoap.org/ws/2004/03/addressing', 'Action',
	'http://schemas.xmlsoap.org/ws/2004/03/addressing', 'From',
	'http://schemas.xmlsoap.org/ws/2004/03/addressing', 'FaultTo',
	'http://schemas.xmlsoap.org/ws/2004/03/addressing', 'RelatesTo',
	wsse_oasis_uri (), 'Created',
	wssu_oasis_uri (), 'Expires'
      );
}
;

create procedure cert ()
{
    return uudecode (
   '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', 2);
}
;

grant execute on cert to public
;

commit work
;

create procedure RM_S_1_LOAD_KEYS ()
{
  if (not xenc_key_exists ('WSSTest1'))
    USER_KEY_LOAD ('WSSTest1', cert(), 'X.509', 'PKCS12', 'ws_s_5', null, 1);
  if (not xenc_key_exists ('WSSTest2'))
    USER_KEY_LOAD ('WSSTest2', cert(), 'X.509', 'PKCS12', 'ws_s_5', null, 1);
  set_user_id ('WSRMR', 0);
  if (not xenc_key_exists ('WSSTest1'))
    USER_KEY_LOAD ('WSSTest1', cert(), 'X.509', 'PKCS12', 'ws_s_5', null, 1);
  set_user_id ('WSRMS', 0, 'WSRMS');
  if (not xenc_key_exists ('WSSTest2'))
    USER_KEY_LOAD ('WSSTest2', cert(), 'X.509', 'PKCS12', 'ws_s_5', null, 1);
}
;

RM_S_1_LOAD_KEYS ()
;

