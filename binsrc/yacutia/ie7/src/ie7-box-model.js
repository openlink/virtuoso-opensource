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
	W3C compliance for Microsoft Internet Explorer

	this module forms part of IE7
	IE7 version 0.7.3 (alpha) 2004/09/18
	by Dean Edwards, 2004
*/
if (window.IE7) IE7.addModule("ie7-box-model", function() {
// big, ugly box-model hack + min/max stuff

// #tantek > #erik > #dean { voice-family: hacker; }

// constants
var NUMERIC = "\\s*:\\s*\\d[\\w%]*", UNIT = /^\d\w*$/, PERCENT = /^\d+%$/, PIXEL = /^\d+(px)?$/;
var MATCH = (appVersion < 6) ? /\b(min|max)-(width|height)\s*:\s*\d/gi : /\b(min|max)-width\s*:\s*\d/gi;
var AUTO = (appVersion < 5.5) ? /^auto|0cm$/ : /^auto$/;

// create a temporary element which is used to inherit styles
//  from the target element. the temporary element can be resized
//  to determine pixel widths/heights
var ie7_tmp = tmpElement();
push(IE7.recalcs, function removeTempElement() {
	if (ie7_tmp.parentElement) ie7_tmp.parentElement.removeChild(ie7_tmp);
});

CSSFixes.addFix(MATCH, function(match) {
	return match.slice(0, 3) + match.charAt(4).toUpperCase() + match.slice(5);
});

var viewport = (quirksMode) ? document.body : documentElement;
function isFixed(element) {
	return element.style.position == "fixed" || element.currentStyle.position == "fixed";
};
function layoutParent(element) {
	var layoutParent = element.offsetParent;
	while (layoutParent && !hasLayout(layoutParent)) layoutParent = layoutParent.offsetParent;
	if (!layoutParent || isFixed(element)) layoutParent = viewport;
	return layoutParent;
};

// -----------------------------------------------------------------------
// box-model
// -----------------------------------------------------------------------

function fixWidth(HEIGHT) {
	fixWidth = function(element, value) {
		if (!element.runtimeStyle.fixedWidth && (!isHTML || element.tagName != "HR")) {
			if (!value) value = element.currentStyle.width;
			element.runtimeStyle.fixedWidth = (UNIT.test(value)) ? Math.max(0, getFixedWidth(element, value)) : value;
			element.runtimeStyle.width = element.runtimeStyle.fixedWidth;
			boxSizing(element);
		}
	};
	if (quirksMode) CSSFixes.addRecalc("width\\s*:\\s*\\d\\w*[^%]", fixWidth);

	var getFixedWidth = (quirksMode) ? function(element, value) {
		return getPixelWidth(element, value) + getBorderWidth(element) + getPaddingWidth(element);
	} : function(element, value) {
		return getPixelWidth(element, value);
	};

	// easy way to get border thickness for elements with "layout"
	function getBorderWidth(element) {
		return element.offsetWidth - element.clientWidth;
	};

	// have to do some pixel conversion to get padding thickness :-(
	function getPaddingWidth(element) {
		return getPixelWidth(element, element.currentStyle.paddingLeft) +
			getPixelWidth(element, element.currentStyle.paddingRight);
	};

	function getMarginWidth(element) { // kevin newman
		return ((element.currentStyle.marginLeft == "auto") ? 0 : getPixelLeft(element, element.currentStyle.marginLeft)) +
			((element.currentStyle.marginRight == "auto") ? 0 : getPixelLeft(element, element.currentStyle.marginRight));
	};

// -----------------------------------------------------------------------
// min/max
// -----------------------------------------------------------------------

	// handle min-width property
	function minWidth(element) {
		minWidth[minWidth.count++] = element;
		// IE6 supports min-height so we frig it here
		if (element.currentStyle.minHeight == "auto") element.runtimeStyle.minHeight = 0;
		fixWidth(element);
		boxSizing(element);
		resizeWidth(element);
	};
	minWidth.count = 0;
	CSSFixes.addRecalc("min-width" + NUMERIC, minWidth);

	// clone the minWidth function to make a maxWidth function
	eval(String(minWidth).replace(/min/g, "max"));
	maxWidth.count = 0;
	CSSFixes.addRecalc("max-width" + NUMERIC, maxWidth);

	// apply min/max restrictions
	function resizeWidth(element) {
		// check boundaries
		var rect = element.getBoundingClientRect();
		var width = rect.right - rect.left;
		if (element.currentStyle.maxWidth && width >= getFixedWidth(element, element.currentStyle.maxWidth))
			element.runtimeStyle.width = getFixedWidth(element, element.currentStyle.maxWidth);
		else if (element.currentStyle.minWidth && width <= getFixedWidth(element, element.currentStyle.minWidth))
			element.runtimeStyle.width = getFixedWidth(element, element.currentStyle.minWidth);
		else
			element.runtimeStyle.width = element.runtimeStyle.fixedWidth;
	};

// -----------------------------------------------------------------------
// right/bottom
// -----------------------------------------------------------------------

	function fixRight(element) {
		if ((element.currentStyle.position == "absolute" || element.currentStyle.position == "fixed") &&
		    element.currentStyle.left != "auto" &&
		    element.currentStyle.right != "auto" &&
		    AUTO.test(element.currentStyle.width)) {
		    	fixRight[fixRight.count++] = element;
		    	boxSizing(element);
		    	resizeRight(element);
		}
	};
	fixRight.count = 0;
	CSSFixes.addRecalc("right" + NUMERIC, fixRight);

	function resizeRight(element) {
		element.runtimeStyle.width = "";
		var parentElement = layoutParent(element);
		var left = (element.runtimeStyle.screenLeft) ? element.getBoundingClientRect().left - 2 : getPixelLeft(element, element.currentStyle.left);
		var width = parentElement.clientWidth - getPixelLeft(element, element.currentStyle.right) -	left - getMarginWidth(element);
	    if (!quirksMode) width -= getBorderWidth(element) + getPaddingWidth(element);
		if (width < 0) width = 0;
		if (isFixed(element) || HEIGHT || element.offsetWidth < width) {
			element.runtimeStyle.fixedWidth = width;
			element.runtimeStyle.width = width;
		}
	};

// -----------------------------------------------------------------------
// window.onresize
// -----------------------------------------------------------------------

	// handle window resize
	var clientWidth = documentElement.clientWidth;
	addEventHandler(window, "onresize", function() {
		var i, wider = (clientWidth < documentElement.clientWidth);
		clientWidth = documentElement.clientWidth;
		// resize elements with "min-width" set
		for (i = 0; i < minWidth.count; i++) {
			var element = minWidth[i];
			var fixedWidth = (element.runtimeStyle.width == element.currentStyle.minWidth);
			if (wider && fixedWidth) element.runtimeStyle.width = "";
			if (wider == fixedWidth) resizeWidth(element);
		}
		// resize elements with "max-width" set
		for (i = 0; i < maxWidth.count; i++) {
			var element = maxWidth[i];
			var fixedWidth = (element.runtimeStyle.width == element.currentStyle.maxWidth);
			if (!wider && fixedWidth) element.runtimeStyle.width = "";
			if (wider != fixedWidth) resizeWidth(element);
		}
		// resize elements with "right" set
		for (i = 0; i < fixRight.count; i++) resizeRight(fixRight[i]);
		// take the temporary element out of the DOM
		removeTempElement();
	});

// -----------------------------------------------------------------------
// pixel conversion
// -----------------------------------------------------------------------

	// this is handy because it means that web developers can mix and match
	//  measurement units in their style sheets. it is not uncommon to
	//  express something like padding in "em" units whilst border thickness
	//  is most often expressed in pixels.

	function getPixelWidth(element, value) {
		if (PIXEL.test(value)) return parseInt(value);
		if (PERCENT.test(value)) return parseInt(parseFloat(value) / 100 * layoutParent(element).clientWidth);
		// inherit style
		var parentElement = (element.canHaveChildren) ? element : element.parentElement;
		parentElement.appendChild(ie7_tmp);
		// resize the temporary element
		ie7_tmp.style.width = value;
		// retrieve pixel width
		return ie7_tmp.offsetWidth;
	};

	function getPixelLeft(element, value) {
		if (parseInt(value) > 0) return getPixelWidth(element, value);
		if (PIXEL.test(value)) return parseInt(value);
		element.parentElement.appendChild(ie7_tmp);
		// resize the temporary element
		ie7_tmp.style.left = value;
		// retrieve pixel width
		return ie7_tmp.offsetLeft;
	};
};

// clone the fixWidth function to create a fixHeight function
eval(String(fixWidth)
	.replace(/Width/g, "Height").replace(/width/g, "height")
	.replace(/Left/g, "Top").replace(/left/g, "top")
	.replace(/Right/g, "Bottom").replace(/right/g, "bottom"));

// apply box-model + min/max fixes
fixWidth();
fixHeight(true);

});
