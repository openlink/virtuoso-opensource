<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2019 OpenLink Software
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
  <xsl:template match="vm:popup_pagewrapper">
    <v:variable name="nav_pos_fixed" type="integer" default="1"/>
    <v:variable name="nav_top" type="integer" default="0"/>
    <xsl:for-each select="//v:variable">
      <xsl:copy-of select="."/>
    </xsl:for-each>
    <xsl:if test="not @clean or @clean = 'no'">
      <div style="padding: 0 0 0.5em 0;">
        <span class="button pointer" onclick="javascript: if (opener != null) opener.focus(); window.close();"><img class="button" src="/ods/images/icons/close_16.png" border="0" alt="Close" title="Close" /> Close</span>
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
    <v:variable name="nav_pos_fixed" type="integer" default="0"/>
    <v:variable name="nav_top" type="integer" default="0"/>
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
            <?vsp
              if (0)
              {
            ?>
                <v:button name="searchHead" action="simple" style="url" value="Submit">
            	<v:on-post>
                    <![CDATA[
                      declare S, q, params any;

                      params := e.ve_params;
                      q := trim (get_keyword ('q', params, ''));
                      S := case when q <> ''then sprintf ('&q=%s&step=1', q) else '' end;
                      self.vc_redirect (ENEWS.WA.utf2wide (ENEWS.WA.page_url (self.domain_id, sprintf ('search.vspx?mode=%s%s', get_keyword ('select', params, 'advanced'), S))));
                      self.vc_data_bind(e);
                     ]]>
            	</v:on-post>
  	        </v:button>
            <?vsp
              }
            ?>
            <div style="float: right; text-align: right; padding-right: 0.5em; padding-top: 20px;">
              <v:text name="q" value="" fmt-function="ENEWS.WA.utf2wide" xhtml_onkeypress="javascript: if (checkNotEnter(event)) return true; vspxPost(\'searchHead\', \'select\', \'simple\'); return false;"/>
              &amp;nbsp;
              <a href="<?vsp http (ENEWS.WA.utf2wide (ENEWS.WA.page_url (self.domain_id, 'search.vspx?mode=simple', self.sid, self.realm))); ?>" onclick="vspxPost('searchHead', 'select', 'simple'); return false;" title="Simple Search">Search</a>
            |
              <a href="<?vsp http (ENEWS.WA.utf2wide (ENEWS.WA.page_url (self.domain_id, 'search.vspx?mode=advanced', self.sid, self.realm))); ?>" onclick="vspxPost('searchHead', 'select', 'advanced'); return false;" title="Advanced">Advanced</a>
          </div>
        </v:template>
      </div>
        <div style="clear: both; border: solid #935000; border-width: 0px 0px 1px 0px;">
          <div style="float: left; padding-left: 0.5em;">
            <?vsp http (ENEWS.WA.utf2wide (ENEWS.WA.banner_links (self.domain_id, self.sid, self.realm))); ?>
          </div>
          <div style="float: right; padding-right: 0.5em;">
            <vm:if test="self.account_rights = 'W'">
              <a href="<?vsp http (ENEWS.WA.utf2wide (ENEWS.WA.page_url (self.domain_id, 'settings.vspx', self.sid, self.realm))); ?>" title="Preferences">Preferences</a>
              |
            </vm:if>
            <a href="<?vsp http (ENEWS.WA.utf2wide (ENEWS.WA.page_url (self.domain_id, 'about.vsp'))); ?>" onclick="javascript: Feeds.aboutDialog(); return false;" title="About">About</a>
      </div>
          <br style="clear: both; line-height: 0.1em" />
        </div>  
      <v:include url="enews_login.vspx"/>
      <table id="MTB">
        <tr>
          <!-- Navigation left column -->
          <v:template type="simple" enabled="--either(gt(self.domain_id, 0), 1, 0)">
            <td id="LC">
                <v:template type="simple" enabled="--case when (self.account_rights <> '') then 1 else 0 end">
              <xsl:call-template name="vm:others"/>
                </v:template>
              <xsl:call-template name="vm:formats"/>
            </td>
      	  </v:template>
          <td id="RC">
              <v:tree show-root="0" multi-branch="0" orientation="horizontal" start-path="--case when ENEWS.WA.check_admin (self.account_id) then 'A' else self.account_rights end" root="ENEWS.WA.navigation_root" child-function="ENEWS.WA.navigation_child">
                <v:before-data-bind>
                  <![CDATA[
                    declare page_name any;

                    page_name := ENEWS.WA.page_name ();
                    if (page_name = 'error.vspx')
                    {
                      self.nav_pos_fixed := 1;
                    }
                    else if (not self.nav_top and page_name <> '')
                    {
                      self.nav_pos_fixed := ENEWS.WA.check_grants (self.account_rights, page_name);
                      control.vc_open_at (sprintf ('//*[@url = "%s"]', page_name));
                    }
                  ]]>
                </v:before-data-bind>

                <v:node-template>
                  <td nowrap="nowrap" class="<?V case when control.tn_open then 'sel' else '' end ?>">
                    <v:button action="simple" style="url" xhtml_class="--(case when (control.vc_parent as vspx_tree_node).tn_open = 1 then 'sel' else '' end)" value="--(control.vc_parent as vspx_tree_node).tn_value">
                      <v:after-data-bind>
                        <![CDATA[
                          if ((control.vc_parent as vspx_tree_node).tn_open = 1)
                            control.ufl_active := 0;
                          else
                            control.ufl_active := ENEWS.WA.check_grants (self.account_rights, ENEWS.WA.page_name ());
                        ]]>
                      </v:after-data-bind>
                      <v:before-render>
                        <![CDATA[
                          control.bt_anchor := 0;
                          control.bt_url := ENEWS.WA.utf2wide (replace (control.bt_url, sprintf ('/enews2/%d', self.domain_id), ENEWS.WA.page_url (self.domain_id)));
                        ]]>
                      </v:before-render>
                      <v:on-post>
                        <![CDATA[
                          declare node vspx_tree_node;
                          declare tree vspx_control;
                          self.nav_pos_fixed := 0;
                          node := control.vc_parent;
                          tree := node.tn_tree;
                          node.tn_tree.vt_open_at := NULL;
                          self.nav_top := 1;
                          tree.vc_data_bind (e);
                        ]]>
                      </v:on-post>
                    </v:button>
                  </td>
                </v:node-template>
                <v:leaf-template>
                  <td nowrap="nowrap" class="<?V case when control.tn_open then 'sel' else '' end ?>">
                    <v:button action="simple" style="url" xhtml_class="--case when (control.vc_parent as vspx_tree_node).tn_open = 1 then 'sel' else '' end" value="--(control.vc_parent as vspx_tree_node).tn_value">
                      <v:before-render>
                        <![CDATA[
                          control.bt_anchor := 0;
                          control.bt_url := ENEWS.WA.utf2wide (replace (control.bt_url, sprintf ('/enews2/%d', self.domain_id), ENEWS.WA.page_url (self.domain_id)));
                        ]]>
                      </v:before-render>
                    </v:button>
                  </td>
                </v:leaf-template>
                <v:horizontal-template>
                  <table class="nav_bar" cellspacing="0">
                    <tr>
                      <v:node-set />
                      <?vsp
                        if ((control as vspx_tree).vt_node <> control) {
                      ?>
                      <td class="filler"> </td>
                      <?vsp } ?>
                    </tr>
                  </table>
                  <?vsp
                    if ((control as vspx_tree).vt_node = control and not length (childs)) {
                  ?>
                  <div class="nav_bar nav_seperator" >x</div>
                  <?vsp } ?>
                </v:horizontal-template>
              </v:tree>
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
        <?vsp
          declare C any;
          C := vsp_ua_get_cookie_vec(self.vc_event.ve_lines);
        ?>
        <div id="FT" style="display: <?V case when get_keyword ('interface', C, '') = 'js' then 'none' else '' end ?>">
        <div id="FT_L">
          <a href="http://www.openlinksw.com/virtuoso">
              <img alt="Powered by OpenLink Virtuoso Universal Server" src="/ods/images/virt_power_no_border.png" border="0" />
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
      <a href="<?vsp http (ENEWS.WA.utf2wide (ENEWS.WA.page_url (self.domain_id, 'bookmark.vspx', self.sid, self.realm))); ?>" title="Bookmarklet"><img src="image/bmklet_32.png" height="16" width="16" border="0" /> Bookmarklet</a>
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

        S := ENEWS.WA.utf2wide (ENEWS.WA.gems_url (self.domain_id));
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
  <xsl:template match="vm:ds-navigation">
    &lt;?vsp
      {
        declare n_start, n_end, n_total integer;
      declare mode any;
        declare ds vspx_data_set;
      declare _prev, _next vspx_button;

      mode := '<xsl:value-of select="string(@mode)" />';
      ds := case when (udt_instance_of (control, fix_identifier_case ('vspx_data_set'))) then control else control.vc_find_parent (control, 'vspx_data_set') end;
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
        http (sprintf ('%s%d - %d of %d', case when (mode = 'compact') then '' else 'Showing ' end, n_start, n_end, n_total));

  	    _next := control.vc_find_control ('<xsl:value-of select="@data-set"/>_next');
  	    _prev := control.vc_find_control ('<xsl:value-of select="@data-set"/>_prev');
      if ((_next is not null and _next.vc_enabled) or (_prev is not null and _prev.vc_enabled))
            http (' | ');
    ?&gt;
    <v:button name="{@data-set}_first" action="simple" style="url" value="{@mode}" xhtml_alt="First" xhtml_class="navi-button" >
      <v:before-render>
        <![CDATA[
          control.ufl_value := '<img src="/ods/images/skin/pager/p_first.png" border="0" alt="First" title="First"/>' || case when (control.ufl_value = 'compact') then '' else ' First' end;
        ]]>
      </v:before-render>
    </v:button>
    <v:button name="{@data-set}_prev" action="simple" style="url" value="{@mode}" xhtml_alt="Previous" xhtml_class="navi-button">
      <v:before-render>
        <![CDATA[
          control.ufl_value := '<img src="/ods/images/skin/pager/p_prev.png" border="0" alt="Previous" title="Previous"/>' || case when (control.ufl_value = 'compact') then '' else ' Prev' end;
        ]]>
      </v:before-render>
    </v:button>
    <v:button name="{@data-set}_next" action="simple" style="url" value="{@mode}" xhtml_alt="Next" xhtml_class="navi-button">
      <v:before-render>
        <![CDATA[
          control.ufl_value := '<img src="/ods/images/skin/pager/p_next.png" border="0" alt="Next" title="Next"/>' || case when (control.ufl_value = 'compact') then '' else ' Next' end;;
        ]]>
      </v:before-render>
    </v:button>
    <v:button name="{@data-set}_last" action="simple" style="url" value="{@mode}" xhtml_alt="Last" xhtml_class="navi-button">
      <v:before-render>
        <![CDATA[
          control.ufl_value := '<img src="/ods/images/skin/pager/p_last.png" border="0" alt="Last" title="Last"/>' || case when (control.ufl_value = 'compact') then '' else ' Last ' end;;
        ]]>
      </v:before-render>
    </v:button>
    &lt;?vsp } ?&gt;
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
      <a href="http://www.openlinksw.com/virtuoso"><img title="Powered by OpenLink Virtuoso Universal Server" src="/ods/images/PoweredByVirtuoso.gif" border="0" /></a>
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
    <div>
      <xsl:attribute name="id"><xsl:value-of select="concat(@tab, '_tab_', @tabNo)" /></xsl:attribute>
      <xsl:attribute name="class">tab <xsl:if test="@activeTab = @tab">activeTab</xsl:if></xsl:attribute>
      <xsl:attribute name="onclick">javascript: showTab('<xsl:value-of select="@tab" />', <xsl:value-of select="@tabsCount" />, <xsl:value-of select="@tabNo" />);</xsl:attribute>
      <xsl:value-of select="@caption"/>
    </div>
  </xsl:template>

</xsl:stylesheet>
