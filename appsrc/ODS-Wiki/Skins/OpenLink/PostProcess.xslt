<?xml version="1.0"?>
<!--
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2006 OpenLink Software
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
    />
  <!-- new clean stylesheet (ghard)-->
  <xsl:include href="../../common.xsl"/>
  <xsl:template match="/">
  <xsl:param name="ti_cluster_name"/>
  <xsl:param name="baseadjust"/>
  <xsl:param name="sid"/>
  <xsl:param name="realm"/>
    <xsl:param name="ods-bar"/>
    <xsl:param name="geo_lat"/>
    <xsl:param name="geo_lng"/>
    <xsl:param name="geo_link"/>
    <html>
      <head profile="http://internetalchemy.org/2003/02/profile">
        <!-- FOAF link if exists -->
        <xsl:copy-of select="//link"/>
  <title><xsl:value-of select="$ti_cluster_name"/>.<xsl:value-of select="$ti_local_name"/></title>
	<link rel="stylesheet" href="{wv:ResourceHREF('Skins/OpenLink/default.css', $baseadjust)}" type="text/css"></link>
	<link rel="alternate" type="application/rss+xml" title="Changelog (RSS 2.0)" href="{wv:ResourceHREF(concat('gems.vsp?cluster=', $ti_cluster_name, '&amp;type=rss20'), $baseadjust)}"></link>
	<link rel="alternate" type="application/rss+xml" title="Changelog (ATOM)" href="{wv:ResourceHREF(concat ('gems.vsp?cluster=', $ti_cluster_name, '&amp;type=atom'), $baseadjust)}"></link>
	<link rel="alternate" type="application/rss+xml" title="Changelog (RDF)" href="{wv:ResourceHREF(concat('gems.vsp?cluster=', $ti_cluster_name, '&amp;type=rdf'), $baseadjust)}"></link>
	<link rel="self" type="application/atom+xml"
	  href="/wiki/Atom"/>
	<link rel="meta" type="application/rdf+xml" title="SIOC" href="{wv:sioc_uri($ti_cluster_name)}" />
	<link rel="service.post" type="application/x.atom+xml"
	      href="{wv:atom_pub_uri($ti_cluster_name)}"/>
        <meta name="dc.title" content="{$ti_abstract}" />
        <meta name="dc.description" content="{$ti_abstract}" />
        <xsl:if test="$geo_lng and $geo_lat">
          <meta name="ICBM" content="{$geo_lng}, {$geo_lat}" />
          <meta name="geo.position" content="{$geo_lng}; {$geo_lat}" />
        </xsl:if>
      </head>
 <body>
	<div id="page">
	  <div id="header">
            <xsl:copy-of select="$ods-bar"/>
	    <!--   <img>
              <xsl:attribute name="src"><xsl:value-of select="wv:ResourceHREF ('images/wikibanner_sml.jpg', $baseadjust)"/></xsl:attribute>
	    </img> -->

	    <!--xsl:attribute name="style">background-image: url(<xsl:value-of select="wv:ResourceHREF ('images/wikibanner_sml.jpg', $baseadjust)"/>)</xsl:attribute-->
	    <div class="login-area" style="display: none">
    <xsl:apply-templates select="//img[@id='login-image']"/>
    <xsl:apply-templates select="//a[@id='login-link']"/>
    <xsl:if test="not $sid">
      User is not authenticated
    </xsl:if>
    <xsl:apply-templates select="//form[@id='login-form']"/>
	    </div>
  </div>
	  <ul class="menu">
	    <li>
          <a href="{wv:registry_get ('wa_home_link', '/wa/')}/?sid={$sid}&realm={$realm}">
            <xsl:value-of select="wv:registry_get('wa_home_title', 'OPS Home')"/>
          </a>
	    </li>
	    <li>
          <xsl:copy-of select="//a[@id='user-settings-link']"/>
	    </li>
	    <li>
          <xsl:copy-of select="//a[@id='cluster-settings-link']"/>
	    </li>
	    <li>
          <xsl:copy-of select="//a[@id='advanced-search-link']"/>
	    </li>
	    <li>
          <xsl:copy-of select="//form[@id='search-form']"/>
	    </li>
	    <li>
	      | <xsl:copy-of select="//a[@id='users-link']"/>
	    </li>
	  </ul>
	  <div id="sidebar">
	    <div id="main-tab" class="portlet">
	      <h3>View</h3>
      <ul>
		<xsl:apply-templates select="//li[@id='wiki-nstab-main']"/>
		<xsl:apply-templates select="//li[@id='wiki-nstab-talks']"/>
		<xsl:for-each select="//div[@class='wiki-source-type']">
		  <xsl:element name="li">
		    <xsl:copy-of select="a"/>
		  </xsl:element> 
		</xsl:for-each>
	      </ul>
	    </div>
	    <div class="feed-container">
	      <h3>Cluster changes</h3>
	      <ul>
        <li>
                  <img border="0" alt="ATOM" title="ATOM" src="{wv:ResourceHREF ('images/atom-icon-16.gif', $baseadjust)}"></img>
          <a>
            <xsl:attribute name="href"><xsl:value-of select="wv:ResourceHREF2 ('gems.vsp',$baseadjust,vector('type','atom','cluster', $ti_cluster_name))"/></xsl:attribute>		
                    Atom 1.0
          </a>
        </li>
        <li>
                  <img border="0" alt="RSS" title="RSS" src="{wv:ResourceHREF ('images/rss-icon-16.gif', $baseadjust)}"></img>
          <a>
		    <xsl:attribute name="href">
		      <xsl:value-of select="wv:ResourceHREF2 ('gems.vsp',$baseadjust,vector('type','rss20','cluster', $ti_cluster_name))"/>
		    </xsl:attribute>		
                    RSS 2.0
          </a>
        </li>
        <li>
                  <img border="0" alt="RDF" title="RDF" src="{wv:ResourceHREF ('images/rdf-icon-16.gif', $baseadjust)}"></img>
          <a>
		    <xsl:attribute name="href">
		      <xsl:value-of select="wv:ResourceHREF2 ('gems.vsp',$baseadjust,vector('type','rdf','cluster', $ti_cluster_name))"/>
		    </xsl:attribute>		
                    RDF
          </a>
        </li>
      </ul>
	      <h3>Site Changes</h3>
      <ul>
        <li>
                  <img border="0" alt="ATOM" title="ATOM" src="{wv:ResourceHREF ('images/atom-icon-16.gif', $baseadjust)}"></img>
          <a>
            <xsl:attribute name="href"><xsl:value-of select="wv:ResourceHREF2 ('gems.vsp',$baseadjust,vector('type','atom'))"/></xsl:attribute>		
                    Atom 1.0
          </a>
        </li>
        <li>
                  <img border="0" alt="RSS" title="RSS" src="{wv:ResourceHREF ('images/rss-icon-16.gif', $baseadjust)}"></img>
          <a>
            <xsl:attribute name="href"><xsl:value-of select="wv:ResourceHREF2 ('gems.vsp',$baseadjust,vector('type','rss20'))"/></xsl:attribute>		
                    RSS 2.0
          </a>
        </li>
        <li>
                  <img border="0" alt="RDF" title="RDF" src="{wv:ResourceHREF ('images/rdf-icon-16.gif', $baseadjust)}"></img>
          <a>
            <xsl:attribute name="href"><xsl:value-of select="wv:ResourceHREF2 ('gems.vsp',$baseadjust,vector('type','rdf'))"/></xsl:attribute>		
                    RDF
          </a>
        </li>
      </ul>
              <h3>Pings</h3>
              <ul>
                <xsl:if test="$geo_link">
                  <li>
                    <a>
                      <xsl:attribute name="href">http://geourl.org/near?p=<xsl:value-of select="$geo_link"/></xsl:attribute>
                      <img src="http://i.geourl.org/geourl.png" border="0"/>
                    </a>
                  </li>
                </xsl:if>
              </ul>
    </div>
	    <!--xsl:apply-templates select="//div[@id='virtuoso-info']"/--> 
  </div>
	  <div id="main">
	    <div id="wiki-path">You are here: <xsl:copy-of select="//div[@class='wiki-nav-container']"/></div>
	    <div id="content">
	      <xsl:copy-of select="//div[@id='content']/."/>
              <xsl:if test="//span[@id='top-mod-by']">
	      <div id="node-footer">
		Modified by <xsl:copy-of select="//span[@id='top-mod-by']"/> at <xsl:copy-of select="//span[@id='top-mod-time']"/>
	      </div>
              </xsl:if>
    </div>
	  </div>
	  <div id="footer">
    <xsl:apply-templates select="//div[@id='wiki-toolbar-container']"/>
  </div>
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
