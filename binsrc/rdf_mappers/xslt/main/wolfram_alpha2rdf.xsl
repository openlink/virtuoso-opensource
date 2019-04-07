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
<!DOCTYPE xsl:stylesheet [
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY wa "http://www.openlinksw.com/schemas/wolframalpha#">
]>

<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms="http://purl.org/dc/terms/"
    xmlns:dcmitype="http://purl.org/dc/dcmitype/"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:bibo="&bibo;"
    xmlns:wa="&wa;"
    xmlns:sioc="&sioc;"
    xmlns:foaf="&foaf;"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    version="1.0">
    
  <xsl:output method="xml" indent="yes"/>
  <xsl:param name="baseUri"/>
  <xsl:variable name="resourceURL" select="vi:proxyIRI($baseUri)"/>
  <xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
  <xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
  
  <xsl:template match="/">
    <rdf:RDF>
      <rdf:Description rdf:about="{$docproxyIRI}">
        <rdf:type rdf:resource="&bibo;Document"/>
        <dc:title>
          <xsl:value-of select="$baseUri"/>
        </dc:title>
        <sioc:container_of rdf:resource="{$resourceURL}"/>
        <foaf:primaryTopic rdf:resource="{$resourceURL}"/>
        <dcterms:subject rdf:resource="{$resourceURL}"/>
        <owl:sameAs rdf:resource="{$docIRI}"/>
      </rdf:Description>
      
      <xsl:apply-templates select="/queryresult/pod" mode="predicates" />
      
      <rdf:Description rdf:about="{$resourceURL}">
        <xsl:apply-templates select="/queryresult/pod" />
        <wa:score><xsl:value-of select="1.0 div (1.0+count(//assumption))" /></wa:score>
        <rdf:type rdf:resource="&wa;Query" />
        <xsl:apply-templates select="/queryresult/sources/source" mode="source" />
      </rdf:Description>
    </rdf:RDF>
  </xsl:template>
  
  <xsl:template match="pod[@primary='true']">
  <!-- If we know W|A are so certain about it, we promote it to being an "official" answer -->
    <wa:primary_answer><xsl:value-of select="./subpod/plaintext" /></wa:primary_answer>
    <rdf:type rdf:resource="&wa;Answer" />
  </xsl:template>
  
  <xsl:template match="pod[@id='Input']">
  <!-- Special pod indicates how the input query was resolved -->
    <wa:normative_query><xsl:value-of select="./subpod/plaintext" /></wa:normative_query>
    <rdfs:seeAlso>
      <wa:Query rdf:about="{concat('http://www.wolframalpha.com/input/?i=', vi:escapeURI(./subpod/plaintext))}">
        <rdfs:label><xsl:value-of select="subpod/plaintext" /></rdfs:label>
      </wa:Query>
    </rdfs:seeAlso>
  </xsl:template>
  
  <xsl:template match="pod" mode="predicates">
  <!-- Generate ontology statements about predicates -->
    <xsl:variable name="pred" select="concat('&wa;', vi:saneURI(./@title))" />
    <owl:DatatypeProperty rdf:about="{$pred}">
      <rdfs:isDefinedBy rdf:resource="&wa;" />
      <rdfs:label><xsl:value-of select="@title" /></rdfs:label>
      <rdfs:comment><xsl:value-of select="concat(@title, ' - ', @id)" /></rdfs:comment>
    </owl:DatatypeProperty>
  </xsl:template>
  
  <xsl:template match="pod">
  <!-- Each pod determines the predicate at hand -->
    <xsl:apply-templates select="subpod">
      <xsl:with-param name="pred"><xsl:value-of select="vi:saneURI(./@title)" /></xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="subpod[string-length(normalize-space(plaintext))&gt;0]">
    <xsl:param name="pred" />
    <xsl:element name="{$pred}" namespace="&wa;"><xsl:value-of select="plaintext" /></xsl:element>
  </xsl:template>

  <xsl:template match="source" mode="source">
    <rdfs:seeAlso>
      <wa:Source rdf:about="{@url}">
        <rdfs:label><xsl:value-of select="@text" /></rdfs:label>
      </wa:Source>
    </rdfs:seeAlso>
  </xsl:template>
  
  <xsl:template match="*|@*|text()"/>
  <xsl:template match="*|@*|text()" mode="predicates" />
  <xsl:template match="*|@*|text()" mode="source" />
</xsl:stylesheet>

