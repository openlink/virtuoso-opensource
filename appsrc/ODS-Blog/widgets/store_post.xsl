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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
     xmlns:vi="http://www.openlinksw.com/weblog/">
    <xsl:output method="xml" indent="yes" encoding="utf-8" omit-xml-declaration="yes" />

    <xsl:template match="/">
	<xsl:choose>
	    <xsl:when test="//tr[not ancestor::table]|//td[not ancestor::table]">
		<table>
		    <xsl:apply-templates />
		</table>
	    </xsl:when>
	    <xsl:otherwise>
		<xsl:apply-templates />
	    </xsl:otherwise>
	</xsl:choose>
    </xsl:template>

    <xsl:template match="body|html|head">
	<xsl:apply-templates />
    </xsl:template>

    <xsl:template match="title">
	<div>
	    <xsl:apply-templates />
	</div>
    </xsl:template>

    <!-- special tag to stop automatic hyperlinking -->
    <xsl:template match="no-auto-href">
	<xsl:apply-templates />
    </xsl:template>

    <xsl:template match="a[@rel='tag' and @style='display:none;']"/>

    <xsl:template match="*">
	<xsl:copy>
	    <xsl:apply-templates select="@*" mode="attr"/>
	    <xsl:if test="local-name () = 'a' and not @id">
		<xsl:attribute name="id">link-<xsl:value-of select="generate-id ()"/></xsl:attribute>
	    </xsl:if>
	    <xsl:apply-templates />
	</xsl:copy>
    </xsl:template>

    <xsl:template match="@*" mode="attr">
	<xsl:attribute name="{local-name ()}">
	    <xsl:choose>
		<xsl:when test="local-name () = 'href' or local-name() = 'src' or local-name() = 'background'">
		    <xsl:value-of select="vi:getExpandUrl(.)" />
		</xsl:when>
		<xsl:otherwise>
		    <xsl:value-of select="." />
		</xsl:otherwise>
	    </xsl:choose>
	</xsl:attribute>
    </xsl:template>

</xsl:stylesheet>
