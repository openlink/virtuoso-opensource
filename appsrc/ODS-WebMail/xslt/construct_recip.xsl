<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="html"/>
  <!-- ====================================================================================== -->
  <xsl:template match="/fr">
    <xsl:apply-templates select="address/addres_list/from"/>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="/to">
    <xsl:apply-templates select="address/addres_list/to"/>
    <xsl:if test="address/addres_list/cc != ''">,<xsl:apply-templates select="address/addres_list/cc"/>
    </xsl:if>
    <xsl:if test="address/addres_list/bcc != ''">,<xsl:apply-templates select="address/addres_list/bcc"/>
    </xsl:if>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="address/addres_list/from | address/addres_list/to | address/addres_list/cc | address/addres_list/bcc">
    <xsl:call-template name="v_name"/>
    <xsl:text> </xsl:text>
    <xsl:call-template name="v_email"/>
    <xsl:if test="position() != last()">, </xsl:if>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="v_name">
    <xsl:if test="name != ''">"<xsl:value-of select="name"/>"</xsl:if>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template name="v_email">
    <xsl:if test="email != ''">&lt;<xsl:value-of select="email"/>&gt;</xsl:if>
  </xsl:template>
  <!-- ====================================================================================== -->
</xsl:stylesheet>
