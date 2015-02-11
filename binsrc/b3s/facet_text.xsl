<?xml version="1.0" encoding="utf-8"?>
<!--
--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2015 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--
-->
<xsl:stylesheet version ="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<!-- xmlns:xsl="http://www.w3.org/TR/WD-xsl" -->
<xsl:output method="text"/>
<xsl:template match="facets">
<xsl:for-each select="result/row">
  <xsl:for-each select="column">
    <xsl:value-of select="." />
    <xsl:text></xsl:text>
  </xsl:for-each>
  <xsl:text>
  </xsl:text>
</xsl:for-each>
<xsl:text> Complete = </xsl:text> <xsl:value-of select="complete"/>
<xsl:text> Activity = </xsl:text> <xsl:value-of select="db-activity"/>
</xsl:template>
</xsl:stylesheet>
