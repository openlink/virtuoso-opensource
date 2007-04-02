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
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
  xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
  version="1.0">
  <xsl:output method="xml" indent="yes"/>
  <xsl:param name="base" />
  <xsl:template match="/">
      <rdf:RDF>
	  <xsl:apply-templates select="html/head"/>
	  <xsl:apply-templates select="/" mode="rdf-in-comment"/>
      </rdf:RDF>
  </xsl:template>
  <xsl:template match="html/head">
      <foaf:Document rdf:about="{$base}">
	  <xsl:apply-templates select="title|meta"/>
	  <xsl:apply-templates select="/html/body//img[@src]"/>
	  <xsl:apply-templates select="/html/body//a[@href]"/>
      </foaf:Document>
  </xsl:template>
  <xsl:template match="*" mode="rdf-in-comment">
      <xsl:apply-templates mode="rdf-in-comment"/>
  </xsl:template>
  <xsl:template match="text()|@*" mode="rdf-in-comment">
  </xsl:template>
  <xsl:template match="comment()" mode="rdf-in-comment">
      <!-- first we parse in 'safe' mode -->
      <xsl:variable name="tmp" select="document-literal (., '', 2)"/>
      <xsl:if test="$tmp/rdf:rdf/rdf:*">
      <xsl:variable name="doc" select="document-literal (.)"/>
	  <xsl:copy-of select="$doc/rdf:RDF/rdf:*"/>
      </xsl:if>
  </xsl:template>
  <xsl:template match="title">
      <dc:title>
	  <xsl:value-of select="."/>
      </dc:title>
  </xsl:template>
  <xsl:template match="meta[@name='description']">
      <dc:description>
	  <xsl:value-of select="@content"/>
      </dc:description>
  </xsl:template>
  <xsl:template match="meta[@name='copyrights']">
      <dc:rights>
	  <xsl:value-of select="@content"/>
      </dc:rights>
  </xsl:template>
  <xsl:template match="meta[@name='keywords']">
      <dc:subject>
	  <xsl:value-of select="@content"/>
      </dc:subject>
  </xsl:template>
  <!-- content specific rules -->
  <xsl:template match="img[@src like 'http://farm%.static.flickr.com/%/%\\_%.%']">
      <foaf:depiction>
	  <foaf:Image rdf:about="{@src}"/>
      </foaf:depiction>
  </xsl:template>
  <xsl:template match="a[@href]">
      <xsl:variable name="url" select="resolve-uri ($base, @href)"/>
      <xsl:choose>
	  <xsl:when test="$url like 'http://www.amazon.com/gp/product/%' or $url like 'http://www.amazon.%/o/ASIN/%'">
	      <xsl:variable name="tmp"
		  select="vi:regexp-match ('(http://www.amazon.com/gp/product/[A-Z0-9]+)|(http://www.amazon.[^/]*/o/ASIN/[A-Z0-9]+)', $url)" />
	      <rdfs:seeAlso rdf:resource="{$tmp}"/>
	  </xsl:when>
	  <xsl:when test="$url like 'http://cgi.sandbox.ebay.com/%&amp;item=%&amp;%' or $url like 'http://cgi.ebay.com/%QQitemZ%QQ%'">
	      <rdfs:seeAlso rdf:resource="{$url}"/>
	  </xsl:when>
      </xsl:choose>
  </xsl:template>
  <xsl:template match="*|text()"/>
</xsl:stylesheet>
