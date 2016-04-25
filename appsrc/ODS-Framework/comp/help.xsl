<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2016 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     version="1.0"
     xmlns:v="http://www.openlinksw.com/vspx/"  exclude-result-prefixes="v"
     xmlns:xhtml="http://www.w3.org/1999/xhtml">
<xsl:output method="text" omit-xml-declaration="yes" indent="yes" />

<xsl:template match="/">
  <xsl:apply-templates />
</xsl:template>

<xsl:template match="wahelp">
  <xsl:apply-templates select="./help[@page=$fragment]"/>
</xsl:template>

<xsl:template match="help">
  <div class="helpbox" id="helpbox"><xsl:apply-templates /></div>
</xsl:template>

<xsl:template match="help/title">
  <h2><xsl:apply-templates /></h2>
</xsl:template>

<xsl:template match="simplelist">
  <ul><xsl:apply-templates /></ul>
</xsl:template>

<xsl:template match="member">
  <li><xsl:apply-templates /></li>
</xsl:template>

<xsl:template match="sect/title">
  <h3><xsl:apply-templates /></h3>
</xsl:template>

<xsl:template match="sect">
  <div class="helpsect"><xsl:apply-templates /></div>
</xsl:template>

<xsl:template match="para">
  <p><xsl:apply-templates /></p>
</xsl:template>

<xsl:template match="emphasis">
  <strong><xsl:apply-templates /></strong>
</xsl:template>

</xsl:stylesheet>

