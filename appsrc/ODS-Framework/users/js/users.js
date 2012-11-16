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

function widgetToggle(elm) {
  var _divs = elm.parentNode.parentNode.parentNode.getElementsByTagName ('div');
  for (var i = 0; i < _divs.length; i++) {
    if (_divs[i].className == 'w_content') {
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
var lfNotReturn = true;
var rfTab;
var ufTab;
var pfPages = [['pf_page_0_0', 'pf_page_0_1', 'pf_page_0_2', 'pf_page_0_3', 'pf_page_0_4', 'pf_page_0_5', 'pf_page_0_6', 'pf_page_0_7', 'pf_page_0_8', 'pf_page_0_9', 'pf_page_0_10'], ['pf_page_1_0', 'pf_page_1_1', 'pf_page_1_2', 'pf_page_1_3'], ['pf_page_2_0', 'pf_page_2_1', 'pf_page_2_2', 'pf_page_2_3', 'pf_page_2_4', 'pf_page_2_5', 'pf_page_2_6']];

var setupWin;
var cRDF;

var regData;
var userData;
var sslData;
var aclData;
var facebookData;
var sslLinks = {"in": [], "up": []};
var validateSession = false;

// init
function init()
{
	OAT.Preferences.imagePath = "/ods/images/oat/";
	OAT.Preferences.stylePath = "/ods/oat/styles/";
	OAT.Preferences.showAjax = false;

  var x = function (data) {
    try {
      regData = OAT.JSON.parse(data);
    } catch (e) { regData = {}; }
  }
  OAT.AJAX.GET ('/ods/api/server.getInfo?info=regData', false, x, {async: false});

  var uriParams = OAT.Dom.uriParams();
  var startForm;
  if (typeof (uriParams['sid']) != 'undefined' && uriParams['sid'] != '') {
    $('sid').value = uriParams['sid'];
    var S = '/ods/api/user.validate?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm'));
    var x = function (data) {
      var xml = OAT.Xml.createXmlDoc(data);
      if (!hasError(xml, false)) {
        validateSession = true;
      }
    }
    OAT.AJAX.GET (S, false, x, {async: false});
  }
	if ($("lf")) {
    lfTab = new OAT.Tab("lf_content", {goCallback: lfCallback});
		lfTab.add("lf_tab_0", "lf_page_0");
		lfTab.add("lf_tab_1", "lf_page_1");
		lfTab.add("lf_tab_2", "lf_page_2");
		lfTab.add("lf_tab_3", "lf_page_3");
    lfTab.add("lf_tab_4", "lf_page_4");
    lfTab.add("lf_tab_5", "lf_page_5");
    var N = null;
    if (regData.login) {
      if (N == null) N = 0;
      OAT.Dom.show('lf_tab_0');
    }
    if (regData.loginSslEnable) {
      if (N == null) N = 3;
      OAT.Dom.show('lf_tab_3');
    }
    if (regData.loginOpenidEnable) {
      if (N == null) N = 1;
      OAT.Dom.show('lf_tab_1');
    }
    if (regData.loginTwitterEnable) {
      if (N == null) N = 4;
      OAT.Dom.show('lf_tab_4');
    }
    if (regData.loginLinkedinEnable) {
      if (N == null) N = 5;
      OAT.Dom.show('lf_tab_5');
    }
    if (N != null) {
      lfTab.go(N);
    } else {
      lfTab.add("lf_tab_6", "lf_page_6");
    }
    if (uriParams['oid-form'] == 'lf') {
      startForm = 'lf';
      OAT.Dom.show('lf');
      OAT.Dom.hide('rf');
      if (uriParams['oid-mode'] == 'twitter') {
        lfTab.go(4);
        lfNotReturn = false;
        loginSubmit(4, 'lf');
      }
      else if (uriParams['oid-mode'] == 'linkedin') {
        lfTab.go(5);
        lfNotReturn = false;
        loginSubmit(5, 'lf');
      }
      else if (typeof (uriParams['openid.signed']) != 'undefined' && uriParams['openid.signed'] != '') {
      lfTab.go(1);
        $('lf_openId').value = uriParams['openid.identity'];
        loginSubmit(1, 'lf');
      }
				}
	}
	if ($("rf")) {
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
    if (uriParams['oid-form'] == 'rf') {
      startForm = 'rf';
      OAT.Dom.hide('lf');
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
            addProfileRowInput(tbl, 'Login Name', 'rf_uid_4', {width: '150px', value: tagValue(user, 'screen_name')});
            addProfileRowInput(tbl, 'E-Mail', 'rf_email_4', {width: '300px'});
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
      else if (uriParams['oid-mode'] == 'linkedin')
      {
        rfTab.go(5);
        $('rf_is_agreed').checked = true;
        var x = function (data) {
          var xml = OAT.Xml.createXmlDoc(data);
          var user = xml.getElementsByTagName('person')[0];
          if (user && user.getElementsByTagName('id')[0]) {
            hiddenCreate('linkedin-data', null, data);
            var tbl = $('rf_table_5');
            addProfileRowInput(tbl, 'Login Name', 'rf_uid_5', {width: '150px', value: OAT.Xml.textValue(user.getElementsByTagName('first-name')[0])});
            addProfileRowInput(tbl, 'E-Mail', 'rf_email_5', {width: '300px'});
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
      else
      {
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
          hiddenCreate('oid-data', null, OAT.JSON.stringify(data));

          var tbl = $('rf_table_1');
          addProfileRowInput(tbl, 'Login Name', 'rf_uid_1', {value: data['nick'], width: '150px'});
          addProfileRowInput(tbl, 'E-Mail', 'rf_email_1', {value: data['mbox'], width: '300px'});
          if (data['name'])
            addProfileRowValue(tbl, 'Full Name', data['name']);
          rfCheckUpdate(1);
      }
      else if (typeof (uriParams['openid.mode']) != 'undefined' && uriParams['openid.mode'] == 'cancel')
      {
        alert('OpenID Authentication Failed');
				}
      }
			}
		}
	if (($v('mode') == 'html') && typeof (uriParams['form']) != 'undefined' && uriParams['form'] == 'register')
    lfRegisterSubmit(null, true);

  if (($("lf") && regData.loginSslEnable) || ($("rf") && regData.sslEnable)) {
		var x = function(data) {
		  var x2 = function(prefix) {
		  	OAT.Dom.show(prefix+"_tab_3");
				var tbl = $(prefix+'_table_3');
				if (tbl) {
          OAT.Dom.unlink(prefix+'_table_3_throbber');
          if ((prefix == "lf") && regData.loginSslEnable) {
            if (sslData.certFilterCheck == '1') {
					addProfileRowValue(tbl, 'WebID', sslData.iri);
          if (sslData.depiction)
            addProfileRowImage(tbl, 'Photo', sslData.depiction);

              if (sslData.loginName)
            addProfileRowValue(tbl, 'Login Name', sslData.loginName);

              if (sslData.mbox)
            addProfileRowValue(tbl, 'E-Mail', sslData.mbox);

					if (sslData.firstName)
						addProfileRowValue(tbl, 'First Name', sslData.firstName);

					if (sslData.family_name)
						addProfileRowValue(tbl, 'Family Name', sslData.family_name);

            if (!sslData.certLogin) {
              var td = addProfileRowText(tbl, 'Sign up for an ODS account using your existing WebID - ', 'font-weight: bold;');
              addProfileRowButton2(td, 'sign_up_1');
              }
            lfTab.go(3);
            } else {
              addProfileRowText(tbl, 'You must have cerificate with WebID to use this option', 'font-weight: bold;', 17);
              if ((document.location.protocol == 'http:') || !sslData.certLogin)
                $('lf_login').disabled = true;
            }
          }
          else if ((prefix == "rf") && regData.sslEnable)
          {
            if (!sslData.certFilterCheck) {
              addProfileRowText(tbl, 'Sign up for an ODS account using another WebID', 'font-weight: bold;');
              $('rf_signup').disabled = true;
            } else {
              addProfileRowValue(tbl, 'WebID', sslData.iri);
              if (sslData.depiction)
                addProfileRowImage(tbl, 'Photo', sslData.depiction);

              if (!sslData.certLogin)
                addProfileRowInput(tbl, 'Login Name', 'rf_uid_3', {value: sslData.loginName, width: '150px'});

              if (sslData.mbox && sslData.certLogin)
                addProfileRowValue(tbl, 'E-Mail', sslData.mbox);

              if (!sslData.certLogin)
                addProfileRowInput(tbl, 'E-Mail', 'rf_email_3', {value: sslData.mbox, width: '300px'});

              if (sslData.firstName)
                addProfileRowValue(tbl, 'First Name', sslData.firstName);

              if (sslData.family_name)
                addProfileRowValue(tbl, 'Family Name', sslData.family_name);

            if (sslData.certLogin) {
              var td = addProfileRowText(tbl, 'You have registered WebID. You can sign in with it! - ', 'font-weight: bold; ');
              addProfileRowButton(td, 'sign_in_1');
              }
              rfCheckUpdate(3);
            rfTab.go(3);
            }
          }
			  }
		  }

			try {
				sslData = OAT.JSON.parse(data);
			} catch (e) {
				sslData = null;
			}
			if (sslData && sslData.iri) {
			  x2('lf');
			  x2('rf');
			}
		}
    if (document.location.protocol == 'https:') {
		OAT.AJAX.GET('/ods/api/user.getFOAFSSLData?sslFOAFCheck=1', '', x);
    } else {
      OAT.Dom.show('lf_tab_3');
      var tbl = $('lf_table_3');
      if (tbl) {
        OAT.Dom.unlink('lf_table_3_throbber');
        var td = addProfileRowText(tbl, 'Have you registered WebID? Sign in with it - ', 'font-weight: bold;');
        addProfileRowButton(td, 'sign_in_2');
        var td2 = addProfileRowText(tbl, 'Sign up for an ODS account using your existing WebID - ', 'font-weight: bold;');
        addProfileRowButton2(td2, 'sign_up_2');
      }
      OAT.Dom.show('rf_tab_3');
      var tbl = $('rf_table_3');
      if (tbl) {
        OAT.Dom.unlink('rf_table_3_throbber');
        var td3 = addProfileRowText(tbl, 'Sign up for an ODS account using your existing WebID - ', 'font-weight: bold;');
        addProfileRowButton2(td3, 'sign_up_3');
      }
    }
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
        a.id = 'span_ssl';
        a.href = 'https://' + document.location.hostname + ((o.sslPort != '443')? ':' + o.sslPort: '') + document.location.pathname;

        var img = OAT.Dom.image('/ods/images/icons/lock_16.png');
        img.border = 0;
        img.alt = 'ODS Users SSL Link';

        OAT.Dom.append([a, img], ['ob_right', a]);

        var links = sslLinks['in'];
        for (var i = 0; i < links.length; i++)
          links[i].href = a.href;

        var links = sslLinks['up'];
        for (var i = 0; i < links.length; i++)
          links[i].href = a.href + '?form=register';
      }
    }
    OAT.AJAX.GET ('/ods/api/server.getInfo?info=sslPort', false, x);
  }
	if ($('pf')) {
	  var obj = $('formTab');
    if (!obj) {hiddenCreate('formTab2', null, '0');}
    var obj = $('formTab2');
    if (!obj) {hiddenCreate('formTab2', null, '0');}
    var obj = $('formTab3');
    if (!obj) {hiddenCreate('formTab3', null, '0');}

    OAT.Event.attach("pf_tab_0", 'click', function(){pfTabSelect('pf_tab_', 0);});
    OAT.Event.attach("pf_tab_1", 'click', function(){pfTabSelect('pf_tab_', 1);});
    OAT.Event.attach("pf_tab_2", 'click', function(){pfTabSelect('pf_tab_', 2);});
    pfTabInit('pf_tab_', $v('formTab'));

    OAT.Event.attach("pf_tab_0_0", 'click', function(){pfTabSelect('pf_tab_0_', 0, 0);});
    OAT.Event.attach("pf_tab_0_1", 'click', function(){pfTabSelect('pf_tab_0_', 0, 1);});
    OAT.Event.attach("pf_tab_0_2", 'click', function(){pfTabSelect('pf_tab_0_', 0, 2);});
    OAT.Event.attach("pf_tab_0_3", 'click', function(){pfTabSelect('pf_tab_0_', 0, 3);});
    OAT.Event.attach("pf_tab_0_4", 'click', function(){pfTabSelect('pf_tab_0_', 0, 4);});
    OAT.Event.attach("pf_tab_0_5", 'click', function(){pfTabSelect('pf_tab_0_', 0, 5);});
    OAT.Event.attach("pf_tab_0_6", 'click',  function(){pfTabSelect('pf_tab_0_', 0, 6);});
    OAT.Event.attach("pf_tab_0_7", 'click',  function(){pfTabSelect('pf_tab_0_', 0, 7);});
    OAT.Event.attach("pf_tab_0_8", 'click',  function(){pfTabSelect('pf_tab_0_', 0, 8);});
    OAT.Event.attach("pf_tab_0_9", 'click',  function(){pfTabSelect('pf_tab_0_', 0, 9);});
    OAT.Event.attach("pf_tab_0_10", 'click', function(){pfTabSelect('pf_tab_0_', 0, 10);});
    OAT.Event.attach("pf_tab_0_11", 'click', function(){pfTabSelect('pf_tab_0_', 0, 11);});
    OAT.Event.attach("pf_tab_0_12", 'click', function(){pfTabSelect('pf_tab_0_', 0, 12);});
    pfTabInit('pf_tab_0_', $v('formTab2'));
    swapRows($v('formTab2'));

    OAT.Event.attach("pf_tab_1_0", 'click', function(){pfTabSelect('pf_tab_1_', 1, 0);});
    OAT.Event.attach("pf_tab_1_1", 'click', function(){pfTabSelect('pf_tab_1_', 1, 1);});
    OAT.Event.attach("pf_tab_1_2", 'click', function(){pfTabSelect('pf_tab_1_', 1, 2);});
    OAT.Event.attach("pf_tab_1_3", 'click', function(){pfTabSelect('pf_tab_1_', 1, 3);});
    pfTabInit('pf_tab_1_', $v('formTab2'));

    OAT.Event.attach("pf_tab_2_0", 'click', function(){pfTabSelect('pf_tab_2_', 2, 0);});
    OAT.Event.attach("pf_tab_2_1", 'click', function(){pfTabSelect('pf_tab_2_', 2, 1);});
    OAT.Event.attach("pf_tab_2_2", 'click', function(){pfTabSelect('pf_tab_2_', 2, 2);});
    OAT.Event.attach("pf_tab_2_3", 'click', function(){pfTabSelect('pf_tab_2_', 2, 3);});
    // pf_tab_2_4
    ufCertificateGenerator();
    OAT.Event.attach("pf_tab_2_5", 'click', function(){pfTabSelect('pf_tab_2_', 2, 5);});

    pfTabInit('pf_tab_2_', $v('formTab2'));
	}
    var userName;
  if (!startForm) {
    if (typeof (uriParams['userName']) != 'undefined' && uriParams['userName'] != '')
      userName = uriParams['userName'];

    if (!userName) {
      var path = document.location.pathname.split('/');
      if (path.length > 3) {
        var tmp = path[3];
        if (tmp.indexOf('~') == 0)
          userName = tmp.substring(1);
      }
    }

    if (validateSession || userName)
      selectProfile(userName);
  }
	if ($v('mode') == 'html') {
	  var host = document.location.protocol + '//' + document.location.host;
    $('hostTag_1').href = host + $('hostTag_1').getAttribute("href");
    $('hostTag_2').href = host + $('hostTag_2').getAttribute("href");

    if (userName) {
      // add link & meta tags
      var S =
        '<link id="userTag_1"  rel="meta" type="application/rdf+xml" title="SIOC" href="[HOST]/dataspace/[USER]/sioc.rdf" />\n' +
        '<link id="userTag_2"  rel="meta" type="application/rdf+xml" title="FOAF" href="[HOST]/dataspace/person/[USER]/foaf.rdf" />\n' +
        '<link id="userTag_3"  rel="meta" type="text/rdf+n3" title="FOAF" href="[HOST]/dataspace/person/[USER]/foaf.n3" />\n' +
        '<link id="userTag_4"  rel="meta" type="application/json" title="FOAF" href="[HOST]/dataspace/person/[USER]/foaf.json" />\n' +
        '<link id="userTag_5"  rel="http://xmlns.com/foaf/0.1/primaryTopic"  title="About" href="[HOST]/dataspace/person/[USER]#this" />\n' +
        '<link id="userTag_6"  rel="schema.dc" href="http://purl.org/dc/elements/1.1/" />\n' +
        '<meta id="userTag_7"  name="dc.language" content="en" scheme="rfc1766" />\n' +
        '<meta id="userTag_8"  name="dc.creator" content="[USER]" />\n' +
        '<meta id="userTag_9"  name="dc.description" content="ODS HTML [USER]s page" />\n' +
        '<meta id="userTag_10" name="dc.title" content="ODS HTML [USER]s page" />\n' +
        '<link id="userTag_11" rev="describedby" title="About" href="[HOST]/dataspace/person/[USER]#this" />\n' +
        '<link id="userTag_12" rel="schema.geo" href="http://www.w3.org/2003/01/geo/wgs84_pos#" />\n' +
        '<meta id="userTag_13" http-equiv="X-XRDS-Location" content="[HOST]/dataspace/[USER]/yadis.xrds" />\n' +
        '<meta id="userTag_14" http-equiv="X-YADIS-Location" content="[HOST]/dataspace/[USER]/yadis.xrds" />\n' +
        '<link id="userTag_15" rel="meta" type="application/xml+apml" title="APML 0.6" href="[HOST]/dataspace/[USER]/apml.xml" />\n' +
        '<link id="userTag_16" rel="alternate" type="application/atom+xml" title="OpenSocial Friends" href="[HOST]/feeds/people/[USER]/friends" />';
      S = S.replace ('[HOST]', host);
      S = S.replace ('[USER]', userName);
      var tag_1  = OAT.Dom.create('link', {id: 'userTag_1',  rel: 'meta', type: 'application/rdf+xml', title: 'SIOC', href: userHref('[HOST]/dataspace/[USER]/sioc.rdf', host, userName)});
      var tag_2  = OAT.Dom.create('link', {id: 'userTag_2',  rel: 'meta', type: 'application/rdf+xml', title: 'FOAF', href: userHref('[HOST]/dataspace/person/[USER]/foaf.rdf', host, userName)});
      var tag_3  = OAT.Dom.create('link', {id: 'userTag_3',  rel: 'meta', type: 'text/rdf+n3', title: 'FOAF', href: userHref('[HOST]/dataspace/person/[USER]/foaf.n3', host, userName)});
      var tag_4  = OAT.Dom.create('link', {id: 'userTag_4',  rel: 'meta', type: 'application/json', title: 'FOAF', href: userHref('[HOST]/dataspace/person/[USER]/foaf.json', host, userName)});
      var tag_5  = OAT.Dom.create('link', {id: 'userTag_5',  rel: 'http://xmlns.com/foaf/0.1/primaryTopic', title: 'About', href: userHref('[HOST]/dataspace/person/[USER]#this', host, userName)});
      var tag_6  = OAT.Dom.create('link', {id: 'userTag_6',  rel: 'schema.dc', href: userHref('http://purl.org/dc/elements/1.1/', host, userName)});
      var tag_7  = OAT.Dom.create('meta', {id: 'userTag_7',  name: 'dc.language', content: 'en', scheme: 'rfc1766'});
      var tag_8  = OAT.Dom.create('meta', {id: 'userTag_8',  name: 'dc.creator', content: userHref('[USER]', host, userName)});
      var tag_9  = OAT.Dom.create('meta', {id: 'userTag_9',  name: 'dc.description', content: userHref('ODS HTML [USER]\'s page', host, userName)});
      var tag_10 = OAT.Dom.create('meta', {id: 'userTag_10', name: 'dc.title', content: userHref('ODS HTML [USER]\'s page', host, userName)});
      var tag_11 = OAT.Dom.create('link', {id: 'userTag_11', rev: 'describedby', title: 'About', href: userHref('[HOST]/dataspace/person/[USER]#this', host, userName)});
      var tag_12 = OAT.Dom.create('link', {id: 'userTag_12', rel: 'schema.geo', href: userHref('http://www.w3.org/2003/01/geo/wgs84_pos#', host, userName)});
      var tag_13 = OAT.Dom.create('meta', {id: 'userTag_13', "http-equiv": 'X-XRDS-Location', content: userHref('[HOST]/dataspace/[USER]/yadis.xrds', host, userName)});
      var tag_14 = OAT.Dom.create('meta', {id: 'userTag_14', "http-equiv": 'X-YADIS-Location', content: userHref('[HOST]/dataspace/[USER]/yadis.xrds', host, userName)});
      var tag_15 = OAT.Dom.create('link', {id: 'userTag_15', rel: 'meta', type: 'application/xml+apml', title: 'APML 0.6', href: userHref('[HOST]/dataspace/[USER]/apml.xml', host, userName)});
      var tag_16 = OAT.Dom.create('link', {id: 'userTag_16', rel: 'alternate', type: 'application/atom+xml', title: 'OpenSocial Friends', href: userHref('[HOST]/feeds/people/[USER]/friends', host, userName)});
      $('hostTag_2').parentNode.insertBefore(tag_1, $('hostTag_2').nextSibling);
      tag_1.parentNode.insertBefore (tag_2 , tag_1.nextSibling);
      tag_2.parentNode.insertBefore (tag_3 , tag_1.nextSibling);
      tag_3.parentNode.insertBefore (tag_4 , tag_1.nextSibling);
      tag_4.parentNode.insertBefore (tag_5 , tag_1.nextSibling);
      tag_5.parentNode.insertBefore (tag_6 , tag_1.nextSibling);
      tag_6.parentNode.insertBefore (tag_7 , tag_1.nextSibling);
      tag_7.parentNode.insertBefore (tag_8 , tag_1.nextSibling);
      tag_8.parentNode.insertBefore (tag_9 , tag_1.nextSibling);
      tag_9.parentNode.insertBefore (tag_10, tag_1.nextSibling);
      tag_10.parentNode.insertBefore(tag_11, tag_1.nextSibling);
      tag_11.parentNode.insertBefore(tag_12, tag_1.nextSibling);
      tag_12.parentNode.insertBefore(tag_13, tag_1.nextSibling);
      tag_13.parentNode.insertBefore(tag_14, tag_1.nextSibling);
      tag_14.parentNode.insertBefore(tag_15, tag_1.nextSibling);
      tag_15.parentNode.insertBefore(tag_16, tag_1.nextSibling);
	  }
	}
  if (regData.loginFacebookEnable || regData.facebookEnable) {
    (function() {
      var e = document.createElement('script');
      e.src = document.location.protocol + '//connect.facebook.net/en_US/all.js';
      e.async = true;
      document.getElementById('fb-root').appendChild(e);
    }());
	}

  OAT.MSG.send(OAT, 'PAGE_LOADED');
}

function userHref(S, host, userName)
{
  return (S.replace ('[HOST]', host)).replace ('[USER]', userName);
}

function lfCallback(oldIndex, newIndex)
{
  $('lf_login').disabled = false;
  if (newIndex == 0)
    $('lf_login').value = 'Login';
  else if (newIndex == 1)
    $('lf_login').value = 'OpenID Login';
  else if (newIndex == 2) {
    $('lf_login').value = 'Facebook Login';
    if (!facebookData)
      $('lf_login').disabled = true;
  }
  else if (newIndex == 3) {
    $('lf_login').value = 'WebID Login';
    if ((document.location.protocol == 'http:') || (sslData && !sslData.certLogin))
      $('lf_login').disabled = true;
  }
  else if (newIndex == 4)
    $('lf_login').value = 'Twitter Login';
  else if (newIndex == 5)
    $('lf_login').value = 'LinkedIn Login';

  pageFocus('lf_page_'+newIndex);
}

function rfCallback(oldIndex, newIndex)
{
  $('rf_signup').disabled = false;
  if (newIndex == 0)
    $('rf_signup').value = 'Sign Up';
  else if (newIndex == 1)
    $('rf_signup').value = 'OpenID Sign Up';
  else if (newIndex == 2) {
    $('rf_signup').value = 'Facebook Sign Up';
    if (!facebookData)
      $('rf_signup').disabled = true;
  }
  else if (newIndex == 3) {
    $('rf_signup').value = 'WebID Sign Up';
    if ((document.location.protocol == 'http:') || (sslData && sslData.certLogin))
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

function myCancel(prefix)
{
  needToConfirm = false;
  OAT.Dom.show(prefix+'_list');
  OAT.Dom.hide(prefix+'_form');
  OAT.Dom.hide(prefix+'_import');
  $('formMode').value = '';
  return false;
}

function mySubmit(prefix)
{
  needToConfirm = false;
  if (($v('formMode') == 'import') || validateInputs($(prefix+'_id'), prefix)) {
    if (prefix == 'pf051') {
      var S = '/ods/api/user.owns.'+ $v('formMode') +'?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm'))
              + '&id=' + encodeURIComponent($v('pf051_id'))
              + '&flag=' + encodeURIComponent($v('pf051_flag'))
              + '&name=' + encodeURIComponent($v('pf051_name'))
              + '&comment=' + encodeURIComponent($v('pf051_comment'))
              + '&properties=' + encodeURIComponent(prepareItems('ow'));
      OAT.AJAX.GET(S, '', function(data){pfShowOffers();});
    }
    if (prefix == 'pf052') {
      var S = '/ods/api/user.favorites.'+ $v('formMode') +'?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm'))
              + '&id=' + encodeURIComponent($v('pf052_id'))
              + '&flag=' + encodeURIComponent($v('pf052_flag'))
              + '&label=' + encodeURIComponent($v('pf052_label'))
              + '&uri=' + encodeURIComponent($v('pf052_uri'))
              + '&properties=' + encodeURIComponent(prepareProperties('r'));
      OAT.AJAX.GET(S, '', function(data){pfShowFavorites();});
    }
    if (prefix == 'pf053') {
    	var S = '/ods/api/user.mades.'+ $v('formMode') +'?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm'))
              + '&id=' + encodeURIComponent($v('pf053_id'))
              + '&property=' + encodeURIComponent($v('pf053_property'))
              + '&url=' + encodeURIComponent($v('pf053_url'))
              + '&description=' + encodeURIComponent($v('pf053_description'));
    	OAT.AJAX.GET(S, '', function(data){pfShowMades();});
    }
    if (prefix == 'pf054') {
    	var S = '/ods/api/user.offers.'+ $v('formMode') +'?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm'))
              + '&id=' + encodeURIComponent($v('pf054_id'))
              + '&flag=' + encodeURIComponent($v('pf054_flag'))
              + '&name=' + encodeURIComponent($v('pf054_name'))
              + '&comment=' + encodeURIComponent($v('pf054_comment'))
              + '&properties=' + encodeURIComponent(prepareItems('ol'));
    	OAT.AJAX.GET(S, '', function(data){pfShowOffers();});
    }
    if (prefix == 'pf055') {
    	var S = '/ods/api/user.seeks.'+ $v('formMode') +'?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm'))
              + '&id=' + encodeURIComponent($v('pf055_id'))
              + '&flag=' + encodeURIComponent($v('pf055_flag'))
              + '&name=' + encodeURIComponent($v('pf055_name'))
              + '&comment=' + encodeURIComponent($v('pf055_comment'))
              + '&properties=' + encodeURIComponent(prepareItems('wl'));
    	OAT.AJAX.GET(S, '', function(data){pfShowSeeks();});
    }
    if (prefix == 'pf056') {
      var S = '/ods/api/user.likes.'+ $v('formMode') +'?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm'))
              + '&id=' + encodeURIComponent($v('pf056_id'))
              + '&flag=' + encodeURIComponent($v('pf056_flag'))
              + '&uri=' + encodeURIComponent($v('pf056_uri'))
              + '&type=' + encodeURIComponent($v('pf056_type'))
              + '&name=' + encodeURIComponent($v('pf056_name'))
              + '&comment=' + encodeURIComponent($v('pf056_comment'))
              + '&properties=' + encodeURIComponent(prepareItems('ld'));
      OAT.AJAX.GET(S, '', function(data){pfShowLikes();});
    }
    if (prefix == 'pf057') {
      var items = [];
      if ($v('formMode') == 'import') {
        var form = $('page_form');
        for (var N = 0; N < form.elements.length; N++)
        {
          if (!form.elements[N])
            continue;

          var ctrl = form.elements[N];
          if (typeof(ctrl.type) == 'undefined')
            continue;

          if (ctrl.name.indexOf("k_fld_1_") != 0)
            continue;

          var suffix = ctrl.name.replace("k_fld_1_", "");
          items.push(["", $v("k_fld_1_"+suffix), $v("k_fld_2_"+suffix), $v("k_fld_3_"+suffix)]);
        }
        $('formMode').value = 'new';
        TBL.clean('k');
      } else {
        items = [[$v("pf057_id"), $v("pf057_flag"), $v("pf057_uri"), $v("pf057_label")]];
      }
      for (var N = 0; N < items.length; N++) {
        var S = '/ods/api/user.knows.'+ $v('formMode') +'?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm'))
                + '&id=' + encodeURIComponent(items[N][0])
                + '&flag=' + encodeURIComponent(items[N][1])
                + '&uri=' + encodeURIComponent(items[N][2])
                + '&label=' + encodeURIComponent(items[N][3]);
        if (N == items.length-1) {
          OAT.AJAX.GET(S, '', function(data){pfShowKnows();});
        } else {
          OAT.AJAX.GET(S, null, null);
        }
      }
    }
    if (prefix == 'pf26') {
      var file;
      var fr;
      var formMode = $v('formMode');
      var id = $v('pf26_id');
      var certificate;
      var enableLogin = $('pf26_enableLogin').checked? '1': '0';

      var fileReadText = function() {
        if (fr) {
          certificate = fr.result;
          pf26Call();
        }
      }

      var pf26Call = function () {
        var S = '/ods/api/user.certificates.'+ formMode +'?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm'))
                + '&id=' + encodeURIComponent(id)
                + '&certificate=' + encodeURIComponent(certificate)
                + '&enableLogin=' + encodeURIComponent(enableLogin);
      OAT.AJAX.GET(S, '', function(data){pfShowCertificates();});
    }

      if ($v('pf26_importFile') == '1') {
        if (window.File && window.FileReader && window.FileList && window.Blob) {
          //do your stuff!
          var fld = $('pf26_file');
          if (!fld.files) {
            alert('This browser doesn\'t seem to support the "files" property of file inputs.');
          } else if (!fld.files[0]) {
            alert('Please select a file!');
          } else {
            file = fld.files[0];
            fr = new FileReader();
            fr.onload = fileReadText;
            fr.readAsText(file);
          }
        } else {
          alert('The File APIs are not fully supported by your browser.');
        }
      } else {
        certificate = $v('pf26_certificate');
        pf26Call();
      }
    }
    OAT.Dom.show(prefix+'_list');
    OAT.Dom.hide(prefix+'_form');
    OAT.Dom.hide(prefix+'_import');
    $('formMode').value = '';
  }
  return false;
}

function submitItems()
{
  if ($('items')) {
    if ($v('formTab') == '0' && $v('formTab2') == '5' && $v('formTab3') == '1' && $v('formMode') != '')
      $('items').value = prepareItems('ow');
    if ($v('formTab') == '0' && $v('formTab2') == '5' && $v('formTab3') == '2' && $v('formMode') != '')
      $('items').value = prepareProperties('r');
    if ($v('formTab') == '0' && $v('formTab2') == '5' && $v('formTab3') == '4' && $v('formMode') != '')
      $('items').value = prepareItems('ol');
    if ($v('formTab') == '0' && $v('formTab2') == '5' && $v('formTab3') == '5' && $v('formMode') != '')
      $('items').value = prepareItems('wl');
    if ($v('formTab') == '0' && $v('formTab2') == '5' && $v('formTab3') == '6' && $v('formMode') != '')
      $('items').value = prepareItems('ld');
  }
}

function myBeforeSubmit()
{
  needToConfirm = false;
  submitItems()
}

function myValidateInputs(fld)
{
  var form = fld.form;
  var formTab = parseInt($v('formTab'));
  var formTab2 = parseInt($v('formTab2'));
  var div = $(pfPages[formTab][formTab2]);

  for (var i = 0; i < form.elements.length; i++) {
    if (!form.elements[i])
      continue;

    var ctrl = form.elements[i];
    if (typeof(ctrl.type) == 'undefined')
      continue;

    if (ctrl.disabled)
      continue;

     if (!OAT.Dom.isChild(ctrl, div))
      continue;

    if (OAT.Dom.isClass(ctrl, 'dummy'))
      continue;

    if (OAT.Dom.isClass(ctrl, '_validate_'))
    {
      retValue = validateField(ctrl);
      if (!retValue)
        return retValue;
    }
  }
  return true;
}

var needToConfirm = true;
function myCheckLeave (form)
{
  var formTab = parseInt($v('formTab'));
  var formTab2 = parseInt($v('formTab2'));
  var div = $(pfPages[formTab][formTab2]);
  var dirty = false;
  var retValue = true;

  submitItems()
  if (needToConfirm && (formTab < 3))
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
          retValue = myValidateInputs($('formTab'));
          if (retValue) {
          hiddenCreate('pf_update', null, 'x');
          form.submit();
        }
        }
        retValue = false;
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
  var formTab2 = parseInt($v('formTab2'));
  var div = $(pfPages[formTab][formTab2]);

  for (var i = 0; i < form.elements.length; i++)
  {
    var ctrl = form.elements[i];

    if (!ctrl)
      continue;

    if (typeof(ctrl.type) == 'undefined')
      continue;

    if (ctrl.disabled)
      continue;

     if ((ctrl.name.indexOf('pf_acl_') != 0) && (ctrl.name.indexOf('x1_fld_2_') != 0))
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

function pfTabSelect(tabPrefix, newIndex, newIndex2, newIndex3)
{
  $('formMode').value = '';
  if (newIndex3 != null) {
    if ($v('formTab3') == newIndex3) {return;}
  } else if (newIndex2 != null) {
    if ($v('formTab2') == newIndex2) {return;}
  } else {
    if ($v('formTab') == newIndex) {return;}
  }
  if ($('form')) {
    var S = '?'+pfParam('sid')+pfParam('realm')+pfParam('form')+'&formTab='+newIndex;
    if (newIndex2)
      S += '&formTab2='+newIndex2;

    if (newIndex3)
      S += '&formTab3='+newIndex3;

    document.location = document.location.protocol + '//' + document.location.host + document.location.pathname + S;
    return;
  }
  if (newIndex == 0)
    swapRows(newIndex2);

  if (myCheckLeave($('page_form'))) {
    if (newIndex3) {
      $('formTab').value = newIndex;
      $('formTab2').value = newIndex2;
    }
    else if (newIndex2)
    {
      $('formTab').value = newIndex;
      $('formTab2').value = newIndex2;
    }
    else
    {
      $('formTab').value = newIndex;
      $('formTab2').value = 0;
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

function pfShowRows(prefix, values, delimiters, showRow, acl, aclName)
{
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

function pfShowBioEvents(prefix, showRow)
{
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

function pfShowOnlineAccounts(prefix, accountType, showRow)
{
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
        if (o[N][1] != 'webid') {
         showRow(prefix, o[N][0], o[N][1], o[N][2], o[N][3]);
        rowCount++;
    	}
    }
    }
  	if (rowCount == 0)
  	  OAT.Dom.show(prefix+'_tr_no');
  }
	OAT.AJAX.GET('/ods/api/user.onlineAccounts.list?sid='+encodeURIComponent($v('sid'))+'&realm='+encodeURIComponent($v('realm'))+'&type='+accountType, '', x);
}

function pfShowItem(api, prefix, names, cb)
{
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
          if (fld.tagName == 'SPAN')
          {
            fld.innerHTML = o[name];
          } else {
            fieldValue(fld, o[name]);
          }
    	}
    	if (cb) {cb(o);}
    }
  }
  OAT.AJAX.GET('/ods/api/'+api+'?sid='+encodeURIComponent($v('sid'))+'&realm='+encodeURIComponent($v('realm'))+'&id='+$v(prefix+'_id'), '', x);
}

function pfShowList(api, prefix, noMsg, cols, idIndex, cb)
{
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
    OAT.Dom.clear(tbody);
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

function pfDeleteListObject(api, id, cb)
{
  if (confirm('Are you sure you want to delete this record?')) {
    var deleteApi = api.replace('list', 'delete');
	  OAT.AJAX.GET('/ods/api/'+deleteApi+'?sid='+encodeURIComponent($v('sid'))+'&realm='+encodeURIComponent($v('realm'))+'&id='+id, '', cb);
	}
}

function pfEditListObject(prefix, id)
{
  hiddenCreate(prefix+'_id', $('page_form'), id);
  $('formMode').value = 'edit';
  if ($v('mode') == 'html') {
    if (prefix == 'pf051')
      pfShowOwn('edit', id);
    if (prefix == 'pf052')
      pfShowFavorite('edit', id);
    if (prefix == 'pf053')
      pfShowMade('edit', id);
    if (prefix == 'pf054')
      pfShowOffer('edit', id);
    if (prefix == 'pf055')
      pfShowSeek('edit', id);
    if (prefix == 'pf056')
      pfShowLike('edit', id);
    if (prefix == 'pf057')
      pfShowKnow('edit', id);
    if (prefix == 'pf26')
      pfShowCertificate('edit', id);
    return false;
  }
  $('page_form').submit();
}

function pfShowMode(prefix, mode, id)
{
  if (mode) {
    OAT.Dom.hide(prefix+'_list');
    if (mode == 'import') {
      OAT.Dom.show(prefix+'_import');
    } else {
    OAT.Dom.show(prefix+'_form');
    }
    hiddenCreate(prefix+'_id', $('page_form'), id);
    $('formMode').value = mode;
  }
}

function pfShowOwn(mode, id)
{
  pfShowMode('pf051', mode, id);
  var x = function (obj) {
    OAT.Dom.clear('ow_tbody');
    RDF.tablePrefix = 'ow';
    RDF.tableOptions = {itemType: {fld_1: {cssText: "display: none;"}, btn_1: {cssText: "display: none;"}}};
    RDF.itemTypes = obj.properties;
    RDF.showItemTypes();
  }
  pfShowItem('user.owns.get', 'pf051', ['flag', 'name', 'comment'], x);
}

function pfShowFavorite(mode, id)
{
  pfShowMode('pf052', mode, id);
  var x = function (obj) {
    $('r_tbody').innerHTML = '<tr id="r_item_0_tr_0_properties"><td></td><td></td><td valign="top"></td></tr>';
    RDF.tablePrefix = 'r';
    RDF.itemTypes = obj.properties;
    RDF.loadOntology(
      'http://rdfs.org/sioc/ns#',
      function(){
        RDF.loadClassProperties(
          RDF.getOntologyClass('sioc:Item'),
          function(){RDF.showPropertiesTable(RDF.itemTypes[0].items[0]);}
        );
      }
    )
  }
  pfShowItem('user.favorites.get', 'pf052', ['flag', 'label', 'uri'], x);
}

function pfShowMade(mode, id)
{
  pfShowMode('pf053', mode, id);
  pfShowItem('user.mades.get', 'pf053', ['property', 'uri', 'description']);
}

function pfShowOffer(mode, id)
{
  pfShowMode('pf054', mode, id);
  var x = function (obj) {
    OAT.Dom.clear('ol_tbody');
    RDF.tablePrefix = 'ol';
    RDF.tableOptions = {itemType: {fld_1: {cssText: "display: none;"}, btn_1: {cssText: "display: none;"}}};
    RDF.itemTypes = obj.properties;
    RDF.showItemTypes();
  }
  pfShowItem('user.offers.get', 'pf054', ['flag', 'name', 'comment'], x);
}

function pfShowSeek(mode, id)
{
  pfShowMode('pf055', mode, id);
  var x = function(obj) {
    OAT.Dom.clear('wl_tbody');
    RDF.tablePrefix = 'wl';
    RDF.tableOptions = {itemType: {fld_1: {cssText: "display: none;"}, btn_1: {cssText: "display: none;"}}};
    RDF.itemTypes = obj.properties;
    RDF.showItemTypes();
  }
  pfShowItem('user.seeks.get', 'pf055', ['flag', 'name', 'comment'], x);
}

function pfShowLike(mode, id)
{
  pfShowMode('pf056', mode, id);
  var x = function(obj) {
    OAT.Dom.clear('ld_tbody');
    RDF.tablePrefix = 'ld';
    RDF.tableOptions = {itemType: {fld_1: {cssText: "display: none;"}, btn_1: {cssText: "display: none;"}}};
    RDF.itemTypes = obj.properties;
    RDF.showItemTypes();
  }
  pfShowItem('user.likes.get', 'pf056', ['flag', 'type', 'uri', 'name'], x);
}

function pfShowKnow(mode, id)
{
  pfShowMode('pf057', mode, id);
  pfShowItem('user.knows.get', 'pf057', ['flag', 'uri', 'label']);
}

function pfShowCertificate(mode, id)
{
  pfShowMode('pf26', mode, id);
  if (mode == 'new') {
    OAT.Dom.hide("pf26_form_0");
    OAT.Dom.hide("pf26_form_1");
    OAT.Dom.hide("pf26_form_2");
  } else {
    OAT.Dom.show("pf26_form_0");
    OAT.Dom.show("pf26_form_1");
    OAT.Dom.show("pf26_form_2");
  }
  pfShowItem('user.certificates.get', 'pf26', ['subject', 'agentID', 'fingerPrint', 'certificate', 'enableLogin']);
}

function pfShowOwns() {
  pfShowList('user.owns.list', 'pf051', 'No Items', [1, 2], 0, function (data){pfShowOwns();});
}

function pfShowFavorites() {
  pfShowList('user.favorites.list', 'pf052', 'No Items', [3, 4], 0, function (data){pfShowFavorites();});
}

function pfShowMades() {
  pfShowList('user.mades.list', 'pf053', 'No Items', [1, 3], 0, function (data){pfShowMades();});
}

function pfShowOffers() {
  pfShowList('user.offers.list', 'pf054', 'No Items', [1, 2], 0, function (data){pfShowOffers();});
}

function pfShowSeeks() {
  pfShowList('user.seeks.list', 'pf055', 'No Items', [1, 2], 0, function (data){pfShowSeeks();});
}

function pfShowLikes() {
  pfShowList('user.likes.list', 'pf056', 'No Items', [2, 1, 3], 0, function (data){pfShowLikes();});
}

function pfShowKnows() {
  pfShowList('user.knows.list', 'pf057', 'No Items', [2, 1], 0, function (data){pfShowKnows();});
}

function pfShowCertificates() {
  pfShowList('user.certificates.list', 'pf26', 'No Items', [1, 2, 3, 4], 0, function (data){pfShowCertificates();});
}

function isShow(element) {
	var elm = $(element);
	if (elm && elm.style.display == "none")
	  return false;
  return true;
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

function fieldValue(obj, str) {
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
}

function fieldUpdate(xml, tName, fName, acl, aclName) {
  var obj = $(fName);
  var str = tagValue(xml, tName);
  fieldValue(obj, str);
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
       o[1] = new Option('acl', '2');
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

function selectProfile(userName) {
  // UI Profile
  var S = '/ods/api/user.info?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm'));
  if (userName)
    S += '&name=' + encodeURIComponent(userName);

  OAT.AJAX.GET(S, '', selectProfileCallbackNew);
}

function selectProfileCallbackNew(data) {
  var xml = OAT.Xml.createXmlDoc(data);
  if (!hasError(xml, false)) {
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
  } else {
    logoutSubmit();
  }
}

function showProfileNew(xmlDoc) {
  var div = $('uf_div_new');
  if (div) {
    var x = function(data) {
      var xslDoc = OAT.Xml.createXmlDoc(data);
      var result = OAT.Xml.transformXSLT(xmlDoc, xslDoc);
      if (result) {
        showTitle('profile');
        OAT.Dom.hide("lf");
        OAT.Dom.hide("rf");
        OAT.Dom.show("uf");
        OAT.Dom.hide("pf");
        div.innerHTML = OAT.Xml.serializeXmlDoc(result);
    }
    }
    OAT.AJAX.GET('/ods/users/users.xsl', false, x);
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
    addProfileTableValues(tbl, 'Other Personal URIs (WebIDs)', tagValue(user, 'webIDs'), [ 'URL', 'Access' ], [ '\n', ';' ])
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

function addProfileRowText(tbl, txt, txtCSSText) {
  var tr = OAT.Dom.create('tr');
  var td = OAT.Dom.create('td');
  td.colSpan = 2;
  td.style.cssText = txtCSSText;
  td.innerHTML = txt;
  tr.appendChild(td);
  tbl.appendChild(tr);

  return td;
}

function addProfileRowButton(td, id) {
  var a = OAT.Dom.create ("a");
  a.id = id;
  a.href = document.location.protocol + '//' + document.location.host + document.location.pathname;
  a.innerHTML = 'Sign In (SSL)';

  td.appendChild(a);
  sslLinks['in'].push(a);
}

function addProfileRowButton2(td, id) {
  var a = OAT.Dom.create ("a");
  a.id = id;
  a.href = document.location.protocol + '//' + document.location.host + document.location.pathname + '?form=register';
  a.innerHTML = 'Sign Up (SSL)';

  td.appendChild(a);
  sslLinks['up'].push(a);
}

function addProfileRow(tbl, xml, tagLabel, label) {
  var value = tagValue(xml, tagLabel);
  if (value)
    addProfileRowValue(tbl, label, value);
}

function addProfileRowValue(tbl, label, value, leftTag) {
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

function addProfileRowImage(tbl, label, value, leftTag) {
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

function addProfileRowInput(tbl, label, fName, fOptions) {
	var tr = OAT.Dom.create('tr');
  tr.id = 'tr_'+fName;

  var th = OAT.Dom.create('th', {verticalAlign: 'top'});
  th.width = '20%';
	th.innerHTML = label + '<div style="font-weight: normal; display: inline; color: red;"> *</div>';
	tr.appendChild(th);

	var td = OAT.Dom.create('td');
  tr.appendChild(td);

  var fld = OAT.Dom.create('input', fOptions);
  fld.type = 'type';
  fld.id = fName;
  fld.name = fld.id;
  if (fld.value == 'undefined')
    fld.value = '';
  td.appendChild(fld);

	tbl.appendChild(tr);
}

function addProfileTableValues(tbl, label, values, headers, delimiters) {
	if (values) {
    var tr = OAT.Dom.create('tr');
    var th = OAT.Dom.create('th');
    th.vAlign = 'top';
    th.width = '20%';
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
  if (!leftTag)
		leftTag = 'td';

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


function logoutUrl() {
  var path = document.location.pathname.split('/');
  document.location = document.location.protocol + '//' + document.location.host + '/' + path[1] + '/' + path[2];
}

function logoutSubmit() {
		var S = '/ods/api/user.logout?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm'));
  OAT.AJAX.GET(S, '', logoutUrl);
  return false;
}

function lfLoginSubmit() {
  loginSubmit(lfTab.selectedIndex, 'lf');
		return false;
}

function loginSubmit(mode, prefix) {
  var uriParams = OAT.Dom.uriParams();
  var notReturn = lfNotReturn;
  lfNotReturn = true;
	var q = '';
	if (mode == 1) {
    if (typeof (uriParams['openid.signed']) != 'undefined' && uriParams['openid.signed'] != '') {
      q += openIdLoginURL(uriParams);
    } else {
		  if ($(prefix+'_openId').value.length == 0)
			return showError('Invalid OpenID URL');

  	  openIdAuthenticate(prefix);
    return false;
  	}
  }
  else if (mode == 2) {
    if (!facebookData || (!facebookData.id && !facebookData.link))
      return showError('Invalid Facebook User');

    q += '&facebookUID=' + ((facebookData.link)? facebookData.link: facebookData.id);
  }
  else if (mode == 3) {
  }
  else if (mode == 4) {
	  if (notReturn || (typeof (uriParams['oauth_verifier']) == 'undefined') || (typeof (uriParams['oauth_token']) == 'undefined')) {
    twitterAuthenticate('lf');
    return false;
    }
    q +='oauthMode=twitter'
      + '&oauthSid=' + encodeURIComponent(uriParams['sid'])
      + '&oauthVerifier=' + encodeURIComponent(uriParams['oauth_verifier'])
      + '&oauthToken=' + encodeURIComponent(uriParams['oauth_token']);
  }
  else if (mode == 5) {
	  if ((notReturn || typeof (uriParams['oauth_verifier']) == 'undefined') || (typeof (uriParams['oauth_token']) == 'undefined')) {
    linkedinAuthenticate('lf');
    return false;
    }
    q +='oauthMode=linkedin'
      + '&oauthSid=' + encodeURIComponent(uriParams['sid'])
      + '&oauthVerifier=' + encodeURIComponent(uriParams['oauth_verifier'])
      + '&oauthToken=' + encodeURIComponent(uriParams['oauth_token']);
  }
  else {
		if (($(prefix+'_uid').value.length == 0) || ($(prefix+'_password').value.length == 0))
      return showError('Invalid User ID or Password');

    q +='user_name=' + encodeURIComponent($v(prefix+'_uid'))
      + '&password_hash=' + encodeURIComponent(OAT.Crypto.sha($v(prefix+'_uid') + $v(prefix+'_password')));
    }
	OAT.AJAX.POST("/ods/api/user.authenticate", q, afterLogin);
	return false;
}

function loginUrl() {
  var x = function (data) {
	var xml = OAT.Xml.createXmlDoc(data);
	if (!hasError(xml)) {
		/* user data */
      var user = xml.getElementsByTagName('user')[0];
      if (user) {
        var userName = tagValue(user, 'name');
        var path = document.location.pathname.split('/');
        document.location = document.location.protocol + '//' + document.location.host + '/' + path[1] + '/' + path[2]+ '/~' + userName + '?sid='+encodeURIComponent($v('sid'))+'&realm='+encodeURIComponent($v('realm'));
      }
			} else {
      logoutUrl();
			}
		}
  var S = '/ods/api/user.info?sid='+encodeURIComponent($v('sid'))+'&realm='+encodeURIComponent($v('realm'))+'&short=1';
  OAT.AJAX.GET(S, '', x);
}

function afterLogin(data, prefix) {
  var xml = OAT.Xml.createXmlDoc(data);
  if (!hasError(xml)) {
    $('sid').value = OAT.Xml.textValue(xml.getElementsByTagName('sid')[0]);
    $('realm').value = 'wa';
    loginUrl();
	} else {
    logoutUrl();
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
  $('formTab2').value=0;
  $('page_form').submit();

  return false;
}

function inputParameter(inputField) {
  var T = $(inputField);
  if (T)
    return T.value;
  return '';
}

function ufCertificateGenerator() {
  var x = function (data) {
    var url;
    try {
      var url = OAT.JSON.parse(data);
    } catch (e) { url = null; }
    if (url && url.indexOf('<failed>') == -1) {
      var a = OAT.Dom.create('a');
      a.href = url;
      a.innerHTML = 'Certificate Generator';
      a.style.cssText = 'color: #000; text-decoration: none;';
      $("pf_tab_2_4").innerHTML = '';
      $("pf_tab_2_4").appendChild(a);
      OAT.Dom.show("pf_tab_2_4");
    } else {
      $("pf_tab_2_4").innerHTML = 'Certificate Generator';
      OAT.Event.attach("pf_tab_2_4", 'click', function(){pfTabSelect('pf_tab_2_', 2, 4);});
      OAT.Dom.show("pf_tab_2_4");
    }
  }
  OAT.AJAX.GET ('/ods/api/user.certificateUrl?sid='+encodeURIComponent($v('sid'))+'&realm='+encodeURIComponent($v('realm')), false, x, {async: false});
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
  $('formTab2').value = '0';
  $('formTab3').value = '0';
  updateList('pf_homecountry', 'Country');
  updateList('pf_businesscountry', 'Country');
  updateList('pf_businessIndustry', 'Industry');
	ufProfileLoad()
}

function ufProfileLoad(No) {
    var formTab = parseInt($v('formTab'));
  var formTab2 = parseInt($v('formTab2'));
  var formTab3 = parseInt($v('formTab3'));
  if (No == 1) {
    formTab2++;
    if (
        ((formTab == 1) && (formTab2 > 3)) ||
        ((formTab == 2) && (formTab2 > 5))
       )
    {
      formTab++;
      formTab2 = 0;
      pfTabInit('pf_tab_', formTab);
    }
    if ($('pf_tab_'+formTab+'_'+formTab2).style.display == 'none')
      formTab2++;
    $('formTab').value = "" + formTab;
    $('formTab2').value = "" + formTab2;
    $('formTab3').value = "" + formTab3;
  }
  if ((formTab == 0) && (formTab2 > 4)) {
    OAT.Dom.hide('pf_footer_0');
  } else {
    OAT.Dom.show('pf_footer_0');
  }
  if ((formTab == 2) && (formTab2 > 4)) {
    OAT.Dom.hide('pf_footer_2');
  } else {
    OAT.Dom.show('pf_footer_2');
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
      pfShowRows("x1", tagValue(user, "webIDs"), ["\n", ";"], function(prefix, val1, val2){TBL.createRow(prefix, null, {fld_1: {value: val1, className: '_validate_ _webid_ _canEmpty_'}, fld_2: {mode: 4, value: val2}});}, aclData, 'pf_acl_webIDs');
			fieldUpdate(user, 'mailSignature', 'pf_mailSignature');
			fieldUpdate(user, 'summary', 'pf_summary', aclData);
			fieldUpdate(user, 'photo', 'pf_photo', aclData);
			fieldUpdate(user, 'photoContent', 'pf_photoContent');
			fieldUpdate(user, 'audio', 'pf_audio', aclData);
			fieldUpdate(user, 'audioContent', 'pf_audioContent');
			fieldUpdate(user, 'appSetting', 'pf_appSetting');
      fieldUpdate(user, 'spbEnable', 'pf_spbEnable');
      fieldUpdate(user, 'inSearch', 'pf_inSearch');
      fieldUpdate(user, 'showActive', 'pf_showActive');
      pfShowRows("x2", tagValue(user, "topicInterests"), ["\n", ";"], function(prefix, val1, val2){TBL.createRow(prefix, null, {fld_1: {value: val1, className: '_validate_ _url_ _canEmpty_'}, fld_2: {value: val2}});}, aclData, 'pf_acl_topicInterests');
      pfShowRows("x3", tagValue(user, "interests"), ["\n", ";"], function(prefix, val1, val2){TBL.createRow(prefix, null, {fld_1: {value: val1, className: '_validate_ _url_ _canEmpty_'}, fld_2: {value: val2}});}, aclData, 'pf_acl_interests');

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
      pfShowOnlineAccounts("x4", "P", function(prefix, val0, val1, val2, val3){TBL.createRow(prefix, null, {id: val0, fld_1: {mode: 10, value: val1}, fld_2: {value: val2, className: '_validate_ _uri_ _canEmpty_'}, fld_3: {value: val3}});});

      // bio events
      pfShowBioEvents("x5", function(prefix, val0, val1, val2, val3){TBL.createRow(prefix, null, {id: val0, fld_1: {mode: 11, value: val1}, fld_2: {value: val2}, fld_3: {value: val3}});});

      // owns
      if (($v('formTab') == "0") && ($v('formTab2') == "5") && ($v('formTab3') == "1"))
        pfShowOwns();

      // favorites
      if (($v('formTab') == "0") && ($v('formTab2') == "5") && ($v('formTab3') == "2"))
        pfShowFavorites();

      // made
      if (($v('formTab') == "0") && ($v('formTab2') == "5") && ($v('formTab3') == "3"))
        pfShowMades();

      // offer
      if (($v('formTab') == "0") && ($v('formTab2') == "5") && ($v('formTab3') == "4"))
        pfShowOffers();

      // seek
      if (($v('formTab') == "0") && ($v('formTab2') == "5") && ($v('formTab3') == "5"))
        pfShowSeeks();

      // likes
      if (($v('formTab') == "0") && ($v('formTab2') == "5") && ($v('formTab3') == "6"))
        pfShowLikes();

      if (($v('formTab') == "0") && ($v('formTab2') == "5") && ($v('formTab3') == "7"))
        pfShowKnows();

      // seek
      if (($v('formTab') == "2") && ($v('formTab2') == "6"))
        pfShowCertificates();

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
      pfShowOnlineAccounts("y1", "B", function(prefix, val0, val1, val2, val3){TBL.createRow(prefix, null, {id: val0, fld_1: {mode: 10, value: val1}, fld_2: {value: val2, className: '_validate_ _uri_ _canEmpty_'}, fld_3: {value: val3}});});

			// contact
			fieldUpdate(user, 'businessIcq', 'pf_businessIcq', aclData);
			fieldUpdate(user, 'businessSkype', 'pf_businessSkype', aclData);
			fieldUpdate(user, 'businessYahoo', 'pf_businessYahoo', aclData);
			fieldUpdate(user, 'businessAim', 'pf_businessAim', aclData);
			fieldUpdate(user, 'businessMsn', 'pf_businessMsn', aclData);
      pfShowRows("y2", tagValue(user, "businessMessaging"), ["\n", ";"], function(prefix, val1, val2){TBL.createRow(prefix, null, {fld_1: {value: val1}, fld_2: {value: val2, cssText: 'width: 220px;'}});});

      // security
      if (tagValue(user, 'noPassword') == '1') {
        OAT.Dom.hide('tr_oldPassword');
      } else {
        OAT.Dom.show('tr_oldPassword');
      }
			fieldUpdate(user, 'securityOpenID', 'pf_securityOpenID');

      var S = tagValue(user, 'securityFacebookID');
      if (S) {
        $('span_facebookName').innerHTML = tagValue(user, 'securityFacebookName');
      } else {
        $('span_facebookName').innerHTML = 'not yet';
      }

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
        OAT.Dom.hide('cert');
        $('cert').src = '';
	    } else {
        OAT.Dom.show('cert');
        $('cert').src = '/ods/cert.vsp?sid=' + encodeURIComponent($v('sid'));
	    }
      showTitle('profile');

      OAT.Dom.hide("lf");
      OAT.Dom.hide("uf");
      OAT.Dom.show("pf");
			pfTabInit('pf_tab_', $v('formTab'));
      pfTabInit('pf_tab_0_', $v('formTab2'));
      pfTabInit('pf_tab_1_', $v('formTab2'));
      pfTabInit('pf_tab_2_', $v('formTab2'));
      pfTabInit('pf_tab_0_5_', $v('formTab3'));
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
  return encodeURIComponent(retValue);
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
  var L = 0;
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
    ontologies.push({"id": ''+L++, "ontology": ontologyName, "items": ontologyItems});
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
    var propertyType = $v(prefix+"_item_"+ontologyNo+"_prop_"+itemNo+"_fld_2_"+propertyNo);
    var propertyValue = $v(prefix+"_item_"+ontologyNo+"_prop_"+itemNo+"_fld_3_"+propertyNo);
    var propertyLanguage = $v(prefix+"_item_"+ontologyNo+"_prop_"+itemNo+"_fld_4_"+propertyNo);
        if (propertyType == 'object') {
          var item = RDF.getItemByName(propertyValue);
          if (item)
            propertyValue = item.id;
        }
    itemProperties.push({"name": propertyName, "value": propertyValue, "type": propertyType, "language": propertyLanguage});
      }
  return itemProperties;
}

function pfUpdateSubmit(No) {
  if (!myValidateInputs($('formTab')))
    return false;

  var formTab = parseInt($v('formTab'));
  var formTab2 = parseInt($v('formTab2'));
  if ((formTab == 0) && (formTab2 == 3))
  {
    updateOnlineAccounts('x4', 'P');
    ufProfileLoad(No);
  }
  else if ((formTab == 0) && (formTab2 == 5))
  {
    updateBioEvents('x5');
    ufProfileLoad(No);
  }
  else if ((formTab == 1) && (formTab2 == 2))
  {
    updateOnlineAccounts('y1', 'B');
    ufProfileLoad(No);
  }
  else if ((formTab == 2) && (formTab2 == 0))
  {
    pfChangeSubmit();
  }
  else
  {
    var A = '';
  	var S = '/ods/api/user.update.fields?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm'))
    if (formTab == 0)
    {
      if (formTab2 == 0)
      {
        // Import
        if ($v('cb_item_i_photo') == '1')
          S += '&photo=' + encodeURIComponent($v('i_photo'));
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
        if ($v('cb_item_i_homeCountry') == '1')
          S += '&homeCountry=' + encodeURIComponent($v('i_homeCountry'));
        if ($v('cb_item_i_homeState') == '1')
          S += '&homeState=' + encodeURIComponent($v('i_homeState'));
        if ($v('cb_item_i_homeCity') == '1')
          S += '&homeCity=' + encodeURIComponent($v('i_homeCity'));
        if ($v('cb_item_i_homeCode') == '1')
          S += '&homeCode=' + encodeURIComponent($v('i_homeCode'));
        if ($v('cb_item_i_homeAddress1') == '1')
          S += '&homeAddress1=' + encodeURIComponent($v('i_homeAddress1'));
        if ($v('cb_item_i_homeAddress2') == '1')
          S += '&homeAddress2=' + encodeURIComponent($v('i_homeAddress2'));
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
        if ($v('cb_item_i_topicInterests') == '1')
          S += '&topicInterests=' + encodeURIComponent($v('i_topicInterests'));
        if ($v('cb_item_i_interests') == '1')
          S += '&interests=' + encodeURIComponent($v('i_interests'));
        if ($v('cb_item_i_onlineAccounts') == '1')
          S += '&onlineAccounts=' + encodeURIComponent($v('i_onlineAccounts'));
      }
      else if (formTab2 == 1)
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
          + '&spbEnable=' + encodeURIComponent($('pf_spbEnable').checked? '1': '0')
          + '&inSearch=' + encodeURIComponent($('pf_inSearch').checked? '1': '0')
          + '&showActive=' + encodeURIComponent($('pf_showActive').checked? '1': '0')
          + '&webIDs=' + encodeTableData("x1", ["\n", ";"])
          + '&topicInterests=' + encodeTableData("x2", ["\n", ";"])
          + '&interests=' + encodeTableData("x3", ["\n", ";"]);
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
          + '&topicInterests=' + $v('pf_acl_topicInterests')
          + '&interests=' + $v('pf_acl_interests')
          + '&audio=' + $v('pf_acl_audio')
          + '&photo=' + $v('pf_acl_photo');
      }
      else if (formTab2 == 2)
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
      else if (formTab2 == 4)
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
      if (formTab2 == 0)
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
      else if (formTab2 == 1)
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
      else if (formTab2 == 3)
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
      if (formTab2 == 1)
      {
        S += '&securitySecretQuestion=' + encodeURIComponent($v('pf_securitySecretQuestion')) +
             '&securitySecretAnswer=' + encodeURIComponent($v('pf_securitySecretAnswer'));
    	}
      else if (formTab2 == 2)
      {
        S += '&securityOpenID=' + encodeURIComponent($v('pf_securityOpenID'));
    	}
      else if (formTab2 == 3)
      {
        S += '&securitySiocLimit=' + encodeURIComponent($v('pf_securitySiocLimit'));
    	}
  	}
  	if (A != '')
  	  OAT.AJAX.GET('/ods/api/user.acl.update?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm')) + '&acls=' + encodeURIComponent(A), false, null, {async: false});

    OAT.AJAX.GET(S, '', function(data){ if((formTab == 0) && (formTab2 == 1)) {$('page_form').submit();}; pfUpdateCallback(data, No);});
  }
  $('pf_oldPassword').value = '';
  $('pf_newPassword').value = '';
  $('pf_newPassword2').value = '';

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
  OAT.Dom.clear('i_tbody');
	OAT.Dom.hide('i_tbl');
}

function pfGetFOAFData(iri) {
  var S = '/ods/api/user.getFOAFData?spongerMode=1&foafIRI=' + encodeURIComponent(iri);
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
      pfSetFOAFValue(tbody, o.depiction,            'Photo',                        'i_photo');
			pfSetFOAFValue(tbody, o.title,                'Title',                 'i_title');
      pfSetFOAFValue(tbody, o.nick,                 'Nick Name',                    'i_nickName');
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
      pfSetFOAFValue(tbody, o.country,              'Address - Country',            'i_homeCountry');
      pfSetFOAFValue(tbody, o.region,               'Address - State/Province',     'i_homeState');
      pfSetFOAFValue(tbody, o.locality,             'Address - City',               'i_homeCity');
      pfSetFOAFValue(tbody, o.pobox,                'Address - Zip/Postal Code',    'i_homeCode');
      pfSetFOAFValue(tbody, o.street,               'Address - Address 1',          'i_homeAddress1');
      pfSetFOAFValue(tbody, o.extadd,               'Address - Address 2',          'i_homeAddress2');
			pfSetFOAFValue(tbody, o.lat,                  'Latitude',              'i_homelat');
			pfSetFOAFValue(tbody, o.lng,                  'Longitude',             'i_homelng');
			pfSetFOAFValue(tbody, o.organizationTitle,    'Organization',          'i_businessOrganization');
			pfSetFOAFValue(tbody, o.organizationHomepage, 'Organization Homepage', 'i_businessHomePage');
			pfSetFOAFValue(tbody, o.resume,               'Resume',                       'i_summary');
			pfSetFOAFValue(tbody, o.tags,                 'Tags',                  'i_tags');
      pfSetFOAFValue(tbody, o.sameAs,               'Other Personal URIs (WebIDs)', 'i_sameAs', ['URI'], ['value']);
      pfSetFOAFValue(tbody, o.topic_interest,       'Topic of Interest',            'i_topicInterests', ['URL', 'Label'], ['value', 'label']);
      pfSetFOAFValue(tbody, o.interest,             'Thing of Interest',            'i_interests', ['URI', 'Label'], ['value', 'label']);
      pfSetFOAFValue(tbody, o.onlineAccounts,       'Online Accounts',              'i_onlineAccounts', ['Label', 'URI'], ['value', 'uri']);
      pfSetFOAFValue(tbody, o.knows,                'Social Network',               'i_knows', ['URI', 'Name'], ['value', 'name']);
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

function pfSetFOAFValue(tbody, fValue, fTitle, fName, fHeaders, fLabels) {
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
      tmp = '';
      for ( var N = 0; N < fValue.length; N++) {
          var trx = OAT.Dom.create('tr');
          tbl.appendChild(trx);
        for ( var M = 0; M < fLabels.length; M++) {
            var tdx = OAT.Dom.create('td');
          var tmpValue = OAT.Dom.text(fValue[N][fLabels[M]]);
          if (tmpValue)
            tdx.appendChild(tmpValue);
            trx.appendChild(tdx);
          if (tmpValue)
            tmp += tmpValue;
          tmp += ';';
          }
        tmp += '\n';
      	}
      fValue = tmp;
    } else {
      if (fName == 'i_photo') {
        var img = OAT.Dom.create('img', {}, 'resize');
        img.src = fValue;
        td.appendChild(img);
      } else {
      td.appendChild(OAT.Dom.text(fValue));
    }
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

function lfRegisterSubmit(event, no) {
  $('sid').value = '';
  $('realm').value = '';

  showTitle('register');

  OAT.Dom.hide("ob_right_logout");
  OAT.Dom.hide("ob_links");

  OAT.Dom.hide("lf");
  OAT.Dom.show("rf");

  rfResetData();
  if (!no && (document.location.protocol == 'https:'))
  rfSSLAutomaticLogin();

  return false;
}

function rfResetData() {
  $('rf_password').value = '';
  $('rf_password2').value = '';
  $('rf_openId').value = '';
  $('rf_is_agreed').checked = false;
  for (var N = 0; N < 5; N++) {
    if ($('rf_uid_'+N))
      $('rf_uid_'+N).value = '';
    if ($('rf_email_'+N))
      $('rf_email_'+N).value = '';
  }
}

function rfSSLAutomaticLogin() {
  if (regData.sslAutomaticEnable && !$("rf_uid_3") && !$("rf_email_3")) {
    $('rf_is_agreed').checked = true;
    rfTab.go(3);
    rfSignupSubmit();
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
    if (!facebookData || (!facebookData.id && !facebookData.lonk))
      return showError('Invalid Facebook User');
	} else if (rfTab.selectedIndex == 3) {
		if (!sslData || !sslData.iri)
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
	  openIdAuthenticate('rf');
		return false;
	}
    q +='&data=' + encodeURIComponent($v('oid-data'))
      + '&name=' + encodeURIComponent($v('rf_uid_1'))
      + '&email=' + encodeURIComponent($v('rf_email_1'));
  }
	else if (rfTab.selectedIndex == 2) {
		q += '&data=' + encodeURIComponent(OAT.JSON.stringify(facebookData))
      + '&name=' + encodeURIComponent($v('rf_uid_2'))
      + '&email=' + encodeURIComponent($v('rf_email_2'));
	}
	else if (rfTab.selectedIndex == 3) {
    q +='&data=' + encodeURIComponent(OAT.JSON.stringify(sslData))
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

function openIdLoginURL(uriParams) {
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

function openIdAuthenticate(prefix) {
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

    if (prefix == 'rf') {
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
    }
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

function showTitle(txt) {
	var T = $('ob_left');
	if (T)
  {
    if ((txt == 'user') || (txt == 'profile')) {
      OAT.Dom.show(T);
      OAT.Dom.show('ob_left_01');
      OAT.Dom.show('ob_right_logout');
      if (validateSession) {
        OAT.Dom.show('ob_left_02');
        $('ob_right_logout').innerHTML = 'Logout';
      } else {
        OAT.Dom.hide('ob_left_02');
        $('ob_right_logout').innerHTML = 'Login';
      }
    } else {
      OAT.Dom.hide(T);
      OAT.Dom.hide('ob_right_logout');
    }
  }
}

function knowsData() {
  if (!validateField($('k_import')))
    return;

	var S = '/ods/api/user.getKnowsData?sourceURI=' + encodeURIComponent($v('k_import'));
	var x = function(data) {
		var o = null;
		try {
			o = OAT.JSON.parse(data);
		} catch (e) {
			o = null;
		}
		if (o) {
      for ( var i = 0; i < o.length; i++) {
        TBL.createRow('k', null, {fld_1: {mode: 4, value: '1'}, fld_2: {value: o[i].uri, readOnly: true}, fld_3: {value: o[i].label, readOnly: true}});
      }
		} else {
			alert('No data founded');
		}
	}
	OAT.AJAX.GET(S, '', x, {onstart : function() {OAT.Dom.show('k_import_image')}, onend : function() {OAT.Dom.hide('k_import_image')}});
}

function userDisable(userName)
{
  var S = '/ods/api/user.disable?name='+encodeURIComponent($v(userName)) + '&sid=' + $v('sid') + '&realm=wa';
	var x = function(data) {
    var xml = OAT.Xml.createXmlDoc(data);
    if (!hasError(xml, false)) {
      alert('User\'s account is disabled!');
      logoutUrl();
    }
	}
  OAT.AJAX.GET(S, '', x);
}

