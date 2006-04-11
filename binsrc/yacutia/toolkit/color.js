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
	Color.pick(x,y,callback)  --  we will callback(selected_color) when user selects one
*/

var Color = {
	pick:function(x,y,callback) {
		var div = Dom.create("div",{position:"absolute",backgroundColor:"#fff",border:"2px solid #000",padding:"2px",width:"168px"});
		if (Dom.isIE()) { div.style.width = "170px"; } else { div.style.width = "162px"; }
		Drag.create(div,div);
		if (x>=0) { div.style.left = x+"px"; } else { div.style.right = (-x)+"px"; }
		if (y>=0) { div.style.top = y+"px"; } else { div.style.bottom = (-y)+"px"; }
		var close = Dom.create("div",{cssFloat:"right",styleFloat:"right",fontWeight:"bold",cursor:"pointer"});
		var help = Dom.create("div",{borderBottom:"1px solid #000"});
		help.innerHTML = "&nbsp;";
		close.innerHTML = 'X';
		Dom.attach(close,"click",function(){Dom.unlink(div);});
		div.appendChild(close);
		div.appendChild(help);
		var col = 0;
		var prepare = function(elm,color) {
			var overRef = function(event) { help.innerHTML = color; }
			var clickRef = function(event) { Dom.unlink(div); callback(color); }
			Dom.attach(elm,"mouseover",overRef);
			Dom.attach(elm,"click",clickRef);
		}
		for (var i=0;i<6;i++)
			for (var j=0;j<3;j++)
				for (var k=0;k<6;k++) {
					var color = "#"+Dom.dec2hex(3*j)+Dom.dec2hex(3*k)+Dom.dec2hex(3*i);
					var elm = Dom.create("div",{cssFloat:"left",styleFloat:"left",width:"9px",height:"9px",backgroundColor:color,cursor:"crosshair",overflow:"hidden"});
					div.appendChild(elm);
					prepare(elm,color);
				}
		for (var i=0;i<6;i++)
			for (var j=3;j<6;j++)
				for (var k=0;k<6;k++) {
					var color = "#"+Dom.dec2hex(3*j)+Dom.dec2hex(3*k)+Dom.dec2hex(3*i);
					var elm = Dom.create("div",{cssFloat:"left",styleFloat:"left",width:"9px",height:"9px",backgroundColor:color,cursor:"crosshair",overflow:"hidden"});
					div.appendChild(elm);
					prepare(elm,color);
				}
				
		
		document.body.appendChild(div);
	}
}
