/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2018 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	new OAT.GhostDrag()
	GhostDrag.addSource(elm,process,callback); -- we will callback(target,x,y) when this elm is successfully dragged
	GhostDrag.delSource(elm);
	GhostDrag.clearSources();
	GhostDrag.addTarget(elm, [customTest], [isLast]);
	GhostDrag.delTarget(elm);
	GhostDrag.clearTargets();
*/

OAT.GhostDragData = {
	lock:false,

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
		var exact = OAT.Event.position(event);
		var x = exact[0];
		var y = exact[1];
		var ok = 0;
		for (var i=0;i<obj.targets.length;i++) {
			var t = obj.targets[i];
			var test = (t[1] ? t[1](x,y) : OAT.GhostDragData.pos(t[0],x,y));
			if (!ok && test) { /* only the first gets executed! */
				ok = 1;
				obj.callback(t[0],x,y);
			}
		}
		if (ok) {
			/* mouseup at correct place - remove element */
			OAT.Dom.unlink(elm);
			OAT.MSG.send(obj,"GD_END",elm);
		} else {
			/* mouseup at wrong place - let's animate it back */
			OAT.MSG.send(obj,"GD_ABORT",elm);
			obj.onFail();
			var coords = OAT.Dom.position(obj.originalElement);
			var x = coords[0];
			var y = coords[1];
			var sf = function() { OAT.Dom.unlink(elm); }
			var anim = new OAT.AnimationPosition(elm,{speed:10,delay:10,left:x,top:y});
			OAT.MSG.attach(anim.animation,"ANIMATION_STOP",sf);
			anim.start();
		}
	}, /* OAT.GhostDragData.up() */

	move:function(event) {
		if (!OAT.GhostDragData.lock) return;
		OAT.Event.prevent(event);
		var elm = OAT.GhostDragData.lock;
		var obj = elm.object;
		if (obj.pending) {
			/* create the duplicate */
			document.body.appendChild(elm);
			elm.style.zIndex = 2000;
			if (obj.process) { obj.process(elm); }
			obj.pending = 0;
			OAT.MSG.send(obj,"GD_START",elm);
		}
		/*
			selection sukz. detect it and remove!
		*/
		OAT.Dom.removeSelection();

		/* ok, now move */
		var offs_x = event.clientX - elm.mouse_x;
		var offs_y = event.clientY - elm.mouse_y;
		var new_x = parseInt(OAT.Style.get(elm,"left")) + offs_x;
		var new_y = parseInt(OAT.Style.get(elm,"top")) + offs_y;
		elm.style.left = new_x + "px";
		elm.style.top = new_y + "px";
		elm.mouse_x = event.clientX;
		elm.mouse_y = event.clientY;
	}, /* OAT.GhostDragData.move(); */

	pos:function(elm,x_,y_) {
		/* is [x_,y_] inside elm ? */
		if (!elm) return 0;
		if (elm.style.display.toLowerCase() == "none") return 0;
		var coords = OAT.Dom.position(elm);
		var x = coords[0]-2;
		var y = coords[1]-2;
		var w = parseInt(elm.offsetWidth)+2;
		var h = parseInt(elm.offsetHeight)+2;
		return (x_ >= x && x_ <= x+w && y_ >= y && y_ <= y+h);
	} /* OAT.GhostDragData.pos(); */
}

OAT.GhostDrag = function() {
	var self = this;
	this.onFail = function(){};
	this.sources = [];
	this.processes = [];
	this.callbacks = [];
	this.targets = [];
	this.pending = 0; /* mouse is down, waiting for move to appear */

	this.addSource = function(node,process,callback) {
		var elm = $(node);
		self.sources.push(elm);
		self.processes.push(process);
		self.callbacks.push(callback);
		var cica = true;
	var ref = function(e) {
            var rclick;
	    if (!e) var e = window.event;
	    if (e.which) rclick = (e.which == 3);
	    else if (e.button) rclick = (e.button == 2);
	    if (rclick) return;
	    
            OAT.Event.prevent(e);
			var index = self.sources.indexOf(elm);
			if (index == -1) return;
	    var x = e.clientX;
	    var y = e.clientY;
			self.startDrag(self.sources[index],self.processes[index],self.callbacks[index],x,y);
		}
		OAT.Event.attach(elm,"mousedown",ref);
	}

	this.delSource = function(node) {
		var elm = $(node);
		var index = self.sources.indexOf(elm);
		if (index == -1) { return; }
		self.sources.splice(index,1);
		self.processes.splice(index,1);
		self.callbacks.splice(index,1);
	}

	this.clearSources = function() {
		self.sources = [];
		self.processes = [];
		self.callbacks = [];
	}

	this.addTarget = function(node,customTest,isLast) {
		var elm = $(node);
		var newTriple = [elm,customTest,isLast];
		if (self.targets.length && self.targets[self.targets.length-1][2]) {
			/* there is last target */
			self.targets.splice(self.targets.length-1,0,newTriple);
		} else {
			self.targets.push(newTriple);
		}
	}

	this.delTarget = function(node) {
		var elm = $(node);
		var index = -1;
		for (var i=0;i<self.targets.length;i++) {
			if (self.targets[i][0] == elm) { index = i; }
		}
		if (index == -1) { return; }
		self.targets.splice(index,1);
	}

	this.clearTargets = function() {
		self.targets = [];
	}

	this.startDrag = function(elm,process,callback,x,y) {
		if (OAT.GhostDragData.lock) { return; }
		self.pending = 1;
		self.originalElement = elm;
		self.callback = callback;
		var obj = OAT.Dom.create("div",{position:"absolute"});
		self.process = process;
		var coords = OAT.Dom.position(elm);
		obj.style.left = coords[0]+"px";
		obj.style.top = coords[1]+"px";
		OAT.Style.set(obj,{opacity:0.5});
		obj.appendChild(elm.cloneNode(true));
		obj.mouse_x = x;
		obj.mouse_y = y;
		obj.object = self;
		OAT.GhostDragData.lock = obj;
	}
}

OAT.Event.attach(document,"mousemove",OAT.GhostDragData.move);
OAT.Event.attach(document,"mouseup",OAT.GhostDragData.up);
