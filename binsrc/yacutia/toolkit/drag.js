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
	Drag.create(clicker,mover,options)
	Drag.remove(clicker,mover)
	Drag.removeAll(clicker)
*/

var Drag = {
	TYPE_X:1,
	TYPE_Y:2,
	TYPE_XY:3,
	elm:[],
	mouse_x:0,
	mouse_y:0,
	
	init:function() {
		Dom.attach(document,"mousemove",Drag.move);
		Dom.attach(document,"mouseup",Drag.up);
	},
	
	move:function(event) {
		if (!Drag.elm.length) return;
		var dx = event.clientX - Drag.mouse_x;
		var dy = event.clientY - Drag.mouse_y;
		for (var i=0;i<Drag.elm.length;i++) {
			var element = Drag.elm[i][0];
			var options = Drag.elm[i][1];
			switch (options.type) {
				case Drag.TYPE_X: Dom.moveBy(element,dx,0); break;
				case Drag.TYPE_Y: Dom.moveBy(element,0,dy); break;
				case Drag.TYPE_XY: Dom.moveBy(element,dx,dy); break;
			}
			if (options.restrictionFunction()) {
				/* undo */
				switch (options.type) {
					case Drag.TYPE_X: Dom.moveBy(element,-dx,0); break;
					case Drag.TYPE_Y: Dom.moveBy(element,0,-dy); break;
					case Drag.TYPE_XY: Dom.moveBy(element,-dx,-dy); break;
				}
			}
		}
		Drag.mouse_x = event.clientX;
		Drag.mouse_y = event.clientY;
	},
	
	up:function(event) {
		Drag.elm = [];
	},

	create:function(clicker,mover,optObj) {
		var options = {
			type:Drag.TYPE_XY,
			restrictionFunction:function(){return false;}
		}
		if (optObj) for (p in optObj) { options[p] = optObj[p]; }
		var elm = $(clicker);
		var win = $(mover);
		var ref = function(event) {
			Drag.elm = elm._Drag_movers;
			Drag.mouse_x = event.clientX;
			Drag.mouse_y = event.clientY;
		}
		if (!elm._Drag_movers) { 
			Dom.attach(elm,"mousedown",ref);		
			elm._Drag_movers = [];
			elm._Drag_cursor = elm.style.cursor;
		}
		elm.style.cursor = "move";
		elm._Drag_movers.push([win,options]);
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
	}
	
}
Loader.loadAttacher(Drag.init);
