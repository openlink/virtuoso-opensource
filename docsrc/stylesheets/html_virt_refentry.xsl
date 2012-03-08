<?xml version="1.0" encoding="ISO-8859-1"?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl" result-ns="html" version="1.0">
<xsl:template match="/">
<xsl:apply-templates/>
</xsl:template>

<xsl:template match="refentry">
<html>
<head>
<title>Virtuoso SQL Function Reference: <xsl:value-of select="refmeta/refentrytitle"/></title>
<link rel="stylesheet" type="text/css" href="../stylesheets/refentry.css" />
</head>
<body>
<xsl:apply-templates select="refmeta"/>
<xsl:apply-templates select="refnamediv"/>
<xsl:apply-templates select="refsynopsisdiv"/>
<xsl:for-each select="refsect1">
  <xsl:apply-templates select="."/>
</xsl:for-each>
</body>
</html>
</xsl:template>

<xsl:template match="refmeta">
<h2><xsl:value-of select="refmiscinfo"/></h2>
<xsl:apply-templates/>
</xsl:template>

<xsl:template match="refnamediv">
<h1><xsl:value-of select="refname"/></h1>
<xsl:value-of select="refpurpose"/>
</xsl:template>

<xsl:template match="refsynopsisdiv">
<h5>Synopsis</h5>
<xsl:apply-templates/>
</xsl:template>

<xsl:template match="funcsynopsis">
  <xsl:for-each select="funcprototype">
    <xsl:apply-templates select="funcdef"/> (
    <xsl:for-each select="paramdef">
      <xsl:value-of select="."/> 
      <xsl:if test="context()[not(end())]">, </xsl:if>
    </xsl:for-each>
  </xsl:for-each> )
</xsl:template>

<xsl:template match="funcdef">
  <i><xsl:value-of select="node()"/></i>
  <xsl:apply-templates/>
</xsl:template>


<xsl:template match="refsect1">
  <h5><xsl:value-of select="title"/></h5>
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="para">
<p><xsl:value-of select="."/></p>
</xsl:template>

<xsl:template match="programlisting">
<pre><xsl:value-of select="."/></pre>
</xsl:template>

<xsl:template match="p">
<p><xsl:apply-templates/></p>
</xsl:template>

<xsl:template match="function">
<b><xsl:value-of select="."/></b>
</xsl:template>

<xsl:template match="parameter">
<xsl:value-of select="."/>
</xsl:template>

</xsl:stylesheet>

