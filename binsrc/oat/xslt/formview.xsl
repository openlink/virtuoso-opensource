<?xml version="1.0" ?>
<!--

  $Id$

  This file is part of the OpenLink Ajax Toolkit (OAT) project

  Copyright (C) 2005-2013 OpenLink Software

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

	<xsl:template name="gems">
		<xsl:for-each select="//object[@type = 'gem1']">
			<xsl:element name="link">
				<xsl:attribute name="rel">alternate</xsl:attribute>
				<xsl:attribute name="type"><xsl:value-of select="properties/property[name = 'MIME type']/value" /></xsl:attribute>
				<xsl:attribute name="title"><xsl:value-of select="properties/property[name = 'Link name']/value" /></xsl:attribute>
 				<xsl:attribute name="href"><xsl:value-of select="properties/property[name = 'Resulting file']/value" /></xsl:attribute>
			</xsl:element>
		</xsl:for-each>
	</xsl:template>

	<xsl:template name="form"> <!-- basic form properties -->
		<xsl:variable name="nocred">
			<xsl:for-each select="//connection|/form">
				<xsl:value-of select="@nocred" />
			</xsl:for-each>
		</xsl:variable>
		var nocred = "<xsl:value-of select="$nocred" />";
		<xsl:variable name="showajax">
			<xsl:for-each select="//connection|/form">
				<xsl:value-of select="@showajax" />
			</xsl:for-each>
		</xsl:variable>
		var showajax = "<xsl:value-of select="$showajax" />";
	</xsl:template>
	
    <xsl:template match = "/*"> <!-- see http://www.dpawson.co.uk/xsl/sect2/root.html for explanation -->
	<html>
		<head>
			<xsl:call-template name="gems" />
			<script type="text/javascript">
				var featureList = ["form"];
			</script>
			<script type="text/javascript" src="/DAV/JS/oat/loader.js"></script>
			<script type="text/javascript">
			<![CDATA[
				var loadingDiv = false;

				function unlink() {
					OAT.Dom.unlink(loadingDiv);
					loadingDiv = false;
				}

				function init() {
			]]>
					<xsl:call-template name="form" />
			<![CDATA[
					var options = {
						onReady:unlink
					}
					
					if (nocred == true) { options.noCred = 1; }
					if (showajax == false) { OAT.AJAX.startRef = function() { return; } }
					
					loadingDiv = OAT.Dom.create("div", {float:"left"});
					var img = OAT.Dom.create("img");
					img.src = OAT.Preferences.imagePath + "Ajax_throbber.gif";
					var txt = OAT.Dom.text(" Processing form content...");

					loadingDiv.appendChild(img);
					loadingDiv.appendChild(txt);
					document.body.appendChild(loadingDiv);
					var f = new OAT.Form(document.body,options);
					f.createFromURL(window.location.toString());
				}
			]]>
			</script>
			
<style type="text/css">
	@import url("/DAV/JS/styles/grid.css");
	@import url("/DAV/JS/styles/timeline.css");
	@import url("/DAV/JS/styles/pivot.css");
	@import url("/DAV/JS/styles/webclip.css");
	
	input, select {
		font: menu;
	}

	.ie_height_fix {
		height: expression(this.ieHeight ? eval(this.ieHeight.offsetHeight) : "0px");
	}

	.right {
		text-align: right;
	}
	
	body {
		font-family: verdana;
		padding: 0px;
		margin: 0px;
	}
	
	.nav {
		font-weight: bold;
		position: absolute;
		left: 10px;
		bottom: 10px;
	}			

	.form {
		border: 2px ridge #aaa;
	}

	.chart {
		height: 200px;
		background-color: #aaa;
		position: relative;
	}

	.legend {
		background-color: #fff;
		border: 1px solid #000;
		font-size: 90%;
		padding: 1px;
	}

	.legend_box {
		width: 10px;
		height: 10px;
		border: 1px solid #000;
		margin: 2px;
		float: left;
		font-size: 0px;
	}

	.textX {
		font-size: 60%;
		text-align: center;
	}

	.textY {
		font-size: 80%;
	}				
	#webclip {
		position: absolute;
		top: 1px;
		right: 1px;
		z-index: 900;
	}

	ul, li {
		margin: 0px;
		padding: 0px;
	}
	
	ul.tab {
		list-style-type: none;
		position:relative;
		left:-2px;
		_left:-4px;
	}

	li.tab {
		display: block;
		border: 2px solid #000;
		padding: 2px 3px;
		margin-right: 0.5em;
		cursor: pointer;
		height:20px;
		_height:28px;
		float:left;
		background-color: #aaa;
	}

	li.tab_selected {
		background-color: #888;
		border-bottom-color: #888;
	}

	li.tab:hover {
		background-color: #ccc;
	}
	
	li.tab_selected:hover {
		background-color: #888;
	}
	
	.tag_cloud a {
		text-decoration: none;
		color: #000;
	}
	
	.rdf_sidebar li {
		margin-left: 0.5em;
	}
	
	.rdf_sidebar {
		font-size: 80%;
		border: 1px solid #000;
		background-color: #fff;
		width: 250px;
		padding: 3px;
	}
</style>
			
			<title>Form</title>
		</head>
		
		<body></body>
	</html>
	</xsl:template>
</xsl:stylesheet>
