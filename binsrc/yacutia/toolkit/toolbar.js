/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
 *  
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *  
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *  
 *  
*/
/*
	t = new Toolbar();
	document.body.appendChild(t.div);
	
	var i = t.addIcon(twoStates,imagePath,tooltip,callback)  ---  callback(state)
	var s = t.addSeparator()
	alert(i.state) --- 0/1
	
	t.removeIcon(i)
	t.removeSeparator(s)
	
	
	CSS: .toolbar .toolbar_icon .toolbar_icon_down .toolbar_separator
*/

function Toolbar() {

	var obj = this;
	this.div = Dom.create("div");
	this.div.className = "toolbar";
	this.icons = [];
	this.separators = [];
	
	this.addIcon = function(twoStates,imagePath,tooltip,callback) {
		var div = Dom.create("div");
		div.className = "toolbar_icon";
		div.title = tooltip;
		div.state = 0;
		
		var img = Dom.create("img");
		img.setAttribute("src",imagePath);
		div.appendChild(img);
		
		var ref = function(event) {
			div.state++;
			if (div.state > 1) { div.state = 0; }
			if (!twoStates) { div.state = 0; }
			div.className = (div.state ? "toolbar_icon toolbar_icon_down" : "toolbar_icon");
			callback(div.state);
		}
		Dom.attach(div,"click",ref);
		this.div.appendChild(div);
		this.icons.push(div);
	}
	
	this.addSeparator = function() {
		var div = Dom.create("div");
		div.className = "toolbar_separator";
		this.div.appendChild(div);
		this.separators.push(div);
	}
	
	this.removeIcon = function(div) {
		var index = -1;
		for (var i=0;i<this.icons.length;i++) if (this.icons[i] == div) { index = i; }
		this.icons.splice(index,1);
	}

	this.removeSeparator = function(div) {
		var index = -1;
		for (var i=0;i<this.separators.length;i++) if (this.separators[i] == div) { index = i; }
		this.separators.splice(index,1);
	}
	
}
