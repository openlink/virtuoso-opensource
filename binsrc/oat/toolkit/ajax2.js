/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software AJAX Toolkit (OAT) project.
 *
 *  Copyright (C) 2006 Ondrej Zara and OpenLink Software
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
		type:OAT.AJAX.TYPE_TEXT,
		async:true
	}
	
	OAT.AJAX.startRef = function..
	OAT.AJAX.endRef = function..

	OAT.AJAX.AUTH_NONE
	OAT.AJAX.AUTH_BASIC
	OAT.AJAX.AUTH_DIGEST
	OAT.AJAX.TYPE_TEXT
	OAT.AJAX.TYPE_XML
*/

OAT.AJAX = {
	AUTH_NONE:0,
	AUTH_BASIC:1,
	AUTH_DIGEST:2,
	TYPE_TEXT:0,
	TYPE_XML:1,
	httpError:1,

	requests:[], 
	dialog:false,
	imagePath:"/DAV/JS/images",
	startRef:false,
	endRef:false,
	
	cancelAll:function() {
		for (var i=0;i<OAT.AJAX.requests.length;i++) { OAT.AJAX.requests[i].canceled = true; }
		OAT.AJAX.requests = [];
		if (OAT.AJAX.endRef || OAT.Preferences.showAjax) { OAT.AJAX.endNotify(); }
	},

	GET:function(url,data,callback,optObj) {
		var options = OAT.AJAX.options(optObj);
		var xhr = OAT.AJAX.init(url,callback,options);
		var url_ = url;
		if (data) {
			url_ += (/\?/.test(url_) ? "&"+data : "?"+data);
		}
		xhr.open("GET",url_,options.async);
		OAT.AJAX.send(xhr,null);
	},
	
	POST:function(url,data,callback,optObj) {
		var options = OAT.AJAX.options(optObj);
		var xhr = OAT.AJAX.init(url,callback,options);
		xhr.open("POST",url,options.async);
		xhr.setRequestHeader("Content-Type","application/x-www-form-urlencoded");
		OAT.AJAX.send(xhr,data);
	},
	
	PUT:function(url,data,callback,optObj) {
		var options = OAT.AJAX.options(optObj);
		var xhr = OAT.AJAX.init(url,callback,options);
		xhr.open("PUT",url,options.async);
		OAT.AJAX.send(xhr,data);
	},
	
	SOAP:function(url,data,callback,optObj) {
		var options = OAT.AJAX.options(optObj);
		var xhr = OAT.AJAX.init(url,callback,options);
		xhr.open("POST",url,options.async);
		OAT.AJAX.send(xhr,data);
	},

	MKCOL:function(url,data,callback,optObj) {
		var options = OAT.AJAX.options(optObj);
		var xhr = OAT.AJAX.init(url,callback,options);
		xhr.open("MKCOL",url,options.async);
		OAT.AJAX.send(xhr,data);
	},

	PROPFIND:function(url,data,callback,optObj) {
		var options = OAT.AJAX.options(optObj);
		var xhr = OAT.AJAX.init(url,callback,options);
		xhr.open("PROPFIND",url,options.async);
		OAT.AJAX.send(xhr,data);
	},

	PROPPATCH:function(url,data,callback,optObj) {
		var options = OAT.AJAX.options(optObj);
		var xhr = OAT.AJAX.init(url,callback,options);
		xhr.open("PROPPATCH",url,options.async);
		OAT.AJAX.send(xhr,data);
	},
	
	options:function(optObj) { /* add default options */
		var options = {
			headers:{},
			auth:OAT.AJAX.AUTH_NONE,
			user:"",
			password:"",
			type:OAT.AJAX.TYPE_TEXT,
			async:true,
			onerror:false
		};
		for (var p in optObj) { options[p] = optObj[p]; }
		return options;
	},
	
	init:function(url,callback,options) { /* common initialization for all methods */
		OAT.MSG.send(OAT.AJAX,OAT.MSG.AJAX_START,url);
		if ((OAT.AJAX.startRef || OAT.Preferences.showAjax) && OAT.AJAX.requests.length == 0) { OAT.AJAX.startNotify(); }
		var xhr = new OAT.AJAX.XMLHTTP(options,callback);
		xhr.setResponse(function(){OAT.AJAX.response(xhr);});
		OAT.AJAX.requests.push(xhr);
		return xhr;
	},
	
	send:function(xhr,data) {
		if (xhr.options.auth == OAT.AJAX.AUTH_BASIC) {
			xhr.setRequestHeader('Authorization','Basic '+OAT.Crypto.base64e(xhr.options.user+":"+xhr.options.password)); 
		}
		if (xhr.options.auth == OAT.AJAX.AUTH_DIGEST) {
			alert("Digest auth not supported yet!");
		}
		for (var p in xhr.options.headers) { xhr.setRequestHeader(p,xhr.options.headers[p]); }
		xhr.send(data);
	},
	
	response:function(xhr) {
		if (xhr.canceled) { return; }
		if (xhr.getReadyState() == 4) {
			var headers = xhr.getAllResponseHeaders();
			var index = OAT.AJAX.requests.find(xhr);
			if (index != -1) { OAT.AJAX.requests.splice(index,1); } /* remove from request registry */

			if ((OAT.AJAX.endRef || OAT.Preferences.showAjax) && OAT.AJAX.requests.length == 0) { OAT.AJAX.endNotify(); }
			
			if (xhr.getStatus().toString().charAt(0) == "2" || xhr.getStatus() == 0) { /* success */
				if (xhr.options.type == OAT.AJAX.TYPE_TEXT) {
					xhr.callback(xhr.getResponseText(),headers);
				} else {
					if (OAT.Dom.isIE() || OAT.Dom.isWebKit()) {
						xmlStr = xhr.getResponseText(); 
						var xmlDoc = OAT.Xml.createXmlDoc(xmlStr);
					} else { 
						var xmlDoc = xhr.getResponseXML(); 
					}
					xhr.callback(xmlDoc,headers);
				}
			} else { /* not success */
				OAT.MSG.send(OAT.AJAX,OAT.MSG.AJAX_ERROR,xhr);
				if (xhr.options.onerror) { 
					xhr.options.onerror(xhr);
				} else if (OAT.AJAX.httpError) {
					var tmp = confirm("Problem retrieving data, status="+xhr.getStatus()+", do you want to see returned problem description?");
					if (tmp) { alert(xhr.getResponseText()); }
				}
			} /* http error */
		} /* readystate == 4 */
	}, /* OAT.AJAX.response */

	startNotify:function() {
		if (OAT.AJAX.startRef) { 
			OAT.AJAX.startRef(); 
			return; 
		}
		if (OAT.Loader.loadedLibs.find("dialog") != -1) {
			if (!OAT.AJAX.dialog) {
				/* create an AJAX window */
				var imagePath = OAT.AJAX.imagePath;
				if (imagePath.charAt(imagePath.length - 1) == "/") imagePath = imagePath.substring(0,imagePath.length - 1);
				var div = OAT.Dom.create("div");
				div.innerHTML = "Ajax call in progress...";
				var dimg = OAT.Dom.create("div");
				var img = OAT.Dom.create("img");
				img.setAttribute("src",OAT.AJAX.imagePath+"/progress.gif");
				dimg.appendChild(img);
				div.appendChild(dimg);
				OAT.AJAX.dialog = new OAT.Dialog("Please wait",div,{width:280,modal:0,zIndex:1001,resize:0,imagePath:OAT.AJAX.imagePath + "/"});
				OAT.AJAX.dialog.ok = OAT.AJAX.dialog.hide;
				OAT.AJAX.dialog.cancel = function() {
					OAT.AJAX.dialog.hide();
					OAT.AJAX.cancelAll();
				}	
			}
			OAT.AJAX.dialog.show();

		}
	},
	
	endNotify:function() {
		if (OAT.AJAX.endRef) { OAT.AJAX.endRef(); return; }
		if (OAT.Loader.loadedLibs.find("dialog") != -1 && OAT.AJAX.dialog) {
			OAT.AJAX.dialog.hide();
		}
	},

	XMLHTTP:function(options,callback) {
		var self = this;
		this.obj = false;
		this.callback = callback;
		this.options = options;
		this.canceled = false;
		this.open = function(method, target, async) { self.obj.open(method, target, async);	}
		this.send = function(data) { self.obj.send(data); }
		this.setResponse = function(callback) { self.obj.onreadystatechange = callback; }
		this.getResponseText = function() { return self.obj.responseText; }
		this.getResponseXML = function() { return self.obj.responseXML;	}
		this.getReadyState = function() { return self.obj.readyState; }
		this.getStatus = function() { return self.obj.status; }
		this.setRequestHeader = function(name,value) { self.obj.setRequestHeader(name,value); }
		this.getAllResponseHeaders = function() { return self.obj.getAllResponseHeaders(); }
		if (window.XMLHttpRequest) {
			self.obj = new XMLHttpRequest(); /* gecko */
		} else if (window.ActiveXObject) {
			self.obj = new ActiveXObject("Microsoft.XMLHTTP"); /* ie */
		} else {
			alert("XMLHTTPRequest not available!");
		}
	}
} /* OAT.AJAX */
OAT.Loader.featureLoaded("ajax2");
