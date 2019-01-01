/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2019 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	OAT.Dimmer.show(something, optObj);
	OAT.Dimmer.hide();
*/

/**
 * @class Shows an object while dimming others, i.e., a Lightbox effect.
 */
OAT.Dimmer = {
	elm:false, /* element */
	root:false, /* root background */

	update:function(event) {
		if (!OAT.Dimmer.root) { return; }
		var scroll = OAT.Dom.getScroll();
		var dims = OAT.Dom.getViewport();
		with (OAT.Dimmer.root.style) {
			left = scroll[0]+"px";
			top = scroll[1]+"px";
			width = dims[0]+"px";
			height = dims[1]+"px";
		}
	},

	show:function(something,optObj) {
		if (OAT.Dimmer.elm) { return; } /* end if another is displayed */
		var options = {
			color: "#000",
			opacity: 0.5,
			popup: false,
			delay: 10
		}
		for (var p in optObj) { options[p] = optObj[p]; }
		var elm = $(something);
		if (!elm) return;
		OAT.Dimmer.elm = elm;
		elm.oldZindex = elm.style.zIndex;
		elm.style.zIndex = 1000;
		OAT.Dimmer.root = OAT.Dom.create("div",{position:"absolute",left:"0px",top:"0px",width:"100%",height:"100%",zIndex:999});
		OAT.Dimmer.root.style.backgroundColor = options.color;
		OAT.Style.set(OAT.Dimmer.root,{opacity:0});
		OAT.Dimmer.root.appendChild(elm);
		document.body.appendChild(OAT.Dimmer.root);
		elm.style.position = 'absolute';
		document.body.appendChild(elm);
		OAT.Dom.show(elm);
		if (options.popup) { OAT.Event.attach(OAT.Dimmer.root,"click",OAT.Dimmer.hide); }

		if (options.delay && OAT.Loader.isLoaded("animation")) {
			var a = new OAT.AnimationOpacity(OAT.Dimmer.root,{opacity:options.opacity,delay:options.delay,speed:0.1});
			a.start();
		} else {
			OAT.Style.set(OAT.Dimmer.root,{opacity:options.opacity});
		}
	},

	hide:function() {
		if (!OAT.Dimmer.root) { return; }
		OAT.Dom.hide(OAT.Dimmer.elm);
		OAT.Dimmer.elm.style.zIndex = OAT.Dimmer.elm.oldZindex;
		document.body.appendChild(OAT.Dimmer.elm);
		OAT.Dom.unlink(OAT.Dimmer.root);
		OAT.Dimmer.root = false;
		OAT.Dimmer.elm = false;
	} /* hide */
}

OAT.Event.attach(window, 'resize', OAT.Dimmer.update);
OAT.Event.attach(window, 'scroll', OAT.Dimmer.update);
