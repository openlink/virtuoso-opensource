<?xml version='1.0'?>
<!--
 -  
 -  $Id: portfolio-choose.xsl,v 1.3.10.1 2013/01/02 16:16:07 source Exp $
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
 -  
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl">
  <xsl:template match="/">
    <HTML>
      <BODY>
        <TABLE BORDER="2">
          <TR>
            <TD>Symbol</TD>
            <TD>Name</TD>
            <TD>Price</TD>
          </TR>
          <xsl:for-each select="portfolio/stock">
            <TR>
              <xsl:attribute name="STYLE">color:
                <xsl:choose>
                  <xsl:when test="price[. $le$ 25]">green</xsl:when>
                  <xsl:when test="price[. $le$ 50]">blue</xsl:when>
                  <xsl:otherwise>red</xsl:otherwise>
                </xsl:choose>
              </xsl:attribute>
              <TD>
                <xsl:value-of select="symbol"/>
                <xsl:if test="@exchange[.='nasdaq']">*</xsl:if>
              </TD>
              <TD><xsl:value-of select="name"/></TD>
              <TD><xsl:value-of select="price"/></TD>
            </TR>
          </xsl:for-each>
        </TABLE>
        <P>* Listed on Nasdaq stock exchange</P>
        <P>Price key: <SPAN STYLE="color:green">less than 25</SPAN>, 
            <SPAN STYLE="color:blue">25-50</SPAN>, 
            <SPAN STYLE="color:red">50+</SPAN>.</P>
      </BODY>
    </HTML>
  </xsl:template>
</xsl:stylesheet>
