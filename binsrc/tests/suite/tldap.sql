--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2006 OpenLink Software
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

connection_set ('LDAP_VERSION', 2);

select  (ldap_search ('ldap://mail2.openlinksw.com:389', 0, 'ou=Accounts, o=OpenLink Software, c=US', '(cn=George*)', 'uid=gkodinov, ou=Accounts, o=OpenLink Software, c=US', 'gkodinov')[3][3]);
ECHO BOTH $IF $EQU $LAST[1] Success "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Ldap Search (cn=George*) : $LAST[1]=" $LAST[1] " MESSAGE=" $MESSAGE "\n";

select  (ldap_search ('ldap://mail2.openlinksw.com:389', 0, 'ou=Accounts, o=OpenLink Software, c=US', '(cn=George*)', 'uid=gkodinov, ou=Accounts, o=OpenLink Software, c=US', 'gkodinov')[1][5][0]);
ECHO BOTH $IF $EQU $LAST[1] gkodinov "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Ldap Search (cn=George*) : uid = " $LAST[1] " MESSAGE=" $MESSAGE "\n";

select  (ldap_search ('ldap://mail2.openlinksw.com:389', 0, 'ou=Accounts, o=OpenLink Software, c=US', '(cn=Kingsley*)', 'uid=gkodinov, ou=Accounts, o=OpenLink Software, c=US', 'gkodinov')[1][5][0]);
ECHO BOTH $IF $EQU $LAST[1] kidehen "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Ldap Search (cn=Kingsley*) : uid = " $LAST[1] " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: Ldap tests\n";
