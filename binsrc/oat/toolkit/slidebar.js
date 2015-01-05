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
	var slb = new OAT.Slidebar (div,
								{ 	autoClose,		true,
									autoCloseDelay,	1000,
									XXX: has no effect yet: position,		"right",
									width,			300,
									handleWidth		10,
									handleOpenImg,	"handle_open.png",
									handleCloseImg,	"handle_close.png",
									imgPrefix,		"i/",
									animSpeed, 		10});
	slb.open ();
	slb.close ();

	CSS: slidebar, slb_handle, slb_handle_img, slb_content

	requires OAT.AnimationSize

	Messages: OAT.MSG.SLB_OPENED, OAT.MSG.SLB_CLOSED

	The widget creates a new container div.slb_content and moves the original DIVs contents to it.

	TODO add left, top, bottom slide bars

*/

OAT.Slidebar = function (div, optionsObj) {

	this.div = $(div);
	var self = this;

	this.sb_to = 0;			/* Timeout to close when autoClose = true */

	this.options = {
		autoClose: 		true,
		autoCloseDelay:	2000, // milliseconds
//		position:		"right",
		width:			300,
		handleWidth:	10,
		handleOpenImg:	"handle_open.png",
		handleCloseImg:	"handle_close.png",
		imgPrefix:		"i/",
		animSpeed:		10
	}
//	called onmouseover

	this.activate = function () {
		clearTimeout (self.sb_to);
	}

// 	called onmouseout

	this.deactivate = function () {
		clearTimeout (self.sb_to);
		self.sb_to = setTimeout (self.close, self.options.autoCloseDelay);
	}

	this.close = function () {
		clearTimeout (self.sb_to);
		OAT.Event.detach (self.handle_div, "click", self.close);
		OAT.Style.set (self.content_div, {overflow : "hidden"});
		self.a_close.start ();
	}

	this.open = function () {
		clearTimeout (self.sb_to);
		OAT.Event.detach (self.handle_div, "click", self.open);
		self.a_open.start ();
	}

	this.opened = function (source, message, event) {

		if (self.options.autoClose) {
			OAT.Event.attach (self.content_div, "mouseover", self.activate);
			OAT.Event.attach (self.div, "mouseout", self.deactivate);
		}

		OAT.Event.attach (self.handle_div, "click", self.close);
		OAT.Style.set (self.content_div, {overflow : "auto"});
		self.handle_close();
		OAT.MSG.send (self, "SLB_OPENED", self);
	}

	this.closed = function (source, message, event) {

// console.log ("sb_closed handler called.");

		if (self.options.autoClose) {
			OAT.Event.detach (self.content_div, "mouseover", self.activate);
			OAT.Event.detach (self.div, "mouseout", self.deactivate);
		}

		OAT.Event.attach (self.handle_div, "click", self.open);
		self.handle_open();
		OAT.MSG.send(self, "SLB_CLOSED", self);
	}

	this.center_handle_img = function () {
		OAT.Dom.center (self.handle_img, false, true);
	}

	this.handle_open = function () {
		self.handle_img.src = self.options.imgPrefix + self.options.handleOpenImg;
	}

	this.handle_close = function () {
		self.handle_img.src = self.options.imgPrefix + self.options.handleCloseImg;
	}

// Initialization

	for (var p in optionsObj) {
	    this.options[p] = optionsObj[p];
	}

	OAT.Dom.addClass (this.div, "slidebar");

// Create container

	this.content_div = document.createElement ("div");
	this.content_div.className = "slb_content";

// Copy original contents to new inner container

	var l = this.div.childNodes.length;

    for (i = 0; i < l; i++) {
    	this.content_div.appendChild (this.div.firstChild);
    }

	this.handle_div  = document.createElement ("div");
	this.handle_div.className = "slb_handle";

	this.handle_img  = document.createElement ("img");
	this.handle_img.className = "slb_handle_img";
	this.handle_img.setAttribute ("alt", "Handle image");

//	move orig. div contents to the container


	this.div.appendChild (this.content_div);
	this.div.appendChild (this.handle_div);
	this.handle_div.appendChild (this.handle_img);

	this.a_open = 	new OAT.AnimationSize (this.div,
										   {width:self.options.width,
										   	speed:self.options.animSpeed,
										   	delay:7});

	this.a_close = 	new OAT.AnimationSize (this.div,
										   {width:self.options.handleWidth,
										   	speed:self.options.animSpeed,
										   	delay:7});

	this.handle_img.src = this.options.imgPrefix+this.options.handleOpenImg;

	OAT.Event.attach (this.handle_div, "click", this.open);

	OAT.MSG.attach (this.a_open.animation, "ANIMATION_STOP", this.opened);
	OAT.MSG.attach (this.a_close.animation, "ANIMATION_STOP", this.closed);

	this.center_handle_img ();

	OAT.Event.attach (window, "resize", this.center_handle_img);
	OAT.Style.set (this.content_div, {overflow : "hidden"});


}
