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

<!-- ==================================================================== -->

<xsl:template match="*" mode="titlepage.mode">
  <!-- if an element isn't found in this mode, try the default mode -->
  <xsl:apply-templates select="."/>
</xsl:template>

<xsl:template match="abbrev" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="abstract" mode="titlepage.mode">
  <fo:block space-before.optimum="1.5em">
    <xsl:call-template name="formal.object.heading">
      <xsl:with-param name="title">
        <xsl:choose>
          <xsl:when test="title">
            <xsl:apply-templates select="title" 
                                 mode="titlepage.abstract.title.mode"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="gentext.element.name">
              <xsl:with-param name="element.name">
                <xsl:value-of select="name(.)"/>
              </xsl:with-param>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:with-param>
    </xsl:call-template>
    <xsl:apply-templates mode="titlepage.mode"/>
  </fo:block>
</xsl:template>

<xsl:template match="abstract/title" mode="titlepage.mode">
</xsl:template>

<xsl:template match="abstract/title" mode="titlepage.abstract.title.mode">
  <xsl:apply-templates mode="titlepage.mode"/>
</xsl:template>

<xsl:template match="address" mode="titlepage.mode">
<!-- this won't do quite what's desired... -->
  <fo:block>
    <xsl:apply-templates mode="titlepage.mode"/>
  </fo:block>
</xsl:template>

<xsl:template match="affiliation" mode="titlepage.mode">
  <fo:block>
    <xsl:apply-templates mode="titlepage.mode"/>
  </fo:block>
</xsl:template>

<xsl:template match="artpagenums" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="author" mode="titlepage.mode">
  <fo:block font-size="14pt" font-weight="bold">
    <xsl:call-template name="person.name"/>
  </fo:block>
  <xsl:apply-templates mode="titlepage.mode"
   select="./affiliation"/>
</xsl:template>

<xsl:template match="authorblurb" mode="titlepage.mode">
  <fo:block>
    <xsl:apply-templates mode="titlepage.mode"/>
  </fo:block>
</xsl:template>  

<xsl:template match="authorgroup" mode="titlepage.mode">
  <xsl:apply-templates mode="titlepage.mode"/>
</xsl:template>

<xsl:template match="authorinitials" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="bibliomisc" mode="titlepage.mode">
  <xsl:apply-templates mode="titlepage.mode"/>
</xsl:template>

<xsl:template match="bibliomset" mode="titlepage.mode">
  <xsl:apply-templates mode="titlepage.mode"/>
</xsl:template>

<xsl:template match="collab" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="confgroup" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="contractnum" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="contractsponsor" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="contrib" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="copyright" mode="titlepage.mode">
  <xsl:variable name="years" select="year"/>
  <xsl:variable name="holders" select="holder"/>

  <fo:block>
    <xsl:call-template name="gentext.element.name"/>
    <xsl:call-template name="gentext.space"/>
    <xsl:call-template name="dingbat">
      <xsl:with-param name="dingbat">copyright</xsl:with-param>
    </xsl:call-template>
    <xsl:call-template name="gentext.space"/>
    <xsl:apply-templates select="$years" mode="titlepage.mode"/>
    <xsl:call-template name="gentext.space"/>
    <xsl:call-template name="gentext.by"/>
    <xsl:call-template name="gentext.space"/>
    <xsl:apply-templates select="$holders" mode="titlepage.mode"/>
  </fo:block>
</xsl:template>

<xsl:template match="year" mode="titlepage.mode">
  <xsl:apply-templates/><xsl:text>, </xsl:text>
</xsl:template>

<xsl:template match="year[position()=last()]" mode="titlepage.mode">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="holder" mode="titlepage.mode">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="corpauthor" mode="titlepage.mode">
  <fo:block font-size="14pt" font-weight="bold">
    <xsl:apply-templates mode="titlepage.mode"/>
  </fo:block>
</xsl:template>

<xsl:template match="corpname" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="date" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="edition" mode="titlepage.mode">
  <fo:block>
    <xsl:apply-templates mode="titlepage.mode"/>
    <xsl:text> </xsl:text>
    <xsl:call-template name="gentext.element.name"/>
  </fo:block>
</xsl:template>

<xsl:template match="editor" mode="titlepage.mode">
  <fo:block font-size="14pt" font-weight="bold">
    <xsl:call-template name="person.name"/>
  </fo:block>
</xsl:template>

<xsl:template match="editor[position()=1]" mode="titlepage.mode">
  <fo:block font-size="12pt"
            font-weight="bold"
            space-before.optimum="1.5em">
    <xsl:call-template name="gentext.edited.by"/>
  </fo:block>
  <fo:block font-size="14pt" font-weight="bold">
    <xsl:call-template name="person.name"/>
  </fo:block>
</xsl:template>

<xsl:template match="firstname" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="graphic" mode="titlepage.mode">
  <!-- use the normal graphic handling code -->
  <xsl:apply-templates select="."/>
</xsl:template>

<xsl:template match="honorific" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="isbn" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="issn" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="itermset" mode="titlepage.mode">
</xsl:template>

<xsl:template match="invpartnumber" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="issuenum" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="jobtitle" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="keywordset" mode="titlepage.mode">
</xsl:template>

<xsl:template match="legalnotice " mode="titlepage.mode">
  <xsl:apply-templates mode="titlepage.mode"/>
</xsl:template>
  
<xsl:template match="legalnotice/title" mode="titlepage.mode">
</xsl:template>

<xsl:template match="lineage" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="modespec" mode="titlepage.mode">
</xsl:template>

<xsl:template match="orgdiv" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="orgname" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="othercredit" mode="titlepage.mode">
  <fo:block font-size="14pt" font-weight="bold">
    <xsl:call-template name="person.name"/>
  </fo:block>
  <xsl:apply-templates mode="titlepage.mode"
   select="./affiliation"/>
</xsl:template>

<xsl:template match="othername" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="pagenums" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="printhistory" mode="titlepage.mode">
  <fo:block>
    <xsl:apply-templates mode="titlepage.mode"/>
  </fo:block>
</xsl:template>

<xsl:template match="productname" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="productnumber" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="pubdate" mode="titlepage.mode">
  <fo:block>
    <xsl:apply-templates mode="titlepage.mode"/>
  </fo:block>
</xsl:template>

<xsl:template match="publishername" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="pubsnumber" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="releaseinfo" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="revhistory" mode="titlepage.mode">
  <fo:block>
    <fo:table>
      <fo:table-body>
        <fo:table-row>
          <fo:table-cell number-columns-spanned="3">
            <fo:block>
              <xsl:call-template name="gentext.element.name"/>
            </fo:block>
          </fo:table-cell>
        </fo:table-row>
        <xsl:apply-templates mode="titlepage.mode"/>
      </fo:table-body>
    </fo:table>
  </fo:block>
</xsl:template>

<xsl:template match="revhistory/revision" mode="titlepage.mode">
  <xsl:variable name="revnumber" select=".//revnumber"/>
  <xsl:variable name="revdate"   select=".//date"/>
  <xsl:variable name="revauthor" select=".//authorinitials"/>
  <xsl:variable name="revremark" select=".//revremark"/>
  <fo:table-row>
    <fo:table-cell>
      <fo:block>
        <xsl:if test="$revnumber">
          <xsl:call-template name="gentext.element.name"/>
          <xsl:text> </xsl:text>
          <xsl:apply-templates select="$revnumber[1]" mode="titlepage.mode"/>
        </xsl:if>
      </fo:block>
    </fo:table-cell>
    <fo:table-cell>
      <fo:block>
        <xsl:apply-templates select="$revdate[1]" mode="titlepage.mode"/>
      </fo:block>
    </fo:table-cell>
    <fo:table-cell>
      <fo:block>
        <xsl:apply-templates select="$revauthor[1]" mode="titlepage.mode"/>
      </fo:block>
    </fo:table-cell>
  </fo:table-row>
  <xsl:if test="$revremark">
    <fo:table-row>
      <fo:table-cell number-columns-spanned="3">
        <fo:block>
          <xsl:apply-templates select="$revremark[1]" mode="titlepage.mode"/>
        </fo:block>
      </fo:table-cell>
    </fo:table-row>
  </xsl:if>
</xsl:template>

<xsl:template match="revision/revnumber" mode="titlepage.mode">
  <xsl:apply-templates mode="titlepage.mode"/>
</xsl:template>

<xsl:template match="revision/date" mode="titlepage.mode">
  <xsl:apply-templates mode="titlepage.mode"/>
</xsl:template>

<xsl:template match="revision/authorinitials" mode="titlepage.mode">
  <xsl:apply-templates mode="titlepage.mode"/>
</xsl:template>

<xsl:template match="revision/revremark" mode="titlepage.mode">
  <xsl:apply-templates mode="titlepage.mode"/>
</xsl:template>

<xsl:template match="seriesvolnums" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="shortaffil" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>
  
<xsl:template match="subjectset" mode="titlepage.mode">
</xsl:template>

<xsl:template match="subtitle" mode="titlepage.mode">
  <fo:block font-size="18pt" font-weight="bold">
    <xsl:apply-templates mode="titlepage.mode"/>
  </fo:block>
</xsl:template>

<xsl:template match="surname" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<xsl:template match="title" mode="titlepage.mode">
  <fo:block font-size="20pt"
            font-weight="bold"
            space-before.optimum="8em">
    <xsl:apply-templates mode="titlepage.mode"/>
  </fo:block>
</xsl:template>

<xsl:template match="titleabbrev" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>
  
<xsl:template match="volumenum" mode="titlepage.mode">
  <fo:inline>
    <xsl:apply-templates mode="titlepage.mode"/>
    <!--<br/>-->
  </fo:inline>
</xsl:template>

<!-- ==================================================================== -->

</xsl:stylesheet>
