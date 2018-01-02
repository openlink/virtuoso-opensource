<?xml version='1.0'?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2018 OpenLink Software
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
     version="1.0"
     xmlns:v="http://www.openlinksw.com/vspx/"  exclude-result-prefixes="v"
     xmlns:xhtml="http://www.w3.org/1999/xhtml">
<xsl:output method="xsl" omit-xml-declaration="no" indent="no" />

<xsl:template match="*">
  <xsl:variable name="scriptable" select="self::v:after-data-bind|self::v:after-data-bind-container|self::v:before-data-bind|self::v:before-data-bind-container|self::v:on-post|self::v:on-post-container|self::v:before-render|self::v:before-render-container|self::v:on-init|self::v:on-init-container|self::v:script|self::v:method|self::v:method-container"/>
  <xsl:copy>
    <xsl:for-each select="@*"><xsl:copy /></xsl:for-each>
    <xsl:if test="xpath-debug-srcline(.) > 0">
      <xsl:attribute name="debug-srcfile"><xsl:value-of select="xpath-debug-srcfile(.)" /></xsl:attribute>
      <xsl:attribute name="debug-srcline"><xsl:value-of select="xpath-debug-srcline(.)" /></xsl:attribute>
    </xsl:if>
  <xsl:if test="$scriptable">
#line push
#line <xsl:value-of select="xpath-debug-srcline(.)"/> "<xsl:value-of select="xpath-debug-srcfile(.)"/>"
</xsl:if>
  <xsl:apply-templates select="node()" />
  <xsl:if test="$scriptable">
#line pop
</xsl:if>
  </xsl:copy>
</xsl:template>

<xsl:template match="text()|comment()|processing-instruction()">
  <xsl:copy/>
</xsl:template>

</xsl:stylesheet>
