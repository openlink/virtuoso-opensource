<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="html" indent="yes" encoding="UTF-8" />

  <xsl:template name="formatSize">
    <xsl:param name="size" />

    <xsl:variable name="startTail" select="substring-before($size, ' ')" />
    <xsl:variable name="endTail" select="substring-after($size, ' ')" />
    <xsl:value-of select="$startTail"/>
    <span style="font-family: Monospace;">&nbsp;<xsl:value-of select="$endTail"/><xsl:if test="string-length($endTail) = 1">&nbsp;</xsl:if></span>

  </xsl:template>

  <xsl:template name="formatDate">
    <xsl:param name="dateString" />

    <xsl:variable name="startTail" select="substring-before($size, ' ')" />
    <xsl:variable name="endTail" select="substring-after($size, ' ')" />
    <xsl:value-of select="$startTail"/>
    <span style="font-family: Monospace; font-size: 80%;">&nbsp;<xsl:value-of select="$endTail"/></span>

  </xsl:template>

  <xsl:template match="PATH">
    <xsl:variable name="path"><xsl:value-of select="@dir_name" /></xsl:variable>
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN">
    <html>
      <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
        <title>Directory listing of <xsl:value-of select="$path" /></title>
        <link rel="stylesheet" href="/conductor/dav/dav_browser.css" type="text/css"><xsl:text> </xsl:text></link>
        <script type="text/javascript" src="/conductor/toolkit/loader.js"><xsl:text> </xsl:text></script>
        <script type="text/javascript" src="/conductor/toolkit/json.js"><xsl:text> </xsl:text></script>
        <script type="text/javascript" src="/conductor/dav/dav_state.js"><xsl:text> </xsl:text></script>
        <script type="text/javascript" src="/conductor/dav/sorttable.js"><xsl:text> </xsl:text></script>
        <link rel="alternate" type="application/rss+xml" title="WebDAV Directory Listing (RSS)">
          <xsl:attribute name="href"><xsl:value-of select='$path' />?a=rss</xsl:attribute>
        </link>
        <link rel="alternate" type="application/atom+xml" title="WebDAV Directory Listing (Atom)">
          <xsl:attribute name="href"><xsl:value-of select='$path' />?a=atom</xsl:attribute>
        </link>
        <link rel="alternate" type="application/rdf+xml" title="WebDAV Directory Listing (RDF RSS 1.0)">
          <xsl:attribute name="href"><xsl:value-of select='$path' />?a=rdf</xsl:attribute>
        </link>
        <link rel="outline" type="text/x-opml" title="WebDAV Directory Subscriptions (OPML)">
          <xsl:attribute name="href"><xsl:value-of select='$path' />?a=opml</xsl:attribute>
        </link>
        <link rel="service" type="application/atomserv+xml" title="WebDAV Directory AtomPub Service">
          <xsl:attribute name="href"><xsl:value-of select='$path' />?a=atomPub</xsl:attribute>
        </link>
        <link rel="service" type="application/atomsvc+xml" title="WebDAV Directory AtomPub Service">
          <xsl:attribute name="href"><xsl:value-of select='$path' />?a=atomPub</xsl:attribute>
        </link>
      </head>
      <body style="background-color: #fff; color: #000; font-family: Arial,Helvetica,Helv,sans-serif;">
        <h4>Index of <xsl:value-of select="$path" /></h4>
        <table id="dir" class="WEBDAV_grid _sortable" style="border: 0px; font-size: 12px;">
          <thead id="dir_thead" style="font-size: 15px;">
            <tr>
              <th id="column_#1" width="50%" class="_sortable">Name</th>
              <th id="column_#3" class="_sortable">Size</th>
              <th id="column_#4" class="_sortable">Date Modified</th>
              <th id="column_#5" class="_sortable">Content Type</th>
              <th id="column_#7" class="_sortable">Owner</th>
              <th id="column_#8" class="_sortable">Group</th>
              <th id="column_#9" class="_unsortable">Permissions</th>
            </tr>
          </thead>
          <tbody id="dir_tbody">
            <xsl:apply-templates select="DIRS">
              <xsl:with-param name="f_path" select="$path" />
            </xsl:apply-templates>

            <xsl:apply-templates select="FILES">
              <xsl:with-param name="f_path" select="$path" />
            </xsl:apply-templates>
          </tbody>
        </table>
        <script type="text/javascript">
          OAT.SortTable.init('dir');
        </script>
      </body>
    </html>
  </xsl:template>

  <xsl:template match="SUBDIR">
    <xsl:param name="f_path" />
    <tr>
      <xsl:if test="@name = '..'">
        <xsl:attribute name="class">_unsortable</xsl:attribute>
      </xsl:if>
      <td>
        <xsl:attribute name="value"><xsl:value-of select="@name" /></xsl:attribute>
        <a>
          <xsl:attribute name="href"><xsl:value-of select='$f_path' /><xsl:value-of select='@name' /></xsl:attribute>
          <img src="/conductor/dav/image/dav/foldr_16.png" alt="folder" />&nbsp;<xsl:value-of select="@name" />
        </a>
      </td>
      <td></td>
      <td>
        <xsl:attribute name="value"><xsl:value-of select="@modify" /></xsl:attribute>
        <xsl:call-template name="formatDate">
          <xsl:with-param name="size" select="@modify" />
        </xsl:call-template>
      </td>
      <td></td>
      <td>
        <xsl:value-of select="@owner" />
      </td>
      <td>
        <xsl:value-of select="@group" />
      </td>
      <td>
        <xsl:value-of select="@permissions" />
      </td>
    </tr>
  </xsl:template>

  <xsl:template match="FILE">
    <xsl:param name="f_path" />
    <tr>
      <td>
        <xsl:attribute name="value"><xsl:value-of select="@name" /></xsl:attribute>
        <a>
          <xsl:attribute name="href"><xsl:value-of select='$f_path' /><xsl:value-of select='@name' /></xsl:attribute>
          <img src="/conductor/dav/image/dav/generic_file.png" alt="file" />&nbsp;<xsl:value-of select="@name" />
        </a>
      </td>
      <td align="right">
        <xsl:attribute name="value"><xsl:value-of select="@length" /></xsl:attribute>
        <xsl:call-template name="formatSize"><xsl:with-param name="size" select="@hs" /></xsl:call-template>
      </td>
      <td>
        <xsl:attribute name="value"><xsl:value-of select="@modify" /></xsl:attribute>
        <xsl:call-template name="formatDate">
          <xsl:with-param name="size" select="@modify" />
        </xsl:call-template>
      </td>
      <td>
        <xsl:value-of select="@mimeType" />
      </td>
      <td>
        <xsl:value-of select="@owner" />
      </td>
      <td>
        <xsl:value-of select="@group" />
      </td>
      <td>
        <xsl:value-of select="@permissions" />
      </td>
    </tr>
  </xsl:template>

</xsl:stylesheet>