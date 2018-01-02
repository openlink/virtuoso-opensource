<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2018 OpenLink Software
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
                xmlns:wv="http://www.openlinksw.com/Virtuoso/WikiV/"
                xmlns:fn2="http://www.w3.org/2004/07/xpath-functions">
<xsl:output
   method="html"
   encoding="utf-8"
/>

<!-- params made by other functions : -->
<xsl:param name="preview_mode"/>
<xsl:param name="readonly"/>
<xsl:param name="baseadjust"/>
<xsl:param name="rnd"/>
<xsl:param name="uid"/>
<xsl:param name="sort"/>
<xsl:param name="col"/>
<xsl:param name="acs"/>
<xsl:param name="acs_marker"/>

<!-- wikiref -->
<xsl:param name="wikiref_params"/>
<xsl:param name="wikiref_cont"/>

<xsl:param name="dashboard">0</xsl:param>
<xsl:param name="admin"/>

<xsl:variable name="hrefdisable">
  <xsl:if test="$preview_mode = '1'">hrefdisable=on&amp;</xsl:if>
</xsl:variable>

<xsl:include href="common.xsl"/>
<xsl:include href="template.xsl"/>

<xsl:template name="Navigation"/>
<xsl:template name="Toolbar"/>

 <xsl:template name="Root">
   Application fault signaled during processing the page. Error has been reported, quote id is:  <xsl:apply-templates/>
	<br/>
	<xsl:call-template name="wikiref">
	  <xsl:with-param name="wikiref_cont"><xsl:value-of select="wv:funcall0('WV.WIKI.DASHBOARD')"/></xsl:with-param>
           <xsl:with-param name="ti_cluster_name">Main</xsl:with-param>
	   <xsl:with-param name="ti_local_name"><xsl:value-of select="wv:funcall0('WV.WIKI.DASHBOARD')"/></xsl:with-param>
	   <xsl:with-param name="wikiref_params"></xsl:with-param>
        </xsl:call-template> 
	<xsl:text> | </xsl:text>
	<xsl:call-template name="wikiref">
           <xsl:with-param name="wikiref_cont">Main home page</xsl:with-param>
           <xsl:with-param name="ti_cluster_name">Main</xsl:with-param>
	   <xsl:with-param name="ti_local_name"><xsl:value-of select="wv:GetMainTopicName('Main')"/></xsl:with-param>
	   <xsl:with-param name="wikiref_params"></xsl:with-param>
        </xsl:call-template> 
	<xsl:if test="$ti_cluster_name != 'Main'">
  	  <xsl:text> | </xsl:text>
	  <xsl:call-template name="wikiref">
           <xsl:with-param name="wikiref_cont"><xsl:value-of select="$ti_cluster_name"/> home page</xsl:with-param>
           <xsl:with-param name="ti_cluster_name"><xsl:value-of select="$ti_cluster_name"/></xsl:with-param>
<!--	   <xsl:with-param name="ti_local_name"><xsl:value-of select="wv:GetMainTopicName($ti_cluster_name)"/></xsl:with-param> -->
	   <xsl:with-param name="ti_local_name"><xsl:value-of select="wv:GetMainTopicName('Main')"/></xsl:with-param> 
	   <xsl:with-param name="wikiref_params"></xsl:with-param>
          </xsl:call-template> 
	</xsl:if> 
<!--
	<xsl:if test="$referer != 'Unknown'">
	    <xsl:text> | </xsl:text>
	    <xsl:call-template name="href">
	     <xsl:with-param name="href"><xsl:value-of select="$referer"/></xsl:with-param>
	     <xsl:with-param name="href_cont">Back</xsl:with-param>
	    </xsl:call-template>
	</xsl:if> -->
 </xsl:template>

 <xsl:template match="Login">
   <xsl:call-template name="Login"/>
 </xsl:template>

 <xsl:template match="node()">
  <xsl:copy>
    <xsl:copy-of select="@*" />
    <xsl:apply-templates select="node()" />
  </xsl:copy>
 </xsl:template>

 <xsl:template match="error">
  <div class="error">
    <xsl:value-of select="@id"/>
  </div>
 </xsl:template>

</xsl:stylesheet>
