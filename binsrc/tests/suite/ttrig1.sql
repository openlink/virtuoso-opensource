--
--  ttrig1.sql
--
--  $Id: ttrig1.sql,v 1.6.10.3 2013/01/02 16:15:30 source Exp $
--
--  Test local or remote table triggers.
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

ECHO BOTH "STARTED: TRIGGERS TEST 1\n";

delete from T_WAREHOUSE;
delete from T_ORDER;
delete from T_ORDER_LINE;

insert into T_WAREHOUSE (W_ID, W_DATA) values (1, 'sample warehouse');
insert into T_ORDER (O_ID, O_W_ID) values (1, 1);
insert into T_ORDER_LINE (OL_O_ID, OL_I_ID, OL_QTY, OL_I_PRICE) values (1, 101, 3, 2);
insert into T_ORDER_LINE (OL_O_ID, OL_I_ID, OL_QTY, OL_I_PRICE) values (1, 102, 4, 2);

select cast (O_VALUE as integer) from T_ORDER;
ECHO BOTH $IF $EQU $LAST[1] 14 "PASSED" "***FAILED";
ECHO BOTH ": O_VALUE after 2 line inserts " $LAST[1] "\n";

update T_ORDER_LINE set OL_QTY = 10 where OL_O_ID = 1 and OL_I_ID = 101;
select cast (O_VALUE as integer) from T_ORDER;
ECHO BOTH $IF $EQU $LAST[1] 28 "PASSED" "***FAILED";
ECHO BOTH ": O_VALUE after line update inserts " $LAST[1] "\n";

update T_ORDER_LINE set OL_QTY = 10 where OL_O_ID = 1 and OL_I_ID = 101;
select cast (O_VALUE as integer) from T_ORDER;
ECHO BOTH $IF $EQU $LAST[1] 28 "PASSED" "***FAILED";
ECHO BOTH ": O_VALUE after line update #2  " $LAST[1] "\n";

insert into T_ORDER (O_ID, O_W_ID) values (2, 1);
insert into T_ORDER_LINE (OL_O_ID, OL_I_ID, OL_QTY, OL_I_PRICE)
     select 2, OL_I_ID, OL_QTY, OL_I_PRICE from T_ORDER_LINE where OL_O_ID = 1;

select cast (O_VALUE as integer) from T_ORDER;
ECHO BOTH $IF $EQU $LAST[1] 28 "PASSED" "***FAILED";
ECHO BOTH ": O_VALUE after insert select " $LAST[1] "\n";

ol_reprice_1 (102, 4);
select cast (O_VALUE as integer) from T_ORDER;
ECHO BOTH $IF $EQU $LAST[1] 36 "PASSED" "***FAILED";
ECHO BOTH ": O_VALUE after positioned reprice #1 " $LAST[1] "\n";

ol_reprice_2 (102, 2);
select cast (O_VALUE as integer) from T_ORDER;
ECHO BOTH $IF $EQU $LAST[1] 28 "PASSED" "***FAILED";
ECHO BOTH ": O_VALUE after positioned reprice #1 " $LAST[1] "\n";

ol_del_i_id_2 (102);
select cast (O_VALUE as integer) from T_ORDER;
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": O_VALUE after positioned delete " $LAST[1] "\n";

delete from T_ORDER_LINE;
select cast (O_VALUE as integer) from T_ORDER;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": O_VALUE after line delete " $LAST[1] "\n";

delete from T_ORDER;
insert into T_ORDER (O_ID, O_W_ID) values (1, 1);
insert into T_ORDER_LINE (OL_O_ID, OL_I_ID, OL_QTY, OL_I_PRICE) values (1, 101, 3, 2);
insert into T_ORDER_LINE (OL_O_ID, OL_I_ID, OL_QTY, OL_I_PRICE) values (1, 102, 4, 2);
select cast (W_ORDER_VALUE as integer) from T_WAREHOUSE;
ECHO BOTH $IF $EQU $LAST[1] 14 "PASSED" "***FAILED";
ECHO BOTH ": W_ORDER_VALUE before order delete " $LAST[1] "\n";

delete from T_ORDER;
select cast (W_ORDER_VALUE as integer) from T_WAREHOUSE;
echo BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": W_ORDER_VALUE after order delete " $LAST[1] "\n";

ECHO BOTH "COMPLETED: TRIGGERS TEST 1\n";
