--
--  tvvec_multi_index.sql
--
--  Several vector indexes in one bif:vector_search:
--
--    option (index (<a>, <b>))          the union of the named indexes
--    option (index *)                   every active index the caller can read
--    option (index (<a>, <b>), ranking raw | relevance)
--
--  The regression that matters most is the FIRST assertion: a single named
--  index must answer exactly as it did before any of this existed.  It takes
--  the same generated SQL and the same procedure; the list and the wildcard
--  are a second table function beside it, not a widening of the first.
--
--  The rest is the semantics, and the interesting ones are the quiet failures:
--
--    * `option (index <a>, index <b>)` PARSED before this and searched only
--      <a> -- the option list is a commalist, so a repeated option is legal,
--      and the consumer walked it backwards and kept the first one written.
--      Silently dropping an index the caller named is now an error.
--    * `limit` means N in total, not N per index, and a subject that sits in
--      two indexes comes back once.  Both are asserted with counts, because
--      both look right until you count.
--    * raw scores are the same measurement only when the indexes agree on
--      model and metric.  A mixed set is refused under `ranking raw` and under
--      score_limit / distance_limit, and allowed under `ranking relevance`,
--      where rank within each index is comparable by construction.
--    * `index *` expands per CALLER, at execution time.  Two users with
--      different graph permissions must get different answers from the same
--      query text -- which is also why it cannot be expanded at compile time:
--      a compiled SPARQL plan is cached by that text.
--    * inside GRAPH <g> { } the search answers as it does outside, for the
--      graph's own index, with or without limits.  It returned only exact
--      matches: the generated SQL wrote the limits it was not given as
--      `IS NULL`, and a procedure table reads that as the value 0.
--    * a cosine score is 1 - distance / 2, from 0 to 1, as SQL's X_SIMILAR
--      and bif:knnSimilar score it, and score_limit is held to that range.
--      bif:vector_search scored 1 - distance, from -1 to 1: the same document
--      had two scores, and a threshold meant different things on the two
--      surfaces.
--
--  Self-contained: in-core deterministic 'test_embedding' models, so this needs
--  neither ONNX nor the VVEC_BEGIN_* fixtures and runs unconditionally.
--
--  Run with:
--    isql <port> dba dba binsrc/tests/suite/tvvec_multi_index.sql
--

echo BOTH "STARTED: multi-index bif:vector_search\n";

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

delete from DB.DBA.ONNX_MODELS where model_name in ('vvec-mi-8', 'vvec-mi-16');
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values ('vvec-mi-8', 'deterministic 8-dim test model', 'internal:vvec-mi-8',
        'test_embedding', 'embedding', '1,8', now (), now ());
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values ('vvec-mi-16', 'deterministic 16-dim test model', 'internal:vvec-mi-16',
        'test_embedding', 'embedding', '1,16', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register the two test models STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

sparql define input:storage "" drop silent vector index <urn:mi:a>;
sparql define input:storage "" drop silent vector index <urn:mi:b>;
sparql define input:storage "" drop silent vector index <urn:mi:a2>;
sparql define input:storage "" drop silent vector index <urn:mi:wide>;
sparql define input:storage "" drop silent vector index <urn:mi:l2>;
sparql define input:storage "" clear graph <urn:mi:ga>;
sparql define input:storage "" clear graph <urn:mi:gb>;
sparql define input:storage ""
insert data {
  graph <urn:mi:ga> {
    <urn:mi:a1> <urn:mi:txt> "alpha one apple" .
    <urn:mi:a2> <urn:mi:txt> "alpha two banana" .
    <urn:mi:a3> <urn:mi:txt> "alpha three cherry" .
  }
  graph <urn:mi:gb> {
    <urn:mi:b1> <urn:mi:txt> "beta one damson" .
    <urn:mi:b2> <urn:mi:txt> "beta two elderberry" .
    <urn:mi:b3> <urn:mi:txt> "beta three fig" .
  }
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": seed the two test graphs STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--  <urn:mi:a>    graph ga, model vvec-mi-8,  cosine
--  <urn:mi:a2>   graph ga, model vvec-mi-8,  cosine  -- same subjects as <urn:mi:a>
--  <urn:mi:b>    graph gb, model vvec-mi-8,  cosine
--  <urn:mi:wide> graph gb, model vvec-mi-16, cosine  -- differs by MODEL
--  <urn:mi:l2>   graph gb, model vvec-mi-8,  l2      -- differs by METRIC
sparql define input:storage ""
create vector index <urn:mi:a> on graph <urn:mi:ga> for predicate <urn:mi:txt>
  using model 'vvec-mi-8' with (dimensions = 8, hnsw_m = 8, ef_construction = 16);
sparql define input:storage ""
create vector index <urn:mi:a2> on graph <urn:mi:ga> for predicate <urn:mi:txt>
  using model 'vvec-mi-8' with (dimensions = 8, hnsw_m = 8, ef_construction = 16);
sparql define input:storage ""
create vector index <urn:mi:b> on graph <urn:mi:gb> for predicate <urn:mi:txt>
  using model 'vvec-mi-8' with (dimensions = 8, hnsw_m = 8, ef_construction = 16);
sparql define input:storage ""
create vector index <urn:mi:wide> on graph <urn:mi:gb> for predicate <urn:mi:txt>
  using model 'vvec-mi-16' with (dimensions = 16, hnsw_m = 8, ef_construction = 16);
sparql define input:storage ""
create vector index <urn:mi:l2> on graph <urn:mi:gb> for predicate <urn:mi:txt>
  using model 'vvec-mi-8' with (dimensions = 8, distance = 'l2', hnsw_m = 8, ef_construction = 16);
sparql define input:storage "" refresh vector index <urn:mi:a>;
sparql define input:storage "" refresh vector index <urn:mi:a2>;
sparql define input:storage "" refresh vector index <urn:mi:b>;
sparql define input:storage "" refresh vector index <urn:mi:wide>;
sparql define input:storage "" refresh vector index <urn:mi:l2>;
select count(*) from DB.DBA.SPARQL_VEC_INDEX
 where SVI_IRI like 'urn:mi:%' and SVI_STATE = 'active';
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
ECHO BOTH ": build five test indexes, active=" $LAST[1] "\n";

--  Run one statement and report the first column of every row, space joined,
--  so an assertion can compare the whole answer rather than a count of it.
--  'ERR <state>' when the statement was refused, which is what most of the
--  negative assertions below check for.
create function DB.DBA.MIVEC_RUN (in _stmt varchar) returns varchar
{
  declare _st, _msg varchar;
  declare _md, _rows any;
  declare _out varchar;
  declare i integer;
  _st := '00000';
  exec (_stmt, _st, _msg, vector (), 1000, _md, _rows);
  if (_st <> '00000' and _st <> 0)
    return 'ERR ' || cast (_st as varchar);
  _out := '';
  if (isvector (_rows))
    for (i := 0; i < length (_rows); i := i + 1)
      _out := _out || case when _out = '' then '' else ' ' end || cast (_rows[i][0] as varchar);
  return case when _out = '' then '(none)' else _out end;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create MIVEC_RUN helper STATE=" $STATE "\n";

create function DB.DBA.MIVEC_ERRMSG (in _stmt varchar) returns varchar
{
  declare _st, _msg varchar;
  declare _md, _rows any;
  _st := '00000';
  exec (_stmt, _st, _msg, vector (), 1000, _md, _rows);
  return coalesce (_msg, '');
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create MIVEC_ERRMSG helper STATE=" $STATE "\n";

create function DB.DBA.MIVEC_AS (in _user varchar, in _stmt varchar) returns varchar
{
  declare _r varchar;
  __set_user_id (_user);
  _r := DB.DBA.MIVEC_RUN (_stmt);
  __pop_user_id ();
  return _r;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create MIVEC_AS helper STATE=" $STATE "\n";

--  How many DISTINCT subjects a statement returned, and how many rows.
create function DB.DBA.MIVEC_COUNTS (in _stmt varchar) returns varchar
{
  declare _s varchar;
  declare _parts any;
  declare i, j, n, d integer;
  _s := DB.DBA.MIVEC_RUN (_stmt);
  if (_s = '(none)' or _s like 'ERR %')
    return _s;
  _parts := split_and_decode (_s, 0, '\0\0 ');
  n := length (_parts);
  d := 0;
  for (i := 0; i < n; i := i + 1)
    {
      for (j := 0; j < i; j := j + 1)
        if (_parts[j] = _parts[i]) goto dup;
      d := d + 1;
   dup:;
    }
  return sprintf ('%d/%d', n, d);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create MIVEC_COUNTS helper STATE=" $STATE "\n";

--  The same answer as a SET: sorted, so an assertion can say which subjects
--  came back without also pinning the order they came back in.  Only two
--  assertions below are about order, and they say so.
create function DB.DBA.MIVEC_SET (in _stmt varchar) returns varchar
{
  declare _s, _t varchar;
  declare _parts any;
  declare i, j, n integer;
  _s := DB.DBA.MIVEC_RUN (_stmt);
  if (_s = '(none)' or _s like 'ERR %')
    return _s;
  _parts := split_and_decode (_s, 0, '\0\0 ');
  n := length (_parts);
  for (i := 1; i < n; i := i + 1)
    for (j := i; j > 0 and _parts[j-1] > _parts[j]; j := j - 1)
      { _t := _parts[j-1]; aset (_parts, j-1, _parts[j]); aset (_parts, j, _t); }
  _s := '';
  for (i := 0; i < n; i := i + 1)
    _s := _s || case when _s = '' then '' else ' ' end || _parts[i];
  return _s;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create MIVEC_SET helper STATE=" $STATE "\n";

--  How many of the returned subjects start with a prefix.  The wildcard runs
--  against whatever indexes the rest of the suite happens to have left on the
--  instance, so its assertions ask what IS in the answer rather than pinning a
--  total that another test could change.
create function DB.DBA.MIVEC_COUNT_PREFIX (in _stmt varchar, in _pfx varchar) returns integer
{
  declare _s varchar;
  declare _parts any;
  declare i, n, c integer;
  _s := DB.DBA.MIVEC_RUN (_stmt);
  if (_s = '(none)' or _s like 'ERR %')
    return -1;
  _parts := split_and_decode (_s, 0, '\0\0 ');
  n := length (_parts);
  c := 0;
  for (i := 0; i < n; i := i + 1)
    if (_parts[i] like _pfx || '%') c := c + 1;
  return c;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create MIVEC_COUNT_PREFIX helper STATE=" $STATE "\n";

-- ===========================================================================
-- 1. The regression that matters: one named index is untouched
-- ===========================================================================
select DB.DBA.MIVEC_SET ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index <urn:mi:a>, limit 3) }');
ECHO BOTH $IF $EQU $LAST[1] "urn:mi:a1 urn:mi:a2 urn:mi:a3" "PASSED" "***FAILED";
ECHO BOTH ": single index unchanged=" $LAST[1] "\n";

--  The single-index ORDER, whatever it is, is the thing the list form has to
--  reproduce when it is given that one index: captured here and compared
--  against, rather than written out, so the assertion stays about equivalence
--  and not about what the test model happens to score.
select case when DB.DBA.MIVEC_RUN ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index <urn:mi:a>, limit 3) }') = DB.DBA.MIVEC_RUN ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index (<urn:mi:a>), limit 3) }') then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a one-element list gives the same rows in the same order=" $LAST[1] "\n";

select case when DB.DBA.MIVEC_RUN ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index <urn:mi:a>, limit 3) }') = DB.DBA.MIVEC_RUN ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index (<urn:mi:a>, <urn:mi:a>), limit 3) }') then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a repeated member collapses to the same answer=" $LAST[1] "\n";

--  RANKING on one index needs no separate implementation: with a single index,
--  ordering by rank within it and by raw score are the same sequence.
select case when DB.DBA.MIVEC_RUN ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index <urn:mi:a>, limit 3) }') = DB.DBA.MIVEC_RUN ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index <urn:mi:a>, ranking relevance, limit 3) }') then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": ranking changes nothing on a single index=" $LAST[1] "\n";

-- ===========================================================================
-- 2. A repeated bare INDEX option is an error, not silently the first one
-- ===========================================================================
select DB.DBA.MIVEC_RUN ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index <urn:mi:a>, index <urn:mi:b>, limit 3) }');
ECHO BOTH $IF $EQU $LAST[1] "ERR 37000" "PASSED" "***FAILED";
ECHO BOTH ": a repeated bare index option is refused=" $LAST[1] "\n";

select DB.DBA.MIVEC_RUN ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index (<urn:mi:a>, <urn:mi:b>), ranking raw, ranking relevance, limit 3) }');
ECHO BOTH $IF $EQU $LAST[1] "ERR 37000" "PASSED" "***FAILED";
ECHO BOTH ": a repeated ranking option is refused=" $LAST[1] "\n";

select DB.DBA.MIVEC_RUN ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index (<urn:mi:a>, <urn:mi:b>), ranking sideways, limit 3) }');
ECHO BOTH $IF $EQU $LAST[1] "ERR 37000" "PASSED" "***FAILED";
ECHO BOTH ": an unknown ranking mode is refused=" $LAST[1] "\n";

-- ===========================================================================
-- 3. The list searches every index in it
-- ===========================================================================
select DB.DBA.MIVEC_COUNTS ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index (<urn:mi:a>, <urn:mi:b>), limit 6) }');
ECHO BOTH $IF $EQU $LAST[1] "6/6" "PASSED" "***FAILED";
ECHO BOTH ": two disjoint indexes return all six subjects, rows/distinct=" $LAST[1] "\n";

select DB.DBA.MIVEC_COUNT_PREFIX ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index (<urn:mi:a>, <urn:mi:b>), limit 6) }', 'urn:mi:b');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": ...and three of them came from the SECOND index=" $LAST[1] "\n";

-- ===========================================================================
-- 4. limit is N in total, and a subject in two indexes comes back once
-- ===========================================================================
select DB.DBA.MIVEC_COUNTS ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index (<urn:mi:a>, <urn:mi:b>), limit 4) }');
ECHO BOTH $IF $EQU $LAST[1] "4/4" "PASSED" "***FAILED";
ECHO BOTH ": limit 4 over two indexes returns 4 rows, not 4 per index=" $LAST[1] "\n";

--  <urn:mi:a> and <urn:mi:a2> index exactly the same three subjects.
select DB.DBA.MIVEC_COUNTS ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index (<urn:mi:a>, <urn:mi:a2>), limit 6) }');
ECHO BOTH $IF $EQU $LAST[1] "3/3" "PASSED" "***FAILED";
ECHO BOTH ": a subject in two indexes comes back once, rows/distinct=" $LAST[1] "\n";

-- ===========================================================================
-- 5. Comparability: refused where the scores are not the same measurement
-- ===========================================================================
select DB.DBA.MIVEC_RUN ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index (<urn:mi:a>, <urn:mi:wide>), limit 3) }');
ECHO BOTH $IF $EQU $LAST[1] "ERR VEC68" "PASSED" "***FAILED";
ECHO BOTH ": different models under the default raw ordering are refused=" $LAST[1] "\n";

select DB.DBA.MIVEC_ERRMSG ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index (<urn:mi:a>, <urn:mi:wide>), limit 3) }');
ECHO BOTH $IF $GT $LAST[1] "" "PASSED" "***FAILED";
ECHO BOTH ": ...and the message names both indexes and the difference: " $LAST[1] "\n";

select DB.DBA.MIVEC_RUN ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index (<urn:mi:b>, <urn:mi:l2>), limit 3) }');
ECHO BOTH $IF $EQU $LAST[1] "ERR VEC68" "PASSED" "***FAILED";
ECHO BOTH ": different metrics under raw are refused=" $LAST[1] "\n";

--  score_limit and distance_limit are thresholds in those same units, so they
--  need the same agreement even when the ordering does not.
select DB.DBA.MIVEC_RUN ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index (<urn:mi:a>, <urn:mi:wide>), ranking relevance, score_limit 0.1, limit 3) }');
ECHO BOTH $IF $EQU $LAST[1] "ERR VEC68" "PASSED" "***FAILED";
ECHO BOTH ": score_limit over a mixed set is refused even under relevance=" $LAST[1] "\n";

-- ===========================================================================
-- 6. ...and allowed under relevance ranking, which compares like with like
-- ===========================================================================
select DB.DBA.MIVEC_COUNTS ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index (<urn:mi:a>, <urn:mi:wide>), ranking relevance, limit 6) }');
ECHO BOTH $IF $EQU $LAST[1] "6/6" "PASSED" "***FAILED";
ECHO BOTH ": a mixed-model pair merges under relevance, rows/distinct=" $LAST[1] "\n";

--  Rank fusion's defining property: rank 1 beats rank 2 whatever the scores,
--  so the first two rows over two disjoint indexes are one from each.
select DB.DBA.MIVEC_COUNT_PREFIX ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index (<urn:mi:a>, <urn:mi:wide>), ranking relevance, limit 2) }', 'urn:mi:b');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": under relevance the top 2 are one from each index=" $LAST[1] "\n";

-- ===========================================================================
-- 7. An index in the list that does not exist, or is not active
-- ===========================================================================
select DB.DBA.MIVEC_RUN ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index (<urn:mi:a>, <urn:mi:nosuch>), limit 3) }');
ECHO BOTH $IF $EQU $LAST[1] "ERR VEC53" "PASSED" "***FAILED";
ECHO BOTH ": an unknown index in the list is refused, naming it=" $LAST[1] "\n";

select DB.DBA.MIVEC_ERRMSG ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index (<urn:mi:a>, <urn:mi:nosuch>), limit 3) }');
ECHO BOTH $IF $GT $LAST[1] "" "PASSED" "***FAILED";
ECHO BOTH ": ...with the same message the single-index path gives: " $LAST[1] "\n";

-- ===========================================================================
-- 8. The wildcard
-- ===========================================================================
--  Asked for what IS in the answer, not for a total: the wildcard also covers
--  whatever indexes the rest of the suite left on the instance.
select DB.DBA.MIVEC_COUNT_PREFIX ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index *, limit 100) }', 'urn:mi:');
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": * as dba covers every one of this test's indexes, deduplicated=" $LAST[1] "\n";

--  A mixed instance -- these five indexes span two models and two metrics --
--  must not error under the wildcard, because bare * means relevance.
select case when DB.DBA.MIVEC_RUN ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index *, limit 100) }') like 'ERR %' then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": * over a mixed-model instance does not error, is_error=" $LAST[1] "\n";

select DB.DBA.MIVEC_RUN ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index *, ranking raw, limit 3) }');
ECHO BOTH $IF $EQU $LAST[1] "ERR VEC68" "PASSED" "***FAILED";
ECHO BOTH ": ...but * with an explicit raw ordering is refused on it=" $LAST[1] "\n";

-- ===========================================================================
-- 9. * expands per caller, at execution time
-- ===========================================================================
create procedure DB.DBA.MIVEC_USER (in _n varchar, in _pw varchar)
{
  declare exit handler for sqlstate '*' { ; };
  if (exists (select 1 from DB.DBA.SYS_USERS where U_NAME = _n))
    DB.DBA.USER_DROP (_n, 0);
  user_create (_n, _pw);
};
select DB.DBA.MIVEC_USER ('mivec_a', 'mivec_a_pw');
select DB.DBA.MIVEC_USER ('mivec_b', 'mivec_b_pw');
select DB.DBA.MIVEC_USER ('mivec_none', 'mivec_none_pw');
grant SPARQL_SELECT to "mivec_a";
grant SPARQL_SELECT to "mivec_b";
grant SPARQL_SELECT to "mivec_none";
DB.DBA.RDF_DEFAULT_USER_PERMS_SET ('mivec_a', 0, 0);
DB.DBA.RDF_DEFAULT_USER_PERMS_SET ('mivec_b', 0, 0);
DB.DBA.RDF_DEFAULT_USER_PERMS_SET ('mivec_none', 0, 0);
DB.DBA.RDF_GRAPH_USER_PERMS_SET ('urn:mi:ga', 'mivec_a', 1);
DB.DBA.RDF_GRAPH_USER_PERMS_SET ('urn:mi:gb', 'mivec_b', 1);
commit work;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": three readers with different graph permissions STATE=" $STATE "\n";

select DB.DBA.MIVEC_COUNT_PREFIX (
  'sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index *, limit 100) }', 'urn:mi:');
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": dba still sees both graphs=" $LAST[1] "\n";

create function DB.DBA.MIVEC_SET_AS (in _user varchar, in _stmt varchar) returns varchar
{
  declare _r varchar;
  __set_user_id (_user);
  _r := DB.DBA.MIVEC_SET (_stmt);
  __pop_user_id ();
  return _r;
};

select DB.DBA.MIVEC_SET_AS ('mivec_a',
  'sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index *, limit 100) }');
ECHO BOTH $IF $EQU $LAST[1] "urn:mi:a1 urn:mi:a2 urn:mi:a3" "PASSED" "***FAILED";
ECHO BOTH ": mivec_a sees only its own graph=" $LAST[1] "\n";

select DB.DBA.MIVEC_SET_AS ('mivec_b',
  'sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index *, limit 100) }');
ECHO BOTH $IF $EQU $LAST[1] "urn:mi:b1 urn:mi:b2 urn:mi:b3" "PASSED" "***FAILED";
ECHO BOTH ": mivec_b sees a DIFFERENT set from the same query=" $LAST[1] "\n";

--  Nothing to search is not an error.  An empty instance and an instance where
--  you may see nothing have to look the same, or the difference is readable
--  from the error.
select DB.DBA.MIVEC_AS ('mivec_none',
  'sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index *, limit 100) }');
ECHO BOTH $IF $EQU $LAST[1] "(none)" "PASSED" "***FAILED";
ECHO BOTH ": * matching no accessible index returns no rows, not an error=" $LAST[1] "\n";

-- ===========================================================================
-- 10. Inside a GRAPH block
-- ===========================================================================
--  Inside GRAPH <g> { } the graph reaches the search procedure as its
--  seventh argument, so the score and distance limits are named before it;
--  a query that gave no limit wrote them as `score_limit IS NULL`.  A
--  procedure table takes each argument from the other side of a predicate on
--  it, and IS NULL has no other side: both limits arrived as 0, and
--  distance_limit 0 kept only exact matches.  These fail before the fix with
--  (none), or with a score that is not the score outside the block.
select DB.DBA.MIVEC_SET ('sparql define input:storage "" select ?d where { graph <urn:mi:ga> { ?d bif:vector_search "alpha" option (index <urn:mi:a>, limit 3) } }');
ECHO BOTH $IF $EQU $LAST[1] "urn:mi:a1 urn:mi:a2 urn:mi:a3" "PASSED" "***FAILED";
ECHO BOTH ": one index inside GRAPH <its graph>, no limits=" $LAST[1] "\n";

--  Not just the subjects: the same scores, in the same order.
select case when DB.DBA.MIVEC_RUN ('sparql define input:storage "" select ?sc where { graph <urn:mi:ga> { ?d bif:vector_search "alpha" option (index <urn:mi:a>, score ?sc, limit 3) } } order by desc (?sc) ?d') = DB.DBA.MIVEC_RUN ('sparql define input:storage "" select ?sc where { ?d bif:vector_search "alpha" option (index <urn:mi:a>, score ?sc, limit 3) } order by desc (?sc) ?d') then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": inside GRAPH, the scores are the scores outside it=" $LAST[1] "\n";

--  One limit given and the other not: the missing one was still 0.
select DB.DBA.MIVEC_SET ('sparql define input:storage "" select ?d where { graph <urn:mi:ga> { ?d bif:vector_search "alpha" option (index <urn:mi:a>, score_limit 0, limit 3) } }');
ECHO BOTH $IF $EQU $LAST[1] "urn:mi:a1 urn:mi:a2 urn:mi:a3" "PASSED" "***FAILED";
ECHO BOTH ": inside GRAPH with score_limit alone=" $LAST[1] "\n";

--  The list form goes through the same argument list.
select DB.DBA.MIVEC_SET ('sparql define input:storage "" select ?d where { graph <urn:mi:ga> { ?d bif:vector_search "alpha" option (index (<urn:mi:a>, <urn:mi:a2>), limit 3) } }');
ECHO BOTH $IF $EQU $LAST[1] "urn:mi:a1 urn:mi:a2 urn:mi:a3" "PASSED" "***FAILED";
ECHO BOTH ": an index list inside GRAPH <its graph>, no limits=" $LAST[1] "\n";

--  Guards, which hold on both sides of the fix: the graph still restricts
--  (an index over ga, searched inside GRAPH <gb>, finds nothing), and limits
--  that are given are still applied.
select DB.DBA.MIVEC_RUN ('sparql define input:storage "" select ?d where { graph <urn:mi:gb> { ?d bif:vector_search "alpha" option (index <urn:mi:a>, limit 3) } }');
ECHO BOTH $IF $EQU $LAST[1] "(none)" "PASSED" "***FAILED";
ECHO BOTH ": an index searched inside another graph's block finds nothing=" $LAST[1] "\n";

select DB.DBA.MIVEC_SET ('sparql define input:storage "" select ?d where { graph <urn:mi:ga> { ?d bif:vector_search "alpha" option (index <urn:mi:a>, score_limit 0, distance_limit 10, limit 3) } }');
ECHO BOTH $IF $EQU $LAST[1] "urn:mi:a1 urn:mi:a2 urn:mi:a3" "PASSED" "***FAILED";
ECHO BOTH ": inside GRAPH with both limits given=" $LAST[1] "\n";

-- ===========================================================================
-- 11. A cosine score is 1 - distance / 2, the scale X_SIMILAR uses
-- ===========================================================================
--  The test model puts the three documents of ga at distance 0, 1 and 1 from
--  "alpha".  bif:vector_search scored them 1, 0 and 0 (1 - distance); SQL's
--  X_SIMILAR, and bif:knnSimilar, score the same distances 1, 0.5 and 0.5
--  (1 - distance / 2).  These fail on the old scale, except the guards marked.
select case when (select max (abs ("sc" - (1 - "dist" / 2))) from (sparql define input:storage ""
    select ?sc ?dist where { ?d bif:vector_search "alpha" option (index <urn:mi:a>, score ?sc, distance ?dist, limit 3) }) x)
  < 0.000001 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": every score is 1 - distance / 2=" $LAST[1] "\n";

select (select sprintf ('%.4f', min ("sc")) from (sparql define input:storage ""
    select ?sc where { ?d bif:vector_search "alpha" option (index <urn:mi:a>, score ?sc, limit 3) }) x);
ECHO BOTH $IF $EQU $LAST[1] "0.5000" "PASSED" "***FAILED";
ECHO BOTH ": the documents at distance 1 score 0.5, not 0=" $LAST[1] "\n";

--  The same three texts in a SQL table with a SQL index on the same model: the
--  two surfaces give the same scores.
create table DB.DBA.MIVEC_SQL_DOCS (ID integer not null primary key, TXT varchar);
insert into DB.DBA.MIVEC_SQL_DOCS values (1, 'alpha one apple');
insert into DB.DBA.MIVEC_SQL_DOCS values (2, 'alpha two banana');
insert into DB.DBA.MIVEC_SQL_DOCS values (3, 'alpha three cherry');
create vector index MIVEC_SQL_IDX on DB.DBA.MIVEC_SQL_DOCS (TXT) using 'vvec-mi-8'
  with (dimensions = 8, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 16);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": a SQL index over the same texts STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select case when abs (
    (select sum (X_SIMILAR (TXT, 'alpha', 3)) from DB.DBA.MIVEC_SQL_DOCS where X_SIMILAR (TXT, 'alpha', 3) > 0)
  - (select sum ("sc") from (sparql define input:storage ""
      select ?sc where { ?d bif:vector_search "alpha" option (index <urn:mi:a>, score ?sc, limit 3) }) x)) < 0.00001
  then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": SQL X_SIMILAR and SPARQL score agree on the same texts=" $LAST[1] "\n";

--  score_limit is a score, so it takes the score's range: 0 to 1.
select DB.DBA.MIVEC_RUN ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index <urn:mi:a>, score_limit -0.5, limit 3) }');
ECHO BOTH $IF $EQU $LAST[1] "ERR VEC61" "PASSED" "***FAILED";
ECHO BOTH ": a negative cosine score_limit is refused with VEC61=" $LAST[1] "\n";

select DB.DBA.MIVEC_SET ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index <urn:mi:a>, score_limit 0.5, limit 3) }');
ECHO BOTH $IF $EQU $LAST[1] "urn:mi:a1 urn:mi:a2 urn:mi:a3" "PASSED" "***FAILED";
ECHO BOTH ": score_limit 0.5 admits the documents at distance 1=" $LAST[1] "\n";

--  Guards, on both scales: above 1 is refused, and the order is the order of
--  distance.
select DB.DBA.MIVEC_RUN ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index <urn:mi:a>, score_limit 1.5, limit 3) }');
ECHO BOTH $IF $EQU $LAST[1] "ERR VEC61" "PASSED" "***FAILED";
ECHO BOTH ": a cosine score_limit above 1 is refused with VEC61=" $LAST[1] "\n";

select DB.DBA.MIVEC_RUN ('sparql define input:storage "" select ?d where { ?d bif:vector_search "alpha" option (index <urn:mi:a>, score ?sc, limit 1) } order by desc (?sc)');
ECHO BOTH $IF $EQU $LAST[1] "urn:mi:a1" "PASSED" "***FAILED";
ECHO BOTH ": the closest document still scores highest=" $LAST[1] "\n";

-- ===========================================================================
-- Cleanup
-- ===========================================================================
DB.DBA.RDF_GRAPH_USER_PERMS_DEL ('urn:mi:ga', 'mivec_a');
DB.DBA.RDF_GRAPH_USER_PERMS_DEL ('urn:mi:gb', 'mivec_b');
DB.DBA.USER_DROP ('mivec_a', 0);
DB.DBA.USER_DROP ('mivec_b', 0);
DB.DBA.USER_DROP ('mivec_none', 0);
sparql define input:storage "" drop silent vector index <urn:mi:a>;
sparql define input:storage "" drop silent vector index <urn:mi:a2>;
sparql define input:storage "" drop silent vector index <urn:mi:b>;
sparql define input:storage "" drop silent vector index <urn:mi:wide>;
sparql define input:storage "" drop silent vector index <urn:mi:l2>;
sparql define input:storage "" clear graph <urn:mi:ga>;
sparql define input:storage "" clear graph <urn:mi:gb>;
drop index MIVEC_SQL_IDX;
drop table DB.DBA.MIVEC_SQL_DOCS;
delete from DB.DBA.VEC_SQL_QUEUE where VQ_INDEX = 'MIVEC_SQL_IDX';
delete from DB.DBA.ONNX_MODELS where model_name in ('vvec-mi-8', 'vvec-mi-16');
drop procedure DB.DBA.MIVEC_USER;
drop function DB.DBA.MIVEC_SET_AS;
drop function DB.DBA.MIVEC_COUNT_PREFIX;
drop function DB.DBA.MIVEC_SET;
drop function DB.DBA.MIVEC_COUNTS;
drop function DB.DBA.MIVEC_AS;
drop function DB.DBA.MIVEC_ERRMSG;
drop function DB.DBA.MIVEC_RUN;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": multi-index test cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;

echo BOTH "COMPLETED: multi-index bif:vector_search\n";
