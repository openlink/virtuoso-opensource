<%@ Page Language="C#" %>
<!--
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
<html>
<head>
<title>HtmlTable, HtmlTableRow, HtmlTableCell</title>
<script runat="server">
	void Page_Load(Object sender, EventArgs e) 
	{
		for (int i = 0; i < 5; i++){
			HtmlTableRow row = new HtmlTableRow ();
			for (int j = 0; j < 4; j++){
				HtmlTableCell cell = new HtmlTableCell ();
				cell.Controls.Add (new LiteralControl ("Row " + i + ", cell " + j));
				row.Cells.Add (cell);
			}
			myTable.Rows.Add (row);
		}
	}
</script>
</head>
<body>  
<form runat="server">
<p>
<table id="myTable" CellPadding=2 CellSpacing=1 Border="2" BorderColor="blue" runat="server" /> 
</form>
</body>
</html>

