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
	new OAT.RoundWin(params)
	not to be directly called, rather accessed by Window library

*/

OAT.RoundWin = function(optObj) {
	var self = this;

	OAT.WindowParent(this,optObj);
	this.options.statusHeight = 20;
	this.options.moveHeight = 8;

	OAT.Style.set(this.div,{border:"1px solid rgb(160,160,164)",font:"menu",backgroundColor:"#fff"});
	OAT.Style.set(this.content,{top:"8px",position:"relative"});

	document.body.appendChild(this.div);
	var tmp = OAT.SimpleFX.roundDiv(this.div,{antialias:0,size:15});
	OAT.Dom.unlink(this.div);

	if (OAT.Browser.isIE && document.compatMode == "BackCompat") {
		OAT.Resize.create(self.resize,tmp[0],OAT.Resize.TYPE_X);
		OAT.Resize.create(self.resize,tmp[1],OAT.Resize.TYPE_X);
		this.resizeTo = function(w,h) {
			if (w) {
				tmp[0].style.width = (w+1) + "px";
				tmp[1].style.width = (w+1) + "px";
				self.move.style.width = w + "px";
				self.div.style.width = w + "px";
				self.content.style.width = w + "px";
			}
			if (h) {
				self.div.style.height = (h - self.options.moveHeight) + "px";
				self.content.style.height = (h - self.options.statusHeight - self.options.moveHeight + 3) + "px";
			}
		}
	}

	OAT.Style.set(this.move,{position:"absolute",left:"0px",top:(-self.options.moveHeight)+"px",height:2*self.options.moveHeight+"px",borderBottom:"1px solid rgb(208,208,210)"});

	if (self.options.move) {
		this.move._Drag_movers[0][1].restrictionFunction = function(l,t) {
			return l < 0 || t <= self.options.moveHeight;
		}
	}

	if (self.closeBtn) {
		OAT.Style.set(this.closeBtn,{cssFloat:"right",styleFloat:"right",fontSize:"1px",marginTop:"2px",marginRight:"5px",cursor:"pointer",width:"14px",height:"13px",backgroundImage:"url("+self.options.imagePath+"RoundWin_close.gif)"});
	}

	if (self.resize) {
		OAT.Style.set(this.resize,{width:"10px",height:"10px",fontSize:"1px",position:"absolute",right:"5px",bottom:"-4px",cursor:"nw-resize",backgroundImage:"url("+self.options.imagePath+"RoundWin_resize.gif)"});
		this.resize.parentNode.appendChild(this.resize);
	}

	OAT.Style.set(this.caption,{textAlign:"center",fontWeight:"bold"});
}
