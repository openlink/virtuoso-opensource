--
--  process.sql
--
--  $Id$
--
--  BPEL support view/procedures
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2014 OpenLink Software
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

create procedure BPEL..get_err_msg (in x any)
{
  if (x is null)
    return null;
  else
    return aref (x,1);
}
;

create xml view "bpel_1_inst" as {
        BPEL.BPEL.script S as "Script" (
               bs_id as Id,
               bs_name as Name,
               bs_state as State,
               bs_date as UploadDate,
               bs_audit as Audit,
               bs_debug as "Debug"
        )
            {
            BPEL.BPEL.instance I as Instance (
                   bi_id as Id,
                   bi_state as State,
                   BPEL..get_err_msg (bi_error) as error,
                   bi_lerror_handled as error_handled,
                   bi_last_act as InactiveSince,
		   bi_started as StartedTime
            )
        on (bi_script = S.bs_id)
  }
}
;


create procedure BPEL.BPEL.stop_process (in script_id int)
{
	for select bi_id from BPEL.BPEL.instance
		where bi_script = script_id
	do {
		BPEL.BPEL.stop_instance (bi_id);
	}
}
;

create procedure BPEL.BPEL.stop_instance (in inst int)
{
	delete from BPEL.BPEL.wait
		where bw_instance = inst;

	update BPEL.BPEL.instance set bi_state = 3 where bi_id = inst and bi_state <> 2;
}
;

