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
  if (divNo != null)
  {
    var divTab = document.getElementById('tab_'+divNo.value);
    if (divTab != null)
      tab = divNo.value;
  }
  showTab2(tab, tabs);
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
  OAT.WebDav.open(options);
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

// ---------------------------------------------------------------------------
var OMAIL = new Object();

OMAIL.forms = new Object();

OMAIL.trim = function (sString, sChar)
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

OMAIL.writeCookie = function (name, value, hours)
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

OMAIL.readCookie = function (name)
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

OMAIL.readField = function (field, doc)
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

OMAIL.createParam = function (field, doc)
{
  var S = '';
  var v = OMAIL.readField(field, doc);
  if (v)
    S = '&'+field+'='+ encodeURIComponent(v);
  return S;
}

OMAIL.sessionParams = function (doc)
{
  return OMAIL.createParam('sid', doc)+OMAIL.createParam('realm', doc);
}

OMAIL.initState = function (state)
{
  if (!state)
    var state = new Object();

  state.sid = OMAIL.readField('sid');
  state.realm = OMAIL.readField('realm');

  return state;
}

OMAIL.saveState = function ()
{
  OMAIL.writeCookie('OMAIL_State', escape(OAT.JSON.stringify(OMAIL.state)), 1);
}

OMAIL.init = function ()
{
  // load cookie data
  var s = OMAIL.readCookie('OMAIL_State');
  if (s)
  {
    try {
      s = OAT.JSON.parse(unescape(s));
    } catch (e) { s = null; }
    s = OMAIL.initState(s);
  } else {
    s = OMAIL.initState();
  }
  OMAIL.state = s;
}

OMAIL.initFilter = function ()
{
  // load filters data
  var x = function(data) {
    var o = OAT.JSON.parse(data);
    OMAIL.searchPredicates = o[0];
    OMAIL.searchCompares = o[1];
    OMAIL.searchActions = o[2];
    OMAIL.searchFolders = o[3];
  }
  OAT.AJAX.GET('action.vsp?a=search&sa=metas'+OMAIL.sessionParams(), '', x, {async:false});
}

OMAIL.formParams = function (doc)
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

OMAIL.searchRowAction = function (rowID)
{
  var tbody = $('search_tbody');
  if (tbody)
  {
    var seqNo = parseInt($v('search_seqNo'));
    if (seqNo == rowID)
    {
      var img = $('search_img_3_' + seqNo);
      if (img)
        img.src = '/oMail/i/del_16.png';
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
      OMAIL.searchRowCreate(seqNo);
    }
    else
    {
      OAT.Dom.unlink('search_tr_'+rowID);
    }
  }
}

OMAIL.searchRowCreate = function (rowID, values)
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
    OMAIL.searchColumnCreate(rowID, 0, values['field_0']);

    var td = OAT.Dom.create('td');
    td.id = 'search_td_1_' + rowID;
    tr.appendChild(td);
    if (values['field_1'])
      OMAIL.searchColumnCreate(rowID, 1, values['field_1']);

    var td = OAT.Dom.create('td');
    td.id = 'search_td_2_' + rowID;
    tr.appendChild(td);
    if (values['field_2'])
      OMAIL.searchColumnCreate(rowID, 2, values['field_2']);

    var td = OAT.Dom.create('td');
    td.id = 'search_td_3_' + rowID;
    var imgSrc = (seqNo != rowID)? '/oMail/i/del_16.png': '/oMail/i/add_16.png';
    var img = OAT.Dom.image(imgSrc);
    img.id = 'search_img_3_' + rowID;
    img.onclick = function (){OMAIL.searchRowAction(rowID)};
    td.appendChild(img);
    tr.appendChild(td);
  }
}

OMAIL.searchColumnsInit = function (rowID, columnNo)
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
      OMAIL.searchColumnCreate(rowID, columnNo)
    }
  }
}

OMAIL.searchColumnCreate = function (rowID, columnNo, columnValue)
{
  var tr = $('search_tr_' + rowID);
  if (tr)
  {
    var td = $('search_td_' + columnNo + '_' + rowID);
    if (td)
    {
      var predicate = OMAIL.searchGetPredicate(rowID);
      if (columnNo == 0)
      {
        var field = OAT.Dom.create('select');
        field.id = 'search_field_' + columnNo + '_' + rowID;
        field.name = field.id;
        field.style.width = '95%';
        OAT.Dom.option('', '', field);
        for (var i = 0; i < OMAIL.searchPredicates.length; i = i + 2)
        {
          if (OMAIL.searchPredicates[i+1][0] == 1)
          {
            OAT.Dom.option(OMAIL.searchPredicates[i+1][1], OMAIL.searchPredicates[i], field);
          }
        }
        if (columnValue)
          field.value = columnValue;
        field.onchange = function(){OMAIL.searchColumnChange(this)};
        td.appendChild(field);
      }
      if (predicate && (columnNo == 1))
      {
        var field = OAT.Dom.create('select');
        field.id = 'search_field_' + columnNo + '_' + rowID;
        field.name = field.id;
        field.style.width = '95%';
        OAT.Dom.option('', '', field);
        var predicateType = predicate[2];
        for (var i = 0; i < OMAIL.searchCompares.length; i = i + 2)
        {
          var compareTypes = OMAIL.searchCompares[i+1][1];
          for (var j = 0; j < compareTypes.length; j++)
          {
            if (compareTypes[j] == predicateType)
            {
              OAT.Dom.option(OMAIL.searchCompares[i+1][0], OMAIL.searchCompares[i], field);
            }
          }
        }
        if (columnValue)
          field.value = columnValue;
        field.onchange = function(){OMAIL.searchColumnChange(this)};
        td.appendChild(field);
      }
      if (predicate && (columnNo == 2))
      {
        var fieldCompare = $('search_field_1_' + rowID);
        if (!fieldCompare) {return;}
        var compare;
        for (var i = 0; i < OMAIL.searchCompares.length; i = i + 2)
        {
          if (OMAIL.searchCompares[i] == fieldCompare.value)
          {
            compare = OMAIL.searchCompares[i+1];
          }
        }
        if (!compare) {return;}
        if (compare[2] == 0) {return;}
        if (predicate[2] == 'priority')
        {
          var field = OAT.Dom.create("select");
          OAT.Dom.option('Normal', '3', field);
          OAT.Dom.option('Lowest', '5', field);
          OAT.Dom.option('Low', '4', field);
          OAT.Dom.option('High', '2', field);
          OAT.Dom.option('Highest', '1', field);
        }
        else
        {
          var field = OAT.Dom.create("input");
          field.type = 'text';
        }
        field.id = 'search_field_' + columnNo + '_' + rowID;
        field.name = field.id;
        field.style.width = '93%';
        if (columnValue)
          field.value = columnValue;
        td.appendChild(field);

        for (var i = 0; i < predicate[4].length; i = i + 2)
        {
          if (predicate[4][i] == 'size')
          {
            field['size'] = predicate[4][i+1];
            field.style.width = null;
          }
          if (predicate[4][i] == 'onclick')
          {
            OAT.Event.attach(field, "click", new Function((predicate[4][i+1]).replace(/-FIELD-/g, field.id)));
          }
          if (predicate[4][i] == 'button')
          {
            var span = OAT.Dom.create("span");
            span.innerHTML = ' ' + (predicate[4][i+1]).replace(/-FIELD-/g, field.id);
            td.appendChild(span);
          }
        }
      }
    }
  }
}

OMAIL.searchColumnChange = function (obj)
{
  var parts = obj.id.split('_');
  var columnNo = parseInt(parts[2]);
  var rowID = parts[3];
  var predicate = OMAIL.searchGetPredicate(rowID);
  if (columnNo == 0)
  {
    OMAIL.searchColumnsInit(rowID, 1);
    if (obj.value == '') {return;}
    if (predicate) {OMAIL.searchColumnCreate(rowID, 1);}
  }
  if (columnNo == 1)
  {
    OMAIL.searchColumnsInit(rowID, 2);
    if (obj.value == '') {return;}
    if (predicate) {OMAIL.searchColumnCreate(rowID, 2);}
  }
}

OMAIL.searchGetPredicate = function (rowID)
{
  var field = $('search_field_0_' + rowID)
  if (field)
  {
    for (var i = 0; i < OMAIL.searchPredicates.length; i = i + 2)
    {
      if (OMAIL.searchPredicates[i] == field.value)
      {
        return OMAIL.searchPredicates[i+1];
      }
    }
  }
  return null;
}

OMAIL.searchGetCompares = function (predicate)
{
  if (predicate)
  {
  }
  return null;
}

OMAIL.actionRowAction = function (rowID)
{
  var tbody = $('action_tbody');
  if (tbody)
  {
    var seqNo = parseInt($v('action_seqNo'));
    if (seqNo == rowID)
    {
      var img = $('action_img_2_' + seqNo);
      if (img)
        img.src = '/oMail/i/del_16.png';
      OAT.Dom.unlink('action_tr');
      var tr = OAT.Dom.create('tr');
      tr.id = 'action_tr';
      var td = OAT.Dom.create('td');
      td.colSpan = '6';
      td.appendChild(OAT.Dom.create('hr'));
      tr.appendChild(td);
      tbody.appendChild(tr);

      seqNo++;
      $('action_seqNo').value = seqNo;
      OMAIL.actionRowCreate(seqNo);
    }
    else
    {
      OAT.Dom.unlink('action_tr_'+rowID);
    }
  }
}

OMAIL.actionRowCreate = function (rowID, values)
{
  var tbody = $('action_tbody');
  if (tbody)
  {
    var seqNo = parseInt($v('action_seqNo'));
    var tr = OAT.Dom.create('tr');
    tr.id = 'action_tr_' + rowID;
    if (seqNo != rowID)
    {
      tr_line = $('action_tr');
      tbody.insertBefore(tr, tr_line);
    }
    else
    {
      tbody.appendChild(tr);
    }
    if (!values)
      values = new Object();

    var td = OAT.Dom.create('td');
    td.id = 'action_td_0_' + rowID;
    tr.appendChild(td);
    OMAIL.actionColumnCreate(rowID, 0, values['field_0']);

    var td = OAT.Dom.create('td');
    td.id = 'action_td_1_' + rowID;
    tr.appendChild(td);
    if (values['field_1'])
      OMAIL.actionColumnCreate(rowID, 1, values['field_1']);

    var td = OAT.Dom.create('td');
    td.id = 'action_td_2_' + rowID;
    var imgSrc = (seqNo != rowID)? '/oMail/i/del_16.png': '/oMail/i/add_16.png';
    var img = OAT.Dom.image(imgSrc);
    img.id = 'action_img_2_' + rowID;
    img.onclick = function (){OMAIL.actionRowAction(rowID)};
    td.appendChild(img);
    tr.appendChild(td);
  }
}

OMAIL.actionColumnsInit = function (rowID, columnNo)
{
  var tr = $('action_tr_' + rowID);
  if (tr)
  {
    var tds = tr.getElementsByTagName("td");
    for (var i = columnNo; i < tds.length-1; i++)
    {
      tds[i].innerHTML = '';
    }
    if (columnNo == 0)
    {
      OMAIL.actionColumnCreate(rowID, columnNo)
    }
  }
}

OMAIL.actionColumnCreate = function (rowID, columnNo, columnValue)
{
  var tr = $('action_tr_' + rowID);
  if (tr)
  {
    var td = $('action_td_' + columnNo + '_' + rowID);
    if (td)
    {
      var predicate = OMAIL.actionGetPredicate(rowID);
      if (columnNo == 0)
      {
        var field = OAT.Dom.create('select');
        field.id = 'action_field_' + columnNo + '_' + rowID;
        field.name = field.id;
        field.style.width = '95%';
        OAT.Dom.option('', '', field);
        for (var i = 0; i < OMAIL.searchActions.length; i = i + 2)
        {
          if (OMAIL.searchActions[i+1][0] == 1)
          {
            OAT.Dom.option(OMAIL.searchActions[i+1][1], OMAIL.searchActions[i], field);
          }
        }
        if (columnValue)
          field.value = columnValue;
        field.onchange = function(){OMAIL.actionColumnChange(this)};
        td.appendChild(field);
      }
      if (columnNo == 1)
      {
        var value_0 = $v('action_field_0_' + rowID);
        if (value_0 && (value_0 != ''))
        {
          var fieldParams;
          for (var i = 0; i < OMAIL.searchActions.length; i = i + 2)
          {
            if ((OMAIL.searchActions[i] == value_0) && (OMAIL.searchActions[i+1][0] == 1))
            {
              fieldParams = OMAIL.searchActions[i+1];
            }
          }
          if (fieldParams)
          {
            if (fieldParams[2])
            {
              if (fieldParams[2] == 'input')
              {
                var field = OAT.Dom.create("input");
                field.type = 'text';
              }
              else if (fieldParams[2] == 'select')
              {
                var field = OAT.Dom.create("select");
                if (fieldParams[3] == 'folder')
                {
                  for (var i = 0; i < OMAIL.searchFolders.length; i = i + 2)
                  {
                    OAT.Dom.option(OMAIL.searchFolders[i+1], OMAIL.searchFolders[i], field);
                  }
                }
                else if (fieldParams[3] == 'priority')
                {
                  OAT.Dom.option('Normal', '3', field);
                  OAT.Dom.option('Lowest', '5', field);
                  OAT.Dom.option('Low', '4', field);
                  OAT.Dom.option('High', '2', field);
                  OAT.Dom.option('Highest', '1', field);
                }
              }
              field.id = 'action_field_' + columnNo + '_' + rowID;
              field.name = field.id;
              field.style.width = '93%';
              if (columnValue)
                field.value = columnValue;
              td.appendChild(field);
            }
          }
        }
      }
    }
  }
}

OMAIL.actionColumnChange = function (obj)
{
  var parts = obj.id.split('_');
  var columnNo = parseInt(parts[2]);
  var rowID = parts[3];
  var predicate = OMAIL.actionGetPredicate(rowID);
  if (columnNo == 0)
  {
    OMAIL.actionColumnsInit(rowID, 1);
    if (obj.value == '') {return;}
  }
  if (predicate)
  {
    OMAIL.actionColumnCreate(rowID, 1)
  }
}

OMAIL.actionGetPredicate = function (rowID)
{
  var field = $('action_field_0_' + rowID)
  if (field)
  {
    for (var i = 0; i < OMAIL.searchActions.length; i = i + 2)
    {
      if (OMAIL.searchActions[i] == field.value)
      {
        return OMAIL.searchActions[i+1];
      }
    }
  }
  return null;
}
