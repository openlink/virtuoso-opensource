<!-- $Id$ -->
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:v="http://www.openlinksw.com/vspx/" xmlns:xhtml="http://www.w3.org/1999/xhtml" xmlns:vm="http://www.openlinksw.com/vspx/macro">
  <xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>
  <xsl:variable name="page_title" select="string (//vm:pagetitle)"/>

  <xsl:include href="dav_browser.xsl"/>

  <!--=========================================================================-->
  <xsl:template match="vm:popup_page_wrapper">
    <xsl:apply-templates select="node()|processing-instruction()"/>
    <div class="copyright">Copyright &amp;copy; 1999-2006 OpenLink Software</div>
  </xsl:template>

</xsl:stylesheet>

