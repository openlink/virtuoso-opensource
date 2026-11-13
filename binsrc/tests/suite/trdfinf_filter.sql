--
--  trdfinf_filter.sql
--
--  With an inference rule set, ?type in { ?s a ?type } ranges over the stored
--  class and its superclasses, and ?p in { ?s ?p ?o } over the stored property
--  and its superproperties.  A FILTER on such a variable has to see the
--  inferred values: != , IN, NOT IN and && of them must not be applied to the
--  stored value only.
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

ECHO BOTH "STARTED: FILTER on an inferred class or property\n";

sparql clear graph <urn:tif:data>;
sparql clear graph <urn:tif:schema>;
DB.DBA.TTLP ('
@prefix ex: <urn:tif:> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
ex:Partner rdfs:subClassOf ex:Lawyer .
ex:Associate rdfs:subClassOf ex:Lawyer .
ex:Lawyer rdfs:subClassOf ex:Person .
ex:Paralegal rdfs:subClassOf ex:Person .
ex:leadPartnerOf rdfs:subPropertyOf ex:worksOn .
', '', 'urn:tif:schema');
DB.DBA.TTLP ('
@prefix ex: <urn:tif:> .
ex:jdoe a ex:Partner ; ex:leadPartnerOf ex:m1 .
ex:asmith a ex:Associate .
ex:clee a ex:Person .
ex:bkhan a ex:Paralegal .
', '', 'urn:tif:data');
rdfs_rule_set ('tif-rules', 'urn:tif:schema');

--  The types of jdoe, as a sorted space separated list.
create procedure TIF_TYPES (in filt varchar)
{
  declare st, msg, md, rs, res any;
  st := '00000';
  exec (concat ('sparql define input:inference "tif-rules" prefix ex: <urn:tif:> select ?t from <urn:tif:data> where { ex:jdoe a ?t ', filt, ' } order by ?t'),
    st, msg, vector (), 0, md, rs);
  if (st <> '00000')
    return st;
  res := '';
  foreach (any r in rs) do
    res := concat (res, case when res = '' then '' else ' ' end, subseq (r[0], 8));
  return res;
}
;

--  The properties linking jdoe to m1.
create procedure TIF_PROPS (in filt varchar)
{
  declare st, msg, md, rs, res any;
  st := '00000';
  exec (concat ('sparql define input:inference "tif-rules" prefix ex: <urn:tif:> select ?p from <urn:tif:data> where { ex:jdoe ?p ex:m1 ', filt, ' } order by ?p'),
    st, msg, vector (), 0, md, rs);
  if (st <> '00000')
    return st;
  res := '';
  foreach (any r in rs) do
    res := concat (res, case when res = '' then '' else ' ' end, subseq (r[0], 8));
  return res;
}
;

select TIF_TYPES ('');
ECHO BOTH $IF $EQU $LAST[1] "Lawyer Partner Person" "PASSED" "***FAILED";
ECHO BOTH ": jdoe's types with inference = " $LAST[1] "\n";

select TIF_TYPES ('filter (?t != ex:Person)');
ECHO BOTH $IF $EQU $LAST[1] "Lawyer Partner" "PASSED" "***FAILED";
ECHO BOTH ": != an inferred class = " $LAST[1] "\n";

select TIF_TYPES ('filter (?t != ex:Partner)');
ECHO BOTH $IF $EQU $LAST[1] "Lawyer Person" "PASSED" "***FAILED";
ECHO BOTH ": != the stored class keeps the inferred ones = " $LAST[1] "\n";

select TIF_TYPES ('filter (?t != ex:Person && ?t != ex:Partner)');
ECHO BOTH $IF $EQU $LAST[1] "Lawyer" "PASSED" "***FAILED";
ECHO BOTH ": two != joined by && = " $LAST[1] "\n";

select TIF_TYPES ('filter (?t in (ex:Lawyer, ex:Person))');
ECHO BOTH $IF $EQU $LAST[1] "Lawyer Person" "PASSED" "***FAILED";
ECHO BOTH ": IN of two inferred classes = " $LAST[1] "\n";

select TIF_TYPES ('filter (?t not in (ex:Partner))');
ECHO BOTH $IF $EQU $LAST[1] "Lawyer Person" "PASSED" "***FAILED";
ECHO BOTH ": NOT IN of the stored class = " $LAST[1] "\n";

select count (*) from (sparql define input:inference "tif-rules" prefix ex: <urn:tif:>
  select ?s ?t from <urn:tif:data> where { ?s a ?t filter (?t != ex:Person) }) x;
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
ECHO BOTH ": != an inferred class over every subject keeps " $LAST[1] " rows\n";

select TIF_PROPS ('');
ECHO BOTH $IF $EQU $LAST[1] "leadPartnerOf worksOn" "PASSED" "***FAILED";
ECHO BOTH ": jdoe to m1 with inference = " $LAST[1] "\n";

select TIF_PROPS ('filter (?p != ex:leadPartnerOf)');
ECHO BOTH $IF $EQU $LAST[1] "worksOn" "PASSED" "***FAILED";
ECHO BOTH ": != the stored property keeps the inferred one = " $LAST[1] "\n";

select TIF_PROPS ('filter (?p != ex:worksOn)');
ECHO BOTH $IF $EQU $LAST[1] "leadPartnerOf" "PASSED" "***FAILED";
ECHO BOTH ": != an inferred property = " $LAST[1] "\n";

--  Forms that already see the inferred value: they must not move.
select TIF_TYPES ('filter (strstarts (str (?t), "urn:tif:P"))');
ECHO BOTH $IF $EQU $LAST[1] "Partner Person" "PASSED" "***FAILED";
ECHO BOTH ": a function of the inferred class = " $LAST[1] "\n";

select count (*) from (sparql define input:inference "tif-rules" prefix ex: <urn:tif:>
  select ?s from <urn:tif:data> where { ?s a ex:Lawyer }) x;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": a class given as a constant finds " $LAST[1] " lawyers\n";

select TIF_TYPES ('filter (?t = ex:Lawyer)');
ECHO BOTH $IF $EQU $LAST[1] "Lawyer" "PASSED" "***FAILED";
ECHO BOTH ": = an inferred class = " $LAST[1] "\n";

select TIF_PROPS ('filter (?p in (ex:worksOn))');
ECHO BOTH $IF $EQU $LAST[1] "worksOn" "PASSED" "***FAILED";
ECHO BOTH ": IN of one inferred property = " $LAST[1] "\n";

drop procedure TIF_TYPES;
drop procedure TIF_PROPS;
sparql clear graph <urn:tif:data>;
sparql clear graph <urn:tif:schema>;

ECHO BOTH "COMPLETED: FILTER on an inferred class or property\n";
