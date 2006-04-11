<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
                xmlns:doc="http://nwalsh.com/xsl/documentation/1.0"
                version='1.0'>

<!-- ********************************************************************
     $Id$
     ********************************************************************

     This file is part of the XSL DocBook Stylesheet distribution.
     See ../README or http://nwalsh.com/docbook/xsl/ for copyright
     and other information.

     ******************************************************************** -->

<xsl:variable name="author.othername.in.middle" select="1"/>
<xsl:variable name="html.stylesheet">docbook.css</xsl:variable>
<xsl:variable name="html.stylesheet.type">text/css</xsl:variable>
<xsl:variable name="refentry.xref.manvolnum" select="1"/>
<xsl:variable name="show.comments" select="1"/>
<xsl:variable name="funcsynopsis.style">kr</xsl:variable>
<xsl:variable name="funcsynopsis.decoration" select="1"/>
<xsl:variable name="refentry.generate.name" select="1"/>

<xsl:variable name="admon.graphics" select="0"/>
<xsl:variable name="admon.graphics.path">../images/</xsl:variable>

<xsl:variable name="section.autolabel" select="0"/>
<xsl:variable name="section.label.includes.component.label" select="0"/>
<xsl:variable name="chapter.autolabel" select="1"/>
<xsl:variable name="part.autolabel" select="0"/>
<xsl:variable name="preface.autolabel" select="0"/>

<xsl:variable name="biblioentry.item.separator">. </xsl:variable>

<!-- ==================================================================== -->

<xsl:variable name="check.idref">1</xsl:variable>

<doc:variable name="check.idref" xmlns="">
<refpurpose>Test the target of IDREF attributes?</refpurpose>
<refdescription>
<para>If 1, the target of IDREF attributes are tested for presence
(and uniqueness). This can be very expensive in large documents.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->

<xsl:variable name="graphic.default.extension"></xsl:variable>

<doc:variable name="graphic.default.extension" xmlns="">
<refpurpose>Default extension for graphic filenames</refpurpose>
<refdescription>
<para>If a <sgmltag>graphic</sgmltag> or <sgmltag>mediaobject</sgmltag>
includes a reference to a filename that does not include an extension,
and the <sgmltag class="attribute">format</sgmltag> attribute is
<emphasis>unspecified</emphasis>, the default extension will be used.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->

</xsl:stylesheet>

