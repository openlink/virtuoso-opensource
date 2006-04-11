<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<!--
 This stylesheet was created by template.xsl; do not edit it by hand.
-->

<xsl:template name="article.titlepage.recto">
  <xsl:apply-templates mode="article.titlepage.recto.mode" select="(articleinfo/title|artheader/title|title)[1]"/>
  <xsl:apply-templates mode="article.titlepage.recto.mode" select="(articleinfo/subtitle|artheader/subtitle|subtitle)[1]"/>
  <xsl:apply-templates mode="article.titlepage.recto.mode" select="articleinfo/corpauthor|artheader/corpauthor"/>
  <xsl:apply-templates mode="article.titlepage.recto.mode" select="articleinfo/authorgroup|artheader/authorgroup"/>
  <xsl:apply-templates mode="article.titlepage.recto.mode" select="articleinfo/author|artheader/author"/>
  <xsl:apply-templates mode="article.titlepage.recto.mode" select="articleinfo/releaseinfo|artheader/releaseinfo"/>
  <xsl:apply-templates mode="article.titlepage.recto.mode" select="articleinfo/copyright|artheader/copyright"/>
  <xsl:apply-templates mode="article.titlepage.recto.mode" select="articleinfo/pubdate|artheader/pubdate"/>
  <xsl:apply-templates mode="article.titlepage.recto.mode" select="articleinfo/revision|artheader/revision"/>
  <xsl:apply-templates mode="article.titlepage.recto.mode" select="articleinfo/revhistory|artheader/revhistory"/>
  <xsl:apply-templates mode="article.titlepage.recto.mode" select="articleinfo/abstract|artheader/abstract"/></xsl:template>

<xsl:template name="article.titlepage.verso"/>

<xsl:template name="article.titlepage.separator"><hr/></xsl:template>

<xsl:template name="article.titlepage.before.recto"/>

<xsl:template name="article.titlepage.before.verso"/>

<xsl:template name="article.titlepage">
  <div class="titlepage">
    <xsl:call-template name="article.titlepage.before.recto"/>
    <xsl:call-template name="article.titlepage.recto"/>
    <xsl:call-template name="article.titlepage.before.verso"/>
    <xsl:call-template name="article.titlepage.verso"/>
    <xsl:call-template name="article.titlepage.separator"/>
  </div>
</xsl:template>

<xsl:template match="*" mode="article.titlepage.recto.mode">
  <!-- if an element isn't found in this mode, -->
  <!-- try the generic titlepage.mode -->
  <xsl:apply-templates select="." mode="titlepage.mode"/>
</xsl:template>

<xsl:template match="*" mode="article.titlepage.verso.mode">
  <!-- if an element isn't found in this mode, -->
  <!-- try the generic titlepage.mode -->
  <xsl:apply-templates select="." mode="titlepage.mode"/>
</xsl:template>

<xsl:template name="book.titlepage.recto">
  <xsl:apply-templates mode="book.titlepage.recto.mode" select="(bookinfo/title|title)[1]"/>
  <xsl:apply-templates mode="book.titlepage.recto.mode" select="(bookinfo/subtitle|subtitle)[1]"/>
  <xsl:apply-templates mode="book.titlepage.recto.mode" select="bookinfo/corpauthor"/>
  <xsl:apply-templates mode="book.titlepage.recto.mode" select="bookinfo/authorgroup"/>
  <xsl:apply-templates mode="book.titlepage.recto.mode" select="bookinfo/author"/>
  <xsl:apply-templates mode="book.titlepage.recto.mode" select="bookinfo/releaseinfo"/>
  <xsl:apply-templates mode="book.titlepage.recto.mode" select="bookinfo/copyright"/>
  <xsl:apply-templates mode="book.titlepage.recto.mode" select="bookinfo/pubdate"/>
  <xsl:apply-templates mode="book.titlepage.recto.mode" select="bookinfo/revision"/>
  <xsl:apply-templates mode="book.titlepage.recto.mode" select="bookinfo/revhistory"/>
  <xsl:apply-templates mode="book.titlepage.recto.mode" select="bookinfo/abstract"/></xsl:template>

<xsl:template name="book.titlepage.verso"/>

<xsl:template name="book.titlepage.separator"><hr/></xsl:template>

<xsl:template name="book.titlepage.before.recto"/>

<xsl:template name="book.titlepage.before.verso"/>

<xsl:template name="book.titlepage">
  <div class="titlepage">
    <xsl:call-template name="book.titlepage.before.recto"/>
    <xsl:call-template name="book.titlepage.recto"/>
    <xsl:call-template name="book.titlepage.before.verso"/>
    <xsl:call-template name="book.titlepage.verso"/>
    <xsl:call-template name="book.titlepage.separator"/>
  </div>
</xsl:template>

<xsl:template match="*" mode="book.titlepage.recto.mode">
  <!-- if an element isn't found in this mode, -->
  <!-- try the generic titlepage.mode -->
  <xsl:apply-templates select="." mode="titlepage.mode"/>
</xsl:template>

<xsl:template match="*" mode="book.titlepage.verso.mode">
  <!-- if an element isn't found in this mode, -->
  <!-- try the generic titlepage.mode -->
  <xsl:apply-templates select="." mode="titlepage.mode"/>
</xsl:template>

<xsl:template name="part.titlepage.recto">
  <xsl:apply-templates mode="part.titlepage.recto.mode" select="(partinfo/title|docinfo/title|title)[1]"/>
  <xsl:apply-templates mode="part.titlepage.recto.mode" select="(partinfo/subtitle|docinfo/subtitle|subtitle)[1]"/>
  <xsl:apply-templates mode="part.titlepage.recto.mode" select="partinfo/corpauthor|docinfo/corpauthor"/>
  <xsl:apply-templates mode="part.titlepage.recto.mode" select="partinfo/authorgroup|docinfo/authorgroup"/>
  <xsl:apply-templates mode="part.titlepage.recto.mode" select="partinfo/author|docinfo/author"/>
  <xsl:apply-templates mode="part.titlepage.recto.mode" select="partinfo/releaseinfo|docinfo/releaseinfo"/>
  <xsl:apply-templates mode="part.titlepage.recto.mode" select="partinfo/copyright|docinfo/copyright"/>
  <xsl:apply-templates mode="part.titlepage.recto.mode" select="partinfo/pubdate|docinfo/pubdate"/>
  <xsl:apply-templates mode="part.titlepage.recto.mode" select="partinfo/revision|docinfo/revision"/>
  <xsl:apply-templates mode="part.titlepage.recto.mode" select="partinfo/revhistory|docinfo/revhistory"/>
  <xsl:apply-templates mode="part.titlepage.recto.mode" select="partinfo/abstract|docinfo/abstract"/></xsl:template>

<xsl:template name="part.titlepage.verso"/>

<xsl:template name="part.titlepage.separator"><hr/></xsl:template>

<xsl:template name="part.titlepage.before.recto"/>

<xsl:template name="part.titlepage.before.verso"/>

<xsl:template name="part.titlepage">
  <div class="titlepage">
    <xsl:call-template name="part.titlepage.before.recto"/>
    <xsl:call-template name="part.titlepage.recto"/>
    <xsl:call-template name="part.titlepage.before.verso"/>
    <xsl:call-template name="part.titlepage.verso"/>
    <xsl:call-template name="part.titlepage.separator"/>
  </div>
</xsl:template>

<xsl:template match="*" mode="part.titlepage.recto.mode">
  <!-- if an element isn't found in this mode, -->
  <!-- try the generic titlepage.mode -->
  <xsl:apply-templates select="." mode="titlepage.mode"/>
</xsl:template>

<xsl:template match="*" mode="part.titlepage.verso.mode">
  <!-- if an element isn't found in this mode, -->
  <!-- try the generic titlepage.mode -->
  <xsl:apply-templates select="." mode="titlepage.mode"/>
</xsl:template>

<xsl:template name="reference.titlepage.recto">
  <xsl:apply-templates mode="reference.titlepage.recto.mode" select="(referenceinfo/title|docinfo/title|title)[1]"/>
  <xsl:apply-templates mode="reference.titlepage.recto.mode" select="(referenceinfo/subtitle|docinfo/subtitle|subtitle)[1]"/>
  <xsl:apply-templates mode="reference.titlepage.recto.mode" select="referenceinfo/corpauthor|docinfo/corpauthor"/>
  <xsl:apply-templates mode="reference.titlepage.recto.mode" select="referenceinfo/authorgroup|docinfo/authorgroup"/>
  <xsl:apply-templates mode="reference.titlepage.recto.mode" select="referenceinfo/author|docinfo/author"/>
  <xsl:apply-templates mode="reference.titlepage.recto.mode" select="referenceinfo/releaseinfo|docinfo/releaseinfo"/>
  <xsl:apply-templates mode="reference.titlepage.recto.mode" select="referenceinfo/copyright|docinfo/copyright"/>
  <xsl:apply-templates mode="reference.titlepage.recto.mode" select="referenceinfo/pubdate|docinfo/pubdate"/>
  <xsl:apply-templates mode="reference.titlepage.recto.mode" select="referenceinfo/revision|docinfo/revision"/>
  <xsl:apply-templates mode="reference.titlepage.recto.mode" select="referenceinfo/revhistory|docinfo/revhistory"/>
  <xsl:apply-templates mode="reference.titlepage.recto.mode" select="referenceinfo/abstract|docinfo/abstract"/></xsl:template>

<xsl:template name="reference.titlepage.verso"/>

<xsl:template name="reference.titlepage.separator"><hr/></xsl:template>

<xsl:template name="reference.titlepage.before.recto"/>

<xsl:template name="reference.titlepage.before.verso"/>

<xsl:template name="reference.titlepage">
  <div class="titlepage">
    <xsl:call-template name="reference.titlepage.before.recto"/>
    <xsl:call-template name="reference.titlepage.recto"/>
    <xsl:call-template name="reference.titlepage.before.verso"/>
    <xsl:call-template name="reference.titlepage.verso"/>
    <xsl:call-template name="reference.titlepage.separator"/>
  </div>
</xsl:template>

<xsl:template match="*" mode="reference.titlepage.recto.mode">
  <!-- if an element isn't found in this mode, -->
  <!-- try the generic titlepage.mode -->
  <xsl:apply-templates select="." mode="titlepage.mode"/>
</xsl:template>

<xsl:template match="*" mode="reference.titlepage.verso.mode">
  <!-- if an element isn't found in this mode, -->
  <!-- try the generic titlepage.mode -->
  <xsl:apply-templates select="." mode="titlepage.mode"/>
</xsl:template>

<xsl:template name="section.titlepage.recto">
  <xsl:apply-templates mode="section.titlepage.recto.mode" select="(sectioninfo/title|sectioninfo/title|title)[1]"/>
  <xsl:apply-templates mode="section.titlepage.recto.mode" select="(sectioninfo/subtitle|sectioninfo/subtitle|subtitle)[1]"/>
  <xsl:apply-templates mode="section.titlepage.recto.mode" select="sectioninfo/corpauthor|sectioninfo/corpauthor"/>
  <xsl:apply-templates mode="section.titlepage.recto.mode" select="sectioninfo/authorgroup|sectioninfo/authorgroup"/>
  <xsl:apply-templates mode="section.titlepage.recto.mode" select="sectioninfo/author|sectioninfo/author"/>
  <xsl:apply-templates mode="section.titlepage.recto.mode" select="sectioninfo/releaseinfo|sectioninfo/releaseinfo"/>
  <xsl:apply-templates mode="section.titlepage.recto.mode" select="sectioninfo/copyright|sectioninfo/copyright"/>
  <xsl:apply-templates mode="section.titlepage.recto.mode" select="sectioninfo/pubdate|sectioninfo/pubdate"/>
  <xsl:apply-templates mode="section.titlepage.recto.mode" select="sectioninfo/revision|sectioninfo/revision"/>
  <xsl:apply-templates mode="section.titlepage.recto.mode" select="sectioninfo/revhistory|sectioninfo/revhistory"/>
  <xsl:apply-templates mode="section.titlepage.recto.mode" select="sectioninfo/abstract|sectioninfo/abstract"/></xsl:template>

<xsl:template name="section.titlepage.verso"/>

<xsl:template name="section.titlepage.separator"><hr/></xsl:template>

<xsl:template name="section.titlepage.before.recto"/>

<xsl:template name="section.titlepage.before.verso"/>

<xsl:template name="section.titlepage">
  <div class="titlepage">
    <xsl:call-template name="section.titlepage.before.recto"/>
    <xsl:call-template name="section.titlepage.recto"/>
    <xsl:call-template name="section.titlepage.before.verso"/>
    <xsl:call-template name="section.titlepage.verso"/>
    <xsl:call-template name="section.titlepage.separator"/>
  </div>
</xsl:template>

<xsl:template match="*" mode="section.titlepage.recto.mode">
  <!-- if an element isn't found in this mode, -->
  <!-- try the generic titlepage.mode -->
  <xsl:apply-templates select="." mode="titlepage.mode"/>
</xsl:template>

<xsl:template match="*" mode="section.titlepage.verso.mode">
  <!-- if an element isn't found in this mode, -->
  <!-- try the generic titlepage.mode -->
  <xsl:apply-templates select="." mode="titlepage.mode"/>
</xsl:template>

<xsl:template name="set.titlepage.recto">
  <xsl:apply-templates mode="set.titlepage.recto.mode" select="(setinfo/title|title)[1]"/>
  <xsl:apply-templates mode="set.titlepage.recto.mode" select="(setinfo/subtitle|subtitle)[1]"/>
  <xsl:apply-templates mode="set.titlepage.recto.mode" select="setinfo/corpauthor"/>
  <xsl:apply-templates mode="set.titlepage.recto.mode" select="setinfo/authorgroup"/>
  <xsl:apply-templates mode="set.titlepage.recto.mode" select="setinfo/author"/>
  <xsl:apply-templates mode="set.titlepage.recto.mode" select="setinfo/releaseinfo"/>
  <xsl:apply-templates mode="set.titlepage.recto.mode" select="setinfo/copyright"/>
  <xsl:apply-templates mode="set.titlepage.recto.mode" select="setinfo/pubdate"/>
  <xsl:apply-templates mode="set.titlepage.recto.mode" select="setinfo/revision"/>
  <xsl:apply-templates mode="set.titlepage.recto.mode" select="setinfo/revhistory"/>
  <xsl:apply-templates mode="set.titlepage.recto.mode" select="setinfo/abstract"/></xsl:template>

<xsl:template name="set.titlepage.verso"/>

<xsl:template name="set.titlepage.separator"><hr/></xsl:template>

<xsl:template name="set.titlepage.before.recto"/>

<xsl:template name="set.titlepage.before.verso"/>

<xsl:template name="set.titlepage">
  <div class="titlepage">
    <xsl:call-template name="set.titlepage.before.recto"/>
    <xsl:call-template name="set.titlepage.recto"/>
    <xsl:call-template name="set.titlepage.before.verso"/>
    <xsl:call-template name="set.titlepage.verso"/>
    <xsl:call-template name="set.titlepage.separator"/>
  </div>
</xsl:template>

<xsl:template match="*" mode="set.titlepage.recto.mode">
  <!-- if an element isn't found in this mode, -->
  <!-- try the generic titlepage.mode -->
  <xsl:apply-templates select="." mode="titlepage.mode"/>
</xsl:template>

<xsl:template match="*" mode="set.titlepage.verso.mode">
  <!-- if an element isn't found in this mode, -->
  <!-- try the generic titlepage.mode -->
  <xsl:apply-templates select="." mode="titlepage.mode"/>
</xsl:template>

</xsl:stylesheet>