/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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
function generateAPPAnchor(options, app)
{
  var appIRI = app.getAttribute('about');
  var appID = app.id;
  var appHref = app.href;
  var appTarget = app.target;
  var appOnclick = app.onclick;
  var link = app;
  var useRDFB = options.useRDFB;
  var searchECRM = options.searchECRM;
  // If we use a separate image to make a++, then actual anchor is previous sibling
  if (app.tagName == "IMG") {
    link = app.previousSibling;
    appHref = link.href;
  }
  var genRef = function() {
    var ul = OAT.Dom.create("div",{paddingLeft:"5px",marginLeft:"0px"});

    // html link
    /*
    if ((appHref != "javascript: void(0);") && (appHref != "javascript:%20void(0);"))
    {
      var a = OAT.Dom.create("a");

      var img = OAT.Dom.image("/ods/images/icons/web_16.png");
      img.style["border"] = "0px";
      a.appendChild(img);

      a.appendChild(OAT.Dom.text(" Web page"));
      a.href = appHref;
      a.target = appTarget;
      if (appOnclick)
      {
	      OAT.Event.attach(a, "click", function(e) {OAT.AnchorData.window.close(); appOnclick(e);});
      } else {
	      OAT.Event.attach(a, "click", function(e) {OAT.AnchorData.window.close();});
      }

      var elm = OAT.Dom.create("div");
      elm.appendChild(a);
      ul.appendChild(elm);
    }
    */

    // rdf link
    if (appIRI) {
      var a = OAT.Dom.create("a");
      var img = OAT.Dom.image("/ods/images/icons/rdf-icon-16.gif");
      img.style["border"] = "0px";
      a.appendChild(img);

      a.appendChild(OAT.Dom.text(" Data Link (RDF)"));
      a.href = $v('sparqlUrl').replace('_RDF_', appIRI);
      a.target = appTarget;
      OAT.Event.attach(a, "click", function() {OAT.AnchorData.window.close();});
      var elm = OAT.Dom.create("div");
      elm.appendChild(a);
      ul.appendChild(elm);
    }

    if (ul.innerHTML != "") {
      var elm = OAT.Dom.create("hr");
      ul.appendChild(elm);
    }

    var elm = OAT.Dom.create("img");
    elm.src = OAT.Preferences.imagePath+"Ajax_throbber.gif";
    ul.appendChild(elm);

    var cb = function(xmlDoc) {
      OAT.Dom.unlink (ul.lastChild);
      var ns = {R:"http://www.w3.org/2005/sparql-results#"};
      var imgPath = "/ods/images/icons/";
      var u = OAT.Xml.xpath(xmlDoc, "//R:results/R:result/R:binding[@name=\"u\"]", ns);
      var t = OAT.Xml.xpath(xmlDoc, "//R:results/R:result/R:binding[@name=\"t\"]", ns);
      var l = OAT.Xml.xpath(xmlDoc, "//R:results/R:result/R:binding[@name=\"l\"]", ns);

      for (var i=0; i<u.length; i++)
      {
      	var aURL = OAT.Xml.textValue(u[i]);
      	var aLabel = OAT.Xml.textValue(l[i]);
      	var aType = OAT.Xml.textValue(t[i]);
      	var imgSrc = generateAPP_image (aType, imgPath);
      	var tp = "", sm = OAT.Dom.create("small");
      	var pos = aType.lastIndexOf ('#');
      	if (pos == -1) {
      	  aType.lastIndexOf ('/');
      	} else {
      	  tp = aType.substring (pos+1);
      	  tp = ' ('+tp+')';
   	      sm.appendChild(OAT.Dom.text(tp));
      	}
      	var elm = OAT.Dom.create("div", {className:"app_item"});
      	var a = OAT.Dom.create("a");
        if (useRDFB == true) {
          a.href = '/rdfbrowser/index.html?uri='+encodeURIComponent(aURL);
	        a.target = "_blank";
        } else {
	        a.href = aURL;
        }
      	if (imgSrc != "") {
      	  var img = OAT.Dom.image(imgSrc);
      	  img.style["border"] = "0px";
      	  a.appendChild(img);
      	  aLabel = " " + aLabel;
      	}
      	a.appendChild(OAT.Dom.text(aLabel));
      	a.appendChild(sm);
      	elm.appendChild(a);
      	ul.appendChild(elm);
      }
      if (ul.innerHTML == "") {
        ul.innerHTML = "Empty list";
     	}
	  }
    var search;
    //alert (app.childNodes[0].tagName);
    if ((link.childNodes.length == 1) && (link.childNodes[0].tagName == "IMG")) {
	    search = link.childNodes[0].getAttribute("alt");
    } else {
	    search = link.innerHTML;
    }
    OAT.AJAX.GET("/ods_services/search/"+escape(search), false, cb, {type:OAT.AJAX.TYPE_XML, onstart:function(){}, onerror:function(){OAT.Dom.unlink(ul.lastChild);}});
    if (searchECRM) {
      OAT.AJAX.GET("/ods_services/search_ecrm/"+escape(search), false, cb, {type:OAT.AJAX.TYPE_XML, onstart:function(){}, onerror:function(){OAT.Dom.unlink(ul.lastChild);}});
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

function generateAPP_image (aType, imgPath)
{
  var imgSrc = imgPath + "docs_16.png";
  if (aType == 'http://rdfs.org/sioc/ns#User')
    imgSrc = imgPath + "user_16.png";
  else if (aType == 'http://rdfs.org/sioc/types#AddressBook')
    imgSrc = imgPath + "ods_ab_16.png";
  else if (aType == 'http://rdfs.org/sioc/types#Briefcase')
    imgSrc = imgPath + "ods_briefcase_16.png";
  else if (aType == 'http://rdfs.org/sioc/types#BookmarkFolder')
    imgSrc = imgPath + "ods_bookmarks_16.png";
  else if (aType == 'http://rdfs.org/sioc/types#Calendar')
    imgSrc = imgPath + "ods_calendar_16.png";
  else if (aType == 'http://rdfs.org/sioc/types#ImageGallery')
    imgSrc = imgPath + "ods_gallery_16.png";
  else if (aType == 'http://rdfs.org/sioc/types#SurveyCollection')
    imgSrc = imgPath + "ods_poll_16.png";
  else if (aType == 'http://rdfs.org/sioc/types#SubscriptionList')
    imgSrc = imgPath + "ods_feeds_16.png";
  else if (aType == 'http://rdfs.org/sioc/types#Weblog')
    imgSrc = imgPath + "ods_weblog_16.png";
  else if (aType == 'http://rdfs.org/sioc/types#Wiki')
    imgSrc = imgPath + "ods_wiki_16.png";
  return imgSrc;
}

// XXX: please remove this function and patch relevant apps!
function gererateAPP(appArea, optObj)
{
  generateAPP(appArea, optObj);
}

function generateAPP(appArea, optObj)
{
  if (!$(appArea)) {return;}
  var options = {
    title: "URL",
    width: 300,
    height: 200,
    appActivation: "click",
    useRDFB: false,
    searchECRM: false
  }
  for (var p in optObj) {
    options[p] = optObj[p];
  }
  var appLinks = $(appArea).getElementsByTagName("a");
  for (var i = 0; i < appLinks.length; i++) {
    var app = appLinks[i];
    if ((app.id) && (app.id.indexOf('cke_') != 0) && (app.href || app.onclick) && !OAT.Dom.isClass(app, 'noapp')) {
    	var img = OAT.Dom.image("/ods/images/icons/rdf_11.png");
    	img.style["border"] = "0px";
    	img.style["padding"] = "0 0 0 5px";
    	img.id = 'app_id_' + app.id;
    	img.hspace = '1';
    	img.alt = "RDF";
    	img.title = "RDF";
    	var next = app.nextSibling;
    	if (next) {
    	  app.parentNode.appendChild (img);
    	} else {
    	  app.parentNode.insertBefore (img, next);
    	}
    	generateAPPAnchor (options, img, OAT.Dom.isClass(app, 'searchECRM'));
    }
  }
}
