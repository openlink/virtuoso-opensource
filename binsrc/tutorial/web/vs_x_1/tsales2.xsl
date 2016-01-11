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



<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                >

    <xsl:output method="html" indent="yes"/>

<xsl:param name="p">123</xsl:param>
<xsl:variable name="p1"><xsl:value-of select="number ($p) + 1"/></xsl:variable>



<xsl:template match="/">

<html attr="{1+2+3}">
    <xsl:variable name="head">
      <head>
	<link rel="stylesheet" type="text/css" href="../demo.css" />
	  <title>Sales Results By Division</title>
      </head>
    </xsl:variable>
    <xsl:copy-of select="$head"/>
    <body>
	<p>Value of parameter (p+1) = <xsl:value-of select="$p1"/></p>
	<table class="tableresult">
	    <tr>
		<th>Division</th>
		<th>Revenue</th>
		<th>Growth</th>
		<th>Bonus</th>
	    </tr>
	    <xsl:variable name="divs" select="sales/division"/>
	    <xsl:for-each select="$divs">
		<tr>
		    <td>
			<em><xsl:value-of select="@id"/></em>
		    </td>
		    <td>
			<xsl:value-of select="revenue"/>
		    </td>
		    <td>
			<!-- highlight negative growth in red -->
			<xsl:if test="growth &lt; 0">
			     <xsl:attribute name="style">
				 <xsl:text>color:red</xsl:text>
			     </xsl:attribute>
			</xsl:if>
			<xsl:value-of select="growth"/>
		    </td>
		    <td>
			<xsl:value-of select="bonus"/>
		    </td>
		</tr>
	    </xsl:for-each>
	</table>
    </body>
</html>

</xsl:template>
</xsl:stylesheet>

