<?xml version="1.0" encoding="ISO-8859-1" ?>
<!-- <!DOCTYPE html  PUBLIC "" "ent.dtd"> -->
<!----
 -  
 -  $Id$
 -
 -   Virtuoso VSPX XSL-T style-sheet for page class compilation
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2017 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     version="1.0"
     xmlns:v="http://www.openlinksw.com/vspx/"
     xmlns:xhtml="http://www.w3.org/1999/xhtml"
     xmlns:vm="http://www.openlinksw.com/vspx/macro">

<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>

<xsl:variable name="page_title" select="string (//vm:pagetitle)" />


<xsl:template match="head/title[string(.)='']" priority="100">
  <title><xsl:value-of select="$page_title" /></title>
</xsl:template>


<xsl:template match="head/title">
  <title><xsl:value-of select="replace(string(.),'!page_title!',$page_title)" /></title>
</xsl:template>

<xsl:template match="vm:pagetitle" />

<xsl:template match="vm:popup_page_wrapper">
  <xsl:apply-templates select="node()|processing-instruction()" />
  <div class="copyright">Virtuoso Universal Server <?V sys_stat('st_dbms_ver') ?>. Copyright &amp;copy; 1998-<?V "LEFT" (datestring (now()), 4)?> OpenLink Software</div>
</xsl:template>

<xsl:template match="vm:pagewrapper">
       <xsl:element name="v:variable">
         <xsl:attribute name="persist">0</xsl:attribute>
          <xsl:attribute name="name">page_owner</xsl:attribute>
          <xsl:attribute name="type">varchar</xsl:attribute>
       </xsl:element>
      <xsl:for-each select="//v:variable">
        <xsl:copy-of select="."/>
      </xsl:for-each>
      <xsl:apply-templates select="vm:init"/>
      <div class="masthead">
        <table width="100%"  border="0" cellpadding="0" cellspacing="0">
          <tr>
            <td colspan="2"><img src="openlink150.gif" alt="" name="" width="150"/></td>
            <!--td align="right">
              <div class="m_z">
	        <a class="m_z" href="/bpel4ws/interop/interop.vsp">Interop Home</a> |
                <a class="m_z" href="http://www.openlinksw.com/index.htm">OpenLink Home</a> |
                <a class="m_z" href="http://www.openlinksw.com/main/company.htm">About Us</a> |
                <a class="m_z" href="http://www.openlinksw.com/main/search.vsp">Search</a>
              </div>
            </td-->
          </tr>
        </table>
      </div>
      <table id="MT" width="100%">
        <tbody>
          <tr>
            <td id="LB" width="10%" class="left_nav" valign="top">
              <table id="NT" width="100%">
                <tbody>
                  <tr>
                    <td>
                      <table class="lnav_container">

                        <tr><td><a href="/BPELGUI/">OpenLink BPEL Process Manager</a></td></tr>
                        <tr><td><img src="vglobe_16.png" alt="Start" title="Start Menu" /><a href="/">Virtuoso Start Menu</a></td></tr>
                        <tr><td><a href="/doc/docs.vsp">Check<br>Documentation</br></a></td></tr>
                        <tr><td><a href="/BPELDemo/">Virtuoso BPEL Tutorials</a></td></tr>
                        <tr><td class="system_info">&nbsp;</td></tr>
                        <tr><td class="system_info">&nbsp;</td></tr>
                        <tr><td class="system_info"><a href="http://www.openlinksw.com">OpenLink Software</a></td></tr>
                        <tr><td class="system_info"><a href="http://www.openlinksw.com/virtuoso">Virtuoso Web Site</a></td></tr>
                        <tr><td class="system_info">Server version: <?V sys_stat('st_dbms_ver') ?></td></tr>
                        <tr><td class="system_info">Server build: <?V sys_stat('st_build_date') ?></td></tr>
                        <tr><td class="system_info">BPEL4WS version: <?V registry_get('_bpel4ws_version_') ?></td></tr>
                        <tr><td class="system_info">BPEL4WS build date: <?V registry_get('_bpel4ws_build_') ?></td></tr>
                        <tr><td class="system_info"><a href="http://www.openlinksw.com/virtuoso"><img alt="Powered by OpenLink Virtuoso Universal Server" src="PoweredByVirtuoso.gif" border="0" /></a></td></tr>
                      </table>
                    </td>
                  </tr>
              </tbody>
              </table>
            </td>
            <td id="RT" width="90%" valign="top">
              <table width="100%">
                <tr>
                  <td><!-- The top menu component -->
                    <v:include url="interop_navigation_bar.vspx"/>
                  </td>
                </tr>
                <tr>
                  <td id="RB" width="90%" valign="top" border="0" cellspacing="0" cellpadding="0">
                    <table id="DT" width="100%" border="0" cellspacing="0" cellpadding="0">
                      <tr class="subpage_header_area">
                        <xsl:apply-templates select="vm:header"/>
                        <xsl:apply-templates select="vm:rawheader"/>
                        &lt;?vsp if (atoi (cfg_item_value (virtuoso_ini_path(), 'HTTPServer', 'ServerThreads')) &lt; 2) { ?&gt;
                          <td><font color="Red">
                        &lt;?vsp http_value('Warning: Only 1 thread allocated for web services.  The BPEL user interface will not be operational'); ?&gt;
                          </font></td>
                        &lt;?vsp } ?&gt;
                      </tr>
                    </table>
                  </td>
                </tr>
                <tr class="main_page_area">
                  <td>
                    <xsl:apply-templates select="vm:pagebody"/>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </tbody>
      </table>
      <div class="footer">
        <a href="http://www.openlinksw.com/main/contactu.htm">Contact Us</a> |
	<a href="http://virtuoso.openlinksw.com/interop/index.htm#">Privacy</a>
      </div>
      <div class="copyright">Copyright &amp;copy; 1998-<?V "LEFT" (datestring (now()), 4)?> OpenLink Software</div>
      <xsl:processing-instruction name="vsp">
		declare ht_stat varchar;
		ht_stat := http_request_status_get ();
		if (ht_stat is not null and ht_stat like 'HTTP/1._ 30_ %')
		  {
		    http_rewrite ();
		  }
	 </xsl:processing-instruction>
</xsl:template>

<xsl:template match="vm:menu">
  <xsl:processing-instruction name="vsp"> if (self.nav_pos_fixed) { </xsl:processing-instruction>
   <xsl:for-each select="vm:menuitem">
      <tr><td class="SubInfo">
         <xsl:choose>
            <xsl:when test="@type='hot' or @url">
                <v:url format="%s">
                   <xsl:copy-of select="@name" />
                   <xsl:attribute name="value">--'<xsl:value-of select="@value"/>'</xsl:attribute>
                   <xsl:attribute name="url">--'<xsl:value-of select="@url"/>'</xsl:attribute>
                 </v:url>
            </xsl:when>
            <xsl:when test="@ref">
                <v:url format="%s">
                   <xsl:copy-of select="@name" />
                   <xsl:attribute name="value">--'<xsl:value-of select="@value"/>'</xsl:attribute>
                   <xsl:attribute name="url">--<xsl:value-of select="@ref"/></xsl:attribute>
                 </v:url>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="@value"/>
            </xsl:otherwise>
         </xsl:choose>
       </td></tr>
    </xsl:for-each>
  &lt;?vsp } else { ?&gt;
      <tr><td class="SubInfo">
       &lt;?vsp http (coalesce (self.nav_tip, '')); ?&gt;
       </td></tr>
  &lt;?vsp } ?&gt;
</xsl:template>

<xsl:template match="vm:url">
     <v:variable>
      <xsl:attribute name="name"><xsl:value-of select="@name"/>_allowed</xsl:attribute>
      <xsl:attribute name="persist">1</xsl:attribute>
        <xsl:attribute name="type">varchar</xsl:attribute>
        <xsl:attribute name="default">
          <xsl:choose>
        <xsl:when test="@allowed">'<xsl:value-of select="@allowed"/>'</xsl:when>
        <xsl:otherwise>null</xsl:otherwise>
      </xsl:choose>
      </xsl:attribute>
     </v:variable>
     <v:url>
       <xsl:copy-of select="@name" />
       <xsl:copy-of select="@format"/>
       <xsl:copy-of select="@value"/>
        <xsl:copy-of select="@url"/>
      &lt;?vsp if (self.nav_pos_fixed) { ?&gt;
      <xsl:apply-templates select="node()|processing-instruction()" />
      &lt;?vsp } ?&gt;
     </v:url>
</xsl:template>



<xsl:template match="vm:rawheader">
  &lt;?vsp if (self.nav_pos_fixed) { ?&gt;
  <xsl:apply-templates select="node()|processing-instruction()" />
  &lt;?vsp } ?&gt;
</xsl:template>
<xsl:template match="vm:raw">
  &lt;?vsp if (self.nav_pos_fixed) { ?&gt;
  <xsl:apply-templates select="node()|processing-instruction()" />
  &lt;?vsp } ?&gt;
</xsl:template>

<xsl:template match="vm:pagebody">
  &lt;?vsp if (self.nav_pos_fixed) { ?&gt;
  <xsl:choose>
    <xsl:when test="@url">
      <v:template name="vm_pagebody_include_url" type="simple">
        <v:include url="{@url}"/>
      </v:template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates select="node()|processing-instruction()" />
    </xsl:otherwise>
  </xsl:choose>
  &lt;?vsp } else { ?&gt;
  <table id="content">
    <tr>
      <td>
        <v:template name="vm_pagebody_splash" type="simple">
        </v:template>
      </td>
    </tr>
  </table>
  &lt;?vsp } ?&gt;
</xsl:template>

<!-- The rest is from page.xsl -->

<xsl:template match="vm:header">
<xsl:if test="@caption">
  &lt;?vsp if (self.nav_pos_fixed) { ?&gt;
  <td class="page_title"> <!-- <xsl:copy-of select="@class"/> -->
  <xsl:value-of select="@caption"/></td>
  &lt;?vsp } ?&gt;
</xsl:if>
<xsl:apply-templates/>
</xsl:template>

<xsl:template match="vm:init">
    <xsl:apply-templates select="node()|processing-instruction()" />
</xsl:template>

<xsl:template match="vm:caption">
<xsl:value-of select="@fixed"/>
<xsl:apply-templates/>
</xsl:template>

<xsl:template match="vm:controls">
<xsl:apply-templates/>
</xsl:template>

<xsl:template match="vm:control">
<td  class="SubInfo">
  <xsl:apply-templates/>
</td>
</xsl:template>

</xsl:stylesheet>
