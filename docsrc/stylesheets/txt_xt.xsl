<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

<xsl:output method="text"/>

<!-- ==================================================================== -->

			<!-- Variables -->
	<xsl:variable name="imgP">../images/</xsl:variable>
			<!-- Variables -->

<!-- ==================================================================== -->
<xsl:variable name="funcsynopsis.style">kr</xsl:variable>

<!-- ==================================================================== -->
<xsl:variable name="funcsynopsis.decoration" select="1"/>


<!-- ==================================================================== -->

<xsl:template match="funcsynopsis">
<xsl:apply-templates/>
</xsl:template>

<xsl:template match="funcdef">
<xsl:apply-templates/>
</xsl:template>

<xsl:template match="paramdef/optional/parameter">
<xsl:apply-templates/>
  <xsl:if test="following-sibling::parameter">
    <xsl:text>, </xsl:text>
  </xsl:if>
</xsl:template>

<xsl:template match="paramdef/parameter">
  <!-- <xsl:choose>
    <xsl:when test="$funcsynopsis.decoration != 0">
      <var class="pdparam"> 
        <xsl:apply-templates/>
      </var>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates/>
    </xsl:otherwise>
  </xsl:choose>-->
      <xsl:apply-templates/>
  <xsl:if test="following-sibling::parameter">
    <xsl:text>, </xsl:text>
  </xsl:if>
</xsl:template>

<xsl:template match="paramdef">
  <xsl:variable name="paramnum">
    <xsl:number count="paramdef" format="1"/>
  </xsl:variable>
  <xsl:if test="$paramnum=1">(</xsl:if>
  <xsl:choose>
    <xsl:when test="$funcsynopsis.style='ansi'">
      <xsl:apply-templates/>
    </xsl:when>
    <xsl:when test="./optional">
[<xsl:apply-templates/>]
    </xsl:when>
    <xsl:otherwise>
<xsl:apply-templates/>
    </xsl:otherwise>
  </xsl:choose>
  <xsl:choose>
    <xsl:when test="following-sibling::paramdef">
      <xsl:text>, </xsl:text>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>);</xsl:text>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>


<xsl:template match="paramdef" mode="kr-funcsynopsis-mode">
  <br/>
  <xsl:apply-templates/>
  <xsl:text>;</xsl:text>
</xsl:template>

<xsl:template match="funcparams">
  <xsl:text>(</xsl:text>
  <xsl:apply-templates/>
  <xsl:text>)
</xsl:text>
</xsl:template>



<xsl:template match="funcdef/function">
  <xsl:choose>
    <xsl:when test="$funcsynopsis.decoration != 0">
      <xsl:apply-templates/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- ================================================== -->
<!-- ================================================== -->
<!-- ================================================== -->
<!-- ================================================== -->

<xsl:template match="/">

<!-- Top of Page -->
<xsl:value-of select="/book/title"/>
<!-- Normal Doc Content -->

<!-- Doc Contents Content -->
      <xsl:text>

Table of Contents

</xsl:text>

    <xsl:for-each select="/book/chapter">
    <xsl:value-of select="./@label"/> - <xsl:value-of select="./title"/><xsl:text>
</xsl:text>

   	<xsl:for-each select="./sect1">

      <xsl:text>    </xsl:text><xsl:value-of select="./title"/><xsl:text>
</xsl:text>
         		<xsl:for-each select="./sect2">
				<xsl:text>        </xsl:text><xsl:value-of select="./title"/><xsl:text>
</xsl:text>
         		</xsl:for-each><xsl:text>
</xsl:text>
		</xsl:for-each><xsl:text>
</xsl:text>
     </xsl:for-each><xsl:text>
</xsl:text>

<!-- Doc Contents Content End -->

  <xsl:apply-templates select="/book/chapter"/> 

<!-- Apendix sections -->

<A NAME="functionindex" />

<xsl:text>
=================================================================
Appendix A
-----------------------------------------------------------------------------------

Function Index

</xsl:text>
<xsl:for-each select="/book/*//funcsynopsis" order-by="funcdef/function">
<xsl:value-of select="./funcdef/function" />
<xsl:text>
</xsl:text>
</xsl:for-each>

<!-- Normal Doc Content -->
<xsl:text>
==================================================================================
Copyright </xsl:text><xsl:value-of select="/book/bookinfo/copyright/year"/><xsl:text>, </xsl:text><xsl:value-of select="/book/bookinfo/copyright/holder"/>


<!-- Bottom of Page -->
</xsl:template>

<!-- ====================================== -->
<xsl:template match="book">
<xsl:apply-templates select="chapter"/>
</xsl:template>

<xsl:template match="chapter">
<xsl:text>

===============================================================================
===============================================================================
Chapter: </xsl:text><xsl:value-of select="./@label" />
<xsl:text>
------------------------------------
</xsl:text>

<xsl:value-of select="./title" />
<xsl:text>
-------------------------------------
</xsl:text>

<xsl:apply-templates select="./abstract" />

<!--  ########## mini Contents bit ######### -->
<xsl:text>
Table of Contents
</xsl:text>


   	<xsl:for-each select="./sect1">

      <xsl:text>...</xsl:text><xsl:value-of select="./title"/><xsl:text>
</xsl:text>
         		<xsl:for-each select="./sect2">
				<xsl:text>...---</xsl:text><xsl:value-of select="./title"/><xsl:text>
</xsl:text>
         		</xsl:for-each><xsl:text>
</xsl:text>
		</xsl:for-each><xsl:text>

                              =            =               =                          

</xsl:text>

<!--  ########## ########### ######### -->

  <xsl:apply-templates select="sect1"/>
</xsl:template>

<xsl:template match="abstract">
<xsl:text>

Abstract:

</xsl:text>
   <xsl:apply-templates />
<xsl:text>

</xsl:text>
</xsl:template>

<xsl:template match="sect1">
   <xsl:apply-templates />
</xsl:template>

<xsl:template match="sect1/title">
<xsl:text>
======================================
</xsl:text>
<xsl:apply-templates />
<xsl:text>
------------------------------------

</xsl:text>
</xsl:template>

<xsl:template match="sect2">
<xsl:text>


</xsl:text>
   <xsl:apply-templates />
<xsl:text>

</xsl:text>
</xsl:template>

<xsl:template match="sect2/title">
<xsl:apply-templates />
</xsl:template>

<xsl:template match="sect3">
<xsl:text>


</xsl:text>
   <xsl:apply-templates />
<xsl:text>
</xsl:text>
</xsl:template>

<xsl:template match="sect3/title">
<xsl:apply-templates />
<xsl:text>

</xsl:text>
</xsl:template>

<xsl:template match="para">
  <xsl:apply-templates />
<xsl:text>
</xsl:text>
</xsl:template>

<xsl:template match="example/title">
<P CLASS="exampletitle"><xsl:apply-templates /></P>
</xsl:template>

<xsl:template match="example">
<TABLE CLASS="example">
<TR><TD><xsl:apply-templates /></TD></TR>
</TABLE>
</xsl:template>

<xsl:template match="note">
<xsl:text>
#############################
</xsl:text>
<xsl:value-of select="./title" />
<xsl:text>
----------------------------------------------
</xsl:text>
    <xsl:for-each select="para" >
      <xsl:value-of select="."/>
    </xsl:for-each>
    <xsl:apply-templates select="itemizedlist"/>
<xsl:text>
################################

</xsl:text>
</xsl:template>

<xsl:template match="tip">
<xsl:text>
############################
</xsl:text>
<xsl:value-of select="./title" />
<xsl:text>-----------------------------</xsl:text>
<xsl:for-each select="para" >
  <xsl:value-of select="."/>
</xsl:for-each>
<xsl:text>
################################

</xsl:text>
</xsl:template>


<xsl:template match="itemizedlist">
<xsl:apply-templates select="listitem"/>
</xsl:template>

<xsl:template match="itemizedlist/listitem">
  <TABLE CLASS="listitem"><TR><TD VALIGN="TOP">
    <xsl:if test="../@mark[.='bullet']">
      <IMG ALT="o"><xsl:attribute name="SRC"><xsl:value-of select="$imgP"/>misc/virtbullet.gif</xsl:attribute></IMG>
    </xsl:if>
    <xsl:if test="../@mark[.='dash']">
      <IMG ALT="-"><xsl:attribute name="SRC"><xsl:value-of select="$imgP"/>misc/Bullet1.gif</xsl:attribute></IMG>
    </xsl:if>
	</TD><TD>
  <xsl:apply-templates select="para"/>
  <xsl:apply-templates select="formalpara"/>
  <xsl:apply-templates select="itemizedlist"/>
  <xsl:apply-templates select="note"/>
  <xsl:apply-templates select="tip"/>
  </TD></TR></TABLE>
</xsl:template>

<xsl:template match="formalpara">
<xsl:text>


</xsl:text>
  <xsl:apply-templates />
<xsl:text>

</xsl:text>
</xsl:template>

<xsl:template match="formalpara/title">
<xsl:apply-templates /><xsl:text>: </xsl:text>
  
</xsl:template>

<xsl:template match="screen">
<xsl:text>

</xsl:text>
<xsl:value-of select="." />
<xsl:text>

</xsl:text>
</xsl:template>

<xsl:template match="programlisting">
<xsl:text>

</xsl:text>
<xsl:value-of select="." />
<xsl:text>

</xsl:text>
</xsl:template>

<xsl:template match="table">
   <BR/>
   <TABLE CLASS="gentable" ALIGN="center">
   <xsl:if test="./tgroup/thead">
     <TR CLASS="gentabhead">
       <xsl:for-each select="./tgroup/thead/row/entry">
         <TD CLASS="gentabcells"><P CLASS="gentabheadp"><xsl:value-of select="." /></P></TD>
       </xsl:for-each>
     </TR>
   </xsl:if>

   <xsl:for-each select="./tgroup/tbody/row" >
     <TR>
     <xsl:for-each select="entry" >
       <TD CLASS="gentabcells">
			<xsl:choose>
				<xsl:when test="./para"><xsl:apply-templates /></xsl:when>
				<xsl:otherwise ><P CLASS="gentabcellsp"><xsl:value-of select="." /></P></xsl:otherwise>
			</xsl:choose>
			<!-- <xsl:apply-templates /> -->
		</TD>
     </xsl:for-each>
     </TR>
   </xsl:for-each> 

   <xsl:if test="./title">
     <TR>
   	<TD CLASS="gentabfoot">
   	<xsl:attribute name="COLSPAN"><xsl:value-of select="./tgroup/@cols" /></xsl:attribute>
   	<P CLASS="figurefooter"><xsl:value-of select="./title"/></P>
     	</TD></TR>
   </xsl:if>
   </TABLE>
   <BR/>
</xsl:template>

<xsl:template match="emphasis">
<xsl:apply-templates/>
</xsl:template>

<xsl:template match="quote">
&quot;<xsl:apply-templates/>&quot;
</xsl:template>

<xsl:template match="ulink">
  <a>
    <xsl:attribute name="href"><xsl:value-of select="@url"/></xsl:attribute>
    <xsl:apply-templates/>
  </a>
</xsl:template>

<xsl:template match="cmdsynopsis" xml:space="preserve">
<PRE CLASS="programlisting">
  <xsl:for-each select="command" >
    <xsl:value-of select="." />
  </xsl:for-each>
  <xsl:for-each select="arg" >
		<xsl:apply-templates />
  </xsl:for-each>
</PRE>
</xsl:template>

<xsl:template match="important">
<xsl:text>
</xsl:text>
!!!! Important !!!! : <xsl:apply-templates/>
<xsl:text>

</xsl:text>

</xsl:template>

<xsl:template match="variablelist">
<TABLE CLASS="varlist">
<xsl:for-each select="varlistentry" >
<TR><TD ALIGN="right" VALIGN="top">
       <P CLASS="varterm"><xsl:value-of select="term" />:</P>
</TD>
<TD>
  <xsl:for-each select="listitem" >
    <xsl:apply-templates />
  </xsl:for-each>
</TD></TR>
</xsl:for-each>
</TABLE>
</xsl:template>

<xsl:template match="simplelist">
<!-- no support for multiple columns -->
<xsl:text>

</xsl:text>
    <xsl:apply-templates select="member" />
<xsl:text>

</xsl:text>
</xsl:template>

<xsl:template match="orderedlist">
<!-- no support for multiple columns -->
<xsl:text>

</xsl:text>
    <xsl:apply-templates select="listitem" />
<xsl:text>

</xsl:text>
</xsl:template>

<xsl:template match="member">
<xsl:text>           * </xsl:text><xsl:apply-templates />
<xsl:text>

</xsl:text>
</xsl:template>

<xsl:template match="orderedlist/listitem">
<xsl:text>           (*) </xsl:text><xsl:apply-templates />
<xsl:text>

</xsl:text>
</xsl:template>

<xsl:template match="figure">
<xsl:text>

Figure: </xsl:text><xsl:value-of select="title" />
<xsl:text>
                  -~</xsl:text><xsl:value-of select="$imgP"/><xsl:value-of select="graphic/@fileref"/>
<xsl:text>


</xsl:text>

</xsl:template>


</xsl:stylesheet>
