<?xml version='1.0'?>
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
 -  
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     version="1.0"
     xmlns:v="http://www.openlinksw.com/vspx/"
     exclude-result-prefixes="v"
     xmlns:xhtml="http://www.w3.org/1999/xhtml">

<xsl:variable name="page_title" select="string (//v:style[@name='pagetitle'])" />

<xsl:template match="head/title[string(.)='']" priority="100">
  <title><xsl:value-of select="$page_title" /></title>
</xsl:template>

<xsl:template match="head/title">
  <title><xsl:value-of select="replace(string(.),'!page_title!',$page_title)" /></title>
</xsl:template>

<xsl:template match="v:style[@name='pagetitle']" />

<xsl:template match="v:style[@name='federalblue']//v:form">
  <v:style name="zigzag">
  <table cellspacing="0" cellpadding="0" border="1" bgcolor="#000000">
  <tr><td bgcolor="#CCCCFF">
    <v:form>
      <xsl:copy-of select="@*" />
      <xsl:apply-templates select="node()|processing-instruction()" />
    </v:form>
  </td></tr></table>
  </v:style>
</xsl:template>

<xsl:template match="v:style[@name='zigzag']//v:button">/\/\/\/\/\
    <xsl:copy>
      <xsl:copy-of select="@*" />
      <xsl:apply-templates select="node()|processing-instruction()" />
    </xsl:copy>/\/\/\/\/\
</xsl:template>

</xsl:stylesheet>
