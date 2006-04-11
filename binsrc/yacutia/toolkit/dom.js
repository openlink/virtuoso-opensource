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
	$(something)
	$$(something)
	$v(something)
	
	Dom.create(tagName,styleObj)
	Dom.text(text)
	Dom.option(name,value,parent)
	Dom.hide(elm)
	Dom.show(elm)
	Dom.clear(elm)
	Dom.unlink(elm)
	Dom.center(elm,x,y)
	Dom.isChild(child,parent)
	Dom.isIE()
	Dom.isGecko()
	Dom.isOpera()
	Dom.hex2dec(hex_str)
	Dom.dec2hex(dec_num)
	Dom.color(str)
	Dom.isClass(something,className)
	Dom.collide(something1,something2)
	Dom.(at|de)tach(element,event,callback)
	Dom.source(event)
	Dom.style(element,property)
	Dom.position(something)	
	Dom.getLT(something)
	Dom.getWH(something)
	Dom.moveBy(element,dx,dy)
	Dom.resizeBy(element,dx,dy)
	Dom.dump(element)
*/

function $(something) {
	if (typeof(something) == "string") {
		var elm = document.getElementById(something);
	} else {
		var elm = something;
	}
	if (!elm) return false;
	return elm;
}

function $$(something) {
	var e = $(something);
	if (!e) return false;
	if (!e.value) return false;
	return e.value;
}

function $v(something) {
	var e = $(something);
	if (!e) return false;
	if (!e.value) return false;
	return e.value;
}

var Dom = {
	create:function(tagName,styleObj) {	
		var elm = document.createElement(tagName);
		if (styleObj) {
			for (prop in styleObj) { elm.style[prop] = styleObj[prop]; }
		}
		return elm;
	},
	
	text:function(text) {
		var elm = document.createTextNode(text);
		return elm;
	},
	
	option:function(name,value,parent) {
		var opt = Dom.create("option");
		opt.innerHTML = name;
		opt.value = value;
		if (parent) { $(parent).appendChild(opt); }
		return opt;
	},
	
	hide:function(element) {
		var elm = $(element);
//		elm.style.visibility = "hidden";
		elm.style.display = "none";
	},
	
	show:function(element) {
		var elm = $(element);
//		elm.style.visibility = "visible";
		elm.style.display = "";
	},

	clear:function(element) {
		var elm = $(element);
		while (elm.firstChild) { elm.removeChild(elm.firstChild); }
	},
	
	unlink:function(element) {
		var elm = $(element);
		if (!elm) { return; }
		elm.parentNode.removeChild(elm);
	},
	
	center:function(element,x,y) {
		var elm = $(element);
		var par_dims = Dom.getWH(elm.offsetParent);
		var dims = Dom.getWH(elm);
		var new_x = Math.round(par_dims[0]/2 - dims[0]/2);
		var new_y = Math.round(par_dims[1]/2 - dims[1]/2);
		if (x) { elm.style.left = new_x + "px"; }
		if (y) { elm.style.top = new_y + "px"; }
	},
	
	isChild:function(child,parent) {
		var c_elm = $(child);
		var p_elm = $(parent);
		/* walk up from the child. if we find parent element, return true */
		var node = c_elm;
		do {
			if (node == p_elm) { return true; }
			node = node.parentNode;
		} while (node != document.body && node != document);
		return false;
	},
	
	isIE:function() {
		return (document.attachEvent ? true : false);
	},

	isGecko:function() {
		return (document.addEventListener ? true : false);
	},
	
	isOpera:function() {
		return (true);
	},

	hex2dec:function(hex_str) {
		return parseInt(hex_str,16);
	},
	
	dec2hex:function(num) {
		var hex = ["0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"];
		return hex[num];
	},
	
	color:function(str) {
		/* returns [col1,col2,col3] in decimal */
		if (str.match(/#/)) {
			/* hex */
			if (str.length == 4) {
				var tmpstr = "#"+str.charAt(1)+str.charAt(1)+str.charAt(2)+str.charAt(2)+str.charAt(3)+str.charAt(3);
			} else {
				var tmpstr = str;
			}
			var tmp = tmpstr.match(/#(..)(..)(..)/);
			return [Dom.hex2dec(tmp[1]),hex2dec(tmp[2]),hex2dec(tmp[3])];
		} else {
			/* decimal */
			var tmp = str.match(/\(([^,]*),([^,]*),([^\)]*)/);
			return [parseInt(tmp[1]),parseInt(tmp[2]),parseInt(tmp[3])];
		}
	},
	
	isClass:function(something,className) {
		var elm = $(something);
		if (!elm) { return false; }
		if (className == "*") { return true; }
		if (className == "") { return false; }
		if (!elm.className) { return false; }
		var c = elm.className.split(" ");
		for (var i=0;i<c.length;i++) if (c[i]==className) { return true; }
		return false;
	},
	
	collide:function(something1,something2) {
		/* true if they have someting common */
		var coords_1 = Dom.position(something1);
		var coords_2 = Dom.position(something2);
		var dims_1 = Dom.getWH(something1);
		var dims_2 = Dom.getWH(something2);
		var bad_x = ( (coords_1[0] < coords_2[0] && coords_1[0]+dims_1[0] < coords_2[0]) || (coords_1[0] > coords_2[0] + dims_2[0]) );
		var bad_y = ( (coords_1[1] < coords_2[1] && coords_1[1]+dims_1[1] < coords_2[1]) || (coords_1[1] > coords_2[1] + dims_2[1]) );
		return !(bad_x || bad_y);
	},
	
	attach:function(elm,event,callback) {
		var element = $(elm);
		if (element.addEventListener) {
			/* gecko */
			element.addEventListener(event,callback,false);
		} else if (element.attachEvent) {
			/* ie */
			element.attachEvent("on"+event,callback);
		} else {
			/* ??? */
			element["on"+event] = callback;
		}
	},
	
	detach:function(elm,event,callback) {
		var element = $(elm);
		if (element.removeEventListener) {
			/* gecko */
			element.removeEventListener(event,callback,false);
		} else if (element.detachEvent) {
			/* ie */
			element.detachEvent("on"+event,callback);
		} else {
			/* ??? */
			element["on"+event] = false;
		}
	},

	source:function(event) {
		return (event.target ? event.target : event.srcElement);
	},
	
	style:function(elm,property) {
		var element = $(elm);
		if (document.defaultView && document.defaultView.getComputedStyle) {
			return document.defaultView.getComputedStyle(element,'')[property];
		} else {
			return element.currentStyle[property];
		} 
	},
	
	position:function(something) {
		var elm = $(something);
		var parent = elm.offsetParent;
		if (elm == document.body || elm == document || !parent) return [0,0];
		var parent_coords = Dom.position(parent);
		var x = elm.offsetLeft - elm.scrollLeft + parent_coords[0];
		var y = elm.offsetTop - elm.scrollTop + parent_coords[1];
		return [x,y];
	},
	
	getLT:function(something) {
		var elm = $(something);
		var curr_x,curr_y;
		if (elm.style.left) {
			curr_x = parseInt(elm.style.left);
		} else {
			curr_x = elm.offsetLeft;
		}
		if (elm.style.top) {
			curr_y = parseInt(elm.style.top);
		} else {
			curr_y = elm.offsetTop;
		}
		return [curr_x,curr_y];
	},
		
	
	getWH:function(something) {
		/*
			This is tricky: we need to measure current element's width & height.
			If this property was already set (thus available directly throught elm.style),
			everything is ok.
			If nothing was set yet:
				* IE stores this information in offsetWidth and offsetHeight
				* Gecko doesn't count borders into offsetWidth and offsetHeight
			Thus, we need another means for counting real dimensions.
		*/
		var curr_w, curr_h;
		var elm = $(something);
		if (elm.style.width) { curr_w = parseInt(elm.style.width); } else {
			if (Dom.isGecko()) { 
				curr_w = parseInt(Dom.style(elm,"width")); 
				if (elm.tagName.toLowerCase() == "input") { curr_w = curr_w + 5; }
			} else { curr_w = elm.offsetWidth; }
		}
		
		if (elm.style.height) {	curr_h = parseInt(elm.style.height); } else {
			if (Dom.isGecko()) { 
				curr_h = parseInt(Dom.style(elm,"height")); 
				if (elm.tagName.toLowerCase() == "input") { curr_h = curr_h + 5; }
			} else { curr_h = elm.offsetHeight; }
		}
		
		/* one more bonus - if we are getting height of document.body, take window size */
		if (elm == document.body) { 
			curr_h = (Dom.isIE() ? document.body.clientHeight : window.innerHeight); 
		}
		return [curr_w,curr_h];
	},
	
	moveBy:function(element,dx,dy) {
		var curr_x,curr_y;
		var elm = $(element);
		var tmp = Dom.getLT(elm);
		curr_x = tmp[0];
		curr_y = tmp[1];
		var x = curr_x + dx;
		var y = curr_y + dy;
		elm.style.left = x + "px";
		elm.style.top = y + "px";
	},
	
	resizeBy:function(element,dx,dy) {
		var curr_w, curr_h;
		var elm = $(element);
		/*
			If the element is not anchored to left top corner, strange things will happen during resizing;
			therefore, we need to make sure it is anchored properly.
		*/
		if (Dom.style(elm,"position") == "absolute") { 
			if (!elm.style.left) {
				elm.style.left = elm.offsetLeft + "px";
			}
			if (!elm.style.top) {
				elm.style.top = elm.offsetTop + "px";
			}
		}
		var tmp = Dom.getWH(elm);
		curr_w = tmp[0];
		curr_h = tmp[1];
		var w = curr_w + dx;
		var h = curr_h + dy;
		elm.style.width = w + "px";
		elm.style.height = h + "px"; 
	},
	
	base64e:function(input) {
		var keyStr = "ABCDEFGHIJKLMNOP" +
                "QRSTUVWXYZabcdef" +
                "ghijklmnopqrstuv" +
                "wxyz0123456789+/" +
                "=";
		var output = "";
		var chr1, chr2, chr3 = "";
		var enc1, enc2, enc3, enc4 = "";
		var i = 0;

		do {
			chr1 = input.charCodeAt(i++);
			chr2 = input.charCodeAt(i++);
			chr3 = input.charCodeAt(i++);

			enc1 = chr1 >> 2;
			enc2 = ((chr1 & 3) << 4) | (chr2 >> 4);
			enc3 = ((chr2 & 15) << 2) | (chr3 >> 6);
			enc4 = chr3 & 63;

			if (isNaN(chr2)) {
				enc3 = enc4 = 64;
			} else if (isNaN(chr3)) {
				enc4 = 64;
			}

			output = output + 
			keyStr.charAt(enc1) + 
			keyStr.charAt(enc2) + 
			keyStr.charAt(enc3) + 
			keyStr.charAt(enc4);
			chr1 = chr2 = chr3 = "";
			enc1 = enc2 = enc3 = enc4 = "";
		} while (i < input.length);
		return output;
	},
	
	base64d:function(input) {
		var keyStr = "ABCDEFGHIJKLMNOP" +
                "QRSTUVWXYZabcdef" +
                "ghijklmnopqrstuv" +
                "wxyz0123456789+/" +
                "=";
		var output = "";
		var chr1, chr2, chr3 = "";
		var enc1, enc2, enc3, enc4 = "";
		var i = 0;

		// remove all characters that are not A-Z, a-z, 0-9, +, /, or =
		var base64test = /[^A-Za-z0-9\+\/\=]/g;
		if (base64test.exec(input)) {
			alert("There were invalid base64 characters in the input text.\n" +
			"Valid base64 characters are A-Z, a-z, 0-9, '+', '/', and '='\n" +
			"Expect errors in decoding.");
		}
		input = input.replace(/[^A-Za-z0-9\+\/\=]/g, "");

		do {
			enc1 = keyStr.indexOf(input.charAt(i++));
			enc2 = keyStr.indexOf(input.charAt(i++));
			enc3 = keyStr.indexOf(input.charAt(i++));
			enc4 = keyStr.indexOf(input.charAt(i++));

			chr1 = (enc1 << 2) | (enc2 >> 4);
			chr2 = ((enc2 & 15) << 4) | (enc3 >> 2);
			chr3 = ((enc3 & 3) << 6) | enc4;

			output = output + String.fromCharCode(chr1);

			if (enc3 != 64) { output = output + String.fromCharCode(chr2); }
			if (enc4 != 64) { output = output + String.fromCharCode(chr3); }

			chr1 = chr2 = chr3 = "";
			enc1 = enc2 = enc3 = enc4 = "";

		} while (i < input.length);

		return output;
	},
	
	dump:function(element) {
		var elm = $(element);
		var text = "";
		text += "style.left: "+elm.style.left+"\n";
		text += "style.right: "+elm.style.right+"\n";
		text += "style.top: "+elm.style.top+"\n";
		text += "style.bottom: "+elm.style.bottom+"\n";
		text += "style.width: "+elm.style.width+"\n";
		text += "style.height: "+elm.style.height+"\n\n";
		
		text += "offsetLeft: "+elm.offsetLeft+"\n";
		text += "offsetRight: "+elm.offsetRight+"\n";
		text += "offsetTop: "+elm.offsetTop+"\n";
		text += "offsetBottom: "+elm.offsetBottom+"\n";
		text += "offsetWidth: "+elm.offsetWidth+"\n";
		text += "offsetHeight: "+elm.offsetHeight+"\n\n";
		
		text += "computed.left: "+Dom.style(elm,"left")+"\n";
		text += "computed.right: "+Dom.style(elm,"right")+"\n";
		text += "computed.top: "+Dom.style(elm,"top")+"\n";
		text += "computed.bottom: "+Dom.style(elm,"bottom")+"\n";
		text += "computed.width: "+Dom.style(elm,"width")+"\n";
		text += "computed.height: "+Dom.style(elm,"height")+"\n\n";

		text += "clientLeft: "+elm.clientLeft+"\n";
		text += "clientRight: "+elm.clientRight+"\n";
		text += "clientTop: "+elm.clientTop+"\n";
		text += "clientBottom: "+elm.clientBottom+"\n";
		text += "clientWidth: "+elm.clientWidth+"\n";
		text += "clientHeight: "+elm.clientHeight+"\n\n";
		
		text += "style.position: "+elm.style.position+"\n";
		text += "computed.position: "+Dom.style(elm,"position")+"\n";
		alert(text);
	}

}
