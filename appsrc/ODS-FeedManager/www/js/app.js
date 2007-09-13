/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2007 OpenLink Software
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
*/
function generateAPPList (appIRI, appHref, appTarget, appOnclick) 
{
	var list = [];
	
	var a = OAT.Dom.create("a");
	a.innerHTML = "Data Link (RDF)";
	a.href = $v('sparqlUrl').replace('_RDF_', appIRI);
	a.target = appTarget;
	OAT.Dom.attach(a, "click", function() {
				OAT.AnchorData.window.close();
			}); 	
	list.push(a);

	var a = OAT.Dom.create("a");
	a.innerHTML = "Doc Link (XHTML)";
	a.href = appHref;
	a.target = appTarget;
	if (appOnclick) {
  	OAT.Dom.attach(a, "click", function(e) {
  				OAT.AnchorData.window.close();
  				appOnclick(e);
  			}); 	
  } else {
  	OAT.Dom.attach(a, "click", function(e) {
  				OAT.AnchorData.window.close();
  			}); 	
  }			
	list.push(a);
	
	return list;
}
	
function generateAPPAnchor(listFunction, options, app) 
{
	var appIRI = app.getAttribute('about');
	var appID = app.id;
	var appHref = app.href;
	var appTarget = app.target;
	var appOnclick = app.onclick;
	var genRef = function() {
		var list = listFunction(appIRI, appHref, appTarget, appOnclick, appID);
		var ul = OAT.Dom.create("ul",{paddingLeft:"20px",marginLeft:"0px"});
		for (var i=0;i<list.length;i++) {
			if (list[i]) {
				var elm = OAT.Dom.create("li");
				elm.appendChild(list[i]);
			} else {
				var elm = OAT.Dom.create("hr");
			}
			ul.appendChild(elm);
		}
		return ul;
	}
	
	app.target = '';
	app.onclick = '';
	var paramsObj = {
		title: options.title,
		width: options.width,
		height: options.height,
		content: genRef,
		result_control: false,
		activation: options.appActivation,
		imagePath: options.imagePath
	};
  OAT.Anchor.assign(app.id, paramsObj);
}
	
function gererateAPP(listFunction, optObj) 
{
	var options = {
		title: "URL",
		width: 180,
		height: 80,
		appActivation: "click"
	}
	for (var p in optObj) { this.options[p] = optObj[p]; }
	
	var appLinks = document.getElementsByTagName("a");
	
	for (var i = 0; i < appLinks.length; i++) {
	  var app = appLinks[i];
	  if (OAT.Dom.isClass(app, 'app') && app.getAttribute('about'))
	    generateAPPAnchor (listFunction, options, app);
	}
}
