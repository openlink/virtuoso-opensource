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
<%@ Import namespace="System.Reflection" %>
<%@ Register TagPrefix="Mono" NAmespace="Mono.Controls" assembly="tabcontrol" %>
<html>
<!-- You must compile tabcontrol.cs and copy the dll to the output/ directory -->

<title>User Control 2</title>
<script runat="server">
	PropertyInfo [] props = null;
	private void EnsureProps ()
	{
		if (props == null) {
			Type t = tabs.GetType ();
			PropertyInfo [] pi = t.GetProperties ();
			int count = 0;
			foreach (PropertyInfo p in pi) {
				if (p.DeclaringType == t)
					count++;
			}

			props = new PropertyInfo [count];
			count = 0;
			foreach (PropertyInfo p in pi) {
				if (p.DeclaringType == t) {
					props [count] = p;
					count++;
				}
			}
		}

	}
	
	void Page_Init (object sender, EventArgs e)
	{
		AddToPlaceHolder ();
	}

	void Page_Load (object sender, EventArgs e)
	{
		if (!IsPostBack)
			UpdateValues ();
	}
	
	private void AddToPlaceHolder ()
	{
		EnsureProps ();
		place.Controls.Clear ();
		foreach (PropertyInfo prop in props) {
			TextBox t = new TextBox ();
			t.ID = "_" + prop.Name;
			t.TextChanged += new EventHandler (PropChanged);
			place.Controls.Add (new LiteralControl (prop.Name + ": "));
			place.Controls.Add (t);
			place.Controls.Add (new LiteralControl ("<p>"));
		}
	}

	private PropertyInfo GetPropInfo (string name)
	{
		EnsureProps ();
		PropertyInfo prop = null;
		foreach (PropertyInfo p in props) {
			if (0 == String.Compare (p.Name, name, true)) {
				prop = p;
				break;
			}
		}
		return prop;
	}

	private object GetPropertyValue (string propName)
	{
		PropertyInfo prop = GetPropInfo (propName);
		MethodInfo method = prop.GetGetMethod ();
		return method.Invoke (tabs, null).ToString ();
	}

	private void SetPropertyValue (string propName, object value)
	{
		PropertyInfo prop = GetPropInfo (propName);
		object new_value;
		if (prop.PropertyType == typeof (string)) {
			new_value = value;
		} else if (prop.PropertyType == typeof (int)) {
			new_value = Int32.Parse ((string) value);
		} else {
			//???
			Console.WriteLine ("Surprise!!!");
			new_value = "";
		}
		MethodInfo method = prop.GetSetMethod ();
		method.Invoke (tabs, new object [] {new_value});
	}

	private void UpdateValues ()
	{
		foreach (Control t in place.Controls) {
			if (t is TextBox)
				((TextBox) t).Text = (string) GetPropertyValue (t.ID.Substring (1));
		}
	}
	
	void SubmitClicked (object sender, EventArgs events)
	{
		if (name.Text == String.Empty)
			return;

		try {
			tabs.AddTab (name.Text, url.Text);
			name.Text = "";
			url.Text = "";
			UpdateValues ();
		} catch (Exception e) {
		}
	}

	void PropChanged (object sender, EventArgs events)
	{
		TextBox s = sender as TextBox;
		if (s == null)
			return;

		SetPropertyValue (s.ID.Substring (1), s.Text);
	}
</script>
<body>
<center>
<h3>Test for Tabs user control (tabcontrol.dll)</h3>
<hr>
</center>
<form runat="server">
<asp:Label id="msg" />
<table>
<tbody>
<tr>
<td width="50%">
<font size=+1>Enter label name and link to add:</font><p>
Name: <asp:TextBox runat="server" id="name" Text="OpenLink" />
<p>
Link: <asp:TextBox runat="server" id="url" Text="http://www.openlinksw.com"/>
<p>
</td>
<td>
<font size=+1>Changes on this values will affect properties of the user control:</font><p>
<asp:PlaceHolder id="place" runat="server" />
</td>
</tr>
</tbody>
</table>
<hr>
<Mono:Tabs runat="server" id="tabs"/>
</form>
</body>
</html>

