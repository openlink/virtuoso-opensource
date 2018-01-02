/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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
function urlParam(fldName)
{
  var O = document.forms[0].elements[fldName];
  if (O && O.value != '')
    return '&' + fldName + '=' + encodeURIComponent(O.value);
  return '';
}

function myA(obj) {
  if (obj.href) {
    document.location = obj.href + '?' + urlParam('sid') + urlParam('realm');
    return false;
  }
}

function AddAdr(obj,addr)
{
	fld = eval('document.f1.'+ obj.name);
  if (obj.checked) {
		if (fld.value.indexOf('~no name~') != -1)
			fld.value = '';
  	if (fld.value.length != 0)
			if (fld.value.substring(fld.value.length-1,fld.value.length) != ',')
				fld.value = fld.value + ',';
		fld.value = fld.value + addr;
	} else {
		pos = fld.value.indexOf(addr)
		if (pos != -1)
			fld.value = fld.value.substring(0,pos) + fld.value.substring(pos + addr.length+1,fld.value.length);
	}
}

function ClearFld(obj,fvalue)
{
	if (obj.value.indexOf(fvalue) != -1)
		obj.value = '';
}

showRow = (navigator.appName.indexOf("Internet Explorer") != -1) ? "block" : "table-row";

function getParent (obj, tag)
{
  var obj = obj.parentNode;
  if (obj.tagName.toLowerCase() == tag)
    return obj;
  return getParent(obj, tag);
}

function selectCheck (obj)
{
  coloriseRow(getParent(obj, 'tr'), obj.checked);
}

function toggleTab(obj, noValue)
{
  if (obj.checked == true)
  {
    OAT.Dom.hide('plain');
    OAT.Dom.show('rte');
  } else {
    OAT.Dom.show('plain');
    OAT.Dom.hide('rte');
  }
  if (noValue == null)
    toggleValue(obj);
}

function initTab(obj)
{
  initValue(obj);
  toggleTab(obj, true);
  returnValue(obj);
}

function toggleValue(obj)
{
  if (obj.checked == true)
  {
    var value = $v('plainMessage');
    oEditor.setData(text2rte(value));
  } else {
    oEditor.updateElement();
    var value = $v('rteMessage');
    $('plainMessage').value = rte2text(value);
  }
}

function initValue (obj)
{
  var value = $v('message');
  if (obj.checked == true)
  {
    oEditor.setData(initRte(value));
  } else {
    $('plainMessage').value = value;
  }
}

function returnValue(obj)
{
  var value;
  if (obj.checked == true)
  {
    oEditor.updateElement();
    value = $v('rteMessage');
  } else {
    value = $v('plainMessage');
  }
  document.forms['f1'].elements['message'].value = value;
}

function initEditor(rte)
{
  if (document.all)
  {
		var oRTE = frames[rte].document;
  	oRTE.designMode = "On";
	} else {
  	try {
  	  document.getElementById(rte).contentDocument.designMode = "on";
  	} catch (e) {
  		setTimeout("initEditor('" + rte + "');", 10);
  	}
	}
}

function clearRte(value) {
  var re;
  re = new RegExp('\r\n', 'gi');
  value = value.replace(re, '\n');
  re = new RegExp('\n', 'gi');
  value = value.replace(re, '');
  return value;
}

function initRte(value) {
  var re;
  re = new RegExp('\r\n', 'gi');
  value = value.replace(re, '\n');
  re = new RegExp('\n', 'gi');
  value = value.replace(re, '<br />');
  re = new RegExp("'", 'gi');
  value = value.replace(re, "&apos;");
  return value;
}

function text2rte(value) {
  var re;
  re = new RegExp('[ ][ ]', 'gi');
  value = value.replace(re, '&nbsp;&nbsp;');
  re = new RegExp('\r\n', 'gi');
  value = value.replace(re, '\n');
  re = new RegExp('\n', 'gi');
  value = value.replace(re, '<br />');
  return value;
}

function rte2text(value) {
  var re;
  re = new RegExp('&nbsp;', 'gi');
  value = value.replace(re, ' ');
  re = new RegExp('<br />', 'gi');
  value = value.replace(re, '\r\n');
  re = new RegExp('<br>', 'gi');
  value = value.replace(re, '\r\n');
  re = new RegExp('<p>', 'gi');
  value = value.replace(re, '');
  re = new RegExp('</p>', 'gi');
  value = value.replace(re, '\r\n');
	re = new RegExp('(<([^>]+)>)', 'gi');
  value = value.replace(re, '');
  return value;
}

function createHidden(aDocument, name, value) {
  var hidden;

  hidden = aDocument.forms["f1"].elements[name];
  if (hidden == null) {
    hidden = aDocument.createElement("input");
    hidden.setAttribute ("type", "hidden");
    hidden.setAttribute ("name", name);
    hidden.setAttribute ("id", name);
    aDocument.forms["f1"].appendChild(hidden);
  }
  hidden.value = value;
}

function dateFormat(date, format) {
	function long(d) {
		return ((d < 10) ? "0" : "") + d;
	}
	var result = "";
	var chr;
	var token;
	var i = 0;
	while (i < format.length) {
		chr = format.charAt(i);
		token = "";
		while ((format.charAt(i) == chr) && (i < format.length)) {
			token += format.charAt(i++);
		}
		if (token == "y")
			result += "" + date[0];
		else if (token == "yy")
			result += date[0].substring(2, 4);
		else if (token == "yyyy")
			result += date[0];
		else if (token == "M")
			result += date[1];
		else if (token == "MM")
			result += long(date[1]);
		else if (token == "d")
			result += date[2];
		else if (token == "dd")
			result += long(date[2]);
		else
			result += token;
	}
	return result;
}

function dateParse(dateString, format) {
	var result = null;
	var pattern = new RegExp(
			'^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])$');
	if (dateString.match(pattern)) {
		dateString = dateString.replace(/\//g, '-');
		result = dateString.split('-');
		result = [ parseInt(result[0], 10), parseInt(result[1], 10), parseInt(result[2], 10) ];
	}
	return result;
}

function datePopup(objName, format) {
	if (!format) {
		format = 'yyyy-MM-dd';
	}
	var obj = $(objName);
	var d = dateParse(obj.value, format);
	var c = new OAT.Calendar( {
		popup : true
	});
	var coords = OAT.Dom.position(obj);
	if (isNaN(coords[0])) {
		coords = [ 0, 0 ];
	}
	var x = function(date) {
		obj.value = dateFormat(date, format);
	}
	c.show(coords[0], coords[1] + 30, x, d);
}

function submitEnter(myForm, myButton, e) {
  var keycode;
  if (window.event)
    keycode = window.event.keyCode;
  else
    if (e)
      keycode = e.which;
    else
      return true;
  if (keycode == 13)
    document.forms[myForm].submit();
  return true;
}

function boxSubmit(value)
{
  createHidden (document, 'bp', value);
  createHidden (document, 'sort.x', '1');
  document.f1.submit ();
}

function attachSubmit(value)
{
  createHidden (document, 'fa_attach.x', '1');
  document.f1.submit ();
}

function groupSubmit (obj)
{
  createHidden (document, 'fa_group.x', obj.value);
  document.f1.submit ();
}

function formSubmit(myField, myValue)
{
  createHidden (document, myField, myValue);
  document.f1.submit ();
}

function confirmAction (confirmMsq, form, txt, selectionMsq)
{
  if (anySelected (form, txt, selectionMsq))
    return confirm (confirmMsq);
  return false;
}

function selectAllCheckboxes (obj, prefix)
{
  var objForm = obj.form;
  for (var i = 0; i < objForm.elements.length; i++) {
    var o = objForm.elements[i];
    if (o != null && o.type == "checkbox" && !o.disabled && o.name.indexOf (prefix) != -1) {
      if (obj.value == 'Select All')
        o.checked = true;
      else
        o.checked = false;
      coloriseRow(getParent(o, 'tr'), o.checked);
    }
  }
  if (obj.value == 'Select All')
    obj.value = 'Unselect All';
  else
    obj.value = 'Select All';
  selectCheck (obj, prefix);
  obj.focus();
}

function anySelected (form, txt, selectionMsq)
{
  if ((form != null) && (txt != null)) {
    for (var i = 0; i < form.elements.length; i++) {
      var obj = form.elements[i];
      if ((obj != null) && (obj.type == "checkbox") && (obj.name.indexOf (txt) != -1) && obj.checked)
        return true;
    }
    if (selectionMsq != null)
      alert(selectionMsq);
    return false;
  }
  return true;
}

function coloriseRow(obj, checked) {
  obj.className = (obj.className).replace('tr_select', '');
  if (checked)
    obj.className = obj.className + ' ' + 'tr_select';
}

function mailsShow(sPage, sPageName, width, height) {
  if ($('sencrypt').checked)
    sPage += '&certificate=1';

	windowShow(sPage, sPageName, width, height);
}

function windowShow(sPage, sPageName, width, height) {
  if (width == null)
		width = 700;
  if (height == null)
		height = 500;
  if (sPage.indexOf('sid=') == -1)
    sPage += urlParam('sid');
  if (sPage.indexOf('realm=') == -1)
    sPage += urlParam('realm');
  sPage += '&return=F1';
  win = window.open(sPage, sPageName, "width="+width+",height="+height+",top=100,left=100,status=yes,toolbar=no,menubar=no,scrollbars=yes,resizable=yes");
  win.window.focus();
}

function showTab2(tab, tabs)
{
  for (var i = 1; i <= tabs; i++) {
    var div = document.getElementById(i);
    if (div != null) {
      var divTab = document.getElementById('tab_'+i);
      if (i == tab) {
        var divNo = document.getElementById('tabNo');
        divNo.value = tab;
        div.style.visibility = 'visible';
        div.style.display = 'block';
        if (divTab != null) {
          divTab.className = "tab activeTab noapp";
          divTab.blur();
        };
      } else {
        div.style.visibility = 'hidden';
        div.style.display = 'none';
        if (divTab != null)
          divTab.className = "tab noapp";
      }
    }
  }
}

function initTab2(tabs, defaultNo)
{
  var divNo = document.getElementById('tabNo');
  var tab = defaultNo;
  if (divNo) {
    var divTab = document.getElementById('tab_'+divNo.value);
    if (divTab)
      tab = divNo.value;
  }
  showTab2(tab, tabs);
}

function addChecked (objForm, objName, selectionMsq)
{
  if (!anySelected (objForm, objName, selectionMsq, 'confirm'))
    return false;

  if (window.opener.document.f1.elements[objForm.elements["set"].value]) {
    var destField = window.opener.document.f1.elements[objForm.elements["set"].value];

    destField.value = (destField.value).replace(';', ',');
    destField.value = OMAIL.trim(destField.value);
    destField.value = OMAIL.trim(destField.value, ',');
    destField.value = OMAIL.trim(destField.value);
    destField.value = destField.value + ',';
    for (var i = 0; i < objForm.elements.length; i = i + 1) {
      var obj = objForm.elements[i];
      if (obj && obj.type == "checkbox" && obj.name == objName) {
        if (obj.checked && (destField.value.indexOf(obj.value+',') == -1)) {
          destField.value += obj.value + ',';
          objSibling = obj.nextSibling;
          if (objSibling && objSibling.type == "hidden")
            createHidden (window.opener.document, 'modulus_'+obj.value, objSibling.value);
          objSibling = objSibling.nextSibling;
          if (objSibling && objSibling.type == "hidden")
            createHidden (window.opener.document, 'public_exponent_'+obj.value, objSibling.value);
        }
      }
    }
    destField.value = OMAIL.trim(destField.value, ',');
  }
  window.close();
}

function davBrowse (fld)
{
  var options = {
    mode: 'browser',
    onConfirmClick: function(path, fname) {$(fld).value = '/DAV' + path + fname;}
                };
  OAT.WebDav.open(options);
}

function accountChange (obj)
{
  if (obj.name == 'type') {
    if (obj.value == 'pop3') {
      $('connect_type').value = 'none';
      $('port').value = '110';
      $('folder_id').value = '100';

      $('connect_type').disabled = false;
      $('folder_id').disabled = false;
    }
    if (obj.value == 'imap') {
      $('connect_type').value = 'none';
      $('port').value = '143';
      $('folder_id').value = '0';

      $('connect_type').disabled = true;
      $('folder_id').disabled = true;
    }
  }
  if (obj.name == 'connect_type') {
    if (obj.value == 'ssl') {
      $('port').value = '995';
    }
    if (obj.value == 'none') {
      $('port').value = '110';
    }
  }
}

function whatLabelChange(obj)
{
  if (obj.value == '1')
    $('whatLabel').innerHTML = 'Name';

  if (obj.value == '2')
    $('whatLabel').innerHTML = 'Mail';
}

function toggleDisabled(obj, toggles)
{
  for (var i = 0; i < toggles.length; i = i + 1) {
    if (obj.value) {
      $(toggles[i]).disabled = false;
    } else {
      $(toggles[i]).disabled = 'disabled';
    }
    if (i == 0)
      $(toggles[i]).checked = true;
    if (i == (toggles.length-1))
      $(toggles[i]).checked = false;
  }
}

var OMAIL = new Object();
OMAIL.forms = new Object();

OMAIL.trim = function (sString, sChar)
{

  if (sString)
{
  if (sChar == null)
    sChar = ' ';

  while (sString.substring(0,1) == sChar)
    sString = sString.substring(1, sString.length);

  while (sString.substring(sString.length-1, sString.length) == sChar)
    sString = sString.substring(0,sString.length-1);

  }
  return sString;
}

OMAIL.enableRadioGroup = function (cell)
{
  var c = $(cell);
  var r = document.forms['f1'].elements[cell+'_radio'];
  for (var i = 0; i < r.length; i = i + 1)
    r[i].disabled = !c.checked;
  }

OMAIL.toggleCell = function (cell)
{
  var c = $('row_'+cell);
  c.style.display = (c.style.display == "none") ? showRow : "none";
  var l = $('label_'+cell);
  l.innerHTML = l.innerHTML.replace((c.style.display == "none") ? 'Remove' : 'Add', (c.style.display == "none") ? 'Add' : 'Remove');
  var v = (c.style.display == "none") ? '0' : '1';
  createHidden (document, 'x_'+cell, v);
  if (document.forms['f1'].elements['eparams'])
  {
    var value = document.forms['f1'].elements['eparams'].value;
    var re = new RegExp('&x_'+cell+'=0', 'gi');
    value = value.replace(re, '');
    re = new RegExp('&x_'+cell+'=1', 'gi');
    value = value.replace(re, '');
    document.forms['f1'].elements['eparams'].value = value+'&x_'+cell+'='+v
  } else {
    createHidden (document, 'eparams', '&x_'+cell+'='+v);
  }
  return false;
}

OMAIL.writeCookie = function (name, value, hours)
{
  if (hours)
  {
    var date = new Date ();
    date.setTime (date.getTime () + (hours * 60 * 60 * 1000));
    var expires = "; expires=" + date.toGMTString ();
  } else {
    var expires = "";
  }
  document.cookie = name + "=" + value + expires + "; path=/";
}

OMAIL.readCookie = function (name)
{
  var cookiesArr = document.cookie.split (';');
  for (var i = 0; i < cookiesArr.length; i++)
  {
    cookiesArr[i] = cookiesArr[i].trim ();
    if (cookiesArr[i].indexOf (name+'=') == 0)
      return cookiesArr[i].substring (name.length + 1, cookiesArr[i].length);
  }
  return false;
}

OMAIL.readField = function (field, doc)
{
  var v;
  if (!doc) {doc = document;}
  if (doc.forms[0])
  {
    v = doc.forms[0].elements[field];
    if (v)
    {
      v = v.value;
    }
  }
  return v;
}

OMAIL.createParam = function (field, doc)
{
  var S = '';
  var v = OMAIL.readField(field, doc);
  if (v)
    S = '&'+field+'='+ encodeURIComponent(v);
  return S;
}

OMAIL.sessionParams = function (doc)
{
  return OMAIL.createParam('sid', doc)+OMAIL.createParam('realm', doc);
}

OMAIL.initState = function (state)
{
  if (!state)
    var state = new Object();

  state.sid = OMAIL.readField('sid');
  state.realm = OMAIL.readField('realm');

  return state;
}

OMAIL.saveState = function ()
{
  OMAIL.writeCookie('OMAIL_State', escape(OAT.JSON.stringify(OMAIL.state)), 1);
}

OMAIL.init = function ()
{
  // load cookie data
  var s = OMAIL.readCookie('OMAIL_State');
  if (s)
  {
    try {
      s = OAT.JSON.parse(unescape(s));
    } catch (e) { s = null; }
    s = OMAIL.initState(s);
  } else {
    s = OMAIL.initState();
  }
  OMAIL.state = s;
}

OMAIL.initFilter = function ()
{
  // load filters data
  var x = function(data) {
    var o = OAT.JSON.parse(data);
    OMAIL.searchPredicates = o[0];
    OMAIL.searchCompares = o[1];
    OMAIL.searchActions = o[2];
    OMAIL.searchFolders = o[3];
  }
  OAT.AJAX.GET('action.vsp?a=search&sa=metas'+OMAIL.sessionParams(), '', x, {async:false});
}

OMAIL.formParams = function (doc)
{
  if (!doc) {doc = document;}
  var S = '';
  var o = doc.forms[0].elements;
  for (var i = 0; i < o.length; i++)
  {
    if (o[i])
    {
      if ((o[i].type == "checkbox" && o[i].checked) || (o[i].type != "checkbox"))
      {
        var n = o[i].name;
        if ((n != '') && (n.indexOf('page_') != 0) && (n.indexOf('__') != 0))
        {
          S += '&' + n + '=' + encodeURIComponent(o[i].value);
        }
      }
    }
  }
  return S;
}

OMAIL.searchGetPredicate = function (No)
      {
  var fld = $('search_fld_1_' + No)
  if (fld) {
    for (var i = 0; i < OMAIL.searchPredicates.length; i += 2) {
      if (OMAIL.searchPredicates[i] == fld.value)
        return OMAIL.searchPredicates[i+1];
      }
    }
  return null;
}

OMAIL.actionGetPredicate = function (No)
{
  var fld = $('action_fld_1_' + No)
  if (fld)
  {
    for (var i = 0; i < OMAIL.searchActions.length; i = i + 2)
    {
      if (OMAIL.searchActions[i] == fld.value)
      {
        return OMAIL.searchActions[i+1];
      }
    }
  }
  return null;
}

OMAIL.aboutDialog = function ()
{
  var aboutDiv = $('aboutDiv');
  if (aboutDiv) {OAT.Dom.unlink(aboutDiv);}
  aboutDiv = OAT.Dom.create('div', {
    width:'430px',
    height: '170px',
    overflow: 'hidden'
  });
  aboutDiv.id = 'aboutDiv';
  aboutDialog = new OAT.Dialog('About ODS Webmail', aboutDiv, {width:445, buttons: 0, resize:0, modal:1});
	aboutDialog.cancel = aboutDialog.hide;

  var x = function (txt) {
    if (txt != "")
    {
      var aboutDiv = $("aboutDiv");
      if (aboutDiv)
      {
        aboutDiv.innerHTML = txt;
        aboutDialog.show ();
      }
    }
  }
  OAT.AJAX.GET('action.vsp?a=about'+OMAIL.sessionParams(), '', x, {type:OAT.AJAX.TYPE_TEXT, onstart:function(){}, onerror:function(){}});
}
