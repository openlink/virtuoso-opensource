<!-- $Id$ -->
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2006 OpenLink Software
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
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:v="http://www.openlinksw.com/vspx/" xmlns:xhtml="http://www.w3.org/1999/xhtml" xmlns:vm="http://www.openlinksw.com/vspx/macro">
  <xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>
  <xsl:variable name="page_title" select="string (//vm:pagetitle)"/>

  <xsl:include href="dav_browser.xsl"/>

  <!--=========================================================================-->
  <xsl:template match="head/title[string(.)='']" priority="100">
    <title>
      <xsl:value-of select="$page_title"/>
    </title>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="head/title">
    <title>
      <xsl:value-of select="replace(string(.),'!page_title!',$page_title)"/>
    </title>
  </xsl:template>
  <xsl:template match="vm:pagetitle"/>

  <!--=========================================================================-->
  <xsl:template match="v:page[not @style and not @on-error-redirect][@name != 'error_page']">
    <xsl:copy>
  	  <xsl:copy-of select="@*"/>
  	    <xsl:attribute name="on-error-redirect">error.vspx</xsl:attribute>
        <xsl:if test="not (@on-deadlock-retry)">
        	<xsl:attribute name="on-deadlock-retry">5</xsl:attribute>
  	   </xsl:if>
  	   <xsl:apply-templates />
    </xsl:copy>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="v:button[not @xhtml_alt or not @xhtml_title]|v:url[not @xhtml_alt or not @xhtml_title]">
    <xsl:copy>
  	  <xsl:copy-of select="@*"/>
      <xsl:if test="not (@xhtml_alt)">
        <xsl:choose>
          <xsl:when test="@xhtml_title">
      	    <xsl:attribute name="xhtml_alt"><xsl:value-of select="@xhtml_title"/></xsl:attribute>
          </xsl:when>
          <xsl:when test="@text">
      	    <xsl:attribute name="xhtml_alt"><xsl:value-of select="@text"/></xsl:attribute>
          </xsl:when>
          <xsl:otherwise>
      	    <xsl:attribute name="xhtml_alt"><xsl:value-of select="@value"/></xsl:attribute>
          </xsl:otherwise>
        </xsl:choose>
  	  </xsl:if>
      <xsl:if test="not (@xhtml_title)">
        <xsl:choose>
          <xsl:when test="@xhtml_alt">
      	    <xsl:attribute name="xhtml_title"><xsl:value-of select="@xhtml_alt"/></xsl:attribute>
          </xsl:when>
          <xsl:when test="@text">
      	    <xsl:attribute name="xhtml_title"><xsl:value-of select="@text"/></xsl:attribute>
          </xsl:when>
          <xsl:otherwise>
      	    <xsl:attribute name="xhtml_title"><xsl:value-of select="@value"/></xsl:attribute>
          </xsl:otherwise>
        </xsl:choose>
  	  </xsl:if>
  	  <xsl:apply-templates />
    </xsl:copy>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:copyright">
    <?vsp http (coalesce (wa_utf8_to_wide ((select top 1 WS_COPYRIGHT from WA_SETTINGS)), '')); ?>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:disclaimer">
    <?vsp http (coalesce (wa_utf8_to_wide ((select top 1 WS_DISCLAIMER from WA_SETTINGS)), '')); ?>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:popup_page_wrapper">
    <xsl:apply-templates select="node()|processing-instruction()"/>
    <div class="copyright"><vm:copyright /></div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:pagewrapper">
    <v:variable name="nav_pos_fixed" type="integer" default="0"/>
    <v:variable name="nav_top" type="integer" default="0"/>
    <v:variable name="nav_tip" type="varchar" default="''"/>
    <xsl:for-each select="//v:variable">
      <xsl:copy-of select="."/>
    </xsl:for-each>
    <xsl:apply-templates select="vm:init"/>
    <v:form name="F1" method="POST" type="simple" xhtml_enctype="multipart/form-data">
      <div style="height: 65px; background-color: #fff;">
        <div style="float: left;  padding-top: 3px;">
          <img src="image/bmkbanner_sml.jpg"/>
        </div>
     	  <v:template type="simple" enabled="--either(equ(self.account_role, 'public'), 0, 1)">
          <div style="float: right; text-align: right; padding-right: 0.5em; padding-top: 20px;">
            <v:text name="keywords" value="" xhtml_onkeypress="return submitEnter(\'F1\', \'GO\', event)"/>
            <xsl:call-template name="nbsp"/>
            <v:button name="GO" action="simple" style="url" value="Search" xhtml_alt="Simple Search">
            	<v:on-post>
                self.vc_redirect(sprintf('search.vspx?keywords=%s&amp;mode=simple&amp;step=1', self.keywords.ufl_value));
            	</v:on-post>
  	        </v:button>
            |
            <v:button action="simple" style="url" value="Advanced" xhtml_alt="Advanced Search">
            	<v:on-post>
                self.vc_redirect(sprintf('search.vspx?keywords=%s&amp;mode=advanced', self.keywords.ufl_value));
            	</v:on-post>
  	        </v:button>
          </div>
      	</v:template>
        <br style="clear: left;"/>
      </div>
      <div style="padding: 0.5em 0 0.25em 0; border: solid #935000; border-width: 0px 0px 1px 0px;">
        <div style="float: left; padding-left: 0.5em;">
          <?vsp
            if (self.account_role <> 'public')
              http(sprintf('<a href="%Vmyhome.vspx?sid=%s&realm=%s" title="%V"><img src="image/home_16.png" border="0"/> %V</a>', BMK.WA.wa_home_link (), self.sid, self.realm, self.accountName, self.accountName));
          ?>
        </div>
        <div style="float: right; text-align: right; padding-right: 0.5em;">
       	  <v:template type="simple" enabled="--either(equ(self.account_role, 'public'), 0, 1)">
            <v:url url="settings.vspx" value="Preferences" xhtml_title="Preferences"/>
            |
      	  </v:template>
          <v:button action="simple" style="url" value="Help" xhtml_alt="Help"/>
            |
          <v:url value="--BMK.WA.wa_home_title ()" url="--BMK.WA.wa_home_link ()"/>
       	  <v:template type="simple" enabled="--either(equ(self.account_role, 'public'), 0, 1)">
            |
            <a href="<?V BMK.WA.wa_home_link () ?>" title="Logout">Logout</a>
      	  </v:template>
        </div>
        <br style="clear: left;"/>
      </div>
      <v:include url="bmk_login.vspx"/>
      <table id="MTB">
        <tr>
          <!-- Navigation left column -->
       	  <v:template type="simple" enabled="--either(equ(self.account_role, 'public'), 0, 1)">
            <td id="LC">
              <xsl:call-template name="vm:others"/>
              <xsl:call-template name="vm:formats"/>
            </td>
      	  </v:template>
          <!-- Navigation right column -->
          <td id="RC">
            <v:vscx name="navbar" url="bmk_navigation.vspx" />
        	  <v:template type="simple" condition="not self.vc_is_valid">
        	    <div class="error">
        		    <p><v:error-summary/></p>
        	    </div>
        	  </v:template>
        	  <div class="main_page_area">
        	    <xsl:apply-templates select="vm:pagebody" />
        	  </div>
          </td>
        </tr>
      </table>
    </v:form>
    <div class="footer">
      <a href="<?V BMK.WA.wa_home_link () ?>aboutus.html" title="About Us">About Us</a> |
      <a href="<?V BMK.WA.wa_home_link () ?>faq.html" title="FAQ">FAQ</a> |
      <a href="<?V BMK.WA.wa_home_link () ?>privacy.html" title="Privacy">Privacy</a> |
      <a href="<?V BMK.WA.wa_home_link () ?>rabuse.vspx" title="Report Abuse">Report Abuse</a> |
      <a href="#" title="Advertise">Advertise</a> |
      <a href="#" title="Contact Us">Contact Us</a>
    </div>
    <div class="copyright">
	    <div><vm:copyright /></div>
	    <div><vm:disclaimer /></div>
	    <a href="http://www.openlinksw.com/virtuoso">
	      <img alt="Powered by OpenLink Virtuoso Universal Server" src="image/PoweredByVirtuoso.gif" border="0" />
	    </a>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="vm:others">
    <div class="left_container">
      <ul class="left_navigation">
        <li><v:url value="--'BM&nbsp;Bookmarklet'" format="%s" url="--'bookmark.vspx'"/></li>
      </ul>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="vm:formats">
    <div class="left_container">
      <ul class="left_navigation">
        <li><xsl:call-template name="vm:rss-link"/></li>
        <li><xsl:call-template name="vm:atom-link"/></li>
        <li><xsl:call-template name="vm:rdf-link"/></li>
        <li><xsl:call-template name="vm:ocs-link"/></li>
        <li><xsl:call-template name="vm:opml-link"/></li>
      </ul>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="vm:atom-link">
    <?vsp
      http(sprintf('<a href="%sBM.atom" target="_blank" title="ATOM export" alt="ATOM export" class="gems"><img src="image/blue-icon-16.gif" border="0"/> Atom</a>', BMK.WA.dav_url(self.domain_id, self.account_id)));
    ?>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="vm:rss-link">
    <?vsp
      http(sprintf('<a href="%sBM.rss" target="_blank" title="RSS export" alt="RSS export" class="gems"><img src="image/rss-icon-16.gif" border="0"/> RSS</a>', BMK.WA.dav_url(self.domain_id, self.account_id)));
    ?>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="vm:rdf-link">
    <?vsp
      http(sprintf('<a href="%sBM.rdf" target="_blank" title="RDF export" alt="RDF export" class="gems"><img src="image/rdf-icon-16.gif" border="0"/> RDF</a>', BMK.WA.dav_url(self.domain_id, self.account_id)));
    ?>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="vm:ocs-link">
    <?vsp
      http(sprintf('<a href="%sBM.ocs" target="_blank" title="OCS export" alt="OCS export" class="gems"><img src="image/blue-icon-16.gif" border="0"/> OCS</a>', BMK.WA.dav_url(self.domain_id, self.account_id)));
    ?>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="vm:opml-link">
    <?vsp
      http(sprintf('<a href="%sBM.opml" target="_blank" title="OPML export" alt="OPML export" class="gems"><img src="image/blue-icon-16.gif" border="0"/> OPML</a>', BMK.WA.dav_url(self.domain_id, self.account_id)));
    ?>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="vm:foaf-link">
    <?vsp
      http(sprintf('<a href="%sBM.foaf" target="_blank" title="FOAF export" alt="FOAF export" class="gems"><img src="image/foaf.gif" border="0"/></a>', BMK.WA.dav_url(self.domain_id, self.account_id)));
    ?>
  </xsl:template>

  <!--=========================================================================-->
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
  	      goto _skip;

        if (_first is not null and not _first.vc_enabled)
    	    d_first := 1;

        if (_next is not null and not _next.vc_enabled)
    	    d_next := 1;

        if (_prev is not null and not _prev.vc_enabled)
    	    d_prev := 1;

        if (_last is not null and not _last.vc_enabled)
    	    d_last := 1;

      _skip:;
    ?&gt;
    <xsl:if test="not(@type) or @type = 'set'">
    <?vsp
      if (d_first)
        http ('<img src="image/first_16.gif" alt="First" title="First" border="0" /> First');
    ?>
    <v:button name="{@data-set}_first" action="simple" style="image" value="image/first_16.gif" xhtml_alt="First" text="&amp;nbsp;First"/>
    </xsl:if>
    <?vsp
      if (d_first or _first.vc_enabled)
        http ('&nbsp;');
      if (d_prev)
        http ('<img src="image/previous_16.gif" alt="Previous" title="Previous" border="0" /> Previous');
    ?>
    <v:button name="{@data-set}_prev" action="simple" style="image" value="image/previous_16.gif" xhtml_alt="Previous" text="&amp;nbsp;Previous"/>
    <?vsp
      if (d_prev or _prev.vc_enabled)
        http ('&nbsp;');
      if (d_next)
        http ('<img src="image/next_16.gif" alt="Next" title="Next" border="0" /> Next');
    ?>
    <v:button name="{@data-set}_next" action="simple" style="image" value="image/next_16.gif" xhtml_alt="Next" text="&amp;nbsp;Next"/>
    <xsl:if test="not(@type) or @type = 'set'">
    <?vsp
      if (d_next or _next.vc_enabled)
        http ('&nbsp;');
      if (d_last)
        http ('<img src="image/last_16.gif" alt="Last" title="Last" border="0" /> Last');
    ?>
    <v:button name="{@data-set}_last" action="simple" style="image" value="image/last_16.gif" xhtml_alt="Last" text="&amp;nbsp;Last"/>
    </xsl:if>
    <?vsp
      }
    ?>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="vm:links">
    <div class="left_container">
      <ul class="left_navigation">
        <li><a href="/doc/docs.vsp" target="_empty" alt="Documentation" title="Documentation">Documentation</a></li>
        <li><a href="/tutorial/index.vsp" target="_empty" alt="Tutorials" title="Tutorials">Tutorials</a></li>
        <li><a href="http://www.openlinksw.com" alt="OpenLink Software" title="OpenLink Software">OpenLink Software</a></li>
        <li><a href="http://www.openlinksw.com/virtuoso" alt="Virtuoso Web Site" title="Virtuoso Web Site">Virtuoso Web Site</a></li>
      </ul>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="vm:splash">
    <div style="padding: 1em; font-size: 0.70em;">
      <a href="http://www.openlinksw.com/virtuoso"><img title="Powered by OpenLink Virtuoso Universal Server" src="image/PoweredByVirtuoso.gif" border="0" /></a>
      <br />
      Server version: <?V sys_stat('st_dbms_ver') ?><br/>
      Server build date: <?V sys_stat('st_build_date') ?><br/>
      BM version: <?V registry_get('_bookmark_version_') ?><br/>
      BM build date: <?V registry_get('_bookmark_build_') ?><br/>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:rawheader">
  &lt;?vsp if (self.nav_pos_fixed) { ?&gt;
  <xsl:apply-templates select="node()|processing-instruction()"/>
  &lt;?vsp } ?&gt;
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:raw">
  &lt;?vsp if (self.nav_pos_fixed) { ?&gt;
  <xsl:apply-templates select="node()|processing-instruction()"/>
  &lt;?vsp } ?&gt;
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:pagebody">
    <xsl:choose>
      <xsl:when test="@url">
        <v:template name="vm_pagebody_include_url" type="simple">
          <v:include url="{@url}"/>
        </v:template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="node()|processing-instruction()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- The rest is from page.xsl -->
  <!--=========================================================================-->
  <xsl:template match="vm:header">
    <xsl:if test="@caption">
    &lt;?vsp if (self.nav_pos_fixed) { ?&gt;
    <td class="page_title">
      <!-- <xsl:copy-of select="@class"/> -->
      <xsl:value-of select="@caption"/>
    </td>
    &lt;?vsp } ?&gt;
    </xsl:if>
    <xsl:apply-templates/>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:init">
    <xsl:apply-templates select="node()|processing-instruction()"/>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:caption">
    <xsl:value-of select="@fixed"/>
    <xsl:apply-templates/>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:label">
    <label>
      <xsl:attribute name="for"><xsl:value-of select="@for"/></xsl:attribute>
      <v:label><xsl:attribute name="value"><xsl:value-of select="@value"/></xsl:attribute></v:label>
    </label>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:tabCaption">
    <div style="display: inline;">
      <xsl:attribute name="id"><xsl:value-of select="concat('tabLabel_', @tab)"/></xsl:attribute>
      <xsl:element name="v:url">
        <xsl:attribute name="url">javascript:showTab(<xsl:value-of select="@tab"/>, <xsl:value-of select="@tabs"/>)</xsl:attribute>
        <xsl:attribute name="value"><xsl:value-of select="@caption"/></xsl:attribute>
        <xsl:attribute name="xhtml_id"><xsl:value-of select="concat('tab_', @tab)"/></xsl:attribute>
        <xsl:attribute name="xhtml_class">tab <xsl:if test="@activeTab = @tab">activeTab</xsl:if></xsl:attribute>
      </xsl:element>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="nbsp">
    <xsl:param name="count" select="1"/>
    <xsl:if test="$count != 0">
      <xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text>
      <xsl:call-template name="nbsp">
        <xsl:with-param name="count" select="$count - 1"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>
  <!--=========================================================================-->

</xsl:stylesheet>
