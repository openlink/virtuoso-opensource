<?xml version="1.0"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2012 OpenLink Software
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
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="html"/>
<xsl:include href="navigations.xsl"/>
<xsl:template match="page">  

<html>
<head>
<xsl:call-template name = "css" />
</head>
<body>
 <xsl:apply-templates select = "nav_2"/>
 <xsl:call-template name = "nav_search" /> 
 <TABLE BGCOLOR="#E1F2FE" ALIGN="center" WIDTH="100%" CELLPADDING="0" CELLSPACING="0" BORDER="0">
 <TR>
  <TD COLSPAN="3"><IMG SRC="i/c.gif" HEIGHT="12" WIDTH="1" /></TD>
 </TR>
 <TR>
  <xsl:apply-templates select="search_result"/>
 </TR>
 <TR>
   <TD COLSPAN="3"><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD>
  </TR>
  <TR>
   <TD COLSPAN="3" BGCOLOR="#0073CC"><IMG SRC="i/c.gif" HEIGHT="1" WIDTH="1" /></TD>
  </TR>
</TABLE>
</body>
</html>
</xsl:template>

<!-- ==================================================================== -->
<xsl:template match="search_form">
<TABLE WIDTH="100%" BGCOLOR="#004C87" CELLPADDING="0" CELLSPACING="0" BORDER="0">
 <TR>
<form action="search.vsp" method="post">
   <TD WIDTH="20%" VALIGN="top"><IMG SRC="i/logo_n.gif" HEIGHT="49" WIDTH="197" BORDER="0"/></TD>
   <TD WIDTH="40%" ALIGN="center">
    <xsl:element name="input">
     <xsl:attribute name="type">text</xsl:attribute>
      <xsl:attribute name="name">q</xsl:attribute>
      <xsl:attribute name="size">36</xsl:attribute>
      <xsl:attribute name="value"><xsl:value-of select="/page/squery"/></xsl:attribute>
     </xsl:element></TD>
    <TD WIDTH="25%" ALIGN="center">
<xsl:apply-templates select="select"/>
<xsl:apply-templates select="hidden"/>
    </TD>
    <TD WIDTH="15%">
<input type="image" name="search" src="i/search.gif" border="0"/>
   </TD>
</form>
 </TR>
</TABLE>
</xsl:template>

<!-- ==================================================================== -->
<xsl:template match="select">
  <select>
    <xsl:attribute name="name"><xsl:value-of select="@name"/></xsl:attribute>
    <xsl:apply-templates select = "option" />
  </select> &#160;
</xsl:template>

<!-- ==================================================================== -->
<xsl:template match="option">
  <option>
  <xsl:attribute name="value"><xsl:value-of select="@value"/></xsl:attribute>
  <xsl:value-of select="."/>
  <xsl:choose>
  <xsl:when test="@selected=1">
    <xsl:attribute name="selected">selected</xsl:attribute></xsl:when>
  </xsl:choose>
  </option>
</xsl:template>

<!-- ==================================================================== -->
<xsl:template match="hidden">
  <xsl:apply-templates select="hidden_input"/>
</xsl:template>

<!-- ==================================================================== -->
<xsl:template match="hidden_input">
  <input type="hidden">
  <xsl:attribute name="name"><xsl:value-of select="@name"/></xsl:attribute>
  <xsl:attribute name="value"><xsl:value-of select="@value"/></xsl:attribute>
  </input>
</xsl:template>

<!-- ==================================================================== -->
<xsl:template match="search_result">
  <xsl:if test="/page/search_result/@hits!=0">
   <TR>
    <TD align="left" class="id" COLSPAN="3"> &#160;<xsl:value-of select="/page/search_result/@hits"/> hit(s) found</TD>
   </TR>
  </xsl:if>
  <TR BGCOLOR="#0073CC">
   <TD WIDTH="60%" HEIGHT="24" class="ie">&#160; message title</TD>
   <TD WIDTH="20%" class="ie">time</TD>
   <TD WIDTH="20%" class="ie">author</TD>
  </TR>
  <TR>
   <TD COLSPAN="3"><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD>
  </TR>
 <xsl:apply-templates/>
  <TR>
    <TD HEIGHT="18" colspan="3" BGCOLOR="#0073CC" class="id"> &#160;<xsl:apply-templates select="/page/navigation"/></TD>
  </TR>
</xsl:template>

<!-- ==================================================================== -->
<xsl:template match="search_err">
  <tr>
   <td valign="top">Error <xsl:value-of select="@msg"/></td>
  </tr>
</xsl:template>
  
<!-- ==================================================================== -->
<xsl:template match="no_hits">
  <TR>
   <TD align="left" class="id" COLSPAN="3"> &#160;No hits found</TD>
  </TR>
</xsl:template>

<!-- ==================================================================== -->
<xsl:template match="info">
 <TR BGCOLOR="#2C98EC">
  <td HEIGHT="20" class="id"> &#160;<xsl:value-of select="@pos"/>. 
  <a class="if"><xsl:attribute name="href"><xsl:value-of select="/page/url"/>?id=<xsl:value-of select="@msg_id"/>&amp;tid=<xsl:value-of select="@tid"/>&amp;fid=<xsl:value-of select="@fid"/>&amp;sid=<xsl:value-of select="/page/sid"/></xsl:attribute><xsl:value-of select="@msg_title"/></a><br/></td>
  <td class="id"><xsl:value-of select="@time"/></td>
  <td class="id"><xsl:value-of select="@nick"/></td>
  </TR>
  <TR>
   <TD COLSPAN="3"><IMG SRC="i/c.gif" HEIGHT="2" WIDTH="1" /></TD>
  </TR>
</xsl:template>

<!-- ==================================================================== -->
<xsl:template match="navigation">
  <xsl:apply-templates/>
</xsl:template>

<!-- ==================================================================== -->
<xsl:template match="nav">
  <xsl:choose>
  <xsl:when test="@iscurrent=1">
    <b><xsl:value-of select="@navpos"/></b>
  </xsl:when>
  <xsl:otherwise>
    <a class="inew"><xsl:attribute name="href"><xsl:value-of select="@ahref"/></xsl:attribute><xsl:value-of select="@navpos"/></a>
  </xsl:otherwise>
  </xsl:choose>
</xsl:template>
</xsl:stylesheet>
