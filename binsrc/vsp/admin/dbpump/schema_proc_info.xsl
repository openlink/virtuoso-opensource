<?xml version="1.0"?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl">
  <xsl:param name="param1"/>
  <xsl:template match="/">
<xsl:value-of select="$param1" />
    <TABLE border="1">
        <xsl:for-each select="schema/procedure[@name=$param1]">
	  <TR>
	  <th>Name</th>
	  <td align="center"><xsl:value-of select="@name"/>&nbsp;</td>
	  </TR>
	  <TR>
	  <th>Comment</th>
	  <td align="center"><xsl:value-of select="@comment"/>&nbsp;</td>
	  </TR>
	  <TR>
	  <th>N In</th>
	  <td align="center"><xsl:value-of select="@n_in"/>&nbsp;</td>
	  </TR>
	  <TR>
	  <th>N Out</th>
	  <td align="center"><xsl:value-of select="@n_out"/>&nbsp;</td>
	  </TR>
	  <TR>
	  <th>N R Sets</th>
	  <td align="center"><xsl:value-of select="@n_r_sets"/>&nbsp;</td>
	  </TR>
	  <TR>
	  <th>More</th>
	  <td align="center"><xsl:value-of select="@more"/>&nbsp;</td>
	  </TR>
	  <TR>
	  <th>Text</th>
	  <td align="center"><xsl:value-of select="@text"/>&nbsp;</td>
	  </TR>
	  <TR>
	  <th>Type</th>
	  <td align="center"><xsl:value-of select="@type"/>&nbsp;</td>
	  </TR>
        </xsl:for-each>
      </TABLE>
  </xsl:template>
</xsl:stylesheet>
