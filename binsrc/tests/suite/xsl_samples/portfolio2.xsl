<?xml version="1.0"?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl">
  <xsl:template match="/">
    <HTML>
      <BODY>
        <xsl:for-each select="portfolio/stock">
          <DIV STYLE="font-size:smaller">Symbol: <xsl:value-of select="symbol"/>,
            Company: <xsl:value-of select="name"/>,
            Price: $<xsl:value-of select="price"/>
          </DIV>
          <DIV>
            <!-- select the children of the logo element -->
            <xsl:apply-templates select="logo/*">
              <!-- recursively apply this template to them -->
<!-- OBSOLETE
              <xsl:template>
                <xsl:copy>
                  <xsl:apply-templates select="@* | * | comment() | processing-instruction() | text()"/>
                </xsl:copy>
              </xsl:template>
-->	      
            </xsl:apply-templates>
          </DIV>
          <HR/>
        </xsl:for-each>
      </BODY>
    </HTML>
  </xsl:template>
</xsl:stylesheet>
