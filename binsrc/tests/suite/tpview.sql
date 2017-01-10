--
--  $Id: tpview.sql,v 1.20.10.2 2013/01/02 16:15:18 source Exp $
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


drop procedure numbers;
create procedure numbers ()
{
  declare n, n2 integer;
  n := 0;
  result_names (n, n2);
  while (n < 10){
    result (n, 2 * n);
    n := n + 1;
  }
}

select n, n2 from numbers () (n int, n2 int) f;
ECHO BOTH $IF $EQU $ROWCNT 10 "PASSED" "***FAILED";
ECHO BOTH ": proc table no params " $rowcnt " rows\n";

select 3*n, n2, n3, __tag (n3)  from numbers () (n int, n2 int, n3 int) f;
ECHO BOTH $IF $EQU $ROWCNT 10 "PASSED" "***FAILED";
ECHO BOTH ": proc table no params with calculations " $rowcnt " rows\n";



drop procedure n_range;
create procedure n_range (in first integer, in  last integer)
{
  __cost (22.2, 10, 1e3, 1e2);
  /*dbg_obj_print ('first = ', first, 'last = ', last);*/
  declare n, n2 integer;
  n := first;
  result_names (n, n2);
  while (n < last){
    result (n, 2 * n);
    n := n + 1;
  }
}


select n, n2 from n_range (first, last) (n int, n2 int) n where first = 2 and last = 12;
ECHO BOTH $IF $EQU $ROWCNT 10 "PASSED" "***FAILED";
ECHO BOTH ": proc params " $rowcnt " rows\n";

select n, n2 from n_range (first, last) (n int, n2 int) n where first = 2 and last = 12 and last = 13;



select a.n, b.n from n_range (first, last) (n int, n2 int) a, n_range (f2, l2) (n int, n2 int) b where first = 2 and last = 12 and f2 = a.n - 2 and l2 = a.n + 2;
ECHO BOTH $IF $EQU $ROWCNT 40 "PASSED" "***FAILED";
ECHO BOTH ": proc derived table " $rowcnt " rows\n";





drop view n_range;
create procedure view n_range as n_range (first, last) (n1 int, n2 int);

select * from n_range where first = 1 and n_range.last = 11 ;
ECHO BOTH $IF $EQU $ROWCNT 10 "PASSED" "***FAILED";
ECHO BOTH ": proc view " $rowcnt " rows\n";

select * from n_range a, n_range b where a.first = 1 and a.last = 11  and b.last = a.n1 + 2 and b.first = a.n1 - 2;
ECHO BOTH $IF $EQU $ROWCNT 40 "PASSED" "***FAILED";
ECHO BOTH ": 2 proc views  " $rowcnt " rows\n";



update n_range set n1 = 1;



drop view BIGTABLE_V;
drop procedure BIGTABLE_P;

create procedure BIGTABLE_P(in PARAM_VALUE varchar)
{
  declare NAME varchar;
  declare VALUE long varchar;
  declare NVALUE long nvarchar;
  declare BVALUE long varbinary;
  result_names(NAME, VALUE, NVALUE, BVALUE);
  if (PARAM_VALUE is null or PARAM_VALUE = 1700)
    {
      result('1700',
	  repeat ('1234567890', 170),
	  repeat (N'1234567890', 170),
	  cast (repeat ('1234567890', 170) as varbinary));
    }
  if (PARAM_VALUE is null or PARAM_VALUE = 2000)
    {
      result('2000',
	  repeat ('1234567890', 200),
	  repeat (N'1234567890', 200),
	  cast (repeat ('1234567890', 200) as varbinary));
    }
};
-- Call stored procedure
call BIGTABLE_P(null);
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": 2 rows procedure call with BLOB result columns" $rowcnt " rows\n";

call BIGTABLE_P(1700);
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": first row procedure call with BLOB result columns" $rowcnt " rows\n";

call BIGTABLE_P(2000);
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": second row procedure call with BLOB result columns" $rowcnt " rows\n";

create procedure view BIGTABLE_V as BIGTABLE_P(PVALUE)(NAME varchar, VALUE long varchar, NVALUE long nvarchar, BVALUE long varbinary);

-- Perform query tests
select * from BIGTABLE_V;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": 2 rows procedure view select with BLOB result columns" $rowcnt " rows\n";

select NAME,
	length (VALUE), dv_type_title (__tag (VALUE)),
	length (NVALUE), dv_type_title (__tag (NVALUE)),
	length (BVALUE), dv_type_title (__tag (BVALUE))
  from BIGTABLE_V where PVALUE = 1700;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": first row procedure view select with BLOB result columns" $rowcnt " rows\n";

ECHO BOTH $IF $EQU $LAST[2] 1700 "PASSED" "***FAILED";
ECHO BOTH ": length of a LONG VARCHAR BLOB from a procedure view select = " $LAST[2] " chars\n";

ECHO BOTH $IF $EQU $LAST[3] VARCHAR "PASSED" "***FAILED";
ECHO BOTH ": type of a LONG VARCHAR BLOB from a procedure view select = " $LAST[3] "\n";



ECHO BOTH $IF $EQU $LAST[4] 1700 "PASSED" "***FAILED";
ECHO BOTH ": length of a LONG NVARCHAR BLOB from a procedure view select = " $LAST[4] " chars\n";

ECHO BOTH $IF $EQU $LAST[5] NVARCHAR "PASSED" "***FAILED";
ECHO BOTH ": type of a LONG NVARCHAR BLOB from a procedure view select = " $LAST[5] "\n";



ECHO BOTH $IF $EQU $LAST[7] VARCHAR "PASSED" "***FAILED";
ECHO BOTH ": type of a LONG VARBINARY BLOB from a procedure view select = " $LAST[7] "\n";

drop table TPJOIN;
drop table TPJOIN_VIEW;
drop procedure TPJOIN_PROC;
create table TPJOIN (ID integer not null primary key, DATA varchar);
insert into TPJOIN (ID, DATA) values (1, 'a');
insert into TPJOIN (ID, DATA) values (2, 'b');

create procedure TPJOIN_PROC (in P_ID integer)
{
  declare ID integer;
  declare DATA varchar;
  result_names (ID, DATA);
  if (P_ID = 1)
    result (1, 'a');
};

create procedure view TPJOIN_VIEW as TPJOIN_PROC (ID) (ID integer, DATA varchar);

select t.ID, t.DATA, p.ID, p.DATA from TPJOIN t join TPJOIN_VIEW p on (p.ID = t.ID);
-- XXX
--ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
--ECHO BOTH ": join between a table & procedure view returns " $ROWCNT " rows\n";

select t.ID, t.DATA, p.ID, p.DATA from TPJOIN t left outer join TPJOIN_VIEW p on (p.ID = t.ID);
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": left outer join between a table & procedure view returns " $ROWCNT " rows\n";


drop view TPVIEWCASEMODE_VIEW;
drop procedure TPVIEWCASEMODE;
drop table TPVIEWCASEMODE;

create table TPVIEWCASEMODE (ID int identity not null primary key, DATA integer not null);
insert into TPVIEWCASEMODE (DATA) values (1);
insert into TPVIEWCASEMODE (DATA) values (2);

create procedure TPVIEWCASEMODE (in DataId integer)
{
  declare DATA integer;
  declare CR cursor for select DATA from TPVIEWCASEMODE where ID = DataId or DataId is null;
  result_names (DATA);
  whenever not found goto done;
  open CR;
  while (1 = 1)
    {
      fetch CR into DATA;
      result (DATA);
    }
done:
  close CR;
};

create procedure view TPVIEWCASEMODE_VIEW as TPVIEWCASEMODE(DataId) (DATA integer);

select * from TPVIEWCASEMODE_VIEW where DataId = NULL;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": procedure view TPVIEWCASEMODE_VIEW with a null returned " $ROWCNT " rows\n";

select * from TPVIEWCASEMODE_VIEW where DataId = 1;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": procedure view TPVIEWCASEMODE_VIEW with a number returned " $ROWCNT " rows\n";

select * from TPVIEWCASEMODE_VIEW where dataid = 1;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": procedure view TPVIEWCASEMODE_VIEW with a incorrect case param name returned " $ROWCNT " rows\n";


drop table SORTTABLE;
create table SORTTABLE (ID integer not null primary key, SEC integer, SDATA varchar, BDATA long varchar);

insert into SORTTABLE (ID, SEC, SDATA, BDATA) values (1, 1, repeat ('s', 1900), repeat ('b', 1900));
insert into SORTTABLE (ID, SEC, SDATA, BDATA) values (2, 2, repeat ('s', 1900), repeat ('b', 19000));

drop procedure SOTEST;
create procedure SOTEST (in w integer)
{
  for select ID, SDATA as s1, blob_to_string (BDATA) as s2, BDATA from SORTTABLE where ID = w order by SEC do
    {
      declare res varchar;
      res := blob_to_string (BDATA);
      /*dbg_obj_print (ID, s1, s2, res);*/
    }
};

SOTEST (1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Sorted order by in a DV_ROW_EXTENSION with inline BLOB STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
SOTEST (2);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Sorted order by in a DV_ROW_EXTENSION with real BLOB STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- test suite for bug #1532

DROP PROCEDURE B1532testSP;
CREATE PROCEDURE B1532testSP(IN qs1 VARCHAR, IN qs2 VARCHAR)
{
  result_names('one', 'two', 'three', 'four');
  result( qs1, 'random text 1', qs2, 'random text 2' );
};


DROP VIEW B1532testSPV;

CREATE PROCEDURE VIEW B1532testSPV AS B1532testSP(qs1, qs2)
    (rs1 VARCHAR, rs2 VARCHAR, rs3 VARCHAR, rs4 VARCHAR);

select * from B1532testSPV where qs1='dfgdf' and qs2='zdfgdf';

DROP VIEW B1532testV;
CREATE VIEW B1532testV (a, b, c, d) AS
	SELECT rs1, rs2, rs3, rs4
	FROM B1532testSPV
	WHERE qs1='fzsjnzv' AND qs2='dfhdfh';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG 1532 : View over a procedure view STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


-- test suite for bug 1499 reopened

DROP PROCEDURE B1499_2_P;
CREATE PROCEDURE B1499_2_P(IN qs1 VARCHAR)
{
  result_names('one', 'two');
  result( qs1, 'random text 1');
};

drop view B1499_2_V;
CREATE PROCEDURE VIEW B1499_2_V AS B1499_2_P (qs1)
    (rs1 VARCHAR, rs2 VARCHAR);

select isstring (12) from B1499_2_V where isstring (12) = 1;

-- test suite for bug 3036
drop table B3036.dba.Atable;
create table B3036.dba.Atable (au_id CHARACTER(12), au_lname VARCHAR(40), au_fname VARCHAR(20));

drop table B3036.dba.TAtable;
create table B3036.dba.TAtable (au_id CHARACTER(12), title_id CHARACTER(6));

drop table B3036.dba.Ttable;
create table B3036.dba.Ttable (title_id CHARACTER(6), title VARCHAR(80));

drop procedure B3036.dba.Atable_sp;
create procedure B3036.dba.Atable_sp ()
{
  declare cmd, error, state varchar;
  declare cursor_handle, meta, retcode, row any;
  declare au_id varchar;
  declare au_lname varchar;
  declare au_fname varchar;

  cmd := 'select * from B3036.dba.Atable';

  -- execute the procedure
  state   := '00000';
  retcode := exec(cmd, state, error, NULL, 1000, meta, NULL, cursor_handle);
  if (retcode = 0 and state = '00000')
  {
    if (isinteger(cursor_handle) = 0)
    {
      -- Process results
      result_names(au_id,au_lname,au_fname);
      while(exec_next(cursor_handle, state, error, row) = 0)
      {
          if (length(row) >= 3)
          {
              -- Extract result columns from row
              au_id := aref(row, 0);
              au_lname := aref(row, 1);
              au_fname := aref(row, 2);
               -- Store result row
              result(au_id,au_lname,au_fname);
          }
      }
      retcode := exec_close(cursor_handle);
    }
  }
  else
  {
      -- process error
      dbg_printf('Error: %d State: %s', retcode, state);
      signal(state, error);
  }

}

drop procedure B3036.DBA.TAtable_sp;
create procedure B3036.DBA.TAtable_sp ()
{
  declare cmd, error, state varchar;
  declare cursor_handle, meta, retcode, row any;
  declare au_id varchar;
  declare title_id varchar;

  cmd := 'select * from B3036.dba.TAtable';

  -- execute the procedure
  state   := '00000';
  retcode := exec(cmd, state, error, NULL, 1000, meta, NULL, cursor_handle);
  if (retcode = 0 and state = '00000')
  {
    if (isinteger(cursor_handle) = 0)
    {
      -- Process results
      result_names(au_id,title_id);
      while(exec_next(cursor_handle, state, error, row) = 0)
      {
          if (length(row) >= 2)
          {
              -- Extract result columns from row
              au_id := aref(row, 0);
              title_id := aref(row, 1);
                -- Store result row
              result(au_id,title_id);
          }
      }
      retcode := exec_close(cursor_handle);
    }
  }
  else
  {
      -- process error
      dbg_printf('Error: %d State: %s', retcode, state);
      signal(state, error);
  }

}


drop procedure B3036.dba.Ttable_sp;
create procedure B3036.dba.Ttable_sp ()
{
  declare cmd, error, state varchar;
  declare cursor_handle, meta, retcode, row any;
  -- Result Columns
  declare title_id varchar;
  declare title varchar;

  cmd := 'select * from B3036.dba.Ttable';

  -- execute the procedure
  state   := '00000';
  retcode := exec(cmd, state, error, NULL, 1000, meta, NULL, cursor_handle);
  if (retcode = 0 and state = '00000')
  {
    if (isinteger(cursor_handle) = 0)
    {
      -- Process results
      result_names(title_id,title);
      while(exec_next(cursor_handle, state, error, row) = 0)
      {
          if (length(row) >= 2)
          {
              -- Extract result columns from row
              title_id := aref(row, 0);
              title := aref(row, 1);
                -- Store result row
              result(title_id,title);
          }
      }
      retcode := exec_close(cursor_handle);
    }
  }
  else
  {
      -- process error
      dbg_printf('Error: %d State: %s', retcode, state);
      signal(state, error);
  }

}

drop table B3036.dba.Atable_spview;
create procedure view B3036.dba.Atable_spview
    as B3036.DBA.Atable_sp () (au_id VARCHAR, au_lname VARCHAR, au_fname VARCHAR);

drop table B3036.dba.TAtable_spview;
create procedure view B3036.dba.TAtable_spview
    as B3036.DBA.TAtable_sp () (au_id VARCHAR, title_id VARCHAR);

drop table B3036.dba.Ttable_spview;
create procedure view B3036.dba.Ttable_spview
    as B3036.DBA.Ttable_sp () (title_id VARCHAR, title VARCHAR);

SELECT A.au_lname, A.au_fname, T.au_id, T1.title_id, T1.title
FROM B3036.DBA.Atable A INNER JOIN B3036.DBA.TAtable T ON ( A.au_id = T.au_id ) INNER JOIN B3036.DBA.Ttable T1  ON ( T.title_id = T1.title_id );
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG 3036-1 : 3 inner join on proc views STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

SELECT A.au_lname, A.au_fname, T.au_id, T1.title_id, T1.title
FROM B3036.DBA.Atable_spview A
     INNER JOIN B3036.DBA.TAtable_spview T ON ( A.au_id = T.au_id )
     INNER JOIN B3036.DBA.Ttable_spview T1 ON ( T.title_id = T1.title_id );
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG 3036-2 : 3 inner join on proc views STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- test suite for bug #2905
select
 gt.TYPE_NAME
from
 DB.DBA.oledb_get_types(t, m) (
  TYPE_NAME NVARCHAR(32),
  DATA_TYPE SMALLINT,
  COLUMN_SIZE INTEGER,
  LITERAL_PREFIX NVARCHAR(5),
  LITERAL_SUFFIX NVARCHAR(5),
  CREATE_PARAMS NVARCHAR(64),
  IS_NULLABLE SMALLINT,
  CASE_SENSITIVE SMALLINT,
  SEARCHABLE INTEGER,
  UNSIGNED_ATTRIBUTE SMALLINT,
  FIXED_PREC_SCALE SMALLINT,
  AUTO_UNIQUE_VALUE SMALLINT,
  LOCAL_TYPE_NAME NVARCHAR(32),
  MINIMUM_SCALE SMALLINT,
  MAXIMUM_SCALE SMALLINT,
  GUID NVARCHAR,
  TYPELIB NVARCHAR,
  VERSION NVARCHAR(32),
  IS_LONG SMALLINT,
  BEST_MATCH SMALLINT,
  IS_FIXEDLENGTH SMALLINT
 ) gt
 where
 t = null and m = null;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG 2905 : procedure view with different result types STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


-- bug 4000
create procedure B4000P (in first integer, in last integer)
{
  declare n, n2 integer;
  n := first;
  result_names (n, n2);
  while (n < last){
   result (n, 2 * n);
   n := n + 1;
  }
  end_result();
};
select n, n2 from B4000P (first, last) (n int, n2 int) n where first = 2 and last = 12;
ECHO BOTH $IF $EQU $ROWCNT 10 "PASSED" "***FAILED";
ECHO BOTH ": BUG4000: proc table w/ end_result returned " $rowcnt " rows\n";


drop view B1499_HASH_V2;
drop view B1499_HASH_V1;

create procedure B1499_HASH_P1() {};

create procedure view B1499_HASH_V1 as B1499_HASH_P1 () (C1 varchar, C2 varchar);

create view B1499_HASH_V2 as
  select C2, P_NAME
  from
    SYS_PROCEDURES INNER JOIN B1499_HASH_V1
       on (B1499_HASH_V1.C1 = p_NAME);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG 1499-hash : procedure view in a view STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop view B8787_PV;
drop procedure B8787;

create procedure B8787 (in FIRST integer, in  LAST integer)
{
  declare N1, N2 integer;
  N1 := FIRST;
  result_names (N1, N2);
  while (N1 < LAST)
    {
      result (N1, 2 * N1);
      N1 := N1 + 1;
    }
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG8787-1: proc created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure view B8787_PV as
        B8787(FIRST, LAST) (N1 int, N2 int);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG8787-2: proc view created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from B8787_PV where FIRST = 1 and LAST = 3;
ECHO BOTH $IF $EQU $COLCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": BUG8787-3: " $COLCNT " cols in 'select *' from proc view\n";

select N1, N2, FIRST, LAST from B8787_PV where FIRST = 1 and LAST = 3;
ECHO BOTH $IF $EQU $LAST[3] 1 "PASSED" "***FAILED";
ECHO BOTH ": BUG8787-4: value for 1st param is " $LAST[3] " in select from proc view\n";
ECHO BOTH $IF $EQU $LAST[4] 3 "PASSED" "***FAILED";
ECHO BOTH ": BUG8787-5: value for 2nd param is " $LAST[4] " in select from proc view\n";

select * from B8787(FIRST, LAST) (N1 int, N2 int) x where FIRST = 1 and LAST = 3;
ECHO BOTH $IF $EQU $COLCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": BUG8787-6: " $COLCNT " cols in 'select *' from proc tb\n";

select N1, N2, FIRST, LAST from B8787(FIRST, LAST) (N1 int, N2 int) x where FIRST = 1 and LAST = 3;
ECHO BOTH $IF $EQU $LAST[3] 1 "PASSED" "***FAILED";
ECHO BOTH ": BUG8787-7: value for 1st param is " $LAST[3] " in select from proc tb\n";
ECHO BOTH $IF $EQU $LAST[4] 3 "PASSED" "***FAILED";
ECHO BOTH ": BUG8787-8: value for 2nd param is " $LAST[4] " in select from proc tb\n";
