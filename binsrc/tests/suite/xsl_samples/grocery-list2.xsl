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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl">
  <xsl:template match="/">
    <HTML>
      <HEAD>
        <SCRIPT LANGUAGE="JSCRIPT"><xsl:comment><![CDATA[
          function hiLite(normalColor, hiliteColor)
          {
            e = window.event.srcElement;
            if (e.style.backgroundColor == hiliteColor)
              e.style.backgroundColor = normalColor;
            else
              e.style.backgroundColor = hiliteColor;
          }
        ]]></xsl:comment></SCRIPT>
      </HEAD>
      <BODY>
        <xsl:for-each select="grocery-list/item">
          <DIV>
            <xsl:attribute name="STYLE">
              background-color:<xsl:eval>whichColor(this)</xsl:eval>
            </xsl:attribute>
            <xsl:attribute name="onClick">
              hiLite('<xsl:eval>whichColor(this)</xsl:eval>',
                '<xsl:eval>selectedColor(this)</xsl:eval>')
            </xsl:attribute>
            <xsl:value-of/>
          </DIV>
        </xsl:for-each>
      </BODY>
    </HTML>
  </xsl:template>

  <!-- <xsl:script><![CDATA[
    function even(e) {
      return childNumber(e) % 2;
    }

    function whichColor(e) {
      if (even(e))
        return "#ddffdd";
      else
        return "#ffffff";
    }

    function selectedColor(e) {
      if (even(e))
        return "#bbddbb";
      else
        return "#dddddd";
    }
  ]]></xsl:script> -->
</xsl:stylesheet>
