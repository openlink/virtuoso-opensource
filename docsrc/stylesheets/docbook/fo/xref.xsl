<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
                version='1.0'>

<!-- ********************************************************************
     $Id$
     ********************************************************************

     This file is part of the XSL DocBook Stylesheet distribution.
     See ../README or http://nwalsh.com/docbook/xsl/ for copyright
     and other information.

     ******************************************************************** -->

<!-- ==================================================================== -->

<xsl:template match="xref">
  <xsl:variable name="targets" select="id(@linkend)"/>
  <xsl:variable name="target" select="$targets[1]"/>
  <xsl:variable name="refelem" select="name($target)"/>

  <xsl:if test="$check.idref = '1'">
    <xsl:call-template name="check.id.unique">
      <xsl:with-param name="linkend" select="@linkend"/>
    </xsl:call-template>
  </xsl:if>

  <xsl:choose>
    <xsl:when test="$refelem=''">
      <xsl:message>
	<xsl:text>XRef to nonexistent id: </xsl:text>
	<xsl:value-of select="@linkend"/>
      </xsl:message>
      <xsl:text>???</xsl:text>
    </xsl:when>

    <xsl:when test="$target/@xreflabel">
      <fo:simple-link internal-destination="{@linkend}">
	<xsl:call-template name="xref.xreflabel">
	  <xsl:with-param name="target" select="$target"/>
	</xsl:call-template>
      </fo:simple-link>
    </xsl:when>

    <xsl:otherwise>
      <fo:simple-link internal-destination="{@linkend}">
        <xsl:choose>
	  <xsl:when test="@endterm">
	    <xsl:variable name="etargets" select="id(@endterm)"/>
	    <xsl:variable name="etarget" select="$etargets[1]"/>
	    <xsl:choose>
	      <xsl:when test="count($etarget) = 0">
		<xsl:message>
		  <xsl:value-of select="count($etargets)"/>
		  <xsl:text>Endterm points to nonexistent ID: </xsl:text>
		  <xsl:value-of select="@endterm"/>
		</xsl:message>
		<xsl:text>???</xsl:text>
	      </xsl:when>
	      <xsl:otherwise>
		<xsl:apply-templates select="$etarget" mode="xref.text"/>
	      </xsl:otherwise>
	    </xsl:choose>
	  </xsl:when>

          <xsl:when test="$refelem='figure'">
            <xsl:call-template name="xref.figure">
              <xsl:with-param name="target" select="$target"/>
            </xsl:call-template>
          </xsl:when>

          <xsl:when test="$refelem='example'">
            <xsl:call-template name="xref.example">
              <xsl:with-param name="target" select="$target"/>
            </xsl:call-template>
          </xsl:when>

          <xsl:when test="$refelem='table'">
            <xsl:call-template name="xref.table">
              <xsl:with-param name="target" select="$target"/>
            </xsl:call-template>
          </xsl:when>

          <xsl:when test="$refelem='equation'">
            <xsl:call-template name="xref.equation">
              <xsl:with-param name="target" select="$target"/>
            </xsl:call-template>
          </xsl:when>

          <xsl:when test="$refelem='dedication'">
            <xsl:call-template name="xref.dedication">
              <xsl:with-param name="target" select="$target"/>
            </xsl:call-template>
          </xsl:when>

          <xsl:when test="$refelem='preface'">
            <xsl:call-template name="xref.preface">
              <xsl:with-param name="target" select="$target"/>
            </xsl:call-template>
          </xsl:when>

          <xsl:when test="$refelem='chapter'">
            <xsl:call-template name="xref.chapter">
              <xsl:with-param name="target" select="$target"/>
            </xsl:call-template>
          </xsl:when>

          <xsl:when test="$refelem='appendix'">
            <xsl:call-template name="xref.appendix">
              <xsl:with-param name="target" select="$target"/>
            </xsl:call-template>
          </xsl:when>

          <xsl:when test="$refelem='bibliography'">
            <xsl:call-template name="xref.bibliography">
              <xsl:with-param name="target" select="$target"/>
            </xsl:call-template>
          </xsl:when>

          <xsl:when test="$refelem='glossary'">
            <xsl:call-template name="xref.glossary">
              <xsl:with-param name="target" select="$target"/>
            </xsl:call-template>
          </xsl:when>

          <xsl:when test="$refelem='index'">
            <xsl:call-template name="xref.index">
              <xsl:with-param name="target" select="$target"/>
            </xsl:call-template>
          </xsl:when>

          <xsl:when test="$refelem='section'
                          or $refelem='simplesect'
                          or $refelem='sect1'
                          or $refelem='sect2'
                          or $refelem='sect3'
                          or $refelem='sect4'
                          or $refelem='sect5'
                          or $refelem='refsect1'
                          or $refelem='refsect2'
                          or $refelem='refsect3'">
            <xsl:call-template name="xref.section">
              <xsl:with-param name="target" select="$target"/>
            </xsl:call-template>
          </xsl:when>

          <xsl:when test="$refelem='listitem' 
                          and name($target/..)='orderedlist'">
            <xsl:apply-templates select="$target" mode="xref"/>
          </xsl:when>

          <xsl:when test="$refelem='part'">
            <xsl:call-template name="xref.part">
              <xsl:with-param name="target" select="$target"/>
            </xsl:call-template>
          </xsl:when>

          <xsl:when test="$refelem='reference'">
            <xsl:call-template name="xref.reference">
              <xsl:with-param name="target" select="$target"/>
            </xsl:call-template>
          </xsl:when>

          <xsl:when test="$refelem='book'">
            <xsl:call-template name="xref.book">
              <xsl:with-param name="target" select="$target"/>
            </xsl:call-template>
          </xsl:when>

          <xsl:otherwise>
	    <xsl:message>
	      <xsl:text>[Don't know what gentext to create for xref to: "</xsl:text>
	      <xsl:value-of select="$refelem"/>
	      <xsl:text>"]</xsl:text>
	    </xsl:message>
	    <xsl:text>???</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </fo:simple-link>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template name="xref.figure">
  <xsl:param name="target" select="."/>
  <xsl:param name="refelem" select="name($target)"/>

  <xsl:apply-templates select="$target" mode="label.content"/>

  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">ldquo</xsl:with-param>
  </xsl:call-template>
  <xsl:apply-templates select="$target" mode="title.content"/>
  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">rdquo</xsl:with-param>
  </xsl:call-template>
</xsl:template>

<xsl:template name="xref.example">
  <xsl:param name="target" select="."/>
  <xsl:param name="refelem" select="name($target)"/>

  <xsl:apply-templates select="$target" mode="label.content"/>

  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">ldquo</xsl:with-param>
  </xsl:call-template>
  <xsl:apply-templates select="$target" mode="title.content"/>
  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">rdquo</xsl:with-param>
  </xsl:call-template>
</xsl:template>

<xsl:template name="xref.table">
  <xsl:param name="target" select="."/>
  <xsl:param name="refelem" select="name($target)"/>

  <xsl:apply-templates select="$target" mode="label.content"/>

  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">ldquo</xsl:with-param>
  </xsl:call-template>
  <xsl:apply-templates select="$target" mode="title.content"/>
  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">rdquo</xsl:with-param>
  </xsl:call-template>
</xsl:template>

<xsl:template name="xref.equation">
  <xsl:param name="target" select="."/>
  <xsl:param name="refelem" select="name($target)"/>

  <xsl:apply-templates select="$target" mode="label.content"/>

  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">ldquo</xsl:with-param>
  </xsl:call-template>
  <xsl:apply-templates select="$target" mode="title.content"/>
  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">rdquo</xsl:with-param>
  </xsl:call-template>
</xsl:template>

<xsl:template name="xref.dedication">
  <xsl:param name="target" select="."/>
  <xsl:param name="refelem" select="name($target)"/>

  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">ldquo</xsl:with-param>
  </xsl:call-template>

  <xsl:apply-templates select="$target" mode="title.ref"/>

  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">rdquo</xsl:with-param>
  </xsl:call-template>
</xsl:template>

<xsl:template name="xref.preface">
  <xsl:param name="target" select="."/>
  <xsl:param name="refelem" select="name($target)"/>

  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">ldquo</xsl:with-param>
  </xsl:call-template>

  <xsl:apply-templates select="$target" mode="title.ref"/>

  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">rdquo</xsl:with-param>
  </xsl:call-template>
</xsl:template>

<xsl:template name="xref.chapter">
  <xsl:param name="target" select="."/>
  <xsl:param name="refelem" select="name($target)"/>

  <xsl:call-template name="gentext.element.name">
    <xsl:with-param name="element.name">
      <xsl:value-of select="$refelem"/>
    </xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="gentext.space"/>

  <xsl:apply-templates select="$target" mode="component.number"/>

  <xsl:text>, </xsl:text>
  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">ldquo</xsl:with-param>
  </xsl:call-template>
  <xsl:apply-templates select="$target/title" mode="xref"/>
  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">rdquo</xsl:with-param>
  </xsl:call-template>
</xsl:template>

<xsl:template name="xref.appendix">
  <xsl:param name="target" select="."/>
  <xsl:param name="refelem" select="name($target)"/>

  <xsl:call-template name="gentext.element.name">
    <xsl:with-param name="element.name">
      <xsl:value-of select="$refelem"/>
    </xsl:with-param>
  </xsl:call-template>

  <xsl:call-template name="gentext.space"/>

  <xsl:apply-templates select="$target" mode="component.number"/>

  <xsl:text>, </xsl:text>
  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">ldquo</xsl:with-param>
  </xsl:call-template>
  <xsl:apply-templates select="$target/title" mode="xref"/>
  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">rdquo</xsl:with-param>
  </xsl:call-template>
</xsl:template>

<xsl:template name="xref.bibliography">
  <xsl:param name="target" select="."/>
  <xsl:param name="refelem" select="name($target)"/>

  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">ldquo</xsl:with-param>
  </xsl:call-template>

  <xsl:apply-templates select="$target" mode="title.ref"/>

  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">rdquo</xsl:with-param>
  </xsl:call-template>
</xsl:template>

<xsl:template name="xref.glossary">
  <xsl:param name="target" select="."/>
  <xsl:param name="refelem" select="name($target)"/>

  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">ldquo</xsl:with-param>
  </xsl:call-template>

  <xsl:apply-templates select="$target" mode="title.ref"/>

  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">rdquo</xsl:with-param>
  </xsl:call-template>
</xsl:template>

<xsl:template name="xref.index">
  <xsl:param name="target" select="."/>
  <xsl:param name="refelem" select="name($target)"/>

  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">ldquo</xsl:with-param>
  </xsl:call-template>

  <xsl:apply-templates select="$target" mode="title.ref"/>

  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">rdquo</xsl:with-param>
  </xsl:call-template>
</xsl:template>

<xsl:template name="xref.section">
  <xsl:param name="target" select="."/>
  <xsl:param name="refelem" select="name($target)"/>

  <xsl:text>the section called </xsl:text>
  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">ldquo</xsl:with-param>
  </xsl:call-template>
  <xsl:apply-templates select="$target" mode="title.content"/>
  <xsl:call-template name="dingbat">
    <xsl:with-param name="dingbat">rdquo</xsl:with-param>
  </xsl:call-template>
</xsl:template>

<xsl:template name="xref.part">
  <xsl:param name="target" select="."/>
  <xsl:param name="refelem" select="name($target)"/>

  <xsl:call-template name="gentext.element.name">
    <xsl:with-param name="element.name">
      <xsl:value-of select="$refelem"/>
    </xsl:with-param>
  </xsl:call-template>
  <xsl:call-template name="gentext.space"/>
  <xsl:apply-templates select="$target" mode="division.number"/>
</xsl:template>

<xsl:template name="xref.reference">
  <xsl:param name="target" select="."/>
  <xsl:param name="refelem" select="name($target)"/>

  <xsl:call-template name="gentext.element.name">
    <xsl:with-param name="element.name">
      <xsl:value-of select="$refelem"/>
    </xsl:with-param>
  </xsl:call-template>
  <xsl:call-template name="gentext.space"/>
  <xsl:apply-templates select="$target" mode="division.number"/>
</xsl:template>

<xsl:template name="xref.book">
  <xsl:param name="target" select="."/>
  <xsl:param name="refelem" select="name($target)"/>

  <xsl:variable name="title">
    <xsl:choose>
      <xsl:when test="$target/title">
        <xsl:apply-templates select="$target/title" mode="xref"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="$target/bookinfo/title"
                             mode="xref"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <fo:inline font-style="italic">
    <xsl:copy-of select="$title"/>
  </fo:inline>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="link">
  <xsl:variable name="linkend" select="@linkend"/>
  <xsl:variable name="targets" select="//node()[@id=$linkend]"/>
  <xsl:variable name="target" select="$targets[1]"/>
  <xsl:variable name="refelem">
    <xsl:value-of select="name($target)"/>
  </xsl:variable>
  <fo:simple-link internal-destination="{@linkend}">
    <xsl:apply-templates/>
  </fo:simple-link>
</xsl:template>

<xsl:template match="ulink">
  <fo:simple-link external-destination="{@url}">
    <xsl:apply-templates/>
  </fo:simple-link>
  <xsl:text> [</xsl:text>
  <xsl:value-of select="@url"/>
  <xsl:text>]</xsl:text>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template name="xref.xreflabel">
  <!-- called to process an xreflabel...you might use this to make  -->
  <!-- xreflabels come out in the right font for different targets, -->
  <!-- for example. -->
  <xsl:param name="target" select="."/>
  <xsl:value-of select="$target/@xreflabel"/>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="title" mode="xref">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="*" mode="xref.text">
  <!-- just skip top-level formatting -->
  <xsl:apply-templates/>
</xsl:template>

</xsl:stylesheet>
