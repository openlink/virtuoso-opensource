<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'
                xmlns:doc="http://nwalsh.com/xsl/documentation/1.0">

<!-- ********************************************************************
     $Id$
     ********************************************************************

     This file is part of the XSL DocBook Stylesheet distribution.
     See ../README or http://nwalsh.com/docbook/xsl/ for copyright
     and other information.

     ******************************************************************** -->

<!-- ==================================================================== -->

<xsl:variable name="author.othername.in.middle" select="1"/>

<doc:variable name="author.othername.in.middle" xmlns="">
<refpurpose>Is <sgmltag>othername</sgmltag> in <sgmltag>author</sgmltag> a
middle name?</refpurpose>
<refdescription>
<para>If true (non-zero), the <sgmltag>othername</sgmltag> of an <sgmltag>author</sgmltag>
appears between the <sgmltag>firstname</sgmltag> and
<sgmltag>surname</sgmltag>.  Otherwise, <sgmltag>othername</sgmltag>
is suppressed.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->

<xsl:variable name="html.stylesheet"></xsl:variable>

<doc:variable name="html.stylesheet" xmlns="">
<refpurpose>Name of the stylesheet to use in the generated HTML</refpurpose>
<refdescription>
<para>The name of the stylesheet to place in the HTML <sgmltag>LINK</sgmltag>
tag, or the empty string to suppress the stylesheet <sgmltag>LINK</sgmltag>.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->

<xsl:variable name="html.stylesheet.type">text/css</xsl:variable>

<doc:variable name="html.stylesheet.type" xmlns="">
<refpurpose>The type of the stylesheet used in the generated HTML</refpurpose>
<refdescription>
<para>The type of the stylesheet to place in the HTML <sgmltag>link</sgmltag> tag.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->

<xsl:variable name="refentry.xref.manvolnum" select="1"/>

<doc:variable name="refentry.xref.manvolnum" xmlns="">
<refpurpose>Output <sgmltag>manvolnum</sgmltag> as part of 
<sgmltag>refentry</sgmltag> cross-reference?</refpurpose>
<refdescription>
<para>if true (non-zero), the <sgmltag>manvolnum</sgmltag> is used when cross-referencing
<sgmltag>refentry</sgmltag>s, either with <sgmltag>xref</sgmltag>
or <sgmltag>citerefentry</sgmltag>.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->
<xsl:variable name="show.comments" select="1"/>

<doc:variable name="show.comments" xmlns="">
<refpurpose>Display <sgmltag>comment</sgmltag> elements?</refpurpose>
<refdescription>
<para>If true (non-zero), comments will be displayed, otherwise they are suppressed.
Comments here refers to the <sgmltag>comment</sgmltag> element,
which will be renamed <sgmltag>remark</sgmltag> in DocBook V4.0,
not XML comments (&lt;-- like this --&gt;) which are unavailable.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->
<xsl:variable name="funcsynopsis.style">kr</xsl:variable>

<doc:variable name="funcsynopsis.style" xmlns="">
<refpurpose>What style of 'FuncSynopsis' should be generated?</refpurpose>
<refdescription>
<para>If <varname>funcsynopsis.style</varname> is <literal>ansi</literal>,
ANSI-style function synopses are generated for a
<sgmltag>funcsynopsis</sgmltag>, otherwise K&amp;R-style
function synopses are generated.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->
<xsl:variable name="funcsynopsis.decoration" select="1"/>

<doc:variable name="funcsynopsis.decoration" xmlns="">
<refpurpose>Decorate elements of a FuncSynopsis?</refpurpose>
<refdescription>
<para>If true (non-zero), elements of the FuncSynopsis will be decorated (e.g. bold or
italic).  The decoration is controlled by functions that can be redefined
in a customization layer.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->

<xsl:variable name="function.parens">0</xsl:variable>

<doc:variable name="function.parens" xmlns="">
<refpurpose>Generate parens after a function?</refpurpose>
<refdescription>
<para>If not 0, the formatting of
a <sgmltag class="starttag">function</sgmltag> element will include
generated parenthesis.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->
<xsl:variable name="refentry.generate.name" select="1"/>

<doc:variable name="refentry.generate.name" xmlns="">
<refpurpose>Output NAME header before 'RefName'(s)?</refpurpose>
<refdescription>
<para>If true (non-zero), a "NAME" section title is output before the list
of 'RefName's.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->
<xsl:variable name="admon.graphics" select="0"/>

<doc:variable name="admon.graphics" xmlns="">
<refpurpose>Use graphics in admonitions?</refpurpose>
<refdescription>
<para>If true (non-zero), admonitions are presented in an alternate style that uses
a graphic.  Default graphics are provided in the distribution.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->
<xsl:variable name="admon.graphics.path">../images/</xsl:variable>

<doc:variable name="admon.graphics.path" xmlns="">
<refpurpose>Path to admonition graphics</refpurpose>
<refdescription>
<para>Sets the path, probably relative to the directory where the HTML
files are created, to the admonition graphics.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->
<xsl:variable name="admon.style">
  <xsl:text>margin-left: 0.5in; margin-right: 0.5in;</xsl:text>
</xsl:variable>

<doc:variable name="admon.style" xmlns="">
<refpurpose>CSS style attributes for admonitions</refpurpose>
<refdescription>
<para>Specifies the value of the <sgmltag class="attribute">STYLE</sgmltag>
attribute that should be added to admonitions.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->
<xsl:variable name="section.autolabel" select="0"/>

<doc:variable name="section.autolabel" xmlns="">
<refpurpose>Are sections enumerated?</refpurpose>
<refdescription>
<para>If true (non-zero), unlabeled sections will be enumerated.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->
<xsl:variable name="section.label.includes.component.label" select="0"/>

<doc:variable name="section.label.includes.component.label" xmlns="">
<refpurpose>Do section labels include the component label?</refpurpose>
<refdescription>
<para>If true (non-zero), section labels are prefixed with the label of the
component that contains them.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->
<xsl:variable name="chapter.autolabel" select="1"/>

<doc:variable name="chapter.autolabel" xmlns="">
<refpurpose>Are chapters and appendixes enumerated?</refpurpose>
<refdescription>
<para>If true (non-zero), unlabeled chapters and appendixes will be enumerated.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->
<xsl:variable name="preface.autolabel" select="0"/>

<doc:variable name="preface.autolabel" xmlns="">
<refpurpose>Are prefaces enumerated?</refpurpose>
<refdescription>
<para>If true (non-zero), unlabeled prefaces will be enumerated.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->
<xsl:variable name="part.autolabel" select="1"/>

<doc:variable name="part.autolabel" xmlns="">
<refpurpose>Are parts and references enumerated?</refpurpose>
<refdescription>
<para>If true (non-zero), unlabeled parts and references will be enumerated.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->
<xsl:variable name="qandadiv.autolabel" select="1"/>

<doc:variable name="qandadiv.autolabel" xmlns="">
<refpurpose>Are divisions in QAndASets enumerated?</refpurpose>
<refdescription>
<para>If true (non-zero), unlabeled qandadivs will be enumerated.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->
<xsl:variable name="qanda.inherit.numeration" select="0"/>

<doc:variable name="qanda.inherit.numeration" xmlns="">
<refpurpose>Does enumeration of QandASet components inherit the numeration of parent elements?</refpurpose>
<refdescription>
<para>If true (non-zero), numbered QandADiv elements and Questions and Answers inherit
the numeration of the ancestors of the QandASet.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->
<xsl:variable name="biblioentry.item.separator">. </xsl:variable>

<doc:variable name="biblioentry.item.separator" xmlns="">
<refpurpose>Text to separate bibliography entries</refpurpose>
<refdescription>
<para>Text to separate bibliography entries
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->
<xsl:variable name="toc.section.depth">2</xsl:variable>

<doc:variable name="toc.section.depth" xmlns="">
<refpurpose>How deep should recursive <sgmltag>section</sgmltag>s appear
in the TOC?</refpurpose>
<refdescription>
<para>Specifies the depth to which recursive sections should appear in the
TOC.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->

<xsl:variable name="using.chunker" select="0"/>

<doc:variable name="using.chunker" xmlns="">
<refpurpose>Will the output be chunked?</refpurpose>
<refdescription>
<para>In addition to providing chunking, the chunker can cleanup a
number of XML to HTML issues. If the chunker is not being used, the
stylesheets try to avoid producing results that will not appear properly
in browsers.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->
<xsl:variable name="generate.component.toc" select="1"/>

<doc:variable name="generate.component.toc" xmlns="">
<refpurpose>Should TOCs be genereated in components (Chapters, Appendixes, etc.)?</refpurpose>
<refdescription>
<para>If true (non-zero), they are.
</para>
</refdescription>
</doc:variable>
<!-- ==================================================================== -->
<xsl:variable name="generate.division.toc" select="1"/>

<doc:variable name="generate.division.toc" xmlns="">
<refpurpose>Should TOCs be genereated in divisions (Books, Parts, etc.)?</refpurpose>
<refdescription>
<para>If true (non-zero), they are.
</para>
</refdescription>
</doc:variable>

<!-- ==================================================================== -->

<xsl:variable name="link.mailto.url"></xsl:variable>

<doc:variable name="link.mailto.url" xmlns="">
<refpurpose>Mailto URL for the LINK REL=made HTML HEAD element</refpurpose>
<refdescription>
<para>If not the empty string, this address will be used for the
REL=made <sgmltag>LINK</sgmltag> element in the HTML <sgmltag>HEAD</sgmltag>.
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

<xsl:variable name="toc.list.type">dl</xsl:variable>

<doc:variable name="toc.list.type" xmlns="">
<refpurpose>Type of HTML list element to use for Tables of Contents</refpurpose>
<refdescription>
<para>When an automatically generated Table of Contents (or List of Titles)
is produced, this HTML element will be used to make the list.
</para>
</refdescription>
</doc:variable>

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

<xsl:variable name="use.id.function">1</xsl:variable>

<doc:variable name="use.id.function" xmlns="">
<refpurpose>Use the XPath id() function to find link targets?</refpurpose>
<refdescription>
<para>If 1, the stylesheets use the <function>id()</function> function
to find the targets of cross reference elements. This is more
efficient, but only works if your XSLT processor implements the
<function>id()</function> function, naturally.</para>
<para>THIS PARAMETER IS NOT SUPPORTED. IT IS ALWAYS ASSUMED TO BE 1.
SEE xref.xsl IF YOU NEED TO TURN IT OFF.</para>
</refdescription>
</doc:variable>

</xsl:stylesheet>

