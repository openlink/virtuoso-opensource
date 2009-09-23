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
<!ENTITY cl "http://www.ebusiness-unibw.org/ontologies/consumerelectronics/v1#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="&rdf;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:sioc="&sioc;"
    xmlns:dcterms="&dcterms;"
    xmlns:gr="&gr;"
    xmlns:bestbuy="http://remix.bestbuy.com/"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:cl="&cl;">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri"/>
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:variable name="ns">http://remix.bestbuy.com/</xsl:variable>

    <xsl:template match="products|product" priority="1">
	<xsl:apply-templates select="*"/>
    </xsl:template>

    <xsl:template match="/">
		<rdf:RDF>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
			</rdf:Description>
			<rdf:Description rdf:about="{$resourceURL}">
				<rdf:type rdf:resource="&gr;ProductOrService"/>
				<sioc:has_container rdf:resource="{$docproxyIRI}"/>
				<xsl:apply-templates/>
			</rdf:Description>
		</rdf:RDF>
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
    
    <xsl:template match="name">
		<rdfs:label>
			<xsl:value-of select="."/>
		</rdfs:label>
    </xsl:template>
    
    <xsl:template match="manufacturer">
		<gr:hasManufacturer>
	    <gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'manufacturer')}">
	    <rdfs:label><xsl:value-of select="concat('Manufacturer ', .)"/></rdfs:label>
            <gr:legalName><xsl:value-of select="."/></gr:legalName>
          </gr:BusinessEntity>
		</gr:hasManufacturer>
    </xsl:template>
    
    <xsl:template match="regularPrice">
		<gr:hasPriceSpecification>
	    <gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'regularPrice')}">
	    <rdfs:label><xsl:value-of select="concat('List Regular Price of ', ., ' USD')"/></rdfs:label>
            <gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasCurrencyValue>
            <gr:hasCurrency rdf:datatype="&xsd;string">USD</gr:hasCurrency>
          </gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template>
    
    <xsl:template match="salePrice">
	<gr:hasPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'salePrice')}">
	    <rdfs:label><xsl:value-of select="concat('List Sale Price of ', ., ' USD')"/></rdfs:label>
		  <gr:UnitPriceSpecification>
            <gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasCurrencyValue>
            <gr:hasCurrency rdf:datatype="&xsd;string">USD</gr:hasCurrency>
          </gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template>
    
    <xsl:template match="weight">
		<cl:hasWeight>
			<gr:QuantitativeValueFloat rdf:ID="Weight">
				<gr:hasUnitOfMeasurement rdf:datatype="http://www.w3.org/2001/XMLSchema#string">lb</gr:hasUnitOfMeasurement>
				<gr:hasValueFloat rdf:datatype="http://www.w3.org/2001/XMLSchema#float"><xsl:value-of select="."/></gr:hasValueFloat>
			</gr:QuantitativeValueFloat>
		</cl:hasWeight>
	</xsl:template>
	
	<xsl:template match="height">
		<cl:hasHeight>
			<gr:QuantitativeValueFloat rdf:ID="Height">
				<gr:hasUnitOfMeasurement rdf:datatype="http://www.w3.org/2001/XMLSchema#string">inches</gr:hasUnitOfMeasurement>
				<gr:hasValueFloat rdf:datatype="http://www.w3.org/2001/XMLSchema#float"><xsl:value-of select="."/></gr:hasValueFloat>
			</gr:QuantitativeValueFloat>
		</cl:hasHeight>
	</xsl:template>
	
	<xsl:template match="depth">
		<cl:hasDepth>
			<gr:QuantitativeValueFloat rdf:ID="Depth">
				<gr:hasUnitOfMeasurement rdf:datatype="http://www.w3.org/2001/XMLSchema#string">inches</gr:hasUnitOfMeasurement>
				<gr:hasValueFloat rdf:datatype="http://www.w3.org/2001/XMLSchema#float"><xsl:value-of select="."/></gr:hasValueFloat>
			</gr:QuantitativeValueFloat>
		</cl:hasDepth>
	</xsl:template>
	
	<xsl:template match="width">
		<cl:hasWidth>
			<gr:QuantitativeValueFloat rdf:ID="Width">
				<gr:hasUnitOfMeasurement rdf:datatype="http://www.w3.org/2001/XMLSchema#string">inches</gr:hasUnitOfMeasurement>
				<gr:hasValueFloat rdf:datatype="http://www.w3.org/2001/XMLSchema#float"><xsl:value-of select="."/></gr:hasValueFloat>
			</gr:QuantitativeValueFloat>
		</cl:hasWidth>
	</xsl:template>
	
    <xsl:template match="*[* and ../../*]">
		<xsl:if test="name() != 'details' and name() != 'detail'">
			<xsl:element namespace="{$ns}" name="{name()}">
				<xsl:attribute name="rdf:parseType">Resource</xsl:attribute>
				<xsl:apply-templates select="@*|node()"/>
			</xsl:element>
		</xsl:if>
		<xsl:if test="name() = 'details'">
			<xsl:apply-templates select="@*|node()"/>
		</xsl:if>
		<xsl:if test="name() = 'detail'">
			<xsl:choose>
				<xsl:when test="name[. = 'Digital Zoom']">
					<cl:hasDigitalZoomFactor>
						<gr:QuantitativeValueInteger rdf:ID="DigitalZoomNumber">
							<gr:hasValueInteger rdf:datatype="http://www.w3.org/2001/XMLSchema#int"><xsl:value-of select="value"/></gr:hasValueInteger>
						</gr:QuantitativeValueInteger>
					</cl:hasDigitalZoomFactor>
				</xsl:when>
				<xsl:when test="name[. = 'Optical Zoom']">
					<cl:hasOpticalZoomFactor>
						<gr:QuantitativeValueInteger rdf:ID="OpticalZoomNumber">
							<gr:hasValueInteger rdf:datatype="http://www.w3.org/2001/XMLSchema#int"><xsl:value-of select="value"/></gr:hasValueInteger>
						</gr:QuantitativeValueInteger>
					</cl:hasOpticalZoomFactor>
				</xsl:when>
				<xsl:when test="name[. = 'Aperture Range']">
					<cl:hasApertureRange>
						<gr:QuantitativeValueInteger rdf:ID="ApertureRangeNumber">
							<gr:hasValueInteger rdf:datatype="http://www.w3.org/2001/XMLSchema#int"><xsl:value-of select="value"/></gr:hasValueInteger>
						</gr:QuantitativeValueInteger>
					</cl:hasApertureRange>
				</xsl:when>
				<xsl:when test="name[. = 'LCD Screen Size']">
					<cl:hasDisplaySize>
						<gr:QuantitativeValueFloat rdf:ID="DisplaySize">
							<gr:hasUnitOfMeasurement rdf:datatype="http://www.w3.org/2001/XMLSchema#string">INH</gr:hasUnitOfMeasurement>
							<gr:hasValueFloat rdf:datatype="http://www.w3.org/2001/XMLSchema#float"><xsl:value-of select="value"/></gr:hasValueFloat>
						</gr:QuantitativeValueFloat>
					</cl:hasDisplaySize>
				</xsl:when>
				<xsl:when test="name[. = 'Imaging Sensor Size']">
					<cl:hasOpticalSensorSize>
						<gr:QuantitativeValueInteger rdf:ID="OpticalSensorSize">
							<gr:hasValueInteger rdf:datatype="http://www.w3.org/2001/XMLSchema#int"><xsl:value-of select="value"/></gr:hasValueInteger>
						</gr:QuantitativeValueInteger>
					</cl:hasOpticalSensorSize>
				</xsl:when>
				<xsl:when test="name[. = 'Self-Timer']">
					<cl:hasSelfTimer>
						<gr:QuantitativeValueFloat rdf:ID="SelfTimerTime">
							<gr:hasValueFloat rdf:datatype="http://www.w3.org/2001/XMLSchema#float"><xsl:value-of select="value"/></gr:hasValueFloat>
						</gr:QuantitativeValueFloat>
					</cl:hasSelfTimer>
				</xsl:when>
				<xsl:otherwise>
					<xsl:element namespace="{$ns}" name="{translate(name, ' ()', '')}">
						<xsl:value-of select="value"/>
					</xsl:element>
				</xsl:otherwise>
			</xsl:choose>	
		</xsl:if>
    </xsl:template>

    <xsl:template match="*">
    <xsl:if test="string-length(.) &gt; 0">
	<xsl:element namespace="{$ns}" name="{name()}">
	    <xsl:apply-templates select="@*|node()"/>
	</xsl:element>
	</xsl:if>
    </xsl:template>
    
</xsl:stylesheet>
