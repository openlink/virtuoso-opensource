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

function toggleControl (ctr1, val, ctr2)
{
  if (ctr2 == null)
    return;

  if (ctr1 && ctr1.value == val)
    {
      ctr2.disabled = true;
    }
  else
    {
      ctr2.disabled = false;
    }
}

function setSelectLists (val, form, pref)
{
  var i;
  if (val == 0 || form == null || pref == null)
    return;
  for (i = 0; i < form.elements.length; i++)
    {
      var contr = form.elements[i];
      if (contr != null && contr.type == 'select-one' && contr.name.indexOf (pref) != -1)
        {
          contr.value = val;
        }
    }
}

function dateFormat(date, format)
{
  function long(d) {
    return ( ( d < 9 )? "0" : "" ) + d;
  }
	var result="";
	var chr;
	var token;
	var i=0;
	while (i < format.length)
	{
		chr = format.charAt(i);
		token = "";
		while ((format.charAt(i) == chr) && (i < format.length))
		{
			token += format.charAt(i++);
		}
		if (token == "y")
		  result += ""+date[0];
		else if (token == "yy")
		  result += date[0].substring(2,4);
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

function dateParse(dateString, format)
{
  var result = null;
  var pattern = new RegExp('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])$');
  if (dateString.match(pattern))
  {
    dateString = dateString.replace(/\//g, '-');
    result = dateString.split('-');
    result = [parseInt(result[0]), parseInt(result[1]), parseInt(result[2])];
  }
  return result;
}

function datePopup(objName, format) {
  if (!format) {format = 'yyyy-MM-dd';}
	var obj = $(objName);
	var d = dateParse(obj.value, format);
  var c = new OAT.Calendar({popup: true});
	var coords = OAT.Dom.position(obj);
	if (isNaN(coords[0])) {coords = [0, 0];}
	var x = function(date) {
	  obj.value = dateFormat(date, format);
	}
	c.show(coords[0], coords[1] + 30, x, d);
}

function submitenter(fld, btn, e)
{
  var keycode;

  if (fld == null || fld.form == null)
    return true;

  if (window.event)
    keycode = window.event.keyCode;
  else if (e)
    keycode = e.which;
  else
    return true;

  if (keycode == 13)
    {
      doPost (fld.form.name, btn);
      return false;
    }
  else
    return true;
}

var sflag = false;
var def_btn = null;
function checkPageLeave (form)
{
  var dirty = false;
  var ret = true;
  var btn = def_btn;
  if (sflag == true || btn == null || btn == '' || form.__submit_func.value != '' || form.__event_initiator.value != '')
    return true;
  for (var i = 0; i < form.elements.length; i++)
    {
      if (form.elements[i] != null)
        {
          var ctrl = form.elements[i];

          if(typeof(ctrl.type)!='undefined')
          {
            if (ctrl.type.indexOf ('select') != -1)
            {
          var selections = 0;
          for (var j = 0; j < ctrl.length; j ++)
    	            {
                     var opt = ctrl.options[j];
    	               if (opt.defaultSelected == true)
    		                   selections ++;
                     if (opt.defaultSelected != opt.selected)
                              dirty = true;
                            }
    	          if (selections == 0 && ctrl.selectedIndex == 0)
    	            dirty = false;
    	          if (dirty == true)
    	            break;
    	          }
            else if ((ctrl.type.indexOf ('text') != -1 || ctrl.type == 'password') && ctrl.defaultValue != ctrl.value)
              {
                dirty = true;
       	        break;
              }
        else if ((ctrl.type == 'checkbox' || ctrl.type == 'radio') && ctrl.defaultChecked != ctrl.checked)
              {
                dirty = true;
                break;
              }
          }
        }
    }

  dirty_force_global = $('dirty_force_global');
  if (!dirty_force_global)
  {
    if (dirty_force_global.value == 'true')
      dirty_force_global = true;
  }else{
     dirty_force_global = false;
  }

  if (dirty_force_global == true )
  {
    dirty_force_global = false ;
    dirty = true;
  }
  if (dirty == true)
    {
    ret = confirm ('You are about to leave the page, but there is changed data which is not saved.\r\nDo you wish to save changes ?');
        if (ret == true)
          {
            form.__submit_func.value = '__submit__';
            form.__submit_func.name = btn;
            form.submit ();
          }
    }
   return ret;
}

function getFileName(form, from, to)
{
  var S = from.value;
  var N;
  var fname;
  if (S.lastIndexOf('\\') > 0)
    N = S.lastIndexOf('\\')+1;
  else
    N = S.lastIndexOf('/')+1;
  fname = S.substr(N,S.length);
  to.value = fname;
}

function checkSelected (form, txt, selectionMsq)
{
  if ((form != null) && (txt != null))
  {
    for (var i = 0; i < form.elements.length; i++)
    {
      var obj = form.elements[i];
      if (obj != null && obj.type == 'checkbox' && obj.name.indexOf (txt) != -1 && obj.checked)
        return true;
    }
    if (selectionMsq != null)
      alert(selectionMsq);
    return false;
  }
  return true;
}


function submenuShowHide ()
{
  submenu_div=document.getElementById('submenu_block');
  if (submenu_div.style.display=='none')
    {
      submenu_div.style.display='block'
	  document.getElementById('myods_cell').className='sel';
    }
  else
    {
      submenu_div.style.display='none';
      document.getElementById('myods_cell').className=' ';
    }
}

function divShowHide ( divname, div_action)
{
  alert(divname);
  _div=document.getElementById(divname);
  if (div_action=='show')
    {
      _div.style.display='block'
    }
  else
    {
      _div.style.display='none';
    }
}

function divs_switch ( showhide, divname_a, divname_b)
{
  _div_a=document.getElementById(divname_a);
  _div_b=document.getElementById(divname_b);


  if(showhide){
     _div_a.style.display='block'
     _div_b.style.display='none';
  }else
  {
     _div_a.style.display='none'
     _div_b.style.display='block';
  }
}

function windowShow(sPage, width, height)
{
  if (width == null)
    width = 500;
  if (height == null)
    height = 420;
  sPage = sPage + '&sid=' + document.forms[0].elements['sid'].value + '&realm=' + document.forms[0].elements['realm'].value;
  win = window.open(sPage, null, "width="+width+",height="+height+",top=100,left=100,status=yes,toolbar=no,menubar=no,scrollbars=yes,resizable=yes");
  win.window.focus();
}


function callSparql (graph, qry_id, res_id, rdf_gem)
{
  var qry_in = document.getElementById (qry_id);
  var div = document.getElementById (res_id);
  var gem = document.getElementById (rdf_gem);
  var qry = qry_in.value;
  var endpoint = '/sparql/?';
  var format = 'text/html';
  var callback = function(data,xmlhttp)
     {
       div.innerHTML = data;
       gem.innerHTML = '<a href="' + endpoint + 'query='+ encodeURIComponent (qry) + '&format=' +
	  encodeURIComponent('application/sparql-results+xml') +
          '&default-graph-uri='+encodeURIComponent (graph) +
          '"><img src="images/orange-icon-16.gif" border="0" hspace="3"> XML</a>';
     }
  var body = function()
     {
       var body = 'query='+encodeURIComponent (qry)+'&format='+ encodeURIComponent('text/html') +
          '&default-graph-uri='+encodeURIComponent (graph);
       return body;
     }
  OAT.Ajax.errorRef = function(status,response,xmlhttp)
  {
    div.innerHTML = '<div class="error_msg"><pre>' + response + '</pre></div>';
  }
  OAT.Ajax.command(OAT.Ajax.POST, endpoint, body, callback, OAT.Ajax.TYPE_TEXT,{'Accept':format});
}

function hasError(root) {
	if (!root)
	{
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

function createState(stateName, stateValue)
{
  var span = $('span_'+stateName);
  if (!span) {return false;}

  span.innerHTML = "";
  var s = stateName.replace(/state/, '');
  var f = function (){updateGeodata(s);};
  var fld = new OAT.Combolist([], stateValue, {onchange: f});
  fld.input.name = stateName;
  fld.input.id = stateName;
  fld.input.style.width = "200px";
  fld.addOption("");

  span.appendChild(fld.div);
  OAT.Event.attach(fld.input, "change", f);

  return fld;
}

function updateState(countryName, stateName, stateValue)
{
  var fld = createState(stateName, stateValue);
  if (!fld) {return false;}

  if ($v(countryName) != '')
	{
    var S = '/ods/api/lookup.list?key=Province&param='+encodeURIComponent($v(countryName));
  	var x = function(data) {
      var xml = OAT.Xml.createXmlDoc(data);
    	var items = xml.getElementsByTagName("item");
  	if (items.length)
  	{
  		for (var i=1; i<=items.length; i++)
  		{
        fld.addOption(OAT.Xml.textValue(items[i-1]));
  		}
  	}
    	updateGeodata(fld.input.id.replace(/state/, ''));
  	}
    OAT.AJAX.GET(S, '', x);
	}
}

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

function sharedChange(obj)
{
  if (obj.value == '2')
    OAT.Dom.show('tr_shared');
  else
    OAT.Dom.hide('tr_shared');
}

function updateGeodata(mode)
{
  var f = function (mode, fld)
  {
    var x = $(mode+fld);
    if (x)
      return '&' + fld + '=' + encodeURIComponent(x.value);
    return '';
  }
  var S = '/ods/api/address.geoData?'+f(mode,'address1')+f(mode,'address2')+f(mode,'city')+f(mode,'code')+f(mode,'state')+f(mode,'country');
  var cb = function(data, mode)
  {
    var o = null;
    try {
      o = OAT.JSON.parse(data);
    } catch (e) {
      o = null;
    }
    if (o)
    {
      if (o.lat)
      {
        var x = $(mode+'lat');
        if (x)
          x.value = o.lat;
      }
      if (o.lng)
      {
        var x = $(mode+'lng');
        if (x)
          x.value = o.lng;
      }
    }
  }
  OAT.AJAX.GET(S, '', function(arg){cb(arg, mode);}, {});
}

function initLoadProfile()
{
  if (top.location == self.location)
    return true;
  parent.nav.showUserProfile();
  return false;
}

function updateRow (prefix, No, optionObject)
{
  if (No != null)
  {
    OAT.Dom.unlink(prefix+'_tr_'+No);
    OAT.Dom.unlink(prefix+'_tr_'+No+'_items');
    OAT.Dom.unlink(prefix+'_tr_'+No+'_properties');
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
    var tbl = $(prefix+'_tbl');
    if (tbl)
    {
      options = {btn_1: {mode: 1}};
      for (var p in optionObject) {options[p] = optionObject[p]; }

      No = optionObject.No;
      if (!No) {No = $v(prefix+'_no');}
      No = parseInt(No)

      OAT.Dom.hide (prefix+'_tr_no');

      var tr = OAT.Dom.create('tr');
      tr.id = prefix+'_tr_' + No;
      tbl.appendChild(tr);

      // fields
      for (var fld in options)
      {
        if (fld.indexOf('fld') == 0)
      {
          var fldOptions = options[fld];
        var td = OAT.Dom.create('td');
          td.id = prefix+'_td_'+ No+'_'+fld.replace(/fld_/, '');
        tr.appendChild(td);
          updateCell (td, prefix, fld, No, fldOptions)
      }
      }

      // actions
      var td = OAT.Dom.create('td');
      td.id = prefix+'_td_'+ No+'_btn';
      td.style.whiteSpace = 'nowrap';
      tr.appendChild(td);
      for (var btn in options)
      {
        if (btn.indexOf('btn') == 0)
        {
          var btnOptions = options[btn];
          updateButton(td, prefix, btn, No, btnOptions)
        }
      }
      $(prefix+'_no').value = No + 1;
    }
  }
}

function updateCell (td, prefix, fldName, No, optionObject)
{
  fldName = prefix + '_' + fldName + '_' + No;
  if (optionObject.tdCssText)
    td.style.cssText = optionObject.tdCssText;
  fn = window["updateField"+optionObject.mode];
  if (fn)
  {
	  fn(td, fldName, prefix, No, optionObject);
  }
  else
  {
	  updateInput(td, fldName, optionObject);
  }
}

function updateInput (elm, fldName, fldOptions)
{
  var fld = OAT.Dom.create('input');
  fld.type = (fldOptions.type)? (fldOptions.type): 'text';
  fld.id = fldName;
  fld.name = fld.id;
  if (fldOptions.value)
  {
    fld.value = fldOptions.value;
    fld.defaultValue = fld.value;
  }
  if (fldOptions.className)
  fld.className = fldOptions.className;
  if (fldOptions.onblur)
  fld.onblur = fldOptions.onblur;
  fld.style.width = '95%';
  if (fldOptions.cssText)
    fld.style.cssText = fldOptions.cssText;
  var elm = $(elm);
  elm.appendChild(fld);
}

var serviceList = [
  ["twelveseconds.jpg", "http://12seconds.tv/", "12seconds"],
  ["amazon.jpg", "http://www.amazon.com/", "Amazon.com"],
  ["ameba.jpg", "http://www.ameba.jp/", "Ameba"],
  ["backtype.jpg", "http://www.backtype.com/", "Backtype"],
  ["blog.jpg", "http://en.wikipedia.org/wiki/Blog/", "Blog"],
  ["brightkite.jpg", "http://brightkite.com/", "brightkite.com"],
  ["feed.jpg", "http://en.wikipedia.org/wiki/Web_feed/", "Custom RSS/Atom"],
  ["dailymotion.jpg", "http://www.dailymotion.com/", "Dailymotion"],
  ["delicious.jpg", "http://del.icio.us/", "Del.icio.us"],
  ["digg.jpg", "http://www.digg.com/", "Digg"],
  ["diigo.jpg", "http://www.diigo.com/", "Diigo"],
  ["disqus.jpg", "http://www.disqus.com/", "Disqus"],
  ["facebook.jpg", "http://www.facebook.com/", "Facebook"],
  ["flickr.jpg", "http://www.flickr.com/", "Flickr"],
  ["fotolog.jpg", "http://www.fotolog.com/", "Fotolog"],
  ["friendfeed.jpg", "http://www.friendfeed.com/", "FriendFeed"],
  ["furl.jpg", "http://www.furl.net/", "Furl"],
  ["googletalk.jpg", "http://talk.google.com/", "Gmail/Google Talk"],
  ["goodreads.jpg", "http://www.goodreads.com/", "Goodreads"],
  ["googlereader.jpg", "http://reader.google.com/", "Google Reader"],
  ["googleshared.jpg", "http://www.google.com/s2/sharing/stuff/", "Google Shared Stuff"],
  ["identica.jpg", "http://identi.ca/", "identi.ca"],
  ["ilike.jpg", "http://www.ilike.com/", "iLike"],
  ["intensedebate.jpg", "http://www.intensedebate.com/", "Intense Debate"],
  ["jaiku.jpg", "http://www.jaiku.com/", "Jaiku"],
  ["joost.jpg", "http://www.joost.com/", "Joost"],
  ["lastfm.jpg", "http://www.last.fm/user/", "Last.fm"],
  ["librarything.jpg", "http://www.librarything.com/", "LibraryThing"],
  ["linkedin.jpg", "http://www.linkedin.com/", "LinkedIn"],
  ["livejournal.jpg", "http://www.livejournal.com/", "LiveJournal"],
  ["magnolia.jpg", "http://ma.gnolia.com/", "Ma.gnolia"],
  ["meneame.jpg", "http://meneame.net/", "meneame"],
  ["misterwong.jpg", "http://www.mister-wong.com/", "Mister Wong"],
  ["mixx.jpg", "http://www.mixx.com/", "Mixx"],
  ["myspace.jpg", "http://www.myspace.com/", "MySpace"],
  ["netflix.jpg", "http://www.netflix.com/", "Netflix"],
  ["netvibes.jpg", "http://www.netvibes.com/", "Netvibes"],
  ["pandora.jpg", "http://www.pandora.com/", "Pandora"],
  ["photobucket.jpg", "http://www.photobucket.com/", "Photobucket"],
  ["picasa.jpg", "http://picasaweb.google.com/", "Picasa Web Albums"],
  ["plurk.jpg", "http://www.plurk.com/", "Plurk"],
  ["polyvore.jpg", "http://www.polyvore.com/", "Polyvore"],
  ["pownce.jpg", "http://pownce.com/", "Pownce"],
  ["reddit.jpg", "http://reddit.com/", "Reddit"],
  ["seesmic.jpg", "http://www.seesmic.com/", "Seesmic"],
  ["skyrock.jpg", "http://www.skyrock.com/", "Skyrock"],
  ["slideshare.jpg", "http://www.slideshare.net/", "SlideShare"],
  ["smotri.jpg", "http://smotri.com/", "Smotri.com"],
  ["smugmug.jpg", "http://www.smugmug.com/", "SmugMug"],
  ["stumbleupon.jpg", "http://www.stumbleupon.com/", "StumbleUpon"],
  ["tipjoy.jpg", "http://tipjoy.com/", "tipjoy"],
  ["tumblr.jpg", "http://www.tumblr.com/", "Tumblr"],
  ["twine.jpg", "http://www.twine.com/", "Twine"],
  ["twitter.jpg", "http://twitter.com/", "Twitter"],
  ["upcoming.jpg", "http://upcoming.yahoo.com/", "Upcoming"],
  ["vimeo.jpg", "http://www.vimeo.com/", "Vimeo"],
  ["wakoopa.jpg", "http://wakoopa.com/", "Wakoopa"],
  ["yahoo.jpg", "http://www.yahoo.com/", "Yahoo"],
  ["yelp.jpg", "http://www.yelp.com/", "Yelp"],
  ["youtube.jpg", "http://www.youtube.com/", "YouTube"],
  ["zooomr.jpg", "http://www.zooomr.com/", "Zooomr"]
]

var setServiceUrl = function(fld)
  {
    for (N = 0; N < serviceList.length; N = N + 1)
    {
      if (fld.value == serviceList[N][2])
      {
        var urlName = fld.input.name.replace(/fld_1_/, 'fld_2_');
        $(urlName).value = serviceList[N][1]+$v('c_nick');
      }
    }
	}

var setServiceUrl2 = function(fld)
  {
    for (N = 0; N < serviceList.length; N = N + 1)
    {
      if (fld.value == serviceList[N][2])
      {
        var urlName = fld.name.replace(/fld_1_/, 'fld_2_');
        $(urlName).value = serviceList[N][1]+$v('c_nick');
      }
    }
	}

function updateComboOption1 (fld, optionImage, optionName)
{
  fld.addOption('<img src="/ods/images/services/'+optionImage+'"/> '+optionName, optionName);
}

function updateComboOption2(fld, elmValue, optionName, optionValue)
{
  for (var i = 0; i < fld.options.length-1; i++)
  {
    if ((fld.options[i].value == optionValue) && (fld.options[i].text == optionName))
      return;
  }
	var o = OAT.Dom.option(optionName, optionValue, fld);
	if (elmValue == optionValue)
	{
	  o.selected = true;
	  o.defaultSelected = true;
	}
}

function updateComboOption30 (fld, fldValue, ontologyClassName)
{
  var ontologyClass = RDF.getOntologyClass(ontologyClassName);
  if (ontologyClass && ontologyClass.properties)
  {
    var P = ontologyClass.properties;
    for (i = 0; i < P.length; i++)
      updateComboOption2(fld, fldValue, P[i].name, P[i].name);
    updateComboOption30 (fld, fldValue, ontologyClass.subClassOf);
  }
}

function updateComboOption10 (fld, fldValue, ontologyClassName)
{
  var ontologyClass = GR.getOntologyClass(ontologyClassName);
  if (ontologyClass && ontologyClass.properties)
  {
    var P = ontologyClass.properties;
    for (i = 0; i < P.length; i++)
      updateComboOption2(fld, fldValue, P[i].name, P[i].name);
    updateComboOption10 (fld, fldValue, ontologyClass.subClassOf);
  }
}

function sortSelect(obj)
{
	if (!obj || !obj.options) { return; }

	var o = new Array();
	for (var i=0; i<obj.options.length; i++) {
		o[o.length] = new Option( obj.options[i].text, obj.options[i].value, obj.options[i].defaultSelected, obj.options[i].selected) ;
	}
	if (o.length==0) { return; }
	o = o.sort(
		function(a,b) {
			if ((a.text+"") < (b.text+"")) { return -1; }
			if ((a.text+"") > (b.text+"")) { return 1; }
			return 0;
			}
		);

	for (var i=0; i<o.length; i++) {
		obj.options[i] = new Option(o[i].text, o[i].value, o[i].defaultSelected, o[i].selected);
	}
}

function updateField1 (elm, fldName, prefix, No, fldOptions)
{
  var elm = $(elm);

  var fld = new OAT.Combolist([], fldOptions.value, {name: fldName, onchange: setServiceUrl});
  fld.input.name = fldName;
  fld.input.id = fldName;
  fld.input.setAttribute("autocomplete", "off");
  fld.input.style.width = "90%";
  for (N = 0; N < serviceList.length; N = N + 1)
    updateComboOption1(fld, serviceList[N][0], serviceList[N][2]);
  elm.appendChild(fld.div);

	var ta = new TypeAhead(fld.input.id, 'onlineAccounts', '');
	fld.input.onchange = setServiceUrl2;
	fld.input.form.onsubmit = CheckSubmit;
	taVars[taVars.length] = ta;
}

function updateField2 (elm, fldName, prefix, No, fldOptions)
{
	var fld = OAT.Dom.create('select');
  fld.name = fldName;
  fld.id = fldName;
	updateComboOption2(fld, fldOptions.value, "Person URI", "URI");
  updateComboOption2(fld, fldOptions.value, "Relationship Property", "Property");
	// updateComboOption2(fld, fldOptions.value, "SPARQL", "SPARQL  Expression");

  var elm = $(elm);
  elm.appendChild(fld);
}

function updateField3 (elm, fldName, prefix, No, fldOptions)
{
	var fld = OAT.Dom.create("select");
  fld.name = fldName;
  fld.id = fldName;
	updateComboOption2(fld, fldOptions.value, "Grant", "G");
	updateComboOption2(fld, fldOptions.value, "Revoke", "R");

  var elm = $(elm);
  elm.appendChild(fld);
}

function updateField4 (elm, fldName, prefix, No, fldOptions)
{
	var fld = OAT.Dom.create("select");
  fld.name = fldName;
  fld.id = fldName;
  updateComboOption2(fld, fldOptions.value, 'bio:Birth', 'bio:Birth');
  updateComboOption2(fld, fldOptions.value, 'bio:Death', 'bio:Death');
  updateComboOption2(fld, fldOptions.value, 'bio:Marriage', 'bio:Marriage');

  var elm = $(elm);
  elm.appendChild(fld);
}

function updateField5 (elm, fldName, prefix, No, fldOptions)
{
	var fld = OAT.Dom.text(fldOptions.labelValue);
  elm.appendChild(fld);

	var fld = OAT.Dom.create("select");
  fld.name = fldName;
  fld.id = fldName;
  fld.style.width = "80%";
  updateComboOption2(fld, fldOptions.value, '', '');
  for (var prefix in RDF.ontologies)
    updateComboOption2(fld, fldOptions.value, RDF.ontologies[prefix].name+' ('+prefix+')', RDF.ontologies[prefix].name);

  var elm = $(elm);
  elm.appendChild(fld);
}

function updateField6 (elm, fldName, prefix, No, fldOptions)
{
  var fld = OAT.Dom.image("images/icons/orderdown_16.png");
  fld.id = fldName;
  fld.mode = 'show';
  fld.title = 'Show Properties';
  fld.onclick = function (){GR.showProperties(this, prefix, No);};
  if (fldOptions.cssText)
    fld.style.cssText = fldOptions.cssText;

  var elm = $(elm);
  elm.appendChild(fld);
}

function updateField7 (elm, fldName, prefix, No, fldOptions)
{
  var elm = $(elm);

	var fld = OAT.Dom.create("input");
  fld.type = 'hidden';
  fld.name = fldName;
  fld.id = fldName;
  fld.value = '0';
  elm.appendChild(fld);

	var fld = OAT.Dom.text(fldOptions.value);
  elm.appendChild(fld);
}

function updateField8 (elm, fldName, prefix, No, fldOptions)
{
	var fld = OAT.Dom.create("select");
  fld.name = fldName;
  fld.id = fldName;
  var ontology = GR.ontologies['gr'];
  if (ontology && ontology.classes)
  {
    for (i = 0; i < ontology.classes.length; i++)
      updateComboOption2(fld, fldOptions.value, ontology.classes[i].name, ontology.classes[i].name);
  }

  var elm = $(elm);
  elm.appendChild(fld);
}

function updateField9 (elm, fldName, prefix, No, fldOptions)
{
  var elm = $(elm);

	var fld = OAT.Dom.create("input");
  fld.type = 'hidden';
  fld.name = fldName;
  fld.id = fldName;
  fld.value = fldOptions.value;
  fld.defaultValue = fldOptions.value;
  elm.appendChild(fld);

  if (!fldOptions.showValue)
    fldOptions.showValue = fldOptions.value;
	var fld = OAT.Dom.text(fldOptions.showValue);
  var elm = $(elm);
  elm.appendChild(fld);
}

function updateField10 (elm, fldName, prefix, No, fldOptions)
{
	var fld = OAT.Dom.create("select");
  fld.name = fldName;
  fld.id = fldName;
  fld.style.width = '95%';
  fld.product = fldOptions.product;
  var fldValue;
    if (fldOptions.value)
    fldValue = fldOptions.value.name;
  updateComboOption2(fld, fldValue, '', '');
  updateComboOption10 (fld, fldValue, fld.product.objectClass);
  fld.onchange = function (){GR.changePropertyValue(fld);};
  sortSelect (fld);

  var elm = $(elm);
  elm.appendChild(fld);
}

function updateField11(elm, fldName, prefix, No, fldOptions)
{
  if (!elm) {return;}
  // clear
  elm.innerHTML = '';

  // get product
  var product = fldOptions.product;
  if (!product) {return;}

  // get property
  var property = fldOptions.value;
  if (!property) {return;}

  // get property data
  var ontologyClassProperty = GR.getOntologyClassProperty(product.objectClass, property.name);
  var propertyType;
  if (ontologyClassProperty.objectProperties)
  {
  	var fld = OAT.Dom.create('select');
    fld.id = fldName;
    fld.name = fld.id;
    fld.style.width = '95%';
    updateComboOption2(fld, property.value, '', '');
    for (var i = 0; i < GR.products.length; i++)
    {
      for (var j = 0; j < ontologyClassProperty.objectProperties.length; j++)
      {
        if (GR.isKindOfClass(GR.products[i].objectClass,ontologyClassProperty.objectProperties[j]))
	        updateComboOption2(fld, property.value, 'Element #'+GR.products[i].id, GR.products[i].id);
	    }
    }
    var grObjects = GR.objects[product.prefix];
    if (grObjects)
    {
      for (var i = 0; i < grObjects.length; i++)
      {
        for (var j = 0; j < ontologyClassProperty.objectProperties.length; j++)
        {
          if (GR.isKindOfClass(grObjects[i].objectClass, ontologyClassProperty.objectProperties[j]))
  	        updateComboOption2(fld, property.value, grObjects[i].id, grObjects[i].id);
  	    }
      }
    }
    elm.appendChild(fld);
    propertyType = 'object';
  }
  if (ontologyClassProperty.datatypeProperties)
  {
    var fld = OAT.Dom.create('input');
    fld.type = 'text';
    fld.id = fldName;
    fld.name = fld.id;
    if (property.value)
      fld.value = property.value;
    fld.style.width = '95%';
    elm.appendChild(fld);
    propertyType = 'data';
  }
  var fld = OAT.Dom.create('input');
  fld.type = 'hidden';
  fld.id = fldName.replace(/fld_2/, 'fld_3');
  fld.name = fld.id;
  fld.value = propertyType;
  elm.appendChild(fld);
}

function updateField12 (elm, fldName, prefix, No, fldOptions)
{
  var elm = $(elm);

  var fld = OAT.Dom.image("images/throbber.gif");
  fld.id = fldName;
  fld.mode = 'show';
  fld.title = 'Show Items';
  fld.onclick = function(){RDF.showItems(this, prefix, No);};
  if (fldOptions.cssText)
    fld.style.cssText = fldOptions.cssText;
  elm.appendChild(fld);
}

function updateField20 (elm, fldName, prefix, No, fldOptions)
{
  var elm = $(elm);

	var fld = OAT.Dom.text(fldOptions.labelValue);
  elm.appendChild(fld);

	var fld = OAT.Dom.create("select");
  fld.name = fldName;
  fld.id = fldName;
  fld.style.width = '80%';
  fld.itemType = fldOptions.itemType;
  var fldValue;
  if (fldOptions.value)
    fldValue = fldOptions.value.name;
  updateComboOption2(fld, fldValue, '', '');
  var ontology = RDF.getOntologyByName(fld.itemType.ontology);
  if (ontology && ontology.classes)
  {
    var C = ontology.classes;
    for (i = 0; i < C.length; i++)
      updateComboOption2(fld, fldValue, C[i].name, C[i].name);
  }
  elm.appendChild(fld);
}

function updateField21 (elm, fldName, prefix, No, fldOptions)
{
  var elm = $(elm);

  var fld = OAT.Dom.image("images/throbber.gif");
  fld.id = fldName;
  fld.mode = 'show';
  fld.title = 'Show Properties';
  fld.onclick = function(){RDF.showProperties(this, prefix, No);};
  if (fldOptions.cssText)
    fld.style.cssText = fldOptions.cssText;
  elm.appendChild(fld);

  if (fldOptions.item)
  {
  	var fld = OAT.Dom.create("input");
    fld.type = 'hidden';
    fld.name = fldName;
    fld.value = fldOptions.item.id;
    elm.appendChild(fld);
	}
  }

function updateField30 (elm, fldName, prefix, No, fldOptions)
  {
	var fld = OAT.Dom.create("select");
  fld.name = fldName;
  fld.id = fldName;
  fld.style.width = '95%';
  fld.item = fldOptions.item;
  var fldValue;
  if (fldOptions.value)
    fldValue = fldOptions.value.name;
  updateComboOption2(fld, fldValue, '', '');
  updateComboOption30 (fld, fldValue, fld.item.className);
  fld.onchange = function(){RDF.changePropertyValue(fld);};
  sortSelect (fld);

  var elm = $(elm);
  elm.appendChild(fld);
  }

function updateField31 (elm, fldName, prefix, No, fldOptions)
{
  if (!elm) {return;}
  // clear
  elm.innerHTML = '';

  // get product
  var item = fldOptions.item;
  if (!item) {return;}

  // get property
  var property = fldOptions.value;
  if (!property) {return;}

  // get property data
  var propertyType;
  var ontologyClassProperty = RDF.getOntologyClassProperty(item.className, property.name);
  if (ontologyClassProperty && ontologyClassProperty.objectProperties)
  {
  	var fld = OAT.Dom.create('select');
    fld.id = fldName;
    fld.name = fld.id;
    fld.style.width = '95%';
    updateComboOption2(fld, property.value, '', '');
    var classNames = ontologyClassProperty.objectProperties;
    for (var n = 0; n < RDF.itemTypes.length; n++)
    {
      var itemTypes = RDF.itemTypes[n];
      for (var m = 0; m < itemTypes.items.length; m++)
  {
        var item = itemTypes.items[m];
        for (var j = 0; j < classNames.length; j++)
        {
          if (RDF.isKindOfClass(item.className, classNames[j]))
  	        updateComboOption2(fld, property.value, item.className+' (#'+item.id+')', item.id);
  	    }
  }
    }
    for (var n = 0; n < RDF.ontologies.length; n++)
    {
      var ontologyObjects = RDF.ontologies[n].objects;
      if (ontologyObjects)
  {
        for (var i = 0; i < ontologyObjects.length; i++)
        {
          for (var j = 0; j < classNames.length; j++)
          {
            if (RDF.isKindOfClass(ontologyObjects[i].className, classNames[j]))
    	        updateComboOption2(fld, property.value, ontologyObjects[i].id, ontologyObjects[i].id);
    	    }
        }
      }
    }
    elm.appendChild(fld);
    propertyType = 'object';
  }
  if (ontologyClassProperty && ontologyClassProperty.datatypeProperties)
  {
    var fld = OAT.Dom.create('input');
    fld.type = 'text';
    fld.id = fldName;
    fld.name = fld.id;
    if (property.value)
    {
      fld.value = property.value;
      fld.defaultValue = fld.value;
  }
    fld.style.width = '95%';
    elm.appendChild(fld);
    propertyType = 'data';
  }
  var fld = OAT.Dom.create('input');
  fld.type = 'hidden';
  fld.id = fldName.replace(/fld_2/, 'fld_3');
  fld.name = fld.id;
  fld.value = propertyType;
  elm.appendChild(fld);
}

function updateButton (td, prefix, fldName, No, optionObject)
{
  fldName = prefix + '_' + fldName + '_' + No;
  if (optionObject.tdCssText)
    td.style.cssText = optionObject.tdCssText;
  var btn;
  fn = window["updateButton"+optionObject.mode];
  if (fn)
  {
	  btn = fn(td, prefix, No, fldName, optionObject);
    if (btn && optionObject.cssText)
      btn.style.cssText = optionObject.cssText;
  }
}

function updateButton1 (elm, prefix, No, btnName, btnOptions)
{
  var btn = OAT.Dom.create("input");
  btn.id = btnName;
  btn.type = 'button';
  btn.value = 'Remove';
  btn.onclick = function (){updateRow(prefix, No);};

  elm.appendChild(btn);
  return btn;
}

function updateButton2 (elm, prefix, No, btnName, btnOptions)
{
  var btn = OAT.Dom.image("images/icons/close_16.png");
  btn.id = btnName;
  btn.style.cssText = 'margin-left: 2px; margin-right: 2px;';
  btn.onclick = function (){
    var product = GR.getProduct(No);
    if (product)
    {
    if (GR.checkProductInSelects(product))
    {
      GR.removeProductInSelects(product);
      for (var i = 0; i < GR.products.length; i++)
      {
        if (GR.products[i].id == product.id)
        {
            GR.products.splice(i, 1);
          break;
        }
      }
      updateRow(prefix, No);
    }
    } else {
      updateRow(prefix, No);
    }
  };

  elm.appendChild(btn);
  return btn;
}

function updateButton3 (elm, prefix, No, btnName, btnOptions)
{
  var btn = OAT.Dom.image("images/icons/add_16.png");
  btn.id = btnName;
  btn.style.cssText = 'margin-left: 2px; margin-right: 2px;';
  btn.onclick = function (){GR.addProduct(prefix, No);};

  elm.appendChild(btn);
  return btn;
}

function updateButton4 (elm, prefix, No, btnName, btnOptions)
{
  var btn = OAT.Dom.image("images/icons/close_16.png");
  btn.id = btnName;
  btn.style.cssText = 'margin-left: 2px; margin-right: 2px;';
  btn.onclick = function (){updateRow(prefix, No);};

  elm.appendChild(btn);
  return btn;
}

function updateButton5 (elm, prefix, No, btnName, btnOptions)
{
  var btn = OAT.Dom.image("images/icons/close_16.png");
  btn.id = btnName;
  btn.style.cssText = 'margin-left: 2px; margin-right: 2px;';
  btn.onclick = function (){
    var itemType = RDF.getItemType(No);
    if (itemType)
    {
      for (var i = 0; i < RDF.itemTypes.length; i++)
      {
        if (RDF.itemTypes[i].id == itemType.id)
        {
          RDF.itemTypes.splice(i, 1);
          break;
        }
      }
    }
    updateRow(prefix, No);
  };

  elm.appendChild(btn);
  return btn;
}

function updateButton6 (elm, prefix, No, btnName, btnOptions)
{
  var btn = OAT.Dom.image("images/icons/add_16.png");
  btn.id = btnName;
  btn.style.cssText = 'margin-left: 2px; margin-right: 2px;';
  btn.onclick = function(){RDF.addItemType(prefix, No);};

  elm.appendChild(btn);
  return btn;
}

function updateButton7 (elm, prefix, No, btnName, btnOptions)
{
  var btn = OAT.Dom.image("images/icons/add_16.png");
  btn.id = btnName;
  btn.style.cssText = 'margin-left: 2px; margin-right: 2px;';
  btn.onclick = function(){RDF.addItem(prefix, No);};

  elm.appendChild(btn);
  return btn;
}

function validateError(fld, msg)
{
  alert(msg);
  setTimeout(function(){fld.focus();}, 1);
  return false;
}

function validateMail(fld)
{
  if ((fld.value.length == 0) || (fld.value.length > 40))
    return validateError(fld, 'E-mail address cannot be empty or longer then 40 chars');

  var regex = /^([a-zA-Z0-9_\.\-])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9]{2,4})+$/;
  if (!regex.test(fld.value))
    return validateError(fld, 'Invalid E-mail address');

  return true;
}

function validateURL(fld)
{
  var regex = /(ftp|http|https|skype):(\/\/)?(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?/
  if (!regex.test(fld.value))
    return validateError(fld, 'Invalid URL address : ' + fld.value);

  return true;
}

function validateField(fld)
{
  if ((fld.value.length == 0) && OAT.Dom.isClass(fld, '_canEmpty_'))
    return true;
  if (OAT.Dom.isClass(fld, '_mail_'))
    return validateMail(fld);
  if (OAT.Dom.isClass(fld, '_url_'))
    return validateURL(fld);
  if (fld.value.length == 0)
    return validateError(fld, 'Field cannot be empty');
  return true;
}

function validateInputs(fld)
{
  var retValue = true;
  var form = fld.form;
  for (i = 0; i < form.elements.length; i++)
  {
    var fld = form.elements[i];
    if (OAT.Dom.isClass(fld, '_validate_'))
    {
      retValue = validateField(fld);
      if (!retValue)
        return retValue;
    }
  }
  return retValue;
}

// Good Relations
// ---------------------------------------------------------------------------
var GR = new Object();
GR.ontologies = new Object();
GR.objects = new Object();
GR.products = new Array();

GR.loadOntology = function (prefix, ontology)
{
  // load classes
  var S = '/ods/api/ontology.classes?ontology='+encodeURIComponent(ontology);
  var x = function(data) {
    var o = null;
    try {
      o = OAT.JSON.parse(data);
    } catch (e) {o = null;}
    GR.ontologies[prefix] = o;
}
  OAT.AJAX.GET(S, '', x, {});

  // load objects (individuals)
  var S = '/ods/api/ontology.objects?ontology='+encodeURIComponent(ontology);
  var x = function(data) {
    var o = null;
    try {
      o = OAT.JSON.parse(data);
    } catch (e) {o = null;}
    GR.objects[prefix] = o;
  }
  OAT.AJAX.GET(S, '', x, {});
}

GR.getOntology = function (prefix)
{
  return GR.ontologies[prefix];
}

GR.getOntologyClass = function (className)
{
  var prefix = GR.getPrefix(className);
  if (prefix)
  {
    var ontology = GR.getOntology(prefix);
    if (ontology)
  {
    var classes = ontology.classes;
    for (var i = 0; i < classes.length; i++)
    {
      if (classes[i].name == className)
        return classes[i];
    }
  }
  }
  return null;
}

GR.getOntologyClassProperty = function (className, propertyName)
{
  var ontologyClass = GR.getOntologyClass(className);
  if (ontologyClass)
  {
    var properties = ontologyClass.properties;
    for (var i = 0; i < properties.length; i++)
    {
      if (properties[i].name == propertyName)
        return properties[i];
    }
    if (ontologyClass.subClassOf)
      return GR.getOntologyClassProperty(ontologyClass.subClassOf, propertyName)
  }
  return null;
}

GR.getProduct = function (No)
{
  for (var i = 0; i < GR.products.length; i++)
  {
    if (GR.products[i].id == No)
      return GR.products[i];
  }
  return null;
}

GR.getPrefix = function (ontologyClassName)
{
  if (!ontologyClassName)
    return null;
  var N = ontologyClassName.indexOf(':');
  if (N == -1)
    return null;
  return ontologyClassName.substring(0, N);
}

GR.isKindOfClass = function (objectClassName, propertyClassName)
{
  if (objectClassName == propertyClassName)
    return true;
  var ontologyClass = GR.getOntologyClass(objectClassName);
  if (ontologyClass && ontologyClass.subClassOf)
    return GR.isKindOfClass (ontologyClass.subClassOf, propertyClassName);
  return false;
}

GR.loadClassProperties = function (ontologyClass, cbFunction)
{
  if (ontologyClass.properties)
  {
    cbFunction();
    return;
  }
    var S = '/ods/api/ontology.classProperties?ontologyClass='+encodeURIComponent(ontologyClass.name);
    var x = function(data) {
      var o = null;
      try {
        o = OAT.JSON.parse(data);
      } catch (e) { o = null; }
      ontologyClass.properties = o;
    var ontologySubClass = GR.getOntologyClass(ontologyClass.subClassOf);
    if (ontologySubClass)
    {
      GR.loadClassProperties(ontologySubClass, cbFunction)
      return;
    }
    cbFunction();
  }
  OAT.AJAX.GET(S, '', x, {});
}

GR.emptyRowID = function (prefix)
{
  return prefix + '_tr_no';
}

GR.clearTable = function (prefix)
{
  var tbody = $(prefix+'_tbody');
  if (!tbody)
    return;
  var noTR = GR.emptyRowID(prefix);
  var TRs = tbody.childNodes;
  for (i = TRs.length; i >= 0; i--)
  {
    var tr = TRs[i];
    if (tr && tr.tagName == 'tr' && tr.id != noTR)
      OAT.Dom.unlink(tr);
  }
  OAT.Dom.show(noTR);
}

GR.showProducts = function ()
{
  var prefix = GR.tablePrefix;
  var tbody = $(prefix+'_tbody');
  if (!tbody)
    return;

  // load ontology http://purl.org/goodrelations/v1#
  GR.loadOntology('gr', 'http://purl.org/goodrelations/v1#');

  // clear table first
  GR.clearTable(prefix);

  var noTR = GR.emptyRowID(prefix);
  if (GR.products && GR.products.length)
  {
    OAT.Dom.hide(noTR);
    for (i = 0; i < GR.products.length; i++)
    {
      GR.showProduct(GR.products[i]);
    }
  } else {
    OAT.Dom.show(noTR);
  }
}

GR.showProduct = function (product)
{
  var prefix = GR.tablePrefix;
  var tbody = $(prefix+'_tbody');
  if (!tbody)
    return;
  updateRow(prefix, null, {No: product.id, fld_1: {mode: 6, cssText: ''}, fld_2: {mode: 7, value: 'Element #'+product.id}, fld_3: {mode: 9, value: product.objectClass}, btn_1: {mode: 2, cssText: 'margin-left: 2px; margin-right: 2px;'}});
}

GR.addProduct = function (prefix, No)
{
  var tr = $(prefix+'_tr_'+No);
  if (!tr) {return;}

  OAT.Dom.show(prefix+'_fld_1_'+No);
  var td = $(prefix+'_td_'+No+'_2');
  if (td)
  	td.innerHTML = 'Element #'+No;

  var td = $(prefix+'_td_'+No+'_3');
  if (td)
  {
    var fld = $(prefix+'_fld_3_' + No);
    if (fld)
    {
      // create new product object
      var product = new Object();
      product.prefix = 'gr';
      product.objectClass = fld.value;
      product.id = No;

      // add product
      GR.products[GR.products.length] = product;

      // hide combo
	    OAT.Dom.hide(fld);

      // show combo value as text
	    var fld = OAT.Dom.text(fld.value);
      td.appendChild(fld);
      GR.addProductToSelects(product);
  	}
  }
	OAT.Dom.hide(prefix+'_btn_2_'+No);
}

GR.addProductToSelects = function (product)
{
  var tbl = $(GR.tablePrefix+'_tbl');
  if (!tbl) {return;}

  var selects = tbl.getElementsByTagName('select');
  if (!selects) {return;}
  for (var i = 0; i < selects.length; i++)
  {
    var obj = selects[i];
    if ((obj.id.indexOf('prop_') == 0) && (obj.id.indexOf('_fld_1_') != -1) && (obj.value != ''))
    {
      var ontologyClassProperty = GR.getOntologyClassProperty(obj.product.objectClass, obj.value);
      if (ontologyClassProperty.objectProperties)
      {
        for (var j = 0; j < ontologyClassProperty.objectProperties.length; j++)
        {
          if (product.objectClass == ontologyClassProperty.objectProperties[j])
          {
      	    var fld = $(obj.id.replace(/_fld_1_/, '_fld_2_'));
            if (fld)
    	        updateComboOption2(fld, fld.value, 'Element #'+product.id, product.id);
    	    }
        }
      }
    }
  }
}

GR.checkProductInSelects = function (product)
{
  return GR.productInSelects (product, 'check');
}

GR.removeProductInSelects = function (product)
{
  return GR.productInSelects (product, 'remove');
}

GR.productInSelects = function (product, mode)
{
  var tbl = $(GR.tablePrefix+'_tbl');
  if (!tbl) {return;}

  var selects = tbl.getElementsByTagName('select');
  if (!selects) {return;}
  for (var i = 0; i < selects.length; i++)
  {
    var obj = selects[i];
    if ((obj.id.indexOf('prop_') == 0) && (obj.id.indexOf('_fld_1_') != -1) && (obj.value != ''))
    {
      var ontologyClassProperty = GR.getOntologyClassProperty(obj.product.objectClass, obj.value);
      if (ontologyClassProperty.objectProperties)
      {
        for (var i = 0; i < ontologyClassProperty.objectProperties.length; i++)
        {
          if (product.objectClass == ontologyClassProperty.objectProperties[i])
          {
      	    var fld = $(obj.id.replace(/_fld_1_/, '_fld_2_'));
            if (fld)
            {
              for (var j = fld.options.length-1; j >= 0; j--)
              {
                if (fld.options[j].value == product.id)
                {
                  if ((mode == 'check') && fld.options[j].selected)
                    return confirm ('The selected object is used. Delete?');
                  if (mode == 'remove')
    	              fld.remove(j);
    	          }
    	        }
    	      }
    	    }
        }
      }
    }
  }
  return true;
}

GR.showProperties = function (obj, prefix, No)
{
  var product = GR.getProduct(No);
  if (!product)
    return;
  var ontologyClass = GR.getOntologyClass(product.objectClass);
  if (!ontologyClass)
    return;
  var tr = $(prefix+'_tr_' + No);
  if (!tr)
    return;
  var fld = $(prefix+'_fld_2_' + No);
  if (fld)
    fld.value = '1';
  var trProperties = $(prefix+'_tr_' + No + '_properties');
  if (obj.mode == 'show')
  {
    obj.mode = 'hide';
    obj.title = 'Hide Properties';
    obj.src = 'images/icons/orderup_16.png';
    if (!trProperties)
    {
      //
      trProperties = OAT.Dom.create('tr');
      trProperties.id = prefix + '_tr_' + No + '_properties';
      trProperties.style.cssText = 'background-color: #F5F5EE;';
      //
      var tdProperties1 = OAT.Dom.create('td');
      tdProperties1.style.cssText = 'background-color: #FFF;';
      trProperties.appendChild(tdProperties1);
      //
      var tdProperties2 = OAT.Dom.create('td');
      tdProperties2.style.cssText = 'vertical-align: top;';
      tdProperties2.appendChild(OAT.Dom.text("~ properties"));
      trProperties.appendChild(tdProperties2);
      //
      var tdProperties3 = OAT.Dom.create('td');
      trProperties.appendChild(tdProperties3);
      GR.loadClassProperties(ontologyClass, function(){GR.showPropertiesTable(product);});
      //
      var tdProperties4 = OAT.Dom.create('td');
      tdProperties4.style.cssText = 'vertical-align: top;';
      trProperties.appendChild(tdProperties4);

      // insertBefore(trProperties, tr);
      var trParent = tr.parentNode;
  	  if(tr.nextSibling)
  	  {
  		  trParent.insertBefore(trProperties, tr.nextSibling);
  	  } else {
  		  trParent.appendChild(trProperties);
  	  }
    } else {
      OAT.Dom.show(trProperties);
    }
  } else {
    obj.mode = 'show';
    obj.title = 'Show Properties';
    obj.src = 'images/icons/orderdown_16.png';
    OAT.Dom.hide(trProperties);
  }
}

GR.showPropertiesTable = function (product)
{
  var ontologyClass = GR.getOntologyClass(product.objectClass);
  if (!ontologyClass)
    return;
  var prefix = GR.tablePrefix;
  var No = product.id;
  var tr = $(prefix + '_tr_' + No + '_properties');
  if (tr)
  {
    var TDs = tr.getElementsByTagName('td');
    if (ontologyClass.properties.length)
    {
      var prefixProp = 'prop_'+No;

      var btn = OAT.Dom.image("images/icons/add_16.png");
      btn.style.cssText = 'margin-left: 2px; margin-right: 2px;';
      btn.onclick = function (){updateRow(prefixProp, null, {fld_1: {mode: 10, product: product}, fld_2: {mode: 11}, btn_1: {mode: 4}});};
      TDs[3].appendChild(btn);

      var S = '<table id="prop_tbl" class="listing" style="background-color: #F5F5EE;"><thead><tr class="listing_header_row"><th width="50%">Property</th><th width="50%">Value</th><th width="80px">Action</th></tr></thead><tbody id="prop_tbody"><tr id="prop_tr_no"><td colspan="3">No Properties</td></tr></tbody></table><input type="hidden" id="prop_no" name="prop_no" value="0" />';
      TDs[2].innerHTML = S.replace(/prop_/g, prefixProp+'_');

      var properties = product.properties;
      if (properties)
      {
        for (var i = 0; i < properties.length; i++)
          updateRow(prefixProp, null, {fld_1: {mode: 10, product: product, value: properties[i]}, fld_2: {mode: 11, product: product, value: properties[i]}, btn_1: {mode: 4}});
      }
    } else {
      TDs[2].innerHTML = '<b><i>class has not properties</i></b>';
    }
  }
}

GR.changePropertyValue = function (obj)
{
  var fld;
  var S = obj.id;
  var fldName = S.replace(/fld_1/, 'fld_2');
  var S = obj.parentNode.id;
  var td = $(S.substr(0,S.lastIndexOf('_')+1)+'2');
  updateField11(td, fldName, null, null, {product: obj.product, value: {name: obj.value}});
}

// RDF Relations
// ---------------------------------------------------------------------------
var RDF = new Object();
RDF.tablePrefix = 'r';
RDF.ontologies = new Object();
RDF.itemTypes = new Object();

var rdfTypes = [{"label":'mo',   "uri":'http://purl.org/ontology/mo/'},
                {"label":'book', "uri":'http://purl.org/NET/book/vocab#'},
    				 		{"label":'foaf', "uri":'http://xmlns.com/foaf/0.1/'},
    						{"label":'owl', "uri":'http://www.w3.org/2002/07/owl#'},
    						{"label":'sioct', "uri":'http://rdfs.org/sioc/types#'},
    						{"label":'sioc', "uri":'http://rdfs.org/sioc/ns#'},
    						{"label":'ibis', "uri":'http://purl.org/ibis#',"hidden":1},
    						{"label":'conf', "uri":'http://www.mindswap.org/~golbeck/web/www04photo.owl#'},
    						{"label":'scot', "uri":'http://scot-project.org/scot/ns'},
    						{"label":'ical', "uri":'http://www.w3.org/2002/12/cal/icaltzd#'},
    						{"label":'mo', "uri":'http://purl.org/ontology/mo/'},
    						{"label":'annotation', "uri":'http://www.w3.org/2000/10/annotation-ns#'},
    						{"label":'rdfs', "uri":'http://www.w3.org/2000/01/rdf-schema#'},
    						{"label":'rdf', "uri":'http://www.w3.org/1999/02/22-rdf-syntax-ns#'},
    						{"label":'dcterms', "uri":'http://purl.org/dc/terms/'},
    						{"label":'dc', "uri":'http://purl.org/dc/elements/1.1/'},
    						{"label":'cc', "uri":'http://web.resource.org/cc/'},
    						{"label":'geo', "uri":'http://www.w3.org/2003/01/geo/wgs84_pos#'},
    						{"label":'rss', "uri":'http://purl.org/rss/1.0/'},
    						{"label":'skos', "uri":'http://www.w3.org/2008/05/skos#'},
    						{"label":'vs', "uri":'http://www.w3.org/2003/06/sw-vocab-status/ns#'},
    						{"label":'opo',"uri":'http://ggg.milanstankovic.org/opo/ns/'},
    						{"label":'nco',"uri":'http://www.semanticdesktop.org/ontologies/nco/'},
    						{"label":'lsdis',"uri":'http://lsdis.cs.uga.edu/projects/meteor-s/wsdl-s/ontologies/LSDIS_FInance.owl'},
    						{"label":'nao',"uri":'http://www.semanticdesktop.org/ontologies/nao/'},
    						{"label":'cohere',"uri":'http://cohere.open.ac.uk/ontology/cohere.owl#'},
    						{"label":'nfo',"uri":'http://www.semanticdesktop.org/ontologies/nfo/'},
    						{"label":'nmo',"uri":'http://www.semanticdesktop.org/ontologies/nmo/'},
    						{"label":'nie',"uri":'http://www.semanticdesktop.org/ontologies/nie/'},
    						{"label":'nid3',"uri":'http://www.semanticdesktop.org/ontologies/nid3/'},
    						{"label":'kuaba',"uri":'http://www.tecweb.inf.puc-rio.br/ontologies/kuaba'},
    						{"label":'wot', "uri":'http://xmlns.com/wot/0.1/',"hidden":1},
    						{"label":'xhtml', "uri":'http://www.w3.org/1999/xhtml',"hidden":1},
    						{"label":'atom', "uri":'http://atomowl.org/ontologies/atomrdf#',"hidden":1},
    						{"label":'dataview', "uri":'http://www.w3.org/2003/g/data-view#',"hidden":1},
    						{"label":'xsd', "uri":'http://www.w3.org/2001/XMLSchema#',"hidden":1}
    					 ];
for (var i=0; i<rdfTypes.length; i=i+1)
{
  rdfType = rdfTypes[i];
  var o = new Object();
  o.name = rdfType.uri;
  RDF.ontologies[rdfType.label] = o;
}

RDF.loadOntology = function (ontologyName, cbFunction)
{
  var prefix = this.ontologyPrefix(ontologyName);
  if (!prefix) {return;}

  // load ontology classes
  var S = '/ods/api/ontology.classes?ontology='+encodeURIComponent(ontologyName);
  var x = function(data) {
    var o = null;
    try {
      o = OAT.JSON.parse(data);
    } catch (e) {o = null;}
    RDF.ontologies[prefix] = o;
    if (o)
    {
      // load objects (individuals)
      var S = '/ods/api/ontology.objects?ontology='+encodeURIComponent(ontologyName);
      var x = function(data) {
        var o = null;
        try {
          o = OAT.JSON.parse(data);
        } catch (e) {o = null;}
        RDF.ontologies[prefix].objects = o;
      }
      OAT.AJAX.GET(S, '', x, {});
    }
    if (cbFunction)
      cbFunction();
  }
  OAT.AJAX.GET(S, '', x, {});
}

RDF.getOntologyByPrefix = function(prefix)
{
  return RDF.ontologies[prefix];
}

RDF.getOntologyByName = function(ontologyName)
{
  var prefix = RDF.ontologyPrefix(ontologyName);
  return RDF.ontologies[prefix];
}

RDF.getOntologyByClass = function(className)
{
  var prefix = RDF.extractPrefix(className);
  return RDF.ontologies[prefix];
}

RDF.getOntologyClass = function(className)
{
  var ontology = RDF.getOntologyByClass(className);
  if (ontology)
  {
    var classes = ontology.classes;
    for (var i = 0; i < classes.length; i++)
    {
      if (classes[i].name == className)
        return classes[i];
    }
  }
  return null;
}

RDF.getOntologyClassProperty = function(className, propertyName)
{
  var ontologyClass = this.getOntologyClass(className);
  if (ontologyClass)
  {
    var properties = ontologyClass.properties;
    for (var i = 0; i < properties.length; i++)
    {
      if (properties[i].name == propertyName)
        return properties[i];
    }
    if (ontologyClass.subClassOf)
      return this.getOntologyClassProperty(ontologyClass.subClassOf, propertyName)
  }
  return null;
}

RDF.ontologyPrefix = function(ontologyName)
{
  for (var prefix in this.ontologies)
    if (this.ontologies[prefix].name == ontologyName)
      return prefix;
  return null;
}

RDF.extractPrefix = function(ontologyClassName)
{
  if (!ontologyClassName)
    return null;
  var N = ontologyClassName.indexOf(':');
  if (N == -1)
    return null;
  return ontologyClassName.substring(0, N);
}

RDF.isKindOfClass = function(objectClassName, propertyClassName)
{
  if (objectClassName == propertyClassName)
    return true;
  var ontologyClass = this.getOntologyClass(objectClassName);
  if (ontologyClass && ontologyClass.subClassOf)
    return RDF.isKindOfClass (ontologyClass.subClassOf, propertyClassName);
  return false;
}

RDF.loadClassProperties = function(ontologyClass, cbFunction)
{
  if (ontologyClass.properties)
  {
    cbFunction();
    return;
  }
  var S = '/ods/api/ontology.classProperties?ontologyClass='+encodeURIComponent(ontologyClass.name);
  var x = function(data) {
    var o = null;
    try {
      o = OAT.JSON.parse(data);
    } catch (e) { o = null; }
    ontologyClass.properties = o;
    var ontologySubClass = RDF.getOntologyClass(ontologyClass.subClassOf);
    if (ontologySubClass)
    {
      RDF.loadClassProperties(ontologySubClass, cbFunction)
      return;
    }
    cbFunction();
  }
  OAT.AJAX.GET(S, '', x, {});
}

RDF.emptyRowID = function()
{
  var prefix = this.tablePrefix;
  return prefix + '_tr_no';
}

RDF.clearTable = function()
{
  var prefix = this.tablePrefix;
  var tbody = $(prefix+'_tbody');
  if (!tbody)
    return;
  var noTR = this.emptyRowID();
  var TRs = tbody.childNodes;
  for (i = TRs.length; i >= 0; i--)
  {
    var tr = TRs[i];
    if (tr && tr.tagName == 'tr' && tr.id != noTR)
      OAT.Dom.unlink(tr);
  }
  OAT.Dom.show(noTR);
}

// Item Types functions
//
RDF.showItemTypes = function()
{
  var prefix = this.tablePrefix;
  var tbody = $(prefix+'_tbody');
  if (!tbody)
    return;

  // clear table first
  var noTR = this.emptyRowID();
  if (this.itemTypes && this.itemTypes.length)
  {
    this.clearTable(prefix);
    for (i = 0; i < this.itemTypes.length; i++)
    {
      // load ontologies
      this.loadOntology(this.itemTypes[i].ontology, (function(itemType){return function(){RDF.showItemType(prefix, itemType)}})(this.itemTypes[i]));
    }
    OAT.Dom.hide(noTR);
  } else {
    OAT.Dom.show(noTR);
  }
}

RDF.showItemType = function(prefix, itemType)
{
  updateRow(prefix, null, {No: itemType.id, fld_1: {mode: 12, cssText: ''}, fld_2: {mode: 9, value: itemType.ontology, showValue: itemType.ontology+' ('+RDF.ontologyPrefix(itemType.ontology)+')'}, btn_1: {mode: 2, cssText: 'margin-left: 2px; margin-right: 2px;'}});
  if (itemType.items)
  {
    var obj = $(prefix+'_fld_1_'+itemType.id);
    this.showItems(obj, prefix, itemType.id)
  }
}

RDF.getItemType = function(No)
{
  for (var i = 0; i < this.itemTypes.length; i++)
  {
    if (this.itemTypes[i].id == No)
      return this.itemTypes[i];
  }
  return null;
}

RDF.getItemTypeByItem = function(item)
{
  for (var i = 0; i < this.itemTypes.length; i++)
  {
    var itemType = this.itemTypes[i];
    if (itemType.items)
      for (var j = 0; j < itemType.items.length; j++)
        if (itemType.items[j] == item)
          return itemType;
  }
  return null;
}

RDF.addItemType = function(prefix, No)
{
  var tr = $(prefix+'_tr_'+No);
  if (!tr) {return;}

  var fld1 = $(prefix+'_fld_1_' + No);
  if (!fld1) {return;}

  var fld2 = $(prefix+'_fld_2_' + No);
  if (!fld2) {return;}

  var fValue = fld2.value.trim();
  if (fValue == '') {return alert ('Please enter value!');}

  for (var i = 0; i < this.itemTypes.length; i++)
    if (this.itemTypes[i].ontology == fValue)
      return alert ('This favorite type already exists. Please enter another value!');

  OAT.Dom.show(fld1);
  var td = $(prefix+'_td_'+No+'_2');
  if (!td) {return;}

    // create new item object
    var itemType = new Object();
    itemType.ontology = fValue;
    itemType.id = No;
    this.loadOntology(itemType.ontology, function(){fld1.onclick();});

    // add item
    this.itemTypes[this.itemTypes.length] = itemType;

    // clear childs
    td.innerHTML = '';

    // add hidden item
  td.appendChild(fld2);
  OAT.Dom.hide(fld2);

    // show combo value as text
    var fld = OAT.Dom.text(fValue+' ('+this.ontologyPrefix(fValue)+')');
    td.appendChild(fld);

	OAT.Dom.hide(prefix+'_btn_2_'+No);
}

// Item functions
//
RDF.showItems = function (obj, prefix, No)
{
  var itemType = this.getItemType(No);
  if (!itemType) {return;}

  var tr = $(prefix+'_tr_' + No);
  if (!tr) {return;}

  var trItems = $(prefix+'_tr_' + No + '_items');
  if (obj.mode == 'show')
  {
    obj.mode = 'hide';
    obj.title = 'Hide Items';
    obj.src = 'images/icons/orderup_16.png';
    if (!trItems)
    {
      //
      trItems = OAT.Dom.create('tr');
      trItems.id = prefix + '_tr_' + No + '_items';
      trItems.style.cssText = 'background-color: #F5F5EE;';
      //
      var tdItems1 = OAT.Dom.create('td');
      tdItems1.style.cssText = 'background-color: #FFF;';
      trItems.appendChild(tdItems1);
      //
      var tdItems2 = OAT.Dom.create('td');
      trItems.appendChild(tdItems2);
      //
      var tdItems3 = OAT.Dom.create('td');
      tdItems3.style.cssText = 'vertical-align: top; background-color: #FFF;';
      trItems.appendChild(tdItems3);

      // insertBefore(trItems, tr);
      var trParent = tr.parentNode;
  	  if(tr.nextSibling)
  	  {
  		  trParent.insertBefore(trItems, tr.nextSibling);
  	  } else {
  		  trParent.appendChild(trItems);
  	  }
      this.showItemsTable(itemType);
    }
    OAT.Dom.show(trItems);
  } else {
    obj.mode = 'show';
    obj.title = 'Show Items';
    obj.src = 'images/icons/orderdown_16.png';
    OAT.Dom.hide(trItems);
  }
}

RDF.showItemsTable = function(itemType)
{
  var ontology = this.getOntologyByName(itemType.ontology);
  if (!ontology) {return;}

  var prefix = this.tablePrefix;
  var No = itemType.id;
  var trItems = $(prefix + '_tr_' + No + '_items');
  if (!trItems) {return;}

  var TDs = trItems.getElementsByTagName('td');
  if (ontology.classes.length)
  {
    var prefixItem = prefix + '_item_' + No;

    var btn = OAT.Dom.image("images/icons/add_16.png");
    btn.style.cssText = 'margin-left: 2px; margin-right: 2px;';
    btn.onclick = function(){updateRow(prefixItem, null, {fld_1: {mode: 21, cssText: 'display: none;'}, fld_2: {mode: 20, itemType: itemType, labelValue: 'New Item: '}, btn_1: {mode: 4, cssText: 'margin-left: 2px; margin-right: 2px;'}, btn_2: {mode: 7, cssText: 'margin-left: 2px; margin-right: 2px;'}});};
    TDs[2].appendChild(btn);

    var S = '<table id="item_tbl" class="listing" style="background-color: #F5F5EE;"><thead><tr class="listing_header_row"><th><div style="width: 16px;"><![CDATA[&nbsp;]]></div></th><th width="100%">Item</th><th width="80px">Action</th></tr></thead><tbody id="item_tbody"><tr id="item_tr_no"><td></td><td colspan="2"><b><i>No Items</i></b></td></tr></tbody></table><input type="hidden" id="item_no" name="item_no" value="0" />';
    TDs[1].innerHTML = S.replace(/item_/g, prefixItem+'_');

    var items = itemType.items;
    if (items)
    {
      for (var i = 0; i < items.length; i++)
        this.showItem(prefixItem, items[i]);
    }
  } else {
    TDs[1].innerHTML = '<b><i>Ontology has not elements</i></b>';
  }
}

RDF.showItem = function(prefix, item)
{
  updateRow(prefix, null, {No: item.id, fld_1: {mode: 21, item: item}, fld_2: {mode: 9, value: item.className, showValue: item.className+' (#'+item.id+')'}, btn_1: {mode: 2, cssText: 'margin-left: 2px; margin-right: 2px;'}});
  if (item.properties)
  {
    var obj = $(prefix+'_fld_1_'+item.id);
    this.showProperties(obj, prefix, item.id)
  }
}

RDF.getItem = function(No)
{
  for (var i = 0; i < this.itemTypes.length; i++)
  {
    var items = this.itemTypes[i].items;
    if (items)
    {
      for (var j = 0; j < items.length; j++)
      {
        if (items[j].id == No)
          return items[j];
      }
    }
  }
  return null;
}

RDF.addItem = function(prefix, No)
{
  var tr = $(prefix+'_tr_'+No);
  if (!tr) {return;}

  var fld1 = $(prefix+'_fld_1_' + No);
  if (!fld1) {return;}

  var fld2 = $(prefix+'_fld_2_' + No);
  if (!fld2) {return;}

  var fValue = fld2.value.trim();
  if (fValue == '')
    return alert ('Please enter value!');

  var itemType = fld2.itemType;
  if (!itemType) {return;}

  OAT.Dom.show(fld1);
  var td = $(prefix+'_td_'+No+'_2');
  if (!td) {return;}

    // create new item
    var item = new Object();
    item.className = fValue;
    item.id = No;

    // add item
    if (!itemType.items)
      itemType.items = [];
    itemType.items[itemType.items.length] = item;

  // load properties
  this.loadClassProperties(item.className, function(){fld1.onclick();});

    // clear childs
    td.innerHTML = '';

    // add hidden item
  td.appendChild(fld2);
  OAT.Dom.hide(fld2);

    // show combo value as text
    var fld = OAT.Dom.text(fValue);
    td.appendChild(fld);

    // update selectors
    RDF.addItemToSelects(item);

	OAT.Dom.hide(prefix+'_btn_2_'+No);
}

RDF.addItemToSelects = function(product)
{
  var tbl = $(this.tablePrefix+'_tbl');
  if (!tbl) {return;}

  var selects = tbl.getElementsByTagName('select');
  if (!selects) {return;}
  for (var i = 0; i < selects.length; i++)
  {
    var obj = selects[i];
    if ((obj.id.indexOf('prop_') == 0) && (obj.id.indexOf('_fld_1_') != -1) && (obj.value != ''))
    {
      var ontologyClassProperty = this.getOntologyClassProperty(obj.itemType.objectClass, obj.value);
      if (ontologyClassProperty.objectProperties)
      {
        for (var j = 0; j < ontologyClassProperty.objectProperties.length; j++)
        {
          if (product.objectClass == ontologyClassProperty.objectProperties[j])
          {
      	    var fld = $(obj.id.replace(/_fld_1_/, '_fld_2_'));
            if (fld)
    	        updateComboOption2(fld, fld.value, 'Element #'+itemType.id, itemType.id);
    	    }
        }
      }
    }
  }
}

RDF.checkItemInSelects = function(product)
{
  return RDF.itemInSelects(product, 'check');
}

RDF.removeItemInSelects = function(product)
{
  return RDF.itemInSelects(product, 'remove');
}

RDF.itemInSelects = function(product, mode)
{
  var tbl = $(this.tablePrefix+'_tbl');
  if (!tbl) {return;}

  var selects = tbl.getElementsByTagName('select');
  if (!selects) {return;}
  for (var i = 0; i < selects.length; i++)
  {
    var obj = selects[i];
    if ((obj.id.indexOf('prop_') == 0) && (obj.id.indexOf('_fld_1_') != -1) && (obj.value != ''))
    {
      var ontologyClassProperty = this.getOntologyClassProperty(obj.product.objectClass, obj.value);
      if (ontologyClassProperty.objectProperties)
      {
        for (var i = 0; i < ontologyClassProperty.objectProperties.length; i++)
        {
          if (product.objectClass == ontologyClassProperty.objectProperties[i])
          {
      	    var fld = $(obj.id.replace(/_fld_1_/, '_fld_2_'));
            if (fld)
            {
              for (var j = fld.options.length-1; j >= 0; j--)
              {
                if (fld.options[j].value == product.id)
                {
                  if ((mode == 'check') && fld.options[j].selected)
                    return confirm ('The selected object is used. Delete?');
                  if (mode == 'remove')
    	              fld.remove(j);
    	          }
    	        }
    	      }
    	    }
        }
      }
    }
  }
  return true;
}

RDF.showProperties = function(obj, prefix, No)
{
  var item = RDF.getItem(No);
  if (!item) {return;}

  var ontologyClass = this.getOntologyClass(item.className);
  if (!ontologyClass) {return;}

  var tr = $(prefix+'_tr_' + No);
  if (!tr) {return;}

  var trProperties = $(prefix+'_tr_' + No + '_properties');
  if (obj.mode == 'show')
  {
    obj.mode = 'hide';
    obj.title = 'Hide Properties';
    obj.src = 'images/icons/orderup_16.png';
    if (!trProperties)
    {
      //
      trProperties = OAT.Dom.create('tr');
      trProperties.id = prefix + '_tr_' + No + '_properties';
      trProperties.style.cssText = 'background-color: #FFF;';
      //
      var tdProperties1 = OAT.Dom.create('td');
      tdProperties1.style.cssText = 'background-color: #F5F5EE;';
      trProperties.appendChild(tdProperties1);
      //
      var tdProperties2 = OAT.Dom.create('td');
      trProperties.appendChild(tdProperties2);
      //
      var tdProperties3 = OAT.Dom.create('td');
      tdProperties3.style.cssText = 'vertical-align: top; background-color: #F5F5EE;';
      trProperties.appendChild(tdProperties3);

      var trParent = tr.parentNode;
  	  if(tr.nextSibling)
  	  {
  		  trParent.insertBefore(trProperties, tr.nextSibling);
  	  } else {
  		  trParent.appendChild(trProperties);
  	  }
      RDF.loadClassProperties(ontologyClass, function(){RDF.showPropertiesTable(item);});
    }
    OAT.Dom.show(trProperties);
  } else {
    obj.mode = 'show';
    obj.title = 'Show Properties';
    obj.src = 'images/icons/orderdown_16.png';
    OAT.Dom.hide(trProperties);
  }
}

RDF.showPropertiesTable = function(item)
{
  var ontologyClass = this.getOntologyClass(item.className);
  if (!ontologyClass) {return;}

  var itemType = this.getItemTypeByItem(item);
  if (!itemType) {return;}

  var prefix = this.tablePrefix + '_item_' + itemType.id;
  var No = item.id;
  var tr = $(prefix + '_tr_' + No + '_properties');
  if (tr)
  {
    var TDs = tr.getElementsByTagName('td');
    if (ontologyClass.properties.length)
    {
      var prefixProp = prefix + '_prop_' + No;

      var btn = OAT.Dom.image("images/icons/add_16.png");
      btn.style.cssText = 'margin-left: 2px; margin-right: 2px;';
      btn.onclick = function(){updateRow(prefixProp, null, {fld_1: {mode: 30, item: item}, fld_2: {mode: 31, item: item}, btn_1: {mode: 4}});};
      TDs[2].appendChild(btn);

      var S = '<table id="prop_tbl" class="listing" style="background-color: #FFF;"><thead><tr class="listing_header_row"><th width="50%">Property</th><th width="50%">Value</th><th width="80px">Action</th></tr></thead><tbody id="prop_tbody"><tr id="prop_tr_no"><td colspan="3">No Properties</td></tr></tbody></table><input type="hidden" id="prop_no" name="prop_no" value="0" />';
      TDs[1].innerHTML = S.replace(/prop_/g, prefixProp+'_');

      var properties = item.properties;
      if (properties)
      {
        for (var i = 0; i < properties.length; i++)
          updateRow(prefixProp, null, {fld_1: {mode: 30, item: item, value: properties[i]}, fld_2: {mode: 31, item: item, value: properties[i]}, btn_1: {mode: 4}});
      }
    } else {
      TDs[1].innerHTML = '<b><i>class has not properties</i></b>';
    }
  }
}

RDF.changePropertyValue = function(obj)
{
  var S = obj.id;
  var fldName = S.replace(/fld_1/, 'fld_2');
  var S = obj.parentNode.id;
  var td = $(S.substr(0,S.lastIndexOf('_')+1)+'2');
  updateField31(td, fldName, '', 0, {item: obj.item, value: {name: obj.value}});
}
