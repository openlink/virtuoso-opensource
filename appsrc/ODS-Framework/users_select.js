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

// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
function getSelected (form, txt)
{
  if ((form != null) && (txt != null)) {
    for (var i = 0; i < form.elements.length; i++) {
      var obj = form.elements[i];
      if ((obj != null) && (obj.type == "checkbox") && (obj.name.indexOf (txt) != -1) && obj.checked)
        return (obj.name).substr(txt.length);
    }
  }
  return '';
}

// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
function singleSelected (form, txt, zeroMsq, moreMsg, mode)
{
  var count = countSelected(form, txt);
  if (count == 0) {
    if (zeroMsq != null)
      alert(zeroMsq);
    return false;
  }
  if (count > 1) {
    if (moreMsg != null)
      alert(moreMsg);
    return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
function confirmAction(confirmMsq, form, txt, selectionMsq) {
  if (anySelected (form, txt, selectionMsq))
    return confirm(confirmMsq);
  return false;
}

// ---------------------------------------------------------------------------
function trim(sString, ch)
{
  if (ch == null)
    ch = ' ';
  while (sString.substring(0,1) == ch)
    sString = sString.substring(1, sString.length);

  while (sString.substring(sString.length-1, sString.length) == ch)
    sString = sString.substring(0,sString.length-1);

  return sString;
}


// ---------------------------------------------------------------------------
//
function rowSelect(obj)
{
  var submitMode = false;
  var srcForm = obj.form;
  var dstForm = eval('window.opener.document.'+$v('form'));
  if (!dstForm)
    return false;

  if (srcForm.elements['src'])
    if (srcForm.elements['src'].value.indexOf('s') != -1)
      submitMode = true;
  if (submitMode)
    if (dstForm && dstForm.elements['submitting'])
        return false;
  var closeMode = true;
  if (srcForm.elements['dst'])
    if (srcForm.elements['dst'].value.indexOf('c') == -1)
      closeMode = false;
  var singleMode = true;
  if (srcForm.elements['dst'])
    if (srcForm.elements['dst'].value.indexOf('s') == -1)
      singleMode = false;

  var s2 = (obj.name).replace('b1', 's2');
  var s1 = (obj.name).replace('b1', 's1');

  var myRe = /^(\w+):(\w+);(.*)?/;
  var params = srcForm.params.value;
  var myArray;
  while(true) {
    myArray = myRe.exec(params);
    if (myArray == undefined)
      break;
    if (myArray.length > 2)
      if (dstForm && dstForm.elements[myArray[1]]) {
          if (myArray[2] == 's1')
          if (dstForm.elements[myArray[1]])
            rowSelectValue(dstForm.elements[myArray[1]], srcForm.elements[s1], singleMode, submitMode);
          if (myArray[2] == 's2')
          if (dstForm.elements[myArray[1]])
            rowSelectValue(dstForm.elements[myArray[1]], srcForm.elements[s2], singleMode, submitMode);
        }
    if (myArray.length < 4)
      break;
    params = '' + myArray[3];
  }
  if (submitMode) {
    window.opener.createHidden('F1', 'submitting', 'yes');
    dstForm.submit();
  }
  if (closeMode)
    window.close();
}

// ---------------------------------------------------------------------------
function rowSelectValue(dstField, srcField, singleMode, submitMode)
{
  if (singleMode) {
    dstField.value = trim(srcField.value, ',');
  } else {
    if (dstField.value == '') {
      dstField.value = srcField.value;
    } else {
      srcField.value = trim(srcField.value , ',');
      var aSrc = srcField.value.split(',');

      dstField.value = dstField.value + ',';
      for (var i = 0; i < aSrc.length; i = i + 1) {
        if (aSrc[i] != '')
          if (dstField.value.indexOf(aSrc[i]+',') == -1)
            dstField.value = dstField.value + trim(aSrc[i], ',') + ',';
      }
    }
    dstField.value = trim(dstField.value, ',');
  }
}

// ---------------------------------------------------------------------------
function updateChecked(form, objName)
{
  for (var i = 0; i < form.elements.length; i = i + 1) {
    var obj = form.elements[i];
    if (obj != null && obj.type == "checkbox" && obj.name == objName) {
      if (obj.checked) {
        if (form.s1.value.indexOf(obj.value+',') == -1)
          form.s1.value = form.s1.value + obj.value+',';
      } else {
        form.s1.value = (form.s1.value).replace(obj.value+',', '');
      }
    }
  }
}

// ---------------------------------------------------------------------------
function addChecked (form, txt, selectionMsq)
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
            rowSelectValue(openerForm.elements[myArray[1]], form.elements[s1], singleMode, submitMode);
          if (myArray[2] == 's2')
          if (openerForm.elements[myArray[1]])
            rowSelectValue(openerForm.elements[myArray[1]], form.elements[s2], singleMode, submitMode);
        }
    if (myArray.length < 4)
      break;
    params = '' + myArray[3];
  }
  if (submitMode)
    openerForm.submit();

  window.close();
}