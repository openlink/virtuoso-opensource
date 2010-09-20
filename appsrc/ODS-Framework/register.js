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

var rfTab;
var rfFacebookData;
var rfSslData;
var rfOptions;
var rfAjaxs = 0;

function rfRowValue(tbl, label, value, leftTag) {
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

function rfRowInput(tbl, label, fName) {
  var tr = OAT.Dom.create('tr');
  tr.id = 'tr+'+fName;

  var th = OAT.Dom.create('th');
  th.width = '30%';
  th.innerHTML = label + '<div style="font-weight: normal; display: inline; color: red;"> *</div>';
  tr.appendChild(th);

  var td = OAT.Dom.create('td');
  tr.appendChild(td);

  var fld = OAT.Dom.create('input');
  fld.type = 'type';
  fld.id = fName;
  fld.name = fld.id;
  td.appendChild(fld);

  tbl.appendChild(tr);
}

function rfInit() {
  if (!$("rf")) {return;}

  var regData;
  var x = function (data) {
    try {
      regData = OAT.JSON.parse(data);
    } catch (e) { regData = {}; }
  }
  OAT.AJAX.GET ('/ods/api/server.getInfo?info=regData', false, x, {async: false});

  rfTab = new OAT.Tab("rf_content", {goCallback: rfCallback});
  rfTab.add("rf_tab_0", "rf_page_0");
  if (regData.openidEnable)
    OAT.Dom.show('rf_tab_1');
  rfTab.add("rf_tab_1", "rf_page_1");
  rfTab.add("rf_tab_2", "rf_page_2");
  rfTab.add("rf_tab_3", "rf_page_3");
  rfTab.go(0);

  var uriParams = OAT.Dom.uriParams();
  if (uriParams['oid-form'] == 'rf') {
    OAT.Dom.show('rf');
    rfTab.go(1);
    if (typeof (uriParams['openid.signed']) != 'undefined' && uriParams['openid.signed'] != '') {
      var x = function (params, param, data, property) {
        if (params[param] && params[param].length != 0)
          data[property] = params[param];
      }
      var data = {};
      var ns;
      for (var prop in uriParams) {
        if (uriParams.hasOwnProperty(prop) && (uriParams[prop] == 'http://openid.net/srv/ax/1.0')) {
          ns = prop.replace('openid.ns.', '');
          break;
        }
      }
      if (ns) {
        x(uriParams, 'openid.'+ns+'.value.country', data, 'homeCountry');
        x(uriParams, 'openid.'+ns+'.value.email', data, 'mbox');
        x(uriParams, 'openid.'+ns+'.value.firstname', data, 'firstName');
        x(uriParams, 'openid.'+ns+'.value.fname', data, 'name');
        x(uriParams, 'openid.'+ns+'.value.language', data, 'language');
        x(uriParams, 'openid.'+ns+'.value.lastname', data, 'family_name');
        x(uriParams, 'openid.'+ns+'.value.fname', data, 'nick');
        x(uriParams, 'openid.'+ns+'.value.timezone', data, 'timezone');
      } else {
        x(uriParams, 'openid.sreg.nickname', data, 'nick');
        x(uriParams, 'openid.sreg.email', data, 'mbox');
        x(uriParams, 'openid.sreg.fullname', data, 'name');
        x(uriParams, 'openid.sreg.dob', data, 'birthday');
        x(uriParams, 'openid.sreg.gender', data, 'gender');
        x(uriParams, 'openid.sreg.postcode', data, 'homeCode');
        x(uriParams, 'openid.sreg.country', data, 'homeCountry');
        x(uriParams, 'openid.sreg.timezone', data, 'homeTimezone');
        x(uriParams, 'openid.sreg.language', data, 'language');
      }
      x(uriParams, 'openid.identity', data, 'openid_url');
      x(uriParams, 'oid-srv', data, 'openid_server');

      $('rf_openId').value = uriParams['openid.identity'];
      $('rf_is_agreed').checked = true;
      if (!data['nick'] || !data['mbox']) {
        hiddenCreate('oid-data', null, OAT.JSON.stringify(data));
        var tbl = $('rf_table_1');
        if (!data['nick'])
          rfRowInput(tbl, 'Login Name', 'rf_openid_uid');
        if (!data['mbox'])
          rfRowInput(tbl, 'E-Mail', 'rf_openid_email');
      } else {
        var q = 'mode=1&data=' + encodeURIComponent(OAT.JSON.stringify(data));
        OAT.AJAX.POST ("/ods/api/user.register", q, rfAfterSignup);
      }
    }
    else if (typeof (uriParams['openid.mode']) != 'undefined' && uriParams['openid.mode'] == 'cancel')
    {
      alert('OpenID Authentication Failed');
    }
  }
  if (regData.facebookEnable) {
    rfLoadFacebookData(function() {
      if (rfFacebookData)
        FB.init(rfFacebookData.api_key, "/ods/fb_dummy.vsp", {
          ifUserConnected : function() {
            rfShowFacebookData();
          },
          ifUserNotConnected : function() {
            rfHideFacebookData();
          }
        });
    });
  }

  if ((document.location.protocol == 'https:') && regData.sslEnable) {
    var x = function(data) {
      try {
        rfSslData = OAT.JSON.parse(data);
      } catch (e) {
        rfSslData = null;
      }
      if (rfSslData && rfSslData.iri && !rfSslData.certLogin) {
        var prefix = 'rf';
        OAT.Dom.show(prefix+"_tab_3");
        var tbl = $(prefix+'_table_3');
        if (tbl) {
          rfRowValue(tbl, 'WebID', rfSslData.iri);
          if (rfSslData.firstName)
            rfRowValue(tbl, 'First Name', rfSslData.firstName);
          if (rfSslData.family_name)
            rfRowValue(tbl, 'Family Name', rfSslData.family_name);
          if (rfSslData.mbox)
            rfRowValue(tbl, 'E-Mail', rfSslData.mbox);
          rfTab.go(3);
        }
      }
    }
    OAT.AJAX.GET('/ods/api/user.getFOAFSSLData?sslFOAFCheck=1', '', x);
  }
}

function rfCallback(oldIndex, newIndex) {
  if (newIndex == 0)
    $('rf_signup').value = 'Sign Up';
  if (newIndex == 1)
    $('rf_signup').value = 'OpenID Sign Up';
  if (newIndex == 2)
    $('rf_signup').value = 'Facebook Sign Up';
  if (newIndex == 3)
    $('rf_signup').value = 'WebID Sign Up';
}

function rfStart() {
  rfAjaxs++;
  $('rf_signup').disabled = true;
	OAT.Dom.hide('rf_close');
	OAT.Dom.show('rf_throbber');
}

function rfEnd() {
  rfAjaxs--;
  if (rfAjaxs == 0) {
    OAT.Dom.hide('rf_throbber');
  	OAT.Dom.show('rf_close');
    $('rf_signup').disabled = false;
  }
}

function rfSignupSubmit(event) {
  if (rfTab.selectedIndex == 0) {
    if ($v('rf_uid') == '')
      return showError('Bad username. Please correct!');
    if ($v('rf_email') == '')
      return showError('Bad mail. Please correct!');
    if ($v('rf_password') == '')
      return showError('Bad password. Please correct!');
    if ($v('rf_password') != $v('rf_password2'))
      return showError('Bad password. Please retype!');
  } else if (rfTab.selectedIndex == 1) {
    if ($v('rf_openId') == '')
      return showError('Bad openID. Please correct!');
  } else if (rfTab.selectedIndex == 2) {
    if (!rfFacebookData || !rfFacebookData.uid)
      return showError('Invalid Facebook UserID');
  } else if (rfTab.selectedIndex == 3) {
    if (!rfSslData || !rfSslData.iri)
      return showError('Invalid WebID UserID');
  }
  if (!$('rf_is_agreed').checked)
    return showError('You have not agreed to the Terms of Service!');

  var q = 'mode=' + encodeURIComponent(rfTab.selectedIndex);
  if (rfTab.selectedIndex == 0) {
    q +='&name=' + encodeURIComponent($v('rf_uid'))
      + '&password=' + encodeURIComponent($v('rf_password'))
      + '&email=' + encodeURIComponent($v('rf_email'));
  }
  else if (rfTab.selectedIndex == 1) {
    if (!$('oid-data')) {
      rfOpenIdAuthenticate('rf');
      return false;
    }
    q += '&data=' + encodeURIComponent($v('oid-data'));
    if ($('rf_openid_uid'))
      q +='&name=' + encodeURIComponent($v('rf_openid_uid'));
    if ($('rf_openid_email'))
      q +='&email=' + encodeURIComponent($v('rf_openid_email'));
  }
  else if (rfTab.selectedIndex == 2) {
    q += '&data=' + encodeURIComponent(OAT.JSON.stringify(rfFacebookData))
  }
  else if (rfTab.selectedIndex == 3) {
    q +='&data=' + encodeURIComponent(OAT.JSON.stringify(rfSslData));
    if ($('rf_webid_uid'))
      q +='&name=' + encodeURIComponent($v('rf_webid_uid'));
    if ($('rf_webid_email'))
      q +='&email=' + encodeURIComponent($v('rf_webid_email'));
  }
  OAT.AJAX.POST("/ods/api/user.register", q, rfAfterSignup, rfOptions);
  return false;
}

function rfAfterSignup(data) {
  var xml = OAT.Xml.createXmlDoc(data);
  if (!hasError(xml)) {
    var form = document.forms['page_form'];
    hiddenCreate('sid', form, OAT.Xml.textValue(xml.getElementsByTagName('sid')[0]));
    hiddenCreate('realm', form, 'wa');
    document.forms['page_form'].submit();
  }
  return false;
}

function rfOpenIdAuthenticate(prefix) {
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
    var oidParams = OAT.Xml.textValue (OAT.Xml.xpath (xml, '/openIdServer_response/params', {})[0]);
    if (!oidParams || !oidParams.length)
      oidParams = 'sreg';

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

    if (oidParams = 'sreg')
      S +='&openid.sreg.optional='+encodeURIComponent('fullname,nickname,dob,gender,postcode,country,timezone')
        + '&openid.sreg.required=' + encodeURIComponent('email,nickname');

    if (oidParams = 'ax')
      S +='&openid.ns.ax=http://openid.net/srv/ax/1.0'
        + '&openid.ax.mode=fetch_request'
        + '&openid.ax.required=country,email,firstname,fname,language,lastname,timezone'
        + '&openid.ax.type.country=http://axschema.org/contact/country/home'
        + '&openid.ax.type.email=http://axschema.org/contact/email'
        + '&openid.ax.type.firstname=http://axschema.org/namePerson/first'
        + '&openid.ax.type.fname=http://axschema.org/namePerson'
        + '&openid.ax.type.language=http://axschema.org/pref/language'
        + '&openid.ax.type.lastname=http://axschema.org/namePerson/last'
        + '&openid.ax.type.timezone=http://axschema.org/pref/timezone';

    document.location = S;
  };
  OAT.AJAX.POST ("/ods_services/Http/openIdServer", q, x);
}

function rfLoadFacebookData(cb) {
  var x = function(data) {
    try {
      rfFacebookData = OAT.JSON.parse(data);
    } catch (e) {
      rfFacebookData = null;
    }
    if (rfFacebookData)
      OAT.Dom.show("rf_tab_2");

    if (cb) {cb()};
  }
  OAT.AJAX.GET('/ods/api/user.getFacebookData?fields=uid,name,first_name,last_name,sex,birthday', '', x);
}

function rfShowFacebookData(skip) {
  var rfLabel = $('rf_facebookData');
  if (rfLabel) {
    rfLabel.innerHTML = '';
    if (rfFacebookData && rfFacebookData.name) {
      rfLabel.innerHTML = 'Connected as <b><i>' + rfFacebookData.name + '</i></b></b>';
    } else if (!skip) {
      rfLoadFacebookData(function() {self.rfShowFacebookData(true);});
    }
  }
}

function rfHideFacebookData() {
  var label = $('rf_facebookData');
  if (label)
    label.innerHTML = '';
  if (rfFacebookData) {
    var o = {}
    o.api_key = rfFacebookData.api_key;
    o.secret = rfFacebookData.secret;
    rfFacebookData = o;
  }
}
