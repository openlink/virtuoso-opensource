<%@ Page Language="C#" %>
<!--
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
<html>
<head>
<script language="C#" runat="server">
	private string folks = "folks";
	void Page_Load(object src, EventArgs e)
	{
		if (!Page.IsPostBack){

			ArrayList values = new ArrayList();

			values.Add (0);
			values.Add (1);
			values.Add (2);
			values.Add (3);
			values.Add (4);
			values.Add (5);
			values.Add (6);

			DataList1.DataSource = values;
			DataList1.DataBind();
		}
	}

	string EvenOrOdd(int number)
	{
		return (string) ((number % 2) == 0 ? "even" : "odd");
	}
</script>
</head>
<body>
<h3>Data binding and templates</h3>
	Testing data bound literal inside templates.
	<form runat=server>
		<asp:DataList id="DataList1" runat="server"
			BorderColor="blue"
			BorderWidth="2"
			GridLines="Both"
			CellPadding="5"
			CellSpacing="2" >

			<ItemTemplate>
			Number: <%# Container.DataItem %>
			This is an <b><%# EvenOrOdd((int) Container.DataItem) %></b> number.
			</ItemTemplate>
			<FooterTemplate>
			That is all <%# folks %>
			</FooterTemplate>
		</asp:datalist>
	</form>
</body>
</html>


