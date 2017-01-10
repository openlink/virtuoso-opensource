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
select DAV_DELETE (WS.WS.COL_PATH (COL_ID), 0, 'dav', 'dav') from WS.WS.SYS_DAV_COL where COL_PARENT = 1;
checkpoint;

create procedure test_ftp (in _user varchar, in _pass varchar, in _ftp_path varchar,
			   in _local_name varchar, in pasv integer)
{

  declare file1, file2 any;

  ftp_get ('localhost:$U{FTPPORT}', _user, _pass, _ftp_path, 'ftp_test_file', 1);

  file1 := file_to_string ('ftp_test_file');
  file2 := file_to_string (_local_name);

  if (file1 = file2) return 1;

  return 0;
}
;

select DAV_ADD_GROUP ('ftp', 'dav', 'dav');
ECHO BOTH $IF $EQU $LAST[1] -1  "***FAILED" "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP add group ftp\n";

select DAV_ADD_USER ('user1', 'pass1', 'ftp', '111000000', 0,  '/DAV/u1/', 'User 1', 'u1@localhost', 'dav', 'dav');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP create user1\n";

select DAV_ADD_USER ('user2', 'pass2', 'ftp', '111000000', 0,  '/DAV/u2/', 'User 2', 'u2@localhost', 'dav', 'dav');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP create user2\n";

select DAV_ADD_USER ('user3', 'pass3', 'ftp', '111000000', 0,  '/DAV/u3/', 'User 3', 'u3@localhost', 'dav', 'dav');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP create user3\n";

select ftp_put ('localhost:$U{FTPPORT}', 'dav', 'dav', 'words.esp', 'words.esp', 0);
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP upload words.esp user dav passive mode\n";

select ftp_put ('localhost:$U{FTPPORT}', 'dav', 'dav', 'test_1947.db.test', 'test_1947.db.test', 0);
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP upload test_1947.db.test user dav\n";

select ftp_put ('localhost:$U{FTPPORT}', 'dav', 'dav', 'nwdemo.sql', 'nwdemo.sql', 1);
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP upload nwdemo.sql user dav\n";

select ftp_put ('localhost:$U{FTPPORT}', 'dav', 'dav', 'nwdemo_norefs.sql', 'nwdemo_norefs.sql', 0);
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP upload nwdemo_norefs.sql user dav\n";

select ftp_put ('localhost:$U{FTPPORT}', 'user1', 'pass1', 'words.esp', 'words.esp', 1);
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP upload words.esp user1\n";

select ftp_put ('localhost:$U{FTPPORT}', 'user2', 'pass2', 'test_1947.db.test', 'test_1947.db.test', 0);
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP upload test_1947.db.test user2\n";

select length (ftp_ls ('localhost:$U{FTPPORT}', 'dav', 'dav', '', 0));
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP ls dav home expected 7 returned " $LAST[1] " entries\n";

select length (ftp_ls ('localhost:$U{FTPPORT}', 'dav', 'dav', 'u1', 0));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP ls dav home user dav passive mode\n";

select length (ftp_ls ('localhost:$U{FTPPORT}', 'dav', 'dav', 'u1', 1));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP ls dav home user dav\n";

select length (ftp_ls ('localhost:$U{FTPPORT}', 'user2', 'pass2', '', 0));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP ls u2 home passive mode\n";

select length (ftp_ls ('localhost:$U{FTPPORT}', 'user2', 'pass2', '', 1));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP ls u2 home\n";

select length (ftp_ls ('localhost:$U{FTPPORT}', 'dav', 'dav', 'u1/', 0));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP ls u3 user dav\n";

select test_ftp ('dav', 'dav', 'nwdemo_norefs.sql', 'nwdemo_norefs.sql', 1);
ECHO BOTH $IF $EQU $LAST[1] 1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP check nwdemo_norefs.sql user dav\n";

select test_ftp ('dav', 'dav', 'u1/words.esp', 'words.esp', 0);
ECHO BOTH $IF $EQU $LAST[1] 1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP check u1/words.esp user dav passive mode\n";

select test_ftp ('dav', 'dav', 'u1/words.esp', 'words.esp', 1);
ECHO BOTH $IF $EQU $LAST[1] 1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP check u1/words.esp user dav\n";

select test_ftp ('dav', 'dav', 'u2/test_1947.db.test', 'test_1947.db.test', 1);
ECHO BOTH $IF $EQU $LAST[1] 1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP check u2/test_1947.db.test user dav\n";

select test_ftp ('user1', 'pass1', 'words.esp', 'words.esp', 0);
ECHO BOTH $IF $EQU $LAST[1] 1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP check words.esp user user1\n";

select test_ftp ('user2', 'pass2', 'test_1947.db.test', 'test_1947.db.test', 1);
ECHO BOTH $IF $EQU $LAST[1] 1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP check test_1947.db.test user2 passive mode\n";

select test_ftp ('user2', 'pass2', 'test_1947.db.test', 'test_1947.db.test', 0);
ECHO BOTH $IF $EQU $LAST[1] 1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP check test_1947.db.test user2\n";

select test_ftp ('user2', 'pass22', 'test_1947.db.test', 'test_1947.db.test', 0);
ECHO BOTH $IF $NEQ $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP check wrong password user1\n";

select ftp_put ('localhost:$U{FTPPORT}', 'anonymous', 'test@test.com', 'test_1947.db.test', 'test_1947.db.test', 0);
ECHO BOTH $IF $NEQ $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP write permission anonymous user\n";


update WS.WS.SYS_DAV_COL set COL_PERMS = '110100110R' where COL_NAME = 'DAV';
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP update permission /DAV/ \n";


update WS.WS.SYS_DAV_COL set COL_PERMS = '110100100R' where COL_NAME = 'u1';
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP update permission /DAV/u1/ \n";


select length (ftp_ls ('localhost:$U{FTPPORT}', 'anonymous', 'test@test.com', '', 0));
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP ls / user anonymous passive mode expected 7 returned " $LAST[1] " entries\n";


select length (ftp_ls ('localhost:$U{FTPPORT}', 'anonymous', 'test@test.com', 'u1', 1));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP ls /u1/ user anonymous\n";


select ftp_put ('localhost:$U{FTPPORT}', 'anonymous', 'test@test.com', 'tftp.sql', 'tftp.sql', 0);
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP user anonymous write in home directory.\n";


select length (ftp_ls ('localhost:$U{FTPPORT}', 'anonymous', 'test@test.com', '', 0));
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP ls / user anonymous passive mode expected 8 returned " $LAST[1] " entries\n";

select ftp_put ('localhost:$U{FTPPORT}', 'anonymous', 'test@test.com', 'tftp.sql', 'u1/tftp.sql', 0);
ECHO BOTH $IF $NEQ $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP user anonymous write to u1.\n";


update WS.WS.SYS_DAV_RES set RES_PERMS = '110100100R' where RES_FULL_PATH = '/DAV/u1/words.esp';
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP update permission /DAV/u1/words.esp \n";


select ftp_get ('localhost:$U{FTPPORT}', 'anonymous', 'test@test.com', 'u1/words.esp', 'test_file', 1);
ECHO BOTH $IF $EQU $STATE 'OK' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP get user anonymous /u1/words.esp \n";


select ftp_put ('localhost:$U{FTPPORT}', 'anonymous', 'test@test.com', 'test_file', 'u1/words.esp', 1);
ECHO BOTH $IF $NEQ $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP try to upload user anonymous /u1/words.esp \n";


update WS.WS.SYS_DAV_RES set RES_PERMS = '110100110R' where RES_FULL_PATH = '/DAV/u1/words.esp';
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP update permission /DAV/u1/words.esp \n";


select ftp_put ('localhost:$U{FTPPORT}', 'anonymous', 'test@test.com', 'test_file', 'u1/words.esp', 1);
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP upload user anonymous /u1/words.esp \n";


select ftp_put ('localhost:$U{FTPPORT}', 'anonymous', 'test@test.com', 'test_file', 'u1/test_file', 1);
ECHO BOTH $IF $NEQ $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FTP upload user anonymous /u1/test_file \n";
