/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2019 OpenLink Software
 *
 *  See LICENSE file for details.
 */

/*
	OAT.SimpleFX.roundImg(something, optObj)
	OAT.SimpleFX.roundDiv(something, optObj)
	OAT.SimpleFX.shadow(something, optObj)
	OAT.SimpleFX.shader(clicker, target, optObj)
*/

OAT.SimpleFX = {
	roundImg:function(something, optObj) {
		var options = {
			corners:[1,1,1,1], /* CW from LT */
			edges:[1,1,1,1], /* CW from T */
			cornerFiles:["lt.gif","rt.gif","rb.gif","lb.gif"],
			edgeFiles:["t.gif","r.gif","b.gif","l.gif"],
			thickness:[16,16,16,16] /* CW from T */
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
				edge.style.height = (i % 2 ? "100%" : options.thickness[i]+"px");
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
		if (OAT.Style.get(elm,"position") == "static") { elm.style.position = "relative"; }
	},

	roundDiv:function(something, optObj) {
		var options = {
			corners:[1,1,1,1], /* CW from LT */
			color:"auto",
			borderColor:"auto",
			backgroundColor:"auto",
			antialias:1,
			size:10
		}
		for (var p in optObj) { options[p] = optObj[p]; }
		var elm = $(something);
		if (OAT.Style.get(elm,"position") == "static") { elm.style.position = "relative"; }
		/* calculate colors */
		var getBG = function(e) {
			var ee = $(e);
			if (!ee || ee == document) { return "#fff"; }
			if (ee.nodeType!=1) /* ie fix */
				if (ee.parentNode) { getBG(ee.parentNode); }
				else { return '#fff'; }
			var bg = OAT.Style.get(ee,"backgroundColor");
			if (bg != "transparent") return bg;
			return getBG(ee.parentNode);
		}
		if (options.color == "auto") { options.color = getBG(elm) ? getBG(elm) : '#fff'; } /* opera fix */
		if (options.backgroundColor == "auto") { options.backgroundColor = getBG(elm.parentNode); }
		/* aacolor */
		var c1 = OAT.Dom.color(options.color);
		var c2 = OAT.Dom.color(options.backgroundColor);
		var aac = [];
		aac.push(parseInt((c1[0]+c2[0])/2));
		aac.push(parseInt((c1[1]+c2[1])/2));
		aac.push(parseInt((c1[2]+c2[2])/2));
		var aacolor = "rgb("+aac.join(",")+")";
		/* prepare margins */
		var margins = [];
		var t = [];
		for (var i = 1;i<options.size;i++) {
			var x = (options.size-i)/options.size;
			var y = Math.sqrt(1-x*x)-1;
			var r = -Math.round(y*options.size);
			if (r) { margins.unshift(r); }
		}
		options.size = margins.length;
		var top = false;
		var bottom = false;
		/* let's go */
		if (options.corners[0] || options.corners[1]) {
			/* top */
			var top = OAT.Dom.create("div",{fontSize:"1px",position:"absolute",width:"100%",left:"0px",height:options.size+"px",top:(-options.size)+"px"});
			for (var i=options.size-1;i>=0;i--) {
				var d = OAT.Dom.create("div",{height:"1px",fontSize:"1px",overflow:"hidden",backgroundColor:options.color});
				/* trick for rounded border */
				var marginOffset = 0;
				if (!options.antialias && parseInt(OAT.Style.get(elm,"borderTopWidth"))) {
					var bc = OAT.Style.get(elm,"borderTopColor");
					if (i==options.size-1) { d.style.backgroundColor = bc; }
					aacolor = bc;
					marginOffset = 1;
					var aas = i < options.size-1 ? margins[i+1] - margins[i] : 1; /* antialias size */
					aas = aas ? aas : 1;
				} else {
					var aas = i > 0 ? margins[i] - margins[i-1] : 1; /* antialias size */
					aas = aas ? aas : 1;
					aas = options.antialias ? aas : 0;
					marginOffset = aas;
				}
				if (options.corners[0]) {
					d.style.marginLeft = (margins[i]-marginOffset)+"px";
					d.style.borderLeft = aas+"px solid "+aacolor;
				}
				if (options.corners[1]) {
					d.style.marginRight = (margins[i]-marginOffset)+"px";
					d.style.borderRight = aas+"px solid "+aacolor;
				}
				top.appendChild(d);
			}
			top.firstChild.style.backgroundColor = options.borderColor;
			(elm.firstChild ? elm.insertBefore(top,elm.firstChild) : elm.appendChild(top));
		}
		if (options.corners[2] || options.corners[3]) {
			/* bottom */
			var bottom = OAT.Dom.create("div",{fontSize:"1px",position:"absolute",width:"100%",left:"0px",height:options.size+"px",bottom:(-options.size)+"px"});
			for (var i=0;i<options.size;i++) {
				var d = OAT.Dom.create("div",{height:"1px",fontSize:"1px",overflow:"hidden",backgroundColor:options.color});
				var aas = i > 0 ? margins[i] - margins[i-1] : 1; /* antialias size */
				aas = aas ? aas : 1;
				/* trick for rounded border */
				var marginOffset = 0;
				if (!options.antialias && parseInt(OAT.Style.get(elm,"borderTopWidth"))) {
					var bc = OAT.Style.get(elm,"borderTopColor");
					if (i==options.size-1) { d.style.backgroundColor = bc; }
					aacolor = bc;
					marginOffset = 1;
					var aas = i < options.size-1 ? margins[i+1] - margins[i] : 1; /* antialias size */
					aas = aas ? aas : 1;
				} else {
					var aas = i > 0 ? margins[i] - margins[i-1] : 1; /* antialias size */
					aas = aas ? aas : 1;
					aas = options.antialias ? aas : 0;
					marginOffset = aas;
				}
				if (options.corners[3]) {
					d.style.marginLeft = (margins[i]-marginOffset)+"px";
					d.style.borderLeft = aas+"px solid "+aacolor;
				}
				if (options.corners[2]) {
					d.style.marginRight = (margins[i]-marginOffset)+"px";
					d.style.borderRight = aas+"px solid "+aacolor;
				}
				bottom.appendChild(d);
			}
			bottom.lastChild.style.backgroundColor = options.borderColor;
			elm.appendChild(bottom);
		}

		if (!options.antialias && parseInt(OAT.Style.get(elm,"borderTopWidth"))) {
			elm.style.borderWidth = "0px 1px";
			elm.style.borderStyle = "solid";
		}
		return [top,bottom]
	},

	shadow:function(something, optObj) {
		var options = {
			imagePath:OAT.Preferences.imagePath,
			offsetX:0,
			offsetY:0,
			bottomSize:8,
			rightSize:8,
			bottomImage:"shadow_bottom.png",
			rightImage:"shadow_right.png",
			cornerImage:"shadow_corner.png"
		}
		for (var p in optObj) { options[p] = optObj[p]; }
		var elm = $(something);
		if (elm.shadows) { return; }
		var b = OAT.Dom.create("div",{position:"absolute",fontSize:"1px"});
		b.style.width = "100%";
		b.style.right = (-options.offsetX)+"px";
		b.style.height = options.bottomSize+"px";
		b.style.bottom = (-options.bottomSize-options.offsetY)+"px";
		OAT.Style.background(b,options.imagePath+options.bottomImage);

		var r = OAT.Dom.create("div",{position:"absolute",fontSize:"1px"});
		r.style.bottom = (-options.offsetY)+"px";
		r.style.width = options.rightSize+"px";
		r.style.right = (-options.rightSize-options.offsetX)+"px";
		r.style.height = "100%";
		OAT.Style.background(r,options.imagePath+options.rightImage);

		var c = OAT.Dom.create("div",{position:"absolute",fontSize:"1px"});
		c.style.bottom = (-options.bottomSize-options.offsetY)+"px";
		c.style.right = (-options.rightSize-options.offsetX)+"px";
		c.style.width = options.rightSize+"px";
		c.style.height = options.bottomSize+"px";
		OAT.Style.background(c,options.imagePath+options.cornerImage);

		elm.appendChild(b);
		elm.appendChild(r);
		elm.appendChild(c);
		if (OAT.Style.get(elm,"position") == "static") { elm.style.position = "relative"; }

		elm.shadows = [b,r,c];
	},

	shadowRemove:function(something) {
		var elm = $(something);
		if (elm.shadows) {
			for (var i=0;i<elm.shadows.length;i++) { OAT.Dom.unlink(elm.shadows[i]); }
		}
		elm.shadows = false;
	},

	shader:function(clicker,target,optObj) {
		var elm1 = $(clicker);
		var elm2 = $(target);
		if (!(elm2 instanceof Array)) { elm2 = [elm2]; }
		var options = {
			initialState:1,
			mode:2, /* 0 - hide, 1 - fade out, 2 - both */
			type:2 /* 0 - hide, 1 - show, 2 - both */

		}
		for (var p in optObj) { options[p] = optObj[p]; }
		for (var i=0;i<elm2.length;i++) {
			elm2[i].__shaderState = options.initialState;
		}
		var ref = function(elm) {
			if (options.type == 0 && elm.__shaderState == 0) { return; }
			if (options.type == 1 && elm.__shaderState == 1) { return; }
			if (elm.__shaderState) {
				var dims = OAT.Dom.getWH(elm);
				elm.__origW = dims[0];
				elm.__origH = dims[1];
				var a1 = OAT.AnimationOpacity(elm,{opacity:0,delay:5});
				var a2 = OAT.AnimationSize(elm,{width:0,height:0,speed:10,delay:2});
				var sf = function() {OAT.Dom.hide(elm);}
				OAT.MSG.attach(a2.animation,"ANIMATION_STOP",sf);
			} else {
				var orig_w = elm.__origW;
				var orig_h = elm.__origH;
				if (!orig_w || !orig_h) { alert("OAT.SimpleFX.shader:\nCannot restore element which was initially hidden!"); }
				OAT.Dom.show(elm);
				var a1 = OAT.AnimationOpacity(elm,{opacity:1,delay:5});
				var a2 = OAT.AnimationSize(elm,{width:orig_w,height:orig_h,speed:10,delay:2});
				var sf = function() {elm.style.width = elm.__origW+"px"; elm.style.height = elm.__origH+"px"; OAT.Dom.show(elm); }
				OAT.MSG.attach(a2.animation,"ANIMATION_STOP",sf);
			}
			elm.__shaderState++;
			if (elm.__shaderState == 2) { elm.__shaderState = 0; }
			a1.start();
			a2.start();
		}
		OAT.Event.attach(elm1,"click",function(){
			for (var i=0;i<elm2.length;i++) {
				var elm = elm2[i];
				ref(elm);
			} /* for all targets */
		});
	}
}
