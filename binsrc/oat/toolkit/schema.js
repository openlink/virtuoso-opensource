/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2018 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
*/
OAT.Schema = {
	getType:function(schemaElements,name) {
		var schemas = schemaElements;
		if (!(schemas instanceof Array)) { schemas = [schemaElements]; }
		var availTypeNodes = OAT.Xml.getElementsByLocalName(schemas,"complexType");
		for (var i=0;i<availTypeNodes.length;i++) {
			var node = availTypeNodes[i];

			if (node.getAttribute("name") == name) {
				/* correct type node */
				var result = {};
				var elems = OAT.Xml.getElementsByLocalName(node,"element");
				for (var i=0;i<elems.length;i++) {
					var n = elems[i].getAttribute("name");
					var t = elems[i].getAttribute("type");
					if (t) {
						t = t.split(":").pop();
						result[n] = OAT.Schema.getType(schemas,t);
					} else {
						var ref = elems[i].getAttribute("ref").split(":").pop();
						var type = OAT.Schema.getElement(schemas,ref);
						if (elems.length > 1) {
							result[ref] = type;
						} else return [type];
					}

				}
				/* also try arrays */
				if (elems.length) { return result; }
				var res = OAT.Xml.getElementsByLocalName(node,"restriction");
				if (res.length && res[0].getAttribute("base").split(":").pop() == "Array") {
					/* is array! */
					result = [];
					var a = OAT.Xml.getElementsByLocalName(res[0],"attribute")[0];
					var t = a.getAttribute("wsdl:arrayType").split(":").pop().match(/(.*)\[\]/)[1];
					result.push(OAT.Schema.getType(schemas,t));
				}
				return result;

			}
		}
		return name;
	},

	getElement:function(schemaElements,name) {
		var schemas = schemaElements;
		if (!(schemas instanceof Array)) { schemas = [schemaElements]; }
		var availElementNodes = OAT.Xml.getElementsByLocalName(schemas,"element");
		for (var i=0;i<availElementNodes.length;i++) {
			var node = availElementNodes[i];
			if (node.getAttribute("name") == name) {
				/* correct type node */
				var result = {};
				var elems = OAT.Xml.getElementsByLocalName(node,"element");
				for (var i=0;i<elems.length;i++) {
					var n = elems[i].getAttribute("name");
					var t = elems[i].getAttribute("type");
					if (t) {
						t = t.split(":").pop();
						result[n] = OAT.Schema.getType(schemas,t);
					} else {
						var ref = elems[i].getAttribute("ref").split(":").pop();
						var type = OAT.Schema.getElement(schemas,ref);
						if (elems.length > 1) {
							result[ref] = type;
						} else return [type];
					}
				}
				/* also try arrays */
				if (elems.length) { return result; }
				var res = OAT.Xml.getElementsByLocalName(node,"restriction");
				if (res.length && res[0].getAttribute("base").split(":").pop() == "Array") {
					/* is array! */
					result = [];
					var a = OAT.Xml.getElementsByLocalName(res[0],"attribute")[0];
					var t = a.getAttribute("wsdl:arrayType").split(":").pop().match(/(.*)\[\]/)[1];
					result.push(OAT.Schema.getType(schemas,t));
				}
				return result;
			}
		}
		return false;
	}
}
