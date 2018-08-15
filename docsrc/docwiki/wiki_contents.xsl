<?xml version="1.0"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2018 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:virt="http://www.openlinksw.com/virtuoso/xslt">
<xsl:output method="text"/>
<!--========================================================================-->
<xsl:template match="/book">
<xsl:call-template name="contentspage"/>
</xsl:template>
<!--========================================================================-->
<xsl:template name="contentspage">
  <xsl:call-template name="titler" />
  <xsl:for-each select="/book/chapter">
    <xsl:value-of select="'\r\n'"/><xsl:text>---++++</xsl:text><xsl:value-of select="concat('[[', virt:WikiNameFromId(@id),']['  )"/>
    <xsl:value-of select="title" />
    <xsl:value-of select="']]\r\n'"/>
    <xsl:for-each select="sect1">
      <xsl:value-of select="'\r\n'"/><xsl:text>   * </xsl:text><xsl:value-of select="concat('[[', virt:WikiNameFromId(@id),']['  )"/>
      <xsl:value-of select="title" />
      <xsl:value-of select="']]\r\n'"/>
      <xsl:for-each select="sect2">
         <xsl:value-of select="'\r\n'"/><xsl:text>      * </xsl:text><xsl:value-of select="concat('[[',  virt:WikiNameFromId(../@id), '#', virt:WikiNameFromId(@id),  ']['  )"/>
         <xsl:value-of select="title" />
         <xsl:value-of select="']]\r\n'"/>
      </xsl:for-each>
    </xsl:for-each>
  </xsl:for-each>
</xsl:template>
<!--========================================================================-->
<xsl:template name="titler">
 <xsl:text>---++</xsl:text><xsl:value-of select="/book/title"/><xsl:text> - Contents</xsl:text>
 <xsl:value-of select="'\r\n\r\n'"/>
</xsl:template>
<!--========================================================================-->
</xsl:stylesheet>
