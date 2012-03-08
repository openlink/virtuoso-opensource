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
  <xsl:include href="box.xsl"/>

  <!-- ====================================================================================== -->
  <xsl:variable name="fid" select="/page/fid"/>

  <!-- ====================================================================================== -->
  <xsl:template match="page">
    <form method="post" name="f1">
      <xsl:attribute name="action"><xsl:value-of select="$iri" />/search.vsp</xsl:attribute>
      <xsl:call-template name="hid_sid"/>
      <input type="hidden" name="bp">
        <xsl:attribute name="value"><xsl:value-of select="bp"/></xsl:attribute>
      </input>
      <input type="hidden" name="mode">
        <xsl:attribute name="value"><xsl:value-of select="mode"/></xsl:attribute>
      </input>
      <div id="mgrid_info">
        <div style="float: left;">
        <xsl:variable name="cf" select="folders//folder[@id = $fid]"/>
          <b>Search: </b>
            <xsl:choose>
              <xsl:when test="string(mode) != 'advanced'">Simple</xsl:when>
              <xsl:otherwise>Advanced</xsl:otherwise>
            </xsl:choose>,<xsl:call-template name="nbsp"/>
          <b>Page:</b><xsl:call-template name="nbsp"/><xsl:value-of select="round((messages/skiped + messages/show_res - 1) div messages/show_res)"/> of <xsl:value-of select="floor((messages/all_res + messages/show_res - 1) div messages/show_res)"/>, <xsl:call-template name="nbsp"/>
          <b>Messages:</b><xsl:call-template name="nbsp"/><xsl:value-of select="messages/skiped + 1"/> - <xsl:value-of select="messages/skiped + messages/show_res"/> of <xsl:value-of select="messages/all_res"/>
      </div>
        <div style="float: right;">
          <b>Group By </b>
          <xsl:call-template name="make_select">
            <xsl:with-param name="name">groupBy</xsl:with-param>
            <xsl:with-param name="selected"><xsl:value-of select="./groupBy" /></xsl:with-param>
            <xsl:with-param name="list">0:;1:Status;2:Priority;3:Address;4:Subject;5:Date;6:Size;7:Attachment;8:Conversation;</xsl:with-param>
            <xsl:with-param name="onchange">javascript: groupSubmit(this); </xsl:with-param>
          </xsl:call-template>
        </div>
      </div>
      <br style="clear: both;"/>
      <xsl:if test="(number(messages/all_res) != 0)">
        <div style="margin: 2px;">
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">export.vsp</xsl:with-param>
            <xsl:with-param name="params"><xsl:value-of select="//export"/>&amp;output=rss</xsl:with-param>
            <xsl:with-param name="title">RSS 2.0</xsl:with-param>
            <xsl:with-param name="img_label"> RSS</xsl:with-param>
            <xsl:with-param name="img">/oMail/i/rss-icon-16.gif</xsl:with-param>
          </xsl:call-template>
          <xsl:if test="/page/atom_version = '0.3'">
            <xsl:call-template name="make_href">
              <xsl:with-param name="url">export.vsp</xsl:with-param>
              <xsl:with-param name="params"><xsl:value-of select="//export"/>&amp;output=atom03</xsl:with-param>
              <xsl:with-param name="title">Atom 0.3</xsl:with-param>
              <xsl:with-param name="img_label"> Atom</xsl:with-param>
              <xsl:with-param name="img">/oMail/i/blue-icon-16.gif</xsl:with-param>
            </xsl:call-template>
          </xsl:if>
          <xsl:if test="/page/atom_version = '1.0'">
            <xsl:call-template name="make_href">
              <xsl:with-param name="url">export.vsp</xsl:with-param>
              <xsl:with-param name="params"><xsl:value-of select="//export"/>&amp;output=atom10</xsl:with-param>
              <xsl:with-param name="title">Atom 1.0</xsl:with-param>
              <xsl:with-param name="img_label"> Atom</xsl:with-param>
              <xsl:with-param name="img">/oMail/i/blue-icon-16.gif</xsl:with-param>
            </xsl:call-template>
          </xsl:if>
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">export.vsp</xsl:with-param>
            <xsl:with-param name="params"><xsl:value-of select="//export"/>&amp;output=rdf</xsl:with-param>
            <xsl:with-param name="title">RDF 1.0</xsl:with-param>
            <xsl:with-param name="img_label"> RDF</xsl:with-param>
            <xsl:with-param name="img">/oMail/i/rdf-icon-16.gif</xsl:with-param>
          </xsl:call-template>
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">export.vsp</xsl:with-param>
            <xsl:with-param name="params"><xsl:value-of select="//export"/>&amp;output=xbel</xsl:with-param>
            <xsl:with-param name="title">XBEL</xsl:with-param>
            <xsl:with-param name="img_label"> XBEL</xsl:with-param>
            <xsl:with-param name="img">/oMail/i/blue-icon-16.gif</xsl:with-param>
          </xsl:call-template>
        </div>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="query/q_cloud != 1">
          <xsl:call-template name="message_table"/>
        </xsl:when>
        <xsl:otherwise>
          <table cellspacing="0" cellpadding="0" width="100%" >
            <tr>
              <td valign="top">
      <xsl:call-template name="message_table"/>
              </td>
              <td width="20%" valign="top" style="border: solid #935000;  border-width: 1px 1px 1px 1px;">
                <div style="margin-left:3px; margin-top:3px;">
                  <xsl:choose>
                    <xsl:when test="count(//ctags/ctag) = 0">
                      no tags
                    </xsl:when>
                    <xsl:otherwise>
                      <xsl:apply-templates select="//ctags/ctag"/>
                    </xsl:otherwise>
                  </xsl:choose>
                </div>
              </td>
            </tr>
          </table>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:call-template name="footer" />
      <xsl:call-template name="advance_search"/>
    </form>
  </xsl:template>

  <!-- ====================================================================================== -->
  <xsl:template match="ctag">
    <a href="#">
      <xsl:attribute name="onclick">javascript: formSubmit('c_tag', '<xsl:value-of select="."/>');</xsl:attribute>
      <span class="nolink_b">
        <xsl:attribute name="style"><xsl:value-of select="./@style"/></xsl:attribute>
        <xsl:value-of select="."/>
      </span>
    </a>
  </xsl:template>

  <!-- ====================================================================================== -->
  <xsl:template name="advance_search">
    <xsl:choose>
      <xsl:when test="string(mode) != 'advanced'">
        <div class="boxHeader" style="text-align: center;">
          <b>Search </b>
          <input type="text" size="40" name="q" onkeypress="return submitEnter('f1', '', event)">
            <xsl:attribute name="value"><xsl:value-of select="query/q"/></xsl:attribute>
          </input>
          |
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">javascript: document.forms['f1'].elements['mode'].value = 'advanced'; document.forms['f1'].submit();</xsl:with-param>
            <xsl:with-param name="label">Advanced</xsl:with-param>
            <xsl:with-param name="title">Advanced Search</xsl:with-param>
          </xsl:call-template>
          |
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">./box.vsp</xsl:with-param>
            <xsl:with-param name="label">Cancel</xsl:with-param>
            <xsl:with-param name="tile">Cancel Search</xsl:with-param>
          </xsl:call-template>
        </div>
      </xsl:when>
      <xsl:otherwise>
        <input name="tabNo" id="tabNo" type="hidden" value="1"/>
       	<div id="c1" style="margin-top: 2px;">
      		<div class="tabs">
      		  &nbsp;
            <div style="display: inline;" id="tabLabel_1">
              <a href="javascript:showTab2(1, 2)" id="tab_1" class="tab noapp" alt="Criteria" title="Criteria">Criteria</a>
            </div>
            <div style="display: inline;" id="tabLabel_2">
              <a href="javascript:showTab2(2, 2)" id="tab_2" class="tab noapp" alt="Options" title="Options">Options</a>
            </div>
          </div>
      		<div class="contents">
            <div id="1" class="tabContent" style="display: none;">
              <table class="form-body" cellspacing="0">
                <tr>
                  <th>
                    <label for="q_from">From</label>
                  </th>
                  <td>
                    <input type="text" size="30" name="q_from" id="q_from">
                      <xsl:attribute name="value"><xsl:value-of select="query/q_from"/></xsl:attribute>
                    </input>
                  </td>
                  <th>
                    <label for="q_after">Received after</label>
                  </th>
                  <td>
                    <input type="text" name="q_after" size="10" id="q_after">
                      <xsl:attribute name="value"><xsl:value-of select="query/q_after"/></xsl:attribute>
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
                      <xsl:attribute name="value"><xsl:value-of select="query/q_to"/></xsl:attribute>
                    </input>
                  </td>
                  <th>
                    <label for="q_before">Received before</label>
                  </th>
                  <td>
                    <input type="text" name="q_before" size="10" id="q_before">
                      <xsl:attribute name="value"><xsl:value-of select="query/q_before"/></xsl:attribute>
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
                      <xsl:attribute name="value"><xsl:value-of select="query/q_subject"/></xsl:attribute>
                    </input>
                  </td>
                  <th>
                    <label for="q_fid">In folder(s)</label>
                  </th>
                  <td>
                    <xsl:apply-templates select="folders" mode="combo">
                      <xsl:with-param name="ID" select="'q_fid'" />
                      <xsl:with-param name="startOption" select="' All folders'" />
                      <xsl:with-param name="selectID" select="/page/query/q_fid" />
                    </xsl:apply-templates>
                  </td>
                </tr>
                <tr>
                  <th>
                    <label for="q_body">Body has word(s)</label>
                  </th>
                  <td>
                    <input type="text" size="30" name="q_body" id="q_body">
                      <xsl:attribute name="value"><xsl:value-of select="query/q_body"/></xsl:attribute>
                    </input>
                  </td>
                  <th>
                    <label for="q_attach">With attachment(s)</label>
                  </th>
                  <td class="mb">
                    <input type="checkbox" name="q_attach" value="1" id="q_attach">
                      <xsl:if test="query/q_attach = 1">
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
                      <xsl:attribute name="value"><xsl:value-of select="query/q_tags"/></xsl:attribute>
                    </input>
                  </td>
                  <th>
                    <label for="q_read">Unread mails</label>
                  </th>
                  <td class="mb">
                    <input type="checkbox" name="q_read" value="1" id="q_read">
                      <xsl:if test="query/q_read = 1">
                        <xsl:attribute name="checked"/>
                      </xsl:if>
                    </input>
                  </td>
                </tr>
              </table>
            </div>
            <div id="2" class="tabContent" style="display: none;">
              <table class="form-body" cellspacing="0">
                <tr>
                  <th width="50%">
                    <label for="q_max">Max Results</label>
                  </th>
                  <td>
                    <input type="text" name="q_max" size="5">
                      <xsl:attribute name="value"><xsl:value-of select="query/q_max"/></xsl:attribute>
                    </input>
                  </td>
                </tr>
                <tr>
                  <th>
                    <label for="q_order">Order by</label>
                  </th>
                  <td>
                    <xsl:call-template name="make_select">
                      <xsl:with-param name="name">q_order</xsl:with-param>
                      <xsl:with-param name="selected"><xsl:value-of select="//messages/order"/></xsl:with-param>
                      <xsl:with-param name="list">3:From;4:Subject;5:Date;6:Size;</xsl:with-param>
                    </xsl:call-template>
                  </td>
                </tr>
                <tr>
                  <th>
                    <label for="q_direction">Direction</label>
                  </th>
                  <td>
                    <xsl:call-template name="make_select">
                      <xsl:with-param name="name">q_direction</xsl:with-param>
                      <xsl:with-param name="selected"><xsl:value-of select="//messages/direction"/></xsl:with-param>
                      <xsl:with-param name="list">1:Asc;2:Desc;</xsl:with-param>
                    </xsl:call-template>
                  </td>
                </tr>
                <tr>
                  <th />
                  <td>
                    <xsl:call-template name="make_checkbox">
                      <xsl:with-param name="name">q_cloud</xsl:with-param>
                      <xsl:with-param name="id">q_cloud</xsl:with-param>
                      <xsl:with-param name="value">1</xsl:with-param>
                      <xsl:with-param name="checked"><xsl:if test="query/q_cloud = 1">1</xsl:if></xsl:with-param>
                    </xsl:call-template>
                    <label for="q_cloud">Show tag cloud</label>
                  </td>
                </tr>
              </table>
            </div>
          </div>
        </div>
        <div class="form-footer">
          <xsl:call-template name="make_submit">
            <xsl:with-param name="name">search</xsl:with-param>
            <xsl:with-param name="value">Search</xsl:with-param>
            <xsl:with-param name="alt">Search</xsl:with-param>
          </xsl:call-template>
          <xsl:call-template name="make_submit">
            <xsl:with-param name="name">fa_save</xsl:with-param>
            <xsl:with-param name="value">Save</xsl:with-param>
            <xsl:with-param name="alt">Save</xsl:with-param>
          </xsl:call-template>
          <xsl:call-template name="make_submit">
            <xsl:with-param name="name">fa_cancel</xsl:with-param>
            <xsl:with-param name="value">Cancel</xsl:with-param>
            <xsl:with-param name="alt">Cancel Search</xsl:with-param>
          </xsl:call-template>
        </div>
        <script>
          initTab2(2, 1);
        </script>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- ====================================================================================== -->
</xsl:stylesheet>
