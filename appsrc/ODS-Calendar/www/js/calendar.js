/*
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
function setFooter() {
  if ($('content')) {
    var wDims = OAT.Dom.getViewport()
    var hDims = OAT.Dom.getWH('FT')
    var cPos = OAT.Dom.position('content')
    $('content').style.height = (wDims[1] - hDims[1] - cPos[1] - 20) + 'px';
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
	if ((format == 'yyyy-MM-dd') || (format == 'yyyy.MM.dd') || (format == 'yyyy/MM/dd')) {
  	var pattern = new RegExp(
  			'^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])$');
  	if (dateString.match(pattern)) {
  		dateString = dateString.replace(/\//g, '-');
  		dateString = dateString.replace(/\./g, '-');
  		result = dateString.split('-');
  		result = [ parseInt(result[0], 10), parseInt(result[1], 10), parseInt(result[2], 10) ];
  	}
  }
	if ((format == 'dd-MM-yyyy') || (format == 'dd.MM.yyyy') || (format == 'dd/MM/yyyy')) {
  	var pattern = new RegExp(
  			'^(0[1-9]|[12][0-9]|3[01])[- /.](0[1-9]|1[012])[- /.]((?:19|20)[0-9][0-9])$');
  	if (dateString.match(pattern)) {
  		dateString = dateString.replace(/\//g, '-');
  		dateString = dateString.replace(/\./g, '-');
  		result = dateString.split('-');
  		result = [ parseInt(result[2], 10), parseInt(result[1], 10), parseInt(result[0], 10) ];
  	}
  }
	if ((format == 'MM-dd-yyyy') || (format == 'MM.dd.yyyy') || (format == 'MM/dd/yyyy')) {
  	var pattern = new RegExp(
  			'^(0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])[- /.]((?:19|20)[0-9][0-9])$');
  	if (dateString.match(pattern)) {
  		dateString = dateString.replace(/\//g, '-');
  		dateString = dateString.replace(/\./g, '-');
  		result = dateString.split('-');
  		result = [ parseInt(result[2], 10), parseInt(result[0], 10), parseInt(result[1], 10) ];
  	}
  }
	return result;
}

function datePopup(objName, format, cb) {
	if (!format)
		format = 'yyyy-MM-dd';

	var obj = $(objName);
	var d = dateParse(obj.value, format);
	var c = new OAT.Calendar({popup: true});
	var coords = OAT.Dom.position(obj);
	if (isNaN(coords[0]))
		coords = [ 0, 0 ];

	var x = function(date) {
		obj.value = dateFormat(date, format);
		if (cb)
		  cb();
	}
	c.show(coords[0], coords[1] + 30, x, d);
}

function dateUpdate(srcField, dstFields, format) {
  function dp(v, f) {
    var dt = dateParse(v, f);
    if (dt)
      dt = new Date(dt[0], dt[1]-1, dt[2]);

    return dt;
  }
  var src = $(srcField);
  if (!src) {return;}
  var srcDate = dp(src.value, format);
  if (!srcDate) {return;}

  var srcSave = $(srcField+'_save');
  if (!srcSave) {return;}
  var srcSaveDate = dp(srcSave.value, format);
  if (!srcSaveDate) {return;}

  var delta = (srcDate.getTime() - srcSaveDate.getTime()) / (60 * 60 * 24 * 1000);
	for (var i = 0; i < dstFields.length; i++) {
    var dst = $(dstFields[i]);
    if (!dst) {continue;}
    var dstDate = dp(dst.value, format);
    if (!dstDate) {continue;}

    dstDate = new Date(dstDate.getFullYear(), dstDate.getMonth(), dstDate.getDate()+delta);
    dst.value = dateFormat([dstDate.getFullYear(), dstDate.getMonth()+1, dstDate.getDate()], format);

    var dstSave = $(dstFields[i]+'_save');
    if (!dstSave) {continue;}
    dstSave.value = dst.value;
  }
  srcSave.value = src.value;
}

function submitEnter(e, fForm, fButton, fName, fValue, f2Name, f2Value, f3Name, f3Value) {
  var keyCode;
  
	if (window.event) {
    keycode = window.event.keyCode;
  } else {
		if (!e)
			return true;

      keycode = e.which;
  }
	if (keycode == 13) {
		if (fButton != '') {
      vspxPost(fButton, fName, fValue, f2Name, f2Value, f3Name, f3Value);
      return false;
    }
		document.forms[fForm].submit();
  }
  return true;
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
	for ( var i = 0; i < objForm.elements.length; i++) {
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
  var element = $(id);
	if (element) {
		if (idFlag) {
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

function shCell(cell) {
  var c = $(cell);
  var i = $(cell+'_image');
	if ((c) && (c.style.display == "none")) {
    c.style.display = "";
		if (i) {
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

function selectAllCheckboxes(obj, prefix) {
  var objForm = obj.form;
	for ( var i = 0; i < objForm.elements.length; i++) {
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

function selectAllCheckboxes2(obj, prefix) {
	var inputs = document.getElementsByTagName("input");

	for ( var i = 0; i < inputs.length; i++) {
	  var o = inputs[i];
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
  obj.focus();
}

function anySelected(form, txt, selectionMsq) {
	if ((form != null) && (txt != null)) {
		for ( var i = 0; i < form.elements.length; i++) {
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
    var table = $(id);
		if (table) {
      var rows = table.getElementsByTagName("tr");
			for (i = 0; i < rows.length; i++)
				rows[i].className = rows[i].className + " tr_" + (i % 2);
    }
  }
}

function coloriseRow(obj, checked) {
  obj.className = (obj.className).replace('tr_select', '');
  if (checked)
    obj.className = obj.className + ' ' + 'tr_select';
}

function showTag(tag) {
  createHidden2(parent.document, 'F1', 'tag', tag);
  parent.document.forms['F1'].submit();
}

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
		box.options[i] = new Option(o[i].text, o[i].value, o[i].defaultSelected, o[i].selected);
}

function showTab(tabs, tabsCount, tabNo) {
	if ($(tabs)) {
		for ( var i = 0; i < tabsCount; i++) {
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

	return false;
}

function calendarsShow(sPage, width, height) {
	if ($('ss_type_0').checked)
    sPage = sPage + '&mode=p'

	return windowShow(sPage, width, height);
}

function tagsShow(sPage, prefix) {
	if ($(prefix+'_subject'))
		sPage += '&txt=' + encodeURIComponent($v(prefix+'_subject'))

	if ($(prefix+'_description'))
		sPage += '&txt2=' + encodeURIComponent($v(prefix+'_description'))

	return windowShow(sPage);
}

function calendarsHelp(mode) {
  var T = '';
	if ($('ss_type_0').checked)
    T = 'Select Public';

	if ($('ss_type_1').checked)
    T = 'Select Shared';

  $('ss_type_button').value = T;
  if (mode)
    $('ss_calendar').value = '';
}

function rowSelect(obj) {
  var srcForm = window.document.F1;
  var dstForm = window.opener.document.F1;

  var s2 = (obj.name).replace('b1', 's2');
  var s1 = (obj.name).replace('b1', 's1');

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
	while (true) {
    myArray = myRe.exec(params);
    if (myArray == undefined)
      break;
      if (myArray.length > 2) {
        var fld = dstForm.elements[myArray[1]];
        if (fld) {
          if (myArray[2] == 's1')
            rowSelectValue(fld, srcForm.elements[s1], singleMode);
          if (myArray[2] == 's2')
            rowSelectValue(fld, srcForm.elements[s2], singleMode);
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

function rowSelectValue(dstField, srcField, singleMode) {
	if (singleMode) {
    dstField.value = srcField.value;
  } else {
    dstField.value = CAL.trim(dstField.value);
    dstField.value = CAL.trim(dstField.value, ',');
    dstField.value = CAL.trim(dstField.value);
		if (dstField.value.indexOf(srcField.value) == -1) {
			if (dstField.value == '') {
        dstField.value = srcField.value;
      } else {
        dstField.value = dstField.value + ',' + srcField.value;
      }
    }
  }
}

// Menu functions
function menuMouseIn(a, b) {
	if (b != undefined) {
		while (b.parentNode) {
      b = b.parentNode;
      if (b == a)
        return true;
    }
  }
  return false;
}

function menuMouseOut(event) {
  var current, related;

	if (window.event) {
    current = this;
    related = window.event.toElement;
  } else {
    current = event.currentTarget;
    related = event.relatedTarget;
  }

  if ((current != related) && !menuMouseIn(current, related))
    current.style.visibility = "hidden";
}

function menuPopup(button, menuID) {
  if (document.getElementsByTagName && !document.all)
    document.all = document.getElementsByTagName("*");
	if (document.all) {
		for ( var i = 0; i < document.all.length; i++) {
      var obj = document.all[i];
			if (obj.id.search('exportMenu') != -1) {
        obj.style.visibility = 'hidden';
				if (OAT.Browser.isIE) {
          obj.onmouseout = menuMouseOut;
        } else {
          obj.addEventListener("mouseout", menuMouseOut, true);
        }
      }
    }
  }

  button.blur();
  var div = $(menuID);
	if (div.style.visibility == 'visible') {
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

// Hiddens functions
function createHidden(frm_name, fld_name, fld_value) {
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

function addTag(tag, objName) {
  var obj = document.F1.elements[objName];
  obj.value = CAL.trim(obj.value);
  obj.value = CAL.trim(obj.value, ',');
  obj.value = CAL.trim(obj.value);
  obj.value = CAL.trim(obj.value, ',');
  obj.value = (obj.value).replace('  ', ' ');
  obj.value = (obj.value).replace(' ,', ',');
  obj.value = obj.value + ',';
	if (obj.value.indexOf(tag + ',') == -1) {
    obj.value = obj.value + tag + ',';
  } else {
    obj.value = (obj.value).replace(tag+',', '');
  }
  obj.value = CAL.trim(obj.value);
  obj.value = CAL.trim(obj.value, ',');
  obj.value = CAL.trim(obj.value);
	return false;
}

function addCheckedTags(openerName, checkName) {
	if (window.opener.document.F1.elements[document.F1.elements[openerName].value]) {
    var objForm = document.F1;
    var objOpener = window.opener.document.F1.elements[document.F1.elements[openerName].value];

    objOpener.value = CAL.trim(objOpener.value);
    objOpener.value = CAL.trim(objOpener.value, ',');
    objOpener.value = CAL.trim(objOpener.value);
    objOpener.value = objOpener.value + ',';
		for ( var i = 0; i < objForm.elements.length; i = i + 1) {
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
    objOpener.value = CAL.trim(objOpener.value, ',');
  }
  window.close();
}

function cSelect(obj) {
  var objID = obj.id;

  createHidden('F1', 'select', objID);
  doPost ('F1', 'command');
}

function eEdit(obj, event) {
	if (typeof (obj) == 'string') {
    var objID = obj;
  } else {  
  var objID = obj.id;
  }
  createHidden('F1', 'edit', objID);
  doPost ('F1', 'command');
}

function eView(obj, event) {
	if (typeof (obj) == 'string') {
		var objID = obj;
	} else {
		var objID = obj.id;
	}
	createHidden('F1', 'view', objID);
	doPost('F1', 'command');
}

function eDate(obj) {
  var objID = obj.id;

  createHidden('F1', 'date', objID);
  doPost ('F1', 'command');
}

function eDelete(event, obj, onOffset) {
  event.cancelBubble = true;

	// delete dialog
	if (onOffset != null) {
		deleteDialog2.okBtn.onclick = function() {
  		deleteDialog2.hide();
      if ($('e_delete_0').checked)
        createHidden('F1', 'onOffset', onOffset);
      createHidden('F1', 'delete', obj.id);
    doPost ('F1', 'command');
  }
		deleteDialog2.cancelBtn = deleteDialog2.hide;
  	deleteDialog2.show ();
  } else {
		deleteDialog.okBtn.onclick = function() {
      createHidden('F1', 'delete', obj.id);
      doPost ('F1', 'command');
  		deleteDialog.hide();
   	}
		deleteDialog.cancelBtn = deleteDialog.hide;
  	deleteDialog.show ();
  }
  return false;
}

function eAnnotea(event, id, domain_id, account_id) {
  event.cancelBubble = true;

	URL = 'annotea.vspx?' + urlParam("sid") + urlParam("realm") + '&oid=' + id + '&did=' + domain_id + '&aid=' + account_id;
	window.open(URL, 'addressbook_anotea_window', 'top=100, left=100, scrollbars=yes, resize=yes, menubar=no, height=500, width=600');
  return false;
}

function cNewEvent(event, onDate, onTime) {
  var srcNode = OAT.Event.source(event);
	if (OAT.Dom.isClass(srcNode, 'CE_new')) {
  if (onDate != null)
    createHidden('F1', 'onDate', onDate);
  if (onTime != null)
    createHidden('F1', 'onTime', onTime);
  createHidden('F1', 'select', 'create');
    createHidden('F1', 'mode', 'event');
    doPost ('F1', 'command');
  }
}

function cExchange(command) {
  createHidden('F1', 'exchange', command);
  doPost ('F1', 'command');
}

function cCalendar(calendar_id) {
	vspxPost('command', 'select', 'settings', 'mode', 'sharedUpdate', 'id', calendar_id);
}

function exchangeHTML() {
  var S, T;

  T = $('ds_navigation');
  if (!T)
    T = $('ds1_navigation');
  if (!T)
    T = $('ds2_navigation');
  if (!T)
    T = $('ds3_navigation');
	if (T) {
    S = $('navigation')
    if (S)
      S.innerHTML = T.innerHTML;
    T.innerHTML = '';
  }
}

function checkRepetition(grpName, checkName) {
	for ( var i = 0; i < document.forms['F1'].elements.length; i++) {
    var obj = document.forms['F1'].elements[i];
		if (obj.type == "radio" && obj.name == grpName) {
      obj.checked = false;
      if (obj.id == checkName)
        obj.checked = true;
    }
  }
}

function urlParam(fldName) {
  var S = '';
  var O = document.forms['F1'].elements[fldName];
  if (O)
    S += '&' + fldName + '=' + encodeURIComponent(O.value);
  return S;
}

function myA(obj) {
  if (obj.href) {
    document.location = obj.href + '?' + urlParam('sid') + urlParam('realm');
    return false;
  }
}

function checkReminder() {
  var cb = function(txt) {
    setTimeout("checkReminder()", 60000);
		if (txt != "") {
      var reminderBody = $("reminderBody");
			if (reminderBody) {
        if (OAT.Dimmer.elm != reminderDialog)
          reminderBody.innerHTML = '';
        var xmlDoc = OAT.Xml.createXmlDoc('<root>'+txt+'</root>');
	      var root = xmlDoc.documentElement;
        var reminderTRs = root.getElementsByTagName('tr');
  		  for (var i=0; i<reminderTRs.length; i++) {
  		    var tr = reminderTRs[i];
					if (!$(tr.id)) {
            reminderBody.innerHTML += OAT.Xml.serializeXmlDoc(tr);
          }
  		  }
        coloriseTable('reminderTable');
    	  reminderDialog.show();
      }
    }
  }
	OAT.AJAX.POST("ajax.vsp", "a=alarms&sa=list" + urlParam("sid") + urlParam("realm"), cb, {
		type : OAT.AJAX.TYPE_TEXT,
		onstart : function() {
		},
		onerror : function() {
		}
	});
}

function dismissReminder(prefix, mode) {
	var inputs = document.getElementsByTagName("input");
	var reminders = "";
	for ( var i = 0; i < inputs.length; i++) {
	  var o = inputs[i];
		if (o != null && o.type == "checkbox" && !o.disabled
				&& o.name.indexOf(prefix) != -1) {
      if (o.checked || mode)
        reminders = reminders + "," + o.value;
    }
  }
	OAT.AJAX.POST("ajax.vsp", "a=alarms&sa=dismiss&reminders="+reminders+urlParam("sid")+urlParam("realm"), function(){}, {onstart : function(){}, onerror : function(){}});
	reminderDialog.hide ();
}

function davBrowse(fld, folders) {
	/* load stylesheets */
	OAT.Style.include("grid.css");
	OAT.Style.include("webdav.css");

	var options = {
		mode : 'browser',
    onConfirmClick: function(path, fname) {$(fld).value = '/DAV' + path + fname;}
                };
  if (!folders) {folders = false;}
  OAT.WebDav.options.foldersOnly = folders;
  OAT.WebDav.open(options);
}

function changeComplete(obj) {
  obj = $(obj);
	if (obj.name == 't_completed' && CAL.trim(obj.value) != '') {
    $('t_status').value = 'Completed';
    $('t_complete').value = '100';
	} else if (obj.name == 't_status' && obj.value == 'Completed') {
    if (CAL.trim($('t_completed').value) == '')
      $('t_completed').value = $('t_eventEndDate').value;
    $('t_complete').value = '100';
	} else if (obj.name == 't_complete' && obj.value == '100') {
    if (CAL.trim($('t_completed').value) == '')
      $('t_completed').value = $('t_eventEndDate').value;
    $('t_status').value = 'Completed';
  }
}

function destinationChange(obj, actions) {
  if (!obj.checked)
    return;
  if (!actions)
    return;
	if (actions.hide) {
    var a = actions.hide;
		for ( var i = 0; i < a.length; i++) {
      var o = $(a[i])
			if (o)
				OAT.Dom.hide(o);
			}
    }
	if (actions.show) {
    var a = actions.show;
		for ( var i = 0; i < a.length; i++) {
      var o = $(a[i])
			if (o)
				OAT.Dom.show(o);
    }
  }
	if (actions.clear) {
    var a = actions.clear;
		for ( var i = 0; i < a.length; i++) {
      var o = $(a[i])
			if (o && o.value)
				o.value = '';
			}
    }
	if (actions.exec) {
		var a = actions.exec;
		for ( var i = 0; i < a.length; i++) {
			a[i](obj);
		}
	}
}

function srcImportLabel(obj) {
  var srcLabel = $('srcLabel');
  if (!srcLabel)
    return;
  if ($('icSource_0').checked)
    srcLabel.innerHTML = 'Local File Name (.ics)';
  if ($('icSource_1').checked)
    srcLabel.innerHTML = 'WebDAV File URL (.ics)';
  if ($('icSource_3').checked)
    srcLabel.innerHTML = 'CalDAV URL';
  if ($('icSource_2').checked)
    srcLabel.innerHTML = 'File URL (.ics)';
  }

function excLabel(obj) {
  var srcLabel = $('excLabel');
  if (!srcLabel)
    return;
  if ($('exc_options_type_1').checked)
    srcLabel.innerHTML = 'WebDAV File URL (.ics)';
  if ($('exc_options_type_3').checked)
    srcLabel.innerHTML = 'CalDAV URL';
  if ($('exc_options_type_2').checked)
    srcLabel.innerHTML = 'File URL (.ics)';
}

var CAL = new Object();

CAL.trim = function(sString, sChar) {

	if (sString) {
		if (sChar == null)
      sChar = ' ';

		while (sString.substring(0, 1) == sChar) {
      sString = sString.substring(1, sString.length);
    }
		while (sString.substring(sString.length - 1, sString.length) == sChar) {
      sString = sString.substring(0,sString.length-1);
    }
  }
  return sString;
}

CAL.colorRef = function(fldName) {
	var callback = function(color) {
	  $(fldName).value = color;
	  $(fldName+"_div").style.backgroundColor = color;
	}
  var c = new OAT.Color();
	var coords = OAT.Event.position(fldName + "_div");
	c.pick(coords[0],coords[1],callback);
}
                        		
CAL.aboutDialog = function() {
  var aboutDiv = $('aboutDiv');
	if (aboutDiv)
		OAT.Dom.unlink(aboutDiv);

  aboutDiv = OAT.Dom.create('div', {
    width:'430px',
    height: '170px',
    overflow: 'hidden'
  });
  aboutDiv.id = 'aboutDiv';
	aboutDialog = new OAT.Dialog('About ODS Calendar', aboutDiv, {width: 445, buttons: 0, resize: 0, modal: 1});
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
	OAT.AJAX.POST("ajax.vsp", "a=about", x, {type: OAT.AJAX.TYPE_TEXT, onstart: function(){}, onerror: function(){}});
}
