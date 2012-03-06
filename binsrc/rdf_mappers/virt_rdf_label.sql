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
@prefix oplli: <http://www.openlinksw.com/schemas/linkedin#> .
@prefix umbelrc: <http://umbel.org/umbel/rc/> .
@prefix oplog: <http://www.openlinksw.com/schemas/opengraph#> . 
@prefix mo: <http://purl.org/ontology/mo/> .

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
gr:name rdfs:subPropertyOf foaf:name .
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
oplgp:middleName rdfs:subPropertyOf sioc:name .
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

oplgp:email owl:equivalentProperty foaf:mbox .
oplgp:actor_profile_image owl:equivalentProperty foaf:img .
oplgp:profile_image owl:equivalentProperty foaf:img .
oplgp:fullImage owl:equivalentProperty foaf:img .
oplgp:previewImage owl:equivalentProperty foaf:img .
oplgp:displayName owl:equivalentProperty foaf:name .
oplgp:name owl:equivalentProperty foaf:name .
oplgp:formatted owl:equivalentProperty foaf:name .
oplgp:middleName rdfs:subPropertyOf foaf:name .
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


oplli:Person owl:equivalentClass foaf:Person .
oplli:Company owl:equivalentClass foaf:Organization .
oplli:InstantMessagingAccount rdfs:subClassOf foaf:OnlineAccount .
oplli:TwitterAccount owl:equivalentClass foaf:OnlineAccount .

oplli:first_name owl:equivalentProperty foaf:firstName .
oplli:has_phone_number owl:equivalentProperty foaf:phone .
oplli:has_im_account owl:equivalentProperty foaf:account .
oplli:has_twitter_account owl:equivalentProperty foaf:account .
oplli:interests owl:equivalentProperty foaf:interest .
oplli:last_name owl:equivalentProperty foaf:lastName .
oplli:location_name owl:equivalentProperty foaf:based_near .
oplli:picture_url owl:equivalentProperty foaf:img .
oplli:publication owl:equivalentProperty foaf:publications .
oplli:public_profile_url owl:equivalentProperty foaf:accountServiceHomepage .
oplli:public_profile_url owl:equivalentProperty foaf:page .
oplli:company_name rdfs:subPropertyOf foaf:name .
oplli:school_name rdfs:subPropertyOf foaf:name .
oplli:im_account_name owl:equivalentProperty foaf:accountName .
oplli:phone_number owl:equivalentProperty foaf:phone .
oplli:publication_summary owl:equivalentProperty foaf:publications .
oplli:publication_title owl:equivalentProperty foaf:publications .
oplli:publisher_name rdfs:subPropertyOf foaf:name .
oplli:author_name rdfs:subPropertyOf foaf:name .
oplli:provider_account_name owl:equivalentProperty foaf:account .  

oplli:Publication owl:equivalentClass sioc:Post .
oplli:Recommendation owl:equivalentClass sioc:Post .
oplli:InstantMessagingAccount owl:equivalentClass sioc:UserAccount .
oplli:TwitterAccount owl:equivalentClass sioc:UserAccount .
oplli:Skill owl:equivalentClass sioc:Role .

oplli:id owl:equivalentProperty sioc:id .
oplli:patent_status_id rdfs:subPropertyOf sioc:id .
oplli:inventor_id rdfs:subPropertyOf sioc:id .
oplli:author_id rdfs:subPropertyOf sioc:id .
oplli:provider_account_id rdfs:subPropertyOf sioc:id .
oplli:member_url_resource owl:equivalentProperty sioc:link .
oplli:picture_url owl:equivalentProperty sioc:link .
oplli:public_profile_url owl:equivalentProperty sioc:link .
oplli:patent_url owl:equivalentProperty sioc:link .
oplli:member_shared_resource_url owl:equivalentProperty sioc:link .
oplli:publication_url owl:equivalentProperty sioc:link . 
oplli:summary owl:equivalentProperty sioc:content . 
oplli:patent_summary owl:equivalentProperty sioc:content . 
oplli:publication_summary owl:equivalentProperty sioc:content . 
oplli:education_notes owl:equivalentProperty sioc:note . 
oplli:provider_account_name rdfs:subPropertyOf sioc:name . 
oplli:first_name rdfs:subPropertyOf sioc:name . 
oplli:im_account_name rdfs:subPropertyOf sioc:name . 
oplli:company_name rdfs:subPropertyOf sioc:name .
oplli:school_name rdfs:subPropertyOf sioc:name .
oplli:publisher_name rdfs:subPropertyOf sioc:name .
oplli:author_name rdfs:subPropertyOf sioc:name .
oplli:provider_account_name rdfs:subPropertyOf sioc:name .
oplli:last_name rdfs:subPropertyOf sioc:name .
oplli:proposal_comments rdfs:subPropertyOf sioc:note . 
oplli:certification_name rdfs:subPropertyOf sioc:name .
oplli:language_name rdfs:subPropertyOf sioc:name .
oplli:publication_title rdfs:subPropertyOf sioc:name .
oplli:member_shared_resource_name rdfs:subPropertyOf sioc:name .

oplli:Person rdfs:subClassOf dc:Agent .
oplli:Company rdfs:subClassOf dc:Agent .
oplli:InstantMessagingAccount rdfs:subClassOf dc:Agent .
oplli:TwitterAccount rdfs:subClassOf dc:Agent .

oplli:proposal_comments rdfs:subPropertyOf dc:description .
oplli:associations rdfs:subPropertyOf dc:description .
oplli:certification rdfs:subPropertyOf dc:description .
oplli:language owl:equivalentProperty dc:language .
oplli:company_type owl:equivalentProperty dc:type .
oplli:im_account_type owl:equivalentProperty dc:type .
oplli:phone_number_type owl:equivalentProperty dc:type .
oplli:recommendation_type owl:equivalentProperty dc:type .
oplli:id owl:equivalentProperty dc:identifier .
oplli:patent_status_id rdfs:subPropertyOf dc:identifier . 
oplli:inventor_id rdfs:subPropertyOf dc:identifier .
oplli:author_id rdfs:subPropertyOf dc:identifier .
oplli:provider_account_id rdfs:subPropertyOf dc:identifier .
oplli:member_url_resource rdfs:subPropertyOf dc:source .
oplli:picture_url rdfs:subPropertyOf dc:source .
oplli:public_profile_url rdfs:subPropertyOf dc:source .
oplli:member_shared_resource_url rdfs:subPropertyOf dc:source .
oplli:patent_url rdfs:subPropertyOf dc:source .
oplli:publication_url rdfs:subPropertyOf dc:source .
oplli:publisher_name owl:equivalentProperty dc:publisher . 
oplli:summary owl:equivalentProperty dc:description .
oplli:patent_title owl:equivalentProperty dc:title .
oplli:title owl:equivalentProperty dc:title .
oplli:publication_title owl:equivalentProperty dc:title .
oplli:date_of_birth owl:equivalentProperty dc:date .
oplli:certification_start_date owl:equivalentProperty dc:date .
oplli:certification_end_date owl:equivalentProperty dc:date .
oplli:education_start_date owl:equivalentProperty dc:date .
oplli:education_end_date owl:equivalentProperty dc:date .
oplli:patent_date owl:equivalentProperty dc:date .
oplli:end_date owl:equivalentProperty dc:date .
oplli:start_date owl:equivalentProperty dc:date .
oplli:publication_date owl:equivalentProperty dc:date .
oplli:author_name owl:equivalentProperty dc:creator .

oplli:Person rdfs:subClassOf dcterms:Agent .
oplli:Company rdfs:subClassOf dcterms:Agent .
oplli:InstantMessagingAccount rdfs:subClassOf dcterms:Agent .
oplli:TwitterAccount rdfs:subClassOf dcterms:Agent .

oplli:proposal_comments rdfs:subPropertyOf dcterms:description .
oplli:associations rdfs:subPropertyOf dcterms:description .
oplli:certification rdfs:subPropertyOf dcterms:description .
oplli:education rdfs:subPropertyOf dcterms:educationLevel .
oplli:language owl:equivalentProperty dcterms:language .
oplli:company_type owl:equivalentProperty dcterms:type .
oplli:im_account_type owl:equivalentProperty dcterms:type .
oplli:phone_number_type owl:equivalentProperty dcterms:type .
oplli:recommendation_type owl:equivalentProperty dcterms:type .
oplli:id owl:equivalentProperty dcterms:identifier .
oplli:patent_status_id rdfs:subPropertyOf dcterms:identifier . 
oplli:inventor_id rdfs:subPropertyOf dcterms:identifier .
oplli:author_id rdfs:subPropertyOf dcterms:identifier .
oplli:provider_account_id rdfs:subPropertyOf dcterms:identifier .
oplli:member_url_resource rdfs:subPropertyOf dcterms:source .
oplli:picture_url rdfs:subPropertyOf dcterms:source .
oplli:public_profile_url rdfs:subPropertyOf dcterms:source .
oplli:member_shared_resource_url rdfs:subPropertyOf dcterms:source .
oplli:patent_url rdfs:subPropertyOf dcterms:source .
oplli:publication_url rdfs:subPropertyOf dcterms:source .
oplli:publisher_name owl:equivalentProperty dcterms:publisher . 
oplli:summary owl:equivalentProperty dcterms:description .
oplli:patent_title owl:equivalentProperty dcterms:title .
oplli:title owl:equivalentProperty dcterms:title .
oplli:publication_title owl:equivalentProperty dcterms:title .
oplli:date_of_birth owl:equivalentProperty dcterms:date .
oplli:certification_start_date owl:equivalentProperty dcterms:date .
oplli:certification_end_date owl:equivalentProperty dcterms:date .
oplli:education_start_date owl:equivalentProperty dcterms:date .
oplli:education_end_date owl:equivalentProperty dcterms:date .
oplli:patent_date owl:equivalentProperty dcterms:date .
oplli:end_date owl:equivalentProperty dcterms:date .
oplli:start_date owl:equivalentProperty dcterms:date .
oplli:publication_date owl:equivalentProperty dcterms:date .
oplli:author_name owl:equivalentProperty dcterms:creator .


oplli:Patent owl:equivalentClass bibo:Patent .
oplli:Publication rdfs:subClassOf bibo:Document .

oplli:publication_url owl:equivalentProperty bibo:uri .
oplli:education_notes owl:equivalentProperty bibo:annotates .
oplli:patent_number owl:equivalentProperty bibo:number .
oplli:skill_years_of_experience owl:equivalentProperty bibo:number .
oplli:patent_status owl:equivalentProperty bibo:status .
oplli:author_name owl:equivalentProperty bibo:owner.
oplli:author_name owl:equivalentProperty bibo:producer .
oplli:author_person owl:equivalentProperty bibo:owner.
oplli:author_person owl:equivalentProperty bibo:producer .
oplli:patent_summary owl:equivalentProperty bibo:content .
oplli:position_summary owl:equivalentProperty bibo:content .
oplli:publication_summary owl:equivalentProperty bibo:content .
oplli:summary owl:equivalentProperty bibo:content .
oplli:id owl:equivalentProperty bibo:identifier .
oplli:patent_status_id owl:equivalentProperty bibo:identifier .
oplli:inventor_id owl:equivalentProperty bibo:identifier .
oplli:author_id owl:equivalentProperty bibo:identifier .
oplli:provider_account_id owl:equivalentProperty bibo:identifier .


oplli:date_of_birth owl:equivalentProperty vcard:BDAY .
oplli:education_notes owl:equivalentProperty vcard:NOTE .
oplli:first_name owl:equivalentProperty vcard:Given .
oplli:last_name owl:equivalentProperty vcard:Family .
oplli:picture_url owl:equivalentProperty vcard:PHOTO .
oplli:company_industry rdfs:subPropertyOf vcard:Orgunit .
oplli:company_name owl:equivalentProperty vcard:Orgname .
oplli:id owl:equivalentProperty vcard:UID .
oplli:patent_status_id owl:equivalentProperty vcard:UID .
oplli:inventor_id owl:equivalentProperty vcard:UID .
oplli:author_id owl:equivalentProperty vcard:UID .
oplli:provider_account_id owl:equivalentProperty vcard:UID .
oplli:phone_number owl:equivalentProperty vcard:TEL .
oplli:phone_number_type owl:equivalentProperty vcard:TELTYPES .
oplli:main_address owl:equivalentProperty vcard:ADR .

oplli:Person owl:equivalentClass dbpedia:Person .
oplli:InstantMessagingAccount owl:equivalentClass dbpedia:Person .
oplli:TwitterAccount owl:equivalentClass dbpedia:Person .
oplli:Company owl:equivalentClass dbpedia:Organization .
oplli:Language owl:equivalentClass dbpedia:Language .
oplli:Publication owl:equivalentClass dbpedia:Activity .
oplli:date_of_birth owl:equivalentProperty dbpedia:Date .
oplli:certification_start_date owl:equivalentProperty dbpedia:Date .
oplli:certification_end_date owl:equivalentProperty dbpedia:Date .
oplli:education_start_date owl:equivalentProperty dbpedia:Date .
oplli:education_end_date owl:equivalentProperty dbpedia:Date .
oplli:patent_date owl:equivalentProperty dbpedia:Date .
oplli:end_date owl:equivalentProperty dbpedia:Date .
oplli:start_date owl:equivalentProperty dbpedia:Date .
oplli:publication_date owl:equivalentProperty dbpedia:Date .
oplli:main_address owl:equivalentProperty dbpedia:Address .
oplli:education_notes owl:equivalentProperty dbpedia:Note .
oplli:location_name owl:equivalentProperty dbpedia:Place .
oplli:date_of_birth owl:equivalentProperty dbpedia:BirthDate .
oplli:patent_title owl:equivalentProperty dbpedia:Title .
oplli:title owl:equivalentProperty dbpedia:Title .
oplli:publication_title owl:equivalentProperty dbpedia:Title .
oplli:school_name owl:equivalentProperty dbpedia:School .
oplli:education_start_date owl:equivalentProperty dbpedia:StartDate .
oplli:start_date owl:equivalentProperty dbpedia:StartDate .
oplli:certification_start_date owl:equivalentProperty dbpedia:StartDate .
oplli:certification_end_date owl:equivalentProperty dbpedia:EndDate .
oplli:education_end_date owl:equivalentProperty dbpedia:EndDate .
oplli:end_date owl:equivalentProperty dbpedia:EndDate .
oplli:certification_name owl:equivalentProperty dbpedia:Certification .
oplli:specialties owl:equivalentProperty dbpedia:Specialist .
oplli:patent owl:equivalentProperty dbpedia:Patent .
oplli:associations owl:equivalentProperty dbpedia:Associate .
oplli:country_code rdfs:subPropertyOf dbpedia:AreaCode .
oplli:education owl:equivalentProperty dbpedia:Education .
oplli:publication_date owl:equivalentProperty dbpedia:FirstPublicationDate .
oplli:publication_date owl:equivalentProperty dbpedia:PublicationDate .
oplli:distance owl:equivalentProperty dbpedia:Distance . 
oplli:industry owl:equivalentProperty dbpedia:Industry .
oplli:interests owl:equivalentProperty dbpedia:Interest .
oplli:language owl:equivalentProperty dbpedia:Language .
oplli:location_name owl:equivalentProperty dbpedia:Location .
oplli:main_address owl:equivalentProperty dbpedia:Address .
oplli:patent owl:equivalentProperty dbpedia:Patent .
oplli:title owl:equivalentProperty dbpedia:Position .
oplli:publisher_name owl:equivalentProperty dbpedia:Publisher .
oplli:company_name owl:equivalentProperty dbpedia:Company .
oplli:patent_status owl:equivalentProperty dbpedia:Status .
oplli:patent_number owl:equivalentProperty dbpedia:Number .
oplli:certification_number owl:equivalentProperty dbpedia:Number .
oplli:phone_number owl:equivalentProperty dbpedia:Number .
oplli:skill_years_of_experience owl:equivalentProperty dbpedia:Number .
oplli:company_type owl:equivalentProperty dbpedia:Type .
oplli:im_account_type owl:equivalentProperty dbpedia:Type .
oplli:phone_number_type owl:equivalentProperty dbpedia:Type .
oplli:recommendation_type owl:equivalentProperty dbpedia:Type . 
oplli:member_url_resource owl:equivalentProperty dbpedia:Source . 
oplli:picture_url owl:equivalentProperty dbpedia:Source . 
oplli:public_profile_url owl:equivalentProperty dbpedia:Source . 
oplli:member_shared_resource_url owl:equivalentProperty dbpedia:Source . 
oplli:patent_url owl:equivalentProperty dbpedia:Source . 
oplli:publication_url owl:equivalentProperty dbpedia:Source . 
oplli:inventor_person owl:equivalentProperty dbpedia:Person . 
oplli:author_name owl:equivalentProperty dbpedia:Author . 
oplli:author_person owl:equivalentProperty dbpedia:Author . 

oplli:Company owl:equivalentClass gr:BusinessEntity .

oplli:Language owl:equivalentClass <http://www.openlinksw.com/schemas/rdfs/Language#this> .

oplli:Publication	owl:equivalentClass umbelrc:ScholarlyArticle .

oplli:date_of_birth owl:equivalentProperty <http://www.openlinksw.com/schemas/rdfs/birthDate#this> .

oplli:has_phone_number owl:equivalentProperty <http://www.openlinksw.com/schemas/rdfs/telephone#this> .


oplog:Account owl:equivalentClass foaf:OnlineAccount .
oplog:Group owl:equivalentClass foaf:Group .
oplog:Note rdfs:subClassOf foaf:Document .
oplog:Photo rdfs:subClassOf foaf:Image . 
oplog:User rdfs:subClassOf foaf:Person . 
oplog:Image owl:equivalentClass foaf:Image . 
oplog:Album rdfs:subClassOf mo:ReleaseType .
oplog:Application rdfs:subClassOf dbpedia:Software . 

oplog:has_picture owl:equivalentProperty foaf:img .
oplog:picture owl:equivalentProperty foaf:img .
oplog:has_photo owl:equivalentProperty foaf:img .
oplog:photos rdfs:subPropertyOf foaf:img .
oplog:has_account rdfs:subPropertyOf foaf:page .
oplog:name owl:equivalentProperty foaf:name .
oplog:uri rdfs:subPropertyOf foaf:homepage .
oplog:website rdfs:subPropertyOf foaf:homepage .
oplog:username rdfs:subPropertyOf foaf:name .
oplog:has_interest owl:equivalentProperty foaf:interest .
oplog:first_name owl:equivalentProperty foaf:firstName .
oplog:last_name owl:equivalentProperty foaf:lastName .
oplog:gender owl:equivalentProperty foaf:gender .
oplog:birthday owl:equivalentProperty foaf:birthday .
oplog:has_friend rdfs:subPropertyOf foaf:knows .
oplog:email owl:equivalentProperty foaf:mbox .
oplog:mobile_phone rdfs:subPropertyOf foaf:phone . 

oplog:Post owl:equivalentClass sioc:Post .
oplog:Activity owl:equivalentClass sioc:Post .
oplog:Account owl:equivalentClass sioc:UserAccount .
oplog:Comment owl:equivalentClass sioc:Post .

oplog:email owl:equivalentProperty sioc:email .
oplog:id owl:equivalentProperty sioc:id .
oplog:third_party_id owl:equivalentProperty sioc:id .
oplog:updated_time owl:equivalentProperty sioc:last_activity_date .
oplog:link owl:equivalentProperty sioc:link .
oplog:name owl:equivalentProperty sioc:name .
oplog:notes rdfs:subPropertyOf sioc:note .

oplog:id owl:equivalentProperty dc:identifier .
oplog:third_party_id rdfs:subPropertyOf dc:identifier .
oplog:album_type rdfs:subPropertyOf dc:type .
oplog:description owl:equivalentProperty dc:description .
oplog:height rdfs:subPropertyOf dc:format .
oplog:width rdfs:subPropertyOf dc:format .
oplog:tagged_by owl:equivalentProperty dc:source .
oplog:link owl:equivalentProperty dc:source .
oplog:uri owl:equivalentProperty dc:source .
oplog:username owl:equivalentProperty dc:publisher .
oplog:updated_time rdfs:subPropertyOf dc:date .
oplog:birthday rdfs:subPropertyOf dc:date .
oplog:languages rdfs:subPropertyOf dc:language .

oplog:id owl:equivalentProperty dcterms:identifier .
oplog:third_party_id rdfs:subPropertyOf dcterms:identifier .
oplog:album_type rdfs:subPropertyOf dcterms:type .
oplog:description owl:equivalentProperty dcterms:description .
oplog:height rdfs:subPropertyOf dcterms:format .
oplog:width rdfs:subPropertyOf dcterms:format .
oplog:tagged_by owl:equivalentProperty dcterms:source .
oplog:link owl:equivalentProperty dcterms:source .
oplog:uri owl:equivalentProperty dcterms:source .
oplog:username owl:equivalentProperty dcterms:publisher .
oplog:updated_time rdfs:subPropertyOf dcterms:date .
oplog:birthday rdfs:subPropertyOf dcterms:date .
oplog:languages rdfs:subPropertyOf dcterms:language .
oplog:education rdfs:subPropertyOf dcterms:educationLevel .

oplog:Photo owl:equivalentClass bibo:Image . 
oplog:Book owl:equivalentClass bibo:Book . 
oplog:Movie owl:equivalentClass bibo:Film . 
oplog:Note owl:equivalentClass bibo:Note . 
oplog:id owl:equivalentProperty bibo:identifier .
oplog:third_party_id rdfs:subPropertyOf bibo:identifier .

oplog:Event owl:equivalentClass event:Event .

oplog:name owl:equivalentProperty vcard:N .
oplog:birthday owl:equivalentProperty vcard:BDAY .
oplog:email owl:equivalentProperty vcard:EMAIL .
oplog:last_name owl:equivalentProperty vcard:Family .
oplog:has_photo rdfs:subPropertyOf vcard:PHOTO .
oplog:photos rdfs:subPropertyOf vcard:PHOTO .
oplog:has_variant rdfs:subPropertyOf vcard:PHOTO .
oplog:mobile_phone rdfs:subPropertyOf vcard:TEL .
oplog:notes rdfs:subPropertyOf vcard:NOTE .
oplog:tagged_by rdfs:subPropertyOf vcard:SOURCE .
oplog:link rdfs:subPropertyOf vcard:SOURCE .
oplog:uri rdfs:subPropertyOf vcard:SOURCE .
oplog:address owl:equivalentProperty vcard:ADR .
oplog:locale owl:equivalentProperty vcard:Locality .
oplog:timezone owl:equivalentProperty vcard:TZ .     
oplog:middle_name rdfs:subPropertyOf vcard:Other .     
oplog:id rdfs:subPropertyOf vcard:UID	.
oplog:third_party_id rdfs:subPropertyOf vcard:UID .
oplog:category rdfs:subPropertyOf vcard:CATEGORIES .

oplog:Activity owl:equivalentClass dbpedia:Activity .
oplog:updated_time rdfs:subPropertyOf dbpedia:Date .
oplog:birthday rdfs:subPropertyOf dbpedia:Date .
oplog:address owl:equivalentProperty dbpedia:Address .
oplog:notes rdfs:subPropertyOf dbpedia:Note .
oplog:location owl:equivalentProperty dbpedia:Location .
oplog:birthday owl:equivalentProperty dbpedia:BirthDate .
oplog:gender owl:equivalentProperty dbpedia:Genre .
oplog:languages rdfs:subPropertyOf dbpedia:Language .
oplog:education owl:equivalentProperty dbpedia:Education .
oplog:has_interest rdfs:subPropertyOf dbpedia:Interest .
oplog:address owl:equivalentProperty dbpedia:Address .
oplog:album_type rdfs:subPropertyOf dbpedia:Type .
oplog:tagged_by rdfs:subPropertyOf dbpedia:Source . 
oplog:link rdfs:subPropertyOf dbpedia:Source . 
oplog:uri rdfs:subPropertyOf dbpedia:Source . 


', '', 'virtrdf-label');

rdfs_rule_set ('virtrdf-label', 'virtrdf-label');

