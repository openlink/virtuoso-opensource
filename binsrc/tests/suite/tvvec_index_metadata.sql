--
--  tvvec_index_metadata.sql
--
--  A vector index's own name and description: rdfs:label and rdfs:comment set
--  at create time, editable afterwards, readable through SPARQL, and gated by
--  ordinary SQL privileges.
--
--  What is worth testing here is not that a string round-trips.  It is the
--  three things that fail quietly:
--
--    * the CREATE options.  An unknown option must still be VEC13, or "label"
--      would be silently swallowed on a server that does not have this.
--    * the two access gates.  `grant execute` on VEC_INDEX_SET_METADATA
--      answers "may this account annotate indexes at all"; the procedure's own
--      check answers "which ones".  The second one is the interesting one:
--      the procedure runs with definer's rights, so a single EXECUTE grant
--      without it would let one account retitle every index on the instance.
--      SVI_OWNER is a varchar holding a numeric user id, which is exactly the
--      shape that produces an ownership check that silently never matches --
--      so the owner-can-edit-its-own case is asserted, not just the refusals.
--    * the RDF view teardown order.  Dropping a quad map after its storage
--      leaks quad-map objects that pin the IRI class forever, and the mapping
--      can then never be re-created under the same name.  That does not fail
--      the first time, so the view is installed, dropped and re-installed
--      TWICE below.
--
--  Self-contained: the in-core deterministic 'test_embedding' model, so this
--  needs neither ONNX nor the VVEC_BEGIN_* fixtures and runs unconditionally.
--
--  Run with:
--    isql <port> dba dba binsrc/tests/suite/tvvec_index_metadata.sql
--

echo BOTH "STARTED: vector index metadata (rdfs:label / rdfs:comment)\n";

-- ===========================================================================
-- Fixtures
-- ===========================================================================
create table DB.DBA.ONNX_MODELS (
  model_id integer identity,
  model_name varchar not null,
  description varchar,
  model_path varchar not null,
  model_type varchar not null,
  input_names varchar,
  input_shapes varchar,
  output_name varchar,
  output_shape varchar,
  vocab_path varchar,
  max_seq_len integer,
  handle integer,
  created_at datetime,
  updated_at datetime,
  primary key (model_id)
) if not exists;
create unique index ONNX_MODELS_NAME_IDX on DB.DBA.ONNX_MODELS (model_name) if not exists;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": ensure ONNX_MODELS table STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-meta-8';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('vvec-meta-8', 'deterministic test model for the index-metadata test',
   'internal:vvec-meta-8', 'test_embedding', 'embedding', '1,8', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register vvec-meta-8 model STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

sparql define input:storage "" drop silent vector index <urn:meta:idx>;
sparql define input:storage "" drop silent vector index <urn:meta:idx2>;
sparql define input:storage "" clear graph <urn:meta:graph>;
sparql define input:storage ""
insert data {
  graph <urn:meta:graph> {
    <urn:meta:doc1> <urn:meta:content> "the first document" .
    <urn:meta:doc2> <urn:meta:content> "the second document" .
  }
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": seed metadata test RDF graph STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--  Two throwaway accounts.  vecmeta_owner ends up owning <urn:meta:idx2>;
--  vecmeta_other never owns anything and is the "has EXECUTE, wrong index"
--  case.  Recreated from scratch so a re-run of this script starts clean.
--
--  EVERY GRANT AND REVOKE BELOW QUOTES THE ACCOUNT NAME.  user_create takes a
--  string and stores the name exactly as given, but GRANT takes an identifier:
--  under the suite's default CaseMode an unquoted vecmeta_owner is folded to
--  VECMETA_OWNER, which matches no account, and the grant fails with
--  SR137 "Bad user name in GRANT/REVOKE" -- or, for a role, U0002.  Nothing
--  else in the test notices, because the account really does exist: it just
--  holds none of the rights the assertions are about.  A development instance
--  with CaseMode = 2 preserves the case and hides all of it.
create procedure DB.DBA.TMETA_USER (in _n varchar, in _pw varchar)
{
  declare exit handler for sqlstate '*' { ; };
  if (exists (select 1 from DB.DBA.SYS_USERS where U_NAME = _n))
    DB.DBA.USER_DROP (_n, 0);
  user_create (_n, _pw);
};
select DB.DBA.TMETA_USER ('vecmeta_owner', 'vecmeta_owner_pw');
select DB.DBA.TMETA_USER ('vecmeta_other', 'vecmeta_other_pw');
--  SPARQL_SELECT is what makes them ordinary SPARQL readers -- it carries the
--  SELECT on DB.DBA.RDF_QUAD every SPARQL query needs.  Without it section 7
--  would be measuring the absence of that, not the absence of a grant on the
--  catalogue, and would "pass" for the wrong reason.
grant SPARQL_SELECT to "vecmeta_owner";
grant SPARQL_SELECT to "vecmeta_other";
select count(*) from DB.DBA.SYS_USERS where U_NAME in ('vecmeta_owner', 'vecmeta_other');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": create test accounts, n=" $LAST[1] "\n";

--  Run one statement as another account and report only whether it was
--  refused.  1 = refused (the expected answer for most of the calls below),
--  0 = it went through.  exec() reports a failure through its STATE out
--  parameter rather than raising, so nothing here can escape before
--  __pop_user_id runs -- and if it could, the whole rest of the script would
--  quietly carry on as the test account.
create function DB.DBA.TMETA_AS (in _user varchar, in _stmt varchar) returns integer
{
  declare _st, _msg varchar;
  declare _md, _rows any;
  _st := '00000';
  __set_user_id (_user);
  exec (_stmt, _st, _msg, vector (), 10, _md, _rows);
  __pop_user_id ();
  if (_st <> '00000' and _st <> 0)
    return 1;
  return 0;
};
select case when __proc_exists ('DB.DBA.TMETA_AS') is not null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": create TMETA_AS helper, defined=" $LAST[1] "\n";

-- ===========================================================================
-- 1. CREATE accepts label and comment, and stores them
-- ===========================================================================
sparql define input:storage ""
create vector index <urn:meta:idx>
  on graph <urn:meta:graph>
  for predicate <urn:meta:content>
  using model 'vvec-meta-8'
  with (dimensions = 8, distance = 'cosine', hnsw_m = 8, ef_construction = 16,
        label = 'Support articles',
        comment = 'Semantic search over the body text of published support articles')
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create index with label and comment STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from DB.DBA.SPARQL_VEC_INDEX
 where SVI_IRI = 'urn:meta:idx' and SVI_LABEL = 'Support articles';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": label stored in the catalogue, rows=" $LAST[1] "\n";

select count(*) from DB.DBA.SPARQL_VEC_INDEX
 where SVI_IRI = 'urn:meta:idx'
   and SVI_COMMENT = 'Semantic search over the body text of published support articles';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": comment stored in the catalogue, rows=" $LAST[1] "\n";

-- ===========================================================================
-- 2. An unknown option is still VEC13
--
--    This is the assertion that stops "label" from being special: the generic
--    `<name> = <string>` rule in the grammar accepts ANY option name, and the
--    only thing that rejects a typo is this branch in VEC_INDEX_SET_OPTIONS.
--    count(*) rather than a bare select, so an empty result set cannot leave
--    $LAST[1] holding the previous statement's value and pass by accident.
-- ===========================================================================
sparql define input:storage ""
create vector index <urn:meta:bogus-idx>
  on graph <urn:meta:graph>
  for predicate <urn:meta:content>
  using model 'vvec-meta-8'
  with (dimensions = 8, labell = 'typo')
;
select count(*) from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:meta:bogus-idx';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": misspelt option still rejected (VEC13), no catalogue residue, rows=" $LAST[1] "\n";

-- ===========================================================================
-- 3. Length caps, and blank meaning unset
-- ===========================================================================
create procedure DB.DBA.TMETA_LONG_LABEL ()
{
  declare _st, _msg varchar;
  declare _md, _rows any;
  _st := '00000';
  exec ('sparql define input:storage "" create vector index <urn:meta:long-idx> ' ||
        'on graph <urn:meta:graph> for predicate <urn:meta:content> ' ||
        'using model ' || chr (39) || 'vvec-meta-8' || chr (39) ||
        ' with (dimensions = 8, label = ' || chr (39) || repeat ('x', 256) || chr (39) || ')',
        _st, _msg, vector (), 10, _md, _rows);
  return 0;
};
select DB.DBA.TMETA_LONG_LABEL ();
select count(*) from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:meta:long-idx';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": 256-character label rejected (VEC26), no catalogue residue, rows=" $LAST[1] "\n";

sparql define input:storage ""
create vector index <urn:meta:idx2>
  on graph <urn:meta:graph>
  for predicate <urn:meta:content>
  using model 'vvec-meta-8'
  with (dimensions = 8, label = '   ')
;
select count(*) from DB.DBA.SPARQL_VEC_INDEX
 where SVI_IRI = 'urn:meta:idx2' and SVI_LABEL is null;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": all-blank label normalises to NULL, rows=" $LAST[1] "\n";

-- ===========================================================================
-- 4. VEC_INDEX_SET_METADATA as dba: set both, set one, clear one
-- ===========================================================================
select DB.DBA.VEC_INDEX_SET_METADATA ('urn:meta:idx', 'Renamed', 'Re-described');
select count(*) from DB.DBA.SPARQL_VEC_INDEX
 where SVI_IRI = 'urn:meta:idx' and SVI_LABEL = 'Renamed' and SVI_COMMENT = 'Re-described';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": SET_METADATA writes both, rows=" $LAST[1] "\n";

--  NULL for an argument means "leave that one alone", so a caller can change
--  the comment without restating the label and vice versa.
select DB.DBA.VEC_INDEX_SET_METADATA ('urn:meta:idx', 'Renamed again');
select count(*) from DB.DBA.SPARQL_VEC_INDEX
 where SVI_IRI = 'urn:meta:idx' and SVI_LABEL = 'Renamed again' and SVI_COMMENT = 'Re-described';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": SET_METADATA leaves an omitted value alone, rows=" $LAST[1] "\n";

--  The empty string is the one way back to unset -- which is why blank is not
--  simply treated as "omitted" here.
select DB.DBA.VEC_INDEX_SET_METADATA ('urn:meta:idx', null, '');
select count(*) from DB.DBA.SPARQL_VEC_INDEX
 where SVI_IRI = 'urn:meta:idx' and SVI_LABEL = 'Renamed again' and SVI_COMMENT is null;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": SET_METADATA clears with the empty string, rows=" $LAST[1] "\n";

select DB.DBA.TMETA_AS ('dba', 'select DB.DBA.VEC_INDEX_SET_METADATA (' || chr (39) ||
  'urn:meta:no-such-idx' || chr (39) || ', ' || chr (39) || 'x' || chr (39) || ')');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": SET_METADATA on an unknown index refused (VEC27)=" $LAST[1] "\n";

-- ===========================================================================
-- 5. The two access gates
-- ===========================================================================
--  Gate 1: no EXECUTE grant, so the call never reaches the owner check.
select DB.DBA.TMETA_AS ('vecmeta_other', 'select DB.DBA.VEC_INDEX_SET_METADATA (' || chr (39) ||
  'urn:meta:idx' || chr (39) || ', ' || chr (39) || 'hijacked' || chr (39) || ')');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": non-dba without EXECUTE refused (SR186)=" $LAST[1] "\n";

grant execute on DB.DBA.VEC_INDEX_SET_METADATA to "vecmeta_other";
grant execute on DB.DBA.VEC_INDEX_SET_METADATA to "vecmeta_owner";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": grant EXECUTE to both test accounts STATE=" $STATE "\n";

--  Gate 2: EXECUTE now held, but the index belongs to dba.
select DB.DBA.TMETA_AS ('vecmeta_other', 'select DB.DBA.VEC_INDEX_SET_METADATA (' || chr (39) ||
  'urn:meta:idx' || chr (39) || ', ' || chr (39) || 'hijacked' || chr (39) || ')');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": non-owner WITH execute still refused (VEC28)=" $LAST[1] "\n";

select count(*) from DB.DBA.SPARQL_VEC_INDEX
 where SVI_IRI = 'urn:meta:idx' and SVI_LABEL = 'Renamed again';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": ...and the label really is unchanged, rows=" $LAST[1] "\n";

--  Hand <urn:meta:idx2> to vecmeta_owner the way BEGIN_CREATE would have:
--  SVI_OWNER is a varchar holding the numeric user id.
update DB.DBA.SPARQL_VEC_INDEX
   set SVI_OWNER = cast ((select U_ID from DB.DBA.SYS_USERS where U_NAME = 'vecmeta_owner') as varchar)
 where SVI_IRI = 'urn:meta:idx2';
commit work;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": hand urn:meta:idx2 to vecmeta_owner STATE=" $STATE "\n";

--  The case most likely to be silently wrong: the owner editing its own index.
--  A comparison that casts one side to integer refuses everybody, including
--  here, and every other assertion in this section would still pass.
select DB.DBA.TMETA_AS ('vecmeta_owner', 'select DB.DBA.VEC_INDEX_SET_METADATA (' || chr (39) ||
  'urn:meta:idx2' || chr (39) || ', ' || chr (39) || 'Mine' || chr (39) || ')');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": the owner may annotate its own index, refused=" $LAST[1] "\n";

select count(*) from DB.DBA.SPARQL_VEC_INDEX
 where SVI_IRI = 'urn:meta:idx2' and SVI_LABEL = 'Mine';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": ...and the write landed, rows=" $LAST[1] "\n";

--  ...but not somebody else's.
select DB.DBA.TMETA_AS ('vecmeta_owner', 'select DB.DBA.VEC_INDEX_SET_METADATA (' || chr (39) ||
  'urn:meta:idx' || chr (39) || ', ' || chr (39) || 'Not mine' || chr (39) || ')');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the owner may NOT annotate another account's index (VEC28)=" $LAST[1] "\n";

--  DBA edits anything, whoever owns it.
select DB.DBA.VEC_INDEX_SET_METADATA ('urn:meta:idx2', 'Taken over by dba');
select count(*) from DB.DBA.SPARQL_VEC_INDEX
 where SVI_IRI = 'urn:meta:idx2' and SVI_LABEL = 'Taken over by dba';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": dba may annotate an index it does not own, rows=" $LAST[1] "\n";

--  Every index created before this column meant anything holds SVI_OWNER '0'.
--  Same value get_user_id (1) returns for dba, and the comparison has to treat
--  the two the same way.
update DB.DBA.SPARQL_VEC_INDEX set SVI_OWNER = '0' where SVI_IRI = 'urn:meta:idx2';
commit work;
select DB.DBA.TMETA_AS ('dba', 'select DB.DBA.VEC_INDEX_SET_METADATA (' || chr (39) ||
  'urn:meta:idx2' || chr (39) || ', ' || chr (39) || 'Legacy owner 0' || chr (39) || ')');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": a legacy SVI_OWNER of '0' is still editable, refused=" $LAST[1] "\n";

-- ===========================================================================
-- 6. The RDF view over the catalogue
-- ===========================================================================
select DB.DBA.VEC_INDEX_META_VIEW_CREATE ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": (re)install the metadata RDF view STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

sparql select count(*) as ?n from <urn:vvec:indexes>
  where { <urn:meta:idx> <http://www.w3.org/2000/01/rdf-schema#label> ?o };
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": rdfs:label readable through SPARQL, n=" $LAST[1] "\n";

--  <urn:meta:idx> had its comment cleared in section 4, so it must have a
--  label and NO comment.  A quad map without an IS NOT NULL guard answers a
--  variable-predicate query with a row whose object is NULL, which is why the
--  view uses one map per column rather than one map with two patterns.
sparql select count(*) as ?n from <urn:vvec:indexes>
  where { <urn:meta:idx> ?p ?o };
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": an index with no comment emits exactly one triple, n=" $LAST[1] "\n";

--  Install / uninstall / re-install, twice.  The teardown-order bug this
--  guards against passes the first time round and only bites on the re-create,
--  so one cycle would prove nothing.
select DB.DBA.VEC_INDEX_META_VIEW_DROP ();
sparql select count(*) as ?n from <urn:vvec:indexes> where { ?s ?p ?o };
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": drop 1 leaves the graph empty, n=" $LAST[1] "\n";

select DB.DBA.VEC_INDEX_META_VIEW_CREATE ();
sparql select count(*) as ?n from <urn:vvec:indexes>
  where { <urn:meta:idx> <http://www.w3.org/2000/01/rdf-schema#label> ?o };
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": re-install 1 works, n=" $LAST[1] "\n";

select DB.DBA.VEC_INDEX_META_VIEW_DROP ();
sparql select count(*) as ?n from <urn:vvec:indexes> where { ?s ?p ?o };
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": drop 2 leaves the graph empty, n=" $LAST[1] "\n";

select DB.DBA.VEC_INDEX_META_VIEW_CREATE ();
sparql select count(*) as ?n from <urn:vvec:indexes>
  where { <urn:meta:idx> <http://www.w3.org/2000/01/rdf-schema#label> ?o };
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": re-install 2 works -- the IRI class was not burned, n=" $LAST[1] "\n";

-- ===========================================================================
-- 7. Reading the view is gated by the base table's SQL privileges
-- ===========================================================================
select DB.DBA.TMETA_AS ('vecmeta_other',
  'sparql select ?o from <urn:vvec:indexes> where { <urn:meta:idx> <http://www.w3.org/2000/01/rdf-schema#label> ?o }');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": no grant, the mapped graph is refused (SQ033)=" $LAST[1] "\n";

grant select (SVI_IRI, SVI_LABEL) on DB.DBA.SPARQL_VEC_INDEX to "vecmeta_other";
commit work;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": column-level grant on (SVI_IRI, SVI_LABEL) STATE=" $STATE "\n";

select DB.DBA.TMETA_AS ('vecmeta_other',
  'sparql select ?o from <urn:vvec:indexes> where { <urn:meta:idx> <http://www.w3.org/2000/01/rdf-schema#label> ?o }');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": with the column grant, rdfs:label reads, refused=" $LAST[1] "\n";

--  Per-predicate access, which graph-level security cannot express: the same
--  reader is refused the column it was not granted.
select DB.DBA.TMETA_AS ('vecmeta_other',
  'sparql select ?o from <urn:vvec:indexes> where { <urn:meta:idx2> <http://www.w3.org/2000/01/rdf-schema#comment> ?o }');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": ...and rdfs:comment is still refused (SQ033)=" $LAST[1] "\n";

-- ===========================================================================
-- Cleanup
-- ===========================================================================
revoke select (SVI_IRI, SVI_LABEL) on DB.DBA.SPARQL_VEC_INDEX from "vecmeta_other";
revoke execute on DB.DBA.VEC_INDEX_SET_METADATA from "vecmeta_other";
revoke execute on DB.DBA.VEC_INDEX_SET_METADATA from "vecmeta_owner";
sparql define input:storage "" drop silent vector index <urn:meta:idx>;
sparql define input:storage "" drop silent vector index <urn:meta:idx2>;
sparql define input:storage "" clear graph <urn:meta:graph>;
delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-meta-8';
DB.DBA.USER_DROP ('vecmeta_owner', 0);
DB.DBA.USER_DROP ('vecmeta_other', 0);
drop procedure DB.DBA.TMETA_LONG_LABEL;
drop function DB.DBA.TMETA_AS;
drop procedure DB.DBA.TMETA_USER;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": metadata test cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;

echo BOTH "COMPLETED: vector index metadata (rdfs:label / rdfs:comment)\n";
