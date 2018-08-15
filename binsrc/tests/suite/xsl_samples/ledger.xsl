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

<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl">
  <xsl:template match="/">
    <HTML>
      <BODY>
        <TABLE STYLE="font-family:Arial; font-size:10pt"
            cellspacing="0" cellpadding="2" width="100%">
          <TR STYLE="background-color:green; color:white">
            <TD>date</TD>
            <TD>number</TD>
            <TD>payee</TD>
            <TD>category</TD>
            <TD>memo</TD>
            <TD>payment</TD>
            <TD>deposit</TD>
            <TD>balance</TD>
            <TD>graph</TD>
          </TR>
          <xsl:for-each select="ledger/*">
            <TR>
              <xsl:if expr="even(this)">
                <xsl:attribute name="STYLE">background-color:lightgreen</xsl:attribute>
              </xsl:if>
              <TD><xsl:value-of select="date"/></TD>
              <TD><xsl:value-of select="number"/></TD>
              <TD><xsl:value-of select="payee"/></TD>
              <TD><xsl:value-of select="category"/></TD>
              <TD><xsl:value-of select="memo"/></TD>
              <xsl:apply-templates select=".">
                <xsl:template>
                  <TD STYLE="text-align:right">$<xsl:value-of select="amount"/></TD>
                  <TD/>
                </xsl:template>
                <xsl:template match="deposit | opening-balance">
                  <TD/>
                  <TD STYLE="text-align:right">$<xsl:value-of select="amount"/></TD>
                </xsl:template>
              </xsl:apply-templates>
              <TD STYLE="text-align:right">
                <xsl:eval>total(this)</xsl:eval>
              </TD>
              <TD STYLE="width:100px; text-align:right; font-size:smaller">
                <DIV STYLE="text-align:left; position:relative; border:1px solid black">
                  <DIV>
                    <xsl:attribute name="STYLE">
                      text-align:left;
                      position:relative;
                      background-color:<xsl:eval>balance &lt; 0 ? "red" : "black"</xsl:eval>;
                      width:<xsl:eval>(balance &lt; 0 ? -balance : balance)*100/range</xsl:eval>;
                      left:<xsl:eval>(balance &lt; 0 ? balance-lowBalance : -lowBalance)*100/range</xsl:eval>px;
                    </xsl:attribute>
                  </DIV>
                </DIV>
              </TD>
            </TR>
            <xsl:if expr="balance &lt; 0">
              <TR>
                <TD COLSPAN="9" STYLE="background-color:red; color:white; font-weight:bold; text-align:center">
                  Overdraft!  Please remit <xsl:eval>formatNumber(-balance, "$#,###.00")</xsl:eval> 
                  within 24 hours to avoid returned check fees!
                </TD>
              </TR>
            </xsl:if>          
          </xsl:for-each>
        </TABLE>
      </BODY>
    </HTML>
  </xsl:template>

  <!-- <xsl:script><![CDATA[
    balance = 0;
    // The following should really be calculated from the data, but we'll just
    //  set some approximate values for this sample.
    highBalance = 1500;
    lowBalance = -500;
    range = 2000;
    
    function total(e) {
      amount = parseInt(e.selectSingleNode("amount").text);
      if (e.nodeName == 'deposit' || e.nodeName == 'opening-balance')
        balance += amount;
      else
        balance -= amount;
      return formatNumber(balance, "$#,###.00");
    }
    
    function even(e) {
      return absoluteChildNumber(e)%2 == 0;
    }
  ]]></xsl:script> -->
  
</xsl:stylesheet>

