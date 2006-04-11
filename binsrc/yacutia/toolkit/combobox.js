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
	var cb = new ComboBox(defaultValue);
	appendChild(cb.div);
	cb.onchange = callback;
	
	cb.addOption(element,textValue)
	
	CSS: combo_box, combo_box_value, combo_box_list, combo_image
*/

function ComboBox(defaultValue) {
	var obj = this;
	this.onchange = function() {};
	this.div = Dom.create("div"); /* THE element */
	this.options = [];
	this.optList = Dom.create("div",{position:"absolute",left:"0px",top:"0px"}); /* list of other options; hidden most of the time */
	this.optList.className = "combo_box_list";
	this.image = Dom.create("img"); /* dropdown clicker */
	this.image.className = "combo_image";
	this.image.setAttribute("src","images/Combobox_select.gif");
	this.selected = Dom.create("div");
	this.selected.className = "combo_box_value";
	this.value = defaultValue;
	this.selected.innerHTML = this.value;
	
	Instant.assign(this.optList);
	this.div.className = "combo_box";
	this.div.appendChild(this.selected);
	this.div.appendChild(this.image);
	document.body.appendChild(obj.optList);
	
	this.select = function(textValue) {
		this.value = textValue;
		this.selected.innerHTML = textValue;
		this.onchange();
		this.optList._Instant_hide(); 
	}
	
	this.open = function() { /* open listbox */
		var coords = Dom.position(obj.div); /* calculate the place */
		obj.optList.style.left = coords[0]+"px";
		obj.optList.style.top = (coords[1]+obj.div.offsetHeight)+"px";
		obj.optList._Instant_show(); /* show listbox */
	}
	
	this.addOption = function(element,textValue) {
		var elm = $(element);
		this.options.push([elm,textValue]);
		this.optList.appendChild(elm);
		var clickRef = function() {	obj.select(textValue); }
		Dom.attach(elm,"click",clickRef); /* what to do after clicking */
	}
	
	Dom.attach(this.image,"click",obj.open);
	Dom.attach(this.selected,"click",obj.open);
}
