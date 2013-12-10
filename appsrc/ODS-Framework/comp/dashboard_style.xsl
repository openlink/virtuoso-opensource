<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2013 OpenLink Software
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
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     xmlns:v="http://www.openlinksw.com/vspx/"  exclude-result-prefixes="v"
     xmlns:xhtml="http://www.w3.org/1999/xhtml">
<xsl:output method="text" omit-xml-declaration="yes" indent="yes" encoding="utf-8"/>

<xsl:template match="/">
  <xsl:apply-templates />
</xsl:template>

<xsl:template match="dashboard">
  <xsl:if test="./dash-row">
  <table class="listing">
    <tr class="listing_header_row">
      <th>Class</th>
      <th>Timestamp</th>
      <th>Application</th>
      <th>Content</th>
    </tr>
    <xsl:for-each select="./dash-row">
      <xsl:sort select="@time" order="descending"/>
        <xsl:sort select="@class"/>
      <xsl:if test="position() <= $nrows">
        <xsl:if test=" (position() mod 2)= 0">
           <xsl:apply-templates select=".">
              <xsl:with-param name = "row_class" >listing_row_even</xsl:with-param>
           </xsl:apply-templates>
        </xsl:if>
        <xsl:if test=" (position() mod 2) > 0">
           <xsl:apply-templates select=".">
            <xsl:with-param name = "row_class" >listing_row_odd</xsl:with-param>
           </xsl:apply-templates>
        </xsl:if>
      </xsl:if>
    </xsl:for-each>
  </table>
  </xsl:if>
</xsl:template>

<xsl:template match="dash-row">
 <tr>
    <xsl:attribute name="class"><xsl:value-of select="$row_class"/></xsl:attribute>
    <td valign="top">
      <xsl:if test="@class = 'normal'">
        <img src="images/icons/about_16.png" border="0" alt="normal" title="normal"/>
      </xsl:if>
      <xsl:if test="not @class = 'normal'">
        <img src="images/icons/stop_16.png" border="0" alt="urgent" title="urgent">
          <xsl:attribute name="alt"><xsl:value-of select="@class"/></xsl:attribute>
          <xsl:attribute name="title"><xsl:value-of select="@class"/></xsl:attribute>
        </img>
      </xsl:if>
    </td>
    <td valign="top" nowrap="true">
      <xsl:value-of select="@time"/>
    </td>
    <td valign="top" nowrap="true">
      <xsl:if test="string-length(@application) < 23">
        <xsl:value-of select="@application"/>
      </xsl:if>
      <xsl:if test="string-length(@application) > 23">
        <xsl:value-of select="substring(@application, 1, 20)"/>...
      </xsl:if>
    </td>
    <td valign="top" width="100%">
      <xsl:value-of select="./dash-data/@content"/>
    </td>
  </tr>
</xsl:template>

<xsl:template match="@*|*">
  <xsl:copy>
    <xsl:apply-templates select="@*"/>
    <xsl:apply-templates/>
  </xsl:copy>
</xsl:template>

</xsl:stylesheet>

