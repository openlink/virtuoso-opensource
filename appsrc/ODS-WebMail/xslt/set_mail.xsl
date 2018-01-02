<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2018 OpenLink Software
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
    <form method="post" name="f1">
      <xsl:attribute name="action"><xsl:value-of select="$iri" />/set_mail.vsp</xsl:attribute>
      <xsl:call-template name="hid_sid"/>
      <table width="100%" cellpadding="0" cellspacing="0" align="center" class="content">
        <colgroup>
          <col class="w350"/>
          <col/>
        </colgroup>
        <caption>
          <span>Preferences</span>
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
    <tr>
      <th style="background-color: #EAEAEE;" />
      <th style="background-color: #EAEAEE; text-align: left;">General</th>
    </tr>
    <xsl:apply-templates select="msg_name"/>
    <xsl:apply-templates select="msg_reply"/>
    <xsl:apply-templates select="msg_result"/>
    <xsl:apply-templates select="usr_sig_inc"/>
    <xsl:apply-templates select="atom_version"/>
    <xsl:apply-templates select="conversation"/>
    <tr>
      <th style="background-color: #EAEAEE;" />
      <th style="background-color: #EAEAEE; text-align: left;">Privacy</th>
    </tr>
    <xsl:apply-templates select="spam_msg_action"/>
    <xsl:apply-templates select="spam_msg_state"/>
    <xsl:apply-templates select="spam_msg_clean"/>
    <xsl:apply-templates select="spam_msg_header"/>
    <xsl:apply-templates select="spam"/>
    <tr>
      <th style="background-color: #EAEAEE;" />
      <th style="background-color: #EAEAEE; text-align: left;">Digitaly Signing</th>
    </tr>
    <xsl:choose>
      <xsl:when test="count(//certificates/certificate) > 0">
    <xsl:apply-templates select="security_sign"/>
    <xsl:apply-templates select="security_sign_mode"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="noCertificates" />
      </xsl:otherwise>
    </xsl:choose>
    <tr>
      <th style="background-color: #EAEAEE;" />
      <th style="background-color: #EAEAEE; text-align: left;">Encryption</th>
    </tr>
    <xsl:choose>
      <xsl:when test="count(//certificates/certificate) > 0">
    <xsl:apply-templates select="security_encrypt"/>
    <xsl:apply-templates select="security_encrypt_mode"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="noCertificates" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="msg_name">
    <tr>
      <th rowspan="2" valign="top">Name</th>
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
      <th>Discussion</th>
      <td>
        <label>
        <xsl:call-template name="make_checkbox">
          <xsl:with-param name="name">conversation</xsl:with-param>
          <xsl:with-param name="value">1</xsl:with-param>
          <xsl:with-param name="checked"><xsl:if test=". = 1">1</xsl:if></xsl:with-param>
          <xsl:with-param name="disabled"><xsl:choose><xsl:when test="../discussion = 0">1</xsl:when><xsl:otherwise>-1</xsl:otherwise></xsl:choose></xsl:with-param>
        </xsl:call-template>
          Enable discussion on this instance
        </label>
      </td>
    </tr>
    <xsl:if test="../discussion = 0">
      <tr>
        <th></th>
        <td class="error_text">
          The Discussion feature is disabled. You need to install the ODS Discussion package in order to use it.
        </td>
      </tr>
    </xsl:if>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="spam_msg_action">
    <tr>
      <th />
      <td>
        <label>
          <xsl:call-template name="make_checkbox">
            <xsl:with-param name="name">spam_msg_action</xsl:with-param>
            <xsl:with-param name="id">spam_msg_action</xsl:with-param>
            <xsl:with-param name="value">1</xsl:with-param>
            <xsl:with-param name="checked"><xsl:if test=". > 0">1</xsl:if></xsl:with-param>
            <xsl:with-param name="onclick">javascript: OMAIL.enableRadioGroup('spam_msg_action');</xsl:with-param>
          </xsl:call-template>
          When messages are determined to be Spam
        </label>
        <div style="margin-left: 16px;">
          <label>
            <input type="radio" name="spam_msg_action_radio" id="spam_msg_action_radio_1" value="1">
              <xsl:if test=". <= 1">
                <xsl:attribute name="checked">checked</xsl:attribute>
              </xsl:if>
              <xsl:if test=". = 0">
                <xsl:attribute name="disabled" />
              </xsl:if>
            </input>
    			  Move them to the Spam folder
    	    </label>
    	    <br />
          <label>
            <input type="radio" name="spam_msg_action_radio" id="spam_msg_action_radio_2" value="2">
              <xsl:if test=". = 2">
                <xsl:attribute name="checked">checked</xsl:attribute>
              </xsl:if>
              <xsl:if test=". = 0">
                <xsl:attribute name="disabled" />
              </xsl:if>
            </input>
            Delete them
    	    </label>
        </div>
      </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="spam_msg_state">
    <tr>
      <th />
      <td>
        <label>
          <xsl:call-template name="make_checkbox">
            <xsl:with-param name="name">spam_msg_state</xsl:with-param>
            <xsl:with-param name="id">spam_msg_state</xsl:with-param>
            <xsl:with-param name="value">1</xsl:with-param>
            <xsl:with-param name="checked"><xsl:if test=". = 1">1</xsl:if></xsl:with-param>
          </xsl:call-template>
          Mark messages determined to be Spam as read
        </label>
      </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="spam_msg_clean">
    <tr>
      <th>Automatically delete spam messages older then</th>
      <td>
        <label>
          <input type="text" name="spam_msg_clean" style="width:30px">
            <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
          </input>
          <xsl:text> days (0 - no delete)</xsl:text>
        </label>
      </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="spam_msg_header">
    <tr>
      <th>Trust mail headers</th>
      <td>
        <label>
          <xsl:call-template name="make_checkbox">
            <xsl:with-param name="name">spam_msg_header</xsl:with-param>
            <xsl:with-param name="id">spam_msg_header</xsl:with-param>
            <xsl:with-param name="value">1</xsl:with-param>
            <xsl:with-param name="checked"><xsl:if test=". = 1">1</xsl:if></xsl:with-param>
          </xsl:call-template>
          (set by SpamAssassin or SpamPal)
        </label>
      </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="spam">
    <tr>
      <th>Allow messages from</th>
      <td>
        <xsl:call-template name="make_select">
          <xsl:with-param name="name">spam</xsl:with-param>
          <xsl:with-param name="selected"><xsl:value-of select="." /></xsl:with-param>
          <xsl:with-param name="list">0:Everyone;1:My contacts only;2:My contacts and contacts with depth 1;3:My contacts and contacts with depth 2;4:My contacts and contacts with depth 3;5:My contacts and contacts with depth 4;</xsl:with-param>
        </xsl:call-template>
      </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="security_sign">
    <tr>
      <th nowrap="nowrap">Use this certificate to digitally sign messages you send</th>
      <td>
        <select name="security_sign" onchange="toggleDisabled(this, ['security_sign_mode']);">
          <option></option>
          <xsl:apply-templates select="certificates/certificate" />
        </select>
      </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="security_sign_mode">
    <tr>
      <th></th>
      <td>
        <label>
          <xsl:call-template name="make_checkbox">
            <xsl:with-param name="name">security_sign_mode</xsl:with-param>
            <xsl:with-param name="id">security_sign_mode</xsl:with-param>
            <xsl:with-param name="value">1</xsl:with-param>
            <xsl:with-param name="checked"><xsl:if test=". = 1">1</xsl:if></xsl:with-param>
            <xsl:with-param name="disabled"><xsl:if test="count(../security_sign/certificates/certificate[@selected]) = 0">1</xsl:if></xsl:with-param>
          </xsl:call-template>
          Digitally sign messages (by default)
        </label>
      </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="security_encrypt">
    <tr>
      <th nowrap="nowrap">Use this certificate to encrypt/decript messages sent to you</th>
      <td>
        <select name="security_encrypt" onchange="toggleDisabled(this, ['security_encrypt_mode_0', 'security_encrypt_mode_1']);">
          <option></option>
          <xsl:apply-templates select="certificates/certificate" />
        </select>
      </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="security_encrypt_mode">
    <tr>
      <th nowrap="nowrap">Default encryption setting when sending messages</th>
      <td>
        <label>
          <input type="radio" id="security_encrypt_mode_0" name="security_encrypt_mode" value="0">
            <xsl:if test="../security_encrypt_mode = 0">
              <xsl:attribute name="checked"/>
            </xsl:if>
            <xsl:if test="count(../security_encrypt/certificates/certificate[@selected]) = 0">
              <xsl:attribute name="disabled" />
            </xsl:if>
          </input>
  			  Never (do not use encryption)
  	    </label>
      </td>
    </tr>
    <tr>
      <th></th>
      <td>
        <label>
          <input type="radio" id="security_encrypt_mode_1" name="security_encrypt_mode" value="1">
            <xsl:if test="../security_encrypt_mode = 1">
              <xsl:attribute name="checked"/>
            </xsl:if>
            <xsl:if test="count(../security_encrypt/certificates/certificate[@selected]) = 0">
              <xsl:attribute name="disabled" />
            </xsl:if>
          </input>
  			  Required (can't send message unless all recipients have certificates)
  	    </label>
      </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="certificate">
    <option>
      <xsl:value-of select="."/>
      <xsl:if test="@selected">
        <xsl:attribute name="selected">1</xsl:attribute>
      </xsl:if>
    </option>
    <xsl:apply-templates select="certificates/certificate" />
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="noCertificates">
    <tr>
      <th></th>
      <td class="error_text">
        Please import/create first your private certificate(s) with user's profile to use this feature.
      </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
</xsl:stylesheet>
