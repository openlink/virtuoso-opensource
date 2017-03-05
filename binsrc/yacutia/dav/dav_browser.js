/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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

function graphBindingChange(obj, det, ndx)
{
  destinationChange(obj, {"checked": {"show": ['dav'+ndx+'_graph', 'dav'+ndx+'_sponger']}, "unchecked": {"hide": ['dav'+ndx+'_graph', 'dav'+ndx+'_sponger'], "clear": ['dav_'+det+'_graph']}});
  if (obj.checked) {
    destinationChange($('dav_'+det+'_sponger'), {"checked": {"show": ['dav'+ndx+'_cartridge', 'dav'+ndx+'_metaCartridge']}, "unchecked": {"hide": ['dav'+ndx+'_cartridge', 'dav'+ndx+'_metaCartridge']}});
  }
  else {
    destinationChange(obj, {"checked": {"show": ['dav'+ndx+'_cartridge', 'dav'+ndx+'_metaCartridge']}, "unchecked": {"hide": ['dav'+ndx+'_cartridge', 'dav'+ndx+'_metaCartridge']}});
  }
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

  if (['', 'S3', 'GDrive', 'Dropbox', 'SkyDrive', 'Box', 'WebDAV', 'RACKSPACE'].indexOf(value) === -1) {
    OAT.Dom.hide('tr_dav_ldp');
  } else {
    OAT.Dom.show('tr_dav_ldp');
  }

  if (!value)
    return;

  hideLabel(4, 18);
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
  else if (value == 'FTP')
    showLabel(18, 18);

  if (value == 'WebDAV')
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

function urlParam(fldName) {
  var O = document.forms[0].elements[fldName];
  if (O && O.value != '')
    return '&' + fldName + '=' + encodeURIComponent(O.value);
  return '';
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
    OAT.Dom.hide('dav_plain_turtle');
    OAT.Dom.show('dav_html');
  }
  else if ($v('dav_mime') == 'text/turtle') {
    OAT.Dom.show('dav_plain');
    OAT.Dom.show('dav_plain_turtle');
    OAT.Dom.hide('dav_html');
  }
  else {
    OAT.Dom.show('dav_plain');
    OAT.Dom.hide('dav_plain_turtle');
    OAT.Dom.hide('dav_html');
  }
}

WEBDAV.updateRdfGraph = function ()
{
  function updateRdfGraphInternal(det) {
    var graphPrefix;
    var rdfGraph;

    if ((det === 'rdfSink') || $('dav_'+det+'_binding').checked) {
    rdfGraph = $('dav_'+det+'_graph');
    if (!rdfGraph)
      return;

    graphPrefix = $v('rdfGraph_prefix');
      if ((rdfGraph.value == '') || (rdfGraph.value == (graphPrefix+$v('dav_name_save')))) {
      rdfGraph.value = graphPrefix + escape($v('dav_name'));
  }
    }
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

WEBDAV.comboListPath = function (element, name, val)
{
  var fld = new OAT.Combolist([], val);
  fld.input.name = name;
  fld.input.id = name;
  fld.input.className = 'field-text';
  fld.input.value = val;
  fld.input.comboList = fld;
  fld.list.style.width = '500px';

  fld.throbler = OAT.Dom.create("img", {display: "none"});
  fld.throbler.src = OAT.AJAX.imagePath+"Ajax_throbber.gif";
  fld.div.appendChild(fld.throbler);
  OAT.Dom.hide(fld.img);

  $(element).appendChild(fld.div);
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
  }
  else {
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

    if ($('tr_dav_'+drive+'_path'))
      OAT.Dom.show('tr_dav_'+drive+'_path');

    $('dav_'+drive+'_authenticate').value = 'Re-Authenticate';
    WEBDAV.loadDriveFolders(drive);
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

  OAT.AJAX.GET(WEBDAV.httpsLink(WEBDAV.Preferences.restPath+'dav_browser_rest.vsp')+'?'+params, '', x, {type:OAT.AJAX.TYPE_TEXT, timeout: 5000, onend: function(){OAT.MSG.detach(OAT.AJAX, 'AJAX_TIMEOUT', t);}});
}

WEBDAV.dav_IMAP_seqNo = 0;
WEBDAV.loadIMAPFolders = function ()
{
  var needLoad = false;
  if (!WEBDAV.dav_IMAP_connection || (WEBDAV.dav_IMAP_connection != $v('dav_IMAP_connection').trim())) {
    WEBDAV.dav_IMAP_connection = $v('dav_IMAP_connection').trim();
    needLoad = true;
  }
  if (!WEBDAV.dav_IMAP_server || (WEBDAV.dav_IMAP_server != $v('dav_IMAP_server').trim())) {
    WEBDAV.dav_IMAP_server = $v('dav_IMAP_server').trim();
    needLoad = true;
  }
  if (!WEBDAV.dav_IMAP_port || (WEBDAV.dav_IMAP_port != $v('dav_IMAP_port').trim())) {
    WEBDAV.dav_IMAP_port = $v('dav_IMAP_port').trim();
    needLoad = true;
  }
  if (!WEBDAV.dav_IMAP_user || (WEBDAV.dav_IMAP_user != $v('dav_IMAP_user').trim())) {
    WEBDAV.dav_IMAP_user = $v('dav_IMAP_user').trim();
    needLoad = true;
  }
  if (!WEBDAV.dav_IMAP_password || (WEBDAV.dav_IMAP_password != $v('dav_IMAP_password').trim())) {
    WEBDAV.dav_IMAP_password = $v('dav_IMAP_password').trim();
    needLoad = true;
  }
  if (needLoad && WEBDAV.dav_IMAP_server && WEBDAV.dav_IMAP_port && WEBDAV.dav_IMAP_user && WEBDAV.dav_IMAP_password) {
    var x = function(seqNo, data) {
      if (seqNo < WEBDAV.dav_IMAP_seqNo)
        return;

      var dav_IMAP_folder = $('dav_IMAP_folder');
      var cl = dav_IMAP_folder.comboList;
      if (cl) {
        cl.clearOpts();
        var o = OAT.JSON.parse(data);
        var founded = false;
        for (var i = 0; i < o.length; i++) {
          cl.addOption(o[i]);
          if (o[i] == dav_IMAP_folder.value)
            founded = true;
        }
        if (!founded) {
          dav_IMAP_folder.value = '';
      }
        if (o.length) {
          OAT.Dom.show(cl.img);
          $('dav_IMAP_authenticated').innerHTML = 'Authenticated';
        }
        OAT.Dom.hide(cl.throbler);
    }
    }
    var params = '&connection=' + encodeURIComponent(WEBDAV.dav_IMAP_connection)
               + '&server='     + encodeURIComponent(WEBDAV.dav_IMAP_server)
               + '&port='       + encodeURIComponent(WEBDAV.dav_IMAP_port)
               + '&user='       + encodeURIComponent(WEBDAV.dav_IMAP_user)
               + '&password='   + encodeURIComponent(WEBDAV.dav_IMAP_password);
      if ($('item_path'))
        params  += '&path='       + $v('item_path');

   var dav_IMAP_folder = $('dav_IMAP_folder');
   var cl = dav_IMAP_folder.comboList;
   if (cl) {
      OAT.Dom.hide(cl.img);
      OAT.Dom.show(cl.throbler);
      $('dav_IMAP_authenticated').innerHTML = 'Not Authenticated';
    }

    WEBDAV.dav_IMAP_seqNo += 1;
    var seqNo = WEBDAV.dav_IMAP_seqNo;
      OAT.AJAX.GET(WEBDAV.httpsLink(WEBDAV.Preferences.restPath+'dav_browser_rest.vsp')+'?a=mailFolders'+params, '', function(data){x(seqNo, data);});
    }
  }

WEBDAV.dav_DET_seqNo = 0;
WEBDAV.loadDriveFolders = function (drive, fields)
{
  var x = function(seqNo, drive, data) {
    if (seqNo < WEBDAV.dav_DET_seqNo)
      return;

    var dav_DET_path = $('dav_'+drive+'_path');
    var cl = dav_DET_path.comboList;
    if (cl) {
      cl.clearOpts();
      if (data !== 'null') {
        var o = OAT.JSON.parse(data);
        var founded = false;
        for (var i = 0; i < o.length; i++) {
          cl.addOption(o[i]);
          if (o[i] == dav_DET_path.value)
            founded = true;
        }
        if (!founded) {
          dav_DET_path.value = '';
        }
        if (o.length)
          OAT.Dom.show(cl.img);
      }
    }
    OAT.Dom.hide(cl.throbler);
  }
  var params = '&drive='+drive;
  if (fields) {
    for (var i = 0; i < fields.length; i++) {
      params  += '&'+fields[i]+'=' + $v('dav_'+drive+'_' + fields[i]).trim();
    }
  }
  if ($('item_path'))
    params  += '&path=' + $v('item_path');

  var txt = $v('dav_'+drive+'_JSON');
  if (txt) {
    var json = OAT.JSON.deserialize(txt);
    params += '&sid='+json.sid;
  }

  var dav_DET_path = $('dav_'+drive+'_path');
  var cl = dav_DET_path.comboList;
  if (cl) {
    OAT.Dom.hide(cl.img);
    OAT.Dom.show(cl.throbler);
  }

  WEBDAV.dav_DET_seqNo += 1;
  var seqNo = WEBDAV.dav_DET_seqNo;
  OAT.AJAX.GET(WEBDAV.httpsLink(WEBDAV.Preferences.restPath+'dav_browser_rest.vsp')+'?a=driveFolders'+params, '', function(data){x(seqNo, drive, data);});
}


WEBDAV.dav_DET_seqNo = 0;
WEBDAV.loadDriveBuckets = function (drive, bucketName, fields)
{
  var needLoad = false;
  for (var i = 0; i < fields.length; i++) {
    if (!WEBDAV["dav_"+fields[i]] || (WEBDAV["dav_"+fields[i]] != $v('dav_'+drive+'_' + fields[i]).trim())) {
      WEBDAV["dav_"+fields[i]] = $v('dav_'+drive+'_' + fields[i]).trim();
      needLoad = true;

      break;
    }
  }
  if (!needLoad) {
    for (var i = 0; i < fields.length; i++) {
      if (!WEBDAV["dav_"+fields[i]]) {
        break;
      }
    }
  }
  if (needLoad) {
    var x = function(seqNo, drive, data) {
      if (seqNo < WEBDAV.dav_DET_seqNo)
        return;

      var dav_DET_BucketName = $('dav_'+drive+'_'+bucketName);
      var cl = dav_DET_BucketName.comboList;
      if (cl) {
        cl.clearOpts();
        if (data !== 'null') {
          var o = OAT.JSON.parse(data);
          var founded = false;
          for (var i = 0; i < o.length; i++) {
            cl.addOption(o[i]);
            if (o[i] == dav_DET_BucketName.value)
              founded = true;
          }
          if (!founded) {
            dav_DET_BucketName.value = '';
          }
          if (o.length)
            OAT.Dom.show(cl.img);

          // load folders
          fields.push(bucketName);
          WEBDAV.loadDriveFolders(drive, fields);
        }
      }
      OAT.Dom.hide(cl.throbler);
    }
    var params = '&drive='+drive;
    for (var i = 0; i < fields.length; i++) {
      params  += '&'+fields[i]+'=' + $v('dav_'+drive+'_' + fields[i]).trim();
    }
    if ($('item_path'))
      params  += '&path=' + $v('item_path');

    var txt = $v('dav_'+drive+'_JSON');
    if (txt) {
      var json = OAT.JSON.deserialize(txt);
      params += '&sid='+json.sid;
    }

    var dav_DET_BucketName = $('dav_'+drive+'_'+bucketName);
    var cl = dav_DET_BucketName.comboList;
    if (cl) {
      OAT.Dom.hide(cl.img);
      OAT.Dom.show(cl.throbler);
    }

    WEBDAV.dav_DET_seqNo += 1;
    var seqNo = WEBDAV.dav_DET_seqNo;
    OAT.AJAX.GET(WEBDAV.httpsLink(WEBDAV.Preferences.restPath+'dav_browser_rest.vsp')+'?a=driveBuckets'+params, '', function(data){x(seqNo, drive, data);});
  }
}


WEBDAV.prefixDialog = function ()
{
  var prefixDiv = $('prefixDiv');
  if (prefixDiv)
    OAT.Dom.unlink(prefixDiv);

  var content =
    '<div style="padding: 1em;">' +
    '  <table style="width: 100%;">' +
    '    <tr>' +
    '      <td align="right" width="30%">' +
    '        <b>Prefix:</b>' +
    '      </td>' +
    '      <td>' +
    '        <input type="text" name="f_prefix" id="f_prefix">' +
    '      </td>' +
    '    </tr>' +
    '    <tr id="tr_prefix" style="display: none;"><td align="right"><b>Ontology:</b></td><td id="td_prefix"></td></tr>' +
    '    <tr><td align="center" colspan="2"><hr /></td></tr>' +
    '    <tr>' +
    '      <td align="center" colspan="2">' +
    '        <input type="button" value="Search" onclick="javascript: prefixDialog.search(); return false;" />' +
    '        <input type="button" value="Close" onclick="javascript: prefixDialog.hide(); return false;" />' +
    '      <td>' +
    '    </tr>' +
    '  </table>' +
    '</div>'
  ;
  prefixDiv = OAT.Dom.create('div', {height: '150px', overflow: 'hidden'});
  prefixDiv.id = 'prefixDiv';
  prefixDiv.innerHTML = content;
  prefixDialog = new OAT.Dialog('Search prefix (http://prefix.cc)', prefixDiv, {width: 400, buttons: 0, resize: 0, modal: 1});
  prefixDialog.cancel = prefixDialog.hide;
  prefixDialog.search = function () {
    var x = function (txt) {
      if (txt != "")
      {
        var json = OAT.JSON.deserialize(txt);
        var prefixTD = $("td_prefix");
        if (prefixTD)
        {
          prefixTD.innerHTML = (json) ? json : 'N/A';
          OAT.Dom.show("tr_prefix");
        }
      } else {
        OAT.Dom.hide("tr_prefix");
      }
    }
    OAT.AJAX.POST(WEBDAV.httpsLink(WEBDAV.Preferences.restPath+'dav_browser_rest.vsp')+'?a=prefix&p='+$v("f_prefix"), null, x);
  };
  prefixDialog.show ();
}

WEBDAV.prefixesDialog = function (el)
{
  var prefixesDiv = $('prefixesDiv');
  if (prefixesDiv)
    OAT.Dom.unlink(prefixesDiv);

  var content =
    '<div style="padding: 1em;">' +
    '  <table style="width: 100%;">' +
    '    <tr>' +
    '      <td align="right">' +
    '        <b>Prefixes:</b>' +
    '      </td>' +
    '      <td>{text}</td>' +
    '    </tr>' +
    '    <tr><td align="center" colspan="2"><hr /><td></tr>' +
    '    <tr>' +
    '      <td align="center" colspan="2">' +
    '        <input type="button" value="Insert" id="prefixes_insert" style="display: none;" />' +
    '        <input type="button" value="Close" onclick="javascript: prefixesDialog.hide(); return false;" />' +
    '      <td>' +
    '    </tr>' +
    '  </table>' +
    '</div>'
  ;
  prefixesDiv = OAT.Dom.create('div', {height: '120px', overflow: 'hidden'});
  prefixesDiv.id = 'prefixesDiv';
  prefixesDiv.innerHTML = '<img src="'+OAT.Preferences.imagePath+'Ajax_throbber.gif'+'" style="margin: 70px 220px;" />';
  prefixesDialog = new OAT.Dialog('Find missed prefixes', prefixesDiv, {width: 550, buttons: 0, resize: 0, modal: 1});
  prefixesDialog.cancel = prefixesDialog.hide;
  prefixesDialog.show();

  var x = function (data) {
    var txt;
    var o;
    var insert = false;
    var encodeHTML = function (str) {
      return str.replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(/"/g, '&quot;')
                .replace(/'/g, '&apos;');
    };

    try {
      o = OAT.JSON.parse(data);
      WEBDAV.progress.id = o.id;
    }
    catch (e) {}

    if (o) {
      if (o.error) {
        txt = '<i style="color: red;">' + o.message + '</i>';
      }
      else {
        if (o.prefixes && (o.prefixes.length > 0)) {
          insert = true;
          prefixesDiv.style.height = 100 + ((o.prefixes.split('\n').length) * 12) + 'px';
          o.prefixes = o.prefixes.replace(/\t/g, ' ');
          txt = '<i style="color: green;"><pre>' + encodeHTML(o.prefixes) + '</pre></i>';
        }
        else {
          txt = '<i style="color: green;">No missed prefixes</i>';
        }
      }
    }
    else {
      txt = '<i style="color: red;">Call error</i>';
    }
    content = content.replace('{text}', txt);
    prefixesDiv.innerHTML = content;
    if (insert) {
      var prefixesInsert = $('prefixes_insert');
      prefixesInsert.onclick = function () {
        $(el).value = o.prefixes + $(el).value;
      };
      OAT.Dom.show(prefixesInsert);
    }
  }
  OAT.AJAX.POST(WEBDAV.httpsLink(WEBDAV.Preferences.restPath+'dav_browser_rest.vsp')+'?a=prefixes', $v(el), x);
}

WEBDAV.verifyTurtleDialog = function (el)
{
  var verifyTurtleDiv = $('verifyTurtleDiv');
  if (verifyTurtleDiv)
    OAT.Dom.unlink(verifyTurtleDiv);

  var content =
    '<div style="padding: 1em;">' +
    '  <table style="width: 100%;">' +
    '    <tr>' +
    '      <td align="right">' +
    '        <b>Verification:</b>' +
    '      </td>' +
    '      <td>{text}</td>' +
    '    </tr>' +
    '    <tr><td align="center" colspan="2"><hr /><td></tr>' +
    '    <tr>' +
    '      <td align="center" colspan="2">' +
    '        <input type="button" value="Close" onclick="javascript: verifyTurtleDialog.hide(); return false;" />' +
    '      <td>' +
    '    </tr>' +
    '  </table>' +
    '</div>'
  ;
  verifyTurtleDiv = OAT.Dom.create('div', {height: '100px', overflow: 'hidden'});
  verifyTurtleDiv.id = 'verifyTurtleDiv';
  verifyTurtleDiv.innerHTML = '<img src="'+OAT.Preferences.imagePath+'Ajax_throbber.gif'+'" style="margin: 70px 220px;" />';
  verifyTurtleDialog = new OAT.Dialog('Find missed prefixes', verifyTurtleDiv, {width: 550, buttons: 0, resize: 0, modal: 1});
  verifyTurtleDialog.cancel = verifyTurtleDialog.hide;
  verifyTurtleDialog.show();

  var x = function (data) {
    var txt;
    var o;

    try {
      o = OAT.JSON.parse(data);
      WEBDAV.progress.id = o.id;
    }
    catch (e) {}

    if (o) {
      if (o.state) {
        if (o.message.length > 30) {
          verifyTurtleDiv.style.height = '120px';
        }
        txt = '<i style="color: red;">' + o.message + '</i>';
      }
      else {
        txt = '<i style="color: green;">Successful</i>';
      }
    }
    else {
      txt = '<i style="color: red;">Call error</i>';
    }
    content = content.replace('{text}', txt);
    verifyTurtleDiv.innerHTML = content;
  }
  OAT.AJAX.POST(WEBDAV.httpsLink(WEBDAV.Preferences.restPath+'dav_browser_rest.vsp')+'?a=verifyTurtle', $v(el), x);
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
  if (returnName) {
    var returnValue = $v('item_name');
    if ($v('browse_type') === 'res') {
      var pos;
      returnValue = returnValue.replace ('\\', '/');
      pos = returnValue.lastIndexOf ('/');
      if (pos !== -1) {
        returnValue = returnValue.substr (pos+1, returnValue.length);
      }
    }
    opener[returnName].value = returnValue;
  }

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

WEBDAV.progress = {};
WEBDAV.progress.size = 40;
WEBDAV.progress.increment = 100 / WEBDAV.progress.size;

WEBDAV.progressParams = function()
{
  function __parent (o)
  {
    var o = o.parentNode;
    if (!o || (o.id == 'progress_params'))
      return o;

    return __parent(o);
  }

  var frm = document.forms['F1'];
  var params = '';
  for (var N = 0; N < frm.elements.length; N++) {
    if (__parent(frm.elements[N])) {
      var o = frm.elements[N];
      if ((o.name != 'item') && (o.type == 'text' || o.type == 'select-one' || o.type == 'radio' || o.type == 'checkbox')) {
        if (o.type == 'text' || o.type == 'select-one')
          params += '&' + o.name +'=' + encodeURIComponent(o.value);
        if (o.type == 'checkbox')
          params += '&' + o.name +'=' + encodeURIComponent((o.checked)? '1' : '0');
        if (o.type == 'radio' && o.checked)
          params += '&' + o.name +'=' + encodeURIComponent(o.value);
      }
    }
  }
  return params;
}

WEBDAV.progressInit = function()
{
  if ($v('progress_start') == 'Background')
    $('progress_close').click();

  var y = function (data) {
    if (data == '') {
      WEBDAV.progressInitPost();
    } else {
      alert(data);
    }
  }
  var frm = document.forms['F1'];
  var params = 'a=progress&sa=validate' + urlParam('sid') + urlParam('realm') + '&c='+$v('f_command') + WEBDAV.progressParams();
  OAT.AJAX.POST(WEBDAV.httpsLink(WEBDAV.Preferences.restPath+'dav_browser_rest.vsp'), params, y, {async: true});
  return false;
}

WEBDAV.progressInitPost = function()
{
  var x = function (data) {
    try {
      var o = OAT.JSON.parse(data);
      WEBDAV.progress.id = o.id;
    } catch (e) {}

    OAT.Dom.hide('progress_params');
    OAT.Dom.show('progress_div');

    var centerCellName;
    var tableText = "";
    for (var N = 1; N <= WEBDAV.progress.size; N++) {
      if (WEBDAV.progress.max) {
        if (N == (WEBDAV.progress.size/2))
          centerCellName = "progress_" + N;
      }
      tableText += "<td id=\"progress_" + N + "\" width=\"" + WEBDAV.progress.increment + "%\" height=\"20px\" bgcolor=\"blue\" />";
    }
    $("progress_text").innerHTML = "Executed 0 commands from " + WEBDAV.progress.max;
    $("progress_bar").innerHTML = "<table width=\"100%\" border=\"0\" cellspacing=\"0\" cellpadding=\"0\"><tr>" + tableText + "</tr></table>";
    WEBDAV.progress.center = $(centerCellName);
    WEBDAV.progress.timer = setTimeout('WEBDAV.progressCheck()', 500);
    $('progress_start').value = 'Background';
  }

  WEBDAV.progress.timer = null;
  WEBDAV.progress.max = 0;
  var frm = document.forms['F1'];
  var params = 'a=progress&sa=init' + urlParam('sid') + urlParam('realm') + '&c='+$v('f_command') + WEBDAV.progressParams();
  for (var N = 0; N < frm.elements.length; N++) {
    var o = frm.elements[N];
    if (o != null && o.name == 'item') {
      params += '&item=' + encodeURIComponent(o.value);
      WEBDAV.progress.max += 1;
    }
  }
  if (!WEBDAV.progress.max)
    return true;

  OAT.AJAX.POST(WEBDAV.httpsLink(WEBDAV.Preferences.restPath+'dav_browser_rest.vsp'), params, x, {async: true});
  return false;
}

WEBDAV.progressCheck = function()
{
  var x = function (data) {
    var idx = WEBDAV.progress.max;
    var results;
    try {
      var o = OAT.JSON.parse(data);
      idx = o.index;
      results = OAT.JSON.parse(o.data)
    } catch (e) { }

    var td = $('progress_text');
    if (td)
      td.innerHTML = "Executed " + idx + " commands from " + WEBDAV.progress.max;

    var percentage = 100;
    if (WEBDAV.progress.max != 0)
      percentage = Math.round (idx * 100 / WEBDAV.progress.max);

    var percentageText = "";
    if (percentage < 10) {
      percentageText = "&nbsp;" + percentage;
    } else {
      percentageText = percentage;
    }
    WEBDAV.progress.center.innerHTML = "<font color=\"white\">" + percentageText + "%</font>";
    for (var N = 1; N <= WEBDAV.progress.size; N++) {
      var cell = $("progress_" + N);
      if (cell) {
        if (percentage/N < WEBDAV.progress.increment) {
          cell.style.backgroundColor = "blue";
        } else {
          cell.style.backgroundColor = "red";
        }
      }
    }
    // set return values
    if (results) {
      var trs = $('dav_list_body').getElementsByTagName('tr');
      for (var N = 0; N < results.length; N++) {
        if (N < trs.length) {
          var tds = trs[N].getElementsByTagName('td');
          if (tds.length)
            tds[tds.length-1].innerHTML = results[N];
        }
      }
    }

    if (idx && (idx < WEBDAV.progress.max)) {
      setTimeout('WEBDAV.progressCheck()', 500);
    } else {
      WEBDAV.progress.timer = null;
      $('progress_close').value = 'Close';
      OAT.Dom.hide('progress_start');
    }
  }
  OAT.AJAX.POST(WEBDAV.httpsLink(WEBDAV.Preferences.restPath+'dav_browser_rest.vsp'), 'a=progress&sa=check&id='+WEBDAV.progress.id+urlParam('sid')+urlParam('realm'), x);
}

WEBDAV.progressStop = function()
{
  WEBDAV.progress.timer = null;
  OAT.AJAX.POST(WEBDAV.httpsLink(WEBDAV.Preferences.restPath+'dav_browser_rest.vsp'), 'a=progress&sa=stop&id='+WEBDAV.progress.id+urlParam('sid')+urlParam('realm'), null, {async: false});
}

WEBDAV.datePopup = function(objName, format, weekStart, cb) {
  var dateParse = function (dateString, format) {
    var result = null;
    if ((format == 'yyyy-MM-dd') || (format == 'yyyy.MM.dd') || (format == 'yyyy/MM/dd')) {
      var pattern = new RegExp(
          '^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])$');
      if (dateString.match(pattern)) {
        dateString = dateString.replace(/\//g, '-');
        dateString = dateString.replace(/\./g, '-');
        result = dateString.split('-');
        result = [ parseInt(result[0], 10), parseInt(result[1], 10), parseInt(result[2], 10) ];
      }
    }
    else if ((format == 'dd-MM-yyyy') || (format == 'dd.MM.yyyy') || (format == 'dd/MM/yyyy')) {
      var pattern = new RegExp(
          '^(0[1-9]|[12][0-9]|3[01])[- /.](0[1-9]|1[012])[- /.]((?:19|20)[0-9][0-9])$');
      if (dateString.match(pattern)) {
        dateString = dateString.replace(/\//g, '-');
        dateString = dateString.replace(/\./g, '-');
        result = dateString.split('-');
        result = [ parseInt(result[2], 10), parseInt(result[1], 10), parseInt(result[0], 10) ];
      }
    }
    else if ((format == 'MM-dd-yyyy') || (format == 'MM.dd.yyyy') || (format == 'MM/dd/yyyy')) {
      var pattern = new RegExp(
          '^(0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])[- /.]((?:19|20)[0-9][0-9])$');
      if (dateString.match(pattern)) {
        dateString = dateString.replace(/\//g, '-');
        dateString = dateString.replace(/\./g, '-');
        result = dateString.split('-');
        result = [ parseInt(result[2], 10), parseInt(result[0], 10), parseInt(result[1], 10) ];
      }
    }
    return result;
  }

  if (!format)
    format = 'yyyy-MM-dd';

  var obj = $(objName);
  var d = dateParse(obj.value, format);
  var c = new OAT.Calendar({popup: true});
  if (weekStart != undefined)
    c.weekStartIndex = weekStart;
  var coords = OAT.Dom.position(obj);
  if (isNaN(coords[0]))
    coords = [ 0, 0 ];

  var x = function(date) {
    var dateFormat = function(date, format) {
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

    obj.value = dateFormat(date, format);
    if (cb)
      cb();
  }
  c.show(coords[0], coords[1] + 30, x, d);
}

WEBDAV.getFileName = function (obj)
{
  var davName = $('dav_name');
  if (!davName) {
    return;
  }
  var S = obj.value;
  var N;
  if (S.lastIndexOf('\\') > 0) {
    N = S.lastIndexOf('\\') + 1;
  }
  else {
    N = S.lastIndexOf('/') + 1;
  }
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
      if (N == -1) {
        S = S + '.rdf';
      }
    }
  }
  davName.value = S;
  WEBDAV.mimeTypeByExt(S);
}

WEBDAV.mimeTypeByExt = function (name)
{
  if ($("dav_mime")) {
    if (!name) {
      name = $("dav_name").value;
    }
    var x = function (txt) {
      if (txt != "")
      {
        var davMime = $("dav_mime");
        if (davMime) {
          davMime.value = txt;
        }
      }
    }
    OAT.AJAX.POST(WEBDAV.httpsLink(WEBDAV.Preferences.restPath+'dav_browser_rest.vsp'), 'a=mimeTypeByExt&fileName='+name, x, {type:OAT.AJAX.TYPE_TEXT, onstart:function(){}, onerror:function(){}});
  }
}

WEBDAV.nameByMimeType = function ()
{
  var dav_name = $("dav_name");
  var dav_mime = $("dav_mime");
  if (dav_name && dav_mime) {
    var x = function (data) {
      var o = OAT.JSON.parse(data);
      if (o.length)
      {
        var dav_name = $("dav_name");
        var namesDiv = $('namesDiv');
        if (namesDiv)
          OAT.Dom.unlink(namesDiv);

        var content =
          '<div style="padding: 0.5em;">' +
          '  <table style="width: 100%;">' +
          '    <tr>' +
          '      <td style="padding-left: 30px;"><ul>';
        var nameLength = 0;
        for (var i = 0; i < o.length; i++) {
          content += '<label><input type="checkbox" name="dav_names_' + i + '" id="dav_names_' + i + '" value="' + o[i] + '" onclick="javascript: WEBDAV.nameByMimeTypeSelect(this); namesDialog.hide(); " /><b>' + o[i] + '</b></label></br>';
          if (o[i].length > nameLength) {
            nameLength = o[i].length;
          }
        }
        content +=
          '      </ul></td>' +
          '    </tr>' +
          '    <tr><td align="center" colspan="2"><hr /><td></tr>' +
          '    <tr>' +
          '      <td align="center">' +
          '        <input type="button" value="Close" onclick="javascript: namesDialog.hide(); return false;" />' +
          '      <td>' +
          '    </tr>' +
          '  </table>' +
          '</div>'
        ;
        namesDiv = OAT.Dom.create('div', {height: 125 + (o.length * 14) + 'px', overflow: 'hidden'});
        namesDiv.id = 'namesDiv';
        namesDiv.innerHTML = content;
        namesDialog = new OAT.Dialog('Select new file name related to mime type:', namesDiv, {width: 150 + Math.min((nameLength * 10), 400), buttons: 0, resize: 0, modal: 1});
        namesDialog.cancel = namesDialog.hide;
        namesDialog.show();
      }
    }
    OAT.AJAX.POST(WEBDAV.httpsLink(WEBDAV.Preferences.restPath+'dav_browser_rest.vsp'), 'a=nameByMimeType&fileName='+dav_name.value+'&mimeType='+dav_mime.value, x, {type:OAT.AJAX.TYPE_TEXT, onstart:function(){}, onerror:function(){}});
  }
}

WEBDAV.nameByMimeTypeSelect = function (obj)
{
  var dav_name = $("dav_name");
  if (dav_name) {
    dav_name.value = obj.value;
  }
}

