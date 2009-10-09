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
    xmlns:oplbb="&oplbb;">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri" />
    <xsl:param name="asin" />
    <xsl:param name="currentDateTime"/>
    <xsl:variable name="resourceURL"><xsl:value-of select="vi:proxyIRI (concat ('http://www.amazon.com/exec/obidos/ASIN/', $asin))"/></xsl:variable>
    <xsl:variable name="base"><xsl:value-of select="concat ('http://www.amazon.com/exec/obidos/ASIN/', $asin)"/></xsl:variable>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:variable name="ns">http://soap.amazon.com/</xsl:variable>

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

			<gr:Offering rdf:about="{$resourceURL}">
			    <sioc:has_container rdf:resource="{$docproxyIRI}"/>
			    <gr:hasBusinessFunction rdf:resource="&gr;Sell"/>
			    <gr:includes rdf:resource="{vi:proxyIRI ($base, '', 'Product')}"/>
			    <gr:validFrom rdf:datatype="&xsd;dateTime"><xsl:value-of select="$currentDateTime"/></gr:validFrom>
			    <gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModePickup"/>
				<xsl:apply-templates select="//OfferSummary" mode="offering"/>
				<!--xsl:apply-templates select="//Offers" mode="offering"/-->
			</gr:Offering>

            <gr:BusinessEntity rdf:about="{vi:proxyIRI ($base, '', 'Vendor')}">
			  <rdfs:comment>The legal agent making the offering</rdfs:comment>
		      <rdfs:label>Amazon Co., Inc.</rdfs:label>
		      <gr:legalName>Amazon Co., Inc.</gr:legalName>
		      <gr:offers rdf:resource="{$resourceURL}"/>
			  <foaf:homepage rdf:resource="http://www.amazon.com" />
			  <!--owl:sameAs rdf:resource="www.amazon.com#amazon" /-->
			  <rdfs:seeAlso rdf:resource="{vi:proxyIRI ('http://www.amazon.com')}"/>
            </gr:BusinessEntity>
            
            <rdf:Description rdf:about="{vi:proxyIRI ($base, '', 'Product')}">
			    <rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder" />
			    <rdf:type rdf:resource="&oplbb;Product" />
                <gr:hasMakeAndModel>
					<rdf:Description rdf:about="{vi:proxyIRI ($base, '', 'MakeAndModel')}">
						<rdf:type rdf:resource="&gr;ProductOrServiceModel"/>
						<rdf:type rdf:resource="&oplbb;Product"/>
					    <xsl:apply-templates select="//ItemAttributes" mode="manufacturer" /> 
                    </rdf:Description>
                </gr:hasMakeAndModel>
		<xsl:choose>
		    <xsl:when test="//ProductGroup[ . = 'Book']">
			<rdf:type rdf:resource="&bibo;Book"/>
			<rdf:type rdf:resource="&book;Book"/>
						<!--xsl:apply-templates select="//ItemAttributes" mode="bibo" /-->
		    </xsl:when>
					<xsl:otherwise/>
		</xsl:choose>
				<xsl:apply-templates select="//ItemAttributes"/>
	    </rdf:Description>

		</rdf:RDF>
    </xsl:template>

    <xsl:template match="ItemAttributes">
        <xsl:apply-templates select="*"/>
    </xsl:template>

    <xsl:template match="OfferSummary/LowestUsedPrice" mode="offering">
		<gr:hasPriceSpecification>
		  <gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($base, '', 'LowestUsedPrice')}">
			<rdfs:label>Lowest Used Price</rdfs:label>
			<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>	
            <gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="Amount div 100"/></gr:hasCurrencyValue>
            <gr:hasCurrency rdf:datatype="&xsd;string"><xsl:value-of select="CurrencyCode"/></gr:hasCurrency>
          </gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template>

    <xsl:template match="OfferSummary/LowestNewPrice" mode="offering">
		<gr:hasPriceSpecification>
		  <gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($base, '', 'LowestNewPrice')}">
			<rdfs:label>Lowest New Price</rdfs:label>
			<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>	
            <gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="Amount div 100"/></gr:hasCurrencyValue>
            <gr:hasCurrency rdf:datatype="&xsd;string"><xsl:value-of select="CurrencyCode"/></gr:hasCurrency>
          </gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template>
    
    <xsl:template match="ItemAttributes/Manufacturer" mode="manufacturer">
		<gr:hasManufacturer>
			<gr:BusinessEntity rdf:about="{vi:proxyIRI ($base, '', 'Manufacturer')}">
				<rdfs:label>Manufacturer</rdfs:label>
            <gr:legalName><xsl:value-of select="."/></gr:legalName>
          </gr:BusinessEntity>
		</gr:hasManufacturer>
    </xsl:template>
    
    <xsl:template match="ItemAttributes/ASIN">
	<oplbb:productId><xsl:value-of select="."/></oplbb:productId>
    </xsl:template>
    <xsl:template match="ItemAttributes/Title">
	<rdfs:comment><xsl:value-of select="."/></rdfs:comment>
	<dc:title><xsl:value-of select="."/></dc:title>
    </xsl:template>
    <xsl:template match="ItemAttributes/description">
	<oplbb:description rdf:datatype="&xsd;string"><xsl:value-of select="."/></oplbb:description>
    </xsl:template>
    <xsl:template match="ItemAttributes/longDescription">
	<oplbb:longDescription rdf:datatype="&xsd;string"><xsl:value-of select="."/></oplbb:longDescription>
    </xsl:template>
    <xsl:template match="ItemAttributes/EAN">
	<gr:hasEAN_UCC-13><xsl:value-of select="."/></gr:hasEAN_UCC-13>
    </xsl:template>
    <xsl:template match="ItemAttributes/PublicationDate">
	<oplbb:dateReleased rdf:datatype="&xsd;date"><xsl:value-of select="."/></oplbb:dateReleased>
    </xsl:template>
    <xsl:template match="ItemAttributes/sku">
	<oplbb:sku><xsl:value-of select="."/></oplbb:sku>
	<gr:hasStockKeepingUnit><xsl:value-of select="."/></gr:hasStockKeepingUnit>
    </xsl:template>
    <xsl:template match="ItemAttributes/onSale">
	<oplbb:onSale rdf:datatype="&xsd;boolean"><xsl:value-of select="."/></oplbb:onSale>
    </xsl:template>
    <xsl:template match="ItemAttributes/color">
	<oplbb:color rdf:datatype="&xsd;string"><xsl:value-of select="."/></oplbb:color>
    </xsl:template>
    <xsl:template match="ItemAttributes/format">
	<oplbb:format rdf:datatype="&xsd;string"><xsl:value-of select="."/></oplbb:format>
    </xsl:template>
    <xsl:template match="ItemAttributes/ProductGroup">
	<oplbb:category><xsl:value-of select="."/></oplbb:category>
    </xsl:template>
    <xsl:template match="ItemAttributes/image">
    <xsl:if test="string-length(.) &gt; 0">
	    <xsl:element namespace="&oplbb;" name="image">
	    <xsl:attribute name="rdf:resource">
		    <xsl:value-of select="."/>
	    </xsl:attribute>
	</xsl:element>
	</xsl:if>
    </xsl:template>

        <xsl:template match="ItemAttributes/details/detail">
	<oplbb:detail>
	    <xsl:element namespace="&oplbb;" name="ProductDetail">
	        <xsl:attribute name='rdf:about'>
	            <xsl:value-of select="concat(vi:proxyIRI ($base, '', 'Detail_'), position())"/>
		</xsl:attribute>
		<oplbb:detail_name rdf:datatype="&xsd;string"><xsl:value-of select="./name"/></oplbb:detail_name>
		<oplbb:detail_value rdf:datatype="&xsd;string"><xsl:value-of select="./value"/></oplbb:detail_value>
	</xsl:element>
	</oplbb:detail>
    </xsl:template>
    
    <xsl:template match="ItemAttributes/PackageDimensions/Weight">
	<oplbb:weight>
	  <gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($base, '', 'Weight')}">
	        <gr:hasValueFloat rdf:datatype="&xsd;float">
	          <xsl:value-of select="."/>
			</gr:hasValueFloat>
			<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">
				<xsl:value-of select="@Units"/>
			</gr:hasUnitOfMeasurement>
	  </gr:QuantitativeValueFloat>
	</oplbb:weight> 
    </xsl:template>

    <xsl:template match="ItemAttributes/PackageDimensions/shippingWeight">
        <oplbb:shippingWeight>
	  <gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($base, '', 'ShippingWeight')}">
	    <xsl:choose>
	      <xsl:when test="contains(. , 'lb')">
	        <gr:hasValueFloat rdf:datatype="&xsd;float">
	          <xsl:value-of select="normalize-space(substring-before(., 'lb'))"/>
		</gr:hasValueFloat>
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">LBR</gr:hasUnitOfMeasurement>
	      </xsl:when>
	      <xsl:when test="contains(. , 'oz')">
	        <gr:hasValueFloat rdf:datatype="&xsd;float">
	          <xsl:value-of select="normalize-space(substring-before(., 'oz'))"/>
		</gr:hasValueFloat>
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">ONZ</gr:hasUnitOfMeasurement>
	      </xsl:when>
	      <xsl:otherwise>
	        <gr:hasValueFloat rdf:datatype="&xsd;float">
	          <xsl:value-of select="."/>
		</gr:hasValueFloat>
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">LBR</gr:hasUnitOfMeasurement>
	      </xsl:otherwise>
	    </xsl:choose>
	  </gr:QuantitativeValueFloat>
	</oplbb:shippingWeight> 
    </xsl:template>

    <xsl:template match="ItemAttributes/PackageDimensions/Height">
		<oplbb:height>
		<gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($base, '', 'Height')}">
				<gr:hasValueFloat rdf:datatype="&xsd;float">
				<xsl:value-of select="."/>
				</gr:hasValueFloat>
				<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">
					<xsl:value-of select="@Units"/>
				</gr:hasUnitOfMeasurement>
		</gr:QuantitativeValueFloat>
		</oplbb:height> 
    </xsl:template>

    <xsl:template match="ItemAttributes/PackageDimensions/Length">
	<oplbb:depth>
		<gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($base, '', 'Length')}">
				<gr:hasValueFloat rdf:datatype="&xsd;float">
				<xsl:value-of select="."/>
				</gr:hasValueFloat>
				<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">
					<xsl:value-of select="@Units"/>
				</gr:hasUnitOfMeasurement>
		</gr:QuantitativeValueFloat>
	</oplbb:depth> 
    </xsl:template>

    <xsl:template match="ItemAttributes/PackageDimensions/Width">
	<oplbb:width>
		<gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($base, '', 'Width')}">
				<gr:hasValueFloat rdf:datatype="&xsd;float">
				<xsl:value-of select="."/>
				</gr:hasValueFloat>
				<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">
					<xsl:value-of select="@Units"/>
				</gr:hasUnitOfMeasurement>
		</gr:QuantitativeValueFloat>
	</oplbb:width> 
    </xsl:template>

    <!-- BIBO OWL -->
    <!--xsl:template match="ItemAttributes/ASIN" mode="bibo">
		<bibo:asin><xsl:value-of select="."/></bibo:asin>
    </xsl:template-->
    
    
    <!--xsl:template match="ItemAttributes/Author" mode="bibo">
        <dcterms:contributor rdf:parseType="Resource">
			<rdf:type rdf:resource="&foaf;Person"/>
		<foaf:name><xsl:value-of select="."/></foaf:name>
		<bibo:role rdf:resource="&bibo;author"/>
		<bibo:position><xsl:value-of select="position(.)"/></bibo:position>
        </dcterms:contributor>
    </xsl:template-->
    
    <xsl:template match="text()|@*"/>
    <xsl:template match="text()|@*" mode="offering" />
    <xsl:template match="text()|@*" mode="manufacturer" />

</xsl:stylesheet>
