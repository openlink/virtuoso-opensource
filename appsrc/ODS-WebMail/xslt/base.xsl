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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:ui="http://www.openlinksw.bg/XMLSchema/ui">

  <xsl:include href="date_time.xsl"/>

  <!-- ========================================================================== -->
  <xsl:template name="nbsp">
    <xsl:param name="count" select="1"/>
    <xsl:if test="$count != 0">
      <xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text>
      <xsl:call-template name="nbsp">
        <xsl:with-param name="count" select="$count - 1"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="copy">
    <xsl:text disable-output-escaping="yes">&amp;copy;</xsl:text>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="middot">
    <xsl:text disable-output-escaping="yes">&amp;middot;</xsl:text>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="curren">
    <xsl:text disable-output-escaping="yes">&amp;curren;</xsl:text>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="raquo">
    <xsl:text disable-output-escaping="yes">&amp;raquo;</xsl:text>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="make_href">
    <xsl:param name="url"/>
    <xsl:param name="params"/>
    <xsl:param name="class"/>
    <xsl:param name="style"/>
    <xsl:param name="target"/>
    <xsl:param name="onclick"/>
    <xsl:param name="onmousedown"/>
    <xsl:param name="label"/>
    <xsl:param name="deflabel"><font color="FF0000"><b>Error !!!</b></font></xsl:param>
    <xsl:param name="title"/>
    <xsl:param name="id"/>
    <xsl:param name="no_sid">0</xsl:param>
    <xsl:param name="img"/>
    <xsl:param name="img_width"/>
    <xsl:param name="img_height"/>
    <xsl:param name="img_hspace"/>
    <xsl:param name="img_vspace"/>
    <xsl:param name="img_align"/>
    <xsl:param name="img_class"/>
    <xsl:param name="img_style"/>
    <xsl:param name="img_with_sid">0</xsl:param>
    <xsl:param name="img_params"/>
    <xsl:param name="img_label"/>
    <xsl:param name="ovr_mount_point"/>

    <xsl:choose>
      <xsl:when test="$url = ''">
        <xsl:variable name="url"><xsl:value-of select="$iri" /></xsl:variable>
       <xsl:variable name="label">Home</xsl:variable>
      </xsl:when>
      <xsl:when test="not(starts-with($url, 'javascript')) and not(starts-with($url, 'http'))">
        <xsl:variable name="url"><xsl:value-of select="$iri" />/<xsl:value-of select="$url" /></xsl:variable>
      </xsl:when>
    </xsl:choose>

    <xsl:choose>
      <xsl:when test="starts-with($url,'javascript')">
        <xsl:variable name="pparams"></xsl:variable>
      </xsl:when>
      <xsl:when test="$no_sid = 1 and $params != ''">
        <xsl:variable name="pparams">?<xsl:value-of select="$params"/></xsl:variable>
      </xsl:when>
      <xsl:when test="$no_sid = 1 and $params = ''">
        <xsl:variable name="pparams"></xsl:variable>
      </xsl:when>
      <xsl:when test="$no_sid = 0 and $params = ''">
        <xsl:variable name="pparams">?sid=<xsl:value-of select="$sid"/>&amp;realm=<xsl:value-of select="$realm"/></xsl:variable>
      </xsl:when>
      <xsl:when test="$no_sid = 0 and $params != ''">
        <xsl:variable name="pparams">?sid=<xsl:value-of select="$sid"/>&amp;realm=<xsl:value-of select="$realm"/>&amp;<xsl:value-of select="$params"/></xsl:variable>
      </xsl:when>
       <xsl:otherwise>
        <xsl:variable name="pparams">buuuuuuuuug</xsl:variable>
      </xsl:otherwise>
    </xsl:choose>

    <xsl:choose>
      <xsl:when test="$img != ''">
        <xsl:variable name="label">
          <xsl:call-template name="make_img">
            <xsl:with-param name="src"      select="$img"/>
            <xsl:with-param name="width"    select="$img_width"/>
            <xsl:with-param name="height"   select="$img_height"/>
            <xsl:with-param name="alt"      select="$label"/>
            <xsl:with-param name="hspace"   select="$img_hspace"/>
            <xsl:with-param name="vspace"   select="$img_vspace"/>
            <xsl:with-param name="align"    select="$img_align"/>
            <xsl:with-param name="class"    select="$img_class"/>
            <xsl:with-param name="style"    select="$img_style"/>
            <xsl:with-param name="with_sid" select="$img_with_sid"/>
            <xsl:with-param name="params"   select="$img_params"/>
          </xsl:call-template>
          <xsl:value-of select="$img_label"/>
        </xsl:variable>
      </xsl:when>
      <xsl:when test="$label != ''">
        <xsl:variable name="label"><xsl:value-of select="$label"/></xsl:variable>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="label"><xsl:value-of select="$deflabel"/></xsl:variable>
      </xsl:otherwise>
    </xsl:choose>

    <xsl:if test="$title = ''">
      <xsl:variable name="$title"><xsl:value-of select="$label"/></xsl:variable>
    </xsl:if>

    <xsl:choose>
      <xsl:when test="$target = 'help-popup'">
        <xsl:variable name="onclick">javascript: windowShow('<xsl:value-of select="$url" /><xsl:value-of select="$pparams" />', 'help');</xsl:variable>
        <xsl:variable name="href">#</xsl:variable>
        <xsl:variable name="target"></xsl:variable>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="href"><xsl:value-of select="$url"/><xsl:value-of select="$pparams"/></xsl:variable>
      </xsl:otherwise>
    </xsl:choose>

    <a>
      <xsl:attribute name="href"><xsl:value-of select="$href"/></xsl:attribute>
      <xsl:if test="$class       != ''"><xsl:attribute name="class"><xsl:value-of select="$class"/></xsl:attribute></xsl:if>
      <xsl:if test="$style       != ''"><xsl:attribute name="style"><xsl:value-of select="$style"/></xsl:attribute></xsl:if>
      <xsl:if test="$onclick     != ''"><xsl:attribute name="onClick"><xsl:value-of select="$onclick"/></xsl:attribute></xsl:if>
      <xsl:if test="$onmousedown != ''"><xsl:attribute name="onMouseDown"><xsl:value-of select="$onmousedown"/></xsl:attribute></xsl:if>
      <xsl:if test="$target      != ''"><xsl:attribute name="target"><xsl:value-of select="$target"/></xsl:attribute></xsl:if>
      <xsl:if test="$title       != ''"><xsl:attribute name="title"><xsl:value-of select="$title"/></xsl:attribute></xsl:if>
      <xsl:if test="$id          != ''"><xsl:attribute name="id"><xsl:value-of select="$id"/></xsl:attribute></xsl:if>
      <xsl:copy-of select="$label" />
    </a>

  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="make_submit">
    <xsl:param name="name"></xsl:param>
    <xsl:param name="value"></xsl:param>
    <xsl:param name="id"></xsl:param>
    <xsl:param name="src">-1</xsl:param>
    <xsl:param name="button">-1</xsl:param>
    <xsl:param name="align"/>
    <xsl:param name="hspace">-1</xsl:param>
    <xsl:param name="vspace">-1</xsl:param>
    <xsl:param name="border">-1</xsl:param>
    <xsl:param name="class">-1</xsl:param>
    <xsl:param name="onclick">-1</xsl:param>
    <xsl:param name="disabled">-1</xsl:param>
    <xsl:param name="tabindex">-1</xsl:param>
    <xsl:param name="alt">-1</xsl:param>
    <xsl:choose>
      <xsl:when test="$src != '-1' and $src != ''">
        <xsl:variable name="type">image</xsl:variable>
        <xsl:variable name="pname"><xsl:value-of select="$name"/></xsl:variable>
      </xsl:when>
      <xsl:when test="$button != '-1'">
        <xsl:variable name="type">button</xsl:variable>
        <xsl:variable name="pname"><xsl:value-of select="$name"/></xsl:variable>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="type">submit</xsl:variable>
        <xsl:variable name="pname"><xsl:value-of select="$name"/>.x</xsl:variable>
      </xsl:otherwise>
    </xsl:choose>

    <input>
      <xsl:attribute name="type"><xsl:value-of select="$type"/></xsl:attribute>
      <xsl:attribute name="name"><xsl:value-of select="$pname"/></xsl:attribute>
      <xsl:attribute name="value"><xsl:value-of select="$value"/></xsl:attribute>
      <xsl:attribute name="alt"><xsl:value-of select="$value"/></xsl:attribute>
      <xsl:attribute name="border">0</xsl:attribute>
      <xsl:if test="$id != ''">
        <xsl:attribute name="id"><xsl:value-of select="$id"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="$src != '-1'">
        <xsl:attribute name="src"><xsl:value-of select="$src"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="$class != '-1'">
        <xsl:attribute name="class"><xsl:value-of select="$class"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="$alt != '-1'">
        <xsl:attribute name="alt"><xsl:value-of select="$alt"/></xsl:attribute><xsl:attribute name="title"><xsl:value-of select="$alt"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="$onclick != '-1'">
        <xsl:attribute name="onClick"><xsl:value-of select="$onclick"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="$border != '-1'">
        <xsl:attribute name="border"><xsl:value-of select="$border"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="$align">
        <xsl:attribute name="align"><xsl:value-of select="$align"/>
      </xsl:attribute></xsl:if>
      <xsl:if test="$hspace != '-1'">
        <xsl:attribute name="hspace"><xsl:value-of select="$hspace"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="$vspace != '-1'">
        <xsl:attribute name="vspace"><xsl:value-of select="$vspace"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="$disabled != '-1'">
        <xsl:attribute name="disabled">disabled</xsl:attribute>
      </xsl:if>
    </input>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="make_img">
    <xsl:param name="src">/not_found.gif</xsl:param>
    <xsl:param name="width"/>
    <xsl:param name="height"/>
    <xsl:param name="alt"/>
    <xsl:param name="hspace"/>
    <xsl:param name="vspace"/>
    <xsl:param name="align"/>
    <xsl:param name="border">0</xsl:param>
    <xsl:param name="with_sid">0</xsl:param>
    <xsl:param name="params"/>
    <xsl:param name="class"/>
    <xsl:param name="style"/>

    <xsl:choose>
      <xsl:when test="$with_sid = 0 and $params != ''">
        <xsl:variable name="pparams">?<xsl:value-of select="$params"/></xsl:variable>
      </xsl:when>
      <xsl:when test="$with_sid = 0 and $params = ''">
        <xsl:variable name="pparams"></xsl:variable>
      </xsl:when>
      <xsl:when test="$with_sid = 1 and $params = ''">
        <xsl:variable name="pparams">?sid=<xsl:value-of select="$sid"/></xsl:variable>
      </xsl:when>
      <xsl:when test="$with_sid = 1 and $params != ''">
        <xsl:variable name="pparams">?sid=<xsl:value-of select="$sid"/>&amp;realm=<xsl:value-of select="$realm"/>&amp;<xsl:value-of select="$params"/></xsl:variable>
      </xsl:when>
       <xsl:otherwise>
        <xsl:variable name="pparams">buuuuuuuuug</xsl:variable>
      </xsl:otherwise>
    </xsl:choose>

    <img>
      <xsl:attribute name="src"><xsl:value-of select="$src"/><xsl:value-of select="$pparams"/></xsl:attribute>
      <xsl:if test="$width"><xsl:attribute name="width"><xsl:value-of select="$width"/></xsl:attribute></xsl:if>
      <xsl:if test="$height"><xsl:attribute name="height"><xsl:value-of select="$height"/></xsl:attribute></xsl:if>
      <xsl:if test="$alt"><xsl:attribute name="alt"><xsl:value-of select="$alt"/></xsl:attribute><xsl:attribute name="title"><xsl:value-of select="$alt"/></xsl:attribute></xsl:if>
      <xsl:if test="$hspace"><xsl:attribute name="hspace"><xsl:value-of select="$hspace"/></xsl:attribute></xsl:if>
      <xsl:if test="$vspace"><xsl:attribute name="vspace"><xsl:value-of select="$vspace"/></xsl:attribute></xsl:if>
      <xsl:if test="$align"><xsl:attribute name="align"><xsl:value-of select="$align"/></xsl:attribute></xsl:if>
      <xsl:if test="$border"><xsl:attribute name="border"><xsl:value-of select="$border"/></xsl:attribute></xsl:if>
      <xsl:if test="$class"><xsl:attribute name="class"><xsl:value-of select="$class"/></xsl:attribute></xsl:if>
      <xsl:if test="$style"><xsl:attribute name="style"><xsl:value-of select="$style"/></xsl:attribute></xsl:if>
    </img>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="make_select">
    <xsl:param name="name"/>
    <xsl:param name="id" />
    <xsl:param name="selected"/>
    <xsl:param name="selected_def"/>
    <xsl:param name="list"/>
    <xsl:param name="listname"/>
    <xsl:param name="treelist">0</xsl:param>
    <xsl:param name="size">1</xsl:param>
    <xsl:param name="class" />
    <xsl:param name="style" />
    <xsl:param name="onclick">-1</xsl:param>
    <xsl:param name="onchange">-1</xsl:param>
    <xsl:param name="onblur">-1</xsl:param>
    <xsl:param name="separ1">:</xsl:param>
    <xsl:param name="separ2">;</xsl:param>
    <xsl:param name="tabindex">-1</xsl:param>
    <xsl:param name="disabled">-1</xsl:param>

    <xsl:if test="$selected = '' or not($selected)">
      <xsl:variable name="selected" select="$selected_def"/>
    </xsl:if>

    <!-- begin element definition -->
    <xsl:element name="select">
      <xsl:attribute name="name"><xsl:value-of select="$name"/></xsl:attribute>
      <xsl:attribute name="size"><xsl:value-of select="$size"/></xsl:attribute>

      <!-- process conditional attributes -->
      <xsl:if test="$id">
        <xsl:attribute name="id"><xsl:value-of select="$id" /></xsl:attribute>
      </xsl:if>
      <xsl:if test="$class">
        <xsl:attribute name="class"><xsl:value-of select="$class"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="$style">
        <xsl:attribute name="style"><xsl:value-of select="$style" /></xsl:attribute>
      </xsl:if>
      <xsl:if test="$onclick != '-1'">
        <xsl:attribute name="onClick"><xsl:value-of select="$onclick"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="$onchange != '-1'">
        <xsl:attribute name="onChange"><xsl:value-of select="$onchange"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="$onblur != '-1'">
        <xsl:attribute name="onBlur"><xsl:value-of select="$onblur"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="$disabled != '-1'">
        <xsl:attribute name="disabled">disabled</xsl:attribute>
      </xsl:if>

      <!-- process fixed list options (if any) -->
      <xsl:if test="$list != ''">
        <xsl:call-template name="make_select_fixed">
          <xsl:with-param name="list"><xsl:value-of select="$list"/></xsl:with-param>
          <xsl:with-param name="selected"><xsl:value-of select="$selected"/></xsl:with-param>
          <xsl:with-param name="separ1"><xsl:value-of select="$separ1"/></xsl:with-param>
          <xsl:with-param name="separ2"><xsl:value-of select="$separ2"/></xsl:with-param>
        </xsl:call-template>
      </xsl:if>

      <!-- process database list options (if any) -->
      <xsl:if test="$listname != ''">
        <xsl:choose>
          <xsl:when test="$treelist = 1">
            <xsl:for-each select="//ui:List[@name=$listname]">
              <xsl:apply-templates select="ui:ListItem[@Parent='']" mode="make_select:tree">
                <xsl:with-param name="selected" select="$selected"/>
              </xsl:apply-templates>
            </xsl:for-each>
          </xsl:when>
          <xsl:otherwise>
            <xsl:for-each select="//ui:List[@name=$listname]">
              <xsl:apply-templates select="ui:ListItem" mode="make_select">
                <xsl:with-param name="selected" select="$selected"/>
              </xsl:apply-templates>
            </xsl:for-each>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:if>

    <!-- end of element definition -->
    </xsl:element>
  </xsl:template>

  <!-- ======================================================================= -->
  <xsl:template name="make_select_fixed">
    <xsl:param name="list"></xsl:param>
    <xsl:param name="selected"></xsl:param>
    <xsl:param name="separ1">:</xsl:param>
    <xsl:param name="separ2">;</xsl:param>

    <xsl:if test="$list!=''">
      <xsl:variable name="value"><xsl:value-of select="substring-before($list,$separ1)"/></xsl:variable>
      <xsl:variable name="label"><xsl:value-of select="substring-after(substring-before($list,$separ2),$separ1)"/></xsl:variable>
      <xsl:variable name="after"><xsl:value-of select="substring-after($list,$separ2)"/></xsl:variable>

      <xsl:element name="option">
        <xsl:attribute name="value"><xsl:value-of select="$value"/></xsl:attribute>
        <xsl:if test="$value=$selected">
          <xsl:attribute name="selected">selected</xsl:attribute>
        </xsl:if>
        <xsl:value-of select="$label"/>
      </xsl:element>

      <xsl:call-template name="make_select_fixed">
        <xsl:with-param name="list"><xsl:value-of select="$after"/></xsl:with-param>
        <xsl:with-param name="selected"><xsl:value-of select="$selected"/></xsl:with-param>
        <xsl:with-param name="separ1"><xsl:value-of select="$separ1"/></xsl:with-param>
        <xsl:with-param name="separ2"><xsl:value-of select="$separ2"/></xsl:with-param>
      </xsl:call-template>
    </xsl:if>

  </xsl:template>

  <!-- ======================================================================= -->
  <xsl:template name="make_select_item" match="//ui:ListItem" mode="make_select">
    <xsl:param name="selected"/>
    <xsl:param name="prefix" select="''"/>

    <xsl:element name="option">
      <xsl:attribute name="value"><xsl:value-of select="@Key"/></xsl:attribute>
      <xsl:if test="@Key = $selected">
        <xsl:attribute name="selected"/>
      </xsl:if>
      <xsl:value-of select="concat($prefix,.)"/>
    </xsl:element>

  </xsl:template>

  <!-- ======================================================================= -->
  <xsl:template name="make_checkbox">
    <xsl:param name="name"/>
    <xsl:param name="id"/>
    <xsl:param name="value"/>
    <xsl:param name="checked"/>
    <xsl:param name="class">-1</xsl:param>
    <xsl:param name="onclick">-1</xsl:param>
    <xsl:param name="disabled">-1</xsl:param>

    <input type="checkbox">
      <xsl:attribute name="name"><xsl:value-of select="$name"/></xsl:attribute>
      <xsl:if test="$id != ''">
        <xsl:attribute name="id"><xsl:value-of select="$id"/></xsl:attribute>
      </xsl:if>
      <xsl:attribute name="value"><xsl:value-of select="$value"/></xsl:attribute>
      <xsl:if test="$checked=$value">
        <xsl:attribute name="checked">checked</xsl:attribute>
      </xsl:if>
      <xsl:if test="$class != '-1'">
        <xsl:attribute name="class"><xsl:value-of select="$class"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="$onclick != '-1'">
        <xsl:attribute name="onClick"><xsl:value-of select="$onclick"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="$disabled != '-1'">
        <xsl:attribute name="disabled">disabled</xsl:attribute>
      </xsl:if>
    </input>
  </xsl:template>

  <!-- ======================================================================= -->
  <xsl:template name="format_date">
    <xsl:param name="date"/>
    <xsl:param name="format"/>

    <xsl:if test="$date != ''">
      <xsl:call-template name="dt:format-date-time">
        <xsl:with-param name="year" select='number(substring($date, 1, 4))'/>
        <xsl:with-param name="month" select='number(substring($date, 6, 2))'/>
        <xsl:with-param name="day" select='number(substring($date, 9, 2))'/>
        <xsl:with-param name="hour" select='number(substring($date, 12, 2))'/>
        <xsl:with-param name="minute" select='number(substring($date, 15, 2))'/>
        <xsl:with-param name="second" select='number(substring($date, 18, 2))'/>
        <xsl:with-param name="format" select="$format"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <!-- ======================================================================= -->
</xsl:stylesheet>
