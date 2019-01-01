/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2019 OpenLink Software
 *
 *  See LICENSE file for details.
 */

/*
*/

OAT.Form = function(targetElm,optObj) {
	var self = this;
	this.options = {
		onReady:function(){},
		onDone:function(){},
		user:false,
		password:false
	}
	for (var p in optObj) { self.options[p] = optObj[p]; }
	this.div = $(targetElm)
	this.datasources = [];
	this.objects = [];
	this.dialogs = {};
	this.sqlDS = [];

	this.paramsDiv = OAT.Dom.create("div");
	this.credsDiv = OAT.Dom.create("div");
	this.credsDiv.innerHTML = '<table><tr><td class="right">Name: </td>'+
	'<td><input name="cred_user" value="demo" type="text" id="cred_user" /></td></tr>'+
	'<tr><td class="right">Password: </td>'+
	'<td><input name="cred_password" value="demo" type="password" id="cred_password" /></td></tr></table>';

	this.getValue = function(fb,index) {
		switch (fb.types[index]) {
			case 0: /* typed at designtime */
			case 2: /* typed at runtime */
				var val = fb.masterFields[index];
			break;
			case 1: /* another form */
				var master = fb.masterDSs[index];
				var masterFieldIndex = master.usedFields[fb.masterFields[index]];
				var val = master.lastRow[masterFieldIndex];
			break;
			case 3: /* uinput */
				var val = $v(fb.masterDSs[index].input);
			break;
		}
		return val;
	}

	this.buildQuery = function(ds) {
		var fb = ds.fieldBinding;
		if (!ds._oldQuery) { ds._oldQuery = ds.options.query; }
		/* easy way */
		if (!fb.masterDSs.length) { return ds._oldQuery; }
		/* hard way */
		var queryObj = new OAT.SqlQuery();
		queryObj.fromString(ds._oldQuery);
		for (var i=0;i<fb.masterDSs.length;i++) {
			if (queryObj.groups.count) {
				var c = queryObj.havings.add();
			} else {
				var c = queryObj.conditions.add();
			}
			c.logic = "AND";
			c.operator = "=";
			var selfFieldIndex = ds.usedFields[fb.selfFields[i]];
			c.column = OAT.SqlQueryData.qualifyOne(queryObj.columns.items[selfFieldIndex].column);
			var val = self.getValue(fb,i);
			if (isNaN(val) || val == "") { val = "'"+val+"'"; }
			c.value = val;
		}
		return queryObj.toString(OAT.SqlQueryData.TYPE_SQL);
	}

	this.buildWSDL = function(ds) {
		var fb = ds.fieldBinding;
		var inputObj = {};
		for (var i=0;i<ds.inputFields.length;i++) {
			inputObj[ds.inputFields[i]] = "";
		}
		for (var i=0;i<fb.masterDSs.length;i++) {
			var index = fb.selfFields[i];
			var column = ds.inputFields[index];
			var val = self.getValue(fb,i);
			inputObj[column] = val;
		}
		var result = {};
		result[ds.rootElement] = inputObj;
		return result;
	}

	this.buildREST = function(ds) {
		var fb = ds.fieldBinding;
		var pairs = {};
		for (var i=0;i<ds.inputFields.length;i++) {
			pairs[ds.inputFields[i]] = "";
		}
		for (var i=0;i<fb.masterDSs.length;i++) {
			var index = fb.selfFields[i];
			var column = ds.inputFields[index];
			var val = self.getValue(fb,i);
			pairs[column] = encodeURIComponent(val);
		}
		var q = [];
		for (var p in pairs) { q.push(p+"="+pairs[p]); }
		return q.join("&");
	}

	this.callForData = function(ds) {
		ds.reset();
		switch (ds.type) {
			case OAT.DataSourceData.TYPE_SQL:
				var q = self.buildQuery(ds);
				if (ds.lastQuery && q == ds.lastQuery) { return; }
				ds.lastQuery = q;
				ds.options.query = q;
			break;

			case OAT.DataSourceData.TYPE_SOAP:
				var inputObj = self.buildWSDL(ds);
				ds.options.inputobj = inputObj;
			break;

			case OAT.DataSourceData.TYPE_REST:
				ds.options.query = self.buildREST(ds);
			break;

			case OAT.DataSourceData.TYPE_SPARQL:
				var sq = new OAT.SparqlQuery();
				sq.fromString(ds.options.query);
				var formatStr = sq.variables.length ? "format=xml" : "format=rdf"; /* xml for SELECT, rdf for CONSTRUCT */
				if (ds.options.query != "") { /* query specified in textarea */
					var q = "query="+encodeURIComponent(ds.options.query)+"&"+formatStr;
					ds.options.query = q;
				}
			break;

			case OAT.DataSourceData.TYPE_GDATA:
				var q = ds.options.query ? "q="+encodeURIComponent(ds.options.query) : "";
				ds.options.query = q;
			break;
		}

		/* notify objects that new data will arrive soon */
		for (var i=0;i<self.objects.length;i++) {
			var o = self.objects[i];
			for (var j=0;j<o.datasources.length;j++) {
				var ods = o.datasources[j];
				if (ods.ds == ds && o.notify) { o.notify(); }
			}
		}
		ds.advanceRecord(0);
	}

	this.attachNav = function(nav) {
		var ds = nav.datasources[0].ds;
		OAT.Event.attach(nav.first,"click",function() { ds.advanceRecord(0); });
		OAT.Event.attach(nav.prevp,"click",function() { ds.advanceRecord(ds.recordIndex - ds.pageSize); });
		OAT.Event.attach(nav.prev,"click",function() { ds.advanceRecord("-1"); });
		OAT.Event.attach(nav.next,"click",function() { ds.advanceRecord("+1"); });
		OAT.Event.attach(nav.nextp,"click",function() { ds.advanceRecord(ds.recordIndex + ds.pageSize); });
//					OAT.Event.attach(nav.last,"click",function() { ds.advanceRecord(parseInt(nav.total.innerHTML)-1); });
		OAT.Event.attach(nav.current,"keyup",function(event) {
			if (event.keyCode != 13) { return; }
			var value = parseInt($v(nav.current));
			ds.advanceRecord(value-1);
		});
	}

	this.recomputeFields = function() {
		/* massive re-computation of used fields for table binding */
		for (var i=0;i<self.datasources.length;i++) { /* count used columns */
			var ds = self.datasources[i];
			ds.usedFields = [];
			for (var j=0;j<ds.outputFields.length;j++) { ds.usedFields.push(-1); }
		}
		for (var i=0;i<self.objects.length;i++) {
			var o = self.objects[i];
			for (var j=0;j<o.datasources.length;j++) {
				var ds = o.datasources[j];
				for (var k=0;k<ds.fieldSets.length;k++) {
					var fs = ds.fieldSets[k];
					for (var l=0;l<fs.columnIndexes.length;l++) {
						if (fs.columnIndexes[l] != -1) { ds.ds.usedFields[fs.columnIndexes[l]] = 1; }
					} /* all fs parts */
				} /* for all fieldsets */
			} /* all datasources */
		} /* all objects */

		/* also binding columns need to be included in query */
		for (var i=0;i<self.datasources.length;i++) {
			var ds = self.datasources[i];
			var fb = ds.fieldBinding;
			for (var j=0;j<fb.selfFields.length;j++) {
				ds.usedFields[fb.selfFields[j]] = 1;
			}
			for (var j=0;j<fb.masterDSs.length;j++) {
				var type = fb.types[j];
				if (type == 1) { fb.masterDSs[j].usedFields[fb.masterFields[j]] = 1; }
			}
		}

		/* we have now marked all really used fields */

		/* create right queries */
		for (var i=0;i<self.datasources.length;i++) {
			var ds = self.datasources[i];
			if (ds.type == OAT.DataSourceData.TYPE_SQL && ds.options.table) { /* only table forms */
				var q = [];
				var index = 0;
				for (var j=0;j<ds.usedFields.length;j++) {
					if (ds.usedFields[j] == 1) {
						q.push(ds.outputFields[j]);
						ds.usedFields[j] = index;
						index++;
					} /* if column is used */
				} /* for all used columns */
				if (!q.length) { alert("OAT.Form.recomputeFields:\nThere are no used data fields in the form."); }
				ds.options.query = "SELECT "+q.join(", ")+" FROM "+OAT.SqlQueryData.qualifyMulti(ds.options.table);
			} else {
				for (var j=0;j<ds.usedFields.length;j++) {
					ds.usedFields[j] = j;
				}
				/* non-table bindings have all usedcolumns ok */
			}
		}
		/* create realIndexes */
		for (var i=0;i<self.objects.length;i++) {
			var o = self.objects[i];
			for (var j=0;j<o.datasources.length;j++) {
				var ds = o.datasources[j];
				for (var k=0;k<ds.fieldSets.length;k++) {
					var fs = ds.fieldSets[k];
					fs.realIndexes = [];
					for (var l=0;l<fs.columnIndexes.length;l++) {
						if (fs.columnIndexes[l] == -1) {
							fs.realIndexes.push(-1);
						} else {
							fs.realIndexes.push(ds.ds.usedFields[fs.columnIndexes[l]]);
						} /* not -1 */
					} /* all fs parts */
				} /* all fieldsets */
			} /* all datasources */
		} /* all objects */
	}

	this.draw = function() {
		self.totalWidth = 0;
		self.totalHeight = 0;
		var do_binding = function(o,index) {
			var ds = o.datasources[index].ds;
			if (!ds) { return; }
			if (o.bindFileCallback) { ds.bindFile(o.bindFileCallback) ;}
			if (o.bindRecordCallback) {
				var ref1 = function(dataRow,currentIndex) { o.bindRecordCallback(dataRow,currentIndex,index); }
				ds.bindRecord(ref1);
			}
			if (o.bindPageCallback) {
				var ref2 = function(dataRows,currentPageIndex) { o.bindPageCallback(dataRows,currentPageIndex,index); }
				ds.bindPage(ref2);
			}
			if (o.empty) {
				var ref3 = function() { o.clear(index); }
				ds.bindEmpty(ref3);
			}
		}
		for (var i=0;i<self.objects.length;i++) {
			var o = self.objects[i];

			if (!o.hidden) {
				self.div.appendChild(o.elm);
				o.init();

				if (o.name == "nav") { self.attachNav(o); }

				/* add dimensions to total width/height */
				var pos = OAT.Dom.getLT(o.elm);
				var dims = OAT.Dom.getWH(o.elm);
				if (pos[0]+dims[0] > self.totalWidth) { self.totalWidth = pos[0]+dims[0]; }
				if (pos[1]+dims[1] > self.totalHeight) { self.totalHeight = pos[1]+dims[1]; }

				for (var j=0;j<o.datasources.length;j++) {
					do_binding(o,j);
				}
			} /* not hidden */
			if (o.name == "map" || o.name == "grid" || o.name == "twostate" || o.name == "pivot") {
				OAT.Resize.createDefault(o.elm);
			} /* if movable object */
		} /* for all objects */

		/* create tab dependencies */
		for (var i=0;i<self.objects.length;i++) if (self.objects[i].name == "tab") {
			var o = self.objects[i];
			var max = o.properties[0].value.length;
			o.countChangeCallback(0,max);
			for (var j=0;j<max;j++) { o.changeCallback(j,o.properties[0].value[j]); }
			for (var j=0;j<o.__tp.length;j++) {
				o.tab.go(j);
				var tp = o.__tp[j];
				for (var k=0;k<tp.length;k++) {
					var victim = self.objects[tp[k]];
					var coords = OAT.Dom.getLT(victim.elm);
					o.consume(victim,coords[0],coords[1]);
				}
			}
		}

		/* create subforms for lookup windows & possible drag handles */
		for (var i=0;i<self.objects.length;i++) {
			var o = self.objects[i];
			if ((o.parentContainer && o.parentContainer.properties[1].value == "1") || o.name == "nav") {
				var mapOK = true;
				for (var j=0;j<self.objects.length;j++) {
					var oo = self.objects[j];
					if (oo.name == "map" && oo.properties[9].value == o.parentContainer) {
						var provider = parseInt(oo.properties[2].value);
						mapOK = mapOK & (provider == 1 || provider == 2);
					}
				}
				if (mapOK) { /* drag only for google & yahoo */
					var useIcon = (o.name == "map" || o.name == "pivot" || o.name == "grid" || o.name == "twostate");
					OAT.Drag.createDefault(o.elm,useIcon);
				}
			}
			if (o.name == "container") { o.createForm(self.objects); }
		}
	}

	this.initialData = function() {
		var topLevelCandidates = [];
		for (var i=0;i<self.datasources.length;i++) {
			var hope = 1;
			var fb = self.datasources[i].fieldBinding;
			for (var j=0;j<fb.types.length;j++) {
				var t = fb.types[j];
				if (t == 1 || t == 3) { hope = 0; }
			}
			if (hope) { topLevelCandidates.push(self.datasources[i]); }
		}
		for (var i=0;i<topLevelCandidates.length;i++) {
			self.callForData(topLevelCandidates[i]);
		}
	}

	this.materialize = function(xmlDoc) { /* everything is ready, do it */
		/* area properties */
		var area = xmlDoc.getElementsByTagName("area")[0];
		self.div.style.backgroundColor = area.getAttribute("bgcolor");
		self.div.style.color = area.getAttribute("fgcolor");
		self.div.style.fontSize = area.getAttribute("size");

		var counter = -1;
		var ready = false;

		/* listen for loading apis */
		OAT.MSG.attach("*","API_LOADING",function() {
			counter = (counter == -1)? 1 : counter+1;
		});

		OAT.MSG.attach("*","API_LOADED",function() {
			counter--;
			if (!counter && ready) { self.initialData(); }
		});

		/* read datasources from xmlDoc */
		var dselms = xmlDoc.getElementsByTagName("ds");
		for (var i=0;i<dselms.length;i++) {
			var dselm = dselms[i];
			var type = parseInt(dselm.getAttribute("type"));
			var ds = new OAT.DataSource(type);
			if (type == OAT.DataSourceData.TYPE_SQL) { self.sqlDS.push(ds); }
			ds.fromXML(dselm);
			self.datasources.push(ds);
		}

		/* read objects from xmlDoc */
		var objelms = xmlDoc.getElementsByTagName("object");
		for (var i=0;i<objelms.length;i++) {
			var objelm = objelms[i];
			var type = objelm.getAttribute("type");
			var obj = new OAT.FormObject[type](0,0,0,1);
			obj.fromXML(objelm,self.datasources);
			self.objects.push(obj);
		}

		self.references();

		var paramsCallback = function() { /* what to do when params are ready */
			self.recomputeFields();
			self.draw();
			self.options.onDone();
			ready = true;
			/* -1 -> no apis needed to be loaded,
			   >0 -> api loading in progress,
			   =0 -> api loading finished
			 */
			if (counter == -1 || counter == 0) { self.initialData(); }
		}

		var qualifiersCallback = function() { /* what to do when qualifiers are ready */
			self.getParams(paramsCallback);
		}

		var credentialsCallback = function() { /* what to do when credentials are ready */
			self.getQualifiers(qualifiersCallback);
		}

		self.options.onReady();
		self.getCredentials(credentialsCallback);
	}

	this.getParams = function(cb) {
		var p = [];
		for (var i=0;i<self.datasources.length;i++) {
			var fb = self.datasources[i].fieldBinding;
			for (var j=0;j<fb.selfFields.length;j++) {
				if (fb.types[j] == 2) {
					p.push([self.datasources[i],j]);
				}
			}
		}
		if (!p.length) { cb(); return; }

		function bindParameter(input,ds,index) {
			var ref = function() {
				ds.fieldBinding.masterFields[index] = $v(input);
			}
			OAT.Event.attach(input,"keyup",ref);
		}

		for (var i=0;i<p.length;i++) {
			/* ask for this parameter */
			var ds = p[i][0];
			var index = p[i][1];
			var div = OAT.Dom.create("div");
			var label = OAT.Dom.create("span");
			var input = OAT.Dom.create("input");
			input.type = "text";

			label.innerHTML = ds.inputFields[ds.fieldBinding.selfFields[index]] + ' = ';

			div.appendChild(label);
			div.appendChild(input);
			self.paramsDiv.appendChild(div);
			bindParameter(input,ds,index);
		}

		var params = new OAT.Dialog("Parameters",self.paramsDiv,{width:400,modal:1,zIndex:1000});
		params.ok = function() { params.hide(); cb(); }
		OAT.Dom.unlink(params.cancelBtn);
		params.show();

	}

	this.getQualifiers = function(cb) {
		if (!self.sqlDS.length) { cb(); return; }
		var qRef = function(qualifs) {
			OAT.SqlQueryData.columnQualifierPre = qualifs[0];
			OAT.SqlQueryData.columnQualifierPost = qualifs[1];
			cb();
		}
		var sqlDS = self.sqlDS;
		OAT.Xmla.connection = sqlDS[0].connection;
		OAT.Xmla.qualifiers(qRef);
	}

	this.getCredentials = function(cb) {
		function applyCreds() {
			for (var i=0;i<self.sqlDS.length;i++) {
				self.sqlDS[i].connection.options.user = self.options.user;
				self.sqlDS[i].connection.options.password = self.options.password;
			}
		}

		var needCreds = 1;

		if (self.options.user) { /* no credentials needed - supplied in options */
			needCreds = 0;
			applyCreds();
		}
		if (!self.sqlDS.length) { needCreds = 0; } /* no credentials asked because no SQL datasources present */
		if (self.sqlDS.length && self.sqlDS[0].connection.options.user) { needCreds = 0; } /* already present */
		if (self.options.noCred) { needCreds = 0; }
		if (self.sqlDS.length && self.sqlDS[0].connection.nocred) { needCreds = 0; }

		if (!needCreds) { cb(); return; }

		/* display credentials dialog */
		var d = new OAT.Dialog("Credentials",self.credsDiv,{modal:1,width:300});
		d.show();
		var ref = function() {
			self.options.user = $v("cred_user");
			self.options.password = $v("cred_password");
			applyCreds();
			d.hide();
			cb();
		}
		d.ok = ref;
		d.cancel = d.hide;
 	}

	this.references = function() { /* do various references */
		/* various references */
		var create_callback = function(index) {
			return function() { self.callForData(self.datasources[index]); }
		}
		for (var i=0;i<self.datasources.length;i++) {
			var fb = self.datasources[i].fieldBinding;
			for (var j=0;j<fb.types.length;j++) {
				switch (fb.types[j]) {
					case 1:
						fb.masterDSs[j] = self.datasources[parseInt(fb.masterDSs[j])];
					break;
					case 3:
						fb.masterDSs[j] = self.objects[parseInt(fb.masterDSs[j])];
						fb.masterDSs[j].changeCallback = create_callback(i);
					break;
				} /* switch */
			} /* all field bindings */
		} /* all datasources*/

		/* control references */
		var os = self.objects;
		for (var i=0;i<os.length;i++) {
			var o = os[i];
			if (o.parentContainer != -1) {
				o.parentContainer = os[o.parentContainer];
			} else { o.parentContainer = false; }
			for (var j=0;j<o.properties.length;j++) {
				var p = o.properties[j];
				if (p.type == "container") { p.value = (parseInt(p.value) == -1 ? false : os[parseInt(p.value)]); }
			}
		}

		var backRef = function(ds) {
			return function(dataRow,index,total) {
				/* optionally modify sub-forms */
				ds.lastRow = dataRow;
				var candidates = {};
				for (var i=0;i<self.datasources.length;i++) {
					var fb = self.datasources[i].fieldBinding;
					for (var j=0;j<fb.masterDSs.length;j++) {
						if (fb.masterDSs[j] == ds) { candidates[i] = 1; }
					}
				}
				for (p in candidates) {	self.callForData(self.datasources[p]); }
			}
		}
		for (var i=0;i<self.datasources.length;i++) {
			var br = backRef(self.datasources[i]);
			self.datasources[i].bindRecord(br);
		}
	}

	this.analyzeControls = function(xmlDoc) { /* return array of required features */
		var objs = xmlDoc.getElementsByTagName("object");
		var arr = [];
		for (var i=0;i<objs.length;i++) {
			var type = objs[i].getAttribute("type");
			if (type == "twostate") { arr.push("grid"); }
			if (type == "grid") { arr.push("grid"); }
			if (type == "barchart") { arr.push("barchart"); }
			if (type == "piechart") { arr.push("piechart"); }
			if (type == "linechart") { arr.push("linechart"); }
			if (type == "sparkline") { arr.push("sparkline"); }
			if (type == "pivot") { arr.push("pivot"); }
			if (type == "timeline") { arr.push("timeline"); }
			if (type == "graph") { arr.push("graphsvg"); }
			if (type == "tab") { arr.push("tab"); }
			if (type == "map") {
				arr.push("map");
				var props = objs[i].getElementsByTagName("property");
				var val = parseInt(OAT.Xml.textValue(props[2].getElementsByTagName("value")[0]));
				if (val == 1 || val == 2) {
					var key = OAT.Xml.textValue(props[0].getElementsByTagName("value")[0]);
					if (val == 1) { window._apiKey = key; }
					if (val == 2) { window.YMAPPID = key; }
				} /* if key needed */
			} /* if map */
		} /* Form::analyze */

		var dss = xmlDoc.getElementsByTagName("ds");
		for (var i=0;i<dss.length;i++) {
			var type = parseInt(dss[i].getAttribute("type"));
			if (type == OAT.DataSourceData.TYPE_SQL) { arr.push("sqlquery"); arr.push("xmla"); }
			if (type == OAT.DataSourceData.TYPE_SOAP) { arr.push("ws"); }
			if (type == OAT.DataSourceData.TYPE_SPARQL) { arr.push("sparql"); }
		}
		return arr;
	}

	this.createFromXML = function(xmlDoc) { /* create form from xml document */
		var needed = self.analyzeControls(xmlDoc);
		var callback = function() {
			self.materialize(xmlDoc);
		}
		OAT.Loader.load(needed,callback);
	}

	this.createFromURL = function(url) { /* create form from url */
		var createRef = function(xmlDoc) {
			self.createFromXML(xmlDoc);
		}
		OAT.AJAX.GET(url,false,createRef,{type:OAT.AJAX.TYPE_XML});
	}
}
