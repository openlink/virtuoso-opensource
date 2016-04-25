<?xml version="1.0"?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl">
  <xsl:template match="/">
    <HTML>
      <HEAD>
        <TITLE><xsl:value-of select="document/title"/></TITLE>
      </HEAD>
      <BODY>
        <H1><xsl:value-of select="document/title"/></H1>

        <DIV STYLE="border:1px solid black; padding:.5em; font-size:smaller">
          <H4>Table of Contents</H4>
          <xsl:for-each select="document/section">
            <DIV STYLE="margin-left:1em">
              <A>
                <xsl:attribute name="HREF">#<xsl:eval>uniqueID(this)</xsl:eval></xsl:attribute>
                Chapter <xsl:eval>formatIndex(childNumber(this), "1")</xsl:eval>.
                <xsl:value-of select="title"/>
              </A>
            </DIV>
          </xsl:for-each>
        </DIV>
        
        <xsl:apply-templates select="document/section"/>
      </BODY>
    </HTML>
  </xsl:template>

  <xsl:template match="section">
    <DIV>
      <H2>
        <A>
          <xsl:attribute name="NAME"><xsl:eval>uniqueID(this)</xsl:eval></xsl:attribute>
          Chapter <xsl:eval>formatIndex(childNumber(this), "1")</xsl:eval>.
          <xsl:value-of select="title"/>
        </A>
      </H2>
      <xsl:apply-templates />
    </DIV>
  </xsl:template>

  <xsl:template match="section/section">
    <DIV>
      <H3><xsl:value-of select="title"/></H3>
      <xsl:apply-templates />
    </DIV>
  </xsl:template>

  <xsl:template match="p">
    <P><xsl:apply-templates /></P>
  </xsl:template>

  <xsl:template match="list">
    <UL>
      <xsl:for-each select="item">
        <LI><xsl:apply-templates /></LI>
      </xsl:for-each>
    </UL>
  </xsl:template>

  <xsl:template match="emph">
    <I><xsl:apply-templates /></I>
  </xsl:template>  

  <xsl:template match="text()"><xsl:value-of /></xsl:template>
  
</xsl:stylesheet>
