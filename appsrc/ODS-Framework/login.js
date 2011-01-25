/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2010 OpenLink Software
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

var lfTab;
var lfFacebookData;
var lfOptions;
var lfAjaxs = 0;
var lfAttempts = 0;

function lfRowValue(tbl, label, value, leftTag) {
  if (!leftTag) {
    leftTag = 'th';
  }
  var tr = OAT.Dom.create('tr');
  var th = OAT.Dom.create(leftTag);
  th.width = '20%';
  th.innerHTML = label;
  tr.appendChild(th);
  if (value) {
    var td = OAT.Dom.create('td');
    td.innerHTML = value;
    tr.appendChild(td);
  }
  tbl.appendChild(tr);
}

function lfInit() {
  if (!$("lf")) {return;}

  lfOptrions = {onstart: lfStart, onend: lfEnd};
  var regData;
  var x = function (data) {
    try {
      regData = OAT.JSON.parse(data);
    } catch (e) { regData = {}; }
  }
  OAT.AJAX.GET ('/ods/api/server.getInfo?info=regData', false, x, {async: false});

  lfTab = new OAT.Tab("lf_content", {goCallback: lfCallback});
  lfTab.add("lf_tab_0", "lf_page_0");
  if (regData.openidEnable)
    OAT.Dom.show('lf_tab_1');
  lfTab.add("lf_tab_1", "lf_page_1");
  lfTab.add("lf_tab_2", "lf_page_2");
  lfTab.add("lf_tab_3", "lf_page_3");
  if (regData.twitterEnable)
    OAT.Dom.show('lf_tab_4');
  lfTab.add("lf_tab_4", "lf_page_4");
  if (regData.linkedinEnable)
    OAT.Dom.show('lf_tab_5');
  lfTab.add("lf_tab_5", "lf_page_5");
  lfTab.go(0);
  var uriParams = OAT.Dom.uriParams();
  if (uriParams['oid-form'] == 'lf') {
    OAT.Dom.show('lf');
    if (uriParams['oid-mode'] == 'twitter') {
      lfTab.go(4);
      $('lf_login').click();
    }
    else if (uriParams['oid-mode'] == 'linkedin') {
      lfTab.go(5);
      $('lf_login').click();
    }
    else {
      $('lf_openId').value = uriParams['openid.identity'];
    lfTab.go(1);
    if (typeof (uriParams['openid.signed']) != 'undefined' && uriParams['openid.signed'] != '')
    {
      OAT.AJAX.POST("/ods/api/user.authenticate", lfOpenIdLoginURL(uriParams), $('lf_login').onclick);
    }
    else if (typeof (uriParams['openid.mode']) != 'undefined' && uriParams['openid.mode'] == 'cancel')
    {
      alert('OpenID Authentication Failed');
    }
    }
  }

  if (regData.facebookEnable) {
    lfLoadFacebookData(function() {
      if (lfFacebookData)
        FB.init(lfFacebookData.api_key, "/ods/fb_dummy.vsp", {
          ifUserConnected : function() {
            lfShowFacebookData();
          },
          ifUserNotConnected : function() {
            lfHideFacebookData();
          }
        });
    });
  }

  if ((document.location.protocol == 'https:') && regData.sslEnable) {
    var x = function(data) {
      var sslData;
      try {
        sslData = OAT.JSON.parse(data);
      } catch (e) {
        sslData = null;
      }
      if (sslData && sslData.iri && sslData.certLogin) {
        var prefix = 'lf';
        OAT.Dom.show(prefix+"_tab_3");
        var tbl = $(prefix+'_table_3');
        if (tbl) {
          lfRowValue(tbl, 'WebID', sslData.iri);
          if (sslData.firstName)
            lfRowValue(tbl, 'First Name', sslData.firstName);
          if (sslData.family_name)
            lfRowValue(tbl, 'Family Name', sslData.family_name);
          if (sslData.mbox)
            lfRowValue(tbl, 'E-Mail', sslData.mbox);

          lfTab.go(3);
        }
      }
    }
    OAT.AJAX.GET('/ods/api/user.getFOAFSSLData?sslFOAFCheck=1', '', x);
  }
}

function lfCallback(oldIndex, newIndex) {
  if (newIndex == 0)
    $('lf_login').value = 'Login';
  else if (newIndex == 1)
    $('lf_login').value = 'OpenID Login';
  else if (newIndex == 2)
    $('lf_login').value = 'Facebook Login';
  else if (newIndex == 3)
    $('lf_login').value = 'WebID Login';
  else if (newIndex == 4)
    $('lf_login').value = 'Twitter';
  else if (newIndex == 5)
    $('lf_login').value = 'LinkedIn';

  pageFocus('lf_page_'+newIndex);
}

function lfStart() {
  lfAjaxs++;
  var inputs = $("lf").getElementsByTagName('input');
  for (var i = 0; i < inputs.length; i++)
    inputs[i].tokenReceived = false;

  $('lf_login').disabled = true;
  $('lf_register').disabled = true;
	OAT.Dom.hide('lf_close');
	OAT.Dom.show('lf_throbber');
}

function lfEnd() {
  lfAjaxs--;
  if (lfAjaxs == 0) {
    var inputs = $("lf").getElementsByTagName('input');
    for (var i = 0; i < inputs.length; i++)
      inputs[i].tokenReceived = true;

    OAT.Dom.hide('lf_throbber');
  	OAT.Dom.show('lf_close');
    $('lf_login').disabled = false;
    $('lf_register').disabled = false;
  }
}

function lfLoginSubmit(cb) {
  var mode = lfTab.selectedIndex;
  var prefix = 'lf';
  var q = '';
  if (mode == 1) {
    var uriParams = OAT.Dom.uriParams();
    if (typeof (uriParams['openid.signed']) != 'undefined' && uriParams['openid.signed'] != '') {
      q += lfOpenIdLoginURL(uriParams);
    } else {
      if ($(prefix+'_openId').value.length == 0)
        return showError('Invalid OpenID URL');

      lfOpenIdAuthenticate(prefix);
      return false;
    }
  } else if (mode == 2) {
    if (!lfFacebookData || !lfFacebookData.uid)
      return showError('Invalid Facebook UserID');

    q += '&facebookUID=' + lfFacebookData.uid;
  } else if (mode == 3) {
  } else if (mode == 4) {
    var uriParams = OAT.Dom.uriParams();
	  if ((typeof (uriParams['oauth_verifier']) == 'undefined') || (typeof (uriParams['oauth_token']) == 'undefined')) {
      twitterAuthenticate('lf');
      return false;
    }
    q +='oauthMode=twitter'
      + '&oauthSid=' + encodeURIComponent(uriParams['sid'])
      + '&oauthVerifier=' + encodeURIComponent(uriParams['oauth_verifier'])
      + '&oauthToken=' + encodeURIComponent(uriParams['oauth_token']);
  } else if (mode == 5) {
    var uriParams = OAT.Dom.uriParams();
	  if ((typeof (uriParams['oauth_verifier']) == 'undefined') || (typeof (uriParams['oauth_token']) == 'undefined')) {
      linkedinAuthenticate('lf');
      return false;
    }
    q +='oauthMode=linkedin'
      + '&oauthSid=' + encodeURIComponent(uriParams['sid'])
      + '&oauthVerifier=' + encodeURIComponent(uriParams['oauth_verifier'])
      + '&oauthToken=' + encodeURIComponent(uriParams['oauth_token']);
  } else {
    if (($(prefix+'_uid').value.length == 0) || ($(prefix+'_password').value.length == 0))
      return showError('Invalid User ID or Password');

    q +='user_name=' + encodeURIComponent($v(prefix+'_uid'))
      + '&password_hash=' + encodeURIComponent(OAT.Crypto.sha($v(prefix+'_uid') + $v(prefix+'_password')));
  }
  OAT.AJAX.POST("/ods/api/user.authenticate", q, ((cb)? cb: lfAfterLogin), lfOptrions);
  return false;
}

function lfAfterLogin(data) {
  var xml = OAT.Xml.createXmlDoc(data);
  if (!hasError(xml)) {
    lfAttempts = 0;
    OAT.Dom.hide('lf_forget');

    var frm = document.forms['page_form'];
    hiddenCreate('sid', frm, OAT.Xml.textValue(xml.getElementsByTagName('sid')[0]));
    hiddenCreate('realm', frm, 'wa');
    hiddenCreate('command', frm, 'login');
  	doPost('page_form', 'lf_login2');
  } else {
    lfAttempts++;
    OAT.Dom.show('lf_forget');
  }
  return false;
}

function lfOpenIdLoginURL(uriParams) {
  var openIdServer       = uriParams['oid-srv'];
  var openIdSig          = uriParams['openid.sig'];
  var openIdIdentity     = uriParams['openid.identity'];
  var openIdAssoc_handle = uriParams['openid.assoc_handle'];
  var openIdSigned       = uriParams['openid.signed'];

  var url = openIdServer + ((openIdServer.lastIndexOf('?') != -1)? '&': '?') +
    'openid.mode=check_authentication' +
    '&openid.assoc_handle=' + encodeURIComponent (openIdAssoc_handle) +
    '&openid.sig='          + encodeURIComponent (openIdSig) +
    '&openid.signed='       + encodeURIComponent (openIdSigned);

  var sig = openIdSigned.split(',');
  for (var i = 0; i < sig.length; i++)
  {
    var _key = sig[i].trim ();
    if (_key != 'mode' &&
        _key != 'signed' &&
        _key != 'assoc_handle')
    {
      var _val = uriParams['openid.' + _key];
      if (_val != '')
        url += '&openid.' + _key + '=' + encodeURIComponent (_val);
    }
  }
  return '&openIdUrl=' + encodeURIComponent (url) + '&openIdIdentity=' + encodeURIComponent (openIdIdentity);
}

function lfOpenIdAuthenticate(prefix) {
  var q = 'openIdUrl=' + encodeURIComponent($v(prefix+'_openId'));
  var x = function (data) {
    var xml = OAT.Xml.createXmlDoc(data);
    var error = OAT.Xml.xpath (xml, '//error_response', {});
    if (error.length)
      showError('Invalied OpenID Server');

    var oidServer = OAT.Xml.textValue (OAT.Xml.xpath (xml, '/openIdServer_response/server', {})[0]);
    if (!oidServer || !oidServer.length)
      showError(' Cannot locate OpenID server');

    var oidVersion = OAT.Xml.textValue (OAT.Xml.xpath (xml, '/openIdServer_response/version', {})[0]);
    var oidDelegate = OAT.Xml.textValue (OAT.Xml.xpath (xml, '/openIdServer_response/delegate', {})[0]);
		var oidUrl = OAT.Xml.textValue(OAT.Xml.xpath(xml, '/openIdServer_response/identity', {})[0]);

    var oidIdent = oidUrl;
    if (oidDelegate && oidDelegate.length)
      oidIdent = oidDelegate;

    var thisPage  = document.location.protocol +
      '//' +
      document.location.host +
      document.location.pathname +
      '?oid-form=' + prefix +
      '&oid-srv=' + encodeURIComponent (oidServer);

    var trustRoot = document.location.protocol + '//' + document.location.host;

    var S = oidServer + ((oidServer.lastIndexOf('?') != -1)? '&': '?') +
      'openid.mode=checkid_setup' +
      '&openid.return_to=' + encodeURIComponent(thisPage);

    if (oidVersion == '1.0')
      S +='&openid.identity=' + encodeURIComponent(oidIdent)
        + '&openid.trust_root=' + encodeURIComponent(trustRoot);

    if (oidVersion == '2.0')
      S +='&openid.ns=' + encodeURIComponent('http://specs.openid.net/auth/2.0')
        + '&openid.claimed_id=' + encodeURIComponent(oidIdent)
        + '&openid.identity=' + encodeURIComponent(oidIdent)

    document.location = S;
  };
  OAT.AJAX.POST ("/ods_services/Http/openIdServer", q, x);
}

function twitterAuthenticate(prefix) {
  var thisPage  = document.location.protocol +
    '//' +
    document.location.host +
    document.location.pathname +
    '?oid-mode=twitter&oid-form=' + prefix;

  var x = function (data) {
    document.location = data;
  }
  OAT.AJAX.POST ("/ods/api/twitterServer?hostUrl="+encodeURIComponent(thisPage), null, x);
}

function linkedinAuthenticate(prefix) {
  var thisPage  = document.location.protocol +
    '//' +
    document.location.host +
    document.location.pathname +
    '?oid-mode=linkedin&oid-form=' + prefix;

  var x = function (data) {
    document.location = data;
  }
  OAT.AJAX.POST ("/ods/api/linkedinServer?hostUrl="+encodeURIComponent(thisPage), null, x);
}

function lfLoadFacebookData(cb) {
  var x = function(data) {
    try {
      lfFacebookData = OAT.JSON.parse(data);
    } catch (e) {
      lfFacebookData = null;
    }

    if (lfFacebookData)
      OAT.Dom.show("lf_tab_2");

    if (cb) {cb()};
  }
  OAT.AJAX.GET('/ods/api/user.getFacebookData?fields=uid,name,first_name,last_name,sex,birthday', '', x);
}

function lfShowFacebookData(skip) {
  var lfLabel = $('lf_facebookData');
  if (lfLabel) {
    lfLabel.innerHTML = '';
    if (lfFacebookData && lfFacebookData.name) {
      lfLabel.innerHTML = 'Connected as <b><i>' + lfFacebookData.name + '</i></b></b>';
    } else if (!skip) {
      lfLoadFacebookData(function() {lfShowFacebookData(true);});
    }
  }
}

function lfHideFacebookData() {
  var label = $('lf_facebookData');
  if (label)
    label.innerHTML = '';
  if (lfFacebookData) {
    var o = {}
    o.api_key = lfFacebookData.api_key;
    o.secret = lfFacebookData.secret;
    lfFacebookData = o;
  }
}
