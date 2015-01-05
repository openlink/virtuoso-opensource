--
--  tplinverse.sql
--
--  $Id$
--
--  PL inverse functions suite
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

--
--  Start the test
--
echo BOTH "\nSTARTED: PL inverse suite (tinverse.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

set ERRORS=stdout;

drop table TINVS;
create table TINVS (TI1 integer, TI2 integer, TI3 integer, TI integer, primary key (TI1, TI2, TI3));
create unique index TINVS_TI on TINVS (TI);

drop table TINVS2;
create table TINVS2 (TI1 integer, TI2 integer, TI3 integer, TI integer, primary key (TI1, TI2, TI3));
create unique index TINVS2_TI on TINVS2 (TI);

insert into TINVS values (1, 1, 1, 111);
insert into TINVS2 values (1, 1, 1, 111);

drop table TINV_UPD;
create table TINV_UPD (TI1 integer, TI2 integer, TI3 integer, TI integer, primary key (TI1, TI2, TI3));
drop view VTINV_UPD;
create view VTINV_UPD as select _PSINGLE (TI) as TIC, TI1, TI2, TI3 from TINV_UPD;

create function _PSINGLE (in X integer) returns integer
{
  signal ('42T01', '_PSINGLE');
  return cast ((-1 * x) as integer);
};

create function _PSINGLE_PRIME (in X integer) returns integer
{
  return cast ((-1 * x) as integer);
};

sinv_drop_inverse ('_PSINGLE');
sinv_drop_inverse ('_PSINGLE_PRIME');
sinv_create_inverse ('_PSINGLE', '_PSINGLE_PRIME', 1);

create function _NPSINGLE (in X integer) returns integer
{
  signal ('42T02', '_NPSINGLE');
  return cast ((-1 * x) as integer);
};

create function _NPSINGLE_PRIME (in X integer) returns integer
{
  return cast ((-1 * x) as integer);
};

sinv_drop_inverse ('_NPSINGLE');
sinv_drop_inverse ('_NPSINGLE_PRIME');
sinv_create_inverse ('_NPSINGLE', '_NPSINGLE_PRIME', 0);

select 1 from TINVS where _PSINGLE (TI) = -1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": f(C1) = x -> C1 = f'(x) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 1 from TINVS where _PSINGLE (TI) = TI1;
ECHO BOTH $IF $EQU $STATE 42T01 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no f(C1) = C2 -> C1 = f'(C2) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 1 from TINVS where exists (select 1 from TINVS2 where _PSINGLE (TINVS.TI) = TINVS2.TI);
ECHO BOTH $IF $EQU $STATE 42T01 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no f(OUT_SCOPE_C) = C -> OUT_SCOPE_C = f'(C) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 1 from TINVS where exists (select 1 from TINVS2 where TINVS.TI = _PSINGLE (TINVS2.TI));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": f(C) = OUT_SCOPE_C -> C = f'(OUT_SCOPE_C) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 1 from TINVS where _PSINGLE (TI) < -1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": f(C1) < x -> C1 < f'(x) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 1 from TINVS where _NPSINGLE (TI) < -1;
ECHO BOTH $IF $EQU $STATE 42T02 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no nf(C1) < x -> C1 < nf'(x) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 1 from TINVS where _NPSINGLE (TI) = -1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": nf(C1) = x -> C1 = nf'(x) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from TINV_UPD;
insert into VTINV_UPD (TIC, TI1, TI2, TI3) values (-112, 1,1,1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": insert into ... (nf(C1)) values (x) -> insert into ... (C1) values (nf'(x)) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from TINV_UPD;
insert into TINV_UPD values (1, 1, 1, 111);

update VTINV_UPD set TIC = -112;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": update ... set nf(C1) = x -> update ... set C1 = nf'(x) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update VTINV_UPD set TIC = TI1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": update ... set nf(C1) = C2 -> update ... set C1 = nf'(C2) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create function _PSINGLE_PRIME (in X integer) returns integer
{
  signal ('42T03', '_PSINGLE_PRIME');
  return cast ((-1 * x) as integer);
};

create function _NPSINGLE_PRIME (in X integer) returns integer
{
  signal ('42T04', '_NPSINGLE_PRIME');
  return cast ((-1 * x) as integer);
};

select 1 from TINVS where _PSINGLE (TI) = _PSINGLE (TI1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": f(C1) = f(C2) -> C1 = C2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 1 from TINVS where _NPSINGLE (TI) = _NPSINGLE (TI1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": nf(C1) = nf(C2) -> C1 = C2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 1 from TINVS where _PSINGLE (TI) < _PSINGLE (TI1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": f(C1) < f(C2) -> C1 < C2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 1 from TINVS where _NPSINGLE (TI) < _NPSINGLE (TI1);
ECHO BOTH $IF $EQU $STATE 42T02 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": nf(C1) < nf(C2) -> C1 < C2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create function _MULTIPLE (in _I1 integer, in _I2 integer, in _I3 integer) returns integer
{
  signal ('42T05', '_MULTIPLE');
  return (_I1 * 100 + _I2 * 10 + _I3);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mf() created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create function _MPRIME_P1 (in _TI integer) returns integer
{
  return (_TI - mod (_TI, 100)) / 100;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mf1'() created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create function _MPRIME_P2 (in _TI integer) returns integer
{
  return mod ((_TI - mod (_TI, 10)) / 10, 10);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mf2'() created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create function _MPRIME_P3 (in _TI integer) returns integer
{
  return mod (_TI, 10);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mf3'() created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

sinv_drop_inverse ('_MULTIPLE');
sinv_create_inverse ('_MULTIPLE', vector ('_MPRIME_P1', '_MPRIME_P2', '_MPRIME_P3'), 1);

select 1 from TINVS where _MULTIPLE (TI1, TI2, TI3) = 111;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mf(C1,C2,C3) = x -> C1 = mf1'(x) and C2 = mf2'(x) and C2 = mf3'(x) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 1 from TINVS where _MULTIPLE (TI1, 1, 1) = 111;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mf(C1,y,z) = x -> C1 = mf1'(x) and y = mf2'(x) and z = mf3'(x) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 1 from TINVS where _MULTIPLE (1, 1, 1) = TI;
ECHO BOTH $IF $EQU $STATE 42T05 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no mf(x,y,z) = C -> x = mf1'(C) and y = mf2'(C) and z = mf3'(C) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 1 from TINVS where _MULTIPLE (TI1, 1, 1) > 111;
ECHO BOTH $IF $EQU $STATE 42T05 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no mf(C1,y,z) > x -> C1 > mf1'(x) and y > mf2'(x) and z > mf3'(x) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 1 from TINVS where _MULTIPLE (TI1, 1) > 111;
ECHO BOTH $IF $NEQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no mf(C1,y) > x -> STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 1 from TINVS where _MULTIPLE (TI1, 1, 2, 3) > 111;
ECHO BOTH $IF $NEQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no mf(C1,y,z,w) > x ->  STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 1 from TINVS where _MULTIPLE (TI1, 1, 1) = _MULTIPLE (1, 2, 3);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mf(C1,y,z) = _MULTIPLE (a, b, c) -> C1 = a and y = b and = c STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 1 from TINVS where _MULTIPLE (1, 1, 1) = _MULTIPLE (1, 2, 3);
ECHO BOTH $IF $EQU $STATE 42T05 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no mf(x,y,z) = _MULTIPLE (a, b, c) -> x = a and y = b and = c STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 1 from TINVS where _MULTIPLE (TI1, 1, 1) > _MULTIPLE (1, 2, 3);
ECHO BOTH $IF $EQU $STATE 42T05 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no mf(C,y,z) > _MULTIPLE (a, b, c) -> STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 1 from (select distinct *, _MULTIPLE (TI1, TI2, TI3) as TII from TINVS) x where TII = 11;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": in nonexp DT mf(C1,C2,C3) = x -> mf1'(x) = C1 and mf2'(x) = C2 and mf3'(x) = C3 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 1 from (select *, _MULTIPLE (TI1, TI2, TI3) as TII from TINVS) x where TII = 11;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": in DT mf(C1,C2,C3) = x -> mf1'(x) = C1 and mf2'(x) = C2 and mf3'(x) = C3 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop view VE1;
drop view VE2;
create view VE1 as select _PSINGLE (TI1) as VE1_PS, * from TINVS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": VE1 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create view VE2 as select _PSINGLE (TI1) as VE2_PS, * from TINVS2;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": VE2 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain ('select 1 from VE1 where VE1_PS = 1');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": view and invs t1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain ('select count(*) from VE1, VE2 where VE1_PS = VE2_PS');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": view and invs t2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select _PSINGLE (_PSINGLE_PRIME (1));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": f(f'(x)) = x STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain ('select count(*) from VE1 join VE2 on VE1_PS = VE2_PS');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": view exp join and invs t2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*)
  from (select _MULTIPLE (TI1, TI2, TI3) as I_TI from TINVS) x
  where not exists (select *
      from (select _MULTIPLE (TINVS2.TI1, TINVS2.TI2, TINVS2.TI3) as I_TI2 from TINVS2) x2);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": f1'(f(a,b,c)) -> a t2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


sinv_drop_inverse ('datestring');
sinv_drop_inverse ('stringdate');
sinv_create_inverse ('datestring', 'stringdate', 1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create inverse over BIFs STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from TINV_UPD;
insert into VTINV_UPD (TIC, TI1, TI2, TI3) values (_PSINGLE(113), 1,1,1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": insert into ... (nf(C1)) values (nf (x)) -> insert into ... (C1) values (x) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from TINV_UPD;
insert into TINV_UPD values (1, 1, 1, 111);

update VTINV_UPD set TIC = _PSINGLE (113);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": update ... set nf(C1) = nf(x) -> update ... set C1 = x STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update VTINV_UPD set TIC = _PSINGLE (TI1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": update ... set nf(C1) = nf(C2) -> update ... set C1 = C2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


drop view VMTINV_UPD;
create view VMTINV_UPD as select _MULTIPLE (TI1, TI2, TI3) as TIC, TI from TINV_UPD;

delete from TINV_UPD;
insert into VMTINV_UPD (TIC, TI) values (111, 1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": insert into ... (nf(C1, C2, C3)) values (x) -> insert into ... (C1,C2,C3) values (nf1'(x), nf2'(x), nf3'(x)) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select * from TINV_UPD;

delete from TINV_UPD;
insert into TINV_UPD (TI, TI1, TI2, TI3) values (111, 1, 1, 1);
update VMTINV_UPD set TIC = 333, TI = 2;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": update ... set nf(C1, C2, C3) = x -> update ... set C1 = nf1'(x), C2 = nf2'(x), C3 = nf3'(x) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select * from TINV_UPD;

--
-- End of test
--
ECHO BOTH "COMPLETED: PL inverse suite (tinverse.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
