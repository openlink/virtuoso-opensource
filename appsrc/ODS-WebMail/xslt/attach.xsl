<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2015 OpenLink Software
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
    <form method="post" enctype="multipart/form-data" name="f1">
      <xsl:attribute name="action"><xsl:value-of select="$iri" />/attach.vsp</xsl:attribute>
      <xsl:call-template name="hid_sid"/>
      <input type="hidden" name="ap">
        <xsl:attribute name="value"><xsl:value-of select="ap"/></xsl:attribute>
      </input>
      <br/>
      <xsl:call-template name="attach_form"/>
      <xsl:apply-templates select="attachments"/>
      <xsl:apply-templates select="eparams"/>
    </form>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="attach_form">
    <table width="60%" cellpadding="0" cellspacing="0" border="1" class="content">
      <caption>
        <a class="bc">
          <xsl:attribute name="href">write.vsp?sid=<xsl:value-of select="$sid"/>&amp;realm=<xsl:value-of select="$realm"/>&amp;wp=<xsl:value-of select="msg_id"/><xsl:value-of select="eparams"/></xsl:attribute>
          <xsl:attribute name="title">Back to message</xsl:attribute>
          <xsl:call-template name="nbsp"/>
          <img src="/oMail/i/back_16.png" border="0"/>
          <xsl:call-template name="nbsp"/> Back to message
        </a>
      </caption>
      <tr>
        <th>
          <label for="att_1">Insert attachment - File</label>
        </th>
        <td>
          <input type="radio" name="att_source" value="0" checked="checked"/>
          <xsl:call-template name="nbsp"/>
          <input type="file" name="att_1" size="40" onchange="javascript: f1.att_source[0].checked = true;" onfocus="f1.att_source[0].checked = true;"/>
        </td>
      </tr>
      <tr>
        <th>
          <label for="att_2">- URI</label>
        </th>
        <td>
          <input type="radio" name="att_source" value="1"/>
          <xsl:call-template name="nbsp"/>
          <input type="text" name="att_2" id="att_2" size="40" onfocus="f1.att_source[1].checked = true;"/>
          <input type="button" name="att_2_button" value="Browse...">
            <xsl:attribute name="onclick">javascript: f1.att_source[1].checked = true; davBrowse ('att_2'); </xsl:attribute>
          </input>
  		    <script type="text/javascript">
            OAT.Loader.load(['dav'], function(){OAT.WebDav.init(davOptions);});
  		    </script>
        </td>
      </tr>
      <tfoot>
        <tr>
          <th colspan="2">
            <xsl:call-template name="make_submit">
              <xsl:with-param name="name">fa</xsl:with-param>
              <xsl:with-param name="value">Upload</xsl:with-param>
              <xsl:with-param name="alt">Upload</xsl:with-param>
            </xsl:call-template>
          </th>
        </tr>
      </tfoot>
    </table>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="attachments">
    <table width="60%" cellpadding="0" cellspacing="0" border="0" id="a" class="content">
      <thead>
        <tr>
          <th align="center">#</th>
          <th>Name</th>
          <th>Type</th>
          <th>Size</th>
          <th>Action</th>
        </tr>
      </thead>
      <tbody>
        <xsl:apply-templates select="attachment"/>
      </tbody>
    </table>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="attachment">
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
          <xsl:with-param name="params">dp=<xsl:value-of select="/page/msg_id"/>,<xsl:value-of select="part_id"/></xsl:with-param>
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
      <td align="center">
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">attach.vsp</xsl:with-param>
          <xsl:with-param name="params">ap=<xsl:value-of select="/page/msg_id"/>,1,<xsl:value-of select="part_id"/><xsl:value-of select="../../eparams"/></xsl:with-param>
          <xsl:with-param name="label">Delete Attachment</xsl:with-param>
          <xsl:with-param name="img">/oMail/i/del_16.png</xsl:with-param>
          <xsl:with-param name="img_label"> Delete</xsl:with-param>
          <xsl:with-param name="class">button</xsl:with-param>
        </xsl:call-template>
      </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
</xsl:stylesheet>
