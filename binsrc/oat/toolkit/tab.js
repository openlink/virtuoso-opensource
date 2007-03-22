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
	new OAT.Tab(element)
	Tab.add(clicker,window)
	Tab.go(index)
	Tab.remove(clicker);
	
	CSS: .tab, .tab_selected
*/

OAT.Tab = function(elm) {
	var self = this;
	
	this.keys = [];
	this.values = [];
	this.element = $(elm);
	this.div = this.element;
	this.selectedIndex = -1;
	this.goCallback = function(oldIndex,newIndex){};
	
	this.add = function(elm_1,elm_2) {
		var element_1 = $(elm_1);
		var element_2 = $(elm_2);
		OAT.Dom.addClass(element_1,"tab");
		var index = self.keys.length;
		
		this.keys.push(element_1);
		this.values.push(element_2);
		var ref=function() {
			self.goTo(element_1);
		}
		OAT.Dom.attach(element_1,"click",ref);
		self.go(index,true);
	};

	this.clear = function() {
		if (this.selectedIndex != -1) {
			OAT.Dom.hide(this.values[this.selectedIndex]);
			document.body.appendChild(this.values[this.selectedIndex]);
			OAT.Dom.removeClass(this.keys[this.selectedIndex],"tab_selected");
		}
	};

	this.goTo = function(clicker) {
		var index = self.keys.find(clicker);
		if (index == -1) { return; }
		self.go(index);
	};
	
	this.go = function(index,forbidCallback) {
		this.clear();
		if (index == -1) { return; }
		this.element.appendChild(this.values[index]);
		OAT.Dom.show(this.values[index]);
		OAT.Dom.addClass(this.keys[index],"tab_selected");
		if (!forbidCallback) { this.goCallback(this.selectedIndex,index); }
		this.selectedIndex = index;
	};
	
	this.remove = function(element) {
		var elm = $(element);
		var decreaseIndex = false;
		var index = self.keys.find(elm);
		if (index < self.selectedIndex) { decreaseIndex = true; }
		if (index == self.selectedIndex) {
			decreaseIndex = true;
			if (index == self.keys.length-1) {
				self.go(index-1);
				decreaseIndex = false;
			} else {
				self.go(index+1);
			}
		}
		self.keys.splice(index,1);
		self.values.splice(index,1);
		if (decreaseIndex) { self.selectedIndex--; }
	};
	
	OAT.Dom.clear(this.element); 
}
OAT.Loader.featureLoaded("tab");
