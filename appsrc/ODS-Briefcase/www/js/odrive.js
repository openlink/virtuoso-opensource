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
function myPost(frm_name, fld_name, fld_value)
{
  createHidden(frm_name, fld_name, fld_value);
  document.forms[frm_name].submit();
}

// ---------------------------------------------------------------------------
function vspxPost(fButton, fName, fValue, f2Name, f2Value, f3Name, f3Value)
{
  if (fName)
    createHidden('F1', fName, fValue);
  if (f2Name)
    createHidden('F1', f2Name, f2Value);
  if (f3Name)
    createHidden('F1', f3Name, f3Value);
  doPost('F1', fButton);
}

// ---------------------------------------------------------------------------
function toolbarPost(fld_value)
{
  document.F1.toolbar_hidden.value = fld_value;
  doPost ('F1', 'toolbar');
}

// ---------------------------------------------------------------------------
function submitEnter(e, myForm, myButton, myAction)
{
  var keycode;
  if (window.event)
  {
    keycode = window.event.keyCode;
  }
  else
  {
    if (!e)
    {
      return true;
    }
    keycode = e.which;
  }
  if (keycode == 13)
  {
    if (myButton == 'action')
    {
      vspxPost(myButton, '_cmd', myAction);
      return false;
    }
    if (myButton != '')
    {
      doPost (myForm, myButton);
      return false;
    }
      document.forms[myForm].submit();
  }
  return true;
}

// ---------------------------------------------------------------------------
function checkNotEnter(e)
{
  var key;

  if (window.event)
  {
    key = window.event.keyCode;
  } else {
    if (e)
    {
      key = e.which;
    } else {
      return true;
    }
  }
  if (key == 13)
    return false;
  return true;
}

// ---------------------------------------------------------------------------
function selectAllCheckboxes (obj, prefix, toolbarsFlag) {
  var objForm = obj.form;
  for (var i = 0; i < objForm.elements.length; i++)
  {
    var o = objForm.elements[i];
    if (o != null && o.type == "checkbox" && !o.disabled && o.name.indexOf (prefix) != -1)
    {
      o.checked = (obj.value == 'Select All');
      coloriseRow(getParent(o, 'tr'), o.checked);
  }
  }
  obj.value = (obj.value == 'Select All')? 'Unselect All': 'Select All';
  if (toolbarsFlag)
    enableToolbars(objForm, prefix);
  obj.focus();
    }

// ---------------------------------------------------------------------------
function selectCheck (obj, prefix)
{
  coloriseRow(getParent(obj, 'tr'), obj.checked);
  enableToolbars(obj.form, prefix, document);
}

// ---------------------------------------------------------------------------
function enableToolbars (objForm, prefix, doc)
{
  var oCount = 0;
  var cCount = 0;
  var rCount = 0;
  var tCount = 0;
  for (var i = 0; i < objForm.elements.length; i++)
  {
    var o = objForm.elements[i];
    if (o != null && o.type == 'checkbox' && !o.disabled && o.name.indexOf (prefix) != -1 && o.checked)
    {
      oCount++;
      if (o.value[o.value.length-1] == '/')
      {
        cCount++;
      } else {
        rCount++;
      }
    }
  }
  tCount = rCount;
  if (oCount != rCount)
    tCount = 0;
  enableElement('tb_rename', 'tb_rename_gray', oCount==1, doc);
  enableElement('tb_copy', 'tb_copy_gray', oCount>0, doc);
  enableElement('tb_move', 'tb_move_gray', oCount>0, doc);
  enableElement('tb_delete', 'tb_delete_gray', oCount>0, doc);

  enableElement('tb_tag', 'tb_tag_gray', tCount>0, doc);
  enableElement('tb_properties', 'tb_properties_gray', oCount>0, doc);
}

// ---------------------------------------------------------------------------
function getParent (o, tag)
{
  var o = o.parentNode;
  if (o.tagName.toLowerCase() == tag)
    return o;
  return getParent(o, tag);
}

// ---------------------------------------------------------------------------
function getDocument (doc)
{
  if (!doc)
  {
    if (window.frameElement)
    {
      doc = window.frameElement.contentDocument;
  }
    else
    {
      doc = document;
    }
  }
  return doc;
}

// ---------------------------------------------------------------------------
function enableElement (id, id_gray, flag, doc)
{
  doc = getDocument (doc);
  var mode = 'block';
  var o = getObject(id, doc);
  if (o)
  {
    if (flag)
    {
      o.style.display = 'block';
      mode = 'none';
    } else {
      o.style.display = 'none';
      mode = 'block';
    }
  }
  var o = getObject(id_gray, doc);
  if (o)
    o.style.display = mode;
}

// ---------------------------------------------------------------------------
function countSelected (form, txt)
{
  var count = 1;

  if ((form != null) && (txt != null))
  {
    count = 0;
    for (var i = 0; i < form.elements.length; i++)
    {
      var obj = form.elements[i];
      if ((obj != null) && (obj.type == "checkbox") && (obj.name.indexOf (txt) != -1) && obj.checked)
        count++;
    }
  }
  return count;
}

// ---------------------------------------------------------------------------
function getSelected (form, txt)
{
  var s = '';
  var n = 1;
  if ((form != null) && (txt != null))
  {
    for (var i = 0; i < form.elements.length; i++)
    {
      var obj = form.elements[i];
      if ((obj != null) && (obj.type == "checkbox") && (obj.name.indexOf (txt) != -1) && obj.checked)
      {
        s = s + '&f' + n + '=' + escape((obj.name).substr(txt.length));
        n++;
      }
    }
  }
  return s;
}

// ---------------------------------------------------------------------------
//
function anySelected (form, txt, selectionMsq, mode)
{
  if ((form != null) && (txt != null))
  {
    for (var i = 0; i < form.elements.length; i++)
    {
      var obj = form.elements[i];
      if ((obj != null) && (obj.type == "checkbox") && (obj.name.indexOf (txt) != -1) && obj.checked)
        return true;
    }
    if (selectionMsq != null)
    {
      if ((mode != null) && (mode == 'confirm'))
        return confirm(selectionMsq);
      alert(selectionMsq);
    }
    return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
//
function singleSelected (form, txt, zeroMsq, moreMsg, mode)
{
  var count = countSelected(form, txt);
  if (count == 0)
  {
    if (zeroMsq != null)
      alert(zeroMsq);
    return false;
  }
  if (count > 1)
  {
    if (moreMsg != null)
      alert(moreMsg);
    return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
function getFileName(obj)
{
  var S = obj.value;
  var N;
  if (S.lastIndexOf('\\') > 0)
    N = S.lastIndexOf('\\') + 1;
  else
    N = S.lastIndexOf('/') + 1;
  S = S.substr(N, S.length);
  if (S.indexOf('?') > 0)
  {
    N = S.indexOf('?');
    S = S.substr(0, N);
  }
  if (S.indexOf('#') > 0)
  {
    N = S.indexOf('#');
    S = S.substr(0, N);
  }
  if (document.F1.dav_destination[1].checked == '1')
  {
    N = S.indexOf('.rdf');
    S = S.substr(0, N);
  }
  if ((document.F1.dav_destination[0].checked == '1') && (document.F1.dav_source[2].checked == '1'))
  {
    N = S.indexOf('.rdf');
    if (N == -1)
      S = S + '.rdf';
  }
  document.F1.dav_name.value = S;
}

// ---------------------------------------------------------------------------
function chkbx(bx1, bx2)
{
  if (bx1.checked == true && bx2.checked == true)
    bx2.checked = false;
}

// ---------------------------------------------------------------------------
function updateLabel(value)
{
  hideLabel(4, 10);
  if (value == 'oMail')
    showLabel(4, 4);
  if (value == 'PropFilter')
    showLabel(5, 5);
  if (value == 'HostFs')
    showLabel(6, 6);
  if (value == 'ResFilter')
    showLabel(7, 7);
  if (value == 'CatFilter')
    showLabel(7, 7);
  if (value == 'rdfSink')
    showLabel(8, 8);
}

// ---------------------------------------------------------------------------
function showLabel(from, to)
{
  for (var i = from; i <= to; i++)
  {
    var div = document.getElementById('tab_'+i);
    if (div != null)
    {
      div.style.visibility = 'visible';
      div.style.display = 'inline';
    }
  }
}

// ---------------------------------------------------------------------------
function hideLabel(from, to)
{
  for (var i = from; i <= to; i++)
  {
    var div = document.getElementById('tab_'+i);
    if (div != null)
    {
      div.style.visibility = 'hidden';
      div.style.display = 'none';
    }
  }
}

// ---------------------------------------------------------------------------
function showTab(tab, tabs)
{
  for (var i = 1; i <= tabs; i++)
  {
    var div = document.getElementById(i);
    if (div != null)
    {
      var divTab = document.getElementById('tab_'+i);
      if (i == tab)
      {
        var divNo = document.getElementById('tabNo');
        divNo.value = tab;
        OAT.Dom.show(div);
        if (divTab)
        {
          OAT.Dom.addClass(divTab, "activeTab");
          divTab.blur();
        }
      } else {
        OAT.Dom.hide(div);
        if (divTab)
        {
          OAT.Dom.removeClass(divTab, "activeTab");
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
function initTab(tabs, defaultNo)
{
  var divNo = document.getElementById('tabNo');
  var tab = defaultNo;
  if (divNo != null)
  {
    var divTab = document.getElementById('tab_'+divNo.value);
    if (divTab != null)
      tab = divNo.value;
  }
  showTab(tab, tabs);
}

// ---------------------------------------------------------------------------
//
function uncheck(checkBox)
{
  document.F1.elements[checkBox].checked = false;
}

// ---------------------------------------------------------------------------
//
function initDisabled()
{
  var formRight = document.F1.elements['formRight'];
  if (!formRight) {return;}
  formRight = formRight.value;
  if (formRight != '1') {return;}

  var objects = document.F1.elements;
  for (var i = 0; i < objects.length; i++)
{
    var obj = objects[i];
    if (obj.disabled && !OAT.Dom.isClass(obj, "disabled"))
    {
      obj.disabled = false;
    }
}
}


// ---------------------------------------------------------------------------
//
function deleteConfirm()
{
  return confirm('Are you sure you want to delete the chosen record?');
}

// ---------------------------------------------------------------------------
//
function deprecateConfirm()
{
  return confirm('Are you sure you want to deprecate the chosen record?');
}

// ---------------------------------------------------------------------------
function confirmAction(confirmMsq, form, txt, selectionMsq) {
  if (anySelected (form, txt, selectionMsq))
    return confirm(confirmMsq);
  return false;
}

// ---------------------------------------------------------------------------
//
function windowShow(sPage, width, height)
{
  if (width == null)
    width = 500;
  if (height == null)
    height = 420;
  sPage = sPage + '&sid=' + document.forms[0].elements['sid'].value + '&realm=' + document.forms[0].elements['realm'].value;
  win = window.open(sPage, null, "width="+width+",height="+height+",top=100,left=100,status=yes,toolbar=no,menubar=no,scrollbars=yes,resizable=yes");
  win.window.focus();
}

// ---------------------------------------------------------------------------
function renameShow(myForm, myPrefix, myPage, width, height)
{
  var myFiles = getSelected (myForm, myPrefix);
  if (myFiles != '')
    windowShow(myPage + myFiles, width, height);
}

// ---------------------------------------------------------------------------
function mailShow(myForm, myPrefix, myPage, width, height)
{
  var myFiles = getSelected (myForm, myPrefix);
  if (myFiles != '') {
    var myBody = 'Sending files:\n';
    for (var i = 0; i < myForm.elements.length; i++) {
      var obj = myForm.elements[i];
      if ((obj != null) && (obj.type == "checkbox") && (obj.name.indexOf (myPrefix) != -1) && obj.checked)
        myBody = myBody + (obj.name).substr(myPrefix.length) + '\n';
    }
    windowShow(myPage + myFiles + '&fa_dav.x=DAV&message=' + escape(myBody), width, height);
  }
}

// ---------------------------------------------------------------------------
function coloriseRow(obj, checked) {
  obj.className = (obj.className).replace('tr_select', '');
  if (checked)
    obj.className = obj.className + ' ' + 'tr_select';
}

// ---------------------------------------------------------------------------
function coloriseTable(id)
{
  var table = $(id);
  if (table)
  {
      var rows = table.getElementsByTagName("tr");
    for (i = 0; i < rows.length; i++)
    {
      if (rows[i].className != "nocolor")
      {
        rows[i].className = "tr_" + (i % 2);
      }
    }
  }
}

// ---------------------------------------------------------------------------
function rowSelect(obj)
{
  var submitMode = false;
  if (window.document.F1.elements['src'])
    if (window.document.F1.elements['src'].value.indexOf('s') != -1)
      submitMode = true;
  if (submitMode)
    if (window.opener.document.F1)
      if (window.opener.document.F1.elements['submitting'])
        return false;
  var closeMode = true;
  if (window.document.F1.elements['dst'])
    if (window.document.F1.elements['dst'].value.indexOf('c') == -1)
      closeMode = false;
  var singleMode = true;
  if (window.document.F1.elements['dst'])
    if (window.document.F1.elements['dst'].value.indexOf('s') == -1)
      singleMode = false;

  var s2 = (obj.name).replace('b1', 's2');
  var s1 = (obj.name).replace('b1', 's1');

  var myRe = /^(\w+):(\w+);(.*)?/;
  var params = window.document.forms['F1'].elements['params'].value;
  var myArray;
  while(true) {
    myArray = myRe.exec(params);
    if (myArray == undefined)
      break;
    if (myArray.length > 2)
      if (window.opener.document.F1)
        if (window.opener.document.F1.elements[myArray[1]]) {
          if (myArray[2] == 's1')
            if (window.opener.document.F1.elements[myArray[1]])
              rowSelectValue(window.opener.document.F1.elements[myArray[1]], window.document.F1.elements[s1], singleMode, submitMode);
          if (myArray[2] == 's2')
            if (window.opener.document.F1.elements[myArray[1]])
              rowSelectValue(window.opener.document.F1.elements[myArray[1]], window.document.F1.elements[s2], singleMode, submitMode);
        }
    if (myArray.length < 4)
      break;
    params = '' + myArray[3];
  }
  if (submitMode) {
    window.opener.createHidden('F1', 'submitting', 'yes');
    window.opener.document.F1.submit();
  }
  if (closeMode)
    window.close();
}

// ---------------------------------------------------------------------------
//
function rowSelectValue(dstField, srcField, singleMode, submitMode)
{
  if (singleMode)
  {
    dstField.value = ODRIVE.trim(srcField.value, ',');
  } else {
    if (dstField.value == '')
    {
      dstField.value = srcField.value;
    } else {
      srcField.value = ODRIVE.trim(srcField.value , ',');
      var aSrc = srcField.value.split(',');

      dstField.value = dstField.value + ',';
      for (var i = 0; i < aSrc.length; i = i + 1)
      {
        if (aSrc[i] != '')
          if (dstField.value.indexOf(aSrc[i]+',') == -1)
            dstField.value = dstField.value + ODRIVE.trim(aSrc[i], ',') + ',';
      }
    }
    dstField.value = ODRIVE.trim(dstField.value, ',');
  }
}

// ---------------------------------------------------------------------------
//
function updateChecked(form, objName)
{
  for (var i = 0; i < form.elements.length; i = i + 1)
  {
    var obj = form.elements[i];
    if (obj != null && obj.type == "checkbox" && obj.name == objName)
    {
      if (obj.checked)
      {
        if (form.s1.value.indexOf(obj.value+',') == -1)
          form.s1.value = form.s1.value + obj.value+',';
      } else {
        form.s1.value = (form.s1.value).replace(obj.value+',', '');
      }
    }
  }
}

// ---------------------------------------------------------------------------
//
function addChecked (form, txt, selectionMsq)
{
  if (!anySelected (form, txt, selectionMsq, 'confirm'))
    return;

  var submitMode = false;
  if (window.document.F1.elements['src'])
    if (window.document.F1.elements['src'].value.indexOf('s') != -1)
      submitMode = true;
  if (submitMode)
    if (window.opener.document.F1)
      if (window.opener.document.F1.elements['submitting'])
        return false;
  var singleMode = true;
  if (window.document.F1.elements['dst'])
    if (window.document.F1.elements['dst'].value.indexOf('s') == -1)
      singleMode = false;

  var s1 = 's1';
  var s2 = 's2';

  var myRe = /^(\w+):(\w+);(.*)?/;
  var params = window.document.forms['F1'].elements['params'].value;
  var myArray;
  while(true)
  {
    myArray = myRe.exec(params);
    if (myArray == undefined)
      break;
    if (myArray.length > 2)
      if (window.opener.document.F1)
        if (window.opener.document.F1.elements[myArray[1]])
        {
          if (myArray[2] == 's1')
            if (window.opener.document.F1.elements[myArray[1]])
              rowSelectValue(window.opener.document.F1.elements[myArray[1]], window.document.F1.elements[s1], singleMode, submitMode);
          if (myArray[2] == 's2')
            if (window.opener.document.F1.elements[myArray[1]])
              rowSelectValue(window.opener.document.F1.elements[myArray[1]], window.document.F1.elements[s2], singleMode, submitMode);
        }
    if (myArray.length < 4)
      break;
    params = '' + myArray[3];
  }
  if (submitMode)
    window.opener.document.F1.submit();
  window.close();
}

// ---------------------------------------------------------------------------
function createHidden(frm_name, fld_name, fld_value)
{
  var hidden;

  if (document.forms[frm_name])
  {
    hidden = document.forms[frm_name].elements[fld_name];
    if (hidden == null)
    {
      hidden = document.createElement("input");
      hidden.setAttribute("type", "hidden");
      hidden.setAttribute("name", fld_name);
      hidden.setAttribute("id", fld_name);
      document.forms[frm_name].appendChild(hidden);
    }
    hidden.value = fld_value;
  }
}

// ---------------------------------------------------------------------------
function getObject(id, doc)
{
  if (!doc) {doc = document;}
  return doc.getElementById(id);
}

// ---------------------------------------------------------------------------
showRow = (navigator.appName.indexOf("Internet Explorer") != -1) ? "block" : "table-row";

// ---------------------------------------------------------------------------
function showTableRow(cell)
{
  var c = getObject(cell);
  if ((c) && (c.style.display == "none"))
    c.style.display = showRow;
}

// ---------------------------------------------------------------------------
function showCell(cell)
{
  var c = getObject(cell);
  if ((c) && (c.style.display == "none"))
    c.style.display = "";
}

// ---------------------------------------------------------------------------
function hideCell(cell)
{
  var c = getObject(cell);
  if ((c) && (c.style.display != "none"))
    c.style.display = "none";
}

// ---------------------------------------------------------------------------
function toggleDavRows()
{
  if (document.forms['F1'].elements['dav_destination'])
  {
    if (document.forms['F1'].elements['dav_destination'][0].checked == '1')
    {
      showTableRow('davRow_mime');
      showTableRow('davRow_version');
      showTableRow('davRow_owner');
      showTableRow('davRow_group');
      showTableRow('davRow_perms');
      showTableRow('davRow_text');
      showTableRow('davRow_metadata');
      showTableRow('davRow_tagsPublic');
      showTableRow('davRow_tagsPrivate');

      showTableRow('rdf_store');

      showCell('label_dav');
      hideCell('label_dav_rdf');
      showCell('dav_name');
      hideCell('dav_name_rdf');
    }
    if (document.forms['F1'].elements['dav_destination'][1].checked == '1')
    {
      hideCell('davRow_tagsPrivate');
      hideCell('davRow_tagsPublic');
      hideCell('davRow_metadata');
      hideCell('davRow_text');
      hideCell('davRow_perms');
      hideCell('davRow_group');
      hideCell('davRow_owner');
      hideCell('davRow_version');
      hideCell('davRow_mime');

      hideCell('rdf_store');
      if (document.forms['F1'].elements['dav_source'][2].checked == '1')
        document.forms['F1'].elements['dav_source'][0].checked = '1';

      hideCell('label_dav');
      showCell('label_dav_rdf');
      hideCell('dav_name');
      showCell('dav_name_rdf');
    }
  }
}

// ---------------------------------------------------------------------------
var ODRIVE = new Object();

ODRIVE.forms = new Object();
ODRIVE.forms['properties'] = {params: {items: true}, width: '900', height: '700', postActions:['ODRIVE.formSubmit()', 'ODRIVE.resetToolbars()']};
ODRIVE.forms['edit'] = {params: {items: true}, height: '430'};
ODRIVE.forms['copy'] = {params: {items: true}, height: '380', postActions:['ODRIVE.formSubmit()', 'ODRIVE.resetToolbars()']};
ODRIVE.forms['move'] = {params: {items: true}, height: '380', postActions:['ODRIVE.formSubmit()', 'ODRIVE.resetToolbars()']};
ODRIVE.forms['tags'] = {params: {items: true}, height: '360', postActions:['ODRIVE.formSubmit()', 'ODRIVE.resetToolbars()']};
ODRIVE.forms['rename'] = {params: {items: true}, height: '150', postActions:['ODRIVE.formSubmit()', 'ODRIVE.resetToolbars()']};
ODRIVE.forms['delete'] = {params: {items: true}, height: '300', postActions:['ODRIVE.formSubmit()', 'ODRIVE.resetToolbars()']};

ODRIVE.trim = function (sString, sChar)
{

  if (sString)
  {
    if (sChar == null)
    {
      sChar = ' ';
    }
    while (sString.substring(0,1) == sChar)
    {
      sString = sString.substring(1, sString.length);
    }
    while (sString.substring(sString.length-1, sString.length) == sChar)
    {
      sString = sString.substring(0,sString.length-1);
    }
  }
  return sString;
}

ODRIVE.writeCookie = function (name, value, hours)
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

ODRIVE.readCookie = function (name)
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

ODRIVE.readField = function (field, doc)
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

ODRIVE.createParam = function (field, doc)
{
  var S = '';
  var v = ODRIVE.readField(field, doc);
  if (v)
    S = '&'+field+'='+ encodeURIComponent(v);
  return S;
}

ODRIVE.sessionParams = function (doc)
{
  return ODRIVE.createParam('sid', doc)+ODRIVE.createParam('realm', doc);
}

ODRIVE.initState = function (state)
{
  if (!state)
    var state = new Object();

  state.sid = ODRIVE.readField('sid');
  state.realm = ODRIVE.readField('realm');

  return state;
}

ODRIVE.saveState = function ()
{
  ODRIVE.writeCookie('ODRIVE_State', escape(OAT.JSON.stringify(ODRIVE.state)), 1);
}

ODRIVE.init = function ()
{
  // load cookie data
  var s = ODRIVE.readCookie('ODRIVE_State');
  if (s)
  {
    try {
      s = OAT.JSON.parse(unescape(s));
    } catch (e) { s = null; }
    s = ODRIVE.initState(s);
  } else {
    s = ODRIVE.initState();
  }
  ODRIVE.state = s;

  ODRIVE.coloriseTables();
}

ODRIVE.initFilter = function ()
{
  if (ODRIVE.searchPredicates) {return;}
  var x = function(data) {
    var o = OAT.JSON.parse(data);
    ODRIVE.searchPredicates = o[0];
    ODRIVE.searchCompares = o[1];
  }
  OAT.AJAX.GET('ajax.vsp?a=search&sa=metas', '', x, {async:false});
}

ODRIVE.formParams = function (doc)
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

ODRIVE.resetToolbars = function ()
{
  enableElement('tb_rename', 'tb_rename_gray', 0);
  enableElement('tb_copy', 'tb_copy_gray', 0);
  enableElement('tb_move', 'tb_move_gray', 0);
  enableElement('tb_delete', 'tb_delete_gray', 0);

  enableElement('tb_tag', 'tb_tag_gray', 0);
  enableElement('tb_properties', 'tb_properties_gray', 0);
}

ODRIVE.formShow = function (action, id, params)
{
  var formParams = action.split('/')[0].toLowerCase();
  var form = ODRIVE.forms[formParams];
  if (form)
  {
    var dx = form.width;
    if (!dx) {dx = '800';}
    var dy  = form.height;
    if (!dy) {dy = '200';}

    var formDiv = $('formDiv');
    if (formDiv) {OAT.Dom.unlink(formDiv);}
    formDiv = OAT.Dom.create('div', {width:dx+'px', height:dy+'px'});
    formDiv.id = 'formDiv';
    formDialog = new OAT.Dialog('', formDiv, {width:parseInt(dx)+20, buttons: 0, resize: 0, modal: 1, onhide: function(){return false;}});
    formDialog.cancel = formDialog.hide;

    var s = 'forms.vspx?sa='+encodeURIComponent(action)+ODRIVE.sessionParams();
    if (id) {s += '&id='+encodeURIComponent(id);}
    if (params) {s += params;}
    if (form.params)
    {
      if (form.params.items)
      {
        // var o = getObject('items_iframe');
        // if (o) {s += ODRIVE.formParams(o.contentDocument);}
        s += ODRIVE.formParams(document);
      }
    }
    s += '&__x='+Math.random();
    formDiv.innerHTML = '<iframe id="forms_iframe" src="'+s+'" width="100%" height="100%" frameborder="0" scrolling="auto" hspace="0" vspace="0" marginwidth="0" marginheight="0"></iframe>';

    formDialog.show ();
  }
}

ODRIVE.formSubmit = function ()
{
  document.F1.submit();
}

ODRIVE.formClose = function (action)
{
  if (action)
  {
    parent.ODRIVE.formPostAfter(action);
  }
  parent.formDialog.hide ();
}

ODRIVE.formPost = function (action, mode)
{
  var win = (mode != 'top') ? parent: window;
  var x = function(data) {
    var o = OAT.JSON.parse(data);
    if ((o != '') && (action != 'export'))
    {
      alert(o);
      return;
    }
    win.ODRIVE.formPostAfter(action);
  }
  var formParams = action.split('/')[0].toLowerCase();
  var form = win.ODRIVE.forms[formParams];
  var s = 'ajax.vsp?a=form&sa='+encodeURIComponent(action)+ODRIVE.formParams();
  if (form.params)
  {
    if (form.params.items)
    {
      // var o = getObject('items_iframe', win.document);
      s += ODRIVE.formParams(win.document);
    }
  }
  OAT.AJAX.GET(s, '', x);
}

ODRIVE.formPostAfter = function (action)
{
  var formParams = action.split('/')[0].toLowerCase();
  var form = ODRIVE.forms[formParams];
  if (form)
  {
    var actions = form.postActions;
    if (actions)
    {
      for (var i = 0; i < actions.length; i++)
      {
        eval(actions[i]);
      }
    }
  }
}

ODRIVE.propertyCombo = function (propertyNo, propertyValue)
{
  var cl = new OAT.Combolist([], propertyValue);
  cl.input.name = "c_property_"+propertyNo;
  cl.input.id = "c_property_"+propertyNo;
  cl.input.style.width = "90%";
  $("c_td_"+propertyNo).appendChild(cl.div);
  ODRIVE.propertyAddOptions(cl);
}

ODRIVE.propertyUpdate = function (claimNo)
{
  if (claimNo == 'xxx')
  {
    if (($v('c_property_xxx') == '') || ($v('c_value_xxx') == ''))
    {
      alert ('The property and value filelds can not be empty|');
    }
    else
    {
      var tr = $('c_tr_xxx');
      if (tr)
      {
        var seqNo = parseInt($v('c_seqNo'));

        var tr_add = OAT.Dom.create('tr');
        tr_add.id = 'c_tr_'+seqNo;

        var S = tr.innerHTML;
        S = S.replace(/xxx/g, ''+seqNo);
        S = S.replace(/add_16/g, 'del_16');
        S = S.replace(/Add/g, 'Delete');

        var tr_parent = $('c_tr').parentNode;
        tr_parent.insertBefore(tr_add, $('c_tr'));
        tr_add.innerHTML = S;

        var cl = new OAT.Combolist([], '');
        cl.input.name = 'c_property_'+seqNo;
        cl.input.id = 'c_property_'+seqNo;
        cl.input.style.width = "90%";
        var td = $('c_td_'+seqNo);
        td.innerHTML = '';
        td.appendChild(cl.div);
        ODRIVE.propertyAddOptions(cl);

        $('c_property_'+seqNo).value = $v('c_property_xxx');
        $('c_value_'+seqNo).value = $v('c_value_xxx');
        if ($('c_action_xxx'))
          $('c_action_'+seqNo).value = $v('c_action_xxx');

        $('c_seqNo').value = seqNo + 1;
        $('c_property_xxx').value = '';
        $('c_value_xxx').value = '';
        if ($('c_action_xxx'))
          $('c_action_xxx').value = '';
      }
    }
  }
  else
  {
    OAT.Dom.unlink('c_tr_'+claimNo);
  }
}

ODRIVE.propertyAddOptions = function (cl)
{
  cl.addOption('xml-sql');
  cl.addOption('xml-sql-root');
  cl.addOption('xml-sql-dtd');
  cl.addOption('xml-sql-schema');
  cl.addOption('xml-sql-description');
  cl.addOption('xml-sql-encoding');
  cl.addOption('xml-stylesheet');
  cl.addOption('xml-template');
  cl.addOption('xper');
}

ODRIVE.aclUpdate = function (claimNo)
{
  if (claimNo == 'xxx')
  {
    if ($v('acl_user_xxx') == '')
    {
      alert ('The users/groups filelds can not be empty|');
    }
    else
    {
      var tr = $('acl_tr_xxx');
      if (tr)
      {
        var seqNo = parseInt($v('acl_seqNo'));

        var tr_add = OAT.Dom.create('tr');
        tr_add.id = 'acl_tr_'+seqNo;

        var S = tr.innerHTML;
        S = S.replace(/xxx/g, ''+seqNo);
        S = S.replace(/add_16/g, 'del_16');
        S = S.replace(/Add/g, 'Delete');

        var tr_parent = $('acl_tr').parentNode;
        tr_parent.insertBefore(tr_add, $('acl_tr'));
        tr_add.innerHTML = S;

        $('acl_user_'+seqNo).value = $v('acl_user_xxx');
        $('acl_inheritance_'+seqNo).selectedIndex = $('acl_inheritance_xxx').selectedIndex;
        $('acl_r_grant_'+seqNo).checked = $('acl_r_grant_xxx').checked;
        $('acl_w_grant_'+seqNo).checked = $('acl_w_grant_xxx').checked;
        $('acl_x_grant_'+seqNo).checked = $('acl_x_grant_xxx').checked;
        $('acl_r_deny_'+seqNo).checked = $('acl_r_deny_xxx').checked;
        $('acl_w_deny_'+seqNo).checked = $('acl_w_deny_xxx').checked;
        $('acl_x_deny_'+seqNo).checked = $('acl_x_deny_xxx').checked;

        $('acl_user_xxx').value = '';
        $('acl_inheritance_xxx').selectedIndex = 0;
        $('acl_r_grant_xxx').checked = true;
        $('acl_w_grant_xxx').checked = true;
        $('acl_x_grant_xxx').checked = false;
        $('acl_r_deny_xxx').checked = false;
        $('acl_w_deny_xxx').checked = false;
        $('acl_x_deny_xxx').checked = false;
        $('acl_seqNo').value = seqNo + 1;
      }
    }
  }
  else
  {
    OAT.Dom.unlink('acl_tr_'+claimNo);
  }
}

ODRIVE.searchRowAction = function (rowID)
{
  var tbody = $('search_tbody');
  if (tbody)
  {
    var seqNo = parseInt($v('search_seqNo'));
    if (seqNo == rowID)
    {
      var span = $('search_span_5_' + seqNo);
      if (span)
      {
        var S = span.innerHTML;
        S = S.replace(/add_16/g, 'del_16');
        S = S.replace(/Add/g, 'Delete');
        span.innerHTML = S;
      }
      OAT.Dom.unlink('search_tr');
      var tr = OAT.Dom.create('tr');
      tr.id = 'search_tr';
      var td = OAT.Dom.create('td');
      td.colSpan = '6';
      td.appendChild(OAT.Dom.create('hr'));
      tr.appendChild(td);
      tbody.appendChild(tr);

      seqNo++;
      $('search_seqNo').value = seqNo;
      ODRIVE.searchRowCreate(seqNo);
    }
    else
    {
      OAT.Dom.unlink('search_tr_'+rowID);
      ODRIVE.searchColumnHide(1);
      ODRIVE.searchColumnHide(2);
    }
  }
}

ODRIVE.searchRowCreate = function (rowID, values)
{
  var tbody = $('search_tbody');
  if (tbody)
  {
    var seqNo = parseInt($v('search_seqNo'));
    var tr = OAT.Dom.create('tr');
    tr.id = 'search_tr_' + rowID;
    if (seqNo != rowID)
    {
      tr_line = $('search_tr');
      tbody.insertBefore(tr, tr_line);
    }
    else
    {
      tbody.appendChild(tr);
    }
    if (!values)
      values = new Object();

    var td = OAT.Dom.create('td');
    td.id = 'search_td_0_' + rowID;
    tr.appendChild(td);
    ODRIVE.searchColumnCreate(rowID, 0, values['field_0']);

    var td = OAT.Dom.create('td');
    td.id = 'search_td_1_' + rowID;
    if (ODRIVE.searchColumnHideCheck(1))
    {
      td.style.display = 'none';
    }
    tr.appendChild(td);
    if (values['field_1'])
      ODRIVE.searchColumnCreate(rowID, 1, values['field_1']);

    var td = OAT.Dom.create('td');
    td.id = 'search_td_2_' + rowID;
    if (ODRIVE.searchColumnHideCheck(2))
    {
      td.style.display = 'none';
    }
    tr.appendChild(td);
    if (values['field_2'])
      ODRIVE.searchColumnCreate(rowID, 2, values['field_2']);

    var td = OAT.Dom.create('td');
    td.id = 'search_td_3_' + rowID;
    tr.appendChild(td);
    if (values['field_3'])
      ODRIVE.searchColumnCreate(rowID, 3, values['field_3']);

    var td = OAT.Dom.create('td');
    td.id = 'search_td_4_' + rowID;
    tr.appendChild(td);
    if (values['field_4'])
      ODRIVE.searchColumnCreate(rowID, 4, values['field_4']);

    var td = OAT.Dom.create('td');
    td.id = 'search_td_5_' + rowID;
    td.style['whiteSpace'] = 'nowrap';
    var span = OAT.Dom.create('span');
    span.id = 'search_span_5_' + rowID;
    span.onclick = function (){ODRIVE.searchRowAction(rowID)};
    OAT.Dom.addClass(span, 'button3');
    OAT.Dom.addClass(span, 'pointer');
    var imgSrc = (seqNo != rowID)? 'image/del_16.png': 'image/add_16.png';
    var img = OAT.Dom.image(imgSrc);
    img.id = 'search_img_5_' + rowID;
    span.appendChild(img);
    span.appendChild((seqNo != rowID)? OAT.Dom.text(' Delete'): OAT.Dom.text(' Add'));
    td.appendChild(span);
    tr.appendChild(td);
    if (values['field_5'])
      ODRIVE.searchColumnCreate(rowID, 5, values['field_5']);
  }
}

ODRIVE.searchColumnsInit = function (rowID, columnNo)
{
  var tr = $('search_tr_' + rowID);
  if (tr)
  {
    var tds = tr.getElementsByTagName("td");
    for (var i = columnNo; i < tds.length-1; i++)
    {
      tds[i].innerHTML = '';
    }
    if (columnNo == 0)
    {
      ODRIVE.searchColumnCreate(rowID, columnNo)
    }
    if (columnNo <= 1)
      ODRIVE.searchColumnHide(1)
    if (columnNo <= 2)
      ODRIVE.searchColumnHide(2)
  }
}

ODRIVE.searchColumnCreate = function (rowID, columnNo, columnValue)
{
  var tr = $('search_tr_' + rowID);
  if (tr)
  {
    var td = $('search_td_' + columnNo + '_' + rowID);
    if (td)
    {
      var predicate = ODRIVE.searchGetPredicate(rowID);
      if (columnNo == 0)
      {
        var field = OAT.Dom.create('select');
        field.id = 'search_field_' + columnNo + '_' + rowID;
        field.name = field.id;
        field.style.width = '95%';
        OAT.Dom.option('', '', field);
        for (var i = 0; i < ODRIVE.searchPredicates.length; i = i + 2)
        {
          if (ODRIVE.searchPredicates[i+1][0] == 1)
          {
            OAT.Dom.option(ODRIVE.searchPredicates[i+1][1], ODRIVE.searchPredicates[i], field);
          }
        }
        if (columnValue)
          field.value = columnValue;
        field.onchange = function(){ODRIVE.searchColumnChange(this)};
        td.appendChild(field);
      }
      if (columnNo == 1)
      {
        if (predicate && (predicate[2] == 'rdfSchema'))
        {
          var field = OAT.Dom.create('select');
          field.id = 'search_field_' + columnNo + '_' + rowID;
          field.name = field.id;
          field.style.width = '95%';
          OAT.Dom.option('', '', field);
          td.appendChild(field);

          var x = function(data) {
            var o = OAT.JSON.parse(data);
            for (var i = 0; i < o.length; i = i + 2)
            {
              OAT.Dom.option(o[i+1], o[i], field);
            }
            if (columnValue)
              field.value = columnValue;
            field.onchange = function(){ODRIVE.searchColumnChange(this)};
          }
          var s = 'ajax.vsp?a=search&sa=schemas';
          OAT.AJAX.GET(s, '', x);
          ODRIVE.searchColumnShow(1);
        }
      }
      if (columnNo == 2)
      {
        if (predicate && (predicate[3] == 'davProperties'))
        {
          var cl = new OAT.Combolist([], '');
          cl.input.id = 'search_field_' + columnNo + '_' + rowID;;
          cl.input.name = cl.input.id;
          cl.input.style.width = "90%";
          if (columnValue)
            cl.input.value = columnValue;
          td.appendChild(cl.div);
          ODRIVE.propertyAddOptions(cl);
          ODRIVE.searchColumnShow(2);
        }
        if (predicate && (predicate[3] == 'rdfProperties'))
        {
          var fieldSchema = $('search_field_1_' + rowID)
          if (fieldSchema && (fieldSchema.value != ''))
          {
            var field = OAT.Dom.create('select');
            field.id = 'search_field_' + columnNo + '_' + rowID;
            field.name = field.id;
            field.style.width = '95%';
            OAT.Dom.option('', '', field);
            td.appendChild(field);

            var x = function(data) {
              var o = OAT.JSON.parse(data);
              for (var i = 0; i < o.length; i = i + 2)
              {
                OAT.Dom.option(o[i+1], o[i], field);
              }
              if (columnValue)
                field.value = columnValue;
            }
            var s = 'ajax.vsp?a=search&sa=schemaProperties&schema='+fieldSchema.value;
            OAT.AJAX.GET(s, '', x);
            ODRIVE.searchColumnShow(2);
          }
        }
      }
      if (columnNo == 3)
      {
        var field = OAT.Dom.create('select');
        field.id = 'search_field_' + columnNo + '_' + rowID;
        field.name = field.id;
        field.style.width = '95%';
        OAT.Dom.option('', '', field);
        var predicateType = predicate[4];
        for (var i = 0; i < ODRIVE.searchCompares.length; i = i + 2)
        {
          var compareTypes = ODRIVE.searchCompares[i+1][1];
          for (var j = 0; j < compareTypes.length; j++)
          {
            if (compareTypes[j] == predicateType)
            {
              OAT.Dom.option(ODRIVE.searchCompares[i+1][0], ODRIVE.searchCompares[i], field);
            }
          }
        }
        if (columnValue)
          field.value = columnValue;
        td.appendChild(field);
      }
      if (columnNo == 4)
      {
    		var properties = OAT.Dom.create("input");
    		var field = OAT.Dom.create("input");
    		field.type = 'text';
        field.id = 'search_field_' + columnNo + '_' + rowID;
        field.name = field.id;
        field.style.width = '93%';
        if (columnValue)
          field.value = columnValue;
        td.appendChild(field);
        for (var i = 0; i < predicate[5].length; i = i + 2)
        {
          if (predicate[5][i] == 'size')
          {
    		    field['size'] = predicate[5][i+1];
            field.style.width = null;
          }
          if (predicate[5][i] == 'onclick')
          {
			      OAT.Event.attach(field, "click", new Function((predicate[5][i+1]).replace(/-FIELD-/g, field.id)));
          }
          if (predicate[5][i] == 'button')
          {
    		    var span = OAT.Dom.create("span");
    		    span.innerHTML = ' ' + (predicate[5][i+1]).replace(/-FIELD-/g, field.id);
            td.appendChild(span);
          }
        }
      }
    }
  }
}

ODRIVE.searchColumnShow = function (columnNo)
{
  var seqNo = parseInt($v('search_seqNo'));
  for (var i = 0; i <= seqNo; i++)
  {
    var td = $('search_td_' + columnNo + '_' + i);
    if (td)
      OAT.Dom.show(td);
  }
  OAT.Dom.show('search_th_' + columnNo);
}

ODRIVE.searchColumnHideCheck = function (columnNo)
{
  var seqNo = parseInt($v('search_seqNo'));
  for (var i = 0; i <= seqNo; i++)
  {
    var td = $('search_td_' + columnNo + '_' + i);
    if (td && (td.innerHTML != '')) {return false;}
  }
  return true;
}

ODRIVE.searchColumnHide = function (columnNo)
{
  if (ODRIVE.searchColumnHideCheck(columnNo))
  {
    var seqNo = parseInt($v('search_seqNo'));
    for (var i = 0; i <= seqNo; i++)
    {
      var td = $('search_td_' + columnNo + '_' + i);
      if (td)
        OAT.Dom.hide(td);
    }
    OAT.Dom.hide('search_th_' + columnNo);
  }
}

ODRIVE.searchColumnChange = function (obj)
{
  var parts = obj.id.split('_');
  var columnNo = parseInt(parts[2]);
  var rowID = parts[3];
  var predicate = ODRIVE.searchGetPredicate(rowID);
  if (columnNo == 0)
  {
    ODRIVE.searchColumnsInit(rowID, 1);
    if (obj.value == '') {return;}
    if (predicate && (predicate[2]))
    {
      ODRIVE.searchColumnCreate(rowID, 1)
      return;
    }
  }
  if (columnNo == 1)
  {
    ODRIVE.searchColumnsInit(rowID, 2);
    if (obj.value == '') {return;}
  }
  if (predicate)
  {
    if (predicate[3])
    {
      ODRIVE.searchColumnCreate(rowID, 2)
    }
    ODRIVE.searchColumnCreate(rowID, 3)
    ODRIVE.searchColumnCreate(rowID, 4)
  }
}

ODRIVE.searchGetPredicate = function (rowID)
{
  var field = $('search_field_0_' + rowID)
  if (field)
  {
    for (var i = 0; i < ODRIVE.searchPredicates.length; i = i + 2)
    {
      if (ODRIVE.searchPredicates[i] == field.value)
      {
        return ODRIVE.searchPredicates[i+1];
      }
    }
  }
  return null;
}

ODRIVE.searchGetCompares = function (predicate)
{
  if (predicate)
  {
  }
  return null;
}

ODRIVE.davFolderSelect = function (fld)
{
  var options = { mode: 'browser',
                  onConfirmClick: function(path) {$(fld).value = '/DAV' + path;}
                };
  OAT.WebDav.open(options);
}

ODRIVE.davFileSelect = function (fld)
{
  var options = { mode: 'browser',
                  onConfirmClick: function(path, fname) {$(fld).value = path + fname;}
                };
  OAT.WebDav.open(options);
}

ODRIVE.coloriseTables = function ()
{
  var area = $('app_area');
  if (!area) {area = document;}
  var tables = area.getElementsByTagName("table");
  for (var i = 0; i < tables.length; i++)
  {
    if (OAT.Dom.isClass(tables[i], "colorise"))
    {
      coloriseTable(tables[i]);
    }
  }
}

