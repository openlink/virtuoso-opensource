<?xml version="1.0"?>
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
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:env="http://www.w3.org/2003/05/soap-envelope"
    xmlns:enc="http://www.w3.org/2003/05/soap-encoding"
    xmlns:rpc="http://www.w3.org/2003/05/soap-rpc">
    <xsl:output method="xml" indent="yes" />
    <xsl:param name="this" />
    <xsl:param name="next" select="'http://www.w3.org/2003/05/soap-encoding/role/next'"/>
    <xsl:template match="/">
	<env:Envelope>
	    <xsl:apply-templates />
	</env:Envelope>
    </xsl:template>
    <xsl:template match="env:Envelope">
	<xsl:apply-templates />
    </xsl:template>
    <xsl:template match="*[@env:role = $this or @env:role = $next]"/>
    <xsl:template match="*">
	<xsl:copy>
	    <xsl:copy-of select="@*" />
	    <xsl:apply-templates />
	</xsl:copy>
    </xsl:template>
</xsl:stylesheet>
