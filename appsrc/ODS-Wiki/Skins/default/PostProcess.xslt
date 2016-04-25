<?xml version="1.0"?>
<!--
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2016 OpenLink Software
 -
 -  This project is free software; you can redistribute it and/or modify it
 -  under the terms of the GNU General Public License as published by the
 -  Free Software Foundation; only version 2 of the License, dated June 1991.
 -
 -  This program is distributed in the hope that it will be useful, but
 -  WITHOUT ANY WARRANTY; without even the implied warranty of
 -  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 -  General Public License for more details.
 -
 -  You should have received a copy of the GNU General Public License along
 -  with this program; if not, write to the Free Software Foundation, Inc.,
 -  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 -
 -
-->

<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xhtml="http://www.w3.org/TR/xhtml1/strict"
                xmlns:wv="http://www.openlinksw.com/Virtuoso/WikiV/"
                xmlns:fn2="http://www.w3.org/2004/07/xpath-functions">

<!-- $Id$ -->

  <xsl:output
    method="html"
   encoding="UTF-8"
   indent="yes"/>
  <!-- new clean stylesheet (ghard)-->
  <xsl:include href="../../common.xsl"/>
  <xsl:template match="/">
    <xsl:param name="ti_cluster_name"/>
    <xsl:param name="baseadjust"/>
    <xsl:param name="sid"/>
    <xsl:param name="realm"/>
  <xsl:param name="ods-bar"/>
    <xsl:param name="ods-app"/>
    <xsl:param name="tree"/>
    <xsl:param name="tree_content"/>
    <xsl:param name="command"/>


    <html>
    <head>	
	<title><xsl:value-of select="$ti_cluster_name"/>.<xsl:value-of select="$ti_local_name"/></title>
      <base href="{wv:WikiClusterURI ($ti_cluster_name)}{$ti_local_name}" />
      <link rel="stylesheet" 
            href="{wv:ResourceHREF('Skins/default/default.css', $baseadjust)}" 
            type="text/css"></link>
      <link rel="alternate" 
            type="application/rss+xml" 
            title="Changelog (RSS 2.0)" 
            href="{wv:ResourceHREF(concat('gems.vsp?cluster=', $ti_cluster_name, '&amp;type=rss20'), $baseadjust)}"></link>
      <link rel="alternate" 
            type="application/atom+xml"
            title="Changelog (ATOM)" 
            href="{wv:ResourceHREF(concat('gems.vsp?cluster=', $ti_cluster_name, '&amp;type=atom'), $baseadjust)}"></link>
      <link rel="alternate" 
            type="application/rss+xml" 
            title="Changelog (RDF)" 
            href="{wv:ResourceHREF(concat('gems.vsp?cluster=', $ti_cluster_name, '&amp;type=rdf'), $baseadjust)}"></link>
      <link rel="self" 
            type="application/atom+xml"
	  href="/wiki/Atom"/>
      <link rel="meta" 
            type="application/rdf+xml" 
            title="SIOC" 
            href="{wv:sioc_uri($ti_cluster_name)}" />
      <link rel="service.post" 
            type="application/x.atom+xml"
	      href="{wv:atom_pub_uri($ti_cluster_name)}"/>
      <link rel="alternate"
            type="application/atomserv+xml"
            href="{wv:atom_pub_uri($ti_cluster_name)}/intro"/>
      <xsl:value-of select="wv:rdfLinksHead($ti_cluster_name, $ti_local_name)" disable-output-escaping="yes" />
	<xsl:copy-of select="$ods-app"/>
    </head>
      <body>
	<div id="page">
	<div id="head">
            <xsl:copy-of select="$ods-bar"/>
<!--xsl:attribute name="style">background-image: url(<xsl:value-of select="wv:ResourceHREF ('images/wikibanner_sml.jpg', $baseadjust)"/>)</xsl:attribute-->
          <div class="login-area" style="display: none">
	      <xsl:apply-templates select="//img[@id='login-image']"/>
	      <xsl:apply-templates select="//a[@id='login-link']"/>
	      <xsl:if test="not $sid">
		User is not authenticated
	      </xsl:if>
	      <xsl:apply-templates select="//form[@id='login-form']"/>
	  </div>
          <div id="hdr-search-form-ctr">
            <xsl:copy-of select="//form[@id='search-form']"/>
              &nbsp;|&nbsp;
              <xsl:copy-of select="//a[@id='advanced-search-link']"/>
              &nbsp;
          </div>
        </div> <!-- head -->
	  <div id="mid">
	    <div id="wiki-path">
              <xsl:copy-of select="//div[@class='wiki-nav-container']"/>
            </div>
          <div id="head-cols">
            <xsl:if test="$command != 'refby' and $command != 'refby-all' and $command != 'index' and $command != 'diff'">
              <div class="row" style="display:none">
                <ul>
                  <li>
                    <xsl:choose>
              	      <xsl:when test="$tree='show'">
                  	    <xsl:call-template name="wikiref">
                  	      <xsl:with-param name="wikiref_params"><xsl:value-of select="wv:pair('command', 'hidetree')"/></xsl:with-param>
                  	      <xsl:with-param name="wikiref_cont">HideTree</xsl:with-param>
                  	    </xsl:call-template>
                  	  </xsl:when>
                  	  <xsl:otherwise>
                  	    <xsl:call-template name="wikiref">
                  	      <xsl:with-param name="wikiref_params"><xsl:value-of select="wv:pair('command', 'showtree')"/></xsl:with-param>
                  	      <xsl:with-param name="wikiref_cont">ShowTree</xsl:with-param>
                  	    </xsl:call-template>
                  	  </xsl:otherwise>
                  	</xsl:choose>
                  	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
                  </li>
                </ul>
                </div>
              </xsl:if>
            <div class="row">
	      <ul>
                <li>
                  <b>This Page:</b>
                </li>
		<xsl:for-each select="//div[@class='wiki-source-type']">
		  <xsl:element name="li">
		    <xsl:copy-of select="a"/>
		  </xsl:element> 
		</xsl:for-each>
	      </ul>
              <ul>
                  <xsl:apply-templates select="//li[@id='wiki-nstab-main']"/>
                  <xsl:apply-templates select="//li[@id='wiki-nstab-talks']"/>
              </ul>
            </div> <!-- row This Page -->
            <div class="row">
    	        <ul>
    	          <li>
    	            <b>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Tools:</b>
    	          </li>
    	          <!--li>
                  <a href="{wv:registry_get ('wa_home_link', '/wa/')}/?sid={$sid}&realm={$realm}">
                    <xsl:value-of select="wv:registry_get('wa_home_title', 'OPS Home')"/>
                  </a>
    	          </li-->
    	          <li>
                  <xsl:copy-of select="//a[@id='user-settings-link']"/>
    	          </li>
                <li>
                  <xsl:copy-of select="//a[@id='cluster-settings-link']"/>
    	          </li>
          		  <li>
          		    <xsl:copy-of select="//a[@id='users-link']"/>
          		  </li>
          		  <li>
                  <xsl:copy-of select="//a[@id='macros-link']"/>
                </li>
  	          </ul>
            </div> <!-- row Tools -->
          </div> <!-- head-menus -->
          &nbsp;
          <xsl:choose>
    	      <xsl:when test="$tree='show'">
            	<div id="cluster-tree-content">
                <div style="float:left; width: 13%; overflow:auto">
                  <br />
                  <xsl:copy-of select="$tree_content"/>
                </div>
                <div style="float:right; width:87%">
                  <xsl:apply-templates select="//div[@id='content']/."/>
                  <xsl:if test="//span[@id='top-mod-by']">
                    <div id="node-footer">
                      Modified by
                      <xsl:copy-of select="//span[@id='top-mod-by']"/> at
                      <xsl:copy-of select="//span[@id='top-mod-time']"/>
                    </div>
                  </xsl:if>
                  <xsl:copy-of select="//div[@id='wiki-toolbar-container']"/>
                </div>
              </div>
        	  </xsl:when>
        	  <xsl:otherwise>
        	    <xsl:apply-templates select="//div[@id='content']/."/>
        	    <xsl:if test="//span[@id='top-mod-by']">
          	    <div id="node-footer">
                  Modified by
                  <xsl:copy-of select="//span[@id='top-mod-by']"/> at
                  <xsl:copy-of select="//span[@id='top-mod-time']"/>
                </div>
              </xsl:if>
              <xsl:copy-of select="//div[@id='wiki-toolbar-container']"/>
        	  </xsl:otherwise>
        	</xsl:choose>
          <br style="clear: both"/>

  	    </div> <!-- mid -->
  	    <div id="foot">

          <div id="foot-cols-ctr">
<!--xsl:apply-templates select="//div[@id='virtuoso-info']"/--> 
              <div class="col">
	      <h3>Cluster changes</h3>
	      <ul>
		<li>
                    <img border="0" 
                         alt="ATOM" 
                         title="ATOM" 
                         src="{wv:ResourceHREF ('images/atom-icon-12.png', $baseadjust)}">
                    </img>
		  <a>
                      <xsl:attribute name="href">
                        <xsl:value-of select="wv:ResourceHREF2 ('gems.vsp',
                                                                $baseadjust, 
                                                                vector ('type','atom','cluster', $ti_cluster_name))"/>
                      </xsl:attribute>		
                    Atom 1.0
		  </a>
		</li>
		<li>
                    <img border="0" 
                         alt="RSS" 
                         title="RSS" 
                         src="{wv:ResourceHREF ('images/rss-icon-12.png', $baseadjust)}"></img>
		  <a>
		    <xsl:attribute name="href">
		      <xsl:value-of select="wv:ResourceHREF2 ('gems.vsp',$baseadjust,vector('type','rss20','cluster', $ti_cluster_name))"/>
		    </xsl:attribute>		
                    RSS 2.0
		  </a>
		</li>
		<li>
                    <img border="0" 
                         alt="RDF" 
                         title="RDF" 
                         src="{wv:ResourceHREF ('images/rdf-icon-12.png', $baseadjust)}"></img>
		  <a>
		    <xsl:attribute name="href">
		      <xsl:value-of select="wv:ResourceHREF2 ('gems.vsp',$baseadjust,vector('type','rdf','cluster', $ti_cluster_name))"/>
		    </xsl:attribute>		
                    RDF
		  </a>
		</li>
                  <li>
                    <img border="0"
                       alt="SIOC (RDF/XML)"
                       title="SIOC (RDF/XML)"
                       src="{wv:ResourceHREF ('images/rdf-icon-12.png', $baseadjust)}"></img>
                  <a>
          		      <xsl:attribute name="href">
          		        <xsl:value-of select="wv:ClusterIRI ($ti_cluster_name)"/>/sioc.rdf
          		      </xsl:attribute>
                    SIOC (RDF/XML)
                  </a>
                </li>
                <li>
                  <img border="0"
                       alt="SIOC (N3/Turtle)"
                       title="SIOC (N3/Turtle)"
                       src="{wv:ResourceHREF ('images/rdf-icon-12.png', $baseadjust)}"></img>
                  <a>
          		      <xsl:attribute name="href">
          		        <xsl:value-of select="wv:ClusterIRI ($ti_cluster_name)"/>/sioc.ttl
          		      </xsl:attribute>
                    SIOC (N3/Turtle)
                  </a>
                </li>
                <li>
                  <img border="0"
                         alt="Wiki Profile"
                         title="Wiki Profile"
                         src="{wv:ResourceHREF ('images/rdf-icon-12.png', $baseadjust)}"></img>
                    <a>
		      <xsl:attribute name="href">
		        <xsl:value-of select="wv:ResourceHREF2 ('gems.vsp',$baseadjust,vector('type','wiki_profile','cluster', $ti_cluster_name))"/>
		      </xsl:attribute>
                      Wiki Profile
                    </a>
                  </li>
	      </ul>
              </div>
              <div class="col">
	      <h3>Site Changes</h3>
	      <ul>
		<li>
                    <img border="0" 
                         alt="ATOM" 
                         title="ATOM" 
                         src="{wv:ResourceHREF ('images/atom-icon-12.png', $baseadjust)}"></img>
		  <a>
                      <xsl:attribute name="href">
                        <xsl:value-of select="wv:ResourceHREF2 ('gems.vsp',$baseadjust,vector('type','atom'))"/>
                      </xsl:attribute>		
                    Atom 1.0
		  </a>
		</li>
		<li>
                    <img border="0" 
                         alt="RSS" 
                         title="RSS" 
                         src="{wv:ResourceHREF ('images/rss-icon-12.png', $baseadjust)}"></img>
		  <a>
                      <xsl:attribute name="href">
                        <xsl:value-of select="wv:ResourceHREF2 ('gems.vsp',$baseadjust,vector('type','rss20'))"/>
                      </xsl:attribute>		
                    RSS 2.0
		  </a>
		</li>
		<li>
                    <img border="0" 
                         alt="RDF" 
                         title="RDF" 
                         src="{wv:ResourceHREF ('images/rdf-icon-12.png', $baseadjust)}"></img>
		  <a>
                      <xsl:attribute name="href">
                        <xsl:value-of select="wv:ResourceHREF2 ('gems.vsp',$baseadjust,vector('type','rdf'))"/>
                      </xsl:attribute>		
                    RDF
		  </a>
		</li>
	      </ul>
              </div> <!-- col -->
            </div> <!-- foot-col-ctr -->
            <div class="debug-info">Default PostProcess.xslt</div>
          </div> <!-- foot -->
	</div> <!-- page -->
      </body>
    </html>

  </xsl:template>

  <xsl:template match="node()">
    <xsl:copy>
      <xsl:copy-of select="@*" />
      <xsl:apply-templates select="node()" />
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
<!-- Keep this comment at the end of the file
Local variables:
mode: xml
sgml-omittag:nil
sgml-shorttag:nil
sgml-namecase-general:nil
sgml-general-insert-case:lower
sgml-minimize-attributes:nil
sgml-always-quote-attributes:t
sgml-indent-step:2
sgml-indent-data:t
sgml-parent-document:nil
sgml-exposed-tags:nil
sgml-local-catalogs:nil
sgml-local-ecat-files:nil
End:
-->
