<?xml version="1.0"?>
<!--
 -  
 -  $Id: raw-xml.xsl,v 1.6.10.1 2013/01/02 16:16:10 source Exp $
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

<!-- Generic style sheet for viewing XML -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl">
  <!-- This template will always be executed, even if this style sheet is not run on the document root -->
  <xsl:template>
    <DIV STYLE="font-family:Courier; font-size:10pt; margin-bottom:2em">
      <!-- Scoped templates are used so they don't interfere with the "kick-off" template. -->
      <xsl:apply-templates select=".">
<!-- OBSOLETE      
        <xsl:template><xsl:apply-templates/></xsl:template>

        <xsl:template match="*">
          <DIV STYLE="margin-left:1em; color:gray">
            &lt;<xsl:value-of select="name()" /><xsl:apply-templates select="@*"/>/&gt;
          </DIV>
        </xsl:template>

        <xsl:template match="*[node()]">
          <DIV STYLE="margin-left:1em">
            <SPAN STYLE="color:gray">&lt;<xsl:value-of select="name()" /><xsl:apply-templates select="@*"/>&gt;</SPAN><xsl:apply-templates select="node()"/><SPAN STYLE="color:gray">&lt;/<xsl:value-of select="name()"/>&gt;</SPAN>
          </DIV>
        </xsl:template>

        <xsl:template match="@*">
          <SPAN STYLE="color:navy"><xsl:value-of select="name()" />="<SPAN STYLE="color:black"><xsl:value-of select="." /></SPAN>"</SPAN>
        </xsl:template>

        <xsl:template match="processing-instruction()">
          <DIV STYLE="margin-left:1em; color:maroon">&lt;?<xsl:value-of select="name()" /><xsl:apply-templates select="@*"/>?&gt;</DIV>
        </xsl:template>

        <xsl:template match="text()"><pre>&lt;![CDATA[<xsl:value-of select="." />]]&gt;</pre></xsl:template>

        <xsl:template match=".[not node()]"><xsl:value-of select="." /></xsl:template>
-->	
      </xsl:apply-templates>
    </DIV>
  </xsl:template>
</xsl:stylesheet>
