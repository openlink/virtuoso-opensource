<?xml version="1.0" encoding="UTF-8"?>
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
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:v="http://www.openlinksw.com/vspx/" xmlns:xhtml="http://www.w3.org/1999/xhtml">
<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>

<xsl:template match="/">
<xsl:apply-templates/>
</xsl:template>
<xsl:template match="v:page">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <link rel="stylesheet" href="yacutia_style.css" type="text/css"/>
      <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
      <title><xsl:value-of select="@title"/></title>
  </head>
  <body>
    <v:page name="{@name}" xmlns:v="http://www.openlinksw.com/vspx/" xmlns:xhtml="http://www.w3.org/1999/xhtml">
      <v:error-summary/>
      <xsl:apply-templates select="variables"/>
      <xsl:apply-templates select="init"/>
      <table id="MT" width="100%" border="0" cellspacing="0" cellpadding="0">
        <tbody>
          <tr>
            <td id="LT" align="center" valign="middle">
              <!--Here is the Virtuoso logo image-->
              <img src="images/virtuosologo.png" width="120" height="32"/>
            </td>
            <td id="RT" valign="top">
              <!-- Here is the top menu component (it seems that name of the  file in URL attribute  mislead us, but this is actually TOP menu component )-->
              <v:include url="adm_navigation_bar.vspx"/>
            </td>
          </tr>
          <tr>
            <td id="LB" width="10%"  valign="top" class="LeftNav">
              <table id="NT" width="100%" border="0" cellspacing="5" cellpadding="0">
                <tbody>
                  <v:include url="adm_login.vspx"/>
                   <tr> <!-- this below is the navigation left  menu bar-->
                      <td valign="top">
                     <table width="100%" border="1" cellspacing="0" cellpadding="5" bordercolordark="#5496B9" bordercolorlight="6CA5C3">
                                <tr class="NavBG">
                           <td valign="top">
                                              <table width="98%" border="2" cellspacing="0" cellpadding="5" bordercolor="#00A0DD">
                                              <xsl:apply-templates select="menu"/>
                                               </table>
                                   </td>
                                </tr>
                                <tr class="SearchLink"><td>Search</td></tr>
                                <tr class="NavBG"><td class="SubInfo"><a href="/doc/docs.vsp">Check<br>Documentation</br></a></td></tr>
                                <tr class="NavBG"><td class="SubInfo"><a href="/tutorial/index.vsp">Try Tutorials</a></td></tr>
                                <tr class="NavBG"><td class="SubInfo"><v:browse-button style="url" name="browse_button1" value="Run ISQL" selector="isql.vspx" child-window-options="scrollbars=yes,resizable=no,menubar=no,height=480,width=640"/></td></tr>
                                <tr class="NavBG"><td class="SubInfo"><v:browse-button style="url" name="browse_button2" value="Run DAV" action="browse" selector="/vspx/browser/dav_browser.vsp" child-window-options="resizable=yes, status=no, menubar=no, scrollbars=no, width=640, height=400" browser-type="dav" browser-mode="RES1" browser-xfer="DOM" browser-list="1" browser-current="1" browser-filter="*" super-mode="view"/></td></tr>
			        <tr><td class="Advice">Version: <?V sys_stat('st_dbms_ver') ?></td></tr>
			        <tr><td class="Advice">Build: <?V sys_stat('st_build_date') ?></td></tr>
                        </table>
                    </td>
                     </tr>
                </tbody>
              </table>
            </td>
            <td id="RB"  align="center" valign="top" >
              <table id="DT" width="100%" border="0" cellspacing="0" cellpadding="5">
                <tr>
                  <td>
                      <table width="100%" border="0" cellspacing="0" cellpadding="0">
                          <tr><xsl:apply-templates select="header"/></tr>
                        </table>
                  </td>
                </tr>
                <tr valign="top">
                  <td align="center">
                    <v:include url="{@content}"/>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </tbody>
      </table>
    </v:page>
  </body>
</html>
</xsl:template>
<xsl:template match="menu">
  <xsl:for-each select="item">
              <tr><td class="SubInfo">
             <xsl:choose>
                <xsl:when test="@type='hot'">
                  <v:url name="{@name}" value="--'{@value}'" format="%s" url="--'{@url}'"/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:value-of select="@value"/>
               </xsl:otherwise>
               </xsl:choose>
    </td></tr>
       </xsl:for-each>
</xsl:template>
<xsl:template match="variables">
  <xsl:for-each select="variable">
      <v:variable persist="{@persist}" name="{@name}"  type="{@type}" default="{@default}"/>
  </xsl:for-each>
</xsl:template>
<xsl:template match="init">
<xsl:apply-templates/>
</xsl:template>


<xsl:template match="header">
<td><xsl:apply-templates select="caption"/></td>
<xsl:apply-templates select="controls"/>
</xsl:template>

<xsl:template match="caption">
<xsl:value-of select="@fixed"/>
<xsl:apply-templates/>
</xsl:template>

<xsl:template match="controls">
<xsl:apply-templates/>
</xsl:template>

<xsl:template match="control">
<td  class="SubInfo">
  <xsl:apply-templates/>
</td>
</xsl:template>

<xsl:template match="conditional">
&lt;?vsp
<xsl:apply-templates select="check" mode="cond"/>
{ <xsl:apply-templates select="do"/> }
?&gt;
</xsl:template>

<xsl:template match="check" mode="cond">
 if ( <xsl:choose>
  <xsl:when test="what/@kind='variable'">self.<xsl:value-of select="what/@value"/></xsl:when>
  <xsl:when test="what/@kind='dynamic'">get_keyword('<xsl:value-of select="what/@value"/>',params)</xsl:when>
</xsl:choose><xsl:value-of select="@relation"/>
<xsl:choose>
  <xsl:when test="with/@kind='variable'">self.<xsl:value-of select="with/@value"/></xsl:when>
  <xsl:when test="with/@kind='dynamic'">get_keyword('<xsl:value-of select="with/@value"/>',params)</xsl:when>
  <xsl:when test="with/@kind='static'"><xsl:if test="with/@type='string'">'</xsl:if><xsl:value-of select="with/@value"/><xsl:if test="with/@type='string'">'</xsl:if></xsl:when>
</xsl:choose>)
</xsl:template>

<xsl:template match="do">
  <xsl:apply-templates  mode="cond"/>
</xsl:template>
<xsl:template match="assign" mode="cond">
  self.<xsl:value-of select="@to"/> := <xsl:choose>
    <xsl:when test="@kind='static'"><xsl:if test="@type='string'">'</xsl:if><xsl:value-of select="@what"/><xsl:if test="@type='string'">'</xsl:if>;</xsl:when>
    <xsl:when test="@kind='dynamic'">get_keyword('<xsl:value-of select="@what"/>',params);</xsl:when></xsl:choose>
</xsl:template>
<xsl:template match="unconditional">
<xsl:apply-templates mode="uncond"/>
</xsl:template>

<xsl:template match="comments" mode="uncond">
<xsl:choose>
  <xsl:when test="@class">
    <xsl:text>&#x20;</xsl:text><span class="{@class}">&nbsp;<xsl:value-of select="@value"/></span><xsl:text>&#x20;</xsl:text>
  </xsl:when>
        <xsl:otherwise>
    <xsl:text>&#x20;</xsl:text><xsl:value-of select="@value"/><xsl:text>&#x20;</xsl:text>
      </xsl:otherwise>
</xsl:choose>
</xsl:template>

<xsl:template match="reference" mode="uncond">
<xsl:element name="v:url">
<xsl:attribute name="name"><xsl:value-of select="@name"/></xsl:attribute>
<xsl:attribute name="value">--'<xsl:value-of select="@value"/>'</xsl:attribute>
<xsl:attribute name="format">%s</xsl:attribute>
<xsl:attribute name="url">--sprintf('<xsl:value-of select="@url"/><xsl:if test="count(param) > 0">?<xsl:for-each select="param"><xsl:value-of select="@name"/>=%<xsl:choose><xsl:when test="@type='string'">s</xsl:when><xsl:when test="@type='number'">d</xsl:when></xsl:choose><xsl:if test="position() != last()"><xsl:text>&#x26;</xsl:text></xsl:if></xsl:for-each>'</xsl:if><xsl:if test="count(param) > 0">,<xsl:for-each select="param">
<xsl:choose>
  <xsl:when test="@kind='static'"><xsl:if test="@type='string'">'</xsl:if><xsl:value-of select="@value"/><xsl:if test="@type='string'">'</xsl:if></xsl:when>
  <xsl:when test="@kind='dynamic'">get_keyword('<xsl:value-of select="@value"/>',params)</xsl:when>
  <xsl:when test="@kind='variable'">self.<xsl:value-of select="@value"/></xsl:when>
</xsl:choose>
<xsl:if test="position() != last()">,</xsl:if></xsl:for-each></xsl:if>)</xsl:attribute>
</xsl:element>
</xsl:template>

<xsl:template match="comments" mode="cond">
<xsl:choose>
  <xsl:when test="@class">
    http('<xsl:text>&#x20;</xsl:text><span class="{@class}">&nbsp;<xsl:value-of select="@value"/></span><xsl:text>&#x20;</xsl:text>');
  </xsl:when>
        <xsl:otherwise>
    http('<xsl:text>&#x20;</xsl:text><xsl:value-of select="@value"/><xsl:text>&#x20;</xsl:text>');
      </xsl:otherwise>
</xsl:choose>
</xsl:template>



<xsl:template match="reference" mode="cond">
http('&lt;a href="');
http(sprintf('<xsl:value-of select="@url"/>?sid=%s&amp;realm=%s<xsl:if test="count(param) > 0">&amp;<xsl:for-each select="param"><xsl:value-of select="@name"/>=%<xsl:choose><xsl:when test="@type='string'">s</xsl:when><xsl:when test="@type='number'">d</xsl:when></xsl:choose><xsl:if test="position() != last()"><xsl:text>&#x26;</xsl:text></xsl:if></xsl:for-each>',self.sid,self.realm</xsl:if><xsl:if test="count(param) > 0">,<xsl:for-each select="param">
<xsl:choose>
  <xsl:when test="@kind='static'"><xsl:if test="@type='string'">'</xsl:if><xsl:value-of select="@value"/><xsl:if test="@type='string'">'</xsl:if></xsl:when>
  <xsl:when test="@kind='dynamic'">get_keyword('<xsl:value-of select="@value"/>',params)</xsl:when>
  <xsl:when test="@kind='variable'">self.<xsl:value-of select="@value"/></xsl:when>
</xsl:choose>
<xsl:if test="position() != last()">,</xsl:if></xsl:for-each></xsl:if>));
http('"&gt;<xsl:value-of select="@value"/>&lt;/a&gt;');
</xsl:template>

<xsl:template match="compose" mode="cond">
<xsl:if test="count(text) > 0">
http(sprintf('<xsl:for-each select="text">
<xsl:choose>
  <xsl:when test="@type='string'">%s</xsl:when>
  <xsl:when test="@type='integer'">%d</xsl:when>
</xsl:choose>
<xsl:if test="position() != last()"><xsl:text>&#x20;</xsl:text></xsl:if>
</xsl:for-each>',<xsl:for-each select="text">
<xsl:choose>
  <xsl:when test="@kind='static'"><xsl:if test="@type='string'">'</xsl:if><xsl:value-of select="@value"/><xsl:if test="@type='string'">'</xsl:if></xsl:when>
  <xsl:when test="@kind='dynamic'">get_keyword('<xsl:value-of select="@value"/>',params)</xsl:when>
  <xsl:when test="@kind='variable'">self.<xsl:value-of select="@value"/></xsl:when>
</xsl:choose>
<xsl:if test="position() != last()">,</xsl:if></xsl:for-each>
));</xsl:if>
</xsl:template>
</xsl:stylesheet>
