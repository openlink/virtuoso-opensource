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

<xsl:template match="itemizedlist">
  <div class="{name(.)}">
    <xsl:if test="title">
      <xsl:apply-templates select="title"/>
    </xsl:if>
    <ul>
    <xsl:apply-templates select="listitem"/>
    </ul>
  </div>
</xsl:template>

<xsl:template match="itemizedlist/title">
  <p><b><xsl:apply-templates/></b></p>
</xsl:template>

<xsl:template name="orderedlist-starting-number">
  <xsl:param name="list" select="."/>
  <xsl:choose>
    <xsl:when test="$list/@continuation != 'continues'">1</xsl:when>
    <xsl:otherwise>
      <xsl:variable name="prevlist"
                    select="$list/preceding::orderedlist[1]"/>
      <xsl:choose>
        <xsl:when test="count($prevlist) = 0">2</xsl:when>
        <xsl:otherwise>
          <xsl:variable name="prevlength" select="count($prevlist/listitem)"/>
          <xsl:variable name="prevstart">
            <xsl:call-template name="orderedlist-starting-number">
              <xsl:with-param name="list" select="$prevlist"/>
            </xsl:call-template>
          </xsl:variable>
          <xsl:value-of select="$prevstart + $prevlength"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="orderedlist">
  <xsl:variable name="start">
    <xsl:choose>
      <xsl:when test="@continuation='continues'">
        <xsl:call-template name="orderedlist-starting-number"/>
      </xsl:when>
      <xsl:otherwise>1</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <div class="{name(.)}">
    <xsl:if test="title">
      <xsl:apply-templates select="title"/>
    </xsl:if>
    <ol>
    <xsl:if test="$start != '1'">
      <xsl:attribute name="start">
        <xsl:value-of select="$start"/>
      </xsl:attribute>
    </xsl:if>
    <xsl:apply-templates select="listitem"/>
    </ol>
  </div>
</xsl:template>

<xsl:template match="orderedlist/title">
  <p><b><xsl:apply-templates/></b></p>
</xsl:template>

<xsl:template match="variablelist">
  <div class="{name(.)}">
    <xsl:if test="title">
      <xsl:apply-templates select="title"/>
    </xsl:if>
    <dl>
    <xsl:apply-templates select="varlistentry"/>
    </dl>
  </div>
</xsl:template>

<xsl:template match="variablelist/title">
  <p><b><xsl:apply-templates/></b></p>
</xsl:template>

<xsl:template match="listitem">
  <xsl:variable name="id">
    <xsl:call-template name="object.id"/>
  </xsl:variable>
  <li><a name="{$id}"/><xsl:apply-templates/></li>
</xsl:template>

<xsl:template match="listitem" mode="xref">
  <xsl:number format="1"/>
</xsl:template>

<xsl:template match="varlistentry">
  <xsl:variable name="id">
    <xsl:call-template name="object.id"/>
  </xsl:variable>
  <dt><a name="{$id}"/><xsl:apply-templates select="term"/></dt>
  <dd><xsl:apply-templates select="listitem"/></dd>
</xsl:template>

<xsl:template match="varlistentry/term">
  <span class="term"><xsl:apply-templates/>, </span>
</xsl:template>

<xsl:template match="varlistentry/term[position()=last()]">
  <span class="term"><xsl:apply-templates/></span>
</xsl:template>

<xsl:template match="varlistentry/listitem">
  <xsl:apply-templates/>
</xsl:template>


<!-- ==================================================================== -->

<xsl:template match="simplelist">
  <!-- with no type specified, the default is 'vert' -->
  <table class="simplelist" border="0">
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
  </table>
</xsl:template>

<xsl:template match="simplelist[@type='inline']">
  <span class="{name(.)}"><xsl:apply-templates/></span>
</xsl:template>

<xsl:template match="simplelist[@type='horiz']">
  <table class="simplelist" border="0">
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
  </table>
</xsl:template>

<xsl:template match="simplelist[@type='vert']">
  <table class="simplelist" border="0">
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
  </table>
</xsl:template>

<xsl:template name="simplelist.horiz">
  <xsl:param name="cols">1</xsl:param>
  <xsl:param name="cell">1</xsl:param>
  <xsl:param name="members" select="./member"/>

  <xsl:if test="$cell &lt;= count($members)">
    <tr>
      <xsl:call-template name="simplelist.horiz.row">
        <xsl:with-param name="cols" select="$cols"/>
        <xsl:with-param name="cell" select="$cell"/>
        <xsl:with-param name="members" select="$members"/>
      </xsl:call-template>
   </tr>
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
    <td>
      <xsl:choose>
        <xsl:when test="$members[position()=$cell]">
          <xsl:apply-templates select="$members[position()=$cell]"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:choose>
            <xsl:when test="$using.chunker != 0">
              <xsl:text>&#160;</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:otherwise>
      </xsl:choose>
    </td>
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
    <tr>
      <xsl:call-template name="simplelist.vert.row">
	<xsl:with-param name="cols" select="$cols"/>
	<xsl:with-param name="rows" select="$rows"/>
	<xsl:with-param name="cell" select="$cell"/>
	<xsl:with-param name="members" select="$members"/>
      </xsl:call-template>
    </tr>
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
    <td>
      <xsl:choose>
        <xsl:when test="$members[position()=$cell]">
          <xsl:apply-templates select="$members[position()=$cell]"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:choose>
            <xsl:when test="$using.chunker != 0">
              <xsl:text>&#160;</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:otherwise>
      </xsl:choose>
    </td>
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
  <div class="{name(.)}">
    <xsl:if test="title">
      <xsl:apply-templates select="title" mode="procedure.title.mode"/>
    </xsl:if>
    <ol><xsl:apply-templates/></ol>
  </div>
</xsl:template>

<xsl:template match="procedure/title">
</xsl:template>

<xsl:template match="title" mode="procedure.title.mode">
  <p>
    <b>
      <xsl:apply-templates/>
    </b>
  </p>
</xsl:template>

<xsl:template match="substeps">
  <ol><xsl:apply-templates/></ol>
</xsl:template>

<xsl:template match="step">
  <li><xsl:apply-templates/></li>
</xsl:template>

<xsl:template match="step/title">
  <xsl:apply-templates select="." mode="procedure.title.mode"/>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="segmentedlist">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="segmentedlist/title">
  <p><b><xsl:apply-templates/></b></p>
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

  <p>
    <b>
      <xsl:apply-templates select="$segtitles[$segnum=position()]"
                           mode="segtitle-in-seg"/>
      <xsl:text>: </xsl:text>
    </b>
    <xsl:apply-templates/>
  </p>
</xsl:template>

<!-- ==================================================================== -->

<xsl:template match="calloutlist">
  <div class="{name(.)}">
    <xsl:if test="./title">
      <p>
        <b>
          <xsl:apply-templates select="./title" mode="calloutlist.title.mode"/>
        </b>
      </p>
    </xsl:if>
    <dl compact="compact"><xsl:apply-templates/></dl>
  </div>
</xsl:template>

<xsl:template match="calloutlist/title">
</xsl:template>

<xsl:template match="calloutlist/title" mode="calloutlist.title.mode">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="callout">
  <dt>
    <xsl:call-template name="callout.arearefs">
      <xsl:with-param name="arearefs" select="@arearefs"/>
    </xsl:call-template>
  </dt>
  <dl><xsl:apply-templates/></dl>
</xsl:template>

<xsl:template name="callout.arearefs">
  <xsl:param name="arearefs"></xsl:param>
  <xsl:if test="$arearefs!=''">
    <xsl:choose>
      <xsl:when test="substring-before($arearefs,' ')=''">
        <xsl:call-template name="callout.arearef">
          <xsl:with-param name="arearef" select="$arearefs"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="callout.arearef">
          <xsl:with-param name="arearef"
                          select="substring-before($arearefs,' ')"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:call-template name="callout.arearefs">
      <xsl:with-param name="arearefs"
                      select="substring-after($arearefs,' ')"/>
    </xsl:call-template>
  </xsl:if>
</xsl:template>

<xsl:template name="callout.arearef">
  <xsl:param name="arearef"></xsl:param>
  <xsl:variable name="targets" select="//node()[@id=$arearef]"/>
  <xsl:variable name="target" select="$targets[1]"/>

  <xsl:choose>
    <xsl:when test="count($target)=0">
      <xsl:value-of select="$arearef"/>
      <xsl:text>: ???</xsl:text>
    </xsl:when>
    <xsl:when test="local-name($target)='co'">
      <a>
        <xsl:attribute name="href">
          <xsl:text>#</xsl:text>
          <xsl:value-of select="$arearef"/>
        </xsl:attribute>
        <xsl:apply-templates select="$target" mode="callout-bug"/>
      </a>
      <xsl:text> </xsl:text>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>???</xsl:text>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- ==================================================================== -->

</xsl:stylesheet>

