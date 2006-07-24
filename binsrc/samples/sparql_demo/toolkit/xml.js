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
	var xml = OAT.Xml.getTreeURL(url);
	var xml = OAT.Xml.getTreeString(string);
	var xml = OAT.Xml.transformURL(xml,url); (url contains XSL file)
 	var xml = OAT.Xml.transformString(xml,string); (string contains XSL file)
	var txt = OAT.Xml.textValue(elem);
	var list = OAT.Xml.getElementsByTagName(elem,tagName);
*/

OAT.Xml = {
	textValue:function(elem) {
		if (document.implementation && document.implementation.createDocument) {				
			var result = elem.textContent;
			/* safari hack */
			if (typeof(result) == "undefined") { 
				result = elem.firstChild; 
				return (result ? result.data : "");
			}
			return result;
		} else if (window.ActiveXObject) {
			return elem.text;
		} else {
			alert("Ooops - no XML parser available");
			return false;
		}
	},
	
	getTreeURL:function(url) {
/* to be thoroughly tested: */
		var xml = OAT.Sjax.command(url);
		return xml;
/* */

		if (document.implementation && document.implementation.createDocument) {				
			var xml = document.implementation.createDocument("", "", null);
			xml.async = false;
			xml.load(url);
			return xml;
		} else if (window.ActiveXObject) {
			var xml = new ActiveXObject("Microsoft.XMLDOM");
			xml.async = false;
			xml.load(url);
			return xml;
		} else {
			alert("Ooops - no XML parser available");
			return false;
		}
	},

	getTreeString:function(string) {
		if (document.implementation && document.implementation.createDocument) {				
			var parser = new DOMParser();
			var xml = parser.parseFromString(string, "text/xml");
			return xml;
		} else if (window.ActiveXObject) {
			var xml = new ActiveXObject("Microsoft.XMLDOM");
			xml.async = false;
			xml.loadXML(string);
			return xml;
		} else {
			alert("Ooops - no XML parser available");
			return false;
		}
	},
	
	transformURL:function(xml,url) {
		if (document.implementation && document.implementation.createDocument) {				
			var xsl = OAT.Xml.getTreeURL(url);
/*			var xsl = document.implementation.createDocument("", "", null);
			xsl.async = false;
			xsl.load(url);*/
			var xslProc = new XSLTProcessor();
			xslProc.importStylesheet(xsl);
			var result = xslProc.transformToDocument(xml);
			return result;
		} else if (window.ActiveXObject) {
			var xsl = OAT.Xml.getTreeURL(url);
			var result = xml.transformNode(xsl);
			return result;
		} else {
			alert("Ooops - no XML parser available");
			return false;
		}
	},
	
	transformString:function(xml,string) {
		if (document.implementation && document.implementation.createDocument) {				
			var parser = new DOMParser();
			var xsl = parser.parseFromString(string, "text/xml");
			var xslProc = new XSLTProcessor();
			xslProc.importStylesheet(xsl);
			var result = xslProc.transformToDocument(xml);
			return result;
		} else if (window.ActiveXObject) {
			var xsl = new ActiveXObject("Microsoft.XMLDOM")
			xsl.async = false;
			xsl.loadXML(url);
			var result = xml.transformNode(xsl);
			return result;
		} else {
			alert("Ooops - no XML parser available");
			return false;
		}
	},
	
	getElementsByTagName:function(elem,tagName) {
		var result = [];
		var elems = elem;
		if (!(elems instanceof Array)) { elems = [elem]; }
		for (var i=0;i<elems.length;i++) {
			var all = elems[i].getElementsByTagName("*");
			for (var j=0;j<all.length;j++) 
				if (all[j].localName == tagName || all[j].baseName == tagName) { result.push(all[j]); }
		}
		return result;
	}
}
OAT.Loader.pendingCount--;
