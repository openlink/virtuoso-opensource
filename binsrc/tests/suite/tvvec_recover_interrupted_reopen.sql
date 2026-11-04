--
--  tvvec_recover_interrupted_reopen.sql -- phase 2 of tvvec_recover_interrupted.sh
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
--  Runs after raw_exit () and a restart.  The in-flight states were committed
--  after the last checkpoint, so roll forward brought them back; the recovery
--  at startup must have seen them and left each index in 'error'.
--

echo BOTH "STARTED: vector index operations interrupted by a crash (phase 2)\n";

select SVI_STATE from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:vrec:refreshing';
ECHO BOTH $IF $EQU $LAST[1] "error" "PASSED" "***FAILED";
ECHO BOTH ": a SPARQL index killed mid-REFRESH is in 'error' after the restart, got " $LAST[1] "\n";

select case when SVI_LAST_ERROR like 'Interrupted while refreshing:%' then 1 else 0 end
  from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:vrec:refreshing';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": its SVI_LAST_ERROR says the refresh was interrupted, " $LAST[1] "\n";

select SVI_STATE from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:vrec:dropping';
ECHO BOTH $IF $EQU $LAST[1] "error" "PASSED" "***FAILED";
ECHO BOTH ": a SPARQL index killed mid-DROP is in 'error' after the restart, got " $LAST[1] "\n";

select RVI_STATE from DB.DBA.RDF_OBJ_VEC_INDEX where RVI_NAME = DB.DBA.RDF_OBJ_VEC_INDEX_KEY ('urn:vrec:objidx');
ECHO BOTH $IF $EQU $LAST[1] "error" "PASSED" "***FAILED";
ECHO BOTH ": an RDF_OBJ index killed mid-embedding is in 'error' after the restart, got " $LAST[1] "\n";

select case when strstr (file_to_string ('virtuoso.log'), 'vector index <urn:vrec:refreshing>: recovered from an interrupted refreshing') is not null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the server log says the index was recovered, " $LAST[1] "\n";

-- SPARQL vector index DDL answers its errors (VEC90 ...) as result rows, with
-- STATE OK, so read the rows.
create function DB.DBA.VREC_RESULT (in stmt varchar) returns varchar
{
  declare st, msg varchar;
  declare md, rws any;
  declare res varchar;
  declare i integer;
  st := '00000';
  exec (stmt, st, msg, vector (), 100, md, rws);
  if (st <> '00000')
    return st || ' ' || msg;
  res := '';
  if (isvector (rws))
    for (i := 0; i < length (rws); i := i + 1)
      res := res || ' | ' || cast (rws[i][0] as varchar) || ' ' || cast (rws[i][1] as varchar);
  return res;
}
;
select case when strstr (DB.DBA.VREC_RESULT ('sparql define input:storage "" refresh vector index <urn:vrec:refreshing>'), 'refreshed') is not null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": REFRESH runs again after the restart, " $LAST[1] "\n";

select SVI_STATE from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:vrec:refreshing';
ECHO BOTH $IF $EQU $LAST[1] "active" "PASSED" "***FAILED";
ECHO BOTH ": and the index is active again, got " $LAST[1] "\n";

select count (*) from (sparql define input:storage "" select ?s where { ?s bif:vector_search "interrupted refresh" option (index <urn:vrec:refreshing>, limit 5) }) x;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": search answers over all 3 literals, got " $LAST[1] "\n";

-- cleanup (DROP accepts 'error')
SPARQL DEFINE input:storage "" DROP VECTOR INDEX <urn:vrec:refreshing>;
SPARQL DEFINE input:storage "" DROP VECTOR INDEX <urn:vrec:dropping>;
DB.DBA.RDF_OBJ_VEC_INDEX_DROP ('urn:vrec:objidx');
SPARQL CLEAR GRAPH <urn:vrec:g>;
drop function DB.DBA.VREC_RESULT;
delete from DB.DBA.ONNX_MODELS where model_name = 'vrec-8';

echo BOTH "COMPLETED: vector index operations interrupted by a crash (phase 2)\n";
