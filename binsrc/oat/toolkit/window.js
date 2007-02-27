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
	exports: div, content, closeBtn, minBtn, maxBtn, move, caption, anchorTo, resizeTo
*/

OAT.WindowData = {
	TYPE_WIN:1,
	TYPE_MAC:2,
	TYPE_ROUND:3,
	TYPE_RECT:4,
	TYPE_AUTO:5
}

OAT.Window = function(optObj,type) {
	var self = this;

	/* get window type */
	var t;
	var autotype = (OAT.Dom.isMac() ? 2 : 1); /* automatic */

	if (type && type != OAT.WindowData.TYPE_AUTO) { t = type; } else { t = autotype; } /* if specified, get specified */
	if (OAT.Preferences.windowTypeOverride) { t = OAT.Preferences.windowTypeOverride; } /* if override, get overriding type */
	if (t == OAT.WindowData.TYPE_AUTO) { t = autotype; }
	var obj = false;
	switch (t) {
		case OAT.WindowData.TYPE_WIN:
			var obj = new OAT.MsWin(optObj);
		break;
		case OAT.WindowData.TYPE_MAC:
			var obj = new OAT.MacWin(optObj);
		break;
		case OAT.WindowData.TYPE_ROUND:
			var obj = new OAT.RoundWin(optObj);
		break;
		case OAT.WindowData.TYPE_RECT:
			var obj = new OAT.RectWin(optObj);
		break;
	}
	if (!obj) { return; }

	/* inherit properties */
	this.div = obj.div;
	this.content = obj.content;
	this.move = obj.move;
	this.caption = obj.caption;
	this.minBtn = obj.minBtn;
	this.maxBtn = obj.maxBtn;
	this.closeBtn = obj.closeBtn;
	this.resize = obj.resize;
	this.resizeTo = obj.resizeTo;
	this.anchorTo = obj.anchorTo;
	/* methods */
	this.onclose = function(){};
	this.onmax = function(){};
	this.onmin = function(){};
	if (this.closeBtn) { OAT.Dom.attach(this.closeBtn,"click",function(){self.onclose();}); }
	if (this.minBtn) { OAT.Dom.attach(this.minBtn,"click",function(){self.onmin();}); }
	if (this.maxBtn) { OAT.Dom.attach(this.maxBtn,"click",function(){self.onmax();}); }
	
	/* trick for easy stacking? need to be thoroughly tested.. */
	var upRef = function(event) {
		if (!obj.div.parentNode) { return; }
		obj.div.parentNode.appendChild(obj.div);
	}
//	OAT.Dom.attach(obj.div,"click",upRef);
}

OAT.WindowParent = function(obj,optObj) { /* abstract parent for all window implementations */
	obj.options = {
		close:1,
		resize:1,
		move:1,
		x:10,
		y:10,
		width:160,
		height:50,
		title:"",
		imagePath:OAT.Preferences.imagePath
	}

	for (var p in optObj) {	obj.options[p] = optObj[p]; }
	
	obj.div = false;
	obj.content = false;
	obj.move = false;
	obj.caption = false;
	obj.closeBtn = false;
	obj.minBtn = false;
	obj.maxBtn = false;
	
	obj.div = OAT.Dom.create("div",{position:"absolute"});
	if (obj.options.x >= 0) { obj.div.style.left = obj.options.x + "px"; }
	if (obj.options.x < 0) {obj.div.style.right = (-obj.options.x) + "px"; }
	if (obj.options.y >= 0) { obj.div.style.top = obj.options.y + "px"; }
	if (obj.options.y < 0) { obj.div.style.bottom = (-obj.options.y) + "px"; }

	obj.content = OAT.Dom.create("div",{overflow:"auto"}); 
	obj.move = OAT.Dom.create("div");
	if (obj.options.move) { OAT.Drag.create(obj.move,obj.div);	}
	
	OAT.Dom.append([obj.div,obj.content,obj.move]);

	if (obj.options.close) {
		obj.closeBtn = OAT.Dom.create("div");
		obj.move.appendChild(obj.closeBtn);
	}

	if (obj.options.max) {
		obj.maxBtn = OAT.Dom.create("div");
		obj.move.appendChild(obj.maxBtn);
	}

	if (obj.options.min) {
		obj.minBtn = OAT.Dom.create("div");
		obj.move.appendChild(obj.minBtn);
	}

	if (obj.options.resize) {
		obj.resize = OAT.Dom.create("div");
 		obj.div.appendChild(obj.resize);
 		OAT.Resize.create(obj.resize,obj.content,OAT.Resize.TYPE_XY);
	}

	
	obj.caption = OAT.Dom.create("div");
	obj.caption.innerHTML = "&nbsp;"+obj.options.title;
	obj.move.appendChild(obj.caption);
	obj.anchorTo = function(x_,y_) { /* where should we put the window? */
		var fs = OAT.Dom.getFreeSpace(x_,y_); /* [left,top] */
		var dims = OAT.Dom.getWH(obj.div);
		
		if (fs[1]) { /* top */
			var y = y_ - 20 - dims[1];
		} else { /* bottom */
			var y = y_ + 20;
		}
		
		var x = Math.round(x_ - dims[0]/2);
		if (x < 0) { x = 10; }
		
		obj.div.style.left = x+"px";
		obj.div.style.top = y+"px";
	}

	obj.resizeTo = function(w,h) {
		if (w) obj.content.style.width = w + "px";
		if (h) obj.content.style.height = h + "px";
	}
	obj.resizeTo(obj.options.width,obj.options.height);
}
OAT.Loader.featureLoaded("window");
