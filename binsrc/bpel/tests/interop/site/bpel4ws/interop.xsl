<?xml version="1.0" encoding="ISO-8859-1" ?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<xsl:output method="html" omit-xml-declaration="yes" indent="yes"/>
<!--=========================================================================-->
<xsl:template match="/">
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <xsl:call-template name="html-title"/>
      <xsl:call-template name="html-style-base"/>
    </head>
    <xsl:call-template name="html-body"/>
  </html>
</xsl:template>
<!--=========================================================================-->
<xsl:template name="html-title">
  <title>Virtuoso BPEL Interoperability</title>
</xsl:template>
<!--=========================================================================-->
<xsl:template name="html-style-base">
  <xsl:element name="link">
    <xsl:attribute name="type">text/css</xsl:attribute>
    <xsl:attribute name="rel">stylesheet</xsl:attribute>
    <xsl:attribute name="href">/bpel4ws/interop/default.css</xsl:attribute>
  </xsl:element>
</xsl:template>
 <!--=========================================================================-->
<xsl:template name="html-body">
  <body>
    <table cellSpacing="0" cellPadding="0" width="100%" border="0">
      <xsl:call-template name="layout-header"/>
      <xsl:call-template name="layout-body"/>
      <xsl:call-template name="layout-footer"/>
    </table>
  </body>
</xsl:template>
 <!--=========================================================================-->
<xsl:template name="layout-header">
  <tr>
    <td colspan="2">
      <div class="masthead">
        <table cellSpacing="0" cellPadding="0" width="100%" border="0">
          <tr>
           <td>
	     <img height="50" src="/bpel4ws/interop/openlink150.gif" width="150"/>
            </td>
           <td align="right">
           <div class="m_e">
	   <a class="m_e" href="/bpel4ws/interop/interop.vsp">Interop Home</a> |
          <a class="m_e" href="http://www.openlinksw.com/index.htm">OpenLink Home</a> |
           <a class="m_e" href="http://www.openlinksw.com/main/company.htm">About Us</a> |
           <a class="m_e" href="http://www.openlinksw.com/main/search.vsp">Search</a>&nbsp;<!-- |
           <!--<a class="m_e" href="http://www.openlinksw.com/main/sitemap.htm">Sitemap</a>-->
           </div>
           </td>
          </tr>
        </table>
      </div>
    </td>
  </tr>
  <tr align="right"></tr>
  <tr><td>&nbsp;</td></tr>
  <tr>
    <td class="m_h">Virtuoso Universal Server</td>
  </tr>
</xsl:template>
 <!--=========================================================================-->
<xsl:template name="layout-body">
  <tr>
    <td vAlign="top" width="100%" class="m_s">Business Process Execution Language (BPEL) Interoperability Site</td>
    <td style="padding-right:10px;">
      <a class="m_n"  href="http://groups.yahoo.com/group/ws-bpel-interop/join">
	<img src="http://us.i1.yimg.com/us.yimg.com/i/yg/img/ui/join.gif" border="0" alt="Click here to join ws-bpel-interop"/>
	<div style="font-size=9pt; white-space: nowrap;">Click to join<br/> ws-bpel-interop</div>
      </a>
    </td>
  </tr>
  <tr>
    <td colspan="2">
       <table width="100%" border="0" cellpadding="0" cellspacing="0" id="content">
          <xsl:call-template name="Interop"/>
      </table>
    </td>
  </tr>
  <tr><td>&nbsp;</td></tr>
</xsl:template>
<!--=========================================================================-->
<xsl:template name="Interop">
  <tr>
    <td colspan="2">
      <a href="about.vsp" class="m_n">About this site</a>
    </td>
  </tr>
  <tr>
    <td colspan="2">
      <a href="bpelrsc.vsp" class="m_n">BPEL Resources</a>
    </td>
  </tr>
  <tr>
    <td colspan="2">
      <a href="protocols.vsp" class="m_n">Protocol Support</a>
    </td>
  </tr>
  <tr>
    <td colspan="2">
      <a href="mgrsum.vsp" class="m_n">Process Manager Summary</a>
    </td>
  </tr>
  <tr>
    <td colspan="2">
      <a href="tstsum.vsp" class="m_n">Test Results</a>
    </td>
  </tr>
  <tr>
    <td colspan="2">
      <p><b>BPEL Interop Testing</b></p>
      <ul>
        <xsl:apply-templates select="test"/>
      </ul>
    </td>
  </tr>
  <tr>
    <td colspan="2">
      <b>BPEL Use Case Testing</b>
      <p>
	The <a class="m_n" href="http://www.oasis-open.org/">
	OASIS </a>WSBPEL Technical Committee maintains a list of Use cases for the
	<a class="m_n" target="_top" href="http://www-106.ibm.com/developerworks/library/ws-bpel/">
	BPEL4WS specification</a>. The following Use (In Process and Completed) cases have been implemented and tested.
      </p>
      <ul>
	<li><a class="m_n" href="http://www.oasis-open.org/committees/download.php/6045/MS-01.rtf">MS-01</a></li>
      </ul>
      <p>Discussions regarding specifications and implementations should be directed to the OASIS TC.</p>
    </td>
  </tr>
  <tr>
    <td>
      <img height="40" src="WS-I_Advocate_Color_sm.gif"/>&nbsp;
      <a class="m_n" href="wsa.vsp">WS-I Advocate</a>
    </td>
  </tr>
</xsl:template>
<!--=========================================================================-->
<xsl:template match="test">
  <li>
     <a class="m_n"><xsl:attribute name="href">view.vsp?id=<xsl:value-of select="@Id"/></xsl:attribute><xsl:value-of select="@Name"/></a>
  </li>
</xsl:template>
<!--=========================================================================-->
<xsl:template name="layout-footer">
  <tr>
    <td colspan="2">
      <div class="footer">
        <A class="m_n" href="http://www.openlinksw.com/main/contactu.htm">Contact Us</A> |
	<A class="m_n" href="http://virtuoso.openlinksw.com/interop/index.htm#">Privacy</A>
      </div>
      <div class="copyright">
	<xsl:text disable-output-escaping="yes">Copyright &amp;copy; 1998-2017 OpenLink Software</xsl:text>
      </div>
    </td>
  </tr>
</xsl:template>
<!--=========================================================================-->
</xsl:stylesheet>
