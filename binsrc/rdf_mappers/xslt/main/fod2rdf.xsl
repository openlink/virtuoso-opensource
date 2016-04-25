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
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
]>

<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms="http://purl.org/dc/terms/"
    xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0"
    xmlns:oo="urn:oasis:names:tc:opendocument:xmlns:meta:1.0:"
    xmlns:bibo="&bibo;"
    xmlns:sioc="&sioc;"
    xmlns:foaf="&foaf;"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    >

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri"/>
    <xsl:variable name="resourceURL" select="vi:proxyIRI($baseUri)"/>
    <xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:template match="office:document-meta|office:meta" priority="1">
		<xsl:apply-templates select="*"/>
    </xsl:template>

    <xsl:template match="/office:document">
	<rdf:RDF>
	    <rdf:Description rdf:about="{$docproxyIRI}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<dc:title><xsl:value-of select="$baseUri"/></dc:title>
			<sioc:container_of rdf:resource="{$resourceURL}"/>
			<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			<dcterms:subject rdf:resource="{$resourceURL}"/>
			<owl:sameAs rdf:resource="{$docIRI}"/>
	    </rdf:Description>
	    <rdf:Description rdf:about="{$resourceURL}">
			<rdf:type rdf:resource="&bibo;Document"/>
			<xsl:apply-templates select="office:meta"/>
	    </rdf:Description>
	</rdf:RDF>
    </xsl:template>

    <xsl:template name="ns">
	<xsl:variable name="ns" select="namespace-uri(.)" />
	<xsl:choose>
	    <xsl:when test="starts-with ($ns, 'urn:') and not ends-with ($ns, ':')">
		<xsl:value-of select="$ns"/><xsl:text>:</xsl:text>
	    </xsl:when>
	    <xsl:otherwise>
		<xsl:value-of select="$ns"/>
	    </xsl:otherwise>
	</xsl:choose>
    </xsl:template>

    <xsl:template match="meta:document-statistic">
	<xsl:variable name="ns">
	    <xsl:call-template name="ns"/>
	</xsl:variable>
	<xsl:element name="{local-name(.)}" namespace="{$ns}">
	    <xsl:attribute name="rdf:parseType">Resource</xsl:attribute>
	    <xsl:for-each select="@*">
		<xsl:variable name="ns1">
		    <xsl:call-template name="ns"/>
		</xsl:variable>
		<xsl:element name="{local-name(.)}" namespace="{$ns1}">
		    <xsl:value-of select="."/>
		</xsl:element>
	    </xsl:for-each>
	</xsl:element>
    </xsl:template>

    <xsl:template match="meta:creation-date">
	<xsl:variable name="ns">
	    <xsl:call-template name="ns"/>
	</xsl:variable>
	<dcterms:created rdf:datatype="&xsd;dateTime">
		<xsl:value-of select="."/>
	</dcterms:created>
    </xsl:template>

	<xsl:template match="meta:generator">
	<xsl:variable name="ns">
	    <xsl:call-template name="ns"/>
	</xsl:variable>
	<xsl:element name="{local-name(.)}" namespace="{$ns}">
	    <xsl:value-of select="."/>
	</xsl:element>
    </xsl:template>

    <xsl:template match="meta:user-defined">
	<xsl:variable name="ns">
	    <xsl:call-template name="ns"/>
	</xsl:variable>
	<xsl:element name="{local-name(.)}" namespace="{$ns}">
	    <xsl:attribute name="rdf:parseType">Resource</xsl:attribute>
	    <rdfs:label>
		<xsl:value-of select="@meta:name"/>
	    </rdfs:label>
	    <dc:description>
		<xsl:value-of select="."/>
	    </dc:description>
	</xsl:element>
    </xsl:template>

<xsl:template match="*|text()"/>


</xsl:stylesheet>
