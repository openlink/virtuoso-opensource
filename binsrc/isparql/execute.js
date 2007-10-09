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

window.defaultPrefixes = [{"label":'atom', "uri":'http://atomowl.org/ontologies/atomrdf#'},
						 {"label":'foaf', "uri":'http://xmlns.com/foaf/0.1/'},
						 {"label":'owl', "uri":'http://www.w3.org/2002/07/owl#'},
						 {"label":'sioct', "uri":'http://rdfs.org/sioc/types#'},
						 {"label":'sioc', "uri":'http://rdfs.org/sioc/ns#'},
						 {"label":'ibis', "uri":'http://purl.org/ibis#'},
						 {"label":'ical', "uri":'http://www.w3.org/2002/12/cal/icaltzd#'},
						 {"label":'mo', "uri":'http://purl.org/ontology/mo/'},
						 {"label":'annotation', "uri":'http://www.w3.org/2000/10/annotation-ns#'},
						 {"label":'rdfs', "uri":'http://www.w3.org/2000/01/rdf-schema#'},
						 {"label":'rdf', "uri":'http://www.w3.org/1999/02/22-rdf-syntax-ns#'},
						 {"label":'dcterms', "uri":'http://purl.org/dc/terms/'},
						 {"label":'dc', "uri":'http://purl.org/dc/elements/1.1/'},
						 {"label":'cc', "uri":'http://web.resource.org/cc/'},
						 {"label":'geo', "uri":'http://www.w3.org/2003/01/geo/wgs84_pos#'},
						 {"label":'rss', "uri":'http://purl.org/rss/1.0/'},
						 {"label":'skos', "uri":'http://www.w3.org/2004/02/skos/core#'},
						 {"label":'vs', "uri":'http://www.w3.org/2003/06/sw-vocab-status/ns#'},
						 {"label":'wot', "uri":'http://xmlns.com/wot/0.1/',"hidden":1},
						 {"label":'xhtml', "uri":'http://www.w3.org/1999/xhtml',"hidden":1},
						 {"label":'dataview', "uri":'http://www.w3.org/2003/g/data-view#',"hidden":1},
						 {"label":'xsd', "uri":'http://www.w3.org/2001/XMLSchema#',"hidden":1}];


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
		backupQuery:false, /* to be execude if original fails */
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
	this.mini = false;
	
	this.init = function() {
		this.dom.result = OAT.Dom.create("div");
		this.dom.request = OAT.Dom.create("pre"); 
		this.dom.response = OAT.Dom.create("pre");
		this.dom.query = OAT.Dom.create("pre");
		this.dom.select = OAT.Dom.create("select");
		OAT.Dom.option("Human readable","0",this.dom.select);
		OAT.Dom.option("Machine readable","1",this.dom.select);
		
		var tabs1 = ["Result","SPARQL Params","Response","Query"];
		var tabs2 = [self.dom.result,self.dom.request,self.dom.response,self.dom.query];
		self.dom.tab = OAT.Dom.create("div",{padding:"5px",backgroundColor:"#fff"});
		self.dom.ul = OAT.Dom.create("ul",{},"tabres");
		self.tab = new OAT.Tab(self.dom.tab,{dockMode:true,dockElement:self.dom.ul});
		for (var i=0;i<tabs1.length;i++) {
			var li = OAT.Dom.create("li");
			self.dom.ul.appendChild(li);
			li.innerHTML = tabs1[i];
			self.tab.add(li,tabs2[i]);
		}
		if (self.options.div) { 
			OAT.Dom.clear(self.options.div);
			OAT.Dom.append([self.options.div,self.dom.select,OAT.Dom.create("br")]);
			OAT.Dom.append([self.options.div,self.dom.ul,self.dom.tab]); 
		}
		self.initNav();
		
		OAT.Event.attach(self.dom.select,"change",function(){
			if (self.cacheIndex > -1) { self.draw(); }
		});
		OAT.Event.attach(self.dom.check,"click",function(){
			if (self.cacheIndex > -1) { self.draw(); }
		});
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
		if (opts.defaultGraph && !opts.query.match(/from *</i)) { paramsObj["default-graph-uri"] = opts.defaultGraph; }
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
		
		var entCount = 0;
		var entities = {};
		var q = self.cache[self.cacheIndex].opts.query.replace(/[\r\n]/g," ");
		var where = q.match(/where *{(.*)}/i);
		if (where) {
			var regs = where[1].match(/<[^>]+>/g);
			if (regs) for (var i=0;i<regs.length;i++) {
				var entity = regs[i].substring(1,regs[i].length-1);
				if (!(entity in entities)) { 
					entities[entity] = 1; 
					entCount++;
				}
			}
		}
		
		var h = OAT.Dom.create("h3");
		h.innerHTML = "This page is about:";
		if (entCount) {
			var ul = OAT.Dom.create("ul");
			for (var p in entities) {
				var li = OAT.Dom.create("li");
				ul.appendChild(li);
				li.innerHTML = p;
			}
			OAT.Dom.append([self.dom.result,h,ul]);
		}
		
		var root = self.store.data.all[0];
		var ns_var = "http://www.w3.org/2005/sparql-results#resultVariable";
		var ns_var2 = "http://www.w3.org/2005/sparql-results#variable";
		var ns_sol = "http://www.w3.org/2005/sparql-results#solution";
		var ns_bind = "http://www.w3.org/2005/sparql-results#binding";
		var ns_val = "http://www.w3.org/2005/sparql-results#value";
		if (!ns_sol in root.preds) { return; }
		
		var grid = new OAT.Grid(self.dom.result);
		var header = root.preds[ns_var];
		if (self.dom.select.value == "1") {
			var map = {
				"hasValue":"Range",
				"isValueOf":"Domain",
				"property":"Property"
			}
			for (var i=0;i<header.length;i++) {
				if (header[i] in map) { header[i] = map[header[i]]; } 
			}
		}
		grid.createHeader(header);
		
		if (!(ns_sol in root.preds)) { return; }
		var solutions = root.preds[ns_sol];
		
		for (var i=0;i<solutions.length;i++) {
			var row = [];
			var simplified_row = [];
			for (var j=0;j<header.length;j++) { 
				row.push(""); 
				simplified_row.push(""); 
			}
			
			var sol = solutions[i];
			if (!(ns_bind in sol.preds)) { continue; }
			var bindings = sol.preds[ns_bind];
			for (var j=0;j<bindings.length;j++) {
				var val = bindings[j].preds[ns_val][0];
				var v = bindings[j].preds[ns_var2][0];
				var index = header.find(v);
				row[index] = val;
				simplified_row[index] = self.simplifyPrefix(val);
			
				if (self.dom.select.value == "0") {
				var value = simplified_row[index];
					var idx = Math.max(value.lastIndexOf("/"),value.lastIndexOf("#"),value.lastIndexOf(":"));
					var simple = value.substring(idx+1);
					if (simple == "this") {
						var idx1 = Math.max(value.lastIndexOf("/"));
						var idx2 = Math.max(value.lastIndexOf("#"));
						var simple = value.substring(idx1+1,idx2);
					}
					simplified_row[index] = simple;
				}
			}
			
			grid.createRow(simplified_row);
			for (var j=0;j<row.length;j++) {
				var val = row[j];
				if (val.match(/^(http|urn|doi)/i)) { /* a++ */
					var a = OAT.Dom.create("a");
					a.innerHTML = simplified_row[j];
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
		for (var i=0;i<parts.length;i++) { self.dom.request.innerHTML += OAT.Xml.escape(parts[i])+"\n"; }
		self.dom.query.innerHTML = OAT.Xml.escape(opts.query);

		if (wasError) {
			/* trap http codes */
			var r = data.match(/Error (..[0-9]{3})/);
			if (r) {
				self.dom.result.innerHTML = "SPARQL Processor error "+r[1];
				if (r[1] == "HT404") { self.dom.result.innerHTML += ": Resource not found"; }
				self.dom.result.innerHTML += ". Check your query and try again.";
			} else {
			self.dom.result.innerHTML = OAT.Xml.escape(data);
			}
			self.dom.response.innerHTML = OAT.Xml.escape(data);
		} else {
			var txt = OAT.Xml.serializeXmlDoc(data);
			txt = OAT.Xml.escape(txt);
			self.dom.response.innerHTML = txt;

			if (opts.query.match(/describe/i) || opts.query.match(/construct/i)) {
				/* rdf mini */
				var lastIndex = 0;
				var tabs = [
					["navigator","Navigator"],
					["browser","Browser",{removeNS:true}],
					["triples","Raw Triples",{}],
					["svg","SVG Graph",{}],
					["images","Images",{}],
					["map","Yahoo Map",{provider:OAT.MapData.TYPE_Y}] 
				];
				
				if(self.mini) {
					lastIndex = self.mini.select.selectedIndex;
				}
				self.mini = new OAT.RDFMini(self.dom.result,{tabs:tabs,showSearch:false});
				self.mini.processLink = self.processLink;
				self.mini.store.addXmlDoc(data);
				self.mini.select.selectedIndex = lastIndex;
				self.mini.redraw();
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
	
	this.simplifyPrefix = function(str) {
		var plist = window.defaultPrefixes;
		var s = str;
		if (!s) { return; }
		if (s.charAt(0) == "<") { s = s.substring(1,s.length-1); }
		
		for (var i=0;i<plist.length;i++) {
			var prefix = plist[i];
			if (s.substring(0,prefix.uri.length) == prefix.uri) {
				return prefix.label + ":" + s.substring(prefix.uri.length); 
			}
		}
		return s;
	}
	
	this.processLink = function(domNode,href) {
		var dereferenceRef = function() {
			var cache = self.cache[self.cacheIndex];

			var q = 'define get:soft "replacing" \n'+
					'define input:same-as "yes" \n'+
					'define input:grab-seealso <http://www.w3.org/2002/07/owl#sameAs> \n'+
					'DESCRIBE <'+href+'>';
			var bq = 'DESCRIBE <'+href+'>';
			var o = {};
			for (var p in cache.opts) { o[p] = cache.opts[p]; }
			o.defaultGraph = false;
			o.query = q;
			o.backupQuery = bq;
			self.execute(o);
		}
	
		var genRef = function() {
			var ul = OAT.Dom.create("ul",{marginLeft:"20px",marginTop:"10px"});

			var li = OAT.Dom.create("li");
			var a = OAT.Dom.create("a");
			a.innerHTML = "Data Link";
			a.href = "#";
			OAT.Dom.attach(a,"click",dereferenceRef);
			var li = OAT.Dom.create("li");
			OAT.Dom.append([ul,li],[li,a]);

			var li = OAT.Dom.create("li");
			var a = OAT.Dom.create("a");
			a.innerHTML = "Document Link";
			a.href = href;
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
		
		var img1 = OAT.Dom.create("img",{paddingLeft:"3px",cursor:"pointer"});
		img1.title = "Data Link";
		img1.src = OAT.Preferences.imagePath + "RDF_rdf.png";
		OAT.Dom.attach(img1,"click",dereferenceRef);

		var a = OAT.Dom.create("a",{paddingLeft:"3px"});
		var img2 = OAT.Dom.create("img",{border:"none"});
		img2.src = OAT.Preferences.imagePath + "RDF_xhtml.gif";
		a.title = "Document Link";
		a.appendChild(img2);
		a.target = "_blank";
		a.href = href;
		
		domNode.parentNode.appendChild(img1);
		domNode.parentNode.appendChild(a);
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
			if (txt.match(/SP031/) && optObj.backupQuery) {
				var newO = {};
				for (var p in optObj) { newO[p] = optObj[p]; }
				newO.query = newO.backupQuery;
				newO.backupQuery = false;
				self.execute(newO);
			} else {
			if (opts.onerror) { opts.onerror(txt); }
			self.addResponse(request,optObj,1,txt);
		}
		}
		var o = {
			type:OAT.AJAX.TYPE_XML,
			onstart:opts.onstart,
			onend:opts.onend,
			onerror:onerror
		}
		
		/* fix remote endpoint: */
		if (opts.endpoint.match(/^http/i)) {
			opts.endpoint = "/proxy?url="+encodeURIComponent(opts.endpoint);
		}
		
		OAT.AJAX.POST(opts.endpoint,request,callback,o);
	}
	
	self.init();
}
