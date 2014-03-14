<?xml version="1.0" ?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/" version="1.0" >
    <xsl:output method="text"/>
    <xsl:template match="/">
	<xsl:text>{</xsl:text><xsl:apply-templates select="*"/><xsl:text>}</xsl:text>
    </xsl:template>
    <xsl:template match="*[not (*) and text()]">"<xsl:value-of select="local-name(.)"/>":"<xsl:value-of select="vi:json-esc-text (text())"/><xsl:text>"</xsl:text>
	<xsl:if test="following-sibling::*"><xsl:text>, </xsl:text></xsl:if>
    </xsl:template>
    <xsl:template match="*[count(../*[name(../*) = name(.)]) = count(../*) and count(../*) &gt; 1]">
	<xsl:if test="not(preceding-sibling::*)"><xsl:text>"</xsl:text><xsl:value-of select="local-name(.)"/><xsl:text>":[</xsl:text></xsl:if>
	<xsl:choose>
	    <xsl:when test="*">
		<xsl:text>{</xsl:text><xsl:apply-templates select="*"/><xsl:text>}</xsl:text>
	    </xsl:when>
	    <xsl:when test="not (*) and @*[.!='']">
		<xsl:text>{</xsl:text>
		<xsl:for-each select="@*[.!='']">"-<xsl:value-of select="local-name(.)"/>":"<xsl:value-of select="vi:json-esc-text (.)"/><xsl:text>"</xsl:text>
		    <xsl:if test="position() != last()"><xsl:text>, </xsl:text></xsl:if>    
		</xsl:for-each>
		<xsl:if test="text()"><xsl:text>, </xsl:text>
		    <xsl:text>"#text":"</xsl:text><xsl:value-of select="vi:json-esc-text (./text())"/><xsl:text>"</xsl:text>
		</xsl:if>
		<xsl:text>}</xsl:text>
	    </xsl:when>
	    <xsl:otherwise>
		<xsl:text>"</xsl:text><xsl:value-of select="vi:json-esc-text (./text())"/><xsl:text>"</xsl:text>
	    </xsl:otherwise>
	</xsl:choose>
	<xsl:if test="following-sibling::*"><xsl:text>, </xsl:text></xsl:if>
	<xsl:if test="not(following-sibling::*)"><xsl:text>]</xsl:text></xsl:if>
    </xsl:template>
    <xsl:template match="*">
	<xsl:text>"</xsl:text><xsl:value-of select="local-name(.)"/><xsl:text>":{</xsl:text>
	<xsl:for-each select="@*[.!='']">"-<xsl:value-of select="local-name(.)"/>":"<xsl:value-of select="vi:json-esc-text (.)"/><xsl:text>"</xsl:text>
	    <xsl:if test="position() != last()"><xsl:text>, </xsl:text></xsl:if>    
	</xsl:for-each>
	<xsl:if test="* and @*[.!='']"><xsl:text>, </xsl:text></xsl:if>
	<xsl:apply-templates select="*"/>
	<xsl:text>}</xsl:text>
	<xsl:if test="following-sibling::*"><xsl:text>, </xsl:text></xsl:if>
    </xsl:template>
</xsl:stylesheet>
