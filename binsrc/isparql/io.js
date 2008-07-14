/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2008 OpenLink Software
 *
 *  See LICENSE file for details.
 *
 * dataObj 
 * 		   -> data: query data/results if any
 * 		   -> query: query text
 * 		   -> endpoint: data endpoint
 * 		   -> defaultGraph: default graph to select from
 * 		   -> schemas: schema list
 * 		   -> pragmas: object with current virtuoso pragmas
 * 		   -> canvas: current canvas state
 */

var iSPARQL = {
	dataObj:{
		data:false,
		query:"",
		endpoint:"",
		defaultGraph:"",
		graphs:[],
		namedGraphs:[],
		prefixes:[],			/* FIXME: prefixes? */
		pragmas:[],
		canvas:false
	}
};

iSPARQL.Preferences = {
	xslt:'/DAV/JS/isparql/xslt/',
	debug:false
}

iSPARQL.IO = {
	/* serialize current query to plain string 
 	 * format is"
 	 * # pragma { name } = { value }
 	 * # endpoint
 	 * # graph
 	 * query text
 	 */
	serializeRq:function(dataObj) {//{{{
		var str = "";
		
		/* serialize pragmas, inserted as sparql comments */
		for (var i=0;i<dataObj.pragmas.length;i++) {
			var pragma = dataObj.pragmas[i];
			var name = pragma[0];
			var values = pragma[1];
			for(var j=0;j<values.length;j++) { str += '# {pragma} {'+name+'} = {'+values[j]+'}\n'; }
		}

		/* endpoint */
		if (dataObj.endpoint) {	str += '# {endpoint} {'+dataObj.endpoint+'}\n';	}
		if (dataObj.defaultGraph) { str += '# {graph} {'+dataObj.defaultGraph+'}\n'; }
		str += dataObj.query;
		return str;
	},//}}}

	serializeLdr:function(dataObj) {//{{{
		var xslt = iSPARQL.Preferences.xslt + 'dynamic-page.xsl';
    	var xmlTemplate  =  '<?xml version="1.0" encoding="UTF-8"?>\n'+
        					'<?xml-stylesheet type="text/xsl" href="' + xslt + '"?>\n'+
  							'<iSPARQL xmlns="urn:schemas-openlink-com:isparql">\n'+
  							'<ISparqlDynamicPage>\n'+
  							'</ISparqlDynamicPage>\n'+
  							'</iSPARQL>';
		var xml = OAT.Xml.createXmlDoc(xmlTemplate);
		var page = xml.getElementsByTagName("ISparqlDynamicPage")[0];
		var isparql = xml.getElementsByTagName("iSPARQL")[0];

		var addNode = function(p,name,text) {
			var node = xml.createElement(name);
			var t = text || "";
			node.textContent = OAT.Dom.toSafeXML(t);
			p.appendChild(node);
			return node;
		}

		if(dataObj.defaultGraph) { addNode(page,"graph",dataObj.defaultGraph); }
		if(dataObj.proxy) { addNode(page,"proxy",dataObj.proxy); }
		if(dataObj.query) { addNode(page,"query",dataObj.query); }

		if(dataObj.prefixes) { 
			var schemas = addNode(page,"schemas");
			for(var i=0;i<dataObj.prefixes.length;i++) {
				var schemaNode = dataObj.prefixes[i];
				addNode(schemas,"schema",schemaNode);
			} 
		}

		if(dataObj.pragmas) {
			var pragmas = addNode(isparql,"pragmas");
			for(var i=0;i<dataObj.pragmas.length;i++) {
				var pragma = dataObj.pragmas[i];
				var name = pragma[0];
				var values = pragma[1];
				var pragmaNode = addNode(pragmas,"pragma");
				addNode(pragmaNode,"name",name);
				for(var j=0;j<values.length;j++) { addNode(pragmaNode,"value",values[j]); }
			}
		}

		if(dataObj.service) { addNode(isparql,"service",dataObj.service); }
  		if(dataObj.canvas) { addNode(isparql,"canvas",dataObj.canvas); }
	
		return OAT.Xml.serializeXmlDoc(xml);
	},//}}}

	serializeXml:function(dataObj) {//{{{
		var xmlTemplate = '<?xml version="1.0" encoding="UTF-8"?>\n'+
						  '<root xmlns:sql="urn:schemas-openlink-com:xml-sql">\n'+
						  '<sql:sparql></sql:sparql>\n'+
  						  '</root>';
		var xml = OAT.Xml.createXmlDoc(xmlTemplate);

		var root = xml.getElementsByTagName("root")[0];
		if(dataObj.defaultGraph) { root.setAttribute('sql:default-graph-uri',OAT.Dom.toSafeXML(dataObj.defaultGraph)); }

		var sql = xml.getElementsByTagName("sparql")[0];
		sql.textContent = OAT.Dom.toSafeXML(dataObj.query);

		return OAT.Xml.serializeXmlDoc(xml);
	},//}}}

	serializeRdf:function(dataObj) {//{{{
		return OAT.Xml.serializeXmlDoc(dataObj.data);	
	},//}}}

	unserializeRq:function(str) {//{{{
		var dataObj = {
			endpoint:false,
			graph:false,
			query:"",
			pragmas:[]
		};
			
		var getEndpoint = function(str) {
			var m = str.match(/^\s*#\s*{endpoint}\s*{(.*?)}/);
			return (m)? m[1] : false;
		}

		var getPragma = function(str) {
			var m = str.match(/^\s*#\s*{pragma}\s*{(.*?)}\s*=\s*{(.*?)}/);
			return m || [];
		}
		
		var getGraph = function(str) {
			var m = str.match(/^\s*#\s*{graph}\s*{(.*?)}/);
			return (m)? m[1] : false;
		}

		var isComment = function(str) {
			return str.match(/^\s*#/);
		}

		var isBlank = function(str) {
			return str.match(/^\s*$/);
		}

		var lines = str.split(/\n/);
		var pragmas = [];
		for (var i=0;i<lines.length;i++) {
			var line = lines[i];

			var p = getPragma(line);
			if(p) { 
				var index = -1;
				for(var j=0;j<pragmas.length;j++) {
					if(pragmas[j][0] == p[0]) { index = j; break; }
				}
				if (index == -1) { dataObj.pragmas.push(p); }
				else { dataObj.pragmas[index][1].push(p[1]); }
			}
			dataObj.endpoint = getEndpoint(line);
			dataObj.defaultGraph = getGraph(line);

			if(!isBlank(line) && !isComment(line)) { dataObj.query += line + '\n';	}
		}
		return dataObj;
	},//}}}

	unserializeXml:function(str) {//{{{
		var dataObj = {
			graph:false,
			query:"",
		};

		var xml = OAT.Xml.createXmlDoc(str);
		var q = xml.getElementsByTagName("sparql")[0];
		var r = xml.getElementsByTagName("root")[0];

		if(q) { dataObj.query = OAT.Dom.fromSafeXML(q.textContent) || ""; }
		if(r) { dataObj.graph = r.getAttribute('sql:default-graph-uri') || false; }

		return dataObj;
	},//}}}

	unserializeLdr:function(str) {//{{{
		var dataObj = {
			graph:false,
			schemas:[],
			pragmas:[],
			query:false,
			proxy:false
		};

		var getNodeValue = function(node,name) {
			var n = node.getElementsByTagName(name)[0];
			return (n)? OAT.Dom.fromSafeXML(n.textContent) : false;
		}

		var xml = OAT.Xml.createXmlDoc(str);

		dataObj.defaultGraph = getNodeValue(xml,"graph");
		dataObj.proxy = getNodeValue(xml,"proxy");
		dataObj.query = getNodeValue(xml,"query");

		var schemas = xml.getElementsByTagName("schemas");
		for (var i=0;i<schemas.length;i++) {
			var schema = OAT.Dom.fromSafeXML(schemas[i]);
			dataObj.prefixes.push(schema);
		}

		var pragmas = xml.getElementsByTagName("pragma");
		for (var i=0;i<pragmas.length;i++) {
			var pnode = pragmas[i];
			var p = getNodeValue(pnode,"name");
			var v = pnode.getElementsByTagName("value");

			var index = -1;
			for(var j=0;j<dataObj.pragmas.length;j++) {
				if(dataObj.pragmas[j][0] == p) { index = j; break; }
			}
			
			if (index == -1) { dataObj.pragmas.push([p,v]); }
			else { for(var j=0;j<v.length;j++) { dataObj.pragmas[index][1].push(v[j]); } }
		}

		return dataObj;
	},//}}}

	serialize:function(dataObj,type) {//{{{
		switch(type) {
			default:
			case "rq":
				return this.serializeRq(dataObj);
			break;
			
			case "xml":
				return this.serializeXml(dataObj);
			break;
	
			case "ldr":
			case "isparql":
				return this.serializeLdr(dataObj);
			break;

			case "rdf":
				return this.serializeRdf(dataObj);
			break;
		}
	},//}}}

	unserialize:function(str,type) {//{{{
		switch(type) {
			default:
			case "rq":
				return this.unserializeRq(str);
			break;
			
			case "xml":
				return this.unserializeXml(str);
			break;
	
			case "ldr":
			case "isparql":
				return this.unserializeLdr(str);
			break;
		}
	},//}}}

	save:function(dataObj) {//{{{
		var options = {
			extensionFilters:[
				['rq','rq','SPARQL Definitions','text/plain'],
    		    ['isparql','isparql','Dynamic Linked Data Page','text/xml'],
    		    ['ldr','ldr','Dynamic Linked Data Resource','text/xml'],
				['rdf','rdf','RDF Data','application/xml'],
    		    ['xml','xml','XML Server Page','text/xml']
			],
			callback:function(){},
			dataCallback:function(file,ext) {
				return iSPARQL.IO.serialize(dataObj,ext);
			}
		}

		OAT.WebDav.saveDialog(options);
	},//}}}

	load:function(callback) {//{{{
		var options = {
			extensionFilters:[
				['rq','rq','SPARQL Definitions','text/plain'],
    		    ['isparql','isparql','Dynamic Linked Data Page','text/xml'],
    		    ['ldr','ldr','Dynamic Linked Data Resource','text/xml'],
    		    ['xml','xml','XML Server Page','text/xml'],
    		    ['','*','All files','']
			],
			dataCallback:function(){},
			callback:function(path,file,data) {
				var m = file.match(/\.(\w+)$/);
				var ext = (m)? m[1] : "xml";
				var o = iSPARQL.IO.unserialize(data,ext);
				if (callback) { callback(path,file,o) };
			}
		}

		OAT.WebDav.openDialog(options);
	}//}}}
}

/* vim:set foldmethod=marker: */
