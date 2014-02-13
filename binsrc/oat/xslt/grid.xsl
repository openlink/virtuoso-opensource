<?xml version="1.0" ?>
<!--

  $Id$

  This file is part of the OpenLink Ajax Toolkit (OAT) project

  Copyright (C) 2005-2014 OpenLink Software

  This project is free software; you can redistribute it and/or modify it
  under the terms of the GNU General Public License as published by the
  Free Software Foundation; only version 2 of the License, dated June 1991

  This project is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software Foundation,
  Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

-->
<xsl:stylesheet version="1.0" xmlns:xsl='http://www.w3.org/1999/XSL/Transform'>
    <xsl:output method="html"/>

	<xsl:template match="ROW[1]">
		<tr>
		<xsl:for-each select="@*">
			<td><xsl:value-of select="name()" /></td>
		</xsl:for-each>
		</tr>
	</xsl:template>

    <xsl:template match = "root">

	<html>
	<head>
		<script type="text/javascript">
			var featureList = ["grid"];
		</script>
		<script type="text/javascript" src="/DAV/JS/oat/loader.js"></script>
		<script type="text/javascript">
<![CDATA[
			
			function init() {
				OAT.GridData.init();
				var grid = new OAT.Grid("grid",{autoNumber:true});
				grid.fromTable("table");	
			}
			]]>
		</script>
		<style type="text/css">
			@import url("/DAV/JS/styles/grid.css");
			#nav {
				margin-top: 0.5em;
			}

			#nav .link {
				color: #00f;
				font-size: medium;
				font-weight: bold;
				cursor: pointer;
			}

			#nav .link:hover {
				border-bottom: 1px dotted #00f;
			}		</style>
		<title>XML tree</title>
	</head>
	<body>

	<div id="grid"></div>
	
	<table id="table">
		<thead>
			<xsl:apply-templates select="ROW[1]"/>
		</thead>
		<tbody>
			<xsl:for-each select="ROW">
			    <tr>
				<xsl:for-each select="@*">
					<td><xsl:value-of select="." /></td>
				</xsl:for-each>
			    </tr>
			</xsl:for-each>
		</tbody>
	</table>


	</body>


	</html>
	
	</xsl:template>
</xsl:stylesheet>
