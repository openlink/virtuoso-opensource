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
var TOC = [];
TOC.push(["ajax.js","ajax.doc.html"]);
TOC.push(["animation.js","animation.doc.html"]);
TOC.push(["bezier.js","bezier.doc.html"]);
TOC.push(["calendar.js","calendar.doc.html"]);
TOC.push(["canvas.js","canvas.doc.html"]);
TOC.push(["color.js","color.doc.html"]);
TOC.push(["combobox.js","combobox.doc.html"]);
TOC.push(["combobutton.js","combobutton.doc.html"]);
TOC.push(["combolist.js","combolist.doc.html"]);
TOC.push(["crypto.js","crypto.doc.html"]);
TOC.push(["dimmer.js","dimmer.doc.html"]);
TOC.push(["dock.js","dock.doc.html"]);
TOC.push(["dom.js","dom.doc.html"]);
TOC.push(["drag.js","drag.doc.html"]);
TOC.push(["ghostdrag.js","ghostdrag.doc.html"]);
TOC.push(["graph.js","graph.doc.html"]);
TOC.push(["grid.js","grid.doc.html"]);
TOC.push(["instant.js","instant.doc.html"]);
TOC.push(["json.js","json.doc.html"]);
TOC.push(["menu.js","menu.doc.html"]);
TOC.push(["mswin.js","mswin.doc.html"]);
TOC.push(["panelbar.js","panelbar.doc.html"]);
TOC.push(["pivot.js","pivot.doc.html"]);
TOC.push(["quickedit.js","quickedit.doc.html"]);
TOC.push(["resize.js","resize.doc.html"]);
TOC.push(["rotator.js","rotator.doc.html"]);
TOC.push(["soap.js","soap.doc.html"]);
TOC.push(["statistics.js","statistics.doc.html"]);
TOC.push(["tab.js","tab.doc.html"]);
TOC.push(["ticker.js","ticker.doc.html"]);
TOC.push(["toolbar.js","toolbar.doc.html"]);
TOC.push(["tree.js","tree.doc.html"]);
TOC.push(["upload.js","upload.doc.html"]);
TOC.push(["validation.js","validation.doc.html"]);
TOC.push(["xml.js","xml.doc.html"]);
TOC.push(["xmla.js","xmla.doc.html"]);
TOC.push(["Event handling basics","events.doc.html"]);

function add_data(data) {
	Dom.clear("content");
	var div = Dom.create("div");
	div.innerHTML = data;
	$("content").appendChild(div);
}

function call_for(file) {
	Ajax.command(Ajax.GET,file,function(){},add_data);
}

function create_ref(elm,file) {
	var callback = function() {	call_for(file);	}
	Dom.attach(elm,"click",callback);
}

function create_toc() {
	Drag.create("toc","toc");
	Window.create("toc",Window.MAXIMIZED);
	Window.createToggle("toggle","toc");
	$("toc")._Window_minimizeFunction = function() { Dom.hide("toc_content"); $("toggle").innerHTML = "+";}
	$("toc")._Window_maximizeFunction = function() { Dom.show("toc_content"); $("toggle").innerHTML = "-";}

	var ul = Dom.create("ul");
	for (var i=0;i<TOC.length;i++) {
		var li = Dom.create("li");
		var a = Dom.create("span");
		a.className = "link";
		a.innerHTML = TOC[i][0];
		li.appendChild(a);
		ul.appendChild(li);
		create_ref(a,TOC[i][1]);
	}
	$("toc_content").appendChild(ul);
}

function init() {
	create_toc();
}