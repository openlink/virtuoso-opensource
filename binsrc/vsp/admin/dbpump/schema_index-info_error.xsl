<?xml version="1.0"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2015 OpenLink Software
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
  <xsl:template match="/">
  <xsl:param name="param1"/>
  <xsl:param name="param2"/>
<xsl:value-of select="$param1" />
    <TABLE>
      <TR>
      <TH>Table</TH>
      <TH>Name</TH>
      <TH>Key Id</TH>
      </TR>
        <xsl:for-each select="schema/index[@name=$param1 or @key_id=$param2 or @table=$param1]">
	  <TR>
	  <td align="center"><xsl:value-of select="@table"/></td>
	  <td align="center"><xsl:value-of select="@name"/></td>
	  <td align="center"><xsl:value-of select="@key_id"/></td>
	  </TR>
	  <TR>
	  <td colspan="2"><TABLE border="1">
          <tr>
	    <th>Name</th>
	    <th>Col Id</th>
	    <th>Type</th>
          </tr>
            <xsl:for-each select="column">
	      <tr>
		<td><xsl:value-of select="@name"/></td>
		<td><xsl:value-of select="@col_id"/></td>
		<td><xsl:value-of select="@type"/>&nbsp;</td>
	      </tr>
            </xsl:for-each>
	  </TABLE></td>
	  </TR>
        </xsl:for-each>
      </TABLE>
  </xsl:template>
</xsl:stylesheet>
