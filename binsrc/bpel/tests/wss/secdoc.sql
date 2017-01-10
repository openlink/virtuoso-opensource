--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2017 OpenLink Software
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
use DB;
vhost_remove (lpath=>'/SecSvc');

select U_NAME from SYS_USERS where U_NAME = 'SSEC';
$IF $EQU $ROWCNT 1 "" "create user SSEC";

vhost_define (lpath=>'/SecSvc', ppath=>'/SOAP/', soap_user=>'SSEC',
    soap_opts=>vector ('Use', 'literal'
      ,'WS-SEC','yes',
      'WSS-KEY', 'DB.DBA.GET_SEC_KEY',
      'WSS-Template', '[ServerPrivate.pfx]',
      'WSS-Validate-Signature', 1,
      'WSS-SecurityCheck', 'DB.DBA.CHECK_ENC'
      ));

create procedure DB.DBA.GET_SEC_KEY ()
{
  declare tk any;
  tk := xenc_key_3DES_rand_create (NULL, 'secret');
  return xenc_key_inst_create (tk, xenc_key_inst_create ('ClientPublic.cer'));
}
;

create procedure DB.DBA.CHECK_ENC (inout x any)
{
  declare sec any;
  sec := connection_get ('wss-keys');
  dbg_obj_print ('sec check:', sec);
  if (not length (sec[0]))
    signal ('22023', 'message is not encrypted');
  return;
}
;


create procedure SSEC..echoSync (in var varchar) returns varchar
{
  dbg_obj_print ('var=',var);
  return 'var='||var;
}
;

grant execute on SSEC..echoSync to SSEC;

create procedure BPEL..load_keys (in u any, in pk any, in pub any, in pass any)
{
  set_user_id (u);
  if (not xenc_key_exists (pk))
    {
      db..user_key_load (pk, file_to_string (http_root () || '/wss/'||pk),
	'X.509', 'PKCS12', pass, null, 1);
    }
  if (not xenc_key_exists (pub))
    {
      db..user_key_load (pub, file_to_string (http_root () || '/wss/'||pub),
	'X.509', 'DER', pass, null, 1);
    }
}
;

BPEL..load_keys ('SSEC', 'ServerPrivate.pfx', 'ClientPublic.cer', 'wse2qs');
BPEL..load_keys ('BPEL', 'ClientPrivate.pfx', 'ServerPublic.cer', 'wse2qs');
BPEL..load_keys ('BPEL', 'dsa.pfx', 'ServerPublic.cer', '1234');
BPEL..load_keys ('DBA', 'ServerPrivate.pfx', 'ClientPublic.cer', 'wse2qs');


use bpel;

create procedure doc_upl ()
{
  declare id int;
  delete from BPEL..script where bs_name = 'WSSecho';
  id := script_upload ('', 'file:/wss/doc.bpel');
  wsdl_upload (id, 'file:/wss/doc.wsdl');
  wsdl_upload (id, 'file:/wss/secsvc.wsdl', null, 'service');
  compile_script (id, '/SecEcho');
  update BPEL..partner_link_init set bpl_opts =
'<wsOptions>
    <addressing version="http://schemas.xmlsoap.org/ws/2003/03/addressing"/>
    <security>
      <key name="ClientPrivate.pfx" />
      <pubkey name="ServerPublic.cer" />
      <in>
        <encrypt type="Optional" />
        <signature type="Optional" />
	<keys/>
      </in>
      <out>
        <encrypt type="AES192" />
        <signature type="Default" />
      </out>
    </security>
    <delivery>
      <in type="NONE" />
      <out type="NONE" />
    </delivery>
   </wsOptions>' where bpl_script = id  and bpl_name in ('service','caller');

};

doc_upl();

create procedure inv_nosec ()
{

  return db..soap_client (
	url=>'http://localhost:'||server_http_port ()||'/SecEcho',
	operation=>'echo',
	parameters=>vector (vector ('varString','string'), 'one'),
	style=>5
	);

}
;

create procedure invsec_sig (in pk any, in pub any)
{

  return db..soap_client (
	url=>'http://localhost:'||server_http_port ()||'/SecEcho',
	operation=>'echo',
	parameters=>vector (vector ('varString','string'), 'one'),
	style=>5,
	auth_type=>'key',
	security_type=>'encrypt',
	template=>sprintf ('[%s]',pk)
	);

}
;

create procedure invsec_enc (in pk any, in pub any)
{

  if (not xenc_key_exists ('key-3des'))
    xenc_key_3DES_rand_create ('key-3des', '1234567890');

  return db..soap_client (
	url=>'http://localhost:'||server_http_port ()||'/SecEcho',
	operation=>'echo',
	parameters=>vector (vector ('varString','string'), 'one'),
	style=>5,
	auth_type=>'key',
	ticket=>xenc_key_inst_create ('key-3des', xenc_key_inst_create (pub)),
	security_type=>'encrypt'
	);

}
;



create procedure invsec (in pk any, in pub any)
{

  if (not xenc_key_exists ('key-3des'))
    xenc_key_3DES_rand_create ('key-3des', '1234567890');

  return db..soap_client (
	url=>'http://localhost:'||server_http_port ()||'/SecEcho',
	operation=>'echo',
	parameters=>vector (vector ('varString','string'), 'one'),
	style=>5,
	auth_type=>'key',
	ticket=>xenc_key_inst_create ('key-3des', xenc_key_inst_create (pub)),
	security_type=>'encrypt',
	template=>sprintf ('[%s]',pk)
	);

}
;

BPEL.BPEL.plink_set_option ('WSSecho', 'caller', 'wss-out-encrypt-key', 'NONE');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Setting caller PLink to do not ask for encryption key \n";

select xpath_eval ('//varString/text()', xml_tree_doc (inv_nosec()));
ECHO BOTH $IF $EQU $LAST[1] "var=one" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Secure script called w/o security returns : " $LAST[1] "\n";

BPEL.BPEL.plink_set_option ('WSSecho', 'caller', 'wss-out-encrypt-key', 'AES192');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Setting caller PLink to ask for encryption key \n";

select xpath_eval ('//varString/text()', xml_tree_doc (invsec_sig('ServerPrivate.pfx', 'ClientPublic.cer')));
ECHO BOTH $IF $EQU $LAST[1] "var=one" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Secure script called with signature returns : " $LAST[1] "\n";

select xpath_eval ('//varString/text()', xml_tree_doc (invsec_enc('ServerPrivate.pfx', 'ClientPublic.cer')));
ECHO BOTH $IF $EQU $LAST[1] "var=one" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Secure script called with encryption returns : " $LAST[1] "\n";

select xpath_eval ('//varString/text()', xml_tree_doc (invsec('ServerPrivate.pfx', 'ClientPublic.cer')));
ECHO BOTH $IF $EQU $LAST[1] "var=one" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Secure script returns : " $LAST[1] "\n";

BPEL.BPEL.plink_set_option ('WSSecho', 'caller', 'wss-in-encrypt', 'Mandatory');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Setting caller PLink to ask for encryption \n";

select xpath_eval ('//varString/text()', xml_tree_doc (inv_nosec()));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Secure script called w/o security STATE:  " $STATE " message: " $MESSAGE "\n";

select xpath_eval ('//varString/text()', xml_tree_doc (invsec_enc('ServerPrivate.pfx', 'ClientPublic.cer')));
ECHO BOTH $IF $EQU $LAST[1] "var=one" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Secure script called with encryption returns : " $LAST[1] "\n";

BPEL.BPEL.plink_set_option ('WSSecho', 'caller', 'wss-in-signature', 'Mandatory');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Setting caller PLink to ask for signature \n";

select xpath_eval ('//varString/text()', xml_tree_doc (invsec_enc('ServerPrivate.pfx', 'ClientPublic.cer')));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Secure script called with encryption only STATE:  " $STATE " message: " $MESSAGE "\n";

select xpath_eval ('//varString/text()', xml_tree_doc (invsec('ServerPrivate.pfx', 'ClientPublic.cer')));
ECHO BOTH $IF $EQU $LAST[1] "var=one" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Secure script (siganture and encryption) returns : " $LAST[1] "\n";


BPEL.BPEL.plink_set_option ('WSSecho', 'service', 'wss-out-signature-type', 'NONE');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Setting service PLink to make only encryption \n";

select xpath_eval ('//varString/text()', xml_tree_doc (invsec('ServerPrivate.pfx', 'ClientPublic.cer')));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Service called with encryption only STATE:  " $STATE " message: " $MESSAGE "\n";

BPEL.BPEL.plink_set_option ('WSSecho', 'service', 'wss-out-signature-type', 'Default');
BPEL.BPEL.plink_set_option ('WSSecho', 'service', 'wss-out-encrypt-key', 'NONE');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Setting PLink to make only signature \n";

select xpath_eval ('//varString/text()', xml_tree_doc (invsec('ServerPrivate.pfx', 'ClientPublic.cer')));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Service called with signature only STATE:  " $STATE " message: " $MESSAGE "\n";

BPEL.BPEL.plink_set_option ('WSSecho', 'service', 'wss-out-encrypt-key', 'AES192');
BPEL.BPEL.plink_set_option ('WSSecho', 'service', 'wss-in-signers', vector ('dsa.pfx'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Setting service PLink to be valid if dsa key is used\n";

select xpath_eval ('//varString/text()', xml_tree_doc (invsec('ServerPrivate.pfx', 'ClientPublic.cer')));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Service do not return required signature STATE:  " $STATE " message: " $MESSAGE "\n";

BPEL.BPEL.plink_set_option ('WSSecho', 'service', 'wss-in-signers', vector ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Setting service PLink to be valid for any key used for signing\n";

select xpath_eval ('//varString/text()', xml_tree_doc (invsec('ServerPrivate.pfx', 'ClientPublic.cer')));
ECHO BOTH $IF $EQU $LAST[1] "var=one" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Calling again with siganture and encryption returns : " $LAST[1] "\n";

select xpath_eval ('//varString/text()', xml_tree_doc (invsec('ServerPrivate.pfx', 'ServerPrivate.pfx')));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": wrong key state: " $STATE "\n";
