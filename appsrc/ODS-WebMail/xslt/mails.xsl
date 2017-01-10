<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2017 OpenLink Software
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
  <xsl:include href="common.xsl"/>
  <!-- ====================================================================================== -->
  <xsl:template match="page">
    <form name="f1" action="mails.vsp" method="post">
      <xsl:call-template name="hid_sid"/>
      <input type="hidden" name="set">
        <xsl:attribute name="value"><xsl:value-of select="set"/></xsl:attribute>
      </input>
      <input type="hidden" name="return">
        <xsl:attribute name="value"><xsl:value-of select="return"/></xsl:attribute>
      </input>
      <div class="boxHeader">
        <!--
        <b>Show</b>
        <xsl:call-template name="make_select">
          <xsl:with-param name="name">where</xsl:with-param>
          <xsl:with-param name="id">where</xsl:with-param>
          <xsl:with-param name="selected"><xsl:value-of select="where" /></xsl:with-param>
          <xsl:with-param name="list">1:Local contacts;2:LOD contacts;</xsl:with-param>
          <xsl:with-param name="onchange">javascript: whatLabelChange(this); </xsl:with-param>
        </xsl:call-template>
        |
        -->
        <label>
	        <xsl:call-template name="make_checkbox">
	          <xsl:with-param name="name">certificate</xsl:with-param>
	          <xsl:with-param name="value">1</xsl:with-param>
	          <xsl:with-param name="checked"><xsl:if test="certificate = 1">1</xsl:if></xsl:with-param>
	        </xsl:call-template>
          With certificate
        </label>
        |
        <b>
          <span id="whatLabel">
            <xsl:choose><xsl:when test="./where = 1">Name</xsl:when><xsl:otherwise>Mail</xsl:otherwise></xsl:choose>
          </span>
        </b>
        &nbsp;
        <input type="text" name="what" size="20">
          <xsl:attribute name="value"><xsl:value-of select="what"/></xsl:attribute>
        </input>
        &nbsp;
        <input type="submit" value="Filter" class="button" />
      </div>
      <table class="ODS_grid">
        <thead>
          <tr>
            <th class="checkbox">
              <input type="checkbox" name="cb_all" value="Select All" onclick="selectAllCheckboxes(this, 'cb_item'); "/>
            </th>
            <th>
              Name
            </th>
            <th>
              Mail
            </th>
          </tr>
        </thead>
        <tbody>
          <xsl:choose>
            <xsl:when test="count(mails/mail) > 0">
          <xsl:apply-templates select="mails" />
            </xsl:when>
            <xsl:otherwise>
              <tr>
                <td colspan="3">
                  No contacts founded
                </td>
              </tr>
            </xsl:otherwise>
          </xsl:choose>
        </tbody>
      </table>
      <div style="padding: 0 0 0.5em 0;">
        <hr />
        <a href="#" onclick="javascript: return addChecked(document.forms['f1'], 'cb_item', 'No contacts were selected for addition.');" class="navi-button">Add selected</a>
      </div>
    </form>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="mails">
    <xsl:for-each select="mail">
      <tr>
        <td class="checkbox">
          <input type="checkbox" name="cb_item">
            <xsl:attribute name="value"><xsl:value-of select="email"/></xsl:attribute>
          </input>
          <xsl:if test="certificate/modulus != ''">
            <input type="hidden">
              <xsl:attribute name="value"><xsl:value-of select="certificate/modulus"/></xsl:attribute>
            </input>
            <input type="hidden">
              <xsl:attribute name="value"><xsl:value-of select="certificate/public_exponent"/></xsl:attribute>
            </input>
          </xsl:if>
        </td>
        <td>
          <xsl:value-of select="name"/>
        </td>
        <td>
          <xsl:value-of select="email"/>
        </td>
      </tr>
    </xsl:for-each>
  </xsl:template>
  <!-- ====================================================================================== -->
</xsl:stylesheet>
