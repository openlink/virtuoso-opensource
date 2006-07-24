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
	$(something)
	$$(something)
	$v(something)
	
	OAT.Dom.create(tagName,styleObj)
	OAT.Dom.text(text)
	OAT.Dom.option(name,value,parent)
	OAT.Dom.hide(elm)
	OAT.Dom.show(elm)
	OAT.Dom.clear(elm)
	OAT.Dom.unlink(elm)
	OAT.Dom.center(elm,x,y)
	OAT.Dom.isChild(child,parent)
	OAT.Dom.isIE()
	OAT.Dom.isGecko()
	OAT.Dom.isOpera()
	OAT.Dom.isWebKit()
	OAT.Dom.hex2dec(hex_str)
	OAT.Dom.dec2hex(dec_num)
	OAT.Dom.color(str)
	OAT.Dom.isClass(something,className)
	OAT.Dom.addClass(something,className)
	OAT.Dom.removeClass(something,className)
	OAT.Dom.collide(something1,something2)
	OAT.Dom.(at|de)tach(element,event,callback)
	OAT.Dom.source(event)
	OAT.Dom.eventPos(event)
	OAT.Dom.style(element,property)
	OAT.Dom.position(something)	
	OAT.Dom.getLT(something)
	OAT.Dom.getWH(something)
	OAT.Dom.moveBy(element,dx,dy)
	OAT.Dom.resizeBy(element,dx,dy)
	OAT.Dom.getScroll()
	OAT.Dom.decodeImage(data)
	OAT.Dom.dump(element)
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
	if (!("value" in e)) return false;
	return e.value;
}

function $v(something) {
	var e = $(something);
	if (!e) return false;
	if (!("value" in e)) return false;
	return e.value;
}

OAT.Dom = {
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
		var opt = OAT.Dom.create("option");
		opt.innerHTML = name;
		opt.value = value;
		if (parent) { $(parent).appendChild(opt); }
		return opt;
	},
	
	hide:function(element) {
		var elm = $(element);
		/* ie input hack */
		var inputs = elm.getElementsByTagName("input");
		if (elm.tagName.toLowerCase() == "input") { inputs[inputs.length] = elm; }
		for (var i=0;i<inputs.length;i++) {
			var inp = inputs[i];
			if (inp.type == "radio" || inp.type == "checkbox") {
				if (!inp.__checked) { inp.__checked = (inp.checked ? "1" : "0"); }
			}
		} 
		/* */
		elm.style.display = "none";
	},
	
	show:function(element) {
		var elm = $(element);
		elm.style.display = "";
		/* ie input hack */
		var inputs = elm.getElementsByTagName("input");
		if (elm.tagName.toLowerCase() == "input") { inputs[inputs.length] = elm; }
		for (var i=0;i<inputs.length;i++) {
			var inp = inputs[i];
			if (inp.type == "radio" || inp.type == "checkbox") {
				inp.checked = (inp.__checked == "1" ? true : false);
				inp.__checked = false;
			}
		} 
		/* */
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
	
	center:function(element,x,y,reference) {
		var elm = $(element);
		var p = elm.offsetParent;
		if (reference) { p = reference; }
		var par_dims = OAT.Dom.getWH(p);
		var dims = OAT.Dom.getWH(elm);
		var new_x = Math.round(par_dims[0]/2 - dims[0]/2);
		var new_y = Math.round(par_dims[1]/2 - dims[1]/2);
		if (new_y < 0) { new_y = 30; }
		var s = OAT.Dom.getScroll();
		new_x += s[0];
		new_y += s[1];
		if (x) { elm.style.left = new_x + "px"; }
		if (y) { elm.style.top = new_y + "px"; }
	},
	
	isChild:function(child,parent) {
		var c_elm = $(child);
		var p_elm = $(parent);
		/* walk up from the child. if we find parent element, return true */
		var node = c_elm.parentNode;
		do {
			if (node == p_elm) { return true; }
			node = node.parentNode;
		} while (node != document.body && node != document);
		return false;
	},
	
	isIE:function() {
		return (document.attachEvent && !document.addEventListener ? true : false);
	},

	isGecko:function() {
		return (document.addEventListener ? true : false);
	},
	
	isOpera:function() {
		return (navigator.userAgent.match(/Opera/));
	},
	
	isWebKit:function() {
		return (navigator.userAgent.match(/AppleWebKit/));
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
			return [OAT.Dom.hex2dec(tmp[1]),hex2dec(tmp[2]),hex2dec(tmp[3])];
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
		var arr = elm.className.split(" ");
		var index = arr.find(className);
		return (index != -1);
	},
	
	addClass:function(something,className) {
		var elm = $(something);
		if (!elm) { return; }
		if (OAT.Dom.isClass(elm,className)) { return; }
		var arr = elm.className.split(" ");
		arr.push(className);
		if (arr[0] == "") { arr.splice(0,1); }
		elm.className = arr.join(" ");
	},
	
	removeClass:function(something,className) {
		var elm = $(something);
		if (!elm) { return; }
		if (!OAT.Dom.isClass(elm,className)) { return; } /* cannot remove non-existing class */
		if (className == "*") { elm.className = ""; } /* should not occur */
		var arr = elm.className.split(" ");
		var index = arr.find(className);
		if (index == -1) { return; } /* should NOT occur! */
		arr.splice(index,1);
		elm.className = arr.join(" ");
	},
	
	collide:function(something1,something2) {
		/* true if they have someting common */
		var coords_1 = OAT.Dom.position(something1);
		var coords_2 = OAT.Dom.position(something2);
		var dims_1 = OAT.Dom.getWH(something1);
		var dims_2 = OAT.Dom.getWH(something2);
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
	
	eventPos:function(event) {
		if (OAT.Dom.isWebKit()) {
			return [event.clientX,event.clientY];
		} else {
			return [event.clientX+document.documentElement.scrollLeft,event.clientY+document.documentElement.scrollTop];
		}
	},
	
	style:function(elm,property) {
		var element = $(elm);
		if (document.defaultView && document.defaultView.getComputedStyle) {
			var cs = document.defaultView.getComputedStyle(element,'');
			if (!cs) { return true; }
			return cs[property];
		} else {
			return element.currentStyle[property];
		} 
	},
	
	position:function(something) {
		var elm = $(something);
		var parent = elm.offsetParent;
		if (elm == document.body || elm == document || !parent) { return OAT.Dom.getLT(elm); }
		var parent_coords = OAT.Dom.position(parent);
		var c = OAT.Dom.getLT(elm);
		/*
		var x = elm.offsetLeft - elm.scrollLeft + parent_coords[0];
		var y = elm.offsetTop - elm.scrollTop + parent_coords[1];
		*/
		var x = c[0] - elm.scrollLeft;
		var y = c[1] - elm.scrollTop;
		
		if (OAT.Dom.isWebKit() && parent == document.body && OAT.Dom.style(elm,"position") == "absolute") { return [x,y]; }
		
		x += parent_coords[0];
		y += parent_coords[1];
		return [x,y];
	},
	
	getLT:function(something) {
		var elm = $(something);
		var curr_x,curr_y;
		if (elm.style.left && elm.style.position != "relative") {
			curr_x = parseInt(elm.style.left);
		} else {
			curr_x = elm.offsetLeft;
		}
		if (elm.style.top && elm.style.position != "relative") {
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
		if (elm.style.width && !elm.style.width.match(/%/)) { 
			curr_w = parseInt(elm.style.width); 
		} else {
			if (OAT.Dom.isGecko()) { 
				curr_w = parseInt(OAT.Dom.style(elm,"width")); 
				if (elm.tagName.toLowerCase() == "input") { curr_w = curr_w + 5; }
			} else { curr_w = elm.offsetWidth; }
		}
		
		if (elm.style.height && !elm.style.height.match(/%/)) {	
			curr_h = parseInt(elm.style.height); 
		} else {
			if (OAT.Dom.isGecko()) { 
				curr_h = parseInt(OAT.Dom.style(elm,"height")); 
				if (elm.tagName.toLowerCase() == "input") { curr_h = curr_h + 5; }
			} else { curr_h = elm.offsetHeight; }
		}
		
		/* one more bonus - if we are getting height of document.body, take window size */
		if (elm == document.body) { 
			curr_h = (OAT.Dom.isIE() ? document.body.clientHeight : window.innerHeight); 
		}
		return [curr_w,curr_h];
	},
	
	moveBy:function(element,dx,dy) {
		var curr_x,curr_y;
		var elm = $(element);
		/*
			If the element is not anchored to left top corner, strange things will happen during resizing;
			therefore, we need to make sure it is anchored properly.
		*/
		if (OAT.Dom.style(elm,"position") == "absolute") { 
			if (!elm.style.left) {
				elm.style.left = elm.offsetLeft + "px";
				elm.style.right = "";
			}
			if (!elm.style.top) {
				elm.style.top = elm.offsetTop + "px";
				elm.style.bottom = "";
			}
		}
		var tmp = OAT.Dom.getLT(elm);
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
		if (OAT.Dom.style(elm,"position") == "absolute") { 
			if (!elm.style.left) {
				elm.style.left = elm.offsetLeft + "px";
				elm.style.right = "";
			}
			if (!elm.style.top) {
				elm.style.top = elm.offsetTop + "px";
				elm.style.bottom = "";
			}
		}
		var tmp = OAT.Dom.getWH(elm);
		curr_w = tmp[0];
		curr_h = tmp[1];
		var w = curr_w + dx;
		var h = curr_h + dy;
		elm.style.width = w + "px";
		elm.style.height = h + "px"; 
	},
	
	decodeImage:function(data) {
		var decoded = OAT.Crypto.base64d(data);
		var mime = "image/";
		switch (decoded.charAt(1)) {
			case "I": mime += "gif"; break;
			case "P": mime += "png"; break;
			case "M": mime += "bmp"; break;
			default: mime += "jpeg"; break;
			
		}
		var src="data:"+mime+";base64,"+data;
		return src;
	},
	
	getScroll:function() {
		if (OAT.Dom.isWebKit() || OAT.Dom.isIE()) {
			var l = document.body.scrollLeft;
			var t = document.body.scrollTop;
		} else {
			var l = document.documentElement.scrollLeft;
			var t = document.documentElement.scrollTop;
		}
		return [l,t];
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
		
		text += "computed.left: "+OAT.Dom.style(elm,"left")+"\n";
		text += "computed.right: "+OAT.Dom.style(elm,"right")+"\n";
		text += "computed.top: "+OAT.Dom.style(elm,"top")+"\n";
		text += "computed.bottom: "+OAT.Dom.style(elm,"bottom")+"\n";
		text += "computed.width: "+OAT.Dom.style(elm,"width")+"\n";
		text += "computed.height: "+OAT.Dom.style(elm,"height")+"\n\n";

		text += "clientLeft: "+elm.clientLeft+"\n";
		text += "clientRight: "+elm.clientRight+"\n";
		text += "clientTop: "+elm.clientTop+"\n";
		text += "clientBottom: "+elm.clientBottom+"\n";
		text += "clientWidth: "+elm.clientWidth+"\n";
		text += "clientHeight: "+elm.clientHeight+"\n\n";
		
		text += "style.position: "+elm.style.position+"\n";
		text += "computed.position: "+OAT.Dom.style(elm,"position")+"\n";
		alert(text);
	}
}
OAT.Loader.pendingCount--;
