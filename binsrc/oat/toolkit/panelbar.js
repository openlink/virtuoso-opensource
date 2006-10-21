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
	var pb = new OAT.Panelbar(div,fadeDelay) ( 0 == no fade )
	pb.addPanel(clickerDiv,contentDiv)
	pb.go(0);
	
	CSS: .panelbar, .panelbar_option, .panelbar_option_selected, .panelbar_option_upper, .panelbar_option_lower, .panelbar_content
*/

OAT.Panelbar = function(div,delay) {
	var obj = this;
	this.div = $(div);
	OAT.Dom.addClass(this.div,"panelbar");
	this.selectedIndex = -1;
	this.panels = [];
	this.delay = delay;
	
	this.go = function(index) {
		for (var i=0;i<obj.panels.length;i++) {
			obj.panels[i][0].className = "panelbar_option "+(i <= index ? "panelbar_option_upper" : "panelbar_option_lower");
			OAT.Dom.hide(obj.panels[i][1]);
			if (obj.delay) {
				obj.panels[i][1].style.opacity = 0;
				obj.panels[i][1].style.filter = "alpha(opacity=0)";
			}
		}
		obj.panels[index][0].className += " panelbar_option_selected";
		OAT.Dom.show(obj.panels[index][1]);
		if (obj.delay) {
			var as = OAT.AnimationStructure.generate(obj.panels[index][1],OAT.AnimationData.FADEIN,{});
			var a = new OAT.Animation(as,obj.delay);
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
		OAT.Dom.attach(clicker_elm,"click",callback);
		this.panels.push([clicker_elm,content_elm]);
		this.div.appendChild(clicker_elm);
		this.div.appendChild(content_elm);
		this.go(this.panels.length-1);
	}
	
	
}
OAT.Loader.pendingCount--;
