/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2017 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	var txt = OAT.Xml.escape(xml);
	var xml = OAT.Xml.unescape(txt);

	var txt = OAT.Xml.textValue(elem)
	var txt = OAT.Xml.localName(elem)
	var arr = OAT.Xml.childElements(elm)

 	var xml = OAT.Xml.transformXSLT(xmlDoc,xslDoc)
	var xml = OAT.Xml.createXmlDoc(string) (create xmlDoc from string)

	var arr = OAT.Xml.getElementsByLocalName(elm,localName)
	var list = OAT.Xml.getLocalAttribute(elem,localName)

	var xpath = OAT.Xml.xpath(xmlDoc,xpath,nsObject)
	var newXmlText = OAT.Xml.removeDefaultNamespace(xmlText)
*/

OAT.Xml = {
    _getImplementation: function () {
	if (!!document.implementation) return document.implementation;
	if (!!document.getImplementation) return document.getImplementation();
	else 
	    return false;
    },

	textValue:function(elem) {
		/*
			gecko: textContent
			ie: text
			safari: .nodeValue of first child
		*/

		if (!elem) { return; }
	if (window.ActiveXObject) {
	    return elem.text;
	} else if (OAT.Xml._getImplementation()) {
			var result = elem.textContent;
			/* safari hack */
			if (typeof(result) == "undefined") {
				result = elem.firstChild;
				return (result ? result.nodeValue : "");
			}
			return result;
		} else {
		    alert("OAT.Xml.textValue:\nNo XML parser available");
		    return false;
		}
	},

	localName:function(elem) {
		if (!elem) { return; }
		if (OAT.Browser.isIE) {
			return elem.baseName;
		} else {
			return elem.localName;
		}
	},

	createXmlDoc:function(string) {
	var impl = OAT.Xml._getImplementation();
	if (impl && !OAT.Browser.isIE) {
	    if (!string) { return impl.createDocument("","",null); }
			var parser = new DOMParser();
			try {
				var xml = parser.parseFromString(string, "text/xml");
			} catch(e) {
			    alert('OAT.Xml.createXmlDoc:\nXML parse error.');
			}
			return xml;
		} else if (window.ActiveXObject) {
			var xml = new ActiveXObject("Microsoft.XMLDOM");
			if (!string) { return xml; }
			xml.loadXML(string);
			if (xml.parseError.errorCode) {
		alert('OAT.Xml.createXmlDoc:\nIE XML ERROR: ' + 
		      xml.parseError.reason + 
		      ' (' + 
		      xml.parseError.errorCode + ')');
			    return false;
			}
			return xml;
		} else {
		    alert("OAT.Xml.createXmlDoc:\nNo XML parser available");
			return false;
		}
		return false;
	},

	newXmlDoc:function() {
		if (document.implementation && document.implementation.createDocument) {
			var xml = document.implementation.createDocument("","",null);
			return xml;
		} else if (window.ActiveXObject) {
			var xml = new ActiveXObject("Microsoft.XMLDOM")
			return xml;
		} else {
		    alert("OAT.Xml.newXmlDox:\nNo XML parser available");
		    return false;
		}
		return false;
	},

    serializeXmlDoc:function(xmlDoc) {
	if (window.ActiveXObject) {
	    var s = xmlDoc.xml;
	    return s;
	} else if (document.implementation && document.implementation.createDocument) {
	    var ser = new XMLSerializer();
	    try {
		var s = ser.serializeToString(xmlDoc);
		return s;
	    } catch (e) {
		return false;
	    }
	} else {
	    alert("OAT.Xml.serializeXmlDoc:\nNo XML parser available");
	    return false;
	}
	return false;
    },

	transformXSLT:function(xmlDoc,xslDoc,paramsArray) {
		if (document.implementation && document.implementation.createDocument) {
			var xslProc = new XSLTProcessor();
			if (paramsArray) for (var i=0;i<paramsArray.length;i++) {
				var param = paramsArray[i];
				xslProc.setParameter(param[0],param[1],param[2]);
			}
			xslProc.importStylesheet(xslDoc);
			var result = xslProc.transformToDocument(xmlDoc);
			return result;
		} else if (window.ActiveXObject) {
			/* new solution with parameters */
			var freeXslDoc = new ActiveXObject("MSXML2.FreeThreadedDOMDocument");
			freeXslDoc.load(xslDoc);
			var template = new ActiveXObject("MSXML2.XSLTemplate");
			template.stylesheet = freeXslDoc;
			var proc = template.createProcessor();
			proc.input = xmlDoc;
			if (paramsArray) for (var i=0;i<paramsArray.length;i++) {
				var param = paramsArray[i];
				proc.addParameter(param[1],param[2]);
			}
			proc.transform();
			var result = proc.output;
			var rDoc = OAT.Xml.createXmlDoc(result);
			return rDoc;
		} else {
		    alert("OAT.Xml.transformXslt:\nNo XSL parser available");
			return false;
		}
	},

	getElementsByLocalName:function(elem,tagName) {
		var result = [];
		var elems = elem;
		if (!elem) { return result; }
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
		if (!elem) { return result; }
		var all = elem.getElementsByTagName("*");
		for (var i=0;i<all.length;i++) {
			if (all[i].parentNode == elem) { result.push(all[i]); }
		}
		return result;
	},

	getLocalAttribute:function(elm,localName) {
		var all = elm.attributes;
		for (var i=0;i<elm.attributes.length;i++) {
	    if (elm.attributes[i].localName == localName || elm.attributes[i].baseName == localName) { 
		return elm.attributes[i].nodeValue; 
	    }
		}
		return false;
	},

	getLocalAttributes:function(elm) {
		var obj = {};
		if(!elm) { return obj; }
		for (var i=0;i<elm.attributes.length;i++) {
			var att = elm.attributes[i];
			var ln = att.localName;
			var key = ln ? ln : att.baseName;
			obj[key] = att.nodeValue;
		}
		return obj;
	},

    getLocalAttributeNodes:function (elm) {
	var obj = {};
	if (!elm) { return obj; }
	for (var i=0;i<elm.attributes.length;i++) {
	    var att = elm.attributes[i];
	    var ln = att.localName;
	    var key = ln ? ln : att.baseName;
	    obj[key] = att;
	}
	return obj;
    },

    getNsURI:function (elm) {
	return elm.namespaceURI;
    },

    getNsPrefix:function (elm) {
	return elm.prefix;
    },

	xpath:function(xmlDoc,xpath,nsObject) {
		var result = [];
		function resolver(prefix) {
			var b = " ";
			if (prefix in nsObject) { return nsObject[prefix]; }
			if (b in nsObject) { return nsObject[" "]; } /* default ns */
			return ""; /* fallback; should not happen */
		}
		if (window.ActiveXObject) {
		    var tmp = xmlDoc.selectNodes(xpath);
		    for (var i=0;i<tmp.length;i++) { result.push(tmp[i]); }
		    return result;
		} else if (document.evaluate) {
			var it = xmlDoc.evaluate(xpath,xmlDoc,resolver,XPathResult.ANY_TYPE,null);
			var node;
			while ((node = it.iterateNext())) {	result.push(node); }
			return result;
		} else {
	    alert("OAT.Xml.xpath:\nNo Xml Parser available");
			return false;
		}
	},

	removeDefaultNamespace:function(xmlText) {
		var xml = xmlText.replace(/xmlns=['"][^"']*["']/g,"");
		return xml;
	},

	escape:OAT.Dom.toSafeXML,
	unescape:OAT.Dom.fromSafeXML
}
