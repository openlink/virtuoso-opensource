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
//		var idPrefix = "_id:";
		var idPrefix = "#";
		var bnodeCount = 0;
		
		function processNode(node) {
			var subj = OAT.Xml.getLocalAttribute(node,"about");
			var id = OAT.Xml.getLocalAttribute(node,"nodeID");
			if (!subj) { 
				if (id) {
					subj = idPrefix+id; 
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
				if (OAT.Xml.localName(a) != "about" && OAT.Xml.localName(a) != "nodeID") {
					var pred = a.localName;
					var obj = a.nodeValue;
					triples.push([subj,pred,obj,1]);
				}
			} /* for all attributes */
			for (var i=0;i<node.childNodes.length;i++) if (node.childNodes[i].nodeType == 1) {
				var n = node.childNodes[i];
				var pred = n.localName;
				if (OAT.Xml.getLocalAttribute(n,"resource") != "") {
					var obj = OAT.Xml.getLocalAttribute(n,"resource");
					if (obj[0] == "#") { obj = idPrefix + obj.substring(1); }
					triples.push([subj,pred,obj,1]);
				} else if (OAT.Xml.getLocalAttribute(n,"nodeID") != "") {
					var obj = idPrefix+OAT.Xml.getLocalAttribute(n,"nodeID");
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
OAT.Loader.pendingCount--;
