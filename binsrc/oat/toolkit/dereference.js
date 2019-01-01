/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2019 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	OAT.Dereference.go(url, callback, optObj)
*/

OAT.Dereference = {
    options:{
	endpoint:"/about?url=",	 /* endpoint for dereferencing *this* resource */

	pragmas:{},			/* key->value pairs */

	endpointOpts:{
	    virtuoso:true,		/* is virtuoso? */
	    proxyVersion:1		/* normal proxy type - default */
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

    go:function(url,callback,optObj) {
	var ajaxOpts = {};
	var endpointOpts = {};
	var pragmas = {};
	var direct = false;
	var endpoint = "";

	/* deep copy defaults */

	this.copy(this.options.ajaxOpts,ajaxOpts);
	this.copy(this.options.endpointOpts,endpointOpts);
	this.copy(this.options.pragmas,pragmas);
	endpoint = this.options.endpoint;

	/* now the settings */

	if (optObj) {
	    this.copy(optObj.ajaxOpts,ajaxOpts);
	    this.copy(optObj.endpointOpts,endpointOpts);
	    this.copy(optObj.pragmas,pragmas);
	    if (optObj.endpoint) endpoint = optObj.endpoint;
	}

	if (!optObj.direct) {
	    if (url.match(/^http/i) && endpointOpts.virtuoso) { /* Virtuoso proxy: */
		if (endpointOpts.proxyVersion == 1) {
		    var r = url.match(/^(http[s]?:\/\/)([^@\/]+@)?(.*)/);
		    var user = (r[2] ? r[2].substring(0,r[2].length-1) : false);
		    var encoded = encodeURIComponent(r[1] + r[3]);
		    encoded = this.addParam(endpoint + encoded, "force", "rdf");

		    if (user) { encoded = this.addParam(encoded, "login", encodeURIComponent(user)); }
		    if (url.match(/\.n3$/)) { encoded = this.addParam(encoded, "output-format", "n3"); }
		    else if (url.match(/\.ttl$/)) { encoded = this.addParam(encoded, "output-format", "ttl"); }
		    else 
			encoded = this.addParam(encoded, "output-format","xml");

		    for (var p in pragmas) { encoded = this.addParam(encoded, p, pragmas[p]); }
		} else {
		    var r = url.match(/^(http[s]?:\/\/)([^@\/]+@)?(.*)/);
		    var user = (r[2] ? r[2].substring(0,r[2].length-1) : false);
		    var encoded = (endpoint + r[1] + r[3]);
		    ajaxOpts["noSecurityCookie"] = true;
		}
	    } else if ((url.match(/^urn:/i) ||
			url.match(/^doi:/i) ||
			url.match(/^oai:/i) ||
			url.match(/^nodeid:/i)) && endpointOpts.virtuoso) { /* Virtuoso proxy: */
		if (endpointOpts.proxyVersion == 1) {
		    var encoded = encodeURIComponent(url);
		    encoded = this.addParam(endpoint + encoded, "force", "rdf");
		    if (url.match(/\.n3$/)) { encoded = this.addParam(encoded, "output-format", "n3"); }
		    else if (url.match(/\.ttl$/)) { encoded = this.addParam(encoded, "output-format", "ttl"); }
		    else 
			encoded = this.addParam(encoded, "output-format","xml");
		    for (var p in pragmas) { encoded = this.addParam(encoded, p, pragmas[p]); }
		} else {
		    var encoded = endpoint + url;
		    ajaxOpts["noSecurityCookie"] = true;
		}
	    } else if (url.match(/^urn:/i) ||
		       url.match(/^doi:/i) ||
		       url.match(/^oai:/i) ||
		       url.match(/^http/i)) { /* other than Virtuoso: */
		var encoded = endpoint + decodeURIComponent(url);
		ajaxOpts["noSecurityCookie"] = true;
	    } else { /* relative uri */
		var encoded = url;
	    }
	} else { /* Dereference using supplied endpoint and options. Direct SPARQL queries, etc */
	    encoded = endpoint + url;
	}
	var xhr = OAT.AJAX.GET(encoded,false,callback,ajaxOpts);
	return xhr;
    }
}
