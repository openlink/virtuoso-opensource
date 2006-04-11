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
	var cb = new ComboButton();
	appendChild(cb.div);
	cb.addOption(imagepath,textvalue,callback)
	cb.removeOption(index)
	
	CSS: combo_button, combo_image, combo_button_text, combo_button_option, combo_button_option_down
*/

function ComboButton() {
	var obj = this;
	this.div = Dom.create("div"); /* THE element */
	this.options = [];
	this.optList = Dom.create("div",{position:"absolute",left:"0px",top:"0px"}); /* list of other options; hidden most of the time */
	this.image = Dom.create("img"); /* dropdown clicker */
	this.image.className = "combo_image";
	this.image.setAttribute("src","images/Combobutton_select.gif");
	this.selected = Dom.create("div",{cssFloat:"left",styleFloat:"left"}); /* currently selected option */
	
	Instant.assign(this.optList);
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
		var coords = Dom.position(obj.div); /* calculate the place */
		obj.optList.style.left = coords[0]+"px";
		obj.optList.style.top = (coords[1]+obj.div.offsetHeight)+"px";
		obj.optList._Instant_show(); /* show listbox */
	}
	
	this.addOption = function(imagepath,textvalue,callback) {
		var opt = Dom.create("div");
		opt.className = "combo_button_option";
		Dom.attach(opt,"mousedown",function(){opt.className += " combo_button_option_down";});
		Dom.attach(opt,"mouseup",function(){opt.className = "combo_button_option";});
		if (imagepath != "") { /* if image specified, add it to option */
			var img = Dom.create("img",{cssFloat:"left",styleFloat:"left"});
			img.setAttribute("src",imagepath);
			opt.appendChild(img);
		}
		var text = Dom.create("div"); /* text */
		text.className = "combo_button_text";
		text.innerHTML = textvalue;
		opt.appendChild(text);
		this.options.push([opt,callback]); /* put to global registry */
		this.optList.appendChild(opt);
		var index = this.options.length - 1;
		var clickRef = function() {	obj.select(index,true); }
		Dom.attach(opt,"click",clickRef); /* what to do after clicking */
		if (this.options.length == 1) { this.select(0,false); } /* first option is automatically selected */
	}
	
	this.removeOption = function(index) {
		if (index > this.options.length-1) { return; }
		var was_active = false;
		if (this.options[index][0] == this.selected.firstChild) { was_active = true; } /* what if we removed the active option? */
		Dom.unlink(this.options[index][0]);
		this.options.splice(index,1);
		if (was_active && this.options.length) { this.select(0,false); } /* then select the first available */
	}
	Dom.attach(this.image,"click",obj.open);
}
