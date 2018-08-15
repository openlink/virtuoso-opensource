/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2018 OpenLink Software
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

OAT.TabData = {
	obj:false,
	move:function(event) {
		if (!OAT.TabData.obj && !OAT.TabData.win) { return; }
		var o = OAT.TabData.obj || OAT.TabData.win;
		var pos = OAT.Event.position(event);
		var parent = o.parent.options.dockElement;
		var is_in = OAT.TabData.inParent(pos,parent);
		is_in ? OAT.Dom.addClass(parent,"tab_signal") : OAT.Dom.removeClass(parent,"tab_signal");

		if (!OAT.TabData.obj) { return; }

		var x_ = event.clientX;
		var y_ = event.clientY;
		var dx = x_ - OAT.TabData.x;
		var dy = y_ - OAT.TabData.y;

		OAT.Dom.moveBy(o.ghost,dx,dy);

		OAT.TabData.x = x_;
		OAT.TabData.y = y_;

		/* check for moving out of parent */
		if (!is_in) { o.undock(event); }
	},

	up:function(event) {
		if (!OAT.TabData.obj ) { return; }
		var o = OAT.TabData.obj;
		OAT.TabData.obj = false;
		OAT.Dom.unlink(o.ghost);
		OAT.Dom.removeClass(o.parent.options.dockElement,"tab_signal");
	},

	x:0,
	y:0,

	checkWin:function(event) {
		if (!OAT.TabData.win) { return; }
		var o = OAT.TabData.win;
		OAT.TabData.win = false;
		var pos = OAT.Event.position(event);
		var parent = o.parent.options.dockElement;
		var is_in = OAT.TabData.inParent(pos,parent);
		if (is_in) { o.dock(); }
	},

	inParent:function(coords,parent) { /* is cursor in parent's rectangle? */
		var pos = OAT.Dom.position(parent);
		var dims = OAT.Dom.getWH(parent);
		return (coords[0] >= pos[0] && coords[0] <= pos[0]+dims[0] && coords[1] >= pos[1] && coords[1] <= pos[1]+dims[1]);
	}
}

OAT.TabPart = function(clicker, mover, parent) {
	var self = this;
	this.key = $(clicker);
	this.value = $(mover);
	this.window = false;
	this.parent = parent;
	this.dragStatus = 0; /* 0 standard state, 1 mouse pressed */

	this.activate = function() {
		if (self.window) { return; }
		parent.element.appendChild(self.value);
		/**/
		OAT.Dom.show(self.value);
		/**/
		OAT.Dom.addClass(self.key,"tab_selected");
	}

	this.deactivate = function() {
		if (self.window) { return; }
		// OAT.Dom.unlink(self.value);
		/**/
		OAT.Dom.hide(self.value);
		/**/
		OAT.Dom.removeClass(self.key,"tab_selected");
	}

	this.remove = function() {
		if (self.window) { self.dock(); }
	}

	this.initDrag = function(event) { /* prepare for ghost creation */
		if (self.dragStatus) { return; }
		self.dragStatus = 1;
		self.eventPos = [event.clientX,event.clientY];
	}

	this.startDrag = function(event) { /* create ghost */
		if (self.dragStatus != 1) { return; }
		self.dragStatus = 0;
		self.ghost = OAT.Dom.create("div",{position:"absolute"});
		OAT.Style.set(self.ghost,{opacity:0.5});
		self.ghost.appendChild(self.key.cloneNode(true));
		/* create right position */
		var pos = OAT.Dom.position(self.key);
		var dx = event.clientX - self.eventPos[0];
		var dy = event.clientY - self.eventPos[1];
		self.ghost.style.left = (pos[0]+dx)+"px";
		self.ghost.style.top = (pos[1]+dy)+"px";
		document.body.appendChild(self.ghost);
		OAT.Dom.removeSelection();

		OAT.TabData.x = event.clientX;
		OAT.TabData.y = event.clientY;
		OAT.TabData.obj = self;
	}

	this.dock = function() {
		OAT.TabData.win = false;

		self.parent.layers.removeLayer(self.window.div);
		OAT.Dom.unlink(self.window.div);
		self.window = false;
		OAT.Dom.hide(self.value);
		document.body.appendChild(self.value);

		OAT.Dom.removeClass(self.parent.options.dockElement,"tab_signal");

		/* try to reconstruct position of self.key */
		if (self.original.next && self.original.next.parentNode == self.original.parent) { /* next sibling available */
			self.original.parent.insertBefore(self.key,self.original.next);
		} else if (self.original.prev && self.original.prev.parentNode == self.original.parent) { /* prev sibling available */
			self.original.parent.insertBefore(self.key,self.original.prev.nextSibling);
		} else { /* fallback */
			self.original.parent.appendChild(self.key);
		}

		self.parent.go(self);
		self.parent.options.onDock(self.parent.tabs.find(self));
	}

	this.undock = function(event) {
		OAT.TabData.obj = false;
		OAT.Dom.unlink(self.ghost);

		/* remove key */
		self.original = {
			parent:self.key.parentNode,
			prev:self.key.previousSibling,
			next:self.key.nextSibling
		}
		OAT.Dom.unlink(self.key);

		/* create window */
		var pos = OAT.Event.position(event);
		var w = self.parent.options.dockWindowWidth;
		var h = self.parent.options.dockWindowHeight;
		var x = Math.max(0,pos[0]-w/2);
		var y = Math.max(0,pos[1]-10);
		self.window = new OAT.Window({close:1,title:self.key.innerHTML,width:w,height:h,x:Math.round(x),y:Math.round(y)});
		self.window.content.appendChild(self.value)
		self.window.onclose = self.dock;
		OAT.Dom.show(self.value);
		document.body.appendChild(self.window.div);
		OAT.Event.attach(self.window.move,"mousedown",function() { OAT.TabData.win = self; });
		OAT.Drag.initiate(event,self.window.move);
		OAT.TabData.win = self;

		/* add to layers */
		self.parent.layers.addLayer(self.window.div);

		/* tab */
		var si = self.parent.selectedIndex;
		var index = -1;
		if (self.parent.tabs[si] == self) { /* activate any other tab */
			for (var i=self.parent.tabs.length-1;i>=0;i--) {
				var t = self.parent.tabs[i];
				if (index == -1 && !t.window) { index = i; }
			}
			self.parent.go(index);
		}
		self.parent.options.onUnDock(self.parent.tabs.find(self));
	}

	OAT.Dom.addClass(self.key,"tab");
	OAT.Event.attach(self.key,"click",function(){ parent.go(self); });

	if (parent.options.dockMode) {
		OAT.Event.attach(self.key,"mousedown",self.initDrag);
		OAT.Event.attach(self.key,"mousemove",self.startDrag);
		OAT.Event.attach(self.key,"mouseup",function(){self.dragStatus = 0;});
	}
}

OAT.Tab = function(elm,optObj) {
	var self = this;

	this.options = {
		goCallback:function(oldIndex,newIndex){},
		onDock:function(index){},
		onUnDock:function(index){},
		dockMode:false,
		dockElement:false,
		dockWindowWidth:700,
		dockWindowHeight:400
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }
	self.options.dockElement = $(self.options.dockElement);
	/* cannot use dock mode when dock element is not set, or windowing not available */
	if (!self.options.dockElement || OAT.Loader.isLoaded("window") == -1) { self.options.dockMode = false; }

	this.tabs = [];
	this.element = $(elm);
	this.selectedIndex = -1;

	this.add = function(elm_1,elm_2) {
		var obj = new OAT.TabPart(elm_1,elm_2,self);
		self.tabs.push(obj);
		self.go(obj,true);
		return obj;
	};

	this.clear = function() {
		for (var i=0;i<self.tabs.length;i++) {
			var tab = self.tabs[i];
			tab.deactivate();
		}
	};

	this.go = function(something,forbidCallback) {
		self.clear();
		var index = (typeof(something) == "object" ? self.tabs.find(something) : something);
		if (index != -1) {
			self.tabs[index].activate();
			if (!forbidCallback) { self.options.goCallback(self.selectedIndex,index); }
		}
		self.selectedIndex = index;
	};

	this.remove = function(something) {
		var index = -1;
		if (something instanceof OAT.TabPart) {
			index = self.tabs.find(something);
		} else if (typeof(something) == "number") {
			index = something;
		} else {
			var e = $(something);
			for (var i=0;i<self.tabs.length;i++) {
				if (self.tabs[i].key == e) { index = i; }
			}
		}
		if (index == -1) { return; }

		var decreaseIndex = false;
		if (index < self.selectedIndex) { decreaseIndex = true; }
		if (index == self.selectedIndex) {
			decreaseIndex = true;
			if (index == self.tabs.length-1) {
				self.go(index-1);
				decreaseIndex = false;
			} else {
				self.go(index+1);
			}
		}
		self.tabs[index].remove();
		self.tabs.splice(index,1);
		if (decreaseIndex) { self.selectedIndex--; }
	};

	OAT.Dom.clear(self.element);

	if (self.options.dockMode) {
		self.layers = new OAT.Layers(100);
		OAT.Event.attach(document,"mousemove",OAT.TabData.move);
		OAT.Event.attach(document,"mouseup",OAT.TabData.up);
		OAT.Event.attach(document,"mouseup",OAT.TabData.checkWin);
	}
}
