OAT.SVGSparqlGroup.prototype.MySetType = function(type){
  if (type == OAT.SVGSparqlData.GROUP_OPTIONAL) 
  {
	  this.setFill('E5E5E5');
	  this.MySetLabel(1,'OPTIONAL');
	  this.label.setAttribute("fill",'797979');
	} else if (type == OAT.SVGSparqlData.GROUP_UNION) {
	  this.setFill('DEDEEF');
	  this.MySetLabel(1,'UNION');
	  this.label.setAttribute("fill",'6767B4');
	} else if (type == OAT.SVGSparqlData.GROUP_CONSTRUCT) {
	  for (var i = 0;i < this.svgsparql.groups.length;i++)
	    if (this.svgsparql.groups[i] != this && this.svgsparql.groups[i].getType() == OAT.SVGSparqlData.GROUP_CONSTRUCT)
	    {
	      alert('More than one CONSTRUCT statement is not supported!');
	      return false;
	    }

	  this.setFill('FFE3D7');
	  this.MySetLabel(1,'CONSTRUCT');
	  this.label.setAttribute("fill",'D23F00');
	} else {
	  this.label.setAttribute("fill",'000000');
  }
  this.setType(type);
  return true;
}


OAT.SVGSparqlEdge.prototype.setValueByDrop = function(val,t,x,y){
  if (t == 'class')
  {
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

OAT.SVGSparqlNode.prototype.setValueByDrop = function(val,t,x,y){
  if (t != 'class')
  {
    this.svgsparql.startDrawing(this,x,y,val);
    return true;
  }
  else
  {
    this.MySetLabel(2,val);
		this.svgsparql.deselectEdges();
		this.svgsparql.deselectNodes();
    this.svgsparql.deselectGroups();
    this.svgsparql.selectNode(this);
    return true;
  }
}

OAT.SVGSparqlNode.prototype.MySetLabel = function(which,newLabel){
  this.setLabel(which,newLabel);
  if (which == 1 && this.orderby_cell)
    this.orderby_cell.value.innerHTML = newLabel;
}

OAT.SVGSparqlEdge.prototype.MySetLabel = function(which,newLabel){
  this.setLabel(which,newLabel);
  if (which == 1 && this.orderby_cell)
    this.orderby_cell.value.innerHTML = newLabel;
}

OAT.SVGSparqlGroup.prototype.MySetLabel = function(which,newLabel){
  this.setLabel(newLabel);
  if (which == 1 && this.orderby_cell)
    this.orderby_cell.value.innerHTML = newLabel;
}

iSPARQL.GroupColorSeq = function()
{
	var self = this;
	this.seq = ['#ff0','#f0f','#0ff','#0f0'];
	this.inx = -1;
  this.getNext = function()
  {
    self.inx++;

    if (self.inx == self.seq.length)
      self.inx = 0;
    return self.seq[self.inx];
  }
  this.reset = function()
  {
    self.inx = -1;
  }
}

iSPARQL.QBE = function ()
{
	var self = this;
	
	this.group_color_seq = new iSPARQL.GroupColorSeq();

	this.clear = function(){
	  self.svgsparql.clear();
	  for (var i = self.orderby_grid.header.cells.length;i > 1; i--)
	  {
      self.orderby_grid.header.removeColumn(i - 1);
    }
    self.resetPrefixes();
	  $('qbe_distinct').checked = false;
	  $('qbe_query_type').selectedIndex = 0;
	  
	  self.group_color_seq.reset();
	  
	  self.format_set();
	  
    var table = $('qbe_dataset_list');
    if (table.tBodies.length)
      OAT.Dom.unlink(table.tBodies[0]);
    $('qbe_datasource_cnt').innerHTML=0;
	}

  this.format_set = function()
  {
	  var format = $('qbe_format');
    for(var i = format.options.length; i > 0; i--)
      format.options[i] = null;

    var set_rdf_options = function(format)
	    {
        format.options[0] = new Option('RDF Graph','application/isparql+rdf-graph');
        format.options[1] = new Option('N3/Turtle','text/rdf+n3');
        format.options[2] = new Option('RDF/XML','application/rdf+xml');
        format.selectedIndex = 0;
    }
    
    if ($v('qbe_query_type') == 'DESCRIBE')
    {
      set_rdf_options(format);
      return;
    }

	  for (var i = 0;i < self.svgsparql.groups.length;i++)
	    if (self.svgsparql.groups[i].getType() == OAT.SVGSparqlData.GROUP_CONSTRUCT)
	    {
        set_rdf_options(format);
        return;
      }

    format.options[0] = new Option('Table','application/isparql+table');
    format.options[1] = new Option('XML','application/sparql-results+xml');
    format.options[2] = new Option('JSON','application/sparql-results+json');
    format.options[3] = new Option('Javascript','application/javascript');
    format.options[4] = new Option('HTML','text/html');
    format.selectedIndex = 0;
    return;
  };
	
	/* create SVGSparql object */
	var options = {
	  nodeOptions:{
      size:15,
      fill:"#f00"
    },
		selectNodeCallback:function(node) {
			node.svg.setAttribute("stroke-width","2");
			node.svg.setAttribute("stroke","#00f"); 
			OAT.Dom.hide("qbe_props_edge");
			OAT.Dom.hide("qbe_props_group");
			OAT.Dom.show("qbe_props_node");
		  
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
			OAT.Dom.hide("qbe_props_node");
		},
		selectEdgeCallback:function(edge) {
			edge.svg.setAttribute("stroke","#f00");
			OAT.Dom.hide("qbe_props_node");
			OAT.Dom.hide("qbe_props_group");
			OAT.Dom.show("qbe_props_edge");
			
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
			OAT.Dom.hide("qbe_props_edge");
		},
		selectGroupCallback:function(group) {
			group.svg.setAttribute("stroke-width","2");
			group.svg.setAttribute("stroke","#f00");
			OAT.Dom.hide("qbe_props_node");
			OAT.Dom.hide("qbe_props_edge");
			OAT.Dom.show("qbe_props_group");

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
			OAT.Dom.hide("qbe_props_group");
		},
	  addNodeCallback:function(node,loadMode)
	  { 
	    if (loadMode) return;
	    node.setType(OAT.SVGSparqlData.NODE_CIRCLE); 
	    node.MySetLabel(1,'?');
	    node.MySetLabel(2,'--type--');
			self.svgsparql.deselectEdges();
			self.svgsparql.deselectNodes();
      self.svgsparql.deselectGroups();
	    self.svgsparql.selectNode(node); 
	  },
	  addEdgeCallback:function(edge,loadMode)
	  { 
	    //edge.setVisible(true);
	    if (loadMode) return;
	    edge.MySetLabel(1,'?');
			self.svgsparql.deselectNodes();
			self.svgsparql.deselectEdges();
      self.svgsparql.deselectGroups();
	    self.svgsparql.selectEdge(edge); 
	  },
	  addGroupCallback:function(group,loadMode)
	  { 
	    group.setVisible(true);
	    group.setFill(self.group_color_seq.getNext());
	    if (loadMode) return;
	    group.MySetLabel(1,'?');
			self.svgsparql.deselectEdges();
      self.svgsparql.deselectGroups();
	    self.svgsparql.selectGroup(group); 
	  },
	  removeNodeCallback:function(node){
	    self.removeOrderBy(node);
	  },
	  removeEdgeCallback:function(edge){
	    self.removeOrderBy(edge);
    },
	  removeGroupCallback:function(group){
	    self.removeOrderBy(group);
    }
	};
	this.svgsparql = new OAT.SVGSparql("qbe_parent",options);
	var restrictionFunction = function(new_width,new_height)  { return new_width < 600; }

	OAT.Resize.create("qbe_resizer_area", "qbe_canvas", OAT.Resize.TYPE_XY,restrictionFunction);
	OAT.Resize.create("qbe_resizer_area", "qbe_parent", OAT.Resize.TYPE_XY,restrictionFunction);
	
	var win_width = 260;
	var win_x = -20;

	this.schema_win = new OAT.Window({title:"Schemas", close:0, min:0, max:0, width:win_width, height:300, x:win_x,y:230});
	this.schema_win.move._Drag_movers[0][1].restrictionFunction = function(l,t) {
		return l < 0 || t < 0;
	}
	$("page_qbe").appendChild(this.schema_win.div);
	l.addLayer(this.schema_win.div);
	this.schema_win.content.appendChild($("schemas"));
	OAT.Resize.create(this.schema_win.resize, "schemas_tree_container", OAT.Resize.TYPE_XY);

	this.props_win = new OAT.Window({title:"Properties", close:0, min:0, max:0, width:win_width, height:86, x:win_x,y:100});
	this.props_win.move._Drag_movers[0][1].restrictionFunction = function(l,t) {
		return l < 0 || t < 0;
	}
	$("page_qbe").appendChild(this.props_win.div);
	l.addLayer(this.props_win.div);
	this.props_win.content.appendChild($("qbe_props"));

	this.results_win = new OAT.Window({title:"Query Results", close:1, min:0, max:0, width:page_w - 40, height:500, x:20,y:600});
	$("page_qbe").appendChild(this.results_win.div);
	l.addLayer(this.results_win.div);
	this.results_win.content.appendChild($("qbe_res_area"));
  this.results_win.onclose = function() { OAT.Dom.hide(self.results_win.div); }
  OAT.Dom.hide(self.results_win.div);

  this.orderby_grid = new OAT.Grid("qbe_orderby_grid",0)
  self.orderby_grid.createHeader([{value:'order by',sortable:0,draggable:0,resizable:0}]);
	
  this.addOrderBy = function(obj,addmode){
    var index = self.orderby_grid.header.cells.length;
    if (obj.node2 && obj.node2.orderby_cell && !addmode)
      index = obj.node2.orderby_cell.number;
    if (!obj.orderby_cell)
    {
      var label = obj.getLabel(1).trim();
      var orderby_cell = self.orderby_grid.appendHeader({value:label,sortable:1,draggable:1,resizable:0},index);
      obj.orderby_cell = orderby_cell;
    }
  }
  this.removeOrderBy = function(obj){
    if (obj.orderby_cell)
    {
      self.orderby_grid.header.removeColumn(obj.orderby_cell.number);
      obj.orderby_cell = false;
    }
  }

	this.var_cnt = 1;

  this.schematree = new OAT.Tree({ext:"png",onClick:"toggle", onDblClick:"toggle"});
  this.schematree.assign("schemas_tree",false);
  this.schematree.unbound = self.schematree.tree.createChild('unbound',1);
  self.schematree.unbound.collapse();
  this.schematree.bound = self.schematree.tree.createChild('bound',1);
  self.schematree.bound.collapse();
  var ref_img = OAT.Dom.create('img');
  ref_img.src = 'images/reload.png';
	OAT.Dom.attach(ref_img,"click",function(){self.schematree.bound.expand();self.SchemaTreeRefresh()});
	self.schematree.bound.gdElm.appendChild(ref_img);
  
	this.save = function(save_name,save_type) {
	  var data = self.getSaveData(save_type)
    goptions.last_path = save_name;
    set_dav_props(goptions.last_path);
		var send_ref = function() { return data; }
		var recv_ref = function(data) { alert('Saved.'); }
		OAT.AJAX.PUT(save_name,send_ref(),recv_ref,{user:goptions.username,password:goptions.password,auth:OAT.AJAX.AUTH_BASIC,headers:{'Content-Type':get_mime_type(goptions.last_path)}});
	}
	
	this.getSaveData = function(save_type){
		var data = "";
		
		data += '#should-sponge:' + $v('qbe_sponge') + '\n';
		data += '#service:' + self.service.input.value + '\n';
		
		switch (save_type) {
			case "rq":
			  data += self.QueryGenerate();
			break;
			case "xml":
			  data += self.QueryGenerate();
    		var xml = '<?xml version="1.0" encoding="UTF-8"?>\n';
  			xml += '<root xmlns:sql="urn:schemas-openlink-com:xml-sql"';
  			if ($v('qbe_graph'))
  			  xml += ' sql:default-graph-uri="' + $v('qbe_graph') + '"';
  			xml += '><sql:sparql>'+OAT.Dom.toSafeXML(data)+'</sql:sparql></root>';
  			data = xml;
			break;
			case "isparql":
			case "isparql.xml":
			  var xslt = location.pathname.substring(0,location.pathname.lastIndexOf("/")) + '/xslt/dynamic-page.xsl';
			  data += self.QueryGenerate();
    		var xml = '<?xml version="1.0" encoding="UTF-8"?>\n';
        xml += '<?xml-stylesheet type="text/xsl" href="' + xslt + '"?>\n';
  			xml += '<iSPARQL xmlns="urn:schemas-openlink-com:isparql">\n';
  			xml += '<ISparqlDynamicPage>\n';
  			//xml += '<service>'+goptions.service+'</service>\n';
  			//xml += '<should_sponge>'+goptions.should_sponge+'</should_sponge>\n';
  			xml += '<proxy>'+goptions.proxy+'</proxy>\n';
  			xml += '<query>'+OAT.Dom.toSafeXML(data)+'</query>\n';
  			for (var i=0;i < self.UpdatedSchemas.length;i++)
  			  xml += '<schema uri="'+ self.UpdatedSchemas[i] +'"/>\n';
  			xml += '</ISparqlDynamicPage>\n';
  			xml += self.svgsparql.toXML();
  			xml += '<should_sponge>'+$v('qbe_sponge')+'</should_sponge>\n';
  			xml += '<service>'+self.service.input.value+'</service>\n';
  			xml += '</iSPARQL>';
  			data = xml;
			break;
		}
		return data;
	}

  this.UpdatedSchemas = [];
  this.prefixes = [];
  
  this.resetPrefixes = function(){
    self.prefixes = [{"label":'atom', "uri":'http://atomowl.org/ontologies/atomrdf#'},
                     {"label":'foaf', "uri":'http://xmlns.com/foaf/0.1/'},
      			         {"label":'owl', "uri":'http://www.w3.org/2002/07/owl#'},
      			         {"label":'sioct', "uri":'http://rdfs.org/sioc/types#'},
      			         {"label":'sioc', "uri":'http://rdfs.org/sioc/ns#'},
      			         {"label":'ibis', "uri":'http://purl.org/ibis#'},
      			         {"label":'ical', "uri":'http://www.w3.org/2002/12/cal/icaltzd#'},
      			         {"label":'annotation', "uri":'http://www.w3.org/2000/10/annotation-ns#'},
      			         {"label":'rdfs', "uri":'http://www.w3.org/2000/01/rdf-schema#'},
      			         {"label":'rdf', "uri":'http://www.w3.org/1999/02/22-rdf-syntax-ns#'},
      			         {"label":'dcterms', "uri":'http://purl.org/dc/terms/'},
      			         {"label":'dc', "uri":'http://purl.org/dc/elements/1.1/'},
      			         {"label":'cc', "uri":'http://web.resource.org/cc/'},
      			         {"label":'geo', "uri":'http://www.w3.org/2003/01/geo/wgs84_pos#'},
      			         {"label":'rss', "uri":'http://purl.org/rss/1.0/'},
      			         {"label":'skos', "uri":'http://www.w3.org/2004/02/skos/core#'},
      			         {"label":'vs', "uri":'http://www.w3.org/2003/06/sw-vocab-status/ns#'},
      			         {"label":'wot', "uri":'http://xmlns.com/wot/0.1/',"hidden":1},
      			         {"label":'xhtml', "uri":'http://www.w3.org/1999/xhtml',"hidden":1},
      			         {"label":'dataview', "uri":'http://www.w3.org/2003/g/data-view#',"hidden":1},
      			         {"label":'xsd', "uri":'http://www.w3.org/2001/XMLSchema#',"hidden":1}];
  }
  self.resetPrefixes();

  this.putPrefix = function(str) 
  {
    var tmp = '';
    if ((tmp = str.match(/^<(.*)>$/)))
    {
      for(var i = 0;i < self.prefixes.length; i++)
      {
        if (tmp[1].substring(0,self.prefixes[i].uri.length) == self.prefixes[i].uri)
        {
          return self.prefixes[i].label + ':' + tmp[1].substring(self.prefixes[i].uri.length);
        }
      }
    }
    return str;
  }

	this.expandPrefix = function(str)
	{
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

  this.optPrefix = function(str,used_prefixes) 
  {
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

	OAT.Dom.attach("schema_import","click",function() {
	  var schema = $v('schema');
	  
	  self.SchemaImport(schema);
    
    return false;
	});
	
	this.SchemaImport = function(schema, silent)
	{
	  self.schematree.unbound.expand();
	  if (self.UpdatedSchemas.find(schema) != -1)
	  {
	    if (!silent)
	      alert('Schema "' + schema + '" already imported!');
	    return;
	  }

	  self.SchemaAdd(schema);

    self.UpdatedSchemas.push(schema);
	}
	
	this.SchemaUpdate = function(node)
	{
	  //var node = li.OATTreeObj;
	  $('schema').value = node.li.uri;
	  if (node.children.length > 0)
	  {
	    ; //node.toggleState();
	  } else {
      // Executed when results are returned
	    var callback = function(data)
	    {
	      var processed = [];
	      var JSONData = eval('(' + data + ')');
	      if (JSONData.results.bindings.length > 0)
	      {
	        var Concepts;
	        var Properties;
	        var attr_inx = 0;
	        var objs = JSONData.results.bindings
          for(var i = 0;i < objs.length; i++)
          {
            var nodetype = '';
            // The uri should be from the current schema
            if (node.li.uri == objs[i].uri.value.substring(0,node.li.uri.length) && processed.find(objs[i].uri.value) == -1) 
            {
              switch (objs[i].type.value) {
                case "http://www.w3.org/2000/01/rdf-schema#Class":
                case "http://www.w3.org/2002/07/owl#Class":
                  nodetype = 'class';
                  break;
                case "http://www.w3.org/1999/02/22-rdf-syntax-ns#Property":
                case "http://www.w3.org/2002/07/owl#ObjectProperty":
                case "http://www.w3.org/2002/07/owl#DatatypeProperty":
                case "http://www.w3.org/2002/07/owl#InverseFunctionalProperty":
                  if(self.SchemaIsAttribute(objs[i]))
                    nodetype = 'property_attr';
                  else
                    nodetype = 'property_rel';
                  break
                default:
                  nodetype = '';
              }
              
              if (nodetype != '')
              {
                if (objs[i].label) var label = objs[i].label.value;
                else var label = self.putPrefix('<' + objs[i].uri.value + '>').replace('<','').replace('>','');
      	        if (nodetype == 'class')
      	        {
      	          if (!Concepts) 
      	          { 
      	            Concepts = node.createChild('Concepts',1,0); 
      	            Concepts.collapse();
      	          }
      	          var pnode = Concepts;
      	        } else {
      	          if (!Properties) 
      	          { 
      	            Properties = node.createChild('Properties',1); 
      	            Properties.collapse();
      	          }
      	          var pnode = Properties;
      	        }
      	        if (nodetype == 'property_attr')
      	        {
      	          var leaf = pnode.createChild(label,1,attr_inx);
      	          attr_inx++;
      	        } else
                  var leaf = pnode.createChild(label,1);
      	        leaf.collapse();
                if (objs[i].comment)
                {
                  leaf.li.alt = objs[i].comment.value;
                  leaf.li.title = objs[i].comment.value;
                }
                leaf.li.uri = objs[i].uri.value;
                leaf.li.uritype = nodetype;
                leaf.li.schema = node.li.uri;
                leaf.li.bound = node.li.bound;
                leaf.label.OATTreeObj = leaf;
                
        			  self.svgsparql.ghostdrag.addSource(leaf.label,self.SchemaNodeDragProcess,self.SchemaNodeDragDrop);
              	OAT.Dom.attach(leaf.label,"dblclick",self.SchemaNodeDblClick);

      	        if (nodetype == 'class')
      	          leaf.setImage('/../../../images/concept-icon-16');
      	        else if (nodetype == 'property_attr')
                  leaf.setImage('/../../../images/attribute-icon-16');
                else
                  leaf.setImage('/../../../images/relation-icon-16');

            	  //OAT.Dom.attach(leaf.label,"click",SchemaWalkClick);
              }
            }
            processed.push(objs[i].uri.value);
          }
	      }
	      //node.expand();
	    }
      var params = {
        //service:'./schema_import.vsp',
        service:self.service.input.value,
        query:'PREFIX owl: <http://www.w3.org/2002/07/owl#>' + '\n' +
              'PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>' + '\n' +
              'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>' + '\n' +
              '' + '\n' +
              'SELECT DISTINCT ?type ?uri ?label ?comment ?range' + '\n' +
            ((node.li.bound)?
              getFromQueryStr() +
              'WHERE {  ' + '\n' +
//              '  ?s rdf:type ?uri' + '\n' +
              '  { ' + '\n' +
              '    { ?s ?uri ?o }' + '\n' +
              '    union' + '\n' +
              '    { ?s a ?uri }' + '\n' +
              '  }' + '\n' +
              '    GRAPH <' + node.li.uri + '> {' + '\n' +
            '':
              'FROM <' + node.li.uri + '>' + '\n' +
              'WHERE {  ' + '\n' +
              '        {  ' + '\n' +
            '') + 
              '         ?uri rdf:type ?type .' + '\n' +
              '               FILTER (?type in (<http://www.w3.org/1999/02/22-rdf-syntax-ns#Property>)' + '\n' +
              '                    || ?type in (<http://www.w3.org/2002/07/owl#Class>)' + '\n' +
              '                    || ?type in (<http://www.w3.org/2000/01/rdf-schema#Class>)' + '\n' +
              '                    || ?type in (<http://www.w3.org/2002/07/owl#ObjectProperty>)' + '\n' +
              '                    || ?type in (<http://www.w3.org/2002/07/owl#DatatypeProperty>)' + '\n' +
              '                    || ?type in (<http://www.w3.org/2002/07/owl#InverseFunctionalProperty>))' + '\n' +
              '         OPTIONAL { ?uri rdfs:label ?label } .' + '\n' +
              '         OPTIONAL { ?uri rdfs:comment ?comment } .' + '\n' +
              '         OPTIONAL { ?uri rdfs:range ?range } .' + '\n' +
              '  }' + '\n' +
              '}' + '\n' +
              'ORDER BY ?uri',
        //default_graph_uri:node.li.uri,
        default_graph_uri:'',
        maxrows:0,
  	    should_sponge:((node.li.bound)?'':'soft'),
        format:'application/sparql-results+json',
        errorHandler:function(xhr)
        {
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

  // Function for dblclick
  this.SchemaNodeDblClick = function(){
    var obj = this.OATTreeObj.li;
	  if(obj.uritype == 'class')
	  {
	      for(var i = 0;i < self.svgsparql.selectedNodes.length;i++)
  		    self.svgsparql.selectedNodes[i].MySetLabel(2,self.putPrefix('<' + obj.uri + '>'));
  	} else {
  		  for(var i = 0;i < self.svgsparql.selectedEdges.length;i++)
    		  self.svgsparql.selectedEdges[i].MySetLabel(1,self.putPrefix('<' + obj.uri + '>'));
  	}
  }

  // Function for drag dim
  this.SchemaNodeDragProcess = function(elm) { elm.firstChild.style.color = "#f00"; elm.firstChild.style.listStyleType = "none";}

  // Function executed on drop
  this.SchemaNodeDragDrop = function(target,x_,y_) { 
    var obj = this.originalElement.OATTreeObj.li;
    if (target == qbe.svgsparql)
    {
      if (obj.uritype == 'class')
      {
  			var pos = OAT.Dom.position(target.parent);
  			var x = x_ - pos[0];
  			var y = y_ - pos[1];
        var node = target.addNode(x,y,"",0);
        node.MySetLabel(2,self.putPrefix('<' + obj.uri + '>'));
      }
    } else {
			var pos = OAT.Dom.position(target.svgsparql.parent);
			var x = x_ - pos[0];
			var y = y_ - pos[1];
      target.setValueByDrop(self.putPrefix('<' + obj.uri + '>'),obj.uritype,x,y); 
    }
  }
  		  
  this.SchemaWalkClick = function(node)
  {
    //var node = this.OATTreeObj;
    if (node.children.length > 0)
    {
      ; //node.toggleState();
    } else {
      var callback = function(data)
      {
        var processed = [];
        var JSONData = eval('(' + data + ')');
        if (JSONData.results.bindings.length > 0)
        {
          var Domains;
          var Ranges;
          var attr_inx = 0;
          var objs = JSONData.results.bindings
          for(var i = 0;i < objs.length; i++)
          {
            if (node.li.uritype == 'class')
            {
              if(self.SchemaIsAttribute(objs[i]))
                nodetype = 'property_attr';
              else
                nodetype = 'property_rel';
            } else
              var nodetype = 'class';
            // The uri should be from the current schema
            if (node.li.schema == objs[i].uri.value.substring(0,node.li.schema.length) && processed.find(objs[i].uri.value) == -1) 
            {
              if (objs[i].label) var label = objs[i].label.value;
              else var label = self.putPrefix('<' + objs[i].uri.value + '>').replace('<','').replace('>','');
  
    	        if (objs[i].type && objs[i].type.value == 'http://www.w3.org/2000/01/rdf-schema#domain')
    	        {
    	          if (!Domains) 
    	          { 
    	            Domains = node.createChild('in-domain-of',1,0); 
    	            Domains.collapse();
    	            //OAT.Dom.attach(Domains.label,"click",function(){ Domains.toggleState()});
    	          }
    	          var pnode = Domains;
    	        } else {
    	          if (!Ranges) 
    	          { 
    	            Ranges = node.createChild('in-range-of',1); 
    	            Ranges.collapse();
    	            //OAT.Dom.attach(Ranges.label,"click",function(){ Ranges.toggleState()});
    	          }
    	          var pnode = Ranges;
    	        }
  
    	        if (nodetype == 'property_attr')
    	        {
    	          var leaf = pnode.createChild(label,1,attr_inx);
    	          attr_inx++;
    	        } else
                var leaf = pnode.createChild(label,1);
    	        leaf.collapse();
              if (objs[i].comment)
              {
                leaf.li.alt = objs[i].comment.value;
                leaf.li.title = objs[i].comment.value;
              }
              leaf.li.uri = objs[i].uri.value;
              leaf.li.uritype = nodetype;
              leaf.li.schema = node.li.schema;
              leaf.li.bound = node.li.bound;
              leaf.label.OATTreeObj = leaf;
              
      			  self.svgsparql.ghostdrag.addSource(leaf.label,self.SchemaNodeDragProcess,self.SchemaNodeDragDrop);
            	OAT.Dom.attach(leaf.label,"dblclick",self.SchemaNodeDblClick);
  
    	        if (nodetype == 'class')
    	          leaf.setImage('/../../../images/concept-icon-16');
    	        else if (nodetype == 'property_attr')
                leaf.setImage('/../../../images/attribute-icon-16');
              else
                leaf.setImage('/../../../images/relation-icon-16');
  
          	  //OAT.Dom.attach(leaf.label,"click",SchemaWalkClick);
            }
          	processed.push(objs[i].uri.value)
          }
        }
        //node.expand();
      }
      var params = {
        service:self.service.input.value,
        query:'PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>' + '\n' +
              'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>' + '\n' +
              '' + '\n' +
              'SELECT DISTINCT ?type ?uri ?label ?comment ?range' + '\n' +
            ((node.li.bound)?
              getFromQueryStr() +
              'WHERE {' + '\n' +
              //'  ?s rdf:type ?uri' + '\n' +
              '    { ' + '\n' +
              '      { ?s ?uri ?o }' + '\n' +
              '      union' + '\n' +
              '      { ?s a ?uri }' + '\n' +
              '    }' + '\n' +
              '    GRAPH <' + node.li.schema + '> {' + '\n' +
            '':
              'FROM <' + node.li.schema + '>' + '\n' +
              'WHERE {  ' + '\n' +
              '        {  ' + '\n' +
            '') + 
              '  { ?uri rdfs:domain <' + node.li.uri + '> . }' + '\n' +
              '    union' + '\n' +
              '  { ?uri rdfs:range <' + node.li.uri + '> . }' + '\n' +
              '  ?uri ?type <' + node.li.uri + '>' + '\n' +
              '  OPTIONAL { ?uri rdfs:label ?label } .' + '\n' +
              '  OPTIONAL { ?uri rdfs:comment ?comment } .' + '\n' +
              '  OPTIONAL { ?uri rdfs:range ?range } .' + '\n' +
              '  }' + '\n' +
              '}' + '\n' +
              'ORDER BY ?uri',
        //default_graph_uri:node.li.schema,
        default_graph_uri:'',
        maxrows:0,
  	    should_sponge:'',
        format:'application/sparql-results+json',
        errorHandler:function(xhr)
        {
          var status = xhr.getStatus();
          var response = xhr.getResponseText();
    			var headers = xhr.getAllResponseHeaders();
          alert(response);
        },
        callback:callback
      }
      if (node.li.uritype != 'class')
        params.query = 'PREFIX owl: <http://www.w3.org/2002/07/owl#>' + '\n' +
              'PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>' + '\n' +
              'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>' + '\n' +
              '' + '\n' +
              'SELECT DISTINCT ?uri, ?label, ?comment, ?range' + '\n' +
            ((node.li.bound)?
              getFromQueryStr() +
              'WHERE {' + '\n' +
//              '  ?s rdf:type ?uri' + '\n' +
              '    { ' + '\n' +
              '      { ?s ?uri ?o }' + '\n' +
              '      union' + '\n' +
              '      { ?s a ?uri }' + '\n' +
              '    }' + '\n' +
              '    GRAPH <' + node.li.schema + '> {' + '\n' +
            '':
              'FROM <' + node.li.schema + '>' + '\n' +
              'WHERE {  ' + '\n' +
              '        {  ' + '\n' +
            '') + 
              '  { <' + node.li.uri + '> rdfs:domain ?uri . }' + '\n' +
              '    union' + '\n' +
              '  { <' + node.li.uri + '> rdfs:range ?uri . }' + '\n' +
              '  <' + node.li.uri + '> ?type ?uri' + '\n' +
              '  OPTIONAL { ?uri rdfs:label ?label } .' + '\n' +
              '  OPTIONAL { ?uri rdfs:comment ?comment } .' + '\n' +
              '  OPTIONAL { ?uri rdfs:range ?range } .' + '\n' +
              '  }' + '\n' +
              '}' + '\n' +
              'ORDER BY ?type ?uri';
      iSPARQL.QueryExec(params);
    }
  }

  this.SchemaIsAttribute = function(obj)
  {
    value = '';
    if (obj.range)
      value = obj.range.value;
    switch (value) {
      case "http://www.w3.org/2000/01/rdf-schema#Literal":
      case "http://atomowl.org/ontologies/atomrdf#Text":
      case "http://www.w3.org/1999/02/22-rdf-syntax-ns#value":
      case "http://atomowl.org/ontologies/atomrdf#Link":
      case "":
        return true;
        break;
      default:
        return false;
    }
    return false;
  }

  this.SchemaAdd = function(schema)
  {
    var node = self.schematree.unbound.createChild(self.putPrefix('<' + schema + '>').replace('<','').replace('>',''),1);
    node.setImage('/../../../images/rdf-icon-16');
    node.collapse();
    node.li.uri = schema;
    node.li.uritype = 'schema';
    node.li.bound = false;
    node.label.OATTreeObj = node;
  	//OAT.Dom.attach(node.label,"click",function() {
  	//  self.SchemaUpdate(this);
    //});
  }
  
  OAT.MSG.attach(self.schematree, OAT.MSG.TREE_EXPAND, function(sender,msgcode,node){
    if (node.li.uritype)
    {
      if (node.li.uritype == 'schema')
        self.SchemaUpdate(node);
      else 
        self.SchemaWalkClick(node);
    }
    if (node == self.schematree.bound)
      self.SchemaTreeRefresh(true);
  });
  
  this.SchemasReset = function()
  {
    for(var i = self.schematree.unbound.children.length - 1;i >= 0;i--)
      self.schematree.unbound.deleteChild(self.schematree.unbound.children[i]);
    self.UpdatedSchemas = [];
    //for(var i = 0;i<self.prefixes.length;i++)
    //  self.SchemaImport(self.prefixes[i].uri);
  }
  self.SchemasReset();
  
  this.SchemaRemove = function(schema)
  {
    for(var i = self.schematree.unbound.children.length - 1;i >= 0;i--)
    {
      if (self.schematree.unbound.children[i].li.uri == schema)
        self.schematree.unbound.deleteChild(self.schematree.unbound.children[i]);
    }
    if (self.UpdatedSchemas.find(schema) != -1)
      self.UpdatedSchemas.splice(self.UpdatedSchemas.find(schema),1);
  }

	OAT.Dom.attach("schema_remove","click",function() {
	  var schema = $v('schema');
	  
    self.SchemaRemove(schema);
    
    return false;
	});

  var schema_cl = new OAT.Combolist([],self.prefixes[0].uri);
  schema_cl.input.name = "schema";
  schema_cl.input.id = "schema";
  schema_cl.img.src = "images/cl.gif";
  $("schema_div").appendChild(schema_cl.div);

  for(var i = 0;i < self.prefixes.length; i++)
    if (!self.prefixes[i].hidden)
      schema_cl.addOption(self.prefixes[i].uri);
      
  this.func_clear = function() {
	  if (tab.selectedIndex != tab.keys.find($('tab_qbe'))) return;
		if(confirm('Are you sure you want to clear the pane?'))
		{
		  self.clear();
  	  $("qbe_res_area").innerHTML = '';
      OAT.Dom.hide(self.results_win.div);
		}
	}
	
	this.func_load = function() {
	  if (tab.selectedIndex != tab.keys.find($('tab_qbe'))) return;
	  var path = '/DAV';
	  if (goptions.username)
	    path += "/home/"+goptions.username;
	  var pathDefault = path;
	  if (goptions.username == 'dav')
	    pathDefault = '/DAV';
	    
    if (goptions.last_path)
      path = goptions.last_path.substring(0,goptions.last_path.lastIndexOf("/"));
	    
  	if (goptions.login_put_type == 'http')
  	{
      var fname = "";
      if (goptions.last_path)
        fname = goptions.last_path.substring(goptions.last_path.lastIndexOf("/") + 1);
			var name = OAT.Dav.getFile(path,fname);
			if (!name) { return; }
      goptions.last_path = name;
			OAT.AJAX.GET(name,'',self.loadFromString,{user:goptions.username,password:goptions.password,auth:OAT.AJAX.AUTH_BASIC});
  	} else {
    	var options = {
    		mode:'open_dialog',
    		user:goptions.username,
    		pass:goptions.password,
        pathDefault:pathDefault + '/',
    		path:path + '/',
    		filetypes:[{ext:'rq',label:'SPARQL Definitions Only'},{ext:'isparql',label:'SPARQL Query Diagram'},{ext:'isparql.xml',label:'iSPARQL Dynamic Page'},{ext:'xml',label:'XML file for execution'},{ext:'*',label:'All files'}],
        onConfirmClick:function(path,fname,data){
          goptions.last_path = path + fname;
          self.loadFromString(data);
          OAT.WebDav.close();
        }
      };
    	OAT.WebDav.open(options);
    	if (goptions.last_path) $('dav_filetype').value = get_file_type(goptions.last_path);
    }
	}
	
	this.func_save = function() {
	  if (tab.selectedIndex != tab.keys.find($('tab_qbe'))) return;
    if (goptions.last_path)
    {
      self.save(goptions.last_path,get_file_type(goptions.last_path)); 
    }else 
      icon_saveas.toggle();
	}
	
	this.func_saveas = function() {
	  if (tab.selectedIndex != tab.keys.find($('tab_qbe'))) return;
	  if (goptions.login_put_type == 'http')
	  {
      if (goptions.last_path)
      {
        $("qbe_save_name").value = goptions.last_path;
        $("qbe_savetype").value = get_file_type(goptions.last_path);
      }
	    dialogs.qbe_save.show();
	  } else {
  	  var path = '/DAV';
  	  if (goptions.username)
  	    path += "/home/"+goptions.username;
  	  var pathDefault = path;
  	  if (goptions.username == 'dav')
  	    pathDefault = '/DAV';

      if (goptions.last_path)
        path = goptions.last_path.substring(0,goptions.last_path.lastIndexOf("/"));

			var options = {
				mode:'save_dialog',
				onConfirmClick:function(ext){
				  OAT.WebDav.SaveContentType = get_mime_type(ext);
      		return qbe.getSaveData(ext);
				},
				afterSave:function(path,fname){
          goptions.last_path = path + fname;
          set_dav_props(goptions.last_path);
				},
    		user:goptions.username,
    		pass:goptions.password,
        pathDefault:pathDefault + '/',
    		path:path + '/',
    		filetypes:[{ext:'rq',label:'SPARQL Definitions Only'},{ext:'isparql',label:'SPARQL Query Diagram'},{ext:'isparql.xml',label:'iSPARQL Dynamic Page'},{ext:'xml',label:'XML file for execution'}]
			};
			OAT.WebDav.open(options);
    	if (goptions.last_path) $('dav_filetype').value = get_file_type(goptions.last_path);
	  }
	}

	/* create toolbar and bind its buttons to various SVGSparql modes */
	var icon_drag, icon_add, icon_draw, icon_remove, icon_clear, icon_group;
	var icon_load, icon_save, icon_saveas, icon_run, icon_generate, icon_get_from_adv, icon_arrange;
	var icon_back, icon_forward, icon_start, icon_finish;
	var icon_datasets;
	
	var t = new OAT.Toolbar("qbe_toolbar");
	
	icon_clear = t.addIcon(0,"images/qbe_clear.png","Clear Pane",self.func_clear);
	OAT.Dom.attach("menu_qbe_clear","click",self.func_clear);

	icon_load = t.addIcon(0,"images/fileopen.png","Open",self.func_load); 
	OAT.Dom.attach("menu_qbe_load","click",self.func_load);

	icon_save = t.addIcon(0,"images/filesave.png","Save",self.func_save); 
	OAT.Dom.attach("menu_qbe_save","click",self.func_save);

	icon_saveas = t.addIcon(0,"images/filesaveas.png","Save As...",self.func_saveas); 
	OAT.Dom.attach("menu_qbe_saveas","click",self.func_saveas);

	t.addSeparator();

	icon_start = t.addIcon(0,"images/start-22.png","First",function(){}); 
  icon_start.style.opacity = 0.3;
  icon_start.style.filter = 'alpha(opacity=30)';
  icon_start.style.cursor = 'default';
	icon_back = t.addIcon(0,"images/back-22.png","Back",function(){}); 
  icon_back.style.opacity = 0.3;
  icon_back.style.filter = 'alpha(opacity=30)';
  icon_back.style.cursor = 'default';
	icon_forward = t.addIcon(0,"images/forward-22.png","Forward",function(){}); 
  icon_forward.style.opacity = 0.3;
  icon_forward.style.filter = 'alpha(opacity=30)';
  icon_forward.style.cursor = 'default';
	icon_finish = t.addIcon(0,"images/finish-22.png","Last",function(){}); 
  icon_finish.style.opacity = 0.3;
  icon_finish.style.filter = 'alpha(opacity=30)';
  icon_finish.style.cursor = 'default';

	t.addSeparator();

	icon_drag = t.addIcon(1,"images/qbe_drag.gif","Drag mode",function(state) {
		if (!state) { return; }
		icon_add.toggleState(0);
		icon_draw.toggleState(0);
		self.svgsparql.mode = OAT.SVGSparqlData.MODE_DRAG;
	});
	icon_add = t.addIcon(1,"images/qbe_add.gif","Add mode",function(state) {
		if (!state) { return; }
		icon_drag.toggleState(0);
		icon_draw.toggleState(0);
		self.svgsparql.mode = OAT.SVGSparqlData.MODE_ADD;
	});
  var process = function(elm) { elm.firstChild.style.color = "#f00"; elm.firstChild.style.listStyleType = "none";}
  var drop = function(target,x_,y_) { 
    if (target == qbe.svgsparql)
    {
			var pos = OAT.Dom.position(target.parent);
			var x = x_ - pos[0];
			var y = y_ - pos[1];
      node = target.addNode(x,y,"",0);
    }; 
  }
  self.svgsparql.ghostdrag.addSource(icon_add,process,drop);
  OAT.Dom.unlink(icon_add.firstChild);
  icon_add.style.backgroundImage = "url(images/qbe_add.gif)";
  icon_add.style.backgroundRepeat = "no-repeat";
  icon_add.style.backgroundPosition = "center";
  icon_add.style.width = '24';
  icon_add.style.height = '24';

	icon_draw = t.addIcon(1,"images/qbe_draw.gif","Draw mode",function(state) {
		if (!state) { return; }
		icon_drag.toggleState(0);
		icon_add.toggleState(0);
		self.svgsparql.mode = OAT.SVGSparqlData.MODE_DRAW;
	});
  var process = function(elm) { elm.firstChild.style.color = "#f00"; elm.firstChild.style.listStyleType = "none";}
  var drop = function(target,x_,y_) { 
    if (target != qbe.svgsparql && !target.node2)
    {
			var pos = OAT.Dom.position(target.svgsparql.parent);
			var x = x_ - pos[0];
			var y = y_ - pos[1];
      qbe.svgsparql.startDrawing(target,x,y,'?');
    }
  }
  self.svgsparql.ghostdrag.addSource(icon_draw,process,drop);
  OAT.Dom.unlink(icon_draw.firstChild);
  icon_draw.style.backgroundImage = "url(images/qbe_draw.gif)";
  icon_draw.style.backgroundRepeat = "no-repeat";
  icon_draw.style.backgroundPosition = "center";
  icon_draw.style.width = '24';
  icon_draw.style.height = '24';

	icon_group = t.addIcon(0,"images/qbe_group.png","Group Selected",function(state) {
	  if (self.svgsparql.selectedNodes.length > 0)
	  {
	    if (self.svgsparql.selectedGroups.length == 0)
  	    var g = self.svgsparql.addGroup("");
  	  else 
  	    var g = self.svgsparql.selectedGroups[0];

  	  for(var i = 0;i < self.svgsparql.selectedNodes.length;i++)
  	  {
  	    node = self.svgsparql.selectedNodes[i];
  	    var oldgroup = node.group;
  	    node.setGroup(g);
  	    if(oldgroup && oldgroup.nodes.length == 0)
  	      self.svgsparql.removeGroup(oldgroup);
  	  }
      self.svgsparql.deselectNodes();
	  } else if (self.svgsparql.selectedGroups.length > 0){
	    if (self.svgsparql.selectedGroups.length == 1)
  	    var g = false;
  	  else 
  	    var g = self.svgsparql.selectedGroups[0];
  	  for(var i = 0;i < self.svgsparql.selectedGroups.length;i++)
  	  {
  	    if (self.svgsparql.selectedGroups[i] != g)
  	      self.svgsparql.selectedGroups[i].setParent(g);
  	  }
	  }
	});

	icon_remove = t.addIcon(0,"images/qbe_remove.png","Remove",function(state) {
		//if (!state) { return; }
		if (self.svgsparql.selectedEdges.length + self.svgsparql.selectedNodes.length + self.svgsparql.selectedGroups.length > 0 )
  		if(confirm('Are you sure you want to delete selected objects?'))
  		{
  		  for(var i = 0;i < self.svgsparql.selectedEdges.length;i++)
  		    self.svgsparql.removeEdge(self.svgsparql.selectedEdges[i]);
  		  for(var i = 0;i < self.svgsparql.selectedNodes.length;i++)
  		    self.svgsparql.removeNode(self.svgsparql.selectedNodes[i]);
  		  for(var i = 0;i < self.svgsparql.selectedGroups.length;i++)
  		    self.svgsparql.removeGroup(self.svgsparql.selectedGroups[i]);

    		self.svgsparql.deselectNodes();
    		self.svgsparql.deselectEdges();
    		self.svgsparql.deselectGroups();
    	}
	});

	t.addSeparator();

  this.func_run = function() {
	  if (tab.selectedIndex != tab.keys.find($('tab_qbe'))) return;
	  self.RunQuery();
	}
	
	this.func_generate = function() {
	  if (tab.selectedIndex != tab.keys.find($('tab_qbe'))) return;
	  tab.go(1); 
	  $('query').value = self.QueryGenerate();
	  format_select();
	  $('default-graph-uri').value = '';
    $('adv_sponge').value = $v('qbe_sponge');
	}
	
	this.func_get_from_adv = function() {
	  if (tab.selectedIndex != tab.keys.find($('tab_qbe'))) return;
	  self.loadFromString($('query').value);
	  if ($v('qbe_graph') == '')
	    $('qbe_graph').value = $v('default-graph-uri').trim();
    $('qbe_sponge').value = $v('adv_sponge');
	}
	
	this.func_arrange = function() {
	  if (tab.selectedIndex != tab.keys.find($('tab_qbe'))) return;
	  self.svgsparql.reposition();
	}

	icon_run = t.addIcon(0,"images/cr22-action-player_play.png","Run Query",self.func_run); 
	OAT.Dom.attach("menu_qbe_run","click",self.func_run);

	t.addSeparator();

	icon_generate = t.addIcon(0,"images/cr22-action-exec.png","Generate",self.func_generate);
	OAT.Dom.attach("menu_qbe_generate","click",self.func_generate);

	icon_get_from_adv = t.addIcon(0,"images/compfile.png","Get from Advanced",self.func_get_from_adv); 
	OAT.Dom.attach("menu_qbe_get_from_adv","click",self.func_get_from_adv);

	t.addSeparator();

	icon_arrange = t.addIcon(0,"images/make_kdevelop.png","Auto Arrange",self.func_arrange); 
	OAT.Dom.attach("menu_qbe_arrange","click",self.func_arrange);

	t.addSeparator();

	this.dataset_win = new OAT.Window({title:"Dataset", close:1, min:0, max:0, width:page_w - 400, height:200, x:200,y:160});
	$("page_qbe").appendChild(this.dataset_win.div);
	l.addLayer(this.dataset_win.div);
	this.dataset_win.content.appendChild($("qbe_dataset_div"));
  this.dataset_win.onclose = function() { OAT.Dom.hide(self.dataset_win.div); }
  OAT.Dom.hide(self.dataset_win.div);
  
  this.dataSourceNum = 1;

  this.addDataSource = function(val,type)
  {
    if (!val){ alert('Empty Data Source!'); return false; }
    
    var table = $('qbe_dataset_list');
    if (!table.tBodies.length)
    {
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
    
  	OAT.Dom.attach(rem_btn,"click",function(){
      OAT.Dom.unlink(row);
      if (!table.tBodies[0].rows.length)
        OAT.Dom.unlink(table.tBodies[0]);
      $('qbe_datasource_cnt').innerHTML--;
      self.SchemaTreeRefresh();
  	});

  	OAT.Dom.attach($('ds_'+self.dataSourceNum),"change",function(){
      self.SchemaTreeRefresh();
  	});
    
    $('qbe_datasource_cnt').innerHTML++;
    self.dataSourceNum++;
   
   return true; 
  }
	OAT.Dom.attach("qbe_dataset_add_btn","click",function() {
    self.addDataSource($v('qbe_dataset_add'));
    $('qbe_dataset_add').value = '';
    self.SchemaTreeRefresh();
  });

  var getFromQueryStr = function()
  {
    var qbe_graph = $v('qbe_graph').trim();
    var from = '';
  	if (qbe_graph != '')
  	  from = 'FROM <' + qbe_graph + '>\n';
    var ds_cbks = document.getElementsByName('ds_cbk');
    if(ds_cbks && ds_cbks.length > 0)
    {
      for(var n = 0; n < ds_cbks.length; n++)
      {
        if (ds_cbks[n].checked)
        {
          var val = $v('ds_'+ds_cbks[n].value).trim();
          if (val != '')
          {
            if ($v('ds_type_'+ds_cbks[n].value) == 'N')
              from += 'FROM NAMED <' + val + '>\n';
            else 
              from += 'FROM <' + val + '>\n';
          }
        }
      }
    }
    return from;
  }

  this.SchemaTreeRefresh = function(force)
  {
    if (self.schematree.bound.state == 0 && !force)
    return;

    var callback = function(data)
    {
      for(var i = self.schematree.bound.children.length - 1;i >= 0;i--)
        self.schematree.bound.deleteChild(self.schematree.bound.children[i]);
	    var JSONData = eval('(' + data + ')');
	    if (JSONData.results.bindings.length > 0)
	    {
        var objs = JSONData.results.bindings
        for(var i = 0;i < objs.length; i++)
        {
          var node = self.schematree.bound.createChild(self.putPrefix('<' + objs[i].g.value + '>').replace('<','').replace('>',''),1);
          node.setImage('/../../../images/rdf-icon-16');
          node.collapse();
          node.li.uri = objs[i].g.value;
          node.li.uritype = 'schema';
          node.li.bound = true;
          node.label.OATTreeObj = node;
        }
      }
    }
    var params = {
      service:self.service.input.value,
      query:'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>' + '\n' +
            '' + '\n' +
            'SELECT DISTINCT ?g' + '\n' +
            getFromQueryStr() +
            'WHERE { ?s rdf:type ?o .' + '\n' +
            ' GRAPH ?g { ?o rdf:type ?type .' + '\n' +
            '               FILTER (?type in (<http://www.w3.org/1999/02/22-rdf-syntax-ns#Property>)' + '\n' +
            '                    || ?type in (<http://www.w3.org/2002/07/owl#Class>)' + '\n' +
            '                    || ?type in (<http://www.w3.org/2000/01/rdf-schema#Class>)' + '\n' +
            '                    || ?type in (<http://www.w3.org/2002/07/owl#ObjectProperty>)' + '\n' +
            '                    || ?type in (<http://www.w3.org/2002/07/owl#DatatypeProperty>)' + '\n' +
            '                    || ?type in (<http://www.w3.org/2002/07/owl#InverseFunctionalProperty>))' + '\n' +
            '  }' + '\n' +
            '}' + '\n' +
            '',
      //default_graph_uri:,
      maxrows:0,
	    should_sponge:'',
      format:'application/sparql-results+json',
      errorHandler:function(xhr)
      {
        var status = xhr.getStatus();
        var response = xhr.getResponseText();
  			var headers = xhr.getAllResponseHeaders();
        alert(response);
      },
      callback:callback
    }
    iSPARQL.QueryExec(params);
  }
    
  var ds_graph_add = function(){
    self.addDataSource($v('qbe_graph').trim());
    $('qbe_graph').value = '';
    //return;    
    self.SchemaTreeRefresh();
  };

	OAT.Dom.attach("qbe_datasource_graph_add","click",ds_graph_add);
  OAT.Keyboard.add('return',self.func_run,null,null,null,$('qbe_graph'));
	OAT.Dom.attach($('qbe_graph'),"change",function(){
    self.SchemaTreeRefresh();
	});

	icon_datasets = t.addIcon(0,"images/folder_html.png","Dataset",function(){
	  if (self.dataset_win.div.style.display == 'none')
	    OAT.Dom.show(self.dataset_win.div);
	  else
	    OAT.Dom.hide(self.dataset_win.div);
	  l.raise(self.dataset_win.div);
	}); 
	icon_datasets.style.cssFloat = 'right';

	icon_drag.toggleState(1);
	
	/* input field for value editing */
	OAT.Dom.attach("qbe_node_id","keyup",function() {
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
	OAT.Dom.attach("qbe_node_res_type","keyup",function() {
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
	OAT.Dom.attach("qbe_edge_value","keyup",function() {
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
	OAT.Dom.attach("qbe_group_id","keyup",function() {
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
	OAT.Dom.attach("qbe_node_type","change",function() {
		var obj = false;
		if (self.svgsparql.selectedNode) 
		{
		  obj = self.svgsparql.selectedNode; 
		  obj.setType($v('qbe_node_type'));
  		self.svgsparql.selectNode(obj);
		}
	}); 

	/* input field for group type switching */
	OAT.Dom.attach("qbe_group_type","change",function() {
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
  	  self.format_set();
  		self.svgsparql.selectGroup(obj);
		}
	}); 

	OAT.Dom.attach("qbe_query_type","change",function() {
	  self.format_set();
	}); 

	/* input field for node type switching */
	OAT.Dom.attach("qbe_edge_type","change",function() {
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
	OAT.Dom.attach("qbe_visible","change",function() {
		  for(var i = 0;i < self.svgsparql.selectedNodes.length;i++)
		    self.svgsparql.selectedNodes[i].setVisible($("qbe_visible").checked);
		  for(var i = 0;i < self.svgsparql.selectedEdges.length;i++)
		    self.svgsparql.selectedEdges[i].setVisible($("qbe_visible").checked);
		  for(var i = 0;i < self.svgsparql.selectedGroups.length;i++)
		    self.svgsparql.selectedGroups[i].setVisible($("qbe_visible").checked);
	});

	/* obj 'orderby' */
	OAT.Dom.attach("qbe_orderby","change",function() {
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

	/* save */
	dialogs.qbe_save = new OAT.Dialog("Save","qbe_save_div",{width:400,modal:1});
	dialogs.qbe_save.ok = function() {
		self.save($v("qbe_save_name"),$v("qbe_savetype"));
		dialogs.qbe_save.hide();
	}
	dialogs.qbe_save.cancel = dialogs.qbe_save.hide;

	/* file name for saving */
	var fileRef = function() {
	  var path = '/DAV';
	  if (goptions.username)
	    path += "/home/"+goptions.username;
	  var pathDefault = path;
	  if (goptions.username == 'dav')
	    pathDefault = '/DAV';
	    
	  var ext = $v('qbe_savetype');

		var name = OAT.Dav.getNewFile(path,'.' + ext);
		if (!name) { return; }
		if (name.slice(name.length-ext.length - 1).toLowerCase() != "." + ext) { name += "." + ext; }
		$("qbe_save_name").value = name;
	}
	OAT.Dom.attach("qbe_browse_btn","click",fileRef);
	
  this.service = new OAT.Combolist(iSPARQL.defaultEndpoints,"/sparql");
  self.service.img.src = "images/cl.gif";
  $("qbe_service_div").appendChild(self.service.div);
	
	this.RunQuery = function()
	{
	  var params = {
	    service:self.service.input.value,
	    query:self.QueryGenerate(),
	    //default_graph_uri:$v('qbe_graph'),
	    //maxrows:$v('qbe_maxrows'),
	    should_sponge:$v('qbe_sponge'),
	    format:$v('qbe_format'),
	    res_div:$('qbe_res_area'),
      browseCallback:function(query,params){
    	  OAT.Dom.show(self.results_win.div);
    	  l.raise(self.results_win.div);
        self.loadFromString(query);
        //$('qbe_graph').value = params.default_graph_uri;
      },
      browseStart:icon_start,
      browseBack:icon_back,
      browseForward:icon_forward,
      browseFinish:icon_finish,
      prefixes:self.prefixes
	  }
	  OAT.Dom.show(self.results_win.div);
	  l.raise(self.results_win.div);
	  window.scrollTo(0,OAT.Dom.getWH(self.results_win.div)[0] - 40);
    iSPARQL.QueryExec(params);
	}
	
	this.loadFromString = function(data)
	{
	  var findByLabel = function(objs, label) 
	  {
	    for (var i = 0;i < objs.length;i++)
	      if (objs[i].getLabel(1) == label)
	        return i;
	    return -1;
	  }

    var walkSparqlQuery = function(obj,nodes,group)
  	{
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
  	
  	// Starting actual routines
  	try {

	  if (data.match(/<[\w:_ ]+>/))
      var xml = OAT.Xml.createXmlDoc(data);
    else
      var xml = {};
    if (xml.firstChild && xml.firstChild.tagName == 'sparql_design')
    {
  		self.clear();
      self.svgsparql.fromXML(xml);
    } else if (xml.firstChild && xml.getElementsByTagName("iSPARQL").length && xml.getElementsByTagName("sparql_design").length) {
      var isparql_node = xml.getElementsByTagName("iSPARQL")[0];
  		self.clear();
      if (isparql_node.getElementsByTagName("sparql_design").length)
      {
        self.svgsparql.fromXML(isparql_node.getElementsByTagName("sparql_design")[0]);
      }
      
      if (xml.getElementsByTagName("schema").length)
      {
        var schemas = xml.getElementsByTagName("schema");
        for (var i=0;i < schemas.length;i++)
          self.SchemaImport(schemas[i].getAttribute('uri'),1);
      }

      if (xml.getElementsByTagName("should_sponge").length)
      {
        var sponge_node = xml.getElementsByTagName("should_sponge")[0];
        $('qbe_sponge').value = OAT.Xml.textValue(sponge_node);
      }

      if (xml.getElementsByTagName("service").length)
      {
        var service = xml.getElementsByTagName("service")[0];
        self.service.input.value = OAT.Xml.textValue(service);
      }
      
  		for (var i=0;i<self.svgsparql.groups.length;i++)
  		  self.svgsparql.groups[i].MySetType(self.svgsparql.groups[i].getType());

    } else {
      if (xml.firstChild && xml.getElementsByTagName("iSPARQL").length && xml.getElementsByTagName("ISparqlDynamicPage").length) {
        var dyn_page_node = xml.getElementsByTagName("ISparqlDynamicPage")[0];
        var query_node = dyn_page_node.getElementsByTagName("query");
          data = OAT.Xml.textValue(query_node);
      } else if (xml.firstChild && xml.getElementsByTagName("sparql").length) {
        var nodes = xml.getElementsByTagName("sparql");
        for (var i=0;i<nodes.length;i++)
          if (nodes[i].namespaceURI == "urn:schemas-openlink-com:xml-sql")
            data = OAT.Xml.textValue(nodes[i]);
      }
        
      var tmp = data.match(/#should-sponge:(.*)/i)
      if (tmp && tmp.length > 1)
      {
        $('qbe_sponge').value = tmp[1].trim();
      }

      var tmp = data.match(/#service:(.*)/i)
      if (tmp && tmp.length > 1)
      {
        self.service.input.value = tmp[1].trim();
      }

    	var sq = new OAT.SparqlQuery();
    	sq.fromString(data);
  		self.clear();

  		/* prefixes */
  		self.prefixes = sq.prefixes.concat(self.prefixes);
  		self.SchemasReset();
  		for (var i=0;i<sq.prefixes.length;i++)
  		  self.SchemaImport(sq.prefixes[i].uri,1);

      self.SchemaTreeRefresh();

  	  $('qbe_graph').value = '';
  	  if (sq.from instanceof Array)
  	  {
    	  for(var i = 0;i<sq.from.length ;i++)
    	    if (sq.from[i] != '') self.addDataSource(sq.from[i].trim().match(/^<(.*)>$/)[1]);
    	} else
      	if (sq.from)
      	  $('qbe_graph').value = sq.from.trim().match(/^<(.*)>$/)[1];
  
  	  for(var i = 0;i<sq.from_named.length ;i++)
  	    self.addDataSource(sq.from_named.trim().match(/^<(.*)>$/)[1],'N');

  	  $('qbe_distinct').checked = sq.distinct;
  	  
  	  if (sq.describe) $('qbe_query_type').selectedIndex = 1;
  	  else $('qbe_query_type').selectedIndex = 0;
  	  
  	  if (sq.construct)
  	  {
    		var const_nodes = [];
	      var new_group = self.svgsparql.addGroup("",1);
	      new_group.MySetType(OAT.SVGSparqlData.GROUP_CONSTRUCT);
  		  walkSparqlQuery(sq.construct,const_nodes,new_group);
  	  }
  	  
  		var nodes = [];
  		walkSparqlQuery(sq.where,nodes,false);
  		/* orders */
      for (var i=0;i<sq.orders.length;i++)
      {
        var n = findByLabel(self.svgsparql.nodes,'?' + sq.orders[i].variable);
        if(n != -1)
        {
          self.addOrderBy(self.svgsparql.nodes[n]);
          if (sq.orders[i].desc)
            self.svgsparql.nodes[n].orderby_cell.changeSort(OAT.GridData.SORT_DESC);
        }

        var n = self.svgsparql.edges.find('?' + sq.orders[i].variable);
        if(n != -1)
        {
          self.addOrderBy(self.svgsparql.edges[n],1);
          if (sq.orders[i].desc)
            self.svgsparql.edges[n].orderby_cell.changeSort(OAT.GridData.SORT_DESC);
        }

        var n = findByLabel(self.svgsparql.groups,'?' + sq.orders[i].variable);
        if(n != -1)
        {
          self.addOrderBy(self.svgsparql.groups[n]);
          if (sq.orders[i].desc)
            self.svgsparql.groups[n].orderby_cell.changeSort(OAT.GridData.SORT_DESC);
        }
      }
      
  	  self.format_set();
  		self.svgsparql.reposition();
    }
    } catch (e) {
  		self.clear();
      alert('There was an error tring to visualize the query. Please check if the query is valid.');
    }
	}
	
	this.QueryGenerate = function()
	{
    
    var proc_nodes = {};
    var used_prefixes = Array();
    var gc = 0;
    var sc = 0;
    var pc = 0;
    var oc = 0;
  	var sq = new OAT.SparqlQuery();
  	var where;
  	
  	var QueryGenerateProcNode = function(node,sq_grp,sq,group)
  	{

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

		  // We now termine if we need to make pattern for the type
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
        // Lets see if it should be vesable?
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

  	var QueryGenerateProcEdge = function(ptr,edge,sq_grp,sq,group)
  	{
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
      // Lets see if it is visable
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

    // put graph ?g if there isn't one
    //var qbe_graph = $v('qbe_graph').trim();
    //if (qbe_graph == '')
    //{
    //  if (gc > 0) var grph_name = '?g' + gc;
    //  else var grph_name = '?g'; 
    //  gc++; 
    //}

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

  	//if (primary_nodes.length > 1)
  	//{
    //	var sq_un = new OAT.SparqlQueryDataUnion(sq,sq);
  	//	for (var i=0;i < primary_nodes.length;i++)
  	//	{
    //  	var sq_grp = new OAT.SparqlQueryDataGroup(sq_un,sq);
  	//	  sq_un.children.push(QueryGenerateProcNode(primary_nodes[i],sq_grp,sq,false));
    //  }
    //  where = sq_un;
    //} else {
    //  var sq_grp = new OAT.SparqlQueryDataGroup(sq,sq);
    //  where = QueryGenerateProcNode(primary_nodes[0],sq_grp,sq,false);
    //}
    var sq_grp = new OAT.SparqlQueryDataGroup(sq,sq);

    for (var i=0;i < primary_nodes.length;i++)
      QueryGenerateProcNode(primary_nodes[i],sq_grp,sq,false);

		for (var n=0;n < child_groups.length;n++) 
      QueryGenerateProcNode(child_groups[n],sq_grp,sq,child_groups[n]);

    where = sq_grp;

  	sq.where = where;

    var qbe_graph = $v('qbe_graph').trim();
  	var from = [];
  	var named = [];
    	
  	if (qbe_graph != '')
  	  from.push('<' + qbe_graph + '>');

    // get all checked named_graphs from named graphs tab
    var ds_cbks = document.getElementsByName('ds_cbk');
    
    if(ds_cbks && ds_cbks.length > 0)
    {
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
    for (var j=0;j < used_prefixes.length;j = j + 2) 
    {
      sq.prefixes.push({"label":used_prefixes[j],"uri":used_prefixes[j + 1]});
    }
    if ($('qbe_distinct').checked) sq.distinct = true;
    else sq.distinct = false;

    if ($v('qbe_query_type') == 'DESCRIBE') sq.describe = true;
    else sq.describe = false;

    full_query = sq.toString();

    return full_query;
    
	}

	if (window.__inherited) {
  	if (window.__inherited.callback)
  	{
    	/* query returning */
    	var returnRef = function() {
    		window.__inherited.callback(self.QueryGenerate());
    		window.close();
    	}
    	OAT.Dom.attach("qbe_return_btn","click",returnRef);
    }
    else
      OAT.Dom.hide("qbe_return_btn");
    
	} else {
	  self.loadFromString(default_qry);
    $('qbe_graph').value = default_dgu;
    //var node1 = self.svgsparql.addNode(0,0,"?s",1);
    //node1.setType(OAT.SVGSparqlData.NODE_CIRCLE); 
    //var node2 = self.svgsparql.addNode(0,0,"?o",1);
    //node2.setType(OAT.SVGSparqlData.NODE_CIRCLE); 
    //var edge  = self.svgsparql.addEdge(node1,node2,"?p",1);	
    OAT.Dom.hide("qbe_return_btn");
  }
}