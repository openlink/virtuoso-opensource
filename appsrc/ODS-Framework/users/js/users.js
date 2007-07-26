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
var executingDiv;
var setupWin;

function init() {
  if ($('pf')) {
    tab = new OAT.Tab ("content");
    tab.add ("tab_0", "page_0");
    tab.add ("tab_1", "page_1");
    tab.add ("tab_2", "page_2");
    tab.add ("tab_3", "page_3");
    tab.add ("tab_4", "page_4");
    tab.go (0);
  }

	executingDiv = OAT.Dom.create("div",{border:"2px solid #000",padding:"1em",position:"absolute",backgroundColor:"#fff"});
	executingDiv.innerHTML = "Executing...";
	document.body.appendChild(executingDiv);
	OAT.Dom.hide(executingDiv);
}

function hiddenCreate(objName) {
  var hidden = $('objName');
  if (!hidden) {
    hidden = document.createElement("input");
    hidden.setAttribute("type", "hidden");
    hidden.setAttribute("name", objName);
    hidden.setAttribute("id", objName);
    document.forms[0].appendChild(hidden);
  }
}

function executingStart() {
	OAT.Dimmer.show(executingDiv);
	OAT.Dom.center(executingDiv,1,1);
}

function executingEnd() {
	OAT.Dimmer.hide();
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
  if (obj.type == 'select-one') {
    var o = obj.options;
  	for (var i=0; i< o.length; i++) {
  		if (o[i].value == str) {
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
  if (obj.options.length == 0) {
    var wsdl = "/ods_services/services.wsdl";
    var serviceName = "ODS_USER_LIST";

    var inputObject = {
    	ODS_USER_LIST:{
        pSid:$v('sid'),
        pRealm:$v('realm'),
        pList:listName
    	}
    }
		var x = function(xml) {
		  listCallback(xml, obj);
		}
  	OAT.WS.invoke(wsdl, serviceName, x, inputObject);
  }
}

function clearSelect(obj)
{
	for (var i=0;i<obj.options.length; i++) {
		obj.options[i] = null;
	}
  obj.value = '';
}

function updateState(countryName, stateName, stateValue)
{
  var obj = $(stateName);
  clearSelect(obj);

  if ($v(countryName) != '') {
    var wsdl = "/ods_services/services.wsdl";
    var serviceName = "ODS_USER_LIST";

    var inputObject = {
    	ODS_USER_LIST:{
        pSid:$v('sid'),
        pRealm:$v('realm'),
        pList:'Province',
        pParam:$v(countryName)
    	}
    }
  	var x = function(xml) {
  	  listCallback(xml, obj, stateValue);
  	}
  	OAT.WS.invoke(wsdl, serviceName, x, inputObject);
  }
}

function listCallback (result, obj, objValue) {
  var xml = OAT.Xml.createXmlDoc(result.ODS_USER_LISTResponse.CallReturn);
	var root = xml.documentElement;
	if (!hasError(root)) {
    /* options */
  	var items = root.getElementsByTagName("item");
  	if (items.length) {
			obj.options[0] = new Option('', '');
  		for (var i=1; i<=items.length; i++) {
  		  o = new Option(OAT.Xml.textValue(items[i-1]), OAT.Xml.textValue(items[i-1]));
  			obj.options[i] = o;
  		}
  		if (objValue != null)
  		  obj.value = objValue;
  	}
	}
  // executingEnd();
}

function copyList(sourceName, targerName)
{
  var targetObj = $(targerName);
  if (targetObj.options.length == 0) {
    var sourceObj = $(sourceName);
		for (var i=0;i<sourceObj.options.length; i++) {
			targetObj.options[i] = sourceObj.options[i];
		}
  }
}

function hasError(root) {
	if (!root) {
    // executingEnd();
		alert('No data!');
		return true;
	}

	/* error */
	var error = root.getElementsByTagName('error')[0];
  if (error) {
	  var code = error.getElementsByTagName('code')[0];
    if (OAT.Xml.textValue(code) != 'OK') {
      if (OAT.Xml.textValue(code) == 'BAD_SESSION') {
        $('sid').value = '';
        $('realm').value = '';
        OAT.Dom.hide("ob_links");
        OAT.Dom.show("lf");
        OAT.Dom.hide("rf");
        OAT.Dom.hide("uf");
        OAT.Dom.hide("pf");
      }
      // executingEnd();
	    var message = error.getElementsByTagName('message')[0];
      if (message)
        alert (OAT.Xml.textValue(message));
  		return true;
    }
  }
  return false;
}

function afterLogin(xml) {
	var root = xml.documentElement;
	if (!hasError(root)) {
  	/* session */
   	var session = root.getElementsByTagName('session')[0];
    if (session) {
      fieldUpdate(session, 'sid', 'sid');
      fieldUpdate(session, 'realm', 'realm');
    }
   	var T = $('form');
   	if (T) {
   	  T.value = 'user';
   	  T.form.submit();
   	} else {
     	var T = $('ob_left');
     	if (T) {
     	  T.innerHTML = '<a href="/ods/myhome.vspx?sid='+$('sid').value+'&realm='+$('realm').value+'">ODS Home</a> > Profile';
     	}
      OAT.Dom.show("ob_right");
      OAT.Dom.hide("ob_links");
      OAT.Dom.hide("lf");
      OAT.Dom.hide("rf");
      OAT.Dom.show("uf");
      OAT.Dom.hide("pf");
      if (!userUpdate(root))
        selectProfile();
    }
  }
  // executingEnd();
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
  // executingEnd();
  return false;
}

function selectProfile() {
  var wsdl = "/ods_services/services.wsdl";
  var serviceName = "ODS_USER_SELECT";

  var inputObject = {
  	ODS_USER_SELECT:{
      pSid:$v('sid'),
      pRealm:$v('realm')
  	}
  }
	OAT.WS.invoke(wsdl, serviceName, selectProfileCallback, inputObject);
  // executingStart();
}

function selectProfileCallback(obj) {
  var xml = OAT.Xml.createXmlDoc(obj.ODS_USER_SELECTResponse.CallReturn);
	var root = xml.documentElement;
	if (!hasError(root)) {
  	/* user data */
   	var user = root.getElementsByTagName('user')[0];
    if (user) {
      tagUpdate(user, 'name', 'uf_name');
      tagUpdate(user, 'mail', 'uf_mail');
      tagUpdate(user, 'title', 'uf_title');
      tagUpdate(user, 'firstName', 'uf_firstName');
      tagUpdate(user, 'lastName', 'uf_lastName');
      tagUpdate(user, 'fullName', 'uf_fullName');
    }
  }
  // executingEnd();
}

function selectLinks() {
  var wsdl = "/ods_services/services.wsdl";
  var serviceName = "ODS_USER_LINKS";

  var inputObject = {
  	ODS_USER_LINKS:{
      pSid:$v('sid'),
      pRealm:$v('realm')
  	}
  }
	OAT.WS.invoke(wsdl, serviceName, selectLinksCallback, inputObject);
}

function selectLinksCallback(obj) {
  var xml = OAT.Xml.createXmlDoc(obj.ODS_USER_LINKSResponse.CallReturn);
	var root = xml.documentElement;
	if (!hasError(root)) {
  	/* links */
    linkUpdate(root, 'foaf', 'ob_links_foaf');
  }
}

function logoutSubmit() {
  var wsdl = "/ods_services/services.wsdl";
  var serviceName = "ODS_USER_LOGOUT";

  var inputObject = {
  	ODS_USER_LOGOUT:{
      pSid:$v('sid'),
      pRealm:$v('realm')
  	}
  }
	OAT.WS.invoke(wsdl, serviceName, logoutCallback, inputObject);
  // executingStart();
  return false;
}

function logoutCallback(obj) {
  $('sid').value = '';
  $('realm').value = '';
 	var T = $('ob_left');
 	if (T) {
 	  T.innerHTML = '<a href="/ods/myhome.vspx?sid='+$('sid').value+'&realm='+$('realm').value+'">ODS Home</a> > Login';
 	}
  OAT.Dom.hide("ob_links");
  OAT.Dom.hide("ob_right");
  OAT.Dom.show("lf");
  OAT.Dom.hide("rf");
  OAT.Dom.hide("pf");
  OAT.Dom.hide("uf");
  // executingEnd();
}

function logoutSubmit2() {
  $('sid').value = '';
  $('realm').value = '';
  $('form').value = 'login';
  $('form').form.submit();
}

function lfLoginSubmit() {
  $('sid').value = '';
  $('realm').value = '';

  if ($v('lf_openID') != '') {
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
  } else {
    var wsdl = "/ods_services/services.wsdl";
    var serviceName = "ODS_USER_LOGIN";

    var inputObject = {
    	ODS_USER_LOGIN:{
        pUser:$v('lf_uid'),
        pPassword:$v('lf_password')
    	}
    }
  	OAT.WS.invoke(wsdl, serviceName, lfLoginCallback, inputObject);
    // executingStart();
  }
  $('lf_password').value = '';
}

function lfLoginCallback(obj) {
  var xml = OAT.Xml.createXmlDoc(obj.ODS_USER_LOGINResponse.CallReturn);
  afterLogin(xml);
}

function lfLoginSubmit2() {
  if ($v('lf_openID') != '') {
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

function rfAlternateLogin (obj) {
  if (obj.checked) {
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

function rfAuthenticateSubmit() {
  if ($('rf_useOpenID').checked) {
    if (!$('rf_is_agreed').checked) {
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

function lfRegisterSubmit(event) {
  $('sid').value = '';
  $('realm').value = '';

 	var T = $('ob_left');
 	if (T) {
 	  T.innerHTML = '<a href="/ods/myhome.vspx?sid='+$('sid').value+'&realm='+$('realm').value+'">ODS Home</a> > Register';
 	}
  OAT.Dom.hide("ob_right");
  OAT.Dom.hide("ob_links");

  OAT.Dom.hide("lf");
  OAT.Dom.show("rf");
  $('rf_openID').value = '';
  $('rf_useOpenID').checked = false;
  $('rf_uid').value = '';
  $('rf_mail').value = '';
  $('rf_password').value = '';
  $('rf_password2').value = '';
  $('rf_is_agreed').checked = false;
  rfAlternateLogin($('rf_useOpenID'));
  return false;
}

function inputParameter (inputField) {
  var T = $(inputField);
  if (T)
    return T.value;
  return '';
}

function rfSignupSubmit(event) {
  if ($v('rf_uid') == '') {
    alert ('Bad username. Please correct!');
  } else if ($v('rf_mail') == '') {
    alert ('Bad mail. Please correct!');
  } else if ($v('rf_password') == '') {
    alert ('Bad password. Please correct!');
  } else if ($v('rf_password') != $v('rf_password2')) {
    alert ('Bad password. Please retype!');
  } else if (!$('rf_is_agreed').checked) {
    alert ('You have not agreed to the Terms of Service!');
  } else {
    $('sid').value = '';
    $('realm').value = '';

    var wsdl = "/ods_services/services.wsdl";
    var serviceName = "ODS_USER_REGISTER";

    var inputObject = {
    	ODS_USER_REGISTER:{
        pUser:$v('rf_uid'),
        pPassword:$v('rf_password') ,
        pMail:$v('rf_mail'),
        oid_identity:inputParameter('rf_identity'),
        oid_fullname:inputParameter('rf_fullname'),
        oid_birthday:inputParameter('rf_birthday'),
        oid_gender:inputParameter('rf_gender'),
        oid_postcode:inputParameter('rf_postcode'),
        oid_country:inputParameter('rf_country'),
        oid_tz:inputParameter('rf_tz')
    	}
    }
  	OAT.WS.invoke(wsdl, serviceName, rfSignupCallback, inputObject);
    // executingStart();
  }
  $('rf_password').value = '';
  $('rf_password2').value = '';
  return false;
}

function rfSignupCallback(obj) {
  var xml = OAT.Xml.createXmlDoc(obj.ODS_USER_REGISTERResponse.CallReturn);
  afterLogin(xml);
}

function ufProfileSubmit() {
  updateList('pf_homeCountry', 'Country');
  clearSelect($('pf_homeState'));
  updateList('pf_businessCountry', 'Country');
  clearSelect($('pf_businessState'));
  updateList('pf_businessIndustry', 'Industry');

  var wsdl = "/ods_services/services.wsdl";
  var serviceName = "ODS_USER_SELECT";

  var inputObject = {
  	ODS_USER_SELECT:{
      pSid:$v('sid'),
      pRealm:$v('realm')
  	}
  }
	OAT.WS.invoke(wsdl, serviceName, ufProfileCallback, inputObject);
  // executingStart();
}

function ufProfileCallback(obj) {
  var xml = OAT.Xml.createXmlDoc(obj.ODS_USER_SELECTResponse.CallReturn);
	var root = xml.documentElement;
	if (!hasError(root)) {
  	/* user data */
   	var user = root.getElementsByTagName('user')[0];
    if (user) {
      //copyList('pf_homeCountry', 'pf_businessCountry');

      // personell
      fieldUpdate(user, 'mail', 'pf_mail');
      fieldUpdate(user, 'title', 'pf_title');
      fieldUpdate(user, 'firstName', 'pf_firstName');
      fieldUpdate(user, 'lastName', 'pf_lastName');
      fieldUpdate(user, 'fullName', 'pf_fullName');

      // cntact
      fieldUpdate(user, 'icq', 'pf_icq');
      fieldUpdate(user, 'skype', 'pf_skype');
      fieldUpdate(user, 'yahoo', 'pf_yahoo');
      fieldUpdate(user, 'aim', 'pf_aim');
      fieldUpdate(user, 'msn', 'pf_msn');

      // home
      fieldUpdate(user, 'homeCountry', 'pf_homeCountry');
      updateState('pf_homeCountry', 'pf_homeState', tagValue(user, 'homeState'));
      fieldUpdate(user, 'homeCity', 'pf_homeCity');
      fieldUpdate(user, 'homeCode', 'pf_homeCode');
      fieldUpdate(user, 'homeAddress1', 'pf_homeAddress1');
      fieldUpdate(user, 'homeAddress2', 'pf_homeAddress2');

      // business
      fieldUpdate(user, 'businessIndustry', 'pf_businessIndustry');
      fieldUpdate(user, 'businessOrganization', 'pf_businessOrganization');
      fieldUpdate(user, 'businessJob', 'pf_businessJob');
      fieldUpdate(user, 'businessCountry', 'pf_businessCountry');
      updateState('pf_businessCountry', 'pf_businessState', tagValue(user, 'businessState'));
      fieldUpdate(user, 'businessCity', 'pf_businessCity');
      fieldUpdate(user, 'businessCode', 'pf_businessCode');
      fieldUpdate(user, 'businessAddress1', 'pf_businessAddress1');
      fieldUpdate(user, 'businessAddress2', 'pf_businessAddress2');

      OAT.Dom.hide("lf");
      OAT.Dom.hide("rf");
      OAT.Dom.hide("uf");
      OAT.Dom.show("pf");
      tab.go (0);
    }
  }
  // executingEnd();
}

function pfUpdateSubmit(event) {
  var wsdl = "/ods_services/services.wsdl";
  var serviceName = "ODS_USER_UPDATE";

  var inputObject = {
  	ODS_USER_UPDATE:{
      pSid:$v('sid'),
      pRealm:$v('realm'),
      pMail:$v('pf_mail'),
      pTitle:$v('pf_title'),
      pFirstName:$v('pf_firstName'),
      pLastName:$v('pf_lastName'),
      pFullName:$v('pf_fullName'),
      pIcq:$v('pf_icq'),
      pSkype:$v('pf_skype'),
      pYahoo:$v('pf_yahoo'),
      pAim:$v('pf_aim'),
      pMsn:$v('pf_msn'),
      pHomeCountry:$v('pf_homeCountry'),
      pHomeState:$v('pf_homeState'),
      pHomeCity:$v('pf_homeCity'),
      pHomeCode:$v('pf_homeCode'),
      pHomeAddress1:$v('pf_homeAddress1'),
      pHomeAddress2:$v('pf_homeAddress2'),
      pBusinessIndustry:$v('pf_businessIndustry'),
      pBusinessOrganization:$v('pf_businessOrganization'),
      pBusinessJob:$v('pf_businessJob'),
      pBusinessCountry:$v('pf_businessCountry'),
      pBusinessState:$v('pf_businessState'),
      pBusinessCity:$v('pf_businessCity'),
      pBusinessCode:$v('pf_businessCode'),
      pBusinessAddress1:$v('pf_businessAddress1'),
      pBusinessAddress2:$v('pf_businessAddress2')
    }
  }
	OAT.WS.invoke(wsdl, serviceName, pfUpdateCallback, inputObject);
  // executingStart();

  $('pf_oldPassword').value = '';
  $('pf_newPassword').value = '';
  $('pf_newPassword2').value = '';
  return false;
}

function pfUpdateCallback(obj) {
  var xml = OAT.Xml.createXmlDoc(obj.ODS_USER_UPDATEResponse.CallReturn);
	var root = xml.documentElement;
	if (!hasError(root)) {
    OAT.Dom.hide("lf");
    OAT.Dom.hide("rf");
    OAT.Dom.show("uf");
    OAT.Dom.hide("pf");
    selectProfile();
  }
  // executingEnd();
}

function pfChangeSubmit(event) {
  if ($v('pf_newPassword') != $v('pf_newPassword2')) {
    alert ('Bad new password. Please retype!');
  } else {
    var wsdl = "/ods_services/services.wsdl";
    var serviceName = "ODS_USER_UPDATE_PASSWORD";

    var inputObject = {
    	ODS_USER_UPDATE_PASSWORD:{
        pSid:$v('sid'),
        pRealm:$v('realm'),
        pOldPassword:$v('pf_oldPassword'),
        pNewPassword:$v('pf_newPassword')
      }
    }
  	OAT.WS.invoke(wsdl, serviceName, pfChangeCallback, inputObject);
    // executingStart();
  }
  $('pf_oldPassword').value = '';
  $('pf_newPassword').value = '';
  $('pf_newPassword2').value = '';
  return false;
}

function pfChangeCallback(obj) {
  var xml = OAT.Xml.createXmlDoc(obj.ODS_USER_UPDATE_PASSWORDResponse.CallReturn);
	var root = xml.documentElement;
	!hasError(root);
  // executingEnd();
}

function pfCancelSubmit() {
  OAT.Dom.hide("lf");
  OAT.Dom.hide("rf");
  OAT.Dom.show("uf");
  OAT.Dom.hide("pf");
}
