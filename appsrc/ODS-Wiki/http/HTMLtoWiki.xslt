<?xml version="1.0"?>
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
 -
-->
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xhtml="http://www.w3.org/TR/xhtml1/strict"
  xmlns:wv="http://www.openlinksw.com/Virtuoso/WikiV/"
  xmlns:fn2="http://www.w3.org/2004/07/xpath-functions">
<xsl:output
  method="txt"
  encoding="UTF-8"
  />

<xsl:template match="html">
  <xsl:apply-templates select="body"/>
</xsl:template>

<xsl:template match="head">  
</xsl:template>

<xsl:template match="body">
<xsl:apply-templates select="node()"/>
</xsl:template>

<xsl:template match="table[@class='wikitable']">
  <xsl:apply-templates select="tr|tbody">
    <xsl:with-param name="wiki-output">1</xsl:with-param>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="tbody">
  <xsl:param name="wiki-output"/>
  <xsl:apply-templates select="tr">
    <xsl:with-param name="wiki-output"><xsl:value-of select="$wiki-output"/></xsl:with-param>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="tr">
  <xsl:param name="wiki-output"/>
  <xsl:choose>
    <xsl:when test="$wiki-output"><xsl:apply-templates select="td|th"><xsl:with-param name="wiki-output">1</xsl:with-param></xsl:apply-templates><xsl:text>
</xsl:text></xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="copy"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="td[@colspan]">
  <xsl:param name="wiki-output"/>
  <xsl:choose>
    <xsl:when test="$wiki-output">|<xsl:apply-templates select="node()"/><xsl:call-template name="colspan"><xsl:with-param name="colspan"><xsl:value-of select="@colspan"/></xsl:with-param></xsl:call-template><xsl:if test="position()=last()">|</xsl:if>
  </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="copy"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="td">
  <xsl:param name="wiki-output"/>
  <xsl:choose><xsl:when test="$wiki-output">|<xsl:apply-templates select="node()"/><xsl:if test="position()=last()">|</xsl:if>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="copy"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>


<xsl:template match="th[@colspan]">
  <xsl:param name="wiki-output"/>
  <xsl:choose><xsl:when test="$wiki-output">|*<xsl:apply-templates select="node()"/>*<xsl:call-template name="colspan"><xsl:with-param name="colspan"><xsl:value-of select="@colspan"/></xsl:with-param></xsl:call-template><xsl:if test="position()=last()">|</xsl:if>     
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="copy"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="th">
  <xsl:param name="wiki-output"/>
  <xsl:choose><xsl:when test="$wiki-output">|*<xsl:apply-templates select="node()"/>*<xsl:if test="position()=last()">|</xsl:if>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="copy"/>      
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>


<xsl:template name="colspan">
  <xsl:param name="colspan"/>
  <xsl:choose>
    <xsl:when test="$colspan > 1">
      <xsl:text>|</xsl:text>
      <xsl:call-template name="colspan">
        <xsl:with-param name="colspan"><xsl:value-of select="$colspan - 1"/></xsl:with-param>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="h1">
  <xsl:text>---+</xsl:text><xsl:copy-of select="node()"/><xsl:text>
</xsl:text>
</xsl:template>

<xsl:template match="h2">
  <xsl:text>---++</xsl:text><xsl:copy-of select="*"/><xsl:text>
</xsl:text>
</xsl:template>

<xsl:template match="h3">
  <xsl:text>---+++</xsl:text><xsl:copy-of select="*"/><xsl:text>
</xsl:text>
</xsl:template>


<xsl:template match="node()">
  <xsl:copy>
    <xsl:copy-of select="@*" />
    <xsl:apply-templates select="node()" />
  </xsl:copy>
</xsl:template>

<xsl:template name="copy">
  <xsl:copy>
    <xsl:copy-of select="@*" />
    <xsl:apply-templates select="node()" />
  </xsl:copy>
</xsl:template>

</xsl:stylesheet>
