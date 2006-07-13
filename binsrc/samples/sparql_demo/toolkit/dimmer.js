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
	OAT.Dimmer.show(something, optObj);
	OAT.Dimmer.hide();
*/

OAT.Dimmer = {
	elm:false, /* element */
	root:false, /* root background */

	show:function(something,optObj) {
		var options = {
			color:"#000",
			opacity:0.5,
			popup:false
		}
		if (optObj) for (var p in optObj) { options[p] = optObj[p]; }
		if (OAT.Dimmer.elm) return; /* end if another is displayed */
		var elm = $(something);
		if (!elm) return;
		OAT.Dimmer.elm = elm;
		elm.oldZindex = elm.style.zIndex;
		elm.style.zIndex = 1000;
		OAT.Dimmer.root = OAT.Dom.create("div",{position:"absolute",left:"0px",top:"0px",width:"100%",height:"100%",zIndex:999});
		OAT.Dimmer.root.style.backgroundColor = options.color;
		OAT.Dimmer.root.style.opacity = options.opacity;
		OAT.Dimmer.root.style.filter = "alpha(opacity="+Math.round(100*options.opacity)+")";
		document.body.appendChild(OAT.Dimmer.root);
		document.body.appendChild(elm);
		OAT.Dom.show(elm);
		if (options.popup) { OAT.Dom.attach(OAT.Dimmer.root,"click",OAT.Dimmer.hide); }
	},
	
	hide:function() {
		if (OAT.Dimmer.root) { 
			OAT.Dom.hide(OAT.Dimmer.elm);
			OAT.Dimmer.elm.style.zIndex = OAT.Dimmer.elm.oldZindex;
			document.body.appendChild(OAT.Dimmer.elm);
			OAT.Dom.unlink(OAT.Dimmer.root);
			OAT.Dimmer.root = false;
			OAT.Dimmer.elm = false;
		} /* if shown */
	} /* hide */
}
OAT.Loader.pendingCount--;
