/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2006 Ondrej Zara and OpenLink Software
 *
 *  See LICENSE file for details.
 */
 
/*
	tl = new OAT.Timeline(portDiv, sliderDiv, paramsObj)
	paramsObj = {
		portWidth:800,
		lineHeight:16,
		bandHeight:20,
		bandColor:"#fff",
		margins:200
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

OAT.TimelineEvent = function(bandIndex,startTime,endTime,content,color) {
	var self = this;
	this.bandIndex = bandIndex;
	this.line = 0;
	this.elm = OAT.Dom.create("div",{position:"absolute",cursor:"pointer",zIndex:3});
	this.startTime = startTime;
	this.endTime = endTime;
	this.elm.title = startTime.toHumanString();
	content.style.position = "relative";
	this.interval = !(this.startTime.getTime() == this.endTime.getTime());
	if (this.interval) {
		this.intervalElm = OAT.Dom.create("div",{position:"absolute",left:"0px",top:"0px",height:"100%",backgroundColor:color,opacity:"0.5"});
		this.intervalElm.style.filter = "alpha(opacity=50)";
		this.elm.appendChild(this.intervalElm);
		this.elm.title += " - "+endTime.toHumanString();
	} 
	this.elm.appendChild(content);
}

OAT.Timeline = function(portElm,sliderElm,paramsObj) {
	var self = this;
	this.events = [];
	this.bands = {};
	this.dateLabels = [];
	this.width = 0;
	this.position = 0;
	this.options = {
		portWidth:800, /* size of viewport */
		lineHeight:16, /* size of one line */
		bandHeight:20,
		bandColor:"#fff",
		margins:200, /* left & right color margins */
		resize:true,
		formatter:true
	}

	for (var p in paramsObj) { self.options[p] = paramsObj[p]; }
	
	this.formatSelect = OAT.Dom.create("select",{font:"menu"});
	
	this.elm = OAT.Dom.create("div",{position:"absolute",top:"0px",left:"0px",height:"100%"}); /* main axis */
	this.elm.style.backgroundColor = self.options.bandColor;
	this.elm.style.zIndex = 3;
	this.port = $(portElm);
	this.port.style.cursor = "w-resize";
	this.port.style.overflow = "hidden"; /* opera sux */
	this.port.style.overflowX = "hidden";
	this.port.style.overflowY = "auto";
	this.options.portWidth = OAT.Dom.getWH(this.port)[0];
	this.sliderElm = $(sliderElm);
	this.sliderBtn = OAT.Dom.create("div");
	this.port.appendChild(this.elm);
	this.sliderElm.appendChild(OAT.Dom.create("hr",{width:"100%",position:"relative",top:"4px"}));
	this.sliderElm.appendChild(this.sliderBtn);
	
	this.slider = new OAT.Slider(this.sliderBtn,{});
	OAT.Dom.addClass(this.port,"timeline_port");
	this.elm.className = "timeline";
	OAT.Dom.addClass(this.sliderBtn,"timeline_slider");
	
	/* dragging */
	OAT.Dom.attach(this.port,"mousedown",function(event){ self.mouse_x = event.clientX; OAT.TimelineData.obj = self; });
	
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
		OAT.Dom.clear(this.elm);
	}
	
	this.fixDate = function(str) {
		var r=false;
		if ((r = str.match(/(....)-(..)-(..) (..):(..):(..)/))) {
			var d = new Date();
			d.setFullYear(r[1]);
			d.setMonth(parseInt(r[2])-1);
			d.setDate(r[3]);
			d.setHours(r[4]);
			d.setMinutes(r[5]);
			d.setSeconds(r[6]);
			d.setMilliseconds(0);
			return d;
		}
		if ((r = str.match(/(....)-(..)-(..)T(..):(..):(..)/))) {
			var d = new Date();
			d.setFullYear(r[1]);
			d.setMonth(parseInt(r[2])-1);
			d.setDate(r[3]);
			d.setHours(r[4]);
			d.setMinutes(r[5]);
			d.setSeconds(r[6]);
			d.setMilliseconds(0);
			return d;
		}
		if ((r = str.match(/(....)-(..)-(..)T(..):(..)/))) {
			var d = new Date();
			d.setFullYear(r[1]);
			d.setMonth(parseInt(r[2])-1);
			d.setDate(r[3]);
			d.setHours(r[4]);
			d.setMinutes(r[5]);
			d.setSeconds(0);
			d.setMilliseconds(0);
			return d;
		}
		if ((r = str.match(/(.{1,2})\.(.{1,2})\.(....)/))) {
			var d = new Date();
			d.setFullYear(r[3]);
			d.setMonth(parseInt(r[2])-1);
			d.setDate(r[1]);
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
		var e = new OAT.TimelineEvent(bandIndex,st,et,content,color);
		self.events.push(e);
		return e.elm;
	}
	
	this.drawResizer = function() {
		if (!self.options.resize) { return; }
		var parent = self.port.parentNode;
		var bg = "url(" + OAT.Preferences.imagePath + "resize.gif)";
		self.resize = OAT.Dom.create("div",{position:"absolute",width:"10px",height:"10px",right:"0px",fontSize:"1px",bottom:"0px",backgroundImage:bg});
		self.resize.style.zIndex = 6;
		parent.appendChild(self.resize);
		OAT.Resize.create(self.resize,parent,OAT.Resize.TYPE_XY);
		OAT.Resize.create(self.resize,self.port,OAT.Resize.TYPE_XY,function(){self.sync();});
	}
	this.drawFormatSelect = function() {
		if (!self.options.formatter) { return; }
		var parent = self.port.parentNode;
		var div = OAT.Dom.create("div",{position:"absolute",top:"-20px",right:"1px",zIndex:5,font:"menu"});
		parent.appendChild(div);
		div.appendChild(OAT.Dom.text("Date format: "));
		div.appendChild(self.formatSelect);
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
			elm.txt.innerHTML = elm._date.format(f);
			elm.txt.title = elm._date.toHumanString();
		}
	}
	OAT.Dom.attach(self.formatSelect,"change",self.drawDateLabels);
	
	this.draw = function() {
		if (!self.events.length) { return; } /* nothing to do */
		/* preparation */
		OAT.Dom.clear(self.elm);
		OAT.Dom.clear(self.port);
		self.port.appendChild(self.elm);
		self.reorderEvents();
		self.width = self.options.margins;
		var lastPlottedIndex = -1;
		var candidateIndex = 0;
		for (var p in self.bands) {
			self.bands[p].lines = [];
		}
		var pendingEnds = [];
		
		/* find appropriate starting time and scale */
		var first = self.events[0];
		var index = 1;
		while (index < self.events.length-1 && self.events[index].startTime.getTime() == first.startTime.getTime()) { index++; }
		if (index == self.events.length) { index--; } /* if all events at the same time */
		var scale = OAT.TlScale.findScale(first.startTime,self.events[index].startTime);
		var line = scale.initBefore(self.events[0].startTime);
		self.dateLabels.push(line);
		line.style.left = self.width + "px";
		self.elm.appendChild(line);
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
						e.intervalElm.style.width = (e.x2 - e.x1) + "px";
						done = 1;
					}
				}
				if (done) for (var j=pendingEnds.length-1;j>=0;j--) {
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
				newscale = OAT.TlScale.findScale(endTime,self.events[lastPlottedIndex+1].startTime,scale.currentTime);
			}
			
			/* if no events need plotting, but there are outstanding ending events, we need to change scale as well */
			if (lastPlottedIndex == self.events.length-1 && pendingEnds.length) {
				newscale = OAT.TlScale.findScale(endTime,pendingEnds[0].endTime,scale.currentTime);
			}
			
			scale = newscale;
			
		} while (lastPlottedIndex < self.events.length-1 || self.width + self.options.margins < self.options.portWidth || pendingEnds.length);
		self.width += self.options.margins;
		self.elm.style.width = self.width + "px";
		
		/* actualize date labels */
		self.drawDateLabels();
		
		/* compute lines */
		for (var i=0;i<self.events.length;i++) { self.computeLine(self.events[i]); }
		
		/* adjust heights */
		var startingHeights = {};
		var total = 0;
		for (var p in self.bands) {
			startingHeights[p] = total;
			var bh = self.bands[p].lines.length * self.options.lineHeight;
			/* band heading */
			var elm = OAT.Dom.create("div",{zIndex:4,position:"absolute",width:"100%",left:"0px",top:(total-1)+"px",textAlign:"center",fontWeight:"bold"});
			elm.style.borderTop = "1px solid #000";
			elm.style.backgroundColor = self.bands[p].color;
			elm.style.height = (self.options.bandHeight+1) + "px";
			elm.innerHTML = self.bands[p].label;
			self.port.appendChild(elm);
			/* band */
			var elm = OAT.Dom.create("div",{zIndex:1,position:"absolute",left:"0px",width:"100%"});
			elm.style.opacity = "0.7";
			elm.style.filter = "alpha(opacity=70)";
			elm.style.backgroundColor = self.bands[p].color;
			elm.style.borderBottom = "1px solid #000";
			elm.style.top = (total + self.options.bandHeight) + "px";
			elm.style.height = bh + "px";
			if (OAT.Dom.isGecko()) { elm.style.height = (bh-1) + "px"; }
			self.elm.appendChild(elm);
			total += bh + self.options.bandHeight;
		}
		for (var i=0;i<self.events.length;i++) {
			var e = self.events[i];
			var top = startingHeights[e.bandIndex] + e.line * self.options.lineHeight + self.options.bandHeight;
			e.elm.style.top = top + "px";
		}
		total += 2 * self.options.lineHeight;
		self.elm.style.height = total + "px";
		
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
		self.options.portWidth = OAT.Dom.getWH(self.port)[0];
		self.slider.options.maxValue = self.width - self.options.portWidth;
		self.slider.options.maxPos = self.options.portWidth - 9;
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
OAT.Dom.attach(document,"mouseup",OAT.TimelineData.up);
OAT.Dom.attach(document,"mousemove",OAT.TimelineData.move);
OAT.Loader.featureLoaded("timeline");
