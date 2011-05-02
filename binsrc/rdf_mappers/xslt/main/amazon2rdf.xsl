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
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY review "http:/www.purl.org/stuff/rev#">
<!ENTITY pto "http://www.productontology.org/id/">
<!ENTITY amz "http://webservices.amazon.com/AWSECommerceService/2005-10-05">
<!ENTITY oplamz "http://www.openlinksw.com/schemas/amazon#">
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
    xmlns:pto="&pto;" 
    xmlns:book="&book;"
    xmlns:dc="&dc;"
    xmlns:dcterms="&dcterms;"
    xmlns:review="&review;"
    xmlns:owl="&owl;"
    xmlns:cl="&cl;"
    xmlns:amz="&amz;"
    xmlns:oplamz="&oplamz;">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri" />
    <xsl:param name="asin" />
    <xsl:param name="currentDateTime"/>
    <xsl:param name="associate_key"/>
    <xsl:param name="wish_list" />

    <xsl:variable name="resourceURL"><xsl:value-of select="vi:proxyIRI (concat ('http://www.amazon.com/o/ASIN/', $asin))"/></xsl:variable>
    <xsl:variable name="base"><xsl:value-of select="concat ('http://www.amazon.com/o/ASIN/', $asin)"/></xsl:variable>
    <xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:template match="/">
		<rdf:RDF>
			<xsl:choose>
				    <xsl:when test="$wish_list = '1'">
						<rdf:Description rdf:about="{$docproxyIRI}">
							    <rdf:type rdf:resource="&bibo;Document"/>
                                                            <sioc:container_of rdf:resource="{vi:proxyIRI($baseUri)}"/>
                                                            <foaf:primaryTopic rdf:resource="{vi:proxyIRI($baseUri)}"/>
                                                            <dcterms:subject rdf:resource="{vi:proxyIRI($baseUri)}"/>
							    <xsl:for-each select="//amz:ListLookupResponse/amz:Lists/amz:List/amz:ListItem/amz:Item">
							      <gr:seeks rdf:resource="{amz:DetailPageURL}"/>
							    </xsl:for-each>
                                                            <owl:sameAs rdf:resource="{$docIRI}"/>
						    </rdf:Description>
                                                <rdf:Description rdf:about="{vi:proxyIRI($baseUri)}">
                                                            <rdf:type rdf:resource="&bibo;Document"/>
                                                            <sioc:has_container rdf:resource="{$docproxyIRI}"/>
							    <xsl:for-each select="//amz:ListLookupResponse/amz:Lists/amz:List/amz:ListItem/amz:Item">
							      <gr:seeks rdf:resource="{amz:DetailPageURL}"/>
							    </xsl:for-each>
                                                 </rdf:Description>           
				    </xsl:when>
				    <xsl:when test="$wish_list = '2'">
						<rdf:Description rdf:about="{$docproxyIRI}">
							    <rdf:type rdf:resource="&bibo;Document"/>
                                                            <sioc:container_of rdf:resource="{vi:proxyIRI($baseUri)}"/>
                                                            <foaf:primaryTopic rdf:resource="{vi:proxyIRI($baseUri)}"/>
                                                            <dcterms:subject rdf:resource="{vi:proxyIRI($baseUri)}"/>
							    <xsl:for-each select="//amz:ItemSearchResponse/amz:Items/amz:Item">
							      <gr:seeks rdf:resource="{amz:DetailPageURL}"/>
							    </xsl:for-each>
                                                            <owl:sameAs rdf:resource="{$docIRI}"/>
						    </rdf:Description>
                                                <rdf:Description rdf:about="{vi:proxyIRI($baseUri)}">
                                                            <rdf:type rdf:resource="&bibo;Document"/>
                                                            <sioc:has_container rdf:resource="{$docproxyIRI}"/>
							    <xsl:for-each select="//amz:ItemSearchResponse/amz:Items/amz:Item">
							      <gr:seeks rdf:resource="{amz:DetailPageURL}"/>
							    </xsl:for-each>
                                                 </rdf:Description>      
				    </xsl:when>
			<xsl:otherwise>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<xsl:for-each select="//amz:CustomerReviews/amz:Review">
				  <foaf:topic rdf:resource="{vi:proxyIRI ($base, '', concat('Review_', amz:CustomerId))}"/>
				</xsl:for-each>
				<!-- See also 'shortcuts' below for foaf:topic links -->
				<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>
            <rdf:Description rdf:about="{$resourceURL}">
			    <rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder" />
			    <rdf:type rdf:resource="&oplamz;Product" />
						<rdf:type rdf:resource="&pto;Amazon.com"/>
	    		<sioc:has_container rdf:resource="{$docproxyIRI}"/>
                <gr:hasMakeAndModel>
					<rdf:Description rdf:about="{vi:proxyIRI ($base, '', 'MakeAndModel')}">
						<rdf:type rdf:resource="&gr;ProductOrServiceModel"/>
						<rdf:type rdf:resource="&oplamz;Product"/>
						<rdfs:label><xsl:value-of select="//amz:ItemAttributes/amz:Brand"/></rdfs:label>
						<xsl:variable name="brand" select="//amz:ItemAttributes/amz:Brand"/>
						<xsl:variable name="model" select="//amz:ItemAttributes/amz:Model"/>
		               	<rdfs:comment><xsl:value-of select="concat($brand, ' ', $model)"/> </rdfs:comment>

					    <xsl:apply-templates select="//amz:ItemAttributes" mode="manufacturer" />
                    </rdf:Description>
                </gr:hasMakeAndModel>
                <xsl:choose>
					<xsl:when test="//amz:ProductGroup[ . = 'Book']">
						<rdf:type rdf:resource="&bibo;Book"/>
						<rdf:type rdf:resource="&book;Book"/>
						<xsl:apply-templates select="//amz:ItemAttributes" mode="bibo" />
					</xsl:when>
					<xsl:otherwise/>
				</xsl:choose>
				<xsl:apply-templates select="//amz:Item"/>
				<xsl:apply-templates select="//amz:ItemAttributes"/>
				<xsl:apply-templates select="//amz:CustomerReviews"/>
			</rdf:Description>
					<xsl:if test="//amz:ItemAttributes/amz:ListPrice">
						<gr:Offering rdf:about="{vi:proxyIRI($base, '', 'ListOffer')}">
							<gr:hasBusinessFunction rdf:resource="&gr;Sell"/>
							<gr:validFrom rdf:datatype="&xsd;dateTime"><xsl:value-of select="$currentDateTime"/></gr:validFrom>
							<gr:includes rdf:resource="{$resourceURL}"/>
							<gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModePickup"/>
							<gr:availableDeliveryMethods rdf:resource="&gr;UPS"/>
							<gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModeMail"/>
							<rdfs:label><xsl:value-of select="concat('List offer: ', //amz:ItemAttributes/amz:Title)"/></rdfs:label>
							<oplamz:hasListPrice>
								<gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($base, '', 'ListPrice')}">
									<rdfs:label>
										<xsl:value-of select="concat( //amz:ItemAttributes/amz:ListPrice/amz:Amount div 100, ' (', //amz:ItemAttributes/amz:ListPrice/amz:CurrencyCode ,')')"/>	
									</rdfs:label>
									<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>	
									<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="//amz:ItemAttributes/amz:ListPrice/amz:Amount div 100"/></gr:hasCurrencyValue>
									<gr:hasCurrency rdf:datatype="&xsd;string"><xsl:value-of select="//amz:ItemAttributes/amz:ListPrice/amz:CurrencyCode"/></gr:hasCurrency>
									<gr:priceType rdf:datatype="&xsd;string">List price</gr:priceType>
								</gr:UnitPriceSpecification>
							</oplamz:hasListPrice>
						</gr:Offering>
						<rdf:Description rdf:about="{$docproxyIRI}">
							<foaf:topic rdf:resource="{vi:proxyIRI ($base, '', 'ListOffer')}"/>	
						</rdf:Description>
					</xsl:if>
			<xsl:apply-templates select="//amz:Offer" mode="offering"/>
			</xsl:otherwise>
			</xsl:choose>
		</rdf:RDF>
    </xsl:template>

    <xsl:template match="amz:Offer" mode="offering">
		<xsl:element namespace="&gr;" name="Offering">
			<xsl:attribute name="rdf:about">
				<xsl:value-of select="concat (vi:proxyIRI($base, '', 'Offer_'), position())"/>
			</xsl:attribute>
			<xsl:if test="$associate_key != ''">
			    <owl:sameAs rdf:resource="{concat ($base, '/ref=nosim/', $associate_key)}"/>
			</xsl:if>		    
	    	<gr:hasBusinessFunction rdf:resource="&gr;Sell"/>
		    <gr:validFrom rdf:datatype="&xsd;dateTime"><xsl:value-of select="$currentDateTime"/></gr:validFrom>
	    	<gr:includes rdf:resource="{$resourceURL}"/>
		    <gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModePickup"/>
			<gr:availableDeliveryMethods rdf:resource="&gr;UPS"/>
			<gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModeMail"/>
	    	<rdfs:label><xsl:value-of select="concat('Offer ', position(), ':', //amz:ItemAttributes/amz:Title)"/></rdfs:label>
			<gr:hasEAN_UCC-13><xsl:value-of select="//amz:ItemAttributes/amz:EAN"/></gr:hasEAN_UCC-13>
			<oplamz:condition><xsl:value-of select="./amz:OfferAttributes/amz:Condition"/></oplamz:condition>
			<oplamz:conditionNote><xsl:value-of select="./amz:OfferAttributes/amz:ConditionNote"/></oplamz:conditionNote>
			<oplamz:availability><xsl:value-of select="./amz:OfferListing/amz:Availability"/></oplamz:availability>
			<oplamz:offerListingId><xsl:value-of select="./amz:OfferListing/amz:OfferListingId"/></oplamz:offerListingId>
			<oplamz:merchantId><xsl:value-of select="./amz:Merchant/amz:MerchantId"/></oplamz:merchantId>
			<gr:hasPriceSpecification>
		  		<gr:UnitPriceSpecification rdf:about="{concat(vi:proxyIRI ($base, '', 'OfferPrice_'), position())}">
					<rdfs:label>
						<xsl:value-of select="concat( ./amz:OfferListing/amz:Price/amz:Amount div 100, ' (', ./amz:OfferListing/amz:Price/amz:CurrencyCode ,')')"/>	
					</rdfs:label>
					<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
            		<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="./amz:OfferListing/amz:Price/amz:Amount div 100"/></gr:hasCurrencyValue>
            		<gr:hasCurrency rdf:datatype="&xsd;string"><xsl:value-of select="./amz:OfferListing/amz:Price/amz:CurrencyCode"/></gr:hasCurrency>
					<gr:priceType rdf:datatype="&xsd;string">offer price</gr:priceType>
          		</gr:UnitPriceSpecification>
			</gr:hasPriceSpecification>
			<oplamz:hasSalePrice>
				<gr:UnitPriceSpecification rdf:about="{concat(vi:proxyIRI ($base, '', 'SalePrice_'), position())}">
					<rdfs:label>
						<xsl:value-of select="concat( ./amz:OfferListing/amz:SalePrice/amz:Amount div 100, ' (', ./amz:OfferListing/amz:SalePrice/amz:CurrencyCode ,')')"/>	
					</rdfs:label>
					<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>	
            		<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="./amz:OfferListing/amz:SalePrice/amz:Amount div 100"/></gr:hasCurrencyValue>
            		<gr:hasCurrency rdf:datatype="&xsd;string"><xsl:value-of select="./amz:OfferListing/amz:SalePrice/amz:CurrencyCode"/></gr:hasCurrency>
					<gr:priceType rdf:datatype="&xsd;string">sale price</gr:priceType>
				</gr:UnitPriceSpecification>
			</oplamz:hasSalePrice>
		</xsl:element>

		<xsl:element namespace="&gr;" name="BusinessEntity">
			<xsl:attribute name='rdf:about'>
				<xsl:value-of select="concat (vi:proxyIRI($base, '', 'Vendor_'), position())"/>
			</xsl:attribute>
			<rdfs:comment>The legal agent making the offering</rdfs:comment>
			<!-- MERCHANTID_{merchant id} will be replaced by merchant name/nickname by cartridge hook function -->
		    <rdfs:label><xsl:value-of select="concat('MERCHANTID_', ./amz:Merchant/amz:MerchantId)"/></rdfs:label>
		    <gr:legalName><xsl:value-of select="concat('MERCHANTID_', ./amz:Merchant/amz:MerchantId)"/></gr:legalName>
		    <gr:offers>
				<xsl:attribute name='rdf:resource'>
					<xsl:value-of select="concat (vi:proxyIRI($base, '', 'Offer_'), position())"/>
				</xsl:attribute>
			</gr:offers>
		  	<rdfs:seeAlso rdf:resource="{./amz:Merchant/amz:GlancePage}"/>
		  	<oplamz:vendorSynopsisUrl rdf:resource="{./amz:Merchant/amz:GlancePage}"/>
		</xsl:element>

		<!-- shortcuts -->
		<rdf:Description rdf:about="{$docproxyIRI}">
			<foaf:topic rdf:resource="{concat (vi:proxyIRI ($base, '', 'Vendor_'), position())}"/>
			<foaf:topic rdf:resource="{concat (vi:proxyIRI ($base, '', 'Offer_'), position())}"/>
		</rdf:Description>
    </xsl:template>

    <xsl:template match="amz:CustomerReviews/amz:AverageRating">
		<review:rating><xsl:value-of select="."/></review:rating>
    </xsl:template>

    <xsl:template match="amz:CustomerReviews/amz:Review">
		<review:hasReview>
			<review:Review rdf:about="{vi:proxyIRI ($base, '', concat('Review_', amz:CustomerId))}">
				<rdfs:label><xsl:value-of select="amz:Summary"/></rdfs:label>
				<review:title><xsl:value-of select="amz:Summary"/></review:title>
				<review:text><xsl:value-of select="amz:Content"/></review:text>
				<review:reviewer><xsl:value-of select="concat('http://www.amazon.com/gp/pdp/profile/', amz:CustomerId)"/></review:reviewer>
				<review:rating><xsl:value-of select="amz:Rating"/></review:rating>
				<review:totalVotes><xsl:value-of select="amz:HelpfulVotes"/></review:totalVotes>
				<dc:date><xsl:value-of select="amz:Date"/></dc:date>
			</review:Review>
		</review:hasReview>
    </xsl:template>

    <xsl:template match="amz:ItemAttributes/amz:Manufacturer" mode="manufacturer">
		<gr:hasManufacturer>
			<gr:BusinessEntity rdf:about="{vi:proxyIRI ($base, '', 'Manufacturer')}">
				<rdfs:label><xsl:value-of select="."/></rdfs:label>
				<gr:legalName><xsl:value-of select="."/></gr:legalName>
			</gr:BusinessEntity>
		</gr:hasManufacturer>
    </xsl:template>

    <xsl:template match="amz:ItemAttributes/amz:Manufacturer">
	<rdf:type rdf:resource="{concat('&pto;', .)}" />
    </xsl:template>
    
    <xsl:template match="amz:ItemAttributes/amz:Publisher">
		<dcterms:publisher>
                        <xsl:value-of select="."/>
		</dcterms:publisher>
    </xsl:template>

    <xsl:template match="amz:Item/amz:ASIN">
		<oplamz:ASIN><xsl:value-of select="."/></oplamz:ASIN>
    </xsl:template>

    <xsl:template match="amz:Item/amz:SmallImage">
		<foaf:depiction rdf:resource="{URL}"/>
    </xsl:template>

    <xsl:template match="amz:Item/amz:MediumImage">
		<foaf:depiction rdf:resource="{URL}"/>
    </xsl:template>
	
    <xsl:template match="amz:Item/amz:LargeImage">
		<foaf:depiction rdf:resource="{URL}"/>
    </xsl:template>

    <xsl:template match="amz:Item/amz:ImageSets">
		<xsl:for-each select="ImageSet/SwatchImage">
			<foaf:depiction rdf:resource="{URL}"/>
		</xsl:for-each>
    </xsl:template>
	
    <xsl:template match="amz:Item/amz:DetailPageURL">
		<oplamz:DetailPageURL><xsl:value-of select="."/></oplamz:DetailPageURL>
    </xsl:template>

    <xsl:template match="amz:ItemAttributes/amz:Color">
		<oplamz:color><xsl:value-of select="."/></oplamz:color>
    </xsl:template>
    <xsl:template match="amz:ItemAttributes/amz:EAN">
		<gr:hasEAN_UCC-13><xsl:value-of select="."/></gr:hasEAN_UCC-13>
    </xsl:template>
    <xsl:template match="amz:ItemAttributes/amz:Title">
		<rdfs:comment><xsl:value-of select="."/></rdfs:comment>
		<dc:title><xsl:value-of select="."/></dc:title>
        <rdfs:label><xsl:value-of select="concat('Product:', .)"/></rdfs:label>
    </xsl:template>
    <xsl:template match="amz:ItemAttributes/amz:ProductGroup">
		<oplamz:productGroup><xsl:value-of select="."/></oplamz:productGroup>
		<rdf:type rdf:resource="{concat('&pto;', .)}" />
    </xsl:template>

    <xsl:template match="amz:ItemAttributes/amz:Feature">
		<oplamz:feature><xsl:value-of select="."/></oplamz:feature>
    </xsl:template>

    <xsl:template match="amz:ItemAttributes/amz:PackageDimensions/Height">
		<oplamz:packageHeight>
			<gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($base, '', 'PackageHeight')}">
				<xsl:choose>
					<xsl:when test="contains(@Units , 'hundredths-inches')">
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select=". div 100"/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">INH</gr:hasUnitOfMeasurement>
						<rdfs:label><xsl:value-of select="concat(. div 100, ' (INH)')"/></rdfs:label>
					</xsl:when>
					<xsl:otherwise>
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select="."/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">
							<xsl:value-of select="@Units"/>
						</gr:hasUnitOfMeasurement>
						<rdfs:label><xsl:value-of select="concat(. , ' (', @Units, ')')"/></rdfs:label>
					</xsl:otherwise>
				</xsl:choose>
			</gr:QuantitativeValueFloat>
		</oplamz:packageHeight>
    </xsl:template>

    <xsl:template match="amz:ItemAttributes/amz:PackageDimensions/amz:Weight">
		<oplamz:packageWeight>
	  		<gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($base, '', 'PackageWeight')}">
				<xsl:choose>
					<xsl:when test="contains(@Units , 'hundredths-pounds')">
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select=". div 100"/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">LBR</gr:hasUnitOfMeasurement>
						<rdfs:label><xsl:value-of select="concat(. div 100, ' (LBR)')"/></rdfs:label>
					</xsl:when>
					<xsl:otherwise>
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select="."/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">
							<xsl:value-of select="@Units"/>
						</gr:hasUnitOfMeasurement>
						<rdfs:label><xsl:value-of select="concat(., ' (', @Units, ')')"/></rdfs:label>
					</xsl:otherwise>
				</xsl:choose>
	  		</gr:QuantitativeValueFloat>
		</oplamz:packageWeight>
    </xsl:template>

    <xsl:template match="amz:ItemAttributes/amz:PackageDimensions/amz:Length">
		<oplamz:packageLength>
			<gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($base, '', 'PackageLength')}">
				<xsl:choose>
					<xsl:when test="contains(@Units , 'hundredths-inches')">
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select=". div 100"/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">INH</gr:hasUnitOfMeasurement>
						<rdfs:label><xsl:value-of select="concat(. div 100, ' (INH)')"/></rdfs:label>
					</xsl:when>
					<xsl:otherwise>
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select="."/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">
							<xsl:value-of select="@Units"/>
						</gr:hasUnitOfMeasurement>
						<rdfs:label><xsl:value-of select="concat(. , ' (', @Units, ')')"/></rdfs:label>
					</xsl:otherwise>
				</xsl:choose>
			</gr:QuantitativeValueFloat>
		</oplamz:packageLength>
    </xsl:template>

	<xsl:template match="amz:ItemAttributes/amz:PackageDimensions/amz:Width">
		<oplamz:packageWidth>
			<!-- Xalan
			<gr:QuantitativeValueFloat rdf:about="{concat ($base, '#', 'PackageWidth')}">
			-->
			<gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($base, '', 'PackageWidth')}">
				<xsl:choose>
					<xsl:when test="contains(@Units , 'hundredths-inches')">
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select=". div 100"/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">INH</gr:hasUnitOfMeasurement>
						<rdfs:label><xsl:value-of select="concat(. div 100, ' (INH)')"/></rdfs:label>
					</xsl:when>
					<xsl:otherwise>
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select="."/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">
							<xsl:value-of select="@Units"/>
						</gr:hasUnitOfMeasurement>
						<rdfs:label><xsl:value-of select="concat(. , ' (', @Units, ')')"/></rdfs:label>
					</xsl:otherwise>
				</xsl:choose>
			</gr:QuantitativeValueFloat>
		</oplamz:packageWidth>
    </xsl:template>

    <xsl:template match="amz:ItemAttributes/amz:ItemDimensions/Height">
		<oplamz:itemHeight>
			<gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($base, '', 'ItemHeight')}">
				<xsl:choose>
					<xsl:when test="contains(@Units , 'hundredths-inches')">
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select=". div 100"/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">INH</gr:hasUnitOfMeasurement>
						<rdfs:label><xsl:value-of select="concat(. div 100, ' (INH)')"/></rdfs:label>
					</xsl:when>
					<xsl:otherwise>
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select="."/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">
							<xsl:value-of select="@Units"/>
						</gr:hasUnitOfMeasurement>
						<rdfs:label><xsl:value-of select="concat(. , ' (', @Units, ')')"/></rdfs:label>
					</xsl:otherwise>
				</xsl:choose>
			</gr:QuantitativeValueFloat>
		</oplamz:itemHeight>
    </xsl:template>

    <xsl:template match="amz:ItemAttributes/amz:ItemDimensions/amz:Weight">
		<oplamz:itemWeight>
	  		<gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($base, '', 'ItemWeight')}">
				<xsl:choose>
					<xsl:when test="contains(@Units , 'hundredths-pounds')">
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select=". div 100"/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">LBR</gr:hasUnitOfMeasurement>
						<rdfs:label><xsl:value-of select="concat(. div 100, ' (LBR)')"/></rdfs:label>
					</xsl:when>
					<xsl:otherwise>
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select="."/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">
							<xsl:value-of select="@Units"/>
						</gr:hasUnitOfMeasurement>
						<rdfs:label><xsl:value-of select="concat(. , ' (', @Units, ')')"/></rdfs:label>
					</xsl:otherwise>
				</xsl:choose>
	  		</gr:QuantitativeValueFloat>
		</oplamz:itemWeight>
    </xsl:template>

    <xsl:template match="amz:ItemAttributes/amz:ItemDimensions/amz:Length">
		<oplamz:itemLength>
			<gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($base, '', 'ItemLength')}">
				<xsl:choose>
					<xsl:when test="contains(@Units , 'hundredths-inches')">
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select=". div 100"/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">INH</gr:hasUnitOfMeasurement>
						<rdfs:label><xsl:value-of select="concat(. div 100, ' (INH)')"/></rdfs:label>
					</xsl:when>
					<xsl:otherwise>
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select="."/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">
							<xsl:value-of select="@Units"/>
						</gr:hasUnitOfMeasurement>
						<rdfs:label><xsl:value-of select="concat(. , ' (', @Units, ')')"/></rdfs:label>
					</xsl:otherwise>
				</xsl:choose>
			</gr:QuantitativeValueFloat>
		</oplamz:itemLength>
    </xsl:template>

	<xsl:template match="amz:ItemAttributes/amz:ItemDimensions/amz:Width">
		<oplamz:itemWidth>
			<gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($base, '', 'ItemWidth')}">
				<xsl:choose>
					<xsl:when test="contains(@Units , 'hundredths-inches')">
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select=". div 100"/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">INH</gr:hasUnitOfMeasurement>
						<rdfs:label><xsl:value-of select="concat(. div 100, ' (INH)')"/></rdfs:label>
					</xsl:when>
					<xsl:otherwise>
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select="."/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">
							<xsl:value-of select="@Units"/>
						</gr:hasUnitOfMeasurement>
						<rdfs:label><xsl:value-of select="concat(. , ' (', @Units, ')')"/></rdfs:label>
					</xsl:otherwise>
				</xsl:choose>
			</gr:QuantitativeValueFloat>
		</oplamz:itemWidth>
    </xsl:template>

    <xsl:template match="amz:ItemAttributes/amz:image">
		<xsl:if test="string-length(.) &gt; 0">
	    	<xsl:element namespace="&oplamz;" name="image">
				<xsl:attribute name="rdf:resource">
		    		<xsl:value-of select="."/>
				</xsl:attribute>
	    	</xsl:element>
		</xsl:if>
    </xsl:template>

    <!-- BIBO OWL -->
    <xsl:template match="amz:ItemAttributes/amz:ASIN" mode="bibo">
		<bibo:asin><xsl:value-of select="."/></bibo:asin>
    </xsl:template>

    <xsl:template match="amz:ItemAttributes/amz:Author" mode="bibo">
      <bibo:authorList rdf:parseType="Collection">
        <rdf:Description rdf:about="{vi:proxyIRI ($base, '', 'Author')}">
	    <rdf:value><xsl:value-of select="."/></rdf:value>
	</rdf:Description>
      </bibo:authorList>
    </xsl:template>

    <xsl:template match="text()|@*"/>
    <xsl:template match="text()|@*" mode="offering" />
    <xsl:template match="text()|@*" mode="manufacturer" />
    <xsl:template match="text()|@*" mode="bibo" />

</xsl:stylesheet>
