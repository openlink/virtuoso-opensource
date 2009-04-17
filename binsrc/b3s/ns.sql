--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2009 OpenLink Software
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

DB.DBA.XML_SET_NS_DECL ('foaf', 'http://xmlns.com/foaf/0.1/', 2);
DB.DBA.XML_SET_NS_DECL ('rev', 'http://purl.org/stuff/rev#', 2);
DB.DBA.XML_SET_NS_DECL ('sioc', 'http://rdfs.org/sioc/ns#', 2);
DB.DBA.XML_SET_NS_DECL ('geonames', 'http://www.geonames.org/ontology#', 2);
DB.DBA.XML_SET_NS_DECL ('geo', 'http://www.w3.org/2003/01/geo/wgs84_pos#', 2);
DB.DBA.XML_SET_NS_DECL ('usc',  'http://www.rdfabout.com/rdf/schema/uscensus/details/100pct/', 2);
DB.DBA.XML_SET_NS_DECL ('b3s', 'http://b3s-demo.openlinksw.com/', 2);
DB.DBA.XML_SET_NS_DECL ('lod', 'http://lod.openlinksw.com/', 2);


delete from rdf_quad where g = iri_to_id ('b3sonto');

ttlp ('
@prefix foaf: <http://xmlns.com/foaf/0.1/>
@prefix dc: <http://purl.org/dc/elements/1.1/>
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
@prefix b3s: <http://b3s.openlinksw.com/>

rdfs:label rdfs:subPropertyOf b3s:label .
dc:title rdfs:subPropertyOf b3s:label .
foaf:name rdfs:subPropertyOf b3s:label .
foaf:nick rdfs:subPropertyOf b3s:label .', 'xx', 'b3sonto');



rdfs_rule_set ('b3s', 'b3sonto');


ttlp ('
@prefix foaf: <http://xmlns.com/foaf/0.1/>
@prefix owl: <http://www.w3.org/2002/07/owl#>
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
@prefix lod: <http://lod.openlinksw.com/>

foaf:mbox_sha1sum a owl:InverseFunctionalProperty .
foaf:name a owl:InverseFunctionalProperty .
foaf:name rdfs:subPropertyOf lod:ifp_like .
foaf:mbox_sha1sum rdfs:subPropertyOf lod:ifp_like .

', 'xx', 'b3sifp');

rdfs_rule_set ('b3sifp', 'b3sifp');
