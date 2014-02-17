<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2014 OpenLink Software
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
  method="xml"
  encoding="utf-8"  />

<xsl:template match="History">
  <rss version="2.0">
    <channel>
      <xsl:if test="@Title">
        <title><xsl:value-of select="@Title"/></title>
      </xsl:if>
      <xsl:if test="not @Title">
        <title><xsl:value-of select="@name"/>'s  Weblog</title>
      </xsl:if>
      <link><xsl:value-of select="@home"/></link>
      <description/>
      <managingEditor><xsl:value-of select="@username"/></managingEditor>
      <pubDate><xsl:value-of select="@date"/></pubDate>
      <generator>Virtuoso Universal Server 03.50.2727</generator>
      <webMaster><xsl:value-of select="@username"/></webMaster>
      <xsl:apply-templates select="Entry"/>
    </channel>
  </rss>
</xsl:template>

<xsl:template match="Entry">
  <item>
    <title><xsl:value-of select="@Title"/></title>
    <guid><xsl:value-of select="@Link"/></guid>
<!--    <link><xsl:value-of select="@Link"/></link> -->
<!--    <comments><xsl:value-of select="@Link"/></comments> -->
    <pubDate><xsl:value-of select="@Created"/></pubDate>
    <creator><xsl:value-of select="@Who"/></creator>
    <author><xsl:value-of select="@Who"/></author>
    <description>
      <xsl:copy-of select="*"/>
    </description>
  </item>
</xsl:template>

</xsl:stylesheet>
