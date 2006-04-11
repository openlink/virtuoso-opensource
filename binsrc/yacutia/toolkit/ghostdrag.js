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
	new GhostDrag()
	GhostDrag.addSource(elm,process,callback); -- we will callback(target,x,y) when this elm is successfully dragged
	GhostDrag.delSource(elm);
	GhostDrag.clearSources();
	GhostDrag.addTarget(elm);
	GhostDrag.delTarget(elm);
	GhostDrag.clearTargets();
*/

var GhostDragData = {
	lock:false,

	init:function() { 
		Dom.attach(document,"mousemove",GhostDragData.move);
		Dom.attach(document,"mouseup",GhostDragData.up);
	},
	
	up:function(event) {
		if (!GhostDragData.lock) return;
		var elm = GhostDragData.lock; /* moving ghost */
		var obj = elm.object;
		if (obj.pending) {
			obj.pending = 0;
			GhostDragData.lock = false;
			return;
		}
		GhostDragData.lock = false;
		var x = document.body.scrollLeft+event.clientX;
		var y = document.body.scrollTop+event.clientY;
		var ok = 0;
		for (var i=0;i<obj.targets.length;i++) {
			if (!ok && GhostDragData.pos(obj.targets[i],x,y)) {
				ok = 1;
				obj.callback(obj.targets[i],x,y);
			}
		}
		if (ok) { 
			/* mouseup at correct place - remove element */
			elm.parentNode.removeChild(elm);
		} else {
			/* mouseup at wrong place - let's animate it back */
			var coords = Dom.position(obj.originalElement);
			var x = coords[0];
			var y = coords[1];
			var struct = AnimationStructure.generate(elm,AnimationData.MOVE,{"x":x,"y":y,"dist":10,"tol":10});
			var anim = new Animation(struct,10);
			anim.endFunction = function() { elm.parentNode.removeChild(elm); }
			anim.start();
		}
	}, /* GhostDragData.up() */

	move:function(event) {
		if (!GhostDragData.lock) return;
		var elm = GhostDragData.lock;
		var obj = elm.object;
		if (obj.pending) {
			/* create the duplicate */
			document.body.appendChild(elm);
			obj.process(elm);
			obj.pending = 0;
		}
		/*
			selection sukz. detect it and remove!
		*/
		var selObj = false;
		if (document.getSelection && !Dom.isGecko()) { selObj = document.getSelection(); }
		if (window.getSelection) { selObj = window.getSelection(); }
		if (document.selection) { selObj = document.selection; }
		if (selObj) {
			if (selObj.empty) { selObj.empty(); }
			if (selObj.removeAllRanges) { selObj.removeAllRanges(); }
		}

		/* ok, now move */
		var offs_x = event.clientX - elm.mouse_x;
		var offs_y = event.clientY - elm.mouse_y;
		var new_x = parseInt(Dom.style(elm,"left")) + offs_x;
		var new_y = parseInt(Dom.style(elm,"top")) + offs_y;
		elm.style.left = new_x + "px";
		elm.style.top = new_y + "px";
		elm.mouse_x = event.clientX;
		elm.mouse_y = event.clientY;
	}, /* GhostDragData.move(); */

	pos:function(elm,x_,y_) {
		/* is [x,y] inside elm ? */
		if (!elm) return 0;
		if (elm.style.display.toLowerCase() == "none") return 0;
		var coords = Dom.position(elm);
		var x = coords[0];
		var y = coords[1];
		var w = parseInt(elm.offsetWidth);
		var h = parseInt(elm.offsetHeight);
		return (x_ >= x && x_ <= x+w && y_ >= y && y_ <= y+h);
	} /* GhostDragData.pos(); */
}

function GhostDrag() {
	this.sources = [];
	this.targets = [];
	this.pending = 0; /* mouse is down, waiting for move to appear */
	
	this.addSource = function(node,process,callback) {
		var elm = $(node);
		this.sources[this.sources.length] = elm;
		var gd = this;
		var ref = function(event) {
			/* mouse pressed on element */
			var ok = 0;
			for (var i=0;i<gd.sources.length;i++) {
				if (gd.sources[i] == elm) { ok = 1; }
			}
			if (!ok) return;
			var x = event.clientX;
			var y = event.clientY;
			gd.startDrag(elm,process,callback,x,y);
		}
		Dom.attach(elm,"mousedown",ref);
	}
	
	this.delSource = function(node) {
		var elm = $(node);
		for (var i=0;i<this.sources.length;i++) {
			if (this.sources[i] == elm) { this.sources[i] = false; }
		}
	}
	
	this.clearSources = function() {
		this.sources = [];
	}
	
	this.addTarget = function(node) {
		var elm = $(node);
		this.targets[this.targets.length] = elm;
	}
	
	this.delTarget = function(node) {
		var elm = $(node);
		for (var i=0;i<this.targets.length;i++) {
			if (this.targets[i] == elm) { this.targets[i] = false; }
		}
	}

	this.clearTargets = function() {
		this.targets = [];
	}

	this.startDrag = function(elm,process,callback,x,y) {
		this.pending = 1;
		this.originalElement = elm;
		this.callback = callback;
		var obj = Dom.create("div",{position:"absolute"});
		this.process = process;
		var coords = Dom.position(elm);
		obj.style.left = coords[0]+"px";
		obj.style.top = coords[1]+"px";
		obj.style.opacity = 0.5;
		obj.style.filter = "alpha(opacity=50)";
		obj.appendChild(elm.cloneNode(true));
		obj.mouse_x = x;
		obj.mouse_y = y;
		obj.object = this;
		GhostDragData.lock = obj;
	}
}

Loader.loadAttacher(GhostDragData.init);
