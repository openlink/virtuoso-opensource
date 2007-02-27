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
	rb = new OAT.TabRDFBrowser("div",optObj);
	rb.newTab(url);
	
	.rdf_tabs .rdf_content .rdf_close
	
*/
 
/*
	rb = new OAT.RDFBrowser("div",optObj);
	rb.attachData(tripleArray);
	rb.addFilter("type","Element");
	rb.removeFilter("type","Element");
	rb.sort("name");
	rb.draw();
	
	.rdf_filter .rdf_data .rdf_categories .rdf_sort .rdf_group .rdf_clear
	
	data: [
		[name,[
			[pred1,value1],
			[pred2,value2],
			...
		],
		...
	]
	
*/

OAT.TabRDFBrowser = function(div,optObj) {
	var self = this;
	
	this.options = {
		pageSize:20,
		maxLength:30,
		maxDistinctValues:100,
		imagePath:OAT.Preferences.imagePath,
		indicator:false,
		tabParent:false
	}

	for (var p in optObj) { this.options[p] = optObj[p]; }
	
	this.browsers = [];
	this.content = OAT.Dom.create("div",false,"rdf_content");
	this.ul = OAT.Dom.create("ul",false,"rdf_tabs");
	this.tabs = [];
	this.tab = new OAT.Tab(self.content);
	
	/* prepare dom */
	var d = $(div);
	OAT.Dom.clear(d);
	OAT.Dom.append([d,self.ul,self.content]);
	/***/
	
	this.tabLabel = function(url) {
		var result = url;
		var part = url.match(/[^\/]+\/?$/);
		if (part) { result = part[0]; }
		var limit = 25;
		result = (result.length > limit ? result.substring(0,limit) + "..." : result);
		return result;
	}
	
	this.newTab = function(url) {
		var o = {};
		o.pageSize = self.options.pageSize;
		o.maxLength = self.options.maxLength;
		o.maxDistinctValues = self.options.maxDistinctValues;
		o.indicator = self.options.indicator;
		o.imagePath = self.options.imagePath;
		o.tabParent = self;
		
		var tab = OAT.Dom.create("li");
		var div = OAT.Dom.create("div");
		tab.innerHTML = self.tabLabel(url);
		self.tabs.push(tab);
		
		var close = OAT.Dom.create("img",false,"rdf_close");
		close.src = self.options.imagePath + "RectWin_close.gif";
		
		OAT.Dom.append([self.ul,tab],[tab,close]);
		self.tab.add(tab,div);
		
		var b = new OAT.RDFBrowser(div,o);
		self.browsers.push(b);
		OAT.Dereference.go(url,b.attachXmlDoc,{type:OAT.AJAX.TYPE_XML});
		
		OAT.Dom.attach(close,"click",function(){
			var index = self.browsers.find(b);
			self.browsers.splice(index,1);
			self.tab.remove(tab);
			OAT.Dom.unlink(tab);
		});
	}
}

OAT.RDFBrowser = function(div,optObj) {
	var self = this;

	this.options = {
		pageSize:20,
		maxLength:30,
		maxDistinctValues:100,
		imagePath:OAT.Preferences.imagePath,
		indicator:false,
		tabParent:false
	}
	for (var p in optObj) { this.options[p] = optObj[p]; }
	
	this.currentPage = 0;
	this.parent = $(div);
	this.sortTerm = false;
	this.groupMode = false;
	this.allData = [];
	this.data = []; /* must be array, because of sorting */
	this.filters = [];
	this.tree = false;
	this.urlHistory = [];
	this.urlIndex = -1;
	this.nav = {};
	
	this.clear = function() {
		var aa = self.categoryDiv.getElementsByTagName("a");
		for (var i=0;i<aa.length;i++) { OAT.Dom.detachAll(aa[i]); }
		if (self.tree) { self.tree.clear(); }
		OAT.Dom.clear(self.parent);
	}

	this.goHistory = function(index) {
		self.urlIndex = index;
		self.nav.url.value = self.urlHistory[self.urlIndex];
		OAT.Dereference.go(self.urlHistory[self.urlIndex],self.attachXmlDoc,{type:OAT.AJAX.TYPE_XML});
	}
	
	this.newURL = function(url) { /* new url */
		self.urlHistory.push(url);
		self.goHistory(self.urlHistory.length-1);
	}
	
	this.attachXmlDoc = function(xmlDoc) {
		if (self.options.indicator) { OAT.Dom.show(self.options.indicator); }
		var triples = OAT.RDF.toTriples(xmlDoc);
		if (!triples.length) { alert("Document contains 0 triples!"); }
		self.attachData(triples);
		self.draw();
		self.refreshURL();
	}
	
	this.refreshURL = function() { /* actualize navigation */
		self.nav.first.disabled = (self.urlIndex == -1 || self.urlIndex == 0);
		self.nav.prev.disabled = (self.urlIndex == -1 || self.urlIndex == 0);
		self.nav.next.disabled = (self.urlIndex == self.urlHistory.length-1);
		self.nav.last.disabled = (self.urlIndex == self.urlHistory.length-1);
	}
	
	this.drawSort = function() {
		OAT.Dom.clear(self.sortDiv);
		var h = OAT.Dom.create("h3");
		h.innerHTML = "Order by";
		self.sortDiv.appendChild(h);
		
		var list = [];
		/* analyze sortable predicates */
		for (var i=0;i<self.data.length;i++) {
			var preds = self.data[i][1];
			for (var j=0;j<preds.length;j++) {
				var pair = preds[j];
				var pred = pair[0];
				var index1 = list.find(pred);
				var index2 = -1;
				for (var k=0;k<self.filters.length;k++) { if (self.filters[k][0] == pred) { index2 = j; } }
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
	
	this.drawCategories = function() { /* category tree */
		if (self.tree) { self.tree.clear(); }
		OAT.Dom.clear(self.categoryDiv);
		var h = OAT.Dom.create("h3");
		h.innerHTML = "Categories";
		self.categoryDiv.appendChild(h);

		var cats = {}; /* object of distinct values contained in filtered data */
		for (var i=0;i<self.data.length;i++) {
			var preds = self.data[i][1];
			for (var j=0;j<preds.length;j++) {
				var pair = preds[j];
				var p = pair[0];
				var o = pair[1];
				if (!(p in cats)) { cats[p] = {}; }
				var obj = cats[p];
				if (!(o in obj)) { obj[o] = 0; }
				obj[o]++;
			}
		}
		
		/* 
			filter out some categories:
			* if there is only 1 element with such property
			* property count is > self.options.maxDistinctValues
			* if category contains 1 or 0 values
		*/
		for (var p in cats) {
			var count = 0;
			var atLeastOne = false;
			var obj = cats[p];
			for (var o in obj) {
				count++;
				if (obj[o] > 1) { atLeastOne = true; }
			}
			if (!atLeastOne || count <= 1 || count > self.options.maxDistinctValues) { delete cats[p]; }
		}
		
		function assign(node,p,o) {
			var ref = function() {
				self.addFilter(p,o);
			}
			OAT.Dom.attach(node,"click",ref);
		}
		
		var ul = OAT.Dom.create("ul");
		var bigTotal = 0;
		for (var p in cats) {
			var obj = cats[p];
			var li = OAT.Dom.create("li");
			var lilabel = OAT.Dom.create("span");
			li.appendChild(lilabel);
			lilabel.innerHTML = p;
			var ul2 = OAT.Dom.create("ul");
			li.appendChild(ul2);
			var count = 0;
			var total = 0;
			var anyli = OAT.Dom.create("li");
			var anya = OAT.Dom.create("a");
			anya.setAttribute("href","javascript:void(0)");
			anya.setAttribute("title","Filter by this value");
			anya.innerHTML = "[any]";
			anyli.appendChild(anya);
			ul2.appendChild(anyli);
			assign(anya,p,"");
			for (var o in obj) {
				count++;
				bigTotal++;
				var li2 = OAT.Dom.create("li");
				var a = OAT.Dom.create("a");
				a.setAttribute("href","javascript:void(0)");
				a.setAttribute("title",o);
				var label = (o.length > self.options.maxLength ? o.substring(0,self.options.maxLength) + "..." : o);
				a.innerHTML = label + " (" + obj[o] + ")";
				total += obj[o];
				li2.appendChild(a);
				ul2.appendChild(li2);
				assign(a,p,o);
			}
			lilabel.innerHTML += " ("+count+")";
			anya.innerHTML += " ("+total+")";
			ul.appendChild(li);
		}
		self.categoryDiv.appendChild(ul);
		self.tree = new OAT.Tree({imagePath:self.options.imagePath,poorMode:(bigTotal > 1000),onClick:"toggle",onDblClick:"toggle"});
		self.tree.assign(ul,true);
		
		for (var i=0;i<self.tree.tree.children.length;i++) { /* expand 'type' node */
			var li = self.tree.tree.children[i];
			if (li.getLabel().match(/type/)) { li.expand(); }
		}	
	}
	
	this.drawFilters = function() { /* list of applied filters */
		OAT.Dom.clear(self.filterDiv);
		var h = OAT.Dom.create("h3");
		h.innerHTML = "Filters";
		self.filterDiv.appendChild(h);
		
		function assign(link,index) {
			var ref = function() {
				var f = self.filters[index];
				self.removeFilter(f[0],f[1]);
			}
			OAT.Dom.attach(link,"click",ref);
		}
		
		for (var i=0;i<self.filters.length;i++) {
			var f = self.filters[i];
			var div = OAT.Dom.create("div");
			var value = (f[1] == "" ? "[any]" : f[1]);
			var strong = OAT.Dom.create("strong");
			strong.innerHTML = f[0]+": ";
			div.appendChild(strong);
			div.innerHTML += value+" ";
			var remove = OAT.Dom.create("a");
			remove.setAttribute("href","javascript:void(0)");
			remove.setAttribute("title","Remove this filter");
			remove.innerHTML = "[remove]";
			assign(remove,i);
			div.appendChild(remove);
			self.filterDiv.appendChild(div);
		}
		
		if (!self.filters.length) {
			var div = OAT.Dom.create("div");
			div.innerHTML = "No filters are selected. Create some by clicking on values in Categories you want to view.";
			self.filterDiv.appendChild(div);
		}
		
		if (self.filters.length > 1) {
			var div = OAT.Dom.create("div");
			var remove = OAT.Dom.create("a");
			remove.setAttribute("href","javascript:void(0)");
			remove.setAttribute("title","Remove all filters");
			remove.innerHTML = "remove all filters";
			OAT.Dom.attach(remove,"click",self.removeAllFilters);
			div.appendChild(remove);
			self.filterDiv.appendChild(div);
		}
	}
	
	this.drawDereference = function(anchor) {
		var ul = OAT.Dom.create("ul",{paddingLeft:"20px",marginLeft:"0px"});
		var href = anchor.href;

		var li1 = OAT.Dom.create("li");
		var a1 = OAT.Dom.create("a");
		a1.innerHTML = "RDF Drill Down";
		a1.href = "javascript:void(0)";
		OAT.Dom.attach(a1,"click",function() {
			/* dereference link */
			OAT.AnchorData.window.close();
			self.newURL(href);
		});
		
		var li2 = OAT.Dom.create("li");
		var a2 = OAT.Dom.create("a");
		a2.innerHTML = "RDF Drill Down - permalink";
		var root = window.location.toString().match(/^[^#]+/)[0];
		a2.href = root+"#"+encodeURIComponent(href);

		var li3 = OAT.Dom.create("li");
		var a3 = OAT.Dom.create("a");
		a3.innerHTML = "(X)HTML Page Open";
		a3.href = href;

		OAT.Dom.append([ul,li1,li2,li3],[li1,a1],[li2,a2],[li3,a3]);
		
		var obj = {
			title:"URL",
			activation:"click",
			content:ul,
			width:0,
			height:0,
			result_control:false
		};
		OAT.Anchor.assign(anchor,obj);
	}
	
	this.drawItem = function(item) { /* one item */
		var div = OAT.Dom.create("div",{},"rdf_item");
		var h = OAT.Dom.create("h3");
		h.innerHTML = item[0];
		div.appendChild(h);

		var preds = item[1];
		for (var i=0;i<preds.length;i++) {
			/* check if predicate is not in filters */
			var predicate = preds[i];
			var ok = true;
			
			for (var j=0;j<self.filters.length;j++) {
				var f = self.filters[j];
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
			if (data.match(/(jpe?g|png|gif)$/i)) { /* image */
				content = OAT.Dom.create("img");
				content.title = data;
				content.src = data;
			} else if (data.match(/^http/i)) { /* link */
				content = OAT.Dom.create("a");
				content.innerHTML = data;
				content.href = data;
				self.drawDereference(content);
			} else if (data.match(/^[^@]+@[^@]+$/i)) { /* mail address */
				content = OAT.Dom.create("a");
				var r = data.match(/^(mailto:)?(.*)/);
				content.innerHTML = r[2];
				content.href = 'mailto:'+r[2];
			} else { /* default - text */
				content = OAT.Dom.create("span");
				content.innerHTML = data;
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
		
		for (var i=0;i<self.data.length;i++) {
			var index = i+1;
			var item = self.data[i];
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
		var count = self.data.length;
		cnt.innerHTML = "There are "+count+" records to match selected filters.";
		OAT.Dom.append([self.pageDiv,cnt,gd,div]);
		
		
		function assign(a,page) {
			a.setAttribute("title","Jump to page "+(page+1));
			a.setAttribute("href","javascript:void(0)");
			OAT.Dom.attach(a,"click",function() {
				self.currentPage = page;
				self.draw(true);
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
				self.draw(true); /* don't re-draw categories */
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
	
	this.draw = function(ignoreCategories) { /* everything */
		/* display all filtered data */
		if (!ignoreCategories) { self.drawCategories(); }
		self.drawFilters();
		self.drawSort();
		self.drawData();
		self.drawPager();
		if (self.options.indicator) { OAT.Dom.hide(self.options.indicator); }
	}
	
	this.sort = function(predicate) {
		if (self.options.indicator) { OAT.Dom.show(self.options.indicator); }
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
		self.data.sort(sf);
		self.draw(true);
	}
	
	this.applyFilters = function(all,draw) {
		/*
			two modes of operation:
			1. all == true => take self.allData and apply all filters
			2. all != true => take self.data and apply last filter
		*/
		if (self.options.indicator) { OAT.Dom.show(self.options.indicator); }
		self.currentPage = 0;
		self.groupMode = false;
		function filterObj(arr,filter) {
			var newData = [];
			for (var i=0;i<arr.length;i++) {
				var preds = arr[i][1];
				var ok = false;
				for (var j=0;j<preds.length;j++) {
					var pair = preds[j];
					if ((pair[0] == filter[0] && pair[1] == filter[1]) || (pair[0] == filter[0] && filter[1] == "")) {
						newData.push(arr[i]); 
						break;
					}
				} /* for all pairs */
			} /* for all subjects */
			return newData;
		}
		
		if (all) {
			self.data = self.allData;
			for (var i=0;i<self.filters.length;i++) {
				var f = self.filters[i];
				self.data = filterObj(self.data,f);
			}
		} else {
			var f = self.filters[self.filters.length-1]; /* last filter */
			self.data = filterObj(self.data,f);
		}
		if (draw) { self.draw(); }
	}
	
	this.attachData = function(tripleArray) {
		if (self.options.indicator) { OAT.Dom.show(self.options.indicator); }
		self.sortTerm = false;
		self.allData = [];
		var dataObj = {}
		for (var i=0;i<tripleArray.length;i++) {
			var t = tripleArray[i];
			var s = t[0];
			var p = t[1];
			var o = t[2];
			if (!(s in dataObj)) { dataObj[s] = []; }
			dataObj[s].push([p,o]);
		}
		for (var p in dataObj) {
			self.allData.push([p,dataObj[p]]);
		}
		
		self.applyFilters(true,false);
	}
	
	this.addFilter = function(predicate, object) {
		self.sortTerm = false;
		self.filters.push([predicate,object]);
		self.applyFilters(false,true);
	}
	
	this.removeFilter = function(predicate, object) {
		self.sortTerm = false;
		var index = -1;
		for (var i=0;i<self.filters.length;i++) {
			var f = self.filters[i];
			if (f[0] == predicate && f[1] == object) { index = i; }
		}
		if (index == -1) { return; }
		self.filters.splice(index,1);
		self.applyFilters(true,true);
	}
	
	this.removeAllFilters = function() {
		self.filters = [];
		self.applyFilters(true,true);
	}
	
	this.init = function() {
		/* dom */
		OAT.Dom.clear(self.parent);
		this.urlDiv = OAT.Dom.create("div",{},"rdf_url");
		this.filterDiv = OAT.Dom.create("div",{},"rdf_filter");
		this.dataDiv = OAT.Dom.create("div",{},"rdf_data");
		this.categoryDiv = OAT.Dom.create("div",{},"rdf_categories");
		this.sortDiv = OAT.Dom.create("div",{},"rdf_sort");
		OAT.Dom.append([self.parent,self.urlDiv,self.categoryDiv,self.filterDiv,self.sortDiv,self.dataDiv]);
		
		/* url */
		self.nav.url = OAT.Dom.create("input");
		self.nav.url.size = 90;
		self.nav.url.type = "text";
		self.nav.btn = OAT.Dom.button("Load");
		self.nav.first = OAT.Dom.button("|<");
		self.nav.prev = OAT.Dom.button("<");
		self.nav.next = OAT.Dom.button(">");
		self.nav.last = OAT.Dom.button(">|");
		var d = OAT.Dom.create("div");
		OAT.Dom.append([self.urlDiv,self.nav.first,self.nav.prev,self.nav.next,self.nav.last,self.nav.url,self.nav.btn]);
		
		OAT.Dom.attach(self.nav.btn,"click",function(){self.newURL($v(self.nav.url));});
		OAT.Dom.attach(self.nav.first,"click",function(){self.goHistory(0);});
		OAT.Dom.attach(self.nav.prev,"click",function(){self.goHistory(self.urlIndex-1);});
		OAT.Dom.attach(self.nav.next,"click",function(){self.goHistory(self.urlIndex+1);});
		OAT.Dom.attach(self.nav.last,"click",function(){self.goHistory(self.urlHistory.length-1);});
		
		var r = false;
		if ((r = window.location.toString().match(/#(.+)$/))) {
			var url = decodeURIComponent(r[1]);
			self.newURL(url);
		} else {
			self.nav.url.value = "foaf.xml";
			self.refreshURL();
		}
	}
	
	this.init();
}
OAT.Loader.featureLoaded("rdfbrowser");
