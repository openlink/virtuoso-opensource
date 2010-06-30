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

var ODS = {}

ODS.app = {
	AddressBook : {
		menuName : 'AddressBook',
		icon : '/ods/images/icons/ods_ab_16.png',
		dsUrl : '#UID#/addressbook/'
	},
	Bookmarks : {
		menuName : 'Bookmarks',
		icon : '/ods/images/icons/ods_bookmarks_16.png',
		dsUrl : '#UID#/bookmark/'
	},
	Calendar : {
		menuName : 'Calendar',
		icon : '/ods/images/icons/ods_calendar_16.png',
		dsUrl : '#UID#/calendar/'
	},
	Community : {
		menuName : 'Community',
		icon : '/ods/images/icons/ods_community_16.png',
		dsUrl : '#UID#/community/'
	},
	Discussion : {
		menuName : 'Discussion',
		icon : '/ods/images/icons/apps_16.png',
		dsUrl : '#UID#/discussion/'
	},
	Polls : {
		menuName : 'Polls',
		icon : '/ods/images/icons/ods_poll_16.png',
		dsUrl : '#UID#/polls/'
	},
	Weblog : {
		menuName : 'Weblog',
		icon : '/ods/images/icons/ods_weblog_16.png',
		dsUrl : '#UID#/weblog/'
	},
	FeedManager : {
		menuName : 'Feed Manager',
		icon : '/ods/images/icons/ods_feeds_16.png',
		dsUrl : '#UID#/feed/'
	},
	Briefcase : {
		menuName : 'Briefcase',
		icon : '/ods/images/icons/ods_briefcase_16.png',
		dsUrl : '#UID#/briefcase/'
	},
	Gallery : {
		menuName : 'Gallery',
		icon : '/ods/images/icons/ods_gallery_16.png',
		dsUrl : '#UID#/gallery/'
	},
	Mail : {
		menuName : 'Mail',
		icon : '/ods/images/icons/ods_mail_16.png',
		dsUrl : '#UID#/mail/'
	},
	Wiki : {
		menuName : 'Wiki',
		icon : '/ods/images/icons/ods_wiki_16.png',
		dsUrl : '#UID#/wiki/'
	},
	InstantMessenger : {
		menuName : 'Instant Messenger',
		icon : '/ods/images/icons/ods_wiki_16.png',
		dsUrl : '#UID#/IM/'
	},
	eCRM : {
		menuName : 'eCRM',
		icon : '/ods/images/icons/apps_16.png',
		dsUrl : '#UID#/ecrm/'
	}
}

ODS.ico = {
	addressBook : {
		alt : 'AddressBook',
		icon : '/ods/images/icons/ods_ab_16.png'
	},
	bookmarks : {
		alt : 'Bookmarks',
		icon : '/ods/images/icons/ods_bookmarks_16.png'
	},
	calendar : {
		alt : 'Calendar',
		icon : '/ods/images/icons/ods_calendar_16.png'
	},
	community : {
		alt : 'Community',
		icon : '/ods/images/icons/ods_community_16.png'
	},
	discussion : {
		alt : 'Discussion',
		icon : '/ods/images/icons/apps_16.png'
	},
	polls : {
		alt : 'Polls',
		icon : '/ods/images/icons/ods_poll_16.png'
	},
	weblog : {
		alt : 'Weblog',
		icon : '/ods/images/icons/ods_weblog_16.png'
	},
	feeds : {
		alt : 'Feed Manager',
		icon : '/ods/images/icons/ods_feeds_16.png'
	},
	briefcase : {
		alt : 'Briefcase',
		icon : '/ods/images/icons/ods_briefcase_16.png'
	},
	gallery : {
		alt : 'Gallery',
		icon : '/ods/images/icons/ods_gallery_16.png'
	},
	mail : {
		alt : 'Mail',
		icon : '/ods/images/icons/ods_mail_16.png'
	},
	wiki : {
		alt : 'Wiki',
		icon : '/ods/images/icons/ods_wiki_16.png'
	},
	system : {
		alt : 'ODS',
		icon : '/ods/images/icons/apps_16.png'
	},
	instantmessenger : {
		alt : 'InstantMessenger',
		icon : '/ods/images/icons/ods_im_16.png'
	}
};

function eTarget(e) {
	if (!e)
		var e = window.event;
	var t = (e.target) ? e.target : e.srcElement;
	if (t.nodeType == 3) // defeat Safari bug
		t = targ.parentNode;
	return t;
}

function isErr(xmlDoc) {
	var errXmlNodes = OAT.Xml.xpath(xmlDoc, '//error_response', {});
	if (errXmlNodes.length)
		return 1;
	return 0;
}

function widgetToggle (elm)
{
  var _divs = elm.parentNode.parentNode.parentNode.getElementsByTagName ('div');
  for (var i = 0; i < _divs.length; i++)
  {
    if (_divs[i].className == 'w_content')
    {
       if (_divs[i].style.display == 'none')
         OAT.Dom.show (_divs[i]);
       else
         OAT.Dom.hide (_divs[i]);
     }
  }
}

function renderNewsFeedBlock(xmlString) {
	var cont = $('notify_content');
	if (!cont) {return;}

	var actHidden = new Array;
	if ($v('sid') != '') {
		self.feedStatus(function(xmlDoc) {
			var actOpt = OAT.Xml.xpath(xmlDoc, '/feedStatus_response/activity', {});
			for ( var i = 0; i < actOpt.length; i++) {
				var act = buildObjByAttributes(actOpt[i]);
				if (act.status == 0)
					actHidden.push(act.id);
			}
		});
	}
	var daily = buildTimeObj();

	var xmlDoc = OAT.Xml.createXmlDoc(OAT.Xml.removeDefaultNamespace(xmlString));
	var entries = OAT.Xml.xpath(xmlDoc, '/feed/entry', {});

	for ( var i = 0; i < entries.length; i++) {
		var entry = buildObjByChildNodes(entries[i]);
		var actImg = false;

		if ((typeof (entry['dc:type']) != 'undefined')
				&& (typeof (entry['dc:type'].value) != 'undefined')
				&& (entry['dc:type'].value.length > 0)
				&& (typeof (ODS.ico[entry['dc:type'].value]) != 'undefined')) {
			actImg = OAT.Dom.create('img', {}, 'msg_icon');
			actImg.alt = ODS.ico[entry['dc:type'].value].alt;
			actImg.src = ODS.ico[entry['dc:type'].value].icon;
		}

		var feedId = entry.id.split('/');
		feedId = feedId[feedId.length - 1];

		var ctrl_hide = OAT.Dom.create('img', {
			width : '16px',
			height : '16px',
			cursor : 'pointer'
		});
		ctrl_hide.src = '/ods/images/skin/default/notify_remove_btn.png';
		ctrl_hide.alt = 'Hide';
		ctrl_hide.feedId = feedId;

		OAT.Event.attach(ctrl_hide, "click", function(e) {
			var t = eTarget(e);
			var feedId = t.feedId;
			t = t.parentNode.parentNode;
			self.feedStatusSet(feedId, 0, function() {
				if (t.parentNode.childNodes.length == 1) {
					if (t.parentNode.previousSibling.tagName == 'H3')
						OAT.Dom.unlink(t.parentNode.previousSibling);
					OAT.Dom.unlink(t.parentNode);
				} else {
					OAT.Dom.unlink(t);
				}
			});
		});

		var ctrl = OAT.Dom.create('div', {}, 'msg_r')
		OAT.Dom.append( [ ctrl, ctrl_hide ]);

		var actDiv = OAT.Dom.create('div', {}, 'msg');
		actDiv.innerHTML = '<span class="time">' + entry.updated.substr(11, 5) + '</span> ' + entry.title;

		var actLi = OAT.Dom.create('li');

		if (actImg)
			OAT.Dom.append( [ actLi, actImg, actDiv, ctrl ]);
		else
			OAT.Dom.append( [ actLi, actDiv, ctrl ]);

		actDiv.childNodes[4].href = actDiv.childNodes[4].href + '?sid=' + $v('sid') + '&realm=wa';

		var actDate = entry.updated.substring(0, 10);
		if (typeof (daily[actDate]) == 'object' && actHidden.find(feedId) == -1) {
			OAT.Dom.append( [ daily[actDate].ulObj, actLi ]);
		} else
			OAT.Dom.append( [ daily['older'].ulObj, actLi ]);
	}

	OAT.Dom.clear($('notify_content'));

	for (day in daily) {
		if (daily[day].ulObj.childNodes.length > 0) {
			OAT.Dom.append( [ $('notify_content'), daily[day].titleObj, daily[day].ulObj ]);
		}
	}
}

function renderDataspaceUL(xmlString) {
	var ulDS = $('ds_list');
	if (!ulDS) {return;}

	OAT.Dom.clear(ulDS);
	var xmlDoc = OAT.Xml.createXmlDoc(xmlString);
	var resXmlNodes = OAT.Xml.xpath(xmlDoc, '//applicationsGet_response/application', {});
	for (var i = 0; i < resXmlNodes.length; i++) {
		var applicationObj = buildObjByAttributes(resXmlNodes[i]);

		applicationObj.selfTextValue = OAT.Xml.textValue(resXmlNodes[i]);
		if (applicationObj.disable != '0' && applicationObj.url.length > 0) {
			var packageName = applicationObj.type;
			packageName = packageName.replace(' ', '');

			var appOpt = {};
			if (typeof (ODS.app[packageName]) != 'undefined')
				appOpt = ODS.app[packageName];
			else
				appOpt = {
					menuName : packageName,
					icon : 'images/icons/apps_16.png',
					dsUrl : '#UID#/' + packageName + '/'
				}

			var appDataSpaceItem = OAT.Dom.create('li');
			var appDataSpaceItemA = OAT.Dom.create('a', {cursor : 'pointer'});
			appDataSpaceItemA.packageName = packageName;
			appDataSpaceItemA.href = applicationObj.dataspace + '?sid=' + $v('sid') + '&realm=wa';

			var appDataSpaceItemImg = OAT.Dom.create('img');
			appDataSpaceItemImg.className = 'app_icon';
			appDataSpaceItemImg.src = appOpt.icon;

			OAT.Dom.append( [ ulDS, appDataSpaceItem ], [
					appDataSpaceItem, appDataSpaceItemA ], [
					appDataSpaceItemA, appDataSpaceItemImg,
					OAT.Dom.text(' ' + applicationObj.selfTextValue) ]);
		}
	}
}

function renderConnectionsWidget(xmlString) {
	var connTP = $('connP1')
	if (!connTP) {return;}

	OAT.Dom.clear(connTP);
	var xmlDoc = OAT.Xml.createXmlDoc(xmlString);
	var connections = OAT.Xml.xpath(xmlDoc, '//connectionsGet_response/user', {});
	var invitations = OAT.Xml.xpath(xmlDoc, '//connectionsGet_response/user/invited', {});

	$('connPTitleTxt').innerHTML = 'Connections (' + (connections.length - invitations.length) + ')';

	var connectionsArr = new Array();
	for ( var i = 0; i < connections.length; i++) {
		var connObj = buildObjByChildNodes(connections[i]);
		if (typeof (connObj.invited) == 'undefined') {
			var connProfileObj = {};
			connProfileObj[connObj.uid] = connObj.fullName;

			connectionsArr.push(connObj.uid);
			var _divC = OAT.Dom.create('div', {cursor : 'pointer'}, 'conn');
			_divC.id = 'connW_' + connObj.uid;
		  OAT.Event.attach(_divC, "dblclick", function() {document.location.href = connObj.dataspace;});
			var tnail = OAT.Dom.create('img', {width : '40px', height : '40px'});
			tnail.src = (connObj.photo.length > 0 ? connObj.photo: '/ods/images/missing_person_tnail.png'); // images/profile_small.png

			var _divCI = OAT.Dom.create('div', {}, 'conn_info');
			var cNameA = OAT.Dom.create('a', {cursor : 'pointer'});
			cNameA.href = connObj.dataspace;
			cNameA.innerHTML = connObj.fullName;
			OAT.Dom.append( [ connTP, _divC ], [ _divC, tnail, _divCI ], [ _divCI, cNameA ]);
		}
	}
}

function feedStatusSet(feedId, feedStatus, cb) {
	var q = 'sid=' + $v('sid') + '&feedId=' + feedId + '&feedStatus=' + feedStatus;
	var x = function(xml) {
		var xmlDoc = OAT.Xml.createXmlDoc(xml);
		if (!isErr(xmlDoc)) {
			if (typeof (cb) == "function")
				cb(xmlDoc);
		}
	}
	OAT.AJAX.POST('/ods_services/Http/feedStatusSet', q, x);
}

function feedStatus(cb) {
	var q = 'sid=' + $v('sid');
	var x = function(xml) {
		var xmlDoc = OAT.Xml.createXmlDoc(xml);
		if (!isErr(xmlDoc)) {
			if (typeof (callbackFunction) == "function")
				cb(xmlDoc);
		}
	}
	OAT.AJAX.POST('/ods_services/Http/feedStatus', q, x);
}

function buildTimeObj() {
	function pZero(val, prec) {
		if (!prec)
			prec = 2;
		if (String(val).length < prec)
			return '0'.repeat(prec - String(val).length) + String(val);
		else
			return val;
	}
	var weekday = new Array(7);

	weekday[0] = "Sunday";
	weekday[1] = "Monday";
	weekday[2] = "Tuesday";
	weekday[3] = "Wednesday";
	weekday[4] = "Thursday";
	weekday[5] = "Friday";
	weekday[6] = "Saturday";

	var obj = {};
	var d = new Date();
	var titleObj = OAT.Dom.create('h3', {}, 'date');

	OAT.Dom.append( [ titleObj, OAT.Dom.text('Today') ]);
	obj[d.getFullYear() + '-' + pZero(d.getMonth() + 1) + '-' + pZero(d.getDate())] = {
		title : 'Today',
		titleObj : titleObj,
		ulObj : OAT.Dom.create('ul', {}, 'msgs')
	};

	d.setDate(d.getDate() - 1);

	var titleObj = OAT.Dom.create('h3', {}, 'date');

	OAT.Dom.append( [ titleObj, OAT.Dom.text('Yesterday') ]);

	obj[d.getFullYear() + '-' + pZero(d.getMonth() + 1) + '-' + pZero(d.getDate())] = {
		title : 'Yesterday',
		titleObj : titleObj,
		ulObj : OAT.Dom.create('ul', {}, 'msgs')
	}

	for ( var i = 0; i < 5; i++) {
		d.setDate(d.getDate() - 1);
		var titleObj = OAT.Dom.create('h3', {}, 'date');
		OAT.Dom.append( [ titleObj, OAT.Dom.text(weekday[d.getDay()]) ]);
		obj[d.getFullYear() + '-' + pZero(d.getMonth() + 1) + '-' + pZero(d.getDate())] = {
			title : weekday[d.getDay()],
			titleObj : titleObj,
			ulObj : OAT.Dom.create('ul', {}, 'msgs')
		}
	}
	var titleObj = OAT.Dom.create('h3', {}, 'date');
	OAT.Dom.append( [ titleObj, OAT.Dom.text('Older') ]);
	obj['older'] = {
		title : 'Older',
		titleObj : titleObj,
		ulObj : OAT.Dom.create('ul', {}, 'msgs')
	};
	return obj;
}

function buildObjByAttributes(elm) {
	var obj = {};
	for ( var i = 0; i < elm.attributes.length; i++) {
		obj[elm.attributes[i].nodeName] = OAT.Xml.textValue(elm.attributes[i]);
	}
	return obj;
}

function buildObjByChildNodes(elm) {
	var obj = {};
	for ( var i = 0; i < elm.childNodes.length; i++) {
		var pName = elm.childNodes[i].nodeName;
		var pValue = OAT.Xml.textValue(elm.childNodes[i]);
		var pAttrib = elm.childNodes[i].attributes;

		if (!(pName == '#text' && pValue == '\n')) {
			if (typeof (obj[pName]) == 'undefined')
				obj[pName] = pValue;
			else {
				var tmpObj = false;

				if (!(obj[pName] instanceof Array)) {
					tmpObj = obj[pName];
					obj[pName] = new Array();
					obj[pName].push(tmpObj);
					obj[pName].push(pValue);
				} else
					obj[pName].push(pValue);
			}
			if (pAttrib.length > 0) {
				var tmpVal = false;
				if ((obj[pName] instanceof Array)) {
					obj[pName][(obj[pName].length - 1)] = {};
					obj[pName][(obj[pName].length - 1)]['value'] = pValue;
				} else {
					obj[pName] = {};
					obj[pName]['value'] = pValue;
				}
				for ( var k = 0; k < pAttrib.length; k++) {
					if ((obj[pName] instanceof Array))
						obj[pName][(obj[pName].length - 1)]['@' + pAttrib[k].nodeName] = OAT.Xml.textValue(pAttrib[k]);
					else
						obj[pName]['@' + pAttrib[k].nodeName] = OAT.Xml.textValue(pAttrib[k]);
				}
			}
		}
	}
	obj.selfTextValue = OAT.Xml.textValue(elm);
	return obj;
}


// publics
var lfTab;
var rfTab;
var ufTab;
var pfPages = [['pf_page_0_0', 'pf_page_0_1', 'pf_page_0_2', 'pf_page_0_3', 'pf_page_0_4', 'pf_page_0_5', 'pf_page_0_6', 'pf_page_0_7', 'pf_page_0_8', 'pf_page_0_9'], ['pf_page_1_0', 'pf_page_1_1', 'pf_page_1_2', 'pf_page_1_3'], ['pf_page_2']];

var setupWin;
var cRDF;

var regData;
var userData;
var sslData;
var aclData;
var facebookData;

// init
function myInit() {
	// CalendarPopup
	OAT.Preferences.imagePath = "/ods/images/oat/";
	OAT.Preferences.stylePath = "/ods/oat/styles/";
	OAT.Preferences.showAjax = false;

  var x = function (data) {
    try {
      regData = OAT.JSON.parse(data);
    } catch (e) { regData = {}; }
  }
  OAT.AJAX.GET ('/ods/api/server.getInfo?info=regData', false, x, {async: false});

	if ($("lf")) {
    lfTab = new OAT.Tab("lf_content", {goCallback: lfCallback});
		lfTab.add("lf_tab_0", "lf_page_0");
		if (regData.openidEnable)
      OAT.Dom.show('lf_tab_1');
		lfTab.add("lf_tab_1", "lf_page_1");
		lfTab.add("lf_tab_2", "lf_page_2");
		lfTab.add("lf_tab_3", "lf_page_3");
		lfTab.go(0);
    var uriParams = OAT.Dom.uriParams();
    if (uriParams['oid-form'] == 'lf') {
      $('lf_openId').value = uriParams['openid.identity'];
      OAT.Dom.show('lf');
      OAT.Dom.hide('rf');
      lfTab.go(1);
      if (typeof (uriParams['openid.signed']) != 'undefined' && uriParams['openid.signed'] != '') {
        OAT.AJAX.POST ("/ods/api/user.authenticate", openIdLoginURL(uriParams), afterLogin);
      } else if (typeof (uriParams['openid.mode']) != 'undefined' && uriParams['openid.mode'] == 'cancel') {
      alert('OpenID Authentication Failed');
    }
				}
	}
	if ($("rf")) {
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
      OAT.Dom.hide('lf');
      OAT.Dom.show('rf');
	    rfTab.go(1);
      if (typeof (uriParams['openid.signed']) != 'undefined' && uriParams['openid.signed'] != '') {
        var x = function (params, param, data, property) {
          if (params[param] && params[param].length != 0)
            data[property] = params[param];
        }
        var data = {};
        if (typeof (uriParams['openid.ns.ax']) != 'undefined' && uriParams['openid.ns.ax'] == 'http://openid.net/srv/ax/1.0') {
          x(uriParams, 'openid.ax.value.country', data, 'homeCountry');
          x(uriParams, 'openid.ax.value.email', data, 'mbox');
          x(uriParams, 'openid.ax.value.firstname', data, 'firstName');
          x(uriParams, 'openid.ax.value.fname', data, 'name');
          x(uriParams, 'openid.ax.value.language', data, 'language');
          x(uriParams, 'openid.ax.value.lastname', data, 'family_name');
          x(uriParams, 'openid.ax.value.fname', data, 'nick');
          x(uriParams, 'openid.ax.value.timezone', data, 'timezone');
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
            addProfileRowInput(tbl, 'Login Name', 'rf_openid_uid');
          if (!data['mbox'])
            addProfileRowInput(tbl, 'E-Mail', 'rf_openid_email');
        } else {
        var q = 'mode=1&data=' + encodeURIComponent(OAT.JSON.stringify(data));
        OAT.AJAX.POST ("/ods/api/user.register", q, afterSignup);
      }
      }
      else if (typeof (uriParams['openid.mode']) != 'undefined' && uriParams['openid.mode'] == 'cancel')
      {
        alert('OpenID Authentication Failed');
				}
			}
		}
	if ($("lf") || $("rf") || $("pf")) {
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
	}
	if (($("lf") || $("rf")) && (document.location.protocol == 'https:') && regData.sslEnable) {
		var x = function(data) {
		  var x2 = function(prefix) {
		  	OAT.Dom.show(prefix+"_tab_3");
				var tbl = $(prefix+'_table_3');
				if (tbl) {
					addProfileRowValue(tbl, 'WebID', sslData.iri);
					if (sslData.firstName)
						addProfileRowValue(tbl, 'First Name', sslData.firstName);
					if (sslData.family_name)
						addProfileRowValue(tbl, 'Family Name', sslData.family_name);
					if (sslData.mbox)
						addProfileRowValue(tbl, 'E-Mail', sslData.mbox);
          if (prefix == "lf") {
            lfTab.go(3);
          } else if (prefix == "rf") {
					  if (!sslData.nick && !sslData.name)
              addProfileRowInput(tbl, 'Login Name', 'rf_webid_uid');
					  if (!sslData.mbox)
              addProfileRowInput(tbl, 'E-Mail', 'rf_webid_email');
            rfTab.go(3);
            if (!$("lf"))
              rfSSLAutomaticLogin();
          }
			  }
		  }

			try {
				sslData = OAT.JSON.parse(data);
			} catch (e) {
				sslData = null;
			}
			if (sslData && sslData.iri) {
			  if (sslData.certLogin)
			  x2('lf');
			  if (!sslData.certLogin)
			  x2('rf');
			}
		}
		OAT.AJAX.GET('/ods/api/user.getFOAFSSLData?sslFOAFCheck=1', '', x);
	}
  if (document.location.protocol != 'https:')
  {
    var x = function (data) {
      var o = null;
      try {
        o = OAT.JSON.parse(data);
      } catch (e) { o = null; }
      if (o && o.sslPort)
      {
        var a = OAT.Dom.create ("a");
        a.href = 'https://' + document.location.hostname + ((o.sslPort != '443')? ':' + o.sslPort: '') + document.location.pathname;

        var img = OAT.Dom.image('/ods/images/icons/lock_16.png');
        img.border = 0;
        img.alt = 'ODS Users SSL Link';

        OAT.Dom.append([a, img], ['ob_right', a]);
      }
    }
    OAT.AJAX.GET ('/ods/api/server.getInfo?info=sslPort', false, x);
  }
	if ($("uf")) {
		ufTab = new OAT.Tab("uf_content");
		ufTab.add("uf_tab_0", "uf_page_0");
		ufTab.add("uf_tab_1", "uf_page_1");
		ufTab.add("uf_tab_2", "uf_page_2");
		ufTab.add("uf_tab_3", "uf_page_3");
		ufTab.add("uf_tab_4", "uf_page_4");
		ufTab.go(0);
		if ($("uf_rdf_content")) {
      try {
  			cRDF = new OAT.RDFMini($("uf_rdf_content"), {showSearch : false});
      } catch (e) {}
    }
	}
	if ($('pf')) {
	  var obj = $('formTab');
	  if (!obj) {hiddenCreate('formSubtab', null, '0');}
	  var obj = $('formSubtab');
	  if (!obj) {hiddenCreate('formSubtab', null, '0');}

    OAT.Event.attach("pf_tab_0", 'click', function(){pfTabSelect('pf_tab_', 0, 'pf_tab_0_');});
    OAT.Event.attach("pf_tab_1", 'click', function(){pfTabSelect('pf_tab_', 1, 'pf_tab_1_');});
    OAT.Event.attach("pf_tab_2", 'click', function(){pfTabSelect('pf_tab_', 2, 'pf_tab_0_');});
    pfTabInit('pf_tab_', $v('formTab'));

    OAT.Event.attach("pf_tab_0_0", 'click', function(){pfTabSelect('pf_tab_0_', 0);});
    OAT.Event.attach("pf_tab_0_1", 'click', function(){pfTabSelect('pf_tab_0_', 1);});
    OAT.Event.attach("pf_tab_0_2", 'click', function(){pfTabSelect('pf_tab_0_', 2);});
    OAT.Event.attach("pf_tab_0_3", 'click', function(){pfTabSelect('pf_tab_0_', 3);});
    OAT.Event.attach("pf_tab_0_4", 'click', function(){pfTabSelect('pf_tab_0_', 4);});
    OAT.Event.attach("pf_tab_0_5", 'click', function(){pfTabSelect('pf_tab_0_', 5);});
    OAT.Event.attach("pf_tab_0_6", 'click', function(){pfTabSelect('pf_tab_0_', 6);});
    OAT.Event.attach("pf_tab_0_7", 'click', function(){pfTabSelect('pf_tab_0_', 7);});
    OAT.Event.attach("pf_tab_0_8", 'click', function(){pfTabSelect('pf_tab_0_', 8);});
    OAT.Event.attach("pf_tab_0_9", 'click', function(){pfTabSelect('pf_tab_0_', 9);});
    pfTabInit('pf_tab_0_', $v('formSubtab'));

    OAT.Event.attach("pf_tab_1_0", 'click', function(){pfTabSelect('pf_tab_1_', 0);});
    OAT.Event.attach("pf_tab_1_1", 'click', function(){pfTabSelect('pf_tab_1_', 1);});
    OAT.Event.attach("pf_tab_1_2", 'click', function(){pfTabSelect('pf_tab_1_', 2);});
    OAT.Event.attach("pf_tab_1_3", 'click', function(){pfTabSelect('pf_tab_1_', 3);});
    pfTabInit('pf_tab_1_', $v('formSubtab'));
	}
}

function lfCallback(oldIndex, newIndex) {
  if (newIndex == 0)
    $('lf_login').value = 'Login';
  if (newIndex == 1)
    $('lf_login').value = 'OpenID Login';
  if (newIndex == 2)
    $('lf_login').value = 'Facebook Login';
  if (newIndex == 3)
    $('lf_login').value = 'WebID Login';
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

function myCancel(prefix)
{
  needToConfirm = false;
  OAT.Dom.show(prefix+'_list');
  OAT.Dom.hide(prefix+'_form');
  $('formMode').value = '';
  return false;
}

function mySubmit(prefix)
{
  needToConfirm = false;
  if (validateInputs($(prefix+'_id'), prefix)) {
    if (prefix == 'pf06') {
      var S = '/ods/api/user.favorites.'+ $v('formMode') +'?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm'))
              + '&id=' + encodeURIComponent($v('pf06_id'))
              + '&label=' + encodeURIComponent($v('pf06_label'))
              + '&uri=' + encodeURIComponent($v('pf06_uri'))
              + '&properties=' + encodeURIComponent(prepareProperties('r'));
      OAT.AJAX.GET(S, '', function(data){pfShowFavorites();});
    }
    if (prefix == 'pf07') {
    	var S = '/ods/api/user.mades.'+ $v('formMode') +'?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm'))
              + '&id=' + encodeURIComponent($v('pf07_id'))
              + '&property=' + encodeURIComponent($v('pf07_property'))
              + '&url=' + encodeURIComponent($v('pf07_url'))
              + '&description=' + encodeURIComponent($v('pf07_description'));
    	OAT.AJAX.GET(S, '', function(data){pfShowMades();});
    }
    if (prefix == 'pf08') {
    	var S = '/ods/api/user.offers.'+ $v('formMode') +'?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm'))
              + '&id=' + encodeURIComponent($v('pf08_id'))
              + '&name=' + encodeURIComponent($v('pf08_name'))
              + '&comment=' + encodeURIComponent($v('pf08_comment'))
              + '&properties=' + encodeURIComponent(prepareItems('ol'));
    	OAT.AJAX.GET(S, '', function(data){pfShowOffers();});
    }
    if (prefix == 'pf09') {
    	var S = '/ods/api/user.seeks.'+ $v('formMode') +'?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm'))
              + '&id=' + encodeURIComponent($v('pf09_id'))
              + '&name=' + encodeURIComponent($v('pf09_name'))
              + '&comment=' + encodeURIComponent($v('pf09_comment'))
              + '&properties=' + encodeURIComponent(prepareItems('wl'));
    	OAT.AJAX.GET(S, '', function(data){pfShowSeeks();});
    }
    OAT.Dom.show(prefix+'_list');
    OAT.Dom.hide(prefix+'_form');
    $('formMode').value = '';
  }
  return false;
}

function submitItems()
{
  if ($('items')) {
    if ($v('formTab') == '0' && $v('formSubtab') == '6' && $v('formMode') != '')
      $('items').value = prepareProperties('r');
    if ($v('formTab') == '0' && $v('formSubtab') == '8' && $v('formMode') != '')
      $('items').value = prepareItems('ol');
    if ($v('formTab') == '0' && $v('formSubtab') == '9' && $v('formMode') != '')
      $('items').value = prepareItems('wl');
  }
}

function myBeforeSubmit()
{
  needToConfirm = false;
  submitItems()
}

var needToConfirm = true;
function myCheckLeave (form)
{
  var formTab = parseInt($v('formTab'));
  var formSubtab = parseInt($v('formSubtab'));
  var div = $(pfPages[formTab][formSubtab]);
  var dirty = false;
  var retValue = true;

  submitItems()
  if (needToConfirm && (formTab < 2))
  {
    for (var i = 0; i < form.elements.length; i++)
    {
      if (!form.elements[i])
        continue;

      var ctrl = form.elements[i];
      if (typeof(ctrl.type) == 'undefined')
        continue;

     	if (!OAT.Dom.isChild(ctrl, div))
        continue;

      if (ctrl.disabled)
        continue;

      if (ctrl.disabled)
        continue;

			if (OAT.Dom.isClass(ctrl, 'dummy'))
        continue;

      if (ctrl.type.indexOf ('select') != -1)
      {
        var selections = 0;
        for (var j = 0; j < ctrl.length; j ++)
        {
          var opt = ctrl.options[j];
          if (opt.defaultSelected == true)
	          selections++;
          if (opt.defaultSelected != opt.selected)
            dirty = true;
        }
	      if (selections == 0 && ctrl.selectedIndex == 0)
	        dirty = false;
	      if (dirty == true)
	        break;
      }
      else if ((ctrl.type.indexOf ('text') != -1 || ctrl.type == 'password') && ctrl.defaultValue != ctrl.value)
      {
        dirty = true;
        break;
      }
      else if ((ctrl.type == 'checkbox' || ctrl.type == 'radio') && ctrl.defaultChecked != ctrl.checked)
      {
        dirty = true;
        break;
      }
    }
    if (dirty)
    {
      retValue = confirm('You are about to leave the page, but there is changed data which is not saved.\r\nDo you wish to save changes ?');
      if ($('form'))
      {
        if (retValue) {
          hiddenCreate('pf_update', null, 'x');
          form.submit();
        }
      } else {
        retValue = !retValue;
      }
    }
  }
  return retValue;
}

function pfSetACLSelects (obj)
{
  var form = obj.form;
  var formTab = parseInt($v('formTab'));
  var formSubtab = parseInt($v('formSubtab'));
  var div = $(pfPages[formTab][formSubtab]);

  for (var i = 0; i < form.elements.length; i++)
  {
    var ctrl = form.elements[i];

    if (!ctrl)
      continue;

    if (typeof(ctrl.type) == 'undefined')
      continue;

    if (ctrl.disabled)
      continue;

   	if (ctrl.name.indexOf('pf_acl_') != 0)
      continue;

   	if (!OAT.Dom.isChild(ctrl, div))
      continue;

    ctrl.value = obj.value;
  }
  obj.value = '0';
}

function pfParam(fldName)
{
  var S = '';
  var v = $v(fldName);
  if (v)
    S = '&'+fldName+'='+ encodeURIComponent(v);
  return S;
}

function pfTabSelect(tabPrefix, newIndex, subtabPrefix) {
  $('formMode').value = '';
  if (subtabPrefix) {
    if ($v('formTab') == newIndex) {return;}
  } else {
    if ($v('formSubtab') == newIndex) {return;}
  }
  if ($('form')) {
    var S = '?'+pfParam('sid')+pfParam('realm')+pfParam('form');
    if (subtabPrefix) {
      S += '&formTab='+newIndex+'&formSubtab=0';
    } else {
      S += pfParam('formTab')+'&formSubtab='+newIndex;
    }
    document.location = document.location.protocol + '//' + document.location.host + document.location.pathname + S;
    return;
  }
  if (myCheckLeave($('page_form'))) {
    if (subtabPrefix) {
      $('formTab').value = newIndex;
      $('formSubtab').value = 0;
    } else {
      $('formSubtab').value = newIndex;
    }
    ufProfileLoad();
  } else {
    pfUpdateSubmit(0);
  }
}

function pfTabInit(tabPrefix, newIndex) {
  var N = 0;
  var pagePrefix = tabPrefix.replace('_tab_', '_page_');
  while (obj = $(tabPrefix+N)) {
    OAT.Dom.hide(pagePrefix+N);
    OAT.Dom.removeClass(tabPrefix+N, 'tab_selected');
    if (tabPrefix+N == tabPrefix+newIndex) {
      OAT.Dom.show(pagePrefix+N);
      OAT.Dom.addClass(tabPrefix+N, 'tab_selected');
    }
    N++;
  }
}

function pfShowRows(prefix, values, delimiters, showRow, acl, aclName) {
  var rowCount = 0;
  var tbl = prefix+'_tbl';
	var tmpLines = values.split(delimiters[0]);
	for ( var N = 0; N < tmpLines.length; N++) {
	  if (tmpLines[N] != '') {
      rowCount++;
  		if (delimiters.length == 1) {
  			showRow(prefix, tmpLines[N]);
  		} else {
  			var items = tmpLines[N].split(delimiters[1]);
  			showRow(prefix, items[0], items[1]);
  		}
  	}
	}
	if (rowCount == 0)
	  OAT.Dom.show(prefix+'_tr_no');

	// update acl
  fieldACLUpdate(acl, aclName);
}

function pfShowBioEvents(prefix, showRow) {
  var x = function (data)
  {
    var rowCount = 0;
		var o = null;
		try {
			o = OAT.JSON.parse(data);
		} catch (e) {
			o = null;
		}
		if (o) {
      var tbl = prefix+'_tbl';
    	for (var N = 0; N < o.length; N++) {
   			showRow(prefix, o[N][0], o[N][1], o[N][2], o[N][3]);
        rowCount++;
    	}
    }
  	if (rowCount == 0)
  	  OAT.Dom.show(prefix+'_tr_no');
  }
	OAT.AJAX.GET('/ods/api/user.bioEvents.list?sid='+encodeURIComponent($v('sid'))+'&realm='+encodeURIComponent($v('realm')), '', x);
}

function pfShowOnlineAccounts(prefix, accountType, showRow) {
  var x = function (data)
  {
    var rowCount = 0;
		var o = null;
		try {
			o = OAT.JSON.parse(data);
		} catch (e) {
			o = null;
		}
		if (o) {
      var tbl = prefix+'_tbl';
    	for (var N = 0; N < o.length; N++) {
   			showRow(prefix, o[N][0], o[N][1], o[N][2]);
        rowCount++;
    	}
    }
  	if (rowCount == 0)
  	  OAT.Dom.show(prefix+'_tr_no');
  }
	OAT.AJAX.GET('/ods/api/user.onlineAccounts.list?sid='+encodeURIComponent($v('sid'))+'&realm='+encodeURIComponent($v('realm'))+'&type='+accountType, '', x);
}

function pfShowItem(api, prefix, names, cb) {
  var x = function (data)
  {
		var o = null;
		try {
			o = OAT.JSON.parse(data);
		} catch (e) {
			o = null;
		}
		if (o) {
    	for (var N = 0; N < names.length; N++) {
    	  var name = names[N];
    	  var fld = $(prefix+'_'+name);
    	  if (fld && (o[name] != null))
    	    fld.value = o[name];
    	}
    	if (cb) {cb(o);}
    }
  }
  OAT.AJAX.GET('/ods/api/'+api+'?sid='+encodeURIComponent($v('sid'))+'&realm='+encodeURIComponent($v('realm'))+'&id='+$v(prefix+'_id'), '', x);
}

function pfShowList(api, prefix, noMsg, cols, idIndex, cb) {
  var x = function (data)
  {
    function buttonShow (elm, actionButton, srcButton, textButton) {
      var span = OAT.Dom.create('span');
      span.className = 'button pointer';
      span.onclick = actionButton;

      var img = OAT.Dom.create('img');
      img.className = 'button';
      img.src = '/ods/images/icons/' + srcButton;
   		span.appendChild(img);
      span.appendChild(OAT.Dom.text(textButton));

   		elm.appendChild(span);
    }
    var rowCount = 0;
		var o = null;
		try {
			o = OAT.JSON.parse(data);
		} catch (e) {
			o = null;
		}
		var tbody = $(prefix+'_tbody');
		tbody.innerHTML = '';
		if (o) {
    	for (var N = 0; N < o.length; N++) {
    	  var id = o[N][idIndex];
    	  var tr = OAT.Dom.create('tr');
    	  for (var M = 0; M < cols.length; M++) {
      	  var td = OAT.Dom.create('td');
      		td.innerHTML = o[N][cols[M]];
      		tr.appendChild(td);
        }
    	  var td = OAT.Dom.create('td');
    	  td.noWrap = true;
        buttonShow(td, function(p1, p2){return function(){pfEditListObject(p1, p2);};}(prefix, id), 'edit_16.png', ' Edit');
        td.appendChild(OAT.Dom.text(' '));
        buttonShow(td, function(p1, p2, p3){return function(){pfDeleteListObject(p1, p2, p3);};}(api, id, cb), 'trash_16.png', ' Delete');
      	tr.appendChild(td);

    		tbody.appendChild(tr);
        rowCount++;
    	}
    }
  	if (rowCount == 0) {
  	  var tr = OAT.Dom.create('tr');
  	  var td = OAT.Dom.create('td');
  		td.colSpan = cols.length + 1;
  		td.innerHTML = noMsg;
  		tr.appendChild(td);

  		tbody.appendChild(tr);
  	}
  }
	OAT.AJAX.GET('/ods/api/'+api+'?sid='+encodeURIComponent($v('sid'))+'&realm='+encodeURIComponent($v('realm')), '', x);
}

function pfDeleteListObject(api, id, cb) {
  if (confirm('Are you sure you want to delete this record?')) {
    var deleteApi = api.replace('list', 'delete');
	  OAT.AJAX.GET('/ods/api/'+deleteApi+'?sid='+encodeURIComponent($v('sid'))+'&realm='+encodeURIComponent($v('realm'))+'&id='+id, '', cb);
	}
}

function pfEditListObject(prefix, id) {
  hiddenCreate(prefix+'_id', $('page_form'), id);
  $('formMode').value = 'edit';
  if ($v('mode') == 'html') {
    if (prefix == 'pf06')
      pfShowFavorite('edit', id);
    if (prefix == 'pf07')
      pfShowMade('edit', id);
    if (prefix == 'pf08')
      pfShowOffer('edit', id);
    if (prefix == 'pf09')
      pfShowSeek('edit', id);
    return false;
  }
  $('page_form').submit();
}

function pfShowMode(prefix, mode, id) {
  if (mode) {
    OAT.Dom.hide(prefix+'_list');
    OAT.Dom.show(prefix+'_form');
    hiddenCreate(prefix+'_id', $('page_form'), id);
    $('formMode').value = mode;
  }
}

function pfShowFavorite(mode, id) {
  pfShowMode('pf06', mode, id)
  var x = function (obj) {
    $('r_tbody').innerHTML = '<tr id="r_item_0_tr_0_properties"><td></td><td></td><td valign="top"></td></tr>';
    RDF.tablePrefix = 'r';
    RDF.itemTypes = obj.properties;
    RDF.loadOntology(
      'http://rdfs.org/sioc/ns#',
      function(){
        RDF.loadClassProperties(
          RDF.getOntologyClass('sioc:Item'),
          function(){
            RDF.showPropertiesTable(RDF.itemTypes[0].items[0]);
          }
        );
      }
    )
  }
  pfShowItem('user.favorites.get', 'pf06', ['label', 'uri'], x);
}

function pfShowMade(mode, id) {
  pfShowMode('pf07', mode, id)
  pfShowItem('user.mades.get', 'pf07', ['property', 'uri', 'description']);
}

function pfShowOffer(mode, id) {
  pfShowMode('pf08', mode, id)
  var x = function (obj) {
    $('ol_tbody').innerHTML = '';
    RDF.tablePrefix = 'ol';
    RDF.tableOptions = {itemType: {fld_1: {cssText: "display: none;"}, btn_1: {cssText: "display: none;"}}};
    RDF.itemTypes = obj.properties;
    RDF.showItemTypes();
  }
  pfShowItem('user.offers.get', 'pf08', ['name', 'comment'], x);
}

function pfShowSeek(mode, id) {
  pfShowMode('pf09', mode, id)
  var x = function(obj) {
    $('wl_tbody').innerHTML = '';
    RDF.tablePrefix = 'wl';
    RDF.tableOptions = {itemType: {fld_1: {cssText: "display: none;"}, btn_1: {cssText: "display: none;"}}};
    RDF.itemTypes = obj.properties;
    RDF.showItemTypes();
  }
  pfShowItem('user.seeks.get', 'pf09', ['name', 'comment'], x);
}

function pfShowFavorites() {
  pfShowList('user.favorites.list', 'pf06', 'No Items', [3, 4], 0, function (data){pfShowFavorites();});
}

function pfShowMades() {
  pfShowList('user.mades.list', 'pf07', 'No Items', [1, 3], 0, function (data){pfShowMades();});
}

function pfShowOffers() {
  pfShowList('user.offers.list', 'pf08', 'No Items', [1, 2], 0, function (data){pfShowOffers();});
}

function pfShowSeeks() {
  pfShowList('user.seeks.list', 'pf09', 'No Items', [1, 2], 0, function (data){pfShowSeeks();});
}

function isShow(element) {
	var elm = $(element);
	if (elm && elm.style.display == "none")
	  return false;
  return true;
}

function loadFacebookData(cb) {
	var x = function(data) {
		try {
			facebookData = OAT.JSON.parse(data);
		} catch (e) {
			facebookData = null;
		}
		if (facebookData && regData.facebookEnable) {
			OAT.Dom.show("lf_tab_2");
			OAT.Dom.show("rf_tab_2");
			OAT.Dom.show("pf_facebook");
			OAT.Dom.show("pf_facebook1");
			OAT.Dom.show("pf_facebook2");
			OAT.Dom.show("pf_facebook3");
		}
		if (cb) {cb()};
	}
	OAT.AJAX.GET('/ods/api/user.getFacebookData?fields=uid,name,first_name,last_name,sex,birthday', '', x);
}

function showFacebookData(skip) {
	var lfLabel = $('lf_facebookData');
	var rfLabel = $('rf_facebookData');
	var pfLabel = $('pf_facebookData');
	if (lfLabel || rfLabel || pfLabel) {
  	if (lfLabel) {lfLabel.innerHTML = '';}
  	if (rfLabel) {rfLabel.innerHTML = '';}
  	if (pfLabel) {pfLabel.innerHTML = '';}
  	if (facebookData && facebookData.name) {
  		if (lfLabel) {lfLabel.innerHTML = 'Connect as <b><i>' + facebookData.name + '</i></b></b>'};
  		if (rfLabel) {rfLabel.innerHTML = 'Connect as <b><i>' + facebookData.name + '</i></b></b>'};
  		if (pfLabel) {pfLabel.innerHTML = 'Connect as <b><i>' + facebookData.name + '</i></b></b>'};
  	}
  	else if (!skip) {
  		self.loadFacebookData(function() {self.showFacebookData(true);});
  	}
	}
}

function hideFacebookData() {
	var label = $('lf_facebookData');
	if (label)
	label.innerHTML = '';
	var label = $('rf_facebookData');
	if (label)
  	label.innerHTML = '';
	if (facebookData) {
	var o = {}
	o.api_key = facebookData.api_key;
	o.secret = facebookData.secret;
	facebookData = o;
}
}

function hiddenCreate(objName, objForm, objValue) {
	var obj = $(objName);
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
		if (str) {
    str = str.replace (/%2B/g, ' ');
    } else {
		  str = '';
    }
  } catch (x) {
    str = '';
  }
  return str;
}

function fieldUpdate(xml, tName, fName, acl, aclName) {
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
	}
	else if (obj.type == 'checkbox') {
		obj.checked = false;
	  if (str == '1')
		  obj.checked = true;
		obj.defaultChecked = obj.checked;
  } else {
    obj.value = str;
		obj.defaultValue = str;
  }
	if (!aclName)
	  aclName = 'pf_acl_' + tName;
  fieldACLUpdate(acl, aclName, tName);
}


function fieldACLUpdate(acl, aclName, tName) {
	if (acl) {
	  var obj = $(aclName);
	  if (!tName)
	    tName = aclName.replace('pf_acl_', '');
  	var str = tagValue(acl, tName);
  	if (obj.type == 'select-one') {
  		var o = obj.options;
  		if (o.length == 0) {
			 o[0] = new Option('public', '1');
			 o[1] = new Option('friends', '2');
			 o[2] = new Option('private', '3');
  		}
  		for ( var i = 0; i < o.length; i++) {
  			if (o[i].value == str) {
  				o[i].selected = true;
  				o[i].defaultSelected = true;
  			}
  		}
  	}
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
	for ( var i = 0; i < obj.options.length; i++)
		obj.options[i] = null;

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

function afterAuthenticate(xml) {
	var root = xml.documentElement;
	if (!hasError(root)) {
  	/* session */
   	var oid = root.getElementsByTagName('oid')[0];
		if (oid) {
      fieldUpdate(oid, 'uid', 'rf_uid');
			fieldUpdate(oid, 'mail', 'rf_email');
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
  // UI Profile
  var S = '/ods/api/user.info?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm'));
  OAT.AJAX.GET(S, '', selectProfileCallbackNew);

  // Old UI Profile
  // var S = '/ods/api/user.info?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm')) + '&short=1';
  // OAT.AJAX.GET(S, '', selectProfileCallback);
}

function selectProfileCallbackNew(data) {
  var xml = OAT.Xml.createXmlDoc(data);
	if (!hasError(xml)) {
  	/* user data */
   	var user = xml.getElementsByTagName('user')[0];
		if (user) {
      $('ob_left_name').innerHTML = tagValue(user, 'fullName');
      x = function (data) {
        var xml = OAT.Xml.createXmlDoc(data);
        if (!hasError(xml)) {
          /* user data */
          showProfileNew(xml);
        }
      }
      var S = '/ods/api/user.info.webID?webID=' + encodeURIComponent(tagValue(user, 'iri'));
      OAT.AJAX.GET(S, '', x);
    }
  }
}

function showProfileNew(xmlDoc) {
  var div = $('uf_div_new');
  if (div) {
    var x = function(data) {
      var xslDoc = OAT.Xml.createXmlDoc(data);
      var result = OAT.Xml.transformXSLT(xmlDoc, xslDoc);
      div.innerHTML = result.documentElement.innerHTML;
    }
    OAT.AJAX.GET('users.xsl', false, x);
  }
}

function selectProfileCallback(data) {
  var xml = OAT.Xml.createXmlDoc(data);
  if (!hasError(xml)) {
    /* user data */
    var user = xml.getElementsByTagName('user')[0];
    if (user)
      showProfile(user)
  }
}

function showProfile(user) {
		  // width
			var L = $('u_profile_l');
  		var R = $('u_profile_r');
  		var LWidth = OAT.Dom.getWH(L)[0] > 0 ? OAT.Dom.getWH(L)[0] : 200;
  		var RWidth = OAT.Dom.getWH($('uf_div'))[0] - LWidth;

  		R.style.width = RWidth + 'px';
   		var widgets = R.getElementsByTagName("div");
  		for (var i = 0; i < widgets.length; i++) {
  			if (OAT.Dom.isClass(widgets[i], 'widget'))
  				widgets[i].style.width = RWidth - 6 + 'px';

  			if (OAT.Dom.isClass(widgets[i], 'tab_deck'))
  				widgets[i].style.width = RWidth - 8 + 'px';
  		}

  $('ob_left_name').innerHTML = tagValue(user, 'fullName');

		  // photo
  		$('userProfilePhotoName').innerHTML = '<h3>' + tagValue(user, 'fullName') + '</h3>';

  		var photo = tagValue(user, 'photo');
  		$('userProfilePhotoImg').src = photo ? photo: '/ods/images/missing_profile_picture.png';
  		$('userProfilePhotoImg').alt = tagValue(user, 'fullName');

  		var iri = tagValue(user, 'iri');
  		var name = tagValue(user, 'name');
  		$('uf_foaf_gem').href = iri.replace('#this', '');
  		$('uf_sioc_gem').href = (iri.replace('#this', '')).replace('/person/'+name, '/'+name);
  		$('uf_vcard_gem').href = '/ods/sn_user_export.vspx?ufid='+tagValue(user, 'uid')+'&ufname='+name;

		  // profile
      var tbl = $('uf_table_0');
			if (tbl) {
				try {
        tbl.innerHTML = '';
				} catch (e) {}
        addProfileRow(tbl, user, 'name',      'Login Name');
				addProfileRow(tbl, user, 'nickName', 'Nick Name');
    addProfileRow(tbl, user, 'iri', 'WebID');
				addProfileRow(tbl, user, 'title', 'Title');
				addProfileRow(tbl, user, 'firstName', 'First Name');
				addProfileRow(tbl, user, 'lastName', 'Lsst Name');
				addProfileRow(tbl, user, 'fullName', 'Full Name');
				addProfileRow(tbl, user, 'mail', 'E-mail');
        addProfileRow(tbl, user, 'gender',    'Gender');
        addProfileRow(tbl, user, 'birthday',  'Birthday');
        addProfileRow(tbl, user, 'homepage',  'Personal Webpage');
				addProfileTableValues(tbl, 'Personal URIs (Web IDs)', tagValue(user, 'webIDs'), [ 'URL' ], [ '\n' ])
				addProfileTableValues(tbl, 'Topic of Interests', tagValue(user, 'interests'), [ 'URL', 'Label' ], [ '\n', ';' ])
				addProfileTableValues(tbl, 'Thing of Interests', tagValue(user, 'topicInterests'), [ 'URL', 'Label' ], [ '\n', ';' ])
      }
      var tbl = $('uf_table_1');
			if (tbl) {
				try {
        tbl.innerHTML = '';
				} catch (e) {}
        addProfileRow(tbl, user, 'icq',   'ICQ Number');
        addProfileRow(tbl, user, 'skype', 'Skype ID');
        addProfileRow(tbl, user, 'aim',   'AIM Name');
        addProfileRow(tbl, user, 'yahoo', 'Yahoo! ID');
        addProfileRow(tbl, user, 'msn',   'MSN Messenger');
				addProfileTableRowValue(tbl, tagValue(user, 'messaging'), ['\n', ';' ], 'th')
      }
      var tbl = $('uf_table_2');
			if (tbl) {
				try {
        tbl.innerHTML = '';
				} catch (e) {}
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
				try {
        tbl.innerHTML = '';
				} catch (e) {}
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

		  // activities
 			OAT.AJAX.GET('/activities/feeds/activities/user/'+name+'/0/', false, renderNewsFeedBlock);

		  // data spaces
  		OAT.AJAX.POST('/ods_services/Http/applicationsGet?scope=own&sid='+$v('sid'), false, renderDataspaceUL);

		  // data spaces
  		OAT.AJAX.POST('/ods_services/Http/connectionsGet?scope=own&sid='+$v('sid'), false, renderConnectionsWidget);
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

function addProfileRowInput(tbl, label, fName) {
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
		var S = '/ods/api/user.logout?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm'));
	OAT.AJAX.GET(S, '', function (){document.location = document.location.protocol + '//' + document.location.host + document.location.pathname;});
  return false;
}

function lfLoginSubmit() {
  loginSubmit(lfTab.selectedIndex, 'lf');
		return false;
}

function loginSubmit(mode, prefix) {
	var q = '';
	if (mode == 1) {
    var uriParams = OAT.Dom.uriParams();
    if (typeof (uriParams['openid.signed']) != 'undefined' && uriParams['openid.signed'] != '') {
      q += openIdLoginURL(uriParams);
    } else {
		  if ($(prefix+'_openId').value.length == 0)
			return showError('Invalid OpenID URL');

  	  openIdAuthenticate(prefix);
    return false;
  	}
	} else if (mode == 2) {
		if (!facebookData || !facebookData.uid)
			return showError('Invalid Facebook UserID');

		q += '&facebookUID=' + facebookData.uid;
	} else if (mode == 3) {
  } else {
		if (($(prefix+'_uid').value.length == 0) || ($(prefix+'_password').value.length == 0))
			return showError('Invalid Member ID or Password');

		q += 'user_name='
				+ encodeURIComponent($v(prefix+'_uid'))
				+ '&password_hash='
				+ encodeURIComponent(OAT.Crypto.sha($v(prefix+'_uid')
						+ $v(prefix+'_password')));
    }
	OAT.AJAX.POST("/ods/api/user.authenticate", q, afterLogin);
	return false;
}

function afterLogin(data, prefix) {
	var xml = OAT.Xml.createXmlDoc(data);
	if (!hasError(xml)) {
		/* user data */
		$('sid').value = OAT.Xml.textValue(xml.getElementsByTagName('sid')[0]);
		$('realm').value = 'wa';
		var T = $('form');
		if (T) {
			T.value = ((prefix == 'rf')? 'profile': 'user');
			T.form.submit();
		} else {
			OAT.Dom.show("ob_right_logout");
			OAT.Dom.hide("ob_links");
			OAT.Dom.hide("lf");
			OAT.Dom.hide("rf");
			OAT.Dom.hide("uf");
			OAT.Dom.hide("pf");
			if (prefix == 'rf') {
			OAT.Dom.show("pf");
			ufProfileSubmit();
			} else {
			  pfCancelSubmit();
			}
		}
	} else {
		$('sid').value = '';
		$('realm').value = '';
	}
	return false;
}

function userSubmit() {
  $('form').value='user';
  $('page_form').submit();

  return false;
}

function profileSubmit() {
  $('form').value='profile';
  $('formTab').value=0;
  $('formSubtab').value=0;
  $('page_form').submit();

  return false;
}

function inputParameter(inputField) {
  var T = $(inputField);
  if (T)
    return T.value;
  return '';
}

function ufCleanTablesData(prefix) {
  var tbl = $(prefix+"_tbl");
  if (!tbl) {return;}

  var TRs = tbl.getElementsByTagName('tr');
  for (var i = TRs.length-1; i >= 0; i--) {
    if (TRs[i].id == prefix+"_tr_no") {
      OAT.Dom.show(TRs[i]);
    } else {
      if (TRs[i].id.indexOf(prefix+"_tr_") == 0)
	      OAT.Dom.unlink(TRs[i]);
		}
	}
}

function ufProfileSubmit() {
  showTitle('user');

	$('formTab').value = '0';
	$('formSubtab').value = '0';
  updateList('pf_homecountry', 'Country');
  updateList('pf_businesscountry', 'Country');
  updateList('pf_businessIndustry', 'Industry');
	ufProfileLoad()
}

function ufProfileLoad(No) {
    var formTab = parseInt($v('formTab'));
    var formSubtab = parseInt($v('formSubtab'));
  if (No == 1) {
    formSubtab++;
    if (
        ((formTab == 1) && (formSubtab > 3)) ||
        (formTab > 1)
       )
    {
      formTab++;
      formSubtab = 0;
      pfTabInit('pf_tab_', formTab);
    }
    $('formTab').value = "" + formTab;
    $('formSubtab').value = "" + formSubtab;
  }
  if ((formTab == 0) && (formSubtab > 5)) {
    OAT.Dom.hide('pf_footer_0');
  } else {
    OAT.Dom.show('pf_footer_0');
  }
  pfCleanFOAFData();
  ufCleanTablesData("x1");
  ufCleanTablesData("x2");
  ufCleanTablesData("x3");
  ufCleanTablesData("x4");
  ufCleanTablesData("x5");
  ufCleanTablesData("x6");
  ufCleanTablesData("r");
  ufCleanTablesData("y1");
  ufCleanTablesData("y2");

	var S = '/ods/api/user.info?sid='+encodeURIComponent($v('sid'))+'&realm='+encodeURIComponent($v('realm'))+'&short=0';
  OAT.AJAX.GET(S, '', ufProfileCallback);
}

function ufProfileCallback(data) {
  var xml = OAT.Xml.createXmlDoc(data);
	if (!hasError(xml)) {
  	/* user data */
   	var user = xml.getElementsByTagName('user')[0];
		if (user) {
		  // acl data
      var x = function (data) {
        aclData = null;
        try {
        	var xml = OAT.Xml.createXmlDoc(data);
        	if (!hasError(xml))
        		aclData = xml.getElementsByTagName('acl')[0];
        } catch (e) {}
      }
      OAT.AJAX.GET ('/ods/api/user.acl.info?sid='+encodeURIComponent($v('sid'))+'&realm='+encodeURIComponent($v('realm')), false, x, {async: false});

      // personal
			// main
      hiddenCreate('c_nick', null, tagValue(user, 'nickName'));
      $('ob_left_name').innerHTML = tagValue(user, 'fullName');
      fieldUpdate(user, 'nickName', 'pf_nickName');
			fieldUpdate(user, 'name', 'pf_loginName');
			fieldUpdate(user, 'nickName', 'pf_nickName');
			fieldUpdate(user, 'mail', 'pf_mail', aclData);
			fieldUpdate(user, 'title', 'pf_title', aclData);
			fieldUpdate(user, 'firstName', 'pf_firstName', aclData);
			fieldUpdate(user, 'lastName', 'pf_lastName', aclData);
			fieldUpdate(user, 'fullName', 'pf_fullName', aclData);
			fieldUpdate(user, 'gender', 'pf_gender', aclData);
			fieldUpdate(user, 'birthday', 'pf_birthday', aclData);
			fieldUpdate(user, 'homepage', 'pf_homepage', aclData);
      pfShowRows("x1", tagValue(user, "webIDs"), ["\n"], function(prefix, val1){TBL.createRow(prefix, null, {fld_1: {value: val1, className: '_validate_ _url_ _canEmpty_'}});}, aclData, 'pf_acl_webIDs');
			fieldUpdate(user, 'mailSignature', 'pf_mailSignature');
			fieldUpdate(user, 'summary', 'pf_summary', aclData);
			fieldUpdate(user, 'photo', 'pf_photo', aclData);
			fieldUpdate(user, 'photoContent', 'pf_photoContent');
			fieldUpdate(user, 'audio', 'pf_audio', aclData);
			fieldUpdate(user, 'audioContent', 'pf_audioContent');
			fieldUpdate(user, 'appSetting', 'pf_appSetting');
      pfShowRows("x2", tagValue(user, "interests"), ["\n", ";"], function(prefix, val1, val2){TBL.createRow(prefix, null, {fld_1: {value: val1, className: '_validate_ _url_ _canEmpty_'}, fld_2: {value: val2}});}, aclData, 'pf_acl_interests');
      pfShowRows("x3", tagValue(user, "topicInterests"), ["\n", ";"], function(prefix, val1, val2){TBL.createRow(prefix, null, {fld_1: {value: val1, className: '_validate_ _url_ _canEmpty_'}, fld_2: {value: val2}});}, aclData, 'pf_acl_topicInterests');

			// address
			fieldUpdate(user, 'homeCountry', 'pf_homecountry', aclData);
			updateState('pf_homecountry', 'pf_homestate', tagValue(user, 'homeState'));
		  fieldACLUpdate(aclData, 'pf_acl_homeState');
			fieldUpdate(user, 'homeCity', 'pf_homecity', aclData);
			fieldUpdate(user, 'homeCode', 'pf_homecode', aclData);
			fieldUpdate(user, 'homeAddress1', 'pf_homeaddress1', aclData);
      fieldUpdate(user, 'homeAddress2',           'pf_homeaddress2');
			fieldUpdate(user, 'homeTimezone', 'pf_homeTimezone', aclData);
			fieldUpdate(user, 'homeLatitude', 'pf_homelat', aclData);
      fieldUpdate(user, 'homeLongitude',          'pf_homelng');
      fieldUpdate(user, 'defaultMapLocation',     'pf_homeDefaultMapLocation');
			fieldUpdate(user, 'homePhone', 'pf_homePhone', aclData);
			fieldUpdate(user, 'homePhoneExt', 'pf_homePhoneExt');
      fieldUpdate(user, 'homeMobile',             'pf_homeMobile');

			// online accounts
      pfShowOnlineAccounts("x4", "P", function(prefix, val0, val1, val2){TBL.createRow(prefix, null, {id: val0, fld_1: {mode: 10, value: val1, className: '_validate_ _url_ _canEmpty_'}, fld_2: {value: val2}});});

      // bio events
      pfShowBioEvents("x5", function(prefix, val0, val1, val2, val3){TBL.createRow(prefix, null, {id: val0, fld_1: {mode: 11, value: val1}, fld_2: {value: val2}, fld_3: {value: val3}});});

      // made
      if (($v('formTab') == "0") && ($v('formSubtab') == "6"))
        pfShowFavorites();

      // made
      if (($v('formTab') == "0") && ($v('formSubtab') == "7"))
        pfShowMades();

      // offer
      if (($v('formTab') == "0") && ($v('formSubtab') == "8"))
        pfShowOffers();

      // seek
      if (($v('formTab') == "0") && ($v('formSubtab') == "9"))
        pfShowSeeks();

			// contact
			fieldUpdate(user, 'icq', 'pf_icq', aclData);
			fieldUpdate(user, 'skype', 'pf_skype', aclData);
			fieldUpdate(user, 'yahoo', 'pf_yahoo', aclData);
			fieldUpdate(user, 'aim', 'pf_aim', aclData);
			fieldUpdate(user, 'msn', 'pf_msn', aclData);
      pfShowRows("x6", tagValue(user, "messaging"), ["\n", ";"], function(prefix, val1, val2){TBL.createRow(prefix, null, {fld_1: {value: val1}, fld_2: {value: val2, cssText: 'width: 220px;'}});});

      // business
			// main
			fieldUpdate(user, 'businessIndustry', 'pf_businessIndustry', aclData);
			fieldUpdate(user, 'businessOrganization', 'pf_businessOrganization', aclData);
      fieldUpdate(user, 'businessHomePage',       'pf_businessHomePage');
			fieldUpdate(user, 'businessJob', 'pf_businessJob', aclData);
			fieldUpdate(user, 'businessRegNo', 'pf_businessRegNo', aclData);
			fieldUpdate(user, 'businessCareer', 'pf_businessCareer', aclData);
			fieldUpdate(user, 'businessEmployees', 'pf_businessEmployees', aclData);
			fieldUpdate(user, 'businessVendor', 'pf_businessVendor', aclData);
			fieldUpdate(user, 'businessService', 'pf_businessService', aclData);
			fieldUpdate(user, 'businessOther', 'pf_businessOther', aclData);
			fieldUpdate(user, 'businessNetwork', 'pf_businessNetwork', aclData);
			fieldUpdate(user, 'businessResume', 'pf_businessResume', aclData);

      // address
			fieldUpdate(user, 'businessCountry', 'pf_businesscountry', aclData);
			updateState('pf_businesscountry', 'pf_businessstate', tagValue(user, 'businessState'));
		  fieldACLUpdate(aclData, 'pf_acl_businessState');
			fieldUpdate(user, 'businessCity', 'pf_businesscity', aclData);
			fieldUpdate(user, 'businessCode', 'pf_businesscode', aclData);
			fieldUpdate(user, 'businessAddress1', 'pf_businessaddress1', aclData);
			fieldUpdate(user, 'businessAddress2', 'pf_businessaddress2', aclData);
			fieldUpdate(user, 'businessTimezone', 'pf_businessTimezone', aclData);
			fieldUpdate(user, 'businessLatitude', 'pf_businesslat', aclData);
      fieldUpdate(user, 'businessLongitude',      'pf_businesslng');
			fieldUpdate(user, 'defaultMapLocation', 'pf_businessDefaultMapLocation');
			fieldUpdate(user, 'businessPhone', 'pf_businessPhone', aclData);
			fieldUpdate(user, 'businessPhoneExt', 'pf_businessPhoneExt');
      fieldUpdate(user, 'businessMobile',         'pf_businessMobile');

			// online accounts
      pfShowOnlineAccounts("y1", "B", function(prefix, val0, val1, val2){TBL.createRow(prefix, null, {id: val0, fld_1: {mode: 10, value: val1, className: '_validate_ _url_ _canEmpty_'}, fld_2: {value: val2}});});

			// contact
			fieldUpdate(user, 'businessIcq', 'pf_businessIcq', aclData);
			fieldUpdate(user, 'businessSkype', 'pf_businessSkype', aclData);
			fieldUpdate(user, 'businessYahoo', 'pf_businessYahoo', aclData);
			fieldUpdate(user, 'businessAim', 'pf_businessAim', aclData);
			fieldUpdate(user, 'businessMsn', 'pf_businessMsn', aclData);
      pfShowRows("y2", tagValue(user, "businessMessaging"), ["\n", ";"], function(prefix, val1, val2){TBL.createRow(prefix, null, {fld_1: {value: val1}, fld_2: {value: val2, cssText: 'width: 220px;'}});});

      // security
			fieldUpdate(user, 'securityOpenID', 'pf_securityOpenID');

			fieldUpdate(user, 'securitySecretQuestion', 'pf_securitySecretQuestion');
      fieldUpdate(user, 'securitySecretAnswer',   'pf_securitySecretAnswer');

      fieldUpdate(user, 'securitySiocLimit',      'pf_securitySiocLimit');

			fieldUpdate(user, 'certificate', 'pf_certificate');
			fieldUpdate(user, 'certificateLogin', 'pf_certificateLogin');
	    var S = tagValue(user, 'certificateSubject');
	    if (S) {
	      OAT.Dom.show('tr_certificateSubject');
	      OAT.Dom.show('span_certificateSubject');
	      $('span_certificateSubject').innerHTML = S;
	    } else {
	      OAT.Dom.hide('tr_certificateSubject');
	      OAT.Dom.hide('span_certificateSubject');
	      $('span_certificateSubject').innerHTML = '';
	    }
	    S = tagValue(user, 'certificateAgentID');
	    if (S) {
	      OAT.Dom.show('tr_certificateAgentID');
	      OAT.Dom.show('span_certificateAgentID');
	      $('span_certificateAgentID').innerHTML = S;
	    } else {
	      OAT.Dom.hide('tr_certificateAgentID');
	      OAT.Dom.hide('span_certificateAgentID');
	      $('span_certificateAgentID').innerHTML = '';
	    }
	    S = tagValue(user, 'certificate');
	    if (S) {
	      OAT.Dom.hide('iframe_certificate');
	      $('iframe_certificate').src = '';
	    } else {
	      OAT.Dom.show('iframe_certificate');
	      $('iframe_certificate').src = '/ods/cert.vsp?sid=' + encodeURIComponent($v('sid'));
	    }
      showTitle('profile');

      OAT.Dom.hide("lf");
      OAT.Dom.hide("uf");
      OAT.Dom.show("pf");
			pfTabInit('pf_tab_', $v('formTab'));
      pfTabInit('pf_tab_0_', $v('formSubtab'));
      pfTabInit('pf_tab_1_', $v('formSubtab'));
    }
  }
}

function encodeTableData(prefix, delimiters)
{
  var retValue = "";
  var form = document.forms[0];
  for (var i = 0; i < form.elements.length; i++)
  {
    if (!form.elements[i])
      continue;

    var ctrl = form.elements[i];
    if (typeof(ctrl.type) == 'undefined')
      continue;

    if (ctrl.name.indexOf(prefix+"_fld_1_") != 0)
      continue;

    var N = parseInt(ctrl.name.replace(prefix+"_fld_1_", ""));
    if (delimiters.length == 1)
    {
      if ($v(prefix+"_fld_1_"+N))
        retValue += $v(prefix+"_fld_1_"+N) + delimiters[0];
    }
    if (delimiters.length == 2)
    {
      if ($v(prefix+"_fld_1_"+N))
        retValue += $v(prefix+"_fld_1_"+N) + delimiters[1] + $v(prefix+"_fld_2_"+N) + delimiters[0];
    }
  }
  return retValue;
}

function updateOnlineAccounts(prefix, accountType)
{
	var S;
	S = '/ods/api/user.onlineAccounts.delete?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm')) + '&type=' + accountType;
	OAT.AJAX.GET(S,null,null,{async:false});
  var form = document.forms[0];
  for (var i = 0; i < form.elements.length; i++)
  {
    if (!form.elements[i])
      continue;

    var ctrl = form.elements[i];
    if (typeof(ctrl.type) == 'undefined')
      continue;

    if (ctrl.name.indexOf(prefix+"_fld_1_") != 0)
      continue;

    var N = parseInt(ctrl.name.replace(prefix+"_fld_1_", ""));
	  S = '/ods/api/user.onlineAccounts.new?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm')) + '&type=' + accountType +
	      '&name=' + encodeURIComponent($v(prefix+"_fld_1_"+N)) + '&url=' + encodeURIComponent($v(prefix+"_fld_2_"+N));
  	OAT.AJAX.GET(S,null,null,{async:false});
  }
}

function updateBioEvents(prefix)
{
	var S;
	S = '/ods/api/user.bioEvents.delete?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm'));
	OAT.AJAX.GET(S,null,null,{async:false});
  var form = document.forms[0];
  for (var i = 0; i < form.elements.length; i++)
  {
    if (!form.elements[i])
      continue;

    var ctrl = form.elements[i];
    if (typeof(ctrl.type) == 'undefined')
      continue;

    if (ctrl.name.indexOf(prefix+"_fld_1_") != 0)
      continue;

    var N = parseInt(ctrl.name.replace(prefix+"_fld_1_", ""));
	  S = '/ods/api/user.bioEvents.new?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm')) +
	      '&event=' + encodeURIComponent($v(prefix+"_fld_1_"+N)) + '&date=' + encodeURIComponent($v(prefix+"_fld_2_"+N)) + '&place=' + encodeURIComponent($v(prefix+"_fld_3_"+N));
	  OAT.AJAX.GET(S,null,null,{async:false});
  }
}

function prepareItems(prefix) {
  var ontologies = [];
  var form = $('page_form');
  for (var N = 0; N < form.elements.length; N++)
  {
    if (!form.elements[N])
      continue;

    var ctrl = form.elements[N];
    if (typeof(ctrl.type) == 'undefined')
      continue;

    if (ctrl.name.indexOf(prefix+"_fld_2_") != 0)
      continue;

    var ontologyNo = ctrl.name.replace(prefix+"_fld_2_", "");
    var ontologyName = ctrl.value;
    var ontologyItems = [];
    for (var M = 0; M < form.elements.length; M++)
    {
      if (!form.elements[M])
        continue;

      var ctrl = form.elements[M];
      if (typeof(ctrl.type) == 'undefined')
        continue;

      if (ctrl.name.indexOf(prefix+"_item_"+ontologyNo+"_fld_2_") != 0)
        continue;

      var itemNo = ctrl.name.replace(prefix+"_item_"+ontologyNo+"_fld_2_", "");
      var itemName = ctrl.value;
      var itemProperties = preparePropertiesWork(prefix, ontologyNo, itemNo);
      ontologyItems.push({"id": itemNo, "className": itemName, "properties": itemProperties});
    }
    ontologies.push(["ontology", ontologyName, "items", ontologyItems]);
  }
  return OAT.JSON.stringify(ontologies);
}

function prepareProperties(prefix) {
  return OAT.JSON.stringify(preparePropertiesWork(prefix, '0', '0'));
}

function preparePropertiesWork(prefix, ontologyNo, itemNo) {
  var form = $('page_form');
      var itemProperties = [];
      for (var L = 0; L < form.elements.length; L++)
      {
        if (!form.elements[L])
          continue;

        var ctrl = form.elements[L];
        if (typeof(ctrl.type) == 'undefined')
          continue;

        if (ctrl.name.indexOf(prefix+"_item_"+ontologyNo+"_prop_"+itemNo+"_fld_1_") != 0)
          continue;

        var propertyNo = ctrl.name.replace(prefix+"_item_"+ontologyNo+"_prop_"+itemNo+"_fld_1_", "");
        var propertyName = ctrl.value;
        var propertyValue = $v(prefix+"_item_"+ontologyNo+"_prop_"+itemNo+"_fld_2_"+propertyNo);
        var propertyType = $v(prefix+"_item_"+ontologyNo+"_prop_"+itemNo+"_fld_3_"+propertyNo);
        if (propertyType == 'object') {
          var item = RDF.getItemByName(propertyValue);
          if (item)
            propertyValue = item.id;
        }
        itemProperties.push({"name": propertyName, "value": propertyValue, "type": propertyType});
      }
  return itemProperties;
}

function pfUpdateSubmit(No) {
	$('pf_oldPassword').value = '';
	$('pf_newPassword').value = '';
	$('pf_newPassword2').value = '';

  var formTab = parseInt($v('formTab'));
  var formSubtab = parseInt($v('formSubtab'));
  if ((formTab == 0) && (formSubtab == 3))
  {
    updateOnlineAccounts('x4', 'P');
    ufProfileLoad(No);
  }
  else if ((formTab == 0) && (formSubtab == 5))
  {
    updateBioEvents('x5');
    ufProfileLoad(No);
  }
  else if ((formTab == 1) && (formSubtab == 2))
  {
    updateOnlineAccounts('y1', 'B');
    ufProfileLoad(No);
  }
  else
  {
    var A = '';
  	var S = '/ods/api/user.update.fields?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm'))
    if (formTab == 0)
    {
      if (formSubtab == 0)
      {
        // Import
        if ($v('cb_item_i_name') == '1')
          S += '&nickName=' + encodeURIComponent($v('i_nickName'));
        if ($v('cb_item_i_title') == '1')
          S += '&title=' + encodeURIComponent($v('i_title'));
        if ($v('cb_item_i_firstName') == '1')
          S += '&firstName=' + encodeURIComponent($v('i_firstName'));
        if ($v('cb_item_i_lastName') == '1')
          S += '&lastName=' + encodeURIComponent($v('i_lastName'));
        if ($v('cb_item_i_fullName') == '1')
          S += '&fullName=' + encodeURIComponent($v('i_fullName'));
        if ($v('cb_item_i_gender') == '1')
          S += '&gender=' + encodeURIComponent($v('i_gender'));
        if ($v('cb_item_i_mail') == '1')
          S += '&mail=' + encodeURIComponent($v('i_mail'));
        if ($v('cb_item_i_birthday') == '1')
          S += '&birthday=' + encodeURIComponent($v('i_birthday'));
        if ($v('cb_item_i_homepage') == '1')
          S += '&homepage=' + encodeURIComponent($v('i_homepage'));
        if ($v('cb_item_i_icq') == '1')
          S += '&icq=' + encodeURIComponent($v('i_icq'));
        if ($v('cb_item_i_aim') == '1')
          S += '&aim=' + encodeURIComponent($v('i_aim'));
        if ($v('cb_item_i_yahoo') == '1')
          S += '&yahoo=' + encodeURIComponent($v('i_yahoo'));
        if ($v('cb_item_i_msn') == '1')
          S += '&msn=' + encodeURIComponent($v('i_msn'));
        if ($v('cb_item_i_skype') == '1')
          S += '&skype=' + encodeURIComponent($v('i_skype'));
        if ($v('cb_item_i_homelat') == '1')
          S += '&homeLatitude=' + encodeURIComponent($v('i_homelat'));
        if ($v('cb_item_i_homelng') == '1')
          S += '&homeLongitude=' + encodeURIComponent($v('i_homelng'));
        if ($v('cb_item_i_homePhone') == '1')
          S += '&homePhone=' + encodeURIComponent($v('i_homePhone'));
        if ($v('cb_item_i_businessOrganization') == '1')
          S += '&businessOrganization=' + encodeURIComponent($v('i_businessOrganization'));
        if ($v('cb_item_i_businessHomePage') == '1')
          S += '&businessHomePage=' + encodeURIComponent($v('i_businessHomePage'));
        if ($v('cb_item_i_summary') == '1')
          S += '&summary=' + encodeURIComponent($v('i_summary'));
        if ($v('cb_item_i_tags') == '1')
          S += '&tags=' + encodeURIComponent($v('i_tags'));
        if ($v('cb_item_i_sameAs') == '1')
          S += '&webIDs=' + encodeURIComponent($v('i_sameAs'));
        if ($v('cb_item_i_interests') == '1')
          S += '&interests=' + encodeURIComponent($v('i_interests'));
        if ($v('cb_item_i_topicInterests') == '1')
          S += '&topicInterests=' + encodeURIComponent($v('i_topicInterests'));
        if ($v('cb_item_i_onlineAccounts') == '1')
          S += '&onlineAccounts=' + encodeURIComponent($v('i_onlineAccounts'));
      }
      if (formSubtab == 1)
      {
        S +='&nickName=' + encodeURIComponent($v('pf_nickName'))
        + '&mail=' + encodeURIComponent($v('pf_mail'))
        + '&title=' + encodeURIComponent($v('pf_title'))
        + '&firstName=' + encodeURIComponent($v('pf_firstName'))
        + '&lastName=' + encodeURIComponent($v('pf_lastName'))
        + '&fullName=' + encodeURIComponent($v('pf_fullName'))
        + '&gender=' + encodeURIComponent($v('pf_gender'))
        + '&birthday=' + encodeURIComponent($v('pf_birthday'))
        + '&homepage=' + encodeURIComponent($v('pf_homepage'))
        + '&mailSignature=' + encodeURIComponent($v('pf_mailSignature'))
          + '&summary=' + encodeURIComponent($v('pf_summary'))
        + '&appSetting=' + encodeURIComponent($v('pf_appSetting'))
        + '&webIDs=' + encodeTableData("x1", ["\n"])
        + '&interests=' + encodeTableData("x2", ["\n", ";"])
        + '&topicInterests=' + encodeTableData("x3", ["\n", ";"]);
        A +='title=' + $v('pf_acl_title')
          + '&firstName=' + $v('pf_acl_firstName')
          + '&lastName=' + $v('pf_acl_lastName')
          + '&fullName=' + $v('pf_acl_fullName')
          + '&gender=' + $v('pf_acl_gender')
          + '&birthday=' + $v('pf_acl_birthday')
          + '&mail=' + $v('pf_acl_mail')
          + '&homepage=' + $v('pf_acl_homepage')
          + '&summary=' + $v('pf_acl_summary')
          + '&webIDs=' +  $v('pf_acl_webIDs')
          + '&interests=' + $v('pf_acl_interests')
          + '&topicInterests=' + $v('pf_acl_topicInterests')
          + '&audio=' + $v('pf_acl_audio')
          + '&photo=' + $v('pf_acl_photo');
      }
      if (formSubtab == 2)
      {
        S +='&defaultMapLocation=' + encodeURIComponent($v('pf_homeDefaultMapLocation'))
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
  			  + '&homePhoneExt=' + encodeURIComponent($v('pf_homePhoneExt'))
  			+ '&homeMobile=' + encodeURIComponent($v('pf_homeMobile'));
        A +='&homeCountry=' + $v('pf_acl_homeCountry')
  			  + '&homeState=' + $v('pf_acl_homeState')
  			  + '&homeCity=' + $v('pf_acl_homeCity')
  			  + '&homeCode=' + $v('pf_acl_homeCode')
  			  + '&homeAddress1=' + $v('pf_acl_homeAddress1')
  			  + '&homeTimezone=' + $v('pf_acl_homeTimezone')
  			  + '&homeLatitude=' + $v('pf_acl_homeLatitude')
  			  + '&homePhone=' + $v('pf_acl_homePhone');
  	  }
      if (formSubtab == 4)
      {
        S +='&icq=' + encodeURIComponent($v('pf_icq'))
        + '&skype=' + encodeURIComponent($v('pf_skype'))
        + '&yahoo=' + encodeURIComponent($v('pf_yahoo'))
        + '&aim=' + encodeURIComponent($v('pf_aim'))
        + '&msn=' + encodeURIComponent($v('pf_msn'))
          + '&messaging=' + encodeTableData("x6", ["\n", ";"]);
        A +='&icq=' + $v('pf_acl_icq')
          + '&skype=' + $v('pf_acl_skype')
          + '&yahoo=' + $v('pf_acl_yahoo')
          + '&aim=' + $v('pf_acl_aim')
          + '&msn=' + $v('pf_acl_msn');
      }
    }
    else if (formTab == 1)
    {
      if (formSubtab == 0)
      {
        S +='&businessIndustry=' + encodeURIComponent($v('pf_businessIndustry'))
  			+ '&businessOrganization=' + encodeURIComponent($v('pf_businessOrganization'))
  			+ '&businessHomePage=' + encodeURIComponent($v('pf_businessHomePage'))
        + '&businessJob=' + encodeURIComponent($v('pf_businessJob'))
			+ '&businessRegNo=' + encodeURIComponent($v('pf_businessRegNo'))
			+ '&businessCareer=' + encodeURIComponent($v('pf_businessCareer'))
  			+ '&businessEmployees=' + encodeURIComponent($v('pf_businessEmployees'))
			+ '&businessVendor=' + encodeURIComponent($v('pf_businessVendor'))
  			+ '&businessService=' + encodeURIComponent($v('pf_businessService'))
        + '&businessOther=' + encodeURIComponent($v('pf_businessOther'))
        + '&businessNetwork=' + encodeURIComponent($v('pf_businessNetwork'))
        + '&businessResume=' + encodeURIComponent($v('pf_businessResume'));
        A +='&businessIndustry=' + $v('pf_acl_businessIndustry')
  			  + '&businessOrganization=' + $v('pf_acl_businessOrganization')
          + '&businessJob=' + $v('pf_acl_businessJob')
  			  + '&businessRegNo=' + $v('pf_acl_businessRegNo')
  			  + '&businessCareer=' + $v('pf_acl_businessCareer')
  			  + '&businessEmployees=' + $v('pf_acl_businessEmployees')
  			  + '&businessVendor=' + $v('pf_acl_businessVendor')
  			  + '&businessService=' + $v('pf_acl_businessService')
          + '&businessOther=' + $v('pf_acl_businessOther')
          + '&businessNetwork=' + $v('pf_acl_businessNetwork')
          + '&businessResume=' + $v('pf_acl_businessResume');
  	  }
      if (formSubtab == 1)
      {
        S +='&businessCountry=' + encodeURIComponent($v('pf_businesscountry'))
        + '&businessState=' + encodeURIComponent($v('pf_businessstate'))
        + '&businessCity=' + encodeURIComponent($v('pf_businesscity'))
        + '&businessCode=' + encodeURIComponent($v('pf_businesscode'))
        + '&businessAddress1=' + encodeURIComponent($v('pf_businessaddress1'))
  			+ '&businessAddress2=' + encodeURIComponent($v('pf_businessaddress2'))
  			+ '&businessTimezone=' + encodeURIComponent($v('pf_businessTimezone'))
  			+ '&businessLatitude=' + encodeURIComponent($v('pf_businesslat'))
  			+ '&businessLongitude=' + encodeURIComponent($v('pf_businesslng'))
  			+ '&businessPhone=' + encodeURIComponent($v('pf_businessPhone'))
  			  + '&businessPhoneExt=' + encodeURIComponent($v('pf_businessPhoneExt'))
  			+ '&businessMobile=' + encodeURIComponent($v('pf_businessMobile'));
        A +='&businessCountry=' + $v('pf_acl_businessCountry')
          + '&businessState=' + $v('pf_acl_businessState')
          + '&businessCity=' + $v('pf_acl_businessCity')
          + '&businessCode=' + $v('pf_acl_businessCode')
          + '&businessAddress1=' + $v('pf_acl_businessAddress1')
  			  + '&businessTimezone=' + $v('pf_acl_businessTimezone')
  			  + '&businessLatitude=' + $v('pf_acl_businesslat')
  			  + '&businessPhone=' + $v('pf_acl_businessPhone')
  	  }
      if (formSubtab == 3)
      {
        S +='&businessIcq=' + encodeURIComponent($v('pf_businessIcq'))
        + '&businessSkype=' + encodeURIComponent($v('pf_businessSkype'))
        + '&businessYahoo=' + encodeURIComponent($v('pf_businessYahoo'))
        + '&businessAim=' + encodeURIComponent($v('pf_businessAim'))
          + '&businessMsn=' + encodeURIComponent($v('pf_businessMsn'))
          + '&businessMessaging=' + encodeTableData("y2", ["\n", ";"]);
        A +='&businessIcq=' + $v('pf_acl_businessIcq')
          + '&businessSkype=' + $v('pf_acl_businessSkype')
          + '&businessYahoo=' + $v('pf_acl_businessYahoo')
          + '&businessAim=' + $v('pf_acl_businessAim')
          + '&businessMsn=' + $v('pf_acl_businessMsn');
      }
  	}
    else if (formTab == 2)
    {
      if (No == 31)
      {
        S += '&securityOpenID=' + encodeURIComponent($v('pf_securityOpenID'));
    	}
      else if (No == 32)
      {
        S += '&securityFacebookID=' + encodeURIComponent(facebookData.uid);
    	}
      else if (No == 33)
      {
        S += '&securityFacebookID=';
    	}
      else if (No == 34)
      {
        S += '&securitySiocLimit=' + encodeURIComponent($v('pf_securitySiocLimit'));
    	}
      else if (No == 35)
      {
        S += '&securitySecretQuestion=' + encodeURIComponent($v('pf_securitySecretQuestion')) +
             '&securitySecretAnswer=' + encodeURIComponent($v('pf_securitySecretAnswer'));
    	}
      else if (No == 36)
      {
        S += '&certificate=' + encodeURIComponent($v('pf_certificate')) +
    		     '&certificateLogin=' + encodeURIComponent($v('pf_certificateLogin'));
    	}
      else if (No == 37)
      {
        S += '&certificate=&certificateLogin=0';
    	}
  	}
  	if (A != '')
  	  OAT.AJAX.GET('/ods/api/user.acl.update?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm')) + '&acls=' + encodeURIComponent(A), false, null, {async: false});

  	OAT.AJAX.GET(S, '', function(data){ if((formTab == 0) && (formSubtab == 1)) {$('page_form').submit();}; pfUpdateCallback(data, No);});
  }
  return false;
}

function pfUpdateCallback(data, No) {
  var xml = OAT.Xml.createXmlDoc(data);
	if (!hasError(xml))
    ufProfileLoad(No);
  }

function pfChangeSubmit(event) {
	if ($v('pf_newPassword') != $v('pf_newPassword2')) {
    alert ('Bad new password. Please retype!');
  } else {
		var S = '/ods/api/user.password_change' +
		    '?sid=' + encodeURIComponent($v('sid')) +
		    '&realm=' + encodeURIComponent($v('realm')) +
		    '&old_password=' + encodeURIComponent($v('pf_oldPassword')) +
		    '&new_password=' + encodeURIComponent($v('pf_newPassword'));
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
		alert('The password was changed successfully.');
	}
}

function pfCancelSubmit() {
  showTitle('profile');

  OAT.Dom.hide("lf");
	OAT.Dom.hide("rf");
  OAT.Dom.show("uf");
  OAT.Dom.hide("pf");
  selectProfile()
	return false;
}

function pfCleanFOAFData() {
  $('pf_foaf').value = '';
  $('pf_foaf').defaultValue = '';
  $('cb_all').checked = false;
  $('cb_all').defaultChecked = false;
	$('i_tbody').innerHTML = '';
	OAT.Dom.hide('i_tbl');
}

function pfGetFOAFData(iri) {
	var S = '/ods/api/user.getFOAFData?foafIRI=' + encodeURIComponent(iri);
	var x = function(data) {
		var o = null;
		try {
			o = OAT.JSON.parse(data);
		} catch (e) {
			o = null;
		}
		if (o && o.iri) {
  	  OAT.Dom.show('i_tbl');
  	  var tbody = $('i_tbody');

			pfSetFOAFValue(tbody, o.iri,                  'Personal WebID',        'i_iri');
			pfSetFOAFValue(tbody, o.nick,                 'Nick Name',             'i_nickName');
			pfSetFOAFValue(tbody, o.title,                'Title',                 'i_title');
			pfSetFOAFValue(tbody, o.firstName,            'First Name',            'i_firstName');
			pfSetFOAFValue(tbody, o.family_name,          'Last Name',             'i_lastName');
			pfSetFOAFValue(tbody, o.name,                 'Full Name',             'i_fullName');
			pfSetFOAFValue(tbody, o.gender,               'Gender',                'i_gender');
			pfSetFOAFValue(tbody, o.mbox,                 'E-mail',                'i_mail');
			pfSetFOAFValue(tbody, o.birthday,             'Birthday',              'i_birthday');
			pfSetFOAFValue(tbody, o.homepage,             'Personal Webpage',      'i_homepage');
			pfSetFOAFValue(tbody, o.icqChatID,            'Icq',                   'i_icq');
			pfSetFOAFValue(tbody, o.skypeChatID,          'Skype ID',              'i_skype');
			pfSetFOAFValue(tbody, o.aimChatID,            'AIM Name',              'i_aim');
			pfSetFOAFValue(tbody, o.yahooChatID,          'Yahoo! ID',             'i_yahoo');
			pfSetFOAFValue(tbody, o.msnChatID,            'MSN Messenger',         'i_msn');
			pfSetFOAFValue(tbody, o.phone,                'Phone',                 'i_homePhone');
			pfSetFOAFValue(tbody, o.lat,                  'Latitude',              'i_homelat');
			pfSetFOAFValue(tbody, o.lng,                  'Longitude',             'i_homelng');
			pfSetFOAFValue(tbody, o.organizationTitle,    'Organization',          'i_businessOrganization');
			pfSetFOAFValue(tbody, o.organizationHomepage, 'Organization Homepage', 'i_businessHomePage');
			pfSetFOAFValue(tbody, o.resume,               'Resume',                       'i_summary');
			pfSetFOAFValue(tbody, o.tags,                 'Tags',                  'i_tags');
			pfSetFOAFValue(tbody, o.sameAs,               'Other Personal URIs (WebIDs)', 'i_sameAs', ['URI'], ['\n']);
			pfSetFOAFValue(tbody, o.interest,             'Topic of Interest',     'i_interests', ['URL', 'Label'], ['\n', ';']);
			pfSetFOAFValue(tbody, o.topic_interest,       'Thing of Interest',     'i_topicInterests', ['URI', 'Label'], ['\n', ';']);
			pfSetFOAFValue(tbody, o.onlineAccounts,       'Online Accounts',              'i_onlineAccounts', ['Label', 'URI'], ['\n', ';']);
		} else {
			alert('No data founded for \'' + iri + '\'');
		}
	}
	$('i_tbody').innerHTML = '';
	OAT.Dom.hide('i_tbl');
	OAT.AJAX.GET(S, '', x, {
		onstart : function() {
			OAT.Dom.show('pf_import_image')
		},
		onend : function() {
			OAT.Dom.hide('pf_import_image')
		}
	});
}

function pfSetFOAFValue(tbody, fValue, fTitle, fName, fHeaders, fDelimiters) {
  if (fValue) {
    var tr = OAT.Dom.create('tr');
    tbody.appendChild(tr);

    var td = OAT.Dom.create('td');
    td.vAlign = 'top';
    var fld = OAT.Dom.create('input');
    fld.type = 'checkbox';
    fld.id = 'cb_item_'+fName;
    fld.name = fld.id;
    fld.value = '1';
    td.appendChild(fld);
    tr.appendChild(td);

    var td = OAT.Dom.create('td');
    td.vAlign = 'top';
    td.appendChild(OAT.Dom.text(fTitle));
    tr.appendChild(td);

    var td = OAT.Dom.create('td');
    td.vAlign = 'top';
    if (fHeaders) {
      var tbl = OAT.Dom.create('table');
      tbl.id = fName+'_tbl';
      tbl.className = 'listing';
      td.appendChild(tbl);
      var thead = OAT.Dom.create('thead');
      tbl.appendChild(thead);
      var trx = OAT.Dom.create('tr');
      trx.className = 'listing_header_row';
      thead.appendChild(trx);
    	for ( var N = 0; N < fHeaders.length; N++) {
        var thx = OAT.Dom.create('th');
        thx.appendChild(OAT.Dom.text(fHeaders[N]));
        trx.appendChild(thx);
      }
    	var lines = fValue.split(fDelimiters[0]);
    	for ( var N = 0; N < lines.length; N++) {
    	  if (lines[N] != '') {
    	    var V;
      		if (fDelimiters.length == 1) {
      			V = [lines[N]];
      		} else {
      			V = lines[N].split(fDelimiters[1]);
      		}
          var trx = OAT.Dom.create('tr');
          tbl.appendChild(trx);
        	for ( var M = 0; M < V.length; M++) {
            var tdx = OAT.Dom.create('td');
            tdx.appendChild(OAT.Dom.text(V[M]));
            trx.appendChild(tdx);
          }
      	}
    	}
    } else {
      td.appendChild(OAT.Dom.text(fValue));
    }
    var fld = OAT.Dom.create('input');
    fld.type = 'hidden';
    fld.id = fName;
    fld.name = fld.id;
    fld.value = fValue;
    td.appendChild(fld);
    tr.appendChild(td);
  }
}

function setDefaultMapLocation(from, to) {
  $('pf_' + to + 'DefaultMapLocation').checked = $('pf_' + from + 'DefaultMapLocation').checked;
}

function setSecretQuestion() {
  var S = $("pf_secretQuestion_select");
  var V = S[S.selectedIndex].value;

  $("pf_secretQuestion").value = V;
}

// ------------------------------------------

function lfRegisterSubmit(event) {
  $('sid').value = '';
  $('realm').value = '';

  showTitle('register');

  OAT.Dom.hide("ob_right_logout");
  OAT.Dom.hide("ob_links");

  OAT.Dom.hide("lf");
  OAT.Dom.show("rf");

  rfResetData();
  if (document.location.protocol == 'https:')
  rfSSLAutomaticLogin();

  return false;
}

function rfResetData() {
  $('rf_uid').value = '';
  $('rf_email').value = '';
  $('rf_password').value = '';
  $('rf_password2').value = '';
  $('rf_openId').value = '';
  $('rf_is_agreed').checked = false;
  if ($('tr_rf_openid_uid'))
    $('tr_rf_openid_uid').value = '';
  if ($('rf_openid_email'))
    $('tr_rf_openid_email').value = '';
  if ($('tr_rf_webid_uid'))
    $('tr_rf_webid_uid').value = '';
  if ($('rf_webid_email'))
    $('tr_rf_webid_email').value = '';
}

function rfSSLAutomaticLogin() {
  if (regData.sslAutomaticEnable && !$("rf_webid_uid") && !$("rf_webid_email")) {
    $('rf_is_agreed').checked = true;
    rfTab.go(3);
    rfSignupSubmit();
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
		if (!facebookData || !facebookData.uid)
			return showError('Invalid Facebook UserID');
	} else if (rfTab.selectedIndex == 3) {
		if (!sslData || !sslData.iri)
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
	  openIdAuthenticate('rf');
		return false;
	}
    q += '&data=' + encodeURIComponent($v('oid-data'));
    if ($('rf_openid_uid'))
      q +='&name=' + encodeURIComponent($v('rf_openid_uid'));
    if ($('rf_openid_email'))
      q +='&email=' + encodeURIComponent($v('rf_openid_email'));
  }
	else if (rfTab.selectedIndex == 2) {
		q += '&data=' + encodeURIComponent(OAT.JSON.stringify(facebookData))
	}
	else if (rfTab.selectedIndex == 3) {
		q +='&data=' + encodeURIComponent(OAT.JSON.stringify(sslData));
		if ($('rf_webid_uid'))
		  q +='&name=' + encodeURIComponent($v('rf_webid_uid'));
		if ($('rf_webid_email'))
		  q +='&email=' + encodeURIComponent($v('rf_webid_email'));
	}
	OAT.AJAX.POST("/ods/api/user.register", q, afterSignup);
	return false;
}

function afterSignup(data) {
 	var xml = OAT.Xml.createXmlDoc(data);
	if (!hasError(xml)) {
    rfResetData();
    afterLogin(data, 'rf');
  }
}

function openIdLoginURL(uriParams) {
  var openIdServer       = uriParams['oid-srv'];
  var openIdSig          = uriParams['openid.sig'];
  var openIdIdentity     = uriParams['openid.identity'];
  var openIdAssoc_handle = uriParams['openid.assoc_handle'];
  var openIdSigned       = uriParams['openid.signed'];

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
        url += '&openid.' + _key + '=' + encodeURIComponent (_val);
    }
  }
  return '&openIdUrl=' + encodeURIComponent (url) + '&openIdIdentity=' + encodeURIComponent (openIdIdentity);
}

function openIdAuthenticate(prefix) {
  var q = 'openIdUrl=' + encodeURIComponent($v(prefix+'_openId'));
  var x = function (data) {
    var xml = OAT.Xml.createXmlDoc(data);
    var error = OAT.Xml.xpath (xml, '//error_response', {});
    if (error.length)
      showError('Invalied OpenID Server');

    var oidVersion = OAT.Xml.textValue (OAT.Xml.xpath (xml, '/openIdServer_response/version', {})[0]);
    var oidServer = OAT.Xml.textValue (OAT.Xml.xpath (xml, '/openIdServer_response/server', {})[0]);
    var oidDelegate = OAT.Xml.textValue (OAT.Xml.xpath (xml, '/openIdServer_response/delegate', {})[0]);

    if (!(oidServer && oidServer.length > 0))
      showError(' Cannot locate OpenID server');

    var oidIdent = $v(prefix+'_openId');
    if (oidDelegate && oidDelegate.length > 0)
      oidIdent = oidDelegate;

    var thisPage  = document.location.protocol +
      '//' +
      document.location.host +
      document.location.pathname +
      '?oid-form=' + prefix +
      '&oid-srv=' + encodeURIComponent (oidServer);

    var trustRoot = document.location.protocol + '//' + document.location.host;

    var S = oidServer +
      '?openid.mode=checkid_setup' +
      '&openid.return_to=' + encodeURIComponent(thisPage);

    if (oidVersion == '1.0')
      S +='&openid.identity=' + encodeURIComponent(oidIdent)
        + '&openid.trust_root=' + encodeURIComponent(trustRoot);

    if (oidVersion == '2.0')
      S +='&openid.ns=' + encodeURIComponent('http://specs.openid.net/auth/2.0')
        + '&openid.claimed_id=' + encodeURIComponent('http://specs.openid.net/auth/2.0/identifier_select')
        + '&openid.identity=' + encodeURIComponent('http://specs.openid.net/auth/2.0/identifier_select')

    if (prefix == 'rf') {
      if (oidVersion == '1.0')
      S += '&openid.sreg.optional='+encodeURIComponent('fullname,nickname,dob,gender,postcode,country,timezone') + '&openid.sreg.required=' + encodeURIComponent('email,nickname');
      if (oidVersion == '2.0')
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
    }
    document.location = S;
  };
  OAT.AJAX.POST ("/ods_services/Http/openIdServer", q, x);
}

function showError(msg) {
	alert(msg);
	return false;
}

function showTitle(txt) {
	var T = $('ob_left');
	if (T)
  {
    if ((txt == 'user') || (txt == 'profile')) {
      OAT.Dom.show(T);
    } else {
      OAT.Dom.hide(T);
    }
  }
}
