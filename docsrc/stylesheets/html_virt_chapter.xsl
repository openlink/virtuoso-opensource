<?xml version='1.0'?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2014 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

  <xsl:output method="html"/>

  <xsl:include href="html_virt_common.xsl"/> 
  <xsl:include href="html_virt_functions.xsl"/> 

  <xsl:template match="/book"> 
    <xsl:apply-templates /> <!-- select="chapter" / -->
  </xsl:template> 

  <xsl:template match="chapter[@id = $chap]"> 

    <DIV CLASS="abstractbg">
      <xsl:apply-templates select="./abstract" />
    </DIV>

    <DIV CLASS="chaptoc">

      <!--  ########## mini Contents bit ######### -->

      <xsl:if test=".//sect1">
        <H2 CLASS="chaptochead">Table of Contents</H2>
        <UL>
          <xsl:for-each select="./sect1">
            <LI class="toc2">
              <A CLASS="toc2">
                <xsl:attribute name="HREF">#<xsl:value-of select="./@id" /></xsl:attribute>
    	        <xsl:value-of select="./title"/>
              </A>
            </LI>
            <UL>
              <xsl:for-each select="./sect2">
	        <LI class="toc3">
	          <A CLASS="toc3">
	            <xsl:attribute name="HREF">#<xsl:value-of select="./@id" /></xsl:attribute>
	            <xsl:value-of select="./title"/>
	          </A>
	        </LI>
              </xsl:for-each>
            </UL>
          </xsl:for-each>
        </UL>
      </xsl:if>
      <xsl:if test=".//refentry">
        <DIV CLASS="reftoc" COLSPAN="2">
          <H2 CLASS="reftochead">Reference Entries</H2>
          <xsl:for-each select=".//refentry" order-by="+.">
            <A CLASS="toc3">
	      <xsl:attribute name="HREF">#<xsl:value-of select="./@id" /></xsl:attribute>
	      <xsl:value-of select="./refmeta/refentrytitle"/>
            </A>
            <xsl:choose>
              <xsl:when test="following-sibling::refentry">
                <xsl:text>, </xsl:text>
              </xsl:when>
              <xsl:otherwise>
                <xsl:text>.</xsl:text>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:for-each>
        </DIV>
      </xsl:if>
      <BR />

      <!--  ########## ########### ######### -->

      <DIV CLASS="chapter" WIDTH="100%">
        <xsl:apply-templates select="sect1|refentry"/>
      </DIV>
    </DIV>
  </xsl:template>
</xsl:stylesheet>



