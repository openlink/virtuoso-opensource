//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2015 OpenLink Software
//  
//  This project is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the
//  Free Software Foundation; only version 2 of the License, dated June 1991.
//  
//  This program is distributed in the hope that it will be useful, but
//  WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
//  General Public License for more details.
//  
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
//  
//  
//
// tabcontrol2.cs: sample user control.
//

using System;
using System.Collections;
using System.Web.UI;
using System.Web.UI.HtmlControls;
using System.Web.UI.WebControls;

namespace Mono.Controls
{
	[ParseChildren(false)]
	public class TabContent : Control
	{
		string label;

		public TabContent ()
		{
		}

		protected override void Render (HtmlTextWriter writer)
		{
			if (this.Parent.GetType () != typeof (Tabs2))
				throw new ApplicationException ("TabContent can only be rendered inside Tabs2");
			base.Render (writer);
		}
		
		public string Label
		{
			get {
				if (label == null)
					return "* You did not set a label for this control *";
				return label;
			}

			set {
				label = value;
			}
		}
	}

	[ParseChildren(false)]
	public class Tabs2 : UserControl, IPostBackEventHandler, IParserAccessor
	{
		Hashtable localValues;
		ArrayList titles;

		public Tabs2 ()
		{
			titles = new ArrayList ();
			localValues = new Hashtable ();
		}

		private void AddTab (TabContent tabContent)
		{
			string title = tabContent.Label;
			Controls.Add (tabContent);
			titles.Add (title);
			if (Controls.Count == 1)
				CurrentTabName = title;
		}

		protected override object SaveViewState ()
		{
			return new Triplet (base.SaveViewState (), localValues, titles);
		}
		
		protected override void LoadViewState (object savedState)
		{
			if (savedState != null) {
				Triplet saved = (Triplet) savedState;
				base.LoadViewState (saved.First);
				localValues = saved.Second as Hashtable;
				titles = saved.Third as ArrayList;
			}
		}
		
		protected override void OnPreRender (EventArgs e)
		{
			base.OnPreRender (e);
			Page.GetPostBackEventReference (this);
			foreach (TabContent content in Controls) {
				if (content.Label  == CurrentTabName)
					content.Visible = true;
				else
					content.Visible = false;
			}
		}

		void IPostBackEventHandler.RaisePostBackEvent (string argument)
		{
			if (argument == null)
				return;

			if (CurrentTabName != argument)
				CurrentTabName = argument;
		}

		protected override ControlCollection CreateControlCollection ()
		{
			return new ControlCollection (this);
		}
		
		protected override void AddParsedSubObject (object obj)
		{
			if (obj is LiteralControl)
				return; // Ignore plain text

			if (!(obj is TabContent))
				throw new ArgumentException ("Tabs2 Only allows TabContent controls inside.",
							     "obj");
			
			AddTab ((TabContent) obj);
		}
		
		void IParserAccessor.AddParsedSubObject (object obj)
		{
			AddParsedSubObject (obj);
		}

		private void RenderBlank (HtmlTextWriter writer)
		{
			writer.WriteBeginTag ("td");
			writer.WriteAttribute ("bgcolor", TabBackColor);
			writer.WriteAttribute ("width", BlankWidth.ToString ());
			writer.Write (">");
			writer.Write ("&nbsp;");
			writer.WriteEndTag ("td");
		}

		private void RenderTabs (HtmlTextWriter writer)
		{
			writer.WriteBeginTag ("tr");
			writer.Write (">");
			writer.WriteLine ();

			if (titles.Count > 0)
				RenderBlank (writer);
			string currentTab = CurrentTabName;
			string key;
			int end = titles.Count;
			for (int i = 0; i < end; i++) {
				key = (string) titles [i];
				writer.WriteBeginTag ("td");
				writer.WriteAttribute ("width", Width.ToString ());
				writer.WriteAttribute ("align", Align.ToString ());
				if (key == currentTab) {
					writer.WriteAttribute ("bgcolor", CurrentTabBackColor);
					writer.Write (">");
					writer.WriteBeginTag ("font");
					writer.WriteAttribute ("color", CurrentTabColor);
					writer.Write (">");
					writer.Write (key);
					writer.WriteEndTag ("font");
				} else {
					writer.WriteAttribute ("bgcolor", TabBackColor);
					writer.Write (">");
					writer.WriteBeginTag ("a");
					string postbackEvent = String.Empty;
					if (Page != null)
						postbackEvent = Page.GetPostBackClientHyperlink (
									this, key);

					writer.WriteAttribute ("href", postbackEvent);
					writer.Write (">");
					writer.Write (key);
					writer.WriteEndTag ("a");
				}
				writer.WriteEndTag ("td");
				RenderBlank (writer);
				writer.WriteLine ();
			}

			writer.WriteEndTag ("tr");
			writer.WriteBeginTag ("tr");
			writer.Write (">");
			writer.WriteLine ();
			writer.WriteBeginTag ("td");
			writer.WriteAttribute ("colspan", "10");
			writer.WriteAttribute ("bgcolor", CurrentTabBackColor);
			writer.Write (">");
			writer.WriteBeginTag ("img");
			writer.WriteAttribute ("width", "1");
			writer.WriteAttribute ("height", "1");
			writer.WriteAttribute ("alt", "");
			writer.Write (">");
			writer.WriteEndTag ("td");
			writer.WriteEndTag ("tr");
		}
		
		protected override void Render (HtmlTextWriter writer)
		{
			if (Page != null)
				Page.VerifyRenderingInServerForm (this);

			if (Controls.Count == 0)
				return;

			writer.WriteBeginTag ("table");
			writer.WriteAttribute ("border", "0");
			writer.WriteAttribute ("cellpadding", "0");
			writer.WriteAttribute ("cellspacing", "0");
			writer.Write (">");
			writer.WriteBeginTag ("tbody");
			writer.Write (">");
			writer.WriteLine ();
			RenderTabs (writer);
			writer.WriteEndTag ("tbody");
			writer.WriteEndTag ("table");
			writer.WriteLine ();
			base.RenderChildren (writer);
		}

		public int BlankWidth
		{
			get { 
				object o = localValues ["BlankWidth"];
				if (o == null)
					return 15;
				return (int) o;
			}
			set {
				localValues ["BlankWidth"] = value;
			}
		}

		public int Width
		{
			get { 
				object o = localValues ["Width"];
				if (o == null)
					return 120;
				return (int) o;
			}
			set {
				localValues ["Width"] = value;
			}
		}

		public string Align
		{
			get { 
				object o = localValues ["Align"];
				if (o == null)
					return "center";
				return (string) o;
			}
			set {
				localValues ["Align"] = value;
			}
		}

		public string CurrentTabName
		{
			get {
				object o = localValues ["CurrentTabName"];
				if (o == null)
					return String.Empty;
				return (string) localValues ["CurrentTabName"];
			}

			set {
				localValues ["CurrentTabName"] = value;
			}
		}

		public string CurrentTabColor
		{
			get {
				object o = localValues ["CurrentTabColor"];
				if (o == null)
					return "#FFFFFF";
				return (string) localValues ["CurrentTabColor"];
			}

			set {
				localValues ["CurrentTabColor"] = value;
			}
		}

		public string CurrentTabBackColor
		{
			get {
				object o = localValues ["CurrentTabBackColor"];
				if (o == null)
					return "#3366CC";
				return (string) localValues ["CurrentTabBackColor"];
			}

			set {
				localValues ["CurrentTabBackColor"] = value;
			}
		}

		public string TabBackColor
		{
			get {
				object o = localValues ["TabBackColor"];
				if (o == null)
					return "#efefef";
				return (string) localValues ["TabBackColor"];
			}

			set {
				localValues ["TabBackColor"] = value;
			}
		}
	}
}

