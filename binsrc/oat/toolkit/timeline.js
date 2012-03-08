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
	tl = new OAT.Timeline(contentDiv, paramsObj)
	paramsObj = {
		lineHeight:16,
		bandHeight:20,
		margins:200,
		sliderHeight:20,
		resize:true,
		formatter:true,
		autoHeight:true,
	}
	tl.addBand(name,color,label)
	tl.addEvent(bandName,startTime,endTime,content,color)
	tl.draw()

	.timeline .timeline_port .timeline_slider
*/

OAT.TimelineData = {
	up:function() {
		OAT.TimelineData.obj = false;
	},
	move:function(event) {
		if (!OAT.TimelineData.obj) { return; }
		var o = OAT.TimelineData.obj;
		var new_x = event.clientX;
		var dx = o.mouse_x - new_x;
		o.mouse_x = new_x;
		var new_pos = o.position + dx;
		var limit = o.slider.options.maxValue;
		if (new_pos < 0) { new_pos = 0; }
		if (new_pos > limit) { new_pos = limit; }
		o.scrollTo(new_pos);
		o.slider.slideTo(new_pos);
	}
}

OAT.TimelineEvent = function(bandIndex,startTime,endTime,content,color,options) {
	var self = this;
	this.bandIndex = bandIndex;
	this.line = 0;
	this.elm = OAT.Dom.create("div",{position:"absolute",height:options.lineHeight+"px",cursor:"pointer",zIndex:3});
	this.startTime = startTime;
	this.endTime = endTime;
	var t = (options.timeTitleOverride ? options.timeTitleOverride(startTime) : startTime.toHumanString());
	this.elm.title = t;
	content.style.position = "relative";
	this.interval = !(this.startTime.getTime() == this.endTime.getTime());
	if (this.interval) {
		if (!options.noIntervals) {
			this.intervalElm = OAT.Dom.create("div",{position:"absolute",left:"0px",top:"0px",height:"100%",backgroundColor:color});
			OAT.Style.set(this.intervalElm,{opacity:0.5});
			this.elm.appendChild(this.intervalElm);
		}
		var t = (options.timeTitleOverride ? options.timeTitleOverride(endTime) : endTime.toHumanString());
		this.elm.title += " - "+t;
	}
	this.elm.appendChild(content);
}

OAT.Timeline = function(contentElm,paramsObj) {
	var self = this;
	this.events = [];
	this.bands = {};
	this.dateLabels = [];
	this.width = 0;
	this.position = 0;
	this.options = {
		lineHeight:16, /* size of one line */
		bandHeight:20,
		margins:200, /* left & right color margins */
		sliderHeight:20,
		resize:true,
		formatter:true,
		autoHeight:true,
		noIntervals:false,
		timeStepOverride:false,
		timeTitleOverride:false,
		timeLabelOverride:false
	}

	for (var p in paramsObj) { self.options[p] = paramsObj[p]; }

	this.formatSelect = OAT.Dom.create("select",{font:"menu"});

	this.elm = OAT.Dom.create("div",{position:"absolute",top:"0px",left:"0px",className:"timeline"}); /* main axis */
	this.elm.style.zIndex = 3;
	this.content = $(contentElm);
	OAT.Dom.makePosition(self.content);

	this.port = OAT.Dom.create("div",{cursor:"w-resize",position:"relative",className:"timeline_port"});
	this.port.style.overflow = "hidden"; /* opera sux */
	this.port.style.overflowX = "hidden";
	this.port.style.overflowY = "auto";
	this.sliderElm = OAT.Dom.create("div",{position:"absolute",height:self.options.sliderHeight+"px",left:"0px",bottom:"0px",width:"100%"});
	this.sliderBtn = OAT.Dom.create("div",{className:"timeline_slider"});

	OAT.Dom.append([self.content,self.port,self.sliderElm]);

	this.sliderElm.appendChild(OAT.Dom.create("hr",{width:"100%",position:"relative",top:"4px"}));
	this.sliderElm.appendChild(this.sliderBtn);

	this.slider = new OAT.Slider(this.sliderBtn,{});

	/* dragging */
	OAT.Event.attach(this.port,"mousedown",function(event){ self.mouse_x = event.clientX; OAT.TimelineData.obj = self; });

	this.reorderEvents = function() {
		function s(a,b) { /* compare by start times */
			return a.startTime.getTime() - b.startTime.getTime();
		}
		self.events.sort(s);
	}

	this.clear = function() {
		self.events = [];
		self.bands = {};
		self.dateLabels = [];
		OAT.Dom.clear(self.elm);
		OAT.Dom.clear(self.port);
	}

	this.fixDate = function(str) {
		if (str instanceof Date) { return str; }
		var r=false;
		function dt() {
			var result = new Date();
			result.setMonth(0);
			result.setDate(1);
			return result;
		}
		if ((r = str.match(/(....)-(..)-(..) (..):(..):(..)/))) {
			var d = dt();
			d.setFullYear(r[1]);
			d.setMonth(parseInt(r[2],10)-1);
			d.setDate(r[3]);
			d.setHours(r[4]);
			d.setMinutes(r[5]);
			d.setSeconds(r[6]);
			d.setMilliseconds(0);
			return d;
		}
		if ((r = str.match(/(....)-(..)-(..)T(..):(..):(..)/))) {
			var d = dt();
			d.setFullYear(r[1]);
			d.setMonth(parseInt(r[2],10)-1);
			d.setDate(r[3]);
			d.setHours(r[4]);
			d.setMinutes(r[5]);
			d.setSeconds(r[6]);
			d.setMilliseconds(0);
			return d;
		}
		if ((r = str.match(/(....)(..)(..)T(..)(..)(..)/))) {
			var d = dt();
			d.setFullYear(r[1]);
			d.setMonth(parseInt(r[2],10)-1);
			d.setDate(r[3]);
			d.setHours(r[4]);
			d.setMinutes(r[5]);
			d.setSeconds(r[6]);
			d.setMilliseconds(0);
			return d;
		}
		if ((r = str.match(/(....)-(..)-(..)T(..):(..)/))) {
			var d = dt();
			d.setFullYear(r[1]);
			d.setMonth(parseInt(r[2],10)-1);
			d.setDate(r[3]);
			d.setHours(r[4]);
			d.setMinutes(r[5]);
			d.setSeconds(0);
			d.setMilliseconds(0);
			return d;
		}
		if ((r = str.match(/(.{1,2})\.(.{1,2})\.(....)/))) {
			var d = dt();
			d.setFullYear(r[3]);
			d.setMonth(parseInt(r[2],10)-1);
			d.setDate(r[1]);
			d.setHours(0);
			d.setMinutes(0);
			d.setSeconds(0);
			d.setMilliseconds(0);
			return d;
		}
		if ((r = str.match(/(.{4})-(.{2})-(.{2})/))) {
			var d = dt();
			d.setFullYear(r[1]);
			d.setMonth(parseInt(r[2],10)-1);
			d.setDate(r[3]);
			d.setHours(0);
			d.setMinutes(0);
			d.setSeconds(0);
			d.setMilliseconds(0);
			return d;
		}
		if ((r = str.match(/^(.{4}):(.{2}):(.{2})$/))) {
			var d = dt();
			d.setFullYear(r[1]);
			d.setMonth(parseFloat(r[2])-1);
			d.setDate(r[3]);
			d.setHours(0);
			d.setMinutes(0);
			d.setSeconds(0);
			d.setMilliseconds(0);
			return d;
		}
		var def = new Date(str);
		if (isNaN(def)) { return false; }
		return def;
	}

	this.addBand = function(name,color,label) {
		var l = (label ? label : name);
		self.bands[name] = {
			color:color,
			label:l,
			lines:[]
		}
	}

	this.addEvent = function(bandIndex,startTime,endTime,content,color) {
		var st = self.fixDate(startTime);
		if (!st) { return; } /* bad format */
		if (endTime) {
			var et = self.fixDate(endTime);
			if (!et) { return; } /* bad format */
		} else {
			var et = self.fixDate(startTime);
		}
		var e = new OAT.TimelineEvent(bandIndex,st,et,content,color,self.options);
		self.events.push(e);
		return e;
	}

	this.drawResizer = function() {
		if (!self.options.resize) { return; }
		var bg = "url(" + OAT.Preferences.imagePath + "resize.gif)";
		self.resize = OAT.Dom.create("div",{position:"absolute",width:"10px",height:"10px",right:"0px",fontSize:"1px",bottom:"0px",backgroundImage:bg});
		self.resize.style.zIndex = 6;
		self.content.appendChild(self.resize);
		OAT.Resize.create(self.resize,self.port,OAT.Resize.TYPE_Y);
		OAT.Resize.create(self.resize,self.content,OAT.Resize.TYPE_XY,function(){self.sync();});
	}
	this.drawFormatSelect = function() {
		if (!self.options.formatter) { return; }
		var div = OAT.Dom.create("div",{position:"absolute",top:"-20px",right:"1px",zIndex:5,font:"menu"});
		self.content.appendChild(div);
		div.appendChild(OAT.Dom.text("Date format: "));
		div.appendChild(self.formatSelect);
		OAT.Dom.clear(self.formatSelect);
		OAT.Dom.option("[automatic]","",self.formatSelect);
		OAT.Dom.option("[none]"," ",self.formatSelect);
		OAT.Dom.option("Year","Y",self.formatSelect);
		OAT.Dom.option("Month","m.",self.formatSelect);
		OAT.Dom.option("Month / Year","m/Y",self.formatSelect);
		OAT.Dom.option("Date","j.n.Y",self.formatSelect);
		OAT.Dom.option("Date & Time","j.n.Y H:i:s",self.formatSelect);
	}

	this.drawDateLabels = function() {
		var val = $v(self.formatSelect);
		for (var i=0;i<self.dateLabels.length;i++) {
			var elm = self.dateLabels[i];
			var f = (val == "" ? elm._format : val);
			var value = (self.options.timeLabelOverride ?
							self.options.timeLabelOverride(elm._date) :
							elm._date.format(f));
			elm.txt.innerHTML = value;
			var value = (self.options.timeTitleOverride ?
							self.options.timeTitleOverride(elm._date) :
							elm._date.toHumanString());
			elm.txt.title = value;
		}
	}
	OAT.Event.attach(self.formatSelect,"change",self.drawDateLabels);

	this.positionEvents = function() { /* main thing */
		var lastPlottedIndex = -1;
		var candidateIndex = 0;
		var pendingEnds = [];
		/* find appropriate starting time and scale */
		var first = self.events[0];
		var index = 1;
		while (index < self.events.length-1 && self.events[index].startTime.getTime() == first.startTime.getTime()) { index++; }
		if (index == self.events.length) { index--; } /* if all events at the same time */
		var scale = OAT.TlScale.findScale(first.startTime,self.events[index].startTime,false,self.options.timeStepOverride);
		var line = scale.initBefore(self.events[0].startTime);
		self.dateLabels.push(line);
		line.style.left = self.width + "px";
		self.elm.appendChild(line);
		var dims = OAT.Dom.getWH(self.port);
		/* main loop */
		do {
			/* create lineset */
			var lines = scale.generateSet();
			/* append them to timeline and plot suitable events */
			for (var i=0;i<lines.length;i++) { /* for all time intervals */
				var elm = lines[i].elm;
				self.dateLabels.push(elm);
				var startTime = lines[i].startTime;
				var endTime = lines[i].endTime;
				var width = lines[i].width;
				var resolution = width / (endTime.getTime() - startTime.getTime());

				/* available events... */
				while (candidateIndex < self.events.length && self.events[candidateIndex].startTime.getTime() <= endTime.getTime()) {
					lastPlottedIndex++; /* let's plot this event */
					var e = self.events[lastPlottedIndex];
					var delta = e.startTime.getTime() - startTime.getTime();
					var left = delta * resolution;
					e.x1 = self.width + left;
					e.elm.style.left = e.x1 + "px";
					self.elm.appendChild(e.elm);
					if (e.interval) {
						pendingEnds.push(e);
						e.x2 = -1; /* mark as todo */
					} else {
						e.x2 = e.x1;
					}
					candidateIndex++;
				}

				var done = 0;
				for (var j=0;j<pendingEnds.length;j++) {
					var e = pendingEnds[j];
					if (e.endTime.getTime() <= endTime.getTime()) {
						var delta = e.endTime.getTime() - startTime.getTime();
						var left = delta * resolution;
						e.x2 = self.width + left;
						if (!self.options.noIntervals) { e.intervalElm.style.width = (e.x2 - e.x1) + "px"; }
						done = 1;
					}
				}
				if (done) for (var j=pendingEnds.length-1;j>=0;j--) { /* remove intervals whose pending ends were drawn */
					var e = pendingEnds[j];
					if (e.x2 != -1) { pendingEnds.splice(j,1); }
				}

				self.width += width; /* increase total width */
				elm.style.left = self.width + "px";
				self.elm.appendChild(elm);
			}
			/* if needed, chage scale */
			var newscale = scale;

			if (lastPlottedIndex != self.events.length-1 && lastPlottedIndex != -1) { /* there are remaining events */
				newscale = OAT.TlScale.findScale(endTime,self.events[lastPlottedIndex+1].startTime,scale.currentTime,self.options.timeStepOverride);
			}

			/* if no events need plotting, but there are outstanding ending events, we need to change scale as well */
			if (lastPlottedIndex == self.events.length-1 && pendingEnds.length) {
				newscale = OAT.TlScale.findScale(endTime,pendingEnds[0].endTime,scale.currentTime,self.options.timeStepOverride);
			}

			scale = newscale;
		/*               there are remaining evens                     timeline is to narrow           there are pending ends    */
		} while (lastPlottedIndex < self.events.length-1 || self.width + self.options.margins < dims[0] || pendingEnds.length);
	} /* OAT.Timeline::positionEvents() */

	this.draw = function() {
		if (!self.events.length) {
			self.drawFormatSelect();
			self.drawResizer();
			self.port.style.height = (2*self.options.sliderHeight) + "px";
			return;
		} /* nothing to do */
		/* preparation */
		OAT.Dom.clear(self.elm);
		OAT.Dom.clear(self.port);
		self.port.appendChild(self.elm);
		self.reorderEvents();
		self.width = self.options.margins;
		for (var p in self.bands) {
			self.bands[p].lines = [];
		}
		self.positionEvents();
		self.width += self.options.margins;
		self.elm.style.width = self.width + "px";

		/* actualize date labels */
		self.drawDateLabels();

		/* compute lines */
		for (var i=0;i<self.events.length;i++) { self.computeLine(self.events[i]); }

		/* adjust heights */
		var startingHeights = {};
		var headerHeights = {};
		var total = 0;
		for (var p in self.bands) {
			startingHeights[p] = total;
			var bh = self.bands[p].lines.length * self.options.lineHeight;
			/* band heading */
			headerHeights[p] = (self.bands[p].label ? self.options.bandHeight : 0);
			var elm = OAT.Dom.create("div",{zIndex:4,position:"absolute",width:"100%",left:"0px",top:(total-1)+"px",textAlign:"center",fontWeight:"bold",className:"timeline_band_header"});
			elm.style.borderTop = "1px solid #000";
			if (self.bands[p].color) { elm.style.backgroundColor = self.bands[p].color; }
			elm.style.height = (self.options.bandHeight+1) + "px";
			elm.innerHTML = self.bands[p].label;
			if (self.bands[p].label) { self.port.appendChild(elm); }
			/* band */
			var elm = OAT.Dom.create("div",{zIndex:1,position:"absolute",left:"0px",width:"100%",className:"timeline_band"});
			if (self.bands[p].color) { elm.style.backgroundColor = self.bands[p].color; }
//			elm.style.borderBottom = "1px solid #000";
			elm.style.top = (total + headerHeights[p]) + "px";
			elm.style.height = bh + "px";
			if (OAT.Browser.isGecko) { elm.style.height = (bh-1) + "px"; }
			self.elm.appendChild(elm);
			total += bh + headerHeights[p];
		}
		for (var i=0;i<self.events.length;i++) {
			var e = self.events[i];
			var top = startingHeights[e.bandIndex] + e.line * self.options.lineHeight + headerHeights[e.bandIndex];
			e.elm.style.top = top + "px";
		}
		total += 2 * self.options.lineHeight;
		if (self.options.autoHeight) {
			self.port.style.height = total + "px";
			self.elm.style.height = "100%";
			self.content.style.height = (total+self.options.sliderHeight)+"px";
		} else {
			self.elm.style.height = total + "px";
			var dims = OAT.Dom.getWH(self.content);
			self.port.style.height = (dims[1]-self.options.sliderHeight)+"px";
		}

		/* sync slider */
		self.slider.options.minValue = 0;
		self.slider.options.minPos = 0;
		self.sync();
		/* slide to center */
		self.slider.options.initValue = Math.round(self.slider.options.maxValue / 2);
		self.slider.init();

		self.drawFormatSelect();
		self.drawResizer();
	}

	this.computeLine = function(event) {
		/* find free line */
		var free = -1;
		var x1 = event.x1;
		var x2 = event.x2;
		var a = self.bands[event.bandIndex].lines;
		for (var i=0;i<a.length;i++) {
			var l = a[i];
			if (free == -1 && x1 > l+40) { free = i; }
		}
		/* if not free, add to end */
		if (free == -1) {
			free = a.length;
			a.push(0);
		}
		event.line = free;
		/* mark as occupied */
		var w = event.elm.offsetWidth;
		a[free] = Math.max(x2,x1+w);
	}

	this.sync = function() {
		var dims = OAT.Dom.getWH(self.port);
		var sdims = OAT.Dom.getWH(self.sliderBtn);
		self.slider.options.maxValue = self.width - dims[0];
		self.slider.options.maxPos = dims[0] - sdims[0];
		if (self.slider.valueToPosition(self.slider.value) > self.slider.options.maxPos) { self.slider.slideTo(self.slider.options.maxValue,true); }
		var pos = parseInt(self.slider.elm.style[self.slider.options.cssProperty]);
		if (pos > self.slider.options.maxPos) { self.slider.slideTo(self.slider.options.maxValue,true); }
	}

	this.scrollTo = function(pixel) {
		self.position = pixel;
		self.elm.style.left = (-self.position) + "px";
	}
	this.slider.onchange = self.scrollTo;

}
OAT.Event.attach(document,"mouseup",OAT.TimelineData.up);
OAT.Event.attach(document,"mousemove",OAT.TimelineData.move);
