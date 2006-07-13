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
	m = new OAT.Menu()
	m.closeFilter = className
	m.moCloseFilter = className
	m.createFromUL(ul)

*/

OAT.MenuItem = function(menu,parent,li,ul) {
	var self = this;
	this.items = [];
	this.li = li;
	this.ul = ul;
	this.parent = parent;
	this.state = 1;
	
	this.open = function() {
		/* close all siblings */
		for (var i=0;i<self.parent.items.length;i++) { self.parent.items[i].close(); }
		/* do something */
		if (self.ul) { OAT.Dom.show(ul); }
		self.state = 1;
	}
	
	this.close = function() {
		if (!self.ul) { return; } /* don't close leaves */
		/* close all children prior to closing parent */
		for (var i=0;i<self.items.length;i++) { self.items[i].close(); }
		/* do something */
		if (self.li) { OAT.Dom.hide(self.ul); } /* hide if not zero level */
		self.state = 0;
	}
	
	this.addLis = function() {
		if (!this.ul) { return; }
		var lis = menu.namedDirectChildren(this.ul,"li");
		for (var i=0;i<lis.length;i++) {
			var li = lis[i];
			var uls = menu.namedDirectChildren(li,"ul"); /* we expect max. 1 ul */
			var ul = (uls.length ? uls[0] : false);
			var me = new OAT.MenuItem(menu,self,li,ul);
			self.items.push(me);
			me.addLis();
		}
	}
	
	
	if (!self.parent.li) { /* 1st level */
		var overRef = function(event) {
			var hope = 0;
			for (var i=0;i<self.parent.items.length;i++) {
				var it = self.parent.items[i];
				if (it != self && it.state) { hope = 1; }
			}
			if (hope) { self.open(); }
		}
		var clickRef = function(event) {
			var src = OAT.Dom.source(event);
			if (src != self.li) { return; }
			if (self.state) { self.close(); } else { self.open(); }
		}
		OAT.Dom.attach(self.li,"mouseover",overRef);
		OAT.Dom.attach(self.li,"click",clickRef);
		
	} else {
		var overRef = function(event) {
			self.open();
		}
		var clickRef = function(event) {
			var src = OAT.Dom.source(event);
			if (src != self.li) { return; }
			if (OAT.Dom.isClass(self.li,menu.closeFilter) && !OAT.Dom.isClass(self.li,menu.noCloseFilter)) {
				menu.root.close();
			}
		}
		OAT.Dom.attach(self.li,"mouseover",overRef);
		OAT.Dom.attach(self.li,"click",clickRef);
	}
}

OAT.Menu = function() {

	var self = this;
	this.closeFilter = "*"; /* by default, clicking any element closes menu */
	this.noCloseFilter = ""; /* by default, there are no 'deaf' elements */
	
	var downRef = function(event) {
		var src = OAT.Dom.source(event);
		/* close if clicked element is not child of any top level li's */
		if (!OAT.Dom.isChild(src,self.root.ul)) { self.root.close(); }
	}
	OAT.Dom.attach(document,"mousedown",downRef);
	
	this.createFromUL = function(elm) { /* manage whole ul tree */
		var ul = $(elm);
		self.root = new OAT.MenuItem(self,false,false,ul);
		self.root.addLis();
		self.root.close();
	}

	this.namedDirectChildren = function(node,tagName) {
		var arr = [];
		var ch = node.childNodes;
		for (var i=0;i<ch.length;i++) {
			if (ch[i].tagName && ch[i].tagName.toLowerCase() == tagName) { arr.push(ch[i]); }
		}
		return arr;
	}
	
/*
	
	this.showStart = function(o) {
		var elm = o.openElm;
		elm._Menu_pendingIn = 1;
		elm._Menu_pendingOut = 0;
		if (o.state) { return; }
		var callback = function() {
			if (!elm._Menu_pendingIn) { return; }
			o.state = 1;
			elm._Menu_pendingIn = 0;
			obj.show(elm);
		}
		setTimeout(callback,obj.delay);
	}
	
	this.hideStart = function(o) {
		var elm = o.openElm;
		elm._Menu_pendingOut = 1;
		elm._Menu_pendingIn = 0;
		if (!o.state) { return; }
		var callback = function() {
			if (!elm._Menu_pendingOut) { return; }
			o.state = 0;
			elm._Menu_pendingOut = 0;
			obj.hide(elm);
		}
		setTimeout(callback,obj.delay);
	}
	
	this.show = function(elm) { 
		switch (obj.animation) {
			case MenuData.ANIM_FADE: var as = OAT.AnimationStructure.generate(elm,OAT.AnimationData.FADEIN,{}); break;
			case MenuData.ANIM_RESIZE: 
				var dim = elm._Menu_savedDimensions;
				var as = OAT.AnimationStructure.generate(elm,OAT.AnimationData.RESIZE,{w:dim[0],h:dim[1],dist:10}); 
			break;
				
		}
		if (obj.animation) {
			var a = new OAT.Animation(as,obj.speed);
			if (obj.animation == MenuData.ANIM_RESIZE) { a.endFunction = function() { elm.style.overflow = "visible"; } }
			a.start();
		}
		elm.style.visibility = "visible";
	}
	
	this.hide = function(elm) { 
		case MenuData.ANIM_FADE: var as = OAT.AnimationStructure.generate(elm,OAT.AnimationData.FADEOUT,{}); break;
			case MenuData.ANIM_RESIZE: var as = OAT.AnimationStructure.generate(elm,OAT.AnimationData.RESIZE,{w:0,h:0,dist:10}); break;
		}
		if (obj.animation) {
			var a = new OAT.Animation(as,obj.speed);
			a.endFunction = function() { elm.style.visibility = "hidden"; }
			if (obj.animation == MenuData.ANIM_RESIZE) { elm.style.overflow = "hidden"; }
			a.start();
		} else { elm.style.visibility = "hidden"; }
	}

	this.hideQuick = function(elm) {
		elm.style.visibility = "hidden";
		elm.style.opacity = 0;
		elm.filter = "alpha(opacity=0);";
	}*/
}
OAT.Loader.pendingCount--;
