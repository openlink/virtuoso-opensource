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
	var pb = new Panelbar(fadeDelay) ( 0 == no fade )
	document.body.appendChild(pb.div);
	
	pb.addPanel(clickerDiv,contentDiv)
	pb.go(0);
	
	CSS: .panelbar, .panelbar_option, .panelbar_option_selected, .panelbar_option_upper, .panelbar_option_lower, .panelbar_content
*/

function Panelbar(delay) {
	var obj = this;
	this.div = Dom.create("div");
	this.div.className = "panelbar";
	this.selectedIndex = -1;
	this.panels = [];
	this.delay = delay;
	
	this.go = function(index) {
		for (var i=0;i<obj.panels.length;i++) {
			obj.panels[i][0].className = "panelbar_option "+(i <= index ? "panelbar_option_upper" : "panelbar_option_lower");
			obj.panels[i][1].style.display = "none";
			if (obj.delay) {
				obj.panels[i][1].style.opacity = 0;
				obj.panels[i][1].style.filter = "alpha(opacity=0)";
			}
		}
		obj.panels[index][0].className += " panelbar_option_selected";
		obj.panels[index][1].style.display = "block";
		if (obj.delay) {
			var as = AnimationStructure.generate(obj.panels[index][1],AnimationData.FADEIN,{});
			var a = new Animation(as,obj.delay);
			a.start();
		}
		obj.selectedIndex = index;
	}
	
	this.addPanel = function(clickerDiv,contentDiv) {
		var clicker_elm = $(clickerDiv);
		var content_elm = $(contentDiv);
		clicker_elm.className = "panelbar_option";
		content_elm.className = "panelbar_content";
		var callback = function(event) {
			var index = -1;
			for (var i=0;i<obj.panels.length;i++) if (obj.panels[i][0] == clicker_elm) { index = i; }
			if (index == obj.selectedIndex) { return; }
			obj.go(index);
		}
		Dom.attach(clicker_elm,"click",callback);
		this.panels.push([clicker_elm,content_elm]);
		this.div.appendChild(clicker_elm);
		this.div.appendChild(content_elm);
		this.go(this.panels.length-1);
	}
	
	
}
