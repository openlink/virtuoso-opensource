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

<xsl:template match="/">
<xsl:param name="ti_cluster_name"/>
<table width="100%"> 
 <tr>
  <td valign="top" width="100%">
   <div class="top">
    <table width="100%">
     <tr width="100%">
      <td valign="top" width="100%">
        <table width="100%">
	 <tr>
	  <td>
           <xsl:apply-templates select="//div[@class='login']"/> 
	   <div class="ATOM_FEED">
	    <a>
	     <xsl:attribute name="href">/wikix/gems.vsp?type=atom&amp;cluster=<xsl:value-of select="$ti_cluster_name"/></xsl:attribute>
	     [XML]
	    </a>
	    <xsl:value-of select="$ti_cluster_name"/>'s ChangeLog
	   </div>
	   <div class="ATOM_FEED">
	    <a>
	     <xsl:attribute name="href">/wikix/gems.vsp?type=atom</xsl:attribute>
	     [XML]
	    </a>
	   ChangeLog
	   </div>
	  </td>
	  <td valign="top">
           <xsl:apply-templates select="//div[@class='user-navigation']"/> 
	  </td>
	  <td align="left">	  
           <xsl:apply-templates select="//div[@class='search']"/>
	  </td>
	 </tr>
	</table>
      </td>
     </tr>
    </table>
   </div>
  </td>
 </tr>
 <tr>
  <td valign="top"> 
   <xsl:apply-templates select="//div[@class='wiki-path']"/>
   <div class="txt">
    <xsl:apply-templates select="//div[@class='content']"/>
   </div>
   <xsl:apply-templates select="//div[@class='wiki-toolbar-container']"/>
  </td>
 </tr>
 <tr>
   <td>
     <xsl:apply-templates select="//div[@class='virtuoso-info']"/> 
   </td>
 </tr>
</table>
 
</xsl:template>


<xsl:template match="node()">
  <xsl:copy>
    <xsl:copy-of select="@*" />
    <xsl:apply-templates select="node()" />
  </xsl:copy>
</xsl:template>


</xsl:stylesheet>
