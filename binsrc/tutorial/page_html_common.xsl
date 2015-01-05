<?xml version="1.0" encoding="utf-8"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2015 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:template match="para">
    <xsl:choose>
      <xsl:when test="local-name(parent::*) = 'listitem'">
        <xsl:apply-templates />
      </xsl:when>
      <xsl:otherwise>
        <p><xsl:apply-templates /></p>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ulink">
    <a>
      <xsl:attribute name="href"><xsl:value-of select="@url"/></xsl:attribute>
      <xsl:apply-templates/>
    </a>
  </xsl:template>

  <xsl:template match="image">
    <img>
      <xsl:attribute name="src"><xsl:value-of select="@url"/></xsl:attribute>
      <xsl:apply-templates/>
    </img>
  </xsl:template>

  <xsl:template match="programlisting">
    <pre><xsl:value-of select="." /></pre>
  </xsl:template>

  <xsl:template match="itemizedlist">
    <ul>
      <xsl:for-each select="./listitem">
        <li><xsl:apply-templates /></li>
      </xsl:for-each>
    </ul>
  </xsl:template>

  <xsl:template match="orderedlist">
    <ol>
      <xsl:for-each select="./listitem">
        <li><xsl:apply-templates /></li>
      </xsl:for-each>
    </ol>
  </xsl:template>

  <xsl:template match="table | tr | th | td">
    <xsl:element name="{local-name()}">
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="refentry/refsect1/title">
    <h4><xsl:value-of select="."/></h4>
  </xsl:template>

</xsl:stylesheet>
