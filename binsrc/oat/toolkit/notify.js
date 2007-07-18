/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2007 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	OAT.Notify.send(content, optObj);
*/

OAT.Notify = {
	container:false,
	update:function() {
		var scroll = OAT.Dom.getScroll();
		var dims = OAT.Dom.getViewport();
		with (OAT.Notify.container.style) {
			right = (-scroll[0])+"px";
			top = scroll[1]+"px";
		}
	},
	createContainer:function() {
		var c = OAT.Dom.create("div",{position:"fixed",top:"0px",right:"0px"});
		document.body.appendChild(c);
		OAT.Notify.container = c;
		if (OAT.Browser.isIE6) { 
			c.style.position = "absolute"; 
			OAT.Notify.update();
		} 
	},
	send:function(content, optObj) {
		if (!OAT.Notify.container) { OAT.Notify.createContainer(); }
		var options = {
			image:false, /* url */
			padding:"2px", /* of container */
			background:"#ccc", /* of container */
			color:"#000", /* of container */
			style:false, /* custom properties for text */
			opacity:0.8,
			delay:50, /* when fading in/out */
			timeout:2000, /* how long will be visible? */
			width:300,
			height:50
		}
		for (var p in optObj) { options[p] = optObj[p]; }
		
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
		
		var aAppear = new OAT.AnimationOpacity(div,{opacity:options.opacity,speed:0.1,delay:options.delay});
		var aDisappear = new OAT.AnimationOpacity(div,{opacity:0,speed:0.1,delay:options.delay});
		var aRemove = new OAT.AnimationSize(div,{height:0,speed:10,delay:options.delay});
		OAT.MSG.attach(aRemove.animation,OAT.MSG.ANIMATION_STOP,function(){	OAT.Dom.unlink(div); });
		OAT.MSG.attach(aAppear.animation,OAT.MSG.ANIMATION_STOP,afterAppear);
		OAT.MSG.attach(aDisappear.animation,OAT.MSG.ANIMATION_STOP,aRemove.start);
		
		
		OAT.Event.attach(div,"click",function() {
			if (options.delay) {
				aRemove.start();
			} else {
				OAT.Dom.unlink(div);
			}
		});
		
		var start = function() {
			OAT.Notify.container.appendChild(div);
			if (options.delay) { 
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
if (OAT.Browser.isIE6) { 
	OAT.Event.attach(window,'resize',OAT.Notify.update); 
	OAT.Event.attach(window,'scroll',OAT.Notify.update); 
}
OAT.Loader.featureLoaded("notify");
