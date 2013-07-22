<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2013 OpenLink Software
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
	<!ENTITY bibo "http://purl.org/ontology/bibo/">
	<!ENTITY sioc "http://rdfs.org/sioc/ns#">
	<!ENTITY owl "http://www.w3.org/2002/07/owl#">
]>
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:skos="http://www.w3.org/2004/02/skos/core#"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
  xmlns:bibo="&bibo;"
  xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
  xmlns:ir="http://web-semantics.org/ns/image-regions"
  xmlns:dcterms="http://purl.org/dc/terms/"
  xmlns:cc="http://web.resource.org/cc/"
  xmlns:sioc="&sioc;"
  xmlns:owl="http://www.w3.org/2002/07/owl#"  
  version="1.0">
  <xsl:output method="xml" indent="yes"/>
  
  <xsl:param name="baseUri" />

    <xsl:variable name="resourceURL" select="vi:proxyIRI($baseUri)"/>
    <xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

  <xsl:template match="/">
	<rdf:Description rdf:about="{$docproxyIRI}">
		<rdf:type rdf:resource="&bibo;Document"/>
		<dc:title><xsl:value-of select="$baseUri"/></dc:title>
		<sioc:container_of rdf:resource="{$resourceURL}"/>
		<dcterms:subject rdf:resource="{$resourceURL}"/>
		<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
		<owl:sameAs rdf:resource="{$docIRI}"/>
	</rdf:Description>
	<rdf:Description rdf:about="{$resourceURL}">
		<rdf:type rdf:resource="&bibo;Document"/>
		<bibo:uri rdf:resource="{$baseUri}"/>
		<xsl:if test="svg/metadata/rdf:RDF/cc:Work">
			<xsl:copy-of select="/svg/metadata/rdf:RDF/cc:Work/*"/>
		</xsl:if>
    </rdf:Description>
    <xsl:if test="not svg/metadata/rdf:RDF/cc:Work">
		<xsl:copy-of select="/svg/metadata/rdf:RDF/*"/>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
