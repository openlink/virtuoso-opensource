/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2009 OpenLink Software
 *
 *  See LICENSE file for details.
 */

var google=window.google||{};
var __gload_count = 0;

function _gwjs(inc) {
	var h = document.getElementsByTagName("head")[0];
	var s = document.createElement("script");
	s.src = inc;
	h.appendChild(s);
}

_gwjs('http://www.google.com/jsapi');

function gmap_last_include() {
	if (window.google.loader && window.google.load) {
		google.loader.ApiKey = OAT.ApiKeys.getKey('gmapapi') || window._apiKey || false;
		google.load("maps","2",{callback: function() { OAT.Loader.featureLoaded("gmaps") }});
	} else if (__gload_count < 5) {
		__gload_count = __gload_count + 1;
		setTimeout(gmap_last_include,1000);
	} else {
		OAT.Loader.featureLoaded("gmaps");
	}
}

setTimeout(gmap_last_include,1000);
