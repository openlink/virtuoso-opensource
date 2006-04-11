<!-- $id$ -->
<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

<xsl:output method="html"/>

<!-- parameters -->
<xsl:param name="rendition_mode"/>
<xsl:param name="enable_decorations" select="0"/>

<!-- configurable paths -->

<xsl:variable name="doc_base">/DAV/docsrc/</xsl:variable>
<xsl:variable name="fn_base"><xsl:value-of select="$doc_base"/>funcref/</xsl:variable>
<xsl:variable name="images_base">/DAV/images/</xsl:variable>


<xsl:variable name="topgradient_url"><xsl:value-of select="{concat ($images_base, 'ref_topgradient.jpg')}"/></xsl:variable>
<xsl:variable name="toplogo_url"><xsl:value-of select="{concat ($images_base, 'ref_2k_logo.jpg')}"/></xsl:variable>

<xsl:template match="optional">
  <SPAN CLASS="paramdef_optional">
    <xsl:text>[</xsl:text>
      <xsl:apply-templates />
    <xsl:text>]</xsl:text>
  </SPAN>
</xsl:template>

<xsl:template match="paramdef">
  <SPAN CLASS="paramdef">
    <xsl:apply-templates/>
    <xsl:if test="following-sibling::paramdef">
      <xsl:text>, </xsl:text>
    </xsl:if>
  </SPAN>
</xsl:template>

<xsl:template match="funcprototype">
  <xsl:value-of select="funcdef/function" />
  <xsl:text> (</xsl:text>
    <xsl:apply-templates select="paramdef"/>
  <xsl:text>);</xsl:text>
</xsl:template>

<xsl:template match="funcsynopsis">
  <P CLASS="funcsynopsis"><A><xsl:attribute name="NAME"><xsl:value-of select="./@id" /></xsl:attribute></A>
    <CODE class="funcdef">
        <xsl:apply-templates />
    </CODE>
  </P>
</xsl:template>



<xsl:template match="para/function">
  <CODE CLASS="function"><xsl:apply-templates/></CODE>
</xsl:template>

<xsl:template match="para/parameter">
  <CODE class="parameter"><xsl:apply-templates/></CODE>
</xsl:template>

<xsl:template match="para/type">
  <CODE class="type"><xsl:apply-templates/></CODE>
</xsl:template>

<xsl:template match="para/link">
  <xsl:choose>
    <xsl:when test="substring(@linkend,1,3)='fn_'">
      <!-- This points to an entry in function reference -->
      <A HREF="{concat ($fn_base, substring (@linkend, 4), '.xml')}">
        <xsl:apply-templates/>
      </A>
    </xsl:when>
    <xsl:when test="substring(@linkend,1,3)='dc_'">
      <!-- base documentation url (TODO: handle appending the anchor) -->  
      
        <A HREF="{concat ($doc_base, substring (@linkend, 4), '.xml')}">
	
          <xsl:apply-templates/>
	</A>
    </xsl:when>
  </xsl:choose>
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
  <CODE class="errorcode">
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
  <TR class="theadrow">
    <xsl:apply-templates/>
  </TR>
</xsl:template>

<xsl:template match="table/title">
    <H4 class="tabletitle"><xsl:apply-templates/></H4>
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
<xsl:template match="refsect1/title"><H2 CLASS="refsect1title"><xsl:apply-templates/></H2></xsl:template>
<xsl:template match="refsect2/title"><H3 CLASS="refsect2title"><xsl:apply-templates/></H3></xsl:template>
<xsl:template match="refsect3/title"><H4 CLASS="refsect3title"><xsl:apply-templates/></H4></xsl:template>
<xsl:template match="example/title"><H3 CLASS="refsect3title"><xsl:apply-templates/></H3></xsl:template>


<!-- Actually one template would do, but maybe someone wants to use CSS to make some xmas lights -->
<xsl:template match="refsect1[@id='params']"><DIV CLASS="ref1params"><xsl:apply-templates/></DIV></xsl:template>
<xsl:template match="refsect1[@id='ret']"><DIV CLASS="ref1ret"><xsl:apply-templates/></DIV></xsl:template>
<xsl:template match="refsect1[@id='errors']"><DIV CLASS="ref1errors"><xsl:apply-templates/></DIV></xsl:template>
<xsl:template match="refsect1[@id='desc']"><DIV CLASS="ref1desc"><xsl:apply-templates/></DIV></xsl:template>
<xsl:template match="refsect1[@id='examples']"><DIV CLASS="ref1examples"><xsl:apply-templates/></DIV></xsl:template>
<xsl:template match="refsect1[@id='seealso']"><DIV CLASS="ref1seealso"><xsl:apply-templates/></DIV></xsl:template>

<!-- A fallback template... see above -->
<xsl:template match="refsect1[not(@id) or @id != 'params' and @id != 'ret' and @id != 'errors' and @id != 'desc' and @id != 'examples' and @id != 'seealso']"><DIV CLASS="ref1other"><xsl:apply-templates/></DIV></xsl:template>

<!-- Are these some kind of fallback rules?
<xsl:template match="refsect2"><DIV CLASS="refsect2"><xsl:apply-templates/></DIV></xsl:template>
<xsl:template match="refsect3"><xsl:apply-templates/></xsl:template>
-->

<xsl:template match="refentry">
<HTML>
<HEAD><TITLE><xsl:value-of select="refmeta/refentrytitle"/><xsl:text> - OpenLink Virtuoso Function Reference</xsl:text></TITLE>
<LINK rel="stylesheet" type="text/css" href="refentry.css" />
</HEAD>
<BODY>
<xsl:if test="enable_decorations = '1'">
<DIV class="topdecoration"><IMG SRC="{$topgradient_url}" ALT="[decorative graphic]" /><IMG CLASS="rightalign" SRC="{$toplogo_url}" ALT="[OpenLink Software Logo]" /></DIV>
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
<P CLASS="copyrightfooter">OpenLink Virtuoso eBusiness Integration Server &copy; 2000, 2001 <A HREF="http://www.openlinksw.com">OpenLink Software</A></P>
</BODY>
</HTML>
</xsl:template>
</xsl:stylesheet>
