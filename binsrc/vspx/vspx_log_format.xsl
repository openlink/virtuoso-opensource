<?xml version='1.0'?>
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
 -
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     version="1.0"
     xmlns:v="http://www.openlinksw.com/vspx/"  exclude-result-prefixes="v"
     xmlns:xhtml="http://www.w3.org/1999/xhtml"
     xmlns:vd="http://www.openlinksw.com/vspx/deps/"
     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      >
<xsl:output method="html" omit-xml-declaration="yes" indent="no" />

<xsl:template match="/">
<hr/>
<xmp><xsl:copy-of select="*/*"/></xmp>
<hr/>
<xmp><xsl:call-template name="group"><xsl:with-param name="lst1" select="*/*"/></xsl:call-template></xmp>
<hr/>
<xsl:variable name="grouped"><xsl:call-template name="group"><xsl:with-param name="lst1" select="*/*"/></xsl:call-template></xsl:variable>
<h3>That's how the page has been executed:</h3>
  <ul>
  <xsl:apply-templates select="$grouped" mode="render" />
  </ul>
</xsl:template>

<xsl:template match="*" mode="render">
  <li><b><xsl:value-of select="if(name()='begin-and-end','run',name())"/></b><xsl:text> </xsl:text><xsl:value-of select="@text"/> at <b><xsl:value-of select="@control-name"/></b>
  <xsl:if test="@instance-name"> (<xsl:value-of select="@instance-name"/>)</xsl:if>
<!--    <xsl:value-of select="@begin-id"/>-<xsl:value-of select="@id"/> -->
    <xsl:if test="ul"><ul><xsl:apply-templates select="ul/*" mode="render"/></ul></xsl:if>
  </li>
</xsl:template>

<xsl:template name="group">
  <xsl:variable name="lst"><xsl:copy-of select="$lst1"/></xsl:variable>
  <xsl:variable name="inners" select="$lst/*[following-sibling::*/@begin-id = preceding-sibling::*/@id]"/>
<!--  <outers><ul><xsl:copy-of select="$lst/*[not(@id = $inners/@id)]"/></ul></outers> -->
<!--  <inners><ul><xsl:copy-of select="$inners"/></ul></inners> -->
  <xsl:for-each select="$lst/*[not(@id = $inners/@id)]">
    <xsl:choose>
      <xsl:when test="@begin-id"></xsl:when>
      <xsl:otherwise>
        <xsl:variable name="pair-begin" select="."/>
        <xsl:variable name="pair-end" select="$pair-begin/following-sibling::*[@begin-id = $pair-begin/@id]"/>
        <xsl:choose>
          <xsl:when test="count($pair-end) = 1">
            <xsl:element name="{concat(name($pair-begin),'-and-',name($pair-end))}">
              <xsl:copy-of select="$pair-end/@*"/>
              <xsl:copy-of select="@*|node()"/>
              <xsl:copy-of select="$pair-end/node()"/>
              <ul>
                <xsl:call-template name="group"><xsl:with-param name="lst1" select="$pair-begin/following-sibling::*[@id &lt; $pair-end/@id]"/></xsl:call-template>
              </ul>
            </xsl:element>
          </xsl:when>
          <xsl:otherwise><xsl:copy-of select="."/></xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:for-each>
</xsl:template>

<xsl:template match="begin[following-sibling::*[1][self::end][@control-name=current()/@control-name][@text=current()/@text]]" mode="collapse">
  <run><xsl:copy-of select="@*|node()"/></run>
</xsl:template>

<xsl:template match="end[preceding-sibling::*[1][self::begin][@control-name=current()/@control-name][@text=current()/@text]]" mode="collapse">
</xsl:template>

<xsl:template match="begin[following-sibling::*[1][self::break][@control-name=current()/@control-name]]" mode="collapse">
</xsl:template>

<xsl:template match="break[preceding-sibling::*[1][self::begin][@control-name=current()/@control-name]]" mode="collapse">
  <run-break><xsl:copy-of select="@*|node()"/></run-break>
</xsl:template>

<xsl:template match="*" mode="collapse">
<xsl:copy><xsl:copy-of select="@*|node()"/></xsl:copy>
</xsl:template>


</xsl:stylesheet>
