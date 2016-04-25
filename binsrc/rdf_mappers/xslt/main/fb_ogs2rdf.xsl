<?xml version="1.0" encoding="UTF-8"?>
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
<!DOCTYPE xsl:stylesheet [
<!ENTITY rdfns  "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY xhv  "http://www.w3.org/1999/xhtml/vocab#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
<!ENTITY mo "http://purl.org/ontology/mo/">
<!ENTITY mmd "http://musicbrainz.org/ns/mmd-1.0#">
<!ENTITY og "http://opengraphprotocol.org/schema/">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
]>
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="&rdfns;"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms="http://purl.org/dc/terms/"
    xmlns:xhv="&xhv;"
    xmlns:sioc="&sioc;"
    xmlns:bibo="&bibo;"
    xmlns:sioct="&sioct;"
	xmlns:owl="&owl;"	
	xmlns:foaf="&foaf;"
    xmlns:mo="&mo;"
    xmlns:og="&og;"
    xmlns:mmd="&mmd;"
    version="1.0"
	>

	<xsl:param name="baseUri" />

	<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
	<xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
	<xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
	
	<xsl:output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" standalone="no" indent="yes" />

	<xsl:template match="/">
		<rdf:RDF>
           <rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<owl:sameAs rdf:resource="{$docIRI}"/>
		    </rdf:Description>
		    <rdf:Description rdf:about="{$resourceURL}">
                <xsl:if test="//id">
                    <og:id><xsl:value-of select="//id"/></og:id>
                </xsl:if>
                <xsl:if test="//picture">
                    <foaf:img rdf:resource="{//picture}"/>
                </xsl:if>
                <xsl:if test="//name">
    				<dc:title><xsl:value-of select="//name"/></dc:title>
                </xsl:if>
                <xsl:if test="//category">
                    <og:category><xsl:value-of select="//category"/></og:category>
                </xsl:if>
                <xsl:if test="//fan_count">
    				<og:fan_count><xsl:value-of select="//fan_count"/></og:fan_count>
                </xsl:if>
		    </rdf:Description>
		</rdf:RDF>
	</xsl:template>

    <xsl:template match="*|text()"/>

</xsl:stylesheet>
