<?xml version="1.0" ?>
<!--

  $Id$

  This file is part of the OpenLink Ajax Toolkit (OAT) project

  Copyright (C) 2005-2018 OpenLink Software

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

    <xsl:template match = "/*"> <!-- see http://www.dpawson.co.uk/xsl/sect2/root.html for explanation -->
	<html>
		<head>
			<script type="text/javascript">
				var featureList=["pivot","xmla","soap","ajax","window","dialog"];
			</script>	
			<script type="text/javascript" src="/DAV/JS/oat/loader.js"></script>
			<script type="text/javascript">
				var pivot = false;
				var header = [];
				var body = [];
				var headerRowIndexes = [];
				var headerColIndexes = [];
				var filterIndexes = [];
				var dataColumnIndex = false;

				function pivot_agg() {
					pivot.options.agg = parseInt($v("pivot_agg"));
					pivot.go();
				}
				<![CDATA[
				function draw() {
					pivot = new OAT.Pivot("pivot","pivot_chart","page",header,body,headerRowIndexes,headerColIndexes,filterIndexes,dataColumnIndex);
				}
				]]>
				function init() {
				<![CDATA[
					/* create agg function list */
					OAT.Dom.clear("pivot_agg");
					for (var i=0;i<OAT.Statistics.list.length;i++) {
						var item = OAT.Statistics.list[i];
						OAT.Dom.option(item.shortDesc,i,"pivot_agg");
					}
					$("pivot_agg").selectedIndex = 1;
				]]>
					<xsl:for-each select="//headerRowIndexes/value">
						headerRowIndexes.push(<xsl:value-of select="." />);
					</xsl:for-each>
					<xsl:for-each select="//headerColIndexes/value">
						headerColIndexes.push(<xsl:value-of select="." />);
					</xsl:for-each>
					<xsl:for-each select="//filterIndexes/value">
						filterIndexes.push(<xsl:value-of select="." />);
					</xsl:for-each>
					<xsl:for-each select="//headerRow/value">
						header.push("<xsl:value-of select="." />");
					</xsl:for-each>
					<xsl:for-each select="//dataColumnIndex">
						dataColumnIndex = <xsl:value-of select="." />;
					</xsl:for-each>
					<xsl:for-each select="//connection">
						var conn = new OAT.Connection(OAT.ConnectionData.TYPE_XMLA);
						conn.options.dsn = "<xsl:value-of select="@dsn" />";
						conn.options.endpoint = "<xsl:value-of select="@endpoint" />";
						conn.options.user = OAT.Crypto.base64d("<xsl:value-of select="@user" />");
						conn.options.password = OAT.Crypto.base64d("<xsl:value-of select="@password" />");
						OAT.Xmla.connection = conn;
						conn.nocred = parseInt("<xsl:value-of select="@nocred" />");
					</xsl:for-each>
				
					OAT.Xmla.query = $("query").innerHTML;
					OAT.Dom.unlink("query");
					var callback = function(tmp) {
						header = tmp[0];
						body = tmp[1];
						draw();
					}
					
					var cont = function() {
						OAT.Xmla.execute(callback);
					}
					
					if (OAT.Xmla.connection.options.user || OAT.Xmla.connection.nocred) {
						OAT.Dom.unlink("credentials");
						cont();
					} else {
						var d = new OAT.Dialog("Credentials","credentials",{modal:1,width:300});
						d.show();
						var ref = function() {
							OAT.Xmla.connection.options.user = $v("cred_user");
							OAT.Xmla.connection.options.password = $v("cred_password");
							d.hide();
							cont();
						}
						d.ok = ref;
						d.cancel = d.hide;
					}
					
				}
			</script>
			
			<style type="text/css">
				@import url("/DAV/JS/styles/pivot.css");
				
				.right {
					text-align: right;
				}

				#credentials {
					margin: 1em;
				}

				#ajax_alert {
					font-weight: bold;
				}

				/* pivot chart */
				#pivot_chart {
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
			</style>
			
			<title>Pivot table</title>
		</head>
		
		<body>
			<select id="pivot_agg" onchange="pivot_agg()"></select>
			<div id="page"></div>
			<div id="credentials">
				<table>
				<tr><td class="right">Name: </td><td><input name="cred_user" value="demo" type="text" id="cred_user" /></td></tr>
				<tr><td class="right">Password: </td><td><input name="cred_password" value="demo" type="password" id="cred_password" /></td></tr>
				</table>
			</div>
			<div id="pivot"></div>
			<div id="pivot_chart"></div>
			<div id="query">
				<xsl:for-each select="//query">
					<xsl:value-of select="." />
				</xsl:for-each>
			</div>
		</body>
	</html>
	</xsl:template>
</xsl:stylesheet>
