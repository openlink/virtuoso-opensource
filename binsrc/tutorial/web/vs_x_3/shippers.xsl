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
 -  
-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="html"/>

    <xsl:template match="/">
	<html>
	    <head>
            <link rel="stylesheet" type="text/css" href="../demo.css" />
	    <title>Shippers list</title>
	    </head>
	    <body>
	    <xsl:apply-templates/>
	    </body>
	</html>
    </xsl:template>

    <xsl:template match="list">
	<table class="tableresult">
	    <tr><td>ID</td><td>Name</td><td>Phone</td></tr>
	    <xsl:apply-templates/>
	</table>
    </xsl:template>

    <xsl:template match="Shippers">
	<tr>
	    <td><xsl:value-of select="ShipperID"/></td>
	    <td><xsl:value-of select="CompanyName"/></td>
	    <td><xsl:value-of select="Phone"/></td>
	</tr>
    </xsl:template>
</xsl:stylesheet>
