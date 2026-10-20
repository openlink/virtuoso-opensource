--
--  tvvec_redo_after_create_reopen.sql -- phase 2 of tvvec_redo_after_create.sh
--
--  Runs on the restarted server, after roll forward replayed everything phase
--  1 did past its checkpoint.  See tvvec_redo_after_create.sql for why each of
--  these can go wrong.
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

echo BOTH "STARTED: redo of a vector index created after the last checkpoint (phase 2)\n";

select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:trac:g', 0);
ECHO BOTH $IF $EQU $LAST[1] 300 "PASSED" "***FAILED";
ECHO BOTH ": roll forward brought back the " $LAST[1] " triples\n";

create procedure DB.DBA.TRAC_TOP1 (in txt varchar) returns varchar
{
  declare st, msg varchar;
  declare md, rs any;
  st := '00000';
  exec (sprintf ('sparql define input:storage "" select ?s where { ?s bif:vector_search "%s" option (index <urn:trac:idx>, limit 1) }', txt),
        st, msg, vector (), 0, md, rs);
  if (st <> '00000' or length (rs) = 0)
    return sprintf ('<no hit: %s %s>', st, msg);
  return id_to_iri (iri_to_id (rs[0][0]));
}
;

--  "doc 17 35" is subject 3 * 32 + 17.  The first search is also what makes
--  the index reconcile, and so rebuild the graph roll forward could not apply.
select DB.DBA.TRAC_TOP1 ('doc 17 35');
ECHO BOTH $IF $EQU $LAST[1] "urn:trac:d113" "PASSED" "***FAILED";
ECHO BOTH ": the index answers after the restart, top hit " $LAST[1] "\n";

select get_keyword ('graph_nodes', __VEC_INDEX_METRICS (DB.DBA.VEC_INDEX_GENERATE_NAME ('urn:trac:idx')));
ECHO BOTH $IF $EQU $LAST[1] 300 "PASSED" "***FAILED";
ECHO BOTH ": the graph holds all rows again, graph_nodes=" $LAST[1] "\n";

select __VEC_INDEX_HEALTH_RECHECK (DB.DBA.VEC_INDEX_GENERATE_NAME ('urn:trac:idx'));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": and is healthy, health=" $LAST[1] "\n";

--  max_seq_len survives the startup re-registration.  128 when the bundled
--  model was not registered at all, so the assertion holds vacuously there.
select case when (select V from DB.DBA.TRAC_EXPECT where K = 'granite') = 0 then 128
  else (select max_seq_len from DB.DBA.ONNX_MODELS where model_name = 'granite-384-local') end;
ECHO BOTH $IF $EQU $LAST[1] 128 "PASSED" "***FAILED";
ECHO BOTH ": the bundled model kept its max_seq_len across the restart, got " $LAST[1] "\n";

select case when registry_get ('__vec_meta_view') = DB.DBA.VEC_INDEX_META_VIEW_VERSION () then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the metadata view is recorded as installed, ok=" $LAST[1] "\n";

sparql select count (*) from <urn:vvec:indexes>
  where { <urn:trac:idx> <http://www.w3.org/2000/01/rdf-schema#label> ?o };
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the view publishes the label exactly once, n=" $LAST[1] "\n";

sparql select ?o from <urn:vvec:indexes>
  where { <urn:trac:idx> <http://www.w3.org/2000/01/rdf-schema#label> ?o };
ECHO BOTH $IF $EQU $LAST[1] "Redo after create" "PASSED" "***FAILED";
ECHO BOTH ": with the right value, label=" $LAST[1] "\n";

--  An IRI id used by the RDF view metadata with no name behind it is what an
--  installer racing roll forward leaves: its unlogged ids are reissued by
--  replay to other names.
select count (*) from DB.DBA.RDF_QUAD q
  where q.G = iri_to_id ('http://www.openlinksw.com/schemas/virtrdf#', 0)
    and q.S < min_bnode_iri_id ()
    and not exists (select 1 from DB.DBA.RDF_IRI i where i.RI_ID = q.S);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": no subject IRI id in virtrdf: without a name, n=" $LAST[1] "\n";

select count (*) from DB.DBA.RDF_QUAD q
  where q.G = iri_to_id ('http://www.openlinksw.com/schemas/virtrdf#', 0)
    and isiri_id (q.O) and q.O < min_bnode_iri_id ()
    and not exists (select 1 from DB.DBA.RDF_IRI i where i.RI_ID = q.O);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": no object IRI id in virtrdf: without a name, n=" $LAST[1] "\n";

select DB.DBA.VEC_INDEX_META_VIEW_INIT ();
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": the installer finds nothing left to do, returned " $LAST[1] "\n";

sparql define input:storage "" drop silent vector index <urn:trac:idx>;
sparql clear graph <urn:trac:g>;
drop table DB.DBA.TRAC_EXPECT;
delete from DB.DBA.ONNX_MODELS where model_name = 'trac-64';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE "\n";

echo BOTH "COMPLETED: redo of a vector index created after the last checkpoint (phase 2)\n";
