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
	OAT.Dimmer.show(something, optObj);
	OAT.Dimmer.hide();
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
		if (OAT.Dimmer.elm) return; /* end if another is displayed */
		var options = {
			color:"#000",
			opacity:0.5,
			popup:false
		}
		for (var p in optObj) { options[p] = optObj[p]; }
		var elm = $(something);
		if (!elm) return;
		OAT.Dimmer.elm = elm;
		elm.oldZindex = elm.style.zIndex;
		elm.style.zIndex = 1000;
		OAT.Dimmer.root = OAT.Dom.create("div",{position:"fixed",left:"0px",top:"0px",width:"100%",height:"100%",zIndex:999});
		if (OAT.Browser.isIE6) { 
			OAT.Dimmer.root.style.position = "absolute"; 
			OAT.Dimmer.update();
		} 

		OAT.Dimmer.root.style.backgroundColor = options.color;
		OAT.Style.opacity(OAT.Dimmer.root,options.opacity);
		document.body.appendChild(OAT.Dimmer.root);
		document.body.appendChild(elm);
		OAT.Dom.show(elm);
		if (options.popup) { OAT.Dom.attach(OAT.Dimmer.root,"click",OAT.Dimmer.hide); }
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
if (OAT.Browser.isIE6) { 
	OAT.Dom.attach(window,'resize',OAT.Dimmer.update); 
	OAT.Dom.attach(window,'scroll',OAT.Dimmer.update); 
}
OAT.Loader.featureLoaded("dimmer");
