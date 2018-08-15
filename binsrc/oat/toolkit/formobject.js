/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2018 OpenLink Software
 *
 *  See LICENSE file for details.
 */

/*
	new OAT.FormObject[name](x, y, designMode, [moreOpts])
	-- appearance --
	FormObject::select()
	FormObject::deselect()
	-- data --
 	FormObject::getValue() - useful only in design when userSet is true
 	FormObject::setValue() - dtto
	FormObject::notify() - we will receive new data soon
 	FormObject::init() - initialization, when all data are bound
 	FormObject::clear()
 	FormObject::fromXML()
 	FormObject::toXML()
*/

/*
	key properties in every object:

	object.form - link to form
	object.elm - DOM node
	object.resizable
	object.userSet - whether user may change its value
	object.bindRecordCallback - for binding to ds
	object.bindPageCallback - for binding to ds
	object.allowMultipleDatasources
	object.datasources - megastructure:
	[
		{
			ds:false, - reference to actual datasource object
			fieldSets:[
				{
					name:"name",
					variable:true,
					names:[],
					columnIndexes:[],
					realIndexes:[]
				},
				{},{},...
			]
		},
		{},{}.....
	]

	object.properties - array of objects:
	{
		name:"name",
		value:"value",
		type:"string|bool|color|select|combo|form"
	}
	object.css - array of objects:
	{
		name:"Color",
		property:"color",
		type:"string|select|color|combo",
		options:[1,2,3] // only for type="select" or type="combo"
	}

*/

OAT.FormObjectNames = {
	"label":"Label",
	"input":"Input",
	"textarea":"TextArea",
	"checkbox":"Checkbox",
	"line":"Line",
	"map":"Map",
	"grid":"Grid",
	"barchart":"Bar chart",
	"piechart":"Pie chart",
	"linechart":"Line chart",
	"sparkline":"Sparkline",
	"pivot":"Pivot table",
	"flash":"Flash",
	"image":"Image",
	"imagelist":"Image list",
	"twostate":"Tabular/Columnar Combo",
	"nav":"Navigation",
	"url":"URL",
	"date":"Date",
	"timeline":"Time line",
	"graph":"RDF Graph",
	"cloud":"Tag cloud",
	"gem1":"Syndication gem",
	"uinput":"User input",
	"tab":"Tab control",
	"container":"Lookup container"
}


OAT.FormObject = {
	init:function(fo) { /* basic default properties */
		fo.name = "";
		fo.hidden = 0;
		fo.empty = 1; /* clear when no data is available? */
		fo.resizable = false;
		fo.userSet = false;
		fo.elm = OAT.Dom.create("div");
		fo.bindRecordCallback = false;
		fo.bindPageCallback = false;
		fo.bindFileCallback = false;
		fo.allowMultipleDatasources = false;
		fo.datasources = [];
		fo.properties = [];
		fo.css = [];
		fo.parentContainer = false;
		fo.init = function(){};
		fo.getValue = function(){return false;};
		fo.setValue = function(){};
		fo.clear = function(){};
		fo.notify = function(){};
	},

	abstractParent:function(fo,x,y) {
		fo.fromXML = function(node,dsArr) {
			var tmp;
			if (node.getAttribute("hidden")) { fo.hidden = 1; }
			fo.parentContainer = parseInt(node.getAttribute("parent")); /* to be referenced later */
			fo.empty = (node.getAttribute("empty")=="1" ? 1 : 0);

			if (fo.userSet) { fo.setValue(node.getAttribute("value")); }
			/* css */
			tmp = node.getElementsByTagName("style")[0];

			/* backward compat, to prevent elements from getting out of viewport */
			var left = tmp.getAttribute("left");
			var top = tmp.getAttribute("top");
			fo.elm.style.left = ((left > 0)? left : 0) + "px";
			fo.elm.style.top = ((top > 0)? top : 0) + "px";

			if (fo.resizable) {
				fo.elm.style.width = tmp.getAttribute("width")+"px";
				fo.elm.style.height = tmp.getAttribute("height")+"px";
			}
			var css = tmp.getElementsByTagName("css")[0];
			for (var i=0;i<css.attributes.length;i++) {
				var attr = css.attributes[i];
				fo.elm.style[attr.name] = attr.value;
			}
			/* properties */

			tmp = node.getElementsByTagName("properties")[0].getElementsByTagName("property");
			/*	compatibility hack for old format - NAV and GRAPH
			*/
			if ((fo.name == "nav" && tmp.length == 1) ||
				(fo.name == "graph" && tmp.length == 13)) {
					var list = [];
					var value = tmp[0].getElementsByTagName("value")[0];
					value = OAT.Xml.textValue(value);
					fo.datasources[0].ds = dsArr[parseInt(value)];
					for (var i=1;i<tmp.length;i++) {
						list.push(tmp[i]);
					}
					tmp = list;
			}
			/* end hack */

			for (var i=0;i<tmp.length;i++) {
				var name = OAT.Xml.textValue(tmp[i].getElementsByTagName("name")[0]);
				var value = tmp[i].getElementsByTagName("value")[0];
				var obj = false;
				for (var j=0;j<fo.properties.length;j++) {
					if (fo.properties[j].name == name) { obj = fo.properties[j]; }
				}
				if (!obj) {
					alert("OAT.FormObject.abstractParent:\nUnknown (probably obsolete?) property '"+name+"'"); 
				} else {
					obj.value = OAT.Xml.textValue(value);
					if (obj.variable) { obj.value = obj.value.split(","); }
				}
			}

			/* tab tricks */
			if (fo.name == "tab") {
				fo.__tp = [];
				var tmp = node.getElementsByTagName("tab_page");
				for (var i=0;i<tmp.length;i++) {
					fo.__tp.push([]);
					var sub = tmp[i].getElementsByTagName("tab_object");
					for (var j=0;j<sub.length;j++) {
						fo.__tp[fo.__tp.length-1].push(OAT.Xml.textValue(sub[j]));
					}
				}
			}
			/* datasources */
			tmp = node.getElementsByTagName("datasource");
			for (var i=0;i<tmp.length;i++) {
				var dsnode = tmp[i]; /* node */
				if (i) {
					/* copy from first index */
					var newds = {ds:false,fieldSets:[]};
					for (var j=0;j<fo.datasources[0].fieldSets.length;j++) {
						var fs = fo.datasources[0].fieldSets[j];
						newds.push({name:fs.name,variable:fs.variable,names:[],realIndexes:[],columnIndexes:fs.variable ? [] : [-1]});
					}
					fo.datasources.push(newds);
				} /* if not first datasource */
				var obj = fo.datasources[i]; /* add values to this object */
				obj.ds = dsnode.getAttribute("index");
				obj.ds = dsArr[parseInt(obj.ds)];

				var fsnodes = dsnode.getElementsByTagName("fieldset");
				for (var j=0;j<fsnodes.length;j++) {
					var fsnode = fsnodes[j];
					var name = fsnode.getAttribute("name");

					var fs = obj.fieldSets[j];
					if (fs.name != name) { alert('OAT.FormObject.abstractParent:\nPanic! Saved data incomplete?'); }
					var names = fsnode.getElementsByTagName("name"); /* all <name> subnodes */
					var indexes = fsnode.getElementsByTagName("columnIndex"); /* all <columnIndex> subnodes */
					fs.names = [];
					fs.columnIndexes = [];
					for (var k=0;k<names.length;k++) { fs.names.push(OAT.Xml.textValue(names[k])); }
					for (var k=0;k<indexes.length;k++) { fs.columnIndexes.push(parseInt(OAT.Xml.textValue(indexes[k]))); }
				} /* for all fieldSets */
			} /* for all datasources */
		} /* fromXML() */

		fo.actualizeResizers = function() {
			if (!fo.resizeXY) { return; }
			var coords = OAT.Dom.position(fo.elm);
			var w = fo.elm.offsetWidth;
			var h = fo.elm.offsetHeight;
			var x = coords[0];
			var y = coords[1];

			fo.resizeX.style.left = (x+w-4)+"px";
			fo.resizeX.style.top = Math.round(y+(h/2)-4)+"px";

			fo.resizeY.style.left = Math.round(x+(w/2)-4)+"px";
			fo.resizeY.style.top = (y+h-4)+"px";

			fo.resizeXY.style.left = (x+w-4)+"px";
			fo.resizeXY.style.top = (y+h-4)+"px";
		}

		fo.select = function() {
			if (fo.selected) { return; }
			fo.selected = 1;
			fo.elm.oldBorder = fo.elm.style.border;
			fo.elm.style.border = "2px solid #f00"; /* red border */
			/* resizor: */
			if (fo.resizable) {
				fo.resizeX = OAT.Dom.create("div",{position:"absolute",width:"6px",height:"6px",backgroundColor:"#f00",border:"1px solid #000",overflow:"hidden",zIndex:10});
				fo.resizeY = OAT.Dom.create("div",{position:"absolute",width:"6px",height:"6px",backgroundColor:"#f00",border:"1px solid #000",overflow:"hidden",zIndex:10});
				fo.resizeXY = OAT.Dom.create("div",{position:"absolute",width:"6px",height:"6px",backgroundColor:"#f00",border:"1px solid #000",overflow:"hidden",zIndex:10});

				fo.actualizeResizers();

				document.body.appendChild(fo.resizeX);
				document.body.appendChild(fo.resizeY);
				document.body.appendChild(fo.resizeXY);

				OAT.Resize.create(fo.resizeX,fo.elm,OAT.Resize.TYPE_X);
				OAT.Resize.create(fo.resizeY,fo.elm,OAT.Resize.TYPE_Y);
				OAT.Resize.create(fo.resizeXY,fo.elm,OAT.Resize.TYPE_XY);

				var cancelFunc = function(event) { event.cancelBubble = true; }
				OAT.Event.attach(fo.resizeX,"mousedown",cancelFunc);
				OAT.Event.attach(fo.resizeY,"mousedown",cancelFunc);
				OAT.Event.attach(fo.resizeXY,"mousedown",cancelFunc);
			}
		} /* FormObject::select() */

		fo.deselect = function() {
			if (!fo.selected) { return; }
			fo.selected = 0;
			fo.elm.style.border = fo.elm.oldBorder;
			if (fo.resizable) {
				OAT.Dom.unlink(fo.resizeX);
				OAT.Dom.unlink(fo.resizeY);
				OAT.Dom.unlink(fo.resizeXY);
				fo.resizeX = false;
				fo.resizeY = false;
				fo.resizeXY = false;
			}
		}
		fo.createForm = function(objArr) {
			var dsArr = [];
			var dsObj = [];
			/* method for containers: fetch all children, append them and re-position */
			var pos = OAT.Dom.getLT(fo.elm);
			for (var i=0;i<objArr.length;i++) {
				var o = objArr[i];
				if (o.parentContainer && o.parentContainer == fo) {
					var e = o.elm;
					var pos2 = OAT.Dom.getLT(e);
					e.style.left = (pos2[0] - pos[0]) + "px";
					e.style.top = (pos2[1] - pos[1]) + "px";
					fo.elm.appendChild(e);
					dsObj.push(o);
					if (o.name == "tab") for (var j=0;j<o.objects.length;j++) { /* for all tabs */
						for (var k=0;k<o.objects[j].length;k++) {
							if (dsObj.indexOf(o.objects[j][k]) == -1) { dsObj.push(o.objects[j][k]); }
						} /* for all tabs */
					} /* if is tab */
				} /* if descendant */
			} /* for all objects */
			for (var i=0;i<dsObj.length;i++) { /* analyze child datasources */
				var o = dsObj[i];
				for (var j=0;j<o.datasources.length;j++) {
					if (o.datasources[j].fieldSets[0].realIndexes[0] != -1) {
						var ds = o.datasources[j].ds;
						var index = dsArr.indexOf(ds);
						if (index == -1) { dsArr.push(ds); }
					} /* if ds is used */
				} /* for all datasources */
			}

			fo.datasources = dsArr;
			fo.elm.style.left = "0px";
			fo.elm.style.top = "0px";
			fo.elm.style.position = "relative";
			OAT.Dom.hide(fo.elm);
		}
		fo.toXML = function(designer) {
			var xml = "";
			var e = fo.elm;
			var x = e.offsetLeft;
			var y = e.offsetTop;
			var w = e.offsetWidth;
			var h = e.offsetHeight;
			var z = e.style.zIndex;
			/* element */
			xml += '\t<object type="'+fo.name+'" parent="'+designer.objects.indexOf(fo.parentContainer)+'" ';
			if (fo.hidden == "1") { xml += 'hidden="1" '; }
			xml += 'empty="'+fo.empty+'" ';
			xml += 'value="'+fo.getValue()+'">\n';

			/* style */
			xml += '\t\t<style left="'+x+'" top="'+y+'" z-index="'+z+'"';
			if (fo.resizable) { xml += ' width="'+w+'" height="'+h+'" '; }
			xml += '>\n';
			xml += '\t\t\t<css ';
			for (var i=0;i<fo.css.length;i++) {
				var css = fo.css[i];
				xml += ' '+css.property+'="'+OAT.Style.get(e,css.property)+'" ';
			}
			xml += '></css>\n';
			xml += '\t\t</style>\n';
			/* tabs */
			if (fo.name == "tab") {
				for (var i=0;i<fo.objects.length;i++) {
					xml += '\t\t<tab_page>\n';
						for (var j=0;j<fo.objects[i].length;j++) {
							var to = fo.objects[i][j];
							xml += '\t\t\t<tab_object>'+designer.objects.indexOf(to)+'</tab_object>\n';
						}
					xml += '\t\t</tab_page>\n';
				}
			}
			/* properties */
			xml += '\t\t<properties>\n';
			for (var i=0;i<fo.properties.length;i++) {
				var p = fo.properties[i];
				xml += '\t\t\t<property>\n';
				xml += '\t\t\t\t<name>'+p.name+'</name>\n';
				var val = p.value;
				// not needed anymore
				// if (p.type == "datasource") { val = designer.datasources.indexOf(val); }
				if (p.type == "container") { val = designer.objects.indexOf(val); }
				if (p.variable) { val = val.join(","); }
				xml += '\t\t\t\t<value>'+val+'</value>\n';
				xml += '\t\t\t\t<type>'+p.type+'</type>\n';
				xml += '\t\t\t</property>\n';
			}
			xml += '\t\t</properties>\n';
			/* datasources */
			xml += '\t\t<datasources>\n';
			for (var i=0;i<fo.datasources.length;i++) {
				var ds = fo.datasources[i];
				xml += '\t\t\t<datasource index="'+designer.datasources.indexOf(ds.ds)+'">\n';
				for (var j=0;j<ds.fieldSets.length;j++) {
					var fs = ds.fieldSets[j];
					xml += '\t\t\t\t<fieldset name="'+fs.name+'" variable="'+(fs.variable ? 1 : 0)+'">\n';
					for (var k=0;k<fs.names.length;k++) {
						xml += '\t\t\t\t\t<name>'+fs.names[k]+'</name>\n';
					}
					for (var k=0;k<fs.columnIndexes.length;k++) {
						xml += '\t\t\t\t\t<columnIndex>'+fs.columnIndexes[k]+'</columnIndex>\n';
					}
					xml += '\t\t\t\t</fieldset>\n';
				}
				xml += '\t\t\t</datasource>\n';
			}
			xml += '\t\t</datasources>\n';
			xml += '\t</object>\n';

			return xml;
		}

		fo.selected = 0;
		fo.elm.style.position = "absolute";
		fo.elm.style.left = x+"px";
		fo.elm.style.top = y+"px";
		var actFunc = function(event) { fo.actualizeResizers(); }
		OAT.Event.attach(document.body,"mousemove",actFunc);
	},

	label:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="label";
		self.resizable = true;
		self.elm = OAT.Dom.create("div");
		self.userSet = true;
		self.datasources = [
			{ds:false,fieldSets:[
				{name:"Value",variable:false,columnIndexes:[-1],names:[],realIndexes:[]}
			]}
		];
		self.css = [
			{name:"Color",property:"color",type:"color"},
			{name:"BG Color",property:"backgroundColor",type:"color"},
			{name:"Font size",property:"fontSize",type:"combo",options:["60%","80%","100%","120%","140%"]}
		];

		self.setValue = function(value) {
			self.elm.innerHTML = value;
		}
		self.getValue = function() {
			return self.elm.innerHTML;
		}

		self.bindRecordCallback = function(dataRow,currentIndex) {
			var ri = self.datasources[0].fieldSets[0].realIndexes;
			if (ri[0] == -1) { return; }
			if (!dataRow) { return; }
			var value = dataRow[ri[0]];
			self.setValue(value);
		}

		self.clear = function() {
			if (self.datasources[0].fieldSets[0].realIndexes[0] != -1) { self.elm.innerHTML = ""; }
		}

		OAT.FormObject.abstractParent(self,x,y);
	},

	input:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="input";
		self.resizable = true;
		self.elm = OAT.Dom.create("input");
		self.elm.setAttribute("type","text");
		self.userSet = true;
		self.datasources = [
			{ds:false,fieldSets:[
				{name:"Value",variable:false,columnIndexes:[-1],names:[],realIndexes:[]}
			]}
		];
		self.css = [
			{name:"Color",property:"color",type:"color"},
			{name:"BG Color",property:"backgroundColor",type:"color"},
			{name:"Font size",property:"fontSize",type:"combo",options:["60%","80%","100%","120%","140%"]}
		];
		self.setValue = function(value) {
			self.elm.value = value;
		}
		self.getValue = function() {
			return self.elm.value;
		}
		self.clear = function() {
			if (self.datasources[0].fieldSets[0].realIndexes[0] != -1) { self.elm.value = ""; }
		}

		self.bindRecordCallback = function(dataRow,currentIndex) {
			var ri = self.datasources[0].fieldSets[0].realIndexes;
			if (ri[0] == -1) { return; }
			if (!dataRow) { return; }
			var value = dataRow[ri[0]];
			self.setValue(value);
		}
		OAT.FormObject.abstractParent(self,x,y);
	},

	uinput:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="uinput";
		self.resizable = true;
		self.elm = OAT.Dom.create("div");
		self.input = OAT.Dom.create("input");
		self.input.type = "text";
		self.button = OAT.Dom.create("input");
		self.button.type = "button";
		self.button.value = "Refresh";
		self.elm.appendChild(self.input);
		self.elm.appendChild(self.button);
		self.changeCallback = function() {}
		if (!designMode) {
			OAT.Event.attach(self.button,"click",function(){self.changeCallback();});
			OAT.Event.attach(self.input,"keyup",function(event) {
				if (event.keyCode == 13) { self.changeCallback(); }
			});
		}
		self.properties = [
			{name:"Name",type:"string",value:"user input"}
		]
		OAT.FormObject.abstractParent(self,x,y);
	},

	textarea:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="textarea";
		self.resizable = true;
		self.elm = OAT.Dom.create("textarea");
		self.elm.value = "textarea";
		self.datasources = [
			{ds:false,fieldSets:[
				{name:"Value",variable:false,columnIndexes:[-1],names:[],realIndexes:[]}
			]}
		];
		self.css = [
			{name:"Color",property:"color",type:"color"},
			{name:"BG Color",property:"backgroundColor",type:"color"},
			{name:"Font size",property:"fontSize",type:"combo",options:["60%","80%","100%","120%","140%"]}
		];
		self.setValue = function(value) {
			self.elm.value = value;
		}
		self.getValue = function() {
			return self.elm.value;
		}
		self.clear = function() {
			self.elm.value = "";
		}
		self.bindRecordCallback = function(dataRow,currentIndex) {
			var ri = self.datasources[0].fieldSets[0].realIndexes;
			if (ri[0] == -1) { return; }
			if (!dataRow) { return; }
			var value = dataRow[ri[0]];
			self.setValue(value);
		}
		OAT.FormObject.abstractParent(self,x,y);
	},

	checkbox:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="checkbox";
		self.elm = OAT.Dom.create("input");
		self.elm.setAttribute("type","checkbox");
		self.datasources = [
			{ds:false,fieldSets:[
				{name:"Checked",variable:false,columnIndexes:[-1],names:[],realIndexes:[]}
			]}
		];
		self.setValue = function(value) {
			var x = value.toString();
			if (x.toUpperCase() == "TRUE") { x = 1; }
			var x = parseInt(x);
			self.elm.checked = (x ? true : false);
		}

		self.bindRecordCallback = function(dataRow,currentIndex) {
			var ri = self.datasources[0].fieldSets[0].realIndexes;
			if (ri[0] == -1) { return; }
			if (!dataRow) { return; }
			var value = dataRow[ri[0]];
			self.setValue(value);
		}
		OAT.FormObject.abstractParent(self,x,y);
	},

	line:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="line";
		self.resizable = true;
		self.elm = OAT.Dom.create("hr");
		self.elm.style.width = "200px";
		OAT.FormObject.abstractParent(self,x,y);
	},

	container:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="container";
		self.resizable = true;
		self.elm = OAT.Dom.create("div");
		self.properties = [
			{name:"Name",type:"string",value:"container"},
			{name:"Descendant controls movable?",type:"bool",value:"1"}
		];
		self.css = [
			{name:"BG Color",property:"backgroundColor",type:"color"}
		];
		if (designMode) {
			self.elm.style.width = "200px";
			self.elm.style.height = "200px";
			self.elm.style.border = '1px solid #000';
			self.elm.innerHTML = "Container";
			self.elm.style.backgroundColor = '#ccc';
		}
		OAT.FormObject.abstractParent(self,x,y);
	},

	tab:function(x,y,designMode,loading) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="tab";
		self.resizable = true;
		self.elm = OAT.Dom.create("div",{width:"200px",height:"200px",border:"2px solid #000",backgroundColor:"#888"});
		self.tab = new OAT.Tab(self.elm);

		self.tabElm = OAT.Dom.create("div",{width:"100%",height:"28px",position:"absolute",top:"-28px",left:"0px"});
		self.tabUL = OAT.Dom.create("ul");
		self.tabUL.className = "tab";
		self.elm.appendChild(self.tabElm);
		self.tabElm.appendChild(self.tabUL);

		self.pages = [];
		self.objects = [];
		self.tabs = [];

		self.consume = function(obj,x,y) {
			var elm = obj.elm;
			elm.__originalParent = elm.parentNode;
			self.pages[self.tab.selectedIndex].appendChild(elm);
			self.objects[self.tab.selectedIndex].push(obj);
			elm.style.left = x+"px";
			elm.style.top = y+"px";
		}

		self.remove = function(obj,x,y) {
			var elm = obj.elm;
			elm.__originalParent.appendChild(elm);
			var i = self.objects[self.tab.selectedIndex].indexOf(obj);
			self.objects[self.tab.selectedIndex].splice(i,1);
			elm.style.left = x+"px";
			elm.style.top = y+"px";
		}

		self.countChangeCallback = function(oldCount,newCount) {
			/* number of tabs is going to change - do something */
			if (oldCount > newCount) {
				/* reduce the number */
				while (self.pages.length > newCount) {
					var rIndex = self.pages.length-1;
					for (var i=0;i<self.objects[rIndex].length;i++) {
						var o = self.objects[rIndex][i];
						self.remove(o,50,50);
					}
					self.tab.remove(self.tabs[rIndex]);
					OAT.Dom.unlink(self.tabs[rIndex]);
					self.tabs.splice(rIndex,1);
					self.pages.splice(rIndex,1);
					self.objects.splice(rIndex,1);
				}
				self.properties[0].value.length = newCount;
			} else {
				/* increase the number */
				for (var i=oldCount;i<newCount;i++) {
					self.objects.push([]);
					var page = OAT.Dom.create("div",{width:"100%",height:"100%"});
					var tab = OAT.Dom.create("li");
					self.tabUL.appendChild(tab);
					self.pages.push(page);
					self.tabs.push(tab);
					self.tab.add(tab,page);
					self.properties[0].value.push("");
				}
			}
		}

		self.changeCallback = function(index,value) {
			self.tabs[index].innerHTML = value;
			self.properties[0].value[index] = value;
		}

		self.properties = [
			{name:"Tabs",type:"string",variable:true,onchange:self.changeCallback,oncountchange:self.countChangeCallback,value:[]}
		]
		if (designMode && !loading) {
			self.countChangeCallback(0,3);
			self.changeCallback(0,"tab 1");
			self.changeCallback(1,"tab 2");
			self.changeCallback(2,"tab 3");
		}

		OAT.FormObject.abstractParent(self,x,y);
	},

	map:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="map";
		self.resizable = true;
		self.elm = OAT.Dom.create("div",{border:"1px solid #00f",backgroundColor:"#ddf",width:"100px",height:"100px",overflow:"hidden"});
		self.windowWasOpened = false;
		self.allowMultipleDatasources = true;
		self.datasources = [
			{ds:false,fieldSets:[
				{name:"Latitude",variable:false,columnIndexes:[-1],names:[],realIndexes:[]},
				{name:"Longitude",variable:false,columnIndexes:[-1],names:[],realIndexes:[]},
				{name:"Marker color",variable:false,columnIndexes:[-1],names:[],realIndexes:[]},
				{name:"Marker image",variable:false,columnIndexes:[-1],names:[],realIndexes:[]}
			]}
		];
		self.properties = [
/*0*/		{name:"Key",type:"string",value:""},
/*1*/		{name:"Zoom level",type:"select",value:"2",options:[["0 - Far","0"],"1","2","3","4","5","6","7","8","9","10","11","12","13","14","15",["16 - Near","16"]]},
/*2*/		{name:"Provider",type:"select",value:OAT.MapData.TYPE_G3,options:[
				["Google v3",OAT.MapData.TYPE_G3],
				["Google",OAT.MapData.TYPE_G],
				["Yahoo!",OAT.MapData.TYPE_Y],
				["MS Virtual Earth",OAT.MapData.TYPE_MS],
				["OpenLayers",OAT.MapData.TYPE_OL]
			]},
/*3*/		{name:"All markers at once?",type:"bool",value:"0"},
/*4*/		{name:"Map type",type:"select",value:"Map",options:["Map","Satellite","Hybrid"]},
/*5*/		{name:"Marker overlap correction",type:"select",value:OAT.MapData.FIX_ROUND1,options:[
				["None",OAT.MapData.FIX_NONE],
				["Circle, center",OAT.MapData.FIX_ROUND1],
				["Circle, no center",OAT.MapData.FIX_ROUND2],
				["Vertical stack",OAT.MapData.FIX_STACK]
			]},
/*6*/		{name:"Marker image",type:"select",value:"",options:[["Normal",""],["People","p"]]},
/*7*/		{name:"Marker width",type:"string",value:"18"},
/*8*/		{name:"Marker height",type:"string",value:"41"},
/*9*/		{name:"Lookup container",type:"container",value:false}
		];
		if (designMode) {
			self.elm.innerHTML = "Map";
		}

		self.closeWindow = function() {
			self.map.closeWindow();
			if (self.form) { self.form.elm.style.display = "none"; }
		}

		self.openWindow = function(dsIndex,recordIndex) {
			if (self.form) {
				var marker = self.markers[dsIndex][recordIndex];
				self.map.openWindow(marker,self.form.elm);
				self.form.elm.style.display = "block";
			}
		}

		self.clickRef = function(dsIndex,index) {
			return function(marker,event) {
				self.windowWasOpened = true;
				/* call for data */
				var result = self.datasources[dsIndex].ds.advanceRecord(index);
				if (!result) { self.openWindow(dsIndex,index); } /* no advancement made, since we already have the data */
 			} /* marker click reference */
		}

		self.setValue = function(value,dsIndex) { /* lat,lon,index,image */
			self.map.removeMarkers(dsIndex);
			if (self.multi) {
				var pointArr = [];
				for (var i=0;i<value.length;i++) {
					var lat = value[i][0];
					var lon = value[i][1];
					var index = value[i][2];
					pointArr.push([lat,lon]);
					var ref = self.clickRef(dsIndex,index);
					var m = self.map.addMarker(dsIndex,lat,lon,value[i][3],self.markerWidth,self.markerHeight,ref);
					self.markers[dsIndex][index] = m;
				}
				self.map.optimalPosition(pointArr);
				var az = self.map.getZoom();
				if (self.zoom > az) { self.zoom = az; }
				self.map.setZoom(self.zoom);
			} else {
				var lat = value[0][0];
				var lon = value[0][1];
				var index = value[0][2];
				var ref = self.clickRef(dsIndex,index);
				var m = self.map.addMarker(dsIndex,lat,lon,value[0][3],self.markerWidth,self.markerHeight,ref);
				self.markers[dsIndex][index] = m;
				self.zoom = self.map.getZoom();
				self.map.centerAndZoom(lat,lon,self.zoom);
			}
		}
		self.getValue = function() { return false; }
		self.init = function() {
			self.zoom = parseInt(self.properties[1].value);
			switch (parseInt(self.properties[2].value)) {
				case OAT.MapData.TYPE_G3: self.provider = OAT.MapData.TYPE_G3; break;
				case OAT.MapData.TYPE_G: self.provider = OAT.MapData.TYPE_G; break;
				case OAT.MapData.TYPE_Y: self.provider = OAT.MapData.TYPE_Y; break;
				case OAT.MapData.TYPE_MS: self.provider = OAT.MapData.TYPE_MS; break;
				case OAT.MapData.TYPE_OL: self.provider = OAT.MapData.TYPE_OL; break;
			}
			self.prefix = self.properties[6].value;
			self.multi = (self.properties[3].value == "1" ? 1 : 0);
			self.fixObj = {fix:parseInt(self.properties[5].value),fixDistance:20};
			self.markerWidth = parseInt(self.properties[7].value);
			self.markerHeight = parseInt(self.properties[8].value);
			/* markers available */
			self.markerPath = OAT.Preferences.imagePath+"markers/";
			self.markerFiles = [];
			for (var i=1;i<=12;i++) {
				var name = self.prefix + (i<10?"0":"") + i +".png";
				self.markerFiles.push(name);
			}
			self.markerIndex = 0;
			self.markerMapping = {};

			var cb = function() {
				self.map.centerAndZoom(0,0,self.zoom);
				self.map.addTypeControl();
				self.map.addTrafficControl();
				self.map.addMapControl();
				switch (self.properties[4].value) {
					case "Map": self.map.setMapType(OAT.MapData.MAP_MAP); break;
					case "Satellite": self.map.setMapType(OAT.MapData.MAP_ORTO); break;
					case "Hybrid": self.map.setMapType(OAT.MapData.MAP_HYB); break;
				}
			}

			self.map = new OAT.Map(self.elm,self.provider,self.fixObj);
			self.map.loadApi(self.provider,cb);

			self.form = false;
			if (self.properties[9].value) { self.form = self.properties[9].value; }


			self.markers = [];
			for (var i=0;i<self.datasources.length;i++) {
				self.markers.push([]);
				OAT.MSG.attach(self.datasources[i].ds,"DS_RECORD_PREADVANCE",self.closeWindow);
			}
		}

		self.bindRecordCallback = function(dataRow,currentIndex,dsIndex) {
			if (!dataRow) { return; }
			var ds = self.datasources[dsIndex];
			var lat = parseFloat(dataRow[ds.fieldSets[0].realIndexes[0]]);
			var lon	= parseFloat(dataRow[ds.fieldSets[1].realIndexes[0]]);
			var color = (ds.fieldSets[2].columnIndexes[0] == -1 ? 1 : dataRow[ds.fieldSets[2].realIndexes[0]]);
			if (!(color in self.markerMapping)) {
				self.markerMapping[color] = self.markerPath + self.markerFiles[self.markerIndex];
				self.markerIndex++;
				if (self.markerIndex >= self.markerFiles.length) { self.markerIndex = 0; }
			}
			var image = self.markerMapping[color];
			if (!isNaN(lat) && !isNaN(lon)) {
				var value = [lat,lon,currentIndex,image];
				if (!self.multi) { self.setValue([value],dsIndex); }
			}
			if (self.windowWasOpened) { self.openWindow(dsIndex,currentIndex); }
		}
		self.bindPageCallback = function(dataRows,currentPageIndex,dsIndex) {
			var values = [];
			var ds = self.datasources[dsIndex];
			for (var i=0;i<dataRows.length;i++) {
				var lat = parseFloat(dataRows[i][ds.fieldSets[0].realIndexes[0]]);
				var lon	= parseFloat(dataRows[i][ds.fieldSets[1].realIndexes[0]]);
				var color = (ds.fieldSets[2].columnIndexes[0] == -1 ? 1 : dataRows[i][ds.fieldSets[2].realIndexes[0]]);
				var index = currentPageIndex+i;
				if (!(color in self.markerMapping)) {
					self.markerMapping[color] = self.markerPath + self.markerFiles[self.markerIndex];
					self.markerIndex++;
					if (self.markerIndex >= self.markerFiles.length) { self.markerIndex = 0; }
				}
				var image = self.markerMapping[color];
				if (ds.fieldSets[3].columnIndexes[0] != -1) { /* custom image */
					image = dataRows[i][ds.fieldSets[3].realIndexes[0]];
				}
				if (!isNaN(lat) && !isNaN(lon)) {
					values.push([lat,lon,index,image]);
				}
			}
			if (self.multi) { self.setValue(values,dsIndex); }
		}
		OAT.FormObject.abstractParent(self,x,y);
	},

	barchart:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="barchart";
		self.elm = OAT.Dom.create("div");
		self.datasources = [
			{ds:false,fieldSets:[
				{name:"Data rows",variable:true,names:[],columnIndexes:[],realIndexes:[]}
			]}
		];
		self.css = [
			{name:"BG Color",property:"backgroundColor",type:"color"}
		];

		if (designMode) {
			self.elm.style.width = "200px";
			self.elm.style.height = "200px";
			self.elm.style.border = '1px solid #000';
			self.elm.innerHTML = "Bar chart";
			self.elm.style.backgroundColor = '#ccc';
		} else {
			self.elm.style.height = "200px";
		}

		self.setValue = function(arr) {
			self.chart.attachData(arr);
			self.chart.draw();
		}
		self.clear = function() {
			OAT.Dom.clear(self.elm);
		}
		self.init = function() {
			self.chart = new OAT.BarChart(self.elm,{});
			var textY = [];
			var fs = self.datasources[0].fieldSets[0];
			for (var i=0;i<fs.realIndexes.length;i++) { textY.push(fs.names[i]); }
			self.chart.attachTextY(textY);
		}

		self.bindPageCallback = function(dataRows, currentPageIndex) {
			var value = [];
			var fs = self.datasources[0].fieldSets[0];
			for (var i=0;i<dataRows.length;i++) {
				var column = [];
				for (var j=0;j<fs.realIndexes.length;j++) {
					column.push(dataRows[i][fs.realIndexes[j]]);
				}
				value.push(column);
			}
			self.setValue(value);
		}
		OAT.FormObject.abstractParent(self,x,y);
	},

	linechart:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="linechart";
		self.resizable = true;
		self.elm = OAT.Dom.create("div");
		self.datasources = [
			{ds:false,fieldSets:[
				{name:"Data rows",variable:true,names:[],columnIndexes:[],realIndexes:[]}
			]}
		];
		self.css = [
			{name:"BG Color",property:"backgroundColor",type:"color"}
		];

		if (designMode) {
			self.elm.style.width = "200px";
			self.elm.style.height = "200px";
			self.elm.style.border = '1px solid #000';
			self.elm.innerHTML = "Line chart";
			self.elm.style.backgroundColor = '#ccc';
		} else {
			self.elm.style.height = "200px";
		}

		self.setValue = function(arr) {
			self.chart.attachData(arr);
			self.chart.draw();
		}
		self.clear = function() {
			OAT.Dom.clear(self.elm);
		}
		self.init = function() {
			self.chart = new OAT.LineChart(self.elm,{});
			var textY = [];
			var fs = self.datasources[0].fieldSets[0];
			for (var i=0;i<fs.realIndexes.length;i++) { textY.push(fs.names[i]); }
			self.chart.attachTextY(textY);
		}

		self.bindPageCallback = function(dataRows, currentPageIndex) {
			var value = [];
			var fs = self.datasources[0].fieldSets[0];
			for (var i=0;i<fs.realIndexes.length;i++) {
				var row = [];
				for (var j=0;j<dataRows.length;j++) {
					row.push(dataRows[j][fs.realIndexes[i]]);
				}
				value.push(row);
			}
			self.setValue(value);
		}
		OAT.FormObject.abstractParent(self,x,y);
	},

	piechart:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="piechart";
		self.elm = OAT.Dom.create("div");
		self.resizable = true;
		self.datasources = [
			{ds:false,fieldSets:[
				{name:"Data",variable:false,names:[],columnIndexes:[],realIndexes:[]},
				{name:"Labels",variable:false,names:[],columnIndexes:[],realIndexes:[]}
			]}
		];
		self.css = [
			{name:"BG Color",property:"backgroundColor",type:"color"}
		];

		if (designMode) {
			self.elm.style.width = "400px";
			self.elm.style.height = "200px";
			self.elm.style.border = '1px solid #000';
			self.elm.innerHTML = "Pie chart";
			self.elm.style.backgroundColor = '#ccc';
		} else {
			self.elm.style.width = "400px";
			self.elm.style.height = "200px";
		}

		self.setValue = function(dataArr,textArr) {
			self.chart.attachData(dataArr);
			self.chart.attachText(textArr);
			self.chart.draw();
		}
		self.clear = function() {
			OAT.Dom.clear(self.elm);
		}
		self.init = function() {
			self.chart = new OAT.PieChart(self.elm,{});
		}

		self.bindPageCallback = function(dataRows, currentPageIndex) {
			var fs1 = self.datasources[0].fieldSets[0];
			var fs2 = self.datasources[0].fieldSets[1];
			var dataArr = [];
			var textArr = [];
			for (var i=0;i<dataRows.length;i++) {
				dataArr.push(dataRows[i][fs1.realIndexes[0]]);
				textArr.push(dataRows[i][fs2.realIndexes[0]]);
			}
			self.setValue(dataArr,textArr);
		}
		OAT.FormObject.abstractParent(self,x,y);
	},

	sparkline:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="sparkline";
		self.elm = OAT.Dom.create("div");
		self.resizable = true;
		self.datasources = [
			{ds:false,fieldSets:[
				{name:"Data",variable:false,names:[],columnIndexes:[],realIndexes:[]},
			]}
		];
		self.css = [
			{name:"BG Color",property:"backgroundColor",type:"color"}
		];

		if (designMode) {
			self.elm.style.width = "200px";
			self.elm.style.height = "100px";
			self.elm.style.border = '1px solid #000';
			self.elm.innerHTML = "Sparkline";
			self.elm.style.backgroundColor = '#ccc';
		} else {
			self.elm.style.width = "200px";
			self.elm.style.height = "100px";
		}

		self.setValue = function(dataArr) {
			self.chart.attachData(dataArr);
			self.chart.draw();
		}
		self.clear = function() {
			OAT.Dom.clear(self.elm);
		}
		self.init = function() {
			self.chart = new OAT.Sparkline(self.elm,{});
		}

		self.bindPageCallback = function(dataRows, currentPageIndex) {
			var fs = self.datasources[0].fieldSets[0];
			var dataArr = [];
			for (var i=0;i<dataRows.length;i++) {
				dataArr.push(dataRows[i][fs.realIndexes[0]]);
			}
			self.setValue(dataArr);
		}
		OAT.FormObject.abstractParent(self,x,y);
	},

	pivot:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="pivot";
		self.resizable = true;
		self.elm = OAT.Dom.create("div");
		self.datasources = [
			{ds:false,fieldSets:[
				{name:"Data column",variable:false,columnIndexes:[-1],realIndexes:[],names:[]},
				{name:"Paging conditions",variable:true,columnIndexes:[],realIndexes:[],names:[]},
				{name:"Row conditions",variable:true,columnIndexes:[],realIndexes:[],names:[]},
				{name:"Column conditions",variable:true,columnIndexes:[],realIndexes:[],names:[]}
			]}
		];
		self.properties = [
			{name:"Data column name",value:"",type:"string"}
		];

		if (designMode) {
			self.elm.style.width = "200px";
			self.elm.style.height = "200px";
			self.elm.style.backgroundColor = '#ccc';
			self.elm.style.border = '1px solid #000';
			self.elm.innerHTML = "Pivot";
		} else {
			self.content = OAT.Dom.create("div",{width:"100%",height:"100%",overflow:"auto"});
			self.elm.appendChild(self.content);
		}

		self.setValue = function(data) {
			self.pivot = new OAT.Pivot(self.pivotDiv,
									self.chartDiv,
									self.filterDiv,
									self.headerRow,
									data,
									self.headerRowIndexes,
									self.headerColIndexes,
									self.filterIndexes,
									0,
									{});
		}
		self.clear = function() {
			OAT.Dom.clear(self.pivotDiv);
			OAT.Dom.clear(self.chartDiv);
		}
		self.init = function() {
			self.aggDiv = OAT.Dom.create("div");
			self.aggDiv.innerHTML = "Aggregate function: ";
			/* create agg function list */
			var pivot_agg = OAT.Dom.create("select");
			for (var i=0;i<OAT.Statistics.list.length;i++) {
				var item = OAT.Statistics.list[i];
				OAT.Dom.option(item.shortDesc,i,pivot_agg);
			}
			pivot_agg.selectedIndex = 1;
			self.aggDiv.appendChild(pivot_agg);

			var aggRef = function() {
				self.pivot.options.agg = parseInt($v(pivot_agg));
				self.pivot.go();
			}
			OAT.Event.attach(pivot_agg,"change",aggRef);

			self.filterDiv = OAT.Dom.create("div");
			self.pivotDiv = OAT.Dom.create("div");
			self.chartDiv = OAT.Dom.create("div");
			self.chartDiv.className = "chart";
			self.content.appendChild(self.aggDiv);
			self.content.appendChild(self.filterDiv);
			self.content.appendChild(self.pivotDiv);
			self.content.appendChild(self.chartDiv);

			self.headerRow = [];
			self.filterIndexes = [];
			self.headerRowIndexes = [];
			self.headerColIndexes = [];
			var index = 1;
			self.headerRow.push(self.properties[0].value);
			for (var i=0;i<self.datasources[0].fieldSets.length;i++) {
				var fs = self.datasources[0].fieldSets[i];
				if (fs.name == "Paging conditions") {
					for (var j=0;j<fs.names.length;j++) {
						self.headerRow.push(fs.names[j]);
						self.filterIndexes.push(index);
						index++;
					}
				}
				if (fs.name == "Row conditions") {
					for (var j=0;j<fs.names.length;j++) {
						self.headerRow.push(fs.names[j]);
						self.headerRowIndexes.push(index);
						index++;
					}
				}
				if (fs.name == "Column conditions") {
					for (var j=0;j<fs.names.length;j++) {
						self.headerRow.push(fs.names[j]);
						self.headerColIndexes.push(index);
						index++;
					}
				}
			} /* for all DSs */

			OAT.Event.attach(self.content,"scroll",function(event){event.cancelBubble = true;});
			OAT.Event.attach(self.content,"mousewheel",function(event){event.cancelBubble = true;});
			OAT.Event.attach(self.content,"DOMMouseScroll",function(event){event.cancelBubble = true;});

		} /* init() */

		self.bindPageCallback = function(dataRows, currentPageIndex) {
			var value = [];
			var fs_1 = self.datasources[0].fieldSets[1];
			var fs_2 = self.datasources[0].fieldSets[2];
			var fs_3 = self.datasources[0].fieldSets[3];
			var fs = self.datasources[0].fieldSets[0];
			for (var i=0;i<dataRows.length;i++) {
				var row = [];
				row.push(dataRows[i][fs.realIndexes[0]]);
				for (var j=0;j<fs_1.realIndexes.length;j++) {
					row.push(dataRows[i][fs_1.realIndexes[j]]);
				}
				for (var j=0;j<fs_2.realIndexes.length;j++) {
					row.push(dataRows[i][fs_2.realIndexes[j]]);
				}
				for (var j=0;j<fs_3.realIndexes.length;j++) {
					row.push(dataRows[i][fs_3.realIndexes[j]]);
				}
				value.push(row);
			}
			self.setValue(value);
		}

		OAT.FormObject.abstractParent(self,x,y);
	},

	grid:function(x,y,designMode,forbidHiding) {
		var self = this;
		OAT.FormObject.init(self);
		self.showAll = false;
		self.name="grid";
		self.resizable = true;
		self.elm = OAT.Dom.create("div");
		self.datasources = [
			{ds:false,fieldSets:[
				{name:"Columns",variable:true,names:[],columnIndexes:[],realIndexes:[]}
			]}
		];
		if (designMode) {
			self.elm.style.width = "200px";
			self.elm.style.height = "200px";
			self.elm.style.backgroundImage = 'url("images/gridbg.gif")';
			self.elm.style.border = '1px solid #000';
			self.elm.innerHTML = "Grid";
		} else {
			self.elm.style.backgroundColor = '#ccc';
			/* MS Live clipboard */
			self.lc = OAT.Dom.create("div",{position:"absolute",left:"-32px",top:"0px"});
			self.lc.className = "webclip";
			var onRef = function() {}
			var outRef = function() {}
			var genRef = function() { return self.grid.toXML(); }
			var pasteRef = function(xmlStr) {}
			var typeRef = function() { return "ol_grid_xhtml"; }
			if (OAT.WebClipBindings) {
				OAT.WebClipBindings.bind(self.lc, typeRef, genRef, pasteRef, onRef, outRef);
				self.elm.appendChild(self.lc);
			}
		}

		self.setValue = function(data) {
			self.grid.clearData();
			for (var i=0;i<data.length;i++) {
				self.grid.createRow(data[i]);
			}
		}
		self.clear = function() {
			self.grid.clearData();
		}
		self.init = function() {
			self.container = OAT.Dom.create("div",{width:"100%",height:"100%",overflow:"auto"});
			self.elm.appendChild(self.container);
			var ds = self.datasources[0].fieldSets[0];
			var ah = forbidHiding ? 0 : 1;
			self.grid = new OAT.Grid(self.container,{autoNumber:true,allowHiding:ah}); /* autonumber & allowHiding */
			self.grid.options.reorderNotifier = function(i1,i2) {
				var fs = self.datasources[0].fieldSets[0];
				var tmp = fs.realIndexes[i1-1];
				var newi = (i1 < i2 ? i2-2 : i2-1);
				fs.realIndexes.splice(i1-1,1);
				fs.realIndexes.splice(newi,0,tmp);
			}
			if (!self.showAll) {
				var data = [];
				for (var i=0;i<ds.names.length;i++) {
					var label = ds.names[i];
					if (label == "") { label = self.datasources[0].ds.outputFields[ds.realIndexes[i]]; }
					var o = {
						value:label,
						sortable:1,
						draggable:1,
						resizable:1
					}
					data.push(o);
				}
				self.grid.createHeader(data);
			}
			OAT.Event.attach(self.container,"scroll",function(event){event.cancelBubble = true;});
			OAT.Event.attach(self.container,"mousewheel",function(event){event.cancelBubble = true;});
			OAT.Event.attach(self.container,"DOMMouseScroll",function(event){event.cancelBubble = true;});
		}

		self.bindHeaderCallback = function(header) {
			var data = [];
			for (var i=0;i<header.length;i++) {
				var o = {
					value:header[i],
					sortable:1,
					draggable:1,
					resizable:1
				}
				data.push(o);
			}
			self.grid.createHeader(data);
		}

		self.bindRecordCallback = function(dataRow, currentIndex) {
			for (var i=0;i<self.grid.rows.length;i++) { self.grid.rows[i].deselect(); }
			if (self.grid.rows.length + self.pageIndex >= currentIndex) { self.grid.rows[currentIndex - self.pageIndex].select(); }
		}

		self.bindPageCallback = function(dataRows, currentPageIndex) {
			var value = [];
			var fs = self.datasources[0].fieldSets[0];
			if (self.showAll && dataRows.length) {
				fs.realIndexes = [];
				for (var i=0;i<dataRows[0].length;i++) { fs.realIndexes.push(i); }
			}
			for (var i=0;i<dataRows.length;i++) {
				var row = [];
				for (var j=0;j<fs.realIndexes.length;j++) {
					row.push(dataRows[i][fs.realIndexes[j]]);
				}
				value.push(row);
			}
			self.grid.options.rowOffset = currentPageIndex;
			self.setValue(value);
			self.pageIndex = currentPageIndex;
		}
		OAT.FormObject.abstractParent(self,x,y);
	},

	flash:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.resizable = true;
		self.name="flash";
		if (designMode) {
			self.elm = OAT.Dom.create("div",{border:"1px solid #00f",backgroundColor:"#ddf",width:"100px",height:"100px"});
			self.elm.innerHTML = "Flash";
		} else {
			self.elm = OAT.Dom.create("object");
			self.param = OAT.Dom.create("param");
			self.param.setAttribute("name","movie");
			self.embed = OAT.Dom.create("embed");
			self.embed.setAttribute("type","application/x-shockwave-flash");
			self.embed.setAttribute("wmode","transparent");
			var p = OAT.Dom.create("param");
			p.setAttribute("name","wmode");
			p.setAttribute("value","transparent");
			OAT.Dom.append([self.elm,self.param,p]);
		}
		self.datasources = [
			{ds:false,fieldSets:[
				{name:"Source",variable:false,columnIndexes:[-1],names:[],realIndexes:[]}
			]}
		];
		self.clear = function() {
		}
		self.setValue = function(value) {
			OAT.Dom.unlink(self.embed);
			var dims = OAT.Dom.getWH(self.elm);
			self.embed.style.width = dims[0]+"px";
			self.embed.style.height = dims[1]+"px";
			self.param.setAttribute("value",value);
			self.embed.setAttribute("src",value);
			self.elm.appendChild(self.embed);
		}
		self.bindRecordCallback = function(dataRow,currentIndex) {
			if (!dataRow) { return; }
			var value = dataRow[self.datasources[0].fieldSets[0].realIndexes[0]];
			self.setValue(value);
		}
		self.notify = function() { /* when waiting for new image, clear the old one */
			self.clear();
		}
		OAT.FormObject.abstractParent(self,x,y);
	},

	decodeImage:function(data) {
		var decoded = OAT.Crypto.base64d(data);
		var mime = "image/";
		switch (decoded.charAt(1)) {
			case "I": mime += "gif"; break;
			case "P": mime += "png"; break;
			case "M": mime += "bmp"; break;
			default: mime += "jpeg"; break;
			
		}
		var src="data:"+mime+";base64,"+data;
		return src;
	},
	
	image:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.resizable = true;
		self.name="image";
		if (designMode) {
			self.elm = OAT.Dom.create("div",{border:"1px solid #00f",backgroundColor:"#ddf",width:"100px",height:"100px"});
			self.elm.innerHTML = "Image";
		} else {
			self.elm = OAT.Dom.create("img");
		}
		self.datasources = [
			{ds:false,fieldSets:[
				{name:"Source",variable:false,columnIndexes:[-1],names:[],realIndexes:[]}
			]}
		];

		self.properties = [
			{name:"User specified size",value:"0",type:"bool"}
		];

		self.clear = function() {
			self.elm.src = "";
		}
		self.setValue = function(value) {
			if (self.properties[0].value == "0") {
				self.elm.style.width = "";
				self.elm.style.height = "";
			}
			if (value.match(/\./)) {
				/* URL */
				self.elm.src = value;
				return;
			}
			if (OAT.Browser.isIE) { return; } /* IE doesn't support data: URLs */
			self.elm.src = OAT.FormObject.decodeImage(value);
		}
		self.bindRecordCallback = function(dataRow,currentIndex) {
			if (!dataRow) { return; }
			var value = dataRow[self.datasources[0].fieldSets[0].realIndexes[0]];
			self.setValue(value);
		}
		self.notify = function() { /* when waiting for new image, clear the old one */
			self.clear();
		}
		OAT.FormObject.abstractParent(self,x,y);
	},

	imagelist:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="imagelist";
		if (designMode) {
			self.elm = OAT.Dom.create("div",{border:"1px solid #00f",backgroundColor:"#ddf",width:"100px",height:"100px"});
			self.elm.innerHTML = "Image list";
		} else {
			self.elm = OAT.Dom.create("table");
			self.tbody = OAT.Dom.create("tbody");
			var thead = OAT.Dom.create("thead");
			self.elm.appendChild(thead);
			self.elm.appendChild(self.tbody);
		}
		self.properties = [
			{name:"Columns",type:"select",value:"3",options:["1","2","3","4","5","6","7","8"]}
		];
		self.datasources = [
			{ds:false,fieldSets:[
				{name:"Small image",variable:false,columnIndexes:[-1],names:[],realIndexes:[]},
				{name:"Large image",variable:false,columnIndexes:[-1],names:[],realIndexes:[]}
			]}
		];
		self.clear = function() {
			OAT.Dom.clear(self.tbody);
		}
		self.setValue = function(value) {
			self.clear();
			if (OAT.Browser.isIE) { return; }
			var limit = parseInt(self.properties[0].value);
			var tr = OAT.Dom.create("tr");

			for (var i=0;i<value.length;i++) {
				var small = value[i][0];
				var large = value[i][0]; /* large == link */
				var img = OAT.Dom.create("img");
				if (small.match(/\./)) {
					img.src = small;
				} else {
					img.src = OAT.Dom.decodeImage(small);
				}
				var td = OAT.Dom.create("td");
				var a = OAT.Dom.create("a");
				a.target = "_blank";
				a.href = large;

				a.appendChild(img);
				td.appendChild(a)
				tr.appendChild(td);

				if (!((i+1) % limit)) {
					self.tbody.appendChild(tr);
					var tr = OAT.Dom.create("tr");
				}
			} /* for all images */
			if ((i+1) % limit) { self.tbody.appendChild(tr); }
		}

		self.bindPageCallback = function(dataRows, currentPageIndex) {
			var value = [];
			var fs1 = self.datasources[0].fieldSets[0];
			var fs2 = self.datasources[0].fieldSets[1];
			for (var i=0;i<dataRows.length;i++) {
				var small = dataRows[i][fs1.realIndexes[0]];
				var large = dataRows[i][fs2.realIndexes[0]];
				value.push([small,large]);
			}
			self.setValue(value);
		}
		self.notify = function() { /* when waiting for new image, clear the old one */
			self.clear();
		}
		OAT.FormObject.abstractParent(self,x,y);
	},

	cloud:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="cloud";
		self.resizable = true;
		if (designMode) {
			self.elm = OAT.Dom.create("div",{border:"1px solid #00f",backgroundColor:"#ddf",width:"100px",height:"100px"});
			self.elm.innerHTML = "Tag Cloud";
		} else {
			self.elm = OAT.Dom.create("div",{border:"1px solid #000"});
			self.elm.className = "tag_cloud";
		}
		self.properties = [
			{name:"Minimum size",type:"string",value:"8px"},
			{name:"Maximum size",type:"string",value:"40px"},
		];
		self.datasources = [
			{ds:false,fieldSets:[
				{name:"Label",variable:false,columnIndexes:[-1],names:[],realIndexes:[]},
				{name:"Link",variable:false,columnIndexes:[-1],names:[],realIndexes:[]},
				{name:"Frequency",variable:false,columnIndexes:[-1],names:[],realIndexes:[]}
			]}
		];
		self.clear = function() {
			OAT.Dom.clear(self.elm);
		}
		self.setValue = function(value) {
			self.clear();
			var min = parseFloat(self.properties[0].value);
			var max = parseFloat(self.properties[1].value);
			var minf = 10000;
			var maxf = 0;
			for (var i=0;i<value.length;i++) { /* analyze extremes */
				var f = parseFloat(value[i][2]);
				if (f > maxf) { maxf = f; }
				if (f < minf) { minf = f; }
			}
			var coef = (max - min) / (maxf - minf);
			for (var i=0;i<value.length;i++) {
				var a = OAT.Dom.create("a");
				a.innerHTML = value[i][0];
				a.href = value[i][1];
				var f = parseFloat(value[i][2]);
				var percent = (f-minf)/(maxf-minf);
				var s = min + coef * (f - minf);
				a.style.fontSize = Math.round(s) + "px";
				if (percent > 0.6) { a.style.fontWeight = "bold"; }
				if (percent > 0.2) { a.style.color = "#6c9"; }
				if (percent > 0.4) { a.style.color = "#c33"; }
				if (percent > 0.6) { a.style.color = "#393"; }
				if (percent > 0.8) { a.style.color = "#90c"; }

				self.elm.appendChild(a);
				self.elm.appendChild(OAT.Dom.text(" "));
			}
		}

		self.bindPageCallback = function(dataRows, currentPageIndex) {
			var value = [];
			var fs1 = self.datasources[0].fieldSets[0];
			var fs2 = self.datasources[0].fieldSets[1];
			var fs3 = self.datasources[0].fieldSets[2];
			for (var i=0;i<dataRows.length;i++) {
				var label = dataRows[i][fs1.realIndexes[0]];
				var link = dataRows[i][fs2.realIndexes[0]];
				var freq = dataRows[i][fs3.realIndexes[0]];
				value.push([label,link,freq]);
			}
			self.setValue(value);
		}
		self.notify = function() { /* when waiting for new image, clear the old one */
			self.clear();
		}
		OAT.FormObject.abstractParent(self,x,y);
	},

	graph:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="graph";
		self.resizable = true;
		if (designMode) {
			self.elm = OAT.Dom.create("div",{border:"1px solid #00f",backgroundColor:"#ddf",width:"100px",height:"100px"});
			self.elm.innerHTML = "RDF Graph";
		} else {
			self.elm = OAT.Dom.create("div",{border:"1px solid #000"});
			self.elm.className = "rdf_graph";
		}
		self.properties = [
/* 0 */		{name:"Type",value:1,type:"select",options:[["All nodes at once",0],["Equal distances",1]],positionOverride:2},
/* 1 */		{name:"Disable runtime editing",value:"0",type:"bool",positionOverride:2},
/* 2 */		{name:"Placement",value:0,type:"select",options:[["Random",0],["Circle",1]],positionOverride:2},
/* 3 */		{name:"Disable runtime editing",value:"0",type:"bool",positionOverride:2},
/* 4 */		{name:"Distance",value:1,type:"select",options:[["Close",0],["Medium",1],["Far",2]],positionOverride:2},
/* 5 */		{name:"Disable runtime editing",value:"0",type:"bool",positionOverride:2},
/* 6 */		{name:"Projection",value:0,type:"select",options:[["Planar",0],["Pseudo-spherical",1]],positionOverride:2},
/* 7 */		{name:"Disable runtime editing",value:"0",type:"bool",positionOverride:2},
/* 8 */		{name:"Labels",value:0,type:"select",options:[["On active node only",0],["Up to distance 1",1],["Up to distance 2",2],["Up to distance 3",3],["Up to distance 4",4],],positionOverride:2},
/* 9 */		{name:"Disable runtime editing",value:"0",type:"bool",positionOverride:2},
/* 10 */	{name:"Visible",value:0,type:"select",options:[["All nodes",0],["Selected up to distance 1",1],["Selected up to distance 2",2],["Selected up to distance 3",3],["Selected up to distance 4",4],],positionOverride:2},
/* 11 */	{name:"Disable runtime editing",value:"0",type:"bool",positionOverride:2},
		];

		self.datasources = [
			{ds:false,fieldSets:[
				{name:"Datasource",variable:false,names:[],columnIndexes:[],realIndexes:[]}
			]}
		];

		self.clear = function() {
			// OAT.Dom.clear(self.elm);
		}
		self.setValue = function(rdfDoc) {
			var triples = OAT.RDF.toTriples(rdfDoc);
			var x = OAT.GraphSVGData.fromTriples(triples);
			var ds = [];
			if (self.properties[1].value == "1") { ds.push("type"); }
			if (self.properties[3].value == "1") { ds.push("placement"); }
			if (self.properties[5].value == "1") { ds.push("distance"); }
			if (self.properties[7].value == "1") { ds.push("projection"); }
			if (self.properties[8].value == "1") { ds.push("labels"); }
			if (self.properties[11].value == "1") { ds.push("show"); }
			var opts = {vertexSize:[4,8]}
			opts.type = parseInt(self.properties[0].value);
			opts.placement = parseInt(self.properties[2].value);
			opts.distance = parseInt(self.properties[4].value);
			opts.projection = parseInt(self.properties[6].value);
			opts.labels = parseInt(self.properties[8].value);
			opts.show = parseInt(self.properties[10].value);
			opts.disabledSelects = ds;
			self.obj = new OAT.GraphSVG(self.elm,x[0],x[1],opts);
			OAT.Resize.createDefault(self.elm,false,self.obj.drawUpdate);
		}
		self.bindFileCallback = function(rdfText) {
			var rdfDoc = OAT.Xml.createXmlDoc(rdfText);
			self.setValue(rdfDoc);
		}
		self.notify = function() { /* when waiting for new image, clear the old one */
			self.clear();
		}
		OAT.FormObject.abstractParent(self,x,y);
	},

	twostate:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="twostate";
		self.resizable = true;
		self.elm = OAT.Dom.create("div");
		self.rowOffset = 0; /* for grid auto-numbering */
		self.datasources = [
			{ds:false,fieldSets:[
				{name:"Columns",variable:true,names:[],columnIndexes:[],realIndexes:[]}
			]}
		];
		self.properties = [
			{name:"Default state",value:"Single",type:"select",options:["Single","Tabular"]}
		];
		if (designMode) {
			self.elm.style.width = "200px";
			self.elm.style.height = "200px";
			self.elm.innerHTML = "Two state control";
			self.elm.style.border = '1px solid #000';
		} else {
			self.elm.style.backgroundColor = '#ccc';
			var notBGcolor = "";
			var BGcolor = "#eee";
			var toggler = OAT.Dom.create("div",{position:"absolute",left:"0px",top:"-20px"});
			var prop = self.properties[0];
			var s = OAT.Dom.create("div",{cssFloat:"left",styleFloat:"left",cursor:"pointer",padding:"2px",margin:"1px"});
			s.innerHTML = "Single";
			toggler.appendChild(s);
			var t = OAT.Dom.create("div",{cssFloat:"left",styleFloat:"left",cursor:"pointer",padding:"2px",margin:"1px"});
			t.innerHTML = "Tabular";
			toggler.appendChild(t);
			var sRef = function() {
				self.properties[0].value = "Single";
				self.init();
				self.setValue(self.lastValueSingle);
			}
			var tRef = function() {
				self.properties[0].value = "Tabular";
				self.init();
				self.setValue(self.lastValueTabular);
			}
			self.elm.appendChild(toggler);
			OAT.Event.attach(s,"click",sRef);
			OAT.Event.attach(t,"click",tRef);
			self.container = OAT.Dom.create("div",{position:"relative",width:"100%",height:"100%"});
			self.container.style.overflow = "auto";
			self.elm.appendChild(self.container);
		}

		self.setValue = function(data) {
			switch (self.properties[0].value) {
				case "Single":
					for (var i=0;i<data.length;i++) {
						self.values[i].value = data[i];
					}
				break;

				case "Tabular":
					self.grid.clearData();
					self.grid.options.rowOffset = self.rowOffset;
					for (var i=0;i<data.length;i++) {
						self.grid.createRow(data[i]);
					}
					for (var i=0;i<self.grid.rows.length;i++) { self.grid.rows[i].deselect(); }
					if (self.grid.rows.length + self.pageIndex >= self.recordIndex && self.recordIndex >= self.pageIndex) {
						self.grid.rows[self.recordIndex - self.pageIndex].select();
					}
				break;
			}
		}
		self.clear = function() {
			switch (self.properties[0].value) {
				case "Single":
					for (var i=0;i<data.length;i++) {
						self.values[i].value = "";
					}
				break;

				case "Tabular":
					self.grid.clearData();
				break;
			}
		}
		self.init = function() {
			OAT.Dom.clear(self.container);
			switch (self.properties[0].value) {
				case "Single":
					s.style.backgroundColor = BGcolor;
					t.style.backgroundColor = notBGcolor;
					self.labels = [];
					self.values = [];
					var maxW = 0;
					var fs = self.datasources[0].fieldSets[0];
					for (var i=0;i<fs.names.length;i++) {
						var lbl = OAT.Dom.create("div",{position:"absolute",left:"3px"});
						lbl.style.top = (4+i*24)+"px";
						var label = fs.names[i];
						if (label == "") { label = self.datasources[0].ds.outputFields[fs.realIndexes[i]]; }
						lbl.innerHTML = label+":";
						self.container.appendChild(lbl);
						self.labels.push(lbl);
						var dims = OAT.Dom.getWH(lbl);
						if (dims[0] > maxW) { maxW = dims[0]; }

						var value = OAT.Dom.create("input",{position:"absolute",left:"3px"});
						value.setAttribute("type","text");
						value.style.top = (2+i*24)+"px";
						self.container.appendChild(value);
						self.values.push(value);
					}
					for (var i=0;i<fs.names.length;i++) {
						var dims = OAT.Dom.getWH(self.labels[i]);
						self.labels[i].style.left = (2+maxW-dims[0])+"px";
						self.values[i].style.left = (maxW+10)+"px";
					}
				break;

				case "Tabular":
					s.style.backgroundColor = notBGcolor;
					t.style.backgroundColor = BGcolor;
					var data = [];
					var fs = self.datasources[0].fieldSets[0];

					for (var i=0;i<fs.names.length;i++) {
						var label = fs.names[i];
						if (label == "") { label = self.datasources[0].ds.outputFields[fs.realIndexes[i]]; }
						var o = {
							value:label,
							sortable:1,
							draggable:1,
							resizable:1
						}
						data.push(o);
					}
					self.grid = new OAT.Grid(self.container,{autoNumber:true});
					self.grid.options.reorderNotifier = function(i1,i2) {
						var fs = self.datasources[0].fieldSets[0];
						var tmp = fs.realIndexes[i1-1];
						var newi = (i1 < i2 ? i2-2 : i2-1);
						fs.realIndexes.splice(i1-1,1);
						fs.realIndexes.splice(newi,0,tmp);
					}
					self.grid.createHeader(data);

					OAT.Event.attach(self.container,"scroll",function(event){event.cancelBubble = true;});
					OAT.Event.attach(self.container,"mousewheel",function(event){event.cancelBubble = true;});
					OAT.Event.attach(self.container,"DOMMouseScroll",function(event){event.cancelBubble = true;});
				break;
			} /* switch */
		} /* FormObject::init() */

		self.bindRecordCallback = function(dataRow, currentIndex) {
			self.recordIndex = currentIndex;
			var value = [];
			var fs = self.datasources[0].fieldSets[0];
			for (var i=0;i<fs.realIndexes.length;i++) {
				value.push(dataRow[fs.realIndexes[i]]);
			}
			self.lastValueSingle = value;
			if (self.properties[0].value == "Single") { self.setValue(value); }
			if (!self.grid) { return; }
			for (var i=0;i<self.grid.rows.length;i++) { self.grid.rows[i].deselect(); }
			if (self.grid.rows.length + self.pageIndex >= self.recordIndex) {
				self.grid.rows[self.recordIndex - self.pageIndex].select();
			}

		}

		self.bindPageCallback = function(dataRows, currentPageIndex) {
			self.pageIndex = currentPageIndex;
			var value = [];
			var fs = self.datasources[0].fieldSets[0];
			for (var i=0;i<dataRows.length;i++) {
				var row = [];
				for (var j=0;j<fs.realIndexes.length;j++) {
					row.push(dataRows[i][fs.realIndexes[j]]);
				}
				value.push(row);
			}
			self.lastValueTabular = value;
			self.rowOffset = currentPageIndex;
			if (self.properties[0].value == "Tabular") { self.setValue(value); }
		}
		OAT.FormObject.abstractParent(self,x,y);
	},

	nav:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="nav";
		self.elm = OAT.Dom.create("div");
		self.first = OAT.Dom.create("input");
		self.prevp = OAT.Dom.create("input");
		self.prev = OAT.Dom.create("input");
		self.next = OAT.Dom.create("input");
		self.nextp = OAT.Dom.create("input");
		self.last = OAT.Dom.create("input");
		self.first.setAttribute("type","button");
		self.prevp.setAttribute("type","button");
		self.prev.setAttribute("type","button");
		self.next.setAttribute("type","button");
		self.nextp.setAttribute("type","button");
		self.last.setAttribute("type","button");
		self.first.value = "|<<";
		self.prevp.value = "<<";
		self.prev.value = "<";
		self.next.value = ">";
		self.nextp.value = ">>";
		self.last.value = ">>|";

		self.current = OAT.Dom.create("input");
		self.current.setAttribute("type","text");
		self.current.setAttribute("size","2");
		self.total = OAT.Dom.create("span");
		self.elm.appendChild(self.first);
		self.elm.appendChild(self.prevp);
		self.elm.appendChild(self.prev);
		self.elm.appendChild(self.current);
//		self.elm.appendChild(self.total);
		self.elm.appendChild(self.next);
		self.elm.appendChild(self.nextp);
//		self.elm.appendChild(self.last);

		self.datasources = [
			{ds:false,fieldSets:[
				{name:"Datasource",variable:false,names:[],columnIndexes:[],realIndexes:[]}
			]}
		];

		self.clear = function() {
//			self.total.innerHTML = "";
			self.current.value = "";
		}

		self.bindRecordCallback = function(dataRow,currentIndex) {
			self.current.value = currentIndex+1;
//			self.total.innerHTML = totalCount;
		}
		OAT.FormObject.abstractParent(self,x,y);
	},

	url:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="url";
		self.resizable = true;
		self.elm = OAT.Dom.create("div");
		if (designMode) {
			self.elm.innerHTML = "URL";
		}
		self.datasources = [
			{ds:false,fieldSets:[
				{name:"Target",variable:false,columnIndexes:[-1],names:[],realIndexes:[]},
				{name:"Description",variable:false,columnIndexes:[-1],names:[],realIndexes:[]}
			]}
		];
		self.properties = [
			{name:"Embed into page",value:"1",type:"bool"},
			{name:"Protocol",value:"",type:"string"},
			{name:"Host",value:"",type:"string"},
			{name:"Port",value:"",type:"string"},
			{name:"Base directory",value:"",type:"string"}
		];
		self.css = [
			{name:"Color",property:"color",type:"color"},
			{name:"BG Color",property:"backgroundColor",type:"color"},
			{name:"Font size",property:"fontSize",type:"combo",options:["60%","80%","100%","120%","140%"]}
		];
		self.clear = function() {
			OAT.Dom.clear(self.elm);
		}
		self.setValue = function(target,label) {
			OAT.Dom.clear(self.elm);
			/* if properties are filled, create the target */
			if (self.properties[2].value != "") {
				var proto = self.properties[1].value;
				var host = self.properties[2].value;
				var port = self.properties[3].value;
				var dir = self.properties[4].value;
				proto = (proto != "" ? proto : "http://");
				port = (port == "" ? "" : ":"+port);
				host = proto+host+port;
				if (dir.charAt(0) != "/") { dir = "/"+dir; }
				if (dir.charAt(dir.length-1) != "/") { dir += "/"; }
				target = (target.charAt(0) == "/" ? target.substring(1) : target);
				target = host+dir+target;
			}
			if (self.properties[0].value == "1") {
				/* guess type from address */
				var type = "unknown";
				if (target.match(/(gif|png|jpe?g)$/i)) { type="img"; }
				if (target.match(/swf$/i)) { type="flash"; }
				if (target.match(/rm$/i)) { type="rm"; }
				var data = false;
				switch (type) {
					case "flash":
						data = OAT.Dom.create("embed",{width:"100%",height:"100%"});
						data.setAttribute("src",target);
					case "rm":
					break;
					case "img":
						data = OAT.Dom.create("a");
						data.setAttribute("href",target);
						data.setAttribute("target","_blank");
						var img = OAT.Dom.create("img");
						img.src = target;
						img.title = label;
						data.appendChild(img);
					break;
					default:
					/* no links, just embeds */
					/*
						data = OAT.Dom.create("a");
						data.innerHTML = label;
						data.setAttribute("href",target);
						data.setAttribute("target","_blank");
					*/
						data = OAT.Dom.create("embed",{width:"100%",height:"100%"});
						data.setAttribute("src",target);
					break;
				}
				self.elm.appendChild(data);
			} else {
				/* simple link */
				var a = OAT.Dom.create("a");
				a.innerHTML = label;
				a.setAttribute("href",target);
				a.setAttribute("target","_blank");
				self.elm.appendChild(a);
			}
		}
		self.getValue = function() {
			return self.elm.innerHTML;
		}

		self.bindRecordCallback = function(dataRow,currentIndex) {
			var ri1 = self.datasources[0].fieldSets[0].realIndexes;
			var ri2 = self.datasources[0].fieldSets[1].realIndexes;
			if (ri1[0] == -1) { return; }
			var value = dataRow[ri1[0]];
			var label = (ri2[0] == -1 ? value : dataRow[ri2[0]]);
			self.setValue(value,label);
		}

		OAT.FormObject.abstractParent(self,x,y);
	},

	gem1:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="gem1";
		self.elm = OAT.Dom.create("div");

		var apply = function() {
			/* load saved query, add information about stylesheet, save as new saved query */
			var source = self.properties[1].value;
			var ss = self.properties[2].value;
			var target = self.properties[3].value;
			if (source == "") { alert("OAT.FormObject.apply:\nPlease select a saved query to process"); return; }
			if (ss == "") { alert("OAT.FormObject.apply:\nPlease select a stylesheet to create a feed"); return; }
			if (target == "") { alert("OAT.FormObject.apply:\nPlease select a target feed file"); return; }

			var processRef = function(query) {
				/* we have saved source query. append a stylesheet and save */
				var q = new OAT.SqlQuery();
				q.fromString(query);
				var result = q.toString(OAT.SqlQueryData.TYPE_SQLX_ELEMENTS);
				var xml = '<?xml version="1.0" encoding="UTF-8"?>\n';
				xml += '<root xmlns:sql="urn:schemas-openlink-com:xml-sql"';
				xml += ' sql:xsl="'+ss+'" ';
				xml += '><sql:sqlx>'+result+'</sql:sqlx></root>';
				var recv_ref = function() { alert("OAT.FormObject.processRef:\nNew saved query created"); }
				var o = {
					auth:OAT.AJAX.AUTH_BASIC,
					user:http_cred.user,
					password:http_cred.password
				}
				OAT.AJAX.PUT(target,xml,recv_ref,o);
			}

			OAT.AJAX.GET(source,false,processRef);
		}

		if (designMode) {
			self.elm.innerHTML = "GEM";
		} else {
			self.link = OAT.Dom.create("a");
			self.image = OAT.Dom.create("img");
			self.elm.appendChild(self.link);
			self.link.appendChild(self.image);
		}
		self.properties = [
			{name:"Icon file",value:"",type:"file",onselect:false,dialog:"open_dialog"},
			{name:"Saved query",value:"",type:"file",onselect:apply,dialog:"open_dialog"},
			{name:"XSLT template",value:"",type:"file",onselect:apply,dialog:"open_dialog"},
			{name:"Resulting file",value:"",type:"file",onselect:apply,dialog:"browser"},
			{name:"Label",value:"Syndicate!",type:"string"},
			{name:"Link name",value:"RSS Feed",type:"string"},
			{name:"MIME type",value:"application/rss+xml",type:"string"}
		];
		self.init = function() {
			var iurl = self.properties[0].value;
			if (iurl) {
				self.image.src = self.properties[0].value; /* draw proper icon */
			} else {
				OAT.Dom.unlink(self.image);
			}
			self.link.href = self.properties[3].value; /* will point at this feed */
			self.link.appendChild(OAT.Dom.text(" "+self.properties[4].value));
		}
		OAT.FormObject.abstractParent(self,x,y);
	},

	timeline:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="timeline";
		self.resizable = true;
		self.elm = OAT.Dom.create("div",{border:"1px solid #00f",backgroundColor:"#ddf",width:"100px",height:"100px"});
		self.datasources = [
			{ds:false,fieldSets:[
				{name:"Time",variable:false,columnIndexes:[-1],names:[],realIndexes:[]},
				{name:"Band",variable:false,columnIndexes:[-1],names:[],realIndexes:[]},
				{name:"Label",variable:false,columnIndexes:[-1],names:[],realIndexes:[]},
				{name:"Link",variable:false,columnIndexes:[-1],names:[],realIndexes:[]}
			]}
		];
		self.properties = [
			{name:"Lookup container",type:"container",value:false},
			{name:"Color scheme",type:"select",options:[["Rainbow",0],["Pastel",1],["Light",2],["Dark",3],["SIMILE-like",4]],value:0},
			{name:"Date format selectbox?",type:"bool",value:"1"}
		];
		if (designMode) {
			self.elm.innerHTML = "Timeline";
		} else {
			self.elm.style.backgroundColor = "transparent";
			self.elm.style.border = "none";
		}

		self.openWindow = function(x,y,event) {
			OAT.Dom.show(self.window.div);
			var pos = OAT.Event.position(event);
			self.window.anchorTo(pos[0],pos[1]);
			self.window.div.style.left = x+"px";
			self.window.div.style.top = y+"px";
		}

		self.closeWindow = function() {
			OAT.Dom.hide(self.window.div);
		}

		self.clickRef = function(dsIndex,index) {
			return function(event) {
				var coords = OAT.Event.position(event);
				if (self.form) {
					self.form.datasources[0].oneShotCallback = function() {
						self.window.content.appendChild(self.form.elm);
						self.form.elm.style.display = "block";
						self.openWindow(coords[0],coords[1]+25,event);
					}
				}
				self.closeWindow();
				self.datasources[dsIndex].ds.advanceRecord(index);
			}
		}

		self.setValue = function(value,dsIndex) { /* time,band,label,link,index */
			self.timeline.clear();
			var bands = {};
			for (var i=0;i<value.length;i++) {
				var b = value[i][1];
				bands[b] = 1;
			}

			var index = 0;
			var colorIndex = parseInt(self.properties[1].value);
			if (isNaN(colorIndex)) { colorIndex = 0; }
			var colors = [];
			if (colorIndex == 0)
				colors = ["rgb(255,204,153)","rgb(255,255,153)","rgb(153,255,153)","rgb(153,255,255)",
				"rgb(153,204,255)","rgb(204,153,255)","rgb(255,153,204)"]; /* rainbow */
			if (colorIndex == 1)
				colors = ["#cf6","#887fff","#66ffe6",
				"#fb9","#7fff66","#ff997f","#96f"]; /* pastel */
			if (colorIndex == 2)
				colors = ["#6ff","#66b3ff","#b3ff66","#eb0075",
				"#ffb366","#66f","#f6f"]; /* light */
			if (colorIndex == 3)
				colors = ["#630","#603","#660","#306",
				"#360","#e07000","#036"]; /* dark */
			if (colorIndex == 4)
				colors = ["#4F7F9E","#BF7730","rgb(128,128,128)",
				"rgb(88,160,220)","rgb(255,128,64)","#406780"]; /* simile */

			for (var p in bands) {
				var c = colors[index % colors.length];
				self.timeline.addBand(p,c);
				index++;
			}

			for (var i=0;i<value.length;i++) {
				var time = value[i][0];
				var band = value[i][1];
				var label = value[i][2];
				var link = value[i][3];
				var index = value[i][4];
				var div = OAT.Dom.create("div",{left:"-7px"});
				var ball = OAT.Dom.create("div",{width:"16px",height:"16px",cssFloat:"left",styleFloat:"left"});
				var bg = "url(" + OAT.Preferences.imagePath + "Timeline_circle.png)";
				ball.style.backgroundImage = bg;
				if (link == "") {
					var t = OAT.Dom.create("span");
				} else {
					var t = OAT.Dom.create("a");
					t.href = link;
					t.target = "_blank";
				}
				t.innerHTML = OAT.Dom.toSafeXML(label);
				div.appendChild(ball);
				div.appendChild(t);
				var e = self.timeline.addEvent(band,time,false,div,"#abf");
				OAT.Event.attach(e.elm,"click",self.clickRef(dsIndex,index));
			}
			self.timeline.draw();
			self.timeline.slider.slideTo(0,1);
		}

		self.getValue = function() { return false; }

		self.init = function() {
			var opts = {formatter:1,autoHeight:false};
			if (self.properties[2].value == 0) { opts.formatter = 0; }
			self.timeline = new OAT.Timeline(self.elm,opts);

			self.form = false;
			if (self.properties[0].value) { self.form = self.properties[0].value; }

			self.window = new OAT.Window({close:1,max:0,min:0,width:0,height:0,x:0,y:0,title:"Lookup window",resize:0},OAT.Window.TYPE_RECT);
			document.body.appendChild(self.window.div);
			self.window.onclose = self.closeWindow;
			self.closeWindow();
		}

		self.bindPageCallback = function(dataRows,currentPageIndex,dsIndex) {
			var values = [];
			var ds = self.datasources[0];
			for (var i=0;i<dataRows.length;i++) {
				var time = dataRows[i][ds.fieldSets[0].realIndexes[0]];
				var index = ds.fieldSets[1].realIndexes[0];
				var band = (index == -1 ? "Data" : dataRows[i][index]);
				var label = dataRows[i][ds.fieldSets[2].realIndexes[0]];
				var index = ds.fieldSets[3].realIndexes[0];
				var link = (index == -1 ? "" : dataRows[i][index]);
				var index = currentPageIndex+i;
				values.push([time,band,label,link,index]);
			}
			self.setValue(values,dsIndex);
		}

		OAT.FormObject.abstractParent(self,x,y);
	} /* timeline */

}
