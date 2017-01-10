--
--  tplscroll.sql
--
--  $Id$
--
--  PL Scrollable cursors suite testing
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

--
--  Start the test
--
echo BOTH "\nSTARTED: PL Scrollable cursors suite (tplscroll.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

drop table PLCR;
create table PLCR (id integer not null primary key);
insert into PLCR values (1);
insert into PLCR values (2);
insert into PLCR values (3);
insert into PLCR values (4);
insert into PLCR values (5);
insert into PLCR values (6);
insert into PLCR values (7);
insert into PLCR values (8);
insert into PLCR values (9);
insert into PLCR values (10);

select count (ID) from PLCR;
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": test table populated with " $LAST[1] " rows\n";

create procedure TEST_FWONLY ()
{
  declare cr cursor for select ID from PLCR;
  declare inx, data integer;
  inx := 0;

  whenever not found goto done;
  open cr;
  while (1)
    {
      fetch cr into data;
      inx := inx + 1;
    }
done:
  close cr;
  result_names (data);
  result (inx);
};
TEST_FWONLY ();
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": FORWARD-ONLY (traditional cursor statement) returned " $LAST[1] " rows\n";


create procedure TEST_STATIC ()
{
  declare cr static cursor for select ID from PLCR;
  declare inx, data integer;
  inx := 0;

  whenever not found goto done;
  open cr;
  while (1)
    {
      fetch cr into data;
      inx := inx + 1;
    }
done:
  close cr;
  result_names (data);
  result (inx);
};
TEST_STATIC ();
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": STATIC (with traditional cursor statement) returned " $LAST[1] " rows\n";

create procedure TEST_KEYSET ()
{
  declare cr keyset cursor for select ID from PLCR;
  declare inx, data integer;
  inx := 0;

  whenever not found goto done;
  open cr;
  while (1)
    {
      fetch cr into data;
      inx := inx + 1;
    }
done:
  close cr;
  result_names (data);
  result (inx);
};
TEST_KEYSET ();
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": KEYSET-DRIVEN (with traditional cursor statement) returned " $LAST[1] " rows\n";

create procedure TEST_DYNAMIC ()
{
  declare cr dynamic cursor for select ID from PLCR;
  declare inx, data integer;
  inx := 0;

  whenever not found goto done;
  open cr;
  while (1)
    {
      fetch cr into data;
      inx := inx + 1;
    }
done:
  close cr;
  result_names (data);
  result (inx);
};
TEST_DYNAMIC ();
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DYNAMIC (with traditional cursor statement) returned " $LAST[1] " rows\n";

create procedure ERR1 ()
{
  declare cr nonsence cursor for select ID from PLCR;
  declare inx, data integer;
  inx := 0;

  whenever not found goto done;
  open cr;
  while (1)
    {
      fetch cr into data;
      inx := inx + 1;
    }
done:
  close cr;
  result_names (data);
  result (inx);
};
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Non-valid cursor mode STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure ERR2 ()
{
  declare param integer;
  declare cr static cursor for select ID from PLCR where id < param1;
  declare inx, data integer;
  inx := 0;

  whenever not found goto done;
  open cr;
  while (1)
    {
      fetch cr into data;
      inx := inx + 1;
    }
done:
  close cr;
  result_names (data);
  result (inx);
};
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Non-present cursor parameter state=" $STATE " MESSAGE=" $MESSAGE "\n";


create procedure ERR3 ()
{
  declare cr cursor for select ID from PLCR;
  declare inx, data integer;
  inx := 0;

  whenever not found goto done;
  open cr;
  while (1)
    {
      fetch cr next into data;
      inx := inx + 1;
    }
done:
  close cr;
  result_names (data);
  result (inx);
};
ERR3();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Non-scrollable cursor with scrollable fetch behaves like FW only state=" $STATE " MESSAGE=" $MESSAGE "\n";


create procedure ERR4 ()
{
  declare cr cursor for select ID from PLCR;
  declare inx, data integer;
  inx := 0;

  whenever not found goto done;
  open cr;
  while (1)
    {
      fetch cr first into data;
      inx := inx + 1;
    }
done:
  close cr;
  result_names (data);
  result (inx);
};
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Non-scrollable cursor with scrollable FETCH state=" $STATE " MESSAGE=" $MESSAGE "\n";


create procedure ERR5 ()
{
  declare cr static cursor for select ID from PLCR;
  declare inx, data integer;
  inx := 0;

  whenever not found goto done;
  open cr;
  while (1)
    {
      fetch cr nonexisting into data;
      inx := inx + 1;
    }
done:
  close cr;
  result_names (data);
  result (inx);
};
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Non-valid cursor fetch direction state=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure ERR6 ()
{
  declare param integer;
  declare cr keyset cursor for select ID from PLCR where ID < param;
  declare inx, data integer;
  inx := 0;
  param := 2;

  whenever not found goto done;
  open cr;
  while (1)
    {
      fetch cr into data;
      inx := inx + 1;
    }
done:
  close cr;
  result_names (data);
  result (inx);
};
ERR6();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Cursor with parameters first row is " $LAST[1] "\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Cursor with parameters returned " $ROWCNT "\n";

create procedure TEST_STATIC_MODES ()
{
  declare cr static cursor for select ID from PLCR;
  declare inx, data integer;
  declare bm any;
  inx := 0;

  result_names (data);
  whenever not found goto done;
  whenever sqlstate 'HY019' goto done;
  open cr;
  fetch cr first into data;
  bm := bookmark (cr);
  result (data);
  if (data <> 1)
    signal ('.....', concat ('Invalid first row ', cast (data as varchar)));
  fetch cr next into data;
  result (data);
  if (data <> 2)
    signal ('.....', concat ('Invalid second row ', cast (data as varchar)));
  fetch cr last into data;
  result (data);
  if (data <> 10)
    signal ('.....', concat ('Invalid last row ', cast (data as varchar)));
  fetch cr previous into data;
  result (data);
  if (data <> 9)
    signal ('.....', concat ('Invalid next to last row ', cast (data as varchar)));
  delete from PLCR where ID = 1;
  fetch cr first into data;
  result (data);
  if (data <> 1)
    signal ('.....', 'Deleted row not found in static');

  fetch cr bookmark bm into data;
  result (data);
  if (data <> 1)
    signal ('.....', 'Bookmarked row not found in static');

  close cr;
  return;

done:
  signal ('.....', 'Not found');
  close cr;
  return;

deleted:
  signal ('.....', 'Row deleted');
  close cr;
  return;
};
TEST_STATIC_MODES();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Static fetch modes state=" $STATE " MESSAGE=" $MESSAGE "\n";


insert into PLCR values (1);
create procedure TEST_KEYSET_MODES ()
{
  declare cr keyset cursor for select ID from PLCR;
  declare inx, data integer;
  declare bm any;
  inx := 0;

  result_names (data);
  whenever not found goto done;
  whenever sqlstate 'HY109' goto done;
  open cr;

  fetch cr first into data;
  bm := bookmark (cr);
  result (data);
  if (data <> 1)
    signal ('.....', concat ('Invalid first row ', cast (data as varchar)));

  fetch cr next into data;
  result (data);
  if (data <> 2)
    signal ('.....', concat ('Invalid second row ', cast (data as varchar)));

  fetch cr last into data;
  result (data);
  if (data <> 10)
    signal ('.....', concat ('Invalid last row ', cast (data as varchar)));

  fetch cr previous into data;
  result (data);
  if (data <> 9)
    signal ('.....', concat ('Invalid next to last row ', cast (data as varchar)));

  delete from PLCR where ID = 1;

  whenever sqlstate 'HY109' goto Ok1;
  fetch cr first into data;
  result (data);
  signal ('.....', 'Deleted row found in keyset using fetch first');
Ok1:
  data := NULL;
  whenever sqlstate 'HY109' goto Ok2;
  fetch cr bookmark bm into data;
  result (data);
  signal ('.....', 'Deleted row found in keyset using fetch bookmark');

Ok2:
  close cr;
  return;

done:
  signal ('.....', 'Not found');
  close cr;
  return;

deleted:
  signal ('.....', 'Row deleted');
  close cr;
  return;
};
TEST_KEYSET_MODES();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Keyset fetch modes state=" $STATE " MESSAGE=" $MESSAGE "\n";

CREATE PROCEDURE KS1 ()
{
  DECLARE MASK ANY;
  DECLARE MASK1 ANY;
  DECLARE CUSTOMERID, COMPANYNAME ANY;
  MASK := 'db%';
  MASK1 := 'VA%';
  DECLARE CR KEYSET CURSOR FOR SELECT U_ID, U_NAME FROM SYS_USERS WHERE U_NAME LIKE MASK OR U_NAME LIKE MASK1;
  OPEN CR;
  FETCH CR FIRST INTO CUSTOMERID, COMPANYNAME;
  DBG_OBJ_PRINT (CUSTOMERID, COMPANYNAME);
  FETCH CR NEXT INTO CUSTOMERID, COMPANYNAME;
  DBG_OBJ_PRINT (CUSTOMERID, COMPANYNAME);
};

KS1 ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Keyset fetch with param only in where =" $STATE " MESSAGE=" $MESSAGE "\n";



-- testsuite for bug #3167
use BUG3167;
DROP TABLE TABLE1_2;
DROP TABLE TABLE1;
DROP TABLE TABLE2;

CREATE TABLE TABLE1 (
	ID        INTEGER NOT NULL,
	NAME      VARCHAR(255) NOT NULL,

	PRIMARY KEY (ID));

CREATE TABLE TABLE2 (
	ID        INTEGER NOT NULL,
	NAME      VARCHAR(255) NOT NULL,

	PRIMARY KEY (ID));

CREATE TABLE TABLE1_2 (
	ID        INTEGER NOT NULL,
	ID_1      INTEGER NOT NULL,
	ID_2      INTEGER NOT NULL,

	PRIMARY KEY (ID));

--ALTER TABLE TABLE1_2 ADD FOREIGN KEY(ID_1)  REFERENCES TABLE1(ID);
--ALTER TABLE TABLE1_2 ADD FOREIGN KEY(ID_2)  REFERENCES TABLE2(ID);

INSERT INTO TABLE1 (ID,NAME) VALUES(1,'Name 1 1');
INSERT INTO TABLE1 (ID,NAME) VALUES(2,'Name 1 2');
INSERT INTO TABLE1 (ID,NAME) VALUES(3,'Name 1 3');

INSERT INTO TABLE2 (ID,NAME) VALUES(1,'Name 2 1');
INSERT INTO TABLE2 (ID,NAME) VALUES(2,'Name 2 2');
INSERT INTO TABLE2 (ID,NAME) VALUES(3,'Name 2 3');

INSERT INTO TABLE1_2 (ID,ID_1,ID_2) VALUES(1,1,1);
INSERT INTO TABLE1_2 (ID,ID_1,ID_2) VALUES(2,2,1);
INSERT INTO TABLE1_2 (ID,ID_1,ID_2) VALUES(3,2,3);
INSERT INTO TABLE1_2 (ID,ID_1,ID_2) VALUES(4,3,3);

SELECT T_1.NAME N1,T_2.NAME N2
  FROM TABLE1_2 T_1_2
 INNER JOIN TABLE1 T_1
    ON T_1_2.ID_1 = T_1.ID
 INNER JOIN TABLE1 T_2
    ON T_1_2.ID_2 = T_2.ID;
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG3167 : select returned " $ROWCNT " rows\n";

drop procedure test1;
create procedure test1(){
  declare n1, n2 varchar;
  result_names (n1, n2);
  for(
      SELECT T_1.NAME N1,T_2.NAME N2
        FROM TABLE1_2 T_1_2
       INNER JOIN TABLE1 T_1
          ON T_1_2.ID_1 = T_1.ID
       INNER JOIN TABLE1 T_2
          ON T_1_2.ID_2 = T_2.ID
  )do{
    result(N1,N2);
  };
};

call test1();
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG3167 : fo cursor returned " $ROWCNT " rows\n";


drop procedure test2;
create procedure test2(){
  declare n1,n2 varchar;

  result_names (n1, n2);
  whenever not found goto done;
  declare cr static cursor for
      SELECT T_1.NAME N1,T_2.NAME N2
        FROM TABLE1_2 T_1_2
       INNER JOIN TABLE1 T_1
          ON T_1_2.ID_1 = T_1.ID
       INNER JOIN TABLE1 T_2
          ON T_1_2.ID_2 = T_2.ID;

  open cr;
  while (1) {
    fetch cr into n1, n2;
    result(n1,n2);
  }
  done: ;

};

call test2();
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG3167 : static cursor returned " $ROWCNT " rows\n";

use DB;



-- XXX: disabled till XML xtest2();
exit;
drop table XPERTEST;
create table XPERTEST (
  ID integer,
  FNAME varchar,
  XPER long varchar
);

insert into XPERTEST (ID, FNAME, XPER) values (1, 'aa', xml_persistent ('<?xml version="1.0"?><q>Hello<p></p></q>'));
insert into XPERTEST (ID, FNAME, XPER) values (2, 'aa', xml_persistent ('<?xml version="1.0"?><q>Hello<p></p></q>'));
insert into XPERTEST (ID, FNAME, XPER) values (3, 'aa', xml_persistent ('<?xml version="1.0"?><q>He<w n1="v1" n2="v2">l</w>lo</q>'));
insert into XPERTEST (ID, FNAME, XPER) values (4, 'aa', xml_persistent ('<?xml version="1.0"?><html><body><h1>Title of Document</h1><p>Some <b>bold</b> text</p><p></p></body></html>'));
insert into XPERTEST (ID, FNAME, XPER) values (5, 'aa', xml_persistent (concat ('<?xml version="1.0"?><q>Hello. This text will be more than 2K long ', repeat ('0123456789ABCDEF', 200), '<p></p></q>')));

create procedure xtest2 ( )
{
  declare cr keyset cursor for select blob_to_string_output(xper) from xpertest;
  declare inx integer;
  declare from_file varchar;
  declare data any;
  inx := 0;

  whenever not found goto done;
  open cr;
  while (1)
    {
      fetch cr into data;
      dbg_obj_print(data);
      inx := inx + 1;
    }
done:
  close cr;
  result_names (data);
  result (inx);
}

xtest2();
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Scrollable cursor with non-copiable values fetched " $LAST[1] " rows\n";


drop view B4635_PV;
drop procedure B4635_PVP;
drop table B4635;
drop procedure B4635_P;

create procedure B4635_PVP ()
{
  return 0;
};

create procedure view B4635_PV as B4635_PVP () (ID1 varchar, HP_LISTEN_HOST varchar);


create table B4635 (ID1 varchar);

insert into B4635 values ('1');
insert into B4635 values ('1');

create procedure B4635_P ()
{

      declare _ID1 any;
      declare cr dynamic cursor for
         select
             ID1
           from
             B4635_PV
         union all
         select
             ID1
           from
             B4635;

      open cr;
      fetch cr into _ID1;
      result_names (_ID1);
      result (_ID1);
};

B4635_P();
ECHO BOTH $IF $EQU $STATUS OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG4635: Scrollable cursor on union STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
--
-- End of test
--
ECHO BOTH "COMPLETED: PL Scrollable cursors suite (tplscroll.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
