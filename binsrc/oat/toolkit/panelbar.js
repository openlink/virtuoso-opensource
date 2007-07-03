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
	var pb = new OAT.Panelbar(div,fadeDelay) ( 0 == no fade )
	pb.addPanel(clickerDiv,contentDiv)
	pb.go(0);
	
	CSS: .panelbar, .panelbar_option, .panelbar_option_selected, .panelbar_option_upper, .panelbar_option_lower, .panelbar_content
*/

OAT.Panelbar = function(div,delay) {
	var self = this;
	this.div = $(div);
	OAT.Dom.addClass(self.div,"panelbar");
	this.selectedIndex = -1;
	this.panels = [];
	this.delay = delay;
	
	this.go = function(index) {
		for (var i=0;i<self.panels.length;i++) {
			OAT.Dom.removeClass(self.panels[i][0],"panelbar_option_selected");
			OAT.Dom.removeClass(self.panels[i][0],"panelbar_option_upper");
			OAT.Dom.removeClass(self.panels[i][0],"panelbar_option_lower");
			OAT.Dom.addClass(self.panels[i][0],(i <= index ? "panelbar_option_upper" : "panelbar_option_lower"));
			OAT.Dom.hide(self.panels[i][1]);
			if (self.delay) { OAT.Style.opacity(self.panels[i][1],0); }
		}
		OAT.Dom.addClass(self.panels[index][0],"panelbar_option_selected");
		OAT.Dom.show(self.panels[index][1]);
		if (self.delay) {
			var a = new OAT.AnimationOpacity(self.panels[index][1],{delay:self.delay,opacity:1});
			a.start();
		}
		self.selectedIndex = index;
	}
	
	this.addPanel = function(clickerDiv,contentDiv) {
		var clicker_elm = $(clickerDiv);
		var content_elm = $(contentDiv);
		OAT.Dom.addClass(clicker_elm,"panelbar_option");
		OAT.Dom.addClass(content_elm,"panelbar_content");
		var callback = function(event) {
			var index = -1;
			for (var i=0;i<self.panels.length;i++) if (self.panels[i][0] == clicker_elm) { index = i; }
			if (index == self.selectedIndex) { return; }
			self.go(index);
		}
		OAT.Dom.attach(clicker_elm,"click",callback);
		this.panels.push([clicker_elm,content_elm]);
		this.div.appendChild(clicker_elm);
		this.div.appendChild(content_elm);
		this.go(this.panels.length-1);
	}
	
	
}
OAT.Loader.featureLoaded("panelbar");
