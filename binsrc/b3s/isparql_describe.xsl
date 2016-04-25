<?xml version="1.0" encoding="utf-8"?>

<!--

  $Id$

  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
  project.

  Copyright (C) 1998-2016 OpenLink Software

  This project is free software; you can redistribute it and/or modify it
  under the terms of the GNU General Public License as published by the
  Free Software Foundation; only version 2 of the License, dated June 1991.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program; if not, write to the Free Software Foundation, Inc.,
  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA

-->

<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:ex="http://example.org/stuff/1.0/">
<xsl:output method="html"
            omit-xml-declaration="yes"
            encoding="utf-8"
            indent="yes"/>

<xsl:param name="full_path"/>
<xsl:param name="name"/>

<xsl:template match="iSPARQL">
  <tr>
    <td class="title"><xsl:value-of select="Description/title"/></td>
    <td class="expln"><xsl:value-of select="Description/description"/></td>
    <!-- td class="qry">
      <code>
        <xsl:value-of select="ISparqlDynamicPage/query"/>
      </code>
    </td --> <!-- .qry -->
    <td class="actions">
      <a>
        <xsl:attribute name="href">
          <xsl:value-of select="$full_path"/>
        </xsl:attribute>
        Run with iSPARQL
      </a>&nbsp;
      <a>
        <xsl:attribute name="href">
          <![CDATA[/sparql?]]>query=<xsl:value-of select="ISparqlDynamicPage/query"/>
        </xsl:attribute>
        Run in SPARQL endpoint
      </a>
    </td> <!-- .actions -->
  </tr>
</xsl:template>

</xsl:stylesheet>

