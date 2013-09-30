<?xml version="1.0" encoding="UTF-8" ?>
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
<!--
  Virtuoso Conductor XSL style-sheet for page macros
  (C)Copyright 2005-2013 OpenLink Software
-->
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:v="http://www.openlinksw.com/vspx/"
                xmlns:xhtml="http://www.w3.org/1999/xhtml"
                xmlns:vm="http://www.openlinksw.com/vspx/macro">

<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>

<xsl:include href="form.xsl"/>
<xsl:include href="dav/dav_browser.xsl"/>
<xsl:include href="file_browser.xsl"/>

<xsl:variable name="page_title" select="string (//vm:pagetitle)" />
<xsl:variable name="pagebody_attrs" select="//vm:pagebody/@*"/>
<xsl:variable name="page_scripts" select="//vm:scripts/processing-instruction()|//vm:scripts/*"/>

<xsl:template match="head/title[string(.)='']" priority="100">
  <title><xsl:value-of select="$page_title" /></title>
  <xsl:copy-of select="$page_scripts"/>
</xsl:template>

<xsl:template match="body[not @*]">
  <body>
    <xsl:for-each select="$pagebody_attrs">
      <xsl:copy-of select="."/>
    </xsl:for-each>
    <xsl:apply-templates />
  </body>
</xsl:template>

<xsl:template match="head/title">
  <title><xsl:value-of select="replace(string(.),'!page_title!',$page_title)" /></title>
</xsl:template>

<xsl:template match="vm:pagetitle" />

<xsl:template match="v:page[not @style and not @on-error-redirect][@name != 'error_page']">
    <xsl:copy>
	<xsl:copy-of select="@*"/>
	<xsl:attribute name="on-error-redirect">error.vspx</xsl:attribute>
	<!--xsl:attribute name="xml-preamble">yes</xsl:attribute-->
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
      <xsl:when test="../@vm:owner">
         <xsl:attribute name="default">'<xsl:value-of select="../@vm:owner"/>'</xsl:attribute>
      </xsl:when>
      <xsl:otherwise>
         <xsl:attribute name="default">null</xsl:attribute>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:element>
  <xsl:apply-templates select="node()|processing-instruction()" />
  <div id="copyright_ctr">Copyright &amp;copy; 1998-<?V "LEFT" (datestring (now()), 4) ?> OpenLink Software</div>
</xsl:template>

<xsl:template match="vm:pagewrapper">
  <v:variable name="page_owner" persist="0" type="varchar">
      <xsl:attribute name="default">
	  <xsl:choose>
	      <xsl:when  test="../@vm:owner">'<xsl:value-of select="../@vm:owner"/>'</xsl:when>
	      <xsl:otherwise>null</xsl:otherwise>
	  </xsl:choose>
      </xsl:attribute>
  </v:variable>
  <v:variable name="nav_pos_fixed" type="int" default="0"/>
  <v:variable name="nav_top" type="int" default="0"/>
  <v:variable name="nav_tip" type="varchar" default="''"/>
  <v:variable name="btn_bmk" type="varchar" default="null" />
  <xsl:for-each select="//v:variable">
    <xsl:copy-of select="."/>
  </xsl:for-each>

  <xsl:apply-templates select="vm:init"/>
  <table id="MTB" cellspacing="0" cellpadding="0" width="100%">
    <tr id="MB2">
      <td colspan="2" align="left">
	<table width="100%" border="0" cellpadding="0" cellspacing="0">
	  <tr>
	    <td align="left"><img src="images/con_banner.gif" border="0"/></td>
	    <td width="80%" align="left">
		<div class="login_info">
		<img src="images/icons/user_16.png" />
	      <?vsp if (connection_get ('vspx_user') is not null) { ?>
	       logged in as <?V connection_get ('vspx_user') ?> |
	      <v:url value="Log out" url="main_tabs.vspx?logout=1"/>
	      <?vsp } else { ?>
	      not logged in
	      <?vsp
	      }?>&amp;nbsp;|&amp;nbsp;<img src="images/vglobe_16.png" alt="Start" title="Start Menu" hspace="2" /><a href="/">Home</a>
	       </div>
	    </td>
	  </tr>
	</table>
      </td>
      </tr>
    <tr id="MT">
     <td id="LC" style="white-space: nowrap;">
      <v:include name="loginp" url="adm_login.vspx"/>
      <!--div class="lmenu_ctr">
        &amp;nbsp;
        <xsl:apply-templates select="vm:menu"/>
      </div-->
      <ul class="left_toolbox">
        <li>
          <img src="images/icons/apps_16.png"
               alt="ISQL"
               title="Interactive SQL popup"/>
          <v:browse-button style="url" name="browse_button1" value="Interactive  SQL (ISQL)" selector="isql.vspx"
              child-window-options="scrollbars=yes,resizable=yes,status=no,menubar=no,height=600,width=800"/>
        </li>
        <?vsp
  if (connection_get ('vspx_user') is not null)
    {
        ?>
        <li>
          <img src="images/icons/foldr_16.png"
               alt="WebDAV browser"
               title="WebDAV browser"/>
          <vm:dav_browser ses_type="yacutia"
                          render="popup"
                          list_type="details"
                          flt="yes"
                          flt_pat=""
                          path="DAV"
                          browse_type="standalone"
                          style_css="test.css"
                          w_title="WebDAV Repository"
                          title="WebDAV Repository"
                          advisory="mega advisory text"
                          lang="en" />
        </li>
          <?vsp
	  }
	  if (vad_check_version ('Framework') is not null)
	  {
          ?>
	  <li><img src="images/vglobe_16.png" alt="WA" title="Data Space Applications" /><a href="<?V wa_link () ?>">OpenLink Data Spaces</a>
	  </li>
	  <?vsp
	  }
          ?>
	  <li><img src="images/vglobe_16.png" alt="Start" title="Start Menu" /><a href="/">Virtuoso Start Menu</a>
	  </li>
      </ul>
      <ul class="left_nav">
	<li>
          <img src="images/icons/docs_16.png"
               alt="Documentation"
               title="Documentation" hspace="2"/>

          <?vsp
	  if (vad_check_version ('doc') is not null)
	  {
          ?>
	  <a href="/doc/html/" target="_top">Documentation<small> (local)</small></a>
	  <?vsp
	  }
          else
          {
          ?>
          <a href="http://docs.openlinksw.com/virtuoso/" target="_top">Documentation<small> (web)</small></a>
          <?vsp
	  }
          ?>
        </li>
        <!--<a href="/doc/docs.vsp" target="_top">Documentation</a>-->
	<li>
          <img src="images/icons/tour_16.png"
               alt="Tutorials"
               title="Tutorials" hspace="2"/>
	  <!--<a href="/tutorial/index.vsp" target="_top">Tutorials</a></li>-->
          <?vsp
	  if (vad_check_version ('tutorial') is not null)
	  {
          ?>
	  <a href="/tutorial/" target="_top">Tutorials<small> (local)</small></a>
	  <?vsp
	  }
          else
          {
          ?>
          <a href="http://demo.openlinksw.com/tutorial/" target="_top">Tutorials<small> (web)</small></a>
          <?vsp
	  }
          ?>
	</li>
      </ul>
      <ul class="left_nav">
	<li class="xtern">
          <img src="images/icons/web_16.png"
               alt="Virtuoso Web Site"
               title="Virtuoso Web Site" hspace="2"/>
	    <a href="http://virtuoso.openlinksw.com/">Virtuoso Web Site</a></li>
	<li class="xtern">
          <img src="images/icons/web_16.png"
               alt="OpenLink Software"
               title="OpenLink Software" hspace="2"/>
	    <a href="http://www.openlinksw.com">OpenLink Software</a></li>
      </ul>
      <ul class="left_id">
        <li>Version: <?V sys_stat ('st_dbms_ver') ?></li>
        <li>Build: <?V sys_stat ('st_build_date') ?></li>
      </ul>
    </td> <!-- LC -->
    <td id="RC">
      <table id="RTB">
      <tr>
	<td id="RT">
	  <v:vscx name="navbar1" url="adm_navigation_bar.vspx" />
	</td>
      </tr>
      <tr>
	<td id="RB"> <!-- Bread and butter zone -->
	  <div class="subpage_header_area">
	    <xsl:apply-templates select="vm:header" />
	    <xsl:apply-templates select="vm:rawheader" />
	    <v:template type="simple" condition="not self.vc_is_valid">
	      <div class="validator_err_ctr">
		<h2>Invalid data entered</h2>
		<p><v:error-summary/></p>
	      </div>
	    </v:template>
	  </div>
	  <div class="main_page_area">
	    <xsl:apply-templates select="vm:pagebody" />
	  </div>
	</td> <!-- RB -->
      </tr>
    </table> <!-- RC -->
  </td>
</tr>
      <tr>
	<td id="copyright_ctr" colspan="2">
	  <!-- Virtuoso Universal Server <?V sys_stat ('st_dbms_ver') ?> -->
	  Copyright &amp;copy; 1998-<?V "LEFT" (datestring (now ()), 4)?> OpenLink Software
	  &amp;nbsp;
	</td>
      </tr>
  </table> <!-- MT -->
</xsl:template>

<xsl:template match="vm:menu">
  <ul class="lmenu">
  &lt;?vsp if (self.nav_pos_fixed) { ?&gt;
    <xsl:for-each select="vm:menuitem">
      <li>
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
      </li>
    </xsl:for-each>
  &lt;?vsp } else { ?&gt;
    <li>
    &lt;?vsp http (coalesce (self.nav_tip, '')); ?&gt;
    </li>
  &lt;?vsp } ?&gt;
  </ul>
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
      http ('<img src="images/icons/first_16.png" alt="First" title="First" border="0" />&nbsp;First');
    }
  ?>
  <v:button name="{@data-set}_first" action="simple" style="image" value="images/icons/first_16.png"
      xhtml_alt="First" xhtml_title="First" text="&amp;nbsp;First">
  </v:button>
      &amp;nbsp;
  </xsl:if>
  <?vsp
    if (d_prev)
    {
      http ('<img src="images/icons/previous_16.png" alt="Previous" title="Previous" border="0" />&nbsp;Previous');
    }
  ?>
  <v:button name="{@data-set}_prev" action="simple" style="image" value="images/icons/previous_16.png"
      xhtml_alt="Previous" xhtml_title="Previous" text="&amp;nbsp;Previous">
  </v:button>
  &amp;nbsp;
  <?vsp
    if (d_next)
    {
      http ('<img src="images/icons/next_16.png" alt="Next" title="Next" border="0" />&nbsp;Next');
    }
  ?>
  <v:button name="{@data-set}_next" action="simple" style="image" value="images/icons/next_16.png"
                                xhtml_alt="Next" xhtml_title="Next" text="&amp;nbsp;Next">
  </v:button>
  <xsl:if test="not(@type) or @type = 'set'">&amp;nbsp;
  <?vsp
    if (d_last)
    {
      http ('<img src="images/icons/last_16.png" alt="Last" title="Last" border="0" />&nbsp;Last');
    }
  ?>
  <v:button name="{@data-set}_last" action="simple" style="image" value="images/icons/last_16.png"
	  xhtml_alt="Last" xhtml_title="Last" text="&amp;nbsp;Last">
  </v:button>
  </xsl:if>
  <?vsp
    }
  ?>
</xsl:template>

<xsl:template match="vm:helppagewrapper">
    <!--div id="MB"><img src="images/yac_banner.jpg" alt="OpenLink Virtuoso Conductor"/></div-->
    <div id="MB2" style="text-align: left;">
	<img src="images/con_banner.gif" border="0"/>
    </div>
    <div>
      <div id="RB"> <!-- Bread and butter zone -->
        <div class="subpage_header_area">
          <xsl:apply-templates select="vm:header" />
          <xsl:apply-templates select="vm:rawheader" />
          <v:template type="simple" condition="not self.vc_is_valid">
            <div class="validator_err_ctr">
              <v:error-summary/>
            </div>
          </v:template>
        </div>
        <div class="main_page_area">
          <xsl:apply-templates select="*" />
        </div>
      </div> <!-- RB -->
      <div id="copyright_ctr">
        Copyright &amp;copy; 1998-<?V "LEFT" (datestring (now()), 4)?> OpenLink Software
      </div>
    </div> <!-- RC -->
</xsl:template>

<xsl:template match="vm:help">
  <div class="help_button">
    <v:button action="browse" name="brws_{generate-id()}" selector="help.vspx?id={@id}&amp;name={@sect}"
	child-window-options="" value="images/icons/help_16.png" style="image" text="Help">
    </v:button>
  </div>
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
    <xsl:when test="@vdb_check">
      <v:template name="vm_pagebody_has_vdb_template" type="simple" enabled="--equ(sys_stat('st_has_vdb'),1)">
        <xsl:apply-templates select="node()|processing-instruction()" />
      </v:template>
      <v:template name="vm_pagebody_no_vdb_template" type="simple" enabled="--equ(sys_stat('st_has_vdb'),0)">
        <div class="attention_box">
          <p>This Virtual Database feature is available only in the commercial release of Virtuoso Universal Server.
          For more information on the commercial release of the Virtuoso Universal Server,
          click on the following links to learn more:</p>
          <a href="http://virtuoso.openlinksw.com/">Virtual Database Home Page</a><br/>
          <a href="http://demo.openlinksw.com/tutorial">Virtual Database Tutorials</a><br/>
          <a href="http://docs.openlinksw.com/virtuoso">Virtual Database Documentation</a><br/>
          <a href="http://www.openlinksw.com/">OpenLink Software</a><br/>
        </div>
      </v:template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates select="node()|processing-instruction()" />
    </xsl:otherwise>
  </xsl:choose>
  <?vsp
    }
  ?>
</xsl:template>

<xsl:template match="vm:pagebody[@show='always']">
    <xsl:apply-templates select="node()|processing-instruction()" />
</xsl:template>

<!-- The rest is from page.xsl -->

<xsl:template match="vm:header">
<xsl:if test="@caption">
  &lt;?vsp if (self.nav_pos_fixed) { ?&gt;
  <h1 class="page_title"> <!-- <xsl:copy-of select="@class"/> -->
  <xsl:value-of select="@caption"/></h1>
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
<td class="SubInfo">
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

<xsl:template match="vm:label">
  <label>
    <xsl:attribute name="for"><xsl:value-of select="@for"/></xsl:attribute>
    <v:label><xsl:attribute name="value"><xsl:value-of select="@value"/></xsl:attribute></v:label>
  </label>
</xsl:template>

<xsl:template match="vm:tabCaption">
  <div>
    <xsl:if test="@hide">
      <xsl:attribute name="style">display: none;</xsl:attribute>
    </xsl:if>
    <xsl:attribute name="id"><xsl:value-of select="concat('tab_', @tab)"/></xsl:attribute>
    <xsl:attribute name="class">tab <xsl:if test="@activeTab = @tab">activeTab</xsl:if></xsl:attribute>
    <xsl:attribute name="onclick">javascript:showTab(<xsl:value-of select="@tab"/>, <xsl:value-of select="@tabs"/>)</xsl:attribute>
    <xsl:value-of select="@caption"/>
  </div>
</xsl:template>

<xsl:template match="vm:if">
  <xsl:processing-instruction name="vsp">
    if (<xsl:value-of select="@test"/>)
    {
  </xsl:processing-instruction>
      <xsl:apply-templates />
  <xsl:processing-instruction name="vsp">
    }
  </xsl:processing-instruction>
</xsl:template>

<!-- dashboard status areas -->
<xsl:template name="st-general">
    <?vsp
    declare bits any;
    bits := self.bits;
    if (isnull (self.pname) or bits[1] = ascii ('1')) { ?>
    <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="1" %s /></td>', self.tp, y_check_if_bit (bits, 1)));
	?>
	<td class="stat_col_label">Up Since</td><td>
	<?vsp
	{
	  declare y, m, d, h, mi int;

	  y := sys_stat ('st_started_since_year');
	  m := sys_stat ('st_started_since_month');
	  d := sys_stat ('st_started_since_day');
	  h := sys_stat ('st_started_since_hour');
	  mi:= sys_stat ('st_started_since_minute');

	  http (sprintf ('%04d-%02d-%02d %02d:%02d', y,m,d,h,mi));
	}
	?>
  </td></tr>
  <?vsp } ?>
  <?vsp if (isnull (self.pname) or bits[2] = ascii ('1')) { ?>
  <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="2" %s /></td>', self.tp, y_check_if_bit (bits, 2)));
	?>
      <td class="stat_col_label">Time Zone</td><td>
      <?vsp
	 declare tz int;
	 tz := timezone (now ());
	 http (sprintf ('GMT %s%d min.', case when tz >=0 then '+' else '' end, tz));
      ?>
  </td></tr>
  <?vsp } ?>
  <?vsp if (isnull (self.pname) or bits[3] = ascii ('1')) { ?>
  <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="3" %s /></td>', self.tp, y_check_if_bit (bits, 3)));
	?>
      <td class="stat_col_label">Version</td><td><?V sys_stat ('st_dbms_ver') ?></td></tr>
  <?vsp } ?>
  <?vsp if (isnull (self.pname) or bits[4] = ascii ('1')) { ?>
  <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="4" %s /></td>', self.tp, y_check_if_bit (bits, 4)));
	?>
      <td class="stat_col_label">Install Directory</td><td><?V server_root () ?></td></tr>
  <?vsp } ?>
  <?vsp if (isnull (self.pname) or bits[5] = ascii ('1')) { ?>
  <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="5" %s /></td>', self.tp, y_check_if_bit (bits, 5)));
	?>
      <td class="stat_col_label">Host</td><td><?V sys_stat ('st_host_name') ?></td></tr>
  <?vsp } ?>
</xsl:template>

<xsl:template name="st-http">
    <?vsp
    declare bits any;
    bits := self.bits;
    if (isnull (self.pname) or bits[1] = ascii ('1')) { ?>
    <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="1" %s /></td>', self.tp, y_check_if_bit (bits, 1)));
	?>
	<td class="stat_col_label">Connections</td><td><?V sys_stat ('tws_connections') ?></td></tr>
  <?vsp } ?>
  <?vsp if (isnull (self.pname) or bits[2] = ascii ('1')) { ?>
  <tr>
	<?vsp if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="2" %s /></td>', self.tp, y_check_if_bit (bits, 2)));
	?>
      <td class="stat_col_label">HTTP Requests</td><td><?V sys_stat ('tws_requests') ?></td></tr>
  <?vsp } ?>
  <?vsp if (isnull (self.pname) or bits[3] = ascii ('1')) { ?>
  <tr>
	<?vsp if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="3" %s /></td>', self.tp, y_check_if_bit (bits, 3)));
	?>
      <td class="stat_col_label">Accepts Queued</td><td><?V sys_stat ('tws_accept_queued') ?></td></tr>
  <?vsp } ?>
  <?vsp if (isnull (self.pname) or bits[4] = ascii ('1')) { ?>
  <tr>
	<?vsp if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="4" %s /></td>', self.tp, y_check_if_bit (bits, 4)));
	?>
      <td class="stat_col_label">Accepts requeued</td><td><?V sys_stat ('tws_accept_requeued') ?></td></tr>
  <?vsp } ?>
  <xsl:call-template name="st-update"/>
</xsl:template>

<xsl:template name="st-diag">
	  <tr><td class="stat_col_label">Profiling</td><td>
	      <?vsp
	        declare prof, xt, s1, s2, s3, s4, s5, s6, isdone, d1,d2 any;
		isdone := 0;
		if (sys_stat ('prof_on') = 0)
		  {
	            http ('Turned OFF');
		  }
		else
		  {
		    http ('Turned ON');
		  }
		    ?>
           </td></tr>
		<?vsp
		if (isstring (file_stat ('virtprof.out')))
		  {
		    declare exit handler for sqlstate '*'
		    {
		      rollback work;
		      goto notdone;
		    };
		    prof := file_to_string ('virtprof.out');
		    prof := concat ('<html>', prof, '</html>');
		    xt := xml_tree_doc (prof);
		    d1 := xpath_eval ('/html/table[@id="tim_t"]//td[@id="start_t"]/text()', xt);
		    d2 := xpath_eval ('/html/table[@id="tim_t"]//td[@id="end_t"]/text()', xt);

		    s1 := xpath_eval ('/html/table[@id="qprof_t"]/tr[3]/td[1]/text()', xt);
		    s2 := xpath_eval ('/html/table[@id="qprof2_t"]/tr[1]/td[1]/text()', xt);
		    s3 := xpath_eval ('/html/table[@id="qprof2_t"]/tr[1]/td[2]/text()', xt);
		    s4 := xpath_eval ('/html/table[@id="stmts_t"]/tr[2]/td[1]/text()', xt);
		    s5 := xpath_eval ('/html/table[@id="stmts_t"]/tr[2]/td[2]/text()', xt);
		    s6 := xpath_eval ('/html/table[@id="stmts_t"]/tr[2]/td[3]/text()', xt);
		    if (s1 is not null)
		      isdone := 1;
		  }
		notdone:;
		if (isdone)
	          {
	      ?>
         <?vsp
	  declare bits any;
	  bits := self.bits;
	  if (isnull (self.pname) or bits[1] = ascii ('1')) { ?>
	  <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="1" %s /></td>', self.tp, y_check_if_bit (bits, 1)));
	?>
	      <td class="stat_col_label">Last Profile Run</td>
	      <td></td>
	  </tr>
  <?vsp } ?>
  <?vsp if (isnull (self.pname) or bits[2] = ascii ('1')) { ?>
	  <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="2" %s /></td>', self.tp, y_check_if_bit (bits, 2)));
	?>
	      <td class="stat_col_label">Start time</td>
	      <td><?V d1 ?></td>
	  </tr>
  <?vsp } ?>
  <?vsp if (isnull (self.pname) or bits[3] = ascii ('1')) { ?>
	  <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="3" %s /></td>', self.tp, y_check_if_bit (bits, 3)));
	?>
	      <td class="stat_col_label">End time</td>
	      <td><?V d2 ?></td>
	  </tr>
  <?vsp } ?>
  <?vsp if (isnull (self.pname) or bits[4] = ascii ('1')) { ?>
	  <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="4" %s /></td>', self.tp, y_check_if_bit (bits, 4)));
	?>
	      <td class="stat_col_label">Query (msec)</td>
	      <td><?V s1 ?> <br />
	      <?V s2 ?> <span style="font-weight: normal;"> Executed </span> <?V s3 ?>
              </td>
	  </tr>
  <?vsp } ?>
  <?vsp if (isnull (self.pname) or bits[5] = ascii ('1')) { ?>
	  <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="5" %s /></td>', self.tp, y_check_if_bit (bits, 5)));
	?>
	      <td class="stat_col_label">Statements Compiled</td>
	      <td>
	      <?V s4 ?> <br />
	      <span style="font-weight: normal;">Compile Time </span> <?V s5 ?> <span style="font-weight: normal;"> (ms)</span><br />
	      <span style="font-weight: normal;">Prepared Reuse </span> <?V s6 ?>
	      </td>
	  </tr>
  <?vsp } ?>
	  <?vsp } ?>
</xsl:template>

<xsl:template name="st-db">
   <?vsp
   declare bits any;
   bits := self.bits;
   if (isnull (self.pname) or bits[1] = ascii ('1')) { ?>
    <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="1" %s /></td>', self.tp, y_check_if_bit (bits, 1)));
	?>
	<td class="stat_col_label">Disk Reads</td>
	<td><?V sys_stat ('disk_reads') ?></td>
    </tr>
  <?vsp } ?>
  <?vsp if (isnull (self.pname) or bits[2] = ascii ('1')) { ?>
    <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="2" %s /></td>', self.tp, y_check_if_bit (bits, 2)));
	?>
	<td class="stat_col_label">Disk Writes</td>
	<td><?V sys_stat ('disk_writess') ?></td>
    </tr>
  <?vsp } ?>
  <?vsp if (isnull (self.pname) or bits[3] = ascii ('1')) { ?>
    <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="3" %s /></td>', self.tp, y_check_if_bit (bits, 3)));
	?>
	<td class="stat_col_label">Last Backup</td>
	<td><?V backup_context_info_get('date') ?></td>
    </tr>
  <?vsp } ?>
  <?vsp if (isnull (self.pname) or bits[4] = ascii ('1')) { ?>
    <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="4" %s /></td>', self.tp, y_check_if_bit (bits, 4)));
	?>
	<td class="stat_col_label">Log Filename</td>
	<td><?V sys_stat ('st_db_log_name') ?></td>
    </tr>
  <?vsp } ?>
  <?vsp if (isnull (self.pname) or bits[5] = ascii ('1')) { ?>
    <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="5" %s /></td>', self.tp, y_check_if_bit (bits, 5)));
	?>
	<td class="stat_col_label">Clients Connected</td>
	<td><?V sys_stat ('st_cli_connects') ?></td>
    </tr>
  <?vsp } ?>
  <xsl:call-template name="st-update"/>
</xsl:template>

<xsl:template name="st-space">
    <?vsp
      declare psz int;
      psz := sys_stat ('st_db_page_size');
    ?>
   <?vsp
   declare bits any;
   bits := self.bits;
   if (isnull (self.pname) or bits[1] = ascii ('1')) { ?>
    <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="1" %s /></td>', self.tp, y_check_if_bit (bits, 1)));
	?>
	<td class="stat_col_label">Master Database</td>
	<td><?V space_fmt (sys_stat ('st_db_pages')*psz) ?>, <?V space_fmt (sys_stat ('st_db_free_pages')*psz) ?> free, <?V space_fmt (psz*sys_stat ('st_chkp_remap_pages')) ?> remap</td>
    </tr>
  <?vsp } ?>
  <?vsp if (isnull (self.pname) or bits[2] = ascii ('1')) { ?>
    <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="2" %s /></td>', self.tp, y_check_if_bit (bits, 2)));
	?>
	<td class="stat_col_label">Temp Database</td>
	<td><?V space_fmt (psz*sys_stat ('st_db_temp_pages')) ?>, <?V space_fmt (psz*sys_stat ('st_db_temp_free_pages')) ?> free</td>
    </tr>
  <?vsp } ?>
  <?vsp if (isnull (self.pname) or bits[3] = ascii ('1')) { ?>
    <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="3" %s /></td>', self.tp, y_check_if_bit (bits, 3)));
	?>
	<td class="stat_col_label">Transaction Log File</td>
	<td><?V concat (sys_stat ('st_db_log_name'), ' ', space_fmt (cast (sys_stat ('st_db_log_length') as int)),'') ?></td>
    </tr>
  <?vsp } ?>
  <xsl:call-template name="st-update"/>
</xsl:template>

<xsl:template name="st-lic">
   <?vsp
   declare bits any;
   bits := self.bits;
   if (isnull (self.pname) or bits[1] = ascii ('1')) { ?>
    <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="1" %s /></td>', self.tp, y_check_if_bit (bits, 1)));
	?>
	<td class="stat_col_label">Server</td>
	<td><?V sys_stat ('st_dbms_name') ?></td>
    </tr>
  <?vsp } ?>
  <?vsp if (isnull (self.pname) or bits[2] = ascii ('1')) { ?>
    <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="2" %s /></td>', self.tp, y_check_if_bit (bits, 2)));
	?>
	<td class="stat_col_label">Platform</td>
	<td><?V sys_stat ('st_build_opsys_id') ?></td>
    </tr>
  <?vsp } ?>
  <?vsp if ((isnull (self.pname) or bits[3] = ascii ('1')) and sys_stat('st_has_vdb') = 1) { ?>
    <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="3" %s /></td>', self.tp, y_check_if_bit (bits, 3)));
	?>
	<td class="stat_col_label">Maximum Licensed <br />Client Connections</td>
	<td><?V sys_stat ('st_lic_max_connections') ?></td>
    </tr>
  <?vsp } ?>
  <?vsp if (isnull (self.pname) or bits[4] = ascii ('1')) { ?>
    <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="4" %s /></td>', self.tp, y_check_if_bit (bits, 4)));
	?>
	<td class="stat_col_label">Build Date</td>
	<td><?V sys_stat ('st_build_date') ?></td>
    </tr>
  <?vsp } ?>
  <?vsp if ((isnull (self.pname) or bits[5] = ascii ('1')) and sys_stat('st_has_vdb') = 1) { ?>
    <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="5" %s /></td>', self.tp, y_check_if_bit (bits, 5)));
	?>
	<td class="stat_col_label">License Owner</td>
	<td><?V sys_stat ('st_lic_owner') ?></td>
    </tr>
  <?vsp } ?>
</xsl:template>

<xsl:template name="st-disk">
   <?vsp
   declare bits any;
   bits := self.bits;
   if (isnull (self.pname) or bits[1] = ascii ('1')) { ?>
    <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="1" %s /></td>', self.tp, y_check_if_bit (bits, 1)));
	?>
	<td colspan="2"><span style="font-weight: normal;">Read ahead </span> <?V sys_stat ('st_db_disk_read_aheads') ?>%, <?V sys_stat ('st_db_disk_read_pct') ?>% in last <?V sys_stat ('st_db_disk_read_last') ?> s</td>
    </tr>
  <?vsp } ?>
  <?vsp if (isnull (self.pname) or bits[2] = ascii ('1')) { ?>
    <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="2" %s /></td>', self.tp, y_check_if_bit (bits, 2)));
	?>
      <td colspan="2" class="stat_col">
	<table>
	    <tr class="listing_row_odd"><td>Index</td><td>Reads</td><td>Hit %</td></tr>
	    <?vsp
	      for select top 3 INDEX_NAME, READS, READ_PCT from DB.DBA.SYS_D_STAT order by READS desc do
	         {
	    ?>
	    <tr><td class="stat_col"><?V INDEX_NAME  ?></td><td class="stat_colr"><?V READS ?></td><td class="stat_colr"><?V READ_PCT ?></td></tr>
	    <?vsp
	         }
            ?>
	</table>
      </td>
    </tr>
  <?vsp } ?>
  <xsl:call-template name="st-update"/>
</xsl:template>

<xsl:template name="st-cli">
   <?vsp
   declare bits any;
   bits := self.bits;
   if (isnull (self.pname) or bits[1] = ascii ('1')) { ?>
    <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="1" %s /></td>', self.tp, y_check_if_bit (bits, 1)));
	?>
	<td colspan="2" class="stat_col">
	    <b><?V sys_stat ('st_cli_n_current_connections') ?></b> clients, <b><?V sys_stat ('st_cli_connects') ?></b> connects since start
	</td>
    </tr>
    <tr>
	<?vsp
	  if (isnull (self.pname))
	    http ('<td></td>');
	?>
	<td colspan="2" class="stat_col">
	    <b><?V sys_stat ('thr_cli_running') ?></b> threads running, <b><?V sys_stat ('thr_cli_waiting') ?></b> waiting, <b><?V sys_stat ('thr_cli_vdb') ?></b>  in network  IO
	</td>
    </tr>
  <?vsp } ?>
  <?vsp if (isnull (self.pname) or bits[2] = ascii ('1')) { ?>
    <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="2" %s /></td>', self.tp, y_check_if_bit (bits, 2)));
	?>
      <td colspan="2" class="stat_col">
	<table>
	    <tr class="listing_row_odd">
		<td>Account</td><td>Connections</td><td align="center">bytes in</td>
		<td align="center">bytes out</td><td align="center">Threads</td>
	    </tr>
	    <?vsp
	    for select distinct name, count(*) as cnt, sum(bin) as bin, sum(bout) as bout, sum(threads) as threads
	    from CLI_STATUS_REPORT group by name order by 2 desc do
	         {
	    ?>
	    <tr>
		<td class="stat_col"><?V name ?></td>
		<td class="stat_col"><?V cnt ?></td>
		<td class="stat_colr"><?V space_fmt (bin) ?></td>
		<td class="stat_colr"><?V space_fmt (bout) ?></td>
		<td class="stat_colr"><?V threads ?></td>
	    </tr>
	    <?vsp
	         }
            ?>
	</table>
      </td>
    </tr>
  <?vsp } ?>
  <xsl:call-template name="st-update"/>
</xsl:template>

<xsl:template match="vm:dash-groups">
    <v:item name="General" value="General" />
    <v:item name="HTTP Server" value="HTTPServer" />
    <v:item name="Diagnostics" value="Diagnostics" />
    <v:item name="Database Server" value="DatabaseServer" />
    <v:item name="Space Allocation" value="SpaceAllocation" />
    <v:item name="License" value="License" />
    <v:item name="Disk" value="Disk" />
    <v:item name="Locks" value="Locks" />
    <v:item name="Clients" value="Clients" />
    <v:item name="Event Activity" value="EventActivity" />
    <v:item name="*** Do not display ***" value="***" />
</xsl:template>

<xsl:template name="st-locks">
   <?vsp
   declare bits any;
   bits := self.bits;
   if (isnull (self.pname) or bits[1] = ascii ('1')) { ?>
    <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="1" %s /></td>', self.tp, y_check_if_bit (bits, 1)));
	?>
	<td colspan="2" class="stat_col">
	    <b><?V sys_stat ('lock_waits') ?></b> waits, <b><?V sys_stat ('lock_deadlocks') ?></b> deadlocks
	</td>
    </tr>
  <?vsp } ?>
  <?vsp if (isnull (self.pname) or bits[2] = ascii ('1')) { ?>
    <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="2" %s /></td>', self.tp, y_check_if_bit (bits, 2)));
	?>
      <td colspan="2" class="stat_col">
	<table>
	    <tr class="listing_row_odd"><td>Index</td><td>Wait (msec)</td><td>Wait %</td></tr>
	    <?vsp
	      for select top 3 INDEX_NAME, WAIT_MSECS, WAIT_PCT from DB.DBA.SYS_L_STAT order by WAIT_MSECS desc do
	         {
	    ?>
	    <tr><td class="stat_col"><?V INDEX_NAME  ?></td><td class="stat_colr"><?V WAIT_MSECS ?></td><td class="stat_colr"><?V WAIT_PCT ?></td></tr>
	    <?vsp
	         }
            ?>
	</table>
      </td>
    </tr>
  <?vsp } ?>
  <xsl:call-template name="st-update"/>
</xsl:template>

<xsl:template name="st-update">
  <?vsp if (isnull (self.pname) or bits[11] >= 1) { ?>
    <tr>
      <td colspan="2" class="stat_col">
	<?vsp
	  if (isnull (self.pname)) {
      http ('Update interval: ');
	    http (sprintf ('<input type="text" size="2" name="%s_updint" value="%d"/>', self.tp, bits[11]));
	    http (' sec');
	  } else {
      http ('<div style="float:right; white-space: nowrap;">Updated: ');
      http (substring (cast (now() as varchar), 1, 19));
      http ('</div>');
    }
	?>
	<?vsp
	  if (not(isnull (self.pname)) and self.pname <> 'show') {
	?>
        <script language="Javascript">
          var timer<?V self.pname ?> = setTimeout("UpdateItem<?V self.pname ?>()",<?V self.bits[11] * 1000 ?>);

          function UpdateItem<?V self.pname ?>(){
          	var cnt = document.getElementById('sys_info_sa<?V self.pname ?>');
          	var xmlhttp = null;
            try {
              xmlhttp = new ActiveXObject("Msxml2.XMLHTTP");
            } catch (e) { }

            if (xmlhttp == null) {
              try {
                xmlhttp = new ActiveXObject("Microsoft.XMLHTTP");
              } catch (e) { }
            } // if

            // Gecko / Mozilla / Firefox
            if (xmlhttp == null)
              xmlhttp = new XMLHttpRequest();

          	xmlhttp.open("GET", 'dashboard_item_show.vspx?sid=<?V self.sid ?>&amp;realm=<?V self.realm ?>&amp;tp=<?V self.tp ?>&amp;bits=<?V substring(self.bits,1,11) || '1' ?>',false);
          	xmlhttp.setRequestHeader("Pragma", "no-cache");
          	xmlhttp.send("");
          	cnt.innerHTML = xmlhttp.responseText;

        		timer<?V self.pname ?> = setTimeout("UpdateItem<?V self.pname ?>()",<?V self.bits[11] * 1000 ?>);
          }
        </script>
    <?vsp } ?>
      </td>
    </tr>
  <?vsp } ?>
</xsl:template>

<xsl:template name="st-ev">
   <?vsp
   declare bits any;
   declare num, active, completed, errs int;
   declare _now any;

   select count(*) into num from SYS_SCHEDULED_EVENT;
   select count(*) into errs from SYS_SCHEDULED_EVENT where SE_LAST_ERROR is not null;
   bits := self.bits;
   if (isnull (self.pname) or bits[1] = ascii ('1')) { ?>
    <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="1" %s /></td>', self.tp, y_check_if_bit (bits, 1)));
	?>
	<td class="stat_col_label">Number of Schedule Events</td>
	<td>
	      <?vsp
	      http_value (num);
	      ?>
      </td>
  </tr>
  <?vsp } ?>
  <?vsp if (isnull (self.pname) or bits[2] = ascii ('1')) { ?>
  <tr>
	<?vsp
	  if (isnull (self.pname))
	    http (sprintf ('<td><input type="checkbox" name="%s" value="2" %s /></td>', self.tp, y_check_if_bit (bits, 2)));
	?>
      <td class="stat_col_label">Errors</td><td><?V errs ?></td>
  </tr>
  <?vsp } ?>
</xsl:template>

<xsl:template match="vm:st-prefs-meth">
  &lt;?vsp
    declare tp any;
    tp := self.tp;
    if (self.pname is not null)
      {
        declare tmp any;
        tmp := get_keyword (tp, vector ('General','General','HTTPServer','HTTP Server','Diagnostics','Diagnostics',
	'DatabaseServer','Database Server','SpaceAllocation','Space Allocation',
	'License','License','EventActivity','Event Activity', 'Disk', 'Disk', 'Locks', 'Locks', 'Clients', 'Clients'));
	if (tmp is not null) {
  ?&gt;
  <tr class="stat_header_line"><th colspan="2"><?V tmp ?></th></tr>
  &lt;?vsp
           }
      }
    if (tp = 'General')
      {
  ?&gt;
       <xsl:call-template name="st-general"/>
  &lt;?vsp
     }
   else if (tp = 'HTTPServer') {
  ?&gt;
       <xsl:call-template name="st-http"/>
  &lt;?vsp
     }
  else if (tp = 'Diagnostics') {
  ?&gt;
       <xsl:call-template name="st-diag"/>
  &lt;?vsp
     }
  else if (tp = 'DatabaseServer') {
  ?&gt;
       <xsl:call-template name="st-db"/>
  &lt;?vsp
     }
  else if (tp = 'SpaceAllocation') {
  ?&gt;
       <xsl:call-template name="st-space"/>
  &lt;?vsp
     }
  else if (tp = 'License') {
  ?&gt;
       <xsl:call-template name="st-lic"/>
  &lt;?vsp
     }
  else if (tp = 'Disk') {
  ?&gt;
       <xsl:call-template name="st-disk"/>
  &lt;?vsp
     }
  else if (tp = 'Locks') {
  ?&gt;
       <xsl:call-template name="st-locks"/>
  &lt;?vsp
     }
  else if (tp = 'Clients') {
  ?&gt;
       <xsl:call-template name="st-cli"/>
  &lt;?vsp
     }
  else if (tp = 'EventActivity') {
  ?&gt;
       <xsl:call-template name="st-ev"/>
  &lt;?vsp
     }
  ?&gt;
</xsl:template>

</xsl:stylesheet>
