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
<%@ Import namespace="System.Reflection" %>
<%@ Register TagPrefix="Mono" Namespace="Mono.Controls" assembly="tabcontrol2" %>
<html>
<!-- You must compile tabcontrol2.cs and copy the dll to the output/ directory -->

<title>User Control tabcontrol2</title>
<script runat=server>
	private static int _clicked = 0;
	void Clicked (object o, EventArgs e)
	{
		uno.InnerText = String.Format ("Somebody pressed me {0} times.", ++_clicked);
	}

	private static int _txt_changed = 0;
	void txt_Changed (object sender, EventArgs e)
	{
		dos.InnerText = String.Format ("Text have changed {0} times.", ++_txt_changed);
	}
</script>

<body>
    <center>
        <h3>Test for Tabs user control (tabcontrol2.dll)</h3>
        <hr>
    </center>

    <form runat="server">
        <Mono:Tabs2 runat="server" id="tabs">
    	    <Mono:TabContent runat="server" label="Empty" />
    	    <Mono:TabContent runat="server" label="Image">
        	Hi there
        	<p>
        	<asp:Image id="im" runat="server"
        		AlternateText="Yes, again the dancing monkey"
        		ImageAlign="left"
        		ImageUrl="http://www.ximian.com/images/index/button-top.gif"/>
            </Mono:TabContent>
            <Mono:TabContent runat="server" Label="Form">
        	 <asp:Button id="btn"
        		Text="Submit"
        		OnClick="Clicked"
        		runat="server"/>
        	 <br>
        	 <span runat=server id="uno"/>
        	 <br>
        	 <span runat=server id="dos"/>
        	 <br>
        	 <asp:TextBox id="txt1" Text="You can write here." TextMode="MultiLine" 
		  OnTextChanged="txt_Changed" runat="server" rows=5 />
        	 <br>
            </Mono:TabContent>
        </Mono:Tabs2>
    </form>
</body>
</html>

