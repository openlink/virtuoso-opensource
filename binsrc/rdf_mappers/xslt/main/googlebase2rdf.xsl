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
<!ENTITY a "http://www.w3.org/2005/Atom">
<!ENTITY batch "http://schemas.google.com/gdata/batch">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY g "http://base.google.com/ns/1.0">
<!ENTITY gm "http://base.google.com/ns-metadata/1.0">
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY oplgb "http://www.openlinksw.com/schemas/google-base#">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY rss "http://purl.org/rss/1.0/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY sioct "http://rdfs.org/sioc/types#">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY xsl "http://www.w3.org/1999/XSL/Transform">
<!ENTITY vi "http://www.openlinksw.com/virtuoso/xslt/">
<!--
<!ENTITY vi "xalan://openlink.virtuoso.XalanExtensions.Sponger">
-->
<!ENTITY virtrdf "http://www.openlinksw.com/schemas/virtrdf#">
<!ENTITY wgs84 "http://www.w3.org/2003/01/geo/wgs84_pos#">
]>
<xsl:stylesheet version="1.0"
    xmlns:a="&a;"
    xmlns:batch="&batch;"
    xmlns:bibo="&bibo;"
    xmlns:dc="&dc;"
    xmlns:dcterms="&dcterms;"
    xmlns:foaf="&foaf;"
    xmlns:g="&g;"
    xmlns:gm="&gm;"
    xmlns:gr="&gr;"
    xmlns:oplgb="&oplgb;"
    xmlns:owl="&owl;"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:rss="&rss;"
    xmlns:sioc="&sioc;"
    xmlns:sioct="&sioct;"
    xmlns:vi="&vi;"
    xmlns:virtrdf="&virtrdf;"
    xmlns:wgs84="&wgs84;"
    xmlns:xsd="&xsd;"
    xmlns:xsl="&xsl;"
	extension-element-prefixes="vi"
    >

    <xsl:output method="xml" encoding="utf-8" indent="yes"/>

    <xsl:param name="baseUri"/>
    <xsl:param name="currentDateTime"/>

    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:variable name="uc">ABCDEFGHIJKLMNOPQRSTUVWXYZ</xsl:variable>
    <xsl:variable name="lc">abcdefghijklmnopqrstuvwxyz</xsl:variable>

    <xsl:template match="/">
	<rdf:RDF>
		<rdf:Description rdf:about="{$docproxyIRI}">
	    	<rdf:type rdf:resource="&bibo;Document"/>
			<owl:sameAs rdf:resource="{$docIRI}"/>
	   		<xsl:apply-templates mode="container" />
		</rdf:Description>
	   	<xsl:apply-templates />
	</rdf:RDF>
    </xsl:template>

	<!-- 
	It's assumed that the sponged URL only contains *one* item.
	i.e. It's an item URL, not a query URL.
	If there's more than one item, we cannot use $resourceURL to identify it.
	-->
    <xsl:template match="a:entry" mode="container">
			<sioc:container_of rdf:resource="{$resourceURL}"/>
	    	<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
			<dcterms:subject rdf:resource="{$resourceURL}"/>
			<rdfs:label><xsl:value-of select="concat('Google Base: ', g:item_type, ' Snippet ', substring-after(a:id, 'snippets/'))"/></rdfs:label>
    </xsl:template>

    <xsl:template match="a:entry" >
		<rdf:Description rdf:about="{$resourceURL}">
			<rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder" />
			<rdf:type rdf:resource="&oplgb;{g:item_type}" /> <!-- OpenLink GoogleBase schema should declare a class for each supported item type -->
			<gr:amountOfThisGood>1</gr:amountOfThisGood>
	   		<sioc:has_container rdf:resource="{$docproxyIRI}"/>
			<owl:sameAs><xsl:value-of select="a:id"/></owl:sameAs>
	    	<dc:title><xsl:value-of select="a:title"/></dc:title>
	    	<dcterms:publisher>Google Inc.</dcterms:publisher>
			<rdfs:label><xsl:value-of select="a:title"/></rdfs:label>
	    	<xsl:apply-templates select="g:*"/>
	    	<xsl:apply-templates select="a:*"/>
		</rdf:Description>
	   	<xsl:apply-templates select="g:price" mode="offering" />
	   	<xsl:apply-templates select="a:author" mode="offering" />
    </xsl:template>

    <xsl:template match="a:content">
		<dc:description><xsl:value-of select="."/></dc:description>
    </xsl:template>

    <xsl:template match="a:entry//a:link[@rel = 'alternate']">
		<rdfs:seeAlso rdf:resource="{@href}"/>
    </xsl:template>

    <xsl:template match="a:entry//a:published">
		<dcterms:created rdf:datatype="&xsd;dateTime"><xsl:value-of select="."/></dcterms:created>
    </xsl:template>

    <xsl:template match="a:entry//a:updated">
		<dcterms:modified rdf:datatype="&xsd;dateTime"><xsl:value-of select="."/></dcterms:modified>
    </xsl:template>

    <xsl:template match="a:category"/>

    <xsl:template match="g:price" mode="offering">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<foaf:topic rdf:resource="{vi:proxyIRI($baseUri, '', 'Offer')}"/>
		</rdf:Description>

		<gr:Offering rdf:about="{vi:proxyIRI($baseUri, '', 'Offer')}">
			<xsl:choose>
				<xsl:when test="contains(../g:listing_type, 'for rent')">
		    		<gr:hasBusinessFunction rdf:resource="&gr;LeaseOut"/>
				</xsl:when>
				<xsl:otherwise>
		    		<gr:hasBusinessFunction rdf:resource="&gr;Sell"/>
				</xsl:otherwise>
			</xsl:choose>
		    <gr:includes rdf:resource="{$resourceURL}"/>
		    <gr:validThrough rdf:datatype="&xsd;dateTime"><xsl:value-of select="../g:expiration_date"/></gr:validThrough>

			<gr:hasPriceSpecification>
		  		<gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'Price')}">
					<xsl:choose>
						<xsl:when test="contains(../g:listing_type, 'for rent')">
							<rdfs:label>Rent (per month)</rdfs:label>
							<gr:hasUnitOfMeasurement>MON</gr:hasUnitOfMeasurement> 
						</xsl:when>
						<xsl:otherwise>
							<rdfs:label>Price</rdfs:label>
							<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement> <!-- C62 implies 'one' -->	
						</xsl:otherwise>
					</xsl:choose>
           			<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="substring-before(., ' ')"/></gr:hasCurrencyValue>
           			<gr:hasCurrency rdf:datatype="&xsd;string"><xsl:value-of select="translate (substring-after(., ' '), $lc, $uc)"/></gr:hasCurrency>
          		</gr:UnitPriceSpecification>
			</gr:hasPriceSpecification>
		</gr:Offering>
    </xsl:template>

    <xsl:template match="a:entry//a:author" mode="offering">
		<rdf:Description rdf:about="{$docproxyIRI}">
			<foaf:topic rdf:resource="{vi:proxyIRI($baseUri, '', 'Vendor')}"/>
		</rdf:Description>

		<gr:BusinessEntity rdf:about="{vi:proxyIRI($baseUri, '', 'Vendor')}">
      		<gr:offers rdf:resource="{vi:proxyIRI ($baseUri, '', 'Offer')}"/>
			<rdfs:comment>The legal agent making the offering</rdfs:comment>
		    <rdfs:label><xsl:value-of select="a:name"/></rdfs:label>
		    <gr:legalName><xsl:value-of select="a:name"/></gr:legalName>
    	</gr:BusinessEntity>
    </xsl:template>

    <xsl:template match="g:image_link">
		<foaf:depiction rdf:resource="{.}"/>
    </xsl:template>

    <xsl:template match="g:location">
		<!--
		<wgs84:lat><xsl:value-of select="g:latitude"/></wgs84:lat>
		<wgs84:long><xsl:value-of select="g:longitude"/></wgs84:long>
		-->
		<xsl:element name="{local-name(.)}" namespace="&oplgb;">
			<xsl:choose>
				<xsl:when test="g:latitude"> 
					<!-- Exclude text of g:latitude and g:longitude child nodes -->
	    			<xsl:value-of select="substring-before(., g:latitude)"/>
				</xsl:when>
				<xsl:otherwise>
	    			<xsl:value-of select="."/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:element>
	   	<xsl:apply-templates />
    </xsl:template>

    <xsl:template match="g:latitude">
		<wgs84:lat><xsl:value-of select="."/></wgs84:lat>
    </xsl:template>

    <xsl:template match="g:longitude">
		<wgs84:long><xsl:value-of select="."/></wgs84:long>
    </xsl:template>

    <xsl:template match="g:price" /> <!-- Already handled by "offering" mode -->
    <xsl:template match="a:author" /> <!-- Already handled by "offering" mode -->

    <xsl:template match="g:*">
		<xsl:element name="{local-name(.)}" namespace="&oplgb;">
			<xsl:choose>
				<xsl:when test="contains(local-name(.), 'bathrooms')">
	    			<xsl:value-of select="floor(.)"/><!-- floor used to force e.g 1.0 to 1 -->
				</xsl:when>
				<xsl:otherwise>
	    			<xsl:value-of select="."/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:element>
    </xsl:template>

    <xsl:template match="text()|@*" />
    <xsl:template match="text()|@*" mode="container" />
    <xsl:template match="text()|@*" mode="offering" />
</xsl:stylesheet>
