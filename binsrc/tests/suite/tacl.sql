--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2015 OpenLink Software
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

echo BOTH "STARTED: HTTP ACL tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

-- wrapper procedure to report readable state
create procedure _http_acl_get (in list varchar, in ip varchar, in dst varchar := null, in obj int := -1, in rw int := -1)
{
  declare rc any;
  rc := http_acl_get (list, ip, dst, obj, rw);
  return case rc when 1 then 'denied' when 0 then 'allowed' when -1 then 'undefined' else 'error' end;
};

-- allow few; deny all
insert into HTTP_ACL (HA_LIST, HA_ORDER, HA_CLIENT_IP, HA_FLAG) values ('TEST', 1, '127.0.0.*', 0);
insert into HTTP_ACL (HA_LIST, HA_ORDER, HA_CLIENT_IP, HA_FLAG) values ('TEST', 2, '192.168.1.*', 0);
insert into HTTP_ACL (HA_LIST, HA_ORDER, HA_CLIENT_IP, HA_FLAG) values ('TEST', 3, '*', 1);


select _http_acl_get ('TEST', '127.0.0.1');
ECHO BOTH $IF $EQU $LAST[1] 'allowed' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ACL TEST/127.0.0.* allowed : " $LAST[1]  "\n";


select _http_acl_get ('TEST', '192.168.1.1');
ECHO BOTH $IF $EQU $LAST[1] 'allowed' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ACL TEST/192.168.1.* allowed : " $LAST[1]  "\n";

select _http_acl_get ('TEST', '224.0.0.1');
ECHO BOTH $IF $EQU $LAST[1] 'denied' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ACL TEST/all denied : " $LAST[1]  "\n";

-- order test - deny all
update HTTP_ACL set HA_ORDER = 0 where HA_LIST = 'TEST' and HA_CLIENT_IP = '*';

select _http_acl_get ('TEST', '127.0.0.1');
ECHO BOTH $IF $EQU $LAST[1] 'denied' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ACL TEST/127.0.0.* denied : " $LAST[1]  "\n";


select _http_acl_get ('TEST', '192.168.1.1');
ECHO BOTH $IF $EQU $LAST[1] 'denied' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ACL TEST/192.168.1.* denied : " $LAST[1]  "\n";

select _http_acl_get ('TEST', '224.0.0.1');
ECHO BOTH $IF $EQU $LAST[1] 'denied' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ACL TEST/all denied : " $LAST[1]  "\n";

-- remove deny list
delete from HTTP_ACL where HA_LIST = 'TEST' and HA_CLIENT_IP = '*';

select _http_acl_get ('TEST', '127.0.0.1');
ECHO BOTH $IF $EQU $LAST[1] 'allowed' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ACL TEST/127.0.0.* allowed : " $LAST[1]  "\n";


select _http_acl_get ('TEST', '192.168.1.1');
ECHO BOTH $IF $EQU $LAST[1] 'allowed' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ACL TEST/192.168.1.* allowed : " $LAST[1]  "\n";

-- undefined item; default action
select _http_acl_get ('TEST', '224.0.0.1');
ECHO BOTH $IF $EQU $LAST[1] 'undefined' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ACL TEST/all undefined : " $LAST[1]  "\n";

select http_client_ip ();
ECHO BOTH $IF $EQU $LAST[1] '127.0.0.1' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Local host address : " $LAST[1]  "\n";

delete from HTTP_ACL where HA_LIST = 'TEST';

-- deny few; allow all
insert into HTTP_ACL (HA_LIST, HA_ORDER, HA_CLIENT_IP, HA_FLAG) values ('TEST', 1, '224.*', 1);
insert into HTTP_ACL (HA_LIST, HA_ORDER, HA_CLIENT_IP, HA_FLAG) values ('TEST', 2, '*', 0);

select _http_acl_get ('TEST', '127.0.0.1');
ECHO BOTH $IF $EQU $LAST[1] 'allowed' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ACL TEST/127.0.0.* allowed : " $LAST[1]  "\n";


select _http_acl_get ('TEST', '192.168.1.1');
ECHO BOTH $IF $EQU $LAST[1] 'allowed' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ACL TEST/192.168.1.* allowed : " $LAST[1]  "\n";

select _http_acl_get ('TEST', '333.0.0.1');
ECHO BOTH $IF $EQU $LAST[1] 'allowed' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ACL TEST/any allowed : " $LAST[1]  "\n";

select _http_acl_get ('TEST', '224.0.0.1');
ECHO BOTH $IF $EQU $LAST[1] 'denied' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ACL TEST/224.* denied : " $LAST[1]  "\n";

delete from HTTP_ACL where HA_LIST = 'TEST';

-- HTTP acl test; allow all
insert into HTTP_ACL (HA_LIST, HA_ORDER, HA_CLIENT_IP, HA_FLAG) values ('HTTP', 1, '*', 0);

select http_get ('http://localhost:$U{HTTPPORT}/');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": HTTP ACL allowed : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from HTTP_ACL where HA_LIST = 'HTTP';

-- HTTP acl test; deny all
insert into HTTP_ACL (HA_LIST, HA_ORDER, HA_CLIENT_IP, HA_FLAG) values ('HTTP', 1, '*', 1);

create procedure acl_check ()
{
  declare h any;
  http_get ('http://localhost:$U{HTTPPORT}/', h);
  if (h[0] not like 'HTTP/1._ 200 %')
    signal ('.....', h[0]);
}
;

acl_check ();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": HTTP ACL denied : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from HTTP_ACL where HA_LIST = 'HTTP';

-- like PROXY acl; allow localhost only
insert into HTTP_ACL (HA_LIST, HA_ORDER, HA_CLIENT_IP, HA_FLAG, HA_DEST_IP) values ('TEST', 1, '127.0.0.*', 0, 'localhost');
insert into HTTP_ACL (HA_LIST, HA_ORDER, HA_CLIENT_IP, HA_FLAG, HA_DEST_IP) values ('TEST', 2, '*', 1, '*');

select _http_acl_get ('TEST', '127.0.0.1', 'localhost');
ECHO BOTH $IF $EQU $LAST[1] 'allowed' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ACL TEST/127.0.0.* -> localhost allowed : " $LAST[1]  "\n";

select _http_acl_get ('TEST', '192.168.1.1', 'localhost');
ECHO BOTH $IF $EQU $LAST[1] 'denied' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ACL TEST/* -> localhost denied : " $LAST[1]  "\n";

select _http_acl_get ('TEST', '127.0.0.1', 'foo.bar');
ECHO BOTH $IF $EQU $LAST[1] 'denied' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ACL TEST/127.0.0.* -> foo.bar denied : " $LAST[1]  "\n";

select _http_acl_get ('TEST', '192.168.1.1', '192.168.1.1');
ECHO BOTH $IF $EQU $LAST[1] 'denied' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ACL TEST/* -> * denied : " $LAST[1]  "\n";

delete from HTTP_ACL where HA_LIST = 'TEST';

-- like NEWS acl test
insert into HTTP_ACL (HA_LIST, HA_ORDER, HA_CLIENT_IP, HA_FLAG, HA_OBJECT, HA_RW) values ('TEST', 1, '127.0.0.*', 0, 12, 1);
insert into HTTP_ACL (HA_LIST, HA_ORDER, HA_CLIENT_IP, HA_FLAG, HA_OBJECT, HA_RW) values ('TEST', 2, '*', 1, 12, 1);

select _http_acl_get ('TEST', '127.0.0.1', null, 12, 1);
ECHO BOTH $IF $EQU $LAST[1] 'allowed' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ACL TEST/127.0.0.* obj=12 rw=1  allowed : " $LAST[1]  "\n";

select _http_acl_get ('TEST', '192.168.1.1', null, 12, 1);
ECHO BOTH $IF $EQU $LAST[1] 'denied' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ACL TEST/* obj=12 rw=1 denied : " $LAST[1]  "\n";

delete from HTTP_ACL where HA_LIST = 'TEST';

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: HTTP ACL tests\n";

