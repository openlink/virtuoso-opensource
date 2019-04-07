<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2019 OpenLink Software
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
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns="http://www.w3.org/1999/xhtml"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms="http://purl.org/dc/terms/"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    version="1.0">
    
  <xsl:output method="xml" indent="yes"/>
  
  <xsl:param name="baseUri"/>
  <xsl:variable name="uc">ABCDEFGHIJKLMNOPQRSTUVWXYZ</xsl:variable>
  <xsl:variable name="lc">abcdefghijklmnopqrstuvwxyz</xsl:variable>
  <xsl:variable name="resourceURL" select="vi:proxyIRI($baseUri)"/>
  <xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
  <xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
  
  <xsl:template match="/">
    <rdf:RDF>
      <xsl:apply-templates select="//h:head/h:meta|//h:head/h:link" mode="ref"/>
      <rdf:Description rdf:about="{$resourceURL}">
        <xsl:apply-templates select="//h:head/h:meta|//h:head/h:link" mode="gen"/>
      </rdf:Description>
    </rdf:RDF>
  </xsl:template>
  
  <xsl:template match="h:meta" mode="ref">
    <xsl:variable name="p" select="vi:docproxyIRI($baseUri, '', vi:saneURI(./@name, -1))"/>
    <owl:DatatypeProperty rdf:about="{$p}">
      <rdfs:label>
        <xsl:value-of select="@name"/>
      </rdfs:label>
      <rdfs:isDefinedBy rdf:resource="{vi:docproxyIRI($baseUri,'','schema')}"/>
    </owl:DatatypeProperty>
  </xsl:template>
  
  <xsl:template match="h:link" mode="ref">
    <xsl:variable name="p" select="vi:docproxyIRI($baseUri, '', vi:saneURI(./@rel, -1))"/>
    <owl:DatatypeProperty rdf:about="{$p}">
      <rdfs:label>
        <xsl:value-of select="@rel"/>
      </rdfs:label>
      <rdfs:isDefinedBy rdf:resource="{vi:docproxyIRI($baseUri,'','schema')}"/>
    </owl:DatatypeProperty>
  </xsl:template>
  
  <xsl:template match="h:meta" mode="gen">
    <xsl:variable name="p" select="vi:docproxyIRI($baseUri, '', vi:saneURI(./@name, -1))"/>
    <xsl:variable name="lp" select="vi:saneURI(./@name, -1)"/>
    <xsl:element name="{$lp}" namespace="{concat($baseUri, '#')}"><xsl:value-of select="@content" /></xsl:element>
  </xsl:template>

  <xsl:template match="h:link" mode="gen">
    <xsl:variable name="p" select="vi:docproxyIRI($baseUri, '', vi:saneURI(./@rel, -1))"/>
    <xsl:variable name="lp" select="vi:saneURI(./@rel, -1)"/>
    <xsl:element name="{$lp}" namespace="{concat($baseUri, '#')}"><xsl:value-of select="@href" /></xsl:element>
  </xsl:template>
  
  <xsl:template match="text()|@*"/>
</xsl:stylesheet>

