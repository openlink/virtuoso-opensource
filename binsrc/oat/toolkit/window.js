/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2019 OpenLink Software
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

OAT.WindowType = function(type) {
	var t = false;
	var autotype = (OAT.Browser.isMac ? OAT.WindowData.TYPE_MAC : OAT.WindowData.TYPE_WIN); /* automatic */
	if (type && type != OAT.WindowData.TYPE_AUTO) { t = type; } else { t = autotype; } /* if specified, get specified */
	if (OAT.Preferences.windowTypeOverride) { t = OAT.Preferences.windowTypeOverride; } /* if override, get overriding type */
	if (t == OAT.WindowData.TYPE_AUTO) { t = autotype; }
	return t;
}

OAT.Window = function(optObj,type) {
	var options = {
		close:1,
		resize:1,
		move:1,
		x:10,
		y:10,
		width:160,
		height:50,
		title:"",
		magnetsH:[],
		magnetsV:[],
		statusHeight:16,
		moveHeight:16,
		imagePath:OAT.Preferences.imagePath
	}
	for (var p in optObj) { options[p] = optObj[p]; }

	if (options.height == 0) { options.height = 200; }

	var self = this;
	/* get window type */
	var t = OAT.WindowType(type);
	var obj = false;
	switch (t) {
		case OAT.WindowData.TYPE_WIN:
			var obj = new OAT.MsWin(options);
		break;
		case OAT.WindowData.TYPE_MAC:
			var obj = new OAT.MacWin(options);
		break;
		case OAT.WindowData.TYPE_ROUND:
			var obj = new OAT.RoundWin(options);
		break;
		case OAT.WindowData.TYPE_RECT:
			var obj = new OAT.RectWin(options);
		break;
	}
	if (!obj) { return; }

	obj.resizeTo(options.width,options.height);
	obj.moveTo(options.x,obj.options.y);

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
	this.moveTo = obj.moveTo;
	this.accomodate = obj.accomodate;
	/* methods */
	this.onclose = function(){};
	this.onmax = function(){};
	this.onmin = function(){};
	if (this.closeBtn) { OAT.Event.attach(this.closeBtn,"click",function(){self.onclose();}); }
	if (this.minBtn) { OAT.Event.attach(this.minBtn,"click",function(){self.onmin();}); }
	if (this.maxBtn) { OAT.Event.attach(this.maxBtn,"click",function(){self.onmax();}); }

	/* trick for easy stacking? need to be thoroughly tested.. */
	var upRef = function(event) {
		if (!obj.div.parentNode) { return; }
		obj.div.parentNode.appendChild(obj.div);
	}
//	OAT.Event.attach(obj.div,"click",upRef);
}

OAT.WindowParent = function(obj,options) { /* abstract parent for all window implementations */
	obj.options = options;
	obj.div = false;
	obj.content = false;
	obj.move = false;
	obj.caption = false;
	obj.closeBtn = false;
	obj.minBtn = false;
	obj.maxBtn = false;

	obj.div = OAT.Dom.create("div",{position:"absolute"});
	obj.content = OAT.Dom.create("div",{overflow:"auto",position:"relative"});
	obj.move = OAT.Dom.create("div");

	if (options.move) {
		OAT.Drag.create(obj.move,obj.div,{magnetsH:options.magnetsH,magnetsV:options.magnetsV});
	}

	OAT.Dom.append([obj.div,obj.move,obj.content]);

	if (options.close) {
		obj.closeBtn = OAT.Dom.create("div");
		obj.move.appendChild(obj.closeBtn);
	}

	if (options.max) {
		obj.maxBtn = OAT.Dom.create("div");
		obj.move.appendChild(obj.maxBtn);
	}

	if (options.min) {
		obj.minBtn = OAT.Dom.create("div");
		obj.move.appendChild(obj.minBtn);
	}

	if (options.resize) {
		obj.resize = OAT.Dom.create("div");
 		obj.div.appendChild(obj.resize);
 		OAT.Resize.create(obj.resize,obj.div,OAT.Resize.TYPE_XY);
 		OAT.Resize.create(obj.resize,obj.content,OAT.Resize.TYPE_XY);
 		OAT.Resize.create(obj.resize,obj.move,OAT.Resize.TYPE_X);
	}


	obj.caption = OAT.Dom.create("div");
	obj.caption.innerHTML = "&nbsp;"+options.title;
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

		obj.moveTo(x,y);
	}

	obj.resizeTo = function(w,h) {
		var movew = w;
		if (OAT.Browser.isIE && document.compatMode == "BackCompat") { movew += 2; } /* wtf omg lol :/ */
		if (w) {
			obj.move.style.width = movew + "px";
			obj.div.style.width = w + "px";
			obj.content.style.width = w + "px";
		}
		if (h) {
			obj.div.style.height = (h - options.moveHeight) + "px";
			obj.content.style.height = (h - options.statusHeight - options.moveHeight + 3) + "px";
		}
	}

	obj.moveTo = function(x,y) {
		if (x >= 0) { obj.div.style.left = x + "px"; }
		if (x < 0) { obj.div.style.right = (-x) + "px"; }
		if (y >= 0) { obj.div.style.top = (y + options.moveHeight) + "px"; }
		if (y < 0) { obj.div.style.bottom = (-y) + "px"; }
	}

	obj.accomodate = function() {
		var x = 0;
		var y = 0;
		for (var i=0;i<obj.content.childNodes.length;i++) {
			var node = obj.content.childNodes[i];
			var dims = OAT.Dom.getWH(node);
			var mt = parseInt(OAT.Style.get(node,"marginTop"));
			var mb = parseInt(OAT.Style.get(node,"marginBottom"));
			var ml = parseInt(OAT.Style.get(node,"marginLeft"));
			var mr = parseInt(OAT.Style.get(node,"marginRight"));
			x = Math.max(x,dims[0]+ml+mr);
			y += dims[1]+mt+mb;
		}
		// obj.resizeTo(x + 4,y + 6 + obj.options.moveHeight + obj.options.statusHeight);
		obj.resizeTo(false,y + 6 + obj.options.moveHeight + obj.options.statusHeight);
	}
}
