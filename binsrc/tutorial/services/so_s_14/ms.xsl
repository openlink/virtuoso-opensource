<?xml version='1.0'?>
<!--
 -  
 -  $Id$
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" >
<xsl:output method="html"/>
<xsl:param name="dsn" />
<xsl:param name="mask" />

<xsl:template match="/">
  <HTML>
    <HEAD><link rel="stylesheet" type="text/css" href="../demo.css" /></HEAD>
    <title>Results of searching on <xsl:value-of select="$mask" /></title>
    <BODY>
     <H3>Simple SOAP client</H3>
     <H4>Results of searching on <xsl:value-of select="$mask" /></H4>
      <table class="tableresult">
      <tr>
         <th>CustomerID</th>
         <th>Company Name</th>
         <th>OrderDate</th>
         <th>ShippedDate</th>
         <th>ProductID</th>
         <th>Quantity</th>
         <th>Discount</th>
      </tr>
      <xsl:for-each select="/remote/record">
      <tr>
         <td><xsl:value-of select="@CustomerID"/></td>
         <td><xsl:value-of select="@CompanyName"/></td>
         <td><xsl:value-of select="@OrderDate"/></td>
         <td><xsl:value-of select="@ShippedDate"/></td>
         <td><xsl:value-of select="@ProductID"/></td>
         <td><xsl:value-of select="@Quantity"/></td>
         <td><xsl:value-of select="@Discount"/></td>
      </tr>
      </xsl:for-each>
      </table>
     <p><a href="so_s_14_ms_client.vsp">New search</a></p>
    </BODY>
  </HTML>
</xsl:template>
</xsl:stylesheet>
