/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
 *  
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *  
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *  
 *  
*/
/*
	new FormObject(name, x, y, designMode)
	-- appearance --
	FormObject::select()
	FormObject::deselect()
	-- data --
	FormObject::getValue() - useful only in design when externalSet is true
	FormObject::setValue() - value or array, if array, then named values go first. if multiData, then last value == pointer index
	FormObject::start() - initialization, when all data are bound
	FormObject::loadXML()
*/

/*
	key properties in every object:

	object.form - link to form
	object.elm - DOM node
	object.externalSet - whether user may change it's value
	object.multiData - whether objects accepts one value per DS, or an array
	object.namedDS - object, name:index
	object.unnamedDS - array of two-element arrays
	object.properties - object, name:index
*/

var FormObject = function(name,x,y,designMode) {
	this.init = function(name) {
		switch (name) {
			case "label":
				this.elm = Dom.create("div");
				this.externalSet = true; 
				this.multiData = false;
				this.namedDS = {"Value":-1};
				this.unnamedDS = false;
				this.properties = false;

				this.setValue = function(value) {
					this.elm.innerHTML = value;
				}
				this.getValue = function() {
					return this.elm.innerHTML;
				}
				this.start = function() {}
			break;
			
			case "input":
				this.elm = Dom.create("input");
				this.elm.setAttribute("type","text");
				this.externalSet = true; 
				this.multiData = false;
				this.namedDS = {"Value":-1};
				this.unnamedDS = false;
				this.properties = false;
				this.setValue = function(value) {
					this.elm.value = value;
				}
				this.getValue = function() {
					return this.elm.value;
				}
				this.start = function() {}
			break;
			
			case "checkbox":
				this.elm = Dom.create("input");
				this.elm.setAttribute("type","checkbox");
				this.externalSet = false; 
				this.multiData = false;
				this.namedDS = {"Checked":-1};
				this.unnamedDS = false;
				this.properties = false;
				this.setValue = function(value) {
					var x = value.toString();
					if (x.toUpperCase() == "TRUE") { x = 1; }
					var x = parseInt(x);
					this.elm.checked = (x ? true : false);
				}
				this.getValue = function() { return false; }
				this.start = function() {}
			break;
			
			case "line":
				this.elm = Dom.create("hr");
				this.elm.style.width = "200px";
				this.externalSet = false; 
				this.multiData = false;
				this.namedDS = false;
				this.unnamedDS = false;
				this.properties = false;
				this.setValue = function(value) {}
				this.getValue = function() { return false; }
				this.start = function() {}
			break;
			
			case "map":
				this.elm = Dom.create("div",{border:"1px solid #00f",backgroundColor:"#ddf",width:"100px",height:"100px"});
				this.externalSet = false;
				this.multiData = false;
				this.namedDS = {"Latitude":-1,"Longitude":-1};
				this.unnamedDS = [];
//				this.properties = {"Key":""};
				this.properties = false;
				this.setValue = function(value) {
					/* call for map */
					var lat = parseFloat(value[0]);
					var lon = parseFloat(value[1]);
					var point = new GPoint(lat,lon);
					var marker = new GMarker(point);
					this.map.centerAndZoom(point,4); 
					this.map.addOverlay(marker);
					var html = "";
					for (var i=2;i<value.length;i++) {
						html += value[i]+"<br/>";
					}
					GEvent.addListener(marker, 'click', function() {marker.openInfoWindowHtml(html);});
				}
				this.getValue = function() { return false; }
				this.start = function() {
					if (GBrowserIsCompatible()) {
						this.map = new GMap(this.elm);
						this.map.centerAndZoom(new GPoint(-122.1419, 37.4419), 4);
						this.map.addControl(new GSmallMapControl());
						this.map.addControl(new GMapTypeControl());
					}
				}
			break;
			
			case "grid":
				this.elm = Dom.create("div");
				this.externalSet = false;
				this.multiData = true;
				this.namedDS = false;
				this.unnamedDS = [];
				this.properties = false;
				if (designMode) {
					this.elm.style.width = "200px";
					this.elm.style.height = "200px";
					this.elm.style.backgroundImage = 'url("images/gridbg.gif")';
					this.elm.style.backgroundColor = '#ccc';
					this.elm.style.border = '1px solid #000';
				}
				this.setValue = function(arr) {
					this.grid.clearData();
					if (arr.length == 1) { return; }
					for (var i=0;i<arr[0].length;i++) {
						var data = [];
						for (var j=0;j<arr.length-1;j++) {
							data.push(arr[j][i]);
						}
						this.grid.createRow(data);
					}
				}
				this.getValue = function() { return false; }
				this.start = function() {
					var data = [];
					for (var i=0;i<this.unnamedDS.length;i++) { 
						var o = {
							value:this.unnamedDS[i][0],
							sortable:0,
							draggable:0,
							resizable:1
						}
						data.push(o); 
					}
					this.elm.style.overflow = "auto";
					this.grid = new Grid(this.elm,true);
					this.grid.imagesPath = "/DAV/VAD/JS/images";
					this.grid.createHeader(data);
				}
			break;
		}
	} /* init */
	
	this.loadXML = function(node) {
		var tmp;
		/* css */
		tmp = node.getElementsByTagName("style")[0];
		this.elm.style.color = tmp.getAttribute("fgcolor");
		this.elm.style.backgroundColor = tmp.getAttribute("bgcolor");
		this.elm.style.fontSize = tmp.getAttribute("size");
		this.elm.style.left = tmp.getAttribute("left")+"px";
		this.elm.style.top = tmp.getAttribute("top")+"px";
		this.elm.style.width = tmp.getAttribute("width")+"px";
		this.elm.style.height = tmp.getAttribute("height")+"px";
		/* properties */
		tmp = node.getElementsByTagName("properties")[0];
		for (var i=0;i<tmp.childNodes.length;i++) {
			this.properties[tmp.childNodes[i].nodeName] = Xml.textValue(tmp.childNodes[i]);
		}
		/* named DS */
		tmp = node.getElementsByTagName("namedds")[0];
		for (var i=0;i<tmp.childNodes.length;i++) {
			this.namedDS[tmp.childNodes[i].nodeName] = Xml.textValue(tmp.childNodes[i]);
		}
		/* unnamed DS */
		tmp = node.getElementsByTagName("pair");
		for (var i=0;i<tmp.length;i++) {
			var name = tmp[i].getElementsByTagName("name")[0];
			var value = tmp[i].getElementsByTagName("value")[0];
			this.unnamedDS.push([Xml.textValue(name),Xml.textValue(value)]);
		}
		
	}	
	
	this.actualizeResizers = function() {
		if (!this.resizeXY) { return; }
		var w = this.elm.offsetWidth;
		var h = this.elm.offsetHeight;
		var x = this.elm.offsetLeft;
		var y = this.elm.offsetTop;

		this.resizeX.style.left = (x+w-4)+"px";
		this.resizeX.style.top = Math.round(y+(h/2)-4)+"px";

		this.resizeY.style.left = Math.round(x+(w/2)-4)+"px";
		this.resizeY.style.top = (y+h-4)+"px";

		this.resizeXY.style.left = (x+w-4)+"px";
		this.resizeXY.style.top = (y+h-4)+"px";
	}
	
	this.select = function() {
		if (this.selected) { return; }
		this.selected = 1;
		this.elm.oldBorder = this.elm.style.border; /* red border */
		this.elm.style.border = "2px solid #f00";
		/* resizor: */
		this.resizeX = Dom.create("div",{position:"absolute",width:"6px",height:"6px",backgroundColor:"#f00",border:"1px solid #000",overflow:"hidden"});
		this.resizeY = Dom.create("div",{position:"absolute",width:"6px",height:"6px",backgroundColor:"#f00",border:"1px solid #000",overflow:"hidden"});
		this.resizeXY = Dom.create("div",{position:"absolute",width:"6px",height:"6px",backgroundColor:"#f00",border:"1px solid #000",overflow:"hidden"});
		
		this.actualizeResizers();

		var parent = this.elm.parentNode;
		parent.appendChild(this.resizeX);
		parent.appendChild(this.resizeY);
		parent.appendChild(this.resizeXY); 
		
		Resize.create(this.resizeX,this.elm,Resize.TYPE_X);
		Resize.create(this.resizeY,this.elm,Resize.TYPE_Y);
		Resize.create(this.resizeXY,this.elm,Resize.TYPE_XY);
		
		var cancelFunc = function(event) { event.cancelBubble = true; }
		Dom.attach(this.resizeX,"mousedown",cancelFunc);
		Dom.attach(this.resizeY,"mousedown",cancelFunc);
		Dom.attach(this.resizeXY,"mousedown",cancelFunc);
	} /* FormObject::select() */

	this.deselect = function() {
		if (!this.selected) { return; }
		this.selected = 0;
		this.elm.style.border = this.elm.oldBorder;
		Dom.unlink(this.resizeX);
		Dom.unlink(this.resizeY);
		Dom.unlink(this.resizeXY);
		this.resizeX = false;
		this.resizeY = false;
		this.resizeXY = false;
	}
	
	this.toXML = function() {
		var xml = "";
		var e = self.elm;
		var x = e.offsetLeft;
		var y = e.offsetTop;
		var w = e.offsetWidth;
		var h = e.offsetHeight;
		var bg = Dom.style(e,"backgroundColor");
		var fg = Dom.style(e,"color");
		var size = Dom.style(e,"fontSize");
		/* element */
		xml += '<object type="'+self.name+'" '+
				'value="'+self.getValue()+'">\n';
		/* style */
		xml += '\t\t\t<style left="'+x+'" top="'+y+'" width="'+w+'" height="'+h+'" '+
				'bgcolor="'+bg+'" fgcolor="'+fg+'" size="'+size+'"></style>\n';
		/* properties */
		xml += '\t\t\t<properties>\n';
		for (p in self.properties) {
			xml += '\t\t\t\t<'+p+'>'+self.properties[p]+'</'+p+'>\n';
		}
		xml += '\t\t\t</properties>\n';
		/* named ds */
		xml += '\t\t\t<namedds>\n';
		for (p in self.namedDS) {
			xml += '\t\t\t\t<'+p+'>'+self.namedDS[p]+'</'+p+'>\n';
		}
		xml += '\t\t\t</namedds>\n';
		/* unnamed ds */
		xml += '\t\t\t<unnamedds>\n';
		if (self.unnamedDS) {
			for (var i=0;i<self.unnamedDS.length;i++) {
				xml += '\t\t\t\t<pair>\n';
				xml += '\t\t\t\t\t<name>'+self.unnamedDS[i][0]+'</name>\n';
				xml += '\t\t\t\t\t<value>'+self.unnamedDS[i][1]+'</value>\n';
				xml += '\t\t\t\t</pair>\n';
			}
		}
		xml += '</unnamedds>\n';
		xml += '\t\t</object>\n';

		return xml;
	}
	 
	this.name = name;
	this.init(this.name);
	this.selected = 0;
	this.elm.style.position = "absolute";
	this.elm.style.left = x+"px";
	this.elm.style.top = y+"px";
	var self = this;
	var actFunc = function(event) { self.actualizeResizers(); }
	Dom.attach(document.body,"mousemove",actFunc);
}
