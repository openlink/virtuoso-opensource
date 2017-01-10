<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2017 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
xmlns:v="http://www.w3.org/2006/vcard/ns#"
xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
xmlns:h="http://www.w3.org/1999/xhtml"
xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
xmlns:foaf="http://xmlns.com/foaf/0.1/"
xmlns:dc="http://purl.org/dc/elements/1.1/"
xmlns:dcterms="http://purl.org/dc/terms/"
xmlns:review="http://www.purl.org/stuff/rev#"
xmlns:bibo="http://purl.org/ontology/bibo/"
xmlns:hrev="http://www.purl.org/stuff/hrev#" version="1.0">
  <xsl:output method="xml" encoding="utf-8" indent="yes" />
  <xsl:preserve-space elements="*" />
  <xsl:param name="baseUri" />
  <xsl:variable name="docproxyIRI"
  select="vi:docproxyIRI($baseUri)" />
  <xsl:template match="/">
  <rdf:RDF>
	<xsl:apply-templates />
  </rdf:RDF>
</xsl:template>
  <xsl:template match="*">
    <xsl:variable name="hreview">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'hreview'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:if test="$hreview != 0">
      <rdf:Description rdf:about="{$docproxyIRI}">
        <foaf:topic rdf:resource="{vi:proxyIRI($baseUri, '', concat('hreview', position()))}" />
      </rdf:Description>
      <review:Review rdf:about="{vi:proxyIRI ($baseUri, '', concat('hreview', position()))}">

        <xsl:apply-templates mode="extract-hreview" />
  </review:Review>
    </xsl:if>
    <xsl:apply-templates />
</xsl:template>
  <xsl:template match="comment()|processing-instruction()|text()" />
  <!-- ============================================================ -->
  <xsl:template match="*" mode="extract-hreview">
    <xsl:variable name="version">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'version'" />
      </xsl:call-template>
  </xsl:variable>
    <xsl:variable name="summary">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'summary'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="reviewer">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'reviewer'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="dtreviewed">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'dtreviewed'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="rating">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'rating'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="description">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'description'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="tags">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'tags'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="permalink">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'permalink'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="license">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'license'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="item">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'item'" />
      </xsl:call-template>
    </xsl:variable>
    <!-- ============================================================ -->
    <xsl:if test="$item != 0">
    <xsl:apply-templates select="." mode="extract-item"/>
  </xsl:if>
    <xsl:if test="$version != 0">
      <review:version>
        <xsl:value-of select="." />
      </review:version>
    </xsl:if>
    <xsl:if test="$summary != 0">
      <dc:description>
        <xsl:value-of select="." />
      </dc:description>
    </xsl:if>
    <xsl:if test="$reviewer != 0 and a/@href">
	<review:reviewer>
		  <foaf:Person rdf:about="{vi:proxyIRI($baseUri, '', concat('reviewer', .))}">
			<foaf:name><xsl:value-of select="."/></foaf:name>
			<bibo:uri rdf:resource="{a/@href}"/>
	  </foaf:Person>
	</review:reviewer>
    </xsl:if>
    <xsl:if test="$dtreviewed != 0">
      <dcterms:modified>
        <xsl:value-of select="." />
      </dcterms:modified>
    </xsl:if>
    <xsl:if test="$rating != 0">
      <review:rating>
	<xsl:variable name="rate" select="normalize-space(.)"/>
	<xsl:choose>
	<xsl:when test=".//*[@class='value-title']">
		<xsl:variable name="rate2" select=".//*[@class='value-title']/@title"/>
	        <xsl:value-of select="$rate2" />
	</xsl:when>
	<xsl:when test="string-length($rate) &gt; 0">
	        <xsl:value-of select="$rate" />
	</xsl:when>
	<xsl:otherwise>
	        <xsl:value-of select="'0'" />
	</xsl:otherwise>
	</xsl:choose>
      </review:rating>
    </xsl:if>
    <xsl:if test="$description != 0">
      <review:text>
        <xsl:value-of select="." />
      </review:text>
    </xsl:if>
    <xsl:if test="$tags != 0">
      <review:tags>
        <xsl:value-of select="." />
      </review:tags>
    </xsl:if>
    <xsl:if test="$permalink != 0 and @src">
      <bibo:uri rdf:resource="{@src}" />
    </xsl:if>
    <xsl:if test="$license != 0">
      <review:license>
        <xsl:value-of select="." />
      </review:license>
    </xsl:if>
    <xsl:apply-templates mode="extract-hreview" />
</xsl:template>
  <xsl:template match="comment()|processing-instruction()|text()"
  mode="extract-hreview" />
  <!-- ============================================================ -->
  <xsl:template match="*" mode="extract-item">
    <xsl:variable name="fn">
      <xsl:call-template name="testclass">
        <xsl:with-param name="val" select="'fn'" />
      </xsl:call-template>
    </xsl:variable>
    <xsl:if test="$fn != 0">
      <review:title>
        <xsl:value-of select="." />
      </review:title>
    </xsl:if>
    <xsl:apply-templates mode="extract-item" />
  </xsl:template>
  <xsl:template match="comment()|processing-instruction()|text()"
  mode="extract-item" />

  <xsl:template name="testclass">
    <xsl:param name="class" select="@class" />
    <xsl:param name="val" select="''" />
    <xsl:choose>
      <xsl:when test="$class = $val or starts-with($class,concat($val, ' ')) or contains($class,concat(' ',$val,' ')) or substring($class, string-length($class)-string-length($val)) = concat(' ',$val)">
      1</xsl:when>
      <xsl:otherwise>0</xsl:otherwise>
    </xsl:choose>
  </xsl:template>
</xsl:stylesheet>
