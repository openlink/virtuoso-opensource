<%@ Page Language="C#" %>
<!--
 -  
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2016 OpenLink Software
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
<title>ListBox</title>
</head>
<body>
<form runat="server">
Single selection:
<p>
<asp:ListBox id="lbs" rows="5" SelectionMode="single" Width="80px" runat="server">
	<asp:ListItem>1</asp:ListItem>
	<asp:ListItem>2</asp:ListItem>
	<asp:ListItem>3</asp:ListItem>
	<asp:ListItem>4</asp:ListItem> 
	<asp:ListItem>5</asp:ListItem> 
	<asp:ListItem>6</asp:ListItem>
	<asp:ListItem>7</asp:ListItem>
	<asp:ListItem>8</asp:ListItem>
	<asp:ListItem>9</asp:ListItem> 
	<asp:ListItem>10</asp:ListItem> 
</asp:ListBox>
<p>
Multiple selection:
<p>
<asp:ListBox id="lbm" rows="5" SelectionMode="Multiple" Width="80px" runat="server">
	<asp:ListItem>1</asp:ListItem>
	<asp:ListItem>2</asp:ListItem>
	<asp:ListItem>3</asp:ListItem>
	<asp:ListItem>4</asp:ListItem> 
	<asp:ListItem>5</asp:ListItem> 
	<asp:ListItem>6</asp:ListItem>
	<asp:ListItem>7</asp:ListItem>
	<asp:ListItem>8</asp:ListItem>
	<asp:ListItem>9</asp:ListItem> 
	<asp:ListItem>10</asp:ListItem> 
</asp:ListBox>
</form>
</body>
</html>

