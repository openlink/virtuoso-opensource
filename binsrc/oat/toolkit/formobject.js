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
	new OAT.FormObject[name](x, y, designMode)
	-- appearance --
	FormObject::select()
	FormObject::deselect()
	-- data --
 	FormObject::getValue() - useful only in design when userSet is true
 	FormObject::setValue() - dtto
	FormObject::notify() - we will recieve new data soon
 	FormObject::init() - initialization, when all data are bound
 	FormObject::clear()
 	FormObject::loadXML()
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
	object.datasources - array of objects:
	{
		name:"name",
		variable:true,
		names:[],
		columnIndexes:[],  -- indexes of all columns in datasource
		realIndexes:[]     -- indexes of columns in current query
	}
	object.properties - array of objects:
	{
		name:"name",
		value:"value",
		type:"string|bool|color|select|combo|form"
	}
	object.css - array of objects:
	{
		name:"Color",
		propery:"color",
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
	"pivot":"Pivot table",
	"image":"Image",
	"imagelist":"Image list",
	"twostate":"Tabular/Columnar Combo",
	"nav":"Navigation",
	"url":"URL",
	"date":"Date",
	"timeline":"Time line",
	"gem":"Syndication gem"
}


OAT.FormObject = {
	init:function(fo) { /* basic default properties */
		fo.name = "";
		fo.hidden = 0;
		fo.resizable = false;
		fo.userSet = false;
		fo.form = false;
		fo.elm = OAT.Dom.create("div");
		fo.bindRecordCallback = false;
		fo.bindPageCallback = false;
		fo.datasources = [];
		fo.properties = [];
		fo.css = [];
		fo.init = function(){};
		fo.getValue = function(){return false;};
		fo.setValue = function(){};
		fo.clear = function(){};
		fo.notify = function(){};
	},
	
	abstractParent:function(fo,x,y) {
		fo.loadXML = function(node) {
			var tmp;
			if (node.getAttribute("hidden")) { fo.hidden = 1; }
			/* css */
			tmp = node.getElementsByTagName("style")[0];
			fo.elm.style.left = tmp.getAttribute("left")+"px";
			fo.elm.style.top = tmp.getAttribute("top")+"px";
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
			for (var i=0;i<tmp.length;i++) {
				var name = tmp[i].getElementsByTagName("name")[0];
				var value = tmp[i].getElementsByTagName("value")[0];
				var obj = fo.properties[i];
				obj.value = OAT.Xml.textValue(value);
				if (obj.name != OAT.Xml.textValue(name)) { alert('Panic! Saved data incomplete?'); }
			}
			/* datasources */
			tmp = node.getElementsByTagName("datasources")[0];
			var dss = tmp.getElementsByTagName("datasource");
			for (var i=0;i<dss.length;i++) {
				var ds = dss[i]; /* node */
				var obj = fo.datasources[i]; /* add values to this object */
				var name = ds.getAttribute("name");
				if (obj.name != name) { alert('Panic! Saved data incomplete?'); }
				
				var names = ds.getElementsByTagName("name"); /* all <name> subnodes */
				var indexes = ds.getElementsByTagName("columnIndex"); /* all <columnIndex> subnodes */
				obj.names = [];
				obj.columnIndexes = [];
				for (var j=0;j<names.length;j++) { obj.names.push(OAT.Xml.textValue(names[j])); }
				for (var j=0;j<indexes.length;j++) { obj.columnIndexes.push(OAT.Xml.textValue(indexes[j])); }
			}
		}	
		
		fo.actualizeResizers = function() {
			if (!fo.resizeXY) { return; }
			var w = fo.elm.offsetWidth;
			var h = fo.elm.offsetHeight;
			var x = fo.elm.offsetLeft;
			var y = fo.elm.offsetTop;

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
				fo.resizeX = OAT.Dom.create("div",{position:"absolute",width:"6px",height:"6px",backgroundColor:"#f00",border:"1px solid #000",overflow:"hidden"});
				fo.resizeY = OAT.Dom.create("div",{position:"absolute",width:"6px",height:"6px",backgroundColor:"#f00",border:"1px solid #000",overflow:"hidden"});
				fo.resizeXY = OAT.Dom.create("div",{position:"absolute",width:"6px",height:"6px",backgroundColor:"#f00",border:"1px solid #000",overflow:"hidden"});
				
				fo.actualizeResizers();

				var parent = fo.elm.parentNode;
				parent.appendChild(fo.resizeX);
				parent.appendChild(fo.resizeY);
				parent.appendChild(fo.resizeXY); 
				
				OAT.Resize.create(fo.resizeX,fo.elm,OAT.Resize.TYPE_X);
				OAT.Resize.create(fo.resizeY,fo.elm,OAT.Resize.TYPE_Y);
				OAT.Resize.create(fo.resizeXY,fo.elm,OAT.Resize.TYPE_XY);
				
				var cancelFunc = function(event) { event.cancelBubble = true; }
				OAT.Dom.attach(fo.resizeX,"mousedown",cancelFunc);
				OAT.Dom.attach(fo.resizeY,"mousedown",cancelFunc);
				OAT.Dom.attach(fo.resizeXY,"mousedown",cancelFunc);
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
		
		fo.toXML = function(designer) {
			var xml = "";
			var e = fo.elm;
			var x = e.offsetLeft;
			var y = e.offsetTop;
			var w = e.offsetWidth;
			var h = e.offsetHeight;
			/* element */
			xml += '<object type="'+fo.name+'" ';
			if (fo.hidden == "1") { xml += 'hidden="1" '; }
			xml += 'value="'+fo.getValue()+'">\n';
			/* style */
			xml += '\t\t\t<style left="'+x+'" top="'+y+'" ';
			if (fo.resizable) { xml += ' width="'+w+'" height="'+h+'" '; }
			xml += '>\n';
			xml += '\t\t\t\t<css ';
			for (var i=0;i<fo.css.length;i++) {
				var css = fo.css[i];
				xml += ' '+css.property+'="'+OAT.Dom.style(e,css.property)+'" ';
			}
			xml += '></css>\n';
			xml += '\t\t\t</style>\n';
			/* properties */
			xml += '\t\t\t<properties>\n';
			for (var i=0;i<fo.properties.length;i++) {
				var p = fo.properties[i];
				xml += '\t\t\t\t<property>\n';
				xml += '\t\t\t\t\t<name>'+p.name+'</name>\n';
				if (p.type != "form") {
					xml += '\t\t\t\t\t<value>'+p.value+'</value>\n';
				} else {
					var index = designer.forms.find(p.value);
					xml += '\t\t\t\t\t<value>'+index+'</value>\n';
				}
				xml += '\t\t\t\t\t<type>'+p.type+'</type>\n';
				xml += '\t\t\t\t</property>\n';
			}
			xml += '\t\t\t</properties>\n';
			/* datasources */
			xml += '\t\t\t<datasources>\n';
			for (var i=0;i<fo.datasources.length;i++) {
				var ds = fo.datasources[i];
				xml += '\t\t\t\t<datasource name="'+ds.name+'" variable="'+(ds.variable ? 1 : 0)+'">\n';
				for (var j=0;j<ds.names.length;j++) {
					xml += '\t\t\t\t\t<name>'+ds.names[j]+'</name>\n';
				}
				for (var j=0;j<ds.columnIndexes.length;j++) {
					xml += '\t\t\t\t\t<columnIndex>'+ds.columnIndexes[j]+'</columnIndex>\n';
				}
				xml += '\t\t\t\t</datasource>\n';
			}
			xml += '\t\t\t</datasources>\n';
			xml += '\t\t</object>\n';

			return xml;
		}
		
		fo.selected = 0;
		fo.elm.style.position = "absolute";
		fo.elm.style.left = x+"px";
		fo.elm.style.top = y+"px";
		var actFunc = function(event) { fo.actualizeResizers(); }
		OAT.Dom.attach(document.body,"mousemove",actFunc);
	},
	
	label:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="label";
		self.resizable = true;
		self.elm = OAT.Dom.create("div");
		self.userSet = true; 
		self.datasources = [
			{name:"Value",variable:false,columnIndexes:[-1],names:[],realIndexes:[]}
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
			if (self.datasources[0].realIndexes[0] == -1) { return; }
			if (!dataRow) { return; }
			var value = dataRow[self.datasources[0].realIndexes[0]];
			self.setValue(value);
		}
		
		self.clear = function() {
			if (self.datasources[0].realIndexes[0] != -1) { self.elm.innerHTML = ""; }
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
			{name:"Value",variable:false,columnIndexes:[-1],names:[],realIndexes:[]}
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
			if (self.datasources[0].realIndexes[0] != -1) { self.elm.value = ""; }
		}
		
		self.bindRecordCallback = function(dataRow,currentIndex) {
			if (self.datasources[0].realIndexes[0] == -1) { return; }
			if (!dataRow) { return; }
			var value = dataRow[self.datasources[0].realIndexes[0]];
			self.setValue(value);
		}
		OAT.FormObject.abstractParent(self,x,y);
	},
	
	textarea:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="textarea";
		self.resizable = true;
		self.elm = OAT.Dom.create("textarea");
		self.datasources = [
			{name:"Value",variable:false,columnIndexes:[-1],names:[],realIndexes:[]}
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
			if (self.datasources[0].realIndexes[0] == -1) { return; }
			if (!dataRow) { return; }
			var value = dataRow[self.datasources[0].realIndexes[0]];
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
			{name:"Checked",variable:false,columnIndexes:[-1],names:[],realIndexes:[]}
		];
		self.setValue = function(value) {
			var x = value.toString();
			if (x.toUpperCase() == "TRUE") { x = 1; }
			var x = parseInt(x);
			self.elm.checked = (x ? true : false);
		}

		self.bindRecordCallback = function(dataRow,currentIndex) {
			if (self.datasources[0].realIndexes[0] == -1) { return; }
			if (!dataRow) { return; }
			var value = dataRow[self.datasources[0].realIndexes[0]];
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
	
	map:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="map";
		self.resizable = true;
		self.elm = OAT.Dom.create("div",{border:"1px solid #00f",backgroundColor:"#ddf",width:"100px",height:"100px",overflow:"hidden"});
		self.datasources = [
			{name:"Latitude",variable:false,columnIndexes:[-1],names:[],realIndexes:[]},
			{name:"Longitude",variable:false,columnIndexes:[-1],names:[],realIndexes:[]},
			{name:"Marker color",variable:false,columnIndexes:[-1],names:[],realIndexes:[]},
			{name:"Marker image",variable:false,columnIndexes:[-1],names:[],realIndexes:[]}
		];
		self.properties = [
/*0*/		{name:"Key",type:"string",value:""},
/*1*/		{name:"Zoom level",type:"select",value:"2",options:[["0 - Far","0"],"1","2","3","4","5","6","7","8","9","10","11","12","13","14","15",["16 - Near","16"]]},
/*2*/		{name:"Provider",type:"select",value:OAT.MapData.TYPE_G,options:[
				["Google",OAT.MapData.TYPE_G],["Yahoo!",OAT.MapData.TYPE_Y],
				["MS Virtual Earth",OAT.MapData.TYPE_MS],["OpenLayers",OAT.MapData.TYPE_OL]
			]},
/*3*/		{name:"All markers at once?",type:"bool",value:"0"},
/*4*/		{name:"Pin data source",type:"form",value:false},
/*5*/		{name:"Map type",type:"select",value:"Map",options:["Map","Satellite","Hybrid"]},
/*6*/		{name:"Marker overlap correction",type:"select",value:OAT.MapData.FIX_ROUND1,options:[
				["None",OAT.MapData.FIX_NONE],
				["Circle, center",OAT.MapData.FIX_ROUND1],
				["Circle, no center",OAT.MapData.FIX_ROUND2],
				["Vertical stack",OAT.MapData.FIX_STACK]
			]},
/*7*/		{name:"Marker image",type:"select",value:"",options:[["Normal",""],["People","p"]]},
/*8*/		{name:"Marker width",type:"string",value:"18"},
/*9*/		{name:"Marker height",type:"string",value:"41"}
		];
		if (designMode) {
			self.elm.innerHTML = "Map";
		}

		self.clickRef = function(index) {
			return function(marker) {
				window.debug.push(marker);
				window.debug.push(index);
				self.map.closeWindow();
				/* call for data */
				if (self.properties[4].value != -1) {
					self.properties[4].value.oneShotCallback = function() {
						self.map.openWindow(marker,self.properties[4].value.div);
					}
				}
				self.form.dso.advanceRecord(index);
			}
		}
		self.setValue = function(value) { /* lat,lon,index,image */
			self.map.removeMarkers();
			if (self.multi) {
				var pointArr = [];
				for (var i=0;i<value.length;i++) { 
					var lat = value[i][0];
					var lon = value[i][1];
					pointArr.push([lat,lon]); 
					self.map.addMarker(lat,lon,value[i][3],self.markerWidth,self.markerHeight,self.clickRef(value[i][2]));
				}
				self.map.optimalPosition(pointArr);
				var az = self.map.getZoom();
				if (self.zoom > az) { self.zoom = az; }
				self.map.setZoom(self.zoom);
			} else {
				var lat = value[0][0];
				var lon = value[0][1];
				self.map.addMarker(lat,lon,value[0][3],self.markerWidth,self.markerHeight,self.clickRef(value[0][2]));
				self.zoom = self.map.getZoom();
				self.map.centerAndZoom(lat,lon,self.zoom);
			}
		}
		self.getValue = function() { return false; }
		self.init = function() {
			self.zoom = parseInt(self.properties[1].value);
			switch (parseInt(self.properties[2].value)) {
				case OAT.MapData.TYPE_G: self.provider = OAT.MapData.TYPE_G; break;
				case OAT.MapData.TYPE_Y: self.provider = OAT.MapData.TYPE_Y; break;
				case OAT.MapData.TYPE_MS: self.provider = OAT.MapData.TYPE_MS; break;
				case OAT.MapData.TYPE_OL: self.provider = OAT.MapData.TYPE_OL; break;
			}
			self.prefix = self.properties[7].value;
			self.multi = (self.properties[3].value == "1" ? 1 : 0);
			self.fix = parseInt(self.properties[6].value);
			self.markerWidth = parseInt(self.properties[8].value);
			self.markerHeight = parseInt(self.properties[9].value);
			self.markers = [];
			/* markers available */
			self.markerPath = "/DAV/JS/images/markers/";
			self.markerFiles = []; 
			for (var i=1;i<=12;i++) {
				var name = self.prefix + (i<10?"0":"") + i +".png";
				self.markerFiles.push(name);
			}
			self.markerIndex = 0;
			self.markerMapping = {};
			self.map = new OAT.Map(self.elm,self.provider,self.fix,20);
			self.map.centerAndZoom(0,0,self.zoom);
			self.map.addTypeControl();
			self.map.addMapControl();

			switch (self.properties[5].value) {
				case "Map": self.map.setMapType(OAT.MapData.MAP_MAP); break;
				case "Satellite": self.map.setMapType(OAT.MapData.MAP_ORTO); break;
				case "Hybrid": self.map.setMapType(OAT.MapData.MAP_HYB); break;
			}
		}
		
		self.bindRecordCallback = function(dataRow,currentIndex) {
			if (!dataRow) { return; }
			var lat = parseFloat(dataRow[self.datasources[0].realIndexes[0]]);
			var lon	= parseFloat(dataRow[self.datasources[1].realIndexes[0]]);
			var color = (self.datasources[2].columnIndexes[0] == -1 ? 1 : dataRow[self.datasources[2].realIndexes[0]]);
			if (!(color in self.markerMapping)) {
				self.markerMapping[color] = self.markerPath + self.markerFiles[self.markerIndex];
				self.markerIndex++;
				if (self.markerIndex >= self.markerFiles.length) { self.markerIndex = 0; }
			}
			var image = self.markerMapping[color];			
			if (!isNaN(lat) && !isNaN(lon)) {
				var value = [lat,lon,currentIndex,image];
				if (!self.multi) { self.setValue([value]); }
			}
		}
		self.bindPageCallback = function(dataRows,currentPageIndex) {
			var values = [];
			for (var i=0;i<dataRows.length;i++) {
				var lat = parseFloat(dataRows[i][self.datasources[0].realIndexes[0]]);
				var lon	= parseFloat(dataRows[i][self.datasources[1].realIndexes[0]]);
				var color = (self.datasources[2].columnIndexes[0] == -1 ? 1 : dataRows[i][self.datasources[2].realIndexes[0]]);
				var index = currentPageIndex+i;
				if (!(color in self.markerMapping)) {
					self.markerMapping[color] = self.markerPath + self.markerFiles[self.markerIndex];
					self.markerIndex++;
					if (self.markerIndex >= self.markerFiles.length) { self.markerIndex = 0; }
				}
				var image = self.markerMapping[color];			
				if (self.datasources[3].columnIndexes[0] != -1) { /* custom image */
					image = dataRows[i][self.datasources[3].realIndexes[0]];
				}
				if (!isNaN(lat) && !isNaN(lon)) {
					values.push([lat,lon,index,image]);
				}
			}
			if (self.multi) { self.setValue(values); }
		}
		OAT.FormObject.abstractParent(self,x,y);
	},
	
	barchart:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="barchart";
		self.elm = OAT.Dom.create("div");
		self.datasources = [
			{name:"Data rows",variable:true,names:[],columnIndexes:[],realIndexes:[]}
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
			var ds = self.datasources[0];
			for (var i=0;i<ds.realIndexes.length;i++) { textY.push(ds.names[i]); }
			self.chart.attachTextY(textY);
		}
		
		self.bindPageCallback = function(dataRows, currentPageIndex) {
			var value = [];
			var ds = self.datasources[0];
			for (var i=0;i<dataRows.length;i++) {
				var column = [];
				for (var j=0;j<ds.realIndexes.length;j++) {
					column.push(dataRows[i][ds.realIndexes[j]]);
				}
				value.push(column);
			}
			self.setValue(value);
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
			{name:"Data column",variable:false,columnIndexes:[-1],realIndexes:[],names:[]},
			{name:"Paging conditions",variable:true,columnIndexes:[],realIndexes:[],names:[]},
			{name:"Row conditions",variable:true,columnIndexes:[],realIndexes:[],names:[]},
			{name:"Column conditions",variable:true,columnIndexes:[],realIndexes:[],names:[]}
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
			OAT.Dom.attach(pivot_agg,"change",aggRef);
		
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
			for (var i=0;i<self.datasources.length;i++) {
				var ds = self.datasources[i];
				if (ds.name == "Paging conditions") {
					for (var j=0;j<ds.names.length;j++) {
						self.headerRow.push(ds.names[j]);
						self.filterIndexes.push(index);
						index++;
					}
				}
				if (ds.name == "Row conditions") {
					for (var j=0;j<ds.names.length;j++) {
						self.headerRow.push(ds.names[j]);
						self.headerRowIndexes.push(index);
						index++;
					}
				}
				if (ds.name == "Column conditions") {
					for (var j=0;j<ds.names.length;j++) {
						self.headerRow.push(ds.names[j]);
						self.headerColIndexes.push(index);
						index++;
					}
				} 
			} /* for all DSs */

			OAT.Dom.attach(self.content,"scroll",function(event){event.cancelBubble = true;});
			OAT.Dom.attach(self.content,"mousewheel",function(event){event.cancelBubble = true;});
			OAT.Dom.attach(self.content,"DOMMouseScroll",function(event){event.cancelBubble = true;});
			
		} /* init() */

		self.bindPageCallback = function(dataRows, currentPageIndex) {
			var value = [];
			var ds_1 = self.datasources[1];
			var ds_2 = self.datasources[2];
			var ds_3 = self.datasources[3];
			var ds = self.datasources[0];
			for (var i=0;i<dataRows.length;i++) {
				var row = [];
				row.push(dataRows[i][ds.realIndexes[0]]);
				for (var j=0;j<ds_1.realIndexes.length;j++) {
					row.push(dataRows[i][ds_1.realIndexes[j]]);
				}
				for (var j=0;j<ds_2.realIndexes.length;j++) {
					row.push(dataRows[i][ds_2.realIndexes[j]]);
				}
				for (var j=0;j<ds_3.realIndexes.length;j++) {
					row.push(dataRows[i][ds_3.realIndexes[j]]);
				}
				value.push(row);
			}
			self.setValue(value);
		}
		
		OAT.FormObject.abstractParent(self,x,y);
	},
	
	grid:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.showAll = false;
		self.name="grid";
		self.resizable = true;
		self.elm = OAT.Dom.create("div");
		self.datasources = [
			{name:"Columns",variable:true,names:[],columnIndexes:[],realIndexes:[]}
		];
		if (designMode) {
			self.elm.style.width = "200px";
			self.elm.style.height = "200px";
			self.elm.style.backgroundImage = 'url("images/gridbg.gif")';
			self.elm.style.border = '1px solid #000';
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
			OAT.WebClipBindings.bind(self.lc, typeRef, genRef, pasteRef, onRef, outRef);
			self.elm.appendChild(self.lc);
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
			var ds = self.datasources[0];
			self.grid = new OAT.Grid(self.container,true);
			self.grid.reorderNotifier = function(i1,i2) {
				var ds = self.datasources[0];
				var tmp = ds.realIndexes[i1-1];
				var newi = (i1 < i2 ? i2-2 : i2-1);
				ds.realIndexes.splice(i1-1,1);
				ds.realIndexes.splice(newi,0,tmp);
			}
			self.grid.imagesPath = "/DAV/JS/images";
			if (!self.showAll) { 
				var data = [];
				for (var i=0;i<ds.names.length;i++) { 
					var o = {
						value:ds.names[i],
						sortable:1,
						draggable:1,
						resizable:1
					}
					data.push(o); 
				}
				self.grid.createHeader(data); 
			}
			OAT.Dom.attach(self.container,"scroll",function(event){event.cancelBubble = true;});
			OAT.Dom.attach(self.container,"mousewheel",function(event){event.cancelBubble = true;});
			OAT.Dom.attach(self.container,"DOMMouseScroll",function(event){event.cancelBubble = true;});
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
			var ds = self.datasources[0];
			if (self.showAll && dataRows.length) {
				self.datasources[0].realIndexes = [];
				for (var i=0;i<dataRows[0].length;i++) { self.datasources[0].realIndexes.push(i); }
			}
			for (var i=0;i<dataRows.length;i++) {
				var row = [];
				for (var j=0;j<ds.realIndexes.length;j++) {
					row.push(dataRows[i][ds.realIndexes[j]]);
				}
				value.push(row);
			}
			self.grid.rowOffset = currentPageIndex;
			self.setValue(value);
			self.pageIndex = currentPageIndex;
		}
		OAT.FormObject.abstractParent(self,x,y);
	},
	
	image:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="image";
		if (designMode) {
			self.elm = OAT.Dom.create("div",{border:"1px solid #00f",backgroundColor:"#ddf",width:"100px",height:"100px"});
			self.elm.innerHTML = "Image";
		} else {
			self.elm = OAT.Dom.create("img");
		}
		self.datasources = [
			{name:"Source",variable:false,columnIndexes:[-1],names:[],realIndexes:[]}
		];
		self.clear = function() {
			self.elm.src = "";
		}
		self.setValue = function(value) {
			if (OAT.Dom.isIE()) { return; }
			if (value.match(/\./)) {
				/* URL */
				self.elm.src = value;
				return; 
			}
			self.elm.src = OAT.Dom.decodeImage(value);
		}
		self.bindRecordCallback = function(dataRow,currentIndex) {
			if (!dataRow) { return; }
			var value = dataRow[self.datasources[0].realIndexes[0]];
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
			{name:"Small image",variable:false,columnIndexes:[-1],names:[],realIndexes:[]},
			{name:"Large image",variable:false,columnIndexes:[-1],names:[],realIndexes:[]}
		];
		self.clear = function() {
			OAT.Dom.clear(self.tbody);
		}
		self.setValue = function(value) {
			self.clear();
			if (OAT.Dom.isIE()) { return; }
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
			var ds1 = self.datasources[0];
			var ds2 = self.datasources[1];
			for (var i=0;i<dataRows.length;i++) {
				var small = dataRows[i][ds1.realIndexes[0]];
				var large = dataRows[i][ds2.realIndexes[0]];
				value.push([small,large]);
			}
			self.setValue(value);
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
			{name:"Columns",variable:true,names:[],columnIndexes:[],realIndexes:[]}
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
			OAT.Dom.attach(s,"click",sRef);
			OAT.Dom.attach(t,"click",tRef);
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
					self.grid.rowOffset = self.rowOffset;
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
					var ds = self.datasources[0];
					for (var i=0;i<ds.names.length;i++) {
						var lbl = OAT.Dom.create("div",{position:"absolute",left:"3px"});
						lbl.style.top = (4+i*24)+"px";
						lbl.innerHTML = ds.names[i]+":";
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
					for (var i=0;i<ds.names.length;i++) {
						var dims = OAT.Dom.getWH(self.labels[i]);
						self.labels[i].style.left = (2+maxW-dims[0])+"px";
						self.values[i].style.left = (maxW+10)+"px";
					}
				break;
				
				case "Tabular":
					s.style.backgroundColor = notBGcolor;
					t.style.backgroundColor = BGcolor;
					var data = [];
					var ds = self.datasources[0];
					for (var i=0;i<ds.names.length;i++) { 
						var o = {
							value:ds.names[i],
							sortable:1,
							draggable:1,
							resizable:1
						}
						data.push(o); 
					}
					self.grid = new OAT.Grid(self.container,true);
					self.grid.reorderNotifier = function(i1,i2) {
						var ds = self.datasources[0];
						var tmp = ds.realIndexes[i1-1];
						var newi = (i1 < i2 ? i2-2 : i2-1);
						ds.realIndexes.splice(i1-1,1);
						ds.realIndexes.splice(newi,0,tmp);
					}
					self.grid.imagesPath = "/DAV/JS/images";
					self.grid.createHeader(data);
					
					OAT.Dom.attach(self.container,"scroll",function(event){event.cancelBubble = true;});
					OAT.Dom.attach(self.container,"mousewheel",function(event){event.cancelBubble = true;});
					OAT.Dom.attach(self.container,"DOMMouseScroll",function(event){event.cancelBubble = true;});
				break;
			} /* switch */
		} /* FormObject::init() */
		
		self.bindRecordCallback = function(dataRow, currentIndex) {
			self.recordIndex = currentIndex;
			var value = [];
			var ds = self.datasources[0];
			for (var i=0;i<ds.realIndexes.length;i++) {
				value.push(dataRow[ds.realIndexes[i]]);
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
			var ds = self.datasources[0];
			for (var i=0;i<dataRows.length;i++) {
				var row = [];
				for (var j=0;j<ds.realIndexes.length;j++) {
					row.push(dataRows[i][ds.realIndexes[j]]);
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
			{name:"Target",variable:false,columnIndexes:[-1],names:[],realIndexes:[]},
			{name:"Description",variable:false,columnIndexes:[-1],names:[],realIndexes:[]}
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
//				alert(target);
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
			if (self.datasources[0].realIndexes[0] == -1) { return; }
			var value = dataRow[self.datasources[0].realIndexes[0]];
			var label = (self.datasources[1].realIndexes[0] == -1 ? value : dataRow[self.datasources[1].realIndexes[0]]);
			self.setValue(value,label);
		}
		
		OAT.FormObject.abstractParent(self,x,y);
	},
	
	gem:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="gem";
		self.elm = OAT.Dom.create("div");
		
		var apply = function() {
			/* load saved query, add information about stylesheet, save as new saved query */
			var source = self.properties[1].value;
			var ss = self.properties[2].value;
			var target = self.properties[3].value;
			if (source == "") { alert("Please select a saved query to process"); return; }
			if (ss == "") { alert("Please select a stylesheet to create a feed"); return; }
			if (target == "") { alert("Please select a target feed file"); return; }
			
			var processRef = function(query) {
				/* we have saved source query. append a stylesheet and save */
				var q = new OAT.SqlQuery();
				q.fromString(query);
				var result = q.toString(OAT.SqlQueryData.TYPE_SQLX_ELEMENTS);
				var xml = '<?xml version="1.0" encoding="UTF-8"?>\n';
				xml += '<root xmlns:sql="urn:schemas-openlink-com:xml-sql"';
				xml += ' sql:xsl="'+ss+'" ';
				xml += '><sql:sqlx>'+result+'</sql:sqlx></root>';
				var send_ref = function() { return xml; }
				var recv_ref = function() { alert("New saved query created"); }
				OAT.Ajax.command(OAT.Ajax.PUT + OAT.Ajax.AUTH_BASIC,target,send_ref,recv_ref,OAT.Ajax.TYPE_TEXT);
			}
			
			OAT.Ajax.command(OAT.Ajax.GET,source,function(){return "";},processRef,OAT.Ajax.TYPE_TEXT,{});
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
			{name:"Icon",value:"",type:"file",onselect:false,dialog:"open_dialog"},
			{name:"Saved query",value:"",type:"file",onselect:apply,dialog:"open_dialog"},
			{name:"XSLT template",value:"",type:"file",onselect:apply,dialog:"open_dialog"},
			{name:"Resulting file",value:"",type:"file",onselect:apply,dialog:"browser"},
			{name:"Link name",value:"RSS Feed",type:"string"},
			{name:"MIME type",value:"application/rss+xml",type:"string"}
		];
		self.init = function() {
			self.image.src = self.properties[0].value; /* draw proper icon */
			self.link.href = self.properties[3].value; /* will point at this feed */
		}
		OAT.FormObject.abstractParent(self,x,y);
	},

	timeline:function(x,y,designMode) {
		var self = this;
		OAT.FormObject.init(self);
		self.name="timeline";
		self.resizable = true;
		self.elm = OAT.Dom.create("div",{border:"1px solid #00f",backgroundColor:"#ddf",width:"100px",height:"100px",overflow:"hidden"});
		self.datasources = [
			{name:"Time",variable:false,columnIndexes:[-1],names:[],realIndexes:[]},
			{name:"Band",variable:false,columnIndexes:[-1],names:[],realIndexes:[]},
			{name:"Label",variable:false,columnIndexes:[-1],names:[],realIndexes:[]},
			{name:"Link",variable:false,columnIndexes:[-1],names:[],realIndexes:[]}
		];
		self.properties = [
			{name:"Lookup bubble content",type:"form",value:false},
		]
		if (designMode) {
			self.elm.innerHTML = "Timeline";
		} else {
			self.elm.style.backgroundColor = "transparent";
			self.elm.style.border = "none";
		}

		self.openWindow = function(x,y) {
			OAT.Dom.show(self.window.div);
			self.window.div.style.left = x+"px";
			self.window.div.style.top = y+"px";
		}
		
		self.closeWindow = function() {
			OAT.Dom.hide(self.window.div);
		}
		
		self.clickRef = function(index) {
			return function(event) {
				var coords = OAT.Dom.eventPos(event);
				if (self.properties[0].value != -1) {
					self.properties[0].value.oneShotCallback = function() {
						self.openWindow(coords[0],coords[1]+25);
					}
				}
				self.closeWindow();
				self.form.dso.advanceRecord(index);
			}
		}
		
		self.setValue = function(value) { /* time,band,label,link,index */
			self.timeline.clear();
			window.value = value;
			var bands = {};
			for (var i=0;i<value.length;i++) {
				var b = value[i][1];
				bands[b] = 1;
			}

			var index = 0;
			var colors = ["rgb(255,204,153)","rgb(255,255,153)","rgb(153,255,153)",
							"rgb(153,255,255)","rgb(153,204,255)","rgb(204,153,255)","rgb(255,153,204)"];
			
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
				ball.style.backgroundImage = "url(/DAV/JS/images/Timeline_circle.png)";
				if (link == "") {
					var t = OAT.Dom.create("span");
				} else {
					var t = OAT.Dom.create("a");
					t.href = link;
					t.target = "_blank";
				}
				t.innerHTML = label;
				div.appendChild(ball);
				div.appendChild(t);
				var elm = self.timeline.addEvent(band,time,false,div,"#abf");
				OAT.Dom.attach(elm,"click",self.clickRef(index));
			}
			self.timeline.draw();
			self.timeline.slider.slideTo(0,1);
		}
		
		self.getValue = function() { return false; }
		
		self.init = function() {
			self.tlElm = OAT.Dom.create("div",{position:"absolute",width:"100%",left:"0px",top:"0px"});
			self.sliderElm = OAT.Dom.create("div",{position:"absolute",width:"100%",left:"0px",bottom:"0px",height:"20px"});
			var h = OAT.Dom.getWH(self.elm)[1];
			self.tlElm.style.height = (h - 22)+"px"; 
			self.elm.appendChild(self.tlElm);
			self.elm.appendChild(self.sliderElm);
			self.timeline = new OAT.Timeline(self.tlElm,self.sliderElm,{});
			
			self.window = new OAT.Window({close:1,max:0,min:0,width:0,height:0,x:0,y:0,title:"Lookup window",resize:0});
			if (self.properties[0].value != -1) {
				document.body.appendChild(self.window.div);
				self.window.content.appendChild(self.properties[0].value.div);
				self.window.onclose = self.closeWindow;
				self.closeWindow(); 
			}
		}
		
		self.bindPageCallback = function(dataRows,currentPageIndex) {
			var values = [];
			for (var i=0;i<dataRows.length;i++) {
				var time = dataRows[i][self.datasources[0].realIndexes[0]];
				var index = self.datasources[1].realIndexes[0];
				var band = (index == -1 ? "Data" : dataRows[i][index]);
				var label = dataRows[i][self.datasources[2].realIndexes[0]];
				var index = self.datasources[3].realIndexes[0];
				var link = (index == -1 ? "" : dataRows[i][index]);
				var index = currentPageIndex+i;
				values.push([time,band,label,link,index]);
			}
			self.setValue(values);
		}
		
		OAT.FormObject.abstractParent(self,x,y);
	} /* timeline */
	
}
OAT.Loader.pendingCount--;
