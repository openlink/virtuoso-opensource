--
--  $Id$
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

-- Query log view

create procedure sys_query_log_pv (in qrl_file varchar := null, in qrl_start datetime := null, in qrl_end datetime := null)
{
  declare ql_start_dt datetime;
  declare ql_client_ip, ql_user, ql_sqlstate, ql_error, ql_text, ql_plan varchar;
  declare ql_node_stat, ql_params,  arr, ses any;
  declare  ql_id, ql_rt_msec, ql_rt_clocks,
    ql_swap, ql_user_cpu, ql_sys_cpu,
    ql_plan_hash,
    ql_c_clocks, ql_c_msec, ql_c_disk_reads, ql_c_disk_wait, ql_c_cl_wait, ql_cl_messages, ql_c_rnd_rows,
    ql_rnd_rows, ql_seq_rows, ql_same_seg, ql_same_page, ql_same_parent, ql_thread_clocks, ql_disk_wait_clocks, ql_cl_wait_clocks, ql_pg_wait_clocks,
    ql_disk_reads, ql_spec_disk_reads, ql_messages, ql_message_bytes, ql_qp_threads, ql_memory, ql_memory_max, ql_c_memory,
    ql_lock_waits, ql_lock_wait_msec, ql_rows_affected int;


  result_names (ql_id, ql_start_dt, ql_rt_msec, ql_rt_clocks, ql_client_ip, ql_user, ql_sqlstate, ql_error,
		ql_swap, ql_user_cpu, ql_sys_cpu,

		ql_text, ql_params, ql_plan_hash,

		ql_c_clocks, ql_c_msec, ql_c_disk_reads, ql_c_disk_wait, ql_c_cl_wait, ql_cl_messages, ql_c_rnd_rows,

		ql_rnd_rows, ql_seq_rows, ql_same_seg, ql_same_page, ql_same_parent, ql_thread_clocks, ql_disk_wait_clocks, ql_cl_wait_clocks, ql_pg_wait_clocks,
ql_disk_reads, ql_spec_disk_reads, ql_messages, ql_message_bytes, ql_qp_threads, ql_memory, ql_memory_max,
		ql_lock_waits, ql_lock_wait_msec,
		ql_plan, ql_node_stat, ql_c_memory, ql_rows_affected);

  if (qrl_file is null)
  qrl_file := 'virtuoso.qrl';
  ses := file_open (qrl_file);
  for (;;)
    {
    arr := read_object (ses);
      if (0 = isarray (arr))
	goto done;
      if (qrl_start is not null and qrl_start > arr[1])
	goto next;
      if (qrl_end is not null and qrl_end < arr[1])
	goto done;
      result (arr[0], arr[1], arr[2], arr[3], arr[4], arr[5], arr[6], arr[7], arr[8], arr[9],
	      arr[10], arr[11], arr[12], arr[13], arr[14], arr[15], arr[16], arr[17], arr[18], arr[19],
	      arr[20], arr[21], arr[22], arr[23], arr[24], arr[25], arr[26], arr[27], arr[28], arr[29],
	      arr[30], arr[31], arr[32], arr[33], arr[34], arr[35], arr[36], arr[37], arr[38], arr[39],
	      arr[40], arr[41], arr[42]);
  next: ;
    }

 done:
  return;
}
;

create procedure ql_node_pv ()
{
  declare qn_type varchar;
  declare qn_ql_id, qn_node, qn_n_in, qn_n_out, qn_clocks int;
    result_names (qn_ql_id, qn_node, qn_type, qn_n_in, qn_n_out, qn_clocks);
}
;

create procedure view SYS_QUERY_LOG as sys_query_log_pv (qrl_file, qrl_start_dt, qrl_end_dt)
     (ql_id bigint, ql_start_dt datetime, ql_rt_msec bigint, ql_rt_clocks bigint, ql_client_ip varchar, ql_user varchar, ql_sqlstate varchar, ql_error varchar,
      ql_swap bigint, ql_user_cpu bigint, ql_sys_cpu bigint,

      ql_text long varchar, ql_params any, ql_plan_hash bigint,

      ql_c_clocks bigint, ql_c_msec bigint, ql_c_disk_reads bigint, ql_c_disk_wait bigint, ql_c_cl_wait bigint, ql_cl_messages bigint, ql_c_rnd_rows bigint,

		ql_rnd_rows bigint, ql_seq_rows bigint, ql_same_seg bigint, ql_same_page bigint, ql_same_parent bigint, ql_thread_clocks bigint, ql_disk_wait_clocks bigint, ql_cl_wait_clocks bigint, ql_pg_wait_clocks bigint,
      ql_disk_reads bigint, ql_spec_disk_reads bigint, ql_messages bigint, ql_message_bytes bigint, ql_qp_threads bigint, ql_memory bigint, ql_memory_max bigint,
		ql_lock_waits bigint, ql_lock_wait_msec bigint,
      ql_plan long varchar, ql_node_stat any, ql_c_memory bigint, ql_rows_affected bigint)
;


create procedure profile (in stmt varchar, in flags varchar := '', in params any := null)
{
  declare sdate datetime;
  declare st, msg,  res, resd, plan any;
  declare e_clocks, rt_msec, rt_clocks,
    rnd_rows, seq_rows, same_seg, same_page, same_parent, thread_clocks, disk_wait_clocks, cl_wait_clocks, pg_wait_clocks,
    disk_reads, spec_disk_reads, messages, message_bytes, qp_threads, memory, memory_max int;
  declare c_clocks , c_msec , c_disk_reads , c_disk_wait , c_cl_wait , cl_messages int;
  prof_enable (1);
  sdate := curdatetime ();
  if (params is null) params := vector ();
  st := '00000';
  e_clocks := rdtsc ();
  exec (stmt, st, msg, params, 20, resd, res);
  e_clocks := rdtsc () - e_clocks;
  prof_enable (0);

  select top 1 ql_rt_msec, ql_rt_clocks, ql_plan,
    ql_rnd_rows, ql_seq_rows, ql_same_seg, ql_same_page, ql_same_parent, ql_thread_clocks, ql_disk_wait_clocks, ql_cl_wait_clocks, ql_pg_wait_clocks,
    ql_disk_reads, ql_spec_disk_reads, ql_messages, ql_message_bytes, ql_qp_threads, ql_memory, ql_memory_max,
    ql_c_clocks , ql_c_msec , ql_c_disk_reads , ql_c_disk_wait , ql_c_cl_wait , ql_cl_messages

    into rt_msec, rt_clocks,  plan,
    rnd_rows, seq_rows, same_seg, same_page, same_parent, thread_clocks, disk_wait_clocks, cl_wait_clocks, pg_wait_clocks,
    disk_reads, spec_disk_reads, messages, message_bytes, qp_threads, memory, memory_max,
    c_clocks , c_msec , c_disk_reads , c_disk_wait , c_cl_wait , cl_messages
from sys_query_log where qrl_start_dt = sdate order by ql_start_dt;

  declare result long varchar;
  declare strses, row1 any;
  declare c, r int;
 strses := string_output ();
  result_names (result);
  if (st <> '00000')
    result (sprintf ('Error: %s: %s', st, msg));
  if (isarray (res))
    {
      for (r := 0; r < length (res); r := r + 1)
	{
	row1 := res[r];
	  for (c := 0; c < length (row1); c := c + 1)
	    {
	      {declare exit handler for sqlstate '*' 
						   { http_value ('***', 0, strses); };
		http_value (row1[c], 0, strses);
	      };
	      http ('\t', strses );
	    }
	  http ('\n', strses);
    }
      result (string_output_string (strses));
    }
  result (plan);
  strses := string_output ();
  result (sprintf ('\n %d msec %d%% cpu, %9.6g rnd %9.6g seq %9.6g%% same seg %9.6g%% same pg ', 
      rt_msec, 
      case e_clocks when 0 then -1 else thread_clocks * 100.0 / e_clocks end, 
      rnd_rows, 
      seq_rows, 
      (100.0 * same_seg) / (rnd_rows + 1), 
      (100.0 * same_page) / (1 + rnd_rows)
      ));
  if (disk_reads)
    result (sprintf ('%d disk reads, %d read ahead, %9.6g%% wait', 
	disk_reads, 
	spec_disk_reads, 
	case e_clocks when 0 then -1 else 100.0 * disk_wait_clocks / e_clocks end
	));
  if (messages)
    result (sprintf (' %d messages %9.6g bytes/m, %9.2g%% clw', 
    	messages, 
	message_bytes / messages, 
	case e_clocks when 0 then -1 else cl_wait_clocks * 100.0 / e_clocks end
	));
  result (sprintf ('Compilation: %d msec %d reads %9.6g%% read %d messages %9.6g%% clw', 
  	c_msec, 
	c_disk_reads, 
	case e_clocks when 0 then -1 else 100.0 * c_disk_wait / e_clocks end,  
	cl_messages, 
	case e_clocks when 0 then -1 else 100.0 * c_cl_wait  / e_clocks end
	));
}
;
