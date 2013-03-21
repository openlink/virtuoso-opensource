/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2013 OpenLink Software
 *
 *  See LICENSE file for details.
 */

var OAT = {
    base: "",

    /**
     * Initialize OAT
     */
    init: function() {
	OAT.Event.attach(window, "load", this._onload); /* listen for window.onload */
	var nodes = document.getElementsByTagName("script"); /* locate self */
	for (var i=0;i<nodes.length;i++) {
	    var s = nodes[i];
	    var re = s.src.match(/^(.*)(oat|loader)\.js$/);
	    if (re) {
		this.base = re[1];
		this._initialLoad(); /* load initial features */
		return;
	    }
	}
	throw new Error("OAT cannot find itself");
    },

    _loaded: false,
    _winloaded: false,

    /**
     * Is everything ready to call window.init ?
     */

    _checkInit: function() {
	if (!this._loaded || !this._winloaded) { return; }
	if (typeof(window.init) == "function") { window.init(); }
    },

    /**
     * window.onload happened
     */

    _onload: function() {
		OAT._winloaded = true;
	OAT._checkInit();
    },

    /**
     * All initial features are loaded
     */

    _initialLoaded: function() {
	OAT._loaded = true;
	OAT.MSG.send(OAT, "OAT_LOADED", null);
	OAT.MSG.send(OAT, "OAT_LOAD", null); // XXX: Backward-compat hack
	OAT._checkInit();
    },

    /**
     * Load features initialy specified in window.featureList
*/

    _initialLoad: function() {
	if (window.featureList && window.featureList.length) {
	    this.Loader.load(window.featureList, this._initialLoaded);
	} else {
	    this._initialLoaded();
	}
    }
};

/**
 * @namespace
 */

OAT.Preferences = {
    showAjax: 1, /* show Ajax window even if not explicitly requested by application? */
    useCursors: 1, /* scrollable cursors */
    windowTypeOverride: 0, /* do not guess window type */
    xsltPath: "/DAV/JS/xslt/",
    imagePath: "/DAV/JS/images/",
    stylePath: "/DAV/JS/styles/",
    endpointXmla: "/XMLA",
    version: "2.9.4",
    build: "$Date: 2012/08/16 10:26:11 $",
    httpError: 1, /* show http errors */
    allowDefaultResize: 1,
    allowDefaultDrag: 1
}

OAT.Debug = {
    levels: {
	WARNING: 1,
	ERROR: 2,
	CRITICAL: 3 },

    level_msg: ["OAT Warning",
		"OAT Error",
		"OAT Critical"],

    log: function (lvl,msg) {
	if (!!window.console && OAT.Preferences.debug) {
	    window.console.log (OAT.Debug.level_msg[lvl] + ': ' + msg);
	}
    },

    reportObsolete: function (where) {
	OAT.Debug.log (OAT.Debug.levels.WARNING,'Obsolete call: ' + where)
	OAT.MSG.send (OAT,'OBSOLETE_CALL',where);
    }
};


OAT.ApiKeys = {
    services: {
        gmapapi: {
            /* key domain : key */
        }
    },

    addKey:function(svc,url,key) {
        if (svc in this.services) {
            this.services[svc][url] = key;
        } else {
            var entry = {};
	    entry[url] = key;
            this.services[svc] = entry;
        }
    },

    getKey:function(svc) {
        var services = OAT.ApiKeys.services;
        var href = window.location.href;

        if (!svc in services) { return false; }

        for (var url in services[svc]) {
            var key = services[svc][url];
            if(href.match(url)) { return key; }
        }
        return false;
    }
}

/**
 * provides a shortcut for getElementById
 * @param something dom node, string id, or array of nodes/id's
 * @returns single or array of matching dom nodes
 */

function $(something) {
    if (typeof(something) == "string") {
	var elm = document.getElementById(something);
    } else {
	var elm = something;
    }
    if (something instanceof Array) {
	var elm = [];
	for (var i=0;i<something.length;i++) { elm.push($(something[i])); }
    }
    if (!elm) return false;
    return elm;
}

/**
 * Returns list of elements belonging to given class.
 * Optional root tag whose children will be searched (document by
 * default) and tag type (all tags by default) can be specified.
 * Prior to 2.8, this function was identical to $v(), please update
 * your code to reflect this change and use $v() where appropriate.
 * @param {string} className name of the class to match
 * @param {node} root optional root element
 * @param {string} tag optional elements of this tag only will be matched
 * @returns {array} of matching elements
 * @since 2.8
 */

function $$(className, root, tag) {
    var e = $(root) || document;
    var tag = tag || "*";

    var elms = e.getElementsByTagName(tag);
    var matches = [];

    if (OAT.Dom.isClass(e,className)) { matches.push(e); }
    for(var i=0;i<elms.length;i++) {
	if(OAT.Dom.isClass(elms[i],className)) { matches.push(elms[i]); }
    }
    return matches;
}

/**
 * returns a value of the element. equivalent to $().value
 * @param string id or node
 * @returns node value, or false if no such element exists or has
 * no value property
 */

function $v(something) {
    var e = $(something);
    if (!e) return false;
    if (!("value" in e)) return false;
    return e.value;
}

/**
 * check if obj is an array
 * @param obj (suspected) array obj
 * @returns true if obj is an array
 */

function isArray(array) { return !!(array && array.constructor == Array); }

/**
 * backward compatibility function,
 * see https://developer.mozilla.org/en/New_in_JavaScript_1.6
 * for details
 */

if (!Array.prototype.indexOf) {
    Array.prototype.indexOf = function(item, from) {
	var len = this.length;
	var i = from || 0;
	if (i < 0) { i += len; }
	for (;i<len;i++) {
	    if (i in this && this[i] === item) { return i; }
	}
	return -1;
    }
}

if (!Array.indexOf) {
    Array.indexOf = function(obj, item, from) { return Array.prototype.indexOf.call(obj, item, from); }
}

/**
 * backward compatibility function,
 * see https://developer.mozilla.org/en/New_in_JavaScript_1.6
 * For details
 */

if (!Array.prototype.lastIndexOf) {
    Array.prototype.lastIndexOf = function(item, from) {
	var len = this.length;
	var i = from || len-1;
	if (i < 0) { i += len; }
	for (;i>-1;i--) {
	    if (i in this && this[i] === item) { return i; }
	}
	return -1;
    }
}

if (!Array.lastIndexOf) {
    Array.lastIndexOf = function(obj, item, from) { return Array.prototype.lastIndexOf.call(obj, item, from); }
}

/**
 * backward compatibility function,
 * see https://developer.mozilla.org/en/New_in_JavaScript_1.6
 * for details
 */

if (!Array.prototype.forEach) {
    Array.prototype.forEach = function(cb, _this) {
	var len = this.length;
	for (var i=0;i<len;i++) {
	    if (i in this) { cb.call(_this, this[i], i, this); }
	}
    }
}

if (!Array.forEach) {
    Array.forEach = function(obj, cb, _this) { Array.prototype.forEach.call(obj, cb, _this); }
}

/**
 * backward compatibility function,
 * see https://developer.mozilla.org/en/New_in_JavaScript_1.6
 * for details
 */

if (!Array.prototype.every) {
    Array.prototype.every = function(cb, _this) {
	var len = this.length;
	for (var i=0;i<len;i++) {
	    if (i in this && !cb.call(_this, this[i], i, this)) { return false; }
	}
	return true;
    }
}

if (!Array.every) {
    Array.every = function(obj, cb, _this) { return Array.prototype.every.call(obj, cb, _this); }
}

/**
 * backward compatibility function,
 * see https://developer.mozilla.org/en/New_in_JavaScript_1.6
 * for details
 */

if (!Array.prototype.some) {
    Array.prototype.some = function(cb, _this) {
	var len = this.length;
	for (var i=0;i<len;i++) {
	    if (i in this && cb.call(_this, this[i], i, this)) { return true; }
	}
	return false;
    }
}

if (!Array.some) {
    Array.some = function(obj, cb, _this) { return Array.prototype.some.call(obj, cb, _this); }
}

/**
 * backward compatibility function,
 * see https://developer.mozilla.org/en/New_in_JavaScript_1.6
 * for details
 */

if (!Array.prototype.map) {
    Array.prototype.map = function(cb, _this) {
	var len = this.length;
	var res = new Array(len);
	for (var i=0;i<len;i++) {
	    if (i in this) { res[i] = cb.call(_this, this[i], i, this); }
	}
	return res;
    }
}

if (!Array.map) {
    Array.map = function(obj, cb, _this) { return Array.prototype.map.call(obj, cb, _this); }
}

/**
 * backward compatibility function,
 * see https://developer.mozilla.org/en/New_in_JavaScript_1.6
 * for details
 */

if (!Array.prototype.filter) {
    Array.prototype.filter = function(cb, _this) {
	var len = this.length;
	var res = [];
	for (var i=0;i<len;i++) {
	    if (i in this) {
		var val = this[i];
		if (cb.call(_this, val, i, this)) { res.push(val); }
	    }
	}
	return res;
    }
}

if (!Array.filter) {
    Array.filter = function(obj, cb, _this) { return Array.prototype.filter.call(obj, cb, _this); }
}

/**
 * find a string in array of strings
 * @param {str} string to find
 * @returns {integer} index of array containing first matching elem or -1 if none found
 */

Array.prototype.find = function(str) {
	for (var i=0;i<this.length;i++) if (this[i] == str) { return i; }
	return -1;
}

/**
 * copy an array
 * @returns {array} copy of this
 */

Array.prototype.copy = function() {
    var a = [];
    for (var i=0;i<this.length;i++) { a.push(this[i]); }
    return a;
}

/**
 * appends elements to this array
 * @param {array} arr object or array to append
 */

Array.prototype.append = function(arr) {
    var a = arr;
    if (!(arr instanceof Array)) { a = [arr]; }
    for (var i=0;i<a.length;i++) { this.push(a[i]); }
}

/**
 * removes whitespace from start and end of the string
 * @returns {string} trimmed string
 */

String.prototype.trim = function() {
    return this.match(/^\s*([\s\S]*?)\s*$/)[1];
}

/**
 * returns a string repeated n-times
 * @param {integer} times number of repetitions
 * @returns repeated string, or empty string if times is zero
 */

String.prototype.repeat = function(times) {
	var ret = '';
	for (var i=0;i<times;i++) { ret += this; }
	return ret;
}

/**
 * pads string with zeros (from left) to specified length
 * @param length final string length
 * @returns padded string
 */

String.prototype.leadingZero = function(length) {
    var l = (length ? length : 2);
    var tmp = this;
    while (tmp.length < l)  { tmp = "0"+tmp; }
    return tmp.toString();
}

/**
 * returns string truncated to maxlength or 20 if not specified
 * @returns {string} truncated string
 * @param {integer} maxlen maximum length of new string
 */

String.prototype.truncate = function(maxlen) {
    var str = this.trim();
    if (!maxlen || maxlen < 2)
	maxlen = 20;
    if (str.length <= maxlen)
	return this;
    var half = Math.floor(maxlen / 2);
    return str.substr(0, half) + "..." + str.substr(length-half); /* IE does not support negative numbers in substr */
}

/**
 * returns number represented as file size in human readable form
 *  (B,kB,MB,GB,TB)
 * @returns {string} size
 */

Number.prototype.toSize = function() {
    var post = ["B","kB","MB","GB","TB"];
    var stepSize = 1024;
    var result = this;
    for (var i=0;i<post.length;i++) {
	if (result >= stepSize && i+1 < post.length) {
	    result = result / stepSize;
	} else { return Math.round(result) + " " + post[i]; }
    }
    return this;
}

/**
 * adds suport for date formatting
 * @param {string} formatStr
 *  d day of month, zero padded
 *  g hours, 12 hour cycle
 *  G hours, 24 hour cycle
 *  h hours, 12 hour cycle, zero padded
 *  H hours, 24 hour cycle, zero padded
 *  i minutes, zero padded
 *  j day of month
 *  m month (01 = Jan, 02 = Feb..), zero padded
 *  n month (1 = Jan, 2 = Feb)
 *  s seconds, zero padded
 *  U seconds since Unix Epoch
 *  w day of the week (0 Sunday, 6 Saturday)
 *  Y full year, e.g. 2008
 *  x milliseconds, zero padded
 * @returns {string} formated date
 */

Date.prototype.format = function(formatStr) {
    var result = formatStr;
    result = result.replace(/d/,this.getDate().toString().leadingZero(2));
    result = result.replace(/g/,parseInt(this.getHours()) % 12);
    result = result.replace(/G/,this.getHours());
    result = result.replace(/h/,(parseInt(this.getHours()) % 12).toString().leadingZero(2));
    result = result.replace(/H/,this.getHours().toString().leadingZero(2));
    result = result.replace(/i/,this.getMinutes().toString().leadingZero(2));
    result = result.replace(/j/,this.getDate());
    result = result.replace(/m/,(this.getMonth()+1).toString().leadingZero(2));
    result = result.replace(/n/,this.getMonth()+1);
    result = result.replace(/s/,this.getSeconds().toString().leadingZero(2));
    result = result.replace(/U/,this.getTime());
    result = result.replace(/w/,this.getDay());
    result = result.replace(/Y/,this.getFullYear());
    result = result.replace(/x/,this.getMilliseconds().toString().leadingZero(3));
    return result;
}

/**
 * returns date as string in human-readable format j.n.Y H:i:s
 * @returns {string} formated date
 */

Date.prototype.toHumanString = function() {
    return this.format("j.n.Y H:i:s");
}

/**
 * @namespace DOM common functions
 */

OAT.Dom = {
    /**
     * creates arbitrary element with specified DOM/style attributes and class
     * @param {string} tagName tag name of the element
     * @param {object} obj key:value pairs to be set as properties of node or node.style
     * @param {className} backwards compatibility classname shortcut..
     * @returns {object} new element
     */

    create:function(tagName,obj,className) {
	var elm = document.createElement(tagName);

	if (!obj) { return elm; }

	for (p in obj) {
	    var value = obj[p];
	    if (p == "class") { p = "className"; }
	    if (p in elm) { elm[p] = value; }
	}

	if (className) elm["className"] = className;

	OAT.Style.set(elm,obj);
	return elm;
    },

    /**
     * creates element in specified namespace
     * @param {string} ns element namespace
     * @param {string} tagName element tag name
     * @returns {node} new element
     */

    createNS:function(ns,tagName) {
	if (document.createElementNS) {
	    var elm = document.createElementNS(ns,tagName);
	} else {
	    var elm = document.createElement(tagName);
	    elm.setAttribute("xmlns",ns);
	}
	return elm;
    },

    /**
     * creates text element
     * @param {string} text text node content
     * @returns {node} new text element
     */

    text:function(text) {
	return document.createTextNode(text);
    },

    /**
     * creates image element
     * @param {string} src image source url
     * @param {string} srcBlank
     * @param {integer} w image width
     * @param {integer} h image height
     * @returns {node} new image node
     */

    image:function(src,srcBlank,w,h) {
	var o = {};

        if (w) { o["width"] = w; }
	if (h) { o["height"] = h; }

	var elm = OAT.Dom.create("img",o);

	OAT.Dom.imageSrc(elm,src,srcBlank);
	return elm;
    },

    imageSrc:function(element,src,srcBlank) {
	var elm = $(element);
	var png = !!src.toLowerCase().match(/png$/);
	if (png && OAT.Browser.isIE6) {
	    if (!srcBlank) { srcBlank = OAT.Preferences.imagePath+'Blank.gif'; }
	    elm.src = srcBlank;
	    elm.style.filter = "progid:DXImageTransform.Microsoft.AlphaImageLoader(src='"+src+"', sizingMethod='image')";
	} else {
	    elm.src = src;
	}
    },

    /**
     * creates option element and optionally attach it to parent select
     * @param {string} name name attribute value
     * @param {string} value value of the option
     * @param {node} parent parent (select) node
     * @returns {node} new option node
     */

    option:function(name,value,parent) {
	var opt = OAT.Dom.create("option");
	opt.innerHTML = name;
	opt.value = value;
	if (parent) { $(parent).appendChild(opt); }
	return opt;
    },

    append:function() {
	for (var i=0;i<arguments.length;i++) {
	    var arr = arguments[i];
	    if (!(arr instanceof Array)) { continue; }
	    if (arr.length < 2) { continue; }
	    var parent = $(arr[0]);
	    for (var j=1;j<arr.length;j++) {
		var children = arr[j];
		if (!(children instanceof Array)) { children = [children]; }
		for (var k=0;k<children.length;k++) {
		    var child = children[k];
		    parent.appendChild($(child));
		}
	    }
	}
    },

    /**
     * hides one or more elements
     * @param {node} element single element or array of elements. function also
     * accepts variable number of arguments
     */

    hide:function(element) {
	if (arguments.length > 1) {
	    for (var i=0;i<arguments.length;i++) { OAT.Dom.hide(arguments[i]); }
	    return;
	}
	if (element instanceof Array) {
	    for (var i=0;i<element.length;i++) { OAT.Dom.hide(element[i]); }
	    return;
	}
	var elm = $(element);
	if (!elm) { return; }
	/* ie input hack */
	var inputs_ = elm.getElementsByTagName("input");
	var inputs = [];
	for (var i=0;i<inputs_.length;i++) { inputs.push(inputs_[i]); }
	if (elm.tagName.toLowerCase() == "input") { inputs.push(elm); }
	for (var i=0;i<inputs.length;i++) {
	    var inp = inputs[i];
	    if (inp.type == "radio" || inp.type == "checkbox") {
		if (!inp.__checked) { inp.__checked = (inp.checked ? "1" : "0"); }
	    }
	}
	/* */
	elm.style.display = "none";
    },

    /**
     * shows one or more hidden elements
     * @param {node} element single element or array of elements. function also
     * accepts variable number of arguments
     */

    show:function(element) {
	if (arguments.length > 1) {
	    for (var i=0;i<arguments.length;i++) { OAT.Dom.show(arguments[i]); }
	    return;
	}
	if (element instanceof Array) {
	    for (var i=0;i<element.length;i++) { OAT.Dom.show(element[i]); }
	    return;
	}
	var elm = $(element);
	if (!elm) { return; }
	elm.style.display = "";
	/* ie input hack */
	var inputs_ = elm.getElementsByTagName("input");
	var inputs = [];
	for (var i=0;i<inputs_.length;i++) { inputs.push(inputs_[i]); }
	if (elm.tagName.toLowerCase() == "input") { inputs.push(elm); }
	for (var i=0;i<inputs.length;i++) {
	    var inp = inputs[i];
	    if (inp.type == "radio" || inp.type == "checkbox") {
		if (inp["__checked"] && inp.__checked === "1") { inp.checked = true; }
		if (inp["__checked"] && inp.__checked === "0") { inp.checked = false; }
		inp.__checked = false;
	    }
	}
	/* */
    },

    /**
     * removes all children of an element
     * @param {node} element to be cleared
     */

    clear:function(element) {
	var elm = $(element);
	while (elm.firstChild) { elm.removeChild(elm.firstChild); }
    },

    /**
     * removes an element
     * @param {node} element element to be removed
     */

    unlink:function(element) {
	var elm = $(element);
	if (!elm) { return; } /* invalid element */
	if (!elm.parentNode) { return; } /* no parent */
	if (elm.parentNode.nodeType != 1) { return; } /* parent is document fragment */
	elm.parentNode.removeChild(elm);
    },

    /**
     * centers an element along x and/or y axis according to reference
     * @param {node} element element to be centered
     * @param {integer} x true/false center along x axis
     * @param {integer} y true/false center along y axis
     * @param {node} reference reference element for centering (default is offsetParent)
     */

    center:function(element,x,y,reference) {
	var elm = $(element);
	var p = elm.offsetParent;
	if (reference) { p = reference; }
	if (!p) { return; }
	var par_dims = (p == document.body || p.tagName.toLowerCase() == "html" ? OAT.Dom.getViewport() : OAT.Dom.getWH(p));
	var dims = OAT.Dom.getWH(elm);
	var new_x = Math.round(par_dims[0]/2 - dims[0]/2);
	var new_y = Math.round(par_dims[1]/2 - dims[1]/2);
	if (new_y < 0) { new_y = 30; }
	var s = OAT.Dom.getScroll();
	if (p == document.body || p.tagName.toLowerCase() == "html") {
	    new_x += s[0];
	    new_y += s[1];
	}
	if (x) { elm.style.left = new_x + "px"; }
	if (y) { elm.style.top = new_y + "px"; }
    },

    /**
     * checks if child is in the subtree of parent
     * @param {node} child
     * @param {node} parent
     * @returns true if parent matches, false if not or node is in detached subtree
     */

    isChild:function(child, parent) {
	var c_elm = $(child);
	var p_elm = $(parent);
	/* walk up from the child. if we find parent element, return true */
	var node = c_elm.parentNode;
	do {
	    if (!node) { return false; }
	    if (node == p_elm) { return true; }
	    node = node.parentNode;
	} while (node != document.body && node != document);
	return false;
    },

    /**
     * returns color string as RGB triple. string starting with # is
     * treated like hexadecimal color representation
     * @param {string} str string that specifies the color
     * @returns {array} [r,g,b] triple in 0..255 range
     */

    color:function(str) {
	var hex2dec = function(hex) {	return parseInt(hex,16); }
	/* returns [col1,col2,col3] in decimal */
	if (str.match(/#/)) {
	    /* hex */
	    if (str.length == 4) {
		var tmpstr = "#"+str.charAt(1)+str.charAt(1)+str.charAt(2)+str.charAt(2)+str.charAt(3)+str.charAt(3);
	    } else {
		var tmpstr = str;
	    }
	    var tmp = tmpstr.match(/#(..)(..)(..)/);
	    return [hex2dec(tmp[1]),hex2dec(tmp[2]),hex2dec(tmp[3])];
	} else {
	    /* decimal */
	    var tmp = str.match(/\(([^,]*),([^,]*),([^\)]*)/);
	    return [parseInt(tmp[1]),parseInt(tmp[2]),parseInt(tmp[3])];
	}
    },

    /**
     * checks whether an element belongs to a given class
     * @param {node} something element to check
     * @param {string} className name of the class
     * @returns {boolean} true or false
     */

    isClass:function(something,className) {
	var elm = $(something);
	if (!elm) { return false; }
	if (className == "*") { return true; }
	if (className == "") { return false; }
	if (!elm.className || typeof(elm.className) != "string") { return false; }
	var arr = elm.className.split(" ");
	var index = arr.indexOf(className);
	return (index != -1);
    },

    /**
     * adds className to object's class attribute
     * @param {node} something element to alter
     * @param {string} className name of the class
     */

    addClass:function(something,className) {
	var elm = $(something);
	if (!elm) { return; }
	if (OAT.Dom.isClass(elm,className)) { return; }
	var arr = elm.className.split(" ");
	arr.push(className);
	if (arr[0] == "") { arr.splice(0,1); }
	elm.className = arr.join(" ");
    },

    /**
     * removes className from object's class attribute
     * @param {node} something element to alter
     * @param {string} className name of the class
     */

    removeClass:function(something,className) {
	var elm = $(something);
	if (!elm) { return; }
	if (!OAT.Dom.isClass(elm,className)) { return; } /* cannot remove non-existing class */
	if (className == "*") { elm.className = ""; } /* should not occur */
	var arr = elm.className.split(" ");
	var index = arr.indexOf(className);
	if (index == -1) { return; } /* should NOT occur! */
	arr.splice(index,1);
	elm.className = arr.join(" ");
    },

    getViewport:function() {
	if (OAT.Browser.isWebKit) {
	    return [window.innerWidth,window.innerHeight];
	}
	if (OAT.Browser.isOpera || document.compatMode == "BackCompat") {
	    return [document.body.clientWidth,document.body.clientHeight];
	} else {
	    return [document.documentElement.clientWidth,document.documentElement.clientHeight];
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

	/*
	this is interesting:
            Opera with no scrolling reports scrollLeft/Top equal to offsetLeft/Top for <input> elements
	*/

	var x = c[0];
	var y = c[1];

	if (!OAT.Browser.isOpera || elm.scrollTop != elm.offsetTop || elm.scrollLeft != elm.offsetLeft) {
	    x -= elm.scrollLeft;
	    y -= elm.scrollTop;
	}

	if (OAT.Browser.isWebKit && parent == document.body && OAT.Style.get(elm,"position") == "absolute") {
	    return [x,y];
	}

	x += parent_coords[0];
	y += parent_coords[1];
	return [x,y];
    },

    /**
     * returns coordinate of top left corner of an element
     * @param {node} element
     * @returns {array} [x,y] coordinates in pixels
     */

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

    /**
     * returns width and height of an element
     * @param {node} element
     * @returns {array} [width,height]
     */

    getWH:function(something) {
	var elm = $(something);
	return [elm.offsetWidth, elm.offsetHeight];
    },

    /**
     * moves element by specified amount
     * @param {node} element element to be moved
     * @param {integer} dx x-axis displacement
     * @param {integer} dy y-axis displacement
     */

    moveBy:function(element,dx,dy) {
	var curr_x,curr_y;
	var elm = $(element);

	/*
	If the element is not anchored to left top corner, strange things will happen during resizing;
	therefore, we need to make sure it is anchored properly.
	*/

	if (OAT.Style.get(elm,"position") == "absolute") {
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

    /**
     * resizes given element by specified amount
     * @param {node} element to be resized
     * @param {integer} x-axis size change
     * @param {integer} y-axis size change
     */

    resizeBy:function(element,dx,dy) {
	var curr_w, curr_h;
	var elm = $(element);
	/*
			If the element is not anchored to left top corner, strange things will happen during resizing;
			therefore, we need to make sure it is anchored properly.
		*/
	if (OAT.Style.get(elm,"position") == "absolute" && dx) {
	    if (!elm.style.left) {
		elm.style.left = elm.offsetLeft + "px";
		elm.style.right = "";
	    }
	    if (!elm.style.top && dy) {
		elm.style.top = elm.offsetTop + "px";
		elm.style.bottom = "";
	    }
	}
	var tmp = OAT.Dom.getWH(elm);
	var w = (elm.style.width && elm.style.width != "auto" ? parseInt(elm.style.width) : tmp[0]);
	var h = (elm.style.height && elm.style.height != "auto" ? parseInt(elm.style.height) : tmp[1]);
	w += dx;
	h += dy;
	if (dx) { elm.style.width = w + "px"; }
	if (dy) { elm.style.height = h + "px"; }
    },

    removeSelection:function() {
	var selObj = false;
	if (document.getSelection && !OAT.Browser.isGecko) { selObj = document.getSelection(); }
	if (window.getSelection) { selObj = window.getSelection(); }
	if (document.selection) { selObj = document.selection; }
	if (selObj) {
	    if (selObj.empty) { selObj.empty(); }
	    if (selObj.removeAllRanges) { selObj.removeAllRanges(); }
	}
    },

    getScroll:function() {
	if (OAT.Browser.isWebKit || (OAT.Browser.isIE && document.compatMode == "BackCompat")) {
	    var l = document.body.scrollLeft;
	    var t = document.body.scrollTop;
	} else {
	    var l = Math.max(document.documentElement.scrollLeft,document.body.scrollLeft);
	    var t = Math.max(document.documentElement.scrollTop,document.body.scrollTop);
	}
	return [l,t];
    },

    getFreeSpace:function(x,y) {
	var scroll = OAT.Dom.getScroll();
	var port = OAT.Dom.getViewport();
	var spaceLeft = x - scroll[0];
	var spaceRight = port[0] - x + scroll[0];
	var spaceTop = y - scroll[1];
	var spaceBottom = port[1] - y + scroll[1];
	var left = (spaceLeft > spaceRight);
	var top = (spaceTop > spaceBottom);
	return [left,top];

    },

    toSafeXML:function(str) {
	if (!str || (typeof(str) != "string")) { return str; }
	return str.replace(/&/g,"&amp;").replace(/>/g,"&gt;").replace(/</g,"&lt;");
    },

    fromSafeXML:function(str) {
	if (!str || (typeof(str) != "string")) { return str; }
	return str.replace(/&amp;/g,"&").replace(/&gt;/g,">").replace(/&lt;/g,"<");
    },

    uriParams:function() {
	var result = {};
	var s = location.search;
	if (s.length > 1) { s = s.substring(1); }
	if (!s) { return result; }
	var parts = s.split("&");
	for (var i=0; i < parts.length; i++) {
	    var part = parts[i];
	    if (!part) { continue; }
	    var index = part.indexOf("=");
	    if (index == -1) { result[decodeURIComponent(part)] = ""; continue; } /* not a pair */

	    var key = part.substring(0,index);
	    var val = part.substring(index+1);
	    key = decodeURIComponent(key);
	    val = decodeURIComponent(val.replace(/\+/g,  " "));

	    var r = false;
	    if ((r = key.match(/(.*)\[\]$/))) {
		key = r[1];
		if (key in result) {
		    result[key].push(val);
		} else {
		    result[key] = [val];
		}
	    } else {
		result[key] = val;
	    }
	}
	return result;
    },

    changeHref:function(elm,newHref) {
	/* opera cannot do this with elements not being part of the page :/ */
	var ok = false;
	var e = $(elm);
	var node = e;
	while (node.parentNode) {
	    node = node.parentNode;
	    if (node == document.body) { ok = true; }
	}
	if (ok) {
	    e.href = newHref;
	} else if (e.parentNode) {
	    var oldParent = e.parentNode;
	    var next = e.nextSibling;
	    document.body.appendChild(e);
	    e.href = newHref;
	    OAT.Dom.unlink(e);
	    oldParent.insertBefore(e,next);
	} else {
	    document.body.appendChild(e);
	    e.href = newHref;
	    OAT.Dom.unlink(e);
	}
    },

    /**
     * sets position to relative if it isn't absolute
     * @param {node} elm element
     */
    makePosition:function(elm) {
	var e = $(elm);
	if (OAT.Style.get(e,"position") != "absolute") {
	    e.style.position = "relative";
	}
    }
}

/**
 * @namespace Style helper
 */

OAT.Style = {
    /**
     * appends new stylesheet file to document
     * @param {string} file filename of the stylesheet
     * @param {integer} force force reloading even if stylesheet file already included
     */

    include:function(file,force) {
	if (!file) return;
	if (!file.match(/:\/\//)) {	file = OAT.Preferences.stylePath + file; }

	if (!force) { /* prevent loading when already loaded */
	    var styles = document.getElementsByTagName('link');
	    var host = location.protocol + '//' + location.host;
	    for (var i=0;i<styles.length;i++)
		if (file == styles[i].getAttribute('href') || host+file==styles[i].getAttribute('href'))
		    return;
	}

	var elm = OAT.Dom.create("link");
	elm.rel = "stylesheet";
	elm.rev = "stylesheet";
	elm.type = "text/css";
	elm.href = file;
	document.getElementsByTagName("head")[0].appendChild(elm);
    },

    /**
     * returns value of specified element style property
     * @param {node} elm element
     * @param {string} property property name
     * @returns {string} property value
     */

    get:function(elm,property) {
	var element = $(elm);
	if (document.defaultView && document.defaultView.getComputedStyle) {
	    var cs = document.defaultView.getComputedStyle(element,'');
	    if (!cs) { return true; }
	    return cs[property];
	} else {
	    try {
		var out = element.currentStyle[property];
	    } catch (e) {
		var out = element.getExpression(property);
	    }
	    return out;
	}
    },

    /**
     * sets css style attributes
     * @param {node} something element
     * @param {object} obj object with key:value property pairs
     */

    set:function(something, obj) {
	var elm = $(something);
	if (!elm) { return ; }

	for (var p in obj) {
	    var val = obj[p];
	    if (p == "float") {
		p = (OAT.Browser.isIE ? "styleFloat" : "cssFloat");
	    }
	    if (p == "opacity") {
		val = Math.max(val,0);
		if (OAT.Browser.isIE) {
		    p = "filter";
		    val = "alpha(opacity="+Math.round(100*val)+")";
		    elm.style.zoom = 1;
		}
	    }
	    if (p in elm.style) { elm.style[p] = val; }
	}
    },

    /**
     * Backwards compat -
     * @param {element} something element
     * @param {opacity} opacity value
     */

    opacity:function(element,opacity) {
	var o = Math.max(opacity,0);
	var elm = $(element);
	if (OAT.Browser.isIE) {
	    elm.style.filter = "alpha(opacity="+Math.round(o*100)+")";
	} else {
	    elm.style.opacity = o;
	}
    }

}

/**
 * @namespace browser helper
 */

OAT.Browser = {
    isKonqueror:!!navigator.userAgent.match(/konqueror/i),
    isKHTML:!!navigator.userAgent.match(/khtml/i),

    isIE: !!navigator.userAgent.match(/msie/i),
    isIE6:!!navigator.userAgent.match(/msie 6/i),
    isIE7:!!navigator.userAgent.match(/msie 7/i),
    isIE8:!!navigator.userAgent.match(/msie 8/i),
    isIE9:!!navigator.userAgent.match(/msie 9/i),

    /* !isIE && !isIE7 */

    isGecko:(!navigator.userAgent.match(/khtml/i) && !!navigator.userAgent.match(/Gecko/i)),

    isOpera:!!navigator.userAgent.match(/Opera/),
    isWebKit:!!navigator.userAgent.match(/AppleWebKit/),

    /* OS detection */
    isMac:!!navigator.platform.toString().match(/mac/i),
    isLinux:!!navigator.platform.toString().match(/linux/i),
    isWindows:!!navigator.userAgent.match(/windows/i),

    /* mozilla chrome */
    isChrome:function() {
	try {
	    if (Components.classes)
		return true;
	    else
		return false;
	} catch(e) {
	    return false;
	}
    },

    isIphone:!!navigator.platform.toString().match(/iphone/i),
    isIpod:!!navigator.platform.toString().match(/ipod/i),
    isSymbian:!!navigator.platform.toString().match(/symbian/i),
    isS60:!!navigator.platform.toString().match(/series60/i),
    isAndroid:!!navigator.userAgent.match(/android/i),

    isScreenOnly:(!!navigator.platform.toString().match(/iphone/i) ||
		  !!navigator.platform.toString().match(/symbian/i) ||
		  !!navigator.platform.toString().match(/ipod/i) ||
		  !!navigator.userAgent.match(/android/i)),

    hasXmlParser: ((!!document.implementation && 
		    !!document.implementation.createDocument) ||
		   (!!document.getImplementation &&
		    !!document.getImplementation().createDocument)),

    hasSVG:(!!document.implementation && 
            document.implementation.hasFeature("http://www.w3.org/TR/SVG11/feature#BasicStructure", "1.1")),
    hasHtml5Storage: function () {
	try {
	    return 'localStorage' in window && window['localStorage'] !== null;
	}
	catch (e) {
	    return false;
	}
    }
    
}



/**
 * @namespace Event helper
 */

OAT.Event = {
    /**
     * attaches event to a given element, optionally with a callback
     * and/or scope from which the callback will be executed
     * @param {node} elm attach the event to this element
     * @param {event} event event to be attached
     * @param {function} callback callback to execute when event fires up
     * @param {object} scope scope object
     */

    attach:function(elm,event,callback,scope) {
	var element = $(elm);
	var cb = callback;

	if (scope) { cb = function() { return callback.call(scope,arguments); } }

	if (element.addEventListener) {	/* gecko */
	    element.addEventListener(event,cb,false);
	} else if (element.attachEvent) { /* ie */
	    element.attachEvent("on"+event,cb);
	} else { /* ??? */
	    element["on"+event] = cb;
	}
    },

    /**
     * detaches an event from given element
     * @param {node} elm detach event from this element
     * @param {object} event event to be detached
     * @param {function} callback event callback
     */

    detach:function(elm,event,callback) {
	var element = $(elm);
	if (element.removeEventListener) { /* gecko */
	    element.removeEventListener(event,callback,false);
	} else if (element.detachEvent) { /* ie */
	    element.detachEvent("on"+event,callback);
	} else { /* ??? */
	    element["on"+event] = false;
	}
    },

    /**
     * returns event source element
     * @returns {node} event source
     */

    source:function(event) {
	return (event.target ? event.target : event.srcElement);
    },

    /**
     * cancels event propagation up the event tree
     */

    cancel:function(event) {
	event.cancelBubble = true;
	if (event.stopPropagation) { event.stopPropagation(); }
    },

    /**
     * returns position of the event
     * @returns {array} [x,y]
     */

    position:function(event) {
	var scroll = OAT.Dom.getScroll();
	return [event.clientX+scroll[0],event.clientY+scroll[1]];
    },

    /**
     * prevents default browser action for given event
     */

    prevent:function(event) {
	if (event.preventDefault) { event.preventDefault(); }
	event.returnValue = false;
    }
}

/**
 * @namespace Messages
 */

OAT.MSG = {
    DEBUG:"DEBUG",
    OAT_DEBUG:"OAT_DEBUG",
    OAT_LOAD:"OAT_LOAD",
    ANIMATION_STOP:"ANIMATION_STOP",
    TREE_EXPAND:"TREE_EXPAND",
    TREE_COLLAPSE:"TREE_COLLAPSE",
    DS_RECORD_PREADVANCE:"DS_RECORD_PREADVANCE",
    DS_RECORD_ADVANCE:"DS_RECORD_ADVANCE",
    DS_PAGE_PREADVANCE:"DS_PAGE_PREADVANCE",
    DS_PAGE_ADVANCE:"DS_PAGE_ADVANCE",
    AJAX_START:"AJAX_START",
    AJAX_ERROR:"AJAX_ERROR",
    AJAX_TIMEOUT:"AJAX_TIMEOUT",
    GD_START:"GD_START",
    GD_ABORT:"GD_ABORT",
    GD_END:"GD_END",
    DOCK_DRAG:"DOCK_DRAG",
    DOCK_REMOVE:"DOCK_REMOVE",
    SLB_OPENED:"SLB_OPENED",
    SLB_CLOSED:"SLB_CLOSED",
    GRID_CELLCLICK:"GRID_CELLCLICK",
    GRID_ROWCLICK:"GRID_ROWCLICK",
    API_LOADING:"API_LOADING",
    API_LOADED:"API_LOADED",
    STORE_LOADING:"STORE_LOADING",
    STORE_LOADED:"STORE_LOADED",
    STORE_LOAD_FAILED:"STORE_LOAD_FAILED",
    STORE_ENABLED:"STORE_ENABLED",
    STORE_DISABLED:"STORE_DISABLED",
    STORE_CLEARED:"STORE_CLEARED",
    STORE_REMOVED:"STORE_REMOVED",
    RDFMINI_VIEW_CHANGED:"RDFMINI_VIEW_CHANGED",
    registry:[],

    /**
     * adds new listener to registry
     * @param {string || object} sender listen to messages from this sender, "*" for everyone
     * @param {string} msg listen to this message, "*" for any
     * @param {function} callback callback to execute upon message retrieval
     */

    attach:function(sender, msg, callback) {
	if (!sender) { return; }
	if (!callback || typeof callback == "undefined") {
	    throw (new Error ("OAT.MSG.attach requires callback function."));
	}

	OAT.MSG.registry.push([sender, msg, callback]);
    },

    /**
     * removes listener from registry
     * @param {string || object} sender message's sender or "*"
     * @param {string} msg message
     * @param {function} callback callback to execute upon message retrieval
     */

    detach:function(sender, msg, callback) {
	if (!sender) { return; }
	var index = -1;
	for (var i=0;i<OAT.MSG.registry.length;i++) {
	    var rec = OAT.MSG.registry[i];
	    if (rec[0] == sender && rec[1] == msg && rec[2] == callback) { index = i; }
	}
	if (index != -1) { OAT.MSG.registry.splice(index,1); }
    },

    /**
     * dispatches new message
     * @param {object} sender message sender
     * @param {message code} msg message string or numeric code
     * @param {event} event message event
     */

    send:function(sender, msg, event) {
	for (var i=0;i<OAT.MSG.registry.length;i++) {
	    var record = OAT.MSG.registry[i];
	    var senderOK = (sender == record[0] || record[0] == "*");
	    if (!senderOK) { continue; }
	    var msgOK = (msg == record[1] || record[1] == "*");
	    if (msgOK) { record[2](sender, msg, event); }
	} /* for all listeners */
    } /* send message */
}

/**
 * @namespace Loading
 * @message LOADER_LOADING
 * @message LOADER_LOADED
 */

OAT.Loader = {
    _loaded: [], /* already loaded modules */
    _callbacks: {}, /* array of callbacks for each module */
    _cacheBuster: false,

    /**
     * Module finished loading, execute all its callbacks
     * @param {string} name
     */

    _finished: function(name) {
	this._loaded.push(name);
	var arr = this._callbacks[name];
	for (var i=0;i<arr.length;i++) { arr[i](); }
        delete this._callbacks[name];
    },

    /**
     * Create script file name
     * @param {string} name Module name
     */

    _createPath: function(name) {
	var url = "";
	if (name.match(/:\/\//)) { /* strings with "://" are considered absolute */
	    url = name;
	} else {
	    url = OAT.base+name+".js";
	}
	if (this._cacheBuster) {
	    url += (url.indexOf("?") == -1 ? "?" : "&") + Math.random();
	}
	return url;
    },

    /**
     * Creates script node and adds event listener
     * @param {string} name Module name
     */

    _createNode: function(name) {
	var script = document.createElement("script");
	script.type = "text/javascript";

	var loader = this;
	if (script.addEventListener) {
	    script.addEventListener("load", function() { loader._finished(name); } ,false);
	    script.addEventListener("error", function() { loader._finished(name); } ,false);
	} else {
	    script.attachEvent("onreadystatechange", function() {
		if (script.readyState == 'loaded' || script.readyState == 'complete') {
		    loader._finished(name);
		}
	    });
	}

	script.src = this._createPath(name);
	document.getElementsByTagName("head")[0].appendChild(script);
    },

    /**
     * Load all dependencies for "name", then execute callback
     * @param {string} name Module name
     * @param {function} callback To be executed
     */

    _loadDependencies: function(name, callback) {
	if (name in this._depends) {
	    this.load(this._depends[name], callback);
	} else {
	    if (callback) { callback(); }
	}
    },

    /**
     * Loads one module, then execute callback
     * @param {string} name Module name
     * @param {function} callback To be executed
     */

    _loadOne: function(name, callback) { /* load one module */
	if (this.isLoaded(name)) {
	    if (callback) { callback(); }
	    return;
	}

	var loader = this;
	var after = function() { /* to be executed when dependencies are met */
	    var arr = []; /* list of load callbacks */
	    if (name in loader._callbacks) {
		arr = loader._callbacks[name];
	    } else {
		loader._callbacks[name] = arr;
	    }

	    if (arr.length) { /* someone else already waits */
		arr.push(callback); /* add ourself to queue */
	    } else { /* we are first */
		arr.push(callback);
		loader._createNode(name);
	    }
	}

	this._loadDependencies(name, after);

    },

    /**
     * Loads all modules, then execute callback
     * @param {string[]} modules Module names
     * @param {function} callback To be executed
     * @param {function[]} [dependencies] Explicit dependencies
     */

    load: function(modules, callback, dependencies) {
	if (dependencies) {
	    var thisf = arguments.callee; /* this function */
	    var thiso = this; /* this object */
	    thisf.call(thiso, dependencies, function() {
		thisf.call(thiso, modules, callback);
	    });
	}

	var m = modules;
	if (!(m instanceof Array)) { m = [m]; }
	OAT.MSG.send(this, "LOADER_LOADING", m);

	var count = m.length;
	var done = function() { /* after each module loads */
	    count--;
	    if (!count) {
		OAT.MSG.send(this, "LOADER_LOADED", m);
		if (callback) { callback(); }
	    }
	}

	if (count) {
	    for (var i=0;i<m.length;i++) {
		this._loadOne(m[i], done);
	    }
	} else {
	    OAT.MSG.send(this, "LOADER_LOADED", m);
	    if (callback) { callback(); }
	}
    },

    /**
     * Tests whether the module in question is already loaded
     * @param {string} module
     * @returns {bool}
     */

    isLoaded: function(module) {
	for (var i=0;i<this._loaded.length;i++) { /* already loaded */
	    if (this._loaded[i] == module) { return true; }
	}
	return false;
    },

    _depends: {
	ajax:["crypto","xml"],
	anchor:"win",
	calendar:["drag","notify"],
	color:"drag",
	combobox:"instant",
	combobutton:"instant",
	combolist:"instant",
	connection:"crypto",
	datasource:["jsobj","json","xml","connection","dstransport","ajax"],
	dav:["grid","tree","toolbar","ajax","xml","dialog","resize","drag"],
	dereference:"ajax",
	dialog:["win","dimmer"],
	dock:["animation","ghostdrag","resize"],
	form:["ajax","dialog","datasource","formobject","crypto"],
	formobject:["drag","resize","datasource","tab","win"],
	fresnel:"xml",
	ghostdrag:"animation",
	graph:"canvas",
	graphsidebar:"tree",
	graphsvg:["svg","graphsidebar","rdf","dereference"],
	grid:["instant","anchor"],
	linechart:"svg",
	menu:"animation",
	notify:"animation",
	panelbar:"animation",
	piechart:"svg",
	pivot:["ghostdrag","statistics","instant","barchart"],
	quickedit:"instant",
	rdf:"xml",
	rdfmini:["rdfstore","rdftabs","notify"],
	rdfstore:["rdf","dereference","n3"],
	rssreader:"xml",
	schema:["xml"],
	simplefx:"animation",
	slidebar:"animation",
	soap:"ajax",
	sparkline:"linechart",
	svgsparql:"geometry",
	timeline:["slider","tlscale","resize"],
	tree:"ghostdrag",
	webclip:"webclipbinding",
	win:["drag","layers"],
	ws:["xml","soap","ajax","schema","connection"],
	xml:["xpath"],
	xmla:["soap","xml","connection"]
    },

    featureLoaded: function (s) {
	return (true);
    }
}

OAT.init();
