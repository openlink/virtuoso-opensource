<%@ Page Language="C#" %>
<!--
 -  
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2018 OpenLink Software
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
	<script runat="server">
	private void Page_Load (object sender, EventArgs e)
	{
		if (!IsPostBack){
			ArrayList optionsList = new ArrayList ();
			optionsList.Add ("One");
			optionsList.Add ("Two");
			optionsList.Add ("Three");
			optionsList.Add ("Four");
			optionsList.Add ("Five");
			list.DataSource = optionsList;
			list.DataBind();
		}
		else 
			msg.DataBind ();
	}
	</script>
</head>
<body>
	<h3>Data binding in attribute values</h3>
	Another silly example for your pleasure...
	<form id="form" runat="server">     
		<asp:DropDownList id="list" runat="server" autopostback="true" />
		<p>
		<asp:Label id="msg" runat="server" text="<%# list.SelectedItem.Text %>"/>
	</form>
</body>
</html>

