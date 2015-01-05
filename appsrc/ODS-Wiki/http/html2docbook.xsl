<?xml version="1.0" encoding="UTF-8"?> 
<!--  
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2015 OpenLink Software
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
-->

<xsl:stylesheet version="1.0"  
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"  
                xmlns:fo="http://www.w3.org/1999/XSL/Format"  
                xmlns:xhtml="http://www.w3.org/1999/xhtml"  
                xmlns:saxon="http://icl.com/saxon" 
                exclude-result-prefixes="xsl fo saxon xhtml"> 
 
<xsl:output method="xml" 
	    indent="no" 
	    omit-xml-declaration="yes"/> 

  <xsl:template match="//xhtml:html"> 
   <xsl:apply-templates select="xhtml:body" /> 
  </xsl:template> 

  <xsl:template match="xhtml:body"> 

   <docbook>
   <section> 
    <title> 
    <xsl:value-of select=".//xhtml:h1[1]|//xhtml:head/xhtml:title" />
    </title> 
    <xsl:apply-templates /> 
   </section> 
   </docbook>
  </xsl:template> 

  <xsl:template match="xhtml:h1[1]">
    <title>
      <xsl:value-of select="." />
    </title>
    <xsl:apply-templates />
  </xsl:template>

  <!--Tim: ignore the header altogether -->
  <xsl:template match="//xhtml:head/*" />

  <!--Tim: convert p to para -->
  <xsl:template match="xhtml:p">
    <para>
      <xsl:apply-templates />
    </para>
  </xsl:template>

  <!-- handle links -->

  <xsl:template match="xhtml:a[normalize-space(text())='?']" />

  <xsl:template
        match="xhtml:a[starts-with(normalize-space(@href), '/twiki/')]">
    <ulink url="{@href}" fixme="FIXME">
      <xsl:apply-templates />
    </ulink>
  </xsl:template>

  <xsl:template match="xhtml:a">
    <ulink url="{@href}">
      <xsl:apply-templates />
    </ulink>
  </xsl:template>

  <xsl:template match="xhtml:div">
    <para>
      <xsl:apply-templates />
    </para>
  </xsl:template>

  <xsl:template match="xhtml:strong|xhtml:b|xhtml:i|xhtml:u">
    <emphasis> <xsl:apply-templates /></emphasis>
  </xsl:template>

  <xsl:template match="xhtml:em">
    <emphasis><xsl:apply-templates /></emphasis>
  </xsl:template>

  <xsl:template match="xhtml:h1|xhtml:h2|xhtml:h3|xhtml:h4|xhtml:h5">
    <bridgehead class="{name(.)}">
      <xsl:apply-templates />
    </bridgehead>
  </xsl:template>

  <xsl:template match="xhtml:ul">
    <itemizedlist mark="bullet" spacing="compact">
      <xsl:apply-templates />
    </itemizedlist>
  </xsl:template>  

  <xsl:template match="xhtml:pre">
    <programlisting>
      <xsl:apply-templates />
    </programlisting>
  </xsl:template>  

  <xsl:template match="xhtml:ol">
    <orderedlist spacing="compact">
      <xsl:apply-templates />
    </orderedlist>
  </xsl:template>

  <xsl:template match="xhtml:li">
    <listitem>
      <xsl:apply-templates />
    </listitem>
  </xsl:template>

  <xsl:template match="xhtml:table">
    <table>
      <title><xsl:value-of select="caption" /></title>
      <tgroup>
	<thead>
	  <xsl:apply-templates select=".//xhtml:thead|.//xhtml:th" />
	</thead>
	<tbody>
	  <xsl:apply-templates />
	</tbody>
      </tgroup>
    </table>
  </xsl:template>

  <xsl:template match="xhtml:tbody|xhtml:span|xhtml:nop|xhtml:code|xhtml:dl">
    <xsl:apply-templates />
  </xsl:template>

  <xsl:template match="xhtml:tr">
    <row>
      <xsl:apply-templates />
    </row>
  </xsl:template>

  <xsl:template match="xhtml:th|xhtml:br|xhtml:hr|xhtml:hide|xhtml:script|xhtml:small|xhtml:font|xhtml:form|//xhtml:style" />

  <xsl:template match="xhtml:img">
    <figure>
      <graphic fileref="{@src}" />
    </figure>
  </xsl:template>

  <xsl:template match="xhtml:td">
    <entry>
      <xsl:apply-templates />
    </entry>
  </xsl:template>

  <xsl:template match="xhtml:tt">
    <computeroutput>
      <xsl:apply-templates />
    </computeroutput>
  </xsl:template>

  <xsl:template match="xhtml:blockquote">
    <blockquote>
      <xsl:apply-templates />
    </blockquote>
  </xsl:template>

  <xsl:template match="xhtml:*">
    <span style="color: red">
      UNKNOWN tag:
      <xsl:value-of select="name(.)" />
      <xsl:value-of select="." />
    </span>
  </xsl:template>

</xsl:stylesheet> 
 
