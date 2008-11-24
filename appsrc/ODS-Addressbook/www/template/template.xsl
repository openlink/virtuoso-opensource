<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
  -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2007 OpenLink Software
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
  <xsl:variable name="page_title" select="string (//vm:pagetitle)"/>

  <xsl:include href="http://local.virt/DAV/VAD/wa/comp/ods_bar.xsl"/>

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
    <v:variable name="nav_pos_fixed" type="integer" default="1"/>
    <v:variable name="nav_top" type="integer" default="0"/>
    <v:variable name="nav_tip" type="varchar" default="''"/>
    <xsl:for-each select="//v:variable">
      <xsl:copy-of select="."/>
    </xsl:for-each>
    <div style="padding: 0.5em;">
      <div style="padding: 0 0 0.5em 0;">
        &amp;nbsp;<a href="#" onClick="javascript: if (opener != null) opener.focus(); window.close();"><img src="image/close_16.png" border="0" alt="Close" title="Close" />&amp;nbsp;Close</a>
        <hr />
      </div>
      <v:form name="F1" type="simple" method="POST">
        <xsl:apply-templates select="vm:pagebody" />
      </v:form>
    </div>
    <div class="copyright"><vm:copyright /></div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:popup_external_page_wrapper">
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
      <ods:ods-bar app_type='AddressBook'/>
      <div id="app_area" style="clear: right;">
      <div style="background-color: #fff;">
        <div style="float: left;">
            <?vsp
              http (sprintf ('<a alt="AddressBook Home" title="AddressBook Home" href="%s"><img src="image/abbanner_sml.jpg" border="0" alt="AddressBook Home" /></a>', AB.WA.utf2wide (AB.WA.domain_sioc_url (self.domain_id, self.sid, self.realm))));
            ?>
        </div>
        <v:template type="simple" enabled="--either(gt(self.domain_id, 0), 1, 0)">
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
      </div>
        <div style="clear: both; border: solid #935000; border-width: 0px 0px 1px 0px;">
          <div style="float: left; padding-left: 0.5em;">
            <?vsp http (AB.WA.utf2wide (AB.WA.banner_links (self.domain_id, self.sid, self.realm))); ?>
          </div>
          <div style="float: right; padding-right: 0.5em;">
        <v:template type="simple" enabled="--case when (self.account_role in ('public', 'guest')) then 0 else 1 end">
              <v:url url="home.vspx?action=settings" value="Preferences" xhtml_title="Preferences"/>
        </v:template>
      </div>
          <p style="clear: both; line-height: 0.1em" />
        </div>
      <v:include url="ab_login.vspx"/>
      <table id="MTB">
        <tr>
          <!-- Navigation left column -->
          <td id="RC">
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
      <div id="FT">
        <div id="FT_L">
          <a href="http://www.openlinksw.com/virtuoso">
            <img alt="Powered by OpenLink Virtuoso Universal Server" src="image/virt_power_no_border.png" border="0" />
          </a>
        </div>
        <div id="FT_R">
          <a href="<?V AB.WA.wa_home_link () ?>faq.html">FAQ</a> |
          <a href="<?V AB.WA.wa_home_link () ?>privacy.html">Privacy</a> |
          <a href="<?V AB.WA.wa_home_link () ?>rabuse.vspx">Report Abuse</a>
          <div><vm:copyright /></div>
          <div><vm:disclaimer /></div>
        </div>
        </div>
      </div>
    </v:form>
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
  <xsl:template name="vm:splash">
    <div style="padding: 1em; font-size: 0.70em;">
      <a href="http://www.openlinksw.com/virtuoso"><img title="Powered by OpenLink Virtuoso Universal Server" src="image/PoweredByVirtuoso.gif" border="0" /></a>
      <br />
      Server version: <?V sys_stat('st_dbms_ver') ?><br/>
      Server build date: <?V sys_stat('st_build_date') ?><br/>
      AddressBook version: <?V registry_get('ab_version') ?><br/>
      AddressBook build date: <?V registry_get('ab_build') ?><br/>
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
      <xsl:attribute name="id"><xsl:value-of select="concat(@tab, '_tab_', @tabNo)" /></xsl:attribute>
      <xsl:attribute name="class">tab <xsl:if test="@activeTab = @tab">activeTab</xsl:if></xsl:attribute>
      <xsl:attribute name="onclick">javascript: showTab('<xsl:value-of select="@tab" />', <xsl:value-of select="@tabsCount" />, <xsl:value-of select="@tabNo" />);</xsl:attribute>
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

</xsl:stylesheet>
