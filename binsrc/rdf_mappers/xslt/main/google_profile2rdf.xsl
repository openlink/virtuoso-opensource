<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2009 OpenLink Software
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
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rss "http://purl.org/rss/1.0/">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY m "http://schemas.microsoft.com/ado/2007/08/dataservices/metadata">
<!ENTITY d "http://schemas.microsoft.com/ado/2007/08/dataservices">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:dc="&dc;"
    xmlns:dcterms="&dcterms;"
    xmlns:a="http://www.w3.org/2005/Atom"
	xmlns:cv="http://purl.org/captsolo/resume-rdf/0.2/cv#"
    xmlns:sioc="&sioc;"
    xmlns:bibo="&bibo;"
    xmlns:foaf="&foaf;"
    xmlns:g="http://base.google.com/ns/1.0"
    xmlns:gb="http://www.openlinksw.com/schemas/google-base#"
    xmlns:virtrdf="http://www.openlinksw.com/schemas/virtrdf#"
    xmlns:batch="http://schemas.google.com/gdata/batch"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:m="&m;"
    xmlns:d="&d;"
    xmlns:owl="http://www.w3.org/2002/07/owl#"	
    xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
    version="1.0">

	<xsl:output method="xml" encoding="utf-8" indent="yes"/>
	
	<xsl:param name="baseUri" />
	
	<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
	<xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
	<xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
	
	<xsl:template match="/">
		<rdf:RDF>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<dc:title>
					<xsl:value-of select="$baseUri"/>
				</dc:title>
				<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>
			<xsl:apply-templates/>
		</rdf:RDF>
	</xsl:template>

	<xsl:template match="entry">
		<rdf:Description rdf:about="{$resourceURL}">
			<rdf:type rdf:resource="&foaf;Person"/>
			<rdfs:label>
				<xsl:value-of select="displayName"/>
			</rdfs:label>
			<foaf:name>
				<xsl:value-of select="displayName"/>
			</foaf:name>
			<dc:description>
				<xsl:value-of select="aboutMe" />
			</dc:description>
			<sioc:link rdf:resource="{profileUrl}" />			
			<foaf:depiction rdf:resource="{thumbnailUrl}"/>			
			<xsl:for-each select="urls">
				<rdfs:seeAlso rdf:resource="{value}"/>
			</xsl:for-each>
			<xsl:for-each select="photos">
				<foaf:depiction rdf:resource="{value}"/>
			</xsl:for-each>
			<xsl:for-each select="organizations">
				<cv:employedIn>
					<cv:Company>
						<xsl:attribute name="rdf:about">
							<xsl:value-of select="vi:proxyIRI($baseUri, '', name )" />
						</xsl:attribute>
						<cv:Name>
							<xsl:value-of select="name" />
						</cv:Name>
						<cv:jobTitle>
							<xsl:value-of select="title"/>
						</cv:jobTitle>
						<cv:jobType>
							<xsl:value-of select="type"/>
						</cv:jobType>
					</cv:Company>
				</cv:employedIn>
			</xsl:for-each>
		</rdf:Description>
	</xsl:template>

	<xsl:template match="text()" />
</xsl:stylesheet>
