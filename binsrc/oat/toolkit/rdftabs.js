/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2008 OpenLink Software
 *
 *  See LICENSE file for details.
 */

/*
	API FOR RDF TABS
	----------------
	
	1) MUST implement
	-----------------
		[constructor](parent, optionsObject) - parent is a reference to owner object (rdfbrowser, rdfmini)
		.elm - DOM node
		.description - textual
		.redraw() - redraw contents
		.reset(hard) - called by parent when triple store changes. when the change is initiated by applying filters, hard == false.
						when the change is initiated by adding/removing URL, hard == true

	2) CAN use
	----------
		parent.data = {
			triples:[] - array of triples
			all:{} - object
			structured:{} - object with applied filters
		}
		parent.store - instance of OAT.RDFStore
		parent.getContentType(string) - return 1=link, 2=mail, 3=image, 0=others
		parent.getTitle(dataItem) - returns title string for data item
		parent.getURI(dataItem) - returns URI for data item
		parent.processLink(domNode, href, disabledActions) - attach external handlers to a link

	
	.rdf_sort .rdf_group .rdf_clear .rdf_data .rtf_tl_port .rdf_tl_slider .rdf_tagcloud .rdf_tagcloud_title
*/
if (!OAT.RDFTabs) { OAT.RDFTabs = {}; }

OAT.RDFTabs.parent = function(obj) {
	/* methods & properties that need to be implemented by each RDFTab */
	obj.redraw = function() {} /* redraw contents */
	obj.reset = function(hard) {} /* triples were changed - reset */
	obj.elm = OAT.Dom.create("div");
	obj.description = "";
}

OAT.RDFTabs.browser = function(parent,optObj) {
	var self = this;
	OAT.RDFTabs.parent(self);
		
	this.options = {
		pageSize:20,
		removeNS:true
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }
	
	this.initialized = false;
	this.dataDiv = OAT.Dom.create("div",{},"rdf_data");
	this.sortDiv = OAT.Dom.create("div",{},"rdf_sort");
	this.description = "This module is used for viewing all filtered data, structured into resource items.";
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
			self.parent.processLink(s,uri);
			s.style.cursor = "pointer";
		}

		var preds = item.preds;
		for (var p in preds) {
			/* check if predicate is not in filters */
			var pred = preds[p];
			var ok = true;
			
			for (var i=0;i<self.parent.store.filtersProperty.length;i++) {
				var f = self.parent.store.filtersProperty[i];
				if (p == f[0] && f[1] != "") { ok = false; }
			}
			if (!ok) { continue; } /* don't draw this property */
			
			var d = OAT.Dom.create("div");
			var strong = OAT.Dom.create("strong");
			strong.innerHTML = (self.options.removeNS ? self.parent.simplify(p) : p)+": ";
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
		if (count == 0) { 
			cnt.innerHTML += "Perhaps your criteria are too restrictive? Please review your filters.";
		}
		OAT.Dom.append([self.pageDiv,cnt,gd,div]);
		
		function assign(a,page) {
			a.setAttribute("title","Jump to page "+(page+1));
			a.setAttribute("href","#");
			OAT.Dom.attach(a,"click",function(event) {
				OAT.Dom.prevent(event);
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
				for (var j=0;j<self.parent.store.filtersProperty.length;j++) { if (self.parent.store.filtersProperty[j][0] == p) { index2 = p; } }
				if (index1 == -1 && index2 == -1) { list.push(p); }
			} /* for all predicates */
		} /* for all data */
		
		var attach = function(elm,val) {
			OAT.Dom.attach(elm,"click",function(event) {
				OAT.Dom.prevent(event);
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
				elm.href = value;
				attach(elm,value);
			}
			elm.innerHTML = self.parent.simplify(value);
			if (i) { self.sortDiv.appendChild(OAT.Dom.text(", ")); }
			self.sortDiv.appendChild(elm);
		}
	}
	
	this.redraw = function() {
		if (!self.initialized) {
			self.initialized = true;
			OAT.Dom.append([self.elm,self.sortDiv,self.dataDiv]);
		} 
		self.drawSort();
		self.drawData();
		self.drawPager();
	}
}

OAT.RDFTabs.navigator = function(parent,optObj) {
	var self = this;
	OAT.RDFTabs.parent(self);
	
	this.plurals = {
		"Person":"People",
		"Class":"Classes",
		"Entry":"Entries"
	}
		
	this.options = {
		limit:5
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }
	
	this.initialized = false;
	this.parent = parent;
	this.history = [];
	this.historyIndex = -1;
	this.nav = {};
	this.waiting = false;
	this.mlCache = [];
	this.topDiv = OAT.Dom.create("div",{},"rdf_nav");
	this.mainDiv = OAT.Dom.create("div");
	this.description = "This module is used to navigate through locally cached data, one resource at a time. Note that filters are not applied here";
	OAT.Dom.append([self.elm,self.topDiv,self.mainDiv]);

	this.gd = new OAT.GhostDrag();
	this.dropReference = function(source) {
		return function(target,x,y) { /* reposition two row blocks */
			if (source == target) { return; }
			var stop = target;
			if (source._rows[source._rows.length-1].nextSibling == target) { stop = target._rows[target._rows.length-1].nextSibling; }
			target.parentNode.insertBefore(source,stop);
			for (var i=0;i<source._rows.length;i++) {
				var row = source._rows[i];
				target.parentNode.insertBefore(row,stop);
			}
		}
	}
	this.gdProcess = function(elm) {
		var t = OAT.Dom.create("table",{},"rdf_nav_spotlight");
		var tb = OAT.Dom.create("tbody");
		OAT.Dom.append([t,tb],[tb,elm.firstChild]);
		elm.appendChild(t);
	}
	
	this.reset = function(hard) {
		if (!hard) { return; } /* we ignore filters */
		if (!self.waiting) {
			self.historyIndex = -1;
			self.history = [];
			self.mlCache = [];
		}
	}

	this.attach = function(elm,item) { /* attach navigation to link */
		OAT.Dom.addClass(elm,"rdf_link");
		OAT.Dom.attach(elm,"click",function(event) {
			/* disable default onclick event for anchor */
			OAT.Dom.prevent(event);
			self.history.splice(self.historyIndex+1,self.history.length-self.history.index+1); /* clear forward history */
			self.history.push(item);
			self.navigate(self.history.length-1);
		});
	}
	
	this.dattach = function(elm,uri) { /* attach dereference to link */
		OAT.Event.attach(elm,"click",function(event) {
			/* disable default onclick event for anchor */
			OAT.Dom.prevent(event);
			self.waiting = true;
			var img = OAT.Dom.create("img");
			img.src = self.parent.options.imagePath + "Dav_throbber.gif";
			var start = function(xhr) {
				elm.parentNode.insertBefore(img,elm);
				OAT.Event.attach(img,"click",xhr.abort);
			}
			var end = function() {
				OAT.Dom.unlink(img);
			}
			self.parent.store.addURL(uri,start,end);
		});
	}
	
	this.getTypeObject = function() { /* object of resource types */
		var obj = {};
		var data = self.parent.data.all;
		for (var i=0;i<data.length;i++) {
			var item = data[i];
			var t = item.type || " ";
			var a = (t in obj ? obj[t] : []);
			a.push(item);
			obj[t] = a;
		}
		return obj;
	}

	this.drawPredicate = function(value) { /* draw one pred's content; return ELM */
		var content = false;
		if (typeof(value) == "object") { /* resource */
			var items = self.parent.store.items;
			var dereferenced = false;
			for(var j=0;j<items.length;j++) {
				var item = items[j];
				/* handle anchors to local file */
				var baseuri = value.uri.match(/^[^#]+/);
				baseuri = baseuri? baseuri[0] : "";
				var basehref = item.href.match(/^[^#]+/);
				basehref = basehref? basehref[0] : "";
				if(basehref == baseuri) { dereferenced = true; };
			}

			content = OAT.Dom.create("a");
			content.href = "?uri=" + encodeURIComponent(value.uri);
			content.innerHTML = self.parent.getTitle(value);

			/* dereferenced, or relative uri/blank node */
			if(dereferenced || !value.uri.match(/^http/i)) {
				self.attach(content,value);
			} else {
				self.dattach(content,value.uri);
			}
		} else { /* literal */
			var type = self.parent.getContentType(value);
			if (type == 3) { /* image */
				content = OAT.Dom.create("img");
				content.src = value;
				var ref = function() {
					var w = content.width;
					var h = content.height;
					var max = Math.max(w,h);
					if (max > 600) {
						var coef = 600 / max;
						var nw = Math.round(w*coef);
						var nh = Math.round(h*coef);
						content.width = nw;
						content.height = nh;
					}
				}
				OAT.Event.attach(content,"load",ref);
			} else if (type == 1) { /* dereferencable link */
				content = OAT.Dom.create("a");
				content.href = value;
				content.innerHTML = self.parent.store.simplify(value);
				self.dattach(content,value);
			} else { /* text */
				content = OAT.Dom.create("span");
				content.innerHTML = value;
				var anchors_ = content.getElementsByTagName("a");
				var anchors = [];
				for (var j=0;j<anchors_.length;j++) { anchors.push(anchors_[j]); }
				for (var j=0;j<anchors.length;j++) {
					var anchor = anchors[j];
					var done = false;
					for (var k=0;k<self.parent.data.all.length;k++) {
						var item = self.parent.data.all[k];
						if (anchor.href == item.uri) {
							self.attach(anchor,item);
							done = true;
							k = self.parent.data.all.length;
						} 
					} /* for all resources */
					if (!done) { self.dattach(anchor,anchor.href); }
				} /* for all nested anchors */
			}
		} /* if literal */
		return content;
	}
	
	this.drawItem = function(item) { /* one item */
		var obj = {};
		for (var p in item.preds) {
			var simple = self.parent.simplify(p);
			if (!(simple in obj)) { obj[simple] = []; }
			var a = obj[simple];
			for (var i=0;i<item.preds[p].length;i++) {
				var value = item.preds[p][i];
				if (a.find(value) == -1) { a.push(value);}
			}
		}
		obj["What Links Here"] = item.back;
		self.drawSpotlight(self.parent.getTitle(item),obj);
	}

	this.navigate = function(index) { /* navigate to history index */
		var item = self.history[index];
		self.drawItem(item);
		self.historyIndex = index;
		self.redrawTop();
	}
	
	this.redrawTop = function() { /* navigation controls */
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
	
	this.drawSpotlightHeading = function(tr,label,arr,cnt) {
		tr._rows = arr;
		self.gd.addTarget(tr);
		self.gd.addSource(tr,self.gdProcess,self.dropReference(tr,arr));
		var states = ["&#x25bc;","&#x25b6;"];
		var state = 0;
		var arrow = OAT.Dom.create("span",{cursor:"pointer"});
		arrow.innerHTML = states[state];
		var td = OAT.Dom.create("td");
		td.appendChild(arrow);
		tr.appendChild(td);
		var td = OAT.Dom.create("td");
		td.colSpan = 3;
		var simple = self.parent.simplify(label);
		if (cnt > 1 && simple.charAt(0) != "[" && simple in self.plurals) {
			simple = self.plurals[simple];
		}
		td.innerHTML = simple;
		tr.appendChild(td);
		OAT.Event.attach(arrow,"click",function() {
			state = (state+1) % 2;
			arrow.innerHTML = states[state];
			for (var i=0;i<arr.length;i++) {
				if (state) { OAT.Dom.hide(arr[i]); } else { OAT.Dom.show(arr[i]); }
			}
		});
	}
	
	this.drawSpotlightType = function(label,data,table) {
		var state = (self.mlCache.find(label) == -1 ? 0 : 1);
		var states = [" more...","less..."];
		var min = Math.min(data.length,self.options.limit);
		var count = (state ? data.length : min);
		var tr = OAT.Dom.create("tr",{},"rdf_nav_header");
		var trset = [];
		self.drawSpotlightHeading(tr,label,trset,data.length);
		table.appendChild(tr);
		var createRow = function(item) {
			var tr = OAT.Dom.create("tr");
			tr.appendChild(OAT.Dom.create("td"));
			var td = OAT.Dom.create("td");
			td.appendChild(self.drawPredicate(item));
			tr.appendChild(td);
			if (typeof(item) == "object") {
				var predc = 0;
				var propc = 0;
				for (var p in item.preds) {
					predc++;
					propc += item.preds[p].length;
				}
				var td1 = OAT.Dom.create("td",{},"rdf_nav_desc");
				td1.innerHTML = predc+" predicates"
				var td2 = OAT.Dom.create("td",{},"rdf_nav_desc");
				td2.innerHTML = propc+" property values"
				OAT.Dom.append([tr,td1,td2]);
			} else {
				td.colSpan = 3;
			}
			return tr;
		}
		
		for (var i=0;i<count;i++) {
			var item = data[i];
			var tr = createRow(item);
			trset.push(tr);
			table.appendChild(tr);
		}
		
		if (self.options.limit < data.length) {
			var toggletr = OAT.Dom.create("tr",{},"rdf_nav_toggle");
			toggletr.appendChild(OAT.Dom.create("td"));
			trset.push(toggletr);
			var td = OAT.Dom.create("td");
			var toggle = OAT.Dom.create("span",{cursor:"pointer"});
			toggle.innerHTML = (state ? states[state] : (data.length - min) + states[state]);
			OAT.Dom.append([td,toggle],[toggletr,td],[table,toggletr]);
			OAT.Event.attach(toggle,"click",function() {
				state = (state+1) % 2;
				toggle.innerHTML = (state ? states[state] : (data.length - min) + states[state]);
				if (state) { /* show more */
					self.mlCache.push(label);
					for (var i=min;i<data.length;i++) {
						var item = data[i];
						var tr = createRow(item);
						trset.splice(i,0,tr);
						table.insertBefore(tr,toggletr);
					}
				} else { /* show less */
					var index = self.mlCache.find(label);
					self.mlCache.splice(label,index);
					for (var i=data.length-1;i>=min;i--) {
						OAT.Dom.unlink(trset[i]);
						trset.splice(i,1);
					}
				}
			}); /* click callback */
		}
	}

	this.drawSpotlight = function(title,obj) { /* list of resources */
		OAT.Dom.clear(self.mainDiv);
		var h3 = OAT.Dom.create("h3",{clear:"both"});
		h3.innerHTML = title;
		var table = OAT.Dom.create("table",{},"rdf_nav_spotlight");
		var tbody = OAT.Dom.create("tbody");
		OAT.Dom.append([self.mainDiv,h3,table],[table,tbody]);
		var remain = false;
		for (var p in obj) {
			if (p == " ") { 
				remain = obj[p]; 
			} else {
				self.drawSpotlightType(p,obj[p],tbody);
			}
		}
		if (remain) { self.drawSpotlightType("[no type specified]",remain,tbody); }
	}
	
	this.redraw = function() {
		if (self.waiting) { self.waiting = false; }
		if (self.historyIndex != -1) { 
			self.navigate(self.historyIndex);
			return;
		}
		/* give a list of items for navigation */
		var obj = self.getTypeObject();
		self.drawSpotlight("Click on a Data Entity to explore its Linked Data Web.",obj);
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
		OAT.Dom.append([self.topDiv,self.nav.help,self.nav.first,self.nav.prev,self.nav.next,self.nav.last]);
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

OAT.RDFTabs.triples = function(parent,optObj) {
	var self = this;
	OAT.RDFTabs.parent(self);
	this.options = {
		pageSize:100,
		removeNS:true
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }

	this.parent = parent;
	this.initialized = false;
	this.grid = false;
	this.currentPage = 0;
	this.pageDiv = OAT.Dom.create("div");
	this.gridDiv = OAT.Dom.create("div");
	this.description = "This module displays all filtered triples.";
	
	this.select = OAT.Dom.create("select");
	OAT.Dom.option("Human readable","0",this.select);
	OAT.Dom.option("Machine readable","1",this.select);
	
	OAT.Dom.append([self.elm,self.pageDiv,self.gridDiv]);
	
	this.patchAnchor = function(column) {
		var a = OAT.Dom.create("a");
		var v = self.grid.rows[self.grid.rows.length-1].cells[column].value;
		var uri = decodeURIComponent(v.innerHTML);
		a.innerHTML = (self.select.value == "0" ? self.parent.store.simplify(uri) : uri);
		a.href = v.innerHTML;
		OAT.Dom.clear(v);
		v.appendChild(a);		
		self.parent.processLink(a,uri);
	}

	this.patchEmbedded = function(column) {
		var v = self.grid.rows[self.grid.rows.length-1].cells[column].value;
		var all = v.getElementsByTagName("a");
		var uris = [];
		for (var i=0;i<all.length;i++) { uris.push(all[i]); }
		for (var i=0;i<uris.length;i++) {
			var uri = uris[i];
			self.parent.processLink(uri,uri.href);
		}
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
		OAT.Dom.append([self.pageDiv,cnt,div,self.select]);
		
		function assign(a,page) {
			a.setAttribute("title","Jump to page "+(page+1));
			a.setAttribute("href","#");
			OAT.Dom.attach(a,"click",function(event) {
				OAT.Dom.prevent(event);
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
			self.grid = new OAT.Grid(self.gridDiv,{autoNumber:true,allowHiding:true});
		}
		self.grid.options.rowOffset = self.options.pageSize * self.currentPage;
		self.grid.createHeader(["Subject","Predicate","Object"]);
		self.grid.clearData();
		
		var total = 0;
		var triples = self.parent.data.triples;
		for (var i=0;i<triples.length;i++) {
			if (i >= self.currentPage * self.options.pageSize && i < (self.currentPage + 1) * self.options.pageSize) {
				var triple = triples[i];
				self.grid.createRow(triple);
				for (var j=0;j<triple.length;j++) {
					var str = triple[j];
					/* if j = 0, we are subject, so simplify & attach a++ */
					if (j == 0 || str.match(/^(http|urn|doi)/i)) { self.patchAnchor(j+1); }
					/* if j = 2, we are object, find embedded hrefs and process */
					if (j == 2 && str.match(/href/)) { self.patchEmbedded(j+1); }
				}
			} /* if in current page */
		} /* for all triples */
		self.drawPager();
	}
	OAT.Event.attach(self.select,"change",self.redraw);
}

OAT.RDFTabs.svg = function(parent,optObj) {
	var self = this;
	OAT.RDFTabs.parent(self);
	this.options = {
		limit:100
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }

	this.parent = parent;
	this.description = "This module displays filtered data as SVG Graph. For performance reasons, the number of used triples is limited to "+self.options.limit+".";
	this.elm.style.position = "relative";
	this.elm.style.height = "600px";
	this.elm.style.top = "24px";
	
	this.redraw = function() {
		/* create better triples */
		var triples = [];
		var cnt = self.parent.data.triples.length;
		if (cnt > self.options.limit) { 
			var note = new OAT.Notify();
			var msg = "There are more than "
						+ self.options.limit
						+ " triples. Such amount would greatly slow down your computer, " 
						+ "so I displayed only first "
						+ self.options.limit
						+ "."
			note.send(msg,{delayIn:10,width:350,height:50,timeout:3000});
			cnt = self.options.limit;
		}
		
		for (var i=0;i<cnt;i++) {
			var t = self.parent.data.triples[i];
			var triple = [t[0],t[1],t[2],(t[2].match(/^http/i) ? 1 : 0)];
			triples.push(triple);
		}
		var x = OAT.GraphSVGData.fromTriples(triples);
		self.graphsvg = new OAT.GraphSVG(self.elm,x[0],x[1],{vertexSize:[4,8],sidebar:false});
		
		for (var i=0;i<self.graphsvg.data.length;i++) {
			var node = self.graphsvg.data[i];
			if (node.name.match(/^http/i)) {
				self.parent.processLink(node.svg,node.name);
			}
		}
		this.elm.style.backgroundColor = '#cacce7';
	}
}

OAT.RDFTabs.map = function(parent,optObj) {
	var self = this;
	OAT.RDFTabs.parent(self);
	
	this.options = {
		provider:OAT.MapData.TYPE_G,
		fix:OAT.MapData.FIX_ROUND1
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }
	
	this.map = false;
	this.parent = parent;
	this.description = "This module plots all geodata found in filtered resources onto a map.";
	this.elm.style.position = "relative";
	this.elm.style.height = "600px";
	
	this.keyProperties = ["based_near","geo"]; /* containing coordinates */
	this.locProperties = ["location"]; /* containing location */
	this.latProperties = ["lat","latitude"];
	this.lonProperties = ["lon","long","longitude"];
	this.lookupProperties = ["name","location"]; /* interesting to be put into lookup pin */
	
	this.usedBlanknodes = [];

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
		var coords = [0,0];
		for (var p in preds) {
			var pred = preds[p];
			var simple = self.parent.simplify(p);
			if (self.keyProperties.find(simple) != -1) { pointResource = pred[0]; } /* this is resource containing geo coordinates */
			if (self.locProperties.find(simple) != -1) { locValue = pred[0]; } /* this is resource containing geo coordinates */
		}
		if (!pointResource && !locValue) { return; }
		
		if (!pointResource) { /* geocode location */
			self.geoCode(locValue,item);
			return;
		}
		if (typeof(pointResource) != "object") { return; } /* not a reference */
		self.usedBlanknodes.push(pointResource);
		/* normal marker add */
		var it = pointResource;
		var preds = it.preds;
		for (var p in preds) {
			var pred = preds[p];
			var simple = self.parent.simplify(p);
			if (self.latProperties.find(simple) != -1) { coords[0] = pred[0]; }
			if (self.lonProperties.find(simple) != -1) { coords[1] = pred[0]; }
		} /* for all geo properties */
		if (coords[0] == 0 || coords[1] == 0) { return; }
		self.pointList.push(coords);
		self.attachMarker(coords,item);
	} /* tryItem */
	
	this.trySimple = function(item) {
		if (self.usedBlanknodes.find(item) != -1) { return; }
		var preds = item.preds;
		var coords = [0,0];
		for (var p in preds) {
			var pred = preds[p];
			var simple = self.parent.simplify(p);
			if (self.latProperties.find(simple) != -1) { coords[0] = pred[0]; } /* latitude */
			if (self.lonProperties.find(simple) != -1) { coords[1] = pred[0]; } /* longitude */
		}
		if (!coords[0] && !coords[1]) { return; }
		self.pointList.push(coords);
		self.attachMarker(coords,item);
	} /* trySimple */

	this.attachMarker = function(coords,item) {
		var m = false;
		var callback = function() { /* draw item contents */
			if (OAT.AnchorData && OAT.AnchorData.window) { OAT.AnchorData.window.close(); }
			var div = OAT.Dom.create("div",{overflow:"auto",width:"450px",height:"250px"});
			var s = OAT.Dom.create("div",{fontWeight:"bold"});
			var title = self.parent.getTitle(item);
			s.innerHTML = title;
			if (title.match(/^http/i)) { 
				self.parent.processLink(s,title); 
				s.style.cursor = "pointer";
			}
			div.appendChild(s);
			var preds = item.preds;
			for (var p in preds) {
				var pred = preds[p];
				var simple = self.parent.simplify(p);
				if (pred.length == 1 || self.lookupProperties.find(simple) != -1) {
					var s = OAT.Dom.create("div");
					s.innerHTML = simple+": ";
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
		m = self.map.addMarker(1,coords[0],coords[1],file,18,41,callback,callback);	
	}
	
	this.redraw = function() {
		self.usedBlanknodes = [];
		var markerPath = OAT.Preferences.imagePath+"markers/";
		self.markerFiles = []; 
		for (var i=1;i<=12;i++) {
			var name = markerPath + (i<10?"0":"") + i +".png";
			self.markerFiles.push(name);
		}
		self.markerIndex = 0;
		self.markerMapping = {};

		self.map = new OAT.Map(self.elm,self.options.provider,{fix:self.options.fix});
		self.map.centerAndZoom(0,0,0);
		self.map.addTypeControl();
		self.map.addMapControl();
		self.map.addTrafficControl();
		self.pointList = [];
		self.pointListLock = 0;
		for (var i=0;i<self.parent.data.structured.length;i++) {
			var item = self.parent.data.structured[i];
			self.tryItem(item);
		}
		for (var i=0;i<self.parent.data.structured.length;i++) {
			var item = self.parent.data.structured[i];
			self.trySimple(item);
		}
		
		OAT.Resize.createDefault(self.elm);

		function tryList() {
			if (!self.pointListLock) { 
				if (!self.pointList.length) { 
					var note = new OAT.Notify();
					var msg = "Current data set contains nothing that could be displayed on the map.";
					note.send(msg);
				}
				self.map.optimalPosition(self.pointList); 
 			} else {
				setTimeout(tryList,500);
			}
		}
		tryList();
	}
}

OAT.RDFTabs.timeline = function(parent,optObj) {
	var self = this;
	OAT.RDFTabs.parent(self);
	
	this.options = {
		imagePath:OAT.Preferences.imagePath
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }

	this.initialized = false;
	this.parent = parent;
	this.description = "This module displays all date/time containing resources on an interactive time line.";
	this.elm.style.position = "relative";
	this.elm.style.margin = "1em";
	this.elm.style.top = "20px";
	
	this.bothProperties = ["date","created"]; /* containing coordinates */
	this.startProperties = ["dtstart"]; /* containing location */
	this.endProperties = ["dtend"];
	this.subProperties = ["dateTime"];
	
	this.tryDeepItem = function(value) {
		if (typeof(value) != "object") { return value; }
		for (var p in value.preds) {
			var pred = value.preds[p];
			var simple = self.parent.simplify(p);
			if (self.subProperties.find(simple) != -1) { return pred[0]; }
		}
		return false;
	}
	
	this.tryItem = function(item) {
		var preds = item.preds;
		var start = false;
		var end = false;
		for (var p in preds) {
			var pred = preds[p];
			var simple = self.parent.simplify(p);
			if (self.bothProperties.find(simple) != -1) {
				var value = pred[0];
				start = self.tryDeepItem(value);
				end = self.tryDeepItem(value);
			}
			if (self.startProperties.find(simple) != -1) {
				var value = pred[0];
				start = self.tryDeepItem(value);
			}
			if (self.endProperties.find(simple) != -1) {
				var value = pred[0];
				end = self.tryDeepItem(value);
			}
		}
		if (!start) { return false; }
		if (!end) { end = start; }
		return [start,end];
	}
	
	this.redraw = function() {
		if (!self.initialized) {
			self.tl = new OAT.Timeline(self.elm,self.options);
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
				self.parent.processLink(t,uri);
			} else {
				var t = OAT.Dom.create("span");
			}
			t.innerHTML = self.parent.getTitle(item);
			OAT.Dom.append([content,ball,t]);
			self.tl.addEvent(ouri,start,end,content,"#ddd");
		}

		self.tl.draw();
		self.tl.slider.slideTo(0,1);

		if (!uris.length) { 
			var note = new OAT.Notify();
			var msg = "Current data set contains nothing that could be displayed on the timeline.";
			note.send(msg);
		}
	}
}

OAT.RDFTabs.images = function(parent,optObj) {
	var self = this;
	OAT.RDFTabs.parent(self);

	this.options = {
		columns:4,
		thumbSize:150,
		size:600
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }

	this.elm.style.textAlign = "center";
	this.parent = parent;
	this.initialized = false;
	this.cache = {};
	this.images = [];
	this.container = false;
	this.description = "This module displays all images found in filtered data set.";
	this.dimmer = false;

	this.showBig = function(index) {
		if (!self.dimmer) {
			self.dimmer = OAT.Dom.create("div",{position:"absolute",padding:"1em",backgroundColor:"#fff",border:"4px solid #000",textAlign:"center",fontSize:"160%"});
			OAT.Dimmer.show(self.dimmer);
			self.container = OAT.Dom.create("div",{margin:"auto"});
			self.prev = OAT.Dom.create("span",{fontWeight:"bold",cursor:"pointer"});
			self.next = OAT.Dom.create("span",{fontWeight:"bold",cursor:"pointer"});
			var middle = OAT.Dom.create("span");
			middle.innerHTML = "&nbsp;&nbsp;&nbsp;";
			self.prev.innerHTML = "&lt;&lt;&lt; ";
			self.next.innerHTML = " &gt;&gt;&gt;";
			self.close = OAT.Dom.create("div",{position:"absolute",top:"0px",right:"0px",backgroundColor:"#fff",padding:"3px",cursor:"pointer",fontWeight:"bold"});
			self.close.innerHTML = "X";
			OAT.Dom.append([self.dimmer,self.close,self.container,self.prev,middle,self.next]);
			
			var closeRef = function() {
				OAT.Dimmer.hide();
				self.dimmer = false;
			}
			OAT.Dom.attach(self.close,"click",closeRef);
			OAT.Dom.attach(self.prev,"click",function(){ self.showBig(self.index-1); });
			OAT.Dom.attach(self.next,"click",function(){ self.showBig(self.index+1); });
		}
		self.index = index;
		var img = OAT.Dom.create("img",{border:"2px solid #000"});
		OAT.Dom.clear(self.container);
		OAT.Dom.attach(img,"load",function() {
			var port = OAT.Dom.getViewport();
			var dim = Math.max(img.width,img.height);
			var limit = Math.min(self.options.size,port[0]-20,port[1]-20);
			if (dim > limit) { 
				var coef = limit/dim;
				var neww = img.width * coef;
				var newh = img.height * coef;
				img.width = neww;
				img.height = newh;
			}
			
			var plus = OAT.Dom.create("strong",{cursor:"pointer",marginRight:"3px"});
			var minus = OAT.Dom.create("strong",{cursor:"pointer"});
			plus.innerHTML = "+";
			minus.innerHTML = "&mdash;";
			var d = OAT.Dom.create("div",{textAlign:"left"});
			OAT.Dom.append([self.container,d],[d,plus,minus]);
			
			var resizeRef = function(coef) {
				var w = img.width;
				var h = img.height;
				w = Math.round(w*coef);
				h = Math.round(h*coef);
				img.width = w;
				img.height = h;
				OAT.Dom.center(self.dimmer,1,1);
			}
			
			OAT.Event.attach(plus,"click",function(){
				resizeRef(1.5);
			});

			
			OAT.Event.attach(minus,"click",function(){
				resizeRef(0.667);
			});

			self.container.appendChild(img);
			OAT.Dom.center(self.dimmer,1,1);
		});
		img.src = self.images[index][0];
		self.fixNav();
	}
	
	this.fixNav = function() { /* visibility of navigation */
		self.prev.style.display = (self.index ? "inline" : "none");
		self.next.style.display = (self.index+1 < self.images.length ? "inline" : "none");
	}
	
	this.drawThumb = function(index,td) {
		var size = self.options.thumbSize;
		var uri = self.images[index][0];
		var item = self.images[index][1];
		var img = OAT.Dom.create("img",{},"rdf_image")
		td.appendChild(img);
		OAT.Dom.attach(img,"load",function() {
			var max = Math.max(img.width,img.height);
			if (max <= size) { return; }
			var coef = size / max;
			var neww = img.width * coef;
			var newh = img.height * coef;
			img.width = neww;
			img.height = newh;
		});
		img.src = uri;
		img.title = self.parent.getTitle(item);
		OAT.Dom.attach(img,"click",function() { self.showBig(index); });
	}
	
	this.addUriItem = function(uri,item) {
		if (uri in self.cache) { return; }
		self.cache[uri] = true;
		self.images.push([uri,item]);
	}
	
	this.getImages = function() {
		self.images = [];
		var data = self.parent.data.structured;
		for (var i=0;i<data.length;i++) {
			var item = data[i];
			var preds = item.preds;
			if (self.parent.getContentType(item.uri) == 3) { self.addUriItem(item.uri,item); }
			for (var p in preds) {
				var pred = preds[p];
				for (var j=0;j<pred.length;j++) {
					var value = pred[j];
					if (typeof(value) == "object") { continue; }
					if (self.parent.getContentType(value) == 3) { 
						self.addUriItem(value,item);
					} else {
						var all = value.match(/http:[^ ]+\.(jpe?g|png|gif)/gi);
						if (all) for (var k=0;k<all.length;k++) { self.addUriItem(all[k],item); } /* for all embedded images */
					} /* if not image */
				} /* for all values */
			} /* for all predicates */
		} /* for all items */
	}
	
	this.redraw = function() {
		var cnt = self.options.columns;
		self.cache = {};
		OAT.Dom.clear(self.elm);
		self.getImages();
		var imgs = self.images;
		var table = OAT.Dom.create("table",{margin:"auto"});
		var tbody = OAT.Dom.create("tbody");
		var tr = OAT.Dom.create("tr");
		OAT.Dom.append([self.elm,table],[table,tbody],[tbody,tr]);
		for (var i=0;i<imgs.length;i++) {
			var td = OAT.Dom.create("td",{textAlign:"center"});
			tr.appendChild(td);
			if (i % cnt == cnt-1) {
				tr = OAT.Dom.create("tr");
				tbody.appendChild(tr);
			}
			self.drawThumb(i,td);
		}
	} /* redraw */
}

OAT.RDFTabs.tagcloud = function(parent,optObj) {
	var self = this;
	OAT.RDFTabs.parent(self);

	this.options = {
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }
	
	this.parent = parent;
	this.initialized = false;
	this.description = "This module displays all links found in filtered data set.";
	this.clouds = [];

	this.addTag = function(item,cloud) {
		var preds = item.preds;
		var title = self.parent.getTitle(item);
		var freq = 1;

		for (var p in preds) {
			var simple = self.parent.simplify(p);
			if (simple == "ownAFrequency") {
				freq = preds[p][0];
				break;
			}
		}
		
		cloud.addItem(title,item.uri,freq);
	}

	this.addCloud = function(item) {
		var preds = item.preds;
		var title = self.parent.getTitle(item);

		var div = OAT.Dom.create("div");
		var cdiv = OAT.Dom.create("div",{},"rdf_tagcloud");
		var tdiv = OAT.Dom.create("div",{},"rdf_tagcloud_title");

		var a = OAT.Dom.create("a");
		a.href = item.uri;
		a.innerHTML = title;

		OAT.Dom.append([self.elm,div],[div,tdiv,cdiv],[tdiv,a]);

		var cloud = new OAT.TagCloud(cdiv);
		for (var p in preds) {
			var simple = self.parent.simplify(p);
			if (simple == "hasTag") {
				var tags = preds[p];
				for (var i=0;i<tags.length;i++) {
					var tag = tags[i];
					self.addTag(tag,cloud);
				}
			}
		}

		this.clouds.push(cloud);
	}	

	this.redraw = function() {
		var data = self.parent.data.structured;

		this.clouds = [];
		OAT.Dom.clear(self.elm);

		for (var i=0;i<data.length;i++) {
			var item = data[i];
			if (self.parent.simplify(item.type) == "Tagcloud") {
				self.addCloud(item);
			}
		} /* for all items */

		for (var i=0; i<this.clouds.length;i++) {
			var cloud = this.clouds[i];
			cloud.draw();
		}

		var all = [];
		var links = self.elm.getElementsByTagName("a");
		for (var i=0;i<links.length;i++) { all.push(links[i]); }
		for (var i=0;i<all.length;i++) {
			var link = all[i];
			self.parent.processLink(link,link.href);
		}
	} /* redraw */
}

OAT.RDFTabs.fresnel = function(parent,optObj) {
	var self = this;
	OAT.RDFTabs.parent(self);

	this.options = {
		defaultURL:"",
		autoload:false
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }
	
	this.parent = parent;
	this.initialized = false;
	this.inputElm = OAT.Dom.create("div");
	this.mainElm = OAT.Dom.create("div",{},"rdf_fresnel");
	this.elm.className = "rdf_fresnel";
	this.description = "This module applies Fresnel RDF Vocabularies to all dereferenced data.";
	OAT.Dom.append([self.elm,self.inputElm,self.mainElm]);
	self.fresnel = new OAT.Fresnel();
	
	this.redraw = function() {
		var results = self.fresnel.format(self.parent.data.all);
		/* append stylesheets */
		var ss = results[1];
		for (var i=0;i<ss.length;i++) {
			var s = ss[i];
			var elm = OAT.Dom.create("link");
			elm.rel = "stylesheet";
			elm.type = "text/css";
			elm.href = s;
			document.getElementsByTagName("head")[0].appendChild(elm);
		}
		/* go */
		var cb = function(xslDoc) {
			var xmlDoc = results[0];
			var out = OAT.Xml.transformXSLT(xmlDoc,xslDoc);
			OAT.Dom.clear(self.mainElm);
			self.mainElm.innerHTML = OAT.Xml.serializeXmlDoc(out);
		}
		OAT.AJAX.GET(OAT.Preferences.xsltPath+"fresnel2html.xsl",false,cb,{type:OAT.AJAX.TYPE_XML});
	} /* redraw */

	if (self.options.autoload && self.options.defaultURL.length) {
		self.fresnel.addURL(self.options.defaultURL,self.redraw);
	} else {
		var inp = OAT.Dom.create("input");
		inp.size = "60";
		inp.value = self.options.defaultURL;
		var btn = OAT.Dom.button("Load Fresnel");
		var go = function() {
			if ($v(inp))
				self.fresnel.addURL($v(inp),self.redraw);

		}
		OAT.Event.attach(btn,"click",go);
		OAT.Event.attach(inp,"keypress",function(event) {
			if (event.keyCode == 13) { go(); }
		});
		OAT.Dom.append([self.inputElm,OAT.Dom.text("Fresnel URI: "),inp,btn]);
	}
}

OAT.Loader.featureLoaded("rdftabs");
