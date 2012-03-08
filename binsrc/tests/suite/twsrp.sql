--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2012 OpenLink Software
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
ECHO BOTH "STARTED: WS-routing tests\n";

--set echo on;

SET ARGV[0] 0;
SET ARGV[1] 0;

create user WSRP;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The wsrp user created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

VHOST_REMOVE (lpath=>'/router');
VHOST_REMOVE (lpath=>'/router1');
VHOST_REMOVE (lpath=>'/router2');

VHOST_DEFINE (lpath=>'/router', ppath=>'/SOAP/', soap_user=>'WSRP', soap_opts=>vector('Namespace','http://soapinterop.org/','MethodInSoapAction','no', 'ServiceName', 'WS-Router', 'CR-escape', 'yes', 'WS-RP', 'yes'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The routing point 1 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

VHOST_DEFINE (lpath=>'/router1', ppath=>'/SOAP/', soap_user=>'WSRP', soap_opts=>vector('Namespace','http://soapinterop.org/','MethodInSoapAction','no', 'ServiceName', 'WS-Router', 'CR-escape', 'yes', 'WS-RP', 'yes'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The routing point 2 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

VHOST_DEFINE (lpath=>'/router2', ppath=>'/SOAP/', soap_user=>'WSRP', soap_opts=>vector('Namespace','http://soapinterop.org/','MethodInSoapAction','no', 'ServiceName', 'WS-Router', 'CR-escape', 'yes', 'WS-RP', 'yes'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The routing point 3 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure
WSRP.WSRP."echoString" (in inputString nvarchar)
returns nvarchar
{
  return inputString;
};

grant execute on WSRP.WSRP."echoString" to WSRP;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The wsrp.wsrp.echoString is exposed as SOAP operation STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create procedure
wsrptest (in r any)
{
  declare hdr any;
  declare stat varchar;
  declare res varchar;
  res :=  http_get ('http://localhost:$U{HTTPPORT}/router', hdr, 'POST', 'Content-Type: text/xml\r\nSOAPAction: "http://soapinterop.org/"', r);
--  dbg_obj_print (res);
  result_names (stat, stat, stat, stat, stat);
  {
    declare xe, xt, r, rto any;
    xe := xml_tree_doc (res);
    xt := xpath_eval ('/Envelope/Body/Fault', xe, 1);
    if (xt is not null)
      {
	declare fc , fr varchar;
        fc := xpath_eval ('string(/Envelope/Header/path/fault/code)', xe, 1);
        fr := xpath_eval ('string(/Envelope/Header/path/fault/reason)', xe, 1);
        signal (cast(fc as varchar), cast (fr as varchar));
      }
    xt := xpath_eval ('string(/Envelope/Body/echoStringResponse/CallReturn)', xe, 1);
    r := cast (xt as varchar);
    rto := xpath_eval ('string(/Envelope/Header/path/relatesTo)', xe, 1);
    xt := xpath_eval ('/Envelope/Header/path/rev/via', xe, 0);
    declare r1, r2, r3 varchar;
    r1 := replace (xpath_eval ('string()',xt[0],1), N'$U{HTTPPORT}', N'');
    r2 := replace (xpath_eval ('string()',xt[1],1), N'$U{HTTPPORT}', N'');
    r3 := replace (xpath_eval ('string()',xt[2],1), N'$U{HTTPPORT}', N'');
    result (r, r1, r2, r3, rto);
  }
  return res;
}

wsrptest(
'<S:Envelope
    xmlns:S="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:cli="http://soapinterop.org/"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <S:Header>
    <m:path xmlns:m="http://schemas.xmlsoap.org/rp" S:actor="http://schemas.xmlsoap.org/soap/actor/next" S:mustUnderstand="1">
    <m:action>http://soapinterop.org/</m:action>
    <m:to>http://localhost:$U{HTTPPORT}/router2</m:to>
    <m:id>uuid:09233523-345b-4351-b623-5dsf35sgs5d6</m:id>
    <m:fwd>
      <m:via>http://localhost:$U{HTTPPORT}/router</m:via>
      <m:via>http://localhost:$U{HTTPPORT}/router1</m:via>
    </m:fwd>
    <m:rev>
    </m:rev>
   </m:path>
 </S:Header>
<S:Body>
  <cli:echoString  S:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" ><inputString  xsi:type="xsd:string">This is a test</inputString></cli:echoString>
</S:Body>
</S:Envelope>');
ECHO BOTH $IF $EQU $LAST[1] 'This is a test' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The echoString result : " $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 'http://localhost:/router' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The echoString called via intermidiary A : " $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 'http://localhost:/router1' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The echoString called via intermidiary B : " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 'http://localhost:/router2' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The echoString called from ultimate C : " $LAST[4] "\n";

ECHO BOTH $IF $EQU $LAST[5] 'uuid:09233523-345b-4351-b623-5dsf35sgs5d6' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The echoString have relatesTo : " $LAST[5] "\n";

wsrptest(
'<S:Envelope
    xmlns:S="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:cli="http://soapinterop.org/"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <S:Header>
    <m:path xmlns:m="http://schemas.xmlsoap.org/rp" S:actor="http://schemas.xmlsoap.org/soap/actor/next" S:mustUnderstand="1">
    <m:action>http://soapinterop.org/</m:action>
    <m:id>uuid:09233523-345b-4351-b623-5dsf35sgs5d6</m:id>
    <m:fwd>
      <m:via>http://localhost:$U{HTTPPORT}/router</m:via>
      <m:via>http://localhost:$U{HTTPPORT}/router1</m:via>
      <m:via>http://localhost:$U{HTTPPORT}/router2</m:via>
    </m:fwd>
    <m:rev>
    </m:rev>
   </m:path>
 </S:Header>
<S:Body>
  <cli:echoString  S:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" ><inputString  xsi:type="xsd:string">This is a test</inputString></cli:echoString>
</S:Body>
</S:Envelope>');

ECHO BOTH $IF $EQU $LAST[1] 'This is a test' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The echoString result (the ultimate is in fwd/via) : " $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 'http://localhost:/router' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The echoString called via intermidiary A : " $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 'http://localhost:/router1' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The echoString called via intermidiary B : " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 'http://localhost:/router2' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The echoString called from ultimate C : " $LAST[4] "\n";

ECHO BOTH $IF $EQU $LAST[5] 'uuid:09233523-345b-4351-b623-5dsf35sgs5d6' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The echoString have relatesTo : " $LAST[5] "\n";


wsrptest(
'<S:Envelope
    xmlns:S="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:cli="http://soapinterop.org/"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <S:Header>
    <m:path xmlns:m="http://schemas.xmlsoap.org/rp" S:actor="http://schemas.xmlsoap.org/soap/actor/next" S:mustUnderstand="1">
    <m:action>http://soapinterop.org/</m:action>
    <m:to>http://localhost:$U{HTTPPORT}/router2</m:to>
    <m:id>uuid:09233523-345b-4351-b623-5dsf35sgs5d6</m:id>
    <m:fwd>
      <m:via>http://localhost:$U{HTTPPORT}/router1</m:via>
      <m:via>http://localhost:$U{HTTPPORT}/router1</m:via>
    </m:fwd>
    <m:rev>
    </m:rev>
   </m:path>
 </S:Header>
<S:Body>
  <cli:echoString  S:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" ><inputString  xsi:type="xsd:string">This is a test</inputString></cli:echoString>
</S:Body>
</S:Envelope>');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The intermidiary A fails as it's not a target STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

wsrptest(
'<S:Envelope
    xmlns:S="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:cli="http://soapinterop.org/"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <S:Header>
    <m:path xmlns:m="http://schemas.xmlsoap.org/rp" S:actor="http://schemas.xmlsoap.org/soap/actor/next" S:mustUnderstand="1">
    <m:action>http://soapinterop.org/</m:action>
    <m:to>http://localhost:$U{HTTPPORT}/router2</m:to>
    <m:id>uuid:09233523-345b-4351-b623-5dsf35sgs5d6</m:id>
    <m:fwd>
      <m:via>http://localhost:$U{HTTPPORT}/router</m:via>
      <m:via>http://localhost:$U{HTTPPORT}/router3</m:via>
      <m:via>http://localhost:$U{HTTPPORT}/router1</m:via>
    </m:fwd>
    <m:rev>
    </m:rev>
   </m:path>
 </S:Header>
<S:Body>
  <cli:echoString  S:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" ><inputString  xsi:type="xsd:string">This is a test</inputString></cli:echoString>
</S:Body>
</S:Envelope>');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The intermidiary A to unresolvable fails STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

wsrptest(
'<S:Envelope
    xmlns:S="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:cli="http://soapinterop.org/"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <S:Header>
    <m:path xmlns:m="http://schemas.xmlsoap.org/rp-fake/" S:actor="http://schemas.xmlsoap.org/soap/actor/next" S:mustUnderstand="1">
    <m:action>http://soapinterop.org/</m:action>
    <m:to>http://localhost:$U{HTTPPORT}/router2</m:to>
    <m:id>uuid:09233523-345b-4351-b623-5dsf35sgs5d6</m:id>
    <m:fwd>
      <m:via>http://localhost:$U{HTTPPORT}/router</m:via>
      <m:via>http://localhost:$U{HTTPPORT}/router1</m:via>
    </m:fwd>
    <m:rev>
    </m:rev>
   </m:path>
 </S:Header>
<S:Body>
  <cli:echoString  S:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" ><inputString  xsi:type="xsd:string">This is a test</inputString></cli:echoString>
</S:Body>
</S:Envelope>');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The intermidiary A fails due to wrong NS of path STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

wsrptest(
'<S:Envelope
    xmlns:S="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:cli="http://soapinterop.org/"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <S:Header>
    <m:path xmlns:m="http://schemas.xmlsoap.org/rp" S:actor="http://schemas.xmlsoap.org/soap/actor/next" S:mustUnderstand="0">
    <m:action>http://soapinterop.org/</m:action>
    <m:to>http://localhost:$U{HTTPPORT}/router2</m:to>
    <m:id>uuid:09233523-345b-4351-b623-5dsf35sgs5d6</m:id>
    <m:fwd>
      <m:via>http://localhost:$U{HTTPPORT}/router</m:via>
      <m:via>http://localhost:$U{HTTPPORT}/router1</m:via>
    </m:fwd>
    <m:rev>
    </m:rev>
   </m:path>
 </S:Header>
<S:Body>
  <cli:echoString  S:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" ><inputString  xsi:type="xsd:string">This is a test</inputString></cli:echoString>
</S:Body>
</S:Envelope>');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The intermidiary A fails due to wrong mustUnderstand STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

wsrptest(
'<S:Envelope
    xmlns:S="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:cli="http://soapinterop.org/"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <S:Header>
    <m:path xmlns:m="http://schemas.xmlsoap.org/rp" S:actor="http://someactor/next" S:mustUnderstand="1">
    <m:action>http://soapinterop.org/</m:action>
    <m:to>http://localhost:$U{HTTPPORT}/router2</m:to>
    <m:id>uuid:09233523-345b-4351-b623-5dsf35sgs5d6</m:id>
    <m:fwd>
      <m:via>http://localhost:$U{HTTPPORT}/router</m:via>
      <m:via>http://localhost:$U{HTTPPORT}/router1</m:via>
    </m:fwd>
    <m:rev>
    </m:rev>
   </m:path>
 </S:Header>
<S:Body>
  <cli:echoString  S:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" ><inputString  xsi:type="xsd:string">This is a test</inputString></cli:echoString>
</S:Body>
</S:Envelope>');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The intermidiary A fails due to wrong actor attribute STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

wsrptest(
'<S:Envelope
    xmlns:S="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:cli="http://soapinterop.org/"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <S:Header>
    <m:path xmlns:m="http://schemas.xmlsoap.org/rp" S:actor="http://schemas.xmlsoap.org/soap/actor/next" S:mustUnderstand="1">
    <m:action>http://soapinterop.org/</m:action>
    <m:to>http://localhost:$U{HTTPPORT}/router2</m:to>
    <m:id>uuid:09233523-345b-4351-b623-5dsf35sgs5d6</m:id>
    <m:fwd>
      <m:via>http://localhost:$U{HTTPPORT}/router</m:via>
    </m:fwd>
    <m:rev>
    </m:rev>
   </m:path>
   <r:referrals xmlns:r="http://schemas.xmlsoap.org/ws/2001/10/referral">
      <r:ref>
        <r:for>
           <r:exact>http://localhost:$U{HTTPPORT}/router</r:exact>
        </r:for>
      <r:if>
        <r:ttl>36000000</r:ttl>
      </r:if>
      <r:go>
        <r:via>http://localhost:$U{HTTPPORT}/router1</r:via>
      </r:go>
      <r:refId>mid:12345@localhost</r:refId>
      </r:ref>
   </r:referrals>
 </S:Header>
<S:Body>
  <cli:echoString  S:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" ><inputString  xsi:type="xsd:string">This is a test</inputString></cli:echoString>
</S:Body>
</S:Envelope>');
ECHO BOTH $IF $EQU $LAST[1] 'This is a test' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The echoString result : " $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 'http://localhost:/router' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The echoString called via intermidiary A : " $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 'http://localhost:/router1' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The echoString called via intermidiary B (inserted dinamically) : " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 'http://localhost:/router2' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The echoString called from ultimate C : " $LAST[4] "\n";

ECHO BOTH $IF $EQU $LAST[5] 'uuid:09233523-345b-4351-b623-5dsf35sgs5d6' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The echoString have relatesTo : " $LAST[5] "\n";


create procedure
wsreftest (in f varchar, in i integer := 0)
{
  declare hdr any;
  declare res varchar;
  res :=  http_get ('http://localhost:$U{HTTPPORT}/router', hdr, 'POST', 'Content-Type: text/xml\r\nSOAPAction: ""', f);
  if (i)
    {
      declare xe any;
      declare prefix, via, refid varchar;
      result_names (prefix, via, refid);
      xe := xml_tree_doc (res);
      prefix := xpath_eval ('/Envelope/Body/queryResponse/ref/for/prefix/text()' , xe, 1);
      via := xpath_eval ('/Envelope/Body/queryResponse/ref/go/via[1]/text()' , xe, 1);
      refid := xpath_eval ('/Envelope/Body/queryResponse/ref/refId/text()' , xe, 1);
      prefix := replace	 (cast(prefix as varchar), '$U{HTTPPORT}', '');
      via := replace	 (cast(via as varchar), '$U{HTTPPORT}', '');
      result (prefix, via, refid);
    }
};


wsreftest (
'<S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/">
<S:Header>
<m:path xmlns:m="http://schemas.xmlsoap.org/rp">
<m:action>http://schemas.xmlsoap.org/ws/2001/10/referral#register</m:action>
<m:to>http://localhost:$U{HTTPPORT}/router</m:to>
<m:rev>
<m:via/>
</m:rev>
<m:id>mid:3000@c.org</m:id>
</m:path>
</S:Header>
<S:Body>
<r:register xmlns:r="http://schemas.xmlsoap.org/ws/2001/10/referral">
<r:ref>
<r:for>
<r:prefix>http://localhost:$U{HTTPPORT}/router2/</r:prefix>
</r:for>
<r:if>
 <r:ttl>36000000</r:ttl>
</r:if>
<r:go>
<r:via>http://localhost:$U{HTTPPORT}/router1/</r:via>
</r:go>
<r:refId>mid:2345@some.host.org</r:refId>
</r:ref>
</r:register>
</S:Body>
</S:Envelope>'
);

wsreftest (
'<S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/">
<S:Header>
<m:path xmlns:m="http://schemas.xmlsoap.org/rp">
<m:action>http://schemas.xmlsoap.org/ws/2001/10/referral#register</m:action>
<m:to>http://localhost:$U{HTTPPORT}/router</m:to>
<m:rev>
<m:via/>
</m:rev>
<m:id>mid:3001@c.org</m:id>
</m:path>
</S:Header>
<S:Body>
<r:register xmlns:r="http://schemas.xmlsoap.org/ws/2001/10/referral">
<r:ref>
<r:for>
<r:prefix>http://localhost:$U{HTTPPORT}/router2/</r:prefix>
</r:for>
<r:if>
 <r:ttl>36000000</r:ttl>
</r:if>
<r:go>
<r:via>http://localhost:$U{HTTPPORT}/router1/</r:via>
</r:go>
<r:refId>mid:3456@some.host.org</r:refId>
</r:ref>
</r:register>
</S:Body>
</S:Envelope>'
);

select count(*) from WS_REFERRALS;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WS-Referral enries : " $LAST[1] "\n";

wsreftest (
'<S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/">
<S:Header>
<m:path xmlns:m="http://schemas.xmlsoap.org/rp">
<m:action>http://schemas.xmlsoap.org/ws/2001/10/referral#register</m:action>
<m:to>http://localhost:$U{HTTPPORT}/router</m:to>
<m:rev>
<m:via/>
</m:rev>
<m:id>mid:3002@c.org</m:id>
</m:path>
</S:Header>
<S:Body>
<r:register xmlns:r="http://schemas.xmlsoap.org/ws/2001/10/referral">
<r:ref>
<r:for>
  <r:prefix>http://localhost:$U{HTTPPORT}/router2/</r:prefix>
</r:for>
<r:if>
 <r:invalidates>
   <r:rid>mid:2345@some.host.org</r:rid>
 </r:invalidates>
</r:if>
<r:go>
</r:go>
<r:refId>mid:3456@some.host.org</r:refId>
</r:ref>
</r:register>
</S:Body>
</S:Envelope>');

select R_ID from WS_REFERRALS;
ECHO BOTH $IF $EQU $LAST[1] 'mid:3456@some.host.org' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WS-Referral remaining entry  : " $LAST[1] "\n";


wsreftest (
'<S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/">
<S:Header>
<m:path xmlns:m="http://schemas.xmlsoap.org/rp">
<m:action>http://schemas.xmlsoap.org/ws/2001/10/referral#query</m:action>
<m:to>http://localhost:$U{HTTPPORT}/router</m:to>
<m:rev>
<m:via/>
</m:rev>
<m:id>mid:1000@a.org</m:id>
</m:path>
</S:Header>
<S:Body>
  <r:query xmlns:r="http://schemas.xmlsoap.org/ws/2001/10/referral">
    <r:for>
      <r:prefix>http://localhost:$U{HTTPPORT}/router2/</r:prefix>
    </r:for>
  </r:query>
</S:Body>
</S:Envelope>', 1);
ECHO BOTH $IF $EQU $LAST[1] 'http://localhost:/router2/' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": queryResponse / prefix : " $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 'http://localhost:/router1/' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": queryResponse / via : " $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 'mid:3456@some.host.org' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": queryResponse / refId : " $LAST[3] "\n";

wsrptest(
'<S:Envelope
    xmlns:S="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:cli="http://soapinterop.org/"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <S:Header>
    <m:path xmlns:m="http://schemas.xmlsoap.org/rp" S:actor="http://schemas.xmlsoap.org/soap/actor/next" S:mustUnderstand="1">
    <m:action>http://soapinterop.org/</m:action>
    <m:to>http://localhost:$U{HTTPPORT}/router2/</m:to>
    <m:id>uuid:09233523-345b-4351-b623-5dsf35sgs5d6</m:id>
    <m:fwd>
      <m:via>http://localhost:$U{HTTPPORT}/router</m:via>
    </m:fwd>
    <m:rev>
    </m:rev>
   </m:path>
 </S:Header>
<S:Body>
  <cli:echoString  S:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" ><inputString  xsi:type="xsd:string">This is a test</inputString></cli:echoString>
</S:Body>
</S:Envelope>');
ECHO BOTH $IF $EQU $LAST[1] 'This is a test' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The echoString result : " $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 'http://localhost:/router' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The echoString called via intermidiary A : " $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 'http://localhost:/router1/' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The echoString called via intermidiary B (inserted w/ WS-referral statement) : " $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 'http://localhost:/router2/' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The echoString called from ultimate C : " $LAST[4] "\n";

ECHO BOTH $IF $EQU $LAST[5] 'uuid:09233523-345b-4351-b623-5dsf35sgs5d6' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The echoString have relatesTo : " $LAST[5] "\n";



ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: WS-routing tests\n";
