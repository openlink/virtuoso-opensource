<?xml version="1.0" encoding="ISO-8859-1" ?>
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
<!-- <!DOCTYPE html  PUBLIC "" "ent.dtd"> -->
<!--
  Virtuoso VSPX XSL-T style-sheet for page class compilation
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     version="1.0"
     xmlns:v="http://www.openlinksw.com/vspx/"
     xmlns:xhtml="http://www.w3.org/1999/xhtml"
     xmlns:vm="http://www.openlinksw.com/vspx/macro">

<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>

<xsl:variable name="page_title" select="string (//vm:pagetitle)" />

<xsl:template match="head/title[string(.)='']" priority="100">
  <title><xsl:value-of select="$page_title" /></title>
</xsl:template>


<xsl:template match="head/title">
  <title><xsl:value-of select="replace(string(.),'!page_title!',$page_title)" /></title>
</xsl:template>

<xsl:template match="vm:pagetitle" />

<xsl:template match="vm:popup_page_wrapper">
  <xsl:element name="v:variable">
    <xsl:attribute name="persist">0</xsl:attribute>
    <xsl:attribute name="name">page_owner</xsl:attribute>
    <xsl:attribute name="type">varchar</xsl:attribute>
    <xsl:choose>
      <xsl:when  test="../@vm:owner">
         <xsl:attribute name="default">'<xsl:value-of select="../@vm:owner"/>'</xsl:attribute>
      </xsl:when>
      <xsl:otherwise>
         <xsl:attribute name="default">null</xsl:attribute>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:element>
  <xsl:apply-templates select="node()|processing-instruction()" />
</xsl:template>

<xsl:template match="vm:pagewrapper">
        <xsl:element name="v:variable">
         <xsl:attribute name="persist">0</xsl:attribute>
          <xsl:attribute name="name">page_owner</xsl:attribute>
          <xsl:attribute name="type">varchar</xsl:attribute>
          <xsl:choose>
           <xsl:when  test="../@vm:owner">
             <xsl:attribute name="default">'<xsl:value-of select="../@vm:owner"/>'</xsl:attribute>
           </xsl:when>
           <xsl:otherwise>
             <xsl:attribute name="default">null</xsl:attribute>
           </xsl:otherwise>
          </xsl:choose>
       </xsl:element>
      <xsl:for-each select="//v:variable">
        <xsl:copy-of select="."/>
      </xsl:for-each>

      <xsl:apply-templates select="vm:init"/>
      <v:include url="login.vspx"/>
      <!--      <div class="page_head"><img src="bpel_banner.jpg"/></div> -->
      <div class="vspx_content">
        <xsl:apply-templates select="vm:pagebody"/>
      </div>
      <!--<br/>-->
      <!--<div class="page_head"><img src="images/yac_banner.jpg"/></div>-->
      <!--<table  width="70%" id="fraim">
              <table id="NT">
                  <tr>
                    <td>
                      <v:include url="bpel_login.vspx"/>
                    </td>
                  </tr>
              </table>
              <table  width="90%" align="center" id="fraim">
                 <tr>
                   <td>
                    <v:include url="bpel_navigation_bar.vspx"/>
                    <xsl:apply-templates select="vm:pagebody"/>
                   </td>
                 </tr>
              </table>
         </table>
	 <div class="copyright">Copyright &amp;copy; 1998-2018 OpenLink Software</div>-->
	 <xsl:processing-instruction name="vsp">
		declare ht_stat varchar;
		ht_stat := http_request_status_get ();
		if (ht_stat is not null and ht_stat like 'HTTP/1._ 30_ %')
		  {
		    http_rewrite ();
		  }
	 </xsl:processing-instruction>
</xsl:template>

<xsl:template match="vm:url">
     <v:variable>
      <xsl:attribute name="name"><xsl:value-of select="@name"/>_allowed</xsl:attribute>
      <xsl:attribute name="persist">1</xsl:attribute>
        <xsl:attribute name="type">varchar</xsl:attribute>
        <xsl:attribute name="default">
          <xsl:choose>
        <xsl:when test="@allowed">'<xsl:value-of select="@allowed"/>'</xsl:when>
        <xsl:otherwise>null</xsl:otherwise>
      </xsl:choose>
      </xsl:attribute>
     </v:variable>
     <v:url>
       <xsl:copy-of select="@name" />
       <xsl:copy-of select="@format"/>
       <xsl:copy-of select="@value"/>
        <xsl:copy-of select="@url"/>
      &lt;?vsp if (self.vc_authenticated) { ?&gt;
      <xsl:apply-templates select="node()|processing-instruction()" />
      &lt;?vsp } ?&gt;
     </v:url>
</xsl:template>

<xsl:template match="vm:rawheader">
  &lt;?vsp if (self.vc_authenticated) { ?&gt;
  <xsl:apply-templates select="node()|processing-instruction()" />
  &lt;?vsp } ?&gt;
</xsl:template>
<xsl:template match="vm:raw">
  &lt;?vsp if (self.vc_authenticated) { ?&gt;
  <xsl:apply-templates select="node()|processing-instruction()" />
  &lt;?vsp } ?&gt;
</xsl:template>

<xsl:template match="vm:pagebody">
      <xsl:apply-templates select="node()|processing-instruction()" />
</xsl:template>

<!-- The rest is from page.xsl -->

<xsl:template match="vm:header">
<xsl:if test="@caption">
  &lt;?vsp if (self.vc_authenticated) { ?&gt;
  <td class="page_title"> <!-- <xsl:copy-of select="@class"/> -->
  <xsl:value-of select="@caption"/></td>
  &lt;?vsp } ?&gt;
</xsl:if>
<xsl:apply-templates/>
</xsl:template>

<xsl:template match="vm:init">
    <xsl:apply-templates select="node()|processing-instruction()" />
</xsl:template>

<xsl:template match="vm:caption">
<xsl:value-of select="@fixed"/>
<xsl:apply-templates/>
</xsl:template>

<xsl:template match="vm:controls">
<xsl:apply-templates/>
</xsl:template>

<xsl:template match="vm:control">
<td  class="SubInfo">
  <xsl:apply-templates/>
</td>
</xsl:template>

<xsl:template match="vm:conditional">
&lt;?vsp
<xsl:apply-templates select="check" mode="cond"/>
{ <xsl:apply-templates select="do"/> }
?&gt;
</xsl:template>

<xsl:template match="vm:check" mode="cond">
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

<xsl:template match="vm:do">
  <xsl:apply-templates  mode="cond"/>
</xsl:template>
<xsl:template match="vm:assign" mode="cond">
  self.<xsl:value-of select="@to"/> := <xsl:choose>
    <xsl:when test="@kind='static'"><xsl:if test="@type='string'">'</xsl:if><xsl:value-of select="@what"/><xsl:if test="@type='string'">'</xsl:if>;</xsl:when>
    <xsl:when test="@kind='dynamic'">get_keyword('<xsl:value-of select="@what"/>',params);</xsl:when></xsl:choose>
</xsl:template>
<xsl:template match="vm:unconditional">
<xsl:apply-templates mode="uncond"/>
</xsl:template>

<xsl:template match="vm:comments" mode="uncond">
<xsl:choose>
  <xsl:when test="@class">
    <xsl:text>&#x20;</xsl:text><span class="{@class}"><xsl:value-of select="@value"/></span><xsl:text>&#x20;</xsl:text>
  </xsl:when>
        <xsl:otherwise>
    <xsl:text>&#x20;</xsl:text><xsl:value-of select="@value"/><xsl:text>&#x20;</xsl:text>
      </xsl:otherwise>
</xsl:choose>
</xsl:template>

<xsl:template match="vm:reference" mode="uncond">
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

<xsl:template match="vm:comments" mode="cond">
<xsl:choose>
  <xsl:when test="@class">
    http('<xsl:text>&#x20;</xsl:text><span class="{@class}"><xsl:value-of select="@value"/></span><xsl:text>&#x20;</xsl:text>');
  </xsl:when>
        <xsl:otherwise>
    http('<xsl:text>&#x20;</xsl:text><xsl:value-of select="@value"/><xsl:text>&#x20;</xsl:text>');
      </xsl:otherwise>
</xsl:choose>
</xsl:template>



<xsl:template match="vm:reference" mode="cond">
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

<xsl:template match="vm:compose" mode="cond">
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

