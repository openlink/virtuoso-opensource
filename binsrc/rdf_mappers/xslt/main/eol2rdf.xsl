<?xml version="1.0" encoding="utf-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2016 OpenLink Software
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
<!DOCTYPE xsl:stylesheet
[
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY gr "http://purl.org/goodrelations/v1#">
]>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
xmlns:rdf="&rdf;"
xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
xmlns:foaf="&foaf;"
xmlns:bibo="&bibo;"
xmlns:sioc="&sioc;" 
xmlns:gr="&gr;"
xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
xmlns:dcterms="&dcterms;"
xmlns:opl="http://www.openlinksw.com/schema/attribution#"
xmlns:dc="http://purl.org/dc/elements/1.1/"
xmlns:owl="http://www.w3.org/2002/07/owl#"
xmlns:dwc="http://rs.tdwg.org/dwc/terms/"
xmlns:cc="http://web.resource.org/cc/"
>

  <xsl:output method="xml" indent="yes" />

  <xsl:param name="baseUri" />

  <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)" />
  <xsl:variable name="docIRI" select="vi:docIRI($baseUri)" />
  <xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)" />
  
	<xsl:template match="/">
		<rdf:RDF>
			  <rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document" />
				<sioc:container_of rdf:resource="{$resourceURL}" />
				<foaf:primaryTopic rdf:resource="{$resourceURL}" />
				<dcterms:subject rdf:resource="{$resourceURL}" />
				<dc:title><xsl:value-of select="$baseUri"/></dc:title>
				<owl:sameAs rdf:resource="{$docIRI}"/>
				<rdfs:label>
					<xsl:value-of select="$baseUri"/>
				</rdfs:label>
			  </rdf:Description>
			<xsl:apply-templates/>		  
		</rdf:RDF>
	</xsl:template>

	<xsl:template match="response">
		<rdf:Description rdf:about="{$resourceURL}">
		  <rdf:type rdf:resource="&bibo;Document"/>
			  <xsl:apply-templates/>
		</rdf:Description>
		<xsl:for-each select="dataObject">
			<rdf:Description rdf:about="{vi:proxyIRI($baseUri, '', dataObjectID)}">
			  <rdf:type rdf:resource="{dataType}" />
				<opl:providedBy>
					<foaf:Organization rdf:about="{concat(agent/@homepage, '#this')}">
						<foaf:name><xsl:value-of select="agent"/></foaf:name>
						<foaf:homepage rdf:resource="{agent/@homepage}"/>
					</foaf:Organization>
				</opl:providedBy>
				<cc:License rdf:resource="{license}"/>
				<xsl:for-each select="mediaURL" >
					<foaf:depiction rdf:resource="{.}"/>
				</xsl:for-each>
				<xsl:for-each select="subject" >
					<dcterms:subject rdf:resource="{.}"/>
				</xsl:for-each>
			  <xsl:apply-templates />
			</rdf:Description>
		</xsl:for-each>
	</xsl:template>
	
  <xsl:template match="taxonConcept">
		<rdfs:label>
			<xsl:value-of select="dwc:scientificName"/>
		</rdfs:label>
		<foaf:name>
			<xsl:value-of select="dwc:scientificName"/>
		</foaf:name>
		<foaf:page rdf:resource="{concat('http://www.eol.org/pages/', taxonConceptID)}"/>
  </xsl:template>

  <xsl:template match="dataObject">
	<sioc:container_of rdf:resource="{vi:proxyIRI($baseUri, '', dataObjectID)}"/>
  </xsl:template>
  
    <xsl:template match="dc:*|dcterms:*">
        <xsl:copy-of select="." />
    </xsl:template>

  <xsl:template match="text()|@*" />
</xsl:stylesheet>
