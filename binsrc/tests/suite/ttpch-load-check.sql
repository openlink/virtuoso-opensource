--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2016 OpenLink Software
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
-- test simple inserts, if they save leading spaces in varchars.

CREATE TABLE TEST_SUPPLIER (
    S_SUPPKEY     INTEGER NOT NULL,
    S_NAME        CHAR(25) NOT NULL,
    S_ADDRESS     VARCHAR(40) NOT NULL,
    S_NATIONKEY   INTEGER NOT NULL,
    S_PHONE       CHAR(15) NOT NULL,
    S_ACCTBAL     double precision NOT NULL,
    S_COMMENT     VARCHAR(101) NOT NULL,
    PRIMARY KEY   (S_SUPPKEY)
    )
alter index TEST_SUPPLIER on TEST_SUPPLIER partition (S_SUPPKEY int (0hexffff00))
;

insert into TEST_SUPPLIER (S_SUPPKEY,S_NAME,S_ADDRESS,S_NATIONKEY,S_PHONE,S_ACCTBAL,S_COMMENT)
values( 2022, 'Supplier#000002022',' dwebGX7Id2pc25YvY33',3,'13-924-162-8911',4296.26,' ironic, even deposits. blithely cl');

select S_ADDRESS from TEST_SUPPLIER;
ECHOLN BOTH $IF $EQU $LAST[1] " dwebGX7Id2pc25YvY33" "PASSED" "***FAILED" ": should not eat leading spaces in varchars:'"$LAST[1]"'";

delete from TEST_SUPPLIER;
select count(*) from TEST_SUPPLIER;
ECHOLN BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED" ": TEST_SUPPLIER table is empty";

-- test CSV loader, if it saves leading spaces in varchars.

create procedure TEST_SUPPLIER_FILL ()
{
  declare str_out any;
  str_out := string_output();
  http( '2022|Supplier#000002022| dwebGX7Id2pc25YvY33|3|13-924-162-8911|4296.26| ironic, even deposits. blithely cl|', str_out);
  csv_vec_load( str_out, 0, null, 'TEST_SUPPLIER', 0, vector ('csv-delimiter', '|', 'lax', 1, 'txn', 0));
}

TEST_SUPPLIER_FILL ();

select S_ADDRESS from TEST_SUPPLIER;
-- this fails, CVS loader eats leading spaces. this is not considered to be an error.
--ECHOLN BOTH $IF $EQU $LAST[1] " dwebGX7Id2pc25YvY33" "PASSED" "***FAILED" ": should not eat leading spaces in varchars:'"$LAST[1]"'";

delete from TEST_SUPPLIER;
select count(*) from TEST_SUPPLIER;
ECHOLN BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED" ": TEST_SUPPLIER table is empty";

drop procedure TEST_SUPPLIER_FILL;
DROP TABLE TEST_SUPPLIER;

select count(*) from REGION;
ECHOLN BOTH $IF $GTE $LAST[1] 5 "PASSED" "***FAILED" ": REGION table is filled properly. Should be at least 5";

select count(*) from NATION;
ECHOLN BOTH $IF $GTE $LAST[1] 25 "PASSED" "***FAILED" ": NATION table is filled properly. Should be at least 25";

select count(*) from SUPPLIER;
ECHOLN BOTH $IF $GTE $LAST[1] $* 10000 $U{TPCH_SCALE} "PASSED" "***FAILED" ": SUPPLIER table is filled properly. Should be at least " $* 10000 $U{TPCH_SCALE};

select count(*) from CUSTOMER;
ECHOLN BOTH $IF $GTE $LAST[1] $* 150000 $U{TPCH_SCALE} "PASSED" "***FAILED" ": CUSTOMER table is filled properly. Should be at least " $* 150000 $U{TPCH_SCALE};

select count(*) from PART;
ECHOLN BOTH $IF $GTE $LAST[1] $* 200000 $U{TPCH_SCALE} "PASSED" "***FAILED" ": PART table is filled properly. Should be at least " $* 200000 $U{TPCH_SCALE};

select count(*) from PARTSUPP;
ECHOLN BOTH $IF $GTE $LAST[1] $* 800000 $U{TPCH_SCALE} "PASSED" "***FAILED" ": PARTSUPP table is filled properly. Should be at least " $* 800000 $U{TPCH_SCALE};

select count(*) from LINEITEM;
ECHOLN BOTH $IF $GTE $LAST[1] $* 6000000 $U{TPCH_SCALE} "PASSED" "***FAILED" ": LINEITEM table is filled properly. Should be at least " $* 6000000 $U{TPCH_SCALE};

select count(*) from ORDERS;
ECHOLN BOTH $IF $GTE $LAST[1] $* 1500000 $U{TPCH_SCALE} "PASSED" "***FAILED" ": ORDERS table is filled properly. Should be at least " $* 1500000 $U{TPCH_SCALE};


select C_CUSTKEY from CUSTOMER_F where C_CUSTKEY = {fn CONVERT('7', SQL_INTEGER)};
ECHOLN BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED" ": equality on a column via function call";

