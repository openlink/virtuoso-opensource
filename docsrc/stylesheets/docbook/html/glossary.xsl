<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

<!-- ********************************************************************
     $Id$
     ********************************************************************

     This file is part of the XSL DocBook Stylesheet distribution.
     See ../README or http://nwalsh.com/docbook/xsl/ for copyright
     and other information.

     ******************************************************************** -->

<!-- ==================================================================== -->

<xsl:template match="glossary">
  <div class="{name(.)}">
    <xsl:call-template name="component.separator"/>
    <xsl:choose>
      <xsl:when test="./title">
	<xsl:apply-templates select="./title" mode="component.title.mode"/>
      </xsl:when>
      <xsl:otherwise>
	<h2 class="title">
	  <a>
	    <xsl:attribute name="name">
	      <xsl:call-template name="object.id"/>
	    </xsl:attribute>
	  </a>
	  <xsl:call-template name="gentext.element.name"/>
	</h2>
      </xsl:otherwise>
    </xsl:choose>

    <xsl:if test="./subtitle">
      <xsl:apply-templates select="./subtitle" mode="component.title.mode"/>
    </xsl:if>

    <dl>
      <xsl:apply-templates/>
    </dl>

    <xsl:call-template name="process.footnotes"/>
  </div>
</xsl:template>

<xsl:template match="glossary/glossaryinfo"></xsl:template>
<xsl:template match="glossary/title"></xsl:template>
<xsl:template match="glossary/subtitle"></xsl:template>
<xsl:template match="glossary/titleabbrev"></xsl:template>

<xsl:template match="glossary/title" mode="component.title.mode">
  <h2>
    <xsl:apply-templates/>
  </h2>
</xsl:template>

<xsl:template match="glossary/subtitle" mode="component.title.mode">
  <h3>
    <i><xsl:apply-templates/></i>
  </h3>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="glosslist">
  <div class="{name(.)}">
    <a>
      <xsl:attribute name="name">
        <xsl:call-template name="object.id"/>
      </xsl:attribute>
    </a>

    <dl>
      <xsl:apply-templates/>
    </dl>
  </div>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="glossdiv">
  <div class="{name(.)}">
    <xsl:apply-templates/>
  </div>
</xsl:template>

<xsl:template match="glossdiv/title">
  <h3 class="{name(.)}">
    <xsl:apply-templates/>
  </h3>
</xsl:template>

<!-- ==================================================================== -->

<!--
GlossEntry ::=
  GlossTerm, Acronym?, Abbrev?,
  (IndexTerm)*,
  RevHistory?,
  (GlossSee | GlossDef+)
-->

<xsl:template match="glossentry">
  <xsl:apply-templates/>
</xsl:template>
  
<xsl:template match="glossentry/glossterm">
  <dt>
    <xsl:apply-templates/>
  </dt>
</xsl:template>

<xsl:template match="glossentry/glossterm[1]">
  <dt>
    <a>
      <xsl:attribute name="name">
        <xsl:call-template name="object.id">
           <xsl:with-param name="object" select=".."/>
        </xsl:call-template>
      </xsl:attribute>

      <xsl:apply-templates/>
    </a>
  </dt>
</xsl:template>


  
<xsl:template match="glossentry/acronym">
</xsl:template>
  
<xsl:template match="glossentry/abbrev">
</xsl:template>
  
<xsl:template match="glossentry/revhistory">
</xsl:template>
  
<xsl:template match="glossentry/glosssee">
  <xsl:variable name="otherterm" select="@otherterm"/>
  <xsl:variable name="targets" select="//node()[@id=$otherterm]"/>
  <xsl:variable name="target" select="$targets[1]"/>
  <dd>
    <p>
      <xsl:call-template name="gentext.element.name"/>
      <xsl:call-template name="gentext.space"/>
      <xsl:choose>
        <xsl:when test="@otherterm">
          <a href="#{@otherterm}">
            <xsl:apply-templates select="$target" mode="xref"/>
          </a>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:text>.</xsl:text>
    </p>
  </dd>
</xsl:template>
  
<xsl:template match="glossentry/glossdef">
  <dd><xsl:apply-templates/></dd>
</xsl:template>

<xsl:template match="glossseealso">
  <xsl:variable name="otherterm" select="@otherterm"/>
  <xsl:variable name="targets" select="//node()[@id=$otherterm]"/>
  <xsl:variable name="target" select="$targets[1]"/>
  <p>
    <xsl:call-template name="gentext.element.name"/>
    <xsl:call-template name="gentext.space"/>
    <xsl:choose>
      <xsl:when test="@otherterm">
        <a href="#{@otherterm}">
          <xsl:apply-templates select="$target" mode="xref"/>
        </a>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>.</xsl:text>
  </p>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="glossentry" mode="xref">
  <xsl:apply-templates select="./glossterm[1]" mode="xref"/>
</xsl:template>

<xsl:template match="glossterm" mode="xref">
  <xsl:apply-templates/>
</xsl:template>

<!-- ==================================================================== -->

</xsl:stylesheet>
