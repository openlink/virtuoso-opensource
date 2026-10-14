--
--  tvvec_create_shorthand.sql
--
--  CREATE VECTOR INDEX shorthand: an omitted ('<column>') list and an omitted
--  WITH (dimensions = <n>).
--
--  Uses a test_embedding model rather than a real one, so it needs no ONNX
--  plugin and runs in a default build.
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

--  A test_embedding model declaring output_shape 1,8: the shorthand has to
--  read the width from here rather than from the user.
delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-shorthand-8';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('vvec-shorthand-8', 'shorthand DDL test model', 'internal:vvec-test-8', 'test_embedding', 'embedding', '1,8', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register vvec-shorthand-8 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table DB.DBA.VVEC_SH_ONE (ID integer not null primary key, TXT varchar(200));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_SH_ONE STATE=" $STATE "\n";

--  The whole point: no column list, no WITH clause.
CREATE VECTOR INDEX VVEC_SH_IDX ON DB.DBA.VVEC_SH_ONE USING 'vvec-shorthand-8';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": CREATE VECTOR INDEX with neither column nor WITH STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select cast (DB.DBA.VEC_SQL_INDEX_OPT (KEY_OPTIONS, 'sc') as varchar) from DB.DBA.SYS_KEYS where KEY_NAME = 'VVEC_SH_IDX';
ECHO BOTH $IF $EQU $LAST[1] TXT "PASSED" "***FAILED";
ECHO BOTH ": inferred source column = " $LAST[1] " expected TXT\n";

select cast (DB.DBA.VEC_SQL_INDEX_OPT (KEY_OPTIONS, 'd') as integer) from DB.DBA.SYS_KEYS where KEY_NAME = 'VVEC_SH_IDX';
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": dimension inferred from the model output_shape = " $LAST[1] " expected 8\n";

select cast (DB.DBA.VEC_SQL_INDEX_OPT (KEY_OPTIONS, 'mt') as varchar) from DB.DBA.SYS_KEYS where KEY_NAME = 'VVEC_SH_IDX';
ECHO BOTH $IF $EQU $LAST[1] cosine "PASSED" "***FAILED";
ECHO BOTH ": distance metric defaulted = " $LAST[1] " expected cosine\n";

--  Two candidate columns: the column must NOT be guessed.  Guessing would
--  build an expensive index over the wrong data and report success, and the
--  mistake would only surface later as quietly poor search results.
create table DB.DBA.VVEC_SH_TWO (ID integer not null primary key, A varchar(100), B varchar(100));
CREATE VECTOR INDEX VVEC_SH_AMBIG ON DB.DBA.VVEC_SH_TWO USING 'vvec-shorthand-8';
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": ambiguous column refused STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--  ... but naming one resolves it.
CREATE VECTOR INDEX VVEC_SH_AMBIG ON DB.DBA.VVEC_SH_TWO (A) USING 'vvec-shorthand-8';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": explicit column with no WITH STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--  No string-compatible column at all.
create table DB.DBA.VVEC_SH_NONE (ID integer not null primary key, N integer);
CREATE VECTOR INDEX VVEC_SH_NOCOL ON DB.DBA.VVEC_SH_NONE USING 'vvec-shorthand-8';
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": table with no string column refused STATE=" $STATE "\n";

--  Regression: an explicit dimension that disagrees with the model is still
--  refused.  Inference must not have turned the check into a silent override.
CREATE VECTOR INDEX VVEC_SH_BADDIM ON DB.DBA.VVEC_SH_ONE (TXT) USING 'vvec-shorthand-8' WITH (dimensions = 128);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": explicit dimension conflicting with the model refused STATE=" $STATE "\n";

--  Regression: the fully explicit form is unchanged.
CREATE VECTOR INDEX VVEC_SH_FULL ON DB.DBA.VVEC_SH_TWO (B) USING 'vvec-shorthand-8' WITH (dimensions = 8, distance_metric = 'l2', hnsw_m = 8, ef_construction = 100);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": fully explicit form STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select cast (DB.DBA.VEC_SQL_INDEX_OPT (KEY_OPTIONS, 'distance_metric') as varchar) from DB.DBA.SYS_KEYS where KEY_NAME = 'VVEC_SH_FULL';
ECHO BOTH $IF $EQU $LAST[1] l2 "PASSED" "***FAILED";
ECHO BOTH ": explicit metric honoured = " $LAST[1] " expected l2\n";

drop table DB.DBA.VVEC_SH_ONE;
drop table DB.DBA.VVEC_SH_TWO;
drop table DB.DBA.VVEC_SH_NONE;
delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-shorthand-8';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE "\n";
