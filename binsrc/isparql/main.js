/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2007 OpenLink Software
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

var dialogs = {};

var goptions = {};
goptions.username = 'demo';
goptions.password = 'demo';
goptions.login_put_type = 'dav';
goptions.service = '/sparql';
goptions.proxy = true;
goptions.should_sponge = 'soft';
var isVirtuoso = false;

var qbe = {};
var adv = {};
var tab = {};
var page_w = 800;
var page_h = 800;
var l = new OAT.Layers(100);

function init()
{
  //OAT.Preferences.windowTypeOverride = OAT.WindowData.TYPE_AUTO;
  OAT.Preferences.imagePath = toolkitImagesPath + "/";
  OAT.AJAX.imagePath = toolkitImagesPath;
  OAT.AJAX.httpError = 0;
  $('about_oat_version').innerHTML = OAT.Preferences.version;

  OAT.Preferences.showAjax = 0;

  // determine server type, if virtuoso we show virtuoso specifics
  OAT.AJAX.GET('./version', '', function(data,headers){ 
    if (headers.match(/VIRTUOSO/i))
    {
      isVirtuoso = true;
      OAT.Dom.show('virtuoso_options');
    }
    var tmp = data.split("/");
    if (tmp && tmp.length > 1)
    {
      $('about_version').innerHTML = tmp[0];
      $('about_date').innerHTML = tmp[1];
    }
    
  },{async:true});

  OAT.Preferences.showAjax = 1;

  OAT.Anchor.zIndex = 1001;
  OAT.Anchor.imagePath = toolkitImagesPath + '/';

	var m = new OAT.Menu();
	m.noCloseFilter = "noclose";
	m.createFromUL("menu");
  
  tab = new OAT.Tab ("main_col");
  tab.add ("tab_qbe","page_qbe");
  tab.add ("tab_query","page_query");
  //tab.add ("tab_proc_opt","page_proc_opt");
  //tab.add ("menu_docs","page_docs");

  tab.go (0); /* is 0-based index... */
  
  tab.goCallback = function(oldIndex,newIndex)
  {
    
    if (oldIndex == newIndex)
    {
	    if (m.root.items[newIndex].state) m.root.items[newIndex].close();
	    else m.root.items[newIndex].open();
    }

    var menu_on,menu_off;
    
    if (newIndex == tab.keys.find($('tab_qbe')))
    {
       menu_on = $('menu_qbe_down');
       menu_off = $('menu_query_down');
    }
    if (newIndex == tab.keys.find($('tab_query')))
    {
       menu_on = $('menu_query_down');
       menu_off = $('menu_qbe_down');
    }
      
    if (menu_on) 
    {
      if (OAT.Dom.isIE())
        menu_on.style.filter = '';
      for (var i = 0; i < menu_on.childNodes.length;i++)
      {
        if (menu_on.childNodes[i].tagName && menu_on.childNodes[i].tagName.toLowerCase() == "li")
        {
          menu_on.childNodes[i].style.opacity = '';
          menu_on.childNodes[i].style.filter = '';
          menu_on.childNodes[i].style.cursor = 'pointer';
        }
      }
    }
    
    if (menu_off) 
    {
      if (OAT.Dom.isIE())
        menu_off.style.filter = 'alpha(opacity=50)';
      for (var i = 0; i < menu_off.childNodes.length;i++)
      {
        if (menu_off.childNodes[i].tagName && menu_off.childNodes[i].tagName.toLowerCase() == "li")
        {
          menu_off.childNodes[i].style.opacity = 0.5;
          menu_off.childNodes[i].style.filter = 'alpha(opacity=50)';
          menu_off.childNodes[i].style.cursor = 'default';
        }
      }
    }
    
    if (OAT.Dom.isIE() && dialogs.qbe_unsupp && newIndex == 0)
    {
      dialogs.qbe_unsupp.show();
      return;
    }
  }
  tab.goCallback(null,0);
  
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

  var sr_cl = new OAT.Combolist(iSPARQL.defaultEndpoints,"/sparql");
  sr_cl.input.name = "service";
  sr_cl.input.id = "service";
  sr_cl.list.style.zIndex = "1200";
  sr_cl.img.src = "images/cl.gif";
  sr_cl.img.width = "16";
  sr_cl.img.height = "16";
  $("sr_cl_div").appendChild(sr_cl.div);

	OAT.WebDav.init({imagePath:toolkitImagesPath + "/",imageExt:"png"});
	
	/* save */
	dialogs.save = new OAT.Dialog("Save","save_div",{width:400,modal:1});
	dialogs.save.ok = function() {
		self.save($v("save_name"),$v("savetype"));
		dialogs.save.hide();
	}
	dialogs.save.cancel = dialogs.save.hide;

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
	  var path = '/DAV';
	  if (goptions.username)
	    path += "/home/"+goptions.username;
	  var pathDefault = path;
	  if (goptions.username == 'dav')
	    pathDefault = '/DAV';
	    
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
	dialogs.goptions = new OAT.Dialog("Options","goptions",{width:450,modal:1,resize:0,zIndex:1001,onshow:dialogs_goptions_onshow,onhide:function(){OAT.Keyboard.disable('goptions');}});
	dialogs.goptions.cancel = function(){
	  dialogs.goptions.hide();
	}
	dialogs.goptions.ok = function(){
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
    if (sel_sponge != goptions.should_sponge)
    {
      $('qbe_sponge').value = sel_sponge;
      $('adv_sponge').value = sel_sponge;
    }
    goptions.should_sponge = sel_sponge;
	  dialogs.goptions.hide();
	}
  OAT.Keyboard.add('esc',function(){dialogs.goptions.cancel();},null,'goptions');
  OAT.Keyboard.add('return',function(){dialogs.goptions.ok();},null,'goptions');

	page_w = OAT.Dom.getWH('page')[0] - 20;

  var page_params = OAT.Dom.uriParams();
  
  if (page_params['default-graph-uri']) default_dgu = page_params['default-graph-uri'];
  if (page_params['query']) default_qry = page_params['query'];
  if (page_params['should-sponge']) default_spng = page_params['should-sponge'];
  
  if (default_dgu == undefined) default_dgu = '';
  $('default-graph-uri').value = default_dgu;

  if (default_qry == undefined) default_qry = 'SELECT * WHERE {?s ?p ?o}';
  $('query').value = default_qry;
  if (!fixed_sponge) fixed_sponge = '';
  else {
    if (fixed_sponge == 'local')
      default_spng = '';
    else
      default_spng = fixed_sponge;
  }
  if (default_spng == undefined) default_spng = 'soft';
  $('qbe_sponge').value = default_spng;
  $('adv_sponge').value = default_spng;
  goptions.should_sponge = default_spng;

  qbe = new iSPARQL.QBE();
  adv = new iSPARQL.Advanced();

  OAT.Dom.hide("page_loading");
  OAT.Dom.show("page_content");
  if (qbe.svgsparql)
  qbe.svgsparql.reposition();
	if (window.__inherited) {
		if (window.__inherited.username)       goptions.username = window.__inherited.username;
		if (window.__inherited.password)       goptions.password = window.__inherited.password;
		if (window.__inherited.login_put_type) goptions.login_put_type = window.__inherited.login_put_type;
		if (window.__inherited.endpoint)       goptions.service = window.__inherited.endpoint;
		if (window.__inherited.proxy)          goptions.proxy = window.__inherited.proxy;
		if (window.__inherited.should_sponge)  goptions.should_sponge = window.__inherited.should_sponge;
		if (window.__inherited.query)          qbe.loadFromString(window.__inherited.query);
    if (window.__inherited.graph)          $('qbe_graph').value = window.__inherited.graph;

  	if (window.__inherited.callback)
  	{
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

    if (window.__inherited.run)
      qbe.func_run();  
  } else {
    OAT.Dom.hide("return_btn");

    var page_params = OAT.Dom.uriParams();
  	for (var p in goptions) { if(page_params['goptions.'+p] != undefined) goptions[p] = page_params['goptions.'+p];}
    
  	if (fixed_sponge)
  	{
  	  goptions.should_sponge = fixed_sponge;
  	  var inputs = document.getElementsByName('should-sponge');
      for(var i = 0; i < inputs.length; i++)
        inputs[i].disabled = true;
      $('qbe_sponge').disabled = true;
      $('adv_sponge').disabled = true;
  	}
    dialogs.goptions.show();
  }

  if (OAT.Dom.isIE())
  {
    tab.go (1); /* is 0-based index... */
  }
}

iSPARQL.Advanced = function ()
{
	var self = this;

	var icon_reset, icon_load, icon_save, icon_saveas, icon_run, icon_load_to_qbe, icon_get_from_qbe;
	var icon_back, icon_forward, icon_start, icon_finish;
	
	this.func_reset = function() {
	  if (tab.selectedIndex != tab.keys.find($('tab_query'))) return;
		if(confirm('Are you sure you want to reset the query?'))
		{
		  $("query_form").reset();
  	  $("res_area").innerHTML = '';
      OAT.Dom.hide(self.results_win.div);
		}
	}
	
	this.func_load = function() {
	  if (tab.selectedIndex != tab.keys.find($('tab_query'))) return;
	  var path = '/DAV';
	  if (goptions.username)
	    path += "/home/"+goptions.username;
	  var pathDefault = path;
	  if (goptions.username == 'dav')
	    pathDefault = '/DAV';

    if (goptions.last_path)
      path = goptions.last_path.substring(0,goptions.last_path.lastIndexOf("/"));
	    
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

  	if (goptions.login_put_type == 'http')
  	{
      var fname = "";
      if (goptions.last_path)
        fname = goptions.last_path.substring(goptions.last_path.lastIndexOf("/") + 1);
			var name = OAT.Dav.getFile(path,fname);
			if (!name) { return; }
      goptions.last_path = name;
			OAT.AJAX.GET(name,'',loadProcess,{user:goptions.username,password:goptions.password,auth:OAT.AJAX.AUTH_BASIC});
  	} else {
    	var options = {
    		mode:'open_dialog',
    		user:goptions.username,
    		pass:goptions.password,
        pathDefault:pathDefault + '/',
    		path:path + '/',
    		filetypes:[{ext:'rq',label:'SPARQL Definitions'},{ext:'isparql',label:'Dynamic Data Web Page'},{ext:'xml',label:'XML Server Page'},{ext:'*',label:'All files'}],
        onConfirmClick:function(path,fname,data){
          goptions.last_path = path + fname;
          loadProcess(data);
          OAT.WebDav.close();
        }
      }
    	OAT.WebDav.open(options);
    	if (goptions.last_path) $('dav_filetype').value = get_file_type(goptions.last_path);
    }
	}
	
	this.func_save = function() {
	  if (tab.selectedIndex != tab.keys.find($('tab_query'))) return;
    if (goptions.last_path)
    {
      self.save(goptions.last_path,get_file_type(goptions.last_path)); 
    }else 
      icon_saveas.toggle();
	}
	
	this.func_saveas = function() {
	  if (tab.selectedIndex != tab.keys.find($('tab_query'))) return;
	  if (goptions.login_put_type == 'http')
	  {
      if (goptions.last_path)
      {
        $("save_name").value = goptions.last_path;
        $("savetype").value = get_file_type(goptions.last_path);
      }
	    dialogs.save.show();
	  } else {
  	  var path = '/DAV';
  	  if (goptions.username)
  	    path += "/home/"+goptions.username;
  	  var pathDefault = path;
  	  if (goptions.username == 'dav')
  	    pathDefault = '/DAV';

      if (goptions.last_path)
        path = goptions.last_path.substring(0,goptions.last_path.lastIndexOf("/"));

			var options = {
				mode:'save_dialog',
				onConfirmClick:function(ext){
				  OAT.Dav.SaveContentType = get_mime_type(ext);
      		return self.getSaveData(ext);
				},
				afterSave:function(path,fname){
          goptions.last_path = path + fname;
          set_dav_props(goptions.last_path);
				},
    		user:goptions.username,
    		pass:goptions.password,
        pathDefault:pathDefault + '/',
    		path:path + '/',
    		filetypes:[{ext:'rq',label:'SPARQL Definitions'},{ext:'isparql',label:'Dynamic Data Web Page'},{ext:'xml',label:'XML Server Page'}]
			};
			OAT.WebDav.open(options);
    	if (goptions.last_path) $('dav_filetype').value = get_file_type(goptions.last_path);
		}
	}
	
	this.func_run = function() {
	  if (tab.selectedIndex != tab.keys.find($('tab_query'))) return;
    var params = {
	    service:self.service.input.value,
      query:$v('query'),
      default_graph_uri:$v('default-graph-uri'),
      //maxrows:$v('maxrows'),
	    should_sponge:$v('adv_sponge'),
      format:$v('format'),
      res_div:$('res_area'),
      named_graphs:[],
      browseCallback:function(query,params){
    	  OAT.Dom.show(self.results_win.div);
        $('query').value = query;
        $('default-graph-uri').value = params.default_graph_uri;
      },
      browseStart:icon_start,
      browseBack:icon_back,
      browseForward:icon_forward,
      browseFinish:icon_finish
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
            params.named_graphs.push(named_graph_value); 
          }
        }
      }
    }
    
    params.prefixes = [];
    var pre_arr = params.query.match(/prefix\s\w+:\s<\S+>/ig);
    if (pre_arr)
      for(var n = 0; n < pre_arr.length; n++)
      {
        var tmp = pre_arr[n].match(/prefix\s(\w+):\s<(\S+)>/i);
        params.prefixes.push({"label":tmp[1],"uri":tmp[2]});
      }

	  OAT.Dom.show(self.results_win.div);
	  window.scrollTo(0,OAT.Dom.getWH(self.results_win.div)[0] - 40);
    iSPARQL.QueryExec(params);
	}
	
	this.func_load_to_qbe = function() {
	  if (OAT.Dom.isIE()) return;
	  
	  if (tab.selectedIndex != tab.keys.find($('tab_query'))) return;
	  tab.go(0);
	  qbe.loadFromString($('query').value);
	  if ($v('qbe_graph') == '')
	    $('qbe_graph').value = $v('default-graph-uri');
    $('qbe_sponge').value = $v('adv_sponge');
	}
	
	this.func_get_from_qbe = function() {
	  if (OAT.Dom.isIE()) return;

	  if (tab.selectedIndex != tab.keys.find($('tab_query'))) return;
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
	icon_reset = t.addIcon(0,"images/qbe_clear.png","Reset",self.func_reset);
	OAT.Dom.attach("menu_reset","click",self.func_reset);
	
	icon_load = t.addIcon(0,"images/fileopen.png","Open",self.func_load); 
	OAT.Dom.attach("menu_load","click",self.func_load);

	icon_save = t.addIcon(0,"images/filesave.png","Save",self.func_save); 
	OAT.Dom.attach("menu_save","click",self.func_save);

	icon_saveas = t.addIcon(0,"images/filesaveas.png","Save As...",self.func_saveas); 
	OAT.Dom.attach("menu_saveas","click",self.func_saveas);

	t.addSeparator();

	icon_start = t.addIcon(0,"images/start-22.png","First",function(){}); 
  icon_start.style.opacity = 0.3;
  icon_start.style.filter = 'alpha(opacity=30)';
  icon_start.style.cursor = 'default';
	icon_back = t.addIcon(0,"images/back-22.png","Back",function(){}); 
  icon_back.style.opacity = 0.3;
  icon_back.style.filter = 'alpha(opacity=30)';
  icon_back.style.cursor = 'default';
	icon_forward = t.addIcon(0,"images/forward-22.png","Forward",function(){}); 
  icon_forward.style.opacity = 0.3;
  icon_forward.style.filter = 'alpha(opacity=30)';
  icon_forward.style.cursor = 'default';
	icon_finish = t.addIcon(0,"images/finish-22.png","Last",function(){}); 
  icon_finish.style.opacity = 0.3;
  icon_finish.style.filter = 'alpha(opacity=30)';
  icon_finish.style.cursor = 'default';

	t.addSeparator();

	icon_run = t.addIcon(0,"images/cr22-action-player_play.png","Run Query",self.func_run); 
	OAT.Dom.attach("menu_run","click",self.func_run);

	t.addSeparator();
	
	icon_load_to_qbe = t.addIcon(0,"images/arrange.png","Visualize",self.func_load_to_qbe); 
	OAT.Dom.attach("menu_load_to_qbe","click",self.func_load_to_qbe);

	icon_get_from_qbe = t.addIcon(0,"images/compfile.png","Get from QBE",self.func_get_from_qbe); 
	OAT.Dom.attach("menu_get_from_qbe","click",self.func_get_from_qbe);

	if (OAT.Dom.isIE())
	{
	  icon_load_to_qbe.style.filter = 'alpha(opacity=30)';
	  icon_load_to_qbe.style.cursor = 'default';
	  icon_get_from_qbe.style.filter = 'alpha(opacity=30)';
	  icon_get_from_qbe.style.cursor = 'default';
	}

	this.results_win = new OAT.Window({title:"Query Results", close:1, min:0, max:0, width:page_w - 40, height:500, x:20,y:560});
	$("page_query").appendChild(self.results_win.div);
	self.results_win.content.appendChild($("res_area"));
  self.results_win.onclose = function() { OAT.Dom.hide(self.results_win.div); }
  OAT.Dom.hide(self.results_win.div);

  this.service = new OAT.Combolist(iSPARQL.defaultEndpoints,"/sparql");
  self.service.img.src = "images/cl.gif";
  self.service.img.width = "16";
  self.service.img.height = "16";
  $("adv_service_div").appendChild(self.service.div);
	
}

function get_file_type(file_name)
{
  if (file_name.match(/isparql\.xml$/i))
    return 'isparql';
  else
    return file_name.substring(file_name.lastIndexOf(".") + 1);
}

function set_dav_props(res){
  if (isVirtuoso && (!res.match(/isparql\.xml$/i)) && res.substring(res.lastIndexOf('.') + 1).toLowerCase() == 'xml')
  {
	  OAT.AJAX.GET('./set_dav_props.vsp?res='+encodeURIComponent(res),'',function(){return '';},{user:goptions.username,password:goptions.password,auth:OAT.AJAX.AUTH_BASIC});
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
	    return 'text/xml';
	  default:
	    return 'text/plain';
		}
}

var last_format = 1;

function format_select(query_obg)
{
  if (query_obg == undefined) query_obg = $('query');
  var query = query_obg.value;
  var format = $('format');
    
  if ((query.match(/construct/i) || query.match(/describe/i)) && last_format == 1)
  {
    for(var i = format.options.length; i > 0; i--)
      format.options[i] = null;
    format.options[0] = new Option('RDF Graph','application/isparql+rdf-graph');
    format.options[1] = new Option('N3/Turtle','text/rdf+n3');
    format.options[2] = new Option('RDF/XML','application/rdf+xml');
    format.selectedIndex = 0;
    last_format = 2;
  }

  if ((!query.match(/construct/i) && !query.match(/describe/i)) && last_format == 2)
  {
    for(var i = format.options.length; i > 0; i--)
      format.options[i] = null;
    format.options[0] = new Option('Table','application/isparql+table');
    format.options[1] = new Option('XML','application/sparql-results+xml');
    format.options[2] = new Option('JSON','application/sparql-results+json');
    format.options[3] = new Option('Javascript','application/javascript');
    format.options[4] = new Option('HTML','text/html');
    format.selectedIndex = 0;
    last_format = 1;
  }
  
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
  //alert(res.charAt(start - 1 - OAT.Dom.isIE()));
  if (!((res.charAt(start - 1 - OAT.Dom.isIE()) == "\n" || start == 0) && start != end))
    start = start + txt.length;
  if (cnt > 1)
    end = end + (cnt * txt.length) - (OAT.Dom.isIE() * (cnt - 1));
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
    if (!((res.charAt(start - 1 - OAT.Dom.isIE()) == "\n" || start == 0) && start != end))
      start = start - txt.length;
    if (cnt > 1)
      end = end - (cnt * txt.length) - (OAT.Dom.isIE() * (cnt - 1));
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

function add_named_graph()
{
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
