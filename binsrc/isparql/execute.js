/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2009 OpenLink Software
 *
 *  See LICENSE file for details.
 *
 */

/*
	iSPARQL query executer & visualizer
*/

// XXX move defaultPrefixes to be handled by defaults.js

window.defaultPrefixes = [
				 		 {"label":'foaf', "uri":'http://xmlns.com/foaf/0.1/'},
						 {"label":'owl', "uri":'http://www.w3.org/2002/07/owl#'},
						 {"label":'sioct', "uri":'http://rdfs.org/sioc/types#'},
						 {"label":'sioc', "uri":'http://rdfs.org/sioc/ns#'},
						 {"label":'ibis', "uri":'http://purl.org/ibis#',"hidden":1},
						 {"label":'conf', "uri":'http://www.mindswap.org/~golbeck/web/www04photo.owl#'},
						 {"label":'scot', "uri":'http://scot-project.org/scot/ns'},
						 {"label":'ical', "uri":'http://www.w3.org/2002/12/cal/icaltzd#'},
						 {"label":'mo', "uri":'http://purl.org/ontology/mo/'},
						 {"label":'annotation', "uri":'http://www.w3.org/2000/10/annotation-ns#'},
						 {"label":'rdfs', "uri":'http://www.w3.org/2000/01/rdf-schema#'},
						 {"label":'rdf', "uri":'http://www.w3.org/1999/02/22-rdf-syntax-ns#'},
						 {"label":'dcterms', "uri":'http://purl.org/dc/terms/'},
						 {"label":'dc', "uri":'http://purl.org/dc/elements/1.1/'},
						 {"label":'cc', "uri":'http://web.resource.org/cc/'},
						 {"label":'geo', "uri":'http://www.w3.org/2003/01/geo/wgs84_pos#'},
    {"label":'georss',     "uri":'http://www.georss.org/georss/'},
						 {"label":'rss', "uri":'http://purl.org/rss/1.0/'},
						 {"label":'skos', "uri":'http://www.w3.org/2008/05/skos#'},
						 {"label":'vs', "uri":'http://www.w3.org/2003/06/sw-vocab-status/ns#'},
						 {"label":'opo',"uri":'http://ggg.milanstankovic.org/opo/ns/'},
						 {"label":'nco',"uri":'http://www.semanticdesktop.org/ontologies/nco/'},
						 {"label":'lsdis',"uri":'http://lsdis.cs.uga.edu/projects/meteor-s/wsdl-s/ontologies/LSDIS_FInance.owl'},
						 {"label":'nao',"uri":'http://www.semanticdesktop.org/ontologies/nao/'},
						 {"label":'cohere',"uri":'http://cohere.open.ac.uk/ontology/cohere.owl#'},
						 {"label":'nfo',"uri":'http://www.semanticdesktop.org/ontologies/nfo/'},
						 {"label":'nmo',"uri":'http://www.semanticdesktop.org/ontologies/nmo/'},
						 {"label":'nie',"uri":'http://www.semanticdesktop.org/ontologies/nie/'},
						 {"label":'nid3',"uri":'http://www.semanticdesktop.org/ontologies/nid3/'},
    {"label":'kuaba',      "uri":'http://www.tecweb.inf.puc-rio.br/ontologies/kuaba/'},
						 {"label":'wot', "uri":'http://xmlns.com/wot/0.1/',"hidden":1},
						 {"label":'xhtml', "uri":'http://www.w3.org/1999/xhtml',"hidden":1},
						 {"label":'atom', "uri":'http://atomowl.org/ontologies/atomrdf#',"hidden":1},
						 {"label":'dataview', "uri":'http://www.w3.org/2003/g/data-view#',"hidden":1},
    {"label":'xsd', "uri":'http://www.w3.org/2001/XMLSchema#',"hidden":1},
    {"label":'gr',         "uri":'http://purl.org/goodrelations/v1#'},
    {"label":'dbo',        "uri":'http://dbpedia.org/ontology/'},
    {"label":'dbpprop',    "uri":'http://dbpedia.org/property/'},
    {"label":'dbpedia',    "uri":'http://dbpedia.org/resource/'}
];

iSPARQL.ResultType = {
    RESSET: 0,
    GRAPH: 1,
    ERROR: 666
};

iSPARQL.CircularBuffer = function (len, initList) {
    var self = this;
    this._length = len;
    this._buf = [];
    this._ptr = 0;
    this._fill = 0;

    this.append = function (item) {
	if (self._fill < self._length) {
	    self._buf.append(item);
	    self._fill++;
	    self._ptr++;
	    return item;
	}
	if (self._ptr == self._length)
	    (self._ptr = 0)

	self._buf[self._ptr] = item;
	self._ptr++;
	return item;
    }

    this.clear = function () {
	self._buf = [];
	self._fill = self._ptr = 0;
    }

    this.appendList = function (list) {
	for (var i=0;i<list.length;i++)
	    self.append (list[i]);
    }

    this.getFill = function () {
	return self._fill;
    }

    this.getLength = this.getFill;

    this.getNth = function (n)
    {
	return self._buf[(self._ptr+n)%self._fill];
    }

    this.putNth = function (n, item) {
	self._buf[(self._ptr+n)%self._fill] = item;
	return item;
    }

    this.toList = function () {
	var retList = [];

	if (self._buf.length == 0) 
	    return retList;

	for (var i=0;i<self._fill;i++) {
	    retList.append(self.getNth(i));
	}
	return retList;
    }

    this.find = function (item) {
	for (i=0;i<self._fill;i++) {
	    if (self.getNth(i) == item)
		return i;
	}
	return -1;
    }

    if (isArray(initList)) {
	if (initList.length <= self._length) {
	    self._buf = initList;
	    self._fill = initList.length;
	    self._ptr = self._fill;
	    return;
	} else {
	    self._buf = initList.slice (initList.length - self._length, initList.length-1);
	}
    }
}

var QueryExec = function(optObj) {
	var self = this;

	this.options = {
		showNav:false,
		div:false,
		virtuoso:false,
		executeCallback:false
    };

	for (var p in optObj) { self.options[p] = optObj[p]; }

	this.queryOptions = {
		/* ajax */
		onstart:false,
		onend:false,
		onerror:false,

		endpoint:false,
		query:false,
		backupQuery:false, /* to be executed if original fails */
		defaultGraph:false,
		namedGraphs:[],
		sponge:false,
	maxrows:false,
	sourceQuery:false /* before macro expansion */
    };

	this.cache = [];
	this.cacheIndex = -1;
	this.dom = {};
	this.tab = false;
	this.mini = false;
    	this.miniplnk = false;
    	this.mRDFCtr = false;

	this.init = function() {
		this.dom.result = OAT.Dom.create("div");
		this.dom.request = OAT.Dom.create("div", {className:'ep_request'}); 
		this.dom.response = OAT.Dom.create("pre",{className:'ep_response'});
		this.dom.query = OAT.Dom.create("pre");
//	this.dom.select = OAT.Dom.create("select");
//	OAT.Dom.option("Machine-readable","1",this.dom.select);
//	OAT.Dom.option("Human-readable","0",this.dom.select);

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
	    OAT.Dom.append([self.options.div,/*self.dom.select,*/OAT.Dom.create("br")]);
			OAT.Dom.append([self.options.div,self.dom.ul,self.dom.tab]);
		}
		self.initNav();

		OAT.Event.attach(self.dom.select,"change",function(){
			if (self.cacheIndex > -1) { self.draw(); }
		});
		OAT.Event.attach(self.dom.check,"click",function(){
			if (self.cacheIndex > -1) { self.draw(); }
		});

	// Add well-known prefixes in global IRIDB

	iSPARQL.StatusUI.statMsg ("Seeding IRIDB &#8230;");

	if (!!OAT.IRIDB) {
	    for (var i=0;i<window.defaultPrefixes.length;i++)
		OAT.IRIDB.insertIRI (window.defaultPrefixes[i].uri, window.defaultPrefixes[i].label);
	}

    };

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
		self.dom.pos_ind = OAT.Dom.create("li",{},"nav");
		
		OAT.Dom.append([self.dom.ul,self.dom.first,self.dom.prev,self.dom.pos_ind,self.dom.next,self.dom.last]);
		
		OAT.Event.attach(self.dom.first,"click",function(){
			if (self.cacheIndex > 0) {
				var old = self.cacheIndex;
				self.cacheIndex = 0;
				self.nav(old);
			}
		});
		
		OAT.Event.attach(self.dom.prev,"click",function(){
			if (self.cacheIndex > 0) {
				var old = self.cacheIndex;
				self.cacheIndex--;
				self.nav(old);
			}
		});
		
		OAT.Event.attach(self.dom.next,"click",function(){
			if (self.cacheIndex > -1 && self.cacheIndex < self.cache.length-1) {
				var old = self.cacheIndex;
				self.cacheIndex++;
				self.nav(old);
			}
		});
		
		OAT.Event.attach(self.dom.last,"click",function(){
			if (self.cacheIndex > -1 && self.cacheIndex < self.cache.length-1) {
				var old = self.cacheIndex;
				self.cacheIndex = self.cache.length-1;
				self.nav(old);
			}
		});
		self.refreshNav();
    };

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
		self.dom.pos_ind.innerHTML = 
			'<span class="nav_pos_ind"><span class="nav_cache_pos">' + 
			(self.cacheIndex + 1) + 
			'</span>(<span class="nav_cache_max">' +
			self.cache.length +
			'</span>)</span>';
    };

    this.isNew = function(opts) {
		if (self.cacheIndex == -1) { return true; }
		var cache = self.cache[self.cacheIndex];
	return (cache.opts.query != opts.query || 
		cache.opts.endpoint != opts.endpoint || 
		cache.opts.defaultGraph != opts.defaultGraph ||
	        cache.opts.maxrows != opts.maxrows ||
	        cache.opts.namedGraphs != opts.namedGraphs ||
	        cache.opts.pragmas != opts.pragmas);
    };

	this.buildRequest = function(opts) {
		var paramsObj = {};

		if (opts.defaultGraph && !opts.query.match(/from *</i)) { paramsObj["default-graph-uri"] = opts.defaultGraph; }
	if (opts.maxrows && opts.query && !opts.query.match(/limit *[0-9].*/i)) { paramsObj["maxrows"] = opts.maxrows; }
		if (opts.sponge && self.options.virtuoso) { paramsObj["should-sponge"] = opts.sponge; }

		var pragmas = [];
	
		if (opts.pragmas) {
			for (var i=0;i<opts.pragmas.length;i++) {
				var pragma = opts.pragmas[i];
				var name = pragma[0];
				var values = pragma[1];
				for(var j=0;j<values.length;j++) { pragmas.push(name+" "+values[j]); }
			}
		}

		paramsObj["query"] = pragmas.join('\n') + '\n' + opts.query;

		var arr = [];
		for (var p in paramsObj) {
			arr.push(p+"="+encodeURIComponent(paramsObj[p]));
		}
		if (opts.namedGraphs) {
			for (var i=0;i<opts.namedGraphs.length;i++) {
				arr.push("named-graph-uri="+encodeURIComponent(opts.namedGraphs[i]));
			}
		}

	if (opts.endpoint.match(/^http/i)) {
	    var req = "url=" + encodeURIComponent(opts.endpoint + "?" + arr.join ("&"));
	    opts.endpoint = "/proxy";
	    return req;
	}

	 arr.push (encodeURIComponent("format=application/rdf+xml"));
		return arr.join("&");
    };

    this.resultType = function(data) {
		if (data.documentElement.localName == "sparql")
			return iSPARQL.ResultType.RESSET;
		if (data.documentElement.localName == "RDF")
			return iSPARQL.ResultType.GRAPH;
    };
	
    //
    // Cache incoming result set or graph
    //
	
     this.addResponse = function(request,opts,wasError,data) { /* Cache and visualize */
		if (OAT.AnchorData.window) { OAT.AnchorData.window.close(); }

		var rt;
        var to = false;
		
		if (!wasError) 
			rt = self.resultType (data);
		else {
			rt = iSPARQL.ResultType.ERROR;
			if (data.match (/Error SR171/))
				to = true;
		}
		
	if (self.isNew(opts) || (self.cache[self.cacheIndex].wasError && !wasError)) {
			var cacheItem = {
				resType: rt,
				wasError:wasError,
				timeOut:to,
				opts:opts,
				request:request,
				data:data,
				txt:OAT.Xml.serializeXmlDoc (data),
				store: new OAT.RDFStore(),
				dom: {}
			}
			
			cacheItem.dom.query_c    = OAT.Dom.create ("div",{className: "query_c"});
			cacheItem.dom.result_c   = OAT.Dom.create ("div",{className: "result_c"});
			cacheItem.dom.request_c  = OAT.Dom.create ("div",{className: "request_c"});
			cacheItem.dom.response_c = OAT.Dom.create ("div",{className: "response_c"});
			
			if (rt == iSPARQL.ResultType.GRAPH) {
				cacheItem.store.addXmlDoc(data);
			}

			var old = self.cacheIndex;
			self.cache.push(cacheItem);
			self.cacheIndex = self.cache.length-1;

		}
		self.draw();
		if (old>=0) self.nav(old);
    };

    this.makeMiniRDFPlinkURI = function (caller,msg,o) {
	var item = self.cache[self.cacheIndex];
	var opts = item.opts;
	var request = item.request;
	var plnk = self.miniplnk;

	var nloca = document.location;

	var xparm = "?query=" + encodeURIComponent(opts.query);

	if (opts.endpoint)
	    xparm = xparm + "&endpoint="  + opts.endpoint;
		xparm = xparm + "&resultview=" + item.mini.options.tabs[o.tabIndex][0];
	xparm += "&maxrows=" + (opts.maxrows ? opts.maxrows : "");

	plnk.target = "_blank";
	plnk.href= nloca.protocol + "//" + nloca.host + "/isparql/view/" + xparm;

		if (iSPARQL.Settings.shorten_uris) 
			iSPARQL.Common.shortenURI (plnk);
				
    }

    this.parseTabIndex = function (rvVal, tabs) {
	for (var i=0;i < tabs.length;i++) {
	    if (rvVal == tabs[i][0]) return i;
	}
	return 0;
    };

    this.RESULT_TYPE = {
	URI:0,
	LITERAL:1
    }

    this.renderResultValue = function (val, opts) {
	if (val.restype == self.RESULT_TYPE.URI) {
	    var a = OAT.Dom.create("a");
			a.innerHTML = self.cache[self.cacheIndex].store.simplify (val.value);
	    a.href = val.value;
	    self.processLink(a, val.value);
	    return a;
	}
	return val.value;
    };

    //
    // return value, datatype
    // 

    this.parseSparqlResDt = function (elm) {
	var ln = OAT.Xml.localName (elm);
	var resVal = {};

	if (ln == 'uri') {
	    resVal.restype = this.RESULT_TYPE.URI;
	    resVal.datatype = '';
	}

	if (ln == 'literal') {
	    resVal.datatype = OAT.Xml.getLocalAttribute (elm, 'datatype');
	    resVal.restype = this.RESULT_TYPE.LITERAL;
	}

	resVal.value = OAT.Xml.textValue(elm);

	return resVal;
    };

    this.getSparqlRsVars = function (xmlDoc) {
	var varArr = [];

	var nodeList = 
	    xmlDoc.getElementsByTagName('variable');

	for (var i=0;i<nodeList.length;i++) {
	    var varName = nodeList[i].getAttribute ('name');
	    varArr.push (varName)
	}
	
	return varArr;
    };

    this.getSparqlResRows = function (xmlDoc) {
	var resArr = [];
	var resRows = xmlDoc.getElementsByTagName ('result');
	
	for (i=0;i<resRows.length;i++) {
	    var bindings = OAT.Xml.getElementsByLocalName (resRows[i], 'binding');
	    var procRow = {};

	    for (j=0;j<bindings.length;j++) {
		var bVarName = OAT.Xml.getLocalAttribute (bindings[j],'name');
		var bElms = OAT.Xml.childElements (bindings[j]);

		var bVar = self.parseSparqlResDt (bElms[0]);
		procRow[bVarName] = bVar;
	    }
	    resArr.push (procRow);
	}

	return resArr;
    };

    // return sparqlResultSet object
    //
    
    this.parseSparqlResultSet = function (xmlDoc) {
	
	var resSet = {};

	resSet.variables = self.getSparqlRsVars(xmlDoc);
	resSet.results = self.getSparqlResRows (xmlDoc);
	
	return resSet;
    };

    this.fixGridRow = function (grid, resSet, n) {
	for (var i=0;i<resSet.variables.length;i++) {
	    if (typeof resSet.results[n][resSet.variables[i]] != 'undefined') {
		var valObj = resSet.results[n][resSet.variables[i]];
		var val = self.renderResultValue (valObj);
		if (typeof val != 'string') {
		    var cell = grid.rows[grid.rows.length-1].cells[i].value;
		    OAT.Dom.clear (cell);
		    OAT.Dom.append ([cell, val]);
		}
	    }
	}
    };

//
// XXX produces URLs which are invalid
//
    
    this.makePivotPermalink = function (ctr) {
	var item = self.cache[self.cacheIndex];
	var opts = item.opts;

	a = OAT.Dom.create("a");
	a.innerHTML = "Make Pivot";
	var xparm = document.location.protocol + '//' + document.location.host + 
	    "/sparql/?query=" + encodeURIComponent(opts.query) + 
	    "&endpoint=" + opts.endpoint;
	xparm += "&maxrows=" + (opts.maxrows ? opts.maxrows : "");
	xparm += "&default-graph-uri=" + (opts.defaultGraph ? opts.defaultGraph : "");
	xparm += "&format=text/cxml";
	a.href = document.location.protocol + '//' + document.location.host + 
	    '/PivotViewer/' + "?url=" + encodeURIComponent(xparm);
	a.target = "_blank";
	var spc = OAT.Dom.create("span");
	spc.innerHTML = "&nbsp;";

		if (iSPARQL.Settings.shorten_uris)
			iSPARQL.Common.shortenURI (a);
		
		OAT.Dom.append([ctr,spc,a]);
		
    };

    this.makeExecPermalink = function (ctr) {
	var item = self.cache[self.cacheIndex];
	var opts = item.opts;
	var request = item.request;
	
	var execURIa = OAT.Dom.create ("a");
	execURIa.innerHTML = "Execute Permalink";
	var nloca = document.location;

	var xparm = "?query=" + encodeURIComponent(opts.query) + "&endpoint="  + opts.endpoint;
	xparm += "&maxrows=" + (opts.maxrows ? opts.maxrows : "");
	xparm += "&default-graph-uri=" + (opts.defaultGraph ? opts.defaultGraph : "");

	execURIa.href = nloca.protocol + "//" + nloca.host + "/isparql/view/" + xparm;
	
		if (iSPARQL.Settings.shorten_uris) 
			iSPARQL.Common.shortenURI (execURIa);
			
	execURIa.target = "_blank";
	
		OAT.Dom.append([ctr,execURIa]);
    };

    this.drawSparqlResultSet = function (resSet) {
		var item = self.cache[self.cacheIndex];
		self.dom.plnk_ctr = OAT.Dom.create("div", {className: "result_plnk_ctr"});

		self.makeExecPermalink (self.dom.plnk_ctr);
	
		if (iSPARQL.Settings.pivotInstalled) 
			self.makePivotPermalink(self.dom.plnk_ctr);

		var anchor_pref_ctr = OAT.Dom.create("div", {className: "anchor_pref_ctr"});
		anchor_label = OAT.Dom.create("label", {htmlFor: "anchor_pref_sel"});
		anchor_label.innerHTML = "Anchor behavior:";
		anchor_pref_sel = OAT.Dom.create ("select", {id: "anchor_pref_sel"});
		anchor_pref_sel.options.add (new Option ("Describe",0));
		anchor_pref_sel.options.add (new Option ("Get Data Items",1));
		anchor_pref_sel.options.add (new Option ("Open Web Page",2));

		OAT.Event.attach(anchor_pref_sel, 'change', function () {
			iSPARQL.Settings.anchorMode = ($('anchor_pref_sel').selectedIndex);
		});

		OAT.Dom.append ([item.dom.result_c, self.dom.plnk_ctr, anchor_pref_ctr]);
        OAT.Dom.append ([anchor_pref_ctr, anchor_label, anchor_pref_sel]);

		var grid = new OAT.Grid (item.dom.result_c);
	grid.createHeader(resSet.variables);

	for (var z=0;z<resSet.results.length;z++) {
	    var gRow = [];
	    for (var y=0;y<resSet.variables.length;y++) {
		var v;
		if (typeof resSet.results[z][resSet.variables[y]] != 'undefined')
		    v = resSet.results[z][resSet.variables[y]].value;
		else 
		    v = '';
		gRow.push(v);
	    }
	    grid.createRow (gRow);

	    // XXX: this hack because OAT.grid cannot add rows with cell values containing DOM nodes.
	    //      should add this to OAT.grid at earliest convenience

	    self.fixGridRow (grid,resSet, z);
	}
    };

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

	self.makeExecPermalink ();

		var data_root = self.cache[cacheIndex].store.data.all[0];
		var ns_var = "http://www.w3.org/2005/sparql-results#resultVariable";
		var ns_var2 = "http://www.w3.org/2005/sparql-results#variable";
		var ns_sol = "http://www.w3.org/2005/sparql-results#solution";
		var ns_bind = "http://www.w3.org/2005/sparql-results#binding";
		var ns_val = "http://www.w3.org/2005/sparql-results#value";

	if (!(ns_sol in data_root.preds)) 
	{ 
	    return; 
	}

		var grid = new OAT.Grid(self.dom.result);
	var header = data_root.preds[ns_var];
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

	if (!(ns_sol in data_root.preds)) { return; }

	var solutions = data_root.preds[ns_sol];

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

					if (!value) value = "";

					var simple = self.cache[cacheIndex].store.simplify(value);
					simplified_row[index] = simple;
				}
			}

			grid.createRow(simplified_row);
	    
			for (var j=0;j<row.length;j++) {
				var val = row[j];
				if (val.match(/^(http|urn|doi)/i)) { /* a++ */
					var a = OAT.Dom.create("a");
					a.innerHTML = simplified_row[j];
		    a.href = val;
					var v = grid.rows[grid.rows.length-1].cells[j].value;
					OAT.Dom.clear(v);
					OAT.Dom.append([v,a]);
					self.processLink(a,val);
				}
			}
		}
    };

    this.makeErrorMsg = function (data) {
	 var msg = '';
	var r = data.match(/Error (..[0-9]{3})/);
	if (r) {
	    msg="<h3>SPARQL Processor Error ("+ r[1] + ")</h3>\n"
	    if (r[1] == "HT404")
		msg += "<p>Resource not found<br/>Check your query and try again</p>";
	}
	else if (data.match(/Error HTCLI/)) {
	    msg = "<h3>Proxy connection error</h3><p>The proxy could not connect to the endpoint ";
	    msg += "<span class=\"endpoint_url\">" + self.cache[self.cacheIndex].opts.endpoint;
	    msg += "</span>. Please try again later.</p>";
	}
	 else {
	     msg =  "<h3>Error</h3>\n";
	     msg += "<p>An error occurred when executing the query</p>\n";
	 }
	 msg += "<p>See Response tab for full response from SPARQL endpoint.</p>";
	return msg;
    };

    this.makeErrorResp = function (data) {
	var txt = OAT.Xml.serializeXmlDoc(data);
	 if (txt.length == 0 || txt == false) 
	    txt = data;
	txt = "<pre>"+txt+"</pre>";
	return txt;
    };

    this.nav = function (old) {
		var item = self.cache[self.cacheIndex];
		var oldItem = self.cache[old];

//		lastIndex = item.mini.select.selectedIndex;

/*
		self.dom.result.replaceChild (oldItem.dom.result_c, item.dom.result_c);
		self.dom.request.replaceChild (oldItem.dom.request_c, item.dom.request_c);
		self.dom.query.replaceChild (oldItem.dom.query_c, item.dom.query_c);
		self.dom.response.replaceChild (oldItem.dom.response_c, item.dom.response_c);
*/
		OAT.Dom.clear(self.dom.result);
		OAT.Dom.clear(self.dom.request);
		OAT.Dom.clear(self.dom.query);
		OAT.Dom.clear(self.dom.response);

		OAT.Dom.append ([self.dom.result, item.dom.result_c],
						[self.dom.request, item.dom.request_c],
						[self.dom.query, item.dom.query_c],
						[self.dom.response, item.dom.response_c]);

		self.refreshNav();
	};

	// called only when new result is received

    this.draw = function(refresh) {
		var item = self.cache[self.cacheIndex];
		var opts = item.opts;
		var request = item.request;
		var wasError = item.wasError;
		var data = item.data;

		if (self.options.executeCallback) { self.options.executeCallback(item); }

		// Generate request page

		var r = decodeURIComponent(request);
		var parts = r.split("&");
		var req = OAT.Dom.create("pre");

		OAT.Dom.append([item.dom.request_c, req]);

		for (var i=0;i<parts.length;i++) { req.innerHTML += OAT.Xml.escape(parts[i])+"\n"; }

		// Generate query page

		var a = OAT.Dom.create("a");
		a.innerHTML = "Query Permalink";
	var xparm = "?query=" + encodeURIComponent(opts.query) + "&endpoint=" + opts.endpoint;
	xparm += "&maxrows=" + (opts.maxrows ? opts.maxrows : "");
	xparm += "&default-graph-uri=" + (opts.defaultGraph ? opts.defaultGraph : "");
	a.href = document.location.protocol + '//' + document.location.host + '/isparql/' + xparm;
		a.target = "_blank";

		if (iSPARQL.Settings.shorten_uris)
			iSPARQL.Common.shortenURI(a);
		
		var q = OAT.Dom.create("pre");
		q.innerHTML = OAT.Xml.escape(opts.query);

		OAT.Dom.append([item.dom.query_c,a,q]);
		

	if (wasError && !data.match(/Error SR171/)) { // Timeout SR171 means there may be data to display
			/* trap http codes */
			item.dom.result_c.innerHTML = self.makeErrorMsg (data);
			item.dom.response_c.innerHTML = self.makeErrorResp (data);
		} 
		else {

			// Generate Response page 

			var xmlTxt = item.txt; // Used if we have to draw a result set - need to remove namespace, etc.
			var txt = OAT.Xml.escape(xmlTxt);
			var resp_p = OAT.Dom.create ("pre");
			resp_p.innerHTML = txt;
			
			OAT.Dom.append ([item.dom.response_c, resp_p]);

			//	generate Result
			
			if (item.resType == iSPARQL.ResultType.GRAPH) { // Use RDFMini to show Graphs
				var lastIndex = 0;
				var tabs = [
					["navigator","Navigator"],
					["browser","Raw Triples",{removeNS:true}],
					["triples","Grid View",{}],
					["svg","SVG Graph",{}],
					["images","Images",{}],
		     ["map",
		      iSPARQL.Defaults.mapProviderNames[iSPARQL.Defaults.map_type],
		      {provider:iSPARQL.Defaults.map_type, 
					markerMode:OAT.RDFTabsData.MARKER_MODE_AUTO,
					clickPopup:true,
					hoverPopup:false}] 
				];

		    lastIndex = self.parseTabIndex (opts.resultView, tabs);
				var c_i = self.cacheIndex;
				
				self.plnk_ctr = OAT.Dom.create ("div",{className:"result_plnk_ctr"}); 
		self.miniplnk = OAT.Dom.create ("a");
		self.miniplnk.innerHTML = "Permalink";
				item.content = OAT.Dom.create ("div",{className: "mini_rdf_ctr"});
				
				OAT.Dom.append ([self.plnk_ctr, self.miniplnk]);

				if (iSPARQL.Settings.pivotInstalled) 
					self.makePivotPermalink(self.plnk_ctr);

				var mini_c = OAT.Dom.create("div");
				
				item.mini = new OAT.RDFMini(mini_c,{tabs:tabs,
													showSearch:false,
													store: item.store});

				OAT.Dom.append([item.dom.result_c, self.plnk_ctr, mini_c]);
				
				//		self.tab.go(0); // got to do here or maps won't resize properly.
				//		self.cache[self.cacheIndex].mini.processLink = self.processLink;
				//		self.cache[self.cacheIndex].mini.store.addXmlDoc(data);
				
				item.mini.select.selectedIndex = lastIndex;
				item.mini.redraw();
		self.makeMiniRDFPlinkURI (false,false,{tabIndex:lastIndex});
				OAT.MSG.attach (item.mini, 'RDFMINI_VIEW_CHANGED', self.makeMiniRDFPlinkURI);
			} else {
		if (data.firstChild.tagName == 'sparql' && 
		    data.firstChild.namespaceURI == 'http://www.w3.org/2005/sparql-results#') {		    
		    var rs = self.parseSparqlResultSet (data);
		    self.drawSparqlResultSet (rs);
			}
		}
	}

		OAT.Dom.append ([self.dom.result, item.dom.result_c],
						[self.dom.request, item.dom.request_c],
						[self.dom.query, item.dom.query_c],
						[self.dom.response, item.dom.response_c]);
		self.tab.go(0);
		self.refreshNav();
    };

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
    };

	this.processLink = function(domNode,href) {
		var dereferenceRef = function(event) {
			OAT.Event.prevent(event);

			var cache = self.cache[self.cacheIndex];

/*	    var q = 'define get:soft "replacing" \n'+
					'define input:same-as "yes" \n'+
					'define input:grab-seealso <http://www.w3.org/2002/07/owl#sameAs> \n'+
		'DESCRIBE <'+href+'> FROM <' + href + '>';*/
	    var q  = 'DESCRIBE <'+href+'>';
			var bq = 'DESCRIBE <'+href+'>';
			var o = {};
			for (var p in cache.opts) { o[p] = cache.opts[p]; }
			o.defaultGraph = false;

			if (o.endpoint.match(/^http/i)) // don't attempt to sponge on remote endpoints
			    o.query = bq;
			else
			    o.query = q;

			o.backupQuery = bq;
			self.execute(o);
 	};

		var selectRef = function(event) {
			OAT.Event.prevent(event);
			var cache = self.cache[self.cacheIndex];
			var o = {};
			for (var p in cache.opts) { o[p] = cache.opts[p]; }

			var graph = o.defaultGraph || false;

			var q = 'SELECT DISTINCT * \n';
			if (graph) { q += 'FROM <' + graph + '> \n'; }
			q += 'WHERE { { <'+href+'> ?p ?o } UNION { ?s ?p <'+href+'> } }';

			o.query = q;
			self.execute(o);
	};

		var genRef = function() {
			var ul = OAT.Dom.create("ul",{marginLeft:"20px",marginTop:"10px"});

			var li = OAT.Dom.create("li");
			var a = OAT.Dom.create("a");
			a.innerHTML = "Get Data Items";
			a.href = href;
			OAT.Event.attach(a,"click",selectRef);
			var li = OAT.Dom.create("li");
			OAT.Dom.append([ul,li],[li,a]);

			var li = OAT.Dom.create("li");
			var a = OAT.Dom.create("a");
	    		a.innerHTML = "Describe Entity";
			a.href = href;
			OAT.Event.attach(a,"click",dereferenceRef);
			var li = OAT.Dom.create("li");
			OAT.Dom.append([ul,li],[li,a]);

			var li = OAT.Dom.create("li");
			var a = OAT.Dom.create("a");
			a.innerHTML = "Open Web Page";
			a.href = href;
			OAT.Dom.append([ul,li],[li,a]);

			return ul;
	};

/*		var obj = {
			title:"URL",
			content:genRef,
			newHref:href,
			width:200,
			height:100,
			result_control:false,
			activation:"click"
		}; */
		
		OAT.Event.attach (domNode, 'click', function (event) {
			switch (iSPARQL.Settings.anchorMode) {
			case 0:
				dereferenceRef(event);
				break;
			case 1:
				selectRef(event);
				break;
			default:
				OAT.Event.prevent(event);
				window.open(href);
			}
		});


//	var img1 = OAT.Dom.create("img",{paddingLeft:"3px",cursor:"pointer"});
//	img1.title = "Describe Data Source";
//	img1.src = OAT.Preferences.imagePath + "RDF_rdf.png";
//	OAT.Event.attach(img1,"click",dereferenceRef);

//	var a = OAT.Dom.create("a",{paddingLeft:"3px"});
//	var img2 = OAT.Dom.create("img",{border:"none"});
//	img2.src = OAT.Preferences.imagePath + "RDF_xhtml.gif";
//	a.title = "Open Web Page";
//	a.appendChild(img2);
//	a.target = "_blank";
//	a.href = "/about/html/" + href;

//	domNode.parentNode.appendChild(img1);
//	domNode.parentNode.appendChild(a);
    };

     this.detectLocationMacros = function (q) {
	 return (q.match(/__P_[a-zA-Z0-9]*__/));
     }

    this.processLocationMacros = function (q, loc) {
	if (self.detectLocationMacros(q)) {
	    if (iSPARQL.locationCache._acquire_denied) {
		alert ("Cannot acquire location required to process this query.");
		return;
	    }
	    
	    var rv = q;
	    rv = rv.replace(/__P_LAT__/g, loc.getLat());
	    rv = rv.replace(/__P_LON__/g, loc.getLon());
	    return rv;
        }

    }

    this.executeWithLocation = function (optObj, loc) {
	optObj.procQuery = self.processLocationMacros (optObj.query, loc);
	self.execute (optObj)
    }

	this.execute = function(optObj) {

		var opts = {};

		for (var p in self.queryOptions) { opts[p] = self.queryOptions[p]; } /* copy of defaults */
		for (var p in optObj) { opts[p] = optObj[p]; }

	if (optObj.procQuery && 
	    optObj.procQuery != opts.query) 
	    opts.query = optObj.procQuery;

		var request = self.buildRequest(opts);

		var callback = function(data) {
			self.addResponse(request,optObj,0,data);
			if (opts.callback) { opts.callback(data); }
	    OAT.MSG.send (self,"iSPARQL_QE_DONE",self);
	};

		var onerror = function(xhr) {
			var txt = xhr.getResponseText();
			if (txt.match(/SP031/) && optObj.backupQuery) {
				var newO = {};
				for (var p in optObj) { newO[p] = optObj[p]; }
				newO.query = newO.backupQuery;
				newO.backupQuery = false;
				self.execute(newO);
			} else {
				self.addResponse(request,optObj,1,txt);
				if (opts.onerror) { opts.onerror(txt); }
			}
	};

		var o = {
			type:OAT.AJAX.TYPE_XML,
			onstart:opts.onstart,
			onend:opts.onend,
	    onerror:onerror,
	    headers:{Accept:"application/rdf+xml,application/sparql-results+xml"}
	};

		if (!opts.endpoint) { opts.endpoint = '/sparql'; }

		OAT.AJAX.POST(opts.endpoint,request,callback,o);
	}

	self.init();
}
