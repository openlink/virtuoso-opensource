<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2016 OpenLink Software
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
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY pto "http://www.productontology.org/id/">
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY cnet "http://api.cnet.com/restApi/v1.0/ns">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY oplcn "http://www.openlinksw.com/schemas/cnet#">
]>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
  xmlns:rdf="&rdf;"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:foaf="&foaf;"
  xmlns:bibo="&bibo;"
  xmlns:sioc="&sioc;"
  xmlns:pto="&pto;" 
  xmlns:gr="&gr;"
  xmlns:dcterms="&dcterms;"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:owl="http://www.w3.org/2002/07/owl#"
  xmlns:cnet="&cnet;"
  xmlns:opl="&opl;"
  xmlns:oplcn="&oplcn;">

  <xsl:output method="xml" indent="yes" />

  <xsl:param name="baseUri" />
  <xsl:param name="currentDateTime"/>

  <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
  <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
  <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

  <xsl:variable name="error" select="/cnet:CNETResponse/cnet:Error/@code" />

  <xsl:template match="/">
	<rdf:RDF>
		<xsl:choose>
			<xsl:when test="string-length(/cnet:CNETResponse/cnet:Error/@code) &gt; 0">
				<rdf:Description rdf:about="{$docproxyIRI}">
					<rdf:type rdf:resource="&bibo;Document"/>
				</rdf:Description>
			</xsl:when>
			<xsl:otherwise>
				<rdf:Description rdf:about="{$docproxyIRI}">
					<rdf:type rdf:resource="&bibo;Document"/>
					<sioc:container_of rdf:resource="{$resourceURL}"/>
					<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
					<foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', 'Vendor')}"/>
					<foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', 'Offering')}"/>
					<dcterms:subject rdf:resource="{$resourceURL}"/>
					<owl:sameAs rdf:resource="{$docIRI}"/>
				</rdf:Description>

	               		<gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Vendor')}">
		  			<rdfs:comment>The legal agent making the offering</rdfs:comment>
		       			<rdfs:label>CBS Interactive</rdfs:label>
		       			<gr:legalName>CBS Interactive</gr:legalName>
		       			<gr:offers rdf:resource="{vi:proxyIRI ($baseUri, '', 'Offering')}"/>
		 			<foaf:homepage rdf:resource="http://www.cnet.com" />
					<!--
					 owl:sameAs provides an exit route to the original data space.
					 In this case, the resource is a dummy URI, which is our 'hint' to CNET.
					 At some stage, we're expecting CNET to expose RDF from this or some similar URI.
					 -->
		  			<owl:sameAs rdf:resource="http://www.cnet.com/about#BusinessEntity_CNET" />
		  			<rdfs:seeAlso rdf:resource="http://www.cnet.com"/>
		  			<rdfs:seeAlso rdf:resource="http://shopper.cnet.com"/>
		  			<rdfs:seeAlso rdf:resource="http://reviews.cnet.com"/>
		  			<rdfs:seeAlso rdf:resource="http://download.cnet.com"/>
	               		</gr:BusinessEntity>

				<gr:Offering rdf:about="{vi:proxyIRI ($baseUri, '', 'Offering')}">
              				<opl:providedBy>
              					<foaf:Organization rdf:about="http://www.cnet.com#this">
              						<foaf:name>CNET</foaf:name>
              						<foaf:homepage rdf:resource="http://www.cnet.com"/>
              					</foaf:Organization>
              				</opl:providedBy>

			    		<sioc:has_container rdf:resource="{$docproxyIRI}"/>
			    		<gr:hasBusinessFunction rdf:resource="&gr;Sell"/>
			                <gr:validFrom rdf:datatype="&xsd;dateTime"><xsl:value-of select="$currentDateTime"/></gr:validFrom>
					<xsl:apply-templates mode="offering" />
				</gr:Offering>
				<xsl:apply-templates select="cnet:CNETResponse" mode="product" />
			</xsl:otherwise>
		</xsl:choose>
	</rdf:RDF>
  </xsl:template>

  <xsl:template match="cnet:SoftwareProduct" mode="offering">
 	<gr:includes rdf:resource="{$resourceURL}"/>
	<gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModeDirectDownload"/>
  </xsl:template>

  <xsl:template match="cnet:TechProduct" mode="offering">
 	<gr:includes rdf:resource="{$resourceURL}"/>
		<gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModePickup"/>
		<gr:availableDeliveryMethods rdf:resource="&gr;UPS"/>
		<gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModeMail"/>
  </xsl:template>

  <xsl:template match="cnet:SoftwareProduct"  mode="product">    
	<rdf:Description rdf:about="{$resourceURL}">
		<rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder" />
		<rdf:type rdf:resource="&oplcn;SoftwareProduct" />
       		<gr:hasMakeAndModel>
	               	<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', 'MakeAndModel')}">
	               		<rdf:type rdf:resource="&gr;ProductOrServiceModel"/>
	               		<rdf:type rdf:resource="&oplcn;SoftwareProduct"/>
				<xsl:apply-templates mode="manufacturer" />
		               	<!-- TO DO
		               	<rdfs:comment>!!#{manufacturer} #{modelNumber}</rdfs:comment>
		               	-->
	              	</rdf:Description>
	       	</gr:hasMakeAndModel>
		<xsl:apply-templates select="*"  />
	</rdf:Description>
  </xsl:template>

  <xsl:template match="cnet:TechProduct"  mode="product">    
	<rdf:Description rdf:about="{$resourceURL}">
		<rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder" />
		<rdf:type rdf:resource="&oplcn;TechProduct" />
      		<opl:providedBy>
      			<foaf:Organization rdf:about="http://www.cnet.com#this">
      				<foaf:name>CNET</foaf:name>
      				<foaf:homepage rdf:resource="http://www.cnet.com"/>
      			</foaf:Organization>
      		</opl:providedBy>

       		<gr:hasMakeAndModel>
	               	<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', 'MakeAndModel')}">
	               		<rdf:type rdf:resource="&gr;ProductOrServiceModel"/>
	               		<rdf:type rdf:resource="&oplcn;TechProduct"/>
				<xsl:apply-templates mode="manufacturer" />
		               	<!-- TO DO
		               	<rdfs:comment>!!#{manufacturer} #{modelNumber}</rdfs:comment>
		               	-->
	              	</rdf:Description>
	       	</gr:hasMakeAndModel>
		<xsl:apply-templates select="*" />
	</rdf:Description>
  </xsl:template>

  <!-- Applies to TechProduct -->

  <xsl:template match="cnet:SKU">
  	<oplcn:sku><xsl:value-of select="."/></oplcn:sku>
	<gr:hasStockKeepingUnit><xsl:value-of select="."/></gr:hasStockKeepingUnit>
  </xsl:template>

  <xsl:template match="cnet:CdsSKU">
  	<oplcn:CdsSKU><xsl:value-of select="."/></oplcn:CdsSKU>
  </xsl:template>

  <xsl:template match="cnet:ImageURL">
	<oplcn:image rdf:resource="{.}"/>
  </xsl:template>

  <xsl:template match="cnet:PriceURL">
	<oplcn:CNETShopperCatalogEntry rdf:resource="{.}"/>
  </xsl:template>

  <xsl:template match="cnet:ReviewURL">
	<oplcn:CNETReview rdf:resource="{.}"/>
  </xsl:template>

  <xsl:template match="cnet:Manufacturer/cnet:Name" mode="manufacturer">
	<gr:hasManufacturer>
		<gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Manufacturer')}">
			<rdfs:label><xsl:value-of select="."/></rdfs:label>
			<gr:legalName><xsl:value-of select="."/></gr:legalName>
		</gr:BusinessEntity>
	</gr:hasManufacturer>
  </xsl:template>

    <xsl:template match="cnet:Manufacturer/cnet:Name">
	<rdf:type rdf:resource="{concat('&pto;', .)}" />
    </xsl:template>

  <xsl:template match="cnet:Specs">
  	<oplcn:specification><xsl:value-of select="string(.)"/></oplcn:specification>
  </xsl:template>

  <xsl:template match="cnet:EditorsChoice">
  	<oplcn:editorsChoice rdf:datatype="&xsd;boolean"><xsl:value-of select="string(.)"/></oplcn:editorsChoice>
  </xsl:template>

  <xsl:template match="cnet:EditorsStarRating">
  	<oplcn:editorsStarRating><xsl:value-of select="concat(., ' out of ', @outOf )"/></oplcn:editorsStarRating>
  </xsl:template>

  <xsl:template match="cnet:Good">
  	<oplcn:goodPoints><xsl:value-of select="."/></oplcn:goodPoints>
  </xsl:template>

  <xsl:template match="cnet:Bad">
  	<oplcn:badPoints><xsl:value-of select="."/></oplcn:badPoints>
  </xsl:template>

  <xsl:template match="cnet:BottomLine">
  	<oplcn:bottomLine><xsl:value-of select="."/></oplcn:bottomLine>
  </xsl:template>

  <xsl:template match="cnet:UserRatingSummary">
  	<oplcn:userRating><xsl:value-of select="concat(cnet:Rating, ' out of ', cnet:Rating/@outOf, ' from ', cnet:TotalVotes, ' votes' )"/></oplcn:userRating>
  	<oplcn:userStarRating><xsl:value-of select="concat(cnet:StarRating, ' out of ', cnet:StarRating/@outOf, ' from ', cnet:TotalVotes, ' votes' )"/></oplcn:userStarRating>
  </xsl:template>

  <xsl:template match="cnet:LowPrice" mode="offering">
	<gr:hasPriceSpecification>
	    	<gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'UnitPriceSpecification')}">
			<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
			<gr:hasCurrency rdf:datatype="&xsd;string">USD</gr:hasCurrency>
			<xsl:choose>
				<xsl:when test="string(.) = string(../cnet:HighPrice)">
                			<rdfs:label>
                			<xsl:value-of select="concat( translate (., '$', ''), ' (USD)')"/>	
                			</rdfs:label>
					<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="translate (., '$', '')"/></gr:hasCurrencyValue>
				</xsl:when>
				<xsl:otherwise>
                			<rdfs:label>sale price</rdfs:label>
					<gr:hasMinCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="translate (., '$', '')"/></gr:hasMinCurrencyValue>
					<gr:hasMaxCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="translate (../cnet:HighPrice, '$', '')"/></gr:hasMaxCurrencyValue>
				</xsl:otherwise>
			</xsl:choose>
	    	</gr:UnitPriceSpecification>
	</gr:hasPriceSpecification>
  </xsl:template>

  <xsl:template match="cnet:PublishDate">
	<dcterms:created>
	    <xsl:value-of select="."/>
	</dcterms:created>
  </xsl:template>

  <!-- End: Applies to TechProduct -->

  <!-- Applies to SoftwareProduct -->

  <xsl:template match="cnet:Publisher" mode="manufacturer">
	<gr:hasManufacturer>
		<gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'publisher')}">
			<rdfs:label><xsl:value-of select="cnet:Name"/></rdfs:label>
			<gr:legalName><xsl:value-of select="cnet:Name"/></gr:legalName>
			<oplcn:publisherSite><xsl:value-of select="cnet:LinkURL"/></oplcn:publisherSite>
		</gr:BusinessEntity>
	</gr:hasManufacturer>
  </xsl:template>

  <xsl:template match="cnet:Price">
	<gr:hasPriceSpecification>
	    <gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'price')}">
		<rdfs:label>
      			<xsl:value-of select="concat( translate (., '$', ''), ' (USD)')"/>	
		</rdfs:label>
		<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
		<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="translate (., '$', '')"/></gr:hasCurrencyValue>
		<gr:hasCurrency rdf:datatype="&xsd;string">USD</gr:hasCurrency>
	    </gr:UnitPriceSpecification>
	</gr:hasPriceSpecification>
  </xsl:template>

    <xsl:template match="cnet:License">
	<oplcn:license><xsl:value-of select="."/></oplcn:license>
    </xsl:template>

    <xsl:template match="cnet:BetaRelease">
	<oplcn:betaRelease rdf:datatype="&xsd;boolean"><xsl:value-of select="."/></oplcn:betaRelease>
    </xsl:template>

    <xsl:template match="cnet:Summary">
	<oplcn:shortDescription><xsl:value-of select="."/></oplcn:shortDescription>
    </xsl:template>

    <xsl:template match="cnet:WhatsNew">
	<oplcn:newFeatures><xsl:value-of select="."/></oplcn:newFeatures>
    </xsl:template>

    <xsl:template match="cnet:Platform">
	<oplcn:platform><xsl:value-of select="."/></oplcn:platform>
    </xsl:template>

    <xsl:template match="cnet:OperatingSystem">
	<oplcn:operatingSystem><xsl:value-of select="."/></oplcn:operatingSystem>
    </xsl:template>

    <xsl:template match="cnet:EditorsNote">
	<xsl:if test="string-length(.) &gt; 0">
	    <oplcn:editorsNote><xsl:value-of select="."/></oplcn:editorsNote>
	</xsl:if>
    </xsl:template>

    <xsl:template match="cnet:WeeklyDownloads">
	<oplcn:weeklyDownloads rdf:datatype="&xsd;integer"><xsl:value-of select="."/></oplcn:weeklyDownloads>
    </xsl:template>

    <xsl:template match="cnet:TotalDownloads">
	<oplcn:totalDownloads rdf:datatype="&xsd;integer"><xsl:value-of select="."/></oplcn:totalDownloads>
    </xsl:template>

    <xsl:template match="cnet:FileSize">
	<oplcn:fileSize rdf:datatype="&xsd;integer"><xsl:value-of select="."/></oplcn:fileSize>
    </xsl:template>

    <xsl:template match="cnet:ReleaseDate">
	<oplcn:dateReleased rdf:datatype="&xsd;dateTime"><xsl:value-of select="translate(concat($currentDateTime, 'Z'), ' ', 'T')"/></oplcn:dateReleased>
    </xsl:template>

    <xsl:template match="cnet:Limitations">
	<xsl:if test="string-length(.) &gt; 0">
		<oplcn:limitations><xsl:value-of select="."/></oplcn:limitations>
	</xsl:if>
    </xsl:template>

    <xsl:template match="cnet:SoftwareProduct/cnet:UserRatingSummary">
  	<oplcn:userRating><xsl:value-of select="concat(cnet:Rating, ' out of ', cnet:Rating/@outOf, ' from ', cnet:TotalVotes, ' votes' )"/></oplcn:userRating>
    </xsl:template>

    <xsl:template match="cnet:ProductDownloadURL">
	<xsl:if test="string-length(.) &gt; 0">
	    <xsl:element namespace="&oplcn;" name="productDownloadURL">
		<xsl:attribute name="rdf:resource">
		    <xsl:value-of select="."/>
		</xsl:attribute>
	    </xsl:element>
	</xsl:if>
    </xsl:template>

    <xsl:template match="cnet:Description">
	<gr:description><xsl:value-of select="string(.)"/></gr:description>
	<oplcn:description><xsl:value-of select="string(.)"/></oplcn:description>
    </xsl:template>

    <xsl:template match="cnet:Version">
	<oplcn:version><xsl:value-of select="string(.)"/></oplcn:version>
    </xsl:template>

  <!-- End: Applies to SoftwareProduct -->

  <!-- Applies to SoftwareProduct | TechProduct -->

  <xsl:template match="cnet:TechProduct/cnet:Name | cnet:SoftwareProduct/cnet:Name" mode="offering">
	<rdfs:label><xsl:value-of select="concat('Offer: ', .)"/></rdfs:label>
  </xsl:template>
  <xsl:template match="cnet:Name">
	<rdfs:label><xsl:value-of select="."/></rdfs:label>
  </xsl:template>
  <xsl:template match="cnet:EditorsRating">
	<xsl:if test="string-length(.) &gt; 0">
  		<oplcn:editorsRating><xsl:value-of select="concat(., ' out of ', @outOf )"/></oplcn:editorsRating>
	</xsl:if>
  </xsl:template>

  <!-- End: Applies to SoftwareProduct | TechProduct -->

  <!-- cnet:SoftwareProduct/cnet:LinkURL points back to page being sponged, so ignore as Sponger handles this automatically -->

  <!--
    <xsl:template match="*[starts-with(.,'http://') or starts-with(.,'urn:')]">
	<xsl:if test="string-length(.) &gt; 0">
	    <xsl:element namespace="&oplcn;" name="{name()}">
		<xsl:attribute name="rdf:resource">
		    <xsl:value-of select="."/>
		</xsl:attribute>
	    </xsl:element>
	</xsl:if>
    </xsl:template>

    <xsl:template match="*[* and ../../*]">
	<xsl:element namespace="&oplcn;" name="{name()}">
	    <xsl:attribute name="rdf:parseType">Resource</xsl:attribute>
	    <xsl:apply-templates select="@*|node()"/>
	</xsl:element>
    </xsl:template>

    <xsl:template match="*">
	<xsl:if test="string-length(.) &gt; 0">
	    <xsl:element namespace="&oplcn;" name="{name()}">
		<xsl:apply-templates select="@*|node()"/>
	    </xsl:element>
	</xsl:if>
    </xsl:template>
  -->

    <xsl:template match="text()|@*"/>
    <xsl:template match="text()|@*" mode="offering" />
    <xsl:template match="text()|@*" mode="manufacturer" />

</xsl:stylesheet>
