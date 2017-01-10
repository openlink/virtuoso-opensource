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
  <xsl:include href="common_folders.xsl"/>

  <!-- ====================================================================================== -->
  <xsl:template match="page">
    <form method="post" name="dacc">
      <xsl:attribute name="action"><xsl:value-of select="$iri" />/ch_pop3.vsp</xsl:attribute>
      <xsl:call-template name="hid_sid"/>
      <xsl:apply-templates select="accounts"/>
      <xsl:apply-templates select="account" mode="update"/>
    </form>
  </xsl:template>

  <!-- ====================================================================================== -->
  <xsl:template match="accounts">
  	<div>
	    <xsl:call-template name="make_href">
	      <xsl:with-param name="url">ch_pop3.vsp</xsl:with-param>
	      <xsl:with-param name="params">cp=-1</xsl:with-param>
	      <xsl:with-param name="label">Create Account</xsl:with-param>
	      <xsl:with-param name="img">/oMail/i/add_16.png</xsl:with-param>
	      <xsl:with-param name="img_label"> Create Account</xsl:with-param>
	      <xsl:with-param name="class">button2</xsl:with-param>
	    </xsl:call-template>
	    <xsl:call-template name="make_href">
        <xsl:with-param name="url">ch_pop3.vsp</xsl:with-param>
        <xsl:with-param name="label">Check All</xsl:with-param>
        <xsl:with-param name="title">Check all external mail accounts now</xsl:with-param>
        <xsl:with-param name="params">cp=<xsl:value-of select="id"/>,2</xsl:with-param>
	      <xsl:with-param name="class">button2</xsl:with-param>
	    </xsl:call-template>
	  </div>
    <br />
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="content">
      <thead>
        <tr>
          <th>Account</th>
          <th>Options</th>
          <th width="10%">Action</th>
        </tr>
      </thead>
      <xsl:apply-templates select="account" mode="list"/>
      <xsl:call-template name="empty_row">
        <xsl:with-param name="count" select="count(account)"/>
        <xsl:with-param name="colspan" select="3"/>
            </xsl:call-template>
    </table>
  </xsl:template>

  <!-- ====================================================================================== -->
  <xsl:template match="account" mode="list">
    <tr class="msgRow">
      <td>
        <b><xsl:value-of select="name"/></b>
      </td>
      <td>
        Checked <xsl:call-template name="intervals"/>
        <xsl:if test="string(check_date) != ''">
          <font size="-2">(last check <xsl:apply-templates select="check_date"/>
            <xsl:call-template name="nbsp"/>
            <xsl:call-template name="nbsp"/>
            <xsl:choose>
              <xsl:when test="check_error = 0">
                <font color="#208D2A">successful</font>
              </xsl:when>
              <xsl:when test="check_error = 1">
                <a href="javascript:alert('Click \'Edit\' and check you server name.');">
                  <font size="-2" color="#ff0000">error - bad server name</font>
                </a>
              </xsl:when>
              <xsl:when test="check_error = 2">
                <a href="javascript:alert('Click \'Edit\' and check you user name and password.');">
                  <font size="-2" color="#ff0000">error - bad user name or pass</font>
                </a>
              </xsl:when>
              <xsl:when test="check_error = 3">
                <a href="javascript:alert('Our server cannot connect to mail server. Click \'Edit\' and check server settings or contact your network administrator.');">
                  <font size="-2" color="#ff0000">error - can't connect to mail server</font>
                </a>
              </xsl:when>
              <xsl:otherwise>
                <font color="#ff0000">error:<xsl:value-of select="check_error"/>
                </font>
              </xsl:otherwise>
            </xsl:choose>
  	      )</font>
        </xsl:if>
        <xsl:if test="id = /page/ch_acc_id">
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
          <xsl:with-param name="label">Check</xsl:with-param>
          <xsl:with-param name="title">Check mail account now</xsl:with-param>
          <xsl:with-param name="params">cp=<xsl:value-of select="id"/>,1</xsl:with-param>
          <xsl:with-param name="class">button2</xsl:with-param>
        </xsl:call-template>
        <xsl:call-template name="nbsp"/>
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">ch_pop3.vsp</xsl:with-param>
          <xsl:with-param name="params">cp=<xsl:value-of select="id"/></xsl:with-param>
          <xsl:with-param name="label">Edit Account</xsl:with-param>
          <xsl:with-param name="img">/oMail/i/edit_16.png</xsl:with-param>
          <xsl:with-param name="img_label"> Edit</xsl:with-param>
          <xsl:with-param name="class">button2</xsl:with-param>
        </xsl:call-template>
        <xsl:call-template name="nbsp"/>
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">ch_pop3.vsp</xsl:with-param>
          <xsl:with-param name="params">cp=<xsl:value-of select="id"/>,3</xsl:with-param>
          <xsl:with-param name="onclick">javascript: return confirm('Are you sure you want to delete this account?');</xsl:with-param>
          <xsl:with-param name="label">Delete Account</xsl:with-param>
          <xsl:with-param name="img">/oMail/i/del_16.png</xsl:with-param>
          <xsl:with-param name="img_label"> Delete</xsl:with-param>
          <xsl:with-param name="class">button2</xsl:with-param>
        </xsl:call-template>
      </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="intervals">
    <xsl:choose>
      <xsl:when test="check_interval = 1">
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
  <xsl:template match="account" mode="update">
    <table width="650" cellpadding="0" cellspacing="0" class="content">
      <caption>
        <span>
          <xsl:choose>
            <xsl:when test="id > 0">
              Update external mail account
            </xsl:when>
            <xsl:otherwise>
              Create external mail account
            </xsl:otherwise>
          </xsl:choose>
        </span>
      </caption>
        <tr>
        <th width="25%">
          <label for="name">Name</label>
      </th>
      <td>
          <input type="hidden" name="id">
            <xsl:attribute name="value"><xsl:value-of select="id"/></xsl:attribute>
        </input>
          <input type="text" name="name" id="name" style="width: 300px;">
            <xsl:attribute name="value"><xsl:value-of select="name"/></xsl:attribute>
        </input>
      </td>
      <td>
        <font class="n">(ex. My Yahoo box)</font>
      </td>
    </tr>
    <tr>
      <th>
        <label for="type">Server Type</label>
      </th>
      <td colspan="2">
        <xsl:call-template name="make_select">
            <xsl:with-param name="name">type</xsl:with-param>
            <xsl:with-param name="id">type</xsl:with-param>
            <xsl:with-param name="selected"><xsl:value-of select="type"/></xsl:with-param>
            <xsl:with-param name="list">pop3:POP3;imap:IMAP;</xsl:with-param>
            <xsl:with-param name="style">width: 100px;</xsl:with-param>
            <xsl:with-param name="onchange">javascript: accountChange(this);</xsl:with-param>
            <xsl:with-param name="disabled">
              <xsl:choose>
                <xsl:when test="type = 'imap'">1</xsl:when>
                <xsl:otherwise>-1</xsl:otherwise>
              </xsl:choose>
            </xsl:with-param>
          </xsl:call-template>
        </td>
      </tr>
      <tr>
        <th>
          <label for="connect_type">Connection Type</label>
        </th>
        <td colspan="2">
          <xsl:call-template name="make_select">
            <xsl:with-param name="name">connect_type</xsl:with-param>
            <xsl:with-param name="id">connect_type</xsl:with-param>
            <xsl:with-param name="selected"><xsl:value-of select="connect_type"/></xsl:with-param>
          <xsl:with-param name="list">none:None;ssl:SSL/TSL;</xsl:with-param>
          <xsl:with-param name="style">width: 100px;</xsl:with-param>
            <xsl:with-param name="onchange">javascript: accountChange(this);</xsl:with-param>
            <xsl:with-param name="disabled">
              <xsl:choose>
                <xsl:when test="type = 'imap'">1</xsl:when>
                <xsl:otherwise>-1</xsl:otherwise>
              </xsl:choose>
            </xsl:with-param>
        </xsl:call-template>
      </td>
    </tr>
    <tr>
      <th>
          <label for="host">Server Address</label>
      </th>
      <td>
          <input type="text" name="host" id="host" style="width: 300px;">
            <xsl:attribute name="value"><xsl:value-of select="host"/></xsl:attribute>
        </input>
      </td>
      <td>
        <font class="n">(ex. pop3.yahoo.com)</font>
      </td>
    </tr>
    <tr>
      <th>
        <label for="port">Server Port</label>
      </th>
      <td>
          <input type="text" name="port" id="port" style="width: 100px;">
            <xsl:attribute name="value"><xsl:value-of select="port"/></xsl:attribute>
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
          <input type="text" name="user" id="user" style="width: 100px;">
            <xsl:attribute name="value"><xsl:value-of select="user" /></xsl:attribute>
        </input>
      </td>
      <td>
        <font class="n">(ex. john_66)</font>
      </td>
    </tr>
    <tr>
      <th>
          <label for="password">Password</label>
      </th>
      <td colspan="2">
          <input type="password" name="password" id="password" style="width: 100px;">
            <xsl:attribute name="value"><xsl:value-of select="password"/></xsl:attribute>
        </input>
      </td>
    </tr>
    <tr>
      <th>
          <label for="folder_id">Store In</label>
      </th>
      <td colspan="2">
        <xsl:apply-templates select="folders" mode="combo">
            <xsl:with-param name="ID" select="'folder_id'" />
          <xsl:with-param name="showPath" select="1" />
            <xsl:with-param name="selectID" select="folder_id" />
          <xsl:with-param name="style">min-width: 100px;</xsl:with-param>
            <xsl:with-param name="startOption">&nbsp;</xsl:with-param>
            <xsl:with-param name="disabled">
              <xsl:choose>
                <xsl:when test="type = 'imap'">1</xsl:when>
                <xsl:otherwise>-1</xsl:otherwise>
              </xsl:choose>
            </xsl:with-param>
          </xsl:apply-templates> / <input type="text" name="folder_name" style="width: 185px" />
      </td>
    </tr>
    <tr>
      <th>Check Interval</th>
      <td colspan="2">
        <label>
            <input type="radio" name="check_interval" value="1" id="ed">
              <xsl:if test="check_interval = 1">
            <xsl:attribute name="checked"/>
          </xsl:if>
        </input>
          Every Day
        </label>
        <label>
            <input type="radio" name="check_interval" value="2" id="eh">
              <xsl:if test="check_interval != 1">
            <xsl:attribute name="checked"/>
          </xsl:if>
        </input>
          Every Hour
        </label>
      </td>
    </tr>
    <tr>
      <th>
        <label for="org">After get</label>
      </th>
      <td colspan="2">
        <label>
        <input type="radio" name="mcopy" value="1" id="org">
          <xsl:if test="mcopy = 1">
            <xsl:attribute name="checked"/>
          </xsl:if>
          </input>
          Leave original
        </label>
        <label>
        <input type="radio" name="mcopy" value="0">
              <xsl:if test="mcopy != 1">
            <xsl:attribute name="checked"/>
          </xsl:if>
          </input>
          Delete from server
        </label>
	    </td>
    </tr>
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
</xsl:stylesheet>
