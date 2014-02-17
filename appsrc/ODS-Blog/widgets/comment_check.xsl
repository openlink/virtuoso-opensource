<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2014 OpenLink Software
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
    <xsl:output method="xml" indent="yes" encoding="utf-8" omit-xml-declaration="yes" media-type="text/html"/>

    <xsl:param name="adblock" />

    <xsl:template match="/">
	<xsl:apply-templates />
    </xsl:template>

    <xsl:template match="body|html">
	<xsl:message terminate="yes">Invalid markup</xsl:message>
    </xsl:template>

    <xsl:template match="*[@src like $adblock//ad/@href ]">
	<xsl:message terminate="yes">Invalid markup</xsl:message>
    </xsl:template>

    <xsl:template match="map/*[@href like $adblock//ad/@href ]">
	<xsl:message terminate="yes">Invalid markup</xsl:message>
    </xsl:template>

    <xsl:template match="title">
	<xsl:message terminate="yes">Invalid markup</xsl:message>
    </xsl:template>

    <xsl:template match="head|script|form|input|button|textarea|object|frame|frameset|select|style|*[@style]">
	<xsl:message terminate="yes">Invalid markup</xsl:message>
    </xsl:template>

    <xsl:template match="*">
	<xsl:copy>
	    <xsl:copy-of select="@*[not starts-with (name(), 'on')]" />
	    <xsl:apply-templates />
	</xsl:copy>
    </xsl:template>

</xsl:stylesheet>
