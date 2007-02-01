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
	new OAT.RectWin(params)
	not to be directly called, rather accessed by Window library
	
*/

OAT.RectWin = function(optObj) {
	var self = this;

	OAT.WindowParent(this,optObj);
	
	OAT.Dom.applyStyle(this.div,{border:"1px solid rgb(164,163,163)",font:"menu",backgroundColor:"#fff"});
	OAT.Dom.applyStyle(this.content,{overflow:"auto",top:"16px",marginBottom:"20px",padding:"2px",position:"relative"}); 
	
	OAT.Dom.applyStyle(this.move,{position:"absolute",left:"0px",top:"0px",width:"100%",height:"16px"}); 

	if (self.options.move) { 
		this.move._Drag_movers[0][1].restrictionFunction = function(l,t) {
			return l < 0 || t < 5;
		}
	}
	if (self.closeBtn) {
		OAT.Dom.applyStyle(this.closeBtn,{cssFloat:"right",styleFloat:"right",fontSize:"1px",marginTop:"2px",marginRight:"2px",cursor:"pointer",width:"14px",height:"13px",backgroundImage:"url("+self.options.imagePath+"RectWin_close.gif)"});
	}

	if (self.resize) {
		OAT.Dom.applyStyle(this.resize,{width:"10px",height:"10px",fontSize:"1px",position:"absolute",right:"2px",bottom:"2px",cursor:"nw-resize",backgroundImage:"url("+self.options.imagePath+"RectWin_resize.gif)"});
	}

	OAT.Dom.applyStyle(this.caption,{textAlign:"center",fontWeight:"bold"});

	this.link = OAT.Dom.create("img");
	this.link.style.position = "absolute";
	this.div.appendChild(this.link);
	OAT.Dom.hide(self.link);
	
	this.moveLink = function(left,top) {
		OAT.Dom.show(self.link);
		if (left) { self.link.style.left = "10px"; }
		if (!left) { self.link.style.right = "40px"; }
		if (top) { self.link.style.top = "-35px"; }
		if (!top) { self.link.style.bottom = "-35px"; }
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
		self.link.src = path;
		self.link.style.filter = "progid:DXImageTransform.Microsoft.AlphaImageLoader(src='"+path+"', sizingMethod='crop')";
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
		
		self.div.style.left = x+"px";
		self.div.style.top = y+"px";
	}

}

OAT.Loader.featureLoaded("rectwin");
