<?xml version="1.0"?>
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
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:v="http://www.openlinksw.com/vspx/" exclude-result-prefixes="v" xmlns:vm="http://www.openlinksw.com/vspx/weblog/">
  <xsl:output method="xml" indent="yes" cdata-section-elements="style"/>

  <xsl:template match="vm:page">
    <v:variable name="template_preview_mode" type="varchar" default="null" persist="session"/>
    <v:variable name="preview_template_name" type="varchar" default="null" persist="session"/>
    <v:variable name="preview_css_name" type="varchar" default="null" persist="session"/>
    <v:variable name="domain" type="varchar" default="null" persist="0"/>
    <v:variable name="uid" type="varchar" default="null" persist="session"/>
    <v:variable name="blogid" type="varchar" default="''"/>
    <v:variable name="page" type="varchar" default="''"/>
    <v:variable name="title" type="varchar" default="''"/>
    <v:variable name="about" type="varchar" default="''"/>
    <v:before-render>
      <![CDATA[
        connection_set('uid', connection_get('vspx_user'));
      ]]>
    </v:before-render>
    <v:on-init>
      <![CDATA[
        declare uid varchar;
        self.blogid := get_keyword('blog_id', params);
        self.sid := get_keyword('sid', params);
        self.realm := get_keyword('realm', params);
        self.domain := http_map_get('vhost');
        self.page := get_keyword('page', params, '');
        whenever not found goto not_found;
        select
          BI_TITLE,
          coalesce(BI_ABOUT, '')
        into
          self.title,
          self.about
        from
          BLOG.DBA.SYS_BLOG_INFO
        where
	  BI_BLOG_ID = self.blogid;
	select VS_UID into uid from VSPX_SESSION where VS_SID = self.sid and VS_REALM = self.realm;
	connection_set ('vspx_user', uid);
        not_found:
        connection_set('blogid', self.blogid);
        set http_charset='utf-8';
      ]]>
    </v:on-init>
    <?vsp
      BLOG.DBA.BLOG_REFFERAL_REGISTER (self.blogid, lines, params);
    ?>
    <html>
      <xsl:apply-templates/>
    </html>
  </xsl:template>

  <xsl:template match="vm:blog-title">
    <v:label value="--self.title"/>
  </xsl:template>

  <xsl:template match="vm:page-title">
    <xsl:if test="count(ancestor::vm:header)=0">
      <xsl:message terminate="yes">
        Widget vm:page-title should be placed inside vm:header only
      </xsl:message>
    </xsl:if>
    <xsl:if test="count(@title)=0">
      <xsl:message terminate="yes">
        Widget vm:page-title should contain mandatory attribute - TITLE
      </xsl:message>
    </xsl:if>
    <title>
      <v:label format="%V">
        <xsl:attribute name="value">
          <xsl:value-of select="@title"/>
        </xsl:attribute>
      </v:label>
    </title>
  </xsl:template>

  <xsl:template match="vm:blog-about">
    <v:label value="--self.about"/>
  </xsl:template>

  <xsl:template match="vm:header">
    <head>
      <xsl:apply-templates/>
    </head>
  </xsl:template>

  <xsl:template match="vm:body">
    <body>
      <v:form type="simple" name="page_form" method="POST">
        <xsl:apply-templates/>
      </v:form>
    </body>
  </xsl:template>

  <xsl:template match="vm:style">
    <xsl:choose>
      <xsl:when test="@url">
        <link rel="stylesheet" type="text/css">
          <xsl:attribute name="href">
            <xsl:value-of select="@url"/>
          </xsl:attribute>
        </link>
      </xsl:when>
      <xsl:otherwise>
        <style>
          <xsl:value-of select="."/>
        </style>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="vm:error-message">
    <v:template type="simple"  name="if_error_message" condition="length(get_keyword('error_message', self.vc_event.ve_params, '')) > 0">
    <pre>
      <?vsp
        http_value(get_keyword('error_message', self.vc_event.ve_params, ''));
      ?>
    </pre>
    </v:template>
    <v:template type="simple"  name="if_simple_message" condition="length(get_keyword('message', self.vc_event.ve_params, '')) > 0">
      <h2>
      <?vsp
        http_value(get_keyword('message', self.vc_event.ve_params, ''));
      ?>
      </h2>
    </v:template>
  </xsl:template>

  <xsl:template match="vm:reset-templates">
    <v:template type="simple" name="if_error_message2" condition="length(get_keyword('error_message', self.vc_event.ve_params, '')) > 0">
      <v:button xhtml_class="real_button" action="simple" name="reset_template_settings" value="Reset Template Settings" xhtml_title="Reset Template Settings" xhtml_alt="Reset Template Settings">
        <v:on-post>
          <v:script>
            <![CDATA[
              update
                BLOG.DBA.SYS_BLOG_INFO
              set
                BI_TEMPLATE = NULL,
                BI_CSS = NULL
              where
                BI_BLOG_ID = self.blogid;
              http_request_status ('HTTP/1.1 302 Found');
              http_header(sprintf(
                'Location: index.vspx?page=index&sid=%s&realm=%s\r\n\r\n',
                self.sid ,
                self.realm));
              self.template_preview_mode := NULL;
              self.preview_template_name := NULL;
              self.preview_css_name := NULL;
            ]]>
          </v:script>
        </v:on-post>
      </v:button>
    </v:template>
  </xsl:template>

  <xsl:template match="vm:*">
    Unknown Weblog component "<xsl:value-of select="local-name()" />"
  </xsl:template>

</xsl:stylesheet>
