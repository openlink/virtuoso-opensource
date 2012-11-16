/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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

function showError(msg) {
  alert(msg);
  return false;
}

function findParent(obj, tag) {
  var obj = obj.parentNode;
  if (obj.tagName.toLowerCase() == tag)
    return obj;
  return findParent(obj, tag);
    }

function odsPost(obj, fields, button) {
  var form = findParent (obj, 'form');
  for (var i = 0; i < fields.length; i += 2)
    hiddenCreate(fields[i], form, fields[i+1]);

  if (button) {
    doPost(form.name, button);
  } else {
    form.submit();
  }
}

function toggleControl (ctr1, val, ctr2)
    {
  if (ctr2 != null)
    ctr2.disabled = (ctr1 && ctr1.value == val);
}

function setSelectLists (val, form, pref)
{
  if (val == 0 || form == null || pref == null)
    return;
  for (var i = 0; i < form.elements.length; i++)
    {
      var contr = form.elements[i];
      if (contr != null && contr.type == 'select-one' && contr.name.indexOf (pref) != -1)
          contr.value = val;
        }
    }

function dateFormat(date, format)
{
  function long(d) {
    return ( ( d < 10 )? "0" : "" ) + d;
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
		result = [ parseInt(result[0], 10), parseInt(result[1], 10), parseInt(result[2], 10) ];
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

function selectAllCheckboxes (obj, prefix)
{
  var objForm = obj.form;
  for (var i = 0; i < objForm.elements.length; i++)
  {
    var o = objForm.elements[i];
    if (o != null && o.type == "checkbox" && !o.disabled && (!prefix || o.name.indexOf (prefix) != -1))
      o.checked = (obj.value == 'Select All');
  }
  if (obj.value == 'Select All')
    obj.value = 'Unselect All';
  else
    obj.value = 'Select All';
  obj.focus();
}

var sflag = false;
var def_btn = null;
function checkPageLeave (form)
{
  var dirty = false;
  var ret = true;
  var btn = def_btn;
  if (sflag == true || btn == null || btn == '' || (form.__submit_func && form.__submit_func.value != '') || (form.__event_initiator && form.__event_initiator.value != ''))
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

function readCookie(name) {
	var cookies = document.cookie.split(';');

	for ( var i = 0; i < cookies.length; i++) {
		cookies[i] = cookies[i].trim();

		if (cookies[i].indexOf(name + '=') == 0)
			return cookies[i].substring (name.length + 1, cookies[i].length);
	}
	return false;
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

function hasError(root, showMessage) {
  if (showMessage != false)
    showMessage = true;
	if (!root)
	{
	  if (showMessage)
		alert('No data!');
		return true;
	}

	/* error */
	var error = root.getElementsByTagName('failed')[0];
  if (error)
  {
	    var message = error.getElementsByTagName('message')[0];
    if (message && showMessage)
        alert (OAT.Xml.textValue(message));
  		return true;
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
    	if (stateValue && (stateValue != ''))
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
  def_btn = null;
  if (top.location == self.location)
    return true;
  parent.nav.showUserProfile();
  return false;
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

function hiddenCreate(objName, objForm, objValue) {
  var obj = $(objName);
  if (!obj) {
    obj = OAT.Dom.create("input");
    obj.setAttribute("type", "hidden");
    obj.setAttribute("name", objName);
    obj.setAttribute("id", objName);
    if (!objForm)
      objForm = document.forms[0];
    objForm.appendChild(obj);
  }
  if (objValue)
    obj.setAttribute("value", objValue);
  return obj;
}

function pageFocus(tab) {
  var div = $(tab);
  if (!div)
    return;

  var inputs = div.getElementsByTagName('input');
  for (var i = 0; i < inputs.length; i++)
  {
    var ctrl = inputs[i];
    if ((ctrl.type.indexOf ('text') != -1) || (ctrl.type == 'password')) {
      try {
        ctrl.focus();
      } catch (e) {}
      break;
    }
  }
}

function accountDisable(userName)
{
  var S = '/ods/api/user.disable?name='+encodeURIComponent($v(userName))
        + '&sid=' + document.forms[0].elements['sid'].value
        + '&realm=' + document.forms[0].elements['realm'].value;
	var x = function(data) {
    var xml = OAT.Xml.createXmlDoc(data);
    if (!hasError(xml, false)) {
      alert('User\'s account is disabled!');
      if (parent) {
			  parent.document.location = document.location.protocol + '//' + document.location.host + '/ods';
			} else {
			  document.location = document.location.protocol + '//' + document.location.host + '/ods';
			}
    }
	}
  OAT.AJAX.GET(S, '', x);
}

function destinationChange(obj, changes) {
  function destinationChangeInternal(actions) {
    if (!obj)
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
  }
  if (!changes)
    return;

  if (obj.checked && changes.checked)
    destinationChangeInternal(changes.checked);

  if (!obj.checked && changes.unchecked)
    destinationChangeInternal(changes.unchecked);
}

function swapRows(newIndex)
{
  var row_0 = $('pf_tabs_0_row_' + ((newIndex < 6)? '1': '0'));
  var row_1 = $('pf_tabs_0_row_' + ((newIndex < 6)? '0': '1'));
  if (!row_0.nextElementSibling)
    swapNodes(row_0, row_1);
}

function swapNodes(node1, node2)
{
  if (!node1) return;
  if (!node2) return;
  var tmp = node1.cloneNode(1);
  var parent = node1.parentNode;
  node2 = parent.replaceChild(tmp, node2);
  parent.replaceChild(node2, node1);
  parent.replaceChild(node1, tmp);
  tmp = null;
}

function loginChange(login, register)
{
  var l = $(login);
  var r = $(register);
  if (!l.checked)
    r.checked = false;
}

function registerChange(login, register)
{
  var l = $(login);
  var r = $(register);
  if (r.checked)
    l.checked = true;
}

// RDF Relations
// ---------------------------------------------------------------------------
var rdfDialog
var RDF = new Object();
RDF.tablePrefix = 'r';
RDF.itemTypes = new Object();

RDF.ontologies = new Object();
RDF.ontologies['annotation'] = {"name": 'http://www.w3.org/2000/10/annotation-ns#'};
RDF.ontologies['atom'] = {"name": 'http://atomowl.org/ontologies/atomrdf#'};
RDF.ontologies['book'] = {"name": 'http://purl.org/NET/book/vocab#'};
RDF.ontologies['cc'] = {"name": 'http://web.resource.org/cc/'};
RDF.ontologies['cohere'] = {"name": 'http://cohere.open.ac.uk/ontology/cohere.owl#'};
RDF.ontologies['conf'] = {"name": 'http://www.mindswap.org/~golbeck/web/www04photo.owl#'};
RDF.ontologies['dataview'] = {"name": 'http://www.w3.org/2003/g/data-view#', "hidden": 1};
RDF.ontologies['dc'] = {"name": 'http://purl.org/dc/elements/1.1/', "hidden": 1};
RDF.ontologies['dcterms'] = {"name": 'http://purl.org/dc/terms/', "hidden": 1};
RDF.ontologies['foaf'] = {"name": 'http://xmlns.com/foaf/0.1/'};
RDF.ontologies['frbr'] = {"name": 'http://vocab.org/frbr/core#'};
RDF.ontologies['geo'] = {"name": 'http://www.w3.org/2003/01/geo/wgs84_pos#'};
RDF.ontologies['gr'] = {"name": 'http://purl.org/goodrelations/v1#'};
RDF.ontologies['ibis'] = {"name": 'http://purl.org/ibis#', "hidden": 1};
RDF.ontologies['ical'] = {"name": 'http://www.w3.org/2002/12/cal/icaltzd#'};
RDF.ontologies['kuaba'] = {"name": 'http://www.tecweb.inf.puc-rio.br/ontologies/kuaba'};
RDF.ontologies['lsdis'] = {"name": 'http://lsdis.cs.uga.edu/projects/meteor-s/wsdl-s/ontologies/LSDIS_FInance.owl'};
RDF.ontologies['like'] = {"name": 'http://ontologi.es/like#', "dependent": 'rev'};
RDF.ontologies['mo'] = {"name": 'http://purl.org/ontology/mo/'};
RDF.ontologies['movie'] = {"name": 'http://www.csd.abdn.ac.uk/~ggrimnes/dev/imdb/IMDB#'};
RDF.ontologies['nao'] = {"name": 'http://www.semanticdesktop.org/ontologies/nao/'};
RDF.ontologies['nco'] = {"name": 'http://www.semanticdesktop.org/ontologies/nco/'};
RDF.ontologies['nfo'] = {"name": 'http://www.semanticdesktop.org/ontologies/nfo/'};
RDF.ontologies['nid3'] = {"name": 'http://www.semanticdesktop.org/ontologies/nid3/'};
RDF.ontologies['nie'] = {"name": 'http://www.semanticdesktop.org/ontologies/nie/'};
RDF.ontologies['nmo'] = {"name": 'http://www.semanticdesktop.org/ontologies/nmo/'};
RDF.ontologies['opo'] = {"name": 'http://ggg.milanstankovic.org/opo/ns/'};
RDF.ontologies['owl'] = {"name": 'http://www.w3.org/2002/07/owl#'};
RDF.ontologies['rdf'] = {"name": 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', "hidden": 1};
RDF.ontologies['rdfs'] =
  {
    "name": 'http://www.w3.org/2000/01/rdf-schema#',
    "hidden": 1,
    "classes":
    [
      {
        "name": 'rdfs:Class',
        properties:
        [
          {"name": 'dc:contributor', "datatypeProperties": 'rdfs:string'},
          {"name": 'dc:coverage', "datatypeProperties": 'rdfs:string'},
          {"name": 'dc:creator', "datatypeProperties": 'rdfs:string'},
          {"name": 'dc:date', "datatypeProperties": 'rdfs:string'},
          {"name": 'dc:description', "datatypeProperties": 'rdfs:string'},
          {"name": 'dc:format', "datatypeProperties": 'rdfs:string'},
          {"name": 'dc:identifier', "datatypeProperties": 'rdfs:string'},
          {"name": 'dc:language', "datatypeProperties": 'rdfs:string'},
          {"name": 'dc:publisher', "datatypeProperties": 'rdfs:string'},
          {"name": 'dc:relation', "datatypeProperties": 'rdfs:string'},
          {"name": 'dc:rights', "datatypeProperties": 'rdfs:string'},
          {"name": 'dc:source', "datatypeProperties": 'rdfs:string'},
          {"name": 'dc:subject', "datatypeProperties": 'rdfs:string'},
          {"name": 'dc:title', "datatypeProperties": 'rdfs:string'},
          {"name": 'dc:type', "datatypeProperties": 'rdfs:string'},
          {"name": 'owl:sameAs', "objectProperties": 'owl:Thing'},
          {"name": 'rdfs:comment', "datatypeProperties": 'rdfs:string'},
          {"name": 'rdfs:label', "datatypeProperties": 'rdfs:string'},
          {"name": 'rdfs:seeAlso', "objectProperties": 'rdfs:Resource'}
        ]
}
    ]
  };
RDF.ontologies['rev'] = {"name": 'http://purl.org/stuff/rev#'};
RDF.ontologies['rss'] = {"name": 'http://purl.org/rss/1.0/'};
RDF.ontologies['scot'] = {"name": 'http://scot-project.org/scot/ns'};
RDF.ontologies['sioc'] = {"name": 'http://rdfs.org/sioc/ns#'};
RDF.ontologies['sioct'] = {"name": 'http://rdfs.org/sioc/types#'};
RDF.ontologies['skos'] = {"name": 'http://www.w3.org/2008/05/skos#'};
RDF.ontologies['vs'] = {"name": 'http://www.w3.org/2003/06/sw-vocab-status/ns#'},
RDF.ontologies['wot'] = {"name": 'http://xmlns.com/wot/0.1/', "hidden": 1};
RDF.ontologies['xhtml'] = {"name": 'http://www.w3.org/1999/xhtml', "hidden": 1};
RDF.ontologies['xsd'] = {"name": 'http://www.w3.org/2001/XMLSchema#', "hidden": 1};

RDF.loadOntology = function (ontologyName, cb, options)
{
  var ontology = this.getOntologyByName(ontologyName);
  var prefix = this.ontologyPrefix(ontologyName);
  if (!prefix) {
    var N = 0;
    while (true) {
      prefix = 'ns' + N;
      if (!RDF.getOntologyByPrefix(prefix))
        break;
      N++;
    }
  }

  // load ontology classes
  var S = '/ods/api/ontology.classes?ontology='+encodeURIComponent(ontologyName)+ '&prefix='+encodeURIComponent(prefix);
  var dependent;
  if (ontology && ontology.dependent) {
    dependent = ontology.dependent;
    S += '&dependentOntology='+encodeURIComponent(this.getOntologyByPrefix(dependent).name);
  }
  var x = function(data) {
    var o = null;
    try {
      o = OAT.JSON.parse(data);
    } catch (e) {o = null;}
    if (o)
    {
      o.prefix = prefix;
      o.dependent = dependent;
      RDF.ontologies[prefix] = o;

      // load objects (individuals)
      var S = '/ods/api/ontology.objects?ontology='+encodeURIComponent(ontologyName)+'&prefix='+prefix;
      var x = function(data) {
        var o = null;
        try {
          o = OAT.JSON.parse(data);
        } catch (e) {o = null;}
        RDF.ontologies[prefix].objects = o;
      }
      OAT.AJAX.GET(S, '', x, {});
      if (o.dependent)
        RDF.loadOntology(RDF.getOntologyByPrefix(o.dependent).name, null, {async: false});
    }
    if (cb) {cb();}
  }
  OAT.AJAX.GET(S, '', x, options);
}

RDF.getOntologyByPrefix = function(prefix)
{
  return RDF.ontologies[prefix];
}

RDF.getOntologyByName = function(ontologyName)
{
  var prefix = this.ontologyPrefix(ontologyName);
  return this.ontologies[prefix];
}

RDF.getOntologyByClass = function(className)
{
  var prefix = this.extractPrefix(className);
  return this.ontologies[prefix];
}

RDF.getOntologyClass = function(className)
{
  var ontology = this.getOntologyByClass(className);
  if (ontology) {
    var classes = ontology.classes;
    for (var i = 0; i < classes.length; i++) {
      if (classes[i].name == className)
        return classes[i];
    }
  }
  return null;
}

RDF.getOntologyClassProperty = function(className, propertyName)
{
	if (className instanceof Array) {
		for (var i=0;i<className.length;i++) {
		  var property = this.getOntologyClassProperty(className[i], propertyName);
		  if (property)
		    return property;
		}
	} else {
  var ontologyClass = this.getOntologyClass(className);
    if (ontologyClass) {
    var properties = ontologyClass.properties;
      for (var i = 0; i < properties.length; i++) {
      if (properties[i].name == propertyName)
        return properties[i];
    }

      if (ontologyClass.subClassOf instanceof Array)
        for (var i=0; i<ontologyClass.subClassOf.length; i++) {
          var property = this.getOntologyClassProperty(ontologyClass.subClassOf[i], propertyName);
          if (property)
            return property;
        }
  }
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
  if (!ontologyClassName) {return null;}

  var N = ontologyClassName.indexOf(':');
  if (N == -1) {return null;}

  return ontologyClassName.substring(0, N);
}

RDF.isKindOfClass = function(objectClassName, propertyClassName)
{
  if (objectClassName == propertyClassName)
    return true;

  var ontologyClass = this.getOntologyClass(objectClassName);
  if (ontologyClass && (ontologyClass.subClassOf instanceof Array))
    for (var i = 0; i < ontologyClass.subClassOf; i++) {
      if (this.hasClassProperties(ontologyClass.subClassOf[i]))
        return true;
    }

  return false;
}

RDF.loadClassProperties = function(ontologyClass, cbFunction)
{
  if (ontologyClass.properties) {
    cbFunction();
    return;
  }
  var ontologyName = RDF.getOntologyByClass(ontologyClass.name).name;
  var prefix = RDF.ontologyPrefix(ontologyName);
  var S = '/ods/api/ontology.classProperties?ontology='+encodeURIComponent(ontologyName)+'&prefix='+prefix+'&ontologyClass='+encodeURIComponent(ontologyClass.name);
  var x = function(data) {
    var o = null;
    try {
      o = OAT.JSON.parse(data);
    } catch (e) { o = null; }
    ontologyClass.properties = o;
    if (ontologyClass.subClassOf instanceof Array) {
      for (var i = 0; i < ontologyClass.subClassOf.length; i++) {
        var ontologySubClass = RDF.getOntologyClass(ontologyClass.subClassOf[i]);
    if (ontologySubClass) {
      RDF.loadClassProperties(ontologySubClass, cbFunction)
          cbFunction = null;
        }
    }
    }
    if (cbFunction)
    cbFunction();
  }
  OAT.AJAX.GET(S, '', x, {});
}

RDF.hasClassProperties = function(className)
{
	if (className instanceof Array) {
		for (var i=0;i<className.length;i++) {
		  var hasProperties = this.hasClassProperties(className[i]);
		  if (hasProperties)
		    return true;
		}
	} else {
    var ontologyClass = this.getOntologyClass(className);
    if (!ontologyClass)
      return false;

    if (ontologyClass.properties.length)
      return true;

    if (ontologyClass.subClassOf instanceof Array)
      for (var i = 0; i < ontologyClass.subClassOf.length; i++) {
        if (this.hasClassProperties(ontologyClass.subClassOf[i]))
          return true;
      }
  }
  return false;
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
RDF.showRDF = function(prefix, format)
{
  function preparePropertiesWork(prefix, ontologyNo, itemNo) {
    var form = document.forms['page_form'];
    var itemProperties = [];
    for (var L = 0; L < form.elements.length; L++) {
      if (!form.elements[L])
        continue;

      var ctrl = form.elements[L];
      if (typeof(ctrl.type) == 'undefined')
        continue;

      if (ctrl.name.indexOf(prefix+"_item_"+ontologyNo+"_prop_"+itemNo+"_fld_1_") != 0)
        continue;

      var propertyNo = ctrl.name.replace(prefix+"_item_"+ontologyNo+"_prop_"+itemNo+"_fld_1_", "");
      var propertyName = ctrl.value;
      var propertyType = $v(prefix+"_item_"+ontologyNo+"_prop_"+itemNo+"_fld_2_"+propertyNo);
      var propertyValue = $v(prefix+"_item_"+ontologyNo+"_prop_"+itemNo+"_fld_3_"+propertyNo);
      var propertyLanguage = $v(prefix+"_item_"+ontologyNo+"_prop_"+itemNo+"_fld_4_"+propertyNo);
      if (propertyType == 'object') {
        var item = RDF.getItemByName(propertyValue);
        if (item)
          propertyValue = item.id;
      }
      itemProperties.push({"name": propertyName, "value": propertyValue, "type": propertyType, "language": propertyLanguage});
    }
    return itemProperties;
  }

  var L = 0;
  var form = document.forms['page_form'];
  var ontologies = [];
  for (var N = 0; N < form.elements.length; N++)
  {
    if (!form.elements[N])
      continue;

    var ctrl = form.elements[N];
    if (typeof(ctrl.type) == 'undefined')
      continue;

    if (ctrl.name.indexOf(prefix+"_fld_2_") != 0)
      continue;

    var ontologyNo = ctrl.name.replace(prefix+"_fld_2_", "");
    var ontologyName = ctrl.value;
    var ontologyItems = [];
    for (var M = 0; M < form.elements.length; M++)
    {
      if (!form.elements[M])
        continue;

      var ctrl = form.elements[M];
      if (typeof(ctrl.type) == 'undefined')
        continue;

      if (ctrl.name.indexOf(prefix+"_item_"+ontologyNo+"_fld_2_") != 0)
        continue;

      var itemNo = ctrl.name.replace(prefix+"_item_"+ontologyNo+"_fld_2_", "");
      var itemName = ctrl.value;
      var itemProperties = preparePropertiesWork(prefix, ontologyNo, itemNo);
      ontologyItems.push({"id": itemNo, "className": itemName, "properties": itemProperties});
    }
    ontologies.push({"id": ''+L++, "ontology": ontologyName, "items": ontologyItems});
  }
  var items = OAT.JSON.stringify(ontologies);
	var x = function(data) {
    if (!rdfDialog) {
      rdfDialog = new OAT.Dialog("Show Data", "rdfDiv", {width: 800, height: 500, resize: 0, modal: 1, buttons: 1});
      OAT.Dom.show('rdfDiv');
    }
    $('rdfData').innerHTML = data;
		rdfDialog.show();
	}
  OAT.AJAX.GET('/ods/api/objects.rdf', 'items='+encodeURIComponent(items)+'&format='+format, x);
}

// Item Types functions
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
    OAT.Dom.unlink(prefix+'_throbber');
    OAT.Dom.show(noTR);
  }
}

RDF.showItemType = function(prefix, itemType)
{
  // hide throbber
  OAT.Dom.unlink(prefix+'_throbber');

  var rowOptions = {No: itemType.id, fld_1: {mode: 43, cssText: ''}, fld_2: {mode: 42, value: itemType.ontology, showValue: itemType.ontology+' ('+RDF.ontologyPrefix(itemType.ontology)+')'}, btn_1: {mode: 40}};
  if (this.tableOptions && this.tableOptions.itemType) {
    var itemTypeOptions = this.tableOptions.itemType;
    for (var p in rowOptions) {
      if (itemTypeOptions[p]) {
        for (var q in itemTypeOptions[p]) {
          if (itemTypeOptions[p][q]) {
            rowOptions[p][q] = itemTypeOptions[p][q];
          }
        }
      }
    }
  }
  TBL.createRow(prefix, null, rowOptions);
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
  if (fValue == '') {return alert ('Please select an Item!');}

  for (var i = 0; i < this.itemTypes.length; i++)
    if (this.itemTypes[i].ontology == fValue)
      return alert ('This type already exists. Please enter another value!');

  OAT.Dom.show(fld1);
  var td = $(prefix+'_td_'+No+'_2');
  if (!td) {return;}

  // create and add new item object
    var itemType = new Object();
    itemType.ontology = fValue;
    itemType.id = No;
  this.loadOntology(itemType.ontology, function() {
    // add item object
    RDF.itemTypes[RDF.itemTypes.length] = itemType;
    // clear childs
    td.innerHTML = '';

    // add hidden item
  td.appendChild(fld2);
  OAT.Dom.hide(fld2);

    // show combo value as text
    td.appendChild(OAT.Dom.text(fValue+' ('+RDF.ontologyPrefix(fValue)+')'));

	OAT.Dom.hide(prefix+'_btn_2_'+No);
    fld1.onclick();
	});
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
    obj.src = '/ods/images/icons/orderup_16.png';
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
    obj.src = '/ods/images/icons/orderdown_16.png';
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

    var fld = OAT.Dom.create('span');
    fld.title = 'Add Element';
    fld.onclick = function(){var id = RDF.newItemId(); TBL.createRow(prefixItem, null, {No: id, fld_1: {mode: 45, cssText: 'display: none;'}, fld_2: {mode: 44, itemType: itemType, labelValue: 'New Item: '}, btn_1: {mode: 42}, btn_2: {mode: 43}});};
    OAT.Dom.addClass(fld, 'button pointer');

    var img = OAT.Dom.create('img');
    img.src = '/ods/images/icons/add_16.png';
    img.alt = 'Add Element';
    img.title = img.alt;
    OAT.Dom.addClass(img, 'button');

    fld.appendChild(img);
    fld.appendChild(OAT.Dom.text(' Add'));
    TDs[2].style.whiteSpace = 'nowrap';
    TDs[2].appendChild(fld);

    var S = '<table id="item_tbl" class="listing" style="background-color: #F5F5EE;"><thead><tr class="listing_header_row"><th><div style="width: 16px;"><![CDATA[&nbsp;]]></div></th><th width="100%">Item</th><th width="80px">Action</th></tr></thead><tbody id="item_tbody"><tr id="item_tr_no"><td></td><td colspan="2"><b><i>No Items</i></b></td></tr></tbody></table><input type="hidden" id="item_no" name="item_no" value="0" />';
    TDs[1].innerHTML = S.replace(/item_/g, prefixItem+'_');

    var items = itemType.items;
    if (items)
    {
      for (var i = 0; i < items.length; i++)
        this.showItem(prefixItem, items[i]);
    } else {
      fld.onclick();
    }
  } else {
    TDs[1].innerHTML = '<b><i>Ontology has no elements</i></b>';
  }
}

RDF.showItem = function(prefix, item)
{
  TBL.createRow(prefix, null, {No: item.id, fld_1: {mode: 45, item: item}, fld_2: {mode: 42, value: item.className, showValue: item.className+' (#'+item.id+')'}, btn_1: {mode: 42}});
  if (item.properties)
  {
    var obj = $(prefix+'_fld_1_'+item.id);
    this.showProperties(obj, prefix, item.id)
  }
}

RDF.newItemId = function()
  {
  var id = 0;
  for (var i = 0; i < this.itemTypes.length; i++) {
    var items = this.itemTypes[i].items;
    if (items)
    {
      for (var j = 0; j < items.length; j++)
      {
        if (parseInt(items[j].id) > id)
          id = parseInt(items[j].id);
      }
    }
  }
  return id+1;
}

RDF.getItem = function(No)
{
  for (var i = 0; i < this.itemTypes.length; i++) {
    var items = this.itemTypes[i].items;
    if (items) {
      for (var j = 0; j < items.length; j++) {
        if (items[j].id == No)
          return items[j];
      }
    }
  }
  return null;
}

RDF.getItemByName = function(name)
{
  for (var i = 0; i < this.itemTypes.length; i++) {
    var items = this.itemTypes[i].items;
    if (items) {
      for (var j = 0; j < items.length; j++) {
        if (RDF.getItemName(items[j]) == name)
          return items[j];
      }
    }
  }
  return null;
}

RDF.getItemName = function(item)
{
  return item.className+' (#'+item.id+')'
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
    return alert ('Please select an Item!');

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
  var ontologyClass = this.getOntologyClass(item.className);
  this.loadClassProperties(ontologyClass, function(){fld1.onclick();});

    // clear childs
    td.innerHTML = '';

    // add hidden item
  td.appendChild(fld2);
  OAT.Dom.hide(fld2);

    // show combo value as text
  var fld = OAT.Dom.text(fValue+' (#'+item.id+')');
    td.appendChild(fld);

    // update selectors
    RDF.addItemToSelects(item);

	OAT.Dom.hide(prefix+'_btn_2_'+No);
}

RDF.addItemToSelects = function(item)
{
  var tbl = $(this.tablePrefix+'_tbl');
  if (!tbl) {return;}

  var combolists = tbl.getElementsByTagName('input');
  if (!combolists) {return;}
  for (var i = 0; i < combolists.length; i++) {
    var obj = combolists[i];
    if ((obj.id.indexOf('_prop_') != -1) && (obj.id.indexOf('_fld_1_') != -1) && (obj.value != ''))
    {
      var ontologyClassProperty = this.getOntologyClassProperty(obj.item.className, obj.value);
      if (ontologyClassProperty.objectProperties)
      {
        for (var j = 0; j < ontologyClassProperty.objectProperties.length; j++)
        {
          if (item.className == ontologyClassProperty.objectProperties[j])
          {
      	    var fld = $(obj.id.replace(/_fld_1_/, '_fld_3_'));
            if (fld && fld.combolist)
              fld.combolist.addOption(RDF.getItemName(item));
    	    }
        }
      }
    }
  }
}

RDF.checkItemInSelects = function(item)
{
  return RDF.itemInSelects(item, 'check');
}

RDF.removeItemInSelects = function(item)
{
  return RDF.itemInSelects(item, 'remove');
}

RDF.itemInSelects = function(item, mode)
{
  var tbl = $(this.tablePrefix+'_tbl');
  if (!tbl) {return;}

  var combolists = tbl.getElementsByTagName('input');
  if (!combolists) {return;}
  for (var i = 0; i < combolists.length; i++) {
    var obj = combolists[i];
    if ((obj.id.indexOf('_prop_') != -1) && (obj.id.indexOf('_fld_1_') != -1) && (obj.value != '')) {
      var ontologyClassProperty = this.getOntologyClassProperty(obj.item.className, obj.value);
      if (ontologyClassProperty.objectProperties) {
        for (var j = 0; j < ontologyClassProperty.objectProperties.length; j++) {
          if (item.className == ontologyClassProperty.objectProperties[j]) {
      	    var fld = $(obj.id.replace(/_fld_1_/, '_fld_3_'));
            if (fld && fld.combolist) {
              if ((fld.value == RDF.getItemName(item)) && (mode == 'check'))
                    return confirm ('The selected object is used. Delete?');
              if (mode == 'remove') {
                if (fld.value == RDF.getItemName(item))
                  fld.value = '';
                var list = fld.combolist.list;
                for (var l = 0; l < list.children.length; l++) {
                  if (list.children[l].value == RDF.getItemName(item))
      	            OAT.Dom.unlink(list.children[l]);
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
    obj.src = '/ods/images/icons/orderup_16.png';
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
    obj.src = '/ods/images/icons/orderdown_16.png';
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
    if (this.hasClassProperties(ontologyClass.name))
    {
      var prefixProp = prefix + '_prop_' + No;

      var fld = OAT.Dom.create('span');
      fld.title = 'Add Property';
      fld.onclick = function(){TBL.createRow(prefixProp, null, {fld_1: {mode: 46, item: item}, fld_2: {mode: 48, item: item}, fld_3: {mode: 47, item: item}, fld_4: {mode: 49, item: item}});};
      OAT.Dom.addClass(fld, 'button pointer');

      var img = OAT.Dom.create('img');
      img.src = '/ods/images/icons/add_16.png';
      img.alt = 'Add Property';
      img.title = img.alt;
      OAT.Dom.addClass(img, 'button');

      fld.appendChild(img);
      fld.appendChild(OAT.Dom.text(' Add'));
      TDs[2].style.whiteSpace = 'nowrap';
      TDs[2].appendChild(fld);

      var S = '<table id="prop_tbl" class="listing" style="background-color: #FFF;"><thead><tr class="listing_header_row"><th width="50%">Property IRI</th><th width="50%" colspan="3">Value</th><th width="80px">Action</th></tr></thead><tbody id="prop_tbody"><tr id="prop_tr_no"><td colspan="3">No Properties</td></tr></tbody></table><input type="hidden" id="prop_no" name="prop_no" value="0" />';
      TDs[1].innerHTML = S.replace(/prop_/g, prefixProp+'_');

      var properties = item.properties;
      if (properties)
      {
        for (var i = 0; i < properties.length; i++)
          TBL.createRow(prefixProp, null, {fld_1: {mode: 46, item: item, value: properties[i]}, fld_2: {mode: 48, item: item, value: properties[i]}, fld_3: {mode: 47, item: item, value: properties[i]}, fld_4: {mode: 49, item: item, value: properties[i]}});
      } else {
        fld.onclick();
      }
    } else {
      TDs[1].innerHTML = '<b><i>class has no properties</i></b>';
    }
  }
}

RDF.changePropertyValue = function(obj)
{
  var fld = obj.input;
  var fldTd = findParent(fld, 'td');
  var S = fldTd.id;

  var fldName = (fld.id).replace(/fld_1/, 'fld_2');
  var td = $(S.substr(0,S.lastIndexOf('_')+1)+'2');
  TBL.createCell48(td, '', fldName, 0, {item: fld.item, value: {name: fld.value}});

  var fldName = (fld.id).replace(/fld_1/, 'fld_3');
  var td = $(S.substr(0,S.lastIndexOf('_')+1)+'3');
  TBL.createCell47(td, '', fldName, 0, {item: fld.item, value: {name: fld.value}});

  var fldName = (fld.id).replace(/fld_1/, 'fld_4');
  var td = $(S.substr(0,S.lastIndexOf('_')+1)+'4');
  TBL.createCell49(td, '', fldName, 0, {item: fld.item, value: {name: fld.value}});
}
