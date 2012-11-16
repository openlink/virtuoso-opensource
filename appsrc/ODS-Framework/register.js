/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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

var regData;
var facebookData;
var rfTab;
var rfSslData;
var rfOptions;
var rfAjaxs = 0;
var rfSslLinks = {"in": [], "up": []};

function rfRowText(tbl, txt, txtCSSText) {
  var tr = OAT.Dom.create('tr');
  var td = OAT.Dom.create('td');
  td.colSpan = 2;
  td.style.cssText = txtCSSText;
  td.innerHTML = txt;
  tr.appendChild(td);
  tbl.appendChild(tr);

  return td;
}

function rfRowButtonClick(obj) {
  var interface = readCookie('interface');
  if (interface == 'js') {
    var ssl = parent.document.getElementById('ssl_link');
    if (ssl) {
      if      (obj.href.indexOf('login.vspx') != -1)
        parent.document.location = ssl.href + '&form=login';

      else if (obj.href.indexOf('register.vspx') != -1)
        parent.document.location = ssl.href + '&form=register';

      return false;
    }
  }
  return true;
}

function rfRowButton(td, id) {
  var a = OAT.Dom.create ("a");
  a.id = id;
  a.href = document.location.protocol + '//' + document.location.host + '/ods/login.vspx';
  a.onclick = function(){return rfRowButtonClick(this);};
  a.innerHTML = 'Sign In (SSL)';

  td.appendChild(a);
  rfSslLinks['in'].push(a);
}

function rfRowButton2(td, id) {
  var a = OAT.Dom.create ("a");
  a.id = id;
  a.href = document.location.protocol + '//' + document.location.host + '/ods/register.vspx';
  a.onclick = function(){return rfRowButtonClick(this);};
  a.innerHTML = 'Sign Up (SSL)';

  td.appendChild(a);
  rfSslLinks['up'].push(a);
}

function rfRowValue(tbl, label, value, leftTag) {
  if (!leftTag)
    leftTag = 'th';

  var tr = OAT.Dom.create('tr');
  var th = OAT.Dom.create(leftTag, {verticalAlign: 'top'});
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

function rfRowImage(tbl, label, value, leftTag) {
  if (!leftTag)
    leftTag = 'th';

  var tr = OAT.Dom.create('tr');
  var th = OAT.Dom.create(leftTag, {verticalAlign: 'top'});
  th.width = '20%';
  th.innerHTML = label;
  tr.appendChild(th);
  if (value) {
    var td = OAT.Dom.create('td');
    var img = OAT.Dom.create('img', {}, 'resize');
    img.src = value;
    td.appendChild(img);
    tr.appendChild(td);
  }
  tbl.appendChild(tr);
}

function rfRowInput(tbl, label, fName, fOptions) {
  var tr = OAT.Dom.create('tr');
  tr.id = 'tr_'+fName;

  var th = OAT.Dom.create('th');
  th.width = '20%';
  th.innerHTML = label + '<div style="font-weight: normal; display: inline; color: red;"> *</div>';
  tr.appendChild(th);

  var td = OAT.Dom.create('td');
  tr.appendChild(td);

  var fld = OAT.Dom.create('input', fOptions);
  fld.type = 'text';
  fld.id = fName;
  fld.name = fld.id;
  if (fld.value == 'undefined')
    fld.value = '';
  td.appendChild(fld);

  tbl.appendChild(tr);
}

function addProfileRowInput(tbl, label, fName, fOptions) {
  rfRowInput(tbl, label, fName, fOptions);
}

function rfInit() {
  if (!$("rf")) {return;}

  var x = function (data) {
    try {
      regData = OAT.JSON.parse(data);
    } catch (e) { regData = {}; }
  }
  OAT.AJAX.GET ('/ods/api/server.getInfo?info=regData', false, x, {async: false});

  rfTab = new OAT.Tab("rf_content", {goCallback: rfCallback});
  rfTab.add("rf_tab_0", "rf_page_0");
  rfTab.add("rf_tab_1", "rf_page_1");
  rfTab.add("rf_tab_2", "rf_page_2");
  rfTab.add("rf_tab_3", "rf_page_3");
  rfTab.add("rf_tab_4", "rf_page_4");
  rfTab.add("rf_tab_5", "rf_page_5");
  var N = null;
  if (regData.register) {
    if (N == null) N = 0;
    OAT.Dom.show('rf_tab_0');
  }
  if (regData.sslEnable) {
    if (N == null) N = 3;
    OAT.Dom.show('rf_tab_3');
  }
  if (regData.openidEnable) {
    if (N == null) N = 1;
    OAT.Dom.show('rf_tab_1');
  }
  if (regData.twitterEnable) {
    if (N == null) N = 4;
    OAT.Dom.show("rf_tab_4");
  }
  if (regData.linkedinEnable) {
    if (N == null) N = 5;
    OAT.Dom.show("rf_tab_5");
  }
  if (N != null) {
    rfTab.go(N);
  } else {
    rfTab.add("rf_tab_6", "rf_page_6");
  }

  var uriParams = OAT.Dom.uriParams();
  if (uriParams['oid-form'] == 'rf') {
    OAT.Dom.show('rf');
    if (uriParams['oid-mode'] == 'twitter') {
      rfTab.go(4);
      $('rf_is_agreed').checked = true;
      var x = function (data) {
        var xml = OAT.Xml.createXmlDoc(data);
        var user = xml.getElementsByTagName('user')[0];
        if (user && user.getElementsByTagName('id')[0]) {
          hiddenCreate('twitter-data', null, data);
          var tbl = $('rf_table_4');
          rfRowInput(tbl, 'Login Name', 'rf_uid_4', {value: OAT.Xml.textValue(user.getElementsByTagName('screen_name')[0]), width: '150px'});
          rfRowInput(tbl, 'E-Mail', 'rf_email_4', {width: '300px'});
          rfCheckUpdate(4);
        }
        else
        {
          alert('Twitter Authentication Failed');
        }
      }
      var S = "/ods/api/twitterVerify"+
        '?sid=' + encodeURIComponent(uriParams['sid']) +
        '&oauth_verifier=' + encodeURIComponent(uriParams['oauth_verifier']) +
        '&oauth_token=' + encodeURIComponent(uriParams['oauth_token']);

      OAT.AJAX.POST (S, null, x);
    }
    else if (uriParams['oid-mode'] == 'linkedin') {
      rfTab.go(5);
      $('rf_is_agreed').checked = true;
      var x = function (data) {
        var xml = OAT.Xml.createXmlDoc(data);
        var user = xml.getElementsByTagName('person')[0];
        if (user && user.getElementsByTagName('id')[0]) {
          hiddenCreate('linkedin-data', null, data);
          var tbl = $('rf_table_5');
          rfRowInput(tbl, 'Login Name', 'rf_uid_5', {value: OAT.Xml.textValue(user.getElementsByTagName('first-name')[0]), width: '150px'});
          rfRowInput(tbl, 'E-Mail', 'rf_email_5', {width: '300px'});
          rfCheckUpdate(5);
        }
        else
        {
          alert('LinkedIn Authentication Failed');
        }
      }
      var S = "/ods/api/linkedinVerify"+
        '?sid=' + encodeURIComponent(uriParams['sid']) +
        '&oauth_verifier=' + encodeURIComponent(uriParams['oauth_verifier']) +
        '&oauth_token=' + encodeURIComponent(uriParams['oauth_token']);

      OAT.AJAX.POST (S, null, x);
    }
    else {
    rfTab.go(1);
    if (typeof (uriParams['openid.signed']) != 'undefined' && uriParams['openid.signed'] != '') {
      var x = function (params, param, data, property) {
          if (params[param] && params[param].length != 0 &&  params[param] != 'undefined')
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
          x(uriParams, 'openid.'+ns+'.value.fullname', data, 'name');
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
          rfRowInput(tbl, 'Login Name', 'rf_uid_1', {value: data['nick'], width: '150px'});
          rfRowInput(tbl, 'E-Mail', 'rf_email_1', {value: data['mbox'], width: '300px'});
          if (data['name'])
            rfRowValue(tbl, 'Full Name', data['name']);
          rfCheckUpdate(1);
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
  }

  if (regData.sslEnable) {
    var x = function(data) {
      try {
        rfSslData = OAT.JSON.parse(data);
      } catch (e) {
        rfSslData = null;
      }
      if (rfSslData && rfSslData.iri) {
        var prefix = 'rf';
        OAT.Dom.show(prefix+"_tab_3");
        var tbl = $(prefix+'_table_3');
        if (tbl) {
          OAT.Dom.unlink(prefix+'_table_3_throbber');
          if (rfSslData && !rfSslData.certFilterCheck) {
            rfRowText(tbl, 'Sign up for an ODS account using another WebID', 'font-weight: bold;');
            $('rf_signup').disabled = true;
          } else {
          rfRowValue(tbl, 'WebID', rfSslData.iri);
          if (rfSslData.depiction)
            rfRowImage(tbl, 'Photo', rfSslData.depiction);

          if (!rfSslData.certLogin)
            rfRowInput(tbl, 'Login Name', 'rf_uid_3', {value: rfSslData.loginName, width: '150px'});

          if (rfSslData.mbox && rfSslData.certLogin)
            rfRowValue(tbl, 'E-Mail', rfSslData.mbox);

          if (!rfSslData.certLogin)
            rfRowInput(tbl, 'E-Mail', 'rf_email_3', {value: rfSslData.mbox, width: '300px'});

          if (rfSslData.firstName)
            rfRowValue(tbl, 'First Name', rfSslData.firstName);

          if (rfSslData.family_name)
            rfRowValue(tbl, 'Family Name', rfSslData.family_name);

          if (rfSslData.certLogin) {
            var td = rfRowText(tbl, 'You have registered WebID and can sign in with it - ', 'font-weight: bold; ');
            rfRowButton(td, 'sign_in_1');
          }
          rfCheckUpdate(3);
          rfTab.go(3);
        }
      }
    }
    }
    if (document.location.protocol == 'https:') {
    OAT.AJAX.GET('/ods/api/user.getFOAFSSLData?sslFOAFCheck=1', '', x);
    } else {
      OAT.Dom.show('rf_tab_3');
      var tbl = $('rf_table_3');
      if (tbl) {
        OAT.Dom.unlink('rf_table_3_throbber');
        var td3 = rfRowText(tbl, 'Sign up for an ODS account using your existing WebID - ', 'font-weight: bold;');
        rfRowButton2(td3, 'sign_up_3');
      }
    }
  }
  if (document.location.protocol != 'https:') {
    var x = function (data) {
      var o = null;
      try {
        o = OAT.JSON.parse(data);
      } catch (e) { o = null; }
      if (o && o.sslPort)
      {
        var ref = 'https://' + document.location.hostname + ((o.sslPort != '443')? ':' + o.sslPort: '');

        var links = rfSslLinks['in'];
        for (var i = 0; i < links.length; i++)
          links[i].href = ref + '/ods/login.vspx';

        var links = rfSslLinks['up'];
        for (var i = 0; i < links.length; i++)
          links[i].href = ref + '/ods/register.vspx';
      }
    }
    OAT.AJAX.GET ('/ods/api/server.getInfo?info=sslPort', false, x);
  }
  if (regData.facebookEnable) {
    (function() {
      var e = document.createElement('script');
      e.src = document.location.protocol + '//connect.facebook.net/en_US/all.js';
      e.async = true;
      document.getElementById('fb-root').appendChild(e);
    }());
  }
}

function rfCallback(oldIndex, newIndex) {
  $('rf_signup').disabled = false;
  if (newIndex == 0)
    $('rf_signup').value = 'Sign Up';
  else if (newIndex == 1)
    $('rf_signup').value = 'OpenID Sign Up';
  else if (newIndex == 2)
    $('rf_signup').value = 'Facebook Sign Up';
  else if (newIndex == 3) {
    $('rf_signup').value = 'WebID Sign Up';
    if ((document.location.protocol == 'http:') || (rfSslData && rfSslData.certLogin))
      $('rf_signup').disabled = true;
  }
  else if (newIndex == 4)
    $('rf_signup').value = 'Twitter Sign Up';
  else if (newIndex == 5)
    $('rf_signup').value = 'LinkedIn Sign Up';

  rfCheckUpdate(newIndex, true);

  pageFocus('rf_page_'+newIndex);
}

function rfCheckUpdate(idx, mode) {
  if (!mode && (rfTab.selectedIndex != idx))
    return;

  $('rf_check').disabled = true;
  if ($('rf_uid_'+idx))
    $('rf_check').disabled = false;
}

function rfStart() {
  rfAjaxs++;
  $('rf_check').disabled = true;
  $('rf_signup').disabled = true;
	OAT.Dom.hide('rf_close');
	OAT.Dom.show('rf_throbber');
}

function rfEnd() {
  rfAjaxs--;
  if (rfAjaxs == 0) {
    OAT.Dom.hide('rf_throbber');
  	OAT.Dom.show('rf_close');
    $('rf_check').disabled = false;
    $('rf_signup').disabled = false;
  }
}

function rfSignupSubmit(event) {
  if (rfTab.selectedIndex == 0) {
    if ($v('rf_uid_0') == '')
      return showError('Bad username. Please correct!');
    if ($v('rf_email_0') == '')
      return showError('Bad mail. Please correct!');
    if ($v('rf_password') == '')
      return showError('Bad password. Please correct!');
    if ($v('rf_password') != $v('rf_password2'))
      return showError('Bad password. Please retype!');
  } else if (rfTab.selectedIndex == 1) {
    if ($v('rf_openId') == '')
      return showError('Bad openID. Please correct!');
  } else if (rfTab.selectedIndex == 2) {
    if (!facebookData || (!facebookData.id && !facebookData.link))
      return showError('Invalid Facebook User');
  } else if (rfTab.selectedIndex == 3) {
    if (!rfSslData || !rfSslData.iri)
      return showError('Invalid WebID UserID');
  }
  if (!$('rf_is_agreed').checked)
    return showError('You have not agreed to the Terms of Service!');

  var q = 'mode=' + encodeURIComponent(rfTab.selectedIndex);
  if (rfTab.selectedIndex == 0) {
    q +='&name=' + encodeURIComponent($v('rf_uid_0'))
      + '&email=' + encodeURIComponent($v('rf_email_0'))
      + '&password=' + encodeURIComponent($v('rf_password'));
  }
  else if (rfTab.selectedIndex == 1) {
    if (!$('oid-data')) {
      rfOpenIdAuthenticate('rf');
      return false;
    }
    q +='&data=' + encodeURIComponent($v('oid-data'))
      + '&name=' + encodeURIComponent($v('rf_uid_1'))
      + '&email=' + encodeURIComponent($v('rf_email_1'));
  }
  else if (rfTab.selectedIndex == 2) {
    q +='&data=' + encodeURIComponent(OAT.JSON.stringify(facebookData))
      + '&name=' + encodeURIComponent($v('rf_uid_2'))
      + '&email=' + encodeURIComponent($v('rf_email_2'));
  }
  else if (rfTab.selectedIndex == 3) {
    q +='&data=' + encodeURIComponent(OAT.JSON.stringify(rfSslData))
      + '&name=' + encodeURIComponent($v('rf_uid_3'))
      + '&email=' + encodeURIComponent($v('rf_email_3'));
  }
  else if (rfTab.selectedIndex == 4) {
    if (!$('twitter-data')) {
      twitterAuthenticate('rf');
      return false;
    }
    q +='&data=' + encodeURIComponent($v('twitter-data'))
      + '&name=' + encodeURIComponent($v('rf_uid_4'))
      + '&email=' + encodeURIComponent($v('rf_email_4'));
  }
  else if (rfTab.selectedIndex == 5) {
    if (!$('linkedin-data')) {
      linkedinAuthenticate('rf');
      return false;
    }
    q +='&data=' + encodeURIComponent($v('linkedin-data'))
      + '&name=' + encodeURIComponent($v('rf_uid_5'))
      + '&email=' + encodeURIComponent($v('rf_email_5'));
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

function rfCheckAvalability(event) {
  var name = $v('rf_uid_'+rfTab.selectedIndex);
  if (!name)
    return showError('Bad username. Please correct!');

  var email = $v('rf_email_'+rfTab.selectedIndex);
  if (!email)
    return showError('Bad Email. Please correct!');

  var x = function (data) {
    var xml = OAT.Xml.createXmlDoc(data);
    if (!hasError(xml))
      alert('Login name and Email are available!');
  }

  var q = '&name=' + encodeURIComponent(name) + '&email=' + encodeURIComponent(email);
  OAT.AJAX.POST("/ods/api/user.checkAvailability", q, x);
  return false;
}

function rfOpenIdAuthenticate(prefix) {
  var q = 'openIdUrl=' + encodeURIComponent($v(prefix+'_openId'));
  var x = function (data) {
    var xml = OAT.Xml.createXmlDoc(data);
    var error = OAT.Xml.xpath (xml, '//error_response', {});
    if (error.length)
      showError('Invalid OpenID Server');

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

    if (oidParams == 'sreg')
      S +='&openid.sreg.optional='+encodeURIComponent('fullname,nickname,dob,gender,postcode,country,timezone')
        + '&openid.sreg.required=' + encodeURIComponent('email,nickname');

    if (oidParams == 'ax')
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
  }
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
