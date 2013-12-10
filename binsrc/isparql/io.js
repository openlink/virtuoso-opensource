/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2009-2013 OpenLink Software
 *
 *  See LICENSE file for details.
 *
 * dataObj
 * 		   -> data: query data/results if any
 * 		   -> query: query text
 * 		   -> endpointOpts: data endpoint options object
 * 		   -> defaultGraph: default graph to select from
 * 		   -> schemas: schema list
 * 		   -> pragmas: object with current virtuoso pragmas
 * 		   -> canvas: current canvas state
 *		   -> metaDataOpts: creator, title, description (,etc.)
 */


iSPARQL.IO = {
    /* serialize current query to plain string
     * format is"
     * # pragma { name } = { value }
     * # endpoint
     * # graph
     * query text
     */
    serializeRq:function(dataObj) {
	var str = "";

	/* serialize pragmas, inserted as sparql comments */
	if (dataObj.endpointOpts.pragmas)
	    for (var i=0;i<dataObj.endpointOpts.pragmas.length;i++) {
		var pragma = dataObj.endpointOpts.pragmas[i];
		var name = pragma[0];
		var values = pragma[1];
		for(var j=0;j<values.length;j++) { 
		    str += '# {pragma} {'+name+'} = {'+values[j]+'}\n'; }
	    }

	/* endpoint */

	if (dataObj.endpointOpts.endpointPath) {
	    str += '# {endpoint} {'+dataObj.endpointOpts.endpointPath+'}\n';
	}

	/* graph */
	if (dataObj.defaultGraph) { str += '# {graph} {'+dataObj.defaultGraph+'}\n'; }

	/* named graph */
	for (var i=0;i<dataObj.namedGraphs.length;i++) {
	    str += '# {named graph} {' + dataObj.namedGraphs[i] + '}\n';
	}

	if (dataObj.maxrows && dataObj.maxrows != 0) {
            str += '# {maxrows} {' + dataObj.maxrows + '}\n';
	}

	str += dataObj.query;
	return str;
    },

    serializeLdr:function(dataObj) {
		var xslt = iSPARQL.Settings.xslt + 'dynamic-page.xsl';
	var iNS = "urn:schemas-openlink-com:isparql";
	var xmlTemplate = '<?xml version="1.0" encoding="UTF-8"?>\n'+
	'<?xml-stylesheet type="text/xsl" href="' + xslt + '"?>\n'+
	'<iSPARQL xmlns="' + iNS + '"\n' +
	'         xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"\n'+
	'         xmlns:dc="http://purl.org/dc/elements/1.1/"\n'+
	'         xmlns:ex="http://example.org/stuff/1.0/">\n'+
	'<rdf:Description about="#this">\n'+
	'  <dc:title></dc:title>\n'+
	'  <dc:creator></dc:creator>\n'+
	'  <dc:description></dc:description>\n'+
	'</rdf:Description>\n'+
	'<ISparqlDynamicPage>\n'+
	'</ISparqlDynamicPage>\n'+
	'</iSPARQL>';

	var xml = OAT.Xml.createXmlDoc(xmlTemplate);

	var page =        OAT.Xml.getElementsByLocalName(xml,"ISparqlDynamicPage")[0];
	var isparql =     OAT.Xml.getElementsByLocalName(xml,"iSPARQL")[0];
	var title =       OAT.Xml.getElementsByLocalName(xml,"title")[0];
	var creator =     OAT.Xml.getElementsByLocalName(xml,"creator")[0];
	var description = OAT.Xml.getElementsByLocalName(xml,"description")[0];

	var addNode = function(p,ns,name,text,nenc) {
	    var node;
	    var t = text || "";

	    if (OAT.Browser.isIE) {
		node = xml.createElement(name)

		if (nenc) {
		    node.text = t;
		}
		else {
		    node.text = OAT.Dom.toSafeXML(t);
		}
	    }
	    else {
		node = xml.createElementNS(ns,name);
	    if (nenc) {
		node.textContent = t;
            }
            else {
		node.textContent = OAT.Dom.toSafeXML(t);
            }
	    }
	    p.appendChild(node);
	    return node;
	}

	if (dataObj.defaultGraph) { addNode(page,iNS,"graph",dataObj.defaultGraph); }
	if (dataObj.useProxy) { addNode(page,iNS,"proxy",dataObj.useProxy); }

        var qn;

	if (dataObj.query) {
          qn = addNode(page,iNS,"query",dataObj.query,true);
 	    if (dataObj.maxrows) { 
		if (OAT.Browser.isIE)
		    qn.setAttribute ('maxrows', dataObj.maxrows.toString());
		else
		    qn.setAttributeNS (iNS, 'maxrows', dataObj.maxrows.toString()); 
	    }
        }
	if (dataObj.prefixes) {
	    var schemas = addNode(page, iNS, "schemas");
	    for(var i=0;i<dataObj.prefixes.length;i++) {
		var schemaNode = dataObj.prefixes[i];
		addNode(schemas,iNS,"schema",schemaNode);
	    }
	}

	if(dataObj.namedGraphs) {
	    var namedgraphs = addNode(page,iNS,"namedgraphs");
	    for(var i=0;i<dataObj.namedGraphs.length;i++) {
		var graphNode = dataObj.namedGraphs[i];
		addNode(namedgraphs,iNS,"namedgraph",graphNode);
	    }
	}

	if(dataObj.endpointOpts.pragmas) {
	    var pragmas = addNode(isparql,iNS,"pragmas");
	    for(var i=0;i<dataObj.endpointOpts.pragmas.length;i++) {
		var pragma = dataObj.endpointOpts.pragmas[i];
		var name = pragma[0];
		var values = pragma[1];
		var pragmaNode = addNode(pragmas,iNS,"pragma");
		addNode(pragmaNode,iNS,"name",name);
		for(var j=0;j<values.length;j++) {
		    addNode(pragmaNode,iNS,"value",values[j]);
		}
	    }
	}

	if (dataObj.endpointOpts.endpointPath) {
	    addNode(isparql,iNS,"endpoint",dataObj.endpointOpts.endpointPath);
	}

	if (dataObj.canvas) { addNode(isparql,iNS,"canvas",dataObj.canvas); }

	if (dataObj.metaDataOpts) {
	    if (OAT.Browser.isIE) {
		title.text       = OAT.Dom.toSafeXML(dataObj.metaDataOpts.title);
		creator.text     = OAT.Dom.toSafeXML(dataObj.metaDataOpts.creator);
		description.text = OAT.Dom.toSafeXML(dataObj.metaDataOpts.description);
	    } else {
	    title.textContent = OAT.Dom.toSafeXML(dataObj.metaDataOpts.title);
	    creator.textContent = OAT.Dom.toSafeXML(dataObj.metaDataOpts.creator);
	    description.textContent = OAT.Dom.toSafeXML(dataObj.metaDataOpts.description);
	}
	}	

	return OAT.Xml.serializeXmlDoc(xml);
    },

    serializeXml:function(dataObj) {
	var xmlTemplate = '<?xml version="1.0" encoding="UTF-8"?>\n'+
	'<root xmlns:sql="urn:schemas-openlink-com:xml-sql">\n'+
	'<sql:sparql></sql:sparql>\n'+
	'</root>';
	var xml = OAT.Xml.createXmlDoc(xmlTemplate);

	var root = xml.getElementsByTagName("root")[0];

	if (dataObj.defaultGraph)
	    root.setAttribute('sql:default-graph-uri',OAT.Dom.toSafeXML(dataObj.defaultGraph));

	var sql = xml.getElementsByTagName("sparql")[0];
	sql.textContent = OAT.Dom.toSafeXML(dataObj.query);

	return OAT.Xml.serializeXmlDoc(xml);
    },

    serializeRdf:function(dataObj) {
	return OAT.Xml.serializeXmlDoc(dataObj.data);
    },

    unserializeRq:function(str) {
	var dataObj = {
	    endpoint:"",
	    defaultGraph:"",
	    namedGraphs:[],
	    query:"",
	    	maxrows:0,
	    pragmas:[]
	};

	var getEndpoint = function(str) {
	    var m = str.match(/^\s*#\s*{endpoint}\s*{(.*?)}/);
	    return (m)? m[1] : false;
	}

	var getPragma = function(str) {
	    var m = str.match(/^\s*#\s*{pragma}\s*{(.*?)}\s*=\s*{(.*?)}/);
	    return (m) ? m : false;
	}

	var getGraph = function(str) {
	    var m = str.match(/^\s*#\s*{graph}\s*{(.*?)}/);
	    return (m)? m[1] : false;
	}

	var getNamedGraph = function(str) {
	    var m = str.match(/^\s*#\s*{named graph}\s*{(.*?)}/);
	    return (m)? m[1] : false;
	}

        var getMaxRows = function (str) {
	    var m = str.match(/^\s*#\s*{maxrows}\s*{(.*?)}/);
            return (m)? m[1] : false;
        }


	var isComment = function(str) {
	    return str.match(/^\s*#/);
	}

	var isBlank = function(str) {
	    return str.match(/^\s*$/);
	}

	var lines = str.split(/\n/);
	for (var i=0;i<lines.length;i++) {
	    var line = lines[i];

	    var p = getPragma(line);
	    if (p) {
		var index = -1;
		for(var j=0;j<dataObj.pragmas.length;j++) {
		    if(dataObj.pragmas[j][0] == p[0]) { index = j; break; }
		}
		if (index == -1) { dataObj.pragmas.push(p); }
		else { dataObj.pragmas[index][1].push(p[1]); }
		continue;
	    }

	    p = getEndpoint(line);
	    if (p) {
		dataObj.endpoint = p;
		continue;
	    }

	    p = getGraph(line);
	    if (p) {
		dataObj.defaultGraph = p;
		continue;
	    }

	    p = getNamedGraph(line);
	    if (p) {
		dataObj.namedGraphs.push(p);
		continue;
	    }

	    p = getMaxRows(line);

	    if (p) {
		data.maxrows = parseInt(p);
		continue;
            }

	    if(!isBlank(line) && !isComment(line)) {
		dataObj.query += line + '\n';
	    }
	}
	return dataObj;
    },

    unserializeXml:function(str) {
	var dataObj = { defaultGraph:"", query:"" };

	var xml = OAT.Xml.createXmlDoc(str);
	var q = xml.getElementsByTagName("sparql")[0];
	var r = xml.getElementsByTagName("root")[0];

	if(q) { dataObj.query = OAT.Dom.fromSafeXML(q.textContent) || ""; }
	if(r) { dataObj.defaultGraph = r.getAttribute('sql:default-graph-uri') || false; }

	return dataObj;
    },

    unserializeLdr:function(str) {
	var dataObj = {
	    defaultGraph:"",
	    graph:false,
	    schemas:[],
	    pragmas:[],
	    prefixes:[],
	    namedGraphs:[],
	    endpoint:"/sparql",
	    query:false,
	    useProxy:false,
	    metaDataOpts:{}
	};

	var getNodeValue = function(node,name) {
	    var n = node.getElementsByTagName(name)[0];
	    return (n)? OAT.Dom.fromSafeXML(n.textContent) : "";
	}

	var xml = OAT.Xml.createXmlDoc(str);

	dataObj.defaultGraph = getNodeValue(xml,"graph");
	if (!dataObj.defaultGraph) dataObj.defaultGraph = '';

	dataObj.endpoint = getNodeValue(xml,"endpoint");
	if (!dataObj.endpoint) dataObj.endpoint = "/sparql";

	dataObj.useProxy = getNodeValue(xml,"proxy");

	dataObj.query = getNodeValue(xml,"query");

	dataObj.maxrows = xml.getElementsByTagName ("query").getAttribute("maxrows");

	var schemas = xml.getElementsByTagName("schemas");

	for (var i=0;i<schemas.length;i++) {
	    var schema = OAT.Dom.fromSafeXML(schemas[i]);
	    dataObj.prefixes.push(schema);
	}

	var namedgraphs = xml.getElementsByTagName("namedgraph");
	for (var i = 0; i < namedgraphs.length; i++) {
	    var graphnode = OAT.Dom.fromSafeXML(namedgraphs[i].firstChild.nodeValue);
	    dataObj.namedGraphs.push(graphnode);
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

	var rdf_desc = xml.getElementsByTagName("rdf:Description")[0];
	dataObj.metaDataOpts.title = getNodeValue(rdf_desc,"dc:title");
	dataObj.metaDataOpts.description = getNodeValue(rdf_desc,"dc:description");
	dataObj.metaDataOpts.creator = getNodeValue(rdf_desc,"dc:creator");

	return dataObj;
    },

    serialize:function(dataObj,type) {
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
    },

    unserialize:function(str,type) {
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
    },

    save:function(dataObj) {
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
    },

    load:function(callback) {
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
    }
}
