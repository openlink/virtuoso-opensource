/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2013 OpenLink Software
 *
 *  See LICENSE file for details.
 */

/*
	rb = new OAT.RDFBrowser("div",optObj);

	rb.toXML();
	rb.fromXML();
	rb.getTitle(item);
	rb.getContent(value);
	rb.getURI(item);
	rb.processLink(domNode, href, disabledActions);

	#rdf_side #rdf_cache #rdf_filter #rdf_tabs #rdf_content

	data.triples
	data.structured

*/

OAT.RDFBrowser = function(div,optObj) {
	var self = this;

	this.options = {
		maxLength:30,
		maxURILength:60,
		maxDistinctValues:100,
		imagePath:OAT.Preferences.imagePath,
		defaultURL:"",
		appActivation:"click",
		endpoint:"/sparql?query="
	}
	for (var p in optObj) { this.options[p] = optObj[p]; }

	this.parent = $(div);
	this.tabs = [];
	this.tree = false;
	this.uri = false;

	this.throbber = false;
	this.throbberElm = false;
	this.ajaxEnd = function() {
		if (self.throbber) {
			if (self.throbberElm) {
				self.throbber.parentNode.replaceChild(self.throbberElm,self.throbber);
			} else {
				OAT.Dom.unlink(self.throbber);
			}
			self.throbber = false;
			self.throbberElm = false;
		}
		if (OAT.AnchorData.window) { OAT.AnchorData.window.close(); }
	}

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
			var query = "CONSTRUCT { ?property ?hasValue ?isValueOf } FROM <{graph}> WHERE { {  <{uri}> ?property ?hasValue . } UNION {   ?isValueOf ?property <{uri}> . } }";
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
				OAT.Event.attach(a,"click",function(){self.bookmarks.remove(index);});
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
				r.href = "javascript:void(0)";
				r.innerHTML = "Remove";
				removeRef(r,i);
				OAT.Dom.append([d,a,OAT.Dom.text(" - "),r,OAT.Dom.create("br")]);
				self.processLink(a,item.uri,OAT.RDFData.DISABLE_BOOKMARK);
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

	this.reset = function(hard) { /* triples were changed */
		for (var i=0;i<self.tabs.length;i++) { self.tabs[i].reset(hard); }
		self.redraw(); /* redraw global elements */
	}

	this.store = new OAT.RDFStore(self.reset,{onend:self.ajaxEnd});
	this.store.div = OAT.Dom.create("div");
	this.data = self.store.data;

	this.store.redraw = function() {
		OAT.Dom.clear(self.store.div);
		var total = 0;
		var removeRef = function(a,url) {
			OAT.Event.attach(a,"click",function(event){ OAT.Event.prevent(event); self.store.remove(url);});
		}
		var checkRef = function(ch,url) {
			var f = function() {
				if (ch.checked) { self.store.enable(url);} else { self.store.disable(url); }
			}
			OAT.Event.attach(ch,"click",f);
			OAT.Event.attach(ch,"change",f);
		}

		var tperm = OAT.Dom.create("a");
		tperm.innerHTML = "permalink";
		var base = window.location.toString().match(/^[^?#]+/)[0];
		var th = base+"?";

		for (var i=0;i<self.store.items.length;i++) {
			var d = OAT.Dom.create("div");
			var item = self.store.items[i];
			total += item.triples.length;

			var ch = OAT.Dom.create("input");
			ch.type = "checkbox";
			ch.checked = item.enabled;
			ch.defaultChecked = item.enabled;

			var a = OAT.Dom.create("a");
//			a.href = item.href;
			var label = (item.href.length > self.options.maxURILength ? item.href.substring(0,self.options.maxURILength) + "..." : item.href);
			a.innerHTML = label;

			var t = OAT.Dom.text(" - "+item.triples.length+" triples - ");
			OAT.Dom.append([d,ch,OAT.Dom.text(" "),a,t]);
			self.processLink(a,item.href,OAT.RDFData.DISABLE_DEREFERENCE);


			var remove = OAT.Dom.create("a");
			remove.href = "#";
			remove.innerHTML = "Remove from storage";
			removeRef(remove,item.href);
			checkRef(ch,item.href);

			var perm = OAT.Dom.create("a");
			perm.innerHTML = "permalink";
			perm.href = base+"?uri="+encodeURIComponent(item.href);
			th += encodeURIComponent("uri[]")+"="+encodeURIComponent(item.href)+"&";

			OAT.Dom.append([d,remove,OAT.Dom.text(" - "),perm],[self.store.div,d]);
		}

		tperm.href = th + self.bookmarks.toURL();
		var d = OAT.Dom.create("div");
		d.innerHTML = "TOTAL: "+total+" triples";
		self.store.div.appendChild(d);
		if (self.store.items.length) {
			OAT.Dom.append([d,OAT.Dom.text(" - "),tperm]);
		}
	}

	this.store.addSPARQL = function(q) {
		var url = self.options.endpoint+encodeURIComponent(q)+"&format=rdf";
		self.store.addURL(url);
	}

	this.throbberReplace = function(elm,replace) {
		return function(xhr) {
			var t = OAT.Dom.create("img",{cursor:"pointer"});
			OAT.Event.attach(t,"click",xhr.abort);
			t.src = self.options.imagePath + "Dav_throbber.gif";
			self.throbber = t;
			self.throbberElm = replace ? elm : false;
			if (replace) {
				elm.parentNode.replaceChild(t,elm);
			} else {
				elm.parentNode.insertBefore(t,elm);
			}
		}
	}

	this.store.loadFromInput = function() {
		self.store.addURL($v(self.store.url),{ajaxOpts:{onstart:self.btnStart}});
	}

	this.store.init = function() {
		var url = OAT.Dom.create("input");
		url.size = 90;
		url.type = "text";
		url.value = self.options.defaultURL;
		self.store.url = url;

		var btn1 = OAT.Dom.create("input", {type:"button",value:"Query"});
		self.btnStart = self.throbberReplace(self.store.div,false);

		var h = OAT.Dom.create("h3");
		h.innerHTML = "Data Source (URL):";
		h.title = "RDF Data Source (URL):";
		OAT.Dom.append([self.cacheDiv,h,url,btn1,OAT.Dom.text(" "),self.store.div]);
		OAT.Event.attach(url,"keypress",function(event) {
			if (event.keyCode == 13) { self.store.loadFromInput(); }
		});
		OAT.Event.attach(btn1,"click",self.store.loadFromInput);

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

	this.addTab = function(type,label,optObj) {
		var obj = new OAT.RDFTabs[type](self,optObj);
		self.tabs.push(obj);
		var li = OAT.Dom.create("li");
		li.innerHTML = label;
		self.tabsUL.appendChild(li);
		self.tab.add(li,obj.elm);
		self.tab.go(0);
	}

	this.processLink = function(domNode,href,disabledActions) { /* assign custom things to a link */
		var genRef = function() {
			var list = self.generateURIActions(href,disabledActions);
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
			newHref:href,
			width:300,
			height:200,
			result_control:false,
			activation:self.options.appActivation
		};
		OAT.Anchor.assign(domNode,obj);

		/* maybe image links */
		var node = $(domNode);
		if (!node.parentNode) { return; } /* cannot append images when no parent is available */
		var images = self.generateImageActions(href,disabledActions);
		var next = node.nextSibling;
		for (var i=0;i<images.length;i++) {
			node.parentNode.insertBefore(images[i],next);
		}
	}

	this.generateURIActions = function(href,disabledActions) {
		var list = [];

		if (!(disabledActions & OAT.RDFData.DISABLE_DEREFERENCE)) {
			var a = OAT.Dom.create("a");
			a.innerHTML = "Data Link";
			a.href = href;
			var start1 = self.throbberReplace(a);
			OAT.Event.attach(a,"click",function(event) {
				/* dereference link - add */
				OAT.Event.prevent(event);
				self.store.addURL(href,{ajaxOpts:{onstart:start1}});
			});
			list.push(a);
		}

		if (!(disabledActions & OAT.RDFData.DISABLE_DEREFERENCE)) {
			var a = OAT.Dom.create("a");
			a.innerHTML = "Data Link - replace storage";
			a.href = href;
			var start2 = self.throbberReplace(a);
			OAT.Event.attach(a,"click",function(event) {
				/* dereference link - replace */
				OAT.Event.prevent(event);
				var ref = function() {
					self.store.clear();
					start2();
				}
				self.store.addURL(href,{ajaxOpts:{onstart:ref}});
			});
			list.push(a);
		}

		if (!(disabledActions & OAT.RDFData.DISABLE_DEREFERENCE)) {
			var a = OAT.Dom.create("a");
			a.innerHTML = "Data Link - permalink";
			var root = window.location.toString().match(/^[^#]+/)[0];
			a.href = root+"#"+encodeURIComponent(href);
			list.push(a);
			list.push(false);
		}

		if (!(disabledActions & OAT.RDFData.DISABLE_FILTER)) {
			var a = OAT.Dom.create("a");
			a.innerHTML = "Relationships";
			a.href = href;
			OAT.Event.attach(a,"click",function(event) {
				/* dereference link */
				OAT.Event.prevent(event);
				OAT.AnchorData.window.close();
				self.store.addFilter(OAT.RDFStoreData.FILTER_URI,href);
			});
			list.push(a);
		}

		if (!(disabledActions & OAT.RDFData.DISABLE_BOOKMARK)) {
			var aa = OAT.Dom.create("a");
			aa.innerHTML = "Bookmark";
			aa.href = href;
			OAT.Event.attach(aa,"click",function(event) {
				OAT.Event.prevent(event);
				var label = prompt("Please name your bookmark:",href);
				self.bookmarks.add(href,label);
				OAT.AnchorData.window.close();
			});
			list.push(aa);
		}
		list.push(false);

		if (!(disabledActions & OAT.RDFData.DISABLE_HTML)) {
			var a = OAT.Dom.create("a");
			a.innerHTML = "Document Link";
			a.href = href;
			list.push(a);
		}
		return list;
	},

	this.generateImageActions = function(href,disabledActions) {
		var list = [];
		if (!(disabledActions & OAT.RDFData.DISABLE_DEREFERENCE)) {
			var img1 = OAT.Dom.create("img",{paddingLeft:"3px",cursor:"pointer"});
			img1.title = "Data Link";
			img1.src = self.options.imagePath + "RDF_rdf.png";
			var start = self.throbberReplace(img1,true);
			OAT.Event.attach(img1,"click",function() {
				/* dereference link - add */
				self.store.addURL(href,{ajaxOpts:{onstart:start}});
			});
			list.push(img1);
		}


		if (!(disabledActions & OAT.RDFData.DISABLE_HTML)) {
			var a = OAT.Dom.create("a",{paddingLeft:"3px"});
			var img2 = OAT.Dom.create("img",{border:"none"});
			img2.src = self.options.imagePath + "RDF_xhtml.gif";
			a.title = "Document Link";
			a.appendChild(img2);
			a.target = "_blank";
			a.href = href;
			list.push(a);
		}
		return list;
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
			var pred = self.simplify(p);
			var atLeastOne = false;
			var obj = cats[p];
			for (var o in obj) {
				count++;
				if (obj[o] > 1) { atLeastOne = true; }
			}
			if ((!atLeastOne && pred != "type") || (count <= 1 && pred != "type") || count > self.options.maxDistinctValues) { delete cats[p]; }
		}

		function assign(node,p,o) {
			var ref = function() {
				self.store.addFilter(OAT.RDFStoreData.FILTER_PROPERTY,p,o);
			}
			OAT.Event.attach(node,"click",ref);
		}

		var ul = OAT.Dom.create("ul");
		var bigTotal = 0;
		for (var p in cats) {
			var obj = cats[p];
			var li = OAT.Dom.create("li");
			var lilabel = OAT.Dom.create("span");
			li.appendChild(lilabel);
			lilabel.innerHTML = self.simplify(p);
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
				var label = self.simplify(o);
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
		self.tree = new OAT.Tree({imagePath:self.options.imagePath,poorMode:(bigTotal > 1000),onClick:"toggle",onDblClick:"toggle"});
		self.tree.assign(ul,true);
		self.categoryDiv.appendChild(ul);
	}

	this.drawFilters = function() { /* list of applied filters */
		OAT.Dom.clear(self.filterDiv);
		var h = OAT.Dom.create("h3");
		h.innerHTML = "Filters";
		self.filterDiv.appendChild(h);

		function assignP(link,index) {
			var ref = function() {
				var f = self.store.filtersProperty[index];
				self.store.removeFilter(OAT.RDFStoreData.FILTER_PROPERTY,f[0],f[1]);
			}
			OAT.Event.attach(link,"click",ref);
		}

		function assignU(link,index) {
			var ref = function() {
				var f = self.store.filtersURI[index];
				self.store.removeFilter(OAT.RDFStoreData.FILTER_URI,f);
			}
			OAT.Event.attach(link,"click",ref);
		}

		for (var i=0;i<self.store.filtersProperty.length;i++) {
			var f = self.store.filtersProperty[i];
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

		for (var i=0;i<self.store.filtersURI.length;i++) {
			var value = self.store.filtersURI[i];
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

		if (!self.store.filtersURI.length && !self.store.filtersProperty.length) {
			var div = OAT.Dom.create("div");
			div.innerHTML = "No filters are selected. Create some by clicking on values in Categories you want to view.";
			self.filterDiv.appendChild(div);
		}

		if (self.store.filtersURI.length + self.store.filtersProperty.length > 1) {
			var div = OAT.Dom.create("div");
			var remove = OAT.Dom.create("a");
			remove.setAttribute("href","javascript:void(0)");
			remove.setAttribute("title","Remove all filters");
			remove.innerHTML = "remove all filters";
			OAT.Event.attach(remove,"click",self.store.removeAllFilters);
			div.appendChild(remove);
			self.filterDiv.appendChild(div);
		}
	}

	this.redraw = function() { /* everything */
		self.drawCategories();
		self.drawFilters();
		self.store.redraw();
		self.bookmarks.redraw();
		for (var i=0;i<self.tabs.length;i++) {
			var tab = self.tab.tabs[i];
			if (i == self.tab.selectedIndex || tab.window) { self.tabs[i].redraw(); }
		}
	}

	this.getContent = function(data_,disabledActions) {
		var content = false;
		var data = (typeof(data_) == "object" ? data_.uri : data_);
		var type = self.getContentType(data);

		switch (type) {
			case 3:
				content = OAT.Dom.create("img");
				content.title = data;
				content.src = data;
				self.processLink(content,data);
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
				content.appendChild(a);
				self.processLink(a,data,disabledActions);
			break;
			default:
				content = OAT.Dom.create("span");
				content.innerHTML = data;
				/* create dereference a++ lookups for all anchors */
				var anchors_ = content.getElementsByTagName("a");
				var anchors = [];
				for (var j=0;j<anchors_.length;j++) { anchors.push(anchors_[j]); }
				for (var j=0;j<anchors.length;j++) {
					var a = anchors[j];
					if (a.href.match(/^http/)) {
						self.processLink(a,a.href);
					}
				}
			break;
		} /* switch */
		return content;
	}

	this.simplify = self.store.simplify;
	this.getContentType = self.store.getContentType;
	this.getTitle = self.store.getTitle;
	this.getURI = self.store.getURI;

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
		self.descDiv = OAT.Dom.create("div");
		self.tabDiv.insertBefore(self.descDiv,self.tabDiv.firstChild);


		var actTab = function(index) {
			self.tabs[index].redraw();
		}
		self.tab.options.onDock = actTab;
		self.tab.options.onUnDock = actTab;
		self.tab.options.goCallback = function(oldIndex,newIndex) {
			if (OAT.AnchorData.window) { OAT.AnchorData.window.close(); }
			self.tabs[newIndex].redraw();
			self.descDiv.innerHTML = self.tabs[newIndex].description;
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
			xml += '\t<uri>'+OAT.Dom.toSafeXML(item.href)+'</uri>\n';
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
		self.store.removeAllFilters();
		var items = xmlDoc.getElementsByTagName("uri");
		for (var i=0;i<items.length;i++) {
			var item = items[i];
			var href = OAT.Xml.textValue(item);
			self.store.addURL(OAT.Dom.fromSafeXML(href));
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
			self.store.removeAllFilters();
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
