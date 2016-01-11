<?xml version="1.0" encoding="ISO-8859-1" ?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2016 OpenLink Software
 -  
 -  This project is free software; you can redistribute it and/or modify it
 -  under the terms of the GNU General Public License as published by the
 -  Free Software Foundation; only version 2 of the License, dated June 1991.
 -  
 -  This program is distributed in the hope that it will be useful, but
 -  WITHOUT ANY WARRANTY; without even the implied warranty of
 -  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 -  General Public License for more details.
 -  
 -  You should have received a copy of the GNU General Public License along
 -  with this program; if not, write to the Free Software Foundation, Inc.,
 -  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 -  
 -  
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<!--=========================================================================-->
<xsl:include href="interop.xsl"/>
<!--=========================================================================-->
<xsl:template name="html-title">
  <title>Virtuoso BPEL Interoperability WS-I Advocate</title>
</xsl:template>
<!--=========================================================================-->
<xsl:template name="Interop">
  <tr>
    <td>
      <p><font class="m_t"><b><xsl:text>Web Site Welcome introduction</xsl:text></b></font></p>
      <p><b><xsl:text>Welcome to the home of OpenLink BPEL Interoperability.</xsl:text></b></p>
      <p>
      <xsl:text>The purpose of the web site to help vendors and users test BPEL implementations based on the </xsl:text>
      <a href="http://www-106.ibm.com/developerworks/library/ws-bpel/" class="m_n">BPEL4WS specification.</a>
      <xsl:text>
        This site provides a vehicle for testing BPEL integration with WS-Security and WS-Reliable Messaging,
        OASIS BPEL Use Cases (hyperlink to BPEL Use Case Testing on Page - Link in ) as well as test for
        interoperability between BPELWS 1.1 compliant products.
      </xsl:text>
      </p>
      <p>
        <xsl:text>
          This site provides test collateral including scripts and wsdls, which are free to download.
          All tests (hyperlink to BPEL Interop Testing on page) are online fully automated and can be
          experienced by selecting the links below.
        </xsl:text>
      </p>
      <p>
        <xsl:text>
         Please visit our of the main web site for more details on the Virtuoso BPEL process manager
         (hyperlink to OpenLink BPEL Process Manager summary page) or
        </xsl:text>
        <a href="http://virtuoso.openlinksw.com/" class="m_n">OpenLinks Virtuoso Universal Server</a>.
      </p>
      <p>
        Join us or send feedback <a href="mailto:bpelfeedback@openlinksw.com " class="m_n">bpelfeedback@openlinksw.com</a>
        and let us know what you think <a href="support@openlinksw.com " class="m_n">support@openlinksw.com</a>.
      </p>
    </td>
  </tr>
</xsl:template>
<!--=========================================================================-->
</xsl:stylesheet>
