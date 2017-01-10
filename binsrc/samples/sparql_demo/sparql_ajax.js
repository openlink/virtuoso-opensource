/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2017 OpenLink Software
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
  OAT.Preferences.imagePath = "toolkit/images/";
  OAT.AJAX.imagePath = "toolkit/images";
  
  tab = new OAT.Tab ("main_col");
  tab.add ("tab_home","page_home");
  tab.add ("tab_query","page_query");
  tab.add ("tab_dawg","page_dawg");
  tab.add ("tab_virt_ext","page_virt_ext");
  tab.add ("tab_sq","page_sq");
  tab.add ("tab_tutorial","page_tutorial");
  tab.add ("tab_import_data","page_import_data");
//  tab.add ("tab_query_remote","page_query_remote");
  tab.go (1); /* is 0-based index... */
	$('load').checked = true;
  $('remote').selectedIndex = 0;
  tab.go (go_to); /* is 0-based index... */

  tabgraphs = new OAT.Tab ("tabgrph_content");
  tabgraphs.add ("tabgrph_default","tabgrph_default_content");
  tabgraphs.add ("tabgrph_named","tabgrph_named_content");
  tabgraphs.go (0);

  var sr_cl = new OAT.Combolist([],"http://demo.openlinksw.com/sparql");
  sr_cl.input.name = "service";
  sr_cl.input.id = "service";
  sr_cl.img.src = "images/cl.gif";
  $("sr_cl_div").appendChild(sr_cl.div);
  sr_cl.addOption("http://demo.openlinksw.com/sparql");
  sr_cl.addOption("http://myopenlink.net:8890/sparql/");
  sr_cl.addOption("http://xmlarmyknife.org/api/rdf/sparql/query");
  sr_cl.addOption("http://www.sparql.org/sparql");
  sr_cl.addOption("http://www.govtrack.us/sparql");
  sr_cl.addOption("http://abdera.watson.ibm.com:8080/sparql");

  sr_cl.addOption("http://km.aifb.uni-karlsruhe.de/services/sparql/SPARQL");
  sr_cl.addOption("http://jena.hpl.hp.com:3040/backstage");
  sr_cl.addOption("http://my.opera.com/community/sparql/sparql");
  sr_cl.addOption("http://www.wasab.dk/morten/2005/04/sparqlette/");

  var dawg_tree = new OAT.Tree({imagePath:"toolkit/images/",ext:"png",onClick:"toggle", onDblClick:"toggle"}); 
  dawg_tree.assign("dawg_tree",true);
  var virt_ext_tree = new OAT.Tree({imagePath:"toolkit/images/",ext:"png",onClick:"toggle", onDblClick:"toggle"}); 
  virt_ext_tree.assign("virt_ext_tree",true);
  var samples_tree = new OAT.Tree({imagePath:"toolkit/images/",ext:"png",onClick:"toggle", onDblClick:"toggle"}); 
  samples_tree.assign("samples_tree",true);
  var tutorial_tree = new OAT.Tree({imagePath:"toolkit/images/",ext:"png",onClick:"toggle", onDblClick:"toggle"});
  tutorial_tree.assign("tutorial_tree",true);

  filewin = new OAT.Window({close:1,min:0,max:0,x:450,y:155,width:500,height:400,title:"View File",imagePath:"toolkit/images/"});
  filewin.content.appendChild($("file_window_content"));
  filewin.div.style.zIndex = 1010;
  document.body.appendChild(filewin.div);
  OAT.Dom.hide(filewin.div);
  filewin.onclose = function() { OAT.Dom.hide(filewin.div); }
  
	OAT.WebDav.init({imagePath:OAT.Preferences.imagePath,imageExt:"png", user:"", pass:""});
	
	OAT.Dom.hide($('remote_panel'));
	//switch_panels();

  var ref=function() { 
    if ($('dawg_tree_container')._Tree_collapsed == 0)
    {
      OAT.Dom.show($('dawg_tree_container'));
      $('dawg_tree_container')._Tree_collapsed = 1;
      OAT.Dom.hide ($('virt_ext_tree_container'));
      $('virt_ext_tree_container')._Tree_collapsed = 0;
      OAT.Dom.hide ($('samples_tree_container'));
      $('samples_tree_container')._Tree_collapsed = 0;
      OAT.Dom.hide ($('tutorial_tree_container'));
      $('tutorial_tree_container')._Tree_collapsed = 0;
    } else {
      OAT.Dom.hide($('dawg_tree_container'));
      $('dawg_tree_container')._Tree_collapsed = 0;
    }
  }
  OAT.Event.attach($('tab_dawg_toggle'),"click",ref);
  $('dawg_tree_container')._Tree_collapsed = 0;

  var ref3v=function() { 
    if ($('virt_ext_tree_container')._Tree_collapsed == 0)
    {
      OAT.Dom.hide($('dawg_tree_container'));
      $('dawg_tree_container')._Tree_collapsed = 0;
      OAT.Dom.show ($('virt_ext_tree_container'));
      $('virt_ext_tree_container')._Tree_collapsed = 1;
      OAT.Dom.hide ($('samples_tree_container'));
      $('samples_tree_container')._Tree_collapsed = 0;
      OAT.Dom.hide ($('tutorial_tree_container'));
      $('tutorial_tree_container')._Tree_collapsed = 0;
    } else {
      OAT.Dom.hide($('virt_ext_tree_container'));
      $('virt_ext_tree_container')._Tree_collapsed = 0;
    }
  }
  OAT.Event.attach($('tab_virt_ext_toggle'),"click",ref3v);
  $('virt_ext_tree_container')._Tree_collapsed = 0;


  var ref2=function() { 
    if ($('samples_tree_container')._Tree_collapsed == 0)
    {
      OAT.Dom.hide ($('dawg_tree_container'));
      $('dawg_tree_container')._Tree_collapsed = 0;
      OAT.Dom.hide ($('virt_ext_tree_container'));
      $('virt_ext_tree_container')._Tree_collapsed = 0;
      OAT.Dom.show($('samples_tree_container'));
      $('samples_tree_container')._Tree_collapsed = 1;
      OAT.Dom.hide ($('tutorial_tree_container'));
      $('tutorial_tree_container')._Tree_collapsed = 0;
    } else {
      OAT.Dom.hide($('samples_tree_container'));
      $('samples_tree_container')._Tree_collapsed = 0;
    }
  }
  OAT.Event.attach($('tab_sq_toggle'),"click",ref2);
  $('samples_tree_container')._Tree_collapsed = 0;

  var ref5=function() {
    if ($('tutorial_tree_container')._Tree_collapsed == 0)
    {
      OAT.Dom.hide ($('dawg_tree_container'));
      $('dawg_tree_container')._Tree_collapsed = 0;
      OAT.Dom.hide ($('virt_ext_tree_container'));
      $('virt_ext_tree_container')._Tree_collapsed = 0;
      OAT.Dom.hide ($('samples_tree_container'));
      $('samples_tree_container')._Tree_collapsed = 0;
      OAT.Dom.show($('tutorial_tree_container'));
      $('tutorial_tree_container')._Tree_collapsed = 1;
    } else {
      OAT.Dom.hide($('tutorial_tree_container'));
      $('tutorial_tree_container')._Tree_collapsed = 0;
    }
  }
  OAT.Event.attach($('tab_tutorial_toggle'),"click",ref5);
  $('tutorial_tree_container')._Tree_collapsed = 0;
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
	  OAT.AJAX.GET(path, '', response,{type:OAT.AJAX.TYPE_TEXT});
	}
}

function open_dav()
{
	var options = {
		mode:'open_dialog',
		user:'',
		pass:'',
		pathDefault:"/DAV/VAD/sparql_demo/data/",
		imagePath:'toolkit/images/',
		imageExt:'png',
		toolbar:{new_folder:false},
    onConfirmClick:view_file
  };
	OAT.WebDav.open(options);
}

function load_dawg(list,item,page)
{
  if (!page) page = 'dawg';
  if (page == 'dawg') tab.go (2);
  else tab.go (3);

  $(page + '_content').innerHTML = 'Loading data ...';
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
        queryuri = (ch[i].firstChild)?ch[i].firstChild.nodeValue:'';
      else if (ch[i].nodeName == 'query')
        query = (ch[i].firstChild)?ch[i].firstChild.nodeValue:'';
      else if (ch[i].nodeName == 'default-graph-uri')
        default_graph_uri = (ch[i].firstChild)?ch[i].firstChild.nodeValue:'';
      else if (ch[i].nodeName == 'data')
        data = (ch[i].firstChild)?ch[i].firstChild.nodeValue:'';
      else if (ch[i].nodeName == 'comment')
        comment = (ch[i].firstChild)?ch[i].firstChild.nodeValue:'';
      else if (ch[i].nodeName == 'etalonuri')
        etalonuri = (ch[i].firstChild)?ch[i].firstChild.nodeValue:'';
      else if (ch[i].nodeName == 'etalon')
        etalon = (ch[i].firstChild)?ch[i].firstChild.nodeValue:'';
      }
    
    $(page + '_content').innerHTML ='';
    $(page + '_content').innerHTML += '<h2>' + decodeURIComponent(item).replace(/\+/g,' ') +'</h2>';
    $(page + '_content').innerHTML +='<p>' + comment +'</p>';
    if (default_graph_uri)
      {
      $(page + '_content').innerHTML +='<h3>Data</h3>';
      $(page + '_content').innerHTML +='<p><a href="#" id="' + page + '_dgu" onclick="view_file(\'' + default_graph_uri + '\')">' + default_graph_uri + '</a><br></p>';
      $(page + '_dgu').setAttribute('casedata',default_graph_uri);
      }
    if (data)
      $(page + '_content').innerHTML +='<div class="query">' + data.replace(/&/g,'&amp;').replace(/</g,'&lt;') + '</div>';
    else
      $(page + '_content').innerHTML +='<p>This query does not use any data files. Instead, it access relational tables of the database.</p>';
    $(page + '_content').innerHTML +='<h3>Query</h3>';
    $(page + '_content').innerHTML +='  <a href="#" onclick="view_file(\'' + queryuri + '\')">' + queryuri + '</a><br>';
    $(page + '_content').innerHTML +='<div class="query" id="' + page + '_query">' + query.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/\n/g,'<br/>').replace(/ /g,'&nbsp;') + '</div>';
    $(page + '_query').setAttribute('casedata',query);
    $(page + '_query').setAttribute('caselist',list);
    $(page + '_content').innerHTML +='  <br/><button name="load_dawg_query" id="load_dawg_query" onclick="load_dawg_query(\'' + page +'\')">Load Query</button><br/>';
    if (etalonuri)
    {
      $(page + '_content').innerHTML +='<h3>Results</h3>';
      $(page + '_content').innerHTML +='<p><a href="#" onclick="view_file(\'' + etalonuri + '\')">' + etalonuri + '</a></p>';
      $(page + '_content').innerHTML += '<div id="' + page + '_etalon">' + etalon + '</div>';
    }
    else
      $(page + '_content').innerHTML += '<div id="dawg_etalon"><p>The result of the query will vary from database to database.</p></div>';
    var table = find_child_element($(page + '_etalon'),'table');
    if (table && table.rows[0] && table.rows[0].cells[0] && table.rows[0].cells[0].innerHTML == 'callret')
    {
      var res = table.rows[1].cells[0].firstChild.innerHTML;
      table.parentNode.removeChild(table);
      $(page + '_etalon').innerHTML = res.replace(/</g,'&lt;');
    }
  };
  OAT.AJAX.GET("./load_dawg_usecase.vsp?list=" + list + "&case=" + item, '', callback, {type:OAT.AJAX.TYPE_XML});
}

function load_dawg_query(page)
{
  if (!$(page + '_query') || !$(page + '_query').innerHTML)
  {
    alert('Please select a test case from the tree on the left.');
    return;
    }
  tab.go(1);
  $('should-sponge').checked = false;
  if ($(page + '_query') && $(page + '_query').getAttribute)
    $('query').value = $(page + '_query').getAttribute('casedata');
  else 
    $('query').value = '';
  if ($(page + '_dgu') && $(page + '_dgu').getAttribute)
    $('default-graph-uri').value = $(page + '_dgu').getAttribute('casedata');
  else 
    $('default-graph-uri').value = '';
  if ($(page + '_etalon') && $(page + '_etalon').getAttribute)
    $('etalon').innerHTML = '<hr/><b>Expected result:</b><br/>' + $(page + '_etalon').innerHTML;
  else 
    $('etalon').innerHTML = '';

  format_select();
  //if($('query').value.match('CONSTRUCT'))
  //  $('format').selectedIndex = 1; 
  //else 
    $('format').selectedIndex = 1; 
    
  $('res_area').innerHTML = '';

  var table = find_child_element($('etalon'),'table');
    if (table)
    { 
    $('etalon').innerHTML += '<div id="grid_etalon"></div>'; 
    table = find_child_element($('etalon'),'table');
    grid2 = new OAT.Grid("grid_etalon",0);
    load_grid(grid2,table);
      table.parentNode.removeChild(table);
    grid2.ieFix();
    }
  //else
  //{
  //  $('etalon').innerHTML += '<pre>' + data.replace(/</g,'&lt;') + '</pre>';
  //}
  //OAT.Dom.hide($('tree_container'));
}

function load_sq(list,item)
{
  tab.go (4);
  $('sq_content').innerHTML = 'Loading data ...';
  var callbacksq = function(data) {
    var ch = data.firstChild.childNodes;
    var query = '';
    var default_graph_uri = '';
    var comment = '';
    for(var i = 0; i < ch.length; i++)
    {
      if (ch[i].nodeName == 'query')
        query = ch[i].firstChild.nodeValue;
      else if (ch[i].nodeName == 'default-graph-uri')
        default_graph_uri = ch[i].firstChild.nodeValue;
      else if (ch[i].nodeName == 'comment')
        comment = (ch[i].firstChild)?ch[i].firstChild.nodeValue:'';
    }
    
    $('sq_content').innerHTML = '<h2>' + decodeURIComponent(item).replace(/\+/g,' ') +'</h2>';
    $('sq_content').innerHTML +='<p>' + comment +'</p>';
    $('sq_content').innerHTML +='<h3>Data</h3>';
    $('sq_content').innerHTML +='<p><a href="' + default_graph_uri + '" id="sq_dgu" target="blank">' + default_graph_uri + '</a><br></p>';
    $('sq_dgu').setAttribute('sqdata',default_graph_uri);
    $('sq_content').innerHTML +='<h3>Query</h3>';
    $('sq_content').innerHTML +='<div class="query" id="sq_query">' + query.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/\n/g,'<br/>').replace(/ /g,'&nbsp;') + '</div>';
    $('sq_query').setAttribute('sqdata',query);
    $('sq_content').innerHTML +='  <br/><button name="load_sq_query" id="load_sq_query" onclick="load_sq_query()">Load Query</button><br/>';
  };
  OAT.AJAX.GET("./load_sq.vsp?list=" + list + "&case=" + item, '', callbacksq, {type:OAT.AJAX.TYPE_XML});
}

function load_sq_query()
{
  if (!$('sq_query') || !$('sq_query').innerHTML)
  {
    alert('Please select sample query from the tree on the left first!');
    return;
  }
  tab.go(1);
  $('should-sponge').checked = true;
  $('query').value = $('sq_query').getAttribute('sqdata');
  $('default-graph-uri').value = $('sq_dgu').getAttribute('sqdata');

  $('res_area').innerHTML = '';
  $('etalon').innerHTML = ''; 
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
  $('etalon').innerHTML = ''; 
}

function reset_click()
{
  $('res_area').innerHTML = ''; 
  $('etalon').innerHTML = ''; 
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

function LoadJSON2Grid(grid,JSONData)
{
  var cells = Array();
  var headers = Array();
  var binding = '';
  // make the header
  for(var h = 0;h < JSONData.head.vars.length;h++)
  {
    cells.push({value:JSONData.head.vars[h],align:OAT.GridData.ALIGN_CENTER});
    headers.push(JSONData.head.vars[h]);
  }
  grid.createHeader(cells);

  // make the rows
  for(var r = 0;r < JSONData.results.bindings.length;r++)
  {
    cells = Array();
    for(var c = 0;c < headers.length;c++)
    {
      if (JSONData.results.bindings[r][headers[c]])
      {
        binding = JSONData.results.bindings[r][headers[c]];
        if (binding.type == 'uri')
          cells.push({value:'<a href="#" onclick="QueryURI(\'' + binding.value + '\',\'' + headers[c] + '\')">' +  binding.value + '</a>'});
        else
          cells.push({value:binding.value});
      }
      else
        cells.push('');
    }
    grid.createRow(cells);
  }

  test = JSONData;
}

function QueryURI(uri,colName)
{
  if (colName.toLowerCase() == 'property' )
  {
    $('query').value  = 'SELECT ?resource ?value\n' +
                        'WHERE { ?resource <' + uri + '> ?value }\n' + 
                        'ORDER BY ?resource ?value\n';
  }
  else
  {
    $('query').value  = 'SELECT ?property ?hasValue ?isValueOf\n' +
                        'WHERE {\n' + 
                        '  { <' + uri + '> ?property ?hasValue }\n' + 
                        '  UNION\n' + 
                        '  { ?isValueOf ?property <' + uri + '> }\n' + 
                        '}\n';
  }

  QueryExec();
}

function load_grid(grid,table){
  var minlen = table.rows[0].cells.length;
  for(var i = 0;i < table.rows.length;i++)
  {
    var row = table.rows[i];
    var cells = Array();
    //for(var n = 0;n < row.cells.length;n++)
    for(var n = 0;n < minlen;n++)
    {
      if (row.cells[n])
    {
      if (i == 0)
        cells.push({value:row.cells[n].innerHTML.replace(/<PRE>/ig,'').replace(/<\/PRE>/ig,''),align:OAT.GridData.ALIGN_CENTER});
      else
        cells.push(row.cells[n].innerHTML.replace(/<PRE>/ig,'').replace(/<\/PRE>/ig,''));
      } else 
        cells.push('');
    }
    if (i == 0)
      grid.createHeader(cells);
    else
      grid.createRow(cells);
  }
}

// Executes the query and proces the results
// param: make diffrence between runs - c:explain, er:error

function QueryExec(param)
{
    
  if (is_r() && $v('service') == '')
  {
    alert('You must specify "Query Service Endpoint"!');
    return;
  }
  // if it is compile, clear the etalon
  if (param == 'c')
    $('etalon').innerHTML = '';
  $('res_area').innerHTML = 'Sending query...';

  // Determine format, if it is table the we need json results
  var format = $v('format');
  if (!format) format = 'text/html';
  if (format == 'application/isparql+table')
    format = 'application/sparql-results+json'; 
  var content_type = 'application/x-www-form-urlencoded';
  
  var ReqHeaders = {'Accept':format,'Content-Type':content_type};

  // generate the request body
  var body = function()
  {
    var body = '';
    
    // parameters we will send
    var params = ['default-graph-uri','query','format','maxrows'];
    // if it is remote add service endpoint
    if (is_r())
      params.push('service');
    else
      params.push('should-sponge');
      
    for(var i = 0; i < params.length; i++)
    {
      if (!(params[i] == 'default-graph-uri' && $v('default-graph-uri') == '') && // Patch ot skip default graph if it is empty;
          !($(params[i]).type == 'checkbox' && !$(params[i]).checked)) // Skip unchecked checkboxes
      {
      if (body != '') 
        body += '&'; 
        body += params[i] + '=';
        if (params[i] == 'format') // If it is format get the overwritten value
        {
          body += encodeURIComponent(format); 
        }
        else if ($(params[i]).type == 'radio')
        {
          for(var n = 0; n < $(params[i]).form.elements[$(params[i]).name].length;n++)
            if ($(params[i]).form.elements[$(params[i]).name][n].checked)
              body += encodeURIComponent($(params[i]).form.elements[$(params[i]).name][n].value); 
        }
        else
          body += encodeURIComponent($v(params[i])); 
      }
    }
    
    // get all checked named_graphs from named graphs tab
    named_graphs = document.getElementsByName('named_graph_cbk');
    
    if(named_graphs && named_graphs.length > 0)
    {
      for(var n = 0; n < named_graphs.length; n++)
      {
        // if it is checked, add to params too
        if (named_graphs[n].checked)
        {
          var named_graph_value = $v('named_graph_'+named_graphs[n].value);
          if (named_graph_value != '')
          {
            if (body != '') 
              body += '&'; 
            body += 'named-graph-uri=';
            body += encodeURIComponent(named_graph_value); 
          }
        }
      }
    }
    
    return body;
  };

  //RESULT PROCESSING
  var callback = function(data,headers) 
  { 
    // Clear the tabls
    OAT.Dom.unlink($('res_container'));
    OAT.Dom.unlink($('result'));
    OAT.Dom.unlink($('request'));
    OAT.Dom.unlink($('response'));

    $('res_area').innerHTML = '';
    var tabres_html = '';
    
    // Make the tabs 
    tabres_html += '<ul id="tabres">';
    tabres_html += '<li id="tabres_result">result</li><li id="tabres_request">request</li><li id="tabres_response">response</li>';
    tabres_html += '</ul>';
    tabres_html += '<div id="res_container"></div>';
    tabres_html += '<div id="result">' + data + '</div>';
    $('res_area').innerHTML += tabres_html;
    
    var body_str = body();
    var request = '';
    request += '<div id="request"><pre>';
    request += 'POST ' + endpoint + ' HTTP 1.1\r\n';
    request += 'Host: ' + window.location.host + '\r\n';
    if (ReqHeaders) {
		  for (var p in ReqHeaders) {
		    request += p + ': ' + ReqHeaders[p] + '\r\n';
		  }
		}
    request += 'Content-Length: ' + body_str.length + '\r\n';
    request += '\r\n';
    request += body_str.replace(/&/g,'&amp;').replace(/</g,'&lt;');
    request += '</pre></div>'; 
    $('res_area').innerHTML += request; 

    var response = '';
    response += '<div id="response"><pre>';
    response += headers;
    response += '\r\n';
    response += data.replace(/&/g,'&amp;').replace(/</g,'&lt;');
    response += '</pre></div>'; 
    $('res_area').innerHTML += response; 

    var tabres = new OAT.Tab ("res_container");
    tabres.add ("tabres_result","result");
    tabres.add ("tabres_request","request");
    tabres.add ("tabres_response","response");
    tabres.go(0);

    //if it is a special format and param is empty then we postprocess json to draw a table
    if ($v('format') == 'application/isparql+table' && !param)
    {
      $('result').innerHTML = '<div id="grid"></div>'; 
      //table = find_child_element($('result'),'table');
      var grid = new OAT.Grid("grid",0);
      var JSONData = eval('(' + data + ')');
      LoadJSON2Grid(grid,JSONData);
      //table.parentNode.removeChild(table);
      grid.ieFix();
      if (typeof grid2 != 'undefined')
        grid2.ieFix();
    }
    else
    {
      // it is either and error or compile
      if (param)
      {
        $('result').innerHTML = data;
      // result too big to post process, just show it
      } else if (data.length > 10 * 1024) {
        
        $('result').innerHTML = '<pre>' + data.replace(/</g,'&lt;') + '</pre>';
      // ry to postprocess it 
      } else {
        var shtype = 'xml';
        if ($v('format') == 'application/sparql-results+json' || 
            $v('format') == 'application/javascript' )
          shtype = 'javascript';
        else if ($v('format') == 'text/html')
          shtype = 'html';
        $('result').innerHTML = '<textarea name="code" class="' + shtype + '">' + data + '</textarea>';
        dp.SyntaxHighlighter.HighlightAll('code',0,0);
      }
    }

  };
  
  var endpoint = '';
  // it it is not remote or compile send to local sparql endpoint
  if (!is_r() && !param)
    endpoint = '/sparql/?'
  // if it is compile 
  else if (param == 'c')
    endpoint = 'explain.vsp?';
  // it must be remote then
  else 
    endpoint = 'remote.vsp?';
  
	optObj = {
		headers:ReqHeaders,
		type:OAT.AJAX.TYPE_TEXT,
		//in case of an error exec the callback also, but give a parameter er
		onerror:function(xhr)
    {
      var status = xhr.getStatus();
      var response = xhr.getResponseText();
			var headers = xhr.getAllResponseHeaders();
			var data = '';
      param = 'er';
      if (!response)
      {
        response = 'There was a problem with your request! The server returned status code: ' + status + '<br/>\n';
        response += 'Unfortunately your browser does not allow us to show the error. ';
        response += 'This is a known bug in the Opera Browser.<br/>\n';
        response += 'However you can click this link which will open a new window with the error: <br/>\n';
        response += '<a target="_blank" href="/sparql/?' + body() + '">/sparql/?' + body() + '</a>';
      }
      else 
      {
        data = response.replace(/&/g,'&amp;').replace(/</g,'&lt;');
      }
      callback('<pre>' + data + '</pre>',headers);
    }
	}
  
  OAT.AJAX.POST(endpoint, body(), callback, optObj);
}

var last_format = 1;

function format_select(query_obg)
{
  if (query_obg == undefined) query_obg = $('query');
  var query = query_obg.value;
  var format = $('format')
    
  if (query.match(/construct/i) && last_format == 1)
  {
    for(var i = format.options.length; i > 0; i--)
      format.options[i] = null;
    format.options[1] = new Option('N3/Turtle','text/rdf+n3');
    format.options[2] = new Option('RDF/XML','application/rdf+xml');
    format.selectedIndex = 1;
    last_format = 2;
  }

  if (!query.match(/construct/i) && last_format == 2)
  {
    for(var i = format.options.length; i > 0; i--)
      format.options[i] = null;
    format.options[1] = new Option('Table','application/isparql+table');
    format.options[2] = new Option('XML','application/sparql-results+xml');
    format.options[3] = new Option('JSON','application/sparql-results+json');
    format.options[4] = new Option('Javascript','application/javascript');
    format.options[5] = new Option('HTML','text/html');
    format.selectedIndex = 1;
    last_format = 1;
  }
  
}

var fileloadwin = null;

function load_click(rid)
{

  var params = '';
  if (fileloadwin == null)
  {
    fileloadwin = new OAT.Window({close:1,min:0,max:0,x:450,y:155,width:500,height:400,title:"Load Resource",imagePath:"toolkit/images/"});
    fileloadwin.div.style.zIndex = 1011;
    document.body.appendChild(fileloadwin.div);
    fileloadwin.onclose = function() { OAT.Dom.hide(fileloadwin.div); }
  } else
    OAT.Dom.show(fileloadwin.div);
  fileloadwin.content.innerHTML = 'Loading...';
    
  if (rid > 0)
    params = 'd_rid=' + rid;
    

  var callbacklq = function(data) {
    fileloadwin.content.innerHTML = data;
  }

  OAT.AJAX.GET("./sparql_file.vsp?" + params, '', callbacklq, {type:OAT.AJAX.TYPE_TEXT});
  
}

function load_rq_click(rid)
{
  var callbacklrq = function(data) {
    $('query').value = data;
  }
  OAT.AJAX.GET("./sparql_file.vsp?act=load&rid=" + rid, '', callbacklrq, {type:OAT.AJAX.TYPE_TEXT});
  OAT.Dom.hide(fileloadwin.div);
}

function store_click(){
  var res_name = prompt("Resource Name",'');
	if (!res_name) return;
	
	var pub = confirm("Make the resource public?");
	if (pub) pub = '1';
  else pub = '0';
  
  var callbacklsc = function(data) {
    if (data == 'overwrite')
    {
      if (confirm("Resource already exists.\nDo you want to overwrite it?"))
      {
        OAT.AJAX.POST("./sparql_file.vsp?act=store&pub="+pub+"&res_name="+encodeURIComponent(res_name)+'&ovr=1', 
            '&query=' + encodeURIComponent($v('query')), callbacklsc, {type:OAT.AJAX.TYPE_TEXT});
      }
    } else 
      alert(data);
  }
	
  OAT.AJAX.POST("./sparql_file.vsp?act=store&pub="+pub+"&res_name="+encodeURIComponent(res_name), 
      '&query=' + encodeURIComponent($v('query')), callbacklsc, {type:OAT.AJAX.TYPE_TEXT});
  
}

function prefix_insert()
{
  prefix = $v('prefix');
  if ($v('query').indexOf(prefix) == -1)
    $('query').value = prefix + '\n' + $v('query');
}

function template_insert()
{
  template = $v('template');
  insert_text($('query'),template);
  $('template').selectedIndex = 0;
}

function tool_invoke()
{
  tool = $v('tool');
  eval(tool);
  $('tool').selectedIndex = 0;
}

function tool_put(txt)
{
  insert_text($('query'),txt);
}

function tool_put_line_start(txt)
{
  var query = $('query');
  var query_value = $v('query').replace("\r",'');
  var lines = query_value.split("\n");

  var pos = getPos(query);
  start = pos[0];
  end   = pos[1];
  var nl = 0;
  if (start < end)
    nl = 1;
  var from  = strCountLines(query_value.substring(0,start));
  var to    = strCountLines(query_value.substring(start,end - nl)) + from;
  
  var res = '';
  var cnt = 0;
  for(var i=0;i<lines.length;i++)
  {
    if ( from <= i && i <= to )
    {
      res += txt + lines[i];
      cnt++;
    }
    else
      res += lines[i];
    if (i < lines.length - 1)
      res += "\n";
  }
  query.value = res;
  //alert(res.charAt(start - 1 - OAT.Browser.isIE));
  if (!((res.charAt(start - 1 - OAT.Browser.isIE) == "\n" || start == 0) && start != end))
    start = start + txt.length;
  if (cnt > 1)
    end = end + (cnt * txt.length) - (OAT.Browser.isIE * (cnt - 1));
  else 
    end = end + txt.length;
  
  setPos(query, start, end);
  query.focus();
}

function tool_rem_line_start(txt)
{
  var query = $('query');
  var query_value = $v('query').replace("\r",'');
  var lines = query_value.split("\n");

  var pos = getPos(query);
  var start = pos[0];
  var end   = pos[1];
  var nl = 0;
  if (start < end)
    nl = 1;
  var from  = strCountLines(query_value.substring(0,start));
  var to    = strCountLines(query_value.substring(start,end - nl)) + from;
  
  var res = '';
  var cnt = 0;
  for(var i=0;i<lines.length;i++)
  {
    if ( from <= i && i <= to && lines[i].substring(0,txt.length) == txt)
    {
      res += lines[i].substring(txt.length);
      cnt++;
    }
    else
      res += lines[i];
    if (i < lines.length - 1)
      res += "\n";
  }
  query.value = res;
  
  if (cnt > 0)
  {
    if (!((res.charAt(start - 1 - OAT.Browser.isIE) == "\n" || start == 0) && start != end))
      start = start - txt.length;
    if (cnt > 1)
      end = end - (cnt * txt.length) - (OAT.Browser.isIE * (cnt - 1));
    else 
      end = end - txt.length;
  }
  setPos(query, start, end);
  query.focus();
}

function tool_put_around(btxt,atxt)
{
  var elm = $('query');
  var start = 0;
  var end = 0;
  
  var pos = getPos(elm);
  start = pos[0];
  end   = pos[1];

  var txt = elm.value.substring(start,end);
  
  insert_text(elm,btxt + txt + atxt);
}


function insert_text(elm,txt)
{
  var start = 0;
  var end = 0;
  
  var pos = getPos(elm);
  start = pos[0];
  end   = pos[1];

  elm.value = elm.value.substring(0,start) + txt + elm.value.substring(end,elm.value.length);
  
  end = start + txt.length;
  setPos(elm, start, end);
  elm.focus();

}

function setPos(elm, start, end) {
  if (typeof elm.selectionStart != "undefined" && typeof elm.selectionEnd != "undefined") {
      elm.setSelectionRange(start, end);
  } else if (document.selection && document.selection.createRange) {
      var range_new = elm.createTextRange ();
      range_new.move ("character", start - strCountLines(elm.value.substring(0,start)));
      range_new.moveEnd ("character", end - start);
      range_new.select ();
  }
}

function getPos(elm) {
	if (typeof elm.selectionStart != "undefined" && typeof elm.selectionEnd != "undefined")
		return [elm.selectionStart,elm.selectionEnd];
  
  elm.focus();
  var range = document.selection.createRange();
  var stored_range = range.duplicate();
  stored_range.moveToElementText( elm );
  stored_range.setEndPoint( 'EndToEnd', range );
  return [stored_range.text.length - range.text.length,stored_range.text.length];
};

function strCountLines(txt){
  var cnt = 0;
  if (txt.length < 1)
    return 0;
  for(var i=1;i<=txt.length;i++)
  {
    if(txt.substring(i-1, i) == "\n") 
    {
      cnt++;
    }
  }
  return cnt;
};

var toolswin = null;

function tools_popup()
{
  if (toolswin == null)
  {
    toolswin = new OAT.Window({close:1,min:0,max:0,x:850,y:300,width:200,height:440,title:"Statement Help",imagePath:"toolkit/images/"});
    toolswin.div.style.zIndex = 1013;
    document.body.appendChild(toolswin.div);
    toolswin.onclose = function() { OAT.Dom.hide(toolswin.div); }
    
    var tools = $('tool').options;
    toolswin.content.innerHTML = '';
    for(i = 0;i<tools.length;i++)
    {
      if (tools[i].value)
        toolswin.content.innerHTML += '<button class="tools_but" onclick="' + tools[i].value.replace(/"/g,'&quot;') + '">' + tools[i].text + '</button>';
    }
  }
  OAT.Dom.show(toolswin.div);

}

var graphs_grid_num = 1;

function add_named_graph()
{
  var named_graph = $v('named_graph_add');
  
  if (!named_graph)
  {
    alert('Please fill in named graph value');
    return false;
  }
  
  table = $('named_graph_list');
  
  if (!table.tBodies.length)
  {
    var body = OAT.Dom.create("tbody")
  	table.appendChild(body);
  }
  
  row = OAT.Dom.create("tr");
  OAT.Dom.addClass(row,"odd");
  row.id = 'named_graph_list_rom'+graphs_grid_num;
  table.tBodies[0].appendChild(row);
  
  cell_cb = OAT.Dom.create("td");
  cell_cb.innerHTML = '<input type="checkbox" name="named_graph_cbk" value="'+graphs_grid_num+'" checked="checked"/>';
  cell_cb.style.textAlign = "center";
  row.appendChild(cell_cb);

  cell_gr = OAT.Dom.create("td");
  cell_gr.innerHTML = '<input type="text" style="width: 440px;" id="named_graph_'+graphs_grid_num+'" value="'+named_graph+'"/>';
  row.appendChild(cell_gr);

  cell_rm = OAT.Dom.create("td");
  cell_rm.innerHTML = '<button onclick="remove_named_graph('+graphs_grid_num+');return false;"><img src="images/edit_remove.png" title="del" alt="del"/> del</button>';
  cell_rm.style.textAlign = "center";
  row.appendChild(cell_rm);
  
  graphs_grid_num++;
  
  $('named_graphs_cnt').innerHTML++;
  
  return false;
  
}

function remove_named_graph(ind)
{
  OAT.Dom.unlink($('named_graph_list_rom'+ind));
  $('named_graphs_cnt').innerHTML--;
  
  table = $('named_graph_list');
  
  if (!table.tBodies[0].rows.length)
  {
    OAT.Dom.unlink(table.tBodies[0]);
  }
  
}

var br_prefixes = Array();
var br_classes = Array();
var bt_properties = Array();


