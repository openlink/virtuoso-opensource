<?xml version="1.0"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2019 OpenLink Software
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

<!-- XSL Stylesheet to view hierarchical rowsets as HTML -->

<!-- xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl" language="vbscript" -->
<xsl:stylesheet
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
		xmlns:msxsl="urn:schemas-microsoft-com:xslt"
		xmlns:xd="urn:schemas-microsoft-com:xml-analysis:rowset"
		xmlns:sql="urn:schemas-microsoft-com:xml-sql"
		xmlns:xsd="http://www.w3.org/2001/XMLSchema"
		version="1.0" >

	<xsl:output method="html" />

	<!-- Open the HTML for the top level document -->
	<xsl:template match="/">
	        <DIV>
		<TABLE class="tableresult">
		<TR>
		<xsl:apply-templates select="//xsd:schema/xsd:complexType[@name='row']//xsd:element/@sql:field" />
		</TR>
		<xsl:apply-templates select="//xd:row" />
		</TABLE>
		</DIV>
	</xsl:template>

	<xsl:template match="xd:row">
		<xsl:variable name="varCurrRow" select="." />
		<TR>
		<!-- Print the values of the attributes (got to handle NULL attributes) -->
		<xsl:for-each select="//xsd:schema/xsd:complexType[@name='row']//xsd:element">
			<xsl:variable name="varCurrCol" select="./@name" />
			<TD>
			<xsl:choose>
				<xsl:when test="$varCurrRow/*[local-name() = $varCurrCol]">
					<xsl:value-of select="$varCurrRow/*[local-name() = $varCurrCol]" />
				</xsl:when>
				<xsl:otherwise>
					<I>null</I>
				</xsl:otherwise>
			</xsl:choose>
			</TD>
		</xsl:for-each>
		</TR>
	</xsl:template>

	<xsl:template match="@sql:field">
		<TH>
		<xsl:value-of select="." />
		</TH>
	</xsl:template>

</xsl:stylesheet>
