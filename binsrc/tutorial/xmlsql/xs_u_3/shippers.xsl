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
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="html" indent="yes" />

    <xsl:template match="/">
        <html>
            <head>
            <title>Shipping companies</title>
	    <link rel="stylesheet" type="text/css" href="/tutorial/xmlsql/demo.css" />
            </head>
            <body>
            <xsl:apply-templates/>
            </body>
        </html>
    </xsl:template>

    <xsl:template match="root">
        <H4>Shipping companies</H4>
        <table class="tableresult">
            <tr><th>ID</th><th>Name</th><th>Phone</th></tr>
            <xsl:apply-templates/>
        </table>
    </xsl:template>

    <xsl:template match="Shippers">
        <tr>
            <td><xsl:value-of select="@ShipperID"/></td>
            <td><xsl:value-of select="@CompanyName"/></td>
            <td><xsl:value-of select="@Phone"/></td>
        </tr>
    </xsl:template>
</xsl:stylesheet>
