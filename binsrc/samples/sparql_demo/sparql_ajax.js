/*
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
 *  
*/

function init()
{
  OAT.Preferences.windowTypeOverride = 1;
  
  tab = new OAT.Tab ("main_col");
  tab.add ("tab_home","page_home");
  tab.add ("tab_query","page_query");
  tab.add ("tab_dawg","page_dawg");
  tab.add ("tab_import_data","page_import_data");
//  tab.add ("tab_query_remote","page_query_remote");
	$('load').checked = true;
  tab.go (go_to); /* is 0-based index... */

  var sr_cl = new OAT.Combolist([],"http://demo.openlinksw.com/sparql");
  sr_cl.input.name = "service";
  sr_cl.input.id = "service";
  sr_cl.img.src = "images/cl.gif";
  $("sr_cl_div").appendChild(sr_cl.div);
  sr_cl.addOption("http://demo.openlinksw.com/sparql");
  sr_cl.addOption("http://xmlarmyknife.org/api/rdf/sparql/query");
  sr_cl.addOption("http://www.sparql.org/sparql");
  sr_cl.addOption("http://www.govtrack.us/sparql");

  OAT.Tree.assign("tree_content","images","gif",true);

  filewin = new OAT.Window({close:1,min:0,max:0,x:450,y:155,width:500,height:400,title:"View File",imagePath:"images/"});
  filewin.content.appendChild($("file_window_content"));
  filewin.div.style.zIndex = 1010;
  document.body.appendChild(filewin.div);
  OAT.Dom.hide(filewin.div);
  filewin.onclose = function() { OAT.Dom.hide(filewin.div); }
  
	OAT.WebDav.init(Array());
	
	OAT.Dom.hide($('remote_panel'));
	//switch_panels();

  var ref=function() { 
    if (OAT.Dom.style($('tree_containter'),'display') == 'none')
      OAT.Dom.show($('tree_containter'));
    else 
      OAT.Dom.hide($('tree_containter'));
  }
  OAT.Dom.attach($('tab_dawg'),"click",ref);
}

function switch_panels()
{
  if ($v('remote') == 'y')
  {
  	OAT.Dom.show($('remote_panel'));
  	OAT.Dom.hide($('local_panel'));
  }
  else
  {
  	OAT.Dom.hide($('remote_panel'));
  	OAT.Dom.show($('local_panel'));
  }
  
    
}
function view_file(path,fname,data)
{
  if (!path)
  {
    path = $v('default-graph-uri');
  }
  path = path.replace('http://local.virt','');
  
  OAT.Dom.show(filewin.div);
  var response = function(data) { 
    var content = data.replace(/</g,'&lt;');
    $('file_window_content').innerHTML = '<pre>' + content + '</pre>'; 
    return false;
  };
  if (data != undefined)
    response(data);
  else
  {
    $('file_window_content').innerHTML = 'Loading data please wait ....';
	  OAT.Ajax.command(OAT.Ajax.GET, path, function(){return '';}, response,OAT.Ajax.TYPE_TEXT);
	}
}

function open_dav()
{
	var options = {
		mode:'open_dialog',
		user:'',
		pass:'',
		pathDefault:"/DAV/sparql_demo/data/",
		imagePath:'images/',
		imageExt:'gif',
		toolbar:{new_folder:false},
    onOpenClick:view_file
  };
	OAT.WebDav.open(options);
}

function load_dawg(list,item)
{
  tab.go (2);
  $('dawg_content').innerHTML = 'Loading data ...';
  var callback = function(data) {
    var ch = data.firstChild.childNodes;
    var queryuri = '';
    var query = '';
    var default_graph_uri = '';
    var data = '';
    var comment = '';
    var etalonuri = '';
    var etalon = '';
    for(var i = 0; i < ch.length; i++)
    {
      if (ch[i].nodeName == 'queryuri')
        queryuri = ch[i].firstChild.nodeValue;
      else if (ch[i].nodeName == 'query')
        query = ch[i].firstChild.nodeValue;
      else if (ch[i].nodeName == 'default-graph-uri')
        default_graph_uri = ch[i].firstChild.nodeValue;
      else if (ch[i].nodeName == 'data')
        data = ch[i].firstChild.nodeValue;
      else if (ch[i].nodeName == 'comment')
        comment = (ch[i].firstChild)?ch[i].firstChild.nodeValue:'';
      else if (ch[i].nodeName == 'etalonuri')
        etalonuri = ch[i].firstChild.nodeValue;
      else if (ch[i].nodeName == 'etalon')
      {
        etalon = ch[i].firstChild.nodeValue;
      }
      }
    
    $('dawg_content').innerHTML = '<h2>' + decodeURIComponent(item).replace(/\+/g,' ') +'</h2>';
    $('dawg_content').innerHTML +='<p>' + comment +'</p>';
    $('dawg_content').innerHTML +='<h3>Data</h3>';
    $('dawg_content').innerHTML +='<p><a href="#" id="dawg_dgu" onclick="view_file(\'' + default_graph_uri + '\')">' + default_graph_uri + '</a><br></p>';
    if (data)
      $('dawg_content').innerHTML +='<div class="query">' + data.replace(/&/g,'&amp;').replace(/</g,'&lt;') + '</div>';
    $('dawg_content').innerHTML +='<h3>Query</h3>';
    $('dawg_content').innerHTML +='  <a href="#" onclick="view_file(\'' + queryuri + '\')">' + queryuri + '</a><br>';
    $('dawg_content').innerHTML +='<div class="query" id="dawg_query">' + query.replace(/&/g,'&amp;').replace(/</g,'&lt;') + '</div>';
    $('dawg_content').innerHTML +='<h3>Results</h3>';
    $('dawg_content').innerHTML +='<p><a href="#" onclick="view_file(\'' + etalonuri + '\')">' + etalonuri + '</a></p>';
    $('dawg_content').innerHTML += '<div id="dawg_etalon">' + etalon + '</div>';

  };
  OAT.Ajax.command(OAT.Ajax.GET, "./sparql_ajax.vsp?list=" + list + "&case=" + item, function(){return '';}, callback, OAT.Ajax.TYPE_XML);
}
function load_dawg_query()
{
  if (!$('dawg_query') || !$('dawg_query').innerHTML)
  {
    alert('Please select DAWG use case from the tree on the left first!');
    return;
    }
  tab.go(1);
  $('query').value = $('dawg_query').innerHTML.replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&amp;/g,'&');
  $('default-graph-uri').value = $('dawg_dgu').innerHTML;
  $('etalon').innerHTML = '<hr/><b>Expected result:</b>' + $('dawg_etalon').innerHTML;

  $('format').selectedIndex = 0; 
  $('result').innerHTML = ''; 

  var table = find_child_element($('etalon'),'table');
    if (table)
    { 
    $('etalon').innerHTML += '<div id="grid_etalon"></div>'; 
    table = find_child_element($('etalon'),'table');
      var grid = new OAT.Grid("grid_etalon",0);
      load_grid(grid,table);
      table.parentNode.removeChild(table);
    }
    else
    {
    $('etalon').innerHTML += '<pre>' + data.replace(/</g,'&lt;') + '</pre>';
    }
  //OAT.Dom.hide($('tree_containter'));
}

function get_r(){
  //if ($('tab_query_remote').className.match('tab_selected'))
  //  return 'r_';
  //else
    return '';
}
function is_r()
{
  if($v('remote') == 'y')
    return true;
  else 
    return false;
};

function format_change()
{
  $(get_r()+'etalon').innerHTML = ''; 
}

function find_child_element(data,node)
{
  if (data.nodeName == node.toUpperCase())
  {
    return data;
  }else
  {
    if (data.childNodes)
    {
      for(var i = 0;i < data.childNodes.length;i++)
      {
        var child = find_child_element(data.childNodes[i],node);
        if (child)
          return child;
      }
    }
    else
      return null;
  }
  return null;
}

function load_grid(grid,table){
  for(var i = 0;i < table.rows.length;i++)
  {
    var row = table.rows[i];
    var cells = Array();
    for(var n = 0;n < row.cells.length;n++)
    {
      if (i == 0)
        cells.push({value:row.cells[n].innerHTML.replace(/<PRE>/ig,'').replace(/<\/PRE>/ig,''),align:OAT.GridData.ALIGN_CENTER});
      else
        cells.push(row.cells[n].innerHTML.replace(/<PRE>/ig,'').replace(/<\/PRE>/ig,''));
    }
    if (i == 0)
      grid.createHeader(cells);
    else
      grid.createRow(cells);
  }
};

function rq_query(param,dl)
{
  if (!dl) dl = 0; // init data loading
  if (!is_r() && !param && !dl) //if data is not loaded we try to load it first.
  {
    load_data(param);
    return;
  };
    
  var r = get_r();
  if (is_r() && $v(r+'service') == '')
  {
    alert('You must specify "Query Service Endpoint"!');
    return;
  }
  if (param == 'c')
    $(r+'etalon').innerHTML = '';
  $(r+'res_area').innerHTML = 'Sending query...';

  var format = $v('format');
  if (!format) format = 'text/html';

  var body = function()
  {
    var body = '';
    var params = ['default-graph-uri','query','format'];
    if (param == 'c')
      params.push('explain');
    if (is_r())
      params.push('service');
    else
      ;//params.push('load');
    for(var i = 0; i < params.length; i++)
    {
      if (body != '') 
        body += '&'; 
      if (!(params[i] == 'default-graph-uri' && $v('default-graph-uri') == '')) // Patch ot skip default graph if it is empty;
      {
        body += params[i] + '=';
        if ($(r+params[i]).type == 'radio')
        {
          for(var n = 0; n < $(r+params[i]).form.elements[$(r+params[i]).name].length;n++)
            if ($(r+params[i]).form.elements[$(r+params[i]).name][n].checked)
              body += encodeURIComponent($(r+params[i]).form.elements[$(r+params[i]).name][n].value); 
        }
        else
          body += encodeURIComponent($v(r+params[i])); 
      }
    }
    return body;
  };
  //OAT.Ajax.httpError=0;
  OAT.Ajax.errorRef = function(status,response,xmlhttp)
  {
    callback(response,xmlhttp);
  }
  var callback = function(data,xmlhttp) 
  { 
    $(r+'res_area').innerHTML = '';
    var tabres_html = '';
    tabres_html += '<ul id="tabres">';
    tabres_html += '<li id="tabres_result">result</li><li id="tabres_request">request</li><li id="tabres_response">response</li>';
    if (dl)
      tabres_html += '<li id="tabres_autoload">data load result</li>';
    tabres_html += '</ul>';
    tabres_html += '<div id="res_container"></div>';
    tabres_html += '<div id="result">' + data + '</div>';
    if (dl)
      tabres_html += '<div id="autoload">' + dl + '</div>';
    $(r+'res_area').innerHTML += tabres_html;
    
    var body_str = body();
    var request = '';
    request += '<div id="request"><pre>';
    request += 'POST ' + endpoint + ' HTTP 1.1\r\n';
    request += 'Host: ' + window.location.host + '\r\n';
    request += 'Accept: ' + format + '\r\n';
    request += 'Content-Type: application/x-www-form-urlencoded' + '\r\n';
    request += 'Content-Length: ' + body_str.length + '\r\n';
    request += '\r\n';
    request += body_str;
    request += '</pre></div>'; 
    $(r+'res_area').innerHTML += request; 

    var response = '';
    response += '<div id="response"><pre>';
    response += xmlhttp.obj.getAllResponseHeaders();
    response += '\r\n';
    response += data.replace(/&/g,'&amp;').replace(/</g,'&lt;');
    response += '</pre></div>'; 
    $(r+'res_area').innerHTML += response; 

    var tabres = new OAT.Tab ("res_container");
    tabres.add ("tabres_result","result");
    tabres.add ("tabres_request","request");
    tabres.add ("tabres_response","response");
    if (dl)
      tabres.add ("tabres_autoload","autoload");
    tabres.go(0);

    var table = find_child_element($(r+'result'),'table');
    if (table && $(r+'format').selectedIndex == 0 && param != 'c')
    {
      $(r+'result').innerHTML += '<div id="grid"></div>'; 
      table = find_child_element($(r+'result'),'table');
      var grid = new OAT.Grid("grid",0);
      load_grid(grid,table);
      table.parentNode.removeChild(table);
    }
    else
    {
      if (!is_r() && !param)
        $(r+'result').innerHTML = '<pre>' + data.replace(/</g,'&lt;') + '</pre>';
      else
        $(r+'result').innerHTML = data;
    }

  };
  //if (!is_r() && !param && $('local_sparql').checked)
  //if (!is_r() && !param)
  //  OAT.Ajax.command(OAT.Ajax.POST, "/sparql/?", body, callback, OAT.Ajax.TYPE_TEXT);
  //else
  
  var endpoint = '';
  if (!is_r() && !param)
  {
    //load_data(param);
    endpoint = '/sparql/?'
  } else
    endpoint = window.location.pathname;
  
  OAT.Ajax.command(OAT.Ajax.POST, endpoint, body, callback, OAT.Ajax.TYPE_TEXT,{'Accept':format});
}

function load_data(param)
{
  if ($('load_never').checked == false)
  {
    $('res_area').innerHTML = 'Request data loading...';
    var ldbody = function()
    {
      var body = '';

      body += 'load=';
      for(var n = 0; n < $('load').form.elements['load'].length;n++)
        if ($('load').form.elements['load'][n].checked)
          body += encodeURIComponent($('load').form.elements['load'][n].value); 

      if ($v('default-graph-uri') != '')
      {
        body += '&loaduri=';
        body += encodeURIComponent($v('default-graph-uri')); 
      }
      
      var pattern = /FROM *<(.*)>/gi;        // recognizes words; global
      var token = pattern.exec($v('query'));   // get the first match
      while (token != null)
      {
        body += '&loaduri=';
        body += encodeURIComponent(token[1]); 
        token = pattern.exec($v('query'));    // get the next match
      }
      
      return body;
    };
    var ldcallback = function(data) 
    { 
      //$('etalon').innerHTML += data;
      if (!data)
        data = 'Empty response';
      rq_query(param,data);
    };
    
    OAT.Ajax.command(OAT.Ajax.POST, window.location.pathname, ldbody, ldcallback, OAT.Ajax.TYPE_TEXT);
  }
  else
    rq_query(param,'Skipped.');
    
}

function folder_click(t)
{
  var Childs = t.parentNode.childNodes;
  Childs[Childs.length - 1]._Tree_toggle();
}
