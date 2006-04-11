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
	new Tab(element)
	Tab.add(clicker,window)
	Tab.go(index)
	
	CSS: .tab, .tab_selected
*/

function Tab(elm) {
	this.keys = [];
	this.values = [];
	this.element = $(elm);
	this.selectedIndex = -1;
	
	this.add = function(elm_1,elm_2) {
		var element_1 = $(elm_1);
		var element_2 = $(elm_2);
		element_1.className = "tab";
		var index = this.keys.length;
		
		this.keys[index] = element_1;
		this.values[index] = element_2;
		var obj = this;
		var ref=function() {
			obj.go(index);
		}
		Dom.attach(element_1,"click",ref);
		this.go(index);
	};

	this.clear = function() {
		if (this.selectedIndex != -1) {
			document.body.appendChild(this.values[this.selectedIndex]);
			this.values[this.selectedIndex].style.display = "none";
			this.keys[this.selectedIndex].className = "tab";
		}
	};

	this.go = function(index) {
		this.clear();
		this.selectedIndex = index;
		this.element.appendChild(this.values[index]);
		this.values[index].style.display = "block";
		this.keys[index].className = "tab tab_selected";
		this.keys[index].origClassName = "tab tab_selected";
	};
	
	Dom.clear(this.element); 
}
