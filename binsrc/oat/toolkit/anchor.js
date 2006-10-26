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

OAT.Anchor = {
	callForData:function(win,options,anchor) {
		options.status = 1; /* loading */
		var ds = new OAT.DataSource(50);
		ds.init();
		var link = anchor.innerHTML;
		var unlinkRef = function() {
			win.caption.innerHTML = anchor.innerHTML;
		}
		ds.bindRecord(unlinkRef);
		
		switch (options.result) {
			case "grid":
				var g = new OAT.FormObject["grid"](0,0,0,1); 
				g.showAll = true;
				win.content.appendChild(g.elm);
				g.elm.style.position = "relative";
				g.init();
				ds.bindRecord(g.bindRecordCallback);
				ds.bindPage(g.bindPageCallback);
				ds.bindHeader(g.bindHeaderCallback);
			break;
		}
		
		switch (options.type) {
			case "sql":
				var query = options.q.replace(/\$link_name/g,link);
				debug.push(options);
				options.connection.options.endpoint = options.href;
				ds.setQuery(query);
			break;
		}
		ds.setConnection(options.connection);
		ds.advanceRecord(0);
	},

	assign:function(element,paramsObj) {
		var elm = $(element);
		if (elm.tagName.toLowerCase() != "a") { return; }
		var options = {
			connection:false,
			dsn:"DSN=Local_Instance",
			type:"sql",
			imagePath:"/DAV/JS/images/",
			q:"SELECT CategoryID, CategoryName FROM Demo.demo.Categories",
			result:"grid",
			activation:"hover"
		};
		for (var p in paramsObj) { options[p] = paramsObj[p]; }

		var win = new OAT.Window({close:1,resize:1,width:300,title:"Loading..."},OAT.WindowData.TYPE_ROUND);
		win.close = function() { OAT.Dom.unlink(win.div); }
		win.onclose = win.close;

		options.status = 0; /* not initialized */
		options.href = elm.href;
		elm.href = "javascript:void(0)";
		var closeFlag = 0;
		
		var startClose = function() {
			closeFlag = 1;
			setTimeout(closeRef,1000);
		}
		var endClose = function() {
			closeFlag = 0;
		}
		var moveRef = function(event) {
			endClose();
			var pos = OAT.Dom.eventPos(event);
			var dims = OAT.Dom.getWH(win.div);
			var x = Math.round(pos[0] - dims[0]/2);
			var y = pos[1] + 20;
			if (x < 0) { x = 10; }
			win.div.style.left = x+"px";
			win.div.style.top = y+"px";
		}
		var displayRef = function(event) {
			endClose();
			document.body.appendChild(win.div);
			moveRef(event);
			if (!options.status) { OAT.Anchor.callForData(win,options,elm); }
		}
		var closeRef = function() {
			if (closeFlag) {
				win.close();
				endClose();
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
OAT.Loader.pendingCount--;
