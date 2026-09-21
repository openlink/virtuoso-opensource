#!/bin/sh
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2026 OpenLink Software
#
#  This project is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; only version 2 of the License, dated June 1991.
#
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#
#
#
#  openGQL: GQL for Virtuoso - wildcard edge negation (!%) benchmark (P2-3)
#
#  Question this answers: does GQL's wildcard negation !% (which the translator
#  lowers to FILTER NOT EXISTS, because SPARQL has no "no predicate" negated
#  path operator) scale WORSE than specific-label negation !iri (which lowers
#  to a native negated property path)? See binsrc/gql/gql-limitations.md.
#
#  The answer is about SCALING (the slope across dataset sizes), not one number,
#  so this runs a size SWEEP and compares three queries at each size:
#    NEGWILD  MATCH (a)-[:!%]->(b)          -> FILTER NOT EXISTS (the case under test)
#    NEGIRI   MATCH (a)-[:!bench:knows]->(b) -> native negated property path (yardstick)
#    BASE     MATCH (a)-[:bench:knows]->(b)  -> positive join (isolates negation cost)
#  NOTE the leading colon: in GQL an edge pattern is [var:type], so the type
#  MUST be introduced by ':'.  Without it, [bench:knows] parses as edge-variable
#  "bench" of type "knows" (and [!...] fails to parse entirely).
#  It prints the generated SPARQL for each (so you see exactly what is timed) and
#  writes the full explain() plans to $OUTDIR — the plan is the real story; watch
#  for a plan flip (hash anti-join -> per-row subquery) as size grows.
#
#  Dataset shape (per node, in the GQL->RDF mapping):
#    1 rdf:type triple + PROPS property triples + ~DEGREE edge triples.
#    So triples ~= NODES * (1 + PROPS + DEGREE). With the defaults
#    (PROPS=3, DEGREE=3) that is ~7 triples/node, i.e.:
#       NODES  10K -> ~70K triples     (noise floor; execution is sub-ms)
#       NODES 100K -> ~700K triples    (trustworthy minimum; !% query > ~100ms)
#       NODES   1M -> ~7M triples      (a bad anti-join plan becomes unmistakable)
#    EMPTY_PCT % of nodes are given NO outgoing edge (so !% has real matches).
#    NOTE: the cost is driven by candidate-node count, not raw triples; an
#    edge-property-heavy (reified) graph inflates triples ~4-5x per edge without
#    adding candidate nodes, so it would need proportionally more triples.
#
#  Usage:
#    PORT=1111 DBA_USER=dba DBA_PASS=dba \
#      SIZES="10000 100000 1000000" \
#      sh binsrc/gql/bench_wildcard_negation.sh
#
#  DOES NOT run automatically; invoke it explicitly. Start with the default
#  modest SIZES and watch the plans before scaling to millions of nodes.
#

set -u

PORT="${PORT:-1111}"
DBA_USER="${DBA_USER:-dba}"
DBA_PASS="${DBA_PASS:-dba}"
ISQL="${ISQL:-$(which isql 2>/dev/null)}"

# Sweep of NODE counts (triples ~= NODES * (1 + PROPS + DEGREE)).
SIZES="${SIZES:-10000 100000 1000000}"
DEGREE="${DEGREE:-3}"        # average out-degree of non-empty nodes
PROPS="${PROPS:-3}"          # data properties per node
EMPTY_PCT="${EMPTY_PCT:-20}" # % of nodes with NO outgoing edge (so !% matches)
RUNS="${RUNS:-7}"            # timed runs per query (median reported)
WARMUP="${WARMUP:-2}"        # untimed warm-up runs (fill the cache)
GRAPH="urn:gqlbench"
OUTDIR="${OUTDIR:-$(dirname "$0")/bench_results}"

[ -n "$ISQL" ] || { echo "ERROR: set ISQL to the Virtuoso isql binary" >&2; exit 1; }
mkdir -p "$OUTDIR"

isql_run () { "$ISQL" "$PORT" "$DBA_USER" "$DBA_PASS" "$@" 2>&1; }

# ---------------------------------------------------------------------------
# Load the server-side helpers once: a data generator and a timing routine.
# Timing is done server-side (msec_time around GQL_RUN) so isql round-trips do
# not pollute the measurement.
# ---------------------------------------------------------------------------
load_helpers () {
  isql_run <<'SQL' >/dev/null
-- Generate a benchmark graph: N nodes each with a type + PROPS properties;
-- (100-EMPTY_PCT)% of nodes also get DEGREE outgoing bench:knows edges.
create procedure DB.DBA.BENCH_GEN (in _n integer, in _degree integer,
                                   in _props integer, in _empty_pct integer)
{
  declare i, j, tgt integer;
  declare g, s, base varchar;
  g := 'urn:gqlbench';
  base := 'urn:gqlbench:node/';
  exec (sprintf ('sparql clear graph <%s>', g));
  log_enable (2, 1);   -- row-autocommit bulk mode (fast, non-transactional load)
  for (i := 0; i < _n; i := i + 1)
    {
      s := concat (base, cast (i as varchar));
      DB.DBA.RDF_QUAD_URI (g, s,
        'http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 'urn:gqlbench:Node');
      for (j := 0; j < _props; j := j + 1)
        DB.DBA.RDF_QUAD_URI_L (g, s, concat ('urn:gqlbench:p', cast (j as varchar)), i);
      -- give edges to (100 - empty_pct)% of nodes
      if (mod (i, 100) >= _empty_pct)
        {
          for (j := 0; j < _degree; j := j + 1)
            {
              tgt := mod (i * 2654435761 + j * 40503 + 1, _n);
              DB.DBA.RDF_QUAD_URI (g, s, 'urn:gqlbench:knows',
                concat (base, cast (tgt as varchar)));
            }
        }
      if (mod (i, 50000) = 0) commit work;
    }
  commit work;
  log_enable (1, 1);
  exec ('checkpoint');
  __ddl_changed ('DB.DBA.RDF_QUAD');
}
;

-- Run a GQL query RUNS times (after WARMUP untimed runs) and return
-- "rows=.. min=..ms median=..ms max=..ms". A statement that overruns the
-- query timeout is reported as TIMEOUT rather than hanging the sweep.
create procedure DB.DBA.BENCH_TIME (in _gql varchar, in _runs integer, in _warmup integer)
{
  declare i, t0, nrows integer;
  declare times any;
  declare r any;
  declare exit handler for sqlstate '*'
    { return concat ('ERROR ', __SQL_STATE, ': ', subseq (cast (__SQL_MESSAGE as varchar), 0, 60)); };
  for (i := 0; i < _warmup; i := i + 1)
    r := DB.DBA.GQL_RUN (_gql, 'urn:gqlbench');
  times := vector ();
  nrows := 0;
  for (i := 0; i < _runs; i := i + 1)
    {
      t0 := msec_time ();
      r := DB.DBA.GQL_RUN (_gql, 'urn:gqlbench');
      times := vector_concat (times, vector (msec_time () - t0));
      if (isarray (r)) nrows := length (r);
    }
  -- insertion sort for the median
  declare a, b integer;
  for (a := 1; a < length (times); a := a + 1)
    {
      declare v integer; v := aref (times, a); b := a - 1;
      while (b >= 0 and aref (times, b) > v) { aset (times, b + 1, aref (times, b)); b := b - 1; }
      aset (times, b + 1, v);
    }
  return sprintf ('rows=%d  min=%dms  median=%dms  max=%dms',
    nrows, aref (times, 0), aref (times, length (times) / 2), aref (times, length (times) - 1));
}
;
SQL
}

# Print the translated SPARQL for a GQL query (one call, no timing).
show_sparql () {
  isql_run "EXEC=select DB.DBA.GQL_TO_SPARQL('$1', 'urn:gqlbench');" \
    | sed -n '/SPARQL/,/^$/p' | sed 's/^/      /'
}

# Dump the SQL execution plan for a GQL query's generated SPARQL to a file.
dump_plan () { # $1 gql  $2 outfile
  isql_run "EXEC=string_to_file('$2', explain(DB.DBA.GQL_TO_SPARQL('$1','urn:gqlbench')), -2);" >/dev/null
}

# The three queries (count form: measures the anti-join, not row transport).
Q_NEGWILD="PREFIX bench: <urn:gqlbench:> MATCH (a:bench:Node)-[:!%]->(b) RETURN count(a) AS c"
Q_NEGIRI="PREFIX bench: <urn:gqlbench:> MATCH (a:bench:Node)-[:!bench:knows]->(b) RETURN count(a) AS c"
Q_BASE="PREFIX bench: <urn:gqlbench:> MATCH (a:bench:Node)-[:bench:knows]->(b) RETURN count(a) AS c"

echo "=== GQL !% wildcard-negation benchmark ==="
echo "isql=$ISQL port=$PORT  degree=$DEGREE props=$PROPS empty_pct=$EMPTY_PCT  runs=$RUNS warmup=$WARMUP"
echo "sizes (nodes): $SIZES     out: $OUTDIR"
echo

echo "--- loading server-side helpers ---"
load_helpers

for N in $SIZES; do
  echo "======================================================================"
  echo "SIZE: $N nodes  (~$(( N * (1 + PROPS + DEGREE) )) triples expected)"
  echo "----------------------------------------------------------------------"
  echo "generating data..."
  isql_run "EXEC=DB.DBA.BENCH_GEN($N, $DEGREE, $PROPS, $EMPTY_PCT);" >/dev/null
  TRIPLES=$(isql_run "EXEC=select count(*) from (sparql select ?s from <$GRAPH> where {?s ?p ?o}) x;" \
    | grep -aoE '^[0-9]+' | head -1)
  echo "actual triples: ${TRIPLES:-?}"
  echo

  for pair in "NEGWILD|$Q_NEGWILD" "NEGIRI|$Q_NEGIRI" "BASE|$Q_BASE"; do
    name="${pair%%|*}"; gql="${pair#*|}"
    echo "  [$name] $gql"
    echo "    generated SPARQL:"
    show_sparql "$gql"
    dump_plan "$gql" "$OUTDIR/plan_${N}_${name}.txt"
    echo -n "    timing: "
    isql_run "EXEC=select DB.DBA.BENCH_TIME('$gql', $RUNS, $WARMUP);" \
      | grep -aoE 'rows=.*ms|ERROR .*|TIMEOUT.*' | head -1
    echo
  done
done

echo "======================================================================"
echo "Interpretation:"
echo "  * Compare how NEGWILD's median grows vs NEGIRI/BASE across sizes."
echo "    Linear-ish growth in all three -> !% is fine as-is (document + close)."
echo "    NEGWILD bending superlinearly (esp. a plan change) -> optimize the"
echo "    !% lowering. The explain() plans are in $OUTDIR/plan_<size>_<query>.txt."
echo "  * Below ~100K nodes numbers are near the compile-overhead noise floor."
echo
echo "Cleanup:  isql $PORT $DBA_USER $DBA_PASS \"EXEC=sparql clear graph <$GRAPH>;\""
