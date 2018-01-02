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
  <xsl:include href="common_folders.xsl"/>
  <!-- ====================================================================================== -->
  <xsl:template match="page">
    <script language="JavaScript">
      <![CDATA[
        function storeCaret (obj) {
          if (obj.createTextRange)
            obj.currRange = document.selection.createRange().duplicate();
        }

        var ids = new Array('from', 'to', 'cc', 'bcc', 'dcc', 'subject');
        var values = new Array('', '', '', '', '');

        function populateArrays() {
          // assign the default values to the items in the values array
          for (var i = 0; i < ids.length; i++) {
            var elem = document.forms['f1'].elements[ids[i]];
            if (elem) {
              if (elem.type == 'checkbox' || elem.type == 'radio')
                values[i] = elem.checked;
              else
                values[i] = elem.value;
            }
          }
        }

        var needToConfirm = true;
        window.onbeforeunload = confirmExit;

        function confirmExit() {
          if (needToConfirm) {
            // check to see if any changes to the data entry fields have been made
            returnValue(document.forms['f1'].elements['mt']);
            for (var i = 0; i < values.length; i++) {
              var elem = document.forms['f1'].elements[ids[i]];
              if (elem) {
                if ((elem.type == 'checkbox' || elem.type == 'radio') && values[i] != elem.checked)
                  return "You have attempted to leave this page. If you have made any changes to the fields without clicking the Send or Save buttons, your changes will be lost. Are you sure you want to exit this page?";
                if (!(elem.type == 'checkbox' || elem.type == 'radio') && elem.value != values[i])
                  return "You have attempted to leave this page. If you have made any changes to the fields without clicking the Send or Save buttons, your changes will be lost. Are you sure you want to exit this page?";
            }
          }
        }
        }
        function activateToggles() {
          var x_cc = false;
          var x_bcc = false;
          var x_dcc = false;
          if (document.forms['f1'].elements['eparams']) {
            var re = new RegExp('x_cc=1');
            if (re.test(document.forms['f1'].elements['eparams'].value))
              x_cc = true;
            var re = new RegExp('x_bcc=1');
            if (re.test(document.forms['f1'].elements['eparams'].value))
              x_bcc = true;
            var re = new RegExp('x_dcc=1');
            if (re.test(document.forms['f1'].elements['eparams'].value))
              x_dcc = true;
          }
          if (x_cc)
            OMAIL.toggleCell('cc');
          if (x_bcc)
            OMAIL.toggleCell('bcc');
          if (x_dcc)
            OMAIL.toggleCell('dcc');
        }

      ]]>
    </script>
    <form name="f1" method="post" enctype="multipart/form-data" onSubmit="javascript: returnValue(document.forms['f1'].elements['mt']); return true;">
      <xsl:attribute name="action"><xsl:value-of select="$iri" />/write.vsp</xsl:attribute>
      <xsl:call-template name="hid_sid"/>
      <input type="hidden" name="wp">
        <xsl:attribute name="value"><xsl:value-of select="wp"/></xsl:attribute>
      </input>
      <input type="hidden" name="ref_id">
        <xsl:attribute name="value"><xsl:value-of select="/page/message/ref_id"/></xsl:attribute>
      </input>
      <input type="hidden" name="ch_scopy">
        <xsl:attribute name="value"><xsl:value-of select="string(//save_copy)"/></xsl:attribute>
      </input>
      <xsl:apply-templates select="message/eparams"/>
      <xsl:apply-templates select="message/options/certificates/certificate"/>
      <xsl:call-template name="write_form"/>
    </form>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="write_form">
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="content">
      <colgroup>
        <col class="w160"/>
        <col/>
      </colgroup>
      <tr>
        <th>
          <xsl:call-template name="nbsp"/>
        </th>
        <td>
          <xsl:call-template name="make_submit">
            <xsl:with-param name="name">fa_send</xsl:with-param>
            <xsl:with-param name="value">send</xsl:with-param>
            <xsl:with-param name="alt">Send</xsl:with-param>
            <xsl:with-param name="src">/oMail/i/send.gif</xsl:with-param>
            <xsl:with-param name="onclick">javascript: needToConfirm = false;</xsl:with-param>
          </xsl:call-template>
          <xsl:call-template name="make_submit">
            <xsl:with-param name="name">fa_save</xsl:with-param>
            <xsl:with-param name="value">seve</xsl:with-param>
            <xsl:with-param name="alt">Save</xsl:with-param>
            <xsl:with-param name="src">/oMail/i/save.gif</xsl:with-param>
            <xsl:with-param name="onclick">javascript: needToConfirm = false;</xsl:with-param>
          </xsl:call-template>
          <xsl:call-template name="make_submit">
            <xsl:with-param name="name">fa_attach</xsl:with-param>
            <xsl:with-param name="value">attach</xsl:with-param>
            <xsl:with-param name="alt">Attach</xsl:with-param>
            <xsl:with-param name="src">/oMail/i/attach.gif</xsl:with-param>
            <xsl:with-param name="onclick">javascript: needToConfirm = false;</xsl:with-param>
          </xsl:call-template>
        </td>
      </tr>
      <tr>
        <th>
          <label for="addr_from">From</label>
        </th>
        <td>
          <select name="from" id="addr_from">
            <xsl:for-each select="accounts/account">
              <option>
                <xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute>
                <xsl:if test=". = ../../message/address/addres_list/from/email">
                  <xsl:attribute name="selected">selected</xsl:attribute>
                </xsl:if>
                <xsl:value-of select="."/>
              </option>
            </xsl:for-each>
          </select>
          <xsl:call-template name="nbsp"/>
          <a href="#" onClick="javascript: OMAIL.toggleCell('cc'); return false;"><label id="label_cc">Add CC</label></a>
          <xsl:call-template name="nbsp"/>
          <a href="#" onClick="javascript: OMAIL.toggleCell('bcc'); return false;"><label id="label_bcc">Add BCC</label></a>
          <xsl:if test="(//conversation = 1) and (//discussion = 1)">
            <xsl:call-template name="nbsp"/>
            <a href="#" onClick="javascript: OMAIL.toggleCell('dcc'); return false;"><label id="label_dcc">Add DCC</label></a>
          </xsl:if>
        </td>
      </tr>
      <tr>
        <th>
          <label for="addr_to">To</label>
        </th>
        <td>
          <input type="text" name="to" size="66" OnFocus="ClearFld(this,'~no address~');" id="addr_to">
            <xsl:attribute name="value"><xsl:apply-templates select="message/address/addres_list/to"/></xsl:attribute>
          </input>
          <xsl:call-template name="nbsp"/>
          <input type="button" value="Select" onclick="javascript: mailsShow('mails.vsp?set=to')" class="button" />
        </td>
      </tr>
      <tr id="row_cc" style="display: none;">
        <th>
          <label for="addr_cc">CC</label>
        </th>
        <td>
          <input type="text" name="cc" size="66" id="addr_cc">
            <xsl:attribute name="value"><xsl:apply-templates select="message/address/addres_list/cc"/></xsl:attribute>
          </input>
          <xsl:call-template name="nbsp"/>
          <input type="button" value="Select" onclick="javascript: mailsShow('mails.vsp?set=cc')" class="button" />
        </td>
      </tr>
      <tr id="row_bcc" style="display: none;">
        <th>
          <label for="addr_bcc">BCC</label>
        </th>
        <td>
          <input type="text" name="bcc" size="66" id="addr_bcc">
            <xsl:attribute name="value"><xsl:apply-templates select="message/address/addres_list/bcc"/></xsl:attribute>
          </input>
          <xsl:call-template name="nbsp"/>
          <input type="button" value="Select" onclick="javascript: mailsShow('mails.vsp?set=bcc')" class="button" />
        </td>
      </tr>
      <xsl:if test="//conversation = 1">
        <tr id="row_dcc" style="display: none;">
          <th>
            <label for="addr_dcc">DCC</label>
          </th>
          <td>
            <input type="text" name="dcc" size="66" id="addr_dcc">
              <xsl:attribute name="value"><xsl:apply-templates select="message/address/addres_list/dcc"/></xsl:attribute>
            </input>
          </td>
        </tr>
      </xsl:if>
      <tr>
        <th>
          <label for="addr_sbj">Subject</label>
        </th>
        <td>
          <input type="text" name="subject" size="66" onFocus="ClearFld(this,'~no subject~');" id="addr_sbj">
            <xsl:attribute name="value"><xsl:value-of select="message/subject"/></xsl:attribute>
          </input>
        </td>
      </tr>
      <!-- Tags -->
      <tr>
        <th>Comma separated tags</th>
        <td>
          <input type="text" name="tags" size="66" >
            <xsl:attribute name="value"><xsl:value-of select="message/tags"/></xsl:attribute>
          </input>
          <xsl:call-template name="nbsp"/>
          <input type="button" value="Clear" onclick="javascript: document.f1.elements['tags'].value = ''" class="button" />
        </td>
      </tr>
      <xsl:if test="count(attachments/attachment) > 0 ">
        <tr>
          <th>Files</th>
          <td>
      		  You have <xsl:value-of select="count(attachments/attachment)"/> attached file<xsl:if test="count(attachments/attachment) > 1">s</xsl:if> in this message.
      		  <a href="#attachments">
      		    (See list below)
    		    </a>
          </td>
        </tr>
      </xsl:if>
      <tr>
        <th>
          <xsl:call-template name="nbsp"/>
        </th>
        <td>
          <label>
            <input type="checkbox" name="mt" value="html" onclick="javascript: toggleTab(this);">
            <xsl:if test="message/type_id = 10110">
              <xsl:attribute name="checked">checked</xsl:attribute>
            </xsl:if>
          </input>
            HTML format
          </label>
          |
          <label>
            <select name="priority">
            <option value="3">
              <xsl:if test="message/priority = 3">
                <xsl:attribute name="selected">1</xsl:attribute>
              </xsl:if>Normal</option>
            <option value="5">
              <xsl:if test="message/priority = 5">
                <xsl:attribute name="selected">1</xsl:attribute>
              </xsl:if>Lowest</option>
            <option value="4">
              <xsl:if test="message/priority = 4">
                <xsl:attribute name="selected">1</xsl:attribute>
              </xsl:if>Low</option>
            <option value="2">
              <xsl:if test="message/priority = 2">
                <xsl:attribute name="selected">1</xsl:attribute>
              </xsl:if>High</option>
            <option value="1">
              <xsl:if test="message/priority = 1">
                <xsl:attribute name="selected">1</xsl:attribute>
              </xsl:if>Highest</option>
          </select>
            Priority
          </label>
          |
          <label>
          <input type="checkbox" name="scopy" value="1">
            <xsl:if test="//save_copy = 1">
              <xsl:attribute name="checked">checked</xsl:attribute>
            </xsl:if>
          </input>
            Save copy in "Sent" folder
          </label>
          <xsl:if test="//security_sign != ''">
            |
            <label>
              <input type="checkbox" name="ssign" id="ssign" value="1">
                <xsl:choose>
                  <xsl:when test="message/options/securitySign">
                    <xsl:if test="message/options/securitySign = 1">
                      <xsl:attribute name="checked">checked</xsl:attribute>
                    </xsl:if>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:if test="//security_sign_mode = 1">
                    <xsl:attribute name="checked">checked</xsl:attribute>
                    </xsl:if>
                  </xsl:otherwise>
                </xsl:choose>
              </input>
              Digitally sign
            </label>
          </xsl:if>
          <xsl:if test="//security_encrypt != ''">
            |
            <label>
              <input type="checkbox" name="sencrypt" id="sencrypt" value="1">
                <xsl:choose>
                  <xsl:when test="message/options/securityEncrypt">
                    <xsl:if test="message/options/securityEncrypt = 1">
                      <xsl:attribute name="checked">checked</xsl:attribute>
                    </xsl:if>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:if test="//security_encrypt_mode = 1">
                    <xsl:attribute name="checked">checked</xsl:attribute>
                    </xsl:if>
                  </xsl:otherwise>
                </xsl:choose>
              </input>
              Encrypt
            </label>
          </xsl:if>
        </td>
      </tr>
      <tr>
        <th>
          <label for="message">Message</label>
        </th>
        <td style="height: 290px;" valign="top">
          <input name="message" id="message" type="hidden">
            <xsl:attribute name="value">
              <xsl:if test="string-length (message/mbody) > 0">
                  <xsl:apply-templates select="message/mbody"/>
              </xsl:if>
                  <xsl:apply-templates select="signature"/>
            </xsl:attribute>
          </input>
          <div>
            <div id="plain" style="display: none;">
              <textarea id="plainMessage" name="plainMessage" style="width: 600px; height: 290px;" onselect="storeCaret(this);" onclick="storeCaret(this);" onkeyup="storeCaret(this);"></textarea>
            </div>
            <div id="rte" style="display: none;">
              <textarea id="rteMessage" name="rteMessage"></textarea>
              <script type="text/javascript" src="/ods/ckeditor/ckeditor.js"></script>
              <script language="JavaScript" type="text/javascript">
                var oEditor = CKEDITOR.replace('rteMessage');
              </script>
            </div>
          </div>
        </td>
      </tr>
      <xsl:if test="count(attachments/attachment) > 0 ">
        <tr>
          <th>Attached files</th>
          <td>
            <xsl:apply-templates select="attachments"/>
          </td>
        </tr>
      </xsl:if>
    </table>
    <script language="JavaScript" type="text/javascript">
      populateArrays();
      activateToggles();
      initTab(document.forms['f1'].elements['mt']);
    </script>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="message/mbody">
    <xsl:if test="../re_mode > 0">
      <xsl:text>

      </xsl:text>
----- Original Message -----
<xsl:if test="count(address/addres_list/from) != 0">
From: <xsl:apply-templates select="address/addres_list/from"/>
</xsl:if>
<xsl:if test="count(address/addres_list/to) != 0">
To: <xsl:apply-templates select="address/addres_list/to"/>
</xsl:if>
<xsl:if test="count(address/addres_list/cc) != 0">
CC: <xsl:apply-templates select="address/addres_list/cc"/>
</xsl:if>
Subject: <xsl:value-of select="subject"/>
Sent: <xsl:value-of select="rcv_date"/>
    </xsl:if>
    <xsl:text>
</xsl:text>
    <xsl:value-of select="mtext"/>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="signature">
    <xsl:text>
------------------------------------------------------
    </xsl:text>
    <xsl:value-of select="."/>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="message/address/addres_list/to | message/address/addres_list/cc | message/address/addres_list/bcc | message/address/addres_list/dcc">
    <xsl:value-of select="name"/>
    <xsl:text> </xsl:text>
    <xsl:value-of select="email"/>
    <xsl:if test="position() != last()">,</xsl:if>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="address/addres_list/from | address/addres_list/to | address/addres_list/cc ">
    <xsl:value-of select="name"/>
    <xsl:text> </xsl:text>
    <xsl:value-of select="email"/>
    <xsl:if test="position() != last()">,</xsl:if>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="attachment_old">
    <xsl:if test="type_id >= 20000">
      <xsl:if test="type_id &lt; 30000">
        <option>
          <xsl:attribute name="value"><xsl:value-of select="part_id"/></xsl:attribute>
          <xsl:value-of select="pname"/>
        </option>
      </xsl:if>
    </xsl:if>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="attachments">
    <a name="attachments"/>
    <table width="60%" cellpadding="0" cellspacing="0" border="0" class="content">
      <thead>
        <tr>
          <th>#</th>
          <th>Name</th>
          <th>Type</th>
          <th>Size</th>
          <th>Action</th>
        </tr>
      </thead>
      <tbody>
        <xsl:apply-templates select="attachment"/>
      </tbody>
      <tfoot>
        <tr>
          <td colspan="5">
            <xsl:call-template name="make_href">
              <xsl:with-param name="url">javascript: attachSubmit(); </xsl:with-param>
              <xsl:with-param name="label">
                <xsl:choose>
                  <xsl:when test="count(attachment) &lt; 5"> Attach new file(s)</xsl:when>
                  <xsl:otherwise> See complete file list ...</xsl:otherwise>
                </xsl:choose>
              </xsl:with-param>
              <xsl:with-param name="title">
                <xsl:choose>
                  <xsl:when test="count(attachment) &lt; 5"> Attach new file(s)</xsl:when>
                  <xsl:otherwise> See complete file list ...</xsl:otherwise>
                </xsl:choose>
              </xsl:with-param>
            </xsl:call-template>
          </td>
        </tr>
      </tfoot>
    </table>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="attachment">
    <xsl:if test="position() &lt; 5">
      <tr>
        <td align="center">
          <xsl:value-of select="position()"/>.
        </td>
        <td>
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">dload.vsp</xsl:with-param>
            <xsl:with-param name="target">_blank</xsl:with-param>
            <xsl:with-param name="label"><xsl:value-of select="pname"/></xsl:with-param>
            <xsl:with-param name="title">Attachment <xsl:value-of select="pname"/></xsl:with-param>
            <xsl:with-param name="params">dp=<xsl:value-of select="/page/msg_id"/>,<xsl:value-of select="part_id"/><xsl:value-of select="//message/eparams"/></xsl:with-param>
          </xsl:call-template>
        </td>
        <td>
          <xsl:value-of select="mime_type"/>
        </td>
        <td>
          <xsl:call-template name="size2str">
            <xsl:with-param name="size" select="dsize"/>
          </xsl:call-template>
        </td>
        <td nowrap="nowrap">
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">attach.vsp</xsl:with-param>
            <xsl:with-param name="params">ap=<xsl:value-of select="/page/msg_id"/>,1,<xsl:value-of select="part_id"/>&amp;back=write<xsl:value-of select="//message/eparams"/></xsl:with-param>
            <xsl:with-param name="label">Delete Attachment</xsl:with-param>
            <xsl:with-param name="img">/oMail/i/del_16.png</xsl:with-param>
            <xsl:with-param name="img_label"> Delete</xsl:with-param>
            <xsl:with-param name="class">button</xsl:with-param>
          </xsl:call-template>
        </td>
      </tr>
    </xsl:if>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="certificate">
    <input type="hidden">
      <xsl:attribute name="name">modulus_<xsl:value-of select="./mail"/></xsl:attribute>
      <xsl:attribute name="id">modulus_<xsl:value-of select="./mail"/></xsl:attribute>
      <xsl:attribute name="value"><xsl:value-of select="./modulus"/></xsl:attribute>
    </input>
    <input type="hidden">
      <xsl:attribute name="name">public_exponent_<xsl:value-of select="./mail"/></xsl:attribute>
      <xsl:attribute name="id">public_exponent_<xsl:value-of select="./mail"/></xsl:attribute>
      <xsl:attribute name="value"><xsl:value-of select="./public_exponent"/></xsl:attribute>
    </input>
  </xsl:template>
  <!-- ====================================================================================== -->
</xsl:stylesheet>
