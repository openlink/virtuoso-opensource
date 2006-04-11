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
	m = new Menu(type,delay,animation,speed)
	m.setCloseFilter(className)
	m.setNoCloseFilter(className)
	m.addLevel(clicker,opener,deep)
	m.createFromUL(ul)

	MenuData.TYPE_CLICK
	MenuData.TYPE_HOVER
	MenuData.ANIM_NONE
	MenuData.ANIM_FADE
	MenuData.ANIM_RESIZE
*/

var MenuData = {
	TYPE_CLICK:1,
	TYPE_HOVER:2,
	ANIM_NONE:0,
	ANIM_FADE:1,
	ANIM_RESIZE:2
}

function Menu(type,delay,animation,speed) {
	var obj = this;
	this.type = type;
	this.levels = [];
	this.delay = delay;
	this.animation = animation;
	this.speed = speed;
	this.state = 0;
	this.closeFilter = "*"; /* by default, clicking any element closes menu */
	this.noCloseFilter = ""; /* by default, there are no 'deaf' elements */
	
	this.setCloseFilter = function(className) {
		this.closeFilter = className;
	}
	
	this.setNoCloseFilter = function(className) {
		this.noCloseFilter = className;
	}
	
	this.tryCloser = function(elm) {
		var callback = function(event) {
			var src = Dom.source(event);
			if (src != elm) { return; }
			obj.hideAll();
			obj.state = 0;
		}
		if (Dom.isClass(elm,this.closeFilter) && !Dom.isClass(elm,this.noCloseFilter)) {
			Dom.attach(elm,"click",callback);
		}
	}
	
	this.assign = function(o) { /* manage event attachments */
		if (o.activation == MenuData.TYPE_CLICK) {
			var overRef = function(event) {
				if (obj.state && !o.state) {
					obj.hideAll(event);
					obj.showStart(o);
				}
			}
			var clickRef = function(event) {
				var src = Dom.source(event);
				if (src != o.clickElm) { return; }
				obj.state = (obj.state ? 0 : 1);
				if (obj.state) { obj.showStart(o); } else { obj.hideStart(o); }
			}
			var globalRef = function(event) {
				if (!o.state) { return; }
				var elm = Dom.source(event);
				while (elm != document.body && elm != document) {
					if (elm == o.clickElm) { return; }
					elm = elm.parentNode;
				}
				obj.state = 0;
				obj.hideStart(o);
			}
			Dom.attach(o.clickElm,"mouseover",overRef);
			Dom.attach(o.clickElm,"click",clickRef);
			Dom.attach(document,"click",globalRef);
		} /* if activated by click */
		if (o.activation == MenuData.TYPE_HOVER) {
			var overRef = function(event) { obj.showStart(o); }
			var outRef = function(event) { obj.hideStart(o); }
			Dom.attach(o.clickElm,"mouseover",overRef);
			Dom.attach(o.clickElm,"mouseout",outRef);
		}
		/* elements which may close menu by clicking */
		var children = o.openElm.childNodes;
		for (var i=0;i<children.length;i++) {
			var elm = children[i];
			this.tryCloser(elm);
		}
		obj.hideQuick(o.openElm);
	}
	
	this.addLevel = function(clicker,opener,deep) { /* add clicker-opener functionality */
		var clickElm = $(clicker);
		var openElm = $(opener);
		var o = {};
		o.clickElm = clickElm;
		o.openElm = openElm;
		o.activation = (this.type == MenuData.TYPE_CLICK && !deep ? MenuData.TYPE_CLICK : MenuData.TYPE_HOVER);
		o.state = 0;
		o.showing = 0;
		o.hiding = 0;
		this.levels.push(o);
		this.assign(o);
	}
	
	this.namedDirectChildren = function(node,tagName) {
		var arr = [];
		var ch = node.childNodes;
		for (var i=0;i<ch.length;i++) {
			if (ch[i].tagName && ch[i].tagName.toLowerCase() == tagName) { arr.push(ch[i]); }
		}
		return arr;
	}
	
	this.createFromUL = function(elm,d) { /* manage whole ul tree */
		var ul = $(elm);
		var lis = this.namedDirectChildren(ul,"li");
		var depth = (d ? 1 : 0);
		for (var i=0;i<lis.length;i++) {
			var uls = this.namedDirectChildren(lis[i],"ul");
			for (var j=0;j<uls.length;j++) {
				this.addLevel(lis[i],uls[j],depth);
				this.createFromUL(uls[j],depth+1);
			}
		}
	}
	
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
	
	this.show = function(elm) { /* show submenu */
		switch (obj.animation) {
			case MenuData.ANIM_FADE: var as = AnimationStructure.generate(elm,AnimationData.FADEIN,{}); break;
			case MenuData.ANIM_RESIZE: 
				var dim = elm._Menu_savedDimensions;
				var as = AnimationStructure.generate(elm,AnimationData.RESIZE,{w:dim[0],h:dim[1],dist:10}); 
			break;
				
		}
		if (obj.animation) {
			var a = new Animation(as,obj.speed);
			if (obj.animation == MenuData.ANIM_RESIZE) { a.endFunction = function() { elm.style.overflow = "visible"; } }
			a.start();
		}
		elm.style.visibility = "visible";
	}
	
	this.hide = function(elm) { /* hide submenu */
		switch (obj.animation) {
			case MenuData.ANIM_FADE: var as = AnimationStructure.generate(elm,AnimationData.FADEOUT,{}); break;
			case MenuData.ANIM_RESIZE: var as = AnimationStructure.generate(elm,AnimationData.RESIZE,{w:0,h:0,dist:10}); break;
		}
		if (obj.animation) {
			var a = new Animation(as,obj.speed);
			a.endFunction = function() { elm.style.visibility = "hidden"; }
			if (obj.animation == MenuData.ANIM_RESIZE) { elm.style.overflow = "hidden"; }
			a.start();
		} else { elm.style.visibility = "hidden"; }
	}

	this.hideQuick = function(elm) { /* hide without eye candy */
		elm.style.visibility = "hidden";
		switch (obj.animation) {
			case MenuData.ANIM_FADE:
				elm.style.opacity = 0;
				elm.filter = "alpha(opacity=0);";
			break;
			case MenuData.ANIM_RESIZE:
				if (!elm._Menu_savedDimensions) {
					var dim = Dom.getWH(elm);
					elm._Menu_savedDimensions = dim;
					elm.style.width = "0px";
					elm.style.height = "0px"; 
					elm.style.overflow = "hidden";
				}
			break;
		}
	}
	
	this.hideAll = function(event) { /* collapse whole menu - when someone clicked */
		for (var i=0;i<obj.levels.length;i++) { 
			obj.levels[i].state = 0;
			obj.hideQuick(obj.levels[i].openElm);
		}
	}
}