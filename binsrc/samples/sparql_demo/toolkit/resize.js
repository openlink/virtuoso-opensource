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
	OAT.Resize.create(clicker,mover,type)
	OAT.Resize.remove(clicker,mover)
	OAT.Resize.removeAll(clicker)
	OAT.Resize.TYPE_X
	OAT.Resize.TYPE_Y
	OAT.Resize.TYPE_XY
*/

OAT.Resize = {
	TYPE_X:1,
	TYPE_Y:2,
	TYPE_XY:3,
	element:[],
	mouse_x:0,
	mouse_y:0,
	
	init:function() {
		OAT.Dom.attach(document,"mousemove",OAT.Resize.move);
		OAT.Dom.attach(document,"mouseup",OAT.Resize.up);
	},
	
	move:function(event) {
		if (!OAT.Resize.element.length) return;
		var dx = event.clientX - OAT.Resize.mouse_x;
		var dy = event.clientY - OAT.Resize.mouse_y;
		/* first test for restrictions */
		var hope = 1;
		for (var i=0;i<OAT.Resize.element.length;i++) {
			var element = OAT.Resize.element[i][0];
			var dims = OAT.Dom.getWH(element);
			var rf = OAT.Resize.element[i][2];
			var testdx = dx;
			var testdy = dy;
			switch (OAT.Resize.element[i][1]) {
				case OAT.Resize.TYPE_X: testdy = 0;	break;
				case -OAT.Resize.TYPE_X: testdx = -dx; testdy = 0; break;
				case OAT.Resize.TYPE_Y: testdx = 0; break;
				case -OAT.Resize.TYPE_Y: testdx = 0; testdy = -dy; break;
				case OAT.Resize.TYPE_XY: break;
				case -OAT.Resize.TYPE_XY: testdx = -dx; testdy = -dy; break;
			} /* switch */
			if (rf(dims[0]+testdx,dims[1]+testdy)) { hope = 0; }
		} /* for all resizing elements */		
		
		if (!hope) { return; }
		
		/* ok, so now resize */
		for (var i=0;i<OAT.Resize.element.length;i++) {
			var element = OAT.Resize.element[i][0];
			switch (OAT.Resize.element[i][1]) {
				case OAT.Resize.TYPE_X: OAT.Dom.resizeBy(element,dx,0);	break;
				case -OAT.Resize.TYPE_X: OAT.Dom.resizeBy(element,-dx,0);	break;
				case OAT.Resize.TYPE_Y: OAT.Dom.resizeBy(element,0,dy);	break;
				case -OAT.Resize.TYPE_Y: OAT.Dom.resizeBy(element,0,-dy);	break;
				case OAT.Resize.TYPE_XY: OAT.Dom.resizeBy(element,dx,dy); break;
				case -OAT.Resize.TYPE_XY: OAT.Dom.resizeBy(element,-dx,-dy); break;
			} /* switch */
		} /* for all resizing elements */
		OAT.Resize.mouse_x = event.clientX;
		OAT.Resize.mouse_y = event.clientY;
	},
	
	up:function(event) {
		OAT.Resize.element = [];
	},

	create:function(clicker,mover,type,restrictionFunction) {
		var elm = $(clicker);
		var win = $(mover);
		var rf = function() { return false; }
		if (restrictionFunction) { rf = restrictionFunction; }
		switch (type) {
			case OAT.Resize.TYPE_XY: elm.style.cursor = "nw-resize"; break;
			case OAT.Resize.TYPE_X: elm.style.cursor = "w-resize"; break;
			case OAT.Resize.TYPE_Y: elm.style.cursor = "n-resize"; break;
		}
		var ref = function(event) {
			OAT.Resize.element = elm._Resize_movers;
			OAT.Resize.mouse_x = event.clientX;
			OAT.Resize.mouse_y = event.clientY;
			event.cancelBubble = true; // don't drag when resizing
		}
		if (!elm._Resize_movers) { 
			OAT.Dom.attach(elm,"mousedown",ref);		
			elm._Resize_movers = [];
		}
		elm._Resize_movers.push([win,type,rf]);
	},
	
	remove:function(clicker,mover) {
		var elm = $(clicker);
		var win = $(mover);
		if (!elm._Resize_movers) { return; }
		var index = -1;
		for (var i=0;i<elm._Resize_movers.length;i++) {
			if (elm._Resize_movers[i][0] == mover) { index = i; }
		}
		if (index == -1) { return; }
		elm._Resize_movers.splice(index,1);
	},
	
	removeAll:function(clicker) {
		var elm = $(clicker);
		if (elm._Resize_movers) { elm._Resize_movers = []; }
	},
	
	createDefault:function(parent) {
		if (!OAT.Preferences.allowDefaultResize) { return; }
		var resize = OAT.Dom.create("div",{position:"absolute",width:"10px",height:"10px",right:"0px",fontSize:"1px",bottom:"0px",backgroundImage:"url(/DAV/JS/images/resize.gif)"});
		parent.appendChild(resize);
		OAT.Resize.create(resize,parent,OAT.Resize.TYPE_XY);
		OAT.Dom.hide(resize);
		var show = function(event) {
			OAT.Dom.show(resize);
			resize._Resize_pending = 0;
		}
		var check = function() {
			if (resize._Resize_pending) {
				OAT.Dom.hide(resize);
			}
		}
		var hide = function(event) {
			resize._Resize_pending = 1;
			setTimeout(check,2000);
		}
		OAT.Dom.attach(parent,"mouseover",show);
		OAT.Dom.attach(parent,"mouseout",hide);
	}

}
OAT.Loader.loadAttacher(OAT.Resize.init);
OAT.Loader.pendingCount--;
