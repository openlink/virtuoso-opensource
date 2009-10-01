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
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY book "http://purl.org/NET/book/vocab#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:aws="http://soap.amazon.com/"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:sioc="&sioc;"
    xmlns:gr="&gr;"
    xmlns:book="&book;"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms="&dcterms;">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri" />
    <xsl:param name="asin" />
    <xsl:variable name="resourceURL">
		<xsl:value-of select="vi:proxyIRI (concat ('http://www.amazon.com/exec/obidos/ASIN/', $asin))"/>
    </xsl:variable>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:variable name="ns">http://soap.amazon.com/</xsl:variable>

    <xsl:template priority="1" match="OperationRequest|Request|TotalResults|TotalPages"/>

    <xsl:template match="ItemLookupResponse|ProductInfo|Details|AsinSearchRequestResponse|return" priority="1">
	<xsl:apply-templates select="*"/>
    </xsl:template>

    <xsl:template match="/">
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
		<rdf:type rdf:resource="&gr;ProductOrService"/>
		<rdfs:label><xsl:value-of select="//ItemAttributes/Title"/></rdfs:label>
		<xsl:choose>
		    <xsl:when test="//ProductGroup[ . = 'Book']">
			<rdf:type rdf:resource="&bibo;Book"/>
			<rdf:type rdf:resource="&book;Book"/>
			<xsl:apply-templates select="//ItemAttributes/*" mode="bibo"/>
			<xsl:apply-templates select="//OfferSummary/*" mode="bibo"/>
			<xsl:apply-templates select="//Offers/*" mode="bibo"/>
		    </xsl:when>
		    <xsl:otherwise>
			<xsl:apply-templates/>
		    </xsl:otherwise>
		</xsl:choose>
			<xsl:apply-templates select="//OfferSummary/*" mode="gr"/>
			<xsl:apply-templates select="//Offers/*" mode="gr"/>
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
	    <rdf:type rdf:resource="&gr;BusinessEntity"/>
	    <foaf:name><xsl:value-of select="."/></foaf:name>
		<xsl:variable name="sas-iri" select="vi:dbpIRI ('', translate (., ' ', '_'))"/>
		<xsl:if test="not starts-with ($sas-iri, '#')">
			<rdfs:seeAlso rdf:resource="{$sas-iri}"/>
		</xsl:if>
	    <bibo:role rdf:resource="&bibo;publisher"/>
    </dcterms:publisher>
    </xsl:template>

    <xsl:template match="LowestUsedPrice" mode="gr">
		<gr:hasPriceSpecification>
		  <gr:UnitPriceSpecification rdf:about="{vi:proxyIRI (concat ('http://www.amazon.com/exec/obidos/ASIN/', $asin), '', 'price')}">
	    <rdfs:label><xsl:value-of select="concat('List Price of ', Amount div 100, ' ', CurrencyCode)"/></rdfs:label>	
            <gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="Amount div 100"/></gr:hasCurrencyValue>
            <gr:hasCurrency rdf:datatype="&xsd;string"><xsl:value-of select="CurrencyCode"/></gr:hasCurrency>
			<gr:valueAddedTaxIncluded rdf:datatype="&xsd;boolean">true</gr:valueAddedTaxIncluded>
          </gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template>
    
    <xsl:template match="Manufacturer" mode="gr">
		<gr:hasManufacturer>
		  <gr:BusinessEntity rdf:about="{vi:proxyIRI (concat ('http://www.amazon.com/exec/obidos/ASIN/', $asin), '', 'manufacturer')}">
	    <rdfs:label><xsl:value-of select="concat('Manufacturer ', .)"/></rdfs:label>
            <gr:legalName><xsl:value-of select="."/></gr:legalName>
          </gr:BusinessEntity>
		</gr:hasManufacturer>
    </xsl:template>
    
    <xsl:template match="*" mode="bibo">
	<xsl:apply-templates select="self::*"/>
    </xsl:template>
    
    <xsl:template match="*" mode="gr">
	<xsl:apply-templates select="self::*"/>
    </xsl:template>
    
    <xsl:template match="*[starts-with(.,'http://') or starts-with(.,'urn:')]">
    <xsl:if test="string-length(.) &gt; 0">
	<xsl:element namespace="{$ns}" name="{name()}">
	    <xsl:attribute name="rdf:resource">
		<xsl:value-of select="vi:proxyIRI (.)"/>
	    </xsl:attribute>
	</xsl:element>
	</xsl:if>
    </xsl:template>

    <xsl:template match="*[* and ../../*]">
	<xsl:element namespace="{$ns}" name="{name()}">
	    <xsl:attribute name="rdf:parseType">Resource</xsl:attribute>
	    <xsl:apply-templates select="@*|node()"/>
	</xsl:element>
    </xsl:template>
    
    <xsl:template match="*">
    <xsl:if test="string-length(.) &gt; 0">
	<xsl:element namespace="{$ns}" name="{name()}">
	    <xsl:apply-templates select="@*|node()"/>
	</xsl:element>
	</xsl:if>
    </xsl:template>
    <xsl:template match="text()"/>
</xsl:stylesheet>
