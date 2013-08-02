<?xml version="1.0"?>
<!--
 -  
 -  $Id: sort.xsl,v 1.5.10.1 2013/01/02 16:16:13 source Exp $
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
  <!-- Identity transformation template -->
  <xsl:template><xsl:copy><xsl:apply-templates select="@* | * | comment() | processing-instruction() | text()"/></xsl:copy></xsl:template>
  
  <!-- Filter out stocks not listed on the nasdaq stock exchange -->
  <xsl:template match="stock[@exchange != 'nasdaq']" />

  <!-- Sort stocks by price -->
  <xsl:template match="portfolio"><xsl:copy><xsl:apply-templates select="@*"/><xsl:apply-templates select="stock"><xsl:sort select="price" data-type="number" /></xsl:apply-templates></xsl:copy></xsl:template>
</xsl:stylesheet>
