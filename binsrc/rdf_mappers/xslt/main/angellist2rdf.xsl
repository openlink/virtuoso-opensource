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
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY oplangel "http://www.openlinksw.com/schemas/angel#">
<!ENTITY oplli "http://www.openlinksw.com/schemas/linkedin#">
<!ENTITY opltw "http://www.openlinksw.com/schemas/twitter#">
<!ENTITY oplog "http://www.openlinksw.com/schemas/opengraph#">
<!ENTITY oplbase "http://www.openlinksw.com/schemas/oplbase#">
]>

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
    xmlns:oplangel="&oplangel;"
    xmlns:opltw="&opltw;"
    xmlns:oplli="&oplli;"
    xmlns:oplog="&oplog;"
    xmlns:oplbase="&oplbase;"
    xmlns:gn="http://www.geonames.org/ontology#" 
    xmlns:foaf="&foaf;"
    version="1.0">
    
  <xsl:output method="xml" indent="yes"/>
  
  <xsl:param name="baseUri"/>
  <xsl:param name="type"/>
  <xsl:variable name="resourceURL" select="vi:proxyIRI($baseUri)"/>
  <xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
  <xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>
  
  <xsl:template match="/">
    <rdf:RDF>
      <rdf:Description rdf:about="{$resourceURL}">
        <xsl:choose>
          <xsl:when test="normalize-space($type)='Person'">
            <xsl:apply-templates select="/results" mode="person"/>
          </xsl:when>
          <xsl:when test="$type='Organization'">
            <xsl:apply-templates select="/results" mode="organization"/>
          </xsl:when>
        </xsl:choose>
      </rdf:Description>
    </rdf:RDF>
  </xsl:template>
  
  <!-- Case where agent is a User -->
  <xsl:template match="results" mode="person">
    <rdf:type rdf:resource="&oplangel;User" />
    <xsl:apply-templates mode="person" />
  </xsl:template>
  
  <xsl:template match="name" mode="person">
    <oplangel:name><xsl:value-of select="." /></oplangel:name>
  </xsl:template>
  
  <xsl:template match="id" mode="person">
    <oplangel:id rdf:datatype="&xsd;integer"><xsl:value-of select="." /></oplangel:id>
  </xsl:template>
  
  <xsl:template match="follower_count" mode="person">
    <oplangel:followers rdf:datatype="&xsd;integer"><xsl:value-of select="." /></oplangel:followers>
  </xsl:template>

  <xsl:template match="angellist_url" mode="person">
    <oplangel:url rdf:resource="{./text()}" />
  </xsl:template>
  
  <xsl:template match="bio" mode="person">
    <oplangel:bio><xsl:value-of select="normalize-space(./text())" /></oplangel:bio>
  </xsl:template>

  <xsl:template match="image" mode="person">
    <oplangel:image rdf:resource="{./text()}" />
  </xsl:template>
  
  <xsl:template match="blog_url" mode="person">
    <oplbase:blog_url rdf:resource="{./text()}" />
  </xsl:template>
  
  <xsl:template match="twitter_url" mode="person">
    <opltw:public_profile_url rdf:resource="{./text()}" />
  </xsl:template>
  
  <xsl:template match="facebook_url" mode="person">
    <oplog:public_profile_url rdf:resource="{./text()}" />
  </xsl:template>

  <xsl:template match="linkedin_url" mode="person">
    <oplli:public_profile_url rdf:resource="{./text()}" />
  </xsl:template>
  
  <xsl:template match="locations" mode="person">
    <oplangel:has_location>
      <oplangel:Location rdf:about="{vi:proxyIRI($baseUri, '', concat('Location_', ./id))}">
        <xsl:apply-templates mode="location" />
        <rdf:type rdf:resource="&oplangel;Location" />
      </oplangel:Location>
    </oplangel:has_location>
  </xsl:template>

  <xsl:template match="locations" mode="organization">
    <oplangel:has_location>
      <oplangel:Location rdf:about="{vi:proxyIRI($baseUri, '', concat('Location_', ./id))}">
        <xsl:apply-templates mode="location" />
        <rdf:type rdf:resource="&oplangel;Location" />
      </oplangel:Location>
    </oplangel:has_location>
  </xsl:template>
  
  <xsl:template match="roles" mode="person">
    <oplangel:role><xsl:value-of select="name" /></oplangel:role>
  </xsl:template>
  
  <!-- Case where agent is a Startup -->
  
  <xsl:template match="results" mode="organization">
    <rdf:type rdf:resource="&oplangel;Startup" />
    <xsl:apply-templates mode="organization" />
  </xsl:template>
  
  <xsl:template match="name" mode="organization">
    <oplangel:name><xsl:value-of select="." /></oplangel:name>
  </xsl:template>
  
  <xsl:template match="id" mode="organization">
    <oplangel:id rdf:datatype="&xsd;integer"><xsl:value-of select="." /></oplangel:id>
  </xsl:template>
  
  <xsl:template match="follower_count" mode="organization">
    <oplangel:followers rdf:datatype="&xsd;integer"><xsl:value-of select="." /></oplangel:followers>
  </xsl:template>

  <xsl:template match="angellist_url" mode="organization">
    <oplangel:url rdf:resource="{./text()}" />
  </xsl:template>

  <xsl:template match="logo_url" mode="organization">
    <oplangel:logo_url rdf:resource="{./text()}" />
  </xsl:template>
  
  <xsl:template match="thumb_url" mode="organization">
    <oplangel:thumb_url rdf:resource="{./text()}" />
  </xsl:template>
  
  <xsl:template match="product_desc" mode="organization">
    <oplangel:product_desc><xsl:value-of select="." /></oplangel:product_desc>
  </xsl:template>
  
  <xsl:template match="high_concept" mode="organization">
    <oplangel:high_concept><xsl:value-of select="." /></oplangel:high_concept>
  </xsl:template>
  
  <xsl:template match="blog_url" mode="organization">
    <oplbase:blog_url rdf:resource="{./text()}" />
  </xsl:template>
  
  <xsl:template match="twitter_url" mode="organization">
    <opltw:public_profile_url rdf:resource="{./text()}" />
  </xsl:template>
  
  <xsl:template match="facebook_url" mode="organization">
    <oplog:public_profile_url rdf:resource="{./text()}" />
  </xsl:template>
  
  <xsl:template match="video_url" mode="organization">
    <oplangel:video_url rdf:resource="{./text()}" />
  </xsl:template>

  <xsl:template match="markets" mode="organization">
    <oplangel:has_market>
      <oplangel:Market rdf:about="{vi:proxyIRI($baseUri, '', concat('Market_', ./id))}">
        <xsl:apply-templates select="*" mode="market" />
      </oplangel:Market>
    </oplangel:has_market>
  </xsl:template>
  
  <xsl:template match="display_name|name" mode="market">
    <oplangel:market_name><xsl:value-of select="." /></oplangel:market_name>
    <rdfs:label><xsl:value-of select="." /></rdfs:label>
  </xsl:template>
  
  <xsl:template match="angellist_url" mode="market">
    <oplangel:market_url rdf:resource="{./text()}" />
  </xsl:template>
  
  <xsl:template match="id" mode="market">
    <oplangel:id rdf:datatype="&xsd;integer"><xsl:value-of select="." /></oplangel:id>
  </xsl:template>
  
  <xsl:template match="id" mode="location">
    <oplangel:location_id rdf:datatype="&xsd;integer"><xsl:value-of select="." /></oplangel:location_id>
  </xsl:template>
  
  <xsl:template match="name|display_name" mode="location">
    <oplangel:location_name><xsl:value-of select="." /></oplangel:location_name>
    <rdfs:label><xsl:value-of select="." /></rdfs:label>
  </xsl:template>
  
  <xsl:template match="angellist_url" mode="location">
    <oplangel:location_url rdf:resource="{./text()}" />
  </xsl:template>
  
  <xsl:template match="text()|@*"/>
  <xsl:template match="text()|@*" mode="person" />
  <xsl:template match="text()|@*" mode="organization" />
  <xsl:template match="text()|@*" mode="market" />
  <xsl:template match="text()|@*" mode="location" />
</xsl:stylesheet>

