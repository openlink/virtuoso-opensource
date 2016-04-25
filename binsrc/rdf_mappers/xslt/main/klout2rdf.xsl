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
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY oplklout "http://www.openlinksw.com/schemas/klout#">
<!ENTITY opltw "http://www.openlinksw.com/schemas/twitter#">
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
]>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:bibo="&bibo;" xmlns:sioc="&sioc;" xmlns:oplklout="&oplklout;" xmlns:opltw="&opltw;" xmlns:foaf="&foaf;" xmlns:owl="http://www.w3.org/2002/07/owl#" xmlns:xsd="&xsd;" version="1.0">

  <xsl:output method="xml" indent="yes"/>
  
  <xsl:param name="baseUri"/>
  <xsl:param name="mode"/>
  
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
      <rdf:Description rdf:about="{$resourceURL}">
        <rdf:type rdf:resource="&sioc;Container"/>
        <rdf:type rdf:resource="&oplklout;User"/>
        <xsl:apply-templates/>
      </rdf:Description>
    </rdf:RDF>
  </xsl:template>
  
  <xsl:template match="users">
    <xsl:apply-templates select="user"/>
  </xsl:template>
  
  <xsl:template match="user">
    <xsl:apply-templates/>
  </xsl:template>
  
  <xsl:template match="twitter_id">
    <opltw:id>
      <xsl:value-of select="."/>
    </opltw:id>
  </xsl:template>
  
  <xsl:template match="twitter_screen_name">
    <opltw:screen_name>
      <xsl:value-of select="."/>
    </opltw:screen_name>
    <rdfs:label>
      <xsl:value-of select="."/>
    </rdfs:label>
    <oplklout:twitterProfileURI rdf:resource="{vi:proxyIRI (concat('http://twitter.com/', .))}"/>
  </xsl:template>
  
  <xsl:template match="score">
    <xsl:apply-templates/>
  </xsl:template>
  
  <xsl:template match="kscore">
    <oplklout:has_klout rdf:datatype="&xsd;float">
      <xsl:value-of select="."/>
    </oplklout:has_klout>
  </xsl:template>
  
  <xsl:template match="slope">
    <oplklout:score_slope rdf:datatype="&xsd;float">
      <xsl:value-of select="."/>
    </oplklout:score_slope>
  </xsl:template>
  
  <xsl:template match="description">
    <oplklout:description>
      <xsl:value-of select="."/>
    </oplklout:description>
  </xsl:template>
  
  <xsl:template match="kclass">
    <oplklout:class>
      <xsl:value-of select="."/>
    </oplklout:class>
  </xsl:template>
  
  <xsl:template match="network_score">
    <oplklout:netscore rdf:datatype="&xsd;float">
      <xsl:value-of select="."/>
    </oplklout:netscore>
  </xsl:template>
  
  <xsl:template match="amplification">
    <oplklout:amplification rdf:datatype="&xsd;float">
      <xsl:value-of select="."/>
    </oplklout:amplification>
  </xsl:template>
  
  <xsl:template match="true_reach">
    <oplklout:true_reach rdf:datatype="&xsd;float">
      <xsl:value-of select="."/>
    </oplklout:true_reach>
  </xsl:template>
  
  <xsl:template match="delta_1day">
    <oplklout:delta1d rdf:datatype="&xsd;float">
      <xsl:value-of select="."/>
    </oplklout:delta1d>
  </xsl:template>
  
  <xsl:template match="delta_5day">
    <oplklout:delta5d rdf:datatype="&xsd;float">
      <xsl:value-of select="."/>
    </oplklout:delta5d>
  </xsl:template>
  
  <xsl:template match="topics">
    <xsl:apply-templates/>
  </xsl:template>
  
  <xsl:template match="topic">
    <oplklout:topic>
      <xsl:value-of select="."/>
    </oplklout:topic>
  </xsl:template>
  
  <xsl:template match="influencees">
    <xsl:apply-templates select="twitter_screen_name" mode="influencee"/>
  </xsl:template>
  
  <xsl:template match="twitter_screen_name" mode="influencee">
    <oplklout:influences>
      <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', .)}">
        <rdf:type rdf:resource="&oplklout;User"/>
        <rdfs:label>
          <xsl:value-of select="."/>
        </rdfs:label>
        <foaf:homepage rdf:resource="{vi:proxyIRI (concat('http://klout.com/', .))}"/>
      </rdf:Description>
    </oplklout:influences>
  </xsl:template>
  
  <xsl:template match="influencers">
    <xsl:apply-templates select="twitter_screen_name" mode="influenced_by"/>
  </xsl:template>
  
  <xsl:template match="twitter_screen_name" mode="influenced_by">
    <oplklout:influenced_by>
      <rdf:Description rdf:about="{vi:proxyIRI ($baseUri, '', .)}">
        <rdf:type rdf:resource="&oplklout;User"/>
        <rdfs:label>
          <xsl:value-of select="."/>
        </rdfs:label>
        <foaf:homepage rdf:resource="{vi:proxyIRI (concat('http://klout.com/', .))}"/>
      </rdf:Description>
    </oplklout:influenced_by>
  </xsl:template>
  
  <xsl:template match="*|text()"/>
  
  <xsl:template match="*|text()" mode="show"/>
  
  <xsl:template match="*|text()" mode="topics"/>
  
  <xsl:template match="*|text()" mode="influencers"/>
  
  <xsl:template match="*|text()" mode="influenced_by"/>
  
  <xsl:template match="*|text()" mode="influences"/>
  
  <xsl:template match="*|text()"/>
</xsl:stylesheet>

