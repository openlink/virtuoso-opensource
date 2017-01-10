<?xml version='1.0'?>
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
 -  
 -  
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:dcterms="http://purl.org/dc/terms/"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:content="http://purl.org/rss/1.0/modules/content/"
  xmlns:sioc="http://rdfs.org/sioc/ns#"
                version='1.0'>
<xsl:include href="html_plain.xsl"/>
<xsl:output method="xml" indent="yes" encoding="UTF-8"/>
<!-- ==================================================================== -->
<xsl:param name="imgroot">../images/</xsl:param>
<xsl:param name="chap">overview</xsl:param>
<xsl:param name="serveraddr">http://localhost:8890/doc/html</xsl:param>
<xsl:param name="thedate">not specified</xsl:param>
<!-- ==================================================================== -->
<xsl:template match="/" priority="10">
<?vsp http_header ('Content-Type: text/xml\r\n'); ?>
<rdf:RDF xmlns="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <xsl:attribute name="rdf" namespace="http://www.w3.org/1999/02/22-rdf-syntax-ns#"/>
  <xsl:attribute name="rdfs" namespace="http://www.w3.org/2000/01/rdf-schema#"/>
  <xsl:attribute name="dc" namespace="http://purl.org/dc/elements/1.1/"/>
  <xsl:attribute name="dcterms" namespace="http://purl.org/dc/terms/"/>
  <!-- <xsl:attribute name="content" namespace="http://purl.org/rss/1.0/modules/content/"/> -->
  <xsl:attribute name="foaf" namespace="http://xmlns.com/foaf/0.1/"/>
  <xsl:attribute name="sioc" namespace="http://rdfs.org/sioc/ns#"/>
<sioc:Space>
      <xsl:attribute name="rdf:about"><xsl:value-of select="$serveraddr"/></xsl:attribute>
  <dc:title><xsl:value-of select="/book/title"/></dc:title>
      <rdfs:seeAlso>
        <xsl:attribute name="rdf:resource"><xsl:value-of select="$serveraddr"/>/<xsl:value-of select="/book/@id" />.sioc.rdf</xsl:attribute>
      </rdfs:seeAlso>
  <sioc:space_of>
        <xsl:attribute name="rdf:resource"><xsl:value-of select="$serveraddr"/>/<xsl:value-of select="$chap" />.html</xsl:attribute>
  </sioc:space_of>
</sioc:Space>
<xsl:apply-templates select="/book/chapter[@id = $chap]"/>
</rdf:RDF>
</xsl:template>

<xsl:template match="chapter" priority="10">
  <sioc:Container>
    <xsl:attribute name="rdf:about"><xsl:value-of select="$serveraddr"/>/<xsl:value-of select="@id" />.html</xsl:attribute>
    <sioc:id><xsl:value-of select="title"/></sioc:id>
    <sioc:has_space>
      <xsl:attribute name="rdf:resource"><xsl:value-of select="$serveraddr"/></xsl:attribute>
    </sioc:has_space>
    <xsl:for-each select="sect1">
      <sioc:container_of>
        <xsl:attribute name="rdf:resource"><xsl:value-of select="$serveraddr"/>/<xsl:value-of select="@id" />.html</xsl:attribute>
      </sioc:container_of>
    </xsl:for-each>
    <rdf:type>Documentation</rdf:type>
  </sioc:Container>
  <xsl:apply-templates select="sect1" />
</xsl:template>

<xsl:template match="sect1" priority="10">
  <foaf:Document>
    <xsl:attribute name="rdf:about"><xsl:value-of select="$serveraddr"/>/<xsl:value-of select="@id" />.html</xsl:attribute>
    <sioc:has_container>
      <xsl:attribute name="rdf:resource"><xsl:value-of select="$serveraddr"/>/<xsl:value-of select="parent::chapter/@id" />.html</xsl:attribute>
    </sioc:has_container>
    <dc:title><xsl:value-of select="title"/></dc:title>
    <dcterms:created><xsl:value-of select="$thedate"/></dcterms:created>
    <rdfs:seeAlso>
      <xsl:attribute name="rdf:resource"><xsl:value-of select="$serveraddr"/>/<xsl:value-of select="@id" />.sioc.rdf</xsl:attribute>
    </rdfs:seeAlso>
  </foaf:Document>
</xsl:template>

<xsl:template match="*" priority="20" mode="strip">
  <xsl:apply-templates mode="strip" />
</xsl:template>

</xsl:stylesheet>
