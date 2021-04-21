--
--
--  $Id$
--
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2021 OpenLink Software
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

delete from RDF_QUAD where G = iri_to_id ('virtrdf-url');

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
@prefix oplzllw: <http://www.openlinksw.com/schemas/zillow#> .
@prefix oplgp: <http://www.openlinksw.com/schemas/googleplus#> .
@prefix event: <http://purl.org/NET/c4dm/event.owl#> .
@prefix dbpedia: <http://dbpedia.org/ontology/> .
@prefix vcard: <http://www.w3.org/2006/vcard/ns#> .
@prefix sioc: <http://rdfs.org/sioc/ns#> .
@prefix opltw: <http://www.openlinksw.com/schemas/twitter#> .
@prefix sioct: <http://rdfs.org/sioc/types#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix oplli: <http://www.openlinksw.com/schemas/linkedin#> .
@prefix umbelrc: <http://umbel.org/umbel/rc/> .
@prefix oplog: <http://www.openlinksw.com/schemas/opengraph#> . 
@prefix mo: <http://purl.org/ontology/mo/> .
@prefix oplbase: <http://www.openlinksw.com/schemas/oplbase#> . 
@prefix schema: <http://schema.org/> .
@prefix virtws: <http://www.openlinksw.com/ontology/webservices#> .
@prefix pows: <http://www.w3.org/2007/05/powder-s#> .


foaf:page rdfs:subPropertyOf virtrdf:url .
foaf:homePage rdfs:subPropertyOf virtrdf:url .
foaf:img rdfs:subPropertyOf virtrdf:url .
foaf:logo rdfs:subPropertyOf virtrdf:url .
foaf:depiction rdfs:subPropertyOf virtrdf:url .

schema:downloadUrl rdfs:subPropertyOf virtrdf:url .
schema:potentialAction rdfs:subPropertyOf virtrdf:url .
schema:logo rdfs:subPropertyOf virtrdf:url .
schema:image rdfs:subPropertyOf virtrdf:url .
schema:mainEntityOfPage rdfs:subPropertyOf virtrdf:url .

pows:describedby rdfs:subPropertyOf virtrdf:url .
sioc:links_to rdfs:subPropertyOf virtrdf:url .

', '', 'virtrdf-url');

rdfs_rule_set ('virtrdf-url', 'virtrdf-url');
