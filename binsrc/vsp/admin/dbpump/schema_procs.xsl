<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2017 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl">
<xsl:param name="param1"/>
  <xsl:template match="/">
    <TABLE border="1">
      <TR>
      <TH>Name</TH>
      <TH>Comment</TH>
      <TH>Type</TH>
      </TR>
        <xsl:for-each select="schema/procedure">
	  <TR>
	  <td><a><xsl:attribute name="href">schema_proc_info.vsp?name=<xsl:value-of select="@name"/></xsl:attribute><xsl:value-of select="@name"/></a></td>
	  <td><xsl:value-of select="@comment"/>&nbsp;</td>
	  <td><xsl:value-of select="@type"/></td>
	  </TR>
        </xsl:for-each>
      </TABLE>
  </xsl:template>
</xsl:stylesheet>
