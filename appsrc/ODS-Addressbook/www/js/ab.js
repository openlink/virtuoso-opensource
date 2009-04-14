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
function myTags(fValue)
{
  createHidden('F1', 'tag', fValue);
  vspxPost('pt_browse', 'pt_action', 'tags', 'pt_value', fValue);
}

// ---------------------------------------------------------------------------
function myCategory(fValue)
{
  vspxPost('pt_browse', 'pt_action', 'category', 'pt_value', fValue);
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
function toolbarPost(fValue)
{
  vspxPost('command', 'select', fValue);
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
  enableElement('tbSharing', 'tbSharing_gray', oCount>0);
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
        if (c)
          OAT.Dom.show(c);
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
    dstField.value = AB.trim(dstField.value);
    dstField.value = AB.trim(dstField.value, ',');
    dstField.value = AB.trim(dstField.value);
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
    for (var i = 0; i < from.length; ++i)
      obj.value = (obj.value).replace(from[i], to);
}

// ---------------------------------------------------------------------------
//
function updateChecked (obj, objName)
{
  var objForm = obj.form;
  coloriseRow(getParent(obj, 'tr'), obj.checked);
  objForm.s1.value = AB.trim(objForm.s1.value);
  objForm.s1.value = AB.trim(objForm.s1.value, ',');
  objForm.s1.value = AB.trim(objForm.s1.value);
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
  objForm.s1.value = AB.trim(objForm.s1.value, ',');
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
  obj.value = AB.trim(obj.value);
  obj.value = AB.trim(obj.value, ',');
  obj.value = AB.trim(obj.value);
  obj.value = (obj.value).replace('  ', ' ');
  obj.value = (obj.value).replace(' ,', ',');
  obj.value = obj.value + ',';
  if (obj.value.indexOf(tag+',') == -1) {
    obj.value = obj.value + tag + ',';
  } else {
    obj.value = (obj.value).replace(tag+',', '');
  }
  obj.value = AB.trim(obj.value, ',');
}

// ---------------------------------------------------------------------------
function addCheckedTags (openerName, checkName)
{
  if (window.opener.document.F1.elements[document.F1.elements[openerName].value]) {
    var objForm = document.F1;
    var objOpener = window.opener.document.F1.elements[document.F1.elements[openerName].value];

    objOpener.value = AB.trim(objOpener.value);
    objOpener.value = AB.trim(objOpener.value, ',');
    objOpener.value = AB.trim(objOpener.value);
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
    objOpener.value = AB.trim(objOpener.value, ',');
  }
  window.close();
}

// ---------------------------------------------------------------------------
function changeType (obj)
{
  showTab(1, 4); 
  if (obj.value != "1") {
    OAT.Dom.show ('a_tab_1');
    OAT.Dom.show ('a_tab_2');
  } else {
    OAT.Dom.hide ('a_tab_1');
    OAT.Dom.hide ('a_tab_2');
}
	var trNodes = document.getElementsByTagName("tr");

	for (var i = 0; i < trNodes.length; i++) {
	  var tr = trNodes[i];
	  if (OAT.Dom.isClass(tr, 'contactType'))
      if (obj.value != "1") {
	      OAT.Dom.show (tr);
  } else {
	      OAT.Dom.hide (tr);
  }
}

}

// ---------------------------------------------------------------------------
function hasError(root) {
	if (!root) {
    // executingEnd();
		alert('No data!');
		return true;
	}

	/* error */
	var error = root.getElementsByTagName('error')[0];
  if (error)
  {
	  var code = error.getElementsByTagName('code')[0];
    if (OAT.Xml.textValue(code) != 'OK')
    {
	    var message = error.getElementsByTagName('message')[0];
      if (message)
        alert (OAT.Xml.textValue(message));
  		return true;
    }
  }
  return false;
}

// ---------------------------------------------------------------------------
function updateState(countryName, stateName, stateValue)
{
  var span = $('span_'+stateName);
  span.innerHTML = "";

  var cc = new OAT.Combolist([], "");
  cc.input.name = stateName;
  cc.input.id = stateName;
  cc.input.size = "60";
  cc.addOption("");

  span.appendChild(cc.div);

  if ($v(countryName) != '')
  {
    var wsdl = "/ods_services/services.wsdl";
    var serviceName = "ODS_USER_LIST";

    var inputObject = {
    	ODS_USER_LIST:{
        pSid:document.forms['F1'].elements['sid'].value,
        pRealm:document.forms['F1'].elements['realm'].value,
        pList:'Province',
        pParam:$v(countryName)
    	}
    }
  	var x = function(xml) {
  	  listCallback(xml, cc, stateValue);
  	}
  	OAT.WS.invoke(wsdl, serviceName, x, inputObject);
  }
}

// ---------------------------------------------------------------------------
function listCallback (result, cc, objValue)
{
  var xml = OAT.Xml.createXmlDoc(result.ODS_USER_LISTResponse.CallReturn);
	var root = xml.documentElement;
	if (!hasError(root))
	{
    /* options */
  	var items = root.getElementsByTagName("item");
  	if (items.length)
  	{
  		for (var i=1; i<=items.length; i++)
  		{
        cc.addOption(OAT.Xml.textValue(items[i-1]));
  		}
  	}
	}
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
function changeState (obj, fName)
{
  if (obj)
  {
    if (obj.type == "checkbox" && obj.checked)
    {
      document.F1.elements[fName].disabled = false;
    } else {
      document.F1.elements[fName].disabled = true;
    }
  } else {
    document.F1.elements[fName].disabled = false;
  }
}

// ---------------------------------------------------------------------------
function exchangeHTML ()
{
  var S, T;

  T = $('ds_navigation');
  if (T)
  {
    S = $('navigation')
    if (S)
      S.innerHTML = T.innerHTML;
    T.innerHTML = '';
  }
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
var AB = new Object();

AB.trim = function (sString, sChar)
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

AB.getFOAFData = function (iri)
{
  var S = '/ods/api/user.getFOAFData?foafIRI='+encodeURIComponent(iri);
  var x = function(data) {
    var o = null;
    try {
      o = OAT.JSON.parse(data);
    } catch (e) { o = null; }
    if (o && o.iri)
    {
      if (confirm('New data for \''+o.iri+'\' is founded. Do you like to fill in the corresponding fields?'))
      {
        AB.setFOAFValue(o.iri, 'ab_iri');
        AB.setFOAFValue(o.nick, 'ab_name');
        AB.setFOAFValue(o.tirle, 'ab_title');
        AB.setFOAFValue(o.name, 'ab_fullName');
        AB.setFOAFValue(o.firstName, 'ab_fName');
        AB.setFOAFValue(o.family_name, 'ab_lName');
        AB.setFOAFValue(o.mbox, 'ab_mail');
        AB.setFOAFValue(o.birthday, 'ab_birthday');
        AB.setFOAFValue(o.gender, 'ab_gender');
        AB.setFOAFValue(o.icqChatID, 'ab_icq');
        AB.setFOAFValue(o.msnChatID, 'ab_msn');
        AB.setFOAFValue(o.aimChatID, 'ab_aim');
        AB.setFOAFValue(o.yahooChatID, 'ab_yahoo');
        AB.setFOAFValue(o.workplaceHomepage, 'ab_web');
        AB.setFOAFValue(o.homepage, 'ab_hWeb');
        AB.setFOAFValue(o.lat, 'ab_hLat');
        AB.setFOAFValue(o.lng, 'ab_hLng');
        AB.setFOAFValue(o.phone, 'ab_hPhone');
        AB.setFOAFValue(o.organizationHomepage, 'ab_bWeb');
        AB.setFOAFValue(o.organizationTitle, 'ab_bOrganization');
        AB.setFOAFValue(o.tags, 'ab_tags');
        // photo
        if (o.depiction)
        {
          AB.setFOAFValue(o.depiction, 'ab_photo_url');
          $('ab_photo_url').onchange();
          $('ab_photo_upload').onclick();
          $('ab_photo_source_1').checked = true;
          $('ab_photo_source_1').onchange();
        }
        // intersts
        if (o.interest)
        {
          var S = o.interest.split ("\n");
          for (var i = 0; i < S.length; i++)
          {
            var T = S[i].split(";");
            if (T.length > 0 && T[0].length > 0)
            {
              if (T.length == 1)
                T.push('');
              AB.updateRow('a', null, {fld1: {value: T[0], className: '_validate_ _url_ _canEmpty_', onBlur: function(){validateField(this);}}, fld2: {value: T[1]}});
      }
    }
  }
      }
    } else {
      alert('No data founded for \''+iri+'\'');
    }
  }
  OAT.AJAX.GET(S, '', x, {onstart: function(){OAT.Dom.show('ab_import_image')}, onend: function(){OAT.Dom.hide('ab_import_image')}});
}

AB.setFOAFValue = function (fValue, fName)
{
  var fElement = document.forms[0].elements[fName];
  if (fValue && fElement)
  {
    if (fElement.type == 'select-one')
    {
      var o = fElement.options;
    	for (var i=0; i< o.length; i++)
    	{
    		if (o[i].value == fValue)
    		{
    		  o[i].selected = true;
    		  o[i].defaultSelected = true;
    		}
    	}
    } else {
      fElement.value = fValue;
    }
  }
}

AB.updateClaim = function (claimNo)
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

AB.aboutDialog = function ()
{
  var aboutDiv = $('aboutDiv');
  if (aboutDiv) {OAT.Dom.unlink(aboutDiv);}
  aboutDiv = OAT.Dom.create('div', {width:'430px', height:'150px'});
  aboutDiv.id = 'aboutDiv';
  aboutDialog = new OAT.Dialog('About ODS AddressBook', aboutDiv, {width:430, buttons: 0, resize:0, modal:1});
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

AB.getFileName = function (from, to)
{
  var S = from.value;
  var N;
  if (S.lastIndexOf('\\') > 0)
  {
    N = S.lastIndexOf('\\') + 1;
  } else {
    N = S.lastIndexOf('/') + 1;
  }
  var S = S.substr(N, S.length);
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
  to.value = S;
}

AB.updateRow = function (prefix, No, optionObject)
{
  if (No != null)
  {
    OAT.Dom.unlink(prefix+'_tr_'+No);
    var No = parseInt($(prefix+'_no').value);
    for (var N = 0; N < No; N++)
    {
      if ($(prefix+'_tr_' + N))
        return;
    }
    OAT.Dom.show (prefix+'_tr_no');
  }
  else
  {
    var No = parseInt($v(prefix+'_no'));
    var tbl = $(prefix+'_tbl');
    if (tbl)
    {
      options = {};
      for (var p in optionObject) {options[p] = optionObject[p]; }

      OAT.Dom.hide (prefix+'_tr_no');

      var tr = OAT.Dom.create('tr');
      tr.id = prefix+'_tr_' + No;
      tbl.appendChild(tr);

      var fldOptions = options.fld1;
      if (fldOptions)
      {
      var td = OAT.Dom.create('td');
      tr.appendChild(td);
        AB.updateCell (td, prefix, '_fld_1_', No, fldOptions)
      }
      var fldOptions = options.fld2;
      if (fldOptions)
      {
      var td = OAT.Dom.create('td');
      tr.appendChild(td);
        AB.updateCell (td, prefix, '_fld_2_', No, fldOptions)
        }
      var fldOptions = options.fld3;
      if (fldOptions)
      {
        var td = OAT.Dom.create('td');
        tr.appendChild(td);
        AB.updateCell (td, prefix, '_fld_3_', No, fldOptions)
      }
      var td = OAT.Dom.create('td');
      tr.appendChild(td);
 		  var fld = OAT.Dom.create("input");
 		  fld.type = 'button';
 		  fld.value = 'Remove';
 		  fld.className = 'button';
      fld.onclick = function (){AB.updateRow(prefix, No);};
      td.appendChild(fld);

      $(prefix+'_no').value = No + 1;
    }
  }
}

AB.updateCell = function (td, prefix, fldName, No, optionObject)
{
  fldName = prefix + fldName + No;
  if (optionObject.mode == 1)
  {
	  AB.updateRowCombo(td, fldName, optionObject);
	}
  else if (optionObject.mode == 2)
  {
	  AB.updateRowCombo2(td, fldName, optionObject);
  }
  else if (optionObject.mode == 3)
  {
	  AB.updateRowCombo3(td, fldName, optionObject);
  }
  else
  {
	  AB.updateInput(td, fldName, optionObject);
  }
}

AB.updateInput = function (elm, fldName, fldOptions)
{
  var fld = OAT.Dom.create("input");
  fld.type = 'text';
  fld.id = fldName;
  fld.name = fld.id;
  if (fldOptions.value)
    fld.value = fldOptions.value;
  fld.className = fldOptions.className;
  fld.onblur = fldOptions.onBlur;
  fld.style.width = '95%';
  var elm = $(elm);
  elm.appendChild(fld);
}

AB.updateRowCombo = function (elm, fldName, fldOptions)
{
  var cc = new OAT.Combolist([], fldOptions.value, {name: fldName});

  cc.input.name = fldName;
  cc.input.id = fldName;
  cc.input.style.width = "90%";
  AB.updateRowComboOption(cc, 'rel:acquaintanceOf');
  AB.updateRowComboOption(cc, 'rel:ambivalentOf');
  AB.updateRowComboOption(cc, 'rel:ancestorOf');
  AB.updateRowComboOption(cc, 'rel:antagonistOf');
  AB.updateRowComboOption(cc, 'rel:apprenticeTo');
  AB.updateRowComboOption(cc, 'rel:childOf');
  AB.updateRowComboOption(cc, 'rel:closeFriendOf');
  AB.updateRowComboOption(cc, 'rel:collaboratesWith');
  AB.updateRowComboOption(cc, 'rel:colleagueOf');
  AB.updateRowComboOption(cc, 'rel:descendantOf');
  AB.updateRowComboOption(cc, 'rel:employedBy');
  AB.updateRowComboOption(cc, 'rel:employerOf');
  AB.updateRowComboOption(cc, 'rel:enemyOf');
  AB.updateRowComboOption(cc, 'rel:engagedTo');
  AB.updateRowComboOption(cc, 'rel:friendOf');
  AB.updateRowComboOption(cc, 'rel:grandchildOf');
  AB.updateRowComboOption(cc, 'rel:grandparentOf');
  AB.updateRowComboOption(cc, 'rel:hasMet');
  AB.updateRowComboOption(cc, 'rel:knowsByReputation');
  AB.updateRowComboOption(cc, 'rel:knowsInPassing');
  AB.updateRowComboOption(cc, 'rel:knowsOf');
  AB.updateRowComboOption(cc, 'rel:lifePartnerOf');
  AB.updateRowComboOption(cc, 'rel:livesWith');
  AB.updateRowComboOption(cc, 'rel:lostContactWith');
  AB.updateRowComboOption(cc, 'rel:mentorOf');
  AB.updateRowComboOption(cc, 'rel:neighborOf');
  AB.updateRowComboOption(cc, 'rel:parentOf');
  AB.updateRowComboOption(cc, 'rel:participant');
  AB.updateRowComboOption(cc, 'rel:participantIn');
  AB.updateRowComboOption(cc, 'rel:siblingOf');
  AB.updateRowComboOption(cc, 'rel:spouseOf');
  AB.updateRowComboOption(cc, 'rel:worksWith');
  AB.updateRowComboOption(cc, 'rel:wouldLikeToKnow');

  var elm = $(elm);
  elm.appendChild(cc.div);
}

AB.updateRowComboOption = function (cc, optionName)
{
  cc.addOption(optionName, optionName);
}

AB.updateRowComboOption2 = function (elm, elmValue, optionName, optionValue)
{
	var o = OAT.Dom.option(optionName, optionValue, elm);
	if (elmValue == optionValue)
	  o.selected = true;
}

AB.updateRowCombo2 = function (elm, fldName, fldOptions)
{
	var cc = OAT.Dom.create("select");
  cc.name = fldName;
  cc.id = fldName;
	AB.updateRowComboOption2(cc, fldOptions.value, "Person URI", "URI");
  AB.updateRowComboOption2(cc, fldOptions.value, "Relationship Property", "Property");
	// AB.updateRowComboOption2(cc, fldOptions.value, "SPARQL", "SPARQL  Expression");

  var elm = $(elm);
  elm.appendChild(cc);
}

AB.updateRowCombo3 = function (elm, fldName, fldOptions)
{
	var cc = OAT.Dom.create("select");
  cc.name = fldName;
  cc.id = fldName;
	AB.updateRowComboOption2 (cc, fldOptions.value, "Grant", "G");
	AB.updateRowComboOption2 (cc, fldOptions.value, "Revoke", "R");

  var elm = $(elm);
  elm.appendChild(cc);
}

AB.validateError = function (fld, msg)
{
  alert(msg);
  setTimeout(function(){fld.focus();}, 1);
  return false;
}

AB.validateMail = function (fld)
{
  if ((fld.value.length == 0) || (fld.value.length > 40))
    return AB.validateError(fld, 'E-mail address cannot be empty or longer then 40 chars');

  var regex = /^([a-zA-Z0-9_\.\-])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9]{2,4})+$/;
  if (!regex.test(fld.value))
    return AB.validateError(fld, 'Invalid E-mail address');

  return true;
}

AB.validateURL = function (fld)
{
  var regex = /(ftp|http|https):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?/
  if (!regex.test(fld.value))
    return AB.validateError(fld, 'Invalid URL address');

  return true;
}

AB.validateField = function (fld)
{
  if ((fld.value.length == 0) && OAT.Dom.isClass(fld, '_canEmpty_'))
    return true;
  if (OAT.Dom.isClass(fld, '_mail_'))
    return AB.validateMail(fld);
  if (OAT.Dom.isClass(fld, '_url_'))
    return AB.validateURL(fld);
  return true;
}

AB.validateInputs = function (fld)
{
  var retValue = true;
  var form = fld.form;
  for (i = 0; i < form.elements.length; i++)
  {
    var fld = form.elements[i];
    if (OAT.Dom.isClass(fld, '_validate_'))
    {
      retValue = AB.validateField(fld);
      if (!retValue)
        return retValue;
    }
  }
  return retValue;
}
