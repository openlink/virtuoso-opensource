<?xml version='1.0'?>
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
  <xsl:output method="html" />
  <xsl:template match="/">
    <HTML>
     <head><link rel="stylesheet" type="text/css" href="../demo.css" /></head>
      <BODY>
        <TABLE BORDER="0" class="tableresult">
          <TR>
            <TD>OrderID</TD>
            <TD>OrderDate</TD>
            <TD>CustomerID</TD>
          </TR>
          <xsl:for-each select="doc/cat/ord">
            <TR>
              <TD><xsl:value-of select="@OrderID"/></TD>
              <TD><xsl:value-of select="@OrderDate"/></TD>
              <TD><xsl:value-of select="@CustomerID"/></TD>
            </TR>
	    <TR>
	    <TD colspan="3">
	    <table border="0" class="tableresult">
	    <xsl:for-each select="prod">
	      <tr>
              <TD><xsl:value-of select="@ProductName"/></TD>
		<xsl:for-each select="det">
		  <TD><xsl:value-of select="@Quantity"/></TD>
		  <TD><xsl:value-of select="@UnitPrice"/></TD>
		</xsl:for-each>
	      </tr>
            </xsl:for-each>
	    </table>
	    </TD>
	    </TR>
          </xsl:for-each>
        </TABLE>
      </BODY>
    </HTML>
  </xsl:template>
</xsl:stylesheet>
