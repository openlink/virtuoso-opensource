<%@ Page Language="C#" %>
<!--
 -  
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2015 OpenLink Software
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
	void Button1_OnClick(object Source, EventArgs e)
	{
		HtmlButton button = (HtmlButton) Source;
		if (button.InnerText == "Enabled 1"){
			Span1.InnerHtml="You deactivated Button1";
			button.InnerText = "Disabled 1";
		}
		else {
			Span1.InnerHtml="You activated Button1";
			button.InnerText = "Enabled 1";
		}
	}

	</script>
</head>
<body>
	<h3>HtmlButton Sample</h3>
	<form id="ServerForm" runat="server">
		<button id=Button1 runat="server" OnServerClick="Button1_OnClick">
		Button1
		</button>
		&nbsp;
		<span id=Span1 runat="server" />
	</form>
</body>
</html>

