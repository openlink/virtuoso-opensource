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
	rb = new OAT.RDFStore(callback, optObj);
	rb.addURL(url,onstart,onend);
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
	
	#rdf_side #rdf_cache #rdf_filter #rdf_tabs #rdf_content
	
	data.triples
	data.structured
	
*/

OAT.RDFStoreData = {
	FILTER_ALL:-1,
	FILTER_PROPERTY:0,
	FILTER_URI:1
}

OAT.RDFStore = function(tripleChangeCallback,optObj) {
	var self = this;
	
        this.labelProps = ["name","nick","label","title","summary","prefLabel"]; // properties used as labels
        
	this.options = {
		ajaxStart:false,
		ajaxEnd:false
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }
	
	this.reset = (tripleChangeCallback ? tripleChangeCallback : function(){});
	this.data = {
		all:[],
		triples:[],
		structured:[] 
		/*
			structured: [
				{
					uri:"uri",
					type:"type uri", // shortcut only! 
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
	this.items = [];
		
	this.addURL = function(u,onstart,onend,title) {
		var url = u.toString().trim();
		OAT.MSG.send(this,OAT.MSG.STORE_LOADING,url);
		var cback = function(str) {
			if (url.match(/\.n3$/) || url.match(/\.ttl$/)) {
				var triples = OAT.N3.toTriples(str);
			} else {
				var xmlDoc = OAT.Xml.createXmlDoc(str);
				var triples = OAT.RDF.toTriples(xmlDoc,url);
			}
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

			for (var i=0;i<triples.length;i++) {
				var t = triples[i];
				/* remove all scripts to prevent their execution */
				t[2] = sanitize(t[2]);

				/* replace some special characters in objects */
				t[2] = decode(t[2]);
				
				if (!title) {
                                        var t1 = self.simplify(t[1]);
					if ((t[0]==url || t[0]==url+'/') && self.labelProps.find(t1)!=-1)
						title = t[2];
			}
			}
			self.addTriples(triples,url,title);
			OAT.MSG.send(this,OAT.MSG.STORE_LOADED,url);
		}
		var start = onstart ? onstart : self.options.ajaxStart;
		var end = onend ? onend : self.options.ajaxEnd;
		OAT.Dereference.go(url,cback,{type:OAT.AJAX.TYPE_TEXT,onend:end,onstart:start});
	}
	
	this.addXmlDoc = function(xmlDoc,href) {
		OAT.MSG.send(this,OAT.MSG.STORE_LOADING,xmlDoc.baseURI);
		var triples = OAT.RDF.toTriples(xmlDoc);
		/* sanitize triples */
		for (var i=0;i<triples.length;i++) {
			var t = triples[i];
			t[2] = t[2].replace(/<script[^>]*>/gi,'');
		}
		self.addTriples(triples,href);
		OAT.MSG.send(this,OAT.MSG.STORE_LOADED,xmlDoc.baseURI);
	}
		
	this.addTriples = function(triples,href,title) {
		var o = {
			triples:triples,
			href:href || "",
			enabled:true,
			title:title
		}
		self.items.push(o);
		self.rebuild(false);
	}
		
	this.findIndex = function(url) {
		for (var i=0;i<self.items.length;i++) {
			var item = self.items[i];
			if (item.href == url) { return i; }
		}
		return -1;
	}
	
	this.clear = function() {
		self.items = [];
		self.rebuild(true);
		OAT.MSG.send(self,OAT.MSG.STORE_CLEARED);
	}
		
	this.remove = function(url) {
		var index = self.findIndex(url);
		if (index == -1) { return; }
		self.items.splice(index,1);
		self.rebuild(true);
		OAT.MSG.send(self,OAT.MSG.STORE_REMOVED,url);
	}
		
	this.enable = function(url) {
		var index = self.findIndex(url);
		if (index == -1) { return; }
		self.items[index].enabled = true;
		self.rebuild(true);
		OAT.MSG.send(self,OAT.MSG.STORE_ENABLED,url);
	}
	
	this.enableAll = function() {
		for (var i=0;i<self.items.length;i++)
			self.enable(self.items[i].href);
	}

	this.disable = function(url) {
		var index = self.findIndex(url);
		if (index == -1) { return; }
		self.items[index].enabled = false;
		self.rebuild(true);
		OAT.MSG.send(self,OAT.MSG.STORE_DISABLED,url);
	}

	this.disableAll = function() {
		for (var i=0;i<self.items.length;i++)
			self.disable(self.items[i].href);
	}

	this.invertSel = function() {
		for (var i=0;i<self.items.length;i++)
			if (self.items[i].enabled) {
				self.disable(self.items[i].href);
			} else {
				self.enable(self.items[i].href);
			}
	}

	this.rebuild = function(complete) {
		var conversionTable = {};
		
		/* 0. adding subroutine */
		function addTriple(triple,originatingURI) {
			var s = triple[0];
			var p = triple[1];
			var o = triple[2];
			var type = (p == "http://www.w3.org/1999/02/22-rdf-syntax-ns#type" ? o : false);
			var cnt = self.data.all.length;
			
			if (s in conversionTable) { /* we already have this; add new property */
				var obj = conversionTable[s];
				var preds = obj.preds;
				if (p in preds) { 
					var values = preds[p];
					if (values.find(o) == -1) { values.push(o); }
				} else { preds[p] = [o]; }
			} else { /* new resource */
				var obj = {
					preds:{},
					ouri:originatingURI,
					type:"",
					uri:s,
					back:[]
				}
				obj.preds[p] = [o];
				conversionTable[s] = obj;
				self.data.all.push(obj);
			}
			if (type) { obj.type = type; }
		} /* add one triple to the structure */

		/* 1. add all needed triples into structure */
		var todo = [];
		if (complete) { /* complete = all */
			self.data.all = [];
			for (var i=0;i<self.items.length;i++) {
				var item = self.items[i];
				if (item.enabled) { todo.push([item.triples,item.href,item.title]); }
			}
		} else { /* not complete - only last item */
			for (var i=0;i<self.data.all.length;i++) {
				var item = self.data.all[i];
				conversionTable[item.uri] = item;
			}
			var item = self.items[self.items.length-1];
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
		self.applyFilters(OAT.RDFStoreData.FILTER_ALL,true); /* all filters, hard reset */
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
		
		self.reset(hardReset);
	}
	
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

	this.getContentType = function(str) {
		/* 0 - generic, 1 - link, 2 - mail, 3 - image */
		if (str.match(/^http.*(jpe?g|png|gif)(#[^#]*)?$/i)) { return 3; }
		if (str.match(/^(http|urn|doi)/i)) { return 1; }
		if (str.match(/^[^@]+@[^@]+$/i)) { return 2; }
		return 0;
	}
	
	this.getTitle = function(item) {
		var result = self.simplify(item.uri);
		var preds = item.preds;
		for (var p in preds) {
			var simple = self.simplify(p);
			if (self.labelProps.find(simple) != -1) { 
				var x = preds[p][0];
				if (typeof(x) != "object") { return x; }
			}
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

	this.simplify = function(str) {
		var r = str.match(/([^\/#]+)[\/#]?$/);
		if (r && r[1] == "this") {
			r = str.match(/([^\/#]+)#[^#]*$/);
		}
		return (r ? r[1] : str);
	}
}
OAT.Loader.featureLoaded("rdfstore");
