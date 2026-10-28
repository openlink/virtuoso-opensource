--
--  $Id: cube.sql,v 1.5.10.5 2013/01/04 10:55:09 oerling Exp $
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
--


select sys_stat ('cluster_enable');
#if $equ $last[1] 0


CREATE PROCEDURE drop_table(in tb varchar)
{
   if(
     exists(
       select KEY_TABLE from DB.DBA.SYS_KEYS
       where KEY_TABLE=tb ) )
     {
       exec(concat ('drop table ', tb));
     }
}

drop_table ('DB.DBA.ROLLUP1');

-- make partition
--__dbf_set ('qp_thread_min_usec', 0);
create table ROLLUP1 (i integer, j integer, k integer, t integer, s integer, primary key (i,j,k,t,s));
alter index ROLLUP1 on ROLLUP1 partition (i int);

create procedure fill_ROLLUP (in c integer:=1000)
{
	while (c > 0)
	{
		c:=c-1;
		insert into ROLLUP1 values
		( mod (c,10), mod (c,5), mod (c,4), mod (c,3), mod (c,2) );
		    commit work;
	}
}

fill_ROLLUP (100);

select * from ROLLUP1;

select j, grouping (j), k, grouping (k), t, grouping (t), sum (i) from ROLLUP1 group by rollup (j,k,t) ;
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
ECHO BOTH ": GROUPING (j) = " $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[4] 1 "PASSED" "***FAILED";
ECHO BOTH ": GROUPING (k) = " $LAST[4] "\n";
ECHO BOTH $IF $EQU $LAST[6] 1 "PASSED" "***FAILED";
ECHO BOTH ": GROUPING (t) = " $LAST[6] "\n";
ECHO BOTH $IF $EQU $ROWCNT 86 "PASSED" "***FAILED";
eCHO BOTH ": TOTAL ROWS = " $ROWCNT "\n";

select j, 0, k, 0, t, 0, sum (i) from ROLLUP1 group by j,k,t;

select j, 0, k, 0, NULL, 1, sum (i) from ROLLUP1 group by j,k;

select j, 0, NULL, 1, NULL, 1, sum (i) from ROLLUP1 group by j;

select NULL, 1, NULL, 1, NULL, 1, sum (i) from ROLLUP1;

select j, grouping (j), k, grouping (k), t, grouping (t), sum (i) from ROLLUP1 group by cube (j,k,t);
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
ECHO BOTH ": GROUPING (j) = " $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[4] 1 "PASSED" "***FAILED";
ECHO BOTH ": GROUPING (k) = " $LAST[4] "\n";
ECHO BOTH $IF $EQU $LAST[6] 1 "PASSED" "***FAILED";
ECHO BOTH ": GROUPING (t) = " $LAST[6] "\n";
ECHO BOTH $IF $EQU $ROWCNT 120 "PASSED" "***FAILED";
ECHO BOTH ": TOTAL ROWS = " $ROWCNT "\n";

create procedure test_rollup ()
{
	declare JJ, GJJ, KK, KJJ, TT, GTT, SS integer;
	declare res varchar;
	result_names ( res, JJ, GJJ, KK, KJJ, TT, GTT, SS );
	for select j, grouping (j) as gj integer, k, grouping (k) as gk integer, t, grouping (t) as gt integer, sum (i) as s from ROLLUP1 group by rollup (j,k,t) do
	{
		res := 'PASSED:';
		if ((gj=1) and j is not null)
			res := '***FAILED: GJJ';
		if ((gk=1) and k is not null)
			res := '***FAILED: GKK';
		if ((gt=1) and (t is not null))
			res := '***FAILED: GTT';

		result (res, j, gj, k, gk, t, gt, s);
	}
}
;

select 'test_rollup...';

test_rollup ();
ECHO BOTH $IF $EQU $LAST[3] 1 "PASSED" "***FAILED";
ECHO BOTH ": GROUPING (j) = " $LAST[3] "\n";
ECHO BOTH $IF $EQU $LAST[5] 1 "PASSED" "***FAILED";
ECHO BOTH ": GROUPING (k) = " $LAST[5] "\n";
ECHO BOTH $IF $EQU $LAST[7] 1 "PASSED" "***FAILED";
ECHO BOTH ": GROUPING (t) = " $LAST[7] "\n";
ECHO BOTH $IF $EQU $ROWCNT 86 "PASSED" "***FAILED";
ECHO BOTH ": TOTAL ROWS = " $ROWCNT "\n";

create procedure test_cube ()
{
	declare JJ, GJJ, KK, KJJ, TT, GTT, SS integer;
	declare res varchar;
	result_names ( res, JJ, GJJ, KK, KJJ, TT, GTT, SS );
	for select j, grouping (j) as gj integer, k, grouping (k) as gk integer, t, grouping (t) as gt integer, sum (i) as s from ROLLUP1 group by cube (j,k,t) do
	{
		res := 'PASSED:';
		if ((gj=1) and j is not null)
			res := '***FAILED: GJJ';
		if ((gk=1) and k is not null)
			res := '***FAILED: GKK';
		if ((gt=1) and (t is not null))
			res := '***FAILED: GTT';

		result (res, j, gj, k, gk, t, gt, s);
	}
}
;

select 'test_rollup...';

test_rollup ();
ECHO BOTH $IF $EQU $LAST[3] 1 "PASSED" "***FAILED";
ECHO BOTH ": GROUPING (j) = " $LAST[3] "\n";
ECHO BOTH $IF $EQU $LAST[5] 1 "PASSED" "***FAILED";
ECHO BOTH ": GROUPING (k) = " $LAST[5] "\n";
ECHO BOTH $IF $EQU $LAST[7] 1 "PASSED" "***FAILED";
ECHO BOTH ": GROUPING (t) = " $LAST[7] "\n";
ECHO BOTH $IF $EQU $ROWCNT 86 "PASSED" "***FAILED";
ECHO BOTH ": TOTAL ROWS = " $ROWCNT "\n";

--bug #8788
drop table B8788;

create table B8788 (ID int primary key, J int);
insert into B8788 values (1,1);
insert into B8788 values (2,2);
insert into B8788 values (3,2);

select distinct GJ
	from (
		select
			count(ID) as CID,
			grouping(J) as GJ,
			J from
			B8788 group by rollup (J) order by J
	     ) MM;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": B8788 the grouping bug : wrong placement of the grouping () call_exp dfe.\n";

-- ROLLUP (K, V) means GROUPING SETS ((K, V), (K), ()): the subtotals are by
-- K, the first key.  It used to give the subtotals of ROLLUP (V, K).
create table ROLLUP_ORDER (K varchar, V varchar, N integer);
insert into ROLLUP_ORDER values ('a', 'x', 1);
insert into ROLLUP_ORDER values ('a', 'y', 2);
insert into ROLLUP_ORDER values ('b', 'x', 3);
-- The rows of q as (k v total), NULL as -, sorted, so the row order of the
-- query does not matter.
create procedure ROLLUP_ORDER_ROWS (in q varchar) returns varchar
{
  declare st, msg, meta, rows, strs any;
  declare res varchar;
  declare inx integer;
  st := '00000';
  exec (q, st, msg, vector (), 0, meta, rows);
  if (st <> '00000')
    return concat ('error ', st, ' ', msg);
  strs := make_array (length (rows), 'any');
  for (inx := 0; inx < length (rows); inx := inx + 1)
    strs[inx] := concat ('(', coalesce (rows[inx][0], '-'), ' ', coalesce (rows[inx][1], '-'), ' ', cast (rows[inx][2] as varchar), ')');
  strs := __vector_sort (strs);
  res := '';
  for (inx := 0; inx < length (strs); inx := inx + 1)
    res := concat (res, strs[inx]);
  return res;
}
;
select ROLLUP_ORDER_ROWS ('select K, V, sum (N) from ROLLUP_ORDER group by rollup (K, V)');
ECHO BOTH $IF $EQU $LAST[1] "(- - 6)(a - 3)(a x 1)(a y 2)(b - 3)(b x 3)" "PASSED" "***FAILED";
ECHO BOTH ": ROLLUP (K, V) = " $LAST[1] "\n";
select ROLLUP_ORDER_ROWS ('select V, K, sum (N) from ROLLUP_ORDER group by rollup (V, K)');
ECHO BOTH $IF $EQU $LAST[1] "(- - 6)(x - 4)(x a 1)(x b 3)(y - 2)(y a 2)" "PASSED" "***FAILED";
ECHO BOTH ": ROLLUP (V, K) = " $LAST[1] "\n";
select ROLLUP_ORDER_ROWS ('select K, V, sum (N) from ROLLUP_ORDER group by grouping sets ((K, V), (K), ())');
ECHO BOTH $IF $EQU $LAST[1] "(- - 6)(a - 3)(a x 1)(a y 2)(b - 3)(b x 3)" "PASSED" "***FAILED";
ECHO BOTH ": GROUPING SETS ((K, V), (K), ()) = " $LAST[1] "\n";
SPARQL INSERT DATA { GRAPH <urn:test:rollup> {
  <urn:test:r1> <urn:test:k> "a" ; <urn:test:v> "x" ; <urn:test:n> 1 .
  <urn:test:r2> <urn:test:k> "a" ; <urn:test:v> "y" ; <urn:test:n> 2 .
  <urn:test:r3> <urn:test:k> "b" ; <urn:test:v> "x" ; <urn:test:n> 3 . } };
select ROLLUP_ORDER_ROWS ('SPARQL SELECT ?k ?v (SUM (?n) AS ?total) FROM <urn:test:rollup> WHERE { ?r <urn:test:k> ?k ; <urn:test:v> ?v ; <urn:test:n> ?n } GROUP BY ROLLUP (?k, ?v)');
ECHO BOTH $IF $EQU $LAST[1] "(- - 6)(a - 3)(a x 1)(a y 2)(b - 3)(b x 3)" "PASSED" "***FAILED";
ECHO BOTH ": SPARQL ROLLUP (?k, ?v) = " $LAST[1] "\n";
SPARQL CLEAR GRAPH <urn:test:rollup>;
drop procedure ROLLUP_ORDER_ROWS;
drop table ROLLUP_ORDER;


-- GROUPING SETS
CREATE TABLE Sales (EmpId INT, Yr INT, Sales NUMERIC);
INSERT into Sales VALUES(1, 2005, 12000);
INSERT into Sales VALUES(1, 2006, 18000);
INSERT into Sales VALUES(1, 2007, 25000);
INSERT into Sales VALUES(2, 2005, 15000);
INSERT into Sales VALUES(2, 2006, 6000);
INSERT into Sales VALUES(3, 2006, 20000);
INSERT into Sales VALUES(3, 2007, 24000);

SELECT (EmpId) as ee, (Yr) as yy, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((ee), (yy));
SELECT (EmpId) as ee, (Yr) as yy, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((ee), order by (yy));
SELECT (EmpId) as ee, f(Yr) as yy, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((ee), order by (yy));
SELECT (EmpId) as ee, f(Yr) as yy, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((ee), (yy));
SELECT (EmpId) as ee, f(Yr) as yy, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((ee), order by (yy), order by (ee));
SELECT EmpId, Yr, AVG(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((EmpId), (Yr));
SELECT EmpId, Yr, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS(());
SELECT EmpId, Yr, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((), (Yr), (EmpId), (Yr, EmpId));
SELECT EmpId, Yr, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((EmpId));
SELECT EmpId, Yr, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((EmpId), (Yr));
SELECT EmpId, Yr, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((EmpId), (Yr), ());
SELECT EmpId, Yr, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((EmpId), (Yr desc));
SELECT EmpId, Yr, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((EmpId), ORDER BY TOP 5 (Yr));
SELECT EmpId, Yr, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((EmpId), order by (Yr));
SELECT EmpId, Yr, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((EmpId), order by (Yr), ());
SELECT EmpId, Yr, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((EmpId), order by (Yr, EmpId));
SELECT EmpId, Yr, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((EmpId), order by (Yr, EmpId), ());
SELECT EmpId, Yr, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((EmpId), order by (Yr desc));
SELECT EmpId, Yr, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((EmpId, Yr), ());

-- SPARQL GROUPING SETS with the empty grouping set (): the SQL text
-- generator read the first argument of the empty grouping list, which has
-- none, and the query could not be run.
SPARQL INSERT DATA { GRAPH <urn:test:gsets> { <urn:test:e1> <urn:test:sales> 10 . <urn:test:e1> <urn:test:sales> 20 . <urn:test:e2> <urn:test:sales> 5 . } };
SPARQL SELECT ?s (SUM (?v) AS ?total) FROM <urn:test:gsets> WHERE { ?s <urn:test:sales> ?v } GROUP BY GROUPING SETS ((?s), ());
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL GROUPING SETS ((?s), ()) returned " $ROWCNT " rows\n";
SPARQL SELECT (SUM (?v) AS ?total) FROM <urn:test:gsets> WHERE { ?s <urn:test:sales> ?v } GROUP BY GROUPING SETS (());
ECHO BOTH $IF $EQU $LAST[1] 35 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL GROUPING SETS (()) total = " $LAST[1] "\n";
SPARQL SELECT (STRLEN (STRUUID ()) AS ?len) WHERE { };
ECHO BOTH $IF $EQU $LAST[1] 36 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL zero-argument built-in STRUUID () = " $LAST[1] " characters\n";
SPARQL CLEAR GRAPH <urn:test:gsets>;
SELECT EmpId, Yr, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((EmpId, Yr), (EmpId));
SELECT f(EmpId) as ee, f2(Yr) as yy, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((ee), order by top 2,1 (yy));
SELECT f(EmpId) as ee, f2(Yr) as yy, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((ee), order by top 3 (yy));
SELECT f(EmpId) as ee, f2(Yr) as yy, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((ee), order by top 5,1 (yy));
SELECT f(EmpId) as ee, f2(Yr) as yy, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((ee), order by top 5 (yy), order by (ee));
SELECT f(EmpId) as ee, f2(Yr+0) as yy, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((ee), order by (yy));
SELECT f(EmpId) as ee, f2(Yr+1) as yy, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((ee), order by (ee));
SELECT f(EmpId) as ee, f2(Yr+1) as yy, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((ee), order by (yy));
SELECT f(EmpId) as ee, f (Yr) as yy, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((ee), (yy));
SELECT f(EmpId) as ee, f (Yr) as yy, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((ee), order by (yy));
SELECT f(EmpId) as ee, f (Yr) as yy, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((ee), order by (yy), order by (ee));
SELECT f2(EmpId) as ee, (Yr) as yy, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((ee), order by (yy));
SELECT f (EmpId), Yr, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((EmpId, Yr), (Yr), ());
SELECT f (EmpId) as ee, f (Yr) as yy, SUM(Sales) AS Sales FROM Sales GROUP BY GROUPING SETS((ee), order by (yy));

#endif
