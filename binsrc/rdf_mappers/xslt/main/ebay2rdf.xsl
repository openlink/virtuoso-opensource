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
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY book "http://purl.org/NET/book/vocab#">
<!ENTITY cl "http://www.ebusiness-unibw.org/ontologies/consumerelectronics/v1#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY oplbb "http://www.openlinksw.com/schemas/bestbuy#">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:sioc="&sioc;"
    xmlns:gr="&gr;"
    xmlns:book="&book;"
    xmlns:dc="&dc;"
    xmlns:dcterms="&dcterms;"
    xmlns:rdfs="&rdfs;"
    xmlns:owl="&owl;"
    xmlns:cl="&cl;"
    xmlns:oplbb="&oplbb;"
    >

    <xsl:output method="xml" indent="yes" encoding="utf-8" />

    <xsl:param name="baseUri"/>
	<xsl:param name="currentDateTime"/>

    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:template match="/">
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
			    <rdfs:label><xsl:value-of select="concat('Offer of ', GetSingleItemResponse/Item/Title)"/></rdfs:label>
			    <gr:includes rdf:resource="{vi:proxyIRI ($baseUri, '', 'Product')}"/>
			    <gr:validFrom rdf:datatype="&xsd;dateTime"><xsl:value-of select="$currentDateTime"/></gr:validFrom>
			    <gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModePickup"/>
			    <gr:availableDeliveryMethods rdf:resource="&gr;UPS"/>
			    <gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModeMail"/>
			    <xsl:apply-templates mode="offering" />
			</gr:Offering>

	        <gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Vendor')}">
			  <rdfs:comment>The legal agent making the offering</rdfs:comment>
		          <rdfs:label>Ebay Co., Inc.</rdfs:label>
		          <gr:legalName>Ebay Co., Inc.</gr:legalName>
		          <gr:offers rdf:resource="{$resourceURL}"/>
			  <foaf:homepage rdf:resource="http://www.ebay.com" />
			  <owl:sameAs rdf:resource="http://www.ebay.com" />
			  <rdfs:seeAlso rdf:resource="{vi:proxyIRI ('http://www.ebay.com')}"/>
	        </gr:BusinessEntity>
	        
			<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', 'Product')}">
			    <rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder" />
			    <rdf:type rdf:resource="&oplbb;Product" />
                <gr:hasMakeAndModel>
	            <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', 'MakeAndModel')}">
	                <rdf:type rdf:resource="&gr;ProductOrServiceModel"/>
	                <rdf:type rdf:resource="&oplbb;Product"/>
				    <xsl:apply-templates select="GetSingleItemResponse/Item" mode="manufacturer" /> 
                 </rdf:Description>
               </gr:hasMakeAndModel>
               <xsl:choose>
					<xsl:when test="substring-before(GetSingleItemResponse/Item/PrimaryCategoryName, ':') = 'Books'">
						<rdf:type rdf:resource="&bibo;Book"/>
						<rdf:type rdf:resource="&book;Book"/>
						<xsl:apply-templates select="GetSingleItemResponse/Item" mode="bibo" />
					</xsl:when>
					<xsl:otherwise/>
				</xsl:choose>
			   <xsl:apply-templates select="GetSingleItemResponse/Item" />
			</rdf:Description>
		</rdf:RDF>
    </xsl:template>

    <xsl:template match="Item">
        <xsl:apply-templates select="*"/>
    </xsl:template>
    
    <xsl:template match="Item/ConvertedCurrentPrice" mode="offering">
		<gr:hasPriceSpecification>
		  <gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'ConvertedCurrentPrice')}">
			<rdfs:label>Converted Current Price</rdfs:label>
			<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>	
            <gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasCurrencyValue>
            <gr:hasCurrency rdf:datatype="&xsd;string"><xsl:value-of select="@currencyID"/></gr:hasCurrency>
          </gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template>
    
    <xsl:template match="Item/ViewItemURLForNaturalSearch">
    <xsl:if test="string-length(.) &gt; 0">
			<xsl:element namespace="&rdfs;" name="seeAlso">
	    <xsl:attribute name="rdf:resource">
		<xsl:value-of select="."/>
	    </xsl:attribute>
	</xsl:element>
	</xsl:if>
    </xsl:template>
    
    <xsl:template match="Item/Title">
	<rdfs:comment><xsl:value-of select="."/></rdfs:comment>
	<dc:title><xsl:value-of select="."/></dc:title>
    </xsl:template>
    <xsl:template match="Item/Description">
	<!--oplbb:description rdf:datatype="&xsd;string"><xsl:value-of select="."/></oplbb:description-->
	<oplbb:longDescription rdf:datatype="&xsd;string"><xsl:value-of select="."/></oplbb:longDescription>
    </xsl:template>
    <xsl:template match="Item/ItemId">
	<oplbb:productId><xsl:value-of select="."/></oplbb:productId>
    </xsl:template>
    <xsl:template match="Item/PrimaryCategoryName">
	<oplbb:category><xsl:value-of select="."/></oplbb:category>
    </xsl:template>
    <xsl:template match="Item/ItemSpecifics/NameValueList[Name='Format']">
	<oplbb:format rdf:datatype="&xsd;string"><xsl:value-of select="Value"/></oplbb:format>
    </xsl:template>
    <xsl:template match="Item/ItemSpecifics/NameValueList[Name='ISBN-13']">
	<gr:hasEAN_UCC-13><xsl:value-of select="Value"/></gr:hasEAN_UCC-13>
    </xsl:template>
    <xsl:template match="product/onSale">
	<oplbb:onSale rdf:datatype="&xsd;boolean"><xsl:value-of select="."/></oplbb:onSale>
    </xsl:template>
    <xsl:template match="Item/GalleryURL">
	<xsl:if test="string-length(.) &gt; 0">
	    <xsl:element namespace="&oplbb;" name="image">
		<xsl:attribute name="rdf:resource">
			<xsl:value-of select="."/>
		</xsl:attribute>
	    </xsl:element>
	</xsl:if>
    </xsl:template>
    <xsl:template match="Item/PictureURL">
	<xsl:if test="string-length(.) &gt; 0">
	    <xsl:element namespace="&oplbb;" name="image">
		<xsl:attribute name="rdf:resource">
			<xsl:value-of select="."/>
		</xsl:attribute>
	    </xsl:element>
	</xsl:if>
    </xsl:template>
    
    <xsl:template match="Item/ItemSpecifics/NameValueList[Name='Brand']" mode="manufacturer">
	<gr:hasManufacturer>
	    <gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Manufacturer')}">
		<rdfs:label>Manufacturer</rdfs:label>
		<gr:legalName><xsl:value-of select="Value"/></gr:legalName>
	    </gr:BusinessEntity>
	</gr:hasManufacturer>
    </xsl:template>
    
	<xsl:template match="Item/ItemSpecifics/NameValueList">
	<oplbb:detail>
	    <xsl:element namespace="&oplbb;" name="ProductDetail">
	        <xsl:attribute name='rdf:about'>
	            <xsl:value-of select="concat(vi:proxyIRI ($baseUri, '', 'Detail_'), position())"/>
		</xsl:attribute>
		<oplbb:detail_name rdf:datatype="&xsd;string"><xsl:value-of select="Name"/></oplbb:detail_name>
		<oplbb:detail_value rdf:datatype="&xsd;string">
			<xsl:variable name="val"/>
			<xsl:for-each select="Value">
				<xsl:choose>
					<xsl:when test="$val = ''">
						<xsl:variable name="val">
			<xsl:value-of select="."/>
						</xsl:variable>
					</xsl:when>
					<xsl:otherwise>
						<xsl:variable name="val">
							<xsl:value-of select="concat($val, ', ', .)"/>
						</xsl:variable>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:for-each>
			<xsl:value-of select="$val"/>
		</oplbb:detail_value>
	    </xsl:element>
	</oplbb:detail>
    </xsl:template>
    
    <xsl:template match="Item/Location">
		<gr:availableAtOrFrom>
			<xsl:value-of select="."/>
		</gr:availableAtOrFrom>
    </xsl:template>

    <xsl:template match="text()|@*"/>
    <xsl:template match="text()|@*" mode="offering" />
    <xsl:template match="text()|@*" mode="manufacturer" />
    <xsl:template match="text()|@*" mode="bibo" />

</xsl:stylesheet>
