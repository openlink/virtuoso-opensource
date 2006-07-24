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
	var cl = new OAT.Combolist(optList,value)
	cl.onchange = callback;
	appendChild(cl.div)
	
	cl.clearOpts()
	cl.addOption(text)
	
	CSS: combo_list, combo_list_input, combo_list_option, combo_list_list
*/

OAT.Combolist = function(optList,value) {
	var obj = this;
	this.value = value;
	this.div = OAT.Dom.create("div");
	this.div.className = "combo_list";
	this.onchange = function() {};
	
	this.img = OAT.Dom.create("img");
	this.img.src="images/Combolist_select.gif";
	this.input = OAT.Dom.create("input");
	this.input.setAttribute("type","text");
	this.input.value = value;
	this.input.className = "combo_list_input";
	
	this.list = OAT.Dom.create("div",{position:"absolute",left:"0px",top:"0px",zIndex:200});
	this.list.className = "combo_list_list";
	OAT.Dom.attach(this.input,"keyup",function(){obj.value = obj.input.value; obj.onchange();});
	OAT.Instant.assign(this.list);
	
	this.clearOpts = function() {
		OAT.Dom.clear(this.list);
	}
	
	this.addOption = function(option) {
		var t = option;
		var v = option;
		if (typeof(option) == "object") { 
			t = option[0];
			v = option[1];
		}
		var opt = OAT.Dom.create("div");
		opt.className = "combo_list_option";
		opt.innerHTML = t;
		opt.value = v;
		attach(opt);
		this.list.appendChild(opt);
	}

	var attach = function(option) {
		var ref = function(event) {
			obj.value = option.value;
			obj.input.value = option.innerHTML;
			obj.onchange(obj.value);
			obj.list._Instant_hide();
		}
		OAT.Dom.attach(option,"click",ref);
	}
	
	for (var i=0;i<optList.length;i++) {
		this.addOption(optList[i]);
	}
	
	this.div.appendChild(this.input);
	this.div.appendChild(this.img);
	document.body.appendChild(this.list);
	
	var showRef = function(event) {
		var coords = OAT.Dom.position(obj.input);
		obj.list.style.left = (coords[0]) +"px";
		obj.list.style.top = (coords[1]+obj.input.offsetHeight)+"px";
		obj.list._Instant_show();
	}
	OAT.Dom.attach(this.img,"click",showRef);
}
OAT.Loader.pendingCount--;
