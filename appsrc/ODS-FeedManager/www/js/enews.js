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
function myPost(frm_name, fld_name, fld_value) {
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
function getObject(id, doc) {
  if (doc == null)
    doc = document;
  if (doc.all)
    return doc.all[id];
  return doc.getElementById(id);
}

// ---------------------------------------------------------------------------
function confirmAction(confirmMsq, form, txt, selectionMsq) {
  if (anySelected (form, txt, selectionMsq))
    return confirm(confirmMsq);
  return false;
}

// ---------------------------------------------------------------------------
function selectAllCheckboxes (form, btn, txt) {
  for (var i = 0; i < form.elements.length; i++) {
    var obj = form.elements[i];
    if (obj != null && obj.type == "checkbox" && !obj.disabled && obj.name.indexOf (txt) != -1) {
      if (btn.value == 'Select All')
        obj.checked = true;
      else
        obj.checked = false;
    }
  }
  if (btn.value == 'Select All')
    btn.value = 'Unselect All';
  else
    btn.value = 'Select All';
  btn.focus();
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
        rows[i].className = "td_row" + (i % 2);;
      }
    }
  }
}

// ---------------------------------------------------------------------------
function trim(sString) {
  while (sString.substring(0,1) == ' ')
    sString = sString.substring(1, sString.length);

  while (sString.substring(sString.length-1, sString.length) == ' ')
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
function clickNode2(obj)
{
  var nodes = obj.parentNode.childNodes;
  for (var i=0; i<nodes.length; i++) {
    var node = nodes[i];
    if (node.tagName == 'A')
      if (node.onclick)
        return node.onclick();
  }
}

// ---------------------------------------------------------------------------
function loadIFrame(id, domainID, accountID, flag, mode)
{
  if (flag == null)
    flag = 'r1';
  if (mode == null)
    mode = 'channel';
  if ((mode != 'p') && (accountID != '-1')) {
    readObject('feed_'+id, flag, document);
    flagObject('image_'+id, flag, document);
    showCount(document);
  }
  var sid = '';
  if (document.forms['F1'].elements['sid'])
    sid = document.forms['F1'].elements['sid'].value;
  var realm = '';
  if (document.forms['F1'].elements['realm'])
    realm = document.forms['F1'].elements['realm'].value;
  var URL = 'view.vspx?sid='+sid+'&realm='+realm+'&fid='+id+'&did='+domainID+'&aid='+accountID+'&f='+flag+'&m='+mode;
  document.getElementById('feed_content').innerHTML = '<iframe src="'+URL+'" style="margin: -2px 0px 0px 0px;" width="100%" height="100%" frameborder="0" scrolling="auto" hspace="0" vspace="0" marginwidth="0" marginheight="0"></iframe>';
}

// ---------------------------------------------------------------------------
function loadIFrameURL(URL)
{
  document.getElementById('feed_content').innerHTML = '<iframe src="http://feedvalidator.org/check.cgi?url='+URL+'" style="margin: -2px 0px 0px 0px;" width="100%" height="100%" frameborder="0" scrolling="auto" hspace="0" vspace="0" marginwidth="0" marginheight="0"></iframe>';
}

// ---------------------------------------------------------------------------
function myInit()
{

  var favourites = $('pane_right2');
  if (favourites) {
    var gd = new OAT.GhostDrag();

    var dummyReference = function(){};
    var successReference = function(node) {
      return function(target,x,y) {
        addFavourite(node.id.replace('pt_node_',''));
      }
    }
    gd.addTarget(favourites);
    nodes = document.getElementsByTagName('span');
    if (nodes)
      for (var i = 0; i < nodes.length; i++)
        if (nodes[i].id)
          if (nodes[i].id.indexOf('pt_node_') != -1)
            gd.addSource(nodes[i], dummyReference, successReference(nodes[i]));
  }
}

// ---------------------------------------------------------------------------
function addFavourite(node)
{
  var favourite = $('pt_favourite_'+node);
  if (favourite)
    return;
  var tNode = $('pt_node_'+node);
  if (!tNode)
    return;

  var S = 'favourites.vsp?sid='+document.F1.sid.value+'&realm='+document.F1.realm.value+'&a=add&node='+escape(node)+'&seq=1';
  OAT.AJAX.GET(S, '', favouriteCallback);
}

// ---------------------------------------------------------------------------
function favouriteCallback()
{
  getFavourites ();
}

// ---------------------------------------------------------------------------
function removeFavourite(node)
{
  var favourite = $('pt_favourite_'+node);
  if (!favourite)
    return;
  if (confirmAction('Are you sure you want to remove this item from Favourites?')) {
    var S = 'favourites.vsp?sid='+document.F1.sid.value+'&realm='+document.F1.realm.value+'&a=remove&node='+escape(node)+'&seq=1';
    OAT.AJAX.GET(S, '', favouriteCallback);
  }
}

// ---------------------------------------------------------------------------
function getFavourites()
{
  var S = 'favourites.vsp?sid='+document.F1.sid.value+'&realm='+document.F1.realm.value+'&a=list';
  OAT.AJAX.GET(S, '', getFavouritesCallback);
}

// ---------------------------------------------------------------------------
function getFavouritesCallback(txt)
{
  $("pane_right2").innerHTML = txt;
}

// ---------------------------------------------------------------------------
function loadFromIFrame(id, domainID, accountID, flag, mode) {
  if (flag == null)
    flag = 'r1';
  if (mode == null)
    mode = 'channel';
  readObject('feed_'+id, flag, parent.document);
  flagObject('image_'+id, flag, parent.document);
  showCount(parent.document);
  var sid = '';
  if (document.forms['F1'].elements['sid'])
    sid = document.forms['F1'].elements['sid'].value;
  var realm = '';
  if (document.forms['F1'].elements['realm'])
    realm = document.forms['F1'].elements['realm'].value;
  var URL = 'view.vspx?sid='+sid+'&realm='+realm+'&fid='+id+'&did='+domainID+'&aid='+accountID+'&f='+flag+'&m='+mode;
  parent.document.getElementById('feed_content').innerHTML = '<iframe src="'+URL+'" style="margin: -2px 0px 0px 0px;" width="100%" height="100%" frameborder="no" scrolling="auto" hspace="0" vspace="0" marginwidth="0" marginheight="0"></iframe>';
}

// ---------------------------------------------------------------------------
function readObject(id, flag, doc) {
  if (doc == null)
    doc = document;
  if (flag == null)
    flag = 'r0';
  var c = getObject(id, doc);
  if (c) {
    if (flag == 'r0') {
      OAT.Dom.removeClass(c, 'read');
      OAT.Dom.addClass(c, 'unread');
    }
    if (flag == 'r1') {
      OAT.Dom.removeClass(c, 'unread');
      OAT.Dom.addClass(c, 'read');
    }
  }
}

// ---------------------------------------------------------------------------
function flagObject(id, flag, doc) {
  if (doc == null)
    doc = document;
  var c = getObject(id, doc);
  if (c) {
    if (flag == 'f0')
      if (c.innerHTML != '')
        c.innerHTML = '';
    if (flag == 'f1')
      if (c.innerHTML == '')
        c.innerHTML = '<img src="image/flag.gif" border="0"/>';
  }
}

// ---------------------------------------------------------------------------
function showCount(doc) {
  if (doc == null)
    doc = document;
  var countAll = 0;
  var countUnread = 0;
  var links = doc.links;
  for (var i=0; i<links.length; i++) {
    if (links[i].id.indexOf('feed_') != -1) {
      countAll += 1;
      if (OAT.Dom.isClass(links[i], 'unread'))
        countUnread += 1;
    }
  }
  var c = getObject('feed_count', doc);
  if (c)
    if (c.innerHTML != (countAll+' ('+countUnread+')'))
      c.innerHTML = countAll+' ('+countUnread+')';
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
  win = window.open(sPage, null, "width="+width+",height="+height+",top=100,left=100,status=yes,toolbar=yes,menubar=yes,scrollbars=yes,resizable=yes");
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
// Hidden functions
//
// ---------------------------------------------------------------------------
function createHidden(frm_name, fld_name, fld_value) {
  createHidden2(document, frm_name, fld_name, fld_value);
}

// ---------------------------------------------------------------------------
//
function createHidden2(doc, frm_name, fld_name, fld_value)
{
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
// Menu functions
//
// ---------------------------------------------------------------------------
function menuMouseIn(a, b)
{
  if (b != undefined) {
    while (b.parentNode) {
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

// ---------------------------------------------------------------------------
//
function menuPopup(button, menuID)
{
  if (document.getElementsByTagName && !document.all)
    document.all = document.getElementsByTagName("*");
  if (document.all) {
    for (var i = 0; i < document.all.length; i++) {
      var obj = document.all[i];
      if (obj.id.search('menuAction') != -1) {
        obj.style.visibility = 'hidden';
        if (browser.isIE) {
          obj.onmouseout = menuMouseOut;
        } else {
          obj.addEventListener("mouseout", menuMouseOut, true);
        }
      }
    }
  }

  button.blur();
  var div = document.getElementById(menuID);
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

// ---------------------------------------------------------------------------
//
function urlParams(mask)
{
  var S = '';
  var form = document.forms['F1'];

  for (var i = 0; i < form.elements.length; i++) {
    var obj = form.elements[i];
    if ((obj.name.indexOf (mask) != -1) && (((obj.type == "checkbox") && (obj.checked)) || (obj.type != "checkbox")))
      S += '&' + form.elements[i].name + '=' + encodeURIComponent(form.elements[i].value);
  }
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
function initRequest()
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

function resetState()
{
	var xmlhttp = initRequest();
	xmlhttp.open("POST", URL + "?mode=reset" + urlParams("sid") + urlParams("realm"), false);
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
	xmlhttp.open("POST", URL+"?mode=stop&id="+progressID+urlParams("sid")+urlParams("realm"), false);
	xmlhttp.setRequestHeader("Pragma", "no-cache");
  xmlhttp.send(null);

  doPost ('F1', 'btn_Background');
}

// ---------------------------------------------------------------------------
//
function initState()
{
  hideObject('btn_Back');
  hideObject('btn_Subscribe');
  showObject('btn_Background');
	document.getElementById("btn_Background").disabled = true;
	document.getElementById("btn_Stop").disabled = true;
 	document.getElementById("btn_Stop").value = 'Stop';

	// reset state first
	resetState();

	// init state
	var xmlhttp = initRequest();
	xmlhttp.open("POST", URL, false);
	xmlhttp.setRequestHeader("Pragma", "no-cache");
  xmlhttp.setRequestHeader("Content-Type", "application/x-www-form-urlencoded; charset=UTF-8");
	xmlhttp.send("mode=init&id="+progressID+urlParams("sid")+urlParams("realm")+urlParams("cb_item")+urlParams("$_"));

	hideObject("feeds");
  createProgressBar();
	if (timer == null)
		timer = setTimeout("checkState()", 1000);

  document.forms['F1'].action = 'channels.vspx';
  var obj = document.getElementById("feeds");
   if (obj)
     obj.innerHTML = '';
  obj = document.getElementById("feedsData");
   if (obj)
     obj.innerHTML = '';
}

// ---------------------------------------------------------------------------
//
function checkState()
{
	var xmlhttp = initRequest();
	xmlhttp.open("POST", URL+"?mode=state&id="+progressID+urlParams("sid")+urlParams("realm"), true);
	xmlhttp.onreadystatechange = function() {
	  if (xmlhttp.readyState == 4) {
      var progressIndex;

      // progressIndex
      try {
        progressIndex = xmlhttp.responseXML.getElementsByTagName("index")[0].firstChild.nodeValue;
      } catch (e) { }

      if (timer != null)
      showProgress(progressIndex);
     	document.getElementById("btn_Background").disabled = false;
     	document.getElementById("btn_Stop").disabled = false;
			if ((progressIndex != null) && (progressIndex != progressMax)) {
        setTimeout("checkState()", 1000);
			} else {
       	document.getElementById("btn_Stop").value = 'Finish';
       	document.getElementById("btn_Background").disabled = true;
			  timer = null;
			}
	  }
	}
	xmlhttp.setRequestHeader("Pragma", "no-cache");
	xmlhttp.send("");
}

// ---------------------------------------------------------------------------
//
function progressText(txt)
{
  getObject('progressText').innerHTML = txt;

  progressMax = 0;
  var form = document.forms['F1'];
  for (var i = 0; i < form.elements.length; i++) {
    var obj = form.elements[i];
    if (obj != null && obj.type == "checkbox" && obj.name.indexOf ('cb_item') != -1 && obj.checked)
      progressMax += 1;
  }
  getObject('progressMax').innerHTML = progressMax;
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
    tdText = "";
    if (x == ((size/2)-1)) {
      centerCellName = "progress_" + x;
      tdText = "<font color=\"white\">" + 0 + '&nbsp;out&nbsp;of&nbsp;' + progressMax + "</font>"
    }
    if (x == (size/2))
      tdText = "<font color=\"white\">" + "Subscriptions</font>";
    if (x == ((size/2)+1))
      tdText = "<font color=\"white\">" + "Completed</font>";
    tableText += "<td id=\"progress_" + x + "\" width=\"" + increment + "%\" height=\"20\" bgcolor=\"blue\">"+tdText+"</td>";
  }
  var idiv = window.document.getElementById("progress");
  idiv.innerHTML = "<table with=\"200\" border=\"0\" cellspacing=\"0\" cellpadding=\"0\"><tr>" + tableText + "</tr></table>";
  centerCell = window.document.getElementById(centerCellName);
}

// ---------------------------------------------------------------------------
//
// show the current percentage
//
function showProgress(progressIndex)
{
  if (progressIndex == null)
    progressIndex = progressMax;

  var percentage = progressIndex * 100 / progressMax;
  centerCell.innerHTML = "<font color=\"white\">" + progressIndex + '&nbsp;out&nbsp;of&nbsp;' + progressMax + "</font>";
  for (x = 0; x < size; x++) {
    var cell = window.document.getElementById("progress_" + x);
    if ((cell) && (percentage/x < increment)) {
      cell.style.backgroundColor = "blue";
    } else {
      cell.style.backgroundColor = "red";
    }
  }
}
