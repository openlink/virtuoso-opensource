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
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY vcard "http://www.w3.org/2001/vcard-rdf/3.0#">
<!ENTITY pto "http://www.productontology.org/id/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY cl "http://www.ebusiness-unibw.org/ontologies/consumerelectronics/v1#">
<!ENTITY oplbb "http://www.openlinksw.com/schemas/bestbuy#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:vcard="&vcard;"	
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:foaf="&foaf;"
    xmlns:pto="&pto;" 
    xmlns:bibo="&bibo;"
    xmlns:sioc="&sioc;"
    xmlns:owl="&owl;"
    xmlns:dcterms="&dcterms;"
    xmlns:gr="&gr;"
    xmlns:bestbuy="http://remix.bestbuy.com/"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:cl="&cl;"
    xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"	
    xmlns:opl="&opl;"
    xmlns:oplbb="&oplbb;">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri"/>
    <xsl:param name="currentDateTime"/>

	<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri, '', 'Offering')"/>
    <xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:variable name="quote"><xsl:text>"</xsl:text></xsl:variable>

    <xsl:template match="/results">
		<rdf:RDF>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<sioc:container_of rdf:resource="{vi:proxyIRI ($baseUri, '', 'Product')}"/>
				<foaf:primaryTopic rdf:resource="{vi:proxyIRI ($baseUri, '', 'Product')}"/>
				<foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', 'Vendor')}"/>
				<foaf:topic rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{vi:proxyIRI ($baseUri, '', 'Product')}"/>
			</rdf:Description>

			<gr:Offering rdf:about="{$resourceURL}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://www.zappos.com#this">
                                 			<foaf:name>Zappos</foaf:name>
                                 			<foaf:homepage rdf:resource="http://www.zappos.com"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>

				<sioc:has_container rdf:resource="{$docproxyIRI}"/>
				<gr:hasBusinessFunction rdf:resource="&gr;Sell"/>
				<rdfs:label><xsl:value-of select="concat('Offer: ', product/productName)"/></rdfs:label>
				<gr:includes rdf:resource="{vi:proxyIRI ($baseUri, '', 'Product')}"/>
				<gr:validFrom rdf:datatype="&xsd;dateTime"><xsl:value-of select="$currentDateTime"/></gr:validFrom>
				<gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModePickup"/>
				<gr:availableDeliveryMethods rdf:resource="&gr;UPS"/>
				<gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModeMail"/>
				<xsl:apply-templates select="product" mode="offering" />
			</gr:Offering>

			<gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Vendor')}">
				<rdfs:label>Zappos.com</rdfs:label>
				<gr:legalName>Zappos.com</gr:legalName>
				<gr:offers rdf:resource="{$resourceURL}"/>
				<foaf:homepage rdf:resource="http://www.zappos.com" />
				<rdfs:seeAlso rdf:resource="{vi:proxyIRI ('http://www.zappos.com')}"/>
			</gr:BusinessEntity>

			<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', 'Product')}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://www.zappos.com#this">
                                 			<foaf:name>Zappos</foaf:name>
                                 			<foaf:homepage rdf:resource="http://www.zappos.com"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>
				<rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder" />
				<rdf:type rdf:resource="&oplbb;Product" />
				<gr:hasMakeAndModel>
					<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', 'MakeAndModel')}">
						<rdf:type rdf:resource="&gr;ProductOrServiceModel"/>
						<rdf:type rdf:resource="&oplbb;Product"/>
						<xsl:apply-templates select="product" mode="manufacturer" /> 
				   </rdf:Description>
				</gr:hasMakeAndModel>
				<xsl:apply-templates select="product" />
			</rdf:Description>
		</rdf:RDF>
    </xsl:template>

    <xsl:template match="product">
        <xsl:apply-templates select="*"/>
    </xsl:template>

    <xsl:template match="product" mode="offering">
		<xsl:for-each select="styles/price">
			<gr:hasPriceSpecification>
				<gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', concat('Price', ../styleId))}">
					<rdfs:label>
						<xsl:value-of select="concat(substring-after(., '$'), ' (USD)')"/>	
					</rdfs:label>
					<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
					<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="substring-after(., '$')"/></gr:hasCurrencyValue>
					<gr:hasCurrency rdf:datatype="&xsd;string">USD</gr:hasCurrency>
					<gr:priceType rdf:datatype="&xsd;string">regular price</gr:priceType>
				</gr:UnitPriceSpecification>
			</gr:hasPriceSpecification>
		</xsl:for-each>
		<xsl:for-each select="styles/originalPrice">
			<gr:hasPriceSpecification>
				<gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', concat('OriginalPrice', ../styleId))}">
					<rdfs:label>
						<xsl:value-of select="concat(substring-after(., '$'), ' (USD)')"/>	
					</rdfs:label>
					<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
					<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="substring-after(., '$')"/></gr:hasCurrencyValue>
					<gr:hasCurrency rdf:datatype="&xsd;string">USD</gr:hasCurrency>
					<gr:priceType rdf:datatype="&xsd;string">original price</gr:priceType>
				</gr:UnitPriceSpecification>
			</gr:hasPriceSpecification>
		</xsl:for-each>
    </xsl:template>

    <xsl:template match="product/productName">
		<rdfs:label>
			<xsl:value-of select="."/>
		</rdfs:label>
		<gr:name>
			<xsl:value-of select="."/>
		</gr:name>
    </xsl:template>

    <xsl:template match="product/defaultProductUrl">
		<xsl:if test="string-length(.) &gt; 0">
			<xsl:element namespace="&rdfs;" name="seeAlso">
				<xsl:attribute name="rdf:resource">
					<xsl:value-of select="."/>
				</xsl:attribute>
			</xsl:element>
		</xsl:if>
    </xsl:template>

    <xsl:template match="product/description">
		<oplbb:description rdf:datatype="&xsd;string"><xsl:value-of select="."/></oplbb:description>
		<xsl:variable name="local_text" select="vi:convert_to_xtree(string(.))"/>
		<xsl:for-each select="$local_text//li">
			<oplbb:feature rdf:datatype="&xsd;string">
				<xsl:value-of select="."/>
			</oplbb:feature>
		</xsl:for-each>
    </xsl:template>

    <xsl:template match="product/productId">
		<oplbb:productId><xsl:value-of select="."/></oplbb:productId>
		<oplbb:sku><xsl:value-of select="."/></oplbb:sku>
		<gr:hasStockKeepingUnit><xsl:value-of select="."/></gr:hasStockKeepingUnit>
    </xsl:template>

    <xsl:template match="product/onSale">
		<oplbb:onSale rdf:datatype="&xsd;boolean"><xsl:value-of select="'1'"/></oplbb:onSale>
    </xsl:template>

    <xsl:template match="product/styles/color">
		<oplbb:color rdf:datatype="&xsd;string"><xsl:value-of select="."/></oplbb:color>
    </xsl:template>
	
    <xsl:template match="product/defaultImageUrl">
		<xsl:if test="string-length(.) &gt; 0">
			<xsl:element namespace="&oplbb;" name="image">
			<xsl:attribute name="rdf:resource">
				<xsl:value-of select="."/>
			</xsl:attribute>
			</xsl:element>
		</xsl:if>
    </xsl:template>

    <xsl:template match="product/brandName" mode="manufacturer">
		<gr:hasManufacturer>
			<gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Manufacturer')}">
				<rdfs:label>
					<xsl:value-of select="."/>	
				</rdfs:label>
				<gr:legalName>
					<xsl:value-of select="."/>
				</gr:legalName>
			</gr:BusinessEntity>
		</gr:hasManufacturer>
    </xsl:template>

    <xsl:template match="text()|@*"/>
    <xsl:template match="text()|@*" mode="offering" />
    <xsl:template match="text()|@*" mode="manufacturer" />

</xsl:stylesheet>
