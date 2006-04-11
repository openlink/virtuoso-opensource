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
	r = new Rotator(panelX, panelY, params, callback)
	
	params: {
		delay:10,
		step:2,
		numLeft:2,
		pause:1000,
		type:RotatorData.TYPE_LEFT
	}
	
	document.body.appendChild(rotator.div);
	r.addPanel(div)
	r.start();
	
	RotatorData.TYPE_LEFT
	RotatorData.TYPE_RIGHT
	RotatorData.TYPE_TOP
	RotatorData.TYPE_BOTTOM
	
	

	CSS: .rotator
*/

var RotatorData = {
	TYPE_LEFT:1,
	TYPE_RIGHT:2,
	TYPE_TOP:3,
	TYPE_BOTTOM:4
}

function Rotator(panelX,panelY,paramsObj,callback) {
	var obj = this;
	this.options = {
		delay:10,
		step:2,
		numLeft:2,
		pause:1000,
		type:RotatorData.TYPE_LEFT
	}
	for (var p in paramsObj) { this.options[p] = paramsObj[p]; }
	this.div = Dom.create("div",{position:"relative",height:"0px"});
	this.div.className = "rotator";
	this.firstTime = 1;
	this.left = 0;
	this.top = 0;
	this.running = 0;
	this.callback = callback;
	this.panelX = panelX;
	this.panelY = panelY;
	
	this.addPanel = function(div) {
		var elm = $(div);
		this.div.appendChild(elm);
	}
	
	this.tick = function() {
		var delay = obj.options.delay;
		var size = 0;
		var cond;
		switch (obj.options.type) {
			case RotatorData.TYPE_LEFT: 
				size = obj.options.numLeft * obj.panelX;
				obj.left -= obj.options.step;
				obj.div.style.left = obj.left+"px";
				cond = (-obj.left >= size);
			break;
			case RotatorData.TYPE_RIGHT: 
				size = obj.options.numLeft * obj.panelX;
				obj.left += obj.options.step;
				obj.div.style.left = obj.left+"px";
				cond = (obj.left >= size);
			break;
			case RotatorData.TYPE_TOP: 
				size = obj.options.numLeft * obj.panelY;
				obj.top -= obj.options.step;
				obj.div.style.top = obj.top+"px";
				cond = (-obj.top >= size);
			break;
			case RotatorData.TYPE_BOTTOM: 
				size = obj.options.numLeft * obj.panelY;
				obj.top += obj.options.step;
				obj.div.style.top = obj.top+"px";
				cond = (obj.top >= size);
			break;
		}
		
		if (cond) {
			if (obj.options.type == RotatorData.TYPE_LEFT || obj.options.type == RotatorData.TYPE_TOP) {
				obj.div.appendChild(obj.div.firstChild);
			} else {
				obj.div.insertBefore(obj.div.childNodes[obj.div.childNodes.length-1],obj.div.firstChild);
			}
			switch (obj.options.type) {
				case RotatorData.TYPE_LEFT: 
					obj.left += obj.panelX;
					obj.div.style.left = obj.left+"px";
				break;
				case RotatorData.TYPE_RIGHT: 
					obj.left -= obj.panelX;
					obj.div.style.left = obj.left+"px";
				break;
				case RotatorData.TYPE_TOP: 
					obj.top += obj.panelY;
					obj.div.style.top = obj.top+"px";
				break;
				case RotatorData.TYPE_BOTTOM: 
					obj.top -= obj.panelY;
					obj.div.style.top = obj.top+"px";
				break;
			}
			obj.callback();
			delay = obj.options.pause;
		} /* if moving elements */
		setTimeout(obj.tick,delay);
	} /* Rotator::tick() */
	
	this.start = function() {
		if (obj.running) { return; }
		var pos = Dom.getLT(obj.div);
		obj.left = pos[0];
		obj.top = pos[1];
		obj.running = 1;
		setTimeout(obj.tick,obj.options.delay);
	}
	
	this.stop = function() { this.running = 0; }
}