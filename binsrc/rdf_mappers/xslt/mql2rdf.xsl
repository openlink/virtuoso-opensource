<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE xsl:stylesheet [
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY xsd  "http://www.w3.org/2001/XMLSchema#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
]>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2006 OpenLink Software
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
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:sioc="&sioc;"
    xmlns:bibo="&bibo;"
    xmlns:foaf="&foaf;"
    xmlns:dct= "http://purl.org/dc/terms/"
    xmlns:mql="http://www.freebase.com/">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri" />

    <xsl:variable name="ns">http://www.freebase.com/</xsl:variable>

    <xsl:template match="/">
	<rdf:RDF>
	    <xsl:if test="/results/ROOT/result/*">
		<rdf:Description rdf:about="{$baseUri}">
		    <rdf:type rdf:resource="&foaf;Document"/>
		    <rdf:type rdf:resource="&bibo;Document"/>
		    <rdf:type rdf:resource="&sioc;Container"/>
		    <sioc:container_of rdf:resource="{vi:proxyIRI($baseUri)}"/>
		    <foaf:topic rdf:resource="{vi:proxyIRI($baseUri)}"/>
		    <dct:subject rdf:resource="{vi:proxyIRI($baseUri)}"/>
		</rdf:Description>
		<rdf:Description rdf:about="{vi:proxyIRI($baseUri)}">
		    <rdf:type rdf:resource="&foaf;Document"/>
		    <rdf:type rdf:resource="&bibo;Document"/>
		    <rdf:type rdf:resource="&sioc;Item"/>
		    <sioc:has_container rdf:resource="{$baseUri}"/>
		    <xsl:apply-templates select="/results/ROOT/result/*"/>
	    </rdf:Description>
	    </xsl:if>
	</rdf:RDF>
    </xsl:template>

    <xsl:template match="*[starts-with(.,'http://') or starts-with(.,'urn:')]">
	<xsl:element namespace="{$ns}" name="{name()}">
	    <xsl:attribute name="rdf:resource">
		<xsl:value-of select="vi:proxyIRI (.)"/>
	    </xsl:attribute>
	</xsl:element>
    </xsl:template>

    <xsl:template match="*[starts-with(.,'/')]">
	<xsl:if test="name () = 'type' and . like '%/person'">
	    <rdf:type rdf:resource="&foaf;Person"/>
	</xsl:if>
	<xsl:element namespace="{$ns}" name="{name()}">
	    <xsl:attribute name="rdf:resource">
		<xsl:value-of select="vi:proxyIRI()"/><xsl:value-of select="$ns"/>view<xsl:value-of select="."/>
	    </xsl:attribute>
	</xsl:element>
    </xsl:template>

    <xsl:template match="*[* and ../../*]">
	<xsl:element namespace="{$ns}" name="{name()}">
	    <xsl:attribute name="rdf:parseType">Resource</xsl:attribute>
	    <xsl:apply-templates select="@*|node()"/>
	</xsl:element>
    </xsl:template>

    <xsl:template match="*">
	<xsl:if test="* or . != ''">
	<xsl:element namespace="{$ns}" name="{name()}">
		<xsl:if test="name() like 'date_%'">
		    <xsl:attribute name="rdf:datatype">&xsd;dateTime</xsl:attribute>
		</xsl:if>
	    <xsl:apply-templates select="@*|node()"/>
	</xsl:element>
	</xsl:if>
    </xsl:template>
</xsl:stylesheet>
