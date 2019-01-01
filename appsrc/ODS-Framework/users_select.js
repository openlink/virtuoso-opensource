/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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
function myPost(frmName, fldName, fldValue)
{
  var frm = document.forms[frmName];
  hiddenCreate(fldName, frm, fldValue);
  frm.submit();
}

function selectAllCheckboxes (form, btn)
{
  for (var i = 0; i < form.elements.length; i = i + 1) {
    var contr = form.elements[i];
    if (contr != null && contr.type == "checkbox") {
      contr.focus();
      if (btn.value == 'Select All')
        contr.checked = true;
      else
        contr.checked = false;
    }
  }
  if (btn.value == 'Select All')
    btn.value = 'Unselect All';
  else
    btn.value = 'Select All';
  btn.focus();
}

function countSelected (form, txt)
{
  var count = 1;

  if ((form != null) && (txt != null)) {
    count = 0;
    for (var i = 0; i < form.elements.length; i++) {
      var obj = form.elements[i];
      if ((obj != null) && (obj.type == "checkbox") && (obj.name.indexOf (txt) != -1) && obj.checked)
        count++;
    }
  }
  return count;
}

function anySelected (form, txt, selectionMsq, mode)
{
  if ((form != null) && (txt != null)) {
    for (var i = 0; i < form.elements.length; i++) {
      var obj = form.elements[i];
      if ((obj != null) && (obj.type == "checkbox") && (obj.name.indexOf (txt) != -1) && obj.checked)
        return true;
    }
    if (selectionMsq != null) {
      if ((mode != null) && (mode == 'confirm'))
        return confirm(selectionMsq);
      alert(selectionMsq);
    }
    return false;
  }
  return true;
}

function confirmAction(confirmMsq, form, txt, selectionMsq) {
  if (anySelected (form, txt, selectionMsq))
    return confirm(confirmMsq);
  return false;
}

function trim(sString, ch)
{
  if (!ch)
    ch = ' ';
  while (sString.substring(0,1) == ch)
    sString = sString.substring(1, sString.length);

  while (sString.substring(sString.length-1, sString.length) == ch)
    sString = sString.substring(0,sString.length-1);

  return sString;
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
    commitChecked(s1Input.form, s1Input.value);
  }
}

function commitChecked(srcForm, s1Value, s2Value)
{
  var dstForm = eval('window.opener.document.'+$v('form'));
  if (!dstForm)
    return false;

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
      if (!myArray)
      break;

      if (myArray.length > 2) {
        var dstField = dstForm.elements[myArray[1]];
        if (dstField) {
          if (myArray[2] == 's1')
            setSelected(dstField, s1Value, singleMode);
          else if (myArray[2] == 's2')
            setSelected(dstField, s2Value, singleMode);
        }
        }

    if (myArray.length < 4)
      break;

    params = '' + myArray[3];
  }
  }
  if (submitMode) {
    // dstForm.hiddenCreate('submitting', dstForm, 'yes');
    dstForm.submit();
  }
  if (closeMode)
    window.close();
}

function addChecked (srcForm, checkboxName, selectionMsq)
{
  if (!anySelected (srcForm, checkboxName, selectionMsq, 'confirm'))
    return false;

  return commitChecked(srcForm, srcForm.s1.value, srcForm.s2.value);
}

function setSelected(dstField, srcValue, singleMode) {
  if (singleMode) {
		dstField.value = srcValue;
  } else {
		dstField.value = trim(dstField.value);
		dstField.value = trim(dstField.value, ',');
		dstField.value = trim(dstField.value);
		if (dstField.value.indexOf(srcValue) == -1) {
    if (dstField.value == '') {
				dstField.value = srcValue;
    } else {
				dstField.value = dstField.value + ',' + srcValue;
      }
    }
  }
}

function updateChecked(obj, objName, event)
{
  if (event)
	  event.cancelBubble = true;
  var objForm = obj.form;

  var s1Value = objForm.s1.value;
  s1Value = trim(s1Value);
  s1Value = trim(s1Value, ',');
  s1Value = trim(s1Value);
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
  objForm.s1.value = trim(s1Value, ',');
}

function addChecked2 (form, txt, selectionMsq)
{
  var openerForm = eval('window.opener.document.'+$v('form'));
  if (!openerForm)
    return false;

  if (!anySelected (form, txt, selectionMsq, 'confirm'))
    return false;

  var submitMode = false;
  if (form.elements['src'] && (form.elements['src'].value.indexOf('s') != -1))
      submitMode = true;

  var singleMode = true;
  if (form.elements['dst'] && (form.elements['dst'].value.indexOf('s') == -1))
      singleMode = false;

  var s1 = 's1';
  var s2 = 's2';

  var myRe = /^(\w+):(\w+);(.*)?/;
  var params = form.elements['params'].value;
  var myArray;
  while(true) {
    myArray = myRe.exec(params);
    if (myArray == undefined)
      break;
    if (myArray.length > 2)
      if (openerForm.elements[myArray[1]]) {
          if (myArray[2] == 's1')
          if (openerForm.elements[myArray[1]])
            setSelected(openerForm.elements[myArray[1]], form.elements[s1], singleMode, submitMode);
          if (myArray[2] == 's2')
          if (openerForm.elements[myArray[1]])
            setSelected(openerForm.elements[myArray[1]], form.elements[s2], singleMode, submitMode);
        }
    if (myArray.length < 4)
      break;
    params = '' + myArray[3];
  }
  if (submitMode)
    openerForm.submit();

  window.close();
}