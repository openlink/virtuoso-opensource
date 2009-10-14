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
<!ENTITY oplbb "http://www.openlinksw.com/schemas/bestbuy#">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
]>
<xsl:stylesheet
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
    xmlns:owl="&owl;"
    xmlns:cl="&cl;"
    xmlns:oplbb="&oplbb;"
  xmlns:po="http://purl.org/ontology/po/"
  xmlns:redwood-tags="http://www.holygoat.co.uk/owl/redwood/0.1/tags/"
  version="1.0">

  <xsl:output method="xml" indent="yes"/>

  <xsl:param name="baseUri" />
	<xsl:param name="currentDateTime"/>

  <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
  <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
  <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

  <xsl:variable name="uc">ABCDEFGHIJKLMNOPQRSTUVWXYZ</xsl:variable>
  <xsl:variable name="lc">abcdefghijklmnopqrstuvwxyz</xsl:variable>

  <xsl:template match="/">
      <rdf:RDF>
		<xsl:apply-templates select="html/head"/>
      </rdf:RDF>
  </xsl:template>

  <xsl:template match="html/head">
      <rdf:Description rdf:about="{$docproxyIRI}">
		<rdf:type rdf:resource="&bibo;Document"/>
		<sioc:container_of rdf:resource="{$resourceURL}"/>
		<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
		<foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', 'Vendor')}"/>
		<foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', 'Product')}"/>
		<dcterms:subject rdf:resource="{$resourceURL}"/>
		<dc:title><xsl:value-of select="$baseUri"/></dc:title>
		<owl:sameAs rdf:resource="{$docIRI}"/>
	  </rdf:Description>

	<gr:Offering rdf:about="{$resourceURL}">
		<sioc:has_container rdf:resource="{$docproxyIRI}"/>
		<gr:hasBusinessFunction rdf:resource="&gr;Sell"/>
		<rdfs:label><xsl:value-of select="concat('Offer of ', meta[translate (@name, $uc, $lc)='book.title']/@content)"/></rdfs:label>
		<gr:includes rdf:resource="{vi:proxyIRI ($baseUri, '', 'Product')}"/>
		<gr:validFrom rdf:datatype="&xsd;dateTime"><xsl:value-of select="$currentDateTime"/></gr:validFrom>
		<gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModePickup"/>
		<gr:availableDeliveryMethods rdf:resource="&gr;UPS"/>
		<gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModeMail"/>
		<xsl:apply-templates mode="offering" />
	</gr:Offering>

    <gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Vendor')}">
		<rdfs:comment>The legal agent making the offering</rdfs:comment>
		    <rdfs:label>Oreilly Co., Inc.</rdfs:label>
		    <gr:legalName>Oreilly Co., Inc.</gr:legalName>
		    <gr:offers rdf:resource="{$resourceURL}"/>
		<foaf:homepage rdf:resource="http://www.oreilly.com" />
		<owl:sameAs rdf:resource="http://www.oreilly.com" />
		<rdfs:seeAlso rdf:resource="{vi:proxyIRI ('http://www.oreilly.com')}"/>
    </gr:BusinessEntity>

	<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', 'Product')}">
		<rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder" />
		<rdf:type rdf:resource="&oplbb;Product" />
		<rdf:type rdf:resource="&bibo;Book"/>
		<rdf:type rdf:resource="&book;Book"/>
        <gr:hasMakeAndModel>
	        <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', 'MakeAndModel')}">
	            <rdf:type rdf:resource="&gr;ProductOrServiceModel"/>
	            <rdf:type rdf:resource="&oplbb;Product"/>
				<xsl:apply-templates select="meta" mode="manufacturer" /> 
	        </rdf:Description>
	    </gr:hasMakeAndModel>
	    <oplbb:onlineAvailability rdf:datatype="&xsd;boolean">true</oplbb:onlineAvailability>
		<xsl:apply-templates select="meta"/>
      </rdf:Description>
  </xsl:template>

  <xsl:template match="//span[@typeof='gr:UnitPriceSpecification']" mode="offering">
	<gr:hasPriceSpecification>
	    <gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', 'UnitPriceSpecification')}">
	    <rdfs:label>sale price</rdfs:label>
		<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
		<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="span[@property='gr:hasCurrencyValue']" /></gr:hasCurrencyValue>
		<gr:hasCurrency rdf:datatype="&xsd;string"><xsl:value-of select="span[@property='gr:hasCurrency']/@content" /></gr:hasCurrency>
	    </gr:UnitPriceSpecification>
	</gr:hasPriceSpecification>
    </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='subtitle']">
      <po:subtitle>
		<xsl:value-of select="@content"/>
      </po:subtitle>
	  <gr:legalName rdf:datatype="http://www.w3.org/2001/XMLSchema#string">
		<xsl:value-of select="@content"/>
	  </gr:legalName>      
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='object.type']">
	<xsl:if test="@content='book'">
		<rdf:type rdf:resource="&bibo;Book"/>
	</xsl:if>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='book.title']">
      <dc:title>
	  <xsl:value-of select="@content"/>
      </dc:title>
      <gr:legalName rdf:datatype="http://www.w3.org/2001/XMLSchema#string">
		<xsl:value-of select="@content"/>
	  </gr:legalName>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='book.author']">
	<bibo:authorList>
		<xsl:value-of select="@content"/>
	</bibo:authorList>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='book.isbn']">
      <bibo:isbn13>
	  <xsl:value-of select="@content"/>
      </bibo:isbn13>
      <!--book:isbn>
	  <xsl:value-of select="@content"/>
      </book:isbn-->
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='book.year']">
      <dc:date>
	  <xsl:value-of select="@content"/>
      </dc:date>
      <gr:validFrom rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">
		<xsl:value-of select="@content"/>
	  </gr:validFrom>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='book.link']">
      <bibo:uri rdf:resource="{$resourceURL}" />
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='book.tags']">
      <redwood-tags:tag>
	  <xsl:value-of select="@content"/>
      </redwood-tags:tag>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='reference']">
      <dcterms:references>
	  <xsl:value-of select="@content"/>
      </dcterms:references>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='isbn']">
      <bibo:isbn10>
	  <xsl:value-of select="@content"/>
      </bibo:isbn10>
      <xsl:variable name="title">
		<xsl:value-of select="//meta[@name='book.title']/@content" />
      </xsl:variable>
      <xsl:variable name="isbn">
		<xsl:value-of select="//meta[@name='isbn']/@content" />
      </xsl:variable>
      <xsl:variable name="resourceURL">
		<xsl:value-of select="concat('http://www.amazon.com/', translate($title, ' ', '-'), '/dp/', $isbn)"/>
      </xsl:variable>
	  <owl:sameAs rdf:resource="{$resourceURL}" />
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='ean']">
      <!--bibo:eanucc13>
	  <xsl:value-of select="@content"/>
      </bibo:eanucc13-->
      <gr:hasEAN_UCC-13>
		<xsl:value-of select="@content"/>
      </gr:hasEAN_UCC-13>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='graphic']">
      <oplbb:image rdf:resource="{@content}"/>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='graphic_medium']">
      <oplbb:image rdf:resource="{@content}"/>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='graphic_large']">
      <oplbb:image rdf:resource="{@content}"/>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='book_title']">
      <dc:title>
	  <xsl:value-of select="@content"/>
      </dc:title>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='author']">
      <dc:creator>
	  <xsl:value-of select="@content"/>
      </dc:creator>
	<xsl:variable name="sas-iri" select="vi:dbpIRI ('', translate (@content, ' ', '_'))"/>
	<xsl:if test="not starts-with ($sas-iri, '#')">
		<rdfs:seeAlso rdf:resource="{$sas-iri}"/>
	</xsl:if>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='description']">
	<oplbb:description rdf:datatype="&xsd;string">
	  <xsl:value-of select="@content"/>
	</oplbb:description>
    </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='keywords']">
      <gr:description>
	  <xsl:value-of select="@content"/>
      </gr:description>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='date']">
      <dc:date>
	  <xsl:value-of select="@content"/>
      </dc:date>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='publisher']">
      <dc:publisher>
	  <xsl:value-of select="@content"/>
      </dc:publisher>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='series']">
      <po:series>
	  <xsl:value-of select="@content"/>
      </po:series>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='edition']">
      <po:series>
	  <xsl:value-of select="@content"/>
      </po:series>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='publisher']" mode="manufacturer">
	<gr:hasManufacturer>
		<gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Manufacturer')}">
		<rdfs:label>Manufacturer</rdfs:label>
		<gr:legalName><xsl:value-of select="@content"/></gr:legalName>
		</gr:BusinessEntity>
	</gr:hasManufacturer>
	</xsl:template>


    <xsl:template match="text()|@*"/>
    <xsl:template match="text()|@*" mode="offering" />
    <xsl:template match="text()|@*" mode="manufacturer" />


</xsl:stylesheet>
