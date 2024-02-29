--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2024 OpenLink Software
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
DB.DBA.XML_SET_NS_DECL ('b3s', 'http://b3s.openlinksw.com/', 2);
DB.DBA.XML_SET_NS_DECL ('lod', 'http://lod.openlinksw.com/', 2);
DB.DBA.XML_SET_NS_DECL ('lgv', 'http://linkedgeodata.org/vocabulary#', 2);
DB.DBA.XML_SET_NS_DECL ('category', 'http://dbpedia.org/resource/Category:', 2);
DB.DBA.XML_SET_NS_DECL ('grs', 'http://www.georss.org/georss/', 2);


create procedure fct_rdfs_rule_set_upgrade()
{
    if (registry_get ('__fct_rdfs_rule_set_upgrade', '0') = '1')
        return;

    --  Remove old rule sets
    rdfs_rule_set ('b3sifp',        'b3sifp',        1);
    rdfs_rule_set ('b3s',           'b3sonto',       1);
    rdfs_rule_set ('facets',        'facets',        1);
    rdfs_rule_set ('facets',        'virtrdf-label', 1);
    rdfs_rule_set ('virtrdf-label', 'virtrdf-label', 1);
    rdfs_rule_set ('virtrdf-url',   'virtrdf-url',   1);
    commit work;

    --  Add existing graph content to new urn based graphs
    SPARQL ADD <b3sifp>        TO <urn:fct:b3sifp>;
    SPARQL ADD <b3sonto>       TO <urn:fct:b3sonto>;
    SPARQL ADD <facets>        TO <urn:fct:facets>;
    SPARQL ADD <virtrdf-label> TO <urn:fct:virtrdf:label>;
    SPARQL ADD <virtrdf-url>   TO <urn:fct:virtrdf:url>;
    commit work;

    -- Delete old graphs
    SPARQL CLEAR GRAPH <b3sifp>;
    SPARQL CLEAR GRAPH <b3sonto>;
    SPARQL CLEAR GRAPH <facets>;
    SPARQL CLEAR GRAPH <virtrdf-label>;
    SPARQL CLEAR GRAPH <virtrdf-url>;
    commit work;

    registry_set ('__fct_rdfs_rule_set_upgrade', '1');
};

fct_rdfs_rule_set_upgrade();


ttlp ('
@prefix foaf: <http://xmlns.com/foaf/0.1/>
@prefix dc: <http://purl.org/dc/elements/1.1/>
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
@prefix b3s: <http://b3s.openlinksw.com/>

rdfs:label rdfs:subPropertyOf b3s:label .
dc:title rdfs:subPropertyOf b3s:label .
foaf:name rdfs:subPropertyOf b3s:label .
foaf:nick rdfs:subPropertyOf b3s:label .
<http://purl.uniprot.org/core/scientificName> rdfs:subPropertyOf b3s:label .
', 'xx', 'urn:fct:b3sonto');



rdfs_rule_set ('b3s', 'urn:fct:b3sonto');


ttlp ('
@prefix foaf: <http://xmlns.com/foaf/0.1/>
@prefix owl: <http://www.w3.org/2002/07/owl#>
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
@prefix lod: <http://lod.openlinksw.com/>

foaf:mbox_sha1sum a owl:InverseFunctionalProperty .
foaf:mbox_sha1sum rdfs:subPropertyOf lod:ifp_like .
foaf:mbox a owl:InverseFunctionalProperty .
foaf:mbox rdfs:subPropertyOf lod:ifp_like .
# rdfs:label a owl:InverseFunctionalProperty .
# rdfs:label rdfs:subPropertyOf lod:ifp_like .
<http://linkedopencommerce.com/schemas/icecat/v1/hasProductId> a owl:InverseFunctionalProperty .
<http://linkedopencommerce.com/schemas/icecat/v1/hasProductId> rdfs:subPropertyOf lod:ifp_like .

', 'xx', 'urn:fct:b3sifp');

rdfs_rule_set ('b3sifp', 'urn:fct:b3sifp');

SPARQL
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
INSERT INTO GRAPH <urn:rules.skos> { skos:broader rdfs:subPropertyOf skos:broaderTransitive .  skos:narrower rdfs:subPropertyOf skos:narrowerTransitive }
;

rdfs_rule_set ('skos-trans', 'urn:rules.skos');

create procedure fct_load_oplweb ()
{
  for select RES_CONTENT as cnt from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/VAD/fct/owl/oplweb.owl' do
    {
      DB.DBA.RDF_LOAD_RDFXML (cast (cnt as varchar), 'http://www.openlinksw.com/schemas/oplweb#', 'http://www.openlinksw.com/schemas/oplweb#');
    }
}
;

fct_load_oplweb ();
rdfs_rule_set ('oplweb', 'http://www.openlinksw.com/schemas/oplweb#');

DB.DBA.RDF_GRAPH_GROUP_CREATE (UNAME'http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs', 1);
DB.DBA.RDF_GRAPH_GROUP_INS('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs', 'urn:fct:b3sifp');
DB.DBA.RDF_GRAPH_GROUP_INS('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs', 'urn:fct:b3sonto');
DB.DBA.RDF_GRAPH_GROUP_INS('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs', 'urn:fct:facets');
DB.DBA.RDF_GRAPH_GROUP_INS('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs', 'urn:fct:virtrdf:label');
DB.DBA.RDF_GRAPH_GROUP_INS('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs', 'urn:fct:virtrdf:url');
DB.DBA.RDF_GRAPH_GROUP_INS('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs', 'urn:rules.skos');
