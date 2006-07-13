/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2006 Ondrej Zara and OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	t = new OAT.Toolbar();
	document.body.appendChild(t.div);
	
	var i = t.addIcon(twoStates,imagePath,tooltip,callback)  ---  callback(state)
	var s = t.addSeparator()
	alert(i.state) --- 0/1
	
	t.removeIcon(i)
	t.removeSeparator(s)
	
	
	CSS: .toolbar .toolbar_icon .toolbar_icon_down .toolbar_separator
*/

OAT.Toolbar = function() {

	var obj = this;
	this.div = OAT.Dom.create("div");
	this.div.className = "toolbar";
	this.icons = [];
	this.separators = [];
	
	this.addIcon = function(twoStates,imagePath,tooltip,callback) {
		var div = OAT.Dom.create("div");
		div.className = "toolbar_icon";
		div.title = tooltip;
		div.state = 0;
		
		var img = OAT.Dom.create("img");
		img.setAttribute("src",imagePath);
		div.appendChild(img);
		
		div.toggle = function(event) {
			div.state++;
			if (div.state > 1) { div.state = 0; }
			if (!twoStates) { div.state = 0; }
			div.className = (div.state ? "toolbar_icon toolbar_icon_down" : "toolbar_icon");
			callback(div.state);
		}
		OAT.Dom.attach(div,"click",div.toggle);
		this.div.appendChild(div);
		this.icons.push(div);
		return div;
	}
	
	this.addSeparator = function() {
		var div = OAT.Dom.create("div");
		div.className = "toolbar_separator";
		this.div.appendChild(div);
		this.separators.push(div);
		return div;
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
OAT.Loader.pendingCount--;
