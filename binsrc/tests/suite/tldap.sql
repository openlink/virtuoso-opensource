--
--  $Id: tldap.sql,v 1.8.2.1.4.1 2013/01/02 16:15:12 source Exp $
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

-- Bugzilla 3099
echo BOTH "STARTED: Ldap test\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

--connection_set ('LDAP_VERSION', 2);

select __proc_exists ('LDAP_SEARCH', 2);
ECHO BOTH $IF $EQU $LAST[1] LDAP_SEARCH "PASSED" "SKIP NEXT 3 TESTS.";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test LDAP support : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure ldap_t1 ()
{
  if (__proc_exists ('LDAP_SEARCH', 2))
     return ldap_search ('ldap://mail.usnet.private:389', 0, 'o=OpenLink Software, c=US', '(cn=Kingsley*)', 'ou=Accounts, o=OpenLink Software, c=US', '')[3][3];
  else
     return 'Success';
}
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create procedure ldap_t1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure ldap_t2 ()
{
  if (__proc_exists ('LDAP_SEARCH', 2))
     return ldap_search ('ldap://mail.usnet.private:389', 0, 'o=OpenLink Software, c=US', '(cn=Orri*)', 'ou=Accounts, o=OpenLink Software, c=US', '')[1][1];
  else
     return 'uid=oerling,ou=Accounts,o=OpenLink Software,c=US';
}
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create procedure ldap_t2 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure ldap_t3 ()
{
  if (__proc_exists ('LDAP_SEARCH', 2))
     return ldap_search ('ldap://mail.usnet.private:389', 0, 'o=OpenLink Software, c=US', '(cn=Kingsley*)', 'ou=Accounts, o=OpenLink Software, c=US', '')[1][1];
  else
     return 'uid=kidehen,ou=Accounts,o=OpenLink Software,c=US';
}
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create procedure ldap_t3 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select ldap_t1 ();
ECHO BOTH $IF $EQU $LAST[1] Success "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Ldap Search (cn=K*) : $LAST[1]=" $LAST[1] " MESSAGE=" $MESSAGE "\n";

select ldap_t2 ();
ECHO BOTH $IF $EQU $LAST[1] "uid=oerling,ou=Accounts,o=OpenLink Software,c=US" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Ldap Search (cn=Orri*) : uid = " $LAST[1] " MESSAGE=" $MESSAGE "\n";

select ldap_t3 ();
ECHO BOTH $IF $EQU $LAST[1] "uid=kidehen,ou=Accounts,o=OpenLink Software,c=US" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Ldap Search (cn=Kingsley*) : uid = " $LAST[1] " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: Ldap tests\n";
