/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2009 OpenLink Software
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
	win:false, /* when using window (OAT.Win) as dimmer */
	winSourceElm:false, /* source element */

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
			popup:false,
			delay:10,
			type:false, /* see OAT.Win window types */
			title:'', /* use with options.type */
			status:'', /* use with options.type */
			top:150, /* use with options.type */
			left:300, /* use with options.type */
			width:'400' /* use with options.type */
		}
		for (var p in optObj) { options[p] = optObj[p]; }
		var elm = $(something);
		OAT.Dimmer.winSourceElm = elm;
		if (!elm) return;
		if (options.type) { /* create new window according to type */
			OAT.Dimmer.win = new OAT.Win({type:options.type,stackGroupBase:false,status:options.status,title:options.title,outerWidth:'auto',y:options.top,x:options.left,outerWidth:options.width});
 			OAT.Dimmer.win.dom.content.innerHTML = elm.innerHTML;
			elm.innerHTML = '';
			OAT.Dom.attach(OAT.Dimmer.win.dom.buttons.c,'click',OAT.Dimmer.hide);
			OAT.Dimmer.win.dom.container.setAttribute('id',elm.getAttribute('id'));
			elm.setAttribute('id','');
			elm = OAT.Dimmer.win.dom.container;
		}
		OAT.Dimmer.elm = elm;
		elm.oldZindex = elm.style.zIndex;
		elm.style.zIndex = 1000;
		OAT.Dimmer.root = OAT.Dom.create("div",{position:"fixed",left:"0px",top:"0px",width:"100%",height:"100%",zIndex:999});
		if (OAT.Browser.isIE6) { 
			OAT.Dimmer.root.style.position = "absolute"; 
			OAT.Dimmer.update();
		} 

		OAT.Dimmer.root.style.backgroundColor = options.color;
		OAT.Style.opacity(OAT.Dimmer.root,0);
		OAT.Dimmer.root.appendChild(elm);
		document.body.appendChild(OAT.Dimmer.root);
		elm.style.position = 'absolute';
		document.body.appendChild(elm);
		OAT.Dom.show(elm);
		if (options.popup) { OAT.Dom.attach(OAT.Dimmer.root,"click",OAT.Dimmer.hide); }
		
		if (options.delay && OAT.Loader.loadedLibs.find("animation") != -1) {
			var a = new OAT.AnimationOpacity(OAT.Dimmer.root,{opacity:options.opacity,delay:options.delay,speed:0.1});
			a.start();
		} else { 
			OAT.Style.opacity(OAT.Dimmer.root,options.opacity);
		}
	},
	
	hide:function() {
		if (!OAT.Dimmer.root) { return; }
		OAT.Dom.hide(OAT.Dimmer.elm);
		OAT.Dimmer.elm.style.zIndex = OAT.Dimmer.elm.oldZindex;
		document.body.appendChild(OAT.Dimmer.elm);
		if (OAT.Dimmer.win) {
			OAT.Dimmer.winSourceElm.innerHTML = OAT.Dimmer.win.dom.content.innerHTML;
			OAT.Dimmer.winSourceElm.setAttribute('id',OAT.Dimmer.win.dom.container.getAttribute('id'));
			OAT.Dimmer.win.dom.container.setAttribute('id','');
			OAT.Dom.clear(OAT.Dimmer.win.dom.container);
			OAT.Dom.unlink(OAT.Dimmer.win.dom.container);
			OAT.Dimmer.win = false;
		}
		OAT.Dom.unlink(OAT.Dimmer.root);
		OAT.Dimmer.root = false;
		OAT.Dimmer.elm = false;
		OAT.Dimmer.winSourceElm = false;
	} /* hide */
}
if (OAT.Browser.isIE6) { 
	OAT.Dom.attach(window,'resize',OAT.Dimmer.update); 
	OAT.Dom.attach(window,'scroll',OAT.Dimmer.update); 
}
OAT.Loader.featureLoaded("dimmer");
