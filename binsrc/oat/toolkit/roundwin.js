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
	new OAT.RoundWin(params)
	not to be directly called, rather accessed by Window library
	
	exports: div, content, closeBtn, minBtn, maxBtn, move, caption
	
	no styling via CSS available ATM
*/

OAT.RoundWin = function(optObj) {
	var self = this;
	var options = {
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

	this.div = OAT.Dom.create("div",{position:"absolute",border:"1px solid rgb(160,160,164)",font:"menu",backgroundColor:"#fff"});
	if (options.x >= 0) { this.div.style.left = options.x + "px"; }
	if (options.x < 0) {this.div.style.right = (-options.x) + "px"; }
	if (options.y >= 0) { this.div.style.top = options.y + "px"; }
	if (options.y < 0) { this.div.style.bottom = (-options.y) + "px"; }

	this.content = OAT.Dom.create("div",{overflow:"auto",top:"8px",marginBottom:"4px",padding:"2px",position:"relative"}); 

	if (options.width) this.content.style.width = options.width + "px";
	if (options.height) this.content.style.height = options.height + "px";
	this.div.appendChild(this.content);
	
	document.body.appendChild(this.div);
	OAT.SimpleFX.roundDiv(this.div,{antialias:0,size:15});
	OAT.Dom.unlink(this.div);

	this.move = OAT.Dom.create("div",{position:"absolute",left:"0px",top:"-8px",width:"100%",height:"16px",borderBottom:"1px solid rgb(208,208,210)"}); 
	this.div.appendChild(this.move);
	OAT.Drag.create(this.move,this.div);
	this.move._Drag_movers[0][1].restrictionFunction = function(l,t) {
		return l < 0 || t < 5;
	}
	
	if (options.close) {
		this.closeBtn = OAT.Dom.create("div",{cssFloat:"right",styleFloat:"right",fontSize:"1px",marginTop:"2px",marginRight:"5px",cursor:"pointer",width:"14px",height:"13px",backgroundImage:"url("+options.imagePath+"RoundWin_close.gif)"});
		this.move.appendChild(this.closeBtn);
	}

	if (options.resize) {
		this.resize = OAT.Dom.create("div",{width:"10px",height:"10px",fontSize:"1px",position:"absolute",right:"5px",bottom:"-4px",cursor:"nw-resize",backgroundImage:"url("+options.imagePath+"RoundWin_resize.gif)"});
 		this.div.appendChild(this.resize);
 		OAT.Resize.create(this.resize,this.content,OAT.Resize.TYPE_XY);
	}

	this.caption = OAT.Dom.create("div",{textAlign:"center",fontWeight:"bold"});
	this.caption.innerHTML = "&nbsp;"+options.title;
	this.move.appendChild(this.caption);
}

OAT.Loader.pendingCount--;
