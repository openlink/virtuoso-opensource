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
var BrowserDetect = {
  init: function () {
    this.browser = this.searchString(this.dataBrowser) || "An unknown browser";
    this.version = this.searchVersion(navigator.userAgent)
      || this.searchVersion(navigator.appVersion)
      || "an unknown version";
    this.OS = this.searchString(this.dataOS) || "an unknown OS";
  },
  searchString: function (data) {
    for (var i=0;i<data.length;i++)  {
      var dataString = data[i].string;
      var dataProp = data[i].prop;
      this.versionSearchString = data[i].versionSearch || data[i].identity;
      if (dataString) {
        if (dataString.indexOf(data[i].subString) != -1)
          return data[i].identity;
      }
      else if (dataProp)
        return data[i].identity;
    }
  },
  searchVersion: function (dataString) {
    var index = dataString.indexOf(this.versionSearchString);
    if (index == -1) return;
    return parseFloat(dataString.substring(index+this.versionSearchString.length+1));
  },
  dataBrowser: [
    { String: navigator.userAgent,
      subString: "OmniWeb",
      versionSearch: "OmniWeb/",
      identity: "OmniWeb"
    },
    {
      string: navigator.vendor,
      subString: "Apple",
      identity: "Safari"
    },
    {
      prop: window.opera,
      identity: "Opera"
    },
    {
      string: navigator.vendor,
      subString: "iCab",
      identity: "iCab"
    },
    {
      string: navigator.vendor,
      subString: "KDE",
      identity: "Konqueror"
    },
    {
      string: navigator.userAgent,
      subString: "Firefox",
      identity: "Firefox"
    },
    {
      string: navigator.vendor,
      subString: "Camino",
      identity: "Camino"
    },
    {    // for newer Netscapes (6+)
      string: navigator.userAgent,
      subString: "Netscape",
      identity: "Netscape"
    },
    {
      string: navigator.userAgent,
      subString: "MSIE",
      identity: "Explorer",
      versionSearch: "MSIE"
    },
    {
      string: navigator.userAgent,
      subString: "Gecko",
      identity: "Mozilla",
      versionSearch: "rv"
    },
    {     // for older Netscapes (4-)
      string: navigator.userAgent,
      subString: "Mozilla",
      identity: "Netscape",
      versionSearch: "Mozilla"
    }
  ],
  dataOS : [
    {
      string: navigator.platform,
      subString: "Win",
      identity: "Windows"
    },
    {
      string: navigator.platform,
      subString: "Mac",
      identity: "Mac"
    },
    {
      string: navigator.platform,
      subString: "Linux",
      identity: "Linux"
    }
  ]

};
BrowserDetect.init();

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
function getParent (obj, tag)
{
  var obj = obj.parentNode;
  if (obj.tagName.toLowerCase() == tag)
    return obj;
  return getParent(obj, tag);
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
  for (var i = 0; i < objForm.elements.length; i++) {
    var o = objForm.elements[i];
    if (o != null && o.type == 'checkbox' && !o.disabled && o.name.indexOf (prefix) != -1 && o.checked)
      oCount += 1;
  }
  enableElement('tbTag', 'tbTag_gray', oCount>0);
  enableElement('tbDelete', 'tbDelete_gray', oCount>0);
}

// ---------------------------------------------------------------------------
function enableElement (id, id_gray, idFlag)
{
  var mode = 'block';
  var element = document.getElementById(id);
  if (element != null) {
    if (idFlag) {
      element.style.display = 'block';
      mode = 'none';
    } else {
      element.style.display = 'none';
      mode = 'block';
    }
  }
  element = document.getElementById(id_gray);
  if (element != null)
    element.style.display = mode;
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
function shCell(cell)
{
  var c = getObject(cell);
  if ((c) && (c.style.display == "none")) {
    c.style.display = "";
  } else {
    c.style.display = "none";
  }
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
function showTab(tab, tabs)
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
          divTab.className = "tab activeTab";
          divTab.blur();
        };
      } else {
        div.style.visibility = 'hidden';
        div.style.display = 'none';
        if (divTab != null)
          divTab.className = "tab";
      }
    }
  }
}

// ---------------------------------------------------------------------------
//
function initTab(tabs, defaultNo)
{
  var divNo = document.getElementById('tabNo');
  var tab = defaultNo;
  if (divNo != null) {
    var divTab = document.getElementById('tab_'+divNo.value);
    if (divTab != null)
      tab = divNo.value;
  }
  showTab(tab, tabs);
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
        dstField.value = dstField.value + ',' + srcField.value;
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
function cSelect(obj)
{
  var objID = obj.id;

  createHidden('F1', 'select', objID);
  doPost ('F1', 'command');
}

// ---------------------------------------------------------------------------
function eEdit(obj)
{
  var objID = obj.id;

  createHidden('F1', 'edit', objID);
  doPost ('F1', 'command');
}

// ---------------------------------------------------------------------------
function eDate(obj)
{
  var objID = obj.id;

  createHidden('F1', 'date', objID);
  doPost ('F1', 'command');
}

// ---------------------------------------------------------------------------
function eDelete(event, obj, onOffset)
{
  event.cancelBubble = true;

	// delete dialog
  if (onOffset != null) {
  	deleteDialog2.ok = function() {
  		deleteDialog2.hide();
      if ($('e_delete_0').checked)
        createHidden('F1', 'onOffset', onOffset);
      createHidden('F1', 'delete', obj.id);
    doPost ('F1', 'command');
  }
  	deleteDialog2.cancel = deleteDialog2.hide;
  	deleteDialog2.show ();
  } else {
  	deleteDialog.ok = function() {
      createHidden('F1', 'delete', obj.id);
      doPost ('F1', 'command');
  		deleteDialog.hide();
   	}
   	deleteDialog.cancel = deleteDialog.hide;
  	deleteDialog.show ();
  }
  return false;
}

// ---------------------------------------------------------------------------
function eAnnotea(event, id, domain_id, account_id)
{
  event.cancelBubble = true;

  URL = 'annotea.vspx?sid=' + document.forms[0].sid.value + '&realm=' + document.forms[0].realm.value + '&oid=' + id + '&did=' + domain_id + '&aid=' + account_id;
  window.open (URL, 'addressbook_anotea_window', 'top=100, left=100, scrollbars=yes, resize=yes, menubar=no, height=500, width=600');
  return false;
}

// ---------------------------------------------------------------------------
function cNewEvent (onDate, onTime)
{
  if (onDate != null)
    createHidden('F1', 'onDate', onDate);
  if (onTime != null)
    createHidden('F1', 'onTime', onTime);
  createHidden('F1', 'select', 'create');
  doPost ('F1', 'command');
}

// ---------------------------------------------------------------------------
function cExchange (command)
{
  createHidden('F1', 'exchange', command);
  doPost ('F1', 'command');
}

// ---------------------------------------------------------------------------
function exchangeHTML ()
{
  var S, T;

  T = 'ds_navigation';
  S = $(T).innerHTML;
  if (S == null || S == '') {
    T = 'ds1_navigation';
    S = $(T).innerHTML;
  }
  if (S == null || S == '') {
    T = 'ds2_navigation';
    S = $(T).innerHTML;
  }
  if (S == null || S == '') {
    T = 'ds3_navigation';
    S = $(T).innerHTML;
  }
  $('navigation').innerHTML = S;
  $(T).innerHTML = '';
}

// ---------------------------------------------------------------------------
function checkRepetition (grpName, checkName)
{
  for (var i = 0; i < document.forms['F1'].elements.length; i++) {
    var obj = document.forms['F1'].elements[i];
    if (obj.type == "radio" && obj.name == grpName) {
      obj.checked = false;
      if (obj.id == checkName)
        obj.checked = true;
    }
  }
}
