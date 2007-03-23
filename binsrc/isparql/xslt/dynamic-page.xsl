<?xml version="1.0" ?>
<!--

  $Id$
  
  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
  project.
  
  Copyright (C) 1998-2006 OpenLink Software
  
  This project is free software; you can redistribute it and/or modify it
  under the terms of the GNU General Public License as published by the
  Free Software Foundation; only version 2 of the License, dated June 1991.
  
  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.
  
  You should have received a copy of the GNU General Public License along
  with this program; if not, write to the Free Software Foundation, Inc.,
  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA

-->
<xsl:stylesheet version="1.0" xmlns:xsl='http://www.w3.org/1999/XSL/Transform' 
    xmlns:i="urn:schemas-openlink-com:isparql">
    <xsl:output method="html"/>

    <xsl:template match = "/">
      <xsl:apply-templates select="//i:ISparqlDynamicPage"/>
    </xsl:template>

    <xsl:template match = "i:ISparqlDynamicPage">

	<html>
	<head>
		<script type="text/javascript">
      var featureList=["tab","ajax2","window","grid","anchor",
             "xml","dialog","sparql","graphsvg"];
		</script>
    <link type="text/css" rel="stylesheet" href="/isparql/SyntaxHighlighter.css"/>
    <link type="text/css" rel="stylesheet" href="/isparql/isparql.css"/>
		<script type="text/javascript" src="/isparql/toolkit/loader.js"></script>
		<script type="text/javascript" src="/isparql/isparql.js"></script>
		<script type="text/javascript">
		
		var goptions = {};
		goptions.service = "<xsl:value-of select="i:service" />";
		var sponge = '';
		sponge = "<xsl:value-of select="i:should_sponge" />";
		<xsl:if test="../i:should_sponge">
  		sponge = "<xsl:value-of select="../i:should_sponge" />";
		</xsl:if>
		<xsl:if test="../i:service">
  		goptions.service = "<xsl:value-of select="../i:service" />";
		</xsl:if>
		var graph = "<xsl:value-of select="i:graph" />";
		var isVirtuoso = true;
		<![CDATA[
		  var toolkitImagesPath = "/isparql/toolkit/images";
			function init() {
        OAT.Preferences.imagePath = toolkitImagesPath + "/";
        OAT.AJAX.imagePath = toolkitImagesPath;
        OAT.Anchor.imagePath = toolkitImagesPath + '/';
        var query = OAT.Dom.fromSafeXML($('query').innerHTML);
        var format = 'application/isparql+table';
        if(query.match(/construct/i) || query.match(/describe/i))
          format = 'application/isparql+rdf-graph';
        var params = {
          service:goptions.service,
          query:OAT.Dom.fromSafeXML($('query').innerHTML),
          default_graph_uri:graph,
          maxrows:0,
          format:format,
          res_div:$('res_area'),
          imagePath:"/isparql/images/",
          should_sponge:sponge,
          hideRequest:true,
          hideResponce:true
        }

        var page_params = {};
        var page_search = location.search;
        if(page_search.length > 1) page_search = page_search.substring(1);
      
        if(page_search) {
          var tmp = page_search.split("&");
          for(var i=0; i < tmp.length; i++) {
            var key = tmp[i].substring(0,tmp[i].indexOf('='));
            var val = tmp[i].substring(tmp[i].indexOf('=') + 1);
            page_params[key] = decodeURIComponent(val);
          }
        }

        if (page_params['dereference-uri'])
        {
      		params.query = 'select * where {?s ?p ?o}';
          params.default_graph_uri = page_params['dereference-uri'];
          params.should_sponge = 'soft';
        }
        // show query by default
        params.showQuery = true;
        if (page_params['showQuery'])
        {
          if (page_params['showQuery'] != '0')
          params.showQuery = true;
          else
            params.showQuery = false;
        }
        if (page_params['showRequest'])
        {
          if (page_params['showRequest'] != '0')
          params.hideRequest = false;
          else
            params.hideRequest = true;
        }
        if (page_params['showResponce'])
        {
          if (page_params['showResponce'] != '0')
          params.hideResponce = false;
          else
            params.hideRequest = true;
        }

        iSPARQL.QueryExec(params);
			}
]]>
		</script>
		<style type="text/css">
			@import url("/isparql/isparql.css");
		</style>
		<title>iSPARQL Dynamic Page</title>
	</head>
	<body>
		<div id="res_area"></div>
		<div id="query" style="display:none;">
		  <xsl:value-of select="i:query"/>
		</div>
	</body>
	</html>
	
	</xsl:template>
</xsl:stylesheet>
