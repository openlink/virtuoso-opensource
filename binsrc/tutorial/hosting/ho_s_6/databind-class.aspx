<%@ Page Language="C#" %>
<!--
 -  
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2014 OpenLink Software
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
	public class NumberMessage
	{
		private int number;
		private string message;
		
		public NumberMessage (int number, string message)
		{
			this.number = number;
			this.message = message;
		}

		public int Number 
		{
			get { return number; }
		}

		public string Message 
		{
			get { return message; }
		}
	}
	
	private void Page_Load (object sender, EventArgs e)
	{
		if (!IsPostBack){
			optionsList.Add (new NumberMessage (1, "One"));
			optionsList.Add (new NumberMessage (2, "Two"));
			optionsList.Add (new NumberMessage (3, "Three"));
			optionsList.Add (new NumberMessage (4, "Four"));
			optionsList.Add (new NumberMessage (5, "Five"));
			list.DataSource = optionsList;
			list.DataBind();
		}
		else
			msg.Text = "Selected option: " + list.SelectedItem.Text + " " + list.SelectedItem.Value;
	}
	</script>
</head>
<body>
	<object id="optionsList" runat="server" class="System.Collections.ArrayList" />
	<h3>Data binding using an array list containing a class</h3>
	DataTextField and DataValueField must contain property names of the
	class bound to the DropDownList.
	<form id="form" runat="server">     
		<asp:DropDownList id="list" runat="server" autopostback="true" 
		datatextfield="Message" datavaluefield="Number"/>
		<asp:Label id="msg" runat="server" />
	</form>
</body>
</html>

