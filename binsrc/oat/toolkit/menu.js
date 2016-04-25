/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2016 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	m = new OAT.Menu()
	m.closeFilter = className
	m.noCloseFilter = className
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
		for (var i=0;i<self.parent.items.length;i++) {
			if (self.parent.items[i]!=self)
				self.parent.items[i].close();
		}
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
			/*
			 * var src = OAT.Event.source(event);
			 * if (src != self.li) { return; }
			 */
			if (self.state) { self.close(); } else { self.open(); }
		}
		OAT.Event.attach(self.li,"mouseover",overRef);
		OAT.Event.attach(self.li,"click",clickRef);

	} else {
		var overRef = function(event) {
			self.open();
		}
		var clickRef = function(event) {
			OAT.Event.cancel(event);
			/*
			var src = OAT.Event.source(event);
			if (src != self.li) { return; }
			*/
			if (OAT.Dom.isClass(self.li,menu.closeFilter) && !OAT.Dom.isClass(self.li,menu.noCloseFilter)) {
				menu.root.close();
			}
		}
		OAT.Event.attach(self.li,"mouseover",overRef);
		OAT.Event.attach(self.li,"click",clickRef);
	}
}

OAT.Menu = function() {

	var self = this;
	this.closeFilter = "*"; /* by default, clicking any element closes menu */
	this.noCloseFilter = ""; /* by default, there are no 'deaf' elements (separators) */

	var downRef = function(event) {
		var src = OAT.Event.source(event);
		/* close if clicked element is not child of any top level li's */
		if (!OAT.Dom.isChild(src,self.root.ul)) { self.root.close(); }
	}
	OAT.Event.attach(document,"mousedown",downRef);

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

}
