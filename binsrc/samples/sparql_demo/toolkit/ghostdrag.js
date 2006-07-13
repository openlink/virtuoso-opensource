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
	new OAT.GhostDrag()
	GhostDrag.addSource(elm,process,callback); -- we will callback(target,x,y) when this elm is successfully dragged
	GhostDrag.delSource(elm);
	GhostDrag.clearSources();
	GhostDrag.addTarget(elm);
	GhostDrag.delTarget(elm);
	GhostDrag.clearTargets();
*/

OAT.GhostDragData = {
	lock:false,

	init:function() { 
		OAT.Dom.attach(document,"mousemove",OAT.GhostDragData.move);
		OAT.Dom.attach(document,"mouseup",OAT.GhostDragData.up);
	},
	
	up:function(event) {
		if (!OAT.GhostDragData.lock) return;
		var elm = OAT.GhostDragData.lock; /* moving ghost */
		var obj = elm.object;
		if (obj.pending) {
			obj.pending = 0;
			OAT.GhostDragData.lock = false;
			return;
		}
		OAT.GhostDragData.lock = false;
		var exact = OAT.Dom.eventPos(event);
		var x = exact[0];
		var y = exact[1];
		var ok = 0;
		for (var i=0;i<obj.targets.length;i++) {
			if (!ok && OAT.GhostDragData.pos(obj.targets[i],x,y)) {
				ok = 1;
				obj.callback(obj.targets[i],x,y);
			}
		}
		if (ok) { 
			/* mouseup at correct place - remove element */
			elm.parentNode.removeChild(elm);
		} else {
			/* mouseup at wrong place - let's animate it back */
			var coords = OAT.Dom.position(obj.originalElement);
			var x = coords[0];
			var y = coords[1];
			var struct = OAT.AnimationStructure.generate(elm,OAT.AnimationData.MOVE,{"x":x,"y":y,"dist":10,"tol":10});
			var anim = new OAT.Animation(struct,10);
			anim.endFunction = function() { elm.parentNode.removeChild(elm); }
			anim.start();
		}
	}, /* OAT.GhostDragData.up() */

	move:function(event) {
		if (!OAT.GhostDragData.lock) return;
		var elm = OAT.GhostDragData.lock;
		var obj = elm.object;
		if (obj.pending) {
			/* create the duplicate */
			document.body.appendChild(elm);
			elm.style.zIndex = 2000;
			obj.process(elm);
			obj.pending = 0;
		}
		/*
			selection sukz. detect it and remove!
		*/
		var selObj = false;
		if (document.getSelection && !OAT.Dom.isGecko()) { selObj = document.getSelection(); }
		if (window.getSelection) { selObj = window.getSelection(); }
		if (document.selection) { selObj = document.selection; }
		if (selObj) {
			if (selObj.empty) { selObj.empty(); }
			if (selObj.removeAllRanges) { selObj.removeAllRanges(); }
		}

		/* ok, now move */
		var offs_x = event.clientX - elm.mouse_x;
		var offs_y = event.clientY - elm.mouse_y;
		var new_x = parseInt(OAT.Dom.style(elm,"left")) + offs_x;
		var new_y = parseInt(OAT.Dom.style(elm,"top")) + offs_y;
		elm.style.left = new_x + "px";
		elm.style.top = new_y + "px";
		elm.mouse_x = event.clientX;
		elm.mouse_y = event.clientY;
	}, /* OAT.GhostDragData.move(); */

	pos:function(elm,x_,y_) {
		/* is [x,y] inside elm ? */
		if (!elm) return 0;
		if (elm.style.display.toLowerCase() == "none") return 0;
		var coords = OAT.Dom.position(elm);
		var x = coords[0];
		var y = coords[1];
		var w = parseInt(elm.offsetWidth);
		var h = parseInt(elm.offsetHeight);
		return (x_ >= x && x_ <= x+w && y_ >= y && y_ <= y+h);
	} /* OAT.GhostDragData.pos(); */
}

OAT.GhostDrag = function() {
	var self = this;
	this.sources = [];
	this.processes = [];
	this.callbacks = [];
	this.targets = [];
	this.pending = 0; /* mouse is down, waiting for move to appear */
	
	this.addSource = function(node,process,callback) {
		var elm = $(node);
		this.sources.push(elm);
		this.processes.push(process);
		this.callbacks.push(callback);
		var index = this.sources.length-1;
		var ref = function(event) {
			/* mouse pressed on element */
			var ok = 0;
			for (var i=0;i<self.sources.length;i++) {
				if (self.sources[i] == elm) { ok = 1; }
			}
			if (!ok) return;
			var x = event.clientX;
			var y = event.clientY;
			self.startDrag(self.sources[index],self.processes[index],self.callbacks[index],x,y);
		}
		OAT.Dom.attach(elm,"mousedown",ref);
	}
	
	this.delSource = function(node) {
		var elm = $(node);
		var index = self.sources.find(elm);
		if (index == -1) { return; }
		self.sources.splice(index,1);
		self.processes.splice(index,1);
		self.callbacks.splice(index,1);
	}
	
	this.clearSources = function() {
		this.sources = [];
		this.processes = [];
		this.callbacks = [];
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
		var obj = OAT.Dom.create("div",{position:"absolute"});
		this.process = process;
		var coords = OAT.Dom.position(elm);
		obj.style.left = coords[0]+"px";
		obj.style.top = coords[1]+"px";
		obj.style.opacity = 0.5;
		obj.style.filter = "alpha(opacity=50)";
		obj.appendChild(elm.cloneNode(true));
		obj.mouse_x = x;
		obj.mouse_y = y;
		obj.object = this;
		OAT.GhostDragData.lock = obj;
	}
}

OAT.Loader.loadAttacher(OAT.GhostDragData.init);
OAT.Loader.pendingCount--;
