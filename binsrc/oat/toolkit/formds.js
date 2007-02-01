/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2006 Ondrej Zara and OpenLink Software
 *
 *  See LICENSE file for details.
 */

OAT.FormDSData = {
	TYPE_NONE:0,
	TYPE_SQL:1,
	TYPE_SOAP:2,
	TYPE_REST:3,
	TYPE_SPARQL:4,
	TYPE_GDATA:5
}

OAT.FormDS = function(formDesignerObj) {
	var self = this;
	
	this.name = "";
	this.fd = formDesignerObj;
	this.inputFields = []; /* for binding */
	this.outputFields = []; /* provides data to controls */
	this.outputLabels = []; /* alternative labels for outputFields */
	this.type = 0; /* 0 none, 1 sql, 2 wsdl, 3 rest, 4 sparql, 5 gdata */
	this.subtype = 0; /* 1 query, 3 table */
	this.query = ""; /* only for type == 1 or type == 4*/
	this.service = ""; /* name of wsdl service */
	this.rootElement = ""; /* name of root input wsdl element */
	this.xpath = 0; /* use xpath for output names? */
	
	this.connection = false; /* connection object */
	
	this.typeToString = function() {
		switch (self.type) {
			case OAT.FormDSData.TYPE_NONE: return "NONE"; break;
			case OAT.FormDSData.TYPE_SQL: return "SQL"; break;
			case OAT.FormDSData.TYPE_SOAP: return "SOAP/WSDL"; break;
			case OAT.FormDSData.TYPE_REST: return "REST"; break;
			case OAT.FormDSData.TYPE_SPARQL: return "SPARQL"; break;
			case OAT.FormDSData.TYPE_GDATA: return "GDATA"; break;
		}
		return "";
	}

	this.fieldBinding = {
		selfFields:[], /* indexes */
		masterDSs:[], /* references */
		masterFields:[], /* indexes */
		types:[] /* types: 0 - value, 1 - foreign column, 2 - ask at runtime, 3 - user input */
	}
	
	this.hidden = 0;
	this.cursorType = 1; /* 0 - Snapshot, 1 - Dynaset */
	this.pageSize = 50;

	this.clear = function() {
		this.inputFields = [];
		this.outputFields = [];
		this.outputLabels = [];
		this.connection = false;
		this.type = 0; /* none, sql, wsdl... */
		this.subtype = 0; /* query = 1, table = 3 */
		this.table = "";
		this.query = "";
		this.service = "";
		this.rootElement = "";
		this.cursorType = 1;
		this.pageSize = 50;
	}
	
	this.loadSaved = function(savedURL,callback) {
		var qRef = function(data) {
			switch (self.type) {
				case OAT.FormDSData.TYPE_SQL: /* sql */
					var queryObj = new OAT.SqlQuery();
					queryObj.fromString(data);
					self.query = queryObj.toString(OAT.SqlQueryData.TYPE_SQL);
				break;
				case OAT.FormDSData.TYPE_SPARQL: /* sparql */
					self.query = data;
				break;
			}
			if (callback) { callback(); }
		}
		OAT.Ajax.command(OAT.Ajax.GET + OAT.Ajax.AUTH_BASIC,savedURL,function(){return '';},qRef,OAT.Ajax.TYPE_TEXT);
	}
	
	this.refresh = function(callback,do_links) {
		/* we know binding type. let's create columns, relations etc */
		switch (self.type) {
			case OAT.FormDSData.TYPE_NONE: callback();	break;
			case OAT.FormDSData.TYPE_SQL:
				switch (self.subtype) {
					case 1: /* query */
						if (do_links) {
							self.inputFields = [];
							self.outputFields = [];
							self.outputLabels = [];
							var queryObj = new OAT.SqlQuery();
							queryObj.fromString(self.query);
							for (var i=0;i<queryObj.columns.count;i++) { 
								var name = OAT.SqlQueryData.deQualifyMulti(queryObj.columns.getResult(i));
								self.inputFields.push(name);
								self.outputFields.push(name);
								self.outputLabels.push("");
							}
						} else { self.heuristicBind(); }
						callback();
					break;

					case 3: /* table */
						if (do_links) {
							var columnRef = function(pole) {
								for (var i=0;i<pole.length;i++) {
									var name = pole[i].name;
									self.inputFields.push(name);
									self.outputFields.push(name);
									self.outputLabels.push("");
								}
								self.relationalBind(catalog,schema,table,callback);
							}
							var spl = self.table.split(".");
							if (spl.length == 3) { 
								var catalog = spl[0];
								var schema = spl[1];
								var table = spl[2];
							} else {
								var catalog = "";
								var schema = "";
								var table = spl[0];
							}
							self.inputFields = [];
							self.outputFields = [];
							self.outputLabels = [];
							OAT.Xmla.endpoint = self.connection.options.endpoint;
							OAT.Xmla.dsn = self.connection.options.dsn;
							OAT.Xmla.user = self.connection.options.user;
							OAT.Xmla.password = self.connection.options.password;
							OAT.Xmla.columns(catalog,schema,table,columnRef);
						} else { callback(); }
					break; /* all sql subtypes */
				}
			break; /* data source types */
			
			case OAT.FormDSData.TYPE_SOAP: /* wsdl */
				self.inputFields = [];
				self.outputFields = [];
				self.outputLabels = [];
				var wsdl = self.connection.options.url;
				var paramsRef = function(input,output) {
					for (var p in input) { self.rootElement = p; }
					for (var p in input[self.rootElement]) { self.inputFields.push(p); }
					self.outputFields = OAT.JSObj.getStringIndexes(output);
					for (var i=0;i<self.outputFields.length;i++) { self.outputLabels.push(""); }
					callback();
				}
				var servicesRef = function(arr) {
					dialogs.services.show();
					OAT.Dom.clear("services_select");
					for (var i=0;i<arr.length;i++) {
						OAT.Dom.option(arr[i],arr[i],"services_select");
					}
					dialogs.services.ok = selectRef;
				}
				var selectRef = function() {
					var s = $v("services_select");
					self.service = s;
					dialogs.services.hide();
					OAT.WS.listParameters(wsdl,s,paramsRef)
				}
				if (do_links) {
					OAT.WS.listServices(wsdl,servicesRef);
				} else {
					OAT.WS.listParameters(wsdl,self.service,paramsRef);
				}
			break; /* case 2 - wsdl */

			case OAT.FormDSData.TYPE_REST: /* rest */
				if (do_links) {
					self.inputFields = $v("bind_rest_in").split(",");
					self.outputFields = $v("bind_rest_out").split(",");
					self.outputLabels = [];
					for (var i=0;i<self.inputFields.length;i++) {
						self.inputFields[i] = self.inputFields[i].trim();
						self.outputLabels.push("");
					}
					for (var i=0;i<self.outputFields.length;i++) {
						self.outputFields[i] = self.outputFields[i].trim();
					}
				}
				callback();
			break;
			
			case OAT.FormDSData.TYPE_SPARQL: /* sparql */
				self.xpath = 1;
				self.inputFields = [];
				self.outputFields = [];
				self.outputLabels = [];
						var sq = new OAT.SparqlQuery();
						sq.fromString(self.query);
				if (self.query == "") { sq.fromURL(self.connection.options.url); }
						for (var i=0;i<sq.variables.length;i++) {
							self.outputLabels.push(sq.variables[i]);
							self.outputFields.push('//result/binding[@name="'+sq.variables[i]+'"]/node()/text()');
						}
				callback();
					break;
			
			case OAT.FormDSData.TYPE_GDATA:
				self.xpath = 1;
				self.inputFields = [];
				self.outputFields = [];
				self.outputLabels = [];
						self.outputLabels = ["Feed title","Feed ID","Feed description","Feed link","Feed category",
											 "Entry title","Entry ID","Entry description",
											 "Entry date","Entry link","Entry content"];
						self.outputFields = ["//atom:feed/atom:title","//atom:feed/atom:id","//atom:feed/atom:subtitle",
											 '//atom:feed/atom:link[@rel="alternate"][@type="text/html"]/@href',"//atom:feed/atom:category/@term",
											 "//atom:feed/atom:entry/atom:title","//atom:feed/atom:entry/atom:id","//atom:feed/atom:entry/atom:summary",
											 "//atom:feed/atom:entry/atom:published","//atom:feed/atom:entry/atom:link","//atom:feed/atom:entry/atom:content"];
				callback();
			break;
		} /* type switch */
	}
	
	this.heuristicBind = function() {
		if (self.fieldBinding.selfFields.length != 0) { return; }
		
		function relationAllowed(secondDS) {
			/* relation is allowed only with other datasource, which has no relation to us */
			if (secondDS == self) { return false; }
			for (var i=0;i<secondDS.fieldBinding.masterDSs.length;i++) {
				var m = secondDS.fieldBinding.masterDSs[i];
				if (m == self) { return false; }
			}
			return true;
		}
		
		/* heuristic - automatic binding to parent form */
		for (var i=0;i<self.inputFields.length;i++) {
			var parts = self.inputFields[i].split("."); 
			var sCol = parts.pop();
			/* try to find appropriate column with same name elsewhere: that would be a good masterCol */
			for (var j=0;j<self.fd.datasources.length;j++) if (relationAllowed(self.fd.datasources[j])) {
				var ds = self.fd.datasources[j];
				for (var k=0;k<ds.outputFields.length;k++) {
					var mCol = ds.outputFields[k].split(".").pop();
					if (sCol == mCol) {
						self.fieldBinding.selfFields.push(i);
						self.fieldBinding.masterFields.push(k);
						self.fieldBinding.masterDSs.push(ds);
						self.fieldBinding.types.push(1);
					}
				} /* all other columns */
			} /* all other forms */
		} /* all our columns */
	} /* tryParents */
	
	this.relationalBind = function(catalog,schema,table,callback) { /* xxx */
		if (self.fieldBinding.selfFields.length != 0) { return; }

		/* get foreign keys and try to figure out bindings to masters */
		var fkRef = function(pole) {
			for (var i=0;i<pole.length;i++) {
				/* key = object w/ catalog,schema,table,column */
				var pk = pole[i][0];
				var fk = pole[i][1];
				if (fk.catalog == catalog && fk.schema == schema && fk.table == table) { 
					for (var j=0;j<self.fd.datasources.length;j++) {
						var ds=self.fd.datasources[j];
						var fq = (pk.catalog == "" ? pk.table : pk.catalog+"."+pk.schema+"."+pk.table);
						if (fq == ds.table) {
							/* good, let's add binding */
							var index1 = ds.outputFields.find(pk.column);
							var index2 = self.inputFields.find(fk.column);
							self.fieldBinding.masterDSs.push(ds);
							self.fieldBinding.masterFields.push(index1);
							self.fieldBinding.selfFields.push(index2);
							self.fieldBinding.types.push(1);
						} /* ok */
					} /* for all other forms */
				} /* relation about our table */
			} /* all relations */
			if (callback) { callback(); }
		}
		OAT.Xmla.foreignKeys(catalog,schema,table,fkRef);
	}
	
	this.toXML = function(uid) {
		var xml = '';
		var fb = self.fieldBinding;
		var tmp = [];
		for (var j=0;j<fb.masterDSs.length;j++) {
			var value = "false";
			switch (parseInt(fb.types[j])) {
				case 1: /* link to datasource */
					value = self.fd.datasources.find(fb.masterDSs[j]);
				break;
				case 3: /* link to uinput */
					value = self.fd.objects.find(fb.masterDSs[j]);
				break;
			}
			tmp.push(value);
		}
		xml += '\t<ds name="'+self.name+'" ';
		xml += ' cursortype="'+self.cursorType+'" pagesize="'+self.pageSize+'" ';
		xml += ' type="'+self.type+'" subtype="'+self.subtype+'" ';
		xml += ' xpath="'+self.xpath+'" service="'+self.service+'" rootelement="'+self.rootElement+'">\n';
		xml += '\t\t'+self.connection.toXML(uid)+'\n';
		xml += '\t\t<table>'+self.table+'</table>\n';
		xml += '\t\t<query><![CDATA['+self.query+']]></query>\n';
		xml += '\t\t<outputFields>\n';
		for (var j=0;j<self.outputFields.length;j++) {
			xml += '\t\t\t<outputField';
			if (self.outputLabels.length && self.outputLabels[j] != "") { xml += ' label="'+self.outputLabels[j]+'"'; }
			xml += '>'+OAT.Dom.toSafeXML(self.outputFields[j])+'</outputField>\n';
		}
		xml += '\t\t</outputFields>\n';
		xml += '\t\t<inputFields>\n';
		for (var j=0;j<self.inputFields.length;j++) {
			xml += '\t\t\t<inputField>'+self.inputFields[j]+'</inputField>\n';
		}
		xml += '\t\t</inputFields>\n';
		xml += '\t\t<selfFields>\n';
		for (var j=0;j<fb.selfFields.length;j++) {
			xml += '\t\t\t<selfField>'+fb.selfFields[j]+'</selfField>\n';
		}
		xml += '\t\t</selfFields>\n';
		xml += '\t\t<masterFields>\n';
		for (var j=0;j<fb.masterFields.length;j++) {
			xml += '\t\t\t<masterField>'+OAT.Dom.toSafeXML(fb.masterFields[j])+'</masterField>\n';
		}
		xml += '\t\t</masterFields>\n';
		xml += '\t\t<masterDSs>\n';
		for (var j=0;j<tmp.length;j++) {
			xml += '\t\t\t<masterDS>'+tmp[j]+'</masterDS>\n';
		}
		xml += '\t\t</masterDSs>\n';
		xml += '\t\t<types>\n';
		for (var j=0;j<fb.types.length;j++) {
			xml += '\t\t\t<type>'+fb.types[j]+'</type>\n';
		}
		xml += '\t\t</types>\n';
		xml += '\t</ds>\n';
		return xml;
	} /* toXML() */
	
	this.fromXML = function(node) {
		var fb = self.fieldBinding;
		self.name = node.getAttribute("name"); /* name */
		self.pageSize = parseInt(node.getAttribute("pagesize"));
		self.cursorType = parseInt(node.getAttribute("cursortype"));
		self.type = parseInt(node.getAttribute("type"));
		self.subtype = parseInt(node.getAttribute("subtype"));
		self.service = node.getAttribute("service");
		self.xpath = parseInt(node.getAttribute("xpath"));
		self.rootElement = node.getAttribute("rootelement");

		var cnode = node.getElementsByTagName("connection")[0];
		var ctype = parseInt(cnode.getAttribute("type"));
		self.connection = new OAT.Connection(ctype);
		self.connection.fromXML(cnode);
		
		var tablenode = node.getElementsByTagName("table")[0];
		self.table = OAT.Xml.textValue(tablenode);
		var qnode = node.getElementsByTagName("query")[0];
		self.query = OAT.Xml.textValue(qnode);

		var tmp = node.getElementsByTagName("inputField");
		self.inputFields = [];
		for (var j=0;j<tmp.length;j++) {
			self.inputFields.push(OAT.Xml.textValue(tmp[j]));
		}
		var tmp = node.getElementsByTagName("outputField");
		self.outputFields = [];
		self.outputLabels = [];
		for (var j=0;j<tmp.length;j++) {
			var v = OAT.Xml.textValue(tmp[j]);
			self.outputFields.push(OAT.Dom.fromSafeXML(v));
			var l = tmp[j].getAttribute("label");
			v = "";
			if (l && l != "") { v = l; }
			self.outputLabels.push(v);
		}

		var tmp = node.getElementsByTagName("selfField");
		for (var j=0;j<tmp.length;j++) {
			fb.selfFields.push(parseInt(OAT.Xml.textValue(tmp[j])));
		}
		var tmp = node.getElementsByTagName("masterDS");
		for (var j=0;j<tmp.length;j++) {
			var val = OAT.Xml.textValue(tmp[j]);
			fb.masterDSs.push(val);
		}
		var tmp = node.getElementsByTagName("type");
		for (var j=0;j<tmp.length;j++) {
			var val = OAT.Xml.textValue(tmp[j]);
			fb.types.push(val);
		}
		var tmp = node.getElementsByTagName("masterField");
		for (var j=0;j<tmp.length;j++) {
			var val = OAT.Xml.textValue(tmp[j]);
			if (fb.types[j] < 2) {
				fb.masterFields.push(fb.types[j] == 1 ? parseInt(val) : OAT.Dom.fromSafeXML(val));
			} else {
				fb.masterFields.push("");
			}
		} /* for all masterFields */
	} /* fromXML() */
} /* FormDS() */
OAT.Loader.featureLoaded("formds");
