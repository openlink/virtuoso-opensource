<?xml version="1.0"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2014 OpenLink Software
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
    <TABLE class="genlist" border="0" cellpadding="0">
	  <TR>
	  <TH colspan="2" class="genhead">Dump Manifest</TH>
	  </TR>

	  <TR>
	  <td  CLASS="statlisthead">User Name</td>
	  <td  CLASS="statdata"><xsl:value-of select="manifest/username"/></td>
	  </TR>

	  <TR>
	  <td  CLASS="statlisthead">Created</td>
	  <td  CLASS="statdata"><xsl:value-of select="manifest/created"/></td>
	  </TR>

	  <xsl:call-template name="tables">
	  </xsl:call-template>
	  <br/>
	  <xsl:call-template name="views">
	  </xsl:call-template>
	  <br/>
	  <xsl:call-template name="procs">
	  </xsl:call-template>
	  <br/>
	  <xsl:call-template name="users">
	  </xsl:call-template>
    </TABLE>

  </xsl:template>

  <xsl:template name="tables">
      <TR>
      <TH colspan="2" class="genhead">Tables</TH>
      </TR>
        <xsl:for-each select="manifest/tables/table">
	  <TR>
	  <td  colspan="2"  CLASS="statdata"><xsl:value-of select="name"/></td>
	  </TR>
        </xsl:for-each>
  </xsl:template>

  <xsl:template name="views">
      <TR>
      <TH  colspan="2" class="genhead">Views</TH>
      </TR>
        <xsl:for-each select="manifest/views/view">
	  <TR>
	  <td  colspan="2"  CLASS="statdata"><xsl:value-of select="name"/></td>
	  </TR>
        </xsl:for-each>
  </xsl:template>

  <xsl:template name="procs">
      <TR>
      <TH  colspan="2" class="genhead">Procs</TH>
      </TR>
        <xsl:for-each select="manifest/procedures/proc">
	  <TR>
	  <td   colspan="2" CLASS="statdata"><xsl:value-of select="name"/></td>
	  </TR>
        </xsl:for-each>
  </xsl:template>

  <xsl:template name="users">
      <TR>
      <TH  colspan="2" class="genhead">Users</TH>
      </TR>
        <xsl:for-each select="manifest/users/user">
	  <TR>
	  <td   colspan="2" CLASS="statdata"><xsl:value-of select="name"/></td>
	  </TR>
        </xsl:for-each>
  </xsl:template>
</xsl:stylesheet>
