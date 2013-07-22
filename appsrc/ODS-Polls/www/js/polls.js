/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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

function urlParam(fldName)
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

function myPost(frm_name, fld_name, fld_value) {
  createHidden(frm_name, fld_name, fld_value);
  document.forms[frm_name].submit();
}

function myTags(fld_value) {
  createHidden('F1', 'tag', fld_value);
  doPost ('F1', 'pt_tags');
}

function vspxPost(fButton, fName, fValue, f2Name, f2Value, f3Name, f3Value) {
  if (fName)
  createHidden('F1', fName, fValue);
  if (f2Name)
  createHidden('F1', f2Name, f2Value);
  if (f3Name)
    createHidden('F1', f3Name, f3Value);
  doPost ('F1', fButton);
}

function toolbarPost(fValue) {
  vspxPost('command', 'select', fValue)
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

function submitEnter(myForm, myButton, e) {
  var keycode;
  if (window.event)
    keycode = window.event.keyCode;
	else if (e)
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

function getObject(id) {
  if (document.all)
    return document.all[id];
  return document.getElementById(id);
}

function getParent(obj, tag) {
  var obj = obj.parentNode;
  if (obj.tagName.toLowerCase() == tag)
    return obj;
  return getParent(obj, tag);
}

function confirmAction(confirmMsq, form, txt, selectionMsq) {
  if (anySelected (form, txt, selectionMsq))
    return confirm(confirmMsq);
  return false;
}

function selectCheck(obj, prefix) {
  coloriseRow(getParent(obj, 'tr'), obj.checked);
  enableToolbars(obj.form, prefix);
}

function enableToolbars(objForm, prefix) {
  var oCount = 0;
  for (var i = 0; i < objForm.elements.length; i++) {
    var o = objForm.elements[i];
		if (o != null && o.type == 'checkbox' && !o.disabled
				&& o.name.indexOf(prefix) != -1 && o.checked)
      oCount += 1;
  }
  enableElement('tbTag', 'tbTag_gray', oCount>0);
  enableElement('tbDelete', 'tbDelete_gray', oCount>0);
}

function enableElement(id, id_gray, idFlag) {
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

function showCell(cell) {
  var c = getObject (cell);
  if ((c) && (c.style.display == "none"))
    c.style.display = "";
}

function hideCell(cell) {
  var c = getObject(cell);
  if ((c) && (c.style.display != "none"))
    c.style.display = "none";
}

function selectAllCheckboxes (obj, prefix) {
  var objForm = obj.form;
  for (var i = 0; i < objForm.elements.length; i++) {
    var o = objForm.elements[i];
		if (o != null && o.type == "checkbox" && !o.disabled
				&& o.name.indexOf(prefix) != -1) {
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

function anySelected (form, txt, selectionMsq) {
  if ((form != null) && (txt != null)) {
    for (var i = 0; i < form.elements.length; i++) {
      var obj = form.elements[i];
			if (obj != null && obj.type == "checkbox"
					&& obj.name.indexOf(txt) != -1 && obj.checked)
        return true;
    }
    if (selectionMsq != null)
      alert(selectionMsq);
    return false;
  }
  return true;
}

function coloriseTable(id) {
  if (document.getElementsByTagName) {
    var table = document.getElementById(id);
    if (table != null) {
      var rows = table.getElementsByTagName("tr");
      for (i = 0; i < rows.length; i++) {
				rows[i].className = rows[i].className + " tr_" + (i % 2);
				;
      }
    }
  }
}

function coloriseRow(obj, checked) {
  obj.className = (obj.className).replace('tr_select', '');
  if (checked)
    obj.className = obj.className + ' ' + 'tr_select';
}

function myTrim(sString, sChar) {
  if (sChar == null)
    sChar = ' ';

  while (sString.substring(0,1) == sChar)
    sString = sString.substring(1, sString.length);

  while (sString.substring(sString.length-1, sString.length) == sChar)
    sString = sString.substring(0,sString.length-1);

  return sString;
}

function showTag(tag) {
  createHidden2(parent.document, 'F1', 'tag', tag);
  parent.document.forms['F1'].submit();
}

//
// sortSelect(select_object)
//   Pass this function a SELECT object and the options will be sorted
//   by their text (display) values
//
function sortSelect(box) {
  var o = new Array();
  for (var i=0; i<box.options.length; i++)
		o[o.length] = new Option(box.options[i].text, box.options[i].value,
				box.options[i].defaultSelected, box.options[i].selected);

  if (o.length==0)
    return;

  o = o.sort(function(a,b) {
		if ((a.text + "") < (b.text + "")) {
			return -1;
                           }
		if ((a.text + "") > (b.text + "")) {
			return 1;
		}
		return 0;
	});

  for (var i=0; i<o.length; i++)
		box.options[i] = new Option(o[i].text, o[i].value,
				o[i].defaultSelected, o[i].selected);
}

function showTab(tabs, tabsCount, tabNo) {
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

function rowSelect(obj) {
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
							rowSelectValue(
									window.opener.document.F1.elements[myArray[1]],
									window.document.F1.elements[s1],
									singleMode, submitMode);
          if (myArray[2] == 's2')
            if (window.opener.document.F1.elements[myArray[1]])
							rowSelectValue(
									window.opener.document.F1.elements[myArray[1]],
									window.document.F1.elements[s2],
									singleMode, submitMode);
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

function rowSelectValue(dstField, srcField, singleMode) {
  if (singleMode) {
    dstField.value = srcField.value;
  } else {
    dstField.value = myTrim(dstField.value);
    dstField.value = myTrim(dstField.value, ',');
    dstField.value = myTrim(dstField.value);
    if (dstField.value.indexOf(srcField.value) == -1) {
      if (dstField.value == '') {
        dstField.value = srcField.value;
      } else {
        dstField.value = dstField.value + ',' + srcField.value;
      }
    }
  }
}

// Hidden functions
function createHidden(frm_name, fld_name, fld_value) {
  var hidden;

  createHidden2(document, frm_name, fld_name, fld_value);
}

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

function changeExportName(fld_name, from, to) {
  var obj = document.forms['F1'].elements[fld_name];
  if (obj)
    obj.value = (obj.value).replace(from, to);
}

function updateChecked(obj, objName) {
  var objForm = obj.form;
  coloriseRow(getParent(obj, 'tr'), obj.checked);
  objForm.s1.value = myTrim(objForm.s1.value);
  objForm.s1.value = myTrim(objForm.s1.value, ',');
  objForm.s1.value = myTrim(objForm.s1.value);
  objForm.s1.value = objForm.s1.value + ',';
  for (var i = 0; i < objForm.elements.length; i = i + 1) {
    var obj = objForm.elements[i];
    if (obj != null && obj.type == "checkbox" && obj.name == objName) {
      if (obj.checked) {
        if (objForm.s1.value.indexOf(obj.value+',') == -1)
          objForm.s1.value = objForm.s1.value + obj.value+',';
      } else {
				objForm.s1.value = (objForm.s1.value).replace(obj.value + ',',
						'');
      }
    }
  }
  objForm.s1.value = myTrim(objForm.s1.value, ',');
}

function addChecked(form, txt, selectionMsq) {
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
							rowSelectValue(
									window.opener.document.F1.elements[myArray[1]],
									window.document.F1.elements[s1],
									singleMode, submitMode);
          if (myArray[2] == 's2')
            if (window.opener.document.F1.elements[myArray[1]])
							rowSelectValue(
									window.opener.document.F1.elements[myArray[1]],
									window.document.F1.elements[s2],
									singleMode, submitMode);
        }
    if (myArray.length < 4)
      break;
    params = '' + myArray[3];
  }
  if (submitMode)
    window.opener.document.F1.submit();
  window.close();
}

function addTag(tag, objName) {
  var obj = document.F1.elements[objName];
  obj.value = myTrim(obj.value);
  obj.value = myTrim(obj.value, ',');
  obj.value = myTrim(obj.value);
  obj.value = (obj.value).replace('  ', ' ');
  obj.value = (obj.value).replace(' ,', ',');
  obj.value = obj.value + ',';
  if (obj.value.indexOf(tag+',') == -1) {
    obj.value = obj.value + tag + ',';
  } else {
    obj.value = (obj.value).replace(tag+',', '');
  }
  obj.value = myTrim(obj.value, ',');
}

function addCheckedTags(openerName, checkName) {
  if (window.opener.document.F1.elements[document.F1.elements[openerName].value]) {
    var objForm = document.F1;
    var objOpener = window.opener.document.F1.elements[document.F1.elements[openerName].value];

    objOpener.value = myTrim(objOpener.value);
    objOpener.value = myTrim(objOpener.value, ',');
    objOpener.value = myTrim(objOpener.value);
    objOpener.value = objOpener.value + ',';
    for (var i = 0; i < objForm.elements.length; i = i + 1) {
      var obj = objForm.elements[i];
      if (obj != null && obj.type == "checkbox" && obj.name == checkName) {
        if (obj.checked) {
          if (objOpener.value.indexOf(obj.value+',') == -1)
            objOpener.value = objOpener.value + obj.value+',';
        } else {
					objOpener.value = (objOpener.value).replace(
							obj.value + ',', '');
        }
      }
    }
    objOpener.value = myTrim(objOpener.value, ',');
  }
  window.close();
}

function changeQuestionType(obj) {
  var qType = obj.form['pq_type'];
  if (qType.value == 'M') {
    showCell ('tr_question_choices');
    showCell ('tr_question_allowed');

    aNumbers = obj.form.elements['pq_choices'].value;
    for (var i = 1; i <= aNumbers; i = i + 1)
      showCell ('tr_answer_'+i);

    hideCell ('tr_range_start');
    hideCell ('tr_range_end');
    hideCell ('tr_range_decimals');
  } else {
    hideCell ('tr_question_choices');
    hideCell ('tr_question_allowed');

    aNumbers = Number (obj.form.elements['pq_choices'].value);
    for (var i = 1; i <= aNumbers; i = i + 1)
      hideCell ('tr_answer_'+i);

    showCell ('tr_range_start');
    showCell ('tr_range_end');
    showCell ('tr_range_decimals');
  }
}

function changeAnswerChoices(obj) {
  var qType = obj.form['pq_type'];
  if (qType.value != 'M')
    return;

  var aNumbers = Number(obj.value);
  for (var i = 1; i <= aNumbers; i = i + 1)
    showCell ('tr_answer_'+i);
  for (var i = aNumbers+1; i <= 10; i = i + 1)
    hideCell ('tr_answer_'+i);

  var qAllowed = obj.form['pq_allowed'];
  var qIndex = qAllowed.selectedIndex;
  for (var i = 0; i < qAllowed.length; i = i + 1)
    qAllowed.options[i] = null;
  for (var i = 0; i < aNumbers; i = i + 1) {
    qAllowed.options[i] = new Option (i+1, i+1);
    if (i == qIndex)
      qAllowed.selectedIndex = i;
  }
}

function checkChoices(obj) {
  if (!obj.checked)
    return;
  var objName = obj.name;
  var N = objName.lastIndexOf('_');
  var qID = objName.substr(N+1);

  var choices = obj.form.elements['choices_'+qID].value;
  var allowed = obj.form.elements['allowed_'+qID].value;

  if (allowed == 1) {
    for (var i = 1; i <= choices; i = i + 1) {
      if (objName != obj.form.elements['answer_'+i+'_'+qID].name)
        obj.form.elements['answer_'+i+'_'+qID].checked = false;
    }
  } else {
    var checks = 0;
    for (var i = 1; i <= choices; i = i + 1) {
      if (obj.form.elements['answer_'+i+'_'+qID].checked)
        checks++;
    }
    if (checks > allowed) {
      obj.checked = false;
      alert ('Maximum number of allowed answers is reached!');
      return false;
    }
  }
  return true;
}

function checkRange(obj) {
  var objName = obj.name;
  var N = objName.lastIndexOf('_');
  var qID = objName.substr(N+1);

  var required = obj.form.elements['required_'+qID].value;
  var range_start = obj.form.elements['range_start_'+qID].value;
  var range_end = obj.form.elements['range_end_'+qID].value;
  var range_decimals = obj.form.elements['range_decimals_'+qID].value;

  var oValue = parseFloat(obj.value, range_decimals);
  if (isNaN(oValue)) {
    alert ('Bad value');
    return false;
  }
  if ((required == 1) && (myTrim (obj.value) == '')) {
    alert ('Must has value');
    return false;
  }
  if ((oValue < range_start) || (oValue > range_end)) {
    alert ('Value must be in range ['+range_start+', '+range_end+']');
    return false;
  }
  return true;
}

function checkVote(obj) {
  var objForm = obj.form;
  var oName;
  var N;
  var qID;
  var qType;
  for (var i = 0; i < objForm.elements.length; i++) {
    var o = objForm.elements[i];
    if (o != null && o.type == 'hidden' && o.name.indexOf ('id_') != -1) {
      qID = o.value;
      qType = objForm.elements['type_'+qID].value;
      if (qType == 'M') {
        var choices = objForm.elements['choices_'+qID].value;
        var allowed = objForm.elements['allowed_'+qID].value;
        var required = objForm.elements['required_'+qID].value;
        var checks = 0;

        for (var j = 1; j <= choices; j = j + 1) {
          if (obj.form.elements['answer_'+j+'_'+qID].checked)
            checks++;
        }
        if (checks < required) {
          alert ('Minimal number of allowed answers is reached!');
          return false;
        }
        if (checks > allowed) {
          alert ('Maximum number of allowed answers is reached!');
          return false;
        }
      }
      if (qType == 'N') {
        if (!checkRange (objForm.elements['answer_'+qID]))
          return false;
      }
    }
  }
  return true;
}

var POLLS = new Object();

POLLS.trim = function(sString, sChar) {

	if (sString) {
		if (sChar == null) {
      sChar = ' ';
    }
		while (sString.substring(0, 1) == sChar) {
      sString = sString.substring(1, sString.length);
    }
		while (sString.substring(sString.length - 1, sString.length) == sChar) {
      sString = sString.substring(0,sString.length-1);
    }
  }
  return sString;
}

POLLS.aboutDialog = function() {
  var aboutDiv = $('aboutDiv');
  if (aboutDiv)
		OAT.Dom.unlink(aboutDiv);

  aboutDiv = OAT.Dom.create('div', {height: '160px', overflow: 'hidden'});
  aboutDiv.id = 'aboutDiv';
	aboutDialog = new OAT.Dialog('About ODS Polls', aboutDiv, {width: 445, buttons: 0, resize: 0, modal: 1});
	aboutDialog.cancel = aboutDialog.hide;

  var x = function (txt) {
		if (txt != "") {
      var aboutDiv = $("aboutDiv");
			if (aboutDiv) {
        aboutDiv.innerHTML = txt;
        aboutDialog.show ();
      }
    }
  }
	OAT.AJAX.POST("ajax.vsp", "a=about", x, {type : OAT.AJAX.TYPE_TEXT, onstart : function() {}, onerror : function() {}});
}
