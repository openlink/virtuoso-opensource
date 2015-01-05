/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2015 OpenLink Software
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
	this.nocred = false; /* doesn't require credentials */
	this.uid = false; /* are credentials stored in serialized form? */
	switch (type) {
		case OAT.ConnectionData.TYPE_XMLA:
			this.options = {
				endpoint:OAT.Preferences.endpointXmla,
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

	this.toXML = function(uid, noCreds) {
		var xml = '<connection type="'+self.type+'"';
		for (var p in self.options) {
			var v = self.options[p];
			if (p == "user" || p == "password")  { v = OAT.Crypto.base64e(v); }
			if ((p != "user" && p != "password") || uid) {
				xml += ' '+p+'="';
				xml += OAT.Dom.toSafeXML(v);
				xml += '"';
			}
		}
		xml += ' nocred="'+(noCreds ? 1 : 0)+'"';
		xml += ' uid="'+(uid ? 1 : 0)+'"';
		xml += '/>';
		return xml;
	}

	this.fromXML = function(node) {
		for (var p in self.options) {
			var v = node.getAttribute(p);
			if (p == "user" || p == "password")  { v = OAT.Crypto.base64d(v); }
			self.options[p] = OAT.Dom.fromSafeXML(v);
		}
		var nc = node.getAttribute("nocred");
		if (nc == true) { self.nocred = true; }
		var uid = node.getAttribute("uid");
		if (uid == true) { self.uid = true; }
	}
}
