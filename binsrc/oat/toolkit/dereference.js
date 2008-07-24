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
	OAT.Dereference.go(url, callback, optObj)
*/

OAT.Dereference = {
	pragmas:{},

	endpoint:"/proxy?url=", /* this can be changed only when used from inside chrome:// 
				   or similar because of XSS security restrictions */
	virtuoso:true, /* if virtuoso proxy is used */

	setPragmas:function(pragmaObj) {
		for (var p in pragmaObj) { 
			if (pragmaObj[p]) {
				this.pragmas[p] = pragmaObj[p];
			} else {
				delete(this.pragmas[p]);
			} 
		}
	},

	clearPragmas:function() {
		this.pragmas = {};
	},

	go:function(url,callback,optObj) {
		var addParam = function(uri, param, value) {
			if (uri.match(/.*\?.*/)) {
				return uri + "&" + param + "=" + value;
			} else {
				return uri + "?" + param + "=" + value;
			}
		}
		if (url.match(/^http/i) && this.virtuoso) { /* Virtuoso proxy: */
			var r = url.match(/^(http[s]?:\/\/)([^@\/]+@)?(.*)/);
			var user = (r[2] ? r[2].substring(0,r[2].length-1) : false);
			var encoded = encodeURIComponent(r[1] + r[3]);
			encoded = addParam(this.endpoint + encoded, "force", "rdf");
			if (user) { encoded = addParam(encoded, "login", encodeURIComponent(user)); }
			if (url.match(/\.n3$/)) { encoded = addParam(encoded, "output-format", "n3"); }
			if (url.match(/\.ttl$/)) { encoded = addParam(encoded, "output-format", "ttl"); }
			for (var p in this.pragmas) { encoded = addParam(encoded, p, this.pragmas[p]); }
		} else if ((url.match(/^urn:/i) || url.match(/^doi:/i) || url.match(/^oai:/i)) && this.virtuoso) { /* Virtuoso proxy: */
			var encoded = encodeURIComponent(url);
			encoded = addParam(this.endpoint + encoded, "force", "rdf");
			if (url.match(/\.n3$/)) { encoded = addParam(encoded, "output-format", "n3"); }
			if (url.match(/\.ttl$/)) { encoded = addParam(encoded, "output-format", "ttl"); }
			for (var p in this.pragmas) { encoded = addParam(encoded, p, this.pragmas[p]); }
		} else if (url.match(/^urn:/i) || url.match(/^doi:/i) || url.match(/^oai:/i) || url.match(/^http/i)) { /* other than Virtuoso: */
			var encoded = this.endpoint + decodeURIComponent(url);
			optObj = {
				noSecurityCookie:true
			};
		} else { /* relative uri */
			var encoded = url;
		}
		OAT.AJAX.GET(encoded,false,callback,optObj);
	}
}
OAT.Loader.featureLoaded("dereference");
