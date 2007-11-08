/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2007 OpenLink Software
 *
 *  See LICENSE file for details.
 */

/*
	OAT.RDF.toTriples(xmlDoc)
*/

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
				if (OAT.RDF.ignoredAttributes.find(local) == -1) {
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
					if (children.length == 0) { /* no children nodes - take text content */
						var obj = OAT.Xml.textValue(n);
						triples.push([subj,pred,obj,0]);
					} else if (children.length == 1) { /* one child - it is a standalone subject */
						var obj = processNode(children[0]);
						triples.push([subj,pred,obj,1]);
					} else if (getAtt(nattribs,"parseType") == "Collection") { /* multiple children - each is a standalone node */
						for (var j=0;j<children.length;j++) {
							var obj = processNode(children[j]);
							triples.push([subj,pred,obj,1]);
						}
					} else { /* multiple children - each is a pred-obj pair */
						var obj = processNode(n,true);
						triples.push([subj,pred,obj,1]);
					} /* multiple children */
				}
			} /* for all subnodes */
			return subj;
		} /* process node */
		
		for (var i=0;i<root.childNodes.length;i++) {
			var node = root.childNodes[i];
			if (node.nodeType == 1) { processNode(node); }
		}
		return triples;
	}
} /* OAT.RDF */
OAT.Loader.featureLoaded("rdf");
