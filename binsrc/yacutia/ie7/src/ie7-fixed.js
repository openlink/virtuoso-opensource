/*
	W3C compliance for Microsoft Internet Explorer

	this module forms part of IE7
	IE7 version 0.7.3 (alpha) 2004/09/18
	by Dean Edwards, 2004
*/
if (window.IE7) IE7.addModule("ie7-fixed", function() {
	// some things to consider for this hack.
	// the document body requires a fixed background. even if
	//  it is just a blank image.
	// you have to use setExpression instead of onscroll, this
	//  together with a fixed body background help avoid the
	//  annoying screen flicker of other solutions.

	var PERCENT = /^\d+%$/;

	CSSFixes.addRecalc("position\\s*:\\s*fixed", positionFixed);
	CSSFixes.addRecalc("background[\\w\\s-]*:[^};]*fixed", backgroundFixed);

	// scrolling is relative to the documentElement (HTML tag) when in
	//  standards mode, otherwise it's relative to the document body
	var body = document.body;
	var viewport$ = (quirksMode) ? "body" : "documentElement";
	var viewport = eval(viewport$);

	function fixBackground() {
		// this is requied by both position:fixed and background-attachment:fixed.
		// it is necessary for the document to also have a fixed background image.
		// we can fake this with a blank image if necessary
		if (body.currentStyle.backgroundAttachment != "fixed") {
			if (body.currentStyle.backgroundImage == "none") {
				body.runtimeStyle.backgroundImage = "url(" + location.protocol + ")"; // dummy
			}
			body.runtimeStyle.backgroundAttachment = "fixed";
		}
		fixBackground = DUMMY;
	};


	var ie7_tmp = tmpElement("img");

	// clone a "left" function to create a "top" function
	function topFunction(leftFunction) {
		return String(leftFunction)
		.replace(/Left/g, "Top")
		.replace(/left/g, "top")
		.replace(/Width/g, "Height")
		.replace(/X/g, "Y");
	};

// -----------------------------------------------------------------------
//  backgroundAttachment: fixed
// -----------------------------------------------------------------------

	function backgroundFixed(element) {
		if (element.currentStyle.backgroundAttachment != "fixed") return;
		if (!element.contains(body)) {
			fixBackground();
			backgroundFixed[backgroundFixed.count++] = element;
			backgroundLeft(element);
			backgroundTop(element);
			backgroundPosition(element);
		}
	};
	backgroundFixed.count = 0;

	function backgroundPosition(element) {
		ie7_tmp.src = element.currentStyle.backgroundImage.slice(5, -2);
		var parentElement = (element.canHaveChildren) ? element : element.parentElement;
		parentElement.appendChild(ie7_tmp);
		setOffsetLeft(element);
		setOffsetTop(element);
		parentElement.removeChild(ie7_tmp);
	};

	function backgroundLeft(element) {
		element.style.backgroundPositionX = element.currentStyle.backgroundPositionX;
		if (!isFixed(element)) {
			var expression = "(parseInt(runtimeStyle.offsetLeft)+document." + viewport$ + ".scrollLeft)||0";
			element.runtimeStyle.setExpression("backgroundPositionX", expression);
		}
	};
	eval(topFunction(backgroundLeft));

	function setOffsetLeft(element) {
		var propertyName = isFixed(element) ? "backgroundPositionX" : "offsetLeft";
		element.runtimeStyle[propertyName] = getOffsetLeft(element, element.style.backgroundPositionX) -
			element.getBoundingClientRect().left - element.clientLeft;
	};
	eval(topFunction(setOffsetLeft));

	function isFixed(element) {
		if (!element) return false;
		if (element.style.position == "fixed" || element.currentStyle.position == "fixed") return true;
		return arguments.callee(element.parentElement);
	};

	function getOffsetLeft(element, position) {
		switch (position) {
			case "left":
			case "top":
				return 0;
			case "right":
			case "bottom":
				return viewport.clientWidth - ie7_tmp.offsetWidth;
			case "center":
				return (viewport.clientWidth - ie7_tmp.offsetWidth) / 2;
			default:
				if (PERCENT.test(position)) {
					return parseInt((viewport.clientWidth - ie7_tmp.offsetWidth) * parseFloat(position) / 100);
				}
				ie7_tmp.style.left = position;
				return ie7_tmp.offsetLeft;
		}
	};
	eval(topFunction(getOffsetLeft));

// -----------------------------------------------------------------------
//  position: fixed
// -----------------------------------------------------------------------

	function positionFixed(element) {
		if (element.currentStyle.position != "fixed") return;
		fixBackground();
		positionFixed[positionFixed.count++] = element;
		// we'll move the element about ourselves
		element.style.position = "fixed";
		element.runtimeStyle.position = "absolute";
		foregroundPosition(element);
	};
	positionFixed.count = 0;

	function foregroundPosition(element, recalc) {
		positionLeft(element, recalc);
		positionTop(element, recalc);
		if (!recalc || element.runtimeStyle.autoTop) {
			// weird extra pixel!?
			if (parseInt(element.currentStyle.bottom) == 0) element.runtimeStyle.screenTop++;
		}
	};

	function positionLeft(element, recalc) {
		// if the element's width is in % units then it must be recalculated
		//  with respect to the viewport
		if (!recalc && PERCENT.test(element.currentStyle.width))
			element.runtimeStyle.fixWidth = element.currentStyle.width;
		if (element.runtimeStyle.fixWidth)
			element.runtimeStyle.width = parseInt(parseFloat(element.runtimeStyle.fixWidth) / 100 * viewport.clientWidth);
		if (recalc) {
			// if the element is fixed on the right then no need to recalculate
			if (!element.runtimeStyle.autoLeft) return;
		} else {
			// is the element fixed on the right?
			element.runtimeStyle.autoLeft = element.currentStyle.right != "auto" && element.currentStyle.left == "auto";
		}
		// reset the element's "left" value and get it's natural position
		element.runtimeStyle.left = "";
		element.runtimeStyle.screenLeft = getScreenLeft(element);
		// accommodate margins
		if (element.currentStyle.marginLeft != "auto") {
			// use a temp element to get pixel equivalents
			element.parentElement.appendChild(ie7_tmp);
			ie7_tmp.style.left = element.currentStyle.marginLeft;
			element.runtimeStyle.screenLeft -= ie7_tmp.offsetLeft;
			// don't leave the temp element in the DOM
			element.parentElement.removeChild(ie7_tmp);
		}
		// if the element is contained by another fixed element then there is no need to
		//  continually recalculate it's left position
		if (isFixed(element.offsetParent)) element.runtimeStyle.pixelLeft = element.runtimeStyle.screenLeft;
		// onsrcoll produces jerky movement, so we use an expression
		else if (!recalc) element.runtimeStyle.setExpression("pixelLeft", "runtimeStyle.screenLeft+document." + viewport$ + ".scrollLeft");
	};
	// clone this function so we can do "top"
	eval(topFunction(positionLeft).replace(/right/g, "bottom").replace(/width/g, "height"));

	// i've forgotten how this works...
	function getScreenLeft(element) { // thanks to kevin newman (captainn)
		var getScreenLeft = element.offsetLeft, nested = false;
		var fixed = isFixed(element.offsetParent) && element.runtimeStyle.autoLeft;
		while (element = element.offsetParent) {
			if (!fixed && element.currentStyle.position != "static") nested = true;
			getScreenLeft += element.offsetLeft * (nested?-1:1);
		}
		return getScreenLeft;
	};
	eval(topFunction(getScreenLeft));

// -----------------------------------------------------------------------
//  capture window resize
// -----------------------------------------------------------------------

	function resize() {
		// if the window has been resized then some positions need to be
		//  recalculated (especially those aligned to "right" or "top"
		for (var i = 0; i < backgroundFixed.count; i++)
			backgroundPosition(backgroundFixed[i]);
		for (i = 0; i < positionFixed.count; i++)
			foregroundPosition(positionFixed[i], true);
		timer = 0;
	};

	// use a timer for some reason.
	//  (sometimes this is a good way to prevent resize loops)
	var timer;
	addEventHandler(window, "onresize", function() {
		if (!timer) timer = setTimeout(resize, 10);
	});

});
