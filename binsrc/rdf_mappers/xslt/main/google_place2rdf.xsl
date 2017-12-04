<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2017 OpenLink Software
 -
 -  This project is free software; you can redistribute it and/or modify it
 -  under the terms of the GNU General Public License as published by the
 -  Free Software Foundation; only version 2 of the License, dated June 1991.
 -
 -  This program is distributed in the hope that it will be useful, but
 -  WITHOUT ANY WARRANTY; without even the implied warranty of
 -  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 -  General Public License for more details.
 -
 -  You should have received a copy of the GNU General Public License along
 -  with this program; if not, write to the Free Software Foundation, Inc.,
 -  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
-->
<!DOCTYPE xsl:stylesheet [
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
<!ENTITY nyt "http://www.nytimes.com/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY vcard "http://www.w3.org/2001/vcard-rdf/3.0#">
<!ENTITY geo "http://www.w3.org/2003/01/geo/wgs84_pos#"> 
<!ENTITY gn "http://www.geonames.org/ontology#">
<!ENTITY review "http://purl.org/stuff/rev#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:opl="http://www.openlinksw.com/schema/attribution#"
    xmlns:dcterms = "http://purl.org/dc/terms/"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:dc="&dc;"
    xmlns:nyt="&nyt;"
    xmlns:sioc="&sioc;"
    xmlns:vcard="&vcard;"
    xmlns:sioct="&sioct;"
    xmlns:geo="&geo;"
    xmlns:gn="&gn;"
    xmlns:review="&review;"
	xmlns:oplfq="http://www.openlinksw.com/schemas/foursquare#"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    >
    
    <xsl:param name="baseUri" />

    <xsl:output method="xml" indent="yes" />
	
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
		
    <xsl:template match="/PlaceDetailsResponse/result">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<sioc:container_of rdf:resource="{$resourceURL}"/>
			<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			<dcterms:subject rdf:resource="{$resourceURL}"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<owl:sameAs rdf:resource="{$docIRI}"/>
		</rdf:Description>
		<rdf:Description rdf:about="{$resourceURL}">
			<rdf:type rdf:resource="&gn;Feature"/>
			<opl:providedBy>
				<foaf:Organization rdf:about="http://maps.google.com#this">
					<foaf:name>Google Maps</foaf:name>
					<foaf:homepage rdf:resource="http://maps.google.com"/>
				</foaf:Organization>
			</opl:providedBy>
			<xsl:if test="name">
				<dc:title>
					<xsl:value-of select="name" />
				</dc:title>
				<rdfs:label>
					<xsl:value-of select="name"/>
				</rdfs:label>
			</xsl:if>        
			<xsl:if test="formatted_phone_number">
				<foaf:phone rdf:resource="tel:{formatted_phone_number}"/>
				<vcard:TEL>
					<xsl:value-of select="formatted_phone_number" />   
				</vcard:TEL>
			</xsl:if>
			<xsl:if test="formatted_address">
				<vcard:ADR>
					<xsl:value-of select="formatted_address" />   
				</vcard:ADR>
			</xsl:if>
			<xsl:if test="address_component[type='locality']">
				<vcard:Locality rdf:resource="{vi:dbpIRI ($baseUri, address_component[type='locality']/long_name)}"/>
			</xsl:if>
			<xsl:if test="address_component[type='country']">
				<vcard:Country rdf:resource="{vi:dbpIRI ($baseUri, address_component[type='country']/long_name)}"/>
			</xsl:if>
			<xsl:if test="address_component[type='administrative_area_level_1']">
				<vcard:Region rdf:resource="{vi:dbpIRI ($baseUri, address_component[type='administrative_area_level_1']/long_name)}"/>
			</xsl:if>
			<xsl:if test="address_component[type='postal_code']">
				<vcard:Pcode>
					<xsl:value-of select="address_component[type='postal_code']/long_name" />   
				</vcard:Pcode>
			</xsl:if>
			<xsl:if test="address_component[type='route']">
				<vcard:Street>
					<xsl:value-of select="address_component[type='route']/long_name" />   
				</vcard:Street>
			</xsl:if>
			<xsl:if test="geometry/location/lng">
				<geo:long rdf:datatype="&xsd;float">
					<xsl:value-of select="geometry/location/lng"/>
				</geo:long>
			</xsl:if>
			<xsl:if test="geometry/location/lat">
				<geo:lat rdf:datatype="&xsd;float">
					<xsl:value-of select="geometry/location/lat"/>
				</geo:lat>
			</xsl:if>
			<bibo:uri rdf:resource="{url}" />
			<sioc:link rdf:resource="{url}" />
			<foaf:depiction rdf:resource="{icon}"/>
			<xsl:if test="string-length(rating) &gt; 0">
				<review:rating>
					<xsl:value-of select="rating"/>
				</review:rating>
			</xsl:if>
			<xsl:for-each select="type">
				<sioc:topic rdf:resource="{vi:dbpIRI ($baseUri, .)}"/>
			</xsl:for-each>
			
		</rdf:Description>
    </xsl:template>

    <xsl:template match="text()|@*"/>

</xsl:stylesheet>
