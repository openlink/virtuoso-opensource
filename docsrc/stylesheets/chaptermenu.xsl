<?xml version="1.0" encoding="UTF-8"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2013 OpenLink Software
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

<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl" result-ns="html">

<!-- this xsl combines some JavaScript with the HTML output for use with the framed version.  This xsl produces
		an expandable menu like tree of the chapter with links and things. -->

<xsl:template match="/">
<xsl:pi name="DOCTYPE HTML PUBLIC">&quot;-//W3C//DTD HTML 4.0 Transitional//EN&quot;</xsl:pi>
  <HTML>
  <HEAD>
  <LINK REL="stylesheet" TYPE="text/css" HREF="virtdoc.css"/>
  <xsl:comment>Generated with chaptermenu.xsl</xsl:comment>
  <TITLE><xsl:value-of select="/book/title"/>
  </TITLE></HEAD>

<BODY CLASS="cf-vdocbody">
    <Script Language="JavaScript">

    function toggler(obj, pic)
    {
    	if (obj.style.display=='')
    	{  obj.style.display='none';
    		pic.src='images/tree/menu.png';
    	}
    	else
    	{	obj.style.display='';
    		pic.src='images/tree/menu2.png';
    	}
    }

    function hide(obj, pic)
    {
    	obj.style.display='none';
	   	pic.src='images/tree/menu.png';
    }

    function show(obj, pic)
    {
    	obj.style.display='';
    	pic.src='images/tree/menu2.png';
    }

    function hi_light_on(img, id, level)
    {
    	status='Click to expand and contract contents levels....';

    	// if (id.style.display=='' ) {img.src='images/tree/virtbullet'+level+'_open_hl.gif';}
    	// if (id.style.display=='none' ) {img.src='images/tree/virtbullet'+level+'_closed_hl.gif';} 

    }

    function hi_light_off(img, id, level)
    {
    	// if (id.style.display=='' ) {img.src='images/tree/virtbullet'+level+'_open.gif';}
    	// if (id.style.display=='none' ) {img.src='images/tree/virtbullet'+level+'_closed.gif';}

    	status='';
    }
    </Script>
<!-- Doc Contents Content -->

<!-- Chapters ======================== -->

<DIV CLASS="cfd-toc">
<HR/>

   	<TABLE WIDTH="100%" CLASS="cf-tabs"><TR>
		<TD WIDTH="10"><IMG SRC="images/tree/menu.png"/></TD>
		<TD><A CLASS="cf-toc1" TARGET="viewfr" HREF="virtdochtml.asp#contents">Contents</A></TD></TR>
	</TABLE>
<HR/>
    <xsl:for-each select="/book/chapter">

   	<TABLE WIDTH="100%" CLASS="cf-tabs"><TR>
		<TD WIDTH="10">
			<IMG SRC="images/tree/menu.png">
			  <xsl:attribute name="ID">imgc1_<xsl:value-of select="./@label" /></xsl:attribute>
			  <xsl:attribute name="ONMOUSEOVER">hi_light_on(this, <xsl:value-of select="./@label" />, '2');</xsl:attribute>
			  <xsl:attribute name="ONMOUSEOUT">hi_light_off(this, <xsl:value-of select="./@label" />, '2');</xsl:attribute>
			  <xsl:attribute name="ONCLICK">toggler(<xsl:value-of select="./@label" />, imgc1_<xsl:value-of select="./@label" />);</xsl:attribute>
			</IMG>
   	</TD>
	<TD>
		<A CLASS="cf-toc1" TARGET="viewfr">
		  <xsl:attribute name="HREF">virtdochtml.asp#<xsl:value-of select="./@label" /></xsl:attribute>
		  <xsl:attribute name="TITLE">Chapter: <xsl:value-of select="./@label" /> - <xsl:value-of select="./title"/>
---------------------------------------------------
<xsl:value-of select="./abstract" /></xsl:attribute>
			<xsl:attribute name="ONCLICK">show(<xsl:value-of select="./@label" />, imgc1_<xsl:value-of select="./@label" />);</xsl:attribute>
	   		<xsl:value-of select="./title"/></A>
	</TD></TR></TABLE>
<!-- Section 1s ======================== -->
		<DIV CLASS="cfd-toc2">
		  <xsl:attribute name="ID"><xsl:value-of select="./@label" /></xsl:attribute>
     	<xsl:for-each select="./sect1">
		<TABLE CLASS="cf-tabs"><TR><TD>
			<IMG SRC="images/tree/menu.png">
			  <xsl:attribute name="ID">imgc2_<xsl:value-of select="../@label" /><xsl:value-of select="./@id" />_</xsl:attribute>
			  <xsl:attribute name="ONMOUSEOVER">hi_light_on(this, _<xsl:value-of select="../@label" /><xsl:value-of select="./@id" />_, '2');</xsl:attribute>
			  <xsl:attribute name="ONMOUSEOUT">hi_light_off(this, _<xsl:value-of select="../@label" /><xsl:value-of select="./@id" />_, '2');</xsl:attribute>
			  <xsl:attribute name="ONCLICK">toggler(_<xsl:value-of select="../@label" /><xsl:value-of select="./@id" />_ , imgc2_<xsl:value-of select="../@label" /><xsl:value-of select="./@id" />_ );</xsl:attribute></IMG>
      	</TD><TD><A CLASS="cf-toc2" TARGET="viewfr">
				<xsl:attribute name="HREF">virtdochtml.asp#<xsl:value-of select="../@label" /><xsl:value-of select="./@id" /></xsl:attribute>
				<xsl:attribute name="ONCLICK">show(_<xsl:value-of select="../@label" /><xsl:value-of select="./@id" />_ , imgc2_<xsl:value-of select="../@label" /><xsl:value-of select="./@id" />_);</xsl:attribute>
      	<xsl:value-of select="./title"/></A></TD></TR>
		</TABLE>
<!-- Section 2s ======================== -->
         	<DIV CLASS="cfd-toc3">
			  <xsl:attribute name="ID">_<xsl:value-of select="../@label" /><xsl:value-of select="./@id" />_</xsl:attribute>
         	<xsl:for-each select="./sect2">
         		<A CLASS="cf-toc3" TARGET="viewfr">
					<xsl:attribute name="HREF">virtdochtml.asp#<xsl:value-of select="../../@label" /><xsl:value-of select="../@id" /><xsl:value-of select="./@id" /></xsl:attribute>
					<xsl:attribute name="TITLE"><xsl:for-each select="./sect3"><xsl:value-of select="./title"/>; </xsl:for-each></xsl:attribute>
         			<xsl:value-of select="./title"/>
				</A><BR/>
         	</xsl:for-each>
			</DIV><Script>hide(_<xsl:value-of select="../@label" /><xsl:value-of select="./@id" />_, imgc2_<xsl:value-of select="../@label" /><xsl:value-of select="./@id" />_);</Script>
       </xsl:for-each>
     </DIV><!-- </TD></TR></TABLE> -->
<Script>hide(<xsl:value-of select="./@label" />, imgc1_<xsl:value-of select="./@label" />, '');</Script></xsl:for-each>

<HR/>

   	<TABLE WIDTH="100%" CLASS="cf-tabs"><TR>
		<TD WIDTH="10"><IMG SRC="images/tree/menu.png"/></TD>
		<TD><A CLASS="cf-toc1" TARGET="viewfr" HREF="virtdochtml.asp#functionindex">Appendix A - Function Index</A></TD></TR>
	</TABLE>

</DIV>

<HR/>
</BODY>
</HTML>
</xsl:template>

</xsl:stylesheet>
