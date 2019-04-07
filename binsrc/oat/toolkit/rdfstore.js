/*  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2019 OpenLink Software
 *
 *  See LICENSE file for details.
 */

/*
	rb = new OAT.RDFStore(callback, optObj);
	rb.addURL(url,optObj);
	rb.addTriples(triples,href);
	rb.addXmlDoc(xmlDoc,href);
	rb.disable(url); // must be dereferenced!
	rb.enable(url); // must be dereferenced!

	rb.addFilter(OAT.RDFStoreData.FILTER_PROPERTY,"property","object");
	rb.addFilter(OAT.RDFStoreData.FILTER_URI,"uri");
	rb.removeFilter(OAT.RDFStoreData.FILTER_PROPERTY,"property","object");
	rb.removeFilter(OAT.RDFStoreData.FILTER_URI,"uri");

	rb.getTitle(item);
	rb.getURI(item);

        // predicate handlers get called in rebuild - used internally to detect labels, type, namespace prefixes

        rb.addPredHandler ()
        rb.removePredHandler ()

	#rdf_side #rdf_cache #rdf_filter #rdf_tabs #rdf_content

	data.triples
	data.structured

        Messages: 

          OAT_RDF_STORE_LOADING
          OAT_RDF_STORE_LOADED
          OAT_RDF_STORE_LOAD_FAILED
          OAT_RDF_STORE_CLEARED
          OAT_RDF_STORE_ENABLED
          OAT_RDF_STORE_DISABLED
          OAT_RDF_STORE_URI_REMOVED
*/

OAT.RDFStoreData = {
    FILTER_ALL:-1,
    FILTER_PROPERTY:0,
    FILTER_URI:1,
    TAG_IRI_ID: 0,
    TAG_LITERAL: 1
};



OAT.RDFStore = function(tripleChangeCallback, optObj) {
    var self = this;

    this.preferredClasses = {
	'http://xmlns.com/foaf/0.1/Person': 0,
	'http://': 1
    };
    
    // properties used as labels - in order of preference

    this.labelProps = {
	"http://www.w3.org/2000/01/rdf-schema#label": 0,
	"http://www.w3.org/2004/02/skos/core#prefLabel": 1,
        "http://www.openlinksw.com/schemas/virtrdf#label": 1,
	"http://xmlns.com/foaf/0.1/name": 2,
	"http://xmlns.com/foaf/0.1/nick": 3,
	"http://purl.org/dc/elements/1.1/title": 4,
	"http://dbpedia.org/property/name":5,
	"http://www.w3.org/2002/12/cal/ical#summary": 6
    };

    self.labelPropLookup = []; // label predicates by iid

//
// iid: {label: "", pref: ""}

    this.labels = {}; // labels by iid
    this.label_cnt = 0;
    this.label_proc_cnt = 0;

    this.store_changed = false;
	
    this._pred_handlers = {};

    this.options = {
	onstart:false,
	onend:false,
	onerror:false
    };

    this.load_q = [];

    for (var p in optObj) { self.options[p] = optObj[p]; }

    this.reset = (tripleChangeCallback ? tripleChangeCallback : function(){});

    this.data = {
	all:[],
	triples:[],
	structured:[]
	/*
	  structured: [
	  {
	  uri:"uri", - URI ID
	  type:"type uri", // shortcut only!
	  title:"" // shortcut
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

    this.graphs = [];

    this.getTripleCount = function () {
	return self.data.triples.length;
    }

    this.getGraphCount = function () {
	return self.graphs.length;
    }

    this.getLabelCount = function () {
	return self.label_cnt;
    }

    this.getLabelProcCount = function () {
	return self.label_proc_cnt;
    }

    this.setOpts = function (optObj) {
	for (var p in optObj)
	    {
		self.options[p] = optObj[p];
	    }
    };


    //
    // Standard predicate handers for label and type shortcuts, nsPrefixes
    //

    // XXX check that this works

    this.labelPredHandler = function (item, t, opt) {
	self.label_proc_cnt++;
	if (t[0] in self.labels) {
	    if (opt < self.labels[t[0]].pref) {
		self.labels[t[0]].label = t[2].getValue();
	    }
	}
	else {
	    self.labels[t[0]] = { label:t[2].getValue(), pref:opt};
	    self.label_cnt++;
	}
	if (opt < item.label_pref) {
	    item.label = t[2].getValue();
	    item.label_pref = opt;
	}
    }

    this.typePredHandler = function (item, t, opt) {
	if (item.type == false) item.type = [t[2]];
	else 
	    if (item.type.indexOf(t[2]) == -1) item.type.push(t[2]);
    }


    this.nsPrefixPredHandler = function (item, t, opt) {
	OAT.IRIDB.addNs (t[0], t[2].getValue());
    }

    this.dequeueURL = function (url, success)
    {
	delete self.load_q[url];
	
	if (success) self.store_changed = true;
	if (self.load_q.length) return;

	if (self.store_changed) OAT.MSG.send(self,"OAT_RDF_STORE_LOADED",{url:url});
    }

    this.queueURL = function (url, xhr) {
	self.load_q[url] = xhr;
    }

    // add handler for predicate
    // these handlers are called whenever a predicate IRI is inserted in the rdf store
    //

    this.addPredHandler = function (p_uri, handler_fun, opts) {
	var uri_id = OAT.IRIDB.insertIRI (p_uri);
	var handler_a = self._pred_handlers[uri_id];
	if (!!handler_a) handler_a.push([handler_fun, opts]);
	else self._pred_handlers[uri_id]=[[handler_fun,opts]];
    }

    this.removePredHandler = function (p_uri, handler_fun) {
        var uri_id = OAT.IRIDB.getIRIID (p_uri);

	for (h in self._pred_handlers [uri_id]) {
	    if (h == handled_fun()) {
		h = null;
	    }
	}
    }

    //
    // Add predicate handlers for label properties
    //

    for (i in self.labelProps)
	self.addPredHandler (i, self.labelPredHandler, self.labelProps[i]);

    //
    // Add predicate handler for type
    //

    self.addPredHandler ("http://www.w3.org/1999/02/22-rdf-syntax-ns#type", 
			 self.typePredHandler, 
			 false);

    //
    // Add predicate handler for namespaces
    //

    self.addPredHandler ("http://www.openlinksw.com/schema/attribution#hasNamespacePrefix", 
			 self.nsPrefixPredHandler, 
			 false);


    // dereference URL, get triples
//

    this.addURL = function(url, optObj) {

	var opt = {};

	for (p in self.options)
	    opt[p] = self.options[p];

	for (var p in optObj) { opt[p] = optObj[p]; }

	/* fallback to defaults */
	if (!opt.ajaxOpts) { opt.ajaxOpts = {}; }

	for (var p in self.options) {
	    if (!opt.ajaxOpts[p]) {
		opt.ajaxOpts[p] = self.options[p];
	    }
	}

	var url_id = OAT.IRIDB.insertIRI (url); // url shoudl now be an ID

	var title = opt.title; delete(opt.title);

	var rdfstore_addurl_cb = function(str) {


	    if (url.match(/\.n3$/) || url.match(/\.ttl$/)) { // XXX Content-Type ??
		var triples = OAT.N3.parse(str);
	    } else {
		var xmlDoc = OAT.Xml.createXmlDoc(str);
		var triples = OAT.RDF.parse(xmlDoc, url);
	    }

	    
	    if (!!window.console) window.console.log("addURL: Got " + triples.length + " triples.");

	    var decode = function(str) {
		str = str.replace(/&amp;/gi,'&');
		str = str.replace(/&gt;/gi,'>');
		str = str.replace(/&lt;/gi,'<');
		str = str.replace(/&quot;/gi,'"');
		return str;
	    }

	    var sanitize = function(str) {
		str = str.replace(/<script[^>]*>/gi,'');
		return str;
	    }

	    var title_pref = 42666;
	    var title_ndx = 0;

	    self.addTriples(triples, url, title);
	    self.dequeueURL(url, true);
	}

	var onerror = opt.ajaxOpts.onerror || false;

	opt.ajaxOpts.onerror = function(xhr) {
	    if (onerror) { onerror(xhr); }
	    self.dequeueURL(url, false);
	    OAT.MSG.send(self,"OAT_RDF_STORE_LOAD_FAILED",{url:url, xhr:xhr});
	}

	opt.ajaxOpts.type = OAT.AJAX.TYPE_TEXT;

	OAT.MSG.send(this,"OAT_RDF_STORE_LOADING",{url:url});

	var xhr = OAT.Dereference.go(url,rdfstore_addurl_cb,opt);
	self.queueURL (url, xhr);
	return xhr;
    }

    this.addXmlDoc = function(xmlDoc,href) {
	OAT.MSG.send(self,"OAT_RDF_STORE_LOADING",{url:href});
	var triples = OAT.RDF.parse (xmlDoc, href);
	var ncount = 0;

	if (!!window.console && !!window.__isparql_debug) window.console.log("addXmlDoc: Got " + triples.length + " triples.");

	/* sanitize triples */
/*	for (var i=0;i<triples.length;i++) {
	    var t = triples[i];
	    t[0] = OAT.IRIDB.insertIRI(t[0]);
	    t[1] = OAT.IRIDB.insertIRI(t[1]);

	    OAT.IRIDB.resolveCIRI(t[0]);
	    OAT.IRIDB.resolveCIRI(t[1]);

	    if (t[3] == 1) {
		t[2] = OAT.IRIDB.insertIRI(t[2]);  // Object is an URI
		OAT.IRIDB.resolveCIRI(t[0]);
	    }
	    else {
	    	if (typeof (t[2]) == "number") {
		    t[2] = t[2].toString;
		    ncount++;
		}
		else
	    t[2] = t[2].replace(/<script[^>]*>/gi,'');
	}
	}

	if (!!window.console) window.console.log("numbers in o: " + ncount);
*/
	self.addTriples(triples,href);
	OAT.MSG.send(self,"OAT_RDF_STORE_LOADED",{url:href});
    }

    this.addTripleList = function(triples,href,title) {
	OAT.MSG.send(self, "OAT_RDF_STORE_LOADING",{url:href});
	self.addTriples(triples,href,title);
	OAT.MSG.send(self, "OAT_RDF_STORE_LOADED",{url:href});
    }

    this.addTriples = function(triples, href, title) {
	var o = {
	    triples:triples,
	    href:href || "",
	    enabled:true,
	    title:title
	}
	
	self.graphs.push(o);
	self.rebuild(false);
    }

    this.findIndex = function(url) {
	for (var i=0;i<self.graphs.length;i++) {
	    var item = self.graphs[i];
	    if (item.href == url) { return i; }
	}
	return -1;
    }

    this.clear = function() {
	self.graphs = [];
	self.rebuild(true);
	OAT.MSG.send(self, "OAT_RDF_STORE_CLEARED",{});
    }

    this.remove = function(uri) {
	var index = self.findIndex(uri);
	if (index == -1) { return; }
	self.graphs.splice(index,1);
	self.rebuild(true);
	OAT.MSG.send(self,"OAT_RDF_STORE_URI_REMOVED",{uri:uri});
    }

    this.enable = function(uri) {
	var index = self.findIndex(uri);
	if (index == -1) { return; }
	self.graphs[index].enabled = true;
	self.rebuild(true);
	OAT.MSG.send(self,"OAT_RDF_STORE_ENABLED",{uri:uri});
    }

    this.enableAll = function() {
	for (var i=0;i<self.graphs.length;i++)
	    self.enable(self.graphs[i].href);
    }

    this.disable = function(url) {
	var index = self.findIndex(url);
	if (index == -1) { return; }
	self.graphs[index].enabled = false;
	self.rebuild(true);
	OAT.MSG.send(self,"OAT_RDF_STORE_DISABLED",{uri:uri});
    }

    this.disableAll = function() {
	for (var i=0;i<self.graphs.length;i++)
	    self.disable(self.graphs[i].href);
    }

    this.invertSel = function() {
	for (var i=0;i<self.graphs.length;i++)
	    if (self.graphs[i].enabled) {
		self.disable(self.graphs[i].href);
	    } else {
		self.enable(self.graphs[i].href);
	    }
    }

    this.setLabel = function (item, p, o) {
	var label_ndx = self.labelPropLookup[p];
	if (label_ndx != -1 && label_ndx < item.label_pref)
	    {
		item.label_pref = label_ndx;
		item.label = o;
	    }
    }

    this.invokePredHandlers = function (item, t) {
	var h_a = self._pred_handlers[t[1]];
	if (!!h_a)
	    for (var i=0;i<h_a.length;i++)
		h_a[i][0](item,t,h_a[i][1]);
    }

    this.rebuild = function(complete) {
	var conversionTable = {};

	/* 0. adding subroutine */
	function addTriple(triple, originatingURI) {

	    var s = triple[0];
	    var p = triple[1];
	    var o = triple[2];

	    //	    if (!!window.console) window.console.log ("<"+OAT.IRIDB.getIRI(s)+">"+"<"+OAT.IRIDB.getIRI(p)+">"+o.toString());

	    var cnt = self.data.all.length;

	    if (s in conversionTable) { /* we already have this; add new property */
		var obj = conversionTable[s];
		var preds = obj.preds;

		if (p in preds) { 
		    var values = preds[p];
		    var fnd = false;
		    for (var i=0;i<values.length;i++) {
			if (values[i].constructor != OAT.RDFAtom) {
			    if (values[i].iid == o.getIID()) {
				fnd = true;
				break;
			    }
			}
			else {
			    if (values[i].equals(o)) {
				fnd = true;
				break;
			    }
			}
		    }
		    if (!fnd) values.push(o);
		  }
		else
		    preds[p] = [o];
                  }
	    else
	      { /* new resource */
		var obj = {
		    preds:{},
		    ouri:originatingURI,
		    type:false,
		    uri:triple[0], // left for debug purposes for now
		    back:[],
		    label_pref: 666,
		    label: "",
		    iid: s
		}

		obj.preds[p] = [o];
		conversionTable[s] = obj;
		self.data.all.push(obj);
	      }
	    
	    self.invokePredHandlers (obj, triple);
	} /* add one triple to the structure */

	/* 1. add all needed triples into structure */
	var todo = [];

	if (complete) { /* complete = all */
	    self.data.all = [];
	    for (var i=0;i<self.graphs.length;i++) { // Item is sort-of synonymous to graph
		var item = self.graphs[i];
		if (item.enabled) { todo.push([item.triples,item.href,item.title]); }
	    }
	} else { /* not complete - only last item */
	    for (var i=0;i<self.data.all.length;i++) {
		var item = self.data.all[i];
		conversionTable[item.uri] = item;
	    }
	    var item = self.graphs[self.graphs.length-1];
	    todo.push([item.triples,item.href,item.title]);
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
		    var iid = ((pred[k].constructor == OAT.RDFAtom) ? pred[k].getIID() : pred[k].iid);
		    if (iid in conversionTable) { 
			var target = conversionTable[iid];
			pred[k] = target;
			if (target.back.indexOf(item) == -1) { target.back.push(item); }
		    }
		}
	    } /* predicates */
	} /* graphs */

	/* 3. apply filters: create self.data.structured + 4. convert filtered data back to triples */

	conversionTable = {}; /* clean up */
	self.applyFilters(OAT.RDFStoreData.FILTER_ALL,true); /* all filters, hard reset */
	OAT.MSG.send(self,"OAT_RDF_STORE_MODIFIED",null);
    }

    this.applyFilters = function(type,hardReset) {
	function filterObj(t,arr,filter) { /* apply one filter */
	    var newData = [];
	    for (var i=0;i<arr.length;i++) {
		var item = arr[i];
		var preds = item.preds;
		var ok = false;
		if (t == OAT.RDFStoreData.FILTER_URI) {
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

		var ok = false;
		if (t == OAT.RDFStoreData.FILTER_PROPERTY) {
		    for (var p in preds) {
			var pred = preds[p];
			if (p == filter[0] && !ok) {
			    if (filter[1] == "") {
				ok = true;
				newData.push(item);
			    } else for (var j=0;j<pred.length;j++) {
				    var value = pred[j];
				    if (value == filter[1] && !ok) {
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
	  case OAT.RDFStoreData.FILTER_ALL: /* all filters */
	    self.data.structured = self.data.all;
	    for (var i=0;i<self.filtersProperty.length;i++) {
	      var f = self.filtersProperty[i];
	      self.data.structured = filterObj(OAT.RDFStoreData.FILTER_PROPERTY,self.data.structured,f);
	    }
	    for (var i=0;i<self.filtersURI.length;i++) {
	      var f = self.filtersURI[i];
	      self.data.structured = filterObj(OAT.RDFStoreData.FILTER_URI,self.data.structured,f);
	    }
	    break;

	  case OAT.RDFStoreData.FILTER_PROPERTY:
	    var f = self.filtersProperty[self.filtersProperty.length-1]; /* last filter */
	    self.data.structured = filterObj(type,self.data.structured,f);
	    break;

	  case OAT.RDFStoreData.FILTER_URI:
	    var f = self.filtersURI[self.filtersURI.length-1]; /* last filter */
	    self.data.structured = filterObj(type,self.data.structured,f);
	    break;
	}

	self.data.triples = [];
	
// XXX
	
	for (var i=0;i<self.data.structured.length;i++) {
	    var item = self.data.structured[i];
	    for (var p in item.preds) {
		var pred = item.preds[p];
		for (var j=0;j<pred.length;j++) {
		    var v = pred[j];
		    var triple = [item.uri, parseInt(p), v];
		    self.data.triples.push(triple);
		}
	    }
	}

	self.reset(hardReset);
    };

    this.addFilter = function(type, predicate, object) {
	switch (type) {
	  case OAT.RDFStoreData.FILTER_PROPERTY:
	    self.filtersProperty.push([predicate,object]);
	    break;

	  case OAT.RDFStoreData.FILTER_URI:
	    self.filtersURI.push(predicate);
	    break;
	}
	self.applyFilters(type,false); /* soft reset */
    }

    this.removeFilter = function(type,predicate,object) {
	var index = -1;

	switch (type) {
	  case OAT.RDFStoreData.FILTER_URI:
	      for (var i=0;i<self.filtersURI.length;i++) {
		  var f = self.filtersURI[i];
		  if (f == predicate) { index = i; }
	      }
	      if (index == -1) { return; }
	      self.filtersURI.splice(index,1);
	      break;

	  case OAT.RDFStoreData.FILTER_PROPERTY:
	      for (var i=0;i<self.filtersProperty.length;i++) {
		  var f = self.filtersProperty[i];
		  if (f[0] == predicate && f[1] == object) { index = i; }
	      }
	      if (index == -1) { return; }
	      self.filtersProperty.splice(index,1);
	      break;
	}

	self.applyFilters(OAT.RDFStoreData.FILTER_ALL,false); /* soft reset */
    }

    this.removeAllFilters = function() {
	self.filtersURI = [];
	self.filtersProperty = [];
	self.applyFilters(OAT.RDFStoreData.FILTER_ALL,false); /* soft reset */
    }

    //
    // XXX The purpose and existence of the function below is just wrong in so many ways! 
    //
    
    this.getContentType = function(iri) {
	if (!iri) return 0;
	/* 0 - generic, 1 - link, 2 - mail, 3 - image */
	if (iri.match(/^http.*(jpe?g|png|gif)(#[^#]*)?$/i)) { return 3; }
	if (iri.match(/^(http|urn|doi)/i)) { return 1; }
	if (iri.match(/^[^@]+@[^@]+$/i)) { return 2; }
	return 0;
    }

    this.getCIRIorSplit = function (iid) {
	var _iid;

	_iid = (iid.constructor == OAT.RDFAtom) ? iid._value : iid;

	return OAT.IRIDB.resolveCIRI (_iid);
	    }

    this.getTitle = function(item) {

	if (!!item.label)
	    return item.label;
	else
	    if (self.options.raw_iris) 
		return OAT.IRIDB.getIRI (item.iid);
            else
		return self.getCIRIorSplit (item.iid);
    }

// XXX

    this.getURI = function(item) {

	var iri = (item.constructor == OAT.RDFAtom) ? item.getIRI(): OAT.IRIDB.getIRI(item.iid);
    	if (iri.match(/^http/i)) { return iri; }
	var props = ["uri","url"];
	var preds = item.preds;
	for (var p in preds) {
	    if (props.indexOf(p) != -1) { return preds[p][0]; }
	}
	return false;
    }

    this.getIRI = this.getURI;

    this.simplify = function(str) {
	return (self.getCIRIorSplit (OAT.IRIDB.insertIRI(str)));
    }
}
