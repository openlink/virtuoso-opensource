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

*/

OAT.RoundWin = function(optObj) {
	var self = this;

	OAT.WindowParent(this,optObj);
	
	OAT.Dom.applyStyle(this.div,{border:"1px solid rgb(160,160,164)",font:"menu",backgroundColor:"#fff"});
	OAT.Dom.applyStyle(this.content,{top:"8px",marginBottom:"14px",padding:"2px",position:"relative"}); 

	document.body.appendChild(this.div);
	OAT.SimpleFX.roundDiv(this.div,{antialias:0,size:15});
	OAT.Dom.unlink(this.div);

	OAT.Dom.applyStyle(this.move,{position:"absolute",left:"0px",top:"-8px",width:"100%",height:"16px",borderBottom:"1px solid rgb(208,208,210)"}); 

	if (self.options.move) { 
		this.move._Drag_movers[0][1].restrictionFunction = function(l,t) {
			return l < 0 || t < 5;
		}
	}

	if (self.closeBtn) {
		OAT.Dom.applyStyle(this.closeBtn,{cssFloat:"right",styleFloat:"right",fontSize:"1px",marginTop:"2px",marginRight:"5px",cursor:"pointer",width:"14px",height:"13px",backgroundImage:"url("+self.options.imagePath+"RoundWin_close.gif)"});
	}

	if (self.resize) {
		OAT.Dom.applyStyle(this.resize,{width:"10px",height:"10px",fontSize:"1px",position:"absolute",right:"5px",bottom:"-4px",cursor:"nw-resize",backgroundImage:"url("+self.options.imagePath+"RoundWin_resize.gif)"});
		this.resize.parentNode.appendChild(this.resize);
	}

	OAT.Dom.applyStyle(this.caption,{textAlign:"center",fontWeight:"bold"});
}

OAT.Loader.featureLoaded("roundwin");
