<?xml version='1.0'?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" />
  <xsl:template match="/definitions">
  <html>
    <head><link rel="stylesheet" type="text/css" href="../demo.css" /></head>
      <body>
	  <h3>WSDL service description of the so-s-1 and so-s-2 examples rendered with XSL-T style-sheet</h3>
	  <xsl:for-each select="message">
	    <table class="tableresult">
	      <th>message</th>
	      <tr>
	       <td colspan="2">
	      <xsl:value-of select="@name"/>
	       </td>
	      </tr>
	      <xsl:for-each select="part">
	      <tr>
	       <td>
		<xsl:value-of select="@name"/>
	       </td>
               <td>
		<xsl:value-of select="@type"/>
	       </td>
               </tr>
	      </xsl:for-each>
	    </table>
	  </xsl:for-each>
	  <xsl:for-each select="portType/operation">
	    <table class="tableresult">
	      <th>operation</th>
	      <tr>
	       <td colspan="2">
	      <xsl:value-of select="@name"/>
	       </td>
	      </tr>
	      <xsl:for-each select="input">
	      <tr>
	       <td>
	        input
	       </td>
	       <td>
		<xsl:value-of select="@message"/>
	       </td>
               <td>
		<xsl:value-of select="@name"/>
	       </td>
               </tr>
	      </xsl:for-each>
	      <xsl:for-each select="output">
	      <tr>
	       <td>
	        output
	       </td>
	       <td>
		<xsl:value-of select="@message"/>
	       </td>
               <td>
		<xsl:value-of select="@name"/>
	       </td>
               </tr>
	      </xsl:for-each>
	    </table>
	  </xsl:for-each>
      </body>
  </html>
  </xsl:template>
</xsl:stylesheet>

