/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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
function destinationChange(obj, changes) {
  function destinationChangeInternal(actions) {
    if (!obj)
      return;

    if (actions.hide) {
      var a = actions.hide;
      for ( var i = 0; i < a.length; i++)
        OAT.Dom.hide(a[i]);
    }
    if (actions.show) {
      var a = actions.show;
      for ( var i = 0; i < a.length; i++)
        OAT.Dom.show(a[i]);
    }
    if (actions.clear) {
      var a = actions.clear;
      for ( var i = 0; i < a.length; i++) {
        var o = $(a[i])
        if (o && o.value)
          o.value = '';
      }
    }
    if (actions.exec) {
		  var a = actions.exec;
		  for ( var i = 0; i < a.length; i++) {
			  a[i](obj);
		  }
	  }
  }
  if (!changes)
    return;

  if (obj.checked && changes.checked)
    destinationChangeInternal(changes.checked);

  if (!obj.checked && changes.unchecked)
    destinationChangeInternal(changes.unchecked);
}

function vspxPost(fButton, fName, fValue, f2Name, f2Value, f3Name, f3Value) {
  if (fName)
    createHidden('F1', fName, fValue);
  if (f2Name)
    createHidden('F1', f2Name, f2Value);
  if (f3Name)
    createHidden('F1', f3Name, f3Value);
  doPost('F1', fButton);
}

var eventTimer;
function vspxSelect(fValue) {
  if (eventTimer)
    clearTimeout(eventTimer);

  eventTimer = setTimeout(
    function() {
      return vspxPost('action', '_cmd', 'select', '_path', fValue);
    }, 500);
}

function vspxUpdate(fValue) {
  if (eventTimer)
    clearTimeout(eventTimer);

  return vspxPost('action', '_cmd', 'update', '_path', fValue);
}

function vspxEdit(fValue) {
  if (eventTimer)
    clearTimeout(eventTimer);

  return vspxPost('action', '_cmd', 'edit', '_path', fValue);
}

function vspxView(fValue) {
  if (eventTimer)
    clearTimeout(eventTimer);

  return vspxPost('action', '_cmd', 'view', '_path', fValue);
}

function cleanPost() {
  var frm = document.forms['F1'];
  frm.__submit_func.value = '__submit__';
  frm.__submit_func.name = '';
}

function odsPost(obj, fields, button) {
  var form = getParent (obj, 'form');
  var formName = form.name;
  createHidden(formName, '_cmd', '');
  for (var i = 0; i < fields.length; i += 2)
    createHidden(formName, fields[i], fields[i+1]);

  if (button) {
    doPost(formName, button);
  } else {
    form.submit();
  }
}

function sortPost(obj, fName, fValue)
{
  if (DAVSTATE) {
    DAVSTATE.readState();
    if (DAVSTATE.state.column != fValue) {
      DAVSTATE.state.direction = 'asc';
    } else {
      if (DAVSTATE.state.direction == 'asc') {
        DAVSTATE.state.direction = 'desc';
      } else {
        DAVSTATE.state.direction = 'asc';
      }
    }
    DAVSTATE.state.column = fValue;
    DAVSTATE.writeState();
  }
  return odsPost(obj, [fName, fValue]);
}

function submitEnter(e, myForm, myButton, myAction)
{
  var keycode;
  if (window.event) {
    keycode = window.event.keyCode;
  } else {
    if (!e)
      return true;

    keycode = e.which;
  }
  if (keycode == 13) {
    if (myButton == 'action') {
      vspxPost(myButton, '_cmd', myAction);
      return false;
    }
    if (myButton != '') {
      doPost (myForm, myButton);
      return false;
    }
    document.forms[myForm].submit();
  }
  return true;
}

function checkNotEnter(e) {
  var key;
  if (window.event) {
    key = window.event.keyCode;
  } else {
    if (e) {
      key = e.which;
    } else {
      return true;
    }
  }
  if (key == 13)
    return false;
  return true;
}

function selectAllCheckboxes (obj, prefix, toolbarsFlag) {
  var objForm = obj.form;
  for (var i = 0; i < objForm.elements.length; i++) {
    var o = objForm.elements[i];
    if (o != null && o.type == "checkbox" && !o.disabled && o.name.indexOf (prefix) == 0) {
      o.checked = (obj.value == 'Select All');
      coloriseRow(getParent(o, 'tr'), o.checked);
    }
  }
  obj.value = (obj.value == 'Select All')? 'Unselect All': 'Select All';
  if (toolbarsFlag)
    WEBDAV.enableToolbars(objForm, prefix);
  obj.focus();
}

function selectCheck(obj, prefix)
{
  coloriseRow(getParent(obj, 'tr'), obj.checked);
  WEBDAV.enableToolbars(obj.form, prefix, document);
}

function getParent (o, tag)
{
  var o = o.parentNode;
  if (o.tagName.toLowerCase() == tag)
    return o;

  return getParent(o, tag);
}

function getDocument (doc)
{
  if (doc)
    return doc;

  if (window.frameElement)
    return window.frameElement.contentDocument;

  return document;
}

function getSelected (frm, txt)
{
  var s = '';
  var n = 1;
  if (frm  && txt) {
    for (var i = 0; i < frm.elements.length; i++) {
      var obj = frm.elements[i];
      if (obj && (obj.type == "checkbox") && (obj.name.indexOf (txt) != -1) && obj.checked) {
        s = s + '&f' + n + '=' + escape((obj.name).substr(txt.length));
        n++;
      }
    }
  }
  return s;
}

function getFileName(obj)
{
  var S = obj.value;
  var N;
  if (S.lastIndexOf('\\') > 0)
    N = S.lastIndexOf('\\') + 1;
  else
    N = S.lastIndexOf('/') + 1;
  S = S.substr(N, S.length);
  if (S.indexOf('?') > 0) {
    N = S.indexOf('?');
    S = S.substr(0, N);
  }
  if (S.indexOf('#') > 0) {
    N = S.indexOf('#');
    S = S.substr(0, N);
  }
  if (document.forms['F1'].elements['dav_destination']) {
    if (document.F1.dav_destination[1].checked == '1') {
      N = S.indexOf('.rdf');
      S = S.substr(0, N);
    }
    if ((document.F1.dav_destination[0].checked == '1') && (document.F1.dav_source[2].checked == '1')) {
      N = S.indexOf('.rdf');
      if (N == -1)
        S = S + '.rdf';
    }
  }
  if ($('dav_name'))
    $('dav_name').value = S;
}

function chkbx(bx1, bx2)
{
  if (bx1.checked == true && bx2.checked == true)
    bx2.checked = false;
}

function updateLabel(value)
{
  function showLabel(from, to)
  {
    for (var i = from; i <= to; i++)
      OAT.Dom.show('tab_'+i);
  }

  function hideLabel(from, to)
  {
    for (var i = from; i <= to; i++)
      OAT.Dom.hide('tab_'+i);
  }

  if (!value)
    return;

  hideLabel(4, 17);
  if (value == 'oMail')
    showLabel(4, 4);
  else if (value == 'PropFilter')
    showLabel(5, 5);
  else if (value == 'S3')
    showLabel(6, 6);
  else if (value == 'ResFilter')
    showLabel(7, 7);
  else if (value == 'CatFilter')
    showLabel(7, 7);
  else if (value == 'rdfSink')
    showLabel(8, 8);
  else if (value == 'SyncML')
    showLabel(10, 10);
  else if (value == 'IMAP')
    showLabel(11, 11);
  else if (value == 'GDrive')
    showLabel(12, 12);
  else if (value == 'Dropbox')
    showLabel(13, 13);
  else if (value == 'SkyDrive')
    showLabel(14, 14);
  else if (value == 'Box')
    showLabel(15, 15);
  else if (value == 'WebDAV')
    showLabel(16, 16);
  else if (value == 'RACKSPACE')
    showLabel(17, 17);

  if ((value == 'IMAP') || (value == 'WebDAV'))
    OAT.Dom.show('cVerify');
  else
    OAT.Dom.hide('cVerify');

}

function showTab(tab, tabs)
{
  for (var i = 1; i <= tabs; i++) {
    var div = document.getElementById(i);
    if (div) {
      var divTab = $('tab_'+i);
      if (i == tab) {
        var divNo = $('tabNo');
        divNo.value = tab;
        OAT.Dom.show(div);
        if (divTab) {
          OAT.Dom.addClass(divTab, "activeTab");
          divTab.blur();
        }
      } else {
        OAT.Dom.hide(div);
        if (divTab)
          OAT.Dom.removeClass(divTab, "activeTab");
      }
    }
  }
}

function initTab(tabs, defaultNo)
{
  var divNo = $v('tabNo');
  var tab = defaultNo;
  if (divNo) {
    var divTab = $v('tab_'+divNo);
    if (divTab)
      tab = divNo;
  }
  showTab(tab, tabs);
}

function initDisabled()
{
  var formRight = $v('formRight');
  if (formRight && formRight != '1')
    return;

  var objects = document.F1.elements;
  for (var i = 0; i < objects.length; i++) {
    var obj = objects[i];
    if (obj.disabled && !OAT.Dom.isClass(obj, "disabled"))
      obj.disabled = false;
  }
}

function webidShow(obj) {
  var S = 'p';
  if (obj.id.replace('fld_2', 'fld_1') != obj.id)
    S = $v(obj.id.replace('fld_2', 'fld_1'));

  windowShow('/ods/webid_select.vspx?mode='+S.charAt(0)+'&params='+obj.id+':s1;');
}

function windowShowInternal(sPage, sPageName, width, height) {
  if (width == null)
    width = 700;
  if (height == null)
    height = 500;
  win = window.open(sPage, sPageName, "width="+width+",height="+height+",top=100,left=100,status=yes,toolbar=no,menubar=no,scrollbars=yes,resizable=yes");
  win.window.focus();
}

function windowShow(sPage, sPageName, width, height) {
  function urlParam(fldName) {
    var O = document.forms[0].elements[fldName];
    if (O && O.value != '')
      return '&' + fldName + '=' + encodeURIComponent(O.value);
    return '';
  }

  if (sPage.indexOf('form=') == -1)
    sPage += '&form=F1';
  if (sPage.indexOf('sid=') == -1)
    sPage += urlParam('sid');
  if (sPage.indexOf('realm=') == -1)
    sPage += urlParam('realm');
  windowShowInternal(sPage, sPageName, width, height);
}

function renameShow(myForm, myPrefix, myPage, width, height) {
  var myFiles = getSelected (myForm, myPrefix);
  if (myFiles != '')
    windowShow(myPage + myFiles, width, height);
}

function authenticateShow(sPage, sPageName, drive, width, height) {
  if (drive == 'WebDAV')
    sPage += '&service=' + encodeURIComponent($v('dav_WebDAV_oauth'));

  OAT.Dom.show('dav_'+drive+'_throbber');
  windowShowInternal(sPage, sPageName, width, height);
}

function coloriseRow(obj, checked) {
  if (checked)
    OAT.Dom.addClass(obj, 'selected');
  else
    OAT.Dom.removeClass(obj, 'selected');
}

// Hiddens functions
function createHidden(frm_name, fld_name, fld_value)
{
  var hidden;

  if (document.forms[frm_name]) {
    hidden = document.forms[frm_name].elements[fld_name];
    if (!hidden) {
      hidden = document.createElement("input");
      hidden.setAttribute("type", "hidden");
      hidden.setAttribute("name", fld_name);
      hidden.setAttribute("id", fld_name);
      document.forms[frm_name].appendChild(hidden);
    }
    hidden.value = fld_value;
  }
  return hidden;
}

function getObject(id, doc)
{
  if (!doc) {doc = document;}
  return doc.getElementById(id);
}

showRow = (navigator.appName.indexOf("Internet Explorer") != -1) ? "block" : "table-row";

var WEBDAV = new Object();

WEBDAV.Preferences = {
  imagePath: "dav/image/"
}

WEBDAV.toggleDavRows = function ()
{
  function showTableRow(cell)
  {
    var c = getObject(cell);
    if ((c) && (c.style.display == "none"))
      c.style.display = showRow;
  }

  if (!document.forms['F1'].elements['dav_destination'])
    return;

  if (document.forms['F1'].elements['dav_destination'][0].checked == '1')
  {
    showTableRow('davRow_mime');
    showTableRow('davRow_version');
    showTableRow('davRow_owner');
    showTableRow('davRow_group');
    showTableRow('davRow_perms');
    showTableRow('davRow_encryption');
    showTableRow('davRow_text');
    showTableRow('davRow_metadata');
    showTableRow('davRow_tagsPublic');
    showTableRow('davRow_tagsPrivate');

    OAT.Dom.show('dav_source_2');
    OAT.Dom.show('label_dav');
    OAT.Dom.hide('label_dav_rdf');
    OAT.Dom.show('dav_name');
    OAT.Dom.hide('dav_name_rdf');
  }
  else if (document.forms['F1'].elements['dav_destination'][1].checked == '1')
  {
    OAT.Dom.hide('davRow_tagsPrivate');
    OAT.Dom.hide('davRow_tagsPublic');
    OAT.Dom.hide('davRow_metadata');
    OAT.Dom.hide('davRow_text');
    OAT.Dom.hide('davRow_encryption');
    OAT.Dom.hide('davRow_perms');
    OAT.Dom.hide('davRow_group');
    OAT.Dom.hide('davRow_owner');
    OAT.Dom.hide('davRow_version');
    OAT.Dom.hide('davRow_mime');
    if ($('dav_content_plain'))
      OAT.Dom.show('davRow_mime');

    OAT.Dom.hide('dav_source_2');
    if (document.forms['F1'].elements['dav_source'] && (document.forms['F1'].elements['dav_source'][2].checked == '1'))
      document.forms['F1'].elements['dav_source'][0].checked = '1';

    OAT.Dom.hide('label_dav');
    OAT.Dom.show('label_dav_rdf');
    OAT.Dom.hide('dav_name');
    OAT.Dom.show('dav_name_rdf');
  }
  WEBDAV.toggleDavSource();
}

WEBDAV.toggleDavSource = function ()
{
  if (!document.forms['F1'].elements['dav_source'])
    return;

  if (document.forms['F1'].elements['dav_source'][0].checked == '1')
  {
    $('dav_file_label').innerHTML = 'File';
    OAT.Dom.show('dav_file');
    OAT.Dom.hide('dav_url');
    OAT.Dom.hide('dav_rdf');
  }
  else if (document.forms['F1'].elements['dav_source'][1].checked == '1')
  {
    $('dav_file_label').innerHTML = 'URL';
    OAT.Dom.hide('dav_file');
    OAT.Dom.show('dav_url');
    OAT.Dom.hide('dav_rdf');
  }
  else if (document.forms['F1'].elements['dav_source'][2].checked == '1')
  {
    $('dav_file_label').innerHTML = 'Quad Store Named Graph IRI';
    OAT.Dom.hide('dav_file');
    OAT.Dom.hide('dav_url');
    OAT.Dom.show('dav_rdf');
  }
}

WEBDAV.writeCookie = function (name, value, hours)
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

WEBDAV.readCookie = function (name)
{
  var cookiesArr = document.cookie.split (';');
  for (var i = 0; i < cookiesArr.length; i++) {
    cookiesArr[i] = cookiesArr[i].trim();
    if (cookiesArr[i].indexOf (name+'=') == 0)
      return cookiesArr[i].substring (name.length + 1, cookiesArr[i].length);
  }
  return false;
}

WEBDAV.readField = function (fld, doc)
{
  var v;
  if (!doc) {doc = document;}
  if (doc.forms[0]) {
    v = doc.forms[0].elements[fld];
    if (v)
      v = v.value;
  }
  return v;
}

WEBDAV.createParam = function (fld, doc)
{
  var S = '';
  var v = WEBDAV.readField(fld, doc);
  if (v)
    S = '&'+fld+'='+ encodeURIComponent(v);
  return S;
}

WEBDAV.sessionParams = function (doc)
{
  return WEBDAV.createParam('sid', doc)+WEBDAV.createParam('realm', doc);
}

WEBDAV.saveState = function ()
{
  WEBDAV.writeCookie('WEBDAV_State', escape(OAT.JSON.stringify(WEBDAV.state)), 1);
}

WEBDAV.init = function ()
{
  function initState(state)
  {
    if (!state)
      var state = new Object();

    state.sid = WEBDAV.readField('sid');
    state.realm = WEBDAV.readField('realm');

    return state;
  }

  // load cookie data
  var s = WEBDAV.readCookie('WEBDAV_State');
  if (s) {
    try {
      s = OAT.JSON.parse(unescape(s));
    } catch (e) { s = null; }
    s = initState(s);
  } else {
    s = initState();
  }
  WEBDAV.state = s;
}

WEBDAV.formParams = function (doc)
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

WEBDAV.enableElement = function(id, id_gray, flag, doc)
{
  doc = getDocument (doc);
  var mode = 'block';
  var o = getObject(id, doc);
  if (o) {
    if (flag) {
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

WEBDAV.enableToolbars = function(objForm, prefix, doc)
{
  var oCount = 0;
  var cCount = 0;
  var rCount = 0;
  var tCount = 0;
  for (var i = 0; i < objForm.elements.length; i++) {
    var o = objForm.elements[i];
    if (o != null && o.type == 'checkbox' && !o.disabled && o.name.indexOf (prefix) != -1 && o.checked) {
      oCount++;
      if (o.value[o.value.length-1] == '/') {
        cCount++;
      } else {
        rCount++;
      }
    }
  }
  tCount = rCount;
  if (oCount != rCount)
    tCount = 0;
  WEBDAV.enableElement('tb_rename', 'tb_rename_gray', oCount==1, doc);
  WEBDAV.enableElement('tb_copy', 'tb_copy_gray', oCount>0, doc);
  WEBDAV.enableElement('tb_move', 'tb_move_gray', oCount>0, doc);
  WEBDAV.enableElement('tb_delete', 'tb_delete_gray', oCount>0, doc);

  WEBDAV.enableElement('tb_tag', 'tb_tag_gray', tCount>0, doc);
  WEBDAV.enableElement('tb_properties', 'tb_properties_gray', oCount>1, doc);
  WEBDAV.enableElement('tb_share', 'tb_share_gray', oCount>1, doc);
}

WEBDAV.resetToolbars = function ()
{
  WEBDAV.enableElement('tb_rename', 'tb_rename_gray', 0);
  WEBDAV.enableElement('tb_copy', 'tb_copy_gray', 0);
  WEBDAV.enableElement('tb_move', 'tb_move_gray', 0);
  WEBDAV.enableElement('tb_delete', 'tb_delete_gray', 0);

  WEBDAV.enableElement('tb_tag', 'tb_tag_gray', 0);
  WEBDAV.enableElement('tb_properties', 'tb_properties_gray', 0);
  WEBDAV.enableElement('tb_share', 'tb_share_gray', 0);
}

WEBDAV.davFolderSelect = function (fld)
{
  /* load stylesheets */
  OAT.Style.include("grid.css");
  OAT.Style.include("webdav.css");

  var options = {
    mode: 'browser',
    onConfirmClick: function(path) {$(fld).value = path;}
  };
  OAT.WebDav.options.foldersOnly = true;
  OAT.WebDav.open(options);
}

WEBDAV.davFileSelect = function (fld)
{
  /* load stylesheets */
  OAT.Style.include("grid.css");
  OAT.Style.include("webdav.css");

  var options = {
    mode: 'browser',
    onConfirmClick: function(path, fname) {$(fld).value = path + fname;}
  };
  OAT.WebDav.options.foldersOnly = false;
  OAT.WebDav.open(options);
}

WEBDAV.validateInputs = function (fld)
{
  var retValue = true;
  var form = fld.form;
  for (i = 0; i < form.elements.length; i++) {
    var fld = form.elements[i];
    if (!fld.readOnly && OAT.Dom.isClass(fld, '_validate_') && WEBDAV.validateField) {
      retValue = WEBDAV.validateField(fld);
      if (!retValue)
        return retValue;
    }
  }
  return retValue;
}

WEBDAV.toggleEditor = function ()
{
  if (!window.oEditor)
    return;

  if ($v('dav_mime') == 'text/html') {
    OAT.Dom.hide('dav_plain');
    OAT.Dom.show('dav_html');
  } else {
    OAT.Dom.show('dav_plain');
    OAT.Dom.hide('dav_html');
  }
}

WEBDAV.updateRdfGraph = function ()
{
  function updateRdfGraphInternal(det) {
    var graphPrefix;
    var rdfGraph;

    rdfGraph = $('dav_'+det+'_graph');
    if (!rdfGraph)
      return;

    graphPrefix = $v('rdfGraph_prefix');
    if ((rdfGraph.value == '') || (rdfGraph.value == (graphPrefix+$v('dav_name_save'))))
      rdfGraph.value = graphPrefix + escape($v('dav_name'));
  }
  function updateRdfBaseInternal(det) {
    var basePrefix;
    var rdfBase;

    rdfBase = $('dav_'+det+'_base');
    if (!rdfBase)
      return;

    basePrefix = $v('rdfBase_prefix');
    if ((rdfBase.value == '') || (rdfBase.value == (basePrefix+$v('dav_name_save'))))
      rdfBase.value = basePrefix + escape($v('dav_name'));
  }
  function updateRdfBaseResourceInternal(det) {
    var basePrefix;
    var rdfBase;

    rdfBase = $('dav_'+det+'_baseResource');
    if (!rdfBase)
      return;

    basePrefix = $v('rdfBase_prefix');
    if ((rdfBase.value == '') || (rdfBase.value == (basePrefix+$v('dav_name_save'))))
      rdfBase.value = basePrefix + escape($v('dav_name'));
  }
  updateRdfGraphInternal('rdfSink');
  updateRdfBaseInternal('rdfSink');
  updateRdfBaseResourceInternal('rdfSink');

  updateRdfGraphInternal('S3');
  updateRdfGraphInternal('IMAP');
  updateRdfGraphInternal('GDrive');
  updateRdfGraphInternal('Dropbox');
  updateRdfGraphInternal('SkyDrive');
  updateRdfGraphInternal('Box');
  updateRdfGraphInternal('WebDAV');
  updateRdfGraphInternal('RACKSPACE');

  $('dav_name_save').value = escape($v('dav_name'));
}

WEBDAV.oauthParams = function (drive, oauth)
{
  var params = null;
  try {
    params = OAT.JSON.parse(unescape(oauth));
  } catch (e) {}
  var fld = createHidden('F1', 'dav_'+drive+'_JSON', null);
  if (!params || params.error) {
    alert ('Bad authentication!');
    fld.value = '';
  } else {
    var d = new Date();
    d = new Date(d.valueOf() + d.getTimezoneOffset() * 60000)
    params.access_timestamp = d.format('Y-m-d H:i');
    fld.value = OAT.JSON.serialize(params);

    if ($('tr_dav_'+drive+'_display_name') && params.name && (params.name != '(NULL)')) {
      createHidden('F1', 'dav_'+drive+'_display_name', params.name);
      OAT.Dom.show('tr_dav_'+drive+'_display_name');
      $('td_dav_'+drive+'_display_name').innerHTML = params.name;
    }

    if ($('tr_dav_'+drive+'_email') && params.email && (params.email != '(NULL)')) {
      createHidden('F1', 'dav_'+drive+'_email', params.email);
      OAT.Dom.show('tr_dav_'+drive+'_email');
      $('td_dav_'+drive+'_email').innerHTML = params.email;
    }

    if ($('tr_dav_'+drive+'_path')) {
      OAT.Dom.show('tr_dav_'+drive+'_path');
    }

    $('dav_'+drive+'_authenticate').value = 'Re-Authenticate';
  }
  OAT.Dom.hide('dav_'+drive+'_throbber');
}

WEBDAV.verifyDialog = function ()
{
  var verifyDiv = $('verifyDiv');
  if (verifyDiv)
    OAT.Dom.unlink(verifyDiv);

  var verifyType = $v('dav_det');

  var content;
  content =
    '<div style="padding: 1em;">' +
    '<table style="width: 100%;">';
  if (verifyType == 'IMAP') {
    content +=
    '  <tr>' +
    '    <td align="right" width="50%">' +
    '      <b>Connection type:</b>' +
    '    </td>' +
    '    <td>{connection}</td>' +
    '  </tr>' +
    '  <tr>' +
    '    <td align="right" width="50%">' +
    '      <b>Mail server:</b>' +
    '    </td>' +
    '    <td>{server}:{port}</td>' +
    '  </tr>' +
    '  <tr>' +
    '    <td align="right" width="50%">' +
    '      <b>User:</b>' +
    '    </td>' +
    '    <td>{user}</td>' +
      '  </tr>'
  ;
  } else {
    content +=
      '  <tr>' +
      '    <td align="right" width="50%">' +
      '      <b>WebDAV path:</b>' +
      '    </td>' +
      '    <td>{path}</td>' +
      '  </tr>' +
      '  <tr>' +
      '    <td align="right" width="50%">' +
      '      <b>User:</b>' +
      '    </td>' +
      '    <td>{user}</td>' +
      '  </tr>'
    ;
  }
  content +=
    '  <tr><td align="center" colspan="2"><hr /><td></tr>' +
    '  <tr>' +
    '    <td align="right">' +
    '      <b>Verification:</b>' +
    '    </td>' +
    '    <td>{text}</td>' +
    '  </tr>' +
    '  <tr><td align="center" colspan="2"><hr /><td></tr>' +
    '  <tr>' +
    '    <td align="center" colspan="2">' +
    '      <input type="button" value="OK" onclick="javascript: verifyDialog.hide(); return false;" />' +
    '    <td>' +
    '  </tr>' +
    '</table>' +
    '</div>'
  ;

  verifyDiv = OAT.Dom.create('div', {height: '165px', overflow: 'hidden'});
  verifyDiv.id = 'verifyDiv';
  verifyDialog = new OAT.Dialog('Verify External Account', verifyDiv, {width:475, buttons: 0, resize:0, modal:1});
  verifyDialog.cancel = verifyDialog.hide;
  verifyDiv.innerHTML = '<img src="'+OAT.Preferences.imagePath+'Ajax_throbber.gif'+'" style="margin: 80px 220px;" />';
  verifyDialog.show();

  var x = function (txt) {
    var verifyDiv = $("verifyDiv");
    if (verifyDiv) {
      if (verifyType == 'IMAP') {
      content = content.replace('{connection}', $v('dav_IMAP_connection'));
      content = content.replace('{server}', $v('dav_IMAP_server'));
      content = content.replace('{port}', $v('dav_IMAP_port'));
      content = content.replace('{user}', $v('dav_IMAP_user'));
      } else {
        content = content.replace('{path}', $v('dav_WebDAV_path'));
        content = content.replace('{user}', $v('dav_WebDAV_user'));
      }
      if (txt) {
        if (txt.length > 30)
          verifyDiv.style.height = '180px';

        txt = '<i style="color: red;">' + txt + '</i>';
      } else {
        txt = '<i style="color: green;">Successful</i>';
      }
      content = content.replace('{text}', txt);
      verifyDiv.innerHTML = content;
    }
  }
  var t = function(){x('Timeout');};

  OAT.MSG.attach(OAT.AJAX, 'AJAX_TIMEOUT', t);
  var params;
  if (verifyType == 'IMAP') {
    params = '&a=mailVerify'
           + '&connection=' + encodeURIComponent($v('dav_IMAP_connection'))
             + '&server='     + encodeURIComponent($v('dav_IMAP_server'))
             + '&port='       + encodeURIComponent($v('dav_IMAP_port'))
             + '&user='       + encodeURIComponent($v('dav_IMAP_user'))
             + '&password='   + encodeURIComponent($v('dav_IMAP_password'));
  }
  if (verifyType == 'WebDAV') {
    var webdavType;
    if ($('dav_WebDAV_authenticationType_1') && $('dav_WebDAV_authenticationType_1').checked)
      webdavType = 'WebID';
    else if ($('dav_WebDAV_authenticationType_2') && $('dav_WebDAV_authenticationType_2').checked)
      webdavType = 'oauth';
    else
      webdavType = 'Digest';

    params = '&a=webdavVerify'
           + '&type='       + webdavType
           + '&server='     + encodeURIComponent($v('dav_WebDAV_path'));
    if (webdavType == 'Digest') {
      params +='&user='     + encodeURIComponent($v('dav_WebDAV_user'))
             + '&password=' + encodeURIComponent($v('dav_WebDAV_password'));
    } else if (webdavType == 'oauth') {
      try {
        var p = OAT.JSON.parse($v('dav_WebDAV_JSON'));
        if (p && p.sid)
          params +='&oauthSid=' + encodeURIComponent(p.sid);
      } catch (e) {}
    } else {
      params +='&key='      + encodeURIComponent($v('dav_WebDAV_key'))
             + WEBDAV.sessionParams();
    }
  }
  if ($('item_path'))
    params += '&path='      + encodeURIComponent($v('item_path'));

  OAT.AJAX.GET(WEBDAV.httpsLink('dav/dav_browser_rest.vsp')+'?'+params, '', x, {type:OAT.AJAX.TYPE_TEXT, timeout: 5000, onend: function(){OAT.MSG.detach(OAT.AJAX, 'AJAX_TIMEOUT', t);}});
}

var dav_IMAP_connection;
var dav_IMAP_server;
var dav_IMAP_port;
var dav_IMAP_user;
var dav_IMAP_password;
var dav_IMAP_seqNo = 0;;
WEBDAV.loadIMAPFolders = function ()
{
  var needLoad = false;
  if (!dav_IMAP_connection || (dav_IMAP_connection != $v('dav_IMAP_connection').trim())) {
    dav_IMAP_connection = $v('dav_IMAP_connection').trim();
    needLoad = true;
  }
  if (!dav_IMAP_server || (dav_IMAP_server != $v('dav_IMAP_server').trim())) {
    dav_IMAP_server = $v('dav_IMAP_server').trim();
    needLoad = true;
  }
  if (!dav_IMAP_port || (dav_IMAP_port != $v('dav_IMAP_port').trim())) {
    dav_IMAP_port = $v('dav_IMAP_port').trim();
    needLoad = true;
  }
  if (!dav_IMAP_user || (dav_IMAP_user != $v('dav_IMAP_user').trim())) {
    dav_IMAP_user = $v('dav_IMAP_user').trim();
    needLoad = true;
  }
  if (!dav_IMAP_password || (dav_IMAP_password != $v('dav_IMAP_password').trim())) {
    dav_IMAP_password = $v('dav_IMAP_password').trim();
    needLoad = true;
  }
  if (needLoad) {
    var x = function(seqNo, data) {
      if (seqNo < dav_IMAP_seqNo)
        return;

      var o = OAT.JSON.parse(data);
      var dav_IMAP_folder = $('dav_IMAP_folder');
      var cl = dav_IMAP_folder.comboList;
      if (cl) {
        cl.clearOpts();
        var founded = false;
        for (var i = 0; i < o.length; i++) {
          cl.addOption(o[i]);
          if (o[i] == dav_IMAP_folder.value)
            founded = true;
        }
        if (!founded)
          dav_IMAP_folder.value = '';

        dav_IMAP_time = new Date();
      }
    }
    if (dav_IMAP_server && dav_IMAP_user && dav_IMAP_password) {
      var params = '&connection=' + encodeURIComponent(dav_IMAP_connection)
                 + '&server='     + encodeURIComponent(dav_IMAP_server)
                 + '&port='       + encodeURIComponent(dav_IMAP_port)
                 + '&user='       + encodeURIComponent(dav_IMAP_user)
                 + '&password='   + encodeURIComponent(dav_IMAP_password);
      if ($('item_path'))
        params  += '&path='       + $v('item_path');

      dav_IMAP_seqNo += 1;
      var seqNo = dav_IMAP_seqNo;
      OAT.AJAX.GET(WEBDAV.httpsLink('dav/dav_browser_rest.vsp')+'?a=mailFolders'+params, '', function(data){x(seqNo, data);});
    }
  }
}

WEBDAV.httpsLink = function (page) {
  return page;

  if (!WEBDAV.sslData)
    return page;

  var href =
    'https://' +
    document.location.hostname +
    ((WEBDAV.sslData.sslPort != '443')? ':' + WEBDAV.sslData.sslPort: '') +
    document.location.pathname +
    '/' +
    page;
  return href;
}

WEBDAV.selectRow = function (formName) {
  if (opener == null)
    return;

  var returnName = $v('retname');
  if (returnName)
    opener[returnName].value = $v('item_name');

  opener.focus ();
  close ();
}

// Menu functions
WEBDAV.menuMouseOut = function (event)
{
  var current, related;

  function menuMouseIn(a, b)
  {
    if (b) {
      while (b.parentNode) {
        b = b.parentNode;
        if (b == a)
          return true;
      }
    }
    return false;
  }

  if (window.event)
  {
    current = this;
    related = window.event.toElement;
  } else {
    current = event.currentTarget;
    related = event.relatedTarget;
  }
  if ((current != related) && !menuMouseIn(current, related))
    OAT.Dom.hide(current);
}

WEBDAV.menuPopup = function (obj, menuID)
{
  var actions = $$('WEBDAV_menu');
  for (var i = 0; i < actions.length; i++) {
    OAT.Dom.hide(actions[i]);
    OAT.Event.attach(actions[i], 'mouseout', WEBDAV.menuMouseOut);
  }
  var div = $(menuID);
  if (div.style.display != 'none') {
    OAT.Dom.hide(div);
  } else {
    var coords = OAT.Dom.position(obj);
    var dims = OAT.Dom.getWH(obj);
    div.style.left = (coords[0]+25) +"px";
    div.style.top = (coords[1]+dims[1]-23)+"px";
    OAT.Dom.show(div);
    div.focus();
  }
  return false;
}
