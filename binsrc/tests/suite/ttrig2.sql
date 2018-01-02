--
--  ttrig2.sql
--
--  $Id: ttrig2.sql,v 1.11.10.2 2013/01/02 16:15:30 source Exp $
--
--  Test INSTEAD OF & view triggers.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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

ECHO BOTH "STARTED: TRIGGERS TEST 2\n";


drop table tt;
drop table tv;

create  table tt (i int);
create view tv as select 'constant' as f, i from tt;
create trigger td instead of delete  on tv
{ dbg_obj_print ('del trig'); return; }


create trigger tu instead of update   on tv
{ dbg_obj_print ('upd trig'); return; }

create trigger ti instead of insert    on tv
{ dbg_obj_print ('ins  trig'); insert into tt values (i); }


insert into tv values ('a', 2);

insert into tv (i) values (1);
insert into tv (i) values (2);

update tv set f = 'q';

update tv set i = 4;
delete from tv;


create procedure tv_upd ()
{
  declare ff, ii any;
  Declare cr cursor for select * from tv;
  open cr;
  fetch cr into ff, ii;
  update tv set f = '1', i = 4 where current of cr;
  delete from tv where current of cr;
}

tv_upd ();

select * from tt;
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both " test with constant col in view with instead of triggers.\n";



drop table IT1;
drop table IT2;

create table IT1 (C1 int, C2 varchar);
create table IT2 (C1 int, C2 varchar);

insert into IT1 values (1, '1');
insert into IT2 values (1, '1');

create trigger TG_1 instead of insert on IT1
{
   dbg_printf ('In instead insert trigger');
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": INSTEAD OF insert trigger defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create trigger TG_2 instead of update on IT1
{
   dbg_printf ('In instead update trigger');
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": INSTEAD OF update trigger defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create trigger TG_3 instead of delete on IT1
{
   dbg_printf ('In instead delete trigger');
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": INSTEAD OF delete trigger defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into IT1 values (2, '2');
select count(*) from IT1;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": INSTEAD OF insert trigger worked\n";

update IT1 set C2 = '3' where C1 = 1;
select C2 from IT1 where C1 = 1;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": INSTEAD OF update trigger worked\n";

delete from IT1 where C1 = 1;
select count(*) from IT1;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": INSTEAD OF delete trigger worked\n";

drop trigger TG_3;
create trigger TG_3 instead of delete on IT1
{
   signal ('....', 'instead of deleted called');
};
drop table IT1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": INSTEAD OF delete trigger not called on table drop STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop view ITV1;
create view ITV1 as select * from IT2;
create trigger TG_4BI before insert on ITV1
{
  dbg_printf ('In before insert view trigger');
};
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": ins trigger defined on a view STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create trigger TG_4 instead of insert on ITV1
{
  dbg_printf ('In instead insert view trigger');
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": instead ins trigger defined on a view STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create trigger TG_4BI before insert on ITV1
{
  dbg_printf ('In before insert view trigger');
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": ins trigger defined on a view STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create trigger TG_4BU before update on ITV1
{
  dbg_printf ('In before update view trigger');
};
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": upd trigger defined on a view STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

USE TTR;

DROP TABLE TT1;

DROP TABLE TT2;


CREATE TABLE TT1 (ID1 INT PRIMARY KEY, DT1 VARCHAR);

CREATE TABLE TT2 (ID2 INT PRIMARY KEY, DT2 VARCHAR);

INSERT INTO TT2 (ID2, DT2) VALUES (1, '1');


CREATE PROCEDURE TT1_P ()
{
  FOR SELECT * FROM TT1 DO
    {
      dbg_obj_print ('TT1_P 1: ', ID1, DT1);
    }
}
;

CREATE PROCEDURE TT2_P ()
{
  FOR SELECT * FROM TT2 DO
    {
      dbg_obj_print ('TT2_P 1: ', ID2, DT2);
    }
}
;

CREATE TRIGGER T_TT1 AFTER INSERT ON TT1
{
  DECLARE I, D ANY;
  SELECT DT2 INTO D FROM TT2 WHERE ID2 = 1;
  CALL ('TT1_P') ();
  CALL ('TT2_P') ();
}
;

INSERT INTO TT1 (ID1, DT1) VALUES (1, '1');

ALTER TABLE TT1 ADD DT11 VARCHAR;

CREATE PROCEDURE TT1_P ()
{
  FOR SELECT * FROM TT1 DO
    {
      dbg_obj_print ('TT1_P 2: ', ID1, DT1, DT11);
    }
}
;


INSERT INTO TT1 (ID1, DT1) VALUES (2, '1');

ALTER TABLE TT2 ADD DT22 VARCHAR;

CREATE PROCEDURE TT2_P ()
{
  FOR SELECT * FROM TT2 DO
    {
      dbg_obj_print ('TT2_P 2: ', ID2, DT2, DT22);
    }
}
;

INSERT INTO TT1 (ID1, DT1) VALUES (3, '1');

-- test for GPF
CREATE TABLE TR1 (ID INT PRIMARY KEY);

CREATE TABLE TR2 (ID INT PRIMARY KEY);

CREATE TRIGGER ONE_TRIGGER AFTER INSERT ON TR1
{
  dbg_obj_print (ID);
}
;

CREATE TRIGGER ONE_TRIGGER AFTER INSERT ON TR2
{
  dbg_obj_print (ID);
}
;

delay (3);

DROP TABLE TR1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": table with trigger drop STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
-- there crash must not be seen

USE DB;

drop table B4489;
create table B4489 (ID int primary key, DATA int NOT NULL);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG4489-1: table created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into B4489 (ID) values (1);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG4489-2: non-null col w/ no value STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create trigger B4489_XXT before insert on B4489 order 99 { declare i int; i := 0; };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG4489-3: before insert trigger created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into B4489 (ID) values (1);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG4489-4: non-null col w/ no value on trig table STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B4489;
create table B4489 (ID int primary key, DATA int NOT NULL DEFAULT 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG4489-5: table created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into B4489 (ID) values (1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG4489-6: non-null col w/ no value STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create trigger B4489_XXT before insert on B4489 order 99 { declare i int; i := 0; };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG4489-7: before insert trigger created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into B4489 (ID) values (2);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG4489-8: non-null col w/ no value on trig table STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


drop table B3746_T;
drop table B3746_ST;
drop table T_LOG;

create table B3746_T (TID int primary key, TDATA int);
create table B3746_ST (STDATA int, under B3746_T);
create TABLE T_LOG (O_TID int, O_TDATA int, O_STDATA int, N_TID int, N_TDATA int, N_STDATA int, TRIG_NAME varchar, TS int);

create trigger BI_B3746_T before insert on B3746_T
{
  delay (1);
  insert into T_LOG (O_TID,O_TDATA,O_STDATA,N_TID,N_TDATA,N_STDATA,TRIG_NAME, TS)
    values (NULL, NULL, NULL, TID, TDATA, NULL, 'BI_B3746_T', msec_time());
  --dbg_obj_print (sprintf ('BI_B3746_T : %d, %d', TID, TDATA));
};
create trigger BI_B3746_ST before insert on B3746_ST
{
  delay (1);
  insert into T_LOG (O_TID,O_TDATA,O_STDATA,N_TID,N_TDATA,N_STDATA,TRIG_NAME, TS)
     values (NULL, NULL, NULL, TID, TDATA, STDATA, 'BI_B3746_ST', msec_time());
  --dbg_obj_print (sprintf ('BI_B3746_ST : %d, %d, %d', TID, TDATA, STDATA));
};
create trigger AI_B3746_T after insert on B3746_T
{
  delay (1);
  insert into T_LOG (O_TID,O_TDATA,O_STDATA,N_TID,N_TDATA,N_STDATA,TRIG_NAME, TS)
     values (NULL, NULL, NULL, TID, TDATA, NULL, 'AI_B3746_T', msec_time());
  --dbg_obj_print (sprintf ('AI_B3746_T : %d, %d', TID, TDATA));
};
create trigger AI_B3746_ST after insert on B3746_ST
{
  delay (1);
  insert into T_LOG (O_TID,O_TDATA,O_STDATA,N_TID,N_TDATA,N_STDATA,TRIG_NAME, TS)
     values (NULL, NULL, NULL, TID, TDATA, STDATA, 'AI_B3746_ST', msec_time());
  --dbg_obj_print (sprintf ('AI_B3746_ST : %d, %d, %d', TID, TDATA, STDATA));
};

create trigger BD_B3746_T before delete on B3746_T
{
  delay (1);
  insert into T_LOG (O_TID,O_TDATA,O_STDATA,N_TID,N_TDATA,N_STDATA,TRIG_NAME, TS)
    values (TID, TDATA, NULL, NULL, NULL, NULL, 'BD_B3746_T', msec_time());
  --dbg_obj_print (sprintf ('BD_B3746_T : %d, %d', TID, TDATA));
};
create trigger BD_B3746_ST before delete on B3746_ST
{
  delay (1);
  insert into T_LOG (O_TID,O_TDATA,O_STDATA,N_TID,N_TDATA,N_STDATA,TRIG_NAME, TS)
     values (TID, TDATA, STDATA, NULL, NULL, NULL, 'BD_B3746_ST', msec_time());
  --dbg_obj_print (sprintf ('BD_B3746_ST : %d, %d, %d', TID, TDATA, STDATA));
};
create trigger AD_B3746_T after delete on B3746_T
{
  delay (1);
  insert into T_LOG (O_TID,O_TDATA,O_STDATA,N_TID,N_TDATA,N_STDATA,TRIG_NAME, TS)
    values (TID, TDATA, NULL, NULL, NULL, NULL, 'AD_B3746_T', msec_time());
  --dbg_obj_print (sprintf ('AD_B3746_T : %d, %d', TID, TDATA));
};
create trigger AD_B3746_ST after delete on B3746_ST
{
  delay (1);
  insert into T_LOG (O_TID,O_TDATA,O_STDATA,N_TID,N_TDATA,N_STDATA,TRIG_NAME, TS)
     values (TID, TDATA, STDATA, NULL, NULL, NULL, 'AD_B3746_ST', msec_time());
  --dbg_obj_print (sprintf ('AD_B3746_ST : %d, %d, %d', TID, TDATA, STDATA));
};

create trigger BU_B3746_T before update on B3746_T referencing new as N, old as O
{
  delay (1);
  insert into T_LOG (O_TID,O_TDATA,O_STDATA,N_TID,N_TDATA,N_STDATA,TRIG_NAME, TS)
    values (O.TID, O.TDATA, NULL, N.TID, N.TDATA, NULL, 'BU_B3746_T', msec_time());
  --dbg_obj_print (sprintf ('BU_B3746_T O:%d, %d N:%d, %d', O.TID, O.TDATA, N.TID, N.TDATA));
};
create trigger BU_B3746_ST before update on B3746_ST referencing new as N, old as O
{
  delay (1);
  insert into T_LOG (O_TID,O_TDATA,O_STDATA,N_TID,N_TDATA,N_STDATA,TRIG_NAME, TS)
    values (O.TID, O.TDATA, O.STDATA, N.TID, N.TDATA, N.STDATA, 'BU_B3746_ST', msec_time());
  --dbg_obj_print (sprintf ('BU_B3746_ST O:%d, %d, %d N:%d, %d, %d', O.TID, O.TDATA, O.STDATA, N.TID, N.TDATA, N.STDATA));
};
create trigger AU_B3746_T after update on B3746_T referencing new as N, old as O
{
  delay (1);
  insert into T_LOG (O_TID,O_TDATA,O_STDATA,N_TID,N_TDATA,N_STDATA,TRIG_NAME, TS)
    values (O.TID, O.TDATA, NULL, N.TID, N.TDATA, NULL, 'AU_B3746_T', msec_time());
  --dbg_obj_print (sprintf ('AU_B3746_T O:%d, %d N:%d, %d', O.TID, O.TDATA, N.TID, N.TDATA));
};
create trigger AU_B3746_ST after update on B3746_ST referencing new as N, old as O
{
  delay (1);
  insert into T_LOG (O_TID,O_TDATA,O_STDATA,N_TID,N_TDATA,N_STDATA,TRIG_NAME, TS)
    values (O.TID, O.TDATA, O.STDATA, N.TID, N.TDATA, N.STDATA, 'AU_B3746_ST', msec_time());
  --dbg_obj_print (sprintf ('AU_B3746_ST O:%d, %d, %d N:%d, %d, %d', O.TID, O.TDATA, O.STDATA, N.TID, N.TDATA, N.STDATA));
};

create trigger BU_B3746_T_TDATA before update (TDATA) on B3746_T referencing new as N, old as O
{
  delay (1);
  insert into T_LOG (O_TID,O_TDATA,O_STDATA,N_TID,N_TDATA,N_STDATA,TRIG_NAME, TS)
    values (O.TID, O.TDATA, NULL, N.TID, N.TDATA, NULL, 'BU_B3746_T_TDATA', msec_time());
  --dbg_obj_print (sprintf ('BU_B3746_T_TDATA O:%d, %d N:%d, %d', O.TID, O.TDATA, N.TID, N.TDATA));
};
create trigger BU_B3746_ST_STDATA before update (STDATA) on B3746_ST referencing new as N, old as O
{
  delay (1);
  insert into T_LOG (O_TID,O_TDATA,O_STDATA,N_TID,N_TDATA,N_STDATA,TRIG_NAME, TS)
    values (O.TID, O.TDATA, O.STDATA, N.TID, N.TDATA, N.STDATA, 'BU_B3746_ST_STDATA', msec_time());
  --dbg_obj_print (sprintf ('BU_B3746_ST_STDATA O:%d, %d, %d N:%d, %d, %d', O.TID, O.TDATA, O.STDATA, N.TID, N.TDATA, N.STDATA));
};

delete from T_LOG;
insert into B3746_ST (TID, TDATA, STDATA) values (1, 2, 3);
select * from T_LOG;

-- XXX: bellow are diosabled dur to obsolete UNDER feature
select count (*) from T_LOG;
--ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": " $LAST[1] " triggers fired on insert\n";

select count (*) from T_LOG where TRIG_NAME = 'BI_B3746_T' and TS < (select b.TS from T_LOG b where b.TRIG_NAME = 'BI_B3746_ST');
--ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": super's before insert trigger fired before the sub's before insert\n";

select count (*) from T_LOG where TRIG_NAME = 'AI_B3746_T' and TS < (select b.TS from T_LOG b where b.TRIG_NAME = 'AI_B3746_ST');
--ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": super's after insert trigger fired before the sub's after insert\n";

select count (*) from T_LOG where
(N_TID <> 1) or
(N_TDATA <> 2) or
(TRIG_NAME like '%_B3746_ST' and N_STDATA <> 3);
--ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": " $LAST[1] " triggers got bad data on insert\n";

delete from T_LOG;
update B3746_ST set STDATA = 4;
select * from T_LOG;

select count (*) from T_LOG;
--ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": " $LAST[1] " triggers fired on update\n";

select count (*) from T_LOG where TRIG_NAME = 'BU_B3746_T' and TS < (select b.TS from T_LOG b where b.TRIG_NAME = 'BU_B3746_ST');
--ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": super's before update fired before the sub's before update\n";

select count (*) from T_LOG where TRIG_NAME = 'AU_B3746_T' and TS < (select b.TS from T_LOG b where b.TRIG_NAME = 'AU_B3746_ST');
--ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": super's after update fired before the sub's after update\n";

select count (*) from T_LOG where TRIG_NAME = 'BU_B3746_ST_STDATA';
--ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": sub's trigger on the update col fired\n";

select count (*) from T_LOG where
(O_TID <> 1) or
(O_TDATA <> 2) or
(TRIG_NAME like '%_B3746_ST%' and O_STDATA <> 3) or
(N_TID <> 1) or
(N_TDATA <> 2) or
(TRIG_NAME like '%_B3746_ST%' and N_STDATA <> 4)
;
--ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": " $LAST[1] " triggers got bad data on update\n";


delete from T_LOG;
update B3746_ST set TDATA = 5;
select * from T_LOG;

select count (*) from T_LOG;
--ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": " $LAST[1] " triggers fired on update of super's col\n";

select count (*) from T_LOG where TRIG_NAME = 'BU_B3746_T' and TS < (select b.TS from T_LOG b where b.TRIG_NAME = 'BU_B3746_ST');
--ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": super's before update fired before the sub's before update\n";

select count (*) from T_LOG where TRIG_NAME = 'AU_B3746_T' and TS < (select b.TS from T_LOG b where b.TRIG_NAME = 'AU_B3746_ST');
--ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": super's after update fired before the sub's after update\n";

select count (*) from T_LOG where TRIG_NAME = 'BU_B3746_T_TDATA';
--ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": super's trigger on the update col fired\n";

select count (*) from T_LOG where
(O_TID <> 1) or
(O_TDATA <> 2) or
(TRIG_NAME like '%_B3746_ST%' and O_STDATA <> 4) or
(N_TID <> 1) or
(N_TDATA <> 5) or
(TRIG_NAME like '%_B3746_ST%' and N_STDATA <> 4)
;
--ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": " $LAST[1] " triggers got bad data on update on super's col\n";


delete from T_LOG;
delete from B3746_ST;
select * from T_LOG;

select count (*) from T_LOG;
--ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": " $LAST[1] " triggers fired on delete\n";

select count (*) from T_LOG where TRIG_NAME = 'BD_B3746_T' and TS < (select b.TS from T_LOG b where b.TRIG_NAME = 'BD_B3746_ST');
--ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": super's before delete trigger fired before the sub's before delete\n";

select count (*) from T_LOG where TRIG_NAME = 'AD_B3746_T' and TS < (select b.TS from T_LOG b where b.TRIG_NAME = 'AD_B3746_ST');
--ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": super's after delete trigger fired before the sub's after delete\n";

select count (*) from T_LOG where
(O_TID <> 1) or
(O_TDATA <> 5) or
(TRIG_NAME like '%_B3746_ST' and O_STDATA <> 4);
--ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": " $LAST[1] " triggers got bad data on delete\n";

drop table EXTRIG;
create table EXTRIG (id int);
create trigger EXTRIGBI before insert on EXTRIG { signal ('42000', 'Insert not allowed'); };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": set triggers off & exec trigger created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure EXTRIG_I (in x integer) { set triggers off; insert into EXTRIG values (x); set triggers on; };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": set triggers off & exec proc1 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure EXTRIG_EI (in x integer) { set triggers off; exec ('insert into EXTRIG values (?)', null, null, vector (x)); set triggers on; };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": set triggers off & exec proc2 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

EXTRIG_I(1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": set triggers off & exec proc1 works w/ normal insert STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

EXTRIG_EI(2);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": set triggers off & exec proc2 works w/ exec insert STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "COMPLETED: TRIGGERS TEST 2\n";
