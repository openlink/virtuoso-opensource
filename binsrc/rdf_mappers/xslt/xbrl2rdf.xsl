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
  xmlns:xsd="http://www.w3.org/2001/XMLSchema"
  xmlns:owl="http://www.w3.org/2002/07/owl#"
  xmlns:link="http://www.xbrl.org/2003/linkbase#"
  xmlns:xlink="http://www.w3.org/1999/xlink#"
  xmlns:xbrli="http://www.xbrl.org/2003/instance#"
  xmlns:mem="http://www.microsoft.com/xbrl/mem#"
  xmlns:usfr-mda="http://www.xbrl.org/us/fr/rpt/seccert/2005-02-28#"
  xmlns:usfr-ar="http://www.xbrl.org/us/fr/rpt/ar/2005-02-28#"
  xmlns:usfr-pte="http://www.xbrl.org/us/fr/common/pte/2005-02-28#"
  xmlns:ref="http://www.xbrl.org/2004/ref#"
  xmlns:usfr-mr="http://www.xbrl.org/us/fr/rpt/mr/2005-02-28#"
  xmlns:us-gaap-ci="http://www.xbrl.org/us/fr/gaap/ci/2005-02-28#"
  xmlns="http://www.openlinksw.com/schemas/xbrl/"
  xmlns:msft="http://www.microsoft.com/msft/xbrl/taxonomy/2005-02-28"
  version="1.0">
  
  <xsl:output method="xml" indent="yes"/>
  <xsl:param name="base" />
  <xsl:template match="/">
      <rdf:RDF>
	  	<xsl:apply-templates select="xbrl"/>
      </rdf:RDF>
  </xsl:template>
  <xsl:template match="xbrl">
      <xsl:apply-templates select="context"/>
      <xsl:apply-templates select="msft:*"/>
  </xsl:template>

  <xsl:template match="context">
    <xsl:variable name="id" select="concat($base, '#', @id)"/>
    <rdf:Description rdf:about="{$id}">
        <contextRef>
            <xsl:value-of select="@id"/>
        </contextRef>
        <xsl:apply-templates select="entity"/>
        <xsl:apply-templates select="period"/>
    </rdf:Description>
  </xsl:template>
  
  <xsl:template match="entity">
    <scheme>
        <xsl:apply-templates select="identifier"/>
    </scheme>
    <rdf:value>
        <xsl:value-of select="identifier" />
    </rdf:value>
  </xsl:template>
    
  <xsl:template match="identifier">
    <xsl:value-of select="@scheme" />
  </xsl:template>

  <xsl:template match="period">
    <period>
        <!--xsl:apply-templates select="instant"/-->
        <!--xsl:apply-templates select="startDate"/>
        <xsl:apply-templates select="endDate"/-->
    </period>
  </xsl:template>
  
  <xsl:template match="instant">
    <instant>
        <xsl:value-of select="."/>
    </instant>
  </xsl:template>

  <xsl:template match="startDate">
    <startDate>
        <xsl:value-of select="."/>
    </startDate>
  </xsl:template>

  <xsl:template match="endDate">
    <endDate>
        <xsl:value-of select="."/>
    </endDate>
  </xsl:template>

<xsl:template match="text()|@*">
  <xsl:value-of select="."/>
</xsl:template>

  <xsl:template match="msft:*|usfr-mda:*">
    <xsl:variable name="contextRef" select="@contextRef"/>
    <xsl:variable name="name1" select="local-name(.)"/>    
    <rdf:Description rdf:about="{$name1}">
        <contextRef>
            <xsl:value-of select="$contextRef"/>
        </contextRef>
        <rdf:value>
            <xsl:value-of select="."/>
        </rdf:value>
    </rdf:Description>
  </xsl:template>

  
</xsl:stylesheet>


