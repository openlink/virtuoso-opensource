-- Verify residual filters and cache separation for column-store sampling.
SET ARGV[0] 0;
SET ARGV[1] 0;
DROP TABLE T_SAMPLE_CACHE_REGRESSION;
CREATE TABLE T_SAMPLE_CACHE_REGRESSION
  (P INTEGER NOT NULL, S INTEGER NOT NULL, O INTEGER NOT NULL, G INTEGER NOT NULL,
   PRIMARY KEY (P, S, O, G)) COLUMN;

-- Populate deterministic data with selective filters and broad index scans.
CREATE PROCEDURE SAMPLE_CACHE_REGRESSION_FILL ()
{
  DECLARE i INTEGER;
  i := 0;
  WHILE (i < 20000)
    {
      INSERT INTO T_SAMPLE_CACHE_REGRESSION VALUES (mod (i, 2), i, i, 0);
      i := i + 1;
    }
};
SAMPLE_CACHE_REGRESSION_FILL ();

-- Populate a residual-filter sample before checking an equivalent point lookup.
CREATE PROCEDURE SAMPLE_CACHE_REGRESSION_CHECK ()
{
  DECLARE clean_point, in_score, filtered_point, scan_score, rare_col, common_col DOUBLE PRECISION;
  clean_point := exec_score ('select O from T_SAMPLE_CACHE_REGRESSION where P = 1 and S = 101');
  in_score := exec_score ('select O from T_SAMPLE_CACHE_REGRESSION where P in (0, 1) and S = 103');
  filtered_point := exec_score ('select O from T_SAMPLE_CACHE_REGRESSION where P = 1 and S = 103');
  scan_score := exec_score ('select O from T_SAMPLE_CACHE_REGRESSION where P in (0, 1)');
  rare_col := exec_score ('select S, max (O) from T_SAMPLE_CACHE_REGRESSION where P = 0 and O = 0 group by S');
  common_col := exec_score ('select S, max (O) from T_SAMPLE_CACHE_REGRESSION where P = 0 and G = 0 group by S');
  result_names (clean_point, in_score, filtered_point, scan_score, rare_col, common_col);
  result (clean_point, in_score, filtered_point, scan_score, rare_col, common_col);
};
SAMPLE_CACHE_REGRESSION_CHECK ();
ECHO BOTH $IF $LT $LAST[3] $LAST[4] "PASSED" "***FAILED";
ECHO BOTH ": point lookup is cheaper than full index scan\n";
ECHO BOTH $IF $LT $LAST[2] $LAST[4] "PASSED" "***FAILED";
ECHO BOTH ": IN lookup retains the remaining filter selectivity\n";
ECHO BOTH $IF $LT $LAST[5] $LAST[6] "PASSED" "***FAILED";
ECHO BOTH ": different filter columns have different cardinalities\n";

-- Sampling changes must preserve query results.
SELECT count (*) FROM T_SAMPLE_CACHE_REGRESSION WHERE P IN (0, 1) AND S = 103;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": IN lookup returns exactly one row\n";
SELECT count (*) FROM T_SAMPLE_CACHE_REGRESSION WHERE P = 0 AND G = 0;
ECHO BOTH $IF $EQU $LAST[1] 10000 "PASSED" "***FAILED";
ECHO BOTH ": common filter returns every matching row\n";

DROP PROCEDURE SAMPLE_CACHE_REGRESSION_CHECK;
DROP PROCEDURE SAMPLE_CACHE_REGRESSION_FILL;
DROP TABLE T_SAMPLE_CACHE_REGRESSION;
