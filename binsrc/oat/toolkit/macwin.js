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
	new OAT.MacWin(params)
	not to be directly called, rather accessed by Window library
	
	exports: div, content, closeBtn, minBtn, maxBtn, move, caption
	
	no styling via CSS available ATM
*/

OAT.MacWin = function(optObj) {
	var self = this;
	var options = {
		min:1,
		max:1,
		close:1,
		resize:1,
		x:10,
		y:10,
		width:160,
		height:50,
		title:"",
		imagePath:"/DAV/JS/images/"
	}

	for (var p in optObj) {	options[p] = optObj[p]; }
	
	this.div = OAT.Dom.create("div",{position:"absolute",font:"menu",backgroundColor:"#c5c5c5"});
	if (options.x >= 0) { this.div.style.left = options.x + "px";	}
	if (options.x < 0) {this.div.style.right = (-options.x) + "px"; }
	if (options.y >= 0) { this.div.style.top = (options.y+23) + "px"; }
	if (options.y < 0) { this.div.style.bottom = (-options.y) + "px"; }
	
	var opt = {
		corners:[1,1,0,0], /* CW from LT */
		edges:[1,1,0,1], /* CW from T */
		cornerFiles:[options.imagePath+"MacWin_lt.gif",options.imagePath+"MacWin_rt.gif","",""],
		edgeFiles:[options.imagePath+"MacWin_top.gif",options.imagePath+"MacWin_left.gif","",options.imagePath+"MacWin_right.gif"],
		thickness:[23,8,0,8] /* CW from T */
	}
	this.content = OAT.Dom.create("div",{overflow:"auto",padding:"2px",position:"relative"}); 
	if (options.width) this.content.style.width = options.width + "px";
	if (options.height) this.content.style.height = options.height + "px";
	this.div.appendChild(this.content);
	
	opt.ieElm = this.content;
	OAT.SimpleFX.round(this.div,opt);
	OAT.SimpleFX.shadow(this.div,{offsetX:8,ieElm:this.content,imagePath:options.imagePath});

	this.move = this.div.edgeElms[0];
	OAT.Drag.create(this.move,this.div);
	OAT.Drag.create(this.div.cornerElms[0],this.div);
	OAT.Drag.create(this.div.cornerElms[1],this.div);
	this.move._Drag_movers[0][1].restrictionFunction = function(l,t) {
		return l < 5 || t < 20;
	}

	this.closeBtn = OAT.Dom.create("div",{cssFloat:"left",styleFloat:"left",fontSize:"1px",marginTop:"5px",marginRight:"1px",width:"13px",height:"13px",backgroundImage:"url("+options.imagePath+"MacWin_blank.gif)"});
	this.move.appendChild(this.closeBtn);

	this.minBtn = OAT.Dom.create("div",{cssFloat:"left",styleFloat:"left",fontSize:"1px",marginTop:"5px",marginRight:"1px",width:"13px",height:"13px",backgroundImage:"url("+options.imagePath+"MacWin_blank.gif)"});
	this.move.appendChild(this.minBtn);

	this.maxBtn = OAT.Dom.create("div",{cssFloat:"left",styleFloat:"left",fontSize:"1px",marginTop:"5px",marginRight:"1px",width:"13px",height:"13px",backgroundImage:"url("+options.imagePath+"MacWin_blank.gif)"});
	this.move.appendChild(this.maxBtn);

	if (options.close) {
		this.closeBtn.style.backgroundImage = "url("+options.imagePath+"MacWin_close.gif)";
		this.closeBtn.style.cursor = "pointer";
		OAT.Dom.attach(this.closeBtn,"mouseover",function(){self.closeBtn.style.backgroundImage = "url("+options.imagePath+"MacWin_close_hover.gif)";});
		OAT.Dom.attach(this.closeBtn,"mouseout",function(){self.closeBtn.style.backgroundImage = "url("+options.imagePath+"MacWin_close.gif)";});
	} else { this.closeBtn = false; }
	
	if (options.min) {
		this.minBtn.style.backgroundImage = "url("+options.imagePath+"MacWin_minimize.gif)";
		this.minBtn.style.cursor = "pointer";
		OAT.Dom.attach(this.minBtn,"mouseover",function(){self.minBtn.style.backgroundImage = "url("+options.imagePath+"MacWin_minimize_hover.gif)";});
		OAT.Dom.attach(this.minBtn,"mouseout",function(){self.minBtn.style.backgroundImage = "url("+options.imagePath+"MacWin_minimize.gif)";});
	} else { this.minBtn = false; }

	if (options.max) {
		this.maxBtn.style.backgroundImage = "url("+options.imagePath+"MacWin_maximize.gif)";
		this.maxBtn.style.cursor = "pointer";
		OAT.Dom.attach(this.maxBtn,"mouseover",function(){self.maxBtn.style.backgroundImage = "url("+options.imagePath+"MacWin_maximize_hover.gif)";});
		OAT.Dom.attach(this.maxBtn,"mouseout",function(){self.maxBtn.style.backgroundImage = "url("+options.imagePath+"MacWin_maximize.gif)";});
	} else { this.maxBtn = false; }

	if (options.resize) {
		this.resize = OAT.Dom.create("div",{width:"10px",height:"10px",fontSize:"1px",position:"absolute",right:"-8px",bottom:"0px",cursor:"nw-resize",backgroundImage:"url("+options.imagePath+"MsWin_resize.gif)"});
		this.div.appendChild(this.resize);
		OAT.Resize.create(this.resize,this.content,OAT.Resize.TYPE_XY);
	}

	this.caption = OAT.Dom.create("div",{textAlign:"center",fontSize:"12px", paddingTop:"4px", fontWeight:"bold", color:"#000"});
	this.caption.innerHTML = "&nbsp;"+options.title;
	this.move.appendChild(this.caption);
}

OAT.Loader.pendingCount--;
