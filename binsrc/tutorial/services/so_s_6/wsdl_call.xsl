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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="html"/>
<xsl:param name="oper" />

<xsl:template match="/">
  <xsl:param name="min_order"/>
  <xsl:param name="max_order"/>
  <HTML>
    <HEAD><link rel="stylesheet" type="text/css" href="../demo.css" /></HEAD>
    <BODY>
     <H3>Enter the data</H3>
     <xsl:choose>
       <xsl:when test="$oper = 'get_customer_info'">
         ('%' sign can be used for search mask, e.g. V%)
       </xsl:when>
       <xsl:when test="$oper = 'new_order'">
         (CustomerID must be 5 character code from Demo.demo.Customers table, e.g. VINET)
       </xsl:when>
       <xsl:when test="$oper = 'get_order'">
         (Order ID minimal value is <xsl:value-of select="$min_order"/>, maximal value is <xsl:value-of select="$max_order"/>)
       </xsl:when>
       <xsl:otherwise>
         <span style="color:red">You haven't select a service!</span>
       </xsl:otherwise>
     </xsl:choose>
     <form action="so_s_6_sample_3.vsp" method="post">
     <input type="hidden" name="oper"><xsl:attribute name="value"><xsl:value-of select="$oper"/></xsl:attribute></input>
     <table class="tableentry">
      <xsl:for-each select="definitions/message">
      <xsl:if test="@name=concat($oper, 'Request')">
        <xsl:for-each select="part">
        <tr><td><input type="text"><xsl:attribute name="name"><xsl:value-of select="@name"/></xsl:attribute></input></td><td><xsl:value-of select="@name"/></td>
	<td><xsl:value-of select="@type"/></td>
	</tr>

        </xsl:for-each>
       </xsl:if>
      </xsl:for-each>
      <xsl:if test="$oper != ''">
        <tr><td colspan="3"><input type="submit" name="exec" value="Call" /></td></tr>
      </xsl:if>
     </table>
     </form>
     <p><a href="so_s_6_sample_1.vsp">New call</a><br /></p>
    </BODY>
  </HTML>
</xsl:template>
</xsl:stylesheet>

