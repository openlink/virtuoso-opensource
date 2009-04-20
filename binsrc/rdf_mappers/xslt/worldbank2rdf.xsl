<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2009 OpenLink Software
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
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY xsd  "http://www.w3.org/2001/XMLSchema#">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY wb "http://www.worldbank.org/">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:xsd="&xsd;"
    xmlns:dc="&dc;"
    xmlns:wb="&wb;"
    >

  <xsl:output method="xml" indent="yes" />

  <xsl:param name="baseUri" />

  <xsl:template match="/">
    <xsl:apply-templates />
  </xsl:template>

  <xsl:template match="/rsp[@stat='ok']">
    <rdf:RDF>
      <xsl:if test="data/dataPoint">
        <!--
        <rdf:Description rdf:about="{vi:proxyIRI($baseUri)}">
	-->
        <rdf:Description rdf:about="{$baseUri}">
          <wb:country>
            <xsl:value-of select="data/dataPoint[1]/country"/>
          </wb:country>
          <wb:country_id>
            <xsl:value-of select="data/dataPoint[1]/country/@id"/>
          </wb:country_id>
          <xsl:apply-templates select="/rsp/data/dataPoint" mode="ok" />
        </rdf:Description>
      </xsl:if>
    </rdf:RDF>
  </xsl:template>

  <xsl:template match="dataPoint" mode="ok">
    <xsl:if test="string(./value)">
      <wb:hasDataPoint>
        <wb:DataPoint>
        <xsl:for-each select="*">
          <xsl:choose>
            <!-- We've already dealt with the country element -->
            <xsl:when test="local-name() = 'country'"/>
            <xsl:when test="local-name() = 'indicator'">
              <wb:indicator>
                <xsl:value-of select="."/>
              </wb:indicator>
              <wb:indicator_id>
                <xsl:value-of select="./@id"/>
              </wb:indicator_id>
            </xsl:when>
            <xsl:when test="local-name() = 'value'">
              <wb:indicator_value>
                <xsl:value-of select="."/>
              </wb:indicator_value>
            </xsl:when>
            <xsl:when test="local-name() = 'date'">
             <wb:date>
               <xsl:value-of select="."/>
             </wb:date>
            </xsl:when>
            <xsl:otherwise>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:for-each>
        </wb:DataPoint>
      </wb:hasDataPoint>
    </xsl:if>
  </xsl:template>

  <xsl:template match="text()|@*"/>

</xsl:stylesheet>
