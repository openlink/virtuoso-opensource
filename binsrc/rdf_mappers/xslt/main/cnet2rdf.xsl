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
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:sioc="&sioc;"
    xmlns:gr="&gr;"
    xmlns:book="&book;"
    xmlns:dcterms="&dcterms;"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns="http://api.cnet.com/rest/v1.0/ns">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri" />
    
    <xsl:variable name="ns">http://api.cnet.com/rest/v1.0/ns</xsl:variable>

    <xsl:template match="CNETResponse|TechProduct" priority="1">
		<xsl:apply-templates select="*"/>
    </xsl:template>
    
    <xsl:template match="CNETResponse|SoftwareProduct" priority="1">
		<xsl:apply-templates select="*"/>
    </xsl:template>
    
    <xsl:variable name="error" select="/CNETResponse/Error/@code" />
    
    <xsl:template match="/">
		<rdf:RDF>
			<xsl:choose>
				<xsl:when test="string-length(/CNETResponse/Error/@code) &gt; 0">
					<rdf:Description rdf:about="{$baseUri}">
						<rdf:type rdf:resource="&bibo;Document"/>
					</rdf:Description>
				</xsl:when>
				<xsl:otherwise>
					<rdf:Description rdf:about="{$baseUri}">
						<rdf:type rdf:resource="&bibo;Document"/>
						<sioc:container_of rdf:resource="{vi:proxyIRI($baseUri)}"/>
						<foaf:primaryTopic rdf:resource="{vi:proxyIRI($baseUri)}"/>
						<dcterms:subject rdf:resource="{vi:proxyIRI($baseUri)}"/>
					</rdf:Description>
					<rdf:Description rdf:about="{vi:proxyIRI($baseUri)}">
						<rdf:type rdf:resource="&gr;ProductOrService"/>
						<sioc:has_container rdf:resource="{$baseUri}"/>
						<xsl:apply-templates />
					</rdf:Description>
				</xsl:otherwise>
			</xsl:choose>
		</rdf:RDF>
    </xsl:template>
    
    <xsl:template match="Name">
		<rdfs:label>
			<xsl:value-of select="."/>
		</rdfs:label>
		<dc:title>
			<xsl:value-of select="."/>
		</dc:title>
    </xsl:template>
    
    <xsl:template match="Publisher">
		<gr:hasManufacturer>
		  <gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'publisher')}">
	    <rdfs:label><xsl:value-of select="concat('Publisher ', Name)"/></rdfs:label>
            <gr:legalName><xsl:value-of select="Name"/></gr:legalName>
            <id><xsl:value-of select="@id"/></id>
          </gr:BusinessEntity>
		</gr:hasManufacturer>
    </xsl:template>
	
	<xsl:template match="Manufacturer">
		<gr:hasManufacturer>
		  <gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'manufacturer')}">
	    <rdfs:label><xsl:value-of select="concat('Manufacturer ', Name)"/></rdfs:label>
            <gr:legalName><xsl:value-of select="Name"/></gr:legalName>
            <id><xsl:value-of select="@id"/></id>
          </gr:BusinessEntity>
		</gr:hasManufacturer>
    </xsl:template>
    <xsl:template match="PublishDate">
		<dcterms:created>
			<xsl:value-of select="."/>
		</dcterms:created>
    </xsl:template>
    
    <xsl:template match="Specs">
		<dc:description>
			<xsl:value-of select="string(.)"/>
		</dc:description>
    </xsl:template>
    <xsl:template match="Description">
		<dc:description>
			<xsl:value-of select="string(.)"/>
		</dc:description>
    </xsl:template>
    
    <xsl:template match="Price">
		<gr:hasPriceSpecification>
		  <gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'price')}">
	    <rdfs:label><xsl:value-of select="concat('List Price of ', ., ' USD')"/></rdfs:label>
            <gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasCurrencyValue>
            <gr:hasCurrency rdf:datatype="&xsd;string">USD</gr:hasCurrency>
			<gr:valueAddedTaxIncluded rdf:datatype="&xsd;boolean">true</gr:valueAddedTaxIncluded>
          </gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template>
    <xsl:template match="LowPrice">
		<gr:hasPriceSpecification>
		  <gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'lowPrice')}">
	    <rdfs:label><xsl:value-of select="concat('List Low Price of ', ., ' USD')"/></rdfs:label>
            <gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasCurrencyValue>
            <gr:hasCurrency rdf:datatype="&xsd;string">USD</gr:hasCurrency>
			<gr:valueAddedTaxIncluded rdf:datatype="&xsd;boolean">true</gr:valueAddedTaxIncluded>
          </gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template>
    
    <xsl:template match="HighPrice">
		<gr:hasPriceSpecification>
		  <gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'highPrice')}">
	    <rdfs:label><xsl:value-of select="concat('List High Price of ', ., ' USD')"/></rdfs:label>
            <gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasCurrencyValue>
            <gr:hasCurrency rdf:datatype="&xsd;string">USD</gr:hasCurrency>
			<gr:valueAddedTaxIncluded rdf:datatype="&xsd;boolean">true</gr:valueAddedTaxIncluded>
          </gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template>


    <xsl:template match="ImageURL">
		<foaf:img rdf:resource="{.}"/>
    </xsl:template>
    <xsl:template match="LinkURL">
		<bibo:link rdf:resource="{.}"/>
    </xsl:template>
    <xsl:template match="PriceURL">
		<rdfs:seeAlso rdf:resource="{.}"/>
    </xsl:template>
	<xsl:template match="ReviewURL">
		<rdfs:seeAlso rdf:resource="{.}"/>
    </xsl:template>

        <xsl:template match="*[starts-with(.,'http://') or starts-with(.,'urn:')]">
    <xsl:if test="string-length(.) &gt; 0">
		<xsl:element namespace="{$ns}" name="{name()}">
			<xsl:attribute name="rdf:resource">
			<xsl:value-of select="."/>
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
    

</xsl:stylesheet>
