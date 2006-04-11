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
	Dimmer.show(something, optObj);
	Dimmer.hide();
*/

var Dimmer = {
	elm:false, /* element */
	root:false, /* root background */

	show:function(something,optObj) {
		var options = {
			color:"#000",
			opacity:0.5,
			popup:false
		}
		if (optObj) for (var p in optObj) { options[p] = optObj[p]; }
		if (Dimmer.elm) return; /* end if another is displayed */
		var elm = $(something);
		if (!elm) return;
		Dimmer.elm = elm;
		elm.style.display = "block"; /* show element */
		elm.oldZindex = elm.style.zIndex;
		elm.style.zIndex = 1000;
		Dimmer.root = Dom.create("div",{position:"absolute",left:"0px",top:"0px",width:"100%",height:"100%",zIndex:999});
		Dimmer.root.style.backgroundColor = options.color;
		Dimmer.root.style.opacity = options.opacity;
		Dimmer.root.style.filter = "alpha(opacity="+Math.round(100*options.opacity)+")";
		document.body.appendChild(Dimmer.root);
		document.body.appendChild(elm);
		if (options.popup) { Dom.attach(Dimmer.root,"click",Dimmer.hide); }
	},
	
	hide:function() {
		if (Dimmer.root) { 
			Dimmer.elm.style.display = "none";
			Dimmer.elm.style.zIndex = Dimmer.elm.oldZindex;
			document.body.appendChild(Dimmer.elm);
			Dom.unlink(Dimmer.root);
			Dimmer.root = false;
			Dimmer.elm = false;
		} /* if shown */
	} /* hide */
}
