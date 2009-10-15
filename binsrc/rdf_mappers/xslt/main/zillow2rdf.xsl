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
<!ENTITY realdf "http://gr8c.org/realdf/ns#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="&rdf;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:sioc="&sioc;"
    xmlns:dcterms="&dcterms;"
    xmlns:gr="&gr;"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:ebay="urn:ebay:apis:eBLBaseComponents"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:SearchResults="http://www.zillow.com/static/xsd/SearchResults.xsd"
    xmlns:realdf="&realdf;"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:zillow="http://www.zillow.com/">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri"/>
    <xsl:param name="currentDateTime"/>

    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:variable name="ns">http://www.zillow.com/</xsl:variable>
    <xsl:variable name="uc">ABCDEFGHIJKLMNOPQRSTUVWXYZ </xsl:variable>
    <xsl:variable name="lc">abcdefghijklmnopqrstuvwxyz_</xsl:variable>
    
    <xsl:template match="/SearchResults:searchresults">
		<rdf:RDF>
		
	    <rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<dc:title><xsl:value-of select="$baseUri"/></dc:title>
		<sioc:container_of rdf:resource="{$resourceURL}"/>
		<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', 'Vendor')}"/>
				<foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', 'Product')}"/>
		<dcterms:subject rdf:resource="{$resourceURL}"/>
		<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>

			<gr:Offering rdf:about="{$resourceURL}">
			    <sioc:has_container rdf:resource="{$docproxyIRI}"/>
			    <gr:hasBusinessFunction rdf:resource="&gr;Sell"/>
			    <rdfs:label><xsl:value-of select="concat('Offer of ', request/address, ' ', request/citystatezip)"/></rdfs:label>
			    <gr:includes rdf:resource="{vi:proxyIRI ($baseUri, '', 'Product')}"/>
			    <gr:validFrom rdf:datatype="&xsd;dateTime"><xsl:value-of select="$currentDateTime"/></gr:validFrom>
				<xsl:apply-templates select="response/results/result" mode="offering"/>
			</gr:Offering>

            <gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Vendor')}">
			  <rdfs:comment>The legal agent making the offering</rdfs:comment>
		      <rdfs:label>Zillow Co., Inc.</rdfs:label>
		      <gr:legalName>Zillow Co., Inc.</gr:legalName>
		      <gr:offers rdf:resource="{$resourceURL}"/>
			  <foaf:homepage rdf:resource="http://www.zollow.com" />
			  <rdfs:seeAlso rdf:resource="{vi:proxyIRI ('http://www.zillow.com')}"/>
            </gr:BusinessEntity>
            
            <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', 'Product')}">
			    <rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder" />
			    <rdf:type rdf:resource="&oplbb;Product" />
				<rdf:type rdf:resource="&realdf;Residential"/>
				<realdf:world>Earth</realdf:world>
				<gr:amountOfThisGood>1</gr:amountOfThisGood>
				<xsl:apply-templates select="response/results/result" />
			</rdf:Description>

		</rdf:RDF>
    </xsl:template>
    
    <xsl:template match="links">
		<rdfs:seeAlso rdf:resource="{homedetails}"/>
		<rdfs:seeAlso rdf:resource="{graphsanddata}"/>
		<rdfs:seeAlso rdf:resource="{mapthishome}"/>
		<rdfs:seeAlso rdf:resource="{myestimator}"/>
		<rdfs:seeAlso rdf:resource="{comparables}"/>
    </xsl:template>

    <xsl:template match="address">
		<realdf:street>
			<xsl:value-of select="street"/>
		</realdf:street>
		<realdf:postalCode>
			<xsl:value-of select="zipcode"/>
		</realdf:postalCode>
		<realdf:country rdf:resource="http://dbpedia.org/resource/United_States"/>
		<realdf:city rdf:resource="{vi:dbpIRI ('', city)}"/>
		<realdf:state rdf:resource="{vi:dbpIRI ('', translate (state, $lc, $uc))}"/>
		<realdf:longitude>
			<xsl:value-of select="longitude"/>
		</realdf:longitude>
		<realdf:latitude>
			<xsl:value-of select="latitude"/>
		</realdf:latitude>
    </xsl:template>

    <xsl:template match="yearBuilt">
		<realdf:yearBuilt>
			<xsl:value-of select="."/>
		</realdf:yearBuilt>
    </xsl:template>
    
    <xsl:template match="taxAssessment">
		<realdf:taxes>
			<xsl:value-of select="."/>
		</realdf:taxes>
    </xsl:template>
    
    <xsl:template match="lotSizeSqFt">
		<realdf:squareFeet>
			<xsl:value-of select="."/>
		</realdf:squareFeet>
    </xsl:template>
    
    <xsl:template match="bathrooms">
		<realdf:baths>
			<xsl:value-of select="."/>
		</realdf:baths>
    </xsl:template>
    
    <xsl:template match="bedrooms">
		<realdf:beds>
			<xsl:value-of select="."/>
		</realdf:beds>
    </xsl:template>
    
    <xsl:template match="localRealEstate" />

    <xsl:template match="lastSoldPrice" mode="offering">
		<xsl:variable name="amount" select="." />
		<realdf:price>
			<xsl:value-of select="$amount"/>
		</realdf:price>
		<gr:hasPriceSpecification>
			<gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'LastSoldPrice')}">
			<rdfs:label>Last Sold Price</rdfs:label>
			<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
            <gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="$amount"/></gr:hasCurrencyValue>
			<gr:hasCurrency rdf:datatype="&xsd;string"><xsl:value-of select="@currency"/></gr:hasCurrency>
          </gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template>
        
    <xsl:template match="text()|@*"/>
    <xsl:template match="text()|@*" mode="offering" />

</xsl:stylesheet>
