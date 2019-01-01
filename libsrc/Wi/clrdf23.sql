--
--  $Id$
--
--  Migrate to 2+3 layout
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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


cl_exec ('__dbf_set (''cl_max_keep_alives_missed'', 1000)');

drop index RDF_QUAD_OGPS;
drop index RDF_QUAD_OPGS;
drop index RDF_QUAD_POGS;
drop index RDF_QUAD_GPOS;
drop index RF_O;
drop table RDF_FT;

cl_exec ('checkpoint');
create table R2 (G iri_id_8, S iri_id_8, P iri_id_8, O any, primary key (P, S, O, G))
alter index R2 on R2 partition (S int (0hexffff00));

create procedure rq_copy ()
{
  declare gr any;
  log_enable (2);
  gr := iri_to_id (jso_sys_graph ());
  insert into R2 option (no cluster) (G, S, P, O) select G, S, P, ro_id_only (DB.DBA.RDF_OBJ_OF_SQLVAL (O)) from rdf_quad table option (no cluster, index rdf_quad) where g <> gr;
}

create procedure ro_id_only (in o any)
{
  if (is_rdf_box (o)
      and isstring (rdf_box_data (o)))
    {
      -- dbg_obj_princ ('ro_id_only sets flag to 2');
      rdf_box_set_is_text (o, 2);
      return o;
    }
  return o;
}


create procedure AQ_EXEC_SRV (in cmd varchar)
{
  declare st, msg any;
  st := '00000';
  exec (cmd, st, msg, vector ());
  if ('00000' <> st)
    signal (st, msg);
}


create procedure exec_from_daq (in cmd varchar)
{
  declare aq any;
 aq := async_queue (1);
  aq_request (aq, 'DB.DBA.AQ_EXEC_SRV', vector (cmd));
  aq_wait_all (aq);
}


log_enable (2);

cl_exec ('exec_from_daq (''rq_copy ()'')');


cl_exec ('checkpoint');

delete from sys_vt_index where vi_table = 'DB.DBA.RDF_QUAD';
drop table RDF_QUAD;
alter table r2 rename RDF_QUAD;
cl_exec ('checkpoint');


create bitmap index_no_fill index RDF_QUAD_POGS on RDF_QUAD (P, O, G, S) partition (O varchar (-1, 0hexffff));
create distinct no primary key ref bitmap index_no_fill index RDF_QUAD_SP on RDF_QUAD (S, P) partition (S int (0hexffff00));
create distinct no primary key ref bitmap index_no_fill index RDF_QUAD_GS on RDF_QUAD (G, S) partition (S int (0hexffff00));
create distinct no primary key ref index_no_fill index RDF_QUAD_OP on RDF_QUAD (O, P) partition (O varchar (-1, 0hexffff));
RDF_GEO_INIT ();

--cl_exec ('insert soft rdf_quad index rdf_quad_gs option (no cluster) (g, s) select g, s from rdf_quad table option (no cluster, index rdf_quad)');
--cl_exec ('insert soft rdf_quad index rdf_quad_sp option (no cluster)(s, p) select s, p from rdf_quad table option (no cluster, index rdf_quad)');
insert into rdf_quad index rdf_quad_pogs (g, s, p, o) select g, s, p, o from rdf_quad table option (index rdf_quad);
--cl_exec ('insert soft rdf_quad index rdf_quad_op option (no cluster)(o, p) select o, p from rdf_quad table option (no cluster, index rdf_quad_pogs)');

create procedure fill_rdf_inx ()
{
  log_enable (2, 1);
  insert soft rdf_quad index rdf_quad_gs option (no cluster) (g, s) select g, s from rdf_quad table option (no cluster, index rdf_quad);
  insert soft rdf_quad index rdf_quad_sp option (no cluster)(s, p) select s, p from rdf_quad table option (no cluster, index rdf_quad);
  insert soft rdf_quad index rdf_quad_op option (no cluster)(o, p) select o, p from rdf_quad table option (no cluster, index rdf_quad_pogs);
}
;

cl_exec ('fill_rdf_inx ()');

cl_exec ('registry_set (''rdf_no_string_inline'', ''1'')');

cl_exec ('checkpoint');


insert into DB.DBA.RO_START (RS_START, RS_DT_AND_LANG, RS_RO_ID)
  select subseq (coalesce (blob_to_string (RO_LONG), RO_VAL), 0, case when length (coalesce (blob_to_string (RO_LONG), RO_VAL)) > 10 then 10 else length (coalesce (blob_to_string (RO_LONG), RO_VAL)) end), RO_DT_AND_LANG, rdf_box (0, 257, 257, RO_ID, 0) from DB.DBA.RDF_OBJ;

create procedure cl_clear_cache ()
{
  __atomic (1);
  cl_exec ('iri_id_cache_flush ()', txn => 1);
  commit work;
  __atomic (0);
}


delete from DB.DBA.RDF_QUAD where G = iri_to_id (DB.DBA.JSO_SYS_GRAPH ());

cl_clear_cache ();

--cl_qm_init ();

cl_exec ('shutdown');



