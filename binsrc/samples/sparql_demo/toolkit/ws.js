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
	OAT.WS.invoke(url,callback,service,paramObj)
	OAT.WS.listServices(wsdlURL,callback) - callback(servicesArray)
	OAT.WS.listParameters(wsdlURL,service,callback) - callback(inputObj,outputObj)
	OAT.WS.getEndpoint(wsdlURL,callback) - callback(endpoint)
*/

OAT.WS = {
	cache:{},
	
	obj2xml:function(obj) {
		var xml = "";
		for (var p in obj) {
			var name = p;
			var value = obj[p];
			if (typeof(value) == "object") {
				var v = OAT.WS.obj2xml(value);
			} else {
				var v = value.toString().replace(/&/g,"&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
			}
			xml += "<"+name+">"+v+"</"+name+">";
		}
		return xml;
	},

	invoke:function(url,service,callback,paramObj) { /* execute */
		/* build request */
		var request = OAT.WS.obj2xml(paramObj);
		/* send request */
		var cback = function(endpoint) {
			var header = {"SOAPAction":service};
			OAT.Soap.command(endpoint, function(){return request;}, function(xmlDoc) {OAT.WS.parseResponse(url,xmlDoc,service,callback);},OAT.Ajax.TYPE_XML,header,true);
		}
		OAT.WS.getEndpoint(url,cback);
	},
	
	getEndpoint:function(url,callback) {
		var ref = function(xmlDoc) {
			var result = [];
			var root = xmlDoc.documentElement;
			var service = OAT.Xml.getElementsByTagName(root,"service")[0];
			var port = OAT.Xml.getElementsByTagName(service,"port")[0];
			var addr = OAT.Xml.getElementsByTagName(port,"address")[0];
			var result = addr.getAttribute("location");
			callback(result);
		}
		OAT.WS.retrieveWSDL(url,ref);
	},
	
	listServices:function(url,callback) { /* list of available services from wsdl */
		var ref = function(xmlDoc) {
			var result = [];
			var root = xmlDoc.documentElement;
			var port = OAT.Xml.getElementsByTagName(root,"portType");
			var ops = OAT.Xml.getElementsByTagName(port[0],"operation");
			for (var i=0;i<ops.length;i++) { result.push(ops[i].getAttribute("name")); }
			callback(result);
		}
		OAT.WS.retrieveWSDL(url,ref);
	},
	
	listParameters:function(url,service,callback) { /* list of input & output parameters for service */
		var ref = function(xmlDoc) {
			/* init */
			var params_in = {};
			var params_out = {};
			var opnames = [];
			var msgnames = [];
			
			/* find proper port */
			var root = xmlDoc.documentElement;
			var port = OAT.Xml.getElementsByTagName(root,"portType");
			var ops = OAT.Xml.getElementsByTagName(port[0],"operation");
			for (var i=0;i<ops.length;i++) { opnames.push(ops[i].getAttribute("name")); }
			var index = opnames.find(service);
			if (index == -1) { return; } /* service does not exist */
			
			/* get input & output message names */
			var input = OAT.Xml.getElementsByTagName(ops[index],"input")[0];
			var output = OAT.Xml.getElementsByTagName(ops[index],"output")[0];
			var inmsg = input.getAttribute("message").split(":").pop(); /* last part after colon */
			var outmsg = output.getAttribute("message").split(":").pop(); /* last part after colon */
			
			/* approproate message nodes */
			var messages = OAT.Xml.getElementsByTagName(root,"message");
			for (var i=0;i<messages.length;i++) { msgnames.push(messages[i].getAttribute("name")); }
			index = msgnames.find(inmsg);
			var inmessage = messages[index];
			index = msgnames.find(outmsg);
			var outmessage = messages[index];
			
			
			/* message parts */
			var params_in = OAT.WS.analyzeType(root,inmessage);
			var params_out = OAT.WS.analyzeType(root,outmessage);
			
			/* done */
			callback(params_in,params_out);
		}
		OAT.WS.retrieveWSDL(url,ref);
	},
	
	parseResponse:function(url,xmlDoc,service,callback) { /* parse response from wsdl-compliant ws */
		window.obj = [];
		window.node = [];
		window.debug = [];
		var parseObject = function(obj,node) {
			window.obj.push(obj);
			window.node.push(node);
			if (typeof(obj) == "object") {
				if (obj instanceof Array) {
					var a = [];
					var elms = OAT.Xml.childElements(node);
					for (var i=0;i<elms.length;i++) { 
						var oneValue = parseObject(obj[0],elms[i])
						a.push(oneValue); 
					}
					return a;
				} else {
					var o = {};
					for (var p in obj) {
						var elm = OAT.Xml.getElementsByTagName(node,p)[0];
						if (elm) { o[p] = parseObject(obj[p],elm); }
					}
					return o;
				}
			} else {
				return OAT.Xml.textValue(node);
			}
		}
	
		var root = xmlDoc.documentElement;
		var obj = {};
		var ref = function(inp,outp) {
			/* parse response xml according to appropriate output parameters definition */
			for (var p in outp) {
				var elm = OAT.Xml.getElementsByTagName(root,p)[0];
				obj[p] = parseObject(outp[p],elm);
			} /* for all expected returned nodes */
			
			callback(obj);
		}
		OAT.WS.listParameters(url,service,ref);
	},

	analyzeType:function(root,messageNode) {
		var schemas = OAT.Xml.getElementsByTagName(root,"schema");
		var result = {};
		var tmp = {};
		var parts = OAT.Xml.getElementsByTagName(messageNode,"part");
		var numElems = 0;
		for (var i=0;i<parts.length;i++) {
			var elm = parts[i];
			if (elm.getAttribute("type")) {
				/* type */
				var t = elm.getAttribute("type").split(":").pop();
				tmp[elm.getAttribute("name")] = OAT.Schema.getType(schemas,t);
			} else {
				/* element */
				numElems++;
				var ename = elm.getAttribute("element").split(":").pop();
				tmp[ename] = OAT.Schema.getElement(schemas,ename);
			}
		}
		if (numElems > 0) { result = tmp; } else {
			result[messageNode.getAttribute("name")] = tmp;
		}
		return result;
	},
	
	retrieveWSDL:function(url,callback) { /* internal routine to retrieve wsdl; either from url or cache */
		if (url in OAT.WS.cache) { 
			callback(OAT.WS.cache[url]); 
		} else {
			var ref = function(xmlDoc) {
				OAT.WS.cache[url] = xmlDoc;
				callback(xmlDoc);
			}
			OAT.Ajax.command(OAT.Ajax.GET,url,function(){return '';},ref,OAT.Ajax.TYPE_XML,{});
		}
	}
	
}

OAT.Loader.pendingCount--;
