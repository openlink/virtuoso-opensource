<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2012 OpenLink Software
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
  <xsl:template name="folder_tree">
    <div id="tree">
      <table cellpadding="1" cellspacing="0" border="0">
        <xsl:apply-templates select="page/folders" mode="list"/>
      </table>
    </div>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="folders" mode="list">
    <xsl:for-each select="folder">
      <tr>
        <td />
              <td>
                <xsl:apply-templates select="ftree/fnode"/>
                <xsl:call-template name="nbsp"/>
          <xsl:choose>
            <xsl:when test="@id != 115">
                <xsl:call-template name="make_href">
                  <xsl:with-param name="url">box.vsp</xsl:with-param>
            <xsl:with-param name="label"><xsl:value-of select="substring(name,1,15)"/><xsl:if test="string-length(name) > 15">...</xsl:if></xsl:with-param>
            <xsl:with-param name="params">bp=<xsl:value-of select="@id"/>,0,<xsl:value-of select="/page/messages/order"/>,<xsl:value-of select="/page/messages/direction"/><xsl:value-of select="/page/eparams"/></xsl:with-param>
                  <xsl:with-param name="class">
              <xsl:if test="@id = /page/folder_id">bc</xsl:if>
                  </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
              <xsl:call-template name="nbsp"/>
              <xsl:value-of select="substring(name,1,15)"/><xsl:if test="string-length(name) > 15">...</xsl:if>
            </xsl:otherwise>
          </xsl:choose>
                <xsl:if test="new_cnt + all_cnt != 0">
                  <font class="n"> (<xsl:value-of select="new_cnt"/>/<xsl:value-of select="all_cnt"/>)</font>
                </xsl:if>
              </td>
            </tr>
      <xsl:apply-templates select="m_list" mode="mlist"/>
      <xsl:apply-templates select="folders" mode="list"/>
    </xsl:for-each>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="ftree/fnode">
    <xsl:choose>
      <xsl:when test="parent::ftree/parent::folder/@id = $fid">
        <xsl:variable name="open">_open</xsl:variable>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="open"></xsl:variable>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:choose>
      <xsl:when test=". = 'F'">
        <img align="top">
          <xsl:attribute name="src">/oMail/i/folder<xsl:value-of select="$open"/>_16.png</xsl:attribute>
        </img>
      </xsl:when>
      <xsl:when test=". = '-'">
        <img align="top">
          <xsl:attribute name="src">/oMail/i/folder<xsl:value-of select="$open"/>_16.png</xsl:attribute>
        </img>
      </xsl:when>
      <xsl:when test=". = 'I'">
        <img src="/oMail/i/c.gif" height="1" width="16"/>
      </xsl:when>
      <xsl:otherwise>
        <img src="/oMail/i/c.gif" height="1" width="16"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="m_list" mode="mlist">
    <xsl:if test="/page/list_pos - show_res > 0">
      <tr>
        <td/>
        <td>
          <img src="/oMail/i/c.gif" height="1" width="16"/>
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">open.vsp</xsl:with-param>
            <xsl:with-param name="params">op=<xsl:value-of select="prev_msg"/>,<xsl:value-of select="message[1]/position - 1"/></xsl:with-param>
            <xsl:with-param name="label">Previous group</xsl:with-param>
            <xsl:with-param name="img">/oMail/i/previous_16.png</xsl:with-param>
            <xsl:with-param name="img_label"> Previous group</xsl:with-param>
            <xsl:with-param name="img_hspace">0</xsl:with-param>
          </xsl:call-template>
        </td>
      </tr>
    </xsl:if>
    <xsl:apply-templates select="message" mode="mlist"/>
    <xsl:if test="message[last()]/position != all_res">
      <tr>
        <td/>
        <td>
          <img src="/oMail/i/c.gif" height="1" width="16"/>
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">open.vsp</xsl:with-param>
            <xsl:with-param name="params">op=<xsl:value-of select="next_msg"/>,<xsl:value-of select="message[last()]/position + 1"/></xsl:with-param>
            <xsl:with-param name="label">Next group</xsl:with-param>
            <xsl:with-param name="img">/oMail/i/next_16.png</xsl:with-param>
            <xsl:with-param name="img_label"> Next group</xsl:with-param>
            <xsl:with-param name="img_hspace">0</xsl:with-param>
          </xsl:call-template>
        </td>
      </tr>
    </xsl:if>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="message" mode="mlist">
    <xsl:choose>
      <xsl:when test="mstatus = 0">
        <xsl:variable name="open"></xsl:variable>
          </xsl:when>
          <xsl:otherwise>
        <xsl:variable name="open">_open</xsl:variable>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:variable name="last" select="last()"/>
    <xsl:variable name="position" select="position()"/>
    <xsl:variable name="subject_len" select="15 - ((../../level/@num) * 2)"/>
    <xsl:choose>
      <xsl:when test="string-length(subject) > 15">
        <xsl:variable name="subject" select="substring(subject,1,$subject_len)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="subject" select="subject"/>
      </xsl:otherwise>
    </xsl:choose>
    <tr>
      <td/>
      <td>
              <xsl:apply-templates select="../../ftree/fnode" mode="msg">
          <xsl:with-param name="open" select="$open"/>
              </xsl:apply-templates>
              <xsl:choose>
                <xsl:when test="/page/message/msg_id != msg_id">
                  <xsl:call-template name="make_href">
                    <xsl:with-param name="url">open.vsp</xsl:with-param>
                    <xsl:with-param name="label"><xsl:value-of select="substring(subject,1,$subject_len)"/>...</xsl:with-param>
                    <xsl:with-param name="title">From: <xsl:value-of select="address/addres_list/from"/>/Subject: <xsl:value-of select="subject"/></xsl:with-param>
                    <xsl:with-param name="params">op=<xsl:value-of select="msg_id"/>,<xsl:value-of select="position"/></xsl:with-param>
                    <xsl:with-param name="class">n</xsl:with-param>
                  </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>
                  <font class="bc">
                    <font style="font-size:10px; background-color:#B0CDE4">
                      <u>
                        <xsl:value-of select="$subject"/>
                      </u>...</font>
                  </font>
                </xsl:otherwise>
              </xsl:choose>
            </td>
          </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="ftree/fnode" mode="msg">
    <xsl:param name="open"/>
    <xsl:choose>
      <xsl:when test=". = 'F'">
        <img src="/oMail/i/c.gif" height="1" width="16" hspace="0" vspace="0"/>
        <img align="top" hspace="0" vspace="0">
          <xsl:attribute name="src">/oMail/i/msg<xsl:value-of select="$open"/>.gif</xsl:attribute>
        </img>
      </xsl:when>
      <xsl:when test=". = '-'">
        <img src="/oMail/i/c.gif" height="1" width="16" hspace="0" vspace="0"/>
        <img align="top" hspace="0" vspace="0">
          <xsl:attribute name="src">/oMail/i/msg<xsl:value-of select="$open"/>.gif</xsl:attribute>
        </img>
      </xsl:when>
      <xsl:otherwise>
        <img src="/oMail/i/c.gif" height="1" width="16"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ====================================================================================== -->
  <xsl:template match="folders" mode="combo">
    <xsl:param name="ID" select="'fid'" />
    <xsl:param name="path" />
    <xsl:param name="showPath" select="0" />
    <xsl:param name="startOption" select="''" />
    <xsl:param name="scope" select="'N'" />
    <xsl:param name="selectID" select="-1" />
    <xsl:param name="skipID" select="-1" />
    <xsl:param name="disabled">-1</xsl:param>
    <xsl:param name="style" />
    <select>
      <xsl:attribute name="name"><xsl:value-of select="$ID"/></xsl:attribute>
      <xsl:attribute name="id"><xsl:value-of select="$ID"/></xsl:attribute>
      <xsl:if test="$style">
        <xsl:attribute name="style"><xsl:value-of select="$style" /></xsl:attribute>
      </xsl:if>
      <xsl:if test="$disabled != -1">
        <xsl:attribute name="disabled"><xsl:value-of select="$disabled" /></xsl:attribute>
      </xsl:if>
      <xsl:if test="$startOption != ''">
        <option value="0"><xsl:value-of select="$startOption"/></option>
      </xsl:if>
      <xsl:apply-templates select="folder" mode="combo">
        <xsl:with-param name="path" select="$path" />
        <xsl:with-param name="showPath" select="$showPath" />
        <xsl:with-param name="scope" select="$scope" />
        <xsl:with-param name="selectID" select="$selectID" />
        <xsl:with-param name="skipID" select="$skipID" />
      </xsl:apply-templates>
    </select>
  </xsl:template>

  <!-- ====================================================================================== -->
  <xsl:template match="foldersCombo" mode="combo">
    <xsl:param name="ID" select="'fid'" />
    <xsl:param name="path" />
    <xsl:param name="showPath" select="0" />
    <xsl:param name="startOption" select="''" />
    <xsl:param name="scope" select="'N'" />
    <xsl:param name="selectID" select="-1" />
    <xsl:param name="skipID" select="-1" />
    <xsl:param name="disabled">-1</xsl:param>
    <xsl:param name="style" />
    <select>
      <xsl:attribute name="name"><xsl:value-of select="$ID"/></xsl:attribute>
      <xsl:attribute name="id"><xsl:value-of select="$ID"/></xsl:attribute>
      <xsl:if test="$style">
        <xsl:attribute name="style"><xsl:value-of select="$style" /></xsl:attribute>
      </xsl:if>
      <xsl:if test="$disabled != -1">
        <xsl:attribute name="disabled"><xsl:value-of select="$disabled" /></xsl:attribute>
      </xsl:if>
      <xsl:if test="$startOption != ''">
        <option value="0"><xsl:value-of select="$startOption"/></option>
      </xsl:if>
      <xsl:apply-templates select="folder" mode="combo">
        <xsl:with-param name="path" select="$path" />
        <xsl:with-param name="showPath" select="$showPath" />
        <xsl:with-param name="scope" select="$scope" />
        <xsl:with-param name="selectID" select="$selectID" />
        <xsl:with-param name="skipID" select="$skipID" />
      </xsl:apply-templates>
    </select>
  </xsl:template>

  <!-- ====================================================================================== -->
  <xsl:template match="folder" mode="combo">
    <xsl:param name="path" select="''" />
    <xsl:param name="showPath" select="0" />
    <xsl:param name="scope" select="'N'" />
    <xsl:param name="selectID" select="-1" />
    <xsl:param name="skipID" select="-1" />
    <xsl:if test="($scope='*' or @smartFlag='N') and $skipID != @id">
      <option>
        <xsl:attribute name="value"><xsl:value-of select="@id"/></xsl:attribute>
        <xsl:if test="@id = $selectID">
          <xsl:attribute name="selected">1</xsl:attribute>
        </xsl:if>
        <xsl:choose>
          <xsl:when test="$showPath=0">
            <xsl:value-of select="level/@str"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="$path"/>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:value-of select="name"/>
      </option>
      <xsl:apply-templates select="folders/folder" mode="combo">
        <xsl:with-param name="path">
          <xsl:value-of select="$path"/>
          <xsl:value-of select="name"/> / </xsl:with-param>
        <xsl:with-param name="showPath" select="$showPath" />
        <xsl:with-param name="scope" select="$scope" />
        <xsl:with-param name="selectID" select="$selectID" />
        <xsl:with-param name="skipID" select="$skipID" />
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
