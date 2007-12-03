/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2007 OpenLink Software
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
			["map","Yahoo Map",{provider:2}],
			["timeline","Timeline",{}],
			["images","Images",{}],
			["tagcloud","Tag Cloud",{}]
		],
		querySearchURI:false,
		showSearch:true,
		imagePath:OAT.Preferences.imagePath,
		endpoint:"/sparql?query="
	}
	for (var p in optObj) { this.options[p] = optObj[p]; }
	
	this.parent = $(div);
	this.content = OAT.Dom.create("div",{},"rdf_mini");
	this.tabs = [];
	this.select = false;
	
	this.executeSparql = function(template,replace) {
		var str = template;
		for (var p in replace) {
			var re = new RegExp(p);
			var str = str.replace(re,replace[p]);
		}
		var url = self.options.endpoint+encodeURIComponent(str)+"&format=rdf";
		self.open(url);
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
		OAT.Dom.attach(btn,"click",self.search);
		OAT.Dom.attach(inp,"keypress",function(e) { if (e.keyCode == 13) { self.search(); } });
		self.searchInput = inp;
		
		if (!self.options.tabs.length) {
			alert("No visualizations available!");
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
			OAT.Dom.attach(s,"change",self.redraw);
			self.select = s;
			OAT.Dom.append([self.parent,OAT.Dom.text("Visualization: "),s]);
		} else {
			var t = self.options.tabs[0];
			var obj = new OAT.RDFTabs[t[0]](self,t[2]);
			self.tabs.push(obj);
		}
		self.parent.appendChild(self.content);
	}
	
	this.redraw = function() { /* change vis */
		var index = 0;
		if (self.select) { index = self.select.selectedIndex; }
		OAT.Dom.clear(self.content);
		self.content.appendChild(self.tabs[index].elm);
		self.content.appendChild(OAT.Dom.create("div",{clear:"both"}));
		self.tabs[index].redraw();
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

	this.store = new OAT.RDFStore(self.reset,{ajaxStart:ajaxStart,ajaxEnd:ajaxEnd});
	this.data = self.store.data;

	this.getContent = function(data_,disabledActions) {
		var content = false;
		var data = (typeof(data_) == "object" ? data_.uri : data_);
		var type = self.getContentType(data);
		
		switch (type) {
			case 3:
				content = OAT.Dom.create("img");
				content.title = data;
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
				a.innerHTML = data;
				a.href = data;
				content.appendChild(a);
				self.processLink(a,data,disabledActions);
			break;
			default:
				content = OAT.Dom.create("span");
				content.innerHTML = data;
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
OAT.Loader.featureLoaded("rdfmini");
