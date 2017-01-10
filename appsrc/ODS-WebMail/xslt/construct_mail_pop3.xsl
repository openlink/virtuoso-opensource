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
  <xsl:output method="text"/>
  <!-- ====================================================================================== -->
  <xsl:template match="message">
    <xsl:value-of select="mheader"/>
    <xsl:call-template name="mime_msg"/>
    <xsl:apply-templates select="alternative"/>
    <xsl:apply-templates select="mbody"/>
    <xsl:apply-templates select="attachments/attachment"/>
    <xsl:apply-templates select="attachments_msg"/>
    <xsl:apply-templates select="boundary" mode="end"/>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="alternative">
    <xsl:variable name="count_att_all" select="count(../attachments)"/>
    <xsl:variable name="count_att_msg" select="count(../attachments_msg)"/>
    <xsl:variable name="count_att" select="$count_att_all + $count_att_msg"/>
    <xsl:choose>
      <xsl:when test="$count_att > 0">
--<xsl:value-of select="../boundary"/>
Content-Type: multipart/alternative;
	boundary="<xsl:value-of select="boundary2"/>"<xsl:text>
</xsl:text>
        <xsl:apply-templates select="mbody"/>
--<xsl:value-of select="boundary2"/>--
</xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="mbody"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- ===================================================================== -->
  <xsl:template name="count_att">

</xsl:template>
  <!-- ===================================================================== -->
  <xsl:template match="mbody">
    <xsl:variable name="count_msg" select="count(../mbody)"/>
    <xsl:variable name="count_att_all_1" select="count(../attachments)"/>
    <xsl:variable name="count_att_all_2" select="count(../../attachments)"/>
    <xsl:variable name="count_att_msg_1" select="count(../attachments_msg)"/>
    <xsl:variable name="count_att_msg_2" select="count(../../attachments_msg)"/>
    <xsl:variable name="count_att" select="$count_att_all_1 + $count_att_all_2 + $count_att_msg_1 + $count_att_msg_2"/>
    <xsl:choose>
      <xsl:when test="$count_msg = 1">
        <!-- samo edno body -->
        <xsl:if test="$count_att > 0">
          <!-- ima attach -->
--<xsl:value-of select="../boundary"/>
          <!-- znachi slagame boundary-1 -->
        </xsl:if>
      </xsl:when>
      <xsl:when test="$count_msg > 1">
        <!-- poveche ot edno body -->
        <xsl:choose>
          <xsl:when test="$count_att > 0">
            <!-- ima attach -->
--<xsl:value-of select="../boundary2"/>
            <!-- znachi slagame boundary-2 -->
          </xsl:when>
          <xsl:otherwise>
            <!-- niama attach -->
2--<xsl:value-of select="../../boundary"/>
            <!-- znachi slagame boundary-1 -->
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
    </xsl:choose>
    <xsl:call-template name="content-type"/>
    <xsl:call-template name="charset"/>
    <xsl:call-template name="content-transfer-encoding"/>
    <xsl:text>

</xsl:text>
    <xsl:value-of select="mtext"/>
    <xsl:text>
</xsl:text>
  </xsl:template>
  <!-- ===================================================================== -->
  <xsl:template name="mime_msg">
    <xsl:variable name="count_msg" select="count(alternative)"/>
    <xsl:variable name="count_msg" select="$count_msg + 1"/>
    <xsl:variable name="count_att_all" select="count(attachments)"/>
    <xsl:variable name="count_att_msg" select="count(attachments_msg)"/>
    <xsl:variable name="count_att" select="$count_att_all + $count_att_msg"/>
    <xsl:if test="($count_msg + $count_att) > 1">
      <xsl:text>

</xsl:text>This is a multi-part message in MIME format<xsl:text>
</xsl:text>
    </xsl:if>
  </xsl:template>
  <!-- ===================================================================== -->
  <xsl:template name="content-type">
    <xsl:variable name="count_msg" select="count(../mbody)"/>
    <xsl:variable name="count_att_all" select="count(../attachments)"/>
    <xsl:variable name="count_att_msg" select="count(../attachments_msg)"/>
    <xsl:variable name="count_att" select="$count_att_all + $count_att_msg"/>
    <xsl:if test="aparams/content-type != ''">
      <xsl:if test="($count_msg + $count_att) > 1">
Content-Type: <xsl:value-of select="aparams/content-type"/>;</xsl:if>
    </xsl:if>
  </xsl:template>
  <!-- ===================================================================== -->
  <xsl:template name="charset">
    <xsl:if test="aparams/charset != ''">
	charset="<xsl:value-of select="aparams/charset"/>"</xsl:if>
  </xsl:template>
  <!-- ===================================================================== -->
  <xsl:template name="content-transfer-encoding">
    <xsl:if test="aparams/charset != ''">
Content-Transfer-Encoding: <xsl:value-of select="aparams/content-transfer-encoding"/>
    </xsl:if>
  </xsl:template>
  <!-- ===================================================================== -->
  <xsl:template match="boundary" mode="end">
--<xsl:value-of select="."/>--
</xsl:template>
  <!-- ATT ===================================================================== -->
  <xsl:template match="attachments/attachment">
--<xsl:value-of select="../../boundary"/>
Content-Type: <xsl:value-of select="mime_type"/>;
	name="<xsl:value-of select="pname"/>"
Content-Transfer-Encoding: <xsl:choose>
      <xsl:when test="type_id > 199">base64</xsl:when>
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
    <xsl:text>
</xsl:text>
  </xsl:template>
  <!-- ATT_MSG ===================================================================== -->
  <xsl:template match="attachments_msg/attachment_msg">
--<xsl:value-of select="../../boundary"/>
Content-Type: message/rfc822;
	name="<xsl:value-of select="file_name"/>"
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment;
	filename="<xsl:value-of select="file_name"/>"<xsl:text>

</xsl:text>
    <xsl:apply-templates select="message"/>
  </xsl:template>
</xsl:stylesheet>
