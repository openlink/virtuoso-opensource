<?xml version="1.0" encoding="utf-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2019 OpenLink Software
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
<!DOCTYPE xsl:stylesheet
[
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY pto "http://www.productontology.org/id/">
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
xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
xmlns:dcterms="&dcterms;"
xmlns:opl="http://www.openlinksw.com/schema/attribution#"
xmlns:dc="http://purl.org/dc/elements/1.1/"
xmlns:owl="http://www.w3.org/2002/07/owl#" 
>

  <xsl:output method="xml" indent="yes" />

  <xsl:param name="baseUri" />

  <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)" />
  <xsl:variable name="docIRI" select="vi:docIRI($baseUri)" />
  <xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)" />
  
  <xsl:template match="/response">
    <rdf:RDF>
          <rdf:Description rdf:about="{$docproxyIRI}">
            <rdf:type rdf:resource="&bibo;Document" />
            <sioc:container_of rdf:resource="{$resourceURL}" />
            <foaf:primaryTopic rdf:resource="{$resourceURL}" />
            <foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', 'Vendor')}" />
            <foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', 'Offering')}" />
            <dcterms:subject rdf:resource="{$resourceURL}" />
            <gr:hasBrand rdf:resource="{vi:proxyIRI ($baseUri, '', 'Brand')}" />
          </rdf:Description>

          <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', 'Brand')}">
            <xsl:apply-templates select="deal/merchant" mode="grbrand" />
          </rdf:Description>
          
		  <gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Vendor')}">
            <rdfs:label><xsl:value-of select="deal/merchant/name" /></rdfs:label>
            <gr:legalName><xsl:value-of select="deal/merchant/name" /></gr:legalName>
            <foaf:name><xsl:value-of select="deal/merchant/id" /></foaf:name>
            <gr:offers rdf:resource="{vi:proxyIRI ($baseUri, '', 'Offering')}" />
            <foaf:homepage rdf:resource="{deal/merchant/websiteUrl}" />
          </gr:BusinessEntity>
		  
          <gr:Offering rdf:about="{vi:proxyIRI ($baseUri, '', 'Offering')}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.groupon.com#this">
                        			<foaf:name>Groupon</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.groupon.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

            <sioc:has_container rdf:resource="{$docproxyIRI}" />
            <gr:hasBusinessFunction rdf:resource="&gr;Sell" />
            <gr:validFrom rdf:datatype="&xsd;dateTime">
              <xsl:value-of select="deal/startAt" />
            </gr:validFrom>
            <gr:validThrough rdf:datatype="&xsd;dateTime">
              <xsl:value-of select="deal/endAt" />
            </gr:validThrough>
            <xsl:apply-templates mode="offering" />
          </gr:Offering>
          <xsl:apply-templates />
    </rdf:RDF>
  </xsl:template>

  <xsl:template match="deal" mode="offering">
    <gr:includes rdf:resource="{$resourceURL}" />
    <gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModePickup" />
    <xsl:apply-templates mode="offering" />
  </xsl:template>

  <xsl:template match="deal">
    <rdf:Description rdf:about="{$resourceURL}">
      <rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder" />
		<opl:providedBy>
			<foaf:Organization rdf:about="http://www.groupon.com#this">
				<foaf:name><xsl:value-of select="concat('Groupon: ', name)"/></foaf:name>
				<foaf:homepage rdf:resource="http://www.groupon.com"/>
			</foaf:Organization>
		</opl:providedBy>
	  
      <xsl:apply-templates />
    </rdf:Description>
  </xsl:template>

  <xsl:template match="mediumImageUrl">
		<foaf:img rdf:resource="{.}"/>
  </xsl:template>
  <xsl:template match="smallImageUrl">
		<foaf:img rdf:resource="{.}"/>
  </xsl:template>
  <xsl:template match="largeImageUrl">
		<foaf:img rdf:resource="{.}"/>
  </xsl:template>
  <xsl:template match="sidebarImageUrl">
		<foaf:img rdf:resource="{.}"/>
  </xsl:template>
  <xsl:template match="pitchHtml">
	<gr:description>
		<xsl:value-of select="."/>
	</gr:description>
  </xsl:template>
    <xsl:template match="dealUrl">
		<bibo:uri rdf:resource="{.}"/>
    </xsl:template>

    <xsl:template match="highlightsHtml">
		<dc:description>
			<xsl:value-of select="."/>
		</dc:description>
    </xsl:template>
  
     <xsl:template match="title">
		<rdfs:label>
			<xsl:value-of select="."/>
		</rdfs:label>
		<gr:name>
			<xsl:value-of select="."/>
		</gr:name>
    </xsl:template>

     <xsl:template match="announcementTitle">
		<rdfs:label>
			<xsl:value-of select="."/>
		</rdfs:label>
		<gr:name>
			<xsl:value-of select="."/>
		</gr:name>
    </xsl:template>
	
    <xsl:template match="options/option/price">
		<gr:hasPriceSpecification>
			<gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'price')}">
				<rdfs:label><xsl:value-of select="formattedAmount"/></rdfs:label>
				<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="amount div 100"/></gr:hasCurrencyValue>
				<gr:hasCurrency rdf:datatype="&xsd;string"><xsl:value-of select="currencyCode"/></gr:hasCurrency>
			</gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
    </xsl:template>
	
    <xsl:template match="division/lat">
		<geo:lat rdf:datatype="&xsd;float">
			<xsl:value-of select="."/>
		</geo:lat>
    </xsl:template>

    <xsl:template match="division/lng">
		<geo:long rdf:datatype="&xsd;float">
			<xsl:value-of select="."/>
		</geo:long>
    </xsl:template>
	
    <xsl:template match="merchant" mode="grbrand">
      <rdf:type rdf:resource="&gr;Brand" />
      <gr:name><xsl:value-of select="normalize-space(name)" /></gr:name>
      <foaf:page><xsl:value-of select="websiteUrl"/></foaf:page>
    </xsl:template>

  <xsl:template match="text()|@*" />
  <xsl:template match="text()|@*" mode="offering" />
  <xsl:template match="text()|@*" mode="manufacturer" />
</xsl:stylesheet>
