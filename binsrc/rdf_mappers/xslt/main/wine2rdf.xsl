<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2014 OpenLink Software
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
<!ENTITY pto "http://www.productontology.org/id/">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY cl "http://www.ebusiness-unibw.org/ontologies/consumerelectronics/v1#">
<!ENTITY oplbb "http://www.openlinksw.com/schemas/bestbuy#">
<!ENTITY vcard "http://www.w3.org/2006/vcard/ns#">
<!ENTITY review "http:/www.purl.org/stuff/rev#"> 
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="&rdf;"
    xmlns:vcard="&vcard;"	
    xmlns:rdfs="&rdfs;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:sioc="&sioc;"
    xmlns:owl="&owl;"
    xmlns:opl="&opl;"
    xmlns:pto="&pto;" 
    xmlns:dcterms="&dcterms;"
    xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"  
    xmlns:review="&review;"    
    xmlns:gr="&gr;"
    xmlns:bestbuy="http://remix.bestbuy.com/"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:cl="&cl;"
    xmlns:oplbb="&oplbb;">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri"/>

    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:variable name="quote"><xsl:text>"</xsl:text></xsl:variable>

    <xsl:template match="/Catalog/Products/List">
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
                                 		<foaf:Organization rdf:about="http://www.wine.com#this">
                                 			<foaf:name>Wine.com</foaf:name>
                                 			<foaf:homepage rdf:resource="http://www.wine.com"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>

			    <sioc:has_container rdf:resource="{$docproxyIRI}"/>
			    <gr:hasBusinessFunction rdf:resource="&gr;Sell"/>
			    <rdfs:label><xsl:value-of select="Product/Name"/></rdfs:label>
			    <gr:includes rdf:resource="{vi:proxyIRI ($baseUri, '', 'Product')}"/>
			    <gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModePickup"/>
			    <gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModeMail"/>
			    <xsl:apply-templates mode="offering" />
			</gr:Offering>
            <gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Vendor')}">
                <rdfs:comment>The legal agent making the offering</rdfs:comment>
                <rdfs:label>Wine.com</rdfs:label>
                <gr:legalName>Wine.com</gr:legalName>
                <gr:offers rdf:resource="{$resourceURL}"/>
                <foaf:homepage rdf:resource="http://www.wine.com" />
                <rdfs:seeAlso rdf:resource="{vi:proxyIRI ('http://www.wine.com')}"/>
	        </gr:BusinessEntity>
			<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', 'Product')}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://www.wine.com#this">
                                 			<foaf:name>Wine.com</foaf:name>
                                 			<foaf:homepage rdf:resource="http://www.wine.com"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>

			    <rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder" />
			    <rdf:type rdf:resource="&oplbb;Product" />
                <gr:hasMakeAndModel>
                    <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', 'MakeAndModel')}">
                        <rdf:type rdf:resource="&gr;ProductOrServiceModel"/>
                        <rdf:type rdf:resource="&oplbb;Product"/>
                        <xsl:apply-templates select="Product" mode="manufacturer" /> 
                    </rdf:Description>
                </gr:hasMakeAndModel>
                <xsl:apply-templates select="Product" />
			</rdf:Description>
		</rdf:RDF>
    </xsl:template>

    <xsl:template match="Product">
        <xsl:apply-templates select="*"/>
    </xsl:template>

    <xsl:template match="Product/PriceMax" mode="offering">
        <gr:hasPriceSpecification>
            <gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'UnitPriceSpecification_Max')}">
                <rdfs:label>
		<xsl:value-of select="concat( ., ' (USD)')"/>	
		</rdfs:label>
                <gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
                <gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasCurrencyValue>
                <gr:hasCurrency rdf:datatype="&xsd;string">USD</gr:hasCurrency>
            </gr:UnitPriceSpecification>
        </gr:hasPriceSpecification>
    </xsl:template>

    <xsl:template match="Product/PriceMin" mode="offering">
        <gr:hasPriceSpecification>
            <gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'UnitPriceSpecification_Min')}">
                <rdfs:label>
		<xsl:value-of select="concat( ., ' (USD)')"/>	
		</rdfs:label>
                <gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
                <gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasCurrencyValue>
                <gr:hasCurrency rdf:datatype="&xsd;string">USD</gr:hasCurrency>
            </gr:UnitPriceSpecification>
        </gr:hasPriceSpecification>
    </xsl:template>

    <xsl:template match="Product/PriceRetail" mode="offering">
        <gr:hasPriceSpecification>
            <gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'UnitPriceSpecification_Retail')}">
                <rdfs:label>
		<xsl:value-of select="concat( ., ' (USD)')"/>	
		</rdfs:label>
                <gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
                <gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasCurrencyValue>
                <gr:hasCurrency rdf:datatype="&xsd;string">USD</gr:hasCurrency>
                <gr:priceType rdf:datatype="&xsd;string">suggested retail price</gr:priceType>
            </gr:UnitPriceSpecification>
        </gr:hasPriceSpecification>
    </xsl:template>

    <xsl:template match="Product/Name">
		<rdfs:label>
			<xsl:value-of select="."/>
		</rdfs:label>
		<gr:name>
			<xsl:value-of select="."/>
		</gr:name>
    </xsl:template>

    <xsl:template match="Product/Url">
        <xsl:if test="string-length(.) &gt; 0">
            <xsl:element namespace="&rdfs;" name="seeAlso">
                <xsl:attribute name="rdf:resource">
                    <xsl:value-of select="."/>
                </xsl:attribute>
            </xsl:element>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Product/Appellation">
        <xsl:if test="string-length(Name) &gt; 0">
		<rdf:type rdf:resource="{concat('&pto;', Name)}" />
        </xsl:if>
    </xsl:template>

    <xsl:template match="Product/Appellation" mode="manufacturer">
        <xsl:if test="string-length(Name) &gt; 0">
        <gr:hasManufacturer>
            <gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Manufacturer')}">
                <gr:legalName><xsl:value-of select="Name"/></gr:legalName>
                <rdfs:seeAlso rdf:resource="{Url}"/>
                <vcard:Region rdf:resource="{vi:dbpIRI('', Region/Name)}"/>
                <rdfs:seeAlso rdf:resource="{Region/Url}"/>
            </gr:BusinessEntity>
        </gr:hasManufacturer>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Product/Vineyard">
        <xsl:if test="string-length(Name) &gt; 0">
	<rdf:type rdf:resource="{concat('&pto;', Name)}" />
        </xsl:if>
    </xsl:template>

    <xsl:template match="Product/Vineyard" mode="manufacturer">
        <xsl:if test="string-length(Name) &gt; 0">
        <gr:hasManufacturer>
            <gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Manufacturer')}">
                <rdfs:label>Manufacturer</rdfs:label>
                <gr:legalName><xsl:value-of select="Name"/></gr:legalName>
                <rdfs:seeAlso rdf:resource="{Url}"/>
                <geo:lat rdf:datatype="&xsd;float">
                    <xsl:value-of select="GeoLocation/Latitude"/>
                </geo:lat>
                <geo:long rdf:datatype="&xsd;float">
                    <xsl:value-of select="GeoLocation/Longitude"/>
                </geo:long>
                <rdfs:seeAlso rdf:resource="{GeoLocation/Url}"/>
            </gr:BusinessEntity>
        </gr:hasManufacturer>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Product/ProductAttributes/ProductAttribute">
        <oplbb:detail>
            <xsl:element namespace="&oplbb;" name="ProductDetail">
                <xsl:attribute name='rdf:about'>
                    <xsl:value-of select="concat(vi:proxyIRI ($baseUri, '', 'Detail_'), position())"/>
                </xsl:attribute>
                <oplbb:detail_name rdf:datatype="&xsd;string"><xsl:value-of select="./Name"/></oplbb:detail_name>
                <oplbb:detail_value rdf:datatype="&xsd;string"><xsl:value-of select="./Id"/></oplbb:detail_value>
                <rdfs:seeAlso rdf:resource="{Url}"/>
            </xsl:element>
        </oplbb:detail>
    </xsl:template>
                
    <xsl:template match="Product/Labels/Label">
        <xsl:if test="string-length(.) &gt; 0">
            <xsl:element namespace="&oplbb;" name="image">
            <xsl:attribute name="rdf:resource">
                <xsl:value-of select="Url"/>
            </xsl:attribute>
            </xsl:element>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Product/GeoLocation">
        <!--geo:lat rdf:datatype="&xsd;float">
            <xsl:value-of select="Latitude"/>
        </geo:lat>
        <geo:long rdf:datatype="&xsd;float">
            <xsl:value-of select="Longitude"/>
        </geo:long-->
        <rdfs:seeAlso rdf:resource="{Url}"/>
    </xsl:template>

    <xsl:template match="Product/Varietal">
        <xsl:if test="string-length(Url) &gt; 0">
        <gr:isVariantOf>
            <oplbb:Product rdf:about="{vi:proxyIRI ($baseUri, '', 'Variant')}">
                <rdfs:label>Varietal</rdfs:label>
                    <xsl:if test="string-length(Name) &gt; 0">
                <gr:legalName><xsl:value-of select="Name"/></gr:legalName>
                    </xsl:if>
                    <xsl:if test="string-length(WineType/Name) &gt; 0">
                        <gr:category><xsl:value-of select="WineType/Name"/></gr:category>
                    </xsl:if>
					<foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', 'Vendor')}"/>
                <rdfs:seeAlso rdf:resource="{Url}"/>
                <rdfs:seeAlso rdf:resource="{WineType/Url}"/>
            </oplbb:Product>
        </gr:isVariantOf>
        </xsl:if>
    </xsl:template>
                
    <xsl:template match="Product/Ratings">
    	<review:rating><xsl:value-of select="."/></review:rating>
    </xsl:template>
                
    <xsl:template match="Product/Id">
        <oplbb:productId><xsl:value-of select="."/></oplbb:productId>
    </xsl:template>

    <xsl:template match="text()|@*"/>
    <xsl:template match="text()|@*" mode="offering" />
    <xsl:template match="text()|@*" mode="manufacturer" />

</xsl:stylesheet>
