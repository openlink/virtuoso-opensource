/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2014 OpenLink Software
 *
 *  See LICENSE file for details.
 */

/*
	var r = new OAT.RSSReader(div, optObj);
	r.display(xmlText);

	CSS: .rss_reader .rss_body .rss_header
*/

OAT.RSSReader = function(div,options) {
	var self = this;
	this.options = {
		limit: 10,
		showTitle: true
	}
	for (var p in options) { self.options[p] = options[p]; }
	this.div = $(div);
	OAT.Dom.addClass(self.div,"rss_reader");

	this.display = function(xmlText) {
		var xml = OAT.Xml.removeDefaultNamespace(xmlText);
		var xmlDoc = OAT.Xml.createXmlDoc(xml);

		var data = {
			title:"",
			link:"",
			items:[],
			item:{
				title:"",
				link:"",
				description:"",
				date:""
			}
		}

		var tn = xmlDoc.documentElement.tagName.toLowerCase();
		if (tn == "rss") { self._parseRSS(xmlDoc,data); }
		if (tn.match(/rdf/)) { self._parseRDF(xmlDoc,data); }
		if (tn == "feed") { self._parseAtom(xmlDoc,data); }

		OAT.Dom.clear(self.div);
		if (self.options.showTitle) {
			var title = OAT.Dom.create("h3",{className:"rss_header"});
			var link = OAT.Dom.create("a");
			link.href = data.link;
			link.innerHTML = data.title;
			OAT.Dom.append([title,link],[self.div,title]);
		}
		var body = OAT.Dom.create("ul",{className:"rss_body"});
		var max = Math.min(data.items.length,self.options.limit);
		for (var i=0;i<max;i++) {
			var li = OAT.Dom.create("li");
			var a = OAT.Dom.create("a");
			a.href = data.items[i].link;
			a.innerHTML = data.items[i].title;
			OAT.Dom.append([li,a],[body,li]);
		}
		self.div.appendChild(body);
	}

	this._parseRSS = function(xmlDoc,result) {
		var titleNode = OAT.Xml.xpath(xmlDoc,"//channel/title")[0];
		var linkNode = OAT.Xml.xpath(xmlDoc,"//channel/link")[0];
		result.title = OAT.Xml.textValue(titleNode);
		result.link = OAT.Xml.textValue(linkNode);
		var itemNodes = OAT.Xml.xpath(xmlDoc,"//item");
		for (var i=0;i<itemNodes.length;i++) {
			var itemNode = itemNodes[i];
			var item = {};
			for (var p in result.item) { item[p] = result.item[p]; }
			var titleNode = itemNode.getElementsByTagName("title");
			if (titleNode.length) { item.title = OAT.Xml.textValue(titleNode[0]); }
			var linkNode = itemNode.getElementsByTagName("link");
			if (linkNode.length) { item.link = OAT.Xml.textValue(linkNode[0]); }
			var descNode = itemNode.getElementsByTagName("description");
			if (descNode.length) { item.description = OAT.Xml.textValue(descNode[0]); }
			var dateNode = itemNode.getElementsByTagName("pubDate");
			if (dateNode.length) { item.date = OAT.Xml.textValue(dateNode[0]); }
			result.items.push(item);
		}
	}

	this._parseAtom = function(xmlDoc,result) {
		var titleNode = OAT.Xml.xpath(xmlDoc,"//feed/title")[0];
		var linkNode = OAT.Xml.xpath(xmlDoc,"//feed/link")[0];
		result.title = OAT.Xml.textValue(titleNode);
		result.link = linkNode.attributes.getNamedItem("href").nodeValue;
		var itemNodes = OAT.Xml.xpath(xmlDoc,"//entry");
		for (var i=0;i<itemNodes.length;i++) {
			var itemNode = itemNodes[i];
			var item = {};
			for (var p in result.item) { item[p] = result.item[p]; }
			var titleNode = itemNode.getElementsByTagName("title");
			if (titleNode.length) { item.title = OAT.Xml.textValue(titleNode[0]); }
			var linkNode = itemNode.getElementsByTagName("link");
			if (linkNode.length) { item.link = linkNode[0].attributes.getNamedItem("href").nodeValue; }
			var descNode = itemNode.getElementsByTagName("summary");
			if (descNode.length) { 
				item.description = OAT.Xml.textValue(descNode[0]); 
				item.description = OAT.Xml.unescape(item.description);
			}
			var dateNode = itemNode.getElementsByTagName("published");
			if (dateNode.length) { item.date = OAT.Xml.textValue(dateNode[0]); }
			result.items.push(item);
		}
	}

	this._parseRDF = function(xmlDoc,result) {
		/* create resolver object */
		var obj = {rdf:"http://www.w3.org/1999/02/22-rdf-syntax-ns#"};
		var titleNode = OAT.Xml.xpath(xmlDoc,"//channel/title",obj)[0];
		var linkNode = OAT.Xml.xpath(xmlDoc,"//channel/link",obj)[0];
		result.title = OAT.Xml.textValue(titleNode);
		result.link = OAT.Xml.textValue(linkNode);
		var itemNodes = OAT.Xml.xpath(xmlDoc,"//item",obj);
		for (var i=0;i<itemNodes.length;i++) {
			var itemNode = itemNodes[i];
			var item = {};
			for (var p in result.item) { item[p] = result.item[p]; }
			var titleNode = itemNode.getElementsByTagName("title");
			if (titleNode.length) { item.title = OAT.Xml.textValue(titleNode[0]); }
			var linkNode = itemNode.getElementsByTagName("link");
			if (linkNode.length) { item.link = OAT.Xml.textValue(linkNode[0]); }
			var descNode = itemNode.getElementsByTagName("description");
			if (descNode.length) { item.description = OAT.Xml.textValue(descNode[0]); }
			var dateNode = itemNode.getElementsByTagName("pubDate");
			if (dateNode.length) { item.date = OAT.Xml.textValue(dateNode[0]); }
			result.items.push(item);
		}
	}

}
