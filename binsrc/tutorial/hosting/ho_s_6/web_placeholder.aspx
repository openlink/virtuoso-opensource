<%@ Page Language="C#" %>
<!--
 -  
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2017 OpenLink Software
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
<script runat="server">
	void Page_Load(Object sender, EventArgs e)
	{
		ControlCollection cc = ph.Controls;
		CheckBox chk = new CheckBox ();
		chk.Text = "Wow?";
		cc.Add (chk);

		cc.Add (new LiteralControl ("\n<br>\n"));
		HyperLink lnk = new HyperLink ();
		lnk.NavigateUrl = "http://www.go-mono.com";
		lnk.Text = "Mono project Home Page";
		lnk.Target="_top";
		cc.Add (lnk);
	}
</script>
<html>
<title>PlaceHolder with a CheckBox and a HyperLink added in Page_Load</title>
<body>
<form runat="server">
	<asp:PlaceHolder id="ph" runat="server"/>
</form>
</body>
</html>

