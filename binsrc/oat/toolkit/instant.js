/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2014 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	var i = new OAT.Instant(element,callback)
	i.show()
	i.hide()

	i.createHandle(handleID)
	i.removeHandle(handleID)
*/

OAT.Instant = function(element, optObj) {
	var self = this;
	this.options = {
		showCallback:false,
		hideCallback:false
	}

	for (var p in optObj) { self.options[p] = optObj[p]; }
	this.state = 1;
	this.elm = $(element);
	this.handles = [];

	this.hide = function() {
		self.state = 0;
		OAT.Dom.hide(self.elm);
	}

	this.show = function() {
		if (self.options.showCallback) { self.options.showCallback(); }
		OAT.Dom.show(self.elm);
		self.state = 1;
	}

	this.check = function(event) {
		/* element shown, checking where user clicked */
		if (!self.state) { return; }
		var node = OAT.Event.source(event);
		if (node == self.elm || OAT.Dom.isChild(node,self.elm)) { return; } /* clicked in element -> not hiding */

		if (self.options.hideCallback) { self.options.hideCallback(); }
		self.hide();
	}

	this.createHandle = function(elm) {
		var e = $(elm);
		self.handles.push(e);
		OAT.Event.attach(e,"mousedown",function(event) {
			if (self.handles.find(e) == -1) { return; }
			if (!self.state) {
				OAT.Event.cancel(event);
				self.show();
			}
		});
	}

	this.removeHandle = function(elm) {
		var e = $(elm);
		var i = self.handles.find(e);
		if (i != -1) { self.handles.splice(i,1); }
	}

	self.elm._Instant_show = self.show;
	self.elm._Instant_hide = self.hide;
	self.hide();
	OAT.Event.attach(document,"mousedown",self.check);

}

OAT.Instant.assign = function(something, callback) { /* backward compatibility */
	var obj = new OAT.Instant(something, {hideCallback:callback});
}
