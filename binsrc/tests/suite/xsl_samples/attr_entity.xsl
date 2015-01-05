<?xml version="1.0"?>
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
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" indent="yes"/>

  <xsl:template match="/">
    <html>
          <body>
          <table border="5">
                 <xsl:apply-templates select="*"/>
          </table>
          </body>
    </html>
  </xsl:template>


    <xsl:template match="*">
       <tr>
           <td>
              <xsl:text>&lt;</xsl:text>
	      <xsl:value-of select="name()"/>
              <xsl:text> </xsl:text>
              <xsl:for-each select="@*">
                <xsl:text> </xsl:text>
		<xsl:value-of select="name()"/>
		<xsl:text>="</xsl:text>
		<xsl:value-of select="."/>
		<xsl:text>" </xsl:text>
              </xsl:for-each>
              <xsl:text>&gt;</xsl:text>  <xsl:value-of select="text()"/>
           </td>
        </tr>
           <xsl:apply-templates select="*"/>
        <tr>
           <td>
              <xsl:text>&lt;/</xsl:text><xsl:value-of select="name()"/><xsl:text>&gt;</xsl:text>
           </td>

       </tr>
    </xsl:template>

</xsl:stylesheet>
