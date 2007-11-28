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
function vspxPost(fButton, fName, fValue, f2Name, f2Value)
{
  createHidden('F1', fName, fValue);
  createHidden('F1', f2Name, f2Value);
  doPost ('F1', fButton);
}

// ---------------------------------------------------------------------------
function toolbarPost(value)
{
  document.F1.tbHidden.value = value;
  doPost ('F1', 'toolbar');
}

// ---------------------------------------------------------------------------
//
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
function getObject(id)
{
  if (document.all)
    return document.all[id];
  return document.getElementById(id);
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
  enableToolbars(obj.form, prefix);
}

// ---------------------------------------------------------------------------
function enableToolbars (objForm, prefix)
{
  var oCount = 0;
  var tCount = 0;
  var mCount = 0;
  for (var i = 0; i < objForm.elements.length; i++) {
    var o = objForm.elements[i];
    if (o != null && o.type == 'checkbox' && !o.disabled && o.name.indexOf (prefix) != -1 && o.checked) {
      oCount += 1;
      if (o.value.indexOf ('b#') != -1)
        tCount += 1;
      if ((o.value.indexOf ('b#') != -1) || (o.value.indexOf ('f#') != -1))
        mCount += 1;
    }
  }
  if (tCount != mCount)
    tCount = 0;
  enableElement('tbTag', tCount>0);
  enableElement('tbTag_gray', tCount==0);
  enableElement('tbMove', mCount>0);
  enableElement('tbMove_gray', mCount==0);
  enableElement('tbRename', oCount==1);
  enableElement('tbRename_gray', oCount!=1);
  enableElement('tbSharing', oCount>0);
  enableElement('tbSharing_gray', oCount==0);
  enableElement('tbProperties', oCount==1);
  enableElement('tbProperties_gray', oCount!=1);
  enableElement('tbDelete', oCount>0);
  enableElement('tbDelete_gray', oCount==0);
}

// ---------------------------------------------------------------------------
function getParent (obj, tag)
{
  var obj = obj.parentNode;
  if (obj.tagName.toLowerCase() == tag)
    return obj;
  return getParent(obj, tag);
}

// ---------------------------------------------------------------------------
function enableElement (id, enableFlag)
{
  var element = document.getElementById(id);
  if (element != null) {
    if (enableFlag) {
     element.style.display = 'block';
    } else {
     element.style.display = 'none';
    }
  }
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
        if (frm.grants.value.indexOf(obj.value+',') == -1)
          frm.grants.value = frm.grants.value + obj.value+',';
      } else {
        frm.grants.value = (frm.grants.value).replace(obj.value+',', '');
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
function trim(sString, sChar) {
  if (sChar == null)
    sChar = ' ';

  while (sString.substring(0,1) == sChar)
    sString = sString.substring(1, sString.length);

  while (sString.substring(sString.length-1, sString.length) == sChar)
    sString = sString.substring(0,sString.length-1);

  return sString;
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
      text.value = trim(text.value);
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
  if (singleMode) {
    dstField.value = srcField.value;
  } else {
    dstField.value = trim(dstField.value);
    dstField.value = trim(dstField.value, ',');
    dstField.value = trim(dstField.value);
    if (dstField.value.indexOf(srcField.value) == -1) {
      if (dstField.value == '') {
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
  objForm.s1.value = trim(objForm.s1.value);
  objForm.s1.value = trim(objForm.s1.value, ',');
  objForm.s1.value = trim(objForm.s1.value);
  objForm.s1.value = objForm.s1.value + ',';
  for (var i = 0; i < objForm.elements.length; i = i + 1) {
    var obj = objForm.elements[i];
    if (obj != null && obj.type == "checkbox" && obj.name == objName) {
      if (obj.checked) {
        if (objForm.s1.value.indexOf(obj.value+',') == -1)
          objForm.s1.value = objForm.s1.value + obj.value+',';
      } else {
        objForm.s1.value = (objForm.s1.value).replace(obj.value+',', '');
      }
    }
  }
  objForm.s1.value = trim(objForm.s1.value, ',');
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
  obj.value = trim(obj.value);
  obj.value = trim(obj.value, ',');
  obj.value = trim(obj.value);
  obj.value = (obj.value).replace('  ', ' ');
  obj.value = (obj.value).replace(' ,', ',');
  obj.value = obj.value + ',';
  if (obj.value.indexOf(tag+',') == -1) {
    obj.value = obj.value + tag + ',';
  } else {
    obj.value = (obj.value).replace(tag+',', '');
  }
  obj.value = trim(obj.value, ',');
}

// ---------------------------------------------------------------------------
//
function addCheckedTags (openerName, checkName)
{
  if (window.opener.document.F1.elements[document.F1.elements[openerName].value]) {
    var objForm = document.F1;
    var objOpener = window.opener.document.F1.elements[document.F1.elements[openerName].value];

    objOpener.value = trim(objOpener.value);
    objOpener.value = trim(objOpener.value, ',');
    objOpener.value = trim(objOpener.value);
    objOpener.value = objOpener.value + ',';
    for (var i = 0; i < objForm.elements.length; i = i + 1) {
      var obj = objForm.elements[i];
      if (obj != null && obj.type == "checkbox" && obj.name == checkName) {
        if (obj.checked) {
          if (objOpener.value.indexOf(obj.value+',') == -1)
            objOpener.value = objOpener.value + obj.value+',';
        } else {
          objOpener.value = (objOpener.value).replace(obj.value+',', '');
        }
      }
    }
    objOpener.value = trim(objOpener.value, ',');
  }
  window.close();
}

// ---------------------------------------------------------------------------
//
function openBookmark (id)
{
  var c = $(id);
  if (c) {
    OAT.Dom.removeClass(c, 'unread');
    OAT.Dom.addClass(c, 'read');
  }
  readBookmark (id);
}

// ---------------------------------------------------------------------------
//
function openIFrame (id, accountID, uri)
{
  if (accountID > 0) {
    var c = $(id);
    if (c) {
      OAT.Dom.removeClass(c, 'unread');
      OAT.Dom.addClass(c, 'read');
    }
    readBookmark (id);
  }
  document.getElementById('bookmark_content').innerHTML = '<iframe src="'+uri+'" style="margin: -2px 0px 0px 0px;" width="100%" height="100%" frameborder="0" scrolling="auto" hspace="0" vspace="0" marginwidth="0" marginheight="0"></iframe>';
}

// ---------------------------------------------------------------------------
//
function urlParam (fldName)
{
  var S = '';
  var O = document.forms['F1'].elements[fldName];

  if (O)
    S += '&' + fldName + '=' + encodeURIComponent(O.value);
  return S;
}

// ---------------------------------------------------------------------------
//
function showObject(id)
{
  var obj = document.getElementById(id);
  if (obj != null) {
    obj.style.display="";
    obj.visible = true;
  }
}

// ---------------------------------------------------------------------------
//
function hideObject(id)
{
  var obj = document.getElementById(id);
  if (obj != null) {
    obj.style.display="none";
    obj.visible = false;
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

  doPost ('F1', 'btn_Background');
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
      if ((progressIndex != null) && (progressIndex != progressMax) && (timer != null)) {
        setTimeout("checkState()", 500);
      } else {
        hideObject('btn_Background');
        document.getElementById("btn_Stop").value = 'Close';
        timer = null;
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
  if (percentage < 10) {
    percentageText = "&nbsp;" + percentage;
  } else {
    percentageText = percentage;
  }
  centerCell.innerHTML = "<font color=\"white\">" + percentageText + "%</font>";
  for (x = 0; x < size; x++) {
    var cell = window.document.getElementById("progress_" + x);
    if ((cell) && (percentage/x < increment)) {
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
  if (document.forms['F1'].elements['sid'])
    sid = document.forms['F1'].elements['sid'].value;
  var realm = '';
  if (document.forms['F1'].elements['realm'])
    realm = document.forms['F1'].elements['realm'].value;
  var URL = 'ajax.vsp?sid='+sid+'&realm='+realm+'&id='+id+'&a=read';

  var xmlhttp = initRequest();
  xmlhttp.open("POST", URL, false);
  xmlhttp.setRequestHeader("Pragma", "no-cache");
  xmlhttp.send(null);
}

// ---------------------------------------------------------------------------
function davBrowse (fld)
{
  var options = { mode: 'browser',
                  onConfirmClick: function(path, fname) {$(fld).value = path + fname;}
                };
  oWebDAV.open(options);
}
