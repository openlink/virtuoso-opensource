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
<xsl:stylesheet  xmlns:xsl="http://www.w3.org/TR/WD-xsl">
  <xsl:template match="/">
    <HTML>
      <STYLE>
        TD {font-size:9pt}
      </STYLE>
      <BODY STYLE="font:9pt Verdana">
        <H3>Invoices</H3>
        <TABLE BORDER="1">
          <TR>
            <TD><B>Qty</B></TD>
            <TD><B>Description</B></TD>
            <TD><B>Price</B></TD>
            <TD><B>Discount</B></TD>
            <TD><B>Total</B></TD>
          </TR>
          <xsl:for-each select="invoices/invoice">
            <TR>
              <TD COLSPAN="5" STYLE="border:none; background-color:#DDDDDD">
                Invoice #<xsl:value-of select="@id"/>,
                for customer: <xsl:value-of select="/invoices/customers/customer[@id=context()/customer/@ref]"/>
              </TD>
            </TR>
            <xsl:for-each select="items/item">
              <TR>
                <TD>
                  <xsl:value-of select="qty"/>
                </TD>
                <TD>
                  <xsl:value-of select="description"/>
                </TD>
                <TD>
                  $<xsl:value-of select="price"/>
                </TD>
                <TD> <!-- 10% volume discount -->
                  <xsl:if test="qty[.$ge$10]">
                    <xsl:for-each select="price">
                      <xsl:eval>formatNumber(this.nodeTypedValue*.10, "$#,##0.00")</xsl:eval>
                    </xsl:for-each>
                  </xsl:if>
                </TD>
                <TD STYLE="text-align:right"> <!-- line total -->
                  <xsl:eval>formatNumber(lineTotal(this), "$#,##0.00")</xsl:eval>
                </TD>
              </TR>
            </xsl:for-each>
            <TR>
              <TD COLSPAN="4"></TD>
              <TD STYLE="text-align:right; border:none; border-top:1px solid black">
                <xsl:eval>formatNumber(invoiceTotal(this), "$#,##0.00")</xsl:eval>
              </TD>
            </TR>
            <TR/>
          </xsl:for-each>
        </TABLE>
      </BODY>
    </HTML>
  </xsl:template>
  
  <!-- <xsl:script><![CDATA[
    function invoiceTotal(invoice)
    {
      items = invoice.selectNodes("items/item");
      var sum = 0;
      for (var item = items.nextNode(); item; item = items.nextNode())
      {
        var price = item.selectSingleNode("price").nodeTypedValue;
        var qty = item.selectSingleNode("qty").nodeTypedValue;
        if (qty >= 10)
          price = 0.9*price;
        sum += price * qty;
      }
      return sum;
    }

    function lineTotal(item)
    {
      var price = item.selectSingleNode("price").nodeTypedValue;
      var qty = item.selectSingleNode("qty").nodeTypedValue;
      if (qty >= 10)
        price = 0.9*price;
      return qty*price;
    }
  ]]></xsl:script> -->
</xsl:stylesheet>

