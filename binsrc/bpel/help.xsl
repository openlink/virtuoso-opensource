<?xml version="1.0" encoding="ISO-8859-1" ?>
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
 -  
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     version="1.0"
     xmlns:v="http://www.openlinksw.com/vspx/"
     xmlns:xhtml="http://www.w3.org/1999/xhtml"
     xmlns:vm="http://www.openlinksw.com/vspx/macro">
<!--=========================================================================-->
<xsl:include href="common.xsl"/>
<!--=========================================================================-->
<xsl:variable name="pid" select="$id"/>
<xsl:variable name="nam" select="$name"/>
<!--=========================================================================-->
<xsl:template match="HelpTopic">
  <div>
  <xsl:call-template name="Title"/>
  <xsl:choose>
    <xsl:when test="sect1[@id=$pid]">
      <xsl:apply-templates select="sect1[@id=$pid]"/>
    </xsl:when>
    <xsl:otherwise><xsl:call-template name="topic-not-found"/></xsl:otherwise>
  </xsl:choose>
  </div>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="sect1">
  <xsl:choose>
    <xsl:when test="$nam != ''">
       <!-- for field name -->
       <table id="subcontent" width="100%" cellpadding="0" cellspacing="0" border="0">
         <tr>
           <td width="15%">&nbsp;</td>
           <td><H3><xsl:value-of select="title"/></H3></td>
         </tr>
         <tr>
           <td width="15%">&nbsp;</td>
           <td><xsl:apply-templates select="/HelpTopic/sect1/sect2/sect3[@id=$nam]" mode="nam"/></td>
         </tr>
       </table>
    </xsl:when>
    <xsl:otherwise>
       <!-- for the page all -->
       <table width="100%" id="subcontent" cellpadding="0" cellspacing="0" border="0">
         <tr>
           <td width="15%">&nbsp;</td>
           <td>
            <xsl:call-template name="sect1-all"/>
           </td>
         </tr>
         <tr>
           <td width="15%">&nbsp;</td>
           <td><xsl:apply-templates select="sect2"/></td>
         </tr>
       </table>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>
<!--=========================================================================-->
<xsl:template name="sect1-all">
   <table width="100%" id="subcontent" cellpadding="0" cellspacing="0" border="0">
     <tr>
      <td><H3><xsl:value-of select="title"/></H3>
          <xsl:apply-templates select="para|simplelist"/>
      </td>
     </tr>
   </table>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="sect2">
   <table width="100%" id="subcontent" cellpadding="0" cellspacing="0" border="0">
     <xsl:apply-templates select="sect3"/>
   </table>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="sect3">
  <tr>
    <td>
      <xsl:apply-templates select="title"/>
      <xsl:apply-templates select="para|simplelist"/>
    </td>
  </tr>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="simplelist">
  <br/><div><xsl:apply-templates/></div>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="member">
 <li><xsl:apply-templates select="ulink"/><xsl:value-of select="."/></li>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="ulink">
  <xsl:call-template name="make_img">
    <xsl:with-param name="src"      select="@url"/>
    <xsl:with-param name="height"   select="16"/>
    <xsl:with-param name="alt"      select="@alt"/>
  </xsl:call-template>&nbsp;
</xsl:template>
<!--=========================================================================-->
<xsl:template match="sect3" mode="nam">
  <table width="100%" id="subcontent" cellpadding="0" cellspacing="0" border="0">
    <tr>
      <td>
        <xsl:apply-templates/>
      </td>
    </tr>
  </table>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="title">
<b><xsl:value-of select="."/></b>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="para">
<br/><xsl:apply-templates/><br/>
</xsl:template>
<!--=========================================================================-->
<xsl:template name="topic-not-found">
<h3>Help Topic Not Found</h3>
</xsl:template>
<!--=========================================================================-->
<xsl:template name="Title">
<h1>OpenLink BPEL Process Manager Help</h1>
</xsl:template>
<!--=========================================================================-->
</xsl:stylesheet>
