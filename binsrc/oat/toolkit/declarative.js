/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2012 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	Declarative markup scanner & initializer:

	OAT.Declarative.shouldBeProcessed = function(domNode)
	OAT.Declarative.execute()
	OAT.Declarative.scanningFinished()
*/

OAT.Declarative = {
	objects:{},
	toBeProcessed:[], /* elements found by scanner, deferred processing */

	shouldBeProcessed:function(domNode) {
		/*
			samples of OAT-markup elements
			<div openajaxType="oat:tab" openajaxParams="{x:1,y:2}" oat:foo="bar">
		*/
		if (domNode.getAttribute("openajaxType") && domNode.getAttribute("openajaxType").toString().split(":")[0].toLowerCase() == "oat") { return true; }
		return false;
	},

	scan:function() { /* to be replaced by OpenAjax Alliance's Event Hub Scanner */
		var tmpAll = document.getElementsByTagName("*"); /* dynamic array */
		var all = [];
		for (var i=0;i<tmpAll.length;i++) { all.push(tmpAll[i]); } /* static array */
		for (var i=0;i<all.length;i++) {
			if (OAT.Declarative.shouldBeProcessed(all[i])) { OAT.Declarative.process(all[i]); }
		}
	},

	process:function(domNode) {	/* process dom node, containing declarative markup for OAT */
		OAT.Declarative.toBeProcessed.push(domNode);
	},

	scanningFinished:function() { /* process deferred elements */
		/*
			A. categorize - 0: ordinary widgets, 1: tab, dock & panelbar, 2: tab, dock & panelbar parts
			B. create widgets from end of the queue
		*/
		var addObject = function(type,o) {
			if (type in OAT.Declarative.objects) { OAT.Declarative.objects[type].push(o); } else { OAT.Declarative.objects[type] = [o];	}
		}
		var partTwo = ["tab","panelbar","dock"];
		var partThree = ["tab_content","panelbar_content","dock_content"];

		var queue = [[],[],[]];
		for (var i=0;i<OAT.Declarative.toBeProcessed.length;i++) {
			var elm = OAT.Declarative.toBeProcessed[i];
			var type = elm.getAttribute("openajaxType").toString().split(":");
			var name = type[1];
			var params = {};
			for (var j=0;j<elm.attributes.length;j++) {
				var a = elm.attributes[j];
				var s = a.nodeName.split(":");
				if (s[0] == "oat") { params[s[1]] = a.nodeValue; }
			}
			var jsonParams = elm.getAttribute("openajaxParams");
			if (jsonParams) {
				var json = OAT.JSON.deserialize(jsonParams);
				for (var p in json) { params[p] = json[p]; }
			}
			var parentArr = queue[0]; /* choose right queue, according to object type */
			if (partTwo.find(name) != -1) { parentArr = queue[1]; }
			if (partThree.find(name) != -1) { parentArr = queue[2]; }
			var obj = {name:name,params:params,elm:elm};
			parentArr.unshift(obj);
		}
		/* normal widgets */
		for (var i=0;i<queue[0].length;i++) {
			var o = queue[0][i];
			switch (o.name) {
				case "drag":
					var target = o.params.target ? o.params.target : o.elm;
					OAT.Drag.create(o.elm,p.params.target);
				break;
				case "resize":
					var target = o.params.target ? o.params.target : o.elm;
					OAT.Drag.create(o.elm,target);
				break;
				case "tree":
					var t = new OAT.Tree(o.params);
					t.assign(o.elm,true);
					addObject("tree",t);
				break;
				case "rounddiv":
					OAT.SimpleFX.roundDiv(o.elm,o.params);
				break;
				case "roundimg":
					OAT.SimpleFX.roundDiv(o.elm,o.params);
				break;
				case "shadow":
					OAT.SimpleFX.shadow(o.elm,o.params);
				break;
				case "shader":
					var target = o.params.target ? o.params.target : o.elm;
					OAT.SimpleFX.shader(o.elm,target);
				break;
				case "validation":
					OAT.Validation.create(o.elm,o.params.type, o.params);
				break;
				case "grid":
					var g = new OAT.Grid(o.elm,{autoNumber:o.params.autonumber,allowHiding:o.params.allowhiding});
					g.fromTable(o.params.table);
					addObject("grid",g);
				break;
				case "anchor":
					o.params.connection = OAT.JSON.deserialize(o.params.connection);
					o.params.datasource = OAT.JSON.deserialize(o.params.datasource);
					OAT.Anchor.assign(o.elm,o.params);
				break;
			} /* switch */
		}

		/* tabs, docks, panelbars */
		for (var i=0;i<queue[1].length;i++) {
			var o = queue[1][i];
			switch (o.name) {
				case "tab":
					var t = new OAT.Tab(o.elm);
					addObject("tab",t);
				break;
				case "dock":
					var d = new OAT.Dock(o.elm,o.params.columns);
					addObject("dock",d);
				break;
				case "panelbar":
					var p = new OAT.Panelbar(o.elm,o.params.fadedelay);
					addObject("panelbar",p);
				break;
			} /* switch */
		}

		/* tabs, docks, panelbars - parts */
		for (var i=0;i<queue[2].length;i++) {
			var o = queue[2][i];
			switch (o.name) {
				case "tab_content":
					var pid = o.params.parent;
					for (var j=0;j<OAT.Declarative.objects["tab"].length;j++) {
						var t = OAT.Declarative.objects["tab"][j];
						if (t.div == $(pid)) { t.add(o.params.clicker,o.elm); }
					}
				break;
				case "dock_content":
					var pid = o.params.parent;
					for (var j=0;j<OAT.Declarative.objects["dock"].length;j++) {
						var d = OAT.Declarative.objects["dock"][j];
						if (d.div == $(pid)) { d.addObject(o.params.column,o.params.clicker,o.elm); }
					}
				break;
				case "panelbar_content":
					var pid = o.params.parent;
					for (var j=0;j<OAT.Declarative.objects["panelbar"].length;j++) {
						var p = OAT.Declarative.objects["panelbar"][j];
						if (p.div == $(pid)) { p.addPanel(o.params.clicker,o.elm); }
					}
				break;
			} /* switch */
		}
	}, /* scanningFinished - dynamic creation of widgets */

	execute:function() {
		/*
			two modes of operation:
			1. scan - no OAA Hub present
			2. attach to OAA Hub
		*/
		OAT.Declarative.scan();
		OAT.Declarative.scanningFinished();
	}
}
