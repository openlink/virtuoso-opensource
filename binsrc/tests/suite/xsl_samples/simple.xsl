<?xml version="1.0"?>
<!--
 -  
 -  $Id: simple.xsl,v 1.3.10.1 2013/01/02 16:16:12 source Exp $
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl">
  <xsl:template match="/">
    <HTML>
      <BODY STYLE="font-family:Arial, helvetica, sans-serif; font-size:12pt;
            background-color:#EEEEEE">
        <xsl:for-each select="breakfast-menu/food">
          <DIV STYLE="background-color:teal; color:white; padding:4px">
            <SPAN STYLE="font-weight:bold; color:white"><xsl:value-of select="name"/></SPAN>
            - <xsl:value-of select="price"/>
          </DIV>
          <DIV STYLE="margin-left:20px; margin-bottom:1em; font-size:10pt">
            <xsl:value-of select="description"/>
            <SPAN STYLE="font-style:italic">
              (<xsl:value-of select="calories"/> calories per serving)
            </SPAN>
          </DIV>
        </xsl:for-each>
      </BODY>
    </HTML>
  </xsl:template>
</xsl:stylesheet>
