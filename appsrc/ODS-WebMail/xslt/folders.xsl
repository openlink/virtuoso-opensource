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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:include href="common.xsl"/>
  <xsl:include href="common_folders.xsl"/>

  <!-- ====================================================================================== -->
  <xsl:template match="page">
    <xsl:choose>
      <xsl:when test="messages/direction = '1'">
        <xsl:variable name="next_ord" select="0"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="next_ord" select="1"/>
      </xsl:otherwise>
    </xsl:choose>
    <form name="f1" method="post">
      <xsl:attribute name="action"><xsl:value-of select="$iri" />/folders.vsp</xsl:attribute>
      <xsl:call-template name="hid_sid"/>
      <xsl:choose>
        <xsl:when test="object/@id">
          <input type="hidden" name="folder_id">
            <xsl:attribute name="value"><xsl:value-of select="object/@id"/></xsl:attribute>
          </input>
          <input type="hidden" name="systemFlag">
            <xsl:attribute name="value"><xsl:value-of select="object/@systemFlag"/></xsl:attribute>
          </input>
          <input type="hidden" name="smartFlag">
            <xsl:attribute name="value"><xsl:value-of select="object/@smartFlag"/></xsl:attribute>
          </input>
          <table width="100%" cellpadding="0" cellspacing="0" class="content">
            <caption>
              <span>Manage Folders</span>
            </caption>
            <tr>
              <th width="20%">
                <label for="name">Name</label>
              </th>
              <td colspan="3">
                <input type="text" name="name" id="name">
                  <xsl:attribute name="value"><xsl:value-of select="object/name"/></xsl:attribute>
                </input>
              </td>
            </tr>
            <tr>
              <th>
                <label for="folders">Parent</label>
              </th>
              <td colspan="3">
                <xsl:choose>
                  <xsl:when test="object/@smartFlag = 'S'">
                    <xsl:variable name="tmp" select="object/parent_id" />
                    <input type="hidden" name="parent_id">
                      <xsl:attribute name="value"><xsl:value-of select="object/parent_id"/></xsl:attribute>
                    </input>
                    <xsl:value-of select="//folders/folder[@id = $tmp]/name"/>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:apply-templates select="folders" mode="combo">
                      <xsl:with-param name="ID" select="'parent_id'" />
                      <xsl:with-param name="selectID" select="//object/parent_id" />
                      <xsl:with-param name="skipID" select="//object/@id" />
                    </xsl:apply-templates>
                  </xsl:otherwise>
                </xsl:choose>
              </td>
            </tr>
            <xsl:if test="object/@smartFlag = 'S'">
              <tr>
                <th>
                  <label for="q_from">From</label>
                </th>
                <td>
                  <input type="text" size="30" name="q_from" id="q_from">
                    <xsl:attribute name="value"><xsl:value-of select="object/query/q_from"/></xsl:attribute>
                  </input>
                </td>
                <th>
                  <label for="q_after">Received after</label>
                </th>
                <td>
                  <input type="text" name="q_after" size="10" id="q_after">
                    <xsl:attribute name="value"><xsl:value-of select="object/query/q_after"/></xsl:attribute>
                  </input>
                  <span>
                    <img id="q_after_select" src="/oMail/i/pick_calendar.gif" onclick="javascript: datePopup('q_after');" border="0" />
                  </span>
                </td>
              </tr>
              <tr>
                <th>
                  <label for="q_to">To</label>
                </th>
                <td>
                  <input type="text" size="30" name="q_to" id="q_to">
                    <xsl:attribute name="value"><xsl:value-of select="object/query/q_to"/></xsl:attribute>
                  </input>
                </td>
                <th>
                  <label for="q_before">Received before</label>
                </th>
                <td>
                  <input type="text" name="q_before" size="10" id="q_before">
                    <xsl:attribute name="value"><xsl:value-of select="object/query/q_before"/></xsl:attribute>
                  </input>
                  <span>
                    <img id="q_before_select" src="/oMail/i/pick_calendar.gif" onclick="javascript: datePopup('q_before');" border="0" />
                  </span>
                </td>
              </tr>
              <tr>
                <th>
                  <label for="q_subject">Subject</label>
                </th>
                <td>
                  <input type="text" size="30" name="q_subject" id="q_subject">
                    <xsl:attribute name="value"><xsl:value-of select="object/query/q_subject"/></xsl:attribute>
      </input>
                </td>
                <th>
                  <label for="q_fid">In folder(s)</label>
                </th>
                <td>
                  <xsl:apply-templates select="folders" mode="combo">
                    <xsl:with-param name="ID" select="'q_fid'" />
                    <xsl:with-param name="startOption" select="' All folders'" />
                    <xsl:with-param name="selectID" select="//object/query/q_fid" />
                    <xsl:with-param name="skipID" select="//object/@id" />
                  </xsl:apply-templates>
                </td>
              </tr>
              <tr>
                <th>
                  <label for="q_body">Body has word(s)</label>
                </th>
                <td>
                  <input type="text" size="30" name="q_body" id="q_body">
                    <xsl:attribute name="value"><xsl:value-of select="object/query/q_body"/></xsl:attribute>
      </input>
                </td>
                <th>
                  <label for="att">With attachment(s)</label>
                </th>
                <td class="mb">
                  <input type="checkbox" name="q_attach" value="1" id="att">
                    <xsl:if test="object/query/q_attach = 1">
                      <xsl:attribute name="checked"/>
                    </xsl:if>
                  </input>
                </td>
              </tr>
              <tr>
                <th>
                  <label for="q_tags">Comma separated tags</label>
                </th>
                <td>
                  <input type="text" size="30" name="q_tags" id="body">
                    <xsl:attribute name="value"><xsl:value-of select="object/query/q_tags"/></xsl:attribute>
                  </input>
                </td>
                <th>
                  <label for="q_read">Unread mails</label>
                </th>
                <td class="mb">
                  <input type="checkbox" name="q_read" value="1" id="q_read">
                    <xsl:if test="object/query/q_read = 1">
                      <xsl:attribute name="checked"/>
                    </xsl:if>
                  </input>
                </td>
              </tr>
            </xsl:if>
            <tfoot>
              <tr>
                <th colspan="4">
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
                </th>
              </tr>
            </tfoot>
          </table>
        </xsl:when>
        <xsl:otherwise>
        	<div>
      	    <xsl:call-template name="make_href">
      	      <xsl:with-param name="url">folders.vsp</xsl:with-param>
      	      <xsl:with-param name="params">fp=0,-1</xsl:with-param>
      	      <xsl:with-param name="label">Create Folder</xsl:with-param>
      	      <xsl:with-param name="img">/oMail/i/add_16.png</xsl:with-param>
      	      <xsl:with-param name="img_label"> Create Folder</xsl:with-param>
      	      <xsl:with-param name="class">button2</xsl:with-param>
      	    </xsl:call-template>
      	    <xsl:call-template name="make_href">
      	      <xsl:with-param name="url">folders.vsp</xsl:with-param>
      	      <xsl:with-param name="params">fp=0,-2</xsl:with-param>
      	      <xsl:with-param name="label">Create Smart Folder</xsl:with-param>
      	      <xsl:with-param name="img">/oMail/i/add_16.png</xsl:with-param>
      	      <xsl:with-param name="img_label"> Create Smart Folder</xsl:with-param>
      	      <xsl:with-param name="class">button2</xsl:with-param>
      	    </xsl:call-template>
      	  </div>
          <br />
      <table width="100%" border="0" cellpadding="0" cellspacing="0" class="content">
        <thead>
          <tr>
            <th width="60%">Folders</th>
            <th align="right">Mails</th>
            <th align="right">New</th>
            <th align="right">Size</th>
            <th align="center" colspan="3" width="15%">Action</th>
          </tr>
        </thead>
        <tbody>
          <xsl:apply-templates select="folders" mode="list"/>
        </tbody>
        <xsl:call-template name="calc_size"/>
      </table>
        </xsl:otherwise>
      </xsl:choose>
    </form>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="folders" mode="list">
    <xsl:for-each select="folder">
      <tr>
        <td>
          <xsl:apply-templates select="ftree/fnode"/>
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">box.vsp</xsl:with-param>
            <xsl:with-param name="label"><xsl:value-of select="name"/></xsl:with-param>
            <xsl:with-param name="title">Select folder <xsl:value-of select="name"/></xsl:with-param>
            <xsl:with-param name="params">bp=<xsl:value-of select="@id"/>,,,</xsl:with-param>
          </xsl:call-template>
        </td>
        <td align="right">
          <xsl:value-of select="all_cnt"/>
        </td>
        <td align="right">
          <xsl:value-of select="new_cnt"/>
        </td>
        <td align="right">
          <xsl:call-template name="size2str">
            <xsl:with-param name="size" select="all_size"/>
            <xsl:with-param name="mode" select="0"/>
          </xsl:call-template>
          <xsl:call-template name="nbsp"/>
        </td>
        <td nowrap="nowrap">
          <xsl:if test="@id > 99">
            <xsl:call-template name="make_href">
              <xsl:with-param name="url">folders.vsp</xsl:with-param>
              <xsl:with-param name="params">fp=<xsl:value-of select="@id"/>,3</xsl:with-param>
              <xsl:with-param name="label">Empty Folder</xsl:with-param>
              <xsl:with-param name="onclick">javascript: return confirm('Are you sure that you want to empty this folder?');</xsl:with-param>
              <xsl:with-param name="img">/oMail/i/trash_16.png</xsl:with-param>
              <xsl:with-param name="img_label"> Empty</xsl:with-param>
              <xsl:with-param name="class">button2</xsl:with-param>
            </xsl:call-template>
          </xsl:if>
          <xsl:call-template name="nbsp"/>
        </td>
        <td nowrap="nowrap">
          <xsl:if test="@systemFlag = 'N'">
            <xsl:call-template name="make_href">
              <xsl:with-param name="url">folders.vsp</xsl:with-param>
              <xsl:with-param name="params">fp=<xsl:value-of select="@id"/>,1</xsl:with-param>
              <xsl:with-param name="label">Edit Folder</xsl:with-param>
              <xsl:with-param name="img">/oMail/i/edit_16.png</xsl:with-param>
              <xsl:with-param name="img_label"> Edit</xsl:with-param>
              <xsl:with-param name="class">button2</xsl:with-param>
            </xsl:call-template>
          </xsl:if>
          <xsl:call-template name="nbsp"/>
        </td>
        <td nowrap="nowrap">
          <xsl:if test="@systemFlag = 'N'">
            <xsl:call-template name="make_href">
              <xsl:with-param name="url">folders.vsp</xsl:with-param>
              <xsl:with-param name="params">fp=<xsl:value-of select="@id"/>,2</xsl:with-param>
              <xsl:with-param name="onclick">javascript: return confirm('Are you sure that you want to delete this folder?');</xsl:with-param>
              <xsl:with-param name="label">Delete Folder</xsl:with-param>
              <xsl:with-param name="img">/oMail/i/del_16.png</xsl:with-param>
              <xsl:with-param name="img_label"> Delete</xsl:with-param>
              <xsl:with-param name="class">button2</xsl:with-param>
            </xsl:call-template>
          </xsl:if>
          <xsl:call-template name="nbsp"/>
        </td>
      </tr>
      <xsl:apply-templates select="folders" mode="list"/>
    </xsl:for-each>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="ftree/fnode">
    <xsl:choose>
      <xsl:when test=". = 'F'">
        <img src="/oMail/i/folder_16.png" align="top"/>
        <xsl:call-template name="nbsp"/>
      </xsl:when>
      <xsl:when test=". = '-'">
        <img src="/oMail/i/folder_16.png" align="top"/>
        <xsl:call-template name="nbsp"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="nbsp"/>
        <img src="/oMail/i/c.gif" align="top" height="1" width="16"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ====================================================================================== -->
  <xsl:template name="calc_size">
    <tfoot>
      <tr>
        <th style="text-align: right;">Total:</th>
        <th style="text-align: right;">
          <xsl:value-of select="sum(//folders/folder/all_cnt)"/>
        </th>
        <th style="text-align: right;">
          <xsl:value-of select="sum(//folders/folder/new_cnt)"/>
        </th>
        <th style="text-align: right;">
          <xsl:call-template name="size2str">
            <xsl:with-param name="size" select="sum(//folders/folder/all_size)"/>
          </xsl:call-template>
          <xsl:call-template name="nbsp"/>
        </th>
        <th colspan="3">
          <xsl:call-template name="nbsp"/>
        </th>
      </tr>
    </tfoot>
  </xsl:template>
</xsl:stylesheet>
