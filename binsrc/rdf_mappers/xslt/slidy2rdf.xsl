<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2008 OpenLink Software
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
<!ENTITY xml 'http://www.w3.org/XML/1998/namespace#'>
<!ENTITY sioct 'http://rdfs.org/sioc/types#'>
<!ENTITY sioc 'http://rdfs.org/sioc/ns#'>
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
	xmlns:xsd="http://www.w3.org/2001/XMLSchema"
	xmlns:virt="http://www.openlinksw.com/virtuoso/xslt"
	xmlns:v="http://www.openlinksw.com/xsltext/"
	xmlns:sioct="&sioct;"
	xmlns:sioc="&sioc;"
	xmlns:foaf="&foaf;"
	xmlns:bibo="&bibo;"
	xmlns:dcterms="&dcterms;"
	version="1.0">

	<xsl:output method="xml" indent="yes" />
	<xsl:param name="baseUri" />
	<xsl:template match="/">
		<rdf:RDF>
			<xsl:if test="//html/head/script[contains(@src, 'slidy.js')]">
				<xsl:apply-templates select="html" />
			</xsl:if>
		</rdf:RDF>
	</xsl:template>

	<xsl:template match="html">
			<rdf:Description rdf:about="{$baseUri}">
				<rdfs:label>
					<xsl:value-of select="//html/head/title"/>
				</rdfs:label>
				<rdf:type rdf:resource="&bibo;Slideshow"/>
			</rdf:Description>
			<xsl:apply-templates select="body"/>
	</xsl:template>

	<xsl:template match="body">
		<xsl:for-each select="//div[contains(@class, 'slide')]">
			<xsl:variable name="pos" select="position()"/>
			<rdf:Description rdf:about="{$baseUri}">
				<xsl:attribute name="rdf:about">#(<xsl:value-of select="$pos"/>)</xsl:attribute>
				<rdf:type rdf:resource="&bibo;Slide"/>
				<dcterms:isPartOf rdf:resource="{$baseUri}"/>
				<bibo:uri>
					<xsl:attribute name="rdf:resource"><xsl:value-of select="$baseUri"/>#(<xsl:value-of select="$pos"/>)</xsl:attribute>
				</bibo:uri>
				<rdfs:label><xsl:value-of select="h1"/></rdfs:label>
				<bibo:content><xsl:value-of select="."/></bibo:content>
				<xsl:for-each select=".//img[@src]">
				    <foaf:depiction rdf:resource="{@src}"/>
				</xsl:for-each>
			</rdf:Description>
		</xsl:for-each>
	</xsl:template>

	<xsl:template match="*|text()"/>

</xsl:stylesheet>
