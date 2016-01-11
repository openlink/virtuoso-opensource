<?xml version="1.0"?>
<!--
 -  
 -  $Id: grocery-list.xsl,v 1.3.10.1 2013/01/02 16:16:04 source Exp $
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl">
  <xsl:template match="/">
    <HTML>
      <HEAD>
        <SCRIPT LANGUAGE="JSCRIPT"><xsl:comment><![CDATA[
          function hiLite()
          {
            e = window.event.srcElement;
            if (e.style.backgroundColor != 'yellow')
              e.style.backgroundColor = 'yellow';
            else
              e.style.backgroundColor = 'white';
          }
        ]]></xsl:comment></SCRIPT>
      </HEAD>
      <BODY>
        <xsl:for-each select="grocery-list/item">
          <DIV STYLE="background-color:yellow" onClick="hiLite()">
            <xsl:value-of/>
          </DIV>
        </xsl:for-each>
      </BODY>
    </HTML>
  </xsl:template>
</xsl:stylesheet>
