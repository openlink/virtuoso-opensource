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
	OAT.JSON.parse(jsonString)
	OAT.JSON.stringify(something)
*/

OAT.JSON = {
	tt:{'\b':'\\b', '\t':'\\t', '\n':'\\n',	'\f':'\\f',	
		'\r':'\\r',	'"' :'\\"',	'\\':'\\\\' },

	parse:function(jsonString) {
		/* filter out while statement */
		var js = jsonString;
		if (js.substr(0,9) == "while(1);") { js = js.substr(9); }
		if (js.substr(0,2) == "/*") { js = js.substr(2,js.length-4); }
		return eval('('+js+')');
	},
	stringify:function(something, mD, c) {
		var maxDepth = 2;
		if (typeof(maxDepth) != "undefined") { maxDepth = mD; }
		if (maxDepth == 0) { return "[maximum depth achieved]"; }
		var result = "";
		var cache = [];
		if (c) { cache = c; }
		for (var i=0;i<cache.length;i++) {
			if (cache[i] === something) { return "[recursion]"; }
		}
		if (typeof(something) == "object") { cache.push(something); }
		switch (typeof(something)) {
			case 'boolean':
				return something.toString();
			break;
			
			case 'number':
				return something.toString();
			break;
			
			case 'function':
				return something.toString();
			break;
			
			case 'string':
				var tmp = "";
				for (var i=0;i<something.length;i++) {
					var r = something.charAt(i);
					for (var p in OAT.JSON.tt) {
						if (r==p) { r = OAT.JSON.tt[p]; }
					}
					tmp += r;
				}
				return '"'+tmp+'"';
			break;
			
			case 'object':
				if (something instanceof Array) {
					var members = [];
					for (var i=0;i<something.length;i++) {
						members.push(OAT.JSON.stringify(something[i],maxDepth-1,cache));
					}
					result = "["+members.join(",\n")+"]";
					return result;
				}
				if (something instanceof Object) {
					var members = [];
					for (var p in something) {
						members.push('"'+p+'":'+OAT.JSON.stringify(something[p],maxDepth-1,cache));
					}
					result = "{"+members.join(",\n")+"}";
				}
			break;
		}
		return result;
	}
}
OAT.Loader.featureLoaded("json");
