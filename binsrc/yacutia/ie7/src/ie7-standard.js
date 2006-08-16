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

/*
includes:
 ie-core.js, ie7-html4.js, ie7-box-model.js,
 ie7-css2.js, ie7-png.js, ie7-fixed.js
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

var loaded = false; // has the core loaded?

IE7.addModule("ie7-html4", function() {

	// fix broken HTML tags

if (isHTML) HTMLFixes = new function() {
	var fixes = []; // private

	function fix(element) {
		// remove the broken tags and replace with <HTML:tagName/>
		var fixedElement = document.createElement("<HTML:" + element.outerHTML.slice(1));
	//# fixedElement.mergeAttributes(element, false);
		if (element.outerHTML.slice(-2) != "/>") {
			// remove child nodes and copy them to the new element
			var endTag = "</"+ element.tagName + ">", nextSibling;
			while ((nextSibling = element.nextSibling) && nextSibling.outerHTML != endTag) {
				element.parentNode.removeChild(nextSibling);
				fixedElement.appendChild(nextSibling);
			}
			// remove the closing tag
			if (nextSibling) element.parentNode.removeChild(nextSibling);
		}
		// replace the broken tag with the namespaced version
		element.parentNode.replaceChild(fixedElement, element);
		return fixedElement;
	};

	this.add = function() {
		push(fixes, arguments);
	};

	this.apply = function() {
	try {
		// create the namespace used to declare our fixed <abbr/> tag.
		//  strangely, this throws an error if there is no <abbr/> tag present!?
		if (appVersion > 5) document.namespaces.add("HTML", "http://www.w3.org/1999/xhtml");

	} catch (ignore) {
		// explorer confuses me.
		// we can create a namespace when the <abbr/>
		//  tag is present, otherwise error!
		//  this kind of suits me but it's still weird.
	} finally {
		// apply all fixes
		for (var i = 0; i < fixes.length; i++) {
			var elements = cssQuery(fixes[i][0]);
			for (var j = 0; j < elements.length; j++) fixes[i][1](elements[j]);
		}
	}};

	// associate <label> elements with an input element
	this.add("label", function(element) {
		if (!element.htmlFor) {
			var input = cssQuery("input,select,textarea", element)[0];
			if (input) {
				if (!input.id) input.id = input.uniqueID;
				element.htmlFor = input.id;
			}
		}
	});

	// provide support for the <abbr> tag for html documents
	//  this is a proper fix, it preserves the dom structure and
	//  <abbr> elements report the correct tagName & namespace prefix
	this.add("abbr", function(element) {
		fix(element);
		// don't cache broken <abbr> tags
		delete cssCache[" abbr"];
	});

	// a couple of <button> fixes
	this.add("button,input", function(element) {
		if (element.tagName == "BUTTON") {
			// IE bug means that innerText is submitted instead of "value"
			var match = element.outerHTML.match(/ value="([^"]*)"/i);
			element.runtimeStyle.value = (match) ? match[1] : "";
		}
		// flag the button/input that was used to submit the form
		if (element.type == "submit") {
			addEventHandler(element, "onclick", function() {
				element.runtimeStyle.clicked = true;
				setTimeout("document.all." + element.uniqueID + ".runtimeStyle.clicked=false", 1);
			});
		}
	});

	// only submit successful controls
	this.add("form", function(element) {
		var UNSUCCESSFUL = /^(submit|reset|button)$/;
		addEventHandler(element, "onsubmit", function() {
			for (var i = 0; i < element.length; i++) {
				if (UNSUCCESSFUL.test(element[i].type) && !element[i].disabled && !element[i].runtimeStyle.clicked) {
					element[i].disabled = true;
					setTimeout("document.all." + element[i].uniqueID + ".disabled=false", 1);
				} else if (element[i].tagName == "BUTTON" && element[i].type == "submit") {
					setTimeout("document.all." + element[i].uniqueID + ".value='" + element[i].value + "'", 1);
					element[i].value = element[i].runtimeStyle.value;
				}
			}
		});
	});
}}, true);

IE7.addModule("ie7-box-model", function() {
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

IE7.addModule("ie7-css2", function() {
// this has lost its oo shape due to IE5.0 inadequcies and
//  the demands of multiple inheritance (sometimes it's just
//  easier that way).

// constants
var CHILD = />/g, ANCHOR = /(\ba(\.[\w-]+)?)$/i;

// cache ie7 classes
IE7.classes = [];
// override the previously defined dummy parser
IE7.parser = new Parser;
// constructors are stored on the IE7 interface
//  this is in anticipation of ie7-css-strict.js
IE7.Class = Class;
IE7.DynamicStyle = DynamicStyle;
IE7.PseudoElement = PseudoElement;
// replace unknown css2/3 selectors with ie7 classes
IE7.parse = function() {
	// parse the style sheet
	with (this.parser) this.cssText = decode(parse(encode(this.cssText)));
	// execute underlying queries of IE7 classes
	for (var i = 0; i < IE7.classes.length; i++) IE7.classes[i].exec();
	// create pseudo elements
	for (i = 0; i < pseudoElements.length; i++) pseudoElements[i].create();
};

// -----------------------------------------------------------------------
//  parser
// -----------------------------------------------------------------------

// override getCSSText function defined in ie7-core.
// explorer will trash unknown selectors (it converts them to "UNKNOWN").
// so we must reload external style sheets (internal style sheets can have their text
//  extracted through the innerHTML property).
getCSSText = function(styleSheet, path) {
	// load the style sheet text from an external file
	return load(styleSheet.href, path);
};

var encoded = []; // private
function Parser() {
	// public
	this.parse = function(cssText) {
		// create regular expressions
		Class.ALL = new RegExp("[^},\\s]*([>+~][^:@,\\s{]+|:(" + pseudoClasses +
			")|\\.[\\w-]+\\.[\\w-.]+|@[@\\d]+)", "g");
		Class.COMPLEX = new RegExp("[^\\s(]+[+~]|@\\d+|:(link|visited|" + pseudoClasses + "|" +
			dynamicPseudoClasses + ")|\\.[\\w-.]+", "g");
		DynamicStyle.ALL = new RegExp("([^}]*):(" + dynamicPseudoClasses + ")([^{]*)", "g");
		// parse out unknown CSS selectors
		return cssText
		.replace(PseudoElement.ALL, PseudoElement.ID)
		.replace(DynamicStyle.ALL, DynamicStyle.ID)
		.replace(Class.ALL, Class.ID);
	};

	this.encode = function(cssText) {
		// create regular expressions
		AttributeSelector.ALL = new RegExp("\\[([^" + attributeTests + "=\\]]+)([" +
			attributeTests + "]?=?)([^\\]]+)?\\]", "g");

		return cssText
		// parse out attribute selectors
		.replace(AttributeSelector.ALL, AttributeSelector.ID)
		// encode style blocks
		.replace(/\{[^\}]*\}/g, function($){return "{"+(push(encoded,$)-1)+"}"})
		// remove double semi-colons (::before)
		.replace(/::/g, ":")
		// split comma separated selectors
		.replace(/([^\}\s]*\,[^\{]*)(\{\d+\})/g, function(match, left, right) {
			return left.split(",").join(right) + right;
		});
	};

	// put style blocks back
	this.decode = function(cssText) {
		return cssText.replace(/\{(\d+)\}/g, function($, $1){return encoded[$1]});
	};
};

// -----------------------------------------------------------------------
// IE7 style classes
// -----------------------------------------------------------------------

// virtual
function _Class() {
	// properties
//- this.id = 0;
//- this.name = "";
//- this.selector = "";
//- this.MATCH = null;
	this.toString = function() {
		return "." + this.name;
	};
	// methods
	this.add = function(element) {
		// allocate this class
		element.className += " " + this.name;
	};
	this.remove = function(element) {
		// deallocate this class
		element.className = element.className.replace(this.MATCH, "");
	};
	this.exec = function() {
		// execute the underlying css query for this class
		var match = cssQuery(this.selector);
		// add the class name for all matching elements
		for (var i = 0; i < match.length; i++) this.add(match[i]);
	};
};

// constructor
function Class(selector, cssText) {
	this.id = IE7.classes.length;
	this.name = Class.PREFIX + this.id;
	this.selector = selector;
	this.MATCH = new RegExp("\\s" + this.name + "\\b", "g");
	push(IE7.classes, this);
};
// inheritance
Class.ancestor = _Class;
Class.prototype = new _Class;
// constants
Class.PREFIX = "ie7_";

// class methods
Class.ID = function(match) {
	return simpleSelector(match) + new Class(match);
};

// -----------------------------------------------------------------------
// IE7 dynamic style
// -----------------------------------------------------------------------

// class properties:

// attach: the element that an event handler will be attached to
// target: the element that will have the IE7 class applied

// virtual
function _DynamicStyle() {
//- this.attach = "";
//- this.dynamicPseudoClass = null;
//- this.target = "";
	// execute the underlying css query for this class
	this.exec = function() {
		var match = cssQuery(this.attach);
		// process results
		for (var i = 0; i < match.length; i++) {
			// retrieve the event handler's target element(s)
			var target = (this.target) ? cssQuery(this.target, match[i]) : [match[i]];
			// attach event handlers for dynamic pseudo-classes
			if (target) this.dynamicPseudoClass(match[i], target, this);
		}
	};
};
// inheritance
_DynamicStyle.prototype = new _Class;

// constructor
function DynamicStyle(selector, attach, dynamicPseudoClass, target) {
	// initialise object properties
	this.attach = attach;
	this.dynamicPseudoClass = dynamicPseudoClasses[dynamicPseudoClass];
	this.target = target;
	// inheritance
	this.inherit = Class;
	this.inherit(selector);
};
// inheritance
DynamicStyle.ancestor = _DynamicStyle;
DynamicStyle.prototype = new _DynamicStyle;
// class methods
DynamicStyle.ID = function(match, attach, dynamicPseudoClass, target) {
	// no need to capture anchor events
	if (isHTML && dynamicPseudoClass != "focus" && ANCHOR.test(attach) && !/[+>~]/.test(target)) return match;
	return simpleSelector(match) + new DynamicStyle(match, attach, dynamicPseudoClass, target);
};;

// -----------------------------------------------------------------------
// IE7 pseudo elements
// -----------------------------------------------------------------------

// CSS text required by the "content" property
HEADER += ".ie7_anon{vertical-align:top;display:inline}";

// convert unicode hexadecimal to javascript string
var HEX = /\\([a-fA-F\d]+)/g;
function unicode(match, code){return eval("'\\u" + "0000".slice(code.length) + code + "'")};

var pseudoElements = [];

// virtual
function _PseudoElement() {
//- this.position = "before";
	this.content = null;
	// this means that the style rule is represented by an empty string
	//  in the IE7 style sheet (effectively deleting it)
	this.toString = function(){return ""};
	// specificity is not required for pseudo elements
	this.specificity = 0;
	// used to load <object type=x-scriptlet>
	function addTimer(object, content, cssText) {
		var timer = setInterval(function() {
		try {
			// wait until the object has loaded
			if (!object.load) return;
			object.load(object, content, cssText);
			clearInterval(timer);
		} catch (ignore) {
			// remote scripting
			clearInterval(timer);
		}}, 10);
	};
	// execute the underlying css query for this class
	this.create = function() {
		if (this.content == null) return;
		for (var i = 0; i < this.match.length; i++) {
			var target = this.match[i];
			var pseudoElement = target.runtimeStyle[this.position];
			if (pseudoElement) {
				// parent for new content
				var parentElement = target.canHaveChildren ? target : target.parentElement;
				// external data?
				var isURL = /^url\(.*\)$/.test(this.content);
				// create the pseudo element (<object> if external, <!> if internal)
				var element = document.createElement(isURL?PseudoElement.OBJECT:"!");
				// flag it as anonymous
				element.ie7_anon = true;
				// apply style
				element.runtimeStyle.cssText = pseudoElement.cssText;
				// use text content
				if (!isURL) element.innerText = pseudoElement.content;
				// insert the pseudo element
				if (this.position == "before") {
					parentElement.insertBefore(element, parentElement.firstChild);
				} else {
					parentElement.appendChild(element);
				}
				// give the <object> a chance to load
				if (isURL) addTimer(element, pseudoElement.content, pseudoElement.cssText);
				target.runtimeStyle[this.position] = null;
			}
		}
	};
	// execute the underlying css query for this class
	this.exec = function() {
		// execute the underlying css query for this class
		this.match = cssQuery(this.selector);
		// add the class name for all matching elements
		for (var i = 0; i < this.match.length; i++) {
			var runtimeStyle = this.match[i].runtimeStyle;
			if (!runtimeStyle[this.position]) runtimeStyle[this.position] = {cssText:""};
			runtimeStyle[this.position].cssText += ";" + this.cssText;
			if (this.content != null) runtimeStyle[this.position].content = this.content;
		}
	};
};
// inheritance
_PseudoElement.prototype = new _Class;
// constructor
function PseudoElement(selector, position, cssText) {
	// initialise object properties
	this.position = position;
	this.cssText = encoded[cssText].slice(1, -1);
	var content = this.cssText.match(PseudoElement.CONTENT);
	if (content) this.content = getString(content[1]).replace(HEX, unicode);
	// inheritance
	this.inherit = Class;
	this.inherit(selector);
	// store this class so we can execute it later
	push(pseudoElements, this);
};
// inheritance
PseudoElement.ancestor = _PseudoElement;
PseudoElement.prototype = new _PseudoElement;
// class methods
PseudoElement.ID = function(match, selector, position, cssText) {
	return new PseudoElement(selector, position, cssText);
};
PseudoElement.ALL = /([^}]*):(before|after)[^{]*\{([^}]*)\}/g;
PseudoElement.CONTENT = /content\s*:\s*([^;]*)(;|$)/;
PseudoElement.OBJECT = "<object class=ie7_anon data='" + makePath("ie7-content.htm", path) +
"' width=100% height=0 type=text/x-scriptlet>";

// -----------------------------------------------------------------------
// selectors
// -----------------------------------------------------------------------

// child selector
selectors[">"] = function(filtered, from, filter, scopeName) {
	for (var i = 0; i < from.length; i++) {
		var subset = from[i].children;
		for (var j = 0; j < subset.length; j++)
			if (compareTagName(subset[j], filter, scopeName)) push(filtered, subset[j]);
	}
};

// sibling selector
selectors["+"] = function(filtered, from, filter, scopeName) {
	for (var i = 0; i < from.length; i++) {
		var adjacent = nextElement(from[i]);
		if (adjacent && compareTagName(adjacent, filter, scopeName)) push(filtered, adjacent);
	}
};

// attribute selector
selectors["@"] = function(filtered, from, filter) {
	filter = attributeSelectors[filter];
	for (var i = 0; i < from.length; i++) if (filter(from[i])) push(filtered, from[i]);
};

// -----------------------------------------------------------------------
// pseudo-classes
// -----------------------------------------------------------------------

pseudoClasses["first-child"] = function(element) {
	return !previousElement(element);
};

pseudoClasses["lang"] = function(element, filterArgs) {
	filterArgs = new RegExp("^" + filterArgs, "i");
	while (element && !element.getAttribute("lang")) element = element.parentNode;
	return element && filterArgs.test(element.getAttribute("lang"));
};

dynamicPseudoClasses.hover = function(element) {
	var instance = arguments;
	addEventHandler(element, "onmouseover", function() {
		IE7.Event.hover.register(instance);
	});
	addEventHandler(element, "onmouseout", function() {
		IE7.Event.hover.unregister(instance);
	});
};

dynamicPseudoClasses.active = function(element) {
	var instance = arguments;
	addEventHandler(element, "onmousedown", function() {
		IE7.Event.active.register(instance);
	});
};

dynamicPseudoClasses.focus = function(element) {
	var instance = arguments;
	addEventHandler(element, "onfocus", function() {
		IE7.Event.focus.register(instance);
	});
	addEventHandler(element, "onblur", function() {
		IE7.Event.focus.unregister(instance);
	});
	// check focus of the active element
	if (element == document.activeElement) {
		IE7.Event.focus.register(instance)
	}
};

// globally trap the mouseup event (thanks Martijn!)
addEventHandler(document, "onmouseup", function() {
	var ie7Event = IE7.Event.active;
	var instances = ie7Event.instances, i;
	for (i in instances) ie7Event.unregister(instances[i]);
	ie7Event = IE7.Event.hover;
	instances = ie7Event.instances;
	for (i in instances)
		if (!instances[i][0].contains(event.srcElement))
			ie7Event.unregister(instances[i]);
});

// -----------------------------------------------------------------------
//  attribute selectors
// -----------------------------------------------------------------------

var attributeSelectors = [];

var ESCAPE = /([\/()[\]?{}|*+])/g;

function AttributeSelector(attribute, compare, value) {
	// properties
	value = getString(value);
	this.id = attributeSelectors.length;
	// build the test expression
	switch (attribute.toLowerCase()) {
		case "id":
			attribute = "element.id.replace(/ms_\\d+/g,'')";
			break;
		case "class":
			attribute = "element.className.replace(/\\b\\s*ie7_\\d+/g,'')";
			break;
		default:
			attribute = "element.getAttribute('" + attribute + "')";
	}
	// continue building the test expression
	compare = attributeTests[compare];
	push(attributeSelectors, new Function("element", "return " + compare(attribute, value)));
};
AttributeSelector.ID = function(match, attribute, compare, value) {
	return new AttributeSelector(attribute, compare, value);
};
AttributeSelector.prototype.toString = function() {
	return AttributeSelector.PREFIX + this.id;
};
attributeTests = {
	toString: function() {
		var toString = [];
		for (var i in this) if (i && i != "escape") push(toString, i);
		return toString.join("").replace(/=/g, "");

	},
	escape: function(value) {
		return value.replace(ESCAPE, "\\$1");
	},
	"": function(attribute) {
		return attribute;
	},
	"=": function(attribute, value) {
		return attribute + "==" + quote(value);
	},
	"~=": function(attribute, value) {
		return "/(^|\\s)" + attributeTests.escape(value) + "(\\s|$)/.test(" + attribute + ")";
	},
	"|=": function(attribute, value) {
		return "/^" + attributeTests.escape(value) + "(-|$)/.test(" + attribute + ")";
	}
};
// constants
AttributeSelector.PREFIX = "@";

// -----------------------------------------------------------------------
//  IE7 events
// -----------------------------------------------------------------------

// virtual
function _ie7Event() {
	// properties
//- this.type = "";
//- this.instances = null;
	// methods
	this.register = function(instance) {
		// an "instance" is actually an Arguments object
		var element = instance[0];
		var target = instance[1];
		var Class = instance[2];
		for (var i = 0; i < target.length; i++) Class.add(target[i]);
		this.instances[Class.id + element.uniqueID] = instance;
	};
	this.unregister = function(instance) {
		var element = instance[0];
		var target = instance[1];
		var Class = instance[2];
		for (var i = 0; i < target.length; i++) Class.remove(target[i]);
		delete this.instances[Class.id + element.uniqueID];
	};
};

// constructor
IE7.Event = function(type) {
	this.type = type;
	this.instances = {};
	IE7.Event[type] = this;
};
// inheritance
IE7.Event.prototype = new _ie7Event;

// ie7 events
new IE7.Event("hover");
new IE7.Event("active");
new IE7.Event("focus");

// -----------------------------------------------------------------------
// generic functions
// -----------------------------------------------------------------------

function simpleSelector(selector) {
	// attempt to preserve specificity for "loose" parsing by
	//  removing unknown tokens from a css selector but keep as
	//  much as we can..
	return selector.replace(Class.COMPLEX, "").replace(CHILD, " ");
};

}, true);

IE7.addModule("ie7-png", function() {
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

IE7.addModule("ie7-fixed", function() {
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

loaded = true;

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
