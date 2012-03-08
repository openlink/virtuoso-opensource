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
<!ENTITY pto "http://www.productontology.org/id/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY vcard "http://www.w3.org/2001/vcard-rdf/3.0#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY cl "http://www.ebusiness-unibw.org/ontologies/consumerelectronics/v1#">
<!ENTITY oplbb "http://www.openlinksw.com/schemas/bestbuy#">
]>

<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:vcard="&vcard;"	
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:sioc="&sioc;"
    xmlns:owl="&owl;"
    xmlns:dcterms="&dcterms;"
    xmlns:pto="&pto;" 
    xmlns:gr="&gr;"
    xmlns:bestbuy="http://remix.bestbuy.com/"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:cl="&cl;"
    xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"	
    xmlns:opl="&opl;"
    xmlns:oplbb="&oplbb;"
    version="1.0">

    <xsl:output method="xml" indent="yes" />
    <xsl:param name="baseUri"/>
    <xsl:param name="currentDateTime"/>
    <xsl:param name="is_store"/>
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
  <xsl:variable name="quote">
    <xsl:text>"</xsl:text>
  </xsl:variable>

    <xsl:template match="/">
		<rdf:RDF>
			<xsl:choose>
				<xsl:when test="$is_store = '1'">
					<rdf:Description rdf:about="{$docproxyIRI}">
						<rdf:type rdf:resource="&bibo;Document"/>
						<sioc:container_of rdf:resource="{$resourceURL}"/>
						<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
						<dcterms:subject rdf:resource="{$resourceURL}"/>
					</rdf:Description>
					<gr:Location rdf:about="{$resourceURL}">
                  				<opl:providedBy>
                  					<foaf:Organization rdf:about="http://www.bestbuy.com#this">
                  						<foaf:name>BestBuy</foaf:name>
                  						<foaf:homepage rdf:resource="http://www.bestbuy.com"/>
                  					</foaf:Organization>
                  				</opl:providedBy>
						<gr:hasOpeningHoursSpecification>
							<gr:OpeningHoursSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'OpenHoursSpecification')}">
                <gr:opens>
                  <xsl:value-of select="/stores/store/hours"/>
                </gr:opens>
							</gr:OpeningHoursSpecification>
						</gr:hasOpeningHoursSpecification>
            <rdfs:label>
              <xsl:value-of select="/stores/store/longName"/>
            </rdfs:label>
            <gr:name>
              <xsl:value-of select="/stores/store/name"/>
            </gr:name>
            <gr:legalName>
              <xsl:value-of select="/stores/store/longName"/>
            </gr:legalName>
						<geo:lat rdf:datatype="&xsd;float">
							<xsl:value-of select="/stores/store/lat"/>
						</geo:lat>
						<geo:long rdf:datatype="&xsd;float">
							<xsl:value-of select="/stores/store/lng"/>
						</geo:long>
						<foaf:phone rdf:resource="tel:{/stores/store/phone}"/>
						<vcard:ADR>
							<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', 'Address')}">
								<rdf:type rdf:resource="&vcard;ADR"/>
								<vcard:Locality>
									<xsl:value-of select="/stores/store/city" />
								</vcard:Locality>
								<vcard:Region>
									<xsl:value-of select="/stores/store/region"/>
								</vcard:Region>
								<vcard:Country>
									<xsl:value-of select="/stores/store/country"/>
								</vcard:Country>
								<vcard:Pcode>
									<xsl:value-of select="/stores/store/postalCode"/>
								</vcard:Pcode>
								<vcard:Extadd>
									<xsl:value-of select="/stores/store/address"/>
								</vcard:Extadd>
								<rdfs:label><xsl:value-of select="vi:trim(concat(/stores/store/address, ', ', /stores/store/city, ', ', /stores/store/postalCode, ', ', /stores/store/country), ', ')"/></rdfs:label>
							</rdf:Description>
						</vcard:ADR>
					</gr:Location>
				</xsl:when>
				<xsl:otherwise>
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
                  					<foaf:Organization rdf:about="http://www.bestbuy.com#this">
                  						<foaf:name>BestBuy</foaf:name>
                  						<foaf:homepage rdf:resource="http://www.bestbuy.com"/>
                  					</foaf:Organization>
                  				</opl:providedBy>
			    <sioc:has_container rdf:resource="{$docproxyIRI}"/>
			    <gr:hasBusinessFunction rdf:resource="&gr;Sell"/>
            <rdfs:label>
              <xsl:value-of select="concat('Offer: ', //product/name)"/>
            </rdfs:label>
			    <!-- For testing with standalone XSLT processor
			    <gr:includes rdf:resource="{concat ($baseUri, '#', 'Product')}"/>
			    -->
			    <gr:includes rdf:resource="{vi:proxyIRI ($baseUri, '', 'Product')}"/>
            <gr:validFrom rdf:datatype="&xsd;dateTime">
              <xsl:value-of select="$currentDateTime"/>
            </gr:validFrom>
			    <gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModePickup"/>
			    <gr:availableDeliveryMethods rdf:resource="&gr;UPS"/>
			    <gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModeMail"/>
			    <xsl:apply-templates mode="offering" />
			</gr:Offering>

			<!-- For testing with standalone XSLT processor
	                <gr:BusinessEntity rdf:about="{concat ($baseUri, '#', 'Vendor')}">
			 -->
	                <gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Vendor')}">
			  <rdfs:comment>The legal agent making the offering</rdfs:comment>
		          <rdfs:label>BestBuy Co., Inc.</rdfs:label>
		          <gr:legalName>BestBuy Co., Inc.</gr:legalName>
		          <gr:offers rdf:resource="{$resourceURL}"/>
			  <foaf:homepage rdf:resource="http://www.bestbuy.com" />
			  <owl:sameAs rdf:resource="http://products.semweb.bestbuy.com/company.rdf#BusinessEntity_BestBuy" />
			  <rdfs:seeAlso rdf:resource="{vi:proxyIRI ('http://www.bestbuy.com')}"/>
	                </gr:BusinessEntity>

			<!-- For testing with standalone XSLT processor
			<rdf:Description rdf:about="{concat ($baseUri, '#', 'Product')}">
			-->
			<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', 'Product')}">
                  				<opl:providedBy>
                  					<foaf:Organization rdf:about="http://www.bestbuy.com#this">
                  						<foaf:name>BestBuy</foaf:name>
                  						<foaf:homepage rdf:resource="http://www.bestbuy.com"/>
                  					</foaf:Organization>
                  				</opl:providedBy>
			    <rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder" />
			    <rdf:type rdf:resource="&oplbb;Product" />
            
            <gr:hasBrand rdf:resource="{vi:proxyIRI ($baseUri, '', 'Brand')}" />
            
                            <gr:hasMakeAndModel>
			        <!-- For testing with standalone XSLT processor
	                        <rdf:Description rdf:about="{concat ($baseUri, '#', 'MakeAndModel')}">
			        -->
	                        <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', 'MakeAndModel')}">
	                            <rdf:type rdf:resource="&gr;ProductOrServiceModel"/>
	                            <rdf:type rdf:resource="&oplbb;Product"/>
				    <xsl:apply-templates select="//product" mode="manufacturer" /> 
		                   <!-- TO DO
		                   <rdfs:comment>!!#{manufacturer} #{modelNumber}</rdfs:comment>
		                   -->
	                       </rdf:Description>
	                   </gr:hasMakeAndModel>
			   <xsl:apply-templates select="//product" />
			</rdf:Description>
	  <xsl:apply-templates select="//product/manufacturer" mode="brand" />
				</xsl:otherwise>
			</xsl:choose>
		</rdf:RDF>
    </xsl:template>

    <xsl:template match="product">
        <xsl:apply-templates select="*"/>
    </xsl:template>

    <!-- mode offering handles attributes which are part of the offering rather than the product itself -->

    <xsl:template match="regularPrice" mode="offering">
	<gr:hasPriceSpecification>
	    <!-- For testing with standalone XSLT processor
	    <gr:UnitPriceSpecification rdf:about="{concat ($baseUri, '#', 'UnitPriceSpecification')}">
	    -->
	    <gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'UnitPriceSpecification')}">
	        <rdfs:label>
			<xsl:value-of select="concat( ., ' (USD)')"/>	
		</rdfs:label>
		<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
        <gr:hasCurrencyValue rdf:datatype="&xsd;float">
          <xsl:value-of select="."/>
        </gr:hasCurrencyValue>
		<gr:hasCurrency rdf:datatype="&xsd;string">USD</gr:hasCurrency>
	        <gr:priceType rdf:datatype="&xsd;string">regular price</gr:priceType>
	    </gr:UnitPriceSpecification>
	</gr:hasPriceSpecification>
    </xsl:template>

    <xsl:template match="salePrice" mode="offering">
        <gr:hasPriceSpecification>
	    <!-- For testing with standalone XSLT processor
	    <gr:UnitPriceSpecification rdf:about="{concat ($baseUri, '#', 'UnitPriceSpecification_SRP')}">
	    -->
	    <gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'UnitPriceSpecification_SRP')}">
	        <rdfs:label>
			<xsl:value-of select="concat( ., ' (USD)')"/>	
		</rdfs:label>
		<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
        <gr:hasCurrencyValue rdf:datatype="&xsd;float">
          <xsl:value-of select="."/>
        </gr:hasCurrencyValue>
	        <gr:hasCurrency rdf:datatype="&xsd;string">USD</gr:hasCurrency>
	        <gr:priceType rdf:datatype="&xsd;string">suggested retail price</gr:priceType>
	    </gr:UnitPriceSpecification>
	</gr:hasPriceSpecification>
    </xsl:template>

    <xsl:template match="shippingCost" mode="offering">
        <gr:hasPriceSpecification>
	    <!-- For testing with standalone XSLT processor
	    <gr:DeliveryChargeSpecification rdf:about="{concat ($baseUri, '#', 'DeliveryChargeSpecification')}">
	    -->
	    <gr:DeliveryChargeSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'DeliveryChargeSpecification')}">
	        <rdfs:label>
			<xsl:value-of select="concat('shipping charge: ', ., ' (USD)')"/>	
		</rdfs:label>
		<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
        <gr:hasCurrencyValue rdf:datatype="&xsd;float">
          <xsl:value-of select="."/>
        </gr:hasCurrencyValue>
	        <gr:hasCurrency rdf:datatype="&xsd;string">USD</gr:hasCurrency>
		<gr:eligibleRegions rdf:datatype="&xsd;string">US</gr:eligibleRegions>
	        <gr:priceType rdf:datatype="&xsd;string">shipping price</gr:priceType>
	    </gr:DeliveryChargeSpecification>
	</gr:hasPriceSpecification>
    </xsl:template>

    <xsl:template match="product/freeShipping" mode="offering">
    <oplbb:freeShipping rdf:datatype="&xsd;boolean">
      <xsl:value-of select="."/>
    </oplbb:freeShipping>
    </xsl:template>

    <xsl:template match="product/name">
		<rdfs:label>
			<xsl:value-of select="."/>
		</rdfs:label>
		<gr:name>
			<xsl:value-of select="."/>
		</gr:name>
    </xsl:template>

    <xsl:template match="product/dollarSavings" mode="offering">
	<oplbb:dollarSaving>
	    <!-- For testing with standalone XSLT processor
	    <gr:QuantitativeValueFloat rdf:about="{concat ($baseUri, '#', 'DollarSaving')}">
	    -->
	    <gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($baseUri, '', 'DollarSaving')}">
	        <rdfs:label>
			<xsl:value-of select="concat(., ' (USD)')"/>	
		</rdfs:label>
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">USD</gr:hasUnitOfMeasurement>
        <gr:hasValueFloat rdf:datatype="&xsd;float">
          <xsl:value-of select="."/>
        </gr:hasValueFloat>
	    </gr:QuantitativeValueFloat>
	</oplbb:dollarSaving>
    </xsl:template>

    <xsl:template match="product/onlineAvailability" mode="offering">
    <oplbb:onlineAvailability rdf:datatype="&xsd;boolean">
      <xsl:value-of select="."/>
    </oplbb:onlineAvailability>
    </xsl:template>

    <xsl:template match="product/onlineAvailabilityText" mode="offering">
    <oplbb:onlineAvailabilityText rdf:datatype="&xsd;string">
      <xsl:value-of select="."/>
    </oplbb:onlineAvailabilityText>
    </xsl:template>

    <xsl:template match="product/specialOrder" mode="offering">
    <oplbb:specialOrder rdf:datatype="&xsd;boolean">
      <xsl:value-of select="."/>
    </oplbb:specialOrder>
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
    <rdfs:comment>
      <xsl:value-of select="."/>
    </rdfs:comment>
    </xsl:template>
  
    <xsl:template match="product/description">
    <oplbb:description rdf:datatype="&xsd;string">
      <xsl:value-of select="."/>
    </oplbb:description>
    </xsl:template>
  
    <xsl:template match="product/longDescription">
    <oplbb:longDescription rdf:datatype="&xsd;string">
      <xsl:value-of select="."/>
    </oplbb:longDescription>
    </xsl:template>
  
    <xsl:template match="product/upc">
    <gr:hasEAN_UCC-13>
      <xsl:value-of select="concat('0', .)"/>
    </gr:hasEAN_UCC-13>
    </xsl:template>
  
    <xsl:template match="product/startDate">
    <oplbb:dateReleased rdf:datatype="&xsd;date">
      <xsl:value-of select="."/>
    </oplbb:dateReleased>
    </xsl:template>
  
    <xsl:template match="product/productId">
    <oplbb:productId>
      <xsl:value-of select="."/>
    </oplbb:productId>
    </xsl:template>
  
    <xsl:template match="product/sku">
    <oplbb:sku>
      <xsl:value-of select="."/>
    </oplbb:sku>
    <gr:hasStockKeepingUnit>
      <xsl:value-of select="."/>
    </gr:hasStockKeepingUnit>
    </xsl:template>
  
    <xsl:template match="product/onSale">
    <oplbb:onSale rdf:datatype="&xsd;boolean">
      <xsl:value-of select="."/>
    </oplbb:onSale>
    </xsl:template>
  
    <xsl:template match="product/color">
    <oplbb:color rdf:datatype="&xsd;string">
      <xsl:value-of select="."/>
    </oplbb:color>
    </xsl:template>
  
    <xsl:template match="product/format">
    <oplbb:format rdf:datatype="&xsd;string">
      <xsl:value-of select="."/>
    </oplbb:format>
    </xsl:template>
  
    <xsl:template match="product/features/feature">
    <oplbb:feature rdf:datatype="&xsd;string">
      <xsl:value-of select="."/>
    </oplbb:feature>
    </xsl:template>
  
    <xsl:template match="product/categoryPath/category/name">
    <oplbb:category>
      <xsl:value-of select="."/>
    </oplbb:category>
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
	    <!-- For testing with standalone XSLT processor
	    <gr:BusinessEntity rdf:about="{concat ($baseUri, '#', 'Manufacturer')}">
	    -->
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

  <xsl:template match="//product/manufacturer" mode="brand">
    <gr:Brand rdf:about="{vi:proxyIRI ($baseUri, '', 'Brand')}">
      <xsl:variable name="brand" select="normalize-space(./text())" />
      <gr:name><xsl:value-of select="$brand"/></gr:name>
      <rdfs:label><xsl:value-of select="$brand"/></rdfs:label>
      <rdfs:seeAlso rdf:resource="{vi:proxyIRI ($baseUri, '', 'Manufacturer')}" />
    </gr:Brand>
  </xsl:template>
  
    <xsl:template match="product/manufacturer">
	<rdf:type rdf:resource="{concat('&pto;', .)}" />
    </xsl:template>

    <xsl:template match="product/details/detail">
	<oplbb:detail>
	    <xsl:element namespace="&oplbb;" name="ProductDetail">
        <xsl:attribute name="rdf:about">
		    <!-- For testing with standalone XSLT processor
	            <xsl:value-of select="concat(concat ($baseUri, '#', 'Detail_'), position())"/>
		    -->
	            <xsl:value-of select="concat(vi:proxyIRI ($baseUri, '', 'Detail_'), position())"/>
		</xsl:attribute>
        <oplbb:detail_name rdf:datatype="&xsd;string">
          <xsl:value-of select="./name"/>
        </oplbb:detail_name>
        <oplbb:detail_value rdf:datatype="&xsd;string">
          <xsl:value-of select="./value"/>
        </oplbb:detail_value>
	    </xsl:element>
	</oplbb:detail>
    </xsl:template>

    <xsl:template match="product/weight">
    <oplbb:weight>
      <!-- or cl:hasWeight -->
	  <!-- For testing with standalone XSLT processor
	  <gr:QuantitativeValueFloat rdf:about="{concat ($baseUri, '#', 'Weight')}">
	  -->
	  <gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($baseUri, '', 'Weight')}">
	    <xsl:choose>
	      <xsl:when test="contains(. , 'lb')">
	        <gr:hasValueFloat rdf:datatype="&xsd;float">
	          <xsl:value-of select="normalize-space(substring-before(., 'lb'))"/>
		</gr:hasValueFloat>
            <rdfs:label>
              <xsl:value-of select="concat(normalize-space(substring-before(., 'lb')), ' (LBR)')"/>
            </rdfs:label>
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">LBR</gr:hasUnitOfMeasurement>
	      </xsl:when>
	      <xsl:when test="contains(. , 'oz')">
	        <gr:hasValueFloat rdf:datatype="&xsd;float">
	          <xsl:value-of select="normalize-space(substring-before(., 'oz'))"/>
		</gr:hasValueFloat>
            <rdfs:label>
              <xsl:value-of select="concat(normalize-space(substring-before(., 'oz')), ' (ONZ)')"/>
            </rdfs:label>
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">ONZ</gr:hasUnitOfMeasurement>
	      </xsl:when>
	      <xsl:otherwise>
	        <gr:hasValueFloat rdf:datatype="&xsd;float">
	          <xsl:value-of select="."/>
		</gr:hasValueFloat>
            <rdfs:label>
              <xsl:value-of select="concat(., ' (LBR)')"/>
            </rdfs:label>
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">LBR</gr:hasUnitOfMeasurement>
	      </xsl:otherwise>
	    </xsl:choose>
	  </gr:QuantitativeValueFloat>
	</oplbb:weight>
    </xsl:template>

    <xsl:template match="product/shippingWeight">
    <oplbb:shippingWeight>
      <!-- or cl -->
	  <!-- For testing with standalone XSLT processor
	  <gr:QuantitativeValueFloat rdf:about="{concat ($baseUri, '#', 'ShippingWeight')}">
	  -->
	  <gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($baseUri, '', 'ShippingWeight')}">
	    <xsl:choose>
	      <xsl:when test="contains(. , 'lb')">
	        <gr:hasValueFloat rdf:datatype="&xsd;float">
	          <xsl:value-of select="normalize-space(substring-before(., 'lb'))"/>
		</gr:hasValueFloat>
            <rdfs:label>
              <xsl:value-of select="concat(normalize-space(substring-before(., 'lb')), ' (LBR)')"/>
            </rdfs:label>
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">LBR</gr:hasUnitOfMeasurement>
	      </xsl:when>
	      <xsl:when test="contains(. , 'oz')">
	        <gr:hasValueFloat rdf:datatype="&xsd;float">
	          <xsl:value-of select="normalize-space(substring-before(., 'oz'))"/>
		</gr:hasValueFloat>
            <rdfs:label>
              <xsl:value-of select="concat(normalize-space(substring-before(., 'oz')), ' (ONZ)')"/>
            </rdfs:label>
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">ONZ</gr:hasUnitOfMeasurement>
	      </xsl:when>
	      <xsl:otherwise>
	        <gr:hasValueFloat rdf:datatype="&xsd;float">
	          <xsl:value-of select="."/>
		</gr:hasValueFloat>
            <rdfs:label>
              <xsl:value-of select="concat(., ' (LBR)')"/>
            </rdfs:label>
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">LBR</gr:hasUnitOfMeasurement>
	      </xsl:otherwise>
	    </xsl:choose>
	  </gr:QuantitativeValueFloat>
	</oplbb:shippingWeight>
    </xsl:template>

    <xsl:template match="product/height">
    <oplbb:height>
      <!-- or cl:hasHeight -->
	  <!-- For testing with standalone XSLT processor
	  <gr:QuantitativeValueFloat rdf:about="{concat ($baseUri, '#', 'Height')}">
	  -->
	  <gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($baseUri, '', 'Height')}">
	    <xsl:choose>
	      <xsl:when test="contains(. , $quote)">
	        <gr:hasValueFloat rdf:datatype="&xsd;float">
	          <xsl:value-of select="normalize-space(substring-before(., $quote))"/>
		</gr:hasValueFloat>
            <rdfs:label>
              <xsl:value-of select="concat(normalize-space(substring-before(., $quote)), ' (INH)')"/>
            </rdfs:label>
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">INH</gr:hasUnitOfMeasurement>
	      </xsl:when>
	      <xsl:when test="contains(. , 'in')">
	        <gr:hasValueFloat rdf:datatype="&xsd;float">
	          <xsl:value-of select="normalize-space(substring-before(., 'in'))"/>
		</gr:hasValueFloat>
            <rdfs:label>
              <xsl:value-of select="concat(normalize-space(substring-before(., 'in')), ' (INH)')"/>
            </rdfs:label>
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">INH</gr:hasUnitOfMeasurement>
	      </xsl:when>
	      <xsl:otherwise>
	        <gr:hasValueFloat rdf:datatype="&xsd;float">
	          <xsl:value-of select="."/>
		</gr:hasValueFloat>
            <rdfs:label>
              <xsl:value-of select="concat(., ' (INH)')"/>
            </rdfs:label>
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">INH</gr:hasUnitOfMeasurement>
	      </xsl:otherwise>
	    </xsl:choose>
	  </gr:QuantitativeValueFloat>
	</oplbb:height>
    </xsl:template>

    <xsl:template match="product/depth">
    <oplbb:depth>
      <!-- or cl:hasDepth -->
	  <!-- For testing with standalone XSLT processor
	  <gr:QuantitativeValueFloat rdf:about="{concat ($baseUri, '#', 'Depth')}">
	  -->
	  <gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($baseUri, '', 'Depth')}">
	    <xsl:choose>
	      <xsl:when test="contains(. , $quote)">
	        <gr:hasValueFloat rdf:datatype="&xsd;float">
	          <xsl:value-of select="normalize-space(substring-before(., $quote))"/>
		</gr:hasValueFloat>
            <rdfs:label>
              <xsl:value-of select="concat(normalize-space(substring-before(., $quote)), ' (INH)')"/>
            </rdfs:label>
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">INH</gr:hasUnitOfMeasurement>
	      </xsl:when>
	      <xsl:when test="contains(. , 'in')">
	        <gr:hasValueFloat rdf:datatype="&xsd;float">
	          <xsl:value-of select="normalize-space(substring-before(., 'in'))"/>
		</gr:hasValueFloat>
            <rdfs:label>
              <xsl:value-of select="concat(normalize-space(substring-before(., 'in')), ' (INH)')"/>
            </rdfs:label>
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">INH</gr:hasUnitOfMeasurement>
	      </xsl:when>
	      <xsl:otherwise>
	        <gr:hasValueFloat rdf:datatype="&xsd;float">
	          <xsl:value-of select="."/>
		</gr:hasValueFloat>
            <rdfs:label>
              <xsl:value-of select="concat(., ' (INH)')"/>
            </rdfs:label>
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">INH</gr:hasUnitOfMeasurement>
	      </xsl:otherwise>
	    </xsl:choose>
	  </gr:QuantitativeValueFloat>
	</oplbb:depth>
    </xsl:template>

    <xsl:template match="product/width">
    <oplbb:width>
      <!-- or cl:hasWidth -->
	  <!-- For testing with standalone XSLT processor
	  <gr:QuantitativeValueFloat rdf:about="{concat ($baseUri, '#', 'Width')}">
	  -->
	  <gr:QuantitativeValueFloat rdf:about="{vi:proxyIRI ($baseUri, '', 'Width')}">
	    <xsl:choose>
	      <xsl:when test="contains(. , $quote)">
	        <gr:hasValueFloat rdf:datatype="&xsd;float">
	          <xsl:value-of select="normalize-space(substring-before(., $quote))"/>
		</gr:hasValueFloat>
            <rdfs:label>
              <xsl:value-of select="concat(normalize-space(substring-before(., $quote)), ' (INH)')"/>
            </rdfs:label>
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">INH</gr:hasUnitOfMeasurement>
	      </xsl:when>
	      <xsl:when test="contains(. , 'in')">
	        <gr:hasValueFloat rdf:datatype="&xsd;float">
	          <xsl:value-of select="normalize-space(substring-before(., 'in'))"/>
		</gr:hasValueFloat>
            <rdfs:label>
              <xsl:value-of select="concat(normalize-space(substring-before(., 'in')), ' (INH)')"/>
            </rdfs:label>
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">INH</gr:hasUnitOfMeasurement>
	      </xsl:when>
	      <xsl:otherwise>
	        <gr:hasValueFloat rdf:datatype="&xsd;float">
	          <xsl:value-of select="."/>
		</gr:hasValueFloat>
            <rdfs:label>
              <xsl:value-of select="concat(., ' (INH)')"/>
            </rdfs:label>
		<gr:hasUnitOfMeasurement rdf:datatype="&xsd;string">INH</gr:hasUnitOfMeasurement>
	      </xsl:otherwise>
	    </xsl:choose>
	  </gr:QuantitativeValueFloat>
	</oplbb:width>
    </xsl:template>

    <xsl:template match="text()|@*"/>
  
    <xsl:template match="text()|@*" mode="offering" />

  <xsl:template match="text()|@*" mode="manufacturer"/>
</xsl:stylesheet>

