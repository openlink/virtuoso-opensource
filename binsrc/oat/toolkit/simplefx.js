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
	OAT.SimpleFX.round(something, optObj)
	OAT.SimpleFX.shadow(something, optObj)
*/ 
 
OAT.SimpleFX = {
	round:function(something, optObj) {
		var options = {
			corners:[1,1,1,1], /* CW from LT */
			edges:[1,1,1,1], /* CW from T */
			cornerFiles:["lt.gif","rt.gif","rb.gif","lb.gif"],
			edgeFiles:["t.gif","r.gif","b.gif","l.gif"],
			thickness:[15,15,15,15], /* CW from T */
			ieElm:false /* ie height fix */
		}
		for (var p in optObj) { options[p] = optObj[p]; }
		var elm = $(something);
		var cornerElms = [];
		var edgeElms = [];
		

		for (var i=0;i<4;i++) {
			if (options.corners[i]) {
				var corner = OAT.Dom.create("div",{position:"absolute",fontSize:"1px"});
				corner.style.backgroundImage = "url("+options.cornerFiles[i]+")";
				var w = options.thickness[i % 3 ? 1 : 3];
				var h = options.thickness[i > 1 ? 2 : 0];
				corner.style.width = w+"px";
				corner.style.height = h+"px";
				corner.style[i % 3 ? "right" : "left"] = (-w)+"px";
				corner.style[i > 1 ? "bottom" : "top"] = (-h)+"px";
				cornerElms.push(corner);
			}
		}
		
		var dirArr = ["top","right","bottom","left"];
		for (var i=0;i<4;i++) {
			if (options.edges[i]) {
				var edge = OAT.Dom.create("div",{position:"absolute",fontSize:"1px"});
				edge.style.backgroundImage = "url("+options.edgeFiles[i]+")";
				edge.style.width = (i % 2 ? options.thickness[i]+"px" : "100%");
				/* ie hack */
				edge.style.height = (i % 2 ? "100%" : options.thickness[i]+"px");
				if (OAT.Dom.isIE() && (i % 2)) {
					edge.style.height = "";
					edge.ieHeight = options.ieElm;
					edge.className += " ie_height_fix";
				}
				edge.style[i % 2 ? "top" : "left"] = "0px";
				edge.style[dirArr[i]] = (-options.thickness[i])+"px";
				edgeElms.push(edge);
			}
		}
		
		function add(e) {
			if (elm.firstChild) {
				elm.insertBefore(e,elm.firstChild);
			} else {
				elm.appendChild(e);
			}
		}

		for (var i=0;i<cornerElms.length;i++) { add(cornerElms[i]); }
		for (var i=0;i<edgeElms.length;i++) { add(edgeElms[i]); }
		
		elm.cornerElms = cornerElms;
		elm.edgeElms = edgeElms;
		if (OAT.Dom.style(elm,"position") == "static") { elm.style.position = "relative"; }
	},
	
	shadow:function(something, optObj) {
		var options = {
			imagePath:"/DAV/JS/images/",
			offsetX:0,
			offsetY:0,
			bottomSize:8,
			rightSize:8,
			bottomImage:"shadow_bottom.png",
			rightImage:"shadow_right.png",
			cornerImage:"shadow_corner.png",
			ieElm:false
		}
		for (var p in optObj) { options[p] = optObj[p]; }
		var elm = $(something);
		if (elm.shadows) { return; }
		var b = OAT.Dom.create("div",{position:"absolute",fontSize:"1px"});
		b.style.width = "100%";
		b.style.right = (-options.offsetX)+"px";
		b.style.height = options.bottomSize+"px";
		b.style.bottom = (-options.bottomSize-options.offsetY)+"px";
		if (OAT.Dom.isIE()) {
			b.style.filter = "progid:DXImageTransform.Microsoft.AlphaImageLoader(src='"+options.imagePath+options.bottomImage+"', sizingMethod='crop')";
		} else {
			b.style.backgroundImage="url("+options.imagePath+options.bottomImage+")";
		}
		
		var r = OAT.Dom.create("div",{position:"absolute",fontSize:"1px"});
		r.style.bottom = (-options.offsetY)+"px";
		r.style.width = options.rightSize+"px";
		r.style.right = (-options.rightSize-options.offsetX)+"px";
		if (OAT.Dom.isIE()) {
			r.style.filter = "progid:DXImageTransform.Microsoft.AlphaImageLoader(src='"+options.imagePath+options.rightImage+"', sizingMethod='crop')";
			r.ieHeight = options.ieElm;
			r.className += " ie_height_fix";
		} else {
			r.style.height="100%";
			r.style.backgroundImage="url("+options.imagePath+options.rightImage+")";
		}
		
		var c = OAT.Dom.create("div",{position:"absolute",fontSize:"1px"});
		c.style.bottom = (-options.bottomSize-options.offsetY)+"px";
		c.style.right = (-options.rightSize-options.offsetX)+"px";
		c.style.width = options.rightSize+"px";
		c.style.height = options.bottomSize+"px";
		if (OAT.Dom.isIE()) {
			c.style.filter = "progid:DXImageTransform.Microsoft.AlphaImageLoader(src='"+options.imagePath+options.cornerImage+"', sizingMethod='crop')";
		} else {
			c.style.backgroundImage="url("+options.imagePath+options.cornerImage+")";
		}

		elm.appendChild(b);
		elm.appendChild(r);
		elm.appendChild(c);
		if (OAT.Dom.style(elm,"position") == "static") { elm.style.position = "relative"; }
		
		elm.shadows = [b,r,c];
	},
	
	shadowRemove:function(something) {
		var elm = $(something);
		if (elm.shadows) {
			for (var i=0;i<elm.shadows.length;i++) { OAT.Dom.unlink(elm.shadows[i]); }
		}
		elm.shadows = false;
	}
}
OAT.Loader.pendingCount--;
