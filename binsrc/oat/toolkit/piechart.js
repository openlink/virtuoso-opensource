/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2014 OpenLink Software
 *
 *  See LICENSE file for details.
 */

/*
	o = new OAT.PieChart(div,optObj)
	o.attachData(arr)
	o.attachText(arr)
	o.attachColors(arr)
	o.draw()
*/
OAT.PieChart = function(div,optObj) {
	var self = this;
	this.div = $(div);
	this.options = {
		radius:0, /* = auto */
		depth:30,
		width:0, /* = auto */
		height:0, /* = auto */
		legend:1,
		ycoef:0.7,
		left:30,
		top:40
	};
	/* compute automatic radius */
	if (!this.options.radius) {
		var h = self.options.height;
		if (!h) { h = OAT.Dom.getWH(self.div)[1]; }
		this.options.radius = (h - 2*self.options.top - self.options.depth) / (2*self.options.ycoef);
	}
	for (var p in optObj) { this.options[p] = optObj[p]; }
	this.data = [];
	this.text = [];
	this.colors = ["rgb(153,153,255)","rgb(153,51,205)","rgb(255,255,204)","rgb(204,255,255)","rgb(102,0,102)",
				"rgb(255,128,128)","rgb(0,102,204)","rgb(204,204,255)","rgb(0,0,128)","rgb(255,0,255)",
				"rgb(0,255,255)","rgb(255,255,0)"];
	this.attachData = function(dataArr) { self.data = dataArr; }
	this.attachColors = function(colorArr) { self.colors = colorArr; }
	this.attachText = function(textArr) { self.text = textArr; }

	this.drawPie = function(svgNode,value,total,start_angle,cx,cy,color,phase) {
		/* compute important data */
		var ycoef = self.options.ycoef;
		var r = self.options.radius;
		var x1 = r * Math.cos(start_angle) + cx;
		var y1 = ycoef * r * Math.sin(start_angle) + cy;
		var angle = parseFloat(value) / total * 2 * Math.PI;
		var end_angle = start_angle + angle;
		var x2 = r * Math.cos(end_angle) + cx;
		var y2 = ycoef * r * Math.sin(end_angle) + cy;
		var large = (angle >= Math.PI ? 1 : 0);

		switch (phase) {
			case 0: /* top part */
				if (value == total) { /* ellipse mode */
					var pElm = OAT.SVG.element("ellipse",{stroke:"#000",fill:color,cx:cx,cy:cy,rx:r,ry:r*ycoef});
				} else {
					var path = "M "+cx+" "+cy+" L "+x1+" "+y1+" ";
					path += "A "+r+" "+r*(ycoef)+" 0 "+large+" 1 "+x2+" "+y2+" ";
					path += "L "+cx+" "+cy+" z";
					var pElm = OAT.SVG.element("path",{"d":path,stroke:"#000",fill:color});
				}
				svgNode.appendChild(pElm);
				var mid_angle = (start_angle + end_angle) / 2;
				var x3 = (r+25) * Math.cos(mid_angle) + cx;
				var y3 = (r+25) * ycoef * Math.sin(mid_angle) + cy + 5;
				y3 += (mid_angle % (2*Math.PI) < Math.PI ? self.options.depth : 0);
				var textElm = OAT.SVG.element("text",{color:"#000",x:x3,y:y3,"text-anchor":"middle"});
				textElm.textContent = value;
				svgNode.appendChild(textElm);
			break;
			case 1: /* lower part */
				if (value == total) { /* ellipse mode */
					var pElm = OAT.SVG.element("ellipse",{stroke:"#000",fill:color,cx:cx,cy:cy,rx:r,ry:r*ycoef});
				} else {
					var path = "M "+cx+" "+cy+" L "+x1+" "+y1+" ";
					path += "A "+r+" "+(r*ycoef)+" 0 "+large+" 1 "+x2+" "+y2+" ";
					path += "L "+cx+" "+cy+" z";
					var pElm = OAT.SVG.element("path",{"d":path,stroke:"#000",fill:color});
				}
				svgNode.appendChild(pElm);
			break;
			case 2: /* middle part */
				var d = self.options.depth;
				/* hack */
				if (value == total) {
					x1 = cx + r;
					x2 = cx - r;
					y1 = cy;
					y2 = cy;
				}
				if (y1 < cy && y2 < cy) {
					y1 = cy;
					y2 = cy;
					x1 = cx - r;
					x2 = cx - r;
				}
				if (y1 < cy) {
					y1 = cy;
					x1 = cx + r;
					large = 0;
				}
				if (y2 < cy) {
					y2 = cy;
					x2 = cx - r;
					large = 0;
				}
				var path = "M "+x1+" "+y1+" L "+x1+" "+(y1-d)+" ";
				path += "A "+r*1+" "+(r*ycoef)+" 0 "+large+" 1 "+x2+" "+(y2-d)+" ";
				path += "L "+x2+" "+y2+" ";
				path += "A "+r+" "+(r*ycoef)+" 0 "+large+" 0 "+x1+" "+y1+" ";
				/* lighter color */
				var c = OAT.Dom.color(color);
				var newr = c[0] + 20; if (newr > 255) { newr = 255; }
				var newg = c[1] + 20; if (newg > 255) { newg = 255; }
				var newb = c[2] + 20; if (newb > 255) { newb = 255; }
				var pElm = OAT.SVG.element("path",{"d":path,stroke:"#000",fill:"rgb("+newr+","+newg+","+newb+")"});
				svgNode.appendChild(pElm);
			break;
		}
		return end_angle;
	}
	this.draw = function() {
		var w = self.options.width ? self.options.width : "100%";
		var h = self.options.height ? self.options.height : "100%";
		var svg = OAT.SVG.canvas(w,h);
		var group = OAT.SVG.element("g",{transform:"scale(1,1)"});
		svg.appendChild(group);
		self.div.appendChild(svg);
		var total = 0;
		for (var i=0;i<self.data.length;i++) { total += parseFloat(self.data[i]); }
		var r = self.options.radius;
		var cx = r+self.options.left;
		var cy = r * self.options.ycoef + self.options.top;
		var angle = 2*Math.PI - Math.PI/2;
		if (self.options.depth) {
			for (var i=0;i<self.data.length;i++) { /* lower part */
				var v = self.data[i];
				var color = self.colors[i % self.colors.length];
				angle = self.drawPie(group,v,total,angle,cx,cy+self.options.depth,color,1);
			} /* for all data */
			for (var i=0;i<self.data.length;i++) { /* middle part */
				var v = self.data[i];
				var color = self.colors[i % self.colors.length];
				angle = self.drawPie(group,v,total,angle,cx,cy+self.options.depth,color,2);
			} /* for all data */
		}
		for (var i=0;i<self.data.length;i++) { /* top part */
			var v = self.data[i];
			var color = self.colors[i % self.colors.length];
			angle = self.drawPie(group,v,total,angle,cx,cy,color,0);
			/* legend */
			if (self.options.legend) {
				var rect = OAT.SVG.element("rect",{width:25,height:25,x:2*self.options.radius+70+self.options.left,y:i*35+20,fill:color,stroke:"#000"});
				svg.appendChild(rect);
				var text = OAT.SVG.element("text",{x:2*self.options.radius+100+self.options.left,y:i*35+35,color:"#000"});
				text.textContent = self.text[i];
				svg.appendChild(text);
			}
		} /* for all data */
	} /* draw */
} /* OAT.PieChart() */
