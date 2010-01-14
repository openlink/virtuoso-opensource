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

// publics
var lfTab;
var ufTab;
var pfTab;
var setupWin;
var cRDF;

var sslData;
var facebookData;

// init
function myInit() {
	// CalendarPopup
	OAT.Preferences.imagePath = "/ods/images/oat/";
	OAT.Preferences.stylePath = "/ods/oat/styles/";
	OAT.Preferences.showAjax = false;

	if ($("lf")) {
    var uriParams = OAT.Dom.uriParams();

    if (typeof (uriParams['openid.signed']) != 'undefined' && uriParams['openid.signed'] != '')
    {
      openIdServer       = uriParams['oid-srv'];
      openIdSig          = uriParams['openid.sig'];
      openIdIdentity     = uriParams['openid.identity'];
      openIdAssoc_handle = uriParams['openid.assoc_handle'];
      openIdSigned       = uriParams['openid.signed'];

      var url = openIdServer +
        '?openid.mode=check_authentication' +
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
            url = url + '&openid.' + _key + '=' + encodeURIComponent (_val);
        }
      }
      var q = '&openIdUrl=' + encodeURIComponent (url) + '&openIdIdentity=' + encodeURIComponent (openIdIdentity);
      OAT.AJAX.POST ("/ods/api/user.authenticate", q, afterLogin);
    }
    else if (typeof (uriParams['openid.mode']) != 'undefined' && uriParams['openid.mode'] == 'cancel')
  {
      alert('OpenID Authentication Failed');
    }
		if (document.location.protocol == 'https:') {
			var x = function(data) {
				var o = null;
				try {
					o = OAT.JSON.parse(data);
				} catch (e) {
					o = null;
				}
				if (o && o.iri) {
					OAT.Dom.show("lf_tab_3");
					var tbl = $('lf_table_3');
					addProfileRowValue(tbl, 'IRI', o.iri);
					if (o.firstName)
						addProfileRowValue(tbl, 'First Name', o.firstName);
					if (o.family_name)
						addProfileRowValue(tbl, 'Family Name', o.family_name);
					if (o.mbox)
						addProfileRowValue(tbl, 'E-Mail', o.mbox);
				}
			}
			OAT.AJAX.GET('/ods/api/user.getFOAFSSLData?sslFOAFCheck=1', '', x);
		}
		loadFacebookData(function() {
			if (facebookData)
				FB.init(facebookData.api_key, "/ods/fb_dummy.vsp", {
					ifUserConnected : function() {
						showFacebookData();
					},
					ifUserNotConnected : function() {
						hideFacebookData();
					}
				});
		});

		lfTab = new OAT.Tab("lf_content");
		lfTab.add("lf_tab_0", "lf_page_0");
		lfTab.add("lf_tab_1", "lf_page_1");
		lfTab.add("lf_tab_2", "lf_page_2");
		lfTab.add("lf_tab_3", "lf_page_3");
		lfTab.go(0);
	}
	if ($("uf")) {
		ufTab = new OAT.Tab("uf_content");
		ufTab.add("uf_tab_0", "uf_page_0");
		ufTab.add("uf_tab_1", "uf_page_1");
		ufTab.add("uf_tab_2", "uf_page_2");
		ufTab.add("uf_tab_3", "uf_page_3");
		ufTab.add("uf_tab_4", "uf_page_4");
		ufTab.go(0);
		if ($("uf_rdf_content"))
			cRDF = new OAT.RDFMini($("uf_rdf_content"), {
				showSearch : false
			});
	}
	if ($('pf')) {
		pfTab = new OAT.Tab("content");
		pfTab.add("tab_0", "page_0");
		pfTab.add("tab_1", "page_1");
		pfTab.add("tab_2", "page_2");
		pfTab.add("tab_3", "page_3");
		pfTab.add("tab_4", "page_4");
		pfTab.go(0);
  }
}

function loadFacebookData(cb) {
	var x = function(data) {
		try {
			facebookData = OAT.JSON.parse(data);
		} catch (e) {
			facebookData = null;
		}
		if (facebookData)
			OAT.Dom.show("lf_tab_2");
		if (cb) {
			cb();
		}
	}
	OAT.AJAX.GET('/ods/api/user.getFacebookData', '', x);
}

function showFacebookData(skip) {
	var label = $('lf_facebookData');
	if (!label) {
		return;
	}
	label.innerHTML = '';
	if (facebookData && facebookData.name)
		label.innerHTML = 'Connect as <b><i>' + facebookData.name + '</i></b></b>';
	else if (!skip)
		self.loadFacebookData(function() {
			self.showFacebookData(true);
		});
}

function hideFacebookData() {
	var label = $('lf_facebookData');
	if (!label) {
		return;
	}
	label.innerHTML = '';

	if (!facebookData) {
		return;
	}
	var o = {}
	o.api_key = facebookData.api_key;
	o.secret = facebookData.secret;
	facebookData = o;
}

function hiddenCreate(objName, objForm, objValue) {
	var obj = $('objName');
	if (!obj) {
		obj = OAT.Dom.create("input");
		obj.setAttribute("type", "hidden");
		obj.setAttribute("name", objName);
		obj.setAttribute("id", objName);
		if (!objForm)
			objForm = document.forms[0];
		objForm.appendChild(obj);
	}
	if (objValue)
		obj.setAttribute("value", objValue);
	return obj;
}

function tagValue(xml, tName) {
  var str;
  try {
    str = OAT.Xml.textValue(xml.getElementsByTagName(tName)[0]);
    str = str.replace (/%2B/g, ' ');
  } catch (x) {
    str = '';
  }
  return str;
}

function fieldUpdate(xml, tName, fName) {
  var obj = $(fName);
  var str = tagValue(xml, tName);
	if (obj.type == 'select-one') {
    var o = obj.options;
		for ( var i = 0; i < o.length; i++) {
			if (o[i].value == str) {
  		  o[i].selected = true;
  		  o[i].defaultSelected = true;
  		}
  	}
  } else {
    obj.value = str;
  }
}

function hiddenUpdate(xml, tName, fName) {
  hiddenCreate(fName);
  fieldUpdate(xml, tName, fName);
}

function tagUpdate(xml, tName, fName) {
  $(fName).innerHTML = tagValue(xml, tName);
}

function linkUpdate(xml, tName, fName) {
  $(fName).href = tagValue(xml, tName);
}

function updateList(fName, listName) {
  var obj = $(fName);
	if (obj.options.length == 0) {
    var S = '/ods/api/lookup.list?key='+encodeURIComponent(listName);
		OAT.AJAX.GET(S, '', function(data) {
			listCallback(data, obj);
		});
  }
}

function clearSelect(obj) {
	for ( var i = 0; i < obj.options.length; i++) {
		obj.options[i] = null;
	}
  obj.value = '';
}

function listCallback (data, obj, objValue) {
  var xml = OAT.Xml.createXmlDoc(data);
	if (!hasError(xml)) {
    /* options */
  	var items = xml.getElementsByTagName("item");
		if (items.length) {
			obj.options[0] = new Option('', '');
  		for (var i=1; i<=items.length; i++) {
				o = new Option(OAT.Xml.textValue(items[i - 1]), OAT.Xml
						.textValue(items[i - 1]));
  			obj.options[i] = o;
  		}
  		if (objValue != null)
  		  obj.value = objValue;
  	}
	}
}

function copyList(sourceName, targetName) {
  var targetObj = $(targetName);
	if (targetObj.options.length == 0) {
    var sourceObj = $(sourceName);
		for ( var i = 0; i < sourceObj.options.length; i++) {
			targetObj.options[i] = sourceObj.options[i];
		}
  }
}

function hasApiError(root) {
	if (root) {
  	var error = root.getElementsByTagName('failed')[0];
		if (error) {
      error = error[0];
	  var code = error.getElementsByTagName('code')[0];
        $('sid').value = '';
        $('realm').value = '';
        OAT.Dom.hide("ob_links");
        OAT.Dom.show("lf");
        OAT.Dom.hide("rf");
        OAT.Dom.hide("uf");
        OAT.Dom.hide("pf");

	    var message = error.getElementsByTagName('message')[0];
        alert (OAT.Xml.textValue(message));
  		return true;
    }
  return false;
}
  return true;
    }

function afterLogin(data) {
  var xml = OAT.Xml.createXmlDoc(data);
	if (!xml || !hasApiError(xml)) {
    $('sid').value = data;
    $('realm').value = 'wa';
   	var T = $('form');
		if (T) {
   	  T.value = 'user';
   	  T.form.submit();
		} else {
     	var T = $('ob_left');
     	if (T)
				T.innerHTML = '<a href="/ods/myhome.vspx?sid=' + $('sid').value
						+ '&realm=' + $('realm').value
						+ '">ODS Home</a> > View Profile';

      OAT.Dom.show("ob_right");
      OAT.Dom.hide("ob_links");
      OAT.Dom.hide("lf");
      OAT.Dom.hide("rf");
      OAT.Dom.show("uf");
      OAT.Dom.hide("pf");
        selectProfile();
    }
  }
  return false;
}

function afterAuthenticate(xml) {
	var root = xml.documentElement;
	if (!hasError(root)) {
  	/* session */
   	var oid = root.getElementsByTagName('oid')[0];
		if (oid) {
      fieldUpdate(oid, 'uid', 'rf_uid');
      fieldUpdate(oid, 'mail', 'rf_mail');
      hiddenUpdate(oid, 'identity', 'rf_identity');
      hiddenUpdate(oid, 'fullname', 'rf_fullname');
      hiddenUpdate(oid, 'birthday', 'rf_birthday');
      hiddenUpdate(oid, 'gender', 'rf_gender');
      hiddenUpdate(oid, 'postcode', 'rf_postcode');
      hiddenUpdate(oid, 'postcode', 'rf_postcode');
      hiddenUpdate(oid, 'country', 'rf_country');
      hiddenUpdate(oid, 'tz', 'rf_tz');
    }
  }
  return false;
}

function selectProfile() {
	var S = '/ods/api/user.info?sid=' + encodeURIComponent($v('sid'))
			+ '&realm=' + encodeURIComponent($v('realm')) + '&short=0';
  OAT.AJAX.GET(S, '', selectProfileCallback);
}

function selectProfileCallback(data) {
  var xml = OAT.Xml.createXmlDoc(data);
	if (!hasError(xml)) {
  	/* user data */
   	var user = xml.getElementsByTagName('user')[0];
		if (user) {
      var tbl = $('uf_table_0');
			if (tbl) {
        tbl.innerHTML = '';
        addProfileRow(tbl, user, 'name',      'Login Name');
        addProfileRow(tbl, user, 'mail',      'Title');
        addProfileRow(tbl, user, 'title',     'First Name');
        addProfileRow(tbl, user, 'firstName', 'Last Name');
        addProfileRow(tbl, user, 'lastName',  'Full Name');
        addProfileRow(tbl, user, 'fullName',  'E-mail');
        addProfileRow(tbl, user, 'gender',    'Gender');
        addProfileRow(tbl, user, 'birthday',  'Birthday');
        addProfileRow(tbl, user, 'homepage',  'Personal Webpage');
				addProfileTableValues(tbl, 'Personal URIs (Web IDs)', tagValue(
						user, 'webIDs'), [ 'URL' ], [ '\n' ])
				addProfileTableValues(tbl, 'Topic of Interests', tagValue(user,
						'interests'), [ 'URL', 'Label' ], [ '\n', ';' ])
				addProfileTableValues(tbl, 'Thing of Interests', tagValue(user,
						'topicInterests'), [ 'URL', 'Label' ], [ '\n', ';' ])
      }

      var tbl = $('uf_table_1');
			if (tbl) {
        tbl.innerHTML = '';
        addProfileRow(tbl, user, 'icq',   'ICQ Number');
        addProfileRow(tbl, user, 'skype', 'Skype ID');
        addProfileRow(tbl, user, 'aim',   'AIM Name');
        addProfileRow(tbl, user, 'yahoo', 'Yahoo! ID');
        addProfileRow(tbl, user, 'msn',   'MSN Messenger');
				addProfileTableRowValue(tbl, tagValue(user, 'messaging'), [
						'\n', ';' ], 'th')
      }
      var tbl = $('uf_table_2');
			if (tbl) {
        tbl.innerHTML = '';
        addProfileRow(tbl, user, 'homeCountry',  'Country');
        addProfileRow(tbl, user, 'homeState',    'State/Province');
        addProfileRow(tbl, user, 'homeCity',     'City/Town');
        addProfileRow(tbl, user, 'homeCode',     'Zip/PostalCode');
        addProfileRow(tbl, user, 'homeAddress1', 'Address1');
        addProfileRow(tbl, user, 'homeAddress2', 'Address2');
        addProfileRow(tbl, user, 'homeTimezone', 'Timezone');
        addProfileRow(tbl, user, 'homeLatitude', 'Latitude');
        addProfileRow(tbl, user, 'homeLongitude','Longitude');
        addProfileRow(tbl, user, 'homePhone',    'Phone');
        addProfileRow(tbl, user, 'homeMobile',   'Mobile');
      }
      var tbl = $('uf_table_3');
			if (tbl) {
        tbl.innerHTML = '';
        addProfileRow(tbl, user, 'businessIndustry',    'Industry');
        addProfileRow(tbl, user, 'businessOrganization','Organization');
        addProfileRow(tbl, user, 'businessJob',         'Job');
        addProfileRow(tbl, user, 'businessCountry',     'Country');
        addProfileRow(tbl, user, 'businessState',       'State/Province');
        addProfileRow(tbl, user, 'businessCity',        'City/Town');
        addProfileRow(tbl, user, 'businessCode',        'Zip/PostalCode');
        addProfileRow(tbl, user, 'businessAddress1',    'Address1');
        addProfileRow(tbl, user, 'businessAddress2',    'Address2');
        addProfileRow(tbl, user, 'businessTimezone',    'Timezone');
        addProfileRow(tbl, user, 'businessLatitude',    'Latitude');
        addProfileRow(tbl, user, 'businessLongitude',   'Longitude');
        addProfileRow(tbl, user, 'businessPhone',       'Phone');
        addProfileRow(tbl, user, 'businessMobile',      'Mobile');
      }
      if (cRDF)
        cRDF.open(tagValue(user, 'iri'));
    }
  }
}

function addProfileRow(tbl, xml, tagLabel, label) {
  var value = tagValue(xml, tagLabel);
  if (value)
    addProfileRowValue(tbl, label, value);
}

function addProfileRowValue(tbl, label, value, leftTag) {
	if (!leftTag) {
		leftTag = 'th';
	}
  var tr = OAT.Dom.create('tr');
  var th = OAT.Dom.create(leftTag);
  th.width = '30%';
  th.innerHTML = label;
  tr.appendChild(th);
	if (value) {
    var td = OAT.Dom.create('td');
    td.innerHTML = value;
    tr.appendChild(td);
  }
  tbl.appendChild(tr);
}

function addProfileTableValues(tbl, label, values, headers, delimiters) {
	if (values) {
    var tr = OAT.Dom.create('tr');
    var th = OAT.Dom.create('th');
    th.vAlign = 'top';
    th.width = '30%';
    th.innerHTML = label;
    tr.appendChild(th);

    var td = OAT.Dom.create('td');
    tr.appendChild(td);

    tbl.appendChild(tr);

    var newTbl = OAT.Dom.create('table');
    newTbl.className = 'listing';
    td.appendChild(newTbl);
		if (headers) {
      var tr = OAT.Dom.create('tr');
      tr.className = 'listing_header_row';
			for ( var N = 0; N < headers.length; N++) {
        var th = OAT.Dom.create('th');
        th.innerHTML = headers[N];
        tr.appendChild(th);
      }
      newTbl.appendChild(tr);
    }
    addProfileTableRowValue(newTbl, values, delimiters)
  }
}

function addProfileTableRowValue(tbl, values, delimiters, leftTag) {
	if (!leftTag) {
		leftTag = 'td';
	}
  var tmpLines = values.split(delimiters[0]);
	for ( var N = 0; N < tmpLines.length; N++) {
		if (delimiters.length == 1) {
      addProfileRowValue(tbl, tmpLines[N], null, leftTag);
		} else {
      var items = tmpLines[N].split(delimiters[1]);
      addProfileRowValue(tbl, items[0], items[1], leftTag);
    }
  }
}

function logoutSubmit() {
	var T = $('form');
	if (T) {
		$('sid').value = '';
		$('realm').value = '';
		T.value = 'login';
		T.form.submit();
	} else {
		var S = '/ods/api/user.logout?sid=' + encodeURIComponent($v('sid'))
				+ '&realm=' + encodeURIComponent($v('realm'));
  OAT.AJAX.GET(S, '', logoutCallback);
	}
  return false;
}

function logoutCallback(obj) {
  $('sid').value = '';
  $('realm').value = '';

  $('lf_uid').value = '';
  $('lf_password').value = '';

 	var T = $('ob_left');
 	if (T)
		T.innerHTML = '<a href="/ods/myhome.vspx?sid=' + $('sid').value
				+ '&realm=' + $('realm').value + '">ODS Home</a> > Login';

  OAT.Dom.hide("ob_links");
  OAT.Dom.hide("ob_right");
  OAT.Dom.show("lf");
  OAT.Dom.hide("rf");
  OAT.Dom.hide("pf");
  OAT.Dom.hide("uf");
}

function lfLoginSubmit() {
	function showError(msg) {
		alert(msg);
		return false;
}
	var q = '';
	if (lfTab.selectedIndex == 1) {
		if ($('lf_openId').value.length == 0)
			return showError('Invalid OpenID URL');

    q += '&openIdUrl=' + encodeURIComponent($v('lf_openId'));
    var x = function (data) {
      var xml = OAT.Xml.createXmlDoc(data);
      var error = OAT.Xml.xpath (xml, '//error_response', {});
      if (error.length)
	      showError('Invalied OpenID Server');

      openIdServer = OAT.Xml.textValue (OAT.Xml.xpath (xml, '/openIdServer_response/server', {})[0]);
      openIdDelegate = OAT.Xml.textValue (OAT.Xml.xpath (xml, '/openIdServer_response/delegate', {})[0]);

      if (!openIdServer || openIdServer.length == 0)
        showError(' Cannot locate OpenID server');

      var oidIdent = $v('lf_openId');
      if (openIdDelegate || openIdDelegate.length > 0)
        oidIdent = openIdDelegate;

      var thisPage  = document.location.protocol +
        '//' +
        document.location.host +
        document.location.pathname +
        '?oid-srv=' +
        encodeURIComponent (openIdServer);

      var trustRoot = document.location.protocol +
        '//' +
        document.location.host;

      document.location = openIdServer +
        '?openid.mode=checkid_setup' +
        '&openid.identity=' + encodeURIComponent (oidIdent) +
        '&openid.return_to=' + encodeURIComponent (thisPage) +
        '&openid.trust_root=' + encodeURIComponent (trustRoot);
    };
    OAT.AJAX.POST ("/ods_services/Http/openIdServer", q, x);
    return false;
	} else if (lfTab.selectedIndex == 2) {
		if (!facebookData || !facebookData.uid)
			return showError('Invalid Facebook UserID');

		q += '&facebookUID=' + facebookData.uid;
	} else if (lfTab.selectedIndex == 3) {
  } else {
		if (($('lf_uid').value.length == 0) || ($('lf_password').value.length == 0))
			return showError('Invalid Member ID or Password');

		q += 'user_name='
				+ encodeURIComponent($v('lf_uid'))
				+ '&password_hash='
				+ encodeURIComponent(OAT.Crypto.sha($v('lf_uid')
						+ $v('lf_password')));
    }
	OAT.AJAX.POST("/ods/api/user.authenticate", q, afterLogin);
	return false;
}

function inputParameter(inputField) {
  var T = $(inputField);
  if (T)
    return T.value;
  return '';
}

function ufProfileSubmit() {
  updateList('pf_homecountry', 'Country');
  updateList('pf_businesscountry', 'Country');
  updateList('pf_businessIndustry', 'Industry');

 	var T = $('pf_change_txt');
 	if (T)
 	  T.innerHTML = '';

	var S = '/ods/api/user.info?sid=' + encodeURIComponent($v('sid'))
			+ '&realm=' + encodeURIComponent($v('realm')) + '&short=0';
  OAT.AJAX.GET(S, '', ufProfileCallback);
}

function ufProfileCallback(data) {
  var xml = OAT.Xml.createXmlDoc(data);
	if (!hasError(xml)) {
  	/* user data */
   	var user = xml.getElementsByTagName('user')[0];
		if (user) {
      // personal
      fieldUpdate(user, 'mail',                   'pf_mail');
      fieldUpdate(user, 'title',                  'pf_title');
      fieldUpdate(user, 'firstName',              'pf_firstName');
      fieldUpdate(user, 'lastName',               'pf_lastName');
      fieldUpdate(user, 'fullName',               'pf_fullName');
      fieldUpdate(user, 'gender',                 'pf_gender');
      fieldUpdate(user, 'birthday',               'pf_birthday');
      fieldUpdate(user, 'homepage',               'pf_homepage');

      // contact
      fieldUpdate(user, 'icq',                    'pf_icq');
      fieldUpdate(user, 'skype',                  'pf_skype');
      fieldUpdate(user, 'yahoo',                  'pf_yahoo');
      fieldUpdate(user, 'aim',                    'pf_aim');
      fieldUpdate(user, 'msn',                    'pf_msn');

      // home
      fieldUpdate(user, 'homeCountry',            'pf_homecountry');
			updateState('pf_homecountry', 'pf_homestate', tagValue(user,
					'homeState'));
      fieldUpdate(user, 'homeCity',               'pf_homecity');
      fieldUpdate(user, 'homeCode',               'pf_homecode');
      fieldUpdate(user, 'homeAddress1',           'pf_homeaddress1');
      fieldUpdate(user, 'homeAddress2',           'pf_homeaddress2');
      fieldUpdate(user, 'homeTimezone',           'pf_homeTimezone');
      fieldUpdate(user, 'homeLatitude',           'pf_homelat');
      fieldUpdate(user, 'homeLongitude',          'pf_homelng');
      fieldUpdate(user, 'defaultMapLocation',     'pf_homeDefaultMapLocation');
      fieldUpdate(user, 'homePhone',              'pf_homePhone');
      fieldUpdate(user, 'homeMobile',             'pf_homeMobile');

      // business
      fieldUpdate(user, 'businessIndustry',       'pf_businessIndustry');
      fieldUpdate(user, 'businessOrganization',   'pf_businessOrganization');
      fieldUpdate(user, 'businessHomePage',       'pf_businessHomePage');
      fieldUpdate(user, 'businessJob',            'pf_businessJob');
      fieldUpdate(user, 'businessCountry',        'pf_businesscountry');
			updateState('pf_businesscountry', 'pf_businessstate', tagValue(
					user, 'businessState'));
      fieldUpdate(user, 'businessCity',           'pf_businesscity');
      fieldUpdate(user, 'businessCode',           'pf_businesscode');
      fieldUpdate(user, 'businessAddress1',       'pf_businessaddress1');
      fieldUpdate(user, 'businessAddress2',       'pf_businessaddress2');
      fieldUpdate(user, 'businessTimezone',       'pf_businessTimezone');
      fieldUpdate(user, 'businessLatitude',       'pf_businesslat');
      fieldUpdate(user, 'businessLongitude',      'pf_businesslng');
			fieldUpdate(user, 'defaultMapLocation',
					'pf_businessDefaultMapLocation');
      fieldUpdate(user, 'businessPhone',          'pf_businessPhone');
      fieldUpdate(user, 'businessMobile',         'pf_businessMobile');
      fieldUpdate(user, 'businessRegNo',          'pf_businessRegNo');
      fieldUpdate(user, 'businessCareer',         'pf_businessCareer');
      fieldUpdate(user, 'businessEmployees',      'pf_businessEmployees');
      fieldUpdate(user, 'businessVendor',         'pf_businessVendor');
      fieldUpdate(user, 'businessService',        'pf_businessService');
      fieldUpdate(user, 'businessOther',          'pf_businessOther');
      fieldUpdate(user, 'businessNetwork',        'pf_businessNetwork');
      fieldUpdate(user, 'businessResume',         'pf_businessResume');

      // security
			fieldUpdate(user, 'securitySecretQuestion',
					'pf_securitySecretQuestion');
      fieldUpdate(user, 'securitySecretAnswer',   'pf_securitySecretAnswer');
      fieldUpdate(user, 'securitySiocLimit',      'pf_securitySiocLimit');

     	var T = $('ob_left');
     	if (T)
				T.innerHTML = '<a href="/ods/myhome.vspx?sid=' + $('sid').value
						+ '&realm=' + $('realm').value
						+ '">ODS Home</a> > Edit Profile';

      OAT.Dom.hide("lf");
      OAT.Dom.hide("rf");
      OAT.Dom.hide("uf");
      OAT.Dom.show("pf");
			pfTab.go(0);
    }
  }
}

function pfUpdateSubmit(event) {
	var S = '/ods/api/user.update.fields' + '?sid='
			+ encodeURIComponent($v('sid')) + '&realm='
			+ encodeURIComponent($v('realm')) + '&mail='
			+ encodeURIComponent($v('pf_mail')) + '&title='
			+ encodeURIComponent($v('pf_title')) + '&firstName='
			+ encodeURIComponent($v('pf_firstName')) + '&lastName='
			+ encodeURIComponent($v('pf_lastName')) + '&fullName='
			+ encodeURIComponent($v('pf_fullName')) + '&gender='
			+ encodeURIComponent($v('pf_gender')) + '&birthday='
			+ encodeURIComponent($v('pf_birthday')) + '&homepage='
			+ encodeURIComponent($v('pf_homepage')) + '&icq='
			+ encodeURIComponent($v('pf_icq')) + '&skype='
			+ encodeURIComponent($v('pf_skype')) + '&yahoo='
			+ encodeURIComponent($v('pf_yahoo')) + '&aim='
			+ encodeURIComponent($v('pf_aim')) + '&msn='
			+ encodeURIComponent($v('pf_msn')) + '&defaultMapLocation='
			+ encodeURIComponent($v('pf_homeDefaultMapLocation'))
			+ '&homeCountry=' + encodeURIComponent($v('pf_homecountry'))
			+ '&homeState=' + encodeURIComponent($v('pf_homestate'))
			+ '&homeCity=' + encodeURIComponent($v('pf_homecity'))
			+ '&homeCode=' + encodeURIComponent($v('pf_homecode'))
			+ '&homeAddress1=' + encodeURIComponent($v('pf_homeaddress1'))
			+ '&homeAddress2=' + encodeURIComponent($v('pf_homeaddress2'))
			+ '&homeTimezone=' + encodeURIComponent($v('pf_homeTimezone'))
			+ '&homeLatitude=' + encodeURIComponent($v('pf_homelat'))
			+ '&homeLongitude=' + encodeURIComponent($v('pf_homelng'))
			+ '&homePhone=' + encodeURIComponent($v('pf_homePhone'))
			+ '&homeMobile=' + encodeURIComponent($v('pf_homeMobile'))
			+ '&businessIndustry='
			+ encodeURIComponent($v('pf_businessIndustry'))
			+ '&businessOrganization='
			+ encodeURIComponent($v('pf_businessOrganization'))
			+ '&businessHomePage='
			+ encodeURIComponent($v('pf_businessHomePage')) + '&businessJob='
			+ encodeURIComponent($v('pf_businessJob')) + '&businessCountry='
			+ encodeURIComponent($v('pf_businesscountry')) + '&businessState='
			+ encodeURIComponent($v('pf_businessstate')) + '&businessCity='
			+ encodeURIComponent($v('pf_businesscity')) + '&businessCode='
			+ encodeURIComponent($v('pf_businesscode')) + '&businessAddress1='
			+ encodeURIComponent($v('pf_businessaddress1'))
			+ '&businessAddress2='
			+ encodeURIComponent($v('pf_businessaddress2'))
			+ '&businessTimezone='
			+ encodeURIComponent($v('pf_businessTimezone'))
			+ '&businessLatitude=' + encodeURIComponent($v('pf_businesslat'))
			+ '&businessLongitude=' + encodeURIComponent($v('pf_businesslng'))
			+ '&businessPhone=' + encodeURIComponent($v('pf_businessPhone'))
			+ '&businessMobile=' + encodeURIComponent($v('pf_businessMobile'))
			+ '&businessRegNo=' + encodeURIComponent($v('pf_businessRegNo'))
			+ '&businessCareer=' + encodeURIComponent($v('pf_businessCareer'))
			+ '&businessEmployees='
			+ encodeURIComponent($v('pf_businessEmployees'))
			+ '&businessVendor=' + encodeURIComponent($v('pf_businessVendor'))
			+ '&businessService='
			+ encodeURIComponent($v('pf_businessService')) + '&businessOther='
			+ encodeURIComponent($v('pf_businessOther')) + '&businessNetwork='
			+ encodeURIComponent($v('pf_businessNetwork')) + '&businessResume='
			+ encodeURIComponent($v('pf_businessResume'))
			+ '&securitySecretQuestion='
			+ encodeURIComponent($v('pf_securitySecretQuestion'))
			+ '&securitySecretAnswer='
			+ encodeURIComponent($v('pf_securitySecretAnswer'))
			+ '&securitySiocLimit='
			+ encodeURIComponent($v('pf_securitySiocLimit'));
  OAT.AJAX.GET(S, '', pfUpdateCallback);

  $('pf_oldPassword').value = '';
  $('pf_newPassword').value = '';
  $('pf_newPassword2').value = '';
  return false;
}

function pfUpdateCallback(data) {
  var xml = OAT.Xml.createXmlDoc(data);
	if (!hasError(xml)) {
    OAT.Dom.hide("lf");
    OAT.Dom.hide("rf");
    OAT.Dom.show("uf");
    OAT.Dom.hide("pf");
    selectProfile();
  }
}

function pfChangeSubmit(event) {
	if ($v('pf_newPassword') != $v('pf_newPassword2')) {
    alert ('Bad new password. Please retype!');
  } else {
		var S = '/ods/api/user.password_change' + '?sid='
				+ encodeURIComponent($v('sid')) + '&realm='
				+ encodeURIComponent($v('realm')) + '&new_password='
				+ encodeURIComponent($v('pf_newPassword'));
    OAT.AJAX.GET(S, '', pfChangeCallback);
  }
  $('pf_oldPassword').value = '';
  $('pf_newPassword').value = '';
  $('pf_newPassword2').value = '';
  return false;
}

function pfChangeCallback(data) {
  var xml = OAT.Xml.createXmlDoc(data);
	if (!hasError(xml)) {
   	var T = $('pf_change_txt');
   	if (T)
   	  T.innerHTML = 'The password was changed successfully.';
	}
}

function pfCancelSubmit() {
 	var T = $('ob_left');
 	if (T)
		T.innerHTML = '<a href="/ods/myhome.vspx?sid=' + $('sid').value
				+ '&realm=' + $('realm').value
				+ '">ODS Home</a> > View Profile';

  OAT.Dom.hide("lf");
  OAT.Dom.hide("rf");
  OAT.Dom.show("uf");
  OAT.Dom.hide("pf");
}

function setDefaultMapLocation(from, to) {
  $('pf_' + to + 'DefaultMapLocation').checked = $('pf_' + from + 'DefaultMapLocation').checked;
}

function setSecretQuestion() {
  var S = $("pf_secretQuestion_select");
  var V = S[S.selectedIndex].value;

  $("pf_secretQuestion").value = V;
}
