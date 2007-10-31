<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2006 OpenLink Software
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
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:skos="http://www.w3.org/2004/02/skos/core#"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
  xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
  xmlns:wf="http://www.w3.org/2005/01/wf/flow#"
  xmlns:dcterms="http://purl.org/dc/terms/"
  version="1.0">
  <xsl:output method="xml" indent="yes"/>
  <xsl:param name="base" />
  <xsl:template match="/">
      <rdf:RDF>
	  	<xsl:apply-templates select="bugzilla/bug"/>
      </rdf:RDF>
  </xsl:template>
  <xsl:template match="bugzilla/bug">
      <foaf:Document rdf:about="{$base}">
      <xsl:apply-templates select="bug_id"/>
	  <xsl:apply-templates select="reporter"/>
	  <xsl:apply-templates select="short_desc"/>
	  <xsl:apply-templates select="long_desc"/>
	  <xsl:apply-templates select="creation_ts"/>	  
      </foaf:Document>
  </xsl:template>
  <xsl:template match="bug_id">
      <dc:title>
	  <xsl:value-of select="."/>
      </dc:title>
  </xsl:template>  
  <xsl:template match="short_desc">
      <dc:subject>
	  <xsl:value-of select="."/>
      </dc:subject>
  </xsl:template>
  <xsl:template match="long_desc">
      <dc:description>
	  <xsl:value-of select="thetext"/>
      </dc:description>
  </xsl:template>
  <xsl:template match="reporter">
      <dc:creator>
	  <xsl:value-of select="."/>
      </dc:creator>
  </xsl:template>
  <xsl:template match="creation_ts">
      <dcterms:issued>
	  <xsl:value-of select="."/>
      </dcterms:issued>
  </xsl:template>
  <xsl:template match="delta_ts">
      <dcterms:modified>
	  <xsl:value-of select="."/>
      </dcterms:modified>
  </xsl:template>
  <xsl:template match="*|text()"/>
</xsl:stylesheet>
