--
--  $Id: twss.sql,v 1.8.10.1 2013/01/02 16:15:35 source Exp $
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
ECHO BOTH "STARTED: WS-Security tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

string_to_file ('wss.pfx', decode_base64(
'MIIIrAIBAzCCCGwGCSqGSIb3DQEHAaCCCF0EgghZMIIIVTCCAtYGCSqGSIb3DQEH
AaCCAscEggLDMIICvzCCArsGCyqGSIb3DQEMCgECoIIBjjCCAYowHAYKKoZIhvcN
AQwBAzAOBAiipXHZbBf09AICB9AEggFoEgUr3Y3JWxNujbY2iuUs7N+RHKc7eM/9
jDjRJtEupAaQyVu4/7hwKYwprgil38nhwHjl8uW0+xFWBBKtwroxhf1aL/4fVENF
iIeD+d07ZMhvJlE+0HCBdqVOhwPJmmWvOOWzzEn+EmJKlJWL6r8oWNDKJwLKM2+I
qVmfxbQNitZ1RCzd7z8+z0UlER5WKlEhRAoT7QgsTha7SDwpp11VOgJ25SzbZepD
h8pELSClVtjm1VW6ddfmWZQpveRSkJUgrBDOuu0WM8YXeWwq/pJuPXHZztdSovnR
2cTIAURaoxiYWkp/AuuV6IOQqiQkCF7N2vl62yZDcj0kRX5XYHBSIzHwQzfZodSa
kcXUx0/+Wew2/iSGQLmvn8BYWZZDq68u7UhrUSG8fSNn0YqeW6Z3MFHZgJCik04F
J4K9AmL/+8QLvf5QI0yV1s/YsbgwtLDUaLtRshnSw67ZN9MxarFwGI0aT8nXloDH
MYIBGDATBgkqhkiG9w0BCRUxBgQEAQAAADBjBgkrBgEEAYI3EQExVh5UAE0AaQBj
AHIAbwBzAG8AZgB0ACAAQgBhAHMAZQAgAEMAcgB5AHAAdABvAGcAcgBhAHAAaABp
AGMAIABQAHIAbwB2AGkAZABlAHIAIAB2ADEALgAwMIGbBgkqhkiG9w0BCRQxgY0e
gYoAOABhADQAOQBmADkANABhAGQAOABjADYAMAA1ADYAYgBiADMAOQA0ADUANgBl
ADQANwA1AGQANgA3ADAAYwAxAF8ANwA4AGEAYgBkADEAMAAyAC0AYQBhAGYANgAt
ADQAYwA5ADgALQA5AGYANQA3AC0ANABlAGIAYQA5ADYAYQBkAGYAYQAzADQwggV3
BgkqhkiG9w0BBwagggVoMIIFZAIBADCCBV0GCSqGSIb3DQEHATAcBgoqhkiG9w0B
DAEGMA4ECFfZHU6IghvJAgIH0ICCBTBNxpW6urY+tGh6A9TZMJ6+ZjswpNMS2gzt
zkxJ/j7w7YnFVNqF4RzgZYT7ZXSy22BqzulwhfTX883i6oljHOYmtMUJXp9QVqYh
rycGZUfmtM9ytl89Fg++edC2c74XRh6vbeQADzjLaYCMgyWxvDKTMRDpJB50/n/O
Wzzs5wS/Vwj4jXwN129p3sTGzN3LEails66BofGmwz1WvDr2JcvUdWGtgsJRN5+L
l/rvx2gB5UnU6XsgkBPw5q/V9eFrR5sRNAtxEYgaUi11wMjoSHP2CPHutnrc5h5r
PO2ojTvlJQl+Rw5MKvYemevRzj2r046wURsve4WBJ/QPK0yLbi+OX/VLkOvju4Vf
7p7T5lO1I1V6w1LyS96p2sNWU5URUmNZsDphNZfoWccZIABXmQ+MBboc7UtJa9r+
29trnNNiabvN+EyAnvz8PLRAwqAxI9c0HiuymPIsmOaQRokt0psOCzaXIntiQNQ0
EH1PEGt/EMNCB+iubJnVve5koB9zCSQYIOZEihXodMhCwX9HCx2NeTD1xTG9GKji
lnKAyr/KATcL1pk3dZMRGJHz8znrYrv4M58NBplj33Dt4p2wgsn7mHqa6U5OoHbV
d2st6fcJN4pjm/orwyfc3A+A8harUd7QJHeOJt4+Wnd7K62THCHcpj1fhpXsAIgZ
fO6cFZJeAuQtR8VGR9qckNIZ18TnADbXO3ADgZpFSowzTK5sjHqjNyCSmOTU6Fjm
MwMahqbsIdJf4C/6jauVjhH/YC+1nkPMsD+KqpkOR3IDRTDknJ1Ab8+oX/oAGI9P
tymEOM2U2mypwCqw6jARfD2LGBOhxwgMu1+y5oJkkBbLsVsODHxJgOAdyi0aGC9A
t4ygoRp8XWzDvtFoW2S9lnV05kP5TAJMYmubzggepb+wdBX1n0z8Wmqly4/tfDbG
C+1dPY3bd8X/6LsBgDPFAUHfcodNRNBLEDZzM/m1mtPb8U/xUUQtmukdUbT+LRNX
7JvPu249rAIdOaQ6qFLFo/rFtwQQPoWwrIzkAdK0CTnv8YENTVQIOUh761A9S5Fr
sTHHlBKJ6HPZWMaEEsvJtgd87+gh0KFcFfXrJYttYkGsA/hquQ13rWgOPgGuRedR
vPeTBDWc8I0/jafKuiosafE+zy4kkvVp1ntE8klOXymoudO8Hp9CWplJtqo0ziW/
EGbJynpEkd5pDHxsudJZM707bX9iME2qszxwUxqmyto/tUvJA2uaq0jh7JBN4Qro
xBa290//9RdJ6aGI0QU5xYQJm6/gYLwCW8XK/SrGQcMt5SvwlOFkqEvItcnjDBtA
3/HavV8gAIDPHieRCWfZDhuKHuANJU/C3WBF+4sqffgcCznFVimARcbMbUoLLP7X
pJmUhxwb/ZfIBbrhYjlMh40mfHs1jKVlJlMJKDRspC7bofKHpVB0LkCXhgck8TrC
sakSah5r5OFHDK4ypZY6SIj+1KnyZ6VGlfJLxGulilvD6t4r1rZgyx2fUDCAsqjF
CPInPijvfVtFOTrPl8y80GdITGKTR2hP6CY6IncQmN1KI3wUmKdZa4TkAKMsOVwG
zCil6P2p66xoI6bMlmqX5mM76XU/rvIWs2w7IQRptHqIdpUn8ol+GIdqhQ3VTkjR
9E5F8bDlcTIUv6d51YtV+ArNhofogalnhbY3ZcaN5n4Zy9C14f5iqH4sAx6Uz6D7
fpiplHmpDFy1jWj6gYa40CjT73s9v1XD+NSvGSJtxn6ppm4vk81Q3ie5wctdtzM8
Bz66OqBhvTA3MB8wBwYFKw4DAhoEFOJQoH4N1R/EY8T/wdS5qxPNMBHQBBT0Ff7W
I7Ay6Fs6/haU6B9n6j8xlw=='), -2);

string_to_file ('cli.pem',decode_base64(
'LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUUzakNDQkVlZ0F3SUJBZ0lL
QVQwVTJnQUFBQUFBQkRBTkJna3Foa2lHOXcwQkFRVUZBREJTTVFzd0NRWUQKVlFR
R0V3SlZVekVRTUE0R0ExVUVCeE1IVUd4dmRtUnBkakVMTUFrR0ExVUVDaE1DY0hZ
eEV6QVJCZ05WQkFzVApDbTl3Wlc1c2FXNXJjM2N4RHpBTkJnTlZCQU1UQm1sdGFY
UnJiekFlRncwd01qQTVNak14TWpRNU5EZGFGdzB3Ck16QTVNak14TWpVNU5EZGFN
Rkl4Q3pBSkJnTlZCQVlUQWxWVE1SQXdEZ1lEVlFRSEV3ZFFiRzkyWkdsMk1Rc3cK
Q1FZRFZRUUtFd0p3ZGpFVE1CRUdBMVVFQ3hNS2IzQmxibXhwYm10emR6RVBNQTBH
QTFVRUF4TUdZMnhwWlc1MApNRnd3RFFZSktvWklodmNOQVFFQkJRQURTd0F3U0FK
QkFQZUV3UEJhT05LL0JmQk1ubGI5dkNENmtsSmJVbmVtCkZ4L2lCM0ptZGV2Tllh
U2ErVGVib1Z3cEY2dlBaLzh5enU0ZGhkelJCQm1TMkFCbzUxem4yeDBDQXdFQUFh
T0MKQXYwd2dnTDVNQTRHQTFVZER3RUIvd1FFQXdJRThEQVRCZ05WSFNVRUREQUtC
Z2dyQmdFRkJRY0RBakFkQmdOVgpIUTRFRmdRVVhrc0ppVDdjRjNkVituTEhERDEx
M3ByMnA4d3dnWXNHQTFVZEl3U0JnekNCZ0lBVTZzNVRNSkQzCk1VaDNtYjhxd2hw
d0YxV0I3RE9oVnFSVU1GSXhDekFKQmdOVkJBWVRBbFZUTVJBd0RnWURWUVFIRXdk
UWJHOTIKWkdsMk1Rc3dDUVlEVlFRS0V3SndkakVUTUJFR0ExVUVDeE1LYjNCbGJt
eHBibXR6ZHpFUE1BMEdBMVVFQXhNRwphVzFwZEd0dmdoQVBncVN2ZWk3V2tFZmM5
d2N1b2htak1JSUJCUVlEVlIwZkJJSDlNSUg2TUlHOG9JRzVvSUcyCmhvR3piR1Jo
Y0Rvdkx5OURUajFwYldsMGEyOHNRMDQ5YldsMGEyOHNRMDQ5UTBSUUxFTk9QVkIx
WW14cFl5VXkKTUV0bGVTVXlNRk5sY25acFkyVnpMRU5PUFZObGNuWnBZMlZ6TEVO
T1BVTnZibVpwWjNWeVlYUnBiMjRzUkVNOQpjSFlzUkVNOWIzQmxibXhwYm10emR5
eEVRejFpWno5alpYSjBhV1pwWTJGMFpWSmxkbTlqWVhScGIyNU1hWE4wClAySmhj
MlUvYjJKcVpXTjBZMnhoYzNNOVkxSk1SR2x6ZEhKcFluVjBhVzl1VUc5cGJuUXdP
YUEzb0RXR00yaDAKZEhBNkx5OXRhWFJyYnk1d2RpNXZjR1Z1YkdsdWEzTjNMbUpu
TDBObGNuUkZibkp2Ykd3dmFXMXBkR3R2TG1OeQpiRENDQVJvR0NDc0dBUVVGQndF
QkJJSUJERENDQVFnd2dhMEdDQ3NHQVFVRkJ6QUNob0dnYkdSaGNEb3ZMeTlEClRq
MXBiV2wwYTI4c1EwNDlRVWxCTEVOT1BWQjFZbXhwWXlVeU1FdGxlU1V5TUZObGNu
WnBZMlZ6TEVOT1BWTmwKY25acFkyVnpMRU5PUFVOdmJtWnBaM1Z5WVhScGIyNHNS
RU05Y0hZc1JFTTliM0JsYm14cGJtdHpkeXhFUXoxaQpaejlqUVVObGNuUnBabWxq
WVhSbFAySmhjMlUvYjJKcVpXTjBZMnhoYzNNOVkyVnlkR2xtYVdOaGRHbHZia0Yx
CmRHaHZjbWwwZVRCV0JnZ3JCZ0VGQlFjd0FvWkthSFIwY0RvdkwyMXBkR3R2TG5C
MkxtOXdaVzVzYVc1cmMzY3UKWW1jdlEyVnlkRVZ1Y205c2JDOXRhWFJyYnk1d2Rp
NXZjR1Z1YkdsdWEzTjNMbUpuWDJsdGFYUnJieTVqY25RdwpEUVlKS29aSWh2Y05B
UUVGQlFBRGdZRUFvL2wrUWM3RXliRzlqdElRVlgzTWhJdWFYcDFCRXAzcDNzSVI4
bHFHCkpQRHZpODlTY3UxL1pNNDRRN2laNzJjQUViZXNpVmpyTXAxREpaWkQ0dnho
QlJDMzBwbnIwZ01KTmlqTFFodXQKSTY0S1NIU0xDVmZweDhQY0c2WXByaHFuNWVT
dnFPcmM5eEZPN0xidlBrblZ5UjFVWm5HcFR2WmlJVzhzWEE4ego5T1U9Ci0tLS0t
RU5EIENFUlRJRklDQVRFLS0tLS0K'
      ), -2);

string_to_file ('dsa.der',decode_base64(
'TUlINUFnRUFBa0VBcW12QkpRcUxJZmFYTW1iMTUvbzhyNEVENFpPZm9zWVpVRWxJ
SmdHdjV5Mzczdnh4SlZLa0FYdXlTR05xTzZyYm1kVDhOd1g0ZnpabEQ3ZnRwLzZn
NFFJVkFLMHFId0Z3bUpWRUlBWVo5ZTQ2V3dxWFNiaS9Ba0VBanVwdWg3bWpRbThU
dEF3a1R6YUZuZm10dzAzc21CSDZQUjMrcko5Yy9xeG9WZ295NERuSzlHVDV0V29O
ck1rVXJwbkZVV1cxTkh0L1plQlhQREhnR2dKQUh0MU80OEZVYjZjOFd4emdDTUcz
NzRsUnpMbVVVV1lJbVR1QnlIdHZJVTgwMXZTMzJyZkRiWEVoWWZlOU1PWmNPb2Qw
RHdMTG5aSTFLL2I2UlpqUWF3SVZBSVh4aHk1MmFTYlZ2QityN0hVeDlTVUtXYlVn'
      ), -2);


create user WSS;

create procedure ADDINT (in a int, in b int) returns int
{
  return (a + b);
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": creating ADDINT procedure STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure echoStr (in s nvarchar) returns nvarchar
{
  return s;
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": creating echoStr procedure STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


grant execute on ADDINT to WSS;
grant execute on echoStr to WSS;


VHOST_REMOVE (lpath=>'/wss');
VHOST_REMOVE (lpath=>'/virt-wss');

VHOST_DEFINE (lpath=>'/wss', ppath=>'/SOAP/', soap_user=>'WSS',
              soap_opts=>vector( 'Namespace','http://soapinterop.org/',
		                 'MethodInSoapAction','no',
				 'ServiceName', 'WSSecure',
				 'HeaderNS', 'http://soapinterop.org/echoheader/',
				 'CR-escape', 'no',
				 'WS-SEC','yes',
--				 'WSS-KEY','DB.DBA.WS_SOAP_GET_KEY',
				 'WSS-Template','wss_tmpl.xml',
				 'WSS-Validate-Signature', 2,
				 'WS-RP','no','wsrp-from','imitko@yahoo.com'));

ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": VHOST_DEFINE lpath=>/wss STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- .NET endpoint, no output encryption
VHOST_DEFINE (lpath=>'/virt-wss', ppath=>'/SOAP/', soap_user=>'WSS',
              soap_opts=>vector( 'Namespace','http://soapinterop.org/',
		                 'MethodInSoapAction','no',
				 'ServiceName', 'WSSecure',
				 'HeaderNS', 'http://soapinterop.org/echoheader/',
				 'CR-escape', 'no',
				 'WS-SEC','yes',
				 'WSS-KEY', 'DB.DBA.WSDK_GET_KEY',
				 'WSS-Template', NULL,
				 'WSS-Validate-Signature', 2,
				 'WS-RP','no','wsrp-from','imitko@yahoo.com'));

ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": VHOST_DEFINE lpath=>/virt-wss STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


string_to_file ('wss_tmpl.xml',
'<?xml version="1.0" encoding="UTF-8"?>
<Signature xmlns="http://www.w3.org/2000/09/xmldsig#" >
  <SignedInfo>
    <CanonicalizationMethod Algorithm="http://www.w3.org/TR/2001/REC-xml-c14n-20010315" />
    <SignatureMethod Algorithm="http://www.w3.org/2000/09/xmldsig#dsa-sha1" />
    <Reference URI="">
      <Transforms>
        <Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature" />
      </Transforms>
      <DigestMethod Algorithm="http://www.w3.org/2000/09/xmldsig#sha1" />
      <DigestValue></DigestValue>
    </Reference>
  </SignedInfo>
  <SignatureValue></SignatureValue>
  <KeyInfo>
    <KeyName>file:dsa.der</KeyName>
  </KeyInfo>
</Signature>' , -2);


string_to_file ('wss_tmpl_no.xml',
'<?xml version="1.0" encoding="UTF-8"?>
<Signature xmlns="http://www.w3.org/2000/09/xmldsig#" >
  <SignedInfo>
    <CanonicalizationMethod Algorithm="http://www.w3.org/TR/2001/REC-xml-c14n-20010315" />
    <SignatureMethod Algorithm="http://www.w3.org/2000/09/xmldsig#dsa-sha1" />
    <Reference URI="">
      <Transforms>
        <Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature" />
      </Transforms>
      <DigestMethod Algorithm="http://www.w3.org/2000/09/xmldsig#sha1" />
      <DigestValue></DigestValue>
    </Reference>
  </SignedInfo>
  <SignatureValue></SignatureValue>
  <KeyInfo>
    <KeyName>twss-no-key</KeyName>
  </KeyInfo>
</Signature>' , -2);

RECONNECT WSS;

USER_KEY_LOAD ('file:wss.pfx', NULL, 'X.509', 'PKCS12', 'virt');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Importing PKCS#12 server certificate   STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


USER_KEY_LOAD ('WSDK Sample Symmetric Key', 'EE/uaFF5N3ZNJWUTR8DYe+OEbwaKQnso', '3DES', 'DER', null);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Importing 3DES server key STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

USER_KEY_LOAD ('file:dsa.der', NULL, 'DSA', 'DER', null);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Importing Client's DSA key : xenc_key_DSA_read 'dsa-key' STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


RECONNECT dba;

USER_KEY_LOAD ('file:cli.pem', NULL, 'X.509', 'PEM', 'virt');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Importing PKCS#12 client certificate   STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


USER_KEY_LOAD ('WSDK Sample Symmetric Key', 'EE/uaFF5N3ZNJWUTR8DYe+OEbwaKQnso', '3DES', 'DER', null);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Importing WSDK Sample Symmetric Key  STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

USER_KEY_LOAD ('file:dsa.der', NULL, 'DSA', 'DER', null);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Importing Server's DSA key : xenc_key_DSA_read 'dsa-key' STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


xenc_key_3DES_rand_create ('wss-3des', '!sec!');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Generating Session Key xenc_key_3DES_rand_create wss-3des  STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create procedure
DB.DBA.WSDK_GET_KEY ()
{
  return xenc_key_inst_create ('WSDK Sample Symmetric Key');
}
;

create procedure
DB.DBA.WS_SOAP_GET_KEY ()
{
  declare superkey, keyinst any;
  superkey := xenc_key_inst_create ('file:dsa.der');
  keyinst := xenc_key_inst_create (xenc_key_3DES_rand_create (NULL, 'secret'), superkey);
  return keyinst;
}
;

grant execute on DB.DBA.WS_SOAP_GET_KEY to WSS
;

create procedure
DB.DBA.WS_SOAP_ACCOUNTING ()
{
--  dbg_obj_print ('key owner: ', connection_get ('wss-token-owner'));
--  dbg_obj_print (connection_get ('wss-token-issuer'));
--  dbg_obj_print (connection_get ('wss-token-serial'));
--  dbg_obj_print (connection_get ('wss-token-start'));
--  dbg_obj_print (connection_get ('wss-token-end'));
  return 1;
}
;

grant execute on DB.DBA.WS_SOAP_ACCOUNTING to public;

create procedure xres (in a any)
{
  result_names (a);
  result (a);
  return;
};



select (xpath_eval ('//ADDINTResponse/CallReturn/text()', xml_tree_doc (vector ( vector (UNAME' root'), SOAP_CLIENT (url=>'http://localhost:$U{HTTPPORT}/wss', operation=>'ADDINT', parameters=>vector ('a', 1, 'b', 2), auth_type=>'key', template=>file_to_string ('wss_tmpl.xml'), ticket=>xenc_key_inst_create (xenc_key_3DES_rand_create (NULL), xenc_key_inst_create ('file:dsa.der'))))), 1));
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DSA encryption ADDINT returned " $LAST[1]  "\n";

-- test without sec headers
SOAP_CLIENT (url=>'http://localhost:$U{HTTPPORT}/wss', operation=>'ADDINT', parameters=>vector ('a', 1, 'b', 2));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": No encryption STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

SOAP_CLIENT (url=>'http://localhost:$U{HTTPPORT}/wss', operation=>'ADDINT', parameters=>vector ('a', 1, 'b', 2), auth_type=>'key', template=>file_to_string ('wss_tmpl_no.xml'));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": No key STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


--SOAP_CLIENT (url=>'http://mitko/WSDKQuickStart/SymmetricEncryption/service/SymmetricEncryption.asmx', operation=>'ADDINT', parameters=>vector ('a', 1, 'b', 2), auth_type=>'key', ticket=>xenc_key_inst_create ('WSDK Sample Symmetric Key'), security_type=>'encr', target_namespace=>'http://microsoft.com/wsdk/samples/SumService', soap_action=>'"http://microsoft.com/wsdk/samples/SumService/ADDINT"')

--SOAP_CLIENT (url=>'http://localhost:$U{HTTPPORT}/wss', operation=>'ADDINT', parameters=>vector ('a', 1, 'b', 2), auth_type=>'key', ticket=>xenc_key_inst_create ('WSDK Sample Symmetric Key'), security_type=>'encr', soap_action=>'""' );

-- test with wrong signature

-- test with RSA
select (xpath_eval ('//ADDINTResponse/CallReturn/text()', xml_tree_doc (vector ( vector (UNAME' root'),
                     SOAP_CLIENT (
		       url=>'http://localhost:$U{HTTPPORT}/virt-wss',
		       operation=>'ADDINT',
		       parameters=>vector ('a', 1, 'b', 2),
		       auth_type=>'key',
		       ticket=>xenc_key_inst_create ('wss-3des', xenc_key_inst_create ('file:cli.pem')),
		       security_type=>'encr',
		       target_namespace=>'http://soapinterop.org/',
		       soap_action=>'"http://soapinterop.org/#ADDINT"',
		       style=>4))), 1)) ;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RSA encryption ADDINT returned " $LAST[1]  "\n";

select (xpath_eval ('//ADDINTResponse/CallReturn/text()', xml_tree_doc (vector ( vector (UNAME' root'),
    SOAP_CLIENT (
      url=>'http://localhost:$U{HTTPPORT}/virt-wss',
      operation=>'ADDINT',
      parameters=>vector ('a', 3, 'b', 4),
      auth_type=>'key',
      ticket=>xenc_key_inst_create ('WSDK Sample Symmetric Key'),
      security_type=>'encr',
      target_namespace=>'http://soapinterop.org/',
      soap_action=>'"http://soapinterop.org/#ADDINT"',
      style=>4))), 1)) ;
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 3des encryption ADDINT returned " $LAST[1]  "\n";


select (xpath_eval ('//ADDINTResponse/CallReturn/text()', xml_tree_doc (vector ( vector (UNAME' root'),
    SOAP_CLIENT (
      url=>'http://localhost:$U{HTTPPORT}/virt-wss',
      operation=>'ADDINT',
      parameters=>vector ('a', 3, 'b', 4),
      auth_type=>'key',
      ticket=>xenc_key_inst_create ('WSDK Sample Symmetric Key'),
      security_type=>'encr',
      target_namespace=>'http://soapinterop.org/',
      soap_action=>'"http://soapinterop.org/#ADDINT"',
      style=>4))), 1)) ;
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 3des encryption / content have NS ADDINT returned " $LAST[1]  "\n";

-- test with x509

-- test kerberos

-- test connection error
SOAP_CLIENT (url=>'http://nosuchhost.none/wss', operation=>'ADDINT', parameters=>vector ('a', 1, 'b', 2));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Connection error test STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: WS-Security tests\n";
