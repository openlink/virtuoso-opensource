<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
  xmlns:v="http://www.openlinksw.com/vspx/"
  xmlns:vm="http://www.openlinksw.com/vspx/macro/">
<!--=========================================================================-->
<xsl:template name="html-style-base">
  <xsl:element name="link">
    <xsl:attribute name="type">text/css</xsl:attribute>
    <xsl:attribute name="rel">stylesheet</xsl:attribute>
    <xsl:attribute name="href">../default.css</xsl:attribute>
  </xsl:element>
</xsl:template>
<!--=========================================================================-->
<xsl:template name="html-body">
  <body>
    <table cellSpacing="0" cellPadding="0" width="100%" border="0">
      <tr class="masthead"><td colspan="2"><xsl:call-template name="layout-header"/></td></tr>
      <tr><td><xsl:call-template name="layout-body"/></td></tr>
      <tr><td><xsl:call-template name="layout-footer"/></td></tr>
    </table>
  </body>
</xsl:template>
<!--=========================================================================-->
<xsl:template name="layout-footer">
      <div class="footer">
        <a class="m_e" href="http://www.openlinksw.com/main/contactu.htm">Contact Us</a> |
	<a class="m_e" href="http://virtuoso.openlinksw.com/interop/index.htm#">Privacy</a>
      </div>
      <div class="copyright">Copyright &amp;copy; 1999-<?V "LEFT" (datestring (now()), 4)?> OpenLink Software</div>
</xsl:template>
<!--=========================================================================-->
<xsl:template name="layout-header">
  <div class="masthead">
    <table width="100%"  border="0" cellpadding="0" cellspacing="0">
      <tr>
        <td colspan="2"><img src="../openlink150.gif" alt="" name="" width="150"/></td>
      </tr>
    </table>
  </div>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="/">
  <xsl:apply-templates select="v:page"/>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="vm:page">
<v:variable name="host" default="null" type="varchar"/>
<v:on-init>
  if (self.host is null)
    {
      self.host := http_request_header (lines, 'Host');
    }
</v:on-init>
<html>
  <head>
    <xsl:apply-templates select="vm:title"/>
    <xsl:call-template name="html-style-base"/>
  </head>
  <xsl:call-template name="html-body"/>
</html>
</xsl:template>
<!--=========================================================================-->
<xsl:template name="layout-body">
  <tr>
    <td>
      <xsl:apply-templates select="vm:body"/>
    </td>
  </tr>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="vm:body">
  <xsl:apply-templates select="*"/>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="vm:title">
  <title>
    <xsl:apply-templates/>
  </title>
</xsl:template>
<!--=========================================================================-->
</xsl:stylesheet>
