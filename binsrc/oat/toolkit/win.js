/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2007 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	tbd.
*/
OAT.WinData = {
	TYPE_TEMPLATE:-1,
	TYPE_AUTO:0,
	TYPE_MS:1,
	TYPE_MAC:2,
	TYPE_ROUND:3,
	TYPE_RECT:4
}

OAT.Win = function(optObj) {
	var self = this;
	
	this.options = { /* defaults */
		title:"",
		x:0,
		y:0,
		visibleButtons:"cmMfr",
		enabledButtons:"cmMfr",
		innerWidth:0,
		innerHeight:0,
		outerWidth:0,
		outerHeight:0,
		stackGroupBase:100,
		type:OAT.WinData.TYPE_AUTO,
		template:false,
		className:false
	}
	
	for (var p in optObj) { this.options[p] = optObj[p]; }
	
	/* create blank dom properties and blank methods */
	self.dom = {
		buttons:{c:false,m:false,M:false,f:false,r:false},
		container:false,
		content:false,
		title:false,
		caption:false,
		status:false,
		resizeContainer:false
	}
	self.moveTo = function(x,y) {
		self.dom.container.style.left = x+"px";
		self.dom.container.style.top = y+"px";
	} 
	self.anchorTo = function(x_,y_) { /* OBSOLETE: this is now done by anchor.js */
		var fs = OAT.Dom.getFreeSpace(x_,y_); /* [left,top] */
		var dims = OAT.Dom.getWH(self.dom.container);
		
		if (fs[1]) { /* top */
			var y = y_ - 30 - dims[1];
		} else { /* bottom */
			var y = y_ + 30;
		}

		if (fs[0]) { /* left */
			var x = x_ + 20 - dims[0]; 
		} else { /* right */
			var x = x_ - 20;
		}
		
		if (x < 0) { x = 10; }
		if (y < 0) { y = 10; }
		
		self.moveTo(x,y);
	} 

	self.innerResizeTo = function(w,h) { }
	self.outerResizeTo = function(w,h) { }
	self.show = function() { OAT.Dom.show(self.dom.container); }
	self.hide = function() { OAT.Dom.hide(self.dom.container); }
	self.minimize = function() { }
	self.maximize = function() { }
	self.flip = function(side) { }
	self.accomodate = function(node) { 
		var dims = OAT.Dom.getWH(node);
		self.innerResizeTo(dims[0],dims[1]);
	}
	
	/* create the DOM accordingly, add methods */
	if (self.options.type == OAT.WinData.TYPE_TEMPLATE) { OAT.WinTemplate(self); }
	if (self.options.type == OAT.WinData.TYPE_MS) { OAT.WinMS(self); }
	if (self.options.type == OAT.WinData.TYPE_MAC) { OAT.WinMAC(self); }
	if (self.options.type == OAT.WinData.TYPE_RECT) { OAT.WinRECT(self); }
	if (self.options.type == OAT.WinData.TYPE_ROUND) { OAT.WinROUND(self); }

	/* assign events */
	if (self.options.enabledButtons.indexOf("m") != -1 && self.dom.buttons.m) {
		OAT.Dom.attach(self.dom.buttons.m,"click",self.minimize);
	}
	if (self.options.enabledButtons.indexOf("M") != -1 && self.dom.buttons.M) {
		OAT.Dom.attach(self.dom.buttons.M,"click",self.maximize);
	}
	if (self.options.enabledButtons.indexOf("c") != -1 && self.dom.buttons.c) {
		OAT.Dom.attach(self.dom.buttons.c,"click",self.hide);
	}
	if (self.options.enabledButtons.indexOf("f") != -1 && self.dom.buttons.f) {
		OAT.Dom.attach(self.dom.buttons.f,"click",self.flip);
	}
	if (self.options.enabledButtons.indexOf("r") != -1 && self.dom.buttons.r) {
		OAT.Resize.create(self.dom.buttons.r,self.dom.resizeContainer,OAT.Resize.TYPE_XY);
	}
	if (self.dom.title) {
		OAT.Drag.create(self.dom.title,self.dom.container);
	}
	
	/* append */
	document.body.appendChild(self.dom.container);

	/* size & title & position */
	self.moveTo(self.options.x,self.options.y);
	if (self.options.outerWidth || self.options.outerHeight) { self.outerResizeTo(self.options.outerWidth,self.options.outerHeight); }
	if (self.options.innerWidth || self.options.innerHeight) { self.innerResizeTo(self.options.innerWidth,self.options.innerHeight); }
	if (self.dom.caption) { self.dom.caption.innerHTML = self.options.title; }
	
	/* nearly ready... */
	if (self.options.stackGroupBase) { OAT.WinManager.addWindow(self.options.stackGroupBase,self.dom.container); }
	self.hide();
}

OAT.WinTemplate = function(obj) {
	var tmp = obj.options.template;
	if (!tmp) {
		alert("OAT Window cannot be created, as a template is required but not specified!");
		return;
	}
	var template = (typeof(tmp) == "function" ? tmp() : $(tmp).cloneNode(true));
	var classMap = {
		"oat_w_ctr":"container",
		"oat_w_title_ctr":"title",
		"oat_w_title_t_ctr":"caption",
		"oat_w_content":"content",
		"oat_w_max_b":["buttons","M"],
		"oat_w_min_b":["buttons","m"],
		"oat_w_close_b":["buttons","c"],
		"oat_w_flip_b":["buttons","f"],
		"oat_w_resize_handle":["buttons","r"]
	}
	var all = [template];
	var tmp = template.getElementsByTagName("*");
	for (var i=0;i<tmp.length;i++) { all.push(tmp[i]); }
	for (var i=0;i<all.length;i++) {
		var node = all[i];
		for (var className in classMap) {
			if (OAT.Dom.isClass(node,className)) { /* add to properties */
				var property = classMap[className];
				if (property instanceof Array) {
					obj.dom[property[0]][property[1]] = node;
				} else {
					obj.dom[property] = node;
				}
			}
		}
	}
	
	/* methods */
	obj.moveTo = function(x,y) {
		obj.dom.container.style.left = x+"px";
		obj.dom.container.style.top = y+"px";
	}
	obj.outerResizeTo = function(w,h) {
		obj.dom.container.style.width = (w ? w+"px" : "auto");
		obj.dom.container.style.height = (h ? h+"px" : "auto");
	}
	obj.innerResizeTo = function(w,h) {
		obj.dom.content.style.width = (w ? w+"px" : "auto");
		obj.dom.content.style.height = (h ? h+"px" : "auto");
	}
}

OAT.WinMS = function(obj) { /* MS-like window */
	obj.dom.container = OAT.Dom.create("div",{position:"absolute"},"oat_winms_container");
	obj.dom.resizeContainer = obj.dom.container;
	obj.dom.content = OAT.Dom.create("div",{},"oat_winms_content");
	obj.dom.title = OAT.Dom.create("div",{},"oat_winms_title");
	obj.dom.caption = OAT.Dom.create("span",{},"oat_winms_caption");
	obj.dom.status = OAT.Dom.create("div",{},"oat_winms_status");

	OAT.Dom.append([obj.dom.container,obj.dom.title,obj.dom.content,obj.dom.status]);
	
	if (obj.options.visibleButtons.indexOf("c") != -1) {
		obj.dom.buttons.c = OAT.Dom.create("div",{},"oat_winms_close_b");
		OAT.Dom.append([obj.dom.title,obj.dom.buttons.c]);
	}
	if (obj.options.visibleButtons.indexOf("M") != -1) {
		obj.dom.buttons.M = OAT.Dom.create("div",{},"oat_winms_max_b");
		OAT.Dom.append([obj.dom.title,obj.dom.buttons.M]);
	}
	if (obj.options.visibleButtons.indexOf("m") != -1) {
		obj.dom.buttons.m = OAT.Dom.create("div",{},"oat_winms_min_b");
		OAT.Dom.append([obj.dom.title,obj.dom.buttons.m]);
	}
	if (obj.options.visibleButtons.indexOf("r") != -1) {
		obj.dom.buttons.r = OAT.Dom.create("div",{},"oat_winms_resize_b");
		OAT.Dom.append([obj.dom.container,obj.dom.buttons.r]);
	}

	OAT.Dom.append([obj.dom.title,obj.dom.caption]);

	obj.outerResizeTo = function(w,h) {
		obj.dom.container.style.width = (w ? w+"px" : "auto");
		obj.dom.container.style.height = (h ? h+"px" : "auto");
	}
	
}

OAT.WinMAC = function(obj) { /* MacOSX-like window */
	obj.dom.container = OAT.Dom.create("div",{position:"absolute"},"oat_winmac_container");
	obj.dom.resizeContainer = obj.dom.container;
	obj.dom.content = OAT.Dom.create("div",{},"oat_winmac_content");
	obj.dom.title = OAT.Dom.create("div",{},"oat_winmac_title");
	obj.dom.caption = OAT.Dom.create("span",{},"oat_winmac_caption");
	obj.dom.status = OAT.Dom.create("div",{},"oat_winmac_status");

	OAT.Dom.append([obj.dom.container,obj.dom.title,obj.dom.content,obj.dom.status]);

	obj.dom.buttons.lc = OAT.Dom.create("div",{},"oat_winmac_leftCorner");
	OAT.Dom.append([obj.dom.title,obj.dom.buttons.lc]);
	obj.dom.buttons.rc = OAT.Dom.create("div",{},"oat_winmac_rightCorner");
	OAT.Dom.append([obj.dom.title,obj.dom.buttons.rc]);

	if (obj.options.visibleButtons.indexOf("c") != -1) {
		obj.dom.buttons.c = OAT.Dom.create("div",{},"oat_winmac_close_b");
		OAT.Dom.append([obj.dom.title,obj.dom.buttons.c]);
	}
	if (obj.options.visibleButtons.indexOf("M") != -1) {
		obj.dom.buttons.M = OAT.Dom.create("div",{},"oat_winmac_max_b");
		OAT.Dom.append([obj.dom.title,obj.dom.buttons.M]);
	}
	if (obj.options.visibleButtons.indexOf("m") != -1) {
		obj.dom.buttons.m = OAT.Dom.create("div",{},"oat_winmac_min_b");
		OAT.Dom.append([obj.dom.title,obj.dom.buttons.m]);
	}
	if (obj.options.visibleButtons.indexOf("r") != -1) {
		obj.dom.buttons.r = OAT.Dom.create("div",{},"oat_winmac_resize_b");
		OAT.Dom.append([obj.dom.container,obj.dom.buttons.r]);
	}

	OAT.Dom.append([obj.dom.title,obj.dom.caption]);

	obj.outerResizeTo = function(w,h) {
		obj.dom.container.style.width = (w ? w+"px" : "auto");
		obj.dom.container.style.height = (h ? (h-8)+"px" : "auto");
	}
	
}

OAT.WinRECT = function(obj) { /* rectangular window */
	obj.dom.container = OAT.Dom.create("div",{position:"absolute"},"oat_winrect_container");
	obj.dom.resizeContainer = obj.dom.container;
	obj.dom.content = OAT.Dom.create("div",{},"oat_winrect_content");
	obj.dom.title = OAT.Dom.create("div",{},"oat_winrect_title");
	obj.dom.caption = OAT.Dom.create("span",{},"oat_winrect_caption");
	obj.dom.status = OAT.Dom.create("div",{},"oat_winrect_status");

	OAT.Dom.append([obj.dom.container,obj.dom.title,obj.dom.content,obj.dom.status]);

	if (obj.options.visibleButtons.indexOf("c") != -1) {
		obj.dom.buttons.c = OAT.Dom.create("div",{},"oat_winrect_close_b");
		OAT.Dom.append([obj.dom.title,obj.dom.buttons.c]);
	}
	if (obj.options.visibleButtons.indexOf("r") != -1) {
		obj.dom.buttons.r = OAT.Dom.create("div",{},"oat_winrect_resize_b");
		OAT.Dom.append([obj.dom.container,obj.dom.buttons.r]);
	}

	OAT.Dom.append([obj.dom.title,obj.dom.caption]);

	obj.outerResizeTo = function(w,h) {
		obj.dom.container.style.width = (w ? w+"px" : "auto");
		obj.dom.container.style.height = (h ? h+"px" : "auto");
	}
	
}

OAT.WinROUND = function(obj) { /* rounded window */
	
	obj.dom.container = OAT.Dom.create("div",{position:"absolute"},"oat_winround_container");
	obj.dom.resizeContainer = obj.dom.container;
	obj.dom.content = OAT.Dom.create("div",{},"oat_winround_content");
	obj.dom.title = OAT.Dom.create("div",{},"oat_winround_title");
	obj.dom.caption = OAT.Dom.create("span",{},"oat_winround_caption");
	obj.dom.status = OAT.Dom.create("div",{},"oat_winround_status");

	OAT.Dom.append([obj.dom.container,obj.dom.title,obj.dom.content,obj.dom.status]);

	if (obj.options.visibleButtons.indexOf("c") != -1) {
		obj.dom.buttons.c = OAT.Dom.create("div",{},"oat_winround_close_b");
		OAT.Dom.append([obj.dom.title,obj.dom.buttons.c]);
	}
	if (obj.options.visibleButtons.indexOf("r") != -1) {
		obj.dom.buttons.r = OAT.Dom.create("div",{},"oat_winround_resize_b");
		OAT.Dom.append([obj.dom.container,obj.dom.buttons.r]);
	}

	OAT.Dom.append([obj.dom.title,obj.dom.caption]);
	OAT.SimpleFX.roundDiv(obj.dom.container,{backgroundColor:'#000',antialias:1,borderColor:'#666'});

	obj.outerResizeTo = function(w,h) {
		obj.dom.container.style.width = (w ? w+"px" : "auto");
		obj.dom.container.style.height = (h ? h+"px" : "auto");
	}
	
}

OAT.WinManager = { /* stacking management */
	stackingGroups:{},
	addWindow:function(zI, container) {
		if (zI in OAT.WinManager.stackingGroups) {
			var l = OAT.WinManager.stackingGroups[zI];
		} else {
			var l = new OAT.Layers(zI);
			OAT.WinManager.stackingGroups[zI] = l;
		}
		l.addLayer(container,"click");
	},
	removeWindow:function(groupId) {
		if (zI in OAT.WinManager.stackingGroups) {
			var l = OAT.WinManager.stackingGroups[zI];
		} else {
			var l = new OAT.Layers(zI);
			OAT.WinManager.stackingGroups[zI] = l;
		}
		l.removeLayer(container);
	}
}
OAT.Loader.featureLoaded("win");
