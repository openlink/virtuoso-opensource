<?xml version='1.0'?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" >
<xsl:output method="html"/>

<xsl:template match="/">
  <HTML>
    <HEAD><link rel="stylesheet" type="text/css" href="../demo.css" /></HEAD>
    <title>Administrative divisions</title>
    <BODY>
     <xsl:for-each select="administrative_divisions/country">
     <H3>Administrative divisions of <xsl:value-of select="name" /></H3>
     <!--
     <p><xsl:value-of select="@info" /></p>
     -->
     <table class="tableresult">
      <xsl:for-each select="province">
       <tr><td><xsl:value-of select="name"/></td></tr>
      </xsl:for-each>
     </table>
     </xsl:for-each>
     <xsl:for-each select="administrative_divisions/noentries">
     <H3>No entries found for <xsl:value-of select="@mask" /></H3>
     </xsl:for-each>
     <p><a href="so_s_11_client.vsp">Get new</a></p>
    </BODY>
  </HTML>
</xsl:template>
</xsl:stylesheet>
