<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2018 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
    <xsl:output indent="yes" doctype-public="+//IDN python.org//DTD XML Bookmark Exchange Language 1.0//EN//XML"
	doctype-system="http://pyxml.sourceforge.net/topics/dtds/xbel-1.0.dtd"/>
    <xsl:template match="folder[not (bookmark)]"/>
    <xsl:template match="*">
	<xsl:copy>
	    <xsl:copy-of select="@*[local-name()!='id']"/>
	    <xsl:if test="@id">
		<xsl:attribute name="id"><xsl:value-of select="generate-id()"/></xsl:attribute>
	    </xsl:if>
	    <xsl:apply-templates />
	</xsl:copy>
    </xsl:template>
</xsl:stylesheet>
