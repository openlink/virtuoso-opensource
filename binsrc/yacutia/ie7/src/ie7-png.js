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
if (window.IE7) IE7.addModule("ie7-png", function() {
// IE5.0 not supported
if (appVersion < 5.5) return;

// constants
// this filter is used to replace a PNG image
var FILTER = "progid:DXImageTransform.Microsoft.AlphaImageLoader(src=%1,sizingMethod='scale')";
// a small transparent image used as a placeholder
var NULL = (/\bSV1\b/.test(navigator.userAgent)) ? makePath("blank.gif", path) :
	"javascript:'#define x_width 1\\n#define x_height 1\\nstatic char x_bits[]={0x00}'";

// ** IE7 VARIABLE
// e.g. only apply the hack to files ending in ".png"
// IE7_PNG_SUFFIX = ".png";

// regular expression version of the above
var pngTest = new RegExp((window.IE7_PNG_SUFFIX || "-trans.png") + "$", "i");

// apply a filter
function addFilter(element, src) {
	element.runtimeStyle.filter = FILTER.replace(/%1/, src);
};

// -----------------------------------------------------------------------
//  fix css
// -----------------------------------------------------------------------

// replace background(-image): url(..) ..  with background(-image): .. ;filter: ..;
var MATCH = /background(-image)?\s*:([^(};]*)url\(([^\)]+)\)([^;}]*)/gi;
CSSFixes.addFix(MATCH, function replace(match, image, prefix, url, suffix) {
	url = getString(url);
	return pngTest.test(url) ? "filter:" +
		FILTER.replace(/scale/, "crop").replace(/%1/, url) + ";zoom:1;background" +
		  (image||"") + ":" + (prefix||"") + "none" + (suffix||"") : match;
});

// -----------------------------------------------------------------------
//  fix html
// -----------------------------------------------------------------------

if (HTMLFixes) {
	function fixImg(element) {
		if (pngTest.test(element.src)) {
			// we have to preserve width and height
			var width = element.width, height = element.height;
			// add the AlphaImageLoader thingy
			addFilter(element, element.src);
			// remove the real image
			element.src = NULL;
			element.width = width;
			element.height = height;
		} else element.runtimeStyle.filter = "";
	};
	HTMLFixes.add("img,input", function(element) {
		if (element.tagName == "INPUT" && element.type != "image") return;
		fixImg(element);
		addEventHandler(element, "onpropertychange", function() {
			if (event.propertyName == "src") fixImg(element);
		});
	});
}

/* ######

// -----------------------------------------------------------------------
//  dhtml/javascript support
// -----------------------------------------------------------------------

function fixBackgroundImage(element) { //DHTML
//#	// ignore HTML IMG tags
//#	if (isHTML && element.tagName == "IMG") return;
	var src = element.currentStyle.backgroundImage.slice(5, -2);
	if (pngTest.test(src)) {
		addFilter(element, src);
		element.runtimeStyle.backgroundImage = "none";
	} else element.runtimeStyle.filter = "";
};

###### */

});
