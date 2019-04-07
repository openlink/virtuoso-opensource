<?xml version="1.0"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2019 OpenLink Software
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
    <TABLE STYLE="border:1px solid black">
      <TR  STYLE="font-size:12pt; font-family:Verdana; font-weight:bold; text-decoration:underline">
        <TD>Price</TD>
        <TD STYLE="background-color:lightgrey">Time</TD>
        <TD>Bidder</TD>
      </TR>
      <xsl:for-each select="AUCTIONBLOCK/ITEM/BIDS/BID"><xsl:sort select="BIDDER" order="descending" />
        <TR STYLE="font-family:Verdana; font-size:12pt; padding:0px 6px">
          <TD>$<xsl:value-of select="PRICE"/></TD>
          <TD STYLE="background-color:lightgrey"><xsl:value-of select="TIME"/></TD>
          <TD><xsl:value-of select="BIDDER"/></TD>
        </TR>
      </xsl:for-each>
    </TABLE>
  </xsl:template>
</xsl:stylesheet>
