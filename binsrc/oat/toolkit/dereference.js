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
		if (url.match(/^http/i)) {
			var encoded = encodeURIComponent(url);
			/* Virtuoso proxy: */
			encoded = "/proxy?url="+encoded+"&force=rdf";
		} else {
			var encoded = url;
		}
		OAT.AJAX.GET(encoded,false,callback,optObj);
	}
}
OAT.Loader.featureLoaded("dereference");
