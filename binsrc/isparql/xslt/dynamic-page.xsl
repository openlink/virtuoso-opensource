<?xml version="1.0" ?>
<!--

  $Id$

  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.

  Copyright (C) 2009 OpenLink Software

  See LICENSE file for details.

-->
<xsl:stylesheet version="1.0" xmlns:xsl='http://www.w3.org/1999/XSL/Transform'>
    <xsl:output method="html"/>

	<xsl:template match = "/*">
	<html>
	<head>
		<script type="text/javascript">var featureList = ["xml"];</script>
		<script type="text/javascript" src="/isparql/toolkit/loader.js"></script>
		<script type="text/javascript">
			function init() {
				var target = "/isparql/execute.html";

				var p = {};
				p.sponge = "<xsl:value-of select="//should_sponge" />";
				<xsl:if test="should_sponge">
				p.sponge = "<xsl:value-of select="//should_sponge" />";
				</xsl:if>
				
				p.endpoint = "<xsl:value-of select="//endpoint" />";
				<xsl:if test="endpoint">
				p.endpoint = "<xsl:value-of select="//endpoint" />";
				</xsl:if>

				p.defaultGraph = "<xsl:value-of select="//graph" />";
				p.query = OAT.Xml.unescape($("p").innerHTML);
				p.file = window.location.href;
				
				var tmp = "";
				for (var prop in p) {
					tmp += prop+"="+encodeURIComponent(p[prop])+"&amp;";
				}
				window.location.href = target+"?"+tmp;
			}
		</script>
		<title>iSPARQL XSLT Forward</title>
	</head>
	<body><pre style="visibility:hidden;" id="p"><xsl:value-of select="//query"/></pre>
	</body>
	</html>
	
	</xsl:template>
</xsl:stylesheet>
