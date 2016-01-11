<?xml version="1.0"?>
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
-->
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xhtml="http://www.w3.org/TR/xhtml1/strict"
                xmlns:wv="http://www.openlinksw.com/Virtuoso/WikiV/" >
<xsl:output
   method="html"
   encoding="utf-8"
/>

<xsl:include href="common.xsl"/>
<xsl:include href="template.xsl"/>

<xsl:template match="node()">
  <xsl:copy>
    <xsl:copy-of select="@*" />
    <xsl:apply-templates select="node()" />
  </xsl:copy>
</xsl:template>
  
<xsl:template name="Navigation"/>
<xsl:template name="Toolbar"/>

<xsl:template match="version">
  <tr>
    <td>
      1.<xsl:value-of select="@Number"/>
    </td>
    <td>
      <xsl:value-of select="substring (@ModDate, 0, 20)"/>
    </td>
  </tr>
</xsl:template>

<xsl:template name="Root">
  <form action="{$baseadjust}{$ti_cluster_name}/{$ti_local_name}" method="post">
    <xsl:call-template name="security_hidden_inputs"/>
    Revision: 1.<input type="text" value="" name="rev"/>
    <input name="sumbit" value="Jump" type="submit"/>
  </form>
      
  <table>
   <tr>
     <th> Revision </th>
     <th> Date </th>
   </tr>
  <xsl:for-each select="//version">
    <xsl:sort select="@Number"
	data-type = "number"
	order = "descending" />
    <xsl:if test="position() != 1">
      <tr> 
  	<td> 
	  <img src="/wikix/images/diff.png" alt="Diff" title="Diff"/>
          <xsl:call-template name="wikiref">
            <xsl:with-param name="wikiref_cont">diff</xsl:with-param>
            <xsl:with-param name="wikiref_params">command=diff&amp;rev=<xsl:value-of select="@Number"/></xsl:with-param>
          </xsl:call-template> 
	</td> 
      </tr>
    </xsl:if>
    <xsl:apply-templates select="self::*"/>
  </xsl:for-each>
  </table>
  <form action="{$baseadjust}{$ti_cluster_name}/{$ti_local_name}" method="get">
    <xsl:call-template name="security_hidden_inputs"/>
    <input type="submit" name="command" value="Back to the topic"></input>
  </form>
</xsl:template>

</xsl:stylesheet>
