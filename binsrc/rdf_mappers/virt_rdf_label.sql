--
--
--  $Id$
--
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2006 OpenLink Software
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

TTLP (
'@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix dc: <http://purl.org/dc/elements/1.1/> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#> .
@prefix fbase: <http://rdf.freebase.com/ns/type.object.> .
@prefix skos: <http://www.w3.org/2008/05/skos#> .
@prefix bibo: <http://purl.org/ontology/bibo/> .
@prefix gr: <http://purl.org/goodrelations/v1#> .
@prefix cb: <http://www.crunchbase.com/> .
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#> .
@prefix og: <http://opengraphprotocol.org/schema/> .
@prefix dv: <http://rdf.data-vocabulary.org/> .
@prefix c: <http://www.w3.org/2002/12/cal/icaltzd#> .

dc:title rdfs:subPropertyOf virtrdf:label .
rdfs:label rdfs:subPropertyOf virtrdf:label .
fbase:name rdfs:subPropertyOf virtrdf:label .
foaf:name rdfs:subPropertyOf virtrdf:label .
<http://s.opencalais.com/1/pred/name> rdfs:subPropertyOf virtrdf:label .
foaf:nick rdfs:subPropertyOf virtrdf:label .
<http://www.w3.org/2004/02/skos/core#prefLabel> rdfs:subPropertyOf virtrdf:label .
skos:prefLabel rdfs:subPropertyOf virtrdf:label .
<http://www.geonames.org/ontology#name> rdfs:subPropertyOf virtrdf:label .
<http://purl.org/dc/terms/title> rdfs:subPropertyOf virtrdf:label .
foaf:accountName rdfs:subPropertyOf virtrdf:label .
bibo:shortTitle rdfs:subPropertyOf virtrdf:label .
<http://s.opencalais.com/1/pred/name> rdfs:subPropertyOf foaf:name .
cb:source_description rdfs:subPropertyOf foaf:name .
<http://s.opencalais.com/1/type/er/Company> rdfs:subClassOf gr:BusinessEntity .
gr:BusinessEntity rdfs:subClassOf foaf:Organization .
<http://dbpedia.org/ontology/Company> rdfs:subClassOf gr:BusinessEntity .
<http://purl.org/ontology/mo/MusicArtist> rdfs:subClassOf foaf:Person .
foaf:maker rdfs:subClassOf dc:creator .
<http://dbpedia.org/property/name> rdfs:subPropertyOf foaf:name .
<http://www.w3.org/2002/12/cal/ical#summary> rdfs:subPropertyOf rdfs:label .
<http://usefulinc.com/ns/doap#name> rdfs:subPropertyOf rdfs:label .
foaf:topic rdfs:subPropertyOf dcterms:references .
<http://opengraphprotocol.org/schema/title> owl:equivalentProperty <http://opengraphprotocol.org/schema/title#this> .
<http://rdfs.org/ns/void#vocabulary> owl:equivalentProperty <http://www.openlinksw.com/schema/attribution/isDescribedUsing> .
<http://aims.fao.org/aos/geopolitical.owl#nameListEN> rdfs:subPropertyOf rdfs:label .
<http://aims.fao.org/aos/geopolitical.owl#hasMinLatitude> rdfs:subPropertyOf geo:lat .
<http://aims.fao.org/aos/geopolitical.owl#hasMinLongitude> rdfs:subPropertyOf geo:long .
og:latitude rdfs:subPropertyOf geo:lat .
og:longitude rdfs:subPropertyOf geo:long .
<http://uberblic.org/ontology/latitude> rdfs:subPropertyOf geo:lat .
<http://uberblic.org/ontology/longitude> rdfs:subPropertyOf geo:long .
<http://www.ontosearch.com/2008/02/ontosminer-ns/domain/common/english#Person> rdfs:subClassOf foaf:Person .
<http://rdfs.org/ns/void#vocabulary> owl:equivalentProperty <http://www.openlinksw.com/schema/attribution#isDescribedUsing> .
<http://www.rdfabout.com/rdf/schema/ussec/tradingSymbol> a owl:inverseFunctionalProperty . 
<http://www.rdfabout.com/rdf/schema/ussec/cik> a owl:inverseFunctionalProperty .
foaf:logo owl:subPropertyOf foaf:depiction .
<http://umbel.org/umbel#isAbout> owl:equivalentProperty foaf:focus .
gr:name owl:equivalentProperty foaf:name .
<http://poolparty.punkt.at/demozone/ont#title> rdfs:subPropertyOf virtrdf:label .
<http://www.w3.org/2007/05/powder-s#describedby> owl:equivalentProperty <http://www.iana.org/assignments/relation/describedby> .
<http://dbpedia.org/property/secCik> a owl:inverseFunctionalProperty .
dv:photo owl:equivalentProperty foaf:depiction .
dv:instructions owl:equivalentProperty dc:description .
dv:name rdfs:subPropertyOf virtrdf:label .
c:summary rdfs:subPropertyOf virtrdf:label .
c:description owl:equivalentProperty dc:description .
foaf:img rdfs:subPropertyOf virtrdf:image .
foaf:depiction rdfs:subPropertyOf virtrdf:image .
dv:photo rdfs:subPropertyOf virtrdf:image .
<http://www.openlinksw.com/schemas/virtcxml#Custom-Screen%20Name> owl:equivalentProperty foaf:nick.
<http://www.openlinksw.com/schemas/virtcxml#Custom-Real%20Name> owl:equivalentProperty foaf:name .
<http://www.openlinksw.com/schemas/virtcxml#FacetDescription> owl:equivalentProperty dcterms:description .
', '', 'virtrdf-label');

rdfs_rule_set ('virtrdf-label', 'virtrdf-label');

