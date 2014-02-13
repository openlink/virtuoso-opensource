<%@ Page Language = "C#" %>
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
<script runat="server">
	string [] msgs = new string [] { "hi!", "hello", "hola", 
					 "Ciao", "adios"};
</script>
<head>
<title>Code Render</title>
</head>
<body>
	<% for (int i = 0; i < 5; i++) {%>
	<%= msgs [i] %> message number <%= i %>.
	<p>
	<% } %>
	<form runat=server>
		<% for (int i = 4; i <= 0; i--) {%>
		<%= msgs [i] %> reverse message number <%= i %>.
		<% } %>
		<h3>One more calendar</h3>
		<asp:calendar id="Calendar1"
		Font-Name="Arial" showtitle="true"
		runat="server">
			<SelectedDayStyle BackColor="Blue" 
					ForeColor="Red"/>
			<TodayDayStyle BackColor="#CCAACC" 
					ForeColor="#000000"/>
		</asp:Calendar>

	</form>
	This should say hello: <%= msgs [1] %>
</body>
</html>

