/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2009 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	OAT.Ajax.command(method, target, data_func, return_func, return_type, customHeaders)
	OAT.Ajax.setStart(callback)
	OAT.Ajax.setEnd(callback)
	OAT.Ajax.setCancel(element)
	OAT.Ajax.user
	OAT.Ajax.password
	OAT.Ajax.GET
	OAT.Ajax.POST
	OAT.Ajax.SOAP
	OAT.Ajax.PUT
	OAT.Ajax.AUTH_BASIC
	OAT.Ajax.AUTH_DIGEST
*/

OAT.Ajax = {
	number:0,      /* # of requests waiting to be responded */
	httpError:1,
	startRef:false,
	endRef:false,
	errorRef:false,
	cancel:false, /* cancel element */
	dialog:false,
	GET:1,
	POST:2,
	SOAP:4,
	PUT:8,
	MKCOL:16,
	PROPFIND:32,
	PROPPATCH:64,
	AUTH_BASIC: 1024,
	AUTH_DIGEST: 512,
	TYPE_TEXT: 0,
	TYPE_XML: 1,
	user:"",       /* for http authorization */
	password:"",
	imagePath:OAT.Preferences.imagePath,
	requests:[],
	
	startNotify:function() {
		if (OAT.Ajax.startRef) { OAT.Ajax.startRef(); return; }
		if (OAT.Loader.loadedLibs.find("dialog") != -1) {
			if (!OAT.Ajax.dialog) {
				/* create an Ajax window */
				var imagePath = OAT.Ajax.imagePath;
				if (imagePath.charAt(imagePath.length - 1) == "/") imagePath = imagePath.substring(0,imagePath.length - 1);
				var div = OAT.Dom.create("div");
				div.innerHTML = "Ajax call in progress...";
				var dimg = OAT.Dom.create("div");
				var img = OAT.Dom.create("img");
				img.setAttribute("src",OAT.Ajax.imagePath+"/progress.gif");
				dimg.appendChild(img);
				div.appendChild(dimg);
				OAT.Ajax.dialog = new OAT.Dialog("Please wait",div,{width:260,modal:0,zIndex:1001,resize:0,imagePath:OAT.Ajax.imagePath + "/"});
				OAT.Ajax.dialog.ok = OAT.Ajax.dialog.hide;
				OAT.Ajax.dialog.cancel = OAT.Ajax.dialog.hide;
				OAT.Ajax.setCancel(OAT.Ajax.dialog.cancelBtn);
			}
			OAT.Ajax.dialog.show();

		}
	},
	
	endNotify:function() {
		if (OAT.Ajax.endRef) { OAT.Ajax.endRef(); return; }
		if (OAT.Loader.loadedLibs.find("dialog") != -1 && OAT.Ajax.dialog) {
			OAT.Ajax.dialog.hide();
		}
	},

	command:function(method, target, data_func, return_func, return_type, customHeaders) {
		if ((OAT.Ajax.startRef || OAT.Preferences.showAjax) && !OAT.Ajax.number) { OAT.Ajax.startNotify(); }
		OAT.Ajax.number++;
		var xmlhttp = new OAT.XMLHTTP();
		var data = null; /* default - no data */
		var request = {state:1};
		OAT.Ajax.requests.push(request);

		var callback_response = function() {
			if (!request.state) { return; } /* canceled */
			if (xmlhttp.getReadyState() == 4) {

				var headers = xmlhttp.getAllResponseHeaders();
				OAT.Ajax.number--;
				if ((OAT.Ajax.endRef || OAT.Preferences.showAjax) && !OAT.Ajax.number) { OAT.Ajax.endNotify(); }
				if (xmlhttp.getStatus().toString().charAt(0) == "2" || xmlhttp.getStatus() == 0) {
					if (return_type == OAT.Ajax.TYPE_TEXT) {
		  				return_func(xmlhttp.getResponseText(),headers);
		  			} else {
						if (OAT.Dom.isIE() || OAT.Dom.isWebKit()) {
							xmlStr = xmlhttp.getResponseText(); 
							var xmlDoc = OAT.Xml.createXmlDoc(xmlStr);
						} else { 
							var xmlDoc = xmlhttp.getResponseXML(); 
						}
						return_func(xmlDoc,headers);
		  			}
				} else {
					if (OAT.Ajax.errorRef){
						OAT.Ajax.errorRef(xmlhttp.getStatus(),xmlhttp.getResponseText(),headers);
					} else if (OAT.Ajax.httpError) {
						var tmp = confirm("Problem retrieving data, status="+xmlhttp.getStatus()+", do you want to see returned problem description?");
						if (tmp) { alert(xmlhttp.getResponseText()); }
					}
				} /* http error */
			} /* response complete */
		} /* callback_response */
		
		xmlhttp.setResponse(callback_response);

		data = data_func(); /* request them from some user-specified routine */
		if (method & OAT.Ajax.GET) {
			var newtarget = (/\?/.test(target) ? target+"&"+data : target+"?"+data);
			xmlhttp.open("GET",newtarget,true);
		}
		if (method & OAT.Ajax.POST) {
			xmlhttp.open("POST",target,true);
			xmlhttp.setRequestHeader("Content-Type","application/x-www-form-urlencoded");
		}
		if (method & OAT.Ajax.SOAP) { xmlhttp.open("POST",target,true); }
		if (method & OAT.Ajax.PUT) { xmlhttp.open("PUT",target,true); }
		if (method & OAT.Ajax.MKCOL) { xmlhttp.open("MKCOL",target,true); }
		if (method & OAT.Ajax.PROPFIND) { xmlhttp.open("PROPFIND",target,true); }
		if (method & OAT.Ajax.PROPPATCH) { xmlhttp.open("PROPPATCH",target,true); }
		if (method & OAT.Ajax.AUTH_BASIC) {	xmlhttp.setRequestHeader('Authorization','Basic '+OAT.Crypto.base64e(OAT.Ajax.user+":"+OAT.Ajax.password)); }

		if (customHeaders) {
			for (var p in customHeaders) {
				xmlhttp.setRequestHeader(p,customHeaders[p]);
			}
		}
		/* xmlhttp.obj.overrideMimeType("text/xml"); */
		xmlhttp.send(method & OAT.Ajax.GET ? null : data);

	},

	setStart:function(callback) {
		OAT.Ajax.startRef = callback;
	},

	setEnd:function(callback) {
		OAT.Ajax.endRef = callback;
	},

	handleError:function(callback) {
		OAT.Ajax.errorRef = callback;
	},

	setCancel:function(element) {
		var elm = $(element);
		OAT.Ajax.cancel = elm;
		OAT.Dom.attach(elm,"click",OAT.Ajax.cancelAll);
	},

	cancelAll:function() {
		for (var i=0;i<OAT.Ajax.requests.length;i++) {
			if (OAT.Ajax.requests[i].state) { OAT.Ajax.requests[i].state = 0; }
		}
		if (OAT.Ajax.endRef || OAT.Preferences.showAjax) { OAT.Ajax.endNotify(); }
		OAT.Ajax.number = 0;
	}
}

OAT.XMLHTTP = function() {
	this.iframe = false;
	this.obj = false;
	this.open = function(method, target, async) {
		if (this.iframe) {
			this.temp_src = target;
		} else {
			this.obj.open(method, target, async);
		}
	}
	this.send = function(data) {
		if (this.iframe) {
			this.ifr.src = this.temp_src;
		} else {
  			this.obj.send(data); 
		}
	}
	this.setResponse = function(callback) {
		if (this.iframe) {
			OAT.Dom.attach(this.ifr,"load",callback);
		} else {
			this.obj.onreadystatechange = callback;
		}
	}
	this.getResponseText = function() {
		if (this.iframe) {
			var data = this.ifr.contentWindow.document.body.innerHTML;
			/* uncomment this to save memory and confuse gecko: */
			/* this.ifr.parentNode.removeChild(this.ifr); */
			return data;
		} else {
			return this.obj.responseText;
		}
	}
	this.getResponseXML = function() {
		if (this.iframe) {
			alert("IFRAME mode active -> XML data not supported");
			return "";
		} else {
			return this.obj.responseXML;
		}
	}
	this.getReadyState = function() {
		if (this.iframe) {
			return 4;
		} else {
			return this.obj.readyState;
		}
	}
	this.getStatus = function() {
		if (this.iframe) {
			return 200;
		} else {
			return this.obj.status;
		}
	}
	this.setRequestHeader = function(name,value) {
		if (!this.iframe) {
			this.obj.setRequestHeader(name,value);
		}
	}
	this.getAllResponseHeaders = function() {
		if (!this.iframe) {
			return this.obj.getAllResponseHeaders();
		}
		return {};
	}
	this.isIframe = function() {
		return this.iframe;
	}

	if (window.XMLHttpRequest) {
		/* gecko */
		this.obj = new XMLHttpRequest();
	} else if (window.ActiveXObject) {
		/* ie */
		this.obj = new ActiveXObject("Microsoft.XMLHTTP");
	}
	if (!this.obj) {
		/* no luck -> iframe */
		this.iframe = true;
		this.ifr = OAT.Dom.create("iframe");
		this.ifr.style.display = "none";
		this.ifr.src = "javascript:;";
		document.body.appendChild(this.ifr);
	}
}

OAT.XMLHTTP_supported = function() {
	var dummy = new OAT.XMLHTTP();
	return (!dummy.isIframe());
}
OAT.Loader.featureLoaded("ajax");
