/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2018 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	t = new OAT.Ticker(div,text,options);

	options: {
		loop:OAT.TickerData.LOOP_NONE,
		add:OAT.TickerData.ADD_END,
		clear:OAT.TickerData.CLEAR_END,
		timing:OAT.TickerData.TIMING_GLOBAL,
		delay:3000,
		pause:1000
	}

	OAT.TickerData.ADD_START - add chars from start of string
	OAT.TickerData.ADD_END - add chars from end of string

	OAT.TickerData.CLEAR_ALL - clear contents when looping
	OAT.TickerData.CLEAR_START - remove chars from start
	OAT.TickerData.CLEAR_END - remove chars from end

	OAT.TickerData.TIMING_PERCHAR - specify delay per character
	OAT.TickerData.TIMING_GLOBAL - specify delay per string

	OAT.TickerData.LOOP_NONE - don't loop
	OAT.TickerData.LOOP_BACK - show and hide
	OAT.TickerData.LOOP_FULL - loop infinitely
*/

OAT.TickerData = {
	ADD_START:1,
	ADD_END:2,

	CLEAR_ALL:1,
	CLEAR_START:2,
	CLEAR_END:3,

	TIMING_PERCHAR:1,
	TIMING_GLOBAL:2,

	LOOP_NONE:1,
	LOOP_BACK:2,
	LOOP_FULL:3
}

OAT.Ticker = function(div,text,optObj) {
	var obj = this;
	this.text = text;
	this.elm = $(div);
	this.stopFlag = 0;
	this.options = {
		loop:OAT.TickerData.LOOP_NONE,
		add:OAT.TickerData.ADD_END,
		clear:OAT.TickerData.CLEAR_ALL,
		timing:OAT.TickerData.TIMING_GLOBAL,
		defDelay:3000,
		pause:1000
	}
	for (p in optObj) { this.options[p] = optObj[p]; }

	this.setText = function(text) { this.text = text; }

	this.tick = function() {
		if (obj.stopFlag) { obj.stopFlag = 0; return; }
		var delay = obj.options.delay;
		var end = 0;
		var old = obj.elm.innerHTML;
		if (obj.direction == 1) { /* forward */
			obj.index++;
			var n = (obj.options.add == OAT.TickerData.ADD_END ? obj.text.slice(0,obj.index) : obj.text.substr(obj.text.length-obj.index) );
		} else { /* backward */
			obj.index--;
			var n = (obj.options.clear == OAT.TickerData.CLEAR_END ? obj.text.slice(0,obj.index) : obj.text.substr(obj.text.length-obj.index) );
		}
		obj.elm.innerHTML = n;

		if (obj.index == obj.text.length) {
			if (obj.options.loop == OAT.TickerData.LOOP_FULL) {
				if (obj.options.clear == OAT.TickerData.CLEAR_ALL) {
					obj.index = 0;
				} else {
					obj.direction = -1;
				}
			}
			if (obj.options.loop == OAT.TickerData.LOOP_BACK) {
				obj.direction = -1;
			}
			delay += obj.options.pause;
		}

		if (obj.options.loop == OAT.TickerData.LOOP_FULL && obj.index == 0) {
			obj.direction = 1;
			delay += obj.options.pause;
		}

		if (obj.index == obj.text.length && obj.options.loop == OAT.TickerData.LOOP_NONE) { end = 1; }
		if (obj.index == 0 && obj.options.loop != OAT.TickerData.LOOP_FULL) { end = 1; }

		if (!end) { setTimeout(obj.tick,delay); }
	}

	this.start = function() {
		obj.direction = 1;
		obj.index = 0;
		if (obj.options.timing == OAT.TickerData.TIMING_GLOBAL) {
			obj.options.delay = Math.floor(obj.options.defDelay / obj.text.length);
		} else { obj.options.delay = obj.options.defDelay; }
		setTimeout(obj.tick,obj.options.delay);
	}

	this.stop = function() {
		obj.stopFlag = 1;
	}
}
