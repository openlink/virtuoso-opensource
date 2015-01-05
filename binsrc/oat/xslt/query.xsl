<?xml version="1.0" ?>
<!--

  $Id$

  This file is part of the OpenLink Ajax Toolkit (OAT) project

  Copyright (C) 2005-2015 OpenLink Software

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

    <xsl:template match = "/root">

	<html>
	<head>
		<script type="text/javascript">
			var featureList = ["grid","ajax","xmla","soap","dialog","crypto","datasource","formobject","webclip"];
		</script>
		<script type="text/javascript" src="/DAV/JS/oat/loader.js"></script>
		<script type="text/javascript">
		
		var user = "<xsl:value-of select="connection/@user" />";
		var password = "<xsl:value-of select="connection/@password" />";
		var dsn = "<xsl:value-of select="connection/@dsn" />";
		var endpoint = "<xsl:value-of select="connection/@endpoint" />";
		var nocred = "<xsl:value-of select="connection/@nocred" />";
		<![CDATA[
			function init() {
				var q = $("query").innerHTML;
				OAT.Dom.unlink("query");

				var conn = new OAT.Connection(OAT.ConnectionData.TYPE_XMLA);
				conn.options.user = OAT.Crypto.base64d(user);
				conn.options.password = OAT.Crypto.base64d(password);
				conn.options.dsn = dsn;
				conn.options.endpoint = endpoint;

				var ds = new OAT.DataSource(OAT.DataSourceData.TYPE_SQL);
				ds.connection = conn;
				ds.pageSize = 50;
				ds.options.query = OAT.Dom.fromSafeXML(q);
				
				var nav = new OAT.FormObject["nav"](30,0,0);
				var grid = new OAT.FormObject["grid"](30,0,0);
				$("grid").appendChild(grid.elm);
				$("nav").appendChild(nav.elm);
				grid.elm.style.width = "100%";
				grid.showAll = true;
				nav.init();
				grid.init();
				ds.bindRecord(nav.bindRecordCallback);
				ds.bindRecord(grid.bindRecordCallback);
				ds.bindPage(grid.bindPageCallback);
				ds.bindHeader(grid.bindHeaderCallback);
				
				OAT.Event.attach(nav.first,"click",function() { ds.advanceRecord(0); });
				OAT.Event.attach(nav.prevp,"click",function() { ds.advanceRecord(ds.recordIndex - ds.pageSize); });
				OAT.Event.attach(nav.prev,"click",function() { ds.advanceRecord("-1"); });
				OAT.Event.attach(nav.next,"click",function() { ds.advanceRecord("+1"); });
				OAT.Event.attach(nav.nextp,"click",function() { ds.advanceRecord(ds.recordIndex + ds.pageSize); });
				OAT.Event.attach(nav.current,"keyup",function(event) { 
					if (event.keyCode != 13) { return; }
					var value = parseInt($v(nav.current));
					ds.advanceRecord(value-1); 
				});
				
				
				var cont = function() {
					ds.advanceRecord(0);
				}

				if (user || parseInt(nocred)) {
					OAT.Dom.unlink("credentials");
					cont();
				} else {
					var d = new OAT.Dialog("Credentials","credentials",{modal:1,width:300});
					d.show();
					var ref = function() {
						conn.options.user = $v("cred_user");
						conn.options.password = $v("cred_password");
						d.hide();
						cont();
					}
					d.ok = ref;
					d.cancel = d.hide;
				}

			}
]]>
		</script>
		<style type="text/css">
			@import url("/DAV/JS/styles/grid.css");
			@import url("/DAV/JS/styles/webclip.css");
			
			.right {
				text-align: right;
			}

			#credentials {
				margin: 1em;
			}
			
			#grid {
				height:600px;
				width: 90%;
				overflow: auto;
			}
		</style>
		<title>Query results</title>
	</head>
	<body>

		<div id="grid" style="position:relative;"></div>
		<div id="nav" style="position:relative;"></div>
	
		<div id="query"><xsl:value-of select="query" /></div>

		<div id="credentials">
			<table>
			<tr><td class="right">Name: </td><td><input name="cred_user" value="demo" type="text" id="cred_user" /></td></tr>
			<tr><td class="right">Password: </td><td><input name="cred_password" value="demo" type="password" id="cred_password" /></td></tr>
			</table>
		</div>
	</body>
	</html>
	
	</xsl:template>
</xsl:stylesheet>
