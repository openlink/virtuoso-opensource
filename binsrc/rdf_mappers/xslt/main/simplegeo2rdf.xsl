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
<!ENTITY review "http:/www.purl.org/stuff/rev#">
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
	xmlns:oplsg="http://www.openlinksw.com/schemas/simplegeo#"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    >
    
    <xsl:param name="baseUri" />

    <xsl:output method="xml" indent="yes" />
	
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:template match="/results/features[1]">
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
				<foaf:Organization rdf:about="http://simplegeo.com#this">
					<foaf:name>SimpleGeo</foaf:name>
					<foaf:homepage rdf:resource="http://simplegeo.com"/>
				</foaf:Organization>
			</opl:providedBy>
			<xsl:if test="geometry/coordinates[1]">
				<geo:long rdf:datatype="&xsd;float">
					<xsl:value-of select="geometry/coordinates[1]"/>
				</geo:long>
			</xsl:if>
			<xsl:if test="geometry/coordinates[2]">
				<geo:lat rdf:datatype="&xsd;float">
					<xsl:value-of select="geometry/coordinates[2]"/>
				</geo:lat>
			</xsl:if>
			<xsl:if test="string-length(id) &gt; 0">
				<sioc:link rdf:resource="{concat('https://simplegeo.com/', id)}"/>
			</xsl:if>
			<xsl:if test="string-length(properties/province) &gt; 0">
				<vcard:Region rdf:resource="{vi:dbpIRI ($baseUri, properties/province)}"/>
			</xsl:if>
			<xsl:if test="string-length(properties/name) &gt; 0">
				<dc:title>
					<xsl:value-of select="properties/name" />
				</dc:title>
				<rdfs:label>
					<xsl:value-of select="properties/name"/>
				</rdfs:label>				
			</xsl:if>       
			<xsl:if test="string-length(properties/country) &gt; 0">
				<vcard:Country rdf:resource="{vi:dbpIRI ($baseUri, properties/country)}"/>
			</xsl:if>
			<xsl:if test="string-length(properties/phone) &gt; 0">
				<foaf:phone rdf:resource="tel:{properties/phone}"/>
			</xsl:if>
			<xsl:if test="string-length(properties/href) &gt; 0">
				<sioc:link rdf:resource="{properties/href}"/>
			</xsl:if>
			<xsl:if test="string-length(properties/city) &gt; 0">
				<vcard:Locality rdf:resource="{vi:dbpIRI ($baseUri, properties/city)}"/>
			</xsl:if>
			<xsl:if test="string-length(properties/address) &gt; 0">
				<vcard:ADR>
					<xsl:value-of select="properties/address" />   
				</vcard:ADR>
			</xsl:if>
			<xsl:if test="string-length(properties/postcode) &gt; 0">
				<vcard:Pcode>
					<xsl:value-of select="properties/postcode" />   
				</vcard:Pcode>
			</xsl:if>
			<xsl:if test="string-length(properties/classifiers/category) &gt; 0">
				<oplsg:category>
					<xsl:value-of select="properties/classifiers/category" />   
				</oplsg:category>
			</xsl:if>
			<xsl:if test="string-length(properties/classifiers/type) &gt; 0">
				<oplsg:type>
					<xsl:value-of select="properties/classifiers/type" />   
				</oplsg:type>
			</xsl:if>
			<xsl:if test="string-length(properties/classifiers/subcategory) &gt; 0">
				<oplsg:subcategory>
					<xsl:value-of select="properties/classifiers/subcategory" />   
				</oplsg:subcategory>
			</xsl:if>
		</rdf:Description>
    </xsl:template>

    <xsl:template match="text()|@*"/>

</xsl:stylesheet>
