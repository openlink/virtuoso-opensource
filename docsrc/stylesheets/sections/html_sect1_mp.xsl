<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   version="1.0" xmlns:xhtml="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml"
  doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"
  doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
  indent="yes"
  encoding="utf-8"
  omit-xml-declaration="yes"
  media-type="text/xml"/>

<!-- ==================================================================== -->

	<xsl:param name="imgroot">../images/</xsl:param>
	<xsl:param name="chap">index</xsl:param>
	<xsl:param name="sect1"></xsl:param>
	<xsl:param name="function">NULL</xsl:param>
	<xsl:param name="refentry">NULL</xsl:param>
	<xsl:param name="pdflocation">../pdf/<xsl:value-of select="/book/@id" />.pdf</xsl:param>
	<xsl:param name="rss">no</xsl:param>
	<xsl:param name="mode">static</xsl:param>

<!-- ==================================================================== -->

<xsl:include href="html_functions.xsl" />
<xsl:include href="html_sect1_common.xsl"/>
<xsl:include href="html_sect1_tocs.xsl"/>

<xsl:template match="/book">
<html>
<head profile=" http://internetalchemy.org/2003/02/profile">
  <!--  script type="text/javascript" src="/doc/util.js"></script -->
  <xsl:variable name="chapnode" select="/book/chapter[./sect1/@id=$chap]/@id|/book/chapter[@id=$chap]/@id" />
  <xsl:variable name="prevnode" select="/book/chapter/sect1[@id=$chap]/preceding-sibling::sect1[1]|/book/chapter[@id=$chap]/preceding-sibling::chapter[1]" />
  <xsl:variable name="prevnodetitle" select="$prevnode/title"/>
  <xsl:variable name="nextnode" select="/book/chapter/sect1[@id=$chap]/following-sibling::*[1]|/book/chapter[@id=$chap]/sect1[1]" />
  <xsl:variable name="nextnodetitle" select="$nextnode/title"/>
  <xsl:variable name="prevchap" select="/book/chapter[@id=$chap]/preceding-sibling::chapter[1]" />
  <xsl:variable name="prevchaptitle" select="$prevchap/title"/>
  <xsl:variable name="nextchap" select="/book/chapter[@id=$chap]/following-sibling::chapter[1]" />
  <xsl:variable name="nextchaptitle" select="$nextchap/title"/>

  <xsl:call-template name="rssfeedlink" />
  <xsl:if test="$mode='server'">
    <meta name="geo.position" content="42.485836;-71.214287" />
    <meta name="geo.country" content="us" />
    <meta name="ICBM" content="42.485836,-71.214287" />
  </xsl:if>    
    <link rel="foaf" type="application/rdf+xml" title="FOAF"
      href="http://www.openlinksw.com/dataspace/uda/about.rdf" />
    
    <link rel="schema.dc" href="http://purl.org/dc/elements/1.1/" />
        
    <xsl:for-each select="/book/chapter[@id = $chap]/chapterinfo/keywordset/keyword">
      <meta name="dc.subject" content="{.}" />
    </xsl:for-each>
    <xsl:for-each select="/book/chapter[sect1/@id = $chap]/chapterinfo/keywordset/keyword">
      <meta name="dc.subject" content="{.}" />
    </xsl:for-each>
    <xsl:for-each select="/book/chapter/sect1[@id = $chap]/sect1info/keywordset/keyword">
      <meta name="dc.subject" content="{.}" />
    </xsl:for-each>
        
    <meta name="dc.title">
      <xsl:attribute name="content">
        <xsl:call-template name="titler2" />
      </xsl:attribute>
    </meta>
    <meta name="dc.subject">
      <xsl:attribute name="content">
        <xsl:call-template name="titler2" />
      </xsl:attribute>
    </meta>
    <meta name="dc.creator">
      <xsl:attribute name="content">
        <xsl:apply-templates select="/book/bookinfo/authorgroup/author" />
      </xsl:attribute>
    </meta>
    <meta name="dc.copyright">
      <xsl:attribute name="content">
        <xsl:value-of select="/book/bookinfo/copyright/holder" />
        <xsl:text>, </xsl:text>
        <xsl:value-of select="/book/bookinfo/copyright/year" />
      </xsl:attribute>
    </meta>


  <link rel="top" href="index.html" title="{/book/title}" />
  <link rel="search" href="/doc/adv_search.vspx" title="Search {/book/title}" />
  <link rel="parent" href="{$chapnode}.html" title="Chapter Contents" />

<xsl:choose>
  <xsl:when test="$chap='preface'">
    <link rel="prev" href="contents.html" title="Contents" /></xsl:when>
  <xsl:when test="$chap='contents' or $chap='index'">
    <link rel="prev" href="index.html" title="Home" /></xsl:when>
  <xsl:when test="/book/chapter[position()=1][@id = $chap]">
    <link rel="prev" href="preface.html" title="Preface" /></xsl:when>

  <xsl:when test="/book/chapter/sect1[1][@id = $chap]">
    <link rel="prev" href="{../@id}.html" title="{../title}" /></xsl:when>

  <xsl:when test="$prevnode">
    <link rel="prev" href="{$prevnode/@id}.html" title="{$prevnodetitle}" /></xsl:when>
  <xsl:when test="not($prevnode) and $chapnode='functions'">
    <link rel="prev" href="functions.html#{$prevchap/@id}" title="{$prevchaptitle}" /></xsl:when>
  <xsl:when test="not($prevnode) and $prevchap">
    <link rel="prev" href="{$prevchap/@id}.html" title="{$prevchaptitle}" /></xsl:when>
  <xsl:otherwise><link rel="prev" href="contents.html" title="Contents" /></xsl:otherwise>
</xsl:choose>

<xsl:choose>
  <xsl:when test="$chap='index'">
    <link rel="next" href="contents.html" title="Contents" /></xsl:when>
  <xsl:when test="$chap='contents'">
    <link rel="next" href="preface.html" title="Preface" /></xsl:when>
  <xsl:when test="$chap='preface'">
    <link rel="next" href="{/book/chapter[position()=1]/@id}.html" title="{/book/chapter[position()=1]/title}" /></xsl:when>

  <xsl:when test="$nextnode">
    <link rel="next" href="{$nextnode/@id}.html" title="{$nextnodetitle}" /></xsl:when>
  <xsl:when test="not($nextnode) and $chapnode='functions'">
    <link rel="next" href="functions.html#{$nextchap/@id}.html" title="{$nextchaptitle}" /></xsl:when>
  <xsl:when test="not($nextnode) and $nextchap">
    <link rel="next" href="{$nextchap/@id}.html" title="{$nextchaptitle}" /></xsl:when>
  <xsl:otherwise><link rel="next" href="contents.html" title="Contents" /></xsl:otherwise>
</xsl:choose>

  <link rel="shortcut icon" href="{$imgroot}misc/favicon.ico" type="image/x-icon" />
  <link rel="stylesheet" type="text/css" href="doc.css"/>
  <link rel="stylesheet" type="text/css" href="/doc/translation.css" />
  <title><xsl:call-template name="titler2" /></title>
  <meta http-equiv="Content-Type" content="text/xhtml; charset=UTF-8" />
  <meta name="author"><xsl:attribute name="content"><xsl:apply-templates select="/book/bookinfo/authorgroup/author" /></xsl:attribute></meta>
  <meta name="copyright"><xsl:attribute name="content"><xsl:value-of select="/book/bookinfo/copyright/holder" /><xsl:text>, </xsl:text><xsl:value-of select="/book/bookinfo/copyright/year" /></xsl:attribute></meta>
  <meta name="keywords">
    <xsl:attribute name="content">
      <xsl:for-each select="/book/chapter[@id = $chap]/chapterinfo/keywordset/keyword">
        <xsl:value-of select="." /><xsl:text>; </xsl:text>
      </xsl:for-each>
      <xsl:for-each select="/book/chapter[sect1/@id = $chap]/chapterinfo/keywordset/keyword">
        <xsl:value-of select="." /><xsl:text>; </xsl:text>
      </xsl:for-each>
      <xsl:for-each select="/book/chapter/sect1[@id = $chap]/sect1info/keywordset/keyword">
        <xsl:value-of select="." /><xsl:text>; </xsl:text>
      </xsl:for-each>
    </xsl:attribute>
  </meta>
  <meta name="GENERATOR" content="OpenLink XSLT Team" />
</head>
<body>
 <xsl:choose>
  <xsl:when test="$sect1 = 'vspx' and $refentry != 'NULL'"><xsl:apply-templates select="/book/chapter/sect1[@id='vspx']//refentry[@id = $refentry]" /></xsl:when>
  <xsl:when test="$chap = 'preface'"><xsl:apply-templates select="/book/preface"/></xsl:when>
  <xsl:when test="$chap = 'index'"><xsl:call-template name="homepage"/></xsl:when>
  <xsl:when test="$chap = 'contents'"><xsl:call-template name="contentspage"/></xsl:when>
  <xsl:when test="$chap = 'functions' and $function != 'NULL'"><xsl:apply-templates select="/book/chapter[@id='functions']/refentry[@id = $function]" /></xsl:when>
  <xsl:when test="$chap = 'functionidx'"><xsl:call-template name="functionidx"/></xsl:when>
  <xsl:otherwise>
    <xsl:apply-templates select="/book/chapter[@id = $chap]|/book/chapter/sect1[@id = $chap]"/>
  </xsl:otherwise>
 </xsl:choose>
</body></html>
</xsl:template>

<!-- #################################################################### -->
<!-- Normal Pages                                                         -->
<!-- ==================================================================== -->
<xsl:template match="/book/preface|chapter|chapter/sect1">
<!-- can we check for node set here in case broker XML? -->
 <xsl:call-template name="header" />
 <xsl:call-template name="navbartop" />
 <xsl:call-template name="current-toc" />
 <xsl:call-template name="text" />
 <xsl:call-template name="translation" />
 <xsl:call-template name="footer" />
</xsl:template>

<!-- #################################################################### -->
<!-- The INDEX/home Page                                                       -->
<!-- ==================================================================== -->
<xsl:template name="homepage">
 <xsl:call-template name="header" />
 <xsl:call-template name="navbartop" />
 <xsl:call-template name="current-toc" />
 <div id="text">
  <div class="homepage"><img src="{$imgroot}misc/splash.jpg" alt="{/book/title}"/></div>
  <p>
    <xsl:text>Also available as PDF:</xsl:text>
    <a href="http://www.adobe.com/" target="_top">(PDF Reader)</a>
  </p>
  <xsl:if test="$mode='static'">
  <p>
    <a href="{$pdflocation}" target="_top">
  <img src="{$imgroot}misc/acopdflogo.gif" width="30" height="30" border="0" alt="PDF Version" />
      <xsl:text>Local Offline</xsl:text>
    </a>
  </p>
  </xsl:if>
  <p>
    <a href="http://docs.openlinksw.com/pdf/virtdocs.pdf" target="_top">
      <img src="{$imgroot}misc/acopdflogo.gif" width="30" height="30" border="0" alt="PDF Version" />
      <xsl:text>Online</xsl:text>
    </a>
  </p>
 </div>
 <xsl:call-template name="translation" />
 <xsl:call-template name="footer" />
</xsl:template>

<!-- #################################################################### -->
<!-- The Function INDEX Page                                              -->
<!-- ==================================================================== -->
<xsl:template name="functionidx">
 <xsl:call-template name="header" />
 <xsl:call-template name="navbartop" />
 <xsl:call-template name="current-toc" />
 <div id="text">
 <h2><xsl:call-template name="titler" /></h2>
 <div class="data">
  <table width="100%">
 <xsl:for-each select="/book/chapter[./@id='functions']//refentry/refnamediv/refname">
  <xsl:sort select="translate(., 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')" data-type="text"/>
  <xsl:variable name="refname"><xsl:value-of select="string(.)" /></xsl:variable>
  <xsl:variable name="id"><xsl:value-of select="../../@id" /></xsl:variable>
  <xsl:variable name="raw_fsyns" select="../../refsynopsisdiv/funcsynopsis" />
  <xsl:variable name="raw_fsyn" select="$raw_fsyns[.//function[string(.)=$refname]]" />
  <xsl:variable name="fsyn">
    <xsl:choose>
      <xsl:when test="$raw_fsyn">
	<xsl:apply-templates select="$raw_fsyn"/>
      </xsl:when>
      <xsl:when test="starts-with($refname,'uddi_')">
       <a href="{$id}.html"><span class="funcdef"><xsl:value-of select="$refname" /></span></a>
	<!-- xsl:apply-templates select="../../refsect1[starts-with(@id, 'syntax_uddi_')]/screen"/ -->
      </xsl:when>
      <xsl:otherwise>
	<xsl:message terminate="yes">refentry <xsl:value-of select="$id" /> contains refname <xsl:value-of select="$refname" /> without appropriate function in funcsynopsis.</xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <tr><td>
  <xsl:call-template name="put_href_to_fsyn">
     <xsl:with-param name="refname" select="string()" />
     <xsl:with-param name="fsyn" select="$fsyn" />
     <xsl:with-param name="id" select="$id" />
  </xsl:call-template></td>
  <td><xsl:value-of select="../refpurpose" /></td></tr>
 </xsl:for-each>
 </table>
 </div>
 </div>
 <xsl:call-template name="translation" />
 <xsl:call-template name="footer" />
</xsl:template>

<xsl:template name="put_href_to_fsyn">
  <xsl:param name="refname" />
  <xsl:param name="fsyn" />
  <xsl:param name="id" />
  <xsl:variable name="stub">
    <a href="{$id}.html"><xsl:value-of select="string($fsyn//SPAN[@CLASS='function'])" /></a>
  </xsl:variable>
  <xsl:apply-templates select="$fsyn" mode="put_href_to_fsyn_mode">
    <xsl:with-param name="stub" select="$stub" />
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="SPAN[@CLASS='function']" mode="put_href_to_fsyn_mode">
  <xsl:param name="stub" />
  <xsl:copy-of select="$stub"/>
</xsl:template>

<xsl:template match="@*" mode="put_href_to_fsyn_mode">
  <xsl:copy />
</xsl:template>

<xsl:template match="node()" mode="put_href_to_fsyn_mode">
  <xsl:param name="stub" />
  <xsl:copy>
  <xsl:apply-templates select="@*|node()" mode="put_href_to_fsyn_mode">
    <xsl:with-param name="stub" select="$stub" />
  </xsl:apply-templates>
  </xsl:copy>
</xsl:template>


<!-- #################################################################### -->
<!-- The CONTENTS page                                                    -->
<!-- ==================================================================== -->
<xsl:template name="contentspage">
 <xsl:call-template name="header" />
 <xsl:call-template name="navbartop" />
 <xsl:call-template name="current-toc" />
 <div id="text">
  <h2><xsl:call-template name="titler" /></h2>
  <div class="maintoc">
  <xsl:for-each select="/book/chapter">
   <div><a class="chapter" href="{@id}.html"><xsl:call-template name="pos" /> <xsl:value-of select="title" /></a></div>
    <xsl:for-each select="sect1">
     <div><a class="sect1" href="{@id}.html"><xsl:call-template name="pos" /> <xsl:value-of select="title" /></a></div>
      <xsl:for-each select="sect2">
       <div><a class="sect2" href="{../@id}.html#{@id}"><xsl:call-template name="pos" /> <xsl:value-of select="title" /></a></div>
      </xsl:for-each>
    </xsl:for-each>
  </xsl:for-each>
  </div>
 </div>
 <xsl:call-template name="translation" />
 <xsl:call-template name="footer" />
</xsl:template>

<!-- #################################################################### -->
<!-- Main Part of Normal Pages                                            -->
<!-- ==================================================================== -->
<xsl:template name="text">
 <div id="text">
  <xsl:choose>
   <xsl:when test="name(.) = 'chapter'">
    <div class="abstract">
     <h2>Abstract</h2>
     <xsl:apply-templates select="abstract/*" />
    </div>
    <xsl:call-template name="minitoc" />
    <br />
    <xsl:apply-templates select="*[name() != 'sect1' and name() != 'refentry']" />
   </xsl:when>
   <xsl:otherwise><xsl:apply-templates /></xsl:otherwise>
  </xsl:choose>
 <xsl:call-template name="navbarbottom" />
 </div>
</xsl:template>

<!-- #################################################################### -->
<!-- Refentry Pages                                                       -->
<!-- ==================================================================== -->
<xsl:template match="(/book/chapter[@id='functions']/refentry)|(/book/chapter/sect1[@id='vspx']//refentry[@id=$refentry])" priority="100">
 <xsl:call-template name="header" />

  <xsl:variable name="cat" select="refmeta/refmiscinfo"/>
  <xsl:variable name="chapnode">functions</xsl:variable>
  <xsl:variable name="prevnode" select="preceding-sibling::refentry[refmeta/refmiscinfo = $cat][1]" />
  <xsl:variable name="nextnode" select="following-sibling::refentry[refmeta/refmiscinfo = $cat][1]" />
  <xsl:variable name="prevchap" select="/book/chapter[@id = 'functions']/docinfo/keywordset/keyword[@id = $cat]/preceding-sibling::keyword[1]" />
  <xsl:variable name="nextchap" select="/book/chapter[@id = 'functions']/docinfo/keywordset/keyword[@id = $cat]/following-sibling::keyword[1]" />

  <xsl:call-template name="navbartop">
   <xsl:with-param name="chapnode" select="$chapnode" />
   <xsl:with-param name="prevnode" select="$prevnode" />
   <xsl:with-param name="nextnode" select="$nextnode" />
   <xsl:with-param name="prevchap" select="$prevchap" />
   <xsl:with-param name="nextchap" select="$nextchap" />
   <xsl:with-param name="nextchaptitle" select="$nextchap"/>
   <xsl:with-param name="prevchaptitle" select="$prevchap"/>
   <xsl:with-param name="nextnodetitle" select="$nextnode/refmeta/refentrytitle"/>
   <xsl:with-param name="prevnodetitle" select="$prevnode/refmeta/refentrytitle"/>
  </xsl:call-template>

 <xsl:call-template name="current-toc">
  <xsl:with-param name="fn" select="@id"/>
  <xsl:with-param name="cat" select="$cat"/>
 </xsl:call-template>
 <div id="text">

  <h2><xsl:value-of select="refmeta/refentrytitle" /></h2>
  <div class="refpurpose"><xsl:apply-templates select="refnamediv/refpurpose"/></div>
  <xsl:for-each select="refsynopsisdiv/funcsynopsis/funcprototype">
   <xsl:sort select="funcdef/function" data-type="text"/>
   <div class="funcsynopsis"><xsl:apply-templates/></div>
  </xsl:for-each>
  <xsl:apply-templates />
 </div>
 <xsl:call-template name="translation" />
 <xsl:call-template name="footer" />
</xsl:template>

<xsl:template match="refentry">
  <xsl:variable name="raw_fsyn" select="refsynopsisdiv/funcsynopsis" />
  <xsl:variable name="fsyn">
    <xsl:apply-templates select="$raw_fsyn"/>
  </xsl:variable>
 <div class="funcsynopsis">
  <xsl:call-template name="put_href_to_fsyn">
     <xsl:with-param name="refname" select="string(refnamediv/refname)" />
     <xsl:with-param name="fsyn" select="$fsyn" />
     <xsl:with-param name="id" select="@id" />
  </xsl:call-template></div>
  <p><xsl:value-of select=".//refpurpose" /></p>
</xsl:template>


<!-- #################################################################### -->

<xsl:template name="header">
 <div id="header">
  <a name="{@id}" />
  <img src="{$imgroot}misc/logo.jpg" alt="" />
  <h1><xsl:call-template name="titler" /></h1>
 </div>
</xsl:template>

<xsl:template name="footer">
 <div id="footer"><div>
   <xsl:text>Copyright&#169; </xsl:text>
   <xsl:value-of select="/book/bookinfo/copyright/year"/>
   <xsl:text> </xsl:text>
   <xsl:value-of select="/book/bookinfo/copyright/holder"/>
   <xsl:text> All rights reserved.</xsl:text>
 </div>
 <div id="validation">
  <a href="http://validator.w3.org/check/referer">
   <img src="http://www.w3.org/Icons/valid-xhtml10"
     alt="Valid XHTML 1.0!" height="31" width="88" /></a>
  <a href="http://jigsaw.w3.org/css-validator/">
   <img src="http://jigsaw.w3.org/css-validator/images/vcss"
     alt="Valid CSS!" height="31" width="88" /></a>
 </div>
</div>
</xsl:template>

<xsl:template name="titler">
 <xsl:choose>
  <xsl:when test="$chap='preface'"><xsl:value-of select="/book/title"/><xsl:text> - Preface</xsl:text></xsl:when>
  <xsl:when test="$chap='contents'"><xsl:value-of select="/book/title"/><xsl:text> - Contents</xsl:text></xsl:when>
  <xsl:when test="$chap='functionidx'"><xsl:value-of select="/book/title"/><xsl:text> - Function Index</xsl:text></xsl:when>
  <xsl:when test="$chap='index' or count(id($chap)) = 0"><xsl:value-of select="/book/title"/></xsl:when>
  <xsl:otherwise>
   <xsl:for-each select="/book/chapter[@id = $chap or sect1/@id = $chap][1]">
    <xsl:call-template name="pos" />
    <xsl:value-of select="title"/>
   </xsl:for-each>
  </xsl:otherwise>
 </xsl:choose>
  <xsl:if test="local-name(.) = 'refentry'"><xsl:text> - </xsl:text><xsl:value-of select="refmeta/refentrytitle" /></xsl:if>
</xsl:template>

<xsl:template name="titler2">
 <xsl:choose>
  <xsl:when test="$chap='preface'"><xsl:value-of select="/book/title"/><xsl:text> - Preface</xsl:text></xsl:when>
  <xsl:when test="$chap='contents'"><xsl:value-of select="/book/title"/><xsl:text> - Contents</xsl:text></xsl:when>
  <xsl:when test="$chap='functionidx'"><xsl:value-of select="/book/title"/><xsl:text> - Function Index</xsl:text></xsl:when>
  <xsl:when test="$chap='index' or count(id($chap)) = 0"><xsl:value-of select="/book/title"/></xsl:when>
  <xsl:otherwise>
   <xsl:for-each select="/book/chapter[@id = $chap or sect1/@id = $chap][1]">
    <xsl:call-template name="pos" />
    <xsl:value-of select="title"/>
   </xsl:for-each>
  </xsl:otherwise>
 </xsl:choose>
</xsl:template>

<xsl:template name="blankpad">
  <div style="clear: both"><xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text></div>
</xsl:template>

<xsl:template name="rssfeedlink">
  <xsl:if test="$rss='yes'">
    <xsl:if test="normalize-space(//self::*[@id = $chap]/ancestor-or-self::chapter)">
      <link rel="alternate" type="application/rss+xml" title="RSS" 
      		href="{//self::*[@id = $chap]/ancestor-or-self::chapter/@id}.rss"></link>
      <link rel="alternate" type="application/atom+xml" title="ATOM" 
      		href="{//self::*[@id = $chap]/ancestor-or-self::chapter/@id}.xml"></link>
      <link rel="alternate" type="application/rdf+xml" title="RDF" 
      		href="{//self::*[@id = $chap]/ancestor-or-self::chapter/@id}.rdf"></link>
    </xsl:if>
    <link rel="alternate" type="application/opml+xml" title="OPML" href="{/book/@id}.opml"></link>
    <link rel="meta" type="application/rdf+xml" title="SIOC" href="{/book/@id}.sioc.rdf" />
  </xsl:if>
</xsl:template>

<xsl:template name="translation">
<xsl:if test="$mode='server'">
 <div id="machinetranslation">
<h3><span>Other Languages</span></h3>
<ul>
  <li>
    <a href="/doc/translate.vsp?langpair=en%7Cfr&hl=fr" title="Fran&#231;ais - Traduction par Google">
                <img src="/images/misc/flag-france.gif" alt="Fran&#231;ais" />
                <span>Fran&#231;ais</span></a>
  </li>
  <li>
    <a href="/doc/translate.vsp?langpair=en%7Ces&hl=es" title="Espa&#241;ol - Traducci&#243;n de Google">
                <img src="/images/misc/flag-spain.gif" alt="Espa&#241;ol" />
                <span>Espa&#241;ol</span></a>
  </li>
  <li>
    <a href="/doc/translate.vsp?langpair=en%7Cde&hl=de" title="Deutsch - &#220;bersetzung durch Google">
                <img src="/images/misc/flag-germany.gif" alt="Deutsche" />
                <span>Deutsch</span></a>
  </li>
  <li>
    <a href="/doc/translate.vsp?langpair=en%7Cit&hl=it" title="Italiano - Traduzione da Google">
                <img src="/images/misc/flag-italy.gif" alt="Italiano" />
                <span>Italiano</span></a>
  </li>
  <li>
    <a href="/doc/translate.vsp?langpair=en%7Cpt&hl=pt" title="Portugu&#234;s - Tradu&#231;&#227;o por Google">
                <img src="/images/misc/flag-portugal.gif" alt="Portugu&#234;s" />
                <span>Portugu&#234;s</span></a>
  </li>
  <li>
    <a href="/doc/translate.vsp?langpair=en%7Cja&hl=ja" title="Japanese - Translation by Google">
                <img src="/images/misc/flag-japan.gif" alt="Japanese" />
                <span>Japanese</span></a>
  </li>
  <li>
    <a href="/doc/translate.vsp?langpair=en%7Czh&hl=zh" title="Simplified Chinese - Translation by Google">
                <img src="/images/misc/flag-china.gif" alt="Simplified Chinese" />
                <span>Chinese</span></a>
  </li>

</ul>
 </div>
  </xsl:if>
</xsl:template>



</xsl:stylesheet>
