<?xml version="1.0"?>
<!--
 -  
 -  $Id$
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
      <HEAD>
        <TITLE><xsl:value-of select="spec/header/title"/></TITLE>
      </HEAD>
      <BODY STYLE="font:9pt Verdana">
        <xsl:for-each select="spec/header">
          <H2><xsl:value-of select="title"/></H2>
          <H4><xsl:value-of select="version"/></H4>
          <H4>World Wide Web Consortium Working Draft
            <xsl:value-of select="pubdate/day"/>-<xsl:value-of select="pubdate/month"/>-<xsl:value-of select="pubdate/year"/>
          </H4>
        </xsl:for-each>
        
        <HR/>
        
        <H3>Table of Contents</H3>
        <xsl:apply-templates select="spec/body/div1 | spec/back/*">
<!-- OBSOLETE	
          <xsl:template match="div1|div2|div3|div4|div5|div6">
            <DIV STYLE="margin-left:1em"><!-- <xsl:eval>sectionNum(this)</xsl:eval> - ->
              <xsl:value-of select="head"/>
              <xsl:apply-templates select="div2|div3|div4|div5|div6"/>
            </DIV>
          </xsl:template>
          <xsl:template match="inform-div1">
            <DIV STYLE="margin-left:1em"><!-- <xsl:eval>sectionNum(this)</xsl:eval> - ->
              <xsl:value-of select="head"/> (Non-Normative)
              <xsl:apply-templates select="div2"/>
            </DIV>
          </xsl:template>
-->	  
        </xsl:apply-templates>
        
      </BODY>
    </HTML>
  </xsl:template>
  
  <!-- <xsl:script><![CDATA[
    function sectionNum(e) {
      if (e)
      {
        if (e.parentNode.nodeName == "back")
          return formatIndex(absoluteChildNumber(e), "A") + ".";
        else
          return sectionNum(e.selectSingleNode("ancestor(inform-div1|div1|div2|div3|div4|div5)")) +
               formatIndex(childNumber(e), "1") + ".";
      }
      else
      {
        return "";
      }
    }
    
    var prodCount = 1;
    function prodNum() {
      return formatIndex(prodCount++, "1");
    }

  ]]></xsl:script> -->

</xsl:stylesheet>
