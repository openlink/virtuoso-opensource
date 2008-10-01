/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2008 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	OAT.Dereference.go(url, callback, optObj)
*/

OAT.Dereference = {
	pragmas:{},

	endpoint:"/proxy?url=", /* this can be changed to generic domain only 
				   when used from inside chrome:// 
				   or similar because of XSS security restrictions */
	virtuoso:true, /* if virtuoso proxy is used */
	virt_proxy_ver:1, /* Normal proxy type - default */
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

		var endpoint = optObj.endpoint || this.endpoint;

		var addParam = function(uri, param, value) {
			if (uri.match(/.*\?.*/)) {
				return uri + "&" + param + "=" + value;
			} else {
				return uri + "?" + param + "=" + value;
			}
		}

		if (this.virtuoso && url.match(/^http/i)) {
			var r = url.match(/^(http[s]?:\/\/)([^@\/]+@)?(.*)/);
			var user = (r[2] ? r[2].substring(0,r[2].length-1) : false);
			var encoded = encodeURIComponent(r[1] + r[3]);
			
			/* triplr-style endpoint cannot process URL params as they are passed through to the remote */
		    	if (this.virt_proxy_ver != 1) {
					optObj["noSecurityCookie"] = true;
		    	} else {
					encoded = addParam(endpoint + encoded, "force", "rdf");
			if (user) { encoded = addParam(encoded, "login", encodeURIComponent(user)); }
			if (url.match(/\.n3$/)) { encoded = addParam(encoded, "output-format", "n3"); }
			if (url.match(/\.ttl$/)) { encoded = addParam(encoded, "output-format", "ttl"); }
			for (var p in this.pragmas) { encoded = addParam(encoded, p, this.pragmas[p]); }
		    }

		} else if (this.virtuoso && (url.match(/^(urn|doi|oai):/i))) {
		    	if (this.virt_proxy_ver != 1) {
				var encoded = this.endpoint + url;
				optObj["noSecurityCookie"] = true;
			} else {
			var encoded = encodeURIComponent(url);
				encoded = addParam(endpoint + encoded, "force", "rdf");
			if (url.match(/\.n3$/)) { encoded = addParam(encoded, "output-format", "n3"); }
			if (url.match(/\.ttl$/)) { encoded = addParam(encoded, "output-format", "ttl"); }
			for (var p in this.pragmas) { encoded = addParam(encoded, p, this.pragmas[p]); }
		    }
		} else if (url.match(/^(urn|doi|oai|http):/i)) { /* other than Virtuoso: */
			var encoded = endpoint + decodeURIComponent(url);
			optObj["noSecurityCookie"] = true;
		} else { /* relative uri */
			var encoded = url;
		}
		var cb = function(data) { if (callback) { callback(endpoint,data); } }
		OAT.AJAX.GET(encoded,false,cb,optObj);
	}
}
OAT.Loader.featureLoaded("dereference");
