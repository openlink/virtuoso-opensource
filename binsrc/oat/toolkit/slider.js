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
	s = new Slider(something,optObj)
	s.slideTo(50)
	s.onchange = function(value)
*/

OAT.SliderData = {
	obj:false,
	mouse_x:0,
	mouse_y:0,
	initPos:0,
	DIR_H:1,
	DIR_V:2,

	move:function(event) {
		if (!OAT.SliderData.obj) { return; }
		var o = OAT.SliderData.obj;
		var delta = 0;
		if (o.options.direction == OAT.SliderData.DIR_H) { delta = event.clientX - OAT.SliderData.mouse_x; }
		if (o.options.direction == OAT.SliderData.DIR_V) { delta = event.clientY - OAT.SliderData.mouse_y; }
		var newpos = delta + OAT.SliderData.initPos;
		var newval = o.positionToValue(newpos);
		if (newval >= o.options.minValue && newval <= o.options.maxValue && newval != o.value) { o.slideTo(newval,true); }
	},
	up:function() {
		OAT.SliderData.obj = false;
	}
}

OAT.Slider = function(something,optObj) {
	var self = this;
	this.value = 0;
	this.options = {
		minValue:0,
		maxValue:100,
		initValue:50,
		minPos:0,
		maxPos:200,
		cssProperty:"left",
		direction:OAT.SliderData.DIR_H
	}
	this.elm = $(something);

	if (optObj) for (var p in optObj) { this.options[p] = optObj[p]; }

	this.valueToPosition = function(value) {
		var o = self.options;
		var pos = o.minPos + (o.maxPos - o.minPos) * (value - o.minValue) / (o.maxValue - o.minValue);
		return Math.round(pos);
	}

	this.positionToValue = function(position) {
		var o = self.options;
		var val = o.minValue + (o.maxValue - o.minValue) * (position - o.minPos) / (o.maxPos - o.minPos);
		return Math.round(val);
	}

	this.slideTo = function(value,forward) {
		self.value = value;
		var pos = self.valueToPosition(value);
		self.elm.style[self.options.cssProperty] = pos + "px";
		if (forward) { self.onchange(value); }
	}

	this.onchange = function(value) {}

	var startRef = function(event) {
		OAT.SliderData.obj = self;
		OAT.SliderData.mouse_x = event.clientX;
		OAT.SliderData.mouse_y = event.clientY;
		OAT.SliderData.initPos = parseInt(self.elm.style[self.options.cssProperty]);
	}

	OAT.Event.attach(self.elm,"mousedown",startRef);

	this.init = function() {
		self.slideTo(self.options.initValue,true);
	}
}

OAT.Event.attach(document,"mousemove",OAT.SliderData.move);
OAT.Event.attach(document,"mouseup",OAT.SliderData.up);
