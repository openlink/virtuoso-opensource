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

/* credits/thanks:
	Shaggy, Martijn Wargers, Jimmy Cerra, Mark D Anderson,
	Lars Dieckow, Erik Arvidsson, Gellért Gyuris, James Denny,
	Unknown W Brackets, Benjamin Westfarer, Rob Eberhardt,
	Bill Edney, Kevin Newman
*/

if (!window.IE7) new function() {
try {
// -----------------------------------------------------------------------
// globals
// -----------------------------------------------------------------------

window.IE7 = this;

// in case of error...
var DUMMY = this.addModule = new Function;
// if the document has been hidden for faster loading, unhide it
function unHide(){if (document.body) document.body.style.visibility = "visible"};
// IE7 version info
this.toString = function(){return "IE7 version 0.7.3 (alpha)"};
// error reporting
var alert = (/ie7_debug/.test(location.search)) ? function(message) {
	window.alert(IE7 + "\n\n" + message);
} : DUMMY;
var appVersion = navigator.appVersion.match(/MSIE (\d\.\d)/)[1];
// IE7 can be turned "off"
if (/ie7_off/.test(location.search) || appVersion < 5 ||
	!/^ms_/.test(document.documentElement.uniqueID)) return unHide();
// IE version info
var quirksMode = Boolean(document.compatMode != "CSS1Compat");
// assume html unless explicitly defined
var isHTML = (typeof document.mimeType == "unknown") ?
	!/\.xml$/i.test(location.pathname) :
	Boolean(document.mimeType != "XML Document");
// ie7 style sheet text
var LINKS = ":link{ie7-link:link}:visited{ie7-link:visited}";
var HEADER = LINKS;
if (!isHTML) HEADER += "*{margin:0}";
// another global
var HTMLFixes; // loaded separately
var documentElement = document.documentElement;

// -----------------------------------------------------------------------
// external
// -----------------------------------------------------------------------

// cache for the various modules that make up IE7.
//  modules are stored as functions. these are executed
//  after the style sheet text has been loaded.
// storing the modules as functions means that we avoid
//  name clashes with other modules.
var modules = {};
this.addModule = function(name, script, autoload) {
	if (!modules) return;
	// re-evelaute the script module in the scope of the main script
	if (loaded) eval("script=" + String(script));
	// this flag means execute immediately
	if (autoload) {
		script();
		script = DUMMY;
	}
	// store the module
	modules[name] = script;
};

var RELATIVE = /^[\w\.]+[^:]*$/;
function makePath(href, path) {
	if (RELATIVE.test(href)) href = (path || "") + href;
	return href;
};

function getPath(href, path) {
	href = makePath(href, path);
	return href.slice(0, href.lastIndexOf("/") + 1);
};

// get the path to this script
var path = getPath(document.scripts[document.scripts.length - 1].src);
// we'll use microsoft's http request object to load external files
var httpRequest = new ActiveXObject("Microsoft.XMLHTTP");
function load(href, path) {
try {
	href = makePath(href, path);
	// easy to load a file huh?
	httpRequest.open("GET", href, false);
	httpRequest.send();
	return httpRequest.responseText;
} catch (ignore) {
	alert("Error [1]: could not load file " + href);
	return "";
}};

// -----------------------------------------------------------------------
// IE5.0 compatibility
// -----------------------------------------------------------------------

// annoying but necessary
var push = function(array, item) {return array.push(item)};
var pop = function(array) {return array.pop()};

// load an external module to patch IE5.0 and override the functions above
if (appVersion < 5.5) eval(load("ie7-ie5.js", path));

// -----------------------------------------------------------------------
//  IE7 style sheet
// -----------------------------------------------------------------------

// create the internal IE7 style sheet
if (document.readyState == "complete" || !isHTML) document.createStyleSheet();
// this fixes a bug to do with the <base> tag
else document.write("<style></style>");
// get the new style sheet
this.styleSheet = document.styleSheets[document.styleSheets.length - 1];
// initialise the text
this.styleSheet.cssText = LINKS;
// mark it as internal
this.styleSheet.ie7 = true;
// store loaded cssText URLs
var cssText = {};
// load an external style sheet
function loadStyleSheet(styleSheet, path) {
	var url = makePath(styleSheet.href, path);
	if (cssText[url]) return "";
	// load from source
	cssText[url] = (styleSheet.disabled) ? "" : fixUrls(getCSSText(styleSheet, path), getPath(styleSheet.href, path));
	return cssText[url];
};

// retrieve the text of a style sheet
var getCSSText = function(styleSheet) {
	// without the CSS2 module we assume CSS1, so it is safe to get Microsoft's stored text
	return styleSheet.cssText;
};

// fix css paths
var URL = /(url\(['"]?)([\w\.]+[^:\)]*['"]?\))/gi;
// we're lumping all css text into one big style sheet so relative
//  paths have to be fixed. this is necessary anyway because of other
//  explorer bugs.
function fixUrls(cssText, pathname) {
	// hack & slash
	return cssText.replace(URL, "$1" + pathname.slice(0, pathname.lastIndexOf("/") + 1) + "$2");
};

// a store for functions that will be called when refreshing IE7
this.recalcs = [];
// be aware of the css modules (do nothing if it's not there)
this.parse = DUMMY;
var complete = false; // IE7 applied?
function _load() {
try {
	// don't call this function again
	complete = true; // IE7 applied!

	var MEDIA = /\bscreen\b|\ball\b|^$/i; // valid media settings

	// handy reference to the sytle sheets collection
	var styleSheets = document.styleSheets;
	var inlineStyles = [];
	var styles = document.getElementsByTagName("style");
	for (var i = styles.length - 1; i >= 0; i--) {
		// don't include the ie7 style header
		push(inlineStyles, /ie7-link/.test(styles[i].innerHTML)?"":styles[i].innerHTML);
	}

	// retrieve unparsed css text. inline style sheets have their
	//  unparsed css text cached by ie7-style.htc.
	function getCSSText(styleSheet, path) {
		var cssText = "";
		// loop through imported style sheets
		if (MEDIA.test(styleSheet.media)) {
			for (var i = 0; i < styleSheet.imports.length; i++) {
				// call this function recursively to get all
				//  imported style sheets
				cssText += arguments.callee(styleSheet.imports[i], getPath(styleSheet.href, path));
			}
			// retrieve inline style or load an external style sheet
			cssText += ((styleSheet.href) ? loadStyleSheet(styleSheet, path) : pop(inlineStyles));
		}
		return cssText;
	};

	// store for style sheet text
	IE7.cssText = "";
	// load all style sheets in the document
	for (i = 0; i < styleSheets.length; i++) IE7.cssText += getCSSText(styleSheets[i], "");
	// tidy the style sheet text (remove comments etc)
	IE7.cssText = encode(IE7.cssText);

	// load modules (ie7 components)
	for (i in modules) modules[i]();
	// prevent further loading
	delete modules;

	// fix html page elements (i.e. <abbr>)
	if (HTMLFixes) HTMLFixes.apply();
	// apply fixes to the style sheet text (text parse)
	CSSFixes.apply();
	// parse css text (ie7 classes and rules)
	IE7.parse();

	// load the new css text
	IE7.styleSheet.cssText = HEADER + decode(IE7.cssText);
	// trash the old style sheets
	for (i = 0; i < styleSheets.length; i++) {
		if (!styleSheets[i].disabled && !styleSheets[i].ie7) styleSheets[i].cssText = "";
	}

	// refresh the document
	IE7.recalc();

	alert("loaded successfully");
} catch (error) {
	alert("Error [2]: " + error.description);
} finally {
	unHide();
}};

// this will change some more later.
//  but for the moment this is how i'm applying the various fixes
//  (this and the huge constructor function preceding it..)
this.recalc = function() {
	// re-apply style sheet rules (re-calculate ie7 classes)
	CSSFixes.recalc();
	// apply global fixes to the document (and some tidying)
	for (var i = 0; i < this.recalcs.length; i++) this.recalcs[i]();
};

// -----------------------------------------------------------------------
//  fix css
// -----------------------------------------------------------------------

// two key methods of the CSSFixes object:
//
// 1. addFix(pattern, replace)
//  make a direct text replacement to style sheet text.
//  pattern: a RegExp representing the text to replace
//  replace: a String representing the replacement text
// 2. addRecalc(pattern, fix)
//  identify elements that match a piece of style sheet text
//  pattern: a RegExp representing the text to replace
//  fix: a Function that takes any matching element as it's only parameter

var CSSFixes = new function() {
	var fixes = []; // private
	this.addFix = function() {
		push(fixes, arguments);
	};
	var recalcs = []; // private
	this.addRecalc = function(pattern, fix) {
		var reg = new RegExp("([^{}]*)\\{([^}]*[^\\w-])?" + pattern, "gi");
		var cssText = IE7.cssText;
		pattern = [];
		while (match = reg.exec(cssText)) {
			push(pattern, match[1]);
			// fix for IE5.0
			if (appVersion < 5.5) cssText = cssText.slice(match.lastIndex);
		}
		if (pattern.length) {
			pattern = pattern.toString();
			push(recalcs, arguments);
		}
	};
	this.apply = function() {
		// loop through the fixes
		// they consist of a pair of arguments passed to a String.replace
		// function. the replacement is made to the entire style sheet text
		for (var i = 0; i < fixes.length; i++) {
			IE7.cssText = IE7.cssText.replace(fixes[i][0], fixes[i][1]);
		}
		// add recalcs here
		this.addRecalc("box-sizing\\s*:\\s*content-box", boxSizing);
		// fix "unscrollable content" bug (http://www.positioniseverything.net/explorer/unscrollable.html)
		this.addRecalc("position\\s*:\\s*absolute", function(element) {
			if (element.offsetParent.currentStyle.position == "relative") boxSizing(element.offsetParent);
		});
	};
	// placeholder for the css module
	this.recalc = function() {
		// loop through the fixes
		for (var i = 0; i < recalcs.length; i++) {
			var elements = cssQuery(recalcs[i][0]);
			for (var j = 0; j < elements.length; j++) recalcs[i][1](elements[j]);
		}
	};
	// fix "double margin" bug (http://www.positioniseverything.net/explorer/doubled-margin.html)
	this.addFix(/(float\s*:\s*(left|right))/gi, "display:inline;$1");
	// display:list-item (IE5.x)
	if (appVersion < 6) this.addFix(/display\s*:\s*list-item/gi, "display:block");
	if (quirksMode) {
		// named font-sizes are too small
		var SIZES = "xx-small,x-small,small,medium,large,x-large,xx-large".split(",");
		for (var i = 0; i < SIZES.length; i++) SIZES[SIZES[i]] = SIZES[i - 1] || "xx-small";
		function replace($,$1,$2,$3){return $1+SIZES[$3]};
		this.addFix(new RegExp("(font(-size)?\\s*:\\s*)(" + SIZES.join("|") + ")", "gi"), replace);
	}
};

// -----------------------------------------------------------------------
//  css query engine
// -----------------------------------------------------------------------

// optimised for speed not readability (sorry)

// this is basically version 2 of cssQuery. it is a lot more complicated
//  but *very* configurable..

// the following functions allow querying of the DOM using CSS selectors

var STANDARD_SELECT = /^[^>\+~\s]/;
var STREAM = /[\s>\+~:@#\.\(\)]|[^\s>\+~:@#\.\(\)]+/g;
var NAMESPACE = /\|/;
var IMPLIED_SELECTOR = /([\s>~\,]|[^(]\+|^)([\.:#@])/g;
var ASTERISK ="$1*$2";

// cache results for faster processing
var cssCache = {};

// this is the main query function
function cssQuery(selector, from) {
	var useCache = !from;
	var base = (from) ? (from.constructor == Array) ? from : [from] : [document];
	// process comma separated selectors
	var selectors = selector.replace(IMPLIED_SELECTOR, ASTERISK).split(",");
	var match = [];
	for (var i = 0; i < selectors.length; i++) {
		// convert the selector to a stream
		selector = toStream(selectors[i]);
		// faster chop if it starts with id
		if (selector.slice(0, 3).join("") == " *#") {
			selector = selector.slice(2);
			from = selectById(base, selector[1]);
		} else from = base;
		// process the stream
		var j = 0, token, filter, filterArgs, cacheSelector = "";
		while (j < selector.length) {
			token = selector[j++];
			filter = selector[j++];
			cacheSelector += token + filter;
			filterArgs = "";
			if (selector[j] == "(") {
				while (selector[j++] != ")") filterArgs += selector[j];
				filterArgs = filterArgs.slice(0, -1);
				cacheSelector += "(" + filterArgs + ")";
			}
			// process a token/filter pair
			from = (useCache && cssCache[cacheSelector]) ?
				cssCache[cacheSelector] : select(from, token, filter, filterArgs);
			if (useCache) cssCache[cacheSelector] = from;
		}
		match = match.concat(from);
	}
	// return the filtered selection
	return match;
};

// convert css selectors to a stream of tokens and filters
//  it's not a real stream. it's just an array of strings.
function toStream(selector) {
	if (STANDARD_SELECT.test(selector)) selector = " " + selector;
	return selector.match(STREAM);
};

// select a set of matching elements.
// "from" is an array of elements.
// "token" is a character representing the type of filter
//  e.g. ">" means child selector
// "filter" represents the tag name, id or class name that is being selected
// the function returns an array of matching elements
function select(from, token, filter, filterArgs) {
	//alert("token="+token+",filter="+filter+",filterArgs="+filterArgs+",from="+from.length);
	var scopeName = "";
	if (NAMESPACE.test(filter)) {
		filter = filter.split("|");
		scopeName = filter[0];
		filter = filter[1];
	}
	var filtered = [];
	if (selectors[token]) selectors[token](filtered, from, filter, scopeName || filterArgs);
	return filtered;
};

function selectById(from, id) {
	//alert("id="+id+",from="+from.length);
	var filtered = [], i, j;
	for (i = 0; i < from.length; i++) {
		var match = from[i].all.item(id);
		if (match) {
			if (match.length == null) push(filtered, match);
			else for (j = 0; j < match.length; j++) push(filtered, match[j]);
		}
	}
	return filtered;
};

var selectors = { // CSS1
	// descendant selector
	" ": function(filtered, from, filter, scopeName) {
		// loop through current selection
		for (var i = 0; i < from.length; i++) {
			// get descendants
			var subset = (filter == "*" && from[i].all) ? from[i].all : from[i].getElementsByTagName(filter);
			// loop through descendants and add to filtered selection
			for (var j = 0; j < subset.length; j++) {
				if (isElement(subset[j]) && (!scopeName || subset[j].scopeName == scopeName))
					push(filtered, subset[j]);
			}
		}
	},
	// ID selector
	"#": function(filtered, from, filter) {
		// loop through current selection and check ID
		for (var i = 0; i < from.length; i++) if (from[i].id == filter) push(filtered, from[i]);
	},
	// class selector
	".": function(filtered, from, filter) {
		// create a RegExp version of the class
		filter = new RegExp("(^|\\s)" + filter + "(\\s|$)");
		// loop through current selection and check class
		for (var i = 0; i < from.length; i++) if (filter.test(from[i].className)) push(filtered, from[i]);
	},
	// pseudo-class selector
	":": function(filtered, from, filter, filterArgs) {
		// retrieve the cssQuery pseudo-class function
		filter = pseudoClasses[filter];
		// loop through current selection and apply pseudo-class filter
		if (filter) for (var i = 0; i < from.length; i++)
			// if the cssQuery pseudo-class function returns "true" add the element
			if (filter(from[i], filterArgs)) push(filtered, from[i]);
	}
};

var attributeTests = "";

var pseudoClasses = { // static
	toString: function() {
		var toString = [];
		for (var pseudoClass in this) {
			if (pseudoClass != "link" && pseudoClass != "visited") {
				if (this[pseudoClass].length > 1) pseudoClass += "\\([^)]*\\)";
				push(toString, pseudoClass);
			}
		}
		return toString.join("|");
	},
	// the "ie7-link" property is set by text contained in the IE7 generated style sheet.
	// (the text is stored in the "LINKS" variable)
	"link": function(element) {
		return Boolean(element.currentStyle["ie7-link"] == "link");
	},
	"visited": function(element) {
		return Boolean(element.currentStyle["ie7-link"] == "visited");
	}
};

// we'll let explorer handle CSS1 dynamic pseudo classes (hover, active)
var dynamicPseudoClasses = {toString: pseudoClasses.toString};
// other IE7 CSS modules can expand this object

// how tedious..
function compareTagName(element, tagName, scopeName) {
	if (scopeName && element.scopeName != scopeName) return false;
	return (tagName == "*") ? isElement(element) : (isHTML) ?
		(element.tagName == tagName.toUpperCase()) : (element.tagName == tagName);
};

// -----------------------------------------------------------------------
// encoding
// -----------------------------------------------------------------------

// a style sheet must be prepared for parsing.
// this means stripping out comments etc
// strings are encoded to avoid parsing bugs (are you reading this microsoft?)

var strings = [];
function getString(string) {
	return QUOTED.test(string) ? strings[string.slice(1, -1)] : string;
};

var encode = function(cssText) {
	return cssText
	// remove comments (gellért gyuris)
	.replace(/(\/\*[^\*]*\*+([^\/][^\*]*\*+)*\/)|('[^']*')|("[^"]*")/g, function(match) {
		return (match.charAt(0) == "/") ? "" : "'" + (push(strings, match.slice(1, -1)) - 1) + "'";
	})
	// parse out @namespace/@import (restating them crashes explorer!)
	.replace(/@(namespace|import)[^;\n]+[;\n]|<!\-\-|\-\->/g, "")
	// fix IE namespaces
	.replace(/\\:/g, "|")
	// trim whitespace
	.replace(/^\s+|\s*([\{\}\+\,>~\s;])\s*|\s+$/g, "$1");
};

function decode(cssText) {
	// fix IE namespaces
	return cssText.replace(/\|/g, "\\:").replace(/'(\d+)'/g, function(match, key) {
		return strings[key];
	});
};

// -----------------------------------------------------------------------
// event handling
// -----------------------------------------------------------------------

var handlers = [];

// add an event handler (function) to an element
function addEventHandler(element, type, handler) {
	element.attachEvent(type, handler);
	// store the handler so it can be detached later
	push(handlers, arguments);
};

// remove an event handler assigned to an element by IE7
function removeEventHandler(element, type, handler) {
try {
	element.detachEvent(type, handler);
} catch (ignore) {
	// write a letter of complaint to microsoft..
}};

// remove event handlers (they eat memory)
window.attachEvent("onbeforeunload", function() {
 	while (handlers.length) {
 		var handler = pop(handlers);
 		removeEventHandler(handler[0], handler[1], handler[2]);
 	};
});

// -----------------------------------------------------------------------
// shared box-model support
// -----------------------------------------------------------------------

// does an element have "layout" ?
var hasLayout = (appVersion < 6) ? function(element) {
	return element.clientWidth;
} : function(element) {
	return element.currentStyle.hasLayout;
};

// give an element "layout"
function boxSizing(element) {
	if (!hasLayout(element)) {
		element.contentEditable = false; // jimmy cerra
		fixMargins(firstChildElement(element));
	}
};

// stop margins collapsing when an element is given "layout"
function fixMargins(element) {
	while (element) {
		element.runtimeStyle.marginTop = element.currentStyle.marginTop;
		element = nextElement(element);
	}
};

// -----------------------------------------------------------------------
// generic
// -----------------------------------------------------------------------

var QUOTED = /('[^']*')|("[^"]*")/;
function quote(value) {return (QUOTED.test(value)) ? value : "'" + value + "'"};
function unquote(value) {return (QUOTED.test(value)) ? value.slice(1, -1) : value};

// create a hidden element - used for testing pixel values
function tmpElement(tagName) {
	var element = document.createElement(tagName || "object");
	element.style.cssText = "position:absolute;padding:0;display:block;border:none;clip:rect(0 0 0 0);left:-9999";
	return element;
};

// IE5.x includes comments (LOL) in it's element collections.
// so we have to check for this. the test is tagName != "!". LOL (again).
function isElement(node) {
	return Boolean(node && node.nodeType == 1 && node.tagName != "!" && !node.ie7_anon);
};

// return the previous element to the supplied element
//  previousSibling is not good enough as it might return a text or comment node
function previousElement(element) {
	while (element && (element = element.previousSibling) && !isElement(element)) continue;
	return element;
};

// return the next element to the supplied element
function nextElement(element) {
	while (element && (element = element.nextSibling) && !isElement(element)) continue;
	return element;
};

// return the first child ELEMENT of an element
//  NOT the first child node (though they may be the same thing)
function firstChildElement(element) {
	element = element.firstChild;
	return (isElement(element)) ? element : nextElement(element);
};

// -----------------------------------------------------------------------
//  modules
// -----------------------------------------------------------------------

//## paste modules here when building IE7 libraries (gotta know what you are doing though!)

var loaded = true;

// -----------------------------------------------------------------------
//  initialisation
// -----------------------------------------------------------------------

// this script may be inserted via a favelet so the page is already loaded
if (document.readyState == "complete") _load();
// apply IE7 when all markup has been parsed by the browser
else addEventHandler(document, "onreadystatechange", function() {
	if (!complete && document.readyState == "complete") setTimeout(_load, 0);
});

// -----------------------------------------------------------------------
//  error handling
// -----------------------------------------------------------------------

} catch (error) {
	unHide();
	alert("Error [0]: " + error.description);
} finally {
	// have a beer...
}}();
