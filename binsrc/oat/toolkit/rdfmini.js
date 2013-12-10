/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2013 OpenLink Software
 *
 *  See LICENSE file for details.
 */

/*
	rm = new OAT.RDFMini("div",optObj);
	rm.open(url);
	rm.search(string);
*/

OAT.RDFMini = function(div,optObj) {
	var self = this;

	this.options = {
		tabs:[
			["navigator","Navigator"],
			["browser","Raw Triples",{removeNS:true}],
			["triples","Grid view",{}],
			["svg","SVG Graph",{}],
			["map","Google Map",{provider:OAT.Map.TYPE_G3}],
			["timeline","Timeline",{}],
			["images","Images",{}],
			["tagcloud","Tag Cloud",{}]
		],
		querySearchURI:false,
		showSearch:true,
		imagePath:OAT.Preferences.imagePath,
	endpoint:"/sparql?query=",
	store: false,
	sel_ctr: false, // optional place view selector in custom place
	defaultTab: 2
	}

	for (var p in optObj) { this.options[p] = optObj[p]; }

	this.parent = $(div);
	this.content = OAT.Dom.create("div",{className:"rdf_mini"});
	this.tabs = [];
	this.select = false;
    this.curTabIdx = this.lastTabIdx = self.options.defaultTab;

	this.executeSparql = function(template,replace) {
		var str = template;
		for (var p in replace) {
			var re = new RegExp(p);
			var str = str.replace(re,replace[p]);
		}
		var url = self.options.endpoint+encodeURIComponent(str)+"&format=rdf";
		self.open(url);
	}

    this.getCurrentTabType = function () {
	return (self.options.tabs[self.curTabIdx][0]);
    }

    this.getCurrentTab = function () {
	return (self.select.selectedIndex);
    }

    this.setTab = function (i) {
	if (i < self.select.options.length) {
	    self.lastTabIdx = self.curTabIdx;
	    self.curTabIdx = self.select.selectedIndex = i;
	    self.redraw();
	}
    }

    this.setDefaultTab = function () {
	self.setTab (self.options.defaultTab);
    }

    this.setLastTab = function () {
	self.setTab (self.lastTabIdx);
    }

	this.search = function(str) {
		var s = (str ? str : $v(self.searchInput));
		if (!s.trim()) { return; }
		if (s.match(/^http/i)) {
			if (self.options.querySearchURI) {
				/* SPARQL special search */
				self.executeSparql('SELECT DISTINCT ?Concept from <{query}> WHERE {[] a ?Concept}',{"{query}":s});
			} else {
				self.open(s);
			}
		} else {
			/* SPARQL search */
			self.executeSparql('SELECT ?s ?p ?o WHERE { ?s ?p ?o . ?o bif:contains "\'{query}\'"}',{"{query}":s});
		}
	}

	this.init = function() {
		OAT.Dom.clear(self.parent);
		self.throbber = OAT.Dom.create("img",{styleFloat:"right",cssFloat:"right",cursor:"pointer"});
		self.throbber.src = self.options.imagePath + "throbber.gif" ;
		OAT.Event.attach(self.throbber,"click",OAT.AJAX.abortAll);
		self.parent.appendChild(self.throbber);
		OAT.Dom.hide(self.throbber);

		var s = OAT.Dom.create("div");
		var inp = OAT.Dom.create("input",{verticalAlign:"middle"});
		inp.type = "text";
		inp.size = "40";
		var btn = OAT.Dom.create("img",{cursor:"pointer",verticalAlign:"middle"});
		btn.src = self.options.imagePath+"RDF_search.gif";
		btn.title = "Search";
		if (self.options.showSearch) { OAT.Dom.append([s,inp,btn],[self.parent,s]); }
		OAT.Event.attach(btn,"click",self.search);
		OAT.Event.attach(inp,"keypress",function(e) { if (e.keyCode == 13) { self.search(); } });
		self.searchInput = inp;

		if (!self.options.tabs.length) {
			var note = new OAT.Notify();
			var msg = "No visualizations available!";
			note.send(msg);
			return;
		}
		if (self.options.tabs.length > 1) {
			var s = OAT.Dom.create("select");
			for (var i=0;i<self.options.tabs.length;i++) {
				var t = self.options.tabs[i];
				var obj = new OAT.RDFTabs[t[0]](self,t[2]);
				self.tabs.push(obj);
				OAT.Dom.option(t[1],t[1],s);
			}
	    OAT.Event.attach(s, "change", self.tabSelChangeH);
			self.select = s;

	    var sel_ctr;

	    if (!self.options.sel_ctr) 
		sel_ctr = OAT.Dom.create("div",{className:"rdfmini_view_sel_ctr"});
	    else
		sel_ctr = self.options.self_ctr;

	    var sel_lbl = OAT.Dom.create("label");

	    OAT.Dom.append([self.parent,sel_ctr],[sel_ctr,sel_lbl,s]);
	    sel_lbl.innerHTML = "View:";
		} else {
			var t = self.options.tabs[0];
			var obj = new OAT.RDFTabs[t[0]](self,t[2]);
			self.tabs.push(obj);
		}

	OAT.MSG.attach ("*","MAP_NOTHING_TO_SHOW", 
			function (_s,_m,_e) { 
			    self.setLastTab();
			    self.redraw() 
			});
	
	var ua = navigator.userAgent;

	if (ua.indexOf('iPhone') != -1 || ua.indexOf('Android') != -1 ) {
	    vp = OAT.Dom.getViewport();

	    self.content.style.width = vp[1]+'px';
	    self.content.style.height = vp[0]+'px';
	    console.info ('viewport: '+vp[1]+'x'+vp[0]);
	    self.content.scrollIntoView(true);
	}
//	else {
//	    self.content.style.height = '600px';
//	}

		self.parent.appendChild(self.content);
	}

    this.tabSelChangeH = function (e) {
	self.setTab(e.target.selectedIndex);
	self.redraw();
    }
    
	this.redraw = function() { /* change vis */
	    var index = 0;
	    if (self.select) { index = self.select.selectedIndex; }
	    OAT.Dom.clear(self.content);
	    self.content.appendChild(self.tabs[index].elm);
	    self.content.appendChild(OAT.Dom.create("div",{clear:"both"}));
	    self.tabs[index].redraw();
	    var et = {};
	    et.tabIndex = index;
	et.tabType = self.options.tabs[index][0];
	    OAT.MSG.send (self,"RDFMINI_VIEW_CHANGED",et);
	}

	this.open = function(url) { /* open url */
		self.store.clear();
		self.store.addURL(url);
	}

	this.reset = function() { /* url arrived */
		for (var i=0;i<self.tabs.length;i++) {
			self.tabs[i].reset();
		}
		self.redraw();
	}

	var ajaxStart = function() { OAT.Dom.show(self.throbber); }
	var ajaxEnd = function() { OAT.Dom.hide(self.throbber); }

    if (this.options.store) {
	this.store = this.options.store;
	this.store.options.onstart = ajaxStart;
	this.store.options.onend = ajaxEnd;
	this.store.reset = this.reset;
    }
    else this.store = new OAT.RDFStore(this.reset,{onstart:ajaxStart,onend:ajaxEnd});

	this.data = self.store.data;

	this.getContent = function(data_,disabledActions) {
		var content = false;
	    var data;
	var label = false;
	var ciri;
	var _type;

	    if (data_.constructor == OAT.RDFAtom)
		switch (data_.getTag()) {
		case OAT.RDFTag.IRI:
		    data = data_.getIRI();
		ciri = OAT.IRIDB.resolveCIRI(data_.getValue());
		content = OAT.Dom.create("span");
		var a = OAT.Dom.create("a");

		if (label) a.innerHTML = label;
		else a.innerHTML = (self.options.raw_iris ? data : ciri);

		a.href = data;
		content.appendChild(a);
		self.processLink(a,data,disabledActions);
		return content;
		case OAT.RDFTag.LIT:
		    data = data_.getValue();
		    break;
	    }
	else if (typeof data_ == 'object') {
	    ciri = OAT.IRIDB.resolveCIRI(data_.iid);
	    data = OAT.IRIDB.getIRI(data_.iid);
	    label = data_.label;
	    content = OAT.Dom.create("span");
	    var a = OAT.Dom.create("a");

	    if (label) a.innerHTML = label;
            else a.innerHTML = (self.options.raw_iris ? data : ciri);

	    a.href = data;
	    content.appendChild(a);
	    self.processLink(a,data,disabledActions);
	    return content;
	}
	
	_type = self.getContentType(data); // Only literals should be left something that may be deref'd?

	switch (_type) { // XXX this should be pruned with extreme prejudice
			case 3:
				content = OAT.Dom.create("img");
	    content.title = (label ? label : data);
				content.src = data;
				self.processLink(content,data);
			break;
			case 2:
				content = OAT.Dom.create("a");
				var r = data.match(/^(mailto:)?(.*)/);
				content.innerHTML = r[2];
				content.href = 'mailto:'+r[2];
			break;
			case 1:
				content = OAT.Dom.create("span");
				var a = OAT.Dom.create("a");
	    a.innerHTML = (label ? label : ciri);
				a.href = data;
				content.appendChild(a);
				self.processLink(a,data,disabledActions);
			break;
			default:
				content = OAT.Dom.create("span");

	    if (data.match(/(#this$|#me$)/))
		content.innerHTML = (label ? label : ciri);
	    else
		content.innerHTML = (label ? label : data);

				/* create dereference a++ lookups for all anchors */
				var anchors_ = content.getElementsByTagName("a");
				var anchors = [];
				for (var j=0;j<anchors_.length;j++) { anchors.push(anchors_[j]); }
				for (var j=0;j<anchors.length;j++) {
					var a = anchors[j];
					if (a.href.match(/^http/)) {
						self.processLink(a,a.href);
					}
				}
			break;
		} /* switch */
		return content;
	}

	this.simplify = self.store.simplify;
	this.getContentType = self.store.getContentType;
	this.getTitle = self.store.getTitle;
	this.getURI = self.store.getURI;
	this.processLink = function(domNode,href,disabledActions){};

	this.init();
}
