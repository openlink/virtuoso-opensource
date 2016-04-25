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
<xsl:include href="common.xsl"/>
<!--=========================================================================-->
<xsl:template match="page">
  <table width="100%" border="0" cellpadding="0" cellspacing="0" id="content">
    <tr><th class="info" colspan="2">Details</th></tr>
    <xsl:apply-templates select="test"/>
  </table>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="test">
  <xsl:choose>
    <xsl:when test="@Client != ''">
      <tr>
        <td>
          <a class="m_e">
            <xsl:attribute name="target">'help-popup'</xsl:attribute>
            <xsl:attribute name="href"><xsl:value-of select="@Client"/></xsl:attribute>
            <xsl:value-of select="concat(@Name,' client')"/>
          </a>
        </td>
      </tr>
    </xsl:when>
  </xsl:choose>
  <tr>
    <td>
      <table width="100%" id="contentlist" cellpadding="0" cellspacing="0">
        <tr>
          <th>Interop process Test Name</th>
          <th>Process EndPoint URLs</th>
        </tr>
        <tr>
          <td>
            <b><xsl:value-of select="@Name"/></b>
          </td>
          <td>
            <table width="100%" border="1" cellpadding="0" cellspacing="0" id="contentlist">
              <tr>
                <th width="40%">EndPoint</th>
                <th>Info</th>
              </tr>
              <xsl:apply-templates select="source"/>
            </table>
          </td>
        </tr>
      </table>
    </td>
  </tr>
  <tr><td>&nbsp;</td></tr>
  <tr>
    <td>
      <table width="100%" id="contentlist" cellpadding="0" cellspacing="0">
        <tr>
          <th align="left">Info</th>
        </tr>
        <tr>
          <td><xsl:apply-templates select="refentry"/></td>
        </tr>
      </table>
    </td>
  </tr>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="source">
  <tr>
    <td>
      <a class="m_e">
        <xsl:attribute name="target">'help-popup'</xsl:attribute>
        <xsl:attribute name="href"><xsl:value-of select="@Url"/></xsl:attribute><xsl:value-of select="@Url"/>
      </a>
    </td>
    <td>
      <xsl:value-of select="@Info"/>
    </td>
  </tr>
</xsl:template>
<!--=========================================================================-->
</xsl:stylesheet>
