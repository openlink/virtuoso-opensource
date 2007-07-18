/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2007 OpenLink Software
 *
 *  See LICENSE file for details.
 *
 */

/*
	iSPARQL query executer & visualizer
*/

var QueryExec = function(optObj) {
	var self = this;
	
	this.options = {
		showNav:false,
		div:false,
		virtuoso:false,
		executeCallback:false
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }
	
	this.queryOptions = {
		/* ajax */
		onstart:false,
		onend:false,
		onerror:false,
		
		endpoint:false,
		query:false,
		defaultGraph:false,
		namedGraphs:[],
		sponge:false,
		limit:false
	}
	
	this.cache = [];
	this.cacheIndex = -1;
	this.dom = {};
	this.tab = false;
	this.store = new OAT.RDFStore(false);
	
	this.init = function() {
		this.dom.result = OAT.Dom.create("div");
		this.dom.request = OAT.Dom.create("pre"); 
		this.dom.response = OAT.Dom.create("pre");
		this.dom.query = OAT.Dom.create("pre");
		var tabs1 = ["Result","Request","Response","Query"];
		var tabs2 = [self.dom.result,self.dom.request,self.dom.response,self.dom.query];
		self.dom.tab = OAT.Dom.create("div",{padding:"5px",backgroundColor:"#fff"});
		self.dom.ul = OAT.Dom.create("ul",{},"tabres");
		self.tab = new OAT.Tab(self.dom.tab);
		for (var i=0;i<tabs1.length;i++) {
			var li = OAT.Dom.create("li");
			self.dom.ul.appendChild(li);
			li.innerHTML = tabs1[i];
			self.tab.add(li,tabs2[i]);
		}
		if (self.options.div) { 
			OAT.Dom.clear(self.options.div);
			OAT.Dom.append([self.options.div,self.dom.ul,self.dom.tab]); 
		}
		
		self.initNav();
	}
	
	this.initNav = function() {
		var ip = OAT.Preferences.imagePath;
		var b = ip+"Blank.gif";
		self.dom.first = OAT.Dom.create("li",{},"nav");
		self.dom.prev = OAT.Dom.create("li",{},"nav");
		self.dom.next = OAT.Dom.create("li",{},"nav");
		self.dom.last = OAT.Dom.create("li",{},"nav");
		self.dom.first.appendChild(OAT.Dom.image(ip+"RDF_first.png",b,16,16));
		self.dom.prev.appendChild(OAT.Dom.image(ip+"RDF_prev.png",b,16,16));
		self.dom.next.appendChild(OAT.Dom.image(ip+"RDF_next.png",b,16,16));
		self.dom.last.appendChild(OAT.Dom.image(ip+"RDF_last.png",b,16,16));
		self.dom.first.title = "First";
		self.dom.prev.title = "Back";
		self.dom.next.title = "Forward";
		self.dom.last.title = "Last";
		OAT.Dom.append([self.dom.ul,self.dom.first,self.dom.prev,self.dom.next,self.dom.last]);
		OAT.Dom.attach(self.dom.first,"click",function(){
			if (self.cacheIndex > 0) { 
				self.cacheIndex = 0;
				self.draw() 
			}
		});
		OAT.Dom.attach(self.dom.prev,"click",function(){
			if (self.cacheIndex > 0) { 
				self.cacheIndex--;
				self.draw();
			}
		});
		OAT.Dom.attach(self.dom.next,"click",function(){
			if (self.cacheIndex > -1 && self.cacheIndex < self.cache.length-1) { 
				self.cacheIndex++;
				self.draw();
			}
		});
		OAT.Dom.attach(self.dom.last,"click",function(){
			if (self.cacheIndex > -1 && self.cacheIndex < self.cache.length-1) { 
				self.cacheIndex = self.cache.length-1;
				self.draw();
			}
		});
		self.refreshNav();
	}
	
	this.refreshNav = function() {
		var activate = function(elm) {
			OAT.Style.opacity(elm,1);
			elm.style.cursor = "pointer";
		}
		var deactivate = function(elm) {
			OAT.Style.opacity(elm,0.3);
			elm.style.cursor = "default";
		}
		if (self.cacheIndex > 0) {
			activate(self.dom.first);
			activate(self.dom.prev);
		} else {
			deactivate(self.dom.first);
			deactivate(self.dom.prev);
		}
		
		if (self.cacheIndex > -1 && self.cacheIndex < self.cache.length-1) {
			activate(self.dom.next);
			activate(self.dom.last);
		} else {
			deactivate(self.dom.next);
			deactivate(self.dom.last);
		}
	}
	
	this.isNew = function(query) {
		if (self.cacheIndex == -1) { return true; }
		var cache = self.cache[self.cacheIndex];
		return (cache.opts.query != query);
	}
	
	this.buildRequest = function(opts) {
		var paramsObj = {};
		paramsObj["query"] = opts.query;
		paramsObj["format"] = "application/rdf+xml";
		if (opts.defaultGraph) { paramsObj["default-graph-uri"] = opts.defaultGraph; }
		if (opts.limit) { paramsObj["maxrows"] = opts.limit; }
		if (opts.sponge && self.options.virtuoso) { paramsObj["should-sponge"] = opts.sponge; }

		var arr = [];
		for (var p in paramsObj) {
			arr.push(p+"="+encodeURIComponent(paramsObj[p]));
		}
		for (var i=0;i<opts.namedGraphs.length;i++) {
			arr.push("named-graph-uri="+encodeURIComponent(opts.namedGraphs[i]));
		}
		return arr.join("&");
	}
	
	this.addResponse = function(request,opts,wasError,data) { /* someting arrived. maybe cache and visualize */
		if (OAT.AnchorData.window) { OAT.AnchorData.window.close(); }
		if (self.isNew(opts.query)) {
			var cache = {
				opts:opts,
				wasError:wasError,
				request:request,
				data:data
			}
			self.cache.push(cache);
			self.cacheIndex = self.cache.length-1;
		}
		self.draw();
	}
	
	this.drawTable = function() {
		OAT.Dom.clear(self.dom.result);
		var root = self.store.data.all[0];
		var ns_var = "http://www.w3.org/2005/sparql-results#resultVariable";
		var ns_var2 = "http://www.w3.org/2005/sparql-results#variable";
		var ns_sol = "http://www.w3.org/2005/sparql-results#solution";
		var ns_bind = "http://www.w3.org/2005/sparql-results#binding";
		var ns_val = "http://www.w3.org/2005/sparql-results#value";
		if (!ns_sol in root.preds) { return; }
		
		var grid = new OAT.Grid(self.dom.result);
		var header = root.preds[ns_var];
		grid.createHeader(header);
		
		if (!(ns_sol in root.preds)) { return; }
		var solutions = root.preds[ns_sol];
		
		for (var i=0;i<solutions.length;i++) {
			var row = [];
			for (var j=0;j<header.length;j++) { row.push(""); }
			
			var sol = solutions[i];
			var bindings = sol.preds[ns_bind];
			for (var j=0;j<bindings.length;j++) {
				var val = bindings[j].preds[ns_val][0];
				var v = bindings[j].preds[ns_var2][0];
				var index = header.find(v);
				row[index] = val;
			}
			grid.createRow(row);
			for (var j=0;j<row.length;j++) {
				var val = row[j];
				if (val.match(/^http/i)) { /* a++ */
					var a = OAT.Dom.create("a");
					a.innerHTML = val;
					a.href = "#";
					var v = grid.rows[grid.rows.length-1].cells[j].value;
					OAT.Dom.clear(v);
					OAT.Dom.append([v,a]);
					self.processLink(a,val);
				}
			}
		}
	}
	
	this.draw = function() {
		var item = self.cache[self.cacheIndex];
		var opts = item.opts;
		var request = item.request;
		var wasError = item.wasError;
		var data = item.data;
		
		if (self.options.executeCallback) { self.options.executeCallback(opts.query); }
		
		self.dom.request.innerHTML = "";
		var r = decodeURIComponent(request);
		var parts = r.split("&");
		for (var i=0;i<parts.length;i++) { self.dom.request.innerHTML += parts[i]+"\n"; }
		self.dom.query.innerHTML = OAT.Xml.escape(opts.query);

		if (wasError) {
			self.dom.result.innerHTML = data;
			self.dom.response.innerHTML = data;
		} else {
			var txt = OAT.Xml.serializeXmlDoc(data);
			txt = OAT.Xml.escape(txt);
			self.dom.response.innerHTML = txt;

			if (opts.query.match(/describe/i) || opts.query.match(/construct/i)) {
				/* rdf mini */
				var tabs = [
					["navigator","Navigator"],
					["browser","Browser",{removeNS:true}],
					["triples","Raw Triples",{}],
					["svg","SVG Graph",{}]
				];
				var mini = new OAT.RDFMini(self.dom.result,{tabs:tabs,showSearch:false});
				mini.processLink = self.processLink;
				mini.store.addXmlDoc(data);
			} else {
				/* own table */
				self.store.clear();
				self.store.addXmlDoc(data);
				self.drawTable();
			}
		}
		
		self.tab.go(0);
		self.refreshNav();
	}
	
	this.processLink = function(domNode,href) {
		var dereferenceRef = function() {
			var cache = self.cache[self.cacheIndex];
			var q = "SELECT ?s, ?p, ?o \n"+
					"FROM <"+href+">\n"+
					"WHERE {?s ?p ?o}";
			var o = {};
			for (var p in cache.opts) { o[p] = cache.opts[p]; }
			o.query = q;
			self.execute(o);
 		}
		var exploreRef = function() {
			var cache = self.cache[self.cacheIndex];
			var q = "SELECT ?property ?hasValue ?isValueOf\n"+
					"WHERE {\n"+
					"{ <"+href+"> ?property ?hasValue }\n"+
					"UNION\n"+
					"{ ?isValueOf ?property <"+href+"> }\n" +
					"} ";
			var o = {};
			for (var p in cache.opts) { o[p] = cache.opts[p]; }
			o.query = q;
			self.execute(o);
		}
	
		var genRef = function() {
			var ul = OAT.Dom.create("ul",{paddingLeft:"20px",marginLeft:"0px"});

			var a = OAT.Dom.create("a");
			a.innerHTML = "Dereference";
			a.href = "#";
			OAT.Dom.attach(a,"click",dereferenceRef);
			var li = OAT.Dom.create("li");
			OAT.Dom.append([ul,li],[li,a]);

			var a = OAT.Dom.create("a");
			a.innerHTML = "Explore";
			a.href = "#";
			OAT.Dom.attach(a,"click",exploreRef);
			var li = OAT.Dom.create("li");
			OAT.Dom.append([ul,li],[li,a]);

			var a = OAT.Dom.create("a");
			a.innerHTML = "(X)HTML Page Open";
			a.href = href;
			var li = OAT.Dom.create("li");
			OAT.Dom.append([ul,li],[li,a]);
			
			return ul;
		}
			
		var obj = {
			title:"URL",
			content:genRef,
			width:200,
			height:100,
			result_control:false,
			activation:"click"
		};
		OAT.Anchor.assign(domNode,obj);
	}
	
	this.execute = function(optObj) {
		var opts = {};
		for (var p in self.queryOptions) { opts[p] = self.queryOptions[p]; } /* copy of defaults */
		for (var p in optObj) { opts[p] = optObj[p]; }
		
		var request = self.buildRequest(opts);
		var callback = function(data) {
			self.addResponse(request,optObj,0,data);
		}
		var onerror = function(xhr) {
			var txt = xhr.getResponseText();
			if (opts.onerror) { opts.onerror(txt); }
			self.addResponse(request,optObj,1,txt);
		}
		var o = {
			type:OAT.AJAX.TYPE_XML,
			onstart:opts.onstart,
			onend:opts.onend,
			onerror:onerror
		}
		OAT.AJAX.POST(opts.endpoint,request,callback,o);
	}
	
	self.init();
}
