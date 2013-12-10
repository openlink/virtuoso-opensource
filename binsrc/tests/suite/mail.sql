--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2013 OpenLink Software
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
create procedure
test_make_mail ()
{
  declare new_m, new_m2 any;
  declare idx int;

  DAV_ADD_USER_INT ('user1', 'test1', 'user1', '11010000', 0, NULL, '', '');
  DAV_ADD_USER_INT ('user2', 'test2', 'user1', '11010000', 0, NULL, '', '');
  DAV_ADD_USER_INT ('user3', 'test3', 'user1', '11010000', 1, NULL, '', '');

--  insert into WS.WS.SYS_DAV_USER (U_GROUP, U_NAME, U_PWD, U_ID, U_ACCOUNT_DISABLED, U_DAV_ENABLE, U_SQL_ENABLE) values (1001, 'user1', 'test1', 1001, 0, 1, 0);
--  insert into WS.WS.SYS_DAV_USER (U_GROUP, U_NAME, U_PWD, U_ID, U_ACCOUNT_DISABLED, U_DAV_ENABLE, U_SQL_ENABLE) values (1001, 'user2', 'test2', 1002, 0, 1, 0);
--  insert into WS.WS.SYS_DAV_USER (U_GROUP, U_NAME, U_PWD, U_ID, U_ACCOUNT_DISABLED, U_DAV_ENABLE, U_SQL_ENABLE) values (1001, 'user3', 'test3', 1003, 1, 1, 0);

  new_m := file_to_string ('eml1.eml');
  new_m2 := file_to_string ('eml2.eml');

  idx := 0;

  while (idx < 50 )
    {
      NEW_MAIL ('user1', new_m);
      NEW_MAIL ('user1', new_m2);
      NEW_MAIL ('user2', new_m);
      NEW_MAIL ('user2', new_m2);
      idx := idx + 1;
    }
  commit work;

  return 1;
}
;


create procedure
_test1 ()
{
  declare res any;
  declare str, test_uidl varchar;

  res := pop3_get ('localhost $U{POP3PORT}', 'user1', 'test1', 9999999, 'UiDL');
  res := pop3_get ('localhost $U{POP3PORT}', 'user2', 'test2', 88888, 'DELETE');
  res := pop3_get ('localhost $U{POP3PORT}', 'user2', 'test2', 88888, 'UiDL');
  test_uidl := (aref (res, 9));

  if (test_uidl = '4644d6ec85405d0e1b8fa5f0f27e57acv_pop')
     return 1;

  return NULL;
}
;


create procedure
_test2 ()
{
  declare res any;
  declare str varchar;

  res := pop3_get ('localhost $U{POP3PORT}', 'user2', 'test2', 88888);
  str := vec_2_str (aref (res, 2));

  NEW_MAIL ('user2', str);
  NEW_MAIL ('user2', str);
  NEW_MAIL ('user1', str);
  NEW_MAIL ('user1', str);

  commit work;

  res := pop3_get ('localhost $U{POP3PORT}', 'user2', 'test2', 99999999, 'UiDL');

  if (length (res) = 91)
    return 1;

  return NULL;
}
;


create procedure
vec_2_str (in _in any)
{
  declare res varchar;
  declare idx, len int;

  idx := 0;
  len := length (_in);
  res := '';

  while (idx < len )
    {
      res := concat (res, aref (_in, idx));
      idx := idx + 1;
    }

  return  res;
}
;

select test_make_mail();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": POP3 Send mail  : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select _test1();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": POP3 UIDL return CORRECT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select (length (pop3_get('localhost $U{POP3PORT}', 'user2', 'test2', 19999, '', vector ('4644d6ec85405d0e1b8fa5f0f27e57acv_pop'))));
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": POP3 Disable messages : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select _test2();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": POP3 Get number of message : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select pop3_get ('localhost $U{POP3PORT}', 'user3', 'test3', 88888, 'UiDL');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": POP3 disabled user check : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select pop3_get ('localhost $U{POP3PORT}', 'user4', 'test4', 88888, 'UiDL');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": POP3 non-existent user check : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select pop3_get ('localhost $U{POP3PORT}', 'user1', 'wrong_pwd', 88888, 'UiDL');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": POP3 wrong password check : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
