<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE xsl:stylesheet [
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
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
    xmlns:rdf="&rdf;"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:aws="http://soap.amazon.com/"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:sioc="&sioc;"
    xmlns:dcterms="&dcterms;">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri" />
    <xsl:variable name="resourceURL">
	<xsl:value-of select="vi:proxyIRI (concat ('http://www.amazon.com/exec/obidos/ASIN/', //ASIN))"/>
    </xsl:variable>

    <xsl:variable name="ns">http://soap.amazon.com/</xsl:variable>

    <xsl:template priority="1" match="OperationRequest|Request|TotalResults|TotalPages"/>

    <xsl:template match="ItemLookupResponse|ProductInfo|Details|AsinSearchRequestResponse|return" priority="1">
	<xsl:apply-templates select="*"/>
    </xsl:template>

    <xsl:template match="/">
	<rdf:RDF>
	    <rdf:Description rdf:about="{$baseUri}">
		<rdf:type rdf:resource="&foaf;Document"/>
		<rdf:type rdf:resource="&bibo;Document"/>
		<rdf:type rdf:resource="&sioc;Container"/>
		<sioc:container_of rdf:resource="{$resourceURL}"/>
		<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
		<dcterms:subject rdf:resource="{$resourceURL}"/>
	    </rdf:Description>
	    <rdf:Description rdf:about="{$resourceURL}">
		<rdf:type rdf:resource="&sioc;Item"/>
		<rdfs:label><xsl:value-of select="//ItemAttributes/Title"/></rdfs:label>
		<xsl:choose>
		    <xsl:when test="//ProductGroup[ . = 'Book']">
			<rdf:type rdf:resource="&bibo;Book"/>
			<xsl:apply-templates select="//ItemAttributes/*" mode="bibo"/>
		    </xsl:when>
		    <xsl:otherwise>
		<xsl:apply-templates/>
		    </xsl:otherwise>
		</xsl:choose>
	    </rdf:Description>
	</rdf:RDF>
    </xsl:template>

    <!-- BIBO OWL -->
    <xsl:template match="Asin" mode="bibo">
	<bibo:asin><xsl:value-of select="."/></bibo:asin>
    </xsl:template>
    <xsl:template match="ProductName" mode="bibo">
	<bibo:shortTitle><xsl:value-of select="."/></bibo:shortTitle>
    </xsl:template>

    <xsl:template match="Author" mode="bibo">
        <dcterms:contributor rdf:parseType="Resource">
		<rdf:type rdf:resource="&foaf;Person"/>
		<foaf:name><xsl:value-of select="."/></foaf:name>
		<bibo:role rdf:resource="&bibo;author"/>
		<bibo:position><xsl:value-of select="position(.)"/></bibo:position>
        </dcterms:contributor>
    </xsl:template>

    <xsl:template match="Manufacturer" mode="bibo">
    <dcterms:publisher rdf:parseType="Resource">
	    <rdf:type rdf:resource="&foaf;Organization"/>
	    <foaf:name><xsl:value-of select="."/></foaf:name>
	    <bibo:role rdf:resource="&bibo;publisher"/>
    </dcterms:publisher>
    </xsl:template>

    <xsl:template match="*" mode="bibo">
	<xsl:apply-templates select="self::*"/>
    </xsl:template>

    <xsl:template match="*[starts-with(.,'http://') or starts-with(.,'urn:')]">
	<xsl:element namespace="{$ns}" name="{name()}">
	    <xsl:attribute name="rdf:resource">
		<xsl:value-of select="vi:proxyIRI (.)"/>
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
	<xsl:element namespace="{$ns}" name="{name()}">
	    <xsl:apply-templates select="@*|node()"/>
	</xsl:element>
    </xsl:template>
</xsl:stylesheet>
