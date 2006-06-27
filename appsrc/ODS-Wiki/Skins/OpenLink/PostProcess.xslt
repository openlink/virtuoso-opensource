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
    <html>
 <header>	
  <title><xsl:value-of select="$ti_cluster_name"/>.<xsl:value-of select="$ti_local_name"/></title>
  <link rel="stylesheet" href="{$baseadjust}../resources/Skins/OpenLink/default.css" type="text/css"></link>
  <link rel="alternate" type="application/rss+xml" title="Changelog (RSS 2.0)" href="{$baseadjust}../resources/gems.vsp?cluster={$ti_cluster_name}&amp;type=rss20"></link>
  <link rel="alternate" type="application/rss+xml" title="Changelog (ATOM)" href="{$baseadjust}../resources/gems.vsp?cluster={$ti_cluster_name}&amp;type=atom"></link>
  <link rel="alternate" type="application/rss+xml" title="Changelog (RDF)" href="{$baseadjust}../gems.vsp?cluster={$ti_cluster_name}&amp;type=rdf"></link>
	<link rel="self" type="application/atom+xml"
	  href="/wiki/Atom"/>
 </header>
 <body>
	<div id="page">
	  <div id="header">
	    <xsl:attribute name="style">background-image: url(<xsl:value-of select="wv:ResourceHREF ('images/wikibanner_sml.jpg', $baseadjust)"/>)</xsl:attribute>
  <div class="login-area">
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
          <a>
            <img border="0" alt="ATOM" title="ATOM" src="{wv:ResourceHREF ('images/atom03.gif', $baseadjust)}"></img>
            <xsl:attribute name="href"><xsl:value-of select="wv:ResourceHREF2 ('gems.vsp',$baseadjust,vector('type','atom','cluster', $ti_cluster_name))"/></xsl:attribute>		
          </a>
        </li>
        <li>
          <a>
            <img border="0" alt="RSS" title="RSS" src="{wv:ResourceHREF ('images/rss20.gif', $baseadjust)}"></img>
		    <xsl:attribute name="href">
		      <xsl:value-of select="wv:ResourceHREF2 ('gems.vsp',$baseadjust,vector('type','rss20','cluster', $ti_cluster_name))"/>
		    </xsl:attribute>		
          </a>
        </li>
        <li>
          <a>
            <img border="0" alt="RDF" title="RDF" src="{wv:ResourceHREF ('images/rdf.gif', $baseadjust)}"></img>
		    <xsl:attribute name="href">
		      <xsl:value-of select="wv:ResourceHREF2 ('gems.vsp',$baseadjust,vector('type','rdf','cluster', $ti_cluster_name))"/>
		    </xsl:attribute>		
          </a>
        </li>
      </ul>
	      <h3>Site Changes</h3>
      <ul>
        <li>
          <a>
            <img border="0" alt="ATOM" title="ATOM" src="{wv:ResourceHREF ('images/atom03.gif', $baseadjust)}"></img>
            <xsl:attribute name="href"><xsl:value-of select="wv:ResourceHREF2 ('gems.vsp',$baseadjust,vector('type','atom'))"/></xsl:attribute>		
          </a>
        </li>
        <li>
          <a>
            <img border="0" alt="RSS" title="RSS" src="{wv:ResourceHREF ('images/rss20.gif', $baseadjust)}"></img>
            <xsl:attribute name="href"><xsl:value-of select="wv:ResourceHREF2 ('gems.vsp',$baseadjust,vector('type','rss20'))"/></xsl:attribute>		
          </a>
        </li>
        <li>
          <a>
            <img border="0" alt="RDF" title="RDF" src="{wv:ResourceHREF ('images/rdf.gif', $baseadjust)}"></img>
            <xsl:attribute name="href"><xsl:value-of select="wv:ResourceHREF2 ('gems.vsp',$baseadjust,vector('type','rdf'))"/></xsl:attribute>		
          </a>
        </li>
      </ul>
    </div>
	    <!--xsl:apply-templates select="//div[@id='virtuoso-info']"/--> 
  </div>
	  <div id="main">
	    <div id="wiki-path">You are here: <xsl:copy-of select="//div[@class='wiki-nav-container']"/></div>
	    <div id="content">
	      <xsl:copy-of select="//div[@id='content']/."/>
	      <div id="node-footer">
		Modified by <xsl:copy-of select="//span[@id='top-mod-by']"/> at <xsl:copy-of select="//span[@id='top-mod-time']"/>
	      </div>
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
