<?xml version="1.0"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2017 OpenLink Software
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
    <DIV STYLE="font-family:Arial; font-size:12pt">
      <xsl:for-each select = "AUCTIONBLOCK/ITEM" >
        <DIV STYLE="font-weight:bold; font-size:14pt">
          <xsl:value-of select = "TITLE" />
          <SPAN STYLE="font-weight:normal"> by </SPAN>
          <xsl:value-of select = "ARTIST" />
        </DIV>
        <xsl:for-each select ="BIDS" >
          <DIV STYLE = "margin-top:4px">
            <xsl:for-each select = "BID" >
              <DIV>
                <xsl:attribute name = "STYLE">position:relative; height:1em; background-color:#FF8800; text-align:right; margin-top:2px;
                  width:<xsl:for-each select = "PRICE[0]"><xsl:eval>calcBidWidth(this)</xsl:eval>%</xsl:for-each>
                </xsl:attribute>
                <SPAN STYLE="font-weight:bold">$<xsl:value-of select = "PRICE" /></SPAN>
                <DIV>
                  <xsl:attribute name = "STYLE">
                    margin-left:4px; position:absolute; top:0px;
                    left:<xsl:eval>(50 > width ? 105 : 0)</xsl:eval>%;
                    width:<xsl:eval>(50 > width ? 10000/width - 110 : 100)</xsl:eval>%;
                    text-align:left
                  </xsl:attribute>
                  <SPAN STYLE="font-weight:bold"><xsl:value-of select = "BIDDER"/></SPAN>
                  <SPAN STYLE="font-style:italic" font-size="10pt">
                    (<xsl:eval>trimSeconds(selectNodes("TIME").nextNode().text)</xsl:eval>)
                  </SPAN>
                </DIV>
              </DIV>
            </xsl:for-each>
          </DIV>
        </xsl:for-each>
      </xsl:for-each>
    </DIV>
  </xsl:template>
  
  <!-- <xsl:script><![CDATA[
  var width;

  function calcWidth(thisBid)
  {
    // Calculate the width of one bar of the graph
    var thisPrice, minPrice, maxPrice, price;
    var bids, aBid, aPrice;
    var bidlist;

    thisPrice = parseInt(thisBid.text, 10);

    bids = thisBid.parentNode;
    bidlist = bids.selectNodes("BID");

    // Find the highest and lowest bids for this item
    maxPrice = thisPrice;
    minPrice = thisPrice;
    for (aBid = bidlist.nextNode(); aBid != null; aBid = bidlist.nextNode())
    {
      aPrice = aBid.selectNodes("PRICE").nextNode();
      if (aPrice != null)
      {
        price = parseInt(aPrice.text, 10);
        if (price < minPrice) minPrice = price;
        if (price > maxPrice) maxPrice = price;
      }
    }

    // Scale the return value with minPrice at 25% and maxPrice at 100%
    if (maxPrice == minPrice)
      width = 100;
    else
      width = (thisPrice - minPrice) * 75 / (maxPrice - minPrice) + 25;

    return width;
  }

  function calcBidWidth(thisBid)
  {
    return calcWidth(thisBid.parentNode);
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

</xsl:stylesheet>
