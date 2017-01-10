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
echo BOTH "STARTED: DAV migration test - checking\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

create procedure rc (in code integer)
{
  if (code < 200 or code > 399)
    signal (sprintf ('HT%d', code), sprintf ('Failed with code (%d)', code));
}


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


--set echo on;

get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin1/blabla1.xml', 'dav_admin1:dav_admin1_pwd');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin1/blabla12.xml', 'dav_admin1:dav_admin1_pwd');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin1/blabla13.xml', 'dav_admin1:dav_admin1_pwd');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin2/blabla2.xml', 'dav_admin1:dav_admin1_pwd');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin2/blabla22.xml', 'dav_admin1:dav_admin1_pwd');
ECHO BOTH $IF $EQU $STATE OK "***FAILED" "PASSED" ;
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin2/blabla23.xml', 'dav_admin1:dav_admin1_pwd');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";



get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin1/blabla1.xml', 'dav_admin2:dav_admin2_pwd');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin1/blabla12.xml', 'dav_admin2:dav_admin2_pwd');
ECHO BOTH $IF $EQU $STATE OK "***FAILED" "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin1/blabla13.xml', 'dav_admin2:dav_admin2_pwd');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin2/blabla2.xml', 'dav_admin2:dav_admin2_pwd');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin2/blabla22.xml', 'dav_admin2:dav_admin2_pwd');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin2/blabla23.xml', 'dav_admin2:dav_admin2_pwd');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";



get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin1/blabla1.xml', 'dav_admin:dav_admin_pwd');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin1/blabla12.xml', 'dav_admin:dav_admin_pwd');
ECHO BOTH $IF $EQU $STATE OK "***FAILED" "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin1/blabla13.xml', 'dav_admin:dav_admin_pwd');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin2/blabla2.xml', 'dav_admin:dav_admin_pwd');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin2/blabla22.xml', 'dav_admin:dav_admin_pwd');
ECHO BOTH $IF $EQU $STATE OK "***FAILED" "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin2/blabla23.xml', 'dav_admin:dav_admin_pwd');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";



get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin1/blabla1.xml', 'dav_user:dav_user_pwd');
ECHO BOTH $IF $EQU $STATE OK "***FAILED" "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin1/blabla12.xml', 'dav_user:dav_user_pwd');
ECHO BOTH $IF $EQU $STATE OK "***FAILED" "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin1/blabla13.xml', 'dav_user:dav_user_pwd');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin2/blabla2.xml', 'dav_user:dav_user_pwd');
ECHO BOTH $IF $EQU $STATE OK "***FAILED" "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin2/blabla22.xml', 'dav_user:dav_user_pwd');
ECHO BOTH $IF $EQU $STATE OK "***FAILED" "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

get ('http://localhost:$U{HTTPPORT}/DAV/col_all/col_admins/admin2/blabla23.xml', 'dav_user:dav_user_pwd');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": browse page retrieved : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";



ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: DAV migration test - checking\n";
