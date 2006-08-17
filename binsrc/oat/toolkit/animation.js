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
	a = new OAT.Animation(animationStructure,delay)
	Animation.endFunction = function(){}
	a.start()
	a.stop()

	OAT.AnimationData.FADEIN
	OAT.AnimationData.FADEOUT
	OAT.AnimationData.RESIZE
	OAT.AnimationData.MOVE
	
	var animationStructure = OAT.AnimationStructure.generate(something,type,paramsObj)
	OR
	var animationStructure = [conditionFunction, initialFunction, stepFunction]
	
	
*/

OAT.AnimationData = {
	FADEIN:1,
	FADEOUT:2,
	RESIZE:3,
	MOVE:4
}

OAT.Animation = function(animationStructure,delay) { 
	this.running = 0;
	this.endFunction = function() {}
	this.delay = delay;
	this.conditionFunction = animationStructure[0];
	this.initialFunction = animationStructure[1];
	this.stepFunction = animationStructure[2];
	
	this.step = function() {
		var obj = this;
		var callback = function() {
			if (!obj.running) return;
			if (obj.conditionFunction()) {
				obj.running = 0;
				obj.endFunction();
			} else {
				obj.stepFunction();
				obj.step();
			}
		} /* callback */
		setTimeout(callback,this.delay);
	}
	
	this.start = function() {
		this.running = 1;
		this.initialFunction();
		this.step();
	}
	
	this.stop = function() {
		this.running = 0;
	}
	
}

OAT.AnimationStructure = {
	generate:function(something,type,paramsObj) {
		var elm = $(something);
		var condRef = function() {}
		var initRef = function() {}
		var stepRef = function() {}
		
		switch (type) {
			case OAT.AnimationData.FADEIN:
				var max = ("max" in paramsObj ? paramsObj.max : 1);
				var step = ("step" in paramsObj ? paramsObj.step : 0.05);
				initRef = function() { 
					if (OAT.Dom.isGecko()) { elm._Animation_opacity = parseFloat(OAT.Dom.style(elm,"opacity")); }
					if (OAT.Dom.isIE()) { 
						elm._Animation_opacity = 1;
						var filter = OAT.Dom.style(elm,"filter"); 
						var num = filter.match(/alpha\(opacity=([^\)]+)\)/);
						if (num) { elm._Animation_opacity = parseFloat(num[1])/100; }
					} /* is ie */
				}
				condRef = function() { return elm._Animation_opacity >= max; }
				stepRef = function() {
					elm._Animation_opacity += step;
					elm.style.opacity = elm._Animation_opacity;
					elm.style.filter = "alpha(opacity="+Math.round(100*elm._Animation_opacity)+")";
				}
			break;
			
			case OAT.AnimationData.FADEOUT:
				var min = ("min" in paramsObj ? paramsObj.min : 0);
				var step = ("step" in paramsObj ? paramsObj.step : 0.05);
				initRef = function() { 
					if (OAT.Dom.isGecko()) { elm._Animation_opacity = parseFloat(OAT.Dom.style(elm,"opacity")); }
					if (OAT.Dom.isIE()) { 
						elm._Animation_opacity = 1;
						var filter = OAT.Dom.style(elm,"filter"); 
						var num = filter.match(/alpha\(opacity=([^\)]+)\)/);
						if (num) { elm._Animation_opacity = parseFloat(num[1])/100; }
					} /* is ie */
				}
				condRef = function() { return elm._Animation_opacity <= min; }
				stepRef = function() { 
					elm._Animation_opacity -= step;
					if (elm._Animation_opacity < 0) { elm._Animation_opacity = 0; }
					elm.style.opacity = elm._Animation_opacity;
					elm.style.filter = "alpha(opacity="+Math.round(100*elm._Animation_opacity)+")";
				}
			break;
			
			case OAT.AnimationData.RESIZE:
				var w = ("w" in paramsObj ? paramsObj.w : 100);
				var h = ("h" in paramsObj ? paramsObj.h : 100);
				var dist = ("dist" in paramsObj ? paramsObj.dist : 1); /* diagonal distance per step */
				initRef = function() { 
					elm._Animation_real_w = elm.offsetWidth;
					elm._Animation_real_h = elm.offsetHeight;
					var dx = w - elm.offsetWidth;
					var dy = h - elm.offsetHeight;
					var sign_x = (dx >= 0 ? 1 : -1);
					var sign_y = (dy >= 0 ? 1 : -1);
					elm._Animation_step_w = sign_x * Math.sqrt( dist * dist * dx * dx / (dx*dx + dy*dy) );
					elm._Animation_step_h = sign_y * Math.sqrt( dist * dist * dy * dy / (dx*dx + dy*dy) );
					elm._Animation_sign_x = sign_x;
					elm._Animation_sign_y = sign_y;
				}
				condRef = function() { 
					var ok_w = (elm._Animation_sign_x > 0 ? elm._Animation_real_w >= w : elm._Animation_real_w <= w);
					var ok_h = (elm._Animation_sign_y > 0 ? elm._Animation_real_h >= h : elm._Animation_real_h <= h);
					return (ok_w && ok_h);
				}
				stepRef = function() {
					elm._Animation_real_w += elm._Animation_step_w;
					elm._Animation_real_h += elm._Animation_step_h;
					var iw = parseInt(elm._Animation_real_w);
					var ih = parseInt(elm._Animation_real_h);
					elm.style.width = (iw >= 0 ? iw : 0) + "px";
					elm.style.height = (ih >= 0 ? ih : 0) + "px";
				}
			break;

			case OAT.AnimationData.MOVE:
				var x = ("x" in paramsObj ? paramsObj.x : 100);
				var y = ("y" in paramsObj ? paramsObj.y : 100);
				var dist = ("dist" in paramsObj ? paramsObj.dist : 1); /* diagonal distance */
				var tol = ("tol" in paramsObj ? paramsObj.tol : 1); /* tolerance */
				initRef = function() { 
					elm._Animation_real_x = elm.offsetLeft;
					elm._Animation_real_y = elm.offsetTop;
					var dx = x - elm.offsetLeft;
					var dy = y - elm.offsetTop;
					var sign_x = (dx >= 0 ? 1 : -1);
					var sign_y = (dy >= 0 ? 1 : -1);
					elm._Animation_step_x = sign_x * Math.sqrt( dist * dist * dx * dx / (dx*dx + dy*dy) );
					elm._Animation_step_y = sign_y * Math.sqrt( dist * dist * dy * dy / (dx*dx + dy*dy) );
				}
				condRef = function() { 
					return (Math.abs(elm.offsetLeft - x) <= tol && Math.abs(elm.offsetTop - y) <= tol);
				}
				stepRef = function() {
					elm._Animation_real_x += elm._Animation_step_x;
					elm._Animation_real_y += elm._Animation_step_y;
					elm.style.left = parseInt(elm._Animation_real_x) + "px";
					elm.style.top = parseInt(elm._Animation_real_y) + "px";
				}
			break;

			} /* switch */
		return [condRef,initRef,stepRef];
	} /* generate */
}
OAT.Loader.pendingCount--;
