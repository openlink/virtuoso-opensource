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
	a = new OAT.Animation(element,optObj)
	a = new OAT.AnimationSize(element,optObj)
	a = new OAT.AnimationPosition(element,optObj)
	a = new OAT.AnimationOpacity(element,optObj)
	a = new OAT.AnimationCSS(element,optObj)
	a.start()
	a.stop()
*/

/**
 * @class Implements basic animation framework, as well as some pre-defined animation effects.
 * @message ANIMATION_STOP animation finished
 */
OAT.Animation = function(element, optionsObject) { /* periodic executer */
	var self = this;
	this.elm = $(element);
	this.options = {
		delay:50,
		startFunction:function() {},
		conditionFunction:function() {},
		stepFunction:function() {},
		stopFunction:function() {}
	}
	for (var p in optionsObject) { self.options[p] = optionsObject[p]; }

	this.step = function() {
		var callback = function() {
			if (!self.running) return;
			if (self.options.conditionFunction(self)) {
				self.running = 0;
				self.options.stopFunction(self);
				OAT.MSG.send(self, "ANIMATION_STOP" ,self);
			} else {
				self.options.stepFunction(self);
				self.step(self);
			}
		} /* callback */
		setTimeout(callback,self.options.delay);
	}

	this.start = function() {
		self.running = 1;
		self.options.startFunction(self);
		self.step();
	}

	this.stop = function() {
		self.running = 0;
	}
}

OAT.AnimationSize = function(element, optionsObject) {
	var self = this;
	this.options = {
		width:-1,
		height:-1,
		delay:50,
		speed:1
	}
	for (var p in optionsObject) { self.options[p] = optionsObject[p]; }

	var o = {delay:self.options.delay};

	o.startFunction = function(a) { /* prepare step */
		a.stepX = 0;
		a.stepY = 0;
		var dims = OAT.Dom.getWH(a.elm);
		a.width = dims[0];
		a.height = dims[1];

		a.diffX = (self.options.width == -1 ? 0 : self.options.width - dims[0]);
		a.diffY = (self.options.height == -1 ? 0 : self.options.height - dims[1]);

		a.signX = (a.diffX >= 0 ? 1 : -1);
		a.signY = (a.diffY >= 0 ? 1 : -1);

		var dx = a.diffX * a.diffX;
		var dy = a.diffY * a.diffY;

		a.stepX = a.signX * Math.sqrt( self.options.speed * self.options.speed * dx / (dx + dy) );
		a.stepY = a.signY * Math.sqrt( self.options.speed * self.options.speed * dy / (dx + dy) );
	}
	o.stopFunction = function(a) {
		if (self.options.width != -1) { a.elm.style.width = self.options.width + "px"; }
		if (self.options.height != -1) { a.elm.style.height = self.options.height + "px"; }
	}
	o.conditionFunction = function(a) {
		var ok_w = (a.signX > 0 ? a.width >= self.options.width : a.width <= self.options.width);
		var ok_h = (a.signY > 0 ? a.height >= self.options.height : a.height <= self.options.height);
		if (self.options.width == -1) { ok_w = 1; }
		if (self.options.height == -1) { ok_h = 1; }
		return (ok_w && ok_h);
	}
	o.stepFunction = function(a) {
		a.width += a.stepX;
		a.height += a.stepY;
		var w = parseInt(a.width);
		var h = parseInt(a.height);
		if (self.options.width != -1) { a.elm.style.width = (w >= 0 ? w : 0) + "px"; ; }
		if (self.options.height != -1) { a.elm.style.height = (h >= 0 ? h : 0) + "px"; ; }
	}
	this.animation = new OAT.Animation(element,o);

	this.start = self.animation.start;
	this.stop = self.animation.stop;
}

OAT.AnimationPosition = function(element, optionsObject) {
	var self = this;
	this.options = {
		left:-1,
		top:-1,
		delay:50,
		speed:1
	}
	for (var p in optionsObject) { self.options[p] = optionsObject[p]; }

	var o = {delay:self.options.delay};

	o.startFunction = function(a) { /* prepare step */
		a.stepX = 0;
		a.stepY = 0;
		var pos = OAT.Dom.getLT(a.elm);
		a.left = pos[0];
		a.top = pos[1];

		a.diffX = (self.options.left == -1 ? 0 : self.options.left - pos[0]);
		a.diffY = (self.options.top == -1 ? 0 : self.options.top - pos[1]);

		a.signX = (a.diffX >= 0 ? 1 : -1);
		a.signY = (a.diffY >= 0 ? 1 : -1);

		var dx = a.diffX * a.diffX;
		var dy = a.diffY * a.diffY;

		a.stepX = a.signX * Math.sqrt( self.options.speed * self.options.speed * dx / (dx + dy) );
		a.stepY = a.signY * Math.sqrt( self.options.speed * self.options.speed * dy / (dx + dy) );
	}
	o.stopFunction = function(a) {
		if (self.options.left != -1) { a.elm.style.left = self.options.left + "px"; }
		if (self.options.top != -1) { a.elm.style.top = self.options.top + "px"; }
	}
	o.conditionFunction = function(a) {
		var ok_l = (a.signX > 0 ? a.left >= self.options.left : a.left <= self.options.left);
		var ok_t = (a.signY > 0 ? a.top >= self.options.top : a.top <= self.options.top);
		if (self.options.left == -1) { ok_l = 1; }
		if (self.options.top == -1) { ok_t = 1; }
		return (ok_l && ok_t);
	}
	o.stepFunction = function(a) {
		a.left += a.stepX;
		a.top += a.stepY;
		var l = parseInt(a.left);
		var t = parseInt(a.top);
		if (self.options.left != -1) { a.elm.style.left = l + "px"; ; }
		if (self.options.top != -1) { a.elm.style.top = t + "px"; ; }
	}
	this.animation = new OAT.Animation(element,o);

	this.start = self.animation.start;
	this.stop = self.animation.stop;
}

OAT.AnimationOpacity = function(element, optionsObject) {
	var self = this;
	this.options = {
		opacity:1,
		delay:50,
		speed:0.1
	}
	for (var p in optionsObject) { self.options[p] = optionsObject[p]; }

	var o = {delay:self.options.delay};

	o.startFunction = function(a) { /* prepare step */
		a.opacity = 1;
		if (OAT.Browser.isGecko) { a.opacity = parseFloat(OAT.Style.get(a.elm,"opacity")); }
		if (OAT.Browser.isIE6) {
			var filter = OAT.Style.get(a.elm,"filter");
			var num = filter.match(/alpha\(opacity=([^\)]+)\)/);
			if (num) { a.opacity = parseFloat(num[1])/100; }
		}
		a.step_ = 1;
		a.diff = self.options.opacity - a.opacity;
		a.sign = (a.diff >= 0 ? 1 : -1);
		a.step_ = a.sign * self.options.speed;
	}
	o.stopFunction = function(a) {
		OAT.Style.set(a.elm,{opacity:self.options.opacity});
	}
	o.conditionFunction = function(a) {
		var ok = (a.sign > 0 ? a.opacity+0.0001 >= self.options.opacity : a.opacity-0.0001 <= self.options.opacity);
		return ok;
	}
	o.stepFunction = function(a) {
		a.opacity += a.step_;
		OAT.Style.set(a.elm,{opacity:a.opacity});
	}
	this.animation = new OAT.Animation(element,o);

	this.start = self.animation.start;
	this.stop = self.animation.stop;
}

OAT.AnimationCSS = function(element, optionsObject) {
	var self = this;
	this.options = {
		delay:50,
		property:false,
		start:0,
		step:1,
		stop:10
	}
	for (var p in optionsObject) { self.options[p] = optionsObject[p]; }

	var o = {delay:self.options.delay};

	o.startFunction = function(a) { /* prepare step */
		a[self.options.property] = self.options.start;
		a.elm.style[self.options.property] = self.options.start;
	}
	o.stopFunction = function(a) {
		a.elm.style[self.options.property] = self.options.stop;
	}
	o.conditionFunction = function(a) {
		var ok = (a[self.options.property] == self.options.stop);
		return ok;
	}
	o.stepFunction = function(a) {
		a[self.options.property] += self.options.step;
		a.elm.style[self.options.property] = a[self.options.property];
	}
	this.animation = new OAT.Animation(element,o);

	this.start = self.animation.start;
	this.stop = self.animation.stop;
}
