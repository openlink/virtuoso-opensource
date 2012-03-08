/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2012 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	new OAT.MacWin(params)
	not to be directly called, rather accessed by Window library

	exports: div, content, closeBtn, minBtn, maxBtn, move, caption, anchorTo, resizeTo

	no styling via CSS available ATM
*/

OAT.MacWin = function(optObj) {
	var self = this;

	OAT.WindowParent(this,optObj);
	this.options.statusHeight = 16;
	this.options.moveHeight = 23;

	OAT.Style.set(this.div,{font:"menu",backgroundColor:"#c5c5c5"});

	var opt = {
		corners:[1,1,0,0], /* CW from LT */
		edges:[1,1,0,1], /* CW from T */
		cornerFiles:[self.options.imagePath+"MacWin_lt.gif",self.options.imagePath+"MacWin_rt.gif","",""],
		edgeFiles:[self.options.imagePath+"MacWin_top.gif",self.options.imagePath+"MacWin_left.gif","",self.options.imagePath+"MacWin_right.gif"],
		thickness:[23,8,0,8] /* CW from T */
	}
	OAT.Style.set(this.content,{position:"relative"});

	OAT.SimpleFX.roundImg(this.div,opt);
	OAT.SimpleFX.shadow(this.div,{offsetX:8,imagePath:self.options.imagePath});

	OAT.Resize.remove(this.resize,this.move);
	OAT.Dom.unlink(this.move);
	this.move = this.div.edgeElms[0];
	OAT.Drag.create(this.move,this.div);
	OAT.Drag.create(this.div.cornerElms[0],this.div);
	OAT.Drag.create(this.div.cornerElms[1],this.div);
	if (self.options.resize) { OAT.Resize.create(this.resize,this.move,OAT.Resize.TYPE_X); }
	this.move._Drag_movers[0][1].restrictionFunction = function(l,t) {
		return l < 5 || t < self.options.statusHeight;
	}

	this.resizeTo = function(w,h) {
		if (w) {
			self.move.style.width = (w-16) + "px";
			self.div.style.width = (w-16) + "px";
			self.content.style.width = (w-16) + "px";
		}
		if (h) {
			self.div.style.height = (h - self.options.moveHeight) + "px";
			self.content.style.height = (h - self.options.statusHeight - self.options.moveHeight) + "px";
		}
	}

	this.moveTo = function(x,y) {
		if (x >= 0) { self.div.style.left = (x+8) + "px"; }
		if (x < 0) { self.div.style.right = (-x) + "px"; }
		if (y >= 0) { self.div.style.top = (y+self.options.moveHeight) + "px"; }
		if (y < 0) { self.div.style.bottom = (-y) + "px"; }
	}

	this.closeBtn = OAT.Dom.create("div",{cssFloat:"left",styleFloat:"left",fontSize:"1px",marginTop:"5px",marginRight:"1px",width:"13px",height:"13px",backgroundImage:"url("+self.options.imagePath+"MacWin_blank.gif)"});
	this.minBtn = OAT.Dom.create("div",{cssFloat:"left",styleFloat:"left",fontSize:"1px",marginTop:"5px",marginRight:"1px",width:"13px",height:"13px",backgroundImage:"url("+self.options.imagePath+"MacWin_blank.gif)"});
	this.maxBtn = OAT.Dom.create("div",{cssFloat:"left",styleFloat:"left",fontSize:"1px",marginTop:"5px",marginRight:"1px",width:"13px",height:"13px",backgroundImage:"url("+self.options.imagePath+"MacWin_blank.gif)"});

	this.caption = OAT.Dom.create("div",{textAlign:"center",fontSize:"12px", paddingTop:"4px", fontWeight:"bold", color:"#000"});
	this.caption.innerHTML = "&nbsp;"+self.options.title;

	OAT.Dom.append([this.move,this.closeBtn,this.minBtn,this.maxBtn,this.caption]);

	if (self.options.close) {
		this.closeBtn.style.backgroundImage = "url("+self.options.imagePath+"MacWin_close.gif)";
		this.closeBtn.style.cursor = "pointer";
		OAT.Event.attach(this.closeBtn,"mouseover",function(){self.closeBtn.style.backgroundImage = "url("+self.options.imagePath+"MacWin_close_hover.gif)";});
		OAT.Event.attach(this.closeBtn,"mouseout",function(){self.closeBtn.style.backgroundImage = "url("+self.options.imagePath+"MacWin_close.gif)";});
	} else { this.closeBtn = false; }

	if (self.options.min) {
		this.minBtn.style.backgroundImage = "url("+self.options.imagePath+"MacWin_minimize.gif)";
		this.minBtn.style.cursor = "pointer";
		OAT.Event.attach(this.minBtn,"mouseover",function(){self.minBtn.style.backgroundImage = "url("+self.options.imagePath+"MacWin_minimize_hover.gif)";});
		OAT.Event.attach(this.minBtn,"mouseout",function(){self.minBtn.style.backgroundImage = "url("+self.options.imagePath+"MacWin_minimize.gif)";});
	} else { this.minBtn = false; }

	if (self.options.max) {
		this.maxBtn.style.backgroundImage = "url("+self.options.imagePath+"MacWin_maximize.gif)";
		this.maxBtn.style.cursor = "pointer";
		OAT.Event.attach(this.maxBtn,"mouseover",function(){self.maxBtn.style.backgroundImage = "url("+self.options.imagePath+"MacWin_maximize_hover.gif)";});
		OAT.Event.attach(this.maxBtn,"mouseout",function(){self.maxBtn.style.backgroundImage = "url("+self.options.imagePath+"MacWin_maximize.gif)";});
	} else { this.maxBtn = false; }

	if (self.options.resize) {
		OAT.Style.set(this.resize,{width:"10px",height:"10px",fontSize:"1px",position:"absolute",right:"-8px",bottom:"0px",cursor:"nw-resize",backgroundImage:"url("+self.options.imagePath+"MsWin_resize.gif)"});
	}

}
