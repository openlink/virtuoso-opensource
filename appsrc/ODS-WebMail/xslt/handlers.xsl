<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2016 OpenLink Software
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
  <!-- ====================================================================================== -->
  <xsl:template match="attachment_preview">
    <table width="95%" cellpadding="0" cellspacing="0" BORDER="0" align="center">
      <tr>
        <td class="td">
          <img src="/oMail/i/c.gif" width="1" height="1"/>
        </td>
        <td>
          <table width="100%" cellpadding="0" cellspacing="0" BORDER="0" bgcolor="#FFEEC6" align="center">
            <tr>
              <td bgcolor="#440000" colspan="3">
                <img src="/oMail/i/c.gif" width="1" height="2"/>
              </td>
            </tr>
            <tr bgcolor="#FFDC88">
              <td height="20">
                <xsl:call-template name="nbsp"/>
                <img align="top">
                  <xsl:attribute name="src">../res/image.vsp?id=<xsl:value-of select="type_id"/></xsl:attribute>
                </img>
                <xsl:call-template name="nbsp"/>
              </td>
              <td>
                <p class="mb">
                  <xsl:call-template name="nbsp"/>
                  <xsl:call-template name="handler_header"/>
                </p>
              </td>
              <td align="right">
                <p class="mb">
                  <xsl:apply-templates select="handlers/handler_objects/actions/action"/>
                  <xsl:call-template name="make_href">
                    <xsl:with-param name="url">box.vsp</xsl:with-param>
                    <xsl:with-param name="params">bp=100&amp;fa_erase.x=1&amp;ch_msg=<xsl:value-of select="msg_id"/>&amp;ru=open.vsp?op=<xsl:value-of select="/page/message/msg_id"/>,<xsl:value-of select="/page/list_pos"/></xsl:with-param>
                    <xsl:with-param name="title">Delete</xsl:with-param>
                    <xsl:with-param name="img">/oMail/i/delete.gif</xsl:with-param>
                  </xsl:call-template>
                </p>
              </td>
            </tr>
            <tr>
              <td bgcolor="#440000" colspan="3">
                <img src="/oMail/i/c.gif" width="1" height="2"/>
              </td>
            </tr>
            <tr>
              <td colspan="3">
                <img src="/oMail/i/c.gif" width="1" height="3"/>
              </td>
            </tr>
            <xsl:apply-templates select="handlers/handler_objects"/>
            <tr>
              <td bgcolor="#440000" colspan="3">
                <img src="/oMail/i/c.gif" width="1" height="2"/>
              </td>
            </tr>
          </table>
        </td>
        <td>
          <img src="/oMail/i/c.gif" width="1" height="1"/>
        </td>
      </tr>
    </table>
    <br/>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="handlers/handler_objects">
    <xsl:apply-templates select="object"/>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="object">
    <tr>
      <td/>
      <td bgcolor="#FFE6AA" colspan="2">
        <p class="mb">
          <b>
            <xsl:value-of select="obj_name"/>
          </b>
        </p>
      </td>
    </tr>
    <xsl:apply-templates select="property"/>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="property">
    <tr>
      <td/>
      <td align="right" width="20%">
        <p class="mb">
          <xsl:call-template name="nbsp"/>
          <xsl:call-template name="nbsp"/>
          <xsl:value-of select="substring(name,1,15)"/>:</p>
      </td>
      <td width="80%">
        <p class="mb">
          <xsl:call-template name="nbsp"/>
          <i>
            <xsl:value-of select="substring(value,1,40)"/>
          </i>
        </p>
      </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="handlers/handler_objects/actions/action">
    <xsl:call-template name="make_href">
      <xsl:with-param name="url">javascript: windowShow('', 'blank');</xsl:with-param>
      <xsl:with-param name="target">_blank</xsl:with-param>
      <xsl:with-param name="params">mid=<xsl:value-of select="/page/message/msg_id"/>&amp;pid=<xsl:value-of select="../../../../part_id"/></xsl:with-param>
      <xsl:with-param name="img"><xsl:call-template name="handler_action"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="handler_header">
    <xsl:choose>
      <xsl:when test="type_id = 10150">Attached VCard preview</xsl:when>
      <xsl:when test="type_id = 10160">Attached calendar preview</xsl:when>
      <xsl:otherwise>Attached object</xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="handler_action">
    <xsl:choose>
      <xsl:when test="label = 'import_to_calendar'">i/import_c.gif</xsl:when>
      <xsl:when test="label = 'import_to_contacts'">import_t.gif</xsl:when>
      <xsl:otherwise>Attached object</xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- ====================================================================================== -->
</xsl:stylesheet>
