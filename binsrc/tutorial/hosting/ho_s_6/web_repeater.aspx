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
<title>Data bound Repeater</title>
<script runat="server">
	void Page_Load (object o, EventArgs e) 
	{
		if (!IsPostBack) {
			ArrayList list = new ArrayList ();
			list.Add (new Datum ("Spain", "es", "Europe"));
			list.Add (new Datum ("Japan", "jp", "Asia"));
			list.Add (new Datum ("Mexico", "mx", "America"));
			rep.DataSource = list;
			rep.DataBind ();
		}
	}

	public class Datum 
	{
		private string country;
		private string abbr;
		private string continent;

		public Datum (string country, string abbr, string continent)
		{
			this.country = country;
			this.abbr = abbr;
			this.continent = continent;
		}

		public string Country 
		{
			get { return country; }
		}

		public string Abbr 
		{
			get { return abbr; }
		}

		public string Continent 
		{
			get { return continent; }
		}

		public override string ToString ()
		{
			return country + " " + abbr + " " + continent;
		}
	} 
</script>
</head>
<body>
<form runat="server">
<asp:Repeater id=rep runat="server">
	<HeaderTemplate>
	<table border=2>
		<tr>
		<td><b>Country</b></td> 
		<td><b>Abbreviation</b></td>
		<td><b>Continent</b></td>
		</tr>
	</HeaderTemplate>
	<ItemTemplate>
	<tr>
	<td> 
	<%# DataBinder.Eval (Container.DataItem, "Country") %> 
	</td>
	<td> 
	<%# DataBinder.Eval (Container.DataItem, "Abbr") %>
	</td>
	<td> 
	<%# DataBinder.Eval (Container.DataItem, "Continent") %>
	</td>
	</tr>
	</ItemTemplate>
	<FooterTemplate>
	</table>
	</FooterTemplate>
</asp:Repeater>
</form>
</html>
</body>

