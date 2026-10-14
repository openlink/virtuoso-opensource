--
--  tvvec_redo_after_create.sql -- phase 1 of tvvec_redo_after_create.sh
--
--  Leaves a transaction log whose tail holds the database's first vector
--  index: its CREATE, the metadata view that CREATE installs, the index's rows
--  and every LOG_VEC_PAGE image of its graph -- all after the last checkpoint.
--  The driver then stops the server without a checkpoint and phase 2 asserts
--  what roll forward made of it.
--
--  Three things are riding on that log:
--
--  * The graph's page images cannot be applied: the index's pages were
--    allocated after the checkpoint, so none of them is in a checkpointed
--    extent map.  Once the first record is refused the graph is rebuilt from
--    the embeddings, so every later record is dead work -- and must not log a
--    line each.
--  * The metadata view installer runs as a server init statement.  Run before
--    roll forward, it finds its registry flag missing (the flag is in the
--    log, not the checkpoint) and installs the view a second time, unlogged,
--    with IRI ids taken from the checkpointed sequence -- the same ids the
--    logged CREATE then reuses for other names.
--  * The bundled model's max_seq_len is operator tuning that the startup
--    re-registration must leave alone.  It is set BEFORE the checkpoint, so
--    that roll forward cannot restore it by accident.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2026 OpenLink Software
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

echo BOTH "STARTED: redo of a vector index created after the last checkpoint (phase 1)\n";

select DB.DBA.ONNX_REGISTRY_INIT ();
delete from DB.DBA.ONNX_MODELS where model_name = 'trac-64';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('trac-64', 'redo-after-create test model', 'internal:trac-64', 'test_embedding', 'embedding', '1,64', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register trac-64 STATE=" $STATE "\n";

--  Operator tuning on the bundled model.  Only meaningful when the ONNX
--  plugin registered it; TRAC_EXPECT records whether it did.
create table DB.DBA.TRAC_EXPECT (K varchar primary key, V integer);
update DB.DBA.ONNX_MODELS set max_seq_len = 128 where model_name = 'granite-384-local';
insert replacing DB.DBA.TRAC_EXPECT (K, V)
  values ('granite', (select count (*) from DB.DBA.ONNX_MODELS where model_name = 'granite-384-local'));
commit work;

--  So that the CREATE below is what installs the metadata view.
select DB.DBA.VEC_INDEX_META_VIEW_DROP ();
select case when coalesce (registry_get ('__vec_meta_view'), '') = '' then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": precondition -- the metadata view is not installed, ok=" $LAST[1] "\n";

checkpoint;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": checkpoint -- everything below exists only in the transaction log\n";

--  300 subjects.  "doc a b" puts 1.0 at a (0..31) and b (32..41), so every
--  subject has its own vector and a search for one's text finds it first.
create procedure DB.DBA.TRAC_LOAD ()
{
  declare k integer;
  for (k := 0; k < 300; k := k + 1)
    DB.DBA.RDF_QUAD_URI_L ('urn:trac:g', sprintf ('urn:trac:d%d', k), 'urn:trac:text',
        sprintf ('doc %d %d', mod (k, 32), 32 + k / 32));
  commit work;
}
;
DB.DBA.TRAC_LOAD ();

sparql define input:storage ""
create vector index <urn:trac:idx>
  on graph <urn:trac:g>
  for predicate <urn:trac:text>
  using model 'trac-64'
  with (dimensions = 64, distance = 'cosine', maintenance = 'manual', label = 'Redo after create')
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create <urn:trac:idx> STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--  Incremental linking: one graph page per node, each one a LOG_VEC_PAGE record.
select DB.DBA.VEC_INDEX_REFRESH ('urn:trac:idx');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": refresh STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select get_keyword ('graph_nodes', __VEC_INDEX_METRICS (DB.DBA.VEC_INDEX_GENERATE_NAME ('urn:trac:idx')));
ECHO BOTH $IF $EQU $LAST[1] 300 "PASSED" "***FAILED";
ECHO BOTH ": precondition -- graph_nodes=" $LAST[1] " before the crash\n";

select case when registry_get ('__vec_meta_view') = DB.DBA.VEC_INDEX_META_VIEW_VERSION () then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": precondition -- the CREATE installed the metadata view, ok=" $LAST[1] "\n";

sparql select count (*) from <urn:vvec:indexes>
  where { <urn:trac:idx> <http://www.w3.org/2000/01/rdf-schema#label> ?o };
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": precondition -- the view publishes the label, n=" $LAST[1] "\n";

echo BOTH "COMPLETED: phase 1 -- the driver now stops the server without a checkpoint\n";
