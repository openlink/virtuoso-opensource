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
  <xsl:variable name="page_title" select="string (//vm:pagetitle)"/>

  <xsl:include href="http://local.virt/DAV/VAD/wa/comp/ods_bar.xsl"/>
  <xsl:include href="file_browser.xsl"/>

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
        <ods:ods-bar app_type='eNews2'/>
      <div id="app_area" style="clear: right;">
      <div style="background-color: #fff;">
        <div style="float: left;">
            <?vsp
              http (sprintf ('<a alt="FeedsManager Home" title="FeedsManager Home" href="%s"><img src="image/enewsbanner_sml.jpg" border="0" alt="FeedsManager Home" /></a>', ENEWS.WA.utf2wide (ENEWS.WA.domain_sioc_url (self.domain_id, self.sid, self.realm))));
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
        <br style="clear: left;"/>
      </div>
        <div style="border: solid #935000; border-width: 0px 0px 1px 0px;">
          <div style="float: left; padding-left: 0.5em; padding-bottom: 0.25em;">
            <?vsp http (ENEWS.WA.utf2wide (ENEWS.WA.banner_links (self.domain_id, self.sid, self.realm))); ?>
          </div>
          <div style="text-align: right; padding-right: 0.5em; padding-bottom: 0.25em;">
          <v:template type="simple" enabled="--case when (self.account_role in ('public', 'guest')) then 0 else 1 end">
            <v:url url="settings.vspx" value="Preferences" xhtml_title="Preferences"/>
            |
      	  </v:template>
          <v:button action="simple" style="url" value="Help" xhtml_alt="Help"/>
      </div>
        </div>  
      <v:include url="enews_login.vspx"/>
      <table id="MTB">
        <tr>
          <!-- Navigation left column -->
          <v:template type="simple" enabled="--either(gt(self.domain_id, 0), 1, 0)">
            <td id="LC">
                <v:template type="simple" enabled="--case when (self.account_role in ('guest')) then 0 else 1 end">
              <xsl:call-template name="vm:others"/>
                </v:template>
              <xsl:call-template name="vm:formats"/>
            </td>
      	  </v:template>
          <!-- Navigation right column -->
          <td id="RC">
            	    <v:vscx name="navbar" url="enews_navigation.vspx" />
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
          <a href="<?V ENEWS.WA.wa_home_link () ?>faq.html">FAQ</a> |
          <a href="<?V ENEWS.WA.wa_home_link () ?>privacy.html">Privacy</a> |
          <a href="<?V ENEWS.WA.wa_home_link () ?>rabuse.vspx">Report Abuse</a>
	    <div><vm:copyright /></div>
	    <div><vm:disclaimer /></div>
    </div>
      </div> <!-- FT -->
      </div>
    </v:form>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="vm:others">
    <div class="left_container">
      <div>
        <v:url value="--'OFM Bookmarklet'" format="%s" url="--'bookmark.vspx'"/>
      </div>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="vm:formats">
    <div class="left_container">
    <?vsp
      declare exit handler for not found;

        declare S varchar;
      declare lat, lng any;

      select WAUI_LAT, WAUI_LNG into lat, lng from DB.DBA.WA_USER_INFO where WAUI_U_ID = self.account_id;
      if (not is_empty_or_null(lat) and not is_empty_or_null (lng) and exists (select 1 from ODS..SVC_HOST, ODS..APP_PING_REG where SH_NAME = 'GeoURL' and AP_HOST_ID = SH_ID and AP_WAI_ID = self.domain_id)) {
          http (sprintf('<a href="http://geourl.org/near?p=%U" title="GeoURL link" alt="GeoURL link" class="gems"><img src="http://i.geourl.org/geourl.png" border="0"/></a>', ENEWS.WA.enews_url (self.domain_id)));
          http ('<div style="border-top: 1px solid #7f94a5;"></div>');
      }

        S := ENEWS.WA.dav_url (self.domain_id);
        http (sprintf('<a href="%sOFM.%s" target="_blank" title="%s export" alt="%s export" class="gems"><img src="image/rss-icon-16.gif" border="0" alt="%s export" /> %s</a>', S, 'rss', 'RSS', 'RSS', 'RSS', 'RSS'));
        http (sprintf('<a href="%sOFM.%s" target="_blank" title="%s export" alt="%s export" class="gems"><img src="image/blue-icon-16.gif" border="0" alt="%s export" /> %s</a>', S, 'atom', 'ATOM', 'ATOM', 'ATOM', 'Atom'));
        http (sprintf('<a href="%sOFM.%s" target="_blank" title="%s export" alt="%s export" class="gems"><img src="image/rdf-icon-16.gif" border="0" alt="%s export" /> %s</a>', S, 'rdf', 'RDF', 'RDF', 'RDF', 'RDF'));

        http ('<div style="border-top: 1px solid #7f94a5;"></div>');
        http (sprintf('<a href="%sOFM.%s" target="_blank" title="%s export" alt="%s export" class="gems"><img src="image/blue-icon-16.gif" border="0" alt="%s export" /> %s</a>', S, 'opml', 'OPML', 'OPML', 'OPML', 'OPML'));
        http (sprintf('<a href="%sOFM.%s" target="_blank" title="%s export" alt="%s export" class="gems"><img src="image/blue-icon-16.gif" border="0" alt="%s export" /> %s</a>', S, 'ocs', 'OCS', 'OCS', 'OCS', 'OCS'));

        http ('<div style="border-top: 1px solid #7f94a5;"></div>');
        http (sprintf ('<a href="%s" target="_blank" title="FOAF export" alt="FOAF export" class="gems"><img src="image/foaf.png" border="0" alt="FOAF export" /> FOAF</a>', ENEWS.WA.foaf_url (self.domain_id)));

        http ('<div style="border-top: 1px solid #7f94a5;"></div>');
        S := sprintf ('http://%s/dataspace/%U/subscriptions/%U/', DB.DBA.wa_cname (), ENEWS.WA.domain_owner_name (self.domain_id), ENEWS.WA.utf2wide (ENEWS.WA.domain_name (self.domain_id)));
        http (sprintf('<a href="%ssioc.%s" title="%s" alt="%s" class="gems"><img src="image/rdf-icon-16.gif" border="0" alt="%s export" /> %s</a>', S, 'rdf', 'SIOC (RDF/XML)', 'SIOC (RDF/XML)', 'SIOC (RDF/XML)', 'SIOC (RDF/XML)'));
        http (sprintf('<a href="%ssioc.%s" title="%s" alt="%s" class="gems"><img src="image/rdf-icon-16.gif" border="0" alt="%s export" /> %s</a>', S, 'ttl', 'SIOC (N3/Turtle)', 'SIOC (N3/Turtle)', 'SIOC (N3/Turtle)', 'SIOC (N3/Turtle)'));
      ?>
    </div>
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
      OFM version: <?V registry_get('_enews2_version_') ?><br/>
      OFM build date: <?V registry_get('_enews2_build_') ?><br/>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:url">
    <v:variable>
      <xsl:attribute name="name"><xsl:value-of select="@name"/>_allowed</xsl:attribute>
      <xsl:attribute name="persist">1</xsl:attribute>
      <xsl:attribute name="type">varchar</xsl:attribute>
      <xsl:attribute name="default"><xsl:choose><xsl:when test="@allowed">'<xsl:value-of select="@allowed"/>'</xsl:when><xsl:otherwise>null</xsl:otherwise></xsl:choose></xsl:attribute>
    </v:variable>
    <v:url>
      <xsl:copy-of select="@name"/>
      <xsl:copy-of select="@format"/>
      <xsl:copy-of select="@value"/>
      <xsl:copy-of select="@url"/>
      &lt;?vsp if (self.nav_pos_fixed) { ?&gt;
      <xsl:apply-templates select="node()|processing-instruction()"/>
      &lt;?vsp } ?&gt;
    </v:url>
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
      <xsl:element name="v:url">
      <xsl:attribute name="url">javascript: showTab(\'<xsl:value-of select="@tab" />\', <xsl:value-of select="@tabsCount" />, <xsl:value-of select="@tabNo" />);</xsl:attribute>
        <xsl:attribute name="value"><xsl:value-of select="@caption"/></xsl:attribute>
      <xsl:attribute name="xhtml_id"><xsl:value-of select="concat(@tab, '_tab_', @tabNo)" /></xsl:attribute>
      <xsl:attribute name="xhtml_class">tab noapp</xsl:attribute>
      </xsl:element>
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

</xsl:stylesheet>
