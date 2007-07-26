/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2007 OpenLink Software
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

function getXTR () {
  var xtr;

  if (typeof(XMLHttpRequest) != "undefined") {
    // The Firefox/Safari/Opera way
    xtr = new XMLHttpRequest();
  } else {
    // The IE way(s)
    try {
      xtr = new ActiveXObject("Msxml2.XMLHTTP.4.0");
    } catch (e) {
      try {
        xtr = new ActiveXObject("Msxml2.XMLHTTP");
      } catch (ex) {
      }
    }
  }
  return xtr;
}

function openID_include (uri) {
  window.open (uri, "OpenID_window", "");
}

// args is object with keys:
//   client_url:          the HTML URL the client provided. is just
//                        sent as-is to the helper URL on the server.
//   helper_url:          the URL of the helper on the server
//   on_success:          (canonical_identity_url, id_server, oid_ret, sig)
//   on_error             (errtxt) general error callback
//   on_need_permissions  (url) URL to send user
//
function openID_verify (optsParams) {
  var xtr = getXTR();
  var nf = function () {};  // null function

  // make a copy to work around Safari bug w/ closures not capturing formal parameters
  var opts = optsParams;

  // make a top-level function that captures some internal variables
  window.OpenID_callback_pass = function (obj) {
    (opts.on_success||nf)(obj);
  };
  window.OpenID_callback_fail = function (url) {
    (opts.on_need_permissions||nf)(url);
  };
  window.OpenID_general_error = function (error) {
    (opts.on_error||nf)(error.err_code, error.err_text);
  };

  var state_callback = function () {
    var ex;
    var helperRes;

    if (xtr.readyState != 4)
      return;

    if (xtr.status == 200) {
      try {
        (opts.on_debug||nf)("responseText = [" + xtr.responseText + "]");
        try {
          eval("var helperRes = " + xtr.responseText + ";\n");
        } catch (ex) {
          (opts.on_error||nf)("invalid_json", "Got invalid JSON response from helper.  Got: " + xtr.responseText + ", e = " + ex);
          return;
        }

        if (helperRes.err_code) {
          (opts.on_error||nf)(helperRes.err_code, helperRes.err_text);
          return;
        }

        var cleanIdentityURL = helperRes.clean_identity_url;
        var macKey = helperRes.openid_key;

        (opts.on_post_helper||nf)(helperRes.id_server, cleanIdentityURL, macKey);
        opts.id_server = helperRes.id_server;

        openID_include(helperRes.checkid_immediate_url);

      } catch (ex) {
        (opts.on_error||nf)("iframe_exception", "Error loading remote iframe: " + ex);
      }
    } else {
      (opts.on_error||nf)("helper_not_200", "Didn't get status code 200 contacting helper.  Got: " + xtr.status);
    }
  }
  xtr.onreadystatechange = state_callback;
  xtr.open("GET", opts.helper_url + "?openid_url=" + escape(opts.client_url) +'&openid_action=' + opts.client_action, true);
  xtr.send(null);
}

function cbDebug (txt) {
}

function cbSuccess (obj) {
  var xml = OAT.Xml.createXmlDoc(obj);
  afterLogin(xml);
  cbSuccessWork ();
}

function cbSuccess2 (obj) {
  var xml = OAT.Xml.createXmlDoc(obj);
  afterLogin(xml);
  cbSuccessWork ();
}

function cbSuccess3 (obj) {
  var xml = OAT.Xml.createXmlDoc(obj);
  afterAuthenticate(xml);
  cbSuccessWork ();
}

function cbSuccessWork () {
  // find the setup window, if they clicked the regular link
  if (! setupWin) {
    try {
      setupWin = window.open("about:blank", "user_setup_url_win");
    } catch (e) { }
  }

  // and now try to close whatever it was
  try {
    if (setupWin)
      setupWin.close();
  } catch (e) { }
}

function cbError (errorCode, errorTxt) {
  alert (errorTxt);
}

function cbNeedPermissions (url) {
  alert ('You need permissions to '+URL);
}
