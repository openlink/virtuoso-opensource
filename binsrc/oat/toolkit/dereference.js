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
	go:function(url,callback,optObj) {
		if (url.match(/^http/i)) { /* Virtuoso proxy: */
			var r = url.match(/^(http[s]?:\/\/)([^@\/]+@)?(.*)/);
			var user = (r[2] ? r[2].substring(0,r[2].length-1) : false);
			var encoded = encodeURIComponent(r[1] + r[3]);
			encoded = "/proxy?url="+encoded+"&force=rdf";
			if (user) { encoded += "&login="+encodeURIComponent(user); }
			if (url.match(/\.n3$/)) { encoded += "&output-format=n3"; }
			if (url.match(/\.ttl$/)) { encoded += "&output-format=ttl"; }
		} else if (url.match(/^urn:/i) || url.match(/^doi:/i) || url.match(/^oai:/i)) { /* Virtuoso proxy: */
			var encoded = encodeURIComponent(url);
			encoded = "/proxy?url="+encoded+"&force=rdf";
			if (url.match(/\.n3$/)) { encoded += "&output-format=n3"; }
			if (url.match(/\.ttl$/)) { encoded += "&output-format=ttl"; }
		} else {
			var encoded = url;
		}
		OAT.AJAX.GET(encoded,false,callback,optObj);
	}
}
OAT.Loader.featureLoaded("dereference");
