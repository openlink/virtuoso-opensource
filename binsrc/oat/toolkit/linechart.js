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
	l = new OAT.LineChart(div,optObj)
	l.attachData(dataArray)
	l.attachTextX(textArray)
	l.attachTextY(textArray)
	l.draw()
*/

OAT.LineChartMarker = {
	MARKER_CIRCLE:function(x,y,size,color,bg,value) {
		var elm = OAT.SVG.element("circle",{r:size/2,stroke:color,cx:x,cy:y,fill:bg});
		elm.setAttribute("title",value);
		return elm;
	},
	MARKER_SQUARE:function(x,y,size,color,bg,value) {
		var elm = OAT.SVG.element("rect",{x:x-size/2,y:y-size/2,width:size,height:size,stroke:color,fill:bg});
		elm.setAttribute("title",value);
		return elm;
	},
	MARKER_CROSS:function(x,y,size,color,bg,value) {
		var s = (size-1)/2;
		var elm = OAT.SVG.element("path",{stroke:color,fill:"none"});
		var d = "M "+(x-s)+" "+y;
		d+= " L "+(x+s)+" "+y+" M "+x+" "+(y-s)+" L "+x+" "+(y+s)+" Z";
		elm.setAttribute("d",d);
		elm.setAttribute("title",value);
		return elm;
	},
	MARKER_TRIANGLE:function(x,y,size,color,bg,value) {
		var elm = OAT.SVG.element("path",{stroke:color,fill:bg});
		elm.setAttribute("title",value);
		var coef = Math.sqrt(3);
		var d = "M "+(x-size/2)+" "+(y+size*coef/6);
		d += " L "+(x+size/2)+" "+(y+size*coef/6);
		d += " L "+x+" "+(y-size*coef/3);
		d += " Z";
		elm.setAttribute("d",d);
		return elm;
	},
	MARKER_NONE:function(x,y,size,color,bg,value) {
		return false;
	}
}

OAT.LineChart = function(div,optObj) {
	var self = this;
	this.div = $(div);
	this.options = {
		paddingLeft:30,
		paddingBottom:30,
		paddingTop:10,
		paddingRight:120,
		axes:true,
		legend:true,
		markerSize:8,
		colors:["#f00","#00f","#0f0","#ff0"],
		grid:true, /* show horizontal grid lines */
		gridDesc:true, /* Y labels */
		gridNum:6, /* approx how many grid lines */
		desc:true, /* X labels */
		markers:[OAT.LineChartMarker.MARKER_CIRCLE,OAT.LineChartMarker.MARKER_TRIANGLE,OAT.LineChartMarker.MARKER_CROSS,OAT.LineChartMarker.MARKER_SQUARE],
		sparklineMarkers:false,
		gridColor:"#888",
		fontSize:14
	};
	for (var p in optObj) { self.options[p] = optObj[p]; }

	this.data = [];
	this.textX = [];
	this.textY = [];

	this.findExtremes = function() {	/* find maximum */
		var allvalues = [];
		for (var i=0;i<self.data.length;i++) {
			if (typeof(self.data[i]) == "object") {
				for (var j=0;j<self.data[i].length;j++) { allvalues.push(self.data[i][j]); }
			} else { allvalues.push(self.data[i]); }
		}
		allvalues.sort(function(a,b){return a-b;});
		return [allvalues.shift(),allvalues.pop()];
	}

	this.draw = function() {
		var dims = OAT.Dom.getWH(self.div);
		var w = dims[0] - self.options.paddingRight - self.options.paddingLeft;
		var h = dims[1] - self.options.paddingTop - self.options.paddingBottom;
		self.svg = OAT.SVG.canvas("100%","100%");
		self.div.appendChild(self.svg);

		var e = self.findExtremes();
		var max = e[1];
		var min = e[0];

		var scale = function(value) {
			return Math.round((value-min) / (max-min) * h);
		}

		if (self.options.axes) {
			var axe1 = OAT.SVG.element("line",{x1:self.options.paddingLeft,x2:self.options.paddingLeft+w,stroke:self.options.gridColor});
			var axe2 = OAT.SVG.element("line",{y1:self.options.paddingTop + h,y2:self.options.paddingTop,stroke:self.options.gridColor});
			var x = self.options.paddingLeft;
			var y = h + self.options.paddingTop;
			axe1.setAttribute("y1",y);
			axe1.setAttribute("y2",y);

			axe2.setAttribute("x1",x);
			axe2.setAttribute("x2",x);

			self.svg.appendChild(axe1);
			self.svg.appendChild(axe2);
		}

		if (self.options.desc) { /* x labels */
			var step = w / (self.textX.length-1);
			var y = self.options.paddingTop + h;
			for (var i=0;i<self.textX.length;i++) {
				var x = self.options.paddingLeft + i*step;
				var l = OAT.SVG.element("line",{x1:x,x2:x});
				l.setAttribute("stroke",self.options.gridColor);
				l.setAttribute("y1",y+3);
				l.setAttribute("y2",y-3);
				self.svg.appendChild(l);
				var t = OAT.SVG.element("text",{"text-anchor":"middle",x:x,y:y+self.options.fontSize+2,"font-size":self.options.fontSize});
				t.textContent = self.textX[i];
				self.svg.appendChild(t);
			}
		}

		if (self.options.grid) { /* horizontal lines */
			/* calculate good values */
			var step = (max-min) / self.options.gridNum;
			var base = Math.floor(Math.log(step) / Math.log(10));
			var divisor = Math.pow(10,base);
			var result = Math.round(step / divisor) * divisor;
			for (var i=min;i<=max;i+=result) {
				i = Math.round(i * 1000) / 1000;
				var line = OAT.SVG.element("line",{x1:self.options.paddingLeft,x2:self.options.paddingLeft+w});
				var scaled = scale(i);
				var y = self.options.paddingTop + h - scaled;
				line.setAttribute("y1",y);
				line.setAttribute("y2",y);
				line.setAttribute("stroke",self.options.gridColor);
				self.svg.appendChild(line);

				if (self.options.gridDesc) {
					/* description of Y axis */
					var desc = OAT.SVG.element("text",{"text-anchor":"end"});
					desc.textContent = i;
					desc.setAttribute("x",self.options.paddingLeft - 5);
					desc.setAttribute("y",y + self.options.fontSize / 3);
					desc.setAttribute("font-size",self.options.fontSize);
					self.svg.appendChild(desc);
				}
			}
		}

		var drawLine = function(dataRow,index) {
			var markerArr = [];
			var markerFunc = self.options.markers[index % self.options.markers.length];
			var color = self.options.colors[index % self.options.colors.length];
			var bg = OAT.Style.get(self.div,"backgroundColor");
			var line = OAT.SVG.element("path",{fill:"none","stroke-width":0.8});
			var step = w / (dataRow.length-1);
			var d = "";
			for (var i=0;i<dataRow.length;i++) {
				var x = self.options.paddingLeft + i*step;
				var y = h + self.options.paddingTop - scale(dataRow[i]);
				d += (i ? " L "+x+" "+y : "M "+x+" "+y);
				markerArr.push(markerFunc(x,y,self.options.markerSize,color,bg,dataRow[i]));
				if (self.options.sparklineMarkers) {
					var c = false;
					if (dataRow[i] == max) {
						c = "#0d0";
					} else if (dataRow[i] == min) {
						c = "#d00";
					} else if (i+1 == dataRow.length) {
						c = "#00d";
					}
					if (c) {
						var spark = OAT.LineChartMarker.MARKER_CROSS(x,y,4,c,bg,dataRow[i]);
						spark.setAttribute("shape-rendering","optimizeSpeed"); /* no antialiasing */
						markerArr.push(spark);
					}
				}

			}
			line.setAttribute("d",d);
			line.setAttribute("stroke",color);
			self.svg.appendChild(line);
			for (var i=0;i<markerArr.length;i++) { if (markerArr[i]) { self.svg.appendChild(markerArr[i]); } }
		}

		if (typeof(self.data[0]) == "object") {
			for (var i=0;i<self.data.length;i++) {
				drawLine(self.data[i],i);
			}
		} else { drawLine(self.data,0); }

		if (self.options.legend) {
			var cnt = self.textY.length;
			var sx = self.options.paddingRight - 10;
			var sy = (cnt*2+0.5) * self.options.fontSize
			var offX = self.options.paddingLeft + 5 + w;
			var offY = self.options.paddingTop + h/2 - sy/2;
			var g = OAT.SVG.element("g",{transform:"translate("+offX+","+offY+")"});
			var box = OAT.SVG.element("rect",{stroke:"#000",fill:"none",x:0,y:0,width:sx,height:sy})
			g.appendChild(box);
			for (var i=0;i<cnt;i++) {
				var y = self.options.fontSize*(2*i+1);
				var markerFunc = self.options.markers[i % self.options.markers.length];
				var color = self.options.colors[i % self.options.colors.length];
				var bg = OAT.Style.get(self.div,"backgroundColor");
				var line = OAT.SVG.element("line",{stroke:color,x1:5,x2:5*self.options.markerSize,y1:y,y2:y});
				var m = markerFunc(5+2.5*self.options.markerSize,y,self.options.markerSize,color,bg,self.textY[i]);
				var t = OAT.SVG.element("text",{x:5+6*self.options.markerSize,y:y+self.options.fontSize/3});
				t.textContent = self.textY[i];
				g.appendChild(line);
				g.appendChild(m);
				g.appendChild(t);
			}
			self.svg.appendChild(g);
		}

	} /* draw */

	this.attachData = function(arr) { self.data = arr; }
	this.attachTextX = function(arr) { self.textX = arr; }
	this.attachTextY = function(arr) { self.textY = arr; }

} /* OAT.LineChart() */
