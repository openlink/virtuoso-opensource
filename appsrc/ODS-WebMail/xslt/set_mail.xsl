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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:include href="common.xsl"/>
  <!-- ====================================================================================== -->
  <xsl:template match="page">
    <form action="set_mail.vsp" method="post" name="f1">
      <xsl:call-template name="hid_sid"/>
      <table width="100%" cellpadding="0" cellspacing="0" align="center" class="content">
        <colgroup>
          <col class="w200"/>
          <col/>
        </colgroup>
        <caption>
          <span>Set your preferences</span>
        </caption>
        <tbody>
          <xsl:apply-templates select="settings"/>
        </tbody>
        <tfoot>
          <tr>
            <td/>
            <td>
              <xsl:call-template name="make_submit">
                <xsl:with-param name="name">fa_save</xsl:with-param>
                <xsl:with-param name="value">Save</xsl:with-param>
                <xsl:with-param name="alt">Save</xsl:with-param>
              </xsl:call-template>
              <xsl:call-template name="make_submit">
                <xsl:with-param name="name">fa_cancel</xsl:with-param>
                <xsl:with-param name="value">Cancel</xsl:with-param>
                <xsl:with-param name="alt">Cancel</xsl:with-param>
              </xsl:call-template>
            </td>
          </tr>
        </tfoot>
      </table>
    </form>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="settings">
    <xsl:apply-templates select="msg_name"/>
    <xsl:apply-templates select="msg_reply"/>
    <xsl:apply-templates select="msg_result"/>
    <xsl:apply-templates select="usr_sig_inc"/>
    <xsl:apply-templates select="atom_version"/>
    <xsl:apply-templates select="conversation"/>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="msg_name">
    <tr>
      <th rowspan="2">Name</th>
      <td>
        <label>
          <input type="radio" name="msg_name" value="0">
            <xsl:if test="@selected = 0">
              <xsl:attribute name="checked"/>
            </xsl:if>
          </input>
  			  Use my name from ODS
  	    </label>
      </td>
    </tr>
    <tr>
      <td>
        <label>
          <input type="radio" name="msg_name" value="1">
            <xsl:if test="@selected = 1">
              <xsl:attribute name="checked"/>
            </xsl:if>
          </input>
  	    </label>
			  Use name
			  <input type="text" name="msg_name_txt" onFocus="f1.msg_name[1].checked = true">
          <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
        </input>
      </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="msg_reply">
    <tr>
      <th>Reply-to</th>
      <td>
        <input type="text" name="msg_reply">
          <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
        </input>
      </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="msg_result">
    <tr>
      <th>Display max</th>
      <td>
        <label>
          <input type="text" name="msg_result" style="width:30px">
            <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
          </input>
          <xsl:text> messages per page</xsl:text>
        </label>
      </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="usr_sig_inc">
    <tr>
      <th rowspan="3" valign="top" nowrap="nowrap">Message Composition</th>
      <td>
        <label>
          <input type="radio" name="usr_sig_inc" value="0">
            <xsl:if test="@selected = 0">
              <xsl:attribute name="checked"/>
            </xsl:if>
          </input>
  			  No signature
  	    </label>
      </td>
    </tr>
    <tr>
      <td>
        <label>
          <input type="radio" name="usr_sig_inc" value="1">
            <xsl:if test="@selected = 1">
              <xsl:attribute name="checked"/>
            </xsl:if>
          </input>
  			  Use signature text:
  	    </label>
      </td>
    </tr>
    <tr>
      <td>
        <textarea name="usr_sig_txt" cols="50" rows="6" onFocus="f1.usr_sig_inc[1].checked = true">
          <xsl:value-of select="."/>
        </textarea>
      </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="atom_version">
    <tr>
      <th>Atom File Version</th>
      <td>
        <xsl:call-template name="make_select">
          <xsl:with-param name="name">atom_version</xsl:with-param>
          <xsl:with-param name="selected"><xsl:value-of select="."/></xsl:with-param>
          <xsl:with-param name="list">0.3:0.3;1.0:1.0;</xsl:with-param>
        </xsl:call-template>
      </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="conversation">
    <tr>
      <th></th>
      <td>
        <xsl:call-template name="make_checkbox">
          <xsl:with-param name="name">conversation</xsl:with-param>
          <xsl:with-param name="value">1</xsl:with-param>
          <xsl:with-param name="checked"><xsl:if test=". = 1">1</xsl:if></xsl:with-param>
        </xsl:call-template>
        Enable conversation on this instance
      </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
</xsl:stylesheet>
