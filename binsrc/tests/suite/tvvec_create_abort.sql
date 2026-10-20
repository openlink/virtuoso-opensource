--
--  tvvec_create_abort.sql
--
--  A SPARQL create that is refused part-way must leave nothing behind.
--
--  The create DDL is a sequence of separately committed statements, so a
--  refusal between BEGIN_CREATE and END_CREATE used to strand the catalogue row
--  in state 'creating': not active, not reachable by DROP, and enough to make
--  a second attempt at the same IRI fail with VEC01 "already exists".
--
--  Uses a test_embedding model, so it needs no ONNX.
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

delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-abort-8';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('vvec-abort-8', 'create-abort test model', 'internal:vvec-test-8', 'test_embedding', 'embedding', '1,8', now (), now ());
DB.DBA.TTLP ('<urn:ab:a> <http://example.org/name> "alpha 1" .', '', 'urn:ab:g');
commit work;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": fixture STATE=" $STATE "\n";

--  Refused at SET_OPTIONS: async with a pattern scoped to neither GRAPH nor
--  FROM.  The DDL reports VEC77 as a result row, so assert on the catalogue.
sparql prefix ex: <http://example.org/>
create vector index <urn:ab:idx>
  key ?d embedding ?t
  where { ?d ex:name ?t }
  using model 'vvec-abort-8'
  with (dimensions = 8, maintenance = 'async');

select count (*) from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:ab:idx';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": refused create leaves no catalogue row, found " $LAST[1] " expected 0\n";

select count (*) from DB.DBA.SPARQL_VEC_INDEX_TRIGGER where SVT_INDEX_IRI = 'urn:ab:idx';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": refused create leaves no trigger rows, found " $LAST[1] " expected 0\n";

--  The point of cleaning up: the same IRI has to be usable again.  Before, this
--  second statement failed with VEC01.
sparql prefix ex: <http://example.org/>
create vector index <urn:ab:idx>
  key ?d embedding ?t
  from <urn:ab:g>
  where { ?d ex:name ?t }
  using model 'vvec-abort-8'
  with (dimensions = 8, maintenance = 'async');

select count (*) from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:ab:idx' and SVI_STATE = 'active';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the same IRI is creatable after a refusal, active = " $LAST[1] " expected 1\n";

sparql define input:storage "" refresh vector index <urn:ab:idx>;
select count (*) from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:ab:idx' and SVI_STATE = 'active';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": and it refreshes normally afterwards\n";

--  An index that finished building must never be touched by the abort path.
DB.DBA.VEC_INDEX_ABORT_CREATE ('urn:ab:idx');
select count (*) from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:ab:idx' and SVI_STATE = 'active';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": abort is a no-op on an active index, still there = " $LAST[1] " expected 1\n";

DB.DBA.VEC_INDEX_DROP ('urn:ab:idx', 1);
sparql clear graph <urn:ab:g>;
delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-abort-8';
commit work;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE "\n";
