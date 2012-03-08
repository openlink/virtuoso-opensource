--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2012 OpenLink Software
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

create procedure cmp
(in tbl1 varchar, in tbl2 varchar)
{
   declare meta any;
   declare res1, res2 any;
   declare res_tb1, res_tb2 any;
   declare column1 any;
   declare column2 any;
   declare val1 any;
   declare val2 any;
   declare state, msg, err varchar;
   declare col_name1, col_name2 varchar;
   declare stm1, stm2 varchar;
   declare idx1, len1 integer;
   declare idx2, len2 integer;
   declare col_type1, col_type2 integer;

   tbl1 := complete_table_name (tbl1, 1);
   tbl2 := complete_table_name (tbl2, 1);

   stm1 := concat ('select \\COLUMN, COL_DTP from SYS_COLS where \\TABLE = \'', tbl1, '\' ORDER BY \\COLUMN');
   stm2 := concat ('select \\COLUMN, COL_DTP from SYS_COLS where \\TABLE = \'', tbl2, '\' ORDER BY \\COLUMN');

   exec (stm1, state, msg, vector (), 100, meta, res1);
   exec (stm2, state, msg, vector (), 100, meta, res2);

--   if (length (res1) <> length (res2))
--     {
--       signal ('00001', concat ('Tables have different number of columns ',
--	  cast (length (res1) as varchar), ' ', cast (length (res2) as varchar) ), 'TBL_C');
--       return 0;
--     }

   len1 := length (res1);
   idx1 := 0;

   while (idx1 < len1)
     {
	col_name1 := aref (aref (res1, idx1), 0);
	col_name2 := aref (aref (res2, idx1), 0);
	col_type1 := aref (aref (res1, idx1), 1);
	col_type2 := aref (aref (res1, idx1), 1);

        if (col_name1 <> col_name2)
          return 0;

--      if (col_type1 <> col_type2)
--        return 0;

	if (col_name1 = '_IDN')
	  goto next;

	stm1 := concat ('select ', col_name1, ' from ', tbl1);
	stm2 := concat ('select ', col_name2, ' from ', tbl2);


   	exec (stm1, state, msg, vector (), 100, meta, res_tb1);
   	exec (stm2, state, msg, vector (), 100, meta, res_tb2);

        if (length (res_tb1) <> length (res_tb2))
	  {
	    signal ('00002', concat ('Tables have different result set ',
	       cast (length (res_tb1) as varchar), ' ', cast (length (res_tb2) as varchar) ), 'TBL_C');
	    return 0;
	  }

	len2 := length (res_tb1);
	idx2 := 0;

	while (idx2 < len2)
	  {

	     val1 := aref (aref (res_tb1, idx2), 0);
	     val2 := aref (aref (res_tb2, idx2), 0);

--	     if (col_type1 = 182)
	     if (__tag (val1) = 181  or __tag (val2) = 181 or __tag (val1) = 182 or __tag (val2) = 182)
	       {
		  val1 := trim (val1);
		  val2 := trim (val2);
	       }

	     if (__tag (val1) <> __tag (val2))
	       {
		  if ((__tag (val1) = 181 or __tag (val1) = 182) and (__tag (val2) = 191))
		    {
		      val1 := cast (val1 as integer);
		      val2 := floor (val2);
		    }

		  if ((__tag (val1) = 184) and (__tag (val2) = 181 or __tag (val2) = 191))
		    {
		      val1 := floor (val1);
		      val2 := cast (val2 as integer);
		    }
	       }

	     if (__tag (val1) = 219)
	       {
--		  val1 := cast (((val1 + 0.5) * 100) as integer) / 100;
--		  val2 := cast (((val2 + 0.5) * 100) as integer) / 100;
		  if (tbl2 = 'DB.DBA.OUT_Q15' and col_name1 = 'TOTAL_REVENUE')
		    {
		       val1 := floor (val1);
		       val2 := floor (val2);
	            }
		  else
		    {
		       val1 := floor (val1 + 0.5);
		       val2 := floor (val2 + 0.5);
	            }
	       }

	     if (val1 <> val2)
	       {
	          signal ('00003', concat ('Tables have different values ',
	            cast (val1 as varchar), ' ', cast (val2 as varchar) ), 'TBL_C');
	          return 0;
	       }

	    idx2 := idx2 + 1;
	  }

next:
	idx1 := idx1 + 1;
     }

--
-- all is OK.
--

  return 1;
}
;
