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
//
function submitEnter(myForm, myButton, e)
{
  var keyCode;
  
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
  for (var i = 0; i < objForm.elements.length; i++)
  {
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
  var element = $(id);
  if (element)
  {
    if (idFlag)
    {
      element.style.display = 'block';
      mode = 'none';
    } else {
      element.style.display = 'none';
      mode = 'block';
    }
  }
  element = $(id_gray);
  if (element)
    element.style.display = mode;
}

// ---------------------------------------------------------------------------
function shCell(cell)
{
  var c = $(cell);
  var i = $(cell+'_image');
  if ((c) && (c.style.display == "none"))
  {
    c.style.display = "";
    if (i)
    {
      i.src = "image/tr_open.gif";
      i.alt = "Close";
    }
  } else {
    c.style.display = "none";
    if (i) {
      i.src = "image/tr_close.gif";
      i.alt = "Open";
    }
  }
}

// ---------------------------------------------------------------------------
function selectAllCheckboxes (obj, prefix)
{
  var objForm = obj.form;
  for (var i = 0; i < objForm.elements.length; i++)
  {
    var o = objForm.elements[i];
    if (o != null && o.type == "checkbox" && !o.disabled && o.name.indexOf (prefix) != -1)
    {
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
function selectAllCheckboxes2 (obj, prefix)
{
	var inputs = document.getElementsByTagName("input");

	for (var i = 0; i < inputs.length; i++)
	{
	  var o = inputs[i];
    if (o != null && o.type == "checkbox" && !o.disabled && o.name.indexOf (prefix) != -1)
    {
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
  obj.focus();
}


// ---------------------------------------------------------------------------
function anySelected (form, txt, selectionMsq)
{
  if ((form != null) && (txt != null))
  {
    for (var i = 0; i < form.elements.length; i++)
    {
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
function coloriseTable(id)
{
  if (document.getElementsByTagName)
  {
    var table = $(id);
    if (table)
    {
      var rows = table.getElementsByTagName("tr");
      for (i = 0; i < rows.length; i++)
      {
        rows[i].className = rows[i].className + " tr_" + (i % 2);;
      }
    }
  }
}

// ---------------------------------------------------------------------------
function coloriseRow(obj, checked)
{
  obj.className = (obj.className).replace('tr_select', '');
  if (checked)
    obj.className = obj.className + ' ' + 'tr_select';
}

// ---------------------------------------------------------------------------
function showTag(tag)
{
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
function sortSelect(box)
{
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
        {
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
function calendarsShow(sPage, width, height)
{
  if ($('ss_type_0').checked)
  {
    sPage = sPage + '&mode=p'
  }
  windowShow(sPage, width, height);
}

// ---------------------------------------------------------------------------
//
function calendarsHelp(mode)
{
  var T = '';
  if ($('ss_type_0').checked)
  {
    T = 'Select Public';
  }
  if ($('ss_type_1').checked)
  {
    T = 'Select Shared';
  }
  $('ss_type_button').value = T;
  if (mode)
    $('ss_calendar').value = '';
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
  {
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
    dstField.value = CAL.trim(dstField.value);
    dstField.value = CAL.trim(dstField.value, ',');
    dstField.value = CAL.trim(dstField.value);
    if (dstField.value.indexOf(srcField.value) == -1)
    {
      if (dstField.value == '')
      {
        dstField.value = srcField.value;
      } else {
        dstField.value = dstField.value + ',' + srcField.value;
      }
    }
  }
}

// ---------------------------------------------------------------------------
//
// Menu functions
//
// ---------------------------------------------------------------------------
function menuMouseIn(a, b)
{
  if (b != undefined)
  {
    while (b.parentNode)
    {
      b = b.parentNode;
      if (b == a)
        return true;
    }
  }
  return false;
}

// ---------------------------------------------------------------------------
//
function menuMouseOut(event)
{
  var current, related;

  if (window.event)
  {
    current = this;
    related = window.event.toElement;
  } else {
    current = event.currentTarget;
    related = event.relatedTarget;
  }

  if ((current != related) && !menuMouseIn(current, related))
    current.style.visibility = "hidden";
}

// ---------------------------------------------------------------------------
//
function menuPopup(button, menuID)
{
  if (document.getElementsByTagName && !document.all)
    document.all = document.getElementsByTagName("*");
  if (document.all)
  {
    for (var i = 0; i < document.all.length; i++)
    {
      var obj = document.all[i];
      if (obj.id.search('exportMenu') != -1)
      {
        obj.style.visibility = 'hidden';
        if (OAT.Browser.isIE)
        {
          obj.onmouseout = menuMouseOut;
        } else {
          obj.addEventListener("mouseout", menuMouseOut, true);
        }
      }
    }
  }

  button.blur();
  var div = $(menuID);
  if (div.style.visibility == 'visible')
  {
    div.style.visibility = 'hidden';
  } else {
    x = button.offsetLeft;
    y = button.offsetTop + button.offsetHeight;
    div.style.left = x - 2 + "px";
    div.style.top  = y - 1 + "px";
    div.style.visibility = 'visible';
  }
  return false;
}

// ---------------------------------------------------------------------------
//
// Hiddens functions
//
// ---------------------------------------------------------------------------
//
function createHidden(frm_name, fld_name, fld_value)
{
  createHidden2(document, frm_name, fld_name, fld_value);
}

// ---------------------------------------------------------------------------
//
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
  }
}

// ---------------------------------------------------------------------------
//
function changeExportName(fld_name, from, to)
{
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
  objForm.s1.value = CAL.trim(objForm.s1.value);
  objForm.s1.value = CAL.trim(objForm.s1.value, ',');
  objForm.s1.value = CAL.trim(objForm.s1.value);
  objForm.s1.value = objForm.s1.value + ',';
  for (var i = 0; i < objForm.elements.length; i = i + 1)
  {
    var obj = objForm.elements[i];
    if (obj != null && obj.type == "checkbox" && obj.name == objName)
    {
      if (obj.checked)
      {
        if (objForm.s1.value.indexOf(obj.value+',') == -1)
        {
          objForm.s1.value = objForm.s1.value + obj.value+',';
        }
      } else {
        objForm.s1.value = (objForm.s1.value).replace(obj.value+',', '');
      }
    }
  }
  objForm.s1.value = CAL.trim(objForm.s1.value, ',');
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
              rowSelectValue(window.opener.document.F1.elements[myArray[1]], window.document.F1.elements[s1], singleMode, submitMode);
          if (myArray[2] == 's2')
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
  obj.value = CAL.trim(obj.value);
  obj.value = CAL.trim(obj.value, ',');
  obj.value = CAL.trim(obj.value);
  obj.value = CAL.trim(obj.value, ',');
  obj.value = (obj.value).replace('  ', ' ');
  obj.value = (obj.value).replace(' ,', ',');
  obj.value = obj.value + ',';
  if (obj.value.indexOf(tag+',') == -1)
  {
    obj.value = obj.value + tag + ',';
  } else {
    obj.value = (obj.value).replace(tag+',', '');
  }
  obj.value = CAL.trim(obj.value);
  obj.value = CAL.trim(obj.value, ',');
  obj.value = CAL.trim(obj.value);
}

// ---------------------------------------------------------------------------
//
function addCheckedTags (openerName, checkName)
{
  if (window.opener.document.F1.elements[document.F1.elements[openerName].value])
  {
    var objForm = document.F1;
    var objOpener = window.opener.document.F1.elements[document.F1.elements[openerName].value];

    objOpener.value = CAL.trim(objOpener.value);
    objOpener.value = CAL.trim(objOpener.value, ',');
    objOpener.value = CAL.trim(objOpener.value);
    objOpener.value = objOpener.value + ',';
    for (var i = 0; i < objForm.elements.length; i = i + 1)
    {
      var obj = objForm.elements[i];
      if (obj != null && obj.type == "checkbox" && obj.name == checkName)
      {
        if (obj.checked) {
          if (objOpener.value.indexOf(obj.value+',') == -1)
            objOpener.value = objOpener.value + obj.value+',';
        } else {
          objOpener.value = (objOpener.value).replace(obj.value+',', '');
        }
      }
    }
    objOpener.value = CAL.trim(objOpener.value, ',');
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
function eEdit(obj, event)
{
  if (typeof(obj) == 'string')
{
    var objID = obj;
  } else {  
  var objID = obj.id;
  }
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
  if (onOffset != null)
  {
  	deleteDialog2.ok = function()
  	{
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
function cNewEvent (event, onDate, onTime)
{
  var srcNode = OAT.Event.source(event);
  if (OAT.Dom.isClass(srcNode, 'CE_new'))
  {
  if (onDate != null)
    createHidden('F1', 'onDate', onDate);
  if (onTime != null)
    createHidden('F1', 'onTime', onTime);
  createHidden('F1', 'select', 'create');
    createHidden('F1', 'mode', 'event');
    doPost ('F1', 'command');
  }
}

// ---------------------------------------------------------------------------
function cExchange (command)
{
  createHidden('F1', 'exchange', command);
  doPost ('F1', 'command');
}

// ---------------------------------------------------------------------------
function cCalendar(calendar_id)
{
  vspxPost('command', 'select', 'settings', 'mode', 'sharedUpdate', 'id', calendar_id);
}

// ---------------------------------------------------------------------------
function exchangeHTML ()
{
  var S, T;

  T = $('ds_navigation');
  if (!T)
    T = $('ds1_navigation');
  if (!T)
    T = $('ds2_navigation');
  if (!T)
    T = $('ds3_navigation');
  if (T)
  {
    S = $('navigation')
    if (S)
      S.innerHTML = T.innerHTML;
    T.innerHTML = '';
  }
}

// ---------------------------------------------------------------------------
function checkRepetition (grpName, checkName)
{
  for (var i = 0; i < document.forms['F1'].elements.length; i++)
  {
    var obj = document.forms['F1'].elements[i];
    if (obj.type == "radio" && obj.name == grpName)
    {
      obj.checked = false;
      if (obj.id == checkName)
        obj.checked = true;
    }
  }
}

// ---------------------------------------------------------------------------
function urlParam (fldName)
{
  var S = '';
  var O = document.forms['F1'].elements[fldName];
  if (O)
    S += '&' + fldName + '=' + encodeURIComponent(O.value);
  return S;
}

// ---------------------------------------------------------------------------
function checkReminder()
{
  var cb = function(txt) {
    setTimeout("checkReminder()", 60000);
    if (txt != "")
    {
      var reminderBody = $("reminderBody");
      if (reminderBody)
      {
        if (OAT.Dimmer.elm != reminderDialog)
          reminderBody.innerHTML = '';
        var xmlDoc = OAT.Xml.createXmlDoc('<root>'+txt+'</root>');
	      var root = xmlDoc.documentElement;
        var reminderTRs = root.getElementsByTagName('tr');
  		  for (var i=0; i<reminderTRs.length; i++) {
  		    var tr = reminderTRs[i];
  		    if (!$(tr.id))
  		    {
            reminderBody.innerHTML += OAT.Xml.serializeXmlDoc(tr);
          }
  		  }
        coloriseTable('reminderTable');
    	  reminderDialog.show();
      }
    }
  }
  OAT.AJAX.POST("ajax.vsp", "a=alarms&sa=list"+urlParam("sid")+urlParam("realm"), cb, {type:OAT.AJAX.TYPE_TEXT, onstart:function(){}, onerror:function(){}});
}

// ---------------------------------------------------------------------------
function dismissReminder(prefix, mode)
{
	var inputs = document.getElementsByTagName("input");
	var reminders = "";
	for (var i = 0; i < inputs.length; i++)
	{
	  var o = inputs[i];
    if (o != null && o.type == "checkbox" && !o.disabled && o.name.indexOf (prefix) != -1)
    {
      if (o.checked || mode)
        reminders = reminders + "," + o.value;
    }
  }
  OAT.AJAX.POST("ajax.vsp", "a=alarms&sa=dismiss&reminders="+reminders+urlParam("sid")+urlParam("realm"), function(){}, {onstart:function(){}, onerror:function(){}});
	reminderDialog.hide ();
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
function changeComplete ()
{
  return;
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
var CAL = new Object();

CAL.trim = function (sString, sChar)
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

CAL.updateClaim = function (claimNo)
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

CAL.aboutDialog = function ()
{
  var aboutDiv = $('aboutDiv');
  if (aboutDiv) {OAT.Dom.unlink(aboutDiv);}
  aboutDiv = OAT.Dom.create('div', {width:'400px', height:'150px'});
  aboutDiv.id = 'aboutDiv';
  aboutDialog = new OAT.Dialog('About ODS Calendar', aboutDiv, {width:400, buttons: 0, resize:0, modal:1});
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
