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
<!ENTITY pto "http://www.productontology.org/id/">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY review "http:/www.purl.org/stuff/rev#">
<!ENTITY ebay "urn:ebay:apis:eBLBaseComponents">
<!ENTITY oplebay "http://www.openlinksw.com/schemas/ebay#">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:sioc="&sioc;"
    xmlns:pto="&pto;" 
    xmlns:gr="&gr;"
    xmlns:book="&book;"
    xmlns:opl="&opl;"
    xmlns:dc="&dc;"
    xmlns:dcterms="&dcterms;"
    xmlns:review="&review;"
    xmlns:owl="&owl;"
    xmlns:cl="&cl;"
    xmlns:ebay="&ebay;"
    xmlns:oplebay="&oplebay;"
    >

    <xsl:output method="xml" indent="yes" encoding="utf-8" />

    <xsl:param name="baseUri"/>
	<xsl:param name="currentDateTime"/>

    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
	<!-- For testing with Xalan XSLT processor
  	<xsl:variable name="resourceURL" select="$baseUri"/>
  	<xsl:variable  name="docIRI" select="$baseUri"/>
  	<xsl:variable  name="docproxyIRI" select="$baseUri"/>
	-->

    <xsl:template match="/ebay:GetSingleItemResponse">
		<rdf:RDF>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<rdf:type rdf:resource="&bibo;Document"/>
				<dc:title><xsl:value-of select="$baseUri"/></dc:title>
                <rdfs:label><xsl:value-of select="$baseUri"/></rdfs:label>
				<sioc:container_of rdf:resource="{$resourceURL}"/>
				<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			    <foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', 'Vendor')}"/>
			    <foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', 'Offer')}"/>
				<!-- Xalan
			    <foaf:topic rdf:resource="{concat ($baseUri, '#', 'Vendor')}"/>
			    <foaf:topic rdf:resource="{concat ($baseUri, '#', 'Offer')}"/>
				-->
				<dcterms:subject rdf:resource="{$resourceURL}"/>
				<owl:sameAs rdf:resource="{$docIRI}"/>
			</rdf:Description>

			<!-- Xalan
			<gr:Offering rdf:about="{concat ($baseUri, '#', 'Offer')}">
			-->
			<gr:Offering rdf:about="{vi:proxyIRI($baseUri, '', 'Offer')}">
                         	<opl:providedBy>
                         		<foaf:Organization rdf:about="http://www.ebay.com#this">
                         			<foaf:name>Ebay</foaf:name>
                         			<foaf:homepage rdf:resource="http://www.ebay.com"/>
                         		</foaf:Organization>
                         	</opl:providedBy>

			    <gr:hasBusinessFunction rdf:resource="&gr;Sell"/>
			    <rdfs:label><xsl:value-of select="ebay:Item/ebay:Title"/></rdfs:label>
				<!-- Xalan
			    <gr:includes rdf:resource="{$resourceURL}"/>
				-->
			    <gr:includes rdf:resource="{$resourceURL}"/>
			    <gr:validFrom rdf:datatype="&xsd;dateTime"><xsl:value-of select="$currentDateTime"/></gr:validFrom>
			    <gr:validThrough rdf:datatype="&xsd;dateTime"><xsl:value-of select="ebay:Item/ebay:EndTime"/></gr:validThrough>
                <gr:acceptedPaymentMethods rdf:resource="{concat('&gr;', ebay:Item/ebay:PaymentMethods)}"/>
			    <gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModePickup"/>
			    <xsl:if test="count(//ebay:ShipToLocations) = 1">
			    	<!--gr:availableDeliveryMethods rdf:resource="&gr;UPS"/-->
			    	<gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModeMail"/>
			    </xsl:if>
			    <xsl:apply-templates mode="offering" />
			</gr:Offering>

			<!-- Xalan
	        <gr:BusinessEntity rdf:about="{concat ($baseUri, '#', 'Vendor')}">
			-->
	        <gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Vendor')}">
				<rdfs:comment>The legal agent making the offering</rdfs:comment>
		        <gr:offers rdf:resource="{vi:proxyIRI ($baseUri, '', 'Offer')}"/>
				<!-- Xalan
		        <gr:offers rdf:resource="{concat ($baseUri, '#', 'Offer')}"/>
				-->
				<xsl:variable name="store"><xsl:value-of select="//ebay:Storefront/ebay:StoreName"/></xsl:variable>
				<xsl:variable name="seller"><xsl:value-of select="//ebay:Seller/ebay:UserID"/></xsl:variable>
				<xsl:choose>
					<xsl:when test="$seller != ''">
		        		<rdfs:label><xsl:value-of select="$seller"/></rdfs:label>
		        		<gr:legalName><xsl:value-of select="$seller"/></gr:legalName>
                        <foaf:page rdf:resource="{concat('http://myworld.ebay.com/', $seller)}" />
					</xsl:when>
					<xsl:when test="$store != ''">
		        		<rdfs:label><xsl:value-of select="$store"/></rdfs:label>
		        		<gr:legalName><xsl:value-of select="$store"/></gr:legalName>
						<foaf:page rdf:resource="{concat('http://myworld.ebay.com/', $store)}" />
						<oplebay:eBayStoreURL><xsl:value-of select="//ebay:Storefront/ebay:StoreURL"/></oplebay:eBayStoreURL>
					</xsl:when>
					<xsl:otherwise>
		        		<rdfs:label>Ebay Co., Inc.</rdfs:label>
		        		<gr:legalName>Ebay Co., Inc.</gr:legalName>
			  			<foaf:homepage rdf:resource="http://www.ebay.com" />
			  			<owl:sameAs rdf:resource="http://www.ebay.com" />
			  			<!-- Xalan
						<rdfs:seeAlso rdf:resource="{concat ('http://www.ebay.com')}"/>
			  			-->
			  			<rdfs:seeAlso rdf:resource="{vi:proxyIRI ('http://www.ebay.com')}"/>
					</xsl:otherwise>
				</xsl:choose>
	        </gr:BusinessEntity>

			<!-- Xalan
			<rdf:Description rdf:about="{$resourceURL}">
			-->
			<rdf:Description rdf:about="{$resourceURL}">
                         	<opl:providedBy>
                         		<foaf:Organization rdf:about="http://www.ebay.com#this">
                         			<foaf:name>Ebay</foaf:name>
                         			<foaf:homepage rdf:resource="http://www.ebay.com"/>
                         		</foaf:Organization>
                         	</opl:providedBy>

			    <rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder" />
			    <rdf:type rdf:resource="&gr;ProductOrService" />
			    
			    <rdf:type rdf:resource="&oplebay;Product" />

                <foaf:page rdf:resource="{$baseUri}"/>
			    <sioc:has_container rdf:resource="{$docproxyIRI}"/>
                <xsl:variable name="brand" 
						select="//ebay:Item/ebay:ItemSpecifics/ebay:NameValueList[ebay:Name='Brand']/ebay:Value"/>
					<xsl:variable name="make"
						select="//ebay:Item/ebay:ItemSpecifics/ebay:NameValueList[ebay:Name='Make']/ebay:Value"/>
					<xsl:variable name="model"
						select="//ebay:Item/ebay:ItemSpecifics/ebay:NameValueList[ebay:Name='Model']/ebay:Value"/>
						
		<xsl:if test="string-length($brand) &gt; 0">
		  <gr:hasBrand rdf:resource="{vi:proxyIRI ($docproxyIRI, '', 'Brand')}" />
		</xsl:if>
						
						
                <xsl:if test="string-length(concat($brand, $make, $model)) &gt; 0">
	
                    <xsl:if test="string-length($make) &gt; 0">
                        <rdf:type rdf:resource="{concat('&pto;', $make)}" />
                    </xsl:if>
                    <xsl:if test="string-length($brand) &gt; 0">
                        <rdf:type rdf:resource="{concat('&pto;', $brand)}" />
                    </xsl:if>
                    <xsl:if test="string-length($model) &gt; 0">
                        <rdf:type rdf:resource="{concat('&pto;', $model)}" />
                    </xsl:if>
                <gr:hasMakeAndModel>
				<!-- Xalan
	            <rdf:Description rdf:about="{concat ($baseUri, '#', 'MakeAndModel')}">
				-->
	            <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', 'MakeAndModel')}">
	                <rdf:type rdf:resource="&gr;ProductOrServiceModel"/>
	                <rdf:type rdf:resource="&oplebay;Product"/>

					<xsl:if test="string-length(concat($brand, $make, $model)) &gt; 0">
		            	<rdfs:comment>
							<xsl:choose>
								<xsl:when test="string-length($make) &gt; 0">
									<xsl:value-of select="$make"/>
								</xsl:when>
								<xsl:when test="string-length($brand) &gt; 0">
									<xsl:value-of select="$brand"/>
								</xsl:when>
							</xsl:choose>
							<xsl:if test="string-length($model) &gt; 0">
								<xsl:if test="string-length(concat($brand, $model)) &gt; 0">
									<xsl:text> </xsl:text>
								</xsl:if>
								<xsl:value-of select="$model"/>
							</xsl:if>
						</rdfs:comment>
					</xsl:if>

					<!-- Remove
				    <xsl:apply-templates select="ebay:GetSingleItemResponse/ebay:Item" mode="manufacturer" />
					-->
				    <xsl:apply-templates select="ebay:Item" mode="manufacturer" />
                 </rdf:Description>
               </gr:hasMakeAndModel>
               </xsl:if>
               <xsl:choose>
					<!-- Remove
					<xsl:when test="substring-before(ebay:GetSingleItemResponse/ebay:Item/ebay:PrimaryCategoryName, ':') = 'Books'">
					-->
					<xsl:when test="substring-before(ebay:Item/ebay:PrimaryCategoryName, ':') = 'Books'">
						<rdf:type rdf:resource="&bibo;Book"/>
						<rdf:type rdf:resource="&book;Book"/>
						<!-- Remove
						<xsl:apply-templates select="ebay:GetSingleItemResponse/ebay:Item" mode="bibo" />
						-->
						<xsl:apply-templates select="ebay:Item" mode="bibo" />
					</xsl:when>
					<xsl:otherwise/>
				</xsl:choose>
			   <!-- Remove
			   <xsl:apply-templates select="ebay:GetSingleItemResponse/ebay:Item" />
			   -->
			   <xsl:apply-templates select="ebay:Item" />
			</rdf:Description>
			
			
			<rdf:Description rdf:about="{vi:proxyIRI ($docproxyIRI, '', 'Brand')}">
				<xsl:apply-templates select="//ebay:Item/ebay:ItemSpecifics/ebay:NameValueList[ebay:Name='Brand']/ebay:Value" mode="grbrand" />
			</rdf:Description>
		</rdf:RDF>
    </xsl:template>

    <xsl:template match="ebay:Value" mode="grbrand">
      <rdf:type rdf:resource="&gr;Brand" />
      <gr:name><xsl:value-of select="." /></gr:name>
    </xsl:template>
    
    <xsl:template match="ebay:Item">
        <xsl:apply-templates select="*"/>
    </xsl:template>

    <xsl:template match="ebay:Item/ebay:ConvertedCurrentPrice" mode="offering">
		<gr:hasPriceSpecification>
		  <!-- Xalan
		  <gr:UnitPriceSpecification rdf:about="{concat ($baseUri, '#', 'ConvertedCurrentPrice')}">
		  -->
		  <gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'ConvertedCurrentPrice')}">
			<rdfs:label>
      			<xsl:value-of select="concat( . , ' (', @currencyID, ')')"/>	
			</rdfs:label>
			<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
            <gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasCurrencyValue>
            <gr:hasCurrency rdf:datatype="&xsd;string"><xsl:value-of select="@currencyID"/></gr:hasCurrency>
          </gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template>

    <xsl:template match="ebay:Item/ebay:ViewItemURLForNaturalSearch">
		<xsl:if test="string-length(.) &gt; 0">
			<xsl:element namespace="&rdfs;" name="seeAlso">
			<xsl:attribute name="rdf:resource">
				<xsl:value-of select="."/>
			</xsl:attribute>
			</xsl:element>
		</xsl:if>
    </xsl:template>

    <xsl:template match="ebay:Item/ebay:Title">
	<rdfs:comment><xsl:value-of select="."/></rdfs:comment>
	<gr:name><xsl:value-of select="."/></gr:name>
    <rdfs:label><xsl:value-of select="."/></rdfs:label>
    </xsl:template>
    <xsl:template match="ebay:Item/ebay:Description">
	<!--oplebay:description rdf:datatype="&xsd;string"><xsl:value-of select="."/></oplebay:description-->
	<gr:description rdf:datatype="&xsd;string"><xsl:value-of select="."/></gr:description>
    </xsl:template>
    <xsl:template match="ebay:Item/ebay:ItemId">
	<oplebay:productId><xsl:value-of select="."/></oplebay:productId>
    </xsl:template>
    <xsl:template match="ebay:Item/ebay:PrimaryCategoryName">
	<oplebay:category><xsl:value-of select="."/></oplebay:category>
    </xsl:template>
    <xsl:template match="ebay:Item/ebay:ItemSpecifics/ebay:NameValueList[Name='Format']">
	<oplebay:format rdf:datatype="&xsd;string"><xsl:value-of select="ebay:Value"/></oplebay:format>
    </xsl:template>
    <xsl:template match="ebay:Item/ebay:ItemSpecifics/ebay:NameValueList[Name='ISBN-13']">
	<gr:hasEAN_UCC-13><xsl:value-of select="ebay:Value"/></gr:hasEAN_UCC-13>
    </xsl:template>
    <xsl:template match="ebay:Item/ebay:GalleryURL">
	<xsl:if test="string-length(.) &gt; 0">
	    <xsl:element namespace="&foaf;" name="depiction">
		<xsl:attribute name="rdf:resource">
		    <xsl:value-of select="."/>
		</xsl:attribute>
	    </xsl:element>
	</xsl:if>
    </xsl:template>
    <xsl:template match="ebay:Item/ebay:PictureURL">
	<xsl:if test="string-length(.) &gt; 0">
	    <xsl:element namespace="&foaf;" name="depiction">
		<xsl:attribute name="rdf:resource">
		    <xsl:value-of select="."/>
		</xsl:attribute>
	    </xsl:element>
	</xsl:if>
    </xsl:template>

	<!--
    <xsl:template match="ebay:Item/ebay:ItemSpecifics/ebay:NameValueList[ebay:Name='Brand']" mode="manufacturer">
	-->
    <xsl:template match="ebay:Item/ebay:ItemSpecifics/ebay:NameValueList[ebay:Name='Make']" mode="manufacturer">
	<gr:hasManufacturer>
	    <gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Manufacturer')}">
		<!-- Xalan
	    <gr:BusinessEntity rdf:about="{concat ($baseUri, '#', 'Manufacturer')}">
		-->
		<rdfs:comment>Manufacturer</rdfs:comment>
		<gr:legalName><xsl:value-of select="ebay:Value"/></gr:legalName>
		<rdfs:label><xsl:value-of select="ebay:Value"/></rdfs:label>
	    </gr:BusinessEntity>
	</gr:hasManufacturer>
    </xsl:template>

	<xsl:template match="ebay:Item/ebay:ItemSpecifics/ebay:NameValueList">
	<oplebay:detail>
	    <xsl:element namespace="&oplebay;" name="ProductDetail">
	        <xsl:attribute name='rdf:about'>
	            <xsl:value-of select="concat(vi:proxyIRI ($baseUri, '', 'Detail_'), position())"/>
				<!-- Xalan
	            <xsl:value-of select="concat($baseUri, '#', 'Detail_', position())"/>
				-->
		</xsl:attribute>
		<oplebay:detail_name><xsl:value-of select="ebay:Name"/></oplebay:detail_name>
		<oplebay:detail_value>
			<xsl:variable name="val"/>
			<xsl:for-each select="ebay:Value">
				<xsl:choose>
					<xsl:when test="$val = ''">
						<xsl:variable name="val">
							<xsl:value-of select="."/>
						</xsl:variable>
					</xsl:when>
					<xsl:otherwise>
						<xsl:variable name="val">
							<xsl:value-of select="concat($val, ', ', .)"/>
						</xsl:variable>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:for-each>
			<xsl:value-of select="$val"/>
		</oplebay:detail_value>
	    </xsl:element>
	</oplebay:detail>
    </xsl:template>

    <xsl:template match="ebay:Item/ebay:Location">
		<oplebay:location_info>
			<xsl:value-of select="."/>
		</oplebay:location_info>
    </xsl:template>

	<!-- Reviews -->

	<xsl:template match="/ebay:FindReviewsAndGuidesResponse">
		<rdf:RDF>
			<rdf:Description rdf:about="{$docproxyIRI}">
				<xsl:for-each select="//ebay:ReviewDetails/ebay:Review">
					<!-- Xalan
				  	<foaf:topic rdf:resource="{concat ($baseUri, '#', 'Review_', ebay:UserID)}"/>
				  	-->
				  	<foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', concat('Review_', ebay:UserID))}"/>
				</xsl:for-each>
			</rdf:Description>

			<rdf:Description rdf:about="{$resourceURL}">
				<xsl:apply-templates/>
			</rdf:Description>
		</rdf:RDF>
	</xsl:template>

    <xsl:template match="ebay:ReviewDetails/ebay:AverageRating">
		<review:rating><xsl:value-of select="."/></review:rating>
    </xsl:template>

    <xsl:template match="ebay:ReviewDetails/ebay:Review">
		<review:hasReview>
			<!-- Xalan
			<review:Review rdf:about="{concat ($baseUri, '#', 'Review_', ebay:UserID)}">
			-->
			<review:Review rdf:about="{vi:proxyIRI ($baseUri, '', concat('Review_', ebay:UserID))}">
				<rdfs:label><xsl:value-of select="ebay:Title"/></rdfs:label>
				<review:title><xsl:value-of select="ebay:Title"/></review:title>
				<!-- FIX : Add URL prefix to review profile on eBay?
				<review:reviewer><xsl:value-of select="concat('http://www.amazon.com/gp/pdp/profile/', amz:CustomerId)"/></review:reviewer>
				-->
				<review:reviewer><xsl:value-of select="ebay:UserID"/></review:reviewer>
				<review:rating><xsl:value-of select="ebay:Rating"/></review:rating>
				<dcterms:created><xsl:value-of select="ebay:CreationTime"/></dcterms:created>
				<review:text><xsl:value-of select="ebay:Text"/></review:text>
				<rdfs:seeAlso rdf:resource="{ebay:URL}"/>
			</review:Review>
		</review:hasReview>
	</xsl:template>

    <xsl:template match="text()|@*"/>
    <xsl:template match="text()|@*" mode="offering" />
    <xsl:template match="text()|@*" mode="manufacturer" />
    <xsl:template match="text()|@*" mode="bibo" />

</xsl:stylesheet>
