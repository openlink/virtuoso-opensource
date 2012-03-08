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
	bc = new OAT.BarChart(div, optObj)
	bc.attachData(dataArray)
	bc.attachTextX(textArray)
	bc.attachTextY(textArray)
	bc.draw()

	CSS: .legend .legend_box .textX .textY

*/

OAT.BarChart = function(div,optObj) {
	var self = this;
	this.options = {
		percentage:false, /* percentage plot? */
		spacing:25, /* between columns */
		paddingLeft:30,
		paddingBottom:30,
		paddingTop:5,
		width:15, /* of one column */
		colors:["#f00","#0f0","#00f"],
		border:true, /* of column */
		grid:true, /* show horizontal grid lines */
		gridDesc:true, /* description of horizontal grid lines */
		gridNum:6, /* approx how many grid lines */
		shadow:true,
		shadowColor:"#222",
		shadowOffset:2
	}

	for (var p in optObj) { this.options[p] = optObj[p]; }

	this.maxValue = 0;
	this.data = [];
	this.textX = [];
	this.textY = [];
	this.div = $(div);

	OAT.Dom.makePosition(self.div);

	this.getFreeH = function() {
		var tmp = OAT.Dom.getWH(self.div);
		return tmp[1] - self.options.paddingTop - self.options.paddingBottom;
	}

	this.drawColumn = function(index, position) {
		var opts = self.options;

		var freeh = self.freeH;
		var orig = (typeof(self.data[index]) == "object" ? self.data[index] : [self.data[index]]);
		if (opts.percentage) {
			var values = [];
			var total = 0;
			for (var i=0;i<orig.length;i++) { total += orig[i]; }
			for (var i=0;i<orig.length;i++) {
				values.push(self.maxValue * orig[i] / total);
			}
		} else { var values = orig; }
		/* percentage? */

		var bottom = opts.paddingBottom;
		var total = 0;
		var divs = [];
		for (var i=0;i<values.length;i++) {
			var v = values[i];
			var d = OAT.Dom.create("div",{position:"absolute",fontSize:"0px",lineHeight:"0px"});
			if (opts.border) { d.style.border = "1px solid #000"; }
			d.style.width = opts.width+"px";
			d.style.backgroundColor = opts.colors[i];
			d.style.left = position+"px";
			d.style.bottom = bottom + "px";
			var h = self.scale(v);
			d.style.height = h+"px";
			bottom += h;
			total += h;
			divs.push(d);
		}

		/* shadow */
		if (opts.shadow) {
			var shadow = OAT.Dom.create("div",{position:"absolute",fontSize:"0px",lineHeight:"0px"});
			shadow.style.left = (parseInt(position)+opts.shadowOffset)+"px";
			shadow.style.bottom = (opts.paddingBottom+opts.shadowOffset)+"px";
			shadow.style.width = opts.width+"px";
			shadow.style.height = total + "px";
			shadow.style.backgroundColor = opts.shadowColor;
			if (opts.border) {
				shadow.style.borderColor = opts.shadowColor;
				shadow.style.borderWidth = "1px";
				shadow.style.borderStyle = "solid";
			}
			self.div.appendChild(shadow);
		}

		for (var i=0;i<divs.length;i++) { self.div.appendChild(divs[i]); }

		/* text X */
		if (self.textX.length) {
			var l = OAT.Dom.create("div",{position:"absolute"});
			l.className = "textX";
			l.innerHTML = self.textX[index];
			l.style.top = (freeh + opts.paddingTop + 2) + "px";
			l.style.left = position + "px";
			self.div.appendChild(l);
			var dims = OAT.Dom.getWH(l);
			l.style.left = (position +Math.round(opts.width/2) - Math.round(dims[0]/2)) + "px";
		}
	}

	this.draw = function() {
		OAT.Dom.clear(self.div);
		self.div.style.width = "100%";
		if (!self.data.length) { return; }
		var position = self.options.paddingLeft;
		var width = self.data.length * (self.options.width + self.options.spacing);
		self.freeH = self.getFreeH();
		/* find maximum */
		self.maxValue = 0;
		for (var i=0;i<self.data.length;i++) {
			if (typeof(self.data[i]) == "object") {
				var total = 0;
				for (var j=0;j<self.data[i].length;j++) { total += parseFloat(self.data[i][j]); }
				if (total > self.maxValue) { self.maxValue = total; }
			} else { if ( parseFloat(self.data[i]) > self.maxValue) {self.maxValue = self.data[i];} }
		}
		/* grid & its description? */
		if (self.options.grid) {
			/* calculate good values */
			var step = (self.options.percentage ? 100 : self.maxValue) / self.options.gridNum;
			var base = Math.floor(Math.log(step) / Math.log(10));
			var divisor = Math.pow(10,base);
			var result = Math.round(step / divisor) * divisor;
			for (var i=0;i<=(self.options.percentage ? 100 : self.maxValue);i+=result) {
				i = Math.round(i * 1000) / 1000;
				var line = OAT.Dom.create("div",{position:"absolute",width:width+"px",height:"1px",fontSize:"0px",lineHeight:"0px",backgroundColor:"#000"});
				var scaled = (self.options.percentage ? self.scale(i/100*self.maxValue) : self.scale(i));
				var top = self.options.paddingTop + self.freeH - scaled;
				line.style.left = position + "px";
				line.style.top = top + "px";
				self.div.appendChild(line);
				if (self.options.gridDesc) {
					/* description of Y axis */
					var desc = OAT.Dom.create("div",{position:"absolute"});
					desc.innerHTML = i;
					desc.className = "textY";
					desc.style.left = position + "px";
					desc.style.top = top + "px";
					self.div.appendChild(desc);
					var dims = OAT.Dom.getWH(desc);
					desc.style.left = (position - 2 - dims[0]) + "px";
					desc.style.top = (top - Math.round(dims[1]/2)) + "px";
				}
			}
		}
		position += Math.round(self.options.spacing / 2);
		for (var i=0;i<self.data.length;i++) {
			self.drawColumn(i,position);
			position += self.options.width + self.options.spacing;
		}
		/* legend? */
		if (self.textY.length) {
			var legend = OAT.Dom.create("div",{position:"absolute"});
			legend.className = "legend";
			legend.style.left = position + "px";
			legend.style.top = self.options.paddingTop + "px";
			self.div.appendChild(legend);
			for (var i=self.data[0].length-1;i>=0;i--) {
				var line = OAT.Dom.create("div",{clear:"left"});
				var box = OAT.Dom.create("div");
				box.className = "legend_box";
				box.style.backgroundColor = self.options.colors[i];
				line.appendChild(box);
				var value = OAT.Dom.text(self.textY[i]);
				line.appendChild(value);
				legend.appendChild(line);
			}
		}
		/* resulting total width */
		var total = self.options.paddingLeft + self.data.length * (self.options.width + self.options.spacing) + 5;
		if (self.textY.length) {
			var dims = OAT.Dom.getWH(legend);
			total += dims[0]+5+Math.round(self.options.spacing/2);
		}
		if (!isNaN(total)) { self.div.style.width = total+"px"; }
	}

	this.scale = function(value) {
		return Math.round(value / self.maxValue * self.freeH);
	}

	this.attachData = function(dataArray) {
		self.data = dataArray;
	}

	this.attachTextX = function(textArray) {
		self.textX = textArray;
	}

	this.attachTextY = function(textArray) {
		self.textY = textArray;
	}

}
