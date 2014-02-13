<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2014 OpenLink Software
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
    xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
    xmlns:opl="http://www.openlinksw.com/schema/attribution#"
    version="1.0">

    <xsl:output method="xml" encoding="utf-8" indent="yes"/>

    <xsl:template match="/">
	<rdf:RDF>
	    <xsl:apply-templates/>
	</rdf:RDF>
    </xsl:template>

	<xsl:template match="a:entry" priority="2">
		<xsl:variable name="id2" select="vi:replace1(a:id)" />
		<rdf:Description rdf:about="{vi:docproxyIRI ($id2)}">
	    <rdf:type rdf:resource="&bibo;Document"/>
		    <xsl:choose>
			<xsl:when test="count(//a:entry) = 1">
			    <foaf:primaryTopic rdf:resource="{vi:proxyIRI ($id2)}"/>
			</xsl:when>
			<xsl:otherwise>
	    <foaf:topic rdf:resource="{vi:proxyIRI ($id2)}"/>
			</xsl:otherwise>
		    </xsl:choose>
	</rdf:Description>
	<rdf:Description rdf:about="{vi:proxyIRI ($id2)}">
	    <rdf:type rdf:resource="&sioc;Item"/>
	     <xsl:choose>
			<xsl:when test="string-length(a:title) &gt; 0">
				<rdfs:label><xsl:value-of select="a:title"/></rdfs:label>
	    <dc:title><xsl:value-of select="a:title"/></dc:title>
			</xsl:when>
			<xsl:otherwise>
				<rdfs:label><xsl:value-of select="a:id"/></rdfs:label>
			</xsl:otherwise>
		</xsl:choose>
	    <xsl:apply-templates select="g:*"/>
	    <xsl:apply-templates select="a:*"/>
			<xsl:for-each select="content/m:properties/d:*[. != '']">
			    <xsl:element name="{local-name(.)}" namespace="http://schemas.microsoft.com/ado/2007/08/dataservices/">
				<xsl:value-of select="."/>
			</xsl:element>
		</xsl:for-each>
			<xsl:if test="a:content/m:properties/d:longitude and a:content/m:properties/d:latitude">
			    <geo:lat><xsl:value-of select="a:content/m:properties/d:latitude"/></geo:lat>
			    <geo:long><xsl:value-of select="a:content/m:properties/d:longitude"/></geo:long>
			</xsl:if>
			<xsl:if test="a:content/m:properties/d:Longitude and a:content/m:properties/d:Latitude">
			    <geo:lat><xsl:value-of select="a:content/m:properties/d:Latitude"/></geo:lat>
			    <geo:long><xsl:value-of select="a:content/m:properties/d:Longitude"/></geo:long>
			</xsl:if>
	</rdf:Description>
    </xsl:template>

    <xsl:template match="a:entry[g:*]" priority="1">
	<rdf:Description rdf:about="{link[@rel='self']/@href}">
	    <rdf:type rdf:resource="&bibo;Document"/>
	    <foaf:topic rdf:resource="{vi:proxyIRI (link[@rel='self']/@href)}"/>
	</rdf:Description>
	<rdf:Description rdf:about="{vi:proxyIRI (link[@rel='self']/@href)}">
	    <rdf:type rdf:resource="&sioc;Item"/>
	    <dc:title><xsl:value-of select="a:title"/></dc:title>
	    <xsl:apply-templates select="g:*"/>
	    <xsl:apply-templates select="a:*"/>
	</rdf:Description>
    </xsl:template>

    <xsl:template match="a:content[not (m:properties)]">
	<dc:description><xsl:value-of select="."/></dc:description>
    </xsl:template>

    <xsl:template match="a:link[@rel != 'self']">
	<sioc:link rdf:resource="{@href}"/>
    </xsl:template>

    <xsl:template match="a:author">
		<xsl:if test="string-length(name) &gt; 0">
	<sioc:has_creator>
	    <xsl:variable name="agent">
					<xsl:choose>
					<xsl:when test="starts-with(parent::a:entry/a:id, 'http://')">
						<xsl:value-of select="vi:proxyIRI (parent::a:entry/a:id, '', name)"/>
					</xsl:when>
					<xsl:when test="parent::a:entry/link[@rel='self']">
		<xsl:value-of select="vi:proxyIRI (parent::a:entry/link[@rel='self']/@href,'',name)"/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="vi:proxyIRI (parent::a:entry/link/@href, '', name)"/>
					</xsl:otherwise>
					</xsl:choose>
	    </xsl:variable>
	    <rdf:Description rdf:about="{$agent}">
		<rdf:type rdf:resource="&foaf;Agent"/>
		<foaf:name><xsl:value-of select="name"/></foaf:name>
		<foaf:mbox rdf:resource="mailto:{email}"/>
				<opl:email_address_digest rdf:resource="{vi:di-uri (email)}"/>
	    </rdf:Description>
	</sioc:has_creator>
		</xsl:if>
    </xsl:template>

    <xsl:template match="a:published">
	<dcterms:created rdf:datatype="&xsd;dateTime"><xsl:value-of select="."/></dcterms:created>
    </xsl:template>

    <xsl:template match="a:updated">
	<dcterms:modified rdf:datatype="&xsd;dateTime"><xsl:value-of select="."/></dcterms:modified>
    </xsl:template>

    <xsl:template match="a:category">
    </xsl:template>

    <xsl:template match="g:*">
	<xsl:element name="{local-name(.)}" namespace="http://www.openlinksw.com/schemas/google-base#">
	    <xsl:value-of select="."/>
	</xsl:element>
    </xsl:template>
    <xsl:template match="text()" />
</xsl:stylesheet>
