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
      if (contr != null && contr.type == "select-one" && contr.name.indexOf (pref) != -1)
        {
          contr.value = val;
        }
    }
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
  var i;
  if (sflag == true || btn == null || btn == '' || form.__submit_func.value != '' || form.__event_initiator.value != '')
    return true;
  for (i = 0; i < form.elements.length; i++)
    {
      if (form.elements[i] != null)
        {
          var ctrl = form.elements[i];

          if(typeof(ctrl.type)!='undefined')
          {
            if (ctrl.type.indexOf ('select') != -1)
            {
                var j, selections = 0;
    	          for (j = 0; j < ctrl.length; j ++)
    	            {
                     var opt = ctrl.options[j];
    	               if (opt.defaultSelected == true)
    		                   selections ++;
                     if (opt.defaultSelected != opt.selected)
                            {
                              dirty = true;
                            }
                  }
    	          if (selections == 0 && ctrl.selectedIndex == 0)
    	            dirty = false;
    	          if (dirty == true)
    	          {
    	            //alert (ctrl.name+' value=['+ctrl.value+'] default=['+ctrl.defaultValue+']');
    	            break;
    	          }
            }
            else if ((ctrl.type.indexOf ('text') != -1 || ctrl.type == 'password') && ctrl.defaultValue != ctrl.value)
              {
    	        //alert (ctrl.name+' value=['+ctrl.value+'] default=['+ctrl.defaultValue+']');
                dirty = true;
       	        break;
              }
            else if ((ctrl.type == 'checkbox' || ctrl.type == 'radio') &&
    	                ctrl.defaultChecked != ctrl.checked
    	              )
              {
    	           //alert (ctrl.name+' value=['+ctrl.checked+'] default=['+ctrl.defaultChecked+']');
                dirty = true;
                break;
              }
          }
        }
    }

  dirty_force_global=document.getElementById('dirty_force_global');
  if(dirty_force_global != null){
     if(dirty_force_global.value=='true') dirty_force_global = true;
  }else{
     dirty_force_global = false;
  };

  if (dirty_force_global == true ) {
    dirty_force_global = false ;
    dirty = true;
  };

  if (dirty == true)
    {
      ret =
confirm ('You are about to leave the page, but there is changed data which is not saved.\r\nDo you wish to save changes ?');
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


function checkSelected (form, txt, selectionMsq) {
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

function updateState(countryName, stateName, stateValue)
{
  var span = $('span_'+stateName);
  span.innerHTML = "";

  var cc = new OAT.Combolist([], "");
  cc.input.name = stateName;
  cc.input.id = stateName;
  cc.input.style.width = "216px";
  cc.addOption("");

  span.appendChild(cc.div);

  if ($v(countryName) != '')
  {
    var wsdl = "/ods_services/services.wsdl";
    var serviceName = "ODS_USER_LIST";

    var inputObject = {
    	ODS_USER_LIST:{
        pSid:document.forms[0].elements['sid'].value,
        pRealm:document.forms[0].elements['realm'].value,
        pList:'Province',
        pParam:$v(countryName)
    	}
    }
  	var x = function(xml) {
  	  listCallback(xml, cc, stateValue);
  	}
  	OAT.WS.invoke(wsdl, serviceName, x, inputObject);
  }
}

function listCallback (result, cc, objValue)
{
  var xml = OAT.Xml.createXmlDoc(result.ODS_USER_LISTResponse.CallReturn);
	var root = xml.documentElement;
	if (!hasError(root))
	{
    /* options */
  	var items = root.getElementsByTagName("item");
  	if (items.length)
  	{
  		for (var i=1; i<=items.length; i++)
  		{
        cc.addOption(OAT.Xml.textValue(items[i-1]));
  		}
  	}
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

function updateRow (prefix, No, optionObject)
{
  if (No != null)
  {
    OAT.Dom.unlink(prefix+'_tr_'+No);
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
    var No = parseInt($v(prefix+'_no'));
    var tbl = $(prefix+'_tbl');
    if (tbl)
    {
      options = {};
      for (var p in optionObject) {options[p] = optionObject[p]; }

      OAT.Dom.hide (prefix+'_tr_no');

      var tr = OAT.Dom.create('tr');
      tr.id = prefix+'_tr_' + No;
      tbl.appendChild(tr);

      var fldOptions = options.fld1;
      if (fldOptions)
      {
        var td = OAT.Dom.create('td');
        tr.appendChild(td);
        updateCell (td, prefix, '_fld_1_', No, fldOptions)
      }
      var fldOptions = options.fld2;
      if (fldOptions)
      {
        var td = OAT.Dom.create('td');
        tr.appendChild(td);
        updateCell (td, prefix, '_fld_2_', No, fldOptions)
      }

      var fldOptions = options.fld3;
      if (fldOptions)
      {
        var td = OAT.Dom.create('td');
        tr.appendChild(td);
        updateCell (td, prefix, '_fld_3_', No, fldOptions)
      }

      var td = OAT.Dom.create('td');
      tr.appendChild(td);
 		  var fld = OAT.Dom.create("input");
 		  fld.type = 'button';
 		  fld.value = 'Remove';
      fld.onclick = function (){updateRow(prefix, No);};
      td.appendChild(fld);

      $(prefix+'_no').value = No + 1;
    }
  }
}

function updateCell (td, prefix, fldName, No, optionObject)
{
  fldName = prefix + fldName + No;
  if (optionObject.mode == 1)
  {
	  updateRowCombo(td, fldName, optionObject);
	}
  else if (optionObject.mode == 2)
  {
	  updateRowCombo2(td, fldName, optionObject);
  }
  else if (optionObject.mode == 3)
  {
	  updateRowCombo3(td, fldName, optionObject);
  }
  else
  {
	  updateInput(td, fldName, optionObject);
  }
}

function updateInput (elm, fldName, fldOptions)
{
  var fld = OAT.Dom.create("input");
  fld.type = 'text';
  fld.id = fldName;
  fld.name = fld.id;
  if (fldOptions.value)
    fld.value = fldOptions.value;
  fld.className = fldOptions.className;
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
  ["blog.jpg", "http://en.wikipedia.org/wiki/Blog", "Blog"],
  ["brightkite.jpg", "http://brightkite.com/", "brightkite.com"],
  ["feed.jpg", "http://en.wikipedia.org/wiki/Web_feed", "Custom RSS/Atom"],
  ["dailymotion.jpg", "http://www.dailymotion.com/", "Dailymotion"],
  ["delicious.jpg", "http://delicious.com/", "delicious"],
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
  ["googleshared.jpg", "http://www.google.com/s2/sharing/stuff", "Google Shared Stuff"],
  ["identica.jpg", "http://identi.ca/", "identi.ca"],
  ["ilike.jpg", "http://www.ilike.com/", "iLike"],
  ["intensedebate.jpg", "http://www.intensedebate.com/", "Intense Debate"],
  ["jaiku.jpg", "http://www.jaiku.com/", "Jaiku"],
  ["joost.jpg", "http://www.joost.com/", "Joost"],
  ["lastfm.jpg", "http://www.last.fm/", "Last.fm"],
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

var setServiceUrl = function(cc)
  {
    for (N = 0; N < serviceList.length; N = N + 1)
    {
      if (cc.value == serviceList[N][2])
      {
      var urlName = cc.input.name.replace(/fld_1_/, 'fld_2_');
        $(urlName).value = serviceList[N][1];
      }
    }
	}

function updateRowCombo (elm, fldName, fldOptions)
{
  var cc = new OAT.Combolist([], fldOptions.value, {name: fldName, onchange: setServiceUrl});

  cc.input.name = fldName;
  cc.input.id = fldName;
  cc.input.style.width = "90%";
  for (N = 0; N < serviceList.length; N = N + 1)
    updateRowComboOption(cc, serviceList[N][0], serviceList[N][2]);

  var elm = $(elm);
  elm.appendChild(cc.div);
}

function updateRowComboOption (cc, optionImage, optionName)
{
  cc.addOption('<img src="/ods/images/services/'+optionImage+'"/> '+optionName, optionName);
}

function updateRowComboOption2 (elm, elmValue, optionName, optionValue)
{
	var o = OAT.Dom.option(optionName, optionValue, elm);
	if (elmValue == optionValue)
	  o.selected = true;
}

function updateRowCombo2 (elm, fldName, fldOptions)
{
	var cc = OAT.Dom.create("select");
  cc.name = fldName;
  cc.id = fldName;
	updateRowComboOption2(cc, fldOptions.value, "Person URI", "URI");
  updateRowComboOption2(cc, fldOptions.value, "Relationship Property", "Property");
	// updateRowComboOption2(cc, fldOptions.value, "SPARQL", "SPARQL  Expression");

  var elm = $(elm);
  elm.appendChild(cc);
}

function updateRowCombo3 (elm, fldName, fldOptions)
{
	var cc = OAT.Dom.create("select");
  cc.name = fldName;
  cc.id = fldName;
	updateRowComboOption2 (cc, fldOptions.value, "Grant", "G");
	updateRowComboOption2 (cc, fldOptions.value, "Revoke", "R");

  var elm = $(elm);
  elm.appendChild(cc);
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
  var regex = /(ftp|http|https):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?/
  if (!regex.test(fld.value))
    return validateError(fld, 'Invalid URL address');

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
