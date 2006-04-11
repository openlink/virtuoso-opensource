<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:doc="http://nwalsh.com/xsl/documentation/1.0"
                version='1.0'>

<!-- ********************************************************************
     $Id$
     ********************************************************************

     This file is part of the XSL DocBook Stylesheet distribution.
     See ../README or http://nwalsh.com/docbook/xsl/ for copyright
     and other information.

     This file contains general templates common to both the HTML and FO
     versions of the DocBook stylesheets.
     ******************************************************************** -->

<!-- ==================================================================== -->
<!-- Establish strip/preserve whitespace rules -->

<xsl:preserve-space elements="*"/>

<xsl:strip-space elements="
abstract affiliation anchor answer appendix area areaset areaspec
artheader article audiodata audioobject author authorblurb authorgroup
beginpage bibliodiv biblioentry bibliography biblioset blockquote book
bookbiblio bookinfo callout calloutlist caption caution chapter
citerefentry cmdsynopsis co collab colophon colspec confgroup
copyright dedication docinfo editor entry entrytbl epigraph equation
example figure footnote footnoteref formalpara funcprototype
funcsynopsis glossary glossdef glossdiv glossentry glosslist graphicco
group highlights imagedata imageobject imageobjectco important index
indexdiv indexentry indexterm informalequation informalexample
informalfigure informaltable inlineequation inlinemediaobject
itemizedlist itermset keycombo keywordset legalnotice listitem lot
mediaobject mediaobjectco menuchoice msg msgentry msgexplan msginfo
msgmain msgrel msgset msgsub msgtext note objectinfo
orderedlist othercredit part partintro preface printhistory procedure
programlistingco publisher qandadiv qandaentry qandaset question
refentry reference refmeta refnamediv refsect1 refsect1info refsect2
refsect2info refsect3 refsect3info refsynopsisdiv refsynopsisdivinfo
revhistory revision row sbr screenco screenshot sect1 sect1info sect2
sect2info sect3 sect3info sect4 sect4info sect5 sect5info section
sectioninfo seglistitem segmentedlist seriesinfo set setindex setinfo
shortcut sidebar simplelist simplesect spanspec step subject
subjectset substeps synopfragment table tbody textobject tfoot tgroup
thead tip toc tocchap toclevel1 toclevel2 toclevel3 toclevel4
toclevel5 tocpart varargs variablelist varlistentry videodata
videoobject void warning subjectset

classsynopsis
constructorsynopsis
destructorsynopsis
fieldsynopsis
methodparam
methodsynopsis
ooclass
ooexception
oointerface
simplemsgentry
"/>

<!-- ====================================================================== -->

<doc:template name="section.level" xmlns="">
<refpurpose>Returns the hierarchical level of a section.</refpurpose>

<refdescription>
<para>This template calculates the hierarchical level of a section.
Hierarchically, components are <quote>top level</quote>, so a
<sgmltag>sect1</sgmltag> is at level 2, <sgmltag>sect3</sgmltag> is
at level 3, etc.</para>

<para>Recursive sections are calculated down to the sixth level.</para>
</refdescription>

<refparameter>
<variablelist>
<varlistentry><term>node</term>
<listitem>
<para>The section node for which the level should be calculated.
Defaults to the context node.</para>
</listitem>
</varlistentry>
</variablelist>
</refparameter>

<refreturn>
<para>The section level, <quote>2</quote>, <quote>3</quote>, etc.
</para>
</refreturn>
</doc:template>

<xsl:template name="section.level">
  <xsl:param name="node" select="."/>
  <xsl:choose>
    <xsl:when test="name($node)='sect1'">2</xsl:when>
    <xsl:when test="name($node)='sect2'">3</xsl:when>
    <xsl:when test="name($node)='sect3'">4</xsl:when>
    <xsl:when test="name($node)='sect4'">5</xsl:when>
    <xsl:when test="name($node)='sect5'">6</xsl:when>
    <xsl:when test="name($node)='section'">
      <xsl:choose>
        <xsl:when test="$node/../../../../../section">6</xsl:when>
        <xsl:when test="$node/../../../../section">5</xsl:when>
        <xsl:when test="$node/../../../section">4</xsl:when>
        <xsl:when test="$node/../../section">3</xsl:when>
        <xsl:otherwise>2</xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:when test="name($node)='simplesect'">
      <xsl:choose>
        <xsl:when test="$node/../../sect1">3</xsl:when>
        <xsl:when test="$node/../../sect2">4</xsl:when>
        <xsl:when test="$node/../../sect3">5</xsl:when>
        <xsl:when test="$node/../../sect4">6</xsl:when>
        <xsl:when test="$node/../../sect5">6</xsl:when>
        <xsl:when test="$node/../../section">
          <xsl:choose>
            <xsl:when test="$node/../../../../../section">6</xsl:when>
            <xsl:when test="$node/../../../../section">5</xsl:when>
            <xsl:when test="$node/../../../section">4</xsl:when>
            <xsl:otherwise>3</xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:otherwise>2</xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>2</xsl:otherwise>
  </xsl:choose>
</xsl:template><!-- section.level -->

<doc:template name="qanda.section.level" xmlns="">
<refpurpose>Returns the hierarchical level of a QandASet.</refpurpose>

<refdescription>
<para>This template calculates the hierarchical level of a QandASet.
</para>
</refdescription>

<refreturn>
<para>The level, <quote>1</quote>, <quote>2</quote>, etc.
</para>
</refreturn>
</doc:template>

<xsl:template name="qanda.section.level">
  <xsl:variable name="section"
                select="(ancestor::section
                         |ancestor::simplesect
                         |ancestor::sect5
                         |ancestor::sect4
                         |ancestor::sect3
                         |ancestor::sect2
                         |ancestor::sect1
                         |ancestor::refsect3
                         |ancestor::refsect2
                         |ancestor::refsect1)[last()]"/>
  <xsl:choose>
    <xsl:when test="count($section) = '0'">1</xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="section.level">
        <xsl:with-param name="node" select="$section"/>
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="qandadiv.section.level">
  <xsl:variable name="section.level">
    <xsl:call-template name="qanda.section.level"/>
  </xsl:variable>
  <xsl:variable name="anc.divs" select="ancestor::qandadiv"/>

  <xsl:value-of select="count($anc.divs) + number($section.level)"/>
</xsl:template>

<!-- ====================================================================== -->

<xsl:template name="object.id">
  <xsl:param name="object" select="."/>
  <xsl:choose>
    <xsl:when test="$object/@id">
      <xsl:value-of select="$object/@id"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="generate-id($object)"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="person.name">
  <!-- Return a formatted string representation of the contents of
       the specified node (by default, the current element).
       Handles Honorific, FirstName, SurName, and Lineage.
       If %author-othername-in-middle% is #t, also OtherName
       Handles *only* the first of each.
       Format is "Honorific. FirstName [OtherName] SurName, Lineage"
  -->
  <xsl:param name="node" select="."/>

  <xsl:choose>
    <!-- handle corpauthor as a special case...-->
    <xsl:when test="name($node)='corpauthor'">
      <xsl:apply-templates select="$node"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:variable name="h_nl" select="$node//honorific[1]"/>
      <xsl:variable name="f_nl" select="$node//firstname[1]"/>
      <xsl:variable name="o_nl" select="$node//othername[1]"/>
      <xsl:variable name="s_nl" select="$node//surname[1]"/>
      <xsl:variable name="l_nl" select="$node//lineage[1]"/>

      <xsl:variable name="has_h" select="$h_nl"/>
      <xsl:variable name="has_f" select="$f_nl"/>
      <xsl:variable name="has_o"
                    select="$o_nl and ($author.othername.in.middle != 0)"/>
      <xsl:variable name="has_s" select="$s_nl"/>
      <xsl:variable name="has_l" select="$l_nl"/>

      <xsl:if test="$has_h">
        <xsl:value-of select="$h_nl"/>.
      </xsl:if>

      <xsl:if test="$has_f">
        <xsl:if test="$has_h"><xsl:text> </xsl:text></xsl:if>
        <xsl:value-of select="$f_nl"/>
      </xsl:if>

      <xsl:if test="$has_o">
        <xsl:if test="$has_h or $has_f"><xsl:text> </xsl:text></xsl:if>
        <xsl:value-of select="$o_nl"/>
      </xsl:if>

      <xsl:if test="$has_s">
        <xsl:if test="$has_h or $has_f or $has_o">
          <xsl:text> </xsl:text>
        </xsl:if>
        <xsl:value-of select="$s_nl"/>
      </xsl:if>

      <xsl:if test="$has_l">
        <xsl:text>, </xsl:text>
        <xsl:value-of select="$l_nl"/>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template> <!-- person.name -->

<xsl:template name="person.name.list">
  <!-- Return a formatted string representation of the contents of
       the current element. The current element must contain one or
       more AUTHORs, CORPAUTHORs, OTHERCREDITs, and/or EDITORs.

       John Doe
     or
       John Doe and Jane Doe
     or
       John Doe, Jane Doe, and A. Nonymous
  -->
  <xsl:param name="person.list" select="./author|./corpauthor|./othercredit|./editor"/>
  <xsl:param name="person.count" select="count($person.list)"/>
  <xsl:param name="count" select="1"/>

  <xsl:choose>
    <xsl:when test="$count>$person.count"></xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="person.name">
        <xsl:with-param name="node" select="$person.list[position()=$count]"/>
      </xsl:call-template>
      <xsl:if test="$count&lt;$person.count">
        <xsl:if test="$person.count>2">,</xsl:if>
        <xsl:text> </xsl:text>
      </xsl:if>
      <xsl:if test="$count+1=$person.count">and </xsl:if>
      <xsl:call-template name="person.name.list">
        <xsl:with-param name="person.list" select="$person.list"/>
        <xsl:with-param name="person.count" select="$person.count"/>
        <xsl:with-param name="count" select="$count+1"/>
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template><!-- person.name.list -->

<!-- === synopsis ======================================================= -->
<!-- The following definitions match those given in the reference
     documentation for DocBook V3.0
-->

<xsl:variable name="arg.choice.opt.open.str">[</xsl:variable>
<xsl:variable name="arg.choice.opt.close.str">]</xsl:variable>
<xsl:variable name="arg.choice.req.open.str">{</xsl:variable>
<xsl:variable name="arg.choice.req.close.str">}</xsl:variable>
<xsl:variable name="arg.choice.plain.open.str"><xsl:text> </xsl:text></xsl:variable>
<xsl:variable name="arg.choice.plain.close.str"><xsl:text> </xsl:text></xsl:variable>
<xsl:variable name="arg.choice.def.open.str">[</xsl:variable>
<xsl:variable name="arg.choice.def.close.str">]</xsl:variable>
<xsl:variable name="arg.rep.repeat.str">...</xsl:variable>
<xsl:variable name="arg.rep.norepeat.str"></xsl:variable>
<xsl:variable name="arg.rep.def.str"></xsl:variable>
<xsl:variable name="arg.or.sep"> | </xsl:variable>
<xsl:variable name="cmdsynopsis.hanging.indent">4pi</xsl:variable>

<!-- ====================================================================== -->
<!-- label content -->

<doc:mode mode="label.content" xmlns="">
<refpurpose>Provides access to element labels</refpurpose>
<refdescription>
<para>Processing an element in the
<literal role="mode">label.content</literal> mode produces the
element label.</para>
<para>If the label is non-null, either because the
<sgmltag class="attribute">label</sgmltag> attribute was present on the
element or the stylesheet automatically generated a label, trailing
punctuation is automatically added.</para>
</refdescription>
</doc:mode>

<xsl:template match="*" mode="label.content">
  <xsl:message>
    <xsl:text>Request for label of unexpected element: </xsl:text>
    <xsl:value-of select="name(.)"/>
  </xsl:message>
</xsl:template>

<xsl:template match="set|book" mode="label.content">
  <xsl:param name="punct">.</xsl:param>
  <xsl:if test="@label">
    <xsl:value-of select="@label"/>
    <xsl:value-of select="$punct"/>
  </xsl:if>
</xsl:template>

<xsl:template match="part" mode="label.content">
  <xsl:param name="punct">.</xsl:param>
  <xsl:choose>
    <xsl:when test="@label">
      <xsl:value-of select="@label"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
    <xsl:when test="$part.autolabel != 0">
      <xsl:number from="book" count="part" format="I"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="preface" mode="label.content">
  <xsl:param name="punct">.</xsl:param>
  <xsl:choose>
    <xsl:when test="@label">
      <xsl:value-of select="@label"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
    <xsl:when test="$preface.autolabel != 0">
      <xsl:number from="book" count="preface" format="1" level="any"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="chapter" mode="label.content">
  <xsl:param name="punct">.</xsl:param>
  <xsl:choose>
    <xsl:when test="@label">
      <xsl:value-of select="@label"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
    <xsl:when test="$chapter.autolabel != 0">
      <xsl:number from="book" count="chapter" format="1" level="any"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="appendix" mode="label.content">
  <xsl:param name="punct">.</xsl:param>
  <xsl:choose>
    <xsl:when test="@label">
      <xsl:value-of select="@label"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
    <xsl:when test="$chapter.autolabel != 0">
      <xsl:number from="book" count="appendix" format="A" level="any"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="article" mode="label.content">
  <xsl:param name="punct">.</xsl:param>
  <xsl:if test="@label">
    <xsl:value-of select="@label"/>
    <xsl:value-of select="$punct"/>
  </xsl:if>
</xsl:template>

<xsl:template match="dedication|colophon" mode="label.content">
  <xsl:param name="punct">.</xsl:param>
  <xsl:if test="@label">
    <xsl:value-of select="@label"/>
    <xsl:value-of select="$punct"/>
  </xsl:if>
</xsl:template>

<xsl:template match="reference" mode="label.content">
  <xsl:param name="punct">.</xsl:param>
  <xsl:choose>
    <xsl:when test="@label">
      <xsl:value-of select="@label"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
    <xsl:when test="$part.autolabel != 0">
      <xsl:number from="book" count="reference" format="I" level="any"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="refentry" mode="label.content">
  <xsl:param name="punct">.</xsl:param>
  <xsl:if test="@label">
    <xsl:value-of select="@label"/>
    <xsl:value-of select="$punct"/>
  </xsl:if>
</xsl:template>

<xsl:template match="section" mode="label.content">
  <xsl:param name="punct">.</xsl:param>
  <xsl:if test="$section.label.includes.component.label != 0">
    <xsl:apply-templates select=".." mode="label.content">
      <xsl:with-param name="punct">.</xsl:with-param>
    </xsl:apply-templates>
  </xsl:if>
  <xsl:choose>
    <xsl:when test="@label">
      <xsl:value-of select="@label"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
    <xsl:when test="$section.autolabel != 0">
      <xsl:number level="multiple" count="section"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="sect1" mode="label.content">
  <xsl:param name="punct">.</xsl:param>
  <xsl:if test="$section.label.includes.component.label != 0">
    <xsl:apply-templates select=".." mode="label.content">
      <xsl:with-param name="punct">.</xsl:with-param>
    </xsl:apply-templates>
  </xsl:if>
  <xsl:choose>
    <xsl:when test="@label">
      <xsl:value-of select="@label"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
    <xsl:when test="$section.autolabel != 0">
      <xsl:number level="multiple" count="sect1"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="sect2" mode="label.content">
  <xsl:param name="punct">.</xsl:param>
  <xsl:choose>
    <xsl:when test="@label">
      <xsl:value-of select="@label"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
    <xsl:when test="$section.autolabel != 0">
      <xsl:number level="multiple" count="sect1|sect2"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="sect3" mode="label.content">
  <xsl:param name="punct">.</xsl:param>
  <xsl:choose>
    <xsl:when test="@label">
      <xsl:value-of select="@label"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
    <xsl:when test="$section.autolabel != 0">
      <xsl:number level="multiple" count="sect1|sect2|sect3"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="sect4" mode="label.content">
  <xsl:param name="punct">.</xsl:param>
  <xsl:choose>
    <xsl:when test="@label">
      <xsl:value-of select="@label"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
    <xsl:when test="$section.autolabel != 0">
      <xsl:number level="multiple" count="sect1|sect2|sect3|sect4"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="sect5" mode="label.content">
  <xsl:param name="punct">.</xsl:param>
  <xsl:choose>
    <xsl:when test="@label">
      <xsl:value-of select="@label"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
    <xsl:when test="$section.autolabel != 0">
      <xsl:number level="multiple" count="sect1|sect2|sect3|sect4|sect5"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="refsect1|refsect2|refsect3" mode="label.content">
  <xsl:param name="punct">.</xsl:param>
  <xsl:choose>
    <xsl:when test="@label">
      <xsl:value-of select="@label"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
    <xsl:when test="$section.autolabel != 0">
      <xsl:number level="multiple" count="refsect1|refsect2|refsect3"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="simplesect" mode="label.content">
  <xsl:param name="punct">.</xsl:param>
  <xsl:choose>
    <xsl:when test="@label">
      <xsl:value-of select="@label"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
    <xsl:when test="$section.autolabel != 0">
      <xsl:number level="multiple" count="section
                                          |sect1|sect2|sect3|sect4|sect5
                                          |refsect1|refsect2|refsect3
                                          |simplesect"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="qandadiv" mode="label.content">
  <xsl:param name="punct">.</xsl:param>
  <xsl:variable name="prefix">
    <xsl:if test="$qanda.inherit.numeration != 0">
      <xsl:variable name="lparent" select="(ancestor::set
                                            |ancestor::book
                                            |ancestor::chapter
                                            |ancestor::appendix
                                            |ancestor::preface
                                            |ancestor::section
                                            |ancestor::simplesect
                                            |ancestor::sect1
                                            |ancestor::sect2
                                            |ancestor::sect3
                                            |ancestor::sect4
                                            |ancestor::sect5
                                            |ancestor::refsect1
                                            |ancestor::refsect2
                                            |ancestor::refsect3)[last()]"/>
      <xsl:if test="count($lparent)>0">
        <xsl:apply-templates select="$lparent" mode="label.content"/>
      </xsl:if>
    </xsl:if>
  </xsl:variable>
  <xsl:choose>
    <xsl:when test="@label">
      <xsl:value-of select="$prefix"/>
      <xsl:value-of select="@label"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
    <xsl:when test="$qandadiv.autolabel != 0">
      <xsl:value-of select="$prefix"/>
      <xsl:number level="multiple" count="qandadiv" format="1"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="question|answer" mode="label.content">
  <xsl:param name="punct">.</xsl:param>
  <xsl:variable name="prefix">
    <xsl:if test="$qanda.inherit.numeration != 0">
      <xsl:variable name="lparent" select="(ancestor::set
                                            |ancestor::book
                                            |ancestor::chapter
                                            |ancestor::appendix
                                            |ancestor::preface
                                            |ancestor::section
                                            |ancestor::simplesect
                                            |ancestor::sect1
                                            |ancestor::sect2
                                            |ancestor::sect3
                                            |ancestor::sect4
                                            |ancestor::sect5
                                            |ancestor::refsect1
                                            |ancestor::refsect2
                                            |ancestor::refsect3
                                            |ancestor::qandadiv)[last()]"/>
      <xsl:if test="count($lparent)>0">
        <xsl:apply-templates select="$lparent" mode="label.content"/>
      </xsl:if>
    </xsl:if>
  </xsl:variable>

  <xsl:variable name="inhlabel"
                select="ancestor-or-self::qandaset/@defaultlabel[1]"/>

  <xsl:variable name="deflabel">
    <xsl:choose>
      <xsl:when test="$inhlabel != ''">
        <xsl:value-of select="$inhlabel"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$qanda.defaultlabel"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="label" select="label"/>

  <xsl:choose>
    <xsl:when test="count($label)>0">
      <xsl:value-of select="$prefix"/>
      <xsl:apply-templates select="$label"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>

    <xsl:when test="$deflabel = 'qanda'">
      <xsl:call-template name="gentext.element.name"/>
    </xsl:when>

    <xsl:when test="$deflabel = 'number'">
      <xsl:if test="name(.) = 'question'">
        <xsl:value-of select="$prefix"/>
        <xsl:number level="multiple" count="qandaentry" format="1"/>
        <xsl:value-of select="$punct"/>
      </xsl:if>
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="bibliography|glossary|index" mode="label.content">
  <xsl:param name="punct">.</xsl:param>
  <xsl:if test="@label">
    <xsl:value-of select="@label"/>
    <xsl:value-of select="$punct"/>
  </xsl:if>
</xsl:template>

<xsl:template match="figure|table|example|equation" mode="label.content">
  <xsl:param name="punct">.</xsl:param>
  <xsl:choose>
    <xsl:when test="@label">
      <xsl:value-of select="@label"/>
      <xsl:value-of select="$punct"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:variable name="pchap"
                    select="ancestor::chapter|ancestor::appendix"/>
      <xsl:choose>
        <xsl:when test="count($pchap)>0">
          <xsl:apply-templates select="$pchap" mode="label.content">
            <xsl:with-param name="punct">.</xsl:with-param>
          </xsl:apply-templates>
          <xsl:number format="1" from="chapter|appendix" level="any"/>
          <xsl:value-of select="$punct"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:number format="1" from="book|article" level="any"/>
          <xsl:value-of select="$punct"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="abstract" mode="label.content">
  <xsl:param name="punct">.</xsl:param>
</xsl:template>

<!-- ====================================================================== -->
<!-- title content -->

<doc:mode mode="title.content" xmlns="">
<refpurpose>Provides access to element titles</refpurpose>
<refdescription>
<para>Processing an element in the
<literal role="mode">title.content</literal> mode produces the
title of the element. This does not include the label. If
<parameter>text-only</parameter> is true, the text of the title
is returned, without inline markup, otherwise inline markup is processed
(in the default mode). By default, <parameter>text-only</parameter>
is false.
</para>
</refdescription>
</doc:mode>

<xsl:template match="*" mode="title.content">
  <xsl:param name="text-only" select="false()"/>
  <xsl:choose>
    <xsl:when test="title">
      <xsl:apply-templates select="title[1]" mode="title.content">
	<xsl:with-param name="text-only" select="$text-only"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise>
      <xsl:message>
	<xsl:text>Request for title of unexpected element: </xsl:text>
	<xsl:value-of select="name(.)"/>
      </xsl:message>
      <xsl:text>???TITLE???</xsl:text>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="title" mode="title.content">
  <xsl:param name="text-only" select="false()"/>
  <xsl:choose>
    <xsl:when test="$text-only">
      <xsl:value-of select="."/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="set" mode="title.content">
  <xsl:param name="text-only" select="false()"/>
  <xsl:apply-templates select="(setinfo/title|title)[1]"
                       mode="title.content">
    <xsl:with-param name="text-only" select="$text-only"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="book" mode="title.content">
  <xsl:param name="text-only" select="false()"/>
  <xsl:apply-templates select="(bookinfo/title|title)[1]"
                       mode="title.content">
    <xsl:with-param name="text-only" select="$text-only"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="part" mode="title.content">
  <xsl:param name="text-only" select="false()"/>
  <xsl:apply-templates select="(partinfo/title|docinfo/title|title)[1]"
                       mode="title.content">
    <xsl:with-param name="text-only" select="$text-only"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="preface|chapter|appendix" mode="title.content">
  <xsl:param name="text-only" select="false()"/>
  <xsl:variable name="title" select="(docinfo/title
                                      |prefaceinfo/title
                                      |chapterinfo/title
                                      |appendixinfo/title
                                      |title)[1]"/>

  <xsl:choose>
    <xsl:when test="$title">
      <xsl:apply-templates select="$title" mode="title.content">
        <xsl:with-param name="text-only" select="$text-only"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="gentext.element.name">
        <xsl:with-param name="element.name" select="name(.)"/>
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="dedication|colophon" mode="title.content">
  <xsl:param name="text-only" select="false()"/>
  <xsl:choose>
    <xsl:when test="title">
      <xsl:apply-templates select="title" mode="title.content">
        <xsl:with-param name="text-only" select="$text-only"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="gentext.element.name">
        <xsl:with-param name="element.name" select="name(.)"/>
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="article" mode="title.content">
  <xsl:param name="text-only" select="false()"/>
  <xsl:variable name="title" select="(artheader/title
                                      |articleinfo/title
                                      |title)[1]"/>

  <xsl:apply-templates select="$title" mode="title.content">
    <xsl:with-param name="text-only" select="$text-only"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="reference" mode="title.content">
  <xsl:param name="text-only" select="false()"/>
  <xsl:apply-templates select="(referenceinfo/title|docinfo/title|title)[1]"
                       mode="title.content">
    <xsl:with-param name="text-only" select="$text-only"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="refentry" mode="title.content">
  <xsl:param name="text-only" select="false()"/>
  <xsl:variable name="refmeta" select=".//refmeta"/>
  <xsl:variable name="refentrytitle" select="$refmeta//refentrytitle"/>
  <xsl:variable name="refnamediv" select=".//refnamediv"/>
  <xsl:variable name="refname" select="$refnamediv//refname"/>

  <xsl:variable name="title">
    <xsl:choose>
      <xsl:when test="$refentrytitle">
        <xsl:apply-templates select="$refentrytitle[1]" mode="title.content"/>
      </xsl:when>
      <xsl:when test="$refname">
        <xsl:apply-templates select="$refname[1]" mode="title.content"/>
      </xsl:when>
      <xsl:otherwise>REFENTRY WITHOUT TITLE???</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="$text-only"><xsl:value-of select="$title"/></xsl:when>
    <xsl:otherwise><xsl:copy-of select="$title"/></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="refentrytitle|refname" mode="title.content">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="section
                     |sect1|sect2|sect3|sect4|sect5
                     |refsect1|refsect2|refsect3
                     |simplesect"
              mode="title.content">
  <xsl:param name="text-only" select="false()"/>
  <xsl:variable name="title" select="(sectioninfo/title
                                      |sect1info/title
                                      |sect2info/title
                                      |sect3info/title
                                      |sect4info/title
                                      |sect5info/title
                                      |refsect1info/title
                                      |refsect2info/title
                                      |refsect3info/title
                                      |title)[1]"/>

  <xsl:apply-templates select="$title" mode="title.content">
    <xsl:with-param name="text-only" select="$text-only"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="bibliography|glossary|index" mode="title.content">
  <xsl:param name="text-only" select="false()"/>
  <xsl:choose>
    <xsl:when test="title">
      <xsl:apply-templates select="title" mode="title.content">
        <xsl:with-param name="text-only" select="$text-only"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="gentext.element.name">
        <xsl:with-param name="element.name" select="name(.)"/>
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="figure|table|example|equation" mode="title.content">
  <xsl:param name="text-only" select="false()"/>
  <xsl:apply-templates select="title" mode="title.content">
    <xsl:with-param name="text-only" select="$text-only"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="abstract" mode="title.content">
  <xsl:param name="text-only" select="false()"/>
  <xsl:choose>
    <xsl:when test="title">
      <xsl:apply-templates select="title" mode="title.content">
        <xsl:with-param name="text-only" select="$text-only"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="gentext.element.name">
        <xsl:with-param name="element.name" select="name(.)"/>
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- ====================================================================== -->
<!-- subtitle content -->

<doc:mode mode="subtitle.content" xmlns="">
<refpurpose>Provides access to element subtitles</refpurpose>
<refdescription>
<para>Processing an element in the
<literal role="mode">subtitle.content</literal> mode produces the
subtitle of the element. If
<parameter>text-only</parameter> is true, the text of the title
is returned, without inline markup, otherwise inline markup is processed
(in the default mode). By default, <parameter>text-only</parameter>
is false.
</para>
</refdescription>
</doc:mode>

<xsl:template match="*" mode="subtitle.content">
  <xsl:message>
    <xsl:text>Request for subtitle of unexpected element: </xsl:text>
    <xsl:value-of select="name(.)"/>
  </xsl:message>
  <xsl:text>???SUBTITLE???</xsl:text>
</xsl:template>

<xsl:template match="subtitle" mode="subtitle.content">
  <xsl:param name="text-only" select="false()"/>
  <xsl:choose>
    <xsl:when test="$text-only">
      <xsl:value-of select="."/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="set" mode="subtitle.content">
  <xsl:param name="text-only" select="false()"/>
  <xsl:apply-templates select="(setinfo/subtitle|subtitle)[1]"
                       mode="subtitle.content">
    <xsl:with-param name="text-only" select="$text-only"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="book" mode="subtitle.content">
  <xsl:param name="text-only" select="false()"/>
  <xsl:apply-templates select="(bookinfo/subtitle|subtitle)[1]"
                       mode="subtitle.content">
    <xsl:with-param name="text-only" select="$text-only"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="part" mode="subtitle.content">
  <xsl:param name="text-only" select="false()"/>
  <xsl:apply-templates select="(partinfo/subtitle
                                |docinfo/subtitle
                                |subtitle)[1]"
                       mode="subtitle.content">
    <xsl:with-param name="text-only" select="$text-only"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="preface|chapter|appendix" mode="subtitle.content">
  <xsl:param name="text-only" select="false()"/>
  <xsl:apply-templates select="(docinfo/subtitle
                                |prefaceinfo/subtitle
                                |chapterinfo/subtitle
                                |appendixinfo/subtitle
                                |subtitle)[1]"
                       mode="subtitle.content">
    <xsl:with-param name="text-only" select="$text-only"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="dedication|colophon" mode="subtitle.content">
  <xsl:param name="text-only" select="false()"/>
  <xsl:apply-templates select="subtitle"
                       mode="subtitle.content">
    <xsl:with-param name="text-only" select="$text-only"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="reference" mode="subtitle.content">
  <xsl:param name="text-only" select="false()"/>
  <xsl:apply-templates select="(referenceinfo/subtitle
                                |docinfo/subtitle
                                |subtitle)[1]"
                       mode="subtitle.content">
    <xsl:with-param name="text-only" select="$text-only"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="refentry" mode="subtitle.content">
  <xsl:param name="text-only" select="false()"/>
  <xsl:apply-templates select="(refentryinfo/subtitle
                                |docinfo/subtitle)[1]"
                       mode="subtitle.content">
    <xsl:with-param name="text-only" select="$text-only"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="section
                     |sect1|sect2|sect3|sect4|sect5
                     |refsect1|refsect2|refsect3
                     |simplesect"
              mode="subtitle.content">
  <xsl:param name="text-only" select="false()"/>
  <xsl:apply-templates select="(sectioninfo/subtitle
                                |sect1info/subtitle
                                |sect2info/subtitle
                                |sect3info/subtitle
                                |sect4info/subtitle
                                |sect5info/subtitle
                                |refsect1info/subtitle
                                |refsect2info/subtitle
                                |refsect3info/subtitle
                                |subtitle)[1]"
                       mode="subtitle.content">
    <xsl:with-param name="text-only" select="$text-only"/>
  </xsl:apply-templates>
</xsl:template>

<!-- ====================================================================== -->
<!-- title reference (label + title) -->

<doc:mode mode="title.ref" xmlns="">
<refpurpose>Provides reference text for an element</refpurpose>
<refdescription>
<para>Processing an element in the
<literal role="mode">title.ref</literal> mode produces the
label and title of the element. If
<parameter>text-only</parameter> is true, the text of the title
is returned, without inline markup, otherwise inline markup is processed
(in the default mode). By default, <parameter>text-only</parameter>
is false.
</para>
</refdescription>
</doc:mode>

<xsl:template match="*" mode="title.ref">
  <xsl:param name="text-only" select="false()"/>
  <xsl:variable name="label">
    <xsl:apply-templates select="." mode="label.content"/>
  </xsl:variable>

  <xsl:if test="$label != ''">
    <xsl:copy-of select="$label"/>
    <xsl:text> </xsl:text>
  </xsl:if>
  <xsl:apply-templates select="." mode="title.content">
    <xsl:with-param name="text-only" select="$text-only"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="figure|table|example|equation" mode="title.ref">
  <xsl:param name="text-only" select="false()"/>

  <xsl:call-template name="gentext.element.name">
    <xsl:with-param name="element.name">
      <xsl:value-of select="name(.)"/>
    </xsl:with-param>
  </xsl:call-template>
  <xsl:call-template name="gentext.space"/>
  <xsl:apply-templates select="." mode="label.content"/>
  <xsl:text> </xsl:text>
  <xsl:apply-templates select="." mode="title.content">
    <xsl:with-param name="text-only" select="$text-only"/>
  </xsl:apply-templates>
</xsl:template>

<!-- ====================================================================== -->

<xsl:template name="string.subst">
  <xsl:param name="string"></xsl:param>
  <xsl:param name="target"></xsl:param>
  <xsl:param name="replacement"></xsl:param>

  <xsl:choose>
    <xsl:when test="contains($string, $target)">
      <xsl:variable name="rest">
        <xsl:call-template name="string.subst">
          <xsl:with-param name="string"
                          select="substring-after($string, $target)"/>
          <xsl:with-param name="target" select="$target"/>
          <xsl:with-param name="replacement" select="$replacement"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:value-of select="concat(substring-before($string, $target),
                                   $replacement,
                                   $rest)"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$string"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- ====================================================================== -->

<xsl:template name="xref.g.subst">
  <xsl:param name="string"></xsl:param>
  <xsl:param name="target" select="."/>
  <xsl:variable name="subst">%g</xsl:variable>

  <xsl:choose>
    <xsl:when test="contains($string, $subst)">
      <xsl:value-of select="substring-before($string, $subst)"/>
      <xsl:call-template name="gentext.element.name">
        <xsl:with-param name="element.name" select="name($target)"/>
      </xsl:call-template>
      <xsl:call-template name="xref.g.subst">
        <xsl:with-param name="string"
                        select="substring-after($string, $subst)"/>
        <xsl:with-param name="target" select="$target"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$string"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="xref.t.subst">
  <xsl:param name="string"></xsl:param>
  <xsl:param name="target" select="."/>
  <xsl:variable name="subst">%t</xsl:variable>

  <xsl:choose>
    <xsl:when test="contains($string, $subst)">
      <xsl:call-template name="xref.g.subst">
        <xsl:with-param name="string"
                        select="substring-before($string, $subst)"/>
        <xsl:with-param name="target" select="$target"/>
      </xsl:call-template>
      <xsl:call-template name="title.xref">
        <xsl:with-param name="target" select="$target"/>
      </xsl:call-template>
      <xsl:call-template name="xref.t.subst">
        <xsl:with-param name="string"
                        select="substring-after($string, $subst)"/>
        <xsl:with-param name="target" select="$target"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="xref.g.subst">
        <xsl:with-param name="string" select="$string"/>
        <xsl:with-param name="target" select="$target"/>
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="xref.n.subst">
  <xsl:param name="string"></xsl:param>
  <xsl:param name="target" select="."/>
  <xsl:variable name="subst">%n</xsl:variable>

  <xsl:choose>
    <xsl:when test="contains($string, $subst)">
      <xsl:call-template name="xref.t.subst">
        <xsl:with-param name="string"
                        select="substring-before($string, $subst)"/>
        <xsl:with-param name="target" select="$target"/>
      </xsl:call-template>
      <xsl:call-template name="number.xref">
        <xsl:with-param name="target" select="$target"/>
      </xsl:call-template>
      <xsl:call-template name="xref.t.subst">
        <xsl:with-param name="string"
                        select="substring-after($string, $subst)"/>
        <xsl:with-param name="target" select="$target"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="xref.t.subst">
        <xsl:with-param name="string" select="$string"/>
        <xsl:with-param name="target" select="$target"/>
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="subst.xref.text">
  <xsl:param name="xref.text"></xsl:param>
  <xsl:param name="target" select="."/>

  <xsl:call-template name="xref.n.subst">
    <xsl:with-param name="string" select="$xref.text"/>
    <xsl:with-param name="target" select="$target"/>
  </xsl:call-template>
</xsl:template>

<!-- ====================================================================== -->

<xsl:template name="filename-extension">
  <xsl:param name="filename"></xsl:param>
  <xsl:param name="recurse" select="false()"/>

  <xsl:choose>
    <xsl:when test="substring-after($filename, '.') != ''">
      <xsl:call-template name="filename-extension">
        <xsl:with-param name="filename"
                        select="substring-after($filename, '.')"/>
        <xsl:with-param name="recurse" select="true()"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="$recurse">
      <xsl:value-of select="$filename"/>
    </xsl:when>
    <xsl:otherwise></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- ====================================================================== -->

<xsl:template name="mediaobject.filename">
  <xsl:param name="object"></xsl:param>

  <xsl:variable name="data" select="$object/videodata
                                    |$object/imagedata
                                    |$object/audiodata"/>

  <xsl:variable name="filename">
    <xsl:choose>
      <xsl:when test="$data[@fileref]">
        <xsl:value-of select="$data/@fileref"/>
      </xsl:when>
      <xsl:when test="$data[@entityref]">
        <xsl:value-of select="unparsed-entity-uri($data/@entityref)"/>
      </xsl:when>
      <xsl:otherwise></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="has.ext" select="contains($filename, '.') != ''"/>

  <xsl:variable name="ext">
    <xsl:choose>
      <xsl:when test="contains($filename, '.')">
        <xsl:call-template name="filename-extension">
          <xsl:with-param name="filename" select="$filename"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$graphic.default.extension"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="graphic.ext">
    <xsl:call-template name="is.graphic.extension">
      <xsl:with-param name="ext" select="$ext"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="not($has.ext)">
      <xsl:choose>
        <xsl:when test="$ext != ''">
          <xsl:value-of select="$filename"/>
          <xsl:text>.</xsl:text>
          <xsl:value-of select="$ext"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$filename"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:when test="not($graphic.ext)">
      <xsl:choose>
        <xsl:when test="$graphic.default.extension != ''">
          <xsl:value-of select="$filename"/>
          <xsl:text>.</xsl:text>
          <xsl:value-of select="$graphic.default.extension"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$filename"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$filename"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- ====================================================================== -->

<doc:template name="check.id.unique" xmlns="">
<refpurpose>Warn users about references to non-unique IDs</refpurpose>
<refdescription>
<para>If passed an ID in <varname>linkend</varname>,
<function>check.id.unique</function> prints
a warning message to the user if either the ID does not exist or
the ID is not unique.</para>
</refdescription>
</doc:template>

<xsl:template name="check.id.unique">
  <xsl:param name="linkend"></xsl:param>
  <xsl:if test="$linkend != ''">
    <xsl:variable name="targets" select="id($linkend)"/>
    <xsl:variable name="target" select="$targets[1]"/>

    <xsl:if test="count($targets)=0">
      <xsl:message>
	<xsl:text>Error: no ID for constraint linkend: </xsl:text>
	<xsl:value-of select="$linkend"/>
	<xsl:text>.</xsl:text>
      </xsl:message>
    </xsl:if>

    <xsl:if test="count($targets)>1">
      <xsl:message>
	<xsl:text>Warning: multiple "IDs" for constraint linkend: </xsl:text>
	<xsl:value-of select="$linkend"/>
	<xsl:text>.</xsl:text>
      </xsl:message>
    </xsl:if>
  </xsl:if>
</xsl:template>

<doc:template name="check.idref.targets" xmlns="">
<refpurpose>Warn users about incorrectly typed references</refpurpose>
<refdescription>
<para>If passed an ID in <varname>linkend</varname>,
<function>check.idref.targets</function> makes sure that the element
pointed to by the link is one of the elements listed in
<varname>element-list</varname> and warns the user otherwise.</para>
</refdescription>
</doc:template>

<xsl:template name="check.idref.targets">
  <xsl:param name="linkend"></xsl:param>
  <xsl:param name="element-list"></xsl:param>
  <xsl:if test="$linkend != ''">
    <xsl:variable name="targets" select="id($linkend)"/>
    <xsl:variable name="target" select="$targets[1]"/>

    <xsl:if test="count($target) &gt; 0">
      <xsl:if test="not(contains(concat(' ', $element-list, ' '), name($target)))">
	<xsl:message>
	  <xsl:text>Error: linkend (</xsl:text>
	  <xsl:value-of select="$linkend"/>
	  <xsl:text>) points to "</xsl:text>
	  <xsl:value-of select="name($target)"/>
	  <xsl:text>" not (one of): </xsl:text>
	  <xsl:value-of select="$element-list"/>
	</xsl:message>
      </xsl:if>
    </xsl:if>
  </xsl:if>
</xsl:template>

<!-- ====================================================================== -->

</xsl:stylesheet>

