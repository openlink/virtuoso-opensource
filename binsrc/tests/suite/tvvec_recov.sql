--
--  tvvec_recov.sql
--
--  Vector index fixture for the recovery test (trecov.sh).
--
--  trecov.sh drives every durability surface in turn -- log roll forward,
--  +backup-dump, the SQL backup () statement, and +crash-dump -- each followed
--  by a restore into a fresh database file.  This puts a real vector index into
--  that rotation so the HNSW graph has to survive all four, and recovck_vec.sql
--  asserts after each one that it came back without being rebuilt.
--
--  The model is an internal deterministic one: it needs no ONNX helper process
--  and no model file on disk, so the fixture stands up in a plain recovery-test
--  environment (same approach as tvvec_backup.sql).
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

ECHO BOTH "STARTED: VVEC recovery fixture\n";

select DB.DBA.ONNX_REGISTRY_INIT ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": registry init STATE=" $STATE "\n";

delete from DB.DBA.ONNX_MODELS where model_name = 'recov-32';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
  values ('recov-32', 'recovery test model', 'internal:recov-32', 'test_embedding', 'embedding', '1,32', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register recov-32 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--  __VEC_INDEX_VALIDATE returns a key/value vector; isql cannot index into one,
--  so pull single fields out through a function.  It is a stored procedure, so
--  it survives the dump/restore cycles along with the rest of the schema and
--  recovck_vec.sql can use it after every restore.
create function DB.DBA.RVEC_KV (in kv any, in k varchar) returns any
{
  declare i integer;
  if (not isvector (kv)) return null;
  for (i := 0; i < length (kv); i := i + 2)
    if (cast (aref (kv, i) as varchar) = k) return aref (kv, i + 1);
  return null;
};

CREATE TABLE DB.DBA.DOCS (
  id      INTEGER NOT NULL PRIMARY KEY,
  content LONG VARCHAR
);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create DOCS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

INSERT INTO DB.DBA.DOCS VALUES (1, 'How do I Install Virtuoso on Linux?');
INSERT INTO DB.DBA.DOCS VALUES (2, 'How do I install virtuoso on Windows?');
INSERT INTO DB.DBA.DOCS VALUES (3, 'How do I install virtuoso on macOS?');

CREATE VECTOR INDEX DOCS_VEC
ON DB.DBA.DOCS (content)
USING 'recov-32'
WITH (
  dimensions      = 32,
  distance_metric = 'cosine',
  hnsw_m          = 16,
  ef_construction = 200
);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create vector index DOCS_VEC STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.DOCS_VEC_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": fixture embeddings rows=" $LAST[1] " expected 3\n";

select DB.DBA.RVEC_KV (__VEC_INDEX_VALIDATE ('DOCS_VEC'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": fixture graph consistent=" $LAST[1] "\n";

select length (__VEC_INDEX_SEARCH ('DOCS_VEC', __VEC_INDEX_QUERY_TEXT_VECTOR ('DOCS_VEC', 'howto virtuoso macOS'), 3, 40));
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": fixture ANN hits=" $LAST[1] " expected 3\n";

--  The graph reaches disk only at checkpoint, so settle it before trecov.sh
--  starts killing and dumping the server.
checkpoint;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": fixture checkpoint STATE=" $STATE "\n";

ECHO BOTH "COMPLETED: VVEC recovery fixture\n";
