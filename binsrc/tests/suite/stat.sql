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
-- statistics test over tpc-d tables
ECHO BOTH "database statistic test begin\n";

drop table stat_counts;
create table stat_counts (cc_id integer, cc_prec integer, cc_ex integer);


create procedure stat_fill_counts_1 ()
{
	declare idx integer;
	idx := 0;
	for select cs_n_rows from sys_col_stat order by cs_table, cs_col do
	{
	  insert into stat_counts values (idx, cs_n_rows, null);
	  idx := idx + 1;
	}
}
;

create procedure stat_fill_counts_2 ()
{
	declare idx integer;
	idx := 0;
	for select cs_n_rows from sys_col_stat order by cs_table, cs_col do
	{
	  update stat_counts set cc_ex = cs_n_rows where cc_id = idx;
	  idx := idx + 1;
	}
}
;

create procedure wrap_SYS_DB_STAT (in x1 any, in x2 any)
{
  declare deadlock_retry_count integer;

  deadlock_retry_count := 100;
  declare exit handler for sqlstate '40001'
    {
      rollback work;
      if (deadlock_retry_count > 0)
	{
	  deadlock_retry_count := deadlock_retry_count - 1;
	  goto again;
	}
      else
	resignal;
    };

again:
    return SYS_DB_STAT (x1, x2);
};

wrap_SYS_DB_STAT (5, 0);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": SYS_DB_STAT : STATE=" $STATE "\n";

stat_fill_counts_1 ();

wrap_SYS_DB_STAT (0, 0);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": SYS_DB_STAT : STATE=" $STATE "\n";

stat_fill_counts_2 ();

-- select * from stat_counts;

select sprintf ('%.1f%%', avg ((abs (cc_prec - cc_ex + 0.0) / cc_ex) * 100)) from stat_counts where cc_ex > 1000;
echo BOTH "Average error = " $LAST[1] "\n";
