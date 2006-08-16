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
ECHO BOTH "STARTED: TPC-D queries\n";


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


load Q1.sql;
load Q2.sql;
load Q3.sql;
load Q4.sql;
load Q5.sql;
load Q6.sql;
load Q7.sql;
load Q8.sql;
load Q9.sql;
load Q10.sql;
load Q11.sql;
load Q12.sql;
load Q13.sql;
load Q14.sql;
load Q15.sql;
load Q16.sql;
load Q17.sql;
load Q18.sql;
load Q19.sql;
load Q20.sql;
load Q21.sql;
load Q22.sql;

ECHO BOTH "COMPLETED: TPC-D queries \n\n";
