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
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY oplbb "http://www.openlinksw.com/schemas/bestbuy#">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="&rdf;"
    xmlns:pto="&pto;" 
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:sioc="&sioc;"
    xmlns:dcterms="&dcterms;"
    xmlns:gr="&gr;"
    xmlns:oplbb="&oplbb;"
    xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:opl="&opl;"
    xmlns:etsy="http://www.etsy.com/">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri"/>
	<xsl:param name="action"/>
	
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:variable name="ns">http://www.etsy.com/</xsl:variable>

    <xsl:template match="/">
		<rdf:RDF>
			<xsl:if test="$action = 'user'">
				<rdf:Description rdf:about="{$docproxyIRI}">
					<rdf:type rdf:resource="&bibo;Document"/>
					<sioc:container_of rdf:resource="{$resourceURL}"/>
					<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
					<dcterms:subject rdf:resource="{$resourceURL}"/>
					<dc:title><xsl:value-of select="$baseUri"/></dc:title>
					<dc:title><xsl:value-of select="$baseUri"/></dc:title>
					<owl:sameAs rdf:resource="{$docIRI}"/>
				</rdf:Description>
				<rdf:Description rdf:about="{$resourceURL}">
					<rdf:type rdf:resource="&foaf;Person"/>
					<xsl:apply-templates select="results/results/*" />
				</rdf:Description>
			</xsl:if>
			<xsl:if test="$action = 'prod'">
				<rdf:Description rdf:about="{$docproxyIRI}">
					<rdf:type rdf:resource="&bibo;Document"/>
					<sioc:container_of rdf:resource="{vi:proxyIRI ($baseUri, '', 'Product')}"/>
					<foaf:primaryTopic rdf:resource="{vi:proxyIRI ($baseUri, '', 'Product')}"/>
					<dcterms:subject rdf:resource="{vi:proxyIRI ($baseUri, '', 'Product')}"/>
					<foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', 'Vendor')}"/>
					<!--foaf:topic rdf:resource="{$resourceURL}"/-->
					<dc:title><xsl:value-of select="$baseUri"/></dc:title>
					<owl:sameAs rdf:resource="{$docIRI}"/>
				</rdf:Description>
				<gr:Offering rdf:about="{$resourceURL}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://www.etsy.com#this">
                                 			<foaf:name>Etsy</foaf:name>
                                 			<foaf:homepage rdf:resource="http://www.etsy.com"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>

					<sioc:has_container rdf:resource="{$docproxyIRI}"/>
					<gr:hasBusinessFunction rdf:resource="&gr;Sell"/>
					<!--rdfs:label><xsl:value-of select="title"/></rdfs:label-->
					<gr:includes rdf:resource="{vi:proxyIRI ($baseUri, '', 'Product')}"/>
					<gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModePickup"/>
				</gr:Offering>
				<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', 'Product')}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://www.etsy.com#this">
                                 			<foaf:name>Etsy</foaf:name>
                                 			<foaf:homepage rdf:resource="http://www.etsy.com"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>

					<rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder" />
					<rdf:type rdf:resource="&oplbb;Product" />
					<sioc:has_container rdf:resource="{$docproxyIRI}"/>
					<xsl:apply-templates select="results/results/*" />
				</rdf:Description>
				<gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Vendor')}">
					<rdfs:comment>The legal agent making the offering</rdfs:comment>
					<rdfs:label>Etsy</rdfs:label>
					<gr:legalName>Etsy</gr:legalName>
					<gr:offers rdf:resource="{$resourceURL}"/>
					<foaf:homepage rdf:resource="http://www.etsy.com" />
					<rdfs:seeAlso rdf:resource="{vi:proxyIRI ('http://www.etsy.com')}"/>
				</gr:BusinessEntity>
			</xsl:if>
		</rdf:RDF>
    </xsl:template>

    <xsl:template match="gender">
		<foaf:gender>
			<xsl:value-of select="."/>
		</foaf:gender>
    </xsl:template>

    <xsl:template match="title">
		<rdfs:label>
			<xsl:value-of select="."/>
		</rdfs:label>
		<gr:name>
			<xsl:value-of select="."/>
		</gr:name>
    </xsl:template>
    
    <xsl:template match="url">
		<bibo:uri>
			<xsl:value-of select="."/>
		</bibo:uri>
    </xsl:template>

    <xsl:template match="image_url_25x25">
		<foaf:img rdf:resource="{.}"/>
    </xsl:template>

    <xsl:template match="image_url_50x50">
		<foaf:img rdf:resource="{.}"/>
    </xsl:template>

    <xsl:template match="image_url_75x75">
		<foaf:img rdf:resource="{.}"/>
    </xsl:template>

    <xsl:template match="image_url_155x125">
		<foaf:img rdf:resource="{.}"/>
    </xsl:template>

    <xsl:template match="image_url_170x135">
		<foaf:img rdf:resource="{.}"/>
    </xsl:template>

    <xsl:template match="image_url_200x200">
		<foaf:img rdf:resource="{.}"/>
    </xsl:template>

    <xsl:template match="image_url_430xN">
		<foaf:img rdf:resource="{.}"/>
    </xsl:template>

    <xsl:template match="user_name">
		<xsl:if test="$action = 'prod'">
			<dcterms:creator rdf:resource="{vi:proxyIRI (concat('http://www.etsy.com/people/', .))}"/>
		</xsl:if>
		<xsl:if test="$action = 'user'">
			<rdfs:label>
				<xsl:value-of select="."/>
			</rdfs:label>
			<foaf:name>
				<xsl:value-of select="."/>
			</foaf:name>
		</xsl:if>
    </xsl:template>

    <xsl:template match="tag">
		<sioc:topic rdf:resource="{concat ('http://www.etsy.com/search_results.php?search_type=all&amp;includes[]=tags&amp;search_query=', .)}"/>
    </xsl:template>

    <xsl:template match="description">
		<gr:description>
			<xsl:value-of select="."/>
		</gr:description>
    </xsl:template>
    
    <xsl:template match="bio">
		<dc:description>
			<xsl:value-of select="."/>
		</dc:description>
    </xsl:template>
    
    <xsl:template match="lat">
		<geo:lat rdf:datatype="&xsd;float">
			<xsl:value-of select="."/>
		</geo:lat>
    </xsl:template>

    <xsl:template match="lon">
		<geo:long rdf:datatype="&xsd;float">
			<xsl:value-of select="."/>
		</geo:long>
    </xsl:template>
    
    <xsl:template match="price">
		<gr:hasPriceSpecification>
			<gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'price')}">
				<rdfs:label><xsl:value-of select="concat( ., ' (USD)')"/></rdfs:label>
				<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasCurrencyValue>
				<gr:hasCurrency rdf:datatype="&xsd;string">USD</gr:hasCurrency>
			</gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template>
    
    <xsl:template match="*|text()"/>
        
</xsl:stylesheet>
