<?xml version="1.0"?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <!-- img ========================================================================== -->
  <xsl:template match="img">
    <img>
      <xsl:if test="@src != ''">
        <xsl:attribute name="src"><xsl:value-of select="@src"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@height != ''">
        <xsl:attribute name="height"><xsl:value-of select="@height"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@width != ''">
        <xsl:attribute name="width"><xsl:value-of select="@width"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@align != ''">
        <xsl:attribute name="align"><xsl:value-of select="@align"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@border != ''">
        <xsl:attribute name="border"><xsl:value-of select="@border"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@alt != ''">
        <xsl:attribute name="alt"><xsl:value-of select="@alt"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@vspace != ''">
        <xsl:attribute name="vspace"><xsl:value-of select="@vspace"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@hspace != ''">
        <xsl:attribute name="hspace"><xsl:value-of select="@hspace"/></xsl:attribute>
      </xsl:if>
      <xsl:apply-templates/>
    </img>
  </xsl:template>
  <!-- a ========================================================================== -->
  <xsl:template match="a">
    <a>
      <xsl:if test="@href != ''">
        <xsl:attribute name="href">redir.vsp?r=<xsl:value-of select="@href"/></xsl:attribute>
      </xsl:if>
      <xsl:apply-templates/>
    </a>
  </xsl:template>
  <!-- font ========================================================================== -->
  <xsl:template match="font">
    <font>
      <xsl:if test="@size != ''">
        <xsl:attribute name="size"><xsl:value-of select="@size"/></xsl:attribute>
      </xsl:if>
      <xsl:apply-templates/>
    </font>
  </xsl:template>
  <!-- table ========================================================================== -->
  <xsl:template match="table">
    <table>
      <xsl:if test="@width != ''">
        <xsl:attribute name="width"><xsl:value-of select="@width"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@align != ''">
        <xsl:attribute name="align"><xsl:value-of select="@align"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@border != ''">
        <xsl:attribute name="border"><xsl:value-of select="@border"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@cellpadding != ''">
        <xsl:attribute name="cellpadding"><xsl:value-of select="@cellpadding"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@cellspacing != ''">
        <xsl:attribute name="cellspacing"><xsl:value-of select="@cellspacing"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@background != ''">
        <xsl:attribute name="background"><xsl:value-of select="@background"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@bgcolor != ''">
        <xsl:attribute name="bgcolor"><xsl:value-of select="@bgcolor"/></xsl:attribute>
      </xsl:if>
      <xsl:apply-templates/>
    </table>
  </xsl:template>
  <!-- tr ========================================================================== -->
  <xsl:template match="tr">
    <tr>
      <xsl:apply-templates/>
    </tr>
  </xsl:template>
  <!-- td ========================================================================== -->
  <xsl:template match="td|th">
    <td>
      <xsl:if test="@colspan != ''">
        <xsl:attribute name="colspan"><xsl:value-of select="@colspan"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@rowspan != ''">
        <xsl:attribute name="rowspan"><xsl:value-of select="@rowspan"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@valign != ''">
        <xsl:attribute name="valign"><xsl:value-of select="@valign"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@align != ''">
        <xsl:attribute name="align"><xsl:value-of select="@align"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@background != ''">
        <xsl:attribute name="background"><xsl:value-of select="@background"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@bgcolor != ''">
        <xsl:attribute name="bgcolor"><xsl:value-of select="@bgcolor"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@nowrap != ''">
        <xsl:attribute name="nowrap"><xsl:value-of select="@nowrap"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@width != ''">
        <xsl:attribute name="width"><xsl:value-of select="@width"/></xsl:attribute>
      </xsl:if>
      <xsl:apply-templates/>
    </td>
  </xsl:template>
  <!-- b ========================================================================== -->
  <xsl:template match="b">
    <b>
      <xsl:apply-templates/>
    </b>
  </xsl:template>
  <!-- strong ========================================================================== -->
  <xsl:template match="strong">
    <strong>
      <xsl:apply-templates/>
    </strong>
  </xsl:template>
  <!-- i ========================================================================== -->
  <xsl:template match="i">
    <i>
      <xsl:apply-templates/>
    </i>
  </xsl:template>
  <!-- em ========================================================================== -->
  <xsl:template match="em">
    <em>
      <xsl:apply-templates/>
    </em>
  </xsl:template>
  <!-- br ========================================================================== -->
  <xsl:template match="br">
    <br>
      <xsl:apply-templates/>
    </br>
  </xsl:template>
  <!-- hr ========================================================================== -->
  <xsl:template match="hr">
    <hr>
      <xsl:apply-templates/>
    </hr>
  </xsl:template>
  <!-- u ========================================================================== -->
  <xsl:template match="u">
    <u>
      <xsl:apply-templates/>
    </u>
  </xsl:template>
  <!-- p ========================================================================== -->
  <xsl:template match="p">
    <p>
      <xsl:apply-templates/>
    </p>
  </xsl:template>
  <!-- div ========================================================================== -->
  <xsl:template match="div">
    <div>
      <xsl:if test="@align != ''">
        <xsl:attribute name="align"><xsl:value-of select="@align"/></xsl:attribute>
      </xsl:if>
      <xsl:apply-templates/>
    </div>
  </xsl:template>
  <!-- center ========================================================================== -->
  <xsl:template match="center">
    <center>
      <xsl:apply-templates/>
    </center>
  </xsl:template>
  <!-- style ========================================================================== -->
  <xsl:template match="style"/>
  <!-- script ========================================================================== -->
  <xsl:template match="script"/>
  <!-- title ========================================================================== -->
  <xsl:template match="title"/>
</xsl:stylesheet>
