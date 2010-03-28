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
var rfTab;
var ufTab;
var pfPages = [['pf_page_0_0', 'pf_page_0_1', 'pf_page_0_2', 'pf_page_0_3', 'pf_page_0_4', 'pf_page_0_5', 'pf_page_0_6', 'pf_page_0_7', 'pf_page_0_8', 'pf_page_0_9'], ['pf_page_1_0', 'pf_page_1_1', 'pf_page_1_2', 'pf_page_1_3'], ['pf_page_2']];

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
		lfTab = new OAT.Tab("lf_content");
		lfTab.add("lf_tab_0", "lf_page_0");
		lfTab.add("lf_tab_1", "lf_page_1");
		lfTab.add("lf_tab_2", "lf_page_2");
		lfTab.add("lf_tab_3", "lf_page_3");
		lfTab.go(0);
    var uriParams = OAT.Dom.uriParams();
    if (uriParams['oid-type'] == 'lf') {
      OAT.Dom.show('lf');
      OAT.Dom.hide('rf');
      lfTab.go(1);
      if (typeof (uriParams['openid.signed']) != 'undefined' && uriParams['openid.signed'] != '') {
        var q = openIdLoginURL(uriParams);
      OAT.AJAX.POST ("/ods/api/user.authenticate", q, afterLogin);
    }
    else if (typeof (uriParams['openid.mode']) != 'undefined' && uriParams['openid.mode'] == 'cancel')
  {
      alert('OpenID Authentication Failed');
    }
				}
	}
	if ($("rf")) {
		rfTab = new OAT.Tab("rf_content");
		rfTab.add("rf_tab_0", "rf_page_0");
		rfTab.add("rf_tab_1", "rf_page_1");
		rfTab.add("rf_tab_2", "rf_page_2");
		rfTab.add("rf_tab_3", "rf_page_3");
		rfTab.go(0);

    var uriParams = OAT.Dom.uriParams();
    if (uriParams['oid-type'] == 'rf') {
      OAT.Dom.hide('lf');
      OAT.Dom.show('rf');
	    rfTab.go(1);
      if (typeof (uriParams['openid.signed']) != 'undefined' && uriParams['openid.signed'] != '') {
        var x = function (params, param, data, property) {
          if (params[param])
            data[property] = params[param];
        }
        var data = {};
        x(uriParams, 'openid.sreg.nickname', data, 'nick');
        x(uriParams, 'openid.sreg.email', data, 'mbox');
        x(uriParams, 'openid.sreg.fullname', data, 'name');
        x(uriParams, 'openid.sreg.dob', data, 'birthday');
        x(uriParams, 'openid.sreg.gender', data, 'gender');
        x(uriParams, 'openid.sreg.postcode', data, 'homeCode');
        x(uriParams, 'openid.sreg.country', data, 'homeCountry');
        x(uriParams, 'openid.sreg.timezone', data, 'homeTimezone');
        x(uriParams, 'openid.sreg.language', data, 'language');
        x(uriParams, 'openid.identity', data, 'openid_url');
        x(uriParams, 'oid-srv', data, 'openid_server');

        $('lf_openId').value = uriParams['openid.identity'];
        $('rf_openId').value = uriParams['openid.identity'];
        $('rf_is_agreed').checked = true;
        var q = 'mode=1&data=' + encodeURIComponent(OAT.JSON.stringify(data, 10));
        OAT.AJAX.POST ("/ods/api/user.register", q, afterSignup);
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
	if (($("lf") || $("rf")) && (document.location.protocol == 'https:')) {
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
		if ($("uf_rdf_content"))
			cRDF = new OAT.RDFMini($("uf_rdf_content"), {
				showSearch : false
			});
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

function myBeforeSubmit ()
{
  needToConfirm = false;
  if ($('items')) {
    if ($v('formTab') == '0' && $v('formSubtab') == '6')
      $('items').value = prepareItems('r');
    if ($v('formTab') == '0' && $v('formSubtab') == '8' && $v('formMode') != '')
      $('items').value = prepareItems('ol');
    if ($v('formTab') == '0' && $v('formSubtab') == '9' && $v('formMode') != '')
      $('items').value = prepareItems('wl');
  }
}

var needToConfirm = true;
function myCheckLeave (form)
{
  var formTab = parseInt($v('formTab'));
  var formSubtab = parseInt($v('formSubtab'));
  var div = $(pfPages[formTab][formSubtab]);
  var dirty = false;
  var retValue = true;

  if ($('items')) {
    if ($v('formTab') == '0' && $v('formSubtab') == '6')
      $('items').value = prepareItems('r');
    if ($v('formTab') == '0' && $v('formSubtab') == '8' && $v('formMode') != '')
      $('items').value = prepareItems('ol');
    if ($v('formTab') == '0' && $v('formSubtab') == '9' && $v('formMode') != '')
      $('items').value = prepareItems('wl');
  }

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

function pfShowRows(prefix, values, delimiters, showRow) {
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

function pfShowFavorites() {
  var x = function (data)
  {
		var o = null;
		try {
			o = OAT.JSON.parse(data);
		} catch (e) {
			o = null;
		}
		if (o) {
      RDF.itemTypes = o;
      RDF.showItemTypes();
    }
  }
	OAT.AJAX.GET('/ods/api/user.favorites.list?sid='+encodeURIComponent($v('sid'))+'&realm='+encodeURIComponent($v('realm')), '', x);
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

function pfShowMade(mode, id) {
  if (mode) {
    OAT.Dom.hide('pf07_list');
    OAT.Dom.show('pf07_form');
    hiddenCreate('pf07_id', $('page_form'), id);
    $('formMode').value = mode;
  }
  pfShowItem('user.mades.get', 'pf07', ['property', 'uri', 'description']);
}

function pfShowOffer(mode, id) {
  if (mode) {
    OAT.Dom.hide('pf08_list');
    OAT.Dom.show('pf08_form');
    hiddenCreate('pf08_id', $('page_form'), id);
    $('formMode').value = mode;
  }
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
  if (mode) {
    OAT.Dom.hide('pf09_list');
    OAT.Dom.show('pf09_form');
    hiddenCreate('pf09_id', $('page_form'), id);
    $('formMode').value = mode;
  }
  var x = function(obj) {
    $('wl_tbody').innerHTML = '';
    RDF.tablePrefix = 'wl';
    RDF.tableOptions = {itemType: {fld_1: {cssText: "display: none;"}, btn_1: {cssText: "display: none;"}}};
    RDF.itemTypes = obj.properties;
    RDF.showItemTypes();
  }
  pfShowItem('user.seeks.get', 'pf09', ['name', 'comment'], x);
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
		if (facebookData) {
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
	var S = '/ods/api/user.info?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm')) + '&short=0';
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
				try {
        tbl.innerHTML = '';
				} catch (e) {}
        addProfileRow(tbl, user, 'name',      'Login Name');
				addProfileRow(tbl, user, 'nickName', 'Nick Name');
				addProfileRow(tbl, user, 'iri', 'IRI');
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
			showTitle('View Profile');

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
  if ((formTab == 0) && (formSubtab > 6)) {
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
      // personal
			// main
			fieldUpdate(user, 'name', 'pf_loginName');
			fieldUpdate(user, 'nickName', 'pf_nickName');
      fieldUpdate(user, 'mail',                   'pf_mail');
      fieldUpdate(user, 'title',                  'pf_title');
      fieldUpdate(user, 'firstName',              'pf_firstName');
      fieldUpdate(user, 'lastName',               'pf_lastName');
      fieldUpdate(user, 'fullName',               'pf_fullName');
      fieldUpdate(user, 'gender',                 'pf_gender');
      fieldUpdate(user, 'birthday',               'pf_birthday');
      fieldUpdate(user, 'homepage',               'pf_homepage');
      pfShowRows("x1", tagValue(user, "webIDs"), ["\n"], function(prefix, val1){TBL.createRow(prefix, null, {fld_1: {value: val1, className: '_validate_ _url_ _canEmpty_'}});});
			fieldUpdate(user, 'mailSignature', 'pf_mailSignature');
			fieldUpdate(user, 'sumary', 'pf_sumary');
			fieldUpdate(user, 'appSetting', 'pf_appSetting');
      pfShowRows("x2", tagValue(user, "interests"), ["\n", ";"], function(prefix, val1, val2){TBL.createRow(prefix, null, {fld_1: {value: val1, className: '_validate_ _url_ _canEmpty_'}, fld_2: {value: val2}});});
      pfShowRows("x3", tagValue(user, "topicInterests"), ["\n", ";"], function(prefix, val1, val2){TBL.createRow(prefix, null, {fld_1: {value: val1, className: '_validate_ _url_ _canEmpty_'}, fld_2: {value: val2}});});

			// address
      fieldUpdate(user, 'homeCountry',            'pf_homecountry');
			updateState('pf_homecountry', 'pf_homestate', tagValue(user, 'homeState'));
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

			// online accounts
      pfShowOnlineAccounts("x4", "P", function(prefix, val0, val1, val2){TBL.createRow(prefix, null, {id: val0, fld_1: {mode: 10, value: val1, className: '_validate_ _url_ _canEmpty_'}, fld_2: {value: val2}});});

      // bio events
      pfShowBioEvents("x5", function(prefix, val0, val1, val2, val3){TBL.createRow(prefix, null, {id: val0, fld_1: {mode: 11, value: val1}, fld_2: {value: val2}, fld_3: {value: val3}});});

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
			fieldUpdate(user, 'icq', 'pf_icq');
			fieldUpdate(user, 'skype', 'pf_skype');
			fieldUpdate(user, 'yahoo', 'pf_yahoo');
			fieldUpdate(user, 'aim', 'pf_aim');
			fieldUpdate(user, 'msn', 'pf_msn');
      pfShowRows("x6", tagValue(user, "messaging"), ["\n", ";"], function(prefix, val1, val2){TBL.createRow(prefix, null, {fld_1: {value: val1}, fld_2: {value: val2, cssText: 'width: 220px;'}});});

      // favorites
      pfShowFavorites();

      // business
			// main
      fieldUpdate(user, 'businessIndustry',       'pf_businessIndustry');
      fieldUpdate(user, 'businessOrganization',   'pf_businessOrganization');
      fieldUpdate(user, 'businessHomePage',       'pf_businessHomePage');
      fieldUpdate(user, 'businessJob',            'pf_businessJob');
			fieldUpdate(user, 'businessRegNo', 'pf_businessRegNo');
			fieldUpdate(user, 'businessCareer', 'pf_businessCareer');
			fieldUpdate(user, 'businessEmployees', 'pf_businessEmployees');
			fieldUpdate(user, 'businessVendor', 'pf_businessVendor');
			fieldUpdate(user, 'businessService', 'pf_businessService');
			fieldUpdate(user, 'businessOther', 'pf_businessOther');
			fieldUpdate(user, 'businessNetwork', 'pf_businessNetwork');
			fieldUpdate(user, 'businessResume', 'pf_businessResume');

      // address
      fieldUpdate(user, 'businessCountry',        'pf_businesscountry');
			updateState('pf_businesscountry', 'pf_businessstate', tagValue(user, 'businessState'));
      fieldUpdate(user, 'businessCity',           'pf_businesscity');
      fieldUpdate(user, 'businessCode',           'pf_businesscode');
      fieldUpdate(user, 'businessAddress1',       'pf_businessaddress1');
      fieldUpdate(user, 'businessAddress2',       'pf_businessaddress2');
      fieldUpdate(user, 'businessTimezone',       'pf_businessTimezone');
      fieldUpdate(user, 'businessLatitude',       'pf_businesslat');
      fieldUpdate(user, 'businessLongitude',      'pf_businesslng');
			fieldUpdate(user, 'defaultMapLocation', 'pf_businessDefaultMapLocation');
      fieldUpdate(user, 'businessPhone',          'pf_businessPhone');
      fieldUpdate(user, 'businessMobile',         'pf_businessMobile');

			// online accounts
      pfShowOnlineAccounts("y1", "B", function(prefix, val0, val1, val2){TBL.createRow(prefix, null, {id: val0, fld_1: {mode: 10, value: val1, className: '_validate_ _url_ _canEmpty_'}, fld_2: {value: val2}});});

			// contact
			fieldUpdate(user, 'businessIcq', 'pf_businessIcq');
			fieldUpdate(user, 'businessSkype', 'pf_businessSkype');
			fieldUpdate(user, 'businessYahoo', 'pf_businessYahoo');
			fieldUpdate(user, 'businessAim', 'pf_businessAim');
			fieldUpdate(user, 'businessMsn', 'pf_businessMsn');
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
			showTitle('Edit Profile');

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
      ontologyItems.push({"id": itemNo, "className": itemName, "properties": itemProperties});
    }
    ontologies.push(["ontology", ontologyName, "items", ontologyItems]);
  }
  return OAT.JSON.stringify(ontologies, 10);
}

function updateFavorites(prefix)
{
	// var S = '/ods/api/user.favorites.delete?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm'));
	// OAT.AJAX.GET(S,null,null,{async:false});

  S = '/ods/api/user.favorites.new?sid=' + encodeURIComponent($v('sid')) + '&realm=' + encodeURIComponent($v('realm')) + '&favorites=' + encodeURIComponent(prepareItems('r'));
  OAT.AJAX.GET(S,null,null,{async:false});
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
  else if ((formTab == 0) && (formSubtab == 4))
  {
    updateBioEvents('x5');
    ufProfileLoad(No);
  }
  else if ((formTab == 0) && (formSubtab == 6))
  {
    updateFavorites('x6');
    ufProfileLoad(No);
  }
  else if ((formTab == 1) && (formSubtab == 2))
  {
    updateOnlineAccounts('y1', 'B');
    ufProfileLoad(No);
  }
  else
  {
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
        if ($v('cb_item_i_homelng') == '1')
          S += '&homePhone=' + encodeURIComponent($v('i_homePhone'));
        if ($v('cb_item_i_businessOrganization') == '1')
          S += '&businessOrganization=' + encodeURIComponent($v('i_businessOrganization'));
        if ($v('cb_item_i_businessHomePage') == '1')
          S += '&businessHomePage=' + encodeURIComponent($v('i_businessHomePage'));
        if ($v('cb_item_i_sumary') == '1')
          S += '&sumary=' + encodeURIComponent($v('i_sumary'));
        if ($v('cb_item_i_tags') == '1')
          S += '&tags=' + encodeURIComponent($v('i_tags'));
        if ($v('cb_item_i_interests') == '1')
          S += '&interests=' + encodeURIComponent($v('i_interests'));
        if ($v('cb_item_i_topicInterests') == '1')
          S += '&topicInterests=' + encodeURIComponent($v('i_topicInterests'));
      }
      if (formSubtab == 1)
      {
        S = S
        + '&nickName=' + encodeURIComponent($v('pf_nickName'))
        + '&mail=' + encodeURIComponent($v('pf_mail'))
        + '&title=' + encodeURIComponent($v('pf_title'))
        + '&firstName=' + encodeURIComponent($v('pf_firstName'))
        + '&lastName=' + encodeURIComponent($v('pf_lastName'))
        + '&fullName=' + encodeURIComponent($v('pf_fullName'))
        + '&gender=' + encodeURIComponent($v('pf_gender'))
        + '&birthday=' + encodeURIComponent($v('pf_birthday'))
        + '&homepage=' + encodeURIComponent($v('pf_homepage'))
        + '&mailSignature=' + encodeURIComponent($v('pf_mailSignature'))
        + '&sumary=' + encodeURIComponent($v('pf_sumary'))
        + '&appSetting=' + encodeURIComponent($v('pf_appSetting'))
        + '&webIDs=' + encodeTableData("x1", ["\n"])
        + '&interests=' + encodeTableData("x2", ["\n", ";"])
        + '&topicInterests=' + encodeTableData("x3", ["\n", ";"]);
      }
      if (formSubtab == 2)
      {
        S = S
        + '&defaultMapLocation=' + encodeURIComponent($v('pf_homeDefaultMapLocation'))
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
  			+ '&homeMobile=' + encodeURIComponent($v('pf_homeMobile'));
  	  }
      if (formSubtab == 5)
      {
        S = S
        + '&icq=' + encodeURIComponent($v('pf_icq'))
        + '&skype=' + encodeURIComponent($v('pf_skype'))
        + '&yahoo=' + encodeURIComponent($v('pf_yahoo'))
        + '&aim=' + encodeURIComponent($v('pf_aim'))
        + '&msn=' + encodeURIComponent($v('pf_msn'))
        + '&messaging=' + encodeTableData("x6", ["\n", ";"])
      }
    }
    else if (formTab == 1)
    {
      if (formSubtab == 0)
      {
        S = S
  			+ '&businessIndustry=' + encodeURIComponent($v('pf_businessIndustry'))
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
  	  }
      if (formSubtab == 1)
      {
        S = S
        + '&businessCountry=' + encodeURIComponent($v('pf_businesscountry'))
        + '&businessState=' + encodeURIComponent($v('pf_businessstate'))
        + '&businessCity=' + encodeURIComponent($v('pf_businesscity'))
        + '&businessCode=' + encodeURIComponent($v('pf_businesscode'))
        + '&businessAddress1=' + encodeURIComponent($v('pf_businessaddress1'))
  			+ '&businessAddress2=' + encodeURIComponent($v('pf_businessaddress2'))
  			+ '&businessTimezone=' + encodeURIComponent($v('pf_businessTimezone'))
  			+ '&businessLatitude=' + encodeURIComponent($v('pf_businesslat'))
  			+ '&businessLongitude=' + encodeURIComponent($v('pf_businesslng'))
  			+ '&businessPhone=' + encodeURIComponent($v('pf_businessPhone'))
  			+ '&businessMobile=' + encodeURIComponent($v('pf_businessMobile'));
  	  }
      if (formSubtab == 3)
      {
        S = S
        + '&businessIcq=' + encodeURIComponent($v('pf_businessIcq'))
        + '&businessSkype=' + encodeURIComponent($v('pf_businessSkype'))
        + '&businessYahoo=' + encodeURIComponent($v('pf_businessYahoo'))
        + '&businessAim=' + encodeURIComponent($v('pf_businessAim'))
        + '&businessMsn=' + encodeURIComponent($v('pf_businessMsn'));
        + '&businessMessaging=' + encodeTableData("y2", ["\n", ";"])
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
  	OAT.AJAX.GET(S, '', function(data){pfUpdateCallback(data, No);});
  }
  return false;
}

function pfUpdateCallback(data, No) {
  var xml = OAT.Xml.createXmlDoc(data);
	if (!hasError(xml)) {
    ufProfileLoad(No);
  }
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
  showTitle('View Profile');

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
			pfSetFOAFValue(tbody, o.resume,               'Resume',                'i_sumary');
			pfSetFOAFValue(tbody, o.tags,                 'Tags',                  'i_tags');
			pfSetFOAFValue(tbody, o.interest,             'Topic of Interest',     'i_interests', ['URL', 'Label'], ['\n', ';']);
			pfSetFOAFValue(tbody, o.topic_interest,       'Thing of Interest',     'i_topicInterests', ['URI', 'Label'], ['\n', ';']);
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

 	showTitle('User Register');

  OAT.Dom.hide("ob_right_logout");
  OAT.Dom.hide("ob_links");

  OAT.Dom.hide("lf");
  OAT.Dom.show("rf");

  $('rf_uid').value = '';
  $('rf_email').value = '';
  $('rf_password').value = '';
  $('rf_password2').value = '';
  $('rf_openId').value = '';
  $('rf_is_agreed').checked = false;

  return false;
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
	  openIdAuthenticate('rf');
		return false;
	}
	else if (rfTab.selectedIndex == 2) {
		q +='&data=' + encodeURIComponent(OAT.JSON.stringify(facebookData, 10))
	}
	else if (rfTab.selectedIndex == 3) {
		q +='&data=' + encodeURIComponent(OAT.JSON.stringify(sslData, 10))
	}
	OAT.AJAX.POST("/ods/api/user.register", q, afterSignup);
	return false;
}

function afterSignup(data) {
 	var xml = OAT.Xml.createXmlDoc(data);
	if (!hasError(xml)) {
    $('rf_uid').value = '';
    $('rf_email').value = '';
    $('rf_password').value = '';
    $('rf_password2').value = '';
    $('rf_openID').value = '';
    $('rf_is_agreed').checked = false;
    afterLogin(data, 'rf');
  }
}

function openIdLoginURL(uriParams) {
  var openIdServer       = uriParams['oid-srv'];
  var openIdSig          = uriParams['openid.sig'];
  var openIdIdentity     = uriParams['openid.identity'];
  var openIdAssoc_handle = uriParams['openid.assoc_handle'];
  var openIdSigned       = uriParams['openid.signed'];

  var sig = openIdSigned.split(',');
  openIdSigned = '';
  for (var i = 0; i < sig.length; i++)
  {
    var _key = sig[i].trim();
    if (_key.indexOf('sreg.') != 0) {
      if (openIdSigned)
        openIdSigned += ',';
      openIdSigned += _key;
    }
  }
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
        _key != 'assoc_handle' &&
        _key.indexOf('sreg.') != 0)
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

    var openIdServer = OAT.Xml.textValue (OAT.Xml.xpath (xml, '/openIdServer_response/server', {})[0]);
    var openIdDelegate = OAT.Xml.textValue (OAT.Xml.xpath (xml, '/openIdServer_response/delegate', {})[0]);

    if (!openIdServer || openIdServer.length == 0)
      showError(' Cannot locate OpenID server');

    var oidIdent = $v(prefix+'_openId');
    if (openIdDelegate || openIdDelegate.length > 0)
      oidIdent = openIdDelegate;

    var thisPage  = document.location.protocol +
      '//' +
      document.location.host +
      document.location.pathname +
      '?oid-type=' +
      prefix +
      '&oid-srv=' +
      prefix +
      '&form=register' +
      '&oid-srv=' +
      encodeURIComponent (openIdServer);

    var trustRoot = document.location.protocol +
      '//' +
      document.location.host;

    var S = openIdServer +
      '?openid.mode=checkid_setup' +
      '&openid.identity=' + encodeURIComponent(oidIdent) +
      '&openid.return_to=' + encodeURIComponent(thisPage) +
      '&openid.trust_root=' + encodeURIComponent(trustRoot);
    if (prefix == 'rf')
      S += '&openid.sreg.optional='+encodeURIComponent('fullname,nickname,dob,gender,postcode,country,timezone') + '&openid.sreg.required=' + encodeURIComponent('email,nickname');
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
		T.innerHTML = txt;
}
