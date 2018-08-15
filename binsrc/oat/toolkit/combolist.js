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
	var cl = new OAT.Combolist(optList,value)
	appendChild(cl.div)

	cl.clearOpts()
	cl.addOption(name, value)

	CSS: combo_list, combo_list_input, combo_list_option, combo_list_list
*/

OAT.Combolist = function(optList,value,optObj) {
	var self = this;

	this.options = {
		name:"combo_list", /* name of input element */
		imagePath:OAT.Preferences.imagePath,
		onchange:function() {}
	}

	for (var p in optObj) { self.options[p] = optObj[p]; }

	this.value = value || "";
	this.div = OAT.Dom.create("div",{},"combo_list");

	this.img = OAT.Dom.create("img",{cursor:"pointer"});
	this.img.src = self.options.imagePath + "Combolist_select.gif";
	this.input = OAT.Dom.create("input",{},"combo_list_input");
	this.input.type = "text";
	this.input.name = self.options.name;
	this.input.value = self.value;
	this.input.defaultValue = self.value;

	this.list = OAT.Dom.create("div",{position:"absolute",left:"0px",top:"0px",zIndex:1001},"combo_list_list");
	OAT.Event.attach(this.input,"keyup",function(){
		self.value = self.input.value;
		self.options.onchange(self);
	});
	self.instant = new OAT.Instant(self.list);

	this.clearOpts = function() {
		OAT.Dom.clear(self.list);
	}

	this.addOption = function(name, value) {
		var n = name;
		var v = name;
		if (value) { v = value; }
		var opt = OAT.Dom.create("div",{},"combo_list_option");
		opt.innerHTML = n;
		opt.value = v;
		attach(opt);
		self.list.appendChild(opt);
	}

	var attach = function(option) {
		var ref = function(event) {
			self.value = option.value;
			self.input.value = option.value;
			self.options.onchange(self);
			self.instant.hide();
		}
		OAT.Event.attach(option,"click",ref);
	}

	if (optList) {
		for (var i=0;i<optList.length;i++) {
			this.addOption(optList[i]);
		}
	}

	OAT.Dom.append([self.div,self.input,self.img],[document.body,self.list]);

	self.instant.options.showCallback = function() {
		var coords = OAT.Dom.position(self.input);
		var dims = OAT.Dom.getWH(self.input);
		self.list.style.left = (coords[0]+2) +"px";
		self.list.style.top = (coords[1]+dims[1]+5)+"px";
	}
	self.instant.createHandle(self.img);
}
