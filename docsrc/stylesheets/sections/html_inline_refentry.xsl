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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

<xsl:output method="html" 
  doctype-public="-//W3C//DTD HTML 4.0 Transitional//EN" 
  doctype-system="http://www.w3.org/TR/1999/REC-html401-19991224/loose.dtd" />

<!-- ==================================================================== -->

	<xsl:param name="imgroot">../images/</xsl:param>
	<xsl:param name="function"></xsl:param>
	<xsl:param name="chap">functions</xsl:param>

<!-- ==================================================================== -->

<xsl:include href="html_functions.xsl"/>
<xsl:include href="html_sect1_common.xsl"/>
<xsl:include href="html_sect1_tocs.xsl"/>

<xsl:template match="/refentry">
  <xsl:variable name="cat" select="refmeta/refmiscinfo"/>

 <DIV CLASS="refentrytitle"><xsl:value-of select="refmeta/refentrytitle" /></DIV>
 <DIV CLASS="refpurpose"><xsl:apply-templates select="refnamediv/refpurpose"/></DIV>
 <xsl:for-each select="refsynopsisdiv/funcsynopsis/funcprototype">
  <xsl:sort select="funcdef/function" data-type="text"/>
  <DIV CLASS="funcsynopsis"><xsl:apply-templates/></DIV>
 </xsl:for-each>

 <xsl:apply-templates />

</xsl:template>

</xsl:stylesheet>
