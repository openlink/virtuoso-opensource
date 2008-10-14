<?xml version="1.0" encoding="UTF-8"?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:v="http://www.openlinksw.com/vspx/" xmlns:xhtml="http://www.w3.org/1999/xhtml" xmlns:vm="http://www.openlinksw.com/vspx/macro" xmlns:ods="http://www.openlinksw.com/vspx/ods/">
  <xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>

  <!--=========================================================================-->
  <xsl:include href="http://local.virt/DAV/VAD/wa/comp/ods_bar.xsl"/>

  <!--=========================================================================-->
  <xsl:variable name="page_title" select="string (//vm:pagetitle)"/>

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
  <xsl:template match="v:button[not @xhtml_alt or not @xhtml_title]">
    <xsl:copy>
  	  <xsl:copy-of select="@*"/>
      <xsl:if test="not (@xhtml_alt)">
        <xsl:choose>
          <xsl:when test="@xhtml_title">
      	    <xsl:attribute name="xhtml_alt"><xsl:value-of select="@xhtml_title"/></xsl:attribute>
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
  <xsl:template match="vm:popup_pagewrapper">
    <v:variable name="nav_pos_fixed" type="integer" default="1"/>
    <v:variable name="nav_top" type="integer" default="0"/>
    <v:variable name="nav_tip" type="varchar" default="''"/>
    <xsl:for-each select="//v:variable">
      <xsl:copy-of select="."/>
    </xsl:for-each>
    <xsl:if test="not @clean or @clean = 'no'">
      <div style="padding: 0 0 0.5em 0;">
        &amp;nbsp;<a href="" onclick="javascript: if (opener != null) opener.focus(); window.close();"><img src="image/close_16.png" border="0" alt="Close" title="Close" />&amp;nbsp;Close</a>
        <hr />
      </div>
    </xsl:if>
    <div id="app_area">
      <v:form name="F1" type="simple" method="POST">
        <xsl:apply-templates select="vm:pagebody" />
      </v:form>
    </div>
    <xsl:if test="not @clean or @clean = 'no'">
    <div class="copyright"><vm:copyright /></div>
    </xsl:if>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:pagewrapper">
    <v:variable name="nav_pos_fixed" type="int" default="0"/>
    <v:variable name="nav_top" type="int" default="0"/>
    <v:variable name="nav_tip" type="varchar" default="''"/>
    <xsl:for-each select="//v:variable">
      <xsl:copy-of select="."/>
    </xsl:for-each>
    <xsl:apply-templates select="vm:init"/>
    <v:form name="F1" method="POST" type="simple" xhtml_enctype="multipart/form-data">
      <ods:ods-bar app_type='oDrive'/>
      <div id="app_area" style="clear: right;">
      <div style="background-color: #fff;">
        <div style="float: left;">
            <?vsp
              http (sprintf ('<a alt="Briefcase Home" title="Briefcase Home" href="%s"><img src="image/drivebanner_sml.jpg" border="0" alt="Briefcase Home" /></a>', ODRIVE.WA.utf2wide (ODRIVE.WA.domain_sioc_url (self.domain_id, self.sid, self.realm))));
            ?>
        </div>
        <div style="float: right; text-align: right; padding-right: 0.5em; padding-top: 20px;">
            <input name="keywords" value="" onkeypress="javascript: if (checkNotEnter(event)) return true; vspxPost('action', '_cmd', 'search', 'mode', 'simple'); return false;" />
          <xsl:call-template name="nbsp"/>
            <v:url url="home.vspx?mode=simple" xhtml_onclick="javascript: vspxPost(\'action\', \'_cmd\', \'search\', \'mode\', \'simple\'); return false;" value="Search" xhtml_title="simple Search" />
          |
            <v:url url="home.vspx?mode=advanced" xhtml_onclick="javascript: vspxPost(\'action\', \'_cmd\', \'search\', \'mode\', \'advanced\'); return false;" value="Advanced" xhtml_title="Advanced Search" />
        </div>
        <br style="clear: left;"/>
      </div>
        <div style="border: solid #935000; border-width: 0px 0px 1px 0px;">
          <div style="float: left; padding-left: 0.5em; padding-bottom: 0.25em;">
            <?vsp http (ODRIVE.WA.utf2wide (ODRIVE.WA.banner_links (self.domain_id, self.sid, self.realm))); ?>
          </div>
          <div style="text-align: right; padding-right: 0.5em; padding-bottom: 0.25em;">
            <v:template name="t1" type="simple" enabled="--case when (self.account_role in ('public', 'guest')) then 0 else 1 end">
          <v:url url="settings.vspx" value="Preferences" xhtml_title="Preferences"/>
        </v:template>
      </div>
        </div>
      <v:include url="odrive_login.vspx"/>
    <table id="RCT">
      <tr>
          <td id="RC">
      	    <v:vscx name="navbar" url="odrive_navigation.vspx" />
              <v:template name="t2" type="simple" condition="not self.vc_is_valid">
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
      <div id="FT">
        <div id="FT_L">
          <a href="http://www.openlinksw.com/virtuoso">
            <img alt="Powered by OpenLink Virtuoso Universal Server" src="image/virt_power_no_border.png" border="0" />
          </a>
    </div>
        <div id="FT_R">
          <a href="<?V ODRIVE.WA.wa_home_link () ?>faq.html">FAQ</a> |
          <a href="<?V ODRIVE.WA.wa_home_link () ?>privacy.html">Privacy</a> |
          <a href="<?V ODRIVE.WA.wa_home_link () ?>rabuse.vspx">Report Abuse</a>
	    <div><vm:copyright /></div>
	    <div><vm:disclaimer /></div>
    </div>
      </div> <!-- FT -->
      </div>
    </v:form>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:menu">
    <div class="left_container">
      <ul class="left_navigation">
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
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:ds-navigation">
    &lt;?vsp
      {
        declare n_start, n_end, n_total integer;
        declare ds vspx_data_set;

        ds := self.vc_find_descendant_control ('<xsl:value-of select="@data-set" />');
        if (isnull (ds.ds_data_source))
        {
          n_total := ds.ds_rows_total;
          n_start := ds.ds_rows_offs + 1;
          n_end   := n_start + ds.ds_nrows - 1;
        } else {
          n_total := ds.ds_data_source.ds_total_rows;
          n_start := ds.ds_data_source.ds_rows_offs + 1;
          n_end   := n_start + ds.ds_data_source.ds_rows_fetched - 1;
        }
        if (n_end > n_total)
          n_end := n_total;

        if (n_total)
          http (sprintf ('%d - %d of %d', n_start, n_end, n_total));

        declare _prev, _next, _last, _first vspx_button;
        declare d_prev, d_next, d_last, d_first integer;

  	    d_prev := d_next := d_last := d_first := 0;
  	    _first := control.vc_find_control ('<xsl:value-of select="@data-set"/>_first');
  	    _last := control.vc_find_control ('<xsl:value-of select="@data-set"/>_last');
  	    _next := control.vc_find_control ('<xsl:value-of select="@data-set"/>_next');
  	    _prev := control.vc_find_control ('<xsl:value-of select="@data-set"/>_prev');

        if (not (_next is not null and not _next.vc_enabled and _prev is not null and not _prev.vc_enabled))
        {
          if (n_total)
            http (' | ');
        if (_first is not null and not _first.vc_enabled)
    	    d_first := 1;

        if (_next is not null and not _next.vc_enabled)
    	    d_next := 1;

        if (_prev is not null and not _prev.vc_enabled)
    	    d_prev := 1;

        if (_last is not null and not _last.vc_enabled)
    	    d_last := 1;
        }
    ?&gt;
    <?vsp
      if (d_first)
        http ('<img src="/ods/images/skin/pager/p_first_gr.png" alt="First Page" title="First Page" border="0" />first&nbsp;');
    ?>
    <v:button name="{@data-set}_first" action="simple" style="image" value="/ods/images/skin/pager/p_first.png" xhtml_alt="First" text="first&amp;nbsp;" />
    <?vsp
      if (d_prev)
        http ('<img src="/ods/images/skin/pager/p_prev_gr.png" alt="Previous Page" title="Previous Page" border="0" />prev&nbsp;');
    ?>
    <v:button name="{@data-set}_prev" action="simple" style="image" value="/ods/images/skin/pager/p_prev.png" xhtml_alt="Previous" text="prev&amp;nbsp;" />
    <?vsp
      if (d_next)
        http ('<img src="/ods/images/skin/pager/p_next_gr.png" alt="Next Page" title="Next Page" border="0" />next&nbsp;');
    ?>
    <v:button name="{@data-set}_next" action="simple" style="image" value="/ods/images/skin/pager/p_next.png" xhtml_alt="Next" text="next&amp;nbsp;" />
    <?vsp
      if (d_last)
        http ('<img src="/ods/images/skin/pager/p_last_gr.png" alt="Last Page" title="Last Page" border="0" />last');
    ?>
    <v:button name="{@data-set}_last" action="simple" style="image" value="/ods/images/skin/pager/p_last.png" xhtml_alt="Last" text="last" />
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
      Briefcase version: <?V registry_get('_oDrive_version_') ?><br/>
      Briefcase build date: <?V registry_get('_oDrive_build_') ?><br/>
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
    &lt;?vsp if (self.nav_pos_fixed) { ?&gt;
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
    &lt;?vsp } else { ?&gt;
      <table class="splash_table">
        <tr>
          <td>
            <xsl:call-template name="vm:splash"/>
          </td>
        </tr>
      </table>
    &lt;?vsp } ?&gt;
  </xsl:template>

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
    <div>
      <xsl:attribute name="id"><xsl:value-of select="concat('tab_', @tab)"/></xsl:attribute>
      <xsl:attribute name="class">tab <xsl:if test="@activeTab = @tab">activeTab</xsl:if></xsl:attribute>
      <xsl:attribute name="onclick">javascript:showTab(<xsl:value-of select="@tab"/>, <xsl:value-of select="@tabs"/>)</xsl:attribute>
      <xsl:value-of select="@caption"/>
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
  <xsl:template match="vm:permissions-header1">
    <tr>
      <xsl:if test="@text">
        <th rowspan="2" style="background-color: #EFEFEF; border-width: 0px;" />
      </xsl:if>
      <th colspan="3">Owner</th>
      <th colspan="3">Group</th>
      <th class="right" colspan="3">Other</th>
    </tr>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:permissions-header2">
    <tr>
      <td>r</td>
      <td>w</td>
      <td>x</td>
      <td>r</td>
      <td>w</td>
      <td>x</td>
      <td>r</td>
      <td>w</td>
      <td class="right">x</td>
    </tr>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="search-dc-template4">
    <div id="4" class="tabContent" style="display: none;">
      <table class="form-body" cellspacing="0">
    <tr>
          <th>
            <v:label for="dav_oMail_DomainId" value="--'oMail domain'" />
          </th>
      <td>
            <v:text name="dav_oMail_DomainId" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:validator test="regexp" regexp="^[0-9]+$" message="Number is expected" runat="client" />
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := get_keyword('dav_oMail_DomainId', self.vc_page.vc_event.ve_params, ODRIVE.WA.DAV_PROP_GET(self.dav_path, 'virt:oMail-DomainId', '1'));
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_oMail_FolderName" value="--'oMail folder name'" />
          </th>
          <td>
            <v:text name="dav_oMail_FolderName" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:validator test="length" min="1" max="255" message="The input can not be empty." runat="client" />
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := get_keyword('dav_oMail_FolderName', self.vc_page.vc_event.ve_params, ODRIVE.WA.DAV_PROP_GET(self.dav_path, 'virt:oMail-FolderName', 'Inbox'));
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_oMail_NameFormat" value="--'oMail name format'" />
          </th>
          <td>
            <v:text name="dav_oMail_NameFormat" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:validator test="length" min="1" max="255" message="The input can not be empty." runat="client" />
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := get_keyword('dav_oMail_NameFormat', self.vc_page.vc_event.ve_params, ODRIVE.WA.DAV_PROP_GET(self.dav_path, 'virt:oMail-NameFormat', '^from^ ^subject^'));
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
      </table>
        </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="search-dc-template5">
    <div id="5" class="tabContent" style="display: none;">
      <table class="form-body" cellspacing="0">
        <tr>
          <th>
            <v:label for="dav_PropFilter_SearchPath" value="--'Search path'" />
          </th>
          <td>
            <v:text name="dav_PropFilter_SearchPath" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:validator test="length" min="1" max="255" message="The input can not be empty." runat="client" />
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := get_keyword('dav_oMail_SearchPath', self.vc_page.vc_event.ve_params, ODRIVE.WA.DAV_PROP_GET(self.dav_path, 'virt:PropFilter-SearchPath', ODRIVE.WA.path_show(self.dir_path)));
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_PropFilter_PropName" value="--'Property name'" />
          </th>
          <td>
            <v:text name="dav_PropFilter_PropName" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:validator test="length" min="1" max="255" message="The input can not be empty." runat="client" />
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := get_keyword('dav_PropFilter_PropName', self.vc_page.vc_event.ve_params, ODRIVE.WA.DAV_PROP_GET(self.dav_path, 'virt:PropFilter-PropName', ''));
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_PropFilter_PropValue" value="--'Property value'" />
          </th>
          <td>
            <v:text name="dav_PropFilter_PropValue" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := get_keyword('dav_PropFilter_PropValue', self.vc_page.vc_event.ve_params, ODRIVE.WA.DAV_PROP_GET(self.dav_path, 'virt:PropFilter-PropValue', ''));
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
      </table>
        </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:search-dc-template7">
    <div id="7" class="tabContent" style="display: none;">
      <table class="form-body" cellspacing="0">
        <tr>
          <th width="30%">
            <v:label for="ts_path" value="--'Search path'" />
          </th>
          <td>
            <?vsp http (sprintf ('<input type="text" name="ts_path" value="%V" disabled="disabled" class="field-text" />', ODRIVE.WA.dc_get(self.search_dc, 'base', 'path', ODRIVE.WA.path_show(self.dir_path)))); ?>
          </td>
        </tr>
      </table>
      <br />
		  <?vsp
		    declare I, N integer;
		    declare S varchar;
		    declare aCriteria, criteria any;
        declare V, f0, f1, f2, f3, f4 any;

        aCriteria := ODRIVE.WA.dc_xml_doc (self.search_dc);
        I := xpath_eval('count(/dc/criteria/entry)', aCriteria);
		  ?>
      <input name="search_seqNo" id="search_seqNo" type="hidden" value="<?V I ?>" />
      <table id="searchProperties" class="form-list" style="width: 100%;" cellspacing="0">
        <thead>
          <tr>
            <th id="search_th_0" width="20%">Field</th>
            <th id="search_th_1" width="20%" style="display: none;">Schena</th>
            <th id="search_th_2" width="20%" style="display: none;">Property</th>
            <th id="search_th_3" width="20%">Condition</th>
            <th id="search_th_4" width="20%">Value</th>
            <th id="search_th_5" width="1%" nowrap="nowrap"><xsl:call-template name="nbsp"/></th>
          </tr>
        </thead>
        <tbody id="search_tbody">
          <tr id="search_tr">
            <td colspan="6">
              <hr />
            </td>
          </tr>
    		  <![CDATA[
    		    <script type="text/javascript">
              OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, ODRIVE.initFilter);
    		  <?vsp
              for (N := 1; N <= I; N := N + 1)
              {
                criteria := xpath_eval('/dc/criteria/entry', aCriteria, N);
                f0 := coalesce (cast (xpath_eval ('@field', criteria) as varchar), 'null');
                f1 := coalesce (cast (xpath_eval ('@schema', criteria) as varchar), 'null');
                f2 := coalesce (cast (xpath_eval ('@property', criteria) as varchar), 'null');
                f3 := coalesce (cast (xpath_eval ('@criteria', criteria) as varchar), 'null');
                f4 := coalesce (cast (xpath_eval ('.', criteria) as varchar), 'null');
                S := sprintf ('field_0:\'%s\', field_1:\'%s\', field_2:\'%s\', field_3:\'%s\', field_4:\'%s\'', f0, f1, f2, f3, f4);
                S := replace (S, '\'null\'', 'null');

                http (sprintf ('OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function(){ODRIVE.searchRowCreate(\'%d\', {%s});});', N - 1, S));
              }
              http (sprintf ('OAT.MSG.attach(OAT, OAT.MSG.OAT_LOAD, function(){ODRIVE.searchRowCreate(\'%d\');})', I));
    		  ?>
    		    </script>
    		  ]]>
        </tbody>
      </table>
        </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:search-dc-template8">
    <div id="8" class="tabContent" style="display: none;">
      <table class="form-body" cellspacing="0">
        <tr>
          <th>
            <v:label for="dav_rdfSink_rdfGraph" value="--'Graph name'" />
          </th>
          <td>
            <v:text name="dav_rdfSink_rdfGraph" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:validator test="length" min="1" max="255" message="The input can not be empty." runat="client" />
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := get_keyword('dav_rdfSink_rdfGraph', self.vc_page.vc_event.ve_params, ODRIVE.WA.DAV_PROP_GET(self.dav_path, 'virt:rdf_graph', ''));
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_rdfSink_rdfSponger" value="--'Sponger (on/off)'" />
          </th>
          <td>
            <v:text name="dav_rdfSink_rdfSponger" format="%s" xhtml_disabled="disabled" xhtml_class="field-short">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := get_keyword('dav_rdfSink_rdfSponger', self.vc_page.vc_event.ve_params, ODRIVE.WA.DAV_PROP_GET(self.dav_path, 'virt:rdf_sponger', ''));
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
      </table>
        </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:search-dc-template9">
    <div id="9" class="tabContent" style="display: none;">
      <table class="form-body" cellspacing="0">
        <tr>
          <th >
            <v:label value="File State" />
          </th>
          <td>
            <?vsp
              http (sprintf ('Lock is <b>%s</b>, ', ODRIVE.WA.DAV_GET_INFO (ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'), 'lockState')));
              http (sprintf ('Version Conrol is <b>%s</b>, ', ODRIVE.WA.DAV_GET_INFO (ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'), 'vc')));
              http (sprintf ('Auto Versioning is <b>%s</b>, ', ODRIVE.WA.DAV_GET_INFO (ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'), 'avcState')));
              http (sprintf ('Version State is <b>%s</b>', ODRIVE.WA.DAV_GET_INFO (ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'), 'vcState')));
            ?>
          </td>
        </tr>
        <v:template name="t3" type="simple" enabled="-- case when (equ(self.command_mode, 10)) then 1 else 0 end">
          <tr>
            <th >
              <v:label value="--sprintf ('Content is %s in Version Conrol', either(equ(ODRIVE.WA.DAV_GET (self.dav_item, 'versionControl'),1), '', 'not'))" format="%s" />
            </th>
            <td valign="center">
              <v:button name="template_vc" action="simple" value="--sprintf ('%s VC', either(equ(ODRIVE.WA.DAV_GET (self.dav_item, 'versionControl'),1), 'Disable', 'Enable'))" xhtml_class="button" xhtml_disabled="disabled">
                <v:on-post>
                  <![CDATA[
                    declare retValue any;

                    if (ODRIVE.WA.DAV_GET (self.dav_item, 'versionControl'))
                    {
                      retValue := ODRIVE.WA.DAV_REMOVE_VERSION_CONTROL (ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'));
                    } else {
                      retValue := ODRIVE.WA.DAV_VERSION_CONTROL (ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'));
                    }
                    if (ODRIVE.WA.DAV_ERROR(retValue))
                    {
                      self.vc_error_message := ODRIVE.WA.DAV_PERROR(retValue);
                      self.vc_is_valid := 0;
                      return;
                    }
                    self.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
            </td>
          </tr>
        </v:template>
        <vm:autoVersion />
        <v:template name="t4" type="simple" enabled="-- case when (equ(ODRIVE.WA.DAV_GET (self.dav_item, 'versionControl'),1)) then 1 else 0 end">
          <tr>
            <th >
              File commands
            </th>
            <td valign="center">
              <v:button name="tepmpate_lock" action="simple" value="Lock" enabled="-- case when (ODRIVE.WA.DAV_IS_LOCKED(ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'))) then 0 else 1 end" xhtml_class="button">
                <v:on-post>
                  <![CDATA[
                    declare retValue any;

                    retValue := ODRIVE.WA.DAV_LOCK (ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'));
                    if (ODRIVE.WA.DAV_ERROR(retValue))
                    {
                      self.vc_error_message := ODRIVE.WA.DAV_PERROR(retValue);
                      self.vc_is_valid := 0;
                      return;
                    }
                    self.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
              <v:button name="tepmpate_unlock" action="simple" value="Unlock" enabled="-- case when (ODRIVE.WA.DAV_IS_LOCKED(ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'))) then 1 else 0 end" xhtml_class="button">
                <v:on-post>
                  <![CDATA[
                    declare retValue any;

                    retValue := ODRIVE.WA.DAV_UNLOCK (ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'));
                    if (ODRIVE.WA.DAV_ERROR(retValue))
                    {
                      self.vc_error_message := ODRIVE.WA.DAV_PERROR(retValue);
                      self.vc_is_valid := 0;
                      return;
                    }
                    self.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
            </td>
          </tr>
          <tr>
            <th >
              Versioning commands
            </th>
            <td valign="center">
              <v:button name="tepmpate_checkIn" action="simple" value="Check-In" enabled="-- case when (is_empty_or_null(ODRIVE.WA.DAV_GET (self.dav_item, 'checked-in'))) then 1 else 0 end" xhtml_class="button">
                <v:on-post>
                  <![CDATA[
                    declare retValue any;

                    retValue := ODRIVE.WA.DAV_CHECKIN (ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'));
                    if (ODRIVE.WA.DAV_ERROR(retValue)) {
                      self.vc_error_message := ODRIVE.WA.DAV_PERROR(retValue);
                      self.vc_is_valid := 0;
                      return;
                    }
                    self.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
              <v:button  name="tepmpate_checkOut" action="simple" value="Check-Out" enabled="-- case when (is_empty_or_null(ODRIVE.WA.DAV_GET (self.dav_item, 'checked-out'))) then 1 else 0 end" xhtml_class="button">
                <v:on-post>
                  <![CDATA[
                    declare retValue any;

                    retValue := ODRIVE.WA.DAV_CHECKOUT (ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'));
                    if (ODRIVE.WA.DAV_ERROR(retValue))
                    {
                      self.vc_error_message := ODRIVE.WA.DAV_PERROR(retValue);
                      self.vc_is_valid := 0;
                      return;
                    }
                    self.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
              <v:button  name="tepmpate_uncheckOut" action="simple" value="Uncheck-Out" enabled="-- case when (is_empty_or_null(ODRIVE.WA.DAV_GET (self.dav_item, 'checked-in'))) then 1 else 0 end" xhtml_class="button">
                <v:on-post>
                  <![CDATA[
                    declare retValue any;

                    retValue := ODRIVE.WA.DAV_UNCHECKOUT (ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'));
                    if (ODRIVE.WA.DAV_ERROR(retValue))
                    {
                      self.vc_error_message := ODRIVE.WA.DAV_PERROR(retValue);
                      self.vc_is_valid := 0;
                      return;
                    }
                    self.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
            </td>
          </tr>
          <tr>
            <th >
              Number of Versions in History
            </th>
            <td valign="center">
              <v:label value="--ODRIVE.WA.DAV_GET_VERSION_COUNT(ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'))" format="%d" />
            </td>
          </tr>
          <tr>
            <th >
              Root version
            </th>
            <td valign="center">
              <v:button style="url" action="simple" value="--ODRIVE.WA.DAV_GET_VERSION_ROOT(ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'))" format="%s">
                <v:on-post>
                  <![CDATA[
                    declare path varchar;

                    path := ODRIVE.WA.DAV_GET_VERSION_ROOT(ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'));
                    if (ODRIVE.WA.odrive_permission(path) = '')
                    {
                      self.vc_error_message := 'You have not rights to read this folder/file!';
                      self.vc_is_valid := 0;
                      self.vc_data_bind (e);
                      return;
                    }

                    http_request_status ('HTTP/1.1 302 Found');
                    http_header (sprintf ('Location: view.vsp?sid=%s&realm=%s&file=%U&mode=download\r\n', self.sid , self.realm, path));
                    self.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
            </td>
          </tr>
          <tr>
            <th>Versions</th>
            <td>
              <v:data-set name="ds_versions" sql="select rs.* from ODRIVE.WA.DAV_GET_VERSION_SET(rs0)(c0 varchar, c1 integer) rs where rs0 = :p0" nrows="0" scrollable="1">
                <v:param name="p0" value="--ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath')" />

                <v:template name="ds_versions_header" type="simple" name-to-remove="table" set-to-remove="bottom">
                  <table class="form-list" style="width: auto;" id="versions" cellspacing="0">
                    <tr>
                      <th>Path</th>
                      <th>Number</th>
                      <th>Size</th>
                      <th>Modified</th>
                      <th>Action</th>
                    </tr>
                  </table>
                </v:template>

                <v:template name="ds_versions_repeat" type="repeat">

                  <v:template name="ds_versions_empty" type="if-not-exists" name-to-remove="table" set-to-remove="both">
                    <table>
                      <tr align="center">
                        <td colspan="5">No versions</td>
                      </tr>
                    </table>
                  </v:template>

                  <v:template name="ds_versions_browse" type="browse" name-to-remove="table" set-to-remove="both">
                    <table>
                      <tr>
                        <td nowrap="nowrap">
                          <v:button name="button_versions_show" style="url" action="simple" value="--(control.vc_parent as vspx_row_template).te_column_value('c0')" format="%s">
                            <v:on-post>
                              <![CDATA[
                                declare path varchar;

                                path := (control.vc_parent as vspx_row_template).te_column_value('c0');
                                if (ODRIVE.WA.odrive_permission(path) = '')
                                {
                                  self.vc_error_message := 'You have not rights to read this folder/file!';
                                  self.vc_is_valid := 0;
                                  self.vc_data_bind (e);
                                  return;
                                }

                                http_request_status ('HTTP/1.1 302 Found');
                                http_header (sprintf ('Location: view.vsp?sid=%s&realm=%s&file=%U&mode=download\r\n', self.sid , self.realm, path));
                                self.vc_data_bind (e);
                              ]]>
                            </v:on-post>
                          </v:button>
                        </td>
                        <td nowrap="nowrap" align="right">
                          <v:label value="--ODRIVE.WA.path_name((control.vc_parent as vspx_row_template).te_column_value('c0'))" />
                        </td>
                        <td nowrap="nowrap" align="right">
                          <v:label>
                            <v:after-data-bind>
                              <![CDATA[
                                control.ufl_value := ODRIVE.WA.ui_size(ODRIVE.WA.DAV_PROP_GET((control.vc_parent as vspx_row_template).te_column_value('c0'), ':getcontentlength'), 'R');
                              ]]>
                            </v:after-data-bind>
                          </v:label>
                        </td>
                        <td nowrap="nowrap" align="right">
                          <v:label>
                            <v:after-data-bind>
                              <![CDATA[
                                control.ufl_value := ODRIVE.WA.ui_date(ODRIVE.WA.DAV_PROP_GET((control.vc_parent as vspx_row_template).te_column_value('c0'), ':getlastmodified'));
                              ]]>
                            </v:after-data-bind>
                          </v:label>
                        </td>
                        <td nowrap="nowrap">
                          <v:button  name="button_versions_delete" action="simple" style="image" value="image/del_16.png" enabled="-- (control.vc_parent as vspx_row_template).te_column_value('c1')" xhtml_onclick="javascript: return confirm(\'Are you sure you want to delete the chosen version and all previous versions?\');">
                            <v:on-post>
                              <![CDATA[
                                declare retValue any;

                                retValue := ODRIVE.WA.DAV_DELETE((control.vc_parent as vspx_row_template).te_column_value('c0'));
                                if (ODRIVE.WA.DAV_ERROR(retValue))
                                {
                                  self.vc_error_message := ODRIVE.WA.DAV_PERROR(retValue);
                                  self.vc_is_valid := 0;
                                  return;
                                }
                                self.vc_data_bind (e);
                              ]]>
                            </v:on-post>
                          </v:button>
                        </td>
                      </tr>
                    </table>
                  </v:template>

                </v:template>

                <v:template name="ds_versions_footer" type="simple" name-to-remove="table" set-to-remove="top">
                  <table>
                  </table>
                </v:template>

              </v:data-set>
            </td>
          </tr>
        </v:template>
      </table>
        </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:search-dc-template10">
    <div id="10" class="tabContent" style="display: none;">
      <table class="form-body" cellspacing="0">
        <tr>
          <th>
            <v:label for="ts_max" value="Max Results" />
          </th>
          <td>
            <?vsp http (sprintf ('<input type="text" name="ts_max" value="%s" size="5" />', ODRIVE.WA.dc_get (self.search_dc, 'options', 'max', '100'))); ?>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="ts_order" value="Order by" />
          </th>
          <td>
            <select name="ts_order">
              <?vsp
                declare N integer;

                for (N := 0; N < length(self.dir_columns); N := N + 1)
                  if (self.dir_columns[N][3] = 1)
                    http (self.option_prepare(self.dir_columns[N][0], self.dir_columns[N][2], self.dir_order));
              ?>
            </select>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="ts_direction" value="Direction" />
          </th>
          <td>
            <select name="ts_direction">
              <?vsp
                http (self.option_prepare('asc',  'Asc',  self.dir_direction));
                http (self.option_prepare('desc', 'Desc', self.dir_direction));
              ?>
            </select>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="ts_grouping" value="Group by" />
          </th>
          <td>
            <select name="ts_grouping">
              <?vsp
                declare N integer;

                http (self.option_prepare('', '', self.dir_grouping));
                for (N := 0; N < length(self.dir_columns); N := N + 1)
                  if (self.dir_columns[N][4] = 1)
                    http (self.option_prepare(self.dir_columns[N][0], self.dir_columns[N][2], self.dir_grouping));
              ?>
            </select>
          </td>
        </tr>
        <tr>
          <th/>
          <td>
            <v:check-box name="ts_cloud" xhtml_id="ts_cloud" value="1" />
            <vm:label for="ts_cloud" value="Show tag cloud" />
          </td>
        </tr>
      </table>
        </div>
  </xsl:template>

  <!--=========================================================================-->
  <!-- Auto Versioning -->
  <xsl:template match="vm:autoVersion">
    <tr id="davRow_version">
      <th>
        <v:label for="dav_autoversion" value="--'Auto Versioning Content'" />
      </th>
      <td>
        <?vsp
          declare tmp any;

          tmp := '';
          if ((self.dav_type = 'R') and (self.command_mode = 10))
            tmp := 'onchange="javascript: window.document.F1.submit();"';
          http (sprintf ('<select name="dav_autoversion" %s disabled="disabled">', tmp));

          tmp := ODRIVE.WA.DAV_GET (self.dav_item, 'autoversion');
          if (isnull(tmp) and (self.dav_type = 'R'))
            tmp := ODRIVE.WA.DAV_GET_AUTOVERSION (ODRIVE.WA.odrive_real_path(self.dir_path));
          http (self.option_prepare('',   'No',   tmp));
          http (self.option_prepare('A',  'Checkout -> Checkin', tmp));
          http (self.option_prepare('B',  'Checkout -> Unlocked -> Checkin', tmp));
          http (self.option_prepare('C',  'Checkout', tmp));
          http (self.option_prepare('D',  'Locked -> Checkout', tmp));

          http ('</select>');
        ?>
      </td>
    </tr>
  </xsl:template>

</xsl:stylesheet>
