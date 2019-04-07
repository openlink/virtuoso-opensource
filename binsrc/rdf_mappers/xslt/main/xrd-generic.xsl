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
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY vi "http://www.openlinksw.com/virtuoso/xslt/">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
]>
<xsl:stylesheet 
  xmlns:dc="&dc;"
  xmlns:dcterms="&dcterms;"
  xmlns:foaf="&foaf;"
  xmlns:owl="&owl;"	
  xmlns:rdf="&rdf;" 
  xmlns:rdfs="&rdfs;" 
  xmlns:sioc="&sioc;"
  xmlns:vi="&vi;" 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  version="1.0">
  <xsl:output method="xml" indent="yes"/>

  <xsl:param name="baseUri"/>
  <xsl:variable name="resourceURL" select="vi:proxyIRI($baseUri)"/>
  <xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
  <xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>

  <xsl:variable name="profilePage" select="/XRD/Subject[0]"/>
  <xsl:variable name="profilePage2" select="/XRD/Alias"/>
  
  <xsl:template match="/XRD">
    <rdf:RDF>
    
      <rdf:Description rdf:about="{$docproxyIRI}">
        <rdf:type rdf:resource="&bibo;Document"/>
        <dc:title><xsl:value-of select="substring-after($baseUri, ':')"/></dc:title>
        <rdfs:label><xsl:value-of select="substring-after($baseUri, ':')"/></rdfs:label>
        <rdf:type rdf:resource="&sioc;Container"/>
        <sioc:container_of rdf:resource="{$resourceURL}"/>
        <foaf:primaryTopic rdf:resource="{$resourceURL}"/>
        <dcterms:subject rdf:resource="{$resourceURL}"/>
        <owl:sameAs rdf:resource="{$docIRI}"/>
      </rdf:Description>
    
      <rdf:Description rdf:about="{$resourceURL}">
        <sioc:has_container rdf:resource="{$docproxyIRI}" />
        <xsl:apply-templates select="Link[@rel='describedby']" mode="topicdescriptors"/>
        <xsl:apply-templates select="Link" mode="stmt"/>
      </rdf:Description>
    </rdf:RDF>
  </xsl:template>
  
  <xsl:template match="Link" mode="topicdescriptors">
    <rdfs:seeAlso rdf:resource="{@href}"/>
  </xsl:template>
  
  <xsl:template match="Link" mode="stmt">
    <xsl:variable name="split">
      <xsl:copy-of select="vi:IRISPLIT(@rel)"/>
    </xsl:variable>
    <xsl:variable name="ns">
      <xsl:value-of select="$split//ns"/>
    </xsl:variable>
    <xsl:variable name="loc">
      <xsl:value-of select="$split//loc"/>
    </xsl:variable>
    <xsl:if test="string-length(normalize-space($ns))&gt;0 and string-length(normalize-space($loc))&gt;0">
      <xsl:element name="{$loc}" namespace="{$ns}">
        <xsl:attribute name="rdf:resource">
          <xsl:value-of select="@href"/>
        </xsl:attribute>
      </xsl:element>
    </xsl:if>
    
    <xsl:if test="normalize-space($ns)='' and normalize-space($loc)='describedby'">
      <xsl:element name="describedby" namespace="http://docs.oasis-open.org/ns/xri/xrd-1.0/">
      <xsl:attribute name="rdf:resource"><xsl:value-of select="@href" /></xsl:attribute>
      </xsl:element>
    </xsl:if>
    
  </xsl:template>
  
  <xsl:template match="text()|@*"/>
</xsl:stylesheet>

