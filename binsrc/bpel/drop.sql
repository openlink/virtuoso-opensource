--
--  drop.sql
--
--  $Id$
--
--  BPEL uninstall operations
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

-- TABLES
BPEL.BPEL.silent_exec ('drop table BPEL.BPEL.script');
BPEL.BPEL.silent_exec ('drop table BPEL..script_source');
BPEL.BPEL.silent_exec ('drop table BPEL.BPEL.instance');
BPEL.BPEL.silent_exec ('drop table BPEL.BPEL.partner_link_init');
BPEL.BPEL.silent_exec ('drop table BPEL..partner_link');
BPEL.BPEL.silent_exec ('drop table BPEL.BPEL.graph');
BPEL.BPEL.silent_exec ('drop table BPEL.BPEL.wait');
BPEL.BPEL.silent_exec ('drop table BPEL.BPEL.queue');
BPEL.BPEL.silent_exec ('drop table BPEL..types_init');
BPEL.BPEL.silent_exec ('drop table BPEL.BPEL.message_parts');
BPEL.BPEL.silent_exec ('drop table BPEL.BPEL.remote_operation');
BPEL.BPEL.silent_exec ('drop table BPEL.BPEL.operation');
BPEL.BPEL.silent_exec ('drop table BPEL.BPEL.partner_link_conf');
BPEL.BPEL.silent_exec ('drop table BPEL.BPEL.property');
BPEL.BPEL.silent_exec ('drop table BPEL.BPEL.property_alias');
BPEL.BPEL.silent_exec ('drop table BPEL.BPEL.correlation_props');
BPEL.BPEL.silent_exec ('drop table BPEL..variables');
BPEL.BPEL.silent_exec ('drop table BPEL..links');
BPEL.BPEL.silent_exec ('drop table BPEL..compensation_scope');
BPEL.BPEL.silent_exec ('drop table BPEL..wsa_messages');
BPEL.BPEL.silent_exec ('drop table BPEL..lock');
BPEL.BPEL.silent_exec ('drop table BPEL..reply_wait');
BPEL.BPEL.silent_exec ('drop table BPEL..time_wait');
BPEL.BPEL.silent_exec ('drop table BPEL..dbg_message');
BPEL.BPEL.silent_exec ('drop table BPEL..configuration');
BPEL.BPEL.silent_exec ('drop table BPEL..error_log');
BPEL.BPEL.silent_exec ('drop table BPEL.BPEL.op_stat');
BPEL.BPEL.silent_exec ('drop table BPEL.BPEL.hosted_classes');
-- additional tables from tutorials
BPEL.BPEL.silent_exec ('drop table BPEL.BPEL.resOnResult1');
BPEL.BPEL.silent_exec ('drop table BPEL.BPEL.resOnResult');
-- UDT
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.node');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.place_vpa');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.place_vq');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.place_vpr');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.place_plep');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.place_expr');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.place_text');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.wait');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.sql_exec');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.java_exec');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.clr_exec');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.switch');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.case1');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.otherwise');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.while_st');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.assign');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.flow');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.onmessage');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.onalarm');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.receive');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.reply');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.invoke');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.sequence');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.compensation_handler');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.scope_end');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.compensation_handler_end');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.catch_fault');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.fault_handlers');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.scope');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.compensate');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.jump');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.link');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.empty');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.throw');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.catch');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.pick');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.terminate');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.server_failure');
BPEL.BPEL.silent_exec ('drop type BPEL..comp_ctx');
BPEL.BPEL.silent_exec ('drop type BPEL..ctx');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.activity');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.place');
BPEL.BPEL.silent_exec ('drop type BPEL.BPEL.partner_link_opts');
-- PROCEDURES

create procedure BPEL.BPEL.DROP_ALL_BPEL_PROC ()
{
  declare arr any;
  arr := vector ();
  for select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like 'BPEL.%'
	and P_NAME <> 'BPEL.BPEL.DROP_ALL_BPEL_PROC'
        and P_NAME <> 'BPEL.BPEL.silent_exec' do
    {
      arr := vector_concat (arr, vector (P_NAME));
    }
  foreach (any elm in arr) do
    {
      DB.DBA.EXEC_STMT ('drop procedure "'||elm||'"', 0);
    }
}
;

BPEL.BPEL.DROP_ALL_BPEL_PROC ()
;

drop procedure BPEL.BPEL.DROP_ALL_BPEL_PROC
;

create procedure BPEL.BPEL.drop_seq ()
{
  sequence_remove('BPEL_NODE_ID');
  commit work;

  sequence_remove('bpel_scope_id');
  commit work;

  sequence_remove('connection_id');
  commit work;
}
;

BPEL.BPEL.drop_seq ()
;

drop procedure BPEL.BPEL.drop_seq
;

BPEL.BPEL.silent_exec ('drop user BPEL');

drop procedure BPEL.BPEL.silent_exec;
