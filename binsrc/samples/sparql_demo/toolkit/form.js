/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2006 Ondrej Zara and OpenLink Software
 *
 *  See LICENSE file for details.
 */

OAT.Form = function(formDesignerObj) {
	var self = this;
	
	this.name = "";
	this.fd = formDesignerObj;
	this.inputFields = []; /* for binding */
	this.outputFields = []; /* provides data to controls */
	this.div=false; /* DOM element */
	this.ds = { /* datasource */
		type:0, /* 0 none, 1 sql, 2 wsdl, ... */
		subtype:0, /* 1 query, 2 saved, 3 table */
		url:"", /* link to saved query or wsdl */
		query:"", /* only for type == 1 (sql) */
		service:"", /* name of wsdl service */
		rootElement:"" /* name of root input wsdl element */
	}
	this.fieldBinding = {
		selfFields:[], /* indexes */
		masterForms:[], /* references */
		masterFields:[] /* indexes */
	}
	this.empty="1"; /* clear when no data available? */
	this.hidden=0;
	this.cursorType=1; /* 0 - Snapshot, 1 - Dynaset */
	this.pageSize = 50;
	this.x=20;
	this.y=0;

	this.clear = function() {
		this.inputFields = [];
		this.outputFields = [];
		this.ds.type = 0; /* none, sql, wsdl... */
		this.ds.subtype = 0; /* query = 1, saved = 2, table = 3 */
		this.ds.url = "";
		this.ds.query = "";
		this.ds.service = "";
		this.ds.rootElement = "";
	}
	
	this.getCoords = function() {
		self.y += 30;
		return [self.x,self.y];
	}
	
	this.toString = function() {
		var num = self.fd.forms.find(self);
		if (self.name) { var name = self.name; } else { var name = "[no name]"; }
		return 	"#"+num+" ("+name+")";
	}
	
	this.refresh = function(callback,do_links) {
		/* we know binding type. let's create columns, relations etc */
		self.inputFields = [];
		self.outputFields = [];
		if (do_links) {
			self.fieldBinding.selfFields = [];
			self.fieldBinding.masterFields = [];
			self.fieldBinding.masterForms = [];
		}
		
		switch (self.ds.type) {
			case 1:
				switch (self.ds.subtype) {
					case 1: /* query */
						var queryObj = new OAT.SqlQuery();
						queryObj.fromString(self.ds.query);
						for (var i=0;i<queryObj.columns.count;i++) { 
							var name = OAT.SqlQueryData.deQualifyMulti(queryObj.columns.getResult(i));
							self.inputFields.push(name);
							self.outputFields.push(name);
						}
						if (do_links) { self.heuristicBind(); }
						callback();
					break;

					case 2: /* saved query */
						var loadRef = function(data) {
							var queryObj = new OAT.SqlQuery();
							queryObj.fromString(data);
							self.ds.query = queryObj.toString(OAT.SqlQueryData.TYPE_SQL);
							for (var i=0;i<queryObj.columns.count;i++) { 
								var name = OAT.SqlQueryData.deQualifyMulti(queryObj.columns.getResult(i));
								self.inputFields.push(name);
								self.outputFields.push(name);
							}
							if (do_links) { self.heuristicBind(); }
							callback();
						}
						OAT.Ajax.command(OAT.Ajax.GET + OAT.Ajax.AUTH_BASIC,self.ds.url,function(){return '';},loadRef,OAT.Ajax.TYPE_TEXT);
					break;

					case 3: /* table */
						var spl = self.ds.url.split(".");
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
							}
							if (do_links) { 
								self.relationalBind(catalog,schema,table,callback);
							} else { callback(); }
						}
						OAT.Xmla.columns(catalog,schema,table,columnRef);
					break; /* all sql subtypes */
				}
			break; /* data source types */
			
			case 2: /* wsdl */
				var wsdl = self.ds.url;
				function getProps(obj) {
					var list = [];
					for (var p in obj) {
						if (typeof(obj[p]) == "object") {
							if (obj[p] instanceof Array) {
								var v0 = obj[p][0];
								if (typeof(v0) == "object") {
									list.append(getProps(v0));
								} else {
									list.push(p);
								}
							} else {
								list.append(getProps(obj[p]));
							}
						} else {
							list.push(p);
						}
					}
					return list;
				}
				
				var paramsRef = function(input,output) {
					/* easy; just first-level */
					for (var p in input) { self.ds.rootElement = p; }
					for (var p in input[self.ds.rootElement]) { self.inputFields.push(p); }
					/* massive; all levels */
					self.outputFields = getProps(output);
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
					self.ds.service = s;
					dialogs.services.hide();
					OAT.WS.listParameters(wsdl,s,paramsRef)
				}
				if (do_links) {
					OAT.WS.listServices(wsdl,servicesRef);
				} else {
					OAT.WS.listParameters(wsdl,self.ds.service,paramsRef);
				}
			break;
		}
	}
	
	this.heuristicBind = function() { /* xxx */
		/* heuristic - automatic binding to parent form */
		for (var i=0;i<self.inputFields.length;i++) {
			var parts = self.inputFields[i].split("."); 
			var sCol = parts.pop();
			/* try to find appropriate column with same name elsewhere: that would be a good masterCol */
			for (var j=0;j<self.fd.forms.length;j++) if (self.fd.forms[j] != self) {
				var f = self.fd.forms[j];
				for (var k=0;k<f.outputFields.length;k++) {
					var mCol = f.outputFields[k].split(".").pop();
					if (sCol == mCol) {
						self.fieldBinding.selfFields.push(i);
						self.fieldBinding.masterFields.push(k);
						self.fieldBinding.masterForms.push(f);
					}
				} /* all other columns */
			} /* all other forms */
		} /* all our columns */
	} /* tryParents */
	
	this.relationalBind = function(catalog,schema,table,callback) {
		/* get foreign keys and try to figure out bindings to masters */
		var fkRef = function(pole) {
			for (var i=0;i<pole.length;i++) {
				/* key = object w/ catalog,schema,table,column */
				var pk = pole[i][0];
				var fk = pole[i][1];
				if (fk.catalog == catalog && fk.schema == schema && fk.table == table) { 
					for (var j=0;j<self.fd.forms.length;j++) {
						var f=self.fd.forms[j];
						var fq = (pk.catalog == "" ? pk.table : pk.catalog+"."+pk.schema+"."+pk.table);
						if (fq == f.ds.url) {
							/* good, let's add binding */
							var index1 = f.outputFields.find(pk.column);
							var index2 = self.inputFields.find(fk.column);
							self.fieldBinding.masterForms.push(f);
							self.fieldBinding.masterFields.push(index1);
							self.fieldBinding.selfFields.push(index2);
						} /* ok */
					} /* for all other forms */
				} /* relation about our table */
			} /* all relations */
			if (callback) { callback(); }
		}
		OAT.Xmla.foreignKeys(catalog,schema,table,fkRef);
	}
} /* Form() */
OAT.Loader.pendingCount--;
