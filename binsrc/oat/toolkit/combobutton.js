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
	var cb = new OAT.ComboButton();
	appendChild(cb.div);
	cb.addOption(imagepath,textvalue,callback)
	cb.removeOption(index)
	
	CSS: combo_button, combo_button_image, combo_button_text, combo_button_option, combo_button_option_down
*/

OAT.ComboButton = function() {
	var obj = this;
	this.div = OAT.Dom.create("div"); /* THE element */
	this.options = [];
	this.optList = OAT.Dom.create("div",{position:"absolute",left:"0px",top:"0px"}); /* list of other options; hidden most of the time */
	this.image = OAT.Dom.create("img"); /* dropdown clicker */
	this.image.className = "combo_button_image";
	this.image.setAttribute("src","images/Combobutton_select.gif");
	this.selected = OAT.Dom.create("div",{cssFloat:"left",styleFloat:"left"}); /* currently selected option */
	
	OAT.Instant.assign(this.optList);
	this.div.className = "combo_button";
	this.div.appendChild(this.selected);
	this.div.appendChild(this.image);
	document.body.appendChild(obj.optList);
	
	this.select = function(index,do_callback) { /* select one option, call for action */
		if (this.selected.firstChild) { this.optList.appendChild(this.selected.firstChild); } /* remove old option, if any */
		this.selected.appendChild(this.options[index][0]); /* append one from listbox */
		if (this.optList.parentNode) { this.optList._Instant_hide(); } /* hide listbox */
		if (do_callback) { this.options[index][1](); } /* if not selected automatically, action */
	}
	
	this.open = function() { /* open listbox */
		var coords = OAT.Dom.position(obj.div); /* calculate the place */
		obj.optList.style.left = coords[0]+"px";
		obj.optList.style.top = (coords[1]+obj.div.offsetHeight)+"px";
		obj.optList._Instant_show(); /* show listbox */
	}
	
	this.addOption = function(imagepath,textvalue,callback) {
		var opt = OAT.Dom.create("div");
		opt.className = "combo_button_option";
		OAT.Dom.attach(opt,"mousedown",function(){opt.className += " combo_button_option_down";});
		OAT.Dom.attach(opt,"mouseup",function(){opt.className = "combo_button_option";});
		if (imagepath != "") { /* if image specified, add it to option */
			var img = OAT.Dom.create("img",{cssFloat:"left",styleFloat:"left"});
			img.setAttribute("src",imagepath);
			opt.appendChild(img);
		}
		var text = OAT.Dom.create("div"); /* text */
		text.className = "combo_button_text";
		text.innerHTML = textvalue;
		opt.appendChild(text);
		this.options.push([opt,callback]); /* put to global registry */
		this.optList.appendChild(opt);
		var index = this.options.length - 1;
		var clickRef = function() {	obj.select(index,true); }
		OAT.Dom.attach(opt,"click",clickRef); /* what to do after clicking */
		if (this.options.length == 1) { this.select(0,false); } /* first option is automatically selected */
	}
	
	this.removeOption = function(index) {
		if (index > this.options.length-1) { return; }
		var was_active = false;
		if (this.options[index][0] == this.selected.firstChild) { was_active = true; } /* what if we removed the active option? */
		OAT.Dom.unlink(this.options[index][0]);
		this.options.splice(index,1);
		if (was_active && this.options.length) { this.select(0,false); } /* then select the first available */
	}
	OAT.Dom.attach(this.image,"click",obj.open);
}
OAT.Loader.featureLoaded("combobutton");
