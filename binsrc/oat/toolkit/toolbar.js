/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2008 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	t = new OAT.Toolbar(div);
	
	var i = t.addIcon(twoStates,imagePath,tooltip,callback)  ---  callback(state)
	var s = t.addSeparator()
	alert(i.state) --- 0/1
	
	t.removeIcon(i)
	t.removeSeparator(s)
	
	
	CSS: .toolbar .toolbar_icon .toolbar_icon_down .toolbar_separator
*/

OAT.Toolbar = function(div,optObj) {
	var self = this;
	this.options = {
		labels:false
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }
	
	this.div = $(div);
	OAT.Dom.addClass(this.div,"toolbar");
	this.icons = [];
	this.separators = [];
	
	this.addIcon = function(twoStates,imagePath,tooltip,callback) {
		var div = OAT.Dom.create("div",{},"toolbar_icon");
		div.title = tooltip;
		div.state = 0;
		
		var img = OAT.Dom.create("img");
		img.src = imagePath;
		
		div.toggleState = function(newState) {
			div.state = newState;
			if (div.state) { 
				OAT.Dom.addClass(div,"toolbar_icon_down"); 
			} else {
				OAT.Dom.removeClass(div,"toolbar_icon_down"); 
			}
			callback(div.state);
		}
		
		div.toggle = function(event) {
			var nstate = div.state+1;
			if (nstate > 1) { nstate = 0; }
			if (!twoStates) { nstate = 0; }
			div.toggleState(nstate);
		}
		
		OAT.Dom.attach(div,"click",div.toggle);
		OAT.Dom.append([div,img],[self.div,div]);
		
		if (self.options.labels) {
			div.appendChild(OAT.Dom.text(tooltip));
		}
		
		self.icons.push(div);
		return div;
	}
	
	this.addSeparator = function() {
		var div = OAT.Dom.create("div",{},"toolbar_separator");
		self.div.appendChild(div);
		self.separators.push(div);
		return div;
	}
	
	this.removeIcon = function(div) {
		var index = self.icons.find(div);
		self.icons.splice(index,1);
	}

	this.removeSeparator = function(div) {
		var index = self.separators.find(div);
		this.separators.splice(index,1);
	}
	
}
OAT.Loader.featureLoaded("toolbar");
