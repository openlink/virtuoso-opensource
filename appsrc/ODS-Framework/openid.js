/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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
*/

var setupWin;
var imagePath;
var helperPath;

function cbSuccess (url, idserver, oid_ret, sig, nam, mail) {
    setImage ('login-bg.gif');
    setNote ('', '#FFFFFF');
    var ex, elm;
    var oid_sig = document.getElementById('oid_sig');
    oid_sig.value = oid_ret;

    elm = document.getElementById('email1');
    elm.value = mail;
    elm = document.getElementById('name1');
    elm.value = nam;

    // find the setup window, if they clicked the regular link
    if (! setupWin) {
	try {
		setupWin = window.open("about:blank", "user_setup_url_win");
        } catch (ex) { }
    }

    // and now try to close whatever it was
//    try {
//	    if (setupWin)
//		setupWin.close();
//    } catch (ex) { }

    prepareWipeOnType();
}

function cbError (errcode, errtxt) {
    setImage ('excl_16.gif');
    setNote("<b>Error:</b> " + ehtml(errtxt), '#FFA3A2');

    prepareWipeOnType();

    var ue = document.getElementById('openid_url');
    ue.focus();
}

function ehtml (str) {
        if (!str) return "";
	return str.replace(/&/g, "&amp;").replace(/\"/g, "&quot;").replace(/\'/g, "&#39;").replace(/>/g, "&gt;").replace(/</g, "&lt;");
}

var setup_URL;

function popSetupURL () {
    setupWin = window.open(setup_URL, "user_setup_url_win");
    return false;
}

function cbNeedPermissions (url) {
    setImage ('excl_16.gif');
    setup_URL = url;
    setNote("<b>Note:</b> You need to <a onclick='return popSetupURL();' target='user_setup_url_win' href='" + url + "'>grant permission</a> for this site to know who you are.  Once you do so, press Login again.", '#FBFFC6');

    popSetupURL();
    prepareWipeOnType();
}

function cbDebug (txt) {
}

function cbPostHelper (id, url, macKey) {
    var oid_key = document.getElementById('oid_key');
    setImage ('wait_16.gif');
    prepareWipeOnType();
    if (oid_key != null)
      oid_key.value = macKey;
}

function setPaths (image_path, helper_path)
{
  imagePath = '/weblog/public/images/';
  helperPath = '/weblog/public/';
  if (image_path != null)
    imagePath = image_path;
  if (helper_path != null)
    helperPath = helper_path;
}

function setImage (img)
{
  var msg = document.getElementById('img');
  msg.innerHTML = '<img src="' + imagePath + img +'" border="0" hspace="1" alt="'+ img +'" />';
  if (img != '')
    msg.style.visibility = "visible";
  else
    msg.style.visibility = "hidden";
}

function stopBubble (e) {
    if (e.stopPropagation)
        e.stopPropagation();
    if ("cancelBubble" in e)
        e.cancelBubble = true;
}

// stops the bubble, as well as the default action
function stopEvent (e) {
    stopBubble(e);
    if (e.preventDefault)
        e.preventDefault();
    if ("returnValue" in e)
        e.returnValue = false;
    return false;
}

function regEvent (target, evt, func) {
    if (! target) return;
    if (target.attachEvent)
        target.attachEvent("on"+evt, func);
    if (target.addEventListener)
        target.addEventListener(evt, func, false);
}

function onClickVerify (e) {
    if (!e) e = window.event;

    setNote ('', '#FFFFFF');
    setImage ('');
    var ue = document.getElementById('openid_url');
    if (!ue) return alert("assert: no ue");

    var client_url = ue.value;

	var opts = {
	    'client_url': client_url,
	    'on_success': cbSuccess,
	    'on_error': cbError,
	    'on_debug': cbDebug,
	    'on_need_permissions': cbNeedPermissions,
	    'on_post_helper': cbPostHelper,
	    'post_grant': "close"
	    };

    opts.helper_url = "http://" + location.host + helperPath + "openid_helper.vsp";

    OpenID_verify(opts);

    setImage ('wait_16.gif');

    return stopEvent(e);
}

function setNote (txt, color) {
    var me = document.getElementById('msg');
    if (!me) return alert("assert: no me");
    me.innerHTML = txt;
    me.style.background = color;
}

function introUI () {
    var oid_sig = document.getElementById('oid_sig');
    setImage ('');
    setNote ('', '#FFFFFF');
    oid_sig.value = '';
    removeWipeOnType();
}

function prepareWipeOnType () {
    var ue = document.getElementById('openid_url');
    ue.onkeydown = introUI;
    ue.onkeypress = introUI;
}

function removeWipeOnType () {
    var ue = document.getElementById('openid_url');
    ue.onkeydown = null;
    ue.onkeypress = null;
}


function _OpenID_iframe_include (uri) {

    //var se = document.createElement("iframe");
    //se.width = 1;
    //se.height = 1;
    //se.style.display = 'inline';
    //se.style.border = '0';

    //var be = document.getElementsByTagName('body').item(0);
    //be.appendChild(se);
    //se.contentWindow.location = uri;
    window.open (uri, "OpenID_window", "");
}


// returns whether the browser is able to do the client-side version of OpenID
function OpenID_capable () {
    return getXTR() ? 1 : 0;
}


// args is object with keys:
//       client_url:   the HTML URL the client provided. is just
//                     sent as-is to the helper URL on the server.
//       helper_url:   the URL of the helper on the server
//       on_success:   (canonical_identity_url, id_server, oid_ret, sig)
//       on_error       (errtxt) general error callback
//       on_need_permissions   (url) URL to send user

function OpenID_verify (arg_hargs) {

    var xtr = getXTR();
    var nf = function () {};  // null function

    // make a copy to work around Safari bug w/ closures not capturing formal parameters
    var hargs = arg_hargs;

    // make a top-level function that captures some internal variables
    window.OpenID_callback_pass = function (identityURL, sig, oid_ret, nam, mail) {
	(hargs.on_success||nf)(identityURL, hargs.id_server, oid_ret, sig, nam, mail);
    };
    window.OpenID_callback_fail = function (url) {
	(hargs.on_need_permissions||nf)(url);
    };
    window.OpenID_general_error = function (erro) {
	(hargs.on_error||nf)(erro.err_code, erro.err_text);
    };

    var state_callback = function () {
	var ex;
	var helperRes;

        if (xtr.readyState != 4)
             return;

        if (xtr.status == 200) {
	    try {
		(hargs.on_debug||nf)("responseText = [" + xtr.responseText + "]");

		try {
		    eval("var helperRes = " + xtr.responseText + ";\n");
		} catch (ex) {
		    (hargs.on_error||nf)("invalid_json", "Got invalid JSON response from helper.  Got: " + xtr.responseText + ", e = " + ex);
		    return;
		}

		if (helperRes.err_code) {
		    (hargs.on_error||nf)(helperRes.err_code, helperRes.err_text);
		    return;
		}

		var cleanIdentityURL = helperRes.clean_identity_url;
	        var macKey = helperRes.openid_key;

		(hargs.on_post_helper||nf)(helperRes.id_server, cleanIdentityURL, macKey);

	        hargs.id_server = helperRes.id_server;

		_OpenID_iframe_include(helperRes.checkid_immediate_url);

	    } catch (ex) {
		(hargs.on_error||nf)("iframe_exception", "Error loading remote iframe: " + ex);
	    }

        } else {
	    (hargs.on_error||nf)("helper_not_200", "Didn't get status code 200 contacting helper.  Got: " + xtr.status);
	}


    };

    xtr.onreadystatechange = state_callback;
    xtr.open("GET", hargs.helper_url + "?openid_url=" + escape(hargs.client_url), true);
    xtr.send(null);
}

function getXTR (need_req_header) {
    var xtr;
    var ex;

    if (typeof(XMLHttpRequest) != "undefined") {
	// The Firefox/Safari/Opera way
        xtr = new XMLHttpRequest();
    } else {
	// The IE way(s)

        try {
            xtr = new ActiveXObject("Msxml2.XMLHTTP.4.0");
        } catch (ex) {
            try {
                xtr = new ActiveXObject("Msxml2.XMLHTTP");
            } catch (ex) {
            }
        }
    }

    if (need_req_header) {
	    // don't work in Opera that only half-supports XMLHttpRequest
	    try {
        	    if (xtr && ! xtr.setRequestHeader)
	            xtr = null;
	    } catch (ex) { }
    }

    return xtr;
}
