--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2015 OpenLink Software
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


echo both "RDF IFP Test\n";

ttlp ('
<john1> a <person> .
<john2> a <person> .
<mary> a <person> .
<mike> a <person> .
<john1> <name> "John" .
<john2> <name> "John" .
<john1> <address> "101 A street" .
<john2> <address> "102 B street" .
<john2> <knows> <mike> .
<john1> <http://www.w3.org/2002/07/owl#sameAs> <john2> .
<mary> <knows> "John" .
<mike> <knows> <john1> .
<mike> <knows> <john2> .
<john1> <name> "Tarzan" .
<mike> <nam> "Tarzan" .
', '', 'ifps');


ttlp ('
<name> a <http://www.w3.org/2002/07/owl#InverseFunctionalProperty> .
<name> <http://www.openlinksw.com/schemas/virtrdf#nullIFPValue> "Tarzan" .
', '', 'ifp_list');

rdfs_rule_set ('ifps', 'ifp_list');



sparql define input:inference 'ifps'  select * from <ifps> where {<john1> ?p ?o};
echo both $if $equ $rowcnt 9 "PASSED" "***FAILED";
echo both ": properties of john\n";

sparql define input:inference 'ifps'  select * from <ifps> where { ?person a <person> . ?person <knows> ?somebody . ?somebody  ?p ?o};


sparql select distinct ?p from <ifps> where { ?p a <person>};
echo both $if $equ $rowcnt 4 "PASSED" "***FAILED";
echo both ": distinct persons\n";

sparql define input:inference "ifps" select distinct ?p from <ifps> where { ?p a <person>};
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": distinct persons with ifp inf\n";


-- rdf_inf_set_ifp_exclude_list ('ifps', iri_to_id ('name'), vector ('John'));

-- sparql define input:inference "ifps" select distinct ?p from <ifps> where { ?p a <person>};


