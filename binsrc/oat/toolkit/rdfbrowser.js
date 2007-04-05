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
	rb = new OAT.RDFBrowser("div",optObj);
	rb.store.addURL(url);
	rb.store.addTriples(triples,label,href);
	
	rb.addFilter(OAT.RDFBrowserData.FILTER_PROPERTY,"property","object");
	rb.addFilter(OAT.RDFBrowserData.FILTER_URI,"uri");
	rb.removeFilter(OAT.RDFBrowserData.FILTER_PROPERTY,"property","object");
	rb.removeFilter(OAT.RDFBrowserData.FILTER_URI,"uri");
	
	rb.toXML();
	rb.fromXML();
	rb.getTitle(item);
	rb.getContent(value);
	
	.rdf_filter .rdf_categories
	
	data: [
		[name,[
			[pred1,value1],
			[pred2,value2],
			...
		],
		...
	]
	
*/

OAT.RDFBrowserData = {
	FILTER_ALL:-1,
	FILTER_PROPERTY:0,
	FILTER_URI:1,
	SPARQL_TEMPLATE:"CONSTRUCT { ?property ?hasValue ?isValueOf } FROM <{graph}> WHERE { {  <{uri}> ?property ?hasValue . } UNION {   ?isValueOf ?property <{uri}> . } }"
}

OAT.RDFBrowser = function(div,optObj) {
	var self = this;

	this.options = {
		maxLength:30,
		maxDistinctValues:100,
		imagePath:OAT.Preferences.imagePath,
		indicator:false,
		defaultURL:"",
		endpoint:"/sparql?query="
	}
	for (var p in optObj) { this.options[p] = optObj[p]; }
	
	this.parent = $(div);
	this.tabs = [];
	this.allData = [];
	this.data = [];
	this.filtersURI = [];
	this.filtersProperty = [];
	this.tree = false;
	this.uri = false;

	this.bookmarks = {
		items:[],
		add:function(uri,label) {
			var query = OAT.RDFBrowserData.SPARQL_TEMPLATE;
			query = query.replace(/{uri}/g,uri).replace(/{graph}/g,self.uri);
			var u = self.options.endpoint+encodeURIComponent(query);
			var o = {
//				uri:u,
				uri:uri,
				label:label
			}
			self.bookmarks.items.push(o);
			self.bookmarks.redraw();
		},

		remove:function(index) {
			self.bookmarks.items.splice(index,1);
			self.bookmarks.redraw();
		},

		redraw:function() {
			var removeRef = function(a,index) {
				OAT.Dom.attach(a,"click",function(){self.bookmarks.remove(index);});
			}

			OAT.Dom.clear(self.bookmarkDiv);
			var h = OAT.Dom.create("h3");
			h.innerHTML = "Bookmarks";
			var d = OAT.Dom.create("div");
			for (var i=0;i<self.bookmarks.items.length;i++) {
				var item = self.bookmarks.items[i];
				var a = OAT.Dom.create("a");
				a.innerHTML = item.label;
				a.href = item.uri;
				var r = OAT.Dom.create("a");
				r.href = "#";
				r.innerHTML = "Remove";
				removeRef(r,i);
				OAT.Dom.append([d,a,OAT.Dom.text(" - "),r,OAT.Dom.create("br")]);
				self.createAnchor(a,item.uri,"bookmark");
			}
			OAT.Dom.append([self.bookmarkDiv,h,d]);
		}
	}
	
	this.store = {
		div:OAT.Dom.create("div"),
		items:[],
		redraw:function() {
			OAT.Dom.clear(self.store.div);
			var total = 0;
			var removeRef = function(a,index) {
				OAT.Dom.attach(a,"click",function(){self.store.remove(index);});
			}
			
			var tperm = OAT.Dom.create("a");
			tperm.innerHTML = "permalink";
			var base = window.location.toString().match(/^[^?#]+/)[0];
			tperm.href = base+"?";
			
			for (var i=0;i<self.store.items.length;i++) {
				var d = OAT.Dom.create("div");
				var item = self.store.items[i];
				total += item.triples.length;
				
				var a = OAT.Dom.create("a");
				a.href = item.href;
				a.innerHTML = item.label;
				d.appendChild(a);
				d.innerHTML += " - "+item.triples.length+" triples - ";
				var remove = OAT.Dom.create("a");
				remove.href = "#";
				remove.innerHTML = "Remove from storage";
				removeRef(remove,i);
				
				var perm = OAT.Dom.create("a");
				perm.innerHTML = "permalink";
				perm.href = base+"?uri="+encodeURIComponent(item.href);
				tperm.href += "uri[]="+encodeURIComponent(item.href)+"&";
				
				OAT.Dom.append([d,remove,OAT.Dom.text(" - "),perm]);
				self.store.div.appendChild(d);
			}
			
			var d = OAT.Dom.create("div");
			d.innerHTML = "TOTAL: "+total+" triples";
			self.store.div.appendChild(d);
			if (self.store.items.length) {
				OAT.Dom.append([d,OAT.Dom.text(" - "),tperm]);
			}
		},
		
		addURL:function(u,l) {
			var url = u.toString().trim();
			self.uri = url;
			var cback = function(xmlDoc) {
				if (self.options.indicator) { OAT.Dom.show(self.options.indicator); }
				var triples = OAT.RDF.toTriples(xmlDoc);
				/* sanitize triples */
				for (var i=0;i<triples.length;i++) {
					var t = triples[i];
					t[2] = t[2].replace(/<script[^>]*>/gi,'');
				}
				if (self.options.indicator) { OAT.Dom.hide(self.options.indicator); }
				var label = (l ? l : url);
				self.store.addTriples(triples,label,url);
			}
			OAT.Dereference.go(url,cback,{type:OAT.AJAX.TYPE_XML});
		},
		
		addTriples:function(triples,label,href) {
			var o = {
				label:label,
				triples:triples,
				href:href
			}
			self.store.items.push(o);
			self.store.redraw();
			self.store.rebuild(false);
		},
		
		clear:function() {
			self.store.items = [];
			self.store.redraw();
			self.store.rebuild(true);
		},
		
		remove:function(index) {
			self.store.items.splice(index,1);
			self.store.redraw();
			self.store.rebuild(true);
		},
		
		rebuild:function(complete) {
			function addTriple(triple) {
				var s = triple[0];
				var p = triple[1];
				var o = triple[2];
				var cnt = self.allData.length;
				for (var i=0;i<cnt;i++) {
					var item = self.allData[i];
					if (item[0] == s) {
						/* good, we have this subject */
						for (var j=0;j<item[1].length;j++) {
							var pair = item[1][j];
							if (pair[0] == p && pair[1] == o) { return; } /* we already have this triple */
						} /* for all predicates */
						item[1].push([p,o]);
						return;
					} /* if subject match */
				} /* for all existing subjects */
				self.allData.push([s,[[p,o]]]); /* new item */
			}

			var todo = [];
			if (complete) {
				self.allData = [];
				for (var i=0;i<self.store.items.length;i++) {
					todo.append(self.store.items[i].triples);
				}
			} else {
				todo = self.store.items[self.store.items.length-1].triples;
			}
			for (var i=0;i<todo.length;i++) { addTriple(todo[i]); }
			self.applyFilters(OAT.RDFBrowserData.FILTER_ALL); /* all filters */
		},
		
		loadFromInput:function() {
			self.store.addURL($v(self.store.url));
		},
		
		init:function() {
			var url = OAT.Dom.create("input");
			url.size = 90;
			url.type = "text";
			url.value = self.options.defaultURL;
			self.store.url = url;
			
			var btn1 = OAT.Dom.button("Query");
			var btn2 = OAT.Dom.button("Load via Local WebDAV");
			
			var h = OAT.Dom.create("h3");
			h.innerHTML = "Data Source URI";
			OAT.Dom.append([self.cacheDiv,h,url,btn1,btn2,self.store.div]);
			OAT.Dom.attach(btn1,"click",self.store.loadFromInput);
			OAT.Dom.attach(btn2,"click",function() {
				var options = {
					mode:'open_dialog',
					pathDefault:'/DAV/home/'+http_cred.user+'/',
					user:http_cred.user,
					pass:http_cred.password,
					onConfirmClick:function(path,fname,data) {
						url.value = path+fname;
						return true; /* return false will keep browser open */
					}
				};
				OAT.WebDav.open(options);
			});
			
			/* querystring url */
			var obj = OAT.Dom.uriParams();
			if (!("uri" in obj)) { return; }
			if (typeof(obj.uri) == "object") { /* array of uris */
				for (var i=0;i<obj.uri.length;i++) {
					url.value = obj.uri[i];
					self.store.loadFromInput();
				}
			} else {
				url.value = obj.uri;
				self.store.loadFromInput();
			}
		}
		
	}

	this.addTab = function(type,label,optObj) {
		var obj = new OAT.RDFTabs[type](self,optObj);
		self.tabs.push(obj);
		var li = OAT.Dom.create("li");
		li.innerHTML = label;
		self.tabsUL.appendChild(li);
		self.tab.add(li,obj.elm);
		self.tab.go(0);
	}

	this.createAnchor = function(element,uri,forbid) {
		var genRef = function() {
			var list = self.generateURIActions(uri,forbid);
			var ul = OAT.Dom.create("ul",{paddingLeft:"20px",marginLeft:"0px"});
			for (var i=0;i<list.length;i++) {
				if (list[i]) {
					var elm = OAT.Dom.create("li");
					elm.appendChild(list[i]);
				} else {
					var elm = OAT.Dom.create("hr");
				}
				ul.appendChild(elm);
			}
			return ul;
		}
			
		var obj = {
			title:"URL",
			activation:"click",
			content:genRef,
			width:0,
			height:0,
			result_control:false
		};
		if (OAT.Dom.isIE()) { obj.width = 300; }
		OAT.Anchor.assign(element,obj);
	}
	
	this.generateURIActions = function(uri,forbid) {
		var list = [];
		var a = OAT.Dom.create("a");
		a.innerHTML = "Get Data Set (Dereference)";
		a.href = "javascript:void(0)";
		OAT.Dom.attach(a,"click",function() {
			/* dereference link - add */
			OAT.AnchorData.window.close();
			self.store.addURL(uri);
		});
		list.push(a);

		if (forbid != "replace") {
		var a = OAT.Dom.create("a");
		a.innerHTML = "Get Data Set (Dereference) - replace storage";
		a.href = "javascript:void(0)";
		OAT.Dom.attach(a,"click",function() {
			/* dereference link - replace */
			OAT.AnchorData.window.close();
			self.store.clear();
			self.store.addURL(uri);
		});
		list.push(a);
		}
		
		var a = OAT.Dom.create("a");
		a.innerHTML = "Get Data Set (Dereference) - permalink";
		var root = window.location.toString().match(/^[^#]+/)[0];
		a.href = root+"#"+encodeURIComponent(uri);
		list.push(a);
		list.push(false);

		var a = OAT.Dom.create("a");
		a.innerHTML = "Explore";
		a.href = "javascript:void(0)";
		OAT.Dom.attach(a,"click",function() {
			/* dereference link */
			OAT.AnchorData.window.close();
			self.addFilter(OAT.RDFBrowserData.FILTER_URI,uri);
		});
		list.push(a);

		if (forbid != "bookmark") {
		var aa = OAT.Dom.create("a");
			aa.innerHTML = "Bookmark";
		aa.href = "javascript:void(0)";
		OAT.Dom.attach(aa,"click",function(){
			var label = prompt("Please name your bookmark:",uri);
			self.bookmarks.add(uri,label);
			OAT.AnchorData.window.close();
		});
		list.push(aa);
		}
		list.push(false);

		var a = OAT.Dom.create("a");
		a.innerHTML = "(X)HTML Page Open";
		a.href = uri;
		list.push(a);
		
		return list;
	},
	
	this.reset = function() { /* triples were changed */
		self.redraw(); /* redraw global elements */
		for (var i=0;i<self.tabs.length;i++) { self.tabs[i].reset(); }
		if (self.tab.selectedIndex != -1) { self.tabs[self.tab.selectedIndex].redraw(); }
	}

	this.drawCategories = function() { /* category tree */
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
			if ((!atLeastOne && p != "type") || (count <= 1 && p != "type") || count > self.options.maxDistinctValues) { delete cats[p]; }
		}
		
		function assign(node,p,o) {
			var ref = function() {
				self.addFilter(OAT.RDFBrowserData.FILTER_PROPERTY,p,o);
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
		
		function assignP(link,index) {
			var ref = function() {
				var f = self.filtersProperty[index];
				self.removeFilter(OAT.RDFBrowserData.FILTER_PROPERTY,f[0],f[1]);
			}
			OAT.Dom.attach(link,"click",ref);
		}
		
		function assignU(link,index) {
			var ref = function() {
				var f = self.filtersURI[index];
				self.removeFilter(OAT.RDFBrowserData.FILTER_URI,f);
			}
			OAT.Dom.attach(link,"click",ref);
		}

		for (var i=0;i<self.filtersProperty.length;i++) {
			var f = self.filtersProperty[i];
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
			assignP(remove,i);
			div.appendChild(remove);
			self.filterDiv.appendChild(div);
		}
		
		for (var i=0;i<self.filtersURI.length;i++) {
			var value = self.filtersURI[i];
			var div = OAT.Dom.create("div");
			var strong = OAT.Dom.create("strong");
			strong.innerHTML = "URI: ";
			div.appendChild(strong);
			div.innerHTML += value+" ";
			var remove = OAT.Dom.create("a");
			remove.setAttribute("href","javascript:void(0)");
			remove.setAttribute("title","Remove this filter");
			remove.innerHTML = "[remove]";
			assignU(remove,i);
			div.appendChild(remove);
			self.filterDiv.appendChild(div);
		}

		if (!self.filtersURI.length && !self.filtersProperty.length) {
			var div = OAT.Dom.create("div");
			div.innerHTML = "No filters are selected. Create some by clicking on values in Categories you want to view.";
			self.filterDiv.appendChild(div);
		}
		
		if (self.filtersURI.length + self.filtersProperty.length > 1) {
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
	
	this.redraw = function() { /* everything */
		if (self.options.indicator) { OAT.Dom.show(self.options.indicator); }
		self.drawCategories();
		self.drawFilters();
		if (self.options.indicator) { OAT.Dom.hide(self.options.indicator); }
	}
	
	this.applyFilters = function(type) {
		if (self.options.indicator) { OAT.Dom.show(self.options.indicator); }
		function filterObj(t,arr,filter) { /* apply one filter */
			var newData = [];
			for (var i=0;i<arr.length;i++) {
				var preds = arr[i][1];
				var ok = false;
				if (t == OAT.RDFBrowserData.FILTER_URI) {
					if (filter == arr[i][0]) { /* uri filter */
						newData.push(arr[i]);
						break;
					}
					for (var j=0;j<preds.length;j++) {
						var pair = preds[j];
						if (pair[1] == filter) {
							newData.push(arr[i]); 
							break;
						}
					} /* for all pairs */
				} /* uri filter */
				
				if (t == OAT.RDFBrowserData.FILTER_PROPERTY) {
					for (var j=0;j<preds.length;j++) {
						var pair = preds[j];
						if ((pair[0] == filter[0] && pair[1] == filter[1]) || (pair[0] == filter[0] && filter[1] == "")) {
							newData.push(arr[i]); 
							break;
						}
					} /* for all pairs */
				}  /* property filter */

			} /* for all subjects */
			return newData;
		}
		
		switch (type) {
			case OAT.RDFBrowserData.FILTER_ALL: /* all filters */
				self.data = self.allData;
				for (var i=0;i<self.filtersProperty.length;i++) {
					var f = self.filtersProperty[i];
					self.data = filterObj(OAT.RDFBrowserData.FILTER_PROPERTY,self.data,f);
				}
				for (var i=0;i<self.filtersURI.length;i++) {
					var f = self.filtersURI[i];
					self.data = filterObj(OAT.RDFBrowserData.FILTER_URI,self.data,f);
				}
			break;

			case OAT.RDFBrowserData.FILTER_PROPERTY:
				var f = self.filtersProperty[self.filtersProperty.length-1]; /* last filter */
				self.data = filterObj(type,self.data,f);
			break;

			case OAT.RDFBrowserData.FILTER_URI:
				var f = self.filtersURI[self.filtersURI.length-1]; /* last filter */
				self.data = filterObj(type,self.data,f);
			break;
		}
		if (self.options.indicator) { OAT.Dom.hide(self.options.indicator); }
		self.reset();
	}
	
	this.addFilter = function(type, predicate, object) {
		switch (type) {
			case OAT.RDFBrowserData.FILTER_PROPERTY: 
				self.filtersProperty.push([predicate,object]);
			break;
			case OAT.RDFBrowserData.FILTER_URI: 
				self.filtersURI.push(predicate);
			break;
		}
		self.applyFilters(type);
	}
	
	this.removeFilter = function(type,predicate,object) {
		var index = -1;
		
		switch (type) {
			case OAT.RDFBrowserData.FILTER_URI: 
				for (var i=0;i<self.filtersURI.length;i++) {
					var f = self.filtersURI[i];
					if (f == predicate) { index = i; }
				}
				if (index == -1) { return; }
				self.filtersURI.splice(index,1);
			break;

			case OAT.RDFBrowserData.FILTER_PROPERTY: 
				for (var i=0;i<self.filtersProperty.length;i++) {
					var f = self.filtersProperty[i];
					if (f[0] == predicate && f[1] == object) { index = i; }
				}
				if (index == -1) { return; }
				self.filtersProperty.splice(index,1);
			break;
		}
		
		self.applyFilters(OAT.RDFBrowserData.FILTER_ALL);
	}
	
	this.removeAllFilters = function() {
		self.filtersURI = [];
		self.filtersProperty = [];
		self.applyFilters(OAT.RDFBrowserData.FILTER_ALL);
	}
	
	this.getContent = function(data,forbid) {
		var content = false;
		if (data.match(/^http.*(jpe?g|png|gif)$/i)) { /* image */
			content = OAT.Dom.create("img");
			content.title = data;
			content.src = data;
			self.createAnchor(content,data,forbid);
		} else if (data.match(/^http/i)) { /* link */
			content = OAT.Dom.create("a");
			content.innerHTML = data;
			content.href = data;
			self.createAnchor(content,data,forbid);
		} else if (data.match(/^[^@]+@[^@]+$/i)) { /* mail address */
			content = OAT.Dom.create("a");
			var r = data.match(/^(mailto:)?(.*)/);
			content.innerHTML = r[2];
			content.href = 'mailto:'+r[2];
		} else { /* default - text */
			content = OAT.Dom.create("span");
			content.innerHTML = data;
		}
		return content;
	}
	
	this.getTitle = function(item) {
		var result = item[0];
		var props = ["name","label","title"];
		var preds = item[1];
		for (var i=0;i<preds.length;i++) {
			var p = preds[i][0];
			var o = preds[i][1];
			if (props.find(p) != -1) { return o; }
		}
		return result;
	}
	
	this.init = function() {
		/* dom */
		OAT.Dom.clear(self.parent);
		self.cacheDiv = OAT.Dom.create("div",{},"rdf_cache");
		self.filterDiv = OAT.Dom.create("div",{},"rdf_filter");
		self.categoryDiv = OAT.Dom.create("div",{},"rdf_categories");
		self.bookmarkDiv = OAT.Dom.create("div",{},"rdf_bookmarks");
		self.sideDiv = OAT.Dom.create("div",{},"rdf_side");
		self.tabsUL = OAT.Dom.create("ul",{},"rdf_tabs");
		self.tabDiv = OAT.Dom.create("div",{},"rdf_content");
		OAT.Dom.append([self.parent,self.sideDiv,self.cacheDiv,self.filterDiv,self.tabsUL,self.tabDiv]);
		OAT.Dom.append([self.sideDiv,self.categoryDiv,self.bookmarkDiv]);
		
		self.tab = new OAT.Tab(self.tabDiv);
		self.tab.goCallback = function(oldIndex,newIndex) {
			if (OAT.AnchorData.window) { OAT.AnchorData.window.close(); }
			self.tabs[newIndex].redraw(true);
		}
		self.redraw();
		self.store.init();
		self.bookmarks.redraw();
	}
	
	this.toXML = function(xslStr) {
		var xml = '<?xml version="1.0" ?>\n';
		if (xslStr) { xml += xslStr+'\n'; }
		xml += '<rdfbrowser tab="'+self.tabsUL.childNodes[self.tab.selectedIndex].innerHTML+'">\n';
		for (var i=0;i<self.store.items.length;i++) {
			var item = self.store.items[i];
			xml += '\t<uri label="'+item.label+'">'+OAT.Dom.toSafeXML(item.href)+'</uri>\n';
		}
		
		xml += '</rdfbrowser>\n';
		return xml;
	}
	
	this.fromXML = function(xmlDoc) {
		self.store.clear();
		self.removeAllFilters();
		var items = xmlDoc.getElementsByTagName("uri");
		for (var i=0;i<items.length;i++) {
			var item = items[i];
			var label = item.getAttribute("label");
			var href = OAT.Xml.textValue(item);
			self.store.addURL(OAT.Dom.fromSafeXML(href),label);
		}
		var b = xmlDoc.getElementsByTagName("rdfbrowser")[0];
		var label = b.getAttribute("tab");
		var index = -1;
		for (var i=0;i<self.tabsUL.childNodes.length;i++) {
			var l = self.tabsUL.childNodes[i].innerHTML;
			if (l == label) { index = i; }
		}
		if (index != -1) { self.tab.go(index); }
		
	}
	
	this.init();
}
OAT.Loader.featureLoaded("rdfbrowser");
