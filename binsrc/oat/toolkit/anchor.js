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
	active:false
}

OAT.Anchor = {
	callForData:function(win,options,anchor,pos) {
		var ds = options.datasource;
		ds.connection = options.connection;
		
		options.status = 1; /* loading */
		var link = anchor.innerHTML;
		var unlinkRef = function() {
			win.caption.innerHTML = anchor.innerHTML;
		}
		ds.bindRecord(unlinkRef);
		ds.bindEmpty(unlinkRef);

		switch (options.result_control) {
			case "grid":
				var g = new OAT.FormObject["grid"](0,0,0,1); /* x,y,designMode,forbidHiding */
				g.showAll = true;
				win.content.appendChild(g.elm);
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
				var f = new OAT.Form(win.content,{onDone:resizeRef});
				var ref = function(xmlText) {
					var xmlDoc = OAT.Xml.createXmlDoc(xmlText);
					f.createFromXML(xmlDoc);
				}
				ds.bindFile(ref);
			break;
			case "timeline":
				var tl = new OAT.FormObject["timeline"](0,20,0); /* x,y,designMode */
				win.content.appendChild(tl.elm);
				tl.elm.style.position = "relative";
				var dims = OAT.Dom.getWH(win.content);
				tl.elm.style.width = (dims[0]-3)+"px";
				tl.elm.style.height = (dims[1]-25)+"px";
				tl.init();
				/* canonic binding to output fields */
				for (var i=0;i<tl.datasources[0].fieldSets.length;i++) {
					tl.datasources[0].fieldSets[i].realIndexes = [i];
				}
				ds.bindPage(tl.bindPageCallback);
			break;
		} /* switch */
		
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
		if (elm.tagName.toLowerCase() != "a") { return; }
		var options = {
			href:false,
			connection:false,
			datasource:false,
			imagePath:"/DAV/JS/images/",
			result:"grid",
			activation:"hover",
			width:300,
			height:0
		};
		for (var p in paramsObj) { options[p] = paramsObj[p]; }

		var win = new OAT.Window({close:1,resize:1,width:options.width,height:options.height,title:"Loading..."},OAT.WindowData.TYPE_RECT);
		win.close = function() { OAT.Dom.unlink(win.div); }
		win.onclose = win.close;

		options.status = 0; /* not initialized */
		if (!options.href) { options.href = elm.href; } /* if no oat:href provided, then try the default one */
		elm.href = "javascript:void(0)";
		var closeFlag = 0;
		
		var startClose = function() {
			closeFlag = 1;
			setTimeout(closeRef,1000);
		}
		var endClose = function() {
			closeFlag = 0;
		}

		var displayRef = function(event) {
			if (OAT.AnchorData.active) { OAT.AnchorData.active.close(); }
			OAT.AnchorData.active = win;
			endClose();
			document.body.appendChild(win.div);
			var pos = OAT.Dom.eventPos(event);
			win.anchorTo(pos[0],pos[1]);
			if (!options.status) { OAT.Anchor.callForData(win,options,elm,pos); }
		}
		var closeRef = function() {
			if (closeFlag) {
				win.close();
				endClose();
				OAT.AnchorData.active = false;
			}
		}
		
		switch (options.activation) {
			case "hover":
				OAT.Dom.attach(elm,"mouseover",displayRef);
				OAT.Dom.attach(win.div,"mouseover",endClose);
				OAT.Dom.attach(elm,"mouseout",startClose);
				OAT.Dom.attach(win.div,"mouseout",startClose);
			break;
			case "click":
				OAT.Dom.attach(elm,"click",displayRef);
			break;
		}
	}
}
OAT.Loader.featureLoaded("anchor");
