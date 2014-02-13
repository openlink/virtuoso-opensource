/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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
  if ($('ab_main')) {
    var wDims = OAT.Dom.getViewport()
    var hDims = OAT.Dom.getWH('FT')
    var cPos = OAT.Dom.position('ab_main')
    $('ab_main').style.height = (wDims[1] - hDims[1] - cPos[1] - 20) + 'px';
  }
}

function urlParam(fldName)
{
  var obj = document.forms[0].elements[fldName];
  if (obj && obj.value != '')
    return '&' + fldName + '=' + encodeURIComponent(obj.value);

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

function myTags(fValue) {
  createHidden('F1', 'tag', fValue);
  vspxPost('pt_browse', 'pt_action', 'tags', 'pt_value', fValue);
}

function myCategory(fValue) {
  vspxPost('pt_browse', 'pt_action', 'category', 'pt_value', fValue);
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

function toolbarPost(fValue) {
  vspxPost('command', 'select', fValue);
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

function selectCheck(obj, prefix, noToolbars) {
  coloriseRow(getParent(obj, 'tr'), obj.checked);
  if (noToolbars)
    return;
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
  enableElement('tbSharing', 'tbSharing_gray', oCount>0);
  enableElement('tbDelete', 'tbDelete_gray', oCount>0);
}

function enableElement(id, id_gray, showFlag) {
  if (showFlag) {
    OAT.Dom.show(id);
    if ($(id))
      OAT.Dom.hide(id_gray);
    } else {
    OAT.Dom.hide(id);
    OAT.Dom.show(id_gray);
}
}

function selectAllCheckboxes(obj, prefix, noToolbars) {
  var objForm = obj.form;
  for (var i = 0; i < objForm.elements.length; i++) {
    var o = objForm.elements[i];
		if (o && o.type == "checkbox" && !o.disabled && o.name.indexOf(prefix) != -1) {
      if (obj.value == 'Select All')
        o.checked = true;
      else
        o.checked = false;
      coloriseRow(getParent(o, 'tr'), o.checked);
    }
  }
  obj.focus();
  if (obj.value == 'Select All')
    obj.value = 'Unselect All';
  else
    obj.value = 'Select All';

  if (noToolbars)
    return;
  enableToolbars(objForm, prefix);
}

function anySelected (form, txt, selectionMsq) {
  if ((form != null) && (txt != null)) {
    for (var i = 0; i < form.elements.length; i++) {
      var obj = form.elements[i];
			if (obj && obj.type == "checkbox" && obj.name.indexOf(txt) != -1 && obj.checked)
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

function showTag(tag) {
  createHidden2(parent.document, 'F1', 'tag', tag);
  parent.document.forms['F1'].submit();
}

function showTab(tabs, tabsCount, tabNo) {
	if (tabNo == null) { tabNo = $v('tabNo'); }
	if (tabNo == null) { tabNo = 0; }
	if ($(tabs)) {
		for ( var i = 0; i < tabsCount; i++) {
      var l = $(tabs+'_tab_'+i);      // tab labels
      var c = $(tabs+'_content_'+i);  // tab contents
			if (i == tabNo) {
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

function createHidden(frm_name, fld_name, fld_value) {
	return createHidden2(document, frm_name, fld_name, fld_value);
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
	return hidden;
}

function changeExportName(fld_name, from, to) {
  var obj = document.forms['F1'].elements[fld_name];
  if (obj)
    for (var i = 0; i < from.length; ++i)
      obj.value = (obj.value).replace(from[i], to);
}

function updateChecked(obj, objName) {
  var objForm = obj.form;
  coloriseRow(getParent(obj, 'tr'), obj.checked);
  objForm.s1.value = AB.trim(objForm.s1.value);
  objForm.s1.value = AB.trim(objForm.s1.value, ',');
  objForm.s1.value = AB.trim(objForm.s1.value);
  objForm.s1.value = objForm.s1.value + ',';
	for ( var i = 0; i < objForm.elements.length; i = i + 1) {
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
  objForm.s1.value = AB.trim(objForm.s1.value, ',');
}

function addTag(tag, objName) {
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
	return false;
}

function addCheckedTags(openerName, checkName) {
  if (window.opener.document.F1.elements[document.F1.elements[openerName].value]) {
    var objForm = document.F1;
    var objOpener = window.opener.document.F1.elements[document.F1.elements[openerName].value];

    objOpener.value = AB.trim(objOpener.value);
    objOpener.value = AB.trim(objOpener.value, ',');
    objOpener.value = AB.trim(objOpener.value);
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
    objOpener.value = AB.trim(objOpener.value, ',');
  }
  window.close();
}

function changeType(obj) {
	showTab('a', 7, 1);
  if (obj.value != "1") {
    OAT.Dom.show ('a_tab_2');
		OAT.Dom.show('a_tab_3');
  } else {
    OAT.Dom.hide ('a_tab_2');
		OAT.Dom.hide('a_tab_3');
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

function hasError(root) {
	if (!root) {
    // executingEnd();
		alert('No data!');
		return true;
	}

	/* error */
	var error = root.getElementsByTagName('error')[0];
	if (error) {
	  var code = error.getElementsByTagName('code')[0];
		if (OAT.Xml.textValue(code) != 'OK') {
	    var message = error.getElementsByTagName('message')[0];
      if (message)
        alert (OAT.Xml.textValue(message));
  		return true;
    }
  }
  return false;
}

function createState(stateName, stateValue) {
  var span = $('span_'+stateName);
	if (!span) {
		return false;
	}

  span.innerHTML = "";
  var s = stateName.replace(/State/, '');
	var f = function() {
		updateGeodata(s);
	};
	var fld = new OAT.Combolist( [], stateValue, {
		onchange : f
	});
  fld.input.name = stateName;
  fld.input.id = stateName;
  fld.input.size = "60";
  fld.addOption("");

  span.appendChild(fld.div);
  OAT.Event.attach(fld.input, "change", f);

  return fld;
}

function updateState(countryName, stateName, stateValue, hasGeodata) {
  var fld = createState(stateName, stateValue);
	if (!fld) {
		return false;
	}

	if ($v(countryName) != '') {
    var S = '/ods/api/lookup.list?key=Province&param='+encodeURIComponent($v(countryName));
		var x = function(data) {
      var xml = OAT.Xml.createXmlDoc(data);
    	var items = xml.getElementsByTagName("item");
			if (items.length) {
				for ( var i = 1; i <= items.length; i++) {
          fld.addOption(OAT.Xml.textValue(items[i-1]));
    	}
    }
    	if (!hasGeodata)
    	  updateGeodata(fld.input.id.replace(/State/, ''));
  	}
    OAT.AJAX.GET(S, '', x);
  }
}

function updateGeodata(mode) {
	var f = function(mode, fld) {
    var x = $(mode+fld);
    if (x)
      return '&' + fld.toLowerCase() + '=' + encodeURIComponent(x.value);
    return '';
  }
	var S = '/ods/api/address.geoData?' + f(mode, 'Address1')
			+ f(mode, 'Address2') + f(mode, 'City') + f(mode, 'Code')
			+ f(mode, 'State') + f(mode, 'Country');
	var cb = function(data, mode) {
    var o = null;
    try {
      o = OAT.JSON.parse(data);
    } catch (e) {
      o = null;
    }
		if (o) {
			if (o.lat) {
        var x = $(mode+'Lat');
        if (x)
          x.value = o.lat;
      }
			if (o.lng) {
        var x = $(mode+'Lng');
        if (x)
          x.value = o.lng;
  		}
  	}
	}
	OAT.AJAX.GET(S, '', function(arg) {cb(arg, mode);});
}

function davBrowse(fld, folders) {
	/* load stylesheets */
	OAT.Style.include("grid.css");
	OAT.Style.include("webdav.css");

  var options = {
    mode: 'browser',
    onConfirmClick: function(path, fname) {$(fld).value = '/DAV' + path + fname;}
  };
  if (!folders) {folders = false;}
  OAT.WebDav.options.foldersOnly = folders;
  OAT.WebDav.open(options);
}

function changeState(obj, fName) {
	if (obj) {
		if (obj.type == "checkbox" && obj.checked) {
      document.F1.elements[fName].disabled = false;
    } else {
      document.F1.elements[fName].disabled = true;
    }
  } else {
    document.F1.elements[fName].disabled = false;
  }
}

function exchangeHTML() {
  var S, T;

  T = $('ds_navigation');
	if (T) {
    S = $('navigation')
    if (S)
      S.innerHTML = T.innerHTML;
    T.innerHTML = '';
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
			if (o) {
				OAT.Dom.hide(o);
			}
    }
  }
	if (actions.show) {
    var a = actions.show;
		for ( var i = 0; i < a.length; i++) {
      var o = $(a[i])
			if (o) {
				OAT.Dom.show(o);
    }
  }
	}
	if (actions.clear) {
    var a = actions.clear;
		for ( var i = 0; i < a.length; i++) {
      var o = $(a[i])
			if (o && o.value) {
				o.value = '';
			}
    }
  }
	if (actions.exec) {
		var a = actions.exec;
		for ( var i = 0; i < a.length; i++) {
			a[i](obj);
		}
	}
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

function iType(obj) {
  var i = -1;
  if ($('i_type_0').checked)
    i = 0;
  if ($('i_type_1').checked)
    i = 1;
  if ($('i_type_2').checked)
    i = 2;
  if (i < 0)
    $('i_type_0').checked = true;
}

function urlParam(fldName)
{
  var O = document.forms[0].elements[fldName];
  if (O && O.value != '')
    return '&' + fldName + '=' + encodeURIComponent(O.value);
  return '';
}

// progress bar
var progressTimer = null;
var progressPollTimer = null;
var progressID = null;
var progressMax = null;
var progressSize = 40;
var progressInc = 100 / progressSize;

function stopState()
{
  progressTimer = null;
  var x = function (data) {
    doPost ('F1', 'btn_Background');
  }
  OAT.AJAX.POST('ajax.vsp', "a=load&sa=stop&id="+progressID+urlParam("sid")+urlParam("realm"), x, {async: false});
}

function initState()
{
  progressTimer = null;
  var x = function (data) {
    try {
      var xml = OAT.Xml.createXmlDoc(data);
      progressID = OAT.Xml.textValue(xml.getElementsByTagName('id')[0]);
    } catch (e) {}

    createProgressBar();
    progressTimer = setTimeout("checkState()", 500);

    document.forms['F1'].action = 'home.vspx';
  }
  OAT.AJAX.POST('ajax.vsp', "a=load&sa=init"+urlParam("sid")+urlParam("realm")+urlParam("i_type")+urlParam("i_data")+urlParam("i_options")+urlParam("i_validation"), x, {async: false});
}

function checkState()
{
  var x = function (data) {
    var progressIndex;
    try {
      var xml = OAT.Xml.createXmlDoc(data);
      progressIndex = OAT.Xml.textValue(xml.getElementsByTagName('index')[0]);
    } catch (e) { }

    showProgress (progressIndex);

    if ((progressIndex != null) && (progressIndex != progressMax)) {
      setTimeout("checkState()", 500);
      if (!progressPollTimer) {
        var progressPoll = xml.getElementsByTagName('poll')[0];
        if (progressPoll) {
          var progressPollAction = OAT.Xml.textValue(progressPoll.getElementsByTagName('action')[0]);
          if (progressPollAction == 'ask') {
            progressPollTimer = setTimeout("checkPollState()", 2000);
            var progressPollData = OAT.Xml.textValue(progressPoll.getElementsByTagName('data')[0]);
            if (!askDialog) {
              askDialog = new OAT.Dialog("Select action", "askDiv", {width:400, resize:0, buttons: 1, modal:1});
              OAT.Dom.show('askDiv');
            }
            OAT.MSG.attach(askDialog, "DIALOG_OK", function() {
              askDialog.hide();
              var pollValue = '';
              if ($('i_ask_0').checked)
                pollValue = 'answer:merge';
              if ($('i_ask_1').checked)
                pollValue = 'answer:override';
              if ($('i_ask_2').checked)
                pollValue = 'answer:skip';
              OAT.AJAX.POST('ajax.vsp', "a=load&sa=poll&id="+progressID+'&value='+pollValue+urlParam("sid")+urlParam("realm"), function(){});
              progressPollTimer = null;
              askprogressPollTimer = null;
            });
            $('askDiv_data').innerHTML = progressPollData;
            askDialog.show();
          }
        }
      }
    } else {
      progressTimer = null;
      progressPollTimer = null;
      $('btn_Stop').value = 'Close';
      OAT.Dom.hide('btn_Background');
      doPost ('F1', 'btn_Background');
    }
  }
  OAT.AJAX.POST('ajax.vsp', "a=load&sa=state&id="+progressID+urlParam("sid")+urlParam("realm"), x);
}

function checkPollState()
{
  var x = function (data) {
    if (progressTimer && progressPollTimer)
      setTimeout("checkPollState()", 2000);
  }
  OAT.AJAX.POST('ajax.vsp', "a=load&sa=poll&id="+progressID+urlParam("sid")+urlParam("realm"), x);
}

function createProgressBar()
{
  progressMax = $('progressMax').innerHTML;
  var centerCellName;
  var tableText = "";
  var tdText = "";
  for (x = 0; x < progressSize; x++) {
    if (progressMax != null) {
      if (x == (progressSize/2))
        centerCellName = "progress_" + x;
    }
    tableText += "<td id=\"progress_" + x + "\" width=\"" + progressInc + "%\" height=\"20\" bgcolor=\"blue\" />";
  }
  var idiv = $("progressText");
  if (idiv)
    idiv.innerHTML = "Imported 0 contacts from " + progressMax;
  var idiv = $("progressBar");
  if (idiv)
    idiv.innerHTML = "<table with=\"200\" border=\"0\" cellspacing=\"0\" cellpadding=\"0\"><tr>" + tableText + "</tr></table>";
  centerCell = $(centerCellName);
}

function showProgress (progressIndex)
{
  if (!progressMax)
    return;

  if (!progressIndex)
    progressIndex = progressMax;

  var idiv = $("progressText");
  if (idiv)
    idiv.innerHTML = "Imported " + progressIndex + " contacts from " + progressMax;
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
  for (x = 0; x < progressSize; x++)
  {
    var cell = $("progress_" + x);
    if ((cell) && (percentage/x < progressInc))
    {
      cell.style.backgroundColor = "blue";
    } else {
      cell.style.backgroundColor = "red";
    }
  }
}

var AB = new Object();
AB.trim = function(sString, sChar) {
	if (sString) {
		if (!sChar)
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

AB.getFOAFData = function(iri) {
	var S = '/ods/api/user.getFOAFData?spongerMode=1&foafIRI=' + encodeURIComponent(iri);
  var x = function(data) {
    var o = null;
    try {
      o = OAT.JSON.parse(data);
		} catch (e) {
			o = null;
		}
		if (o && o.iri) {
			if (confirm('New data for \'' + o.iri + '\' is founded. Would you like to import discovered data into the corresponding contact details fields?')) {
				AB.setFOAFValue(o.personalProfileDocument, 'ab_foaf');
        AB.setFOAFValue(o.iri, 'ab_iri');
				AB.setFOAFValue(o.nick, 'ab_name');
				AB.setFOAFValue(o.title, 'ab_title');
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
				AB.setFOAFValue(o.skypeChatID, 'ab_skype');
        AB.setFOAFValue(o.workplaceHomepage, 'ab_web');
        AB.setFOAFValue(o.homepage, 'ab_hWeb');
        AB.setFOAFValue(o.lat, 'ab_hLat');
        AB.setFOAFValue(o.lng, 'ab_hLng');
        AB.setFOAFValue(o.phone, 'ab_hPhone');
        AB.setFOAFValue(o.organizationHomepage, 'ab_bWeb');
        AB.setFOAFValue(o.organizationTitle, 'ab_bOrganization');
        AB.setFOAFValue(o.tags, 'ab_tags');
        // photo
				if (o.depiction) {
          AB.setFOAFValue(o.depiction, 'ab_photo_url');
          $('ab_photo_url').onchange();
          $('ab_photo_upload').onclick();
          $('ab_photo_source_1').checked = true;
          $('ab_photo_source_1').onchange();
        }
        // intersts
				if (o.interest) {
					for (var i = 0; i < o.interest.length; i++) {
						TBL.createRow('a',
						              null,
						              {fld_1 : {value: o.interest[i].value, className: '_validate_ _url_', onBlur: function() {validateField(this);}},
								           fld_2 : {value: o.interest[i].label}
								          }
								         );
					}
				}
				if (o.knows) {
					for (var i = 0; i < o.knows.length; i++) {
						TBL.createRow('b',
						              null,
                          {fld_1: {mode: 20, value: 'foaf:knows', className: "_validate_"},
                           fld_2: {value: o.knows[i].value, className: "_validate_ _uri_"}
      }
                         );
    }
  }
      }
    } else {
      alert('No data founded for \''+iri+'\'');
    }
  }
	OAT.AJAX.GET(S, '', x, {onstart : function() {OAT.Dom.show('ab_import_image')}, onend : function() {OAT.Dom.hide('ab_import_image')}});
}

AB.setFOAFValue = function(fValue, fName) {
  var fElement = document.forms[0].elements[fName];
	if (fValue && fElement) {
		if (fElement.type == 'select-one') {
      var o = fElement.options;
			for ( var i = 0; i < o.length; i++) {
				if (o[i].value == fValue) {
    		  o[i].selected = true;
    		  o[i].defaultSelected = true;
    		}
    	}
    } else {
      fElement.value = fValue;
    }
  }
}

AB.aboutDialog = function() {
  var aboutDiv = $('aboutDiv');
  if (aboutDiv)
		OAT.Dom.unlink(aboutDiv);

  aboutDiv = OAT.Dom.create('div', {height: '160px', overflow: 'hidden'});
  aboutDiv.id = 'aboutDiv';
  aboutDialog = new OAT.Dialog('About ODS AddressBook', aboutDiv, {width:445, buttons: 0, resize:0, modal:1});
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
	OAT.AJAX.POST("ajax.vsp", "a=about", x, {
		type : OAT.AJAX.TYPE_TEXT,
		onstart : function() {},
		onerror : function() {}
	});
}

AB.getFileName = function(from, to) {
  var S = from.value;
  var N;
	if (S.lastIndexOf('\\') > 0) {
    N = S.lastIndexOf('\\') + 1;
  } else {
    N = S.lastIndexOf('/') + 1;
  }
  var S = S.substr(N, S.length);
	if (S.indexOf('?') > 0) {
    N = S.indexOf('?');
    S = S.substr(0, N);
  }
	if (S.indexOf('#') > 0) {
    N = S.indexOf('#');
    S = S.substr(0, N);
  }
  to.value = S;
}
