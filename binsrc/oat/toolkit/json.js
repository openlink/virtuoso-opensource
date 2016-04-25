/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2016 OpenLink Software
 *
 *  See LICENSE file for details.
 */

OAT.JSON = {
	_table: {
		'\b': '\\b',
		'\t': '\\t',
		'\n': '\\n',
		'\f': '\\f',
		'\r': '\\r',
		'"' : '\\"',
		'\\': '\\\\'
	},

	_sanitize:function(str) {
		var result = '"';
		for (var i=0;i<str.length;i++) {
			var ch = str.charAt(i);
			result += this._table[ch] || ch;
		}
		result += '"';
		return result;
	},

	deserialize:function(jsonString) {

	if (typeof JSON != "undefined") {
	    return JSON.parse(jsonString); // Use native JSON if available
	}
	
		var js = jsonString; /* various safeguards */
		if (js.substr(0,9) == "while(1);") { js = js.substr(9); }
		if (js.substr(0,2) == "/*") { js = js.substr(2,js.length-4); }
		return eval('('+js+')');
	},

	serialize:function(something, c) {
	
	if (typeof (JSON) != "undefined") {
	    return JSON.stringify(something); // Use native JSON if available
	}
	
		var cache = c || [];
		if (cache.indexOf(something) != -1) { throw new Error("Cannot serialize cyclic structure!"); }

		switch (typeof(something)) {
		    case "string": return this._sanitize(something);
		    case "number":
		    case "boolean": return something.toString();
			case "function": throw new Error("Cannot serialize functions");
		    case "object":
 				if (something === null) {
				    return "null";
				} else if (something instanceof Number || something instanceof Boolean || something instanceof RegExp)  { 
				return something.toString();
				} else if (something instanceof String) { 
				    return this._sanitize(something); 
				} else if (something instanceof Date) { 
				    return "new Date("+something.getTime()+")"; 
				} else if (something instanceof Array) {
				    var arr = [];
					cache.push(something);
		for (var i=0;i<(OAT.Browser.isIE?something.length-1:something.length);i++) {
						arr.push(arguments.callee.call(this, something[i], cache));
				}
				    return "["+arr.join(",")+"]";
				} else if (something instanceof Object) {
				    var arr = [];
					cache.push(something);
					for (var p in something) {
						var str = this._sanitize(p) + ":" + arguments.callee.call(this, something[p], cache);
						arr.push(str);
					}
				    return "{"+arr.join(",")+"}";
				}
			break;
			default: throw new Error("Unknown data type");
		}
		return null;
	}

}

//  Backward compatibility
OAT.JSON.stringify = OAT.JSON.serialize;
OAT.JSON.parse     = OAT.JSON.deserialize;
