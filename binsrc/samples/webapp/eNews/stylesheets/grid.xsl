<?xml version="1.0" ?> 
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2017 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/XSL/Transform/1.0" version="1.0">
  <xsl:output method="html" />
  <xsl:param name="xml_url" />
  <xsl:template match="/moreovernews">
      <div ID="news" style="position:absolute; width:300; top:10; left:10; backgroundcolor: #FFFFCC">
        <table cellpadding="10" cellspacing="0" border="1" width="300">
          <tr>
            <td class="heading" colspan="2">
              <a class="xml_url" target="_blank">
                <xsl:attribute name="HREF">
                  <xsl:value-of select="$xml_url" />
                </xsl:attribute>
                <xsl:value-of select="//article/cluster" />
              </a>
            </td>
          </tr>
          <xsl:for-each select="article">
            <TR bgColor="#FFFFCC">
              <TD VALIGN="top" WIDTH="95">
                <font class="harvest">
                  <xsl:value-of select="harvest_time" />
                </font>
              </TD>
              <TD VALIGN="top" WIDTH="200">
                <A CLASS="headline" TARGET="_blank">
                  <xsl:attribute name="HREF">
                    <xsl:value-of select="url" /> 
                  </xsl:attribute>
                  <xsl:value-of select="headline_text" /> 
                </A>
              </TD>
            </TR>
          </xsl:for-each>
          <xsl:text>&#13;</xsl:text>
        </table>
      </div>
  </xsl:template>
</xsl:stylesheet>
