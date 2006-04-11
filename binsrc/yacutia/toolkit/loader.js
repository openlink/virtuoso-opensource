/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
 *  
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *  
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *  
 *  
*/
/*
	Loader.include()
	Loader.makeDep()
	Loader.loadAttacher(callback)
*/

var Dependencies = {
	ajax:["dom","crypto"],
	dom:[],
	drag:["dom"],
	resize:["dom"],
	soap:["ajax"],
	tab:["dom"],
	window:["dom"],
	xmla:["soap"],
	mswin:["window","drag","resize","dom"],
	tree:["dom"],
	ghostdrag:["dom","animation"],
	instant:["dom"],
	animation:["dom"],
	quickedit:["dom","instant"],
	dimmer:["dom"],
	bezier:[],
	canvas:["dom"],
	grid:["dom"],
	xml:[],
	combolist:["dom","instant"],
	formobject:["dom"],
	color:["dom","drag"],
	combobutton:["dom","instant"],
	pivot:["dom","ghostdrag","statistics"],
	statistics:[],
	upload:["dom"],
	validation:["dom"],
	combobox:["dom","instant"],
	toolbar:["dom"],
	menu:["dom","animation"],
	panelbar:["dom","animation"],
	dock:["dom","animation","ghostdrag"],
	ticker:["dom"],
	rotator:["dom"],
	calendar:["dom","drag"],
	crypto:[],
	json:[],
	graph:["dom","canvas"],
	dav:[],
	query:[]
}

var Files = {
	dom:"dom.js",
	drag:"drag.js",
	resize:"resize.js",
	ajax:"ajax.js",
	soap:"soap.js",
	xmla:"xmla.js",
	tab:"tab.js",
	window:"window.js",
	mswin:"mswin.js",
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
	query:"query.js"
}

var Loader = {
	loadList:{},

	loadAttacher:function(callback) {
		if (window.addEventListener) {
			/* gecko */
			window.addEventListener("load",callback,false);
		} else if (window.attachEvent) {
			/* ie */
			window.attachEvent("onload",callback);
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
		var name = path+file;
		var script = document.createElement("script");
		script.src = name;
		// alert("including "+name);
		document.getElementsByTagName("head")[0].appendChild(script);
	},
	
	makeDep:function() {
		/* create fileList array based on featureList, Dependencies and Files */
		for (var i=0;i<featureList.length;i++) {
			Loader.addFeature(featureList[i]);
		}
	},
	
	addFeature:function(name) {
		Loader.loadList[name] = 1;
		for (var i=0;i<Dependencies[name].length;i++) {
			Loader.addFeature(Dependencies[name][i]);
		}
	}
}

Loader.makeDep();
for (p in Loader.loadList) { Loader.include(Files[p]); }
