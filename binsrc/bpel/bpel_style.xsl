<?xml version="1.0" encoding="ISO-8859-1" ?>
<!-- <!DOCTYPE html  PUBLIC "" "ent.dtd"> -->
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2012 OpenLink Software
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
     xmlns:v="http://www.openlinksw.com/vspx/"
     xmlns:xhtml="http://www.w3.org/1999/xhtml"
     xmlns:vm="http://www.openlinksw.com/vspx/macro">

<!--<xsl:include href="form.xsl"/>

<xsl:include href="dav_browser.xsl"/>-->

<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>

<xsl:variable name="page_title" select="string (//vm:pagetitle)" />

<xsl:template match="head/title[string(.)='']" priority="100">
  <title><xsl:value-of select="$page_title" /></title>
</xsl:template>


<xsl:template match="head/title">
  <title><xsl:value-of select="replace(string(.),'!page_title!',$page_title)" /></title>
</xsl:template>

<xsl:template match="vm:pagetitle" />

<xsl:template match="v:page[not @style and not @on-error-redirect][@name != 'error_page']">
  <xsl:copy>
    <xsl:copy-of select="@*"/>
    <xsl:attribute name="on-error-redirect">error.vspx</xsl:attribute>
    <xsl:if test="not (@on-deadlock-retry)">
      <xsl:attribute name="on-deadlock-retry">3</xsl:attribute>
    </xsl:if>
    <xsl:apply-templates />
  </xsl:copy>
</xsl:template>

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
  <div class="copyright">Virtuoso Universal Server <?V sys_stat('st_dbms_ver') ?>. Copyright &amp;copy; 1998-<?V "LEFT" (datestring (now()), 4)?> OpenLink Software</div>
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
      <div class="page_head">
        <table width="100%"  border="0" cellpadding="0" cellspacing="0" class="page_head">
          <tr>
            <td><img src="i/bpelheader350.jpg" alt="" name="" width="350" height="75"/></td>
            <td nowrap="1">
              <v:include url="bpel_login.vspx"/>
            </td>
          </tr>
        </table>
      </div>
      <table id="MT" width="100%">
        <tbody>
          <tr>
            <td id="LB" width="10%" class="left_nav" valign="top">
              <table id="NT" width="100%">
                <tbody>
                  <tr>
                    <td>
                      <table class="lnav_container">
                        <tr><td><img src="i/vglobe_16.png" alt="Start" title="Start Menu" /><a href="/">Virtuoso Start Menu</a></td></tr>
                        <tr><td><a href="/BPELGUI/start.vsp" target="_blank">QuickStart</a></td></tr>
                        <tr><td><a href="/doc/docs.vsp">Check<br>Documentation</br></a></td></tr>
                        <tr><td><a href="/BPELDemo/">Virtuoso BPEL Tutorials</a></td></tr>
                        <tr><td class="system_info">&nbsp;</td></tr>
                        <tr><td class="system_info">&nbsp;</td></tr>
                        <tr><td class="system_info"><a href="http://www.openlinksw.com">OpenLink Software</a></td></tr>
                        <tr><td class="system_info"><a href="http://www.openlinksw.com/virtuoso">Virtuoso Web Site</a></td></tr>
                        <tr><td class="system_info">Server version: <?V sys_stat('st_dbms_ver') ?></td></tr>
                        <tr><td class="system_info">Server build: <?V sys_stat('st_build_date') ?></td></tr>
                        <tr><td class="system_info">BPEL4WS version: <?V registry_get('_bpel4ws_version_') ?></td></tr>
                        <tr><td class="system_info">BPEL4WS build date: <?V registry_get('_bpel4ws_build_') ?></td></tr>
                        <tr><td class="system_info"><a href="http://www.openlinksw.com/virtuoso"><img alt="Powered by OpenLink Virtuoso Universal Server" src="i/PoweredByVirtuoso.gif" border="0" /></a></td></tr>
                      </table>
                    </td>
                  </tr>
              </tbody>
              </table>
            </td>
            <td id="RT" width="90%" valign="top">
              <table width="100%">
                <tr>
                  <td><!-- The top menu component -->
                    <v:include url="bpel_navigation_bar.vspx"/>
                  </td>
                </tr>
                <tr>
                  <td id="RB" width="90%" valign="top" border="0" cellspacing="0" cellpadding="0">
                    <table id="DT" width="100%" border="0" cellspacing="0" cellpadding="0">
                      <tr class="subpage_header_area">
                        <xsl:apply-templates select="vm:header"/>
                        <xsl:apply-templates select="vm:rawheader"/>
                        &lt;?vsp if (atoi (cfg_item_value (virtuoso_ini_path(), 'HTTPServer', 'ServerThreads')) &lt; 2) { ?&gt;
                          <td><font color="Red">
                        &lt;?vsp http_value('Warning: Only 1 thread allocated for web services.  The BPEL user interface will not be operational'); ?&gt;
                          </font></td>
                        &lt;?vsp } ?&gt;
                      </tr>
                    </table>
                  </td>
                </tr>
                <tr class="main_page_area">
                  <td>
                    <xsl:apply-templates select="vm:pagebody"/>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </tbody>
      </table>
      <!--Virtuoso Universal Server <?V sys_stat('st_dbms_ver') ?>. -->
      <div class="copyright">Copyright &amp;copy; 1999-<?V "LEFT" (datestring (now()), 4)?> OpenLink Software</div>
      <xsl:processing-instruction name="vsp">
		declare ht_stat varchar;
		ht_stat := http_request_status_get ();
		if (ht_stat is not null and ht_stat like 'HTTP/1._ 30_ %')
		  {
		    http_rewrite ();
		  }
	 </xsl:processing-instruction>
</xsl:template>

<xsl:template match="vm:menu">
  <xsl:processing-instruction name="vsp"> if (self.nav_pos_fixed) { </xsl:processing-instruction>
   <xsl:for-each select="vm:menuitem">
      <tr><td class="SubInfo">
         <xsl:choose>
            <xsl:when test="@type='hot' or @url">
                <v:url format="%s">
                   <xsl:copy-of select="@name" />
                   <xsl:attribute name="value">--'<xsl:value-of select="@value"/>'</xsl:attribute>
                   <xsl:attribute name="url">--'<xsl:value-of select="@url"/>'</xsl:attribute>
                 </v:url>
            </xsl:when>
            <xsl:when test="@ref">
                <v:url format="%s">
                   <xsl:copy-of select="@name" />
                   <xsl:attribute name="value">--'<xsl:value-of select="@value"/>'</xsl:attribute>
                   <xsl:attribute name="url">--<xsl:value-of select="@ref"/></xsl:attribute>
                 </v:url>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="@value"/>
            </xsl:otherwise>
         </xsl:choose>
       </td></tr>
    </xsl:for-each>
  &lt;?vsp } else { ?&gt;
      <tr><td class="SubInfo">
       &lt;?vsp http (coalesce (self.nav_tip, '')); ?&gt;
       </td></tr>
  &lt;?vsp } ?&gt;
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
      &lt;?vsp if (self.nav_pos_fixed) { ?&gt;
      <xsl:apply-templates select="node()|processing-instruction()" />
      &lt;?vsp } ?&gt;
     </v:url>
</xsl:template>



<xsl:template match="vm:rawheader">
  &lt;?vsp if (self.nav_pos_fixed) { ?&gt;
  <xsl:apply-templates select="node()|processing-instruction()" />
  &lt;?vsp } ?&gt;
</xsl:template>
<xsl:template match="vm:raw">
  &lt;?vsp if (self.nav_pos_fixed) { ?&gt;
  <xsl:apply-templates select="node()|processing-instruction()" />
  &lt;?vsp } ?&gt;
</xsl:template>

<xsl:template match="vm:pagebody">
  &lt;?vsp if (self.nav_pos_fixed) { ?&gt;
  <xsl:choose>
    <xsl:when test="@url">
      <v:template name="vm_pagebody_include_url" type="simple">
        <v:include url="{@url}"/>
      </v:template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates select="node()|processing-instruction()" />
    </xsl:otherwise>
  </xsl:choose>
  &lt;?vsp } else { ?&gt;
  <table id="content">
    <tr>
      <td>
        <v:template name="vm_pagebody_splash" type="simple">
          <v:include url="virtuoso_splash.vspx"/>
        </v:template>
      </td>
    </tr>
  </table>
  &lt;?vsp } ?&gt;
</xsl:template>

<!-- The rest is from page.xsl -->

<xsl:template match="vm:header">
<xsl:if test="@caption">
  &lt;?vsp if (self.nav_pos_fixed) { ?&gt;
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

<xsl:template match="vm:ds-navigation">
  &lt;?vsp
     {
        declare _prev, _next, _last, _first vspx_button;
	declare d_prev, d_next, d_last, d_first int;

	d_prev := d_next := d_last := d_first := 0;
	_first := control.vc_find_control ('<xsl:value-of select="@data-set"/>_first');
	_last := control.vc_find_control ('<xsl:value-of select="@data-set"/>_last');
	_next := control.vc_find_control ('<xsl:value-of select="@data-set"/>_next');
	_prev := control.vc_find_control ('<xsl:value-of select="@data-set"/>_prev');

	if (_next is not null and not _next.vc_enabled and _prev is not null and not _prev.vc_enabled)
	  goto skipit;

        if (_first is not null and not _first.vc_enabled)
	  {
	    d_first := 1;
	  }
        if (_next is not null and not _next.vc_enabled)
	  {
	    d_next := 1;
	  }
        if (_prev is not null and not _prev.vc_enabled)
	  {
	    d_prev := 1;
	  }
        if (_last is not null and not _last.vc_enabled)
	  {
	    d_last := 1;
	  }
      skipit:;
  ?&gt;
  <xsl:if test="not(@type) or @type = 'set'">
  <?vsp
    if (d_first)
    {
      http ('<img src="i/first_16.png" alt="First" title="First" border="0" />&#160;First');
    }
  ?>
  <v:button name="{@data-set}_first" action="simple" style="image" value="i/first_16.png"
      xhtml_alt="First" xhtml_title="First" text="&#160;First">
  </v:button>
      &#160;
  </xsl:if>
  <?vsp
    if (d_prev)
    {
      http ('<img src="i/previous_16.png" alt="Previous" title="Previous" border="0" />&#160;Previous');
    }
  ?>
  <v:button name="{@data-set}_prev" action="simple" style="image" value="i/previous_16.png"
      xhtml_alt="Previous" xhtml_title="Previous" text="&#160;Previous">
  </v:button>
  &#160;
  <?vsp
    if (d_next)
    {
      http ('<img src="i/next_16.png" alt="Next" title="Next" border="0" />&#160;Next');
    }
  ?>
  <v:button name="{@data-set}_next" action="simple" style="image" value="i/next_16.png"
                                xhtml_alt="Next" xhtml_title="Next" text="&#160;Next">
  </v:button>
  <xsl:if test="not(@type) or @type = 'set'">&#160;
  <?vsp
    if (d_last)
    {
      http ('<img src="i/last_16.png" alt="Last" title="Last" border="0" />&#160;Last');
    }
  ?>
  <v:button name="{@data-set}_last" action="simple" style="image" value="i/last_16.png"
	  xhtml_alt="Last" xhtml_title="Last" text="&#160;Last">
  </v:button>
  </xsl:if>
  <?vsp
    }
  ?>
</xsl:template>
</xsl:stylesheet>
