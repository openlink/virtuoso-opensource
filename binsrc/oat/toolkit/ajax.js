/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software AJAX Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2016 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	OAT.AJAX.GET|POST|SOAP|PUT|MKCOL|PROPFIND|PROPPATCH(url, data, callback, optObj)
	optObj = {
		headers:{},
		auth:OAT.AJAX.AUTH_NONE,
		user:"",
		password:"",
		timeout:false,
		type:OAT.AJAX.TYPE_TEXT,
		async:true,
		onerror:function(){},
		onstart:function(){},
		onend:function(){},
		noSecurityCookie:false
	}

	OAT.AJAX.startRef = function..
	OAT.AJAX.endRef = function..

	OAT.AJAX.AUTH_NONE
	OAT.AJAX.AUTH_BASIC
	OAT.AJAX.TYPE_TEXT
	OAT.AJAX.TYPE_XML
*/

/**
 * @namespace Provides basic Asynchronous XML call (AJAX) routines.
 * @message AJAX_START ajax reuqest started
 * @message AJAX_TIMEOUT ajax request timed out
 * @message AJAX_ERROR ajax request finished with error
 * @message AJAX_DONE ajax request successfully finished
 */
OAT.AJAX = {
	AUTH_NONE:0,
	AUTH_BASIC:1,
	TYPE_TEXT:0,
	TYPE_XML:1,
	httpError:1,
	SHOW_NONE:0,
	SHOW_POPUP:1,
	SHOW_THROBBER:2,

	requests:[],
	dialog:false,
	imagePath:OAT.Preferences.imagePath,
	startRef:false,
	endRef:false,

	abortAll:function() {
		while (OAT.AJAX.requests.length) { OAT.AJAX.requests[0].abort(); }
	},

    GET:function(url,dta,callback,optObj) {
		var options = OAT.AJAX.options(optObj);
		var xhr = OAT.AJAX.init(url,callback,options);
		var url_ = url;
		/* create security cookie */
		if (url.match(/\?/)) {
			url_ += "&";
		} else {
	    if (dta || !options.noSecurityCookie) { url_ += "?"; }
		}

	if(dta) { url_ += dta; }

		if (!options.noSecurityCookie) {
			url_ += "&";
			var secure = OAT.AJAX.createCookie(); /* array of name & value */
			url_ += secure[0]+"="+secure[1];
		}
	xhr.open("GET",url_,options.async,options.user,options.password);
		OAT.AJAX.send(xhr,null);
		return xhr;
	},

    HEAD:function(url,dta,callback,optObj) {
	var options = OAT.AJAX.options(optObj);
	var xhr = OAT.AJAX.init(url,callback,options);
	xhr.open("HEAD",url,options.async,options.user,options.password);
	OAT.AJAX.send(xhr,dta);
	return xhr;
    },
    
    POST:function(url,dta,callback,optObj) {
		var options = OAT.AJAX.options(optObj);
		var xhr = OAT.AJAX.init(url,callback,options);
	xhr.open("POST",url,options.async,options.user,options.password);
		xhr.setRequestHeader("Content-Type","application/x-www-form-urlencoded");
	OAT.AJAX.send(xhr,dta);
		return xhr;
	},

    PUT:function(url,dta,callback,optObj) {
		var options = OAT.AJAX.options(optObj);
		var xhr = OAT.AJAX.init(url,callback,options);
	xhr.open("PUT",url,options.async,options.user,options.password);
	OAT.AJAX.send(xhr,dta);
		return xhr;
	},

    SOAP:function(url,dta,callback,optObj) {
		var options = OAT.AJAX.options(optObj);
		var xhr = OAT.AJAX.init(url,callback,options);
	xhr.open("POST",url,options.async,options.user,options.password);
	OAT.AJAX.send(xhr,dta);
		return xhr;
	},

    MKCOL:function(url,dta,callback,optObj) {
		var options = OAT.AJAX.options(optObj);
		var xhr = OAT.AJAX.init(url,callback,options);
	xhr.open("MKCOL",url,options.async,options.user,options.password);
	OAT.AJAX.send(xhr,dta);
		return xhr;
	},

    PROPFIND:function(url,dta,callback,optObj) {
		var options = OAT.AJAX.options(optObj);
		var xhr = OAT.AJAX.init(url,callback,options);
	xhr.open("PROPFIND",url,options.async,options.user,options.password);
	OAT.AJAX.send(xhr,dta);
		return xhr;
	},

    PROPPATCH:function(url,dta,callback,optObj) {
		var options = OAT.AJAX.options(optObj);
		var xhr = OAT.AJAX.init(url,callback,options);
	xhr.open("PROPPATCH",url,options.async,options.user,options.password);
	OAT.AJAX.send(xhr,dta);
		return xhr;
	},

	options:function(optObj) { /* add default options */
		var options = {
			headers:{},
			auth:OAT.AJAX.AUTH_NONE,
	    user:null,
	    password:null,
			timeout:false,
			type:OAT.AJAX.TYPE_TEXT,
			noSecurityCookie:false,
			async:true,
			onerror:false,
			onstart:false,
			onend:false
		};
		for (var p in optObj) { options[p] = optObj[p]; }
		return options;
	},

	init:function(url,callback,options) { /* common initialization for all methods */
		OAT.MSG.send(OAT.AJAX, "AJAX_START", url);

		var xhr = new OAT.AJAX.XMLHTTP(options,callback);

		if (options.onstart) { /* if individual callback */
			options.onstart(xhr);
		} else { /* global notification otherwise - when allowed or specified */
			if ((OAT.AJAX.startRef || OAT.Preferences.showAjax) && !OAT.AJAX.requests.length) {
				 OAT.AJAX.startNotify(OAT.Preferences.showAjax);
			}
		}

		xhr.setResponse(function(){OAT.AJAX.response(xhr);});
		OAT.AJAX.requests.push(xhr);
		return xhr;
	},

    send:function(xhr,body) {
		function go() {
	    xhr.send(body);
			try {
				if (OAT.Browser.isGecko && !xhr.options.async) {
					OAT.AJAX.response(xhr);
				}
			} catch (e) {}
		}
		for (var p in xhr.options.headers) { xhr.setRequestHeader(p,xhr.options.headers[p]); }

		if (xhr.options.timeout) { xhr.setTimeout(xhr.options.timeout); }

		if (xhr.options.auth == OAT.AJAX.AUTH_BASIC) {
			var cb = function() {
				xhr.setRequestHeader('Authorization','Basic '+OAT.Crypto.base64e(xhr.options.user+":"+xhr.options.password));
				go();
			}
			OAT.Loader.load("crypto", cb);
	} /* if (BASIC) auth needed */ 
	else go();
	},

	response:function(xhr) {
		if (xhr.aborted) { return; }
		if (xhr.getReadyState() == 4) {
			if (xhr.timeout != false) { xhr.clearTimeout(); }
			var headers = xhr.getAllResponseHeaders();
			var index = OAT.AJAX.requests.indexOf(xhr);
			if (index != -1) { OAT.AJAX.requests.splice(index,1); } /* remove from request registry */
			OAT.AJAX.checkEnd();
			if (xhr.options.onend) { xhr.options.onend(xhr); }
			if (xhr.getStatus().toString().charAt(0) == "2" || xhr.getStatus() == 0) { /* success */
				OAT.MSG.send(OAT.AJAX, "AJAX_DONE", xhr);
				if (xhr.options.type == OAT.AJAX.TYPE_TEXT) {
					xhr.callback(xhr.getResponseText(),headers);
				} else {
					if (OAT.Browser.isIE || OAT.Browser.isWebKit) {
						xmlStr = xhr.getResponseText();
						var xmlDoc = OAT.Xml.createXmlDoc(xmlStr);
					} else {
						var xmlDoc = xhr.getResponseXML();
						if (!xmlDoc) { xmlDoc = OAT.Xml.createXmlDoc(xhr.getResponseText()); }
					}
					xhr.callback(xmlDoc,headers);
				}
			} else { /* not success */
				OAT.MSG.send(OAT.AJAX, "AJAX_ERROR", xhr);
				if (xhr.options.onerror) {
					xhr.options.onerror(xhr);
				} else if (OAT.AJAX.httpError) {
					var errtext = "Problem retrieving data, status="+xhr.getStatus()+".";
					if (OAT.AJAX.SHOW_POPUP) { // show the error message inside the popup
					    $('oat_ajax').innerHTML = errtext+"<br/><br/>";
					    if ($('oat_ajax_title')) $('oat_ajax_title').innerHTML = 'Error';
					    var button1 = OAT.Dom.create("input",{type:'button'});
					    button1.value = "Details";
					    button1.onclick = function() { window.alert(xhr.getResponseText()); }
					    var button2 = OAT.Dom.create("input",{type:'button'});
					    button2.value = "Continue";
					    button2.onclick = function() { OAT.AJAX.endNotify(OAT.Preferences.showAjax); }
					    OAT.Dom.append([$('oat_ajax'),button1,button2]);
                                        } else { // if no popup
					    var tmp = window.confirm(errtext);
					    if (tmp) { window.alert(xhr.getResponseText()); }
					}
				}
			} /* http error */
		} /* readystate == 4 */
	}, /* OAT.AJAX.response */

	checkEnd:function() {
		if ((OAT.AJAX.endRef || OAT.Preferences.showAjax) && OAT.AJAX.requests.length == 0) {
			OAT.AJAX.endNotify(OAT.Preferences.showAjax);
		}
	},

	startNotify:function(showType) { /* global notification */
		if (OAT.AJAX.startRef) {
			OAT.AJAX.startRef();
			return;
		}
		if (showType == OAT.AJAX.SHOW_POPUP) { // show dialog
			if (OAT.Loader.isLoaded("dialog")) {
				if (!OAT.AJAX.dialog) {
					// create an AJAX window
					var imagePath = OAT.AJAX.imagePath;
					var div = OAT.Dom.create("div",{textAlign:"center",id:'oat_ajax'});
					var img = OAT.Dom.create("img");
					img.src = OAT.AJAX.imagePath+"Ajax_throbber.gif";
					OAT.Dom.append([div,img,OAT.Dom.create("br"),OAT.Dom.text("Retrieving data from server...")]);
					OAT.AJAX.dialog = new OAT.Dialog("Please wait", div,
											{ width:240, modal:0, zIndex:1001, resize:0 });
					OAT.MSG.attach(OAT.AJAX.dialog, "DIALOG_CANCEL", function() {
						OAT.AJAX.abortAll();
					});
				}
				OAT.AJAX.dialog.open();
			}
		}
		if (showType == OAT.AJAX.SHOW_THROBBER) { // show throbber
			if ($('oat_ajax_throbber')) {
				OAT.Dom.show($('oat_ajax_throbber'));
			} else {
				var win = new OAT.Win({type:OAT.Win.Round,title:"Processing...",outerWidth:165,outerHeight:125,buttons:""});
				win.dom.container.id = 'oat_ajax_throbber';
				win.dom.content.id = 'oat_ajax';
				win.dom.title.id = 'oat_ajax_title';
				win.open();

				var img = OAT.Dom.image('./imgs/throbber.gif');
				win.dom.content.appendChild(img);
				win.dom.content.style.textAlign = 'center';
				win.dom.content.style.marginTop = '12px';
				win.dom.container.style.position = 'fixed';
				OAT.Dom.center(win.dom.container,1,1,document.body);
			}
		}
	},

	endNotify:function(showType) {
		if (OAT.AJAX.endRef) { OAT.AJAX.endRef(); return; }
		if (showType == OAT.AJAX.SHOW_POPUP) {
			if (OAT.Loader.isLoaded("dialog") && OAT.AJAX.dialog) {
				OAT.AJAX.dialog.close();
			}
		}
		if (showType == OAT.AJAX.SHOW_THROBBER) {
			OAT.Dom.hide($('oat_ajax_throbber'));
		}
	},

	createCookie:function() {
		var code = Math.random().toString().split(".").pop();
		var date = new Date();
		var name = "oatSecurityCookie";
		date.setTime(date.getTime()+(60*1000)); /* 1 minute validity */
		var expires = "; expires="+date.toGMTString();
		document.cookie = name+"="+code+expires+"; path=/";
		return [name,code];
	},

	XMLHTTP:function(options,callback) {
		var self = this;
		this.obj = false;
		this.callback = callback;
		this.options = options;
		this.timeout = false;
		this.aborted = false;
	
	this.open = function(method, target, async, user, password) {
			try {
		self.obj.open(method, target, async, user, password);
			} catch(e) {
				self.aborted = true;
				if (self.options.onend) { self.options.onend(self); }
				var index = OAT.AJAX.requests.indexOf(self);
				OAT.AJAX.requests.splice(index,1);
				OAT.AJAX.checkEnd();
			}
		}
	this.send = function(body) { if (!self.aborted) { self.obj.send(body); } }
		this.setResponse = function(callback) { self.obj.onreadystatechange = callback; }
		this.getResponseText = function() { return self.obj.responseText; }
		this.getResponseXML = function() { return self.obj.responseXML;	}
		this.getReadyState = function() { return self.obj.readyState; }
		this.getStatus = function() { return self.obj.status; }
		this.setRequestHeader = function(name,value) { self.obj.setRequestHeader(name,value); }
		this.getAllResponseHeaders = function() { return self.obj.getAllResponseHeaders(); }

		this.setTimeout = function(msec) {
			var cb = function() {
			   OAT.MSG.send(OAT.AJAX, "AJAX_TIMEOUT", self);
			   self.timeout = false;
			   self.abort();
			}
			self.timeout = setTimeout(cb,msec);
		}

		this.clearTimeout = function(msec) {
			clearTimeout(self.timeout);
			self.timeout = false;
		}

		this.abort = function() { /* abort */
			self.aborted = true;
			var index = OAT.AJAX.requests.indexOf(self);
			if (index != -1) { OAT.AJAX.requests.splice(index,1); }
			if (self.options.onend) { self.options.onend(self); }
			if (self.timeout != false) { self.clearTimeout(); }
			OAT.AJAX.checkEnd();
			if (self.obj.abort) { self.obj.abort(); } /* abort the xmlhttp */
		}


		//
		//  Constructor
		//
		var oXMLHttpRequest = window.XMLHttpRequest;
		if (oXMLHttpRequest) {
			self.obj = new oXMLHttpRequest(); /* gecko */
		} else if (window.ActiveXObject) {
			self.obj = new ActiveXObject("Microsoft.XMLHTTP"); /* ie */
		} else {
			alert("OAT.AJAX.constructor:\nXMLHTTPRequest not available!");
		}

		// Fix problem with some versions of FireBug
		if (OAT.Browser.isGecko && oXMLHttpRequest.wrapped)
			self.obj.wrapped = oXMLHttpRequest.wrapped;
	}
} /* OAT.AJAX */
OAT.AJAX.cancelAll = OAT.AJAX.abortAll;
