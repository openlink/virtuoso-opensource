/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2006 OpenLink Software
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
// ---------------------------------------------------------------------------
function AddAdr(obj,addr)
{
	fld = eval('document.f1.'+ obj.name);
	if (obj.checked == true) {
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

// ---------------------------------------------------------------------------
function ClearFld(obj,fvalue)
{
	if (obj.value.indexOf(fvalue) != -1)
		obj.value = '';
}

// ---------------------------------------------------------------------------
showRow = (navigator.appName.indexOf("Internet Explorer") != -1) ? "block" : "table-row";

// ---------------------------------------------------------------------------
function getParent (obj, tag)
{
  var obj = obj.parentNode;
  if (obj.tagName.toLowerCase() == tag)
    return obj;
  return getParent(obj, tag);
}

// ---------------------------------------------------------------------------
function selectCheck (obj, prefix)
{
  coloriseRow(getParent(obj, 'tr'), obj.checked);
}

// ---------------------------------------------------------------------------
function toggleTab(obj, noValue)
{
  if (obj.checked == true)
  {
    document.getElementById('plain').style.display = 'none';
    document.getElementById('rte').style.display = 'block';
    initEditor('rteMessage');
  } else {
    document.getElementById('plain').style.display = 'block';
    document.getElementById('rte').style.display = 'none';
  }
  if (noValue == null)
    toggleValue(obj);
}

// ---------------------------------------------------------------------------
function initTab(obj)
{
  initValue(obj);
  toggleTab(obj, true);
  returnValue(obj);
}

// ---------------------------------------------------------------------------
function toggleValue(obj)
{
  if (obj.checked == true)
  {
    var value = document.forms['f1'].elements['plainMessage'].value;
    enableDesignMode('rteMessage', text2rte(value), true);
  } else {
    updateRTE('rteMessage');
    var value = document.forms['f1'].elements['rteMessage'].value;
    document.forms['f1'].elements['plainMessage'].value = rte2text(value);
  }
}

// ---------------------------------------------------------------------------
function initValue (obj)
{
  var value = document.forms['f1'].elements['message'].value;
  if (obj.checked == true)
  {
    enableDesignMode('rteMessage', initRte(value), false);
  } else {
    document.forms['f1'].elements['plainMessage'].value = value;
  }
}

// ---------------------------------------------------------------------------
function returnValue(obj)
{
  var value;
  if (obj.checked == true)
  {
    updateRTE('rteMessage');
    value = clearRte(document.forms['f1'].elements['rteMessage'].value);
  } else {
    value = document.forms['f1'].elements['plainMessage'].value;
  }
  document.forms['f1'].elements['message'].value = value;
}

// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
function clearRte(value) {
  var re;
  re = new RegExp('\r\n', 'gi');
  value = value.replace(re, '\n');
  re = new RegExp('\n', 'gi');
  value = value.replace(re, '');
  return value;
}

// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
function boxSubmit(value) {
  createHidden (document, 'bp', value);
  createHidden (document, 'sort.x', '1');
  document.f1.submit ();
}

// ---------------------------------------------------------------------------
function attachSubmit(value) {
  createHidden (document, 'fa_attach.x', '1');
  document.f1.submit ();
}

// ---------------------------------------------------------------------------
function formSubmit(myField, myValue)
{
  createHidden (document, myField, myValue);
  document.f1.submit ();
}

// ---------------------------------------------------------------------------
function confirmAction (confirmMsq, form, txt, selectionMsq)
{
  if (anySelected (form, txt, selectionMsq))
    return confirm (confirmMsq);
  return false;
}

// ---------------------------------------------------------------------------
function selectAllCheckboxes (obj, prefix) {
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

// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
function coloriseRow(obj, checked) {
  obj.className = (obj.className).replace('tr_select', '');
  if (checked)
    obj.className = obj.className + ' ' + 'tr_select';
}

// ---------------------------------------------------------------------------
function windowShow(sPage, width, height)
{
  if (width == null)
    width = 500;
  if (height == null)
    height = 420;
  sPage = sPage + '&return=F1&sid=' + document.forms[0].elements['sid'].value + '&realm=' + document.forms[0].elements['realm'].value;
  win = window.open(sPage, null, "width="+width+",height="+height+", top=100, left=100, scrollbars=yes, resize=yes, menubar=no");
  win.window.focus();
}

// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
function initTab2(tabs, defaultNo)
{
  var divNo = document.getElementById('tabNo');
  var tab = defaultNo;
  if (divNo != null) {
    var divTab = document.getElementById('tab_'+divNo.value);
    if (divTab != null)
      tab = divNo.value;
  }
  showTab2(tab, tabs);
}

// ---------------------------------------------------------------------------
function saveCheckbox(obj)
{
  createHidden(document, 'ch_'+obj.name, obj.checked ? '1': '');
}

// ---------------------------------------------------------------------------
function addChecked (objForm, objName, selectionMsq)
{
  if (!anySelected (objForm, objName, selectionMsq, 'confirm'))
    return;

  if (window.opener.document.f1.elements[objForm.elements["set"].value])
  {
    var destField = window.opener.document.f1.elements[objForm.elements["set"].value];

    destField.value = (destField.value).replace(';', ',');
    destField.value = WebMail.trim(destField.value);
    destField.value = WebMail.trim(destField.value, ',');
    destField.value = WebMail.trim(destField.value);
    destField.value = destField.value + ',';
    for (var i = 0; i < objForm.elements.length; i = i + 1)
    {
      var obj = objForm.elements[i];
      if (obj != null && obj.type == "checkbox" && obj.name == objName)
      {
        if (obj.checked)
        {
          if (destField.value.indexOf(obj.value+',') == -1)
            destField.value = destField.value + obj.value+',';
        } else {
          destField.value = (destField.value).replace(obj.value+',', '');
        }
      }
    }
    destField.value = WebMail.trim(destField.value, ',');
  }

  window.close();
}

// ---------------------------------------------------------------------------
function davBrowse (fld)
{
  var options = { mode: 'browser',
                  onConfirmClick: function(path, fname) {$(fld).value = path + fname;}
                };
  oWebDAV.open(options);
}

// ---------------------------------------------------------------------------
var WebMail = new Object();

// ---------------------------------------------------------------------------
WebMail.trim = function (sString, sChar)
{
  if (sChar == null)
    sChar = ' ';

  while (sString.substring(0,1) == sChar)
    sString = sString.substring(1, sString.length);

  while (sString.substring(sString.length-1, sString.length) == sChar)
    sString = sString.substring(0,sString.length-1);

  return sString;
}

// ---------------------------------------------------------------------------
WebMail.toggleCell = function (cell)
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

// ---------------------------------------------------------------------------
WebMail.enableRadioGroup = function (cell)
{
  var c = $(cell);
  var r = document.forms['f1'].elements[cell+'_radio'];
  for (var i = 0; i < r.length; i = i + 1)
  {
    r[i].disabled = !c.checked;
  }
}
