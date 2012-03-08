<html>
<!--
 -  
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2012 OpenLink Software
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
<head>
<script language="C#" runat="server">
	void Click (object o, EventArgs e) 
	{
		 lbl.Text = "You selected '" + ddl.SelectedItem.Text +
			    "' (index #" + ddl.SelectedIndex + ").";  
	}
</script>
<title>DropDownList</title>
</head>
<h3>DropDownList test</h3>
<body>
	<form runat="server">
		<asp:DropDownList id="ddl" runat="server">
			<asp:ListItem>Item 1</asp:ListItem>
			<asp:ListItem>Item 2</asp:ListItem>
			<asp:ListItem>Item 3</asp:ListItem>
			<asp:ListItem>Item 4</asp:ListItem> 
		</asp:DropDownList>
		<br><br>
		<asp:Button id="btn" Text="Submit"
			    OnClick="Click" runat="server"/>
		<hr>
		<asp:Label id="lbl" runat="server"/>
	</form>
</body>

