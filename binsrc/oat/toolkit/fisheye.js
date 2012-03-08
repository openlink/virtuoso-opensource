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
	f = new OAT.FishEye(div,optObj);
	var i = f.addImage(url);

	CSS: .fisheye
*/

OAT.FishEye = function(div,optObj) {
	var options = {
		smallSize:48,
		bigSize:64,
		limit:200,
		spacing:5
	}
	for (var p in optObj) { options[p] = optObj[p]; }
	var images = [];
	var self = this;
	self.div = $(div);
	OAT.Dom.addClass(self.div,"fisheye");

	self.addImage = function(url) {
		var i = OAT.Dom.create("img",{position:"absolute"});
		i.setAttribute("src",url);
		images.push(i);
		self.div.appendChild(i);
		recount(-1);
		return i;
	}

	var sizeFunction = function(dist) {
		if (dist >= options.limit) { return options.smallSize; }
//		return Math.round(options.bigSize + dist*(options.smallSize-options.bigSize)/options.limit);
		return Math.round(Math.cos((dist*Math.PI)/(options.limit*2))*(options.bigSize-options.smallSize)+options.smallSize);
	}


	var recount = function(event_x) {
		var sizes = [];
		var dists = [];
/*		if (event_x != -1 && self.lock) { return; }
		if (event_x != -1) {
			self.lock = 1;
			setTimeout(function(){self.lock=0;},200);
		} */
		for (var i=0;i<images.length;i++) {
			var img = images[i];
			if (event_x == -1) {
				var size = options.smallSize;
			} else {
				var idims = OAT.Dom.getWH(img);
				var ipos = OAT.Dom.position(img);
				var center = Math.round(ipos[0] + idims[0]/2);
				var dist = Math.abs(event_x - center);
				dists.push(dist);
				var size = sizeFunction(dist);
			}
			sizes.push(size);
		}
		var total = options.spacing;
		for (var i=0;i<images.length;i++) {
			var img = images[i];
			var size = sizes[i];
			img.style.width = size + "px";
			img.style.height = size + "px";
			img.style.left = total+"px";
			total += size;
		}
		self.div.style.width = (total+options.spacing)+"px";

	}
	self.recount = recount;

	var move = function(event) {
		var pos = OAT.Event.position(event);
		recount(pos[0]);
	}

	var over = function(event) {
		move(event);
	}

	var out = function(event) {
		recount(-1);
	}

	OAT.Event.attach(self.div,"mouseover",over);
	OAT.Event.attach(self.div,"mouseout",out);
	OAT.Event.attach(self.div,"mousemove",move);
}
