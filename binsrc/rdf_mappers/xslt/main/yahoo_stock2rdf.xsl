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
<!ENTITY stock "http://xbrlontology.com/ontology/finance/stock_market#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY opl "http://www.openlinksw.com/schema/attribution#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="&rdf;"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:dc   ="http://purl.org/dc/elements/1.1/"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:stock="&stock;"
    xmlns:opl="&opl;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:sioc="&sioc;"
    xmlns:dcterms="&dcterms;"
    xmlns:owl="&owl;"
    >

    <xsl:output method="xml" indent="yes" />
    <xsl:param name="baseUri" />
    <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
    <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

    <xsl:template match="/">
	<rdf:RDF>
	    <xsl:apply-templates select="*"/>
	</rdf:RDF>
    </xsl:template>

    <xsl:template match="quote">
	<xsl:variable name="pt" select="vi:proxyIRI(concat('http://finance.yahoo.com/q?s=', symbol))"/>
	<rdf:Description rdf:about="{$docproxyIRI}">
	    <rdf:type rdf:resource="&bibo;Document"/>
	    <dc:title><xsl:value-of select="$baseUri"/></dc:title>
	    <sioc:container_of rdf:resource="{$pt}"/>
	    <foaf:primaryTopic rdf:resource="{$pt}"/>
	    <dcterms:subject rdf:resource="{$pt}"/>
	    <owl:sameAs rdf:resource="{$pt}"/>
	</rdf:Description>
	<rdf:Description rdf:about="{vi:proxyIRI(concat ('http://dbpedia.org/resource/', @stock))}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://finance.yahoo.com#this">
                                 			<foaf:name>Yahoo! Stock</foaf:name>
                                 			<foaf:homepage rdf:resource="http://finance.yahoo.com"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>

	    <rdf:type rdf:resource="&stock;StockMarket"/>
	</rdf:Description>
	<rdf:Description rdf:about="{vi:proxyIRI(concat ('http://finance.yahoo.com/q?s=', symbol), '', '#price')}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://finance.yahoo.com#this">
                                 			<foaf:name>Yahoo! Stock</foaf:name>
                                 			<foaf:homepage rdf:resource="http://finance.yahoo.com"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>
	    <rdf:type rdf:resource="&stock;DailyPrice"/>
	    <stock:bid><xsl:value-of select="bid"/></stock:bid>
	    <stock:ask><xsl:value-of select="ask"/></stock:ask>
	    <stock:open.price><xsl:value-of select="open"/></stock:open.price>
	    <stock:prev.close><xsl:value-of select="prev.close"/></stock:prev.close>
	    <stock:days-High><xsl:value-of select="high"/></stock:days-High>
	    <stock:days-Low><xsl:value-of select="low"/></stock:days-Low>
	    <stock:relativeToStock rdf:resource="{vi:proxyIRI(concat ('http://finance.yahoo.com/q?s=', symbol))}"/>
	</rdf:Description>
	<rdf:Description rdf:about="{vi:proxyIRI(concat('http://finance.yahoo.com/q?s=', symbol))}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://finance.yahoo.com#this">
                                 			<foaf:name>Yahoo! Stock</foaf:name>
                                 			<foaf:homepage rdf:resource="http://finance.yahoo.com"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>
	    <rdf:type rdf:resource="&stock;Stock"/>
	    <stock:hasDailyPrice rdf:resource="{vi:proxyIRI(concat('http://finance.yahoo.com/q?s=', symbol), '', '#price')}"/>
	    <stock:partOfCompany rdf:resource="{vi:proxyIRI(concat ('http://dbpedia.org/resource/', symbol))}"/>
	    <stock:relativeToStockMarket rdf:resource="{vi:proxyIRI(concat ('http://dbpedia.org/resource/', @stock))}"/>
	</rdf:Description>
	<rdf:Description rdf:about="{vi:proxyIRI(concat ('http://dbpedia.org/resource/', symbol))}">
                                 	<opl:providedBy>
                                 		<foaf:Organization rdf:about="http://finance.yahoo.com#this">
                                 			<foaf:name>Yahoo! Stock</foaf:name>
                                 			<foaf:homepage rdf:resource="http://finance.yahoo.com"/>
                                 		</foaf:Organization>
                                 	</opl:providedBy>
	    <rdf:type rdf:resource="&stock;Company"/>
	    <stock:hasStocks rdf:resource="{vi:proxyIRI(concat ('http://finance.yahoo.com/q?s=', symbol))}"/>
	    <stock:companyName><xsl:value-of select="company"/></stock:companyName>
	</rdf:Description>
    </xsl:template>

    <xsl:template match="history">
	<xsl:for-each select="hist-price">
	    <rdf:Description rdf:ID="{date}">
		<rdfs:label><xsl:value-of select="../@symbol"/> on <xsl:value-of select="date"/></rdfs:label>
		<dcterms:issued><xsl:value-of select="date"/></dcterms:issued>
		<rdf:type rdf:resource="&stock;PriceHistory"/>
		<stock:highPrice><xsl:value-of select="high"/></stock:highPrice>
		<stock:lowPrice><xsl:value-of select="low"/></stock:lowPrice>
		<stock:open.price><xsl:value-of select="open"/></stock:open.price>
		<stock:close><xsl:value-of select="open"/></stock:close>
		<stock:volume><xsl:value-of select="volume"/></stock:volume>
		<stock:adjClose><xsl:value-of select="adjclose"/></stock:adjClose>
		<stock:relativeToStock rdf:resource="{vi:proxyIRI(concat ('http://finance.yahoo.com/q?s=', ../@symbol))}"/>
	    </rdf:Description>
	</xsl:for-each>
	<rdf:Description rdf:about="{vi:proxyIRI(concat ('http://finance.yahoo.com/q?s=', @symbol))}">
	    <xsl:for-each select="hist-price">
		<stock:hasPriceHist rdf:resource="#{date}"/>
	    </xsl:for-each>
	</rdf:Description>
    </xsl:template>

    <xsl:template match="text()"/>

</xsl:stylesheet>
