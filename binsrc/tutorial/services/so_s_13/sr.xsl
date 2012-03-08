<?xml version='1.0'?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" >
<xsl:output method="html"/>
<xsl:param name="url" />
<xsl:param name="symbol" />

<xsl:template match="/">
  <HTML>
    <HEAD><link rel="stylesheet" type="text/css" href="../demo.css" /></HEAD>
    <title>Nasdaq quote for <xsl:value-of select="$symbol" /></title>
    <BODY>
     <H3>Simple SOAP client</H3>
     <H4>Peer Certificate Info:</H4>
     <table border="0" class="tableresult">
     <tr><td>Serial #</td> <td><xsl:value-of select="quotes/cert_info/sn" /></td></tr>
     <tr><td>Subject</td> <td><xsl:value-of select="quotes/cert_info/subject" /></td></tr>
     <tr><td>Issuer</td> <td><xsl:value-of select="quotes/cert_info/issuer" /></td></tr>
     <tr><td>Not valid before</td> <td><xsl:value-of select="quotes/cert_info/bef" /></td></tr>
     <tr><td>Not valid after</td> <td><xsl:value-of select="quotes/cert_info/after" /></td></tr>
     </table>
      <xsl:for-each select="quotes/nasdaqamex-dot-com/equity-quote">
     <H4>Quotes for: <xsl:value-of select="issue-name" /></H4>
     <table class="tableresult">
     <tr><td>Source</td><td><a><xsl:attribute name="href">
     <xsl:value-of select="$url" /><xsl:value-of select="@symbol" /></xsl:attribute>
     View XML source</a></td></tr>
       <tr><td>Symbol</td>		<td><xsl:value-of select="@symbol"/></td></tr>
       <tr><td>Market</td>		<td><xsl:value-of select="market-center-code"/></td></tr>
       <tr><td>Todays High</td>		<td><xsl:value-of select="todays-high-price"/></td></tr>
       <tr><td>Todays Low</td>		<td><xsl:value-of select="todays-low-price"/></td></tr>
       <tr><td>52-Weeks High</td>	<td><xsl:value-of select="fifty-two-wk-high-price"/></td></tr>
       <tr><td>52-Weeks Low</td>	<td><xsl:value-of select="fifty-two-wk-low-price"/></td></tr>
       <tr><td>Last Sale Price</td>	<td><xsl:value-of select="last-sale-price"/></td></tr>
       <tr><td>Net Price Change</td>	<td><xsl:value-of select="net-change-price"/></td></tr>
       <tr><td>Net Percent Change</td>	<td><xsl:value-of select="net-change-pct"/></td></tr>
       <tr><td>Share Volume</td><td><xsl:value-of select="share-volume-qty"/>	</td></tr>
       <tr><td>Previous Close Price</td> 	<td><xsl:value-of select="previous-close-price"/></td></tr>
       <tr><td>Total Outstanding Shares</td> 	<td><xsl:value-of select="total-outstanding-shares-qty"/></td></tr>
       <xsl:if test="issuer-web-site-url!=''">
       <tr><td>Issuer-Web-Site</td><td><a><xsl:attribute name="href"><xsl:value-of select="issuer-web-site-url"/></xsl:attribute><xsl:value-of select="issuer-web-site-url"/></a></td></tr>
       </xsl:if>
       <xsl:if test="issuer-logo-url!=''">
       <tr><td>Issuer-Logo</td><td><img><xsl:attribute name="src"><xsl:value-of select="issuer-logo-url"/></xsl:attribute></img></td></tr>
       </xsl:if>
       <tr><td>Trading Status</td>	<td><xsl:value-of select="trading-status"/></td></tr>
     </table>
      </xsl:for-each>
     <p><a href="so_s_13_secure_SOAP_client.vsp">Get new quote</a></p>
    </BODY>
  </HTML>
</xsl:template>
</xsl:stylesheet>
