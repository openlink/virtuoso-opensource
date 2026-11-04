--
--  tvvec_recover_interrupted.sql -- phase 1 of tvvec_recover_interrupted.sh
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
--  Creates two SPARQL vector indexes and an RDF_OBJ vector index, checkpoints,
--  then puts each in the state its operation commits when it starts -- the
--  state a crash leaves behind.  Those commits come after the checkpoint, so
--  they are in the transaction log only.  Uses the in-process 'test_embedding'
--  model type, so it needs no ONNX plugin.
--

echo BOTH "STARTED: vector index operations interrupted by a crash (phase 1)\n";

delete from DB.DBA.ONNX_MODELS where model_name = 'vrec-8';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
  values ('vrec-8', 'deterministic recovery test model', 'internal:vrec-8',
          'test_embedding', 'embedding', '1,8', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register vrec-8 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

SPARQL INSERT DATA { GRAPH <urn:vrec:g> {
  <urn:vrec:a> <urn:vrec:p> "an interrupted refresh leaves the index busy" .
  <urn:vrec:b> <urn:vrec:p> "recovery at startup puts it in error" .
  <urn:vrec:c> <urn:vrec:p> "and refresh can retry from there" } };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": 3 literals inserted STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

SPARQL DEFINE input:storage "" CREATE VECTOR INDEX <urn:vrec:refreshing> ON GRAPH <urn:vrec:g> FOR PREDICATE <urn:vrec:p> USING MODEL 'vrec-8' WITH (dimensions = 8, distance = 'cosine');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create <urn:vrec:refreshing> STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

SPARQL DEFINE input:storage "" REFRESH VECTOR INDEX <urn:vrec:refreshing>;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": first refresh of <urn:vrec:refreshing> STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

SPARQL DEFINE input:storage "" CREATE VECTOR INDEX <urn:vrec:dropping> ON GRAPH <urn:vrec:g> FOR PREDICATE <urn:vrec:p> USING MODEL 'vrec-8' WITH (dimensions = 8, distance = 'cosine');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create <urn:vrec:dropping> STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.RDF_OBJ_VEC_INDEX_CREATE ('urn:vrec:objidx', 'vrec-8', null, 0, null, 'bulk', 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create the RDF_OBJ vector index urn:vrec:objidx STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI in ('urn:vrec:refreshing', 'urn:vrec:dropping') and SVI_STATE = 'active';
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": both SPARQL indexes are active before the checkpoint, got " $LAST[1] "\n";

checkpoint;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": checkpoint STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- After the checkpoint, and never checkpointed: what REFRESH, DROP and an
-- RDF_OBJ index build commit when they start.
DB.DBA.VEC_INDEX_BEGIN_MUTATION ('urn:vrec:refreshing', 'refreshing');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": <urn:vrec:refreshing> mid-REFRESH STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.VEC_INDEX_BEGIN_MUTATION ('urn:vrec:dropping', 'dropping');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": <urn:vrec:dropping> mid-DROP STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update DB.DBA.RDF_OBJ_VEC_INDEX set RVI_STATE = 'embedding', RVI_LAST_ERROR = null
 where RVI_NAME = DB.DBA.RDF_OBJ_VEC_INDEX_KEY ('urn:vrec:objidx');
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": urn:vrec:objidx mid-embedding, rows " $ROWCNT "\n";

select SVI_STATE from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:vrec:refreshing';
ECHO BOTH $IF $EQU $LAST[1] "refreshing" "PASSED" "***FAILED";
ECHO BOTH ": <urn:vrec:refreshing> reads 'refreshing' when the server is killed, got " $LAST[1] "\n";

echo BOTH "COMPLETED: vector index operations interrupted by a crash (phase 1)\n";
