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
  <feed xmlns="http://purl.org/atom/ns#" version="0.3" xml:lang="en-us">
    <xsl:attribute name="base"><xsl:value-of select="@base"/></xsl:attribute>
    <xsl:if test="@Title">
      <title><xsl:value-of select="@Title"/></title>
    </xsl:if>
    <xsl:if test="not @Title">
     <title >oWiki <xsl:value-of select="@cluster"/> Weblog</title>
    </xsl:if>
    <link  rel="alternate"><xsl:value-of select="@home"/></link>
    <copyright >Copyright (c) 1998-2014 OpenLink Software</copyright>
    <author >
      <name><xsl:value-of select="@name"/></name>
      <email><xsl:value-of select="@email"/></email>
    </author> 
    <xsl:apply-templates select="Entry"/>
  </feed>  
</xsl:template>

<xsl:template match="Entry">
  <entry xmlns="http://purl.org/atom/ns#" id="{@Id}">
    <title><xsl:value-of select="@Title"/></title>
    <link><xsl:value-of select="@Link"/></link>
    <created><xsl:value-of select="@Created"/></created>
    <issued><xsl:value-of select="@Issued"/></issued>
    <modified><xsl:value-of select="@Modified"/></modified>
    <content type="text/html" mode="escaped" xml:lang="en-us">
        <xsl:copy-of select="*"/>
    </content> 
  </entry>
</xsl:template>

</xsl:stylesheet>
