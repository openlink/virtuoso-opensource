<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2007 OpenLink Software
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
-->
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
  version="1.0">
  <xsl:output method="xml" indent="yes"/>
  <xsl:param name="base" />
  <xsl:template match="/">
      <xsl:apply-templates select="html/head"/>
  </xsl:template>
  <xsl:template match="html/head">
      <rdf:RDF>
	  <foaf:Document rdf:about="{$base}">
	      <xsl:apply-templates select="title|meta"/>
	      <xsl:apply-templates select="/html/body//img[@src]"/>
	  </foaf:Document>
      </rdf:RDF>
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
  <xsl:template match="img[@src like 'http://farm%.static.flickr.com/%/%\\_%.%']">
      <foaf:depiction>
	  <foaf:Image rdf:about="{@src}"/>
      </foaf:depiction>
  </xsl:template>
  <xsl:template match="*|text()"/>
</xsl:stylesheet>
