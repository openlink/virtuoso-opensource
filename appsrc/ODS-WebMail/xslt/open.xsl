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
  <xsl:include href="html_parse.xsl"/>
  <xsl:include href="handlers.xsl"/>
  <xsl:include href="common_folders.xsl"/>
  <xsl:variable name="fid" select="/page/message/folder_id"/>
  <!-- ====================================================================================== -->
  <xsl:template match="page">
    <form method="post" name="f1">
      <xsl:attribute name="action"><xsl:value-of select="$iri" />/open.vsp</xsl:attribute>
      <xsl:call-template name="hid_sid"/>
      <xsl:call-template name="msg_tools"/>
      <xsl:apply-templates select="message"/>
      <table cellpadding="0" cellspacing="0" border="0" width="100%">
        <tr>
          <td>
            <xsl:call-template name="nbsp"/>
          </td>
          <td>
            <br/>
            <xsl:choose>
              <xsl:when test="message/type_id = 10100">
                <pre class="mb">
                  <xsl:apply-templates select="message/mbody"/>
                </pre>
              </xsl:when>
              <xsl:otherwise>
                <xsl:apply-templates select="message/mbody"/>
              </xsl:otherwise>
            </xsl:choose>
            <br/>
            <br/>
          </td>
        </tr>
      </table>
      <xsl:apply-templates select="attachments_msg"/>
      <xsl:apply-templates select="attachment_preview"/>
      <xsl:apply-templates select="attachments"/>
      <br/>
      <xsl:if test="not(@mode)">
        <xsl:call-template name="msg_tools_advance"/>
      </xsl:if>
      <!-- /goliamata burkotia -->
      <xsl:apply-templates select="eparams"/>
    </form>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="message">
    <table width="100%" cellpadding="0" cellspacing="0" class="content">
      <colgroup>
        <col class="w160"/>
      </colgroup>
      <!-- From -->
      <tr>
        <th>From</th>
        <td>
          <xsl:apply-templates select="address/addres_list/from"/>
        </td>
      </tr>
      <!-- To -->
      <tr>
        <th>To</th>
        <td>
          <xsl:apply-templates select="address/addres_list/to"/>
        </td>
      </tr>
      <!-- CC -->
      <xsl:if test="address/addres_list/cc">
        <tr>
          <th>CC</th>
          <td>
            <xsl:apply-templates select="address/addres_list/cc"/>
          </td>
        </tr>
      </xsl:if>
      <!-- BCC -->
      <xsl:if test="address/addres_list/bcc">
        <tr>
          <th>BCC</th>
          <td>
            <xsl:apply-templates select="address/addres_list/bcc"/>
          </td>
        </tr>
      </xsl:if>
      <!-- Subject -->
      <tr>
        <th>Subject</th>
        <td>
          <xsl:value-of select="subject"/>
        </td>
      </tr>
      <!-- Date -->
      <tr>
        <th>Date</th>
        <td>
          <xsl:call-template name="format_date">
            <xsl:with-param name="date" select="rcv_date"/>
            <xsl:with-param name="format" select="'%d.%m.%Y %H:%M'"/>
          </xsl:call-template>
        </td>
      </tr>
      <!-- Size -->
      <tr>
        <th>Size</th>
        <td>
          <xsl:call-template name="size2str">
            <xsl:with-param name="size" select="dsize"/>
            <xsl:with-param name="mode" select="1"/>
          </xsl:call-template>
          <xsl:choose>
            <xsl:when test="attached = 1"> (<b>1</b> file attached)	</xsl:when>
            <xsl:when test="attached > 1"> (<xsl:value-of select="attached"/> files attached)</xsl:when>
          </xsl:choose>
        </td>
      </tr>
      <!-- Options -->
      <xsl:if test="options/ssl = 1">
        <tr>
          <th>Options</th>
          <td>
            Signed: <b>Yes</b>
            <xsl:choose>
              <xsl:when test="options/sslVerified = 1">
                <b><i>(verified)</i></b>
              </xsl:when>
              <xsl:otherwise>
                <xsl:if test="options/webID != ''">; WebID: <b><xsl:value-of select="options/webID" /></b>
                  <xsl:if test="options/webIDVerified">
                    (<img src="/ods/images/icons/lock_16.png" height="14" />)
                  </xsl:if>
                </xsl:if>
              </xsl:otherwise>
            </xsl:choose>
          </td>
        </tr>
      </xsl:if>
      <!-- Tags -->
      <tr>
        <th>Comma separated tags</th>
        <td>
          <input type="text" name="tags" size="66" >
            <xsl:attribute name="value"><xsl:value-of select="tags"/></xsl:attribute>
          </input>
          <xsl:call-template name="nbsp"/>
          <input type="button" value="Clear" onclick="javascript: document.f1.elements['tags'].value = ''" class="button" />
          <xsl:call-template name="nbsp"/>
          <xsl:call-template name="make_submit">
            <xsl:with-param name="name">fa_tags_save</xsl:with-param>
            <xsl:with-param name="value">Save</xsl:with-param>
            <xsl:with-param name="alt">Save Tags</xsl:with-param>
            <xsl:with-param name="class">button</xsl:with-param>
          </xsl:call-template>
        </td>
      </tr>
      <!-- Attach -->
      <xsl:if test="count(mime_list/mime_types) != 1">
      <tr>
        <th>Versions</th>
        <td>
          <xsl:apply-templates select="mime_list/mime_types"/>
        </td>
      </tr>
      </xsl:if>
    </table>
  </xsl:template>

  <!-- ====================================================================================== -->
  <xsl:template match="address/addres_list/from | address/addres_list/to | address/addres_list/cc | address/addres_list/bcc">
    <xsl:variable name="address">
    <xsl:choose>
        <xsl:when test="string(name) != ''"><xsl:value-of select="name" /></xsl:when>
        <xsl:when test="string(email)!= ''"><xsl:value-of select="email" /></xsl:when>
        <xsl:otherwise>~no address~</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:value-of select="$address" />
    <xsl:if test="$address != '~no address~'">
      <xsl:if test="//user_info/app > 0">
        <xsl:call-template name="nbsp" />
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">javascript: void(0);</xsl:with-param>
          <xsl:with-param name="label"><xsl:value-of select="$address" /></xsl:with-param>
          <xsl:with-param name="img">/ods/images/icons/rdf_11.png</xsl:with-param>
          <xsl:with-param name="id">address_<xsl:value-of select="generate-id ()"/></xsl:with-param>
          <xsl:with-param name="style">display: none;</xsl:with-param>
        </xsl:call-template>
      </xsl:if>
      <xsl:if test="//message/addContact != ''">
        <xsl:call-template name="nbsp" />
        <xsl:call-template name="make_href">
          <xsl:with-param name="url"><xsl:value-of select="//message/addContact" /></xsl:with-param>
          <xsl:with-param name="title">Add contact <xsl:value-of select="$address" /></xsl:with-param>
          <xsl:with-param name="params">id=-1&amp;name=<xsl:value-of select="name" />&amp;mail=<xsl:value-of select="email" /></xsl:with-param>
          <xsl:with-param name="img">/oMail/i/add_contact_16.png</xsl:with-param>
        </xsl:call-template>
      </xsl:if>
    </xsl:if>
    <xsl:if test="position() != last()">,</xsl:if>
  </xsl:template>

  <!-- ====================================================================================== -->
  <xsl:template match="message/mbody">
    <xsl:apply-templates/>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="message/mime_list/mime_types">
    <xsl:choose>
      <xsl:when test=".= 10110">
        <xsl:choose>
          <xsl:when test=". = /page/message/type_id">
            <b>html</b>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="make_href">
              <xsl:with-param name="url">open.vsp</xsl:with-param>
              <xsl:with-param name="label">html</xsl:with-param>
              <xsl:with-param name="title">Html view</xsl:with-param>
              <xsl:with-param name="params">op=<xsl:value-of select="/page/message/msg_id"/>,<xsl:value-of select="/page/list_pos"/>,<xsl:value-of select="."/>,<xsl:value-of select="/page/folder_view"/><xsl:value-of select="/page/eparams"/></xsl:with-param>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <xsl:choose>
          <xsl:when test=". = /page/message/type_id">
            <b>plain</b>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="make_href">
              <xsl:with-param name="url">open.vsp</xsl:with-param>
              <xsl:with-param name="label">plain</xsl:with-param>
              <xsl:with-param name="title">Plain text view</xsl:with-param>
              <xsl:with-param name="params">op=<xsl:value-of select="/page/message/msg_id"/>,<xsl:value-of select="/page/list_pos"/>,<xsl:value-of select="."/>,<xsl:value-of select="/page/folder_view"/><xsl:value-of select="/page/eparams"/></xsl:with-param>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
    |
  </xsl:template>
  <!-- ====================================================================================== -->
  <!-- Attachment MSG -->
  <!-- ====================================================================================== -->
  <xsl:template match="attachments_msg">
    <xsl:apply-templates select="attachment_msg"/>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="attachment_msg">
    <table width="95%" cellpadding="0" cellspacing="0" border="0" align="center">
      <tr>
        <td class="td"/>
        <td>
          <table width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#FFEEC6" align="center">
            <tr>
              <td colspan="2" height="20">
                <p class="mb">
                  <xsl:call-template name="nbsp"/>
                  <img src="/oMail/i/m_1.gif" width="13" height="12" align="top"/>
                  <xsl:call-template name="nbsp"/>
                  <xsl:call-template name="make_href">
                    <xsl:with-param name="url">open.vsp</xsl:with-param>
                    <xsl:with-param name="target">_blank</xsl:with-param>
                    <xsl:with-param name="label">Attached message - read it</xsl:with-param>
                    <xsl:with-param name="title">Read attached message</xsl:with-param>
                    <xsl:with-param name="params">op=<xsl:value-of select="msg_id"/>,<xsl:value-of select="/page/list_pos"/></xsl:with-param>
                  </xsl:call-template>
                </p>
              </td>
              <td align="right">
                <p class="mb">
                  <xsl:call-template name="make_href">
                    <xsl:with-param name="url">box.vsp</xsl:with-param>
                    <xsl:with-param name="title">Delete attached message</xsl:with-param>
                    <xsl:with-param name="params">bp=100&amp;fa_erase.x=1&amp;ch_msg=<xsl:value-of select="msg_id"/>&amp;ru=open.vsp?op=<xsl:value-of select="/page/message/msg_id"/>,<xsl:value-of select="/page/list_pos"/></xsl:with-param>
                    <xsl:with-param name="img">/oMail/i/delete.gif</xsl:with-param>
                  </xsl:call-template>
                  <xsl:call-template name="nbsp"/>
                </p>
              </td>
            </tr>
            <!-- From -->
            <tr>
              <td>From</td>
              <td width="85%" colspan="2">
                <p class="mb">
                  <xsl:call-template name="nbsp"/>
                  <xsl:apply-templates select="address/addres_list/from"/>
                </p>
              </td>
            </tr>
            <!-- To -->
            <tr>
              <td>To</td>
              <td width="85%" colspan="2">
                <p class="mb">
                  <xsl:call-template name="nbsp"/>
                  <xsl:apply-templates select="address/addres_list/to"/>
                </p>
              </td>
            </tr>
            <xsl:if test="address/addres_list/cc">
              <tr>
                <td>CC</td>
                <td width="85%" colspan="2">
                  <p class="mb">
                    <xsl:call-template name="nbsp"/>
                    <xsl:apply-templates select="address/addres_list/cc"/>
                  </p>
                </td>
              </tr>
            </xsl:if>
            <!-- Subject -->
            <tr>
              <td>Subject</td>
              <td width="85%" colspan="2">
                <p class="mb">
                  <xsl:call-template name="nbsp"/>
                  <xsl:value-of select="subject"/>
                </p>
              </td>
            </tr>
            <!-- Date -->
            <tr>
              <td>Date</td>
              <td width="85%" colspan="2">
                <p class="mb">
                  <xsl:call-template name="nbsp"/>
                  <xsl:call-template name="format_date">
                    <xsl:with-param name="date" select="rcv_date"/>
                    <xsl:with-param name="format" select="'%d.%m.%Y %H:%M'"/>
                  </xsl:call-template>
                </p>
              </td>
            </tr>
            <!-- Size -->
            <tr>
              <td>Size</td>
              <td width="85%" colspan="2">
                <p class="mb">
                  <xsl:call-template name="nbsp"/>
                  <xsl:call-template name="size2str">
                    <xsl:with-param name="size" select="dsize"/>
                    <xsl:with-param name="mode" select="1"/>
                  </xsl:call-template>
                  <xsl:choose>
                    <xsl:when test="attached = 1"> (<b>1</b> file attached)</xsl:when>
                    <xsl:when test="attached > 1"> (<xsl:value-of select="attached"/> files attached)</xsl:when>
                  </xsl:choose>
                </p>
              </td>
            </tr>
          </table>
        </td>
        <td />
      </tr>
    </table>
    <br/>
  </xsl:template>
  <!-- ====================================================================================== -->
  <!-- Attachment FILE -->
  <!-- ====================================================================================== -->
  <xsl:template match="attachments">
    <!-- prikacheni failove -->
    <table width="60%" cellpadding="0" cellspacing="0" border="0" align="center" class="content">
      <colgroup>
        <col class="c"/>
        <col/>
        <col/>
        <col class="c"/>
        <col class="c"/>
      </colgroup>
      <thead>
        <tr>
          <th>
            <img src="/oMail/i/at.gif" width="6" height="12"/>
          </th>
          <th>Attached File</th>
          <th>Type</th>
          <th>Size</th>
          <th>Action</th>
        </tr>
      </thead>
      <xsl:apply-templates select="attachment_preview"/>
      <xsl:apply-templates select="attachment"/>
    </table>
    <!-- /prikacheni failove -->
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="attachment">
    <xsl:choose>
      <xsl:when test="string-length(pname) = 0">
        <xsl:variable name="pname">~no name~</xsl:variable>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="pname" select="pname"/>
      </xsl:otherwise>
    </xsl:choose>
    <tr>
      <td>
        <img>
          <xsl:attribute name="src"><xsl:text>/oMail/res/image.vsp?id=</xsl:text><xsl:value-of select="type_id"/><xsl:text>&amp;ext=</xsl:text><xsl:value-of select="mime_ext_id"/></xsl:attribute>
        </img>
      </td>
      <td>
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">dload.vsp</xsl:with-param>
          <xsl:with-param name="params">dp=<xsl:value-of select="/page/message/msg_id"/>,<xsl:value-of select="part_id"/></xsl:with-param>
          <xsl:with-param name="target">_blank</xsl:with-param>
          <xsl:with-param name="label"><xsl:value-of select="$pname"/></xsl:with-param>
          <xsl:with-param name="title">Attachment <xsl:value-of select="$pname"/></xsl:with-param>
        </xsl:call-template>
      </td>
      <td>
        <xsl:value-of select="mime_type"/>
      </td>
      <td>
        <xsl:call-template name="size2str">
          <xsl:with-param name="size" select="dsize"/>
          <xsl:with-param name="mode" select="1"/>
        </xsl:call-template>
      </td>
      <td>
        <xsl:call-template name="dload_utl"/>
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">attach.vsp</xsl:with-param>
          <xsl:with-param name="params">ap=<xsl:value-of select="/page/message/msg_id"/>,1,<xsl:value-of select="part_id"/>&amp;back=open</xsl:with-param>
          <xsl:with-param name="label">Delete Attachment</xsl:with-param>
          <xsl:with-param name="img">/oMail/i/del_16.png</xsl:with-param>
          <xsl:with-param name="img_label"> Delete</xsl:with-param>
          <xsl:with-param name="class">button</xsl:with-param>
        </xsl:call-template>
      </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="dload_utl">
    <xsl:choose>
      <xsl:when test="type_id = 10150">
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">./contacts/vmail.vsp</xsl:with-param>
          <xsl:with-param name="target">_blank</xsl:with-param>
          <xsl:with-param name="label">Add to contacts</xsl:with-param>
          <xsl:with-param name="title">Add to contacts</xsl:with-param>
          <xsl:with-param name="params">mid=<xsl:value-of select="/page/message/msg_id"/>&amp;pid=<xsl:value-of select="part_id"/></xsl:with-param>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="type_id = 10125">
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">open.vsp</xsl:with-param>
          <xsl:with-param name="target">_blank</xsl:with-param>
          <xsl:with-param name="label">Read it</xsl:with-param>
          <xsl:with-param name="title">Read it</xsl:with-param>
          <xsl:with-param name="params">op=<xsl:value-of select="/page/message/msg_id"/></xsl:with-param>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="type_id = 10160">
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">open.vsp</xsl:with-param>
          <xsl:with-param name="target">_blank</xsl:with-param>
          <xsl:with-param name="label">Add to calendar</xsl:with-param>
          <xsl:with-param name="title">Add to calendar</xsl:with-param>
          <xsl:with-param name="params">a=m&amp;mid=<xsl:value-of select="/page/message/msg_id"/>&amp;pid=<xsl:value-of select="part_id"/></xsl:with-param>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">dload.vsp</xsl:with-param>
          <xsl:with-param name="params">dp=<xsl:value-of select="/page/message/msg_id"/>,<xsl:value-of select="part_id"/>,1</xsl:with-param>
          <xsl:with-param name="target">_blank</xsl:with-param>
          <xsl:with-param name="label">Download</xsl:with-param>
          <xsl:with-param name="img">/oMail/i/impt_16.png</xsl:with-param>
          <xsl:with-param name="img_label"> Download</xsl:with-param>
          <xsl:with-param name="class">button</xsl:with-param>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="msg_tools">
    <table cellpadding="0" cellspacing="0" width="100%">
      <input type="hidden" name="op">
        <xsl:attribute name="value"><xsl:value-of select="op"/></xsl:attribute>
      </input>
      <input type="hidden" name="ch_msg">
        <xsl:attribute name="value"><xsl:value-of select="message/msg_id"/></xsl:attribute>
      </input>
      <tr>
        <td>
          <ul id="buttons">
            <li>
              <xsl:call-template name="make_href">
                <xsl:with-param name="url">write.vsp</xsl:with-param>
                <xsl:with-param name="label">reply</xsl:with-param>
                <xsl:with-param name="title">Reply message</xsl:with-param>
                <xsl:with-param name="params">wp=0,0,1,<xsl:value-of select="/page/message/msg_id"/><xsl:value-of select="eparams"/></xsl:with-param>
              </xsl:call-template>
            </li>
            <li>
              <xsl:call-template name="make_href">
                <xsl:with-param name="url">write.vsp</xsl:with-param>
                <xsl:with-param name="label">reply to all</xsl:with-param>
                <xsl:with-param name="title">Reply message to all</xsl:with-param>
                <xsl:with-param name="params">wp=0,0,2,<xsl:value-of select="/page/message/msg_id"/><xsl:value-of select="eparams"/></xsl:with-param>
              </xsl:call-template>
            </li>
            <li>
              <xsl:call-template name="make_href">
                <xsl:with-param name="url">write.vsp</xsl:with-param>
                <xsl:with-param name="label">forward</xsl:with-param>
                <xsl:with-param name="title">Forward message</xsl:with-param>
                <xsl:with-param name="params">wp=0,0,3,<xsl:value-of select="/page/message/msg_id"/><xsl:value-of select="eparams"/></xsl:with-param>
              </xsl:call-template>
            </li>
            <li>
              <xsl:choose>
                <xsl:when test="/page/@mode = 'popup'">
                  <xsl:call-template name="make_href">
                    <xsl:with-param name="url">javascript:window.close();</xsl:with-param>
                    <xsl:with-param name="label">close</xsl:with-param>
                    <xsl:with-param name="title">Close</xsl:with-param>
                  </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:call-template name="make_href">
                    <xsl:with-param name="url">box.vsp</xsl:with-param>
                    <xsl:with-param name="label">close</xsl:with-param>
                    <xsl:with-param name="title">Close</xsl:with-param>
                    <xsl:with-param name="params">bp=<xsl:value-of select="/page/message/folder_id"/></xsl:with-param>
                  </xsl:call-template>
                </xsl:otherwise>
              </xsl:choose>
            </li>
            <xsl:choose>
              <xsl:when test="/page/@mode = 'popup'">
            </xsl:when>
              <xsl:otherwise>
                <li class="right">
                  <xsl:call-template name="make_href">
                    <xsl:with-param name="url">box.vsp</xsl:with-param>
                    <xsl:with-param name="label">delete</xsl:with-param>
                    <xsl:with-param name="title">Delete message</xsl:with-param>
                    <xsl:with-param name="params">bp=<xsl:value-of select="/page/message/folder_id"/>&amp;fa_delete.x=1&amp;ch_msg=<xsl:value-of select="/page/message/msg_id"/></xsl:with-param>
                    <xsl:with-param name="class">del</xsl:with-param>
                  </xsl:call-template>
                </li>
              </xsl:otherwise>
            </xsl:choose>
            <li class="right">
              <xsl:call-template name="make_href">
                <xsl:with-param name="url">javascript:window.print();</xsl:with-param>
                <xsl:with-param name="label">print</xsl:with-param>
                <xsl:with-param name="title">Print message</xsl:with-param>
              </xsl:call-template>
            </li>
            <li class="right">
              <xsl:call-template name="make_href">
                <xsl:with-param name="url">open.vsp</xsl:with-param>
                <xsl:with-param name="label">mark as <xsl:if test="message/mstatus=1">un</xsl:if>read</xsl:with-param>
                <xsl:with-param name="title">Read/unread message</xsl:with-param>
                <xsl:with-param name="params">fa_mark.x=mark&amp;ms=<xsl:choose><xsl:when test="message/mstatus = '0'">1</xsl:when><xsl:otherwise>0</xsl:otherwise></xsl:choose>&amp;op=<xsl:value-of select="/page/message/msg_id"/>,<xsl:value-of select="/page/list_pos"/>,<xsl:value-of select="/page/message/type_id"/>,<xsl:value-of select="/page/folder_view"/><xsl:value-of select="eparams"/></xsl:with-param>
                <xsl:with-param name="class">w</xsl:with-param>
              </xsl:call-template>
            </li>
          </ul>
        </td>
      </tr>
    </table>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="msg_tools_advance">
    <table cellpadding="0" cellspacing="0" width="100%" id="tools">
      <input type="hidden" name="op">
        <xsl:attribute name="value"><xsl:value-of select="op"/></xsl:attribute>
      </input>
      <input type="hidden" name="ch_msg">
        <xsl:attribute name="value"><xsl:value-of select="message/msg_id"/></xsl:attribute>
      </input>
      <xsl:choose>
        <xsl:when test="/page/message/parent_id = 0">
          <tr>
            <th class="left">
              <label for="fid">Move to folder</label>
              <xsl:apply-templates select="foldersCombo" mode="combo" />
              <xsl:call-template name="make_href">
                <xsl:with-param name="url">javascript: formSubmit('fa_move.x', '1'); </xsl:with-param>
                <xsl:with-param name="title">Move</xsl:with-param>
                <xsl:with-param name="img">/oMail/i/move_16.png</xsl:with-param>
                <xsl:with-param name="img_label"> Move</xsl:with-param>
                <xsl:with-param name="class">button</xsl:with-param>
              </xsl:call-template>
            </th>
          </tr>
        </xsl:when>
      </xsl:choose>
    </table>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="paging">
    <table cellpadding="0" cellspacing="0" border="1">
      <tr>
        <xsl:choose>
          <xsl:when test="/page/message/parent_id = 0">
            <td width="80">
              <xsl:if test="/page/message/prev > 0">
                <xsl:call-template name="make_href">
                  <xsl:with-param name="url">open.vsp</xsl:with-param>
                  <xsl:with-param name="label">prev msg</xsl:with-param>
                  <xsl:with-param name="title">Previous message</xsl:with-param>
                  <xsl:with-param name="img">/oMail/i/arrow_up.gif</xsl:with-param>
                  <xsl:with-param name="params">op=<xsl:value-of select="/page/message/prev"/>,<xsl:value-of select="/page/list_pos - 1"/></xsl:with-param>
                </xsl:call-template>
              </xsl:if>
            </td>
            <td>
              <xsl:call-template name="nbsp"/>|<xsl:call-template name="nbsp"/>
            </td>
            <td>
              <xsl:if test="/page/message/next > 0">
                <xsl:call-template name="make_href">
                  <xsl:with-param name="url">open.vsp</xsl:with-param>
                  <xsl:with-param name="label">next msg</xsl:with-param>
                  <xsl:with-param name="title">Next message</xsl:with-param>
                  <xsl:with-param name="img">/oMail/i/arrow_down.gif</xsl:with-param>
                  <xsl:with-param name="params">op=<xsl:value-of select="/page/message/next"/>,<xsl:value-of select="/page/list_pos + 1"/></xsl:with-param>
                </xsl:call-template>
              </xsl:if>
            </td>
          </xsl:when>
          <xsl:otherwise>
            <td colspan="3">
              <xsl:call-template name="nbsp"/>
            </td>
          </xsl:otherwise>
        </xsl:choose>
      </tr>
    </table>
  </xsl:template>

  <!-- ====================================================================================== -->
  <xsl:template name="url_escape">
    <xsl:param name="val"/>
    <xsl:if test="string-length($val) != 0">
      <xsl:choose>
        <xsl:when test="string-length(substring-before($val,' ')) != 0">
          <xsl:value-of select="substring-before($val,' ')"/>%20<xsl:value-of select="substring-after($val,' ')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$val"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
  </xsl:template>

  <!-- ====================================================================================== -->
</xsl:stylesheet>
