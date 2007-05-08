/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2006 Ondrej Zara and OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	OAT.Anchor.assign(elm,paramsObj);
*/

OAT.AnchorData = {
	active:false,
	window:false
}

OAT.Anchor = {
	imagePath:'/DAV/JS/images/',
	zIndex:200,
	
	appendContent:function(options) {
		if (options.content) {
			if (typeof(options.content) == "function") { options.content = options.content(); }
			var win = OAT.AnchorData.window;
			win.content.style.width = "";
			win.content.style.height = "";
			if (options.width) { win.content.style.width = options.width + "px"; }
			if (options.height) { win.content.style.height = options.height + "px"; }
			OAT.Dom.clear(win.content);
			win.content.appendChild(options.content);
		}
	},
	
	callForData:function(options,pos) {
		var win = OAT.AnchorData.window;
		options.status = 1; /* loading */
		if (options.title) { win.caption.innerHTML = options.title; }

		var ds = options.datasource;
		if (ds) { 
			ds.connection = options.connection; 
			var link = options.elm.innerHTML;
			var unlinkRef = function() {
				win.caption.innerHTML = options.elm.innerHTML;
				if (options.title) { win.caption.innerHTML = options.title; }
			}
			ds.bindRecord(unlinkRef);
			ds.bindEmpty(unlinkRef);
		}
			
		switch (options.result_control) {
			case "grid":
				var g = new OAT.FormObject["grid"](0,0,0,1); /* x,y,designMode,forbidHiding */
				g.showAll = true;
				options.content = g.elm;
				g.elm.style.position = "relative";
				g.init();
				ds.bindRecord(g.bindRecordCallback);
				ds.bindPage(g.bindPageCallback);
				ds.bindHeader(g.bindHeaderCallback);
			break;
			case "form":
				var f = false;
				var resizeRef = function() {
					win.resizeTo(f.totalWidth+5,f.totalHeight+5);
					win.anchorTo(pos[0],pos[1]);
				}
				options.content = OAT.Dom.create("div");
				var f = new OAT.Form(options.content,{onDone:resizeRef});
				var ref = function(xmlText) {
					var xmlDoc = OAT.Xml.createXmlDoc(xmlText);
					f.createFromXML(xmlDoc);
				}
				ds.bindFile(ref);
			break;
			case "timeline":
				var tl = new OAT.FormObject["timeline"](0,20,0); /* x,y,designMode */
				options.content = tl.elm;
				tl.elm.style.position = "relative";
				tl.elm.style.width = (options.width-3)+"px";
				tl.elm.style.height = (options.height-25)+"px";
				tl.init();
				/* canonic binding to output fields */
				for (var i=0;i<tl.datasources[0].fieldSets.length;i++) {
					tl.datasources[0].fieldSets[i].realIndexes = [i];
				}
				ds.bindPage(tl.bindPageCallback);
			break;
		} /* switch */
		
		OAT.Anchor.appendContent(options);

		if (!ds) { return; }

		ds.options.query = ds.options.query.replace(/\$link_name/g,link);
		options.connection.options.endpoint = options.href;
		options.connection.options.url = options.href;

		switch (ds.type) {
			case OAT.DataSourceData.TYPE_SPARQL:
				var sq = new OAT.SparqlQuery();
				sq.fromString(ds.options.query);
				var formatStr = sq.variables.length ? "format=xml" : "format=rdf"; /* xml for SELECT, rdf for CONSTRUCT */
				ds.options.query = "query="+encodeURIComponent(ds.options.query)+"&"+formatStr;
			break;
			case OAT.DataSourceData.TYPE_GDATA:
				ds.options.query = ds.options.query ? "q="+encodeURIComponent(ds.options.query) : "";
			break;
		} /* switch */
		ds.advanceRecord(0);
	},

	assign:function(element,paramsObj) {
		var elm = $(element);
		var options = {
			href:false,
			newHref:"javascript:void(0)",
			connection:false,
			datasource:false,
			content:false,
			title:false,
			imagePath:"/DAV/JS/images/",
			result_control:"grid",
			activation:"hover",
			width:300,
			height:200
		};
		for (var p in paramsObj) { options[p] = paramsObj[p]; }
		options.elm = elm;

		if (!OAT.AnchorData.window) { /* create window */
			var win = new OAT.Window({close:1,resize:1,width:options.width,height:options.height,imagePath:OAT.Anchor.imagePath,title:"Loading..."},OAT.WindowData.TYPE_RECT);
			win.div.style.zIndex = OAT.Anchor.zIndex;
			win.close = function() { OAT.Dom.hide(win.div); }
			win.onclose = win.close;
			win.close();
			document.body.appendChild(win.div);
			function checkOver() {
				var opts = OAT.AnchorData.active;
				if (!opts) { return; }
				if (opts.activation == "hover") { opts.endClose(); }
			}
			function checkOut() {
				var opts = OAT.AnchorData.active;
				if (!opts) { return; }
				if (opts.activation == "hover") { opts.startClose(); }
			}
			OAT.Dom.attach(win.div,"mouseover",checkOver);
			OAT.Dom.attach(win.div,"mouseout",checkOut);
			OAT.AnchorData.window = win;
		}

		options.status = 0; /* not initialized */
		if (!options.href && 'href' in elm) { options.href = elm.href; } /* if no oat:href provided, then try the default one */
		if (elm.tagName.toString().toLowerCase() == "a") { OAT.Dom.changeHref(elm,options.newHref); }
		
		options.displayRef = function(event) {
			var win = OAT.AnchorData.window;
			win.close(); /* close existing window */
			OAT.AnchorData.active = options;
			options.endClose();
			OAT.Dom.show(win.div);
			var pos = OAT.Dom.eventPos(event);
		
			if (!options.status) { /* first time */
				win.content.style.width = "200px";
				win.content.style.height = "50px";
				OAT.Anchor.callForData(options,pos); 
			} else { 
				OAT.Anchor.appendContent(options);
			}
			win.anchorTo(pos[0],pos[1]);
		}
		options.closeRef = function() {
			if (options.closeFlag) {
				OAT.AnchorData.window.close();
				options.endClose();
				OAT.AnchorData.active = false;
			}
		}
		options.startClose = function() {
			options.closeFlag = 1;
			setTimeout(options.closeRef,1000);
		}
		options.endClose = function() {
			options.closeFlag = 0;
		}
	
		switch (options.activation) {
			case "hover":
				OAT.Dom.attach(elm,"mouseover",options.displayRef);
				OAT.Dom.attach(elm,"mouseout",options.startClose);
			break;
			case "click":
				OAT.Dom.attach(elm,"click",options.displayRef);
			break;
		}
	}
}
OAT.Loader.featureLoaded("anchor");
