<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2015 OpenLink Software
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
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY pto "http://www.productontology.org/id/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY geo "http://www.w3.org/2003/01/geo/wgs84_pos#"> 
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY oplzllw "http://www.openlinksw.com/schemas/zillow#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="&rdf;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:sioc="&sioc;"
    xmlns:dcterms="&dcterms;"
    xmlns:geo="&geo;"
    xmlns:gr="&gr;"
    xmlns:opl="&opl;"
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
    <xsl:param name="currentDateTime"/>

    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:variable name="uc">ABCDEFGHIJKLMNOPQRSTUVWXYZ </xsl:variable>
    <xsl:variable name="lc">abcdefghijklmnopqrstuvwxyz_</xsl:variable>

	<!-- Process GetDeepSearchResults response -->

    <xsl:template match="/SearchResults:searchresults">
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

			<gr:Offering rdf:about="{vi:proxyIRI($baseUri, '', 'Offer')}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://www.zillow.com#this">
                                 			<foaf:name>Zillow</foaf:name>
                                 			<foaf:homepage rdf:resource="http://www.zillow.com"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>

			    <gr:hasBusinessFunction rdf:resource="&gr;Sell"/>
			    <rdfs:label><xsl:value-of select="concat(request/address, ' ', request/citystatezip)"/></rdfs:label>
			    <gr:includes rdf:resource="{$resourceURL}"/>
			    <gr:validFrom rdf:datatype="&xsd;dateTime"><xsl:value-of select="$currentDateTime"/></gr:validFrom>
				<xsl:apply-templates select="response/results/result" mode="offering"/>
			</gr:Offering>

            <gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Vendor')}">
			  	<rdfs:comment>The legal agent making the offering</rdfs:comment>
		      	<rdfs:label>Zillow Co., Inc.</rdfs:label>
		      	<gr:legalName>Zillow Co., Inc.</gr:legalName>
		      	<gr:offers rdf:resource="{vi:proxyIRI ($baseUri, '', 'Offer')}"/>
			  	<foaf:homepage rdf:resource="http://www.zillow.com" />
			  	<rdfs:seeAlso rdf:resource="{vi:proxyIRI ('http://www.zillow.com')}"/>
            </gr:BusinessEntity>

            <rdf:Description rdf:about="{$resourceURL}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://www.zillow.com#this">
                                 			<foaf:name>Zillow</foaf:name>
                                 			<foaf:homepage rdf:resource="http://www.zillow.com"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>
			    <rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder" />
			    <rdf:type rdf:resource="&oplzllw;Product" />
	    		<sioc:has_container rdf:resource="{$docproxyIRI}"/>
				<gr:amountOfThisGood>1</gr:amountOfThisGood>
				<xsl:apply-templates select="response/results/result" />
			</rdf:Description>
		</rdf:RDF>
    </xsl:template>

    <xsl:template match="result">
		<oplzllw:zpid><xsl:value-of select="zpid"/></oplzllw:zpid>
		<oplzllw:bathrooms>
	    	<xsl:value-of select="floor(bathrooms)"/><!-- floor used to force e.g 1.0 to 1 -->
		</oplzllw:bathrooms>
		<oplzllw:bedrooms><xsl:value-of select="floor(bedrooms)"/></oplzllw:bedrooms>
		<oplzllw:squareFeet><xsl:value-of select="finishedSqFt"/></oplzllw:squareFeet>
		<oplzllw:lotSize><xsl:value-of select="lotSizeSqFt"/></oplzllw:lotSize>
		<oplzllw:yearBuilt><xsl:value-of select="yearBuilt"/></oplzllw:yearBuilt>
		<oplzllw:taxes><xsl:value-of select="taxAssessment"/></oplzllw:taxes>
		<oplzllw:taxAssessmentYear><xsl:value-of select="taxAssessmentYear"/></oplzllw:taxAssessmentYear>
		<xsl:apply-templates />
	</xsl:template>

    <xsl:template match="result/links">
		<rdfs:seeAlso rdf:resource="{homedetails}"/>
		<rdfs:seeAlso rdf:resource="{graphsanddata}"/>
		<rdfs:seeAlso rdf:resource="{mapthishome}"/>
		<rdfs:seeAlso rdf:resource="{myestimator}"/>
		<rdfs:seeAlso rdf:resource="{comparables}"/>
    </xsl:template>

    <xsl:template match="result/address">
		<rdfs:label>
			<xsl:value-of select="concat(street, ', ', city, ', ', state)"/>
		</rdfs:label>
		<oplzllw:street><xsl:value-of select="street"/></oplzllw:street>
		<oplzllw:postalCode><xsl:value-of select="zipcode"/></oplzllw:postalCode>
		<oplzllw:city><xsl:value-of select="city"/></oplzllw:city>
		<oplzllw:state><xsl:value-of select="translate (state, $lc, $uc)"/></oplzllw:state>
		<rdfs:seeAlso rdf:resource="{vi:dbpIRI ('', city)}"/>
		<rdfs:seeAlso rdf:resource="{vi:dbpIRI ('', translate (state, $lc, $uc))}"/>
		<geo:long><xsl:value-of select="longitude"/></geo:long>
		<geo:lat><xsl:value-of select="latitude"/></geo:lat>
    </xsl:template>

    <xsl:template match="localRealEstate" />

    <xsl:template match="useCode">
		<oplzllw:homeType><xsl:value-of select="."/></oplzllw:homeType>
	</xsl:template>

    <xsl:template match="lastSoldPrice" mode="offering">
		<xsl:variable name="amount" select="." />
		<gr:hasPriceSpecification>
			<gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'LastSoldPrice')}">
				<rdfs:label>
					<xsl:value-of select="concat( vi:formatAmount($amount), ' (', @currency, ')')"/>	
				</rdfs:label>
				<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
				<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="$amount"/></gr:hasCurrencyValue>
				<gr:hasCurrency rdf:datatype="&xsd;string"><xsl:value-of select="@currency"/></gr:hasCurrency>
				<oplzllw:lastSoldDate><xsl:value-of select="../lastSoldDate"/></oplzllw:lastSoldDate>
			</gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template>

    <xsl:template match="zestimate" mode="offering">
		<xsl:variable name="amount" select="amount" />
		<gr:hasPriceSpecification>
			<gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'ZestimatePrice')}">
				<rdfs:label>
					<xsl:value-of select="concat(vi:formatAmount($amount), ' (', amount/@currency, ')')"/>
				</rdfs:label>
				<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
				<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="$amount"/></gr:hasCurrencyValue>
				<gr:hasMinCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="valuationRange/low"/></gr:hasMinCurrencyValue>
				<gr:hasMaxCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="valuationRange/high"/></gr:hasMaxCurrencyValue>
				<gr:hasCurrency rdf:datatype="&xsd;string"><xsl:value-of select="amount/@currency"/></gr:hasCurrency>
				<oplzllw:listingLastUpdated><xsl:value-of select="last-updated"/></oplzllw:listingLastUpdated>
			</gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template>

	<!-- Process GetUpdatedPropertyDetails response -->

	<!--
	The GetUpdatedPropertyDetails response includes the property's sale price, whereas the GetDeepSearchResults
	response only includes the lastSoldPrice. lastSoldPrice is used to create a UnitPriceSpecification labelled
	'Last Sold Price' for the Offering. The price returned by GetUpdatedPropertyDetails is used to create a second
	UnitPriceSpecification labelled 'Current Price'. However this information is not always available.
	GetUpdatedPropertyDetails often returns error code 501 - "The updated data for the property you are requesting
	is not available due to legal restrictions". It looks like properties being sold by agents return this code,
	while properties being sold directly by the owner make the information available.
	-->

    <xsl:template match="/UpdatedPropertyDetails:updatedPropertyDetails">
		<rdf:RDF>
            <rdf:Description rdf:about="{$resourceURL}">
				<xsl:apply-templates select="response" />
			</rdf:Description>

			<gr:Offering rdf:about="{vi:proxyIRI($baseUri, '', 'Offer')}">
				<xsl:apply-templates select="response" mode="offering"/>
			</gr:Offering>
		</rdf:RDF>
    </xsl:template>

    <xsl:template match="price" mode="offering">
		<xsl:variable name="amount" select="." />
		<oplzllw:price>
			<xsl:value-of select="$amount"/>
		</oplzllw:price>
		<gr:hasPriceSpecification>
			<gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'CurrentPrice')}">
				<rdfs:label>
				<xsl:value-of select="concat( vi:formatAmount($amount), ' (', @currency, ')')"/>	
				</rdfs:label>
				<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
				<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="$amount"/></gr:hasCurrencyValue>
				<gr:hasCurrency rdf:datatype="&xsd;string"><xsl:value-of select="@currency"/></gr:hasCurrency>
			</gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template>

    <xsl:template match="yearUpdated">
		<oplzllw:yearUpdated><xsl:value-of select="."/></oplzllw:yearUpdated>
	</xsl:template>
    <xsl:template match="numFloors">
		<oplzllw:numFloors><xsl:value-of select="."/></oplzllw:numFloors>
	</xsl:template>
    <xsl:template match="numRooms">
		<oplzllw:numRooms><xsl:value-of select="."/></oplzllw:numRooms>
	</xsl:template>
    <xsl:template match="homeDescription">
		<oplzllw:homeDescription><xsl:value-of select="."/></oplzllw:homeDescription>
	</xsl:template>
    <xsl:template match="whatOwnerLoves">
		<oplzllw:whatOwnerLoves><xsl:value-of select="."/></oplzllw:whatOwnerLoves>
	</xsl:template>
    <xsl:template match="roof">
<oplzllw:roof><xsl:value-of select="."/></oplzllw:roof>
	</xsl:template>
    <xsl:template match="exteriorMaterial">
<oplzllw:exteriorMaterial><xsl:value-of select="."/></oplzllw:exteriorMaterial>
	</xsl:template>
    <xsl:template match="parkingType">
		<oplzllw:parkingType><xsl:value-of select="."/></oplzllw:parkingType>
	</xsl:template>
    <xsl:template match="heatingSystem">
		<oplzllw:heatingSystem><xsl:value-of select="."/></oplzllw:heatingSystem>
	</xsl:template>
    <xsl:template match="heatingSources">
		<oplzllw:heatingSources><xsl:value-of select="."/></oplzllw:heatingSources>
	</xsl:template>
    <xsl:template match="appliances">
		<oplzllw:appliances><xsl:value-of select="."/></oplzllw:appliances>
	</xsl:template>
    <xsl:template match="floorCovering">
		<oplzllw:floorCovering><xsl:value-of select="."/></oplzllw:floorCovering>
	</xsl:template>
    <xsl:template match="rooms">
		<oplzllw:rooms><xsl:value-of select="."/></oplzllw:rooms>
	</xsl:template>
    <xsl:template match="image/url">
		<!--
		Remove any query string from image URL or it won't render in description.vsp
	 	e.g. from http://images3.zillow.com/is/image/i0/i1/i2283/IS131nd4m22pf37.jpg?op_sharpen=1&amp;qlt=90&amp;size=400,400
		-->
		<xsl:choose>
			<xsl:when test="contains(., '?')">
				<oplzllw:image rdf:resource="{substring-before(., '?')}"/>
			</xsl:when>
			<xsl:otherwise>
				<oplzllw:image rdf:resource="{.}"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- TO DO: Should this info form part of the Offering rather than ProductOrServicePlaceholder? -->
    <xsl:template match="posting">
		<oplzllw:listingStatus><xsl:value-of select="status"/></oplzllw:listingStatus>
		<oplzllw:listingType><xsl:value-of select="type"/></oplzllw:listingType>
		<oplzllw:listingLastUpdated><xsl:value-of select="lastUpdatedDate"/></oplzllw:listingLastUpdated>
	</xsl:template>

    <xsl:template match="text()|@*"/>
    <xsl:template match="text()|@*" mode="offering" />

</xsl:stylesheet>
