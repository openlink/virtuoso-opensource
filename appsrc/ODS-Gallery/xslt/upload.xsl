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
<xsl:stylesheet xmlns:v="http://www.openlinksw.com/vspx/" xmlns:vm="http://www.openlinksw.com/vspx/weblog/" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:msxsl="urn:schemas-microsoft-com:xslt" xmlns:fmt="urn:p2plusfmt-xsltformats" xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" xmlns:s="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/" xmlns:soap12="http://schemas.xmlsoap.org/wsdl/soap12/" version="1.0">
  <xsl:output method="html"/>
<!-- ======================================================================= -->
  <xsl:template match="vm:body">

  </xsl:template>

<!-- ======================================================================= -->
  <xsl:template match="vm:file_upload">
    <xsl:call-template name="file_upload">
      <xsl:with-param name="files">20</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

<!-- ======================================================================= -->
  <xsl:template name="file_upload">
    <xsl:param name="key">1</xsl:param>
    <xsl:param name="files"/>
    <tr>
      <td><xsl:value-of select="$key"/></td>
      <td align="right">
        <input type="file" style="width:310px">
          <xsl:attribute name="OnChange">image_check_exist(this.value,<xsl:value-of select="$key"/>)</xsl:attribute>
          <xsl:attribute name="name">my_image_<xsl:value-of select="$key"/></xsl:attribute>
        </input>
        <input type="hidden" value="">
          <xsl:attribute name="name">replace_image_<xsl:value-of select="$key"/></xsl:attribute>
        </input>
      </td>
      <td>
        <input type="text" name="description">
          <xsl:attribute name="name">description_<xsl:value-of select="$key"/></xsl:attribute>
        </input>
      </td>
    </tr>
    <xsl:if test="$key &lt; $files">
      <xsl:call-template name="file_upload">
        <xsl:with-param name="key"><xsl:value-of select="$key + 1"/></xsl:with-param>
        <xsl:with-param name="files"><xsl:value-of select="$files"/></xsl:with-param>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>
</xsl:stylesheet>
