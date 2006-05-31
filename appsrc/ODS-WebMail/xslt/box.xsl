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
  <xsl:include href="common_folders.xsl"/>

  <!-- ====================================================================================== -->
  <xsl:template match="page">
    <form action="box.vsp" method="post" name="f1">
      <xsl:call-template name="hid_sid"/>
      <input type="hidden" name="bp">
        <xsl:attribute name="value"><xsl:value-of select="bp"/></xsl:attribute>
      </input>
      <div id="mgrid_info">
        <xsl:variable name="cf" select="folders//folder[folder_id = $fid]"/>
        <span>
          <b>Folder:</b><xsl:call-template name="nbsp"/><xsl:value-of select="$cf/name"/>,<xsl:call-template name="nbsp"/>
          <b>Page:</b><xsl:call-template name="nbsp"/><xsl:value-of select="round((messages/skiped + messages/show_res - 1) div messages/show_res)"/> of <xsl:value-of select="floor((messages/all_res + messages/show_res - 1) div messages/show_res)"/>, <xsl:call-template name="nbsp"/>
          <b>Messages:</b><xsl:call-template name="nbsp"/><xsl:value-of select="messages/skiped"/> - <xsl:value-of select="messages/skiped + messages/show_res"/> of <xsl:value-of select="messages/all_res"/> (<xsl:value-of select="$cf/new_cnt"/> new)
        </span>
      </div>
      <xsl:call-template name="message_table"/>
      <xsl:if test="not(@mode)">
        <xsl:apply-templates select="folders" mode="combo"/>
      </xsl:if>
    </form>
    <xsl:call-template name="js_check_all"/>
    <xsl:apply-templates select="eparams"/>
    <xsl:call-template name="external_action"/>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="message_table">
    <table width="100%" cellpadding="0" cellspacing="0" border="0" id="mgrid">
      <colgroup>
        <xsl:if test="not(/page/@mode)">
          <col class="ct1"/>
        </xsl:if>
        <col class="ct1"/>
        <col class="ct1"/>
        <col class="ct1"/>
        <col class="from"/>
        <col class="subj"/>
        <col class="received"/>
        <col class="size"/>
      </colgroup>
      <xsl:call-template name="messages_header"/>
      <xsl:apply-templates select="messages/message"/>
      <xsl:call-template name="message_empty">
        <xsl:with-param name="count" select="count(messages/message)"/>
      </xsl:call-template>
    </table>
    <xsl:call-template name="skiped"/>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="messages_header">
    <xsl:choose>
      <xsl:when test="messages/direction = '2'">
        <xsl:variable name="next_ord" select="1"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="next_ord" select="2"/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:choose>
      <xsl:when test="(number(/page/folder_id) = 100) or (number(/page/folder_id) = 0)">
        <xsl:variable name="cell">From</xsl:variable>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="cell">To</xsl:variable>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:choose>
      <xsl:when test="(number(/page/folder_id) = 100) or (number(/page/folder_id) = 0)">
        <xsl:variable name="date_cell">Received</xsl:variable>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="date_cell">Sent</xsl:variable>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:choose>
      <xsl:when test="/page/@id = 'search'">
        <xsl:variable name="page_url">search</xsl:variable>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="page_url">box</xsl:variable>
      </xsl:otherwise>
    </xsl:choose>
    <thead>
      <tr>
        <xsl:if test="not(/page/@mode)">
          <th class="center">
            <input type="checkbox" name="ch_all" value="1" onClick="sel_all();"/>
          </th>
        </xsl:if>
        <th class="center">
          <xsl:if test="messages/order = '1'">
            <xsl:attribute name="class">sortcolc</xsl:attribute>
          </xsl:if>
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">javascript: boxSubmit('<xsl:value-of select="/page/folder_id"/>,<xsl:value-of select="messages/skiped"/>,1,<xsl:value-of select="$next_ord"/><xsl:value-of select="eparams"/>'); </xsl:with-param>
            <xsl:with-param name="title">Read/Unread column</xsl:with-param>
            <xsl:with-param name="img">/oMail/i/st.gif</xsl:with-param>
          </xsl:call-template>
        </th>
        <th class="center">
          <xsl:if test="messages/order = '2'">
            <xsl:attribute name="class">sortcolc</xsl:attribute>
          </xsl:if>
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">javascript: boxSubmit('<xsl:value-of select="/page/folder_id"/>,<xsl:value-of select="messages/skiped"/>,2,<xsl:value-of select="$next_ord"/><xsl:value-of select="eparams"/>'); </xsl:with-param>
            <xsl:with-param name="title">Priority column</xsl:with-param>
            <xsl:with-param name="img">/oMail/i/pr.gif</xsl:with-param>
            <xsl:with-param name="img_hspace">3</xsl:with-param>
          </xsl:call-template>
        </th>
        <th class="center">
          <xsl:if test="messages/order = '7'">
            <xsl:attribute name="class">sortcolc</xsl:attribute>
          </xsl:if>
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">javascript: boxSubmit('<xsl:value-of select="/page/folder_id"/>,<xsl:value-of select="messages/skiped"/>,7,<xsl:value-of select="$next_ord"/><xsl:value-of select="eparams"/>'); </xsl:with-param>
            <xsl:with-param name="title">Attachments column</xsl:with-param>
            <xsl:with-param name="img">/oMail/i/at.gif</xsl:with-param>
          </xsl:call-template>
        </th>
        <th>
          <xsl:if test="messages/order = '3'">
            <xsl:attribute name="class">sortcol</xsl:attribute>
          </xsl:if>
          <a>
            <xsl:attribute name="href">javascript: boxSubmit('<xsl:value-of select="/page/folder_id"/>,<xsl:value-of select="messages/skiped"/>,3,<xsl:value-of select="$next_ord"/><xsl:value-of select="eparams"/>');</xsl:attribute>
            <xsl:attribute name="title"><xsl:value-of select="$cell"/> column</xsl:attribute>
            <xsl:if test="messages/order = '3'">
              <xsl:call-template name="direction"/>
            </xsl:if>
            <xsl:value-of select="$cell"/>
          </a>
        </th>
        <th>
          <xsl:if test="messages/order = '4'">
            <xsl:attribute name="class">sortcol</xsl:attribute>
          </xsl:if>
          <a>
            <xsl:attribute name="href">javascript: boxSubmit('<xsl:value-of select="/page/folder_id"/>,<xsl:value-of select="messages/skiped"/>,4,<xsl:value-of select="$next_ord"/><xsl:value-of select="eparams"/>');</xsl:attribute>
            <xsl:attribute name="title">Subject column</xsl:attribute>
            <xsl:if test="messages/order = '4'">
              <xsl:call-template name="direction"/>
            </xsl:if>
            <xsl:text>Subject</xsl:text>
          </a>
        </th>
        <th>
          <xsl:if test="messages/order = '5'">
            <xsl:attribute name="class">sortcol</xsl:attribute>
          </xsl:if>
          <a>
            <xsl:attribute name="href">javascript: boxSubmit('<xsl:value-of select="/page/folder_id"/>,<xsl:value-of select="messages/skiped"/>,5,<xsl:value-of select="$next_ord"/><xsl:value-of select="eparams"/>');</xsl:attribute>
            <xsl:attribute name="title"><xsl:value-of select="$date_cell"/> column</xsl:attribute>
            <xsl:if test="messages/order = '5'">
              <xsl:call-template name="direction"/>
            </xsl:if>
            <xsl:value-of select="$date_cell"/>
          </a>
        </th>
        <th align="right">
          <xsl:if test="messages/order = '6'">
            <xsl:attribute name="class">sortcol</xsl:attribute>
          </xsl:if>
          <a>
            <xsl:attribute name="href">javascript: boxSubmit('<xsl:value-of select="/page/folder_id"/>,<xsl:value-of select="messages/skiped"/>,6,<xsl:value-of select="$next_ord"/><xsl:value-of select="eparams"/>');</xsl:attribute>
            <xsl:attribute name="title">Size column</xsl:attribute>
            <xsl:if test="messages/order = '6'">
              <xsl:call-template name="direction"/>
            </xsl:if>
            <xsl:text>Size</xsl:text>
          </a>
        </th>
      </tr>
    </thead>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="messages/message">
    <xsl:choose>
      <xsl:when test="/page/@mode = 'popup'">
        <xsl:variable name="open_url">javascript:Go(<xsl:value-of select="msg_id"/>,'<xsl:value-of select="subject"/>')</xsl:variable>
      </xsl:when>
      <xsl:when test="/page/folder_id = 130">
        <xsl:variable name="open_url">write.vsp?sid=<xsl:value-of select="$sid"/>&amp;realm=<xsl:value-of select="$realm"/>&amp;wp=<xsl:value-of select="msg_id"/>
        </xsl:variable>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="open_url">open.vsp?sid=<xsl:value-of select="$sid"/>&amp;realm=<xsl:value-of select="$realm"/>&amp;op=<xsl:value-of select="msg_id"/>,<xsl:value-of select="position"/>
        </xsl:variable>
      </xsl:otherwise>
    </xsl:choose>
    <tr>
      <xsl:call-template name="LH"/>
      <xsl:if test="mstatus = 0">
        <xsl:attribute name="class">mark</xsl:attribute>
      </xsl:if>
      <xsl:if test="not(/page/@mode)">
        <td align="center">
          <input type="checkbox" name="ch_msg" onClick="CCA(this);">
            <xsl:attribute name="value"><xsl:value-of select="msg_id"/></xsl:attribute>
          </input>
        </td>
      </xsl:if>
      <td align="center">
        <img>
          <xsl:attribute name="SRC">/oMail/i/m_<xsl:value-of select="mstatus"/>.gif</xsl:attribute>
        </img>
      </td>
      <td align="center">
        <img>
          <xsl:attribute name="SRC">/oMail/i/pr_<xsl:value-of select="priority"/>.gif</xsl:attribute>
        </img>
      </td>
      <td align="center">
        <xsl:choose>
          <xsl:when test="attached > 0">
            <img src="/oMail/i/at.gif">
              <xsl:attribute name="alt">This message have <xsl:value-of select="attached"/> attached file(s)</xsl:attribute>
            </img>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="nbsp"/>
          </xsl:otherwise>
        </xsl:choose>
      </td>
      <td>
        <a>
          <xsl:attribute name="href"><xsl:value-of select="$open_url"/></xsl:attribute>
          <xsl:attribute name="title"><xsl:call-template name="show_name_alt"/></xsl:attribute>
          <xsl:call-template name="show_name"/>
        </a>
      </td>
      <td>
        <a>
          <xsl:attribute name="href"><xsl:value-of select="$open_url"/></xsl:attribute>
          <xsl:attribute name="title"><xsl:value-of select="subject"/></xsl:attribute>
          <xsl:call-template name="show_subject"/>
        </a>
      </td>
      <td>
        <xsl:call-template name="format_date">
          <xsl:with-param name="date" select="rcv_date"/>
          <xsl:with-param name="format" select="'%d.%m.%Y'"/>
        </xsl:call-template>
        <font size="1">
          <xsl:call-template name="format_date">
            <xsl:with-param name="date" select="rcv_date"/>
            <xsl:with-param name="format" select="' %H:%M'"/>
          </xsl:call-template>
        </font>
      </td>
      <td align="right">
        <xsl:call-template name="size2str">
          <xsl:with-param name="size" select="dsize"/>
        </xsl:call-template>
      </td>
    </tr>
  </xsl:template>

  <!-- ====================================================================================== -->
  <xsl:template name="message_empty">
    <xsl:param name="count"/>
    <xsl:if test="$count < messages/show_res">
      <tr>
        <td colspan="8" height="24">
          <xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text>
        </td>
      </tr>
      <xsl:call-template name="message_empty">
        <xsl:with-param name="count" select="$count+1"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <!-- ====================================================================================== -->
  <xsl:template match="folders" mode="combo">
    <xsl:if test="count(//messages/message) != 0">
      <table cellpadding="0" cellspacing="0" width="100%" class="content">
        <tfoot>
          <tr>
            <td>
              <xsl:call-template name="nbsp"/>Move selected to
  	 	        <select name="fid">
                <xsl:apply-templates select="folder"/>
              </select>
              <xsl:call-template name="make_href">
                <xsl:with-param name="url">javascript: if (anySelected(document.f1, 'ch_msg', 'No messages were selected to be moved.')) formSubmit('fa_move.x', '1'); </xsl:with-param>
                <xsl:with-param name="title">Move</xsl:with-param>
                <xsl:with-param name="img">/oMail/i/move_16.png</xsl:with-param>
                <xsl:with-param name="img_label"> Move</xsl:with-param>
                <xsl:with-param name="class">button</xsl:with-param>
              </xsl:call-template>
            </td>
            <td class="right">
              <xsl:if test="/page/folder_id = 110">
                <xsl:call-template name="make_href">
                  <xsl:with-param name="url">tools.vsp</xsl:with-param>
                  <xsl:with-param name="params">tp=<xsl:value-of select="/page/folder_id"/>,2,1,1</xsl:with-param>
                  <xsl:with-param name="label">Delete All</xsl:with-param>
                  <xsl:with-param name="img">/oMail/i/del_16.png</xsl:with-param>
                  <xsl:with-param name="img_label"> Delete All</xsl:with-param>
                  <xsl:with-param name="class">button</xsl:with-param>
                </xsl:call-template>
              </xsl:if>
              <xsl:call-template name="make_href">
                <xsl:with-param name="url">javascript: if (anySelected(document.f1, 'ch_msg', 'No messages were selected to be deleted.')) formSubmit('fa_delete.x', '1'); </xsl:with-param>
                <xsl:with-param name="lable">Delete Selected</xsl:with-param>
                <xsl:with-param name="img">/oMail/i/del_16.png</xsl:with-param>
                <xsl:with-param name="img_label"> Delete</xsl:with-param>
                <xsl:with-param name="class">button</xsl:with-param>
              </xsl:call-template>
            </td>
          </tr>
        </tfoot>
      </table>
    </xsl:if>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="folder">
    <option>
      <xsl:attribute name="value"><xsl:value-of select="folder_id"/></xsl:attribute>
      <xsl:value-of select="level/@str"/>
      <xsl:value-of select="name"/>
    </option>
    <xsl:apply-templates select="folders/folder"/>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="skiped">
    <table cellpadding="0" cellspacing="0" width="100%" id="paging">
      <tr>
        <xsl:choose>
          <xsl:when test="messages/skiped + (messages/all_res - messages/skiped - messages/show_res) > 0 ">
            <td class="cleft">
              <xsl:choose>
                <xsl:when test="messages/skiped > 0">
                  <xsl:call-template name="make_href">
                    <xsl:with-param name="url">javascript: boxSubmit('<xsl:value-of select="folder_id"/>,0,<xsl:value-of select="/page/messages/order"/>,<xsl:value-of select="/page/messages/direction"/><xsl:value-of select="/page/eparams"/>');</xsl:with-param>
                    <xsl:with-param name="label">First</xsl:with-param>
                    <xsl:with-param name="title">First page</xsl:with-param>
                  </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>First</xsl:otherwise>
              </xsl:choose>
              <xsl:call-template name="nbsp"/>
            </td>
            <td class="ccenter">
              <xsl:choose>
                <xsl:when test="messages/skiped > 0">
                  <xsl:call-template name="make_href">
                    <xsl:with-param name="url">javascript: boxSubmit('<xsl:value-of select="folder_id"/>,<xsl:value-of select="messages/skiped - messages/show_res"/>,<xsl:value-of select="/page/messages/order"/>,<xsl:value-of select="/page/messages/direction"/><xsl:value-of select="/page/eparams"/>');</xsl:with-param>
                    <xsl:with-param name="label">Previous</xsl:with-param>
                    <xsl:with-param name="title">Previous page</xsl:with-param>
                  </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>Previous</xsl:otherwise>
              </xsl:choose>
              <xsl:call-template name="nbsp"/>|<xsl:call-template name="nbsp"/>
              <xsl:choose>
                <xsl:when test="(messages/skiped + messages/show_res) &lt; messages/all_res">
                  <xsl:call-template name="make_href">
                    <xsl:with-param name="url">javascript: boxSubmit('<xsl:value-of select="folder_id"/>,<xsl:value-of select="messages/skiped + messages/show_res"/>,<xsl:value-of select="/page/messages/order"/>,<xsl:value-of select="/page/messages/direction"/><xsl:value-of select="/page/eparams"/>');</xsl:with-param>
                    <xsl:with-param name="label">Next</xsl:with-param>
                    <xsl:with-param name="title">Next page</xsl:with-param>
                  </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>Next</xsl:otherwise>
              </xsl:choose>
            </td>
            <td class="cright">
              <xsl:call-template name="nbsp"/>
              <xsl:choose>
                <xsl:when test="(messages/skiped + messages/show_res) &lt; messages/all_res">
                  <xsl:call-template name="make_href">
                    <xsl:with-param name="url">javascript: boxSubmit('<xsl:value-of select="folder_id"/>,<xsl:value-of select="round(((messages/all_res + messages/show_res - 1) div (messages/show_res)) - 1) * messages/show_res"/>,<xsl:value-of select="/page/messages/order"/>,<xsl:value-of select="/page/messages/direction"/><xsl:value-of select="/page/eparams"/>');</xsl:with-param>
                    <xsl:with-param name="label">Last</xsl:with-param>
                    <xsl:with-param name="title">Last page</xsl:with-param>
                  </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>Last</xsl:otherwise>
              </xsl:choose>
            </td>
          </xsl:when>
          <xsl:otherwise>
            <td>
              <xsl:call-template name="nbsp"/>
            </td>
          </xsl:otherwise>
        </xsl:choose>
      </tr>
    </table>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="external_action">
    <script>
      <xsl:text>
    function Go(msg_id,subject){
      if(opener){
        </xsl:text>
      <xsl:apply-templates select="return"/>
      <xsl:apply-templates select="external_params"/>
      <xsl:if test="not(substring-before(.,'!'))">
        <xsl:text>
        opener_form.submit();
    </xsl:text>
      </xsl:if>
      <xsl:text>
        window.close();
      }else{
        alert('Missing parent window')
      }
    }
  </xsl:text>
    </script>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="return">
    <xsl:choose>
      <xsl:when test="substring-before(.,'!')">
        <xsl:text>opener_form = opener.document.</xsl:text>
        <xsl:value-of select="substring-before(.,'!')"/>
        <xsl:text>;
      </xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>opener_form = opener.document.</xsl:text>
        <xsl:value-of select="."/>
        <xsl:text>;
      </xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="external_params">
    <xsl:for-each select="*">
      <xsl:choose>
        <xsl:when test=". = 'msg_id'">
          <xsl:text>      opener_form.</xsl:text>
          <xsl:value-of select="name()"/>
          <xsl:text>.value = msg_id
    </xsl:text>
        </xsl:when>
        <xsl:when test=". = 'subject'">
          <xsl:text>      opener_form.</xsl:text>
          <xsl:value-of select="name()"/>
          <xsl:text>.value = subject
    </xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>      opener_form.</xsl:text>
          <xsl:value-of select="name()"/>
          <xsl:text>.value = '</xsl:text>
          <xsl:value-of select="."/>
          <xsl:text>'
    </xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>
</xsl:stylesheet>
