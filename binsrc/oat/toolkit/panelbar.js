/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2015 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	var pb = new OAT.Panelbar(div,fadeDelayAndSpeed, heightInPixelsOrFalseForAuto, doNotAnimate) ( 0 == no fade )
	pb.addPanel(clickerDiv,contentDiv)
	pb.go(0);

	CSS: .panelbar, .panelbar_option, .panelbar_option_selected, .panelbar_option_upper, .panelbar_option_lower, .panelbar_content
*/

OAT.Panelbar = function(div, delay, height, noanim) {
	var self = this;
	self.div = $(div);
	OAT.Dom.addClass(self.div,"panelbar");
	self.selectedIndex = -1;
	self.panels = [];
	self.height = false;
	self.delay = (delay ? delay : 30);
	self.noanim = (noanim ? true : false);
	self.animA = false;
	self.animB = false;

	this.go = function(index, noanim) {
		if (self.animA) self.animA.stop();
		if (self.animB) self.animB.stop();
		OAT.Dom.addClass(self.panels[index][0],"panelbar_option_selected");
		for (var i=0;i<self.panels.length;i++) {
			OAT.Dom.removeClass(self.panels[i][0],"panelbar_option_selected");
			OAT.Dom.removeClass(self.panels[i][0],"panelbar_option_upper");
			OAT.Dom.removeClass(self.panels[i][0],"panelbar_option_lower");
			OAT.Dom.addClass(self.panels[i][0],(i <= index ? "panelbar_option_upper" : "panelbar_option_lower"));
			if (i == index) { /* show the selected */
				OAT.Dom.show(self.panels[i][1]);
				if (OAT.Browser.isIE6) {
					;
				} else if (!noanim) {
					self.animA = new OAT.AnimationOpacity(self.panels[i][1],{delay:self.delay,opacity:1});
					self.animB = new OAT.AnimationSize(self.panels[i][1],{
								delay:self.delay,
								height:self.height,
								speed:self.delay
					});
					self.animA.start();
					self.animB.start();
				} else {
					OAT.Style.set(self.panels[i][1], {opacity:1});
					self.panels[i][1].style.height = self.height+'px';
				}
			} else { /* hide others */
				if (self.panels[i][1].style.height=='0px') {
					; // no need to hide again what is already hidden
				} else if (OAT.Browser.isIE6) {
					OAT.Dom.hide(self.panels[i][1]);
				} else if (!noanim) {
					var a = new OAT.AnimationOpacity(self.panels[i][1],{delay:self.delay,opacity:0});
					var b = new OAT.AnimationSize(self.panels[i][1],{delay:self.delay,height:0,speed:self.delay});
					a.start();
					b.start();
				} else {
					OAT.Style.set(self.panels[i][1], {opacity:1});
					self.panels[i][1].style.height = '0px';
				}
			}
		}
		self.selectedIndex = index;
		self.indexRunning = false;
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
			self.go(index, self.noanim);
		}
		OAT.Event.attach(clicker_elm,"click",callback);
		this.panels.push([clicker_elm,content_elm]);
		this.div.appendChild(clicker_elm);
		this.div.appendChild(content_elm);
		if (!self.height)
			self.height = parseInt(OAT.Style.get(content_elm,"height"));
		//this.go(this.panels.length-1, true);
		OAT.Style.set(content_elm, {opacity:1});
		content_elm.style.height = '0px';
	}


}
