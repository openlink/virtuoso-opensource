<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:include href="common.xsl"/>
  <!-- ====================================================================================== -->
  <xsl:template match="/dev">
    <xsl:apply-templates select="page"/>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="page">
    <table align="center" cellpadding="0" cellspacing="0" border="0" id="info" width="70%">
      <tr height="200">
        <th style="text-align: center;">The message has been sent successfully to: <i><xsl:value-of select="//to"/></i></th>
      </tr>
      <xsl:if test="string(//page/@mode) != 'popup'">
        <tr>
          <th style="text-align: center;">
            <hr/>
            <xsl:choose>
              <xsl:when test="return/@type = 'form'">
                <xsl:call-template name="make_href">
                  <xsl:with-param name="url">javascript:Go();</xsl:with-param>
                  <xsl:with-param name="label">Close window</xsl:with-param>
                  <xsl:with-param name="title">Close window</xsl:with-param>
                </xsl:call-template>
              </xsl:when>
              <xsl:when test="return/@type = 'url'">
                <xsl:call-template name="make_href">
                  <xsl:with-param name="url"><xsl:value-of select="return"/></xsl:with-param>
                  <xsl:with-param name="label">OK</xsl:with-param>
                  <xsl:with-param name="title">OK</xsl:with-param>
                  <xsl:with-param name="params"><xsl:value-of select="eparams"/></xsl:with-param>
                </xsl:call-template>
              </xsl:when>
              <xsl:otherwise>
                <xsl:call-template name="make_href">
                  <xsl:with-param name="url">write.vsp</xsl:with-param>
                  <xsl:with-param name="label">Write new message?</xsl:with-param>
                  <xsl:with-param name="title">Write new message?</xsl:with-param>
                </xsl:call-template>
              </xsl:otherwise>
            </xsl:choose>
          </th>
        </tr>
      </xsl:if>
    </table>
    <br/>
    <xsl:call-template name="external_action"/>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="external_action">
    <script>
      <xsl:text>
    function Go(){
      if(opener){
        </xsl:text>
      <xsl:apply-templates select="return"/>
      <xsl:apply-templates select="external_params"/>
      <xsl:text>
      opener_form.submit();
      window.close();
      }else{
        alert('Missing parent window')
      }
    }
  </xsl:text>
    </script>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="return">
    <xsl:text>opener_form = opener.document.</xsl:text>
    <xsl:value-of select="."/>
    <xsl:text>
  </xsl:text>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="external_params">
    <xsl:for-each select="*">
      <xsl:text>      opener_form.</xsl:text>
      <xsl:value-of select="name()"/>
      <xsl:text>.value = '</xsl:text>
      <xsl:value-of select="."/>
      <xsl:text>'
  </xsl:text>
    </xsl:for-each>
  </xsl:template>
  <!-- ====================================================================================== -->
</xsl:stylesheet>
