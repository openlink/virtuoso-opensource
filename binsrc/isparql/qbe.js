/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2009-2015 OpenLink Software
 *
 *  See LICENSE file for details.
 *
 */

function init_qbe() {
    OAT.SVGSparqlGroup.prototype.MySetType = function(type) {
	if (type == OAT.SVGSparqlData.GROUP_OPTIONAL) {
	    this.setFill('#E5E5E5');
	    this.MySetLabel(1,'OPTIONAL');
	    this.label.setAttribute("fill",'#797979');
	} else if (type == OAT.SVGSparqlData.GROUP_UNION) {
	    this.setFill('#DEDEEF');
	    this.MySetLabel(1,'UNION');
	    this.label.setAttribute("fill",'#6767B4');
	} else if (type == OAT.SVGSparqlData.GROUP_CONSTRUCT) {
	    for (var i = 0;i < this.svgsparql.groups.length;i++)
		if (this.svgsparql.groups[i] != this && this.svgsparql.groups[i].getType() == OAT.SVGSparqlData.GROUP_CONSTRUCT) {
		    alert('More than one CONSTRUCT statement is not supported!');
		    return false;
		}
	    this.setFill('#FFE3D7');
	    this.MySetLabel(1,'CONSTRUCT');
	    this.label.setAttribute("fill",'#D23F00');
	} else {
	    this.label.setAttribute("fill",'#000000');
	}
	this.setType(type);
	return true;
    }

    OAT.SVGSparqlEdge.prototype.setValueByDrop = function(val,t,x,y) {
	if (t == 'class') {
	    return false;
	} else {
	    this.MySetLabel(1,val);
	    this.svgsparql.deselectEdges();
	    this.svgsparql.deselectNodes();
	    this.svgsparql.deselectGroups();
	    this.svgsparql.selectEdge(this);
	    return true;
	}
    }

    OAT.SVGSparqlNode.prototype.setValueByDrop = function(val,t,x,y) {
	if (t != 'class') {
	    this.svgsparql.startDrawing(this,x,y,val);
	    return true;
	} else if (this.getType() == 1) { /* literal */
	    this.MySetLabel(2,val);
	    this.svgsparql.deselectEdges();
	    this.svgsparql.deselectNodes();
	    this.svgsparql.deselectGroups();
	    this.svgsparql.selectNode(this);
	    return true;
	} else { /* resource */
	    var goodNode = false;
	    for (var i=0;i<this.edges.length;i++) { /* try to find existing rdf:type node */
		var e = this.edges[i];
		var l = e.getLabel(1);
		if (e.node1 == this && (l == "rdf:type" || l == "a" || l == "type")) { goodNode = e.node2; }
		if (e.node2 == this && (l == "rdf:type" || l == "a" || l == "type")) { goodNode = this; }
	    }
	    if (!goodNode) {
		/* create a new rdf:type triple */
		this.svgsparql.selectNode(this);
		var dims = OAT.Dom.getWH("qbe_parent");
		var tol = 20;
		do {
		    var a = Math.random()*Math.PI*2;
		    var xx = x + 120 * Math.cos(a);
		    var yy = y + 120 * Math.sin(a);
		} while (xx < tol || yy < tol || xx > dims[0]-tol || yy > dims[1]-tol);
		goodNode = this.svgsparql.addNode(xx,yy,"",0);
		var e = this.svgsparql.addEdge(this,goodNode,"",0);
		e.MySetLabel(1,"rdf:type");
		e.setVisible(false);
	    } else {
		this.svgsparql.selectNode(goodNode);
	    }
	    goodNode.MySetLabel(1,val);
	    this.svgsparql.deselectEdges();
	    this.svgsparql.deselectNodes();
	    this.svgsparql.deselectGroups();
	}
    }

    OAT.SVGSparqlNode.prototype.MySetLabel = function(which,newLabel) {
	if (which == 1) {
	    var old = this.getLabel(1);
	    var count = 0;
	    for (var i=0;i<this.svgsparql.nodes.length;i++) {
		var l2 = this.svgsparql.nodes[i].getLabel(1);
		if (l2 == old) { count++; }
	    }
	    if (count == 1) { this.svgsparql.qbe.Schemas.DeleteNode(old); }
	    this.svgsparql.qbe.Schemas.InsertNode(this.svgsparql.qbe.Schemas.Bound,newLabel,"class",false,false);
	}
	this.setLabel(which,newLabel);
	if (which == 1 && this.orderby_cell) { this.orderby_cell.value.innerHTML = newLabel; }
    }

    OAT.SVGSparqlEdge.prototype.MySetLabel = function(which,newLabel) {
	if (which == 1) {
	    var old = this.getLabel(1);
	    var count = 0;
	    for (var i=0;i<this.svgsparql.edges.length;i++) {
		var l2 = this.svgsparql.edges[i].getLabel(1);
		if (l2 == old) { count++; }
	    }
	    if (count == 1) { this.svgsparql.qbe.Schemas.DeleteNode(old); }
	    this.svgsparql.qbe.Schemas.InsertNode(this.svgsparql.qbe.Schemas.Bound,newLabel,"property_attr",false,false);
	}
	this.setLabel(which,newLabel);
	if (which == 1 && this.orderby_cell) { this.orderby_cell.value.innerHTML = newLabel; }
    }

    OAT.SVGSparqlGroup.prototype.MySetLabel = function(which,newLabel) {
	this.setLabel(newLabel);
	if (which == 1 && this.orderby_cell) { this.orderby_cell.value.innerHTML = newLabel; }
    }
}

iSPARQL.GroupColorSeq = function() {
    var self = this;
    this.seq = ['#ff0','#f0f','#0ff','#0f0'];
    this.inx = -1;
    this.getNext = function() {
	self.inx++;
	if (self.inx == self.seq.length) { self.inx = 0; }
	return self.seq[self.inx];
    }
    this.reset = function() {
	self.inx = -1;
    }
};

iSPARQL.QBE = function (def_obj) {
    var self = this;

    this.defaults = def_obj;

    this.l = new OAT.Layers(100);
    this.group_color_seq = new iSPARQL.GroupColorSeq();

    this.clear = function() {
	if (self.svgsparql) {
	    self.svgsparql.clear();
	    self.svgsparql.ghostdrag.addTarget(self.props_win.dom.content);
	}
	for (var i = self.orderby_grid.header.cells.length;i > 1; i--) {
	    self.orderby_grid.header.removeColumn(i - 1);
	}
	self.resetPrefixes();
	var root=self.Schemas.Bound;
	for (var i=root.children.length-1;i>=0;i--) {
	    var ch = root.children[i];
	    root.deleteChild(ch);
	}
	$('qbe_distinct').checked = false;
	$('qbe_query_type').selectedIndex = 0;

	self.group_color_seq.reset();

	var table = $('qbe_dataset_list');
	if (table.tBodies.length) { OAT.Dom.unlink(table.tBodies[0]); }
	$('qbe_datasource_cnt').innerHTML=0;
    }

    /* create SVGSparql object */
    var options = {
	nodeOptions:{
	    size:15,
	    fill:"#f00"
	},
	selectNodeCallback:function(node) {
	    node.svg.setAttribute("stroke-width","4");
	    node.svg.setAttribute("stroke","#00f");
	    OAT.Dom.hide("qbe_props_help");
	    OAT.Dom.hide("qbe_props_edge");
	    OAT.Dom.hide("qbe_props_group");
	    OAT.Dom.show("qbe_props_node");
	    OAT.Dom.show("qbe_props_common");
	    self.props_win.dom.caption.innerHTML = 'Node';


	    var t = node.getLabel(2);
	    if (t == '--type--') t = '';

	    $("qbe_node_type").selectedIndex = node.getType();
	    $("qbe_node_id").value = node.getLabel(1);
	    $("qbe_node_res_type").value = t;
	    $("qbe_visible").disabled = false;
	    $("qbe_visible").checked = node.getVisible();
	    $("qbe_orderby").disabled = false;
	    if (node.orderby_cell)
		$("qbe_orderby").checked = true;
	    else
		$("qbe_orderby").checked = false;
	},
	deselectNodeCallback:function(node) {
	    node.svg.setAttribute("stroke-width","0.001"); /* cannot be zero due to bug in firefox */
	    OAT.Dom.hide("qbe_props_common");
	    OAT.Dom.hide("qbe_props_node");
	    OAT.Dom.show("qbe_props_help");
	    self.props_win.dom.caption.innerHTML = 'Inspector';
	},
	selectEdgeCallback:function(edge) {
	    edge.svg.setAttribute("stroke","#f00");
	    OAT.Dom.hide("qbe_props_help");
	    OAT.Dom.hide("qbe_props_node");
	    OAT.Dom.hide("qbe_props_group");
	    OAT.Dom.show("qbe_props_edge");
	    OAT.Dom.show("qbe_props_common");
	    self.props_win.dom.caption.innerHTML = 'Connector';

	    var val = edge.getLabel(1);
	    if (val == '?') val = '';
	    $("qbe_edge_value").value = val;
	    $("qbe_edge_type").checked = edge.getType();
	    $("qbe_visible").disabled = false;
	    $("qbe_visible").checked = edge.getVisible();
	    $("qbe_orderby").disabled = false;
	    if (edge.orderby_cell)
		$("qbe_orderby").checked = true;
	    else
		$("qbe_orderby").checked = false;
	},
	deselectEdgeCallback:function(edge) {
	    edge.svg.setAttribute("stroke","#888"); /* cannot be zero due to bug in firefox */
	    OAT.Dom.hide("qbe_props_common");
	    OAT.Dom.hide("qbe_props_edge");
	    OAT.Dom.show("qbe_props_help");
	    self.props_win.dom.caption.innerHTML = 'Inspector';
	},
	selectGroupCallback:function(group) {
	    group.svg.setAttribute("stroke-width","2");
	    group.svg.setAttribute("stroke","#f00");
	    OAT.Dom.hide("qbe_props_help");
	    OAT.Dom.hide("qbe_props_node");
	    OAT.Dom.hide("qbe_props_edge");
	    OAT.Dom.show("qbe_props_group");
	    OAT.Dom.show("qbe_props_common");
	    self.props_win.dom.caption.innerHTML = 'Group';

	    var val = group.getLabel(1);
	    if (val == '?') val = '';

	    if (group.getType() == OAT.SVGSparqlData.GROUP_GRAPH)
		{
		    $("qbe_visible").disabled = false;
		    $("qbe_orderby").disabled = false;
		    $("qbe_group_id").disabled = false;
		    $("qbe_group_type").selectedIndex = 0;
		} else {
		$("qbe_visible").disabled = true;
		$("qbe_orderby").disabled = true;
		$("qbe_group_id").disabled = true;
		$("qbe_group_type").selectedIndex = group.getType();
	    }

	    $("qbe_group_id").value = group.getLabel(1);
	    $("qbe_visible").checked = group.getVisible();
	    if (group.orderby_cell)
		$("qbe_orderby").checked = true;
	    else
		$("qbe_orderby").checked = false;
	},
	deselectGroupCallback:function(group) {
	    group.svg.setAttribute("stroke-width","0.001");
	    OAT.Dom.hide("qbe_props_common");
	    OAT.Dom.hide("qbe_props_group");
	    self.props_win.dom.caption.innerHTML = '&nbsp;';
	},
	addNodeCallback:function(node,loadMode) {
	    if (loadMode) { return; }
	    node.setType(OAT.SVGSparqlData.NODE_CIRCLE);
	    node.MySetLabel(1,'?');
	    // node.MySetLabel(2,'--type--'); /* no type for resources! this works only for literals! */
	    self.svgsparql.deselectEdges();
	    self.svgsparql.deselectNodes();
	    self.svgsparql.deselectGroups();
	    self.svgsparql.selectNode(node);
	},
	addEdgeCallback:function(edge,loadMode) {
	    //edge.setVisible(true);
	    if (loadMode) { return; }
	    edge.MySetLabel(1,'?');
	    self.svgsparql.deselectNodes();
	    self.svgsparql.deselectEdges();
	    self.svgsparql.deselectGroups();
	    self.svgsparql.selectEdge(edge);
	},
	addGroupCallback:function(group,loadMode) {
	    group.setVisible(true);
	    group.setFill(self.group_color_seq.getNext());
	    if (loadMode) { return; }
	    group.MySetLabel(1,'?');
	    self.svgsparql.deselectEdges();
	    self.svgsparql.deselectGroups();
	    self.svgsparql.selectGroup(group);
	},
	removeNodeCallback:function(node) {
	    var type = node.getType();
	    if (type == OAT.SVGSparqlData.NODE_CIRCLE) {
		var count = 0;
		var label = node.getLabel(1);
		for (var i=0;i<self.svgsparql.nodes.length;i++) {
		    var l2 = self.svgsparql.nodes[i].getLabel(1);
		    if (l2 == label) { count++; }
		}
		if (count == 1) { self.Schemas.DeleteNode(label); }
	    }
	    self.removeOrderBy(node);
	},
	removeEdgeCallback:function(edge){
	    var count = 0;
	    var label = edge.getLabel(1);
	    for (var i=0;i<self.svgsparql.edges.length;i++) {
		var l2 = self.svgsparql.edges[i].getLabel(1);
		if (l2 == label) { count++; }
	    }
	    if (count == 1) { self.Schemas.DeleteNode(label); }
	    self.removeOrderBy(edge);
	},
	removeGroupCallback:function(group){
	    self.removeOrderBy(group);
	}
    };
    if (!OAT.Browser.isIE && !OAT.Browser.hasNoSVG) { 
	this.svgsparql = new OAT.SVGSparql("qbe_parent",options);
	this.svgsparql.qbe = this;
    }
    var restrictionFunction = function(new_width,new_height)  { return new_width < 600; }

    OAT.Resize.create("qbe_resizer_area", "qbe_bottom", OAT.Resize.TYPE_X,restrictionFunction);
    OAT.Resize.create("qbe_resizer_area", "qbe_canvas", OAT.Resize.TYPE_XY,restrictionFunction);
    OAT.Resize.create("qbe_resizer_area", "qbe_parent", OAT.Resize.TYPE_XY,restrictionFunction);
    $("qbe_resizer_area").style.backgroundImage = 'url("'+OAT.Preferences.imagePath+"resize.gif"+'")';

    var win_width = 260;
    var win_x = -20;

    this.schema_win = new OAT.Win({title:"Schemas", 
				   buttons: "cr",
				   outerWidth:win_width, 
				   outerHeight:300, 
				   x:win_x,
				   y:250,
				   className:"schema_win"});
//    this.schema_win.move._Drag_movers[0][1].restrictionFunction = function(l,t) {
//	return l < 0 || t < 0;
//    }

    $("page_qbe").appendChild(this.schema_win.dom.container);
    self.l.addLayer(this.schema_win.dom.container);
    this.schema_win.dom.content.appendChild($("schemas"));
    this.schema_win.open();

    this.props_win = new OAT.Win({title:"",
				  buttons: "cr",
				  outerWidth:win_width, 
				  outerHeight:120, 
				  x:win_x, 
				  y:82, 
				  className: "inspector_win"});

//    this.props_win.move._Drag_movers[0][1].restrictionFunction = function(l,t) {
//	return l < 0 || t < 0;
//    }

    $("page_qbe").appendChild(this.props_win.dom.container);

    self.l.addLayer(this.props_win.dom.container);
    this.props_win.dom.content.appendChild($("qbe_props"));
    this.props_win.dom.caption.innerHTML = 'Inspector';
    this.props_win.open();

    this.orderby_grid = new OAT.Grid("qbe_orderby_grid",0)
    self.orderby_grid.createHeader([{value:'order by',sortable:0,draggable:0,resizable:0}]);

    this.addOrderBy = function(obj,addmode) {
	var index = self.orderby_grid.header.cells.length;
	if (obj.node2 && obj.node2.orderby_cell && !addmode) { index = obj.node2.orderby_cell.number; }
	if (!obj.orderby_cell) {
	    var label = obj.getLabel(1).trim();
	    var orderby_cell = self.orderby_grid.appendHeader({value:label,sortable:1,draggable:1,resizable:0},index);
	    obj.orderby_cell = orderby_cell;
	}
    }
    this.removeOrderBy = function(obj) {
	if (obj.orderby_cell) {
	    self.orderby_grid.header.removeColumn(obj.orderby_cell.number);
	    obj.orderby_cell = false;
	}
    }

    this.var_cnt = 1;

    this.save = function() {
	var data = self.getSaveData();
	iSPARQL.IO.save(data);
    }

    /* return data for saving */
    this.getSaveData = function() {
	var dataObj = {
	    query:"",
	    maxrows:0,
	    endpointOpts: {},
	    canvas:false,
	    defaultGraph:false,
	    prefixes:[],
	    metaDataOpts:{},
	    namedGraphs:[]
	};

	dataObj.query = self.QueryGenerate();
	dataObj.endpointOpts.endpointPath = iSPARQL.endpointOpts.endpointPath;
	dataObj.endpointOpts.useProxy = iSPARQL.endpointOpts.useProxy;
	dataObj.endpointOpts.pragmas = iSPARQL.endpointOpts.pragmas;
	dataObj.canvas = self.svgsparql.toXML();
	dataObj.defaultGraph = $v('qbe_graph');
	dataObj.metaDataOpts = iSPARQL.mdOpts.getMetaDataObj();
	dataObj.maxrows = iSPARQL.dataObj.maxrows;

	if(qe.cacheIndex == -1) {
	    var cache = qe.cache[qe.cacheIndex];
	    dataObj.data = (cache)? cache.data : false;
	}

	for (var i=0;i < self.Schemas.Imported.length;i++) {
	    dataObj.prefixes.push(self.Schemas.Imported[i]);
	}

	return dataObj;
    }

    this.prefixes = [];

    this.resetPrefixes = function(){
	self.prefixes = [];
	for (var i=0;i<window.defaultPrefixes.length;i++) {
	    self.prefixes.push(window.defaultPrefixes[i]);
	}
    }
    self.resetPrefixes();

    this.putPrefix = function(str) { /* replace first part of URI with prefix, if applicable */
	var tmp = '';
	if ((tmp = str.match(/^<(.*)>$/))) { /* if is an <URI> */
	    var uri = tmp[1];
	    for (var i = 0;i < self.prefixes.length; i++) {
		var prefix = self.prefixes[i];
		if (uri.substring(0,prefix.uri.length) == prefix.uri &&  /* if prefix.uri is left substring of uri */
		    !uri.substring(prefix.uri.length,uri.length).match(/\//)) { /* remaining part doesn't contain slash */
		    return prefix.label + ':' + uri.substring(prefix.uri.length); /* prefix:remainder */
		}
	    }
	}
	return str;
    }

    this.getPrefixParts = function(str) { /* return firstpart, secondpart, prefix (if found) */
	var s = str;
	if (!s) { return; }
	if (s.charAt(0) == "<") { s = s.substring(1,s.length-1); }
	var first = "";
	var second = "";
	var pf = false;

	for (var i=0;i<self.prefixes.length;i++) {
	    var prefix = self.prefixes[i];
	    if (s.substring(0,prefix.uri.length) == prefix.uri) {
		first = prefix.uri;
		pf = prefix.label+":";
		second = s.substring(prefix.uri.length);
		return [first,second,pf];
	    }
	}
	var i1 = s.lastIndexOf("/");
	var i2 = s.lastIndexOf("#");
	var index = Math.max(i1,i2);
	if (index == -1) { return false; }
	first = s.substring(0,index+1);
	second = s.substring(index+1);
	return [first,second,pf];
    }

    this.expandPrefix = function(str)	{
	var tmp = '';
	if(str.match(/^\?/))
	    return str;
	else if (str == 'a')
	    return '<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>';
	else if((tmp = str.match(/<(.*)>/)))
	    return str;
	else
	    {
		var idx = str.indexOf(':');
		if (idx != -1)
		    {
			var prefix = str.substring(0,idx);
			for(var i = 0;i < self.prefixes.length; i++)
			    {
				if (self.prefixes[i].label == prefix)
				    return '<' + self.prefixes[i].uri + str.substring(idx + 1) + '>';
			    }
		    }
	    }
	return str;
    }

    this.optPrefix = function(str,used_prefixes)   {
	var prefix = '';
	for(var i = 0;i < self.prefixes.length; i++)
	    {
		schema = self.prefixes[i].uri;
		if (schema == str.substring(1,schema.length + 1))
		    {
			if (used_prefixes.find(schema) == -1)
			    {
				used_prefixes.push(self.prefixes[i].label);
				used_prefixes.push(self.prefixes[i].uri);
			    }
			return self.prefixes[i].label + ':' + str.substring(prefix.length + 2,str.length - 1);
		    }
	    }
	return str;
    }

    var t = new OAT.Tree({ext:"png",onClick:"toggle", onDblClick:"toggle", imagePath:"images/"});
    t.assign("schemas_tree",false);
    var root = t.tree;
    var bound = root.createChild('bound',1);
    var unbound = root.createChild('unbound',1);
    bound.collapse();
    unbound.collapse();
    var ref_img = OAT.Dom.create('img',{width:'16px',height: '16px', verticalAlign: 'middle', marginLeft: '3px', cursor: 'pointer'});
    ref_img.src = 'images/reload.png';
    unbound._gdElm.appendChild(ref_img);
    OAT.Event.attach(ref_img,"click",function(){
			 self.Schemas.Unbound.expand();
			 self.Schemas.Refresh()
			     });
    OAT.Event.attach("schema_import","click",function() {
		       self.Schemas.Import($v('schema').trim());
		   });
    OAT.Event.attach("schema_remove","click",function() {
		       self.Schemas.Remove($v('schema').trim());
		   });

    self.Schemas = {
	Tree:t,
	Bound:bound,
	Unbound:unbound,
	Imported:[],
	Import:function(schema, silent) {
	    self.Schemas.Unbound.expand(true);
	    if (self.Schemas.Imported.find(schema) != -1)	{
		// if (!silent) { alert('Schema "' + schema + '" already imported!'); }
		// return;
	    } else { self.Schemas.Imported.push(schema); }
	    self.Schemas.Add(schema);
	},
	Add:function(schema) {
	    var parts = self.getPrefixParts(schema);
	    if (!parts) {
		alert("Malformed schema!");
		return;
	    }
	    var label = parts[2] || parts[0];
	    var node = self.Schemas.MergeSchema(self.Schemas.Unbound,parts[0],schema,label);
	    node.expand();
	},
	MergeSchema:function(parent,schema,graphSchema,label,bound) { /* insert a new prefix into schemas */
	    for (var i=0;i<parent.children.length;i++) {
		if (parent.children[i].schema == schema) { return parent.children[i]; } /* we already have this */
	    }
	    var node = parent.createChild(label,1);
	    node.setImage('rdf-icon-16');
	    node.collapse();
	    /* custom properties */
	    node.schema = schema;
	    node.graphSchema = graphSchema;
	    node.uritype = (parent == self.Schemas.Unbound ? 'schema' : false);
	    node.bound = bound;
	    return node;
	},
	Reset:function() {
	    var p = self.Schemas.Unbound;
	    for (var i=p.children.length-1;i>=0;i--) { p.deleteChild(p.children[i]); }
	    var p = self.Schemas.Bound;
	    for (var i=p.children.length-1;i>=0;i--) { p.deleteChild(p.children[i]); }
	    self.Schemas.Imported = [];
	},
	Remove:function(schema) {
	    var p = self.Schemas.Unbound;
	    for (var i=p.children.length-1;i>=0;i--) {
		var child = p.children[i];
		if (child.schema == schema) { p.deleteChild(child); }
	    }
	    var p = self.Schemas.Bound;
	    for (var i=p.children.length-1;i>=0;i--) {
		var child = p.children[i];
		if (child.schema == schema) { p.deleteChild(child); }
	    }
	    var index = self.Schemas.Imported.find(schema);
	    if (index != -1) { self.Schemas.Imported.splice(index,1); }
	},
	NodeDblClick:function() {
	    var node = this.node;
	    if (node.uritype == 'class') {
		for(var i = 0;i < self.svgsparql.selectedNodes.length;i++) {
		    self.svgsparql.selectedNodes[i].MySetLabel(2,self.putPrefix('<' + node.uri + '>'));
		}
	    } else {
		for(var i = 0;i < self.svgsparql.selectedEdges.length;i++) {
		    self.svgsparql.selectedEdges[i].MySetLabel(1,self.putPrefix('<' + node.uri + '>'));
		}
	    }
	},
	NodeDragProcess:function(elm) {
	    elm.firstChild.style.color = "#f00";
	    elm.firstChild.style.listStyleType = "none";
	},
	NodeDragDrop:function(target,x_,y_) {
	    /* insert into "Bound" tree */
	    var treeNode = this.originalElement.node;
	    self.Schemas.InsertNode(self.Schemas.Bound,treeNode.uri,treeNode.uritype,treeNode.label,treeNode.comment);

	    var val = self.putPrefix('<' + treeNode.uri + '>');
	    if (target == self.svgsparql) {
		if (treeNode.uritype == 'class') {
		    var pos = OAT.Dom.position(target.parent);
		    var x = x_ - pos[0];
		    var y = y_ - pos[1];
		    var node = target.addNode(x,y,"",0);
		    node.setValueByDrop(val,treeNode.uritype,x,y);
		}
	    } else if (target.svgsparql) {
		var pos = OAT.Dom.position(target.svgsparql.parent);
		var x = x_ - pos[0];
		var y = y_ - pos[1];
		target.setValueByDrop(val,treeNode.uritype,x,y);
	    } else if (target == self.props_win.dom.content) {
		if (self.svgsparql.selectedNode)
		    self.svgsparql.selectedNode.setValueByDrop(val,treeNode.uritype);
		else if (self.svgsparql.selectedEdge)
		    self.svgsparql.selectedEdge.setValueByDrop(val,treeNode.uritype);
	    }
	},
	IsAttribute:function(obj) {
	    value = '';
	    if (obj.range) { value = obj.range.value; }
	    switch (value) {
		case "http://www.w3.org/2000/01/rdf-schema#Literal":
		case "http://atomowl.org/ontologies/atomrdf#Text":
		case "http://www.w3.org/1999/02/22-rdf-syntax-ns#value":
		case "http://atomowl.org/ontologies/atomrdf#Link":
		case "":
		return true;
		break;
	    }
	    return false;
	},
	InsertNode:function(parent,uri_,type,label,comment) {
	    /* first, test for a good parent */
	    var uri = self.expandPrefix(uri_);
	    if (uri.charAt(0) == "<") {	uri = uri.substring(1,uri.length-1); }

	    var parts = self.getPrefixParts(uri);
	    if (!parts) { return; }
	    var schemaLabel = parts[2] || parts[0];
	    var schemaNode = self.Schemas.MergeSchema(parent,parts[0],parts[0],schemaLabel,false);

	    var nodeLabel = label || parts[1];

	    /* search for Classes / Properties node */
	    var labels = {};
	    for (var i=0;i<schemaNode.children.length;i++) {
		var child = schemaNode.children[i];
		labels[child._label.innerHTML] = child;
	    }

	    var parentNode = false;
	    if (type == 'class') {
		if ("Classes" in labels) {
		    parentNode = labels["Classes"];
		} else {
		    parentNode = schemaNode.createChild('Classes',1);
		    parentNode.collapse();
		}
	    } else {
		if ("Properties" in labels) {
		    parentNode = labels["Properties"];
		} else {
		    parentNode = schemaNode.createChild('Properties',1);
		    parentNode.collapse();
		}
	    }

	    for (var i=0;i<parentNode.children.length;i++) {
		var child = parentNode.children[i];
		if (child.uri == uri) { return; } /* already inserted */
	    }

	    var leaf = parentNode.createChild(nodeLabel,0);

	    if (comment) {
		leaf.li.alt = comment;
		leaf.li.title = comment;
	    }

	    leaf.uri = uri;
	    leaf.uritype = type;
	    leaf.bound = schemaNode.bound;
	    leaf.label = label;
	    leaf.comment = comment;
	    leaf._gdElm.node = leaf;

	    self.svgsparql.ghostdrag.addSource(leaf._gdElm,self.Schemas.NodeDragProcess,self.Schemas.NodeDragDrop);
	    OAT.Event.attach(leaf._gdElm,"dblclick",self.Schemas.NodeDblClick);

	    if (type == 'class') {
		leaf.setImage('concept-icon-16');
	    } else if (type == 'property_attr') {
		leaf.setImage('attribute-icon-16');
	    } else { leaf.setImage('relation-icon-16'); }
	},
	DeleteNode:function(uri) { /* only from "Bound" subtree */
	    var url = self.expandPrefix(uri);
	    if (url.charAt(0) == "<") {	url = url.substring(1,url.length-1); }
	    var parts = self.getPrefixParts(url);
	    if (!parts) { return; }
	    var root = self.Schemas.Bound;
	    var schemaNode = false;
	    for (var i=0;i<root.children.length;i++) {
		var child = root.children[i];
		if (child.schema == parts[0])  { schemaNode = child; }
	    }
	    if (!schemaNode) { return; }
	    var containerNode = false;
	    var finalNode = false;
	    for (var i=0;i<schemaNode.children.length;i++) {
		var child1 = schemaNode.children[i];
		for (var j=0;j<child1.children.length;j++) {
		    var child2 = child1.children[j];
		    if (child2.uri == url) {
			containerNode = child1;
			finalNode = child2;
		    }
		}
	    }
	    if (!finalNode) { return; }
	    containerNode.deleteChild(finalNode);
	    if (!containerNode.children.length) { schemaNode.deleteChild(containerNode); }
	    if (!schemaNode.children.length) { root.deleteChild(schemaNode); }
	},
	Update:function(node) { /* get Classes and Properties for a prefix */
	    if (node.children.length > 0) { return; } /* nothing when already fetched */
	    var callback = function(data) {
		var JSONData = eval('(' + data + ')');

		var insert = function(obj,type,schemaParts) {
		    var uri = obj.uri.value;
		    var parts = self.getPrefixParts(uri);
		    if (parts[0] != schemaParts[0]) { return; }
		    var label = (obj.label ? obj.label.value : false);
		    var comment = (obj.comment ? obj.comment.value : false);
		    self.Schemas.InsertNode(self.Schemas.Unbound,uri,type,label,comment);
		}

		if (JSONData.results.bindings.length > 0) {
		    var objs = JSONData.results.bindings;
		    var schemaParts = self.getPrefixParts(node.schema);
		    var classes = [];
		    var rels = [];
		    var attrs = [];
		    for (var i=0;i<objs.length;i++) {
			var obj = objs[i];
			switch (obj.type.value) {
			case "http://www.w3.org/2000/01/rdf-schema#Class":
			case "http://www.w3.org/2002/07/owl#Class":
			    classes.push(obj);
			    break;
			case "http://www.w3.org/1999/02/22-rdf-syntax-ns#Property":
			case "http://www.w3.org/2002/07/owl#ObjectProperty":
			case "http://www.w3.org/2002/07/owl#DatatypeProperty":
			case "http://www.w3.org/2002/07/owl#InverseFunctionalProperty":
			    if (self.Schemas.IsAttribute(obj)) { attrs.push(obj); }
			    else { rels.push(obj); }
			    break;
			}
		    } /* for all elements */
		    var lmax = Math.min (classes.length, 200);
		    for (var i=0;i<lmax;i++) {
			var c = classes[i];
			var type = 'class';
			insert(c,type,schemaParts);
		    }

		    var lmax = Math.min (attrs.length, 200);
		    for (var i=0;i<lmax;i++) {
			var a = attrs[i];
			var type = 'property_attr';
			insert(a,type,schemaParts);
		    }

		    var lmax = Math.min (rels.length, 200);
		    for (var i=0;i<lmax;i++) {
			var r = rels[i];
			var type = 'property_rel';
			insert(r,type,schemaParts);
		    }
		} /* if data ok */
	    }
	    var oldIcon = "";
	    var oldFilter = "";
	    var params = {
		endpoint:iSPARQL.endpointOpts.endpointPath,
		query:
		'define get:soft "replacing" \n'+
		'PREFIX owl: <http://www.w3.org/2002/07/owl#> \n' +
		'PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> \n' +
		'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> \n' +
		'\n' +
		'SELECT DISTINCT ?type ?uri ?label ?comment ?range \n' +
		'FROM <' + node.schema + '> \n' +
		'WHERE { \n ' +
		'    		{\n ' +
		'        { ?uri a ?type . FILTER (?type = <http://www.w3.org/1999/02/22-rdf-syntax-ns#Property>) } UNION\n' +
		'        { ?uri a ?type . FILTER (?type = <http://www.w3.org/2002/07/owl#Class>) } UNION\n' +
		'        { ?uri a ?type . FILTER (?type = <http://www.w3.org/2000/01/rdf-schema#Class>) } UNION\n' +
		'        { ?uri a ?type . FILTER (?type = <http://www.w3.org/2002/07/owl#ObjectProperty>) } UNION\n' +
		'        { ?uri a ?type . FILTER (?type = <http://www.w3.org/2002/07/owl#DatatypeProperty>) } UNION\n' +
		'        { ?uri a ?type . FILTER (?type = <http://www.w3.org/2002/07/owl#InverseFunctionalProperty>) } }\n' +
		'         OPTIONAL { ?uri rdfs:label ?label } .' + '\n' +
		'         OPTIONAL { ?uri rdfs:comment ?comment } .' + '\n' +
		'         OPTIONAL { ?uri rdfs:range ?range } .' + '\n' +
		'}' + '\n' +
		'ORDER BY ?uri',
		//default_graph_uri:node.li.uri,
		default_graph_uri:'',
		maxrows:1000,
		should_sponge:((node.bound)?'':'soft'),
		format:'application/sparql-results+json',
		errorHandler:function(xhr) {
		    var status = xhr.getStatus();
		    var response = xhr.getResponseText();
		    var headers = xhr.getAllResponseHeaders();
		    alert(response);
		},
		onstart:function() {
		    oldIcon = node._icon.src;
		    oldFilter = node._icon.style.filter;
		    node._icon.src = OAT.Preferences.imagePath+"Dav_throbber.gif";
		    node._icon.style.filter = "";
		},
		onend:function() {
		    node._icon.src = oldIcon;
		    node._icon.style.filter = oldFilter;
		},
		callback:callback
	    }
	    iSPARQL.QueryExec(params);
	}, /* Schemas.Update */
	Refresh:function(force) { /* get a list of prefixes */
	    if (self.Schemas.Unbound.state == 0 && !force) { return; }
	    var node = self.Schemas.Unbound;
	    var oldIcon = node._icon.src || "";
	    var oldFilter = node._icon.style.filter || "";
	    var callback = function(data) {
		for (var i = node.children.length-1;i >= 0;i--) { /* clear old children */
		    node.deleteChild(node.children[i]);
		}
		var JSONData = eval('(' + data + ')');
		if (JSONData.results.bindings.length > 0) {
		    var objs = JSONData.results.bindings;
		    for (var i = 0;i < objs.length; i++) { /* for each result row */
			var g = objs[i].g;
			if(!g) { continue; };

			var uri = g.value;
			var parts = self.getPrefixParts(uri);
			if (!parts) { continue; }
			var label = parts[2] || parts[0];
			self.Schemas.MergeSchema(self.Schemas.Unbound,parts[0],uri,label,true);
		    }
		}
	    }
	    var params = {
		endpoint:iSPARQL.endpointOpts.endpointPath,
		query:'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>\n' +
		'SELECT DISTINCT ?g ' + getFromQueryStr() + '\n' +
		' WHERE { ?s a ?o .\n' +
		'    GRAPH ?g {\n' +
		'        { ?o a <http://www.w3.org/1999/02/22-rdf-syntax-ns#Property> . } UNION\n' +
		'        { ?o a <http://www.w3.org/2002/07/owl#Class> . } UNION\n' +
		'        { ?o a <http://www.w3.org/2000/01/rdf-schema#Class> . } UNION\n' +
		'        { ?o a <http://www.w3.org/2002/07/owl#ObjectProperty> . } UNION\n' +
		'        { ?o a <http://www.w3.org/2002/07/owl#DatatypeProperty> . } UNION\n' +
		'        { ?o a <http://www.w3.org/2002/07/owl#InverseFunctionalProperty> } } }',
		//default_graph_uri:,
		maxrows:0,
		should_sponge:'',
		format:'application/sparql-results+json',
		onstart:function() {
		    node._icon.src = OAT.Preferences.imagePath+"Dav_throbber.gif";
		    node._icon.style.filter = "";
		},
		onend:function() {
		    node._icon.src = oldIcon;
		    node._icon.style.filter = oldFilter;
		},
		errorHandler:function(xhr) {
		    var status = xhr.getStatus();
		    var response = xhr.getResponseText();
		    var headers = xhr.getAllResponseHeaders();
		    alert(response);
		},
		callback:callback
	    }
	    iSPARQL.QueryExec(params);
	}
    }

    self.Schemas.Reset();

    OAT.MSG.attach(self.Schemas.Tree, 'TREE_EXPAND', function(sender,msgcode,node) {
		       if (node.uritype) {
			   self.Schemas.Update(node);
		       }
		       if (node == self.Schemas.Unbound) { self.Schemas.Refresh(true); }
		   });


    var schema_cl = new OAT.Combolist([],self.prefixes[0].uri);
    schema_cl.input.name = "schema";
    schema_cl.input.id = "schema";
    schema_cl.img.src = "images/cl.gif";
    schema_cl.img.width = "16";
    schema_cl.img.height = "16";
    $("schema_div").appendChild(schema_cl.div);

    for (var i = 0;i < self.prefixes.length; i++) {
	if (!self.prefixes[i].hidden) { schema_cl.addOption(self.prefixes[i].uri); }
    }

    this.func_clear = function() {
	tab.go(tab_qbe);
	if (confirm('Are you sure you want to clear the pane?')) {
	    self.clear();
	}
    }

    this.setOpts = function (data) {
	iSPARQL.metaDataOpts.loadObj (data.metaDataOpts);
	var o = {
	    pragmas: data.pragmas,
	    endpointPath: data.endpoint,
	    useProxy: data.useProxy
	}
	iSPARQL.endPointOpts.loadObj (o);
    }

    this.func_load = function() {
	if (iSPARQL.serverConn.connected) {
	    var callback = function(path,file,data) {
		self.loadFromString(data.query);
		self.setOpts(data);
	    }
	    iSPARQL.IO.load(callback);
	}
    }

    // XXX OAT.Toolbar doesn't support disabled icons (!) so have to have check here
    //     should fix OAT toolbar for this.

    this.func_save = function() {
	if (iSPARQL.serverConn.connected)
	    self.save();
    }

    this.func_saveas = function() {
	if (iSPARQL.serverConn.connected)
	    self.save();
    }

    this.serverConnectHandler = function (sender, msg, evt) {
	iSPARQL.Common.enableFileOps();

    },

    this.serverDisconnectHandler = function (sender, msg, evt) {
	iSPARQL.Common.disableFileOps();
    },

    this.disableFileOps = function () {
	OAT.Event.detach("menu_qbe_load",  "click",  self.func_load);
	OAT.Event.detach("menu_qbe_save",  "click",  self.func_save);
	OAT.Event.detach("menu_qbe_saveas","click",  self.func_saveas);

	OAT.Dom.addClass("menu_qbe_load",   "disabled");
	OAT.Dom.addClass("menu_qbe_save",   "disabled");
	OAT.Dom.addClass("menu_qbe_saveas", "disabled");
    }

    this.enableFileOpts = function () {
	OAT.Event.attach("menu_qbe_load",  "click",  self.func_load);
	OAT.Event.attach("menu_qbe_save",  "click",  self.func_save);
	OAT.Event.attach("menu_qbe_saveas","click",  self.func_saveas);

	OAT.Dom.removeClass("menu_qbe_load",   "disabled");
	OAT.Dom.removeClass("menu_qbe_save",   "disabled");
	OAT.Dom.removeClass("menu_qbe_saveas", "disabled");
    }

    /* create toolbar and bind its buttons to various SVGSparql modes */
    var icon_drag, icon_add, icon_draw, icon_remove, icon_clear, icon_group;
    var icon_load, icon_save, icon_saveas, icon_run, icon_generate, icon_get_from_adv, icon_arrange;
    //var icon_back, icon_forward, icon_start, icon_finish;
    var icon_datasets, icon_graph_add;

    var t = new OAT.Toolbar("qbe_toolbar");

    icon_clear = t.addIcon(0,"images/new.png","Clear Pane",self.func_clear);
    OAT.Event.attach("menu_qbe_clear","click",self.func_clear);

    icon_load =   t.addIcon(0,"images/open_h.png",   "Open",       self.func_load);
    icon_save =   t.addIcon(0,"images/save_h.png",   "Save",       self.func_save);
    icon_saveas = t.addIcon(0,"images/save_as_h.png","Save As...", self.func_saveas);

    t.addSeparator();

    icon_drag = t.addIcon(1,"images/select_mode_h.png","Drag mode",function(state) {
			      if (!state) { return; }
			      icon_add.toggleState(0);
			      icon_draw.toggleState(0);
			      if (self.svgsparql) { self.svgsparql.mode = OAT.SVGSparqlData.MODE_DRAG; }
			  });
    icon_add = t.addIcon(1,"images/add_node_mode_h.png","Add nodes",function(state) {
			     if (!state) { return; }
			     icon_drag.toggleState(0);
			     icon_draw.toggleState(0);
			     self.svgsparql.mode = OAT.SVGSparqlData.MODE_ADD;
			 });
    var process = function(elm) { elm.firstChild.style.color = "#f00"; elm.firstChild.style.listStyleType = "none";}
    var drop = function(target,x_,y_) {
	if (target == qbe.svgsparql) {
	    var pos = OAT.Dom.position(target.parent);
	    var x = x_ - pos[0];
	    var y = y_ - pos[1];
	    node = target.addNode(x,y,"",0);
	};
    }

    OAT.MSG.attach ("*", "iSPARQL_SERVER_CONNECTED", this.serverConnectHandler);

    if (self.svgsparql) { self.svgsparql.ghostdrag.addSource(icon_add,process,drop); }

    OAT.Dom.unlink(icon_add.firstChild);
    icon_add.style.backgroundImage = "url(images/add_node_mode_h.png)";
    icon_add.style.backgroundRepeat = "no-repeat";
    icon_add.style.backgroundPosition = "center";
    icon_add.style.width = '24';
    icon_add.style.height = '24';

    icon_draw = t.addIcon(1,"images/connect_mode_h.png","Connector",function(state) {
			      if (!state) { return; }
			      icon_drag.toggleState(0);
			      icon_add.toggleState(0);
			      self.svgsparql.mode = OAT.SVGSparqlData.MODE_DRAW;
			  });
    var process = function(elm) {
	elm.firstChild.style.color = "#f00";
	elm.firstChild.style.listStyleType = "none";
    }
    var drop = function(target,x_,y_) {
	if (target != qbe.svgsparql && !target.node2) {
	    var pos = OAT.Dom.position(target.svgsparql.parent);
	    var x = x_ - pos[0];
	    var y = y_ - pos[1];
	    qbe.svgsparql.startDrawing(target,x,y,'?');
	}
    }
    if (self.svgsparql) { self.svgsparql.ghostdrag.addSource(icon_draw,process,drop); }
    OAT.Dom.unlink(icon_draw.firstChild);
    icon_draw.style.backgroundImage = "url(images/connect_mode_h.png)";
    icon_draw.style.backgroundRepeat = "no-repeat";
    icon_draw.style.backgroundPosition = "center";
    icon_draw.style.width = '24';
    icon_draw.style.height = '24';

    icon_group = t.addIcon(0,"images/group_h.png","Group Selected",function(state) {
			       if (self.svgsparql.selectedNodes.length > 0) {
				   if (self.svgsparql.selectedGroups.length == 0) {
				       var g = self.svgsparql.addGroup("");
				   } else {
				       var g = self.svgsparql.selectedGroups[0];
				   }

				   for (var i = 0;i < self.svgsparql.selectedNodes.length;i++) {
				       node = self.svgsparql.selectedNodes[i];
				       var oldgroup = node.group;
				       node.setGroup(g);
				       if(oldgroup && oldgroup.nodes.length == 0)
					   self.svgsparql.removeGroup(oldgroup);
				   }
				   self.svgsparql.deselectNodes();
			       } else if (self.svgsparql.selectedGroups.length > 0) {
				   if (self.svgsparql.selectedGroups.length == 1) { var g = false; } else { var g = self.svgsparql.selectedGroups[0]; }
				   for(var i = 0;i < self.svgsparql.selectedGroups.length;i++)	{
				       if (self.svgsparql.selectedGroups[i] != g) { self.svgsparql.selectedGroups[i].setParent(g); }
				   }
			       }
			   });

    icon_remove = t.addIcon(0,"images/delete_h.png","Remove",function(state) {
				//if (!state) { return; }
				if (self.svgsparql.selectedEdges.length +
				    self.svgsparql.selectedNodes.length +
				    self.svgsparql.selectedGroups.length > 0 )
				    if (confirm('Are you sure you want to delete the selected objects?')) {
					for(var i = 0;i < self.svgsparql.selectedEdges.length;i++) {
					    self.svgsparql.removeEdge(self.svgsparql.selectedEdges[i]);
					}
					for(var i = 0;i < self.svgsparql.selectedNodes.length;i++) {
					    self.svgsparql.removeNode(self.svgsparql.selectedNodes[i]);
					}
					for(var i = 0;i < self.svgsparql.selectedGroups.length;i++) {
					    self.svgsparql.removeGroup(self.svgsparql.selectedGroups[i]);
					}
					self.svgsparql.deselectNodes();
					self.svgsparql.deselectEdges();
					self.svgsparql.deselectGroups();
				    }
			    });

    t.addSeparator();

    this.func_run = function() {
	self.RunQuery();
    }

    this.func_generate = function() {
	//if (tab.selectedIndex != 0 && !tab_qbe.window) return;
	tab.go(tab_query);
	$('query').value = self.QueryGenerate();
	$('default-graph-uri').value = '';
	$('adv_sponge').value = $v('qbe_sponge');
	iSPARQL.Common.setQuery($('query').value);
    }

    this.func_get_from_adv = function() {
	tab.go(tab_qbe);
	//if (tab.selectedIndex != 0 && !tab_qbe.window) return;
	self.loadFromString($('query').value);
	if ($v('qbe_graph') == '')
	    $('qbe_graph').value = $v('default-graph-uri').trim();
	$('qbe_sponge').value = $v('adv_sponge');
    }

    this.func_arrange = function() {
	tab.go(tab_qbe);
	//if (tab.selectedIndex != 0 && !tab_qbe.window) return;
	self.svgsparql.reposition();
    }

    icon_run = t.addIcon(0,"images/cr22-action-player_play.png","Run Query",self.func_run);
    OAT.Event.attach("menu_qbe_run","click",self.func_run);

    t.addSeparator();

    icon_generate = t.addIcon(0,"images/cr22-action-exec.png","Generate",self.func_generate);
    OAT.Event.attach("menu_qbe_generate","click",self.func_generate);

    icon_get_from_adv = t.addIcon(0,"images/compfile.png","Get from Advanced",self.func_get_from_adv);
    OAT.Event.attach("menu_qbe_get_from_adv","click",self.func_get_from_adv);

    t.addSeparator();

    icon_arrange = t.addIcon(0,"images/make_kdevelop.png","Auto Arrange",self.func_arrange);
    OAT.Event.attach("menu_qbe_arrange","click",self.func_arrange);

    t.addSeparator();

    icon_datasets = t.addIcon(0,"images/folder_html.png","Dataset",function(){
				  if (self.dataset_win.dom.container.style.display == 'none') {
				      OAT.Dom.show(self.dataset_win.dom.container);
				  } else {
				      OAT.Dom.hide(self.dataset_win.dom.container);
				  }
				  self.l.raise(self.dataset_win.dom.container);
			      });
    //icon_datasets.style.cssFloat = 'right';

    var ds_graph_add = function() {
	self.addDataSource($v('qbe_graph').trim());
	$('qbe_graph').value = '';
	//return;
	self.Schemas.Refresh();
    };

    var qbe_graph_input = OAT.Dom.create("input");
    qbe_graph_input.id = "qbe_graph";
    qbe_graph_input.name = "qbe_graph";

    var calc_width = function() {
	var w = OAT.Dom.getViewport()[0];
	qbe_graph_input.style.width = w - 680 + 'px';
    }
    calc_width();
    OAT.Event.attach(window,"resize",calc_width);

    var qbe_graph_label = OAT.Dom.create("label");
    qbe_graph_label["htmlFor"] = "qbe_graph";

    qbe_graph_label.innerHTML = 'Data Source (URL):';
    qbe_graph_label.title = 'RDF Data Source (URL):';

    var qbe_datasource_cnt = OAT.Dom.create("sub");
    qbe_datasource_cnt.id = "qbe_datasource_cnt";
    qbe_datasource_cnt.innerHTML = '0';

    OAT.Dom.append([t.div,qbe_datasource_cnt,qbe_graph_label,qbe_graph_input]);

    icon_graph_add = t.addIcon(0,"images/edit_add.png","add",ds_graph_add)
    //OAT.Event.attach("qbe_datasource_graph_add","click",ds_graph_add);
    icon_graph_add.style.marginTop = '6px';

    this.dataset_win = new OAT.Win({title:"Dataset", 
				    close:1, 
				    min:0, 
				    max:0, 
				    outerWidth:page_w - 400, 
				    outerHeight:200, 
				    x:200,
				    y:160});
    $("page_qbe").appendChild(this.dataset_win.dom.container);
    self.l.addLayer(this.dataset_win.dom.container);
    this.dataset_win.dom.content.appendChild($("qbe_dataset_div"));
    this.dataset_win.onclose = function() { OAT.Dom.hide(self.dataset_win.container); }
    OAT.Dom.hide(self.dataset_win.dom.container);

    this.dataSourceNum = 1;

    this.addDataSource = function(val,type) {
	if (!val){ alert('Empty Information Source!'); return false; }

	var table = $('qbe_dataset_list');
	if (!table.tBodies.length) {
	    var body = OAT.Dom.create("tbody")
	    	table.appendChild(body);
	}

	var row = OAT.Dom.create("tr");
	OAT.Dom.addClass(row,"odd");
	row.id = 'ds_list_row'+self.dataSourceNum;
	table.tBodies[0].appendChild(row);

	var cell_cb = OAT.Dom.create("td");
	cell_cb.innerHTML = '<input type="checkbox" name="ds_cbk" value="'+self.dataSourceNum+'" checked="checked"/>';
	cell_cb.style.textAlign = "center";
	row.appendChild(cell_cb);

	var cell_cb = OAT.Dom.create("td");
	cell_cb.innerHTML = '<select id="ds_type_'+self.dataSourceNum+'"><option value="F">From</option><option value="N"'+((type == 'N')?' selected="selected"':'')+'>Named</option></select>';
	row.appendChild(cell_cb);

	var cell_ds = OAT.Dom.create("td");
	cell_ds.innerHTML = '<input type="text" style="width: 440px;" id="ds_'+self.dataSourceNum+'" value="'+val+'"/>';
	row.appendChild(cell_ds);

	var cell_rm = OAT.Dom.create("td");
	cell_rm.style.textAlign = "center";
	row.appendChild(cell_rm);
	var rem_btn = OAT.Dom.create("button");
	rem_btn.innerHTML = '<img src="images/edit_remove.png" title="del" alt="del"/> del';
	cell_rm.appendChild(rem_btn);

	OAT.Event.attach(rem_btn,"click",function(){
				   OAT.Dom.unlink(row);
				   if (!table.tBodies[0].rows.length) { OAT.Dom.unlink(table.tBodies[0]); }
				   $('qbe_datasource_cnt').innerHTML--;
				   self.Schemas.Refresh();
		       });

	OAT.Event.attach($('ds_'+self.dataSourceNum),"change",function(){
			   self.Schemas.Refresh();
		       });

	$('qbe_datasource_cnt').innerHTML++;
	self.dataSourceNum++;

	return true;
    }
    OAT.Event.attach("qbe_dataset_add_btn","click",function() {
		       self.addDataSource($v('qbe_dataset_add'));
		       $('qbe_dataset_add').value = '';
		       self.Schemas.Refresh();
		   });

    var getFromQueryStr = function() {
	var qbe_graph = $v('qbe_graph').trim();
	var from = '';
	if (qbe_graph != '') { from = 'FROM <' + qbe_graph + '>\n'; }
	var ds_cbks = document.getElementsByName('ds_cbk');
	if (ds_cbks && ds_cbks.length > 0) {
	    for(var n = 0; n < ds_cbks.length; n++)	{
		if (ds_cbks[n].checked)	{
		    var val = $v('ds_'+ds_cbks[n].value).trim();
		    if (val != '') {
			if ($v('ds_type_'+ds_cbks[n].value) == 'N') {
			    from += 'FROM NAMED <' + val + '>\n';
			} else {
			    from += 'FROM <' + val + '>\n';
			}
		    }
		}
	    }
	}
	return from;
    }

    OAT.Keyboard.add('return',self.func_run,null,null,null,$('qbe_graph'));
    OAT.Event.attach($('qbe_graph'),"change",self.Schemas.Refresh);

    icon_drag.toggleState(1);
    /* input field for value editing */
    OAT.Event.attach("qbe_node_id","keyup",function() {
		       var obj = false;
		       if (self.svgsparql.selectedNode)
			   {
			       obj = self.svgsparql.selectedNode;
			       if (obj)
				   {
				       obj.MySetLabel(1,$v("qbe_node_id"));
				   }
			   }
		   });

    /* input fields for value editing */
    OAT.Event.attach("qbe_node_res_type","keyup",function() {
		       var obj = false;
		       if (self.svgsparql.selectedNode)
			   {
			       obj = self.svgsparql.selectedNode;
			       if (obj)
				   {
				       var val = $v("qbe_node_res_type");
				       if (val.trim() == '') val = '--type--';
				       obj.MySetLabel(2,val);
				   }
			   }
		   });
    OAT.Event.attach("qbe_edge_value","keyup",function() {
		       var obj = false;
		       if (self.svgsparql.selectedEdge)
			   {
			       obj = self.svgsparql.selectedEdge;
			       var val = $v("qbe_edge_value");
			       if (val.trim() == '') val = '?';
			       if (obj)
				   obj.MySetLabel(1,val);
			   }
		   });

    /* input field for value editing */
    OAT.Event.attach("qbe_group_id","keyup",function() {
		       var obj = false;
		       if (self.svgsparql.selectedGroup)
			   {
			       obj = self.svgsparql.selectedGroup;
			       if (obj)
				   {
				       obj.MySetLabel(1,$v("qbe_group_id"));
				   }
			   }
		   });

    /* input field for node type switching */
    OAT.Event.attach("qbe_node_type","change",function() {
		       var obj = false;
		       if (self.svgsparql.selectedNode) {
			   obj = self.svgsparql.selectedNode;
			   obj.setType($v('qbe_node_type'));
			   self.svgsparql.selectNode(obj);
		       }
		   });

    /* input field for group type switching */
    OAT.Event.attach("qbe_group_type","change",function() {
		       var obj = false;
		       if (self.svgsparql.selectedGroup)
			   {
			       obj = self.svgsparql.selectedGroup;
			       if ($v("qbe_group_type") == OAT.SVGSparqlData.GROUP_GRAPH)
				   {
				       obj.MySetType($v("qbe_group_type"));
				       obj.setFill(self.group_color_seq.getNext());
				       obj.MySetLabel(1,'?');
				   } else {
				   obj.MySetType($v("qbe_group_type"));
				   self.removeOrderBy(obj);
			       }
			       self.svgsparql.selectGroup(obj);
			   }
		   });

    /* input field for node type switching */
    OAT.Event.attach("qbe_edge_type","change",function() {
		       var obj = false;
		       if (self.svgsparql.selectedEdge)
			   {
			       obj = self.svgsparql.selectedEdge;
			       if($("qbe_edge_type").checked)
				   obj.setType(1);
			       else
				   obj.setType(0);
			   }
		   });

    /* obj 'visibility' */
    OAT.Event.attach("qbe_visible","change",function() {
		       for(var i = 0;i < self.svgsparql.selectedNodes.length;i++)
			   self.svgsparql.selectedNodes[i].setVisible($("qbe_visible").checked);
		       for(var i = 0;i < self.svgsparql.selectedEdges.length;i++)
			   self.svgsparql.selectedEdges[i].setVisible($("qbe_visible").checked);
		       for(var i = 0;i < self.svgsparql.selectedGroups.length;i++)
			   self.svgsparql.selectedGroups[i].setVisible($("qbe_visible").checked);
		   });

    /* obj 'orderby' */
    OAT.Event.attach("qbe_orderby","change",function() {
		       if ($("qbe_orderby").checked)
			   {
			       for(var i = 0;i < self.svgsparql.selectedGroups.length;i++)
				   if (self.svgsparql.selectedGroups[i].getType() == OAT.SVGSparqlData.GROUP_GRAPH)
				       self.addOrderBy(self.svgsparql.selectedGroups[i]);
			       for(var i = 0;i < self.svgsparql.selectedNodes.length;i++)
				   self.addOrderBy(self.svgsparql.selectedNodes[i]);
			       for(var i = 0;i < self.svgsparql.selectedEdges.length;i++)
				   self.addOrderBy(self.svgsparql.selectedEdges[i]);
			   } else {
			   for(var i = 0;i < self.svgsparql.selectedEdges.length;i++)
			       self.removeOrderBy(self.svgsparql.selectedEdges[i]);
			   for(var i = 0;i < self.svgsparql.selectedNodes.length;i++)
			       self.removeOrderBy(self.svgsparql.selectedNodes[i]);
			   for(var i = 0;i < self.svgsparql.selectedGroups.length;i++)
			       self.removeOrderBy(self.svgsparql.selectedGroups[i]);
		       }
		   });

    /* file name for saving */
    var fileRef = function() {
	var path = iSPARQL.Common.getFilePath();
	var pathDefault = iSPARQL.Common.getDefaultPath();

	var ext = $v('qbe_savetype');

	var name = OAT.Dav.getNewFile(path,'.' + ext);
	if (!name) { return; }
	if (name.slice(name.length-ext.length - 1).toLowerCase() != "." + ext) { name += "." + ext; }
	$("qbe_save_name").value = name;
    }
    OAT.Event.attach("qbe_browse_btn","click",fileRef);

    this.RunQuery = function() {
	var p = {
	    query:self.QueryGenerate(),
	    defaultGraph:$v("qbe_graph"),
	    sponge:$v("qbe_sponge"),
	    endpoint:iSPARQL.endpointOpts.endpointPath,
	    pragmas:iSPARQL.endpointOpts.pragmas,
	    maxrows:iSPARQL.dataObj.maxrows,
	    view:0
	}
	iSPARQL.recentQueryUI.addQuery (p.query);
	
	var lc = [];

	if (qe.detectLocationMacros(p.query)) {
	    if (!iSPARQL.locationCache) {
		if (!!localStorage && !!localStorage.iSPARQL_locationCache)
		    lc = localStorage.iSPARQL_locationCache;
		iSPARQL.locationCache = new iSPARQL.LocationCache (10, lc, true);
	    }
	    var locUI = new iSPARQL.locationAcquireUI ({useCB: qe.executeWithLocation, 
                cancelCB: false,
		cbParm: p,
		cache: iSPARQL.locationCache});
	    locUI.refresh();
	} else {
	qe.execute(p);
    }
    }

    this.loadFromString = function(data) {
	var findByLabel = function(objs, label) {
	    for (var i = 0;i < objs.length;i++)
		if (objs[i].getLabel(1) == label) return i;
	    return -1;
	}

	var walkSparqlQuery = function(obj,nodes,group) {
	    ret = [];
	    switch (obj.type) {
	    case 'group':
		for (var i = 0; i < obj.children.length; i++)
		    {
			var t = walkSparqlQuery(obj.children[i],nodes,group);
			ret.push(t);
		    }
		return ret;
	        break;
	    case 'union':
		var new_group = self.svgsparql.addGroup("",1);
		new_group.MySetType(OAT.SVGSparqlData.GROUP_UNION);
		if (group) new_group.setParent(group);
		for (var i = 0; i < obj.children.length; i++)
		    {
			var new_nodes = [];
			walkSparqlQuery(obj.children[i],new_nodes,new_group);
		    }
		return new_group;
	        break;
	    case 'optional':
		if (obj.content.type == 'pattern')
		    return walkSparqlQuery(obj.content,nodes,group);
		else
		    {
			var new_group = self.svgsparql.addGroup("",1);
			new_group.MySetType(OAT.SVGSparqlData.GROUP_OPTIONAL);
			if (group) new_group.setParent(group);
			walkSparqlQuery(obj.content,nodes,new_group);
			return group;
		    }
	        break;
	    case 'graph':
		var g = self.putPrefix(obj.name);
		var new_group = self.svgsparql.addGroup(g,1);
		new_group.setFill(self.group_color_seq.getNext());
		if (!g.match(/^\?/) || (g.match(/^\?/) && obj.obj.variables.length != 0 && obj.obj.variables.find(g.substring(1)) == -1))
	            new_group.setVisible(false);
		if (group) new_group.setParent(group);
		walkSparqlQuery(obj.content,nodes,new_group);

		if (findByLabel(nodes,g) != -1)
		    {
			var inx = findByLabel(nodes,g);
			var node = nodes[inx];
			for(var i = 0; i < node.edges.length; i++)
			    {
				var node1 = node.edges[i].node1;
				var edge = self.svgsparql.addEdge(node1,new_group,node.edges[i].getLabel(1),1);
				edge.setVisible(node.edges[i].getVisible());
			    }
			self.svgsparql.removeNode(node);
			nodes.splice(inx,1);
		    }

		return new_group;
	        break;
	    case "pattern":
		var node1;
		var node2;
		var s = self.putPrefix(obj.s);
		if (findByLabel(nodes,s) == -1)
		    {
			node1 = self.svgsparql.addNode(0,0,"",1);
			node1.MySetLabel(1,s);
			node1.setType(OAT.SVGSparqlData.NODE_CIRCLE);
			if (!s.match(/^\?/) || (s.match(/^\?/) && obj.obj.variables.length != 0 && obj.obj.variables.find(s.substring(1)) == -1))
			    node1.setVisible(false);
			if (group) node1.setGroup(group);
			nodes.push(node1);
		    } else
	            node1 = nodes[findByLabel(nodes,s)];

		var o = self.putPrefix(obj.o);
		if (obj.p == '<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>' &&
		    (!o.match(/^\?/) ||
		     o.match(/^\?/) && obj.obj.variables.length != 0 && obj.obj.variables.find(o.substring(1)) == -1)
		    )
		    {
			node1.MySetLabel(2,o);
			return node1;
			break;
		    }

		if (findByLabel(nodes,o) == -1) {
	            node2 = self.svgsparql.addNode(0,0,"",1);
	            node2.MySetLabel(1,o);
	            if (obj.otype == '')
			node2.setType(OAT.SVGSparqlData.NODE_CIRCLE);
	            else
			node2.MySetLabel(2,self.putPrefix(obj.otype));

	            if (!o.match(/^\?/) || (o.match(/^\?/) && obj.obj.variables.length != 0 && obj.obj.variables.find(o.substring(1)) == -1))
			node2.setVisible(false);
	            if (group) node2.setGroup(group);
	            nodes.push(node2);
		} else
	            node2 = nodes[findByLabel(nodes,o)];

		var p = self.putPrefix(obj.p);
		var edge = self.svgsparql.addEdge(node1,node2,"",1);
		edge.MySetLabel(1,p);
		if (obj.parent.type == 'optional')
		    edge.setType(OAT.SVGSparqlData.EDGE_DASHED);
		if (!p.match(/^\?/) || (p.match(/^\?/) && obj.obj.variables.length != 0 && obj.obj.variables.find(p.substring(1)) == -1))
	            edge.setVisible(false);
		return node1;
	        break;
	    default:
	        break;
	    }
	    return ret;
	}

	try {
	    if (data.match(/<[\w:_ ]+>/)) {
		var xml = OAT.Xml.createXmlDoc(data);
	    } else {
		var xml = {};
	    }
	    if (xml.firstChild && xml.firstChild.tagName == 'sparql_design') {
		self.clear();
		self.svgsparql.fromXML(xml);
	    }
	    else if (xml.firstChild && xml.getElementsByTagName("iSPARQL").length) {
		if (xml.getElementsByTagName("ISparqlDynamicPage").length) {
		    var dyn_page_node = xml.getElementsByTagName("ISparqlDynamicPage")[0];
		    var query_node = dyn_page_node.getElementsByTagName("query")[0];
		    data = OAT.Xml.textValue(query_node);
		}
		var design_loaded = false;
		if (xml.getElementsByTagName("sparql_design").length) {
		    var isparql_node = xml.getElementsByTagName("iSPARQL")[0];
		    self.clear();
		    if (isparql_node.getElementsByTagName("sparql_design").length) {
			self.svgsparql.fromXML(isparql_node.getElementsByTagName("sparql_design")[0]);
		    }

		    if (xml.getElementsByTagName("schema").length) {
			var schemas = xml.getElementsByTagName("schema");
			for (var i=0;i < schemas.length;i++)
			    self.Schemas.Import(schemas[i].getAttribute('uri'),1);
		    }

		    if (xml.getElementsByTagName("should_sponge").length) {
			var sponge_node = xml.getElementsByTagName("should_sponge")[0];
			$('qbe_sponge').value = OAT.Xml.textValue(sponge_node);
		    }

		    if (xml.getElementsByTagName("service").length)	{
			var service = xml.getElementsByTagName("service")[0];
			$('service').value = OAT.Xml.textValue(service);
		    }

		    for (var i=0;i<self.svgsparql.groups.length;i++)
			self.svgsparql.groups[i].MySetType(self.svgsparql.groups[i].getType());
		    design_loaded = true;
		}

	    }
	    else if (xml.firstChild && xml.getElementsByTagName("sparql").length) {
		var nodes = xml.getElementsByTagName("sparql");
		for (var i=0;i<nodes.length;i++)
		    if (nodes[i].namespaceURI == "urn:schemas-openlink-com:xml-sql")
			data = OAT.Xml.textValue(nodes[i]);
	    }

	    if (!design_loaded) {
		var tmp = data.match(/#should-sponge:(.*)/i)
		if (tmp && tmp.length > 1) {
		    $('qbe_sponge').value = tmp[1].trim();
		}

		var tmp = data.match(/#service:(.*)/i)
		if (tmp && tmp.length > 1) {
		    $('service').service.input.value = tmp[1].trim();
		}
	    }

	    var sq = new OAT.SparqlQuery();
	    sq.fromString(data);
	    if (!design_loaded) { self.clear(); }

	    /* prefixes */
	    self.prefixes = sq.prefixes.concat(self.prefixes);
	    self.Schemas.Reset();
	    for (var i=0;i<sq.prefixes.length;i++)
		self.Schemas.Import(sq.prefixes[i].uri,1);

	    $('qbe_graph').value = '';
	    if (sq.from instanceof Array)  {
		for(var i = 0;i<sq.from.length ;i++)
		    if (sq.from[i] != '') self.addDataSource(sq.from[i].trim().match(/^<(.*)>$/)[1]);
	    } else
		if (sq.from)
		    $('qbe_graph').value = sq.from.trim().match(/^<(.*)>$/)[1];

	    for(var i = 0;i<sq.from_named.length ;i++)
		self.addDataSource(sq.from_named.trim().match(/^<(.*)>$/)[1],'N');

	    $('qbe_distinct').checked = sq.distinct;

	    if (sq.mode == "SELECT") $('qbe_query_type').selectedIndex = 0;
	    if (sq.mode == "DESCRIBE") $('qbe_query_type').selectedIndex = 1;
	    if (sq.mode == "INSERT") $('qbe_query_type').selectedIndex = 2;
	    if (sq.mode == "DELETE") $('qbe_query_type').selectedIndex = 3;

	    if (!design_loaded)	{
		if (sq.construct)
		    {
			var const_nodes = [];
			var new_group = self.svgsparql.addGroup("",1);
			new_group.MySetType(OAT.SVGSparqlData.GROUP_CONSTRUCT);
			walkSparqlQuery(sq.construct,const_nodes,new_group);
		    }

		var nodes = [];
		walkSparqlQuery(sq.where,nodes,false);
	    } else {

		for (var i=0;i<self.svgsparql.nodes.length;i++) {
		    var node = self.svgsparql.nodes[i];
		    self.Schemas.InsertNode(self.Schemas.Bound,node.getLabel(1),"class",false,false);
		}
		for (var i=0;i<self.svgsparql.edges.length;i++) {
		    var edge = self.svgsparql.edges[i];
		    self.Schemas.InsertNode(self.Schemas.Bound,edge.getLabel(1),"property_attr",false,false);
		}
	    }
	    /* orders */
	    for (var i=0;i<sq.orders.length;i++) {
		var n = findByLabel(self.svgsparql.nodes,'?' + sq.orders[i].variable);
		if(n != -1) {
		    self.addOrderBy(self.svgsparql.nodes[n]);
		    if (sq.orders[i].desc)
			self.svgsparql.nodes[n].orderby_cell.changeSort(OAT.GridData.SORT_DESC);
		}

		var n = self.svgsparql.edges.find('?' + sq.orders[i].variable);
		if(n != -1) {
		    self.addOrderBy(self.svgsparql.edges[n],1);
		    if (sq.orders[i].desc)
			self.svgsparql.edges[n].orderby_cell.changeSort(OAT.GridData.SORT_DESC);
		}

		var n = findByLabel(self.svgsparql.groups,'?' + sq.orders[i].variable);
		if(n != -1) {
		    self.addOrderBy(self.svgsparql.groups[n]);
		    if (sq.orders[i].desc)
			self.svgsparql.groups[n].orderby_cell.changeSort(OAT.GridData.SORT_DESC);
		}
	    }

	    // self.Schemas.Refresh();
	    if (!design_loaded) { self.svgsparql.reposition(); }

	} catch (e) {
	    self.clear();
	    alert('There was an error trying to visualize the query. Please check if the query is valid.');
	    if (self.defaults.debug) throw (e);
	}
    }

    this.QueryGenerate = function()	{

	var proc_nodes = {};
	var used_prefixes = Array();
	var gc = 0;
	var sc = 0;
	var pc = 0;
	var oc = 0;
	var sq = new OAT.SparqlQuery();
	var where;

	var QueryGenerateProcNode = function(node,sq_grp,sq,group) {

	    if (!proc_nodes[group]) proc_nodes[group] = [];
	    if (node instanceof OAT.SVGSparqlGroup)
		{
		    if (node.getType() == OAT.SVGSparqlData.GROUP_UNION)
			{
			    var sq_grp_new = new OAT.SparqlQueryDataUnion(sq_grp,sq);
			    sq_grp.children.push(sq_grp_new);
			}
		    else if (node.getType() == OAT.SVGSparqlData.GROUP_OPTIONAL)
			{
			    var grp = new OAT.SparqlQueryDataOptional(sq_grp,sq);
			    var sq_grp_new = new OAT.SparqlQueryDataGroup(grp,sq);
			    grp.content = sq_grp_new;
			    sq_grp.children.push(grp);
			}
		    else if (node.getType() == OAT.SVGSparqlData.GROUP_CONSTRUCT)
			{
			    var sq_grp_new = new OAT.SparqlQueryDataGroup(sq,sq);
			    sq.construct = sq_grp_new;
			}
		    else
			{
			    if (node.getLabel(1) == '?' || node.getLabel(1) == '')
				{
				    if (gc > 0) node.MySetLabel(1,'?g' + gc);
				    else node.MySetLabel(1,'?g');
				    gc++;
				}

			    var grp = new OAT.SparqlQueryDataGraph(sq_grp,sq);
			    grp.name = node.getLabel(1);
			    var sq_grp_new = new OAT.SparqlQueryDataGroup(grp,sq);
			    grp.content = sq_grp_new;
			    sq_grp.children.push(grp);

			    var tmp;
			    if (node.getVisible())
				if ((tmp = node.getLabel(1).match(/\?(.*)$/)) && sq.variables.find(tmp[1]) == -1)
				    sq.variables.push(tmp[1]);
			}

			var primary_nodes = [];
			// find primary nodes (the once that are not a child of any)
			for (var i=0;i < node.nodes.length;i++)
			    {
				var tmp_node = node.nodes[i];
				var is_prim = 1;
				if (node != tmp_node.group)
				    is_prim = 0;
				else
				    for (var n=0;n < tmp_node.edges.length;n++)
					{
					    if ((tmp_node.edges[n].node1.group != tmp_node.group &&
						 tmp_node.edges[n].node2.group == tmp_node.group)
						||
						(tmp_node.edges[n].node2.group != tmp_node.group &&
						 tmp_node.edges[n].node1.group == tmp_node.group))
						{
						    var ptr = new OAT.SparqlQueryDataPattern(sq_grp_new,sq);
						    sq_grp_new.children.push(ptr);
						    QueryGenerateProcEdge(ptr,tmp_node.edges[n],sq_grp_new,sq,node);
						}
					    if (tmp_node.edges[n].node2 == tmp_node)
						{
						    is_prim = 0;
						    break;
						}
					}
				if (is_prim)
				    primary_nodes.push(tmp_node);
			    }
			for (var n=0;n < primary_nodes.length;n++)
			    QueryGenerateProcNode(primary_nodes[n],sq_grp_new,sq,node);

			var child_groups = [];
			for (var i=0;i < self.svgsparql.groups.length;i++)
			    {
				var new_grp = self.svgsparql.groups[i];
				var is_prim = 1;
				if (node != new_grp.parent)
				    is_prim = 0;
				else
				    for (var n=0;n < new_grp.edges.length;n++)
					{
					    if (new_grp.edges[n].node2 == grp)
						{
						    is_prim = 0;
						    break;
						}
					}
				if (is_prim)
				    child_groups.push(new_grp);
			    }
			for (var n=0;n < child_groups.length;n++)
			    QueryGenerateProcNode(child_groups[n],sq_grp_new,sq,child_groups[n]);

			return grp;
		}

	    // We now determine if we need to make pattern for the type
	    if (node instanceof OAT.SVGSparqlNode && proc_nodes[group].find(node) == -1)
		{
		    var t = node.getLabel(2);

		    if (node.getLabel(1) == '?' || node.getLabel(1) == '')
			{ if (sc > 0) node.MySetLabel(1,'?s' + sc);
			    else node.MySetLabel(1,'?s');
			    sc++;
			}

		    if (t != '' && t != '--type--' && node.getType() == OAT.SVGSparqlData.NODE_CIRCLE)
			{
			    var ptr = new OAT.SparqlQueryDataPattern(sq_grp,sq);
			    sq_grp.children.push(ptr);
			    ptr.s = self.expandPrefix(node.getLabel(1));
			    ptr.p = 'a';
			    ptr.o = self.expandPrefix(t);
			    // put in the array of used_prefixes
			    self.optPrefix(ptr.s,used_prefixes);
			    self.optPrefix(ptr.p,used_prefixes);
			    self.optPrefix(ptr.o,used_prefixes);
			}
		    // Lets see if it should be visible?
		    var tmp;
		    if (node.getType() == OAT.SVGSparqlData.NODE_CIRCLE && node.getVisible())
			if ((tmp = node.getLabel(1).match(/\?(.*)$/)) && sq.variables.find(tmp[1]) == -1)
			    sq.variables.push(tmp[1]);
		    //query_vars += node.getSValue() + ' ';
		}

	    // then we go though all edges
	    for (var n=0;n < node.edges.length;n++)
		{
		    // we go through all edges where the current node is a primary (left side) one
		    if (//proc_nodes.find(node.edges[n].node1) == -1 &&
			node == node.edges[n].node1 &&
			(
			 node instanceof OAT.SVGSparqlNode &&
			 node.getType() == OAT.SVGSparqlData.NODE_CIRCLE
			 )
			)
			{
			    if (node.edges[n].node2 instanceof OAT.SVGSparqlNode && node.group != node.edges[n].node2.group)
				{
				    return false;
				} else {
				if (node.edges[n].getType() == OAT.SVGSparqlData.EDGE_DASHED)
				    {
					var opt = new OAT.SparqlQueryDataOptional(sq_grp,sq);
					var ptr = new OAT.SparqlQueryDataPattern(opt,sq);
					opt.content = ptr;
					sq_grp.children.push(opt);
					//pattern = 'OPTIONAL {' + pattern + '}'
				    } else {
				    var ptr = new OAT.SparqlQueryDataPattern(sq_grp,sq);
				    sq_grp.children.push(ptr);
				}
				var next_grp = sq_grp;
			    }

			    QueryGenerateProcEdge(ptr,node.edges[n],sq_grp,sq,group)
			}
		}
	    proc_nodes[group].push(node);
	    return sq_grp;
	}

	var QueryGenerateProcEdge = function(ptr,edge,sq_grp,sq,group) {
	    // Init the names
	    if (edge.node1.getLabel(1) == '?' || edge.node1.getLabel(1) == '')
		{ if (sc > 0) edge.node1.MySetLabel(1,'?s' + sc);
		    else edge.node1.MySetLabel(1,'?s');
		  sc++;
		}
	    if (edge.getLabel(1) == '?' || edge.getLabel(1) == '')
		{ if (pc > 0) edge.MySetLabel(1,'?p' + pc);
		    else edge.MySetLabel(1,'?p');
		  pc++;
		}
	    if (edge.node2.getLabel(1) == '?' || edge.node2.getLabel(1) == '')
		{ if (oc > 0) edge.node2.MySetLabel(1,'?o' + oc);
		    else edge.node2.MySetLabel(1,'?o');
		  oc++;
		}
	    // Lets see if it is visible
	    if (edge.getVisible())
		if ((tmp = edge.getLabel(1).match(/\?(.*)$/)) && sq.variables.find(tmp[1]) == -1)
		    sq.variables.push(tmp[1]);

	    ptr.s = self.expandPrefix(edge.node1.getLabel(1));
	    ptr.p = self.expandPrefix(edge.getLabel(1));
	    ptr.o = self.expandPrefix(edge.node2.getLabel(1));
	    // Populate used_prefixes
	    self.optPrefix(ptr.s,used_prefixes);
	    self.optPrefix(ptr.p,used_prefixes);
	    self.optPrefix(ptr.o,used_prefixes);

	    // If it is a value node then we need to set the proper type
	    if (edge.node2 instanceof OAT.SVGSparqlNode && edge.node2.getType() == OAT.SVGSparqlData.NODE_RECT)
		{
		    var t = edge.node2.getLabel(2);
		    if (t != '' && t != '--type--')
			{
			    ptr.otype = self.expandPrefix(t);
			    if (ptr.otype.indexOf('<http://www.w3.org/2001/XMLSchema#') != 0)
				self.optPrefix(ptr.otype,used_prefixes);
			}
		    else
			ptr.otype = 'xsd:string';
		} else {
		QueryGenerateProcNode(edge.node2,sq_grp,sq,group);
	    }
	    return ptr;
	}

	for (var i=0;i < self.svgsparql.nodes.length;i++)
	    {
		if(self.svgsparql.nodes[i].getLabel(1).match(/\?s[0-9]*\W*/))
		    sc++;
		else if(self.svgsparql.nodes[i].getLabel(1).match(/\?o[0-9]*\W*/))
		    oc++;
		else if(self.svgsparql.nodes[i].getLabel(1).match(/\?g[0-9]*\W*/))
		    gc++;
		else if(self.svgsparql.nodes[i].getLabel(1).match(/\?p[0-9]*\W*/))
		    pc++;
	    }
	for (var i=0;i < self.svgsparql.groups.length;i++)
	    {
		if(self.svgsparql.groups[i].getLabel(1).match(/\?s[0-9]*\W*/))
		    sc++;
		else if(self.svgsparql.groups[i].getLabel(1).match(/\?o[0-9]*\W*/))
		    oc++;
		else if(self.svgsparql.groups[i].getLabel(1).match(/\?g[0-9]*\W*/))
		    gc++;
		else if(self.svgsparql.groups[i].getLabel(1).match(/\?p[0-9]*\W*/))
		    pc++;
	    }
	for (var i=0;i < self.svgsparql.edges.length;i++)
	    {
		if(self.svgsparql.edges[i].getLabel(1).match(/\?s[0-9]*\W*/))
		    sc++;
		else if(self.svgsparql.edges[i].getLabel(1).match(/\?o[0-9]*\W*/))
		    oc++;
		else if(self.svgsparql.edges[i].getLabel(1).match(/\?g[0-9]*\W*/))
		    gc++;
		else if(self.svgsparql.edges[i].getLabel(1).match(/\?p[0-9]*\W*/))
		    pc++;
	    }


	var primary_nodes = [];
	// find primary nodes (the once that are not a child of any)
	for (var i=0;i < self.svgsparql.nodes.length;i++)
	    {
		var node = self.svgsparql.nodes[i];
		var is_prim = 1;
		if (node.group)
		    is_prim = 0;
		else
		    for (var n=0;n < node.edges.length;n++)
			{
			    if (node.edges[n].node2 == node)
				{
				    is_prim = 0;
				    break;
				}
			}
		if (is_prim)
		    primary_nodes.push(node);
	    }

	var child_groups = [];
	for (var i=0;i < self.svgsparql.groups.length;i++)
	    {
		var grp = self.svgsparql.groups[i];
		var is_prim = 1;
		if (false != grp.parent)
		    is_prim = 0;
		else
		    for (var n=0;n < grp.edges.length;n++)
			{
			    if (grp.edges[n].node2 == grp)
				{
				    is_prim = 0;
				    break;
				}
			}
		if (is_prim)
		    child_groups.push(grp);
	    }

	var sq_grp = new OAT.SparqlQueryDataGroup(sq,sq);

	for (var i=0;i < primary_nodes.length;i++) { QueryGenerateProcNode(primary_nodes[i],sq_grp,sq,false); }

	for (var n=0;n < child_groups.length;n++) { QueryGenerateProcNode(child_groups[n],sq_grp,sq,child_groups[n]); }

	where = sq_grp;
	sq.where = where;

	var qbe_graph = $v('qbe_graph').trim();
	var from = [];
	var named = [];

	if (qbe_graph != '')
	    from.push('<' + qbe_graph + '>');

	// get all checked named_graphs from named graphs tab
	var ds_cbks = document.getElementsByName('ds_cbk');

	if(ds_cbks && ds_cbks.length > 0) {
	    for(var n = 0; n < ds_cbks.length; n++)
		{
		    // if it is checked, add to params too
		    if (ds_cbks[n].checked)
			{
			    var val = $v('ds_'+ds_cbks[n].value).trim();
			    if (val != '')
				{
				    if ($v('ds_type_'+ds_cbks[n].value) == 'N')
					named.push('<' + val + '>');
				    else
					from.push('<' + val + '>');
				}
			}
		}
	}

	sq.from = from;
	sq.from_named = named;

	for (var i=1;i < self.orderby_grid.header.cells.length;i++)
	    {
		var label = self.orderby_grid.header.cells[i].value.innerHTML;
		var tmp = label.match(/^\?(\w*)/);
		var variable = tmp[1];
		var desc = false;
		if (self.orderby_grid.header.cells[i].sort == OAT.GridData.SORT_DESC)
		    desc = true;
		sq.orders.push({"desc": desc,"variable":variable});
	    }

	var full_query = '';
	for (var j=0;j < used_prefixes.length;j = j + 2) {
	    sq.prefixes.push({"label":used_prefixes[j],"uri":used_prefixes[j + 1]});
	}
	sq.distinct = $('qbe_distinct').checked;
	sq.mode = $v("qbe_query_type");

	full_query = sq.toString();

	return full_query;

    }

    if (window.__inherited) {
	if (window.__inherited.callback) {
	    /* query returning */
	    var returnRef = function() {
		window.__inherited.callback(self.QueryGenerate());
		window.close();
	    }
	    OAT.Event.attach("qbe_return_btn", "click", returnRef);
	} else { OAT.Dom.hide("qbe_return_btn");}

    } else {
	if (self.svgsparql) { self.loadFromString(self.defaults.query); self.svgsparql.reposition();}
	$('qbe_graph').value = self.defaults.graph;
	OAT.Dom.hide("qbe_return_btn");
    }
}
