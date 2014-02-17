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
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY pto "http://www.productontology.org/id/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY vcard "http://www.w3.org/2001/vcard-rdf/3.0#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY cl "http://www.ebusiness-unibw.org/ontologies/consumerelectronics/v1#">
<!ENTITY oplbb "http://www.openlinksw.com/schemas/bestbuy#">
<!ENTITY oplamz "http://www.openlinksw.com/schemas/amazon#">
]>
<xsl:stylesheet version="1.0"
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
    xmlns:gr="&gr;"
    xmlns:pto="&pto;" 
    xmlns:oplamz="&oplamz;"	
    xmlns:opl="&opl;"
    xmlns:bestbuy="http://remix.bestbuy.com/"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:cl="&cl;"
    xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"	
    xmlns:oplbb="&oplbb;">

    <xsl:output method="xml" indent="yes" />

    <xsl:param name="baseUri"/>
    <xsl:param name="currentDateTime"/>

	<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:template match="/pw_api_results">
		<rdf:RDF>
				<rdf:Description rdf:about="{$docproxyIRI}">
					<rdf:type rdf:resource="&bibo;Document"/>
					<sioc:container_of rdf:resource="{vi:proxyIRI ($baseUri, '', 'Product')}"/>
					<foaf:primaryTopic rdf:resource="{vi:proxyIRI ($baseUri, '', 'Product')}"/>
					<foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', 'Vendor')}"/>
					<foaf:topic rdf:resource="{$resourceURL}"/>
					<dcterms:subject rdf:resource="{vi:proxyIRI ($baseUri, '', 'Product')}"/>
				<owl:sameAs rdf:resource="{$docIRI}"/>
				</rdf:Description>

						<gr:BusinessEntity rdf:about="{vi:proxyIRI ($baseUri, '', 'Vendor')}">
				  <rdfs:comment>ProductWiki</rdfs:comment>
					  <rdfs:label>ProductWiki</rdfs:label>
					  <gr:legalName>ProductWiki</gr:legalName>
					  <gr:offers rdf:resource="{$resourceURL}"/>
				  <foaf:homepage rdf:resource="http://www.productwiki.com" />
				  <rdfs:seeAlso rdf:resource="{vi:proxyIRI ('http://www.productwiki.com')}"/>
						</gr:BusinessEntity>

				<rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', 'Product')}">
                        	<opl:providedBy>
                        		<foaf:Organization rdf:about="http://www.productwiki.com#this">
                        			<foaf:name>Productwiki</foaf:name>
                        			<foaf:homepage rdf:resource="http://www.productwiki.com"/>
                        		</foaf:Organization>
                        	</opl:providedBy>

					<rdf:type rdf:resource="&gr;ProductOrServicesSomeInstancesPlaceholder" />
					<rdf:type rdf:resource="&oplbb;Product" />
				   <xsl:apply-templates select="//product[1]" />
				</rdf:Description>
		</rdf:RDF>
    </xsl:template>

    <xsl:template match="product[1]">
        <xsl:apply-templates select="*"/>
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

    <xsl:template match="product/description">
		<xsl:variable name="local_text" select="vi:convert_to_xtree(string(.))"/>
		<oplbb:description rdf:datatype="&xsd;string">
			<xsl:value-of select="."/>
		</oplbb:description>
		<xsl:for-each select="$local_text//li">
			<oplbb:feature rdf:datatype="&xsd;string">
				<xsl:value-of select="."/>
			</oplbb:feature>
		</xsl:for-each>
    </xsl:template>

    <xsl:template match="product/title">
		<oplbb:title rdf:datatype="&xsd;string">
			<xsl:value-of select="."/>
		</oplbb:title>
		<dc:title>
			<xsl:value-of select="." />
		</dc:title>
	</xsl:template>
	
    <xsl:template match="product/skus/sku/upc">
		<gr:hasEAN_UCC-13>
			<xsl:value-of select="."/>
		</gr:hasEAN_UCC-13>
    </xsl:template>

    <xsl:template match="product/skus/sku/asin">
		<oplamz:ASIN>
			<xsl:value-of select="."/>
		</oplamz:ASIN>	
    </xsl:template>

    <xsl:template match="product/skus/sku/mpn">
		<gr:hasMPN>
			<xsl:value-of select="."/>
		</gr:hasMPN>	
    </xsl:template>
	
    <xsl:template match="product/id">
		<oplbb:productId>
			<xsl:value-of select="."/>
		</oplbb:productId>
    </xsl:template>

    <xsl:template match="product/category">
		<oplbb:category>
			<xsl:value-of select="."/>
		</oplbb:category>
    </xsl:template>

    <xsl:template match="product/images/image/rawimage">
	<xsl:if test="string-length(.) &gt; 0">
	    <xsl:element namespace="&oplbb;" name="image">
		<xsl:attribute name="rdf:resource">
		    <xsl:value-of select="."/>
		</xsl:attribute>
	    </xsl:element>
	</xsl:if>
    </xsl:template>

	    <xsl:template match="product/images/image/largeimage">
	<xsl:if test="string-length(.) &gt; 0">
	    <xsl:element namespace="&oplbb;" name="image">
		<xsl:attribute name="rdf:resource">
		    <xsl:value-of select="."/>
		</xsl:attribute>
	    </xsl:element>
	</xsl:if>
    </xsl:template>

	    <xsl:template match="product/images/image/mediumimage">
	<xsl:if test="string-length(.) &gt; 0">
	    <xsl:element namespace="&oplbb;" name="image">
		<xsl:attribute name="rdf:resource">
		    <xsl:value-of select="."/>
		</xsl:attribute>
	    </xsl:element>
	</xsl:if>
    </xsl:template>
	
	    <xsl:template match="product/images/image/smallimage">
	<xsl:if test="string-length(.) &gt; 0">
	    <xsl:element namespace="&oplbb;" name="image">
		<xsl:attribute name="rdf:resource">
		    <xsl:value-of select="."/>
		</xsl:attribute>
	    </xsl:element>
	</xsl:if>
    </xsl:template>

    <xsl:template match="text()|@*"/>

</xsl:stylesheet>
