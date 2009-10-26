/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2009 OpenLink Software
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
var CNV = new Object();
CNV.page = new Object();

CNV.fromLabels = {
  "openid": "Openid",
  "facebook": "Facebook"
}

CNV.fromMenu = function (obj)
{
  if (!CNV.fm)
  {
    CNV.fm = OAT.Dom.create("div", {width: "120px", display: "none"});
    CNV.fm.className = "cnv-menu";
    if (CNV.fromLabels)
    for (var i in CNV.fromLabels)
    {
      var item = OAT.Dom.create("div");
      item.className = "cnv-menuItem";
      var label = OAT.Dom.create("label");
      var ch = OAT.Dom.create("input");
			ch.id = "cb_" + i;
			ch.type = "checkbox";
			var cbAction = function (){CNV.fromAction(this);};
			OAT.Dom.attach(ch, "click", cbAction);
			label.appendChild(ch);
			label.appendChild(OAT.Dom.text(CNV.fromLabels[i]));
			item.appendChild(label);
      CNV.fm.appendChild(item);
    }
    document.body.appendChild(CNV.fm);
  }
  if (CNV.fm.style.display == "none")
  {
		var coords = OAT.Dom.position(obj);
		var dims = OAT.Dom.getWH(obj);
		CNV.fm.style.left = (coords[0]) +"px";
		CNV.fm.style.top = (coords[1]+dims[1]+5)+"px";
    OAT.Dom.show(CNV.fm);
  } else {
    OAT.Dom.hide(CNV.fm);
  }
}

CNV.fromAction = function (obj)
{
  OAT.Dom.hide(CNV.fm);
  //if (!obj.checked)
  //  return;

  var mode = obj.id.replace('cb_', '');
  var formDiv = $('formDiv');
  if (formDiv) {OAT.Dom.unlink(formDiv);}

  var dx;
  if (!dx) {dx = '400';}
  var dy;
  if (!dy) {dy = '145';}
  formDiv = OAT.Dom.create('div', {width:dx+'px', height:dy+'px'});
  formDiv.id = 'formDiv';
  formDialog = new OAT.Dialog('', formDiv, {width:parseInt(dx)+20, buttons: 0, resize: 0, modal: 1, onhide: function(){return false;}});
  formDialog.cancel = formDialog.hide;
  var s = 'conversation-login.vsp?mode='+mode;
  formDiv.innerHTML = '<iframe id="forms_iframe" src="'+s+'" width="100%" height="100%" frameborder="0" scrolling="auto" hspace="0" vspace="0" marginwidth="0" marginheight="0"></iframe>';
  formDialog.show();
}

CNV.fromClose = function ()
{
  parent.formDialog.hide ();
}

CNV.writeCookie = function (name, value, hours)
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

CNV.readCookie = function (name)
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

CNV.initState = function (state)
{
  // init cookie data
  if (!state)
    var state = new Object();
  return state;
}

CNV.loadState = function ()
{
  // load cookie data
  var s = CNV.readCookie('CNV_State');
  if (s)
  {
    try {
      s = OAT.JSON.parse(unescape(s));
    } catch (e) { s = null; }
    s = CNV.initState(s);
  } else {
    s = CNV.initState();
  }
  CNV.state = s;
}

CNV.saveState = function ()
{
  CNV.writeCookie('CNV_State', escape(OAT.JSON.stringify(CNV.state)), 1);
}

CNV.initQE = function (items)
{
  CNV.loadState();
  if (items)
  {
    for (var i = 0; i < items.length; i++)
      if ($('qe_'+items[i]))
      {
        var tmp = CNV.state[items[i]];
        if (!tmp)
          tmp = CNV.page[items[i]];
        if (tmp)
          $('qe_'+items[i]).innerHTML = tmp;
        OAT.QuickEdit.assign('qe_'+items[i],OAT.QuickEdit.STRING,[])
      }
  }
  CNV.saveState();
}

CNV.saveQE = function (items)
{
  if (items)
  {
    for (var i = 0; i < items.length; i++)
      if ($(items[i]) && $('qe_'+items[i]))
      {
        CNV.state[items[i]] = $('qe_'+items[i]).innerHTML;
        $(items[i]).value = $('qe_'+items[i]).innerHTML;
      }
  }
  CNV.saveState();
}
