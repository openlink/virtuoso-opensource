<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <!-- img ========================================================================== -->
  <xsl:template match="img">
    <img>
      <xsl:if test="@src != ''">
        <xsl:attribute name="src"><xsl:value-of select="@src"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@height != ''">
        <xsl:attribute name="height"><xsl:value-of select="@height"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@width != ''">
        <xsl:attribute name="width"><xsl:value-of select="@width"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@align != ''">
        <xsl:attribute name="align"><xsl:value-of select="@align"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@border != ''">
        <xsl:attribute name="border"><xsl:value-of select="@border"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@alt != ''">
        <xsl:attribute name="alt"><xsl:value-of select="@alt"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@vspace != ''">
        <xsl:attribute name="vspace"><xsl:value-of select="@vspace"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@hspace != ''">
        <xsl:attribute name="hspace"><xsl:value-of select="@hspace"/></xsl:attribute>
      </xsl:if>
      <xsl:call-template name="style"/>
      <xsl:apply-templates/>
    </img>
  </xsl:template>
  <!-- a ========================================================================== -->
  <xsl:template match="a">
    <a>
      <xsl:if test="@href != ''">
        <xsl:attribute name="href">redir.vsp?r=<xsl:value-of select="@href"/></xsl:attribute>
      </xsl:if>
      <xsl:call-template name="style"/>
      <xsl:apply-templates/>
    </a>
  </xsl:template>
  <!-- font ========================================================================== -->
  <xsl:template match="font">
    <font>
      <xsl:if test="@size != ''">
        <xsl:attribute name="size"><xsl:value-of select="@size"/></xsl:attribute>
      </xsl:if>
      <xsl:call-template name="style"/>
      <xsl:apply-templates/>
    </font>
  </xsl:template>
  <!-- table ========================================================================== -->
  <xsl:template match="table">
    <table>
      <xsl:if test="@width != ''">
        <xsl:attribute name="width"><xsl:value-of select="@width"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@align != ''">
        <xsl:attribute name="align"><xsl:value-of select="@align"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@border != ''">
        <xsl:attribute name="border"><xsl:value-of select="@border"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@cellpadding != ''">
        <xsl:attribute name="cellpadding"><xsl:value-of select="@cellpadding"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@cellspacing != ''">
        <xsl:attribute name="cellspacing"><xsl:value-of select="@cellspacing"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@background != ''">
        <xsl:attribute name="background"><xsl:value-of select="@background"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@bgcolor != ''">
        <xsl:attribute name="bgcolor"><xsl:value-of select="@bgcolor"/></xsl:attribute>
      </xsl:if>
      <xsl:call-template name="style"/>
      <xsl:apply-templates/>
    </table>
  </xsl:template>
  <!-- tr ========================================================================== -->
  <xsl:template match="tr">
    <tr>
      <xsl:call-template name="style"/>
      <xsl:apply-templates/>
    </tr>
  </xsl:template>
  <!-- td ========================================================================== -->
  <xsl:template match="td">
    <td>
      <xsl:if test="@colspan != ''">
        <xsl:attribute name="colspan"><xsl:value-of select="@colspan"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@rowspan != ''">
        <xsl:attribute name="rowspan"><xsl:value-of select="@rowspan"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@valign != ''">
        <xsl:attribute name="valign"><xsl:value-of select="@valign"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@align != ''">
        <xsl:attribute name="align"><xsl:value-of select="@align"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@background != ''">
        <xsl:attribute name="background"><xsl:value-of select="@background"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@bgcolor != ''">
        <xsl:attribute name="bgcolor"><xsl:value-of select="@bgcolor"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@nowrap != ''">
        <xsl:attribute name="nowrap"><xsl:value-of select="@nowrap"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@width != ''">
        <xsl:attribute name="width"><xsl:value-of select="@width"/></xsl:attribute>
      </xsl:if>
      <xsl:call-template name="style"/>
      <xsl:apply-templates/>
    </td>
  </xsl:template>
  <!-- b ========================================================================== -->
  <xsl:template match="b">
    <b>
      <xsl:call-template name="style"/>
      <xsl:apply-templates/>
    </b>
  </xsl:template>
  <!-- strong ========================================================================== -->
  <xsl:template match="strong">
    <strong>
      <xsl:call-template name="style"/>
      <xsl:apply-templates/>
    </strong>
  </xsl:template>
  <!-- i ========================================================================== -->
  <xsl:template match="i">
    <i>
      <xsl:call-template name="style"/>
      <xsl:apply-templates/>
    </i>
  </xsl:template>
  <!-- em ========================================================================== -->
  <xsl:template match="em">
    <em>
      <xsl:call-template name="style"/>
      <xsl:apply-templates/>
    </em>
  </xsl:template>
  <!-- br ========================================================================== -->
  <xsl:template match="br">
    <br>
      <xsl:apply-templates/>
    </br>
  </xsl:template>
  <!-- u ========================================================================== -->
  <xsl:template match="u">
    <u>
      <xsl:call-template name="style"/>
      <xsl:apply-templates/>
    </u>
  </xsl:template>
  <!-- p ========================================================================== -->
  <xsl:template match="p">
    <p>
      <xsl:call-template name="style"/>
      <xsl:apply-templates/>
    </p>
  </xsl:template>
  <!-- div ========================================================================== -->
  <xsl:template match="div">
    <div>
      <xsl:if test="@align != ''">
        <xsl:attribute name="align"><xsl:value-of select="@align"/></xsl:attribute>
      </xsl:if>
      <xsl:call-template name="style"/>
      <xsl:apply-templates/>
    </div>
  </xsl:template>
  <!-- center ========================================================================== -->
  <xsl:template match="center">
    <center>
      <xsl:call-template name="style"/>
      <xsl:apply-templates/>
    </center>
  </xsl:template>
  <!-- span ========================================================================== -->
  <xsl:template match="span">
    <span>
      <xsl:call-template name="style"/>
      <xsl:apply-templates/>
    </span>
  </xsl:template>
  <!-- ul ========================================================================== -->
  <xsl:template match="ul">
    <ul>
      <xsl:call-template name="style"/>
      <xsl:apply-templates/>
    </ul>
  </xsl:template>
  <!-- li ========================================================================== -->
  <xsl:template match="li">
    <li>
      <xsl:call-template name="style"/>
      <xsl:apply-templates/>
    </li>
  </xsl:template>
  <!-- style ======================================================================= -->
  <xsl:template match="style"/>
  <!-- script ====================================================================== -->
  <xsl:template match="script"/>
  <!-- title ======================================================================= -->
  <xsl:template match="title"/>
  <!-- ============================================================================= -->
  <xsl:template name="style">
    <xsl:if test="@style != ''">
      <xsl:attribute name="style"><xsl:value-of select="@style"/></xsl:attribute>
    </xsl:if>
  </xsl:template>
</xsl:stylesheet>
