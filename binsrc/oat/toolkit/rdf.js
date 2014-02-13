/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2014 OpenLink Software
 *
 *  See LICENSE file for details.
 */

/*
 *	OAT.RDF.toTriples(xmlDoc)
*/

OAT.RDFTag = {
    IRI: 0,
    LIT: 1,
    BNODE:2,
    strings: ["IID", "LIT", "BNODE"]
}

OAT.RDFAtom = function (tag, value, ns) {
    var self = this;

    self._tag = tag;
    self._val = value;
    self._dt = '';
    self._lang = false;

    this.isIRI = function () {
	if (self._tag == OAT.RDFTag.IRI) return true;
	return false;
    }

    this.isBNode = function () {
	if (self._tag == OAT.RDFTag.BNODE) return true
	return false;
    }

    this.isLit = function () {
	if (self._tag == OAT.RDFTag.LIT) return true;
	return false;
    }

    this.getTag = function () {
	return self._tag;
    }

    this.getValue = function () {
	return self._val;
    }

    this.getLang = function () {
	return self._lang;
    }

    this.equals = function (_obj) {
	if (_obj.constructor != OAT.RDFAtom) return false;
	if (_obj._tag != self._tag) return false;
	if (_obj._val != self._val) return false;
	return true;
    }

    //
    // get value with data type, lang, in XML-XSD formatting
    //

    this.getValueDt = function () {
	// XXX no-op
    }

    //
    // get IID of (XSD) datatype if literal
    //

    this.getDt = function () {
	if (self._tag == OAT.RDFTag.LIT) {
	    if (!!dt) return _dt;
	    return false
	}
	return false;
    }

    this.getIRI = function () {
	if (self._tag == OAT.RDFTag.IRI)
	    return OAT.IRIDB.getIRI (self._val);
	return false;
    }

    this.getIID = function () {
	if (self._tag == OAT.RDFTag.IRI)
	    return self._val;
	return false;
    }

    this.tagString = function (t) {
	return OAT.RDFTag.strings[t];
    }
	
    this.toString = function () {
	var _out = "#ATOM:\{" + self.tagString(self._tag);
	if (self.getTag() == OAT.RDFTag.IRI) {
            _out += "IID:" + self._val + " " + "<" + OAT.IRIDB.getIRI (self._val) + ">";
	}
	if (self.getTag() == OAT.RDFTag.LIT) {
	    _out += "\"" + self._val + "\"";
	    var lang_tag = self.getLang();
	    if (lang_tag) _out += "@" + lang_tag;
	}
	return _out + "\}";
    }

    //
    // constructor
    //
	
    if (tag == OAT.RDFTag.IRI) {
	self._val = OAT.IRIDB.insertIRI(value, ns);
    }
    
    _value = value;
};

//
// Global IRI repository
// 


OAT.IRIDB = {

//
// Some "Well-known" namespaces
//

    _default_iris: [
	["http://www.w3.org/1999/02/22-rdf-syntax-ns#", "rdf"],
	["http://purl.org/dc/elements/1.1/",            "dc"],
	["http://www.w3.org/2002/07/owl#",              "owl"],
	["http://rdfs.org/sioc/ns#",                    "sioc"],
	["http://www.w3.org/2000/01/rdf-schema#",       "rdfs"],
        ["http://www.w3.org/2001/XMLSchema#",           "xsd"],
	["http://xmlns.com/foaf/0.1/",                  "foaf"],
	["http://umbel.org/umbel#",                     "umbel"],
	["http://purl.org/goodrelations/v1#",           "gr"],
	["http://www.openlinksw.com/schemas/xbrl/",     "xbrl"],
	["http://www.openlinksw.com/schemas/rdfs/",     "oplrdfs"],
	["http://dbpedia.org/resource/",                "dbpedia"],
        ["http://dbpedia.org/ontology/",                "dbo"],
        ["http://dbpedia.org/property/",                "dbpprop"],
	["http://dbpedia.org/class/yago/",              "yago"]
], // IRI array 

    _iri_a:  [],
    _iri_h: {},
    _iri_c:  0,  // High water mark
    _iri_d:  0,  // no dirty XXX: delete/compaction not implemented yet
    _ciri_h: {}, // CIRI hash
    _ns_pref: {},
    _ciri_unres: [], // iids with unresolved CIRI
    _enableHTML5LocalStorage:false,
    _ns_cnt: 0,  // count of "anon" ns pfxes

    //
    // Insert IRI, update ns prefix, or just get IID of existing IRI
    //
    
    insertIRI: function (iri, ns) {
	var iid = this._iri_h[iri];

	if (!iid) {
	    iid = this._iri_c++;
	    this._iri_h[iri] = iid;
	    this._iri_a[iid] = [iri, (ns?ns:false)];
	} else
	    if (ns) {
		if (typeof ns == "object") throw "InsertIRI error: Ciri cannot be an object.";
		this._iri_a[iid][1] = ns;
	    }
	return iid;
    },

    insertIRIArr: function (iri_arr) {
	var r_a = []; 
	for (var i=0;i<iri_arr.length;i++) {
	    if (typeof iri_arr[i] == 'object') {
		r_a.push (this.insertIRI (iri_arr[i][0], iri_arr[i][1]));
	    } 
	    else {
		r_a.push (this.insertIRI (iri_arr[i]));
	    }
	}
	return r_a;
    },

    addNs: function (iid, ns) {
	var iri_s = this._iri_a[iid];

	if (iri_s) 
	{
	    iri_s[1] = ns;
	}
    },

    getIRI: function (iid) {
	var i_a = this._iri_a[iid];
	return (i_a ? i_a[0] : false);
    },

    getIID: this.insertIRI,

    getIRIID: function (iri) {
	var iri_id = this._iri_h[iri];
	return (iri_id ? iri_id : false);
    },

    getCIRIByID: function (iid) {
	var i_a = this._iri_a[iid];
	return ((i_a && i_a[1]) ? i_a[1] : false);
    },
    getIRIID: function (iri) {
	var iri_id = this._iri_h[iri];
	return (iri_id ? iri_id : false);
    },

//
// Resolve an IRI to a CIRI representation
//

    getCIRIByIRI:function (iri) {
	var i_id = this._iri_h[iri];
	var i_a = this._iri_a[i_id];
	return (i_a ? i_a[1] : false);
    },

    splitIRI:function (iri) {
	if (typeof iri != "string") throw "splitIRI: invalid iri - must be string";
	var r = iri.match(/([^\/#]+)[\/#]?$/);
	if (r && r[1] == "this") {
	    r = iri.match(/([^\/#]+)#[^#]*$/);
	}
	return (r ? r : false);
    }, 

    makeNSPrefix:function() {
	return 'ns'+this._ns_cnt++;
    },

    //
    //  Resolve CIRI (IRI with NS Prefix) and cache
    //

    resolveCIRI:function (iid) {
	var ciri = this._iri_a[iid][1];
	if (!!ciri) return ciri;

        var iri = this._iri_a[iid][0];

	var i_a = this.splitIRI (iri); // http://www.zonk.net/onto/cli/ 
	
	var ns_iri = iri.substr(0, i_a.index);
	var ns_iid = this._iri_h [ns_iri];

	if (ns_iid) {
            if (this._iri_a[ns_iid][1]) {
		ciri = this._iri_a[ns_iid][1] + ":" + i_a[0]; // Already have a ns prefix
	    } else {
		var new_ns = this.makeNSPrefix(); // ns IRI exists but no prefix - synthesize and save
		ciri = new_ns + ':' + i_a[0];
		this._iri_a[ns_iid][1] = new_ns;
	    }
	}
	else
	    {
	    var new_ns = this.makeNSPrefix();
	    this.insertIRI(ns_iri, new_ns);
	    ciri = new_ns + ":" + i_a[0];	    
	    }

	this._iri_a[iid][1] = ciri; // cache CIRI with the IRI

	return ciri;
    },

    init: function () {
	if (this._enableHTML5LocalStorage) {
	    if (!!localStorage.OAT_IRIDB) {
		try {
		    var idb = OAT.JSON.deserialize (localStorage.OAT_IRIDB);
		}
		catch (e) {
		    localStorage.OAT_IRIDB = OAT.JSON.serialize ({_iri_a: [],_iri_h:{},_iri_c:0});
		}
		OAT.IRIDB._iri_a = idb._iri_a;
		OAT.IRIDB._iri_h = idb._iri_h;
		OAT.IRIDB._iri_c = idb._iri_c;
		OAT.IRIDB._iri_d = idb._iri_d;
	    } else {
	    this.insertIRIArr (this._default_iris);
		this.save();
	    }
	    OAT.MSG.attach ("*","OAT_RDF_STORE_LOADED", this.save);
	}
	else
	    this.insertIRIArr (this._default_iris);
    },	    

    getStats: function () {
	return ({iriCount: this._iri_c, dirty: this._iri_d});
    },

    //
    // If enabled, should limit of triples to store, due to quota restriction and 
    // OAT.JSON.serialize performance issues
    //

    save: function (m,s,l) {
	localStorage.OAT_IRIDB = OAT.JSON.serialize({_iri_a: OAT.IRIDB._iri_a, 
						     _iri_h: OAT.IRIDB._iri_h,
						     _iri_c: OAT.IRIDB._iri_c});
    }
};

OAT.IRIDB.init();

OAT.RDFData = {
	DISABLE_HTML:1,
	DISABLE_DEREFERENCE:2,
	DISABLE_BOOKMARK:4,
	DISABLE_FILTER:8
}

OAT.RDF = {
	ignoredAttributes:["about","nodeID","ID","parseType"],
	toTriples:function(xmlDoc,url) {
		var triples = [];
		var root = xmlDoc.documentElement;
		if (!root || !root.childNodes) { return triples; }
		var bnodePrefix = "_:" + Math.round(1000*Math.random()) + "_";
		var bnodeCount = 0;

		var u = url || "";
		u = u.match(/^[^#]+/);
		u = u? u[0] : "";
		var idPrefix = u + "#";

		function getAtt(obj,att) {
			if (att in obj) { return obj[att]; }
			return false;
		}

		function processNode(node,isPredicateNode) {
			/* get info about node */
			var attribs = OAT.Xml.getLocalAttributes(node);
			/* try to get description from node header */
			var subj = getAtt(attribs,"about");
			var id1 = getAtt(attribs,"nodeID");
			var id2 = getAtt(attribs,"ID");
	    
			/* no subject in triplet */
			if (!subj) {
				/* try construct it from ids */
				if (id1) {
					subj = idPrefix+id1;
				} else if (id2) {
					subj = idPrefix+id2;
				} else {
					/* create anonymous subject */
					subj = bnodePrefix+bnodeCount;
					bnodeCount++;
				}
			}
			/* now we have a subject */

			/* handle literals ? */
			if (OAT.Xml.localName(node) != "Description" && !isPredicateNode) { /* add 'type' where needed */
				var pred = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type";
				var obj = node.namespaceURI + OAT.Xml.localName(node);
				triples.push([subj,pred,obj,0]); /* 0 - literal, 1 - reference */
			}

			/* for each of our own attributes, push a reference triplet into the graph */
			for (var i=0;i<node.attributes.length;i++) {
				var a = node.attributes[i];
				var local = OAT.Xml.localName(a);
				if (OAT.RDF.ignoredAttributes.indexOf(local) == -1) {
					var pred = a.namespaceURI+OAT.Xml.localName(a);
					var obj = a.nodeValue;
					triples.push([subj,pred,obj,1]);
				}
			} /* for all attributes */

			/* for each of our children create triplets based on their type */
			for (var i=0;i<node.childNodes.length;i++) if (node.childNodes[i].nodeType == 1) {
				var n = node.childNodes[i];
				var nattribs = OAT.Xml.getLocalAttributes(n);
				var pred = n.namespaceURI+OAT.Xml.localName(n);

				if (getAtt(nattribs,"resource") != "") { /* link via id */
					var obj = getAtt(nattribs,"resource");
					if (obj[0] == "#") { obj = idPrefix + obj.substring(1); }
					triples.push([subj,pred,obj,1]);
				} else if (getAtt(nattribs,"nodeID") != "") { /* link via id */
					/* recurse */
					var obj = processNode(n,true);
					triples.push([subj,pred,obj,1]);
				} else if (getAtt(nattribs,"ID") != "") { /* link via id */
					/* recurse */
					var obj = processNode(n,true);
					triples.push([subj,pred,obj,1]);
				} else {
					var children = [];
					for (var j=0;j<n.childNodes.length;j++) if (n.childNodes[j].nodeType == 1) {
						children.push(n.childNodes[j]);
					}
					/* now what those children mean: */
					if (getAtt(nattribs,"parseType") == "Collection") { 	/* possibly multiple children - each is a standalone node */
						for (var j=0;j<children.length;j++) {
							var obj = processNode(children[j]);
							triples.push([subj,pred,obj,1]);
						}
					} else if (getAtt(nattribs,"parseType") == "Literal") { /* possibly multiple children, literal - everything to one string */
						var obj = "";
						for (var j=0;j<children.length;j++) {
							obj += OAT.Xml.serializeXmlDoc(children[j]);
						}
						triples.push([subj,pred,obj,1]);
					} else if (children.length == 1) { /* one child - it is a standalone subject */
						var obj = processNode(children[0]);
						triples.push([subj,pred,obj,1]);
					} else if (children.length == 0) { /* no children nodes - take text content */
						var obj = OAT.Xml.textValue(n);
						triples.push([subj,pred,obj,0]);
					} else { /* other cases, multiple children - each is a pred-obj pair */
						var obj = processNode(n,true);
						triples.push([subj,pred,obj,1]);
					}
				}
			} /* for all subnodes */
			return subj;
		} /* process node */

		for (var i=0;i<root.childNodes.length;i++) {
			var node = root.childNodes[i];
			if (node.nodeType == 1) { processNode(node); }
		}
		return triples;
    },

    //
    // Parse RDF+XML - return typed triples
    //

    parse:function(xmlDoc,url) {
	var triples = [];
	var root = xmlDoc.documentElement;
	if (!root || !root.childNodes) { return triples; }
	var bnodePrefix = "_:" + Math.round(1000*Math.random()) + "_";
	var bnodeCount = 0;
	
	var u = url || "";
	u = u.match(/^[^#]+/);
	u = u? u[0] : "";
	var idPrefix = u + "#";
	
	function getAtt(obj, att) {
	    if (att in obj) { return obj[att]; }
	    return false;
	}
	
	function getAttVal (obj, att) {
	    if (att in obj) { return obj[att].nodeValue; }
	}

	function processNode(node,isPredicateNode) {
	    /* get info about node */
	    var attribs = OAT.Xml.getLocalAttributeNodes(node);
	    /* try to get description from node header */
	    var subj = getAttVal(attribs,"about");
	    
	    var id1 = getAttVal(attribs,"nodeID");
	    var id2 = getAttVal(attribs,"ID");
	    
	    /* no subject in triplet */
	    if (!subj) {
		/* try construct it from ids */
		if (id1) {
		    subj = idPrefix+id1;
		} else if (id2) {
		    subj = idPrefix+id2;
		} else {
		    /* create anonymous subject */
		    subj = bnodePrefix+bnodeCount;
		    bnodeCount++;
		}
	    }
	    else {
		var subj_n = attribs["about"];
		var subjNs = OAT.Xml.getNsURI(subj_n);
		var subjNsPref = OAT.Xml.getNsPrefix(subj_n);
		OAT.IRIDB.insertIRI (subjNs, subjNsPref);
	    }

	    /* now we have a subject */
	    
	    /* handle literals ? */

	    if (OAT.Xml.localName(node) != "Description" && !isPredicateNode) { /* add 'type' where needed */
		var pred = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type";
		var obj = node.namespaceURI + OAT.Xml.localName(node);
		var objType = getAtt(attribs, pred);
		triples.push([OAT.IRIDB.insertIRI(subj),
			      OAT.IRIDB.insertIRI(pred),
			      new OAT.RDFAtom (OAT.RDFTag.IRI, OAT.IRIDB.insertIRI(obj))]); /* 0 - literal, 1 - reference */
	    }
	    

	    /* for each of our own attributes, push a reference triplet into the graph */
	    for (var i=0;i<node.attributes.length;i++) {
		var a = node.attributes[i];
		var local = OAT.Xml.localName(a);
		if (OAT.RDF.ignoredAttributes.indexOf(local) == -1) {
		    var pred = a.namespaceURI+OAT.Xml.localName(a);
		    var predNs = OAT.Xml.getNsURI(a);
		    var predNsPrefix = OAT.Xml.getNsPrefix(a);

		    // make sure ns prefix is stored
		    OAT.IRIDB.insertIRI(predNs,predNsPrefix);

		    var obj = a.nodeValue;

		    var objNs = OAT.Xml.getNsURI (a);
		    var objNsPrefix = OAT.Xml.getNsPrefix(obj);

		    OAT.IRIDB.insertIRI(objNs, objNsPrefix);

		    triples.push([OAT.IRIDB.insertIRI(subj),
				  OAT.IRIDB.insertIRI(pred),
				  new OAT.RDFAtom (OAT.RDFTag.IRI, OAT.IRIDB.insertIRI(obj), objNs)]);
		}
	    } /* for all attributes */
	    
	    /* for each of our children create triplets based on their type */
	    for (var i=0;i<node.childNodes.length;i++) if (node.childNodes[i].nodeType == 1) {
		var n = node.childNodes[i];
		var nattribs = OAT.Xml.getLocalAttributes(n);
		var pred = n.namespaceURI+OAT.Xml.localName(n);
		var predNs = OAT.Xml.getNsURI(n);
		var predNsPrefix = OAT.Xml.getNsPrefix(n);

		if (getAtt(nattribs,"resource") != "") { /* link via id */
		    var obj = getAtt(nattribs, "resource");
		    if (obj[0] == "#") { obj = idPrefix + obj.substring(1); }
		    
		    OAT.IRIDB.insertIRI (predNs, predNsPrefix);

		    triples.push([OAT.IRIDB.insertIRI(subj),
				  OAT.IRIDB.insertIRI(pred,n.nodeName),
				  new OAT.RDFAtom (OAT.RDFTag.IRI, obj)]);
		} else if (getAtt(nattribs, "nodeID") != "") { /* link via id */
		    /* recurse */
		    var obj = processNode(n, true);

		    triples.push([OAT.IRIDB.insertIRI(subj),
				  OAT.IRIDB.insertIRI(pred),
				  new OAT.RDFAtom (OAT.RDFTag.IRI, obj)]);
		} else if (getAtt(nattribs,"ID") != "") { /* link via id */
		    /* recurse */
		    var obj = processNode(n,true);

		    triples.push([OAT.IRIDB.insertIRI(subj),
				  OAT.IRIDB.insertIRI(pred),
				  new OAT.RDFAtom (OAT.RDFTag.IRI, obj)]);
		} else {
		    var children = [];
		    for (var j=0;j<n.childNodes.length;j++) if (n.childNodes[j].nodeType == 1) {
			children.push(n.childNodes[j]);
		    }
		    /* now what those children mean: */
		    if (getAtt(nattribs,"parseType") == "Collection") { 	/* possibly multiple children - each is a standalone node */
			for (var j=0;j<children.length;j++) {
			    var obj = processNode(children[j]);
			    triples.push([OAT.IRIDB.insertIRI(subj),
					  OAT.IRIDB.insertIRI(pred),
					  new OAT.RDFAtom (OAT.RDFTag.IRI, obj)]);
			}
		    } else if (getAtt(nattribs,"parseType") == "Literal") { /* possibly multiple children, literal - everything to one string */
			var obj = "";
			for (var j=0;j<children.length;j++) {
			    obj += OAT.Xml.serializeXmlDoc(children[j]);
			}
			triples.push([OAT.IRIDB.insertIRI(subj),
				      OAT.IRIDB.insertIRI(pred),
				      new OAT.RDFAtom (OAT.RDFTag.LIT, obj)]);
		    } else if (children.length == 1) { /* one child - it is a standalone subject */
			var obj = processNode(children[0]);
			triples.push([OAT.IRIDB.insertIRI(subj),
				      OAT.IRIDB.insertIRI(pred),
				      new OAT.RDFAtom (OAT.RDFTag.IRI, obj)]);
		    } else if (children.length == 0) { /* no children nodes - take text content */
			var obj = OAT.Xml.textValue(n);

			triples.push([OAT.IRIDB.insertIRI(subj),
				      OAT.IRIDB.insertIRI(pred),
				      new OAT.RDFAtom (OAT.RDFTag.LIT, obj)]);
		    } else { /* other cases, multiple children - each is a pred-obj pair */
			var obj = processNode(n,true);
			triples.push([OAT.IRIDB.insertIRI(subj),
				      OAT.IRIDB.insertIRI(pred),
				      new OAT.RDFAtom (OAT.RDFTag.IRI, obj)]);
		    }
		}
	    } /* for all subnodes */
	    return subj;
	} /* process node */
	
	for (var i=0;i<root.childNodes.length;i++) {
	    var node = root.childNodes[i];
	    if (node.nodeType == 1) { 
		if (OAT.Xml.localName(node) == "parsererror") { // Handle WebKit Parse error
		    var error_m = node.innerText ? node.innerText : "Unknown Error";

		    // XXX: This is probably not a good idea - should just throw an exception?

		    if (!url.match(/#[a-zA-Z0-9]*$/)) url += '#parseErrorInQueryResult';
		    
		    triples.push ([OAT.IRIDB.insertIRI(url),
				   OAT.IRIDB.insertIRI("http://www.openlinksw.com/schema/oat/hasRdfParserError"),
				   new OAT.RDFAtom (OAT.RDFTag.LIT, error_m)]);
		} else {
		    processNode(node); 
		}
	    }
	}
	return triples;
	}


} /* OAT.RDF */

/*
	OAT.N3.toTriples(string);
 */

OAT.N3 = {
    cleanComments:function(str) { /* remove comments */
	var lines = str.split(/\r|\n/);
	for (var i=0;i<lines.length;i++) {
	    lines[i] = lines[i].replace(/\t/g," ");
	    lines[i] = lines[i].replace(/^#.*$/g,"");
	    lines[i] = lines[i].replace(/ #[^"]+$/g,"");
	}
	return lines.join(" ");
    },
    tokenize:function(string) { /* convert to array */
	var str = string;
	var arr = [];
	var item = "";
	var instring = false;
	var inuri = false;
	for (var i=0;i<str.length;i++) {
	    var ch = str.charAt(i);
	    switch (ch) {
	    case "<":
		if (!instring) {
		    inuri = true;
		} else { item += ch; }
		break;
		
	    case ">":
		if (!instring) {
		    inuri = false;
		    arr.push(item);
		    item = "";
		} else { item += ch; }
		break;
		
	    case "'":
	    case '"':
		if (!instring) {
		    instring = ch;
		} else if (instring == ch) {
		    instring = false;
		    arr.push('"'+item+'"');
		    item = "";
		    var stopArr = [" ",";",".",","];
		    var st;
		    if (i+2 < str.length && str.charAt(i+1) == "^" && str.charAt(i+2) == "^") { /* skip type declaration, if present */
			st = i+2;
			while (i+2 < str.length && stopArr.indexOf(str.charAt(i+1)) == -1) { i++; }
			var dtStr = str.substring (st,i+1);
		    } else if (i+1 < str.length && str.charAt(i+1) == "@") { /* skip lang declaration */
			st = i+1;
			while (i+2 < str.length && stopArr.indexOf(str.charAt(i+1)) == -1) { i++; }
			var langStr = str.substring (st,i);
		    }
		} else {
		    item += ch;
		}
		break;
		
	    case "[":
		  case "]":
	    case ";":
	    case ".":
	    case ",":
		if (!instring && !inuri) {
		    if (item) { arr.push(item); }
		    arr.push(ch);
		    item = "";
		} else { item += ch; }
		break;
		
	    case " ":
		if (instring) {
		    item += ch;
		} else if (item && !inuri) {
		    arr.push(item);
		    item = "";
		}
		break;
		
	    default:
		item += ch;
		break;
	    }
	}
	if (item) { arr.push(item); } /* flush stack */
	return arr;
    },
    analyzeNamespaces:function(triples) { /* get namespace object, remove namespace triples */
	var indexes = [];
	var obj = {};
	for (var i=0;i<triples.length;i++) {
	    var t = triples[i];
	    if (t[0] == "@prefix") {
		obj[t[1]] = t[2];
		indexes.push(i);
		OAT.IRIDB.insertIRI (t[1].substring(0,t[1].length-1),t[2]); // Add namespace iri in IRIDB
	    }
	}
	for (var i=indexes.length-1;i>=0;i--) { triples.splice(indexes[i],1); }
	return obj;
    },
    applyNamespaces:function(triples,nsObj) { /* resolve namespaces */
	for (var i=0;i<triples.length;i++) {
	    var t = triples[i];
	    for (var j=0;j<t.length;j++) {
		var str = t[j];
		if (str.charAt(0) != '"') {
		    var r = str.match(/(^[^:]*:)(.*)/);
		    if (r && r[1] in nsObj) {
			t[j] = nsObj[r[1]] + r[2];
		    }
		} /* not string */
	    } /* s,p,o */
	} /* all triples */
	return triples;
    },
    applyShorthands:function(triples) { /* resolve N3 shorthands, remove string quotes */
	var shorts = {
	    "a":"http://www.w3.org/1999/02/22-rdf-syntax-ns#type",
	    "=":"http://www.w3.org/2002/07/owl#sameAs",
	    "=>":"http://www.w3.org/2000/10/swap/log#implies"
	}
	for (var i=0;i<triples.length;i++) {
	    var t = triples[i];
	    var p = t[1];
	    if (p in shorts) { t[1] = shorts[p]; }
	    var o = t[2];
	    if (o.charAt(0) == '"') { t[2] = o.substring(1,o.length-1); }
	}
    },
    _parse:function(arr) { /* main routine */
	var bnodePrefix = "_:" + Math.round(1000*Math.random()) + "_";
	var bnodeCount = 0;
	
	var triples = [];
	
	var resStack = [];
	var predStack = [];
	
	var expected = 0;
	
	for (var i=0;i<arr.length;i++) {
	    var token = arr[i];
	    switch (token) {
	    case ")": break; /* nothing interesting */
	case "]":
	resStack.pop();
	predStack.pop();
	break;
	
    case "(":
	   break;
	   
	  case "[":
		 expected = 1;
		 bnodeCount++;
		 var res = bnodePrefix+bnodeCount;
		 var pred = predStack[predStack.length-1];
		 if (resStack.length) { triples.push([resStack[resStack.length-1],pred,res]); }
		 resStack.push(res); /* new blank node */
		 predStack.push(""); /* new empty predicate */
		 break;
		 
		case ";":
		 expected = 1;
		 break;
		 
		case ".":
		 expected = 0;
		 resStack = [];
		 break;
		 
		case ",":
		 expected = 2;
		 break;
		 
		default:
		 if (expected == 0) {
		     resStack.push(token);
		     predStack.push("");
		     expected = 1;
		 } else if (expected == 1) {
		     predStack[predStack.length-1] = token;
		     expected = 2;
		 } else if (expected == 2) {
		     var pred = predStack[predStack.length-1];
		     triples.push([resStack[resStack.length-1],pred,token]);
		 }
		 break;
		}
	  }
	
	return triples;
    },
    
    toTriples:function(str) {
	var clean = OAT.N3.cleanComments(str);
	var tokens = OAT.N3.tokenize(clean);
	window.tok = tokens;
	var triples = OAT.N3._parse(tokens);
	var ns = OAT.N3.analyzeNamespaces(triples);
	OAT.N3.applyNamespaces(triples,ns);
	OAT.N3.applyShorthands(triples);
	return triples;
    },

    parse: function (str) {
	var clean = OAT.N3.cleanComments(str);
	var tokens = OAT.N3.tokenize(clean);
	window.tok = tokens;
	var triples = OAT.N3._parse(tokens);
	var ns = OAT.N3.analyzeNamespaces(triples);
	OAT.N3.applyNamespaces(triples,ns);
	OAT.N3.applyShorthands(triples);
	return triples;
    }
}
// OAT.N3
