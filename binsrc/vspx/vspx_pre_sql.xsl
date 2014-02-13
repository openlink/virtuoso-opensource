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
     version="1.0"
     xmlns:v="http://www.openlinksw.com/vspx/"  exclude-result-prefixes="v"
     xmlns:xhtml="http://www.w3.org/1999/xhtml">
<xsl:output method="text" omit-xml-declaration="yes" indent="yes"
	cdata-section-elements="v:after-data-bind v:after-data-bind-container v:before-data-bind v:before-data-bind-container v:on-post v:on-post-container v:before-render v:before-render-container v:on-init v:script" />

<xsl:template match="/">
  <xsl:apply-templates select="//v:*" mode="attr-check" />
  <xsl:apply-templates select="node()" />
</xsl:template>

<xsl:template match="*">
  <xsl:copy>
    <xsl:for-each select="@*"><xsl:copy /></xsl:for-each>
    <xsl:apply-templates select="node()" />
  </xsl:copy>
</xsl:template>

<xsl:template match="v:*">
  <xsl:copy>
    <xsl:for-each select="@*"><xsl:copy /></xsl:for-each>
    <xsl:if test="empty(@control-udt) and empty (.[v:page])">
      <xsl:attribute name="control-udt"><xsl:apply-templates select="." mode="create_control_name"/></xsl:attribute>
    </xsl:if>
    <xsl:apply-templates select="node()" />
  </xsl:copy>
</xsl:template>

<xsl:template match="v:on-init|v:on-init-container|v:before-data-bind|v:before-data-bind-container|v:after-data-bind|v:after-data-bind-container|v:on-post|v:on-post-container|v:before-render|v:before-render-container">
  <xsl:element name="{concat ('v:', replace (local-name(.), '-container', ''))}">
    <xsl:for-each select="@*"><xsl:copy /></xsl:for-each>
    <xsl:attribute name="belongs-to"><xsl:apply-templates select=".." mode="eh-belongs-to"/></xsl:attribute>
--no_c_escapes-
   {
   <xsl:value-of select="." />
   }<xsl:text/>
  </xsl:element>
</xsl:template>

<xsl:template match="v:method|v:method-container">
  <xsl:element name="{concat ('v:', replace (local-name(.), '-container', ''))}">
    <xsl:for-each select="@*"><xsl:copy /></xsl:for-each>
    <xsl:if test="empty(@returns)">
      <xsl:attribute name="returns">any</xsl:attribute>
    </xsl:if>
    <xsl:if test="empty(@arglist)">
      <xsl:attribute name="arglist">inout control vspx_control, inout e vspx_event</xsl:attribute>
    </xsl:if>
--no_c_escapes-
   {
   <xsl:value-of select="." />
   }<xsl:text/>
  </xsl:element>
</xsl:template>

<xsl:template match="text()|comment()|processing-instruction()">
  <xsl:copy/>
</xsl:template>


<!-- mode="eh-belongs-to": finding a name of control that relates to the given event handler -->
<xsl:template match="v:hidden" mode="eh-belongs-to" >
  <xsl:apply-templates select=".." mode="eh-belongs-to"/>
</xsl:template>

<xsl:template match="*" mode="eh-belongs-to" >
  <xsl:choose>
    <xsl:when test="@name and v:vcc_exists (name())">
      <xsl:value-of select="@name" />
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates select=".." mode="eh-belongs-to"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="v:*" mode="eh-belongs-to" >
  <xsl:value-of select="@name" />
</xsl:template>

<!--  mode="create_control_name": composing target control name from tag name -->

<xsl:template match="v:node-template" mode="create_control_name">vspx_tree_node</xsl:template>
<xsl:template match="v:leaf-template" mode="create_control_name">vspx_tree_node</xsl:template>
<xsl:template match="v:form[empty (@type) or @type='simple']" mode="create_control_name">vspx_form</xsl:template>
<xsl:template match="v:form" mode="create_control_name">vspx_<xsl:value-of select="@type" />_form</xsl:template>
<xsl:template match="v:button[@action='simple']" mode="create_control_name">vspx_button</xsl:template>
<xsl:template match="v:button[@action='submit']" mode="create_control_name">vspx_submit</xsl:template>
<xsl:template match="v:button" mode="create_control_name">vspx_<xsl:value-of select="@action" />_button</xsl:template>
<xsl:template match="v:template[@type='row']" mode="create_control_name">vspx_row_template</xsl:template>
<xsl:template match="v:template[@type='browse']" mode="create_control_name">vspx_row_template</xsl:template>
<xsl:template match="v:template" mode="create_control_name">vspx_template</xsl:template>
<xsl:template match="v:local-variable" mode="create_control_name">vspx_field_value</xsl:template>
<xsl:template match="v:*" mode="create_control_name">vspx_<xsl:value-of select="translate (local-name (),'-','_')" /></xsl:template>

<!-- search for invalid combinations of attributes -->

<xsl:template match="v:*[@element-path][not(@element-value)]" mode="attr-check">
  <xsl:call-template name="report-bug"><xsl:with-param name="bug">'element-path' attribute without 'element-value' attribute</xsl:with-param></xsl:call-template>
</xsl:template>

<xsl:template match="v:*[@element-update-path][not(@element-value)]" mode="attr-check">
  <xsl:call-template name="report-bug"><xsl:with-param name="bug">'element-update-path' attribute without 'element-value' attribute</xsl:with-param></xsl:call-template>
</xsl:template>

<xsl:template match="v:*[@element-place][not(@element-value)]" mode="attr-check">
  <xsl:call-template name="report-bug"><xsl:with-param name="bug">'element-place' attribute without 'element-value' attribute</xsl:with-param></xsl:call-template>
</xsl:template>

<xsl:template match="v:*[@element-params][not(@element-path)]" mode="attr-check">
  <xsl:call-template name="report-bug"><xsl:with-param name="bug">'element-params' attribute without 'element-path' attribute</xsl:with-param></xsl:call-template>
</xsl:template>

<xsl:template match="v:*[@element-update-params][not(@element-path)]" mode="attr-check">
  <xsl:call-template name="report-bug"><xsl:with-param name="bug">'element-update-params' attribute without 'element-update-path' attribute</xsl:with-param></xsl:call-template>
</xsl:template>

<xsl:template match="v:check-box[@true-value][not(@is-boolean='true' or @is-boolean='1')]" mode="attr-check">
  <xsl:call-template name="report-bug"><xsl:with-param name="bug">'true-value' attribute that is useless because 'is-boolean' attribute is not set to 'true'</xsl:with-param></xsl:call-template>
</xsl:template>

<xsl:template match="v:check-box[@false-value][not(@is-boolean='true' or @is-boolean='1')]" mode="attr-check">
  <xsl:call-template name="report-bug"><xsl:with-param name="bug">'false-value' attribute that is useless because 'is-boolean' attribute is not set to 'true'</xsl:with-param></xsl:call-template>
</xsl:template>

<xsl:template match="v:validator[@regexp][not(@test='regexp')]" mode="attr-check">
  <xsl:call-template name="report-bug"><xsl:with-param name="bug">'regexp' attribute that is useless because 'test' attribute is not set to 'regexp'</xsl:with-param></xsl:call-template>
</xsl:template>

<xsl:template match="v:validator[@min][not(@test='value' or @test='length')]" mode="attr-check">
  <xsl:call-template name="report-bug"><xsl:with-param name="bug">'min' attribute that is useless because 'test' attribute is not set to 'value' or 'length'</xsl:with-param></xsl:call-template>
</xsl:template>

<xsl:template match="v:validator[@max][not(@test='value' or @test='length')]" mode="attr-check">
  <xsl:call-template name="report-bug"><xsl:with-param name="bug">'max' attribute that is useless because 'test' attribute is not set to 'value' or 'length'</xsl:with-param></xsl:call-template>
</xsl:template>

<xsl:template match="v:button[@child-window-options][not(@action='browse')]" mode="attr-check">
  <xsl:call-template name="report-bug"><xsl:with-param name="bug">'child-window-options' attribute that is useless because 'action' attribute is not set to 'browse'</xsl:with-param></xsl:call-template>
</xsl:template>

<xsl:template match="v:button[@browser-current][not(@action='browse')]" mode="attr-check">
  <xsl:call-template name="report-bug"><xsl:with-param name="bug">'browser-current' attribute that is useless because 'action' attribute is not set to 'browse'</xsl:with-param></xsl:call-template>
</xsl:template>

<xsl:template match="v:button[@browser-filter][not(@action='browse')]" mode="attr-check">
  <xsl:call-template name="report-bug"><xsl:with-param name="bug">'browser-filter' attribute that is useless because 'action' attribute is not set to 'browse'</xsl:with-param></xsl:call-template>
</xsl:template>

<xsl:template match="v:button[@browser-list][not(@action='browse')]" mode="attr-check">
  <xsl:call-template name="report-bug"><xsl:with-param name="bug">'browser-list' attribute that is useless because 'action' attribute is not set to 'browse'</xsl:with-param></xsl:call-template>
</xsl:template>

<xsl:template match="v:button[@browser-mode][not(@action='browse')]" mode="attr-check">
  <xsl:call-template name="report-bug"><xsl:with-param name="bug">'browser-mode' attribute that is useless because 'action' attribute is not set to 'browse'</xsl:with-param></xsl:call-template>
</xsl:template>

<xsl:template match="v:button[@browser-type][not(@action='browse')]" mode="attr-check">
  <xsl:call-template name="report-bug"><xsl:with-param name="bug">'browser-type' attribute that is useless because 'action' attribute is not set to 'browse'</xsl:with-param></xsl:call-template>
</xsl:template>

<xsl:template match="v:button[@browser-xfer][not(@action='browse')]" mode="attr-check">
  <xsl:call-template name="report-bug"><xsl:with-param name="bug">'browser-xfer' attribute that is useless because 'action' attribute is not set to 'browse'</xsl:with-param></xsl:call-template>
</xsl:template>

<xsl:template match="v:button[@selector][not(@action='browse')]" mode="attr-check">
  <xsl:call-template name="report-bug"><xsl:with-param name="bug">'selector' attribute that is useless because 'action' attribute is not set to 'browse'</xsl:with-param></xsl:call-template>
</xsl:template>


<xsl:template match="*" mode="attr-check"></xsl:template>

<xsl:template name="report-bug">
  <xsl:message terminate="yes">
    <xsl:text>The VSPX control</xsl:text>
    <xsl:if test="@name"> '<xsl:value-of select="@name"/>'</xsl:if>
    <xsl:text>of type '</xsl:text><xsl:value-of select="local-name()"/><xsl:text>'</xsl:text>
    <xsl:if test="@debug-srcfile"> (at line <xsl:value-of select="@debug-srcline"/> of '<xsl:value-of select="@debug-srcfile"/>')</xsl:if>
    <xsl:text> has </xsl:text><xsl:value-of select="$bug"/>
  </xsl:message>
</xsl:template>

</xsl:stylesheet>
