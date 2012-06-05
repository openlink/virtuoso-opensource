/*
 *  $Id$
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
function setFooter() {
  if ($('dav_list')) {
    var wDims = OAT.Dom.getViewport()
    var hDims = OAT.Dom.getWH('FT')
    var cPos = OAT.Dom.position('dav_list')
    $('dav_list').style.height = (wDims[1] - hDims[1] - cPos[1] - 20) + 'px';
  }
}

function destinationChange(obj, changes) {
  function destinationChangeInternal(actions) {
    if (actions.hide) {
      var a = actions.hide;
      for ( var i = 0; i < a.length; i++) {
        var o = $(a[i])
        if (o) {
          OAT.Dom.hide(o);
        }
      }
    }
    if (actions.show) {
      var a = actions.show;
      for ( var i = 0; i < a.length; i++) {
        var o = $(a[i])
        if (o) {
          OAT.Dom.show(o);
        }
      }
    }
    if (actions.clear) {
      var a = actions.clear;
      for ( var i = 0; i < a.length; i++) {
        var o = $(a[i])
        if (o && o.value) {
          o.value = '';
        }
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

function urlParam(fldName) {
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

function vspxPost(fButton, fName, fValue, f2Name, f2Value, f3Name, f3Value) {
  if (fName)
    createHidden('F1', fName, fValue);
  if (f2Name)
    createHidden('F1', f2Name, f2Value);
  if (f3Name)
    createHidden('F1', f3Name, f3Value);
  doPost('F1', fButton);
}

function odsPost(obj, fields, button) {
  var form = getParent (obj, 'form');
  var formName = form.name;
  for (var i = 0; i < fields.length; i += 2)
    createHidden(formName, fields[i], fields[i+1]);

  if (button) {
    doPost(formName, button);
  } else {
    form.submit();
  }
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
  for (var i = 0; i < objForm.elements.length; i++)
  {
    var o = objForm.elements[i];
    if (o != null && o.type == "checkbox" && !o.disabled && o.name.indexOf (prefix) == 0)
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

function selectCheck (obj, prefix)
{
  coloriseRow(getParent(obj, 'tr'), obj.checked);
  enableToolbars(obj.form, prefix, document);
}

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
  enableElement('tb_properties', 'tb_properties_gray', oCount>1, doc);
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
  document.F1.dav_name.value = S;
}

function chkbx(bx1, bx2)
{
  if (bx1.checked == true && bx2.checked == true)
    bx2.checked = false;
}

function updateLabel(value)
{
  hideLabel(4, 14);
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
}

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
          OAT.Dom.removeClass(divTab, "activeTab");
        }
      }
    }
  }

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

function deleteConfirm() {
  return confirm('Are you sure you want to delete the chosen record?');
}

function deprecateConfirm() {
  return confirm('Are you sure you want to deprecate the chosen record?');
}

function confirmAction(confirmMsq, form, txt, selectionMsq) {
  if (anySelected (form, txt, selectionMsq))
    return confirm(confirmMsq);
  return false;
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

function coloriseRow(obj, checked) {
  if (checked)
    OAT.Dom.addClass(obj, 'selected');
  else
    OAT.Dom.removeClass(obj, 'selected');
}

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

function rowSelect(obj)
{
  var s2 = (obj.name).replace('b1', 's2');
  var s1 = (obj.name).replace('b1', 's1');

  var srcForm = window.document.F1;
  var dstForm = window.opener.document.F1;

  var submitMode = false;
  if (srcForm.elements['src'] && (srcForm.elements['src'].value.indexOf('s') != -1)) {
      submitMode = true;
    if (dstForm && dstForm.elements['submitting'])
        return false;
  }
  var closeMode = true;
  var singleMode = true;
  if (srcForm.elements['dst']) {
    if (srcForm.elements['dst'].value.indexOf('c') == -1)
      closeMode = false;
    if (srcForm.elements['dst'].value.indexOf('s') == -1)
      singleMode = false;
  }

  var myRe = /^(\w+):(\w+);(.*)?/;
  var params = srcForm.elements['params'].value;
  var myArray;
  if (dstForm) {
  while(true) {
    myArray = myRe.exec(params);
    if (myArray == undefined)
      break;
      if (myArray.length > 2) {
        var fld = dstForm.elements[myArray[1]];
        if (fld) {
          if (myArray[2] == 's1')
            rowSelectValue(fld, srcForm.elements[s1], singleMode, submitMode);
          if (myArray[2] == 's2')
            rowSelectValue(fld, srcForm.elements[s2], singleMode, submitMode);
        }
        }
    if (myArray.length < 4)
      break;
    params = '' + myArray[3];
  }
  }
  if (submitMode) {
    window.opener.createHidden('F1', 'submitting', 'yes');
    dstForm.submit();
  }
  if (closeMode)
    window.close();
}

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
        if ((aSrc[i] != '') && (dstField.value.indexOf(aSrc[i]+',') == -1))
          dstField.value += ODRIVE.trim(aSrc[i], ',') + ',';
      }
    }
    dstField.value = ODRIVE.trim(dstField.value, ',');
  }
  if (dstField.onchange)
    dstField.onchange();
}

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
          form.s1.value += obj.value+',';
      } else {
        form.s1.value = (form.s1.value).replace(obj.value+',', '');
      }
    }
  }
}

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

// Hiddens functions
function createHidden(frm_name, fld_name, fld_value)
{
  return createHidden2(document, frm_name, fld_name, fld_value);
}

function createHidden2(doc, frm_name, fld_name, fld_value)
{
  var hidden;

  if (doc.forms[frm_name])
  {
    hidden = doc.forms[frm_name].elements[fld_name];
    if (hidden == null)
    {
      hidden = doc.createElement("input");
      hidden.setAttribute("type", "hidden");
      hidden.setAttribute("name", fld_name);
      hidden.setAttribute("id", fld_name);
      doc.forms[frm_name].appendChild(hidden);
    }
    hidden.value = fld_value;

    return hidden;
  }
}

function getObject(id, doc)
{
  if (!doc) {doc = document;}
  return doc.getElementById(id);
}

showRow = (navigator.appName.indexOf("Internet Explorer") != -1) ? "block" : "table-row";

function showTableRow(cell)
{
  var c = getObject(cell);
  if ((c) && (c.style.display == "none"))
    c.style.display = showRow;
}

function showCell(cell)
{
  var c = getObject(cell);
  if ((c) && (c.style.display == "none"))
    c.style.display = "";
}

function hideCell(cell)
{
  var c = getObject(cell);
  if ((c) && (c.style.display != "none"))
    c.style.display = "none";
}

function toggleDavRows()
{
  if (!document.forms['F1'].elements['dav_destination'])
    return;

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

    showCell('dav_source_2');
      showCell('label_dav');
      hideCell('label_dav_rdf');
      showCell('dav_name');
      hideCell('dav_name_rdf');
    }
  else if (document.forms['F1'].elements['dav_destination'][1].checked == '1')
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
    if ($('dav_content_plain'))
      showCell('davRow_mime');

    hideCell('dav_source_2');
    if (document.forms['F1'].elements['dav_source'] && (document.forms['F1'].elements['dav_source'][2].checked == '1'))
        document.forms['F1'].elements['dav_source'][0].checked = '1';

      hideCell('label_dav');
      showCell('label_dav_rdf');
      hideCell('dav_name');
      showCell('dav_name_rdf');
    }
  toggleDavSource();
}

function toggleDavSource()
{
  if (!document.forms['F1'].elements['dav_source'])
    return;

  if (document.forms['F1'].elements['dav_source'][0].checked == '1')
  {
    $('dav_file_label').innerHTML = 'File';
    showCell('dav_file');
    hideCell('dav_url');
    hideCell('dav_rdf');
  }
  else if (document.forms['F1'].elements['dav_source'][1].checked == '1')
  {
    $('dav_file_label').innerHTML = 'URL';
    hideCell('dav_file');
    showCell('dav_url');
    hideCell('dav_rdf');
  }
  else if (document.forms['F1'].elements['dav_source'][2].checked == '1')
  {
    $('dav_file_label').innerHTML = 'Quad Store Named Graph IRI';
    hideCell('dav_file');
    hideCell('dav_url');
    showCell('dav_rdf');
  }
}

var ODRIVE = new Object();

ODRIVE.forms = new Object();
ODRIVE.forms['properties'] = {params: {items: true}, width: '900', height: '630', postActions:['ODRIVE.formSubmit()', 'ODRIVE.resetToolbars()']};
ODRIVE.forms['edit'] = {params: {items: true}, height: '440', postActions:['ODRIVE.formSubmit()']};
ODRIVE.forms['view'] = {params: {items: true}, height: '440'};
ODRIVE.forms['copy'] = {params: {items: true}, height: '330', postActions:['ODRIVE.formSubmit()', 'ODRIVE.resetToolbars()']};
ODRIVE.forms['move'] = {params: {items: true}, height: '330', postActions:['ODRIVE.formSubmit()', 'ODRIVE.resetToolbars()']};
ODRIVE.forms['tags'] = {params: {items: true}, height: '350', postActions:['ODRIVE.formSubmit()', 'ODRIVE.resetToolbars()']};
ODRIVE.forms['rename'] = {params: {items: true}, height: '160', postActions:['ODRIVE.formSubmit()', 'ODRIVE.resetToolbars()']};
ODRIVE.forms['delete'] = {params: {items: true}, height: '290', postActions:['ODRIVE.formSubmit()', 'ODRIVE.resetToolbars()']};

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

ODRIVE.readField = function (fld, doc)
{
  var v;
  if (!doc) {doc = document;}
  if (doc.forms[0])
  {
    v = doc.forms[0].elements[fld];
    if (v)
    {
      v = v.value;
    }
  }
  return v;
}

ODRIVE.createParam = function (fld, doc)
{
  var S = '';
  var v = ODRIVE.readField(fld, doc);
  if (v)
    S = '&'+fld+'='+ encodeURIComponent(v);
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
  var cmd = $('_cmd');
  if (cmd)
   cmd.value = '';

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
    formDialog = new OAT.Dialog('', formDiv, {buttons: 0, resize: 0, modal: 1, onhide: function(){return false;}});
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
  if (form) {
    var actions = form.postActions;
    if (actions) {
      for (var i = 0; i < actions.length; i++)
        eval(actions[i]);
      }
    }
  }

ODRIVE.searchRowAction = function (No)
{
  var tbody = $('search_tbody');
  if (tbody)
  {
    OAT.Dom.unlink('search_tr_'+No);
      ODRIVE.searchColumnHide(1);
      ODRIVE.searchColumnHide(2);
    var No = parseInt($v('search_no'));
    for (var N = 0; N < No; N++)
    {
      if ($('search_tr_'+N))
        return;
    }
    OAT.Dom.show('search_tr_no');
  }
}

ODRIVE.searchRowCreate = function (values)
{
  var tbody = $('search_tbody');
  if (tbody) {
    if (!$('search_no')) {
    	var fld = OAT.Dom.create("input");
      fld.type = 'hidden';
      fld.name = 'search_no';
      fld.id = fld.name;
      fld.value = '0';
      tbody.appendChild(fld);
    }
    var No = parseInt($v('search_no'));
    OAT.Dom.hide ('search_tr_no');

    var tr = OAT.Dom.create('tr');
    tr.id = 'search_tr_' + No;
      tbody.appendChild(tr);
    if (!values)
      values = new Object();

    var td = OAT.Dom.create('td');
    td.id = 'search_td_0_' + No;
    tr.appendChild(td);
    ODRIVE.searchColumnCreate(No, 0, values['field_0']);

    var td = OAT.Dom.create('td');
    td.id = 'search_td_1_' + No;
    if (!values['field_1'])
      td.style.display = 'none';
    tr.appendChild(td);
    if (values['field_1'])
      ODRIVE.searchColumnCreate(No, 1, values['field_1']);

    var td = OAT.Dom.create('td');
    td.id = 'search_td_2_' + No;
    if (!values['field_2'])
      td.style.display = 'none';
    tr.appendChild(td);
    if (values['field_2'])
      ODRIVE.searchColumnCreate(No, 2, values['field_2']);

    var td = OAT.Dom.create('td');
    td.id = 'search_td_3_' + No;
    tr.appendChild(td);
    if (values['field_3'])
      ODRIVE.searchColumnCreate(No, 3, values['field_3']);

    var td = OAT.Dom.create('td');
    td.id = 'search_td_4_' + No;
    tr.appendChild(td);
    if (values['field_4'])
      ODRIVE.searchColumnCreate(No, 4, values['field_4']);

    var td = OAT.Dom.create('td');
    td.id = 'search_td_5_' + No;
    td.style['whiteSpace'] = 'nowrap';
    var span = OAT.Dom.create('span');
    span.onclick = function (){ODRIVE.searchRowAction(No)};
    OAT.Dom.addClass(span, 'button');
    OAT.Dom.addClass(span, 'pointer');
    var img = OAT.Dom.image('/ods/images/icons/trash_16.png');
    OAT.Dom.addClass(img, 'button');
    span.appendChild(img);
    span.appendChild(OAT.Dom.text(' Delete'));
    td.appendChild(span);
    tr.appendChild(td);

    $('search_no').value = No + 1;

  }
}

ODRIVE.searchColumnsInit = function (No, columnNo)
  {
  var tr = $('search_tr_' + No);
  if (tr) {
    var tds = tr.getElementsByTagName("td");
    for (var i = columnNo; i < tds.length-1; i++)
      tds[i].innerHTML = '';

    if (columnNo == 0)
      ODRIVE.searchColumnCreate(No, columnNo)
    if (columnNo <= 1)
      ODRIVE.searchColumnHide(1)
    if (columnNo <= 2)
      ODRIVE.searchColumnHide(2)
  }
}

ODRIVE.searchColumnCreate = function (No, columnNo, columnValue)
{
  var tr = $('search_tr_' + No);
  if (tr)
  {
    var td = $('search_td_' + columnNo + '_' + No);
    if (td) {
      var predicate = ODRIVE.searchGetPredicate(No);
      if (columnNo == 0) {
        var fld = OAT.Dom.create('select');
        fld.id = 'search_field_' + columnNo + '_' + No;
        fld.name = fld.id;
        fld.style.width = '95%';
        OAT.Dom.option('', '', fld);
        for (var i = 0; i < ODRIVE.searchPredicates.length; i = i + 2)
        {
          if (ODRIVE.searchPredicates[i+1][0] == 1)
            OAT.Dom.option(ODRIVE.searchPredicates[i+1][1], ODRIVE.searchPredicates[i], fld);
        }
        if (columnValue)
          fld.value = columnValue;
        fld.onchange = function(){ODRIVE.searchColumnChange(this)};
        td.appendChild(fld);
      }
      else if (columnNo == 1)
      {
        if (predicate && (predicate[2] == 'rdfSchema')) {
          var fld = OAT.Dom.create('select');
          fld.id = 'search_field_' + columnNo + '_' + No;
          fld.name = fld.id;
          fld.style.width = '95%';
          OAT.Dom.option('', '', fld);
          td.appendChild(fld);
          ODRIVE.searchColumnShow(1);

          var x = function(data) {
            var o = OAT.JSON.parse(data);
            for (var i = 0; i < o.length; i = i + 2)
              OAT.Dom.option(o[i+1], o[i], fld);

            if (columnValue)
              fld.value = columnValue;
            fld.onchange = function(){ODRIVE.searchColumnChange(this)};
          }
          var s = 'ajax.vsp?a=search&sa=schemas';
          OAT.AJAX.GET(s, '', x, {async: false});
        }
      }
      else if (columnNo == 2)
      {
        if (predicate && (predicate[3] == 'davProperties')) {
          TBL.createCell40(td, 'search', 'search_field_'+columnNo+'_'+No, No, {value: columnValue})
          ODRIVE.searchColumnShow(2);
        }
        else if (predicate && (predicate[3] == 'rdfProperties'))
        {
          var fldSchema = $('search_field_1_' + No)
          if (fldSchema && (fldSchema.value != '')) {
            var fld = OAT.Dom.create('select');
            fld.id = 'search_field_' + columnNo + '_' + No;
            fld.name = fld.id;
            fld.style.width = '95%';
            OAT.Dom.option('', '', fld);
            td.appendChild(fld);
            ODRIVE.searchColumnShow(2);

            var x = function(data) {
              var o = OAT.JSON.parse(data);
              for (var i = 0; i < o.length; i = i + 2)
                OAT.Dom.option(o[i+1], o[i], fld);

              if (columnValue)
                fld.value = columnValue;
            }
            var s = 'ajax.vsp?a=search&sa=schemaProperties&schema='+fldSchema.value;
            OAT.AJAX.GET(s, '', x);
          }
        }
      }
      else if (columnNo == 3)
      {
        var fld = OAT.Dom.create('select');
        fld.id = 'search_field_' + columnNo + '_' + No;
        fld.name = fld.id;
        fld.style.width = '95%';
        OAT.Dom.option('', '', fld);
        var predicateType = predicate[4];
        for (var i = 0; i < ODRIVE.searchCompares.length; i = i + 2) {
          var compareTypes = ODRIVE.searchCompares[i+1][1];
          for (var j = 0; j < compareTypes.length; j++)
          {
            if (compareTypes[j] == predicateType)
              OAT.Dom.option(ODRIVE.searchCompares[i+1][0], ODRIVE.searchCompares[i], fld);
          }
        }
        if (columnValue)
          fld.value = columnValue;
        td.appendChild(fld);
      }
      else if (columnNo == 4)
      {
    		var properties = OAT.Dom.create("input");
    		var fld = OAT.Dom.create("input");
    		fld.type = 'text';
        fld.id = 'search_field_' + columnNo + '_' + No;
        fld.name = fld.id;
        fld.style.width = '93%';
        if (columnValue)
          fld.value = columnValue;
        td.appendChild(fld);
        for (var i = 0; i < predicate[5].length; i = i + 2) {
          if (predicate[5][i] == 'size') {
    		    fld['size'] = predicate[5][i+1];
            fld.style.width = null;
          }
          else if (predicate[5][i] == 'onclick')
          {
			      OAT.Event.attach(fld, "click", new Function((predicate[5][i+1]).replace(/-FIELD-/g, fld.id)));
          }
          else if (predicate[5][i] == 'button')
          {
    		    var span = OAT.Dom.create("span");
    		    span.innerHTML = ' ' + (predicate[5][i+1]).replace(/-FIELD-/g, fld.id);
            td.appendChild(span);
          }
        }
      }
    }
  }
}

ODRIVE.searchColumnShow = function (columnNo)
{
  var No = parseInt($v('search_no'));
  for (var i = 0; i <= No; i++)
  {
    var td = $('search_td_' + columnNo + '_' + i);
    if (td)
      OAT.Dom.show(td);
  }
  OAT.Dom.show('search_th_' + columnNo);
}

ODRIVE.searchColumnHideCheck = function (columnNo)
{
  var No = parseInt($v('search_no'));
  for (var i = 0; i <= No; i++)
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
    var No = parseInt($v('search_no'));
    for (var i = 0; i <= No; i++)
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
  var No = parts[3];
  var predicate = ODRIVE.searchGetPredicate(No);
  if (columnNo == 0)
  {
    ODRIVE.searchColumnsInit(No, 1);
    if (obj.value == '') {return;}
    if (predicate && (predicate[2]))
    {
      ODRIVE.searchColumnCreate(No, 1)
      return;
    }
  }
  if (columnNo == 1)
  {
    ODRIVE.searchColumnsInit(No, 2);
    if (obj.value == '') {return;}
  }
  if (predicate)
  {
    if (predicate[3])
    {
      ODRIVE.searchColumnCreate(No, 2)
    }
    ODRIVE.searchColumnCreate(No, 3)
    ODRIVE.searchColumnCreate(No, 4)
  }
}

ODRIVE.searchGetPredicate = function (No)
{
  var fld = $('search_field_0_' + No)
  if (fld)
  {
    for (var i = 0; i < ODRIVE.searchPredicates.length; i = i + 2)
    {
      if (ODRIVE.searchPredicates[i] == fld.value)
      {
        return ODRIVE.searchPredicates[i+1];
      }
    }
  }
  return null;
}

ODRIVE.searchGetCompares = function (predicate)
{
  if (predicate) {}
  return null;
}

ODRIVE.davFolderSelect = function (fld)
{
	/* load stylesheets */
	OAT.Style.include("grid.css");
	OAT.Style.include("webdav.css");

  var options = {
    mode: 'browser',
                  onConfirmClick: function(path) {$(fld).value = '/DAV' + path;}
                };
  OAT.WebDav.options.foldersOnly = true;
  OAT.WebDav.open(options);
}

ODRIVE.davFileSelect = function (fld)
{
	/* load stylesheets */
	OAT.Style.include("grid.css");
	OAT.Style.include("webdav.css");

  var options = {
    mode: 'browser',
    onConfirmClick: function(path, fname) {$(fld).value = '/DAV' + path + fname;}
                };
  OAT.WebDav.options.foldersOnly = false;
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

ODRIVE.aboutDialog = function ()
{
  var aboutDiv = $('aboutDiv');
  if (aboutDiv)
    OAT.Dom.unlink(aboutDiv);

  aboutDiv = OAT.Dom.create('div', {height: '160px', overflow: 'hidden'});
  aboutDiv.id = 'aboutDiv';
  aboutDialog = new OAT.Dialog('About ODS Briefcase', aboutDiv, {width:445, buttons: 0, resize:0, modal:1});
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
  OAT.AJAX.POST("ajax.vsp", "a=about", x, {type:OAT.AJAX.TYPE_TEXT, onstart:function(){}, onerror:function(){}});
}

ODRIVE.validateInputs = function (fld)
{
  var retValue = true;
  var form = fld.form;
  for (i = 0; i < form.elements.length; i++)
  {
    var fld = form.elements[i];
    if (!fld.readOnly && OAT.Dom.isClass(fld, '_validate_'))
    {
      retValue = ODRIVE.validateField(fld);
      if (!retValue)
        return retValue;
    }
  }
  return retValue;
}

ODRIVE.toggleEditor = function ()
{
  if ($v('dav_mime') == 'text/html') {
    OAT.Dom.hide('dav_plain');
    OAT.Dom.show('dav_html');
    oEditor.setData($v('dav_content_plain'));
  } else {
    OAT.Dom.show('dav_plain');
    OAT.Dom.hide('dav_html');
    oEditor.updateElement();
    $('dav_content_plain').value = $v('dav_content_html');
  }
}

ODRIVE.updateRdfGraph = function ()
{
  if (
      ($v('dav_rdfSink_rdfGraph') == '') ||
      ($v('dav_rdfSink_rdfGraph') == ($v('rdfGraph_prefix')+$v('dav_name_save')+'#this'))
     )
    $('dav_rdfSink_rdfGraph').value = $v('rdfGraph_prefix') + $v('dav_name') + '#this';

  if (
      ($v('dav_IMAP_graph') == '') ||
      ($v('dav_IMAP_graph') == ($v('rdfGraph_prefix')+$v('dav_name_save')+'#this'))
     )
    $('dav_IMAP_graph').value = $v('rdfGraph_prefix') + $v('dav_name') + '#this';

  if (
      ($v('dav_GDrive_graph') == '') ||
      ($v('dav_GDrive_graph') == ($v('rdfGraph_prefix')+$v('dav_name_save')+'#this'))
     )
    $('dav_GDrive_graph').value = $v('rdfGraph_prefix') + $v('dav_name') + '#this';

  if (
      ($v('dav_Dropbox_graph') == '') ||
      ($v('dav_Dropbox_graph') == ($v('rdfGraph_prefix')+$v('dav_name_save')+'#this'))
     )
    $('dav_Dropbox_graph').value = $v('rdfGraph_prefix') + $v('dav_name') + '#this';

  if (
      ($v('dav_SkyDrive_graph') == '') ||
      ($v('dav_SkyDrive_graph') == ($v('rdfGraph_prefix')+$v('dav_name_save')+'#this'))
     )
    $('dav_SkyDrive_graph').value = $v('rdfGraph_prefix') + $v('dav_name') + '#this';

  $('dav_name_save').value = $v('dav_name');
}

ODRIVE.oauthParams = function (json, display_name, email)
{
  try {
    params = OAT.JSON.deserialize(unescape(json));
  } catch (e) { params = null; }
  var fld = createHidden('F1', 'dav_GDrive_JSON', null);
  if (!params || params.error) {
    alert ('Bad authentication!');
    fld.value = '';
  } else {
    var d = new Date();
    params.access_timestamp = d.format('Y-m-d H:i');
    fld.value = OAT.JSON.serialize(params);
    // $('dav_GDrive_authentication').innerHTML = 'Authenticated';
    createHidden('F1', 'dav_GDrive_display_name', display_name);
    createHidden('F1', 'dav_GDrive_email', email);

    OAT.Dom.show('tr_dav_GDrive_display_name');
    $('td_dav_GDrive_display_name').innerHTML = display_name;
    OAT.Dom.show('tr_dav_GDrive_email');
    $('td_dav_GDrive_email').innerHTML = email;
    $('dav_GDrive_authenticate').value = 'Re-Authenticate';
  }
}

ODRIVE.dropboxParams = function (sid, display_name, email)
{
  createHidden('F1', 'dav_Dropbox_authentication', 'Yes');
  createHidden('F1', 'dav_Dropbox_sid', sid);
  createHidden('F1', 'dav_Dropbox_display_name', display_name);
  createHidden('F1', 'dav_Dropbox_email', email);

  OAT.Dom.show('tr_dav_Dropbox_display_name');
  $('td_dav_Dropbox_display_name').innerHTML = display_name;
  OAT.Dom.show('tr_dav_Dropbox_email');
  $('td_dav_Dropbox_email').innerHTML = email;
  $('dav_Dropbox_authenticate').value = 'Re-Authenticate';
}

ODRIVE.skydriveParams = function (json, display_name)
{
  try {
    params = OAT.JSON.deserialize(unescape(json));
  } catch (e) { params = null; }
  var fld = createHidden('F1', 'dav_SkyDrive_JSON', null);
  if (!params || params.error) {
    alert ('Bad authentication!');
    fld.value = '';
  } else {
    var d = new Date();
    params.access_timestamp = d.format('Y-m-d H:i');
    fld.value = OAT.JSON.serialize(params);
    createHidden('F1', 'dav_SkyDrive_display_name', display_name);

    OAT.Dom.show('tr_dav_SkyDrive_display_name');
    $('td_dav_SkyDrive_display_name').innerHTML = display_name;
    $('dav_SkyDrive_authenticate').value = 'Re-Authenticate';
  }
}