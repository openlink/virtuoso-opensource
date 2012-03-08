<?xml version='1.0'?>
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
 -  
-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="html" indent="yes"/>
    <xsl:template match="/">
	<xsl:apply-templates select="*"/>
	<xsl:if test="//administrative_divisions/noentries">
	    <H3>No entries found for <xsl:value-of select="@mask" /></H3>
	</xsl:if>
    </xsl:template>
    <xsl:template match="administrative_divisions">
	<xsl:apply-templates select="country" />
    </xsl:template>
    <xsl:template match="country">
	<H3>Administrative divisions of <xsl:value-of select="name" /></H3>
	<table class="tableresult">
	    <xsl:apply-templates select="*"/>
	</table>
    </xsl:template>
    <xsl:template match="province">
	<tr><td><xsl:value-of select="name"/></td></tr>
    </xsl:template>
    <xsl:template match="*">
	<xsl:apply-templates select="*"/>
    </xsl:template>
</xsl:stylesheet>
