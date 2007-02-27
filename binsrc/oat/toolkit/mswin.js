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
	
*/

OAT.MsWin = function(optObj) {
	var self = this;
	
	OAT.WindowParent(this,optObj);
	
	OAT.Dom.applyStyle(this.div,{border:"1px solid #000",font:"menu",backgroundColor:"#fff"});
	OAT.Dom.applyStyle(this.content,{overflow:"auto",marginTop:"16px",paddingLeft:"2px",paddingRight:"2px",marginBottom:"10px",position:"relative"}); 

	OAT.Dom.applyStyle(this.move,{position:"absolute",left:"0px",top:"0px",width:"100%",height:"16px",backgroundColor:"#0000a0",fontWeight:"bold",color:"#fff"}); 

	this.move._Drag_movers[0][1].restrictionFunction = function(l,t) {
		return l < 0 || t < 14;
	}
	
	if (this.closeBtn) {
		OAT.Dom.applyStyle(this.closeBtn,{cssFloat:"right",styleFloat:"right",fontSize:"1px",marginTop:"1px",cursor:"pointer",width:"16px",height:"14px",backgroundImage:"url("+self.options.imagePath+"MsWin_close.png)"});
	}

	if (this.maxBtn) {
		OAT.Dom.applyStyle(this.maxBtn,{cssFloat:"right",styleFloat:"right",fontSize:"1px",marginTop:"1px",cursor:"pointer",width:"16px",height:"14px",backgroundImage:"url("+self.options.imagePath+"MsWin_maximize.png)"});
	}

	if (this.minBtn) {
		OAT.Dom.applyStyle(this.minBtn,{cssFloat:"right",styleFloat:"right",fontSize:"1px",marginTop:"1px",cursor:"pointer",width:"16px",height:"14px",backgroundImage:"url("+self.options.imagePath+"MsWin_minimize.png)"});
	}

	if (this.resize) {
		OAT.Dom.applyStyle(this.resize,{width:"10px",height:"10px",fontSize:"1px",position:"absolute",right:"0px",bottom:"0px",cursor:"nw-resize",backgroundImage:"url("+self.options.imagePath+"MsWin_resize.gif)"});
	}

}

OAT.Loader.featureLoaded("mswin");
