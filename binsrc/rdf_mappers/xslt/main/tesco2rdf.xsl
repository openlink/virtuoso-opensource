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
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY pto "http://www.productontology.org/id/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY oplbb "http://www.openlinksw.com/schemas/bestbuy#">
<!ENTITY opltesco "http://www.openlinksw.com/schemas/tesco#"> 
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="&rdf;"
    xmlns:foaf="&foaf;"
    xmlns:pto="&pto;" 
    xmlns:bibo="&bibo;"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:sioc="&sioc;"
    xmlns:opl="&opl;"
    xmlns:dcterms="&dcterms;"
    xmlns:gr="&gr;"
    xmlns:oplbb="&oplbb;"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:opltesco="&opltesco;">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri"/>

    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:variable name="ns">http://www.openlinksw.com/schemas/tesco#</xsl:variable>

    <xsl:template match="results|Products" priority="1">
		<xsl:apply-templates select="*"/>
    </xsl:template>

    <xsl:template match="/">
		<xsl:if test="results/StatusCode='0'">
		<rdf:RDF>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
					<sioc:container_of rdf:resource="{vi:proxyIRI ($baseUri, '', 'Product')}"/>
					<foaf:primaryTopic rdf:resource="{vi:proxyIRI ($baseUri, '', 'Product')}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
					<foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', 'Vendor')}"/>
				<dc:title><xsl:value-of select="$baseUri"/></dc:title>
				<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>
				<gr:Offering rdf:about="{$resourceURL}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://www.tesco.com#this">
                                 			<foaf:name>Tesco</foaf:name>
                                 			<foaf:homepage rdf:resource="http://www.tesco.com"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>

					<sioc:has_container rdf:resource="{$docproxyIRI}"/>
					<gr:hasBusinessFunction rdf:resource="&gr;Sell"/>
					<rdfs:label><xsl:value-of select="//Name"/></rdfs:label>
					<gr:includes rdf:resource="{vi:proxyIRI ($baseUri, '', 'Product')}"/>
					<gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModePickup"/>
                    <gr:eligibleRegions>US</gr:eligibleRegions>
					<xsl:apply-templates mode="offering"/>
				</gr:Offering>
				<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', 'Product')}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://www.tesco.com#this">
                                 			<foaf:name>Tesco</foaf:name>
                                 			<foaf:homepage rdf:resource="http://www.tesco.com"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>

					<rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder" />
					<rdf:type rdf:resource="&oplbb;Product" />
				<sioc:has_container rdf:resource="{$docproxyIRI}"/>
				<xsl:apply-templates/>
			</rdf:Description>
				<gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Vendor')}">
					<rdfs:comment>Tesco PLC</rdfs:comment>
					<rdfs:label>Tesco PLC</rdfs:label>
					<gr:legalName>Tesco PLC</gr:legalName>
					<gr:offers rdf:resource="{$resourceURL}"/>
					<foaf:homepage rdf:resource="http://www.tesco.com" />
					<rdfs:seeAlso rdf:resource="{vi:proxyIRI ('http://www.tesco.com')}"/>
                    <foaf:depiction rdf:resource="http://www.tesco.com/shopping/images/logoTesco.gif"/>
				</gr:BusinessEntity>
		</rdf:RDF>
		</xsl:if>
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

    <xsl:template match="Name">
		<rdfs:label>
			<xsl:value-of select="."/>
		</rdfs:label>
		<gr:name>
			<xsl:value-of select="."/>
		</gr:name>
    </xsl:template>

    <xsl:template match="manufacturer">
	<rdf:type rdf:resource="{concat('&pto;', .)}" />
		<gr:hasManufacturer>
		  <gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Manufacturer')}">
	    <rdfs:label><xsl:value-of select="concat('Manufacturer ', .)"/></rdfs:label>
            <gr:legalName><xsl:value-of select="."/></gr:legalName>
          </gr:BusinessEntity>
		</gr:hasManufacturer>
    </xsl:template>

    <xsl:template match="Price" mode="offering">
		<gr:hasPriceSpecification>
		  <gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'price')}">
            <rdfs:label><xsl:value-of select="concat('Price of ', ., ' GBP')"/></rdfs:label>
            <gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasCurrencyValue>
            <gr:hasCurrency rdf:datatype="&xsd;string">GBP</gr:hasCurrency>
          </gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template>

    <!--xsl:template match="Price">
		<gr:hasPriceSpecification>
		  <gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'price')}">
            <rdfs:label><xsl:value-of select="concat('Price of ', ., ' GBP')"/></rdfs:label>
            <gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasCurrencyValue>
            <gr:hasCurrency rdf:datatype="&xsd;string">GBP</gr:hasCurrency>
          </gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template-->
    
    <!--xsl:template match="PriceDescription">
		<gr:hasPriceSpecification>
		  <gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'price')}">
            <rdfs:label><xsl:value-of select="."/></rdfs:label>
          </gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template-->

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

    <xsl:template match="text()|@*" mode="offering" />
    
</xsl:stylesheet>
