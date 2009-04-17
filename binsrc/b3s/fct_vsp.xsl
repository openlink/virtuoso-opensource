<?xml version="1.0" encoding="utf-8"?>
<!--
--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2009 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--
-->
<xsl:stylesheet version ="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="html" encoding="ISO-8859-1"/>
<xsl:variable name="page_len" select="20"/>
<xsl:variable name="offs" select="if(/facets/view/@offset = '', 1, /facets/view/@offset + 1)"/> <!-- humans count from 1 -->
<xsl:variable name="rowcnt" select="count(/facets/result/row)"/>
<xsl:template match = "facets">
<div id="res">
  <div class="btn_bar btn_bar_top">
    <xsl:call-template name="render-pager"/>
  <xsl:if test="/facets/complete != 'yes'">
    <span class="partial_res_expln">
      <xsl:choose>
        <xsl:when test="$rowcnt != 0">
          The query timed out with partial result:
        </xsl:when>
        <xsl:otherwise>
          The query timed out with no result:
        </xsl:otherwise>
      </xsl:choose>
    </span>
    <a class="partial_res_help" href="/fct/facet_doc.html#timeout">What's this?</a>&#8194;
    <button>
      <xsl:attribute name="onclick">
        javascript:fct_nav_to('/fct/facet.vsp?cmd=refresh&amp;sid=<xsl:value-of select="$sid"/>&amp;timeout=<xsl:value-of select="$timeout"/>')
      </xsl:attribute>Retry with <xsl:value-of select="($timeout div 1000)"/> seconds timeout
    </button>
  </xsl:if>
</div> <!-- btn_bar -->
<xsl:if test="/facets/complete = 'yes' and /facets/processed = 0 and $rowcnt = 0">
  <div class="empty_result">
    Nothing found.
  </div>
</xsl:if>
<!--xsl:choose>
  <xsl:when test="$type = 'text'"><h3>Text match results</h3></xsl:when>
  <xsl:when test="$type = 'text-properties'"><h3>List of Properties With Matching Text</h3></xsl:when>
  <xsl:when test="$type = 'classes'"><h3>Types</h3></xsl:when>
  <xsl:when test="$type = 'properties'"><h3>Properties</h3></xsl:when>
  <xsl:when test="$type = 'properties-in'"><h3>Referencing Properties</h3></xsl:when>
  <xsl:when test="$type = 'list'"><h3>List</h3></xsl:when>
  <xsl:when test="$type = 'list-count'"><h3>Distinct values</h3></xsl:when>
  <xsl:when test="$type = 'geo'"><h3>Location</h3></xsl:when>
</xsl:choose-->
<!--xsl:message terminate="no"><xsl:value-of select="$type"/></xsl:message-->
<xsl:choose>
  <xsl:when test="$type = 'geo'">
    <script type="text/javascript" >
<![CDATA[
OAT.Preferences.imagePath = "oat/images/";
function init(){
  var callback = function(commonMapObj) {
    var click = function (href, label) {
      return function(marker) {
        var x;
	if (href.length > 0) {
	  x = OAT.Dom.create ("a");
	  x.href = '/about/?url='+escape (href);
	  if (label.length > 0)
	    x.innerHTML = label;
	  else
            x.innerHTML = href;
	}
        else x = OAT.Dom.text(label);
	commonMapObj.openWindow (marker, x);
      }
    }
    window.m = commonMapObj;
    commonMapObj.centerAndZoom(0,0,0);
    commonMapObj.addTypeControl();
    commonMapObj.addMapControl();
    commonMapObj.setMapType(OAT.MapData.MAP_HYB);

    var markersArr = [];
]]>
    <xsl:for-each select="result/row">
      commonMapObj.addMarker(1,
                             <xsl:value-of select="column[3]"/>,
                             <xsl:value-of select="column[4]"/>,
                             "oat/images/markers/01.png",
                             18,
                             41,
                             click ("<xsl:value-of select="column[1]"/>", "<xsl:value-of select='translate (normalize-space (column[2]), &apos;"&apos;, &apos;&apos;)'/>"));
      markersArr.push([<xsl:value-of select="column[3]"/>,<xsl:value-of select="column[4]"/>]);
    </xsl:for-each>
<![CDATA[
    commonMapObj.optimalPosition(markersArr);
    return;
  }
  window.YMAPPID = "";
  var providerType = OAT.MapData.TYPE_Y;
  var containerDiv = document.getElementById('user_map');
  var map = new OAT.Map(containerDiv,providerType,{fix:OAT.MapData.FIX_ROUND1});
  map.loadApi(providerType, callback);
}
]]>
    </script>
    <div id="user_map" style="position:relative; width:600px; height:400px;"></div>
  </xsl:when>
  <xsl:otherwise>
    <xsl:choose>
      <xsl:when test="count (/facets/result) &gt; 1">
	<xsl:for-each select="result[@type = 'classes' or @type = 'properties']">
	  <div class="facet_ctr">
	    <xsl:choose>
              <xsl:when test="@type='properties'">
		<h4 class="facet_hd">Properties</h4>
              </xsl:when>
              <xsl:otherwise>
		<h4 class="facet_hd">Types</h4>
              </xsl:otherwise>
	    </xsl:choose>
	    <div class="facet">
              <xsl:call-template name="render-result">
		<xsl:with-param name="view-type"><xsl:value-of select="@type"/></xsl:with-param>
		<xsl:with-param name="command">
		  <xsl:choose>
		    <xsl:when test="@type = 'classes'">set_class</xsl:when>
		    <xsl:when test="@type = 'properties'">open_property</xsl:when>
		    <xsl:otherwise><xsl:value-of select="$cmd"/></xsl:otherwise>
                  </xsl:choose>
		</xsl:with-param>
              </xsl:call-template>
	    </div>
	  </div> <!-- facet_ctr -->
	</xsl:for-each>
	<xsl:for-each select="/facets/result [@type != 'classes' and @type != 'properties']">
	  <xsl:call-template name="render-result">
	    <xsl:with-param name="view-type"><xsl:value-of select="$type"/></xsl:with-param>
	    <xsl:with-param name="command">
	      <xsl:choose>
                <xsl:when test="@type = 'classes'">set_class</xsl:when>
                <xsl:when test="@type = 'properties'">open_property</xsl:when>
                <xsl:otherwise><xsl:value-of select="$cmd"/></xsl:otherwise>
              </xsl:choose>
	    </xsl:with-param>
	  </xsl:call-template>
        </xsl:for-each>
      </xsl:when>
      <xsl:otherwise>
        <xsl:for-each select="/facets/result">
	  <xsl:call-template name="render-result">
	    <xsl:with-param name="view-type"><xsl:value-of select="$type"/></xsl:with-param>
	    <xsl:with-param name="command">
	      <xsl:choose>
                <xsl:when test="@type = 'classes'">set_class</xsl:when>
                <xsl:when test="@type = 'properties'">open_property</xsl:when>
	        <xsl:otherwise><xsl:value-of select="$cmd"/></xsl:otherwise>
              </xsl:choose>
	    </xsl:with-param>
	  </xsl:call-template>
        </xsl:for-each>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:otherwise>
</xsl:choose>
<div class="btn_bar">
  <xsl:call-template name="render-pager"/>
</div> <!-- btn_bar -->
<div id="result_nfo">
  <xsl:choose>
    <xsl:when test="/facets/complete = 'yes'">Complete result - </xsl:when>
    <xsl:otherwise>Partial result - </xsl:otherwise>
  </xsl:choose>
  <xsl:value-of select="if(/facets/processed > 0, /facets/processed, $rowcnt)"/> processed in <xsl:value-of select="/facets/time"/> msec.<br/>  Resource utilization:
  <xsl:value-of select="/facets/db-activity"/> 
</div> <!-- #result_nfo -->
</div> <!-- #res -->
<script type="text/javascript">
  var sparql_a = OAT.Dom.create('a',{}, 'sparql_a');
  sparql_a.href='sparql.vsp?q=<xsl:value-of select="urlify (/facets/sparql)"/>'
  sparql_a.innerHTML = 'View query as SPARQL';
  OAT.Dom.append (['sparql_a_ctr',sparql_a]);
</script>
</xsl:template>

<xsl:template name="render-pager">
  <xsl:if test="/facets/processed &gt; 0">
    <div class="pager">
      <span class="stats">Showing 
      <xsl:value-of select="$offs"/>-<!-- <xsl:value-of select="$offs + $page_len - 1"/>--><xsl:value-of select="$offs + $rowcnt - 1"/> of
      <xsl:value-of select="/facets/processed"/> total&#8194;
      </span>
      <xsl:if test="$offs &gt;= $page_len">
	<button>
	  <xsl:attribute name="class">pager</xsl:attribute>
	  <xsl:attribute name="onclick">javascript:fct_nav_to('/fct/facet.vsp?cmd=prev&amp;sid=<xsl:value-of select="$sid"/>')
	  </xsl:attribute>&#9666; Prev
	</button>
      </xsl:if>
      <xsl:if test="($offs + $page_len) &lt; /facets/processed">
	<button>
	  <xsl:attribute name="class">pager</xsl:attribute>
	  <xsl:attribute name="onclick">javascript:fct_nav_to('/fct/facet.vsp?cmd=next&amp;sid=<xsl:value-of select="$sid"/>')
	  </xsl:attribute>&#9656; Next
	</button>
      </xsl:if>
    </div>
  </xsl:if>
</xsl:template> <!-- render-pager -->

<xsl:template name="render-result">
<table class="result">
  <thead>
    <xsl:choose>
      <xsl:when test="$view-type = 'properties'">
	<div class="dbg"><xsl:value-of select="$view-type"/></div>
	<tr><th>Property</th><th></th><th>Count</th></tr>
      </xsl:when>
      <xsl:when test="$view-type = 'list-count'">
	<div class="dbg"><xsl:value-of select="$view-type"/></div>
	<tr><th>Entity</th><th>Title</th><th>Count</th></tr>
      </xsl:when>
      <xsl:when test="$view-type = 'text-properties'">
	<div class="dbg"><xsl:value-of select="$view-type"/></div>
	<tr><th>Property</th><th>Label</th><th>Count</th></tr>
      </xsl:when>
      <xsl:when test="$view-type = 'properties-in'">
	<div class="dbg"><xsl:value-of select="$view-type"/></div>
	<tr><th>Property</th><th>Label</th><th>Count</th></tr>
      </xsl:when>
      <xsl:when test="$view-type = 'list'">
	<div class="dbg"><xsl:value-of select="$view-type"/></div>
	<tr><th></th><th></th><th></th></tr>
      </xsl:when>
      <xsl:when test="$view-type = 'classes'">
	<div class="dbg"><xsl:value-of select="$view-type"/></div>
	<tr><th>Type</th><th>Label</th><th>Count</th></tr>
      </xsl:when>
      <xsl:when test="$view-type = 'text'">
	<div class="dbg"><xsl:value-of select="$view-type"/></div>
	<tr><th>Entity</th><th>Title</th><th>Text excerpt</th></tr>
      </xsl:when>
    </xsl:choose>
  </thead>
  <tbody>
    <xsl:for-each select="row">
      <tr>
	<xsl:choose>
	  <xsl:when test="$view-type = 'properties' or
			  $view-type = 'classes' or
			  $view-type = 'properties-in' or
			  $view-type = 'text-properties' or
			  $view-type = 'list' or
			  $view-type = 'list-count'">
	  <xsl:if test="./@rank">
            <td>
              <xsl:value-of select="./@rank"/>
            </td>
	</xsl:if>
	    <td>
	      <xsl:if test="'url' = column[1]/@dataview-type">
		<a>
		  <xsl:attribute name="href">
		    /about/?url=<xsl:value-of select="urlify (column[1])"/>&amp;sid=<xsl:value-of select="$sid"/>
		  </xsl:attribute>
		  <xsl:attribute name="class">describe</xsl:attribute>
		    Describe
		</a>
	      </xsl:if>
	      <a>
		<xsl:attribute name="href">
		  /fct/facet.vsp?cmd=<xsl:value-of select="$command"/>&amp;iri=<xsl:value-of select="urlify (column[1])"/>&amp;lang=<xsl:value-of select="column[1]/@xml:lang"/>&amp;datatype=<xsl:value-of select="urlify (column[1]/@datatype)"/>&amp;sid=<xsl:value-of select="$sid"/>
		</xsl:attribute>
		<xsl:attribute name="title">
		  <xsl:value-of select="column[1]"/>
		</xsl:attribute>
		<xsl:choose>
		  <xsl:when test="'' != column[1]/@shortform">
		    <xsl:value-of select="column[1]/@shortform"/>
		  </xsl:when>
		  <xsl:otherwise>
		    <xsl:value-of select="column[1]"/>
		  </xsl:otherwise>
		</xsl:choose>
	      </a>
	    </td>
	    <td>
	      <xsl:choose>
		<xsl:when test="'' != ./@shortform"><xsl:value-of select="./@shortform"/></xsl:when>
		<xsl:otherwise>
		  <xsl:value-of select="column[2]"/>
		</xsl:otherwise>
	      </xsl:choose>
	    </td>
	    <td>
	      <xsl:apply-templates select="column[3]"/>
	    </td>
	  </xsl:when>
	  <xsl:otherwise>
            <td class="rnk">
              <xsl:for-each select="column[@datatype='trank' or @datatype='erank']">
                <img class="rnk">
                  <xsl:attribute name="src">
                    images/r_<xsl:value-of select="min (floor(.), 10)"/>.png
                  </xsl:attribute>
                    <xsl:attribute name="alt">
                      <xsl:choose>
                        <xsl:when test="./@datatype='trank'">Text Rank:</xsl:when>
                        <xsl:when test="./@datatype='erank'">Entity Rank:</xsl:when> 
		      </xsl:choose>
                      <xsl:value-of select="."/>
                    </xsl:attribute>
                    <xsl:attribute name="title">
                      <xsl:choose>
                        <xsl:when test="./@datatype='trank'">Text Rank:</xsl:when>
                        <xsl:when test="./@datatype='erank'">Entity Rank:</xsl:when> 
                      </xsl:choose>
                    <xsl:value-of select="."/>
                  </xsl:attribute>
                </img>
              </xsl:for-each>
	    </td>
	    <xsl:for-each select="column">
	      <td>
		<xsl:choose>
		  <xsl:when test="'url' = ./@datatype">
		    <a>
		      <xsl:attribute name="href">/about/?url=<xsl:value-of select="urlify (.)"/></xsl:attribute>
		      <xsl:attribute name="title"><xsl:value-of select="."/></xsl:attribute>
		      <xsl:choose>
			<xsl:when test="'' != ./@shortform"><xsl:value-of select="./@shortform"/></xsl:when>
			<xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
		      </xsl:choose>
		    </a>
		  </xsl:when>
                  <xsl:when test="'erank' = ./@datatype or 'trank' = ./@datatype">

                  </xsl:when>
		  <xsl:otherwise><xsl:apply-templates select="."/></xsl:otherwise>
		</xsl:choose>
	      </td>
	    </xsl:for-each>
	  </xsl:otherwise>
	</xsl:choose>
      </tr>
      <xsl:text></xsl:text>
    </xsl:for-each>
  </tbody>
</table>
</xsl:template>

<xsl:template match="@* | node()">
  <xsl:copy>
    <xsl:apply-templates select="@* | node()"/>
  </xsl:copy>
</xsl:template>


</xsl:stylesheet>
