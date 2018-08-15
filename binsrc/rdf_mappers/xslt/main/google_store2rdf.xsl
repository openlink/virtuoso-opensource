<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2018 OpenLink Software
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
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY cl "http://www.ebusiness-unibw.org/ontologies/consumerelectronics/v1#">
<!ENTITY oplbb "http://www.openlinksw.com/schemas/bestbuy#">
<!ENTITY review "http://purl.org/stuff/rev#"> 
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:sioc="&sioc;"
    xmlns:owl="&owl;"
	xmlns:s="http://www.google.com/shopping/api/schemas/2010"
    xmlns:pto="&pto;" 
    xmlns:dcterms="&dcterms;"
    xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"  
    xmlns:review="&review;"    
    xmlns:gr="&gr;"
    xmlns:opl="&opl;"
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

    <xsl:template match="/feed">
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
                        		<foaf:Organization rdf:about="http://www.google.com#this">
                        			<foaf:name>Google Store</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.google.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

			    <sioc:has_container rdf:resource="{$docproxyIRI}"/>
			    <gr:hasBusinessFunction rdf:resource="&gr;Sell"/>
			    <rdfs:label><xsl:value-of select="entry[1]/title"/></rdfs:label>
			    <gr:includes rdf:resource="{vi:proxyIRI ($baseUri, '', 'Product')}"/>
			    <gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModePickup"/>
			    <gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModeMail"/>
			    <xsl:apply-templates select="entry[1]" mode="offering" />
			</gr:Offering>
            <gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Vendor')}">
                <rdfs:comment>Google Store</rdfs:comment>
                <rdfs:label>Google Store</rdfs:label>
                <gr:legalName>Google Store</gr:legalName>
                <gr:offers rdf:resource="{$resourceURL}"/>
                <foaf:homepage rdf:resource="http://www.google.com" />
                <rdfs:seeAlso rdf:resource="{vi:proxyIRI ('http://www.google.com')}"/>
				<foaf:depiction rdf:resource="http://www.googlestore.com/images/googlestore_logo.gif"/>
	        </gr:BusinessEntity>
			<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', 'Product')}">
			    <rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder" />
			    <rdf:type rdf:resource="&oplbb;Product" />
                <!--gr:hasMakeAndModel>
                    <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', 'MakeAndModel')}">
                        <rdf:type rdf:resource="&gr;ProductOrServiceModel"/>
                        <rdf:type rdf:resource="&oplbb;Product"/>
                        <xsl:apply-templates select="entry[1]" mode="manufacturer" /> 
                    </rdf:Description>
                </gr:hasMakeAndModel-->
                <xsl:apply-templates select="entry[1]" />
			</rdf:Description>
		</rdf:RDF>
    </xsl:template>

    <xsl:template match="entry">
        <xsl:apply-templates select="*"/>
    </xsl:template>

    <xsl:template match="entry/s:product/s:description">
		<oplbb:description rdf:datatype="&xsd;string"><xsl:value-of select="."/></oplbb:description>
    </xsl:template>

    <xsl:template match="entry/s:product/s:inventories/s:inventory/s:price" mode="offering">
        <gr:hasPriceSpecification>
            <gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'UnitPriceSpecification')}">
                <rdfs:label>
					<xsl:value-of select="concat( ., ' (', @currency, ')')"/>	
				</rdfs:label>
                <gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
                <gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasCurrencyValue>
                <gr:hasCurrency rdf:datatype="&xsd;string"><xsl:value-of select="@currency"/></gr:hasCurrency>
            </gr:UnitPriceSpecification>
        </gr:hasPriceSpecification>
    </xsl:template>

    <xsl:template match="entry/s:product/s:creationTime">
        <dcterms:created>
			<xsl:value-of select="."/>
		</dcterms:created>
    </xsl:template>

    <xsl:template match="entry/s:product/s:modificationTime">
        <dcterms:modified>
			<xsl:value-of select="."/>
		</dcterms:modified>
    </xsl:template>

    <xsl:template match="entry/s:product/s:images/s:image">
		<xsl:if test="string-length(@link) &gt; 0">
			<xsl:element namespace="&oplbb;" name="image">
			<xsl:attribute name="rdf:resource">
				<xsl:value-of select="@link"/>
			</xsl:attribute>
			</xsl:element>
		</xsl:if>
    </xsl:template>

    <xsl:template match="entry/title">
		<rdfs:label>
			<xsl:value-of select="."/>
		</rdfs:label>
		<gr:name>
			<xsl:value-of select="."/>
		</gr:name>
    </xsl:template>

    <xsl:template match="entry/s:product/s:link">
        <sioc:link rdf:resource="{.}"/>
    </xsl:template>

    <xsl:template match="entry/s:product/s:googleId">
        <oplbb:productId><xsl:value-of select="."/></oplbb:productId>
    </xsl:template>

    <xsl:template match="text()|@*"/>
    <xsl:template match="text()|@*" mode="offering" />
    <xsl:template match="text()|@*" mode="manufacturer" />

</xsl:stylesheet>
