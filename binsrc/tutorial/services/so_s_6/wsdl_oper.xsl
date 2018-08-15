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

<xsl:template match="/">
  <HTML>
    <HEAD><link rel="stylesheet" type="text/css" href="../demo.css" /></HEAD>
    <BODY>
     <H3>Select service</H3>
     <form action="so_s_6_sample_2.vsp" method="post">
     <table class="tableentry">
      <xsl:for-each select="definitions/binding/operation">
        <tr><td><input type="radio" name="oper"><xsl:attribute name="value"><xsl:value-of select="@name"/></xsl:attribute></input></td><td><xsl:value-of select="@name"/></td></tr>
      </xsl:for-each>
        <tr><td colspan="2"><input type="submit" name="exec" value="Continue" /></td></tr>
     </table>
     </form>
    </BODY>
  </HTML>
</xsl:template>
</xsl:stylesheet>

