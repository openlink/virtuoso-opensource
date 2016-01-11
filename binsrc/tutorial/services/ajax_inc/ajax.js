/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2016 OpenLink Software
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

/// Ajax = Asynchronous JavaScript + XML (+ HTML)
/// Ajax framework for Internet Explorer (6.0, ...) and Firefox (1.0, ...)
/// by Matthias Hertel
/// More information on: http://ajaxaspects.blogspot.com/ and http://ajaxaspekte.blogspot.com/
/// -----
/// ajax.js: Common Javascript methods and global objects
/// 05.06.2005 creation.
/// 19.06.2005 minor corrections to webservices.
/// 25.06.2005 ajax action queue and timing.
/// 02.07.2005 queue up actions fixed.
/// 10.07.2005 ajax.timeout
/// 10.07.2005 a option object that is passed from ajax.Start() to prepare() is also queued.
/// 10.07.2005 a option object that is passed from ajax.Start() to prepare(), finish()
///            and onException() is also queued.
/// 12.07.2005 correct xml encoding when CallSoap()
/// 20.07.2005 more datatypes and XML Documents
/// 20.07.2005 more datatypes and XML Documents fixed
/// 06.08.2005 caching implemented.
/// 07.08.2005 bugs fixed, when queuing without a delay time.

// ----- global variable for the proxies to webservices. -----

/// <summary>The root object for the proxies to webservices.</summary>
var proxies = new Object();

proxies.current = null; // the current active webservice call.
proxies.xmlhttp = null; // The current active xmlhttp object.


// ----- global variable for the ajax engine. -----

/// <summary>The root object for the ajax engine.</summary>
var ajax = new Object();

ajax.current = null; /// The current active AJAX action.
ajax.option = null; /// The options for the current active AJAX action.

ajax.queue = new Array(); /// The pending AJAX actions.
ajax.options = new Array(); /// The options for the pending AJAX actions.

ajax.timer = null; /// The timer for delayed actions.


// ----- AJAX engine and actions implementation -----

///<summary>Start an AJAX action by entering it into the queue</summary>

ajax.Start = function (action, options) {

  if (action == null) {
    alert("ajax.Start: Argument action must be set.");
    return;

  } else if ((action.queueClear != null) && (action.queueClear == true)) {
    ajax.queue = new Array();
    ajax.options = new Array();

  } else if ((ajax.queue.length > 0) && ((action.queueMultiple == null) || (action.queueMultiple == false))) {
    // remove existing action entries from the queue and clear a running timer
    if ((ajax.timer != null) && (ajax.queue[0] == action)) {
      window.clearTimeout(ajax.timer);
      ajax.timer = null;
    } // if

    var n = 0;
    while (n < ajax.queue.length) {
      if (ajax.queue[n] == action)
        ajax.queue.splice(n, 1);
      else
        n++;
    } // while
  } // if

  if ((action.queueTop == null) || (action.queueTop == false)) {
    // to the end.
    ajax.queue.push(action);
    ajax.options.push(options);

  } else {
    // to the top
    ajax.queue.unshift(action);
    ajax.options.unshift(options);
  } // if

  // check if the action should start
  ajax.Next(false);
} // ajax.Start


///<summary>Check, if the next AJAX action can start.
///This is an internal method that should not be called from external.</summary>
///<remarks>for private use only.<remarks>
ajax.Next = function (forceStart) {
  var ca = null // current action
  var co = null // current opptions
  var data = null;

  if (ajax.current != null)
    return; // a call is active: wait more time

  if (ajax.timer != null)
    return; // a call is pendig: wait more time

  if (ajax.queue.length == 0)
    return; // nothing to do.

  ca = ajax.queue[0];
  co = ajax.options[0];
  if ((forceStart == true) || (ca.delay == null) || (ca.delay == 0)) {
    // start top action
    ajax.current = ca;
    ajax.queue.shift();
    ajax.option = co;
    ajax.options.shift();

    // get the data
    if (ca.prepare != null)
      data = ca.prepare(co);

    if (ca.call == null) {
      // no call
      ajax.Finsh(data);
    } else {
      // start the call
      ca.call.func = ajax.Finsh;
      ca.call.onException = ajax.Exception;

      //darco
      if(typeof data =='object'){
        var params = '';
        for(var i=0;i<data.length;i++){
          params += 'data['+i+']'
          if(i<data.length-1){
            params += ','
          }
        }
        eval('ca.call('+params+')')

      }else{
        ca.call(data);
      }

      // start timeout timer
      if (ca.timeout != null)
        ajax.timer = window.setTimeout(ajax.Cancel, ca.timeout * 1000);
    } // if

  } else {
    // start a timer and wait
    ajax.timer = window.setTimeout(ajax.EndWait, ca.delay);
  } // if
} // ajax.Next


///<summary>The delay time of an action is over.</summary>
ajax.EndWait = function() {
  ajax.timer = null;
  ajax.Next(true);
} // ajax.EndWait


///<summary>The current action timed out.</summary>
ajax.Cancel = function() {
  proxies.cancel(); // cancel the current webservice call.
  ajax.timer = null;
  ajax.current = null;
  ajax.option = null;
  window.setTimeout(ajax.Next, 200); // give some to time to cancel the http connection.
  // ajax.Next(false);
} // ajax.Cancel


///<summary>Finish an AJAX Action the normal way</summary>
ajax.Finsh = function (data) {
  // clear timeout timer if set
  if (ajax.timer != null) {
    window.clearTimeout(ajax.timer);
    ajax.timer = null;
  } // if

  // use the data
  if ((ajax.current != null) && (ajax.current.finish != null))
    ajax.current.finish(data, ajax.option);
  // reset the running action
  ajax.current = null;
  ajax.option = null;
  ajax.Next(false)
} // ajax.Finsh


///<summary>Finish an AJAX Action with an exception</summary>
ajax.Exception = function (ex) {
  // use the data

  if (ajax.current.onException != null){
    ajax.current.onException(ex, ajax.option);
}
  // reset the running action
  ajax.current = null;
  ajax.option = null;
} // ajax.Exception


///<summary>Clear all pending AJAX actions.</summary>
ajax.CancelAll = function () {
  // cancel the current action
  ajax.Cancel();
  // and clear the queue
  ajax.queue = new Array();
  ajax.options = new Array();
} // ajax.CancelAll


// ----- webservice proxy implementation -----

///<summary>Execute a soap call.
///Build the xml for the call of a soap method of a webservice
///and post it to the server.</summary>
proxies.callSoap = function (args) {
  var p = args.callee;
  var x = null;

  // check for existing cache-entry
  if (p._cache != null) {
    if ((p.params.length == 1) && (args.length == 1) && (p._cache[args[0]] != null)) {
      if (p.func != null) {
        p.func(p._cache[args[0]]);
        return(null);
      } else {
        return(p._cache[args[0]]);
      } // if
    } else {
      p._cachekey = args[0];
    }// if
  } // if

  proxies.current = p;

  try {
    x = new ActiveXObject("Msxml2.XMLHTTP");
  } catch (e) { }

  if (x == null) {
    try {
      x = new ActiveXObject("Microsoft.XMLHTTP");
    } catch (e) { }
  } // if

  // Gecko / Mozilla / Firefox
  if ((x == null) && (typeof(XMLHttpRequest) != "undefined"))
    x = new XMLHttpRequest();

  proxies.xmlhttp = x;

  // envelope start
  var soap = "<?xml version='1.0' encoding='utf-8'?>"
    + "<soap:Envelope xmlns:soap='http://schemas.xmlsoap.org/soap/envelope/'>"
    + "<soap:Body>"
    + "<m:" + p.fname + " xmlns:m='" + p.service.ns + "'>";

  // parameters

  for (n = 0; (n < p.params.length) && (n < args.length); n++) {
    var val = args[n];
    var typ = p.params[n].split(':');


    if ((typ.length == 1) || (typ[1] == "string")) {
      val = String(args[n]).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

    } else if (typ[1] == "int") {
      val = parseInt(args[n]);

    } else if (typ[1] == "float") {
      val = parseFloat(args[n]);

    } else if ((typ[1] == "x") && (typeof(args[n]) == "string")) {
      val = args[n];

    } else if ((typ[1] == "x") && (typeof(XMLSerializer) != "undefined")) {
      val = (new XMLSerializer()).serializeToString(args[n].firstChild);

    } else if (typ[1] == "x") {
      val = args[n].xml;

    } else if ((typ[1] == "bool") && (typeof(args[n]) == "string")) {
      val = args[n].toLowerCase();

    } else if (typ[1] == "bool") {
      val = String(args[n]).toLowerCase();

    } else if (typ[1] == "date") {
      // calculate the xml format for datetime objects from a javascript date object
      var s, ret;
      ret = String(val.getFullYear());
      ret += "-";
      s = String(val.getMonth() + 1);
      ret += (s.length == 1 ? "0" + s : s);
      ret += "-";
      s = String(val.getDate() + 1);
      ret += (s.length == 1 ? "0" + s : s);
      ret += "T";
      s = String(val.getHours() + 1);
      ret += (s.length == 1 ? "0" + s : s);
      ret += ":";
      s = String(val.getMinutes() + 1);
      ret += (s.length == 1 ? "0" + s : s);
      ret += ":";
      s = String(val.getSeconds() + 1);
      ret += (s.length == 1 ? "0" + s : s);
      val = ret;
    } // if
    else {
        val = eval('input_'+typ[1]+'(val)');
    }


    soap += "<" + typ[0] + ">" + val + "</" + typ[0] + ">"
  } // for

  // envelope end
  soap += "</m:" + p.fname + ">"
    + "</soap:Body>"
    + "</soap:Envelope>";

  x.open("POST", p.service.url, (p.func != null));
  x.setRequestHeader("SOAPAction", p.action);
  x.setRequestHeader("Content-Type", "text/xml; charset=utf-8");

  if (p.corefunc != null) {
    // async call with xmlhttp-object as parameter
    x.onreadystatechange = p.corefunc;
    x.send(soap);

  } else if (p.func != null) {
    // async call
    x.onreadystatechange = proxies.response;
    x.send(soap);

  } else {
    // sync call
    x.send(soap);
    return(proxies.response());
  } // if
} // proxies.callSoap


// cancel the running webservice call.
proxies.cancel = function() {
  var cc = proxies.current;
  var cx = proxies.xmlhttp;

  if (proxies.xmlhttp != null) {
    proxies.xmlhttp.onreadystatechange = function() { };
    proxies.xmlhttp.abort();
    if (proxies.current.onException != null)
      proxies.current.onException("WebService call was canceled.")
    proxies.current = null;
    proxies.xmlhttp = null;
  } // if
} // proxies.cancel


// px is a proxies.service.func object !
proxies.EnableCache = function (px) {
  // attach an empty _cache object.
  px._cache = new Object();
} // proxies.EnableCache


///<summary>Callback method for a webservice call that dispatches the response to servive.func or service.onException.</summary>
///<remarks>for private use only.<remarks>
proxies.response = function () {
  var ret = null;
  var x = proxies.xmlhttp;
  var cc = proxies.current;
  var rtype = cc.rtype[0].split(':');
  var _xml = '';

  if ((x != null) && (x.readyState == 4)) {
    if (x.status == 200) {
      var xNode = x.responseXML.getElementsByTagName(rtype[0])[0];

      if ((xNode == null) || (xNode.firstChild == null)) {
        ret = null;

      } else if ((rtype.length == 1) || (rtype[1] == "string")) {
        ret = (xNode.textContent ? xNode.textContent : xNode.text);

      } else if (rtype[1] == "bool") {
        ret = ((xNode.textContent ? xNode.textContent : xNode.text).toLowercase() == "true");

      } else if (rtype[1] == "int") {
        ret = parseInt(xNode.textContent ? xNode.textContent : xNode.text);

      } else if (rtype[1] == "float") {
        ret = parseFloat(xNode.textContent ? xNode.textContent : xNode.text);

      } else if ((rtype[1] == "x") && (typeof(XMLSerializer) != "undefined")) {
        ret = (new XMLSerializer()).serializeToString(xNode.firstChild);
        ret = ajax._getXMLDOM(ret);

      } else if (rtype[1] == "x") {
        ret = xNode.firstChild.xml;
        ret = ajax._getXMLDOM(ret);

      //Darco
      } else if (rtype[1]) {

        ret = eval('new '+rtype[1]+'(xNode)');

      } else  {

        ret = (xNode.textContent ? xNode.textContent : xNode.text);
      } // if

      // store to _cache
      if ((cc._cache != null) && (cc._cachekey != null)) {
        cc._cache[cc._cachekey] = ret;
        cc._cachekey = null;
      } // if

      proxies.xmlhttp = null;
      proxies.current = null;

      if (cc.func == null) {
        return(ret); // sync
      } else {
        cc.func(ret); // async
        return(null);
      } // if

    } else if (proxies.current.onException == null) {
       // no exception
       var tz = 0;
    } else {
      // raise an exception
      ret = new Error();

      if (x.status == 404) {
        ret.message = "The webservice could not be found.";

      } else if (x.status == 500) {
        ret.name = "SoapException";
        var n = x.responseXML.documentElement.firstChild.firstChild.firstChild;
        while (n != null) {
          if (n.nodeName == "faultcode") ret.message = n.firstChild.nodeValue;
          if (n.nodeName == "faultstring") ret.description = n.firstChild.nodeValue;
          n = n.nextSibling;
        } // while

      } else if ((x.status == 502) || (x.status == 12031)) {
        ret.message = "The server could not be found.";

      } else {
        // no classified response.
        ret.message = "Result-Status:" + x.status + "\n" + x.responseText;
      } // if
      proxies.current.onException(ret);
    } // if

    proxies.xmlhttp = null;
    proxies.current = null;
  } // if
} // proxies.response


///<summary>Callback method to show the result of a soap call in an alert box.</summary>
///<remarks>To set up a debug output in an alert box use:
///proxies.service.method.corefunc = proxies.alertResult;</remarks>
proxies.alertResult = function () {
  var x = proxies.xmlhttp;

  if (x.readyState == 4) {
    if (x.status == 200) {
     if (x.responseXML.documentElement.firstChild.firstChild.firstChild == null)
       alert("(no result)");
     else
       alert(x.responseXML.documentElement.firstChild.firstChild.firstChild.firstChild.nodeValue);

    } else if (x.status == 404) { alert("Error!\n\nThe webservice could not be found.");

    } else if (x.status == 500) {
      // a SoapException
      var ex = new Error();
      ex.name = "SoapException";
      var n = x.responseXML.documentElement.firstChild.firstChild.firstChild;
      while (n != null) {
        if (n.nodeName == "faultcode") ex.message = n.firstChild.nodeValue;
        if (n.nodeName == "faultstring") ex.description = n.firstChild.nodeValue;
        n = n.nextSibling;
      } // while
      alert("The server threw an exception.\n\n" + ex.message + "\n\n" + ex.description);

    } else if (x.status == 502) { alert("Error!\n\nThe server could not be found.");

    } else {
      // no classified response.
      alert("Result-Status:" + x.status + "\n" + x.responseText);
    } // if

    proxies.xmlhttp = null;
    proxies.current = null;
  } // if
} // proxies.alertResult


///<summary>Show all the details of the returned data of a webservice call.
///Use this method for debugging transmission problems.</summary>
///<remarks>To set up a debug output in an alert box use:
///proxies.service.method.corefunc = proxies.alertResponseText;</remarks>
proxies.alertResponseText = function () {
 if (proxies.xmlhttp.readyState == 4)
   alert("Status:" + proxies.xmlhttp.status + "\nRESULT:" + proxies.xmlhttp.responseText);
} // proxies.alertResponseText


///<summary>show the details about an exception.</summary>
proxies.alertException = function(ex) {
  var s = "Exception:\n\n";

  if (ex.constructor == String) {
    s = ex;
  } else {
    if ((ex.name != null) && (ex.name != ""))
      s += "Type: " + ex.name + "\n\n";

    if ((ex.message != null) && (ex.message != ""))
      s += "Message:\n" + ex.message + "\n\n";

    if ((ex.description != null) && (ex.description != "") && (ex.message != ex.description))
      s += "Description:\n" + ex.description + "\n\n";
  } // if

  alert(s);
} // proxies.alertException


///<summary>Get a browser specific implementation of the XMLDOM object, containing a XML document.</summary>
///<param name="xmlText">the xml document as string.</param>
ajax._getXMLDOM = function (xmlText) {
  var obj = null;

  if ((document.implementation != null) && (typeof document.implementation.createDocument == "function")) {
    // Gecko / Mozilla / Firefox
    var parser = new DOMParser();
    obj = parser.parseFromString(xmlText, "text/xml");

  } else {
    // IE
    try {
      obj = new ActiveXObject("MSXML2.DOMDocument");
    } catch (e) { }

    if (obj == null) {
      try {
        obj = new ActiveXObject("Microsoft.XMLDOM");
      } catch (e) { }
    } // if

    if (obj != null) {
      obj.async = false;
      obj.validateOnParse = false;
    } // if
    obj.loadXML(xmlText);
  } // if
  return(obj);
} // _getXMLDOM


///<summary>show the details of a javascript object.</summary>
///<remarks>This helps a lot while developing and debugging.</remarks>
function inspectObj(obj) {
  var s = "InspectObj:";

  if (obj == null) {
    s = "(null)"; alert(s); return;
  } else if (obj.constructor == String) {
    s = "\"" + obj + "\"";
  } else if (obj.constructor == Array) {
    s += " _ARRAY";
  } else if (typeof(obj) == "function") {
    s += " [function]" + obj;

  } else if ((typeof(XMLSerializer) != "undefined") && (obj.constructor == XMLDocument)) {
    s = "[XMLDocument]:\n" + (new XMLSerializer()).serializeToString(obj.firstChild);
    alert(s); return;

  } else if ((obj.constructor == null) && (typeof(obj) == "object") && (obj.xml != null)) {
    s = "[XML]:\n" + obj.xml;
    alert(s); return;
  }

  for (p in obj) {
    try {
      if (obj[p] == null) {
        s += "\n" + String(p) + " (...)";

      } else if (typeof(obj[p]) == "function") {
        s += "\n" + String(p) + " [function]";

      } else if (obj[p].constructor == Array) {
        s += "\n" + String(p) + " [ARRAY]: " + obj[p];
        for (n = 0; n < obj[p].length; n++)
          s += "\n  " + n + ": " + obj[p][n];

      } else {
        s += "\n" + String(p) + " [" + typeof(obj[p]) + "]: " + obj[p];
      } // if
    } catch (e) { s+= e;}
  } // for
  alert(s);
} // inspectObj
function d(obj) {
  inspectObj(obj)
}

// ----- End -----
