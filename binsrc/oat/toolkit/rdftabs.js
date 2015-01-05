/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2015 OpenLink Software
 *
 *  See LICENSE file for details.
 */

/*
	API FOR RDF TABS
	----------------

	1) MUST implement
	-----------------
		[constructor](parent, optionsObject) - parent is a reference to owner object (rdfbrowser, rdfmini)
		.elm - DOM node
		.description - textual
		.redraw() - redraw contents
		.reset(hard) - called by parent when triple store changes. when the change is initiated by applying filters, hard == false.
						when the change is initiated by adding/removing URL, hard == true

	2) CAN use
	----------
		parent.data = {
			triples:[] - array of triples
			all:{} - object
			structured:{} - object with applied filters
		}
		parent.store - instance of OAT.RDFStore
		parent.getContentType(string) - return 1=link, 2=mail, 3=image, 0=others
		parent.getTitle(dataItem) - returns title string for data item
		parent.getURI(dataItem) - returns URI for data item
		parent.processLink(domNode, href, disabledActions) - attach external handlers to a link


	.rdf_sort .rdf_group .rdf_clear .rdf_data .rtf_tl_port .rdf_tl_slider .rdf_tagcloud .rdf_tagcloud_title
*/


OAT.RDFTabsData = {
    MARKER_MODE_DISTINCT_O: 1, // Old default behaviour - distinct markers by ouri
    MARKER_MODE_BY_TYPE:    2, // Markers by item type match
    MARKER_MODE_EXPLICIT:   3, // Markers by explicit property oat:rdfTabsMarker <marker URL>
    MARKER_MODE_AUTO:       4
};

if (!OAT.RDFTabs) { OAT.RDFTabs = {}; }

OAT.RDFTabs.parent = function(obj) {
    /* methods & properties that need to be implemented by each RDFTab */
    obj.redraw = function() {} /* redraw contents */
    obj.reset = function(hard) {} /* triples were changed - reset */
    obj.elm = OAT.Dom.create("div", {className:"rdf_tab"});
    obj.description = "";
}

OAT.RDFTabs.browser = function(parent,optObj) {
    var self = this;
    OAT.RDFTabs.parent(self);

    this.options = {
	pageSize:20,
	removeNS:true,
	description:"This view shows all RDF data grouped by subject resource.",
	desc:"RDF data by subject resource",
	raw_iris: false
    }

    for (var p in optObj) { self.options[p] = optObj[p]; }

    this.initialized = false;
	this.dataDiv = OAT.Dom.create("div",{className:"rdf_data"});
	this.sortDiv = OAT.Dom.create("div",{className:"rdf_sort"});
    this.description = self.options.description;
    this.desc = self.options.desc;
    this.parent = parent;
    this.sortTerm = false;
    this.groupMode = false;
    this.currentPage = 0;


    this.elm = OAT.Dom.create("div", {}, "rdf_tab rdft_browser");

    this.reset = function(hard) {
	self.sortTerm = false;
	self.groupMode = false;
	self.currentPage = 0;
    }

    this.sort = function(predicate) {
	var sf = function(a,b) {
	    /* find values of this predicate */
	    var a_ = false;
	    var b_ = false;
	    var ap = a.preds;
	    var bp = b.preds;
	    for (var p in ap) { if (p == predicate) { a_ = ap[p][0]; }}
	    for (var p in bp) { if (p == predicate) { b_ = bp[p][0]; }}
	    if (typeof(a_) == "object") { a_ = a_.uri; }
	    if (typeof(b_) == "object") { b_ = b_.uri; }

	    if (a_ == b_) { return 0; }
	    if (a_ === false) { return 1; }
	    if (b_ === false) { return -1; }
	    if (parseFloat(a_) == a_) {
		var result = (parseFloat(a_) < parseFloat(b_) ? -1 : 1);
	    } else {
		var result = (a_ < b_ ? -1 : 1);
	    }
	    return result;
	}
	self.parent.data.structured.sort(sf);
	self.redraw();
    }

    this.resize = function (sender,msg,content) {

	//	    var i_list = $$('o_img')

	//	    for (var i=0;i < i_list.length;i++) {
	//		i_list[i].width = Math.min(OAT.Dom.getWH(i_list[i])[0], Math.round(content.w * .666)-5);
	//	    }
    }

    this.drawItem = function(item) { /* one item */
	var s_ctr = OAT.Dom.create("div",{className:"rdf_item"});
	var h = OAT.Dom.create("h3", {className:"rdf_subject"});
	var s = OAT.Dom.create("a");
	var uri = OAT.IRIDB.getIRI(item.uri);

	s.href = uri;
	s.title = uri;
	s.innerHTML = self.parent.getTitle(item);

	OAT.Dom.append([s_ctr,h],[h,s]);

	if (uri.match(/^http/i)) {
	    self.parent.processLink(s,uri);
	    s.style.cursor = "pointer";
	}

	var preds = item.preds;

	var preds_ctr = OAT.Dom.create ("div", {className:"rdf_preds"});

	for (var p in preds) {

	    /* check if predicate is not in filters */
	    var pred = preds[p];
	    var ok = true;

	    for (var i=0;i<self.parent.store.filtersProperty.length;i++) {
		var f = self.parent.store.filtersProperty[i];
		if (p == f[0] && f[1] != "") { ok = false; }
	    }
	    if (!ok) { continue; } /* don't draw this property */

	    var p_ctr = OAT.Dom.create("div",{className:"rdf_p"});
	    var p_a = OAT.Dom.create("a");
	    var p_iri = OAT.IRIDB.getIRI(p);
	    var p_ciri = OAT.IRIDB.resolveCIRI(p);

	    p_a.href = p_iri;

	    p_a.innerHTML = (self.options.removeNS ? p_ciri.truncate(60) : p_iri.truncate(60));
	    p_a.title = p_iri;
	    p_ctr.appendChild (p_a);
	    preds_ctr.appendChild (p_ctr);
	    self.parent.processLink (p_a, p_iri);
	    var pred_ul = OAT.Dom.create("ul", {className:"rdf_o"})
	    for (var i=0;i<pred.length;i++) {
		var pred_li = OAT.Dom.create ("li", {className:"rdf_o"});
		var value = pred[i];
		var content = self.parent.getContent(value);
		pred_li.appendChild(content);
		pred_ul.appendChild(pred_li);
	    }
	    preds_ctr.appendChild (pred_ul);
	} /* for all predicates */
	s_ctr.appendChild (preds_ctr);
	return s_ctr;
    }

    this.drawData = function() { /* set of items */
	OAT.Dom.clear(self.dataDiv);
	var h = OAT.Dom.create("h3", {className:"data"});
	h.innerHTML = "Data";
	self.dataDiv.appendChild(h);

	self.pageDiv = OAT.Dom.create("div", {className:"pager"});
	self.dataDiv.appendChild(self.pageDiv);

	var toggleRef = function(gd) {
	    return function() {
		gd.state = (gd.state+1) % 2;
		if (gd.state) { OAT.Dom.show(gd); } else { OAT.Dom.hide(gd); }
	    }
	}

	var groupDiv = false;
	var createGroup = function(label) {
	    if (groupDiv) { groupDiv.appendChild(OAT.Dom.create("div",{className:"rdf_clear"})); }
	    groupDiv = OAT.Dom.create("div", {display:"none",className:"rdf_group"});
	    groupDiv.state = 0;
	    var h = OAT.Dom.create("h3",{borderBottom:"1px solid #888",cursor:"pointer"});
	    h.innerHTML = label;
	    OAT.Dom.append([self.dataDiv,h,groupDiv]);
	    OAT.Event.attach(h,"click",toggleRef(groupDiv));
	}

	var groupValue = false;
	var findGV = function(record) {
	    var result = false;
	    var preds = record.preds;
	    for (p in preds) {
		if (p == self.sortTerm) { result = preds[p][0]; } /* take first */
	    }
	    if (typeof(result) == "object") { result = result.uri; }
	    return result;
	}

	var data = self.parent.data.structured;
	for (var i=0;i<data.length;i++) {
	    var item = data[i];
	    if (self.groupMode) { /* grouping */
		var gv = findGV(item);
		if (gv != groupValue || i == 0) {
		    /* create new group */
		    groupValue = gv;
		    createGroup(gv);
		}
		groupDiv.appendChild(self.drawItem(item));
	    } else if (i >= self.currentPage * self.options.pageSize &&
		       i < (self.currentPage + 1) * self.options.pageSize) {
		self.dataDiv.appendChild(self.drawItem(item));
	    } /* if in current page */

	} /* for all data items subjects */
    }

    this.drawPager = function() {
	var cnt = OAT.Dom.create("div", {className:"pgr_count"});
	var div = OAT.Dom.create("div", {className:"pgr_page_no"});
	var gd  = OAT.Dom.create("div", {className:"pgr_grouping"});

	var count = self.parent.data.structured.length;
	var tcount = self.parent.data.triples.length;
	var pcount = 0;

	for (var i=0;i<self.parent.data.structured.length;i++) {
	    var item = self.parent.data.structured[i];
	    for (var p in item.preds) { pcount++; }
	}

	cnt.innerHTML = "" +
	    count +
	    " records (" +
		       tcount + " triples, " + pcount + " properties) match selected filters. ";

	if (count == 0) {
	    cnt.innerHTML += "Nothing to display. Perhaps your filters are too restrictive?";
	}

	OAT.Dom.append([self.pageDiv,cnt,gd,div]);

	function assign(a,page) {
	    a.setAttribute("title","Jump to page "+(page+1));
			a.setAttribute("href","#");
	    OAT.Event.attach(a,"click",function(event) {
		OAT.Event.prevent(event);
		self.currentPage = page;
		self.redraw();
	    });
	}

	if (self.groupMode || self.sortTerm) {
	    var cb = OAT.Dom.create("input");
	    cb.type = "checkbox";
	    cb.checked = self.groupMode;
	    cb.id = "rdf_group_cb";
	    var l = OAT.Dom.create("label");
	    l.innerHTML = "Grouping";
	    l.htmlFor = "rdf_group_cb";
	    OAT.Dom.append([gd,cb,l]);
	    OAT.Event.attach(cb,"change",function() {
		self.groupMode = !self.groupMode;
		self.redraw();
	    });
	} else {
	    gd.innerHTML = "To enable grouping, order records by some value.";
	}

	if (count > self.options.pageSize && !self.groupMode) { /* create pager */
	    div.innerHTML = "Page: ";
	    var pagecount = Math.ceil(count/self.options.pageSize);
	    for (var i=0;i<pagecount;i++) {
		var a = OAT.Dom.create("a");
		if (i != self.currentPage) { assign(a,i); }
		div.appendChild(OAT.Dom.text(" "));
		div.appendChild(a);
		a.innerHTML = i+1;
		div.appendChild(OAT.Dom.text(" "));
	    }
	}
    }

    this.drawSort = function() {
	OAT.Dom.clear(self.sortDiv);
	var h = OAT.Dom.create("h3", {}, "orderby");
	h.innerHTML = "Order By Resource Category";
	self.sortDiv.appendChild(h);

	var list = [];
	/* analyze sortable predicates */
	var data = self.parent.data.structured;
	for (var i=0;i<data.length;i++) {
	    var item = data[i];
	    var preds = item.preds;
	    for (var p in preds) {
		var index1 = list.indexOf(p);
		var index2 = -1;
		for (var j=0;j<self.parent.store.filtersProperty.length;j++) {
		    if (self.parent.store.filtersProperty[j][0] == p) { index2 = p; }
		}
		if (index1 == -1 && index2 == -1) { list.push(p); }
	    } /* for all predicates */
	} /* for all data */

	var attach = function(elm,val) {
	    OAT.Event.attach(elm,"click",function(event) {
		OAT.Event.prevent(event);
		self.sortTerm = val;
		self.sort(val);
	    });
	}

	for (var i=0;i<list.length;i++) {
	    var value = list[i];
	    if (self.sortTerm == value) {
		var elm = OAT.Dom.create("span");
	    } else {
		var elm = OAT.Dom.create("a");
		elm.href = OAT.IRIDB.getIRI(value);
		attach(elm,value);
	    }

	    if (self.options.raw_iris) elm.innerHTML = elm.href; 
            else elm.innerHTML = self.parent.store.getCIRIorSplit(value);

	    if (i) { self.sortDiv.appendChild(OAT.Dom.text(", ")); }
	    self.sortDiv.appendChild(elm);
	}
    }

    this.redraw = function() {
	if (!self.initialized) {
	    self.initialized = true;
	    OAT.Dom.append([self.elm,self.sortDiv,self.dataDiv]);
	}
	self.drawSort();
	self.drawData();
	self.drawPager();
    }
}

OAT.RDFTabs.navigator = function(parent,optObj) {
    var self = this;
    OAT.RDFTabs.parent(self);

    this.plurals = {
	"Person":"People",
	"Class":"Classes",
	"Entry":"Entries"
    }

    this.options = {
	limit:5,
	description:"This module is used to navigate through locally cached data, one resource at a time. Filters are not applied.",
	desc:"Navigate through locally cached data (Filters not applied)",
        raw_iris: false
    }

    for (var p in optObj) { self.options[p] = optObj[p]; }

    this.initialized = false;
    this.parent = parent;
    this.history = [];
    this.historyIndex = -1;
    this.nav = {};
    this.waiting = false;
    this.mlCache = [];
    this.topDiv = OAT.Dom.create("div",{className:"rdf_nav"});
    this.mainDiv = OAT.Dom.create("div",{className:"rdf_nav_content"});
    this.description = self.options.description;
    this.desc = self.options.desc;

    OAT.Dom.append([self.elm,self.topDiv,self.mainDiv]);

    this.gd = new OAT.GhostDrag();
    this.dropReference = function(source) {
	return function(target,x,y) { /* reposition two row blocks */
	    if (source == target) { return; }
	    var stop = target;
	    if (source._rows[source._rows.length-1].nextSibling == target) {
		stop = target._rows[target._rows.length-1].nextSibling;
	    }
	    target.parentNode.insertBefore(source,stop);
	    for (var i=0;i<source._rows.length;i++) {
		var row = source._rows[i];
		target.parentNode.insertBefore(row,stop);
	    }
	}
    }
    this.gdProcess = function(elm) {
	var t = OAT.Dom.create("table",{className:"rdf_nav_spotlight"});
	var tb = OAT.Dom.create("tbody");
	OAT.Dom.append([t,tb],[tb,elm.firstChild]);
	elm.appendChild(t);
    }

    this.reset = function(hard) {
	if (!hard) { return; } /* we ignore filters */
	if (!self.waiting) {
	    self.historyIndex = -1;
	    self.history = [];
	    self.mlCache = [];
	}
    }

    this.attach = function(elm,item) { /* attach navigation to link */
	OAT.Dom.addClass(elm,"rdf_link");
	var arrow = OAT.Dom.image(self.parent.options.imagePath + 'arrow_down_anim.gif');
	arrow.style.marginLeft = '3px';
	arrow.title = 'Click to explore retrieved data';
	elm.appendChild(arrow);
	setTimeout( function() {
	    if (arrow) elm.removeChild(arrow);
	    arrow = null;
	}, 30000);
	OAT.Event.attach(elm,"click",function(event) {
	    if (arrow) elm.removeChild(arrow);
	    arrow = null;
	    /* disable default onclick event for anchor */
	    OAT.Event.prevent(event);
	    self.history.splice(self.historyIndex+1,self.history.length-self.history.index+1); /* clear forward history */
	    self.history.push(item);
	    self.navigate(self.history.length-1);
	});
    }

    this.dattach = function(elm,uri) { /* attach dereference to link */
	OAT.Event.attach(elm,"click",function(event) {
	    /* disable default onclick event for anchor */
	    OAT.Event.prevent(event);
	    self.waiting = true;
	    var img = OAT.Dom.create("img");
	    img.src = self.parent.options.imagePath + "Dav_throbber.gif";
	    var start = function(xhr) {
		elm.parentNode.insertBefore(img,elm);
		OAT.Event.attach(img,"click",xhr.abort);
	    }
	    var end = function() {
		OAT.Dom.unlink(img);
	    }
	    self.parent.store.addURL(uri,{ajaxOpts:{onstart:start,onend:end}});
	});
    }

    this.getTypeObject = function() { /* object of resource types */
	var obj = [];
	var noTypeArr = [];

	OAT.IRIDB.insertIRI('http://openlinksw.com/schemas/oat/rdftabs#','oatrdftabs');
	var ntIID = OAT.IRIDB.insertIRI('http://openlinksw.com/schemas/oat/rdftabs#isReferencedBy');

	var data = self.parent.data.all;

	for (var i=0;i<data.length;i++) {
	    var item = data[i];
	    if (item.type) {
		for (var j=0;j<item.type.length;j++) {
		    var t = item.type[j].getValue();
		    var fnd = false;
		    for (var k=0;k<obj.length;k++) {
			if (obj[k][0] == t) {
			    obj[k][1].push(item);
			    fnd = true;
			}
		    }
		    if (!fnd) 
			obj.push([t,[item]]);
		}
	    }
	    else { 
		noTypeArr.push(item);
	    }
	}
	if (noTypeArr.length) {
	    obj.push ([ntIID, noTypeArr]);
	}
	return obj;
    }

// XXX old code
//    var content = false;
//    if (typeof(value) == "object") { /* resource */
//	var items = self.parent.store.items;
//	var dereferenced = false;
//	for(var j=0;j<items.length;j++) {
//	    var item = items[j];
//	    /* handle anchors to local file */
//	    var baseuri = value.uri.match(/^[^#]+/);
//	    baseuri = baseuri? baseuri[0] : "";
//	    var basehref = item.href.match(/^[^#]+/);
//	    basehref = basehref? basehref[0] : "";
//	    if (basehref == baseuri) { dereferenced = true; };
//	}
//
//	content = OAT.Dom.create("a");
//	content.href = value.uri;
//	content.innerHTML = self.parent.getTitle(value);
//	
//	/* dereferenced, or relative uri/blank node */
//	if(dereferenced || !value.uri.match(/^http/i) || !value.uri.match(/^NodeID/i)) {
//	    self.attach(content,value);
//	} else {
//	    self.dattach(content,value.uri);
//	}
//  } else { /* literal */
//	var type = self.parent.getContentType(value);
//	if (type == 3) { /* image */
//	    content = OAT.Dom.create("img");
//	    content.src = value;
//	    var ref = function() {
//		var w = content.width;
//		var h = content.height;
//		var max = Math.max(w,h);
//		if (max > 600) {
//		    var coef = 600 / max;
//		    var nw = Math.round(w*coef);
//		    var nh = Math.round(h*coef);
//		    content.width = nw;
//		    content.height = nh;
//		}
//	    }
//	    OAT.Event.attach(content,"load",ref);
//	} else if (type == 1) { /* dereferencable link */
//	    content = OAT.Dom.create("a");
//	    content.href = value;
//	    content.innerHTML = self.parent.store.simplify(value);
//	    self.dattach(content,value);
//	} else { /* text */
//	    content = OAT.Dom.create("span");
//	    content.innerHTML = value;
//	    var anchors_ = content.getElementsByTagName("a");
//	    var anchors = [];
//	    for (var j=0;j<anchors_.length;j++) { anchors.push(anchors_[j]); }
//	    for (var j=0;j<anchors.length;j++) {
//		var anchor = anchors[j];
//		var done = false;
//		for (var k=0;k<self.parent.data.all.length;k++) {
//		    var item = self.parent.data.all[k];
//		    if (anchor.href == item.uri) {
//			self.attach(anchor,item);
//			done = true;
//			k = self.parent.data.all.length;
//		    }
//		} /* for all resources */
//		if (!done) { self.dattach(anchor,anchor.href); }
//	    } /* for all nested anchors */
//	}
//    } /* if literal */
//    return content;
//}


    this.drawPredicate = function(value) { /* draw one pred's content; return ELM */
	var content = false;	
	if (value.constructor == OAT.RDFAtom) {
	    if (value.isIRI()) {
		type = self.parent.getContentType(value.getIRI());
	    if (type == 3) { /* image */
		content = OAT.Dom.create("img");
		    content.src = value.getIRI();
		var ref = function() {
		    var w = content.width;
		    var h = content.height;
		    var max = Math.max(w,h);
		    if (max > 600) {
			var coef = 600 / max;
			var nw = Math.round(w*coef);
			var nh = Math.round(h*coef);
			content.width = nw;
			content.height = nh;
		    }
		}
		OAT.Event.attach(content,"load",ref);
	    } else if (type == 1) { /* dereferencable link */
		content = OAT.Dom.create("a");
		    content.href = value.getIRI();

		    if (self.options.raw_iris) content.innerHTML = value.getIRI();
                    else content.innerHTML = self.parent.store.getCIRIorSplit(value.getIID());

		    self.dattach(content,value.getIRI());
		} 
	    } else { /* text */
		content = OAT.Dom.create("span");
		content.innerHTML = value.getValue();
		var anchors_ = content.getElementsByTagName("a");
		var anchors = [];
		for (var j=0;j<anchors_.length;j++) { anchors.push(anchors_[j]); }
		for (var j=0;j<anchors.length;j++) {
		    var anchor = anchors[j];
		    var done = false;
		    for (var k=0;k<self.parent.data.all.length;k++) {
			var item = self.parent.data.all[k];
			if (anchor.href == item.uri) {
			    self.attach(anchor,item);
			    done = true;
			    k = self.parent.data.all.length;
			}
		    } /* for all resources */
		    if (!done) { self.dattach(anchor,anchor.href); }
		} /* for all nested anchors */
	    }
	}
	else if (typeof(value) == "object") { /* resource */
	    var graphs = self.parent.store.graphs;
	    var dereferenced = false;
	    for (var j=0;j<graphs.length;j++) {
		var item = graphs[j];
		/* handle anchors to local file */
		var baseuri = OAT.IRIDB.getIRI(value.iid).match(/^[^#]+/);
		baseuri = baseuri ? baseuri[0] : "";
		var basehref = item.href.match(/^[^#]+/);
		basehref = basehref ? basehref[0] : "";
		if (basehref == baseuri) { dereferenced = true; };
	    }

	    var val_iri = OAT.IRIDB.getIRI(value.uri);
	    content = OAT.Dom.create("a");
	    content.href = val_iri;
	    content.title= val_iri;
	    content.innerHTML = self.parent.getTitle(value);

	    /* dereferenced, or relative uri/blank node */
	    if(dereferenced || !val_iri.match(/^http/i) || !val_iri.match(/^NodeID/i)) {
		self.attach(content,value);
	    } else {
		self.dattach(content,val_iri);
	    }
	}
	return content;
    }

    this.drawItem = function(item) { /* one item */
	var obj = [];
	var refByA = [];
	var refByIID = OAT.IRIDB.insertIRI('http://openlinksw.com/schemas/oat/rdftabs#isReferencedBy');

	for (var p in item.preds) {
	    obj.push ([p, item.preds[p]]);
	}

	for (var i=0;i<item.back.length;i++)
          obj.push ([refByIID, item.back[i]]); // XXX item.back is a list of backreferences

	self.drawSpotlight(self.parent.getTitle(item),
			   OAT.IRIDB.getIRI(item.uri),
			   obj);
    }

    this.breadCrumbClickFun = function (index) {
	return (function () {
	    self.navigate (index);
	});
    }

    this.drawBreadCrumbs = function () {
	var bc = self.nav.breadCrumbs;
	OAT.Dom.clear(bc);
	var a = OAT.Dom.create("span", {className: "bc_title"});
	a.innerHTML = "Result";
//	a.href = "#";
	a.title = "Initial query result";

	OAT.Event.attach(a,"click",function() {
	    if (self.historyIndex != -1) {
		self.historyIndex = -1;
		self.history = [];
		self.redraw();
	    }
	});

	bc.appendChild (a);

	for (var i=0;i<self.historyIndex+1;i++) {
	    a = OAT.Dom.create("a");
	    var iid = self.history[i].iid;

	    if (iid in self.parent.store.labels)
		a.innerHTML = self.parent.store.labels[iid].label;
	    else
		if (self.options.raw_iris) 
                    a.innerHTML = OAT.IRIDB.getIRI(iid);
                else 
		a.innerHTML = self.parent.store.getCIRIorSplit(iid);

	    a.title = a.href = OAT.IRIDB.getIRI(iid);

	    OAT.Event.attach (a,"click", self.breadCrumbClickFun (i));

	    var sep = OAT.Dom.create("span",{className: "bc_sep"})
	    sep.innerHTML = ">";
	    bc.appendChild(sep);
	    bc.appendChild(a);
	}
    }

    this.navigate = function(index) { /* navigate to history index */
	var item = self.history[index];
	self.drawItem(item);
	self.historyIndex = index;
	self.redrawTop();
    }

    this.redrawTop = function() { /* navigation controls */
	var activate = function(elm) {
	    OAT.Style.set(elm,{opacity:1});
	    elm.style.cursor = "pointer";
	}
	var deactivate = function(elm) {
	    OAT.Style.set(elm,{opacity:0.3});
	    elm.style.cursor = "default";
	}
	if (self.historyIndex > 0) {
	    activate(self.nav.first);
	    activate(self.nav.prev);
	} else {
	    deactivate(self.nav.first);
	    deactivate(self.nav.prev);
	}

	if (self.historyIndex > -1 && self.historyIndex < self.history.length-1) {
	    activate(self.nav.next);
	    activate(self.nav.last);
	} else {
	    deactivate(self.nav.next);
	    deactivate(self.nav.last);
	}

	if (self.historyIndex != -1) {
	    activate(self.nav.help);
	} else {
	    deactivate(self.nav.help);
	}
	self.nav.position.innerHTML = self.historyIndex+1;
	self.nav.historyCount.innerHTML = "("+(self.history.length)+")";
	self.drawBreadCrumbs();
    }

    this.drawSpotlightHeading = function(tr,label,arr,cnt) {
	tr._rows = arr;
	self.gd.addTarget(tr);
	self.gd.addSource(tr,self.gdProcess,self.dropReference(tr,arr));
	var states = ["&#x25bc;","&#x25b6;"];
	var state = 0;
	var arrow = OAT.Dom.create("span",{cursor:"pointer"});
	arrow.innerHTML = states[state];
	var td = OAT.Dom.create("td");
	td.appendChild(arrow);
	tr.appendChild(td);
	var td = OAT.Dom.create("td");
	td.colSpan = 3;

	var simple;

	if (self.options.raw_iris) 
            simple = OAT.IRIDB.getIRI(label); 
        else 
	simple = self.parent.store.getCIRIorSplit(label);

	if (cnt > 1 && simple.charAt(0) != "[" && simple in self.plurals) {
	    simple = self.plurals[simple];
	}//]

	var a = OAT.Dom.create("a", {className: "nav_rdf_subject"});

	a.innerHTML = simple;
	a.title = OAT.IRIDB.getIRI(label);
	a.href = simple;

	td.appendChild (a);
	tr.appendChild(td);

	OAT.Event.attach(arrow,"click",function() {
	    state = (state+1) % 2;
	    arrow.innerHTML = states[state];
	    for (var i=0;i<arr.length;i++) {
		if (state) { OAT.Dom.hide(arr[i]); } else { OAT.Dom.show(arr[i]); }
	    }
	});
    }

    this.drawSpotlightType = function(label,data,table) {
	var state = (self.mlCache.indexOf(label) == -1 ? 0 : 1);
	var states = [" more...","less..."];
	var min = Math.min(data.length,self.options.limit);
	var count = (state ? data.length : min);
	var tr = OAT.Dom.create("tr",{className:"rdf_nav_header"});
	var trset = [];
	self.drawSpotlightHeading(tr,label,trset,data.length);
	table.appendChild(tr);
	var createRow = function(item) {
	    var tr = OAT.Dom.create("tr");
	    tr.appendChild(OAT.Dom.create("td"));
	    var td = OAT.Dom.create("td");
	    td.appendChild(self.drawPredicate(item));
	    tr.appendChild(td);
	    if (item.constructor != OAT.RDFAtom) {
		var predc = 0;
		var propc = 0;
		for (var p in item.preds) {
		    predc++;
		    propc += item.preds[p].length;
		}
		
		var td1 = OAT.Dom.create("td",{className:"rdf_nav_desc"});
		td1.innerHTML = predc+" properties"
		var td2 = OAT.Dom.create("td",{className:"rdf_nav_desc"});
		td2.innerHTML = propc+" values"
		OAT.Dom.append([tr,td1,td2]);
	    } else {
		td.colSpan = 3;
	    }
	    return tr;
	}

	for (var i=0;i<count;i++) {
	    var item = data[i];
	    var tr = createRow(item);
	    trset.push(tr);
	    table.appendChild(tr);
	}

	if (self.options.limit < data.length) {
	    var toggletr = OAT.Dom.create("tr",{className:"rdf_nav_toggle"});
	    toggletr.appendChild(OAT.Dom.create("td"));
	    trset.push(toggletr);
	    var td = OAT.Dom.create("td");
	    var toggle = OAT.Dom.create("span",{className:"toggler"});
	    toggle.innerHTML = (state ? states[state] : (data.length - min) + states[state]);
	    OAT.Dom.append([td,toggle],[toggletr,td],[table,toggletr]);
	    OAT.Event.attach(toggle,"click",function() {
		state = (state+1) % 2;
		toggle.innerHTML = (state ? states[state] : (data.length - min) + states[state]);
		if (state) { /* show more */
		    self.mlCache.push(label);
		    for (var i=min;i<data.length;i++) {
			var item = data[i];
			var tr = createRow(item);
			trset.splice(i,0,tr);
			table.insertBefore(tr,toggletr);
		    }
		} else { /* show less */
		    var index = self.mlCache.indexOf(label);
		    self.mlCache.splice(label,index);
		    for (var i=data.length-1;i>=min;i--) {
			OAT.Dom.unlink(trset[i]);
			trset.splice(i,1);
		    }
		}
	    }); /* click callback */
	}
    }

    this.drawSpotlight = function(title, uri, obj) { /* list of resources */
	OAT.Dom.clear(self.mainDiv);
	var t_elm = OAT.Dom.create("h3",{className:"rdf_nav_title"});

	if (uri) {
            var a = OAT.Dom.create ("a");
            a.href = uri;
            a.innerHTML = title;
            OAT.Dom.append ([t_elm, a]);
	}
	else 
            t_elm.innerHTML = title;

	var table = OAT.Dom.create("table",{className:"rdf_nav_spotlight"});
	var tbody = OAT.Dom.create("tbody");
	OAT.Dom.append([self.mainDiv,t_elm,table],[table,tbody]);
	var remain = false;

	for (i=0;i<obj.length;i++)
	    self.drawSpotlightType(obj[i][0],obj[i][1],tbody);
    }

    this.redraw = function() {
	if (self.waiting) { self.waiting = false; }
	if (self.historyIndex != -1) {
	    self.navigate(self.historyIndex);
	    return;
	}
	/* give a list of graphs for navigation */
	var obj = self.getTypeObject();
	self.drawSpotlight("Click on a Data Entity to explore its Linked Data Web.",false,obj);
	self.redrawTop();
    }

    this.initTop = function() {
	var ip = self.parent.options.imagePath;
	var b = ip+"Blank.gif";

	self.nav.first = OAT.Dom.create("div");
	self.nav.prev = OAT.Dom.create("div");
	self.nav.help = OAT.Dom.create("div"); // XXX should be home
	self.nav.next = OAT.Dom.create("div");
	self.nav.last = OAT.Dom.create("div");
	self.nav.position = OAT.Dom.create("div");
	self.nav.historyCount = OAT.Dom.create("div");
	self.nav.breadCrumbs = OAT.Dom.create("div",{id:"rdf_nav_breadcrumbs"});
	self.nav.first.appendChild(OAT.Dom.image(ip+"RDF_first.png",b,16,16));
	self.nav.prev.appendChild(OAT.Dom.image(ip+"RDF_prev.png",b,16,16));
	self.nav.help.appendChild(OAT.Dom.image(ip+"RDF_help.png",b,16,16)); // XXX should be home
	self.nav.next.appendChild(OAT.Dom.image(ip+"RDF_next.png",b,16,16));
	self.nav.last.appendChild(OAT.Dom.image(ip+"RDF_last.png",b,16,16));

	self.nav.first.title = "First";
	self.nav.prev.title = "Back";
	self.nav.help.title = "List of resources";
	self.nav.next.title = "Forward";
	self.nav.last.title = "Last";

	OAT.Dom.append([self.topDiv,self.nav.help,self.nav.first,self.nav.prev,self.nav.position,self.nav.historyCount,self.nav.next,self.nav.last,self.nav.breadCrumbs]);
	OAT.Event.attach(self.nav.first,"click",function() {
	    if (self.historyIndex > 0) { self.navigate(0); }
	});
	OAT.Event.attach(self.nav.prev,"click",function() {
	    if (self.historyIndex > 0) { self.navigate(self.historyIndex-1); }
	});
	OAT.Event.attach(self.nav.next,"click",function() {
	    if (self.historyIndex > -1 && self.historyIndex < self.history.length-1) { self.navigate(self.historyIndex+1); }
	});
	OAT.Event.attach(self.nav.last,"click",function() {
	    if (self.historyIndex > -1 && self.historyIndex < self.history.length-1) { self.navigate(self.history.length-1); }
	});
	OAT.Event.attach(self.nav.help,"click",function() {
	    if (self.historyIndex != -1) {
		self.historyIndex = -1;
		self.history = [];
		self.redraw();
	    }
	});
    }
    self.initTop();
}

OAT.RDFTabs.triples = function(parent,optObj) {
    var self = this;
    OAT.RDFTabs.parent(self);
    this.options = {
	pageSize:100,
	removeNS:true,
	description:"This module displays all filtered triples.",
	desc:"All filtered triples",
        raw_iris: false
    }
    for (var p in optObj) { self.options[p] = optObj[p]; }

    this.parent = parent;
    this.initialized = false;
    this.grid = false;
    this.currentPage = 0;
    this.pageDiv = OAT.Dom.create("div");
    this.gridDiv = OAT.Dom.create("div");
    this.description = self.options.description;
    this.desc = self.options.desc;

//    this.select = OAT.Dom.create("select");
//    OAT.Dom.option("Human readable","0",this.select);
//    OAT.Dom.option("Machine readable","1",this.select);

    OAT.Dom.append([self.elm,self.pageDiv,self.gridDiv]);

//
// XXX patchEmbedded is dead code for now
//

    this.patchEmbedded = function(column,atom) {
	var v = self.grid.rows[self.grid.rows.length-1].cells[column].value;
	var all = v.getElementsByTagName("a");
	var uris = [];
	for (var i=0;i<all.length;i++) { uris.push(all[i]); }
	for (var i=0;i<uris.length;i++) {
	    var uri = uris[i];
	    self.parent.processLink(uri,uri.href);
	}
    }

    this.reset = function() {
	self.currentPage = 0;
    }

    this.drawPager = function() {
	var cnt = OAT.Dom.create("div");
	var div = OAT.Dom.create("div");
	var count = self.parent.data.triples.length;

	cnt.innerHTML = "There are "+count+" triples available.";
	OAT.Dom.clear(self.pageDiv);
	OAT.Dom.append([self.pageDiv,cnt,div]);

	function assign(a,page) {
	    a.setAttribute("title","Jump to page "+(page+1));
	    a.setAttribute("href","#");
	    OAT.Event.attach(a,"click",function(event) {
		OAT.Event.prevent(event);
		self.currentPage = page;
		self.redraw();
	    });
	}

	if (count > self.options.pageSize) { /* create pager */
	    div.innerHTML = "Page: ";
	    var pagecount = Math.ceil(count/self.options.pageSize);
	    for (var i=0;i<pagecount;i++) {
		var a = OAT.Dom.create("a");
		if (i != self.currentPage) { assign(a,i); }
		div.appendChild(OAT.Dom.text(" "));
		div.appendChild(a);
		a.innerHTML = i+1;
		div.appendChild(OAT.Dom.text(" "));
	    }
	}
    }

    this.processColumn = function (pos, atom) {
	var v = self.grid.rows[self.grid.rows.length-1].cells[pos+1].value;
	var iid;

	if (atom.constructor == OAT.RDFAtom) {
	    if (atom.isLit ()) {
		v.innerHTML = atom.getValue();
		return;
	    }
	    if (atom.isIRI ()) {
		iid = atom.getIID();
	    }
	} else {
	    if (typeof (atom) == 'object')
		iid = atom.iid;
	    else 
		iid = atom; // this is a plain IID value
	}


	try { 	// Dirty data does exist, you see...
	var iri = decodeURIComponent(OAT.IRIDB.getIRI(iid));
            var col_v_elm = OAT.Dom.create("a");

            if (self.options.raw_iris)
              col_v_elm.innerHTML = iri;
            else 
              col_v_elm = self.parent.store.getCIRIorSplit(iid);

	    col_v_elm.href = iri;
	    self.parent.processLink(col_v_elm, iri);
        } catch (e) {
	    col_v_elm = OAT.Dom.create("span",{className:"error_col"});
            col_v_elm.innerHTML = OAT.IRIDB.getIRI(iid) + " (invalid URI)";
	}
	OAT.Dom.clear(v);
	v.appendChild(col_v_elm);
    }

    this.redraw = function() {
	if (!self.initialized) {
	    self.initialized = true;
	    self.grid = new OAT.Grid(self.gridDiv,{autoNumber:true,allowHiding:true});
	}
	self.grid.options.rowOffset = self.options.pageSize * self.currentPage;
	self.grid.createHeader(["Subject","Predicate","Object"]);
	self.grid.clearData();

	var total = 0;
	var triples = self.parent.data.triples;
	for (var i=0;i<triples.length;i++) {
	    if (i >= self.currentPage * self.options.pageSize && i < (self.currentPage + 1) * self.options.pageSize) {
		self.grid.createRow(["","",""]);
		var t = triples[i];
		for (var j=0;j<t.length;j++) {
		    self.processColumn (j,t[j]); 
		}
	    } /* if in current page */
	} /* for all triples */
	self.drawPager();
    }
    OAT.Event.attach(self.select,"change",self.redraw);
}

OAT.RDFTabs.svg = function(parent,optObj) {
    var self = this;
    OAT.RDFTabs.parent(self);
    this.options = {
	limit:100,
	description:"",
	desc:"Filtered data as SVG Graph",
        raw_iris: false
    }
    for (var p in optObj) { self.options[p] = optObj[p]; }

    if (!self.options.description)
	self.options.description = "This module displays filtered data as SVG Graph. Display is limited to "+self.options.limit+" triples.";

    this.parent = parent;
    this.description = self.options.description;
    this.desc = self.options.desc;
    this.elm.style.position = "relative";
    this.elm.style.height = "600px";
    this.elm.style.top = "24px";

    this.redraw = function() {
	/* create better triples */
	var triples = [];
	var cnt = self.parent.data.triples.length;

	if (cnt > self.options.limit) {
	    var note = new OAT.Notify(false, {notifyType: 2});
	    var msg = "Note: Display limited to " + self.options.limit + " triples."
	    note.send (msg,{delayIn:10,timeout:5000});
	    cnt = self.options.limit;
	}

	for (var i=0;i<cnt;i++) {
	    var t = self.parent.data.triples[i];

	    //
	    // XXX: FIXME here and in RDFStore
	    //
 
	    var new_o;

	    if (t[2].constructor == OAT.RDFAtom) {
		if (t[2].isIRI())
		    new_o = t[2].getIRI();
		else 
		    new_o = t[2].value;
	    }
	    else {
		if (typeof t[2] == 'object') {
		    new_o = OAT.IRIDB.getIRI(t[2].iid)
		}
		else new_o = t[2];
	    }
	    var triple = [OAT.IRIDB.getIRI(t[0]), 
			  OAT.IRIDB.getIRI(t[1]),
			  new_o];

//	    if (t[2].isIRI()) {
//		triple.push (t[2].getIRI());
//		triple.push (1);
//	    } else {
//		triple.push (t[2].getValue());
//		triple.push(0);
//	    }

	    triples.push(triple);
	}

	var x = OAT.GraphSVGData.fromTriples(triples);
	self.graphsvg = new OAT.GraphSVG(self.elm,x[0],x[1],{vertexSize:[4,8],sidebar:false});

	for (var i=0;i<self.graphsvg.data.length;i++) {
	    var node = self.graphsvg.data[i];
	    if (node.name && node.name.match(/^http/i)) {
		self.parent.processLink(node.svg,node.name);
	    }
	}
	this.elm.style.backgroundColor = '#cacce7';
    }
},

//
// Ordered data structure for points
// Not a R-Tree but may improve speed for some cases.
//

OAT.RDFTabs.PointList = function (opts) {
    var self = this;
    this._uniqueInsert = opts.uniqueInsert;
    this._list = [];

    this.__ins_new = function (pos, p, o) {
	self._list.splice (pos, 0, new Array (p[0], new Array (new Array (p[1], o))));
    }

    this._k = function (x) {
	if (typeof (x) != 'object') return x;
	return x[0];
    }

    this.find = function (p) {
    }

    this.find_1 = function (p) {}

    this.insert = function (p, o) {
	if (typeof (p) != 'object') throw new Error ('Invalid Point Type in Insert');

	if (typeof (p[0]) == 'string')
	    p[0] = parseFloat (p[0]);

	if (typeof (p[1]) == 'string')
	    p[1] = parseFloat (p[1]);

	if (!self._list.length || self._k(self._list[0] > p[0])) {
	    self.__ins_new (0, p, o)
	    return p;
	}

	if (self._k(self._list[self._list.length-1]) < p[0]) {
	    self._list.push(new Array (p[0], new Array (new Array (p[1], o))));
	    return (p);
	}

	return (self._ins_1 (p, o, 0, self._list.length-1));
    }

    this._ins_1 = function (p, o, st, en) {
	if (self._k(self._list[st]) == p[0])
	    return (self.ins_y (p, o, self._list[st][1])) // found existing X, now insert y in ylist

	if (st == en) {
	    if (self._k(self._list[st]) > p[0])
		self.__ins_new (st, p, o);
	    else
		self.__ins_new (st+1, p, o);
	    return p;
	}

	// recurse

	var split = Math.floor (((en-st)/2)+st);

	if (self._k(self._list[split]) < p[0])
	    return (self._ins_1 (p, o, split+1, en))
	else
	    return (self._ins_1 (p, o, st, split));
    }

    this.ins_y = function (p, o, lst) {
	if (p[1] < lst[0][0]) {
	    lst.splice (0, 0, new Array (p[1], o));
	    return p;
	}

	if (p[1] > lst[lst.length-1]) {
	    lst.push (p[1]);
	    return p;
	}

	return (self.ins_y_1 (p, o, lst, 0, lst.length-1));
    }

    this.ins_y_1 = function (p, o, lst, st, en) {
	if (self._k(lst[st]) == p[1]) {
	    if (!self._uniqueInsert)
		lst.splice (st, 0, new Array (p[1], o));
	    return p;
	}

	if (st == en) {
	    if (self._k(lst[st]) > p[1])
		lst.splice (st, 0, new Array (p[1], o))
	    else
		lst.splice (st+1, 0, new Array (p[1], o));
	    return p;
	}

	// recurse

	var split = Math.floor (((en-st)/2)+st);

	if (self._k(lst[split]) < p[1])
	    return (self.ins_y_1 (p, o, lst, split+1, en));
	else
	    return (self.ins_y_1 (p, o, lst, 0, split));
    }

    this.clear = function () {
	self._list = [];
    }

    this.length = function () {
	return self._list.length;
    }

    //
    // Get array of points [[2.3, 43.4][2.1, 42.2]..[]]
    //

    this.makeArray = function (unique) {
	var retArr = [];
	var vo, vn;
	for (var i=0;i<self._list.length;i++) {
	    vo = -1;
	    vn = -1;
	    for (var j=0;j<self._list[i][1].length;j++) {
		vn = self._list[i][1][j][0];
		if (!unique || vo == -1 || vn != vo) {
		    retArr.push (new Array (self._list[i][0], vn, self._list[i][1][j][1]));
		    vo = vn;
		}
	    }
	}
	return retArr;
    }

    this.makePointsArray = function (unique) {
	var retArr = [];
	for (var i=0;i<self._list.length;i++) {
	    var vo = -1;
	    var vn = -1;
	    for (var j=0;j<self._list[i][1].length;j++) {
		vn = self._list[i][1][j][0];
		if (!unique || vo == -1 || vn != vo) {
		    retArr.push (new Array (self._list[i][0], vn));
		    vo = vn;
		}
	    }
	}
	return retArr;
    }
}

//
// Sends MAP_NOTHING_TO_SHOW if there's nothing to show on map
//

OAT.RDFTabs.map = function(parent,optObj) {
    var self = this;
    OAT.RDFTabs.parent(self);

    this.options = {
	provider:OAT.Map.TYPE_G3,
	fix:OAT.Map.FIX_ROUND1,
	markerMode: OAT.RDFTabsData.MARKER_MODE_DISTINCT_O, // backwards compatible default
	description:"This module plots all geodata found in filtered resources onto a map.",
	desc:"Plots all geodata onto a map",
	clickPopup:true,
	hoverPopup:true,
	height: "600px",
	useMobileOpts:false,
	supportedMobileDetected:false,
        raw_iris: false
    }

    for (var p in optObj) { self.options[p] = optObj[p]; }

    this.map = false;
    this.map_loaded = false;
    this.parent = parent;
    this.description = self.options.description;
    this.desc = self.options.desc;
    this.elm.style.position = "relative";

    var useragent = navigator.userAgent;
    
    if (useragent.indexOf('iPhone') != -1 || useragent.indexOf('Android') != -1 ) {
	self.elm.style.width = '100%';
	self.elm.style.height = '100%';
	self.options.supportedMobileDetected = true;
    } else {
    this.elm.style.height = self.options.height;
    }

    // Various properties used to obtain @ICBM.mil address
    //

    this.keyProperties    = OAT.IRIDB.insertIRIArr (["http://xmlns.com/foaf/0.1/based_near",
						    "http://www.w3.org/2003/01/geo/wgs84_pos",
						     "http://www.w3.org/2003/01/geo/geometry",
						     "http://www.w3.org/2003/01/geo/wgs84_pos#geometry"]); /* containing coords */

    this.locProperties    = OAT.IRIDB.insertIRIArr (["http://xmlns.com/foaf/0.1/location", 
						     "http://www.w3.org/2006/vcard/ns#locality",
						     "http://www.w3.org/2001/vcard-rdf/3.0#Locality"]); /* containing location */

    this.latProperties    = OAT.IRIDB.insertIRIArr (["http://www.w3.org/2003/01/geo/lat",
						     "http://www.w3.org/2003/01/geo/wgs84_pos#lat",
						     "http://www.w3.org/2003/01/geo/latitude", 
						     "http://www.w3.org/2006/vcard/ns#latitude",
						     "http://www.w3.org/2001/vcard-rdf/3.0#latitude",
						     "http://dbpedia.org/property/lat",
						     "http://www.openlinksw.com/schemas/zillow#latitude"]);

    this.lonProperties    = OAT.IRIDB.insertIRIArr (["http://www.w3.org/2003/01/geo/lng",
						     "http://www.w3.org/2003/01/geo/wgs84_pos#long",
						     "http://www.w3.org/2003/01/geo/lon",
						     "http://www.w3.org/2003/01/geo/long",
						     "http://www.w3.org/2003/01/geo/longitude",
						     "http://www.w3.org/2006/vcard/ns#longitude",
						     "http://www.w3.org/2001/vcard-rdf/3.0#longitude",
						     "http://dbpedia.org/property/long",
						     "http://www.openlinksw.com/schemas/zillow#longitude"]);

    this.lookupProperties = OAT.IRIDB.insertIRIArr (["http://xmlns.com/foaf/0.1/name",
						     "http://xmlns.com/foaf/0.1/location"]); /* interesting to be put into lookup pin */

    this.pointTypes = OAT.IRIDB.insertIRIArr (["http://www.w3.org/2003/01/geo/Point", 
					       "http://www.w3.org/2003/01/geo/wgs84_pos#Point",
					       "http://www.georss.org/georss/point",
					       "http://www.openlinksw.com/schemas/virtrdf#Geometry"]);

    this.markerPredBlacklist = OAT.IRIDB.insertIRIArr (["http://www.openlinksw.com/schemas/oat/rdftabs#useMarker",
							"http://xmlns.com/foaf/0.1/based_near",
							"http://www.w3.org/2003/01/geo/wgs84_pos",
							"http://www.w3.org/2003/01/geo/geometry",
							"http://www.w3.org/2003/01/geo/wgs84_pos#geometry",
							"http://www.w3.org/2003/01/geo/lat",
							"http://www.w3.org/2003/01/geo/wgs84_pos#lat",
							"http://www.w3.org/2003/01/geo/latitude", 
							"http://www.w3.org/2006/vcard/ns#latitude",
							"http://www.w3.org/2001/vcard-rdf/3.0#latitude",
							"http://dbpedia.org/property/lat",
							"http://www.w3.org/2003/01/geo/lng",
							"http://www.w3.org/2003/01/geo/wgs84_pos#long",
							"http://www.w3.org/2003/01/geo/lon",
							"http://www.w3.org/2003/01/geo/long",
							"http://www.w3.org/2003/01/geo/longitude",
							"http://www.w3.org/2006/vcard/ns#longitude",
							"http://www.w3.org/2001/vcard-rdf/3.0#longitude",
							"http://dbpedia.org/property/long",
							"http://www.w3.org/2003/01/geo/Point", 
							"http://www.w3.org/2003/01/geo/wgs84_pos#Point",
							"http://www.georss.org/georss/point",
							"http://www.openlinksw.com/schemas/virtrdf#Geometry"]);

    this.usedBlanknodes = [];
    this.pointList = new OAT.RDFTabs.PointList({uniqueInsert:true});

    this.geoCode = function(address,item) {
	self.pointListLock++;
	var cb = function(coords) {
	    if (coords && coords[0] != 0 && coords[1] != 0) {
		self.attachMarker(coords,item);
	    }
	    self.pointListLock--;
	}
	self.map.geoCode(address,cb);
    }

    this.extractCoords = function (preds) {
	coords = [];
	for (var p in preds) {
	    var pred = preds[p];
	    if (!!(p = parseInt(p))) {
		if (self.latProperties.indexOf(p) != -1) { coords[0] = pred[0]; }
		if (self.lonProperties.indexOf(p) != -1) { coords[1] = pred[0]; }
	    }
	} /* for all geo properties */
	return (coords);
    }

    this.tryItem = function(item) {
	var preds = item.preds;
	var pointResource = false;
	var locValue = false;
	var coords = [0,0];

	if (item.type) {
	    for (var i=0;i<item.type.length;i++) {
		if (self.pointTypes.indexOf(item.type[i].getValue()) != -1)
	    coords = self.extractCoords (item.preds);
	}
	}

	    for (var p in preds) {
		var pred = preds[p];
	    if (!!(p = parseInt(p))) {	    
		if (self.keyProperties.indexOf(p) != -1) { 
		    if (pred[0] instanceof OAT.RDFAtom && pred[0].isLit())
		    pointResource = pred[0].getValue(); 
		} /* resource containing geo coordinates */
		if (self.locProperties.indexOf(p) != -1) { 
		    locValue = pred[0].getValue(); 
		} /* resource containing geo coordinates */
		if (self.latProperties.indexOf(p) != -1) {
		    coords[0] = pred[0].getValue();
		}
		if (self.lonProperties.indexOf(p) != -1) {
		    coords[1] = pred[0].getValue();
		}
	    }
	    }

	if (coords[0] != 0 && coords[1] != 0) {
	    if (!!window.console && window.oat_debug) window.console.log ('found coords :' + coords[0] + ' ' + coords[1]);
	    self.attachMarker(coords, item);
	    return;
	}

	if (!pointResource && !locValue && (coords[0] == 0 || coords[1] == 0)) { 
	    return; // Nothing here. Move on.
	}
	
	if (!pointResource && locValue) { /* geocode location */
	    if (!!window.console && window.oat_debug) window.console.log ('geocoding: '+locValue);
	    self.geoCode(locValue,item);
		return;
	    }
	
	if (typeof pointResource == "string") { // handle geo:geometry coords, etc.
		var cmatches = pointResource.match (/POINT\((-?\d+\.*\d*) (-?\d+\.*\d*)/)
		if (!!cmatches && cmatches.length == 3) {
		    coords[0] = cmatches[2];
		    coords[1] = cmatches[1];
		    if (coords[0] == 0 || coords[1] == 0) { return; }
		self.attachMarker(coords,item);
		    return;
		}
	    
	    cmatches = pointResource.match (/(-?\d+\.*\d*) (-?\d+\.*\d*)/);
	    if (!!cmatches && cmatches.length == 3) {
		coords[0] = cmatches[2];
		coords[1] = cmatches[1];
		if (coords[0] == 0 || coords[1] == 0) { return; }
		self.attachMarker(coords,item);
		return;
	    }
	    }
	
	    self.usedBlanknodes.push(pointResource);

	    /* normal marker add */
	    coords = self.extractCoords (pointResource.preds);

	if (coords[0] == 0 || coords[1] == 0) { return; }

	self.attachMarker(coords, item);
    } /* tryItem */

    this.trySimple = function(item) {
	if (self.usedBlanknodes.find(item) != -1) { return; }
	var preds = item.preds;
	var coords = [0,0];
	for (var p in preds) {
	    var pred = preds[p];
	    if (self.latProperties.indexOf(p) != -1) { coords[0] = pred[0]; } /* latitude */
	    if (self.lonProperties.indexOf(p) != -1) { coords[1] = pred[0]; } /* longitude */
	}
	if (!coords[0] && !coords[1]) { return; }
	self.attachMarker(coords,item);
    } /* trySimple */

    this.getMarker = function(item) {
	var markerPath = OAT.Preferences.imagePath+"markers/";
	var markerFile;
	var mpred;
	var m_p_iid = OAT.IRIDB.insertIRI('http://www.openlinksw.com/schemas/oat/rdftabs#useMarker');
	switch (self.options.markerMode) {
	case OAT.RDFTabsData.MARKER_MODE_DISTINCT_O:
            var ouri = item.ouri;
            if (!(ouri in self.markerMapping)) {
                self.markerMapping[ouri] = self.markerFiles[self.markerIndex % self.markerFiles.length];
                self.markerIndex++;
            }
            markerFile = self.markerMapping[ouri];
	    break;
	case OAT.RDFTabsData.MARKER_MODE_BY_TYPE:
	    return markerPath + '01.png';
	    break;
	case OAT.RDFTabsData.MARKER_MODE_EXPLICIT:
	    if (typeof (item.preds[m_p_iid]) != 'undefined') {
	    mpred = item.preds[m_p_iid][0];
		if (mpred.constructor == OAT.RDFAtom) {
		    if (mpred.isIRI())
			markerFile = mpred.getIRI();
		    else if (mpred.isLit()) {
			markerFile = mpred.getValue();
			if (!markerFile.toUpperCase().match(/HTTP(S?):\/\//)) {
			    markerFile = markerPath + markerFile+'.png';
			}
		    }
		}
	    }
	    break;
	case OAT.RDFTabsData.MARKER_MODE_AUTO:
	    if (typeof (item.preds[m_p_iid]) != 'undefined') { // explicit marker def takes precedence
	    mpred = item.preds[m_p_iid][0];
		if (mpred.constructor == OAT.RDFAtom) {
		    if (mpred.isIRI())
			markerFile = mpred.getIRI();
		    else if (mpred.isLit()) {
			markerFile = mpred.getValue();
			if (!markerFile.toUpperCase().match(/HTTP(S?):\/\//)) {
			    markerFile = markerPath + markerFile+'.png';
			}
		    }
		}
		else
		markerFile = markerPath + mpred + '.png';
		break;
	    }
	    else {
		markerFile = markerPath + self.getMarkerByType (item);
	    }

	}
	return markerFile;
    }

    this.getMarkerByType = function (item) { // XXX not implemented
	return '01.png';
    }

    this.attachMarker = function(coords, item) {
	self.pointList.insert (coords, {item: item});
    }

    this.getAbstract = function(item) {
	for (p in item.preds) {
	    var comIRI = OAT.IRIDB.insertIRI("http://www.w3.org/2000/01/rdf-schema#comment");
	    if (parseInt(p) == comIRI) { 
		return item.preds[p][0].getValue();
	    }
	}
	return false;
	}

    // an item isCoordinateContainer if it's referred by another item and
    // its type property values are all geo point types and/or it only has geo coordinate properties

    this.isCoordinateContainer = function (item) {
	type_iid = OAT.IRIDB.getIRIID("http://www.w3.org/1999/02/22-rdf-syntax-ns#type");
	if (!item.back.length) 
	    return false;
	var preds = item.preds;
	var nc_cnt = 0;
	for (var p in preds) {
	    var pVal = parseInt(p);
	    if (pVal == type_iid) { // go through types - pointTypes don't count
		for (var i=0;i<preds[p].length;i++) {
		    if (self.pointTypes.find(preds[p][i].getIID()) == -1)
			return false;
		}
	    } else {
		if (self.lonProperties.find(pVal) != -1 ||
		    self.latProperties.find(pVal) != -1 || 
		    self.keyProperties.find(pVal) != -1) {
		    continue;
		}
		else return false; // got a non-geo-property
	    }
	}
	return true;
    }

    this.drawReferences = function (item, container) {
        var p_table = OAT.Dom.create ("table");
	for (i=0;i<item.back.length;i++) { // include backreferences;
	    var predC = OAT.Dom.create("tr",{className:"predicate"});
	    var predT = OAT.Dom.create("td",{className:"pred_title"});
	    predT.innerHTML = "Referenced by";
	    var predV = OAT.Dom.create("td",{className:"pred_value"});
	    var content = self.parent.getContent(item.back[i], "replace");
	    OAT.Dom.append([predV,content],[predC,predT,predV], [p_table,predC]);
	}
	OAT.Dom.append ([container,p_table]);
    }

//
// Return marker content for item
//    

    this.drawAllProps = function (item, container) {
	var preds = item.preds;
        var p_table = OAT.Dom.create ("table");
	for (var p in preds) {
	    if (self.markerPredBlacklist.find(parseInt(p)) != -1) continue; // Not all predicates are created equal
	    var pred = preds[p];
            var simple;

	    if (self.options.raw_iris)
              simple = OAT.IRIDB.getIRI (p); 
            else 
              simple = self.parent.store.getCIRIorSplit(p);

	    if (pred.length == 1 || self.lookupProperties.find(simple) != -1) {
		var predC = OAT.Dom.create("tr",{className:"predicate"});
		var predT = OAT.Dom.create("td",{className:"pred_title"});
		predT.innerHTML = simple;
		var predV = OAT.Dom.create("td",{className:"pred_value"});
		var content = self.parent.getContent(pred[0],"replace");
		OAT.Dom.append([predV,content],[predC,predT,predV],[p_table,predC]);
	    } /* only interesting data */
	} /* for all predicates */
        OAT.Dom.append([container,p_table])
	return container;
    }

    this.showMarkerPopup = function () {

    }

    this.hideMarkerPopup = function () {

    }

    this.makeAnchor = function (ctr, content, href) {
	var a = OAT.Dom.create ("a");
	a.href=href;
        
    }
    this.drawMarker = function (item) {
	if (self.isCoordinateContainer(item))
	    var s_item = item.back[0];
	else 
	    s_item = false;

	var titleH = OAT.Dom.create("h2",{className:"markerTitle"});

	var title = self.parent.getTitle(s_item ? s_item : item);
	var titleHref='';
	var popup_ctr;

	if (self.options.supportedMobileDetected && self.options.useMobileOpts) {
	    var titleA = OAT.Dom.create ("a");
	    OAT.Dom.attach (titleA,"click",self.showMarkerPopup);
	}
	else {
	if (title.match(/^http/i)) {
	        var titleA = OAT.Dom.create("a",{href:titleHref,target:"_blank"});
		self.parent.processLink(titleA, title);
		titleA.innerHTML = title;
		OAT.Dom.append ([titleH, titleA]);		
	} else {
		var titleHref = self.parent.getURI(s_item ? s_item : item);
	    if (titleHref) {
		var titleA = OAT.Dom.create("a",{href:titleHref,target:"_blank"});
		    self.parent.processLink(titleA, titleHref);
		titleA.innerHTML = title;
		OAT.Dom.append ([titleH, titleA]);
	    } else {
		titleH.innerHTML = title;
	    }
	}

	    var ctr = OAT.Dom.create("div",{className:'marker_ctr'});
	    var abstr = self.getAbstract(s_item ? s_item : item);

	if (abstr) {
	var abstrC = OAT.Dom.create("div",{className:'abstract'});
	    abstrC.innerHTML = abstr;
	}	
	}
	
	//	if (self.parent.store.itemHasType (item, "")) { }
	//	if (self.parent.store.itemHasType (item, "")) { }

	var props_ctr = OAT.Dom.create("div", {className: "props_ctr"});

	if (abstr)
	    OAT.Dom.append([ctr,titleH,abstrC,props_ctr]);
	else 
	    OAT.Dom.append([ctr,titleH,props_ctr]);

	self.drawAllProps (s_item ? s_item : item, props_ctr);
	self.drawReferences (s_item ? s_item : item, props_ctr);

	return ctr;
    }

    this.markerClickHandler = function(caller, msg, m) {
	item = m.__oat_rdftabs_item;
	if (OAT.AnchorData && OAT.AnchorData.window) { OAT.AnchorData.window.close(); }
	var div = self.drawMarker(item);
	self.map.openWindow(m, div);
    }


    this.makeAndAddMarker = function (x,y,item) {
	var m = false;
	var markerImg = self.getMarker(item);

	m = self.map.addMarker(x,
			       y,
			       false,
			       {image:markerImg,
				imageSize:[18,41],
				custData: {__oat_rdftabs_item: item}});
    }

    this.addMarkers = function () {
	var pArr = self.pointList.makeArray (true);
	var o,x,y,clickCB,hoverCB,markerImg;
	var item;

	for (var i=0; i<pArr.length; i++) {
	    x = pArr[i][0];
	    y = pArr[i][1];
	    item = pArr[i][2].item;

	    self.makeAndAddMarker (x,y,item);
	}
	OAT.MSG.attach ("*", "MAP_MARKER_CLICK", self.markerClickHandler);
	self.map.showMarkers(false);
    }

    this.redraw = function() {
	self.usedBlanknodes = [];
	var markerPath = OAT.Preferences.imagePath+"markers/";
	self.markerFiles = [];
	for (var i=1;i<=12;i++) {
	    var name = markerPath + (i<10?"0":"") + i +".png";
	    self.markerFiles.push(name);
	}
	self.markerIndex = 0;
	self.markerMapping = {};

	var cb = function() {
	    self.map_loaded = true;
	    self.map.init(self.options.provider);
	    self.map.centerAndZoom(0,0,0);
//	    self.map.addTypeControl();
//	    self.map.addMapControl();
//          self.map.addTrafficControl();
	    self.map.showControls();
	    self.pointList.clear();
	    self.pointListLock = 0;
	    for (var i=0;i<self.parent.data.structured.length;i++) {
		var item = self.parent.data.structured[i];
		self.tryItem(item);
	    }
	    for (var i=0;i<self.parent.data.structured.length;i++) {
		var item = self.parent.data.structured[i];
		self.trySimple(item);
	    }

	    
	    self.addMarkers();
	    
	}

	if (!self.map_loaded) {
	    self.map = new OAT.Map(self.elm,
				   self.options.provider,
				   {fix:self.options.fix,markerIcon:"toolkit/images/markers/01.png",
				    markerIconSize:[18,41]},
				   self.options.specificOpts);
	    OAT.Map.loadApi(self.options.provider,{callback: cb});
	}

	OAT.Resize.createDefault(self.elm);

	function tryList() {
	    if (!self.pointListLock && self.map_loaded) {
		if (!self.pointList.length()) {
		    var note = new OAT.Notify (false, {notifyType: 2});
		    var msg = "Current data set contains nothing that could be displayed on the map.";
		    note.send(msg, {timeout: 4000});
		    OAT.MSG.send (self, "MAP_NOTHING_TO_SHOW", false);
		}
                clearTimeout (window.tryListTo);
		self.map.optimalPosition(self.pointList.makePointsArray(false));
 	    } else {
		window.tryListTo = setTimeout(tryList,500);
	    }
	}
	tryList();
    }
}

OAT.RDFTabs.timeline = function(parent,optObj) {
    var self = this;
    OAT.RDFTabs.parent(self);

    this.options = {
	imagePath:OAT.Preferences.imagePath,
	description:"This module displays all date/time containing resources on an interactive timeline.",
	desc:"Date/time on timeline",
        raw_iris: false
    }
    for (var p in optObj) { self.options[p] = optObj[p]; }

    this.initialized = false;
    this.parent = parent;
    this.description = self.options.description;
    this.desc = self.options.desc;
    this.elm.style.position = "relative";
    this.elm.style.margin = "1em";
    this.elm.style.top = "20px";

    //ical: http://www.w3.org/2002/12/cal/ical/
	
    this.bothProperties = [
	"http://purl.org/dc/elements/1.1/date", 
	"http://purl.org/dc/terms/created", 
	"http://www.w3.org/2002/12/cal/ical#created" ]; /* containing date */

    this.startProperties = [
	"http://microformats.org/wiki/hcalendar/dtstart",
	"http://www.w3.org/2002/12/cal/ical#dtstart"];

    this.endProperties = [
	"http://microformats.org/wiki/hcalendar/dtend",
	"http://www.w3.org/2002/12/cal/ical#dtend"];

    this.subProperties = ["http://www.w3.org/2001/XMLSchema#dateTime"];

    this.tryDeepItem = function(value) {
	if (typeof(value) != "object") { return value; }
	for (var p in value.preds) {
	    var pred = value.preds[p];
	    if (self.subProperties.indexOf(p) != -1) { return pred[0]; }
	}
	return false;
    }

    this.tryItem = function(item) {
	var preds = item.preds;
	var start = false;
	var end = false;
	for (var p in preds) {
	    var pred = preds[p];
	    if (self.bothProperties.indexOf(p) != -1) {
		var value = pred[0];
		start = self.tryDeepItem(value);
		end = self.tryDeepItem(value);
	    }
	    if (self.startProperties.indexOf(p) != -1) {
		var value = pred[0];
		start = self.tryDeepItem(value);
	    }
	    if (self.endProperties.indexOf(p) != -1) {
		var value = pred[0];
		end = self.tryDeepItem(value);
	    }
	}
	if (!start) { return false; }
	if (!end) { end = start; }
	return [start,end];
    }

    this.redraw = function() {
	if (!self.initialized) {
	    self.tl = new OAT.Timeline(self.elm,self.options);
	    self.initialized = true;
	}
	var uris = [];
	self.tl.clear();
	var colors = ["#cf6","#887fff","#66ffe6","#fb9","#7fff66","#ff997f","#96f"]; /* pastel */

	for (var i=0;i<self.parent.data.structured.length;i++) {
	    var item = self.parent.data.structured[i];
	    var date = self.tryItem(item);

	    if (!date) { continue; }
	    var ouri = item.ouri;

	    if (uris.indexOf(ouri) == -1) {
		self.tl.addBand(ouri,colors[uris.length % colors.length]);
		uris.push(ouri);
	    }
	    var start = date[0];
	    var end = date[1];
	    /* add event */
	    var content = OAT.Dom.create("div",{left:"-7px"});
	    var ball = OAT.Dom.create("div",{width:"16px",height:"16px",cssFloat:"left",styleFloat:"left"});
	    ball.style.backgroundImage = "url("+self.options.imagePath+"Timeline_circle.png)";
	    var uri = self.parent.getURI(item);
	    if (uri) {
		var t = OAT.Dom.create("a");
		self.parent.processLink(t,uri);
	    } else {
		var t = OAT.Dom.create("span");
	    }
	    t.innerHTML = self.parent.getTitle(item);
	    OAT.Dom.append([content,ball,t]);
	    self.tl.addEvent(ouri,start,end,content,"#ddd");
	}

	self.tl.draw();
	self.tl.slider.slideTo(0,1);

	if (!uris.length) {
	    var note = new OAT.Notify();
	    var msg = "Current data set contains nothing that could be displayed on the timeline.";
	    note.send(msg, {timeout: 4000});
	}
    }
}

//
// XXX unfinished
//

OAT.RDFTabs.people = function(parent,optObj) {
    var self = this;
    OAT.RDFTabs.parent(self);

    this.options = {
	pictSize:150,
	columns: 2,
	width: 800,
        raw_iris: false
    };

    this.personTypes = ["http://xmlns.com/foaf/0.1/Person"];
    this.nameTypes = [];
    this.addressContainers = [];
    this.depictTypes = ["http://xmlns.com/foaf/0.1/depiction"];

    for (var p in optObj) { self.options[p] = optObj[p]; }    

    this.makeAddress = function (s) { var x=1; }

    this.makeCard = function (s) { var x=1; }

    this.redraw = function () {	var x=1; }
}

OAT.RDFTabs.images = function(parent,optObj) {
    var self = this;
    OAT.RDFTabs.parent(self);

    this.options = {
	columns:4,
	thumbSize:150,
	size:600,
	description:"This module displays all images found in filtered data set.",
	desc:"Images from filtered data set",
        raw_iris: false
    }

    for (var p in optObj) { self.options[p] = optObj[p]; }

    this.elm.style.textAlign = "center";
    this.parent = parent;
    this.initialized = false;
    this.cache = {};
    this.images = [];
    this.container = false;
    this.description = self.options.description;
    this.desc = self.options.desc;
    this.dimmer = false;
    this.imageProperties = OAT.IRIDB.insertIRIArr (["http://xmlns.com/foaf/0.1/depiction"]);

    this.showBig = function(index) {
	if (!self.dimmer) {
	    self.dimmer = OAT.Dom.create("div",
					 {position:"absolute",
					  padding:"1em",
					  backgroundColor:"#fff",
					  border:"4px solid #000",
					  textAlign:"center",
					  fontSize:"160%"});
	    OAT.Dimmer.show(self.dimmer);
	    self.container = OAT.Dom.create("div",{margin:"auto"});
	    self.prev = OAT.Dom.create("span",{fontWeight:"bold",cursor:"pointer"});
	    self.next = OAT.Dom.create("span",{fontWeight:"bold",cursor:"pointer"});
	    var middle = OAT.Dom.create("span");
	    middle.innerHTML = "&nbsp;&nbsp;&nbsp;";
	    self.prev.innerHTML = "&lt;&lt;&lt; ";
	    self.next.innerHTML = " &gt;&gt;&gt;";
	    self.close = OAT.Dom.create ("div", { position:"absolute",
						  top:"0px",right:"0px",
						  backgroundColor:"#fff",
						  padding:"3px",
						  fontWeight:"bold"});
	    self.close.innerHTML = "X";
	    OAT.Dom.append([self.dimmer,self.close,self.container,self.prev,middle,self.next]);

	    var closeRef = function() {
		OAT.Dimmer.hide();
		self.dimmer = false;
	    }
	    OAT.Event.attach(self.close,"click",closeRef);
	    OAT.Event.attach(self.prev,"click",function(){ self.showBig(self.index-1); });
	    OAT.Event.attach(self.next,"click",function(){ self.showBig(self.index+1); });
	}
	self.index = index;
	var img = OAT.Dom.create("img",{border:"2px solid #000"});
	OAT.Dom.clear(self.container);
	OAT.Event.attach(img,"load",function() {
	    var port = OAT.Dom.getViewport();
	    var dim = Math.max(img.width,img.height);
	    var limit = Math.min(self.options.size,port[0]-20,port[1]-20);
	    if (dim > limit) {
		var coef = limit/dim;
		var neww = img.width * coef;
		var newh = img.height * coef;
		img.width = neww;
		img.height = newh;
	    }

	    var plus = OAT.Dom.create("strong",{cursor:"pointer",marginRight:"3px"});
	    var minus = OAT.Dom.create("strong",{cursor:"pointer"});
	    plus.innerHTML = "+";
	    minus.innerHTML = "&mdash;";
	    var d = OAT.Dom.create("div",{textAlign:"left"});
	    OAT.Dom.append([self.container,d],[d,plus,minus]);

	    var resizeRef = function(coef) {
		var w = img.width;
		var h = img.height;
		w = Math.round(w*coef);
		h = Math.round(h*coef);
		img.width = w;
		img.height = h;
		OAT.Dom.center(self.dimmer,1,1);
	    }

	    OAT.Event.attach(plus,"click",function(){
		resizeRef(1.5);
	    });


	    OAT.Event.attach(minus,"click",function(){
		resizeRef(0.667);
	    });

	    self.container.appendChild(img);
	    OAT.Dom.center(self.dimmer,1,1);
	});
	img.src = self.images[index][0];
	img.title = self.parent.getTitle(item);
	self.fixNav();
    }

    this.fixNav = function() { /* visibility of navigation */
	self.prev.style.display = (self.index ? "inline" : "none");
	self.next.style.display = (self.index+1 < self.images.length ? "inline" : "none");
    }

    this.drawThumb = function(index,td) {
	var size = self.options.thumbSize;
	var uri = self.images[index][0];
	var item = self.images[index][1];
	var img = OAT.Dom.create("img",{className:"rdf_image"})
	td.appendChild(img);
	OAT.Event.attach(img,"load",function() {
	    var max = Math.max(img.width,img.height);
	    if (max <= size) { return; }
	    var coef = size / max;
	    var neww = img.width * coef;
	    var newh = img.height * coef;
	    img.width = neww;
	    img.height = newh;
	});
	img.src = uri;
	img.title = self.parent.getTitle(item);
	img.alt = self.parent.getTitle(item);
	OAT.Event.attach(img,"click",function() { self.showBig(index); });
    }

    this.addUriItem = function(uri,item) {
	if (uri in self.cache) { return; }
	self.cache[uri] = true;
	self.images.push([uri,item]);
    }

    this.getImages = function() {
	self.images = [];
	var data = self.parent.data.structured;
	for (var i=0;i<data.length;i++) {
	    var item = data[i];
	    var preds = item.preds;
	    /* if our uri looks like an image */
	    var cur_iri = OAT.IRIDB.getIRI(item.uri);

	    if (self.parent.getContentType(cur_iri) == 3)
		self.addUriItem(cur_iri,item);

	    for (var p in preds) {
		var pred = preds[p];

		/* treat certain predicate values as images automatically */
		if (self.imageProperties.indexOf(parseInt(p)) != -1) {
		    for (var j=0;j<pred.length;j++) {
			if (pred[j].isIRI()) 
			    self.addUriItem(pred[j].getIRI(),item);
		    }
		} else {
		    /* look for predicates that are/contain image links */
		    for (var j=0;j<pred.length;j++) {
			if (pred[j].constructor != OAT.RDFAtom ||
			    pred[j].getTag() != OAT.RDFTag.IRI) { continue; }
			var value = pred[j].getIRI();
			if (self.parent.getContentType(value) == 3) {
			    self.addUriItem(value,item);
			} else {
			    var all = value.match(/http:[^ ]+\.(jpe?g|png|gif)\?.*/gi);
			    if (all) for (var k=0;k<all.length;k++) { 
				self.addUriItem(OAT.IRIDB.getIRI(all[k]),item); 
			    } /* for all embedded images */
			} /* if not image */
		    } /* for all values */
		}
	    } /* for all predicates */
	} /* for all graphs */
    }

    this.redraw = function() {
	var cnt = self.options.columns;
	self.cache = {};
	OAT.Dom.clear(self.elm);
	self.getImages();
	var imgs = self.images;
	var table = OAT.Dom.create("table",{margin:"auto"});
	var tbody = OAT.Dom.create("tbody");
	var tr = OAT.Dom.create("tr");
	OAT.Dom.append([self.elm,table],[table,tbody],[tbody,tr]);
	for (var i=0;i<imgs.length;i++) {
	    var td = OAT.Dom.create("td",{textAlign:"center"});
	    tr.appendChild(td);
	    if (i % cnt == cnt-1) {
		tr = OAT.Dom.create("tr");
		tbody.appendChild(tr);
	    }
	    self.drawThumb(i,td);
	}
    } /* redraw */
}

OAT.RDFTabs.tagcloud = function(parent,optObj) {
    var self = this;
    OAT.RDFTabs.parent(self);

    this.options = {
	description:"This module displays all links found in filtered data set.",
	desc:"Links from filtered data set",
        raw_iris: false
    }
    for (var p in optObj) { self.options[p] = optObj[p]; }

    this.parent = parent;
    this.initialized = false;
    this.description = self.options.description;
    this.desc = self.options.desc;
    this.clouds = [];

    this.addTag = function(item,cloud) {
	var preds = item.preds;
	var title = self.parent.getTitle(item);
	var freq = 1;
	var freqP = OAT.IRIDB.insertIRI ('http://scot-project.org/scot/ns#ownAFrequency');

	for (var p in preds) {
	    if (p == freqP)
		freq = preds[p][0];
		break;
	    }

	cloud.addItem(title,item.uri,freq);
    }

    this.addCloud = function(item) {
	var preds = item.preds;
	var title = self.parent.getTitle(item);

	var div = OAT.Dom.create("div");
	var cdiv = OAT.Dom.create("div",{},"rdf_tagcloud");
	var tdiv = OAT.Dom.create("div",{},"rdf_tagcloud_title");

	var a = OAT.Dom.create("a");
	a.href = item.uri;
	a.innerHTML = title;

	OAT.Dom.append([self.elm,div],[div,tdiv,cdiv],[tdiv,a]);

	var cloud = new OAT.TagCloud(cdiv);
	var tagP = OAT.IRIDB.insertIRI ('http://scot-project.org/scot/ns#hasTag');
	for (var p in preds) {
	    if (p == tagP) {
		var tags = preds[p];
		for (var i=0;i<tags.length;i++) {
		    var tag = tags[i];
		    self.addTag(tag,cloud);
		}
	    }
	}

	this.clouds.push(cloud);
    }

    this.redraw = function() {
	var data = self.parent.data.structured;
	var tcP = OAT.IRIDB.insertIRI ('http://scot-project.org/scot/ns#Tagcloud');
	this.clouds = [];

	OAT.Dom.clear(self.elm);

	for (var i=0;i<data.length;i++) {
	    var item = data[i];
	    if (item.type == tcP) {
		self.addCloud(item);
	    }
	} /* for all graphs */

	for (var i=0; i<this.clouds.length;i++) {
	    var cloud = this.clouds[i];
	    cloud.draw();
	}

	var all = [];
	var links = self.elm.getElementsByTagName("a");
	for (var i=0;i<links.length;i++) { all.push(links[i]); }
	for (var i=0;i<all.length;i++) {
	    var link = all[i];
	    self.parent.processLink(link,link.href);
	}
    } /* redraw */
}

OAT.RDFTabs.fresnel = function(parent, optObj) {
    var self = this;
    OAT.RDFTabs.parent(self);

    this.options = {
	defaultURL:"",
	autoload:false,
	description:"This module applies Fresnel RDF Vocabularies to all dereferenced data.",
	desc:"Fresnel RDF Vocabularies to dereferenced data",
        raw_iris: false
    }
    for (var p in optObj) { self.options[p] = optObj[p]; }

    this.parent = parent;
    this.initialized = false;
    this.inputElm = OAT.Dom.create("div");
    this.mainElm = OAT.Dom.create("div",{className:"rdf_fresnel"});
    this.elm.className = "rdf_fresnel";
    this.description = self.options.description;
    this.desc = self.options.desc;
    OAT.Dom.append([self.elm,self.inputElm,self.mainElm]);
    self.fresnel = new OAT.Fresnel();

    this.redraw = function() {
	var results = self.fresnel.format(self.parent.data.all);
	/* append stylesheets */
	var ss = results[1];
	for (var i=0;i<ss.length;i++) {
	    var s = ss[i];
	    var elm = OAT.Dom.create("link");
	    elm.rel = "stylesheet";
	    elm.type = "text/css";
	    elm.href = s;
	    document.getElementsByTagName("head")[0].appendChild(elm);
	}
	/* go */
	var cb = function(xslDoc) {
	    var xmlDoc = results[0];
	    var out = OAT.Xml.transformXSLT(xmlDoc,xslDoc);
	    OAT.Dom.clear(self.mainElm);
	    self.mainElm.innerHTML = OAT.Xml.unescape(OAT.Xml.serializeXmlDoc(out));
	    var foaf = "http://xmlns.com/foaf/0.1/";

	    var find = function(str) {
		var triples = self.parent.data.triples;
		for (var i=0;i<triples.length;i++) {
		    var t = triples[i];
		    if ((t[1] != foaf+"name") && (t[1] != foaf+"knows")) { continue; }
		    if (t[2] == str) { return t; }
		}
		return false;
	    }

	    var isBnode = function(str) {
		return (str.match(/^_:/));
	    }

	    /* get all relevant elements from fresnel processed page */
	    var all = [];
	    var spans = self.mainElm.getElementsByTagName("span");

	    for (var i=0;i<spans.length;i++) { all.push(spans[i]); }

	    for (var i=0;i<all.length;i++) {
		var node = all[i];
		var str = decodeURIComponent(node.innerHTML);
		var triple = find(str);
		if (!triple) { continue; }

		/* create link */
		var a = OAT.Dom.create("a");
		a.innerHTML = self.parent.simplify(str);
		OAT.Dom.clear(node);
		node.appendChild(a);

		/* href is a literal */
		if (triple[1] == foaf+"name" && !isBnode(triple[0])) {
		    a.href = triple[0];
		    self.parent.processLink(a,triple[0]);
		} else if (triple[1] == foaf+"knows" && !isBnode(triple[2])) {
		    a.href = triple[2];
		    self.parent.processLink(a,triple[2]);
		}
	    }
	}
	OAT.AJAX.GET(OAT.Preferences.xsltPath+"fresnel2html.xsl",false,cb,{type:OAT.AJAX.TYPE_XML});
    } /* redraw */

    if (self.options.autoload && self.options.defaultURL.length) {
	self.fresnel.addURL(self.options.defaultURL,self.redraw);
    } else {
	var inp = OAT.Dom.create("input");
	inp.size = "60";
	inp.value = self.options.defaultURL;
	var btn = OAT.Dom.create("input", {type:"button",value:"Load Fresnel"});
	var go = function() {
	    if ($v(inp))
		self.fresnel.addURL($v(inp),self.redraw);

	}
	OAT.Event.attach(btn,"click",go);
	OAT.Event.attach(inp,"keypress",function(event) {
	    if (event.keyCode == 13) { go(); }
	});
	OAT.Dom.append([self.inputElm,OAT.Dom.text("Fresnel URI: "),inp,btn]);
    }
}
