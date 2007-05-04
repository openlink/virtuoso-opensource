/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2007 OpenLink Software
 *  
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *  
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *  
 *  
*/

window.iSPARQL = {
  LoadJSON2Grid:function (grid,JSONData,params)
  {
    var cells = Array();
    var headers = Array();
    var binding = '';
    // make the header
    for(var h = 0;h < JSONData.head.vars.length;h++)
    {
      if (params.replace_headers && params.replace_headers.find(JSONData.head.vars[h]) != -1)
        var label = params.replace_headers[params.replace_headers.find(JSONData.head.vars[h]) + 1];
      else 
        var label = JSONData.head.vars[h];
      cells.push({value:label,align:OAT.GridData.ALIGN_CENTER});
      headers.push(JSONData.head.vars[h]);
    }
    grid.createHeader(cells);
  
    var putPrefix = function(str) 
    {
      var tmp = '';
      if (str == 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type')
        return 'a';
      for(var i = 0;i < params.prefixes.length; i++)
        if (str.substring(0,params.prefixes[i].uri.length) == params.prefixes[i].uri)
          return params.prefixes[i].label + ':' + str.substring(params.prefixes[i].uri.length);
      return str;
    }
    
    var URIClick = function(anchor,click_type){
      var new_query;
    	var from = '';
  
    	if (params.default_graph_uri.trim() == '')
    	{
      	var sq = new OAT.SparqlQuery();
      	sq.fromString(params.query);
  
      	//from = 'FROM ' + sq.from + '\n';
        // from	    
    	  if (sq.from instanceof Array)
    	  {
      	  for(var i = 0;i<sq.from.length ;i++)
      	    if (sq.from[i] != '') from += 'FROM ' + sq.from[i] + '\n';
      	} else
      	  if (sq.from != '') from += 'FROM ' + sq.from + '\n';
    
    	  for(var i = 0;i<sq.from_named.length ;i++)
    	    from += 'FROM NAMED ' + sq.from_named[i] + '\n';
    	}
    	
    	params.should_sponge = '';
  	  if (click_type)
    	params.default_graph_uri = '';
  	  if (click_type == 1)
  	  {
  	    //if (sq.from instanceof Array && sq.from.find('<' + anchor.uri + '>') == -1)
  	    //  from += 'FROM <' + anchor.uri + '>\n';
  	      from = 'FROM <' + anchor.uri + '>\n';
  	    new_query = 'SELECT *\n' +
  	                from +
                    'WHERE {?s ?p ?o}\n';
      	params.should_sponge = 'soft';
  	  }
  	  else if (click_type == 2)
  	  {
  	      from = 'FROM <' + anchor.uri + '>\n';
  	    new_query = 'SELECT distinct ?class\n' +
  	                from +
                    'WHERE {[] a ?class}\n';
      	params.should_sponge = '';
  	  }
  	  else if(anchor.header && anchor.header.toLowerCase() == 'property')
  	  {
  	    new_query = 'SELECT ?resource ?value\n' +
  	                from +
                    'WHERE { ?resource <' + anchor.uri + '> ?value }\n' + 
                    'ORDER BY ?resource ?value\n';
    	} else {
  	    new_query = 'SELECT ?property ?hasValue ?isValueOf\n' +
  	                from +
                    'WHERE {\n' + 
                    '  { <' + anchor.uri + '> ?property ?hasValue }\n' + 
                    '  UNION\n' + 
                    '  { ?isValueOf ?property <' + anchor.uri + '> }\n' + 
                    '}\n';
    	}
    	params.query = new_query;
    	params.nav_index++;
    	params.nav_stack.splice(params.nav_index,params.nav_stack.length);
    	params.nav_stack.push({ query:new_query,
    	                        default_graph_uri:params.default_graph_uri,
    	                        format:params.format});
      iSPARQL.QueryExec(params);
      params.browseCallback(new_query,params);
    }
    
    var drawAnchor = function (anchor) 
    {
  		var ul = OAT.Dom.create("ul",{paddingLeft:"20px",marginLeft:"0px"});
  		var li1 = OAT.Dom.create("li");
  		var a1 = OAT.Dom.create("a");
  		a1.innerHTML = "Explore";
  		a1.href = "javascript:void(0)";
  
  		//var li4 = OAT.Dom.create("li");
  		//var a4 = OAT.Dom.create("a");
  		//a4.innerHTML = "Get Classes";
  		//a4.href = "javascript:void(0)";
  		
  		var hr1 = OAT.Dom.create("hr");
  		
  		var li2 = OAT.Dom.create("li");
  		var a2 = OAT.Dom.create("a");
  		a2.innerHTML = "Get Data Set (Dereference)";
  		a2.href = "javascript:void(0)";
  
  		var li3 = OAT.Dom.create("li");
  		var a3 = OAT.Dom.create("a");
  		a3.innerHTML = "Get Data Set (Dereference) in new window";
  		a3.href = "javascript:void(0)";
  
  		var hr2 = OAT.Dom.create("hr");

  		var li5 = OAT.Dom.create("li");
  		var a5 = OAT.Dom.create("a");
  		a5.innerHTML = "(X)HTML Page Open";
  		a5.target = "_blank";
  		a5.href = anchor.uri;

  		OAT.Dom.append([ul,li1,/*li4,*/hr1,li2,li3,hr2,li5],[li1,a1],/*[li4,a4],*/[li2,a2],[li3,a3],[li5,a5]);
  
  		OAT.Dom.attach(a1,"click",function() {
  			OAT.AnchorData.window.close();
  			URIClick(anchor);
  		});
  		//OAT.Dom.attach(a4,"click",function() {
  		//	OAT.AnchorData.window.close();
  		//	URIClick(anchor,2);
  		//});
  		OAT.Dom.attach(a2,"click",function() {
  			OAT.AnchorData.window.close();
  			URIClick(anchor,1);
  		});
  		OAT.Dom.attach(a3,"click",function() {
  			OAT.AnchorData.window.close();
  
    		var obj = {};
    		obj.username = goptions.username;
    		obj.password = goptions.username;
    		obj.endpoint = goptions.service;
    		obj.login_put_type = goptions.login_put_type;
    		obj.proxy = goptions.proxy;
    		obj.should_sponge = goptions.should_sponge;
    		obj.query = 'select * where {?s ?p ?o}';
    		obj.graph = anchor.uri;
    		obj.run = 1;
    		var w = window.open(location.protocol + '//' + location.host + location.pathname + '?dereference-uri=' + encodeURIComponent(anchor.uri));
    		w.__inherited = obj;
  		});
  
  		var obj = {
  			title:"URL",
  			activation:"click",
  			content:ul,
  			width:0,
  			height:0,
  			result_control:false,
  			newHref:'#' + anchor.uri
  		};
  		OAT.Anchor.assign(anchor,obj);
    }
  
    // make the rows
    for(var r = 0;r < JSONData.results.bindings.length;r++)
    {
      var row = grid.createRow([]);
      var idx = grid.rows.length - 1;
      for(var c = 0;c < headers.length;c++)
      {
        var cell;
        if (JSONData.results.bindings[r][headers[c]])
        {
          binding = JSONData.results.bindings[r][headers[c]];
          var value = binding.value;
          // We check and normalize the content here 
          if (value.match(/<.*/))
          {
            value = value.replace(/<script.*?\/>/ig,'');
            value = value.replace(/<script.*?>.*?<\/script>/ig,'');
            value = value.replace(/<[^>]*="javascript:[^"]*"[^>]*>/ig,'');
          }
          if (binding.type == 'uri' || value.match(/^http:\/\/.*/))
          {
            cell = grid.rows[idx].addCell({value:value});
        		var a = OAT.Dom.create("a");
        		a.innerHTML = putPrefix(value);
        		a.href = value;
        		cell.innerHTML = '';
        		OAT.Dom.append([cell,a]);
            a.uri = value;
            a.header = headers[c];
          	//OAT.Dom.attach(cell.firstChild,"click",URIClick);
          	OAT.Dom.attach(cell.firstChild,"dblclick",URIClick);
          	drawAnchor(a);
          } else if (value.match(/<a/)) {
            cell = grid.rows[idx].addCell({value:value});
            anchors = cell.getElementsByTagName("a");
            for(var i=0;i<anchors.length;i++)
            {
              var tmp = anchors[i];
              tmp.uri = tmp.href;
          	  drawAnchor(tmp);
            }
          } else
            cell = grid.rows[idx].addCell({value:value});
        }
        else
          cell = grid.rows[idx].addCell('');
      }
      
    }
  
  },

  defaultEndpoints:["/sparql",
                    "http://demo.openlinksw.com/sparql",
                    "http://myopenlink.net:8890/sparql/",
                    "http://xmlarmyknife.org/api/rdf/sparql/query",
                    "http://www.sparql.org/sparql",
                    "http://www.govtrack.us/sparql",
                    "http://abdera.watson.ibm.com:8080/sparql",
                    "http://km.aifb.uni-karlsruhe.de/services/sparql/SPARQL",
                    "http://jena.hpl.hp.com:3040/backstage",
                    "http://my.opera.com/community/sparql/sparql",
                    "http://www.wasab.dk/morten/2005/04/sparqlette/"],


  QueryExec:function(paramsObj)
  {
    // We use this to fix IE visualization problems with pre content
    var putTextInPre = function(elm,txt){
      if (OAT.Dom.isIE()) 
        txt = txt.replace(/\r\n/g,'\r').replace(/\n/g,'\r');
      OAT.Dom.append([elm,OAT.Dom.text(txt)]);
    }

  	var params = {
  		service:goptions.service,               // The sparql endpoint to send the query to
  		default_graph_uri:'',                   // Default graph
  		query:'',                               // The query itself
  		res_div:$('res_area'),                  // DIV where to put the results
  		format:'text/html',                     // Sets format to the request and process the results accordinglly.
  		should_sponge:goptions.should_sponge,   // should-sponge param - as described in Virtuoso Docs.
  		maxrows:0,                              // sets maxrows params to the endpoint, 0 for nolimit /limit left to server/
  		proxy:goptions.proxy,                   // If the endpoint is http: ... and this is set, the request would be send to './remote.vsp'
  		named_graphs:[],                        // Array of named graphs to send to the endpoint
  		prefixes:[], // {"label":'rdf', "uri":'http://www.w3.org/1999/02/22-rdf-syntax-ns#'} // those are used when showing results
  		imagePath:'images/',
  		errorHandler:function(xhr)              // function called when the endpoint returns error
      {
        var status = xhr.getStatus();
        var response = xhr.getResponseText();
  			var headers = xhr.getAllResponseHeaders();
  			var data = '';
        if (!response)
        {
          data = 'There was a problem with your request! The server returned status code: ' + status + '<br/>\n';
          data += 'Unfortunately your browser does not allow us to show the error. ';
          data += 'This is a known bug in the Opera Browser.<br/>\n';
          data += 'However you can click this link which will open a new window with the error: <br/>\n';
          data += '<a target="_blank" href="/sparql/?' + body() + '">/sparql/?' + body() + '</a>';
        }
        else 
        {
          data = response.replace(/&/g,'&amp;').replace(/</g,'&lt;');
        }
        params.callback('<pre>' + data + '</pre>',headers,'er');
      },
  		browseCallback:function(query,params){},// 
  		browseStart:false, // sets blur to this object
  		browseBack:false,  // sets blur to this object
  		browseForward:false, // sets blur to this object
  		browseFinish:false,  // sets blur to this object
  		hideRequest:false,  // if true hides the request tab in the generated responce
  		hideResponce:false, // if true hides the responce tab in the generated responce
  		showQuery:false,    // if true shows the query tab in the generated responce
      //RESULT PROCESSING
      callback:function(data,headers,param)  // function called on result
      {
        // Clear the tabls
        OAT.Dom.clear(params.res_div);
        
        // Make the tabs 
        var tabres_ul = OAT.Dom.create("ul");
        tabres_ul.className = "tabres";

        var tabres_li_formats = OAT.Dom.create("li");
        tabres_li_formats.className = "nav_right";
        OAT.Dom.append([tabres_ul,tabres_li_formats]);
        // We have to change params.format on each interaction in order to change the param 
        var format_orig = params.format;
        if ((params.query.match(/construct/i) || params.query.match(/describe/i)))
        {
          var a_n3 = OAT.Dom.create("a");
          a_n3.innerHTML = 'N3/Turtle';
          a_n3.target = '_blank';
          params.format = 'text/rdf+n3';
          a_n3.href = params.service + '?' + body();
          var a_rdf = OAT.Dom.create("a");
          a_rdf.innerHTML = 'RDF/XML';
          a_rdf.target = '_blank';
          params.format = 'application/rdf+xml';
          a_rdf.href = params.service + '?' + body();
          OAT.Dom.append([tabres_li_formats,a_n3,a_rdf]);
        } else {
          var a_xml = OAT.Dom.create("a");
          a_xml.innerHTML = 'XML';
          a_xml.target = '_blank';
          params.format = 'application/sparql-results+xml';
          a_xml.href = params.service + '?' + body();
          var a_json = OAT.Dom.create("a");
          a_json.innerHTML = 'JSON';
          a_json.target = '_blank';
          params.format = 'application/sparql-results+json';
          a_json.href = params.service + '?' + body();
          var a_js = OAT.Dom.create("a");
          a_js.innerHTML = 'JavaScript';
          a_js.target = '_blank';
          params.format = 'application/javascript';
          a_js.href = params.service + '?' + body();
          var a_html = OAT.Dom.create("a");
          a_html.innerHTML = 'HTML';
          a_html.target = '_blank';
          params.format = 'text/html';
          a_html.href = params.service + '?' + body();
          OAT.Dom.append([tabres_li_formats,a_xml,a_json,a_js,a_html]);
        }
        params.format = format_orig;
        

        var tabres_li_result = OAT.Dom.create("li");
        tabres_li_result.innerHTML = "result";
        OAT.Dom.append([tabres_ul,tabres_li_result]);
        if (!params.hideRequest)
        {
          var tabres_li_request = OAT.Dom.create("li");
          tabres_li_request.innerHTML = "request";
          OAT.Dom.append([tabres_ul,tabres_li_request]);
        }
        if (!params.hideResponce)
        {
          var tabres_li_response = OAT.Dom.create("li");
          tabres_li_response.innerHTML = "response";
          OAT.Dom.append([tabres_ul,tabres_li_response]);
        }

        if (params.showQuery)
        {
          var tabres_li_query = OAT.Dom.create("li");
          tabres_li_query.innerHTML = "query";
          OAT.Dom.append([tabres_ul,tabres_li_query]);
        }

        var tabres_li_start = OAT.Dom.create("li");
        tabres_li_start.className = "nav";
        var tabres_li_start_img = OAT.Dom.create("img");
        tabres_li_start_img.src = params.imagePath + "start.png";
        OAT.Dom.append([tabres_ul,tabres_li_start],[tabres_li_start,tabres_li_start_img]);

        var tabres_li_back = OAT.Dom.create("li");
        tabres_li_back.className = "nav";
        var tabres_li_back_img = OAT.Dom.create("img");
        tabres_li_back_img.src = params.imagePath + "back.png";
        OAT.Dom.append([tabres_ul,tabres_li_back],[tabres_li_back,tabres_li_back_img]);

        var tabres_li_forward = OAT.Dom.create("li");
        tabres_li_forward.className = "nav";
        var tabres_li_forward_img = OAT.Dom.create("img");
        tabres_li_forward_img.src = params.imagePath + "forward.png";
        OAT.Dom.append([tabres_ul,tabres_li_forward],[tabres_li_forward,tabres_li_forward_img]);

        var tabres_li_finish = OAT.Dom.create("li");
        tabres_li_finish.className = "nav";
        var tabres_li_finish_img = OAT.Dom.create("img");
        tabres_li_finish_img.src = params.imagePath + "finish.png";
        OAT.Dom.append([tabres_ul,tabres_li_finish],[tabres_li_finish,tabres_li_finish_img]);
        
        var res_container = OAT.Dom.create("div");
        res_container.className = "res_container";

        var result = OAT.Dom.create("div");
        result.className = "result";
        
        OAT.Dom.append([params.res_div,tabres_ul,res_container,result]);

        if (!params.hideRequest)
        {
          var body_str = body();
          var request = OAT.Dom.create("div");
          request.className = "request";
          var request_content = OAT.Dom.create("pre");
          OAT.Dom.append([request,request_content]);
          putTextInPre(request_content,'POST ' + endpoint + ' HTTP 1.1\r\n');
          putTextInPre(request_content,'Host: ' + window.location.host + '\r\n');
          if (ReqHeaders) {
      		  for (var p in ReqHeaders) {
      		    putTextInPre(request_content,p + ': ' + ReqHeaders[p] + '\r\n');
      		  }
      		}
          putTextInPre(request_content,'Content-Length: ' + body_str.length + '\r\n');
          putTextInPre(request_content,'\r\n');
          //putTextInPre(request_content,body_str.replace(/&/g,'&amp;').replace(/</g,'&lt;'));
          putTextInPre(request_content,body_str);
  
          OAT.Dom.append([params.res_div,request]);
        }
    
        if (!params.hideResponce)
        {
          var response = OAT.Dom.create("div");
          response.className = "response";
          var responce_content = OAT.Dom.create("pre");
          OAT.Dom.append([response,responce_content]);
        
          putTextInPre(responce_content,headers);
          putTextInPre(responce_content,'\r\n');
          //putTextInPre(responce_content,data.replace(/&/g,'&amp;').replace(/</g,'&lt;'));
          putTextInPre(responce_content,data);
          OAT.Dom.append([params.res_div,response]);
        }

        if (params.showQuery)
        {
          var query_div = OAT.Dom.create("div");
          query_div.className = "response";
          var query_div_content = OAT.Dom.create("pre");
          OAT.Dom.append([query_div,query_div_content]);
        
          //query_div_content.innerHTML = params.query.replace(/&/g,'&amp;').replace(/</g,'&lt;');
          //putTextInPre(query_div_content,params.query.replace(/&/g,'&amp;').replace(/</g,'&lt;'));
          putTextInPre(query_div_content,params.query);
          OAT.Dom.append([params.res_div,query_div]);
        }
        
        var tabres = new OAT.Tab (res_container);
        tabres.add (tabres_li_result,result);
        if (!params.hideRequest)
          tabres.add (tabres_li_request,request);
        if (!params.hideResponce)
          tabres.add (tabres_li_response,response);
        if (params.showQuery)
          tabres.add (tabres_li_query,query_div);
        tabres.go(0);


        if (params.browseStart.click)
          OAT.Dom.detach(params.browseStart,"click",params.browseStart.click);
        var tabres_start = tabres_li_start_img;
        if (params.nav_index == 0)
        {
          tabres_start.style.opacity = 0.3;
	        tabres_start.style.filter = 'alpha(opacity=30)';
	        tabres_start.style.cursor = 'default';
	        if (params.browseStart)
	        {
            params.browseStart.style.opacity = 0.3;
	          params.browseStart.style.filter = 'alpha(opacity=30)';
	          params.browseStart.style.cursor = 'default';
	        }
	      } else {
	        var startClick = function() {
        	  params.nav_index = 0;
        	  params.nav_restore();
            iSPARQL.QueryExec(params);
            params.browseCallback(params.query,params);
    	    }
        	OAT.Dom.attach(tabres_start,"click",startClick);
	        if (params.browseStart)
	        {
        	  OAT.Dom.attach(params.browseStart,"click",startClick);
          	params.browseStart.click = startClick;
            params.browseStart.style.opacity = '';
	          params.browseStart.style.filter = '';
	          params.browseStart.style.cursor = 'pointer';
        	}
    	  }

        if (params.browseBack.click)
          OAT.Dom.detach(params.browseBack,"click",params.browseBack.click);
        var tabres_back = tabres_li_back_img;
        if (params.nav_index == 0)
        {
          tabres_back.style.opacity = 0.3;
	        tabres_back.style.filter = 'alpha(opacity=30)';
	        tabres_back.style.cursor = 'default';
	        if (params.browseBack)
	        {
            params.browseBack.style.opacity = 0.3;
	          params.browseBack.style.filter = 'alpha(opacity=30)';
	          params.browseBack.style.cursor = 'default';
	        }
	      } else {
	        var backClick = function() {
        	  params.nav_index--;
        	  params.nav_restore();
            iSPARQL.QueryExec(params);
            params.browseCallback(params.query,params);
    	    }
        	OAT.Dom.attach(tabres_back,"click",backClick);
	        if (params.browseBack)
	        {
        	  OAT.Dom.attach(params.browseBack,"click",backClick);
          	params.browseBack.click = backClick;
            params.browseBack.style.opacity = '';
	          params.browseBack.style.filter = '';
	          params.browseBack.style.cursor = 'pointer';
        	}
    	  }
        
        if (params.browseForward.click)
          OAT.Dom.detach(params.browseForward,"click",params.browseForward.click);
        var tabres_forward = tabres_li_forward_img;
        if (params.nav_index == params.nav_stack.length - 1)
        {
          tabres_forward.style.opacity = 0.3;
	        tabres_forward.style.filter = 'alpha(opacity=30)';
	        tabres_forward.style.cursor = 'default';
	        if (params.browseForward)
	        {
            params.browseForward.style.opacity = 0.3;
	          params.browseForward.style.filter = 'alpha(opacity=30)';
	          params.browseForward.style.cursor = 'default';
	        }
	      } else {
	        var forwardClick = function() {
        	  params.nav_index++;
        	  params.nav_restore();
            iSPARQL.QueryExec(params);
            params.browseCallback(params.query,params);
    	    }
        	OAT.Dom.attach(tabres_forward,"click",forwardClick);
	        if (params.browseForward)
	        {
          	OAT.Dom.attach(params.browseForward,"click",forwardClick);
          	params.browseForward.click = forwardClick;
            params.browseForward.style.opacity = '';
	          params.browseForward.style.filter = '';
	          params.browseForward.style.cursor = 'pointer';
          }
    	  }

        if (params.browseFinish.click)
          OAT.Dom.detach(params.browseFinish,"click",params.browseFinish.click);
        var tabres_finish = tabres_li_finish;
        if (params.nav_index == params.nav_stack.length - 1)
        {
          tabres_finish.style.opacity = 0.3;
	        tabres_finish.style.filter = 'alpha(opacity=30)';
	        tabres_finish.style.cursor = 'default';
	        if (params.browseFinish)
	        {
            params.browseFinish.style.opacity = 0.3;
	          params.browseFinish.style.filter = 'alpha(opacity=30)';
	          params.browseFinish.style.cursor = 'default';
	        }
	      } else {
	        var finishClick = function() {
        	  params.nav_index = params.nav_stack.length - 1;
        	  params.nav_restore();
            iSPARQL.QueryExec(params);
            params.browseCallback(params.query,params);
    	    }
        	OAT.Dom.attach(tabres_finish,"click",finishClick);
	        if (params.browseFinish)
	        {
          	OAT.Dom.attach(params.browseFinish,"click",finishClick);
          	params.browseFinish.click = finishClick;
            params.browseFinish.style.opacity = '';
	          params.browseFinish.style.filter = '';
	          params.browseFinish.style.cursor = 'pointer';
          }
    	  }
    	      
        //if it is a special format and param is empty then we postprocess json to draw a table
        if (params.format == 'application/isparql+table' && !param)
        {
          var grid_div = OAT.Dom.create("div");
          grid_div.className = "grid";
          OAT.Dom.append([result,grid_div]);

          var grid = new OAT.Grid(grid_div,0);
          var JSONData = eval('(' + data + ')');
          iSPARQL.LoadJSON2Grid(grid,JSONData,params);
          //table.parentNode.removeChild(table);
          grid.ieFix();
          if (typeof grid2 != 'undefined')
            grid2.ieFix();
        }
        else if (params.format == 'application/isparql+rdf-graph' && !param)
        {
          var res = OAT.Dom.create("div",{position:"relative",marginTop:"20px",height:"450px"});
          OAT.Dom.append([result,res]);
          var xml = OAT.Xml.createXmlDoc(data);
          var triples = OAT.RDF.toTriples(xml);
          var x = OAT.GraphSVGData.fromTriples(triples);
          var rdf_graph = new OAT.GraphSVG(res, x[0], x[1], {});
        }
        else
        {
          // it is either and error or compile
          if (param)
          {
            result.innerHTML = data;
          // result too big to post process, just show it
          } else if (data.length > 10 * 1024) {
            
            result.innerHTML = '<pre>' + data.replace(/</g,'&lt;') + '</pre>';
          // ry to postprocess it 
          } else {
            var shtype = 'xml';
            if (params.format == 'application/sparql-results+json' || 
                params.format == 'application/javascript' )
              shtype = 'javascript';
            else if (params.format == 'text/html')
              shtype = 'html';
            result.innerHTML = '<textarea name="code" class="' + shtype + '">' + data + '</textarea>';
            dp.SyntaxHighlighter.HighlightAll('code',0,0);
          }
        }
      },
  		nav_stack:[{query:paramsObj.query,
  		            default_graph_uri:paramsObj.default_graph_uri,
  		            format:paramsObj.format}],
  		nav_index:0,
  		nav_restore:function(){
    	  this.query = this.nav_stack[this.nav_index].query;
    	  this.default_graph_uri = this.nav_stack[this.nav_index].default_graph_uri;
    	  this.format = this.nav_stack[this.nav_index].format;
  		}
  	};
  	
  	for (var p in paramsObj) { params[p] = paramsObj[p]; }

    if (params.service == '')
    {
      alert('You must specify "Query Service Endpoint"!');
      return;
    }
    
    var content_type = 'application/x-www-form-urlencoded';
    
    var ReqHeaders = {'Accept':params.format,'Content-Type':content_type};
  
    var endpoint = params.service;
    if (endpoint.match(/^http:\/\//) && params.proxy && isVirtuoso)
      endpoint = './remote.vsp';
  
    OAT.Dom.clear(params.res_div);
  
    // generate the request body
    var body = function()
    {
      var body = '';

      if (params.default_graph_uri)
      {
        body += '&default-graph-uri=';
        body += encodeURIComponent(params.default_graph_uri);
      }

      if (params.query)
      {
        body += '&query=';
        body += encodeURIComponent(params.query);
      }

      if (params.format)
      {
        body += '&format=';
        if (params.format == 'application/isparql+table')
          body += encodeURIComponent('application/sparql-results+json'); 
        else if (params.format == 'application/isparql+rdf-graph')
          body += encodeURIComponent('application/rdf+xml'); 
        else
          body += encodeURIComponent(params.format);
      }

      if (params.maxrows)
      {
        body += '&maxrows=';
        body += encodeURIComponent(params.maxrows);
      }

      if (isVirtuoso && params.should_sponge && params.should_sponge != '')
      {
        body += '&should-sponge=';
        body += encodeURIComponent(params.should_sponge);
      }
      
      if (endpoint != params.service)
      {
        body += '&service=';
        body += encodeURIComponent(params.service);
      }
      
      for(var n = 0; n < params.named_graphs.length; n++)
      {
        if (params.named_graphs[n] != '')
        {
          body += '&named-graph-uri=';
          body += encodeURIComponent(params.named_graphs[n]); 
        }
      }
      return body.substring(1);
    }
  
    //in case of an error exec the callback also, but give a parameter er
    //OAT.Ajax.errorRef = params.errorHandler;
          
    OAT.AJAX.POST (endpoint, body(), params.callback, {headers:ReqHeaders,onerror:params.errorHandler});
    //OAT.Ajax.command(OAT.Ajax.POST, endpoint, body, params.callback, OAT.Ajax.TYPE_TEXT,ReqHeaders);
  }
 
};

