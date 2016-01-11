<?xml version="1.0"?>
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
 -
-->
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:dc="http://purl.org/metadata/dublin_core#"
  xmlns="http://purl.org/ocs/directory/0.5/#"
  xmlns:vi="http://www.openlinksw.com/weblog/"
  version="1.0">

  <xsl:output indent="yes" />

  <xsl:template match="/">
    <rdf:RDF>
      <xsl:apply-templates/>
    </rdf:RDF>
  </xsl:template>

  <xsl:template match="*">
    <xsl:choose>
      <xsl:when test="namespace-uri()=''">
	<xsl:element name="{name()}" namespace="http://purl.org/ocs/directory/0.5/#">
	  <xsl:apply-templates />
	</xsl:element>
      </xsl:when>
      <xsl:otherwise>
	<xsl:copy>
	  <xsl:apply-templates />
	</xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="opml">
    <directory rdf:about="{vi:getHttpUrl()}">
      <channels>
	<rdf:Bag>
	  <xsl:apply-templates select="body/outline"  mode="bag"/>
	</rdf:Bag>
      </channels>
    </directory>
    <xsl:apply-templates  select="body/outline"  mode="channel"/>
  </xsl:template>

  <xsl:template match="outline[@xmlUrl]" mode="bag">
    <rdf:li rdf:resource="{@xmlUrl}" />
</xsl:template>

  <xsl:template match="outline[@url]" mode="bag">
    <rdf:li rdf:resource="{@url}" />
  </xsl:template>

  <xsl:template match="body/outline[@xmlUrl and @htmlUrl]" mode="channel" >
    <channel rdf:about="{@htmlUrl}">
      <xsl:apply-templates select="@*"/>
      <formats>
	<rdf:Alt>
	  <rdf:li>
	    <rdf:Description rdf:about="{@xmlUrl}">
	    </rdf:Description>
	  </rdf:li>
	</rdf:Alt>
      </formats>
    </channel>
  </xsl:template>

  <xsl:template match="body/outline[@xmlUrl and not (@htmlUrl)]" mode="channel" >
    <channel rdf:about="{@xmlUrl}">
      <xsl:apply-templates select="@*"/>
      <formats>
	<rdf:Alt>
	  <rdf:li>
	    <rdf:Description rdf:about="{@xmlUrl}">
	    </rdf:Description>
	  </rdf:li>
	</rdf:Alt>
      </formats>
    </channel>
  </xsl:template>


  <xsl:template match="body/outline[@url]" mode="channel" >
    <channel rdf:about="{@url}">
      <xsl:apply-templates select="@*"/>
    </channel>
  </xsl:template>

  <xsl:template match="@title">
    <dc:title><xsl:value-of select="." /></dc:title>
  </xsl:template>

  <xsl:template match="@description">
    <dc:description><xsl:value-of select="." /></dc:description>
  </xsl:template>

</xsl:stylesheet>
