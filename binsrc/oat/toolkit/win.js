/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2012 OpenLink Software
 *
 *  See LICENSE file for details.
 */

/**
	@message WINDOW_OPEN
	@message WINDOW_CLOSE
	@message WINDOW_MAXIMIZE
	@message WINDOW_RESTORE
	@message WINDOW_SHADE
	@message WINDOW_UNSHADE
*/

OAT.Win = function(optObj) {
	var self = this;

	this._shaded = false;
	this._oldSize = null; /* remember original size when maximizing */
	this._oldPosition = null; /* remember original position, too */

	this.options = { /* defaults */
		title:"",
		x:0,
		y:0,
		buttons:"csMr",
		innerWidth: false,
		innerHeight: false,
		outerWidth: 350,
		outerHeight: false,
		stackGroupBase:100,
		type:false, /* false = auto */
		template:false,
		className:false
	}

	for (var p in optObj) { this.options[p] = optObj[p]; }

	/* create blank dom properties and blank methods */
	this.dom = {
		buttons: {
			c: false,
			s: false,
			M: false,
			r: false
		},
		container: false,
		content: false,
		title: false,
		caption: false,
		status: false
	}

	/**
	 * move window to specified [x,y] position
	 * @param {int} x
	 * @param {int} y
	 */
	this.moveTo = function(x,y) {
		var xprop = (x >= 0 ? "left" : "right");
		var yprop = (y >= 0 ? "top" : "bottom");
		self.dom.container.style[xprop] = Math.abs(x) + "px";
		self.dom.container.style[yprop] = Math.abs(y) + "px";
	}

	/**
	 * width is set at container
	 */
	this._width = function(w) {
		var width = w;
		width -= parseInt(OAT.Style.get(self.dom.container, "borderLeftWidth")) || 0;
		width -= parseInt(OAT.Style.get(self.dom.container, "borderRightWidth")) || 0;

		self.dom.container.style.width = (w ? width+"px" : "");
	}

	/**
	 * height is set at content
	 */
	this._height = function(h) {
		self.dom.content.style.height = (h ? h+"px" : "");
	}

    /**
     * get outer container
     */
    this.getOuterContainer = function () {
	return self.dom.container;
    }

    /**
     * get inner container
     */

    this.getInnerContainer = function () {
	return self.dom.content;
    }

	/**
	 * resize window content
	 */
	this.innerResizeTo = function(w,h) {
		this._height(h);

		var wh1 = OAT.Dom.getWH(self.dom.container);
		var wh2 = OAT.Dom.getWH(self.dom.content);
		var diff = wh1[0]-wh2[0];
		var width = w;
		if (width) { width += diff; }
		this._width(width);
	}

	/**
	 * resize window container
	 */
	this.outerResizeTo = function(w,h) {
		this._width(w);

		var wh1 = OAT.Dom.getWH(self.dom.container);
		var wh2 = OAT.Dom.getWH(self.dom.content);
		var diff = wh1[1]-wh2[1];
		var height = h;
		if (height) { height -= diff; }
		this._height(height);
	}

	/**
	 * open window
	 */
	this.open = function() {
		OAT.Dom.show(self.dom.container);
		OAT.MSG.send(self, "WINDOW_OPEN");
	}

	/**
	 * close window
	 */
	this.close = function() {
		OAT.Dom.hide(self.dom.container);
		OAT.MSG.send(self, "WINDOW_CLOSE");
	}

	/**
	 * shades the window to window header
	 */
	this.shade = function() {
		if (self._shaded) {
			self.unshade();
			return;
		}

		self._shaded = true;

		self.dom.content.style.display = 'none';
		self.dom.status.style.display = 'none';
		if (self.dom.buttons.r) {
			self.dom.buttons.r.style.display = 'none';
		}
		OAT.MSG.send(self, "WINDOW_SHADE");
	}

	/**
	 * unshades the window from window header
	 */
	this.unshade = function() {
		self.dom.content.style.display = '';
		self.dom.status.style.display = '';
		if (self.dom.buttons.r) {
			self.dom.buttons.r.style.display = '';
		}

		self._shaded = false;
		OAT.MSG.send(self, "WINDOW_UNSHADE");
	}

	/**
	 * maximizes window to full extent
	 */
	this.maximize = function() {
		if (self._oldSize) { return; }

		self._oldSize = OAT.Dom.getWH(self.dom.content);
		self._oldPosition = OAT.Dom.getLT(self.dom.container);

		self.moveTo(0, 0);

		if (self.dom.container.parentNode == document.body) {
			var max = OAT.Dom.getViewport();
		} else {
			var max = OAT.Dom.getWH(self.dom.container.parentNode);
		}

		self.outerResizeTo(max[0], max[1]);
		OAT.MSG.send(self, "WINDOW_MAXIMIZE");
	}

	/**
	 * restores window to nonmaximized size
	 */
	this.restore = function() {
		if (!self._oldSize) { return; }
		this.innerResizeTo(this._oldSize[0], this._oldSize[1]);
		this.moveTo(this._oldPosition[0],this._oldPosition[1]);
		this._oldSize = null;
		this._oldPosition = null;
		OAT.MSG.send(self, "WINDOW_RESTORE");
	}

	/**
	 * sets width and height according to the specified element of auto if none specified
	 */
	this.accomodate = function(node) {
		if (node) {
		    var dims = OAT.Dom.getWH(node);
                } else {
		    var dims = [false,false];
                }
		self.innerResizeTo(dims[0],dims[1]);
	}

	this._setupResizing = function() {
		var x = 0;
		var y = 0;
		var flag = 0;
		this.dom.buttons.r.style.cursor = "nw-resize";

		OAT.Event.attach(self.dom.buttons.r, "mousedown", function(e) {
			flag = 1;
			x = e.clientX;
			y = e.clientY;
		});
		OAT.Event.attach(document, "mouseup", function(e) {
			flag = 0;
		});
		OAT.Event.attach(document, "mousemove", function(e) {
			if (!flag) { return; }
			var dx = e.clientX - x;
			var dy = e.clientY - y;
			x = e.clientX;
			y = e.clientY;
			OAT.Dom.resizeBy(self.dom.container, dx, 0);
			OAT.Dom.resizeBy(self.dom.content, 0, dy);
		});
	}

	/* create the DOM accordingly, add methods */
	if (this.options.type) {
		this.options.type(this);
	} else {
		if (OAT.Browser.isMac) {
			OAT.Win.Mac(self);
		} else {
			OAT.Win.MS(self);
		}
	}

	this.dom.content.style.overflow = "auto";

	/* assign events */
	if (this.dom.buttons.s) { OAT.Event.attach(this.dom.buttons.s,"click",this.shade); }
	if (this.dom.buttons.M) { OAT.Event.attach(this.dom.buttons.M,"click", function() {
			if (self._oldSize) { self.restore(); } else { self.maximize(); }
		});
	}
	if (this.dom.buttons.c) { OAT.Event.attach(this.dom.buttons.c,"click",this.close); }
	if (this.dom.buttons.r) { self._setupResizing(); }
	if (this.dom.title) { OAT.Drag.create(this.dom.title, this.dom.container); }

	/* hide and append */
	this.close();
        document.body.appendChild(this.dom.container);

	/* size & title & position */
	this.moveTo(this.options.x, this.options.y);

	if (this.options.outerWidth || this.options.outerHeight) { 
	    this.outerResizeTo(this.options.outerWidth, this.options.outerHeight); 
	}

	if (this.options.innerWidth || this.options.innerHeight) { 
	    this.innerResizeTo(this.options.innerWidth, this.options.innerHeight); 
	}

	if (this.dom.caption) { this.dom.caption.innerHTML = this.options.title; }

	/* nearly ready... */
	if (this.options.stackGroupBase) { OAT.WinManager.addWindow(this.options.stackGroupBase, this.dom.container); }
}

/**
 * @class window template
 */
OAT.Win.Template = function(obj) {
	var tmp = obj.options.template;
	if (!tmp) {
		alert("OAT.Win.Template:\nOAT Window cannot be created, as a template is required but not specified!");
		return;
	}
	var template = (typeof(tmp) == "function" ? tmp() : $(tmp).cloneNode(true));
	var classMap = {
		"oat_w_ctr":"container",
		"oat_w_title_ctr":"title",
		"oat_w_title_t_ctr":"caption",
		"oat_w_content":"content",
		"oat_w_max_b":["buttons","M"],
		"oat_w_shade_b":["buttons","s"],
		"oat_w_close_b":["buttons","c"],
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

}

/**
 * @class MS-like window
 */
OAT.Win.MS = function(obj) {
	OAT.Style.include('winms.css');
	obj.dom.container = OAT.Dom.create("div",
					   {position:"absolute",
					    className:"oat_winms_container oat_win_container"});
	obj.dom.content = OAT.Dom.create("div",{className:"oat_winms_content"});
	obj.dom.title = OAT.Dom.create("div",{className:"oat_winms_title"});
	obj.dom.caption = OAT.Dom.create("span",{className:"oat_winms_caption"});
	obj.dom.status = OAT.Dom.create("div",{className:"oat_winms_status"});

	OAT.Dom.append([obj.dom.container,obj.dom.title,obj.dom.content,obj.dom.status]);

	if (obj.options.buttons.indexOf("c") != -1) {
		obj.dom.buttons.c = OAT.Dom.create("div",{className:"oat_winms_close_b"});
		OAT.Dom.append([obj.dom.title,obj.dom.buttons.c]);
	}
	if (obj.options.buttons.indexOf("M") != -1) {
		obj.dom.buttons.M = OAT.Dom.create("div",{className:"oat_winms_max_b"});
		OAT.Dom.append([obj.dom.title,obj.dom.buttons.M]);
	}
	if (obj.options.buttons.indexOf("s") != -1) {
		obj.dom.buttons.s = OAT.Dom.create("div",{className:"oat_winms_shade_b"});
		OAT.Dom.append([obj.dom.title,obj.dom.buttons.s]);
	}
	if (obj.options.buttons.indexOf("r") != -1) {
		obj.dom.buttons.r = OAT.Dom.create("div",{className:"oat_winms_resize_b"});
		OAT.Dom.append([obj.dom.container,obj.dom.buttons.r]);
	}

	OAT.Dom.append([obj.dom.title,obj.dom.caption]);

}

/**
 * @class Mac OS X-like window
 */
OAT.Win.Mac = function(obj) {
	OAT.Style.include('winmac.css');
	obj.dom.container = OAT.Dom.create("div",{position:"absolute",className:"oat_winmac_container oat_win_container"});
	obj.dom.content = OAT.Dom.create("div",{className:"oat_winmac_content"});
	obj.dom.title = OAT.Dom.create("div",{className:"oat_winmac_title"});
	obj.dom.caption = OAT.Dom.create("span",{className:"oat_winmac_caption"});
	obj.dom.status = OAT.Dom.create("div",{className:"oat_winmac_status"});

	OAT.Dom.append([obj.dom.container,obj.dom.title,obj.dom.content,obj.dom.status]);

	obj.dom.buttons.lc = OAT.Dom.create("div",{className:"oat_winmac_leftCorner"});
	OAT.Dom.append([obj.dom.title,obj.dom.buttons.lc]);
	obj.dom.buttons.rc = OAT.Dom.create("div",{className:"oat_winmac_rightCorner"});
	OAT.Dom.append([obj.dom.title,obj.dom.buttons.rc]);

	if (obj.options.buttons.indexOf("c") != -1) {
		obj.dom.buttons.c = OAT.Dom.create("div",{className:"oat_winmac_close_b"});
		OAT.Dom.append([obj.dom.title,obj.dom.buttons.c]);
	}
	if (obj.options.buttons.indexOf("M") != -1) {
		obj.dom.buttons.M = OAT.Dom.create("div",{className:"oat_winmac_max_b"});
		OAT.Dom.append([obj.dom.title,obj.dom.buttons.M]);
	}
	if (obj.options.buttons.indexOf("s") != -1) {
		obj.dom.buttons.s = OAT.Dom.create("div",{className:"oat_winmac_shade_b"});
		OAT.Dom.append([obj.dom.title,obj.dom.buttons.s]);
	}
	if (obj.options.buttons.indexOf("r") != -1) {
		obj.dom.buttons.r = OAT.Dom.create("div",{className:"oat_winmac_resize_b"});
		OAT.Dom.append([obj.dom.container,obj.dom.buttons.r]);
	}

	OAT.Dom.append([obj.dom.title,obj.dom.caption]);

}

/**
 * @"class" simple, rectangular window
 */
OAT.Win.Rect = function(obj) {
	OAT.Style.include('winrect.css');
	obj.dom.container = OAT.Dom.create("div",{position:"absolute", className:"oat_winrect_container oat_win_container"});
	obj.dom.content = OAT.Dom.create("div",{className:"oat_winrect_content"});
	obj.dom.title = OAT.Dom.create("div",{className:"oat_winrect_title"});
	obj.dom.caption = OAT.Dom.create("span",{className:"oat_winrect_caption"});
	obj.dom.status = OAT.Dom.create("div",{className:"oat_winrect_status"});

	OAT.Dom.append([obj.dom.container,obj.dom.title,obj.dom.content,obj.dom.status]);

	if (obj.options.buttons.indexOf("c") != -1) {
		obj.dom.buttons.c = OAT.Dom.create("div",{className:"oat_winrect_close_b"});
		OAT.Dom.append([obj.dom.title,obj.dom.buttons.c]);
	}
	if (obj.options.buttons.indexOf("r") != -1) {
		obj.dom.buttons.r = OAT.Dom.create("div",{className:"oat_winrect_resize_b"});
		OAT.Dom.append([obj.dom.container,obj.dom.buttons.r]);
	}

	OAT.Dom.append([obj.dom.title,obj.dom.caption]);
}

/**
 * @class window with rounded corners
 */
OAT.Win.Round = function(obj) {
	OAT.Style.include('winround.css');

	obj.dom.container = OAT.Dom.create("div",{position:"absolute", 
						  className:"oat_winround_container oat_win_container"});

	obj.dom.table = OAT.Dom.create("table",{className:"oat_winround_wrapper"});
	obj.dom.tr_t = OAT.Dom.create("tr",{});
	obj.dom.td_lt = OAT.Dom.create("td",{className:"oat_winround_lt"});
	obj.dom.td_t = OAT.Dom.create("td",{className:"oat_winround_t"});
	obj.dom.td_rt = OAT.Dom.create("td",{className:"oat_winround_rt"});
	obj.dom.tr_m = OAT.Dom.create("tr",{});
	obj.dom.td_l = OAT.Dom.create("td",{className:"oat_winround_l"});
	obj.dom.td_m = OAT.Dom.create("td",{className:"oat_winround_m"});
 	obj.dom.td_r = OAT.Dom.create("td",{className:"oat_winround_r"});
	obj.dom.tr_b = OAT.Dom.create("tr",{});
	obj.dom.td_lb = OAT.Dom.create("td",{className:"oat_winround_lb"});
	obj.dom.td_b = OAT.Dom.create("td",{className:"oat_winround_b"});
	obj.dom.td_rb = OAT.Dom.create("td",{className:"oat_winround_rb"});

	obj.dom.content = OAT.Dom.create("div",{className:"oat_winround_content"});
	obj.dom.title = OAT.Dom.create("div",{className:"oat_winround_title"});
	obj.dom.caption = OAT.Dom.create("span",{className:"oat_winround_caption"});
	obj.dom.status = OAT.Dom.create("div",{className:"oat_winround_status"});

	if (obj.options.buttons.indexOf("c") != -1) {
		obj.dom.buttons.c = OAT.Dom.create("div",{className:"oat_winround_close_b"});
		OAT.Dom.append([obj.dom.title,obj.dom.buttons.c]);
	}
	if (obj.options.buttons.indexOf("r") != -1) {
		obj.dom.buttons.r = OAT.Dom.create("div",{className:"oat_winround_resize_b"});
		OAT.Dom.append([obj.dom.td_rb,obj.dom.buttons.r]);
	}

	OAT.Dom.append([obj.dom.title,obj.dom.caption]);

	if (OAT.Browser.isIE) { /* FIXME: rework into a dom build process */
		obj.dom.container.innerHTML = '<table class="oat_winround_wrapper"><tr><td class="oat_winround_lt"></td><td class="oat_winround_t"></td><td class="oat_winround_rt"></td></tr><tr><td class="oat_winround_l"></td><td class="oat_winround_m"></td><td class="oat_winround_r"></td></tr><tr><td class="oat_winround_lb"></td><td class="oat_winround_b"></td><td class="oat_winround_rb"></td></tr></table>';
		obj.dom.container.childNodes[0].childNodes[0].childNodes[0].childNodes[1].appendChild(obj.dom.title);
		obj.dom.container.childNodes[0].childNodes[0].childNodes[1].childNodes[1].appendChild(obj.dom.content);
		obj.dom.container.childNodes[0].childNodes[0].childNodes[2].childNodes[1].appendChild(obj.dom.status);
		obj.dom.container.childNodes[0].childNodes[0].childNodes[2].childNodes[2].appendChild(obj.dom.buttons.r);
	} else {
		/* create table */
		OAT.Dom.append([obj.dom.tr_t,obj.dom.td_lt,obj.dom.td_t,obj.dom.td_rt]);
		OAT.Dom.append([obj.dom.tr_m,obj.dom.td_l,obj.dom.td_m,obj.dom.td_r]);
		OAT.Dom.append([obj.dom.tr_b,obj.dom.td_lb,obj.dom.td_b,obj.dom.td_rb]);
		OAT.Dom.append([obj.dom.table,obj.dom.tr_t,obj.dom.tr_m,obj.dom.tr_b]);
		/* put window elements into the table */
		OAT.Dom.append([obj.dom.td_t,obj.dom.title]);
		OAT.Dom.append([obj.dom.td_m,obj.dom.content]);
		OAT.Dom.append([obj.dom.td_b,obj.dom.status]);
		/* insert the table into the container*/
		OAT.Dom.append([obj.dom.container,obj.dom.table]);
	}

}

/**
 * @class OpenLink Data spaces window design
 */
OAT.Win.ODS = function(obj) {
	OAT.Style.include('winods.css');
	obj.dom.container = OAT.Dom.create("div",{position:"absolute", className:"oat_winods_container oat_win_container"});
	obj.dom.content = OAT.Dom.create("div",{className:"oat_winods_content"});
	obj.dom.title = OAT.Dom.create("div",{className:"oat_winods_title"});
	obj.dom.caption = OAT.Dom.create("span",{className:"oat_winods_caption"});
	obj.dom.status = OAT.Dom.create("div",{className:"oat_winods_status"});

	OAT.Dom.append([obj.dom.container,obj.dom.title,obj.dom.content,obj.dom.status]);

	if (obj.options.buttons.indexOf("c") != -1) {
		obj.dom.buttons.c = OAT.Dom.create("div",{className:"oat_winods_close_b"});
		OAT.Dom.append([obj.dom.title,obj.dom.buttons.c]);
	}
	if (obj.options.buttons.indexOf("r") != -1) {
		obj.dom.buttons.r = OAT.Dom.create("div",{className:"oat_winods_resize_b"});
		OAT.Dom.append([obj.dom.container,obj.dom.buttons.r]);
	}

	OAT.Dom.append([obj.dom.title,obj.dom.caption]);
}

/**
 * stacking management
 */
OAT.WinManager = {
	stackingGroups:{},
	addWindow:function(zI, container) {
		if (zI in OAT.WinManager.stackingGroups) {
			var l = OAT.WinManager.stackingGroups[zI];
		} else {
			var l = new OAT.Layers(zI);
			OAT.WinManager.stackingGroups[zI] = l;
		}
		l.addLayer(container);
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
