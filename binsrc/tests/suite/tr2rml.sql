--
--  tr2rml.sql
--
--  R2RML mappings turned into RDF views by DB.DBA.R2RML_MAKE_QM_FROM_G ().
--  Run by tr2rml.sh after it loads the rdb2rdf SQL files.
--
--  1. An object map with rr:template and no rr:termType.  R2RML 7.4: a term
--     map without rr:termType is an rr:Literal if it is an object map that is
--     column-valued or has rr:language or rr:datatype, and an rr:IRI
--     otherwise -- so a template object map is an IRI.  The generator's
--     IRI-class pass declared the class with term type IRI, the quad map pass
--     defaulted the object map to Literal, and the two names it derives from
--     the term type differed: the script created one class and used another,
--     the view was left half-built (14 of 42 triples) with a 22023 error row.
--  2. The generator must not write a quad map that uses an IRI or literal
--     class its script does not create.
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

ECHO BOTH "STARTED: R2RML (tr2rml.sql)\n";

create table COURSE.L6.TIMESHEET (ENTRY_ID integer primary key, MATTER_ID varchar, PERSON varchar, WORK_DATE date, HOURS decimal, ACTIVITY varchar);
insert into COURSE.L6.TIMESHEET values (1, 'M-1001-00001', 'alice', stringdate ('2026-03-02'), 1.5, 'drafting');
insert into COURSE.L6.TIMESHEET values (2, 'M-1001-00001', 'bob', stringdate ('2026-03-02'), 2, 'review');
insert into COURSE.L6.TIMESHEET values (3, 'M-1001-00002', 'alice', stringdate ('2026-03-03'), 0.75, 'call');
insert into COURSE.L6.TIMESHEET values (4, 'M-1001-00002', 'carol', stringdate ('2026-03-04'), 3.25, 'research');
insert into COURSE.L6.TIMESHEET values (5, 'M-1001-00003', 'bob', stringdate ('2026-03-05'), 1, 'filing');
insert into COURSE.L6.TIMESHEET values (6, 'M-1001-00003', 'dave', stringdate ('2026-03-06'), 4.5, 'drafting');
insert into COURSE.L6.TIMESHEET values (7, 'M-1001-00004', 'carol', stringdate ('2026-03-09'), 2.5, 'review');

select count (*) from COURSE.L6.TIMESHEET;
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
ECHO BOTH ": the TIMESHEET table has 7 rows\n";

-- The mapping of the finding: the ex:person object map is a template
-- without rr:termType.  <urn:tr2rml:map-iri> is the same with
-- rr:termType rr:IRI, which always worked.
SPARQL CLEAR GRAPH <urn:tr2rml:map>;
SPARQL CLEAR GRAPH <urn:tr2rml:map-iri>;
create procedure TR2RML_LOAD_MAP (in map_graph varchar, in view_graph varchar, in person_term_type varchar)
{
  DB.DBA.TTLP (sprintf ('@prefix rr: <http://www.w3.org/ns/r2rml#> .
@prefix ex: <http://example.org/firm/ns#> .
<%s#TimesheetMap> a rr:TriplesMap ;
  rr:logicalTable [ rr:tableSchema "COURSE" ; rr:tableOwner "L6" ; rr:tableName "TIMESHEET" ] ;
  rr:subjectMap [ rr:template "http://example.org/firm/timesheet/{ENTRY_ID}" ; rr:class ex:TimeEntry ; rr:graph <%s> ] ;
  rr:predicateObjectMap [ rr:predicate ex:matterId ; rr:objectMap [ rr:column "MATTER_ID" ] ] ;
  rr:predicateObjectMap [ rr:predicate ex:person ; rr:objectMap [ rr:template "http://example.org/firm/id/{PERSON}" %s ] ] ;
  rr:predicateObjectMap [ rr:predicate ex:workDate ; rr:objectMap [ rr:column "WORK_DATE" ] ] ;
  rr:predicateObjectMap [ rr:predicate ex:hours ; rr:objectMap [ rr:column "HOURS" ] ] ;
  rr:predicateObjectMap [ rr:predicate ex:activity ; rr:objectMap [ rr:column "ACTIVITY" ] ] .
', map_graph, view_graph, person_term_type), '', map_graph);
}
;
TR2RML_LOAD_MAP ('urn:tr2rml:map', 'urn:tr2rml:view', '');
TR2RML_LOAD_MAP ('urn:tr2rml:map-iri', 'urn:tr2rml:view-iri', '; rr:termType rr:IRI');

-- How many references to an r2rml:virt02- class a generated script makes
-- that the same script does not create.
create function TR2RML_UNDECLARED (in script varchar) returns integer
{
  declare lines, declared any;
  declare l, cls varchar;
  declare inx, n integer;
  declared := dict_new ();
  lines := split_and_decode (script, 0, '\0\0\n');
  for (inx := 0; inx < length (lines); inx := inx + 1)
    {
      l := lines[inx];
      if (l like 'create % class <r2rml:%')
        dict_put (declared, regexp_match ('<r2rml:virt02-[0-9a-f]+>', l), 1);
    }
  n := 0;
  for (inx := 0; inx < length (lines); inx := inx + 1)
    {
      l := lines[inx];
      if (not (l like 'create % class <r2rml:%'))
        {
          while (1)
            {
              cls := regexp_match ('<r2rml:virt02-[0-9a-f]+>', l, 1);
              if (cls is null)
                goto next_line;
              if (dict_get (declared, cls) is null)
                n := n + 1;
            }
        }
next_line: ;
    }
  return n;
}
;

-- Runs the script generated for a mapping graph; returns the number of
-- error rows the quad map DDL answers with (it reports errors as rows and
-- leaves the statement's SQLSTATE at 00000), or the SQLSTATE of a raise.
create function TR2RML_RUN (in map_graph varchar, in qm varchar) returns varchar
{
  declare script, st, msg, mdta, rset any;
  declare inx, errs integer;
  declare exit handler for sqlstate '*' { return __SQL_STATE; };
  script := DB.DBA.R2RML_MAKE_QM_FROM_G (map_graph, null, qm);
  st := '00000';
  exec ('sparql ' || script, st, msg, vector (), 0, mdta, rset);
  if (st <> '00000')
    return st;
  errs := 0;
  if (isarray (rset))
    for (inx := 0; inx < length (rset); inx := inx + 1)
      {
        if (rset[inx][0] <> '00000')
          errs := errs + 1;
      }
  return cast (errs as varchar);
}
;

--------------------------------------------------------------------------
-- 1. rr:template without rr:termType in an object map is an IRI.
--------------------------------------------------------------------------

select TR2RML_UNDECLARED (DB.DBA.R2RML_MAKE_QM_FROM_G ('urn:tr2rml:map-iri', null, 'urn:tr2rml:qm-iri'));
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": with rr:termType rr:IRI the script creates every class it uses (" $LAST[1] " missing)\n";

select TR2RML_UNDECLARED (DB.DBA.R2RML_MAKE_QM_FROM_G ('urn:tr2rml:map', null, 'urn:tr2rml:qm'));
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": without rr:termType the script creates every class it uses (" $LAST[1] " missing)\n";

select TR2RML_RUN ('urn:tr2rml:map-iri', 'urn:tr2rml:qm-iri');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": the view with rr:termType rr:IRI is created without errors, got " $LAST[1] "\n";

SPARQL SELECT COUNT (*) FROM <urn:tr2rml:view-iri> WHERE { ?s ?p ?o };
ECHO BOTH $IF $EQU $LAST[1] 42 "PASSED" "***FAILED";
ECHO BOTH ": the view with rr:termType rr:IRI has 42 triples, got " $LAST[1] "\n";

select TR2RML_RUN ('urn:tr2rml:map', 'urn:tr2rml:qm');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": the view without rr:termType is created without errors, got " $LAST[1] "\n";

SPARQL SELECT COUNT (*) FROM <urn:tr2rml:view> WHERE { ?s ?p ?o };
ECHO BOTH $IF $EQU $LAST[1] 42 "PASSED" "***FAILED";
ECHO BOTH ": the view without rr:termType has 42 triples, got " $LAST[1] "\n";

-- Counted in SQL over the rows the view returns: on a half-built view the
-- SPARQL compiler can turn the pattern into a constant (finding F11), so a
-- SPARQL COUNT or ASK alone is not evidence of a triple.
select count (*) from (sparql select ?s ?o from <urn:tr2rml:view> where { ?s <http://example.org/firm/ns#person> ?o }) x
  where "o" like 'http://example.org/firm/id/%' and 1 = __box_flags ("o");
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
ECHO BOTH ": its 7 ex:person objects are IRIs made from the template, got " $LAST[1] "\n";

select count (*) from (sparql select ?o from <urn:tr2rml:view> where { <http://example.org/firm/timesheet/4> <http://example.org/firm/ns#person> ?o }) x
  where "o" = 'http://example.org/firm/id/carol';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": timesheet 4 is by <http://example.org/firm/id/carol>, got " $LAST[1] "\n";

--------------------------------------------------------------------------
-- 2. The generator refuses to use a class its script has not created.
--    Called directly: a field written before the class pass ran.
--------------------------------------------------------------------------

create function TR2RML_REF_WITHOUT_CLASS () returns varchar
{
  declare m DB.DBA.R2RML_MAP;
  declare tmap IRI_ID;
  declare exit handler for sqlstate '*' { return __SQL_STATE; };
  m := DB.DBA.R2RML_MAP (iri_to_id ('urn:tr2rml:map'));
  m.codegen_ses := string_output ();
  m.declared_jsos := dict_new ();
  m.declared_tmap_aliases := dict_new ();
  m.used_fld_tmap_aliases := vector (vector (), vector (), vector (), vector (), vector ());
  tmap := iri_to_id ('urn:tr2rml:map#TimesheetMap');
  dict_put (m.declared_tmap_aliases, tmap, 'tbl0');
  m.R2RML_FILL_TRIPLESMAP_METAS_CACHE ();
  m.R2RML_GEN_FLD (3, null, tmap, null, 'http://example.org/firm/id/{PERSON}', 'http://www.w3.org/ns/r2rml#IRI', null, null);
  return 'written: ' || string_output_string (m.codegen_ses);
}
;

select TR2RML_REF_WITHOUT_CLASS ();
ECHO BOTH $IF $EQU $LAST[1] "R2RML" "PASSED" "***FAILED";
ECHO BOTH ": a quad map field whose class the script does not create is an R2RML error, got " $LAST[1] "\n";

--------------------------------------------------------------------------
-- 3. rr:datatype on a column, naming the column's natural datatype.
--    R2RML 11: the literal has the natural lexical form of the value and
--    the given datatype; for xsd:date on a DATE column that is the natural
--    literal.  The generator wrote a literal class ("%D", "%d") with
--    option (datatype ...), and a literal class keeps that option only for
--    the compiler's static typing: the view wrote plain strings.
--------------------------------------------------------------------------

create table COURSE.L6.WORKDAY (DAY_ID integer primary key, WORK_DATE date, HOURS integer);
insert into COURSE.L6.WORKDAY values (1, cast ('2026-01-12' as date), 7);
insert into COURSE.L6.WORKDAY values (2, cast ('2026-01-13' as date), 8);

SPARQL CLEAR GRAPH <urn:tr2rml:map-dt>;
DB.DBA.TTLP ('@prefix rr: <http://www.w3.org/ns/r2rml#> .
@prefix ex: <http://example.org/firm/ns#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
<urn:tr2rml:map-dt#WorkdayMap> a rr:TriplesMap ;
  rr:logicalTable [ rr:tableSchema "COURSE" ; rr:tableOwner "L6" ; rr:tableName "WORKDAY" ] ;
  rr:subjectMap [ rr:template "http://example.org/firm/workday/{DAY_ID}" ; rr:graph <urn:tr2rml:view-dt> ] ;
  rr:predicateObjectMap [ rr:predicate ex:workDate ; rr:objectMap [ rr:column "WORK_DATE" ; rr:datatype xsd:date ] ] ;
  rr:predicateObjectMap [ rr:predicate ex:hours ; rr:objectMap [ rr:column "HOURS" ; rr:datatype xsd:integer ] ] .
', '', 'urn:tr2rml:map-dt');

select TR2RML_UNDECLARED (DB.DBA.R2RML_MAKE_QM_FROM_G ('urn:tr2rml:map-dt', null, 'urn:tr2rml:qm-dt'));
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": with rr:datatype on columns the script creates every class it uses (" $LAST[1] " missing)\n";

select TR2RML_RUN ('urn:tr2rml:map-dt', 'urn:tr2rml:qm-dt');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": the view with rr:datatype on columns is created without errors, got " $LAST[1] "\n";

select count (*) from (sparql select ?o from <urn:tr2rml:view-dt> where { ?s <http://example.org/firm/ns#workDate> ?o }) x;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": the view has 2 ex:workDate triples, got " $LAST[1] "\n";

-- ?p unbound, so the datatype is the value's own, not the one the compiler
-- knows statically for the field
select count (*) from (sparql select (str (datatype (?o)) as ?dt) from <urn:tr2rml:view-dt> where { ?s ?p ?o }) x
  where "dt" = 'http://www.w3.org/2001/XMLSchema#date';
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": rr:datatype xsd:date on a DATE column gives 2 xsd:date values, got " $LAST[1] "\n";

select count (*) from (sparql select (str (datatype (?o)) as ?dt) from <urn:tr2rml:view-dt> where { ?s ?p ?o }) x
  where "dt" = 'http://www.w3.org/2001/XMLSchema#integer';
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": rr:datatype xsd:integer on an INTEGER column gives 2 xsd:integer values, got " $LAST[1] "\n";

select case when strstr (cast (s as varchar), '"2026-01-12"^^<http://www.w3.org/2001/XMLSchema#date>') is not null then 'found' else cast (s as varchar) end
  from (select (sparql define output:format "NT" construct { ?s ?p ?o } from <urn:tr2rml:view-dt>
    where { ?s ?p ?o . filter (?s = <http://example.org/firm/workday/1>) }) as s) x;
ECHO BOTH $IF $EQU $LAST[1] "found" "PASSED" "***FAILED";
ECHO BOTH ": the view's N-Triples write \"2026-01-12\"^^xsd:date, got " $LAST[1] "\n";

select count (*) from (sparql select ?s from <urn:tr2rml:view-dt> where { ?s <http://example.org/firm/ns#workDate> "2026-01-13"^^<http://www.w3.org/2001/XMLSchema#date> }) x;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a pattern with the typed date \"2026-01-13\"^^xsd:date finds its row, got " $LAST[1] "\n";

--------------------------------------------------------------------------
-- 4. cleanup
--------------------------------------------------------------------------

SPARQL DROP SILENT QUAD MAP <urn:tr2rml:qm>;
SPARQL DROP SILENT QUAD MAP <urn:tr2rml:qm-iri>;
SPARQL DROP SILENT QUAD MAP <urn:tr2rml:qm-dt>;

ECHO BOTH "COMPLETED: R2RML (tr2rml.sql)\n";
