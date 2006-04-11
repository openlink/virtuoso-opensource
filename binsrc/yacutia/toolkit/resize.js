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
	Resize.create(clicker,mover,type)
	Resize.remove(clicker,mover)
	Resize.removeAll(clicker)
	Resize.TYPE_X
	Resize.TYPE_Y
	Resize.TYPE_XY
*/

var Resize = {
	TYPE_X:1,
	TYPE_Y:2,
	TYPE_XY:3,
	element:[],
	mouse_x:0,
	mouse_y:0,
	
	init:function() {
		Dom.attach(document,"mousemove",Resize.move);
		Dom.attach(document,"mouseup",Resize.up);
	},
	
	move:function(event) {
		if (!Resize.element.length) return;
		var dx = event.clientX - Resize.mouse_x;
		var dy = event.clientY - Resize.mouse_y;
		for (var i=0;i<Resize.element.length;i++) {
			var element = Resize.element[i][0];
			switch (Resize.element[i][1]) {
				case Resize.TYPE_X:
					Dom.resizeBy(element,dx,0);
				break;
				case Resize.TYPE_Y:
					Dom.resizeBy(element,0,dy);
				break;
				case Resize.TYPE_XY:
					Dom.resizeBy(element,dx,dy);
				break;
			} /* switch */
		} /* for all resizing elements */
		Resize.mouse_x = event.clientX;
		Resize.mouse_y = event.clientY;
	},
	
	up:function(event) {
		Resize.element = [];
	},

	create:function(clicker,mover,type) {
		var elm = $(clicker);
		var win = $(mover);
		switch (type) {
			case Resize.TYPE_XY: elm.style.cursor = "nw-resize"; break;
			case Resize.TYPE_X: elm.style.cursor = "w-resize"; break;
			case Resize.TYPE_Y: elm.style.cursor = "n-resize"; break;
		}
		var ref = function(event) {
			Resize.element = elm._Resize_movers;
			Resize.mouse_x = event.clientX;
			Resize.mouse_y = event.clientY;
			event.cancelBubble = true;
		}
		if (!elm._Resize_movers) { 
			Dom.attach(elm,"mousedown",ref);		
			elm._Resize_movers = [];
		}
		elm._Resize_movers.push([win,type]);
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
	}

}
Loader.loadAttacher(Resize.init);
