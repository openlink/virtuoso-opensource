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

<xsl:output method="xml" indent="yes" />

<!-- ==================================================================== -->

	<xsl:param name="imgroot">../images/</xsl:param>
	<xsl:param name="chap">overview</xsl:param>
	<xsl:param name="serveraddr">http://localhost:8890/doc/html</xsl:param>
	<xsl:param name="thedate">not specified</xsl:param>

<!-- ==================================================================== -->

<xsl:template match="/book">
<opml version="2.0">
  <head>
    <title><xsl:value-of select="title" /></title>
    <ownerName><xsl:value-of select="bookinfo/authorgroup/author/firstname" /></ownerName>
    <ownerEmail>documentation@openlinksw.co.uk</ownerEmail>
    <dateCreated><xsl:value-of select="$thedate" /></dateCreated>
  </head>
  <body>
<xsl:apply-templates select="chapter" />
  </body>
</opml>
</xsl:template>

<xsl:template match="chapter">
  <outline>
    <xsl:attribute name="title"><xsl:value-of select="title" /></xsl:attribute>
    <xsl:attribute name="htmlUrl"><xsl:value-of select="$serveraddr" />/<xsl:value-of select="@id" />.html</xsl:attribute>
    <xsl:attribute name="xmlUrl"><xsl:value-of select="$serveraddr" />/<xsl:value-of select="@id" />.rss</xsl:attribute>
  </outline>
</xsl:template>

</xsl:stylesheet>
