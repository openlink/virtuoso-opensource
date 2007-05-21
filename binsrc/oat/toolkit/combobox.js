/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2007 OpenLink Software
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
	var self = this;
	this.onchange = function() {};
	this.div = OAT.Dom.create("div",{},"combo_box"); /* THE element */
	this.options = [];
	this.optList = OAT.Dom.create("div",{position:"absolute",left:"0px",top:"0px"},"combo_box_list"); /* list of other options; hidden most of the time */
	this.image = OAT.Dom.create("img",{},"combo_image"); /* dropdown clicker */
	this.image.src = OAT.Preferences.imagePath+"Combobox_select.gif";
	this.selected = OAT.Dom.create("div",{},"combo_box_value");
	this.value = defaultValue;
	this.selected.innerHTML = this.value;
	
	OAT.Instant.assign(this.optList);
	OAT.Dom.append([this.div,this.selected,this.image],[document.body,self.optList]);
	
	this.select = function(textValue) {
		this.value = textValue;
		this.selected.innerHTML = textValue;
		this.onchange(textValue);
		this.optList._Instant_hide(); 
	}
	
	this.open = function() { /* open listbox */
		var coords = OAT.Dom.position(self.div); /* calculate the place */
		var dims = OAT.Dom.getWH(self.div); /* calculate the place */
		self.optList.style.left = coords[0]+"px";
		self.optList.style.top = (coords[1]+dims[1])+"px";
		self.optList._Instant_show(); /* show listbox */
	}
	
	this.addOption = function(element,textValue) {
		var elm = $(element);
		self.options.push([elm,textValue]);
		self.optList.appendChild(elm);
		var clickRef = function() {	self.select(textValue); }
		OAT.Dom.attach(elm,"click",clickRef); /* what to do after clicking */
	}
	
	OAT.Dom.attach(this.image,"click",self.open);
	OAT.Dom.attach(this.selected,"click",self.open);
}
OAT.Loader.featureLoaded("combobox");
