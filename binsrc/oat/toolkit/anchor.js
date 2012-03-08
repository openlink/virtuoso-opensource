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
	OAT.Anchor.assign(elm,paramsObj);
*/

/**
 * @class
 */
OAT.AnchorData = {
	active:false,
	window:false,
	closeOnBlur:true
}

/**
 * @class Enhanced Anchor tag.
 */
OAT.Anchor = {

	appendContent:function(options) {
		if (options.content && options.window) {
			if (typeof(options.content) == "function") { options.content = options.content(); }
			var win = options.window;
			OAT.Dom.clear(win.dom.content);
			win.dom.content.appendChild(options.content);
			OAT.Anchor.fixSize(win);
		}
	},

	callForData:function(options,pos) {
		var win = options.window;
		options.stat = 1; /* loading */
		if (options.title) { win.dom.caption.innerHTML = options.title; }
		if (options.status) { win.dom.status.innerHTML = options.status; }

		var ds = options.datasource;
		if (ds) {
			ds.connection = options.connection;
			var link = options.elm.innerHTML;
			var unlinkRef = function() {
				win.dom.caption.innerHTML = options.elm.innerHTML;
				if (options.title) { win.dom.caption.innerHTML = options.title; }
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
					options.anchorTo(pos[0],pos[1]);
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
				tl.elm.style.width = (options.width-5)+"px";
				tl.elm.style.height = (options.height-65)+"px";
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

	/** adjust width and height if content overflows container depending on block or inline element inside */
	fixSize:function (win) {
			/* wait to finish all ajax calls */
			setTimeout(function(){
				if (OAT.AJAX && OAT.AJAX.requests.length) {
					OAT.Anchor.fixSize(win);
				} else {
		if (win.dom.container.style.height=='auto' || 
		    win.dom.container.style.width=='auto') { /* if auto, keep auto */
					    return;
                                        }
					var height = OAT.Dom.getWH(win.dom.content)[1];
					while (OAT.Dom.getWH(win.dom.content)[1]+50 > OAT.Dom.getWH(win.dom.container)[1]) {
						if (OAT.Dom.getWH(win.dom.container)[0] < 650)
							win.dom.container.style.width = (OAT.Dom.getWH(win.dom.container)[0]+100)+'px';
						if (height == OAT.Dom.getWH(win.dom.content)[1]) {
			if (OAT.Dom.getWH(win.dom.container)[0] > 100) 
			    win.dom.container.style.width = (OAT.Dom.getWH(win.dom.container)[0]-100)+'px';
							/* now adding scrollbar when too large window */
							if (OAT.Dom.getWH(win.dom.content)[1] > 300) {
								win.dom.content.style.height = '300px';
								win.dom.content.style.overflow = 'auto';
							}
							win.dom.container.style.height = (OAT.Dom.getWH(win.dom.content)[1]+40)+'px';
							break;
						}
						height = OAT.Dom.getWH(win.dom.content)[1];
					}
				}
			}, 50 );
		},

	assign:function(element,paramsObj) {
		var elm = $(element);
		var options = {
			href:false, /* url to be fetched */
			newHref:"#",
			connection:false, /* for url fetch */
			datasource:false, /* for url fetch */
			content:false, /* node or function to be inserted */
			status:false, /* window status */
			title:false, /* window title */
			result_control:false, /* for url fetch */
			activation:"hover",
			width:340,
			height:false, /* false is 'auto' */
			elm:elm, /* anchor node */
			window:false, /* what should be displayed */
			arrow:false, /* what should be displayed */
			type:OAT.Win.Rect,
			buttons:"cr",
			template:false, /* use with type:false - see win component documentation */
	    preload:false /* include the a++ node in the page DOM right at the assing time - 
                             do not use when large number of a++ windows on the page */
		};
		for (var p in paramsObj) { options[p] = paramsObj[p]; }

		var win = new OAT.Win( {
			outerWidth:options.width,
			outerHeight:options.height,
			title:"Loading...",
			type:options.type,
			status:options.status,
			buttons:options.buttons,
			template:options.template	} );
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
		OAT.Dom.addClass(win.dom.container,"oat_anchor");
		OAT.Event.attach(win.dom.container,"mouseover",checkOver);
		OAT.Event.attach(win.dom.container,"mouseout",checkOut);
		var arrow = OAT.Dom.create("div",{});
		OAT.Dom.append([win.dom.container,arrow]);
		options.arrow = arrow;
		options.window = win;

		win.close = function() { OAT.Dom.hide(win.dom.container); }
		win.onclose = win.close;
		win.close();

		options.stat = 0; /* not initialized */
		if (!options.href && 'href' in elm) { options.href = elm.href; } /* if no oat:href provided, then try the default one */
		if (elm.tagName.toString().toLowerCase() == "a") { 
			//OAT.Dom.changeHref(elm,options.newHref); 
		}

		options.displayRef = function(event,preload) {
			OAT.Event.prevent(event);
			var win = options.window;
			win.close(); /* close existing window */
			OAT.AnchorData.active = options;
			var pos = OAT.Event.position(event);
			OAT.AnchorData.window = win; /* assign last opened window */

			OAT.Event.attach(win.dom.container,"click",function(event) { OAT.Event.cancel(event); });

			OAT.Event.cancel(event);

			if (!options.stat) {
				OAT.Anchor.callForData(options,pos);
			} else {
				OAT.Anchor.appendContent(options);
			}

			if (!preload) {
			    if (options.activation=="focus") {
				pos = OAT.Dom.position(elm);
			    }
			    options.anchorTo(pos[0],pos[1]);
			    win.open();
			    window.setTimeout(function(){
				options.anchorTo(pos[0],pos[1]);
			    },60); /* after adding arrows, window can be shifted a bit */
			}

		}

        if (options.preload) {
		    options.displayRef(false, true);
		}

		options.anchorTo = function(x_,y_) {
			var win = options.window;
			var fs = OAT.Dom.getFreeSpace(x_,y_); /* [left,top] */
			var dims = OAT.Dom.getWH(win.dom.container);

			if (fs[1]) { /* top */
				var y = y_ - 30 - dims[1];
				var className = 'bottom';
			} else { /* bottom */
				var y = y_ + 30;
				var className = 'top';
			}

			if (fs[0]) { /* left */
				var x = x_ + 20 - dims[0];
				className += 'right';
			} else { /* right */
				var x = x_ - 30;
				className += 'left';
			}

			if (x < 0) { x = 10; }
			if (y < 0) { y = 10; }

			OAT.Dom.addClass(options.arrow,"oat_anchor_arrow_"+className);
			win.moveTo(x,y);
		}
		options.closeRef = function() {
			if (options.closeFlag) {
				options.window.close();
				OAT.AnchorData.active = false;
			}
		}
		options.close = function() { options.window.close(); }
		options.startClose = function() {
			options.closeFlag = 1;
			setTimeout(options.closeRef,1000);
		}
		options.endClose = function() {
			options.closeFlag = 0;
		}

		switch (options.activation) {
			case "hover":
				OAT.Event.attach(elm,"mouseover",options.displayRef);
				OAT.Event.attach(elm,"mouseout",options.startClose);
			break;
			case "click":
				OAT.Event.attach(elm,"click",options.displayRef);
			break;
			case "dblclick":
				OAT.Event.attach(elm,"dblclick",options.displayRef);
			break;
			case "focus":
				OAT.Event.attach(elm,"focus",options.displayRef);
				OAT.Event.attach(elm,"blur",options.close);
			break;

		}
	},

	close:function(elem, recursive) {
		elem = $(elem);
		if (elem.tagName=='BODY' || elem.tagName=='HTML') return;
		if (elem.className.match(/oat_anchor/)) {
			OAT.Dom.hide(elem);
			if (recursive) this.close(elem.parentNode);
		} else {
			this.close(elem.parentNode);
		}
	}
}

/* if clicked on the document outside a++ windows, close all of them */
OAT.Anchor.closeOnBlur = function() {
	OAT.Event.attach(document.getElementsByTagName('html')[0], "click", function(event) {
	if (!OAT.AnchorData.closeOnBlur) return;
	var checkIfClickedOutside = function(elem) {
		if (!elem)
			return false;
		if (elem.tagName=='BODY' || elem.tagName=='HTML' || !elem.className.match)
			return true;
		if (elem.className.match(/oat_anchor/)) {
			return false;
		} else {
			return checkIfClickedOutside(elem.parentNode);
		}
	}
	if ( !checkIfClickedOutside((OAT.Browser.isIE)?event.srcElement:event.target) )
		return;
	var opened = $$("oat_anchor");
	for (i in opened) {
		if (!opened[i].tagName) continue;
		OAT.Anchor.close(opened[i], true);
	}
	});
};

if (OAT.Browser.isIE) {
	setTimeout(OAT.Anchor.closeOnBlur,1000);
} else {
	OAT.Anchor.closeOnBlur();
}
