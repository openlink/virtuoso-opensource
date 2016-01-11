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
                xmlns:wv="http://www.openlinksw.com/Virtuoso/WikiV/"
                xmlns:fn2="http://www.w3.org/2004/07/xpath-functions">
<xsl:output
   method="html"
   encoding="utf-8"
/>

<!-- params made by "TopicInfo"::ti_xslt_vector() : -->
<!--
<xsl:param name="ti_default_cluster"/>
<xsl:param name="ti_raw_name"/>	
<xsl:param name="ti_raw_title"/>
<xsl:param name="ti_wiki_name"/>
<xsl:param name="ti_cluster_name"/>
<xsl:param name="ti_local_name"/>
<xsl:param name="ti_id"/>
<xsl:param name="ti_cluster_id"/>
<xsl:param name="ti_res_id"/>
<xsl:param name="ti_col_id"/>
<xsl:param name="ti_abstract"/>
<xsl:param name="ti_text"/>
<xsl:param name="ti_author_id"/>
<xsl:param name="ti_etrx_id"/>
<xsl:param name="ti_etrx_datetime"/>
-->
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

<xsl:variable name="hrefdisable">
  <xsl:if test="$preview_mode = '1'">hrefdisable=on&amp;</xsl:if>
</xsl:variable>

<xsl:include href="common.xsl"/>
<xsl:include href="template.xsl"/>

<xsl:template name="Navigation"/>
<xsl:template name="Toolbar"/>


 <xsl:template match="Login">
   <xsl:call-template name="Login"/>
 </xsl:template>

<xsl:template match="node()">
  <xsl:copy>
    <xsl:copy-of select="@*" />
    <xsl:apply-templates select="node()" />
  </xsl:copy>
</xsl:template>

<xsl:template name="Root">
    <xsl:apply-templates/>
    <xsl:call-template name="back-button"/>
</xsl:template>





</xsl:stylesheet>
