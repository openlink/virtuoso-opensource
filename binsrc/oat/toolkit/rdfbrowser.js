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
	rb.getURI(item);
	
	#rdf_side #rdf_cache #rdf_filter #rdf_tabs #rdf_content
	
	data.triples
	data.structured
	
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
		maxURILength:60,
		maxDistinctValues:100,
		imagePath:OAT.Preferences.imagePath,
		indicator:false,
		defaultURL:"",
		appActivation:"click",
		endpoint:"/sparql?query="
	}
	for (var p in optObj) { this.options[p] = optObj[p]; }
	
	this.parent = $(div);
	this.tabs = [];
	this.data = {
		all:[],
		triples:[],
		structured:[] 
		/*
			structured: [
				{
					uri:"uri",
					ouri:"originating uri",
					preds:{a:[0,1],...},
					back:[] - list of backreferences
				}
				, ...
			]
		*/
	};
	this.filtersURI = [];
	this.filtersProperty = [];
	this.tree = false;
	this.uri = false;

	this.bookmarks = {
		items:[],
		
		init:function() {
			self.bookmarks.redraw();
			
			var obj = OAT.Dom.uriParams();
			if (!("bmURI" in obj)) { return; }
			var uris = obj.bmURI;
			var labels = obj.bmLabel;
			for (var i=0;i<uris.length;i++) {
				var uri = decodeURIComponent(uris[i]);
				var label = decodeURIComponent(labels[i]);
				self.bookmarks.add(uri,label);
			}
		},
		
		add:function(uri,label) {
			var query = OAT.RDFBrowserData.SPARQL_TEMPLATE;
			query = query.replace(/{uri}/g,uri).replace(/{graph}/g,self.uri);
			var u = self.options.endpoint+encodeURIComponent(query);
			var o = {
				uri:uri,
				label:label
			}
			self.bookmarks.items.push(o);
			self.bookmarks.redraw();
			self.store.redraw();
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
				self.createAnchor(a,item.uri,"bookmark");
				OAT.Dom.append([d,a,OAT.Dom.text(" - "),r,OAT.Dom.create("br")]);
			}
			OAT.Dom.append([self.bookmarkDiv,h,d]);
		},
		
		toURL:function() {
			var result = "";
			for (var i=0;i<self.bookmarks.items.length;i++) {
				var item = self.bookmarks.items[i];
				result += encodeURIComponent("bmURI[]")+"="+encodeURIComponent(item.uri)+"&";
				result += encodeURIComponent("bmLabel[]")+"="+encodeURIComponent(item.label)+"&";
			}
			return result;
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
			var th = base+"?";
			
			for (var i=0;i<self.store.items.length;i++) {
				var d = OAT.Dom.create("div");
				var item = self.store.items[i];
				total += item.triples.length;
				
				var a = OAT.Dom.create("a");
				a.href = item.href;
				var label = (item.label.length > self.options.maxURILength ? item.label.substring(0,self.options.maxURILength) + "..." : item.label);
				a.innerHTML = label;

				d.appendChild(a);
				d.innerHTML += " - "+item.triples.length+" triples - ";
				var remove = OAT.Dom.create("a");
				remove.href = "#";
				remove.innerHTML = "Remove from storage";
				removeRef(remove,i);
				
				var perm = OAT.Dom.create("a");
				perm.innerHTML = "permalink";
				perm.href = base+"?uri="+encodeURIComponent(item.href);
				th += encodeURIComponent("uri[]")+"="+encodeURIComponent(item.href)+"&";
				
				OAT.Dom.append([d,remove,OAT.Dom.text(" - "),perm]);
				self.store.div.appendChild(d);
			}
			
			tperm.href = th + self.bookmarks.toURL();
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
		
		addSPARQL:function(q) {
			var url = self.options.endpoint+encodeURIComponent(q)+"&format=rdf";
			self.store.addURL(url);
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
			var conversionTable = {};
			
			/* 0. adding subroutine */
			function addTriple(triple,originatingURI) {
				var s = triple[0];
				var p = triple[1];
				var o = triple[2];
				var cnt = self.data.all.length;
				
				if (s in conversionTable) { /* we already have this; add new property */
					var obj = conversionTable[s];
					var preds = obj.preds;
					if (p in preds) { preds[p].push(o); } else { preds[p] = [o]; }
				} else { /* new resource */
					var obj = {
						preds:{},
						ouri:originatingURI,
						uri:s,
						back:[]
					}
					obj.preds[p] = [o];
					conversionTable[s] = obj;
					self.data.all.push(obj);
			}
			} /* add one triple to the structure */

			/* 1. add all needed triples into structure */
			var todo = [];
			if (complete) {
				self.data.all = [];
				for (var i=0;i<self.store.items.length;i++) {
					var item = self.store.items[i];
					todo.push([item.triples,item.label]);
				}
			} else {
				var item = self.store.items[self.store.items.length-1];
				todo.push([item.triples,item.label]);
			}
			for (var i=0;i<todo.length;i++) { 
				var triples = todo[i][0];
				var uri = todo[i][1];
				for (var j=0;j<triples.length;j++) { addTriple(triples[j],uri); }
			}
				
			/* 2. create reference links based on conversionTable */
			for (var i=0;i<self.data.all.length;i++) {
				var item = self.data.all[i];
				var preds = item.preds;
				for (var j in preds) {
					var pred = preds[j];
					for (var k=0;k<pred.length;k++) {
						var value = pred[k];
						if (value in conversionTable) { 
							var target = conversionTable[value];
							pred[k] = target; 
							if (target.back.find(item) == -1) { target.back.push(item); }
				}
			}
				} /* predicates */
			} /* items */
			
			/* 3. apply filters: create self.data.structured + 4. convert filtered data back to triples */
			conversionTable = {}; /* clean up */
			self.applyFilters(OAT.RDFBrowserData.FILTER_ALL,true); /* all filters, hard reset */
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
			OAT.Dom.attach(url,"keypress",function(event) {
				if (event.keyCode == 13) { self.store.loadFromInput(); }
			});
			OAT.Dom.attach(btn1,"click",self.store.loadFromInput);
			OAT.Dom.attach(btn2,"click",function() {
				var options = {
					extensionFilters:[],
					callback:function(path,name,data) {
						if (name.match(/\.rq$/)) {
							self.fromRQ(data,false);
						} else if (name.match(/\.isparql$/)) {
							var xmlDoc = OAT.Xml.createXmlDoc(data);
							var q = xmlDoc.getElementsByTagName("query")[0];
							self.fromRQ(OAT.Xml.textValue(q),false);
						} else if (name.match(/\.xml$/) || name.match(/\.rdf$/)) { /* local file */
							self.store.url.value = path+name;
							self.store.loadFromInput();
						} else { /* try the sponger */
							self.store.url.value = window.location.protocol+"//"+window.location.host+path+name;
							self.store.loadFromInput();
						}
					}
				};
				OAT.WebDav.openDialog(options);
			});
			
			/* querystring url */
			var obj = OAT.Dom.uriParams();
			if (!("uri" in obj)) { return; }
			if (typeof(obj.uri) == "object") { /* array of uris */
				for (var i=0;i<obj.uri.length;i++) {
					self.store.addURL(obj.uri[i]);
				}
			} else {
				self.store.addURL(obj.uri);
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
			content:genRef,
			width:300,
			height:200,
			result_control:false,
			activation:self.options.appActivation
		};
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
	
	this.generateImageActions = function(uri) {
		var list = [];
		var img1 = OAT.Dom.create("img",{paddingLeft:"3px",cursor:"pointer"});
		img1.title = "Get Data Set (Dereference)";
		img1.src = self.options.imagePath + "RDF_rdf.png";
		OAT.Dom.attach(img1,"click",function() {
			/* dereference link - add */
			OAT.AnchorData.window.close();
			self.store.addURL(uri);
		});
		list.push(img1);

		var a = OAT.Dom.create("a",{paddingLeft:"3px"});
		var img2 = OAT.Dom.create("img",{border:"none"});
		img2.src = self.options.imagePath + "RDF_xhtml.gif";
		a.title = "(X)HTML Page Open";
		a.appendChild(img2);
		a.target = "_blank";
		a.href = uri;
		list.push(a);
		
		return list;
	}
	
	this.reset = function() { /* triples were changed */
		for (var i=0;i<self.tabs.length;i++) { self.tabs[i].reset(); }
		self.redraw(); /* redraw global elements */
	}

	this.drawCategories = function() { /* category tree */
		OAT.Dom.clear(self.categoryDiv);
		var h = OAT.Dom.create("h3");
		h.innerHTML = "Categories";
		self.categoryDiv.appendChild(h);

		var cats = {}; /* object of distinct values contained in filtered data */
		for (var i=0;i<self.data.structured.length;i++) {
			var item = self.data.structured[i];
			var preds = item.preds;
			for (var p in preds) {
				var pred = preds[p];
				for (var j=0;j<pred.length;j++) {
					var value = pred[j];
					if (typeof(value) == "object") { continue; }

					if (!(p in cats)) { cats[p] = {}; }
					var obj = cats[p];
					if (!(value in obj)) { obj[value] = 0; }
					obj[value]++;
				}
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
				var label = o;
				var r = label.match(/#(.+)$/);
				if (r) { label = r[1]; }
				if (label.length > self.options.maxLength) { label = label.substring(0,self.options.maxLength) + "&hellip;"; }
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
		
/*
		for (var i=0;i<self.tree.tree.children.length;i++) { // expand 'type' node 
			var li = self.tree.tree.children[i];
			if (li.getLabel().match(/type/)) { li.expand(); }
		}	
*/
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
		self.store.redraw();
		self.bookmarks.redraw();
		for (var i=0;i<self.tabs.length;i++) {
			var tab = self.tab.tabs[i];
			if (i == self.tab.selectedIndex || tab.window) { self.tabs[i].redraw(); }
		}
		if (self.options.indicator) { OAT.Dom.hide(self.options.indicator); }
	}
	
	this.applyFilters = function(type,hardReset) {
		if (self.options.indicator) { OAT.Dom.show(self.options.indicator); }
		function filterObj(t,arr,filter) { /* apply one filter */
			var newData = [];
			for (var i=0;i<arr.length;i++) {
				var item = arr[i];
				var preds = item.preds;
				var ok = false;
				if (t == OAT.RDFBrowserData.FILTER_URI) {
					if (filter == item.uri) { /* uri filter */
						newData.push(item);
						ok = true;
					}
					if (!ok) for (var p in preds) {
						var pred = preds[p];
						for (var j=0;j<pred.length;j++) {
							var value = pred[j];
							if (typeof(value) == "object" && value.uri == filter && !ok) { 
								newData.push(item); 
								ok = true;
							} /* if filter match */
						} /* for all predicate values */
					} /* for all predicates */
				} /* uri filter */
				
				if (t == OAT.RDFBrowserData.FILTER_PROPERTY) {
					for (var p in preds) {
						var pred = preds[p];
						if (p == filter[0]) {
							if (filter[1] == "") {
								ok = true;
								newData.push(item);
							} else for (var j=0;j<pred.length;j++) {
								var value = pred[j];
								if (value == filter[1]) {
									ok = true;
									newData.push(item);
								} /* match! */
							} /* nonempty */
						} /* if first filter part match */
					} /* for all pairs */
				}  /* property filter */

			} /* for all subjects */
			return newData;
		}
		
		switch (type) {
			case OAT.RDFBrowserData.FILTER_ALL: /* all filters */
				self.data.structured = self.data.all;
				for (var i=0;i<self.filtersProperty.length;i++) {
					var f = self.filtersProperty[i];
					self.data.structured = filterObj(OAT.RDFBrowserData.FILTER_PROPERTY,self.data.structured,f);
				}
				for (var i=0;i<self.filtersURI.length;i++) {
					var f = self.filtersURI[i];
					self.data.structured = filterObj(OAT.RDFBrowserData.FILTER_URI,self.data.structured,f);
				}
			break;

			case OAT.RDFBrowserData.FILTER_PROPERTY:
				var f = self.filtersProperty[self.filtersProperty.length-1]; /* last filter */
				self.data.structured = filterObj(type,self.data.structured,f);
			break;

			case OAT.RDFBrowserData.FILTER_URI:
				var f = self.filtersURI[self.filtersURI.length-1]; /* last filter */
				self.data.structured = filterObj(type,self.data.structured,f);
			break;
		}
		
		self.data.triples = [];
		for (var i=0;i<self.data.structured.length;i++) {
			var item = self.data.structured[i];
			for (var p in item.preds) {
				var pred = item.preds[p];
				for (var j=0;j<pred.length;j++) {
					var v = pred[j];
					var triple = [item.uri,p,(typeof(v) == "object" ? v.uri : v)];
					self.data.triples.push(triple);
				}
			}
		}
		
		if (self.options.indicator) { OAT.Dom.hide(self.options.indicator); }
		self.reset(hardReset);
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
	
	this.getContentType = function(str) {
		/* 0 - generic, 1 - link, 2 - mail, 3 - image */
		if (str.match(/^http.*(jpe?g|png|gif)$/i)) { return 3; }
		if (str.match(/^http/i)) { return 1; }
		if (str.match(/^[^@]+@[^@]+$/i)) { return 2; }
		return 0;
	}
	
	this.getContent = function(data_,forbid) {
		var content = false;
		var data = (typeof(data_) == "object" ? data_.uri : data_);
		var type = self.getContentType(data);
		
		switch (type) {
			case 3:
			content = OAT.Dom.create("img");
			content.title = data;
			content.src = data;
			self.createAnchor(content,data,forbid);
			break;
			case 2:
				content = OAT.Dom.create("a");
				var r = data.match(/^(mailto:)?(.*)/);
				content.innerHTML = r[2];
				content.href = 'mailto:'+r[2];
			break;
			case 1:
			content = OAT.Dom.create("span");
			var a = OAT.Dom.create("a");
			a.innerHTML = data;
			a.href = data;
			self.createAnchor(a,data,forbid);
			var imglist = self.generateImageActions(data);
			OAT.Dom.append([content,a,imglist]);
			break;
			default:
			content = OAT.Dom.create("span");
			content.innerHTML = data;
			/* create dereference a++ lookups for all anchors */
			var anchors = content.getElementsByTagName("a");
			for (var j=0;j<anchors.length;j++) {
				var a = anchors[j];
				if (a.href.match(/^http/)) {
					self.createAnchor(a,a.href); 
					var imglist = self.generateImageActions(a.href);
					var next = a.nextSibling;
					for (var k=0;k<imglist.length;k++) {
						a.parentNode.insertBefore(imglist[k],next);
					}
				}
			}
			break;
		} /* switch */
		return content;
	}
	
	this.getTitle = function(item) {
		var result = item.uri;
		var props = ["name","label","title","summary"];
		var preds = item.preds;
		for (var p in preds) {
			if (props.find(p) != -1) { return preds[p][0]; }
		}
		return result;
	}
	
	this.getURI = function(item) {
		if (item.uri.match(/^http/i)) { return item.uri; }
		var props = ["uri","url"];
		var preds = item.preds;
		for (var p in preds) {
			if (props.find(p) != -1) { return preds[p][0]; }
		}
		return false;
	}
	
	this.init = function() {
		/* dom */
		self.sideDiv = $("rdf_side");
		if (!self.sideDiv) { 
			self.sideDiv = OAT.Dom.create("div",{});
			self.sideDiv.id = "rdf_side";
			self.parent.appendChild(self.sideDiv);
		}

		self.cacheDiv = $("rdf_cache");
		if (!self.cacheDiv) { 
			self.cacheDiv = OAT.Dom.create("div",{});
			self.cacheDiv.id = "rdf_cache";
			self.parent.appendChild(self.cacheDiv);
		}

		self.filterDiv = $("rdf_filter");
		if (!self.filterDiv) { 
			self.filterDiv = OAT.Dom.create("div",{});
			self.filterDiv.id = "rdf_filter";
			self.parent.appendChild(self.filterDiv);
		}

		self.tabsUL = $("rdf_tabs");
		if (!self.tabsUL) { 
			self.tabsUL = OAT.Dom.create("ul",{});
			self.tabsUL.id = "rdf_tabs";
			self.parent.appendChild(self.tabsUL);
		}

		self.tabDiv = $("rdf_content");
		if (!self.tabDiv) { 
			self.tabDiv = OAT.Dom.create("div",{});
			self.tabDiv.id = "rdf_content";
			self.parent.appendChild(self.tabDiv);
		}

		self.categoryDiv = OAT.Dom.create("div",{},"rdf_categories");
		self.bookmarkDiv = OAT.Dom.create("div",{},"rdf_bookmarks");
		OAT.Dom.append([self.sideDiv,self.categoryDiv,self.bookmarkDiv]);
		
		self.tab = new OAT.Tab(self.tabDiv,{dockMode:true,dockElement:"rdf_tabs"});
		var actTab = function(index) {
			self.tabs[index].redraw();
		}
		self.tab.options.onDock = actTab;
		self.tab.options.onUnDock = actTab;
		self.tab.options.goCallback = function(oldIndex,newIndex) {
			if (OAT.AnchorData.window) { OAT.AnchorData.window.close(); }
			self.tabs[newIndex].redraw();
		}
		
		self.redraw();
		self.store.init();
		self.bookmarks.init();
	}
	
	this.toXML = function(xslStr) {
		var xml = '<?xml version="1.0" ?>\n';
		if (xslStr) { xml += xslStr+'\n'; }
		xml += '<rdfbrowser tab="'+self.tabsUL.childNodes[self.tab.selectedIndex].innerHTML+'">\n';
		for (var i=0;i<self.store.items.length;i++) {
			var item = self.store.items[i];
			xml += '\t<uri label="'+OAT.Dom.toSafeXML(item.label)+'">'+OAT.Dom.toSafeXML(item.href)+'</uri>\n';
		}
		for (var i=0;i<self.bookmarks.items.length;i++) {
			var item = self.bookmarks.items[i];
			xml += '\t<bookmark label="'+OAT.Dom.toSafeXML(item.label)+'">'+OAT.Dom.toSafeXML(item.uri)+'</bookmark>\n';
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
			var label = OAT.Dom.fromSafeXML(item.getAttribute("label"));
			var href = OAT.Xml.textValue(item);
			self.store.addURL(OAT.Dom.fromSafeXML(href),label);
		}
		var items = xmlDoc.getElementsByTagName("bookmark");
		for (var i=0;i<items.length;i++) {
			var item = items[i];
			var label = OAT.Dom.fromSafeXML(item.getAttribute("label"));
			var uri = OAT.Xml.textValue(item);
			self.bookmarks.add(OAT.Dom.fromSafeXML(uri),label);
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
	
	this.fromRQ = function(data,clear) {
		if (clear) {
		self.store.clear();
		self.removeAllFilters();
		}
		var q = "";
		var d = data.replace(/[\r\n]/g," \n");
		var parts = d.split("\n");
		for (var i=0;i<parts.length;i++) {
			var part = parts[i].replace(/\n/g,"");
			var r = part.match(/^[^#]*/);
			q += r[0];
		}
		self.store.addSPARQL(q);
		if (clear) { self.tab.go(0); }
	}
	
	this.init();
}
OAT.Loader.featureLoaded("rdfbrowser");
