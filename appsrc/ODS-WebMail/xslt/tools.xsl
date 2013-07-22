<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2013 OpenLink Software
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
    <table id="info" width="500" align="center" cellpadding="0" cellspacing="0" border="0">
      <xsl:apply-templates select="object"/>
    </table>
    <br/>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="object">
    <xsl:choose>
      <xsl:when test="@action_id = 0">
        <xsl:call-template name="edit_folder"/>
      </xsl:when>
      <xsl:when test="@action_id = 1">
        <xsl:call-template name="del_folder"/>
      </xsl:when>
      <xsl:when test="@action_id = 2">
        <xsl:call-template name="emp_folder"/>
      </xsl:when>
    </xsl:choose>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="edit_folder">
    <caption>
      <span>Edit folder</span>
    </caption>
    <form method="post">
      <xsl:attribute name="action"><xsl:value-of select="$iri" />/tools.vsp</xsl:attribute>
      <xsl:call-template name="hid_sid"/>
      <input type="hidden" name="tp">
        <xsl:attribute name="value"><xsl:value-of select="/page/tp"/>,1</xsl:attribute>
      </input>
      <input type="hidden" name="ok">
        <xsl:attribute name="value">1</xsl:attribute>
      </input>
      <tr>
        <th>
          <label for="name">Name:</label>
          <xsl:call-template name="nbsp"/>
        </th>
        <td>
          <input type="text" name="oname" id="name">
            <xsl:attribute name="value"><xsl:value-of select="object_name"/></xsl:attribute>
          </input>
        </td>
      </tr>
      <xsl:apply-templates select="folders" mode="combo"/>
      <tr>
        <td align="center" colspan="2">
          <xsl:call-template name="make_submit">
            <xsl:with-param name="name">save</xsl:with-param>
            <xsl:with-param name="value">Save</xsl:with-param>
            <xsl:with-param name="alt">Save</xsl:with-param>
          </xsl:call-template>
          <xsl:call-template name="make_submit">
            <xsl:with-param name="name">cancel</xsl:with-param>
            <xsl:with-param name="value">Cancel</xsl:with-param>
            <xsl:with-param name="alt">cancel</xsl:with-param>
            <xsl:with-param name="onclick">javascript:history.go(-1)</xsl:with-param>
          </xsl:call-template>
        </td>
      </tr>
    </form>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="folders" mode="combo">
    <tr>
      <th>
        <label for="folders">Parent:</label>
        <xsl:call-template name="nbsp"/>
      </th>
      <td>
        <select name="pid" id="folders">
          <xsl:apply-templates select="folder"/>
        </select>
      </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="folder[@smartFlag='N']">
    <xsl:if test="@id != /page/object/object_id">
      <option>
        <xsl:if test="@id = /page/object/parent_id">
          <xsl:attribute name="selected">selected</xsl:attribute>
        </xsl:if>
        <xsl:attribute name="value"><xsl:value-of select="@id"/></xsl:attribute>
        <xsl:value-of select="level/@str"/>
        <xsl:value-of select="name"/>
      </option>
      <xsl:apply-templates select="folders/folder"/>
    </xsl:if>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="del_folder">
    <thead>
      <tr>
        <th>Are you sure you want to delete folder "<xsl:value-of select="/page/object/object_name"/>"?</th>
      </tr>
    </thead>
    <tr>
      <td>
        <ul>
          <li>If you choose "Yes" you will delete <xsl:value-of select="count_m"/> message(s), <xsl:value-of select="count_f"/> subfolder(s) and this folder. External boxes will use parent folder for incoming messages.<br/>
          </li>
          <li>If you choose "No" you will return to folder list without any actions<br/>
          </li>
        </ul>
      </td>
    </tr>
    <tfoot>
      <tr>
        <td>
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">tools.vsp</xsl:with-param>
            <xsl:with-param name="params">tp=<xsl:value-of select="object_id"/>,<xsl:value-of select="@action_id"/>,1</xsl:with-param>
            <xsl:with-param name="label">Delete This Folder</xsl:with-param>
            <xsl:with-param name="img">/oMail/i/yes.gif</xsl:with-param>
          </xsl:call-template>
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">folders.vsp</xsl:with-param>
            <xsl:with-param name="label">Go Back Without Delete Anything</xsl:with-param>
            <xsl:with-param name="img">/oMail/i/no.gif</xsl:with-param>
          </xsl:call-template>
        </td>
      </tr>
    </tfoot>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="emp_folder">
    <thead>
      <tr>
        <th>Are you sure you want to delete all messages from this folder?</th>
      </tr>
    </thead>
    <tr>
      <td>
        <ul>
          <li>If you choose "Yes" you will delete <xsl:value-of select="count_m"/> message(s) in <xsl:value-of select="count_f"/> subfolder(s)<br/>
          </li>
          <li>If you choose "No" you will return to folder list without any actions<br/>
          </li>
        </ul>
      </td>
    </tr>
    <tfoot>
      <tr>
        <td>
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">tools.vsp</xsl:with-param>
            <xsl:with-param name="params">tp=<xsl:value-of select="object_id"/>,<xsl:value-of select="@action_id"/>,1</xsl:with-param>
            <xsl:with-param name="label">Delete All Messages in This Folder</xsl:with-param>
            <xsl:with-param name="img">/oMail/i/yes.gif</xsl:with-param>
          </xsl:call-template>
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">folders.vsp</xsl:with-param>
            <xsl:with-param name="label">Go Back Without Delete Anything</xsl:with-param>
            <xsl:with-param name="img">/oMail/i/no.gif</xsl:with-param>
          </xsl:call-template>
        </td>
      </tr>
    </tfoot>
  </xsl:template>
  <!-- ====================================================================================== -->
</xsl:stylesheet>
