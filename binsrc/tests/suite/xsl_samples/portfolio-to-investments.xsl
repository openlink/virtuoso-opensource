<?xml version="1.0"?>
<!--
 -  
 -  $Id: portfolio-to-investments.xsl,v 1.3.10.1 2013/01/02 16:16:08 source Exp $
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl">
  <xsl:template match="/">
    <investments>
      <xsl:for-each select="portfolio/stock">
        <item type="stock">
          <xsl:attribute name="exch"><xsl:value-of select="@exchange"/></xsl:attribute>
          <xsl:attribute name="symbol"><xsl:value-of select="symbol"/></xsl:attribute>
          <xsl:attribute name="company"><xsl:value-of select="name"/></xsl:attribute>
          <xsl:attribute name="price"><xsl:value-of select="price"/></xsl:attribute>
        </item>
      </xsl:for-each>
    </investments>
  </xsl:template>
</xsl:stylesheet>
