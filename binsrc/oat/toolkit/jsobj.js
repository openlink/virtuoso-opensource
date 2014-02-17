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
	OAT.JSObj.walk(obj,callback)
	OAT.JSObj.getStringIndexes(obj)
	OAT.JSObj.getAllValues(obj,property)
	OAT.JSObj.createFromXmlNode(node)
*/

OAT.JSObj = {
	walk:function(obj,callback) { /* callback(key,value) */
		if (typeof obj != "object") { return; }
		if (obj instanceof Array) {
			/* array */
			for (var i=0;i<obj.length;i++) {
				callback(i,obj[i]);
				OAT.JSObj.walk(obj[i],callback);
			}
		} else {
			/* object */
			for (var p in obj) {
				callback(p,obj[p]);
				OAT.JSObj.walk(obj[p],callback);
			}
		}
	}, /* JSObj.walk() */

	getStringIndexes:function(obj) {
		var list = [];
		var callback = function(key,value) {
			if (typeof(value) != "object") { list.push(key); }
		}
		OAT.JSObj.walk(obj,callback);
		return list;
	},

	getAllValues:function(obj,property) {
		var list = [];
		var callback = function(key,value) {
			if (typeof(value) != "object" && key == property) { list.push(value); }
		}
		OAT.JSObj.walk(obj,callback);
		return list;
	},

	createFromXmlNode:function(node) {
		var childNodes = [];
		for (var i=0;i<node.childNodes.length;i++) {
			var n = node.childNodes[i];
			if (n.nodeType == 1) {
				childNodes.push(OAT.JSObj.createFromXmlNode(n));
			}
		}
		if (childNodes.length) {
			var result = childNodes;
		} else {
			var result = OAT.Xml.textValue(node);
		}
		var o = {};
		o[node.tagName] = result;
		return o;
	}
}
