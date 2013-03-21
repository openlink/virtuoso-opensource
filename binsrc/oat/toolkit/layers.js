/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2013 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*

	var l = new OAT.Layers(baseOffset);
	l.addLayer(something,activationEvent)
	l.removeLayer(something)
*/

OAT.Layers = function(baseOffset) {
	var self = this;
	this.baseOffset = baseOffset;
	this.layers = [];
	this.currentIndex = 0;

	this.raise = function(elm) {
		var index = self.layers.find(elm);
		if (index == -1) { return; }
		var curr = elm.style.zIndex;
		for (var i=0;i<self.layers.length;i++) {
			var e = self.layers[i];
			if (e.style.zIndex > curr) { e.style.zIndex--; }
		}
		elm.style.zIndex = self.currentIndex;
	}

	this.addLayer = function(something,activationEvent) {
		var elm = $(something);
		if (!elm) { return; }
		self.currentIndex++;
		elm.style.zIndex = self.currentIndex;
		self.layers.push(elm);
		var event = (activationEvent ? activationEvent : "mousedown");
		OAT.Event.attach(elm,event,function(){self.raise(elm);});
	}

	this.removeLayer = function(something) {
		var elm = $(something);
		var index = self.layers.find(elm);
		if (index == -1) { return; }
		self.layers.splice(index,1);
	}

	self.currentIndex = self.baseOffset;
}
