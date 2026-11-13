--
--  tsparql_dt_long.sql
--
--  A literal longer than 20 characters is stored in RDF_QUAD as a box that
--  holds only its RDF_OBJ id and a prefix; __ro2sq fetches the rest.  A sort
--  or group key keeps such a value by its id, or id and prefix, so a selected
--  key must be completed after the sort or group, as SQL over a SPARQL derived
--  table does: the report showed GROUP BY labelling such groups 0 and ORDER BY
--  cutting the names to 20 characters.
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

ECHO BOTH "STARTED: long literals out of SPARQL, sorted and grouped in SQL\n";

sparql clear graph <urn:tdl:g>;
DB.DBA.TTLP ('
@prefix ex: <urn:tdl:> .
ex:m1 ex:id "1001-00001" ; ex:client ex:c1 .
ex:m2 ex:id "1001-00002" ; ex:client ex:c1 .
ex:m3 ex:id "1002-00001" ; ex:client ex:c2 .
ex:m4 ex:id "1003-00001" ; ex:client ex:c3 .
ex:c1 ex:name "Harrowgate Industries" .
ex:c2 ex:name "Ardent Capital Partners" .
ex:c3 ex:name "Pinnacle Ventures" .
ex:z ex:label "Harrowgate Industries Zeta" .
ex:a ex:label "Harrowgate Industries Alpha" .
', '', 'urn:tdl:g');

create table TDL_HOURS (ID integer primary key, MATTER_ID varchar, HOURS decimal);
insert into TDL_HOURS values (1, '1001-00001', 10);
insert into TDL_HOURS values (2, '1001-00001', 12);
insert into TDL_HOURS values (3, '1001-00002', 7);
insert into TDL_HOURS values (4, '1002-00001', 15.5);
insert into TDL_HOURS values (5, '1003-00001', 3);

--  SQL over a SPARQL derived table joined to a table.  The selected key is
--  completed after the group or sort, not carried through it.
--
--  The query of the report: SQL GROUP BY over a SPARQL derived table.
select g."client", sum (t.HOURS) from (sparql prefix ex: <urn:tdl:> select ?id ?client from <urn:tdl:g>
  where { ?m ex:id ?id ; ex:client/ex:name ?client }) as g, TDL_HOURS t
  where t.MATTER_ID = g."id" group by g."client" order by 2 desc option (loop);
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
ECHO BOTH ": GROUP BY over the derived table gives " $ROWCNT " groups\n";
ECHO BOTH $IF $EQU $LAST[1] "Pinnacle Ventures" "PASSED" "***FAILED";
ECHO BOTH ": guard, the smallest group (a short name) is " $LAST[1] "\n";

select top 1 g."client" from (sparql prefix ex: <urn:tdl:> select ?id ?client from <urn:tdl:g>
  where { ?m ex:id ?id ; ex:client/ex:name ?client }) as g, TDL_HOURS t
  where t.MATTER_ID = g."id" group by g."client" order by sum (t.HOURS) desc option (loop);
ECHO BOTH $IF $EQU $LAST[1] "Harrowgate Industries" "PASSED" "***FAILED";
ECHO BOTH ": the largest group is labelled " $LAST[1] "\n";

--  GROUP BY without ORDER BY: only the group carries the key.
select count (*) from (select g."client" as c, sum (t.HOURS) as h from (sparql prefix ex: <urn:tdl:> select ?id ?client from <urn:tdl:g>
  where { ?m ex:id ?id ; ex:client/ex:name ?client }) as g, TDL_HOURS t
  where t.MATTER_ID = g."id" group by g."client" option (loop)) x
  where c in ('Harrowgate Industries', 'Ardent Capital Partners', 'Pinnacle Ventures');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": GROUP BY without ORDER BY labels " $LAST[1] " of 3 groups whole\n";

--  The optimizer's own join order and join type.
select g."client", sum (t.HOURS) from (sparql prefix ex: <urn:tdl:> select ?id ?client from <urn:tdl:g>
  where { ?m ex:id ?id ; ex:client/ex:name ?client }) as g, TDL_HOURS t
  where t.MATTER_ID = g."id" group by g."client" order by 2;
ECHO BOTH $IF $EQU $LAST[1] "Harrowgate Industries" "PASSED" "***FAILED";
ECHO BOTH ": without option (loop), the largest group is labelled " $LAST[1] "\n";

--  The same join without GROUP BY, sorted on the name both ways.
select g."client" from (sparql prefix ex: <urn:tdl:> select ?id ?client from <urn:tdl:g>
  where { ?m ex:id ?id ; ex:client/ex:name ?client }) as g, TDL_HOURS t
  where t.MATTER_ID = g."id" order by 1 desc option (loop);
ECHO BOTH $IF $EQU $LAST[1] "Ardent Capital Partners" "PASSED" "***FAILED";
ECHO BOTH ": ORDER BY on the name descending, last row " $LAST[1] "\n";

select g."client" from (sparql prefix ex: <urn:tdl:> select ?id ?client from <urn:tdl:g>
  where { ?m ex:id ?id ; ex:client/ex:name ?client }) as g, TDL_HOURS t
  where t.MATTER_ID = g."id" order by 1 option (loop);
ECHO BOTH $IF $EQU $LAST[1] "Pinnacle Ventures" "PASSED" "***FAILED";
ECHO BOTH ": ORDER BY on the name ascending, last row " $LAST[1] "\n";
select count (*) from (select g."client" as c from (sparql prefix ex: <urn:tdl:> select ?id ?client from <urn:tdl:g>
  where { ?m ex:id ?id ; ex:client/ex:name ?client }) as g, TDL_HOURS t
  where t.MATTER_ID = g."id" order by 1 option (loop)) x where c = 'Harrowgate Industries';
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": ORDER BY on the name keeps " $LAST[1] " of 3 long rows whole\n";

--  Plain SQL on the quad store, no SPARQL.
select __ro2sq (O) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tdl:g') and P = iri_to_id ('urn:tdl:name') order by 1 desc;
ECHO BOTH $IF $EQU $LAST[1] "Ardent Capital Partners" "PASSED" "***FAILED";
ECHO BOTH ": ORDER BY __ro2sq (O) desc, last row " $LAST[1] "\n";

--  Two strings with one short-key prefix: the sort must order them by their
--  whole text, not by the prefix and id, and return them whole.
select x from (select __ro2sq (O) as x from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tdl:g') and P = iri_to_id ('urn:tdl:label')) d order by x;
ECHO BOTH $IF $EQU $LAST[1] "Harrowgate Industries Zeta" "PASSED" "***FAILED";
ECHO BOTH ": ascending, the last of two strings with one prefix is " $LAST[1] "\n";

select x from (select __ro2sq (O) as x from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tdl:g') and P = iri_to_id ('urn:tdl:label')) d order by x desc;
ECHO BOTH $IF $EQU $LAST[1] "Harrowgate Industries Alpha" "PASSED" "***FAILED";
ECHO BOTH ": descending, the last of two strings with one prefix is " $LAST[1] "\n";

select count (*) from (select top 10 x from (select __ro2sq (O) as x from DB.DBA.RDF_QUAD
  where G = iri_to_id ('urn:tdl:g') and P = iri_to_id ('urn:tdl:label')) d order by x) e
  where x in ('Harrowgate Industries Zeta', 'Harrowgate Industries Alpha');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": a derived table with TOP and ORDER BY returns " $LAST[1] " of 2 such strings whole\n";

select count (*) from (select x, count (*) as n from (select __ro2sq (O) as x from DB.DBA.RDF_QUAD
  where G = iri_to_id ('urn:tdl:g') and P = iri_to_id ('urn:tdl:name')) d group by x) e
  where x in ('Harrowgate Industries', 'Ardent Capital Partners');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": GROUP BY __ro2sq (O) keeps " $LAST[1] " long names whole\n";

--  A literal of several KB: the sort row carries it by its RDF_OBJ id, as a
--  key or not, so the row stays within the row length limit.
DB.DBA.TTLP (concat ('<urn:tdl:d1> <urn:tdl:abstract> "', repeat ('a', 6001), '" .
<urn:tdl:d2> <urn:tdl:abstract> "', repeat ('b', 512), '" .
<urn:tdl:d3> <urn:tdl:abstract> "short" .'), '', 'urn:tdl:g');

sparql select (strlen (?a) as ?n) where { graph <urn:tdl:g> { ?d <urn:tdl:abstract> ?a } } order by desc (strlen (?a));
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL sorted on strlen () of a 6001-character literal: " $ROWCNT " rows\n";

sparql select ?a where { graph <urn:tdl:g> { ?d <urn:tdl:abstract> ?a } } order by desc (strlen (?a));
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
ECHO BOTH ": the literals themselves, sorted on their length: " $ROWCNT " rows\n";

select x from (select __ro2sq (O) as x from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tdl:g')
  and P = iri_to_id ('urn:tdl:abstract') order by length (__ro2sq (O))) d;
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
ECHO BOTH ": SQL, __ro2sq (O) of a 6001-character literal carried through a sort: " $ROWCNT " rows\n";

select length (x) from (select __ro2sq (O) as x from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tdl:g')
  and P = iri_to_id ('urn:tdl:abstract')) d order by length (x) desc;
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
ECHO BOTH ": SQL sorted on the length of __ro2sq (O), last " $LAST[1] "\n";

--  Sorted and grouped on the literal itself, whatever its length.
select length (y) from (select top 10 x as y from (select __ro2sq (O) as x from DB.DBA.RDF_QUAD
  where G = iri_to_id ('urn:tdl:g') and P = iri_to_id ('urn:tdl:abstract')) d order by x desc) e;
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
ECHO BOTH ": ORDER BY the literals themselves: " $ROWCNT " rows\n";
ECHO BOTH $IF $EQU $LAST[1] 6001 "PASSED" "***FAILED";
ECHO BOTH ": ORDER BY a 6001-character literal returns it whole: " $LAST[1] " characters\n";

select count (*) from (select x, count (*) as n from (select __ro2sq (O) as x from DB.DBA.RDF_QUAD
  where G = iri_to_id ('urn:tdl:g') and P = iri_to_id ('urn:tdl:abstract')) d group by x) e where length (x) in (6001, 512);
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": GROUP BY keeps a 6001- and a 512-character literal whole: " $LAST[1] " groups\n";

--  A selected key without an alias keeps its column name.
create procedure TDL_COL_NAME ()
{
  declare meta, rows any;
  exec ('select d.x from (select top 10 __ro2sq (O) as x from DB.DBA.RDF_QUAD where G = iri_to_id (''urn:tdl:g'')
    and P = iri_to_id (''urn:tdl:label'')) d order by d.x', null, null, vector (), 0, meta, rows);
  return meta[0][0][0];
}
;
select upper (TDL_COL_NAME ());
ECHO BOTH $IF $EQU $LAST[1] "X" "PASSED" "***FAILED";
ECHO BOTH ": the selected key d.x is still named " $LAST[1] "\n";
drop procedure TDL_COL_NAME;

--  Guards: values that are not sorted or grouped, and the cast workaround.
select length (g."client") from (sparql prefix ex: <urn:tdl:> select ?client from <urn:tdl:g>
  where { ex:c2 ex:name ?client }) as g;
ECHO BOTH $IF $EQU $LAST[1] 23 "PASSED" "***FAILED";
ECHO BOTH ": guard, a long name read without sorting has " $LAST[1] " characters\n";

select top 1 cast (g."client" as varchar) from (sparql prefix ex: <urn:tdl:> select ?id ?client from <urn:tdl:g>
  where { ?m ex:id ?id ; ex:client/ex:name ?client }) as g, TDL_HOURS t
  where t.MATTER_ID = g."id" group by cast (g."client" as varchar) order by sum (t.HOURS) desc option (loop);
ECHO BOTH $IF $EQU $LAST[1] "Harrowgate Industries" "PASSED" "***FAILED";
ECHO BOTH ": guard, grouping on the cast to varchar gives " $LAST[1] "\n";

drop table TDL_HOURS;
sparql clear graph <urn:tdl:g>;

ECHO BOTH "COMPLETED: long literals out of SPARQL, sorted and grouped in SQL\n";
