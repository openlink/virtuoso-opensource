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


	<!-- Amazon provides a short URL http://www.amazon.com/o/ASIN/{asin} for each product  -->
    <xsl:variable name="resourceURL"><xsl:value-of select="vi:proxyIRI (concat ('http://www.amazon.com/o/ASIN/', $asin))"/></xsl:variable>
	<!-- Usual form used by cartridges:
    <xsl:variable name="resourceURL"><xsl:value-of select="vi:proxyIRI ($base)"/></xsl:variable>
	-->
    <xsl:variable name="base"><xsl:value-of select="concat ('http://www.amazon.com/o/ASIN/', $asin)"/></xsl:variable>
    <xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
	<!-- For testing with Xalan XSLT processor
  	<xsl:variable name="resourceURL" select="$base"/>
  	<xsl:variable  name="docIRI" select="$base"/>
  	<xsl:variable  name="docproxyIRI" select="$base"/>
  	-->

    <xsl:template match="/">
		<rdf:RDF>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
				<xsl:for-each select="//amz:CustomerReviews/amz:Review">
				  <!-- Xalan
				  <foaf:topic rdf:resource="{concat ($base, '#', 'Review_', amz:CustomerId)}"/>
				  -->
				  <foaf:topic rdf:resource="{vi:proxyIRI ($base, '', concat('Review_', amz:CustomerId))}"/>
				</xsl:for-each>
				<!-- See also 'shortcuts' below for foaf:topic links -->
				<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>

			<!--
            <rdf:Description rdf:about="{vi:proxyIRI ($base, '', 'Product')}">
			-->
            <rdf:Description rdf:about="{$resourceURL}">
			    <rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder" />
			    <rdf:type rdf:resource="&oplamz;Product" />
	    		<sioc:has_container rdf:resource="{$docproxyIRI}"/>
                <gr:hasMakeAndModel>
					<!-- Xalan
					<rdf:Description rdf:about="{concat ($base, '#', 'MakeAndModel')}">
					-->
					<rdf:Description rdf:about="{vi:proxyIRI ($base, '', 'MakeAndModel')}">
						<rdf:type rdf:resource="&gr;ProductOrServiceModel"/>
						<rdf:type rdf:resource="&oplamz;Product"/>

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

			<xsl:apply-templates select="//amz:Offer" mode="offering"/>
		</rdf:RDF>
    </xsl:template>

    <xsl:template match="amz:Offer" mode="offering">
		<xsl:element namespace="&gr;" name="Offering">
			<xsl:attribute name="rdf:about">
				<!-- Xalan
				<xsl:value-of select="concat ($base, '#', 'Offer_', position())"/>
				-->
				<xsl:value-of select="concat (vi:proxyIRI($base, '', 'Offer_'), position())"/>
			</xsl:attribute>
	    	<gr:hasBusinessFunction rdf:resource="&gr;Sell"/>
		    <gr:validFrom rdf:datatype="&xsd;dateTime"><xsl:value-of select="$currentDateTime"/></gr:validFrom>
	    	<gr:includes rdf:resource="{$resourceURL}"/>
			<!-- TO DO: Other delivery methods? -->
		    <gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModePickup"/>
			<gr:availableDeliveryMethods rdf:resource="&gr;UPS"/>
			<gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModeMail"/>
	    	<rdfs:label><xsl:value-of select="//amz:ItemAttributes/amz:Title"/></rdfs:label>
			<gr:hasEAN_UCC-13><xsl:value-of select="//amz:ItemAttributes/amz:EAN"/></gr:hasEAN_UCC-13>
			<oplamz:condition><xsl:value-of select="./amz:OfferAttributes/amz:Condition"/></oplamz:condition>
			<oplamz:conditionNote><xsl:value-of select="./amz:OfferAttributes/amz:ConditionNote"/></oplamz:conditionNote>
			<oplamz:availability><xsl:value-of select="./amz:OfferListing/amz:Availability"/></oplamz:availability>
			<oplamz:offerListingId><xsl:value-of select="./amz:OfferListing/amz:OfferListingId"/></oplamz:offerListingId>
			<oplamz:merchantId><xsl:value-of select="./amz:Merchant/amz:MerchantId"/></oplamz:merchantId>

			<gr:hasPriceSpecification>
				<!-- Xalan
		  		<gr:UnitPriceSpecification rdf:about="{concat ($base, '#', 'OfferPrice_', position())}">
				-->
		  		<gr:UnitPriceSpecification rdf:about="{concat(vi:proxyIRI ($base, '', 'OfferPrice_'), position())}">
					<rdfs:label>Offer price</rdfs:label>
					<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
            		<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="./amz:OfferListing/amz:Price/amz:Amount div 100"/></gr:hasCurrencyValue>
            		<gr:hasCurrency rdf:datatype="&xsd;string"><xsl:value-of select="./amz:OfferListing/amz:Price/amz:CurrencyCode"/></gr:hasCurrency>
          		</gr:UnitPriceSpecification>
			</gr:hasPriceSpecification>
		</xsl:element>

		<xsl:element namespace="&gr;" name="BusinessEntity">
			<xsl:attribute name='rdf:about'>
				<!-- Xalan
				<xsl:value-of select="concat ($base, '#', 'Vendor_', position())"/>
				-->
				<xsl:value-of select="concat (vi:proxyIRI($base, '', 'Vendor_'), position())"/>
			</xsl:attribute>
			<rdfs:comment>The legal agent making the offering</rdfs:comment>
			<!-- MERCHANTID_{merchant id} will be replaced by merchant name/nickname by cartridge hook function -->
		    <rdfs:label><xsl:value-of select="concat('MERCHANTID_', ./amz:Merchant/amz:MerchantId)"/></rdfs:label>
		    <gr:legalName><xsl:value-of select="concat('MERCHANTID_', ./amz:Merchant/amz:MerchantId)"/></gr:legalName>
		    <gr:offers>
				<xsl:attribute name='rdf:resource'>
					<!-- Xalan
					<xsl:value-of select="concat ($base, '#', 'Offer_', position())"/>
					-->
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
			<!-- Xalan
			<foaf:topic rdf:resource="{concat ($base, '#', 'Vendor_', position())}"/>
			<foaf:topic rdf:resource="{concat ($base, '#', 'Offer_', position())}"/>
			-->
		</rdf:Description>

    </xsl:template>

    <xsl:template match="amz:CustomerReviews/amz:AverageRating">
		<review:rating><xsl:value-of select="."/></review:rating>
    </xsl:template>

    <xsl:template match="amz:CustomerReviews/amz:Review">
		<review:hasReview>
			<!-- Xalan
			<review:Review rdf:about="{concat ($base, '#', 'Review_', amz:CustomerId)}">
			-->
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
			<!-- Xalan
			<gr:BusinessEntity rdf:about="{concat ($base, '#', 'Manufacturer')}">
			-->
			<gr:BusinessEntity rdf:about="{vi:proxyIRI ($base, '', 'Manufacturer')}">
				<rdfs:label>Manufacturer</rdfs:label>
				<gr:legalName><xsl:value-of select="."/></gr:legalName>
			</gr:BusinessEntity>
		</gr:hasManufacturer>
    </xsl:template>

    <xsl:template match="amz:Item/amz:ASIN">
		<oplamz:ASIN><xsl:value-of select="."/></oplamz:ASIN>
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
    </xsl:template>
    <xsl:template match="amz:ItemAttributes/amz:ProductGroup">
		<oplamz:productGroup><xsl:value-of select="."/></oplamz:productGroup>
    </xsl:template>

    <xsl:template match="amz:ItemAttributes/amz:ListPrice">
	    <!-- gr:hasPriceSpecification domain doesn't include gr:ProductOrService -->
		<oplamz:hasListPrice>
			<!-- Xalan
		  	<gr:UnitPriceSpecification rdf:about="{concat ($base, '#', 'ListPrice')}">
			-->
			<gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($base, '', 'ListPrice')}">
				<rdfs:label>List price</rdfs:label>
				<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
           		<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="amz:Amount div 100"/></gr:hasCurrencyValue>
           		<gr:hasCurrency rdf:datatype="&xsd;string"><xsl:value-of select="amz:CurrencyCode"/></gr:hasCurrency>
          	</gr:UnitPriceSpecification>
		</oplamz:hasListPrice>
    </xsl:template>

    <xsl:template match="amz:ItemAttributes/amz:Feature">
		<oplamz:feature><xsl:value-of select="."/></oplamz:feature>
    </xsl:template>

    <xsl:template match="amz:ItemAttributes/amz:PackageDimensions/Height">
		<oplamz:packageHeight>
			<!-- Xalan
			<gr:QuantitativeValueFloat rdf:about="{concat ($base, '#', 'PackageHeight')}">
			-->
			<gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($base, '', 'PackageHeight')}">
				<xsl:choose>
					<xsl:when test="contains(@Units , 'hundredths-inches')">
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select=". div 100"/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">INH</gr:hasUnitOfMeasurement>
					</xsl:when>
					<xsl:otherwise>
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select="."/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">
							<xsl:value-of select="@Units"/>
						</gr:hasUnitOfMeasurement>
					</xsl:otherwise>
				</xsl:choose>
			</gr:QuantitativeValueFloat>
		</oplamz:packageHeight>
    </xsl:template>

    <xsl:template match="amz:ItemAttributes/amz:PackageDimensions/amz:Weight">
		<oplamz:packageWeight>
			<!-- Xalan
	  		<gr:QuantitativeValueFloat rdf:about="{concat ($base, '#', 'PackageWeight')}">
			-->
	  		<gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($base, '', 'PackageWeight')}">
				<xsl:choose>
					<xsl:when test="contains(@Units , 'hundredths-pounds')">
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select=". div 100"/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">LBR</gr:hasUnitOfMeasurement>
					</xsl:when>
					<xsl:otherwise>
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select="."/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">
							<xsl:value-of select="@Units"/>
						</gr:hasUnitOfMeasurement>
					</xsl:otherwise>
				</xsl:choose>
	  		</gr:QuantitativeValueFloat>
		</oplamz:packageWeight>
    </xsl:template>

    <xsl:template match="amz:ItemAttributes/amz:PackageDimensions/amz:Length">
		<oplamz:packageLength>
			<!-- Xalan
			<gr:QuantitativeValueFloat rdf:about="{concat ($base, '#', 'PackageLength')}">
			-->
			<gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($base, '', 'PackageLength')}">
				<xsl:choose>
					<xsl:when test="contains(@Units , 'hundredths-inches')">
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select=". div 100"/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">INH</gr:hasUnitOfMeasurement>
					</xsl:when>
					<xsl:otherwise>
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select="."/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">
							<xsl:value-of select="@Units"/>
						</gr:hasUnitOfMeasurement>
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
					</xsl:when>
					<xsl:otherwise>
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select="."/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">
							<xsl:value-of select="@Units"/>
						</gr:hasUnitOfMeasurement>
					</xsl:otherwise>
				</xsl:choose>
			</gr:QuantitativeValueFloat>
		</oplamz:packageWidth>
    </xsl:template>

    <xsl:template match="amz:ItemAttributes/amz:ItemDimensions/Height">
		<oplamz:itemHeight>
			<!-- Xalan
			<gr:QuantitativeValueFloat rdf:about="{concat ($base, '#', 'ItemHeight')}">
			-->
			<gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($base, '', 'ItemHeight')}">
				<xsl:choose>
					<xsl:when test="contains(@Units , 'hundredths-inches')">
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select=". div 100"/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">INH</gr:hasUnitOfMeasurement>
					</xsl:when>
					<xsl:otherwise>
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select="."/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">
							<xsl:value-of select="@Units"/>
						</gr:hasUnitOfMeasurement>
					</xsl:otherwise>
				</xsl:choose>
			</gr:QuantitativeValueFloat>
		</oplamz:itemHeight>
    </xsl:template>

    <xsl:template match="amz:ItemAttributes/amz:ItemDimensions/amz:Weight">
		<oplamz:itemWeight>
			<!-- Xalan
	  		<gr:QuantitativeValueFloat rdf:about="{concat ($base, '#', 'ItemWeight')}">
			-->
	  		<gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($base, '', 'ItemWeight')}">
				<xsl:choose>
					<xsl:when test="contains(@Units , 'hundredths-pounds')">
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select=". div 100"/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">LBR</gr:hasUnitOfMeasurement>
					</xsl:when>
					<xsl:otherwise>
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select="."/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">
							<xsl:value-of select="@Units"/>
						</gr:hasUnitOfMeasurement>
					</xsl:otherwise>
				</xsl:choose>
	  		</gr:QuantitativeValueFloat>
		</oplamz:itemWeight>
    </xsl:template>

    <xsl:template match="amz:ItemAttributes/amz:ItemDimensions/amz:Length">
		<oplamz:itemLength>
			<!-- Xalan
			<gr:QuantitativeValueFloat rdf:about="{concat ($base, '#', 'ItemLength')}">
			-->
			<gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($base, '', 'ItemLength')}">
				<xsl:choose>
					<xsl:when test="contains(@Units , 'hundredths-inches')">
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select=". div 100"/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">INH</gr:hasUnitOfMeasurement>
					</xsl:when>
					<xsl:otherwise>
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select="."/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">
							<xsl:value-of select="@Units"/>
						</gr:hasUnitOfMeasurement>
					</xsl:otherwise>
				</xsl:choose>
			</gr:QuantitativeValueFloat>
		</oplamz:itemLength>
    </xsl:template>

	<xsl:template match="amz:ItemAttributes/amz:ItemDimensions/amz:Width">
		<oplamz:itemWidth>
			<!-- Xalan
			<gr:QuantitativeValueFloat rdf:about="{concat ($base, '#', 'ItemWidth')}">
			-->
			<gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($base, '', 'ItemWidth')}">
				<xsl:choose>
					<xsl:when test="contains(@Units , 'hundredths-inches')">
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select=". div 100"/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">INH</gr:hasUnitOfMeasurement>
					</xsl:when>
					<xsl:otherwise>
						<gr:hasValueFloat rdf:datatype="&xsd;float">
							<xsl:value-of select="."/>
						</gr:hasValueFloat>
						<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">
							<xsl:value-of select="@Units"/>
						</gr:hasUnitOfMeasurement>
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


    <!--xsl:template match="amz:ItemAttributes/amz:Author" mode="bibo">
        <dcterms:contributor>
			<foaf:Person rdf:about="{vi:proxyIRI ($base, '', 'Author')}">
				<foaf:name><xsl:value-of select="."/></foaf:name>
			</foaf:Person>
			<bibo:role rdf:resource="&bibo;author"/>
        </dcterms:contributor>
    </xsl:template-->

    <xsl:template match="text()|@*"/>
    <xsl:template match="text()|@*" mode="offering" />
    <xsl:template match="text()|@*" mode="manufacturer" />
    <xsl:template match="text()|@*" mode="bibo" />

</xsl:stylesheet>
