--
--  tvvec_ddl_error_reload.sql
--
--  A failed vector index statement keeps its error and nothing more.
--
--  SPARQL vector index DDL runs through the quad-map DDL executor,
--  DB.DBA.RDF_QM_CHANGE_OPT, which answers a failed operation by reloading
--  the built-in RDF metadata: right after a quad map operation that may have
--  written half of its metadata, pointless after a vector index operation,
--  which keeps nothing there.  A typo in `drop vector index` cost a reload of
--  2479 triples of the system graph -- some 150 ms, and about 218 KB in the
--  transaction log -- and three extra result rows.
--
--  1-3 are tests of the change (each fails before it); the rest are guards
--  and hold on both sides:
--    1. dropping a missing index answers VEC42 and does not reload;
--    2. ...and writes next to nothing to the transaction log;
--    3. a CREATE that fails answers its error and does not reload;
--    4. the VEC42 row is still there (guard);
--    5. DROP SILENT of a missing index is still quiet (guard);
--    6. a failed quad map operation still reloads (guard).
--
--  Self-contained, no model or vonnx needed.
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

echo BOTH "STARTED: failed vector index DDL and the RDF metadata reload\n";

--  The (STATE, MESSAGE) rows a SPARQL DDL statement answered, joined by ' | '.
--  Quad-map DDL reports a failed operation as a row and leaves the
--  statement's own SQLSTATE at 00000, so the rows are what to look at.
create function DB.DBA.TVDDL_ROWS (in _stmt varchar) returns varchar
{
  declare _st, _msg varchar;
  declare _md, _rows any;
  declare _out varchar;
  declare _i integer;
  _st := '00000';
  exec (_stmt, _st, _msg, vector (), 100, _md, _rows);
  if (_st <> '00000' and _st <> 0)
    return 'error ' || cast (_st as varchar) || ' ' || coalesce (_msg, '');
  _out := '';
  if (isvector (_rows))
    for (_i := 0; _i < length (_rows); _i := _i + 1)
      _out := _out || case when _i > 0 then ' | ' else '' end
        || cast (_rows[_i][0] as varchar) || ' ' || cast (_rows[_i][1] as varchar);
  return _out;
};

--  1, 4.
select DB.DBA.TVDDL_ROWS ('sparql drop vector index <urn:tvddl:no-such-index>');
ECHO BOTH ": drop of a missing index answered: " $LAST[1] "\n";
select case when strstr (DB.DBA.TVDDL_ROWS ('sparql drop vector index <urn:tvddl:no-such-index>'), 'Reloading built-in metadata') is null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": 1. dropping a missing vector index does not reload the RDF metadata, ok=" $LAST[1] "\n";
select case when DB.DBA.TVDDL_ROWS ('sparql drop vector index <urn:tvddl:no-such-index>') like 'VEC42 %not found%' then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": 4. ...and still answers VEC42, ok=" $LAST[1] "\n";

--  2.  The reload deletes and re-inserts every triple of the built-in
--  metadata, so it shows in the transaction log; a checkpoint empties the log
--  first.  Both sides of the change differ by two orders of magnitude.
checkpoint;
select DB.DBA.TVDDL_ROWS ('sparql drop vector index <urn:tvddl:no-such-index>');
select case when cast (file_stat ('virtuoso.trx', 1) as integer) < 10000 then 1 else 0 end, file_stat ('virtuoso.trx', 1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": 2. ...and leaves the transaction log under 10 KB: " $LAST[2] " bytes\n";

--  3.  A CREATE that fails part-way -- the model does not exist -- undoes its
--  own catalogue row and must not reload either.
select DB.DBA.TVDDL_ROWS ('sparql create vector index <urn:tvddl:bad-model> on graph <urn:tvddl:g> for predicate <urn:tvddl:p> using model ''tvddl-no-such-model'' with (dimensions = 8)');
ECHO BOTH ": a CREATE with a missing model answered: " $LAST[1] "\n";
select case when strstr (DB.DBA.TVDDL_ROWS ('sparql create vector index <urn:tvddl:bad-model> on graph <urn:tvddl:g> for predicate <urn:tvddl:p> using model ''tvddl-no-such-model'' with (dimensions = 8)'), 'Reloading built-in metadata') is null
  and not exists (select 1 from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:tvddl:bad-model') then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": 3. a failed CREATE does not reload and leaves no catalogue row, ok=" $LAST[1] "\n";

--  5.
select DB.DBA.TVDDL_ROWS ('sparql drop silent vector index <urn:tvddl:no-such-index>');
ECHO BOTH ": DROP SILENT of a missing index answered: " $LAST[1] "\n";
select case when DB.DBA.TVDDL_ROWS ('sparql drop silent vector index <urn:tvddl:no-such-index>')
  = '00000 Vector index <urn:tvddl:no-such-index> does not exist (silent) | 00000 1 RDF metadata manipulation operations done' then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": 5. DROP SILENT of a missing index is quiet and does not reload, ok=" $LAST[1] "\n";

--  6.  A quad map operation that fails may have written part of its metadata,
--  so the reload stays for those.
select case when strstr (DB.DBA.TVDDL_ROWS ('sparql drop quad map <urn:tvddl:no-such-map>'), 'Reloading built-in metadata') is not null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": 6. a failed quad map operation still reloads the RDF metadata, ok=" $LAST[1] "\n";

drop function DB.DBA.TVDDL_ROWS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE "\n";

echo BOTH "COMPLETED: failed vector index DDL and the RDF metadata reload\n";
