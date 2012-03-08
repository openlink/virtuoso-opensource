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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:v="http://www.openlinksw.com/vspx/" exclude-result-prefixes="v" xmlns:vm="http://www.openlinksw.com/vspx/ods/">
    <xsl:output method="text" omit-xml-declaration="yes" indent="no"  encoding="UTF-8" />

    <xsl:param name="chk" select="false ()"/>

    <xsl:template match="processing-instruction ()">
	<xsl:copy-of select="." />
    </xsl:template>

    <xsl:template match="comment()" />

    <xsl:template match="v:*">
	<xsl:copy>
	    <xsl:copy-of select="@*[not starts-with (local-name(), 'debug-')]"/>
	    <xsl:apply-templates />
	</xsl:copy>
    </xsl:template>

    <xsl:template match="*">
	<xsl:text>&lt;</xsl:text>
	<xsl:value-of select="local-name()"/>
	<xsl:for-each select="@*[not starts-with (local-name(), 'debug-')]">
	    <xsl:text> </xsl:text>
	    <xsl:value-of select="local-name()"/>
	    <xsl:text>="</xsl:text><xsl:value-of select="."/><xsl:text>"</xsl:text>
	</xsl:for-each>
	<xsl:choose>
	    <xsl:when test="not (* or text() or processing-instruction())">
		<xsl:text> /&gt;</xsl:text>
	    </xsl:when>
	    <xsl:otherwise>
		<xsl:text>&gt;</xsl:text>
		<xsl:apply-templates />
		<xsl:text>&lt;/</xsl:text><xsl:value-of select="local-name()"/><xsl:text>&gt;</xsl:text>
	    </xsl:otherwise>
	</xsl:choose>
    </xsl:template>

</xsl:stylesheet>

