<?xml version="1.0" ?>
<!--
 -  
 -  $Id: emp_my.xsl,v 1.3.10.1 2013/01/02 16:14:39 source Exp $
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
    <xsl:output method="html"/>
    <xsl:template match = "root">
	<HTML>
	<HEAD>
	<STYLE>th { background-color: #CCCCCC }</STYLE>
	</HEAD>
	<BODY>
	<TABLE border="1" style="width:300;">
	<TR><TH colspan="2">Employees</TH></TR>
	<TR><TH >FirstName</TH><TH>LastName</TH></TR>
	<xsl:for-each select="Employees">
	    <TR>
	    <TD><xsl:value-of select = "@firstname" /></TD>
	    <TD><B><xsl:value-of select = "@lastname" /></B></TD>
	    </TR>
	</xsl:for-each>
	</TABLE>
	</BODY>
	</HTML>
    </xsl:template>
</xsl:stylesheet>
