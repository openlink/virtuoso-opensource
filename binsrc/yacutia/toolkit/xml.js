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
	var xml = Xml.getTreeURL(url);
	var xml = Xml.getTreeString(string);
	var xml = Xml.transformURL(xml,url); (url contains XSL file)
 	var xml = Xml.transformString(xml,string); (string contains XSL file)
	var txt = Xml.textValue(elem);
*/

var Xml = {
	textValue:function(elem) {
		if (document.implementation && document.implementation.createDocument) {				
			return elem.textContent;
		} else if (window.ActiveXObject) {
			return elem.text;
		} else {
			alert("Ooops - no XML parser available");
			return false;
		}
	},
	
	getTreeURL:function(url) {
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
			var xsl = document.implementation.createDocument("", "", null);
			xsl.async = false;
			xsl.load(url);
			var xslProc = new XSLTProcessor();
			xslProc.importStylesheet(xsl);
			var result = xslProc.transformToDocument(xml);
			return result;
		} else if (window.ActiveXObject) {
			var xsl = new ActiveXObject("Microsoft.XMLDOM")
			xsl.async = false;
			xsl.load(url);
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
	}
}
