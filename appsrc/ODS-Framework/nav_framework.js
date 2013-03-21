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

// TODO: move template functions to OAT
//
function get_param(name) {
  var regexS = "[\\?&]"+name+"=([^&#]*)";
  var regex = new RegExp( regexS );
  var results = regex.exec( document.location.href );
  if( results == null )
    return "";
  else
    return results[1];
}

function _getChildElemsByClassName(elm, class_name, max_depth,
		stop_at_first_match, elm_arr) {
  var i = 0;

	if (!max_depth)
		return elm_arr;
	if (OAT.Dom.isClass(elm, class_name)) {
      elm_arr.append (elm);
      if (stop_at_first_match)
	return elm_arr;
    }
	for (i = 0; i < elm.childNodes.length; i++) {
      var n = elm.childNodes[i];
      if (is_elem (n))
			_getChildElemsByClassName(n, class_name, max_depth,
					stop_at_first_match, elm_arr);
      if (elm_arr.length && stop_at_first_match)
	return elm_arr;
    }
  max_depth--;
  return elm_arr;
}

function getChildElemsByClassName(elm, class_name, max_depth, stop_at_first_match) {
  var elm_arr = new Array ();
	return _getChildElemsByClassName(elm, class_name, max_depth, stop_at_first_match, elm_arr);
}

function replaceTemplateClass(elm, class_name, content) {
  var  _n = getChildElemsByClassName (elm, class_name, 16, false);
	for ( var i = 0; i < _n.length; i++) {
      _n[i].replaceChild (document.createTextNode (content), _n[i].firstChild);
    }
}

function is_elem(node) {
  return (node.nodeType == 1) ? true : false;
}

function is_attrib_node(node) {
  return (node.nodeType == 2) ? true : false;
} 

function append_elem(_src, _dst) {
  for (var i = 0; i < _src.childNodes.length; i++)
    _dst.appendChild (_src.childNodes[i].cloneNode (true));
}

function tpl_elem_repl(_src, _dst) {
	if (_dst.hasChildNodes)
      OAT.Dom.clear (_dst);

  append_elem (_src, _dst);
  return _dst;
}

function ODSDOMSwapElem(old_elem, new_elem, tmp) {
  tmp.parentNode.replaceChild (old_elem);
  old_elem.parentNode.replaceChild (new_elem);
  new_elem.parentNode.replaceChild (tmp);
}

function dd(txt) {
	if (typeof console == 'object' && typeof console.debug == 'function')
	    console.debug(txt);
	}

function getMetaContents(metaKey) {
    var m = document.getElementsByTagName ('meta');
	for ( var i in m) {
	    if (m[i].name == metaKey)
		return m[i].content;
	}
    return false;
}

function eTarget(e) {
    if (!e)
	var e = window.event;
  var t = (e.target) ? e.target : e.srcElement;
	if (t.nodeType == 3) // defeat Safari bug
		t = targ.parentNode;
  return t;
}

function onEnterDown(e) {
  if (!e)
    return;

    var keycode = (window.event) ? window.event.keyCode : e.which;
	if (keycode == 13) {
	    var t = eTarget (e);
	    if (typeof (t.callback) == "function")
		t.callback (e);
	    return false;
	}
        return true;
}

function buildObjByAttributes(elm) {
   var obj = {};
	for ( var i = 0; i < elm.attributes.length; i++)
	   obj[elm.attributes[i].nodeName] = OAT.Xml.textValue (elm.attributes[i]);

   return obj;
}

function buildObjByChildNodes(elm) {
   var obj = {};
	for ( var i = 0; i < elm.childNodes.length; i++) {
	   var pName   = elm.childNodes[i].nodeName;
	   var pValue  = OAT.Xml.textValue (elm.childNodes[i]);
	   var pAttrib = elm.childNodes[i].attributes;

		if (!(pName == '#text' && pValue == '\n')) {
		   if (typeof (obj[pName]) == 'undefined')
		       obj[pName] = pValue;
			else {
			   var tmpObj = false;

				if (!(obj[pName] instanceof Array)) {
				   tmpObj = obj[pName];
				   obj[pName]=new Array();
				   obj[pName].push (tmpObj);
				   obj[pName].push (pValue);
				} else
			       obj[pName].push (pValue);
		       }
			if (pAttrib.length > 0) {
			   var tmpVal = false;
				if ((obj[pName] instanceof Array)) {
				   obj[pName][(obj[pName].length-1)] = {};
				   obj[pName][(obj[pName].length-1)]['value'] = pValue;
				} else {
				   obj[pName] = {};
				   obj[pName]['value'] = pValue;
			       }
				for ( var k = 0; k < pAttrib.length; k++) {
				   if ((obj[pName] instanceof Array))
						obj[pName][(obj[pName].length - 1)]['@' + pAttrib[k].nodeName] = OAT.Xml
								.textValue(pAttrib[k]);
				   else
						obj[pName]['@' + pAttrib[k].nodeName] = OAT.Xml
								.textValue(pAttrib[k]);
			       }
		       }
	       }
       }

   obj.selfTextValue=OAT.Xml.textValue(elm);

   return obj;
}

function replaceChild(newElm, oldElm) {
	if (typeof (newElm) == 'undefined' || typeof (oldElm) == 'undefined' || typeof (oldElm.parentNode) == 'undefined')
	return;

    OAT.Dom.hide (oldElm);
    oldElm.parentNode.insertBefore (newElm, oldElm);
    OAT.Dom.unlink (oldElm);
}

function inverseSelected(parentDiv) {
	if (typeof (parentDiv) == 'undefined')
		return;

    var inputCtrls = parentDiv.getElementsByTagName ('input');

	for ( var i = 0; i < inputCtrls.length; i++) {
	    if (inputCtrls[i].type == 'checkbox')
		inputCtrls[i].checked = inputCtrls[i].checked ? false : true;
	}
}

OAT.Preferences.imagePath = "/ods/images/oat/";
OAT.Preferences.stylePath = "/ods/oat/styles/";

window.ODS = {};

ODS.Preferences = {
  imagePath         : "/ods/images/",
  dataspacePath     : "/dataspace/",
  odsHome           : "/ods/",
  root              : document.location.protocol + '//' + document.location.host,
  svcEndpoint       : "/ods_services/Http/",
  activitiesEndpoint: "/activities/feeds/activities/user/",
	version : "10.09.2010"
};

ODS.app = {
	AddressBook : {
		menuName : 'AddressBook',
		icon : 'images/icons/ods_ab_16.png',
		dsUrl : '#UID#/addressbook/'
	},
	Bookmarks : {
		menuName : 'Bookmarks',
		icon : 'images/icons/ods_bookmarks_16.png',
		dsUrl : '#UID#/bookmark/'
	},
	Calendar : {
		menuName : 'Calendar',
		icon : 'images/icons/ods_calendar_16.png',
		dsUrl : '#UID#/calendar/'
	},
	Community : {
		menuName : 'Community',
		icon : 'images/icons/ods_community_16.png',
		dsUrl : '#UID#/community/'
	},
	Discussion : {
		menuName : 'Discussion',
		icon : 'images/icons/apps_16.png',
		dsUrl : '#UID#/discussion/'
	},
	Polls : {
		menuName : 'Polls',
		icon : 'images/icons/ods_poll_16.png',
		dsUrl : '#UID#/polls/'
	},
	Weblog : {
		menuName : 'Weblog',
		icon : 'images/icons/ods_weblog_16.png',
		dsUrl : '#UID#/weblog/'
	},
	FeedManager : {
		menuName : 'Feed Manager',
		icon : 'images/icons/ods_feeds_16.png',
		dsUrl : '#UID#/feed/'
	},
	Briefcase : {
		menuName : 'Briefcase',
		icon : 'images/icons/ods_briefcase_16.png',
		dsUrl : '#UID#/briefcase/'
	},
	Gallery : {
		menuName : 'Gallery',
		icon : 'images/icons/ods_gallery_16.png',
		dsUrl : '#UID#/gallery/'
	},
	Mail : {
		menuName : 'Mail',
		icon : 'images/icons/ods_mail_16.png',
		dsUrl : '#UID#/mail/'
	},
	Wiki : {
		menuName : 'Wiki',
		icon : 'images/icons/ods_wiki_16.png',
		dsUrl : '#UID#/wiki/'
	},
	InstantMessenger : {
		menuName : 'Instant Messenger',
		icon : 'images/icons/ods_wiki_16.png',
		dsUrl : '#UID#/IM/'
	},
	eCRM : {
		menuName : 'eCRM',
		icon : 'images/icons/apps_16.png',
		dsUrl : '#UID#/ecrm/'
	}
};

ODS.ico = {
	addressBook : {
		alt : 'AddressBook',
		icon : 'images/icons/ods_ab_16.png'
	},
	bookmarks : {
		alt : 'Bookmarks',
		icon : 'images/icons/ods_bookmarks_16.png'
	},
	calendar : {
		alt : 'Calendar',
		icon : 'images/icons/ods_calendar_16.png'
	},
	community : {
		alt : 'Community',
		icon : 'images/icons/ods_community_16.png'
	},
	discussion : {
		alt : 'Discussion',
		icon : 'images/icons/apps_16.png'
	},
	polls : {
		alt : 'Polls',
		icon : 'images/icons/ods_poll_16.png'
	},
	weblog : {
		alt : 'Weblog',
		icon : 'images/icons/ods_weblog_16.png'
	},
	feeds : {
		alt : 'Feed Manager',
		icon : 'images/icons/ods_feeds_16.png'
	},
	briefcase : {
		alt : 'Briefcase',
		icon : 'images/icons/ods_briefcase_16.png'
	},
	gallery : {
		alt : 'Gallery',
		icon : 'images/icons/ods_gallery_16.png'
	},
	mail : {
		alt : 'Mail',
		icon : 'images/icons/ods_mail_16.png'
	},
	wiki : {
		alt : 'Wiki',
		icon : 'images/icons/ods_wiki_16.png'
	},
	system : {
		alt : 'ODS',
		icon : 'images/icons/apps_16.png'
	},
	instantmessenger : {
		alt : 'InstantMessenger',
		icon : 'images/icons/ods_im_16.png'
	}
};

ODS.paginator = function(iSet, containerTop, containerBottom, callback, customItemsPerPage) {
    var self = this;

    this.elmTop    = $(containerTop);
    this.elmBottom = $(containerBottom);

	if (!self.elmTop && !self.elmBottom)
		return;

    this.totalItems   = iSet.length;
    this.pages        = false;
    this.currentPage  = false;
    this.startIndex   = false;
    this.endIndex     = false;
    this.iSet         = iSet;
    this.currenISet   = new Array();
	this.idTop = typeof (self.elmTop.id) != 'undefined' ? self.elmTop.id : 'pagerTop';
	this.idBottom = typeof (self.elmBottom.id) != 'undefined' ? self.elmBottom.id : 'pagerBottom';

    this.itemsPerPage = 5;

    if (typeof (customItemsPerPage) == 'number')
	this.itemsPerPage = customItemsPerPage;
	else if (typeof (customItemsPerPage) != 'undefined' && !isNaN(parseInt(customItemsPerPage, 10)))
		this.itemsPerPage = parseInt (customItemsPerPage, 10);

	this.first = function() {
		if (self.currentPage == 1)
			return;

	self.go (1);
    };

	this.last = function() {
		if (self.currentPage == (self.pages))
			return;

	self.go (self.pages);
    };

	this.prev = function() {
		if (self.currentPage == 1)
			return;

	self.go (self.currentPage - 1);
    };

	this.next = function() {
		if (self.currentPage == (self.pages))
			return;

	self.go (self.currentPage + 1);
    };

	this.go = function(pageNum) {
	if (typeof (pageNum) != 'number' || pageNum < 0)
	    return;

		if (this.totalItems == 0) {
		self.pages        = false;
		self.currentPage  = false;
		self.startIndex   = false;
		self.endIndex     = false;
		} else if (self.totalItems <= self.itemsPerPage) {
		    self.pages        = 1;
		    self.currentPage  = 1;
		    self.startIndex   = 1;
		    self.endIndex     = self.totalItems;
		} else {
		    self.pages = Math.ceil (self.totalItems / self.itemsPerPage);

			var startIndex = pageNum * self.itemsPerPage
					- (self.itemsPerPage - 1);
		    if (startIndex > this.totalItems)
			startIndex = this.totalItems;

		    var endIndex = startIndex + (self.itemsPerPage - 1);
			if (endIndex > this.totalItems)
				endIndex = this.totalItems;

		    self.startIndex = startIndex;
		    self.endIndex = endIndex;

		    self.currenISet = new Array();

		    var i = 0;

			for ( var idx = startIndex; idx <= endIndex; idx++) {
			    self.currenISet[i] = self.iSet[idx];
			    i++;
			}

		    self.currentPage = pageNum;
		}

		if (self.elmTop) {
		var newElmTop = self.paginatorCtrl (self.idTop);
		replaceChild (newElmTop, self.elmTop)
		self.elmTop = newElmTop;
	    }

		if (self.elmBottom) {
		var newElmBottom = self.paginatorCtrl (self.idBottom);
		replaceChild (newElmBottom, self.elmBottom)
		self.elmBottom = newElmBottom;

	    }

	if (typeof (callback) == 'function')
	    callback (self);
    };

	this.paginatorCtrl = function(divId) {
		var settings = {
			first : {
				txt : 'first',
				txtAlt : 'First page',
				imgE : 'p_first.png',
				imgD : 'p_first_gr.png'
			},
			prev : {
				txt : 'prev',
				txtAlt : 'Previous page',
				imgE : 'p_prev.png',
				imgD : 'p_prev_gr.png'
			},
			next : {
				txt : 'next',
				txtAlt : 'Next page',
				imgE : 'p_next.png',
				imgD : 'p_next_gr.png'
			},
			last : {
				txt : 'last',
				txtAlt : 'Last page',
				imgE : 'p_last.png',
				imgD : 'p_last_gr.png'
			},
			skinBase : 'images/skin/pager/'
		};

		function elmCtrl(elmType, disabled) {

			if (typeof (settings[elmType]) == 'undefined')
				return false;

	    var isD = 0;
			if (typeof (disabled) != undefined && disabled == 1)
		isD = 1;

	    var elmA = false;

			if (isD) {
		    elmA = OAT.Dom.create ('a');
		    var elmImg = OAT.Dom.create ('img');
		    elmImg.src = settings.skinBase + settings[elmType].imgD;
		    elmImg.alt = settings[elmType].txtAlt;
			} else {
		    elmA = OAT.Dom.create ('a');
		    elmA.action = elmType;
				OAT.Event.attach(elmA, "click", function(e) {
					var t = eTarget(e);
					self[t.action]();
				});
		    var elmImg = OAT.Dom.create ('img');
		    elmImg.action = elmType;
		    elmImg.src = settings.skinBase + settings[elmType].imgE;
		    elmImg.alt = settings[elmType].txtAlt;

		}

			OAT.Dom.append( [ elmA, elmImg, OAT.Dom.text(settings[elmType].txt)]);
	    return elmA;
	}

	var pagerDiv = OAT.Dom.create ('div', {}, 'pager');
	pagerDiv.id = divId;
	pagerDiv.paginator = self;

		if (self.totalItems > 1) {
			var resultsTxt = 'Results ' + self.startIndex + ' - '
					+ self.endIndex + ' of ' + self.totalItems + ':';
		} else
	    var resultsTxt = 'Results 0';

	var firstA = elmCtrl ('first',1);
	var prevA  = elmCtrl ('prev',1);
	var nextA  = elmCtrl ('next',1);
	var lastA  = elmCtrl ('last',1);

		if (self.pages > 1) {
			if (self.currentPage > 1) {
			firstA = elmCtrl ('first');
			prevA  = elmCtrl ('prev');
		    }
			if (self.currentPage < self.pages) {
			nextA = elmCtrl ('next');
			lastA = elmCtrl ('last');
		    }
	    }

		OAT.Dom.append( [ pagerDiv, OAT.Dom.text(resultsTxt), firstA, prevA,
				nextA, lastA ]);

	return pagerDiv;
    }

    this.first ();
};

ODS.session = function(customEndpoint) {
    var self = this;

    this.sid           = false;
    this.realm         = 'wa';
    this.userName      = false;
    this.userId        = false;
    this.userIsDba     = false;
    this.connections   = false;
    this.connectionsId = false;
    this.invitationsId = false;

    this.endpoint = ODS.Preferences.svcEndpoint;
  if (typeof (customEndpoint) != 'undefined' && length (customEndpoint))
	this.endpoint = customEndpoint;

	this.validateSid = function() {
	var data = 'sid=' + self.sid + '&realm=wa';
		var callback = function(xmlString) {
	    var xmlDoc = OAT.Xml.createXmlDoc (xmlString);
			if (!self.isErr(xmlDoc)) {
				self.userName = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/sessionValidate_response/userName', {})[0]);
				self.userId = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/sessionValidate_response/userId', {})[0]);
				self.userIsDba = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/sessionValidate_response/dba', {})[0]);
		    OAT.MSG.send (self, "WA_SES_VALIDBIND", {});
			} else {
		    self.sid = false;
        	    OAT.MSG.send (self, "WA_SES_INVALID", {});
		}
	};
		OAT.AJAX.POST(self.endpoint + "sessionValidate", data, callback, options);
    };

	this.end = function() {
	var data = 'sid=' + self.sid;
		var callback = function(xmlString) {
	    var xmlDoc = OAT.Xml.createXmlDoc (xmlString);

			if (!self.isErr(xmlDoc)) {
		    self.sid       = false;
		    self.userName  = false;
		    self.userId    = false;
		    self.userIsDba = false;
				OAT.MSG.send(self, "WA_SES_INVALID", {sessionEnd: true});
		}
	};
	OAT.AJAX.POST (self.endpoint+"sessionEnd", data, callback, options);
    };

	this.usersGetInfo = function(users, fields, callbackFunction) {
		var data = 'sid=' + self.sid + '&realm=' + self.realm + '&usersStr='
				+ encodeURIComponent(users) + '&fieldsStr='
				+ encodeURIComponent(fields);

		var callback = function(xmlString) {
	    var xmlDoc = OAT.Xml.createXmlDoc (xmlString);

			if (!self.isErr(xmlDoc)) {
		    if (typeof (callbackFunction) == "function")
			callbackFunction (xmlDoc);
		}
	};

	OAT.AJAX.POST (self.endpoint + "usersGetInfo", data, callback, options);
    };

	this.isErr = function(xmlDoc) {
	var errXmlNodes = OAT.Xml.xpath (xmlDoc, '//error_response', {});
		if (errXmlNodes.length) {
			var errCode = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/error_response/error_code', {})[0]);
			var errMsg = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/error_response/error_msg', {})[0]);
		dd ('ERROR - msg: ' + errMsg + ' code: ' + errCode);
		return 1;
	    }
	    return 0;
    };

	this.connectionAdd = function(connectionId, connectionFullName) {
	var connection = {};
	connection[connectionId] = connectionFullName;

	if (!self.connections)
	    self.connections = new Array();

	self.connections.push (connection);

	if (!self.connectionsId)
	    self.connectionsId = new Array();

	self.connectionsId.push (connectionId);
    };

	this.connectionRemove = function(connectionId) {
	var arrPos = self.connectionsId.find (connectionId);

		if (arrPos > -1) {
		var newArr = new Array ();
		newArr = newArr.concat (self.connectionsId.slice (0, arrPos));
			newArr = newArr.concat(self.connectionsId.slice(arrPos + 1,
					self.connectionsId.length));

		self.connectionsId = newArr;

			for ( var i = 0; i < self.connections.length; i++) {
			var done=false;
				for (connId in self.connections[i]) {
					if (connId == connectionId) {
					var newArr = new Array();
					newArr = newArr.concat (self.connections.slice (0, i));
						newArr = newArr.concat(self.connections.slice(i + 1,
								self.connections.length));

					self.connections = newArr;
					done = true;
				    }
			    }
				if (done)
					break;
		    }
	    }
    };

	this.invitationAdd = function(invitationId) {
	self.invitationsId = self.arrAddElm (self.invitationsId, invitationId);
    };

	this.invitationRemove = function(invitationId) {
		self.invitationsId = self.arrRemoveElm(self.invitationsId, invitationId);
    };

    // XXX: Looks like generic util functions which should not be session methods

	this.arrAddElm = function(arr, elmId) {
	if (!arr)
	    arr = new Array ();
		else if (typeof (arr) != 'object' || (typeof (arr) == 'object' && typeof (arr.push) != 'function'))
		return;

	arr.push (elmId);

	return arr;
    };

	this.arrRemoveElm = function(arr, elmId) {
		if (typeof (arr) != 'object' || (typeof (arr) == 'object' && typeof (arr.find) != 'function'))
	    return;

    var arrPos = arr.find (elmId);

		if (arrPos > -1) {
	    var newArr = new Array();
	    newArr = newArr.concat (arr.slice (0, arrPos));
	    newArr = newArr.concat (arr.slice (arrPos + 1, arr.length));

	    arr = newArr;
	}
	return arr;
    };
}; // ODS.Session

ODS.Nav = function(navOptions) {
    var self           = this;
    this.ods           = ODS.Preferences.odsHome;
    this.dataspace     = ODS.Preferences.dataspacePath;
//  this.uriqaDefaultHost=false;
	this.serverOptions = {
		uriqaDefaultHost : false,
		useRDFB : 0
	};
    this.leftbar       = $(navOptions.leftbar);
    this.rightbar      = $(navOptions.rightbar);
    this.appmenu       = $(navOptions.appmenu);
    this.logindiv      = false;
    this.msgDock       = false;
    this.userLogged    = 0;
	this.options = {
		imagePath : ODS.Preferences.imagePath
	};
    this.ui            = {};
    this.defaultAction = false;
    this.session       = new ODS.session ();
  this.loading_app_menu_elem = false;
  this.throbberImg = false;
  this.appIconSave = false;
  this.appIconSaveBag = false;
  this.alog = true;
	this.profile = {
		userName : false,
			  userId       : false,
			  userFullName : false,
			  connections  : new Array(),
			  ciTab        : false,
			  ciMap        : false,
		connTab : false,
			  msgTab       : false,
			  show         : false,
		dataspace : {
			userName : false,
			userId : false
		},
			personal_uri : false,
			sioc_uri     : false,
			foaf_uri: false,
		set : function(profileId) {
			this.userName = false;
							        this.userId   = profileId;
							        userFullName  = false;
			this.connections = new Array();
		}
    };

	this.connections = {
		userId : false,
		show : false
	};

	this.searchObj = {
		qStr : false,
		map : false,
		tab : false
	};

	OAT.MSG.attach(
	  self.session,
	  "WA_SES_VALIDBIND",
	  function() {
			self.createCookie ('sid', self.session.sid, 1);
			self.userLogged = 1;
  		self.session.usersGetInfo(self.session.userId, 'fullName', function(xmlDoc) {
			self.setLoggedUserInfo(xmlDoc);
		});
  		self.connectionsGet(self.session.userId, 'fullName,photo,homeLocation,dataspace', function(xmlDocRet) {
					self.updateConnectionsSession(xmlDocRet);
				});
			self.initLeftBar ();
			self.initRightBar ();
			self.initAppMenu ();

			self.connections.userId = self.session.userId;

			OAT.Dimmer.hide();
  		OAT.MSG.send(self.session, "WA_SES_VALIDATION_END", {sessionValid: 1});
  	}
  );

	OAT.MSG.attach(
	  self.session,
	  "WA_SES_INVALID",
	  function(src, msg, event) {
			self.showLoginThrobber ('hide');
			if ($('loginBtn'))
			    $('loginBtn').disabled = false;

			if ($('signupBtn'))
			    $('signupBtn').disabled = false;

			if ($('loginCloseBtn'))
			    OAT.Dom.show ($('loginCloseBtn'));

			self.createCookie ('sid', '', 1);

		if (typeof (event.retryLogIn) != 'undefined' && event.retryLogIn == true) {
				self.wait('hide');

				if (typeof (event.msg) != 'undefined' && event.msg.length>0)
				    self.showLoginErr (event.msg);
				else
				    self.showLoginErr ();

				if (!$('loginDiv'))
				    self.logIn ();
		} else {
  			if (typeof (event.sessionEnd) != 'undefined' && event.sessionEnd == true) {
				   document.location.hash = '';
				   document.location.href = 'index.html';
			} else {
				OAT.MSG.send(self.session, "WA_SES_VALIDATION_END", {sessionValid: 0});
			}
    }
  	}
	);
	OAT.MSG.attach(
	  self.session,
					"WA_SES_VALIDATION_END",
					function(src, msg, event) {
			self.showLoginThrobber ('hide');
						if (typeof (self.defaultAction) == 'function') {
				self.defaultAction ();
				self.defaultAction = false;
			    }

			// XXX
			var q_pos = document.location.href.indexOf ('?');
			var pos1 = document.location.href.indexOf('/dataspace/person/');
			var pos2 = document.location.href.indexOf('/dataspace/organization/');

			if (q_pos > -1 && pos1 > q_pos) 
			    pos1 = -1;

			if (q_pos > -1 && pos2 > q_pos) 
			    pos2 = -1;

					if (pos1 > -1 || pos2 > -1) {
				var profileId = document.location.href.split ('/')[5];
				profileId = profileId.split ('#')[0];

				var profileType = profileId.split ('/')[4];
				self.profile.show = true;

						if (self.session.sid
								&& self.session.userName == self.profile.userName
								&& self.session.userName == profileId) {
					self.showProfile ();
						} else {
					var metaProfileId = getMetaContents ('dataspaceid');

							if (!metaProfileId) {
					    self.profile.set ('/' + profileId);
							} else {
						self.profile.set (metaProfileId);
						self.profile.dataspace.userId = metaProfileId;
						self.profile.dataspace.userName = profileId;
					    }
					self.initProfile ();
				    }
				return;
			    }
					if (document.location.hash.length > 0) {
				defaultAction = document.location.hash;
						if (defaultAction == '#invitations') {
							if (self.session.userName) {
						self.invitationsGet('fullName,photo,home',self.renderInvitations);
						document.location.href = document.location.href.split('#')[0] + '#';
							} else {
					    self.logIn ();
				    }
				}
				else if (defaultAction.indexOf('#/person/') > -1 || defaultAction.indexOf('#/organization/') > -1)
				{
					var profileId = document.location.href.split ('#')[1];
					document.location.href = document.location.href.split('#')[0] + '#';

					var profileType = profileId.split ('/')[1];
					profileId = profileId.split ('/')[2];

					self.profile.show = true;
							if (!self.session.sid
									|| (self.session.sid && self.session.userName != profileId)) {
						self.profile.set ('/' + profileId);
						self.initProfile();
					    }
				}
				else
				{
							if (defaultAction.indexOf('#msg') > -1) {
					    var msg = defaultAction.replace('#msg=','');
					    self.dimmerMsg (msg);

						self.loadVspx(self.frontPage());
						document.location.href = document.location.href.split('#')[0] + '#';
							} else if (defaultAction.indexOf('#fhref') > -1) {
						var fhref = defaultAction.replace('#fhref=', '');
					    self.loadVspx (self.expandURL (fhref));
						document.location.href = document.location.href.split('#')[0] + '#';
							} else {
						self.loadVspx(self.frontPage());
  			}
      }
			}
			else
			{
				self.loadVspx(self.frontPage());
  		}
		}
	);

	OAT.MSG.attach(
	  self,
	  "WA_PROFILE_UPDATED",
	  function() {
			if (self.profile.show)
			    self.showProfile ();
			self.profile.show = false;
			//			self.profile.ciMap.expandMap ();
		}
	);

	OAT.MSG.attach(
	  self,
	  "WA_CONNECTIONS_UPDATED",
	  function() {
			if (self.connections.show)
			    self.showConnections ();
			self.connections.show = false;
	  }
	);

	this.setLoggedUserInfo = function(xmlDoc) {
		var userDisplayName = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/fullName', {})[0]);
	if (userDisplayName == '')
	    userDisplayName = self.session.userName;
	$('aUserProfile').innerHTML = userDisplayName;
    };

	this.initAppMenu = function() {
	var rootDiv = self.appmenu;

	OAT.Dom.clear (rootDiv);

	if (!self.session.userName)
	    return;

    var appTitle = OAT.Dom.create ("h3");
	appTitle.id = 'APP_MENU_T';

    var appTitleApplicationA = OAT.Dom.create ("a");
    appTitleApplicationA.id = 'APP_MENU_LNK';
	appTitleApplicationA.innerHTML = 'Applications';

    var appTitleEditA = OAT.Dom.create ("a", {}, 'lnk');
	appTitleEditA.innerHTML='edit';

    OAT.Event.attach (appTitleEditA, "click", function () {
			      self.loadVspx (self.expandURL (self.ods + 'services.vspx'));
			  });

		OAT.Dom.append( [ rootDiv, appTitle ], [ appTitle, appTitleApplicationA, OAT.Dom.text(' '), appTitleEditA ]);

	var ulApp = OAT.Dom.create ("ul");
	ulApp.id = 'APP_MENU';
	OAT.Dom.append ([rootDiv,ulApp]);

	var ftApp = OAT.Dom.create ('div');
	ftApp.id='APP_MENU_FT';

	var ftAppA=OAT.Dom.create ('a');
	ftAppA.href='javascript:void(0)';
	ftAppA.innerHTML='More...';

    OAT.Event.attach (ftAppA, "click", function () {
			      self.loadVspx (self.expandURL ('admin.vspx'));
			  });
	OAT.Dom.append ([rootDiv, ftApp], [ftApp, ftAppA]);

		function renderAppNav(xmlDoc) {
			var resXmlNodes = OAT.Xml.xpath(xmlDoc, '//installedPackages_response/application', {});

			for ( var i = 0; i < resXmlNodes.length; i++) {
       		    var packageName = OAT.Xml.textValue (resXmlNodes[i]);
		    packageName = packageName.replace (' ','');

        var appOpt;
		    if (typeof (ODS.app[packageName]) != 'undefined')
			appOpt = ODS.app[packageName];
		    else
					appOpt = {
						menuName : packageName,
						icon : 'images/icons/apps_16.png',
						dsUrl : '#UID#/' + packageName + '/'
					};

		    var appMenuItem = OAT.Dom.create ('li');
	  var appMenuItemA = OAT.Dom.create ('a');
		    appMenuItemA.packageName = packageName;
		    appMenuItemA.id = packageName + '_menuItem';
				OAT.Event.attach(appMenuItemA, "click", function(e) {
				var t = eTarget (e);
          if (t.tagName == 'IMG')
            t = t.parentNode;
				self.show_app_throbber (t.parentNode);
            self.checkApplication (t.packageName, self.appCheck);
				});
		    var appMenuItemImg = OAT.Dom.create ('img');
		    appMenuItemImg.className = 'app_icon';
		    appMenuItemImg.src = appOpt.icon;

//exception - items that should not be shown
				if (appOpt.menuName != 'Community') {
					OAT.Dom.append( [ ulApp, appMenuItem ], [ appMenuItem,
							appMenuItemA ], [ appMenuItemA, appMenuItemImg,
							OAT.Dom.text(' ' + appOpt.menuName) ]);
				} else {
			    $('communities_menu').isInstalled = true;
			}
		}
	}
    self.installedPackages (renderAppNav);
  }

	this.appCheck = function(xmlDoc) {
		var url = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc,
				'/createApplication_response/application/url|/checkApplication_response/application/url', {})[0]);
	self.loadVspx (self.expandURL (url));
	self.wait ();
    };

	this.initLeftBar = function() {
	rootDiv = self.leftbar;
	OAT.Dom.clear (rootDiv);
		var a = OAT.Dom.create('a', {})
		a.href = '';
		a.id = 'ODS_HOME_LNK';
		a.innerHTML = '<img class="ods_logo" src="images/odslogosml_new.png" alt="Site Home"/>';
	  OAT.Event.attach(a, "click", function() {self.loadVspx(self.frontPage());});
		OAT.Dom.append( [ rootDiv, a ]);
    };

	this.initRightBar = function() {
	var rootDiv = self.rightbar;

	var profileMenuDiv = $('profile_menu');

		if (profileMenuDiv) {
		OAT.Dom.hide ($('profile_menu'));
		OAT.Dom.clear ($('profile_menu'));

			var profileMenuAProfile = OAT.Dom.create('a', {
				cursor : 'pointer',
				paddingRight : '3px'
			}, 'menu_link profile');
		profileMenuAProfile.innerHTML = 'Profile';
      OAT.Event.attach (profileMenuAProfile, "click", function() {
				      self.profile.show = true;
				      self.profile.set (self.session.userId);
				      self.initProfile ();
				  });

			var profileMenuAProfileEdit = OAT.Dom.create('a', {
				cursor : 'pointer'
			}, 'menu_link profile_edit shortcut');
		profileMenuAProfileEdit.innerHTML = 'edit';
      OAT.Event.attach (profileMenuAProfileEdit, "click", function () {
				self.loadCheckedVspx(self.expandURL(self.ods + 'uiedit.vspx'));
				  });

		if (self.session.userName)
				OAT.Dom.append( [ profileMenuDiv, profileMenuAProfile,
						profileMenuAProfileEdit ]);
			else {
			if (self.profile.userName)
			    OAT.Dom.append ([profileMenuDiv, profileMenuAProfile]);
			}
			;
		OAT.Dom.show ($('profile_menu'));
	    }

	OAT.Dom.hide ($('communities_menu').parentNode);
	var communityMenuBodyUl = $('communities_menu_body');

		function renderCommunityMenu(xmlDoc) {
	    OAT.Dom.clear (communityMenuBodyUl);

			var packageInstalled = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '//userCommunities_response/community_package', {})[0]);
			if (packageInstalled == 0) {
		    OAT.Dom.hide ($('communities_menu'));
		    return;
		}

			var communities = OAT.Xml.xpath(xmlDoc, '//userCommunities_response/community', {});
			for ( var i = 0; i < communities.length; i++) {
		    var communityMenuBodyLi = OAT.Dom.create ('li',{},'menu_item');
				var communityMenuBodyLiA = OAT.Dom.create('a', {cursor: 'pointer'});

				communityMenuBodyLiA.innerHTML = OAT.Xml.textValue(communities[i].childNodes[0]);
				communityMenuBodyLiA.homepage = OAT.Xml.textValue(communities[i].childNodes[1]);

				OAT.Event.attach(communityMenuBodyLiA, "click", function(e) {
					  var t = eTarget(e);
					  self.loadVspx (self.expandURL (t.homepage));
				      });

				OAT.Dom.append( [ communityMenuBodyUl, communityMenuBodyLi ], [communityMenuBodyLi, communityMenuBodyLiA ]);
		}

			if (i == 0 && !self.session.userName) {
		    OAT.Dom.hide ($('communities_menu'));
		    return;
		}

			if (self.session.userName) {
				var communityMenuBodyLi = OAT.Dom.create('li', {},
						'menu_separator');
		    OAT.Dom.append ([communityMenuBodyUl, communityMenuBodyLi]);

		    var communityMenuBodyLi  = OAT.Dom.create ('li', {}, 'menu_item');
				var communityMenuBodyLiA = OAT.Dom.create('a', {cursor : 'pointer'});
		    communityMenuBodyLiA.innerHTML = 'Join a community now';
		    communityMenuBodyLiA.homepage = 'search.vspx?apps=apps&q=Community';

				OAT.Event.attach(communityMenuBodyLiA, "click", function(e) {
					  var t = eTarget (e);
					  self.loadVspx (self.expandURL (t.homepage));
				      });

				OAT.Dom.append( [ communityMenuBodyUl, communityMenuBodyLi ], [
						communityMenuBodyLi, communityMenuBodyLiA ]);

		    var communityMenuBodyLi  = OAT.Dom.create ('li', {}, 'menu_item');
				var communityMenuBodyLiA = OAT.Dom.create('a', {cursor : 'pointer'});

		    communityMenuBodyLiA.innerHTML = 'Create a community';
		    communityMenuBodyLiA.homepage  = 'index_inst.vspx?wa_name=Community';

				OAT.Event.attach(communityMenuBodyLiA, "click", function(e) {
					  var t = eTarget (e);
					  self.loadVspx (self.expandURL (t.homepage));
				      });
				OAT.Dom.append( [ communityMenuBodyUl, communityMenuBodyLi ], [
						communityMenuBodyLi, communityMenuBodyLiA ]);
		}

	    $('communities_menu_body').style.zIndex = 100;

	    var communityMenu = new OAT.Menu ();

	    communityMenu.noCloseFilter = 'menu_separator';
	    communityMenu.createFromUL ("communities_menu");

	    OAT.Dom.show ($('communities_menu').parentNode);

	    self.wait ('hide');
	    return;
	}

	this.userCommunities (renderCommunityMenu);

//Community menu interface create END

	OAT.Dom.hide ($('messages_menu').parentNode);

		function renderMessagesMenu(xmlDoc) {

	    msgMenuItems = $('messages_menu_items');
	    msgMenuItems.style.zIndex = 101;
			for ( var i = 0; i < msgMenuItems.childNodes.length; i++) {
				if (msgMenuItems.childNodes[i].nodeName == 'LI') {
			    if (msgMenuItems.childNodes[i].id=='mi_inbox')
				OAT.Event.attach (msgMenuItems.childNodes[i],"click",
						  function () {
						      self.profile.msgTab.go(0);
						      self.showMessages ();
						  });
					else if (msgMenuItems.childNodes[i].id == 'mi_sent')
				    OAT.Event.attach (msgMenuItems.childNodes[i],"click",
						      function () {
							  self.profile.msgTab.go (1);
							  self.showMessages ();
						      });
					else if (msgMenuItems.childNodes[i].id == 'mi_notification')
					OAT.Event.attach (msgMenuItems.childNodes[i], "click",
							  function () {
							      self.profile.msgTab.go (3);
							      self.showMessages ();
							  });
					else if (msgMenuItems.childNodes[i].id == 'mi_new_message')
					    OAT.Event.attach (msgMenuItems.childNodes[i], "click",
							      function () {
								  self.profile.msgTab.go (4);
								  self.showMessages ();
							      });
			}
		}

			var newMsgCount = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '//userMessages_response/new_message_count', {})[0]);
	    $('newMsgCountSpan').innerHTML='('+newMsgCount+')';

	    var messagesMenu = new OAT.Menu ();
	    messagesMenu.noCloseFilter = 'menu_separator';
	    messagesMenu.createFromUL ("messages_menu");

			OAT.Style.include(location.protocol + '//' + location.host + '/ods/dock.css');
	    OAT.Dom.show ($('messages_menu').parentNode);

			OAT.Loader.load( [ "dock" ], function() {
					 self.userMessages (1, renderMessagesInterface);
//                                                  setInterval(function(){self.userMessages(1,renderMessagesInterface);},10000);
				     });
	    self.wait('hide');
	    return;
	}

		function renderMessagesInterface(xmlDoc) {
			if (!self.profile.msgTab) {
		    var msgTab = new OAT.Tab ('msgPCtr');
		    msgTab.add ('msgT1', 'msgP1');
		    msgTab.add ("msgT2", "msgP2");
		    msgTab.add ('msgT3', 'msgP3');
		    msgTab.add ("msgT4", "msgP4");
		    msgTab.add ("msgT5", "msgP5");
		    msgTab.go (0);

		    self.profile.msgTab = msgTab;
		}

			OAT.Event.attach('msgT1', "click", function() {
				self.userMessages(2, renderInboxBlock);
			});
			OAT.Event.attach('msgT2', "click", function() {
				self.userMessages(3, renderSentBlock);
			});
			OAT.Event.attach('msgT3', "click", function() {
				self.userMessages(1, renderConversationBlock);
			});

//      OAT.Dom.clear($('msgP5'));

	    if (! $('sendBlock'))
		OAT.Dom.append ([$('msgP5'),renderSendBlock ()]);

	    $('sendBlock').style.width = OAT.Dom.getWH ($('APP'))[0] - 6 + 'px';

	    var updateDock = false;
	    if (!self.msgDock)
		self.msgDock = new OAT.Dock ('messages_div',2);
			else {
		    updateDock = true;
				for ( var i = 0; i < self.msgDock.windows.length; i++) {
			    var dockTitle = self.msgDock.windows[i].options.title;
					if (dockTitle == 'Inbox' || dockTitle == 'Sent'
							|| dockTitle == 'Conversation') {
						self.msgDock.windows[i].dock
								.removeObject(self.msgDock.windows[i]);
				    i--;
				}
			}
		}

	    var dock = self.msgDock

      // hide dock control for now

	    OAT.Dom.hide (dock.columns[0]);
	    OAT.Dom.hide (dock.columns[1]);

      // remove these lines to show dock control.

	    var titleBGColor="#336699";
	    var titleTxtColor="#fff";

			function renderMsgNavBlock() {
		var container = OAT.Dom.create ("div");
				var showSendA = OAT.Dom.create('a', {
					cursor : 'pointer'
				});
	
		showSendA.blockId = 'sendBlock';
				OAT.Event.attach(showSendA, "click", function(e) {
				      var t = eTarget (e);
				      if ($(t.blockId))
					  return;
					dock.addObject(0, renderSendBlock(), {
						color : titleBGColor,
						       title      : 'New message',
						titleColor : titleTxtColor
					});
				  });

		OAT.Dom.append ([showSendA, OAT.Dom.text ('New message')]);

				var showInboxA = OAT.Dom.create('a', {
					cursor : 'pointer'
				});
		showInboxA.blockId = 'inboxBlock';

				OAT.Event.attach(showInboxA, "click", function(e) {
				      var t = eTarget (e);
				      if ($(t.blockId))
					  return;
				      inboxDock = false;
				      inboxDock = renderInboxBlock (xmlDoc);
				  });

		OAT.Dom.append ([showInboxA, OAT.Dom.text ('Inbox')]);

				var showSentA = OAT.Dom.create('a', {
					cursor : 'pointer'
				});
		showSentA.blockId = 'sentBlock';

				OAT.Event.attach(showSentA, "click", function(e) {
				      var t = eTarget (e);
				      if ($(t.blockId))
					  return;
				      sentDock = false;
				      sentDock = renderSentBlock (xmlDoc);
				  });
		OAT.Dom.append ([showSentA, OAT.Dom.text ('Sent')]);

				var showConversationA = OAT.Dom.create('a', {
					cursor : 'pointer'
				});
		showConversationA.blockId = 'conversationBlock';

				OAT.Event.attach(showConversationA, "click", function(e) {
				      var t = eTarget (e);

				      if ($(t.blockId))
					  return;

				      conversationDock = false;
				      conversationDock = renderConversationBlock (xmlDoc);
				  });

				OAT.Dom.append( [ showConversationA,
						OAT.Dom.text('Conversation') ]);

		OAT.Dom.append ([container, showSendA, OAT.Dom.text (' | '),
				 showInboxA, OAT.Dom.text (' | '), showSentA,
				 OAT.Dom.text (' | '), showConversationA]);
		return container;
	    }

			if (!updateDock) {
				var msgNavDock = dock.addObject(0, renderMsgNavBlock(), {
					color : titleBGColor,
									       title      : 'Show dashboard',
					titleColor : titleTxtColor
				});
		    OAT.Dom.unlink (msgNavDock.close.firstChild);
		}

			function renderSendBlock() {
				var container = OAT.Dom.create("div", {
					textAlign : 'center'
				});
		container.id = 'sendBlock';

				var _span = OAT.Dom.create('span', {
					cssFloat : 'left',
					padding : '5px 0px 0px 5px'
				});
		_span.innerHTML = 'To:';

				var msgUserSpan = OAT.Dom.create('span', {
					width : '45%',
							   cssFloat  : 'left',
							   textAlign : 'left',
					padding : '5px 0px 0px 5px'
				});

		msgUserSpan.id = 'msgUserSpan';

				var userList = OAT.Dom.create("select", {
					width : '45%',
							  cssFloat : 'right',
					margin : '0px 3px 5px 0px'
				});

		userList.id = 'userList';

		OAT.Dom.option ('&lt;Select recipient&gt;', -1, userList);

				for ( var i = 0; i < self.session.connections.length; i++) {
					for (cId in self.session.connections[i]) {
						OAT.Dom.option(self.session.connections[i][cId], cId,
								userList);
			    }
		    }

				OAT.Event
						.attach(
								userList,
								"change",
				  function (e) {
				      var t = eTarget (e);
				      if (t.options [t.selectedIndex].value == -1)
					  $('msgUserSpan').innerHTML = '';
				      else
					  $('msgUserSpan').innerHTML = t.options[t.selectedIndex].text;

				      $('sendBtn').sendto = t.options[t.selectedIndex].value;
				  });

				OAT.Event.attach(userList, "click", function(e) {
					userList.style.color = '#000';
				});

				var msgText = OAT.Dom.create('textarea', {
					width : '99%'
				});

		msgText.id = 'msgText';

		var sendBtn = OAT.Dom.create ('input');

		sendBtn.id     = 'sendBtn';
		sendBtn.type   = 'button';
		sendBtn.sendto = -1;
		sendBtn.value  = 'Send';

				OAT.Event.attach(sendBtn, "click", function(e) {
				      var t = eTarget (e);

					if (t.sendto == -1) {
					      userList.style.color = '#f00';
					      userList.focus ();
					      return;
					  }

					if ($('msgText').value.length == 0) {
					      $('msgText').focus();
					      return;
					  }

				      userList.style.color = '#000';

					self.userMessageSend(t.sendto, $('msgText').value, false,
							    function () {
								self.userMessages (1, renderMessagesInterface);
							    });
				  });

				var msgSentTxt = OAT.Dom.create('span', {
					color : 'green',
							  cssFloat : 'right',
							  padding  : '0px 5px 0px 0px',
							  display  : 'none',
					marginTop : '-18px'
				});

		msgSentTxt.id = 'msgSentTxt';
		msgSentTxt.innerHTML = " Message sent! ";

				OAT.Dom.append( [ container, _span, msgUserSpan, userList,
						OAT.Dom.create('br'), msgText, OAT.Dom.create('br'),
						sendBtn, msgSentTxt ]);

		return container;
	    }

			if (!updateDock) {
				var sendDock = dock.addObject(0, renderSendBlock(), {
					color : titleBGColor,
									   title      : 'New message',
					titleColor : titleTxtColor
				});
		}

			function renderInboxBlock(xmlDoc) {
		var container = OAT.Dom.create ("div");
		container.id = 'inboxBlock';

		var containerTab = OAT.Dom.create ("div");
		containerTab.id = 'inboxTab';

				var messages = OAT.Xml.xpath(xmlDoc,
						'//userMessages_response/message', {});

				for ( var i = 0; i < messages.length; i++) {
			var msg = buildObjByChildNodes (messages[i]);
					if (msg.recipient['@id'] == self.session.userId) {
						var div = OAT.Dom.create('div', {
							overflow : 'auto',
								 width        : '100%',
							borderBottom : '1px dotted #DDDDDD'
						}, 'msg');

						div.innerHTML = '<span class="time">'
								+ msg.received.substr(0, 10)
								+ ' '
								+ msg.received.substr(11, 5)
								+ '</span><span style="font-style:italic"> From: '
								+ msg.sender.value + '</span> - ' + msg.text;

				var divC = OAT.Dom.create ('div',{},'msg_item');
						divC.innerHTML = '<img style="width:16px;height:16px;cursor:pointer;float:right;"'
								+ ' src="images/skin/default/notify_remove_btn.png">'
								+ '<span class="time">'
								+ msg.received.substr(0, 10)
								+ ' '
								+ msg.received.substr(11, 5)
								+ '</span><span style="font-style: italic"> From: '
				    + msg.sender.value + '</span> - ' + msg.text;

				ctrl_hide = divC.getElementsByTagName ('img')[0];
				ctrl_hide.msgId = msg.id;
						OAT.Event
								.attach(
										ctrl_hide,
										"click",
						  function (e) {
						      var t = eTarget (e);
											self.userMessageStatusSet(
															t.msgId,
															-1,
										 function () {
																OAT.Dom.unlink(t.parentNode);
																var msgCount = $('newMsgCountSpan').innerHTML
																		.substring(
																				1,
																				$('newMsgCountSpan').innerHTML.length - 1);
																$('newMsgCountSpan').innerHTML = '(' + (msgCount - 1) + ')';
																self.wait('hide');
										 });
						  });

				OAT.Dom.append ([container, div]);
				OAT.Dom.append ([containerTab, divC]);
			    }
		    }

				if (messages.length == 0) {
	    var div = OAT.Dom.create ('div', {
	      overflow    : 'auto',
							  width       : '100%',
							  height      : '20px',
							  paddingLeft : '10px',
						borderBottom : '1px dotted #DDDDDD'
					}, 'msg');

			div.innerHTML = 'You have no messages.';
			OAT.Dom.append ([containerTab,div]);
		    }


		OAT.Dom.clear ($('msgP1'));
		OAT.Dom.append ([$('msgP1'), containerTab]);

		self.wait ('hide');

				if (inboxDock) {
			OAT.Dom.clear (inboxDock.div);
			OAT.Dom.append ([inboxDock.div, container]);
			return inboxDock;
				} else {
					var newDock = dock.addObject(1, container, {
						color : titleBGColor,
								     title:'Inbox',
						titleColor : titleTxtColor
					});
			return newDock;
		    }
	    }

	    var inboxDock = false;
	    inboxDock = renderInboxBlock (xmlDoc);

			function renderSentBlock(xmlDoc) {
		var container = OAT.Dom.create ("div");
		container.id = 'sentBlock';

		var containerTab = OAT.Dom.create ("div");
		containerTab.id = 'sentTab';

				var messages = OAT.Xml.xpath(xmlDoc,
						'//userMessages_response/message', {});

				for ( var i = 0; i < messages.length; i++) {
			var msg = buildObjByChildNodes (messages[i]);
					if (msg.sender['@id'] == self.session.userId) {
				var div = OAT.Dom.create ('div', {}, 'msg');
						div.innerHTML = '<span class="time">'
								+ msg.received.substr(0, 10)
								+ ' '
								+ msg.received.substr(11, 5)
								+ '</span><span style="font-style:italic"> To: '
								+ msg.recipient.value + '</span> - ' + msg.text;

				var divC = OAT.Dom.create ('div', {}, 'msg_item');
						divC.innerHTML = '<img style="width:16px;height:16px;cursor:pointer;float:right;"'
								+ ' src="images/skin/default/notify_remove_btn.png">'
								+ '<span class="time">'
								+ msg.received.substr(0, 10)
								+ ' '
								+ msg.received.substr(11, 5)
								+ '</span><span style="font-style:italic"> To: '
								+ msg.recipient.value + '</span> - ' + msg.text;

				ctrl_hide = divC.getElementsByTagName ('img')[0];
				ctrl_hide.msgId = msg.id;
						OAT.Event.attach(ctrl_hide, "click", function(e) {
						      var t = eTarget (e);
							self.userMessageStatusSet(t.msgId, -1, function() {
										     OAT.Dom.unlink (t.parentNode);
										     self.wait ('hide');
										 });
						  });

				OAT.Dom.append ([container,div]);
				OAT.Dom.append ([containerTab,divC]);

			    }
		    }

				if (messages.length == 0) {
					var div = OAT.Dom.create('div', {
						overflow : 'auto',
							  width       : '100%',
							  height      : '20px',
							  paddingLeft : '10px',
						borderBottom : '1px dotted #DDDDDD'
					}, 'msg');

			div.innerHTML = 'This folder is empty.';
			OAT.Dom.append ([containerTab,div]);
		    }

		OAT.Dom.clear ($('msgP2'));
		OAT.Dom.append ([$('msgP2'), containerTab]);

		self.wait ('hide');

				if (sentDock) {
			OAT.Dom.append ([sentDock.div,container]);
			return sentDock;
				} else {
					var newDock = dock.addObject(1, container, {
						color : titleBGColor,
								     title     : 'Sent',
						titleColor : titleTxtColor
					});
			return newDock;
		    }
	    }

	    var sentDock = false;
	    sentDock = renderSentBlock (xmlDoc);

			function renderConversationBlock(xmlDoc) {

		var container = OAT.Dom.create ("div");
		container.id = 'conversationBlock';

		var containerTab = OAT.Dom.create ("div");
		containerTab.id = 'conversationTab';

				var messages = OAT.Xml.xpath(xmlDoc, '//userMessages_response/message', {});
				for ( var i = 0; i < messages.length; i++) {
			var msg = buildObjByChildNodes (messages[i]);
					if (msg.sender['@id'] == self.session.userId) {
				var div = OAT.Dom.create ('div', {}, 'msg');
						div.innerHTML = '<span class="time">'
								+ msg.received.substr(0, 10)
								+ ' '
								+ msg.received.substr(11, 5)
								+ '</span><span style="font-style:italic"> To: '
								+ msg.recipient.value + '</span> - ' + msg.text;

				var divC = OAT.Dom.create ('div', {}, 'msg_item');
						divC.innerHTML = '<img style="width:16px;height:16px;cursor:pointer;float:right;"'
								+ ' src="images/skin/default/notify_remove_btn.png">'
								+ '<span class="time">'
								+ msg.received.substr(0, 10)
								+ ' '
								+ msg.received.substr(11, 5)
								+ '</span><span style="font-style:italic"> To: '
								+ msg.recipient.value + '</span> - ' + msg.text;

				ctrl_hide = divC.getElementsByTagName ('img')[0];
				ctrl_hide.msgId = msg.id;

						OAT.Event.attach(ctrl_hide, "click", function(e) {
						      var t = eTarget (e);
							self.userMessageStatusSet(t.msgId, -1, function() {
										     OAT.Dom.unlink(t.parentNode);
										     self.wait('hide');
							});
						});

				OAT.Dom.append ([container, div]);
				OAT.Dom.append ([containerTab, divC]);

					} else if (msg.recipient['@id'] == self.session.userId) {
				    var div = OAT.Dom.create ('div', {}, 'msg');

						div.innerHTML = '<span class="time">'
								+ msg.received.substr(0, 10)
								+ ' '
								+ msg.received.substr(11, 5)
								+ '</span><span style="font-style:italic"> From: '
								+ msg.sender.value + '</span> - ' + msg.text;

				    var divC = OAT.Dom.create ('div', {}, 'msg_item');

						divC.innerHTML = '<img style="width:16px;height:16px;cursor:pointer;float:right;"'
								+ 'src="images/skin/default/notify_remove_btn.png">'
								+ '<span class="time">'
								+ msg.received.substr(0, 10)
								+ ' '
								+ msg.received.substr(11, 5)
								+ '</span><span style="font-style:italic"> From: '
								+ msg.sender.value + '</span> - ' + msg.text;

				    OAT.Dom.append ([container, div]);
				    OAT.Dom.append ([containerTab, divC]);
				}
		    }

				if (messages.length == 0) {
					var div = OAT.Dom.create('div', {
						overflow : 'auto',
							  width       : '100%',
							  height      : '20px',
							  paddingLeft : '10px',
						borderBottom : '1px dotted #DDDDDD'
					}, 'msg');

			div.innerHTML = 'This folder is empty.';
			OAT.Dom.append ([containerTab,div]);
		    }

		OAT.Dom.clear ($('msgP3'));
		OAT.Dom.append ([$('msgP3'), containerTab]);

		self.wait ('hide');

				if (conversationDock) {
			OAT.Dom.append ([conversationDock.div, container]);
			return conversationDock;
				} else {
					var newDock = dock.addObject(1, container, {
						color : titleBGColor,
								     title     : 'Conversation',
						titleColor : titleTxtColor
					});
			return newDock;
		    }

		var containerTab = OAT.Dom.create ("div");
		containerTab.id = 'notificationsTab';

				if (1 == 1) {
					var div = OAT.Dom.create('div', {
						overflow : 'auto',
							  width       : '100%',
							  height      : '20px',
							  paddingLeft : '10px',
						borderBottom : '1px dotted #DDDDDD'
					}, 'msg');
			div.innerHTML = 'This folder is empty.';
			OAT.Dom.append ([containerTab, div]);
		    }

		OAT.Dom.clear ($('msgP4'));
		OAT.Dom.append ([$('msgP4'), containerTab]);
	    }

	    var conversationDock = false;
	    conversationDock = renderConversationBlock (xmlDoc);

	    dock.div.style.width = '100%';
	    dock.columns[0].style.width = '49%';
	    dock.columns[1].style.width = '49%';

	    self.wait ('hide');
	    return;
	}

		if (self.session.userName) {
		this.userMessages (0, renderMessagesMenu);
	    }

		function renderConnectionsMenu() {
	    var connectionsMenu = new OAT.Menu ();
	    connectionsMenu.noCloseFilter = 'menu_separator';
	    connectionsMenu.createFromUL ("connections_menu");

	    connMenuItems = $('connections_menu_items');
	    connMenuItems.style.zIndex = 101;

			for ( var i = 0; i < connMenuItems.childNodes.length; i++) {
				if (connMenuItems.childNodes[i].nodeName == 'LI'
						&& connMenuItems.childNodes[i].className != 'menu_separator'
						&& connMenuItems.childNodes[i].innerHTML.indexOf('loadVspx') == -1) {
					if (connMenuItems.childNodes[i].innerHTML.indexOf('Invitations') != -1)
						OAT.Event.attach(connMenuItems.childNodes[i], "click", function() {
							self.invitationsGet('fullName,photo,home', self.renderInvitations)
						      });
					else if (connMenuItems.childNodes[i].innerHTML.indexOf('Find People') != -1)
						OAT.Event.attach(connMenuItems.childNodes[i], "click", function() {
								  if ($('search_lst_sort'))
								      $('search_lst_sort').selectedIndex = 0;
								  if ($('search_focus_sel'))
								      $('search_focus_sel').selectedIndex = 1;
								  self.showSearch ();
							      });
					else {
						OAT.Event.attach(connMenuItems.childNodes[i], "click", function() {
								  self.connections.show = true;
								  self.connections.userId = self.session.userId;
							self.connectionsGet(self.connections.userId, 'fullName,photo,homeLocation,dataspace', self.updateConnectionsInterface)
							      });
				}
			}
		}

	    OAT.Dom.show ($('connections_menu').parentNode);

	    var connInterfaceTab = new OAT.Tab ('cisPCtr');

	    connInterfaceTab.add ('csiT1','cisP1');
	    connInterfaceTab.add ('csiT2','cisP2');
	    connInterfaceTab.go (0);
	}

		if (self.session.userName)
		renderConnectionsMenu ();

	var loginfoDiv = $('ODS_BAR_RC');
	OAT.Dom.clear (loginfoDiv);

		var aSettings = OAT.Dom.create("a", {cursor: 'pointer'});

		OAT.Event.attach(aSettings, "click", function() {
			self.loadCheckedVspx(self.expandURL(self.ods + 'app_settings.vspx'));
			  });

    aSettings.innerHTML = 'Application Settings';

		var aSiteSettings = OAT.Dom.create("a", {cursor: 'pointer'});

		OAT.Event.attach(aSiteSettings, "click", function() {
			self.loadCheckedVspx(self.expandURL(self.ods + 'site_settings.vspx'));
			  });

	aSiteSettings.innerHTML = 'Site Settings';

		var aUserProfile = OAT.Dom.create("a", {cursor : 'pointer'});
	aUserProfile.id = 'aUserProfile';
		OAT.Event.attach(aUserProfile, "click", function() {
          self.profile.show = true;
          self.profile.set (self.session.userId);
          self.initProfile ();
        // self.loadVspx (self.expandURL (self.dataspace +
        //   'person/' +
        //   self.session.userName +
        //   '#this'));
			});
	aUserProfile.innerHTML = self.session.userName;

	var aLogin = OAT.Dom.create ("a");

	aLogin.href = 'javascript:void(0)';
	aLogin.innerHTML = 'Sign In';

	OAT.Event.attach (aLogin, "click", this.logIn);

	var aLogout = OAT.Dom.create ("a");

	aLogout.href = 'javascript:void(0)';
	aLogout.innerHTML = 'Logout';

	OAT.Event.attach (aLogout, "click", self.session.end);

		var aSignUp = OAT.Dom.create("a", {cursor: 'pointer'});

		OAT.Event.attach(aSignUp, "click", function() {
			self.loadVspx(self.ods + 'register.vspx?');
		});
	aSignUp.innerHTML = 'Sign Up';

	var aHelp = OAT.Dom.create ("a");

	aHelp.target = "_blank";
	aHelp.href = self.expandURL (self.ods + 'help.vspx');
	aHelp.innerHTML = 'Help';

    var aHelp = OAT.Dom.create ("a");

    aHelp.target = "_blank";
    aHelp.href = self.expandURL (self.ods + 'help.vspx');
    aHelp.innerHTML = 'Help';

		if (self.userLogged && self.session.userIsDba == 1) {
			OAT.Dom.append( [ rootDiv, loginfoDiv ], [ loginfoDiv, aSettings, aSiteSettings, aUserProfile, aLogout, aHelp ]);
		}
		else if (self.userLogged && self.session.userIsDba == 0)
	  {
		  OAT.Dom.append( [ rootDiv, loginfoDiv ], [ loginfoDiv, aSettings, aUserProfile, aLogout, aHelp ]);
      }
		else
		{
			OAT.Dom.append( [ rootDiv, loginfoDiv ], [ loginfoDiv, aLogin, aSignUp, aHelp ]);
    }
    var x = function (data) {
      try {
        self.regData = OAT.JSON.parse(data);
      } catch (e) { self.regData = {}; }
      if (!regData)
        regData = self.regData;
    }
    OAT.AJAX.GET ('/ods/api/server.getInfo?info=regData', false, x, {async: false});

		if (document.location.protocol != 'https:') {
      var x = function (data) {
        var o = null;
        try {
          o = OAT.JSON.parse(data);
				} catch (e) {
					o = null;
				}
				if (o && o.sslPort && !$('ssl_link')) {
	  var hostname = document.location.hostname;
	  if (o.sslHost && o.sslHost.length > 0)
	    hostname = o.sslHost;
          aSSL = OAT.Dom.create ("a");
					aSSL.id = 'ssl_link';
	  if (o.sslPort != '443')
						aSSL.href = 'https://' + hostname + ':' + o.sslPort + '/ods/index.html?alog=1';
	  else
            aSSL.href = 'https://' + hostname + '/ods/index.html?alog=1';
          var aImg = OAT.Dom.create ('img');
          aImg.src = 'images/icons/lock_16.png';
          aImg.alt = 'ODS SSL Link';
          OAT.Dom.append([aSSL, aImg], [loginfoDiv, aSSL]);
        }
      }
      OAT.AJAX.GET ('/ods/api/server.getInfo?info=sslPort', false, x);
		}
		else if (!self.userLogged && self.regData.sslEnable && self.regData.sslAutomaticEnable)
	  {
      var x = function (data) {
        var o = null;
        try {
          o = OAT.JSON.parse(data);
				} catch (e) {
					o = null;
				}
        if (!lfSslData)
         lfSslData = o;

				if (o && o.iri) {
          self.sslData = o;
					if (o.certLogin && !self.userLogged) {
            self.logIn();
						if (self.alog && get_param('alog') == '1') {
		  self.alog = false;
							lfTab.go(3);
              lfLoginSubmit(self.afterLogin);
						}
		}
	    }
        }
		  OAT.AJAX.GET('/ods/api/user.getFOAFSSLData?sslFOAFCheck=1', false, x, {async: false});
			}
      }

	this.showUserProfile = function() {
    self.profile.show = true;
    self.profile.set (self.session.userId);
    self.initProfile ();
  }

	this.getSearchOptions = function(searchBoxObj) {
	var searchQ = false;

		if (searchBoxObj && searchBoxObj.value
				&& searchBoxObj.value.trim() != '') {
		searchQ = 'q=' + encodeURIComponent (searchBoxObj.value.trim ());

		if ($('search_lst_sort') && $('search_lst_sort').value)
		    searchQ += '&' + $('search_lst_sort').value;

			if ($('search_focus_sel') && $('search_focus_sel').value) {
				if ($('search_focus_sel').value != ''
						&& $('search_focus_sel').value != 'on_advanced')
			    searchQ += '&' + $('search_focus_sel').value + '=1';
				else if ($('search_focus_sel').value != ''
						&& $('search_focus_sel').value == 'on_advanced'
						&& typeof ($('search_focus_advanced')) != 'undefined') {

					var advancedFocusCB = $('search_focus_advanced').getElementsByTagName('input');
					for ( var i = 0; i < advancedFocusCB.length; i++) {
						if (advancedFocusCB[i].type == 'checkbox'
								&& advancedFocusCB[i].checked)
					    searchQ += '&' + advancedFocusCB[i].value + '=1';
				    }
			    }
		    }

	    }
	return searchQ;
    };

	this.initSearch = function() {
		function modifySearchOptions(xmlDoc) {
			var searchVal2Pack = {
				on_wikis : 'Wiki',
				  on_blogs       : 'Weblog',
				  on_news        : 'Feed Manager',
				  on_bookmark    : 'Bookmarks',
				  on_omail       : 'Mail',
				  on_polls       : 'Polls',
				  on_addressbook : 'AddressBook',
				  on_calendar    : 'Calendar',
				  on_nntp        : 'Discussion',
				  on_community   : 'Community',
				on_photos : 'Gallery'
			}

			if ($('search_lst_sort')) {
		    var searchFocusOptions = $('search_focus_sel').options;

				for ( var i = 0; i < searchFocusOptions.length; i++) {
					if (typeof (searchVal2Pack[searchFocusOptions[i].value]) != 'undefined') {
						var pack = OAT.Xml.xpath(
										xmlDoc,
										"//installedPackages_response/application[text()='"
												+ searchVal2Pack[searchFocusOptions[i].value]
												+ "']", {})[0];
						if (typeof (pack) != 'undefined') {
					    var att = buildObjByAttributes (pack);

							if (typeof (att.maxinstances) != 'undefined'
									&& att.maxinstances == '0')
						$('search_focus_sel').remove(i);

						} else
					$('search_focus_sel').remove (i);
				}
			}
		}

			if ($('search_focus_advanced')) {
				var advancedFocusCB = $('search_focus_advanced')
						.getElementsByTagName('input');
				for ( var i = 0; i < advancedFocusCB.length; i++) {
					if (advancedFocusCB[i].type == 'checkbox') {
						if (typeof (searchVal2Pack[advancedFocusCB[i].value]) != 'undefined') {
							var pack = OAT.Xml.xpath(
											xmlDoc,
											"//installedPackages_response/application[text()='"
													+ searchVal2Pack[advancedFocusCB[i].value]
													+ "']", {})[0];
							if (typeof (pack) != 'undefined') {
						    var att = buildObjByAttributes(pack);

								if (typeof (att.maxinstances) != 'undefined'
										&& att.maxinstances == '0') {
							    advancedFocusCB[i].checked=false;
							    advancedFocusCB[i].disabled=true;
							}
							} else {
						    advancedFocusCB[i].checked=false;
						    advancedFocusCB[i].disabled=true;
						}
					}
				}
			}
		}
        }

        self.installedPackages (modifySearchOptions);

        self.searchObj.tab = new OAT.Tab ('searchPCtr');
        self.searchObj.tab.add ('searcT1','searchP1');
        self.searchObj.tab.add ('searcT2','searchP2');
        self.searchObj.tab.go (0);


        var mapOpt = {
      fix:OAT.Map.FIX_ROUND1
	}

	var searchCallback = function(commonMapObj) {
	    commonMapObj.addTypeControl();
	    commonMapObj.addMapControl();
	commonMapObj.setMapType(OAT.Map.MAP_MAP);
	    commonMapObj.centerAndZoom(0,0,1);

	    if ($v ('search_textbox_searchC') == '')
		self.searchContacts ('', self.renderSearchResultsMap);
	}

		OAT.Event.attach('searcT2', "click", function() {
		      self.searchObj.map.loadApi (providerType, searchCallback);
		  });

    // Google maps Api v3 is now the default

		var searchDiv = $('searchMap');
      var providerType = OAT.Map.TYPE_G3;
	self.searchObj.map = new OAT.Map (searchDiv, providerType, mapOpt);

		self.searchObj.map.removeAllMarkers = function() {
	    var totalCount = this.markerArr.length;
	    for (var i = 0; i < totalCount; i++)
		this.removeMarker (this.markerArr[0]);
	};

		self.searchObj.map.ref = function(mapObj, infoDiv) {
			return function(marker) {
		    mapObj.closeWindow();
		    mapObj.openWindow(marker,infoDiv);
		}
	    };

		if ($('search_textbox_searchC')) {
			$('search_textbox_searchC').callback = function(e) {
				var t = eTarget(e);
				if (t && t.value && t.value.trim().length > 1) {
					self.search(self.getSearchOptions(t), self.renderSearchResults);
					self.searchContacts('keywords=' + t.value, self.renderSearchResultsMap);
				} else if ($('search_focus_sel').value == 'on_people') {
					self.searchContacts(self.getSearchOptions(t), self.renderSearchResults);
				    self.searchContacts ('', self.renderSearchResultsMap);
				} else if (t && t.value && t.value.trim().length < 2) {
					self.dimmerMsg ('Invalid keyword string entered.');
					return;
				    }
		    };

			OAT.Event.attach($('search_textbox_searchC'), "keypress", onEnterDown);
	    }

        OAT.Event.attach ($('search_textbox_searchC'), "keypress", onEnterDown);

		if ($('search_button_searchC')) {
			$('search_button_searchC').callback = function() {
			var t = $('search_textbox_searchC');

				if (t && t.value && t.value.trim().length > 1) {
					self.search(self.getSearchOptions(t), self.renderSearchResults);
					self.searchContacts('keywords=' + t.value, self.renderSearchResultsMap);
				} else if ($('search_focus_sel').value == 'on_people') {
					self.searchContacts(self.getSearchOptions(t), self.renderSearchResults);
				    self.searchContacts ('', self.renderSearchResultsMap);
				} else if (t && t.value && t.value.trim().length < 2) {
					self.dimmerMsg ('Invalid keyword string entered.');
					return;
				    }
		    };
	    }

        if ($('toggleSelect'))
			$('toggleSelect').callback = function() {
		    inverseSelected ($('search_listing'))
		};

        if ($('search_focus_sel'))
			$('search_focus_sel').callback = function() {
		    if (this[this.selectedIndex].value == 'on_advanced')
			OAT.Dom.show ($('search_focus_advanced'));
		    else
			OAT.Dom.hide ($('search_focus_advanced'));
		}

        $('search_focus_sel').callback ();

        if ($('advanced_search_searchC'))
			$('advanced_search_searchC').callback = function() {
		    var t = $('search_textbox_searchC');

		    if (t && t.value && t.value.length > 0)
					nav.loadVspx(nav.expandURL(nav.ods + 'search.vspx?q='
							+ encodeURIComponent(t.value.trim())));
		    else
			nav.loadVspx (nav.expandURL (nav.ods + 'search.vspx'));
		};

		if ($('tagSelectedToggle')) {
		$('tagSelectedToggle').divId = 'do_tag_block';
			$('tagSelectedToggle').callback = function() {
				if ($(this.divId)) {
				if ($(this.divId).style.display == 'none')
				    OAT.Dom.show ($(this.divId));
				else
				    OAT.Dom.hide ($(this.divId));
			    }
			return;
		    };
	    }

		if ($('tagsInput')) {
			$('tagsInput').doTagToggle = function() {
			var img = this.parentNode.getElementsByTagName ("img")[0];
				if (!self.session.userId
						|| this.value.length == 0
						|| typeof ($('top_pager').paginator) == 'undefined'
						|| (typeof ($('top_pager').paginator) != 'undefined' && $('top_pager').paginator.totalCount == 0)) {
				img.action = false;
				img.style.cursor = '';
				if (img.src != 'images/icons/add_16_gr.png')
				    img.src = 'images/icons/add_16_gr.png';
				} else {
				img.action = 'tag';
				img.style.cursor = 'pointer';
				if (img.src != 'images/icons/add_16.png')
				    img.src = 'images/icons/add_16.png';
			    }
			return;
		    };
	    }

		if ($('do_tag')) {
			$('do_tag').callback = function() {
				if (typeof (this.action) != 'undefined' && this.action == 'tag') {
				var tagStr = $('tagsInput').value.trim ();
				var tagObjStr = '';

					if (tagStr != '') {
					var i = 0;
					var inps = $('search_listing').getElementsByTagName ('input');

						for ( var k = 0; k < inps.length; k++) {
							if (inps[k].type == 'checkbox' && inps[k].checked) {
							tagObjStr += '&obj' + i + '=' + inps[k].value;
							i++;
						    }
					    }
				    }

				if (tagStr.length > 0 && tagObjStr.length > 0)
				    self.tagSearchResult ('tagStr=' + tagStr + tagObjStr,
							  function () {
							      self.wait('hide');
							  });

			    }
			return;
		    };
	    }

        var permaInstant = new OAT.Instant ($('search_gems_block'));
        permaInstant.createHandle ($('searchPermalinkA'));
        permaInstant.createHandle ($('searchPermalinkImg'));

		function gemHref(gemType) {
			if (typeof (gemType) == 'undefined')
				return;

	    var q = $('search_textbox_searchC').value + '';
	    var onStr='';

			if ($('search_focus_sel') && $('search_focus_sel').value) {
		    var allSearchOpts = '';
		    var selectedSearchOpts = '';

				var searchVal2Gems = {
					on_people : 'people',
					  on_apps        : 'apps',
					  on_dav         : 'dav',
					  on_wikis       : 'wiki',
					  on_blogs       : 'weblog',
					  on_news        : 'feeds',
					  on_bookmark    : 'bookmark',
					  on_omail       : 'mail',
					  on_polls       : 'polls',
					  on_addressbook : 'addressbook',
					  on_calendar    : 'calendar',
					  on_nntp        : 'discussion',
					  on_community   : 'community',
					  on_photos      : 'gallery'
		    };

				var advancedFocusCB = $('search_focus_advanced')
						.getElementsByTagName('input');

				if (typeof ($('search_focus_advanced')) != 'undefined') {
					for ( var i = 0; i < advancedFocusCB.length; i++) {
						if (advancedFocusCB[i].type == 'checkbox'
								&& advancedFocusCB[i].checked
								&& typeof (searchVal2Gems[advancedFocusCB[i].value]) != 'undefined') {
					    var optStr = searchVal2Gems[advancedFocusCB[i].value];

					    if (!advancedFocusCB[i].disabled)
						allSearchOpts += (i == advancedFocusCB.length-1) ? optStr : optStr + ',';
					    if (advancedFocusCB[i].checked)
						selectedSearchOpts += (i == advancedFocusCB.length-1) ? optStr : optStr + ',';
					}
				}
			}

		    if ($('search_focus_sel').value == 'on_all')
			onStr = allSearchOpts;
				else if ($('search_focus_sel').value == 'on_advanced')
			    onStr = selectedSearchOpts;
				else if ($('search_focus_sel').value != ''
						&& typeof (searchVal2Gems[$('search_focus_sel').value]) != 'undefined') {
				    onStr = searchVal2Gems[$('search_focus_sel').value];
				}
		}

          var gHref = false;

			if (gemType == 'gdata') {
				gHref = self
						.expandURL('/dataspace/GData/' + onStr + '/?q=' + q);
			} else {
				gHref = self.expandURL('search.vspx?q=' + q
						+ '&q_tags=&r=100&s=1&apps=' + onStr + '&o=' + gemType);
	      }

	  return gHref;
        }

		if ($('search_gems_block')) {
		var gems = $('search_gems_block').getElementsByTagName ('a');

			for ( var i = 0; i < gems.length; i++) {
				OAT.Event.attach(gems[i], "click", function(e) {
					    var t = eTarget (e);
					    var gemUrl = gemHref (t.rel);
					    if (gemUrl.length)
						window.open (gemUrl);
					});
		    }
	    }
    };

	this.renderSearchResultsMap = function(xmlDoc) {
	self.wait ('hide');
	self.searchObj.map.removeAllMarkers ();

		var mapResults = OAT.Xml.xpath(xmlDoc, '//searchContacts_response/search_result', {});
	self.searchObj.map.geoCoordArr = new Array();

		for ( var i = 0; i < mapResults.length; i++) {
		var result = buildObjByChildNodes (mapResults[i]);
		var htmlDiv = OAT.Dom.create ('div');

		htmlDiv.innerHTML = result.html;

			self.searchObj.map.addMarker(result.uid, result.latitude,
					result.longitude, false, false, false, self.searchObj.map.ref(self.searchObj.map, htmlDiv));
			self.searchObj.map.geoCoordArr.push(new Array(result.latitude, result.longitude));
	    }

	self.searchObj.map.optimalPosition (self.searchObj.map.geoCoordArr);

    };

	this.renderSearchResults = function(xmlDoc) {
	if (typeof ($('search_focus_sel').callback) == 'function')
	    $('search_focus_sel').callback();

	OAT.Dom.clear ($('search_listing'));

	if ($('search_textbox_searchC').value.length > 0)
	    $('search_textbox').value = '';

		var results = OAT.Xml.xpath(xmlDoc, '//search_response/search_result', {});
		var results_contacts = OAT.Xml.xpath(xmlDoc, '//searchContacts_response/search_result', {});

	if (results_contacts && results_contacts.length > 0)
	    results = results.concat (results_contacts);

		var resultsPagination = new ODS.paginator(results, $('top_pager'), $('bottom_pager'), renderResultsPage);
		function renderResultsPage(paginationCtrl) {
	    OAT.Dom.clear ($('search_listing'));

			if (paginationCtrl.startIndex && paginationCtrl.endIndex) {
				for ( var i = paginationCtrl.startIndex; i <= paginationCtrl.endIndex; i++) {
			    var result = buildObjByChildNodes (paginationCtrl.iSet[i-1]);
			    result.date = new Date (result.date);

			    var resultLi = OAT.Dom.create ('li');
			    var resultCB = OAT.Dom.create ('input', {}, 'sel_ckb')
				resultCB.type = 'checkbox';
			    resultCB.checked = true;
			    resultCB.value = result.tag_table_fk;

			    var resultDiv = OAT.Dom.create ('div',{},'hit');

			    var resultInnerDiv = OAT.Dom.create('div', {}, 'hit_ctr');
			    resultInnerDiv.innerHTML = result.html;

			    if (resultInnerDiv.firstChild.className == 'map_user_data')
				resultInnerDiv.firstChild.style.width = '98%';

			    var aElms = resultInnerDiv.getElementsByTagName ('a');

					for ( var k = 0; k < aElms.length; k++) {
						if (typeof (aElms[k].rel) != 'undefined'
								&& aElms[k].rel.indexOf('invite#') > -1) {
					    aElms[k].href = "javascript:void(0)";
					    aElms[k].uid = aElms[k].rel.split ('#')[1];
					    aElms[k].fullName = aElms[k].rel.split ('#')[2];

							OAT.Event.attach(
											aElms[k],
											"click",
											function(e) {
								var t = eTarget (e);
								if (t.tagName == 'IMG')
								    t = t.parentNode;

												self.connectionSet(
																t.uid,
																1,
										    function () {
																	self.session.connectionAdd(t.uid, t.fullName);
																	self.session.invitationAdd(t.uid);
											self.connections.show = true;
																	self.connectionsGet(
																					self.session.userId,
													     'fullName,photo,homeLocation,dataspace',
													     self.updateConnectionsInterface);
										    });
							    });
						} else {
					    if (aElms[k].href.length > 0)
								aElms[k].onclick = function(e) {
							var t = eTarget (e);
							if (t.tagName == 'IMG')
							    t = t.parentNode;
							self.loadVspx (t.href);
							return false;
						    };
					}
				}
					OAT.Dom.append( [ $('search_listing'), resultLi ], [
							resultLi, resultDiv ], [ resultDiv, resultCB, resultInnerDiv ]);
			}
		}
	}

		if (resultsPagination.totalItems == 0) {
		var resultLi = OAT.Dom.create ('li');
			resultLi.innerHTML = '<div class="hit" style="padding:10px 0px 5px 0px;">&nbsp;Your search - <b>' + $('search_textbox_searchC').value + '</b> - did not match any documents.</div>';

		OAT.Dom.append ([$('search_listing'),resultLi]);
	    }
		self.showSearch();
	self.wait ('hide');
    };

	this.renderInvitations = function(xmlDoc) {
	var invitations = OAT.Xml.xpath (xmlDoc, '//invitationsGet_response/invitation', {});

		if (invitations.length > 0) {
			var fullName = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '//invitationsGet_response/invitation/fullName', {})[0]);
			var invUserID = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '//invitationsGet_response/invitation/uid', {})[0]);

			function showInvProfile() {
		    self.wait ();
		    self.profile.show = true;
		    self.profile.set (invUserID);
		    self.initProfile ();
		}

			function showLoggedUserProfile() {
		    self.wait ();
		    self.profile.show = true;
		    self.profile.set (self.session.userID);
		    self.initProfile ();
		}

		OAT.Event.attach ($('invitations_connection_photo'), "click", showInvProfile);
		OAT.Event.attach ($('invitations_connection_profileA'), "click", showInvProfile);
		OAT.Event.attach ($('invitations_connection_ownprofileA') ,"click", showLoggedUserProfile);


		$('invitations_connection_full_name_1').innerHTML = fullName;
		$('invitations_connection_full_name_2').innerHTML = fullName;
		$('invitations_connection_full_name_3').innerHTML = fullName;
		$('invitations_connection_full_name_4').innerHTML = fullName;
		$('invitations_connection_full_name_5').innerHTML = fullName;

		$('invitations_connection_photo').alt = fullName;

			$('invitations_connection_photo').src = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc,
											  '//invitationsGet_response/invitation/photo',{})[0]);

			$('invitations_connection_city').innerHTML = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc,
					    '//invitationsGet_response/invitation/home/city',{})[0]);

			$('invitations_connection_country').innerHTML = OAT.Xml
					.textValue(OAT.Xml
							.xpath(
									xmlDoc,
									'//invitationsGet_response/invitation/home/country',
									{})[0]);

			$('invitations_connection_conncount').innerHTML = OAT.Xml
					.textValue(OAT.Xml
							.xpath(
									xmlDoc,
									'//invitationsGet_response/invitation/connections/count',
									{})[0]);

		$('invitations_C').visited = 1;

		OAT.Event.attach ($('invitations_connection_acceptA'), "click",
				  function (){
						self.connectionSet(invUserID, 2, function() {
							self.invitationsGet('fullName,photo,home', self.renderInvitations);
							  })
					  });

		OAT.Event.attach ($('invitations_connection_rejectA'), "click",
				  function () {
						self.connectionSet(invUserID, 3, function() {
							self.invitationsGet('fullName,photo,home', self.renderInvitations);
							  });
				  });

		self.showInvitations();
		} else {
			if (typeof ($('invitations_C').visited) != 'undefined'
					&& $('invitations_C').visited == 1) {
			$('invitations_C').visited = 0;
			self.connections.show = true;
			self.connectionsGet (self.connections.userId,
					     'fullName,photo,homeLocation,dataspace',
					     self.updateConnectionsInterface);
			} else
				self.dimmerMsg('You have no new invitations.', function() {
					self.connections.show = true;
					self.connectionsGet (self.connections.userId,
							     'fullName,photo,homeLocation,dataspace',
							     self.updateConnectionsInterface);
				    });
	    }

    };

	this.requireLogin = function() {
		if (this.session.userId)
			return;
    self.logIn();
  }

	this.logIn = function() {
    // XXX: add later #destroy previous session and session cookie#

	var loginDiv = $('loginDiv');
		if (!self.loginDiv) {
  	  $('lf_close').onclick = OAT.Dimmer.hide;
  		$('lf_login').onclick = function() {
        lfLoginSubmit(self.afterLogin);
  		};
  		$('lf_register').onclick = function() {
				      OAT.Dimmer.hide ();
  			self.session.sid = false;
				      self.loadVspx (self.expandURL (self.ods + 'register.vspx'));
			};
		  lfInit();
	    var inputs = $("lf").getElementsByTagName('input');
      for (var i = 0; i < inputs.length; i++) {
        obj = inputs[i];
				obj.tokenReceived = true;
				obj.callback = function() {
					if (this.tokenReceived)
            lfLoginSubmit(self.afterLogin);
			};
				OAT.Event.attach(obj, "keypress", onEnterDown);
	    }

			var loginDiv = OAT.Dom.create('div');
		loginDiv.id = 'loginDiv';
			OAT.Dom.show($('login_page'));
			OAT.Dom.append([loginDiv, $('login_page')]);
			self.loginDiv = loginDiv;
	    }
	OAT.Dimmer.show (loginDiv);
	OAT.Dom.center (loginDiv, 1, 1);
		pageFocus('lf_page_'+lfTab.selectedIndex);
	};

	this.afterLogin = function(data) {
    var xml = OAT.Xml.createXmlDoc(data);
    if (!hasError(xml)) {
      lfAttempts = 0;
      OAT.Dom.hide('lf_forget');

      var session = self.session;
      session.sid = OAT.Xml.textValue(xml.getElementsByTagName('sid')[0]);
			session.userName = OAT.Xml.textValue(xml.getElementsByTagName('uname')[0]);
			session.userId = OAT.Xml.textValue(xml.getElementsByTagName('uid')[0]);
			session.userIsDba = OAT.Xml.textValue(xml.getElementsByTagName('dba')[0]);
		  OAT.MSG.send(session, "WA_SES_VALIDBIND", {});
    } else {
      lfAttempts++;

      var code = '';
    	var error = xml.getElementsByTagName('failed')[0];
      if (error) {
        code = error.getElementsByTagName('code')[0];
        if (code)
          code = OAT.Xml.textValue(code);
      }

      if (code != '22000')
      OAT.Dom.show('lf_forget');
    }
    return false;
	    }

	this.showLoginThrobber = function(throbberState) {
	var throbber = $('loginThrobber');

    if (throbber)
		if (throbber.style.display != 'none' || throbberState == 'hide') {
		OAT.Dom.hide (throbber);
  		} else {
	    OAT.Dom.show (throbber);
  		}

	return;
    }

	this.showLoginErr = function(errMsg) {
	if ($('loginBtn'))
	    $('loginBtn').disabled = false;

	if ($('signupBtn'))
	    $('signupBtn').disabled = false;

	if ($('loginCloseBtn'))
	    OAT.Dom.show ($('loginCloseBtn'));

		if (typeof (errMsg) == 'undefined') {
		if ($('loginDiv').loginTab.selectedIndex == 1)
		    errMsg = 'Invalid OpenID URL';
		else
				errMsg = 'Invalid User ID or Password';
	    }
		if ($('loginDiv').loginTab.selectedIndex == 0
				&& $('loginUserName').value.length > 0) {
		OAT.Dom.show ($('loginForgot'));
		} else {
		OAT.Dom.hide ($('loginForgot'));
	    }

	OAT.Dom.clear ('loginErrDiv');

		var warnImg = OAT.Dom.create('img', {
			verticalAlign : 'text-bottom',
			padding : '3px 3px 0px 0px'
		});
	warnImg.src = 'images/warn_16.png';

	OAT.Dom.append ([$('loginErrDiv'), warnImg, OAT.Dom.text (errMsg)]);
	self.showLoginThrobber ('hide');
	return;
    }

	this.updateConnectionsSession = function(xmlDoc) {
	var connections = OAT.Xml.xpath (xmlDoc, '//connectionsGet_response/user',{});
	var invitations = OAT.Xml.xpath (xmlDoc, '//connectionsGet_response/user/invited',{});

	if (self.session.userId == self.connections.userId)
	    $('connectionsCountSpan').innerHTML = '(' + (connections.length-invitations.length) + ')';

		for ( var i = 0; i < connections.length; i++) {
		var conn = buildObjByChildNodes (connections[i]);
		var arrPos = -1;
		if (self.session.connectionsId)
		    arrPos = self.session.connectionsId.find (conn.uid);

		if (self.session.userId == self.connections.userId && arrPos == -1 )
		    self.session.connectionAdd (conn.uid, conn.fullName);

			if (self.session.userId == self.connections.userId
					&& typeof (conn.invited) != 'undefined'
					&& conn.invited == 1) {
			var invPos = -1;
			if (self.session.invitationsId)
			    invPos = self.session.invitationsId.find (conn.uid);

			if (invPos == -1)
			    self.session.invitationAdd (conn.uid);
		    }
	    }
    };

	this.updateConnectionsInterface = function(xmlDoc) {
	var connections = OAT.Xml.xpath (xmlDoc, '//connectionsGet_response/user', {});
	var invitations = OAT.Xml.xpath (xmlDoc, '//connectionsGet_response/user/invited', {});

// START render connection Interface
	if (self.session.userId == self.connections.userId)
	    $('connectionsCountSpan').innerHTML = '(' + (connections.length-invitations.length) + ')';

        OAT.Dom.clear ($('connections_list'));
        var templateHtml = $('connectionsTemplate').innerHTML;

		for ( var i = 0; i < connections.length; i++) {
		var conn = buildObjByChildNodes (connections[i]);
		var arrPos = -1;
	
		if (self.session.connectionsId)
		    arrPos = self.session.connectionsId.find (conn.uid);

			if (self.session.userId == self.connections.userId && arrPos == -1)
		    self.session.connectionAdd (conn.uid, conn.fullName);

		var connHTML = templateHtml;

			connHTML = connHTML.replace('images/profile.png', conn.photo.length > 0 ? conn.photo : 'images/profile.png');
	connHTML = connHTML.replace ('{connProfileFullName}', conn.fullName);
	connHTML = connHTML.replace ('{sendMsg}', 'sendMsg_' + conn.uid);
	connHTML = connHTML.replace ('{viewConnections}', 'viewConnections_' + conn.uid);
	connHTML = connHTML.replace ('{doConnection}', 'doConnection_' + conn.uid);

		var divSize = (OAT.Dom.getWH ($('RT'))[0] - 20) + 'px';

			var div = OAT.Dom.create('div', {
				width : divSize,
						  border: '1px solid',
				margin : '5px'
			});
		div.uid = conn.uid;
		div.innerHTML = connHTML;

		var elm = div.getElementsByTagName ("img")[0];
		elm.uid = conn.uid;

			OAT.Event.attach(elm, "click", function(e) {
				    var t = eTarget(e);
				    self.profile.show = true;
				    self.profile.set (t.uid);
				    self.initProfile();
				});

		var elm = div.getElementsByTagName ("span")[0];
		elm.uid = conn.uid;

			OAT.Event.attach(elm, "dblclick", function(e) {
				    var t = eTarget (e);
				    self.profile.show = true;
				    self.profile.set (t.uid);
				    self.initProfile ();
				});

		self.ui.attachPersonBox (elm, conn);

		OAT.Dom.append ([$('connections_list'),div]);

		var elm = $('sendMsg_' + conn.uid);

			if (self.session.sid) {
			elm.uid = conn.uid;

			if (conn.uid == self.session.userId)
			    OAT.Dom.unlink (elm);
				else {
					OAT.Event.attach(elm, "click", function(e) {
						      var t = eTarget (e);
						      self.ui.newMsgWin (t, t.uid);
						  });
		    }
				;
			} else
		    OAT.Dom.hide (elm);

		var elm = $('viewConnections_' + conn.uid);
		elm.uid = conn.uid;

			OAT.Event.attach(elm, "click", function(e) {
				      var t = eTarget (e);
				      self.connections.show = true;
				      self.connections.userId = t.uid;
				self.connectionsGet(self.connections.userId, 'fullName,photo,homeLocation,dataspace', self.updateConnectionsInterface);
				  });

		var elm = $('doConnection_' + conn.uid);
		var elmParent = elm.parentNode;

		OAT.Dom.unlink (elm);

			var elm = OAT.Dom.create('a', {
				cursor : 'pointer',
				textDecoration : 'underline'
			});

		elm.id = "'doConnection_'+conn.uid";
		elm.uid = conn.uid;
		elm.fullName = conn.fullName;

			if (self.session.sid) {
				if (self.session.connectionsId && self.session.connectionsId.find(conn.uid) > -1 && typeof (conn.invited) == 'undefined') {
				elm.innerHTML = 'Disconnect';

					OAT.Event.attach(elm, "click", function(e) {
						    var t = eTarget (e);
						self.connectionSet(t.uid, 0, function() {
									    self.session.connectionRemove (t.uid);
									    self.initProfile ();
									    self.connections.show = true;
							self.connectionsGet(self.connections.userId, 'fullName,photo,homeLocation,dataspace', self.updateConnectionsInterface);
									});
						});
				} else if (self.session.connectionsId
						&& self.session.connectionsId.find(conn.uid) > -1
						&& typeof (conn.invited) != 'undefined'
						&& conn.invited == 1) {
				    elm.innerHTML = 'Withdraw invitation';

					OAT.Event.attach(elm, "click", function(e) {
							var t = eTarget (e);
						self.connectionSet(t.uid, 4, function() {
										self.session.connectionRemove (t.uid);
										self.initProfile ();
										self.connections.show = true;
							self.connectionsGet(self.connections.userId, 'fullName,photo,homeLocation,dataspace', self.updateConnectionsInterface);
									    });
						    });

				} else if (self.session.userId != conn.uid) {
				    elm.innerHTML = 'Connect';
					OAT.Event.attach(elm, "click", function(e) {
							var t = eTarget (e);
						self.connectionSet(t.uid, 1, function() {
							self.session.connectionAdd(t.uid, t.fullName);
										self.session.invitationAdd (t.uid);
										self.connections.show = true;
							self.connectionsGet(self.connections.userId, 'fullName,photo,homeLocation,dataspace', self.updateConnectionsInterface);
									    });
						    });
				}

			OAT.Dom.append ([elmParent,elm]);
			} else {
			elm.innerHTML = 'Connect';
				OAT.Event.attach(elm, "click", function(e) {
					    var t = eTarget (e);
					self.defaultAction = function() {
						self.connectionSet(t.uid, 1, function(xmlDoc) {
							var msg = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/connectionSet_response/message', {})[0]);
									   if (msg && msg.length > 0)
									       self.dimmerMsg (msg);
							else {
										   self.session.connectionAdd (t.uid);
										   self.session.invitationAdd (t.uid);
							}
									   self.connections.show = true;
							self.connectionsGet(self.session.userId, 'fullName,photo,homeLocation,dataspace', self.updateConnectionsInterface);
								       });
						};
					    self.logIn ();
					});
			OAT.Dom.append ([elmParent,elm]);
		    }
	    }
    OAT.MSG.send (self, "WA_CONNECTIONS_UPDATED", {});
// END render connection Interface
    };

	this.initProfile = function() {
	var p = OAT.Dom.uriParams ();

		if (typeof (p.profile) != 'undefined'
				&& p.profile != self.session.userId) {
		self.profile.userId = p.profile;
		} else {
			if (!self.profile.userId) {
			self.profile.userName = self.session.userName;
			self.profile.userId = self.session.userId;
		    }

	    }

	var pL = $('u_profile_l');
	var pR = $('u_profile_r');

	var pLWide = OAT.Dom.getWH (pL)[0] > 0 ? OAT.Dom.getWH (pL)[0] : 200;
	var pRWidth = OAT.Dom.getWH ($('APP'))[0] - pLWide;

	pR.style.width = pRWidth + 'px';

	var rWidgets = pR.getElementsByTagName ("div");

		for ( var i = 0; i < rWidgets.length; i++) {
		if (OAT.Dom.isClass (rWidgets[i], 'widget'))
		    rWidgets[i].style.width = pRWidth - 6 + 'px';

		if (OAT.Dom.isClass (rWidgets[i], 'tab_deck'))
		    rWidgets[i].style.width = pRWidth - 8 + 'px';
	    }

		// if(!self.profile.connTab)
		// {
		//    var connTab=new OAT.Tab('connPCtr');
		//    connTab.add('connT1','connP1');
		//    connTab.add('connT2','connP2');
		//    connTab.go(0);
		//    self.profile.connTab=connTab;
		// }

	self.session.usersGetInfo (self.profile.userId,
				'userName,fullName,photo,dataspace', function(xmlDoc2) {
				       self.updateProfile(xmlDoc2);
				   });

		var mapOpt = {
      fix         : OAT.Map.FIX_ROUND1,
	    fixDistance : 20,
	    fixEpsilon  : 0.5
	}

    var cbCommMap = function () {
    self.profile.connMap = new OAT.Map('connP2map',OAT.Map.TYPE_G3,mapOpt);
		  self.profile.connMap.connLocations = {};
    self.profile.connMap.connData={};
    self.profile.connMap.centerAndZoom(0,0,8); /* africa, middle zoom */
    self.profile.connMap.setMapType(OAT.Map.MAP_ORTO); /* aerial */

		  OAT.Event.attach('connT2', "click", function() {
		    self.profile.connMap.obj.checkResize();
                                                 self.profile.connMap.optimalPosition(self.profile.connMap.connLocations);
                                                });
    }
    // OAT.Map.loadApi(OAT.Map.TYPE_G3, {callback: cbCommMap});

		if (!self.profile.ciTab) {
		var ciTab = new OAT.Tab ('ciPCtr');

		ciTab.add ('ciT1', 'ciP1');
		ciTab.add ("ciT2", "ciP2");
		ciTab.add ("ciT3", "ciP3");
		ciTab.add ("ciT4", "ciP4");
		ciTab.add ("ciT5", "ciP5");
	ciTab.add ("ciT6", "ciP6");

		ciTab.go (0);

		self.profile.ciTab = ciTab;
	    }

    var cbCiMap = function () {
  		self.profile.ciMap = new OAT.Map('locatorMap', OAT.Map.TYPE_G3, mapOpt);

      self.profile.ciMap.homeLocation  = false;
      self.profile.ciMap.workLocation  = false;
      self.profile.ciMap.connLocations = new Array();
      self.profile.ciMap.connData      = {};
      self.profile.ciMap.centerAndZoom (0, 0, 8); /* africa, middle zoom */
      self.profile.ciMap.obj.addControl (new GSmallMapControl ());
      self.profile.ciMap.setMapType (OAT.Map.MAP_ORTO); /* aerial */
  		self.profile.ciMap.expandMap = function() {
	  self.profile.ciMap.obj.checkResize();
  			if (self.profile.ciMap.homeLocation && self.profile.ciMap.workLocation)
  				self.profile.ciMap.optimalPosition(new Array(self.profile.ciMap.homeLocation, self.profile.ciMap.workLocation));
          else
	      self.profile.ciMap.centerAndZoom (50, -10, 3);
      }
      setTimeout(self.profile.ciMap.expandMap,500);
    }
    // OAT.Map.loadApi(OAT.Map.TYPE_G3, {callback: cbCiMap});
    };

	this.updateProfile = function(xmlDoc) {
		var userProfileName = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc,
					     '/usersGetInfo_response/user/userName',{})[0]);

	self.profile.userName = userProfileName;
		var userDisplayName = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/fullName', {})[0]);
	if (userDisplayName == '')
	    userDisplayName = self.profile.userName;
		self.profile.userFullName = userDisplayName;

		var userProfileDataspace = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/dataspace', {})[0]);
		var userFOAFURI = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/foaf_ds', {})[0]);
		var userSIOCURI = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/sioc_ds', {})[0]);

		$('userProfilePhotoName').innerHTML = '<h3>' + userDisplayName + '</h3>';
 		$('ProfilePhoto').innerHTML = '';
 		var userProfilePhoto = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/photo', {})[0]);
    if (userProfilePhoto) {
      var img = OAT.Dom.create('img');
      img.className = 'prof_photo';
      img.src = userProfilePhoto;
      img.alt = userDisplayName;
      img.rel = 'foaf:depiction';
      OAT.Dom.clear('userProfilePhoto');
      $('userProfilePhoto').appendChild(img);
  	} else {
      $('userProfilePhoto').innerHTML = '<br /><b>Photo Not Available</b><br /><br />';
  	}

	var gems = $('profileUserGems').getElementsByTagName ("a");

    // XXX Ugly hack, replace with backend func ASAP

		this.profile.foaf_uri = self.odsLink() + userProfileDataspace.replace('#this', ''); // foaf

		if (this.profile.foaf_uri) {
      var thisPage  = document.location.protocol + '//' + document.location.host + document.location.pathname;
      if (thisPage != this.profile.foaf_uri)
        document.location = this.profile.foaf_uri;
    }

    var org_pref= (userProfileDataspace.indexOf ('/organization') > -1) ? 'organization/' : 'person/';

		this.profile.sioc_uri = self.odsLink() + userProfileDataspace.replace(org_pref + self.profile.userName + '#this', self.profile.userName); //sioc

    this.profile.personal_uri = userProfileDataspace;

    gems[1].href = this.profile.sioc_uri;
    gems[0].href = this.profile.foaf_uri;

//    gems[2].href='http://geourl.org/near?p='+encodeURIComponent('http://'+document.location.host+'/dataspace/'+self.profile.userName); //GEOURL //http://geourl.org/near?p=http%3A//bdimitrov.lukanet.com%3A8890/dataspace/borislavdimitrov

		this.profile.vcard = self.odsLink() + self.ods + 'sn_user_export.vspx?ufid=' + self.profile.userId + '&ufname=' + self.profile.userName; //vcard

    gems[2].href = this.profile.vcard;

		this.connect_users = function(e) {
			if (eTarget(e).id == 'profileConnAction' || eTarget(e).id == 'connect_box_connect') {
	  self.requireLogin ();
				self.connectionSet(self.profile.userId, 1, function(xmlDoc) {
				var msg = OAT.Xml.textValue (OAT.Xml.xpath (xmlDoc,
							'/connectionSet_response/message', {})[0]);
									if (msg && msg.length > 0)
									    self.dimmerMsg (msg);
				
										self.session.connectionAdd (self.profile.userId);
										self.session.invitationAdd (self.profile.userId);
				self.initProfile ();
				    });
			} else
	dd ('Invalid target in connect_users');
    };

		this.showConnectBox = function() {
      dd ('showConnectBox');
      var conn_a = $('profileConnAction');
      conn_a.innerHTML = 'Connect';
      OAT.Event.attach (conn_a, 'click', this.connect_users);
      var cb = tpl_elem_repl ($('connect_box_tpl'), $('connect_box'));
      var conn_btn = $('connect_box_connect')
      OAT.Event.attach (conn_btn, 'click', this.connect_users);
      this.processConnectBoxTemplate (cb);
      OAT.Dom.show (cb);
    };

		this.showDisconnectBox = function() {
      dd ('showDisconnectBox');
      var conn_a = $('profileConnAction');
      conn_a.innerHTML = 'Disconnect';
      OAT.Event.attach (conn_a, 'click', this.disconnect_users);
      OAT.Dom.hide ($('connect_box'));
    };

		this.processConnectBoxTemplate = function(tpl) {
      replaceTemplateClass (tpl, 'u_full_name', self.profile.userFullName);
      replaceTemplateClass (tpl, 'u_name', self.profile.userName);
      //      replaceTemplateClass (tpl, 'u_thumbnail', self.profile.userThumbnail, self.profile.userPhotoURL);
    }

		this.disconnect_users = function(e) {
      dd ('disconnect_users');
      dd ('user:' + self.session.userId);
      dd ('from:' + self.profile.userId);
      if (eTarget (e).id == 'profileConnAction' || eTarget (e).id == 'connect_box_disconnect') 
				self.connectionSet(self.profile.userId, 0, function() {
										    self.session.connectionRemove (self.profile.userId);
										    self.initProfile ();
										});
				else
	dd ('Disconnect action for unknown control initiated');
    }

		this.withdraw_connection = function(e) {
      if (eTarget (e).id == 'profileConnAction' || eTarget (e).id == 'connect_box_withdraw')
				self.connectionSet(self.profile.userId, 4, function() {
											self.session.connectionRemove (self.profile.userId);
											self.session.invitationRemove (self.profile.userId);
											self.initProfile ();
										    });
      else 
	dd ('withdraw action from unknown source');
    };

		this.showWithdrawBox = function() {
      dd ('showWithdrawBox');
      var conn_a = $('profileConnAction')
      conn_a.innerHTML = 'Withdraw invitation';
      OAT.Event.attach (conn_a, "click", this.withdraw_connection);
      var cb = tpl_elem_repl ($('connect_pending_tpl'), $('connect_box'));
      var wd_btn = $('connect_box_withdraw');
      OAT.Event.attach (wd_btn, 'click', this.withdraw_connection);
      replaceTemplateClass (cb, 'u_full_name', self.profile.userName);
      OAT.Dom.show (cb);
    };

		this.hideConnectBox = function() {
      dd ('hideConnectBox');
      var conn_a = $('profileConnAction');
      OAT.Dom.hide (conn_a);
      var conn_b = $('connect_box');
      OAT.Dom.hide (conn_b);
    };

		this.isConnected = function(uid) {
			if (!self.session.userId || !self.session.connectionsId)
				return false;
      
			if (self.session.connectionsId) {
				if (self.session.connectionsId.find(uid) > -1 && (!self.session.invitationsId || (self.session.invitationsId && self.session.invitationsId.find(uid) < 0))) {
	      return true;
	    }
	}
    }

		this.hasPendingInvitation = function(uid) {
			if (!self.session.connectionsId)
				return false;
			if (self.session.connectionsId.find(self.profile.userId) > -1 && self.session.invitationsId && self.session.invitationsId.find(self.profile.userId) > -1)
	  return true;
					}

		function renderConnectBox() {
      var box_tpl;
      
      if (self.session.userID == self.profile.userID) 
	return;

      if (self.canConnect (self.profile.userId))
	box_tpl = $('connect_box_tpl');
				    else
	box_tpl = $('disconnect_box_tpl');

      OAD.Dom.show (box_tpl);
			OAT.Event.attach(getConnectBoxButton(box_tpl), "click",
					this.initiateConnection)
    }

		function renderProfileUserActions() {
      OAT.Dom.show ($('profile_user_actions'));
    
      var msgA = $('profileSendMsg');
	  
			if (self.session.userId == self.profile.userId
					|| !self.session.userId)
	OAT.Dom.hide (msgA);
			else {
	  OAT.Dom.show (msgA);
				OAT.Event.attach(msgA, "click", function() {
			    self.ui.newMsgWin (msgA, self.profile.userId);
								});
					    }

      var connA = $('profileConnAction');

			if (self.session.userId) {
				if (self.session.userId != self.profile.userId) {
	      // dd ('viewing somebody else');
					if (self.isConnected(self.profile.userId)) {
		  self.showDisconnectBox ();
					} else if (self.hasPendingInvitation(self.profile.userId)) {
		  self.showWithdrawBox ();
					} else {
		  self.showConnectBox ();
		}
				} else {
	      // dd ('viewing own profile');
	      self.hideConnectBox();
	    }
			} else
	self.showConnectBox ();
	}

	renderProfileUserActions ();

		function renderConnectionsWidget(xmlDoc) {

	    var connTP = $('connP1')
		OAT.Dom.clear (connTP);

			function attachClick(elm, connId) {
				OAT.Event.attach(elm, "dblclick", function() {
				   self.profile.show = true;
				   self.profile.set (connId);
				   self.initProfile ();
			       });
			}

			function attachDblClick(elm, url) {
				OAT.Event.attach(elm, "dblclick", function() {
				    document.location.href=url;
				});
			}

	    var connections = OAT.Xml.xpath (xmlDoc, '//connectionsGet_response/user', {});

	    var invitations = OAT.Xml.xpath (xmlDoc, '//connectionsGet_response/user/invited', {});

	    $('connPTitleTxt').innerHTML = 'Connections (' + (connections.length - invitations.length) + ')';

	    var connectionsArr = new Array();

			for ( var i = 0; i < connections.length; i++) {
		    var connObj = buildObjByChildNodes (connections[i]);

				if (typeof (connObj.invited) == 'undefined'
						|| (typeof (connObj.invited) != 'undefined' && self.session.userId != self.profile.userId)) {
			    var connProfileObj = {};
			    connProfileObj[connObj.uid] = connObj.fullName;

			    self.profile.connections.push (connProfileObj);
			    connectionsArr.push (connObj.uid);

					var _divC = OAT.Dom.create('div', {
						cursor : 'pointer'
					}, 'conn');

			    _divC.id = 'connW_' + connObj.uid;

//           attachClick (_divC,connObj.uid);

			    attachDblClick (_divC, connObj.dataspace);

					var tnail = OAT.Dom.create('img', {
						width : '40px',
						height : '40px'
					});

					tnail.src = (connObj.photo.length > 0 ? connObj.photo
							: 'images/missing_person_tnail.png'); // images/profile_small.png

			    var _divCI = OAT.Dom.create ('div', {}, 'conn_info');
					var cNameA = OAT.Dom.create('a', {
						cursor : 'pointer'
					});
			    cNameA.href = self.odsLink (connObj.dataspace);
			    cNameA.innerHTML = connObj.fullName;

					OAT.Dom.append( [ connTP, _divC ],
							[ _divC, tnail, _divCI ], [ _divCI, cNameA ]);

			    self.ui.attachPersonBox (cNameA, connObj);

			    var userHome = connections[i].getElementsByTagName ('home')[0];

			    var _lat = OAT.Xml.textValue (userHome.childNodes[0]);
			    var _lon = OAT.Xml.textValue (userHome.childNodes[1]);

			    //			    if (_lat != '' && _lon != '') {
			    //				self.profile.ciMap.addMarker (i, _lat, _lon,
			    //							      tnail.src, 40, 40,
			    //						      function (marker) {
			    //							  self.profile.show = true;
			    //							  self.profile.set (self.profile.ciMap.connData[marker.__group].id);
			    //							  self.initProfile ();
			    //						      });
			    //
			    //		self.profile.ciMap.connLocations.push (new Array (_lat ,_lon));

			    //	self.profile.ciMap.connData[i] = {id    : connObj.uid,
			    //					  name  : cNameA.innerHTML,
			    //					  photo : tnail.src}
			    //
			    // }

			}
		}

			if (self.session.userId == self.profile.userId) {
		    self.session.connections = self.profile.connections;
		    self.session.connectionsId = connectionsArr;
		}

	    //	    self.profile.ciMap.optimalPosition (self.profile.ciMap.connLocations);
	    self.wait ('hide');

	    return;
	}

		function activitiesByAtom(atomXml) {
	    var activities = new Array();
	    return activities;
	}

		function buildTimeObj() {
			function pZero(val, prec) {
				if (!prec)
					prec = 2;
		if (String (val).length < prec)
		    return '0'.repeat (prec - String (val).length) + String (val);
		else
		    return val;
			}
	    var weekday = new Array (7);

	    weekday[0] = "Sunday";
	    weekday[1] = "Monday";
	    weekday[2] = "Tuesday";
	    weekday[3] = "Wednesday";
	    weekday[4] = "Thursday";
	    weekday[5] = "Friday";
	    weekday[6] = "Saturday";

	    var obj = {};
	    var d = new Date ();

	    //     d.setFullYear(2007,0,1);

	    var titleObj = OAT.Dom.create ('h3',{},'date');

	    OAT.Dom.append ([titleObj,OAT.Dom.text ('Today')]);
			obj[d.getFullYear() + '-' + pZero(d.getMonth() + 1) + '-'
					+ pZero(d.getDate())] = {
				title : 'Today',
	     titleObj : titleObj,
				ulObj : OAT.Dom.create('ul', {}, 'msgs')
			};

	    d.setDate (d.getDate () - 1);

	    var titleObj = OAT.Dom.create ('h3', {}, 'date');

	    OAT.Dom.append ([titleObj, OAT.Dom.text ('Yesterday')]);

			obj[d.getFullYear() + '-' + pZero(d.getMonth() + 1) + '-'
					+ pZero(d.getDate())] = {
				title : 'Yesterday',
	     titleObj : titleObj,
				ulObj : OAT.Dom.create('ul', {}, 'msgs')
			};

			for ( var i = 0; i < 5; i++) {
		    d.setDate (d.getDate () - 1);

		    var titleObj = OAT.Dom.create ('h3', {}, 'date');
				OAT.Dom.append( [ titleObj, OAT.Dom.text(weekday[d.getDay()]) ]);

				obj[d.getFullYear() + '-' + pZero(d.getMonth() + 1) + '-' + pZero(d.getDate())] = {
					title : weekday[d.getDay()],
			  titleObj : titleObj,
					ulObj : OAT.Dom.create('ul', {}, 'msgs')
				};
		}

	    var titleObj = OAT.Dom.create ('h3', {}, 'date');

	    OAT.Dom.append ([titleObj, OAT.Dom.text('Older')]);

			obj['older'] = {
				title : 'Older',
			    titleObj : titleObj,
				ulObj : OAT.Dom.create('ul', {}, 'msgs')
			};
	    return obj;
	}

		function renderNewsFeedBlock(xmlString) {
	    var actHidden = new Array;

			if (self.session.sid) {
		    self.feedStatus (function(xmlDoc) {
					var actOpt = OAT.Xml.xpath(xmlDoc,
							'/feedStatus_response/activity', {});
					for ( var i = 0; i < actOpt.length; i++) {
				    var act = buildObjByAttributes(actOpt[i]);
				    if (act.status == 0)
					actHidden.push (act.id);
				}
			});
		}

	    var daily = buildTimeObj();
	    var cont = $('notify_content');

			if (!cont)
				return;

			var xmlDoc = OAT.Xml.createXmlDoc(OAT.Xml.removeDefaultNamespace(xmlString));
	    var entries = OAT.Xml.xpath (xmlDoc, '/feed/entry',{});

			for ( var i = 0; i < entries.length; i++) {
		    var entry = buildObjByChildNodes (entries[i]);
		    var actImg = false;

				if ((typeof (entry['dc:type']) != 'undefined')
						&& (typeof (entry['dc:type'].value) != 'undefined')
						&& (entry['dc:type'].value.length > 0)
						&& (typeof (ODS.ico[entry['dc:type'].value]) != 'undefined')) {
			    actImg = OAT.Dom.create ('img',{},'msg_icon');
			    actImg.alt = ODS.ico[entry['dc:type'].value].alt;
			    actImg.src = ODS.ico[entry['dc:type'].value].icon;
				}
				;

		    var feedId = entry.id.split ('/');
		    feedId = feedId[feedId.length - 1];

				var ctrl_hide = OAT.Dom.create('img', {
					width : '16px',
					height : '16px',
					cursor : 'pointer'
				});
		    ctrl_hide.src = 'images/skin/default/notify_remove_btn.png';
		    ctrl_hide.alt = 'Hide';

		    ctrl_hide.feedId = feedId;

				OAT.Event.attach(ctrl_hide, "click", function(e) {
					  var t = eTarget (e);
					  var feedId = t.feedId;
					  t = t.parentNode.parentNode;
					self.feedStatusSet(feedId, 0, function() {
						if (t.parentNode.childNodes.length == 1) {
								      if (t.parentNode.previousSibling.tagName == 'H3')
									  OAT.Dom.unlink(t.parentNode.previousSibling);
								      OAT.Dom.unlink(t.parentNode);
						} else
								      OAT.Dom.unlink(t);

							      });
				      });

		    var ctrl = OAT.Dom.create ('div', {}, 'msg_r')
			OAT.Dom.append ([ctrl, ctrl_hide]);

		    var actDiv = OAT.Dom.create ('div', {}, 'msg');
				actDiv.innerHTML = '<span class="time">'
						+ entry.updated.substr(11, 5) + '</span> '
						+ entry.title;

		    var actLi = OAT.Dom.create ('li');

		    if (actImg)
			OAT.Dom.append ([actLi, actImg, actDiv, ctrl]);
		    else
			OAT.Dom.append ([actLi, actDiv, ctrl]);

	  // XXX hack to replace URL with loader. Should be handled in URL rewriters

	  var appUri = actDiv.childNodes[4].href;
				actDiv.childNodes[4].onclick = function() {
					return false;
				};
				OAT.Event.attach(actDiv.childNodes[4], "click",
						(function(href) {
							return function() {
								self.loadVspx(href)
							}
						})(actDiv.childNodes[4].href));

		    var actDate = entry.updated.substring (0, 10);

				if (typeof (daily[actDate]) == 'object'
						&& actHidden.find(feedId) == -1) {
			    OAT.Dom.append ([daily[actDate].ulObj,actLi]);
				} else
			OAT.Dom.append ([daily['older'].ulObj, actLi]);
		}

	    OAT.Dom.clear ($('notify_content'));

			for (day in daily) {
				if (daily[day].ulObj.childNodes.length > 0) {
					OAT.Dom.append( [ $('notify_content'), daily[day].titleObj,
					     daily[day].ulObj]);
			}
		}
	}

		function renderContactInformationBlock(xmlDoc) {
			var titledFullname =
			    OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/title', {})[0])
					+ ' '
					+ OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/fullName', {})[0]);

			var _home = OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/home', {});
			var _business = OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/organization', {});
			var _im = OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/im', {})[0];

	    OAT.Dom.clear ($('ciP3'));

      var _ul = OAT.Dom.create ('ul',{},'ci_im');
      OAT.Dom.append ([$('ciP3'), _ul]);

			for ( var i = 0; i < _im.childNodes.length; i++) {
	  var _li = OAT.Dom.create ('li');
	  _li.innerHTML = _im.childNodes[i].nodeName + ': ';

				OAT.Dom.append( [ _ul, _li, OAT.Dom.text(OAT.Xml.textValue(_im.childNodes[i]))]);
		}

	    var organization = {};
			for ( var i = 0; i < _business[0].childNodes.length; i++) {
				organization[_business[0].childNodes[i].nodeName] = OAT.Xml.textValue(_business[0].childNodes[i]);
		}

			$('ciP2title').innerHTML = '<a href="'
					+ ((organization.url.indexOf('http://') >= 0) ? organization.url : 'http://' + organization.url) + '">'
					+ organization.title + '</a>';
			$('ciP2address').innerHTML = organization.address1 + organization.address2;
			$('ciP2city').innerHTML = (organization.city.length) > 0 ? organization.city + ', ' : organization.city;
	    $('ciP2state').innerHTML   = organization.state;
			$('ciP2zip').innerHTML = (organization.state.length + organization.zip.length) > 0 ? organization.zip + ', ' : ' ';
	    $('ciP2country').innerHTML = organization.country;
			$('ciP2tel').innerHTML = (organization.mobile.length > 0) ? organization.phone + ', ' + organization.mobile : organization.phone;

	    var home = {};

			for ( var i = 0; i < _home[0].childNodes.length; i++) {
				home[_home[0].childNodes[i].nodeName] = OAT.Xml.textValue(_home[0].childNodes[i]);
		}

			var photo = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/photo', {})[0]);
			$('ciP1photo').innerHTML = '';
      if (photo) {
        var img = OAT.Dom.create('img');
        img.className = 'photo';
        img.src = photo;
        img.alt = 'photo';
        img.rel = 'foaf:depiction';
        $('ciP1photo').appendChild(img);
    	}

			$('ciP1uri').href = this.nav.profile.personal_uri;
  		var x = function(data) {
			  $('ciP1qrcode').src = 'data:image/jpg;base64,' + data;
  		};
      OAT.AJAX.GET ('/ods/api/qrcode?data='+encodeURIComponent(this.nav.profile.personal_uri), null, x, ajaxOptions);

	    $('ciP1fn').innerHTML        = titledFullname;
	    $('ciP1org').innerHTML       = organization.title;
	    $('ciP1email').style.display = 'none';
	    $('ciP1address').innerHTML   = home.address1+home.address2;
	    $('ciP1city').innerHTML      = home.city.length ? home.city+', ' : '';
	    $('ciP1state').innerHTML     = home.state;
			$('ciP1zip').innerHTML = (home.state.length + home.zip.length) > 0 ? home.zip + ', ' : home.zip;
	    $('ciP1country').innerHTML   = home.country;
			$('ciP1tel').innerHTML = (home.mobile.length > 0) ? home.phone + ', ' + home.mobile : home.phone;

	    //  	    self.profile.ciMap.centerAndZoom (home.latitude,home.longitude,8); /* africa, middle zoom */
	    //	    self.profile.ciMap.addTypeControl ();

	    //	    if (home.latitude != '' && home.longitude != '')
	    //		{
	    //		    self.profile.ciMap.homeLocation = new Array (home.latitude, home.longitude);
	    //	    self.profile.ciMap.addMarker (1,
	    //						  home.latitude,
	    //						  home.longitude,
	    //						  false,false,false,
	    //						  function (marker) {
	    //						      var _div = OAT.Dom.create ('div');
	    //						      _div.innerHTML = 'Home location:<br/>' +
	    //							  home.address1 +
	    //							  home.address2 +
	    //							  '<br/>' +
	    //							  home.city +
	    //							  ',' +
	    //							  home.state +
	    //							  ' ' +
	    //							  home.zip +
	    //							  ', ' +
	    //							  home.country;
	    //						      self.profile.ciMap.openWindow (marker, _div);
	    //						  });
	    //		}

	    //	    if (organization.latitude != '' && organization.longitude != '')
	    //		{
	    //		    self.profile.ciMap.workLocation = new Array (organization.latitude, organization.longitude);
	    //		    self.profile.ciMap.addMarker (2,
	    //						  organization.latitude,
	    //						  organization.longitude,
	    //						  false,false,false,
	    //						  function (marker) {
	    //						      var _div = OAT.Dom.create ('div');
	    //						      _div.innerHTML = 'Work location:<br/>' +
	    //							  organization.title +
	    //							  '<br/>' +
	    //							  organization.address1 +
	    //							  organization.address2 +
	    //							  '<br/>' +
	    //							  organization.city +
	    //							  ', ' +
	    //							  organization.state +
	    //							  ' ' +
	    //							  organization.zip +
	    //							  ', ' +
	    //							  organization.country;
	    //						      self.profile.ciMap.openWindow (marker,_div);
	    //						  });
	    //		}

  //      OAT.Dom.append([$('ciP1'),
  //                      organizationA,
  //                      OAT.Dom.create('br'),
  //                      OAT.Dom.text(organization.address1+organization.address2),
  //                      OAT.Dom.create('br'),
  //                      OAT.Dom.text(organization.city+', '+organization.state+' '+organization.zip+', '+organization.country)
  //                     ]);


	    //	    if (self.profile.ciMap.homeLocation &&
	    //		self.profile.ciMap.workLocation)
	    //		self.profile.ciMap.optimalPosition (new Array (self.profile.ciMap.homeLocation,
	    //							       self.profile.ciMap.workLocation));
	    //	    else
	    //		self.profile.ciMap.centerAndZoom (50, -10, 3);

//      self.profile.ciMap.optimalPosition(new Array(self.profile.ciMap.homeLocation,self.profile.ciMap.workLocation));

      $('sm_personal').href = this.nav.profile.personal_uri;
			$('sm_openid').href = this.nav.profile.personal_uri.replace('#this', '');
      $('sm_foaf').href = this.nav.profile.foaf_uri;
      $('sm_sioc').href = this.nav.profile.sioc_uri;
			$('sm_dataspace').href = this.nav.profile.personal_uri.replace('#this', '');
      $('sm_vcard').href = this.nav.profile.vcard;

	    return;

	}

	// This box is disabled

		function renderSematicMagic() {
			if ($('sm_personal') && $('sm_personal').tagName == 'A') {
		    $('sm_personal').href = userProfileDataspace;

		    if (self.serverOptions.useRDFB)
					$('sm_personal').onclick = function(e) {
				var t = eTarget (e);
				self.loadRDFB (t.href);
				return false;
			    };
		    else
			$('sm_personal').target = '_blank';
		}

			if ($('sm_openid') && $('sm_openid').tagName == 'A') {
		    $('sm_openid').href = userProfileDataspace;
		    if (self.serverOptions.useRDFB)
					$('sm_openid').onclick = function(e) {
				var t = eTarget (e);
				self.loadRDFB (t.href);
				return false;
			    };
		    else
			$('sm_openid').target = '_blank';
		}

			if ($('sm_dataspace') && $('sm_dataspace').tagName == 'A') {
		    $('sm_dataspace').href = userProfileDataspace;

		    if (self.serverOptions.useRDFB)
					$('sm_dataspace').onclick = function(e) {
				var t = eTarget (e);
				self.loadRDFB (t.href);
				return false;
			    };
		    else
			$('sm_dataspace').target = '_blank';
		}

			if ($('sm_foaf') && $('sm_foaf').tagName == 'A') {
				$('sm_foaf').href = self.odsLink() + userProfileDataspace.replace('#this', '/foaf.rdf');

		    if (self.serverOptions.useRDFB)
					$('sm_foaf').onclick = function(e) {
				var t = eTarget (e);
				self.loadRDFB (t.href);
				return false;
			    };
		    else
			$('sm_foaf').target = '_blank';
		}

			if ($('sm_sioc') && $('sm_sioc').tagName == 'A') {
				$('sm_sioc').href = self.odsLink() + userProfileDataspace.replace('#this', '/sioc.rdf');

		    if (self.serverOptions.useRDFB)
					$('sm_sioc').onclick = function(e) {
				var t = eTarget(e);
				self.loadRDFB (t.href);
				return false;
			    };
		    else
			$('sm_sioc').target='_blank';
		}

			if ($('sm_vcard') && $('sm_vcard').tagName == 'A') {
				$('sm_vcard').href = self.odsLink() + self.ods
						+ 'sn_user_export.vspx?ufid=' + self.profile.userId
						+ '&ufname=' + self.profile.userName;
		    $('sm_vcard').target='_blank';
		}
	}

	//	renderSematicMagic ();

		function renderDataspaceUl(xmlDoc) {
			var resXmlNodes = OAT.Xml.xpath(xmlDoc, '//applicationsGet_response/application', {});
	    var ulDS = $('ds_list');

	    OAT.Dom.clear (ulDS);

			for ( var i = 0; i < resXmlNodes.length; i++) {
		    var applicationObj = buildObjByAttributes (resXmlNodes[i]);

				applicationObj.selfTextValue = OAT.Xml.textValue(resXmlNodes[i]);

				if (applicationObj.disable != '0'
						&& applicationObj.url.length > 0) {
			    var packageName = applicationObj.type;
			    packageName = packageName.replace (' ','');

			    var appOpt = {};

			    if (typeof (ODS.app[packageName]) != 'undefined')
				appOpt = ODS.app[packageName];
			    else
						appOpt = {
							menuName : packageName,
					  icon    : 'images/icons/apps_16.png',
							dsUrl : '#UID#/' + packageName + '/'
						};

			    var appDataSpaceItem = OAT.Dom.create ('li');
					var appDataSpaceItemA = OAT.Dom.create('a', {
						cursor : 'pointer'
					});

			    appDataSpaceItemA.packageName = packageName;

					appDataSpaceItemA.href = ODS.Preferences.root
							+ applicationObj.dataspace;

					appDataSpaceItemA.onclick = function() {
						return false;
					};

					OAT.Event.attach(appDataSpaceItemA, "click", function(e) {
						  var t = eTarget (e);
						  self.loadVspx (self.expandURL (t.href));
						  return false;
					      });

			    var appDataSpaceItemImg = OAT.Dom.create ('img');
			    appDataSpaceItemImg.className = 'app_icon';
			    appDataSpaceItemImg.src = appOpt.icon;

//exception - items that should not be show;
//         if(appOpt.menuName!='Community')
//         {
					OAT.Dom.append( [ ulDS, appDataSpaceItem ], [
							appDataSpaceItem, appDataSpaceItemA ], [
							appDataSpaceItemA, appDataSpaceItemImg,
					     OAT.Dom.text (' ' + applicationObj.selfTextValue)]);
//         }

			}
		}

	}

		function renderDiscussionGroups(xmlDoc) {
	    var discussionsDiv = $('discussionsCtr');

	    OAT.Dom.clear (discussionsDiv);

			var resXmlNodes = OAT.Xml.xpath(xmlDoc, '//userDiscussionGroups_response/discussionGroup', {});

	    var discussionGroup = {}
			for ( var i = 0; i < resXmlNodes.length; i++) {
		    discussionGroup = buildObjByChildNodes (resXmlNodes[i]);

	  var discussionA = OAT.Dom.create ('a');
		    discussionA.innerHTML = discussionGroup.name;

				OAT.Event.attach(discussionA, "click", function() {
					  self.loadVspx (nav.expandURL (discussionGroup.url));
				      });

//        discussionA.href=self.expandURL(discussionGroup.url);
//        discussionA.target='_blank';

		    if (i == 0)
			OAT.Dom.append ([discussionsDiv, discussionA]);
		    else
					OAT.Dom.append( [ discussionsDiv, OAT.Dom.text(', '), discussionA ]);
		}

	    $('discussionsTitleTxt').innerHTML = 'Discussion Groups (' + (i) + ')';
	}

		function renderPersonalInformationBlock(xmlDoc) {

		  function renderPersonalInformationBlockInternal(node, values) {
  			OAT.Dom.clear(node);
  			values = OAT.Xml.textValue(values[0]).split('\n');
  			for ( var i = 0; i < values.length; i++) {
  				if (values[i].length) {
  					var iArr = values[i].split(';');

  					var a = OAT.Dom.create('a');
  					a.innerHTML = iArr[1];
  					a.href = self.expandURL(iArr[0]);
  					a.target = '_blank';
			    if (i == 0)
  						OAT.Dom.append( [ node, a ]);
			    else
  						OAT.Dom.append( [ node, OAT.Dom.text(', '), a ]);
  				}
			}
		}

			var interestsP = $('interestTopicsCtr');
			var interests = OAT.Xml.xpath(xmlDoc, '//usersGetInfo_response/user/interestTopics', {});
			renderPersonalInformationBlockInternal(interestsP, interests);

			var interestsP = $('interestsCtr');
			var interests = OAT.Xml.xpath(xmlDoc, '//usersGetInfo_response/user/interests', {});
			renderPersonalInformationBlockInternal(interestsP, interests);

			var musicP = $('musicCtr');
			OAT.Dom.clear(musicP);

			var music = OAT.Xml.xpath(xmlDoc, '//usersGetInfo_response/user/music', {});
	    musicP.innerHTML = OAT.Xml.textValue (music[0]);
	}

	if (self.session.sid && self.session.userId == self.profile.userId)
	    self.applicationsGet (false, false, 'own', renderDataspaceUl);
		else if (self.profile.userId)
			self.applicationsGet(self.profile.userId, false, 'all', renderDataspaceUl);

//    self.installedPackages(renderDataspaceUl);

	self.connectionsGet (self.profile.userId,
				'fullName,photo,homeLocation,dataspace', function(xmlDocRet) {
				 renderConnectionsWidget (xmlDocRet);
				 if (self.session.userId == self.profile.userId)
				     self.updateConnectionsInterface (xmlDocRet);
			     });

		if (self.session.sid) {
		OAT.Dom.show ($('groups_w'));
			self.discussionGroupsGet(self.profile.userId, renderDiscussionGroups);
		} else
	    OAT.Dom.hide ($('groups_w'));

	if (self.profile.userName)
			OAT.AJAX.GET(ODS.Preferences.activitiesEndpoint
					+ self.profile.userName + '/0/', false,
					renderNewsFeedBlock, optionsGet);
		else if (self.profile.dataspace.userName)
			OAT.AJAX.GET(ODS.Preferences.activitiesEndpoint
					+ self.profile.dataspace.userName + '/0/', false,
					renderNewsFeedBlock, optionsGet);

		self.session
				.usersGetInfo(
						self.profile.userId,
				   'title,fullName,photo,home,homeLocation,business,businessLocation,im',
				   function (xmlDoc3) {
				       renderContactInformationBlock (xmlDoc3);
				   });

		self.session.usersGetInfo(self.profile.userId, 'interestTopics,interests,music',
				   function (xmlDoc3) {
				       renderPersonalInformationBlock (xmlDoc3);
				   });

	var graphIRI = false;

		function RDFMInit() {
	    var head = document.getElementsByTagName ("head")[0];
	    var cssNode = document.createElement ('link');
	    var div = $("linkedDataC");
	    var r = new OAT.RDFMini (div, {showSearch:false});
	    cssNode.type = 'text/css';
	    cssNode.rel = 'stylesheet';
	    cssNode.href = "rdfm.css";
	    head.appendChild (cssNode);
	    if (graphIRI)
		r.open (graphIRI);
	}

	var graphIRI = self.odsLink (userProfileDataspace);
		var fList = [ "rdfmini", "dimmer", "grid", "graphsvg", "map",
				"timeline", "tagcloud", "anchor", "dock" ];
    OAT.Loader.load (fList, RDFMInit);

    OAT.MSG.send (self, "WA_PROFILE_UPDATED", {});

    };

	this.showProfile = function() {
	OAT.Dom.hide ('vspxApp');
	OAT.Dom.hide ('messages_div');
	OAT.Dom.hide ('contacts_interface');
	OAT.Dom.hide ('invitations_C');
	OAT.Dom.hide ('generalSearch_C');

	OAT.Dom.show ('u_profile_l');
	OAT.Dom.show ('u_profile_r');
    };

	this.showMessages = function() {
	OAT.Dom.hide ('vspxApp');
	OAT.Dom.hide ('u_profile_l');
	OAT.Dom.hide ('u_profile_r');
	OAT.Dom.hide ('contacts_interface');
	OAT.Dom.hide ('invitations_C');
	OAT.Dom.hide ('generalSearch_C');

	OAT.Dom.show ('messages_div');
    };

	this.showConnections = function() {
	OAT.Dom.hide ('vspxApp');
	OAT.Dom.hide ('u_profile_l');
	OAT.Dom.hide ('u_profile_r');
	OAT.Dom.hide ('messages_div');
	OAT.Dom.hide ('invitations_C');
	OAT.Dom.hide ('generalSearch_C');

	OAT.Dom.show ('contacts_interface');
    };

	this.showInvitations = function() {
	OAT.Dom.hide ('vspxApp');
	OAT.Dom.hide ('u_profile_l');
	OAT.Dom.hide ('u_profile_r');
	OAT.Dom.hide ('messages_div');
	OAT.Dom.hide ('contacts_interface');
	OAT.Dom.hide ('generalSearch_C');

	OAT.Dom.show ('invitations_C');
    };

	this.showSearch = function() {
	OAT.Dom.hide ('vspxApp');
	OAT.Dom.hide ('u_profile_l');
	OAT.Dom.hide ('u_profile_r');
	OAT.Dom.hide ('messages_div');
	OAT.Dom.hide ('contacts_interface');
	OAT.Dom.hide ('invitations_C');

	OAT.Dom.show ('generalSearch_C');
    };

	this.loadVspx = function(url) {
	OAT.Dom.hide ('u_profile_l');
	OAT.Dom.hide ('u_profile_r');
	OAT.Dom.hide ('messages_div');
	OAT.Dom.hide ('contacts_interface');
	OAT.Dom.hide ('invitations_C');
	OAT.Dom.hide ('generalSearch_C');

	var iframe = $('vspxApp');
	OAT.Dom.show (iframe);
	iframe.src = (url);
    };

	this.frontPage = function() {
		if (this.session.userName)
			return this.expandURL(this.ods + 'myhome.vspx');

		return this.expandURL(this.ods + 'sfront.vspx');
	};

	this.loadCheckedVspx = function(url) {
    var x = function (data) {
      var xml = OAT.Xml.createXmlDoc(data);
      if (hasError(xml, false)) {
				self.session.end();
      } else {
	      self.loadVspx(url);
	    }
    }
    OAT.AJAX.GET('/ods/api/user.validate?sid='+self.session.sid+'&realm='+self.session.realm, false, x);
	};

	this.loadRDFB = function(url, useFrame) {
		if (typeof (url) == 'undefined')
			return;

	if (url.indexOf (document.location.protocol + '//') < 0)
			var rdfbUrl = '/rdfbrowser/index.html?uri=' + encodeURIComponent(self.odsLink()+ url);
	else
	    var rdfbUrl = '/rdfbrowser/index.html?uri=' + encodeURIComponent (url);

	if (typeof (useFrame) != 'undefined')
	    self.loadVspx (rdfbUrl);
	else
	    window.open (rdfbUrl);
	return;
    };

	this.expandURL = function(url) {
	var retUrl = url;

		if (self.session.userName) {
		if (url.indexOf ('?') >- 1)
				retUrl = url + '&sid=' + self.session.sid + '&realm='+ self.session.realm;
		else
				retUrl = url + '?sid=' + self.session.sid + '&realm='+ self.session.realm;
	    }
	return retUrl;
    };

	this.wait = function(blah) {
    dd ('Warning: Obsolete function wait called.');
      return;
  }

	this.show_app_throbber = function(app_menu_elem) {
		if (!this.throbberImg) {
	this.appIconSaveBag = OAT.Dom.create ('div', {display: "none"});
	this.throbberImg = OAT.Dom.create ('img', {}, 'throbber_img');
	this.appIconSave = OAT.Dom.create ('img');
	OAT.Dom.append ([this.appIconSaveBag, this.throbberImg, this.appIconSave]);
	this.throbberImg.id = "APP_THROBBER"
	this.throbberImg.src = 'images/throbber.gif';
	    }

    this.hide_app_throbber ();
    this.loading_app_menu_elem = app_menu_elem;

    var app_icon = getChildElemsByClassName (app_menu_elem, 'app_icon', 3, true)[0];
    OAT.Dom.hide (app_icon);

    var app_icon_par = app_icon.parentNode;
    this.appIconSave = app_icon_par.replaceChild (this.throbberImg, app_icon)
    OAT.Dom.show (this.throbberImg);
  };

	this.hide_app_throbber = function() {
		if (this.loading_app_menu_elem) {
			var throbber = getChildElemsByClassName(this.loading_app_menu_elem,
					'throbber_img', 2, true)[0];
	  OAT.Dom.hide (this.throbberImg);

	  var throbber_par = throbber.parentNode;
			this.throbberImg = throbber_par.replaceChild(this.appIconSave,
					throbber);
	  OAT.Dom.show (this.appIconSave);
	  this.loading_app_menu_elem = false;
	    }
    };

	this.dimmerMsg = function(msg, callback) {
		var div = OAT.Dom.create('div', {
			background : '#FFF',
					  cursor    : 'pointer',
			padding : '10px'
		})
	div.innerHTML = '' + msg;
	div.id = 'dimmerMsg';
		if (typeof (callback) == "function") {
			OAT.Event.attach(div, "click", function() {
				      OAT.Dimmer.hide ();
				      callback ();
				  });
		} else
      setTimeout ('OAT.Dimmer.hide ()', 5000)
		OAT.Event.attach(div, "click", function() {OAT.Dimmer.hide();});

	OAT.Dimmer.hide ();
		OAT.Dimmer.show(div, {popup : true});
	OAT.Dom.center (div, 1, 1);

	if (typeof (callback) == "function")
	    OAT.Event.attach (OAT.Dimmer.root, "click", callback);
    };

	var ajaxOptions = {
		auth : OAT.AJAX.AUTH_BASIC,
		onerror : function(request) {dd(request.getStatus());}
    };

  this.installedPackages = function (callbackFunction) {
	var data = 'sid=' + (self.session.sid ? self.session.sid : '');
    var callback = function (xmlString) {
	    var xmlDoc = OAT.Xml.createXmlDoc (xmlString);
			if (!self.session.isErr(xmlDoc)) {
		    if (typeof (callbackFunction) == "function")
			callbackFunction (xmlDoc);
		}
	};

		OAT.AJAX.POST(self.session.endpoint + "installedPackages", data,
				callback, ajaxOptions);
    };

  this.applicationsGet = function (userIdentity, applicationType, scope, callbackFunction) {
	var data = 'sid=' + (self.session.sid ? self.session.sid : '');

    if (typeof (userIdentity) != 'undefined' && userIdentity != false)
	    data += '&userIdentity=' + userIdentity;

    if (typeof (applicationType) != 'undefined' && applicationType != false)
	    data += '&applicationType=' + applicationType;

	if (typeof (scope) != 'undefined')
	    data += '&scope=' + scope;

		var callback = function(xmlString) {
	    var xmlDoc = OAT.Xml.createXmlDoc (xmlString);

			if (!self.session.isErr(xmlDoc)) {
		    if (typeof (callbackFunction) == "function")
			callbackFunction(xmlDoc);
		}
	};
		OAT.AJAX.POST(self.session.endpoint + "applicationsGet", data, callback, ajaxOptions);
    };

  this.checkApplication = function (applicationType, callbackFunction) {
	if (applicationType == 'FeedManager')
	    applicationType = 'Feed Manager';

		else if (applicationType == 'InstantMessenger')
	    applicationType = 'Instant Messenger';

		var data = 'sid=' + self.session.sid + '&application=' + encodeURIComponent(applicationType);
		var callback = function(xmlString) {
	    var xmlDoc = OAT.Xml.createXmlDoc (xmlString);
			if (!self.session.isErr(xmlDoc)) {
		    if (typeof (callbackFunction) == "function")
			callbackFunction (xmlDoc);
			} else {
				self.session.end();
				// self.wait();
		}
    }
		OAT.AJAX.POST(self.session.endpoint + "checkApplication", data, callback, ajaxOptions);
	};

  this.userCommunities = function (callbackFunction) {
	self.wait ();

	var data = 'sid=' + self.session.sid;

    var callback = function (xmlString) {
	    var xmlDoc = OAT.Xml.createXmlDoc (xmlString);
			if (!self.session.isErr(xmlDoc)) {
		    if (typeof (callbackFunction) == "function")
			callbackFunction (xmlDoc);
			} else {
		    self.wait ();
		}
	};

	OAT.AJAX.POST (self.session.endpoint + "userCommunities", data, callback, ajaxOptions);
    };

  this.invitationsGet = function (extraFields, callbackFunction) {
	self.wait ();
	var data = 'sid=' + self.session.sid + '&extraFields=' + encodeURIComponent (extraFields);

		var callback = function(xmlString) {
	    var xmlDoc = OAT.Xml.createXmlDoc (xmlString);
			if (!self.session.isErr(xmlDoc)) {
		    if (typeof (callbackFunction) == "function")
			callbackFunction (xmlDoc);
			} else {
		    self.wait();
		}
	};

    OAT.AJAX.POST (self.session.endpoint + "invitationsGet", data, callback, ajaxOptions);
    };

  this.connectionsGet = function (userId, extraFields, callbackFunction) {
	self.wait ();

		var data = 'sid=' + self.session.sid + '&userId=' + userId
				+ '&extraFields=' + encodeURIComponent(extraFields);

    var callback = function (xmlString) {
	    var xmlDoc = OAT.Xml.createXmlDoc (xmlString);
			if (!self.session.isErr(xmlDoc)) {
		    if (typeof (callbackFunction) == "function")
			callbackFunction (xmlDoc);
			} else {
		    self.wait ();
		}
	};
    OAT.AJAX.POST (self.session.endpoint + "connectionsGet", data, callback, ajaxOptions);
    };

	this.connectionSet = function(connectionId, action, callbackFunction) {
    //action invite 1,confirm 2, disconnect 0

        self.wait ();

	var data = 'sid=' + self.session.sid + '&connectionId=' + connectionId + '&action=' + action;

		var callback = function(xmlString) {
	    var xmlDoc = OAT.Xml.createXmlDoc(xmlString);

			if (!self.session.isErr(xmlDoc)) {
		    if (typeof (callbackFunction) == "function")
			callbackFunction (xmlDoc);
			} else {
		    self.wait ();
		}
	};
    OAT.AJAX.POST (self.session.endpoint + "connectionSet", data, callback, ajaxOptions);
    };

	this.discussionGroupsGet = function(userId, callbackFunction) {
	var data = 'sid=' + self.session.sid + '&userId=' + userId;

    var callback = function (xmlString) {
	    var xmlDoc = OAT.Xml.createXmlDoc (xmlString);

			if (!self.session.isErr(xmlDoc)) {
		    if (typeof (callbackFunction) == "function")
			callbackFunction (xmlDoc);
		}
	};
    OAT.AJAX.POST (self.session.endpoint + "userDiscussionGroups", data, callback, ajaxOptions);
    };

	this.feedStatusSet = function(feedId, feedStatus, callbackFunction) {
	var data = 'sid=' + self.session.sid + '&feedId=' + feedId + '&feedStatus=' + feedStatus;

    var callback = function (xmlString) {
	    var xmlDoc = OAT.Xml.createXmlDoc (xmlString);

			if (!self.session.isErr(xmlDoc)) {
		    if (typeof (callbackFunction) == "function")
			callbackFunction (xmlDoc);
		}
	};
    OAT.AJAX.POST (self.session.endpoint + "feedStatusSet", data, callback, ajaxOptions);
    };

    this.feedStatus = function (callbackFunction) {

	var data = 'sid=' + self.session.sid;

    var callback = function (xmlString) {
	    var xmlDoc = OAT.Xml.createXmlDoc (xmlString);
			if (!self.session.isErr(xmlDoc)) {
		    if (typeof (callbackFunction) == "function")
			callbackFunction (xmlDoc);
		}
	};

	OAT.AJAX.POST (self.session.endpoint + "feedStatus", data, callback, optionsSynch);
    };

	this.userMessages = function(msgType, callbackFunction) {
	var data = 'sid=' + self.session.sid + '&msgType=' + msgType;

    var callback = function (xmlString) {
	    var xmlDoc = OAT.Xml.createXmlDoc (xmlString);

			if (!self.session.isErr(xmlDoc)) {
		    if (typeof (callbackFunction) == "function")
			callbackFunction (xmlDoc);
		}
	};

	OAT.AJAX.POST (self.session.endpoint + "userMessages", data, callback, ajaxOptions);
    };

	this.userMessageSend = function(recipientId, msg, senderId, callbackFunction) {
      var data = 'sid=' + self.session.sid + '&recipientId=' + recipientId + '&msg=' + encodeURIComponent (msg);

      if (typeof (senderId) != 'undefined' && senderId)
	  data = data + '&senderId=' + senderId;

		var callback = function(xmlString) {
	    var xmlDoc = OAT.Xml.createXmlDoc (xmlString);

			if (!self.session.isErr(xmlDoc)) {
				var respObj = buildObjByAttributes(OAT.Xml.xpath(xmlDoc, '/userMessageSend_response/message', {})[0]);

				if (respObj.status == 1) {
			    OAT.Dom.show ($('msgSentTxt'));
					setTimeout(function() {OAT.Dom.hide($('msgSentTxt'));}, 3000);

			    OAT.Dom.show ($('msgSentTxtWin'));
					setTimeout(function() {OAT.Dom.hide($('msgSentTxtWin'));}, 3000);
			}

		    if (typeof (callbackFunction) == "function")
			callbackFunction (xmlDoc);
		}
	};
		OAT.AJAX.POST(self.session.endpoint + "userMessageSend", data, callback, optionsSynch);
    };

	this.userMessageStatusSet = function(msgId, msgStatus, callbackFunction) {
	var data = 'sid=' + self.session.sid + '&msgId=' + msgId + '&msgStatus=' + msgStatus;

    var callback = function (xmlString) {
	    var xmlDoc = OAT.Xml.createXmlDoc (xmlString);
			if (!self.session.isErr(xmlDoc)) {
		    if (typeof (callbackFunction) == "function")
			callbackFunction (xmlDoc);
		}
	};
		OAT.AJAX.POST(self.session.endpoint + "userMessageStatusSet", data, callback, ajaxOptions);
    };

	this.search = function(searchParamsStr, callbackFunction) {
		var data = 'sid=' + self.session.sid + '&searchParams='
				+ encodeURIComponent(searchParamsStr);

		var callback = function(xmlString) {
	    var xmlDoc = OAT.Xml.createXmlDoc (xmlString);

			if (!self.session.isErr(xmlDoc)) {
		    if (typeof (callbackFunction) == "function")
			callbackFunction (xmlDoc);
		}
	};
		OAT.AJAX.POST(self.session.endpoint + "search", data, callback, optionsSynch);
    };

	this.searchContacts = function(searchParamsStr, callbackFunction) {
		var data = 'sid=' + self.session.sid + '&searchParams='
				+ encodeURIComponent(searchParamsStr);
    var callback = function (xmlString) {
	    var xmlDoc = OAT.Xml.createXmlDoc (xmlString);
			if (!self.session.isErr(xmlDoc)) {
		    if (typeof (callbackFunction) == "function")
			callbackFunction (xmlDoc);
		}
	};
		OAT.AJAX.POST(self.session.endpoint + "searchContacts", data, callback, optionsSynch);
    };

	this.tagSearchResult = function(tagParamsStr, callbackFunction) {
		var data = 'sid=' + self.session.sid + '&tagParams='
				+ encodeURIComponent(tagParamsStr);

    var callback = function (xmlString) {
	    var xmlDoc = OAT.Xml.createXmlDoc (xmlString);
			if (!self.session.isErr(xmlDoc)) {
		    if (typeof (callbackFunction) == "function")
			callbackFunction (xmlDoc);
		}
	};
		OAT.AJAX.POST(self.session.endpoint + "tagSearchResult", data,
				callback, ajaxOptions);
    };

	this.serverSettings = function() {
      var data = '';

		var callback = function(xmlString) {
	  var xmlDoc = OAT.Xml.createXmlDoc (xmlString);

			if (!self.session.isErr(xmlDoc)) {
		  if (!self.serverOptions.uriqaDefaultHost)
					self.serverOptions.uriqaDefaultHost = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc,'/serverSettings_response/uriqaDefaultHost',{})[0]);

				if (OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc,'/serverSettings_response/useRDFB', {})[0]) == '1')
		      self.serverOptions.useRDFB = 1;

				var googleKey = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/serverSettings_response/googleMpasKey', {})[0]);
		  if (googleKey != '')
		      window._apiKey = googleKey;
	      }
      };

		OAT.AJAX.POST(self.session.endpoint + "serverSettings", data, callback,
				ajaxOptions);
    };

	this.ui = {
		newMsgWin : function(anchorObj, sendToUid) {
	    if ($('sendBlockWin'))
		OAT.Dom.unlink ($('sendBlockWin').parentNode.parentNode);

			var msgWin = self.ui.newWindow( {
				close : 1,
					     resize : 1,
					     width  : 400,
					     height : 140,
				title : 'New Message'
			}, OAT.WindowData.TYPE_RECT);

	    var div = self.ui.renderSendBlock (sendToUid);
	    OAT.Dom.show (msgWin.div);
	    OAT.Dom.clear (msgWin.content);
	    OAT.Dom.append ([msgWin.content,div]);

	    var pos = OAT.Dom.position (anchorObj);
	    var size = OAT.Dom.getWH (anchorObj);
			if (isNaN(size[0]))
				size[0] = 0;

	    msgWin.anchorTo (pos[0] + size[0] - 5, pos[1]);
	},

		newWindow : function(options, type, parent) {
			if (!parent)
				parent = document.body;
			if (!type)
				type = 0;
	    var win = new OAT.Window (options, type);
			win.onclose = function() {
		OAT.Dom.hide (win.div);
	    }

 //  l.addLayer(win.div);
 //  win.resize._Resize_movers[0][2] = function(x,y){return x < 150 || y < 50;}

			var keyPress = function(event) {
				if (event.keyCode == 27) {
			win.onclose ();
		    }
	    };

	    OAT.Event.attach (win.div, "keypress", keyPress);
	    OAT.Dom.append ([parent, win.div]);
	    return win;
	},

		renderSendBlock : function(sendToUid) {
	    if (typeof (sendToUid) == 'undefined')
		var sendToUid =- 1;

	    var selectedUid = false;

			var container = OAT.Dom.create("div", {textAlign : 'center'});
	    container.id = 'sendBlockWin';

			var _span = OAT.Dom.create('span', {
				cssFloat : 'left',
				padding : '5px 0px 0px 5px'
			});

	    _span.innerHTML = 'To:';
			var msgUserSpan = OAT.Dom.create('span', {
				width : '45%',
						       cssFloat : 'left',
						       textAlign: 'left',
				padding : '5px 0px 0px 5px'
			});
	    msgUserSpan.id = 'msgUserSpanWin';

			var userList = OAT.Dom.create("select", {
				width : '45%',
						       cssFloat : 'right',
				margin : '0px 3px 5px 0px'
			});
	    userList.id = 'userListWin';

	    OAT.Dom.option ('&lt;Select recipient&gt;', -1, userList);

			for ( var i = 0; i < self.session.connections.length; i++) {
				for (cId in self.session.connections[i]) {
					OAT.Dom.option(self.session.connections[i][cId], cId,
							userList);

					if (cId == sendToUid) {
				    userList.selectedIndex = userList.options.length - 1;
				    msgUserSpan.innerHTML = self.session.connections[i][cId];
				    selectedUid = cId;
				}
			}
		}

			OAT.Event.attach(userList, "change", function(e) {
				  var t = eTarget (e);

				  if (t.options[t.selectedIndex].value == -1)
				      $('msgUserSpanWin').innerHTML = '';
				  else
				      $('msgUserSpanWin').innerHTML = t.options[t.selectedIndex].text;

				  $('sendBtnWin').sendto = t.options[t.selectedIndex].value;
			      });

			OAT.Event.attach(userList, "click", function(e) {
				  userList.style.color = '#000';
			      });

			var msgText = OAT.Dom.create('textarea', {width : '97%'});
	    msgText.id  = 'msgTextWin';

	    var sendBtn  = OAT.Dom.create ('input');
	    sendBtn.id   = 'sendBtnWin';
	    sendBtn.type = 'button';

	    if (!selectedUid)
		sendBtn.sendto = -1;
	    else
		sendBtn.sendto = selectedUid;

	    sendBtn.value = 'Send';

			OAT.Event.attach(sendBtn, "click", function(e) {
				  var t = eTarget (e);

				if (t.sendto == -1) {
					  userList.style.color = '#f00';
					  userList.focus ();
					  return;
				      }
				if ($('msgTextWin').value.length == 0) {
					  $('msgTextWin').focus ();
					  return;
				      }
				  userList.style.color = '#000';

				self.userMessageSend(t.sendto, $('msgTextWin').value, false,
							function () {
							    self.wait('hide');
							});
			      });

			var msgSentTxt = OAT.Dom.create('span', {
				color : 'green',
						      cssFloat : 'right',
						      padding  : '0px 5px 0px 0px',
						      display  : 'none',
				marginTop : '-18px'
			});
	    msgSentTxt.id = 'msgSentTxtWin';
	    msgSentTxt.innerHTML = " Message sent! ";

			OAT.Dom.append( [ container, _span, msgUserSpan, userList,
					OAT.Dom.create('br'), msgText, OAT.Dom.create('br'),
					sendBtn, msgSentTxt ]);

	    return container;
	},

		attachPersonBox : function(elm, connObj) {
			var connContent = OAT.Dom.create('div', {}, 'a_bubble conn_info_bubble');
	    connContent.innerHTML = $('connection_info_bubble').innerHTML;

	    var img = connContent.getElementsByTagName ('img')[0];

			if (typeof (img) != 'undefined') {
		    img.src = connObj.photo;
		    img.alt = connObj.fullName;
		}

	    var links = connContent.getElementsByTagName ('a');

	    if (typeof (links[0]) != 'undefined')
		links[0].href = self.odsLink (connObj.dataspace);

	    if (document.location.href == self.odsLink (connObj.dataspace))
				OAT.Event.attach(links[0], "click", function(e) {
				    var t = eTarget (e);
				    OAT.Anchor.close (t);
				    self.profile.show = true;
				    self.initProfile ();
				});

//        OAT.Event.attach(links[0],"click",function() {self.profile.show=true; self.profile.set(connObj.uid) ;self.initProfile();});

			if (typeof (links[1]) != 'undefined') {
		    links[1].uid = connObj.uid;
				if (self.session.sid && self.session.userId != connObj.uid) {
					if (self.session.connectionsId
							&& self.session.connectionsId.find(connObj.uid) > -1
							&& typeof (connObj.invited) == 'undefined') {
				    links[1].innerHTML = 'Disconnect';
						OAT.Event.attach(links[1], "click", function(e) {
						       var t = eTarget (e);
						       OAT.Anchor.close (t);
							self.connectionSet(t.uid, 0, function() {
									       self.session.connectionRemove (t.uid);
									       self.initProfile ();
									   });
						   });
					} else if (self.session.connectionsId
							&& self.session.connectionsId.find(connObj.uid) > -1
							&& typeof (connObj.invited) != 'undefined'
							&& connObj.invited == 1) {
					links[1].innerHTML = 'Withdraw invitation';
						OAT.Event.attach(links[1], "click", function(e) {
                                                            var t = eTarget (e);
                                                            OAT.Anchor.close (t);
							self.connectionSet(t.uid, 4, function() {
										    self.session.connectionRemove (t.uid);
										    self.initProfile ();
										});
							});
					} else if (self.session.userId != connObj.uid) {
					    links[1].innerHTML = 'Connect';
						OAT.Event.attach(links[1], "click", function(e) {
								var t = eTarget (e);
							self.connectionSet(t.uid, 1, function() {
											self.initProfile();
										    });
							    });
					}
				} else if (!self.session.sid && self.session.userId != connObj.uid) {
				links[1].innerHTML='Connect';
					OAT.Event
							.attach(
									links[1],
									"click",
						function (e) {
						    var t = eTarget (e);
						    OAT.Anchor.close (t);
										self.defaultAction = function() {
											self.connectionSet(
															t.uid,
									       1,
									       function (xmlDoc) {
																var msg = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc,'/connectionSet_response/message',{})[0]);
																if (msg && msg.length > 0)
							     // self.dimmerMsg (msg);
							     ;
																else {
																	self.session.connectionAdd(t.uid);
																	self.session.invitationAdd(t.uid);
										       }
										   self.connections.show = true;
																self.connectionsGet(
																				self.session.userId,
													'fullName,photo,homeLocation,dataspace',
													self.updateConnectionsInterface);
									       });
							};
						    self.logIn();
						});
				} else
			    OAT.Dom.hide (links[1].parentNode);
		}

//          OAT.Event.attach(links[0],"click",function() {self.profile.show=true; self.profile.set(connObj.uid) ;self.initProfile();});
//         }
			if (typeof (links[2]) != 'undefined') {
		    links[2].uid = connObj.uid;
				OAT.Event.attach(links[2], "click", function(e) {
					  var t = eTarget (e);
					  OAT.Anchor.close (t);
					  self.connections.show = true;
					  self.connections.userId = t.uid;
					  self.connectionsGet (self.connections.userId,
							       'fullName,photo,homeLocation,dataspace',
							       self.updateConnectionsInterface);
				      });
		}

			if (typeof (links[3]) != 'undefined'
					&& self.serverOptions.useRDFB == 1) {
				links[3].href = '/rdfbrowser/index.html?uri=' + encodeURIComponent(document.location.protocol
						+ '//'
						+ self.serverOptions.uriqaDefaultHost
						+ connObj.dataspace);
		    links[3].target = "_blank";
			} else
		OAT.Dom.hide (links[3].parentNode);

	    var obj = {
		title         : connObj.fullName,
		content       : connContent,
		status        : "",
		result_control: false,
		activation    : "click",
		enabledButtons: "c",
				visibleButtons : "c"
	    };
	    OAT.Anchor.assign (elm, obj);
	}

    }; //end ui

	// XXX: Generic util funcs needn't be methods

	this.createCookie = function(name, value, hours) {
		if (hours) {
		var date = new Date ();
		date.setTime (date.getTime () + (hours * 60 * 60 * 1000));
		var expires = "; expires=" + date.toGMTString ();
		} else
	    var expires = "";

	document.cookie = name + "=" + value + expires + "; path=/";
    };

	this.readCookie = function(name) {
	var cookiesArr = document.cookie.split (';');

		for ( var i = 0; i < cookiesArr.length; i++) {
		cookiesArr[i] = cookiesArr[i].trim ();

		if (cookiesArr[i].indexOf (name+'=') == 0)
		    return cookiesArr[i].substring (name.length + 1, cookiesArr[i].length);
	    }

	return false;
    };

	this.odsLink = function(extPath) {
	var odsLink = '';
    var odsHost = document.location.host;
    //	self.serverOptions.uriqaDefaultHost ?  self.serverOptions.uriqaDefaultHost : document.location.host;

	if (typeof (extPath) != 'undefined')
	    odsLink = document.location.protocol + '//' + odsHost+extPath;
	else
	    odsLink = document.location.protocol + '//' + odsHost;

	return odsLink;
    };

	self.serverSettings();
    var uriParams = OAT.Dom.uriParams();
    var cookieSid = this.readCookie ('sid');

	if (typeof (uriParams['form']) != 'undefined' && uriParams['form'] == 'login')
	{
    self.loadVspx(self.frontPage());
	  self.logIn();
	}
	else if (typeof (uriParams['form']) != 'undefined' && uriParams['form'] == 'register')
	{
		self.loadVspx(self.expandURL(self.ods + 'register.vspx'));
	}
	else if (!self.session.sid && typeof (uriParams['openid.signed']) != 'undefined' && uriParams['openid.signed'] != '')
	{
	  self.logIn();
		lfTab.go(1);
	}
	else if (!self.session.sid && (typeof (uriParams['oauth_verifier']) != 'undefined' && uriParams['oauth_verifier'] != '') && (typeof (uriParams['oauth_token']) != 'undefined' && uriParams['oauth_token'] != ''))
	{
	  self.logIn();
	  if (uriParams['oid-mode'] == 'twitter')
		lfTab.go(4);
		else
		  lfTab.go(5);
	}
	else if (!self.session.sid && typeof (uriParams['openid.mode']) != 'undefined' && uriParams['openid.mode'] == 'cancel')
	{
	  self.logIn();
	}
	else if (typeof (uriParams.sid) != 'undefined' && uriParams.sid != '')
	{
		    self.session.sid = uriParams.sid;
		    self.session.validateSid ();
	}
	else if (!self.session.sid && cookieSid)
	{
			self.session.sid = cookieSid;
			self.session.validateSid ();
	}
	else
	{
		OAT.MSG.send(self.session, "WA_SES_VALIDATION_END", {sessionValid: 0});
		    }

	OAT.Event.attach($('vspxApp'), "load", function() {
	  self.hide_app_throbber();
	});
	OAT.Event.attach($('vspxApp'), "load", function() {
						if (!self.session.sid) {
							var getParams = OAT.Browser.isIE ? $('vspxApp').contentWindow.location.href: $('vspxApp').contentDocument.location.search;
		  if (getParams.indexOf('oid-mode=') > -1)
		    return;

							if (getParams.indexOf('sid=') > -1) {
								var iframeSid = getParams.substring(getParams.indexOf('sid=') + 4, getParams.length);
								iframeSid = iframeSid.substring(0, iframeSid.indexOf('&'));
					  self.session.sid = iframeSid;
					  self.session.validateSid ();
				      }
			      }
		      });

	if ($('search_textbox')) {
		$('search_textbox').callback = function(e) {
		    if ($('search_lst_sort'))
			$('search_lst_sort').selectedIndex = 0;

		    if ($('search_focus_sel'))
			$('search_focus_sel').selectedIndex = 0;

		    var t = eTarget (e);
			if (t && t.value && t.value.length < 2) {
			    self.dimmerMsg ('Invalid keyword string entered.');
			    return;
			}
			if (t && t.value && t.value.length > 0) {
//                                                nav.loadVspx(nav.expandURL(nav.ods+'search.vspx?q='+encodeURIComponent(t.value.trim())));
			    $('search_textbox_searchC').value = t.value;
				self.search('q=' + encodeURIComponent(t.value.trim()) + '&on_all=1', self.renderSearchResults);
			}
		};

	    OAT.Event.attach ($('search_textbox'), "keypress", onEnterDown);
	}

    OAT.Event.attach ($('search_textbox'), "keypress", onEnterDown);

	if ($('search_img')) {
		$('search_img').callback = function() {
		    if ($('search_lst_sort'))
			$('search_lst_sort').selectedIndex = 0;

		    if ($('search_focus_sel'))
			$('search_focus_sel').selectedIndex = 0;

		    var t = $('search_textbox');

			if (t && t.value && t.value.length < 2) {
			    self.dimmerMsg ('Invalid keyword string entered.');
			    return;
			}

//                                            if(t && t.value && t.value.length>0)
//                                                nav.loadVspx(nav.expandURL(nav.ods+'search.vspx?q='+encodeURIComponent(t.value.trim())));
//                                            else
//                                                nav.loadVspx(nav.expandURL(nav.ods+'search.vspx'));

			if (t && t.value && t.value.length > 0) {
			    $('search_textbox_searchC').value = t.value;
				self
						.search(
								'q=' + encodeURIComponent(t.value.trim()) + '&on_all=1',
					 self.renderSearchResults);
			} else
			self.showSearch ();
		};
	}

    this.initLeftBar();
    this.initRightBar();
    this.initAppMenu();
    this.initSearch();

    this.createCookie ('interface','js',1);
}

var navOptions = {
	leftbar : 'ods_logo',
		   rightbar : 'ODS_BAR',
	appmenu : 'APP_MENU_C'
};

ODSInitArray.push (initNav);

var nav          = false;
var options      = false;
var optionsSynch = false;
var optionsGet   = false;

function initNav() {
	options = {
		auth : OAT.AJAX.AUTH_BASIC,
	       noSecurityCookie : 1,
		onerror: function(request) {dd(request.getStatus());}
    };

	optionsSynch = {
		auth : OAT.AJAX.AUTH_BASIC,
		    async   : false,
		onerror: function(request) {dd(request.getStatus());}
    };

	optionsGet = {
		auth : OAT.AJAX.AUTH_NONE,
		  noSecurityCookie : 1,
		onerror : function(request) {dd(request.getStatus());}
    };

    var vpsize = OAT.Dom.getViewport ();

    $('RT').style.width = vpsize[0] - 168 + 'px';
    $('vspxApp').style.height = vpsize[1] - 80 + 'px';

    nav = new ODS.Nav (navOptions);
  var x = x;
}

