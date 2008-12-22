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

  state.sid = Feeds.readField('sid');
  state.realm = Feeds.readField('realm');
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
  if (s)
  {
    try {
      s = OAT.JSON.parse(unescape(s));
    } catch (e) { s = null; }
    s = Feeds.initState(s);
  } else {
    s = Feeds.initState();
  }
  Feeds.state = s;
  var v = $('nodePath');
  if (v && (v.value != ''))
  {
    Feeds.state.selected = v.value;
  }

  Feeds.initFeeds()
  Feeds.initTags()
}

Feeds.initTags = function ()
{
  var div = $('pane_left_tags');
  if (!div)
    return;

  if (Feeds.state.tab != 'tags')
  {
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

  if (Feeds.state.tab != 'feeds')
  {
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
    if (Feeds.state.expanded)
    {
      for (var i = 0; i < Feeds.state.expanded.length; i++)
      {
        v.push(Feeds.state.expanded[i]);
      }
    }
    if (Feeds.state.selected)
    {
      v.push(Feeds.state.selected);
    }
    Feeds.loadPath(v, 0);
  };
  Feeds.loadTree('', Feeds.tree.tree, x);
}

Feeds.loadPath = function (w, wIndex)
{
  var selectNode;

  for (var n = wIndex; n < w.length; n++)
  {
    var nodePath = w[n];
    var parts = nodePath.split("/");
    if (parts[0] == "") { parts.shift(); }
    if (parts[parts.length-1] == "") { parts.pop(); }

    var node = Feeds.tree.tree;
    var currentPath = '';

    for (var i = 0; i < parts.length; i++)
    {
      currentPath += '/' + parts[i];
      var index = -1;
      for (var j = 0; j < node.children.length; j++)
      {
        var child = node.children[j];
        if (child.myPath == currentPath)
        {
          if ((child.children.length == 0) && child.ul)
          {
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
      {
        selectNode = node;
      }
    }
    node.toggleSelect({ctrlKey:false});
  }
  Feeds.loadItems(Feeds.selectPath());
}

Feeds.selectPath = function ()
{
  if (Feeds.state.selected)
  {
    if (Feeds.state.selected.indexOf('t#') != 0)
    {
      var parts = Feeds.state.selected.split("/");
      if (parts[0] == "") { parts.shift(); }
      if (parts[parts.length-1] == "") { parts.pop(); }

      var node = Feeds.tree.tree;
      var currentPath = '';

      for (var i = 0; i < parts.length; i++)
      {
        currentPath += '/' + parts[i];
        for (var j = 0; j < node.children.length; j++)
        {
          var child = node.children[j];
          if (child.myPath == currentPath)
          {
            if (Feeds.state.selected == child.myPath)
            {
              child.select();
              return child.myID;
            }
            index = j;
            break;
          }
        }
        if (index == -1) {return;}
        node = node.children[index];
        if (!node) {break;}
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
    OAT.Dom.attach(node._gdElm, 'click', function() {Feeds.selectNode(path, node);});
  }
  var o = OAT.JSON.parse(data);
  for (var i = 0; i < o.length; i++)
  {
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
    {
      Feeds.gd.addSource(newNode._gdElm, Feeds.gdDummy, Feeds.gdSuccess(iID));
    }

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
  if (!a)
  {
    a = [nodePath];
  } else {
    var N = a.find(nodePath);
    if (N == -1)
    {
      a.push(nodePath);
    }
  }
  Feeds.state.expanded = a;
  Feeds.saveState();

  if (node.children.length != 0) { return; } /* nothing when already fetched */

  Feeds.loadTree(nodePath, node);
}

Feeds.collapseTree = function (nodePath, node)
{
  var expanded = Feeds.state.expanded;
  if (expanded)
  {
    var N = expanded.find(nodePath);
    if (N != -1)
    {
      var a = [];
      for (var i = 0; i < expanded.length; i++)
      {
        if (i != N)
        {
          a.push(expanded[i]);
        }
      }
      Feeds.state.expanded = a;
      Feeds.saveState();
    }
  }
}

Feeds.selectNode = function(nodePath, node)
{
  if (node.selectable)
  {
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
  if (v && (v.value != ''))
  {
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
  if (confirmAction('Are you sure you want to remove this item from Favourites?'))
  {
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

Feeds.updateClaim = function (claimNo)
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

Feeds.aboutDialog = function ()
{
  var aboutDiv = $('aboutDiv');
  if (aboutDiv) {OAT.Dom.unlink(aboutDiv);}
  aboutDiv = OAT.Dom.create('div', {width:'450px', height:'150px'});
  aboutDiv.id = 'aboutDiv';
  aboutDialog = new OAT.Dialog('About ODS FeedsManager', aboutDiv, {width:450, buttons: 0, resize:0, modal:1});
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
function getObject(id, doc)
{
  if (!doc) {doc = document;}
  return doc.getElementById(id);
}

// ---------------------------------------------------------------------------
function confirmAction(confirmMsq, form, txt, selectionMsq)
{
  if (anySelected (form, txt, selectionMsq))
    return confirm(confirmMsq);
  return false;
}

// ---------------------------------------------------------------------------
function selectAllCheckboxes (form, btn, txt)
{
  for (var i = 0; i < form.elements.length; i++)
  {
    var obj = form.elements[i];
    if (obj != null && obj.type == "checkbox" && !obj.disabled && obj.name.indexOf (txt) != -1)
    {
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
    var table = document.getElementById(id);
    if (table != null)
    {
      var rows = table.getElementsByTagName("tr");
      for (i = 0; i < rows.length; i++)
      {
        rows[i].className = "tr_" + (i % 2);;
      }
    }
  }
}

// ---------------------------------------------------------------------------
function clickNode(obj)
{
  var nodes = obj.parentNode.childNodes;
  for (var i=0; i<nodes.length; i++)
  {
    var node = nodes[i];
    if ((node.tagName == 'A') && (node.innerHTML))
    {
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
  for (var i=0; i<nodes.length; i++)
  {
    var node = nodes[i];
    if ((node.tagName == 'A') && (node.onclick))
        return node.onclick();
  }
}

// ---------------------------------------------------------------------------
function loadIFrame(id, mode)
{
  var doc = document.ownerDocument;
  if (!getObject('pane_right_bottom', doc)) {var doc = parent.document;}
  if (!mode) {mode = 'c';}
  if (mode != 'p')
{
    readObject('feed_'+id, 'r1', doc);
  }
  var URL = 'item.vspx?&fid='+id+'&f=r1&m='+mode+Feeds.sessionParams(doc);
  getObject('pane_right_bottom', doc).innerHTML = '<iframe id="feed_item" src="'+URL+'" style="margin: -2px 0px 0px 0px;" width="100%" height="100%" frameborder="0" scrolling="auto" hspace="0" vspace="0" marginwidth="0" marginheight="0"></iframe>';
}

// ---------------------------------------------------------------------------
function loadIFrameURL(URL)
{
  var doc = parent.document;
  getObject('pane_right_bottom', doc).innerHTML = '<iframe src="http://feedvalidator.org/check.cgi?url='+encodeURIComponent(URL)+'" style="margin: -2px 0px 0px 0px;" width="100%" height="100%" frameborder="0" scrolling="auto" hspace="0" vspace="0" marginwidth="0" marginheight="0"></iframe>';
}

// ---------------------------------------------------------------------------
function loadFromIFrame(id, flag, mode)
{
  var doc = parent.document;
  if (!flag) {flag = 'r1';}
  if (!mode) {mode = 'c';}

  readObject('feed_'+id, flag, doc);
  flagObject('image_'+id, flag, doc);

  var URL = 'item.vspx?fid='+id+'&f='+flag+'&m='+mode+Feeds.sessionParams(doc);
  getObject('pane_right_bottom', doc).innerHTML = '<iframe src="'+URL+'" style="margin: -2px 0px 0px 0px;" width="100%" height="100%" frameborder="no" scrolling="auto" hspace="0" vspace="0" marginwidth="0" marginheight="0"></iframe>';
}

// ---------------------------------------------------------------------------
function readObject(id, flag, doc)
{
  var c = $(id);
  if (c)
{
    if (flag == 'r0')
{
      OAT.Dom.removeClass(id, 'read');
      OAT.Dom.addClass(id, 'unread');
}
    else if (flag == 'r1')
    {
      OAT.Dom.removeClass(id, 'unread');
      OAT.Dom.addClass(id, 'read');
    }
  }
}

// ---------------------------------------------------------------------------
function flagObject(id, flag, doc)
{
  var c = $(id);
  if (c)
  {
    if (flag == 'f0')
    {
        c.innerHTML = '';
}
    else if (flag == 'f1')
    {
      c.innerHTML = '<img src="image/flag.gif" border="0"/>';
    }
  }
}

// ---------------------------------------------------------------------------
function addOption (form, text_name, box_name)
{
  var box = form.elements[box_name];
  if (box)
  {
    var text = form.elements[text_name];
    if (text)
    {
      text.value = Feeds.trim(text.value);
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
function deleteOption (form, box_name)
{
  var box = form.elements[box_name];
  if (box)
	  box.options[box.selectedIndex] = null;
}

// ---------------------------------------------------------------------------
function composeOptions (form, box_name, text_name)
{
  var box = form.elements[box_name];
  if (box)
  {
    var text = form.elements[text_name];
    if (text)
    {
		  text.value = '';
    	for (var i=0; i<box.options.length; i++)
    	  if (text.value == '')
		      text.value = box.options[i].value;
		    else
          text.value += '\n' + box.options[i].value;
	  }
	}
}

// ---------------------------------------------------------------------------
function showTag(tag)
{
  parent.Feeds.selectTag(tag);
}

// ---------------------------------------------------------------------------
// sortSelect(select_object)
//   Pass this function a SELECT object and the options will be sorted
//   by their text (display) values
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
        {
          $('tabNo').value = tabNo;
        }
        if (c)
        {
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

// ---------------------------------------------------------------------------
// Hidden functions
// ---------------------------------------------------------------------------
function createHidden(frm_name, fld_name, fld_value)
{
  createHidden2(document, frm_name, fld_name, fld_value);
}

// ---------------------------------------------------------------------------
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
// Menu functions
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
function urlParams(mask)
{
  var S = '';
  var form = document.forms['F1'];

  for (var i = 0; i < form.elements.length; i++)
  {
    var obj = form.elements[i];
    if ((obj.name.indexOf (mask) != -1) && (((obj.type == "checkbox") && (obj.checked)) || (obj.type != "checkbox")))
      S += '&' + form.elements[i].name + '=' + encodeURIComponent(form.elements[i].value);
  }
  return S;
}

// ---------------------------------------------------------------------------
function showObject(id)
{
  var obj = document.getElementById(id);
  if (obj)
  {
    obj.style.display="";
    obj.visible = true;
  }
}

// ---------------------------------------------------------------------------
function hideObject(id)
{
  var obj = document.getElementById(id);
  if (obj != null)
  {
    obj.style.display="none";
    obj.visible = false;
  }
}

// ---------------------------------------------------------------------------
function initRequest()
{
	var xmlhttp = null;
  try {
    xmlhttp = new ActiveXObject("Msxml2.XMLHTTP");
  } catch (e) { }

  if (xmlhttp == null)
  {
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
function checkState()
{
	var xmlhttp = initRequest();
	xmlhttp.open("POST", URL+"?mode=state&id="+progressID+urlParams("sid")+urlParams("realm"), true);
	xmlhttp.onreadystatechange = function() {
    if (xmlhttp.readyState == 4)
    {
      var progressIndex;

      // progressIndex
      try {
        progressIndex = xmlhttp.responseXML.getElementsByTagName("index")[0].firstChild.nodeValue;
      } catch (e) { }

      if (timer != null)
      showProgress(progressIndex);
     	document.getElementById("btn_Background").disabled = false;
     	document.getElementById("btn_Stop").disabled = false;
      if ((progressIndex != null) && (progressIndex != progressMax))
      {
        setTimeout("checkState()", 1000);
			} else {
        doPost ('F1', 'btn_Stop');
			  timer = null;
			}
	  }
	}
	xmlhttp.setRequestHeader("Pragma", "no-cache");
	xmlhttp.send("");
}

// ---------------------------------------------------------------------------
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
// create the progress bar
// ---------------------------------------------------------------------------
function createProgressBar()
{
  progressMax = getObject('progressMax').innerHTML;

  var centerCellName;
  var tableText = "";
  var tdText = "";
  for (x = 0; x < size; x++)
  {
    tdText = "";
    if (x == ((size/2)-1))
    {
      centerCellName = "progress_" + x;
      tdText = "<font color=\"white\">" + 0 + '&nbsp;out&nbsp;of&nbsp;' + progressMax + "</font>"
    }
    else if (x == (size/2))
    {
      tdText = "<font color=\"white\">" + "Subscriptions</font>";
    }
    else if (x == ((size/2)+1))
    {
      tdText = "<font color=\"white\">" + "Completed</font>";
    }
    tableText += "<td id=\"progress_" + x + "\" width=\"" + increment + "%\" height=\"20\" bgcolor=\"blue\">"+tdText+"</td>";
  }
  var idiv = window.document.getElementById("progress");
  idiv.innerHTML = "<table with=\"200\" border=\"0\" cellspacing=\"0\" cellpadding=\"0\"><tr>" + tableText + "</tr></table>";
  centerCell = window.document.getElementById(centerCellName);
}

// ---------------------------------------------------------------------------
// show the current percentage
// ---------------------------------------------------------------------------
function showProgress(progressIndex)
{
  if (progressIndex == null)
    progressIndex = progressMax;

  var percentage = progressIndex * 100 / progressMax;
  centerCell.innerHTML = "<font color=\"white\">" + progressIndex + '&nbsp;out&nbsp;of&nbsp;' + progressMax + "</font>";
  for (x = 0; x < size; x++)
  {
    var cell = window.document.getElementById("progress_" + x);
    if (cell)
    {
      if ((percentage == 0) || (percentage/x < increment))
    {
      cell.style.backgroundColor = "blue";
    } else {
      cell.style.backgroundColor = "red";
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

