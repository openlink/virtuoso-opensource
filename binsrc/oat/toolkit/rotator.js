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
	r = new OAT.Rotator(panelX, panelY, params, callback)

	params: {
		delay:10,
		step:2,
		numLeft:2,
		pause:1000,
		type:OAT.RotatorData.TYPE_LEFT
	}

	document.body.appendChild(rotator.div);
	r.addPanel(div)
	r.start();

	OAT.RotatorData.TYPE_LEFT
	OAT.RotatorData.TYPE_RIGHT
	OAT.RotatorData.TYPE_TOP
	OAT.RotatorData.TYPE_BOTTOM



	CSS: .rotator
*/

OAT.RotatorData = {
	TYPE_LEFT:1,
	TYPE_RIGHT:2,
	TYPE_TOP:3,
	TYPE_BOTTOM:4
}

OAT.Rotator = function(panelX,panelY,paramsObj,callback) {
	var obj = this;
	this.options = {
		delay:10,
		step:2,
		numLeft:2,
		pause:1000,
		type:OAT.RotatorData.TYPE_LEFT
	}
	for (var p in paramsObj) { this.options[p] = paramsObj[p]; }
	this.div = OAT.Dom.create("div",{position:"relative",height:"0px"});
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
			case OAT.RotatorData.TYPE_LEFT:
				size = obj.options.numLeft * obj.panelX;
				obj.left -= obj.options.step;
				obj.div.style.left = obj.left+"px";
				cond = (-obj.left >= size);
			break;
			case OAT.RotatorData.TYPE_RIGHT:
				size = obj.options.numLeft * obj.panelX;
				obj.left += obj.options.step;
				obj.div.style.left = obj.left+"px";
				cond = (obj.left >= size);
			break;
			case OAT.RotatorData.TYPE_TOP:
				size = obj.options.numLeft * obj.panelY;
				obj.top -= obj.options.step;
				obj.div.style.top = obj.top+"px";
				cond = (-obj.top >= size);
			break;
			case OAT.RotatorData.TYPE_BOTTOM:
				size = obj.options.numLeft * obj.panelY;
				obj.top += obj.options.step;
				obj.div.style.top = obj.top+"px";
				cond = (obj.top >= size);
			break;
		}

		if (cond) {
			if (obj.options.type == OAT.RotatorData.TYPE_LEFT || obj.options.type == OAT.RotatorData.TYPE_TOP) {
				obj.div.appendChild(obj.div.firstChild);
			} else {
				obj.div.insertBefore(obj.div.childNodes[obj.div.childNodes.length-1],obj.div.firstChild);
			}
			switch (obj.options.type) {
				case OAT.RotatorData.TYPE_LEFT:
					obj.left += obj.panelX;
					obj.div.style.left = obj.left+"px";
				break;
				case OAT.RotatorData.TYPE_RIGHT:
					obj.left -= obj.panelX;
					obj.div.style.left = obj.left+"px";
				break;
				case OAT.RotatorData.TYPE_TOP:
					obj.top += obj.panelY;
					obj.div.style.top = obj.top+"px";
				break;
				case OAT.RotatorData.TYPE_BOTTOM:
					obj.top -= obj.panelY;
					obj.div.style.top = obj.top+"px";
				break;
			}
			obj.callback();
			if (!obj.running) { return;}
			delay = obj.options.pause;
		} /* if moving elements */
		setTimeout(obj.tick,delay);
	} /* Rotator::tick() */

	this.start = function() {
		if (obj.running) { return; }
		var pos = OAT.Dom.getLT(obj.div);
		obj.left = pos[0];
		obj.top = pos[1];
		obj.running = 1;
		setTimeout(obj.tick,obj.options.delay);
	}

	this.stop = function() { this.running = 0; }
}
