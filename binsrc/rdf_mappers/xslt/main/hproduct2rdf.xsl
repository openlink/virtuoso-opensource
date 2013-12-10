<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2013 OpenLink Software
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
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY gr "http://purl.org/goodrelations/v1#">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
]>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
	xmlns:v="http://www.w3.org/2006/vcard/ns#"
	xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
	xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:rdf="&rdf;"
    xmlns:foaf="&foaf;"
    xmlns:bibo="&bibo;"
    xmlns:dc="&dc;"
    xmlns:sioc="&sioc;"
    xmlns:dcterms="&dcterms;"
    xmlns:gr="&gr;">

<xsl:output method="xml" encoding="utf-8" indent="yes"/>

<xsl:preserve-space elements="*"/>

<xsl:param name="baseUri"/>
<xsl:variable name="resourceURL" select="vi:proxyIRI ($baseUri)"/>
<xsl:variable  name="docIRI" select="vi:docIRI($baseUri)"/>
<xsl:variable  name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

<xsl:template match="/">
  <rdf:RDF>
    <xsl:apply-templates/>
  </rdf:RDF>
</xsl:template>

<xsl:template match="*">
  <xsl:variable name="hproduct">
    <xsl:call-template name="testclass">
      <xsl:with-param name="val" select="'hproduct'"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:if test="$hproduct != 0">
	<rdf:Description rdf:about="{$docproxyIRI}">
        <foaf:topic rdf:resource="{vi:proxyIRI ($baseUri, '', 'hproduct')}" />
	</rdf:Description>
    <gr:ProductOrService rdf:about="{vi:proxyIRI ($baseUri, '', 'hproduct')}">
      <xsl:apply-templates mode="extract-hproduct"/>
    </gr:ProductOrService>
  </xsl:if>

  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="comment()|processing-instruction()|text()"/>

<!-- ============================================================ -->

<xsl:template match="*" mode="extract-hproduct">
  <xsl:variable name="fn">
    <xsl:call-template name="testclass">
      <xsl:with-param name="val" select="'fn'"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="brand">
    <xsl:call-template name="testclass">
      <xsl:with-param name="val" select="'brand'"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="review">
    <xsl:call-template name="testclass">
      <xsl:with-param name="val" select="'review'"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="category">
    <xsl:call-template name="testclass">
      <xsl:with-param name="val" select="'category'"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="price">
    <xsl:call-template name="testclass">
      <xsl:with-param name="val" select="'price'"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="description">
    <xsl:call-template name="testclass">
      <xsl:with-param name="val" select="'description'"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="url">
    <xsl:call-template name="testclass">
      <xsl:with-param name="val" select="'url'"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="listing">
    <xsl:call-template name="testclass">
      <xsl:with-param name="val" select="'listing'"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="identifier">
    <xsl:call-template name="testclass">
      <xsl:with-param name="val" select="'identifier'"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="type">
    <xsl:call-template name="testclass">
      <xsl:with-param name="val" select="'type'"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="value">
    <xsl:call-template name="testclass">
      <xsl:with-param name="val" select="'value'"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="photo">
    <xsl:call-template name="testclass">
      <xsl:with-param name="val" select="'photo'"/>
    </xsl:call-template>
  </xsl:variable>

  <!-- ============================================================ -->

  <xsl:if test="$fn != 0">
    <dc:title>
		<xsl:value-of select="."/>
	</dc:title>
  </xsl:if>

  <xsl:if test="$brand != 0">
	<gr:hasManufacturer>
		<gr:BusinessEntity rdf:ID="manufacturer">
	    <rdfs:label><xsl:value-of select="concat('Manufacturer ', .)"/></rdfs:label>
			<gr:legalName><xsl:value-of select="."/></gr:legalName>
		</gr:BusinessEntity>
	</gr:hasManufacturer>
  </xsl:if>

  <xsl:if test="$category != 0">
    <v:category>
      <xsl:value-of select="."/>
    </v:category>
  </xsl:if>

  <xsl:if test="$price != 0">
	<gr:hasPriceSpecification>
		<gr:UnitPriceSpecification  rdf:ID="price">
	    <rdfs:label><xsl:value-of select="concat('List Price of ', .)"/></rdfs:label>
        <gr:hasCurrencyValue rdf:datatype="&xsd;float"><xsl:value-of select="."/></gr:hasCurrencyValue>
        </gr:UnitPriceSpecification>
	</gr:hasPriceSpecification>
 </xsl:if>

  <xsl:if test="$description != 0">
    <rdfs:comment>
		<xsl:value-of select="."/>
	</rdfs:comment>
  </xsl:if>

  <xsl:if test="$photo != 0 and @src">
    <foaf:img rdf:resource="{@src}"/>
  </xsl:if>

  <xsl:if test="$url != 0">
    <bibo:url>
      <xsl:attribute name="rdf:resource">
	<xsl:choose>
	  <xsl:when test="@href">
	    <xsl:value-of select="@href"/>
	  </xsl:when>
	  <xsl:otherwise>
	    <xsl:if test="not(contains(.,':'))">http://</xsl:if>
	    <xsl:value-of select="string(.)"/>
	  </xsl:otherwise>
	</xsl:choose>
      </xsl:attribute>
    </bibo:url>
  </xsl:if>

  <xsl:if test="$review != 0">
    <dc:description>
		<xsl:value-of select="."/>
	</dc:description>
  </xsl:if>

  <xsl:apply-templates mode="extract-hproduct"/>
</xsl:template>

<xsl:template match="comment()|processing-instruction()|text()"
	      mode="extract-hproduct"/>



<!-- ============================================================ -->

<xsl:template match="*" mode="field-exists">
  <xsl:param name="field" select="''"/>

  <xsl:variable name="f">
    <xsl:call-template name="testclass">
      <xsl:with-param name="val" select="$field"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="$f != 0">
      <xsl:value-of select="."/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates select="*" mode="field-exists">
	<xsl:with-param name="field" select="$field"/>
      </xsl:apply-templates>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="comment()|processing-instruction()|text()"
	      mode="field-exists"/>

<!-- ============================================================ -->

<xsl:template match="*" mode="extract-field">
  <xsl:param name="field" select="''"/>
  <xsl:param name="prop" select="concat('v:',$field)"/>

  <xsl:variable name="f">
    <xsl:call-template name="testclass">
      <xsl:with-param name="val" select="$field"/>
    </xsl:call-template>
  </xsl:variable>

  <!--
  <xsl:message>f: <xsl:value-of select="$f"/>; field: <xsl:value-of select="$field"/>; c: <xsl:value-of select="@class"/></xsl:message>
  -->

  <xsl:if test="$f != 0">
    <xsl:element name="{$prop}">
      <xsl:value-of select="."/>
    </xsl:element>
  </xsl:if>

  <xsl:apply-templates select="*" mode="extract-field">
    <xsl:with-param name="field" select="$field"/>
    <xsl:with-param name="prop" select="$prop"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="comment()|processing-instruction()|text()"
	      mode="extract-field"/>

<!-- ============================================================ -->

<xsl:template name="testclass">
  <xsl:param name="class" select="@class"/>
  <xsl:param name="val" select="''"/>

  <xsl:choose>
    <xsl:when test="$class = $val
		    or starts-with($class,concat($val, ' '))
		    or contains($class,concat(' ',$val,' '))
		    or substring($class, string-length($class)-string-length($val)) = concat(' ',$val)">1</xsl:when>
    <xsl:otherwise>0</xsl:otherwise>
  </xsl:choose>
</xsl:template>


</xsl:stylesheet>
