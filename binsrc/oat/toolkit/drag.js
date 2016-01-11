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
	OAT.Drag.create(clicker,mover,optObj)
	OAT.Drag.remove(clicker,mover)
	OAT.Drag.removeAll(clicker)
*/

OAT.Drag = {
	TYPE_X:1,
	TYPE_Y:2,
	TYPE_XY:3,
	elm:false,
	mouse_x:0,
	mouse_y:0,

	move:function(event) {
		if (!OAT.Drag.elm) return;
		OAT.Dom.removeSelection();
		var vp = OAT.Dom.getViewport();
		var pos = OAT.Dom.position(OAT.Drag.elm);
		var cpos = OAT.Event.position(event);
		var dims = OAT.Dom.getWH(OAT.Drag.elm);

		/* stop when mouse leaves viewport */
		if (event.clientX > vp[0] || event.clientX < 0 || event.clientY > vp[1] || event.clientY < 0) {
			return;
		}

		/* delta from last cursor scan */
		var dx = event.clientX - OAT.Drag.mouse_x;
		var dy = event.clientY - OAT.Drag.mouse_y;

		/* check restriction */
		var checkOK = true;
		var movers = OAT.Drag.elm._Drag_movers;
		for (var i=0;i<movers.length;i++) {
			var element = movers[i][0];
			var options = movers[i][1];
			var pos = OAT.Dom.getLT(element);
			if (options.restrictionFunction(pos[0]+dx,pos[1]+dy)) { checkOK = false; }
		}

		/* check magnets */
		var magnetOK = true;
		var mlimit = 10;
		function check(a,b) { return Math.abs(a-b) <= mlimit; }
		for (var i=0;i<movers.length;i++) {
			var element = movers[i][0];
			var options = movers[i][1];
			var ndims = OAT.Dom.getWH(element);
			var npos = OAT.Dom.position(element);
			var nx = npos[0]+dx;
			var ny = npos[1]+dy;
			for (var j=0;j<options.magnetsH.length;j++) {
				var m = $(options.magnetsH[j]);
				var mpos = OAT.Dom.position(m);
				var mdims = OAT.Dom.getWH(m);
				if (check(nx,mpos[0])) { element.style.left = mpos[0]+"px"; magnetOK = false; break; }
				if (check(nx+ndims[0],mpos[0])) { element.style.left = (mpos[0]-ndims[0])+"px"; magnetOK = false; break; }
				if (check(nx,mpos[0]+mdims[0])) { element.style.left = (mpos[0]+mdims[0])+"px"; magnetOK = false; break; }
				if (check(nx+ndims[0],mpos[0]+mdims[0])) { element.style.left = (mpos[0]+mdims[0]-ndims[0])+"px"; magnetOK = false; break; }
			}
			for (var j=0;j<options.magnetsV.length;j++) {
				var m = $(options.magnetsV[j]);
				var mpos = OAT.Dom.position(m);
				var mdims = OAT.Dom.getWH(m);
				if (check(ny,mpos[1])) { element.style.top = mpos[1]+"px"; magnetOK = false; break; }
				if (check(ny+ndims[1],mpos[1])) { element.style.top = (mpos[1]-ndims[1])+"px"; magnetOK = false; break; }
				if (check(ny,mpos[1]+mdims[1])) { element.style.top = (mpos[1]+mdims[1])+"px"; magnetOK = false; break; }
				if (check(ny+ndims[1],mpos[1]+mdims[1])) { element.style.top = (mpos[1]+mdims[1]-ndims[1])+"px"; magnetOK = false; break; }
			}
		}

		/* perform dragging */
		if (checkOK && magnetOK) {
			for (var i=0;i<movers.length;i++) {
				var element = movers[i][0];
				var options = movers[i][1];
				if (options.moveFunction) { options.moveFunction(dx,dy); } else {
					switch (options.type) {
						case OAT.Drag.TYPE_X: OAT.Dom.moveBy(element,dx,0); break;
						case OAT.Drag.TYPE_Y: OAT.Dom.moveBy(element,0,dy); break;
						case OAT.Drag.TYPE_XY: OAT.Dom.moveBy(element,dx,dy); break;
					} /* switch */
				} /* if not custom move function */
			} /* for all movers */
			OAT.Drag.mouse_x = event.clientX;
			OAT.Drag.mouse_y = event.clientY;
		}
	},

	up:function(event) {
		if (!OAT.Drag.elm) { return; }
		var movers = OAT.Drag.elm._Drag_movers;
		for (var i=0;i<movers.length;i++) {
			var element = movers[i][0];
			var options = movers[i][1];
			options.endFunction(element);
		}
		OAT.Drag.elm = false;
	},

	create:function(clicker,mover,optObj) {
		var options = {
			type:OAT.Drag.TYPE_XY,
			restrictionFunction:function(){return false;},
			endFunction:function(){},
			moveFunction:false,
			magnetsH:[],
			magnetsV:[],
			cursor:true
		}
		if (optObj) for (p in optObj) { options[p] = optObj[p]; }
		var elm = $(clicker);
		var win = $(mover);
		var ref = function(event) {
			OAT.Drag.initiate(event,elm);
		}
		if (!elm._Drag_movers) {
			OAT.Event.attach(elm,"mousedown",ref);
			elm._Drag_movers = [];
			elm._Drag_cursor = elm.style.cursor;
		}
		if (options.cursor) { elm.style.cursor = "move"; }
		elm._Drag_movers.push([win,options]);
	},

	initiate:function(event,elm) {
		OAT.Drag.elm = elm;
		OAT.Drag.mouse_x = event.clientX;
		OAT.Drag.mouse_y = event.clientY;
	},

	remove:function(clicker,mover) {
		var elm = $(clicker);
		var win = $(mover);
		if (!elm._Drag_movers) { return; }
		var index = -1;
		for (var i=0;i<elm._Drag_movers.length;i++) {
			if (elm._Drag_movers[i][0] == mover) { index = i; }
		}
		if (index == -1) { return; }
		elm._Drag_movers.splice(index,1);
	},

	removeAll:function(clicker) {
		var elm = $(clicker);
		if (elm._Drag_movers) {
			elm._Drag_movers = [];
			elm.style.cursor = elm._Drag_cursor;
		}
	},

	createDefault:function(element,useIcon) {
		if (!OAT.Preferences.allowDefaultDrag) { return; }
		var elm = $(element);
		var bg = "url(" + OAT.Preferences.imagePath + "drag.png)";
		var drag = OAT.Dom.create("div",{position:"absolute",width:"21px",height:"21px",backgroundImage:bg});
		var pos = OAT.Dom.getLT(elm);
		drag.style.left = (pos[0]-21) + "px";
		drag.style.top = (pos[1]-21) + "px";
		if (!useIcon) {
			var restrictionFunction = function(newx,newy) {
				var dims = OAT.Dom.getWH(elm);
				var parDims = OAT.Dom.getWH(elm.parentNode);
				var r = newx + dims[0];
				var b = newy + dims[1];
				return (newx < 0 || newy < 0 || r > parDims[0] || b > parDims[1]);
			}
			OAT.Drag.create(elm,elm,{restrictionFunction:restrictionFunction});
			return;
		}
		elm.parentNode.appendChild(drag);
		var restrictionFunction = function(newx,newy) {
			var dims = OAT.Dom.getWH(elm);
			var parDims = OAT.Dom.getWH(elm.parentNode);
			var r = newx + dims[0];
			var b = newy + dims[1];
			return (newx < 20 || newy < 20 || r > parDims[0] || b > parDims[1]);
		}

		OAT.Drag.create(drag,drag);
		OAT.Drag.create(drag,elm,{restrictionFunction:restrictionFunction});

		OAT.Dom.hide(drag);
		var show = function(event) {
			OAT.Dom.show(drag);
			drag._Drag_pending = 0;
		}
		var check = function() {
			if (drag._Drag_pending) {
				OAT.Dom.hide(drag);
			}
		}
		var hide = function(event) {
			drag._Drag_pending = 1;
			setTimeout(check,3000);
		}
		OAT.Event.attach(elm,"mouseover",show);
		OAT.Event.attach(elm,"mouseout",hide);
	}
}
OAT.Event.attach(document,"mousemove",OAT.Drag.move);
OAT.Event.attach(document,"mouseup",OAT.Drag.up);
