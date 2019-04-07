<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2019 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:v="http://www.openlinksw.com/vspx/" exclude-result-prefixes="v" xmlns:vm="http://www.openlinksw.com/vspx/ods/"
  xmlns:wa="http://www.openlinksw.com/vspx/wa/">
    <xsl:output method="xml" omit-xml-declaration="yes" indent="no"  encoding="UTF-8" />

    <xsl:param name="class" />
    <xsl:param name="what" />

    <!-- we need a special case for conditions -->
    <xsl:template match="vm:page">
	<xsl:apply-templates />
    </xsl:template>

    <xsl:template match="vm:header">
	<xsl:if test="$what = local-name()">
	    <xsl:apply-templates />
	</xsl:if>
    </xsl:template>

    <xsl:template match="vm:condition">
	<xsl:if test="boolean (wa:condition (@test, $class))">
	    <xsl:apply-templates />
	</xsl:if>
    </xsl:template>

    <xsl:template match="vm:pagewrapper|vm:body">
	<xsl:if test="$what = local-name()">
	    <xsl:apply-templates />
	</xsl:if>
    </xsl:template>

    <xsl:template match="vm:*">
	<xsl:value-of select="wa:render (replace (local-name(.), '-', '_'), $class)" disable-output-escaping="yes"/>
    </xsl:template>

    <xsl:template match="v:*">
	<xsl:apply-templates />
    </xsl:template>

    <xsl:template match="*">
	<xsl:variable name="elm" select="local-name()"/>
	<xsl:variable name="single" select="boolean (*|text())"/>
	<xsl:value-of select="wa:render-static ($elm, '', 1, $single)" />
	    <xsl:for-each select="@*">
	       <xsl:value-of select="wa:render-static (local-name(), string(.), 2, 0)" />
	   </xsl:for-each>
	<xsl:if test="$single"><xsl:value-of select="wa:render-static ('&gt;', '', 3, 0)" /></xsl:if>
	    <xsl:apply-templates />
	<xsl:value-of select="wa:render-static ($elm, '', 0, $single)" />
    </xsl:template>

    <xsl:template match="text()">
	<xsl:value-of select="wa:render-static (., '', 3, 0)" />
    </xsl:template>

</xsl:stylesheet>
