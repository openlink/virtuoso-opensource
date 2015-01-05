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

<!-- Generic stylesheet for viewing XML -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl">
  <xsl:template match="/">
    <DIV STYLE="font-family:Courier; font-size:10pt; margin-bottom:2em">
      <xsl:apply-templates />
    </DIV>
  </xsl:template>  
  
  <xsl:template match="*">
    <DIV STYLE="margin-left:1em; color:gray">
      <xsl:attribute name="id"><xsl:eval>makeId(this)</xsl:eval></xsl:attribute>
      &lt;<xsl:node-name/><xsl:apply-templates select="@*"/>/&gt;
    </DIV>
  </xsl:template>

  <xsl:template match="*[node()]">
    <DIV STYLE="margin-left:1em">
      <SPAN STYLE="color:gray">
        <xsl:attribute name="id"><xsl:eval>makeId(this)</xsl:eval></xsl:attribute>
        &lt;<xsl:node-name/><xsl:apply-templates select="@*"/>&gt;</SPAN><xsl:apply-templates select="node()"/><SPAN STYLE="color:gray">&lt;/<xsl:node-name/>&gt;</SPAN>
    </DIV>
  </xsl:template>

  <xsl:template match="@*" xml:space="preserve">
    <SPAN STYLE="color:navy"><xsl:attribute name="id"><xsl:eval>makeId(this)</xsl:eval></xsl:attribute>
    <xsl:node-name/>="<SPAN STYLE="color:black"><xsl:value-of /></SPAN>"</SPAN>
  </xsl:template>

  <xsl:template match="processing-instruction()">
    <DIV STYLE="margin-left:1em; color:maroon"><xsl:attribute name="id"><xsl:eval>makeId(this)</xsl:eval></xsl:attribute>&lt;?<xsl:node-name/><xsl:apply-templates select="@*"/>?&gt;</DIV>
  </xsl:template>

  <!--
  <xsl:template match="cdata()"><pre><xsl:attribute name="id"><xsl:eval>makeId(this)</xsl:eval></xsl:attribute>&lt;![CDATA[<xsl:value-of />]]&gt;</pre></xsl:template>
  -->

  <xsl:template match="text()"><pre><xsl:attribute name="id"><xsl:eval>makeId(this)</xsl:eval></xsl:attribute>&lt;![CDATA[<xsl:value-of />]]&gt;</pre></xsl:template>

  <xsl:template match=".[not node()]"><SPAN><xsl:attribute name="id"><xsl:eval>makeId(this)</xsl:eval></xsl:attribute><xsl:value-of /></SPAN></xsl:template>
  
  <!-- <xsl:script>
      function makeId(e)
      {
        if (e)
          return makeId(e.selectSingleNode("..")) + 
            absoluteChildNumber(e) + (e.nodeType == 2 ? "@" : "_");
        else
          return "";
      }
  </xsl:script> -->
</xsl:stylesheet>
