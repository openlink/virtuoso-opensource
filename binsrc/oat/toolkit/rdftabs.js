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
	this.reset = function(hard) {} /* triples were changed - reset */
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
	this.descDiv = OAT.Dom.create("div");
	this.descDiv.innerHTML = "This module is used for viewing all filtered data, structured into resource items.";
	this.parent = parent;
	this.sortTerm = false;
	this.groupMode = false;
	this.currentPage = 0;


	this.reset = function(hard) {
		self.sortTerm = false;
		self.groupMode = false;
		self.currentPage = 0;
	}
	
	this.sort = function(predicate) {
		var sf = function(a,b) {
			/* find values of this predicate */
			var a_ = false;
			var b_ = false;
			var ap = a.preds;
			var bp = b.preds;
			for (var p in ap) { if (p == predicate) { a_ = ap[p][0]; }}
			for (var p in bp) { if (p == predicate) { b_ = bp[p][0]; }}
			if (typeof(a_) == "object") { a_ = a_.uri; }
			if (typeof(b_) == "object") { b_ = b_.uri; }
			
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
		self.parent.data.structured.sort(sf);
		self.redraw();
	}
	

	this.drawItem = function(item) { /* one item */
		var div = OAT.Dom.create("div",{},"rdf_item");
		var h = OAT.Dom.create("h3");
		var s = OAT.Dom.create("span");
		var uri = item.uri;
		s.innerHTML = uri;
		OAT.Dom.append([div,h],[h,s]);
		if (uri.match(/^http/i)) {
			self.parent.createAnchor(s,uri);
			var imglist = self.parent.generateImageActions(uri);
			OAT.Dom.append([h,imglist]);
			s.style.cursor = "pointer";
		}

		var preds = item.preds;
		for (var p in preds) {
			/* check if predicate is not in filters */
			var pred = preds[p];
			var ok = true;
			
			for (var i=0;i<self.parent.filtersProperty.length;i++) {
				var f = self.parent.filtersProperty[i];
				if (p == f[0] && f[1] != "") { ok = false; }
			}
			if (!ok) { continue; } /* don't draw this property */
			
			var d = OAT.Dom.create("div");
			var strong = OAT.Dom.create("strong");
			strong.innerHTML = p+": ";
			OAT.Dom.append([d,strong],[div,d]);
			
			/* decide output format */
			for (var i=0;i<pred.length;i++) {
				var value = pred[i];
				var content = self.parent.getContent(value);
				if (i) { d.appendChild(OAT.Dom.text(", ")); }
				d.appendChild(content);
			}
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
			var preds = record.preds;
			for (p in preds) { 
				if (p == self.sortTerm) { result = preds[p][0]; } /* take first */
			}
			if (typeof(result) == "object") { result = result.uri; }
			return result;
		}
		
		var data = self.parent.data.structured;
		for (var i=0;i<data.length;i++) {
			var item = data[i];
			if (self.groupMode) { /* grouping */
				var gv = findGV(item);
				if (gv != groupValue || i == 0) {
					/* create new group */
					groupValue = gv;
					createGroup(gv);
				}
				groupDiv.appendChild(self.drawItem(item));
			} else if (i >= self.currentPage * self.options.pageSize && i < (self.currentPage + 1) * self.options.pageSize) {
				self.dataDiv.appendChild(self.drawItem(item));
			} /* if in current page */
			
		} /* for all data items subjects */
	}

	this.drawPager = function() {
		var cnt = OAT.Dom.create("div");
		var div = OAT.Dom.create("div");
		var gd = OAT.Dom.create("div");
		var count = self.parent.data.structured.length;
		var tcount = self.parent.data.triples.length;
		var pcount = 0;
		for (var i=0;i<self.parent.data.structured.length;i++) {
			var item = self.parent.data.structured[i];
			for (var p in item.preds) { pcount++; }
		}
		
		cnt.innerHTML = "There are "+count+" records ("+tcount+" triples, "+pcount+" predicates) to match selected filters. ";
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
		var data = self.parent.data.structured;
		for (var i=0;i<data.length;i++) {
			var item = data[i];
			var preds = item.preds;
			for (var p in preds) {
				var index1 = list.find(p);
				var index2 = -1;
				for (var j=0;j<self.parent.filtersProperty.length;j++) { if (self.parent.filtersProperty[j][0] == p) { index2 = p; } }
				if (index1 == -1 && index2 == -1) { list.push(p); }
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
	
	this.redraw = function() {
		if (!self.initialized) {
			self.initialized = true;
			OAT.Dom.append([self.elm,self.descDiv,self.sortDiv,self.dataDiv]);
		} 
		self.drawSort();
		self.drawData();
		self.drawPager();
	}
}
OAT.RDFTabs.browser.prototype = new OAT.RDFTabs.parent();

OAT.RDFTabs.navigator = function(parent,optObj) {
	var self = this;
		
	this.options = {
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }
	
	this.initialized = false;
	this.parent = parent;
	this.history = [];
	this.historyIndex = -1;
	this.nav = {};
	this.topDiv = OAT.Dom.create("div",{},"rdf_nav");
	this.mainDiv = OAT.Dom.create("div",{},"rdf_item");
	this.descDiv = OAT.Dom.create("div");
	this.descDiv.innerHTML = "This module is used for navigating through all locally cached data, one resource at a time. "+
							"Note that filters doesn't apply here, all data is displayed.";
	OAT.Dom.append([self.elm,self.descDiv,self.topDiv,self.mainDiv]);

	this.attach = function(elm,item) {
		OAT.Dom.addClass(elm,"rdf_link");
		OAT.Dom.attach(elm,"click",function() {
			self.history.splice(self.historyIndex+1,self.history.length-self.history.index+1); /* clear forward history */
			self.history.push(item);
			self.navigate(self.history.length-1);
		});
	}
	
	this.drawPredicate = function(name,pred) { /* draw one pred's content; return DIV */
		var d = OAT.Dom.create("div");
		var strong = OAT.Dom.create("strong");
		strong.innerHTML = name+": ";
		OAT.Dom.append([d,strong]);

		/* decide output format */
		for (var i=0;i<pred.length;i++) {
			var value = pred[i];
			var svalue = (typeof(value) == "object" ? value.uri : value);
			var type = self.parent.getContentType(svalue);
			if (type == 3) { /* image */
				var content = OAT.Dom.create("img");
				content.src = svalue;
			} else { /* text */
				var content = OAT.Dom.create("span");
				content.innerHTML = svalue;
			}
			
			if (typeof(value) == "object") { /* link! */
				self.attach(content,value);
			}
			
			if (i) { d.appendChild(OAT.Dom.text(", ")); }
			d.appendChild(content);
		}
		return d;
	}
	
	this.drawItem = function(item) { /* one item */
		OAT.Dom.clear(self.mainDiv);
		var h = OAT.Dom.create("h3");
		h.innerHTML = item.uri;
		self.mainDiv.appendChild(h);

		var preds = item.preds;
		for (var p in preds) {
			var pred = preds[p];
			self.mainDiv.appendChild(self.drawPredicate(p,pred));
		} /* for all predicates */
		
		/* draw ancestors */
		var h = OAT.Dom.create("h3");
		h.innerHTML = "What links here";
		self.mainDiv.appendChild(h);
		for (var i=0;i<item.back.length;i++) {
			if (i) { self.mainDiv.appendChild(OAT.Dom.text(", ")); }
			var sitem = item.back[i];
			var s = OAT.Dom.create("span");
			s.innerHTML = sitem.uri;
			self.attach(s,sitem);
			self.mainDiv.appendChild(s);
		}
	}

	this.navigate = function(index) {
		var item = self.history[index];
		self.drawItem(item);
		self.historyIndex = index;
		self.redrawTop();
	}
	
	this.reset = function(hard) {
		if (!hard) { return; } /* we ignore filters */
		self.historyIndex = -1;
		self.history = [];
	}
	
	this.redrawTop = function() {
		var activate = function(elm) {
			OAT.Style.opacity(elm,1);
			elm.style.cursor = "pointer";
		}
		var deactivate = function(elm) {
			OAT.Style.opacity(elm,0.3);
			elm.style.cursor = "default";
		}
		if (self.historyIndex > 0) {
			activate(self.nav.first);
			activate(self.nav.prev);
		} else {
			deactivate(self.nav.first);
			deactivate(self.nav.prev);
		}
		
		if (self.historyIndex > -1 && self.historyIndex < self.history.length-1) {
			activate(self.nav.next);
			activate(self.nav.last);
		} else {
			deactivate(self.nav.next);
			deactivate(self.nav.last);
		}
		
		if (self.historyIndex != -1) {
			activate(self.nav.help);
		} else {
			deactivate(self.nav.help);
		}
	}
	
	this.redraw = function() {
		if (self.historyIndex != -1) { 
			self.navigate(self.historyIndex);
			return;
		}
		/* give a list of items for navigation */
		OAT.Dom.clear(self.mainDiv);
		var h = OAT.Dom.create("h3");
		h.innerHTML = "Please pick a starting resource";
		self.mainDiv.appendChild(h);
		for (var i=0;i<self.parent.data.structured.length;i++) {
			var item = self.parent.data.structured[i];
			var div = OAT.Dom.create("div");
			var a = OAT.Dom.create("span");
			a.innerHTML = item.uri;
			self.attach(a,item);
			OAT.Dom.append([self.mainDiv,div],[div,a]);
		}
		self.redrawTop();
	}

	this.initTop = function() {
		var ip = self.parent.options.imagePath;
		var b = ip+"Blank.gif";
		self.nav.first = OAT.Dom.create("div");
		self.nav.prev = OAT.Dom.create("div");
		self.nav.help = OAT.Dom.create("div");
		self.nav.next = OAT.Dom.create("div");
		self.nav.last = OAT.Dom.create("div");
		self.nav.first.appendChild(OAT.Dom.image(ip+"RDF_first.png",b,16,16));
		self.nav.prev.appendChild(OAT.Dom.image(ip+"RDF_prev.png",b,16,16));
		self.nav.help.appendChild(OAT.Dom.image(ip+"RDF_help.png",b,16,16));
		self.nav.next.appendChild(OAT.Dom.image(ip+"RDF_next.png",b,16,16));
		self.nav.last.appendChild(OAT.Dom.image(ip+"RDF_last.png",b,16,16));
		self.nav.first.title = "First";
		self.nav.prev.title = "Back";
		self.nav.help.title = "List of resources";
		self.nav.next.title = "Forward";
		self.nav.last.title = "Last";
		OAT.Dom.append([self.topDiv,self.nav.first,self.nav.prev,self.nav.help,self.nav.next,self.nav.last]);
		OAT.Dom.attach(self.nav.first,"click",function(){
			if (self.historyIndex > 0) { self.navigate(0); }
		});
		OAT.Dom.attach(self.nav.prev,"click",function(){
			if (self.historyIndex > 0) { self.navigate(self.historyIndex-1); }
		});
		OAT.Dom.attach(self.nav.next,"click",function(){
			if (self.historyIndex > -1 && self.historyIndex < self.history.length-1) { self.navigate(self.historyIndex+1); }
		});
		OAT.Dom.attach(self.nav.last,"click",function(){
			if (self.historyIndex > -1 && self.historyIndex < self.history.length-1) { self.navigate(self.history.length-1); }
		});
		OAT.Dom.attach(self.nav.help,"click",function(){
			if (self.historyIndex != -1) { 
				self.historyIndex = -1;
				self.history = [];
				self.redraw();
			}
		});
	}
	self.initTop();
}
OAT.RDFTabs.navigator.prototype = new OAT.RDFTabs.parent();

OAT.RDFTabs.triples = function(parent,optObj) {
	var self = this;
	this.options = {
		pageSize:100
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }

	this.parent = parent;
	this.initialized = false;
	this.grid = false;
	this.currentPage = 0;
	this.pageDiv = OAT.Dom.create("div");
	this.gridDiv = OAT.Dom.create("div");
	this.descDiv = OAT.Dom.create("div");
	this.descDiv.innerHTML = "This module displays all filtered triples.";
	OAT.Dom.append([self.elm,self.descDiv,self.pageDiv,self.gridDiv]);
	
	this.patchAnchor = function(column) {
		var a = OAT.Dom.create("a");
		var v = self.grid.rows[self.grid.rows.length-1].cells[column].value;
		a.innerHTML = v.innerHTML;
		self.parent.createAnchor(a,a.innerHTML);
		var imglist = self.parent.generateImageActions(a.innerHTML);
		OAT.Dom.clear(v);
		OAT.Dom.append([v,a,imglist]);;
	}
	
	this.reset = function() {
		self.currentPage = 0;
	}
	
	this.drawPager = function() {
		var cnt = OAT.Dom.create("div");
		var div = OAT.Dom.create("div");
		var count = self.parent.data.triples.length;

		cnt.innerHTML = "There are "+count+" triples available.";
		OAT.Dom.clear(self.pageDiv);
		OAT.Dom.append([self.pageDiv,cnt,div]);
		
		function assign(a,page) {
			a.setAttribute("title","Jump to page "+(page+1));
			a.setAttribute("href","#");
			OAT.Dom.attach(a,"click",function() {
				self.currentPage = page;
				self.redraw();
			});
		}
		
		if (count > self.options.pageSize) { /* create pager */
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
	
	this.redraw = function() {
		if (!self.initialized) {
			self.initialized = true;
			self.grid = new OAT.Grid(self.gridDiv,true,true);
		}
		self.grid.createHeader(["Subject","Predicate","Object"]);
		self.grid.clearData();
		self.grid.rowOffset = self.options.pageSize * self.currentPage;
		
		var total = 0;
		var triples = self.parent.data.triples;

		for (var i=0;i<triples.length;i++) {
			if (i >= self.currentPage * self.options.pageSize && i < (self.currentPage + 1) * self.options.pageSize) {
			var triple = triples[i];
			self.grid.createRow(triple);
			if (triple[0].match(/^http/i)) { self.patchAnchor(1); }
			if (triple[2].match(/^http/i)) { self.patchAnchor(3); }
			} /* if in current page */
		} /* for all triples */
		self.drawPager();
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
	this.svgDiv = OAT.Dom.create("div");
	this.descDiv = OAT.Dom.create("div");
	this.descDiv.innerHTML = "This module displays filtered data as SVG Graph. For performance reasons, the number of used triples is limited to "+self.options.limit+".";
	this.svgDiv.style.position = "relative";
	this.svgDiv.style.height = "600px";
	this.svgDiv.style.top = "24px";
	OAT.Dom.append([self.elm,self.descDiv,self.svgDiv]);
	
	this.redraw = function() {
		/* create better triples */
		var triples = [];
		var cnt = self.parent.data.triples.length;
		if (cnt > self.options.limit) { 
					alert("There are more than "+self.options.limit+" triples. Such amount would greatly slow down your computer, "+
							"so I am going to display only first "+self.options.limit+".");
			cnt = self.options.limit;
				}
		
		for (var i=0;i<cnt;i++) {
			var t = self.parent.data.triples[i];
			var triple = [t[0],t[1],t[2],(t[2].match(/^http/i) ? 1 : 0)];
			triples.push(triple);
		}
		var x = OAT.GraphSVGData.fromTriples(triples);
		self.graphsvg = new OAT.GraphSVG(self.svgDiv,x[0],x[1],{vertexSize:[4,8]});
		
		for (var i=0;i<self.graphsvg.data.length;i++) {
			var node = self.graphsvg.data[i];
			if (node.name.match(/^http/i)) {
				self.parent.createAnchor(node.svg,node.name);
			}
		}
	}
}
OAT.RDFTabs.svg.prototype = new OAT.RDFTabs.parent();

OAT.RDFTabs.map = function(parent,optObj) {
	var self = this;
	
	this.options = {
		provider:OAT.MapData.TYPE_G,
		fix:OAT.MapData.FIX_ROUND1
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }

	this.map = false;
	this.parent = parent;
	this.descDiv = OAT.Dom.create("div");
	this.descDiv.innerHTML = "This module plots all geodata found in filtered resources onto a map.";
	this.mapDiv = OAT.Dom.create("div");
	this.mapDiv.style.position = "relative";
	this.mapDiv.style.height = "600px";
	OAT.Dom.append([self.elm,self.descDiv,self.mapDiv]);
	
	this.keyProperties = ["based_near","geo"]; /* containing coordinates */
	this.locProperties = ["location"]; /* containing location */
	this.latProperties = ["lat","latitude"];
	this.lonProperties = ["lon","long","longitude"];
	this.lookupProperties = ["name","location"]; /* interesting to be put into lookup pin */

	this.geoCode = function(address,item) {
		self.pointListLock++;
		var cb = function(coords) {
			if (coords && coords[0] != 0 && coords[1] != 0) {
				self.pointList.push(coords);
				self.attachMarker(coords,item);
			}
			self.pointListLock--;
		}
		self.map.geoCode(address,cb);
	}
	
	this.tryItem = function(item) {
		var preds = item.preds;
		var pointResource = false;
		var locValue = false;
		for (var p in preds) {
			var pred = preds[p];
			if (self.keyProperties.find(p) != -1) { pointResource = pred[0]; } /* this is resource containig geo coordinates */
			if (self.locProperties.find(p) != -1) { locValue = pred[0]; } /* this is resource containig geo coordinates */
		}
		if (!pointResource && !locValue) { return false; }
		
		if (!pointResource) { /* geocode location */
			self.geoCode(locValue,item);
			return;
		}
		if (typeof(pointResource) != "object") { return; } /* not a reference */
		/* normal marker add */
		var it = pointResource;
				var coords = [0,0];
		var preds = it.preds;
		for (var p in preds) {
			var pred = preds[p];
			if (self.latProperties.find(p) != -1) { coords[0] = pred[0]; }
			if (self.lonProperties.find(p) != -1) { coords[1] = pred[0]; }
				} /* for all geo properties */
				if (coords[0] == 0 || coords[1] == 0) { return; }
				self.pointList.push(coords);
				self.attachMarker(coords,item);
	} /* tryItem */
	
	this.attachMarker = function(coords,item) {
		var m = false;
		var callback = function() { /* draw item contents */
			if (OAT.AnchorData.window) { OAT.AnchorData.window.close(); }
			var div = OAT.Dom.create("div",{overflow:"auto",width:"450px",height:"250px"});
			var s = OAT.Dom.create("div",{fontWeight:"bold"});
			var title = self.parent.getTitle(item);
			s.innerHTML = title;
			if (title.match(/^http/i)) { 
				self.parent.createAnchor(s,title); 
				s.style.cursor = "pointer";
			}
			div.appendChild(s);
			var preds = item.preds;
			for (var p in preds) {
				var pred = preds[p];
				if (pred.length == 1 || self.lookupProperties.find(p) != -1) {
				var s = OAT.Dom.create("div");
					s.innerHTML = p+": ";
					var content = self.parent.getContent(pred[0],"replace");
					OAT.Dom.append([s,content],[div,s]);
				} /* only interesting data */
			} /* for all predicates */
			self.map.openWindow(m,div);
		}
		var ouri = item.ouri;
		if (!(ouri in self.markerMapping)) {
			self.markerMapping[ouri] = self.markerFiles[self.markerIndex % self.markerFiles.length];
			self.markerIndex++;
		}
		var file = self.markerMapping[ouri];
		m = self.map.addMarker(1,coords[0],coords[1],file,18,41,callback);
	}
	
	this.redraw = function() {
		var markerPath = OAT.Preferences.imagePath+"markers/";
		self.markerFiles = []; 
		for (var i=1;i<=12;i++) {
			var name = markerPath + (i<10?"0":"") + i +".png";
			self.markerFiles.push(name);
		}
		self.markerIndex = 0;
		self.markerMapping = {};

		self.map = new OAT.Map(self.mapDiv,self.options.provider,{fix:self.options.fix});
		self.map.centerAndZoom(0,0,0);
		self.map.addTypeControl();
		self.map.addMapControl();
		self.pointList = [];
		self.pointListLock = 0;
		for (var i=0;i<self.parent.data.structured.length;i++) {
			var item = self.parent.data.structured[i];
			var data = self.tryItem(item);
		}
		
		OAT.Resize.createDefault(self.mapDiv);

		function tryList() {
			if (!self.pointListLock) { 
				if (!self.pointList.length) { alert("Nothing displayable was found."); }
				self.map.optimalPosition(self.pointList); 
			} else {
				setTimeout(tryList,500);
			}
		}
		tryList();
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
	this.tlDiv = OAT.Dom.create("div");
	this.descDiv = OAT.Dom.create("div");
	this.descDiv.innerHTML = "This module displays all date/time containing resources on an interactive time line.";
	this.tlDiv.style.position = "relative";
	this.tlDiv.style.width = "100%";
	this.tlDiv.style.margin = "1em";
	this.tlDiv.style.top = "20px";
	OAT.Dom.append([self.elm,self.descDiv,self.tlDiv]);
	
	this.bothProperties = ["date"]; /* containing coordinates */
	this.startProperties = ["dtstart"]; /* containing location */
	this.endProperties = ["dtend"];
	this.subProperties = ["dateTime"];
	
	
	this.tryDeepItem = function(value) {
		if (typeof(value) != "object") { return value; }
		for (var p in value.preds) {
			var pred = value.preds[p];
			if (self.subProperties.find(p) != -1) { return pred[0]; }
		}
		return false;
	}
	
	this.tryItem = function(item) {
		var preds = item.preds;
		var start = false;
		var end = false;
		for (var p in preds) {
			var pred = preds[p];
			if (self.bothProperties.find(p) != -1) {
				var value = pred[0];
				start = self.tryDeepItem(value);
				end = self.tryDeepItem(value);
			}
			if (self.startProperties.find(p) != -1) {
				var value = pred[0];
				start = self.tryDeepItem(value);
			}
			if (self.endProperties.find(p) != -1) {
				var value = pred[0];
				end = self.tryDeepItem(value);
			}
		}
		if (!start || !end) { return false; }
		return [start,end];
	}
	
	this.redraw = function() {
		if (!self.initialized) {
			self.tl = new OAT.Timeline(self.tlDiv,self.options);
			self.initialized = true;
		}	
		var uris = [];
		self.tl.clear();
		var colors = ["#cf6","#887fff","#66ffe6","#fb9","#7fff66","#ff997f","#96f"]; /* pastel */
		
		for (var i=0;i<self.parent.data.structured.length;i++) {
			var item = self.parent.data.structured[i];
			var date = self.tryItem(item);
			if (!date) { continue; }
			var ouri = item.ouri;
			if (uris.find(ouri) == -1) {
				self.tl.addBand(ouri,colors[uris.length % colors.length]);
				uris.push(ouri);
			}
			var start = date[0];
			var end = date[1];
			/* add event */
			var content = OAT.Dom.create("div",{left:"-7px"});
			var ball = OAT.Dom.create("div",{width:"16px",height:"16px",cssFloat:"left",styleFloat:"left"});
			ball.style.backgroundImage = "url("+self.options.imagePath+"Timeline_circle.png)";
			var uri = self.parent.getURI(item);
			if (uri) {
			var t = OAT.Dom.create("a");
				self.parent.createAnchor(t,uri);
			} else {
				var t = OAT.Dom.create("span");
			}
			t.innerHTML = self.parent.getTitle(item);
			OAT.Dom.append([content,ball,t]);
			self.tl.addEvent(ouri,start,end,content,"#ddd");
		}
		self.tl.draw();
		self.tl.slider.slideTo(0,1);
	}
}
OAT.RDFTabs.timeline.prototype = new OAT.RDFTabs.parent();


OAT.RDFTabs.images = function(parent,optObj) {
	var self = this;
	this.options = {
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }

	this.parent = parent;
	this.initialized = false;
	this.imgDiv = OAT.Dom.create("div");
	this.descDiv = OAT.Dom.create("div");
	this.descDiv.innerHTML = "This module displays all images found in filtered data set.";
	OAT.Dom.append([self.elm,self.descDiv,self.imgDiv]);
	
	this.drawOne = function(uri,item) {
		var img = OAT.Dom.create("img",{},"rdf_image")
		img.src = uri;
		img.title = self.parent.getTitle(item);
		self.imgDiv.appendChild(img);
		self.parent.createAnchor(img,uri);
	}
	
	this.redraw = function() {
		OAT.Dom.clear(self.imgDiv);
		var data = self.parent.data.structured;
		for (var i=0;i<data.length;i++) {
			var item = data[i];
			var preds = item.preds;
			if (self.parent.getContentType(item.uri) == 3) { self.drawOne(item.uri,item); }
			for (var p in preds) {
				var pred = preds[p];
				for (var j=0;j<pred.length;j++) {
					var value = pred[j];
					if (typeof(value) == "object") { continue; }
					if (self.parent.getContentType(value) == 3) { self.drawOne(value,item); }
				} /* for all values */
			} /* for all predicates */
		} /* for all items */
	} /* redraw */
}
OAT.RDFTabs.images.prototype = new OAT.RDFTabs.parent();

OAT.Loader.featureLoaded("rdftabs");
