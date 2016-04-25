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
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY cl "http://www.ebusiness-unibw.org/ontologies/consumerelectronics/v1#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY pto "http://www.productontology.org/id/">
<!ENTITY oplbb "http://www.openlinksw.com/schemas/bestbuy#">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
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
    xmlns:pto="&pto;" 
    xmlns:opl="&opl;"
    xmlns:dc="&dc;"
    xmlns:dcterms="&dcterms;"
    xmlns:owl="&owl;"
    xmlns:cl="&cl;"
    xmlns:oplbb="&oplbb;"
    xmlns:po="http://purl.org/ontology/po/"
    xmlns:redwood-tags="http://www.holygoat.co.uk/owl/redwood/0.1/tags/"
	version="1.0">

  <xsl:output method="xml" indent="yes"/>

	<xsl:param name="baseUri"/>
	<xsl:param name="currentDateTime"/>

	<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
	<xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
	<xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
	<!-- Xalan
	<xsl:variable name="resourceURL" select="$baseUri"/>
	<xsl:variable  name="docIRI" select="$baseUri"/>
	<xsl:variable  name="docproxyIRI" select="$baseUri"/>
	-->

  <xsl:variable name="uc">ABCDEFGHIJKLMNOPQRSTUVWXYZ</xsl:variable>
  <xsl:variable name="lc">abcdefghijklmnopqrstuvwxyz</xsl:variable>

  <xsl:variable name="title">
	<xsl:value-of select="//meta[@name='book.title']/@content" />
  </xsl:variable>
  <xsl:variable name="subtitle">
	<xsl:value-of select="//meta[@name='subtitle']/@content" />
  </xsl:variable>
  <xsl:variable name="isbn">
	<xsl:value-of select="//meta[@name='isbn']/@content" />
  </xsl:variable>
  <xsl:variable name="extent">
	<xsl:value-of select="//*[@property='dc:extent']" />
  </xsl:variable>
  <xsl:variable name="category">
	<xsl:value-of select="translate(//meta[translate(@name, $uc, $lc)='category']/@content, $uc, $lc)" />
  </xsl:variable>

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
		<!-- Xalan
		<foaf:topic rdf:resource="{concat ($baseUri, '#', 'Vendor')}"/>
		<foaf:topic rdf:resource="{concat ($baseUri, '#', 'Offering')}"/>
		-->
		<foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', 'Vendor')}"/>
		<foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', 'Offering')}"/>
		<dcterms:subject rdf:resource="{$resourceURL}"/>
		<dc:title><xsl:value-of select="$baseUri"/></dc:title>
		<owl:sameAs rdf:resource="{$docIRI}"/>
	</rdf:Description>

	<!-- Xalan
	<gr:Offering rdf:about="{concat ($baseUri, '#', 'Offering')}">
	-->
	<gr:Offering rdf:about="{vi:proxyIRI ($baseUri, '', 'Offering')}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.oreilly.com#this">
                        			<foaf:name>Oreilly</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.oreilly.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

		<sioc:has_container rdf:resource="{$docproxyIRI}"/>
		<gr:hasBusinessFunction rdf:resource="&gr;Sell"/>
		<rdfs:label><xsl:value-of select="concat($title, ' - ', $subtitle)"/></rdfs:label>
		<gr:includes rdf:resource="{$resourceURL}"/>
		<gr:validFrom rdf:datatype="&xsd;dateTime"><xsl:value-of select="$currentDateTime"/></gr:validFrom>
		<gr:availableDeliveryMethods rdf:resource="&gr;UPS"/>
		<gr:availableDeliveryMethods rdf:resource="&gr;DeliveryModeMail"/>
		<!-- As was: Doesn't work - omits gr:hasPriceSpecification node
		<xsl:apply-templates mode="offering" />
		-->
		<xsl:apply-templates select="//span[@typeof='gr:UnitPriceSpecification']" mode="offering" />
	</gr:Offering>

	<!-- Xalan
    <gr:BusinessEntity rdf:about="{concat ($baseUri, '#', 'Vendor')}">
	-->
    <gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Vendor')}">
		<rdfs:comment>The legal agent making the offering</rdfs:comment>
		    <rdfs:label>O'Reilly Media, Inc.</rdfs:label>
		    <gr:legalName>O'Reilly Media, Inc.</gr:legalName>
			<!-- Xalan
		    <gr:offers rdf:resource="{concat ($baseUri, '#', 'Offering')}"/>
			-->
		    <gr:offers rdf:resource="{vi:proxyIRI ($baseUri, '', 'Offering')}"/>
		<foaf:homepage rdf:resource="http://oreilly.com" />
		<owl:sameAs rdf:resource="http://oreilly.com" />
		<!-- Xalan
		<rdfs:seeAlso rdf:resource="http://www.oreilly.com"/>
		-->
		<rdfs:seeAlso rdf:resource="{vi:proxyIRI ('http://www.oreilly.com')}"/>
    </gr:BusinessEntity>

	<rdf:Description rdf:about="{$resourceURL}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.oreilly.com#this">
                        			<foaf:name>Oreilly</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.oreilly.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

		<rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder" />
		<xsl:choose>
			<xsl:when test="$category='video'">
				<rdf:type rdf:resource="&bibo;AudioVisualDocument"/>
				<dcterms:extent><xsl:value-of select="normalize-space($extent)" /></dcterms:extent>
			</xsl:when>
			<xsl:when test="$category='books'">
				<rdf:type rdf:resource="&bibo;Book"/>
				<bibo:numPages><xsl:value-of select="normalize-space($extent)" /></bibo:numPages>
			</xsl:when>
		</xsl:choose>
    	<bibo:shortTitle><xsl:value-of select="$title"/></bibo:shortTitle>
    	<gr:name><xsl:value-of select="concat($title, ' - ', $subtitle)"/></gr:name>
		<rdfs:label><xsl:value-of select="concat($title, ' - ', $subtitle)"/></rdfs:label>
		<xsl:apply-templates select="meta" />
  		<xsl:apply-templates select="//div[@id='short-description']/div" />
  		<xsl:apply-templates select="//div[@id='fulldesc']/div" />
  		<xsl:apply-templates select="//div[@class='product-metadata']//*[@typeof='foaf:Person']" />
	</rdf:Description>
  </xsl:template>

  	<xsl:template match="//span[@typeof='gr:UnitPriceSpecification']" mode="offering">
		<gr:hasPriceSpecification>
			<!-- Xalan
	    	<gr:UnitPriceSpecification rdf:about="{concat ($baseUri, '#', 'UnitPriceSpecification')}">
			-->
	    	<gr:UnitPriceSpecification rdf:about="{vi:proxyIRI ($baseUri, '', concat('UnitPriceSpecification_', position()))}">
	    		<rdfs:label>
				<xsl:value-of select="concat(span[@property='gr:hasCurrencyValue'], ' (', span[@property='gr:hasCurrency']/@content, ')' )" />
			</rdfs:label>
				<gr:hasUnitOfMeasurement>C62</gr:hasUnitOfMeasurement>
				<gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="span[@property='gr:hasCurrencyValue']" /></gr:hasCurrencyValue>
				<gr:hasCurrency rdf:datatype="&xsd;string"><xsl:value-of select="span[@property='gr:hasCurrency']/@content" /></gr:hasCurrency>
	    	</gr:UnitPriceSpecification>
		</gr:hasPriceSpecification>
	</xsl:template>

  <!-- Not valid for videos, which also seem to have object.type of 'book'
  <xsl:template match="meta[translate (@name, $uc, $lc)='object.type']">
	<xsl:if test="@content='book'">
		<rdf:type rdf:resource="&bibo;Book"/>
	</xsl:if>
  </xsl:template>
  -->

  <xsl:template match="meta[translate (@name, $uc, $lc)='book.author']">
	<bibo:authorList>
		<xsl:value-of select="@content"/>
	</bibo:authorList>
  </xsl:template>

	<xsl:template match="meta[translate (@name, $uc, $lc)='book.isbn']">
	<xsl:if test="string-length(@content) &gt; 0">
    	<bibo:isbn13>
	  		<xsl:value-of select="@content"/>
      	</bibo:isbn13>
      	<dcterms:identifier>
	  		<xsl:value-of select="@content"/>
      	</dcterms:identifier>
	</xsl:if>
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
      	<xsl:variable name="amazonBookURL">
			<xsl:value-of select="concat('http://www.amazon.com/', translate($title, ' ', '-'), '/dp/', $isbn)"/>
      	</xsl:variable>
	  	<owl:sameAs rdf:resource="{$amazonBookURL}" />
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='ean']">
	<xsl:if test="string-length(@content) &gt; 0">
      <gr:hasEAN_UCC-13>
		<xsl:value-of select="@content"/>
      </gr:hasEAN_UCC-13>
       </xsl:if>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='graphic']">
      <foaf:img rdf:resource="{@content}"/>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='graphic_medium']">
      <foaf:img rdf:resource="{@content}"/>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='graphic_large']">
      <foaf:img rdf:resource="{@content}"/>
  </xsl:template>

	<!-- Used concatentation of metas book.title & subtitle instead
	<xsl:template match="meta[translate (@name, $uc, $lc)='book_title']">
    	<dc:title>
	  		<xsl:value-of select="@content"/>
      	</dc:title>
	</xsl:template>
	-->

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
		<bibo:abstract rdf:datatype="&xsd;string">
			<xsl:value-of select="@content"/>
		</bibo:abstract>
    </xsl:template>

	<xsl:template match="meta[translate (@name, $uc, $lc)='keywords']">
    	<dcterms:subject>
	  		<xsl:value-of select="@content"/>
      	</dcterms:subject>
	</xsl:template>

	<xsl:template match="meta[@name='search_date']">
		<!-- search_date is in ISO 8601 format as required by Dublin Core spec -->
    	<dcterms:issued>
	  		<xsl:value-of select="@content"/>
      	</dcterms:issued>
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

  <xsl:template match="meta[translate (@name, $uc, $lc)='edition_full']">
      <bibo:edition>
	  <xsl:value-of select="@content"/>
      </bibo:edition>
  </xsl:template>

  	<xsl:template match="//div[@id='short-description']/div">
		<bibo:shortDescription><xsl:value-of select="." /></bibo:shortDescription>
	</xsl:template>

  	<xsl:template match="//div[@id='fulldesc']/div">
		<gr:description>
			<xsl:value-of select="." />
		</gr:description>
	</xsl:template>

  	<xsl:template match="*[@typeof='foaf:Person']">
		<dc:contributor>
			<xsl:variable name="author"><xsl:value-of select="translate(@about, ':', '_')" /></xsl:variable>
			<!-- Xalan
			<foaf:Person rdf:about="{concat($baseUri, '#', concat('Author_', position()))}">
			-->
			<foaf:Person rdf:about="{vi:proxyIRI ($baseUri, '', concat('Author_', position()))}">
				<foaf:name><xsl:value-of select="." /></foaf:name>
				<foaf:homepage rdf:resource="{@href}"/>
			</foaf:Person>
		</dc:contributor>
	</xsl:template>

    <xsl:template match="text()|@*"/>
    <xsl:template match="text()|@*" mode="offering" />

</xsl:stylesheet>
