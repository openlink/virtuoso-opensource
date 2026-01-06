<?xml version="1.0"?>
<!--
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2026 OpenLink Software
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
  xmlns:ods="http://www.openlinksw.com/ods/"
  xmlns:atom="http://www.w3.org/2005/Atom"
  version="1.0">

  <xsl:output indent="yes" encoding="UTF-8" />

  <xsl:template match="PATH">
    <xsl:variable name="host"><xsl:value-of select="@dir_host" /></xsl:variable>
    <xsl:variable name="path"><xsl:value-of select="@dir_name" /></xsl:variable>
    <rss version="2.0">
      <channel>
        <title>
          <xsl:choose>
            <xsl:when test="@title"><xsl:value-of select="@title"/></xsl:when>
            <xsl:otherwise>Directory Listing of <xsl:value-of select="$path" /></xsl:otherwise>
          </xsl:choose>
        </title>
        <description>
          <xsl:choose>
            <xsl:when test="@title"><xsl:value-of select="@title"/></xsl:when>
            <xsl:otherwise>Directory Listing of <xsl:value-of select="$path" /></xsl:otherwise>
          </xsl:choose>
        </description>
        <link><xsl:value-of select="$host" /><xsl:value-of select="$path" /></link>
        <atom:link rel="self" href="{$host}{$path}?a=rss" type="application/rss+xml"/>
        <xsl:apply-templates select="DIRS">
          <xsl:with-param name="f_host" select="$host" />
          <xsl:with-param name="f_path" select="$path" />
        </xsl:apply-templates>

        <xsl:apply-templates select="FILES">
          <xsl:with-param name="f_host" select="$host" />
          <xsl:with-param name="f_path" select="$path" />
        </xsl:apply-templates>
      </channel>
    </rss>
  </xsl:template>

  <xsl:template match="SUBDIR[not(starts-with(@name, '.'))]">
    <xsl:param name="f_host" />
    <xsl:param name="f_path" />
    <xsl:if test="@name != '..'">
      <item>
        <title><xsl:call-template name="item-title" /></title>
        <link><xsl:value-of select="$f_host" /><xsl:value-of select="$f_path" /><xsl:value-of select="@name" />/</link>
        <guid><xsl:value-of select="$f_host" /><xsl:value-of select="$f_path" /><xsl:value-of select="@name" />/</guid>
        <pubDate><xsl:value-of select="@pubDate" /></pubDate>
        <ods:modified><xsl:value-of select="@modify" /></ods:modified>
        <category>collection</category>
      </item>
    </xsl:if>
  </xsl:template>

  <xsl:template match="FILE[not(starts-with(@name, '.'))]">
    <xsl:param name="f_host" />
    <xsl:param name="f_path" />
    <item>
      <title><xsl:call-template name="item-title" /></title>
      <link><xsl:value-of select="$f_host" /><xsl:value-of select="$f_path" /><xsl:value-of select="@name" /></link>
      <guid><xsl:value-of select="$f_host" /><xsl:value-of select="$f_path" /><xsl:value-of select="@name" /></guid>
      <pubDate><xsl:value-of select="@pubDate" /></pubDate>
      <ods:modified><xsl:value-of select="@modify" /></ods:modified>
      <category>resource</category>
    </item>
  </xsl:template>

  <xsl:template name="item-title">
    <xsl:choose>
      <xsl:when test="@title"><xsl:value-of select="@title"/></xsl:when>
      <xsl:otherwise><xsl:value-of select="@name"/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
