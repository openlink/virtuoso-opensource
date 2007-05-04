<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2007 OpenLink Software
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
    <form name="f1" action="mails.vsp" method="post">
      <xsl:call-template name="hid_sid"/>
      <input type="hidden" name="set">
        <xsl:attribute name="value"><xsl:value-of select="set"/></xsl:attribute>
      </input>
      <table width="100%" border="0" cellpadding="0" cellspacing="0" class="content">
        <thead>
          <tr>
            <th style="text-align: center; padding: 0;" width="1%">
              <input type="checkbox" name="cb_all" value="Select All" onclick="selectAllCheckboxes(this, 'cb_item'); "/>
            </th>
            <th>
              Name
            </th>
            <th>
              Mail
            </th>
          </tr>
        </thead>
        <tbody>
          <xsl:apply-templates select="mails" />
        </tbody>
      </table>
      <div style="padding: 0 0 0.5em 0;">
        <hr />
        <a href="#" onclick="javascript: addChecked(document.forms['f1'], 'cb_item', 'No contacts were selected for addition.');" class="button2">Add selected</a>
      </div>
    </form>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="mails">
    <xsl:for-each select="mail">
      <tr>
        <td align="center">
          <input type="checkbox" name="cb_item">
            <xsl:attribute name="value"><xsl:value-of select="email"/></xsl:attribute>
          </input>
        </td>
        <td>
          <xsl:value-of select="name"/>
        </td>
        <td>
          <xsl:value-of select="email"/>
        </td>
      </tr>
    </xsl:for-each>
  </xsl:template>
  <!-- ====================================================================================== -->
</xsl:stylesheet>
