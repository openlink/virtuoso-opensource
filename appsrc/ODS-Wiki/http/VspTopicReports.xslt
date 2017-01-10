<?xml version="1.0"?>
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
-->
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xhtml="http://www.w3.org/TR/xhtml1/strict"
                xmlns:wv="http://www.openlinksw.com/Virtuoso/WikiV/" >

  <xsl:output method="html" encoding="utf-8"/>

<xsl:include href="common.xsl"/>
<xsl:include href="template.xsl"/>

<xsl:param name="sid"/>
<xsl:param name="realm"/>

<xsl:template match="node()">
  <xsl:copy>
    <xsl:copy-of select="@*" />
    <xsl:apply-templates select="node()" />
  </xsl:copy>
</xsl:template>
  
  <xsl:template match="Referers">
    <h3>Topics that link to
    <xsl:call-template name="wikiref">
      <xsl:with-param name="wikiref_cont"><xsl:value-of select="$ti_cluster_name"/>.<xsl:value-of select="$ti_local_name"/></xsl:with-param>
    </xsl:call-template>:</h3>
    <ul>
      <xsl:apply-templates select="Link">
        <xsl:sort select="@LOCALNAME"/>
      </xsl:apply-templates>
    </ul>
  </xsl:template>

<xsl:template match="Link">
<li>
  <xsl:call-template name="wikiref">
    <xsl:with-param name="ti_local_name"><xsl:value-of select="@LOCALNAME"/></xsl:with-param>
    <xsl:with-param name="ti_cluster_name"><xsl:value-of select="@CLUSTERNAME"/></xsl:with-param>
    <xsl:with-param name="wikiref_cont"><xsl:value-of select="@CLUSTERNAME"/>.<xsl:value-of select="@LOCALNAME"/></xsl:with-param>
  </xsl:call-template>
<xsl:if test="@Abstract"> -- <xsl:value-of select="@Abstract"/></xsl:if>
      <xsl:if test="@UPDATED_ON"> (<i>last updated by <b><xsl:value-of select="@UPDATED_BY"/></b> on <b><xsl:value-of select="@UPDATED_ON"/></b></i>)</xsl:if>
      <!--<xsl:if test="@CREATED_ON"> (<i>created by <b><xsl:value-of select="@CREATED_BY"/></b> on <b><xsl:value-of select="@CREATED_ON"/></b></i>)</xsl:if>-->
</li>
</xsl:template>

<xsl:template match="ClusterIndex">
<h3>This is a list of all topics of the cluster "<xsl:value-of select="$ti_cluster_name"/>":</h3>
<ul>
<xsl:apply-templates select="Link">
  <xsl:sort select="@LOCALNAME"/>
</xsl:apply-templates>
</ul>
</xsl:template>

<xsl:template match="Diff">
<h3>This is a diff between 1.<xsl:value-of select="@from"/> and 1.<xsl:value-of select="@to"/> revisions:</h3>
<code>
 <xsl:copy-of select="wv:DiffPrint(text/text())"/>
</code>
</xsl:template>

<xsl:template name="Navigation"/>
<xsl:template name="Toolbar"/>

<xsl:template name="Root">
  <xsl:param name="back_to_rev"/>
  <xsl:apply-templates select="node()"/>
  <div class="report-buttons">
    <span>
      <xsl:call-template name="back-button"/>
    </span>
    <span>
      <xsl:if test="$back_to_rev = 1">
        <form>
          <xsl:attribute name="action"><xsl:value-of select="wv:ResourceHREF2 ('history.vspx', $baseadjust, '')"/></xsl:attribute>
          <xsl:attribute name="method">get</xsl:attribute>
          <xsl:call-template name="security_hidden_inputs"/>
          <input type="submit" name="command" value="Back to the history"/>
          <input>
            <xsl:attribute name="type">hidden</xsl:attribute>
            <xsl:attribute name="name">id</xsl:attribute>
            <xsl:attribute name="value"><xsl:value-of select="$ti_id"/></xsl:attribute>
          </input>
          <input>
            <xsl:attribute name="type">hidden</xsl:attribute>
            <xsl:attribute name="name">sid</xsl:attribute>
            <xsl:attribute name="value"><xsl:value-of select="$sid"/></xsl:attribute>
          </input>
        </form>
      </xsl:if>
    </span>
  </div>
</xsl:template>

</xsl:stylesheet>
