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
	OAT.SVG.canvas(w,h)
	OAT.SVG.element(name,{attrObj});
*/
OAT.SVG = {
	ns:"http://www.w3.org/2000/svg",
	canvas:function(w,h) {
		var elm = OAT.Dom.createNS(OAT.SVG.ns,"svg");
		elm.setAttribute("width",w ? w : 300);
		elm.setAttribute("height",h ? h : 200);
		return elm;
	},
	element:function(name,attrObj) {
		var elm = OAT.Dom.createNS(OAT.SVG.ns,name);
		for (var p in attrObj) { elm.setAttribute(p,attrObj[p]); }
		return elm;
	}
}
