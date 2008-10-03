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
	options:{
		endpoint:"/proxy",	/* can be specified as urlParam */

		urlParams:{},		/* key->value pairs */

		endpointOpts:{
	virtuoso:true, /* if virtuoso proxy is used */
			proxyVersion:1	/* normal proxy type - default */
	},

		ajaxOpts:{}
	},

	addParam:function(url, param, value) {
		if (url.match(/.*\?.*/)) {
			return url + "&" + param + "=" + value;
		} 
		return url + "?" + param + "=" + value;
	},

	copy:function(srcObj,dstObj,propObj) {
		if (!propObj) { propObj = srcObj; }
		for (var p in propObj) { dstObj[p] = srcObj[p]; }
	},

	go:function(u,callback,optObj) {
		var ajaxOpts = {};
		var endpointOpts = {};
		var urlParams = {};

		/* deep copy defaults */
		this.copy(this.options.ajaxOpts,ajaxOpts);
		this.copy(this.options.endpointOpts,endpointOpts);
		this.copy(this.options.urlParams,urlParams);

		/* now the settings */
		this.copy(optObj.ajaxOpts,ajaxOpts);
		this.copy(optObj.endpointOpts,endpointOpts);
		this.copy(optObj.urlParams,urlParams);

		/* endpoint can be specified directly, or via urlparams */

		var endpoint = optObj.endpoint || this.options.endpoint;
		if ("endpoint" in urlParams) { 
			endpoint = urlParams["endpoint"]; 
			delete(urlParams["endpoint"]); 
		}

		/* backward compat */
		urlParams.url = urlParams.url || u;
		var url = urlParams.url;

		if (endpointOpts.virtuoso && url.match(/^http/i)) {
			var r = url.match(/^(http[s]?:\/\/)([^@\/]+@)?(.*)/);
			var user = (r[2] ? r[2].substring(0,r[2].length-1) : false);
			urlParams.url = encodeURIComponent(r[1] + r[3]);
			
			/* triplr-style endpoint cannot process URL params as they are passed through to the remote */
		   	if (endpointOpts.proxyVersion != 1) {
				ajaxOpts["noSecurityCookie"] = true;
		    	} else {
				encoded = this.addParam(endpoint, "force", "rdf");
				if (user) { encoded = this.addParam(encoded, "login", encodeURIComponent(user)); }
				if (url.match(/\.n3$/)) { encoded = this.addParam(encoded, "output-format", "n3"); }
				if (url.match(/\.ttl$/)) { encoded = this.addParam(encoded, "output-format", "ttl"); }
				for (var p in urlParams) { encoded = this.addParam(encoded, p, urlParams[p]); }
		   	}
		} else if (endpointOpts.virtuoso && (url.match(/^(urn|doi|oai):/i))) {
		    if (opt.endpointOpts.proxyVersion != 1) {
				var encoded = endpoint + url;
				ajaxOpts["noSecurityCookie"] = true;
			} else {
				urlParams.url = encodeURIComponent(url);
				var encoded = this.addParam(endpoint, "force", "rdf");
				if (url.match(/\.n3$/)) { encoded = this.addParam(encoded, "output-format", "n3"); }
				if (url.match(/\.ttl$/)) { encoded = this.addParam(encoded, "output-format", "ttl"); }
				for (var p in urlParams) { encoded = this.addParam(encoded, p, urlParams[p]); }
		    }
		} else if (url.match(/^(urn|doi|oai|http):/i)) { /* other than Virtuoso: */
			var encoded = endpoint + decodeURIComponent(url);
			ajaxOpts["noSecurityCookie"] = true;
		} else { /* relative uri */
			var encoded = url;
		}

		var cb = function(data) { if (callback) { callback(data,{endpoint:endpoint,url:url,params:urlParams}); } }
		OAT.AJAX.GET(encoded,false,cb,ajaxOpts);
	}
}
OAT.Loader.featureLoaded("dereference");
