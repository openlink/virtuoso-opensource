<?xml version='1.0'?>
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
<!DOCTYPE html  PUBLIC "" "../ent.dtd">
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" >
<xsl:output method="html" indent="yes"/>
<xsl:param name="mask" />

<xsl:template match="/">
  <HTML>
    <HEAD><link rel="stylesheet" type="text/css" href="../demo.css" /></HEAD>
    <title>Administrative divisions</title>
    <BODY>
     <xsl:choose>
     <xsl:when test="number(get_Divisions2DResponse/CallReturn/item[1]) > 0">
     <H3>Administrative divisions of <xsl:value-of select="$mask" /></H3>
     <p>Divisions: <xsl:value-of select="get_Divisions2DResponse/CallReturn/item[1]" /></p>
     <table class="tableresult">
       <xsl:apply-templates select="get_Divisions2DResponse/CallReturn" />
     </table>
     </xsl:when>
     <xsl:otherwise>
     <H3>No entries found for <xsl:value-of select="$mask" /></H3>
     </xsl:otherwise>
     </xsl:choose>

     <p><a href="so_s_11_array_client.vsp">Get new</a></p>
    </BODY>
  </HTML>
</xsl:template>

<xsl:template match="item">
       <xsl:if test="(position(.) mod 2) != 1">
         <tr><td>
	   <xsl:value-of select="."/>&nbsp;
	 </td></tr>
       </xsl:if>
</xsl:template>

</xsl:stylesheet>
