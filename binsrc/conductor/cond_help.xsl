<?xml version="1.0" encoding="UTF-8" ?>
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
 -
-->
  MARKUP

  vm:help_button - a button that toggles visibility of vm:help_viewport

  Attributes
    style = "button" | "anchor"

  vm:help_viewport - help text viewer

  Attributes
    title = <string> - title text

  vm:tooltip - an icon which pops up a short help text at cursor position with settable delay time

  XHTML CLASSES

  input.help_toggle    = help button if type=button
  a.help_toggle        = help "button" if style="anchor"

  div.help_viewport    = top-level container for the help "window"
  div.help_title       = help viewport title area
  div.help_body        = main area of help text
  div.help_footer      = footer area for dismiss link, etc.
  span.help_title      = help title

  DEPENDENCIES

  Needs JavaScript functions provided by cond_help.js which needs be loaded on page.
  A CSS stylesheet cond_help.css can be used to produce default output style.
  Client support for DOM level 2 Core

-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0"
                xmlns:v="http://www.openlinksw.com/vspx/"
                xmlns:xhtml="http://www.w3.org/1999/xhtml"
                xmlns:vm="http://www.openlinksw.com/vspx/macro">

  <xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>

  <xsl:template match="vm:help_button">
    <xsl:choose>
      <xsl:when test="@style = 'button'">
        <xsl:element name="input">
          <xsl:attribute name="name">help_toggle</xsl:attribute>
          <xsl:attribute name="type">button</xsl:attribute>
          <xsl:attribute name="class">help_toggle</xsl:attribute>
          <xsl:attribute name="value">Help</xsl:attribute>
          <xsl:attribute name="onClick">
            <xsl:choose>
              <xsl:when test="@display = 'popup'">
                javascript:vm_help_toggle_popup('<xsl:value-of select="@title"/>');
              </xsl:when>
              <xsl:otherwise>
                javascript:vm_help_toggle();
              </xsl:otherwise>
            </xsl:choose>
          </xsl:attribute>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:element name="a">
          <xsl:attribute name="name">help_toggle</xsl:attribute>
          <xsl:attribute name="class">help_toggle</xsl:attribute>
          <xsl:attribute name="href">#</xsl:attribute>
          <xsl:attribute name="onClick">
            <xsl:choose>
              <xsl:when test="@display = 'popup'">
                javascript:vm_help_toggle_popup();
              </xsl:when>
              <xsl:otherwise>
                javascript:vm_help_toggle();
              </xsl:otherwise>
            </xsl:choose>
          </xsl:attribute>
          Help
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="vm:help_viewport">
    <!-- Commented because of IE inconsistency-->
    <!--<script src="help.js" language="JavaScript" type="text/javascript"></script>-->
    <link rel="stylesheet" href="help.css" type="text/css"/>
    <div class="help_viewport" name="help_viewport" style="display: none;">
      <div class="help_title">
        <span class="help_title"><xsl:value-of select="@title"/></span>
      </div>
      <div class="help_body">
        <xsl:apply-templates/>
      </div>
      <div class="help_footer">
        <a class="help_dismiss" href="#" onClick="javascript:vm_help_toggle();">Dismiss</a>
      </div>
    </div>
  </xsl:template>

  <xsl:template match="vm:tooltip">
    <xsl:element name="a">
      <xsl:attribute name="class">tooltip</xsl:attribute>
      <xsl:attribute name="href">#</xsl:attribute>
      <xsl:attribute name="onMouseOver">javascript:show_tooltip ('<xsl:value-of select="@text"/>')</xsl:attribute>
      ?
    </xsl:element>
  </xsl:template>
</xsl:stylesheet>
