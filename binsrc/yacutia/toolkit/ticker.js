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
	t = new Ticker(div,text,options);
	
	options: {
		loop:TickerData.LOOP_NONE,
		add:TickerData.ADD_END,
		clear:TickerData.CLEAR_END,
		timing:TickerData.TIMING_GLOBAL,
		delay:3000,
		pause:1000
	}

	TickerData.ADD_START - add chars from start of string
	TickerData.ADD_END - add chars from end of string

	TickerData.CLEAR_ALL - clear contents when looping
	TickerData.CLEAR_START - remove chars from start
	TickerData.CLEAR_END - remove chars from end
	
	TickerData.TIMING_PERCHAR - specify delay per character
	TickerData.TIMING_GLOBAL - specify delay per string
	
	TickerData.LOOP_NONE - don't loop
	TickerData.LOOP_BACK - show and hide
	TickerData.LOOP_FULL - loop infinitely
*/

var TickerData = {
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

function Ticker(div,text,optObj) {
	var obj = this;
	this.text = text;
	this.elm = $(div);
	this.stopFlag = 0;
	this.options = {
		loop:TickerData.LOOP_NONE,
		add:TickerData.ADD_END,
		clear:TickerData.CLEAR_ALL,
		timing:TickerData.TIMING_GLOBAL,
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
			var n = (obj.options.add == TickerData.ADD_END ? obj.text.slice(0,obj.index) : obj.text.substr(obj.text.length-obj.index) );
		} else { /* backward */
			obj.index--;
			var n = (obj.options.clear == TickerData.CLEAR_END ? obj.text.slice(0,obj.index) : obj.text.substr(obj.text.length-obj.index) );
		}
		obj.elm.innerHTML = n;
		
		if (obj.index == obj.text.length) {
			if (obj.options.loop == TickerData.LOOP_FULL) {
				if (obj.options.clear == TickerData.CLEAR_ALL) {
					obj.index = 0;
				} else {
					obj.direction = -1;
				}
			}
			if (obj.options.loop == TickerData.LOOP_BACK) {
				obj.direction = -1;
			}
			delay += obj.options.pause;
		}
		
		if (obj.options.loop == TickerData.LOOP_FULL && obj.index == 0) {
			obj.direction = 1;
			delay += obj.options.pause;
		}
		
		if (obj.index == obj.text.length && obj.options.loop == TickerData.LOOP_NONE) { end = 1; }
		if (obj.index == 0 && obj.options.loop != TickerData.LOOP_FULL) { end = 1; }
		
		if (!end) { setTimeout(obj.tick,delay); }
	}
	
	this.start = function() {
		obj.direction = 1;
		obj.index = 0;
		if (obj.options.timing == TickerData.TIMING_GLOBAL) {
			obj.options.delay = Math.floor(obj.options.defDelay / obj.text.length);
		} else { obj.options.delay = obj.options.defDelay; }
		setTimeout(obj.tick,obj.options.delay);
	}
	
	this.stop = function() {
		obj.stopFlag = 1;
	}
}