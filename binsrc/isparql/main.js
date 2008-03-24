/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2007 OpenLink Software
 *
 *  See LICENSE file for details.
 *
 */

var defaultEndpoints = ["/sparql","http://demo.openlinksw.com/sparql","http://myopenlink.net:8890/sparql/",
						"http://xmlarmyknife.org/api/rdf/sparql/query","http://www.sparql.org/sparql",
						"http://www.govtrack.us/sparql","http://abdera.watson.ibm.com:8080/sparql",
						"http://km.aifb.uni-karlsruhe.de/services/sparql/SPARQL","http://jena.hpl.hp.com:3040/backstage",
						"http://my.opera.com/community/sparql/sparql","http://www.wasab.dk/morten/2005/04/sparqlette/"];

var dialogs = {};

var goptions = {};
goptions.username = '';
goptions.password = '';
goptions.login_put_type = 'dav';
goptions.service = '/sparql';
goptions.proxy = true;
goptions.should_sponge = 'soft';
goptions.initial_screen = true;
goptions.last_path = '';
var isVirtuoso = false;

var qbe = {};
var adv = {};
var tab = {};
var tab_qbe = {};
var tab_query = {};
var page_w = 800;
var page_h = 800;
var iSPARQL = {};

if (typeof(default_dgu) == 'undefined') var default_dgu = '';
if (typeof(default_qry) == 'undefined') var default_qry = 'SELECT * WHERE {?s ?p ?o}';
if (typeof(default_spng) == 'undefined') var default_spng = 'soft';
if (typeof(do_auth_verify) == 'undefined') var do_auth_verify = '';
if (typeof(fixed_sponge) == 'undefined') var fixed_sponge = '';
if (typeof(toolkitImagesPath) == 'undefined') var toolkitImagesPath = "/isparql/toolkit/images/";
if (typeof(get_initial_credentials) == 'undefined') var get_initial_credentials = "";
if (typeof(default_user) != 'undefined') goptions.username = default_user;
if (typeof(default_pass) != 'undefined') goptions.password = default_pass;

function init() {
	OAT.Dom.hide("throbber");
	OAT.Event.attach("throbber","click",OAT.AJAX.cancelAll);
	init_qbe();
	/* fix image paths */
	if (toolkitImagesPath.match(/[^\/]$/)) { toolkitImagesPath += "/"; }
	OAT.Preferences.imagePath = toolkitImagesPath;
	OAT.AJAX.imagePath = toolkitImagesPath;
	OAT.Anchor.imagePath = toolkitImagesPath;
	OAT.WebDav.options.imagePath = toolkitImagesPath;
	
	OAT.AJAX.httpError = 0;
	$('about_oat_version').innerHTML = OAT.Preferences.version;
	$("throbber").src = OAT.Preferences.imagePath + "Dav_throbber.gif";

  // determine server type, if virtuoso we show virtuoso specifics
	OAT.AJAX.GET('./version', '', function(data,headers) { 
		
		if (headers.match(/VIRTUOSO/i)) {
		isVirtuoso = true;
		OAT.Dom.show('virtuoso_options');
		}
		var tmp = data.split("/");
		if (tmp && tmp.length > 1) {
		$('about_version').innerHTML = tmp[0];
		$('about_date').innerHTML = tmp[1];
		}
	},{async:false});


  OAT.Anchor.zIndex = 1001;

	var m = new OAT.Menu();
	m.noCloseFilter = "noclose";
	m.createFromUL("menu");

  var menuOn = function(index) {
    var menu_on = menus[index];
    if (OAT.Browser.isIE) menu_on.style.filter = '';
    for (var i = 0; i < menu_on.childNodes.length;i++) {
      if (menu_on.childNodes[i].tagName && menu_on.childNodes[i].tagName.toLowerCase() == "li") {
        menu_on.childNodes[i].style.opacity = '';
        menu_on.childNodes[i].style.filter = '';
        menu_on.childNodes[i].style.cursor = 'pointer';
      }
    }
  }
  
  var menuOff = function(index) {
    if (tab.tabs[index].window)
      return;
    var menu_off = menus[index];
    if (OAT.Browser.isIE)
      menu_off.style.filter = 'alpha(opacity=50)';
    for (var i = 0; i < menu_off.childNodes.length;i++) {
      if (menu_off.childNodes[i].tagName && menu_off.childNodes[i].tagName.toLowerCase() == "li") {
        menu_off.childNodes[i].style.opacity = 0.5;
        menu_off.childNodes[i].style.filter = 'alpha(opacity=50)';
        menu_off.childNodes[i].style.cursor = 'default';
      }
    }
  }
  
  var menus = [$('menu_file_down'),$('menu_tools_down')];

  var tab_goCallback = function(oldIndex,newIndex) {
    if (oldIndex != newIndex) {
      for (var i=0;i < menus.length;i++)
        if (newIndex > 1)
          menuOff(i);
        else
          menuOn(i);
    }

    if (OAT.Browser.isIE && dialogs.qbe_unsupp && newIndex == 0) {
      dialogs.qbe_unsupp.show();
      return;
    }
  }
  
  var onUnDock = function(newIndex) {
    if (newIndex == 0) {
      var x = 720;
      if (OAT.Browser.isMac) x -= 20;
      qbe.props_win.moveTo(x,42);
      qbe.schema_win.moveTo(x,182);
    }
    //menuOn(newIndex);
  }

  var onDock = function(newIndex) {
    if (newIndex == 0) {
      qbe.props_win.moveTo(page_w - 260,92);
      qbe.schema_win.moveTo(page_w - 260,232);
    }
    //menuOn(newIndex);
  }
  
  tab = new OAT.Tab ("main_col",{dockMode:true,dockElement:"tabs",goCallback:tab_goCallback,onDock:onDock,onUnDock:onUnDock,dockWindowWidth:1000,dockWindowHeight:600});
  tab_qbe = tab.add ("tab_qbe","page_qbe");
  tab_query = tab.add ("tab_query","page_query");

  tab.go (0); /* is 0-based index... */
  
	OAT.Dom.attach("menu_proc_opt","click",function() {
	  dialogs.goptions.show();
	});
	OAT.Dom.attach("menu_about","click",function() {
	  dialogs.about.show();
	});

  var tabgraphs = new OAT.Tab ("tabgrph_content");
  tabgraphs.add ("tabgrph_default","tabgrph_default_content");
  tabgraphs.add ("tabgrph_named","tabgrph_named_content");
  tabgraphs.go (0);

  var sr_cl = new OAT.Combolist(defaultEndpoints,"/sparql");
  sr_cl.input.name = "service";
  sr_cl.input.id = "service";
  sr_cl.list.style.zIndex = "1200";
  sr_cl.img.src = "images/cl.gif";
  sr_cl.img.width = "16";
  sr_cl.img.height = "16";
  $("sr_cl_div").appendChild(sr_cl.div);

	
	/* qbe_unsupp */
	dialogs.qbe_unsupp = new OAT.Dialog("Unsupported","qbe_unsupported_div",{width:400,modal:1});
	dialogs.qbe_unsupp.ok = function() {
		tab.go(1);
		dialogs.qbe_unsupp.hide();
	}
	dialogs.qbe_unsupp.cancel = dialogs.qbe_unsupp.ok;

	/* about */
	dialogs.about = new OAT.Dialog("About","about_div",{width:400,modal:0});
	dialogs.about.ok = dialogs.about.hide;
	dialogs.about.cancel = dialogs.about.hide;
	/* file name for saving */
	var fileRef = function() {
	  var path = iSPARQL.Common.getFilePath();
	  var pathDefault = iSPARQL.Common.getDefaultPath();
	    
	  var ext = $v('savetype');

		var name = OAT.Dav.getNewFile(path,'.' + ext);
		if (!name) { return; }
		if (name.slice(name.length-ext.length - 1).toLowerCase() != "." + ext) { name += "." + ext; }
		$("save_name").value = name;
	}
	OAT.Dom.attach("browse_btn","click",fileRef);

	/* options */
	var dialogs_goptions_onshow = function(){
	  OAT.Keyboard.enable('goptions');
	  //
    $('username').value = goptions.username;
    $('password').value = goptions.password;
    $('login_put_type').value = goptions.login_put_type;
    $('service').value = goptions.service;
    $('proxy').checked = goptions.proxy;
		switch (goptions.should_sponge) {
			case "grab-everything": $('should-sponge-grab-seealso').checked = true; break;
			case "grab-seealso": $('should-sponge-grab-seealso').checked = true; break;
			case "grab-all": $('should-sponge-grab-all').checked = true; break;
			case "soft"    : $('should-sponge-soft').checked = true; break;
			default: $('should-sponge-none').checked = true; break;
		}
	}
	dialogs.goptions = new OAT.Dialog("Preferences","goptions",{width:450,height:500,modal:1,resize:0,close:0,zIndex:1001,onshow:dialogs_goptions_onshow,onhide:function(){OAT.Keyboard.disable('goptions');}});
	dialogs.goptions.cancel = function(){
//	  if (!do_auth_verify || !goptions.initial_screen)
	    dialogs.goptions.hide();
	}
	dialogs.goptions.ok = function(){
	  var auth = iSPARQL.Common.checkAuth($v('username'),$v('password'));

	    if (auth == true) {
	      goptions.username = $v('username');
	      goptions.password = $v('password');
	      goptions.login_put_type = $v('login_put_type');
	      goptions.service = $v('service');
	      goptions.proxy = $('proxy').checked;
	      var sel_sponge = '';
	      if  ($('should-sponge-grab-everything').checked) sel_sponge = 'grab-everything';
	      else if  ($('should-sponge-grab-seealso').checked) sel_sponge = 'grab-seealso';
	      else if  ($('should-sponge-grab-all').checked) sel_sponge = 'grab-all';
	      else if ($('should-sponge-soft').checked) sel_sponge = 'soft';
	      if (sel_sponge != goptions.should_sponge) {
	        $('qbe_sponge').value = sel_sponge;
	        $('adv_sponge').value = sel_sponge;
	      }
	      goptions.should_sponge = sel_sponge;
	    	goptions.initial_screen = false;
	  	  dialogs.goptions.hide();
	  	} else {
	  	  if (auth == false)
	  	    alert('Unauthorized');
	  	  else 
	  	    alert(auth);
	  	}
	}
  OAT.Keyboard.add('esc',function(){dialogs.goptions.cancel();},null,'goptions');
  OAT.Keyboard.add('return',function(){dialogs.goptions.ok();},null,'goptions');

	page_w = OAT.Dom.getWH('page')[0] - 20;

	var page_params = OAT.Dom.uriParams();

	if (page_params['default-graph-uri']) default_dgu = page_params['default-graph-uri'];
	if (page_params['query']) default_qry = page_params['query'];
	if (page_params['should-sponge']) default_spng = page_params['should-sponge'];

	$('default-graph-uri').value = default_dgu;
	$('query').value = default_qry;
	if (!fixed_sponge) {
		fixed_sponge = '';
	} else {
		if (fixed_sponge == 'local') {
			default_spng = '';
		} else {
			default_spng = fixed_sponge;
		}
	}
	$('qbe_sponge').value = default_spng;
	$('adv_sponge').value = default_spng;
	goptions.should_sponge = default_spng;

	window.qbe = new iSPARQL.QBE();
	window.adv = new iSPARQL.Advanced();

	var execCB = function(query) {
		if (qbe.QueryGenerate() == query) { return; }
		if (tab.selectedIndex == 0) { 
			qbe.loadFromString(query);
		}
		if (tab.selectedIndex == 1) {
			$("query").value = query;
		}
	}
	window.qe = new QueryExec({div:"page_results",executeCallback:execCB});

	var loadToQBE = OAT.Dom.create("li",{},"nav");
	loadToQBE.title = 'Load query to QBE';
	var img = OAT.Dom.create("img");
	img.src = "images/arrange.png";
	OAT.Dom.attach(loadToQBE,'click',function(){ /* load to QBE */
		tab.go(tab_qbe);
		var cache = qe.cache[qe.cacheIndex];
		qbe.loadFromString(cache.opts.query);
		$('qbe_sponge').value = cache.opts.sponge;
		qbe.service.input.value = cache.opts.endpoint;
	});
	OAT.Dom.append([qe.dom.ul,loadToQBE],[loadToQBE,img]);
  
  
	var loadToAdvanced = OAT.Dom.create("li",{},"nav");
	loadToAdvanced.title = 'Load query to Advanced';
	var img = OAT.Dom.create("img");
	img.src = "images/cr22-action-edit.png";
	OAT.Dom.attach(loadToAdvanced,'click',function(){
		tab.go(tab_query);
		var cache = qe.cache[qe.cacheIndex];
		$('query').value = cache.opts.query;
		$('default-graph-uri').value = cache.opts.defaultGraph;
		$('adv_sponge').value = cache.opts.sponge;
		adv.service.input.value = cache.opts.endpoint;
	});
	OAT.Dom.append([qe.dom.ul,loadToAdvanced],[loadToAdvanced,img]);
  
  
	OAT.Resize.create("query_resizer_area", "query_div", OAT.Resize.TYPE_X);
	OAT.Resize.create("query_resizer_area", "query", OAT.Resize.TYPE_Y);
	$("query_resizer_area").style.backgroundImage = 'url("'+OAT.Preferences.imagePath+"resize.gif"+'")';
	$("query_resizer_area").style.cursor = "nw-resize";
  
  
  
  
  
  OAT.Dom.attach("menu_b_reset","click",function() {
    if (tab.tabs.find(tab_qbe) == tab.selectedIndex)
      qbe.func_clear();
    if (tab.tabs.find(tab_query) == tab.selectedIndex)
      adv.func_reset();
  });
  
  OAT.Dom.attach("menu_b_load","click",function() {
    if (tab.tabs.find(tab_qbe) == tab.selectedIndex)
      qbe.func_load();
    if (tab.tabs.find(tab_query) == tab.selectedIndex)
      adv.func_load();
  });

  OAT.Dom.attach("menu_b_save","click",function() {
    if (tab.tabs.find(tab_qbe) == tab.selectedIndex)
      qbe.func_save();
    if (tab.tabs.find(tab_query) == tab.selectedIndex)
      adv.func_save();
  });

  OAT.Dom.attach("menu_b_saveas","click",function(){
    if (tab.tabs.find(tab_qbe) == tab.selectedIndex)
      qbe.func_saveas();
    if (tab.tabs.find(tab_query) == tab.selectedIndex)
      adv.func_saveas();
  });

  OAT.Dom.attach("menu_b_run","click",function(){
    if (tab.tabs.find(tab_qbe) == tab.selectedIndex)
      qbe.func_run();
    if (tab.tabs.find(tab_query) == tab.selectedIndex)
      adv.func_run();
  });

  OAT.Dom.attach("menu_b_qbe","click",function(){
    tab.go(tab_qbe);
  });

  OAT.Dom.attach("menu_b_adv","click",function(){
    tab.go(tab_query);
  });

  OAT.Dom.hide("page_loading");
  OAT.Dom.show("page_content");
  if (qbe.svgsparql) { qbe.svgsparql.reposition(); }
	if (window.__inherited) {
		if (window.__inherited.username)       goptions.username = window.__inherited.username;
		if (window.__inherited.password)       goptions.password = window.__inherited.password;
		if (window.__inherited.login_put_type) goptions.login_put_type = window.__inherited.login_put_type;
		if (window.__inherited.endpoint)       goptions.service = window.__inherited.endpoint;
		if (window.__inherited.proxy)          goptions.proxy = window.__inherited.proxy;
		if (window.__inherited.should_sponge)  goptions.should_sponge = window.__inherited.should_sponge;
		if (window.__inherited.query)          qbe.loadFromString(window.__inherited.query);
    if (window.__inherited.graph)          $('qbe_graph').value = window.__inherited.graph;

  	if (window.__inherited.callback) {
    	/* query returning */
    	var returnRef = function() {
    	  if ($v('default-graph-uri') == '' || confirm('WARNING ! ! !\nDefault graph will be lost, construct your query using FROM instead. \nDo you wish to continue?'))
    	  {
    		  window.__inherited.callback($v('query'));
    		  window.close();
    		}
    	}
    	OAT.Dom.attach("return_btn","click",returnRef);
    }
    else 
      OAT.Dom.hide("return_btn");

	  if (!iSPARQL.Common.checkAuth(goptions.username,goptions.password) == true)
      dialogs.goptions.show();
    else if (window.__inherited.run)
      qbe.func_run();  
  } else {
    OAT.Dom.hide("return_btn");

    var page_params = OAT.Dom.uriParams();
  	for (var p in goptions) { if(page_params['goptions.'+p] != undefined) goptions[p] = page_params['goptions.'+p];}
    
  	if (fixed_sponge) {
  	  goptions.should_sponge = fixed_sponge;
  	  var inputs = document.getElementsByName('should-sponge');
      for(var i = 0; i < inputs.length; i++)
        inputs[i].disabled = true;
      $('qbe_sponge').disabled = true;
      $('adv_sponge').disabled = true;
  	}
  	
  	var show_initial_screen = true;
  	if(get_initial_credentials)	{
      OAT.AJAX.GET(get_initial_credentials, '', function(data,headers){ 
        if (data != '')
        {
          var tmp = OAT.Crypto.base64d(data).split(':');
          if (tmp.length > 0)
          {
            goptions.username = tmp[0];
            goptions.password = tmp[1];
          }
          show_initial_screen = false;
        }
      },{async:false,onerror:function(xhr){alert(xhr.getResponseText());}});
  	  if (!iSPARQL.Common.checkAuth(goptions.username,goptions.password) == true)
  	    show_initial_screen = true;
  	}

  	if (show_initial_screen)
      dialogs.goptions.show();
    else
    	goptions.initial_screen = true;
  }

  OAT.WebDav.init({imageExt:"png",silentStart:true,user:goptions.user,pass:goptions.pass});

  if (OAT.Browser.isIE) {
    tab.go (1); /* is 0-based index... */
  }
}

iSPARQL.QueryCache = {};

iSPARQL.QueryExec = function(paramsObj) {
	    // We use this to fix IE visualization problems with pre content
	    var putTextInPre = function(elm,txt){
	      if (OAT.Browser.isIE) 
	        txt = txt.replace(/\r\n/g,'\r').replace(/\n/g,'\r');
	      OAT.Dom.append([elm,OAT.Dom.text(txt)]);
	    }

	  	var params = {
			onstart:false,
			onend:false,
	  		service:goptions.service,               // The sparql endpoint to send the query to
	  		default_graph_uri:'',                   // Default graph
	  		query:'',                               // The query itself
	  		res_div:$('res_area'),                  // DIV where to put the results
	  		format:'text/html',                     // Sets format to the request and process the results accordingly.
	  		should_sponge:goptions.should_sponge,   // should-sponge param - as described in Virtuoso Docs.
	  		maxrows:0,                              // sets maxrows params to the endpoint, 0 for nolimit /limit left to server/
	  		proxy:goptions.proxy,                   // If the endpoint is http: ... and this is set, the request would be send to './remote.vsp'
	  		named_graphs:[],                        // Array of named graphs to send to the endpoint
	  		prefixes:[], // {"label":'rdf', "uri":'http://www.w3.org/1999/02/22-rdf-syntax-ns#'} // those are used when showing results
	  		imagePath:'images/',
	  		errorHandler:function(xhr) {             // function called when the endpoint returns error
				var status = xhr.getStatus();
				var response = xhr.getResponseText();
				var headers = xhr.getAllResponseHeaders();
				var data = '';
				if (!response) {
					data = 'There was a problem with your request! The server returned status code: ' + status + '<br/>\n';
					data += 'Unfortunately your browser does not allow us to show the error. ';
					data += 'This is a known bug in the Opera Browser.<br/>\n';
					data += 'However you can click this link which will open a new window with the error: <br/>\n';
					data += '<a target="_blank" href="/sparql/?' + body() + '">/sparql/?' + body() + '</a>';
				} else {
					data = response.replace(/&/g,'&amp;').replace(/</g,'&lt;');
				}
				params.cb(data,headers,'er');
			},
	  		hideRequest:false,  // if true hides the request tab in the generated response
	  		hideResponse:false, // if true hides the response tab in the generated response
	  		showQuery:false,    // if true shows the query tab in the generated response
			//RESULT PROCESSING
	        callback:function(data,headers,param) {  // function called on result
		    } /* callback */
	  	};
	  	for (var p in paramsObj) { params[p] = paramsObj[p]; }

	    if (params.service == '') {
	      alert('You must specify "Query Service Endpoint"!');
	      return;
	    }
	    
	    var content_type = 'application/x-www-form-urlencoded';
	    var ReqHeaders = {'Accept':params.format,'Content-Type':content_type};
	    var endpoint = params.service;
	    if (endpoint.match(/^http:\/\//) && params.proxy && isVirtuoso) { endpoint = './remote.vsp'; }
	    OAT.Dom.clear(params.res_div);
	  
	    // generate the request body
	    var body = function()  {
	      var body = '';

	      if (params.default_graph_uri) {
	        body += '&default-graph-uri=';
	        body += encodeURIComponent(params.default_graph_uri);
	      }

	      if (params.query) {
	        body += '&query=';
	        body += encodeURIComponent(params.query);
	      }

	      if (params.format) {
	        body += '&format=';
	        if (params.format == 'application/isparql+table')
	          body += encodeURIComponent('application/sparql-results+json'); 
	        else if (params.format == 'application/isparql+rdf-graph')
	          body += encodeURIComponent('application/rdf+xml'); 
	        else
	          body += encodeURIComponent(params.format);
	      }

	      if (params.maxrows) {
	        body += '&maxrows=';
	        body += encodeURIComponent(params.maxrows);
	      }

	      if (isVirtuoso && params.should_sponge && params.should_sponge != '') {
	        body += '&should-sponge=';
	        body += encodeURIComponent(params.should_sponge);
	      }
	      
	      if (endpoint != params.service) {
	        body += '&service=';
	        body += encodeURIComponent(params.service);
	      }
	      
	      for(var n = 0; n < params.named_graphs.length; n++) {
	        if (params.named_graphs[n] != '')
	        {
	          body += '&named-graph-uri=';
	          body += encodeURIComponent(params.named_graphs[n]); 
	        }
	      }
	      return body.substring(1);
	    }

		var o = {
			header:ReqHeaders,
			onerror:params.errorHandler,
			onstart:params.onstart || function(){OAT.Dom.show("throbber");},
			onend:params.onend || function(){OAT.Dom.hide("throbber");}
		}

		var cb = function(data) {
			iSPARQL.QueryCache[params.query] = data;
			params.callback(data);
		}
		
		if (params.query in iSPARQL.QueryCache) {
			params.callback(iSPARQL.QueryCache[params.query]);
		} else {
			OAT.AJAX.POST (endpoint, body(), cb, o);
		}
	}

iSPARQL.Advanced = function () {
	var self = this;

	var icon_reset, icon_load, icon_save, icon_saveas, icon_run, icon_load_to_qbe, icon_get_from_qbe;
	var icon_back, icon_forward, icon_start, icon_finish;
	
	this.func_reset = function() {
	  //if (tab.selectedIndex != 1 && !tab_query.window) return;
	  tab.go(tab_query);
		if(confirm('Are you sure you want to reset the query?'))
		{
		  //$("query_form").reset();
		  $("query").value = '';
  	  
      var table = $('named_graph_list');
      if (table.tBodies.length)
        OAT.Dom.unlink(table.tBodies[0]);
      $('named_graphs_cnt').innerHTML=0;
  	  //$("res_area").innerHTML = '';
      //OAT.Dom.hide(self.results_win.div);
		}
	}
	
	this.func_load = function() {
	  //if (tab.selectedIndex != 1 && !tab_query.window) return;
	  tab.go(tab_query);
	  var path = iSPARQL.Common.getFilePath();
	  var file = iSPARQL.Common.getFile();
	  //var pathDefault = iSPARQL.Common.getDefaultPath();
	    
	  var loadProcess = function(data){
  	  if (data.match(/<[\w:_ ]+>/))
        var xml = OAT.Xml.createXmlDoc(data);
      else
        var xml = {};

      $('default-graph-uri').value = '';
      if (xml.firstChild && xml.getElementsByTagName("iSPARQL").length && xml.getElementsByTagName("ISparqlDynamicPage").length) {
        var dyn_page_node = xml.getElementsByTagName("ISparqlDynamicPage")[0];
        var query_node = dyn_page_node.getElementsByTagName("query")[0];
        data = OAT.Xml.textValue(query_node);
        if (dyn_page_node.getElementsByTagName("graph").length)
          $('default-graph-uri').value = OAT.Xml.textValue(dyn_page_node.getElementsByTagName("graph")[0]);

      } else if (xml.firstChild && xml.getElementsByTagName("sparql").length) {
        var nodes = xml.getElementsByTagName("sparql");
        for (var i=0;i<nodes.length;i++)
          if (nodes[i].namespaceURI == "urn:schemas-openlink-com:xml-sql")
          {
            data = OAT.Xml.textValue(nodes[i]);
            $('default-graph-uri').value = nodes[i].getAttribute('default-graph-uri');
          }
      }

      var tmp = data.match(/#should-sponge:(.*)/i)
      if (tmp && tmp.length > 1)
      {
        $('adv_sponge').value = tmp[1].trim();
      }
      var tmp = data.match(/#service:(.*)/i)
      if (tmp && tmp.length > 1)
      {
        self.service.input.value = tmp[1].trim();
      }
	    
	    $('query').value = data;
	  }

    	var options = {
    		user:goptions.username,
    		pass:goptions.password,
    		path:path + '/',
    		file:file,
    		extension:get_file_type(goptions.last_path),
    		isDav:((goptions.login_put_type == 'http')?false:true),
    		extensionFilters:[['rq','rq','SPARQL Definitions',get_mime_type('rq')],
    		                  ['isparql','isparql','Dynamic Linked Data Page',get_mime_type('isparql')],
    		                  ['ldr','ldr','Dynamic Linked Data Resource',get_mime_type('ldr')],
    		                  ['xml','xml','XML Server Page',get_mime_type('xml')],
    		                  ['','*','All files','']
    		                 ],
        callback:function(path,fname,data){
          goptions.last_path = path + fname;
          loadProcess(data);
          //OAT.WebDav.close();
        }
      }
      	
    	OAT.WebDav.openDialog(options);
	}
	
	this.func_save = function() {
	  //if (tab.selectedIndex != 1 && !tab_query.window) return;
	  tab.go(tab_query);
    if (goptions.last_path)
    {
      self.save(goptions.last_path,get_file_type(goptions.last_path)); 
    }else 
      icon_saveas.toggle();
	}
	
	this.func_saveas = function() {
	  tab.go(tab_query);
  	  var path = iSPARQL.Common.getFilePath();
  	  var file = iSPARQL.Common.getFile();

			var options = {
    		user:goptions.username,
    		pass:goptions.password,
    		path:path + '/',
    		file:file,
    		extension:get_file_type(goptions.last_path),
    		isDav:((goptions.login_put_type == 'http')?false:true),
    		extensionFilters:[['rq','rq','SPARQL Definitions',get_mime_type('rq')],
    		                  ['isparql','isparql','Dynamic Linked Data Page',get_mime_type('isparql')],
    		                  ['ldr','ldr','Dynamic Linked Data Resource',get_mime_type('ldr')],
    		                  ['xml','xml','XML Server Page',get_mime_type('xml')]
    		                 ],
				callback:function(path,fname){
          goptions.last_path = path + fname;
          set_dav_props(goptions.last_path);
				},
    		dataCallback:function(fname,ext){
				  //OAT.Dav.SaveContentType = get_mime_type(ext);
      		return self.getSaveData(ext);
				}
			};
			OAT.WebDav.saveDialog(options);
	}
	
	this.func_run = function() {
		//if (tab.selectedIndex != 1 && !tab_query.window) return;
		tab.go(tab_query);

		// get all checked named_graphs from named graphs tab
		var graphs = [];
		named_graphs = document.getElementsByName('named_graph_cbk');

		if (named_graphs && named_graphs.length > 0) {
			for (var n = 0; n < named_graphs.length; n++) {
				// if it is checked, add to params too
				if (named_graphs[n].checked) {
					var named_graph_value = $v('named_graph_'+named_graphs[n].value);
					if (named_graph_value != '') { graphs.push(named_graph_value); }
				}
			}
		}

		var q = $v("query");
		var prefixes = [];
		var pre_arr = q.match(/prefix\s\w+:\s<\S+>/ig);
		if (pre_arr) for(var n = 0; n < pre_arr.length; n++) {
			var tmp = pre_arr[n].match(/prefix\s(\w+):\s<(\S+)>/i);
			prefixes.push({"label":tmp[1],"uri":tmp[2]});
		}

		var p = {
			query:q,
			defaultGraph:$v('default-graph-uri').trim(),
			sponge:$v("adv_sponge"),
			endpoint:self.service.input.value,
			namedGraphs:graphs
		}
		qe.execute(p);
	}
	
	this.func_load_to_qbe = function() {
	  if (OAT.Browser.isIE) return;
	  
	  //if (tab.selectedIndex != 1 && !tab_query.window) return;
	  tab.go(tab_qbe);
	  qbe.loadFromString($('query').value);
	  if ($v('qbe_graph') == '')
	    $('qbe_graph').value = $v('default-graph-uri').trim();
    $('qbe_sponge').value = $v('adv_sponge');
	}
	
	this.func_get_from_qbe = function() {
	  tab.go(tab_query);
	  if (OAT.Browser.isIE) return;

	  //if (tab.selectedIndex != 1 && !tab_query.window) return;
    $('adv_sponge').value = $v('qbe_sponge');
    $('query').value = qbe.QueryGenerate();
	}

  this.save = function(save_name,save_type) {
    var data = self.getSaveData(save_type);
    goptions.last_path = save_name;
    set_dav_props(goptions.last_path);
		var send_ref = function() { return data; }
		var recv_ref = function(data) { alert('Saved.'); }
		OAT.AJAX.PUT(save_name,send_ref(),recv_ref,{user:goptions.username,password:goptions.password,auth:OAT.AJAX.AUTH_BASIC,headers:{'Content-Type':get_mime_type(goptions.last_path)}});
  }

  this.getSaveData = function(save_type) {
		var data = "";
		
		var query = $('query');

    if(query.value.match(/#should-sponge:(.*)/i))
      query.value = query.value.replace(/#should-sponge:.*/i,'#should-sponge:' + $v('adv_sponge'));
    else
  	  query.value = '#should-sponge:' + $v('adv_sponge') + '\n' + query.value;

    if(query.value.match(/#service:(.*)/i))
      query.value = query.value.replace(/#service:.*/i,'#service:' + self.service.input.value);
    else
  	  query.value = '#service:' + self.service.input.value + '\n' + query.value;
		
		switch (save_type) {
			case "rq":
			  data += $v('query');
			break;
			case "isparql":
			case "ldr":
			  var xslt = location.pathname.substring(0,location.pathname.lastIndexOf("/")) + '/xslt/dynamic-page.xsl';
			  data += $v('query');
    		var xml = '<?xml version="1.0" encoding="UTF-8"?>\n';
        xml += '<?xml-stylesheet type="text/xsl" href="' + xslt + '"?>\n';
  			xml += '<iSPARQL xmlns="urn:schemas-openlink-com:isparql">\n';
  			xml += '<ISparqlDynamicPage>\n';
  			//xml += '<service>'+goptions.service+'</service>\n';
  			//xml += '<should_sponge>'+goptions.should_sponge+'</should_sponge>\n';
  			xml += '<proxy>'+goptions.proxy+'</proxy>\n';
  			xml += '<query>'+OAT.Dom.toSafeXML(data)+'</query>\n';
  			xml += '<graph>'+OAT.Dom.toSafeXML($v('default-graph-uri'))+'</graph>\n';
  			xml += '</ISparqlDynamicPage>\n';
  			xml += '<should_sponge>'+$v('adv_sponge')+'</should_sponge>\n';
  			xml += '<service>'+self.service.input.value+'</service>\n';
  			xml += '</iSPARQL>';
  			data = xml;
			break;
			case "xml":
			  data += $v('query');
    		var xml = '<?xml version="1.0" encoding="UTF-8"?>\n';
  			xml += '<root xmlns:sql="urn:schemas-openlink-com:xml-sql"';
  			if ($v('default-graph-uri'))
  			  xml += ' sql:default-graph-uri="' + $v('default-graph-uri') + '"';
  			xml += '><sql:sparql>'+OAT.Dom.toSafeXML(data)+'</sql:sparql></root>';
  			data = xml;
			break;
		}
	  return data;
  }

	var t = new OAT.Toolbar("toolbar");
	icon_reset = t.addIcon(0,"images/new.png","Reset",self.func_reset);
	OAT.Dom.attach("menu_reset","click",self.func_reset);
	
	icon_load = t.addIcon(0,"images/open_h.png","Open",self.func_load); 
	OAT.Dom.attach("menu_load","click",self.func_load);

	icon_save = t.addIcon(0,"images/save_h.png","Save",self.func_save); 
	OAT.Dom.attach("menu_save","click",self.func_save);

	icon_saveas = t.addIcon(0,"images/save_as_h.png","Save As...",self.func_saveas); 
	OAT.Dom.attach("menu_saveas","click",self.func_saveas);

	t.addSeparator();

	icon_run = t.addIcon(0,"images/cr22-action-player_play.png","Run Query",self.func_run); 
	OAT.Dom.attach("menu_run","click",self.func_run);

	t.addSeparator();
	
	icon_load_to_qbe = t.addIcon(0,"images/arrange.png","Visualize",self.func_load_to_qbe); 
	OAT.Dom.attach("menu_load_to_qbe","click",self.func_load_to_qbe);

	icon_get_from_qbe = t.addIcon(0,"images/compfile.png","Get from QBE",self.func_get_from_qbe); 
	OAT.Dom.attach("menu_get_from_qbe","click",self.func_get_from_qbe);
	
	if (OAT.Browser.isIE) {
	  icon_load_to_qbe.style.filter = 'alpha(opacity=30)';
	  icon_load_to_qbe.style.cursor = 'default';
	  icon_get_from_qbe.style.filter = 'alpha(opacity=30)';
	  icon_get_from_qbe.style.cursor = 'default';
	}


  this.service = new OAT.Combolist(defaultEndpoints,"/sparql");
  self.service.img.src = "images/cl.gif";
  self.service.img.width = "16";
  self.service.img.height = "16";
  $("adv_service_div").appendChild(self.service.div);
	
	/* Data Retrieval Options */
	OAT.Event.attach($("cachingSchemesCtl"),'change', function(event) {
		OAT.Anchor.close(event.target || event.srcElement); // "||" because IE has srcElement instead of target
		$("cachingSchemesTitle").innerHTML = $("cachingSchemesCtl").options[$("cachingSchemesCtl").options.selectedIndex].text;
		// = $("cachingSchemesCtl").options[$("cachingSchemesCtl").options.selectedIndex].value;
	});
	OAT.Event.attach($("pathTravSchemesSave"),'click', function(event) {
		OAT.Anchor.close(event.target || event.srcElement); // "||" because IE has srcElement instead of target
		if ($("pathTravSchemesGraball").checked) {
			$("pathTravSchemesTitle").innerHTML = 'Follow all Properties';
			// = 'grab-all';
			return;
		} else {
			$("pathTravSchemesTitle").innerHTML = 'Follow Properties';
			var out = new Array();
			var preds = $("pathTravSchemesPreds").options;
			for (var i=0;i<preds.length; i++) {
				var p = preds[i];
				if (p.selected) { 
					var v = "<" + p.value + ">";
					out.push(v);
				}
			}
			// = out;
		}		
	});
	OAT.Event.attach($("nodesCrawledCtl"),'change', function(event) {
		OAT.Anchor.close(event.target || event.srcElement); // "||" because IE has srcElement instead of target
		$("nodesCrawledTitle").innerHTML = $("nodesCrawledCtl").options[$("nodesCrawledCtl").options.selectedIndex].text;
		//  = $("nodesCrawledCtl").options[$("nodesCrawledCtl").options.selectedIndex].value;
	});
	OAT.Event.attach($("nodesRetrievedCtl"),'change', function(event) {
		OAT.Anchor.close(event.target || event.srcElement); // "||" because IE has srcElement instead of target
		$("nodesRetrievedTitle").innerHTML = $("nodesRetrievedCtl").options[$("nodesRetrievedCtl").options.selectedIndex].text;
		//  = $("nodesRetrievedCtl").options[$("nodesRetrievedCtl").options.selectedIndex].value;
	});
	var prefs = {	title:"Caching Schemes",
			content:$('cachingSchemesWin'),
			status:"",
			width:200,
			result_control:false,
			activation:"click",
			type:OAT.WinData.TYPE_RECT
	}
	OAT.Anchor.assign("cachingSchemes",prefs);
	prefs.title = "Nodes Retrieved";
	prefs.content = $('nodesRetrievedWin');
	OAT.Anchor.assign("nodesRetrieved",prefs);
	prefs.title = "Nodes Crawled";
	prefs.content = $('nodesCrawledWin');
	OAT.Anchor.assign("nodesCrawled",prefs);
	prefs.title = "Path Traversal Schemes";
	prefs.status = "Select more with Ctrl click";
	prefs.content = $('pathTravSchemesWin');
	OAT.Anchor.assign("pathTravSchemes",prefs);
	/* Custom predicates:
	   add predicate */
	OAT.Event.attach($("spongerPredsAdd"),"click",function() {
		var pred = window.prompt("Type new predicate:");
		if (pred) {
			for (var i=0;i<$("pathTravSchemesPreds").options.length;i++) {
				if ($("pathTravSchemesPreds").options[i].value==pred) {
					alert("Predicate "+pred+" is already present in the list.");
					return;
				}	
			}
			var l =$("pathTravSchemesPreds").options.length;
			$("pathTravSchemesPreds").options[l] = new Option(pred,pred);
		} else {
			alert("No predicate added.");
		}
	});
	/* remove selected predicate */
	OAT.Event.attach($("spongerPredsDel"),"click",function() {
		for (var i=0;i<$("pathTravSchemesPreds").options.length;i++)
			if ($("pathTravSchemesPreds").options[i].selected) {
				$("pathTravSchemesPreds").options[i] = null;
				i--;
			}
	});
	/* restore default set of predicates (ask only if list length is not 0) */
	OAT.Event.attach($("spongerPredsDefault"),"click",function() {
		if ($("pathTravSchemesPreds").options.length==0 || window.confirm("This will remove custom added predicates. Really restore?")) {
			$("pathTravSchemesPreds").options.length = 0;
			$("pathTravSchemesPreds").options[0] = new Option('foaf:knows','foaf:knows');
			$("pathTravSchemesPreds").options[1] = new Option('sioc:links_to','sioc:links_to');
			$("pathTravSchemesPreds").options[2] = new Option('rdfs:isDefinedBy','rdfs:isDefinedBy');
			$("pathTravSchemesPreds").options[3] = new Option('rdfs:seeAlso','rdfs:seeAlso');
			$("pathTravSchemesPreds").options[4] = new Option('owl:sameAs','owl:sameAs');
		}
	});

}

iSPARQL.Common = {
	getFilePath:function() {
	  var path = '/DAV';
	  if (goptions.username)
	    path += "/home/"+goptions.username;

    if (goptions.last_path)
      path = goptions.last_path.substring(0,goptions.last_path.lastIndexOf("/"));
    
    return path;
	},

	getFile:function() {
	  var file = '';

    if (goptions.last_path)
      file = goptions.last_path.substring(goptions.last_path.lastIndexOf("/") + 1,goptions.last_path.length);
    
    return file;
	},

	getDefaultPath:function() {
	  var path = '/DAV';
	  if (goptions.username)
	    path += "/home/"+goptions.username;
	  var pathDefault = path;
	  if (goptions.username == 'dav')
	    pathDefault = '/DAV';

    return pathDefault;
	},
	
	checkAuth:function(username,password) {
	  var auth = false;
	  if (!do_auth_verify) return true;
    OAT.AJAX.GET(do_auth_verify, 'username='+username+'&pass='+password, function(data,headers){ 
      if (data == 'OK')
        auth = true;
      else
        auth = data;
    },{async:false,onerror:function(xhr){alert(xhr.getResponseText());}});
    return auth;
	}

}

function get_file_type(file_name) {
  if (file_name.match(/isparql\.xml$/i))
    return 'isparql';
  else
    return file_name.substring(file_name.lastIndexOf(".") + 1);
}

function set_dav_props(res){
  var ext = res.substring(res.lastIndexOf('.') + 1).toLowerCase();
  if (isVirtuoso && (ext == 'xml' || ext == 'isparql' || ext == 'rq'))
  {
	  OAT.AJAX.GET('./set_dav_props.vsp?res='+encodeURIComponent(res),'',function(){return '';},{user:goptions.username,password:goptions.password,auth:OAT.AJAX.AUTH_BASIC,onerror:function(xhr){alert(xhr.getResponseText());}});
	}
}

function get_mime_type(res){
  var ext = '';
  if (res.indexOf(('.')))
    ext = res.substring(res.lastIndexOf('.') + 1).toLowerCase();
  else ext = res.toLowerCase();
  switch (ext) {
    case 'xml':
    case 'isparql':
    case 'ldr':
	    return 'text/xml';
	  default:
	    return 'text/plain';
	}
}

function prefix_insert(){
  prefix = $v('prefix');
  if ($v('query').indexOf(prefix) == -1)
    $('query').value = prefix + '\n' + $v('query');
}

function template_insert(){
  template = $v('template');
  insert_text($('query'),template);
  $('template').selectedIndex = 0;
}

function tool_invoke(){
  tool = $v('tool');
  eval(tool);
  $('tool').selectedIndex = 0;
}

function tool_put(txt){
  insert_text($('query'),txt);
}

function tool_put_line_start(txt){
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

function tool_rem_line_start(txt){
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

function tool_put_around(btxt,atxt){
  var elm = $('query');
  var start = 0;
  var end = 0;
  
  var pos = getPos(elm);
  start = pos[0];
  end   = pos[1];

  var txt = elm.value.substring(start,end);
  
  insert_text(elm,btxt + txt + atxt);
}


function insert_text(elm,txt){
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

function tools_popup(){
  if (toolswin == null)
  {
  	var topbox_ctl_xy = OAT.Dom.getLT('topbox_ctl');
    toolswin = new OAT.Window({close:1,min:0,max:0,x:topbox_ctl_xy[0] + 200,y:topbox_ctl_xy[1] + 50,width:200,height:440,title:"Statement Help"});
    toolswin.div.style.zIndex = 1013;
    $("page_query").appendChild(toolswin.div);
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

function add_named_graph(){
  var named_graph = $v('named_graph_add');
  
  if (!named_graph)
  {
    alert('Please fill in named graph value');
    return false;
  }
  
  var table = $('named_graph_list');
  
  if (!table.tBodies.length)
  {
    var body = OAT.Dom.create("tbody")
  	table.appendChild(body);
  }
  
  var row = OAT.Dom.create("tr");
  OAT.Dom.addClass(row,"odd");
  row.id = 'named_graph_list_rom'+graphs_grid_num;
  table.tBodies[0].appendChild(row);
  
  var cell_cb = OAT.Dom.create("td");
  cell_cb.innerHTML = '<input type="checkbox" name="named_graph_cbk" value="'+graphs_grid_num+'" checked="checked"/>';
  cell_cb.style.textAlign = "center";
  row.appendChild(cell_cb);

  var cell_gr = OAT.Dom.create("td");
  cell_gr.innerHTML = '<input type="text" style="width: 440px;" id="named_graph_'+graphs_grid_num+'" value="'+named_graph+'"/>';
  row.appendChild(cell_gr);

  var cell_rm = OAT.Dom.create("td");
  cell_rm.style.textAlign = "center";
  row.appendChild(cell_rm);
  var rem_btn = OAT.Dom.create("button");
  rem_btn.innerHTML = '<img src="images/edit_remove.png" title="del" alt="del"/> del';
  cell_rm.appendChild(rem_btn);
  
	OAT.Dom.attach(rem_btn,"click",function(){
    OAT.Dom.unlink(row);
    $('named_graphs_cnt').innerHTML--;
    if (!table.tBodies[0].rows.length)
      OAT.Dom.unlink(table.tBodies[0]);
	});
  
  
  graphs_grid_num++;
  
  $('named_graphs_cnt').innerHTML++;
  
  $('named_graph_add').value = '';
  
  return false;
  
}

function remove_named_graph(ind){
	OAT.Dom.unlink($('named_graph_list_rom'+ind));
	$('named_graphs_cnt').innerHTML--;
	var table = $('named_graph_list');
	if (!table.tBodies[0].rows.length) { OAT.Dom.unlink(table.tBodies[0]); }
}
