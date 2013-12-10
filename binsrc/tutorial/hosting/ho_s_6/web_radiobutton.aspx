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
<title>RadioButton</title>
</head>
<body>
<form runat="server">
	<asp:RadioButton id="r1" Text="One" GroupName="group1" runat="server" Checked="True" />
	<br>
	<asp:RadioButton id="r2" Text="Two" GroupName="group1" runat="server"/>
	<br>
	<asp:RadioButton id="r3"  Text="Three" GroupName="group1" runat="server"/>
	<br>
	Here another group of radio buttons.
	<br>
	<asp:RadioButton id="r4" Text="Ein" GroupName="group2" runat="server"/>
	<br>
	<asp:RadioButton id="r5"  Text="Zwei" GroupName="group2" runat="server" checked="true"/>
	<br>
</form>
</body>
</html>
