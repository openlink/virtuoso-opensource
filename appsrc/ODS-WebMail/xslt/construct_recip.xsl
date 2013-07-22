<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2013 OpenLink Software
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
  <xsl:output method="html"/>
  <!-- ====================================================================================== -->
  <xsl:template match="/fr">
    <xsl:apply-templates select="address/addres_list/from"/>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="/to">
    <xsl:apply-templates select="address/addres_list/to"/>
    <xsl:if test="address/addres_list/cc != ''">,<xsl:apply-templates select="address/addres_list/cc"/>
    </xsl:if>
    <xsl:if test="address/addres_list/bcc != ''">,<xsl:apply-templates select="address/addres_list/bcc"/>
    </xsl:if>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="address/addres_list/from | address/addres_list/to | address/addres_list/cc | address/addres_list/bcc">
    <xsl:call-template name="v_name"/>
    <xsl:text> </xsl:text>
    <xsl:call-template name="v_email"/>
    <xsl:if test="position() != last()">, </xsl:if>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="v_name">
    <xsl:if test="name != ''">"<xsl:value-of select="name"/>"</xsl:if>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="v_email">
    <xsl:if test="email != ''">&lt;<xsl:value-of select="email"/>&gt;</xsl:if>
  </xsl:template>
  <!-- ====================================================================================== -->
</xsl:stylesheet>
