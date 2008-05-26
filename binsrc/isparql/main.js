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
	$('about_oat_build').innerHTML = OAT.Preferences.build;
	$("throbber").src = OAT.Preferences.imagePath + "Dav_throbber.gif";

	/* build info */
	$("foot").innerHTML += " OAT Version " + OAT.Preferences.version + " Build " + OAT.Preferences.build;

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

	/* FIXME: outfactor this into separate class ? */
	var redrawSpongerOpts = function() {

		var setEndpoint = function(endpoint) {
			iSPARQL.Common.setEndpoint(endpoint);
		}

  		var showEndpoints = function() {	
  			OAT.Dom.clear('service_div');
			var c = new OAT.Combolist(defaultEndpoints,"/sparql",{name:"service",onchange:setEndpoint});
  			c.input.id = "service";
			$("service_div").appendChild(c.div);
		}

		/* toggle options */
		var toggleOptions = function() {
			if ($("endpoint").style.display=="none") {
				$("endpoint").style.display = "block";
				$("derefOpts").style.display = "block";
				$("togglerarrow").innerHTML = "&#8679;";
			} else {
				$("endpoint").style.display = "none";
				$("derefOpts").style.display = "none";
				$("togglerarrow").innerHTML = "&#8681;";
			}
		}

		/* Data Retrieval Options */

		/* cache -> get soft/replacing */
		var setGetPragma = function() {
			var a = [];
			var p = $("cachingSchemesCtl").options[$("cachingSchemesCtl").options.selectedIndex].value;
			a.push(['define get:soft',[(p)? '"'+p+'"' : p]]);
			iSPARQL.Common.setPragmas(a);
		}

		/* grab-seealso/grab-all */
		var setGrabPragma = function() {
			var a = [];

			if ($("pathTravSchemesDefault").checked) {
				a.push(['define input:grab-all',[false]]);
				a.push(['define input:grab-seealso',[false]]);
			} else
			if ($("pathTravSchemesGraball").checked) {
				a.push(['define input:grab-all',['"yes"']]);
				a.push(['define input:grab-seealso',[false]]);
			} else {
				var v = [];
				var pref = [];

				var preds = $("pathTravSchemesPreds").options;
				for (var i=0;i<preds.length;i++) {
					var p = preds[i];
					if (p.selected) { v.push("<" + p.text + ">"); pref.push(p.text + " = " + p.value); }
				}
				iSPARQL.Common.addPrefix(p);
				a.push(['define input:grab-all',[false]]);
				a.push(['define input:grab-seealso',v]);
			}

			iSPARQL.Common.setPragmas(a);
		}

		var setGrabVarPragma = function() {
			var a = [];
			var v = [];
			var vars = $("spongerVars").options;
			for (var i=0;i<vars.length;i++) {
				var item = vars[i];
				if (item.selected) { v.push("?" + item.value); }
			}
			a.push(['define input:grab-var',v]);
			iSPARQL.Common.setPragmas(a);
		}

		var setGrabLimitPragma = function() {
			var a = [];
			a.push(['define input:grab-limit', [ $("nodesRetrievedCtl").options[$("nodesRetrievedCtl").options.selectedIndex].value ] ]);
			iSPARQL.Common.setPragmas(a);
		}

		var setGrabDepthPragma = function() {
			var a = [];
			a.push(['define input:grab-depth', [ $("nodesCrawledCtl").options[$("nodesCrawledCtl").options.selectedIndex].value ] ]);
			iSPARQL.Common.setPragmas(a);
		}

		var hideSeeAlsoControls = function() {
			OAT.Dom.hide("pathTravSchemesPreds");
			OAT.Dom.hide("spongerPredsAdd");
			OAT.Dom.hide("spongerPredsDel");
			OAT.Dom.hide("spongerPredsDefault");
		}

		var showSeeAlsoControls = function() {
			OAT.Dom.show("pathTravSchemesPreds");
			OAT.Dom.show("spongerPredsAdd");
			OAT.Dom.show("spongerPredsDel");
			OAT.Dom.show("spongerPredsDefault");
		}

		var addGrabVar = function() {
			var v = window.prompt("Variable name");
			if (!v) { return; }
			var l = $("spongerVars").options.length;
			$("spongerVars").options[l++] = new Option(v,v);
			if (l>0) { OAT.Dom.show("spongerVars"); }
			setGrabVarPragma();
		}

		var delGrabVar = function() {
			for (var i=0;i<$("spongerVars").options.length;i++) {
				if ($("spongerVars").options[i].selected) {
					$("spongerVars").options[i] = null;
				}
			}
			var l = $("spongerVars").options.length;
			if (l<1) { OAT.Dom.hide("spongerVars"); }
			setGrabVarPragma();
		}

		var addSeeAlsoPredicate = function() {
			var prefix = $v("pragmaAddPropPrefix");
			var uri = $v("pragmaAddPropUri");
			if (!prefix.length || !uri.length) {
				alert("Both prefix and URI must be entered.");
				return;
			}

			for (var i=0;i<$("pathTravSchemesPreds").options.length;i++) {
				if ($("pathTravSchemesPreds").options[i].text==prefix) {
					alert("Prefix "+prefix+" is already present in the list.");
					return;
				}	
			}
			
			var l = $("pathTravSchemesPreds").options.length;
			$("pathTravSchemesPreds").options[l] = new Option(prefix,uri);
			OAT.Dimmer.hide();
			$("pragmaAddPropPrefix").value = '';
			$("pragmaAddPropUri").value = '';
			setGrabPragma();
		}

		/* remove selected predicate */
		var delSeeAlsoPredicate = function() {
			for (var i=0;i<$("pathTravSchemesPreds").options.length;i++) {
				if ($("pathTravSchemesPreds").options[i].selected) {
					$("pathTravSchemesPreds").options[i] = null;
				}
			}
			setGrabPragma();
		}

		var restoreSeeAlsoPredicates = function() {
			if ($("pathTravSchemesPreds").options.length == 0 
			    || window.confirm("This will remove custom added predicates. Really restore?")) {

				$("pathTravSchemesPreds").options.length = 0;
				$("pathTravSchemesPreds").options[0] = new Option('foaf:knows','http://xmlns.com/foaf/0.1/',true);
				$("pathTravSchemesPreds").options[1] = new Option('sioc:links_to','http://rdfs.org/sioc/ns#',true);
				$("pathTravSchemesPreds").options[2] = new Option('rdfs:isDefinedBy','http://www.w3.org/2000/01/rdf-schema#',true);
				$("pathTravSchemesPreds").options[3] = new Option('rdfs:seeAlso','http://www.w3.org/2000/01/rdf-schema#',true);
				$("pathTravSchemesPreds").options[4] = new Option('owl:sameAs','http://www.w3.org/2002/07/owl#',true);
			}
			setGrabPragma();
		}

		var showAddSeealso = function() {
			OAT.Dimmer.show($("pragmaAddProp"), {color:"#333", popup:false});
			$("pragmaAddPropPrefix").focus();
		}
	
		var hideAddSeealso = function() {
			OAT.Dimmer.hide();
			$("pragmaAddPropPrefix").value = '';
			$("pragmaAddPropUri").value = '';
		}

		/* main display toggling */
		OAT.Event.attach("opttoggler",'click', toggleOptions);

		/* pragmas */
		OAT.Event.attach($("cachingSchemesCtl"),'change', setGetPragma);
		OAT.Event.attach($("nodesCrawledCtl"),'change', setGrabDepthPragma);
		OAT.Event.attach($("nodesRetrievedCtl"),'change', setGrabLimitPragma);

		/* clicking on other traversal schemes hides grab:seealso controls */
		OAT.Event.attach("pathTravSchemesGraball",'click',function() { hideSeeAlsoControls(); setGrabPragma(); });
		OAT.Event.attach("pathTravSchemesGraballLabel",'click',function() { hideSeeAlsoControls(); setGrabPragma(); });
		OAT.Event.attach("pathTravSchemesDefault",'click',function() { hideSeeAlsoControls(); setGrabPragma(); });
		OAT.Event.attach("pathTravSchemesDefaultLabel",'click',function() { hideSeeAlsoControls(); setGrabPragma(); });

		/* and displaying shows them */
		OAT.Event.attach("pathTravSchemesSeealso",'click',function() { showSeeAlsoControls(); setGrabPragma(); });
		OAT.Event.attach("pathTravSchemesSeealsoLabel",'click',function() { showSeeAlsoControls(); setGrabPragma(); });
		OAT.Event.attach("pathTravSchemesPreds",'change',function() { setGrabPragma(); });


		/* hidden by default */
		hideSeeAlsoControls();

		/* Custom predicates: add predicate */
		OAT.Event.attach($("spongerPredsAdd"),"click",showAddSeealso);
		OAT.Event.attach($("pragmaAddPropAdd"),"click",addSeeAlsoPredicate);
		OAT.Event.attach($("pragmaAddPropCancel"),"click",hideAddSeealso);

		/* remove selected predicate */
		OAT.Event.attach($("spongerPredsDel"),"click",delSeeAlsoPredicate);

		/* restore default set of predicates (ask only if list length is not 0) */
		OAT.Event.attach($("spongerPredsDefault"),"click",restoreSeeAlsoPredicates);

		/* input grab-var */
		OAT.Event.attach($("spongerVars"),'change',setGrabVarPragma);
		OAT.Event.attach($("spongerVarsAdd"),"click",addGrabVar);
		OAT.Event.attach($("spongerVarsDel"),"click",delGrabVar);

		/* endpoint combolist */
		showEndpoints();	
		setEndpoint($("service").value);
	}

	redrawSpongerOpts();

  var tab_goCallback = function(oldIndex,newIndex) {
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
  }

  var onDock = function(newIndex) {
    if (newIndex == 0) {
      qbe.props_win.moveTo(page_w - 260,92);
      qbe.schema_win.moveTo(page_w - 260,232);
    }
  }
  
  tab = new OAT.Tab ("main_col",{dockMode:true,dockElement:"tabs",goCallback:tab_goCallback,onDock:onDock,onUnDock:onUnDock,dockWindowWidth:1000,dockWindowHeight:600});
  tab_qbe = tab.add ("tab_qbe","page_qbe");
  tab_query = tab.add ("tab_query","page_query");
  tab_results = tab.add("tab_results","page_results");

  tab.go (0); /* is 0-based index... */
  
	OAT.Dom.attach("menu_about","click",function() {
	  dialogs.about.show();
	});

  var tabgraphs = new OAT.Tab ("tabgrph_content");
  tabgraphs.add ("tabgrph_default","tabgrph_default_content");
  tabgraphs.add ("tabgrph_named","tabgrph_named_content");
  tabgraphs.go (0);

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
	dialogs.goptions.cancel = function() {
  		OAT.WebDav.init({imageExt:"png",silentStart:true,user:"demo",pass:"demo"});
	    dialogs.goptions.hide();
	}
	dialogs.goptions.ok = function() {
	  var auth = iSPARQL.Common.checkAuth($v('username'),$v('password'));
  		OAT.WebDav.init({imageExt:"png",silentStart:true,user:$v('username'),pass:$v('password')});

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
			qbe.loadFromString(query);
		qbe.svgsparql.reposition();
			$("query").value = query;
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
  
  
	OAT.Dom.attach("query","keyup",function() { iSPARQL.Common.setQuery($v("query")); });
	OAT.Dom.attach("default-graph-uri","keyup",function() { iSPARQL.Common.setDefaultGraph($v("default-graph-uri")); });
  
  
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
 

  if (OAT.Browser.isIE) {
    tab.go (1); /* is 0-based index... */
  }
}


/* FIXME: this is only used by Schemas, so it should go away.
 * Schemas should use its own query (caching mechanism)
 */
iSPARQL.QueryExec = function(optObj) {
	var self = this;

	this.options = {
		/* ajax */
		onstart:false,
		onend:false,
		onerror:false,
		errorHandler:function(xhr) {
			var status = xhr.getStatus();
			var response = xhr.getResponseText();
			var headers = xhr.getAllResponseHeaders();
			alert(response);
		},

	  	endpoint:"/sparql",
	  	query:false,
	  	format:"text/html",
	  	sponge:false,
	  	maxrows:0,
	    callback:function(data,headers,param) {}
	};

	this.cache = {};

	this.go = function(optObj) {
		var opts = {};
		for (var p in self.options) { opts[p] = self.options[p]; }
		for (var p in optObj) { opts[p] = optObj[p]; }

		if (opts.query in self.cache) { 
			if (opts.callback) { opts.callback(self.cache[opts.query]); }
			return;
		}

		var req = {
			query:opts.query,
			format:opts.format,
		};

		if (opts.defaultGraph && !opts.query.match(/from *</i)) { req["default-graph-uri"] = opts.defaultGraph; }
		if (opts.limit) { req["maxrows"] = opts.limit; }
		if (opts.sponge && self.options.virtuoso) { req["should-sponge"] = opts.sponge; }

		var arr = [];
		for (var p in req) {
			arr.push(p+"="+encodeURIComponent(req[p]));
		}
		var query = arr.join("&");

		var callback = function(data) {
			self.cache[opts.query] = data;
			if (opts.callback) { opts.callback(data); }
		}

		var o = {
			onerror:opts.errorHandler,
			onstart:opts.onstart || function() { OAT.Dom.show("throbber"); },
			onend:opts.onend || function() { OAT.Dom.hide("throbber"); }
		}
		
		OAT.AJAX.POST (opts.endpoint, query, callback, o);
	}

	self.go(optObj);
}

iSPARQL.Advanced = function () {
	var self = this;

	this.func_reset = function() {
		tab.go(tab_query);
		if(confirm('Are you sure you want to reset the query?')) {
			iSPARQL.Common.reset();
			self.redraw();
		}
	}

	this.redraw = function() {
		/* query */
		$("query").value = iSPARQL.dataObj.query;

		/* default graph */
		$("default-graph-uri").value = iSPARQL.dataObj.defaultGraph;

		var findPragma = function(name) {
			for (var i=0;i<iSPARQL.dataObj.pragmas.length;i++) {
				var pragma = iSPARQL.dataObj.pragmas[i];
				if (pragma[0] == name) { return pragma; } 
			}
			return false;
		}

		var setPragmaSelect = function(pragma,select) {
			var p = findPragma(pragma) || false;
			if (!p) { return; }

			var opts = $(select).options;
			for (var i=0;i<opts.length;i++) {
				var opt = opts[i];
				if (opt.value == pragma[1][0]) { 
					$(select).options[i].selectedIndex = i; 
					break; 
				}
			}
		}

		var setPragmaRadio = function(pragma,radio) {
			var p = findPragma(pragma) || false;
			if (!p) { return; }
			$(radio).checked = true;
		}

		var setPragmaList = function(pragma,select) {
			var p = findPragma(pragma) || false;
			if (!p) { return; }
		
			var values = pragma[1];
			var opts = $(select).options;
			for (var i=0;i<opts.length;i++) {
				var opt = opts[i];
				var index = values.find("<" + opt.value + ">");
				$(select).options[i].selected = (index == -1)? false : true; 
			}
		}

		/* pragmas */
		setPragmaSelect('define input:grab-limit',"nodesRetrievedCtl");
		setPragmaSelect('define input:grab-depth',"nodesCrawledCtl");
		setPragmaSelect('define get:soft',"cachingSchemesCtl");
		setPragmaRadio('define input:grab-all',"pathTravSchemesGraball");
		setPragmaRadio('define input:grab-seealso',"pathTravSchemesSeealso");
		setPragmaList('define input:grab-seealso',"pathTravSchemesPreds");

		/* named graphs */
      	var table = $('named_graph_list');
      	if (table.tBodies.length) { OAT.Dom.unlink(table.tBodies[0]); }
		$('named_graphs_cnt').innerHTML = 0;

		for (var i=0;i<iSPARQL.dataObj.namedGraphs.length;i++) {
			add_named_graph(iSPARQL.dataObj.namedGraphs[i]);
		}
	}
	
	this.func_load = function() {
		var callback = function(path,file,data) {
			iSPARQL.dataObj = data;
			self.redraw();
		}

		iSPARQL.IO.load(callback);
	}
	
	this.func_save = function() {
    	self.save(); 
	}
	
	this.func_saveas = function() {
		self.save();
	}
	
	this.func_run = function() {
		/* FIXME: what to do with these schmas/prefixes */
		/*
		var prefixes = [];
		var q = iSPARQL.dataObj.query;
		var allPrefixes = q.match(/prefix\s+\w+:\s+<\S+>/mig) || [];		
		for(var i=0;i<allPrefixes.length;i++) {
			var cur = allPrefixes[i];
			var pref = cur.match(/prefix\s+(\w+):\s+<(\S+)>/i);
			prefixes.push({"label":pref[1],"uri":pref[2]});
		}

		FIXME: catch also pragmas here
		*/

		var o = {
			query:iSPARQL.dataObj.query,
			defaultGraph:iSPARQL.dataObj.defaultGraph,
			endpoint:iSPARQL.dataObj.endpoint,
			pragmas:iSPARQL.dataObj.pragmas,
			namedGraphs:iSPARQL.dataObj.namedGraphs,
			callback:iSPARQL.Common.setData
		}
		qe.execute(o);
	}
	
	this.func_load_to_qbe = function() {
		if (OAT.Browser.isIE) { return; }
		tab.go(tab_qbe);
	  
		qbe.loadFromString($('query').value);
	 	 if ($v('qbe_graph') == '')
	    	$('qbe_graph').value = $v('default-graph-uri').trim();
	    $('qbe_sponge').value = $v('adv_sponge');
		//qbe.redraw();
	}
	
	this.func_get_from_qbe = function() {
	  tab.go(tab_query);
	  if (OAT.Browser.isIE) return;

	  //if (tab.selectedIndex != 1 && !tab_query.window) return;
    $('adv_sponge').value = $v('qbe_sponge');
		iSPARQL.Common.setQuery(qbe.QueryGenerate());
		iSPARQL.Common.setDefaultGraph($v('qbe_graph'));
		self.redraw();	
	}

	this.save = function() {
		iSPARQL.IO.save(iSPARQL.dataObj);
	}

	var t = new OAT.Toolbar("toolbar");
	t.addIcon(0,"images/new.png","Reset",self.func_reset);
	t.addIcon(0,"images/open_h.png","Open",self.func_load); 
	t.addIcon(0,"images/save_h.png","Save",self.func_save); 
	t.addIcon(0,"images/save_as_h.png","Save As...",self.func_saveas); 
	t.addSeparator();
	t.addIcon(0,"images/cr22-action-player_play.png","Run Query",self.func_run); 

	/* msie does not support svg yet */
	if (!OAT.Browser.isIE) {
		t.addSeparator();
		t.addIcon(0,"images/arrange.png","Visualize",self.func_load_to_qbe); 
		t.addIcon(0,"images/compfile.png","Get from QBE",self.func_get_from_qbe);
	}
}

iSPARQL.Common = {

	log:function(msg) {
		if(!!(window.console) && iSPARQL.Preferences.debug) { 
			window.console.log(msg);
		}
	},

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
	},

	setPragmas:function(pragmas) {
		for (var i=0;i<pragmas.length;i++) {
			var pragma = pragmas[i];
			
			/* look for existing pragma defs in dataObj */
			var index = -1;
			for (var j=0;j<iSPARQL.dataObj.pragmas.length;j++) {
				var searched = iSPARQL.dataObj.pragmas[j];
				if (searched[0] == pragma[0]) { index = j; break; }
			}

			/* now, if our value is false, then delete them */
			var value = pragma[1][0];

			if (value) {
				if (index == -1) { iSPARQL.dataObj.pragmas.push(pragma); }
				else { iSPARQL.dataObj.pragmas[index] = pragma; }
			} else {
				if (index != -1) { iSPARQL.dataObj.pragmas.splice(index,1); }
			}
		}
		iSPARQL.Common.log(iSPARQL.dataObj.pragmas);
	},

	clearPragmas:function() {
		iSPARQL.dataObj.pragmas = [];
	},

	setEndpoint:function(endpoint) {
		iSPARQL.dataObj.endpoint = endpoint || "";
		iSPARQL.Common.log(iSPARQL.dataObj.endpoint);
	},

	addNamedGraph:function(graph) {
		var index = iSPARQL.dataObj.namedGraphs.find(graph);
		if (index != -1) { return; }
		iSPARQL.dataObj.namedGraphs.push(graph);
		iSPARQL.Common.log(iSPARQL.dataObj.namedGraphs);
	},

	removeNamedGraph:function(graph) {
		var index = iSPARQL.dataObj.namedGraphs.find(graph);
		if (index == -1) { return; }
		iSPARQL.dataObj.namedGraphs.splice(index,1);
		iSPARQL.Common.log(iSPARQL.dataObj.namedGraphs);
	},

	addGraph:function(graph) {
		var index = iSPARQL.dataObj.graphs.find(graph);
		if (index != -1) { return; }
		iSPARQL.dataObj.graphs.push(graph);
		iSPARQL.Common.log(iSPARQL.dataObj.graphs);
	},

	addPrefix:function(prefix) {
		var index = iSPARQL.dataObj.prefixes.find(prefix);
		if (index != -1) { return; }
		iSPARQL.dataObj.prefixes.push(prefix);
		iSPARQL.Common.log(iSPARQL.dataObj.prefixes);
	},

	removeGraph:function(graph) {
		var index = iSPARQL.dataObj.graphs.find(graph);
		if (index == -1) { return; }
		iSPARQL.dataObj.graphs.splice(index,1);
		iSPARQL.Common.log(iSPARQL.dataObj.graphs);
	},

	setQuery:function(query) {
		iSPARQL.dataObj.query = query;
		iSPARQL.Common.log(iSPARQL.dataObj.query);
	},

	setDefaultGraph:function(graph) {
		iSPARQL.dataObj.defaultGraph = graph;
		iSPARQL.Common.log(iSPARQL.dataObj.defaultGraph);
	},

	setData:function(data) {
		iSPARQL.dataObj.data = data;
		iSPARQL.Common.log(iSPARQL.dataObj.data);
	},

	reset:function() {
		iSPARQL.dataObj = {
			data:false,
			query:"",
			endpoint:"",
			defaultGraph:"",
			graphs:[],
			namedGraphs:[],
			prefixes:[],			/* FIXME: prefixes? */
			pragmas:{},
			canvas:false
		};
		this.log(iSPARQL.dataObj);
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

function add_named_graph(graph) {
	var named_graph = $v('named_graph_add') || graph;
  
	if (!named_graph) {
	    alert('Please fill in named graph value.');
    	return false;
	}

	if (iSPARQL.dataObj.namedGraphs.find(named_graph) != -1) {
		alert('Graph already present.');
		return false;
	}
  
	var table = $('named_graph_list');
  
	if (!table.tBodies.length) {
	    var body = OAT.Dom.create("tbody");
  		table.appendChild(body);
	}
  
	var row = OAT.Dom.create("tr");

	var boxCell = OAT.Dom.create("td");
	boxCell.style.textAlign = "center";

	var boxCheck = OAT.Dom.create("input");
	boxCheck.type = "checkbox";
	boxCheck.checked = "checked";

	var graphCell = OAT.Dom.create("td");
	graphCell.innerHTML = '<input type="text" style="width: 440px;" value="'+named_graph+'"/>';

	var delCell = OAT.Dom.create("td");
	delCell.style.textAlign = "center";

	var delButton = OAT.Dom.create("button");
	delButton.innerHTML = '<img src="images/edit_remove.png" title="del" alt="del"/> del';

	OAT.Dom.append([delCell,delButton],[boxCell,boxCheck],[row,boxCell,graphCell,delCell],[table.tBodies[0],row]);
  
	OAT.Dom.attach(delButton,"click",function() {
	    OAT.Dom.unlink(row);
    	$('named_graphs_cnt').innerHTML--;
	    if (!table.tBodies[0].rows.length)
    		OAT.Dom.unlink(table.tBodies[0]);
		iSPARQL.Common.removeNamedGraph(named_graph);
	});
  
	OAT.Dom.attach(boxCheck,"click",function() {
		if (iSPARQL.dataObj.namedGraphs.find(named_graph) == -1) {
			iSPARQL.Common.addNamedGraph(named_graph);
		} else {
			iSPARQL.Common.removeNamedGraph(named_graph);
		}
	});
		
	iSPARQL.Common.addNamedGraph(named_graph);  
  
	$('named_graphs_cnt').innerHTML++;
	$('named_graph_add').value = '';
}
