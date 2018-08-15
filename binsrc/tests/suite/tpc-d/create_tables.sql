--  
--  $Id$
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
-- PARAMS
-- integer    (Virtuoso: integer)
-- smallmoney (Virtuoso: numeric (3,2))
-- largemoney (Virtuoso: numeric (20,2))
-- datetime   (Virtuoso: datetime)
-- date       (Virtuoso: date)

drop table CUSTOMER;
drop table HISTORY;
drop table LINEITEM;
drop table NATION;
drop table ORDERS;
drop table PART;
drop table PARTSUPP;
drop table REGION;
drop table SUPPLIER;


-- 150 000 * SF
create table CUSTOMER (
	C_CUSTKEY	$U{integer},
	C_NAME		varchar(25),
	C_ADDRESS	varchar(40),
	C_NATIONKEY	$U{integer},
	C_PHONE		character(15),
	C_ACCTBAL	$U{largemoney},
	C_MKTSEGMENT	character(10),
	C_COMMENT	varchar(117),
	primary key (C_CUSTKEY)
);

create table HISTORY (
	H_P_KEY $U{integer},
	H_S_KEY $U{integer},
	H_O_KEY $U{integer},
	H_L_KEY $U{integer},
	H_DELTA $U{integer},
	H_DATE_T $U{datetime}
);

-- 1 500 000 * random(1, 7) * SF
create table LINEITEM (
	L_ORDERKEY	$U{integer},
	L_PARTKEY	$U{integer},
	L_SUPPKEY	$U{integer},
	L_LINENUMBER	$U{integer},
	L_QUANTITY	$U{largemoney},
	L_EXTENDEDPRICE	$U{largemoney},
	L_DISCOUNT	$U{smallmoney},
	L_TAX		$U{smallmoney},
	L_RETURNFLAG	character(1),
	L_LINESTATUS	character(1),
	L_SHIPDATE	$U{date},
	L_COMMITDATE	$U{date},
	L_RECEIPTDATE	$U{date},
	L_SHIPINSTRUCT	character(25),
	L_SHIPMODE	character(10),
	L_COMMENT	varchar(44),
	primary key (L_ORDERKEY, L_LINENUMBER)
);

-- 25
create table NATION (
	N_NATIONKEY	$U{integer},
	N_NAME		character(25),
	N_REGIONKEY	$U{integer},
	N_COMMENT	varchar(152),
	primary key (N_NATIONKEY)
);

-- 1 500 000 * SF
create table ORDERS (
	O_ORDERKEY	$U{integer},
	O_CUSTKEY	$U{integer},
	O_ORDERSTATUS	character(1),
	O_TOTALPRICE	$U{largemoney},
	O_ORDERDATE	$U{date},
	O_ORDERPRIORITY	character(15),
	O_CLERK		character(15),
	O_SHIPPRIORITY	$U{integer},
	O_COMMENT	varchar(79),
	primary key(O_ORDERKEY)
);

-- 200 000 * SF
create table PART (
	P_PARTKEY	$U{integer},
	P_NAME		varchar(55),
	P_MFGR		character(25),
	P_BRAND		character(10),
	P_TYPE		varchar(25),
	P_SIZE		$U{integer},
	P_CONTAINER	character(10),
	P_RETAILPRICE	$U{largemoney},
	P_COMMENT	varchar(23),
	primary key (P_PARTKEY)
);

-- 800 000 * SF
create table PARTSUPP (
	PS_PARTKEY	$U{integer},
	PS_SUPPKEY	$U{integer},
	PS_AVAILQTY	$U{integer},
	PS_SUPPLYCOST	$U{largemoney},
	PS_COMMENT	varchar(199),
	primary key (PS_PARTKEY, PS_SUPPKEY)
);

-- 5
create table REGION (
	R_REGIONKEY	$U{integer},
	R_NAME		character(25),
	R_COMMENT	varchar(152),
	primary key (R_REGIONKEY)
);

-- 10 000 * SF
create table SUPPLIER (
	S_SUPPKEY	$U{integer},
	S_NAME		character(25),
	S_ADDRESS	varchar(40),
	S_NATIONKEY	$U{integer},
	S_PHONE		character(15),
	S_ACCTBAL	$U{largemoney},
	S_COMMENT	varchar(101),
	primary key (S_SUPPKEY)
);
