<%@ language="C#" %>
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
<script runat=server>
	void txt_Changed (object sender, EventArgs e)
	{
	}
</script>
<head>
<title>TextBox: MultiLine, SingleLine and Password</title>
</head>
<body>
<form runat="server">
Multiline:
<br>
<asp:TextBox id="txt1" Text="multiline" TextMode="MultiLine" OnTextChanged="txt_Changed" runat="server" rows=5 />
<br>
Single:
<br>
<asp:TextBox id="txt2" Text="singleline" TextMode="singleLine" OnTextChanged="txt_Changed" runat="server" maxlength=40 />
<br>
Password:
<br>
<asp:TextBox id="txt3" Text="badifyouseethis" TextMode="password" OnTextChanged="txt_Changed" runat="server" maxlength=15 />
<br>
</form>
</body>
</html>

