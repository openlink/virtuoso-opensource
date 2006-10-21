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
	new OAT.MsWin(params)
	not to be directly called, rather accessed by Window library
	
	exports: div, content, closeBtn, minBtn, maxBtn, move, caption
	
	no styling via CSS available ATM
*/

OAT.MsWin = function(optObj) {
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

	this.div = OAT.Dom.create("div",{position:"absolute",border:"1px solid #000",font:"menu",backgroundColor:"#fff"});
	if (options.x >= 0) { this.div.style.left = options.x + "px";	}
	if (options.x < 0) {this.div.style.right = (-options.x) + "px"; }
	if (options.y >= 0) { this.div.style.top = options.y + "px"; }
	if (options.y < 0) { this.div.style.bottom = (-options.y) + "px"; }

	this.content = OAT.Dom.create("div",{overflow:"auto",paddingTop:"16px",paddingLeft:"2px",paddingRight:"2px",paddingBottom:"2px",position:"relative"}); 
	if (options.width) this.content.style.width = options.width + "px";
	if (options.height) this.content.style.height = options.height + "px";
	this.div.appendChild(this.content);

	this.move = OAT.Dom.create("div",{position:"absolute",left:"0px",top:"0px",width:"100%",height:"16px",backgroundColor:"#0000a0",fontWeight:"bold",color:"#fff"}); 
	this.div.appendChild(this.move);
	OAT.Drag.create(this.move,this.div);
	this.move._Drag_movers[0][1].restrictionFunction = function(l,t) {
		return l < 0 || t < 14;
	}
	
	if (options.close) {
		this.closeBtn = OAT.Dom.create("div",{cssFloat:"right",styleFloat:"right",fontSize:"1px",marginTop:"1px",cursor:"pointer",width:"16px",height:"14px",backgroundImage:"url("+options.imagePath+"MsWin_close.png)"});
		this.move.appendChild(this.closeBtn);
	}

	if (options["max"]) {
		this.maxBtn = OAT.Dom.create("div",{cssFloat:"right",styleFloat:"right",fontSize:"1px",marginTop:"1px",cursor:"pointer",width:"16px",height:"14px",backgroundImage:"url("+options.imagePath+"MsWin_maximize.png)"});
		this.move.appendChild(this.maxBtn);
	}

	if (options["min"]) {
		this.minBtn = OAT.Dom.create("div",{cssFloat:"right",styleFloat:"right",fontSize:"1px",marginTop:"1px",cursor:"pointer",width:"16px",height:"14px",backgroundImage:"url("+options.imagePath+"MsWin_minimize.png)"});
		this.move.appendChild(this.minBtn);
	}

	if (options.resize) {
		this.resize = OAT.Dom.create("div",{width:"10px",height:"10px",fontSize:"1px",position:"absolute",right:"0px",bottom:"0px",cursor:"nw-resize",backgroundImage:"url("+options.imagePath+"MsWin_resize.gif)"});
 		this.div.appendChild(this.resize);
 		OAT.Resize.create(this.resize,this.content,OAT.Resize.TYPE_XY);
	}

	this.caption = OAT.Dom.create("div");
	this.caption.innerHTML = "&nbsp;"+options.title;
	this.move.appendChild(this.caption);
}

OAT.Loader.pendingCount--;
