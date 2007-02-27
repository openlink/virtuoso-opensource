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
    <script laguage="JavaScript">
      function cdel(acc_id){
        if(confirm('Are you sure you want to delete this account ')){
          document.dacc.del_acc_id.value = acc_id;
          document.dacc.submit();
          return true;
        }
      }
    </script>
    <form action="ch_pop3.vsp" method="post" name="dacc">
      <xsl:call-template name="hid_sid"/>
      <input type="hidden" name="del_acc_id" value="0"/>
      <xsl:apply-templates select="accounts"/>
      <xsl:apply-templates select="account"/>
    </form>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="accounts">
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="content">
      <thead>
        <tr>
          <th>Accounts</th>
          <th>Options</th>
          <th nowrap="nowrap" width="25%">Action</th>
        </tr>
      </thead>
      <xsl:apply-templates select="acc"/>
      <xsl:if test="not(acc)">
        <tr>
          <td height="50" colspan="3">
            You do not have any external accounts.
          </td>
        </tr>
      </xsl:if>
      <tfoot>
        <tr>
          <td colspan="3">
            <xsl:call-template name="make_href">
              <xsl:with-param name="url">ch_pop3.vsp</xsl:with-param>
              <xsl:with-param name="params">cp=-1</xsl:with-param>
              <xsl:with-param name="label">Create POP3 Account</xsl:with-param>
              <xsl:with-param name="img">/oMail/i/add_16.png</xsl:with-param>
              <xsl:with-param name="img_label"> Create POP3 Account</xsl:with-param>
              <xsl:with-param name="class">button</xsl:with-param>
            </xsl:call-template>
          </td>
        </tr>
      </tfoot>
    </table>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="acc">
    <tr>
      <td>
        <b><xsl:value-of select="acc_name"/></b>
      </td>
      <td>
        Checked <xsl:call-template name="intervals"/>
        <xsl:if test="string(last_check) != ''">
          <font size="-2">(last check <xsl:apply-templates select="last_check"/>
            <xsl:call-template name="nbsp"/>
            <xsl:call-template name="nbsp"/>
            <xsl:choose>
              <xsl:when test="ch_error = 0">
                <font color="#208D2A">successful</font>
              </xsl:when>
              <xsl:when test="ch_error = 1">
                <a href="javascript:alert('Click \'Edit\' and check you server name.');">
                  <font size="-2" color="#ff0000">error - bad server name</font>
                </a>
              </xsl:when>
              <xsl:when test="ch_error = 2">
                <a href="javascript:alert('Click \'Edit\' and check you user name and password.');">
                  <font size="-2" color="#ff0000">error - bad user name or pass</font>
                </a>
              </xsl:when>
              <xsl:when test="ch_error = 3">
                <a href="javascript:alert('Our server cannot connect to POP3 server. Click \'Edit\' and check server settings or contact your network administrator.');">
                  <font size="-2" color="#ff0000">error - can't connect to POP3 server</font>
                </a>
              </xsl:when>
              <xsl:otherwise>
                <font color="#ff0000">error:<xsl:value-of select="ch_error"/>
                </font>
              </xsl:otherwise>
            </xsl:choose>
  	      )</font>
        </xsl:if>
        <xsl:if test="acc_id = /page/ch_acc_id">
          <a>
            <xsl:attribute name="href">box.vsp?sid=<xsl:value-of select="$sid"/>&amp;realm=<xsl:value-of select="$realm"/>&amp;bp=<xsl:value-of select="folder_id"/></xsl:attribute>
            <font color="#FF0000">
              <xsl:call-template name="nbsp"/>
              <xsl:call-template name="nbsp"/>
              <xsl:call-template name="nbsp"/>
              <xsl:value-of select="/page/new_msg"/> new message<xsl:if test="/page/new_msg != 1">s</xsl:if>
            </font>
          </a>
        </xsl:if>
      </td>
      <td nowrap="nowrap">
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">ch_pop3.vsp</xsl:with-param>
          <xsl:with-param name="label">Check Now</xsl:with-param>
          <xsl:with-param name="title">Check pop3 account now</xsl:with-param>
          <xsl:with-param name="params">cp=<xsl:value-of select="acc_id"/>,1</xsl:with-param>
          <xsl:with-param name="class">button</xsl:with-param>
        </xsl:call-template>
        <xsl:call-template name="nbsp"/>
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">ch_pop3.vsp</xsl:with-param>
          <xsl:with-param name="params">cp=<xsl:value-of select="acc_id"/></xsl:with-param>
          <xsl:with-param name="label">Edit POP3 Account</xsl:with-param>
          <xsl:with-param name="img">/oMail/i/edit_16.png</xsl:with-param>
          <xsl:with-param name="img_label"> Edit</xsl:with-param>
          <xsl:with-param name="class">button</xsl:with-param>
        </xsl:call-template>
        <xsl:call-template name="nbsp"/>
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">javascript:cdel(<xsl:value-of select="acc_id"/>)</xsl:with-param>
          <xsl:with-param name="label">Delete POP3 Account</xsl:with-param>
          <xsl:with-param name="img">/oMail/i/del_16.png</xsl:with-param>
          <xsl:with-param name="img_label"> Delete</xsl:with-param>
          <xsl:with-param name="class">button</xsl:with-param>
        </xsl:call-template>
      </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="intervals">
    <xsl:choose>
      <xsl:when test="intervals = 1">
        daily
      </xsl:when>
      <xsl:otherwise>
        every hour
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="last_check">
    <xsl:call-template name="format_date">
      <xsl:with-param name="date" select="."/>
      <xsl:with-param name="format" select="'%d.%m.%Y'"/>
    </xsl:call-template>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="account">
    <table width="600" cellpadding="0" cellspacing="0" class="content">
      <colgroup>
        <col class="w160"/>
        <col/>
      </colgroup>
      <caption>
        <span>Manage your external mail box</span>
      </caption>
      <xsl:apply-templates select="acc_edit"/>
      <tfoot>
        <tr>
          <th colspan="3">
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
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="acc_edit">
    <input type="hidden" name="acc_id">
      <xsl:attribute name="value"><xsl:value-of select="acc_id"/></xsl:attribute>
    </input>
    <tr>
      <th>
        <label for="acc">Account Name</label>
      </th>
      <td>
        <input type="text" name="acc_name" id="acc">
          <xsl:attribute name="value"><xsl:value-of select="acc_name"/></xsl:attribute>
        </input>
      </td>
      <td>
        <font class="n">(ex. My Yahoo box)</font>
      </td>
    </tr>
    <tr>
      <th>
        <label for="server">Server Address</label>
      </th>
      <td>
        <input type="text" name="pop_server" id="server">
          <xsl:attribute name="value"><xsl:value-of select="pop_server"/></xsl:attribute>
        </input>
      </td>
      <td>
        <font class="n">(ex. pop3.yahoo.com)</font>
      </td>
    </tr>
    <tr>
      <th>
        <label for="port">Port</label>
      </th>
      <td>
        <input type="text" name="pop_port" id="port">
          <xsl:attribute name="value"><xsl:value-of select="pop_port"/></xsl:attribute>
        </input>
      </td>
      <td>
        <font class="n">(ex. 110)</font>
      </td>
    </tr>
    <tr>
      <th>
        <label for="user">User Name</label>
      </th>
      <td>
        <input type="text" name="user_name" id="user">
          <xsl:attribute name="value"><xsl:value-of select="user_name"/></xsl:attribute>
        </input>
      </td>
      <td>
        <font class="n">(ex. john_66)</font>
      </td>
    </tr>
    <tr>
      <th>
        <label for="pass">Password</label>
      </th>
      <td>
        <input type="password" name="user_pass" id="pass">
          <xsl:attribute name="value"><xsl:value-of select="user_pass"/></xsl:attribute>
        </input>
      </td>
    </tr>
    <tr>
      <th>
        <label for="folders">Store In</label>
      </th>
      <td colspan="2">
        <xsl:apply-templates select="folders" mode="combo"/> / <input type="text" name="fname"/>
      </td>
    </tr>
    <tr>
      <th>Check Interval</th>
      <td>
        <input type="radio" name="ch_interval" value="1" id="ed">
          <xsl:if test="intervals = 1">
            <xsl:attribute name="checked"/>
          </xsl:if>
        </input>
        <label for="ed">Every Day</label>
      </td>
      <td>
        <input type="radio" name="ch_interval" value="2" id="eh">
          <xsl:if test="intervals = 2">
            <xsl:attribute name="checked"/>
          </xsl:if>
        </input>
        <label for="eh">Every Hour</label>
      </td>
    </tr>
    <tr>
      <th>
        <label for="org">After get</label>
      </th>
      <td>
        <input type="radio" name="mcopy" value="1" id="org">
          <xsl:if test="mcopy = 1">
            <xsl:attribute name="checked"/>
          </xsl:if>
        </input> Leave original
      </td>
      <td>
        <input type="radio" name="mcopy" value="0">
          <xsl:if test="mcopy = 0">
            <xsl:attribute name="checked"/>
          </xsl:if>
        </input> Delete from server
	    </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="folders" mode="combo">
    <select name="fid" id="folders">
      <xsl:apply-templates select="folder">
        <xsl:with-param name="path"/>
      </xsl:apply-templates>
    </select>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="folder">
    <xsl:param name="path"/>
    <option>
      <xsl:attribute name="value"><xsl:value-of select="folder_id"/></xsl:attribute>
      <xsl:if test="folder_id = /page/account/acc_edit/folder_id">
        <xsl:attribute name="selected">selected</xsl:attribute>
      </xsl:if>
      <xsl:value-of select="$path"/>
      <xsl:value-of select="name"/>
    </option>
    <xsl:apply-templates select="folders">
      <xsl:with-param name="path">
        <xsl:value-of select="$path"/>
        <xsl:value-of select="name"/> / </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  <!-- ====================================================================================== -->
</xsl:stylesheet>
