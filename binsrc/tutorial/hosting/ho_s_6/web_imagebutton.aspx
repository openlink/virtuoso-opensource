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
	void Clicked (object o, ImageClickEventArgs e)
	{
		// e.X -> x coordinate of the click
		// e.Y -> y coordinate of the click
	}
</script>
<title>ImageButton</title>
</head>
<body>
<form runat="server">
<asp:ImageButton id="imgButton" AlternateText="Image button" 
OnClick="Clicked" ImageUrl="http://virtuoso.openlinksw.com/images/openlink150.gif" 
ImageAlign="left" runat="server"/>
</form>
</body>
</html>

