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
backup_context_clear();

DELETE USER IMPOSTER;
CREATE USER IMPOSTER;

RECONNECT IMPOSTER;

create procedure check_unauth_backup_sec ()
{
  whenever SQLSTATE '42000' goto unsucc;
  BACKUP_ONLINE('imposter_#', 150);

  return '***FAILED';

unsucc:
  return 'PASSED';
}
;

create procedure check_auth_backup_sec ()
{
  whenever SQLSTATE '42000' goto succ;
  BACKUP_ONLINE('imposter_#', 150);

  return 'PASSED';

succ:
  return '***FAILED';
}
;

SELECT CHECK_UNAUTH_BACKUP_SEC();
ECHO BOTH $LAST[1];
ECHO BOTH ": Invoking BACKUP_ONLINE procedure from unauthtorized user test\n";

RECONNECT dba;
SELECT CHECK_AUTH_BACKUP_SEC();
ECHO BOTH $LAST[1];
ECHO BOTH ": Invoking BACKUP_ONLINE procedure from authtorized user test\n";


ADD USER GROUP IMPOSTER "DBA";
-- insert into sys_user_group select a.u_id, b.u_group from sys_users a, sys_users b where b.u_name = 'BACKUP' and a.u_name = 'IMPOSTER';

RECONNECT "IMPOSTER";

SELECT CHECK_AUTH_BACKUP_SEC();
ECHO BOTH $LAST[1];
ECHO BOTH ": Invoking BACKUP_ONLINE procedure from authtorized user test\n";

BACKUP_ONLINE ('/usr/aaa_#', 150, 200);
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
ECHO BOTH ": " $STATE " FILENAME CHECK1 TEST\n";

BACKUP_ONLINE ('usr/../aaa_#', 150, 200);
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
ECHO BOTH ": " $STATE " FILENAME CHECK2 TEST\n";

BACKUP_ONLINE ('f:/../aaa_#', 150, 200);
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
ECHO BOTH ": " $STATE " FILENAME CHECK3 TEST\n";

BACKUP_ONLINE ('toolongfile111111sdfsdlfkjsdlfkjsdlfkjsldkfjsldkfjsldkjflskdjflskdjflskdjflskdjflskdjflskdjflskjdflskjdflskjdflskjdflskdjflskdjflskdjflskdjflskjdflskjdflskdjflskdjflskdjf1111112222222222233333333334444444444555555555566666666667777ksjdhfkjashdfkashdfkjahsdkfjhaskdfhaksdjhfkajshdfkjasdfha777777', 150, 200);
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
ECHO BOTH ": " $STATE " TOO LONG FILEE TEST\n";

#BACKUP_CONTEXT_CLEAR();
#CHECK_TIMEOUT_ERROR();
#ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
#ECHO BOTH ": " $STATE " TIMEOUT TEST\n";


BACKUP_CONTEXT_CLEAR();

create procedure create_seqs (in pr varchar, in imax integer)
{
 declare idx integer;
 idx := 0;
 while (idx < imax)
  {
    sequence_next (sprintf ('%s%ld', pr, idx));
    idx := idx + 1;
  }
}
;

create procedure check_seqs (in pr varchar, in imax integer, in val integer)
{
 declare idx integer;
 idx := 0;
 while (idx < imax)
  {
    if (val <> sequence_next (sprintf ('%s%ld',pr, idx)))
	{
	  return 'NOTEQUAL';
	}
    idx := idx + 1;
  }
 return 'EQUAL';
}
;


create_seqs ('h', 10000);

 
checkpoint;
 

create_seqs ('ax', 10000);
create_seqs ('bx', 10000);
create_seqs ('x', 10000);

backup_online ('vvv', 150);
