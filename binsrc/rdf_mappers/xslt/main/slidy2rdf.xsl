<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2012 OpenLink Software
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
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:sioct="&sioct;"
    xmlns:sioc="&sioc;"
    xmlns:opl="&opl;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:dcterms="&dcterms;"
    xmlns:dc="&dc;"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    version="1.0">

    <xsl:output method="xml" indent="yes" />
    <xsl:param name="baseUri" />
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:template match="/">
	<rdf:RDF>
	    <xsl:if test="//html/head/script[contains(@src, 'slidy.js')]">
		<xsl:apply-templates select="html" />
	    </xsl:if>
	</rdf:RDF>
    </xsl:template>

    <xsl:template match="html">
	<rdf:Description rdf:about="{$docproxyIRI}">
	    <rdf:type rdf:resource="&bibo;Document"/>
	    <sioc:container_of rdf:resource="{$resourceURL}"/>
	    <foaf:primaryTopic rdf:resource="{$resourceURL}"/>
	    <dcterms:subject rdf:resource="{$resourceURL}"/>
	    <dc:title><xsl:value-of select="$baseUri"/></dc:title>
	    <owl:sameAs rdf:resource="{$docIRI}"/>
	</rdf:Description>
	<rdf:Description rdf:about="{$resourceURL}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.slidy.com#this">
                        			<foaf:name>Slidy</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.slidy.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

	    <rdfs:label>
		<xsl:value-of select="string (//html/head/title)"/>
	    </rdfs:label>
	    <rdf:type rdf:resource="&bibo;Slideshow"/>
	    <xsl:for-each select="//div[contains(@class, 'slide')]">
		<xsl:variable name="pos" select="position()"/>
		<dcterms:hasPart rdf:resource="{vi:proxyIRI ($baseUri,'', concat ('(',$pos,')'))}"/>
	    </xsl:for-each>
	</rdf:Description>
	<xsl:apply-templates select="body"/>
    </xsl:template>

    <xsl:template match="body">
	<xsl:for-each select="//div[contains(@class, 'slide')]">
	    <xsl:variable name="pos" select="position()"/>
	    <rdf:Description rdf:about="{vi:proxyIRI ($baseUri,'', concat ('(',$pos,')'))}">
		<rdf:type rdf:resource="&bibo;Slide"/>
		<dcterms:isPartOf rdf:resource="{$resourceURL}"/>
		<bibo:uri rdf:resource="{concat ($baseUri,'#(',$pos,')')}"/>
		<rdfs:label><xsl:value-of select="h1"/></rdfs:label>
		<bibo:content><xsl:call-template name="removeTags" /></bibo:content>
		<!--dc:description><xsl:value-of select="string (.)"/></dc:description>
		<sioc:content><xsl:value-of select="string (.)"/></sioc:content-->
		<xsl:for-each select=".//img[@src]">
		    <foaf:depiction rdf:resource="{@src}"/>
		</xsl:for-each>
	    </rdf:Description>
	</xsl:for-each>
    </xsl:template>

    <xsl:template match="*|text()"/>
    <xsl:template name="removeTags">
	<xsl:variable name="post" select="document-literal (., '', 2, 'UTF-8')"/>
	<xsl:value-of select="normalize-space(string($post))" />
    </xsl:template>

</xsl:stylesheet>
