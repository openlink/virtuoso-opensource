<?xml version="1.0"?>
<!--
 -  
 -  $Id$
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
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" indent="yes"/>

  <xsl:template match="/">
    <DIV STYLE="font-family:Courier; font-size:14pt; margin-bottom:2em">
                 <xsl:apply-templates select="*"/>
    </DIV>
  </xsl:template>


    <xsl:template match="*">
          <DIV STYLE="margin-left:1em; color:blue">
              <xsl:text>&lt;</xsl:text>
          <SPAN STYLE="color:brown">
        <xsl:value-of select="name()"/>
          </SPAN>
              <xsl:text> </xsl:text>
              <xsl:for-each select="@*">
                <xsl:text> </xsl:text>
          <SPAN STYLE="color:navy">
    <xsl:value-of select="name()"/>
          </SPAN>
    <xsl:text>="</xsl:text>
          <SPAN STYLE="color:black">
    <xsl:value-of select="."/>
          </SPAN>
    <xsl:text>" </xsl:text>
              </xsl:for-each>
              <xsl:text>&gt;</xsl:text>
          <SPAN STYLE="color:black;font-weight:bold">
        <xsl:value-of select="text()"/>
          </SPAN>
           <xsl:apply-templates select="*"/>
              <xsl:text>&lt;/</xsl:text>
          <SPAN STYLE="color:brown">
        <xsl:value-of select="name()"/>
          </SPAN>
        <xsl:text>&gt;</xsl:text>
          </DIV>
    </xsl:template>

</xsl:stylesheet>
