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

var tab;
var setupWin;

function hiddenCreate(objName)
{
  var hidden = $('objName');
  if (!hidden)
  {
    hidden = document.createElement("input");
    hidden.setAttribute("type", "hidden");
    hidden.setAttribute("name", objName);
    hidden.setAttribute("id", objName);
    document.forms[0].appendChild(hidden);
  }
}

function tagValue(xml, tName)
{
  var str;
  try {
    str = OAT.Xml.textValue(xml.getElementsByTagName(tName)[0]);
    str = str.replace (/%2B/g, ' ');
  } catch (x) {
    str = '';
  }
  return str;
}

function fieldUpdate(xml, tName, fName)
{
  var obj = $(fName);
  var str = tagValue(xml, tName);
  if (obj.type == 'select-one')
  {
    var o = obj.options;
  	for (var i=0; i< o.length; i++)
  	{
  		if (o[i].value == str)
  		{
  		  o[i].selected = true;
  		  o[i].defaultSelected = true;
  		}
  	}
  } else {
    obj.value = str;
  }
}

function hiddenUpdate(xml, tName, fName)
{
  hiddenCreate(fName);
  fieldUpdate(xml, tName, fName);
}

function tagUpdate(xml, tName, fName)
{
  $(fName).innerHTML = tagValue(xml, tName);
}

function linkUpdate(xml, tName, fName)
{
  $(fName).href = tagValue(xml, tName);
}

function userUpdate(root)
{
 	var user = root.getElementsByTagName('user')[0];
  if (!user)
    return false;
  tagUpdate(user, 'name', 'uf_name');
  tagUpdate(user, 'mail', 'uf_mail');
  tagUpdate(user, 'title', 'uf_title');
  tagUpdate(user, 'firstName', 'uf_firstName');
  tagUpdate(user, 'lastName', 'uf_lastName');
  tagUpdate(user, 'fullName', 'uf_fullName');
  return true;
}

function updateList(fName, listName)
{
  var obj = $(fName);
  if (obj.options.length == 0)
  {
    var S = '/ods/api/lookup.list?key='+encodeURIComponent(listName);
    OAT.AJAX.GET(S, '', function(data){listCallback(data, obj);});
  }
}

function clearSelect(obj)
{
	for (var i=0;i<obj.options.length; i++)
	{
		obj.options[i] = null;
	}
  obj.value = '';
}

function listCallback (data, obj, objValue) {
  var xml = OAT.Xml.createXmlDoc(data);
	if (!hasError(xml))
{
    /* options */
  	var items = xml.getElementsByTagName("item");
  	if (items.length)
  	{
			obj.options[0] = new Option('', '');
  		for (var i=1; i<=items.length; i++) {
  		  o = new Option(OAT.Xml.textValue(items[i-1]), OAT.Xml.textValue(items[i-1]));
  			obj.options[i] = o;
  		}
  		if (objValue != null)
  		  obj.value = objValue;
  	}
	}
}

function copyList(sourceName, targetName)
{
  var targetObj = $(targetName);
  if (targetObj.options.length == 0)
  {
    var sourceObj = $(sourceName);
		for (var i=0;i<sourceObj.options.length; i++)
		{
			targetObj.options[i] = sourceObj.options[i];
		}
  }
}

function hasApiError(root)
{
	if (root)
	{
  	var error = root.getElementsByTagName('failed')[0];
    if (error)
    {
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

function afterLogin(data)
{
  var xml = OAT.Xml.createXmlDoc(data);
	if (!xml || !hasApiError(xml))
	{
    $('sid').value = data;
    $('realm').value = 'wa';
   	var T = $('form');
   	if (T)
   	{
   	  T.value = 'user';
   	  T.form.submit();
   	}
   	else
   	{
     	var T = $('ob_left');
     	if (T)
     	  T.innerHTML = '<a href="/ods/myhome.vspx?sid='+$('sid').value+'&realm='+$('realm').value+'">ODS Home</a> > View Profile';

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

function afterAuthenticate(xml)
{
	var root = xml.documentElement;
	if (!hasError(root))
	{
  	/* session */
   	var oid = root.getElementsByTagName('oid')[0];
    if (oid)
    {
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

function selectProfile()
{
  var S = '/ods/api/user.info?sid='+encodeURIComponent($v('sid'))+'&realm='+encodeURIComponent($v('realm'));
  OAT.AJAX.GET(S, '', selectProfileCallback);
}

function selectProfileCallback(data)
{
  var xml = OAT.Xml.createXmlDoc(data);
	if (!hasError(xml))
	{
  	/* user data */
   	var user = xml.getElementsByTagName('user')[0];
    if (user) {
      tagUpdate(user, 'name', 'uf_name');
      tagUpdate(user, 'mail', 'uf_mail');
      tagUpdate(user, 'title', 'uf_title');
      tagUpdate(user, 'firstName', 'uf_firstName');
      tagUpdate(user, 'lastName', 'uf_lastName');
      tagUpdate(user, 'fullName', 'uf_fullName');
    }
  }
}

function logoutSubmit()
{
  var S = '/ods/api/user.logout?sid='+encodeURIComponent($v('sid'))+'&realm='+encodeURIComponent($v('realm'));
  OAT.AJAX.GET(S, '', logoutCallback);
  return false;
}

function logoutCallback(obj)
{
  $('sid').value = '';
  $('realm').value = '';

  $('lf_uid').value = '';
  $('lf_password').value = '';

 	var T = $('ob_left');
 	if (T)
 	  T.innerHTML = '<a href="/ods/myhome.vspx?sid='+$('sid').value+'&realm='+$('realm').value+'">ODS Home</a> > Login';

  OAT.Dom.hide("ob_links");
  OAT.Dom.hide("ob_right");
  OAT.Dom.show("lf");
  OAT.Dom.hide("rf");
  OAT.Dom.hide("pf");
  OAT.Dom.hide("uf");
}

function logoutSubmit2()
{
  $('sid').value = '';
  $('realm').value = '';
  $('form').value = 'login';
  $('form').form.submit();
}

function lfLoginSubmit()
{
  $('sid').value = '';
  $('realm').value = '';

  if ($v('lf_openID') != '')
  {
    var opts = {
      'client_url': $v('lf_openID'),
      'client_action': 'login',
      'on_success': cbSuccess,
      'on_error': cbError,
      'on_debug': cbDebug,
      'on_need_permissions': cbNeedPermissions,
      'post_grant': "close",
      'helper_url': "http://" + location.host + "/ods/users/oid_login.vsp"
    };
    openID_verify(opts);
    }
  else
  {
    var S = '/ods/api/user.authenticate?user_name='+encodeURIComponent($v('lf_uid'))+'&password_hash='+encodeURIComponent(OAT.Crypto.sha($v('lf_uid')+$v('lf_password')));
    OAT.AJAX.GET(S, '', function(data){afterLogin(data);});
  }
  $('lf_password').value = '';
}

function lfLoginSubmit2()
{
  if ($v('lf_openID') != '')
  {
    var opts = {
      'client_url': $v('lf_openID'),
      'client_action': 'login',
      'on_success': cbSuccess,
      'on_error': cbError,
      'on_debug': cbDebug,
      'on_need_permissions': cbNeedPermissions,
      'post_grant': "close",
      'helper_url': "http://" + location.host + "/ods/users/oid_login.vsp"
    };
    openID_verify(opts);
    return false;
  }
}

function rfAlternateLogin (obj)
{
  if (obj.checked)
  {
    OAT.Dom.hide ('rf_login_1');
    OAT.Dom.hide ('rf_login_2');
    OAT.Dom.hide ('rf_login_3');
    OAT.Dom.hide ('rf_login_4');
    OAT.Dom.hide ('rf_login_5');
  } else {
    OAT.Dom.show ('rf_login_1');
    OAT.Dom.show ('rf_login_2');
    OAT.Dom.show ('rf_login_3');
    OAT.Dom.show ('rf_login_4');
    OAT.Dom.show ('rf_login_5');
  }
}

function rfAuthenticateSubmit()
{
  if ($('rf_useOpenID').checked)
  {
    if (!$('rf_is_agreed').checked)
    {
      alert ('You have not agreed to the Terms of Service!');
      return;
    }
    var opts = {
      'client_url': $v('rf_openID'),
      'client_action': 'register',
      'on_success': cbSuccess2,
      'on_error': cbError,
      'on_debug': cbDebug,
      'on_need_permissions': cbNeedPermissions,
      'post_grant': "close"
    };
  } else {
    var opts = {
      'client_url': $v('rf_openID'),
      'client_action': 'authenticate',
      'on_success': cbSuccess3,
      'on_error': cbError,
      'on_debug': cbDebug,
      'on_need_permissions': cbNeedPermissions,
      'post_grant': "close"
    };
  }
  opts.helper_url = "http://" + location.host + "/ods/users/oid_login.vsp";
  openID_verify(opts);
}

function inputParameter (inputField)
{
  var T = $(inputField);
  if (T)
    return T.value;
  return '';
}

function ufProfileSubmit()
{
  updateList('pf_homecountry', 'Country');
  updateList('pf_businesscountry', 'Country');
  updateList('pf_businessIndustry', 'Industry');

 	var T = $('pf_change_txt');
 	if (T)
 	  T.innerHTML = '';

  var S = '/ods/api/user.info?sid='+encodeURIComponent($v('sid'))+'&realm='+encodeURIComponent($v('realm'))+'&short=0';
  OAT.AJAX.GET(S, '', ufProfileCallback);
}

function ufProfileCallback(data)
{
  var xml = OAT.Xml.createXmlDoc(data);
	if (!hasError(xml))
	{
  	/* user data */
   	var user = xml.getElementsByTagName('user')[0];
    if (user)
    {
      // personal
      fieldUpdate(user, 'mail',                   'pf_mail');
      fieldUpdate(user, 'title',                  'pf_title');
      fieldUpdate(user, 'firstName',              'pf_firstName');
      fieldUpdate(user, 'lastName',               'pf_lastName');
      fieldUpdate(user, 'fullName',               'pf_fullName');
      fieldUpdate(user, 'gender',                 'pf_gender');
      fieldUpdate(user, 'birthday',               'pf_birthday');

      // contact
      fieldUpdate(user, 'icq',                    'pf_icq');
      fieldUpdate(user, 'skype',                  'pf_skype');
      fieldUpdate(user, 'yahoo',                  'pf_yahoo');
      fieldUpdate(user, 'aim',                    'pf_aim');
      fieldUpdate(user, 'msn',                    'pf_msn');

      // home
      fieldUpdate(user, 'homeCountry',            'pf_homecountry');
      updateState('pf_homecountry',               'pf_homestate', tagValue(user, 'homeState'));
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
      updateState('pf_businesscountry',           'pf_businessstate', tagValue(user, 'businessState'));
      fieldUpdate(user, 'businessCity',           'pf_businesscity');
      fieldUpdate(user, 'businessCode',           'pf_businesscode');
      fieldUpdate(user, 'businessAddress1',       'pf_businessaddress1');
      fieldUpdate(user, 'businessAddress2',       'pf_businessaddress2');
      fieldUpdate(user, 'businessTimezone',       'pf_businessTimezone');
      fieldUpdate(user, 'businessLatitude',       'pf_businesslat');
      fieldUpdate(user, 'businessLongitude',      'pf_businesslng');
      fieldUpdate(user, 'defaultMapLocation',     'pf_businessDefaultMapLocation');
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
      fieldUpdate(user, 'securitySecretQuestion', 'pf_securitySecretQuestion');
      fieldUpdate(user, 'securitySecretAnswer',   'pf_securitySecretAnswer');
      fieldUpdate(user, 'securitySiocLimit',      'pf_securitySiocLimit');

     	var T = $('ob_left');
     	if (T)
     	  T.innerHTML = '<a href="/ods/myhome.vspx?sid='+$('sid').value+'&realm='+$('realm').value+'">ODS Home</a> > Edit Profile';

      OAT.Dom.hide("lf");
      OAT.Dom.hide("rf");
      OAT.Dom.hide("uf");
      OAT.Dom.show("pf");
      tab.go (0);
    }
  }
}

function pfUpdateSubmit(event)
{
  var S = '/ods/api/user.update.fields' +
          '?sid=' + encodeURIComponent($v('sid')) +
          '&realm=' + encodeURIComponent($v('realm')) +
          '&mail=' + encodeURIComponent($v('pf_mail')) +
          '&title=' + encodeURIComponent($v('pf_title')) +
          '&firstName=' + encodeURIComponent($v('pf_firstName')) +
          '&lastName=' + encodeURIComponent($v('pf_lastName')) +
          '&fullName=' + encodeURIComponent($v('pf_fullName')) +
          '&gender=' + encodeURIComponent($v('pf_gender')) +
          '&birthday=' + encodeURIComponent($v('pf_birthday')) +
          '&icq=' + encodeURIComponent($v('pf_icq')) +
          '&skype=' + encodeURIComponent($v('pf_skype')) +
          '&yahoo=' + encodeURIComponent($v('pf_yahoo')) +
          '&aim=' + encodeURIComponent($v('pf_aim')) +
          '&msn=' + encodeURIComponent($v('pf_msn')) +
          '&defaultMapLocation=' + encodeURIComponent($v('pf_homeDefaultMapLocation')) +
          '&homeCountry=' + encodeURIComponent($v('pf_homecountry')) +
          '&homeState=' + encodeURIComponent($v('pf_homestate')) +
          '&homeCity=' + encodeURIComponent($v('pf_homecity')) +
          '&homeCode=' + encodeURIComponent($v('pf_homecode')) +
          '&homeAddress1=' + encodeURIComponent($v('pf_homeaddress1')) +
          '&homeAddress2=' + encodeURIComponent($v('pf_homeaddress2')) +
          '&homeTimezone=' + encodeURIComponent($v('pf_homeTimezone')) +
          '&homeLatitude=' + encodeURIComponent($v('pf_homelat')) +
          '&homeLongitude=' + encodeURIComponent($v('pf_homelng')) +
          '&homePhone=' + encodeURIComponent($v('pf_homePhone')) +
          '&homeMobile=' + encodeURIComponent($v('pf_homeMobile')) +
          '&businessIndustry=' + encodeURIComponent($v('pf_businessIndustry')) +
          '&businessOrganization=' + encodeURIComponent($v('pf_businessOrganization')) +
          '&businessHomePage=' + encodeURIComponent($v('pf_businessHomePage')) +
          '&businessJob=' + encodeURIComponent($v('pf_businessJob')) +
          '&businessCountry=' + encodeURIComponent($v('pf_businesscountry')) +
          '&businessState=' + encodeURIComponent($v('pf_businessstate')) +
          '&businessCity=' + encodeURIComponent($v('pf_businesscity')) +
          '&businessCode=' + encodeURIComponent($v('pf_businesscode')) +
          '&businessAddress1=' + encodeURIComponent($v('pf_businessaddress1')) +
          '&businessAddress2=' + encodeURIComponent($v('pf_businessaddress2')) +
          '&businessTimezone=' + encodeURIComponent($v('pf_businessTimezone')) +
          '&businessLatitude=' + encodeURIComponent($v('pf_businesslat')) +
          '&businessLongitude=' + encodeURIComponent($v('pf_businesslng')) +
          '&businessPhone=' + encodeURIComponent($v('pf_businessPhone')) +
          '&businessMobile=' + encodeURIComponent($v('pf_businessMobile')) +
          '&businessRegNo=' + encodeURIComponent($v('pf_businessRegNo')) +
          '&businessCareer=' + encodeURIComponent($v('pf_businessCareer')) +
          '&businessEmployees=' + encodeURIComponent($v('pf_businessEmployees')) +
          '&businessVendor=' + encodeURIComponent($v('pf_businessVendor')) +
          '&businessService=' + encodeURIComponent($v('pf_businessService')) +
          '&businessOther=' + encodeURIComponent($v('pf_businessOther')) +
          '&businessNetwork=' + encodeURIComponent($v('pf_businessNetwork')) +
          '&businessResume=' + encodeURIComponent($v('pf_businessResume')) +
          '&securitySecretQuestion=' + encodeURIComponent($v('pf_securitySecretQuestion')) +
          '&securitySecretAnswer=' + encodeURIComponent($v('pf_securitySecretAnswer')) +
          '&securitySiocLimit=' + encodeURIComponent($v('pf_securitySiocLimit'));
  OAT.AJAX.GET(S, '', pfUpdateCallback);

  $('pf_oldPassword').value = '';
  $('pf_newPassword').value = '';
  $('pf_newPassword2').value = '';
  return false;
}

function pfUpdateCallback(data)
{
  var xml = OAT.Xml.createXmlDoc(data);
	if (!hasError(xml))
	{
    OAT.Dom.hide("lf");
    OAT.Dom.hide("rf");
    OAT.Dom.show("uf");
    OAT.Dom.hide("pf");
    selectProfile();
  }
}

function pfChangeSubmit(event)
{
  if ($v('pf_newPassword') != $v('pf_newPassword2'))
  {
    alert ('Bad new password. Please retype!');
  } else {
    var S = '/ods/api/user.password_change'+
            '?sid='+encodeURIComponent($v('sid'))+
            '&realm='+encodeURIComponent($v('realm'))+
            '&new_password='+encodeURIComponent($v('pf_newPassword'));
    OAT.AJAX.GET(S, '', pfChangeCallback);
  }
  $('pf_oldPassword').value = '';
  $('pf_newPassword').value = '';
  $('pf_newPassword2').value = '';
  return false;
}

function pfChangeCallback(data)
{
  var xml = OAT.Xml.createXmlDoc(data);
	if (!hasError(xml))
	{
   	var T = $('pf_change_txt');
   	if (T)
   	  T.innerHTML = 'The password was changed successfully.';
	}
}

function pfCancelSubmit()
{
 	var T = $('ob_left');
 	if (T)
 	  T.innerHTML = '<a href="/ods/myhome.vspx?sid='+$('sid').value+'&realm='+$('realm').value+'">ODS Home</a> > View Profile';

  OAT.Dom.hide("lf");
  OAT.Dom.hide("rf");
  OAT.Dom.show("uf");
  OAT.Dom.hide("pf");
}

function setDefaultMapLocation (from, to)
{
  $('pf_' + to + 'DefaultMapLocation').checked = $('pf_' + from + 'DefaultMapLocation').checked;
}

function setSecretQuestion ()
{
  var S = $("pf_secretQuestion_select");
  var V = S[S.selectedIndex].value;

  $("pf_secretQuestion").value = V;
}
