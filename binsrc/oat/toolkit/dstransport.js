/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2012 OpenLink Software
 *
 *  See LICENSE file for details.
 */

OAT.DSTransport = {};

OAT.DSTransport.SQL = {
	fetch:function(conn,options,index,callback) {
		OAT.Xmla.connection = conn;
		OAT.Xmla.query = options.query;
		var l = (options.cursortype == 1 ? options.limit : 0);
		OAT.Xmla.execute(callback,{limit:l,offset:index});
	},
	parse:function(fetchedData,options,outputFields) {
		return fetchedData;
	},
	options:{
		query:"", /* query text */
		table:"", /* table name; it is up to user to create appropriate query for table */
		limit:50, /* for cursors */
		cursortype:1 /* 0 - Snapshot, 1 - Dynaset */
	}
}

OAT.DSTransport.WSDL = {
	fetch:function(conn,options,index,callback) {
		OAT.WS.invoke(conn.options.url,options.service,callback,options.inputObj);
	},
	parse:function(fetchedData,options,outputFields) {
		var allValues = {};
		var data = [];
		/* analyze maximum count */
		var max = 0;
		for (var i=0;i<outputFields.length;i++) {
			var name = outputFields[i];
			/* find number of appearances of this output field in output object */
			var values = OAT.JSObj.getAllValues(fetchedData,name);
			allValues[name] = values;
			var l = values.length;
			if (l > max) { max = l; }
		}
		for (var i=0;i<max;i++) {
			var row = [];
			for (var j=0;j<outputFields.length;j++) {
				var name = outputFields[j];
				var values = allValues[name];
				var v = (values.length ? values[i % values.length] : "");
				row.push(v);
			}
			data.push(row);
		}
		return [outputFields,data];
	},
	options:{
		service:"", /* name of wsdl service */
		rootelement:"", /* name of root input wsdl element */
		inputobj:false
	}
}

OAT.DSTransport.REST = {
	fetch:function(conn,options,index,callback) {
		OAT.AJAX.GET(conn.options.url,options.query,callback);
	},

	parse:function(fetchedData,options,outputFields) {
		var obj = {};
		var nsObj = {};
		var xmlDoc = false;
		if (options.output == 0) { /* xml */
			/* analyze namespaces */
			var ns = fetchedData.match(/xmlns="([^"]*)"/);
			if (ns) { nsObj[" "] = ns[1]; }
			var ns = fetchedData.match(/xmlns:[^=]+="[^"]*"/g);
			if (ns) for (var i=0;i<ns.length;i++) {
				var tmp = ns[i];
				var r = tmp.match(/xmlns:([^=]+)="([^"]*)"/);
				nsObj[r[1]] = r[2];
			}
			/* BAD HACK FOR GECKO - remove default namespace - THIS IS WRONG AND UGLY!!! */
			var t = fetchedData.replace(/xmlns="[^"]*"/g,"");
			/***/
			xmlDoc = OAT.Xml.createXmlDoc(t);
			obj = OAT.JSObj.createFromXmlNode(xmlDoc.documentElement);
		} else { /* json */
			obj = OAT.JSON.deserialize(text);
		}

		var allValues = {};
		var data = [];
		/* analyze maximum count */
		var max = 0;
		for (var i=0;i<outputFields.length;i++) {
			var name = outputFields[i];
			/* find number of appearances of this output field in output object */
			if (options.xpath) { /* makes sense only for non-JSON data */
				var nodes = OAT.Xml.xpath(xmlDoc,name,nsObj);
				var values = [];
				for (var j=0;j<nodes.length;j++) { values.push(OAT.Xml.textValue(nodes[j])); }
			} else {
				var values = OAT.JSObj.getAllValues(obj,name);
			}
			allValues[name] = values;
			var l = values.length;
			if (l > max) { max = l; }
		}
		for (var i=0;i<max;i++) {
			var row = [];
			for (var j=0;j<outputFields.length;j++) {
				var name = outputFields[j];
				var values = allValues[name];
				var v = (values.length ? values[i % values.length] : "");
				row.push(v);
			}
			data.push(row);
		}
		return [outputFields,data];
	},

	options:{
		query:"", /* querystring */
		output:0, /* 0 = xml, 1 = json */
		xpath:0 /* use xpath for output names? */
	}
}
