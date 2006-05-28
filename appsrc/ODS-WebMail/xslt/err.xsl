 <xsl:stylesheet xmlns:xsl = "http://www.w3.org/1999/XSL/Transform" version = "1.0" >
  <xsl:include href="common.xsl"/>

  <!-- ========================================================================== -->
  <xsl:template match = "page">
    <xsl:apply-templates select="errors/error[@id = current()/error]"/>
    <xsl:if test="not(errors/error[@id = current()/error])">
      <xsl:apply-templates select="errors/error[@id = 0]"/>
    </xsl:if>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match = "error">
    <table id="info" style="width:500px" align="center">
      <caption><span>Problem</span></caption>
      <xsl:apply-templates/>
    </table>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match = "title">
    <tr>
      <td rowspan="3" class="warning">Error <xsl:value-of select="../../../error"/></td>
      <td><h1><xsl:apply-templates/></h1></td>
    </tr>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match = "descr">
    <tr>
      <td><xsl:apply-templates/></td>
    </tr>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match = "decision">
    <tr>
      <td>Decision:<br/>
        <xsl:apply-templates/>
      </td>
    </tr>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match = "button" name = "button">
    <tfoot>
      <tr>
        <td></td>
        <td>
          <ul id="buttons">
            <li>
              <xsl:call-template name="link"/>
            </li>
          </ul>
        </td>
      </tr>
    </tfoot>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="back" name="link">
    <a>
      <xsl:choose>
        <xsl:when test="@page">
          <xsl:attribute name="href">
            <xsl:value-of select="@page"/>
            <xsl:text>?sid=</xsl:text>
            <xsl:value-of select="$sid"/>
            <xsl:text>&amp;realm=</xsl:text>
            <xsl:value-of select="$realm"/>
            <xsl:if test="@p">
              <xsl:text>&amp;</xsl:text>
              <xsl:value-of select="@p"/>
              <xsl:text>=</xsl:text>
              <xsl:value-of select="/page/p"/>
            </xsl:if>
          </xsl:attribute>
        </xsl:when>
        <xsl:otherwise>
          <xsl:attribute name="href">javascript:history.go(-1)</xsl:attribute>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:attribute name="title">Back</xsl:attribute>
      Back
    </a>
    <xsl:apply-templates/>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match = "msg">
    <xsl:value-of select="//msg"/>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match = "b">
    <b>
      <xsl:apply-templates/>
    </b>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match = "br">
    <br/>
    <xsl:apply-templates/>
  </xsl:template>

  <!-- ========================================================================== -->
</xsl:stylesheet>