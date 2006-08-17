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
	var xml = OAT.Xml.getTreeString(string);
	var xml = OAT.Xml.createXmlDoc(string); (create xmlDoc from string)
 	var xml = OAT.Xml.transformXSLT(xmlDoc,xslDoc);
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
	
	transformXSLT:function(xmlDoc,xslDoc) {
		if (document.implementation && document.implementation.createDocument) {				
			var xslProc = new XSLTProcessor();
			xslProc.importStylesheet(xslDoc);
			var result = xslProc.transformToDocument(xmlDoc);
			return result;
		} else if (window.ActiveXObject) {
			var result = xmlDoc.transformNode(xslDoc);
			var rDoc = OAT.Xml.createXmlDoc(result);
			return rDoc;
		} else {
			alert("Ooops - no XSL parser available");
			return false;
		}
	},
	
	createXmlDoc:function(string) {
		if (document.implementation && document.implementation.createDocument) {				
			var parser = new DOMParser();
			var xml = parser.parseFromString(string, "text/xml");
			return xml;
		} else if (window.ActiveXObject) {
			var xml = new ActiveXObject("Microsoft.XMLDOM")
			xml.loadXML(string);
			if (xml.parseError.errorCode) {
				alert('IE XML ERROR: '+xml.parseError.reason+' ('+xml.parseError.errorCode+')');
				return false;
			}
			return xml;
		} else {
			alert("Ooops - no XML parser available");
			return false;
		}
		return false;
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
	},
	
	childElements:function(elem) {
		var result = [];
		var all = elem.getElementsByTagName("*");
		for (var i=0;i<all.length;i++) {
			if (all[i].parentNode == elem) { result.push(all[i]); }
		}
		return result;
	},
	
	xpath:function(xmlDoc,xpath,nsObject) {
		var result = [];
		function resolver(prefix) {
			var b = " ";
			if (prefix in nsObject) { return nsObject[prefix]; }
			if (b in nsObject) { return nsObject[" "]; } /* default ns */
			return ""; /* fallback; should not happen */
		}
		if (document.evaluate) {
			var it = xmlDoc.evaluate(xpath,xmlDoc,resolver,XPathResult.ANY_TYPE,null); 
			var node;
			while ((node = it.iterateNext())) {	result.push(node); }
			return result;
		} else if (window.ActiveXObject) {
			var tmp = xmlDoc.selectNodes(xpath);
			for (var i=0;i<tmp.length;i++) { result.push(tmp[i]); }
			return result;
		} else {
			alert("Ooops - no XML parser available");
			return false;
		}
	}
}
OAT.Loader.pendingCount--;
