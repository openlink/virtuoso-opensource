--
--  Bpel_interpreter.sql
--
--  $Id$
--
--  BPEL Intrepreter
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

use BPEL;

create procedure BPEL..dbg_printf (in format varchar,
	in x1 any := null,
	in x2 any := null,
	in x3 any := null,
	in x4 any := null,
	in x5 any := null,
	in x6 any := null,
	in x7 any := null
	)
{
	 --dbg_printf (format, x1,x2,x3,x4,x5,x6,x7);
  ;
}
;

create procedure v_bit_print (in mask varbinary, in len int := 30)
{
  declare str varchar;
  declare i, l int;

  --dbg_obj_print (bit_print (mask));
  l := bit_v_count (mask);
  if (len < l)
    len := l;
  str := repeat ('0', l);
  for (i := 0; i < l; i := i + 1)
    {
      if (bit_is_set (mask, i))
        {
          str [l-i-1] := str [l-i-1] + 1;
        }
    }
  return concat (repeat ('0', len-l),str);
}
;


-- this is called when node is going to be stored but not yet,
-- so all in the graph before it are predecesors except branches of the flow.
-- also the CompensationHandler & FaultHandler are not predecessors for any node
create procedure set_predecessor_mask (inout node BPEL.BPEL.node, in is_event int)
{
  declare act BPEL.BPEL.activity;
  declare p_act BPEL.BPEL.activity;
  declare preds varbinary;
  declare p_id int;
  -- selects the immediate predecesor
  declare pr cursor for select bg_activity, bg_node_id from BPEL..graph where bg_script_id = node.bn_script_id
		and ((bg_node_id < node.bn_id and bg_parent = node.bn_parent) or (bg_node_id = node.bn_parent))
		order by bg_node_id desc;
  act := node.bn_activity;
  preds := act.ba_preds_bf;

  whenever not found goto endf;
  open pr (prefetch 1);
  p_act := null;
  while (p_act is null or p_act.ba_type in ('CompensationHandler', 'FaultHandler', 'Link'))
    {
      fetch pr into p_act, p_id;
      if (node.bn_parent_node is not null and node.bn_parent_node.bn_activity.ba_type in ('Flow', 'Pick')
	  and p_id <> node.bn_parent)
        p_act := null;
      else if (is_event and p_id <> node.bn_parent)
	{
	  p_act := null;
	}
      else if (p_act.ba_is_event and p_id <> node.bn_parent)
	{
	  p_act := null;
	}
    }
  preds := bit_set (preds, p_act.ba_id);
  --dbg_obj_print (act.ba_type, act.ba_id, 'parent=', p_id);

  -- XXX: this probably must be done for every predecessor that have children
  if (p_act.ba_type in ('Flow', 'Sequence', 'Scope', 'While', 'Switch', 'Pick') and p_id <> node.bn_parent)
    {
       for select bg_activity from BPEL..graph where bg_script_id = node.bn_script_id
		and bg_node_id > p_id and bg_node_id < node.bn_id do
          {
            p_act := bg_activity;
	    if (p_act.ba_type not in ('CompensationHandler', 'FaultHandler', 'Link') and not p_act.ba_is_event)
	      {
		--dbg_obj_print ('more preds=', p_act.ba_type, p_act.ba_id);
                preds := bit_set (preds, p_act.ba_id);
	      }
          }
    }

  act.ba_preds_bf := preds;
  node.bn_activity := act;
  endf:
   close pr;
  return;
}
;


create procedure BPEL..zero_mask (in bit_no int)
{
  if (bit_no = 0)
    return cast (repeat ('\x0',2) as varbinary);
  return bit_clear (bit_set (cast (repeat ('\x0', 2) as varbinary), bit_no-1), bit_no-1);
}
;

create procedure set_init_mask (inout node BPEL.BPEL.node, in nodes_cnt int)
{
  declare act BPEL.BPEL.activity;
  declare mask varbinary;

  act := node.bn_activity;
  if (not act.ba_type in ('While', 'CompensationHandler', 'FaultHandler', 'Case', 'Otherwise', 'Catch', 'Scope','onMessage', 'onAlarm'))
    return;
  --mask := cast (repeat ('\x0', nodes_cnt + 1) as varbinary);
  mask := BPEL..zero_mask (nodes_cnt+1);
  mask := v_bit_or (act.ba_init_bf, mask);
  for select bg_activity, bg_node_id from BPEL..graph where bg_parent = node.bn_id do
    {
       declare p_act BPEL.BPEL.activity;
       p_act := bg_activity;
       mask := bit_set (mask, p_act.ba_id);
       BPEL..set_init_chil_mask	(mask, bg_node_id);
    }
  act.ba_init_bf := v_bit_not (mask);
  node.bn_activity := act;
}
;

create procedure set_init_chil_mask (inout mask varbinary, in node_id int)
{
  for select bg_activity, bg_node_id from BPEL..graph where bg_parent = node_id do
     {
	declare p_act BPEL.BPEL.activity;
	p_act := bg_activity;
	mask := bit_set (mask, p_act.ba_id);
	BPEL..set_init_chil_mask (mask, bg_node_id);
     }
}
;


create procedure set_pickup_mask (inout node BPEL.BPEL.node, inout pmask varbinary, inout targets any, in is_event int)
{
  declare act BPEL.BPEL.activity;

  act := node.bn_activity;

  -- activity with many links going to it is a pickup point too
  if (length (targets) > 0 or is_event)
    pmask := bit_set (pmask, act.ba_id);

  if (not act.ba_type in ('Flow', 'Pick'))
    return;

  for select bg_activity, bg_node_id from BPEL..graph where bg_parent = node.bn_id do
    {
       declare p_act BPEL.BPEL.activity;
       p_act := bg_activity;
       if (p_act.ba_type <> 'Link')
         pmask := bit_set (pmask, p_act.ba_id);
    }
}
;

-- XXX: important, make this
create procedure set_links (inout node BPEL.BPEL.node)
{
  declare act BPEL.BPEL.activity;

  act := node.bn_activity;
  if (act.ba_type = 'Link')
    {
      declare lnk BPEL..link;
      lnk := act;
      insert into BPEL..links (bl_script, bl_name, bl_act_id) values (node.bn_script_id, lnk.ba_name, act.ba_id);
    }
  else
    {
      declare i, l int;
      declare tmp any;
      declare exit handler for not found { signal ('22023', 'No such link'); };
      tmp := make_array (length (act.ba_src_links), 'any');
      for (i := 0; i < length (act.ba_src_links); i := i + 2)
         {
	   declare lnk varchar;
           declare lnk_id int;

           declare cr cursor for select bl_act_id from BPEL..links where bl_script = node.bn_script_id and
		bl_name = lnk order by bl_act_id desc;
	   lnk := act.ba_src_links[i];
	   open cr (prefetch 1);
	   fetch cr into lnk_id;
	   close cr;
           tmp [i] := lnk_id;
           tmp [i+1] := case when length (act.ba_src_links[i+1]) then decode_base64(act.ba_src_links[i+1])
			else 'true()' end;
         }
      act.ba_src_links := tmp;
      tmp := make_array (length (act.ba_tgt_links), 'any');
      for (i := 0; i < length (act.ba_tgt_links); i := i + 1)
         {
	   declare lnk varchar;
           declare lnk_id int;

           declare cr cursor for select bl_act_id from BPEL..links where bl_script = node.bn_script_id and
		bl_name = lnk order by bl_act_id desc;
	   lnk := act.ba_tgt_links[i];
	   open cr (prefetch 1);
	   fetch cr into lnk_id;
	   close cr;
           tmp [i] := lnk_id;
         }
      act.ba_tgt_links := tmp;
      node.bn_activity := act;
    }
  return;
}
;

create procedure set_successors (in scp int)
{
  for select bg_activity, bg_node_id as node_id from graph where bg_script_id = scp order by bg_node_id do
   {
     declare act activity;
     declare succ any;

     act := bg_activity;
     succ := vector ();

     for select bg_activity as bg_activity1 from graph as graph1 where bg_script_id = scp
	and bg_node_id <> node_id order by bg_node_id do
        {
          declare act1 activity;
          act1 := bg_activity1;
	  if (bit_is_set (act1.ba_preds_bf, act.ba_id) and act1.ba_type <> 'Link')
            {
              --dbg_obj_print ('successor of=', act1.ba_id, ' ty=', act.ba_type, ' is=', act1.ba_id, ' ty=', act1.ba_type);
	      succ := vector_concat (succ, vector (act1.ba_id));
	    }
	}
      --dbg_obj_print ('for: ', act.ba_id, ' ',act.ba_type, succ);
      act.ba_succ := succ;
      update graph set bg_activity = act where bg_script_id = scp and bg_node_id = node_id;
   }
}
;


create procedure run (in scp_id varchar, in args any, in hdr any, in oper varchar, in host varchar)
{
  declare inst, scp_uri, first_node, rc, dbg, step_mode int;
  declare pmask, zmask varbinary;
  declare bpel_nm varchar;
  declare xmlnss_pre varchar;
  declare scps any;
  declare url any;

  declare cr cursor for select bg_node_id from BPEL..graph where bg_script_id = scp_id
	order by bg_script_id, bg_node_id asc;

  scp_uri := null;
  whenever not found goto err_ret;
  select bs_name, bs_pickup_bf, bs_debug, bs_name, bs_scopes, bs_step_mode, bs_uri
      into scp_uri, pmask, dbg, bpel_nm, scps, step_mode, url
      from BPEL..script where bs_id = scp_id with (prefetch 1);
  select bsrc_temp into xmlnss_pre from BPEL..script, BPEL..script_source where bsrc_script_id = scp_id and bsrc_role = 'bpel-exp';
  open cr (prefetch 1);
  fetch cr into first_node;
  close cr;
  commit work;
  declare deadlock_count int;
  deadlock_count := BPEL..max_deadlock_cnt ();
  declare exit handler for sqlstate '40001' {
    rollback work;
    --dbg_obj_print (__SQL_MESSAGE);
    --dbg_printf ('Deadlock catched in "run" inst=%d', inst);
    if (deadlock_count > 0)
      {
	BPEL..add_audit_entry (inst, -11, sprintf ('Deadlock catched in "run": %s, retrying...', __SQL_MESSAGE));
	delay (BPEL..deadlock_delay());
	 --dbg_printf ('Deadock ..resume %d', deadlock_count);
	deadlock_count := deadlock_count - 1;
	goto again;
      }
    BPEL..add_audit_entry (inst, -11, sprintf ('Deadlock catched in "run": %s, resignal', __SQL_MESSAGE));
    --dbg_printf ('Deadlock retry maximum count inst=%d', inst);
    signal ('BPELZ', 'Deadlock retry maximum count reached.');
  };
 again:

  -- initialize a new instance; activities & link bf are zero
--  zmask := cast (repeat ('\x0', length (pmask)) as varbinary);
  zmask := BPEL..zero_mask ((length (pmask)-2)*8 + aref (cast (pmask as varchar), 0));
  insert into BPEL.BPEL.instance (bi_script, bi_state, bi_started, bi_activities_bf, bi_link_status_bf, bi_wsa, bi_prefix_info, bi_init_oper, bi_scopes, bi_comp_stack, bi_host)
  values (scp_id, -1, now (), zmask, zmask, hdr, xmlnss_pre, oper, scps, vector (), host);
  inst := identity_value ();
  if (connection_get ('BPEL_audit') = 1)
    BPEL..delete_audit (inst, bpel_nm);

  --dbg_obj_print ('Instance started inst=', inst);
  --insert into BPEL.BPEL.scopes values (inst, first_node, -1);

  connection_set ('BPEL_script_id', scp_id);
  connection_set ('BPEL/Script', scp_uri);
  connection_set ('BPEL/ScriptUrl', url);
  BPEL..set_io_request (inst, args);

  -- there result is same as in bi_state of that instance
  declare exit handler for sqlstate '*' {
    BPEL..add_audit_entry (inst, -11, sprintf ('catched in BPEL..run: %s', __SQL_MESSAGE));
  };
  rc := process_nodes (scp_id, inst, 0, first_node, pmask, first_node, dbg, step_mode);

  return inst;
err_ret:
  if (scp_uri is not null)
    close cr;
  signal ('22023', 'No such process');
}
;

create procedure resume (in inst int, in scp_id varchar, in args any := null, in wnode int := 0, in scp_inst int := 0)
{
  declare first_node, node, i, l, rc, audit, dbg, stat, step_mode int;
  declare pmask, zmask varbinary;
  declare scp_uri, url varchar;

  whenever not found goto err_ret;

  select bs_name, bs_pickup_bf, bs_first_node_id, bs_audit, bs_debug, bs_step_mode, bs_uri
      	into scp_uri, pmask, first_node, audit, dbg, step_mode, url
	from BPEL..script where bs_id = scp_id with (prefetch 1);
  stat := BPEL..get_conf_param ('Statistics', 0);

  commit work;
  declare deadlock_count int;
  deadlock_count := BPEL..max_deadlock_cnt ();
  declare exit handler for sqlstate '40001' {
    rollback work;
    if (deadlock_count > 0)
      {
	BPEL..add_audit_entry (inst, -11, sprintf ('Deadlock catched in BPEL..resume: %s, retrying...', __SQL_MESSAGE));
	delay (BPEL..deadlock_delay());
	 --dbg_printf ('Deadock ..resume %d', deadlock_count);
	deadlock_count := deadlock_count - 1;
	goto again2;
      }
    BPEL..add_audit_entry (inst, -11, sprintf ('Deadlock catched in BPEL..resume: %s, resignal', __SQL_MESSAGE));
    signal ('BPELZ', 'Deadlock retry maximum count reached.');
  };
 again2:

  connection_set ('BPEL_script_id', scp_id);
  connection_set ('BPEL/Script', scp_uri);
  connection_set ('BPEL_audit', audit);
  connection_set ('BPEL/ScriptUrl', url);
  declare exit handler for sqlstate '*' {
    BPEL..add_audit_entry (inst, -11, sprintf ('catched in BPEL..resume: %s', __SQL_MESSAGE));
  };
  if (stat)
    connection_set ('BPEL_stat', 1);
  if (args is not null)
    BPEL..set_io_request (inst, args);

  if (wnode > 0) -- there is a node to resume comming from outside
    {
      rc := process_nodes (scp_id, inst, scp_inst, wnode, pmask, first_node, dbg, step_mode);
      if (rc = 0 or rc = 2 or rc = 3) -- instance is running
	{
           --dbg_obj_print ('completed rc=',rc,' inst=',inst,' node=',wnode);
          return rc;
        }
    }

   --dbg_obj_print ('resume finished inst=',inst,' node=',wnode);

  return rc;

err_ret:
  signal ('22023', 'No such process');
}
;

create procedure get_scope_id (inout act BPEL.BPEL.activity, inout scps any, inout cstack any, in scope_inst int, inout ctx BPEL..ctx)
{
  declare pos, lscp int;

  if (scope_inst > 0)
    {
      ctx.c_scope_id := cstack[0][0];
      ctx.c_pscope_id := cstack[0][2];
      return;
    }

  pos := act.ba_scope_idx;
  if (pos > 0)
    {
      ctx.c_scope_id := scps[pos];
      ctx.c_pscope_id := 0;
      if (act.ba_pscope_idx > 0)
	{
	  ctx.c_pscope_id := scps [act.ba_pscope_idx];
	}
      return;
    }
  signal ('42000', sprintf ('Non-existing scope id=%d', act.ba_scope));
}
;

create procedure set_scope_id (inout act BPEL.BPEL.activity, inout scps any, inout ctx BPEL..ctx)
{
  declare pos int;
  pos := act.ba_scope_idx;
  if (pos > 0)
    {
      scps[pos] := ctx.c_scope_id;
      return;
    }
  signal ('42000', sprintf ('Non-existing scope id=%d', act.ba_scope));
}
;

create procedure get_node_todo (in inst int, in node int, in activs any, inout links any, in pmask varbinary, in first_node int, in scp_inst int)
{
  declare wtnode, node_id, from_comp int;
  declare wt cursor for select bw_node, bw_from_comp from BPEL.BPEL.wait
	where bw_instance = inst and bw_state = 1;
  -- get from wait if can
  node_id := -1;
  wtnode := 0;
  whenever not found goto nwait;
  open wt (prefetch 1, exclusive);
  fetch wt into wtnode, from_comp;
  --if ((scp_inst > 0 and from_comp = 0) or (scp_inst = 0 and from_comp > 0))
  --  {
  --    dbg_obj_print ('skipping a wait..', wtnode);
  --  }
  nwait:
  close wt;
  if (wtnode > 0 and ((scp_inst = 0 and from_comp = 0) or (scp_inst > 0 and from_comp > 0)))
    {
      node_id := wtnode;
      links := bit_clear (links, (wtnode - first_node) + 1);
       --dbg_obj_print ('*** found a wait node:', wtnode);
    }
  else
  -- get pickup point
    {
      declare i, l int;
       --dbg_obj_print ('pmask tst:', bit_print (pmask));
      l := bit_v_count (pmask); --(length (pmask)-2)*8 + aref (cast (pmask as varchar), 0);
      for (i := 0; i < l; i := i + 1)
	 {
	   --dbg_obj_print ('bit', i, ' stat=', bit_is_set (pmask, i));
	   if (bit_is_set (pmask, i) and not bit_is_set (activs, i) and not bit_is_set (links, i))
	     {
	       node_id := first_node + i - 1; -- the bits are plus one
	       if (node_id <= node) -- just in case where we trying to get something but we go to same point
                 node_id := -1;
	       else
	         goto retu;
	       --dbg_obj_print ('*** pickup:', node_id);
	     }
	 }
    }
retu:
  -- goto a sleep
  --dbg_obj_print ('get_node', node_id);
  return node_id;
}
;

create procedure process_nodes (in scp_id int, in inst int, in scope_inst int, in node_id int,
				in pmask any, in first_node int, in dbg int, in step_mode int := 0)
{
  declare act BPEL.BPEL.activity;
  declare nxt_node, stat, rc, current_node, link_state, link_cond, node_cnt, retry, deadlock_cnt int;
  declare preds, activs, links varbinary;
  declare gen_err, pname, oper, host varchar;
  declare fault_err_vec, hdr, scps, cstack any;
  declare ctx BPEL..ctx;
  declare started datetime;
  declare xmlnss_pre varchar;

  declare cr cursor for select bg_activity from BPEL..graph where bg_script_id = scp_id
    and bg_node_id = node_id;
  --declare cr_cnt cursor for select bs_act_num from BPEL.BPEL.script where bs_id = scp_id;
  declare ins cursor for select bi_state, bi_activities_bf, bi_link_status_bf, bi_wsa,
  	bi_started, bi_prefix_info, bi_init_oper, bi_scopes, bi_comp_stack, bi_host
	from BPEL.BPEL.instance where bi_id = inst;
  --set isolation='committed';
   --dbg_printf ('> process_nodes inst=%d, node_id=%d', inst, node_id);

  -- XXX: this is to use specific process function
  --pname := sprintf ('BPEL.BPEL.proc_%d', scp_id);
  --if (__proc_exists (pname))
  --  {
  --    stat := call (pname) (inst, node_id, scope_inst);
  --    return stat;
  --  }

  ctx := new BPEL..ctx ();
  current_node := node_id;
  gen_err := null;
  whenever not found goto notf;

  --open cr_cnt;
  --fetch cr_cnt into noe_cnt;
  --close cr_cnt;

  open ins (exclusive, prefetch 1);
  fetch ins into stat, activs, links, hdr, started, xmlnss_pre, oper, scps, cstack, host;

   --dbg_printf ('> got exclusive read on inst=%d, node_id=%d stat=%d', inst, node_id,stat);
   --dbg_printf ('> %s',bit_print ( activs));

  retry := 0;

  if (stat = 1 or stat = -1 or stat = 4) -- suspended or new one
    update BPEL.BPEL.instance set bi_state = 0 where current of ins;
  else if (stat = 0) -- instance is alredy running , just exit
    goto notfx;
  else		     -- any other state
    goto notfx;

  -- this needs for BPEL XPath function extensions
  connection_set ('BPEL_inst', inst);
  ctx.c_hdr := hdr;
  ctx.c_debug := dbg;
  ctx.c_script_id := scp_id;
  ctx.c_init_oper := oper;
  ctx.c_script := connection_get ('BPEL/Script');
  ctx.c_first_node := first_node;
  ctx.c_host := host;

  -- restarted in the middle of compensation
  if (length (cstack) > 0)
    {
      scope_inst := cstack[0][0];
      node_id := cstack[0][1];
      current_node := node_id;
      --dbg_obj_print ('resuming from cmpensation:', current_node, scope_inst);
    }

  -- * must not catch 40001
  declare exit handler for sqlstate '40001' {
    resignal;
  };

  declare exit handler for sqlstate '*' {
    BPEL..add_audit_entry (inst, -13, sprintf ('%s %s', __SQL_STATE, __SQL_MESSAGE));
    rollback work;
    gen_err := __SQL_MESSAGE;
    goto notfn;
  };

  while (1)
    {
      deadlock_cnt := 0;
      {
        declare exit handler for not found {
		close cr;
		goto notfn;
	 };
        open cr (prefetch 1);
        fetch cr into act;
        close cr;
      }
      -- save the current node
      current_node := node_id;
      rc := 0;
      -- check the activity mask
      if (bit_is_set (activs, act.ba_id) or bit_is_set (links, act.ba_id))
	{
	  --dbg_printf ('> Already done: %d %s', act.ba_id, act.ba_type);
          goto next_node;
	}
      else


      -- check the predecessor
      if (not v_equal (act.ba_preds_bf, v_bit_and (activs, act.ba_preds_bf)))
	{
	  --dbg_printf ('> Predecessor is not done: %d %s scp_inst=%d', act.ba_id, act.ba_type, scope_inst);
	  node_id := get_node_todo (inst, current_node, activs, links, pmask, first_node, scope_inst);
          if (node_id < 0)
            goto notfn;
          goto next_node;
	}


      if (v_true (act.ba_init_bf)) -- if the activity have a init mask
        {
           -- XXX: make sure ba_init_bf len is = activs !!!
           activs := v_bit_and (activs, act.ba_init_bf);
	   --dbg_obj_print (act.ba_id, 'resetting mask', v_bit_print (activs));
           links := v_bit_and (links, act.ba_init_bf);
        }

      -- evaluate the node; here we doing all the things for given activity
      -- proceeed all link conditions if any
      -- this is needed to know where is the variable in the XPath functions
      connection_set ('BPEL_scope', act.ba_scope);
      connection_set ('BPEL_scope_inst', scope_inst);
      connection_set ('BPEL_xmlnss_pre', xmlnss_pre);

      --
      -- check target link conditions
      --
      if (length (act.ba_tgt_links))
	{
          link_state := 0;
	  link_cond := 1;
	  foreach (int lnk_id in act.ba_tgt_links) do
	    {
	      if (bit_is_set (links, lnk_id))
		{
		  link_state := 1;
		}
	      if (not bit_is_set (activs, lnk_id))
		{
		  link_cond := 0;
                }
	    }
          -- not all links are ready
	  if (not link_cond)
            {
	      --dbg_obj_print ('Not all target links are ready');
	      node_id := get_node_todo (inst, current_node, activs, links, pmask, first_node, scope_inst);
	      if (node_id < 0)
		goto notfn;
	      goto next_node;
	    }
	  if (act.ba_join_cond is not null)
	    link_state := BPEL..xpath_evaluate0 (act.ba_join_cond);
        }
      else
        link_state := 1;

      -- Not retriable
      declare exit handler for sqlstate 'BPELZ'
	{
	  BPEL..add_audit_entry (inst, -11, sprintf ('Deadlock, %s, max retry count exceeded. Abort', __SQL_MESSAGE));
	  BPEL..send_error_mail (inst, __SQL_STATE, __SQL_MESSAGE);
	  activs := v_bit_all_neg (activs);
	  goto notfn;
	};
      -- Retriable errors
      declare exit handler for sqlstate 'BPELR'
        {
	  gen_err := ctx.c_full_err;
	  if (gen_err is null)
	    BPEL..add_audit_entry (inst, -12, 'BPELR');
	  else
	    BPEL..add_audit_entry (inst, -12, gen_err);
	  retry := 1;
	  goto notfn;
	};
      -- fault handlers start from here
      -- find the handler and goto in it
      declare exit handler for sqlstate 'BPELX'
	{
	  declare err varchar;
	  err := regexp_match ('[^\r\n]*', __SQL_MESSAGE);
           --dbg_obj_print ('exception was thrown:', err, act.ba_fault_hdl);
	  BPEL..add_audit_entry (inst, -11, err);
          if (act.ba_fault_hdl > 0)
            {
	      declare sc, fh BPEL..activity;
	      declare rev varbinary;
	      ctx.c_fault := BPEL.BPEL.get_nc_name (err);
              -- mark all inside scope as done
	      node_id := act.ba_scope;
              open cr (prefetch 1);
	      fetch cr into sc;
	      close cr;
	      node_id := act.ba_fault_hdl;
              open cr (prefetch 1);
	      fetch cr into fh;
	      close cr;

	      -- mark current node
	      activs := bit_set (activs, act.ba_id);

	      -- mark all inside scope as known/false
	      rev := v_bit_not (sc.ba_init_bf);
              activs := v_bit_or (activs, rev);
	      links := v_bit_and (links, sc.ba_init_bf);
	      remove_waits (sc, inst, ctx);

	      -- mark fault handler as known/true
	      links := bit_set (links, fh.ba_id);

	      -- mark all under handler as unknown/false
	      activs := v_bit_and (activs, fh.ba_init_bf);
	      links := v_bit_and (links, fh.ba_init_bf);


	      -- goto the handler head node
	      node_id := act.ba_fault_hdl;
              BPEL..set_var (sprintf ('@fault-%d', fh.ba_fault_hdl), inst, act.ba_scope, ctx.c_fault, 0);

	      if (ctx.c_fault like '%communicationFault')
	        connection_set ('BPEL_invoke_id', act.ba_id);
	      goto mark_current_and_go;
            }
          else
            {
	      rollback work;
	      gen_err := __SQL_MESSAGE;
	      --dbg_obj_print ('gen_err:', gen_err);
	      goto notfn;
            }
            -- was resignal,but this seems go over the procedure;
	};
again:
       --dbg_printf ('< 11');

      if (not link_state)
	{
	  if (act.ba_suppress_join_fail)
	    {
	      goto mark_current_and_go;
	    }
	  else
	    {
	      signal('BPELX', 'bpws:joinFailure');
	    }
	}
      -- handlers have to be at the beggining of scope or at least at point wwhere
      -- they have to catch erorr
      -- there is a commit inside invoke etc. this will resignal to outer scope
      declare deadlock_count int;
      deadlock_count := BPEL..max_deadlock_cnt ();
      declare exit handler for sqlstate '40001' {
	rollback work;
	--dbg_printf ('Deadlock catched in "process_node": inst=%d node=%d', inst, current_node);
	if (deadlock_count > 0)
	  {
	    BPEL..add_audit_entry (inst, -11, sprintf ('Deadlock catched in "process_node": %s, retrying...', __SQL_MESSAGE));
	    delay (BPEL..deadlock_delay());
	     --dbg_printf ('Deadock ..resume %d', deadlock_count);
	    deadlock_count := deadlock_count - 1;
            -- tell interpreter to do the item again
	    current_node := -1;
	    goto again2;
	  }
	BPEL..add_audit_entry (inst, -11, sprintf ('Deadlock catched in "process_node": %s, resignal', __SQL_MESSAGE));
	signal ('BPELZ', 'Deadlock retry maximum count reached.');
      };

      get_scope_id (act, scps, cstack, scope_inst, ctx);
      --dbg_printf ('> %02d %10.10s [%s]', act.ba_id, act.ba_type, bit_print (activs));
      --dbg_printf ('> scp=%d %02d %25.25s', scope_inst, act.ba_id, act.ba_type);
      if (0 < (rc := act.eval (inst, scope_inst, node_id, activs, links, cstack, ctx)))
        {
          declare i, l int;
          activs := bit_set (activs, act.ba_id);
          links := bit_set (links, act.ba_id);
          l := length (act.ba_src_links);
	  -- go over all links that are sources
          for (i := 0; i < l; i := i + 2)
            {
	      declare lnk_id int;
	      declare cond varchar;

	      lnk_id := act.ba_src_links[i];
	      cond := act.ba_src_links[i+1];
	      -- evaluate condition to set transition flag
	      if (BPEL..xpath_evaluate0 (cond))
	        links := bit_set (links, lnk_id);
              else
                links := bit_clear (links, lnk_id);
              -- in either cases set link activity executed flag on
	      --dbg_obj_print ('setting inst=',inst,' link=', lnk_id, ' node=', current_node);
              activs := bit_set (activs, lnk_id);
            }
        }
       --dbg_printf ('< rc = %d', rc);
  mark_current_and_go:
       --dbg_printf ('< %02d %10.10s [%s]', act.ba_id, act.ba_type, bit_print (activs));
      if (scope_inst = 0)
        set_scope_id (act, scps, ctx);
      fault_err_vec := BPEL..make_error ('BPELX', ctx.c_fault); -- compiler f@ here
      update BPEL.BPEL.instance set bi_activities_bf = activs, bi_link_status_bf = links,
				    bi_error = fault_err_vec, bi_scopes = scps, bi_comp_stack = cstack
	    where current of ins;
      --dbg_obj_print ('RC3:', row_count());
      --dbg_printf ('< %02d %10.10s [%s]', act.ba_id, act.ba_type, bit_print (activs));
      -- XXX: check this creafully !!!
      close ins;
      commit work;

      if (act.ba_type = 'serverFailure' or (step_mode > 0 and rc > 0))
	{
	  declare acopy varbinary;
	  declare sync_init_wait int;
	  acopy := activs;
	  acopy := bit_set (acopy, 0);
	  sync_init_wait := coalesce (connection_get ('BPEL_reply_sent'), 0);
	  --dbg_obj_print (sync_init_wait);
	  if (not all_bits_set (acopy) and sync_init_wait = 0)
	    {
	      --dbg_obj_print ('stopping at:', act.ba_type, act.ba_id, v_bit_print (activs));
	      return 0;
	    }
	}

    again2:

      open ins (exclusive, prefetch 1);
      fetch ins into stat, activs, links, hdr, started, xmlnss_pre, oper, scps, cstack, host;
       --dbg_printf ('< 2');

      next_node:;
      -- in any case we clear the activity/s bit in pickup mask
      pmask := bit_clear (pmask, act.ba_id);
      --dbg_obj_print ('pmask clr:', bit_print (pmask));
      -- if node is changed do not touch it
      if (node_id = current_node)
	{
          node_id := node_id + 1;
          --dbg_obj_print ('Next node:', node_id, ' successors=', act.ba_succ);
        }
       --dbg_printf ('< 3');
    }

    --dbg_obj_print ('fin');
notfn:
    --dbg_obj_print ('notfn');

  whenever sqlstate '*' default;
  whenever sqlstate '40001' default;
  whenever sqlstate 'BPELR' default;
  whenever sqlstate 'BPELZ' default;
  whenever sqlstate 'BPELX' default;


  --dbg_obj_print ('gen_err:', gen_err);
  check_inst_state (scp_id, inst, activs, started, gen_err, stat, retry);
  --dbg_obj_print ('activs:', bit_print (activs), stat)	;

  update BPEL.BPEL.instance set bi_state = stat, bi_error = BPEL..make_error ('BPELX', gen_err), bi_last_act = now ()
	where current of ins;
  if (retry = 1)
    {
      update BPEL.BPEL.instance set bi_activities_bf = connection_get ('BPEL_activs')
	where current of ins;
    }
notfx:

  close ins;
  --dbg_printf ('finished exec round inst=%d', inst);
  return stat;

notf:
  close ins;
  signal ('22023', sprintf ('No such instance id=[%d]', inst));
  return;
}
;

-- changed from {inout gen_err} to {in gen_err} since it passed
-- the NULL instead of error string.
-- can not reproduce with other procedures.
-- Ruslan
create procedure check_inst_state (in scp_id int, in inst int, inout activs any, inout started any, in gen_err any, inout stat int, inout retry int)
{
  -- the last bit is reserved, so here we prematurely set it to 1
  activs := bit_set (activs, 0);
  --dbg_obj_print ('gen_err2:', gen_err, ':', __SQL_MESSAGE);
  if (all_bits_set (activs))
    {
      stat := 2; -- finished

      if (connection_get ('BPEL_stat') is not null)
	{
	  declare cr cursor for select bs_n_completed, bs_cum_wait from BPEL.BPEL.script where bs_id = scp_id;
	  declare n_com, m_wait int;
	  open cr (exclusive,  prefetch 1);
	  fetch cr into n_com, m_wait;
	  update BPEL.BPEL.script set bs_n_completed = n_com + 1, bs_cum_wait = m_wait + datediff ('millisecond', started, now()) where current of cr;
	  close cr;
	}
      delete from BPEL..variables where v_inst = inst and (v_scope_inst <> 0 or v_name = '@request@' or v_name = '@result@');
      BPEL..add_audit_entry (inst, -2, '');
    }
  else if (gen_err is not null)
    {
      BPEL..stat_inc_errors (inst, scp_id);
      --dbg_obj_print ('Error:', __SQL_STATE, gen_err);
      BPEL..log_error (__SQL_STATE, gen_err);
      if (retry = 0)
	{
	  delete from BPEL..wait where bw_instance = inst;
	  stat := 3; -- general error
	  for select rw_id from reply_wait where rw_inst = inst do
	    {
	      declare s, fault any;
	      fault := soap_make_error ('300', '42000', gen_err);
	      --dbg_obj_print ('error: Recall session', rw_id, gen_err);
	      s := http_recall_session (rw_id);
	      reply_fault_to_client (s, fault);
	    }
	  delete from reply_wait where rw_inst = inst;
	  delete from BPEL..variables where v_inst = inst and (v_scope_inst <> 0 or v_name = '@request@' or v_name = '@result@');
	}
      else
	{
	  stat := 4; -- freezed until explicit restart
	  for select rw_id from reply_wait where rw_inst = inst do
	    {
	      declare s, fault any;
	      if (isentity (gen_err))
	        fault := soap_make_error ('300', '42000', serialize_to_UTF8_xml (gen_err));
	      else
	        fault := soap_make_error ('300', '42000', gen_err);
	      s := http_recall_session (rw_id);
	      reply_fault_to_client (s, fault);
	    }
	  delete from reply_wait where rw_inst = inst;
	}
    }
  else
    stat := 1; -- suspended
}
;

create procedure remove_waits (inout sc BPEL.BPEL.activity, in inst int, inout ctx BPEL..ctx)
{
  declare i, l, node int;
  declare imask varbinary;

  imask := sc.ba_init_bf;
  i := 0;
  l := bit_v_count (imask);
  for (i := 0; i < l; i := i + 1)
    {
      if (not bit_is_set (imask, i))
	{
	  node := ctx.c_first_node + i - 1;
	  delete from BPEL..wait where bw_instance = inst and bw_node = node;
	  delete from BPEL..time_wait where tw_inst = inst and tw_node = node;
	}
    }
}
;

--
-- activity evaluation:
-- returns : 1 - completed, 0 - not completed
-- special case is jump which returns head node of the
-- loop
--

-- default for generic activity
create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.activity
{
  BPEL..dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  self.add_audit_entry (inst, node, '');
  return 1;
}
;

-- wait N seconds
create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.wait
{
  BPEL..dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  self.add_audit_entry (inst, node, sprintf ('wait for %d seconds', self.ba_seconds));
  commit work; -- release the locks
  if (self.ba_seconds <> 0)
    delay (self.ba_seconds);
  return 1;
}
;

-- executes a procedure accepting instance & node
create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.sql_exec
{
  BPEL..dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  self.add_audit_entry (inst, node, self.ba_sql_text);
  call (self.ba_proc_name) (inst, node);
  return 1;
}
;

-- call java method
create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.java_exec
{
  declare new_vars varchar;
  BPEL..dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  self.add_audit_entry (inst, node, self.ba_class_name);
--dbg_printf ('old_vars: %s', cast (BPEL..dump_inst_vars (inst, self.ba_scope, scp_inst) as varchar));
 whenever sqlstate '42000' goto err;
  new_vars := java_call_method (self.ba_class_name,
	java_new_object (self.ba_class_name,
			 BPEL..dump_inst_vars (inst, self.ba_scope, scp_inst),
			 connection_get ('BPEL_xmlnss_pre')),
	'bpel_eval',
	'Ljava/lang/String;');
--dbg_printf ('new_vars: %s', cast (new_vars as varchar));
  BPEL..rest_inst_vars (inst, self.ba_scope, scp_inst, new_vars);
  return 1;
 err:
  ctx.c_full_err := BPEL..make_java_error(__SQL_STATE, __SQL_MESSAGE);
  signal ('BPELX', 'bpws:javaFault');
}
;

-- call CLR method
create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.clr_exec
{
  declare new_vars varchar;
  BPEL..dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  self.add_audit_entry (inst, node, self.ba_class_name);
  whenever sqlstate '42000' goto err;
-- dbg_printf ('old_vars: %s', cast (BPEL..dump_inst_vars (inst, self.ba_scope, scp_inst) as varchar));
  declare descs, rows any;
  -- trick.. need procedure for creating new instances by name... like "CALL" for functions
  EXEC ('select (new "DB"."DBA"."' || self.ba_class_name || '"(?,?)).bpel_eval()', null,null,
	vector (connection_get ('BPEL_xmlnss_pre'),
		BPEL..dump_inst_vars (inst, self.ba_scope, scp_inst)),
	1,
	descs,
	rows);
  new_vars := aref( aref( rows, 0), 0);
--  dbg_printf ('new_vars: %s', cast (new_vars as varchar));
  BPEL..rest_inst_vars (inst, self.ba_scope, scp_inst, cast (new_vars as varchar));
  return 1;
err:
  ctx.c_full_err := BPEL..make_clr_error(__SQL_STATE, __SQL_MESSAGE);
  signal ('BPELX', 'bpws:clrFault');
}
;


-- just head node & do nothing for now
create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.switch
{
  BPEL..dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  self.add_audit_entry (inst, node, '');
  return 1;
}
;

-- returns 1 always
create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.case1
{
  declare _res integer;
  declare other BPEL..activity;
  set isolation='committed';
  declare cr cursor for select bg_activity from BPEL..graph where bg_parent = self.ba_parent_id
	and bg_node_id <> node;
  BPEL..dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  _res := BPEL.BPEL.xpath_evaluate0 (self.ba_condition);
  if (_res > 0)
    {
      self.add_audit_entry (inst, node, sprintf ('%s == true', self.ba_condition));
      whenever not found goto alldone;
      open cr;
      while (1)
        {
	  fetch cr into other;
          amask := v_bit_or (amask, v_bit_not (other.ba_init_bf));
	  amask := bit_set (amask, other.ba_id);
	}
      close cr;
      alldone:
      return 1;
    }
  self.add_audit_entry (inst, node, sprintf ('%s == false', self.ba_condition));
  -- if false then all descendants are like executed
  amask := v_bit_or (amask, v_bit_not (self.ba_init_bf));
  return 1;
}
;

-- if this is not alredy done evaluate it.
create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.otherwise
{
  self.add_audit_entry (inst, node, '');
  BPEL..dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  return 1;
}
;

create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.while_st
{
  declare res any;
  BPEL..dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  -- if expression is false make all children as executed
  res := BPEL.BPEL.xpath_evaluate0 (self.ba_condition);
  if (not res or res is null)
    {
      self.add_audit_entry (inst, node, sprintf ('%s = false', self.ba_condition));
      declare rev_init varbinary;
      rev_init := v_bit_not (self.ba_init_bf);
      amask := v_bit_or (amask, rev_init);
    }
  else
    self.add_audit_entry (inst, node, sprintf ('%s = true', self.ba_condition));
  return 1;
}
;

create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.assign
{
  BPEL..dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  declare f any;
  --dbg_obj_print (self.ba_from,  self.ba_to);
  f := self.ba_from.get_value (inst, self.ba_scope, scp_inst);
  --dbg_obj_print ('self.ba_from:', self.ba_from);
  --dbg_obj_print ('self.ba_to:', self.ba_to);
  --dbg_obj_print ('from:', f);
  if (connection_get ('BPEL_audit') = 1)
    {
      self.add_audit_entry (inst, node, sprintf ('From %s', self.ba_from.get_info()));
      self.add_audit_entry (inst, node, f);
      self.add_audit_entry (inst, node, sprintf ('To %s', self.ba_to.get_info()));
    }
  self.ba_to.set_value (inst, self.ba_scope, scp_inst, f);
  --dbg_obj_print ('AFTER ASSIGN: TO', self.ba_to.get_value (inst, self.ba_scope, scp_inst));
  return 1;
}
;

create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.flow
{
  BPEL..dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  self.add_audit_entry (inst, node, '');
  return 1;
}
;

create procedure BPEL..get_corr_exp (in scp int, in tp varchar, in corr varchar)
{
  declare xp_query any;
  declare i int;
  xp_query := null;
  i := 0;
  for select pa_query, pa_part
    from BPEL.BPEL.property_alias, BPEL.BPEL.correlation_props
      where
      pa_message = tp
      and cpp_corr = corr
      and cpp_script = scp
      and pa_prop_name = cpp_prop_name
      and pa_script = cpp_script do
  {
    declare q varchar;
    q := '';
    if (length (pa_part))
      q := sprintf ('/message/part[@name="%s"]', pa_part);
    if (length (pa_query))
      {
	q := concat ('string (', q , pa_query, ')');
      }
     -- more than one
     if (i = 1)
       xp_query := concat ('vi:encode_base64 (', xp_query);
     if (i >= 1)
       xp_query := concat (xp_query, '), "|" , vi:encode_base64 (');
     xp_query := concat(xp_query, q);
     i := i + 1;
   }
  if (i > 1)
    xp_query := concat ('[ xmlns:vi="http://www.openlinksw.com/virtuoso/xslt" ] concat(', xp_query, '))');
  if (xp_query is not null)
    xp_query := concat (coalesce (connection_get ('BPEL_xmlnss_pre'), ''), xp_query);
  return xp_query;
}
;

create method check_correlation (in msg any, in inst int, in scope int, in scope_inst int, inout ctx BPEL..ctx) for BPEL.BPEL.receive
{
  declare corr_var_id, i, l, init_cor int;
  declare corr_var_val, test_val any;
  declare var_type, xp_query varchar;

  corr_var_id := null; -- name of the correlation property
  corr_var_val := null; -- value of the correlation property
  xp_query := null;
  init_cor := 0;

  l := length (self.ba_correlations);
  for (i := 0; i < l; i := i + 1)
    {
      declare v, var any;
      v := self.ba_correlations[i];
      if (v[1] = 'no')
	{
	  var := BPEL..get_var (v[0], inst, scope, scope_inst, 1);
	  corr_var_val := var;
	  corr_var_id := v[0];
	}
    }


   var_type := BPEL..get_var_type (SELF.ba_var, inst, scope, scope_inst); -- type of the variable
   var_type := BPEL.BPEL.get_nc_name (var_type);

   xp_query := BPEL..get_corr_exp (ctx.c_script_id, var_type, corr_var_id);
   --dbg_obj_print (xp_query);
   if (xp_query is null)
     return 1;
   test_val := xpath_eval (xp_query, xml_tree_doc (msg));
   --dbg_obj_print ('checking correlation:', test_val, ' corr=', corr_var_id);
   if (test_val = corr_var_val)
     return 1;
   return 0;
}
;

-- returns 1 if found something into the queue, 0 if wait is registered
create method register_wait_object (in inst int, in node int, in scope int, in scope_inst int, inout ctx BPEL..ctx) for BPEL.BPEL.receive
{
      declare corr_var_id, i, l, use_mid, dummy, dbg int;
      declare corr_var_val, msg, sec any;
      declare var_type, xp_query, pl varchar;
      declare cr cursor for
	  select xml_tree_doc (__xml_deserialize_packed (bw_message)), bw_security from BPEL..wait
	where bw_instance = inst and bw_node = node and bw_state = 1;
      declare wa cursor for select wa_mid from BPEL..wsa_messages where
	wa_inst = inst and wa_pl = pl;
      declare lc cursor for select lck from BPEL..lock where lck = 1;
      declare pl cursor for select pl_debug from partner_link where
         pl_inst = inst and pl_name = pl and  pl_scope_inst = scope_inst and pl_role = 1;


      whenever not found default;
      open lc (exclusive, prefetch 1);
      fetch lc into dummy;

      corr_var_id := null; -- name of the correlation property
      corr_var_val := null; -- value of the correlation property
      xp_query := null;
      use_mid := 0;
      pl := self.ba_partner_link;

      whenever not found goto next_step;
      open cr (prefetch 1, exclusive);
      fetch cr into msg, sec;
      -- suspend receive from outside if compensation is still running
      if (scope_inst > 0 and self.ba_in_comp = 0)
	{
	  --dbg_obj_print ('suspending a rcv', node);
	  close cr;
	  close lc;
	  return 0;
	}
      delete from BPEL..wait where current of cr;
      BPEL..stat_update_n_rec (inst, ctx.c_script_id, self.ba_partner_link, self.ba_operation, msg);
      close cr;
      prof_sample ('BPEL recv from wait', 0, 1);
      --dbg_printf ('Got a message from wait');
      BPEL..set_io_request (inst, msg);
      close lc;
      security_check (sec, inst, scope_inst, node, pl);
      return 1;
      next_step:
      close cr;


      l := length (self.ba_correlations);
      for (i := 0; i < l; i := i + 1)
	{
	  declare v, var any;
	  v := self.ba_correlations[i];
	  if (v[1] = 'no')
	    {
	      var := BPEL..get_var (v[0], inst, scope, scope_inst, 1);
	      corr_var_val := var;
	      corr_var_id := v[0];
	    }
	}


	var_type := BPEL..get_var_type (SELF.ba_var, inst, scope, scope_inst); -- type of the variable
	var_type := BPEL.BPEL.get_nc_name (var_type);

        xp_query := BPEL..get_corr_exp (ctx.c_script_id, var_type, corr_var_id);

	--dbg_printf ('wait %d, %d, %d', inst, node, scope);

        if (not length(xp_query))
          {
	    whenever not found goto nfm;
	    open wa (prefetch 1);
	    fetch wa into corr_var_val;
	    if (not self.ba_is_event)
	      {
		--dbg_obj_print ('deleted by', self.ba_type);
	        delete from BPEL..wsa_messages where current of wa;
              }
	    use_mid := 1;
	    xp_query := 'string(/Header/RelatesTo)';
	    nfm:
	    close wa;
          }

        --dbg_obj_print ('trying in the queue', corr_var_val);

        for select bq_message, bq_header, bq_id as id, bq_security from BPEL.BPEL.queue
	   where bq_op = self.ba_operation and bq_state = 0 and bq_script = ctx.c_script_id do
	   {
             if (length (xp_query))
               {
		  declare v any;
		  declare ment any;

		  if (use_mid and bq_header is null)
                    goto next_iq;

		  if (use_mid)
                    ment := xml_tree_doc (__xml_deserialize_packed (bq_header));
		  else
                    ment := xml_tree_doc (__xml_deserialize_packed (bq_message));

		  v := xpath_eval (xp_query, ment);
		  if (v = corr_var_val)
		    {
		      match_no_corr:
		      declare message any;
		      message := __xml_deserialize_packed (bq_message);
		      --dbg_obj_print ('matched from queue');
                      --dbg_obj_print ('matched from queue:', corr_var_val, ' corr=', corr_var_id);
		      delete from BPEL.BPEL.queue where bq_id = id;
		      BPEL..set_io_request (inst, xml_tree_doc (message));
		      prof_sample ('BPEL recv from queue', 0, 1);
		      close lc;
		      sec := bq_security;
                      security_check (sec, inst, scope_inst, node, pl);
		      return 1;
                    }
               }
	     else
	       {
		 --dbg_obj_print ('matched w/o correlation');
		 goto match_no_corr;
	       }
             next_iq:;
           }

        --dbg_obj_print ('put into wait');

	insert soft BPEL.BPEL.wait
		(
		 bw_instance,
		 bw_node,
		 bw_script,
		 bw_script_id,
		 bw_scope,
		 bw_partner_link,
		 bw_port,
		 bw_deadline,
		 bw_correlation_exp,
		 bw_expected_value,
		 bw_message_type,
		 bw_from_comp
		)
	    values
		(
		inst,
		node,
		ctx.c_script,
		ctx.c_script_id,
		scope,
		self.ba_partner_link,
		self.ba_operation,
		NULL,
		xp_query,
		corr_var_val,
	        use_mid,
		self.ba_in_comp
		);

   dbg := 0;
   if (not ctx.c_debug)
     {
       whenever not found goto nfpl;
       open pl (prefetch 1);
       fetch pl into dbg;
     nfpl:
       close pl;
     }

   if ((ctx.c_debug or dbg = 1) and row_count ())
     {
       insert into BPEL..dbg_message
	   (bdm_text, bdm_ts, bdm_inout, bdm_sender_inst, bdm_plink,
	    bdm_recipient, bdm_activity, bdm_conn, bdm_action, bdm_oper, bdm_script)
	   values (null, now(), 1, inst, self.ba_partner_link, ctx.c_script,
	       node, null, null, self.ba_operation, ctx.c_script_id);
     }
   close lc;
   return 0;
}
;

create procedure get_signing_info ()
{
  declare ret any;
  ret := connection_get ('wss-keys');
  connection_set ('wss-keys', null);
  return ret;
}
;

create procedure security_check (inout sec any, in inst int, in scp_inst int, in node int, in pl any)
{
  declare wsopts BPEL.BPEL.partner_link_opts;
  declare opts, emsg any;
  declare cr cursor for select pl_opts from partner_link where
    pl_inst = inst and pl_name = pl and  pl_scope_inst = scp_inst and pl_role = 1;

  wsopts := new BPEL.BPEL.partner_link_opts ();
  whenever not found goto nfpl;
  open cr (prefetch 1);
  fetch cr into opts;
  BPEL..get_pl_options (opts, wsopts, inst, node);

  --
  -- the encrypt/signing keyinfo must contain :
  -- vector ( vector (ekey1, ekey2, ...), vector (skey-tmp, skey-name) )
  --

  if (sec is null
      or not isarray (sec)
      or length (sec) < 2)
    sec := vector (vector (), null);

  if (wsopts.pl_in_sign = 'Mandatory' and sec[1] is null)
    {
      emsg := 'XML Signature is missing';
      goto err;
    }

  if (length (wsopts.pl_in_tokens) and sec[1] is not null)
    {
      declare own any;
      own := null;
      if (sec[1] is not null and isarray(sec[1]) and sec[1][1] is not null)
	own := sec[1][1];
      if (own is null or not position (own, wsopts.pl_in_tokens))
	{
          emsg := 'XML Signature is invalid';
	  goto err;
	}
    }

  if (wsopts.pl_in_enc = 'Mandatory' and length (sec[0]) = 0)
    {
      emsg := 'XML Encryption is missing';
      goto err;
    }

  nfpl:
  close cr;
  return;
  err:
  commit work;
  signal ('BPELX', emsg);
}
;

create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.receive
{
  declare val any;
  BPEL..dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  --dbg_obj_print (self, val);
  --dbg_printf ('Eval: %d %s %s', self.ba_id, self.ba_type, self.ba_operation);
  --dbg_obj_print ('receive activity:', node, scp_inst, self.ba_in_comp);
  val := BPEL..get_io_request (inst);
  -- if there is correlation then check it first !!!
  if (val is not null)
    {
      if (self.ba_one_way = 1)
	{
	  connection_set ('BPEL_reply_sent', 0);
	  self.add_audit_entry(inst, node, 'Got one way request');
	}
      else
        {
          declare id int;
	  id := sequence_next ('connection_id');
	  insert into BPEL..reply_wait
	      (rw_inst,rw_partner,rw_port,rw_operation,rw_query,rw_expect, rw_id, rw_started)
	   values (inst, self.ba_partner_link, self.ba_port_type, self.ba_operation, null, null, id, now ());
	  --dbg_obj_print ('id=', id);
	  connection_set ('BPEL_reply_sent', 0);
	  http_request_status ('reply sent');
          http_keep_session (null, id);
	}
      self.add_audit_entry(inst, node, val);
      BPEL..stat_update_n_rec (inst, ctx.c_script_id, self.ba_partner_link, self.ba_operation, val);
      BPEL..dbg_printf ('Got a message: %d', node);
      if (self.check_correlation (val, inst, self.ba_scope, scp_inst, ctx))
        {
          prof_sample ('BPEL recv', 0, 1);
	   --dbg_obj_print ('GOT:',val);
          BPEL..set_var (SELF.ba_var, inst, self.ba_scope, val, scp_inst);
          if (ctx.c_hdr is not null)
            {
              declare replyto any;
	      -- XXX: /Header is f@# here
	      replyto := cast(xpath_eval ('string(//ReplyTo/Address)', ctx.c_hdr) as varchar);
	      update partner_link set pl_endpoint = replyto where pl_inst = inst
		and pl_name = self.ba_partner_link and pl_scope_inst = scp_inst and pl_role = 1;
            }
          BPEL..corr_init ('in', self.ba_correlations, self.ba_var, val, inst, scp_inst, self.ba_scope, ctx);
	  security_check (get_signing_info (), inst, scp_inst, node, self.ba_partner_link);
          return 1;
        }
      else
        BPEL..set_io_request (inst, val);
    }
  if (self.register_wait_object (inst, node, self.ba_scope, scp_inst, ctx))
    {
      --dbg_printf ('Got a message from queue: %d', node);
      val := BPEL..get_io_request (inst);
      self.add_audit_entry(inst, node, 'Got a message from queue');
      self.add_audit_entry(inst, node, val);
       --dbg_obj_print ('GOT:', val);
      BPEL..set_var (SELF.ba_var, inst, self.ba_scope, val, scp_inst);
      BPEL..corr_init ('in', self.ba_correlations, self.ba_var, val, inst, scp_inst, self.ba_scope, ctx);
      return 1;
    }
  return 0;
}
;

create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.pick
{
  BPEL..dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  self.add_audit_entry(inst, node, '');
  return 1;
}
;

create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.onmessage
{
  --dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  -- done inside receive
  declare rc int;
  declare other BPEL..activity;
  declare cr cursor for select bg_activity from BPEL..graph where bg_parent = self.ba_parent_id
	and bg_node_id <> node;

  if (self.ba_create_inst and self.ba_operation <> ctx.c_init_oper)
    return 0;

  rc := (self as BPEL..receive).eval (inst, scp_inst, node, amask, links, stack, ctx);
  --dbg_obj_print ('receive rc=', rc);
  if (rc = 1 and not self.ba_is_event)
    {
      self.add_audit_entry(inst, node, '');
      whenever not found goto alldone;
      open cr;
      while (1)
        {
	  fetch cr into other;
          -- delete other wait too or rather just mark it for delete
	  --dbg_obj_print ('setting done for:', other.ba_id, other.ba_type);
          amask := v_bit_or (amask, v_bit_not (other.ba_init_bf));
	  amask := bit_set (amask, other.ba_id);
	}
      alldone:
      close cr;
    }
  else if (self.ba_is_event)
    {
      if (rc = 0)
        amask := v_bit_or (amask, v_bit_not (self.ba_init_bf));
      --dbg_obj_print ('onmessage event rc=', rc);
    }
  return rc;
}
;

create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.onalarm
{
  --dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);

  declare t, rc, unt int;
  declare tw cursor for select tw_sec from BPEL..time_wait where tw_inst = inst and tw_node = node;
  declare other BPEL..activity;
  declare cr cursor for select bg_activity from BPEL..graph where bg_parent = self.ba_parent_id
	and bg_node_id <> node;

  rc := 0;
  whenever not found goto newwait;
  open tw (exclusive, prefetch 1);
  fetch tw into t;
  if (t = 0)
    {
      self.add_audit_entry(inst, node, '');
      rc := 1;
      delete from BPEL..time_wait where tw_inst = inst and tw_node = node;
      if (not self.ba_is_event)
	{
	  whenever not found goto alldone;
	  open cr;
	  while (1)
	    {
	      fetch cr into other;
	      -- delete other waits too
	      --dbg_obj_print ('setting done for:', other.ba_id, other.ba_type);
	      amask := v_bit_or (amask, v_bit_not (other.ba_init_bf));
	      amask := bit_set (amask, other.ba_id);
	    }
	  alldone:
	  close cr;
	}
    }
  close tw;
  return rc;

newwait:
  t := 0;
  unt := now ();

  if (self.ba_seconds > 0)
    {
      t := self.ba_seconds;
      unt := dateadd ('second', t, now ());
    }
  insert into BPEL..time_wait (tw_inst, tw_node, tw_sec, tw_until, tw_scope_inst, tw_script, tw_script_id)
		values (inst, node, t, unt, scp_inst, ctx.c_script, ctx.c_script_id);
  if (self.ba_is_event)
    {
      amask := v_bit_or (amask, v_bit_not (self.ba_init_bf));
    }
  --register_time_wait (inst, node, scp_inst);
  http_get ('http://localhost:'||server_http_port ()||'/BPELGUI/time.vsp');
  return 0;
}
;

create procedure BPEL.BPEL.ALARM_CALLBACK (inout ses any, inout cd any)
{
  declare resp any;
  declare inst, node, rc, dummy, scp_inst, script_id int;
  declare script varchar;

  set_user_id ('BPEL', 0);
  resp := ses_read_line (ses, 0, 1000);

  inst := cd [0];
  node := cd [1];
  script := cd [2];
  scp_inst := cd [3];
  script_id := cd [4];


  declare exit handler for sqlstate '*' {
     --dbg_printf ('%s',__SQL_MESSAGE);
    ;
  };
  declare deadlock_count int;
  deadlock_count := BPEL..max_deadlock_cnt ();
  declare exit handler for sqlstate '40001' {
    rollback work;
    if (deadlock_count > 0)
      {
	BPEL..add_audit_entry (inst, -11, sprintf ('Deadlock catched in alarm_callback: %s, retrying...', __SQL_MESSAGE));
	delay (BPEL..deadlock_delay());
	 --dbg_printf ('Deadock ..resume %d', deadlock_count);
	deadlock_count := deadlock_count - 1;
	goto again2;
      }
    BPEL..add_audit_entry (inst, -11, sprintf ('Deadlock catched in alarm_callback: %s, resignal', __SQL_MESSAGE));
    BPEL..send_error_mail (inst, __SQL_STATE, __SQL_MESSAGE);
    signal ('BPELZ', 'Deadlock retry maximum count reached.');
  };
 again2:

  --dbg_obj_print ('ALARM_CALLBACK', cd);

  --dbg_obj_print ('resuming alarm instance:', inst, node);
  rc := BPEL..resume (inst, script_id, null, node, scp_inst);

  if (rc = 0)
    {
      commit work;
      delay (1);
      goto again2;
    }

  --delete from BPEL..time_wait where tw_inst = inst and tw_node = node;
  --dbg_obj_print ('end alarm resume rc=',rc, ' inst=', inst, ' node=', node);
}
;


create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.terminate
{
  BPEL..dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  declare i, l int;
  l := (length (amask)-2)*8 + aref (cast (amask as varchar), 0);
  for (i := 0; i < l; i := i + 1)
     {
       amask := bit_set (amask, i);
     }
  ctx.c_fault := 'Terminated';
  return 1;
}
;


create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.reply
{
  BPEL..dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  declare var_val, conn, xq, exp, omsg any;
  declare id, style int;
  declare dbg, opts any;
  declare wsopts BPEL.BPEL.partner_link_opts;
  declare started datetime;
  declare op cursor for select bo_style from BPEL..operation where bo_name = self.ba_operation
	and bo_script = ctx.c_script_id;
  declare cr cursor for select rw_id,rw_query,rw_expect,rw_started from reply_wait
	where rw_inst = inst and rw_partner = self.ba_partnerLink and rw_port = self.ba_portType
	and rw_operation = self.ba_operation;
  declare pl cursor for select pl_debug, pl_opts from partner_link where
    pl_inst = inst and pl_name = self.ba_partnerLink and  pl_scope_inst = scp_inst and pl_role = 1;

  wsopts := new BPEL.BPEL.partner_link_opts ();
  var_val := BPEL..get_var (SELF.ba_variable, inst, self.ba_scope, scp_inst, 1);
  self.add_audit_entry (inst, node, var_val);
  id := null;
  whenever not found goto nf;
  open cr (exclusive, prefetch 1);
  fetch cr into id, xq, exp, started;
  open op (prefetch 1);
  fetch op into style;
  open pl (prefetch 1);
  fetch pl into dbg, opts;
  BPEL..get_pl_options (opts, wsopts, inst, node);
  --BPEL..set_io_result (inst, var_val);

  -- check correlation as there could be such
  --dbg_obj_print ('reply: Recall session', id);
  BPEL..corr_init ('out', self.ba_correlations, self.ba_variable, var_val, inst, scp_inst, self.ba_scope, ctx);
  omsg := make_reply_to_client (var_val, self.ba_operation, style, wsopts, self.ba_fault);
  conn := http_recall_session (id);
  BPEL..stat_update_cum_wait (inst, ctx.c_script_id, self.ba_partnerLink, self.ba_operation, started, now() );
  delete from BPEL..reply_wait where current of cr;
  commit work;
  reply_to_client (conn, omsg, self.ba_fault);
  nf:
  close cr;
  close op;
  if (id is null)
    signal ('22023', 'Reply to non waiting operation and partner');
  return 1;
}
;

create procedure check_async_result (in inst int, inout scp_inst int, inout node int, inout ctx BPEL..ctx, inout inv BPEL.BPEL.invoke)
{
  declare rc int;
  declare msg, res, serr, res_str, sec any;
  declare cr cursor for select bw_message, bw_security from BPEL.BPEL.wait where
	bw_instance = inst and bw_node = node;
  rc := -1;
  whenever not found goto nf;
  open cr (exclusive, prefetch 1);
  fetch cr into msg, sec;
  rc := 0;
  if (msg is not null)
    {
      res := xml_tree_doc (__xml_deserialize_packed (blob_to_string (msg)));
      serr := xpath_eval ('//Fault', res);
      delete from BPEL.BPEL.wait where current of cr;
      if (serr is not null)
	{
	  BPEL..signal_bpelx_err (res);
	}
      else
	{
          res_str := res;
	  --dbg_obj_print ('sync sec:', sec);
          security_check (sec, inst, scp_inst, node, inv.ba_partner_link);
	   --dbg_obj_print (res_str, ' inst=', inst, ' scp=', scp_inst, ' node=', node);
	  BPEL..set_var (inv.ba_output_var, inst, inv.ba_scope, res_str, scp_inst);
          BPEL..corr_init ('in', inv.ba_correlations, inv.ba_output_var, res_str, inst, scp_inst, inv.ba_scope, ctx);
	}
       --dbg_obj_print ('We found a message inst=', inst, ' node=',node);
      rc := 1;
    }
nf:
  close cr;
  return rc;
}
;

create procedure corr_init
	(
	in pattern varchar,
	inout corrs any,
	inout var any,
	inout var_val any,
	in inst int,
	inout scp_inst int,
	in scope int,
	inout ctx BPEL..ctx
	)
{
   declare i, l int;
   l := length (corrs);
   --dbg_printf ('corr_init: %s patt=%s', var, pattern);
   for (i := 0; i < l; i := i + 1)
     {
        declare v any;
	declare nam, ty varchar;
	v := corrs [i];
	nam := v[0];
	ty := v[1];
	if (ty = 'yes' and v[2] = pattern)
	  {
	    declare var_type, xp_query varchar;
	    --dbg_obj_print ('corr ty=', ty, ' name=', nam, ' patt=', v[2]);
	    var_type := BPEL..get_var_type (var, inst, scope, scp_inst);
	    var_type := BPEL.BPEL.get_nc_name (var_type);

            xp_query := BPEL..get_corr_exp (ctx.c_script_id, var_type, nam);
            if (xp_query is not null)
              {
		declare eval any;
		eval := BPEL.BPEL.xpath_evaluate (xp_query, var_val);
                --dbg_obj_print ('setting correlation:', eval, ' corr=', nam);
		BPEL..set_var (nam, inst, scope, eval, scp_inst);
              }
	  }
      }
}
;

create procedure BPEL..signal_bpelx_err (in res any)
{
  declare serr any;
  serr := xpath_eval ('//Fault/faultstring/text()', res);
  if (serr is not null)
    signal ('BPELX', cast (serr as varchar));
  else
    serr := xpath_eval ('//Fault/faultcode/text()', res);
  if (serr is not null)
    signal ('BPELX', cast (serr as varchar));
  signal ('BPELX', 'UnknownError');
}
;

create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.invoke
{
   --dbg_printf ('Eval: %d %s [%s]', self.ba_id, self.ba_type, bit_print (amask));
  BPEL..dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  declare i, l, rc int;
  declare var_val, imtype, mid any;

  if (0 <= (rc := check_async_result (inst, scp_inst, node, ctx, self)))
    return rc;

   --dbg_printf ('next');
  var_val := BPEL..get_var (SELF.ba_input_var, inst, self.ba_scope, scp_inst, 1);
  if (var_val is null)
    {
      signal ('BPELV', 'Input variable is not initialized');
    }

   BPEL..corr_init ('out', self.ba_correlations, self.ba_input_var, var_val, inst, scp_inst, self.ba_scope, ctx);

      for select bi_script from BPEL.BPEL.instance where bi_id = inst
	do {
   	  declare res any;
	  declare headers any;

	  --dbg_obj_print ('out=', self.ba_output_var, ' in=',self.ba_input_var);
          imtype := null;
          if (length (self.ba_output_var))
            {
              imtype := BPEL..get_var_type (self.ba_output_var, inst, self.ba_scope, 0);
              imtype := BPEL.BPEL.get_nc_name (imtype);
            }
	  connection_set ('BPEL_activs', amask);
	  mid := null;
  	  res := BPEL.BPEL.invoke_partner (bi_script, var_val, 128, inst, node, self, ctx, scp_inst, imtype, mid);

	  if (SELF.is_sync = 1)
            {
		if (res is null)
		  {
		    links := bit_set (links, self.ba_id);
                    return 0;
		  }
		declare res_str, serr varchar;
		serr := xpath_eval ('//Fault', xml_tree_doc (res));
		if (serr is not null)
		  {
			BPEL.BPEL.obj_print (res);
			delete from BPEL..wsa_messages where
			    wa_inst = inst and wa_pl = self.ba_partner_link and wa_mid = mid;
			BPEL..signal_bpelx_err (xml_tree_doc (res));
		  }
                else
                  {
                     if (length (res) > 1)
		       res := aref (res, 1);
		     if (isstring (res))
		       res_str := res;
		     else
 		       res_str := xml_tree_doc (res);
		     BPEL..set_var (SELF.ba_output_var, inst, self.ba_scope, res_str, scp_inst);
		}
	    }
          else
            {
		declare serr varchar;
		--dbg_obj_print (xml_tree_doc (res));
		if ((res <> 0) and (xpath_eval ('//Fault', xml_tree_doc (res)) is not null))
                  {
		     delete from BPEL..wsa_messages where
			    wa_inst = inst and wa_pl = self.ba_partner_link and wa_mid = mid;
                     BPEL..signal_bpelx_err (xml_tree_doc (res));
		  }
	     }
	}
  return 1;
}
;

create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.sequence
{
  self.add_audit_entry (inst, node, '');
  BPEL..dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  return 1;
}
;

create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.scope_end
{
  declare nid int;
  declare nscp_inst int;
  declare ev BPEL.BPEL.activity;
  BPEL..dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  declare cr cursor for select bg_activity from BPEL..graph
      where bg_node_id = nid and bg_script_id = ctx.c_script_id;
  foreach (int n in self.se_events) do
    {
      nid := n;
      whenever not found goto err;
      open cr (prefetch 1);
      fetch cr into ev;
      amask := v_bit_or (amask, v_bit_not (ev.ba_init_bf));
      amask := bit_set (amask, ev.ba_id);
      if (ev.ba_type = 'onMessage')
        delete from BPEL..wait where bw_instance = inst and bw_node = nid;
      else
        delete from BPEL..time_wait where tw_inst = inst and tw_node = nid;
      close cr;
    }
  if (scp_inst = 0)
    {
      declare hdl BPEL.BPEL.activity;
      declare hdl_id int;
      declare hd cursor for select bg_activity, bg_node_id from BPEL.BPEL.graph where
	  bg_script_id = ctx.c_script_id and bg_node_id > node and bg_parent = self.ba_parent_id;
      hdl_id := -1;
      whenever not found goto err1;
      open hd (prefetch 1);
      while (hdl_id < 0)
	{
	  fetch hd into hdl, hdl_id;
	  if (hdl.ba_type <> 'CompensationHandler')
	    hdl_id := -1;
	}
      close hd;
      --dbg_obj_print ('installing comp scp_id=', ctx.c_scope_id, ' parent=',  ctx.c_pscope_id);
      insert into compensation_scope (tc_seq, tc_seq_parent, tc_inst, tc_scopes,
	  		tc_head_node, tc_head_node_bit, tc_scope_name)
	    values (ctx.c_scope_id, ctx.c_pscope_id, inst, serialize (hdl.ba_enc_scps),
			hdl_id, hdl.ba_id, self.se_scope_name);
      nscp_inst := ctx.c_scope_id; --identity_value ();
      --dbg_obj_print ('installing a comps for scp=' , nscp_inst, ' scope=', self.ba_scope);
      if (self.se_comp_act)
	{
	  --dbg_obj_print ('installing snapshot:', self.se_scope_name);
	  insert into BPEL..variables
	      (v_inst, v_scope_inst, v_name, v_s1_value, v_s2_value, v_b1_value, v_b2_value)
	    select v_inst, nscp_inst, v_name, v_s1_value, v_s2_value, v_b1_value, v_b2_value from BPEL..variables
	    where v_inst = inst and v_scope_inst = 0;
	  insert into BPEL..partner_link (pl_inst, pl_name, pl_scope_inst, pl_role, pl_endpoint, pl_debug)
	    select pl_inst, pl_name, nscp_inst, pl_role, pl_endpoint, pl_debug from BPEL..partner_link
	    where pl_inst = inst and pl_scope_inst = 0;
        }
      --dbg_obj_print ('compensation_scope init', nscp_inst);
     }
  return 1;
  err:
  signal ('22023', 'Bad node in events collection');
  err1:
  if (self.ba_scope <> ctx.c_first_node)
    signal ('22023', 'Cannot install compensation handlers (missing)');
  return 1;
}
;

create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.compensation_handler
{
  declare rev_init varbinary;
  self.add_audit_entry (inst, node, '');
  --dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  --dbg_obj_print ('compensation_scope mark as done', scp_inst);
  rev_init := v_bit_not (self.ba_init_bf);
  amask := v_bit_or (amask, rev_init);
  return 1;
}
;

create procedure enable_handler (in node int, inout amask varbinary, inout links varbinary, inout ctx BPEL..ctx)
{
  declare hdl BPEL.BPEL.activity;
  declare cr cursor for select bg_activity from BPEL.BPEL.graph where bg_node_id = node;
  whenever not found goto err;
  open cr (prefetch 1);
  fetch cr into hdl;

  --dbg_obj_print ('enabling handler:', hdl.ba_type, hdl.ba_id);

  amask := v_bit_and (amask, hdl.ba_init_bf);
  links := v_bit_and (links, hdl.ba_init_bf);
  amask := bit_set (amask, hdl.ba_id);
  links := bit_set (links, hdl.ba_id);

  close cr;
  return;
  err:
  signal ('42000', sprintf ('Non-existing node id=%d', node));
}
;

create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.compensation_handler_end
{
  --dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  self.add_audit_entry (inst, node, '');
  declare comp_from int;
  declare cr cursor for select tc_compensating_from from BPEL..compensation_scope
	where tc_inst = inst and tc_seq = scp_inst;
  whenever not found goto ret;
  open cr (exclusive, prefetch 1);
  fetch cr into comp_from;
  --dbg_obj_print ('comp-from:', comp_from, scp_inst);
  if (scp_inst > 0)
    {
      declare nstack any;
      declare parent_seq, scope_name, comp_id, comp_node, comp_scp any;
      declare seq, scopes, head, head_bit any;

      declare tc cursor for select tc_seq, tc_scopes, tc_head_node, tc_head_node_bit from BPEL..compensation_scope
	  where tc_inst = inst and tc_seq_parent = parent_seq and
	  (length (scope_name) = 0 or tc_scope_name = scope_name)
	  order by tc_seq desc;

      delete from BPEL..compensation_scope where tc_seq = scp_inst and tc_inst = inst;
      --dbg_obj_print ('de-installing a comps: ' , scp_inst);
      delete from BPEL..variables where v_inst = inst and v_scope_inst = scp_inst;

      -- stack contains
      -- scope_id, handler_head_node, scope_name, scope_inst_compensating_from, comp_serial, comp_node_id

      comp_scp   := stack[0][0];
      parent_seq := stack[0][3];
      scope_name := stack[0][2];
      comp_id    := stack[0][4];
      comp_node  := stack[0][5];

      --dbg_obj_print ('stack:', stack);

      {
	declare st_top any;
	whenever not found goto popit;
	open tc (exclusive, prefetch 1);
	fetch tc into seq, scopes, head, head_bit;
	update BPEL..compensation_scope set tc_compensating_from = scp_inst where current of cr;
	enable_handler (head, amask, links, ctx);

	st_top := stack[0];
	st_top[0] := seq;
	st_top[1] := head;
	stack[0] := st_top;

        --dbg_obj_print ('updated stack:', stack);
	scp_inst := seq;
	node := head;
	close cr;
	return 0;
      }

      popit:
      --dbg_obj_print ('poping from stack');
      nstack := subseq (stack, 1, length (stack));
      stack := nstack;
      amask := bit_set (amask, comp_id);
      if (length (stack) > 0)
	{
	  node := stack[0][1];
	  scp_inst := stack[0][0];
	}
      else
	{
	  node := comp_node;
	  scp_inst := 0;
        }
      --dbg_obj_print ('new stack:', stack);
    }
ret:
  close cr;
  return 1;
}
;

create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.fault_handlers
{
  declare rev_init varbinary;

  self.add_audit_entry (inst, node, '');
  BPEL..dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  rev_init := v_bit_not (self.ba_init_bf);
  amask := v_bit_or (amask, rev_init);
  insert soft BPEL..variables (v_inst, v_scope_inst, v_name, v_type)
      values (inst, scp_inst, sprintf ('@fault-%d', node), 'any');
  return 1;
}
;

create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.scope
{
  declare idx, var_cnt, cor_cnt int;
  cor_cnt := var_cnt := idx := 0;
  BPEL..dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  -- init the partner links; they are always in the top scope
  set isolation='committed';
  ctx.c_scope_id := sequence_next ('bpel_scope_id');
  if (self.ba_parent_id < 0)
    {
      insert into partner_link (pl_inst, pl_name, pl_scope_inst, pl_role, pl_endpoint, pl_backup_endpoint, pl_debug, pl_opts)
	select inst, bpl_name, scp_inst, 1, bpl_endpoint, bpl_backup_endpoint, bpl_debug, bpl_opts
	from partner_link_init where bpl_script = ctx.c_script_id;
    }
  -- we should probably make so that scope is executed only once
  for (idx := 0; idx < length (self.ba_vars); idx := idx + 1)
    {
      declare v, iv any;
      v := self.ba_vars [idx];
      -- we should probably make a normal cursor
      insert soft BPEL..variables (v_inst, v_scope_inst, v_name, v_type)
	values (inst, 0, v[0], v[2]);
      if (row_count ())
        {
	  declare vtp any;
          if (length (v) > 3)
            vtp := v[3];
          else
            vtp := 0;
          iv := (select vi_value from BPEL..types_init where vi_script = ctx.c_script_id
	        and vi_name = BPEL..get_nc_name (v[2]) and vi_type = vtp);
          BPEL..set_var (v[0], inst, 0, iv, scp_inst);
        }
      var_cnt := var_cnt + 1;
    }
  --
  -- for every correlation set we are defining a special variable
  --
  for (idx := 0; idx < length (self.ba_corrs); idx := idx + 1)
    {
      declare v any;
      v := self.ba_corrs [idx];
      -- we probably should put here the id of the var
      --dbg_obj_print (v, self.ba_scope);
      insert soft BPEL..variables (v_inst, v_scope_inst, v_name, v_type)
	values (inst, 0, v[0], v[2]);
      cor_cnt := cor_cnt + 1;
    }
  self.add_audit_entry (inst, node, sprintf ('%d variables, %d correlation sets', var_cnt, cor_cnt));
  set isolation='repeatable';
  return 1;
}
;

--
-- compensate is invoked, loop over compensation_scope
-- find a scopes to be compensted
--

create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.compensate
{
  --dbg_printf ('Eval: %d %s [%s]', self.ba_id, self.ba_type, self.ba_scope_name);
  --dbg_obj_print ('compensate in scope=', ctx.c_scope_id, ' scp_inst=', scp_inst);
  declare seq, scopes, head, head_bit any;
  declare cr cursor for select tc_seq, tc_scopes, tc_head_node, tc_head_node_bit from BPEL..compensation_scope
	where
		tc_inst = inst and
		tc_seq_parent = ctx.c_scope_id and
		(length (self.ba_scope_name) = 0 or tc_scope_name = self.ba_scope_name)
		order by tc_seq desc;
  whenever not found goto ret;
  open cr (exclusive, prefetch 1);
  self.add_audit_entry (inst, node, self.ba_scope_name);
  while (1)
    {
      fetch cr into seq, scopes, head, head_bit;
      scopes := deserialize (blob_to_string (scopes));
      --dbg_obj_print ('test for comp:', head, seq, scopes, self.ba_scope);
      --dbg_obj_print ('compensate found', seq);
      if (seq <> scp_inst)
	{ -- invoke in a new scope
	  --dbg_obj_print ('run in new scope:', seq);
	  declare nstack any;
	  update BPEL..compensation_scope set tc_compensating_from = scp_inst where current of cr;

	  enable_handler (head, amask, links, ctx);
	  links := bit_set (links, self.ba_id);
	  nstack := vector_concat (vector (
	  	vector (seq, head, self.ba_scope_name, ctx.c_scope_id, self.ba_id, node)),
				    stack);
	  stack := nstack;
	  scp_inst := seq;
	  node := head;
	  close cr;
	  return 0;
	}
    }
ret:
  close cr;
  return 1;
}
;

create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.jump
{
  BPEL..dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  -- there is a explicit jump; just go on it
  if (self.ba_node_id > 0)
    {
      node := self.ba_node_id;
      amask := bit_clear (amask, self.ba_act_id);
      links := bit_clear (links, self.ba_act_id);
      self.add_audit_entry (inst, node, sprintf ('jump to: %d', node));
    }
  else if (length (ctx.c_jumps) > 0)
    { -- conditional jumps take the last and pop it from context
      declare i, l int;
      declare njumps any;
      l := length (ctx.c_jumps);
      node := ctx.c_jumps[l-1];
      njumps := make_array (l-1, 'any');
      for (i := 0; i < l-1; i := i+1)
         {
           njumps[i] := ctx.c_jumps[i];
         }
      ctx.c_jumps := njumps;
   }
  else
    {
      signal ('BPELX', 'invalidJump');
    }
  return 1;
}
;

create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.link
{
  BPEL..dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  return 0;
}
;


create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.throw
{
  --dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  self.add_audit_entry (inst, node, self.ba_fault);
  if (self.ba_fault = '*')
    {
      declare err varchar;
      err := BPEL..get_var (sprintf ('@fault-%d', self.ba_fault_hdl), inst, self.ba_scope, 0);
      if (err like '%communicationFault')
	signal ('BPELR', err);
      if (err is null)
        err := 'UnknownError';
      signal ('BPELX', err);
    }
  signal ('BPELX', self.ba_fault);
  return 1;
}
;


create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.catch
{
  declare err varchar;
  err := ctx.c_fault;
  BPEL..dbg_printf ('Eval: %d %s [%s]=[%s]', self.ba_id, self.ba_type, self.ba_fault, err);

  if (self.ba_fault like '%comminucationFault')
    connection_set ('BPEL_invoke_id', null);

  if (err like self.ba_fault)
    {
      self.add_audit_entry (inst, node, err);
      declare other BPEL..activity;
      declare cr cursor for select bg_activity from BPEL..graph where bg_parent = self.ba_parent_id
	and bg_node_id <> node;
      --dbg_obj_print ('Catched');

      declare err_val any;

      err_val := ctx.c_full_err;
      insert soft BPEL..variables (v_inst, v_scope_inst, v_name, v_type)
	values (inst, scp_inst, SELF.ba_var, 'any');
      BPEL..set_var (SELF.ba_var, inst, self.ba_scope, err_val, 0);
      whenever not found goto alldone;
      open cr;
      while (1)
        {
	  fetch cr into other;
          amask := v_bit_or (amask, v_bit_not (other.ba_init_bf));
	  amask := bit_set (amask, other.ba_id);
	}
      close cr;
      alldone:
      return 1;
    }
  else
    {
      declare rev varbinary;
      rev := v_bit_not (self.ba_init_bf);
      amask := v_bit_or (amask, rev);
      --dbg_obj_print ('Not catched');
      --dbg_obj_print (bit_print (amask));
    }
  return 1;
}
;


create method eval (in inst int, inout scp_inst int, inout node int, inout amask varbinary, inout links varbinary, inout stack any, inout ctx BPEL..ctx) for BPEL.BPEL.server_failure
{
  --dbg_printf ('Eval: %d %s', self.ba_id, self.ba_type);
  self.add_audit_entry (inst, node, '');
  log_message (sprintf ('BPEL server failure simulation inst=[%d] scp=[%d] node=[%d]', inst, scp_inst, node));
  return 1;
}
;


--
--  Variables manipulation
--

create procedure get_var (in name varchar, in inst int, in scope int, in scope_inst int := 0, in check_avial int := 0)
{
  declare vs1, vs2, vb1, vb2 any;
  declare cr cursor for select v_s1_value,v_s2_value,v_b1_value,v_b2_value from BPEL..variables
	where v_inst = inst and v_scope_inst = scope_inst and v_name = name;
  declare exit handler for not found {
    close cr;
    signal ('22023', sprintf ('No such variable %s, inst=[%d], scp_inst=[%d]',name,inst,scope_inst));
  };
  open cr (prefetch 1);
  fetch cr into vs1,vs2,vb1,vb2;
  close cr;
  if (vs1 is not null) -- string or numeric
    return vs1;
  else if (vb1 is not null) -- string or numeric
    return blob_to_string (vb1);
  else if (vs2 is not null)
    {
      declare dvs2 any;
      dvs2 := __xml_deserialize_packed (vs2);
      -- when text node is serialized the result is string
      if (isstring (dvs2))
	return dvs2;
      return xml_tree_doc (dvs2);
    }
  else if (vb2 is not null)
    return xml_tree_doc (__xml_deserialize_packed (blob_to_string(vb2)));
  if (check_avial)
    signal ('BPELX', 'bpws:uninitializedVariable');
  return null;
}
;

create procedure get_var_type (in name varchar, in inst int, in scope int, in scope_inst int := 0)
{
  declare ty any;
  declare cr cursor for select v_type from BPEL..variables
	where v_inst = inst and v_scope_inst = scope_inst and v_name = name;
  declare exit handler for not found {
    close cr;
    signal ('22023', 'No such variable');
  };
  open cr (prefetch 1);
  fetch cr into ty;
  close cr;
  return ty;
}
;

create procedure set_var (in name varchar, in inst int, in scope int, in value any, in scope_inst int := 0)
{
  declare v1, v2, v3, v4 any;
  declare scp int;
  declare cr cursor for select v_s1_value,v_s2_value,v_b1_value,v_b2_value from BPEL..variables
	where v_inst = inst and v_scope_inst = scope_inst and v_name = name;
  declare exit handler for not found {
    close cr;
    signal ('22023', sprintf ('No such variable %s, inst=[%d], scp_inst=[%d]',name,inst,scope_inst));
  };
  open cr (prefetch 1, exclusive);
  fetch cr into v1, v2, v3, v4;
  declare s1,b1,b2 any;
  declare s2 varchar;
  s1 := null;
  s2 := null;
  b1 := null;
  b2 := null;

  if ((value is null) or isnumeric (value) or
	((isstring (value) or iswidestring(value)) and (length (value) <= 3072)))
    s1 := value;
  else if ((isstring (value) or iswidestring(value)) and (length (value) > 3072))
    b1 := value;
  else
    {
      declare xx any;
      xx := __xml_serialize_packed (value);
      if (length (xx) > 3072)
	b2 := xx;
      else
	s2 := xx;
    }
  update BPEL..variables
    set
      v_s1_value = s1,
      v_s2_value = s2,
      v_b1_value = b1,
      v_b2_value = b2
    where v_inst = inst and v_scope_inst = scope_inst and v_name = name;
  close cr;
  return;
}
;


--
-- Additional info for logging
--

create method get_info () for BPEL.BPEL.place_text
{
  return self.ba_text;
}
;

create method get_info () for BPEL.BPEL.place_expr
{
  return self.ba_exp;
}
;

create method get_info () for BPEL.BPEL.place_plep
{
  return sprintf ('PartnerLink: "%s" Role: "%d"', self.ba_pl, self.ba_ep);
}
;

create method get_info () for BPEL.BPEL.place_vpr
{
  return sprintf ('Variable: "%s" Property: "%s"', self.ba_var, self.ba_property);
}
;

create method get_info () for BPEL.BPEL.place_vq
{
  return sprintf ('Variable: "%s" Query: "%s"', self.ba_var, self.ba_query);
}
;

create method get_info () for BPEL.BPEL.place_vpa
{
  return sprintf ('Variable: "%s" Part: "%s" Query: "%s"', self.ba_var, self.ba_query, self.ba_query);
}
;

--
-- Assigment XXX: when extracting & pushing something type must be check !!!
--

create method get_value (in inst int, in scope int, in scope_inst int) for BPEL.BPEL.place_vpa
{
	declare var_val, val, xq, nod, txt any;
	declare qry varchar;

	var_val := BPEL..get_var (self.ba_var, inst, scope, scope_inst, 1);

	if (not isentity (var_val) or (self.ba_query = '' and self.ba_part = ''))
	  return var_val;

        qry := sprintf ('/message/part[@name="%s"]', self.ba_part);

        if (self.ba_query = '' or self.ba_query like '/%')
          {
            qry := concat (self.bp_query_prefix, concat (qry, self.ba_query));
            xq := BPEL.BPEL.xpath_evaluate (qry, var_val);
          }
        else
          {
            declare xq1 any;
            xq1 := BPEL.BPEL.xpath_evaluate (qry, var_val);
            if (xq1 is not null) -- XXX: may be we should prohibit further processing
              var_val := xml_cut (xq1);
            xq := BPEL.BPEL.xpath_evaluate (concat (self.bp_query_prefix, self.ba_query), var_val);
          }
        --dbg_obj_print ('get_value, vpa:',self);

        val := null;

        if (xq is not null and isentity (xq))
          {
            xq := xml_cut (xq);
            if ((nod := xpath_eval ('*', xq, 0)) is not null and length (nod) = 1)
              val := xml_cut (nod[0]);
            else if ((txt := xpath_eval ('node()', xq, 0)) is not null and length (txt) = 1)
	      val := xml_cut (txt[0]);
            else
              val := xq;
          }
        else
          val := xq; -- integers, strings etc.
	--dbg_obj_print ('ret:val:',val);
	return val;
}
;

create method get_value (in inst int, in scope int, in scope_inst int) for BPEL.BPEL.place_text
{
  -- here this weird trick is really needed
  -- since nobody knows is this xml or not
  declare xx any;
whenever sqlstate '22007' goto noxml;
  return xtree_doc (self.ba_text);
 noxml:
  return self.ba_text;
}
;

create method get_value (in inst int, in scope int, in scope_inst int) for BPEL.BPEL.place_vq
{
	declare var_val, val, xq, nod, txt any;
	declare qry varchar;
	--dbg_obj_print ('get_value,place_vq');
	var_val := BPEL..get_var (self.ba_var, inst, scope, scope_inst, 1);
        --dbg_obj_print (var_val);
	if (not isentity (var_val) or self.ba_query = '' )
	  return var_val;

        if (self.ba_query <> '')
          {
            xq := BPEL.BPEL.xpath_evaluate (concat (self.bp_query_prefix, self.ba_query), var_val);
          }

        --dbg_obj_print ('get_value, vq:',self);


        val := null;

        if (xq is not null and isentity (xq))
          {
            xq := xml_cut (xq);
            if ((nod := xpath_eval ('*', xq, 0)) is not null and length (nod) = 1)
              val := xml_cut (nod[0]);
            else if ((txt := xpath_eval ('node()', xq, 0)) is not null and length (txt) = 1)
	      val := xml_cut (txt[0]);
            else
              val := xq;
          }
        else
          val := xq; -- integers, strings etc.
        --dbg_obj_print ('ret:val:',val);
	return val;
}
;

create procedure set_value_to_var (in qry varchar, inout val any, inout var any)
{
	declare ent, ent_to_ch, ent_to_ch2 any;
  declare xq any;

  xq := BPEL..xpath_evaluate (qry, var);

  --dbg_obj_print ('set_value:', var, val, xq);

  ent_to_ch := null; ent_to_ch2 := null;
  if (xq is not null)
    {
      declare nod, txt any;
      nod := xpath_eval ('./*', xq, 0);
      if (nod is not null and length (nod) = 1)
        {
	  ent_to_ch := nod[0];
	  XMLReplace (var, ent_to_ch, val);
	}
      else if (nod is not null and isentity (val))
	{
	  declare nnod any;
	  declare nam, vnam, newe any;

	  nnod := null;
	  -- the value passed is a selected node
	  if (length (xpath_eval ('name()', val)))
	    nnod := xpath_eval ('*|text()', val, 0);
	  else if (length (xpath_eval ('name(*)', val))) -- the value is xml fragment
	    nnod := xpath_eval ('*/*', val, 0);

	  nam := cast (xpath_eval ('name()', xq) as varchar);
	  newe := xml_tree_doc (sprintf ('<%s xmlns="%s"/>',
		  BPEL..get_nc_name (nam), BPEL..get_ns_uri (nam)));
	  XMLReplace (var, xq, newe);
	  xq := BPEL..xpath_evaluate (qry, var);

	  if (nnod is not null)
	    {
	      foreach (any elm in nnod) do
		{
		  XMLAppendChildren (xq, elm);
		}
              }
            else
              {
	       XMLAppendChildren (xq, val);
              }
          }
      else if ((txt := xpath_eval ('./node()', xq, 0)) is not null and length (txt) = 1)
          {
	    ent_to_ch := txt[0];
	    XMLReplace (var, ent_to_ch, val);
          }
      else
          {
	    ent_to_ch2 := xq;
            XMLAppendChildren (ent_to_ch2, val);
          }
    }
}
;

create method set_value (in inst int, in scope int, in scope_inst int, in val any) for BPEL.BPEL.place_vq
{
	declare ent, ent_to_ch, ent_to_ch2 any;
	declare var, qry, xq any;
	 --dbg_obj_print (self.ba_var, inst, scope, scope_inst);
	var := BPEL..get_var (self.ba_var, inst, scope, scope_inst, 0);
        if (isinteger (val))
          val := cast (val as varchar);
        --dbg_obj_print ('set_value, vq:',self,val);

	if (not isentity (var) or self.ba_query = '')
          {
            --dbg_obj_print ('no entity or no query nor part');
	    BPEL..set_var (SELF.ba_var, inst, scope, val, scope_inst);
	    return 1;
	  }

	qry := concat (self.bp_query_prefix, self.ba_query);
	set_value_to_var (qry, val, var);

	BPEL..set_var (SELF.ba_var, inst, scope, var, scope_inst);
	return 1;
}
;

create method set_value (in inst int, in scope int, in scope_inst int, in val any) for BPEL.BPEL.place_vpa
{
	declare var, qry, xq, sty any;
	 --dbg_obj_print (self.ba_var, inst, scope, scope_inst);
	var := BPEL..get_var (self.ba_var, inst, scope, scope_inst, 0);
        if (isinteger (val))
          val := cast (val as varchar);
        --dbg_obj_print ('set_value, vpa:',self,val);

	if (not isentity (var) or (self.ba_query = '' and self.ba_part = ''))
          {
            --dbg_obj_print ('no entity or no query nor part');
	    BPEL..set_var (SELF.ba_var, inst, scope, val, scope_inst);
	    return 1;
	  }

        qry := sprintf ('/message/part[@name="%s"]', self.ba_part);

	if (self.ba_query = '' and cast (xpath_eval (qry||'/@style', var) as varchar) = '0')
	  qry := concat (qry, '/', self.ba_part);

        if (self.ba_query = '')
          qry := concat (qry);
        else
          qry := concat (qry, self.ba_query);

	qry := concat (self.bp_query_prefix, qry);
	set_value_to_var (qry, val, var);
        --dbg_obj_print ('setting:', SELF.ba_var, ' val=',var);
	BPEL..set_var (SELF.ba_var, inst, scope, var, scope_inst);
	return 1;
}
;




create method get_value (in inst int, in scope int, in scope_inst int) for BPEL.BPEL.place_expr
{
   declare res any;
   --dbg_obj_print (inst,scope_inst,self.ba_exp);
   res := BPEL.BPEL.xpath_evaluate0 (self.bp_query_prefix || self.ba_exp);
   if (internal_type (res) = 225)
     return cast (res as varchar);
   else
     return res;
}
;

create method set_value (in inst int, in scope int, in scope_inst int, in val any) for BPEL.BPEL.place_expr
{
   return 1;
}
;

create method get_value (in inst int, in scope int, in scope_inst int) for BPEL.BPEL.place_plep
{
  declare url, res, wsauri varchar;
  declare opts any;
  declare cr cursor for select pl_endpoint, pl_opts from partner_link where pl_inst = inst and
	pl_scope_inst = scope_inst and pl_name = self.ba_pl and pl_role = self.ba_ep;

  res := null;
  wsauri := 'http://schemas.xmlsoap.org/ws/2003/03/addressing';
  whenever not found goto nf;
  open cr (prefetch 1);
  fetch cr into url, opts;
  if (opts is null)
    opts := '';
  else
    {
      wsauri := cast (xpath_eval ('/wsOptions/addressing/@version', opts) as varchar);
      opts := '<wsa:ReferenceProperties>' || serialize_to_UTF8_xml (opts) || '</wsa:ReferenceProperties>';
    }
  res := sprintf ('<wsa:EndpointReference xmlns:wsa="%s"><wsa:Address>%s</wsa:Address>%s</wsa:EndpointReference>', wsauri, coalesce (url, ''), opts);
  res := xtree_doc (res);
nf:
  close cr;
  return res;
}
;

create method set_value (in inst int, in scope int, in scope_inst int, in val any) for BPEL.BPEL.place_plep
{
   --dbg_obj_print (val);
   declare url, new_url, res varchar;
   declare opts any;
   declare cr cursor for select pl_endpoint from partner_link where pl_inst = inst and
	pl_scope_inst = scope_inst and pl_name = self.ba_pl and pl_role = self.ba_ep;

   if ((isstring (val) and length (val)) or isentity (val))
     {
       declare xp any;
       if (isentity (val))
	 xp := val;
       else
         xp := xml_tree_doc (val);
       new_url := xpath_eval ('string(/EndpointReference/Address)', xp);
       new_url := cast (new_url as varchar);
       if (length (new_url) = 0)
         new_url := null;
       opts := xpath_eval ('/EndpointReference/ReferenceProperties/wsOptions', xp);
       if (opts is not null)
	 opts := xml_cut (opts);
     }
   else
     new_url := null;

   whenever not found goto nf;
   open cr (prefetch 1);
   fetch cr into url;
   update partner_link set pl_endpoint = new_url, pl_opts = opts where current of cr;
nf:
   close cr;
   return 1;
}
;

--
-- I/O XXX: consider rewriting
--

create procedure set_io_request (in inst int, in val any)
{
  -- this is an exception ; consider other way
  insert soft BPEL..variables (v_inst, v_scope_inst, v_name, v_type)
	values (inst, 0, '@request@', 'any');
  BPEL..set_var ('@request@', inst, 1, val, 0);
}
;

create procedure get_io_request (in inst int)
{
  declare res any;
  res := BPEL..get_var ('@request@', inst, 1, 0);
  set_io_request (inst, null);
  return res;
}
;

create procedure set_io_result (in inst int, in val any)
{
  insert soft BPEL..variables (v_inst, v_scope_inst, v_name, v_type)
	values (inst, 0, '@result@', 'any');
  BPEL..set_var ('@result@', inst, 1, val, 0, 1);
}
;

create procedure get_io_result (in inst int)
{
  declare res any;
  insert soft BPEL..variables (v_inst, v_scope_inst, v_name, v_type)
	values (inst, 0, '@result@', 'any');
  res := BPEL..get_var ('@result@', inst, 1, 0, 1);
  set_io_result (inst, null);
  return res;
}
;

/* make WS-Addressing headers */
create procedure wsa_headers
	(
	in inst int,
	in plink varchar,
	inout ctx BPEL..ctx,
	in _to varchar,
	in _action varchar,
	in _replyto varchar,
	in wsa_cap int,
	in relates varchar := '',
	inout mid any,
	in wsa_ns varchar := 'http://schemas.xmlsoap.org/ws/2003/03/addressing',
	in wsa_pt varchar := '',
	in wsa_svc varchar := ''
	)
{
  declare wsa_to, wsa_mid, wsa_act, wsa_reply, wsa_relates, ret, wsu_ns any;
  declare pt, svc any;
  mid := 'uuid:' || lower (uuid ());
  -- XXX : tell other activities that can correlate with relates to
  if (wsa_cap)
    insert into BPEL..wsa_messages (wa_inst, wa_pl, wa_mid) values (inst, plink, mid);

  pt := null;
  svc := null;

  if (length (wsa_pt))
    pt := vector (composite (), '', wsa_pt);

  if (length (wsa_svc))
    svc := vector (composite (), '', wsa_svc);


  wsa_to := vector (composite (), vector ('Id', 'Id-'||uuid()) , _to);
  wsa_act := vector (composite (), vector ('Id', 'Id-'||uuid()), _action);
  wsa_mid := vector (composite (), vector ('Id', 'Id-'||uuid(), 'rootId', '0', 'parentId', '0', 'priority', '0'),
  				mid);
  wsa_reply := vector (composite (), vector ('Id', 'Id-'||uuid()),
  		'Address', _replyto,
                'PortType', pt,
                'ServiceName', svc
  	);
  wsa_relates := vector (composite (), vector ('Id', 'Id-'||uuid()), relates);

  ret := vector ();

  if (length (_to))
    {
      ret := vector_concat (ret,
                  vector (vector ('To', wsa_ns || ':To'), wsa_to)
		);
    }
  if (length (_action))
    {
      ret := vector_concat (ret,
                  vector (vector ('Action', wsa_ns || ':Action'), wsa_act)
		);
    }
  if (mid is not null)
    {
      ret := vector_concat (ret,
                  vector (vector ('MessageID', wsa_ns || ':MessageID'), wsa_mid)
		);
    }
  if (length (_replyto))
    {
      ret := vector_concat (ret,
                  vector (vector ('ReplyTo', wsa_ns || ':ReplyTo'), wsa_reply)
		);
    }
  if (length (relates))
    {
      ret := vector_concat (ret,
                  vector (vector ('RelatesTo', wsa_ns || ':RelatesTo'), wsa_relates)
	       );
    }

  return ret;
}
;

create procedure BPEL.BPEL.SOAP_CLIENT_CALLBACK (inout ses any, inout cd any)
{
  declare resp, msg, sec any;
  declare inst, node, rc, dummy, scp_inst, scp_id, mtype, style, deadlock_cnt, stat, audit int;
  declare script varchar;
  declare lc cursor for select lck from BPEL..lock where lck = 1;
  -- XXX: have exclusive lock on instance instaed

  set_user_id ('BPEL', 0);
  {
    declare exit handler for sqlstate '*' {
       resp := xtree_doc (soap_make_error ('300', __SQL_STATE, __SQL_MESSAGE));
       goto http_err;
    };
    resp := soap_receive (ses, 11, 64+128, sec);
    connection_set ('wss-keys', sec);
  }

  http_err:

  inst := cd [0];
  node := cd [1];
  script := cd [2];
  scp_inst := cd [3];
  scp_id := cd [4];
  mtype := cd [5];
  audit := cd [6];
  stat := cd [7];
  style := cd[8];

  deadlock_cnt := 0;

   --dbg_obj_print ('CALLBACK:', cd, resp);
   --dbg_obj_print ('CALLBACK CD:', cd);

   if (stat is not null)
     connection_set ('BPEL_stat', stat);
   connection_set ('BPEL_audit', audit);

  declare exit handler for sqlstate '40001'
    {
      --dbg_obj_print ('DEADLOCK inst=', inst, ' node=', node);
      rollback work;
      deadlock_cnt := deadlock_cnt + 1;
      if (deadlock_cnt > BPEL..max_deadlock_cnt ())
	{
	  BPEL..add_audit_entry (inst, -11, 'maximum deadlock retries count reached. Abort.');
	}
      else
	{
	  BPEL..add_audit_entry (inst, -1, 'Deadock is detected in the SOAP_CLIENT_CALLBACK, retrying...');
	  BPEL..send_error_mail (inst, __SQL_STATE, __SQL_MESSAGE);
	  delay (BPEL..deadlock_delay ());
	}
      goto again;
    };
 again:

  resp := xml_tree_doc (resp);
  --style := 1;
  if (xpath_eval ('//@encodingStyle', resp) = N'http://schemas.xmlsoap.org/soap/encoding/')
    style := 0;
  resp := xml_cut (xpath_eval ('/Envelope/Body', resp));
  -- XXX: operation & style must be defined
  --dbg_obj_print ('BODY RESPONSE:', resp);
  if (xpath_eval ('//Fault', resp) is null)
     msg := make_message_var (scp_id, resp, '*', mtype, style);
  else
     msg := resp;
  --dbg_obj_print ('RESPONSE to INVOKE:', msg);
  whenever not found default;
  open lc (exclusive, prefetch 1);
  fetch lc into dummy;
  if (stat is null)
    {
      update BPEL.BPEL.wait set bw_message = __xml_serialize_packed (msg), bw_state = 1,
      	bw_security = get_signing_info ()
	where bw_instance = inst and bw_node = node;
    }
  else
    {
      whenever not found goto notf;
      declare cw cursor for select bw_message, bw_start_date, bw_state, bw_partner_link, bw_port
				     from BPEL.BPEL.wait
				       where bw_instance = inst and bw_node = node;
      declare w_message any;
      declare s_date datetime;
      declare w_state int;
      declare w_plink, w_op varchar;
      open cw (prefetch 1);
      fetch cw into w_message, s_date, w_state, w_plink, w_op;
      update BPEL.BPEL.wait set bw_message = __xml_serialize_packed (msg), bw_state = 1,
      	bw_security = get_signing_info ()
	where current of cw;
      close cw;
      BPEL..stat_update_cum_wait (inst, scp_id, w_plink, w_op, s_date, now());
    notf:
      ;
    }
  commit work;

  declare deadlock_count int;
  deadlock_count := BPEL..max_deadlock_cnt ();
  declare exit handler for sqlstate '40001' {
    rollback work;
    if (deadlock_count > 0)
      {
	--dbg_printf ('Deadock [2]  %s %d', script, deadlock_count);
	BPEL..add_audit_entry (inst, -1, 'Deadock is detected in the SOAP_CLIENT_CALLBACK 2, retrying...');
	delay (BPEL..deadlock_delay());
	deadlock_count := deadlock_count - 1;
	goto again2;
      }
    BPEL..add_audit_entry (inst, -1, 'Deadock is detected in the SOAP_CLIENT_CALLBACK 2, resignal');
    BPEL..send_error_mail (inst, __SQL_STATE, __SQL_MESSAGE);
    signal ('BPELZ', 'Deadlock retry maximum count reached.');
  };
 again2:

  close lc;
  if (row_count () = 1)
    {
      --dbg_obj_print ('resuming instance:', inst, node);
      rc := BPEL..resume (inst, scp_id, null, node, scp_inst);
      --dbg_obj_print ('end resume rc=',rc, ' inst=', inst, ' node=', node);
    }
}
;

create procedure unregister_partner_wait (in  uid varchar)
{
  delete from BPEL.BPEL.wait where bw_uid = uid;
}
;

create procedure register_partner_wait (in inst int, in node int, inout inv BPEL.BPEL.invoke, inout ctx BPEL..ctx)
{
  declare uid varchar;
  uid := uuid ();
  insert into BPEL.BPEL.wait
    (
     bw_uid,
     bw_instance,
     bw_node,
     bw_script,
     bw_script_id,
     bw_scope,
     bw_partner_link,
     bw_port,
     bw_deadline,
     bw_correlation_exp,
     bw_expected_value,
     bw_message_type,
     bw_start_date,
     bw_from_comp
    )
    values
    (
     uid,
     inst,
     node,
     ctx.c_script,
     ctx.c_script_id,
     null,
     inv.ba_partner_link,
     inv.ba_operation,
     null,
     null,
     null,
     null,
     now (),
     inv.ba_in_comp
    );
  return uid;
}
;

create procedure BPEL..get_pl_options
			(
			inout pl_opts any,
			inout opts BPEL.BPEL.partner_link_opts,
			in inst int,
			in node int
			)
{
  declare xt, ekey, tmp, kn, rn, uname, upwd any;
  declare sk, wss_pkey, wss_skey, wss_sign, wsa_ver, func any;

  if (not isentity (pl_opts))
    return 0;

  wsa_ver := cast (xpath_eval ('/wsOptions/addressing/@version', pl_opts) as varchar);
  if (wsa_ver is not null)
    opts.pl_wsa_version := wsa_ver;
  wss_pkey := cast (xpath_eval ('/wsOptions/security/key/@name', pl_opts) as varchar);
  wss_skey := cast (xpath_eval ('/wsOptions/security/pubkey/@name', pl_opts) as varchar);

  opts.pl_in_enc := cast (xpath_eval ('/wsOptions/security/in/encrypt/@type', pl_opts) as varchar);
  opts.pl_in_sign := cast (xpath_eval ('/wsOptions/security/in/signature/@type', pl_opts) as varchar);
  opts.pl_in_tokens := xpath_eval ('/wsOptions/security/in/keys/key/@name', pl_opts, 0);

  uname := cast (xpath_eval ('/wsOptions/security/http-auth/@username', pl_opts) as varchar);
  upwd  := cast (xpath_eval ('/wsOptions/security/http-auth/@password', pl_opts) as varchar);

  if (length (uname) and length (upwd))
    {
      opts.pl_uid := uname;
      opts.pl_pwd := upwd;
    }

  ekey := cast (xpath_eval ('/wsOptions/security/out/encrypt/@type', pl_opts) as varchar);
  opts.pl_delivery := cast (xpath_eval ('/wsOptions/delivery/out[@type != "NONE"]/@type', pl_opts) as varchar);
  kn := sprintf ('SKEY-%d-%d', inst, node);
  -- if session key is already generated remove and make new one
  if (xenc_key_exists (kn))
    xenc_key_remove (kn);
  rn := md5 (datestring (now()));
  sk := null;
  if (ekey = '3DES')
    {
      sk := xenc_key_3DES_rand_create (kn);
    }
  else if (ekey = 'AES128')
    {
      sk := xenc_key_AES_create (kn, 128, md5 (rn));
    }
  else if (ekey = 'AES192')
    {
      sk := xenc_key_AES_create (kn, 192, md5 (rn));
    }
  else if (ekey = 'AES256')
    {
      sk := xenc_key_AES_create (kn, 256, md5 (rn));
    }
  --dbg_obj_print (user, xenc_key_exists (wss_skey));
  if (sk is not null and wss_skey is not null)
    opts.pl_keyinst := xenc_key_inst_create (kn, xenc_key_inst_create (wss_skey));
  wss_sign := cast (xpath_eval ('/wsOptions/security/out/signature/@type', pl_opts) as varchar);
  func := cast (xpath_eval ('/wsOptions/security/out/signature/@function', pl_opts) as varchar);
  if (wss_sign = 'Default' and wss_pkey is not null)
    opts.pl_signature := sprintf ('[%s]', wss_pkey);
  else if (wss_sign = 'Custom' and wss_pkey is not null)
    opts.pl_signature := sprintf ('[func:%s]', func);

  if (opts.pl_keyinst is not null or opts.pl_signature is not null)
    {
      opts.pl_auth := 'key';
      opts.pl_sec := 'encrypt';
    }
}
;

-- WSRM Acknowledgement
grant execute on DB.DBA.WSRMSequenceAcknowledgement to BPEL;

create procedure BPEL.BPEL.invoke_partner
		(
		in s_id int,
		in param varchar,
		in form int,
		in inst int,
		in node int,
		in inv BPEL.BPEL.invoke,
		inout ctx BPEL..ctx,
		in scp_inst int,
		in mtype varchar,
		inout mid varchar
		)
{
  declare endpoint, backup_endpoint varchar;
  declare ret, dt, headers, pars, opts any;
  declare pl, oper, hthdr varchar;
  declare is_sync, dbg, second_try int;
  declare wsopts BPEL.BPEL.partner_link_opts;
  declare cr cursor for select pl_endpoint, pl_backup_endpoint, pl_debug, pl_opts from partner_link where
    pl_inst = inst and pl_name = pl and  pl_scope_inst = scp_inst and pl_role = 1;

  wsopts := new BPEL.BPEL.partner_link_opts ();
  pl := BPEL.BPEL.dots_strip(inv.ba_partner_link);
   oper := inv.ba_operation;
  is_sync := inv.is_sync;

  endpoint := null;
  second_try := 0;
  dbg := 0;
  mid := null;
  hthdr := null;

  whenever not found goto nfpl;
  open cr (prefetch 1);
  fetch cr into endpoint, backup_endpoint, dbg, opts;
  BPEL..get_pl_options (opts, wsopts, inst, node);
  nfpl:
  close cr;

  if (length (wsopts.pl_uid) and length (wsopts.pl_pwd))
    {
      hthdr := sprintf ('Authorization: Basic %s\r\n', encode_base64 (concat (wsopts.pl_uid,':',wsopts.pl_pwd)));
    }

  --dbg_obj_print (wsopts);
  if (length (endpoint) = 0)
    endpoint := BPEL.BPEL.default_endpoint_base (ctx.c_host);

  for select ro_style, ro_endpoint_uri, ro_target_namespace, ro_use_wsa, ro_action,
  	ro_reply_port, ro_reply_service
    	from BPEL.BPEL.remote_operation
	where ro_script = s_id and ro_operation = oper and ro_partner_link = pl
	do {
		declare _style int;
	        declare conn, target_ns any;
                declare action varchar;
		_style := coalesce (ro_style, 0);
                action := ro_action;
		target_ns := ro_target_namespace;
		declare uid varchar;
		uid := null;
		declare direct int;
		if (is_sync = 1)
                  {
		    direct := 2;
                    uid := register_partner_wait (inst, node, inv, ctx);
		  }
                else
                  {
		    direct := 1;
		    hthdr := null;
		  }

		if (is_sync = 0)
		  {
                    declare replyto, relates varchar;
		    replyto := BPEL.BPEL.my_addr (ctx.c_script, ctx.c_host);
		    relates := '';
		    if (ctx.c_hdr is not null)
                      {
			relates := cast(xpath_eval ('string(//MessageID)', ctx.c_hdr) as varchar);
		      }
		    --dbg_obj_print ('relates', relates, ' inst=', inst, ' node=', node);
		    headers := BPEL..wsa_headers (inst, inv.ba_partner_link,
			ctx, endpoint, action, replyto, ro_use_wsa, relates, mid,
			wsopts.pl_wsa_version, ro_reply_port, ro_reply_service);
		  }
		else if (wsopts.pl_sec = 'encrypt')
                  {
		    headers := BPEL..wsa_headers (inst, inv.ba_partner_link,
			ctx, endpoint, action, null, 0, null, mid,
			wsopts.pl_wsa_version, ro_reply_port, ro_reply_service);
		  }
		else
		  headers := null;

                pars := make_params (param, _style);

		conn := null;
                dt := msec_time ();
		inv.add_audit_entry (inst, node, sprintf ('To: %s # %s', endpoint, oper));
		inv.add_audit_entry (inst, node, param);
		if (ctx.c_debug or dbg = 1)
                  {
                    declare endp varchar;
       	            endp := endpoint;
		    endpoint := sprintf (
			'http://localhost:%s/BPELGUI/debug.vsp?ep=%U&pl=%s&inst=%d&node=%d&oper=%s&scp=%d&sync=%d',
			server_http_port (), endpoint, pl, inst, node, oper, ctx.c_script_id, is_sync);
                  }
	    declare exit handler for sqlstate 'HTCLI'
		{
		  BPEL..stat_inc_pl_errors (inst, ctx.c_script_id, inv.ba_partner_link, inv.ba_operation);
		  if (second_try = 0 and length (backup_endpoint) > 0)
		    {
		      BPEL..add_audit_entry (inst, -1, sprintf ('Can not connect to %s, trying backup endpoint %s', endpoint, backup_endpoint));
		      endpoint := backup_endpoint;
		      second_try := 1;
		      goto again;
		    }
		  else
		    {
		      unregister_partner_wait (uid);
		      commit work;
		      ctx.c_full_err := BPEL..make_connection_error_string (__SQL_STATE, __SQL_MESSAGE,
					      inv.ba_partner_link,
					      inv.ba_type,
					      endpoint,
					      param);
		      signal ('BPELX', 'bpws:communicationFault');
		    }
		};
	again:
		BPEL..stat_update_n_inv (inst, ctx.c_script_id, inv.ba_partner_link, inv.ba_operation, pars);
		--dbg_obj_print ('wsopts=', wsopts);
		-- IMPORTANT: Transaction ends before SOAP Request, because it can take a lot of time
		commit work;

		declare deadlock_count int;
		deadlock_count := BPEL..max_deadlock_cnt ();
		declare exit handler for sqlstate '40001' {
		  rollback work;
		  if (deadlock_count > 0)
		    {
    		      BPEL..add_audit_entry (inst, -1, 'Deadock is detected in the invoke_partner, retrying...');
		      --dbg_printf ('Deadock [12] %d %d', inst, deadlock_count);
		      delay (BPEL..deadlock_delay());
		      deadlock_count := deadlock_count - 1;
		      goto again2;
		    }
    		  BPEL..add_audit_entry (inst, -1, 'Deadock is detected in the invoke_partner, resignal');
		  signal ('BPELZ', 'Deadlock retry maximum count reached.');
		};
	again2:


                if (wsopts.pl_delivery is not null and not is_sync)
                  {
		    declare addr DB.DBA.wsa_cli;
		    declare cli DB.DBA.wsrm_cli;
		    declare req DB.DBA.soap_client_req;

		    addr := new DB.DBA.wsa_cli ();
		    addr."to" := endpoint;
		    addr."from" := BPEL.BPEL.default_endpoint_base (ctx.c_host);
		    addr.reply_to := BPEL.BPEL.my_addr (ctx.c_script, ctx.c_host);
		    addr.action := action;
		    addr.mid := mid;

		    req := new DB.DBA.soap_client_req ();
		    req.url := addr."to";
		    req.operation := oper;
		    req.style := _style;
		    req.parameters := pars;

		    req.soap_action := action;
		    req.target_namespace := target_ns;
		    req.auth_type := wsopts.pl_auth;
		    req.ticket := wsopts.pl_keyinst;
		    req.security_type := wsopts.pl_sec;
		    req.template := wsopts.pl_signature;
		    req.security_schema := wss_oasis_ns ();

		    cli := new DB.DBA.wsrm_cli (addr, addr."to");
		    --cli.set_parameter ('Assurance', 'InOrder');
		    --cli.send_message (req);
		    cli.finish (req);

		    ret := null;
		  }
                else
                  {
		    --dbg_obj_print ('Invoke', endpoint,oper,direct);
		    ret := DB.DBA.SOAP_ASYNC_CLIENT (
			url=>endpoint,
			soap_action=>action,
			operation=>oper,
			parameters => pars,
			style => (_style + form),
			direction => direct,
			headers => headers,
			target_namespace=>target_ns,
			conn => conn,
			time_out => 10000,
			-- HTTP Authentication
			http_header=>hthdr,
			user_name=>wsopts.pl_uid,
			user_password=>wsopts.pl_pwd,
			-- WS-Security options
			auth_type=>wsopts.pl_auth,
			ticket=>wsopts.pl_keyinst,
			security_type=>wsopts.pl_sec,
			template=>wsopts.pl_signature,
			security_schema => wss_oasis_ns ()
			);
		  }
		prof_sample ('BPEL invoke', msec_time () - dt, 1);
 		if (is_sync = 1)
                  {
		    if (ret is null)
                      {
			http_on_message (conn, 'BPEL.BPEL.SOAP_CLIENT_CALLBACK',
			    vector (inst, node, ctx.c_script, scp_inst,
				ctx.c_script_id, mtype, connection_get ('BPEL_audit'),
				connection_get ('BPEL_stat'), _style));
                      }
		    else
                      {
			-- zero time of wait
			delete from BPEL.BPEL.wait where bw_instance = inst and bw_node = node;
		      }
		  }
                return ret;
	}
}
;


--
-- MAIN
-- all requests go here
--


/**/
--
-- using new interpreter
--
create procedure BPEL.BPEL.schedule_request
		(
		in script varchar,
		in action varchar,
		in body any,
		in hdr any,
		in style int,
		in host varchar
		)
{
        declare inst, wnode, stat, mtype, dummy, script_id int;
	declare correlation_exp, expected_value any;
	declare op_name, rpc_oper, imsg, omsg varchar;
	declare mesg any;
	declare inst_partner_lnk varchar;
	declare audit, stat_on, n_create, send_repl int;

	declare cr cursor for select bw_instance, bw_correlation_exp, bw_expected_value, bw_node, bw_message_type,
			bw_port, bw_script_id
         		from BPEL.BPEL.wait where bw_script = script
			and (rpc_oper is null or bw_port = rpc_oper)
			and bw_message_type is not null;

        declare lc cursor for select lck from BPEL..lock where lck = 1;

        declare cr_scp cursor for select bs_audit, bs_n_create, bs_id from BPEL.BPEL.script
					       where bs_name = script and bs_state = 0;

	send_repl := 1;

	if (not style)
	  rpc_oper := cast(xpath_eval ('local-name (/Body/*[1])', body) as varchar);
	else
	  rpc_oper := null;

        whenever not found default;
	declare deadlock_count int;
	deadlock_count := BPEL..max_deadlock_cnt ();
	inst := -1;
	declare exit handler for sqlstate 'BPELZ' {
	  BPEL..send_error_mail (inst, __SQL_STATE, __SQL_MESSAGE);
	};
	declare exit handler for sqlstate '40001' {
	  rollback work;
	  if (deadlock_count > 0)
	   {
	      --dbg_printf ('Deadock [2]  %s %d', script, deadlock_count);
	      delay (BPEL..deadlock_delay());
	      deadlock_count := deadlock_count - 1;
	      goto again2;
	   }
	  BPEL..send_error_mail (inst, __SQL_STATE, __SQL_MESSAGE);
	  signal ('BPELZ', 'Deadlock retry maximum count reached.');
	};
 again2:

        open lc (exclusive, prefetch 1);
        fetch lc into dummy;
        --dbg_obj_print (hdr);
        --dbg_obj_print (body);
        BPEL..dbg_printf ('IN schedule_request');
	whenever not found goto notwait;

	open cr (prefetch 1);

	while (1)
	  {
	    imsg := null; omsg:= null; mesg := null;
	    fetch cr into inst, correlation_exp, expected_value, wnode, mtype, op_name, script_id;
		-- check for waiting that matches message which is arrived
		--dbg_printf ('Wait node test: %d %d', inst, wnode);
	   {
	     declare in_xp varchar;
	     whenever not found goto next_wait;
	     select bo_input, bo_output, bo_input_xp into imsg, omsg, in_xp from BPEL..operation where
	         bo_script = script_id and bo_name = op_name;
             if (style and xpath_eval (in_xp, body) is null)
	       goto next_wait;
	     mesg := make_message_var (script_id, body, op_name, imsg, style);
	   }
		if (length (correlation_exp))
                  {
                    declare v, org, ment any;

		    if (mtype and hdr is null)
                      goto next_wait;

		    org := blob_to_string (expected_value);
                    if (mtype)
                      ment := xml_cut (hdr);
                    else
		      ment := xml_cut (mesg);
		    v := xpath_eval (correlation_exp, ment);
		    --dbg_obj_print (ment);
		    --dbg_obj_print ('CORRELATION:', correlation_exp,v,org);
                    if (v <> org)
                      goto next_wait;
                    --dbg_obj_print ('wait matched:' , v);
		  }
            --dbg_obj_print ('schedule_request matched a message', op_name, mesg, body, hdr);
	    close cr;
	    --dbg_obj_print ('1 is it one way:', omsg, send_repl);
            if (send_repl and length (omsg) = 0 and not http_is_flushed ()) -- OneWay operation
              {
	        http_request_status ('HTTP/1.1 200 OK');
                http (BPEL..make_empty_soap_env ());
	        http_flush();
	        send_repl := 0;
	      }

	     commit work;
	     declare exit handler for sqlstate '40001' {
	       rollback work;
	       if (deadlock_count > 0)
		 {
    	           BPEL..add_audit_entry (inst, -1, 'Deadock is detected in the schedule_requset, retry');
		   --dbg_printf ('Deadock [1] %s %d %d',script, inst,  deadlock_count);
		   deadlock_count := deadlock_count - 1;
		   goto again1;
		 }
    	       BPEL..add_audit_entry (inst, -1, 'Deadock is detected in the schedule_requset, resignal');
	       BPEL..send_error_mail (inst, __SQL_STATE, __SQL_MESSAGE);
	       signal ('BPELZ', 'Deadlock retry maximum count reached.');
	     };
	  again1:

	     --dbg_printf ('RESUMING %d', inst);
             declare rc int;
 	     update BPEL.BPEL.wait set bw_message = __xml_serialize_packed (mesg),bw_state = 1,
      	        bw_security = get_signing_info ()
	     	where bw_instance = inst and bw_node = wnode;
	     rc := BPEL..resume (inst, script_id, null, wnode);
	     return null;
	     if (not rc)
               {
	         BPEL..dbg_printf ('INSTANCE IS ALREADY RUNNING %d rc=%d', inst, rc);
                 -- what we will do if syncronous connection is it?
                 return NULL;
               }
             else
               {
                 delete from BPEL.BPEL.wait where bw_instance = inst and bw_node = wnode;
	         BPEL..dbg_printf ('FINISHED RESUMING %d row=[%d]', inst, row_count());
	         return null; --BPEL..get_io_result (inst);
               }
next_wait:;

	  }
notwait:
        close cr;
	whenever not found goto nosuchscp;
	open cr_scp (exclusive, prefetch 1);
	fetch cr_scp into audit, n_create, script_id;


	imsg := null; omsg:= null; mesg := null; op_name := null;
            if (not style)
              {
		select bo_input, bo_output into imsg, omsg from BPEL..operation where
		  bo_script = script_id and bo_name = rpc_oper;
		op_name := rpc_oper;
              }
            else -- literal style
              {
                for select bo_name, bo_action, bo_input as message, bo_output, bo_input_xp
		   from BPEL..operation where bo_script = script_id do
                  {
		    --dbg_obj_print ('bo_name', bo_name, bo_input_xp);
                    if (xpath_eval (bo_input_xp, body) is not null)
                      {
                        --dbg_obj_print ('found', message);
                        if (op_name is null or bo_action = action)
                          {
			    op_name := bo_name;
			    imsg := message;
			    omsg := bo_output;
                          }
                      }
                  }
                if (op_name is not null)
		  goto runit;
                goto nosuchscp;
              }
	runit:
	--dbg_obj_print ('2 is it one way:', omsg, send_repl);
        if (send_repl and length (omsg) = 0 and not http_is_flushed ()) -- OneWay operation
          {
	    http_request_status ('HTTP/1.1 200 OK');
            http (BPEL..make_empty_soap_env ());
	    http_flush();
	    send_repl := 0;
	  }
	mesg := make_message_var (script_id, body, op_name, imsg, style);

	inst_partner_lnk := null;
	for select bo_partner_link from BPEL.BPEL.operation
	     where bo_script = script_id and bo_name = op_name and bo_init = 1
	do
	   {
	     inst_partner_lnk := bo_partner_link;
	   }
	if (inst_partner_lnk is not null)
	  {

	    stat_on := BPEL..get_conf_param ('Statistics', 0);
	    connection_set ('BPEL_audit', audit);
	    -- in stepping mode allow request to get it's response and wait
            --dbg_obj_print ('BPEL_reply_sent', send_repl);
	    connection_set ('BPEL_reply_sent', send_repl);
	    if (stat_on)
	      {
		connection_set ('BPEL_stat', 1);
		update BPEL.BPEL.script set bs_n_create = n_create+1 where current of cr_scp;
	      }
	    close cr_scp;
	    commit work;
	    declare exit handler for sqlstate '40001' {
	    rollback work;
	      if (deadlock_count > 0)
		{
		  BPEL..add_audit_entry (inst, -1, 'Deadock is detected in the schedule_requset 3, retry');
		  --dbg_printf ('Deadock [3] %s %d %d',script, inst,  deadlock_count);
		  deadlock_count := deadlock_count - 1;
		  goto again3;
		}
	      BPEL..add_audit_entry (inst, -1, 'Deadock is detected in the schedule_requset 3, resignal');
	      BPEL..send_error_mail (inst, __SQL_STATE, __SQL_MESSAGE);
	      signal ('BPELZ', 'Deadlock retry maximum count reached.');
	    };
	  again3:
	    --dbg_obj_print ('Initiate a new instance', mesg);
	    inst := BPEL..run (script_id, mesg, hdr, op_name, host);
	    --dbg_printf ('Finished run of instance inst=%d',inst);
	    commit work; -- no updates after this
	    return null; --BPEL..get_io_result (inst);
	  }
	else
	 {
	    declare hdr1 any;
	    --dbg_printf ('Put into a queue hdr=%d args=%d', isnull (hdr), isnull (mesg));
            if (hdr is not null)
	      hdr1 := __xml_serialize_packed (hdr);
            else
	      hdr1 := null;
	    insert into BPEL.BPEL.queue (bq_state, bq_op, bq_message, bq_header, bq_script, bq_security)
			values (0, op_name, __xml_serialize_packed (mesg), hdr1, script_id, get_signing_info ());
	    commit work; -- no updates after this
	    return;
	 }
   return;
   nosuchscp:
   signal ('22023', 'No such operation');
}
;



-- TODO: Important
-- The bellow must be done in C , wrappers to the soap_serialize etc.
create procedure soap_11_env (in oper varchar, in style int, inout var_val any, in fault any)
{
  declare s, xq any;
  declare exit handler for sqlstate '*' {
		xq := xtree_doc (soap_make_error ('300', __SQL_STATE, __SQL_MESSAGE));
		goto sen;
  };
  if (fault is not null)
    {

      s := sprintf ('<stub xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/"><SOAP:Envelope xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/"
	 xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/"
	 %s
	 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	 xmlns:xsd="http://www.w3.org/2001/XMLSchema"
	 xmlns:dt="urn:schemas-microsoft-com:datatypes"
	 xmlns:ref="http://schemas.xmlsoap.org/ws/2002/04/reference/">
	<SOAP:Body><SOAP:Fault><faultcode>%s</faultcode><faultstring>%s</faultstring><detail>{for \$i in /message/part/* return \$i}</detail></SOAP:Fault></SOAP:Body></SOAP:Envelope></stub>',
	case when style then '' else 'SOAP:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/' end, fault, fault);
    }
  else if (style)
    {
      s := '<stub xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/"><SOAP:Envelope xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/"
	 xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/"
	 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	 xmlns:xsd="http://www.w3.org/2001/XMLSchema"
	 xmlns:dt="urn:schemas-microsoft-com:datatypes"
	 xmlns:ref="http://schemas.xmlsoap.org/ws/2002/04/reference/">
	<SOAP:Body>{for \$i in /message/part/* return \$i}</SOAP:Body></SOAP:Envelope></stub>';
     }
   else
     {
       s := sprintf ('<stub xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/"><SOAP:Envelope xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/"
	 xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/"
	 SOAP:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
	 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	 xmlns:xsd="http://www.w3.org/2001/XMLSchema"
	 xmlns:dt="urn:schemas-microsoft-com:datatypes"
	 xmlns:ref="http://schemas.xmlsoap.org/ws/2002/04/reference/">
	<SOAP:Body><%sResponse>{for \$i in /message/part/* return \$i}</%sResponse></SOAP:Body></SOAP:Envelope></stub>',
	oper, oper);
     }
   xq := xquery_eval (s, var_val);
   xq := xml_cut (xpath_eval ('/stub/Envelope', xq));
   sen:
   --dbg_obj_print (xq);
   return xq;
}
;

create procedure make_empty_soap_env ()
{
  return '<SOAP:Envelope xmlns:SOAP="http://schemas.xmlsoap.org/soap/envelope/"><SOAP:Body /></SOAP:Envelope>';
}
;

-- Audit stuff
--
--

create method add_audit_entry (in inst int, in node int, in info any) for BPEL.BPEL.activity
{
  BPEL..add_audit_entry (inst, node, info);
}
;

create procedure BPEL..add_audit_entry (in inst int, in node int, in info any)
{
  if (connection_get ('BPEL_audit') <> 1)
    return 0;

  declare exit handler for sqlstate '*', not found
  {
    rollback work;
    --dbg_printf ('Error in BPEL..add_audit_entry: %s', __SQL_MESSAGE);
    return;
  };
  BPEL..make_audit_dir();

  declare cr cursor for select (bg_activity as BPEL.BPEL.activity).ba_type from BPEL.BPEL.graph,
  	BPEL.BPEL.instance where
		bg_script_id = bi_script
		and bi_id = inst
		and bg_node_id = node;
  declare fn_cr cursor for select bs_name from BPEL.BPEL.instance, BPEL.BPEL.script
  	where bi_id = inst and
		bi_script = bs_id;
  declare _id int;
  declare info_str varchar;
  declare act_name varchar;

  if (node = -11)
    {
      act_name := 'Error';
    }
  if (node = -12)
    {
      act_name := 'RecoverableError';
    }
  else if (node = -2)
    {
      act_name := 'ScriptEnded';
    }
  else if (node = -13)
    {
      act_name := 'UnhandledException';
    }
  else if (node = -4)
    {
      act_name := 'Retry';
    }
  else if (node < 0)
    {
      act_name := '';
    }
  else
    {
      open cr (prefetch 1);
      fetch cr into act_name;
      close cr;
    }
  info_str := info;
  declare x any;
  declare dt, old_dt varchar;
  dt := substring (cast (now() as varchar), 1, 19);
  x := string_output ();
  if (node < -10)
    http ('[ERROR][', x);
  else if (node < 0)
    http ('[WARN ][', x);
  else
    http ('[INFO ][', x);
  old_dt := connection_get ('BPEL/Audit/LastDate');
  if ((old_dt is null) or (old_dt <> dt))
    {
      http (dt, x);
      connection_set ('BPEL/Audit/LastDate', dt);
    }

  http (']', x);
  if (node < 0)
    http_value ('',null,x);
  else
    http_value (node,null,x);
  http (':', x);
  http (act_name, x);
  http (': ', x);
  if (info is not null)
    {
	declare y any;
	declare str varchar;
	declare inx integer;
	y := string_output();
	if (isstring (info))
	  http (info, y);
	else
	  http_value (info, null, y);
	str := replace (replace (string_output_string(y), '\n', ' '), '\r', ' ');
	inx := 1;
	if (length (str) > 80)
	  {
	    while (inx < length (str))
	      {
		http (substring (str,inx, 80), x);
--		http (' ', x);
		inx := inx + 80;
	      }
	  }
	else
	  http (str, x);
    }
  http ('\r\n', x);
  info_str := string_output_string (x);
  _id := 0;
  declare fn varchar;
  declare bpel_nm varchar;
  open fn_cr (prefetch 1);
  fetch fn_cr into bpel_nm;
  close fn_cr;
  BPEL..append_entry_to_audit (info_str, inst, bpel_nm);
}
;

create procedure reply_fault_to_client (inout conn any, inout var_val any)
{
  declare s any;
  ses_write ('HTTP/1.1 500 Internal Server Error\r\n', conn);
  ses_write ('Content-Type: text/xml\r\n', conn);
  ses_write (sprintf ('Content-Length: %d\r\n', length (var_val)), conn);
  ses_write ('Server: Virtuoso (BPEL 1.0)\r\n\r\n', conn);
  ses_write (var_val, conn);
}
;

create procedure wss_oasis_ns ()
{
  return
   vector (
		'wsse', DB.DBA.WSSE_OASIS_URI (),
		'wsu', DB.DBA.WSSU_OASIS_URI ()
          );
}
;

create procedure make_reply_to_client (inout var_val any, in oper varchar, in style int, inout opts BPEL.BPEL.partner_link_opts, in fault any)
{
  declare resp, s, retval, body, templ any;

  resp := soap_11_env (oper, style, var_val, fault);
  if (opts.pl_keyinst is not null or opts.pl_signature is not null)
    resp := xslt ('http://local.virt/wsrp_resp', resp, vector ('routing', 0, 'b_id', lower(uuid()),
	'wsu', DB.DBA.WSSU_OASIS_URI ()));
  s := string_output ();
  http_value (resp, null, s);
  resp := string_output_string (s);

  templ := opts.pl_signature;
  if (templ like '^[%^]' escape '^')
  {
     templ := trim (templ, '[]');
     if ("LEFT" (templ, 5) = 'func:')
       {
          templ := subseq (templ, 5);
          templ := call (templ) (resp);
       }
     else
       templ := DB.DBA.SOAP_DEFAULT_XENC_TEMPLATE (resp, templ, vector ());
  }


  if (opts.pl_keyinst is not null)
    body := xenc_encrypt (resp, 11, templ, wss_oasis_ns (), '//Envelope/Body[*]', opts.pl_keyinst, 'Content');
  else if (templ is not null)
    body := xenc_encrypt (resp, 11, templ, wss_oasis_ns ());
  else
    body := resp;
  --dbg_obj_print (body);
  return body;
}
;

create procedure reply_to_client (inout conn any, inout resp any, in fault any)
{
  if (not length (fault))
    ses_write ('HTTP/1.1 200 OK\r\n', conn);
  else
    ses_write ('HTTP/1.1 500 Server Error\r\n', conn);
  ses_write ('Content-Type: text/xml\r\n', conn);
  ses_write (sprintf ('Content-Length: %d\r\n', length (resp)), conn);
  ses_write ('Server: Virtuoso (BPEL 1.0)\r\n\r\n', conn);
  ses_write (resp, conn);
}
;


create procedure make_message_var (in scp_id int, inout body any, in operation varchar, in message varchar,in style int)
{
  declare args, parts any;
  args := string_output ();
  if (style = 0)
    {
	http (sprintf ('<message name="%s">', BPEL..get_nc_name (message)), args);
	parts := xpath_eval (sprintf ('/Body/%s/*', operation), body, 0);
	foreach (any elm in parts) do
	  {
	    declare pname, pval, ns, nspref any;
	    pname := cast (xpath_eval ('local-name (.)', elm) as varchar);
	    ns := cast (xpath_eval ('namespace-uri (.)', elm) as varchar);
	    nspref := '';
	    if (length (ns))
	      nspref := 'ns:';
	    pval := xquery_eval (sprintf ('declare namespace ns="%s";<part name="%s" style="0">{ for \$i in /%s%s return \$i }</part>',
		ns, pname, nspref, pname),
		xml_cut (elm));
	    http_value (pval, null, args);
	  }
	http ('</message>', args);
    }
  else
    {
	http (sprintf ('<message name="%s">', BPEL..get_nc_name (message)), args);
	for select mp_part, mp_xp from BPEL..message_parts where
	  mp_script = scp_id and mp_message = BPEL..get_nc_name (message) do
	{
	  declare elm any;
	  http (sprintf ('<part name="%s" style="1">', mp_part), args);
	  elm := xpath_eval (mp_xp, body);
	  if (elm is not null)
	    http_value (elm, null, args);
	  http ('</part>', args);
	}
	http ('</message>', args);
    }
  return xtree_doc (string_output_string (args));
}
;

create procedure make_params (in var_val any, in style int)
{
  declare pars, parts any;
  declare i, l int;
  parts := xquery_eval ('for \$i in /message/part/* return \$i', xml_cut (var_val), 0);
  l := length (parts) * 2;
  pars := make_array (l, 'any');
  for (i := 0; i < l; i := i + 2)
    {
      pars[i] := sprintf ('param%d', i/2);
      pars[i + 1] := parts[i/2];
    }
  return pars;
}
;


create procedure BPEL..log_error (in stat any, in msg any)
{
  declare fn, lmsg, lstat, lmsg1, str, email varchar;
  declare lev int;

  set isolation='committed';

  lev := 3;

  declare exit handler for sqlstate '*' {
    rollback work;
    BPEL..send_error_alert (str);
    return;
  };


  if (stat = 'BPELR')
    {
      declare xp any;
      xp := xml_tree_doc (msg);
      lstat := xpath_eval ('/comFault/@sqlState', xp);
      lmsg := xpath_eval ('/comFault/@message', xp);
      lev := 2;
    }
  else
    {
      if (isstring (stat) and stat like '40%')
        lev := 1;
      lstat := stat;
      lmsg := msg;
    }

  lmsg1 := regexp_match ('[^\r\n]*', lmsg);
  str := sprintf ('[%s][%s][%s]\r\n',
	case lev when 1 then 'FATAL' when 2 then 'NETWORK' else 'INSTANCE' end,
	lstat, lmsg1);

  BPEL..make_audit_dir();
  fn := sprintf ('%s/server_log.txt', BPEL..audit_dir ());
  string_to_file (fn, sprintf ('%s ', substring (cast (now() as varchar), 1, 19)) || str, -1);
  insert into BPEL.BPEL.error_log (bel_level, bel_notice_sent, bel_text) values (lev, null, str);
  return;
}
;
