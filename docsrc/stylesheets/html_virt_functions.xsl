<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

<xsl:output method="html"/>

<xsl:include href="virt_config.xsl"/>
<xsl:include href="html_virt_util.xsl"/>

<xsl:variable name="topgradienturl">
  <xsl:value-of select="concat ($imgroot, 'ref_topgradient.jpg')"/>
</xsl:variable>
<xsl:variable name="toplogourl">
  <xsl:value-of select="concat ($docroot, 'ref_2k_logo.jpg')"/>
</xsl:variable>

<xsl:template match="optional">
  <SPAN CLASS="paramdef_optional">
    <xsl:text>[</xsl:text>
      <xsl:apply-templates />
    <xsl:text>]</xsl:text>
  </SPAN>
</xsl:template>

<xsl:template match="paramdef/parameter">
  <xsl:text> </xsl:text>
  <xsl:apply-templates/>
  <xsl:text> </xsl:text>
</xsl:template>

<xsl:template match="paramdef">
  <SPAN CLASS="paramdef">
    <xsl:apply-templates/>
    <xsl:if test="following-sibling::paramdef">
      <xsl:text>, </xsl:text>
    </xsl:if>
  </SPAN>
</xsl:template>

<!-- Not all function reference items are functions -->

<xsl:template match="funcprototype">
  <xsl:value-of select="funcdef/function" />
  <xsl:if test="paramdef">
    <xsl:text> (</xsl:text>
      <xsl:apply-templates select="paramdef"/>
    <xsl:text>);</xsl:text>
  </xsl:if>
</xsl:template>

<xsl:template match="funcsynopsis">
  <P CLASS="funcsynopsis">
    <A>
      <xsl:attribute name="NAME"><xsl:value-of select="./@id" /></xsl:attribute>
    </A>
    <CODE CLASS="funcdef">
        <xsl:apply-templates />
    </CODE>
  </P>
</xsl:template>

<xsl:template match="para/function">
  <CODE CLASS="function"><xsl:apply-templates/></CODE>
</xsl:template>

<xsl:template match="para/parameter">
  <CODE CLASS="parameter"><xsl:apply-templates/></CODE>
</xsl:template>

<xsl:template match="para/type">
  <CODE CLASS="type"><xsl:apply-templates/></CODE>
</xsl:template>

<xsl:template match="example/screen">
  <P CLASS="examplecodepara">
    <PRE CLASS="example"><xsl:apply-templates/></PRE>
  </P>
</xsl:template>

<xsl:template match="programlisting">
  <P CLASS="programlistpara">
    <PRE CLASS="programlist"><xsl:apply-templates/></PRE>
  </P>
</xsl:template>

<xsl:template match="refnamediv"><xsl:apply-templates/></xsl:template>

<xsl:template match="errorcode">
  <CODE CLASS="errorcode">
    <xsl:apply-templates/>
  </CODE>
</xsl:template>

<xsl:template match="thead/row/entry">
  <TH>
    <xsl:apply-templates/>
  </TH>
</xsl:template>

<xsl:template match="tbody/row/entry">
  <TD>
    <xsl:apply-templates/>
  </TD>
</xsl:template>

<xsl:template match="tbody/row">
  <TR>
    <xsl:apply-templates/>
  </TR>
</xsl:template>

<xsl:template match="thead/row">
  <TR CLASS="theadrow">
    <xsl:apply-templates/>
  </TR>
</xsl:template>

<xsl:template match="table/title">
  <H4 CLASS="tabletitle"><xsl:apply-templates/></H4>
</xsl:template>

<xsl:template match="tgroup">
  <TABLE>
    <xsl:apply-templates/>
  </TABLE>
</xsl:template>

<xsl:template match="para">
  <P><xsl:apply-templates/></P>
</xsl:template>

<xsl:template match="refsynopsisdiv">
  <DIV CLASS="ref1synopsis"><H2 class="refsect1title">Synopsis</H2><xsl:apply-templates/></DIV>
</xsl:template>

<!-- Vanilla HTML heading tags for titles -->
<xsl:template match="refsect1/title">
  <xsl:choose>
    <xsl:when test="$renditionmode='single_page'">
      <H2 class="refsect1title">
        <xsl:apply-templates/>
      </H2>
    </xsl:when>
    <xsl:otherwise>
      <H3 class="refsect1title">
        <xsl:apply-templates/>
      </H3>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="refsect2/title">
  <xsl:choose>
    <xsl:when test="$renditionmode='single_page'">
      <H3 CLASS="refsect2title">
        <xsl:apply-templates/>
      </H3>
    </xsl:when>
    <xsl:otherwise>
      <H4 CLASS="refsect2title">
        <xsl:apply-templates/>
      </H4>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>
<xsl:template match="refsect3/title">
  <xsl:choose>
    <xsl:when test="$renditionmode='single_page'">
      <H4 CLASS="refsect3title">
        <xsl:apply-templates/>
      </H4>
    </xsl:when>
    <xsl:otherwise>
      <H5 CLASS="refsect3title">
        <xsl:apply-templates/>
      </H5>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>
<xsl:template match="example/title">
  <xsl:choose>
    <xsl:when test="$renditionmode='single_page'">
      <H3 CLASS="refsect3title">
        <xsl:apply-templates/>
      </H3>
    </xsl:when>
    <xsl:otherwise>
      <H4 CLASS="refsect3title">
        <xsl:apply-templates/>
      </H4>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>


<!-- Actually one template would do, but maybe someone wants to use CSS to make some xmas lights -->
<xsl:template match="refsect1[@id='params']">
  <DIV CLASS="ref1params">
    <xsl:apply-templates/>
  </DIV>
</xsl:template>
<xsl:template match="refsect1[@id='ret']">
  <DIV CLASS="ref1ret">
    <xsl:apply-templates/>
  </DIV>
</xsl:template>
<xsl:template match="refsect1[@id = 'errors']">
  <DIV CLASS="ref1errors">
    <xsl:apply-templates/>
  </DIV>
</xsl:template>
<xsl:template match="refsect1[contains(@id, 'err_')]">
  <DIV CLASS="ref1errors">
    <xsl:apply-templates/>
  </DIV>
</xsl:template>
<xsl:template match="refsect1[@id='desc']">
  <DIV CLASS="ref1desc">
    <xsl:apply-templates/>
  </DIV>
</xsl:template>
<xsl:template match="refsect1[@id='examples']">
  <DIV CLASS="ref1examples">
    <xsl:apply-templates/>
  </DIV>
</xsl:template>
<xsl:template match="refsect1[@id='seealso']">
  <DIV CLASS="ref1seealso">
    <xsl:apply-templates/>
  </DIV>
</xsl:template>

<!-- A fallback template... see above -->
<xsl:template match="refsect1[not(@id) or @id != 'params' and @id != 'ret' and @id != 'errors' and @id != 'desc' and @id != 'examples' and @id != 'seealso']">
  <DIV CLASS="ref1other">
    <xsl:apply-templates/>
  </DIV>
</xsl:template>

<!-- Are these some kind of fallback rules?
<xsl:template match="refsect2"><DIV CLASS="refsect2"><xsl:apply-templates/></DIV></xsl:template>
<xsl:template match="refsect3"><xsl:apply-templates/></xsl:template>
-->

<xsl:template match="refentry">
<xsl:choose>
  <xsl:when test="$renditionmode='single_page'">
    <HTML>
      <HEAD>
        <TITLE>
          <xsl:value-of select="refmeta/refentrytitle"/><xsl:text> - OpenLink Virtuoso Function Reference</xsl:text>
        </TITLE>
        <LINK rel="stylesheet" type="text/css" href="refentry.css" />
      </HEAD>
      <BODY>
        <xsl:if test="$enable_decorations = '1'">
          <DIV class="topdecoration"><IMG SRC="{$topgradienturl}" ALT="[decorative graphic]" /><IMG CLASS="rightalign" SRC="{$toplogourl}" ALT="[OpenLink Software]" /></DIV>
        </xsl:if>
        <A><xsl:attribute name="NAME"><xsl:value-of select="@id"/></xsl:attribute></A>
        <H1 CLASS="refentrytitle"><xsl:value-of select="refmeta/refentrytitle"/></H1>
        <P CLASS="refpurpose"><xsl:apply-templates select="refnamediv/refpurpose"/></P>
        <xsl:apply-templates select="refsynopsisdiv" />
        <xsl:apply-templates select="refsect1[@id='desc']"/>
        <xsl:apply-templates select="refsect1[@id='params']"/>
        <xsl:apply-templates select="refsect1[@id='ret']"/>
        <xsl:apply-templates select="refsect1[@id='errors']"/>
        <xsl:apply-templates select="refsect1[not(@id) or @id != 'params' and @id != 'ret' and @id != 'errors' and @id != 'desc' and @id != 'examples' and @id != 'seealso']"/>
        <xsl:apply-templates select="refsect1[@id='examples']"/>
        <xsl:apply-templates select="refsect1[@id='seealso']"/>
        <P CLASS="copyrightfooter">OpenLink Virtuoso eBusiness Integration Server (c) 2000, 2001 <A HREF="http://www.openlinksw.com">OpenLink Software</A></P>
      </BODY>
    </HTML>
  </xsl:when>
  <xsl:otherwise>
    <DIV CLASS="refentry">
      <A><xsl:attribute name="NAME"><xsl:value-of select="@id"/></xsl:attribute></A>
      <xsl:choose>
        <xsl:when test="$renditionmode='single_page'">
          <H1 CLASS="refentrytitle">
            <xsl:value-of select="refmeta/refentrytitle"/>
	  </H1>
        </xsl:when>
        <xsl:otherwise>
          <H2 CLASS="refentrytitle">
	    <xsl:value-of select="refmeta/refentrytitle"/>
	  </H2>
        </xsl:otherwise>
      </xsl:choose>
      <P CLASS="refpurpose"><xsl:apply-templates select="refnamediv/refpurpose"/></P>
      <xsl:apply-templates select="refsynopsisdiv" />
      <xsl:apply-templates select="refsect1[@id='desc']"/>
      <xsl:apply-templates select="refsect1[@id='params']"/>
      <xsl:apply-templates select="refsect1[@id='ret']"/>
      <xsl:apply-templates select="refsect1[@id='errors']"/>
      <xsl:apply-templates select="refsect1[not(@id) or @id != 'params' and @id != 'ret' and @id != 'errors' and @id != 'desc' and @id != 'examples' and @id != 'seealso']"/>
      <xsl:apply-templates select="refsect1[@id='examples']"/>
      <xsl:apply-templates select="refsect1[@id='seealso']"/>
    </DIV>
  </xsl:otherwise>
</xsl:choose>
</xsl:template>
</xsl:stylesheet>

