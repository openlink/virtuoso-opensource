<?xml version="1.0" encoding="ISO-8859-1" ?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<!--=========================================================================-->
<xsl:template match="refentry">
    <table width="100%" border="0" cellpadding="0" cellspacing="0" id="contentlist">
        <tr>
    <!--<th><xsl:value-of select="refentry/@id"/></th>-->
    </tr>
    <xsl:for-each select="refentry/refsect1"><tr><td>
          <xsl:apply-templates select="."/></td></tr>
    </xsl:for-each>
    </table>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="refentry" mode="protoclos">
    <table width="100%" border="0" cellpadding="0" cellspacing="0" id="contentlist">
      <tr>
        <th>No</th>
        <th>Protocol</th>
      </tr>
    <xsl:for-each select="refentry/refsect1">
      <tr>
      <xsl:choose>
        <xsl:when test="(position() mod 2) = 0">
           <xsl:attribute name="bgcolor">#fefefe</xsl:attribute>
        </xsl:when>
        <xsl:otherwise>
           <xsl:attribute name="bgcolor">#efefef</xsl:attribute>
        </xsl:otherwise>
      </xsl:choose>
        <td><xsl:value-of select="position()"/>.</td>
        <td><xsl:apply-templates select="."/></td>
      </tr>
    </xsl:for-each>
    </table>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="para">
<P><xsl:apply-templates /></P>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="ulink">
  <a class="m_e">
    <xsl:attribute name="target">'help-popup'</xsl:attribute>
    <xsl:attribute name="href"><xsl:value-of select="@url"/></xsl:attribute>
    <xsl:apply-templates/>
  </a>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="image">
  <img>
    <xsl:attribute name="src"><xsl:value-of select="@url"/></xsl:attribute>
    <xsl:apply-templates/>
  </img>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="programlisting">
<pre style="width:100px"><font class="m_t"><xsl:value-of select="." /></font></pre>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="itemizedlist">
<ul>
  <xsl:for-each select="./listitem">
  <LI><xsl:apply-templates /></LI>
  </xsl:for-each>
</ul>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="orderedlist">
<ol>
  <xsl:for-each select="./listitem">
  <LI><xsl:apply-templates /></LI>
  </xsl:for-each>
</ol>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="refentry/refsect1/title">
<font class="m_t"><b><xsl:value-of select="."/></b></font>
</xsl:template>
<!--=========================================================================-->
</xsl:stylesheet>
