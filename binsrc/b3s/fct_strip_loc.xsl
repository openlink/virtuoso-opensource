<?xml version="1.0" encoding="utf-8"?>
<!--
--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2017 OpenLink Software
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
<xsl:stylesheet version="1.0"
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<!-- strip "temporary" location data off any cond with auto-acquire enabled for permalinks -->

<xsl:template match="cond[@acquire='true']">
  <cond type="near">
    <xsl:attribute name="neg">
      <xsl:value-of select="./@neg"/>
    </xsl:attribute>
    <xsl:attribute name="location-prop">
      <xsl:value-of select="./@location-prop"/>
    </xsl:attribute>
    <xsl:attribute name="d">
      <xsl:value-of select="./@d"/>
    </xsl:attribute>
    <xsl:attribute name="acquire">
      <xsl:value-of select="./@acquire"/>
    </xsl:attribute>
  </cond>
</xsl:template>

<xsl:template match="@* | node()">
  <xsl:copy>
    <xsl:apply-templates select="@* | node()"/>
  </xsl:copy>
</xsl:template>

</xsl:stylesheet>
