/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2015 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	s = new OAT.SVGSparql(parentElm,options)
	options.selectNodeCallback(node)
	options.selectGroupCallback(group)
	options.selectEdgeCallback(edge)
	options.deselectNodeCallback(node)
	options.deselectGroupCallback(group)
	options.deselectEdgeCallback(edge)
	options.addNodeCallback(node,loadMode)
	options.addEdgeCallback(edge,loadMode)
	options.addGroupCallback(group,loadMode)
	options.removeNodeCallback(node)
	options.removeEdgeCallback(edge)
	options.removeGroupCallback(group)
	s.toXML()
	s.fromXML()
	s.setProjection(OAT.SVGSparqlData.PROJECTION_PLANAR | PROJECTION_SPHERICAL )
	s.reposition()
	s.arrange()
	s.startDrawing(node|group,clientX,clientY,label)

	node|edge|group.setLabel(index,value)
	node|edge|group.getLabel(index)
	node|edge|group.setType(type)
	node|edge|group.getType()
	node|edge|group.signalStart|signalStop()
	node|edge|group.setVisible(bool)
	node|edge|group.getVisible()
	node.setGroup(group|false)

	group.setParent(newParentGroup)
	group.setFill(newColor)

*/

OAT.SVGSparqlData = {
	MODE_DRAG:0,
	MODE_ADD:1,
	MODE_DRAW:2,
	NODE_CIRCLE:0,
	NODE_RECT:1,
	EDGE_SOLID:0,
	EDGE_DASHED:1,
	PROJECTION_PLANAR:0,
	PROJECTION_SPHERICAL:1,
  GROUP_GRAPH:0,
  GROUP_OPTIONAL:1,
  GROUP_UNION:2,
  GROUP_CONSTRUCT:3
}

OAT.SVGSparqlGroup = function(svgsparql,label) {
	var self = this;
	this.svgsparql = svgsparql;
	this.nodes = [];
	this.edges = [];
	this.parent = false;
	this.signal = false;
	this.svg = OAT.SVG.element("path",{fill:svgsparql.options.groupOptions.color});
	this.label = OAT.SVG.element("text",svgsparql.options.fontOptions);
	this.visible = true; /* not overall visibility, but rather SPARQL query inclusion */
	this.type = OAT.SVGSparqlData.GROUP_GRAPH;

	this.setType = function(newType) {
		self.type = parseInt(newType);
	}

	this.getType = function() {
		return self.type;
	}

	this.setFill = function(newColor) {
		self.svg.setAttribute("fill",newColor);
	}

	this.setVisible = function(value) {
		self.visible = value;
	}

	this.getVisible = function() { return self.visible; }

	this.setParent = function(newParent) {
		var oldParent = self.parent;
		self.parent = newParent;
		if (oldParent) { oldParent.redraw(); }
		if (self.parent) {
			/* move our svg element after parent's element */
			if (self.parent.svg.nextSibling) {
				self.parent.svg.parentNode.insertBefore(self.svg,self.parent.svg.nextSibling);
			} else {
				self.parent.svg.parentNode.appendChild(self.svg);
			}
			self.parent.redraw();
		}
	}

	this.signalStart = function() {
		if (self.signal) { return; }
		self.signal = true;
		self.label.setAttribute("font-weight","bold");
	}

	this.signalStop = function() {
		if (!self.signal) { return; }
		self.signal = false;
		self.label.setAttribute("font-weight","normal");
	}

	this.checkBBox = function(x,y) {
		var bb = self.svgsparql.bbox(self.svg);
		if (x >= bb.x && y >= bb.y && x <= bb.x+bb.width && y <= bb.y+bb.height) { return true; }
		return false;
	}

	this.checkNodes = function() {
		self.nodes = [];
		for (var i=0;i<svgsparql.nodes.length;i++) {
			var n = svgsparql.nodes[i];
			if (!n.group) { continue; }
			if (n.group == self || n.group.parent == self) { self.nodes.push(n); }
		}
	}


	this.twoClosestNodes = function(x,y) {
		self.checkNodes();
		if (!self.nodes.length) { return false; }
		if (self.nodes.length == 1) { return [self.nodes[0],self.nodes[0]]; }
		if (self.nodes.length == 2) { return self.nodes; }
		var points = [];
		for (var i=0;i<self.nodes.length;i++) {
			var n = self.nodes[i];
			points.push([n.draw_x,n.draw_y]);
		}
		var poly = OAT.Geometry.createConvexPolygon(points);
		var distFunc = function(p1,p2) {
			var d1 = (x-p1[0])*(x-p1[0]) + (y-p1[1])*(y-p1[1]);
			var d2 = (x-p2[0])*(x-p2[0]) + (y-p2[1])*(y-p2[1]);
			return d1 - d2;
		}
		poly.sort(distFunc);
		var result = [false,false];
		for (var i=0;i<self.nodes.length;i++) {
			var n = self.nodes[i];
			if (n.draw_x == poly[0][0] && n.draw_y == poly[0][1]) { result[0] = n; }
			if (n.draw_x == poly[1][0] && n.draw_y == poly[1][1]) { result[1] = n; }
		}
		return result;
	}

	this.getCOG = function() {
		self.checkNodes();
		if (!self.nodes.length) { return false; }
		if (self.nodes.length == 1) { return [self.nodes[0].draw_x,self.nodes[0].draw_y]; }
		if (self.nodes.length == 2) {
			var x = (self.nodes[0].draw_x + self.nodes[1].draw_x) / 2;
			var y = (self.nodes[0].draw_y + self.nodes[1].draw_y) / 2;
			return [x,y];
		}
		var points = [];
		for (var i=0;i<self.nodes.length;i++) {
			var n = self.nodes[i];
			points.push([n.draw_x,n.draw_y]);
		}
		var poly = OAT.Geometry.createConvexPolygon(points);
		return OAT.Geometry.findCOG(poly);
	}

	this.setLabel = function(newLabel) {
		self.label.textContent = newLabel;
	}

	this.getLabel = function() {
		return self.label.textContent;
	}
	this.setLabel(label);

	this.redraw = function() {
		var labelOffset = [0,-30];
		self.checkNodes();
		if (self.nodes.length == 0) { self.svg.style.display = "none"; return; }
		self.svg.style.display = "";
		if (self.nodes.length == 1) {
			var x = self.nodes[0].draw_x;
			var y = self.nodes[0].draw_y;
			var dist = self.svgsparql.options.groupOptions.padding;
			var d = "M "+x+" "+(y-dist)+" ";
			d += " A "+dist+" "+dist+" 0 1 1 "+x+" "+(y+dist);
			d += " A "+dist+" "+dist+" 0 1 1 "+x+" "+(y-dist);
			d += " Z";
			self.svg.setAttribute("d",d);
			self.label.setAttribute("x",x+labelOffset[0]);
			self.label.setAttribute("y",y+labelOffset[1]);
			for (var i=0;i<self.edges.length;i++) { self.edges[i].redraw(); }
			return;
		} /* one point */
		var points = [];
		if (self.nodes.length == 2) {
			var x1 = self.nodes[0].draw_x;
			var y1 = self.nodes[0].draw_y;
			var x2 = self.nodes[1].draw_x;
			var y2 = self.nodes[1].draw_y;
			var vec1 = [x2-x1,y2-y1];
			var vec2 = [vec1[1],-vec1[0]];
			var dist = self.svgsparql.options.groupOptions.padding / 2;
			var norm = vec2[0]*vec2[0] + vec2[1]*vec2[1];
			norm = Math.sqrt(norm);
			vec2[0] = vec2[0] / norm * dist;
			vec2[1] = vec2[1] / norm * dist;
			points.push([x1-vec2[0],y1-vec2[1]]);
			points.push([x1+vec2[0],y1+vec2[1]]);
			points.push([x2-vec2[0],y2-vec2[1]]);
			points.push([x2+vec2[0],y2+vec2[1]]);
		} else {
			for (var i=0;i<self.nodes.length;i++) {
				var n = self.nodes[i];
				points.push([n.draw_x,n.draw_y]);
			}
		}
		var poly = OAT.Geometry.createConvexPolygon(points);
		var cog = OAT.Geometry.findCOG(poly);
		self.label.setAttribute("x",cog[0]+labelOffset[0]);
		self.label.setAttribute("y",cog[1]+labelOffset[1]);
		var dist = self.svgsparql.options.groupOptions.padding;
		for (var i=0;i<poly.length;i++) {
			var center = poly[i];
			var b = poly[i+1 < poly.length ? i+1 : 0];
			var a = poly[i > 0 ? i-1 : poly.length-1];
			var vec = OAT.Geometry.middleVector(center,a,b);
			var point_x = center[0] + vec[0];
			var point_y = center[1] + vec[1];
			var n = OAT.Geometry.movePoint(poly[i],[point_x,point_y],dist/2);
			n = OAT.Geometry.movePoint(n,cog,dist/2);
			poly[i] = n;
		}
		var subpoints = [];
		var rd = self.svgsparql.options.groupOptions.roundingDistance;
		for (var i=0;i<poly.length;i++) {
			var center = poly[i];
			var subpoint = [];
			var b = poly[i+1 < poly.length ? i+1 : 0];
			var a = poly[i > 0 ? i-1 : poly.length-1];
			subpoint.push(OAT.Geometry.movePoint(center,a,-rd));
			subpoint.push(OAT.Geometry.movePoint(center,b,-rd));
			subpoints.push(subpoint);
		}
		/* without subpoints
		var d = "M "+poly[0][0]+" "+poly[0][1]+" ";
		for (var i=1;i<poly.length;i++) {
			var p = poly[i];
			d += " L "+p[0]+" "+p[1]+" ";
		}
		/**/

		/* with subpoints */
		var d = "M "+subpoints[0][0][0]+" "+subpoints[0][0][1]+" ";
		for (var i=0;i<subpoints.length;i++) {
			var sp = subpoints[i][1];
			d += " L "+sp[0]+" "+sp[1]+" ";
			if (i+1 < subpoints.length) {
				var nextsp = subpoints[i+1][0];
				d += " L "+nextsp[0]+" "+nextsp[1]+" ";
			}
		}
		/* */

		d += " z";
		self.svg.setAttribute("d",d);
		for (var i=0;i<self.edges.length;i++) { self.edges[i].redraw(); }
	}

	this.toXML = function() {
		var xml = "";
		var pi = self.svgsparql.groups.find(self.parent);
		xml += '\t\t<group parent="'+pi+'" type="'+self.getType()+'"';
		xml += ' visible="'+(self.visible ? "1" : "0")+'"';
		xml += '>';
		xml += OAT.Dom.toSafeXML(self.getLabel());
		xml += '</group>\n';
		return xml;
	}

	this.fromXML = function(xmlNode) {
		var val = OAT.Xml.textValue(xmlNode);
		var t = parseInt(xmlNode.getAttribute("type"));
		self.setType(t);
		var arr = OAT.Dom.fromSafeXML(val);
		self.setVisible(xmlNode.getAttribute("visible") == "1");
		self.setLabel(arr);
	}

}

OAT.SVGSparqlNode = function(x,y,value,svgsparql) {
	var self = this;
	this.x = x;
	this.y = y;
	this.hidden = false;
	this.selected = false;
	this.signal = false;
	this.svgsparql = svgsparql;
	this.svgs = [];
	this.group = false;
	this.indicator = OAT.SVG.element("circle",{fill:svgsparql.options.indicatorColor,r:svgsparql.options.indicatorSize});
	this.label1 = OAT.SVG.element("text",svgsparql.options.fontOptions);
	this.label2 = OAT.SVG.element("text",svgsparql.options.fontOptions);
	this.edges = [];
	this.visible = true; /* not overall visibility, but rather SPARQL query inclusion */
	this.type = OAT.SVGSparqlData.NODE_CIRCLE;

	var options = svgsparql.options.nodeOptions;

	this.svgs.push(OAT.SVG.element("circle",options));
	this.svgs.push(OAT.SVG.element("rect",options));
	this.svg = self.svgs[0];

	for (var i=0;i<self.svgs.length;i++) { self.svgs[i].obj = self; }
	self.label1.obj = self;
	self.label2.obj = self;

	this.setGroup = function(group) {
		var oldGroup = self.group;
		self.group = group;
		if (oldGroup) { oldGroup.redraw(); }
		if (self.group) { group.redraw(); }
	}

	this.setType = function(newType) {
		self.type = parseInt(newType);
		var newsvg = false;
		switch (self.type) {
			case OAT.SVGSparqlData.NODE_CIRCLE:
				newsvg = self.svgs[0];
				newsvg.setAttribute("r",options.size);
			break;
			case OAT.SVGSparqlData.NODE_RECT:
				newsvg = self.svgs[1];
				newsvg.setAttribute("width",options.size * 2);
				newsvg.setAttribute("height",options.size * 1.5);
			break;
		} /* switch */
		if (!newsvg) { return; }
		if (self.svg.parentNode) { self.svg.parentNode.replaceChild(newsvg,self.svg); }
		self.svg = newsvg;
		self.redraw();
	}

	this.getType = function() {
		return self.type;
	}

	this.setLabel = function(which,newLabel) {
		self["label"+which].textContent = newLabel;
	}

	this.getLabel = function(which) {
		return self["label"+which].textContent;
	}
	this.setLabel(1,value);

	this.setVisible = function(value) {
		self.visible = value;
		self.redraw();
	}

	this.getVisible = function() { return self.visible; }

	this.signalStart = function() {
		if (self.signal) { return; }
		self.signal = true;
		self.label1.setAttribute("font-weight","bold");
		self.label2.setAttribute("font-weight","bold");
	}

	this.signalStop = function() {
		if (!self.signal) { return; }
		self.signal = false;
		self.label1.setAttribute("font-weight","normal");
		self.label2.setAttribute("font-weight","normal");
	}

	this.checkBBox = function(x,y) {
		var bb = self.svgsparql.bbox(self.svg);
		if (x >= bb.x && y >= bb.y && x <= bb.x+bb.width && y <= bb.y+bb.height) { return true; }
		var bb = self.svgsparql.bbox(self.label1);
		if (x >= bb.x && y >= bb.y && x <= bb.x+bb.width && y <= bb.y+bb.height) { return true; }
		var bb = self.svgsparql.bbox(self.label2);
		if (x >= bb.x && y >= bb.y && x <= bb.x+bb.width && y <= bb.y+bb.height) { return true; }
		return false;
	}

	this.redraw = function() {
		self.draw_x = self.x;
		self.draw_y = self.y;
		self.hidden = false;
		if (self.svgsparql.projection == OAT.SVGSparqlData.PROJECTION_SPHERICAL) {
			var c = OAT.Geometry.toSpherical(self.x,self.y);
			if (!c) {
				self.hidden = true;
				self.draw_x = -100;
				self.draw_y = -100;
			} else {
				self.draw_x = c[0];
				self.draw_y = c[1];
			}
		}

		switch (self.type) {
			case OAT.SVGSparqlData.NODE_CIRCLE:
				self.svg.setAttribute("cx",self.draw_x);
				self.svg.setAttribute("cy",self.draw_y);
			break;
			case OAT.SVGSparqlData.NODE_RECT:
				var w = parseFloat(self.svg.getAttribute("width"));
				var h = parseFloat(self.svg.getAttribute("height"));
				self.svg.setAttribute("x",self.draw_x - w/2);
				self.svg.setAttribute("y",self.draw_y - h/2);
			break;

		} /* switch */

		self.indicator.setAttribute("cx",self.draw_x);
		self.indicator.setAttribute("cy",self.draw_y);

		if (self.visible) {
			self.indicator.style.visibility = "";
		} else {
			self.indicator.style.visibility = "hidden";
		}

		self.label1.setAttribute("x",self.draw_x);
		self.label1.setAttribute("y",self.draw_y);
		self.label2.setAttribute("x",self.draw_x);
		self.label2.setAttribute("y",self.draw_y+svgsparql.options.fontOptions["font-size"]+2);
		for (var i=0;i<self.edges.length;i++) { self.edges[i].redraw(); }
	}

	this.setType(OAT.SVGSparqlData.NODE_RECT);

	this.toXML = function() {
		var xml = "";
		xml += '\t\t<node x="'+self.x+'" y="'+self.y+'" type="'+self.getType()+'" group="'+self.svgsparql.groups.find(self.group)+'" ';
		xml += 'visible="'+(self.visible ? "1" : "0")+'"';
		xml += '>';
		xml += OAT.Dom.toSafeXML(self.getLabel(1));
		xml += ",";
		xml += OAT.Dom.toSafeXML(self.getLabel(2));
		xml += '</node>\n';
		return xml;
	}

	this.fromXML = function(xmlNode) {
		var val = OAT.Xml.textValue(xmlNode);
		var arr = OAT.Dom.fromSafeXML(val).split(",");
		self.setLabel(1,arr[0]);
		self.setLabel(2,arr[1]);
		self.x = parseInt(xmlNode.getAttribute("x"));
		self.y = parseInt(xmlNode.getAttribute("y"));
		var t = parseInt(xmlNode.getAttribute("type"));
		self.setType(t);
		var g = parseInt(xmlNode.getAttribute("group"));
		if (g != -1 && !isNaN(g)) { self.setGroup(self.svgsparql.groups[g]); }
		self.setVisible(xmlNode.getAttribute("visible") == "1");
	}
}

OAT.SVGSparqlEdge = function(node1,node2,value,svgsparql,radius) {
	var self = this;
	this.node1 = node1;
	this.node2 = node2;
	this.svgsparql = svgsparql;
	this.selected = false;
	this.signal = false;
	this.visible = true; /* not overall visibility, but rather SPARQL query inclusion */
	this.type = OAT.SVGSparqlData.EDGE_SOLID;
	node1.edges.push(self);
	node2.edges.push(self);

	var options = svgsparql.options.edgeOptions;

	if (node1 == node2) {
		this.svg = OAT.SVG.element("path",options);
		this.svg.setAttribute("fill","none");
	} else {
		this.svg = OAT.SVG.element("line",options);
		this.svg.setAttribute("marker-end","url(#arrow)");
	}
	this.indicator = OAT.SVG.element("circle",{fill:svgsparql.options.indicatorColor,r:svgsparql.options.indicatorSize});
	this.label1 = OAT.SVG.element("text",svgsparql.options.fontOptions);
	this.label2 = OAT.SVG.element("text",svgsparql.options.fontOptions);

	self.svg.obj = self;
	self.label1.obj = self;
	self.label2.obj = self;

	this.setType = function(newType) {
		self.type = parseInt(newType);
		switch (self.type) {
			case OAT.SVGSparqlData.EDGE_SOLID:
				self.svg.setAttribute("stroke-dasharray","1,0");
			break;
			case OAT.SVGSparqlData.EDGE_DASHED:
				self.svg.setAttribute("stroke-dasharray","3,3");
			break;
		}
		self.redraw();
	}

	this.getType = function() {
		return self.type;
	}

	this.setLabel = function(which,newLabel) {
		self["label"+which].textContent = newLabel;
	}

	this.getLabel = function(which) {
		return self["label"+which].textContent;
	}
	this.setLabel(1,value);

	this.setVisible = function(value) {
		self.visible = value;
		self.redraw();
	}

	this.getVisible = function() { return self.visible; }

	this.signalStart = function() {
		if (self.signal) { return; }
		self.signal = true;
		self.label1.setAttribute("font-weight","bold");
		self.label2.setAttribute("font-weight","bold");
	}

	this.signalStop = function() {
		if (!self.signal) { return; }
		self.signal = false;
		self.label1.setAttribute("font-weight","normal");
		self.label2.setAttribute("font-weight","normal");
	}

	this.checkBBox = function(x,y) {
		var bb = self.svgsparql.bbox(self.svg);
		if (x >= bb.x && y >= bb.y && x <= bb.x+bb.width && y <= bb.y+bb.height) { return true; }
		var bb = self.svgsparql.bbox(self.label1);
		if (x >= bb.x && y >= bb.y && x <= bb.x+bb.width && y <= bb.y+bb.height) { return true; }
		var bb = self.svgsparql.bbox(self.label2);
		if (x >= bb.x && y >= bb.y && x <= bb.x+bb.width && y <= bb.y+bb.height) { return true; }
		return false;
	}

	this.redraw = function() { /* compute line coords */
		var x1,x2,y1,y2;
		var shift1 = true;
		var shift2 = true;

		if (self.node1 instanceof OAT.SVGSparqlGroup && self.node2 instanceof OAT.SVGSparqlGroup) {
			/* edge between two groups */
			var coords = self.svgsparql.twoGroupsCoords(self.node1,self.node2);
			self.redraw2(coords[0],coords[1],coords[2],coords[3]);
			return;
		}

		if (self.node1 instanceof OAT.SVGSparqlNode && self.node2 instanceof OAT.SVGSparqlNode) {
			/* edge between two nodes */
			var x1 = self.node1.draw_x;
			var x2 = self.node2.draw_x;
			var y1 = self.node1.draw_y;
			var y2 = self.node2.draw_y;
		} else {
			/* node and group */
			if (self.node1 instanceof OAT.SVGSparqlNode) {
				/* first is node */
				x1 = self.node1.draw_x;
				y1 = self.node1.draw_y;
				var two = self.node2.twoClosestNodes(x1,y1);
				x2 = (two[0].draw_x + two[1].draw_x) / 2;
				y2 = (two[0].draw_y + two[1].draw_y) / 2;
				shift2 = false;
			} else {
				/* second is node */
				x2 = self.node2.draw_x;
				y2 = self.node2.draw_y;
				var two = self.node1.twoClosestNodes(x2,y2);
				x1 = (two[0].draw_x + two[1].draw_x) / 2;
				y1 = (two[0].draw_y + two[1].draw_y) / 2;
				shift1 = false;
			}
		}

		/* at least one node is present: check for visibility */
		var s = OAT.Geometry.sphericalData;
		if (self.node1 instanceof OAT.SVGSparqlNode && self.node1.hidden) {
			var dx = self.node1.x - s.cx;
			var dy = self.node1.y - s.cy;
			var a = Math.atan2(dy,dx);
			x1 = s.cx + s.r * Math.cos(a);
			y1 = s.cy + s.r * Math.sin(a);
		}
		if (self.node2 instanceof OAT.SVGSparqlNode && self.node2.hidden) {
			var dx = self.node2.x - s.cx;
			var dy = self.node2.y - s.cy;
			var a = Math.atan2(dy,dx);
			x2 = s.cx + s.r * Math.cos(a);
			y2 = s.cy + s.r * Math.sin(a);
			}

		var dist = radius + options.padding;
		if (shift1) {
			var m1 = OAT.Geometry.movePoint([x1,y1],[x2,y2],-dist);
			x1 = m1[0];
			y1 = m1[1];
		}
		if (shift2) {
			var m2 = OAT.Geometry.movePoint([x2,y2],[x1,y1],-dist);
			x2 = m2[0];
			y2 = m2[1];
		}

		self.redraw2(x1,y1,x2,y2);
	}

	this.redraw2 = function(x1,y1,x2,y2) { /* draw a line */
		var y;
		if (x1 == x2 && y1 == y2) {
			self.svg.setAttribute("d","M "+x1+" "+y1+" A "+(radius*1.5)+" "+(radius*1.5)+" 0 1 0 "+x2+" "+y2);
			self.label1.setAttribute("x",x1);
			self.label2.setAttribute("x",x1);
			self.indicator.setAttribute("cx",x1);
			y = y1 - 1.5*radius;
		} else {
			self.indicator.setAttribute("cx",(x1+x2)/2);
			self.label1.setAttribute("x",(x2+x1)/2);
			self.label2.setAttribute("x",(x2+x1)/2);
			y = (y2+y1)/2;
			self.svg.setAttribute("x1",x1);
			self.svg.setAttribute("x2",x2);
			self.svg.setAttribute("y1",y1);
			self.svg.setAttribute("y2",y2);
		}
		self.label1.setAttribute("y",y);
		self.label2.setAttribute("y",y+svgsparql.options.fontOptions["font-size"]+2);
		self.indicator.setAttribute("cy",y);
		if (self.visible) {
			self.indicator.style.visibility = "";
		} else {
			self.indicator.style.visibility = "hidden";
		}
	}

	this.redraw();

	this.toXML = function() {
		var xml = "";
		xml += '\t\t<edge type="'+self.getType()+'"';
		if (self.node1 instanceof OAT.SVGSparqlNode) {
			var index1 = self.svgsparql.nodes.find(self.node1);
			xml += ' node1="'+index1+'" ';
		} else {
			var index1 = self.svgsparql.groups.find(self.node1);
			xml += ' group1="'+index1+'" ';
		}
		if (self.node2 instanceof OAT.SVGSparqlNode) {
			var index2 = self.svgsparql.nodes.find(self.node2);
			xml += ' node2="'+index2+'" ';
		} else {
			var index2 = self.svgsparql.groups.find(self.node2);
			xml += ' group2="'+index2+'" ';
		}
		xml += 'visible="'+(self.visible ? "1" : "0")+'"';
		xml += '>';
		xml += OAT.Dom.toSafeXML(self.getLabel(1));
		xml += ",";
		xml += OAT.Dom.toSafeXML(self.getLabel(2));
		xml += '</edge>\n';
		return xml;
	}

	this.fromXML = function(xmlNode) {
		var val = OAT.Xml.textValue(xmlNode);
		var arr = OAT.Dom.fromSafeXML(val).split(",");
		self.setLabel(1,arr[0]);
		self.setLabel(2,arr[1]);
		var t = parseInt(xmlNode.getAttribute("type"));
		self.setType(t);
		self.setVisible(xmlNode.getAttribute("visible") == "1");
	}

}

OAT.SVGSparql = function(parentElm,paramsObj) {
	var self = this;

	this.options = {
		allowSelfEdges:false,
		defaultNodeValue:"<anonymous node>",
		defaultEdgeValue:"<anonymous edge>",
		indicatorColor:"#ff0",
		indicatorSize:6,
		padding:10,
		groupOptions:{
			color:"#aaf",
			padding:25,
			roundingDistance:15
		},
		nodeOptions:{
			size:10,
			fill:"#f00"
		},
		edgeOptions:{
			stroke:"#888",
			"stroke-width":2,
			padding:4
		},
		fontOptions:{
			"font-size":12,
			"text-anchor":"middle"
		}
	};
	for (var p in paramsObj) { self.options[p] = paramsObj[p]; }

	this.mode = OAT.SVGSparqlData.MODE_DRAG;
	this.projection = OAT.SVGSparqlData.PROJECTION_PLANAR;
	this.timeStamp = 0;
	this.nodes = [];
	this.edges = [];
	this.groups = [];
	this.x = 0;
	this.y = 0;
	this.lasso = false;
	this.fakeEdge = false;
	this.selectedNode = false;
	this.selectedEdge = false;
	this.selectedGroup = false;
	this.selectedNodes = [];
	this.selectedEdges = [];
	this.selectedGroups = [];

	this.ghostdrag = new OAT.GhostDrag();

	self.parent = $(parentElm);
	OAT.Dom.makePosition(self.parent);
	var dims = OAT.Dom.getWH(self.parent);
	self.svgcanvas = OAT.SVG.canvas("100%","100%");
	self.svg = OAT.SVG.element("g");
	self.parent.appendChild(self.svgcanvas);
	self.svgcanvas.appendChild(self.svg);

	/* define arrow marker */
	var defs = OAT.SVG.element("defs");
	var marker = OAT.SVG.element("marker",{id:"arrow"});
	var poly = OAT.SVG.element("polyline",{fill:self.options.edgeOptions.stroke,points:"0,0 10,4 0,7"});
	marker.setAttribute("viewBox","0 0 10 7");
	marker.setAttribute("refX","8");
	marker.setAttribute("refY","4");
	marker.setAttribute("markerUnits","strokeWidth");
	marker.setAttribute("orient","auto");
	marker.setAttribute("markerWidth","6");
	marker.setAttribute("markerHeight","6");

	var pattern = OAT.SVG.element("pattern",{id:"pattern",patternUnits:"userSpaceOnUse",x:0,y:0,width:10,height:10});
	var rect1 = OAT.SVG.element("rect",{x:0,y:0,width:5,height:5,fill:"lightblue"});
	var rect2 = OAT.SVG.element("rect",{x:5,y:5,width:5,height:5,fill:"lightblue"});

	OAT.Dom.append([self.svg,defs],[defs,marker,pattern],[marker,poly],[pattern,rect1,rect2]);

	this.lassoStart = function(event) { /* selecting multiple nodes */
		self.lasso = OAT.Dom.create("div",{position:"absolute",border:"2px dotted #0f0",width:"0px",height:"0px",zIndex:10});
		OAT.Event.attach(self.lasso,"mouseup",self.lassoStop);
		OAT.Event.attach(self.lasso,"mousemove",self.lassoProcess);
		var coords = OAT.Dom.position(self.parent);
		var exact = OAT.Event.position(event);
		var x = exact[0] - coords[0];
		var y = exact[1] - coords[1];
		self.lasso.style.left = x + "px";
		self.lasso.style.top = y + "px";
		self.lasso.origX = x;
		self.lasso.origY = y;
	}

	this.lassoProcess = function(event) {
		if (!self.lasso) { return; }
		if (!self.lasso.parentNode) { self.parent.appendChild(self.lasso); }
		var exact = OAT.Event.position(event);
		var pos = OAT.Dom.position(self.parent);
		var end_x = exact[0] - pos[0];
		var end_y = exact[1] - pos[1];
		var dx = end_x - self.lasso.origX;
		var dy = end_y - self.lasso.origY;
		if (dx < 0) {
			self.lasso.style.left = end_x + "px";
		}
		if (dy < 0) {
			self.lasso.style.top = end_y + "px";
		}
		self.lasso.style.width = Math.abs(dx) + "px";
		self.lasso.style.height = Math.abs(dy) + "px";
	}

	this.lassoStop = function(event) {
		if (!self.lasso) { return; }
		self.deselectGroups();
		self.deselectNodes();
		self.deselectEdges();
		var pos = OAT.Dom.getLT(self.lasso);
		var dims = OAT.Dom.getWH(self.lasso);
		for (var i=0;i<self.nodes.length;i++) {
			var n = self.nodes[i];
			if (n.x >= pos[0] && n.x <= pos[0]+dims[0] && n.y >= pos[1] && n.y <= pos[1]+dims[1]) { self.selectNode(n); }
		}
		OAT.Dom.unlink(self.lasso);
		self.lasso = false;
	}

	this.redraw = function() {
		for (var i=0;i<self.nodes.length;i++) { self.nodes[i].redraw(); }
		for (var i=0;i<self.groups.length;i++) { self.groups[i].redraw(); }
	}

	this.bbox = function(svgNode) {
		var fake = {x:-1,y:-1,w:0,h:0};
		if (svgNode.style.display == "none") { return fake; } /* hidden */
		if (!svgNode.parentNode) { return fake; } /* if not appended */
		if (!self.parent.offsetParent) { return fake; } /* if not visible */
		if (svgNode.nodeName == "text" && svgNode.textContent == "") { return fake; }
		return svgNode.getBBox();
	}

	this.twoGroupsCoords = function(g1,g2) { /* return 4 coordinates of edge between two groups */
		var x1,y1,x2,y2;
		g1.checkNodes();
		g2.checkNodes();

		var c1 = [];
		var c2 = [];

		for (var i=0;i<g1.nodes.length;i++) {
			for (var j=0;j<g1.nodes.length;j++) {
				if (i != j || g1.nodes.length == 1) {
					var n1 = g1.nodes[i];
					var n2 = g1.nodes[j];
					var x = (n1.draw_x + n2.draw_x)/2;
					var y = (n1.draw_y + n2.draw_y)/2;
					c1.push([x,y]);
				}
			}
		}

		for (var i=0;i<g2.nodes.length;i++) {
			for (var j=0;j<g2.nodes.length;j++) {
				if (i != j || g2.nodes.length == 1) {
					var n1 = g2.nodes[i];
					var n2 = g2.nodes[j];
					var x = (n1.draw_x + n2.draw_x)/2;
					var y = (n1.draw_y + n2.draw_y)/2;
					c2.push([x,y]);
				}
			}
		}

		var mindist = 100000;
		for (var i=0;i<c1.length;i++) {
			for (var j=0;j<c2.length;j++) {
				var cc1 = c1[i];
				var cc2 = c2[j];
				var dist = (cc1[0]-cc2[0])*(cc1[0]-cc2[0]) + (cc1[1]-cc2[1])*(cc1[1]-cc2[1]);
				if (dist < mindist) {
					mindist = dist;
					x1 = cc1[0];
					y1 = cc1[1];
					x2 = cc2[0];
					y2 = cc2[1];
				}
			}
		}
		return [x1,y1,x2,y2];
	}

	this.dragging = {
		obj:false,
		x:0,
		y:0,
		move:function(event) {
			if (!self.dragging.obj) { return; }
			var dx = event.clientX - self.dragging.x;
			var dy = event.clientY - self.dragging.y;
			self.dragging.x = event.clientX;
			self.dragging.y = event.clientY;
			if (self.dragging.obj == self) { /* moving the canvas */
				for (var i=0;i<self.nodes.length;i++) {
					var n = self.nodes[i];
					n.x += dx;
					n.y += dy;
				}
				self.redraw();
				return;
			}
			if (self.fakeEdge) { /* drawing an edge */
				var epos = OAT.Event.position(event);
				var pos = OAT.Dom.position(self.parent);
				var x = epos[0] - pos[0];
				var y = epos[1] - pos[1];
				self.fakeEdge._x2 = x;
				self.fakeEdge._y2 = y;
				self.fakeEdge.redraw();
			} else { /* moving selected nodes */
				if (self.selectedNodes.find(self.dragging.obj) == -1) {
					var o = self.dragging.obj;
					o.x += dx;
					o.y += dy;
					o.redraw();
				} else {
					for (var i=0;i<self.selectedNodes.length;i++) {
						var n = self.selectedNodes[i];
						n.x += dx;
						n.y += dy;
						n.redraw();
					} /* for all selected */
				} /* dragging selected nodes */
			} /* dragging some nodes */
		}, /* mousemove */
		up:function(event) {
			if (self.lasso) {
				self.lassoStop(event);
				return;
			}
			if (!self.dragging.obj) { return; }
			var o = self.dragging.obj;
			self.dragging.obj = false;

			if (self.fakeEdge) { /* if drawing mode */
				var l1 = self.fakeEdge.l1.textContent;
				var l2 = self.fakeEdge.l2.textContent;
				self.fakeEdge.unlink();
				var epos = OAT.Event.position(event);
				var pos = OAT.Dom.position(self.parent);
				var x = epos[0] - pos[0];
				var y = epos[1] - pos[1];
				var elm = self.findActiveElement(x,y,true);
				if (elm && elm instanceof OAT.SVGSparqlNode) {
					/* create correct new edge */
					var node1 = o;
					var node2 = elm;
					if (node1 == node2 && !self.options.allowSelfEdges) { return; }
					var e = self.addEdge(node1,node2,self.options.defaultEdgeValue);
					if (l1 != "") {
						e.setLabel(1,l1);
						e.setLabel(2,l2);
					}
				} else if (elm && elm instanceof OAT.SVGSparqlGroup) {
					var node1 = o;
					var group2 = elm;
					var e = self.addEdge(node1,group2,self.options.defaultEdgeValue);
					if (l1 != "") {
						e.setLabel(1,l1);
						e.setLabel(2,l2);
					}
				} /* not over node nor group */
			} else {
				self.redraw();
			}
		} /* self.dragging.up */
	} /* self.dragging */

	/*
		firefox trick: firefox sometimes displays 'dragging forbidden' cursor when we try to move nodes.
		this can be prevented by creating semi-transparent layer
	*/
	this.layers = {
		background:false,
		groups:false,
		nodes:false,
		edges:false,
		labels:false
	};
	for (var p in self.layers) {
		var g = OAT.SVG.element("g");
		self.layers[p] = g;
		self.svg.appendChild(g);
	}
	var r = OAT.SVG.element("rect",{x:0,y:0,width:"100%",height:"100%",fill:"#fff","fill-opacity":0.1});
	self.layers.background.appendChild(r);

	this.setProjection = function(newProjection) {
		self.projection = newProjection;
		self.prepareSphere();
		if (self.projection == OAT.SVGSparqlData.PROJECTION_SPHERICAL) {
			var sd = OAT.Geometry.sphericalData;
			if (!self.sphere) {
				self.sphere = OAT.SVG.element("circle",{cx:sd.cx,cy:sd.cy,r:sd.r,fill:"#000","fill-opacity":0.05});
				self.layers.background.appendChild(self.sphere);
			}
		} else {
			if (self.sphere) { OAT.Dom.unlink(self.sphere); self.sphere = false; }
		}
		self.redraw();
	}

	this.computeMinDist = function(w,h) {
		/* for each node, compute its distance to all other nodes & borders. find the minimum, add to total */
		var total = 0;
		var cnt = self.nodes.length;
		var dx,dy;
		for (var i=0;i<cnt;i++) {
			var n1 = self.nodes[i];
			/* distances to borders */
			var min = Math.min(n1.x,n1.y,w-n1.x,h-n1.y);
			for (var j=0;j<cnt;j++) {
				if (i != j) {
					var n2 = self.nodes[j];
					dx = n2.x - n1.x;
					dy = n2.y - n1.y;
					var dist = 0.5*Math.sqrt(dx*dx + dy*dy*dy); /* we prefer horizontal distance */
					if (dist < min) { min = dist; }
				}
			}
			total += min;
		}
		return total;
	}

	this.arrange = function(numIterations) { /* shift nodes to optimize space */
		var num = (numIterations ? numIterations : 5);
		var cnt = self.nodes.length;
		var dims = OAT.Dom.getWH(self.parent);
		var w = dims[0];
		var h = dims[1];
		var shiftSize = 20;
		var shiftMatrix = [
			[0,0],
			[1,0],
			[-1,0],
			[0,1],
			[0,-1],
			[1,1],
			[-1,-1],
			[1,-1],
			[-1,1]
		];
		for (var i=0;i<shiftMatrix.length;i++) {
			shiftMatrix[i][0] *= shiftSize;
			shiftMatrix[i][1] *= shiftSize;
		}
		/* place missing nodes to viewport */
		for (var i=0;i<cnt;i++) {
			var n = self.nodes[i];
			if (n.x < 0) { n.x = 0; }
			if (n.y < 0) { n.y = 0; }
			if (n.x > w) { n.x = w; }
			if (n.y > h) { n.y = h; }
		}
		for (var i=0;i<num;i++) {
			/* one iteration */
			for (var j=0;j<cnt;j++) {
				var node = self.nodes[j];
				var oldx = node.x;
				var oldy = node.y;
				var bestDist = self.computeMinDist(w,h);
				var bestIndex = 0;
				for (var k=1;k<shiftMatrix.length;k++) {
					/* test shift */
					node.x = oldx + shiftMatrix[k][0];
					node.y = oldy + shiftMatrix[k][1];
					var c = self.computeMinDist(w,h);
					if (node.x <= 0 || node.y <= 0 || node.x >=w || node.y >= h) { c = 0; }
					if (c > bestDist) {
						bestDist = c;
						bestIndex = k;
						k = shiftMatrix.length; /* end after first better result is found - optimization! */
					} /* if better result */
				} /* for all possible shifts */
				node.x = oldx + shiftMatrix[bestIndex][0];
				node.y = oldy + shiftMatrix[bestIndex][1];
			} /* for all nodes */
		} /* for all iterations */
		self.redraw();
	} /* arrange */

	this.reposition = function() {
		/* completely re-position and arrange all nodes */
		var components = [];
		var allNodes = [];
		var usedNodes = [];

		var walk = function(node) {
			var index = allNodes.find(node);
			if (index == -1) { return [false,0]; }
			usedNodes.push(node);
			allNodes.splice(index,1);
			var out = 0;
			var tmp = [false,-1];
			for (var i=0;i<node.edges.length;i++) {
				var e = node.edges[i];
				if (e.node1 != node && e.node1 instanceof OAT.SVGSparqlNode) { tmp = walk(e.node1); }
				if (e.node2 != node && e.node2 instanceof OAT.SVGSparqlNode) { tmp = walk(e.node2); out++; }
			}
			if (out > tmp[1]) { return [node,out]; } else { return tmp; }
		}

		for (var i=0;i<self.nodes.length;i++) { allNodes.push(self.nodes[i]); }
		while (allNodes.length) {
			var start = allNodes[0];
			var maxEdges = walk(start);
			components.push(maxEdges);
		}

		var dims = OAT.Dom.getWH(self.parent);
		var w = dims[0];
		var h = dims[1];
		var s = Math.ceil(Math.sqrt(components.length)); /* number of nodes in a row / column */
		var s2 = Math.ceil(components.length / s);
		var depth = 0;
		var coef1 = 1.5; /* distance increase for too dense nodes */
		//var coefX = Math.sqrt(w/h);
		var coefX = 1;
		//var coefY = Math.sqrt(h/w);
		var coefY = 1;

		/* find optimal distance */
		var dist = 80;
		if (self.nodes.length/components.length < 3) { dist = 120; }

		function computeAngle(index,numSiblings,parentAngle,first) {
			if (!first) {
				var angle = (parentAngle + Math.PI) + (index+1) * (2 * Math.PI) / (numSiblings+1);
			} else {
				/* first time - don't care about parent's angle */
				var angle = index * 2 * Math.PI / numSiblings;
			}
			return angle;
		}
		for (var ci=0;ci<components.length;ci++) {
			var centerNode = components[ci][0];
			/* draw one component */
			var v = w/(s+1);
			if (ci >= s*(s2-1)) { v = w/(components.length - s*(s2-1) + 1); }
			var cx = (ci % s + 1) * v;
			var cy = Math.floor(1 + ci / s) * (h/(s2+1));

			centerNode.x = cx;
			centerNode.y = cy;

			var positionedNodes = [];
			var workToDo = [[centerNode,0]];

			while (workToDo.length) {
				var node = workToDo[0][0]; /* this node needs children repositioned */
				var angle = workToDo[0][1]; /* this node needs children repositioned */
				workToDo.splice(0,1);
				positionedNodes.push(node);
				var children = [];
				for (var i=0;i<node.edges.length;i++) {
					var e = node.edges[i];
					if (e.node1 instanceof OAT.SVGSparqlNode && e.node1 != node && positionedNodes.find(e.node1) == -1 && children.find(e.node1) == -1)  { children.push(e.node1); }
					if (e.node2 instanceof OAT.SVGSparqlNode && e.node2 != node && positionedNodes.find(e.node2) == -1 && children.find(e.node1) == -1)  { children.push(e.node2); }
				}
				for (var i=0;i<children.length;i++) {
					var child = children[i];
					var a = 0.3 + computeAngle(i,children.length,angle,node == centerNode);
					var d = (children.length > 8 && i % 2) ? coef1*dist : dist;
					child.x = node.x + d * Math.cos(a) * coefX;
					child.y = node.y + d * Math.sin(a) * coefY;
					workToDo.push([child,a]);
				}
			} /* while work to do */
		} /* for all components */
		self.arrange();
	}

	this.addTarget = function(svgObj) {
		var testFunc = function(x_,y_) {
			var pos = OAT.Dom.position(self.parent);
			var x = x_ - pos[0];
			var y = y_ - pos[1];
			return svgObj.checkBBox(x,y);
		}
		self.ghostdrag.addTarget(svgObj,testFunc);
	}

	this.delTarget = function(svgObj) {
		self.ghostdrag.delTarget(svgObj);
	}

	this.clear = function() {
		self.nodes = [];
		self.edges = [];
		self.groups = [];
		self.deselectNodes();
		self.deselectEdges();
		self.deselectGroups();
		self.ghostdrag.clearTargets();
		var canvasCheck = function(x_,y_) {
			var pos = OAT.Dom.position(self.parent);
			var x = x_ - pos[0];
			var y = y_ - pos[1];
			var dims = OAT.Dom.getWH(self.parent);
			return (x >=0 && y >= 0 && x <= dims[0] && y <= dims[1]);
		}
		self.ghostdrag.addTarget(self,canvasCheck,true);
		for (var p in self.layers) if (p != "background") { OAT.Dom.clear(self.layers[p]); }
	}

	this.sphere = false;
	this.prepareSphere = function() {
		var dims = OAT.Dom.getWH(self.parent);
		var w = dims[0];
		var h = dims[1];
		var p = self.options.padding;
		OAT.Geometry.sphericalData.r = Math.min(w,h) / 2 - p;
		OAT.Geometry.sphericalData.R = OAT.Geometry.sphericalData.r * Math.PI / 2;
		OAT.Geometry.sphericalData.cx = w/2;
		OAT.Geometry.sphericalData.cy = h/2;
	}

	this.startDrawing = function(obj,clientX,clientY,label) {
		self.dragging.obj = obj;
		self.dragging.x = clientX;
		self.dragging.y = clientY;
		self.fakeEdge = OAT.SVG.element("line",self.options.edgeOptions);
		var l1 = OAT.SVG.element("text",self.options.fontOptions);
		var l2 = OAT.SVG.element("text",self.options.fontOptions);
		self.svg.appendChild(self.fakeEdge);
		self.svg.appendChild(l1);
		self.svg.appendChild(l2);
		var parts = label.split(",");
		l1.textContent = parts[0];
		if (parts.length > 1) { l2.textContent = parts[1]; }
		if (obj instanceof OAT.SVGSparqlNode) {
			self.fakeEdge._x1 = obj.draw_x;
			self.fakeEdge._y1 = obj.draw_y;
			self.fakeEdge._x2 = obj.draw_x;
			self.fakeEdge._y2 = obj.draw_y;
		}
		if (obj instanceof OAT.SVGSparqlGroup) {
			var pos = OAT.Dom.position(self.parent);
			var x = clientX - pos[0];
			var y = clientY - pos[1];
			var cog = obj.getCOG(x,y);
			if (!cog) { return; }
			self.fakeEdge._x1 = cog[0];
			self.fakeEdge._y1 = cog[1];
			self.fakeEdge._x2 = cog[0];
			self.fakeEdge._y2 = cog[1];
		}
		self.fakeEdge.l1 = l1;
		self.fakeEdge.l2 = l2;
		self.fakeEdge.redraw = function() {
			var x1 = self.fakeEdge._x1;
			var x2 = self.fakeEdge._x2;
			var y1 = self.fakeEdge._y1;
			var y2 = self.fakeEdge._y2;
			self.fakeEdge.setAttribute("x1",x1);
			self.fakeEdge.setAttribute("x2",x2);
			self.fakeEdge.setAttribute("y1",y1);
			self.fakeEdge.setAttribute("y2",y2);
			l1.setAttribute("x",(x2+x1)/2);
			l2.setAttribute("x",(x2+x1)/2);
			var y = (y2+y1)/2;
			l1.setAttribute("y",y);
			l2.setAttribute("y",y+self.options.fontOptions["font-size"]+2);
		}
		self.fakeEdge.unlink = function() {
			OAT.Dom.unlink(l1);
			OAT.Dom.unlink(l2);
			OAT.Dom.unlink(self.fakeEdge);
			self.fakeEdge = false;
		}
		self.fakeEdge.redraw();
	}

	this.deselectGroup = function(group) {
		var index = self.selectedGroups.find(group);
		if (index == -1) { return; }
		group.selected = false;
		self.selectedGroups.splice(index,1);
		if (self.options.deselectGroupCallback) { self.options.deselectGroupCallback(group); }
		if (group == self.selectedGroup) { self.selectedGroup = false; }
	}

	this.deselectNode = function(node) {
		var index = self.selectedNodes.find(node);
		if (index == -1) { return; }
		node.selected = false;
		self.selectedNodes.splice(index,1);
		if (self.options.deselectNodeCallback) { self.options.deselectNodeCallback(node); }
		if (node == self.selectedNode) { self.selectedNode = false; }
	}

	this.deselectEdge = function(edge) {
		var index = self.selectedEdges.find(edge);
		if (index == -1) { return; }
		edge.selected = false;
		self.selectedEdges.splice(index,1);
		if (self.options.deselectEdgeCallback) { self.options.deselectEdgeCallback(edge); }
		if (edge == self.selectedEdge) { self.selectedEdge = false; }
	}

	this.deselectGroups = function() {
		while (self.selectedGroups.length) { self.deselectGroup(self.selectedGroups[0]); }
	}

	this.deselectNodes = function() {
		while (self.selectedNodes.length) { self.deselectNode(self.selectedNodes[0]); }
	}

	this.deselectEdges = function() {
		while (self.selectedEdges.length) { self.deselectEdge(self.selectedEdges[0]); }
	}

	this.selectGroup = function(group) {
		self.selectedGroup = group;
		group.selected = true;
		self.selectedGroups.push(group);
		if (self.options.selectGroupCallback) { self.options.selectGroupCallback(group); }
	}

	this.selectNode = function(node) {
		self.selectedNode = node;
		node.selected = true;
		self.selectedNodes.push(node);
		if (self.options.selectNodeCallback) { self.options.selectNodeCallback(node); }
	}

	this.selectEdge = function(edge) {
		self.selectedEdge = edge;
		edge.selected = true;
		self.selectedEdges.push(edge);
		if (self.options.selectEdgeCallback) { self.options.selectEdgeCallback(edge); }
	}

	this.toggleGroup = function(group,event) {
		if (!event.shiftKey && !event.ctrlKey) {
			self.deselectGroups();
			self.deselectNodes();
			self.deselectEdges();
			self.selectGroup(group);
		} else {
			if (group.selected) { self.deselectGroup(group); } else { self.selectGroup(group); }
		}
	}

	this.toggleNode = function(node,event) {
		if (!event.shiftKey && !event.ctrlKey) {
			self.deselectGroups();
			self.deselectNodes();
			self.deselectEdges();
			self.selectNode(node);
		} else {
			if (node.selected) { self.deselectNode(node); } else { self.selectNode(node); }
		}
	}

	this.toggleEdge = function(edge,event) {
		if (!event.shiftKey && !event.ctrlKey) {
			self.deselectGroups();
			self.deselectNodes();
			self.deselectEdges();
			self.selectEdge(edge);
		} else {
			if (edge.selected) { self.deselectEdge(edge); } else { self.selectEdge(edge); }
		}
	}

	this.removeNode = function(node) {
		if (self.options.removeNodeCallback) { self.options.removeNodeCallback(node); }
		while (node.edges.length) { self.removeEdge(node.edges[0]); } /* remove all relevant edges */
		self.delTarget(node);
		var index = self.nodes.find(node);
		self.nodes.splice(index,1);
		for (var i=0;i<node.svgs.length;i++) {
			OAT.Dom.unlink(node.svgs[i]);
		}
		OAT.Dom.unlink(node.label1);
		OAT.Dom.unlink(node.label2);
		OAT.Dom.unlink(node.indicator);
		if (node == self.selectedNode) { self.deselectNode(); }
		if (node.group) { node.group.redraw(); }
	}

	this.removeEdge = function(edge) {
		/* remove from parent's array */
		if (self.options.removeEdgeCallback) { self.options.removeEdgeCallback(edge); }
		self.delTarget(edge);
		var i = edge.node1.edges.find(edge);
		edge.node1.edges.splice(i,1);
		var i = edge.node2.edges.find(edge);
		edge.node2.edges.splice(i,1);
		var index = self.edges.find(edge);
		self.edges.splice(index,1);
		OAT.Dom.unlink(edge.svg);
		OAT.Dom.unlink(edge.indicator);
		OAT.Dom.unlink(edge.label1);
		OAT.Dom.unlink(edge.label2);
		if (edge == self.selectedEdge) { self.deselectEdge(); }
	}

	this.toXML = function() {
		var xml = "";
		xml += "<sparql_design>\n";
		xml += "\t<nodes>\n";
		for (var i=0;i<self.nodes.length;i++) { xml += self.nodes[i].toXML(); }
		xml += "\t</nodes>\n";
		xml += "\t<edges>\n";
		for (var i=0;i<self.edges.length;i++) { xml += self.edges[i].toXML(); }
		xml += "\t</edges>\n";
		xml += "\t<groups>\n";
		for (var i=0;i<self.groups.length;i++) { xml += self.groups[i].toXML(); }
		xml += "\t</groups>\n";
		xml += "</sparql_design>\n";
		return xml;
	}

	this.fromXML = function(xmlNode) {
		self.clear();
		var nnodes = xmlNode.getElementsByTagName("node");
		var enodes = xmlNode.getElementsByTagName("edge");
		var gnodes = xmlNode.getElementsByTagName("group");
		for (var i=0;i<gnodes.length;i++) {
			var group = self.addGroup("");
			if (group) { group.fromXML(gnodes[i]); }
		}
		for (var i=0;i<nnodes.length;i++) {
			var node = self.addNode(0,0,"",1);
			if (node) { node.fromXML(nnodes[i]); }
		}
		for (var i=0;i<enodes.length;i++) {
			var nindex1 = parseInt(enodes[i].getAttribute("node1"));
			var nindex2 = parseInt(enodes[i].getAttribute("node2"));
			var gindex1 = parseInt(enodes[i].getAttribute("group1"));
			var gindex2 = parseInt(enodes[i].getAttribute("group2"));
			var first = (isNaN(gindex1) ? self.nodes[nindex1] : self.groups[gindex1]);
			var second = (isNaN(gindex2) ? self.nodes[nindex2] : self.groups[gindex2]);
			var edge = self.addEdge(first,second,"",1);
			edge.fromXML(enodes[i]);
		}
	}

	this.addEdge = function(node1,node2,value,loadMode) {
		/* check for inverse or same edge */
		for (var i=0;i<self.edges.length;i++) {
			var e = self.edges[i];
			if (e.node1 == node1 && e.node2 == node2) {
				alert("OAT.SVGSparql.addEdge:\nThis relationship can not be created, because the same relationship already exists.");
				return false;
			}
			if (e.node1 == node2 && e.node2 == node1) {
				alert("OAT.SVGSparql.addEdge:\nThis relationship can not be created, because inverse relationship exists.");
				return false;
			}
		}

		var edge = new OAT.SVGSparqlEdge(node1,node2,value,self,self.options.nodeOptions.size);
		if (self.options.addEdgeCallback) { self.options.addEdgeCallback(edge,loadMode); }
		self.addTarget(edge);
		self.edges.push(edge);
		self.layers.edges.appendChild(edge.svg);
		self.layers.edges.appendChild(edge.indicator);
		self.layers.labels.appendChild(edge.label1);
		self.layers.labels.appendChild(edge.label2);
		return edge;
	}

	this.addNode = function(x_,y_,value,loadMode) {
		var x = x_;
		var y = y_;
		if (self.projection == OAT.SVGSparqlData.PROJECTION_SPHERICAL) {
			var c = OAT.Geometry.fromSpherical(x,y);
			if (!c) {
				alert("OAT.SVGSparql.addNode:\nIn spherical mode, nodes must be placed within radius.");
				return false;
			}
			x = c[0];
			y = c[1];
		}
		var node = new OAT.SVGSparqlNode(x,y,value,self);
		if (self.options.addNodeCallback) { self.options.addNodeCallback(node,loadMode); }
		self.addTarget(node);
		self.nodes.push(node);
		self.layers.nodes.appendChild(node.svg);
		self.layers.nodes.appendChild(node.indicator);
		self.layers.labels.appendChild(node.label1);
		self.layers.labels.appendChild(node.label2);
		return node;
	}

	this.addGroup = function(label,loadMode) {
		var group = new OAT.SVGSparqlGroup(self,label);
		if (self.options.addGroupCallback) { self.options.addGroupCallback(group,loadMode); }
		self.groups.push(group);
		self.layers.groups.appendChild(group.svg);
		self.layers.labels.appendChild(group.label);
		group.redraw();
		return group;
	}

	this.removeGroup = function(group) {
		if (self.options.removeGroupCallback) { self.options.removeGroupCallback(group); }
		OAT.Dom.unlink(group.label);
		OAT.Dom.unlink(group.svg);
		while (group.edges.length) { self.removeEdge(group.edges[0]); } /* remove all relevant edges */
		var index = self.groups.find(group);
		for (var i=0;i<self.nodes.length;i++) {
			if (self.nodes[i].group == group) { self.nodes[i].setGroup(false); }
		}
		self.groups.splice(index,1);
		for (var i=0;i<self.groups.length;i++) {
			if (self.groups[i].parent == group) { self.groups[i].setParent(false); }
		}
	}

	this.findActiveElement = function(x,y,ignoreEdges) {
		for (var i=0;i<self.nodes.length;i++) { /* nodes first */
			var n = self.nodes[i];
			if (n.checkBBox(x,y)) { return n; }
		}
		if (!ignoreEdges) {
			for (var i=0;i<self.edges.length;i++) { /* then edges */
				var e = self.edges[i];
				if (e.checkBBox(x,y)) { return e; }
			}
		}
		/* groups are more difficult */
		var groupset = [];
		var forbiddenParents = [];
		for (var i=0;i<self.groups.length;i++) if (self.groups[i].checkBBox(x,y)) {
			groupset.push(self.groups[i]);
			if (self.groups[i].parent) { forbiddenParents.push(self.groups[i].parent); }
		}
		for (var i=0;i<groupset.length;i++) {
			var g = groupset[i];
			if (forbiddenParents.find(g) == -1) { return g; }
		}
		return false;
	}

	var downRef = function(event) { /* start dragging or moving */
		self.timeStamp = event.timeStamp;
		if (self.dragging.obj) { return; }
		var epos = OAT.Event.position(event);
		var pos = OAT.Dom.position(self.parent);
		var x = epos[0] - pos[0];
		var y = epos[1] - pos[1];
		var elm = self.findActiveElement(x,y,true);

		if (self.mode == OAT.SVGSparqlData.MODE_DRAG) {
			self.dragging.x = event.clientX;
			self.dragging.y = event.clientY;
			if (event.ctrlKey || event.shiftKey) {
				self.dragging.obj = self; /* whole canvas */
			} else if (!elm || !(elm instanceof OAT.SVGSparqlNode)) {
				self.lassoStart(event); /* lasso */
			} else {
				self.dragging.obj = elm; /* node (or set of nodes */
			}
		}

		if (self.mode == OAT.SVGSparqlData.MODE_DRAW) {
			if (!(elm instanceof OAT.SVGSparqlEdge)) {
				self.startDrawing(elm,event.clientX,event.clientY,"");
			}
		}

	}

	var clickRef = function(event) { /* add new node */
		var epos = OAT.Event.position(event);
		var pos = OAT.Dom.position(self.parent);
		var x = epos[0] - pos[0];
		var y = epos[1] - pos[1];
		if (self.mode == OAT.SVGSparqlData.MODE_ADD) {
			var ep = OAT.Event.position(event);
			var coords = OAT.Dom.position(self.parent);
			self.addNode(ep[0]-coords[0],ep[1]-coords[1],self.options.defaultNodeValue);
		}
		if (self.mode == OAT.SVGSparqlData.MODE_DRAG) {
			if (event.timeStamp - self.timeStamp > 500) { return; } /* ignore click > 500msec */
			var active = self.findActiveElement(x,y);
			if (!active) { return; }
			if (active instanceof OAT.SVGSparqlNode) { self.toggleNode(active,event); }
			if (active instanceof OAT.SVGSparqlEdge) { self.toggleEdge(active,event); }
			if (active instanceof OAT.SVGSparqlGroup) { self.toggleGroup(active,event); }
		}
	}

	var moveRef = function(event) { /* signalling */
		if (self.dragging.obj == self) { return; } /* do nothing when canvas is dragged */

		if (self.lasso) {
			self.lassoProcess(event);
			return;
		}

		var epos = OAT.Event.position(event);
		var pos = OAT.Dom.position(self.parent);
		var x = epos[0] - pos[0];
		var y = epos[1] - pos[1];

		var active = self.findActiveElement(x,y,self.fakeEdge != false);
		/* designal groups */
		for (var i=0;i<self.groups.length;i++) { if (active != self.groups[i]) { self.groups[i].signalStop(); } }
		/* designal edges */
		for (var i=0;i<self.edges.length;i++) { if (active != self.edges[i]) { self.edges[i].signalStop(); } }
		/* designal nodes */
		for (var i=0;i<self.nodes.length;i++) { if (active != self.nodes[i]) { self.nodes[i].signalStop(); } }
		if (!active) { return; }
		active.signalStart();
	}

	OAT.Event.attach(self.svg,"mousedown",downRef); /* start drag or draw */
	OAT.Event.attach(self.svg,"click",clickRef);
	OAT.Event.attach(document,"mousemove",moveRef);

	OAT.Event.attach(self.svg,"mousemove",self.dragging.move);
	OAT.Event.attach(self.svg,"mouseup",self.dragging.up);

	self.clear();
	self.prepareSphere();
}
