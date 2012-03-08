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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     version="1.0"
     xmlns:v="http://www.openlinksw.com/vspx/"
     xmlns:xhtml="http://www.w3.org/1999/xhtml"
     xmlns:vm="http://www.openlinksw.com/vspx/macro">

<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>

<xsl:variable name="page_title" select="string (//vm:pagetitle)" />

<xsl:template match="head/title[string(.)='']" priority="100">
  <title><xsl:value-of select="$page_title" /></title>
</xsl:template>

<xsl:template match="head/title">
  <title><xsl:value-of select="replace(string(.),'!page_title!',$page_title)" /></title>
</xsl:template>

<xsl:template match="vm:pagetitle" />

<xsl:template match="vm:pagewrapper">
  <xsl:element name="v:variable">
    <xsl:attribute name="persist">0</xsl:attribute>
    <xsl:attribute name="name">page_owner</xsl:attribute>
    <xsl:attribute name="type">varchar</xsl:attribute>
    <xsl:choose>
     <xsl:when  test="../@vm:owner">
       <xsl:attribute name="default">'<xsl:value-of select="../@vm:owner"/>'</xsl:attribute>
     </xsl:when>
     <xsl:otherwise>
       <xsl:attribute name="default">null</xsl:attribute>
     </xsl:otherwise>
    </xsl:choose>
  </xsl:element>
  <xsl:for-each select="//v:variable">
    <xsl:copy-of select="."/>
  </xsl:for-each>
  <div class="page_head">
    <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="page_head">
      <tr>
        <td><img src="i/bpelheader350.jpg" alt="" name="" width="350" height="75"/></td>
        <td nowrap="1">
          <v:include url="bpel_login_new.vspx"/>
        </td>
      </tr>
    </table>
  </div>
  <table id="MT" width="100%">
    <tbody>
      <tr>
        <td id="RT" width="90%" valign="top">
          <table width="100%">
            <tr class="main_page_area">
              <td>
                <xsl:apply-templates select="vm:pagebody"/>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </tbody>
  </table>
  <div class="copyright">Copyright &amp;copy; 1998-<?V "LEFT" (datestring (now()), 4)?> OpenLink Software</div>
</xsl:template>

<xsl:template match="vm:pagebody">
  <xsl:apply-templates/>
</xsl:template>

</xsl:stylesheet>
