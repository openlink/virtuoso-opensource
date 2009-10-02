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
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY cl "http://www.ebusiness-unibw.org/ontologies/consumerelectronics/v1#">
<!ENTITY oplbb "http://www.openlinksw.com/schemas/bestbuy/">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:sioc="&sioc;"
    xmlns:dcterms="&dcterms;"
    xmlns:gr="&gr;"
    xmlns:bestbuy="http://remix.bestbuy.com/"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:cl="&cl;"
    xmlns:oplbb="&oplbb;">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri"/>
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:variable name="ns">http://www.openlinksw.com/schemas/bestbuy/</xsl:variable>

    <xsl:template match="/">
		<rdf:RDF>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>

			<gr:Offering rdf:about="{$resourceURL}">
				<sioc:has_container rdf:resource="{$docproxyIRI}"/>
			    <gr:hasBusinessFunction rdf:resource="&gr;Sell"/>
			    <gr:includes rdf:resource="{vi:proxyIRI ($baseUri, '', 'Product')}"/>
			    <gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModePickup"/>
			    <gr:availableDeliveryMethods rdf:resource="&gr;UPS"/>
			    <gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModeMail"/>
			    <xsl:apply-templates mode="offering" />
			</gr:Offering>

			<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', 'Product')}">
			    <rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder" />
			    <rdf:type rdf:resource="&oplbb;Product" />
                            <gr:hasMakeAndModel>
	                        <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', 'MakeAndModel')}">
	                            <rdf:type rdf:resource="&gr;ProductOrServiceModel"/>
	                            <rdf:type rdf:resource="&oplbb;Product"/>
				    <xsl:apply-templates select="products/product" mode="manufacturer" /> 
		                   <!-- TO DO
		                   <rdfs:comment>!!#{manufacturer} #{modelNumber}</rdfs:comment>
		                   -->
			</rdf:Description>
	                   </gr:hasMakeAndModel>

			   <xsl:apply-templates select="products/product" />
			</rdf:Description>

		</rdf:RDF>
    </xsl:template>

    <xsl:template match="product">
        <xsl:apply-templates select="*"/>
    </xsl:template>

    <xsl:template match="regularPrice" mode="offering">
	<gr:hasPriceSpecification>
	    <gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'UnitPriceSpecification')}">
	        <rdfs:label>sale price</rdfs:label>
		<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
		<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasCurrencyValue>
		<gr:hasCurrency rdf:datatype="&xsd;string">USD</gr:hasCurrency>
		<!-- Absence of gr:priceType property indicates this is the actual sale price not, say, a suggested retail price (SRP) -->
	    </gr:UnitPriceSpecification>
	</gr:hasPriceSpecification>
    </xsl:template>

    <xsl:template match="salePrice" mode="offering">
        <gr:hasPriceSpecification>
	    <gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'UnitPriceSpecification_SRP')}">
	        <rdfs:label>suggested retail price</rdfs:label>
		<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
	        <gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasCurrencyValue>
	        <gr:hasCurrency rdf:datatype="&xsd;string">USD</gr:hasCurrency>
	        <gr:priceType rdf:datatype="&xsd;string">suggested retail price</gr:priceType>
	    </gr:UnitPriceSpecification>
	</gr:hasPriceSpecification>
    </xsl:template>

    <xsl:template match="shippingCost" mode="offering">
        <gr:hasPriceSpecification>
	    <gr:DeliveryChargeSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'DeliveryChargeSpecification')}">
	        <rdfs:label>shipping charge</rdfs:label>
		<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
	        <gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasCurrencyValue>
	        <gr:hasCurrency rdf:datatype="&xsd;string">USD</gr:hasCurrency>
	    </gr:DeliveryChargeSpecification>
	</gr:hasPriceSpecification>
    </xsl:template>

    <xsl:template match="product/name">
	<rdfs:label>
	    <xsl:value-of select="."/>
	</rdfs:label>
    </xsl:template>

    <xsl:template match="product/url">
    <xsl:if test="string-length(.) &gt; 0">
	    <xsl:element namespace="&rdfs;" name="seeAlso">
			<xsl:attribute name="rdf:resource">
			<xsl:value-of select="."/>
			</xsl:attribute>
		</xsl:element>
    </xsl:if>
    </xsl:template>
    
    <xsl:template match="product/shortDescription">
	<rdfs:comment><xsl:value-of select="."/></rdfs:comment>
    </xsl:template>
    <xsl:template match="product/description">
	<oplbb:description rdf:datatype="&xsd;string"><xsl:value-of select="."/></oplbb:description>
    </xsl:template>
    <xsl:template match="product/longDescription">
	<oplbb:longDescription rdf:datatype="&xsd;string"><xsl:value-of select="."/></oplbb:longDescription>
    </xsl:template>
    <xsl:template match="product/upc">
	<gr:hasEAN_UCC-13><xsl:value-of select="concat('0', .)"/></gr:hasEAN_UCC-13>
    </xsl:template>
    <xsl:template match="product/startDate">
	<oplbb:dateReleased rdf:datatype="&xsd;date"><xsl:value-of select="."/></oplbb:dateReleased>
    </xsl:template>
    <xsl:template match="product/productId">
	<oplbb:productId><xsl:value-of select="."/></oplbb:productId>
    </xsl:template>
    <xsl:template match="product/sku">
	<oplbb:sku><xsl:value-of select="."/></oplbb:sku>
    </xsl:template>
    <xsl:template match="product/onSale">
	<oplbb:onSale rdf:datatype="&xsd;boolean"><xsl:value-of select="."/></oplbb:onSale>
    </xsl:template>
    <xsl:template match="product/color">
	<oplbb:color rdf:datatype="&xsd;string"><xsl:value-of select="."/></oplbb:color>
    </xsl:template>
    <xsl:template match="product/format">
	<oplbb:format rdf:datatype="&xsd;string"><xsl:value-of select="."/></oplbb:format>
    </xsl:template>
    <xsl:template match="product/onlineAvailability">
	<oplbb:onlineAvailability rdf:datatype="&xsd;boolean"><xsl:value-of select="."/></oplbb:onlineAvailability>
    </xsl:template>
    <xsl:template match="product/onlineAvailabilityText">
	<oplbb:onlineAvailabilityText rdf:datatype="&xsd;string"><xsl:value-of select="."/></oplbb:onlineAvailabilityText>
    </xsl:template>
    <xsl:template match="product/specialOrder">
	<oplbb:specialOrder rdf:datatype="&xsd;boolean"><xsl:value-of select="."/></oplbb:specialOrder>
    </xsl:template>
    <xsl:template match="product/freeShipping">
	<oplbb:freeShipping rdf:datatype="&xsd;boolean"><xsl:value-of select="."/></oplbb:freeShipping>
    </xsl:template>
    <xsl:template match="product/categoryPath/category/name">
	<oplbb:category><xsl:value-of select="."/></oplbb:category>
    </xsl:template>
    <xsl:template match="product/image">
	<xsl:if test="string-length(.) &gt; 0">
	    <xsl:element namespace="&oplbb;" name="image">
		<xsl:attribute name="rdf:resource">
			<xsl:value-of select="."/>
		</xsl:attribute>
	    </xsl:element>
	</xsl:if>
    </xsl:template>
    
    <xsl:template match="product/manufacturer" mode="manufacturer">
		<gr:hasManufacturer>
	    <gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Manufacturer')}">
		<rdfs:label>Manufacturer</rdfs:label>
            <gr:legalName><xsl:value-of select="."/></gr:legalName>
          </gr:BusinessEntity>
		</gr:hasManufacturer>
    </xsl:template>
    
    <xsl:template match="product/details/detail">
	<oplbb:detail>
	    <xsl:element namespace="&oplbb;" name="ProductDetail">
	        <xsl:attribute name='rdf:about'>
	            <xsl:value-of select="concat(vi:proxyIRI ($baseUri, '', 'Detail_'), position())"/>
		</xsl:attribute>
		<oplbb:detail_name rdf:datatype="&xsd;string"><xsl:value-of select="./name"/></oplbb:detail_name>
		<oplbb:detail_value rdf:datatype="&xsd;string"><xsl:value-of select="./value"/></oplbb:detail_value>
	    </xsl:element>
	</oplbb:detail>
    </xsl:template>
    
    <xsl:template match="product/dollarSavings">
	<oplbb:dollarSaving>
	    <gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($baseUri, '', 'DollarSaving')}">
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">USD</gr:hasUnitOfMeasurement>
		<gr:hasValueFloat rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasValueFloat>
	    </gr:QuantitativeValueFloat>
	</oplbb:dollarSaving> 
    </xsl:template>
    
    <xsl:template match="product/weight">
	<oplbb:weight> <!-- or cl:hasWeight -->
	    <gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($baseUri, '', 'Weight')}">
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">LBR</gr:hasUnitOfMeasurement>
		<!-- TO DO: Need to parse out any unit included in BestBuy product description -->
		<gr:hasValueFloat rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasValueFloat>
			</gr:QuantitativeValueFloat>
	</oplbb:weight> 
	</xsl:template>
	
    <xsl:template match="product/shippingWeight">
	<oplbb:shippingWeight> <!-- or cl:??? -->
	    <gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($baseUri, '', 'ShippingWeight')}">
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">LBR</gr:hasUnitOfMeasurement>
		<!-- TO DO: Need to parse out any unit included in BestBuy product description -->
		<gr:hasValueFloat rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasValueFloat>
			</gr:QuantitativeValueFloat>
	</oplbb:shippingWeight> 
	</xsl:template>
	
    <xsl:template match="product/height">
	<oplbb:height> <!-- or cl:hasHeight -->
	    <gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($baseUri, '', 'Height')}">
                <!-- TO DO: UN/CEFACT 3-digit code for inches? -->
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">inches</gr:hasUnitOfMeasurement>
		<!-- TO DO: Need to parse out any unit included in BestBuy product description -->
		<gr:hasValueFloat rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasValueFloat>
			</gr:QuantitativeValueFloat>
	</oplbb:height> 
	</xsl:template>
	
    <xsl:template match="product/depth">
	<oplbb:depth> <!-- or cl:hasDepth -->
	    <gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($baseUri, '', 'Depth')}">
                <!-- TO DO: UN/CEFACT 3-digit code for inches? -->
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">inches</gr:hasUnitOfMeasurement>
		<!-- TO DO: Need to parse out any unit included in BestBuy product description -->
		<gr:hasValueFloat rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasValueFloat>
			</gr:QuantitativeValueFloat>
	</oplbb:depth> 
	</xsl:template>
	
    <xsl:template match="product/width">
	<oplbb:width> <!-- or cl:hasWidth -->
	    <gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($baseUri, '', 'Width')}">
                <!-- TO DO: UN/CEFACT 3-digit code for inches? -->
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">inches</gr:hasUnitOfMeasurement>
		<!-- TO DO: Need to parse out any unit included in BestBuy product description -->
		<gr:hasValueFloat rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasValueFloat>
	    </gr:QuantitativeValueFloat>
	</oplbb:width> 
    </xsl:template>

    <xsl:template match="text()|@*"/>
    <xsl:template match="text()|@*" mode="offering" />
    <xsl:template match="text()|@*" mode="manufacturer" />
    
</xsl:stylesheet>
