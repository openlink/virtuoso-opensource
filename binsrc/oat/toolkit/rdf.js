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
	OAT.RDF.toTriples(xmlDoc)
*/
OAT.RDF = {
	toTriples:function(xmlDoc) {
		var triples = [];
		var root = xmlDoc.documentElement;
		var bnodePrefix = "_:";
		var idPrefix = "#";
		var bnodeCount = 0;
		
		function getAtt(obj,att) {
			if (att in obj) { return obj[att]; }
			return false;
		}
		
		function processNode(node) {
			var attribs = OAT.Xml.getLocalAttributes(node);
			var subj = getAtt(attribs,"about");
			var id1 = getAtt(attribs,"nodeID");
			var id2 = getAtt(attribs,"ID");
			if (!subj) { 
				if (id1) {
					subj = idPrefix+id1; 
				} else if (id2) {
					subj = idPrefix+id2; 
				} else {
					subj = bnodePrefix+""+bnodeCount;
					bnodeCount++;
				}
			}
			
			if (OAT.Xml.localName(node) != "Description") {
				var pred = "type";
				var obj = node.localName;
				triples.push([subj,pred,obj,0]); /* 0 - literal, 1 - reference */
			}
			for (var i=0;i<node.attributes.length;i++) {
				var a = node.attributes[i];
				if (OAT.Xml.localName(a) != "about" && OAT.Xml.localName(a) != "nodeID" && OAT.Xml.localName(a) != "ID") {
					var pred = a.localName;
					var obj = a.nodeValue;
					triples.push([subj,pred,obj,1]);
				}
			} /* for all attributes */
			for (var i=0;i<node.childNodes.length;i++) if (node.childNodes[i].nodeType == 1) {
				var n = node.childNodes[i];
				var nattribs = OAT.Xml.getLocalAttributes(n);
				var pred = n.localName;
				if (getAtt(nattribs,"resource") != "") { /* link via id */
					var obj = getAtt(nattribs,"resource");
					if (obj[0] == "#") { obj = idPrefix + obj.substring(1); }
					triples.push([subj,pred,obj,1]);
				} else if (getAtt(nattribs,"nodeID") != "") { /* link via id */
					var obj = idPrefix+getAtt(nattribs,"nodeID");
					triples.push([subj,pred,obj,1]);
				} else if (getAtt(nattribs,"ID") != "") { /* link via id */
					var obj = idPrefix+getAtt(nattribs,"ID");
					triples.push([subj,pred,obj,1]);
				} else {
					var recursion = 0;
					for (var j=0;j<n.childNodes.length;j++) if (n.childNodes[j].nodeType == 1) {
						recursion = 1;
						var obj = processNode(n.childNodes[j]);
						triples.push([subj,pred,obj,1]);
					}
					if (!recursion) {
						var obj = OAT.Xml.textValue(n);
						triples.push([subj,pred,obj,0]);
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
	}
} /* OAT.RDF */
OAT.Loader.featureLoaded("rdf");
