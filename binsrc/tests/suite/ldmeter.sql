--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2017 OpenLink Software
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

drop table ld_metric;

create table ld_metric
(
 lm_id int  primary key,
 lm_dt datetime,
 lm_first_id int,
 lm_secs_since_start int,
 lm_n_rows bigint,
 lm_n_deletes bigint,
 lm_cpu int,
 lm_io_stat any,
 lm_read_time bigint,
 lm_read_pct float,
 lm_rows_per_s float,
 lm_dels_per_s float,
 lm_cpu_pct float,
 lm_rusage any
 );

create index lm_dt on ld_metric (lm_dt);




create procedure io_stat ()
{
  return vector (sys_stat ('disk_reads'), sys_stat ('ra_count'), sys_stat ('ra_pages'), sys_stat ('tc_read_aside'), sys_stat ('tc_unused_read_aside'),
  sys_stat ('tc_merge_reads'), sys_stat ('tc_merge_read_pages'));
}

-- getrusage returns:
-- 0. user cpu msec
-- 1. sys cpu msec
-- 2. max  resident set
-- 3.  min flt
-- 4. maj flt
-- 5 n swap
-- 6. blocking input
-- 7. blocking output

create procedure ld_sample (in is_first int := 0)
{
  declare ru any;
  declare now datetime;
  declare id, n_rows, read_time, last_read_time, elapsed, n_dels int;
 id := sequence_next ('lm');
 now := curdatetime ();
 n_rows := (select cl_sys_stat (key_table, name_part (key_name, 2), 'touches') from sys_keys where key_name = 'DB.DBA.RDF_QUAD');
 n_dels := (select cl_sys_stat (key_table, name_part (key_name, 2), 'n_deletes') from sys_keys where key_name = 'DB.DBA.RDF_QUAD');

 ru := getrusage ();
  if (is_first)
    {

      insert into ld_metric (lm_id, lm_dt, lm_first_id, lm_cpu, lm_read_time, lm_n_rows, lm_rusage, lm_secs_since_start, lm_io_stat, lm_n_deletes) 
	values (id, now, id, ru[0] + ru[1], sys_stat ('read_cum_time'), n_rows, ru, 0, io_stat(), n_dels);
}
  else
    {
      declare last_dt, start_dt datetime;
      declare first_id, last_rows, last_cpu, last_read, last_dels  int;
      select lm_id, lm_dt  into first_id, start_dt from ld_metric where lm_dt < now and lm_first_id = lm_id order by lm_dt desc;
      select lm_dt, lm_n_rows, lm_cpu, lm_read_time, lm_n_deletes into last_dt, last_rows, last_cpu, last_read, last_dels  
	from ld_metric where lm_dt < now order by lm_dt desc;

      insert into ld_metric (lm_id, lm_dt, lm_first_id, lm_cpu, lm_read_time, lm_n_rows, lm_rusage, lm_secs_since_start, lm_io_stat, lm_n_deletes) 
	values (id, now, first_id, ru[0] + ru[1], sys_stat ('read_cum_time'), n_rows, ru, datediff ('second', start_dt, now), io_stat (), n_dels);
    elapsed := datediff ('second', last_dt, now);
      update ld_metric set
	lm_read_pct = (sys_stat ('read_cum_time') - last_read) / 10 / (0.0001 + elapsed),
	lm_cpu_pct = (((ru[0] + ru[1]) - last_cpu) / 10) / (0.001 + elapsed),
	lm_rows_per_s = (n_rows - last_rows) / (0.001 + elapsed),
	lm_dels_per_s = (n_dels - last_dels) / (0.001 + elapsed)
	where lm_id = id;
    }
  commit work;
}


create procedure ld_meter_run (in s_delay int)
{
  declare stat, msg any;
  ld_sample (1);
  while (1)
    {
      delay (s_delay);
      stat := '00000';
      exec ('ld_sample (0)', stat, msg, null);
      if (stat <> '00000')
	{
	  rollback work;
	  log_message (stat || ' ' || msg);
	}
    }
}


-- Query fro read rate in MB/s
-- select (io1 - io0) / 128.0 / datediff ('second', dt0, dt1) from (select a.lm_io_stat[0] as io1, b.lm_io_stat[0] as io0, a.lm_dt as dt1, b.lm_dt as dt0  from ld_metric a, ld_metric b where b.lm_id = a.lm_id - 1) f;
