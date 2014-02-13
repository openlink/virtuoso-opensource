/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2014 OpenLink Software
 *
 *  See LICENSE file for details.
 */
var rdfb = false;
if (typeof(defaultGraph) == 'undefined') var defaultGraph = false;
var dialogs = {};

var http_cred = {
	user:"demo",
	password:"demo",
	isDav:true
};

var ext_rdf = [
	["rq","rq","Saved SPARQL Query"],
	["isparql","isparql","Saved iSPARQL Query"],
	["n3","n3","N3 RDF"],
	["ttl","ttl","Turtle RDF"],
	["xml","xml","RDF/XML"],
	["rdf","rdf","RDF/XML"]
];
var ext_open = [
	["wqx","wqx","Web Query"]
];
var ext_save = [
	["wqx","wqx","Web Query"]
];

var Search = {
	template:'CONSTRUCT { ?s ?p ?o } {dsn} WHERE { ?s ?p ?o . ?o bif:contains "\'{query}\'"}',
	go:function() {
		var q = $v("search_query");
		if (!q) { return; }
		var dsn = [];

		/*
		for (var i=0;i<rdfb.store.items.length;i++) {
			var item = rdfb.store.items[i];
			rdfb.store.disable(item.href);
			if (item.href.match(/^http/i)) { dsn.push(item.href); }
		}
		*/

		if (dsn.length || defaultGraph) { dsn.unshift(defaultGraph); }
		for (var i=0;i<dsn.length;i++) {
			dsn[i] = (i ? " FROM NAMED " : " FROM ") + "<"+dsn[i]+"> ";
		}
		var text = Search.template.replace(/{dsn}/,dsn.join("")).replace(/{query}/,q);
		rdfb.store.clear();
		rdfb.store.removeAllFilters();
		rdfb.store.addSPARQL(text);
	}
}

var IO = {
	save:function() {
		var xslStr = '<?xml-stylesheet type="text/xsl" href="'+$v("options_xslt")+'rdfbrowser.xsl"?>';
		var xml = rdfb.toXML(xslStr);
		var options = {
			extensionFilters:ext_save,
			dataCallback:function(file,ext) { return xml; },
			callback:function() { alert("Saved."); }
		};
		OAT.WebDav.saveDialog(options);
	},

	doLoadWQX:function(filename,ignoreCredentials) {
		var callback = function(xmlDoc) { rdfb.fromXML(xmlDoc); }
		var o = {
			auth:OAT.AJAX.AUTH_BASIC,
			user:http_cred.user,
			pass:http_cred.password,
			type:OAT.AJAX.TYPE_XML
		}
		if (ignoreCredentials) { o.auth = OAT.AJAX.AUTH_NONE; }
		OAT.AJAX.GET(filename,false,callback,o);
	},

	loadSession:function() {
		var options = {
			extensionFilters:ext_open,
			callback:function(path,name,data){
				var xmlDoc = OAT.Xml.createXmlDoc(data);
				rdfb.fromXML(xmlDoc);
			}
		};
		OAT.WebDav.openDialog(options);
	},

	loadRDF:function() {
		var options = {
			extensionFilters:ext_rdf,
			callback:function(path,name,data){
				if (name.match(/\.rq$/)) {
					rdfb.fromRQ(data,true);
				} else if (name.match(/\.isparql$/)) {
					var xmlDoc = OAT.Xml.createXmlDoc(data);
					var q = xmlDoc.getElementsByTagName("query")[0];
					rdfb.fromRQ(OAT.Xml.textValue(q),true);
				} else {
					rdfb.store.url.value = path+name;
					rdfb.store.loadFromInput();
				}
			}
		};
		OAT.WebDav.openDialog(options);
	}

}

function RDFBInit() {
	/* xslt path */
	OAT.Preferences.xsltPath = '/ods/oat/xslt/'
	$("options_xslt").value = OAT.Preferences.xsltPath;

	/* ajax http errors */
	$("options_http").checked = (OAT.Preferences.httpError == 1 ? true : false);
	OAT.AJAX.httpError = OAT.Preferences.httpError;
	OAT.Event.attach("options_http","change",function(){OAT.AJAX.httpError = ($("options_http").checked ? 1 : 0);});

OAT.Dereference = {
	go:function(url,callback,optObj)
	     {
	       if (url.match(/^http/i))
		 { /* Virtuoso proxy: */
		   var r = url.match(/^http:\/\/([^@\/]+@)?(.*)/);
		   var user = (r[1] ? r[1].substring(0,r[1].length-1) : false);
                   var iri = "http://"+r[2];
		   var encoded = encodeURIComponent(iri);
		   if (defaultGraph && -1 != iri.lastIndexOf (defaultGraph))
		     encoded = "/proxy?url="+encoded;
		   else
		     {
		       encoded = "/proxy?url="+encoded+"&force=rdf";
		       if (user)
			 {
			   encoded += "&login="+encodeURIComponent(user);
			 }
		       if (url.match(/\.n3$/))
			 {
			   encoded += "&output-format=n3";
			 }
		     }
		 }
	       else if (url.match(/^urn:/i) || url.match(/^doi:/i) || url.match(/^oai:/i))
		 { /* Virtuoso proxy: */
		   var encoded = encodeURIComponent(url);
		   encoded = "/proxy?url="+encoded+"&force=rdf";
		   if (url.match(/\.n3$/))
		     {
		       encoded += "&output-format=n3";
		     }
		 }
	       else
		 {
		   var encoded = url;
		 }
	       optObj.headers = { Accept:"application/rdf+xml" };
	       OAT.AJAX.GET(encoded,false,callback,optObj);
	     }
}

	/* options */
        /*
	dialogs.options = new OAT.Dialog("Options","options",{width:400,modal:1});
	dialogs.options.ok = function() {
		rdfb.options.appActivation = $v("options_app");
		dialogs.options.hide();
		rdfb.redraw();
	}
	dialogs.options.cancel = dialogs.options.hide;
        */

	/* about */
        /*
	dialogs.about = new OAT.Dialog("About","about_div",{width:400,modal:1});
	dialogs.about.ok = dialogs.about.hide;
	dialogs.about.cancel = dialogs.about.hide;
        */

	/* connection */
        /*
	dialogs.connection = new OAT.Dialog("Connection Setup","connection",{width:500,modal:1,buttons:1});
	dialogs.connection.ok = function() {
		http_cred.user = $v("user");
		http_cred.password = $v("password");
		http_cred.isDav = ($v("login_put_type") == "1");
		dialogs.connection.hide();
		var o = {
			user:http_cred.user,
			pass:http_cred.password,
			isDav:http_cred.isDav,
			path:"/DAV/home/"+http_cred.user+"/"
		}
		OAT.WebDav.init(o);
		// also look for default graph
		var ref = function(xmlDoc) {
			var nodes = OAT.Xml.getElementsByLocalName(xmlDoc.documentElement,"DefaultGraph");
			if (nodes && nodes.length) { defaultGraph = OAT.Xml.textValue(nodes[0]); }
		}
		OAT.AJAX.GET("/sparql?ini",null,ref,{type:OAT.AJAX.TYPE_XML,onerror:function(){}});
	}
	dialogs.connection.cancel = function() {
		dialogs.connection.hide();
		// init with default options
		OAT.WebDav.init();
	}
        */

	/* menu */
        /*
	var m = new OAT.Menu();
	m.noCloseFilter = "noclose";
	m.createFromUL("menu");
	OAT.Event.attach("menu_about","click",dialogs.about.show);
	OAT.Event.attach("menu_options","click",dialogs.options.show);
	OAT.Event.attach("menu_save","click",IO.save);
	OAT.Event.attach("menu_load","click",IO.loadSession);
	OAT.Event.attach("menu_rdf","click",IO.loadRDF);
        */

	OAT.Dom.unlink("throbber");
	var c = $("throbber_content");
	var p = $("placeholder");
	while (c.firstChild) { p.appendChild(c.firstChild); }
	OAT.Dom.unlink(c);

	/* browser */
	rdfb = new OAT.RDFBrowser("browse",{});
	rdfb.addTab("navigator","Navigator",{});
	rdfb.addTab("browser","Browser",{});
	rdfb.addTab("triples","Raw triples",{});
	rdfb.addTab("svg","SVG Graph",{});
	// rdfb.addTab("map","Yahoo Map",{provider:OAT.MapData.TYPE_Y});
  rdfb.addTab("map","Google Map",{provider:OAT.Map.TYPE_G3});
	rdfb.addTab("timeline","Timeline",{});
	rdfb.addTab("images","Images",{});
	rdfb.addTab("tagcloud","Tag Cloud",{});
	rdfb.addTab("fresnel","Fresnel",{defaultURL:""});

	/* search */
	OAT.Event.attach("search_btn","click",Search.go);
	OAT.Event.attach("search_query","keypress",function(event) {
		if (event.keyCode == 13) { Search.go(); }
	});


	/* history */
	if (window.location.href.match(/history/)) {
		var hs = OAT.Dom.create("select");
		OAT.Dom.option("","",hs);
		for (var i=0;i<window.history.length;i++) {
			OAT.Dom.option(window.history[i],window.history[i],hs);
		}
		var div = OAT.Dom.create("div");
		div.innerHTML = "Browsing history: ";
		div.appendChild(hs);
		rdfb.store.div.parentNode.insertBefore(div,rdfb.store.div);
		hs.selectedIndex = 0;
		OAT.Event.attach(hs,"change",function() {
			if (hs.value != "") { rdfb.store.url.value = hs.value; }
		});
	}

	var historyRef = function() {
		var ch = $("options_history");
		if (ch.checked) {
			try {
				netscape.security.PrivilegeManager.enablePrivilege('UniversalBrowserRead');
			} catch (e) {
			alert(e);
				ch.checked = false;
			}
			/* decide based on selection */
		}
	}
	OAT.Event.attach("options_history","change",historyRef);

	/* load */
        /*
	var obj = OAT.Dom.uriParams();
	if ("load" in obj && obj.load != "") {
		IO.doLoadWQX(obj.load,true);
	} else {
		$('about_oat_version').innerHTML = OAT.Preferences.version;
		var ver = "$Id$";
		var r = ver.match(/main\.js,v ([^ ]+)/);
		$('about_version').innerHTML = r[1];
		dialogs.connection.show();
	}
        */
}
