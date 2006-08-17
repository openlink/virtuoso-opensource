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

	OAT.Layers.addLayer(something,activationEvent)
	OAT.Layers.removeLayer(someting)
*/

OAT.Layers = {
	baseOffset:100,
	layers:[],
	currentIndex:0,
	
	raise:function(elm) {
		var index = OAT.Layers.layers.find(elm);
		if (index == -1) { return; }
		var curr = elm.style.zIndex;
		for (var i=0;i<OAT.Layers.layers.length;i++) {
			var e = OAT.Layers.layers[i];
			if (e.style.zIndex > curr) { e.style.zIndex--; }
		}
		elm.style.zIndex = OAT.Layers.currentIndex;
	},

	addLayer:function(something,activationEvent) {
		var elm = $(something);
		if (!elm) { return; }
		OAT.Layers.currentIndex++;
		elm.style.zIndex = OAT.Layers.currentIndex;
		OAT.Layers.layers.push(elm);
		var event = (activationEvent ? activationEvent : "mousedown");
		OAT.Dom.attach(elm,event,function(){OAT.Layers.raise(elm);});
	},
	
	removeLayer:function(something) {
		var elm = $(something);
		var index = OAT.Layers.layers.find(elm);
		if (index == -1) { return; }
		OAT.Layers.layers.splice(index,1);
	}
	
}
OAT.Layers.currentIndex = OAT.Layers.baseOffset;
OAT.Loader.pendingCount--;
