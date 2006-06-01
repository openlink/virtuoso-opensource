<?xml version="1.0"?>
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
<!-- simple page widgets -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:v="http://www.openlinksw.com/vspx/"
    xmlns:vm="http://www.openlinksw.com/vspx/weblog/">
    <xsl:template match="vm:page">
      <xsl:call-template name="vars" />
	  <v:on-init><![CDATA[
	   set http_charset='UTF-8';
	   ]]></v:on-init>
      <!--html-->
	<xsl:apply-templates />
        <vm:nntpf-copyright/>
      <!--/html-->
      <?vsp
        declare ht_stat varchar;
        ht_stat := http_request_status_get ();
        if (ht_stat is not null and ht_stat like 'HTTP/1._ 30_ %')
	  {
	    http_rewrite ();
	  }
      ?>
    </xsl:template>
    <xsl:template match="vm:header">
      <header>
        <v:include url="virtuoso_app_links.xhtml"/>
	<link rel="stylesheet" type="text/css" href="nntpf.css" />
	<xsl:apply-templates />
      </header>
    </xsl:template>
    <xsl:template match="vm:body">
      <body>
	<v:form name="page_form" type="simple" method="POST">
	  <xsl:apply-templates />
	</v:form>
      </body>
    </xsl:template>
    <xsl:template match="vm:js">
    <script type="text/javascript">
      function doPostN (frm_name, name)
        {
          var frm = document.forms[frm_name];
          frm.__submit_func.value = '__submit__';
          frm.__submit_func.name = name;
          frm.submit ();
        }
      function doPostValueN (frm_name, name, value)
	{
	  var frm = document.forms[frm_name];
	  frm.__submit_func.value = value;
	  frm.__submit_func.name = name;
	  frm.action="#1";
	  frm.submit ();
	}
      function doPostValueNT (frm_name, name, value)
	{
	  var frm = document.forms[frm_name];
	  frm.action="nntpf_nthread_view.vspx";
	  frm.group.value = value;
	  frm.submit ();
	}
      function doPostValueT (frm_name, name, value)
	{
	  var frm = document.forms[frm_name];
	  frm.action="nntpf_thread_view.vspx";
	  frm.group.value = value;
	  frm.submit ();
	}
      function doPostValueRSS (frm_name, name, value)
	{
	  var frm = document.forms[frm_name];
	  frm.action="nntpf_rss_group.vspx";
	  frm.group.value = value;
	  frm.submit ();
	}
    </script>
    <noscript>
	   Warning: The browser not support or not enabled JavaScript. Some controls may not work properly.
    </noscript>

    </xsl:template>
    <xsl:template match="vm:title">
      <title>
	<xsl:apply-templates />
      </title>
    </xsl:template>
    <xsl:template match="vm:search">
	<xsl:apply-templates />
    </xsl:template>
    <xsl:template match="vm:register">
      <vm:template enabled="1">
	<a href="../wa/register.vspx?ret=/nntpf/">Register</a>
      </vm:template>
    </xsl:template>
    <xsl:template match="vm:variable" />
    <xsl:template name="vars">
      <v:variable name="u_id" type="int" default="null" persist="session" />
      <v:variable name="u_name" type="varchar" default="null" persist="session" />
      <v:variable name="u_full_name" type="varchar" default="null" persist="session" />
      <v:variable name="u_e_mail" type="varchar" default="null" persist="session" />
      <v:variable name="search_trm" type="varchar" default="null" persist="session" />
      <v:variable name="url" type="varchar" default="'nntpf_main.vspx'" persist="pagestate" param-name="URL" />
      <v:variable name="users_length" persist="1" type="integer" default="10" />
      <v:variable name="login_attempts" type="integer" default="0" persist="1" />
      <v:variable name="grp_sel_no_thr" type="integer" default="0" persist="1" />
      <v:variable name="ndays" type="any" default="null" />
      <v:variable name="grp_sel_thr" type="integer" default="0" persist="1" />
      <v:variable name="size_is_changed" type="integer" default="0" persist="1" />
      <v:variable name="list_len" type="integer" default="10" persist="1" />
      <!--v:variable name="article_list" type="any" default="1" persist="1" /-->
      <v:variable name="article_list_lenght" type="integer" default="10" persist="1" />
      <v:variable name="fordate" type="date" default="null"/>
      <v:variable name="dprev" type="date" default="null"/>
      <v:variable name="dnext" type="date" default="null"/>
      <v:variable name="post_body" type="any" default="null"/>
      <v:variable name="post_from" type="any" default="null"/>
      <v:variable name="post_subj" type="any" default="null"/>
      <v:variable name="post_old_hdr" type="any" default="null"/>
      <v:variable name="nntp_cal_day" type="datetime" default="null" param-name="date" persist="session"/>
      <v:variable name="external_home_url" type="varchar" default="'../nntpf/nntpf_main.vspx'" persist="session"/>
      <v:variable name="grp_list" persist="0" type="any" default="NULL"/>
      <v:variable name="cur_art" persist="0" type="integer" default="NULL"/>

      <xsl:for-each select="//vm:variable">
	<v:variable>
	  <xsl:copy-of select="@*"/>
	</v:variable>
      </xsl:for-each>
    </xsl:template>
    <xsl:template match="vm:template">
      <v:template type="simple">
	<xsl:attribute name="name">tm_<xsl:value-of select="generate-id()"/></xsl:attribute>
	<xsl:copy-of select="@*"/>
	<xsl:apply-templates />
      </v:template>
    </xsl:template>
    <xsl:template match="vm:label">
      <v:label>
	<xsl:attribute name="name">ll_<xsl:value-of select="generate-id()"/></xsl:attribute>
	<xsl:copy-of select="@*"/>
	<xsl:apply-templates />
      </v:label>
    </xsl:template>
    <xsl:template match="vm:url">
      <v:url>
	<xsl:attribute name="name">url_<xsl:value-of select="generate-id()"/></xsl:attribute>
	<xsl:copy-of select="@*"/>
	<xsl:apply-templates />
      </v:url>
    </xsl:template>
    <xsl:template match="vm:home-link">
      <vm:url url="nntpf_main.vspx">
	<xsl:attribute name="value"><xsl:apply-templates/></xsl:attribute>
      </vm:url>
    </xsl:template>
    <xsl:template match="vm:nntpf-title">
      <xsl:call-template name="title"/>
      <v:template type="simple" condition="self.vc_authenticated">
        <table class="user_id">
          <tr class="user_id">
            <td class="user_id">
                Logged in as <?V case when self.u_full_name <> '' then wa_utf8_to_wide (self.u_full_name) else self.u_name end ?>
                <v:url value="--'&nbsp;Logout'"
                       format="%s"
                       url="--'nntpf_logout.vspx'" />
            </td>
          </tr>
        </table>
      </v:template>
    </xsl:template>

    <xsl:template match="vm:nntpf-search">
      <xsl:call-template name="search"/>
    </xsl:template>

    <xsl:template match="vm:post-login">
      <xsl:call-template name="vm:post_login"/>
    </xsl:template>

    <xsl:template match="vm:nntpf-copyright">
      <div class="copyright">
         Articles belong to their respective posters.
         Application <vm:opl-copyright-str from="2004"/>
      </div>
    </xsl:template>

    <xsl:template match="vm:*">
      <p class="error">Control not implemented: "<xsl:value-of select="local-name (.)"/>"</p>
    </xsl:template>

</xsl:stylesheet>
