<?xml version="1.0" ?>
<!--

  $Id$

  This file is part of the OpenLink Ajax Toolkit (OAT) project

  Copyright (C) 2005-2019 OpenLink Software

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
	<xsl:strip-space elements="*"/>

	<xsl:template name="recursion">
		<xsl:for-each select="node()">
		<li>
			<xsl:choose>
				<xsl:when test="name()=''">
					<em><xsl:value-of select="." /></em>
				</xsl:when>
				<xsl:otherwise>
				<xsl:value-of select="name()" />
					<ul>
						<xsl:for-each select="@*">
							<li>
							<xsl:value-of select="name()" /> = <xsl:value-of select="." />
							</li>
						</xsl:for-each>
						<xsl:call-template name="recursion" />
					</ul>
				</xsl:otherwise>
			</xsl:choose>
		</li>
		</xsl:for-each>
	</xsl:template>
	
    <xsl:template match = "/*"> <!-- see http://www.dpawson.co.uk/xsl/sect2/root.html for explanation -->

	<html>
	<head>
		<script type="text/javascript">
			var featureList = ["tree"];
		</script>
		<script type="text/javascript" src="/DAV/JS/oat/loader.js"></script>
		<script type="text/javascript">
		<![CDATA[
			function init() {
				var t = new OAT.Tree();
				t.assign('tree',1);
			}
		]]>
		</script>
		<style type="text/css">
			ul {
				margin: 0px;
				padding: 0px;
			}
			ul#tree ul {
				padding-left: 1em;
				_padding-left: 0em;
				_margin-left: 1em;
			}
		</style>
		<title>XML tree</title>
		<link rel="stylesheet" href="style.css" type="text/css" />
	</head>
	<body>

	<ul id="tree">
		<li>
			<xsl:value-of select="name()" />
			<ul>
				<xsl:call-template name="recursion" />
			</ul>
		</li>
	</ul>


	</body>
	</html>
	
	</xsl:template>
</xsl:stylesheet>
