/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2015 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	OAT.Notify.send(content, optObj);
*/

OAT.Notify = function(parentDiv,optObj) {
	var self = this;
    this.types = {POPUP: 0, BAR: 1, PUSHBAR: 2};

	this.options = {
		x:-1,
	y:-1,
	notifyType: 1
    };

	for (var p in optObj) { self.options[p] = optObj[p]; }

	this.parentDiv = parentDiv || document.body;
	this.container = false;
	this.cx = 0;
	this.cy = 0;
    this.visible = false;
    this.content = false;

	this.update = function() {
		var scroll = OAT.Dom.getScroll();
		var dims = OAT.Dom.getViewport();
		with (self.container.style) {
			left = (self.cx + scroll[0]) + "px";
			top = (self.cy + scroll[1]) + "px";
		}
	}

    this.createPopupContainer = function (width, height) {
		var pos = OAT.Dom.getLT(self.parentDiv);
		var dim = OAT.Dom.getWH(self.parentDiv);

		if(self.options.x == -1) {
			self.cx = Math.round( pos[0] + (dim[0] - width ) / 2 );
		} else {
			self.cx = pos[0] + self.options.x;
		}

		if(self.options.y == -1) {
			self.cy = Math.round( pos[1] + (dim[1] - height) / 2 );
		} else {
			self.cy = pos[1] + self.options.y;
		}

	var c = OAT.Dom.create("div", {className: "notify_popup_ctr", 
				       position: "fixed", 
				       top: self.cy + "px", 
				       left: self.cx + "px"});

		if (OAT.Browser.isIE6) {
			c.style.position = "absolute";
			OAT.Event.attach(window,'resize',self.update);
			OAT.Event.attach(window,'scroll',self.update);
			self.update();
		}

	return c;
    }
    
    this.createBarContainer = function () { 
	var pos = OAT.Dom.getLT(self.parentDiv);
	var dim = OAT.Dom.getWH(self.parentDiv);
	
	c = OAT.Dom.create("div", {className: "notify_bar_ctr",
				       position: "fixed",
				       top: 0,
				       left: 0,
				       width: "100%", //dim[0]+"px"
				       "z-index": 5000});
	return c;
    }

    this.createPushBarContainer = function () { 
	var pos = OAT.Dom.getLT(self.parentDiv);
	var dim = OAT.Dom.getWH(self.parentDiv);
	
	var c = OAT.Dom.create("div", {className: "notify_bar_ctr",
				       top: 0,
				       left: 0,
				       width: "100%", //dim[0]+"px",
				       "z-index": 5000});
	return c;
	}

	this.send = function(content, optObj) {
		var options = {
			image:false, /* url */
			padding:"2px", /* of container */
			background:"#ccc", /* of container */
			color:"#000", /* of container */
			style:false, /* custom properties for text */
			opacity:0.8,
			delayIn:50, /* when fading in */
			delayOut:50, /* when fading out */
			timeout:2000, /* how long will be visible? */
			width:300,
			height:50
		}

	if (self.visible) { 
	    var c = $(content);
	    if (!c) { // new text
		self.content.innerHTML = content;
	    }
	    else { // DOM frag as content. Need to replace existing
		OAT.Dom.unlink(self.content);
		self.content = c;
	    }
	    return;
	}

		for (var p in optObj) { options[p] = optObj[p]; }

	switch (self.options.notifyType) {
	case self.types.POPUP:
	    if (!self.container) {
		var c = self.createPopupContainer (options.width, options.height); 
		self.container = c;
		self.parentDiv.appendChild(self.container);
	    }
	    self.inner = OAT.Dom.create ("div", {width: options.width + "px", 
						height: options.height + "px", 
						cursor: "pointer",
						overflow: "hidden",
						marginBottom: "2px",
						padding: options.padding,
						backgroundColor: options.background,
						color: options.color});
	    
	    break;
	case self.types.BAR:
	    if (!self.container) {
		var c = self.createBarContainer (options.height);
		self.container = c;
		self.parentDiv.appendChild(self.container);
	    }
	    
	    self.inner = OAT.Dom.create ("div", {className: "notify_bar_inner",
						width:    "100%", // should be same width as the container
						cursor:   "pointer",
						overflow: "hidden",
						backgroundColor:options.background,
						color: options.color});
	    break;
	case self.types.PUSHBAR:
	    if (!self.container) {
		var c = self.createPushBarContainer (options.height);
		self.container = c;
		self.parentDiv.insertBefore (self.container,self.parentDiv.firstChild);
	    }
	    
	    self.inner = OAT.Dom.create ("div", {className: "notify_bar_inner",
						width:    "100%", // should be same width as the container
						cursor:   "pointer",
						overflow: "hidden",
						backgroundColor:options.background,
						color: options.color});
	    break;
	}
	
	if (options.image) { /* image */
	    var img = OAT.Dom.create ("img", {cssFloat: "left", 
					      styleFloat:"left", 
					      marginRight: "2px"});
	    img.src = options.image;
	    self.inner.appendChild(img);
	}

	var ct = $(content);
	if (!ct) {
	    self.content = OAT.Dom.create("div", {className: "notify_content"});
	    self.content.innerHTML = content;
		}
	
	if (options.style) { OAT.Style.set (self.c, options.style); }

	self.inner.appendChild(self.content);

	if (options.close) {
	    var close_img = OAT.Dom.create ("img", {cssFloat:"right", styleFloat:"right"});
	    img.src = options.close;
	    self.inner.appendChild(close_img);
		}

	OAT.Style.set(self.inner, {opacity:0});

		var afterAppear = function() {
			if (!options.timeout) { return; }
			setTimeout(function() {
		if (self.inner.parentNode) { self.aDisappear.start(); }
			},options.timeout);
		}

	self.aAppear =    new OAT.AnimationOpacity (self.inner, {opacity:options.opacity, speed:0.1, delay:options.delayIn});
	self.aDisappear = new OAT.AnimationOpacity (self.inner, {opacity:0, speed:0.1, delay:options.delayOut});
	self.aRemove =    new OAT.AnimationSize (self.inner, {height:0, speed:10, delay:options.delayOut});
	
	OAT.MSG.attach (self.aRemove.animation, "ANIMATION_STOP", function() { OAT.Dom.unlink (self.inner); OAT.Dom.hide (self.container)});
	OAT.MSG.attach (self.aAppear.animation, "ANIMATION_STOP", afterAppear);
	OAT.MSG.attach (self.aDisappear.animation, "ANIMATION_STOP", self.aRemove.start);

	OAT.Event.attach (self.inner,"click",function() {
			if (options.delayOut) {
		self.aRemove.start();
			} else {
		OAT.Dom.unlink(self.inner);
			}
		});

		var start = function() {
	    self.visible = true;
	    self.container.appendChild (self.inner);
	    OAT.Dom.show (self.container);
			if (options.delayIn) {
		self.aAppear.start();
			} else {
				OAT.Style.set(div,{opacity:options.opacity});
				afterAppear();
			}
		}
	
		var end = function() {
			aAppear.stop();
		}

		start();
	}

    this.hide = function () {
	self.visible = false;
	self.aDisappear.start();
    }
}
