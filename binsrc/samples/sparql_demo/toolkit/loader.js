/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2006 Ondrej Zara and OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	OAT.Loader.include()
	OAT.Loader.makeDep()
	OAT.Loader.loadAttacher(callback)
*/
window.OAT = {};

Array.prototype.find = function(str) {
	var index = -1;
	for (var i=0;i<this.length;i++) if (this[i] == str) { index = i; }
	return index;
}

String.prototype.trim = function() {
	var result = this.match(/^ *(.*?) *$/);
	return (result ? result[1] : this);
}


OAT.Dependencies = {
	ajax:["dom","crypto"],
	dom:[],
	drag:"dom",
	resize:"dom",
	soap:"ajax",
	tab:"dom",
	window:["dom","mswin","macwin"],
	xmla:["soap","xml"],
	mswin:["drag","resize","dom"],
	macwin:["drag","resize","dom","simplefx"],
	tree:"dom",
	ghostdrag:["dom","animation"],
	instant:"dom",
	animation:"dom",
	quickedit:["dom","instant"],
	dimmer:"dom",
	bezier:[],
	canvas:"dom",
	grid:"dom",
	xml:[],
	combolist:["dom","instant"],
	formobject:["dom","drag","resize","datasource"],
	color:["dom","drag"],
	combobutton:["dom","instant"],
	pivot:["dom","ghostdrag","statistics","instant","barchart"],
	statistics:[],
	upload:"dom",
	validation:"dom",
	combobox:["dom","instant"],
	toolbar:"dom",
	menu:["dom","animation"],
	panelbar:["dom","animation"],
	dock:["dom","animation","ghostdrag"],
	ticker:"dom",
	rotator:"dom",
	calendar:["dom","drag"],
	crypto:[],
	json:[],
	graph:["dom","canvas"],
	dav:["dom","grid","tree","toolbar"],
	sqlquery:[],
	preferences:[],
	barchart:"dom",
	webclip:[],
	bindings:[],
	fisheye:"dom",
	dialog:["dom","window","dimmer"],
	datasource:[],
	gmaps:["gapi","map"],
	ymaps:["map"],
	simplefx:["dom"],
	gapi:[],
	msapi:["map","layers"],
	atlascompat:[],
	layers:[],
	map:[],
	slider:["dom"]
}

OAT.Files = {
	dom:"dom.js",
	drag:"drag.js",
	resize:"resize.js",
	ajax:"ajax.js",
	soap:"soap.js",
	xmla:"xmla.js",
	tab:"tab.js",
	window:"window.js",
	mswin:"mswin.js",
	macwin:"macwin.js",
	tree:"tree.js",
	ghostdrag:"ghostdrag.js",
	instant:"instant.js",
	animation:"animation.js",
	quickedit:"quickedit.js",
	bezier:"bezier.js",
	canvas:"canvas.js",
	grid:"grid.js",
	xml:"xml.js",
	combolist:"combolist.js",
	formobject:"formobject.js",
	color:"color.js",
	combobutton:"combobutton.js",
	pivot:"pivot.js",
	statistics:"statistics.js",
	upload:"upload.js",
	validation:"validation.js",
	combobox:"combobox.js",
	toolbar:"toolbar.js",
	menu:"menu.js",
	panelbar:"panelbar.js",
	dock:"dock.js",
	ticker:"ticker.js",
	rotator:"rotator.js",
	calendar:"calendar.js",
	crypto:"crypto.js",
	json:"json.js",
	dimmer:"dimmer.js",
	graph:"graph.js",
	dav:"dav.js",
	sqlquery:"sqlquery.js",
	preferences:"preferences.js",
	barchart:"barchart.js",
	webclip:["webclip.js","webclipbinding.js"],
	bindings:"bindings.js",
	fisheye:"fisheye.js",
	dialog:"dialog.js",
	datasource:"datasource.js",
	gmaps:"customGoogleLoader.js",
	ymaps:"customYahooLoader.js",
	msapi:"msapi.js",
	simplefx:"simplefx.js",
	gapi:"gmapapi.js",
	layers:"layers.js",
	map:"map.js",
	slider:"slider.js",
	atlascompat:"AtlasCompat.js"
}

OAT.Loader = {
	loadList:{},
	
	safeInit:function(callback) {
		/* load only after all components were included */
		var ref = function() {
			if (OAT.Loader.pendingCount < 1) { callback(); } else { setTimeout(ref,100); }
		}
		setTimeout(ref,500);
	},

	loadAttacher:function(callback) {
		if (window.addEventListener) {
			/* gecko */
			window.addEventListener("load",callback,false);
		} else if (window.attachEvent) {
			/* ie */
			var ref = function() {
				if (document.readyState == "complete") { callback(); } else {
					setTimeout(ref,100);
				}
			}
			setTimeout(ref,500);
		} else {
			/* ??? */
			window["onload"] = callback;
		}
	},

	include:function(file) {
		var path = "";
		if (window.toolkitPath) {
			path = toolkitPath;
			if (path.charAt(path.length-1) != "/") { path += "/"; }
		}
		var value = (typeof(file) == "object" ? file : [file]);
		for (var i=0;i<value.length;i++) {
			var name = path+value[i];
			var script = document.createElement("script");
			script.src = name;
			// alert("including "+name);
			document.getElementsByTagName("head")[0].appendChild(script);
		}
	},

	makeDep:function() {
		/* create loadList object based on featureList, Dependencies and Files */
		OAT.Loader.addFeature("preferences");
		for (var i=0;i<featureList.length;i++) {
			OAT.Loader.addFeature(featureList[i]);
		}
		/* ie compat library */
		if (featureList.find("msapi") != -1 && document.addEventListener) {
			OAT.Loader.addFeature("atlascompat");
		}
	},

	addFeature:function(name) {
		OAT.Loader.loadList[name] = 1;
		var value = OAT.Dependencies[name];
		var arr = (typeof(value) == "object" ? value : [value]);
		for (var i=0;i<arr.length;i++) {
			OAT.Loader.addFeature(arr[i]);
		}
	}
}

OAT.Loader.makeDep();
OAT.Loader.pendingCount = 0;
for (p in OAT.Loader.loadList) { OAT.Loader.pendingCount++; }
for (p in OAT.Loader.loadList) { OAT.Loader.include(OAT.Files[p]); }
