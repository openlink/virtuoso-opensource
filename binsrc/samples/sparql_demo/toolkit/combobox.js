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
	var cb = new OAT.ComboBox(defaultValue);
	appendChild(cb.div);
	cb.onchange = callback;
	
	cb.addOption(element,textValue)
	
	CSS: combo_box, combo_box_value, combo_box_list, combo_image
*/

OAT.ComboBox = function(defaultValue) {
	var obj = this;
	this.onchange = function() {};
	this.div = OAT.Dom.create("div"); /* THE element */
	this.options = [];
	this.optList = OAT.Dom.create("div",{position:"absolute",left:"0px",top:"0px"}); /* list of other options; hidden most of the time */
	this.optList.className = "combo_box_list";
	this.image = OAT.Dom.create("img"); /* dropdown clicker */
	this.image.className = "combo_image";
	this.image.setAttribute("src","images/Combobox_select.gif");
	this.selected = OAT.Dom.create("div");
	this.selected.className = "combo_box_value";
	this.value = defaultValue;
	this.selected.innerHTML = this.value;
	
	OAT.Instant.assign(this.optList);
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
		var coords = OAT.Dom.position(obj.div); /* calculate the place */
		obj.optList.style.left = coords[0]+"px";
		obj.optList.style.top = (coords[1]+obj.div.offsetHeight)+"px";
		obj.optList._Instant_show(); /* show listbox */
	}
	
	this.addOption = function(element,textValue) {
		var elm = $(element);
		this.options.push([elm,textValue]);
		this.optList.appendChild(elm);
		var clickRef = function() {	obj.select(textValue); }
		OAT.Dom.attach(elm,"click",clickRef); /* what to do after clicking */
	}
	
	OAT.Dom.attach(this.image,"click",obj.open);
	OAT.Dom.attach(this.selected,"click",obj.open);
}
OAT.Loader.pendingCount--;
