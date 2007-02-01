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
	rb = new OAT.RDFBrowser("div");
	rb.attachData(tripleArray);
	rb.addFilter("type","Element");
	rb.removeFilter("type","Element");
	rb.draw();
	
	.rdf_filter .rdf_data .rdf_categories
*/

OAT.RDFBrowser = function(div,optObj) {
	var self = this;
	this.options = {
		pageSize:20,
		maxLength:30,
		maxDistinctValues:100,
		imagePath:"/DAV/JS/images"
	}
	for (var p in optObj) { this.options[p] = optObj[p]; }
	
	this.currentPage = 0;
	this.parent = $(div);
	OAT.Dom.clear(self.parent);
	this.allData = [];
	this.data = [];
	this.filters = [];
	this.filterDiv = OAT.Dom.create("div",{},"rdf_filter");
	this.dataDiv = OAT.Dom.create("div",{},"rdf_data");
	this.categoryDiv = OAT.Dom.create("div",{},"rdf_categories");
	self.parent.appendChild(self.categoryDiv);
	self.parent.appendChild(self.filterDiv);
	self.parent.appendChild(self.dataDiv);
	this.tree = false;
	
	this.clear = function() {
		var aa = self.categoryDiv.getElementsByTagName("a");
		for (var i=0;i<aa.length;i++) { OAT.Dom.detachAll(aa[i]); }
		if (self.tree) { self.tree.clear(); }
		OAT.Dom.clear(self.parent);
	}
	
	this.drawCategories = function() {
		if (self.tree) { self.tree.clear(); }
		OAT.Dom.clear(self.categoryDiv);
		var h = OAT.Dom.create("h3");
		h.innerHTML = "Categories";
		self.categoryDiv.appendChild(h);

		var cats = {};
		for (var tmp in self.data) {
			var s = self.data[tmp];
			for (var i=0;i<s.length;i++) {
				var pair = s[i];
				var p = pair[0];
				var o = pair[1];
				if (!(p in cats)) { cats[p] = {}; }
				var obj = cats[p];
				if (!(o in obj)) { obj[o] = 0; }
				obj[o]++;
			}
		}
		
		/* filter too large categories */
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
				a.setAttribute("title","Filter by this value");
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
		
		for (var i=0;i<self.tree.tree.children.length;i++) {
			var li = self.tree.tree.children[i];
			if (li.getLabel().match(/type/)) { li.expand(); }
		}
		
	}
	
	this.drawFilters = function() {
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
	
	this.drawData = function() {
		OAT.Dom.clear(self.dataDiv);
		var h = OAT.Dom.create("h3");
		h.innerHTML = "Data";
		self.dataDiv.appendChild(h);
		
		var cntdiv = OAT.Dom.create("div");
		self.dataDiv.appendChild(cntdiv);
		
		var pagediv = OAT.Dom.create("div");
		self.dataDiv.appendChild(pagediv);
		
		var count = 0;
		for (var p in self.data) {
			count++;
			if (count >= self.currentPage * self.options.pageSize && count < (self.currentPage + 1) * self.options.pageSize) {
				var div = OAT.Dom.create("div",{},"rdf_item");
				var h = OAT.Dom.create("h3");
				h.innerHTML = p;
				div.appendChild(h);
				var s = self.data[p];
				for (var i=0;i<s.length;i++) {
					/* check if predicate is not in filters */
					var ok = true;
					for (var j=0;j<self.filters.length;j++) {
						var f = self.filters[j];
						if (s[i][0] == f[0] && f[1] != "") { ok = false; }
					}
					if (ok) {
						var d = OAT.Dom.create("div");
						var strong = OAT.Dom.create("strong");
						strong.innerHTML = s[i][0]+": ";
						d.appendChild(strong);
						d.innerHTML += s[i][1];
						div.appendChild(d);
					} /* if not in filters */
				} /* for all predicates */
				self.dataDiv.appendChild(div);
			} /* if in current page */
		} /* for all filtered subjects */
		
		cntdiv.innerHTML = "There are "+count+" records to match selected filters.";
		
		function assign(a,page) {
			a.setAttribute("title","Jump to page "+(page+1));
			a.setAttribute("href","javascript:void(0)");
			OAT.Dom.attach(a,"click",function() {
				self.currentPage = page;
				self.drawData();
			});
		}
		
		if (count > self.options.pageSize) { /* create pager */
			pagediv.innerHTML = "Page: ";
			var pagecount = Math.ceil(count/self.options.pageSize);
			for (var i=0;i<pagecount;i++) {
				var a = OAT.Dom.create("a");
				if (i != self.currentPage) { assign(a,i); }
				pagediv.appendChild(OAT.Dom.text(" "));
				pagediv.appendChild(a);
				a.innerHTML = i+1;
				pagediv.appendChild(OAT.Dom.text(" "));
			}
		}
	}
	
	this.draw = function() {
		/* display all filtered data */
		self.drawCategories();
		self.drawFilters();
		self.drawData();
	}
	
	this.applyFilters = function(all,draw) {
		/*
			two modes of operation:
			1. all == true => take self.allData and apply all filters
			2. all != true => take self.data and apply last filter
		*/
		function filterObj(obj,filter) {
			var newData = {};
			for (var p in obj) {
				var s = obj[p];
				var ok = false;
				for (var i=0;i<s.length;i++) {
					var pair = s[i];
					if ((pair[0] == filter[0] && pair[1] == filter[1]) || (pair[0] == filter[0] && filter[1] == "")) {
						newData[p] = s; 
						i = s.length;
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
		self.allData = {};
		for (var i=0;i<tripleArray.length;i++) {
			var t = tripleArray[i];
			var s = t[0];
			var p = t[1];
			var o = t[2];
			if (!(s in self.allData)) { self.allData[s] = []; }
			self.allData[s].push([p,o]);
		}
		self.applyFilters(true,false);
	}
	
	this.addFilter = function(predicate, object) {
		self.filters.push([predicate,object]);
		self.applyFilters(false,true);
	}
	
	this.removeFilter = function(predicate, object) {
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
}
OAT.Loader.featureLoaded("rdfbrowser");
