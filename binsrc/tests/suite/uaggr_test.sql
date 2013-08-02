--  
--  $Id: uaggr_test.sql,v 1.3.10.2 2013/01/02 16:15:37 source Exp $
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
create procedure BB (in num numeric)
{
  declare ceil integer;
  declare ceil2 integer;
  declare ceil3 integer;


  ceil := num;

  ceil2 := (cast (num*100 as integer)) - 100 * cast (num as integer);

  return sprintf ('%d.%02d', ceil, ceil2);
}
;
drop table var_test;
create table var_test (i integer identity, val integer);

select VAR_POP (val), VAR_SAMP (val), STDDEV_POP (val), COVAR_SAMP (i, i), COVAR_SAMP (i, val), COVAR_SAMP( val, i), COVAR_SAMP (val,val) from var_test;

insert into var_test (val) values (1);

select AVG(val), VAR_POP (val), VAR_SAMP(val), STDDEV_POP (val), COVAR_SAMP (i, i), COVAR_SAMP (i, val), COVAR_SAMP( val, i), COVAR_SAMP (val,val) from var_test;

select AVG(val), VAR (val), STDDEV (val), COVAR (i, i) from var_test;
ECHO BOTH $IF $EQU $LAST[2] NULL "PASSED" "***FAILED";
ECHO BOTH ": VAR() returns " $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[3] NULL "PASSED" "***FAILED";
ECHO BOTH ": STDDEV() returns " $LAST[3] "\n";
ECHO BOTH $IF $EQU $LAST[4] NULL "PASSED" "***FAILED";
ECHO BOTH ": COVAR() returns " $LAST[4] "\n";

select AVG(val), VAR_SAMP (val), STDDEV_SAMP (val), COVAR_SAMP (i, i) from var_test;
ECHO BOTH $IF $EQU $LAST[2] 0 "PASSED" "***FAILED";
ECHO BOTH ": VAR_SAMP() returns " $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[3] 0 "PASSED" "***FAILED";
ECHO BOTH ": STDDEV_SAMP() returns " $LAST[3] "\n";
ECHO BOTH $IF $EQU $LAST[4] 0 "PASSED" "***FAILED";
ECHO BOTH ": COVAR_SAMP() returns " $LAST[4] "\n";

insert into var_test (val) values (1);
insert into var_test (val) values (1);
insert into var_test (val) values (1);
insert into var_test (val) values (1);
insert into var_test (val) values (1);
insert into var_test (val) values (1);
insert into var_test (val) values (1);
insert into var_test (val) values (1);
insert into var_test (val) values (1);
insert into var_test (val) values (1);

insert into var_test (val)  values (5);
insert into var_test (val)  values (5);
insert into var_test (val)  values (5);
insert into var_test (val)  values (5);
insert into var_test (val)  values (5);
insert into var_test (val)  values (5);
insert into var_test (val)  values (5);
insert into var_test (val)  values (5);
insert into var_test (val)  values (5);
insert into var_test (val)  values (5);
insert into var_test (val)  values (5);


insert into var_test (val) values (7);
insert into var_test (val) values (7);
insert into var_test (val) values (7);
insert into var_test (val) values (7);
insert into var_test (val) values (7);
insert into var_test (val) values (7);
insert into var_test (val) values (7);
insert into var_test (val) values (7);
insert into var_test (val) values (7);
insert into var_test (val) values (7);
insert into var_test (val) values (7);

-- delete from var_test;
insert into var_test (val) values (1);
insert into var_test (val) values (2);
insert into var_test (val) values (3);
insert into var_test (val) values (4);
insert into var_test (val) values (5);
insert into var_test (val) values (6);


select VAR_POP (val) as VAR, STDDEV_POP (val) as STDDEV_POP, STDDEV_SAMP (val) as STDDEV_SAMP, COVAR_SAMP (i, i) as COVAR_SAMPxx, COVAR_SAMP (i, val) as COVAR_SAMPxy, COVAR_SAMP( val, i) as COVAR_SAMPyx, COVAR_POP (val, i) as COVAR_POPxy, COVAR_SAMP (val,val) as COVAR_SAMPyy from var_test;

--XXX
--select val, VAR_SAMP (i), VAR_POP(i), STDDEV_POP (i), COVAR_SAMP (i,i) from var_test group by val;


select BB (COVAR_SAMP (i, val)), BB ((SUM( (cast (i as numeric)) * val) - SUM(i) * SUM(val) / COUNT(i)) / (COUNT (i)-1))  from var_test;
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": COVAR_SAMP = (sum (xy) - sum (x) * sum (y) / n ) / (n - 1) = " $LAST[1] "\n";

select BB (COVAR_POP (i, val)), BB( (SUM( (cast (i as numeric)) * val) - SUM(i) * SUM(val) / COUNT(i)) / COUNT (i))  from var_test;
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": COVAR_POP = (sum (xy) - sum (x) * sum (y) / n ) / n = " $LAST[1] "\n";

select BB (VAR_POP (val)) , BB ((SUM(val * val) - SUM(val) * SUM(val) / (cast (COUNT(i) as numeric))) / COUNT (i) ) from var_test;
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": VAR_POP = (sum (xx) - sum (x) * sum (x) / n ) / n = " $LAST[1] "\n";

select BB (VAR_SAMP (val)), BB( COVAR_SAMP (val, val))  from var_test;
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": VAR_SAMP (x) = COVAR_SAMP (x,x) = " $LAST[1]"\n";

select BB (regr_slope (i, val)), BB ( covar_pop (i,val) / var_pop (val))  from var_test;
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": REGR_SLOPE returns COVAR_POP / VAR_POP = " $LAST[1] "\n";

select BB (REGR_INTERCEPT (i, val)) , BB (AVG (cast (i as numeric)) - REGR_SLOPE (i, val) * AVG (cast (val as numeric)) ) from var_test;
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": REGR_INTERCEPT(x,y) = AVG (x) - REGR_SLOPE (x,y) * AVG (y) = "$LAST[1] " \n";

select BB (REGR_COUNT (i, val)), BB ( COUNT (i)) from var_test;
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": REGR_COUNT = COUNT = " $LAST[1] "\n";

insert into var_test (val) values (null);
select BB (REGR_COUNT (i, val)), BB (COUNT (i)) from var_test;
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "***FAILED" "PASSED";
ECHO BOTH ": REGR_COUNT != COUNT \n";

select BB (REGR_AVGX (i, val)), BB( AVG(cast (i as numeric)) ) from var_test where val is not null;
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": REGR_AVGX = AVG(x) = " $LAST[1] "\n";

select BB (REGR_AVGY (i, val)), BB(AVG(cast (val as numeric)) ) from var_test where val is not null;
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": REGR_AVGY = AVG(y) = " $LAST[1] "\n";

select BB (CORR (i, val)), BB (COVAR_POP (i, val) / STDDEV_POP (i) / STDDEV_POP (val)  ) from var_test where val is not null;
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": CORR (x,y) == COVAR_POP (x,y) / (STDDEV_POP (x) * STDDEV_POP (y) ) = " $LAST[1] "\n";
 
select BB (REGR_R2 (i, val)), BB (CORR (i, val) * CORR (i, val)) from var_test;
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": REGR_R2 (x,y) = CORR (x,y)^2 = " $LAST[1] "\n";

select BB (REGR_SXX (i, val)), BB (REGR_COUNT(i,val) * VAR_POP (val)) from var_test where val is not null;
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": REGR_SXX = REGR_COUNT () * VAR_POP (y) = " $LAST[1] "\n";
select BB (REGR_SYY (i, val)), BB(REGR_COUNT(i,val) * VAR_POP (i)) from var_test where val is not null;
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": REGR_SYY = REGR_COUNT () * VAR_POP (x) = " $LAST[1] "\n";
select BB (REGR_SXY (i, val)), BB(REGR_COUNT(i,val) * COVAR_POP (i,val)) from var_test where val is not null;
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": REGR_SXY = REGR_COUNT () * COVAR_POP (x,y) = " $LAST[1] "\n";

