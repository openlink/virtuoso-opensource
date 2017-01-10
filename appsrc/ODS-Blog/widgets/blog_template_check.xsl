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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:v="http://www.openlinksw.com/vspx/" xmlns:vm="http://www.openlinksw.com/vspx/weblog/">
    <xsl:template match="v:page">
	<xsl:if test="@style and @style != '/DAV/VAD/blog2/widgets/main.xsl'">
	    <xsl:message terminate="yes">The template MUST not contain custom widgets set</xsl:message>
	</xsl:if>
	<xsl:if test="@decor">
	    <xsl:message terminate="yes">The template MUST not contain custom decoration</xsl:message>
	</xsl:if>
	<xsl:apply-templates />
    </xsl:template>
    <xsl:template match="v:error-summary[not(*)]" />
    <xsl:template match="processing-instruction ()">
	<xsl:message terminate="yes">The template MUST not contain vsp markup</xsl:message>
    </xsl:template>
    <xsl:template match="v:include">
	<xsl:variable name="doc" select="document (@url)"/>
	<xsl:apply-templates select="$doc/*"/>
	<xsl:apply-templates />
    </xsl:template>
    <xsl:template match="v:*">
	<xsl:message terminate="yes">The template MUST not contain vspx markup</xsl:message>
    </xsl:template>
</xsl:stylesheet>
