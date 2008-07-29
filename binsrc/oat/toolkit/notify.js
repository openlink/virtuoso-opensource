/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2008 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	OAT.Notify.send(content, optObj);
*/

OAT.Notify = function(parentDiv,optObj) {
	var self = this;
	this.options = {
		x:-1,
		y:-1
	}

	for (var p in optObj) { self.options[p] = optObj[p]; }

	this.parentDiv = parentDiv || document.body;
	this.container = false; 
	this.cx = 0;
	this.cy = 0;

	
	this.update = function() {
		var scroll = OAT.Dom.getScroll();
		var dims = OAT.Dom.getViewport();
		with (self.container.style) {
			left = (self.cx + scroll[0]) + "px";
			top = (self.cy + scroll[1]) + "px";
		}
	}
	
	this.createContainer = function(width,height) {
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
		
		var c = OAT.Dom.create("div",{position:"fixed", top: self.cy + "px", left: self.cx + "px"});
		self.container = c;
		self.parentDiv.appendChild(c);


		if (OAT.Browser.isIE6) { 
			c.style.position = "absolute"; 
			OAT.Event.attach(window,'resize',self.update); 
			OAT.Event.attach(window,'scroll',self.update); 
			self.update();
		} 
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
		for (var p in optObj) { options[p] = optObj[p]; }

		if (!self.container) { self.createContainer(options.width,options.height); }
		
		var c = $(content);
		if (!c) { 
			c = OAT.Dom.create("div");
			c.innerHTML = content; 
		}
		if (options.style) { OAT.Style.apply(c,options.style); }

		var div = OAT.Dom.create("div",{width:options.width+"px",height:options.height+"px",cursor:"pointer",overflow:"hidden",marginBottom:"2px",padding:options.padding,backgroundColor:options.background,color:options.color});
		if (options.image) { /* image */
			var img = OAT.Dom.create("img",{cssFloat:"left",styleFloat:"left",marginRight:"2px"});
			img.src = options.image;
			div.appendChild(img); 
		}
		div.appendChild(c);
		OAT.Style.opacity(div,0);

		var afterAppear = function() {
			if (!options.timeout) { return; }
			setTimeout(function() {
				if (div.parentNode) { aDisappear.start(); }
			},options.timeout);
		}
		
		var aAppear = new OAT.AnimationOpacity(div,{opacity:options.opacity,speed:0.1,delay:options.delayIn});
		var aDisappear = new OAT.AnimationOpacity(div,{opacity:0,speed:0.1,delay:options.delayOut});
		var aRemove = new OAT.AnimationSize(div,{height:0,speed:10,delay:options.delayOut});
		OAT.MSG.attach(aRemove.animation,OAT.MSG.ANIMATION_STOP,function(){	OAT.Dom.unlink(div); });
		OAT.MSG.attach(aAppear.animation,OAT.MSG.ANIMATION_STOP,afterAppear);
		OAT.MSG.attach(aDisappear.animation,OAT.MSG.ANIMATION_STOP,aRemove.start);
		
		
		OAT.Event.attach(div,"click",function() {
			if (options.delayOut) {
				aRemove.start();
			} else {
				OAT.Dom.unlink(div);
			}
		});

		var start = function() {
			self.container.appendChild(div);
			if (options.delayIn) { 
				aAppear.start(); 
			} else { 
				OAT.Style.opacity(div,options.opacity); 
				afterAppear();
			}
		}
		var end = function() {
			aAppear.stop();
		}
		
		start();
	}

		
}
OAT.Loader.featureLoaded("notify");
