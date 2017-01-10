<?xml version="1.0" encoding="utf-8"?>
<!--
--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2017 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--
-->
<xsl:stylesheet version ="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:fct="http://openlinksw.com/services/facets/1.0/">
    <xsl:output method="xml" indent="yes" encoding="UTF-8" cdata-section-elements="fct:column"/>

    <xsl:template match="*">
	<xsl:element name="{local-name ()}" namespace="http://openlinksw.com/services/facets/1.0/">
	    <xsl:copy-of select="@*"/>
	    <xsl:apply-templates/>
	</xsl:element>
    </xsl:template>

    <xsl:template match="column">
	<xsl:element name="{local-name ()}" namespace="http://openlinksw.com/services/facets/1.0/">
	    <xsl:copy-of select="@*"/>
	    <xsl:apply-templates mode="raw"/>
	</xsl:element>
    </xsl:template>

    <xsl:template match="*" mode="raw">
	<xsl:value-of select="serialize (.)"/>
    </xsl:template>

    <xsl:template match="text()" mode="raw">
	<xsl:value-of select="serialize (.)"/>
    </xsl:template>

</xsl:stylesheet>
