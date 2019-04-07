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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output method="html" indent="yes"/>
<xsl:template match="/">

<html>
    <head>
	<title>Sales Report</title>
        <link rel="stylesheet" type="text/css" href="../demo.css" />
    </head>
    <body>
	<table border="1" class="tableresult">
	    <tr>
		<th>OrderID</th>
		<th>ShippedDate</th>
		<th>Product</th>
		<th>Quantity</th>
		<th>UnitPrice</th>
	    </tr>
	    <xsl:for-each select="document/Order">
		<xsl:sort select="@OrderID"
			  data-type="string"
			  order="ascending"/>
		<tr>
		    <td>
			<b><xsl:value-of select="@OrderID"/></b>
		    </td>
		    <td>
			<em><xsl:value-of select="substring (@ShippedDate, 0, 11)"/></em>
		    </td>
    	           <xsl:for-each select="Product">
		    <td>
			<xsl:value-of select="@ProductName"/>
		    </td>
	            <xsl:for-each select="Details">
		    <td>
			<xsl:value-of select="@Quantity"/>
		    </td>
		    <td>
			<xsl:value-of select="@UnitPrice"/>
		    </td>
	          </xsl:for-each>
	         </xsl:for-each>
		</tr>
	    </xsl:for-each>
	</table>
        <p><a href="vs_xr_1_qry.vsp">Get a new report</a></p>
    </body>
</html>

</xsl:template>
</xsl:stylesheet>
