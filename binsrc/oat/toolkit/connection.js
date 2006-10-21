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
	c = new OAT.Connection(OAT.ConnectionDATA.TYPE_XMLA,optObj)
	c.toXML()
	c.fromXML(node)
	
*/
OAT.ConnectionData = { 
	TYPE_XMLA:1,
	TYPE_WSDL:2,
	TYPE_REST:3
}

OAT.Connection = function(type,optObj) {
	var self = this;
	this.type = type;
	switch (type) {
		case OAT.ConnectionData.TYPE_XMLA:
			this.options = {
				endpoint:"",
				dsn:"",
				user:"",
				password:""
			};
		break;
		case OAT.ConnectionData.TYPE_WSDL:
			this.options = {
				url:""
			}
		break;
		case OAT.ConnectionData.TYPE_REST:
			this.options = {
				url:""
			}
		break;
	}
	for (var p in optObj) if (p in this.options) { this.options[p] = optObj[p]; }
	
	this.toXML = function(uid) {
		var xml = '<connection type="'+self.type+'"';
		for (var p in self.options) { 
			var v = self.options[p];
			if (p == "user" || p == "password")  { v = OAT.Crypto.base64e(v); }
			if ((p != "user" && p != "password") || uid) {
				xml += ' '+p+'="';
				xml += v;
				xml += '"'; 
			}
		}
		xml += '/>';
		return xml;
	}
	
	this.fromXML = function(node) {
		for (var p in self.options) {
			var v = node.getAttribute(p);
			if (p == "user" || p == "password")  { v = OAT.Crypto.base64d(v); }
			self.options[p] = v;
		}
	}
}
OAT.Loader.pendingCount--;
