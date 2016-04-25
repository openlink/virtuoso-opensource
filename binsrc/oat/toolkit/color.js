/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2016 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	var c = new OAT.Color()
	c.pick(x,y,callback)  --  we will callback(selected_color) when user selects one
*/

OAT.Color = function() {
	var self = this;
	this.callback = function(){};

	this.div = OAT.Dom.create("div",{position:"absolute",backgroundColor:"#fff",border:"2px solid #000",padding:"2px",width:"168px",zIndex:200});
	this.div.style.width = (OAT.Browser.isIE ? "170px" : "162px");
	OAT.Drag.create(this.div,this.div);
	var close = OAT.Dom.create("div",{cssFloat:"right",styleFloat:"right",fontWeight:"bold",cursor:"pointer"});
	var help = OAT.Dom.create("div",{borderBottom:"1px solid #000"});
	help.innerHTML = "&nbsp;";
	close.innerHTML = 'X';
	OAT.Event.attach(close,"click",function(){OAT.Dom.unlink(self.div);});
	this.div.appendChild(close);
	this.div.appendChild(help);

	var col = 0;
	var prepare = function(elm,color) {
		var overRef = function(event) { help.innerHTML = color; }
		var clickRef = function(event) { OAT.Dom.unlink(self.div); self.callback(color); }
		OAT.Event.attach(elm,"mouseover",overRef);
		OAT.Event.attach(elm,"click",clickRef);
	}

	function dec2hex(dec) {
		return dec.toString(16);
	}

	for (var i=0;i<6;i++)
		for (var j=0;j<3;j++)
			for (var k=0;k<6;k++) {
				var color = "#"+dec2hex(3*j)+dec2hex(3*k)+dec2hex(3*i);
				var elm = OAT.Dom.create("div",{cssFloat:"left",styleFloat:"left",width:"9px",height:"9px",backgroundColor:color,cursor:"crosshair",overflow:"hidden"});
				self.div.appendChild(elm);
				prepare(elm,color);
			}
	for (var i=0;i<6;i++)
		for (var j=3;j<6;j++)
			for (var k=0;k<6;k++) {
				var color = "#"+dec2hex(3*j)+dec2hex(3*k)+dec2hex(3*i);
				var elm = OAT.Dom.create("div",{cssFloat:"left",styleFloat:"left",width:"9px",height:"9px",backgroundColor:color,cursor:"crosshair",overflow:"hidden"});
				self.div.appendChild(elm);
				prepare(elm,color);
			}



	this.pick = function(x,y,callback) {
		self.callback = callback;
		var d = self.div;
		if (x>=0) { d.style.left = x+"px"; } else { d.style.right = (-x)+"px"; }
		if (y>=0) { d.style.top = y+"px"; } else { d.style.bottom = (-y)+"px"; }
		document.body.appendChild(d);
	}
}
