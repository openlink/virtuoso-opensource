<?xml version='1.0'?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2013 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

<xsl:output method="html"/>

<!-- ==================================================================== -->

			<!-- Variables -->
	<xsl:variable name="imgP">../images/</xsl:variable>
	<xsl:param name="expchap">overview</xsl:param>
			<!-- Variables -->

<!-- ==================================================================== -->

<xsl:template match="//chapter">
<DIV CLASS="contents">
<TABLE CELLPADDING="2" CELLSPACING="2">
<TR>
  <TD ALIGN="right" WIDTH="300">
  <A>
    <xsl:attribute name="HREF">virtdoc_contents.vsp?exp=<xsl:value-of select="@id" />#<xsl:value-of select="@id" /></xsl:attribute>
    <xsl:attribute name="ID"><xsl:value-of select="@id" /></xsl:attribute>
    <xsl:text>+</xsl:text>
  </A>
  </TD>
  <TD CLASS="chaptername">
  <A>
    <xsl:attribute name="HREF">virtdoc_part.vsp?part=<xsl:value-of select="@id" /></xsl:attribute>
    <xsl:attribute name="NAME"><xsl:value-of select="@id" /></xsl:attribute>
    <xsl:apply-templates select="title" />
  </A>
</TD></TR>

<xsl:if test="$expchap=@id">
<TR>
  <TD CLASS="abstract" VALIGN="top"><xsl:apply-templates select="abstract" /></TD>
  <TD CLASS="sect" NOWRAP="" VALIGN="top"><xsl:apply-templates select="sect1|sect2|sect3" /></TD>
</TR>
</xsl:if>
</TABLE>
</DIV>
</xsl:template>

<xsl:template match="sect1|sect2|sect3">
<DIV><xsl:attribute name="CLASS"><xsl:value-of select="name(.)" /></xsl:attribute>
  <A>
    <xsl:attribute name="HREF">virtdoc_part.vsp?part=<xsl:value-of select="@id" /></xsl:attribute>
    <xsl:attribute name="ID"><xsl:value-of select="@id" /></xsl:attribute>
    <xsl:apply-templates select="title" />
  </A>
<xsl:apply-templates select="sect1|sect2|sect3" />
</DIV>
</xsl:template>

<xsl:template match="title"><xsl:apply-templates /></xsl:template>

<xsl:template match="abstract"><xsl:apply-templates /></xsl:template>
<xsl:template match="abstract/para"><DIV><xsl:apply-templates /></DIV></xsl:template>

<xsl:template match="bookinfo|toc|lot|preface|book/title" />

</xsl:stylesheet>
