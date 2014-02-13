/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2014 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	var d = new OAT.DataSource(type);
	d.connection = ...
	d.options.xxx = yyy

	d.reset();

	d.bindRecord(simpleCallback);
	d.bindPage(multiCallback);
	d.bindFile(fileCallback);
	d.bindEmpty(emptyCallback);
	d.bindHeader(headerCallback);

	d.advanceRecord(something, ignoreDups);   something: "-1","+1",number
*/

OAT.DataSourceData = {
	TYPE_NONE:0,
	TYPE_SQL:1,
	TYPE_SOAP:2,
	TYPE_REST:3,
	TYPE_SPARQL:4,
	TYPE_GDATA:5
}

OAT.DataSource = function(type) {
	var self = this;
	this.name = "";
	this.type = type; /* 0 none, 1 sql, 2 wsdl, 3 rest, 4 sparql, 5 gdata */
	this.options = {};

	/* design features */
	this.inputFields = []; /* for binding */
	this.outputFields = []; /* provides data to controls */
	this.outputLabels = []; /* alternative labels for outputFields */

	this.connection = false; /* connection object */
	this.transport = false; /* transport object */

	/* bindings */
	this.boundRecords = [];
	this.boundPages = [];
	this.boundFiles = [];
	this.boundEmpties = [];
	this.boundHeaders = [];

	/* data */
	this.dataRows = [];
	this.recordIndex = -1; /* 0 .. self.dataRows.length */
	this.pageIndex = -1; /* 0 .. self.dataRows.length */
	this.pageSize = 0; /* if 0 then fetch all */

	switch (self.type) {
		case OAT.DataSourceData.TYPE_SQL: self.transport = OAT.DSTransport.SQL; break;
		case OAT.DataSourceData.TYPE_SOAP: self.transport = OAT.DSTransport.WSDL; break;
		case OAT.DataSourceData.TYPE_REST: self.transport = OAT.DSTransport.REST; break;
		case OAT.DataSourceData.TYPE_SPARQL: self.transport = OAT.DSTransport.SPARQL; break;
		case OAT.DataSourceData.TYPE_GDATA:	self.transport = OAT.DSTransport.REST; break;
	}
	for (var p in self.transport.options) { self.options[p] = self.transport.options[p]; } /* read options */
	switch (self.type) {
		case OAT.DataSourceData.TYPE_SQL:
			self.connection = new OAT.Connection(OAT.ConnectionData.TYPE_XMLA);
		break;
		case OAT.DataSourceData.TYPE_SOAP:
			self.connection = new OAT.Connection(OAT.ConnectionData.TYPE_WSDL);
		break;
		case OAT.DataSourceData.TYPE_REST:
			self.connection = new OAT.Connection(OAT.ConnectionData.TYPE_REST);
		break;
		case OAT.DataSourceData.TYPE_SPARQL:
			self.connection = new OAT.Connection(OAT.ConnectionData.TYPE_REST);
			self.options.xpath = 1;
			self.inputFields = [];
			self.outputFields = [];
			self.outputLabels = [];
		break;
		case OAT.DataSourceData.TYPE_GDATA:
			self.connection = new OAT.Connection(OAT.ConnectionData.TYPE_REST);
			self.options.xpath = 1;
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
		break;
	}

	this.bindEmpty = function(callback) {
		var index = self.boundEmpties.length;
		self.boundEmpties.push(callback);
		return index;
	}

	this.bindFile = function(callback) {
		var index = self.boundFiles.length;
		self.boundFiles.push(callback);
		return index;
	}

	this.bindRecord = function(callback) {
		var index = self.boundRecords.length;
		self.boundRecords.push(callback);
		return index;
	}

	this.bindPage = function(callback) {
		/* page == set of records */
		var index = self.boundPages.length;
		self.boundPages.push(callback);
		return index;
	}

	this.bindHeader = function(callback) {
		var index = self.boundHeaders.length;
		self.boundHeaders.push(callback);
		return index;
	}

	this.unBindEmpty = function(index) {
		self.boundEmpties.splice(index,1);
	}

	this.unBindFile = function(index) {
		self.boundFiles.splice(index,1);
	}

	this.unBindRecord = function(index) {
		self.boundRecords.splice(index,1);
	}

	this.unBindPage = function(index) {
		self.boundPages.splice(index,1);
	}

	this.unBindHeader = function(index) {
		self.boundHeaders.splice(index,1);
	}

	this.reset = function() {
		self.recordIndex = -1;
		self.pageIndex = -1;
		self.dataRows = [];
	}

	this.checkAvailability = function(index,strict) { /* test data for presence */
		/* we want PAGE starting at 'index'. is it possible? */
		/*
			a) all data cached -> true
			b) all data missing -> false
			c) some data present -> true <=> !strict
		*/
		if (!self.pageSize) { return (strict ? false : true); }
		var end = index + self.pageSize;
		var count = 0;
		for (var i=index;i<end;i++) {
			if (self.dataRows[i]) { count++; }
		}
		if (!count) { return false; }
		if (count == self.pageSize) { return true; }
		return (strict ? false : true);
	}

	/* add data to cache */
	this.processData = function(data,index) {
		self.header = data[0];
		var d = data[1];
		for (var i=0;i<d.length;i++) {
			self.dataRows[i+index] = d[i];
		}
		if (self.recordIndex == -1) {
			/* very first time data arrived: headers, maybe blank */
			if (self.oneShotCallback) { self.oneShotCallback(); }
			for (var i=0;i<self.boundHeaders.length;i++) { self.boundHeaders[i](self.header); }
			if (!self.dataRows[index]) {
				for (var i=0;i<self.boundEmpties.length;i++) { self.boundEmpties[i](); }
			}
		}
	}

	this.fetchRecord = function(index,callback) {  /* retrieve one record from cache */
		/* never sends queries, since appropriate page has to be received first! */
		if (self.dataRows[index]) { callback(); }
	}

	this.fetchPage = function(index,callback) { /* retrieve one page; either from cache or db */
		if (self.checkAvailability(index,true)) { callback(); return; }
		var ref = function(data) {
			for (var i=0;i<self.boundFiles.length;i++) { self.boundFiles[i](data); }
			var parsed = self.transport.parse(data,self.options,self.outputFields);
			self.processData(parsed,index);
			if (self.checkAvailability(index,false)) { callback(); }
		}

		var options = self.options;
		if ("limit" in options) { options.limit = self.pageSize; }

		self.transport.fetch(self.connection,options,index,ref);
	}

	this.getNewIndex = function(something,index,size) { /* calculate new index */
		/* get new index number specified by 'something', when located @ index with page size 'size' */
		var newIndex = -1;
		if (typeof(something) == "string") {
//			if (something == "+1" && (index+1)*size < self.count) { newIndex = index+1; }
			if (something == "+1") { newIndex = index+1; }
			if (something == "-1" && index > 0) { newIndex = index-1; }
		} else {
//			if (something >= 0 && something*size < self.count) { newIndex = something; }
			if (something >= 0) { newIndex = something; }
		}
		return newIndex;
	}

	this.advanceRecord = function(something) { 	/* go to record # */
		/* get the record number we want */
		var newIndex = self.getNewIndex(something,self.recordIndex,1); /* this is new requested index */
		if (newIndex == -1 || newIndex == self.recordIndex) { return false; } /* do nothing if is not correct or the present one */
		var newPageIndex = (self.pageSize ? Math.floor(newIndex / self.pageSize) : 0) * self.pageSize;
		/* sometimes we also have to change page */
		OAT.MSG.send(self,"DS_RECORD_PREADVANCE",newIndex);
		var callback = function() {
			self.recordIndex = newIndex;
			/* populate objects based on current index */
			var data = self.dataRows[self.recordIndex];
			OAT.MSG.send(self,"DS_RECORD_ADVANCE",[data,self.recordIndex]);
			for (var i=0;i<self.boundRecords.length;i++) {
				/* notify all receiving objects */
				self.boundRecords[i](data,self.recordIndex);
			}
		}
		var command = function() { self.fetchRecord(newIndex,callback); }
		if (newPageIndex == self.pageIndex) { command(); } else {
			self.advancePage(newPageIndex,command);
		}
		return true;
	}

	this.advancePage = function(newIndex,command) { /* go to page #, not to be directly called! */
		OAT.MSG.send(self,"DS_PAGE_PREADVANCE",newIndex);
		/* get the page we want */
		var callback = function() {
			var data = [];
			self.pageIndex = newIndex;
			var l = (self.pageSize ? Math.min(self.pageSize+self.pageIndex,self.dataRows.length) : self.dataRows.length);
			for (var j=self.pageIndex;j<l;j++) {
				data.push(self.dataRows[j]);
			}
			OAT.MSG.send(self,"DS_PAGE_ADVANCE",[data,self.pageIndex]);
			for (var i=0;i<self.boundPages.length;i++) {
				self.boundPages[i](data,self.pageIndex);
			} /* all page requesting objects */
			command();
		}
		self.fetchPage(newIndex,callback);
	}

	this.typeToString = function() {
		switch (self.type) {
			case OAT.DataSourceData.TYPE_NONE: return "NONE"; break;
			case OAT.DataSourceData.TYPE_SQL: return "SQL"; break;
			case OAT.DataSourceData.TYPE_SOAP: return "SOAP/WSDL"; break;
			case OAT.DataSourceData.TYPE_REST: return "REST"; break;
			case OAT.DataSourceData.TYPE_SPARQL: return "SPARQL"; break;
			case OAT.DataSourceData.TYPE_GDATA: return "GDATA"; break;
		}
		return "";
	}

	this.fieldBinding = {
		selfFields:[], /* indexes */
		masterDSs:[], /* references */
		masterFields:[], /* indexes */
		types:[] /* types: 0 - value, 1 - foreign column, 2 - ask at runtime, 3 - user input */
	}

	this.loadSaved = function(savedURL,callback) {
		var qRef = function(data) {
			switch (self.type) {
				case OAT.DataSourceData.TYPE_SQL: /* sql */
					var queryObj = new OAT.SqlQuery();
					queryObj.fromString(data);
					self.query = queryObj.toString(OAT.SqlQueryData.TYPE_SQL);
				break;
				case OAT.DataSourceData.TYPE_SPARQL: /* sparql */
					self.query = data;
				break;
			}
			if (callback) { callback(); }
		}
		OAT.AJAX.GET(savedURL,false,qRef);
	}

	this.refresh = function(callback,do_links,datasources) {
		/* we know binding type. let's create columns, relations etc */
		switch (self.type) {
			case OAT.DataSourceData.TYPE_NONE: callback();	break;
			case OAT.DataSourceData.TYPE_SQL:
				if (self.options.table) { /* table */
					if (do_links) {
						var spl = self.options.table.split(".");
						if (spl.length == 3) {
							var catalog = spl[0];
							var schema = spl[1];
							var table = spl[2];
						} else {
							var catalog = "";
							var schema = "";
							var table = spl[0];
						}
						var columnRef = function(pole) {
							for (var i=0;i<pole.length;i++) {
								var name = pole[i].name;
								self.inputFields.push(name);
								self.outputFields.push(name);
								self.outputLabels.push("");
							}
							self.relationalBind(datasources,catalog,schema,table,callback);
						}
						self.inputFields = [];
						self.outputFields = [];
						self.outputLabels = [];
						OAT.Xmla.connection = self.connection;
						OAT.Xmla.columns(catalog,schema,table,columnRef);
					} else { callback(); }
				} else { /* query */
					if (do_links) {
						self.inputFields = [];
						self.outputFields = [];
						self.outputLabels = [];
						var queryObj = new OAT.SqlQuery();
						queryObj.fromString(self.options.query);
						for (var i=0;i<queryObj.columns.count;i++) {
							var name = OAT.SqlQueryData.deQualifyMulti(queryObj.columns.getResult(i));
							self.inputFields.push(name);
							self.outputFields.push(name);
							self.outputLabels.push("");
						}
						self.heuristicBind(datasources);
					}
					callback();
				}
				break;

			case OAT.DataSourceData.TYPE_SOAP: /* wsdl */
				self.inputFields = [];
				self.outputFields = [];
				self.outputLabels = [];
				var wsdl = self.connection.options.url;
				var paramsRef = function(input,output) {
					for (var p in input) { self.options.rootelement = p; }
					for (var p in input[self.options.rootelement]) { self.inputFields.push(p); }
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
					self.options.service = s;
					dialogs.services.hide();
					OAT.WS.listParameters(wsdl,s,paramsRef)
				}
				if (do_links) {
					OAT.WS.listServices(wsdl,servicesRef);
				} else {
					OAT.WS.listParameters(wsdl,self.options.service,paramsRef);
				}
			break; /* case 2 - wsdl */

			case OAT.DataSourceData.TYPE_REST: /* rest */
				if (do_links) {
					self.inputFields = $v("bind_rest_in").split(",");
					self.outputFields = $v("bind_rest_out").split(",");
					if (self.inputFields.length == 1 && self.inputFields[0] == "") { self.inputFields = []; }
					if (self.outputFields.length == 1 && self.outputFields[0] == "") { self.outputFields = []; }
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

			case OAT.DataSourceData.TYPE_SPARQL: /* sparql */
				var sq = new OAT.SparqlQuery();
				sq.fromString(self.options.query);
				if (self.options.query == "") { sq.fromString(self.connection.options.url); }
				for (var i=0;i<sq.variables.length;i++) {
					self.outputLabels.push(sq.variables[i]);
					self.outputFields.push('//result/binding[@name="'+sq.variables[i]+'"]/node()/text()');
				}
				callback();
			break;

			case OAT.DataSourceData.TYPE_GDATA:
				callback();
			break;
		} /* type switch */
	}

	this.heuristicBind = function(datasources) {
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
			for (var j=0;j<datasources.length;j++) if (relationAllowed(datasources[j])) {
				var ds = datasources[j];
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

	this.relationalBind = function(datasources,catalog,schema,table,callback) { /* xxx */
		if (self.fieldBinding.selfFields.length != 0) { return; }

		/* get foreign keys and try to figure out bindings to masters */
		var fkRef = function(pole) {
			for (var i=0;i<pole.length;i++) {
				/* key = object w/ catalog,schema,table,column */
				var pk = pole[i][0];
				var fk = pole[i][1];
				if (fk.catalog == catalog && fk.schema == schema && fk.table == table) {
					for (var j=0;j<datasources.length;j++) {
						var ds=datasources[j];
						var fq = (pk.catalog == "" ? pk.table : pk.catalog+"."+pk.schema+"."+pk.table);
						if (fq == ds.table) {
							/* good, let's add binding */
							var index1 = ds.outputFields.indexOf(pk.column);
							var index2 = self.inputFields.indexOf(fk.column);
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

	this.toXML = function(uid,datasources,objects,nocred) {
		var xml = '';
		var fb = self.fieldBinding;
		var tmp = [];
		for (var j=0;j<fb.masterDSs.length;j++) {
			var value = "false";
			switch (parseInt(fb.types[j])) {
				case 1: /* link to datasource */
					value = datasources.indexOf(fb.masterDSs[j]);
				break;
				case 3: /* link to uinput */
					value = objects.indexOf(fb.masterDSs[j]);
				break;
			}
			tmp.push(value);
		}
		xml += '\t<ds name="'+self.name+'" type="'+self.type+'" pagesize="'+self.pageSize+'">\n';
		xml += '\t\t'+self.connection.toXML(uid,nocred)+'\n';
		xml += '\t\t<options';
		for (var p in self.options) {
			if (p != "query") { xml += ' '+p+'="'+self.options[p]+'"'; }
		}
		xml += '/>\n';
		if ("query" in self.options) {
			xml += '\t\t<query><![CDATA['+self.options.query+']]></query>\n';
		}
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
		self.pageSize = parseInt(node.getAttribute("pagesize")); /* name */

		if (node.getAttribute("subtype")) {
			/* compatibility mode */
			for (var p in self.options) { self.options[p] = node.getAttribute(p); }
			if ("table" in self.options) {
				var tablenode = node.getElementsByTagName("table")[0];
				self.options.table = OAT.Xml.textValue(tablenode);
				if (self.options.table == "undefined") { self.options.table = ""; }
				if (self.options.table == "false") { self.options.table = ""; }
			}
			if ("limit" in self.options) { self.options.limit = self.pageSize; }
			if ("output" in self.options) { self.options.output = parseInt(node.getAttribute("subtype")); }
		} else {
			/* standard mode */
			var opts = node.getElementsByTagName("options")[0];
			for (var p in self.options) {
				self.options[p] = opts.getAttribute(p);
				if (p == "table" && self.options[p] == "false") { self.options[p] = false; }
			}
		}
		if ("query" in self.options) {
			var qnode = node.getElementsByTagName("query")[0];
			self.options.query = OAT.Xml.textValue(qnode);
		}

		var cnode = node.getElementsByTagName("connection")[0];
		var ctype = parseInt(cnode.getAttribute("type"));
		self.connection = new OAT.Connection(ctype);
		self.connection.fromXML(cnode);

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
			fb.types.push(parseInt(val));
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
} /* DataSource() */
