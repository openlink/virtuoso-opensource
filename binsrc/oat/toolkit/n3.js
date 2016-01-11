/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2016 OpenLink Software
 *
 *  See LICENSE file for details.
 */

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
						if (i+2 < str.length && str.charAt(i+1) == "^" && str.charAt(i+2) == "^") { /* skip type declaration, if present */
							while (i+2 < str.length && stopArr.indexOf(str.charAt(i+1)) == -1) { i++; }
						} else if (i+1 < str.length && str.charAt(i+1) == "@") { /* skip lang declaration */
							while (i+2 < str.length && stopArr.indexOf(str.charAt(i+1)) == -1) { i++; }
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
	parse:function(arr) { /* main routine */
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
		var triples = OAT.N3.parse(tokens);
		var ns = OAT.N3.analyzeNamespaces(triples);
		OAT.N3.applyNamespaces(triples,ns);
		OAT.N3.applyShorthands(triples);
		return triples;
	}
}
