/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2014 OpenLink Software
 *
 *  See LICENSE file for details.
 */

/*
	new OAT.RectWin(params)
	not to be directly called, rather accessed by Window library

*/

OAT.RectWin = function(optObj) {
	var self = this;

	OAT.WindowParent(this,optObj);
	this.options.statusHeight = 30;
	this.options.moveHeight = 16;

	OAT.Style.set(this.div,{border:"1px solid rgb(164,163,163)",font:"menu",backgroundColor:"#fff"});
	OAT.Style.set(this.content,{overflow:"auto",top:"16px",position:"relative"});
	OAT.Style.set(this.move,{position:"absolute",left:"0px",top:"0px",height:this.options.moveHeight+"px"});

	if (self.options.move) {
		this.move._Drag_movers[0][1].restrictionFunction = function(l,t) {
			return l < 0 || t < 0;
		}
	}
	if (self.closeBtn) {
		OAT.Style.set(this.closeBtn,{cssFloat:"right",styleFloat:"right",fontSize:"1px",marginTop:"2px",marginRight:"2px",cursor:"pointer",width:"14px",height:"13px",backgroundImage:"url("+self.options.imagePath+"RectWin_close.gif)"});
	}

	if (self.resize) {
		OAT.Style.set(this.resize,{width:"10px",height:"10px",fontSize:"1px",position:"absolute",right:"2px",bottom:"2px",cursor:"nw-resize",backgroundImage:"url("+self.options.imagePath+"RectWin_resize.gif)"});
	}

	OAT.Style.set(this.caption,{textAlign:"center",fontWeight:"bold"});

	this.resizeTo = function(w,h) {
		if (w) {
			self.move.style.width = w + "px";
			self.div.style.width = w + "px";
			self.content.style.width = w + "px";
		}
		if (h) {
			self.div.style.height = h + "px";
			self.content.style.height = (h - self.options.statusHeight) + "px";
		}
	}

	this.moveTo = function(x,y) {
		if (x >= 0) { self.div.style.left = x + "px"; }
		if (x < 0) { self.div.style.right = (-x) + "px"; }
		if (y >= 0) { self.div.style.top = y + "px"; }
		if (y < 0) { self.div.style.bottom = (-y) + "px"; }
	}

	this.link = OAT.Dom.create("img");
	this.link.style.position = "absolute";
	this.div.appendChild(this.link);
	OAT.Dom.hide(self.link);

	this.moveLink = function(left,top) {
		OAT.Dom.show(self.link);
		if (left) { self.link.style.left = "10px"; self.link.style.right = "";}
		if (!left) { self.link.style.right = "40px"; self.link.style.left = "";}
		if (top) { self.link.style.top = "-35px"; self.link.style.bottom = "";}
		if (!top) {
			self.link.style.bottom = "-35px"; self.link.style.top = "";
			if (OAT.Browser.isIE) { self.link.style.bottom = "-35px"; }
		}
		if (left && top) {
			var path = self.options.imagePath + "RectWin_lt.png";
		}
		if (!left && !top) {
			var path = self.options.imagePath + "RectWin_rb.png";
		}
		if (left && !top) {
			var path = self.options.imagePath + "RectWin_lb.png";
		}
		if (!left && top) {
			var path = self.options.imagePath + "RectWin_rt.png";
		}
		self.link.style.width = "30px";
		self.link.style.height = "35px";
		OAT.Dom.imageSrc(self.link,path,self.options.imagePath + "Blank.gif");
	}

	this.anchorTo = function(x_,y_) { /* where should we put the window? */
		var fs = OAT.Dom.getFreeSpace(x_,y_); /* [left,top] */
		var dims = OAT.Dom.getWH(self.div);
		self.moveLink(!fs[0],!fs[1]);

		if (fs[1]) { /* top */
			var y = y_ - 50 - dims[1];
		} else { /* bottom */
			var y = y_ + 50;
		}

		if (fs[0]) { /* left */
			var x = x_ + 10 - dims[0];
		} else { /* right */
			var x = x_ - 10;
		}

		if (x < 0) { x = 10; }
		if (y < 0) { y = 10; }

		self.moveTo(x,y);
	}

}
