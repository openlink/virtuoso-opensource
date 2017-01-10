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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:v="http://www.openlinksw.com/vspx/" exclude-result-prefixes="v" xmlns:vm="http://www.openlinksw.com/vspx/weblog/">
    <xsl:output method="xml" omit-xml-declaration="yes" indent="no"  encoding="UTF-8" />

    <xsl:param name="chk" select="false ()"/>
    <xsl:include href="main.xsl"/>

    <!--xsl:template match="vm:if[@test]">
	<xsl:apply-templates />
    </xsl:template-->

    <xsl:template match="v:label[not @render-only and not(*) and not (@enabled)]
			|v:url[not @render-only and not(*) and not(@enabled) and not(@active)]">
	<xsl:copy>
	    <xsl:copy-of select="@*[not starts-with (local-name(), 'debug-')]"/>
	    <xsl:attribute name="render-only">1</xsl:attribute>
	    <xsl:apply-templates />
	</xsl:copy>
    </xsl:template>

    <xsl:template match="v:template[@condition and @type='simple']">
	<xsl:processing-instruction name="vsp">if (<xsl:value-of select="@condition"/>) { </xsl:processing-instruction>
	    <xsl:apply-templates />
	<xsl:processing-instruction name="vsp"> } </xsl:processing-instruction>
    </xsl:template>

    <xsl:template match="processing-instruction ()">
	<xsl:copy-of select="." />
    </xsl:template>

    <xsl:template match="comment()" />

    <xsl:template match="v:*|*">
	<xsl:copy>
	    <xsl:copy-of select="@*[not starts-with (local-name(), 'debug-')]"/>
	    <xsl:apply-templates />
	</xsl:copy>
    </xsl:template>

</xsl:stylesheet>
