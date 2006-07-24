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
	OAT.Color.pick(x,y,callback)  --  we will callback(selected_color) when user selects one
*/

OAT.Color = {
	pick:function(x,y,callback) {
		var div = OAT.Dom.create("div",{position:"absolute",backgroundColor:"#fff",border:"2px solid #000",padding:"2px",width:"168px",zIndex:200});
		this.div = div;
		if (OAT.Dom.isIE()) { div.style.width = "170px"; } else { div.style.width = "162px"; }
		OAT.Drag.create(div,div);
		if (x>=0) { div.style.left = x+"px"; } else { div.style.right = (-x)+"px"; }
		if (y>=0) { div.style.top = y+"px"; } else { div.style.bottom = (-y)+"px"; }
		var close = OAT.Dom.create("div",{cssFloat:"right",styleFloat:"right",fontWeight:"bold",cursor:"pointer"});
		var help = OAT.Dom.create("div",{borderBottom:"1px solid #000"});
		help.innerHTML = "&nbsp;";
		close.innerHTML = 'X';
		OAT.Dom.attach(close,"click",function(){OAT.Dom.unlink(div);});
		div.appendChild(close);
		div.appendChild(help);
		var col = 0;
		var prepare = function(elm,color) {
			var overRef = function(event) { help.innerHTML = color; }
			var clickRef = function(event) { OAT.Dom.unlink(div); callback(color); }
			OAT.Dom.attach(elm,"mouseover",overRef);
			OAT.Dom.attach(elm,"click",clickRef);
		}
		for (var i=0;i<6;i++)
			for (var j=0;j<3;j++)
				for (var k=0;k<6;k++) {
					var color = "#"+OAT.Dom.dec2hex(3*j)+OAT.Dom.dec2hex(3*k)+OAT.Dom.dec2hex(3*i);
					var elm = OAT.Dom.create("div",{cssFloat:"left",styleFloat:"left",width:"9px",height:"9px",backgroundColor:color,cursor:"crosshair",overflow:"hidden"});
					div.appendChild(elm);
					prepare(elm,color);
				}
		for (var i=0;i<6;i++)
			for (var j=3;j<6;j++)
				for (var k=0;k<6;k++) {
					var color = "#"+OAT.Dom.dec2hex(3*j)+OAT.Dom.dec2hex(3*k)+OAT.Dom.dec2hex(3*i);
					var elm = OAT.Dom.create("div",{cssFloat:"left",styleFloat:"left",width:"9px",height:"9px",backgroundColor:color,cursor:"crosshair",overflow:"hidden"});
					div.appendChild(elm);
					prepare(elm,color);
				}
				
		
		document.body.appendChild(div);
	}
}
OAT.Loader.pendingCount--;
