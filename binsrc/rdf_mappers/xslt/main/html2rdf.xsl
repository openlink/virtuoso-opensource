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
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY awol "http://bblfish.net/work/atom-owl/2006-06-06/#">
]>
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="&rdf;"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:skos="http://www.w3.org/2004/02/skos/core#"
  xmlns:sioc="&sioc;"
  xmlns:foaf="&foaf;"
  xmlns:owl="&owl;"
  xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
  xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
  xmlns:umbel="http://umbel.org/umbel#"
  xmlns:content="http://purl.org/rss/1.0/modules/content/"
  xmlns:awol="&awol;"
  version="1.0">
  <xsl:output method="xml" indent="yes" encoding="utf-8"/>
  <xsl:param name="baseUri" />
  <xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
  <xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
  <xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
  <xsl:variable name="uc">ABCDEFGHIJKLMNOPQRSTUVWXYZ</xsl:variable>
  <xsl:variable name="lc">abcdefghijklmnopqrstuvwxyz</xsl:variable>

  <xsl:template match="/">
      <rdf:RDF>
		<xsl:apply-templates select="html/head"/>
		<xsl:apply-templates select="/" mode="rdf-in-comment"/>
      </rdf:RDF>
  </xsl:template>

  <xsl:template match="html/head">
      <rdf:Description rdf:about="{$docproxyIRI}">
		<rdf:type rdf:resource="&bibo;Document"/>
		<dc:title><xsl:value-of select="$baseUri"/></dc:title>
		<owl:sameAs rdf:resource="{$docIRI}"/>
		<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
      </rdf:Description>
      <rdf:Description rdf:about="{$resourceURL}">
		<rdf:type rdf:resource="&bibo;Document"/>
		<xsl:apply-templates select="title|meta"/>
		<xsl:apply-templates select="//img[@src]"/>
		<xsl:apply-templates select="//a[@href]"/>
		<xsl:apply-templates select="link[@rel='alternate']"/>
		<xsl:variable name="doc1">
		    <xsl:apply-templates  select="/html/body" mode="content"/>
		</xsl:variable>
		<xsl:if test="not ($baseUri like 'http://%.nytimes.com/%')">
		    <awol:content>
			<awol:Content>
			    <!--awol:body rdf:parseType="Literal">
				<xsl:apply-templates select="$doc1" mode="content"/>
			    </awol:body-->
			    <awol:src rdf:resource="{$baseUri}"/>
			</awol:Content>
		    </awol:content>
		</xsl:if>
		<!--content:encoded><xsl:value-of select="vi:escape($doc1)" /></content:encoded-->
      </rdf:Description>
  </xsl:template>

  <xsl:template match="link[@rel='alternate']">
      <rdfs:seeAlso rdf:resource="{@href}"/>
  </xsl:template>

  <xsl:template match="*" mode="rdf-in-comment">
      <xsl:apply-templates mode="rdf-in-comment"/>
  </xsl:template>

  <xsl:template match="text()|@*" mode="rdf-in-comment">
  </xsl:template>

  <xsl:template match="comment()" mode="rdf-in-comment">
    <!-- first we parse in 'safe' mode -->
    <xsl:variable name="tmp" select="document-literal (., '', 2)"/>
		<xsl:if test="$tmp/rdf:rdf/*">
		<xsl:variable name="doc" select="document-literal (replace (., '&quot;xmlns', '&quot; xmlns'))"/>
		<xsl:copy-of select="$doc/rdf:RDF/*"/>
	</xsl:if>
  </xsl:template>

  <xsl:template match="title">
     <dc:title>
		<xsl:value-of select="."/>
     </dc:title>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='description']">
      <dc:description>
		<xsl:value-of select="@content"/>
      </dc:description>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='author']">
      <dc:creator>
		<xsl:value-of select="@content"/>
      </dc:creator>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='byl']">
      <dc:creator>
		<xsl:value-of select="@content"/>
      </dc:creator>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='copyrights']">
      <dc:rights>
		<xsl:value-of select="@content"/>
      </dc:rights>
  </xsl:template>

  <xsl:template match="meta[translate (@name, $uc, $lc)='keywords']">
      <dc:subject>
		<xsl:value-of select="@content"/>
	  </dc:subject>
      <!--xsl:variable name="res" select="vi:umbelGet (@content)"/>
      <xsl:for-each select="$res//object[@type='umbel:SubjectConcept']">
	  <umbel:isAbout rdf:resource="{@uri}"/>
      </xsl:for-each>
      <xsl:variable name="nes" select="vi:umbelGetNE (@content)"/>
      <xsl:for-each select="$nes//object[@type='owl:Thing']">
	  <owl:sameAs rdf:resource="{@uri}"/>
      </xsl:for-each-->
  </xsl:template>

  <xsl:template match="img[@src like 'http://farm%.static.flickr.com/%/%\\_%.%']">
      <foaf:depiction>
	  <foaf:Image rdf:about="{@src}"/>
      </foaf:depiction>
  </xsl:template>

  <xsl:template match="a[@href]">
      <xsl:variable name="url" select="resolve-uri ($baseUri, @href)"/>
      <xsl:if test="not ($url like 'javascript:%')">
	  <xsl:choose>
	      <xsl:when test="$url like 'http://www.amazon.com/gp/product/%' or $url like 'http://www.amazon.%/o/ASIN/%'">
		  <xsl:variable name="tmp"
		      select="vi:regexp-match ('(http://www.amazon.com/gp/product/[A-Z0-9]+)|(http://www.amazon.[^/]*/o/ASIN/[A-Z0-9]+)', $url)" />
		  <rdfs:seeAlso rdf:resource="{$tmp}"/>
	      </xsl:when>
	      <xsl:when test="$url like 'http://cgi.sandbox.ebay.com/%&amp;item=%&amp;%' or $url like 'http://cgi.ebay.com/%QQitemZ%QQ%'">
		  <rdfs:seeAlso rdf:resource="{$url}"/>
	      </xsl:when>
	      <xsl:when test="$url like 'urn:lsid:%' or $url like 'doi:%' or $url like 'oai:%'">
		  <rdfs:seeAlso rdf:resource="{vi:proxyIRI ($url, '', '')}"/>
	      </xsl:when>
	      <xsl:when test="$url like 'lsidres:urn:lsid:%'">
		  <rdfs:seeAlso rdf:resource="{substring-after ($url, 'lsidres:')}"/>
	      </xsl:when>
	      <xsl:otherwise>
		  <sioc:links_to rdf:resource="{$url}"/>
	      </xsl:otherwise>
	  </xsl:choose>
      </xsl:if>
  </xsl:template>

  <xsl:template match="*|text()"/>

  <!-- content of html -->
  <xsl:template match="body|html" mode="content">
      <xsl:apply-templates mode="content"/>
  </xsl:template>

  <xsl:template match="title" mode="content">
      <div>
	  <xsl:apply-templates mode="content" />
      </div>
  </xsl:template>

  <xsl:template match="object[embed]" mode="content">
      <xsl:apply-templates select="embed" mode="content"/>
  </xsl:template>

  <xsl:template match="head|script|form|input|button|textarea|object|frame|frameset|select" mode="content" />

  <xsl:template match="*" mode="content">
      <xsl:copy>
	  <xsl:copy-of select="@*[not starts-with (name(), 'on') and name() != 'class' and name() != 'style' ]"/>
	  <xsl:apply-templates  mode="content"/>
      </xsl:copy>
  </xsl:template>

  <xsl:template match="text()" mode="content">
      <xsl:value-of select="."/>
  </xsl:template>

</xsl:stylesheet>
