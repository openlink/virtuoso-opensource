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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl">

  <!-- <xsl:script><![CDATA[
    function formatPrice(price)
    {
      var l = price.length;
      if (l > 3)
        price = price.substr(0,l-3) + "," + price.substr(l-3)
      return "$" + price + ".";
    }

    function trimSeconds(time)
    {
      // This function trims the "seconds" off of a time string
      var i = 0;
      var start = 0;
      var end = 0;
      while (time.charAt(i) != ":")
        i++;
      i++;
      while (time.charAt(i) != ":")
        i++;
      start = i;
      while (time.charAt(i) != " ")
        i++;
      end = i;
      return time.substring(0,start) + time.substring(end, time.length);
    }
  ]]></xsl:script> -->

  <xsl:template match="/">
    <TABLE STYLE="border:1px solid black">
      <TR  STYLE="font-size:12pt; font-family:Verdana; font-weight:bold; text-decoration:underline">
        <TD>Bidder</TD>
        <TD>Price</TD>
        <TD>Time (<SPAN STYLE="color:teal">AM</SPAN>/PM)</TD>
      </TR>
      <xsl:for-each select="AUCTIONBLOCK/ITEM/BIDS/BID">
        <TR STYLE="font-family:Verdana; font-size:12pt; padding:0px 6px">
          <TD><xsl:value-of select="BIDDER"/></TD>
          <TD><xsl:apply-templates select="PRICE"/></TD>
          <TD>
            <xsl:attribute name="STYLE">color:<xsl:eval>this.selectSingleNode("TIME").text.indexOf("AM",0) &gt; 0 ? "teal" : "black"</xsl:eval></xsl:attribute>
            <xsl:apply-templates select="TIME"/>
          </TD>
        </TR>
      </xsl:for-each>
    </TABLE>
  </xsl:template>
  
  <xsl:template match="PRICE">
    <xsl:eval>formatPrice(this.text)</xsl:eval>
  </xsl:template>

  <xsl:template match="TIME">
    <xsl:eval>this.text</xsl:eval>
  </xsl:template>

</xsl:stylesheet>
