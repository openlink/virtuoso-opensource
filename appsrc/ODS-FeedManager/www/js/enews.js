/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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
var Feeds = new Object();

// Drag Object
Feeds.gdDummy = function(){};

Feeds.gdSuccess = function(node)
{
  return function(target,x,y) {Feeds.addFavourite(node);}
}

Feeds.trim = function (sString, sChar)
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
  return sString;
}

Feeds.writeCookie = function (name, value, hours)
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

Feeds.readCookie = function (name)
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

Feeds.readField = function (field, doc)
{
  var v;
  if (!doc)
    doc = document;
  if (doc.forms[0]) {
    v = doc.forms[0].elements[field];
    if (v)
      v = v.value;
    }
  return v;
}

Feeds.createParam = function (field, doc)
{
  var S = '';
  var v = Feeds.readField(field, doc);
  if (v)
    S = '&'+field+'='+ encodeURIComponent(v);
  return S;
}

Feeds.sessionParams = function (doc)
{
  return Feeds.createParam('sid', doc)+Feeds.createParam('realm', doc);
}

Feeds.initState = function (state)
{
  if (!state)
    var state = new Object();

  delete state.sid;
  var v = Feeds.readField('sid');
  if (v)
    state.sid = v;

  delete state.realm;
  var v = Feeds.readField('realm');
  if (v)
    state.realm = v;
  if (!state.tab)
    state.tab = 'feeds';

  return state;
}

Feeds.saveState = function ()
{
  Feeds.writeCookie('Feeds_State', escape(OAT.JSON.stringify(Feeds.state)), 1);
}

Feeds.toggleLeftPane = function (pane)
{
  Feeds.state.tab = pane;
  Feeds.saveState();

  Feeds.initFeeds();
  Feeds.initTags();
}

Feeds.initLeftPane = function ()
{
  var div = $('pane_left');
  if (!div)
    return;

  // favorites
  var favourites = $('pane_right2');
  if (favourites)
  {
    Feeds.listFavourites();
    Feeds.gd = new OAT.GhostDrag();
    Feeds.gd.addTarget(favourites);
  }

  // load cookie data
  var s = Feeds.readCookie('Feeds_State');
  if (s) {
    try {
      s = OAT.JSON.parse(unescape(s));
    } catch (e) { s = null; }
    s = Feeds.initState(s);
  } else {
    s = Feeds.initState();
  }
  Feeds.state = s;
  var v = $('nodePath');
  if (v && (v.value != '')) {
    Feeds.state.selected = v.value;
    if (v.value.indexOf('t#') == 0)
      Feeds.state.tab = 'tags';
    Feeds.saveState();
  }

  Feeds.initFeeds()
  Feeds.initTags()
}

Feeds.initTags = function ()
{
  var div = $('pane_left_tags');
  if (!div)
    return;

  if (Feeds.state.tab != 'tags') {
    OAT.Dom.addClass('tags_button', 'tab2');
    OAT.Dom.removeClass('tags_button', 'activeTab2');
    OAT.Dom.hide('pane_left_tags');
    return;
  }

  OAT.Dom.show('pane_left_tags');
  OAT.Dom.removeClass('tags_button', 'tab2');
  OAT.Dom.addClass('tags_button', 'activeTab2');

  if (div.innerHTML != '...')
    return;

  Feeds.loadTags();
}

Feeds.loadTags = function ()
{
  var div = $('pane_left_tags');
  div.innerHTML = '';

  var x = function(data) {
    div.innerHTML = data;
    var selected = Feeds.state.selected;
    if (selected && selected.indexOf('t#') == 0)
      Feeds.selectTag(selected);
  }
  var S = 'ajax.vsp?a=tags&sa=load&np='+encodeURIComponent(Feeds.state.selected)+Feeds.sessionParams();
  OAT.AJAX.GET(S, '', x);
}

Feeds.selectTag = function (tag)
{
  Feeds.toggleLeftPane('tags');
  var newTag = tag.replace('t#', '');
  if (tag.indexOf('t#') != 0)
    tag = 't#'+tag;
  aTags = $('pane_left_tags').getElementsByTagName('a');
  for (var i = 0; i < aTags.length; i++)
  {
    a = aTags[i];
    if (a.id)
    {
      if (a.id.indexOf('t_tag_') == 0)
      {
        OAT.Dom.removeClass(a, 'FM_bold');
        if (a.id == ('t_tag_' + newTag))
          OAT.Dom.addClass(a, 'FM_bold');
      }
    }
  }
  Feeds.state.selected = tag;
  Feeds.saveState();
  Feeds.loadItems(Feeds.state.selected)
}

Feeds.initFeeds = function ()
{
  var div = $('pane_left_feeds');
  if (!div)
    return;

  if (Feeds.state.tab != 'feeds') {
    OAT.Dom.addClass('feeds_button', 'tab2');
    OAT.Dom.removeClass('feeds_button', 'activeTab2');
    OAT.Dom.hide('pane_left_feeds');
    return;
  }

  OAT.Dom.removeClass('feeds_button', 'tab2');
  OAT.Dom.addClass('feeds_button', 'activeTab2');
  OAT.Dom.show('pane_left_feeds');

  if (div.innerHTML != '...')
    return;

  Feeds.loadFeeds();
}

Feeds.loadFeeds = function ()
{
  var div = $('pane_left_feeds');
  div.innerHTML = '';

  Feeds.tree = new OAT.Tree();
  var ul = OAT.Dom.create("ul",{whiteSpace:"nowrap"});
  Feeds.tree.assign(ul, true);
  div.appendChild(ul);

  OAT.MSG.attach(Feeds.tree, OAT.MSG.TREE_EXPAND, function(sender,msg,node) {
    var nodePath = node.myPath;
    Feeds.expandTree(nodePath, node);
  });
  OAT.MSG.attach(Feeds.tree, OAT.MSG.TREE_COLLAPSE, function(sender,msg,node) {
    var nodePath = node.myPath;
    Feeds.collapseTree(nodePath, node);
  });

  // load and open selected nodes
  var x = function() {
    var v = new Array();
    if (Feeds.state.expanded) {
      for (var i = 0; i < Feeds.state.expanded.length; i++)
        v.push(Feeds.state.expanded[i]);
      }
    if (Feeds.state.selected)
      v.push(Feeds.state.selected);

    Feeds.loadPath(v, 0);
  };
  Feeds.loadTree('', Feeds.tree.tree, x);
}

Feeds.loadPath = function (w, wIndex)
{
  var selectNode;
  for (var n = wIndex; n < w.length; n++) {
    var nodePath = w[n];
    var parts = nodePath.split("/");
    if (parts[0] == "") { parts.shift(); }
    if (parts[parts.length-1] == "") { parts.pop(); }

    var node = Feeds.tree.tree;
    var currentPath = '';

    for (var i = 0; i < parts.length; i++) {
      currentPath += '/' + parts[i];
      var index = -1;
      for (var j = 0; j < node.children.length; j++) {
        var child = node.children[j];
        if (child.myPath == currentPath) {
          if ((child.children.length == 0) && child.ul) {
            var x = function() {Feeds.loadPath(w, n);};
            Feeds.loadTree(currentPath, child, x);
            return;
          }
          index = j;
          break;
        }
      }
      if (index == -1) {break;}

      node = node.children[index];
      node.expand(true);
      if (Feeds.state.selected == node.myPath)
        selectNode = node;
      }
    node.toggleSelect({ctrlKey:false});
  }
  Feeds.loadItems(Feeds.selectPath());
}

Feeds.selectPath = function ()
{
  if (Feeds.state.selected) {
    if (Feeds.state.selected.indexOf('t#') != 0) {
      var parts = Feeds.state.selected.split("/");
      if (parts[0] == "") { parts.shift(); }
      if (parts[parts.length-1] == "") { parts.pop(); }

      var node = Feeds.tree.tree;
      var currentPath = '';

      for (var i = 0; i < parts.length; i++) {
        currentPath += '/' + parts[i];
        for (var j = 0; j < node.children.length; j++) {
          var child = node.children[j];
          if (child.myPath == currentPath) {
            if (Feeds.state.selected == child.myPath) {
              child.select();
              return child.myID;
            }
            index = j;
            break;
          }
        }
        if (index == -1) {return;}
        node = node.children[index];
        if (!node)
          break;
      }
      Feeds.state.selected = '';
    }
  }
  return Feeds.state.selected;
}

Feeds.loadTree = function(nodePath, node, nodeFunction)
{
  var S = 'ajax.vsp?a=tree&sa=load&np='+encodeURIComponent(nodePath)+Feeds.sessionParams();
  var x = function(data) {
    Feeds.updateTree(data, node, nodePath, nodeFunction);
  }
  OAT.AJAX.GET(S, '', x);
}

Feeds.updateTree = function(data, node, nodePath, nodeFunction)
{
  function attach(node, path) {
    OAT.Event.attach(node._gdElm, 'click', function() {Feeds.selectNode(path, node);});
  }
  var o = OAT.JSON.parse(data);
  for (var i = 0; i < o.length; i++) {
    var item = o[i];
    var iID = item[0];
    var iType = item[1];
    var iLabel = item[2];
    var iPath = item[3];
    var iImage = item[4];
    var iSelected = item[5];
    var iDraggable = item[6];

    var newNode = node.createChild(iLabel, iType==0? false: true);
    if (iImage != '')
      newNode.setImage(iImage);
    attach(newNode, iPath)
    newNode.collapse();

    /* draggable */
    if ((iDraggable == 1) && (Feeds.gd))
      Feeds.gd.addSource(newNode._gdElm, Feeds.gdDummy, Feeds.gdSuccess(iID));

    /* custom properties */
    newNode.myID = iID;
    newNode.myPath = iPath;
    newNode.selectable = iSelected==0? false: true;
  }
  if (node.children.length == 0)
    node.ul = false
  Feeds.tree.walk("sync");
  if (nodeFunction)
    nodeFunction();
}

Feeds.expandTree = function (nodePath, node)
{
  var a = Feeds.state.expanded;
  if (!a) {
    a = [nodePath];
  } else {
    var N = a.find(nodePath);
    if (N == -1)
      a.push(nodePath);
    }
  Feeds.state.expanded = a;
  Feeds.saveState();

  if (node.children.length != 0) { return; } /* nothing when already fetched */

  Feeds.loadTree(nodePath, node);
}

Feeds.collapseTree = function (nodePath, node)
{
  var expanded = Feeds.state.expanded;
  if (expanded) {
    var N = expanded.find(nodePath);
    if (N != -1) {
      var a = [];
      for (var i = 0; i < expanded.length; i++) {
        if (i != N)
          a.push(expanded[i]);
        }
      Feeds.state.expanded = a;
      Feeds.saveState();
    }
  }
}

Feeds.selectNode = function(nodePath, node)
{
  if (node.selectable) {
    Feeds.loadItems(node.myID);
    Feeds.state.selected = nodePath;
    Feeds.saveState();
  }
}

Feeds.loadItems = function(nodeID)
{
  $('pane_right_bottom').innerHTML = '';
  var URL = 'items.vspx?node='+encodeURIComponent(nodeID)+Feeds.sessionParams();
  var v = $('nodeItem');
  if (v && (v.value != '')) {
    URL += '&item=' + v.value;
    v.value = '';
  }
  $('pane_right_top').innerHTML = '<iframe id="feed_items" src="'+URL+'" width="100%" height="100%" frameborder="0" scrolling="auto" hspace="0" vspace="0" marginwidth="0" marginheight="0"></iframe>';
}

Feeds.addFavourite = function (node)
{
  if ($('pt_favourite_'+node)) {return;}
  var x = function(data) {
    Feeds.listFavourites();
  }
  var S = 'ajax.vsp?a=favourites&sa=add&node='+escape(node)+'&seq=1'+Feeds.sessionParams();
  OAT.AJAX.GET(S, '', x);
}

Feeds.removeFavourite = function (node)
{
  if (!$('pt_favourite_'+node)) {return};
  if (confirmAction('Are you sure you want to remove this item from Favourites?')) {
    var x = function(data) {
      Feeds.listFavourites();
    }
    var S = 'ajax.vsp?a=favourites&sa=remove&node='+escape(node)+'&seq=1'+Feeds.sessionParams();
    OAT.AJAX.GET(S, '', x);
  }
}

Feeds.selectFavourite = function (nodePath)
{
  Feeds.state.selected = nodePath;
  Feeds.loadPath ([nodePath], 0);
}

Feeds.listFavourites = function ()
{
  var x = function(data) {
    $("pane_right2").innerHTML = data;
  }
  var S = 'ajax.vsp?a=favourites&sa=list'+Feeds.sessionParams();
  OAT.AJAX.GET(S, '', x);
}

Feeds.aboutDialog = function ()
{
  var aboutDiv = $('aboutDiv');
  if (aboutDiv)
    OAT.Dom.unlink(aboutDiv);

  aboutDiv = OAT.Dom.create('div', {height: '160px', overflow: 'hidden'});
  aboutDiv.id = 'aboutDiv';
  aboutDialog = new OAT.Dialog('About ODS FeedsManager', aboutDiv, {width:445, buttons: 0, resize:0, modal:1});
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
  OAT.AJAX.POST("ajax.vsp", "a=about", x, {type:OAT.AJAX.TYPE_TEXT, onstart:function(){}, onerror:function(){}});
}

function setFooter() {
  if ($('pane_main')) {
    var wDims = OAT.Dom.getViewport()
    var hDims = OAT.Dom.getWH('FT')
    var cPos = OAT.Dom.position('pane_main')
    $('pane_main').style.height = (wDims[1] - hDims[1] - cPos[1] - 20) + 'px';
  }
}

function myPost(frm_name, fld_name, fld_value)
{
  createHidden(frm_name, fld_name, fld_value);
  document.forms[frm_name].submit();
}

function myTags(fld_value)
{
  createHidden('F1', 'tag', fld_value);
  doPost ('F1', 'pt_tags');
}

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
	if (!format)
		format = 'yyyy-MM-dd';

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

function checkNotEnter(e)
{
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

function getObject(id, doc)
{
  if (!doc) {doc = document;}
  return doc.getElementById(id);
}

function confirmAction(confirmMsq, form, txt, selectionMsq)
{
  if (anySelected (form, txt, selectionMsq))
    return confirm(confirmMsq);
  return false;
}

function selectAllCheckboxes (form, btn, txt)
{
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

function anySelected (form, txt, selectionMsq)
{
  if ((form != null) && (txt != null))
  {
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

function coloriseTable(id)
{
  var table = $(id);
  if (table) {
      var rows = table.getElementsByTagName("tr");
      for (i = 0; i < rows.length; i++)
        rows[i].className = "tr_" + (i % 2);;
      }
    }

function clickNode(obj)
{
  var nodes = obj.parentNode.childNodes;
  for (var i=0; i<nodes.length; i++) {
    var node = nodes[i];
    if ((node.tagName == 'A') && (node.innerHTML)) {
        if (node.innerHTML.indexOf('<IMG') == 0)
           return node.onclick();
        if (node.innerHTML.indexOf('<img') == 0)
           return node.onclick();
      }
  }
}

function clickNode2(obj)
{
  var nodes = obj.parentNode.childNodes;
  for (var i=0; i<nodes.length; i++) {
    var node = nodes[i];
    if ((node.tagName == 'A') && (node.onclick))
        return node.onclick();
  }
}

function loadIFrame(id, mode)
{
  var doc = parent.document;
  if (!mode)
    mode = 'c';
  if (mode != 'p')
    readObject('feed_'+id, 'r1');

  var URL = 'item.vspx?&fid='+id+'&f=r1&m='+mode+Feeds.sessionParams(doc);
  getObject('pane_right_bottom', doc).innerHTML = '<iframe id="feed_item" src="'+URL+'" style="margin: -2px 0px 0px 0px;" width="100%" height="100%" frameborder="0" scrolling="auto" hspace="0" vspace="0" marginwidth="0" marginheight="0"></iframe>';
}

function loadIFrameURL(URL)
{
  var doc = parent.document;
  getObject('pane_right_bottom', doc).innerHTML = '<iframe src="http://feedvalidator.org/check.cgi?url='+encodeURIComponent(URL)+'" style="margin: -2px 0px 0px 0px;" width="100%" height="100%" frameborder="0" scrolling="auto" hspace="0" vspace="0" marginwidth="0" marginheight="0"></iframe>';
}

function loadFromIFrame(id, mode, flag)
{
  var doc = parent.document;
  var frame = getObject('feed_items', doc);
  if (frame) {
    readObject('feed_'+id, flag, frame.contentDocument);
    flagObject('image_'+id, flag, frame.contentDocument);
  }
  var URL = 'item.vspx?fid='+id+'&f='+flag+'&m='+mode+Feeds.sessionParams(doc);
  getObject('pane_right_bottom', doc).innerHTML = '<iframe src="'+URL+'" style="margin: -2px 0px 0px 0px;" width="100%" height="100%" frameborder="no" scrolling="auto" hspace="0" vspace="0" marginwidth="0" marginheight="0"></iframe>';
}

function readObject(id, flag, doc)
{
  var c = getObject(id, doc);
  if (!c)
    return;

    if (flag == 'r0')
{
    OAT.Dom.removeClass(c, 'read');
    OAT.Dom.addClass(c, 'unread');
}
    else if (flag == 'r1')
    {
    OAT.Dom.removeClass(c, 'unread');
    OAT.Dom.addClass(c, 'read');
  }
}

function flagObject(id, flag, doc)
{
  var c = getObject(id, doc);
  if (!c)
    return;

    if (flag == 'f0')
    {
        c.innerHTML = '';
}
    else if (flag == 'f1')
    {
      c.innerHTML = '<img src="image/flag.gif" border="0"/>';
    }
  }

function showTag(tag)
{
  parent.Feeds.selectTag(tag);
}

function showTab(tabs, tabsCount, tabNo)
{
  if (!$(tabs))
    return;

  for (var i = 0; i < tabsCount; i++) {
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
  win = window.open(sPage, sPageName, "width="+width+",height="+height+",top=100,left=100,status=yes,toolbar=yes,menubar=yes,scrollbars=yes,resizable=yes");
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

function rowSelectValue(dstField, srcField, singleMode)
{
  if (singleMode)
  {
    dstField.value = srcField.value;
  } else {
    if (dstField.value.indexOf(srcField.value) == -1)
    {
      if (dstField.value == '')
      {
        dstField.value = srcField.value;
      } else {
        dstField.value = dstField.value + ', ' + srcField.value;
      }
    }
  }
}

// Hidden functions
function createHidden(frm_name, fld_name, fld_value)
{
  createHidden2(document, frm_name, fld_name, fld_value);
}

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

// Menu functions
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

function urlParams(mask)
{
  var S = '';
  var form = document.forms['F1'];
  for (var i = 0; i < form.elements.length; i++) {
    var obj = form.elements[i];
    if ((obj.name.indexOf (mask) != -1) && (((obj.type == "checkbox") && (obj.checked)) || (obj.type != "checkbox")))
      S += '&' + obj.name + '=' + encodeURIComponent(obj.value);
  }
  return S;
}

var progressTimer = null;
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
  OAT.AJAX.POST('ajax.vsp', "a=load&sa=stop&id="+progressID+urlParams("sid")+urlParams("realm"), x, {async: false});
}

function initState()
{
  progressTimer = null;
  var x = function (data) {
    try {
      var xml = OAT.Xml.createXmlDoc(data);
      progressID = OAT.Xml.textValue(xml.getElementsByTagName('id')[0]);
    } catch (e) {}

    OAT.Dom.hide('btn_Back');
    OAT.Dom.hide('btn_Subscribe');
    OAT.Dom.show('btn_Background');
    $("btn_Background").disabled = true;
    $("btn_Stop").disabled = true;
    $("btn_Stop").value = 'Stop';

    OAT.Dom.hide("feeds");
    var obj = $("feeds");
    if (obj) {
      OAT.Dom.hide(obj);
     obj.innerHTML = '';
    }
    obj = $("feedsData");
   if (obj)
     obj.innerHTML = '';

    createProgressBar();
    progressTimer = setTimeout("checkState()", 1000);

    document.forms['F1'].action = 'channels.vspx';
  }
  OAT.AJAX.POST('ajax.vsp', "a=load&sa=init"+urlParams("sid")+urlParams("realm")+urlParams("cb_item")+urlParams("$_"), x, {async: false});
}

function checkState()
{
  var x = function (data) {
      var progressIndex;
      try {
      var xml = OAT.Xml.createXmlDoc(data);
      progressIndex = OAT.Xml.textValue(xml.getElementsByTagName('index')[0]);
      } catch (e) { }

      showProgress(progressIndex);

    $("btn_Background").disabled = false;
    $("btn_Stop").disabled = false;
    if ((progressIndex != null) && (progressIndex != progressMax)) {
        setTimeout("checkState()", 1000);
			} else {
      progressTimer = null;
      $('btn_Stop').value = 'Close';
      OAT.Dom.hide('btn_Background');
			}
	  }
  OAT.AJAX.POST('ajax.vsp', "a=load&sa=state&id="+progressID+urlParams("sid")+urlParams("realm"), x);
}

function progressText(txt)
{
  progressMax = 0;
  var form = document.forms['F1'];
  for (var i = 0; i < form.elements.length; i++) {
    var obj = form.elements[i];
    if (obj && obj.type == "checkbox" && obj.checked && obj.name.indexOf ('cb_item') != -1)
      progressMax += 1;
  }
  $('progressText').innerHTML = txt;
  $('progressMax').innerHTML = progressMax;
}

// create the progress bar
function createProgressBar()
{
  progressMax = $('progressMax').innerHTML;
  var centerCellName;
  var tableText = "";
  var tdText = "";
  for (x = 0; x < progressSize; x++)
  {
    tdText = "";
    if (x == ((progressSize/2)-1))
    {
      centerCellName = "progress_" + x;
      tdText = "<font color=\"white\">" + 0 + '&nbsp;out&nbsp;of&nbsp;' + progressMax + "</font>"
    }
    else if (x == (progressSize/2))
    {
      tdText = "<font color=\"white\">" + "Subscriptions</font>";
    }
    else if (x == ((progressSize/2)+1))
    {
      tdText = "<font color=\"white\">" + "Completed</font>";
    }
    tableText += "<td id=\"progress_" + x + "\" width=\"" + progressInc + "%\" height=\"20\" bgcolor=\"blue\">"+tdText+"</td>";
  }
  var idiv = window.document.getElementById("progress");
  idiv.innerHTML = "<table with=\"200\" border=\"0\" cellspacing=\"0\" cellpadding=\"0\"><tr>" + tableText + "</tr></table>";
  centerCell = window.document.getElementById(centerCellName);
}

// show the current percentage
function showProgress(progressIndex)
{
  if (progressIndex == null)
    progressIndex = progressMax;

  var percentage = progressIndex * 100 / progressMax;
  centerCell.innerHTML = "<font color=\"white\">" + progressIndex + '&nbsp;out&nbsp;of&nbsp;' + progressMax + "</font>";
  for (x = 0; x < progressSize; x++) {
    var cell = window.document.getElementById("progress_" + x);
    if (cell) {
      if ((percentage == 0) || (percentage/x < progressInc)) {
      cell.style.backgroundColor = "blue";
    } else {
      cell.style.backgroundColor = "red";
    }
  }
}
}

function davBrowse(fld, folders) {
	/* load stylesheets */
	OAT.Style.include("grid.css");
	OAT.Style.include("webdav.css");

  var options = {
    mode: 'browser',
    onConfirmClick: function(path, fname){$(fld).value = '/DAV' + path + fname;}
  };
  if (!folders) {folders = false;}
  OAT.WebDav.options.foldersOnly = folders;
  OAT.WebDav.open(options);
}

function getParent (obj, tag)
{
  var obj = obj.parentNode;
  if (obj.tagName.toLowerCase() == tag)
    return obj;
  return getParent(obj, tag);
}

function coloriseRow(obj, checked)
{
  obj.className = (obj.className).replace('tr_select', '');
  if (checked)
    obj.className = obj.className + ' ' + 'tr_select';
}

function updateChecked (obj, objName)
{
  var objForm = obj.form;
  coloriseRow(getParent(obj, 'tr'), obj.checked);

  var s1Value = objForm.s1.value;
  s1Value = Feeds.trim(s1Value);
  s1Value = Feeds.trim(s1Value, ',');
  s1Value = Feeds.trim(s1Value);
  s1Value = s1Value + ',';
  for (var i = 0; i < objForm.elements.length; i = i + 1) {
    var obj = objForm.elements[i];
    if (obj != null && obj.type == "checkbox" && obj.name == objName) {
      if (obj.checked)
      {
        if (s1Value.indexOf(obj.value+',') == -1)
          s1Value = s1Value + obj.value+',';
      } else {
        s1Value = (s1Value).replace(obj.value+',', '');
      }
    }
  }
  objForm.s1.value = Feeds.trim(s1Value, ',');
}

function addChecked (form, txt, selectionMsq)
{
  var openerForm = eval('window.opener.document.F1');
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
