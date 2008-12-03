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
function myTags(fld_value)
{
  createHidden('F1', 'tag', fld_value);
  doPost ('F1', 'pt_tags');
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
  doPost ('F1', fButton);
}

// ---------------------------------------------------------------------------
function toolbarPost(value)
{
  document.F1.tbHidden.value = value;
  doPost ('F1', 'toolbar');
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
  if (keycode == 13) {
    if (myButton != '') {
      doPost (myForm, myButton);
      return false;
    } else
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
function getObject(id, doc)
{
  if (!doc) {doc = document;}
  return doc.getElementById(id);
}

// ---------------------------------------------------------------------------
function confirmAction(confirmMsq, form, txt, selectionMsq)
{
  if (anySelected (form, txt, selectionMsq))
    return confirm(confirmMsq);
  return false;
}

// ---------------------------------------------------------------------------
function selectCheck (obj, prefix)
{
  coloriseRow(getParent(obj, 'tr'), obj.checked);
  enableToolbars(obj.form, prefix, parent.document);
}

// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
function getParent (o, tag)
{
  var o = o.parentNode;
  if (o.tagName.toLowerCase() == tag)
    return o;
  return getParent(o, tag);
}

// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
function showCell (cell)
{
  var c = getObject (cell);
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

// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
//
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

// ---------------------------------------------------------------------------
function coloriseTable(id) {
  if (document.getElementsByTagName) {
    var table = document.getElementById(id);
    if (table != null) {
      var rows = table.getElementsByTagName("tr");
      for (i = 0; i < rows.length; i++) {
        rows[i].className = rows[i].className + " tr_" + (i % 2);;
      }
    }
  }
}

// ---------------------------------------------------------------------------
function coloriseRow(obj, checked) {
  obj.className = (obj.className).replace('tr_select', '');
  if (checked)
    obj.className = obj.className + ' ' + 'tr_select';
}

// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
function clickNode2(obj) {
  var nodes = obj.parentNode.childNodes;
  for (var i=0; i<nodes.length; i++) {
    var node = nodes[i];
    if (node.tagName == 'A')
      if (node.onclick)
        return node.onclick();
  }
}

// ---------------------------------------------------------------------------
function addOption (form, text_name, box_name) {
  var box = form.elements[box_name];
  if (box) {
    var text = form.elements[text_name];
    if (text) {
      text.value = BMK.trim(text.value);
      if (text.value == '')
        return;
    	for (var i=0; i<box.options.length; i++)
		    if (text.value == box.options[i].value)
		      return;
	    box.options[box.options.length] = new Option(text.value, text.value, false, true);
	    sortSelect(box);
	    text.value = '';
	  }
	}
}

// ---------------------------------------------------------------------------
function deleteOption (form, box_name) {
  var box = form.elements[box_name];
  if (box)
	  box.options[box.selectedIndex] = null;
}

// ---------------------------------------------------------------------------
function composeOptions (form, box_name, text_name) {
  var box = form.elements[box_name];
  if (box) {
    var text = form.elements[text_name];
    if (text) {
		  text.value = '';
    	for (var i=0; i<box.options.length; i++)
    	  if (text.value == '')
		      text.value = box.options[i].value;
		    else
		      text.value = text.value + '\n' + box.options[i].value;
	  }
	}
}

// ---------------------------------------------------------------------------
function showTag(tag) {
  createHidden2(parent.document, 'F1', 'tag', tag);
  parent.document.forms['F1'].submit();
}

// ---------------------------------------------------------------------------
//
// sortSelect(select_object)
//   Pass this function a SELECT object and the options will be sorted
//   by their text (display) values
//
// ---------------------------------------------------------------------------
function sortSelect(box) {
	var o = new Array();
	for (var i=0; i<box.options.length; i++)
		o[o.length] = new Option( box.options[i].text, box.options[i].value, box.options[i].defaultSelected, box.options[i].selected) ;

	if (o.length==0)
	  return;

	o = o.sort(function(a,b) {
                      			if ((a.text+"") < (b.text+"")) { return -1; }
                      			if ((a.text+"") > (b.text+"")) { return 1; }
                      			return 0;
			                     }
		        );

	for (var i=0; i<o.length; i++)
		box.options[i] = new Option(o[i].text, o[i].value, o[i].defaultSelected, o[i].selected);
}

// ---------------------------------------------------------------------------
//
function showTab(tabs, tabsCount, tabNo)
{
  if ($(tabs)) {
    for (var i = 0; i < tabsCount; i++) {
      var l = $(tabs+'_tab_'+i);      // tab labels
      var c = $(tabs+'_content_'+i);  // tab contents
      if (i == tabNo) {
        if ($('tabNo'))
          $('tabNo').value = tabNo;
        if (c) {
          OAT.Dom.show(c);
      }
        OAT.Dom.addClass(l, "activeTab");
        l.blur();
      } else {
        if (c) {
          OAT.Dom.hide(c);
    }
        OAT.Dom.removeClass(l, "activeTab");
  }
}
  }
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
  win = window.open(sPage, null, "width="+width+",height="+height+", top=100, left=100, scrollbars=yes, resize=yes, menubar=no");
  win.window.focus();
}

// ---------------------------------------------------------------------------
//
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
function rowSelectValue(dstField, srcField, singleMode)
{
  if (singleMode)
  {
    dstField.value = srcField.value;
  } else {
    dstField.value = BMK.trim(dstField.value);
    dstField.value = BMK.trim(dstField.value, ',');
    dstField.value = BMK.trim(dstField.value);
    if (dstField.value.indexOf(srcField.value) == -1)
    {
      if (dstField.value == '')
      {
        dstField.value = srcField.value;
      } else {
        dstField.value = dstField.value + ', ' + srcField.value;
      }
    }
  }
}

// ---------------------------------------------------------------------------
//
// Hiddens functions
//
// ---------------------------------------------------------------------------
//
function createHidden(frm_name, fld_name, fld_value) {
  var hidden;

  createHidden2(document, frm_name, fld_name, fld_value);
}

// ---------------------------------------------------------------------------
//
function createHidden2(doc, frm_name, fld_name, fld_value) {
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
}

// ---------------------------------------------------------------------------
//
function changeExportName(fld_name, from, to) {
  var obj = document.forms['F1'].elements[fld_name];
  if (obj)
    obj.value = (obj.value).replace(from, to);
}

// ---------------------------------------------------------------------------
//
function updateChecked (obj, objName)
{
  var objForm = obj.form;
  coloriseRow(getParent(obj, 'tr'), obj.checked);
  objForm.s1.value = BMK.trim(objForm.s1.value);
  objForm.s1.value = BMK.trim(objForm.s1.value, ',');
  objForm.s1.value = BMK.trim(objForm.s1.value);
  objForm.s1.value = objForm.s1.value + ',';
  for (var i = 0; i < objForm.elements.length; i = i + 1)
  {
    var obj = objForm.elements[i];
    if (obj != null && obj.type == "checkbox" && obj.name == objName)
    {
      if (obj.checked)
      {
        if (objForm.s1.value.indexOf(obj.value+',') == -1)
          objForm.s1.value = objForm.s1.value + obj.value+',';
      } else {
        objForm.s1.value = (objForm.s1.value).replace(obj.value+',', '');
      }
    }
  }
  objForm.s1.value = BMK.trim(objForm.s1.value, ',');
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
  if (submitMode)
    window.opener.document.F1.submit();
  window.close();
}

// ---------------------------------------------------------------------------
//
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

// ---------------------------------------------------------------------------
//
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

// ---------------------------------------------------------------------------
//
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

// ---------------------------------------------------------------------------
//
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

// ---------------------------------------------------------------------------
//
function urlParam (fldName)
{
  var S = '';
  var O = document.forms[0].elements[fldName];
  if (O)
    S += '&' + fldName + '=' + encodeURIComponent(O.value);
  return S;
}

// ---------------------------------------------------------------------------
//
function showObject(id)
{
  var o = document.getElementById(id);
  if (o)
  {
    o.style.display="";
    o.visible = true;
  }
}

// ---------------------------------------------------------------------------
//
function hideObject(id)
{
  var o = document.getElementById(id);
  if (o != null)
  {
    o.style.display="none";
    o.visible = false;
  }
}

// ---------------------------------------------------------------------------
//
function initRequest ()
{
  var xmlhttp = null;
  try {
    xmlhttp = new ActiveXObject("Msxml2.XMLHTTP");
  } catch (e) { }

  if (xmlhttp == null) {
    try {
      xmlhttp = new ActiveXObject("Microsoft.XMLHTTP");
    } catch (e) { }
  }

  // Gecko / Mozilla / Firefox
  if (xmlhttp == null)
    xmlhttp = new XMLHttpRequest();

  return xmlhttp;
}

// ---------------------------------------------------------------------------
//
var timer = null;
var progressID = null;
var progressMax = null;
var progressStop = null;

function resetState()
{
  var xmlhttp = initRequest();
  var URL = 'ajax.vsp?a=import&sa=reset';
  xmlhttp.open("POST", URL + urlParam("sid") + urlParam("realm"), false);
  xmlhttp.setRequestHeader("Pragma", "no-cache");
  xmlhttp.send(null);
  try {
    progressID = xmlhttp.responseXML.getElementsByTagName("id")[0].firstChild.nodeValue;
  } catch (e) { }
}

// ---------------------------------------------------------------------------
//
function stopState()
{
  timer = null;

  var xmlhttp = initRequest();
  var URL = 'ajax.vsp?a=import&sa=stop';
  xmlhttp.open("POST", URL+"&id="+progressID+urlParam("sid")+urlParam("realm"), false);
  xmlhttp.setRequestHeader("Pragma", "no-cache");
  xmlhttp.send(null);
}

// ---------------------------------------------------------------------------
//
function initState ()
{
  // reset state first
  resetState();

  // init state
  var xmlhttp = initRequest();
  var URL = 'ajax.vsp';
  xmlhttp.open("POST", URL, false);
  xmlhttp.setRequestHeader("Pragma", "no-cache");
  xmlhttp.setRequestHeader("Content-Type", "application/x-www-form-urlencoded; charset=UTF-8");
  xmlhttp.send("a=import&sa=init&id="+progressID+urlParam("sid")+urlParam("realm")+urlParam("folder_id")+urlParam("folder_name")+urlParam("tags"));

  createProgressBar();
  timer = setTimeout("checkState()", 1000);

  document.forms['F1'].action = 'bookmarks.vspx';
}

// ---------------------------------------------------------------------------
//
function checkState()
{
  var xmlhttp = initRequest();
  var URL = 'ajax.vsp?a=import&sa=state';
  xmlhttp.open("POST", URL+"&id="+progressID+urlParam("sid")+urlParam("realm"), true);
  xmlhttp.onreadystatechange = function() {
    if (xmlhttp.readyState == 4) {
      var progressIndex;

      // progressIndex
      try {
        progressIndex = xmlhttp.responseXML.getElementsByTagName("index")[0].firstChild.nodeValue;
      } catch (e) { }

      if (timer != null)
        showProgress (progressIndex);
      if ((progressIndex != null) && (progressIndex != progressMax) && (timer != null))
      {
        setTimeout("checkState()", 500);
      } else {
        timer = null;
        $('btn_Stop').click();
      }
    }
  }
  xmlhttp.setRequestHeader("Pragma", "no-cache");
  xmlhttp.send("");
}

var size = 40;
var increment = 100 / size;

// ---------------------------------------------------------------------------
//
// create the progress bar
//
function createProgressBar()
{
  progressMax = getObject('progressMax').innerHTML;

  var centerCellName;
  var tableText = "";
  var tdText = "";
  for (x = 0; x < size; x++) {
    if (progressMax != null) {
	    if (x == (size/2))
	      centerCellName = "progress_" + x;
	  }
    tableText += "<td id=\"progress_" + x + "\" width=\"" + increment + "%\" height=\"20\" bgcolor=\"blue\" />";
  }
  var idiv = window.document.getElementById("progressText");
  if (idiv)
    idiv.innerHTML = "Imported 0 bookmarks from " + progressMax;
  var idiv = window.document.getElementById("progressBar");
  if (idiv)
    idiv.innerHTML = "<table with=\"200\" border=\"0\" cellspacing=\"0\" cellpadding=\"0\"><tr>" + tableText + "</tr></table>";
  centerCell = window.document.getElementById(centerCellName);
}

// ---------------------------------------------------------------------------
//
// show the current percentage
//
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
  for (x = 0; x < size; x++)
  {
    var cell = window.document.getElementById("progress_" + x);
    if ((cell) && (percentage/x < increment))
    {
      cell.style.backgroundColor = "blue";
    } else {
      cell.style.backgroundColor = "red";
    }
  }
}

// ---------------------------------------------------------------------------
//
function readBookmark (id)
{
  var sid = '';
  if (document.forms[0].elements['sid'])
    sid = document.forms[0].elements['sid'].value;
  var realm = '';
  if (document.forms[0].elements['realm'])
    realm = document.forms[0].elements['realm'].value;
  OAT.AJAX.POST ("ajax.vsp", "sid="+sid+"&realm="+realm+"&id="+id+"&a=visited", function(){}, {onstart:function(){}, onerror:function(){}});
}

// ---------------------------------------------------------------------------
function davBrowse (fld)
{
  var options = { mode: 'browser',
                  onConfirmClick: function(path, fname) {$(fld).value = path + fname;}
                };
  OAT.WebDav.open(options);
}

// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
var BMK = new Object();

BMK.trim = function (sString, sChar)
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
    {
      v = v.value;
    }
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

  state.sid = BMK.readField('sid');
  state.realm = BMK.readField('realm');
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
  BMK.forms['import'] = {height: '400', postActions:['BMK.loadTree()', 'BMK.reloadItems()', 'BMK.resetToolbars()']};
  BMK.forms['export'] = {height: '160'};
  BMK.forms['bookmark'] = {height: '380', postActions:['BMK.reloadItems()', 'BMK.resetToolbars()']};
  BMK.forms['folder'] = {height: '180', postActions:['BMK.loadTree()', 'BMK.reloadItems()', 'BMK.resetToolbars()']};
  BMK.forms['smart folder'] = {height: '320', postActions:['BMK.loadTree()', 'BMK.reloadItems()', 'BMK.resetToolbars()']};
  BMK.forms['move'] = {params: {items: true}, height: '100', postActions:['BMK.loadTree()', 'BMK.reloadItems()', 'BMK.resetToolbars()']};
  BMK.forms['share'] = {params: {items: true}, height: '130', postActions:['BMK.reloadItems()', 'BMK.resetToolbars()']};
  BMK.forms['tags'] = {params: {items: true}, height: '130', postActions:['BMK.loadTags()', 'BMK.reloadItems()', 'BMK.resetToolbars()']};
  BMK.forms['delete'] = {params: {items: true}, postActions:['BMK.loadTree()', 'BMK.loadTags()', 'BMK.resetToolbars()']};

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

BMK.loadTags = function ()
{
  var div = $('pane_left_tags');
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
  if (!div)
    return;

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

BMK.loadTree = function ()
{
  var div = $('pane_left_tree');
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
  BMK.nodeAction();
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

BMK.nodeAction = function()
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
    OAT.Dom.attach(node._gdElm, 'click', function() {BMK.selectNode(path, node);});
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
  var URL = 'forms.vspx?sa=browse&node='+encodeURIComponent(nodeID)+'&path='+encodeURIComponent(nodePath)+BMK.sessionParams();
  var v = $('nodeItem');
  if (v && (v.value != ''))
  {
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

BMK.formShow = function (action, id, params)
{
  var formParams = action.split('/')[0].toLowerCase();
  var form = BMK.forms[formParams];
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

BMK.updateClaim = function (claimNo)
{
  if (claimNo == 'xxx')
  {
    if (($v('c_iri_xxx') == '') || ($v('c_relation_xxx') == '') || ($v('c_value_xxx') == ''))
    {
      alert ('The IRI, relation and value fileld can not be empty|');
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

        var tr_parent = $('c_tr').parentNode;
        tr_parent.insertBefore(tr_add, $('c_tr'));
        tr_add.innerHTML = S;

        var cl = new OAT.Combolist([], 'rdfs:seeAlso');
        cl.input.name = 'c_relation_'+seqNo;
        cl.input.id = 'c_relation_'+seqNo;
        cl.input.style.width = "80%";
        var td = $('c_td_'+seqNo);
        td.innerHTML = '';
        td.appendChild(cl.div);
        cl.addOption('rdfs:seeAlso');
        cl.addOption('foaf:made');
        cl.addOption('foaf:maker');

        $('c_iri_'+seqNo).value = $v('c_iri_xxx');
        $('c_relation_'+seqNo).value = $v('c_relation_xxx');
        $('c_value_'+seqNo).value = $v('c_value_xxx');

        $('c_seqNo').value = seqNo + 1;
        $('c_iri_xxx').value = '';
        $('c_relation_xxx').value = '';
        $('c_value_xxx').value = '';
      }
    }
  }
  else
  {
    OAT.Dom.unlink('c_tr_'+claimNo);
  }
}

BMK.aboutDialog = function ()
{
  var aboutDiv = $('aboutDiv');
  if (aboutDiv) {OAT.Dom.unlink(aboutDiv);}
  aboutDiv = OAT.Dom.create('div', {width:'430px', height:'150px'});
  aboutDiv.id = 'aboutDiv';
  aboutDialog = new OAT.Dialog('About ODS Booomarks', aboutDiv, {width:430, buttons: 0, resize:0, modal:1});
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
