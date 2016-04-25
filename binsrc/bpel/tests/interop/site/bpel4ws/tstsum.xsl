<?xml version="1.0" encoding="ISO-8859-1" ?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<!--=========================================================================-->
<xsl:template match="page">
  <table width="100%" border="0" cellpadding="0" cellspacing="0" id="content">
    <xsl:call-template name="Interop"/>
  </table>
</xsl:template>
<!--=========================================================================-->
<xsl:template name="Interop">
  <tr><th class="info">Details</th></tr>
  <tr>
    <td>
      <a class="m_e" href="post.vspx"> Post test results</a>
    </td>
  </tr>
  <tr>
    <td>
      <table width="100%" border="0" cellpadding="0" cellspacing="0" id="contentlist">
        <tr>
          <th>Manufacturer</th>
          <th>Product</th>
          <th>Version</th>
          <th>No</th>
          <th>Interop Process Test</th>
          <th>Process Endpoint URL</th>
          <th>WSDL, XML and BPEL Documents</th>
          <th>Date Created</th>
          <th>Comments</th>
        </tr>
        <xsl:apply-templates select="results"/>
      </table>
    </td>
  </tr>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="results">
   <tr>
     <xsl:attribute name="bgcolor">#90a9f0</xsl:attribute>
     <td><xsl:value-of select="section/ProductInfo/manifactor/."/></td>
     <td><xsl:value-of select="section/ProductInfo/product/."/></td>
     <td><xsl:value-of select="section/ProductInfo/version/."/></td>
     <td colspan="6">&nbsp;</td>
   </tr>
   <xsl:apply-templates select="section"/>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="section">
  <xsl:apply-templates select="test"/>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="test">
  <tr class="info">
    <xsl:attribute name="bgcolor"><xsl:choose><xsl:when test="(position() mod 2) = 0">#efefef</xsl:when><xsl:otherwise>#fefefe</xsl:otherwise></xsl:choose></xsl:attribute>
    <td colspan="3">&nbsp;</td>
    <td align="center"><xsl:value-of select="position()"/>.</td>
    <td><xsl:value-of select="@id"/></td>
    <xsl:apply-templates select="endPoint"/>
    <xsl:apply-templates select="files"/>
    <xsl:apply-templates select="date"/>
    <xsl:apply-templates select="comments"/>
  </tr>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="endPoint">
  <td><xsl:apply-templates select="ulink"/></td>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="ulink">
  <a class="m_e">
   <xsl:attribute name="target">'help-popup'</xsl:attribute>
   <xsl:attribute name="href"><xsl:value-of select="@url"/></xsl:attribute>
   <xsl:value-of select="@url"/>
  </a>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="files">
  <td><xsl:apply-templates select="itemizedlist"/></td>
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
<xsl:template match="comments">
  <td><xsl:apply-templates select="para"/></td>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="date">
  <td><xsl:apply-templates select="para"/></td>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="para">
<P><xsl:apply-templates /></P>
</xsl:template>
<!--=========================================================================-->
</xsl:stylesheet>
