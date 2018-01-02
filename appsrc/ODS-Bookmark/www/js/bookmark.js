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
function setFooter() {
  if ($('pane_main')) {
    var wDims = OAT.Dom.getViewport()
    var hDims = OAT.Dom.getWH('FT')
    var cPos = OAT.Dom.position('pane_main')
    $('pane_main').style.height = (wDims[1] - hDims[1] - cPos[1] - 20) + 'px';
  }
}

function myPost(frm_name, fld_name, fld_value)
{
  createHidden(frm_name, fld_name, fld_value);
  document.forms[frm_name].submit();
}

function myTags(fld_value)
{
  createHidden('F1', 'tag', fld_value);
  doPost ('F1', 'pt_tags');
}

function vspxPost(fButton, fName, fValue, f2Name, f2Value, f3Name, f3Value)
{
  if (fName)
  createHidden('F1', fName, fValue);
  if (f2Name)
  createHidden('F1', f2Name, f2Value);
  if (f3Name)
    createHidden('F1', f3Name, f3Value);
  doPost ('F1', fButton);
}

function toolbarPost(value)
{
  document.F1.tbHidden.value = value;
  doPost ('F1', 'toolbar');
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

function submitEnter(myForm, myButton, e) {
  var keycode;
  if (window.event)
    keycode = window.event.keyCode;
  else
    if (e)
      keycode = e.which;
    else
      return true;
  if (keycode == 13) {
    if (myButton != '') {
      doPost (myForm, myButton);
      return false;
    } else
    document.forms[myForm].submit();
  }
  return true;
}

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

function getObject(id, doc)
{
  if (!doc) {doc = document;}
  return doc.getElementById(id);
}

function confirmAction(confirmMsq, form, txt, selectionMsq)
{
  if (anySelected (form, txt, selectionMsq))
    return confirm(confirmMsq);
  return false;
}

function selectCheck (obj, prefix)
{
  coloriseRow(getParent(obj, 'tr'), obj.checked);
  enableToolbars(obj.form, prefix, parent.document);
}

function enableToolbars (objForm, prefix, doc)
{
  var oCount = 0;
  var tCount = 0;
  var mCount = 0;
  for (var i = 0; i < objForm.elements.length; i++)
  {
    var o = objForm.elements[i];
    if (o != null && o.type == 'checkbox' && !o.disabled && o.name.indexOf (prefix) != -1 && o.checked)
    {
      oCount += 1;
      if (o.value.indexOf ('b#') != -1)
        tCount += 1;
      if ((o.value.indexOf ('b#') != -1) || (o.value.indexOf ('f#') != -1))
        mCount += 1;
    }
  }
  if (tCount != mCount)
    tCount = 0;
  enableElement('tbTag', 'tbTag_gray', tCount>0, doc);
  enableElement('tbMove', 'tbMove_gray', mCount>0, doc);
  enableElement('tbSharing', 'tbSharing_gray', oCount>0, doc);
  enableElement('tbDelete', 'tbDelete_gray', oCount>0, doc);
}

function getParent (o, tag)
{
  var o = o.parentNode;
  if (o.tagName.toLowerCase() == tag)
    return o;
  return getParent(o, tag);
}

function enableElement (id, id_gray, flag, doc)
{
  if (!doc) {doc = document;}
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

function selectAllCheckboxes (obj, prefix) {
  var objForm = obj.form;
  for (var i = 0; i < objForm.elements.length; i++) {
    var o = objForm.elements[i];
    if (o != null && o.type == "checkbox" && !o.disabled && o.name.indexOf (prefix) != -1)
    {
      o.checked = (obj.value == 'Select All');
      coloriseRow(getParent(o, 'tr'), o.checked);
    }
  }
  obj.value = (obj.value == 'Select All')? 'Unselect All': 'Select All';
  selectCheck (obj, prefix);
  obj.focus();
}

function anySelected (form, txt, selectionMsq) {
  if ((form != null) && (txt != null)) {
    for (var i = 0; i < form.elements.length; i++) {
      var obj = form.elements[i];
      if (obj != null && obj.type == "checkbox" && obj.name.indexOf (txt) != -1 && obj.checked)
        return true;
    }
    if (selectionMsq != null)
      alert(selectionMsq);
    return false;
  }
  return true;
}

function changeState (obj, fld_name) {
  if (obj) {
    if (obj.type == "checkbox" && obj.checked) {
    document.F1.elements[fld_name].disabled = false;
  } else {
    document.F1.elements[fld_name].disabled = true;
  }
  } else {
    document.F1.elements[fld_name].disabled = false;
  }
}

function updateGrants(objName)
{
  var frm = document.forms['F1'];
  for (var i = 0; i < frm.elements.length; i = i + 1) {
    var obj = frm.elements[i];
    if (obj != null && obj.type == "checkbox" && obj.name == objName) {
      if (obj.checked) {
        if (frm.share.value.indexOf(obj.value+',') == -1)
          frm.share.value = frm.share.value + obj.value+',';
      } else {
        frm.share.value = (frm.share.value).replace(obj.value+',', '');
      }
    }
  }
}

function coloriseTable(id) {
  var table = $(id);
  if (table) {
      var rows = table.getElementsByTagName("tr");
      for (i = 0; i < rows.length; i++) {
        rows[i].className = rows[i].className + " tr_" + (i % 2);;
      }
    }
  }

function coloriseRow(obj, checked) {
  obj.className = (obj.className).replace('tr_select', '');
  if (checked)
    obj.className = obj.className + ' ' + 'tr_select';
}

function clickNode(obj) {
  var nodes = obj.parentNode.childNodes;
  for (var i=0; i<nodes.length; i++) {
    var node = nodes[i];
    if (node.tagName == 'A')
      if (node.innerHTML != null) {
        if (node.innerHTML.indexOf('<IMG') == 0)
           return node.onclick();
        if (node.innerHTML.indexOf('<img') == 0)
           return node.onclick();
      }
  }
}

function clickNode2(obj) {
  var nodes = obj.parentNode.childNodes;
  for (var i=0; i<nodes.length; i++) {
    var node = nodes[i];
    if (node.tagName == 'A')
      if (node.onclick)
        return node.onclick();
  }
}

function showTag(tag) {
  createHidden2(parent.document, 'F1', 'tag', tag);
  parent.document.forms['F1'].submit();
}

function showTab(tabs, tabsCount, tabNo)
{
  if ($(tabs))
  {
    for (var i = 0; i < tabsCount; i++)
    {
      var l = $(tabs+'_tab_'+i);      // tab labels
      var c = $(tabs+'_content_'+i);  // tab contents
      if (i == tabNo)
      {
        if ($('tabNo'))
          $('tabNo').value = tabNo;
        if (c) {
          OAT.Dom.show(c);
      }
        OAT.Dom.addClass(l, "activeTab");
        l.blur();
      } else {
        if (c)
          OAT.Dom.hide(c);
        OAT.Dom.removeClass(l, "activeTab");
  }
}
  }
}

function windowShow(sPage, sPageName, width, height) {
	if (width == null)
    width = 700;
	if (height == null)
		height = 500;
  if (sPage.indexOf('form=') == -1)
    sPage += '&form=F1';
  if (sPage.indexOf('sid=') == -1)
    sPage += urlParam('sid');
  if (sPage.indexOf('realm=') == -1)
    sPage += urlParam('realm');
  win = window.open(sPage, sPageName, "width="+width+",height="+height+",top=100,left=100,status=yes,toolbar=no,menubar=no,scrollbars=yes,resizable=yes");
  win.window.focus();
}

function rowSelected(tr)
{
  var cbInput;
  var s1Input;
  var s2Input;
  var inputs = tr.getElementsByTagName('input');
  for (var i = 0; i < inputs.length; i++) {
    if (inputs[i].name == 'cb_item')
      cbInput = inputs[i];
    if (inputs[i].name == 's1_item')
      s1Input = inputs[i];
    if (inputs[i].name == 's2_item')
      s2Input = inputs[i];
  }
  if (cbInput) {
    cbInput.checked = !cbInput.checked;
    updateChecked(cbInput, cbInput.name);
  }
  else if (s1Input)
{
    commitChecked(s1Input.value);
  }
}

function commitChecked(s1Value, s2Value)
{
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
            rowSelectValue(fld, s1Value, singleMode);
          if (myArray[2] == 's2')
            rowSelectValue(fld, s2Value, singleMode);
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

function updateChecked (obj, objName, event)
{
  if (event)
	  event.cancelBubble = true;
  var objForm = obj.form;
  coloriseRow(getParent(obj, 'tr'), obj.checked);

  var s1Value = objForm.s1.value;
  s1Value = BMK.trim(s1Value);
  s1Value = BMK.trim(s1Value, ',');
  s1Value = BMK.trim(s1Value);
  s1Value = s1Value + ',';
  for (var i = 0; i < objForm.elements.length; i = i + 1) {
    var obj = objForm.elements[i];
    if (obj != null && obj.type == "checkbox" && obj.name == objName) {
      if (obj.checked) {
        if (s1Value.indexOf(obj.value+',') == -1)
          s1Value = s1Value + obj.value + ',';
      } else {
        s1Value = (s1Value).replace(obj.value+',', '');
      }
    }
  }
  objForm.s1.value = BMK.trim(s1Value, ',');
}

function addChecked(srcForm, checkboxName, selectionMsq)
  {
  if (!anySelected (srcForm, checkboxName, selectionMsq, 'confirm'))
    return false;

  return commitChecked(srcForm.s1.value, srcForm.s2.value);
}

function rowSelectValue(dstField, srcValue, singleMode) {
	if (singleMode) {
		dstField.value = srcValue;
  } else {
    dstField.value = BMK.trim(dstField.value);
    dstField.value = BMK.trim(dstField.value, ',');
    dstField.value = BMK.trim(dstField.value);
		if (dstField.value.indexOf(srcValue) == -1) {
			if (dstField.value == '') {
				dstField.value = srcValue;
      } else {
				dstField.value = dstField.value + ',' + srcValue;
      }
    }
  }
}

// Hiddens functions
function createHidden(frm_name, fld_name, fld_value)
{
  return createHidden2(document, frm_name, fld_name, fld_value);
}

function createHidden2(doc, frm_name, fld_name, fld_value)
{
  var hidden;
  if (doc.forms[frm_name]) {
    hidden = doc.forms[frm_name].elements[fld_name];
    if (hidden == null) {
      hidden = doc.createElement("input");
      hidden.setAttribute("type", "hidden");
      hidden.setAttribute("name", fld_name);
      hidden.setAttribute("id", fld_name);
      doc.forms[frm_name].appendChild(hidden);
    }
    hidden.value = fld_value;
  }
  return hidden;
}

function changeExportName(fld_name, from, to) {
  var obj = document.forms['F1'].elements[fld_name];
  if (obj)
    obj.value = (obj.value).replace(from, to);
}

function addTag(tag, objName)
{
  var obj = document.F1.elements[objName];
  obj.value = BMK.trim(obj.value);
  obj.value = BMK.trim(obj.value, ',');
  obj.value = BMK.trim(obj.value);
  obj.value = (obj.value).replace('  ', ' ');
  obj.value = (obj.value).replace(' ,', ',');
  obj.value = obj.value + ',';
  if (obj.value.indexOf(tag+',') == -1) {
    obj.value = obj.value + tag + ',';
  } else {
    obj.value = (obj.value).replace(tag+',', '');
  }
  obj.value = BMK.trim(obj.value, ',');
}

function addCheckedTags (openerName, checkName)
{
  if (window.opener.document.F1.elements[document.F1.elements[openerName].value])
  {
    var objForm = document.F1;
    var objOpener = window.opener.document.F1.elements[document.F1.elements[openerName].value];

    objOpener.value = BMK.trim(objOpener.value);
    objOpener.value = BMK.trim(objOpener.value, ',');
    objOpener.value = BMK.trim(objOpener.value);
    objOpener.value = objOpener.value + ',';
    for (var i = 0; i < objForm.elements.length; i = i + 1)
    {
      var obj = objForm.elements[i];
      if (obj != null && obj.type == "checkbox" && obj.name == checkName)
      {
        if (obj.checked)
        {
          if (objOpener.value.indexOf(obj.value+',') == -1)
            objOpener.value = objOpener.value + obj.value+',';
        } else {
          objOpener.value = (objOpener.value).replace(obj.value+',', '');
        }
      }
    }
    objOpener.value = BMK.trim(objOpener.value, ',');
  }
  window.close();
}

function openBookmark (id)
{
  var c = $('bookmark_'+id);
  if (c)
  {
    OAT.Dom.removeClass(c, 'unvisited');
    OAT.Dom.addClass(c, 'visited');
  }
  readBookmark (id);
}

function openIFrame (id, accountID, uri)
{
  if (accountID > 0)
  {
    var c = $('bookmark_'+id);
    if (c)
    {
      OAT.Dom.removeClass(c, 'unvisited');
      OAT.Dom.addClass(c, 'visited');
    }
    readBookmark (id);
  }
  document.getElementById('pane_right_bottom').innerHTML = '<iframe src="'+uri+'" style="margin: -2px 0px 0px 0px;" width="100%" height="100%" frameborder="0" scrolling="auto" hspace="0" vspace="0" marginwidth="0" marginheight="0"></iframe>';
}

function urlParam (fldName)
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

var progressTimer = null;
var progressID = null;
var progressMax = null;
var progressSize = 40;
var progressInc = 100 / progressSize;

function stopState()
{
  progressTimer = null;
  OAT.AJAX.POST('ajax.vsp', "a=load&sa=stop&id="+progressID+urlParam("sid")+urlParam("realm"), null, {async: false});
}

function initState ()
{
  progressTimer = null;
  var x = function (data) {
    try {
      var xml = OAT.Xml.createXmlDoc(data);
      progressID = OAT.Xml.textValue(xml.getElementsByTagName('id')[0]);
    } catch (e) {}

  createProgressBar();
    progressTimer = setTimeout("checkState()", 500);

  document.forms['F1'].action = 'bookmarks.vspx';
}
  OAT.AJAX.POST('ajax.vsp', "a=load&sa=init"+urlParam("sid")+urlParam("realm")+urlParam("folder_id")+urlParam("folder_name")+urlParam("tags"), x, {async: false});
}

function checkState()
{
  var x = function (data) {
      var progressIndex;
      try {
      var xml = OAT.Xml.createXmlDoc(data);
      progressIndex = OAT.Xml.textValue(xml.getElementsByTagName('index')[0]);
      } catch (e) { }

        showProgress (progressIndex);

    if ((progressIndex != null) && (progressIndex != progressMax)) {
        setTimeout("checkState()", 500);
      } else {
      progressTimer = null;
      $('btn_Stop').value = 'Close';
      OAT.Dom.hide('btn_Background');
      }
    }
  OAT.AJAX.POST('ajax.vsp', "a=load&sa=state&id="+progressID+urlParam("sid")+urlParam("realm"), x);
}

function createProgressBar()
{
  progressMax = getObject('progressMax').innerHTML;

  var centerCellName;
  var tableText = "";
  var tdText = "";
  for (x = 0; x < progressSize; x++) {
    if (progressMax != null) {
      if (x == (progressSize/2))
	      centerCellName = "progress_" + x;
	  }
    tableText += "<td id=\"progress_" + x + "\" width=\"" + progressInc + "%\" height=\"20\" bgcolor=\"blue\" />";
  }
  var idiv = window.document.getElementById("progressText");
  if (idiv)
    idiv.innerHTML = "Imported 0 bookmarks from " + progressMax;
  var idiv = window.document.getElementById("progressBar");
  if (idiv)
    idiv.innerHTML = "<table with=\"200\" border=\"0\" cellspacing=\"0\" cellpadding=\"0\"><tr>" + tableText + "</tr></table>";
  centerCell = window.document.getElementById(centerCellName);
}

function showProgress (progressIndex)
{
  if (!progressMax)
    return;

  if (!progressIndex)
    progressIndex = progressMax;

  var idiv = window.document.getElementById("progressText");
  if (idiv)
    idiv.innerHTML = "Imported " + progressIndex + " bookmarks from " + progressMax;
  var percentage = 100;
  if (progressMax != 0)
    percentage = Math.round (progressIndex * 100 / progressMax);
  var percentageText = "";
  if (percentage < 10)
  {
    percentageText = "&nbsp;" + percentage;
  } else {
    percentageText = percentage;
  }
  centerCell.innerHTML = "<font color=\"white\">" + percentageText + "%</font>";
  for (x = 0; x < progressSize; x++)
  {
    var cell = window.document.getElementById("progress_" + x);
    if ((cell) && (percentage/x < progressInc))
    {
      cell.style.backgroundColor = "blue";
    } else {
      cell.style.backgroundColor = "red";
    }
  }
}

function readBookmark (id)
{
  var sid = '';
  if (document.forms[0].elements['sid'])
    sid = document.forms[0].elements['sid'].value;
  var realm = '';
  if (document.forms[0].elements['realm'])
    realm = document.forms[0].elements['realm'].value;
  OAT.AJAX.POST ('ajax.vsp', "sid="+sid+"&realm="+realm+"&id="+id+"&a=visited", function(){}, {onstart:function(){}, onerror:function(){}});
}

function davBrowse(fld, folders) {
	/* load stylesheets */
	OAT.Style.include("grid.css");
	OAT.Style.include("webdav.css");

  var options = {
    mode: 'browser',
    onConfirmClick: function(path, fname) {$(fld).value = '/DAV' + path + fname;}
  };
  if (!folders) {folders = false;}
  OAT.WebDav.options.foldersOnly = folders;
  OAT.WebDav.open(options);
}

function destinationChange(obj, actions)
{
  if (!obj.checked)
    return;
  if (!actions)
    return;
  if (actions.hide)
  {
    var a = actions.hide;
    for (var i = 0; i < a.length; i++)
    {
      var o = $(a[i])
      if (o) {OAT.Dom.hide(o);}
    }
  }
  if (actions.show)
  {
    var a = actions.show;
    for (var i = 0; i < a.length; i++)
    {
      var o = $(a[i])
      if (o) {OAT.Dom.show(o);}
    }
  }
  if (actions.clear)
  {
    var a = actions.clear;
    for (var i = 0; i < a.length; i++)
    {
      var o = $(a[i])
      if (o && o.value) {o.value = '';}
    }
  }
}

var BMK = new Object();
BMK.trim = function (sString, sChar)
{
  if (sString) {
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

BMK.writeCookie = function (name, value, hours)
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

BMK.readCookie = function (name)
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

BMK.readField = function (field, doc)
{
  var v;
  if (!doc) {doc = document;}
  if (doc.forms[0])
  {
    v = doc.forms[0].elements[field];
    if (v)
      v = v.value;
    }
  return v;
}

BMK.createParam = function (field, doc)
{
  var S = '';
  var v = BMK.readField(field, doc);
  if (v)
    S = '&'+field+'='+ encodeURIComponent(v);
  return S;
}

BMK.sessionParams = function (doc)
{
  return BMK.createParam('sid', doc)+BMK.createParam('realm', doc);
}

BMK.initState = function (state)
{
  if (!state)
    var state = new Object();

  var v = BMK.readField('sid');
  if (v)
    state.sid = v;
  var v = BMK.readField('realm');
  if (v)
    state.sid = v;
  if (!state.tab)
    state.tab = 'tree';

  return state;
}

BMK.saveState = function ()
{
  BMK.writeCookie('BMK_State', escape(OAT.JSON.stringify(BMK.state)), 1);
}

BMK.toggleLeftPane = function (pane)
{
  BMK.state.tab = pane;
  BMK.saveState();

  BMK.initTabs();
}

BMK.initLeftPane = function ()
{
  var div = $('pane_left');
  if (!div)
    return;

  // load cookie data
  var s = BMK.readCookie('BMK_State');
  if (s)
  {
    try {
      s = OAT.JSON.parse(unescape(s));
    } catch (e) { s = null; }
    s = BMK.initState(s);
  } else {
    s = BMK.initState();
  }
  BMK.state = s;
  var v = $('nodePath');
  if (v && (v.value != ''))
  {
    BMK.state.expanded = null;
    BMK.state.selected = v.value;
    if (v.value.indexOf('t#') == 0)
      BMK.state.tab = 'tags';
    BMK.saveState();
  }
  BMK.forms = new Object();
  BMK.forms['import'] = {height: '400', postActions:['BMK.loadTree(true)', 'BMK.reloadItems()', 'BMK.resetToolbars()']};
  BMK.forms['export'] = {height: '160'};
  BMK.forms['bookmark'] = {height: '400', postActions:['BMK.loadTags(true)', 'BMK.reloadItems()', 'BMK.resetToolbars()']};
  BMK.forms['folder'] = {height: '180', postActions:['BMK.loadTree(true)', 'BMK.reloadItems()', 'BMK.resetToolbars()']};
  BMK.forms['smart folder'] = {height: '320', postActions:['BMK.loadTree(true)', 'BMK.reloadItems()', 'BMK.resetToolbars()']};
  BMK.forms['move'] = {params: {items: true}, height: '100', postActions:['BMK.loadTree(true)', 'BMK.reloadItems()', 'BMK.resetToolbars()']};
  BMK.forms['share'] = {params: {items: true}, height: '130', postActions:['BMK.reloadItems()', 'BMK.resetToolbars()']};
  BMK.forms['tags'] = {params: {items: true}, height: '130', postActions:['BMK.loadTags(true)', 'BMK.reloadItems()', 'BMK.resetToolbars()']};
  BMK.forms['delete'] = {params: {items: true}, postActions:['BMK.loadTree(true)', 'BMK.loadTags(true)', 'BMK.resetToolbars()']};
  BMK.forms['bookmarklet'] = {redirect: 'settings.vspx?sa=bookmarklet'};

  BMK.initTabs()
}

BMK.initTabs = function ()
{
  BMK.initTree()
  BMK.initTags()
}

BMK.initTags = function ()
{
  var div = $('pane_left_tags');
  if (!div) {return;}

  if (BMK.state.tab != 'tags')
  {
    OAT.Dom.addClass('tags_button', 'tab2');
    OAT.Dom.removeClass('tags_button', 'activeTab2');
    OAT.Dom.hide('pane_left_tags');
    return;
  }

  OAT.Dom.show('pane_left_tags');
  OAT.Dom.removeClass('tags_button', 'tab2');
  OAT.Dom.addClass('tags_button', 'activeTab2');

  if (div.innerHTML != '...') {return;}
  BMK.loadTags();
}

BMK.loadTags = function (mode)
{
  var div = $('pane_left_tags');
  if (!div) {return;}
  if (mode && (div.innerHTML == '...')) {return;}

  div.innerHTML = '';
  var x = function(data) {
    div.innerHTML = data;
    var selected = BMK.state.selected;
    if (selected && (selected.indexOf('t#') == 0))
      BMK.selectTag(selected);
  }
  var S = 'ajax.vsp?a=tags&sa=load&np='+encodeURIComponent(BMK.state.selected)+BMK.sessionParams();
  OAT.AJAX.GET(S, '', x);
}

BMK.selectTag = function (tag)
{
  var newTag = tag.replace('t#', '');
  if (tag.indexOf('t#') != 0)
    tag = 't#'+tag;
  aTags = $('pane_left_tags').getElementsByTagName('a');
  for (var i = 0; i < aTags.length; i++)
  {
    a = aTags[i];
    if (a.id)
    {
      if (a.id.indexOf('t_tag_') == 0)
      {
        OAT.Dom.removeClass(a, 'FM_bold');
        if (a.id == ('t_tag_' + newTag))
          OAT.Dom.addClass(a, 'FM_bold');
      }
    }
  }
  BMK.state.tab = 'tags';
  BMK.state.selected = tag;
  BMK.saveState();
  BMK.initTabs();
  BMK.loadItems(BMK.state.selected)
}

BMK.initTree = function ()
{
  var div = $('pane_left_tree');
  if (!div) {return;}

  if (BMK.state.tab != 'tree')
  {
    OAT.Dom.addClass('tree_button', 'tab2');
    OAT.Dom.removeClass('tree_button', 'activeTab2');
    OAT.Dom.hide('pane_left_tree');
    return;
  }

  OAT.Dom.removeClass('tree_button', 'tab2');
  OAT.Dom.addClass('tree_button', 'activeTab2');
  OAT.Dom.show('pane_left_tree');

  if (div.innerHTML != '...') {return;}
  BMK.loadTree();
}

BMK.loadTree = function (mode)
{
  var div = $('pane_left_tree');
  if (!div) {return;}
  if (mode && (div.innerHTML == '...')) {return;}

  div.innerHTML = '';
  BMK.tree = new OAT.Tree();
  var ul = OAT.Dom.create("ul",{whiteSpace:"nowrap"});
  BMK.tree.assign(ul, true);
  div.appendChild(ul);

  OAT.MSG.attach(BMK.tree, OAT.MSG.TREE_EXPAND, function(sender,msg,node) {
    var nodePath = node.myPath;
    BMK.expandTree(nodePath, node);
  });
  OAT.MSG.attach(BMK.tree, OAT.MSG.TREE_COLLAPSE, function(sender,msg,node) {
    var nodePath = node.myPath;
    BMK.collapseTree(nodePath, node);
  });

  // load and open selected nodes
  var x = function() {
    var v = new Array();
    if (BMK.state.expanded)
    {
      for (var i = 0; i < BMK.state.expanded.length; i++)
      {
        v.push(BMK.state.expanded[i]);
      }
    }
    if (BMK.state.selected)
    {
      v.push(BMK.state.selected);
    }
    BMK.loadPath(v, 0);
  };
  BMK.loadTreeData('', BMK.tree.tree, x);
}

BMK.loadPath = function (w, wIndex)
{
  var selectNode;

  for (var n = wIndex; n < w.length; n++)
  {
    var nodePath = w[n];
    var parts = nodePath.split("/");
    if (parts[0] == "") { parts.shift(); }
    if (parts[parts.length-1] == "") { parts.pop(); }

    var node = BMK.tree.tree;
    var currentPath = '';

    for (var i = 0; i < parts.length; i++)
    {
      currentPath += '/' + parts[i];
      var index = -1;
      for (var j = 0; j < node.children.length; j++)
      {
        var child = node.children[j];
        if (child.myPath == currentPath)
        {
          if ((child.children.length == 0) && child.ul)
          {
            var x = function() {BMK.loadPath(w, n);};
            BMK.loadTreeData(currentPath, child, x);
            return;
          }
          index = j;
          break;
        }
      }
      if (index == -1) {break;}

      node = node.children[index];
      node.expand(true);
      if (BMK.state.selected == node.myPath)
      {
        selectNode = node;
      }
    }
    node.toggleSelect({ctrlKey:false});
  }
  BMK.selectedPath();
  BMK.execNodeAction();
}

BMK.findPath = function (path)
{
  if (!path)
    return null;

  if (path.indexOf('t#') == 0)
    return null;

  var parts = path.split("/");
  if (parts[0] == "") { parts.shift(); }
  if (parts[parts.length-1] == "") { parts.pop(); }

  var node = BMK.tree.tree;
  var currentPath = '';

  for (var i = 0; i < parts.length; i++)
  {
    currentPath += '/' + parts[i];
    var index = -1;
    for (var j = 0; j < node.children.length; j++)
    {
      var child = node.children[j];
      if (path == child.myPath) {return child;}
      if (child.myPath == currentPath)
      {
        index = j;
        break;
      }
    }
    if (index == -1) {return;}
    node = node.children[index];
    if (!node) {break;}
  }
  return null;
}

BMK.selectedPath = function ()
{
  var node = BMK.findPath(BMK.state.selected);
  if (node)
  {
    node.select();
    BMK.loadItems(node.myID, node.myPath);
  }
}

BMK.loadTreeData = function(nodePath, node, nodeFunction)
{
  var S = 'ajax.vsp?a=tree&sa=load&np='+encodeURIComponent(nodePath)+BMK.sessionParams();
  var x = function(data) {
    BMK.updateTree(data, node, nodePath, nodeFunction);
  }
  OAT.AJAX.GET(S, '', x);
}

BMK.execNodeAction = function()
{
  var a = $('nodeAction');
  if (a && (a.value != ''))
  {
    var n = $('id');
    if (n) {n = n.value;}
    var p = $('nodeParams');
    if (p) {p = p.value;}
    BMK.formShow(a.value, n, p);
    a.value = '';
  }
}

BMK.updateTree = function(data, node, nodePath, nodeFunction)
{
  function attach(node, path) {
    OAT.Event.attach(node._gdElm, 'click', function() {BMK.selectNode(path, node);});
  }
  var o = OAT.JSON.parse(data);
  for (var i = 0; i < o.length; i++)
  {
    var item = o[i];
    var iID = item[0];
    var iType = item[1];
    var iLabel = item[2];
    var iPath = item[3];
    var iImage = item[4];
    var iSelected = item[5];
    var iDraggable = item[6];

    var newNode = node.createChild(iLabel, iType==0? false: true);
    if (iImage != '')
      newNode.setImage(iImage);
    attach(newNode, iPath)
    newNode.collapse();

    /* custom properties */
    newNode.myID = iID;
    newNode.myPath = iPath;
    newNode.selectable = iSelected==0? false: true;
  }
  if (node.children.length == 0)
    node.ul = false
  BMK.tree.walk("sync");
  if (nodeFunction)
    nodeFunction();
}

BMK.expandTree = function (nodePath, node)
{
  var a = BMK.state.expanded;
  if (!a)
  {
    a = [nodePath];
  } else {
    var N = a.find(nodePath);
    if (N == -1)
    {
      a.push(nodePath);
    }
  }
  BMK.state.expanded = a;
  BMK.saveState();

  if (node.children.length != 0) { return; } /* nothing when already fetched */

  BMK.loadTreeData(nodePath, node);
}

BMK.collapseTree = function (nodePath, node)
{
  var expanded = BMK.state.expanded;
  if (expanded)
  {
    var N = expanded.find(nodePath);
    if (N != -1)
    {
      var a = [];
      for (var i = 0; i < expanded.length; i++)
      {
        if (i != N)
        {
          a.push(expanded[i]);
        }
      }
      BMK.state.expanded = a;
      BMK.saveState();
    }
  }
}

BMK.selectPath = function (nodePath)
{
  BMK.state.tab = 'tree';
  BMK.state.selected = nodePath;
  BMK.saveState();
  BMK.initTabs();
  BMK.resetToolbars();
  BMK.loadPath([nodePath], 0);
}

BMK.selectNode = function(nodePath, node)
{
  if (node.selectable)
  {
    BMK.state.selected = nodePath;
    BMK.saveState();
    BMK.loadItems(node.myID, nodePath);
  }
}

BMK.loadItems = function(nodeID, nodePath)
{
  BMK.resetToolbars();
  nodeID = BMK.trim(nodeID, '/');
  if (!nodePath)
    nodePath = nodeID;
  var pane = $('pane_right_top');
  pane.innerHTML = '';
  var URL = 'forms.vspx?sa=browse&node='+encodeURIComponent(nodeID)+'&path='+encodeURIComponent('/'+BMK.trim(nodePath, '/'))+BMK.sessionParams();
  var v = $('nodeItem');
  if (v && (v.value != '')) {
    URL += '&item=' + v.value;
    v.value = '';
  }
  pane.innerHTML = '<iframe id="items_iframe" src="'+URL+'" width="100%" height="100%" frameborder="0" scrolling="auto" hspace="0" vspace="0" marginwidth="0" marginheight="0"></iframe>';
  var pane = $('pane_right_bottom');
  if (pane)
    pane.innerHTML = '';
}

BMK.reloadItems = function()
{
  BMK.loadItems(BMK.state.selected);
}

BMK.resetToolbars = function ()
{
  enableElement('tbTag', 'tbTag_gray', 0);
  enableElement('tbMove', 'tbMove_gray', 0);
  enableElement('tbSharing', 'tbSharing_gray', 0);
  enableElement('tbDelete', 'tbDelete_gray', 0);
}

BMK.formParams = function (doc)
{
  if (!doc) {doc = document;}
  var S = '';
  var o = doc.forms[0].elements;
  for (var i = 0; i < o.length; i++) {
    if (!o[i] || !o[i].name)
      continue;

    if ((o[i].type == "checkbox" && o[i].checked) || (o[i].type != "checkbox")) {
        var n = o[i].name;
        if ((n != '') && (n.indexOf('page_') != 0) && (n.indexOf('__') != 0))
          S += '&' + n + '=' + encodeURIComponent(o[i].value);
        }
      }
  return S;
}

BMK.formShow = function (action, id, params)
{
  var formParams = action.split('/')[0].toLowerCase();
  var form = BMK.forms[formParams];
  if (!form) {return;}
  if (form.redirect)
  {
    location.href = form.redirect+BMK.sessionParams();
  } else {
  var dx = form.width;
  if (!dx) {dx = '720';}
  var dy  = form.height;
  if (!dy) {dy = '200';}

  var formDiv = $('formDiv');
  if (formDiv) {OAT.Dom.unlink(formDiv);}
  formDiv = OAT.Dom.create('div', {width:dx+'px', height:dy+'px'});
  formDiv.id = 'formDiv';
  formDialog = new OAT.Dialog('', formDiv, {width:parseInt(dx)+20, buttons: 0, resize: 0, modal: 1, onhide: function(){return false;}});
  formDialog.cancel = formDialog.hide;

  var s = 'forms.vspx?sa='+encodeURIComponent(action)+BMK.sessionParams();
  if (id) {s += '&id='+encodeURIComponent(id);}
  if (params) {s += params;}
  if (form.params)
  {
    if (form.params.items)
    {
      var o = getObject('items_iframe');
      if (o) {s += BMK.formParams(o.contentDocument);}
    }
  }
  formDiv.innerHTML = '<iframe id="forms_iframe" src="'+s+'" width="100%" height="100%" frameborder="0" scrolling="auto" hspace="0" vspace="0" marginwidth="0" marginheight="0"></iframe>';
  formDialog.show ();
}
}

BMK.formClose = function ()
{
  parent.formDialog.hide ();
}

BMK.formPost = function (action, mode)
{
  var win = (mode != 'top') ? parent: window;
  var x = function(data) {
    var o = OAT.JSON.parse(data);
    if ((o != '') && (action != 'export'))
    {
      alert(o);
      return;
    }
    win.BMK.formPostAfter(action);
  }
  var formParams = action.split('/')[0].toLowerCase();
  var form = win.BMK.forms[formParams];
  var s = 'ajax.vsp?a=form&sa='+encodeURIComponent(action)+BMK.formParams();
  if (form.params)
  {
    if (form.params.items)
    {
      var o = getObject('items_iframe', win.document);
      if (o) {s += BMK.formParams(o.contentDocument);}
    }
  }
  OAT.AJAX.GET(s, '', x);
}

BMK.formPostAfter = function (action)
{
 var formParams = action.split('/')[0].toLowerCase();
 var form = BMK.forms[formParams];
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
  if (formDialog)
    formDialog.hide();
}

BMK.aboutDialog = function ()
{
  var aboutDiv = $('aboutDiv');
  if (aboutDiv)
    OAT.Dom.unlink(aboutDiv);

  aboutDiv = OAT.Dom.create('div', {height: '160px', overflow: 'hidden'});
  aboutDiv.id = 'aboutDiv';
  aboutDialog = new OAT.Dialog('About ODS Booomarks', aboutDiv, {width:445, buttons: 0, resize:0, modal:1});
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
