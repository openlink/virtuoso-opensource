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
	Ajax.command(method, target, data_func, return_func)
	Ajax.manage(element, event, method, target, data_func, return_func)
	Ajax.setStart(callback)
	Ajax.setEnd(callback)
	Ajax.setCancel(element)
	Ajax.user
	Ajax.password
	Ajax.GET
	Ajax.POST
	Ajax.SOAP
	Ajax.PUT
	Ajax.AUTH_BASIC
	Ajax.AUTH_DIGEST
*/

var Ajax = {
	number:0,      /* # of requests waiting to be responded */
	startRef:false,
	endRef:false,
	cancel:false, /* cancel element */
	GET:1,
	POST:2,
	SOAP:4,
	PUT:8,
	MKCOL:16,
	AUTH_BASIC: 1024,
	AUTH_DIGEST: 512,
	user:"",       /* for http authorization */
	password:"",
	requests:[],

	command:function(method, target, data_func, return_func) {
		if (Ajax.startRef && !Ajax.number) { Ajax.startRef(); }
		Ajax.number++;
		var xmlhttp = new XMLHTTP();
		var data = null; /* default - no data */
		var request = {state:1};
		Ajax.requests.push(request);
		
		var callback_response = function() {
			if (!request.state) { return; } /* cancelled */
			if (xmlhttp.getReadyState() == 4) {
				Ajax.number--;
				if (Ajax.endRef && !Ajax.number) { Ajax.endRef(); }
				if (xmlhttp.getStatus().toString().charAt(0) == "2" || xmlhttp.getStatus() == 0) {
					return_func(xmlhttp.getResponseText());
				} else {
					var tmp = confirm("Problem retrieving data, status="+xmlhttp.getStatus()+", do you want to see returned problem description?");
					if (tmp) { alert(xmlhttp.getResponseText()); }
				} 
			} /* response complete */
		} /* callback_response */
		xmlhttp.setResponse(callback_response);

		data = data_func(); /* request them from some user-specified routine */
		if (method & Ajax.GET) {
			var newtarget = (/\?/.test(target) ? target+"&"+data : target+"?"+data);
			xmlhttp.open("GET",newtarget,true);
		}
		if (method & Ajax.POST) {
			xmlhttp.open("POST",target,true);
			xmlhttp.setRequestHeader("Content-Type","application/x-www-form-urlencoded");
		}
		if (method & Ajax.SOAP) {
			xmlhttp.open("POST",target,true);
			xmlhttp.setRequestHeader("Content-Type",'application/soap+xml; action="urn:schemas-microsoft-com:xml-analysis:Discover"');
		}
		if (method & Ajax.PUT) { xmlhttp.open("PUT",target,true); }
		if (method & Ajax.MKCOL) { xmlhttp.open("MKCOL",target,true); }
		if (method & Ajax.AUTH_BASIC) {	xmlhttp.setRequestHeader('Authorization','Basic '+Crypto.base64e(Ajax.user+":"+Ajax.password)); }

		xmlhttp.send(data);
		/* alert("SENDING\n\n"+data+"\n\nto: "+target); */
	},

	manage:function(elm, event, method, target, data_func, return_func) {
		var element = $(elm);
		if (!element) {
			alert("Element '"+id+"' not found");
			return;
		}
		if (method == Ajax.POST && !XMLHTTP_supported()) {
			alert("IFRAME mode active -> POSTs not allowed");
			return;
		}
		var callback_request = function() {
			Ajax.command(method,target,data_func,return_func);
		} /* callback_request */
		
		Dom.attach(element,event,callback_request);
	},
	
	setStart:function(callback) {
		Ajax.startRef = callback;
	},
	
	setEnd:function(callback) {
		Ajax.endRef = callback;
	},
	
	setCancel:function(element) {
		var elm = $(element);
		Ajax.cancel = elm;
		Dom.attach(elm,"click",Ajax.cancelAll);
	},
	
	cancelAll:function() {
		for (var i=0;i<Ajax.requests.length;i++) {
			if (Ajax.requests[i].state) { Ajax.requests[i].state = 0; }
		}
		if (Ajax.endRef) { Ajax.endRef(); }
		Ajax.number = 0;
	}
}

function XMLHTTP() {
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
			Dom.attach(this.ifr,"load",callback);
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
		this.ifr = Dom.create("iframe");
		this.ifr.style.display = "none";
		this.ifr.src = "javascript:;";
		document.body.appendChild(this.ifr);
	}
}

function XMLHTTP_supported() {
	var dummy = new XMLHTTP();
	return (!dummy.isIframe());
}
