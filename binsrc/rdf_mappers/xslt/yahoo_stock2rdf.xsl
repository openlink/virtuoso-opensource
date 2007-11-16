<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE xsl:stylesheet [
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY stock "http://xbrlontology.com/ontology/finance/stock_market#">
]>
<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2006 OpenLink Software
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
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="&rdf;"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:dc   ="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms = "http://purl.org/dc/terms/"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:stock="&stock;"
    >

    <xsl:output method="xml" indent="yes" />
    <xsl:param name="baseUri" />

    <xsl:template match="/">
	<rdf:RDF>
	    <xsl:apply-templates select="*"/>
	</rdf:RDF>
    </xsl:template>

    <xsl:template match="quote">
	<rdf:Description rdf:about="http://dbpedia.org/resource/{@stock}">
	    <rdf:type rdf:resource="&stock;StockMarket"/>
	</rdf:Description>
	<rdf:Description rdf:about="http://finance.yahoo.com/q?s={symbol}#price">
	    <rdf:type rdf:resource="&stock;DailyPrice"/>
	    <stock:bid><xsl:value-of select="bid"/></stock:bid>
	    <stock:ask><xsl:value-of select="ask"/></stock:ask>
	    <stock:open.price><xsl:value-of select="open"/></stock:open.price>
	    <stock:prev.close><xsl:value-of select="prev.close"/></stock:prev.close>
	    <stock:days-High><xsl:value-of select="high"/></stock:days-High>
	    <stock:days-Low><xsl:value-of select="low"/></stock:days-Low>
	    <stock:relativeToStock rdf:resource="http://finance.yahoo.com/q?s={symbol}#this"/>
	</rdf:Description>
	<rdf:Description rdf:about="http://finance.yahoo.com/q?s={symbol}#this">
	    <rdf:type rdf:resource="&stock;Stock"/>
	    <stock:hasDailyPrice rdf:resource="http://finance.yahoo.com/q?s={symbol}#price"/>
	    <stock:partOfCompany rdf:resource="http://dbpedia.org/resource/{symbol}"/>
	    <stock:relativeToStockMarket rdf:resource="http://dbpedia.org/resource/{@stock}"/>
	</rdf:Description>
	<rdf:Description rdf:about="http://dbpedia.org/resource/{symbol}">
	    <rdf:type rdf:resource="&stock;Company"/>
	    <stock:hasStocks rdf:resource="http://finance.yahoo.com/q?s={symbol}#this"/>
	    <stock:companyName><xsl:value-of select="company"/></stock:companyName>
	</rdf:Description>
    </xsl:template>

    <xsl:template match="history">
	<xsl:for-each select="hist-price">
	    <rdf:Description rdf:ID="{date}">
		<rdfs:label><xsl:value-of select="../@symbol"/> on <xsl:value-of select="date"/></rdfs:label>
		<dc:date><xsl:value-of select="date"/></dc:date>
		<rdf:type rdf:resource="&stock;PriceHistory"/>
		<stock:highPrice><xsl:value-of select="high"/></stock:highPrice>
		<stock:lowPrice><xsl:value-of select="low"/></stock:lowPrice>
		<stock:open.price><xsl:value-of select="open"/></stock:open.price>
		<stock:close><xsl:value-of select="open"/></stock:close>
		<stock:volume><xsl:value-of select="volume"/></stock:volume>
		<stock:adjClose><xsl:value-of select="adjclose"/></stock:adjClose>
		<stock:relativeToStock rdf:resource="http://finance.yahoo.com/q?s={../@symbol}#this"/>
	    </rdf:Description>
	</xsl:for-each>
	<rdf:Description rdf:about="http://finance.yahoo.com/q?s={@symbol}#this">
	    <xsl:for-each select="hist-price">
		<stock:hasPriceHist rdf:resource="#{date}"/>
	    </xsl:for-each>
	</rdf:Description>
    </xsl:template>

    <xsl:template match="text()"/>

</xsl:stylesheet>
