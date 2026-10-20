--
--  tvec_sparql_for_predicate.sql
--
--  The vector index shorthand selector, FOR PREDICATE <iri>, and the RDF 1.2
--  built-in PREDICATE() use the same word.  The lexer returns PREDICATE as
--  the built-in, so the selector rule has to accept that token and refuse
--  any other built-in name after FOR.  Both forms must parse: a grammar that
--  keeps only the selector makes every PREDICATE() a syntax error while
--  SUBJECT() and OBJECT() still work.
--
--  Every statement is compiled with sparql_to_sql_text () and not run, so
--  this needs no model, no vonnx and no fixtures, and does not depend on the
--  CaseMode of the server.
--
--  Run with:
--    isql <port> dba dba binsrc/tests/suite/tvec_sparql_for_predicate.sql
--

echo BOTH "STARTED: SPARQL vector index FOR PREDICATE and the PREDICATE() built-in\n";

-- Compile Q without running it.  'OK' when the generated SQL contains every
-- string in NEEDLES, otherwise the first one missing or the error raised.
create procedure DB.DBA.TVEC_FOR_PRED_COMPILE (in q varchar, in needles any) returns varchar
{
  declare sqltext varchar;
  declare inx integer;
  declare exit handler for sqlstate '*' { return __SQL_STATE || ' ' || __SQL_MESSAGE; };
  sqltext := cast (sparql_to_sql_text (q) as varchar);
  for (inx := 0; inx < length (needles); inx := inx + 1)
    {
      if (strstr (sqltext, needles[inx]) is null)
        return 'compiled without ' || needles[inx];
    }
  return 'OK';
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TVEC_FOR_PRED_COMPILE helper STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Compile Q, which must be refused.  'REJECTED' when the error message
-- contains NEEDLE, 'ACCEPTED' when Q compiled, otherwise the error raised.
create procedure DB.DBA.TVEC_FOR_PRED_REJECT (in q varchar, in needle varchar) returns varchar
{
  declare exit handler for sqlstate '*' {
    if (strstr (__SQL_MESSAGE, needle) is not null)
      return 'REJECTED';
    return __SQL_STATE || ' ' || __SQL_MESSAGE;
  };
  sparql_to_sql_text (q);
  return 'ACCEPTED';
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TVEC_FOR_PRED_REJECT helper STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- ===========================================================================
-- 1. FOR PREDICATE declares the shorthand selector, with and without ON GRAPH
-- ===========================================================================
select DB.DBA.TVEC_FOR_PRED_COMPILE (
  'create vector index <urn:forpred:idx> on graph <urn:forpred:g> for predicate <urn:forpred:p> using model ''forpred-model''',
  vector ('VEC_INDEX_SET_SELECTOR', '''shorthand''', 'UNAME''urn:forpred:g''', 'UNAME''urn:forpred:p'''));
ECHO BOTH $IF $EQU $LAST[1] OK "PASSED" "***FAILED";
ECHO BOTH ": ON GRAPH <g> for predicate <p> declares a shorthand selector on <g> and <p>: " $LAST[1] "\n";

select DB.DBA.TVEC_FOR_PRED_COMPILE (
  'create vector index <urn:forpred:idx> FOR PREDICATE <urn:forpred:p> using model ''forpred-model''',
  vector ('VEC_INDEX_SET_SELECTOR', '''shorthand''', 'UNAME''urn:forpred:p'''));
ECHO BOTH $IF $EQU $LAST[1] OK "PASSED" "***FAILED";
ECHO BOTH ": FOR PREDICATE <p> without ON GRAPH declares a shorthand selector on <p>: " $LAST[1] "\n";

-- ===========================================================================
-- 2. Everywhere else PREDICATE() is the RDF 1.2 built-in
-- ===========================================================================
select DB.DBA.TVEC_FOR_PRED_COMPILE (
  'select (PREDICATE(?t) as ?p) where { ?r <urn:forpred:about> ?t }',
  vector ('RDF_STAR_TT_GET_P'));
ECHO BOTH $IF $EQU $LAST[1] OK "PASSED" "***FAILED";
ECHO BOTH ": PREDICATE(?t) compiles to RDF_STAR_TT_GET_P: " $LAST[1] "\n";

select DB.DBA.TVEC_FOR_PRED_COMPILE (
  'select ?r where { ?r <urn:forpred:about> ?t . filter (predicate(?t) = <urn:forpred:p>) }',
  vector ('RDF_STAR_TT_GET_P'));
ECHO BOTH $IF $EQU $LAST[1] OK "PASSED" "***FAILED";
ECHO BOTH ": predicate(?t) in a FILTER compiles to RDF_STAR_TT_GET_P: " $LAST[1] "\n";

-- ===========================================================================
-- 3. Any other word after FOR is refused
-- ===========================================================================
select DB.DBA.TVEC_FOR_PRED_REJECT (
  'create vector index <urn:forpred:idx> on graph <urn:forpred:g> for subject <urn:forpred:p> using model ''forpred-model''',
  'PREDICATE expected after FOR');
ECHO BOTH $IF $EQU $LAST[1] REJECTED "PASSED" "***FAILED";
ECHO BOTH ": FOR SUBJECT <p> is refused as PREDICATE expected after FOR: " $LAST[1] "\n";

select DB.DBA.TVEC_FOR_PRED_REJECT (
  'create vector index <urn:forpred:idx> on graph <urn:forpred:g> for str <urn:forpred:p> using model ''forpred-model''',
  'PREDICATE expected after FOR');
ECHO BOTH $IF $EQU $LAST[1] REJECTED "PASSED" "***FAILED";
ECHO BOTH ": FOR STR <p> is refused as PREDICATE expected after FOR: " $LAST[1] "\n";

select DB.DBA.TVEC_FOR_PRED_REJECT (
  'create vector index <urn:forpred:idx> on graph <urn:forpred:g> for <urn:forpred:p> using model ''forpred-model''',
  'syntax error');
ECHO BOTH $IF $EQU $LAST[1] REJECTED "PASSED" "***FAILED";
ECHO BOTH ": FOR <p> without PREDICATE is a syntax error: " $LAST[1] "\n";

-- ===========================================================================
-- Cleanup
-- ===========================================================================
drop procedure DB.DBA.TVEC_FOR_PRED_COMPILE;
drop procedure DB.DBA.TVEC_FOR_PRED_REJECT;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": FOR PREDICATE test cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: SPARQL vector index FOR PREDICATE and the PREDICATE() built-in\n";
