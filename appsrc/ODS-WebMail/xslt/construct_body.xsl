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
  <xsl:output method="text"/>
  <xsl:variable name="content_transfer_encoding">8bit</xsl:variable>
  <xsl:variable name="charset_def">windows-1251</xsl:variable>
  <xsl:variable name="charset">
    <xsl:choose>
      <xsl:when test="/message/charset != ''">
        <xsl:value-of select="/message/charset"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$charset_def"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <!-- ====================================================================================== -->
  <xsl:template match="message">Content-Type: <xsl:call-template name="content_type"/>;
<xsl:call-template name="content_transfer_encoding"/>;

<xsl:call-template name="mbody"/>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="content_type">
    <xsl:choose>
      <xsl:when test="count(attachments) > 0">multipart/mixed</xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="mime_type"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- BODY ===================================================================== -->
  <xsl:template name="mbody">
    <xsl:choose>
      <xsl:when test="count(attachments) > 0">
        <xsl:call-template name="multipart"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="mbody/mtext"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- BODY ===================================================================== -->
  <xsl:template name="multipart">
 This is a multi-part message in MIME format.

--<xsl:value-of select="boundary"/>
Content-Type: <xsl:call-template name="mime_type"/>;
	charset="<xsl:value-of select="$charset"/>"
Content-Transfer-Encoding: <xsl:value-of select="$content_transfer_encoding"/>
    <xsl:text>

</xsl:text>
    <xsl:value-of select="mbody/mtext"/>

--<xsl:value-of select="boundary"/>
    <xsl:apply-templates select="attachments/attachment"/>--
</xsl:template>
  <!-- ATT ===================================================================== -->
  <xsl:template match="attachments/attachment">
Content-Type: <xsl:value-of select="mime_type"/>;
	name="<xsl:value-of select="pname"/>"
Content-Transfer-Encoding: <xsl:choose>
      <xsl:when test="type_id > 19999">base64</xsl:when>
      <xsl:otherwise>8 bit</xsl:otherwise>
    </xsl:choose>
Content-Disposition: attachment;
<xsl:choose>
      <xsl:when test="string-length(content_id) > 0">Content-ID: &lt;<xsl:value-of select="content_id"/>&gt;</xsl:when>
      <xsl:otherwise>	filename="<xsl:value-of select="pname"/>"</xsl:otherwise>
    </xsl:choose>
    <xsl:text>

</xsl:text>
    <xsl:value-of select="bdata"/>

--<xsl:value-of select="//boundary"/>
  </xsl:template>
  <!-- MIME-TYPE ============================================================== -->
  <xsl:template name="mime_type">
    <xsl:choose>
      <xsl:when test="type_id = 10110">text/html</xsl:when>
      <xsl:when test="type_id = 10100">text/plain</xsl:when>
      <xsl:when test="mime_type = 'html'">text/html</xsl:when>
      <xsl:when test="mime_type = 'text'">text/plain</xsl:when>
      <xsl:when test="mime_type = 'txt'">text/plain</xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="mime_type"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- CONTENT_TRANSFER_ENCODING ============================================================== -->
  <xsl:template name="content_transfer_encoding">
    <xsl:choose>
      <xsl:when test="count(attachments) = 0">	charset="<xsl:value-of select="$charset"/>"
Content-Transfer-Encoding: <xsl:value-of select="$content_transfer_encoding"/>
      </xsl:when>
      <xsl:otherwise>	boundary="<xsl:value-of select="boundary"/>"</xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- Ref ID ============================================================== -->
  <xsl:template match="ref_id">
    <xsl:if test="string-length(.) > 0">
References: &lt;<xsl:value-of select="."/>&gt;</xsl:if>
  </xsl:template>
</xsl:stylesheet>
