--
--  $Id: thttp.sql,v 1.24.6.1.4.1 2013/01/02 16:15:10 source Exp $
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2014 OpenLink Software
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
echo BOTH "STARTED: HTTP server tests\n";
CONNECT;

--set echo on;

SET ARGV[0] 0;
SET ARGV[1] 0;

drop table allow;
drop table deny;

create user "demo";

create table allow (id varchar);
insert into allow values ('10');
insert into allow values ('12');
insert into allow values ('11');
grant select on allow to "demo";
create table deny (id varchar);
insert into deny values ('20');
insert into deny values ('30');
insert into deny values ('40');

create procedure c_resp (in hdr any)
{
  declare line, code varchar;
  if (hdr is null or __tag (hdr) <> 193)
    return (502);
  if (length (hdr) < 1)
    return (502);
  line := aref (hdr, 0);
  if (length (line) < 12)
    return (502);
  code := substring (line, strstr (line, 'HTTP/1.') + 9, length (line));
  while ((length (code) > 0) and (aref (code, 0) < ascii ('0') or aref (code, 0) > ascii ('9')))
    code := substring (code, 2, length (code) - 1);
  if (length (code) < 3)
    return (502);
  code := substring (code, 1, 3);
  code := atoi (code);
  return code;
}
;

create procedure rc (in code integer)
{
  if (code < 200 or code > 399)
    signal (sprintf ('HT%d', code), sprintf ('Failed with code (%d)', code));
}

create procedure
get (in uri varchar, in up varchar)
{
  declare rc any;
  declare res varchar;
  if (up is not null)
    res := http_get (uri, rc, 'GET', concat ('Authorization: Basic ', encode_base64 (up)));
  else
    res := http_get (uri, rc, 'GET');
--  dbg_obj_print ('>>>> RESPONSE : \n', rc, '>>>>>>>>>>>>>\n');
  rc := c_resp (rc);
  rc (rc);
  return res;
}


create procedure
meth (in uri varchar, in meth varchar, in up varchar, in body varchar)
{
  declare rc any;
  declare res varchar;
  if (up is not null)
    {
      if (body is null)
        res := http_get (uri, rc, meth, concat ('Authorization: Basic ', encode_base64 (up)));
      else
        res := http_get (uri, rc, meth, concat ('Authorization: Basic ', encode_base64 (up)), body);
    }
  else
    {
      if (body is null)
        res := http_get (uri, rc, meth, null);
      else
        res := http_get (uri, rc, meth, null, body);
    }
  rc := c_resp (rc);
  rc (rc);
}


create procedure
make_http ()
{
  declare _all, temp any;
  declare idx integer;

  idx := 0;
  _all := '<html>\r\n<head>\r\n<title>Test gzip encoding</title>\r\n</head>\r\n<BODY>';

  while (idx < 1200)
    {
       temp := (sprintf ('%i - %s<BR>\r\n', idx, MD5 (cast (idx as varchar))));
       _all := concat (_all, temp);
       idx := idx + 1;
    }

  _all := concat (_all, '</BODY>\r\n</HTML>\r\n');

  return (_all);
}
;

create procedure
make_big_vsp ()
{
  string_to_file ('big.vsp', '<?vsp declare len, idx, size integer; declare line varchar; line := repeat (''abc'', 1000) || ''\r\n''; len := 2500; idx := 0; size := 0; while (idx < len) { http (line); size := size + length (line) + 2; idx := idx + 1; } ?>', 0);
}
;

create procedure
vxml_test ()
{
  declare vxml, vxsl varchar;
  declare doc varchar;
  vxml := '<?xml version="1.0"?>
	    <portfolio xmlns:dt="urn:schemas-microsoft-com:datatypes" xml:space="preserve">
	    <stock exchange="nyse">
	    <name>zacx corp</name>
	    <symbol>ZCXM</symbol>
	    <price dt:dt="number">28.875</price>
	    </stock>
	    <stock exchange="nasdaq">
	    <name>zaffymat inc</name>
	    <symbol>ZFFX</symbol>
	    <price dt:dt="number">92.250</price>
	    </stock>
	    <stock exchange="nasdaq">
	    <name>zysmergy inc</name>
	    <symbol>ZYSZ</symbol>
	    <price dt:dt="number">20.313</price>
	    </stock>
	    </portfolio>
	    ';
  vxsl := '<?xml version=''1.0''?>
	    <xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl">
	    <xsl:template match="/">
	    <HTML>
	    <BODY>
	    <TABLE BORDER="2">
	    <TR>
	    <TD>Symbol</TD>
	    <TD>Name</TD>
	    <TD>Price</TD>
	    </TR>
	    <xsl:for-each select="portfolio/stock">
	    <TR>
	    <TD><xsl:value-of select="symbol"/></TD>
	    <TD><xsl:value-of select="name"/></TD>
	    <TD><xsl:value-of select="price"/></TD>
	    </TR>
	    </xsl:for-each>
	    </TABLE>
	    </BODY>
	    </HTML>
	    </xsl:template>
	    </xsl:stylesheet>
	    ';
  string_to_file ('portfolio.vxml', vxml, 0);
  string_to_file ('portfolio.vxsl', vxsl, 0);
  doc := http_get ('http://localhost:$U{HTTPPORT}/portfolio.vxml');
  if (doc = '<HTML><BODY><TABLE BORDER="2"><TR><TD>Symbol</TD><TD>Name</TD><TD>Price</TD></TR><TR><TD>ZCXM</TD><TD>zacx corp</TD><TD>28.875</TD></TR><TR><TD>ZFFX</TD><TD>zaffymat inc</TD><TD>92.250</TD></TR><TR><TD>ZYSZ</TD><TD>zysmergy inc</TD><TD>20.313</TD></TR></TABLE></BODY></HTML>')
    return;
  signal ('VXML1', 'The VXML execution failed.');
}

vxml_test();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": VXML/VXSL transformation : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure
test_gz (in _port varchar)
{
  declare test, test2 any;
  declare idx integer;
  declare port varchar;
  declare _res any;

  port := cast ((_port + 17) as varchar);

  string_to_file ('test_gz.vsp', '<?vsp http(make_http ()); \?>\r\n', 0);

  http_enable_gz (1);

  VHOST_DEFINE (concat ('localhost:', port), concat (':', port), '/', '/', 0, 0, NULL,  NULL, NULL, NULL, 'dba', NULL, NULL, 0);

  test := http_get (concat ('http://localhost:', port, '/test_gz.vsp'), _res, 'GET', 'Accept-Encoding: gzip');

  test := cast (test as varchar);

  test2 := string_output_string (gzip_uncompress (file_to_string ('etalon_ouput_gz')));

  http_enable_gz (0);

  if (length (test) <> length (test2))
    return 0;

  if (md5(test) = md5 (test2))
    return 1;

  return 0;
}
;


sys_mkdir (concat (http_root (), '/vdir'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": directory  ./vdir created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

sys_mkdir (concat (http_root (), '/vdir1'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": directory ./vdir1 created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

VHOST_DEFINE ('localhost:$U{HTTPPORT1}','localhost:$U{HTTPPORT1}', '/', '/vdir/', 0, 1, 'def.html', 'DB.DBA.HP_AUTH_SQL_USER', 'vdir realm', 'DB.DBA.HP_SES_VARS_STORE', 'demo', 'demo', 'Basic', 1) ;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": new listen host defined on : " $U{HTTPPORT1} " : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

VHOST_DEFINE ('localhost:$U{HTTPPORT2}','localhost:$U{HTTPPORT2}', '/', '/vdir1/', 0, 0, 'def.html', 'DB.DBA.HP_AUTH_SQL_USER', 'vdir 1 realm', 'DB.DBA.HP_SES_VARS_STORE', 'demo', 'demo', 'Digest', 1) ;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": new listen host defined on : " $U{HTTPPORT2} " : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

VHOST_DEFINE ('localhost:$U{HTTPPORT1}','localhost:$U{HTTPPORT1}', '/DAV', '/DAV/', 1, 1, 'def.html', 'DB.DBA.HP_AUTH_DAV_PROTOCOL', 'dav realm', 'DB.DBA.HP_SES_VARS_STORE', 'dba', 'dba', 'Basic', 1) ;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WebDAV domain added to the " $U{HTTPPORT1} " listen host : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select http_listen_host ('localhost:$U{HTTPPORT1}',2);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Listening host on : " $U{HTTPPORT1} " tested\n";

select http_listen_host ('localhost:$U{HTTPPORT2}',2);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Listening host on : " $U{HTTPPORT2} " tested\n";

get ('http://localhost:$U{HTTPPORT1}/', 'dba:dba');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select soap_call_new ('localhost:$U{HTTPPORT1}', '/url-maina', 'uri-maina', 'method-maina', null, 11);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 5418: soap call to non-existant page : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

string_to_file (concat (http_root (), '/vdir/def.html'), '<p>Default page</p>', 0);
string_to_file (concat (http_root (), '/vdir/allow.vsp'), '<?vsp for select id from db.dba.allow do { http (id); http (''<br>''); };  ?>', 0);
string_to_file (concat (http_root (), '/vdir/deny.vsp'), '<?vsp for select id from db.dba.deny do { http (id); };  ?>', 0);

delete from ADMIN_SESSION;
insert into ADMIN_SESSION (ASES_ID) values ('f4d96e82c2788d41ff8518b7c02456b3');
string_to_file (concat (http_root (), '/vdir/ses.vsp'), '<?vsp  declare sesvar any; sesvar := connection_get (\'sesvar\'); if (sesvar is null) connection_set (\'sesvar\' , \'abracadabra\'); else { http (sesvar); connection_set (\'sesvar\' , \'ator\');} ?>', 0);

get ('http://localhost:$U{HTTPPORT1}/', 'dba:dba');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": default page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select get ('http://localhost:$U{HTTPPORT1}/ses.vsp?sid=f4d96e82c2788d41ff8518b7c02456b3', 'dba:dba');
ECHO BOTH $IF $EQU $LAST[1] '' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": session variable stored : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select get ('http://localhost:$U{HTTPPORT1}/ses.vsp?sid=f4d96e82c2788d41ff8518b7c02456b3', 'dba:dba');
ECHO BOTH $IF $EQU $LAST[1] 'abracadabra' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": session variable retrieved : " $LAST[1] "\n";

select get ('http://localhost:$U{HTTPPORT1}/ses.vsp?sid=f4d96e82c2788d41ff8518b7c02456b3', 'dba:dba');
ECHO BOTH $IF $EQU $LAST[1] 'ator' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": session variable retrieved : " $LAST[1] "\n";

get ('http://localhost:$U{HTTPPORT1}/allow.vsp', 'dba:dba');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": granted table select allowed in VSP : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT1}/deny.vsp', 'dba:dba');
ECHO BOTH $IF $EQU $STATE 'HT500' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": not granted table denied in VSP : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT2}/', 'dba:dba');
ECHO BOTH $IF $EQU $STATE 'HT401' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": trying to retrieve digest only allowed domain with basic authentication : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT2}/', 'dba:error');
ECHO BOTH $IF $EQU $STATE 'HT401' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": trying to retrieve digest only allowed domain with wrong password : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT1}/DAV/', 'dav:dav');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DAV browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT1}/DAV/', 'dav:error');
ECHO BOTH $IF $EQU $STATE 'HT401' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DAV browse page not retrieved (wrong password) : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


VHOST_REMOVE ('localhost:$U{HTTPPORT1}','localhost:$U{HTTPPORT1}', '/', 1);
VHOST_REMOVE ('localhost:$U{HTTPPORT1}','localhost:$U{HTTPPORT1}', '/DAV', 1);
VHOST_REMOVE ('localhost:$U{HTTPPORT2}','localhost:$U{HTTPPORT2}', '/', 1);

--- XXX: this is timing ????
delay (2);

select http_listen_host ('localhost:$U{HTTPPORT1}',2);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Listening host on : " $U{HTTPPORT1} " stopped & tested\n";

select http_listen_host ('localhost:$U{HTTPPORT2}',2);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Listening host on : " $U{HTTPPORT2} " stopped & tested\n";



get ('http://localhost:$U{HTTPPORT1}/', 'dba:dba');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": trying to retrieve pages after definition removal : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


get ('http://localhost:$U{HTTPPORT2}/', 'dba:dba');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": trying to retrieve pages after definition removal : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

VHOST_DEFINE ('localhost:$U{HTTPPORT1}','localhost:$U{HTTPPORT1}', '/', '/DAV/', 1, 1, 'index.html', 'DB.DBA.HP_AUTH_DAV_PROTOCOL', 'DAV', null, 'dba', null, 'Basic', 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WebDAV domain and " $U{HTTPPORT1} " listen host added again : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select http_listen_host ('localhost:$U{HTTPPORT1}',2);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Listening host on : " $U{HTTPPORT1} " started & tested\n";

select DAV_RES_UPLOAD ('/DAV/iri.vsp', '<?vsp http (id_to_iri (iri_to_id (\'local:/resource/Paris\'))); ?>', '', '111101101N',
    	'dav', 'administrators', 'dav', 'dav');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": iri.vsp upload : RET=" $LAST[1] "\n";

select equ (get ('http://localhost:$U{HTTPPORT1}/iri.vsp', 'dav:dav'), 'http://localhost:$U{HTTPPORT1}/resource/Paris');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": IRI returned from HTTP context\n";

get ('http://localhost:$U{HTTPPORT1}/', 'dav:dav');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DAV browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT1}/', 'dav:err');
ECHO BOTH $IF $EQU $STATE 'HT401' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Wrong password test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--delete from SYS_USERS where U_ID >= 100;
--insert into WS.WS.SYS_DAV_USER (U_ID, U_NAME, U_PWD, U_DEF_PERMS, U_GROUP, U_ACCOUNT_DISABLED)
--    values (2, 'user', 'pass', '11010000', 1, 0);
DAV_ADD_USER_INT ('user', 'pass', 'administrators', '11010000', 0, NULL, '', '');
update WS.WS.SYS_DAV_USER set U_ID = 1001 where U_NAME = 'user';

get ('http://localhost:$U{HTTPPORT1}/', 'user:pass');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": User account test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update WS.WS.SYS_DAV_COL set COL_PERMS = '110100100R' where COL_ID = 1;
get ('http://localhost:$U{HTTPPORT1}/', null);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Public access test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update WS.WS.SYS_DAV_COL set COL_PERMS = '110100000R' where COL_ID = 1;

meth ('http://localhost:$U{HTTPPORT1}/user/', 'MKCOL', 'dav:dav', null);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Created new folder with admin account : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

meth ('http://localhost:$U{HTTPPORT1}/user/', 'MKCOL', 'dav:dav', null);
ECHO BOTH $IF $EQU $STATE 'HT405' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Access to / denied with user account : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update WS.WS.SYS_DAV_COL set COL_OWNER = 1001 where WS.WS.COL_PATH (COL_ID) = '/DAV/user/';

meth ('http://localhost:$U{HTTPPORT1}/user/public/', 'MKCOL', 'user:pass', null);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Created new folder with user account under /user : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


meth ('http://localhost:$U{HTTPPORT1}/user/public/doc.txt', 'PUT', 'user:pass', 'qwerty');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Created new resource with user account under /user/public : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select RES_FULL_PATH from WS.WS.SYS_DAV_RES where contains (RES_CONTENT, 'qwerty');
ECHO BOTH $IF $EQU $LAST[1] '/DAV/user/public/doc.txt' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": new resource uploaded and text indexed : " $LAST[1] "\n";

get ('http://localhost:$U{HTTPPORT1}/user/public/doc.txt', null);
ECHO BOTH $IF $EQU $STATE 'HT401' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Public access test to doc.txt denied : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update WS.WS.SYS_DAV_RES set RES_PERMS = '110100100R' where RES_FULL_PATH = '/DAV/user/public/doc.txt';
get ('http://localhost:$U{HTTPPORT1}/user/public/doc.txt', null);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Public read access test have granted to doc.txt : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

meth ('http://localhost:$U{HTTPPORT1}/user/public/doc.txt', 'PUT', null, 'abcde');
ECHO BOTH $IF $EQU $STATE 'HT401' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Public write access to doc.txt denied : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select blob_to_string(RES_CONTENT) from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/user/public/doc.txt';
ECHO BOTH $IF $EQU $LAST[1] 'qwerty' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": resource not changed : " $LAST[1] "\n";

select res_full_path from ws..sys_dav_res;

meth ('http://localhost:$U{HTTPPORT1}/index.html', 'PUT', 'dav:dav', 'default page');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": default page index.html created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update WS.WS.SYS_DAV_RES set RES_PERMS = '110100100R' where RES_FULL_PATH = '/DAV/index.html';
get ('http://localhost:$U{HTTPPORT1}/', null);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Public access test to index.html granted : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select test_gz ($U{HTTPPORT1});
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": HTTP test gz encoding : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select make_big_vsp ();

select length (http_get (concat ('http://localhost:'|| cast (($U{HTTPPORT1} + 17) as varchar)||'/big.vsp'), NULL, 'GET'));
ECHO BOTH $IF $EQU $LAST[1] 7505000 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": HTTP test string_session tmp file : STATE=" $STATE "  LAST="  $LAST[1] "\n";

VHOST_REMOVE ('localhost:$U{HTTPPORT1}','localhost:$U{HTTPPORT1}', '/', 1);

select http_listen_host ('localhost:$U{HTTPPORT1}',2);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Listening host on : " $U{HTTPPORT1} " stopped & tested\n";

delete from WS.WS.SYS_DAV_COL where COL_OWNER = 1001;
delete from WS.WS.SYS_DAV_RES where RES_OWNER = 1001;
delete from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/index.html';

mutex_stat();

VHOST_DEFINE (ppath => '/test_404', lpath => '/test_404', vsp_user => 'dba', opts => vector ('executable', 'yes', '404_page', '404.vsp'));

create procedure
resp_get (in uri varchar, in up varchar)
{
  declare rc any;
  declare res varchar;
  if (up is not null)
    res := http_get (uri, rc, 'GET', concat ('Authorization: Basic ', encode_base64 (up)));
  else
    res := http_get (uri, rc, 'GET');
--  dbg_obj_print ('>>>> RESPONSE : \n', rc, '>>>>>>>>>>>>>\n');
  result_names (res);
  result (res);
  rc := c_resp (rc);
  rc (rc);
  return res;
};

select replace (resp, '\n', '') from resp_get (_url, _auth) (resp varchar) x
where _url = 'http://localhost:$U{HTTPPORT}/test_404/non-existant.vsp' and _auth = 'dba:dba';
ECHO BOTH $IF $EQU $LAST[1] '<h4>404 subst vsp</h4>' "PASSED" "***FAILED";
ECHO BOTH ": BUG 5529: 404 handler fired : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select replace (resp, '\n', '') from resp_get (_url, _auth) (resp varchar) x
where _url = 'http://localhost:$U{HTTPPORT}/test_404/non-ex-dir/non-existant.vsp' and _auth = 'dba:dba';
ECHO BOTH $IF $EQU $LAST[1] '<h4>404 subst vsp</h4>' "PASSED" "***FAILED";
ECHO BOTH ": BUG 5529: 404 handler fired : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

VHOST_REMOVE (lpath => '/test_404', del_vsps => 1);

USER_CREATE ('davuser', 'davuser', vector ('DAV_ENABLE', 1, 'SQL_ENABLE', 0));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": davuser creation : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select "DB"."DBA"."DAV_COL_CREATE" ('/DAV/mustnotbecreated/', '110100100N', 'dba', NULL, 'dav', NULL);
ECHO BOTH $IF $LT $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": null password passed to DAV API : RET=" $LAST[1] "\n";

select DAV_RES_UPLOAD ('/DAV/run.vsp', '<?vsp http (user); ?>', '', '111101101N',
    	'dav', 'administrators', 'dav', 'dav');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": run.vsp upload : RET=" $LAST[1] "\n";

select DAV_RES_UPLOAD ('/DAV/norun.vsp', '<?vsp http (user); ?>', '', '111101101N',
    	'davuser', null, 'dav', 'dav');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": norun.vsp upload : RET=" $LAST[1] "\n";

create procedure get_ct (in path any)
{
  declare hdr any;
  declare cnt any;
  cnt := http_get (sprintf ('http://localhost:%s%s', server_http_port (), path), hdr);
  if (hdr[0] not like 'HTTP/1.1 200 %')
    signal ('DAVSC', hdr[0]);
  return cnt;
}
;

select get_ct ('/DAV/run.vsp');
ECHO BOTH $IF $EQU $LAST[1] 'dba' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": run.vsp test : RET=[" $LAST[1] "]\n";

select get_ct ('/DAV/norun.vsp');
ECHO BOTH $IF $EQU $LAST[1] '<?vsp http (user); ?>' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": norun.vsp test : RET=[" $LAST[1] "]\n";


select DAV_RES_UPLOAD ('/DAV/run.vsp', '<?vsp http (\'user=\'||user); ?>', '', '111101101N',
    	'dav', 'administrators', 'davuser', 'davuser');
ECHO BOTH $IF $LT $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": run.vsp upload by davuser : RET=" $LAST[1] "\n";

select get_ct ('/DAV/run.vsp');
ECHO BOTH $IF $EQU $LAST[1] 'dba' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": run.vsp test : RET=[" $LAST[1] "]\n";


select "DB"."DBA"."DAV_COL_CREATE" ('/DAV/ex/', '110100100N', 'dav', null, 'dav', 'dav');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": /DAV/ex creation : RET=" $LAST[1] "\n";

VHOST_REMOVE (lpath=>'/davex');
VHOST_DEFINE (lpath=>'/davex', ppath=>'/DAV/ex/', is_dav=>1, vsp_user=>'dba', opts=>vector ('executable', 'yes'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": VHOST_DEFINE (lpath=>'/davex', ppath=>'/DAV/ex/') : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


select DAV_RES_UPLOAD ('/DAV/ex/runex.vsp', '<?vsp http (user); ?>', '', '111101101N',
    	'davuser', null, 'dav', 'dav');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": runex.vsp upload : RET=" $LAST[1] "\n";


select get_ct ('/davex/runex.vsp');
ECHO BOTH $IF $EQU $LAST[1] 'dba' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": runex.vsp test vi /davex : RET=[" $LAST[1] "]\n";

select get_ct ('/DAV/ex/runex.vsp');
ECHO BOTH $IF $EQU $LAST[1] '<?vsp http (user); ?>' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": runex.vsp test via /DAV : RET=[" $LAST[1] "]\n";

select equ (iri_to_id ('http://localhost:'||server_http_port ()||'/resource/Paris'), iri_to_id ('local:/resource/Paris')) ;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": IRI of local:/resource/Paris\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: HTTP server tests\n";
