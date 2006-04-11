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

<xsl:template match="itemizedlist">
  <xsl:variable name="id"><xsl:call-template name="object.id"/></xsl:variable>
  <fo:list-block id="{$id}"
                 space-before.minimum="0.8em"
                 space-before.optimum="1em"
                 space-before.maximum="1.2em">
    <xsl:apply-templates/>
  </fo:list-block>
</xsl:template>

<xsl:template match="itemizedlist/listitem">
  <xsl:variable name="id"><xsl:call-template name="object.id"/></xsl:variable>
  <fo:list-item id="{$id}"
                space-before.minimum="0.8em"
                space-before.optimum="1em"
                space-before.maximum="1.2em">
    <fo:list-item-label>
      <fo:block>
        <xsl:text>&#x2022;</xsl:text>
      </fo:block>
    </fo:list-item-label>
    <fo:list-item-body>
      <xsl:apply-templates/>
    </fo:list-item-body>
  </fo:list-item>
</xsl:template>

<xsl:template match="orderedlist">
  <xsl:variable name="id"><xsl:call-template name="object.id"/></xsl:variable>
  <fo:list-block id="{$id}"
                 space-before.minimum="0.8em"
                 space-before.optimum="1em"
                 space-before.maximum="1.2em">
    <xsl:apply-templates/>
  </fo:list-block>
</xsl:template>

<xsl:template match="orderedlist/listitem">
  <xsl:variable name="id"><xsl:call-template name="object.id"/></xsl:variable>
  <fo:list-item id="{$id}"
                space-before.minimum="0.8em"
                space-before.optimum="1em"
                space-before.maximum="1.2em">
    <fo:list-item-label>
      <fo:block>
        <xsl:number count="listitem" format="1."/>
      </fo:block>
    </fo:list-item-label>
    <fo:list-item-body>
      <xsl:apply-templates/>
    </fo:list-item-body>
  </fo:list-item>
</xsl:template>

<xsl:template match="listitem/para[1]">
  <fo:block>
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<xsl:template match="variablelist">
  <xsl:variable name="id"><xsl:call-template name="object.id"/></xsl:variable>
  <fo:list-block id="{$id}"
                 provisional-distance-between-starts="3in"
                 provisional-label-separation="0.25in"
                 space-before.minimum="0.8em"
                 space-before.optimum="1em"
                 space-before.maximum="1.2em">
    <xsl:apply-templates/>
  </fo:list-block>
</xsl:template>

<xsl:template match="varlistentry">
  <xsl:variable name="id"><xsl:call-template name="object.id"/></xsl:variable>
  <fo:list-item id="{$id}"
                space-before.minimum="0.8em"
                space-before.optimum="1em"
                space-before.maximum="1.2em">
    <fo:list-item-label>
      <fo:block>
        <xsl:apply-templates select="term"/>
      </fo:block>
    </fo:list-item-label>
    <fo:list-item-body>
      <xsl:apply-templates select="listitem"/>
    </fo:list-item-body>
  </fo:list-item>
</xsl:template>

<xsl:template match="varlistentry/term">
  <fo:inline><xsl:apply-templates/>, </fo:inline>
</xsl:template>

<xsl:template match="varlistentry/term[position()=last()]">
  <fo:inline><xsl:apply-templates/></fo:inline>
</xsl:template>

<xsl:template match="varlistentry/listitem">
  <xsl:apply-templates/>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="simplelist">
  <!-- with no type specified, the default is 'vert' -->
  <fo:table>
    <fo:table-body>
      <xsl:call-template name="simplelist.vert">
	<xsl:with-param name="cols">
	  <xsl:choose>
	    <xsl:when test="@columns">
	      <xsl:value-of select="@columns"/>
	    </xsl:when>
	    <xsl:otherwise>1</xsl:otherwise>
	  </xsl:choose>
	</xsl:with-param>
      </xsl:call-template>
    </fo:table-body>
  </fo:table>
</xsl:template>

<xsl:template match="simplelist[@type='inline']">
  <fo:inline><xsl:apply-templates/></fo:inline>
</xsl:template>

<xsl:template match="simplelist[@type='horiz']">
  <fo:table>
    <fo:table-body>
      <xsl:call-template name="simplelist.horiz">
	<xsl:with-param name="cols">
	  <xsl:choose>
	    <xsl:when test="@columns">
	      <xsl:value-of select="@columns"/>
	    </xsl:when>
	    <xsl:otherwise>1</xsl:otherwise>
	  </xsl:choose>
	</xsl:with-param>
      </xsl:call-template>
    </fo:table-body>
  </fo:table>
</xsl:template>

<xsl:template match="simplelist[@type='vert']">
  <fo:table>
    <fo:table-body>
      <xsl:call-template name="simplelist.vert">
	<xsl:with-param name="cols">
	  <xsl:choose>
	    <xsl:when test="@columns">
	      <xsl:value-of select="@columns"/>
	    </xsl:when>
	    <xsl:otherwise>1</xsl:otherwise>
	  </xsl:choose>
	</xsl:with-param>
      </xsl:call-template>
    </fo:table-body>
  </fo:table>
</xsl:template>

<xsl:template name="simplelist.horiz">
  <xsl:param name="cols">1</xsl:param>
  <xsl:param name="cell">1</xsl:param>
  <xsl:param name="members" select="./member"/>

  <xsl:if test="$cell &lt;= count($members)">
    <fo:table-row>
      <xsl:call-template name="simplelist.horiz.row">
        <xsl:with-param name="cols" select="$cols"/>
        <xsl:with-param name="cell" select="$cell"/>
        <xsl:with-param name="members" select="$members"/>
      </xsl:call-template>
   </fo:table-row>
    <xsl:call-template name="simplelist.horiz">
      <xsl:with-param name="cols" select="$cols"/>
      <xsl:with-param name="cell" select="$cell + $cols"/>
      <xsl:with-param name="members" select="$members"/>
    </xsl:call-template>
  </xsl:if>
</xsl:template>

<xsl:template name="simplelist.horiz.row">
  <xsl:param name="cols">1</xsl:param>
  <xsl:param name="cell">1</xsl:param>
  <xsl:param name="members" select="./member"/>
  <xsl:param name="curcol">1</xsl:param>

  <xsl:if test="$curcol &lt;= $cols">
    <fo:table-cell>
      <xsl:if test="$members[position()=$cell]">
        <xsl:apply-templates select="$members[position()=$cell]"/>
      </xsl:if>
    </fo:table-cell>
    <xsl:call-template name="simplelist.horiz.row">
      <xsl:with-param name="cols" select="$cols"/>
      <xsl:with-param name="cell" select="$cell+1"/>
      <xsl:with-param name="members" select="$members"/>
      <xsl:with-param name="curcol" select="$curcol+1"/>
    </xsl:call-template>
  </xsl:if>
</xsl:template>

<xsl:template name="simplelist.vert">
  <xsl:param name="cols">1</xsl:param>
  <xsl:param name="cell">1</xsl:param>
  <xsl:param name="members" select="./member"/>
  <xsl:param name="rows"
             select="floor((count($members)+$cols - 1) div $cols)"/>

  <xsl:if test="$cell &lt;= $rows">
    <fo:table-row>
      <xsl:call-template name="simplelist.vert.row">
        <xsl:with-param name="cols" select="$cols"/>
        <xsl:with-param name="rows" select="$rows"/>
        <xsl:with-param name="cell" select="$cell"/>
        <xsl:with-param name="members" select="$members"/>
      </xsl:call-template>
   </fo:table-row>
    <xsl:call-template name="simplelist.vert">
      <xsl:with-param name="cols" select="$cols"/>
      <xsl:with-param name="cell" select="$cell+1"/>
      <xsl:with-param name="members" select="$members"/>
      <xsl:with-param name="rows" select="$rows"/>
    </xsl:call-template>
  </xsl:if>
</xsl:template>

<xsl:template name="simplelist.vert.row">
  <xsl:param name="cols">1</xsl:param>
  <xsl:param name="rows">1</xsl:param>
  <xsl:param name="cell">1</xsl:param>
  <xsl:param name="members" select="./member"/>
  <xsl:param name="curcol">1</xsl:param>

  <xsl:if test="$curcol &lt;= $cols">
    <fo:table-cell>
      <xsl:if test="$members[position()=$cell]">
        <xsl:apply-templates select="$members[position()=$cell]"/>
      </xsl:if>
    </fo:table-cell>
    <xsl:call-template name="simplelist.vert.row">
      <xsl:with-param name="cols" select="$cols"/>
      <xsl:with-param name="rows" select="$rows"/>
      <xsl:with-param name="cell" select="$cell+$rows"/>
      <xsl:with-param name="members" select="$members"/>
      <xsl:with-param name="curcol" select="$curcol+1"/>
    </xsl:call-template>
  </xsl:if>
</xsl:template>

<xsl:template match="member">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="simplelist[@type='inline']/member">
  <xsl:apply-templates/>
  <xsl:text>, </xsl:text>
</xsl:template>

<xsl:template match="simplelist[@type='inline']/member[position()=last()]">
  <xsl:apply-templates/>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="procedure">
  <xsl:variable name="title" select="title"/>
  <xsl:variable name="preamble" 
                select="*[not(self::step or self::title)]"/>
  <xsl:variable name="steps" select="step"/>

  <fo:block space-before.optimum="1em"
            space-before.minimum="0.8em"
            space-before.maximum="1.2em">
    <xsl:if test="./title">
      <fo:block font-weight="bold">
        <xsl:apply-templates select="./title" mode="procedure.title.mode"/>
      </fo:block>
    </xsl:if>
    <xsl:apply-templates select="$preamble"/>
    <fo:list-block space-before.optimum="1em"
                   space-before.minimum="0.8em"
                   space-before.maximum="1.2em">
      <xsl:apply-templates select="$steps"/>
    </fo:list-block>
  </fo:block>
</xsl:template>

<xsl:template match="procedure/title">
</xsl:template>

<xsl:template match="procedure/title" mode="procedure.title.mode">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="substeps">
  <fo:list-block space-before.optimum="1em"
                 space-before.minimum="0.8em"
                 space-before.maximum="1.2em">
    <xsl:apply-templates/>
  </fo:list-block>
</xsl:template>

<xsl:template match="step">
  <fo:list-item>
    <fo:list-item-label>
      <fo:block>
        <xsl:number count="step" format="1."/>
      </fo:block>
    </fo:list-item-label>
    <fo:list-item-body><xsl:apply-templates/></fo:list-item-body>
  </fo:list-item>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="segmentedlist">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="segmentedlist/title">
  <fo:block font-weight="bold">
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<xsl:template match="segtitle">
</xsl:template>

<xsl:template match="segtitle" mode="segtitle-in-seg">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="seglistitem">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="seg">
  <xsl:variable name="segnum" select="position()"/>
  <xsl:variable name="seglist" select="ancestor::segmentedlist"/>
  <xsl:variable name="segtitles" select="$seglist/segtitle"/>

  <!--
     Note: segtitle is only going to be the right thing in a well formed
     SegmentedList.  If there are too many Segs or too few SegTitles,
     you'll get something odd...maybe an error
  -->

  <fo:block>
    <fo:inline font-weight="bold">
      <xsl:apply-templates select="$segtitles[$segnum=position()]"
                           mode="segtitle-in-seg"/>
      <xsl:text>: </xsl:text>
    </fo:inline>
    <xsl:apply-templates/>
  </fo:block>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="calloutlist">
  <fo:block>
    <xsl:if test="./title">
      <fo:block font-weight="bold">
        <xsl:apply-templates select="./title" mode="calloutlist.title.mode"/>
      </fo:block>
    </xsl:if>
    <fo:list-block space-before.optimum="1em"
                   space-before.minimum="0.8em"
                   space-before.maximum="1.2em">
      <xsl:apply-templates/>
    </fo:list-block>
  </fo:block>
</xsl:template>

<xsl:template match="calloutlist/title">
</xsl:template>

<xsl:template match="calloutlist/title" mode="calloutlist.title.mode">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="callout">
  <fo:list-item>
    <fo:list-item-label>
      <fo:block>CO</fo:block>
    </fo:list-item-label>
    <fo:list-item-body>
      <xsl:apply-templates/>
    </fo:list-item-body>
  </fo:list-item>
</xsl:template>

<!-- ==================================================================== -->

</xsl:stylesheet>

