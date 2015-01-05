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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:v="http://www.openlinksw.com/vspx/" exclude-result-prefixes="v" xmlns:vm="http://www.openlinksw.com/vspx/weblog/">
    <xsl:output method="xml" omit-xml-declaration="yes" indent="no"  encoding="UTF-8" />

    <xsl:param name="class" />
    <xsl:param name="what" />
    <xsl:param name="ctr" />
    <xsl:param name="post" />
    <xsl:param name="comm" />
    <xsl:param name="tb" />

    <xsl:template match="vm:page">
	<xsl:apply-templates />
    </xsl:template>

    <xsl:template match="vm:header">
	<xsl:if test="$what = local-name()">
	    <xsl:apply-templates />
	</xsl:if>
    </xsl:template>

    <xsl:template match="vm:body">
	<xsl:if test="$what = local-name()">
	    <xsl:apply-templates />
	</xsl:if>
    </xsl:template>

    <!-- compatibility templates -->
    <!-- only if required
    <xsl:include href="compat.xsl"/>

    <xsl:template match="vm:comments-view">
	<xsl:variable name="doc"><stub><xsl:call-template name="comments-view"/></stub></xsl:variable>
	<xsl:call-template name="apply-inner"><xsl:with-param name="doc" select="$doc"/></xsl:call-template>
    </xsl:template>

    <xsl:template match="vm:trackbacks">
	<xsl:variable name="doc"><stub><xsl:call-template name="trackbacks"/></stub></xsl:variable>
	<xsl:call-template name="apply-inner"><xsl:with-param name="doc" select="$doc"/></xsl:call-template>
    </xsl:template>

    <xsl:template match="vm:referrals">
	<xsl:variable name="doc"><stub><xsl:call-template name="referrals"/></stub></xsl:variable>
	<xsl:call-template name="apply-inner"><xsl:with-param name="doc" select="$doc"/></xsl:call-template>
    </xsl:template>

    <xsl:template match="vm:related">
	<xsl:variable name="doc"><stub><xsl:call-template name="related"/></stub></xsl:variable>
	<xsl:call-template name="apply-inner"><xsl:with-param name="doc" select="$doc"/></xsl:call-template>
    </xsl:template>

    <xsl:template match="vm:comments">
	<xsl:variable name="doc"><stub><xsl:call-template name="comments"/></stub></xsl:variable>
	<xsl:call-template name="apply-inner"><xsl:with-param name="doc" select="$doc"/></xsl:call-template>
    </xsl:template>

    <xsl:template match="vm:posts[not (*) and $what = local-name()]">
	<xsl:variable name="doc"><stub><xsl:call-template name="posts-default" /></stub></xsl:variable>
	<xsl:call-template name="apply-inner"><xsl:with-param name="doc" select="$doc"/></xsl:call-template>
    </xsl:template>

    <xsl:template name="apply-inner">
	<xsl:apply-templates select="$doc/stub/*">
	    <xsl:with-param name="class" select="$class"/>
	    <xsl:with-param name="what"  select="$what"/>
	    <xsl:with-param name="ctr"   select="$ctr"/>
	    <xsl:with-param name="post"  select="$post"/>
	    <xsl:with-param name="comm"  select="$comm"/>
	    <xsl:with-param name="tb"    select="$tb"/>
	</xsl:apply-templates>
    </xsl:template>
    -->
    <!-- eof compatibility -->

    <xsl:template match="vm:if">
	<!--xsl:message terminate="no">condition: test=[<xsl:value-of select="@test"/>]</xsl:message-->
	<xsl:if test="boolean (vm:condition (@test, $class, $ctr))">
	    <!--xsl:message terminate="no">condition: test=[<xsl:value-of select="@test"/>] passed</xsl:message-->
	    <xsl:apply-templates />
	</xsl:if>
    </xsl:template>

    <xsl:template match="vm:*">
	<xsl:choose>
	    <xsl:when test="$what = local-name()">
		<xsl:apply-templates />
	    </xsl:when>
	    <xsl:otherwise>
		<xsl:variable name="data">
		    <data>
			<xsl:for-each select="@*">
			    <xsl:element name="{local-name()}"><xsl:value-of select="."/></xsl:element>
			</xsl:for-each>
		    </data>
		</xsl:variable>
		<xsl:choose>
		    <xsl:when test="local-name() = 'posts' and @mode">
			<xsl:variable name="wdt"><xsl:value-of select="concat(replace (local-name(.), '-', '_'), '_', @mode)"/></xsl:variable>
		    </xsl:when>
		    <xsl:otherwise>
			<xsl:variable name="wdt"><xsl:value-of select="replace (local-name(.), '-', '_')"/></xsl:variable>
		    </xsl:otherwise>
		</xsl:choose>
		<xsl:variable name="test"><xsl:value-of select="number(vm:render ($wdt, $class, $data, $ctr, $post, $comm, $tb))"/></xsl:variable>
		<!-- XXX: exceptions -->
		<xsl:if test="local-name() = 'post-comments' or local-name() = 'post-trackbacks'
		    or local-name() = 'post-enclosure' or local-name() = 'post-tags'
		    or local-name() = 'post-modification-date' or local-name() = 'post-categories' ">
		    <xsl:if test="$test = 1">
			<!--xsl:message terminate="no">render: <xsl:value-of select="local-name()"/> test=[<xsl:value-of select="$test"/>]</xsl:message-->
			<xsl:apply-templates />
		    </xsl:if>
		</xsl:if>
	    </xsl:otherwise>
	</xsl:choose>
    </xsl:template>

    <xsl:template match="v:*">
	<xsl:apply-templates />
    </xsl:template>

    <xsl:template match="*">
	<xsl:variable name="elm" select="local-name()"/>
	<xsl:variable name="single" select="boolean (*|text())"/>
	<xsl:value-of select="vm:render-static ($elm, '', 1, $single)" />
	    <xsl:for-each select="@*">
	       <xsl:value-of select="vm:render-static (local-name(), string(.), 2, 0)" />
	   </xsl:for-each>
	<xsl:if test="$single"><xsl:value-of select="vm:render-static ('&gt;', '', 3, 0)" /></xsl:if>
	    <xsl:apply-templates />
	<xsl:value-of select="vm:render-static ($elm, '', 0, $single)" />
    </xsl:template>

    <xsl:template match="text()">
	<xsl:value-of select="vm:render-static (., '', 3, 0)" />
    </xsl:template>

</xsl:stylesheet>
