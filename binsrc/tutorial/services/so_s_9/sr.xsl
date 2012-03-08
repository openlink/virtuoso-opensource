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
  <xsl:param name="url"  />
  <xsl:param name="symbol" />

  <xsl:template match="/">
    <HTML>
      <HEAD><link rel="stylesheet" type="text/css" href="demo.css" /></HEAD>
      <title>Stock Quotes</title>
      <BODY>
	<H3>Simple SOAP client</H3>
	<H4>Quotes for: <xsl:value-of select="$symbol" /></H4>
	<xsl:for-each select="StockQuotes/Stock">
	    <table class="tableresult">
		<xsl:for-each select="*">
		    <tr><td><xsl:value-of select="local-name()"/></td><td><xsl:value-of select="."/></td></tr>
		</xsl:for-each>
	  </table>
	  <br/>
	</xsl:for-each>
        <p><a href="../so_s_9/so_s_9_client.vsp">Get new quote</a></p>
      </BODY>
    </HTML>
  </xsl:template>
</xsl:stylesheet>
