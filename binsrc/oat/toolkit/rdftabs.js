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
	var tab = new OAT.RDFTab.[name](parent, optObj);
	document.appendChild(tab.elm);
	tab.reset();
	tab.redraw();
	
	.rdf_sort .rdf_group .rdf_clear .rdf_data .rtf_tl_port .rdf_tl_slider
*/
OAT.RDFTabs = {};

OAT.RDFTabs.parent = function() {
	/* methods & properties that need to be implemented by each RDFTab */
	this.redraw = function() {} /* redraw contents */
	this.reset = function() {} /* triples were changed - reset */
	this.elm = OAT.Dom.create("div");
}

OAT.RDFTabs.browser = function(parent,optObj) {
	var self = this;
		
	this.options = {
		pageSize:20
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }
	
	this.initialized = false;
	this.dataDiv = OAT.Dom.create("div",{},"rdf_data");
	this.sortDiv = OAT.Dom.create("div",{},"rdf_sort");
	this.parent = parent;
	this.sortTerm = false;
	this.groupMode = false;
	this.currentPage = 0;

	this.reset = function() {
		self.sortTerm = false;
		self.groupMode = false;
		self.currentPage = 0;
	}
	
	this.sort = function(predicate) {
		var sf = function(a,b) {
			/* find values of this predicate */
			var a_ = false;
			var b_ = false;
			var ap = a[1];
			var bp = b[1];
			for (var i=0;i<ap.length;i++) { if (ap[i][0] == predicate) { a_ = ap[i][1]; }}
			for (var i=0;i<bp.length;i++) { if (bp[i][0] == predicate) { b_ = bp[i][1]; }}
			if (a_ == b_) { return 0; }
			if (a_ === false) { return 1; }
			if (b_ === false) { return -1; }
			if (parseFloat(a_) == a_) {
				var result = (parseFloat(a_) < parseFloat(b_) ? -1 : 1);
			} else {
				var result = (a_ < b_ ? -1 : 1);
			}
			return result;
		}
		self.parent.data.sort(sf);
		self.redraw();
	}
	

	this.drawItem = function(item) { /* one item */
		var div = OAT.Dom.create("div",{},"rdf_item");
		var h = OAT.Dom.create("h3");
		h.innerHTML = item[0];
		div.appendChild(h);
		if (item[0].match(/^http/i)) {
			self.parent.createAnchor(h,item[0]);
			h.style.cursor = "pointer";
		}

		var preds = item[1];
		for (var i=0;i<preds.length;i++) {
			/* check if predicate is not in filters */
			var predicate = preds[i];
			var ok = true;
			
			for (var j=0;j<self.parent.filtersProperty.length;j++) {
				var f = self.parent.filtersProperty[j];
				if (predicate[0] == f[0] && f[1] != "") { ok = false; }
			}
			if (!ok) { continue; } /* don't draw this property */
			
			var d = OAT.Dom.create("div");
			var strong = OAT.Dom.create("strong");
			strong.innerHTML = predicate[0]+": ";
			var content = false;
			
			/* decide output format */
			var data = preds[i][1];
			var r = false;
			if (data.match(/^http.*(jpe?g|png|gif)$/i)) { /* image */
				content = OAT.Dom.create("img");
				content.title = data;
				content.src = data;
				self.parent.createAnchor(content,data);
			} else if (data.match(/^http/i)) { /* link */
				content = OAT.Dom.create("a");
				content.innerHTML = data;
				content.href = data;
				self.parent.createAnchor(content,data);
			} else if (data.match(/^[^@]+@[^@]+$/i)) { /* mail address */
				content = OAT.Dom.create("a");
				var r = data.match(/^(mailto:)?(.*)/);
				content.innerHTML = r[2];
				content.href = 'mailto:'+r[2];
			} else { /* default - text */
				content = OAT.Dom.create("span");
				content.innerHTML = data;
			}
			/* create dereference a++ lookups for all anchors */
			var nodes = [];
			var anchors = content.getElementsByTagName("a");
			for (var j=0;j<anchors.length;j++) {
				var a = anchors[j];
				if (a.href.match(/^http/)) { self.parent.createAnchor(a,a.href); }
			}
			OAT.Dom.append([d,strong,content],[div,d]);
			
		} /* for all predicates */
		
		return div;
	}

	this.drawData = function() { /* set of items */
		OAT.Dom.clear(self.dataDiv);
		var h = OAT.Dom.create("h3");
		h.innerHTML = "Data";
		self.dataDiv.appendChild(h);
		
		self.pageDiv = OAT.Dom.create("div");
		self.dataDiv.appendChild(self.pageDiv);
		
		var toggleRef = function(gd) {
			return function() {
				gd.state = (gd.state+1) % 2;
				if (gd.state) { OAT.Dom.show(gd); } else { OAT.Dom.hide(gd); }
			}		
		}

		var groupDiv = false;
		var createGroup = function(label) {
			if (groupDiv) { groupDiv.appendChild(OAT.Dom.create("div",{},"rdf_clear")); }
			groupDiv = OAT.Dom.create("div",{display:"none"},"rdf_group");
			groupDiv.state = 0;
			var h = OAT.Dom.create("h3",{borderBottom:"1px solid #888",cursor:"pointer"});
			h.innerHTML = label;
			OAT.Dom.append([self.dataDiv,h,groupDiv]);
			OAT.Dom.attach(h,"click",toggleRef(groupDiv));
		}
		
		var groupValue = false;
		var findGV = function(record) {
			var result = false;
			var preds = record[1];
			for (var i=0;i<preds.length;i++) { if (preds[i][0] == self.sortTerm) { result = preds[i][1]; } }
			return result;
		}
		
		for (var i=0;i<self.parent.data.length;i++) {
			var index = i+1;
			var item = self.parent.data[i];
			if (self.groupMode) { /* grouping */
				var gv = findGV(item);
				if (gv != groupValue || i == 0) {
					/* create new group */
					groupValue = gv;
					createGroup(gv);
				}
				groupDiv.appendChild(self.drawItem(item));
			} else if (index >= self.currentPage * self.options.pageSize && index < (self.currentPage + 1) * self.options.pageSize) {
				self.dataDiv.appendChild(self.drawItem(item));
			} /* if in current page */
			
		} /* for all data items subjects */
	}

	this.drawPager = function() {
		var cnt = OAT.Dom.create("div");
		var div = OAT.Dom.create("div");
		var gd = OAT.Dom.create("div");
		var count = self.parent.data.length;
		cnt.innerHTML = "There are "+count+" records to match selected filters. ";
		if (count == 0) { cnt.innerHTML += "Perhaps your filters are too restrictive?"; }
		OAT.Dom.append([self.pageDiv,cnt,gd,div]);
		
		function assign(a,page) {
			a.setAttribute("title","Jump to page "+(page+1));
			a.setAttribute("href","javascript:void(0)");
			OAT.Dom.attach(a,"click",function() {
				self.currentPage = page;
				self.redraw();
			});
		}
		
		if (self.groupMode || self.sortTerm) {
			var cb = OAT.Dom.create("input");
			cb.type = "checkbox";
			cb.checked = self.groupMode;
			cb.id = "rdf_group_cb";
			var l = OAT.Dom.create("label");
			l.innerHTML = "Grouping";
			l.htmlFor = "rdf_group_cb";
			OAT.Dom.append([gd,cb,l]);
			OAT.Dom.attach(cb,"change",function() {
				self.groupMode = !self.groupMode;
				self.redraw();
			});
		} else {
			gd.innerHTML = "To enable grouping, order records by some value.";
		}

		if (count > self.options.pageSize && !self.groupMode) { /* create pager */
			div.innerHTML = "Page: ";
			var pagecount = Math.ceil(count/self.options.pageSize);
			for (var i=0;i<pagecount;i++) {
				var a = OAT.Dom.create("a");
				if (i != self.currentPage) { assign(a,i); }
				div.appendChild(OAT.Dom.text(" "));
				div.appendChild(a);
				a.innerHTML = i+1;
				div.appendChild(OAT.Dom.text(" "));
			}
		}
	}
	
	this.drawSort = function() {
		OAT.Dom.clear(self.sortDiv);
		var h = OAT.Dom.create("h3");
		h.innerHTML = "Order by";
		self.sortDiv.appendChild(h);
		
		var list = [];
		/* analyze sortable predicates */
		for (var i=0;i<self.parent.data.length;i++) {
			var preds = self.parent.data[i][1];
			for (var j=0;j<preds.length;j++) {
				var pair = preds[j];
				var pred = pair[0];
				var index1 = list.find(pred);
				var index2 = -1;
				for (var k=0;k<self.parent.filtersProperty.length;k++) { if (self.parent.filtersProperty[k][0] == pred) { index2 = j; } }
				if (index1 == -1 && index2 == -1) { list.push(pred); }
			} /* for all predicates */
		} /* for all data */
		
		var attach = function(elm,val) {
			OAT.Dom.attach(elm,"click",function() {
				self.sortTerm = val;
				self.sort(val);
			});
		}
		
		for (var i=0;i<list.length;i++) {
			var value = list[i];
			if (self.sortTerm == value) {
				var elm = OAT.Dom.create("span");
			} else {
				var elm = OAT.Dom.create("a");
				elm.href = "javascript:void(0);"
				attach(elm,list[i]);
			}
			elm.innerHTML = list[i];
			if (i) { self.sortDiv.appendChild(OAT.Dom.text(", ")); }
			self.sortDiv.appendChild(elm);
		}
	}
	
	this.redraw = function(complete) {
		if (!self.initialized) {
			self.initialized = true;
			OAT.Dom.append([self.elm,self.sortDiv,self.dataDiv]);
		} 
		self.drawSort();
		self.drawData();
		self.drawPager();
	}
}
OAT.RDFTabs.browser.prototype = new OAT.RDFTabs.parent();

OAT.RDFTabs.triples = function(parent,optObj) {
	var self = this;
	this.options = {
		limit:200
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }

	this.parent = parent;
	this.initialized = false;
	this.grid = false;
	
	this.patchAnchor = function(column) {
		var a = OAT.Dom.create("a");
		var v = self.grid.rows[self.grid.rows.length-1].cells[column].value;
		a.innerHTML = v.innerHTML;
		self.parent.createAnchor(a,a.innerHTML);
		OAT.Dom.clear(v);
		v.appendChild(a);
	}
	
	this.redraw = function() {
		if (!self.initialized) {
			self.initialized = true;
			self.grid = new OAT.Grid(self.elm,true,true);
		}
		self.grid.createHeader(["Subject","Predicate","Object"]);
		self.grid.clearData();
		
		var total = 0;
		for (var i=0;i<self.parent.data.length;i++) {
			var item = self.parent.data[i];
			for (var j=0;j<item[1].length;j++) {
				self.grid.createRow([item[0],item[1][j][0],item[1][j][1]]);
				if (item[0].match(/^http/i)) { self.patchAnchor(1); }
				if (item[1][j][1].match(/^http/i)) { self.patchAnchor(3); }
				total++;
				if (total == self.options.limit) { 
					j = item[1].length;
					i = self.parent.data.length;
					alert("There are more than "+self.options.limit+" triples. Such amount would greatly slow down your computer, "+
							"so I am going to display only first "+self.options.limit+".");
				}
			}
		}
	}
}
OAT.RDFTabs.triples.prototype = new OAT.RDFTabs.parent();

OAT.RDFTabs.svg = function(parent,optObj) {
	var self = this;
	this.options = {
		limit:100
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }

	this.parent = parent;
	this.elm.style.position = "relative";
	this.elm.style.top = "24px";
	
	this.redraw = function() {
		if (OAT.Dom.isIE()) { return; }
		var triples = [];
		/* create raw triples */
		for (var i=0;i<self.parent.data.length;i++) {
			var item = self.parent.data[i];
			for (var j=0;j<item[1].length;j++) {
				var t = [item[0],item[1][j][0],item[1][j][1]];
				t.push( item[1][j][1].match(/^http/i) ? 1 : 0);
				triples.push(t);
				if (triples.length == self.options.limit) { 
					j = item[1].length;
					i = self.parent.data.length;
					alert("There are more than "+self.options.limit+" triples. Such amount would greatly slow down your computer, "+
							"so I am going to display only first "+self.options.limit+".");
				}
			}
		}
		var x = OAT.GraphSVGData.fromTriples(triples);
		self.graphsvg = new OAT.GraphSVG(self.elm,x[0],x[1],{vertexSize:[4,8]});
	}
}
OAT.RDFTabs.svg.prototype = new OAT.RDFTabs.parent();

OAT.RDFTabs.map = function(parent,optObj) {
	var self = this;
	
	this.options = {
		provider:OAT.MapData.TYPE_G
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }

	this.map = false;
	this.parent = parent;
	this.elm.style.position = "relative";
	this.elm.style.width = "100%";
	this.elm.style.height = "100%";
	
	this.keyProperties = ["based_near","geo"];
	this.latProperties = ["lat","latitude"];
	this.lonProperties = ["lon","long","longitude"];

	this.tryItem = function(item) {
		var preds = item[1];
		var pointResource = false;
		for (var i=0;i<preds.length;i++) {
			var p = preds[i];
			if (self.keyProperties.find(p[0]) != -1) { pointResource = p[1]; } /* this is resource containig geo coordinates */
		}
		if (!pointResource) { return false; }
		for (var i=0;i<self.parent.data.length;i++) {
			var it = self.parent.data[i];
			if (it[0] == pointResource) {
				/* find coords */
				var coords = [0,0];
				for (var j=0;j<it[1].length;j++) {
					if (self.latProperties.find(it[1][j][0]) != -1) { coords[0] = it[1][j][1]; }
					if (self.lonProperties.find(it[1][j][0]) != -1) { coords[1] = it[1][j][1]; }
				} /* for all geo properties */
				if (coords[0] == 0 || coords[1] == 0) { return false; }
				return coords;
			} /* geo resource */
		} /* for all resources */
	}
	
	this.attachMarker = function(data,item) {
		var m = false;
		var callback = function() {
			var div = OAT.Dom.create("div");
			var s = OAT.Dom.create("div",{fontWeight:"bold"});
			s.innerHTML = item[0];
			div.appendChild(s);
			var preds = item[1];
			for (var i=0;i<preds.length;i++) {
				var p = preds[i][0];
				var o = preds[i][1];
				if (self.keyProperties.find(p) != -1) { continue; }
				var s = OAT.Dom.create("div");
				s.innerHTML = p+": "+o;
				div.appendChild(s);
			}
			self.map.openWindow(m,div);
		}
		m = self.map.addMarker(1,data[0],data[1],false,false,false,callback);
	}
	
	this.redraw = function() {
		self.map = new OAT.Map(self.elm,self.options.provider);
		self.map.centerAndZoom(0,0,0);
		self.map.addTypeControl();
		self.map.addMapControl();
		var list = [];
		for (var i=0;i<self.parent.data.length;i++) {
			var item = self.parent.data[i];
			var data = self.tryItem(item);
			if (!data) { continue; }
			/* add marker */
			self.attachMarker(data,item);
			list.push(data);
		}
		self.map.optimalPosition(list);
	}
}
OAT.RDFTabs.map.prototype = new OAT.RDFTabs.parent();

OAT.RDFTabs.timeline = function(parent,optObj) {
	var self = this;
	
	this.options = {
		imagePath:OAT.Preferences.imagePath
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }

	this.initialized = false;
	this.parent = parent;
	this.elm.style.position = "relative";
	this.elm.style.width = "100%";
	this.elm.style.height = "100%";
	this.elm.style.top = "20px";
	
	this.port = OAT.Dom.create("div",{},"rdf_tl_port");
	this.slider = OAT.Dom.create("div",{},"rdf_tl_slider");
	OAT.Dom.append([self.elm,self.port,self.slider]);

	this.tryItem = function(item) {
		var preds = item[1];
		var pointResource = false;
		for (var i=0;i<preds.length;i++) {
			var p = preds[i];
			if (p[0] == "date") { return p[1]; }
		}
		return false;
	}
	
	this.redraw = function() {
		if (!self.initialized) {
			self.tl = new OAT.Timeline(self.port,self.slider,self.options);
			self.initialized = true;
		}	
		self.tl.clear();
		self.tl.addBand("Timeline","#8FaFcE");
		
		for (var i=0;i<self.parent.data.length;i++) {
			var item = self.parent.data[i];
			var date = self.tryItem(item);
			if (!date) { continue; }
			/* add event */
			var content = OAT.Dom.create("div",{left:"-7px"});
			var ball = OAT.Dom.create("div",{width:"16px",height:"16px",cssFloat:"left",styleFloat:"left"});
			ball.style.backgroundImage = "url("+self.options.imagePath+"Timeline_circle.png)";
			var t = OAT.Dom.create("span");
			t.innerHTML = item[0];
			OAT.Dom.append([content,ball,t]);
			self.tl.addEvent("Timeline",date,date,content,"#ddd");
		}
		self.tl.draw();
		self.tl.slider.slideTo(0,1);
	}
}
OAT.RDFTabs.timeline.prototype = new OAT.RDFTabs.parent();

OAT.Loader.featureLoaded("rdftabs");
