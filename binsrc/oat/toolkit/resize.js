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
		for (var i=0;i<OAT.Resize.element.length;i++) {
			OAT.Resize.element[i][3](); /* endFunction() */
		}
		OAT.Resize.element = [];
	},

	create:function(clicker,mover,type,restrictionFunction,endFunction) {
		var elm = $(clicker);
		var win = $(mover);
		var rf = function() { return false; }
		var ef = function() { return false; }
		if (restrictionFunction) { rf = restrictionFunction; }
		if (endFunction) { ef = endFunction; }
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
			OAT.Event.attach(elm,"mousedown",ref);
			elm._Resize_movers = [];
		}
		elm._Resize_movers.push([win,type,rf,ef]);
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

	createDefault:function(parent,restrictionFunction,endFunction) {
		if (!OAT.Preferences.allowDefaultResize) { return; }
		var bg = "url(" + OAT.Preferences.imagePath + "resize.gif)";
		var resize = OAT.Dom.create("div",{position:"absolute",width:"10px",height:"10px",right:"0px",fontSize:"1px",bottom:"0px",backgroundImage:bg});
		parent.appendChild(resize);
		OAT.Resize.create(resize,parent,OAT.Resize.TYPE_XY,restrictionFunction,endFunction);
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
		OAT.Event.attach(parent,"mouseover",show);
		OAT.Event.attach(parent,"mouseout",hide);
	}

}
OAT.Event.attach(document,"mousemove",OAT.Resize.move);
OAT.Event.attach(document,"mouseup",OAT.Resize.up);
