/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
 *  
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *  
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *  
 *  
*/
/*
	new MsWin(params)
	
	no styling via CSS available ATM
*/

function MsWin(p) {
	this.def = {
		min:1,
		max:1,
		close:1,
		move:1,
		resize:1,
		x:10,
		y:10,
		w:160,
		h:50,
		title:""
	}


	this.params = {};
	for (var property in this.def) {
		if (property in p) {
			this.params[property] = p[property];
		} else {
			this.params[property] = this.def[property];
		}
	}


	this.div = Dom.create("div",{position:"absolute",border:"1px solid #000",font:"menu",backgroundColor:"#fff"}); /* window */
	if (this.params["x"] >= 0) { this.div.style.left = this.params["x"] + "px";	}
	if (this.params["x"] < 0) {this.div.style.right = (-this.params["x"]) + "px"; }
	if (this.params["y"] >= 0) { this.div.style.top = this.params["y"] + "px"; }
	if (this.params["y"] < 0) { this.div.style.bottom = (-this.params["y"]) + "px"; }
	if (this.params["w"]) this.div.style.width = this.params["w"] + "px";
	if (this.params["h"]) this.div.style.height = this.params["h"] + "px";

	Window.create(this.div,Window.MAXIMIZED);

	this.content = Dom.create("div",{position:"relative",paddingLeft:"2px",paddingRight:"2px",marginBottom:"2px",overflow:"auto"}); 
	if (this.params["h"]) this.content.style.height = (this.params["h"]-18) + "px";
	if (this.params["w"]) this.content.style.width = (this.params["w"] - 4)+ "px";

	if (this.params["move"]) {
		this.move = Dom.create("div",{width:"100%",height:"16px",paddingTop:"2px",backgroundColor:"#0000a0",fontWeight:"bold",color:"#fff"});
		
		if (this.params["close"]) {
			this.close = Dom.create("div",{cssFloat:"right",styleFloat:"right",marginTop:"1px",width:"16px",height:"14px",backgroundRepeat:"no-repeat",backgroundImage:"url(images/MsWin_close.png)"});
			this.move.appendChild(this.close);
			Window.createClose(this.close,this.div);
		}

		if (this.params["max"]) {
			this.max = Dom.create("div",{cssFloat:"right",styleFloat:"right",marginTop:"1px",width:"16px",height:"14px",backgroundRepeat:"no-repeat",backgroundImage:"url(images/MsWin_maximize.png)"});
			this.move.appendChild(this.max);
			Window.createMaximize(this.max,this.div);
		}

		if (this.params["min"]) {
			this.min = Dom.create("div",{cssFloat:"right",styleFloat:"right",marginTop:"1px",width:"16px",height:"14px",backgroundRepeat:"no-repeat",backgroundImage:"url(images/MsWin_minimize.png)"});
			this.move.appendChild(this.min);
			Window.createMinimize(this.min,this.div);
		}

		this.move.caption = Dom.create("div");
		this.move.caption.innerHTML = "&nbsp;"+this.params["title"];
		this.move.appendChild(this.move.caption);
		this.div.appendChild(this.move);
		Drag.create(this.move,this.div);
	}
	
	this.div.appendChild(this.content);

	if (this.params["resize"]) {
		var resize = Dom.create("div",{width:"10px",height:"10px",position:"absolute",right:"-5px",bottom:"-5px",cursor:"nw-resize"});
		this.div.appendChild(resize);
		Resize.create(resize,this.content,Resize.TYPE_XY);
		Resize.create(resize,this.div,Resize.TYPE_XY);
	}
}