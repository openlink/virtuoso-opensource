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

OAT.Panelbar = function(div,delay,height) {
	var self = this;
	this.div = $(div);
	OAT.Dom.addClass(self.div,"panelbar");
	this.selectedIndex = -1;
	this.panels = [];
	this.delay = delay;
	this.height = self.div.style.heigh
	
	this.go = function(index,noanim) {
		if (!self.delay) self.delay = 20;
		if (!self.height) self.height = 350;
		OAT.Dom.addClass(self.panels[index][0],"panelbar_option_selected");
		for (var i=0;i<self.panels.length;i++) {
			OAT.Dom.removeClass(self.panels[i][0],"panelbar_option_selected");
			OAT.Dom.removeClass(self.panels[i][0],"panelbar_option_upper");
			OAT.Dom.removeClass(self.panels[i][0],"panelbar_option_lower");
			OAT.Dom.addClass(self.panels[i][0],(i <= index ? "panelbar_option_upper" : "panelbar_option_lower"));
			if (i == index) { /* show the selected */
				if (OAT.Browser.isIE6) {
					OAT.Dom.show(self.panels[i][1]);
				} else if (!noanim) {
					var a = new OAT.AnimationOpacity(self.panels[i][1],{delay:self.delay,opacity:1});
					var b = new OAT.AnimationSize(self.panels[i][1],{delay:self.delay,height:self.height,speed:self.delay});
					a.start();
					b.start();
				} else {
					OAT.Style.opacity(self.panels[i][1], 0);
					self.panels[i][1].style.height = '0px';
				}
			} else { /* hide others */
				if (OAT.Browser.isIE6) {
					OAT.Dom.hide(self.panels[i][1]);
				} else if (!noanim) {
					var a = new OAT.AnimationOpacity(self.panels[i][1],{delay:self.delay,opacity:0});
					var b = new OAT.AnimationSize(self.panels[i][1],{delay:self.delay,height:0,speed:self.delay});
					a.start();
					b.start();
				} else {
					OAT.Style.opacity(self.panels[i][1], 1);
					self.panels[i][1].style.height = '0px';
				}
			}
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
		this.go(this.panels.length-1, true);
	}
	
	
}
OAT.Loader.featureLoaded("panelbar");
