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
	var cl = new Combolist(optList,value)
	cl.onchange = callback;
	appendChild(cl.div)
	
	cl.clearOpts()
	cl.addOption(text)
	
	CSS: combo_list, combo_list_input, combo_list_option, combo_list_list
*/

function Combolist(optList,value) {
	var obj = this;
	this.value = value;
	this.div = Dom.create("div");
	this.div.className = "combo_list";
	this.onchange = function() {};
	
	this.img = Dom.create("img");
	this.img.src="images/Combolist_select.gif";
	this.input = Dom.create("input");
	this.input.setAttribute("type","text");
	this.input.value = value;
	this.input.className = "combo_list_input";
	
	this.list = Dom.create("div",{position:"absolute",left:"0px",top:"0px"});
	this.list.className = "combo_list_list";
	Dom.attach(this.input,"keyup",function(){obj.value = obj.input.value; obj.onchange();});
	Instant.assign(this.list);
	
	this.clearOpts = function() {
		Dom.clear(this.list);
	}
	
	this.addOption = function(option) {
		var opt = Dom.create("div");
		opt.className = "combo_list_option";
		opt.innerHTML = option;
		attach(opt);
		this.list.appendChild(opt);
	}

	var attach = function(option) {
		var ref = function(event) {
			obj.value = option.innerHTML;
			obj.input.value = option.innerHTML;
			obj.onchange();
			obj.list._Instant_hide();
		}
		Dom.attach(option,"click",ref);
	}
	
	for (var i=0;i<optList.length;i++) {
		this.addOption(optList[i]);
	}
	
	this.div.appendChild(this.input);
	this.div.appendChild(this.img);
	document.body.appendChild(this.list);
	
	var showRef = function(event) {
		var coords = Dom.position(obj.input);
		obj.list.style.left = (coords[0]) +"px";
		obj.list.style.top = (coords[1]+obj.input.offsetHeight)+"px";
		obj.list._Instant_show();
	}
	Dom.attach(this.img,"click",showRef);
}
