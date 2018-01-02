<?xml version="1.0" encoding="utf-8"?>
<!--
--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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
<xsl:stylesheet version ="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="html"/>
<xsl:template match = "result">

<a href="/fct/facet.vsp?cmd=refresh&sid={$sid}">Return to facets</a>
<br/>
<table>
	<xsl:for-each select="row">
<tr>
<td><xsl:value-of select="column[1]"/></td>
<td><xsl:value-of select="column[2]"/></td>
<td>
<xsl:choose>
<xsl:when test="'url' = column[3]/@datatype">
<a><xsl:attribute name="href">/fct/facet.vsp?cmd=open&amp;iri=<xsl:value-of select="urlify (column[3])"/>&amp;sid=<xsl:value-of select="$sid"/></xsl:attribute><xsl:value-of select="column[3]"/></a>
</xsl:when>
<xsl:otherwise><xsl:value-of select="column[3]"/></xsl:otherwise>
</xsl:choose>
</td>
</tr>
<xsl:text>
</xsl:text>
</xsl:for-each>
</table>
</xsl:template>
</xsl:stylesheet>
