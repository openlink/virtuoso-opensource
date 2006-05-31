<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2006 OpenLink Software
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
                xmlns:xhtml="http://www.w3.org/TR/xhtml1/strict"
                xmlns:wv="http://www.openlinksw.com/Virtuoso/WikiV/" >
<xsl:output
   method="html"
   encoding="utf-8"
/>

<xsl:template match="ChangeLog">
  <table class="wikitable">
    <tr><td>Change Log</td></tr>
    <tr><td>
    <table class="wikitable1">
      <th align="left">Topic</th>
      <th align="left">Action</th>
      <th align="left">Date</th>
      <th align="left">Changed By</th>
      <xsl:apply-templates select="Entry">
        <xsl:sort select="@date" order="descending"/>
      </xsl:apply-templates>
    </table>
  </td></tr></table>
</xsl:template>

<xsl:template match="Entry">
  <tr>
    <td>
       <a>
         <xsl:attribute name="href"><xsl:value-of select="@topicname"/></xsl:attribute>
         <xsl:attribute name="style">wikiword</xsl:attribute>
         <xsl:value-of select="@topicname"/>
       </a>		     
    </td>
    <td><xsl:value-of select="@action"/></td>
    <td><xsl:value-of select="@date"/></td>
    <td>
      <xsl:if test="@who != ''">
       <a>
         <xsl:attribute name="href"><xsl:value-of select="@who"/></xsl:attribute>
         <xsl:attribute name="style">wikiword</xsl:attribute>
         <xsl:value-of select="@who"/>
       </a>		     
     </xsl:if>
    </td>
  </tr>
</xsl:template>

</xsl:stylesheet>
