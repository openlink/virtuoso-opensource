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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:vi="http://www.openlinksw.com/weblog/">
    <xsl:output method="xml" indent="yes" encoding="utf-8" omit-xml-declaration="yes" media-type="text/html"/>

    <xsl:param name="adblock" />
    <xsl:param name="media" select="number(0)"/>

    <xsl:template match="/">
	<xsl:apply-templates />
    </xsl:template>

    <xsl:template match="body|html">
	<xsl:apply-templates />
    </xsl:template>

    <xsl:template match="*[@src like $adblock//ad/@href ]" />

    <xsl:template match="map/*[@href like $adblock//ad/@href ]" />

    <xsl:template match="title">
	<div>
	    <xsl:apply-templates />
	</div>
    </xsl:template>

    <xsl:template match="script[@id[starts-with (., 'scp_')] and starts-with (., 'playEnclosure (')]">
	<xsl:if test="boolean($media)">
	    <xsl:copy>
		<xsl:copy-of select="@type|@id" />
		<xsl:apply-templates />
	    </xsl:copy>
	</xsl:if>
    </xsl:template>

    <xsl:template match="object[embed]">
	<xsl:apply-templates select="embed"/>
    </xsl:template>

    <xsl:template match="head|script|form|input|button|textarea|object|frame|frameset|select" />

    <xsl:template match="img[@id[starts-with (., 'media_')]]">
	<xsl:choose>
	    <xsl:when test="boolean($media)">
		<xsl:copy>
		    <xsl:copy-of select="@*[not starts-with (name(), 'on')]"/>
		    <xsl:copy-of select="@onclick"/>
		<xsl:apply-templates />
	    </xsl:copy>
	    </xsl:when>
	    <xsl:otherwise>
		<xsl:variable name="tmp">
		    <xsl:value-of select='substring-before(substring-after (@onclick, "playMedia"), ", ")'/>
		</xsl:variable>
		<xsl:variable name="src">
		    <xsl:value-of select='substring-before(substring-after ($tmp, "&apos;"), "&apos;")'/>
		</xsl:variable>
		<embed src="{$src}" autoplay="false" controller="true"></embed>
	    </xsl:otherwise>
	</xsl:choose>
    </xsl:template>

    <xsl:template match="*">
	<xsl:copy>
	    <xsl:if test="local-name() = 'img' and not (@alt)">
	      <xsl:attribute name="alt">Image</xsl:attribute>
	    </xsl:if>
	    <xsl:copy-of select="@*[not starts-with (name(), 'on')]"/>
	    <xsl:if test="boolean($media) and (local-name() = 'a' or local-name() = 'img')  and @id[starts-with (., 'media_')]">
		<xsl:copy-of select="@onclick"/>
	    </xsl:if>
	    <xsl:apply-templates />
	</xsl:copy>
    </xsl:template>

</xsl:stylesheet>
