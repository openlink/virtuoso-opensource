<?xml version="1.0" encoding="utf-8"?>
<!--
--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2012 OpenLink Software
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
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:addthis="http://www.addthis.com/help/api-spec">
<xsl:output method="html" encoding="ISO-8859-1" indent="yes"/>
<!-- Pager-related vars calculation -->

<xsl:variable name="offs"
              select="if(or(/facets/view/@offset = '', not(/facets/view/@offset)), 1, /facets/view/@offset + 1)"/>
<xsl:variable name="limit" select="/facets/view/@limit"/>

<xsl:variable name="rowcnt" select="count(/facets/result/row)"/>

<xsl:param name="s_term"/>
<xsl:param name="p_term"/>
<xsl:param name="o_term"/>
<xsl:param name="t_term"/>
<xsl:param name="p_qry"/>
<xsl:param name="p_xml"/>
<xsl:param name="tree"/>
<xsl:param name="addthis_key"/>
<xsl:param name="type"/>

<xsl:variable name="view-type">
  <xsl:choose>
    <xsl:when test="/facets/result/@type='list' and /facets/view/@position='0'">
      <xsl:text>entities-list</xsl:text>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="/facets/result/@type"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:variable>

<xsl:variable name="noresult">
  <xsl:if test="/facets/complete = 'yes' and /facets/processed = 0 and $rowcnt = 0"><xsl:value-of select="1"/></xsl:if>
</xsl:variable>

<xsl:template match="facets">
  <div id="res">
    <div class="btn_bar btn_bar_top">
      <xsl:comment><xsl:value-of select="$type"/></xsl:comment>
      <xsl:call-template name="render-pager">
        <xsl:with-param name="pfx">pager_top</xsl:with-param>
      </xsl:call-template>
      <xsl:if test="/facets/complete != 'yes'">
        <span class="partial_res_expln">
          <xsl:choose>
            <xsl:when test="$rowcnt != 0">
              <xsl:text>The query timed out with partial result:</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text>The query timed out with no result:</xsl:text>
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
    <xsl:choose>
      <xsl:when test="$noresult = 1">
        <div class="empty_result">
          <h3>No Result</h3>
          <p>This query did not produce any results.<br/>
          Try dropping some of the conditions, to make the query less specific.</p>
        </div>
      </xsl:when>
      <xsl:otherwise>
        <xsl:choose>
          <!--xsl:when test="$view-type = 'text'"><h3>Text match results</h3></xsl:when>
          <xsl:when test="$view-type = 'text-d'"><h3>Text match results</h3></xsl:when>
          <xsl:when test="$view-type = 'text-properties'"><h3>List of Properties With Matching Text</h3></xsl:when>
          <xsl:when test="$view-type = 'classes'"><h3>Types</h3></xsl:when>
          <xsl:when test="$view-type = 'properties'"><h3>Properties</h3></xsl:when>
          <xsl:when test="$view-type = 'properties-in'"><h3>Referencing Properties</h3></xsl:when-->
          <xsl:when test="$view-type = 'list'"><h3>Select a value or condition</h3></xsl:when>
          <xsl:when test="$view-type = 'entities-list'"><h3>Entities found</h3></xsl:when>
          <!--xsl:when test="$view-type = 'list-count'"><h3>Distinct values</h3></xsl:when>
          <xsl:when test="$view-type = 'geo'"><h3>Location</h3></xsl:when-->
        </xsl:choose>
        <!-- xsl:message terminate="no"><xsl:value-of select="$type"/></xsl:message -->
        <xsl:choose>
          <xsl:when test="$view-type = 'geo' or $view-type = 'geo-list'">
            <xsl:call-template name="render-geo-conds-ui">
              <xsl:with-param name="result" select="/facets/result"/>
            </xsl:call-template>
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
                        <xsl:with-param name="view-type"><xsl:value-of select="$view-type"/></xsl:with-param>
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
	            <xsl:with-param name="view-type"><xsl:value-of select="$view-type"/></xsl:with-param>
	            <xsl:with-param name="command">
	              <xsl:choose>
                        <xsl:when test="@type = 'classes'">set_class</xsl:when>
                        <xsl:when test="@type = 'properties'">open_property</xsl:when>
                        <xsl:otherwise><xsl:value-of select="$cmd"/></xsl:otherwise>
                      </xsl:choose>
	            </xsl:with-param>
	          </xsl:call-template>
                </xsl:for-each>
              </xsl:when> <!-- multiple results -->
              <xsl:otherwise>
                <xsl:for-each select="/facets/result">
	          <xsl:call-template name="render-result">
	            <xsl:with-param name="view-type"><xsl:value-of select="$view-type"/></xsl:with-param>
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
          <xsl:call-template name="render-pager">
            <xsl:with-param name="pfx">pager_bottom</xsl:with-param>
          </xsl:call-template>
        </div> <!-- btn_bar -->
      </xsl:otherwise> <!-- non-empty result -->
    </xsl:choose>
    <div id="result_nfo">
      <xsl:choose>
        <xsl:when test="/facets/complete = 'yes'">
          <xsl:text>Complete result - </xsl:text>
        </xsl:when>
        <xsl:otherwise>Partial result - </xsl:otherwise>
      </xsl:choose>
      <xsl:value-of select="if(/facets/processed &gt; 0, /facets/processed, $rowcnt)"/>
      <xsl:text> processed in </xsl:text>
      <xsl:value-of select="/facets/time"/>
      <xsl:text> msec.</xsl:text>
      <br/>
      <xsl:text>  Resource utilization: </xsl:text>
      <xsl:value-of select="/facets/db-activity"/>
    </div> <!-- #result_nfo -->
  </div> <!-- #res -->
  <script type="text/javascript">
  var sparql_a = OAT.Dom.create('a',{}, 'sparql_a');
  sparql_a.href='/sparql?default-graph-uri=&amp;qtxt=<xsl:value-of select="urlify ($p_qry)"/>&amp;debug='
  sparql_a.innerHTML = 'View query as SPARQL';
  var plink_a = OAT.Dom.create('a',{}, 'plink_a');
  plink_a.href='/fct/facet.vsp?qxml=<xsl:value-of select="urlify ($p_xml)"/>'
  plink_a.innerHTML = 'Facet permalink';
  OAT.Dom.append (['sparql_a_ctr',sparql_a, plink_a]);
  </script>
  <!--xsl:message terminate="no">addthis_key:<xsl:value-of select="$addthis_key"/></xsl:message-->
  <xsl:if test="$view-type = 'entities-list' or $type = 'default'">
  <script type="text/javascript">
  if ($('pivot_a_ctr')) {
    var pivot_a = OAT.Dom.create('a', {}, 'pivot_a');
    pivot_a.href='/pivot_collections/pivot.vsp?sid=<xsl:value-of select="$sid"/>&amp;limit=75&amp;qrcodes=0&amp;CXML_redir_for_subjs=&amp;CXML_redir_for_hrefs=&amp;q=<xsl:value-of select="urlify (normalize-space(/facets/sparql))"/>'
	  pivot_a.innerHTML = 'Make Pivot collection';
      pivot_a.id = 'pivot_a_mpc';

      var pivot_pg = OAT.Dom.create('span', {}, 'pivot_pg');
      pivot_pg.innerHTML = '&nbsp;&nbsp;(&nbsp;<a  href="#" title="Sets the maximum number of entities displayed in a PivotViewer page. Entities on other pages are accessible via Related Collections links. A value of 0 disables paging, displaying all entities in a single PivotViewer page. Range: 0..1000">Page size</a>&nbsp;<input type="text" onblur="fct_set_pivot_page_size()" id="pivot_pg_size" size="4" maxlength="4" value="75" />&nbsp;&nbsp;)';
	  var pivot_qrcode_opts = OAT.Dom.create('span', {}, 'pivot_qrcode_opts');
	  pivot_qrcode_opts.innerHTML = '&nbsp;&nbsp;<a href="#" title="Include a QRcode adjacent to each item\'s image">with QRcodes</a><input type="checkbox" onclick="fct_set_pivot_qrcode_opt()" id="pivot_qrcode" />';

	  var pivot_link_opts = OAT.Dom.create('span', {}, 'pivot_link_opts');
	  pivot_link_opts.innerHTML = '&nbsp;&nbsp;\
	  <a href="#" title="Sets the link-out behavior of subject URIs, optionally performing a DESCRIBE on the subject">Subject&nbsp;&nbsp;link&nbsp;behavior</a>&nbsp;\
	  <select id="CXML_redir_for_subjs" onchange="fct_set_pivot_subj_uri_opt()">\
			<option value="121" selected="true">External resource link</option>\
	  		<option value="">No link out</option>\
			<!-- <option value="LOCAL_PIVOT">External faceted navigation links</option> -->\
			<option value="LOCAL_TTL">External description resource (TTL)</option>\
			<!-- <option value="LOCAL_CXML">External description resource (CXML)</option> -->\
			<option value="LOCAL_NTRIPLES">External description resource (NTRIPLES)</option>\
			<option value="LOCAL_JSON">External description resource (JSON)</option>\
			<option value="LOCAL_XML">External description resource (RDF/XML)</option>\
		</select>\
		&nbsp;&nbsp;\
		<a href="#" title="Sets the CXML type of resource URIs to String or Link, optionally performing a DESCRIBE on the resource">Facet&nbsp;link&nbsp;behavior</a>&nbsp;\
		<select id="CXML_redir_for_hrefs" onchange="fct_set_pivot_href_opt()">\
			<option value="" selected="true">Local faceted navigation link</option>\
			<option value="121">External resource link</option>\
			<option value="LOCAL_PIVOT">External faceted navigation links</option>\
			<option value="LOCAL_TTL">External description resource (TTL)</option>\
			<option value="LOCAL_CXML">External description resource (CXML)</option>\
			<option value="LOCAL_NTRIPLES">External description resource (NTRIPLES)</option>\
			<option value="LOCAL_JSON">External description resource (JSON)</option>\
			<option value="LOCAL_XML">External description resource (RDF/XML)</option>\
		</select>';

      OAT.Dom.append (['pivot_a_ctr',pivot_a,pivot_pg,pivot_qrcode_opts,pivot_link_opts]);
  }
    </script>
  </xsl:if>

  <xsl:call-template name="render-init-func">
    <xsl:with-param name="result" select="/facets/result"/>
  </xsl:call-template>

</xsl:template>

<xsl:template name="render-limit-opts">
  <xsl:param name="lim-list"/>
  <xsl:param name="limit"/>
  <xsl:variable name="new-lim-list" select="concat(normalize-space($lim-list), ' ')"/>
  <xsl:variable name="first-val" select="substring-before($new-lim-list, ' ')" />
  <xsl:variable name="remaining" select="substring-after($new-lim-list, ' ')" />
  <option>
    <xsl:attribute name="value"><xsl:value-of select="$first-val"/></xsl:attribute>
    <xsl:if test="$first-val = $limit"><xsl:attribute name="selected">true</xsl:attribute></xsl:if>
    <xsl:value-of select="$first-val"/>
  </option>
  <xsl:if test="$remaining">
    <xsl:call-template name="render-limit-opts">
      <xsl:with-param name="lim-list"><xsl:value-of select="$remaining"/></xsl:with-param>
      <xsl:with-param name="limit"><xsl:value-of select="$limit"/></xsl:with-param>
    </xsl:call-template>
  </xsl:if>
</xsl:template>

<xsl:template name="render-pager">
  <xsl:param name="pfx"/>
  <xsl:if test="/facets/processed &gt; 0">
    <form class="pager">
      <xsl:attribute name="id"><xsl:value-of select="$pfx"/></xsl:attribute>
      <input type="hidden" name="sid">
        <xsl:attribute name="value">
          <xsl:value-of select="$sid"/>
        </xsl:attribute>
      </input>
      <input type="hidden" name="cmd" value="go_to">
        <xsl:attribute name="id"><xsl:value-of select="$pfx"/>_cmd</xsl:attribute>
      </input>
      <label>
        <xsl:attribute name="for"><xsl:value-of select="$pfx"/>_goto</xsl:attribute>
        Go to:
      </label>

      <input name="offset" type="text" class="pager_go" size="3">
        <xsl:attribute name="id"><xsl:value-of select="$pfx"/>_goto</xsl:attribute>
        <!--xsl:attribute name="value"><xsl:value-of select="$offs"/></xsl:attribute-->
      </input>

      <label>
        <xsl:attribute name="for"><xsl:value-of select="$pfx"/>_nres</xsl:attribute>
        Show
      </label>
      <select name="limit">
        <xsl:attribute name="id"><xsl:value-of select="$pfx"/>_nres</xsl:attribute>
        <xsl:call-template name="render-limit-opts">
          <xsl:with-param name="lim-list">20 50 100 150 200 300 400 500</xsl:with-param>
          <xsl:with-param name="limit" select="$limit"/>
        </xsl:call-template>
      </select>
      <span class="pager_stats">
        <xsl:value-of select="$offs"/> - <xsl:value-of select="$offs + $rowcnt - 1"/> <xsl:text> of </xsl:text>
	<xsl:value-of select="/facets/processed"/> <xsl:text> total&#8194;</xsl:text>
      </span>
	<button>
          <xsl:if test="$offs &lt;= 1">
            <xsl:attribute name="disabled">true</xsl:attribute>
          </xsl:if>
	  <xsl:attribute name="class">pager</xsl:attribute>
	  <xsl:attribute name="onclick">javascript:fct_pager_prev('<xsl:value-of select="$pfx"/>');</xsl:attribute>
          &#9664;
	</button>
	<button>
          <xsl:if test="not(($offs + $limit) &lt; /facets/processed)">
            <xsl:attribute name="disabled">true</xsl:attribute>
          </xsl:if>
	  <xsl:attribute name="class">pager</xsl:attribute>
	  <xsl:attribute name="onclick">javascript:fct_pager_next('<xsl:value-of select="$pfx"/>');</xsl:attribute>
          &#9654;
	</button>
    </form>
  </xsl:if>
</xsl:template> <!-- render-pager -->

<xsl:template name="render-result">
<div class="dbg"><xsl:value-of select="$view-type"/></div>
<table id="result_t">
  <xsl:attribute name="class">result <xsl:value-of select="$view-type"/></xsl:attribute>
  <thead>
    <xsl:choose>
      <xsl:when test="$view-type = 'properties'">
	<tr><th></th><th><xsl:value-of select="$p_term"/></th><!--th>Label</th--><th></th><th>Count</th></tr>
      </xsl:when>
      <xsl:when test="$view-type = 'list-count'">
	<tr><th></th><th><xsl:value-of select="$s_term"/></th><!--th>Title</th--><th></th><th>Count</th></tr>
      </xsl:when>
      <xsl:when test="$view-type = 'text-properties'">
	<tr><th></th><th><xsl:value-of select="$p_term"/></th><!--th>Label</th--><th></th><th>Count</th></tr>
      </xsl:when>
      <xsl:when test="$view-type = 'properties-in'">
	<tr><th></th><th><xsl:value-of select="$p_term"/></th><!--th>Label</th--><th></th><th>Count</th></tr>
      </xsl:when>
      <xsl:when test="$view-type = 'list'">
	<tr><th></th><th></th><th></th></tr>
      </xsl:when>
      <xsl:when test="$view-type = 'classes'">
	<tr><th></th><th><xsl:value-of select="$t_term"/></th><!--th>Label</th--><th></th><th>Count</th></tr>
      </xsl:when>
      <xsl:when test="$view-type = 'text' or $view-type = 'text-d'">
	<tr><th></th><th></th><th></th><th><xsl:value-of select="$s_term"/></th><th>Title</th><th>Named Graph</th></tr>
      </xsl:when>
      <xsl:when test="$view-type = 'text' or $view-type = 'propval-list'">
	<tr><th>Value</th><th>Datatype</th></tr>
      </xsl:when>
    </xsl:choose>
  </thead>
  <tbody>
    <xsl:for-each select="row">
      <tr>
	<xsl:choose>
          <xsl:when test="$view-type = 'entities-list'">
	    <xsl:if test="./@rank">
              <td>
                <xsl:value-of select="./@rank"/>
              </td>
            </xsl:if>
            <td>
              <xsl:call-template name="render-describe-link">
                <xsl:with-param name="uri" select="column[1]"/>
                <xsl:with-param name="content" select="column[2]"/>
              </xsl:call-template>
            </td>
          </xsl:when>
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
              <xsl:if test="$view-type = 'properties' or $view-type = 'classes'">
                <input type="checkbox" name="cb" value="{position (.)}" checked="true" onclick="javascript:fct_sel_neg (this)"/>
              </xsl:if>

              <!--xsl:message terminate="no">
                <xsl:value-of select="$query/query/class/@iri"/><xsl:text> | </xsl:text><xsl:value-of select="column[1]"/>
              </xsl:message-->

              <xsl:variable name="current_iri" select="column[1]"/>
              <xsl:variable name="use_iri">
                <xsl:choose>
                  <xsl:when test="not $query/query/class[@iri = $current_iri] and column[1]/@sparql_ser != ''">
                    <xsl:value-of select="urlify(column[1]/@sparql_ser)"/>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="urlify($current_iri)"/>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:variable>
              <xsl:comment><xsl:value-of select="$current_iri"/></xsl:comment>
            </td>
            <td>
              <a id="a_{position (.)}">
                <xsl:attribute name="class">sel_val</xsl:attribute>
                <xsl:attribute name="href">
                  <xsl:text>/fct/facet.vsp?cmd=</xsl:text>
                  <xsl:value-of select="$command"/>
                  <xsl:text>&amp;</xsl:text>
                  <xsl:choose>
                    <xsl:when test="'cond' = $command">cond_t=eq&amp;val=<xsl:value-of select="$use_iri"/></xsl:when>
                    <xsl:otherwise>iri=<xsl:value-of select="$use_iri"/></xsl:otherwise>
                  </xsl:choose>
                  <xsl:text>&amp;lang=</xsl:text>
                  <xsl:value-of select="column[1]/@xml:lang"/>
                  <xsl:text>&amp;datatype=</xsl:text>
                  <xsl:value-of select="urlify (column[1]/@datatype)"/>
                  <xsl:text>&amp;sid=</xsl:text>
                  <xsl:value-of select="$sid"/>
                </xsl:attribute> <!-- href -->
                <xsl:attribute name="title">
                  <xsl:value-of select="column[1]"/>
                </xsl:attribute>
                <xsl:choose>
                  <xsl:when test="'' != string (column[2])">
                    <xsl:value-of select="column[2]"/>
                  </xsl:when>
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
              <xsl:if test="'uri' = column[1]/@datatype or 'url' = column[1]/@datatype">
                <xsl:call-template name="render-describe-link">
                  <xsl:with-param name="uri" select="column[1]"/>
                  <xsl:with-param name="shortform" select="column[1]/@shortform"/>
                  <xsl:with-param name="content">Describe</xsl:with-param>
                </xsl:call-template>
              </xsl:if>
            </td>
            <xsl:if test="$view-type = 'list'">
              <td class="val_dt">
                <xsl:value-of select="column[1]/@datatype"/>
              </td>
            </xsl:if>
            <td>
              <xsl:apply-templates select="column[3]"/>
            </td>
	  </xsl:when>
          <xsl:otherwise> <!-- text matches view -->
            <td class="rnk">
              <xsl:for-each select="column[@datatype='trank' or @datatype='erank']">
                <img class="rnk">
                  <xsl:attribute name="src">
                    <xsl:text>images/r_</xsl:text><xsl:value-of select="min (floor(.), 10)"/><xsl:text>.png</xsl:text>
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
		  <xsl:when test="'uri' = ./@datatype or 'url' = ./@datatype">
                    <xsl:call-template name="render-describe-link">
                      <xsl:with-param name="uri" select="."/>
                      <xsl:with-param name="shortform" select="./@shortform"/>
                    </xsl:call-template>
		  </xsl:when>
                  <xsl:when test="'erank' = ./@datatype or 'trank' = ./@datatype">
                  </xsl:when>
		  <xsl:otherwise>
                    <xsl:apply-templates select="."/>
                  </xsl:otherwise>
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

<xsl:if test="/facets/result/@type='propval-list' or $view-type='list'">
  <form id="cond_form">
    <input type="hidden" name="sid"><xsl:attribute name="value"><xsl:value-of select="$sid"/></xsl:attribute></input>
    <input type="hidden" name="hi" id="out_hi"/>
    <input type="hidden" name="lo" id="out_lo"/>
    <input type="hidden" name="lang" id="out_lang"/>
    <input type="hidden" name="datatype" id="out_dtp"/>
    <input type="hidden" name="val" id="out_val"/>
    <input type="hidden" name="cmd" value="cond" id="cmd"/>
    <input type="hidden" name="cond_parms" id="cond_parms"/>
    Add condition:
    <select id="cond_type" name="cond_t">
      <option value="none">None</option>
      <option value="eq">==</option>
      <option value="neq">!=</option>
      <option value="gte">&gt;=</option>
      <option value="gt">&gt;</option>
      <option value="lte">&lt;=</option>
      <option value="lt">&lt;</option>
      <option value="range">Between</option>
      <option value="neg_range">Not Between</option>
      <option value="contains">Contains</option>
      <option value="in">In</option>
      <option value="not_in">Not In</option>
    </select>
    <span id="cond_inp_ctr" style="display:none">
      <!--label for="ckb_neg" class="ckb">Negation:</label><input type="checkbox" name="neg" id="ckb_neg"/-->
      <input id="cond_lo" type="text"/>
      <span id="cond_hi_ctr"> and <input id="cond_hi" type="text"/></span> <select id="cond_dt"></select>
      <input type="button" id="set_cond" value="Set Condition"/>
    </span>
    <div id="in_ctr" style="display:none"></div>
    <div id="geo_ctr" style="display:none"></div>
  </form>
</xsl:if>

<xsl:call-template name="render-init-func">
  <xsl:with-param name="result" select="/facets/result"/>
</xsl:call-template>

</xsl:template> <!-- render-result -->

<xsl:template name="render-describe-link">
  <xsl:param name="uri"/>
  <xsl:param name="shortform"/>
  <xsl:param name="content"/>
  <xsl:param name="marker"/>
  <!--xsl:message terminate="no">"<xsl:value-of select="content"/>"</xsl:message-->
  <a>
    <xsl:attribute name="href">
      <xsl:text>/describe/?url=</xsl:text>
      <xsl:value-of select="urlify ($uri)"/>
      <xsl:text>&amp;sid=</xsl:text>
      <xsl:value-of select="$sid"/>
    </xsl:attribute>
    <xsl:attribute name="class">describe</xsl:attribute>
    <xsl:attribute name="title">
      <xsl:choose>
        <xsl:when test="$shortform">
          <xsl:value-of select="$shortform"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$uri"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:attribute>
    <xsl:choose>
      <xsl:when test="$content=''">
        <xsl:choose>
          <xsl:when test="$shortform != ''">
            <xsl:value-of select="$shortform"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="$uri"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$content"/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:value-of select="$marker"/>
  </a>
</xsl:template> <!-- render-describe-link -->

<xsl:template name="render-geo-conds-ui">
  <!--xsl:message terminate="no">In render-geo-conds-ui. type=<xsl:value-of select="$type"/></xsl:message-->
  <xsl:param name="result"/>
  <xsl:if test="$type='geo' or $type='geo-list'">
    <div id="user_map"></div>
    <form id="cond_form">
      <input type="hidden" name="sid"><xsl:attribute name="value"><xsl:value-of select="$sid"/></xsl:attribute></input>
      <input type="hidden" name="cmd" value="cond" id="cmd"/>
      <input type="hidden" name="cno" value="" id="cno"/>
      <input type="hidden" name="cond_t" value="near" id="cond_t"/>
      <label for="cond_distance">Within: </label>
      <input name="dist" id="cond_dist" type="text" size="5"/> km of
      <select name="loc_trig_sel" id="loc_trig_sel">
        <option>Coordinates</option>
        <option value="on">Autolocation</option>
      </select>
      <span id="loc_ctr">
        <img src="images/notify-throbber.gif" alt="Locating..." id="loc_acq_thr_i" style="display:none"/>
        <input id="cond_loc" type="text" style="display:none"/>
      </span>
      <span id="coord_ctr">
        <!--label for="ckb_neg" class="ckb">Negation:</label><input type="checkbox" name="neg" id="ckb_neg"/-->
        <label for="cond_lat">Lat:</label>
        <input name="lat" id="cond_lat" type="text" size="9"/>
        <label for="cond_lon">Lon:</label>
        <input name="lon" id="cond_lon" type="text" size="9"/>
        <label for="cond_acc">Accuracy</label>
        <input id="cond_acc" type="text" size="6" disabled="true"/>
      </span>
      <button id="cond_loc_acq_b">Acquire</button>
      <button id="cond_loc_use_b">Set condition</button>
    </form>
  </xsl:if>
</xsl:template> <!-- render-geo-conds-ui -->

<xsl:template name="render-init-func">
  <xsl:param name="result"/>
  <!--xsl:message terminate="no">In render-init-func: type=<xsl:value-of select="$type"/></xsl:message-->
  <script type="text/javascript" >
    <xsl:if test="$type='geo' or $type='geo-list'">
OAT.Preferences.imagePath = "oat/images/";
function markerClickHandler (caller, msg, m) {
  var c = m.__fct_bubble_content;

  var x;
  if (c[0].length > 0) {
    x = OAT.Dom.create ("a");
    x.href = '/describe/?url='+escape (c[0]);
    if (c[1].length > 0)
      x.innerHTML = c[1];
    else
      x.innerHTML = c[0];
    }
    else x = OAT.Dom.text(c[1]);
  window.cMap.openWindow (m, x);
}
    </xsl:if>

function init() {

    <xsl:if test="$type='geo' or $type='geo-list'">
  window.cMap = {};
  var mapcb = function() {
    window.cMap.init(OAT.Map.TYPE_G3);
    window.cMap.centerAndZoom(0,0,0);
    window.cMap.setMapType(OAT.Map.MAP_HYB);
    OAT.MSG.attach ("*", "MAP_MARKER_CLICK", markerClickHandler);
    var markersArr = [];
      <xsl:for-each select="$result/row">
      <!--xsl:message terminate="no"><xsl:value-of select="."/></xsl:message-->
        window.cMap.addMarker(<xsl:value-of select="column[3]"/>,
                              <xsl:value-of select="column[4]"/>,
                              false,
                              {image: "oat/images/markers/01.png",
                               imageSize: [18,41],
                               custData: {__fct_bubble_content: ["<xsl:value-of select="column[1]"/>",
	                                                         "<xsl:value-of select='translate (normalize-space (column[2]), &apos;"&apos;, &apos;&apos;)'/>"]}});
        markersArr.push([<xsl:value-of select="column[3]"/>,<xsl:value-of select="column[4]"/>]);
      </xsl:for-each>
    fct_add_loc_marker ();
    window.cMap.optimalPosition(markersArr);
    window.cMap.showMarkers(false);
    return;
  }

  window.YMAPPID = "";
  var providerType = OAT.Map.TYPE_G3;
  window.cMap = new OAT.Map($('user_map'),providerType,{fix:OAT.Map.FIX_ROUND1});
  OAT.Map.loadApi(providerType, {callback: mapcb});
  window.geo_ui = new Geo_ui ('cond_form');

  var acq_trig = $('acq_l_trig');

  if (acq_trig) {
    window.geo_ui.loc_update(parseInt(acq_trig.innerHTML));
  }
    </xsl:if>
    <xsl:if test="$addthis_key != ''">
    </xsl:if>
  fct_init_ui();
}<!-- init -->
  </script>
  <xsl:if test="$addthis_key != ''">
  <script type="text/javascript">
  var addthis_config = {
    "data_track_clickback":true,
    ui_cobrand:"OpenLink Virtuoso",
    pubid: "<xsl:value-of select="$addthis_key"/>"
  };
var addthis_share = {
  url:  window.location.protocol + '//' + window.location.host + window.location.pathname + '?qxml=<xsl:value-of select="urlify ($p_xml)"/>',
  title: "Faceted browser permalink",
  Description: "This is a permalink to an OpenLink Faceted Browsing service page."
};
  </script>
  <script type="text/javascript" src="http://s7.addthis.com/js/250/addthis_widget.js"></script>
  </xsl:if>
</xsl:template>

<xsl:template match="@* | node()">
  <xsl:copy>
    <xsl:apply-templates select="@* | node()"/>
  </xsl:copy>
</xsl:template>

</xsl:stylesheet>
