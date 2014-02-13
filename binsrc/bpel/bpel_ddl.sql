--
--  bpel_ddl.sql
--
--  $Id$
--
--  BPEL DB Schema
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


create procedure exec_no_error(in expr varchar) {
  declare state, message, meta, result any;
  exec(expr, state, message, vector(), 0, meta, result);
}
;

exec_no_error ('
create type BPEL.BPEL.node as (
	bn_id		int,			      -- node id
	bn_parent	int,			      -- parent node id
	bn_top_node 	BPEL.BPEL.node default null,  -- the top-most node
	bn_parent_node 	BPEL.BPEL.node default null,  -- the parent node
	bn_activity	BPEL.BPEL.activity,	      -- activity representing the node
	bn_childs	any,			      -- lvector of node ids of the children nodes
	bn_scope	int,
	bn_script_id 	int,			      -- the script
	bn_cnt		int default 0 -- last activity serial no; valid on top node only
	)
	SELF AS REF
	constructor method node (act BPEL.BPEL.activity, inst int, top_node BPEL.BPEL.node),
	static method new_node (parent BPEL.BPEL.node, act BPEL.BPEL.activity, inst int) returns BPEL.BPEL.node,
	static method new_flow (parent BPEL.BPEL.node, inst int) returns BPEL.BPEL.node,
	static method new_compensation_handler (parent BPEL.BPEL.node, inst int) returns BPEL.BPEL.node,
	static method new_fault_handlers (parent BPEL.BPEL.node, inst int) returns BPEL.BPEL.node,
	static method new_activity (parent BPEL.BPEL.node, inst int) returns BPEL.BPEL.node,
	static method new_sequence (parent BPEL.BPEL.node, inst int) returns BPEL.BPEL.node,
	static method new_invoke (parent BPEL.BPEL.node, inst int,
		_partnerLink varchar,
		_portType varchar,
		_operation varchar,
		_inputVariable varchar,
		_outputVariable varchar,
		_corrs any
		) returns BPEL.BPEL.node,
	static method new_compensate (parent BPEL.BPEL.node, inst int,
		_scope varchar) returns BPEL.BPEL.node,
	static method new_scope (parent BPEL.BPEL.node, inst int, in nm varchar) returns BPEL.BPEL.node,
	method add_child (child BPEL.BPEL.node) returns int')
;

-- Activity Base UDT
exec_no_error('
create type BPEL.BPEL.activity as (
		ba_type 	  varchar,
		ba_id		  int,	-- serial no
		ba_preds_bf varbinary default \'\\x0\\x0\', 	-- bitmask for predecesors to be completed
		ba_init_bf 	  varbinary default \'\\x0\\x0\',	-- bitmask for initialization of loops
		ba_parent_id	  int,
		ba_scope_idx 	  int,	-- index of the current scope"s number in the instance scope no vector
		ba_pscope_idx 	  int,	-- index of the parent scope"s number in the instance scope no vector
		ba_join_cond 	  varchar default NULL,
		ba_suppress_join_fail int default 0,
		ba_scope 	  int default 0,
		ba_fault_hdl 	  int default 0,
		ba_fault_hdl_bit  int default 0,
		ba_src_links	  any,
		ba_tgt_links 	  any,
		ba_enc_scps 	  any,
		ba_succ		  any,
		ba_src_line	  int default null,
		ba_is_event	  int,
		ba_in_comp	  int
		)
	method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int,
	method http_output (mode varchar) returns varchar,
	method add_audit_entry(inst int, node int, in info any) returns int')
;

exec_no_error ('
create type BPEL.BPEL.place as (
	bp_id	int,
	bp_query_prefix varchar
	)
	method get_value (in inst int, in scope int, in scope_inst int) returns any,
	method set_value (in inst int, in scope int, in scope_inst int, in val any) returns int,
	method get_info () returns varchar')
;

exec_no_error ('
create type BPEL.BPEL.place_vpa under BPEL.BPEL.place as (
	ba_var	varchar,
	ba_part varchar,
	ba_query varchar
	)
	overriding method get_value (in inst int, in scope int, in scope_inst int) returns any,
	overriding method set_value (in inst int, in scope int, in scope_inst int, in val any) returns int,
	overriding method get_info () returns varchar,
	constructor method place_vpa (v varchar, part varchar, q varchar)')
;

exec_no_error ('
create type BPEL.BPEL.place_vq under BPEL.BPEL.place as (
	ba_var	varchar,
	ba_query varchar
	)
	overriding method get_value (in inst int, in scope int, in scope_inst int) returns any,
	overriding method set_value (in inst int, in scope int, in scope_inst int, in val any) returns int,
	overriding method get_info () returns varchar,
	constructor method place_vq (v varchar, q varchar)')
;

exec_no_error ('
create type BPEL.BPEL.place_vpr under BPEL.BPEL.place as (
	ba_var	varchar,
	ba_property	varchar
	)
	overriding method get_info () returns varchar,
	constructor method place_vpr (v varchar, prop varchar)')
;

exec_no_error ('
create type BPEL.BPEL.place_plep under BPEL.BPEL.place as (
	ba_pl	varchar,
	ba_ep	varchar
	)
	overriding method get_value (in inst int, in scope int, in scope_inst int) returns any,
	overriding method set_value (in inst int, in scope int, in scope_inst int, in val any) returns int,
	overriding method get_info () returns varchar,
	constructor  method place_plep (pl varchar, ep any)')
;

exec_no_error ('
create type BPEL.BPEL.place_expr under BPEL.BPEL.place as (
	ba_exp	varchar
	)
	overriding method get_value (in inst int, in scope int, in scope_inst int) returns any,
	overriding method set_value (in inst int, in scope int, in scope_inst int, in val any) returns int,
	overriding method get_info () returns varchar,
	constructor method  place_expr (expr varchar)')
;

exec_no_error ('
create type BPEL.BPEL.place_text under BPEL.BPEL.place as (
	ba_text	varchar
	)
	overriding method get_value (in inst int, in scope int, in scope_inst int) returns any,
	overriding method get_info () returns varchar,
	constructor method  place_text (_text varchar)')
;

-- Wait

exec_no_error ('
create type BPEL.BPEL.wait under BPEL.BPEL.activity as (
		ba_seconds	int
	)
	constructor method wait (dt varchar),
	overriding method http_output (mode varchar) returns varchar,
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int')
;



-- Virtuoso PL extension
exec_no_error ('
create type BPEL.BPEL.sql_exec under BPEL.BPEL.activity as (
	ba_proc_name	varchar,
	ba_sql_text	varchar
	)
	constructor method sql_exec (_text varchar),
	overriding method http_output (mode varchar) returns varchar,
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int')
;

-- Java extension
exec_no_error ('
create type BPEL.BPEL.java_exec under BPEL.BPEL.activity as (
	ba_class_name	varchar
	)
	constructor method java_exec (name varchar, _text varchar, _imports varchar),
	overriding method http_output (mode varchar) returns varchar,
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int')
;

-- .NET extension
exec_no_error ('
create type BPEL.BPEL.clr_exec under BPEL.BPEL.activity as (
	ba_class_name	varchar,
	ba_assemblies	any
	)
	constructor method clr_exec (name varchar, _text varchar, _imports varchar, refs any),
	overriding method http_output (mode varchar) returns varchar,
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int')
;


-- Switch
exec_no_error ('
create type BPEL.BPEL.switch under BPEL.BPEL.activity
	constructor method switch (),
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int')
;

-- Case
exec_no_error ('
create type BPEL.BPEL.case1 under BPEL.BPEL.activity as
        (
	  ba_condition	varchar
	)
	constructor method case1 (expr varchar),
	overriding method http_output (mode varchar) returns varchar,
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int')
;

-- Otherwise
exec_no_error ('
create type BPEL.BPEL.otherwise under BPEL.BPEL.activity
	constructor method otherwise (),
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int')
;

-- While
exec_no_error ('
create type BPEL.BPEL.while_st under BPEL.BPEL.activity as
	(
	  ba_condition  varchar
	)
	constructor method while_st (cond varchar),
	overriding method http_output (mode varchar) returns varchar,
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int')
;

-- Assign (one per copy)
exec_no_error ('create type BPEL.BPEL.assign under BPEL.BPEL.activity as (
	ba_from	BPEL.BPEL.place,
	ba_to	BPEL.BPEL.place
	)
	constructor method assign (_from BPEL.BPEL.place),
	method add_to (_to BPEL.BPEL.place) returns int,
	overriding method http_output (mode varchar) returns varchar,
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int');

-- Flow
exec_no_error ('create type BPEL.BPEL.flow under BPEL.BPEL.activity
	constructor method flow (),
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int');

-- Receive
exec_no_error ('create type BPEL.BPEL.receive under BPEL.BPEL.activity as (
		ba_name		varchar,
		ba_partner_link	varchar, -- id
		ba_port_type	varchar, -- id
		ba_operation	varchar, -- id
		ba_var		varchar, -- inputVariable
		ba_create_inst	int default 0, -- 0 == FALSE
		ba_correlations	any,
		ba_one_way	int
	)
	constructor method receive (_name		varchar,
			_partner_link	varchar,
		        _port_type	varchar,
			_operation	varchar,
			_var		varchar,
			_create_inst	varchar,
			_corrs	any,
			_one_way int
			),
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int,
	overriding method http_output (mode varchar) returns varchar,
	--method register_wait_object (inst int, node int, scope int) returns int,
	method register_wait_object (in inst int, in node int, in scope int, in scope_inst int, inout ctx BPEL..ctx) returns int,
	method check_correlation (in msg any, in inst int, in scope int, in scope_inst int, inout ctx BPEL..ctx) returns int,
	method unregister_wait_object (inst int, node int, scope int) returns int');

-- Reply
exec_no_error ('create type BPEL.BPEL.reply under BPEL.BPEL.activity as (
             ba_partnerLink varchar,
             ba_portType varchar,
             ba_operation varchar,
             ba_variable varchar,
             ba_name varchar,
	     ba_fault varchar default null,
	     ba_correlations		any -- correlation
	)
	constructor method reply (
             _partnerLink varchar,
             _portType varchar,
             _operation varchar,
             _variable varchar,
             _name varchar,
	     _corrs any,
	     _fault any
	     ),
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int,
	overriding method http_output (mode varchar) returns varchar');

-- Invoke (sync or async)
exec_no_error ('create type BPEL.BPEL.invoke under BPEL.BPEL.activity as (
	ba_name		varchar,
	ba_partner_link	varchar, -- id
        ba_port_type		varchar, -- id
	ba_operation		varchar, -- id
	ba_input_var		varchar, -- inputVariable
	ba_output_var		varchar,
	ba_correlations		any, -- correlation
	is_sync			int default 0
	)
	constructor method invoke ( _partnerLink varchar,
                _portType varchar,
                _operation varchar,
                _inputVariable varchar,
		_outputVariable varchar,
		_corrs any
		),
	overriding method http_output (mode varchar) returns varchar,
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int');

-- Sequence
exec_no_error ('create type BPEL.BPEL.sequence under BPEL.BPEL.activity as (
	ba_childs	any -- vector
	)
	constructor method sequence (),
	overriding method http_output (mode varchar) returns varchar,
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int');

-- CompensationHandler
exec_no_error ('create type BPEL.BPEL.compensation_handler under BPEL.BPEL.activity as (
	bch_parent_scope	int,
	bch_node_id	int -- reference to graph
	)
	constructor method compensation_handler (),
	overriding method http_output (mode varchar) returns varchar,
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int,
	overriding method compensate (in inst int, inout node int, inout amask varbinary) returns int');

exec_no_error ('create type BPEL.BPEL.compensation_handler_end under BPEL.BPEL.activity
	constructor method compensation_handler_end (),
	overriding method http_output (mode varchar) returns varchar,
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int');

-- Catch (obsoleted)
exec_no_error ('create type BPEL.BPEL.catch_fault as (
	cf_name		varchar,
	cf_var		varchar,
	cf_node_id	int
	)
	constructor method catch_fault (
		nm varchar,
		vr varchar,
		nd int)');

-- FaultHandler
exec_no_error ('create type BPEL.BPEL.fault_handlers under BPEL.BPEL.activity as (
	bfh_parent_scope	int,
	bfh_cfs			any -- array of BPEL.BPEL.catch_fault
	)
	constructor method fault_handlers (),
	overriding method http_output (mode varchar) returns varchar,
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int');

exec_no_error ('create type BPEL.BPEL.scope_end under BPEL.BPEL.activity as
	(
	  se_events any,
	  se_scope_name varchar,
	  se_comp_act int default 0
	)
	constructor method scope_end (inout events any, in scope_name any, in comps int),
	overriding method http_output (mode varchar) returns varchar,
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int');

-- Scope
exec_no_error ('create type BPEL.BPEL.scope under BPEL.BPEL.activity as (
	ba_parent_scope	int,
	ba_name	varchar,
	ba_exception any, -- array of fault description, handler node id ref to BPEL.BPEL.graph
	ba_compensation int,  --ref to BPEL.BPEL.graph
	ba_vars any,  -- array of (vars idx -- look at BPEL.BPEL.var
	ba_childs any, -- array
	ba_corrs any -- array of correlation set refs
	)
	constructor method scope (in nm varchar),
	constructor method scope (),
	overriding method http_output (mode varchar) returns varchar,
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int');


-- Compensate
exec_no_error ('create type BPEL.BPEL.compensate under BPEL.BPEL.activity as (
	ba_scope_name varchar
	)
	constructor method compensate (in _scope varchar),
	method handle_scope (in inst int, in curr_scope int,
		in compensation_scope int,
		in compensation_node int) returns int,
	overriding method http_output (mode varchar) returns varchar,
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int');

-- pseudo activity Jump
exec_no_error ('create type BPEL.BPEL.jump under BPEL.BPEL.activity as
	(
	  ba_act_id int,
	  ba_node_id int default 0
	)
	constructor method jump (in act_id int, in node_id int),
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int');

-- pseudo activity Link
exec_no_error ('create type BPEL.BPEL.link under BPEL.BPEL.activity as
	(
	  ba_name varchar
	)
	constructor method link (in name varchar),
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int');

-- Empty
exec_no_error ('create type BPEL.BPEL.empty under BPEL.BPEL.activity
	constructor method empty ()');

-- Throw
exec_no_error ('create type BPEL.BPEL.throw under BPEL.BPEL.activity as
	(
	  ba_fault varchar
	)
	constructor method throw (in fault varchar),
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int');

-- Catch
exec_no_error ('create type BPEL.BPEL.catch under BPEL.BPEL.activity as
	(
	  ba_fault varchar,
	  ba_var varchar
	)
	constructor method catch (in fault varchar, in var varchar),
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int');

-- Pick
exec_no_error ('create type BPEL.BPEL.pick under BPEL.BPEL.activity as
	(
	  ba_create_inst int
	)
	constructor method pick (in flag varchar),
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int');

-- onMessage
exec_no_error ('create type BPEL.BPEL.onmessage under BPEL.BPEL.receive
	constructor method onmessage
	(
	 _partner_link	varchar,
	 _port_type	varchar,
	 _operation	varchar,
	 _var		varchar,
	 _create_inst	varchar,
	 _corrs		any,
	 _one_way       int
	),
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int');

-- onAlarm
exec_no_error ('create type BPEL.BPEL.onalarm under BPEL.BPEL.activity as
	(
	  ba_for_exp varchar,
	  ba_until_exp varchar,
	  ba_seconds int
	)
	constructor method onalarm (in for_exp varchar, in until_exp varchar),
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int');

-- Terminate
exec_no_error ('create type BPEL.BPEL.terminate under BPEL.BPEL.activity
	constructor method terminate (),
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int');

-- XXX: for testing only : serverFailure
exec_no_error ('create type BPEL.BPEL.server_failure under BPEL.BPEL.activity
	constructor method server_failure (),
	overriding method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) returns int');

--
-- Tables; IMPORTANT: please keep descriptions up-to date
-- the following goes to the documentation
--


-- Scripts table, keeps one record per version
exec_no_error ('create table BPEL.BPEL.script (
	bs_id integer identity, 	-- unique id identifying the process
	bs_uri varchar,			-- obsoleted: script source URI
	bs_name varchar,		-- process name, all versions have same name
	bs_state int, 			-- 0 on, current version, 1 obsolete, 2 edit mode
	bs_date	datetime,		-- date of registration
	bs_audit int default 0, 	-- audit flag : 1 on, 0 off
	bs_debug int default 0,		-- debug flag
	bs_version int default 0,	-- process version
	bs_parent_id int default null,	-- fk to bs_id of previous process version
	bs_first_node_id int,  		-- the first node id in the graph
	bs_pickup_bf varbinary default \'\\x0\',	-- bitmask for resume nodes
	bs_act_num	int, 		-- stores the total number of activities
	bs_lpath	varchar default null, -- virtual directory
	bs_scopes	any,		-- initial copy of scopes array
	bs_step_mode    int default 0,	-- stepping mode flag

	-- process statistics
	bs_n_completed int default 0,
	bs_n_errors int default 0,
	bs_n_create int default 0,
	bs_cum_wait int default 0,
	primary key (bs_id))');

exec_no_error ('create index bs_name on BPEL.BPEL.script (bs_name, bs_state)');

-- BPEL and WSDL sources
exec_no_error ('create table BPEL..script_source
	(
	 bsrc_script_id int, -- script id, fk to bs_id of scripts table.
	 bsrc_role varchar,  -- one of bpel, bpel-ext, wsdl, deploy, partner-1... partner-n
	 bsrc_text long xml, -- source text
	 bsrc_url varchar,   -- if this comes from an uri
	 bsrc_temp varchar,  -- contains the namespaces info
	 primary key (bsrc_script_id, bsrc_role)
)
');



-- Process instances
exec_no_error ('create table BPEL.BPEL.instance (
	bi_id int identity,   		-- global immutable id of instance
	bi_script int,  		-- fk to bs_id from BPEL.BPEL.script
	bi_scope_no int default 0,  	-- sequence counter for scope numbers in instance
	bi_state int default 0,
		-- 0, started
		-- 1, suspended (wait for signal)
		-- 2, finished
		-- 3, aborted
	bi_error any,			-- error
	bi_lerror_handled int,
	bi_last_act	datetime,	-- last activity execution
	bi_started	datetime,	-- start time
	bi_init_oper	varchar,	-- operation that made the instance
	bi_host		varchar,
	bi_wsa		long xml,	-- WS-Addressing headers
	bi_activities_bf varbinary default \'\\x0\\x0\', -- bitmask for each activity is completed or not
	bi_link_status_bf varbinary default \'\\x0\\x0\', -- bitmask for link status
	bi_prefix_info varchar default \'\', -- xpath prefix string
	bi_scopes any,			-- array containing current compensation scopes
	bi_comp_stack any,
	primary key (bi_id))');


-- Initial values (URL etc.) for partner links
exec_no_error ('create table BPEL.BPEL.partner_link_init (
	bpl_script int, 	-- script instance id
	bpl_name varchar,	-- partner link name
	bpl_partner any,  	-- url, end point etc serialized
	bpl_role varchar,
	bpl_myrole varchar,
	bpl_type varchar,
	bpl_endpoint varchar,	-- partner service endpoint URL
	bpl_backup_endpoint varchar,
	bpl_wsdl_uri varchar,
	bpl_debug int default 0,-- debug flag
	bpl_opts long xml,	-- partner link options (WS-Security, WS-RM etc.)
	primary key (bpl_script,bpl_name))');

-- Runtime values for partner links (run time copy of partner_link_init table)
exec_no_error ('create table BPEL..partner_link (
	pl_inst int, 		-- instance id
	pl_name varchar, 	-- partner link name
	pl_scope_inst int, 	-- scope instance id
	pl_role int, 		-- flag 0 - myRole, 1 - partnerRole
	pl_endpoint varchar, 	-- current URL to the partner service
	pl_backup_endpoint varchar, -- second URL to the service for connection error
	pl_debug int default 0,	-- debug flag
	pl_opts long xml,	-- partner link options (WS-Security, WS-RM etc.)
	primary key (pl_inst, pl_name, pl_scope_inst, pl_role))');

-- Script compilation
exec_no_error ('create table BPEL.BPEL.graph (
	bg_script_id int,  	-- FK to bs_id of BPEL.BPEL.script
	bg_node_id int , 	-- running id in the script, referenced from BPEL.BPEL.waits etc.
	bg_activity BPEL.BPEL.activity, -- UDT representing activity
	bg_childs any,
	bg_parent int,
        bg_src_id varchar,	-- internal use
	primary key (bg_script_id, bg_node_id))');

sequence_set ('BPEL_NODE_ID', 1, 1);

-- Receive activities waiting for incoming message
exec_no_error ('create table BPEL.BPEL.wait (
	bw_uid varchar,
	bw_instance integer,  -- instance id
	bw_script varchar,    -- FK reference to bs_name of script table
	bw_script_id int,     -- FK reference to bs_id of script table
	bw_node int,	      -- FK reference to bg_node_id of the graph table
	bw_scope  int,
	bw_partner_link varchar, -- the party from which instance waiting a message
	bw_port varchar,  	 -- the name of the operation which instance wait to receive
	bw_deadline datetime,
	bw_message long varchar default null, -- if instance is occupied and message is already arrived
	bw_state int default 0,		      -- flag that bw_message is not null (0 or 1)
	bw_correlation_exp varchar, 	      -- XPath expression for computing the correlation value from message
	bw_expected_value long varbinary,     -- value of the expected correlation
	bw_message_type int default 0,	      -- where to expect the data : 0 - SOAP:Body 1 - SOAP:Header
	bw_start_date datetime,
	bw_from_comp int default 0,
	bw_security any,
	primary key (bw_instance, bw_node))');

exec_no_error ('create index wait_sp on BPEL.BPEL.wait (bw_port, bw_script, bw_message_type)');

exec_no_error ('create index wait_st on BPEL.BPEL.wait (bw_instance, bw_state)');

exec_no_error ('create index wait_uid on BPEL.BPEL.wait (bw_uid)');

-- Messages which have been arrived but not correlated yet
exec_no_error ('create table BPEL.BPEL.queue (
	bq_id int identity,	-- unique id
	bq_script int,		-- FK references bs_id from the script table
	bq_ts timestamp,
	bq_state int,		-- state of the Queue item; 0 - not processed
	bq_endpoint varchar,	-- not used
	bq_op varchar,		-- Operation name
	bq_mid varchar,		-- mot used
	bq_message long varchar, -- The incoming message text
	bq_header long varchar,  -- SOAP:Header
	bq_security any,
	primary key (bq_op, bq_ts)
	)');


-- Initial values for SOAP Messages and XMLSchema types
exec_no_error ('create table BPEL..types_init (
	vi_script int,	   -- FK reference to bs_id to the script table
	vi_name   varchar, -- message name, element name etc.
	vi_type   int, 	   -- 0 - message, 1 - element, 2 - XMLSchema type
	vi_value  long xml,-- Initial value
	primary key (vi_script, vi_name, vi_type)
)
')
;

-- Matching XPath expressions for the SOAP message parts
exec_no_error ('create table BPEL.BPEL.message_parts
	(
	mp_script int,	    -- FK reference to bs_id to the script table
	mp_message varchar, -- message name
	mp_part varchar,    -- part name
	mp_xp   varchar,    -- location XPath expression
	primary key (mp_script, mp_message, mp_part)
	)
')
;

-- Operations which are invoked by process (used in invoke activities)
exec_no_error ('create table BPEL.BPEL.remote_operation (
	ro_script int,		-- FK reference to bs_id to the script table
	ro_partner_link varchar,-- name of the partner link
	ro_role varchar,	-- not used
	ro_operation varchar,	-- operation name
	ro_port_type varchar,	-- port type
	ro_input varchar,	-- input message name
	ro_output varchar,	-- output message name
	ro_endpoint_uri varchar,-- not used
	ro_style int,		-- messages encoding style : 1 - literal, 0 - RPC like
	ro_action varchar default \'\', -- SOAP Action value
	ro_target_namespace varchar,  -- for RPC encoding the namespace to be used for wrapper elements
	ro_use_wsa int default 0, -- WS-Addressing capabilities flag
	ro_reply_service varchar, -- for one-way operations: reply service name
	ro_reply_port varchar,    -- for one-way operations: reply port type
	primary key (ro_script, ro_partner_link, ro_operation)
)
')
;

-- Operations which process defines (can receive and reply)
exec_no_error ('create table BPEL.BPEL.operation (
	bo_script int,		-- FK reference to bs_id to the script table
	bo_name	varchar,	-- operation name
	bo_action varchar,	-- SOAP Action value
	bo_port_type	varchar,-- port type
	bo_partner_link varchar,-- name of the partner link
	bo_input	varchar,-- input message name
	bo_input_xp	varchar,-- XPath expression to match the input message
	bo_small_input	varchar,-- not used
	bo_output	varchar,-- output message name
	bo_style	int default 0,-- messages encoding style : 1 - literal, 0 - RPC like
	bo_init		int,	-- process instantiation flag: 1 - can make new instances
	primary key (bo_script, bo_name, bo_partner_link)
)')
;

exec_no_error ('create index bo_name on BPEL.BPEL.operation (bo_name)')
;

-- Predefined endpoint URLs for partner links
exec_no_error ('create table BPEL.BPEL.partner_link_conf (
	plc_name	varchar,
	plc_endpoint	varchar,
	primary key (plc_name)
)
')
;

-- Properties
exec_no_error ('create table BPEL.BPEL.property
(
  bpr_script int, 	-- FK reference to bs_id to the script table
  bpr_name varchar,	-- property name
  bpr_type varchar,	-- property type
  primary key (bpr_script, bpr_name)
)
')
;

-- Aliases
exec_no_error ('create table BPEL.BPEL.property_alias (
	pa_script	int,		-- FK reference to bs_id to the script table
	pa_prop_id	int identity,
	pa_prop_name	varchar,	-- property name
	pa_message	varchar,	-- message name
	pa_part		varchar,	-- part name
	pa_query	varchar,	-- XPath query to set the property value
	pa_type		varchar,
	primary key (pa_script, pa_prop_name, pa_message))
')
;

-- Correlation properties
exec_no_error ('create table BPEL.BPEL.correlation_props (
	cpp_id 		int identity (start with 1),
	cpp_script	int,		-- FK reference to bs_id to the script table
	cpp_corr	varchar,	-- correlation name
	cpp_prop_name	varchar,	-- property name
	primary key (cpp_id, cpp_script, cpp_corr, cpp_prop_name))
')
;

-- Variables
exec_no_error ('create table BPEL..variables (
	v_inst 		int,		-- instance id, FK reference bi_id of the instance table
	v_scope_inst   	int,		-- scope instance id; different than 0 for compensation scope
	v_name 		varchar,	-- variable name
	v_type 		varchar,	-- variable type
	v_s1_value	any, 		-- string, numeric
	v_s2_value	varchar, 	-- XML entities
	v_b1_value	long varchar,	-- long strings
	v_b2_value	long varchar, 	-- XML entities
	primary key (v_inst, v_scope_inst, v_name))
')
;

-- Links
exec_no_error ('create table BPEL..links
	(
	  bl_script int,	-- FK reference to bs_id to the script table
	  bl_name   varchar,	-- link name
	  bl_act_id int,	-- corresponding link activity bit number
	  primary key (bl_act_id, bl_script)
	)
')
;

sequence_set ('bpel_scope_id', 1, 1);

-- Compensation scopes
exec_no_error ('create table BPEL..compensation_scope
	(tc_inst int,
	 tc_seq	 int,
	 tc_scope_name varchar default null,
	 tc_scopes long varbinary,
	 tc_head_node int,
	 tc_head_node_bit int,
	 tc_compensating_from int default null,
	 tc_seq_parent	int default null,
	 primary key (tc_inst, tc_seq)
	)
')
;

-- Messages are correlated via WS-Addressing
exec_no_error ('create table BPEL..wsa_messages
	(
	wa_inst int,
	wa_pl	varchar,
	wa_mid  varchar,
	primary key (wa_inst, wa_pl, wa_mid)
	)
')
;

exec_no_error ('create table BPEL..lock
	(
	lck int primary key
	)
')
;

insert soft BPEL..lock (lck) values (1)
;

-- Accepted connections which are waiting for reply
exec_no_error ('create table BPEL..reply_wait
	(
	rw_inst int,
	rw_id int, -- identity (start with 1),
	rw_partner varchar,
	rw_port varchar,
	rw_operation varchar,
	rw_query varchar,
	rw_expect varchar,
	rw_started datetime,
	primary key (rw_inst, rw_id)
	)
')
;

sequence_set ('connection_id', 1, 1);

-- Registered alarm events
exec_no_error ('create table BPEL..time_wait
	(
	  tw_inst 	int,
	  tw_node 	int,
	  tw_scope_inst int,
	  tw_script	varchar,
	  tw_script_id	int,
	  tw_sec  	int,
	  tw_until 	datetime,
	  primary key (tw_inst, tw_node)
	)
')
;

exec_no_error ('create type BPEL..comp_ctx as
	(
	  c_tgtlinks any,
	  c_srclinks any,
	  c_join_cond varchar,
	  c_supp_join varchar,
	  c_current_scope int,
	  c_current_fault int,
	  c_current_fault_bit int,
	  c_enc_scps	any,
          c_internal_id varchar,
	  c_src_line int,
	  c_scopes any,
	  c_event int default 0,
	  c_in_comp int default 0
	)
	self as ref
')
;


exec_no_error ('create type BPEL..ctx as
	(
          c_fault    varchar default null,
	  c_full_err varchar default null,
	  c_comp     int default 0,
	  c_jumps    any,
	  c_flushed  int default 0,
	  c_hdr	     any default null,
	  c_script_id int default null,
	  c_script varchar default null,
	  c_debug int default 0,
	  c_init_oper varchar default null,
	  c_first_node int default 0,
	  c_scope_id int,
	  c_pscope_id int,
	  c_host varchar
	)
       self as ref
')
;

-- BPEL message debugging queue
exec_no_error ('create table BPEL..dbg_message (
	bdm_text long varchar,		-- message text
	bdm_id int identity (start with 1),
	bdm_ts datetime,
	bdm_inout int, 			-- 1 for in, 0 for out
	bdm_sender_inst int, 		-- instance id of sender if outbound message
	bdm_receiver int, 		-- if inbound, inst id of receiving inst
	bdm_plink varchar, 		-- name of partner link in the script in question
	bdm_recipient varchar, 		-- partner link value for outbound message, URL.
	bdm_activity int, 		-- activity id of activity that either sent the message or would receive the message in the sender/receiver instance.
	bdm_oper varchar,		-- operation name
	bdm_script int,			-- process id, FK reference bs_id from script table
	bdm_action varchar,		-- SOAP Action value
	bdm_conn int,			-- client connection id
	primary key (bdm_id)
)
')
;

-- BPEL engine configuration
exec_no_error ('create table BPEL..configuration (
	conf_name	varchar not null,
	conf_desc 	varchar,
	conf_value	any, -- not blob
	conf_long_value	long varchar,
	primary key (conf_name)
)
')
;

exec_no_error ('create trigger dbg_wait_del after delete on BPEL.BPEL.wait {
  delete from BPEL..dbg_message where bdm_sender_inst = bw_instance and bdm_activity = bw_node;
}
')
;

exec_no_error ('create type BPEL.BPEL.partner_link_opts as
	(
	  pl_auth varchar default \'none\',
          pl_keyinst any default null,
	  pl_sec varchar default \'sign\',
	  pl_signature varchar default null,
	  pl_delivery varchar default null,
	  pl_wsa_version varchar default \'http://schemas.xmlsoap.org/ws/2003/03/addressing\',
	  pl_uid varchar default null,
	  pl_pwd varchar default null,
	  pl_in_enc varchar default null,
	  pl_in_sign varchar default null,
	  pl_in_tokens any default null
	)
	self as ref
')
;

exec_no_error ('create table BPEL.BPEL.op_stat
	(
	 bos_process int,
	 bos_plink varchar,
	 bos_op varchar,
	 bos_n_invokes int default 0,
	 bos_n_receives int default 0,
	 bos_cum_wait numeric default 0, -- miliseconds total time wait at the partner link/operation
	 bos_data_in numeric default 0,
	 bos_data_out numeric default 0,
	 bos_n_errors int default 0,
	 primary key (bos_process, bos_plink, bos_op)
)
')
;


exec_no_error ('create table BPEL.BPEL.error_log
	(
	 bel_ts timestamp,
	 bel_seq int identity,
	 bel_level int, -- bel_level is 1. fatal 2. network, 3 instance.
	 bel_notice_sent datetime,  -- time the email was sent, null if none
	 bel_text varchar,
	 primary key (bel_ts, bel_seq)
)
')
;

exec_no_error ('create table BPEL.BPEL.hosted_classes
	(
	 hc_script	int,
	 hc_type	varchar default \'java\',
	 hc_name	varchar,
	 hc_text	long varbinary, -- compiled class
	 hc_path	varchar, -- path to class if it is stored in file system
	 hc_load_method	varchar,
	 primary key (hc_script, hc_type,  hc_name)
)
')
;

