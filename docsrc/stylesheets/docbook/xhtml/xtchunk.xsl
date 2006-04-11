<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xt="http://www.jclark.com/xt"
		version="1.0"
                extension-element-prefixes="xt">

<!-- NB: because xt:document doesn't seem to accept an AVT in its -->
<!-- method attribute, some code has to be duplicated here. Check -->
<!-- to make sure this code is in sync with ../html/xtchunk.xsl   -->
<!-- if you're having difficulties :-(                            -->

<xsl:include href="../html/xtchunk.xsl"/>

<xsl:variable name="html.ext">.xhtm</xsl:variable>

<xsl:output method="xml"/>

<xsl:template match="set|book|part|preface|chapter|appendix
                     |article
                     |reference|refentry
                     |sect1[position()>1]
                     |section[position()>1 and name(parent::*) != 'section']
                     |setindex
                     |book/glossary|article/glossary
                     |book/bibliography|article/bibliography
                     |book/index|article/index
                     |colophon">
  <xsl:variable name="prev"
    select="(preceding::book[1]
             |preceding::preface[1]
             |preceding::chapter[1]
             |preceding::appendix[1]
             |preceding::part[1]
             |preceding::reference[1]
             |preceding::refentry[1]
             |preceding::colophon[1]
             |preceding::sect1[position()=1
                               and name(preceding-sibling::*[1]) = 'sect1']
             |preceding::section[position()=1
                                 and name(preceding-sibling::*[1]) = 'section'
                                 and name(parent::*) != 'section']
             |preceding::article[1]
             |preceding::bibliography[1]
             |preceding::glossary[1]
             |preceding::index[1]
             |preceding::setindex[1]
             |ancestor::set
             |ancestor::book[1]
             |ancestor::preface[1]
             |ancestor::chapter[1]
             |ancestor::appendix[1]
             |ancestor::part[1]
             |ancestor::reference[1]
             |ancestor::article[1])[last()]"/>

  <xsl:variable name="next"
    select="(following::book[1]
             |following::preface[1]
             |following::chapter[1]
             |following::appendix[1]
             |following::part[1]
             |following::reference[1]
             |following::refentry[1]
             |following::colophon[1]
             |following::sect1[1]
             |following::section[name(parent::*) != 'section']
             |following::bibliography[1]
             |following::glossary[1]
             |following::index[1]
             |following::article[1]
             |following::setindex[1]
             |descendant::book[1]
             |descendant::preface[1]
             |descendant::chapter[1]
             |descendant::appendix[1]
             |descendant::article[1]
             |descendant::bibliography[1]
             |descendant::glossary[1]
             |descendant::index[1]
             |descendant::colophon[1]
             |descendant::setindex[1]
             |descendant::part[1]
             |descendant::reference[1]
             |descendant::refentry[1]
             |descendant::sect1[2]
             |descendant::section[position()=2
                                  and name(parent::*) != 'section'])[1]"/>

  <xsl:variable name="ischunk"><xsl:call-template name="chunk"/></xsl:variable>
  <xsl:variable name="chunkfn">
    <xsl:if test="$ischunk='1'">
      <xsl:apply-templates mode="chunk-filename" select="."/>
    </xsl:if>
  </xsl:variable>

  <xsl:if test="$ischunk='0'">
    <xsl:message>
      <xsl:text>Error </xsl:text>
      <xsl:value-of select="name(.)"/>
      <xsl:text> is not a chunk!</xsl:text>
    </xsl:message>
  </xsl:if>

  <xsl:message>
    <xsl:text>Writing </xsl:text>
    <xsl:value-of select="$chunkfn"/>
    <xsl:text> for </xsl:text>
    <xsl:value-of select="name(.)"/>
  </xsl:message>

  <xt:document method="html" href="{$chunkfn}">
    <html>
      <xsl:call-template name="html.head">
        <xsl:with-param name="prev" select="$prev"/>
        <xsl:with-param name="next" select="$next"/>
      </xsl:call-template>

      <body>
        <xsl:call-template name="header.navigation">
          <xsl:with-param name="prev" select="$prev"/>
          <xsl:with-param name="next" select="$next"/>
        </xsl:call-template>


        <xsl:apply-imports/>

        <xsl:call-template name="footer.navigation">
          <xsl:with-param name="prev" select="$prev"/>
          <xsl:with-param name="next" select="$next"/>
        </xsl:call-template>
      </body>
    </html>
  </xt:document>
</xsl:template>

</xsl:stylesheet>
