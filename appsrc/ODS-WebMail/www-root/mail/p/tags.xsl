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
<xsl:stylesheet xmlns:xsl = "http://www.w3.org/1999/XSL/Transform" version = "1.0" >
<xsl:output method = "text" />

	<xsl:template match = "/">
		<xsl:apply-templates select="tag_list"/>
	</xsl:template>

	<!-- ====================================================================================== -->
	<xsl:template match = "tag_list"><![CDATA[<xsl:stylesheet xmlns:xsl = "http://www.w3.org/1999/XSL/Transform" version = "1.0" >]]>
		<xsl:apply-templates select="allow_tags"/>
		<xsl:apply-templates select="ban_tags"/>
<![CDATA[</xsl:stylesheet>]]>
	</xsl:template>

	<!-- ====================================================================================== -->
	<xsl:template match = "allow_tags">
		<xsl:apply-templates select="*" mode="tags"/>
	</xsl:template>

	<!-- ====================================================================================== -->
	<xsl:template match = "ban_tags">
		<xsl:apply-templates select="*" mode="btags"/>
	</xsl:template>

	<!-- ====================================================================================== -->
	<xsl:template match = "*" mode="tags">
	<![CDATA[<!-- ]]><xsl:value-of select = "{name()}" /><![CDATA[ ========================================================================== -->]]>
	<![CDATA[<xsl:template match = "]]><xsl:value-of select = "{name()}" /><![CDATA[">]]>
			<xsl:element name = "{name()}" >
				<xsl:apply-templates select="*" mode="atts"/>
				<![CDATA[<xsl:apply-templates/>]]>
			</xsl:element>
		<![CDATA[</xsl:template>]]>
	 </xsl:template>

	<!-- ====================================================================================== -->
	<xsl:template match = "*" mode="atts">
			<![CDATA[<xsl:if test="@]]><xsl:value-of select = "{name()}" /><![CDATA[ != ''">]]>
				<![CDATA[<xsl:attribute name="]]><xsl:value-of select = "{name()}" /><![CDATA[">]]>
						<xsl:choose>
						  <xsl:when test="@value != ''">
									<xsl:value-of select = "@value" />
						  </xsl:when>
						  <xsl:otherwise>
						    	<xsl:value-of select = "@avalue" /><![CDATA[<xsl:value-of select = "@]]><xsl:value-of select = "{name()}" /><![CDATA[" />]]>
						  </xsl:otherwise>
						</xsl:choose>
				<![CDATA[</xsl:attribute>]]>
			<![CDATA[</xsl:if>]]>
	 </xsl:template>

	<!-- ====================================================================================== -->
	<xsl:template match = "*" mode="btags">
	<![CDATA[<!-- ]]><xsl:value-of select = "{name()}" /><![CDATA[ ========================================================================== -->]]>
	<![CDATA[<xsl:template match = "]]><xsl:value-of select = "{name()}" /><![CDATA["/>]]>
	 </xsl:template>


</xsl:stylesheet> 
