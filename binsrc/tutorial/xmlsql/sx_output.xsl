<?xml version="1.0"?>
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
 -  
-->
<xsl:stylesheet version = '1.0'
     xmlns:xsl='http://www.w3.org/1999/XSL/Transform'>

<xsl:output method="html"/>

<xsl:template match="/rows">
<table border="1">
  <xsl:for-each select="*">
    <tr><th>Result&#160;row&#160;<xsl:value-of select="position()" />&#160;of&#160;<xsl:value-of select="last()"/></th><td width="100%">
      <xsl:apply-templates select="." />
    </td></tr>
  </xsl:for-each>
</table>
</xsl:template>

<xsl:template match="/rows/row">
  <xsl:apply-templates select="node()" />
</xsl:template>

<xsl:template match="*">
  <xsl:text>&lt;</xsl:text>
     <xsl:value-of select="name()"/>
     <xsl:call-template name="attr"/>
  <xsl:if test="empty(node())">
    <xsl:text>/&gt;</xsl:text>
  </xsl:if>
  <xsl:if test="not(empty(node()))">
    <xsl:text>&gt;</xsl:text>
    <xsl:choose>
      <xsl:when test="*">
        <xsl:variable name="indent">
          <xsl:for-each select="ancestor::*[name() != 'rows'][name() != 'row']">&#160;&#160;&#160;&#160;</xsl:for-each>
        </xsl:variable>
        <xsl:for-each select="node()">
          <br/>&#160;&#160;&#160;&#160;<xsl:value-of select="$indent"/>
          <xsl:apply-templates select="." />
	</xsl:for-each>
        <br/><xsl:value-of select="$indent"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="node()" />
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>&lt;/</xsl:text>
       <xsl:value-of select="name()"/>
    <xsl:text>&gt;</xsl:text>
  </xsl:if>
</xsl:template>


<xsl:template name="attr">
  <xsl:for-each select="@*">
     <xsl:text> </xsl:text>
     <Font style="color:green"><xsl:value-of select="name()"/></Font>
     <xsl:text>="</xsl:text>
     <Font style="color:blue"><xsl:value-of select="."/></Font>
     <xsl:text>"</xsl:text>
  </xsl:for-each>
</xsl:template>


<xsl:template match="text()">
  <Font style="color:red"><nobr><xsl:value-of select="." /></nobr></Font>
</xsl:template>

<!--
<xsl:template name="elem">
          <xsl:text>&lt;</xsl:text>
            <xsl:value-of select="name()"/>
             <xsl:call-template name="attr"/>
          <xsl:text>&gt;</xsl:text>
          <xsl:for-each select="child::*">
            <xsl:call-template name="elem"/>
          </xsl:for-each>
</xsl:template>

<xsl:template name="attr">
               <xsl:text> id = </xsl:text>
               <xsl:value-of select="./@id"/>
               <xsl:for-each select="child::*">
                    <xsl:value-of select="./@id"/>
                    <xsl:text> </xsl:text>
               </xsl:for-each>
</xsl:template>
-->
</xsl:stylesheet>
