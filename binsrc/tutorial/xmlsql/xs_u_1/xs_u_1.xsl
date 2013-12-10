<?xml version='1.0'?>
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
 -  
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" />
  <xsl:template match="/">
    <ROOT xmlns:sql="urn:schemas-microsoft-com:xml-sql">
    <sql:sync>
    <sql:after>
    <xsl:for-each select="doc/id">
      <ord>
        <oid><xsl:value-of select="@OrderID" /></oid>
        <ocid><xsl:value-of select="@CustomerID" /></ocid>
      </ord>
      <xsl:text>
      </xsl:text>
      <xsl:for-each select="oid">
      <oline>
        <olid><xsl:value-of select="@OrderID" /></olid>
        <olq><xsl:value-of select="@Quantity" /></olq>
        <olp><xsl:value-of select="@UnitPrice" /></olp>
      </oline> 
      <xsl:text>
      </xsl:text>
      </xsl:for-each>
    </xsl:for-each>
    </sql:after>
    </sql:sync>
    </ROOT>
  </xsl:template>
</xsl:stylesheet>
