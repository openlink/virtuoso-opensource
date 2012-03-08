/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2012 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	var tc = new OAT.TagCloud(elm, optObj);
	tc.clearItems();
	tc.addItem(name,link,frequency = 1);
	tc.draw();
*/

OAT.TagCloudData = {
	COLOR_SIZE:0,
	COLOR_CYCLE:1,
	COLOR_RANDOM:2
}

OAT.TagCloud = function(elm, optObj) {
	var self = this;
	this.options = {
		separator:" ",
		colors:["#f00","#0f0","#00f"],
		sizes:["80%","100%","120%"],
		colorMapping:OAT.TagCloudData.COLOR_SIZE
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }
	this.elm = $(elm);

	this.items = {};
	this.min = 0;
	this.max = 0;

	this.getColor = function(item,index) {
		var count = self.options.colors.length;
		switch (self.options.colorMapping) {
			case OAT.TagCloudData.COLOR_SIZE:
				var piece = (self.max - self.min) / count;
				var f = item.freq;
				var idx = Math.floor((f-self.min) / piece);
				if (idx >= count) { idx--; }
				return self.options.colors[idx];
			break;
			case OAT.TagCloudData.COLOR_CYCLE:
				return self.options.colors[index % count];
			break;
			case OAT.TagCloudData.COLOR_RANDOM:
				var idx = Math.floor(Math.random()*count);
				return self.options.colors[idx];
			break;
		}
	}

	this.getSize = function(item,index) {
		var count = self.options.sizes.length;
		var piece = (self.max - self.min) / count;
		var f = item.freq;
		var idx = Math.floor((f-self.min) / piece);
		if (idx >= count) { idx--; }
		return self.options.sizes[idx];
	}

	this.clearItems = function() {
		this.items = {};
		this.min = 99999;
		this.max = 0
	}

	this.addItem = function(name,link,frequency) {
		var freq = frequency || 1;
		if (name in self.items) {
			var o = self.items[name];
		} else {
			var o = {
				link:link,
				freq:0
			}
			self.items[name] = o;
		}
		o.freq += freq;
		if (o.freq > self.max) { self.max = o.freq; }
		if (o.freq < self.min) { self.min = o.freq; }
	}

	this.draw = function() {
		OAT.Dom.clear(self.elm);
		var counter = 0;
		for (var p in self.items) {
			var item = self.items[p];
			var a = OAT.Dom.create("a");
			a.href = item.link;
			a.innerHTML = p;
			var color = self.getColor(item,counter);
			var size = self.getSize(item,counter);
			if (color) { a.style.color = color; }
			if (size) { a.style.fontSize = size; }
			self.elm.appendChild(a);
			var separator = self.elm.appendChild(OAT.Dom.text(self.options.separator));
			counter++;
		}
		OAT.Dom.unlink(separator);
	}

	this.clearItems();
}
