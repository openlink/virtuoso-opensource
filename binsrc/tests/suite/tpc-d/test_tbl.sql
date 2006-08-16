--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2006 OpenLink Software
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
drop table OUT_Q1;
create table OUT_Q1 (
	L_RETURNFLAG	CHARACTER (1),
	L_LINESTATUS	CHARACTER (1),
	SUM_QTY		DECIMAL,
	SUM_BASE_PRICE	DECIMAL,
	SUM_DISC_PRICE	DECIMAL,
	SUM_CHARGE	DECIMAL,
	AVG_QTY		DECIMAL (10, 8),
	AVG_PRICE	DECIMAL,
	AVG_DISC	DECIMAL (10, 5),
	COUNT_ORDER	INTEGER
);


drop table OUT_Q2;
create table OUT_Q2 (
	S_ACCTBAL	NUMERIC,
	S_NAME		CHARACTER (25),
	N_NAME		CHARACTER (25),
	P_PARTKEY	INTEGER,
	P_MFGR		CHARACTER (25),
	S_ADDRESS	VARCHAR (40),
	S_PHONE		CHARACTER (15),
	S_COMMENT	VARCHAR (101)
);


drop table OUT_Q3;
create table OUT_Q3 (
	L_ORDERKEY	INTEGER,
	REVENUE		DECIMAL (12,4),
	O_ORDERDATE	DATE,
	O_SHIPPRIORITY	INTEGER
);


drop table OUT_Q4;
create table OUT_Q4 (
	O_ORDERPRIORITY CHARACTER (15),
	ORDER_COUNT	INTEGER
);


drop table OUT_Q5;
create table OUT_Q5 (
	N_NAME		CHARACTER (25),
	REVENUE		DECIMAL (12,4)
);


drop table OUT_Q6;
create table OUT_Q6 (
	REVENUE		DECIMAL (12,4)
);


drop table OUT_Q7;
create table OUT_Q7 (
	SUPP_NATION	CHARACTER (25),
	CUST_NATION	CHARACTER (25),
	L_YEAR		INTEGER,
	REVENUE		DECIMAL (12,4)
);


drop table OUT_Q8;
create table OUT_Q8 (
	O_YEAR		INTEGER,
	MKT_SHARE	DECIMAL (12,4)
);


drop table OUT_Q9;
create table OUT_Q9 (
	NATION		CHARACTER (25),
	O_YEAR		INTEGER,
	SUM_PROFIT	DECIMAL (12,4)
);


drop table OUT_Q10;
create table OUT_Q10 (
	C_CUSTKEY	INTEGER,
	C_NAME		CHARACTER (25),
	REVENUE		DECIMAL (12,4),
	C_ACCTBAL	DECIMAL (12,4),
	N_NAME		CHARACTER (25),
	C_ADDRESS	CHARACTER (40),
	C_PHONE		CHARACTER (15),
	C_COMMENT	CHARACTER (117)
);


drop table OUT_Q11;
create table OUT_Q11 (
	PS_PARTKEY	INTEGER,
	VALUE		DECIMAL (12,4)
);


drop table OUT_Q12;
create table OUT_Q12 (
	L_SHIPMODE	CHARACTER (10),
	HIGH_LINE_COUNT	DECIMAL (12,4),
	LOW_LINE_COUNT	DECIMAL (12,4)
);


drop table OUT_Q13;
create table OUT_Q13 (
	C_COUNT		DECIMAL (12,4),
	CUSTDIST	DECIMAL (12,4)
);


drop table OUT_Q14;
create table OUT_Q14 (
	PROMO_REVENUE	DECIMAL (12,4)
);


drop table OUT_Q15;
create table OUT_Q15 (
	S_SUPPKEY	INTEGER,
	S_NAME		CHARACTER (25),
	S_ADDRESS	VARCHAR(40),
	S_PHONE		CHARACTER(15),
	TOTAL_REVENUE	DECIMAL (12,4)
);


drop table OUT_Q16;
create table OUT_Q16 (
	P_BRAND		CHARACTER (10),
	P_TYPE		CHARACTER (25),
	P_SIZE		INTEGER,
	SUPPLIER_CNT	INTEGER
);


drop table OUT_Q17;
create table OUT_Q17 (
	AVG_YEARLY	DECIMAL (12,4)
);


drop table OUT_Q18;
create table OUT_Q18 (
	C_NAME		CHARACTER (25),
	C_CUSTKEY	INTEGER,
	O_ORDERKEY	INTEGER,
	O_ORDERDATE	DATE,
	O_TOTALPRICE	DECIMAL (12,2),
	SUM_L_QUANTITY  DECIMAL (12,2)
);


drop table OUT_Q19;
create table OUT_Q19 (
	REVENUE		DECIMAL (12,4)
);


drop table OUT_Q20;
create table OUT_Q20 (
	S_NAME		CHARACTER(25),
	S_ADDRESS	VARCHAR(40)
);


drop table OUT_Q21;
create table OUT_Q21 (
	S_NAME		CHARACTER(25),
	NUMWAIT		INTEGER
);


drop table OUT_Q22;
create table OUT_Q22 (
	CNTRYCODE	CHARACTER (2),
	NUMCUST		INTEGER,
	TOTACCTBAL	DECIMAL (12,4)
);
