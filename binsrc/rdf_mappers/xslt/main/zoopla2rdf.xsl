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
<!ENTITY pto "http://www.productontology.org/id/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY geo "http://www.w3.org/2003/01/geo/wgs84_pos#"> 
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY oplzllw "http://www.openlinksw.com/schemas/zillow#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:opl="http://www.openlinksw.com/schema/attribution#"
    xmlns:rdf="&rdf;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:sioc="&sioc;"
    xmlns:geo="&geo;"
    xmlns:dcterms="&dcterms;"
    xmlns:gr="&gr;"
    xmlns:pto="&pto;" 
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:SearchResults="http://www.zillow.com/static/xsd/SearchResults.xsd"
    xmlns:UpdatedPropertyDetails="http://www.zillow.com/static/xsd/UpdatedPropertyDetails.xsd"
    xmlns:oplzllw="&oplzllw;"
    xmlns:zillow="http://www.zillow.com/">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri"/>

    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

	<!-- Process GetDeepSearchResults response -->

    <xsl:template match="/response">
		<rdf:RDF>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<dc:title><xsl:value-of select="$baseUri"/></dc:title>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', 'Vendor')}"/>
				<foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', 'Offer')}"/>
				<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>
			<xsl:apply-templates select="property"/>
			<xsl:apply-templates select="listing"/>
		</rdf:RDF>
    </xsl:template>
	
	<xsl:template match="property|listing">
		<gr:Offering rdf:about="{vi:proxyIRI($baseUri, '', 'Offer')}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://www.zoopla.com#this">
                                 			<foaf:name>Zoopla</foaf:name>
                                 			<foaf:homepage rdf:resource="http://www.zoopla.com"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>
			<xsl:if test="listing_status = 'rent'">
				<gr:hasBusinessFunction rdf:resource="&gr;LeaseOut"/>
			</xsl:if>
			<xsl:if test="listing_status != 'rent'">
				<gr:hasBusinessFunction rdf:resource="&gr;Sell"/>
			</xsl:if>
			<rdfs:label>
				<xsl:value-of select="concat(displayable_address, address, ' ', county, ' ', country)"/>
			</rdfs:label>
			<gr:includes rdf:resource="{$resourceURL}"/>
			<xsl:apply-templates mode="offering"/>
		</gr:Offering>

		<gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Vendor')}">
			<rdfs:comment>The legal agent making the offering</rdfs:comment>
			<rdfs:label>Zoopla</rdfs:label>
			<gr:legalName>Zoopla</gr:legalName>
			<gr:offers rdf:resource="{vi:proxyIRI ($baseUri, '', 'Offer')}"/>
			<foaf:homepage rdf:resource="http://www.zoopla.co.uk" />
			<rdfs:seeAlso rdf:resource="{vi:proxyIRI ('http://www.zoopla.co.uk')}"/>
		</gr:BusinessEntity>
		
		<rdf:Description rdf:about="{$resourceURL}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://www.zoopla.com#this">
                                 			<foaf:name>Zoopla</foaf:name>
                                 			<foaf:homepage rdf:resource="http://www.zoopla.com"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>
			<rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder" />
			<rdf:type rdf:resource="&oplzllw;Product" />
			<sioc:has_container rdf:resource="{$docproxyIRI}"/>
			<gr:amountOfThisGood>1</gr:amountOfThisGood>
			<gr:offers rdf:resource="{vi:proxyIRI ($baseUri, '', 'Offer')}"/>
			<rdfs:label>
				<xsl:value-of select="concat(displayable_address, address, ' ', county, ' ', country)"/>
			</rdfs:label>
			<xsl:if test="address">
				<oplzllw:address><xsl:value-of select="address"/></oplzllw:address>
			</xsl:if>
			<xsl:if test="street">
				<oplzllw:street><xsl:value-of select="street"/></oplzllw:street>
			</xsl:if>
			<xsl:if test="town">
				<oplzllw:city><xsl:value-of select="town"/></oplzllw:city>
			</xsl:if>
			<xsl:if test="string-length(country) &gt; 0">
				<oplzllw:country><xsl:value-of select="country"/></oplzllw:country>
			</xsl:if>
			<xsl:if test="county">
				<oplzllw:state><xsl:value-of select="county"/></oplzllw:state>
			</xsl:if>
			<xsl:if test="details_url">
				<rdfs:seeAlso rdf:resource="{details_url}"/>
			</xsl:if>
			<xsl:if test="refine_estimate_url">
				<rdfs:seeAlso rdf:resource="{refine_estimate_url}"/>
			</xsl:if>
			<xsl:if test="longitude">
				<geo:long><xsl:value-of select="longitude"/></geo:long>
			</xsl:if>
			<xsl:if test="latitude">
				<geo:lat><xsl:value-of select="latitude"/></geo:lat>
			</xsl:if>
			<xsl:if test="postcode">
				<oplzllw:postalCode><xsl:value-of select="postcode"/></oplzllw:postalCode>
			</xsl:if>
			<xsl:if test="description">
				<oplzllw:homeDescription><xsl:value-of select="description"/></oplzllw:homeDescription>
			</xsl:if>
			<xsl:if test="displayable_address">
				<oplzllw:address><xsl:value-of select="displayable_address"/></oplzllw:address>
			</xsl:if>
			<xsl:if test="image_url">
				<foaf:depiction rdf:resource="{image_url}"/>
			</xsl:if>
			<xsl:if test="num_bathrooms">
				<oplzllw:bathrooms><xsl:value-of select="num_bathrooms"/></oplzllw:bathrooms>
			</xsl:if>
			<xsl:if test="num_bedrooms">
				<oplzllw:bedrooms><xsl:value-of select="num_bedrooms"/></oplzllw:bedrooms>
			</xsl:if>
			<xsl:if test="num_floors">
				<oplzllw:numFloors><xsl:value-of select="num_floors"/></oplzllw:numFloors>
			</xsl:if>
			<xsl:if test="num_recepts">
				<oplzllw:recepts><xsl:value-of select="num_recepts"/></oplzllw:recepts>
			</xsl:if>
			<xsl:if test="post_town">
				<oplzllw:city><xsl:value-of select="post_town"/></oplzllw:city>
			</xsl:if>
			<xsl:if test="thumbnail_url">
				<foaf:depiction rdf:resource="{thumbnail_url}"/>
			</xsl:if>
			<xsl:if test="street_name">
				<oplzllw:street><xsl:value-of select="street_name"/></oplzllw:street>
			</xsl:if>
			<xsl:if test="string-length(property_type) &gt; 0">
				<oplzllw:type><xsl:value-of select="property_type"/></oplzllw:type>
			</xsl:if>
		</rdf:Description>		
	</xsl:template>
	
	 <xsl:template match="estimate_value" mode="offering">
		<xsl:variable name="amount" select="." />
		<gr:hasPriceSpecification>
			<gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'estimate_value')}">
				<rdfs:label>
					<xsl:value-of select="concat( vi:formatAmount($amount), ' GBP')"/>	
				</rdfs:label>
				<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
				<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="$amount"/></gr:hasCurrencyValue>
				<gr:hasCurrency rdf:datatype="&xsd;string">GBP</gr:hasCurrency>
			</gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template>
	
	<xsl:template match="estimate_value_lower" mode="offering">
		<xsl:variable name="amount" select="." />
		<gr:hasPriceSpecification>
			<gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'estimate_value_lower')}">
				<rdfs:label>
					<xsl:value-of select="concat( vi:formatAmount($amount), ' GBP')"/>	
				</rdfs:label>
				<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
				<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="$amount"/></gr:hasCurrencyValue>
				<gr:hasCurrency rdf:datatype="&xsd;string">GBP</gr:hasCurrency>
			</gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template>

	<xsl:template match="estimate_value_upper" mode="offering">
		<xsl:variable name="amount" select="." />
		<gr:hasPriceSpecification>
			<gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'estimate_value_upper')}">
				<rdfs:label>
					<xsl:value-of select="concat( vi:formatAmount($amount), ' GBP')"/>	
				</rdfs:label>
				<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
				<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="$amount"/></gr:hasCurrencyValue>
				<gr:hasCurrency rdf:datatype="&xsd;string">GBP</gr:hasCurrency>
			</gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template>

	<xsl:template match="rental_estimate_value_lower" mode="offering">
		<xsl:variable name="amount" select="." />
		<gr:hasPriceSpecification>
			<gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'rental_estimate_value_lower')}">
				<rdfs:label>
					<xsl:value-of select="concat( vi:formatAmount($amount), ' GBP')"/>	
				</rdfs:label>
				<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
				<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="$amount"/></gr:hasCurrencyValue>
				<gr:hasCurrency rdf:datatype="&xsd;string">GBP</gr:hasCurrency>
			</gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template>

	<xsl:template match="rental_estimate_value_upper" mode="offering">
		<xsl:variable name="amount" select="." />
		<gr:hasPriceSpecification>
			<gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'rental_estimate_value_upper')}">
				<rdfs:label>
					<xsl:value-of select="concat( vi:formatAmount($amount), ' GBP')"/>	
				</rdfs:label>
				<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
				<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="$amount"/></gr:hasCurrencyValue>
				<gr:hasCurrency rdf:datatype="&xsd;string">GBP</gr:hasCurrency>
			</gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template>

	<xsl:template match="price" mode="offering">
		<xsl:variable name="amount" select="." />
		<gr:hasPriceSpecification>
			<gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'price')}">
				<rdfs:label>
					<xsl:value-of select="concat( vi:formatAmount($amount), ' GBP')"/>	
				</rdfs:label>
				<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
				<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="$amount"/></gr:hasCurrencyValue>
				<gr:hasCurrency rdf:datatype="&xsd;string">GBP</gr:hasCurrency>
			</gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template>	

    <xsl:template match="text()|@*"/>
    <xsl:template match="text()|@*" mode="offering" />

</xsl:stylesheet>
