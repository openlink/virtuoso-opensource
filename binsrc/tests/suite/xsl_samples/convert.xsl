<?xml version="1.0"?>
<!--
 -  
 -  $Id: convert.xsl,v 1.4.10.1 2013/01/02 16:16:03 source Exp $
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2017 OpenLink Software
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
<?xml-stylesheet type="text/xsl" href="showxsl.xsl"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl">
  <xsl:template match="/">
    <xsl:pi name="xml">version="1.0"</xsl:pi>
    <xsl:pi name="xml-stylesheet">type="text/xsl" href="style.xsl"</xsl:pi>
    <xsl:comment>Style sheet converted automatically to &lt;xsl:element&gt; syntax</xsl:comment>
    <xsl:apply-templates select="comment()"/>
    <xsl:apply-templates select="*"/>
  </xsl:template>

  <!-- Copy text, comments and pis -->
  <xsl:template match="comment() | processing-instruction() | text()">
    <xsl:copy>
      <xsl:apply-templates />
    </xsl:copy>
  </xsl:template>

  <!-- Convert non-XSL elements to <xsl:element> syntax -->
  <xsl:template match="*">
    <xsl:element name="xsl:element">
      <xsl:attribute name="name"><xsl:node-name/></xsl:attribute>
      <xsl:apply-templates select="@*"/> <!-- consolidate -->
      <xsl:apply-templates select="node()"/>
    </xsl:element>
  </xsl:template>

  <!-- Convert non-XSL attribute to <xsl:attribute> syntax -->
  <xsl:template match="@*">
    <xsl:element name="xsl:attribute">
      <xsl:attribute name="name"><xsl:node-name/></xsl:attribute>
      <xsl:value-of/>
    </xsl:element>
  </xsl:template>

  <!-- Copy namespace attributes -->
  <xsl:template match="@xmlns:*">
    <xsl:copy><xsl:value-of/></xsl:copy>
  </xsl:template>

  <!-- Copy XSL elements and their attributes -->
  <xsl:template match="xsl:*">
    <xsl:copy>
      <xsl:for-each select="@*">
        <xsl:copy><xsl:value-of/></xsl:copy>
      </xsl:for-each>
      <xsl:apply-templates select="node()"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>
