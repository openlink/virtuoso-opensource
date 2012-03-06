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
@prefix oplzllw: <http://www.openlinksw.com/schemas/zillow#> .
@prefix oplgp: <http://www.openlinksw.com/schemas/googleplus#> .
@prefix event: <http://purl.org/NET/c4dm/event.owl#> .
@prefix dbpedia: <http://dbpedia.org/ontology/> .
@prefix vcard: <http://www.w3.org/2001/vcard-rdf/3.0#> .
@prefix sioc: <http://rdfs.org/sioc/ns#> .
@prefix opltw: <http://www.openlinksw.com/schemas/twitter#> .
@prefix sioct: <http://rdfs.org/sioc/types#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

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
<http://www.w3.org/1999/02/22-rdf-syntax-ns#value> rdfs:subPropertyOf virtrdf:label .
<http://rdf.alchemyapi.com/rdf/v1/s/aapi-schema.rdf#Name> rdfs:subPropertyOf virtrdf:label .
<http://rdf.freebase.com/ns/common.topic.alias> rdfs:subPropertyOf virtrdf:label .
<http://commontag.org/ns#label> rdfs:subPropertyOf virtrdf:label .
oplzllw:latitude owl:equivalentProperty geo:lat .
oplzllw:longitude owl:equivalentProperty geo:long .
oplgp:organization_name rdfs:subPropertyOf virtrdf:label .
oplgp:displayName rdfs:subPropertyOf virtrdf:label .
oplgp:activity_title rdfs:subPropertyOf virtrdf:label .
oplgp:actor_displayName rdfs:subPropertyOf virtrdf:label .
oplgp:attachment_displayName rdfs:subPropertyOf virtrdf:label .
<http://yago-knowledge.org/resource/hasPreferredMeaning> rdfs:subPropertyOf virtrdf:label .
<http://yago-knowledge.org/resource/hasPreferredName> rdfs:subPropertyOf virtrdf:label .

oplgp:Activity owl:equivalentClass sioc:Post .
oplgp:ActivityObject owl:equivalentClass sioc:Post .
oplgp:Actor owl:equivalentClass sioc:UserAccount .
oplgp:Comment owl:equivalentClass sioc:Post .

oplgp:actor owl:equivalentProperty sioc:has_creator .
oplgp:comment_actor owl:equivalentProperty sioc:has_creator .
oplgp:has_comment owl:equivalentProperty sioc:has_reply .
oplgp:in_reply_to owl:equivalentProperty sioc:reply_of .
oplgp:attachment owl:equivalentProperty sioc:attachment .
oplgp:annotation owl:equivalentProperty sioc:content .
oplgp:html_content owl:equivalentProperty sioc:content .
oplgp:originalContent owl:equivalentProperty sioc:content .
oplgp:content owl:equivalentProperty sioc:content .
oplgp:comment_content owl:equivalentProperty sioc:content .
oplgp:email owl:equivalentProperty sioc:email .
oplgp:role owl:equivalentProperty sioc:has_function .
oplgp:activity_replied_to_id owl:equivalentProperty sioc:id .
oplgp:placeId owl:equivalentProperty sioc:id.
oplgp:id owl:equivalentProperty sioc:id. 
oplgp:updated owl:equivalentProperty sioc:last_activity_date .
oplgp:activity_url owl:equivalentProperty sioc:link .
oplgp:profile_url owl:equivalentProperty sioc:link .
oplgp:shared_url owl:equivalentProperty sioc:link .
oplgp:primary_url owl:equivalentProperty sioc:link .
oplgp:url_value owl:equivalentProperty sioc:link .
oplgp:object_url owl:equivalentProperty sioc:link .
oplgp:actor_profile_url owl:equivalentProperty sioc:link .
oplgp:attachment_url owl:equivalentProperty sioc:link .
oplgp:embed_url owl:equivalentProperty sioc:link .
oplgp:full_image_url owl:equivalentProperty sioc:link .
oplgp:preview_image_url owl:equivalentProperty sioc:link .
oplgp:in_reply_to_url owl:equivalentProperty sioc:link .
oplgp:displayName owl:equivalentProperty sioc:name .
oplgp:name owl:equivalentProperty sioc:name .
oplgp:formatted owl:equivalentProperty sioc:name .
oplgp:middleName owl:equivalentProperty sioc:name .
oplgp:organization_name owl:equivalentProperty sioc:name .
oplgp:actor_displayName owl:equivalentProperty sioc:name .
oplgp:attachment_displayName owl:equivalentProperty sioc:name .
oplgp:familyName owl:equivalentProperty sioc:name .
oplgp:givenName owl:equivalentProperty sioc:name .
oplgp:annotation owl:equivalentProperty sioc:note . 

oplgp:Organization owl:equivalentClass foaf:Organization .
oplgp:Person owl:equivalentClass foaf:Person .
oplgp:FullImage owl:equivalentClass foaf:Image .
oplgp:PreviewImage owl:equivalentClass foaf:Image .
oplgp:Actor owl:equivalentClass foaf:OnlineAccount .

oplgp:actor owl:equivalentProperty foaf:account .
oplgp:email owl:equivalentProperty foaf:mbox .
oplgp:actor_profile_image owl:equivalentProperty foaf:img .
oplgp:profile_image owl:equivalentProperty foaf:img .
oplgp:fullImage owl:equivalentProperty foaf:img .
oplgp:previewImage owl:equivalentProperty foaf:img .
oplgp:displayName owl:equivalentProperty foaf:name .
oplgp:name owl:equivalentProperty foaf:name .
oplgp:formatted owl:equivalentProperty foaf:name .
oplgp:middleName owl:equivalentProperty foaf:name .
oplgp:organization_name owl:equivalentProperty foaf:name .
oplgp:actor_displayName owl:equivalentProperty foaf:name .
oplgp:attachment_displayName owl:equivalentProperty foaf:name .
oplgp:familyName owl:equivalentProperty foaf:familyName .
oplgp:givenName owl:equivalentProperty foaf:givenName .
oplgp:gender owl:equivalentProperty foaf:gender .
oplgp:nickname owl:equivalentProperty foaf:nick .
oplgp:date_of_birth owl:equivalentProperty foaf:birthday .
oplgp:relationshipStatus owl:equivalentProperty foaf:status .
oplgp:honorificPrefix owl:equivalentProperty foaf:title .
oplgp:honorificSuffix owl:equivalentProperty foaf:surname .

oplgp:aboutMe rdfs:subPropertyOf dc:description .
oplgp:activity_title owl:equivalentProperty dc:title .
oplgp:published owl:equivalentProperty dc:date .
oplgp:updated owl:equivalentProperty dc:date .
oplgp:date_of_birth owl:equivalentProperty dc:date .
oplgp:endDate owl:equivalentProperty dc:date .
oplgp:startDate owl:equivalentProperty dc:date .
oplgp:actor owl:equivalentProperty dc:creator .
oplgp:comment_actor owl:equivalentProperty dc:creator .
oplgp:tagline rdfs:subPropertyOf dc:description .
oplgp:role rdfs:subPropertyOf dc:description .
oplgp:access_description rdfs:subPropertyOf dc:description .
oplgp:attachment_media_type rdfs:subPropertyOf dc:format .
oplgp:full_image_width rdfs:subPropertyOf dc:format .
oplgp:full_image_height rdfs:subPropertyOf dc:format .
oplgp:preview_image_height rdfs:subPropertyOf dc:format .
oplgp:preview_image_width rdfs:subPropertyOf dc:format .
oplgp:activity_replied_to_id rdfs:subPropertyOf dc:identifier .
oplgp:placeId rdfs:subPropertyOf dc:identifier .
oplgp:id rdfs:subPropertyOf dc:identifier .
oplgp:speaksLanguage rdfs:subPropertyOf dc:language .
oplgp:activity_title owl:equivalentProperty dc:publisher .
oplgp:relationshipStatus rdfs:subPropertyOf dc:relation .
oplgp:profile_url rdfs:subPropertyOf dc:source .
oplgp:shared_url rdfs:subPropertyOf dc:source .
oplgp:crosspostSource rdfs:subPropertyOf dc:source .
oplgp:activity_url rdfs:subPropertyOf dc:source .
oplgp:activity_url rdfs:subPropertyOf dc:source .
oplgp:url_value rdfs:subPropertyOf dc:source .
oplgp:object_url rdfs:subPropertyOf dc:source .
oplgp:actor_profile_url rdfs:subPropertyOf dc:source .
oplgp:attachment_url rdfs:subPropertyOf dc:source .
oplgp:embed_url rdfs:subPropertyOf dc:source .
oplgp:full_image_url rdfs:subPropertyOf dc:source .
oplgp:preview_image_url rdfs:subPropertyOf dc:source .
oplgp:comment_self_link rdfs:subPropertyOf dc:source .
oplgp:in_reply_to_url rdfs:subPropertyOf dc:source .
oplgp:title owl:equivalentProperty dc:title .
oplgp:attachment_displayName owl:equivalentProperty dc:title .
oplgp:activity_title owl:equivalentProperty dc:title .
oplgp:email_type rdfs:subPropertyOf dc:type .
oplgp:organization_type owl:equivalentProperty dc:type .
oplgp:url_type rdfs:subPropertyOf dc:type .
oplgp:access_item_type rdfs:subPropertyOf dc:type .
oplgp:activity_object_type rdfs:subPropertyOf dc:type .
oplgp:attachment_media_type rdfs:subPropertyOf dc:type .
oplgp:embed_media_type rdfs:subPropertyOf dc:type .
oplgp:full_image_media_type rdfs:subPropertyOf dc:type .
oplgp:preview_image_media_type rdfs:subPropertyOf dc:type .   

oplgp:published owl:equivalentProperty dcterms:created .
oplgp:updated owl:equivalentProperty dcterms:date .
oplgp:actor owl:equivalentProperty dcterms:creator .
oplgp:comment_actor owl:equivalentProperty dcterms:creator .
oplgp:aboutMe rdfs:subPropertyOf dcterms:description .
oplgp:tagline rdfs:subPropertyOf dcterms:description .
oplgp:access_description rdfs:subPropertyOf dcterms:description .
oplgp:attachment_media_type rdfs:subPropertyOf dcterms:format .
oplgp:full_image_width rdfs:subPropertyOf dcterms:format .
oplgp:full_image_height rdfs:subPropertyOf dcterms:format .
oplgp:preview_image_height rdfs:subPropertyOf dcterms:format .
oplgp:preview_image_width rdfs:subPropertyOf dcterms:format .
oplgp:activity_replied_to_id rdfs:subPropertyOf dcterms:identifier .
oplgp:placeId rdfs:subPropertyOf dcterms:identifier .
oplgp:id rdfs:subPropertyOf dcterms:identifier .
oplgp:speaksLanguage rdfs:subPropertyOf dcterms:language .
oplgp:updated owl:equivalentProperty dcterms:modified .
oplgp:activity_title owl:equivalentProperty dcterms:publisher .
oplgp:relationshipStatus rdfs:subPropertyOf dcterms:relation .
oplgp:profile_url rdfs:subPropertyOf dcterms:source .
oplgp:shared_url rdfs:subPropertyOf dcterms:source .
oplgp:crosspostSource rdfs:subPropertyOf dcterms:source .
oplgp:activity_url rdfs:subPropertyOf dcterms:source .
oplgp:activity_url rdfs:subPropertyOf dcterms:source .
oplgp:url_value rdfs:subPropertyOf dcterms:source .
oplgp:object_url rdfs:subPropertyOf dcterms:source .
oplgp:actor_profile_url rdfs:subPropertyOf dcterms:source .
oplgp:attachment_url rdfs:subPropertyOf dcterms:source .
oplgp:embed_url rdfs:subPropertyOf dcterms:source .
oplgp:full_image_url rdfs:subPropertyOf dcterms:source .
oplgp:preview_image_url rdfs:subPropertyOf dcterms:source .
oplgp:comment_self_link rdfs:subPropertyOf dcterms:source .
oplgp:in_reply_to_url rdfs:subPropertyOf dcterms:source .
oplgp:title owl:equivalentProperty dcterms:title .
oplgp:attachment_displayName owl:equivalentProperty dcterms:title .
oplgp:activity_title owl:equivalentProperty dcterms:title .
oplgp:email_type rdfs:subPropertyOf dcterms:type .
oplgp:organization_type owl:equivalentProperty dcterms:type .
oplgp:url_type rdfs:subPropertyOf dcterms:type .
oplgp:access_item_type rdfs:subPropertyOf dcterms:type .
oplgp:activity_object_type rdfs:subPropertyOf dcterms:type .
oplgp:attachment_media_type rdfs:subPropertyOf dcterms:type .
oplgp:embed_media_type rdfs:subPropertyOf dcterms:type .
oplgp:full_image_media_type rdfs:subPropertyOf dcterms:type .
oplgp:preview_image_media_type rdfs:subPropertyOf dcterms:type .   

oplgp:FullImage owl:equivalentClass bibo:Image . 
oplgp:Email owl:equivalentClass bibo:Email .
oplgp:PreviewImage owl:equivalentClass bibo:Image . 

oplgp:annotation owl:equivalentProperty bibo:content .
oplgp:annotation owl:equivalentProperty bibo:annotates .
oplgp:originalContent owl:equivalentProperty bibo:content .
oplgp:content owl:equivalentProperty bibo:content .
oplgp:comment_content owl:equivalentProperty bibo:content .
oplgp:html_content owl:equivalentProperty bibo:content .
oplgp:relationshipStatus owl:equivalentProperty bibo:status .
oplgp:activity_title owl:equivalentProperty bibo:title .
oplgp:activity_title owl:equivalentProperty bibo:title .
oplgp:title owl:equivalentProperty bibo:title .
oplgp:attachment_displayName owl:equivalentProperty bibo:title .
oplgp:actor owl:equivalentProperty bibo:owner .
oplgp:comment_actor owl:equivalentProperty bibo:owner .
oplgp:activity_replied_to_id rdfs:subPropertyOf bibo:identifier .
oplgp:placeId rdfs:subPropertyOf bibo:identifier .
oplgp:id rdfs:subPropertyOf bibo:identifier .
oplgp:honorificPrefix owl:equivalentProperty bibo:prefixName .
oplgp:honorificSuffix owl:equivalentProperty bibo:suffixName .

oplgp:placeName owl:equivalentProperty event:place .

oplgp:date_of_birth owl:equivalentProperty <http://www.openlinksw.com/schemas/rdfs/birthDate#this> .
	
oplgp:honorificPrefix owl:equivalentProperty vcard:TITLE .
oplgp:formatted owl:equivalentProperty vcard:FN .
oplgp:nickname owl:equivalentProperty vcard:NICKNAME .
oplgp:date_of_birth owl:equivalentProperty vcard:BDAY .
oplgp:title owl:equivalentProperty vcard:TITLE .
oplgp:role owl:equivalentProperty vcard:ROLE .
oplgp:annotation owl:equivalentProperty vcard:NOTE .
oplgp:email owl:equivalentProperty vcard:EMAIL .
oplgp:displayName owl:equivalentProperty vcard:N .
oplgp:name owl:equivalentProperty vcard:N .
oplgp:formatted owl:equivalentProperty vcard:N .
oplgp:familyName owl:equivalentProperty vcard:Family .
oplgp:givenName owl:equivalentProperty vcard:Given .
oplgp:honorificPrefix owl:equivalentProperty vcard:Prefix .
oplgp:honorificSuffix owl:equivalentProperty vcard:Suffix .
oplgp:organization_name owl:equivalentProperty vcard:ORG .
oplgp:department owl:subPropertyOf vcard:Orgunit .
oplgp:actor_profile_image owl:equivalentProperty vcard:PHOTO .
oplgp:profile_image owl:equivalentProperty vcard:PHOTO .
oplgp:fullImage owl:equivalentProperty vcard:PHOTO .
oplgp:previewImage owl:equivalentProperty vcard:PHOTO .

oplgp:shared_url owl:equivalentProperty rdfs:seeAlso .

oplgp:Activity owl:equivalentClass dbpedia:Activity .
oplgp:Name owl:equivalentClass dbpedia:Name .
oplgp:Organization owl:equivalentClass dbpedia:Organization .
oplgp:Person owl:equivalentClass dbpedia:Person .
oplgp:Actor owl:equivalentClass dbpedia:Actor .
oplgp:PlaceLived owl:equivalentClass dbpedia:Place .
oplgp:activity_title owl:equivalentClass dbpedia:Publisher .
oplgp:published owl:equivalentProperty dbpedia:Date .
oplgp:updated owl:equivalentProperty dbpedia:Date .
oplgp:access owl:equivalentProperty dbpedia:Access .
oplgp:address owl:equivalentProperty dbpedia:Address .
oplgp:annotation owl:equivalentProperty dbpedia:Note .
oplgp:placeName owl:equivalentProperty dbpedia:Place .
oplgp:currentLocation owl:equivalentProperty dbpedia:LocatedInArea .
oplgp:date_of_birth owl:equivalentProperty dbpedia:BirthDate .
oplgp:gender owl:equivalentProperty dbpedia:Genre .
oplgp:speaksLanguage owl:equivalentProperty dbpedia:Language .
oplgp:relationshipStatus owl:equivalentProperty dbpedia:Relation .
oplgp:department owl:equivalentProperty dbpedia:Department .
oplgp:role owl:equivalentProperty dbpedia:Role .
oplgp:location owl:equivalentProperty dbpedia:Location .
oplgp:title owl:equivalentProperty dbpedia:Title .


opltw:User owl:equivalentClass foaf:Person .
opltw:made_tweet owl:equivalentProperty foaf:made .
opltw:via owl:equivalentProperty foaf:maker .

opltw:Tweet owl:equivalentClass sioc:Post .
opltw:User owl:equivalentClass sioc:UserAccount .
opltw:made_tweet owl:equivalentProperty sioc:has_creator .
opltw:id owl:equivalentProperty sioc:id .
opltw:appLink owl:equivalentProperty sioc:link .

opltw:Tweet owl:equivalentClass sioct:MicroblogPost .

opltw:appLink owl:equivalentProperty rdf:Resource .

opltw:User owl:equivalentClass dc:Agent .
opltw:made_tweet owl:equivalentProperty dc:creator .
opltw:id rdfs:subPropertyOf dc:identifier .
opltw:appLink rdfs:subPropertyOf dc:source .

opltw:User owl:equivalentClass dcterms:Agent .
opltw:made_tweet owl:equivalentProperty dcterms:creator .
opltw:id rdfs:subPropertyOf dcterms:identifier .
opltw:appLink rdfs:subPropertyOf dcterms:source .

opltw:Tweet owl:equivalentClass bibo:Article.
opltw:id rdfs:subPropertyOf bibo:identifier .

opltw:Tweet owl:equivalentClass dbpedia:Activity .
opltw:User owl:equivalentClass dbpedia:Actor .
opltw:User owl:equivalentClass dbpedia:Person .
opltw:Application owl:equivalentClass dbpedia:Software .
opltw:id owl:equivalentProperty dbpedia:Id .
opltw:followed_by owl:equivalentProperty dbpedia:Person .
opltw:follows owl:equivalentProperty dbpedia:Person .
opltw:made_tweet owl:equivalentProperty dbpedia:Owner .

', '', 'virtrdf-label');

rdfs_rule_set ('virtrdf-label', 'virtrdf-label');

