<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2015 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" >
<xsl:output method="text" indent="no" />
<xsl:param name="files"/>
<xsl:variable name="pad" select="'              '"/>
<xsl:variable name="lpad" select="'                        '"/>
<xsl:template match="/">
    <xsl:text/> Flat profile (by self):<xsl:text>&#10;</xsl:text>
    <xsl:text/>    self                calls  name (average)<xsl:text>&#10;</xsl:text>
    <xsl:text/>    -----------------------------------------<xsl:text>&#10;</xsl:text>
<xsl:for-each select="pl_stats/proc|pl_stats/method">
<xsl:sort select="format-number(number (@self), '000000000000.')" order="descending"/>
<xsl:variable name="tim" select="format-number(number (@self), '.')" />
<xsl:variable name="avg" select="format-number(number (@self) div number (@calls), '.0000')" />
<xsl:variable name="pcalls" select="number(@calls)" />
<xsl:value-of select="substring ($pad, 1, 14 - string-length ($tim))"/>
<xsl:value-of select="$tim"/>
<xsl:value-of select="substring ($pad, 1, 14 - string-length ($pcalls))"/>
<xsl:value-of select="$pcalls"/> : <xsl:value-of select="@name"/> <xsl:call-template name="cls_name"/> : (<xsl:value-of select="$avg"/> msec)<xsl:text/><xsl:text>&#10;</xsl:text>
</xsl:for-each>
    <xsl:text>&#10;</xsl:text>
    <xsl:text>&#10;</xsl:text>
    <xsl:text/> Flat profile (by cumulative):<xsl:text>&#10;</xsl:text>
    <xsl:text/>    cumulative          calls  name (average)<xsl:text>&#10;</xsl:text>
    <xsl:text/>    -----------------------------------------<xsl:text>&#10;</xsl:text>
<xsl:for-each select="pl_stats/proc|pl_stats/method">
<xsl:sort select="format-number(number (@time), '000000000000.')" order="descending"/>
<xsl:variable name="tim" select="format-number(number (@time), '.')" />
<xsl:variable name="avg" select="format-number(number (@time) div number (@calls), '.0000')" />
<xsl:variable name="pcalls" select="number(@calls)" />
<xsl:value-of select="substring ($pad, 1, 14 - string-length ($tim))"/>
<xsl:value-of select="$tim"/>
<xsl:value-of select="substring ($pad, 1, 14 - string-length ($pcalls))"/>
<xsl:value-of select="$pcalls"/> : <xsl:value-of select="@name"/> <xsl:call-template name="cls_name"/> : (<xsl:value-of select="$avg"/> msec)<xsl:text/><xsl:text>&#10;</xsl:text>
</xsl:for-each>

Coverage:
<xsl:variable name="src" select="."/>
file                             lines         total      coverage (%)
----------------------------------------------------------------------
<xsl:for-each select="$files/files/file" >
    <xsl:variable name="file" select="@name"/>
    <xsl:variable name="lines" select="count ($src/pl_stats/*[@file = $file]/line[number(@ctr) > 0])"/>
    <xsl:variable name="total" select="sum ($src/pl_stats/*[@file = $file]/@lct)"/>
    <xsl:variable name="pct" select="format-number((100 * $lines div $total), '.0000')"/>
    <xsl:text/><xsl:value-of select="$file"/>
    <xsl:value-of select="substring ($lpad, 1, 24 - string-length ($file))"/>
    <xsl:text/>
    <xsl:value-of select="substring ($pad, 1, 14 - string-length ($lines))"/>
    <xsl:value-of select="$lines"/>
    <xsl:text/>
    <xsl:value-of select="substring ($pad, 1, 14 - string-length ($lines))"/>
    <xsl:value-of  select="$total" />
    <xsl:text/>
    <xsl:value-of select="substring ($pad, 1, 14 - string-length ($pct))"/>
    <xsl:value-of select="$pct" /><xsl:text>&#10;</xsl:text>
</xsl:for-each>
----------------------------------------------------------------------
</xsl:template>
<xsl:template name="cls_name">
    <xsl:if test="@class">
	<xsl:text> of </xsl:text> <xsl:value-of select="@class"/><xsl:text> </xsl:text>
    </xsl:if>
</xsl:template>
<xsl:template match="*|@*|text()"/>
</xsl:stylesheet>
