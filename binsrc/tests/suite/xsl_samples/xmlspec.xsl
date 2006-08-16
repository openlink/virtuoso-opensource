<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl">
  <xsl:template><xsl:value-of/></xsl:template>

  <xsl:template match="*"><SPAN STYLE="color:pink"><xsl:attribute name="TITLE"><xsl:node-name/></xsl:attribute><xsl:apply-templates/></SPAN></xsl:template>

  <xsl:template match="/">
    <!--<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">-->
    <html>
      <head>
        <title><xsl:value-of select="spec/header/title"/></title>
      </head>
      <body>
        <xsl:for-each select="spec/header">
          <img src="http://www.w3.org/pub/WWW/Icons/WWW/w3c_home" alt="W3C Logo" border="0" align="left"/>
          <h4 align="right"><xsl:value-of select="w3c-designation"/></h4>
          <br clear="ALL"/>
          <h1 align="CENTER"><xsl:value-of select="title"/></h1>
          <h3 align="CENTER"><xsl:value-of select="version"/></h3>
          <h3 align="CENTER">World Wide Web Consortium Working Draft
            <xsl:value-of select="pubdate/day"/>-<xsl:value-of select="pubdate/month"/>-<xsl:value-of select="pubdate/year"/>
          </h3>

          <h4>This version</h4>
          <p><xsl:for-each select="publoc/loc"><xsl:apply-templates select="."/><br/></xsl:for-each></p>
          
          <h4>Latest version</h4>
          <p><xsl:for-each select="latestloc/loc"><xsl:apply-templates select="."/><br/></xsl:for-each></p>
          
          <h4>Previous versions</h4>
          <p><xsl:for-each select="prevlocs/loc"><xsl:apply-templates select="."/><br/></xsl:for-each><xsl:apply-templates select="prevlocs/loc"/></p>

          <h4>Editors</h4>
          <p><xsl:apply-templates select="authlist/author"/></p>

          <p><small><a href=
          "http://www.w3.org/Consortium/Legal/ipr-notice.html#Copyright">
          Copyright</a> <!-- BUGBUG &nbsp;&copy;&nbsp; --> 1998 <a href="http://www.w3.org">
          W3C</a> (<a href="http://www.lcs.mit.edu">MIT</a>, <a href=
          "http://www.inria.fr/">INRIA</a>, <a href="http://www.keio.ac.jp/">
          Keio</a>), All Rights Reserved. W3C <a href=
          "http://www.w3.org/Consortium/Legal/ipr-notice.html#Legal
          Disclaimer">liability</a>, <a href=
          "http://www.w3.org/Consortium/Legal/ipr-notice.html#W3C
          Trademarks">trademark</a>, <a href=
          "http://www.w3.org/Consortium/Legal/copyright-documents.html">
          document use</a> and <a href=
          "http://www.w3.org/Consortium/Legal/copyright-software.html">
          software licensing</a> rules apply.</small></p>

          <h2 class="status">Status of this document</h2>
          <xsl:apply-templates select="status"/>

          <h2 class="abstract">Abstract</h2>
          <xsl:apply-templates select="abstract"/>
        </xsl:for-each>
        
        <h2 class="table-of-contents">Table of Contents</h2>
        <dl class="table-of-contents">
          <xsl:apply-templates select="spec/body/div1">
            <xsl:template match="div1|div2|div3">
                <dt><xsl:eval>sectionNum(this)</xsl:eval>
                  <a><xsl:attribute name="href">#<xsl:choose>
                      <xsl:when test="@id"><xsl:value-of select="@id"/></xsl:when>
                      <xsl:otherwise>AEN<xsl:eval>uniqueID(this)</xsl:eval></xsl:otherwise>
                    </xsl:choose></xsl:attribute>
                    <xsl:value-of select="head"/>
                  </a>
                </dt>
                <xsl:if test="div2|div3">
                  <dd><dl><xsl:apply-templates select="div2|div3"/></dl></dd>
                </xsl:if>
            </xsl:template>
          </xsl:apply-templates>
        </dl>
        
        <h3 class="table-of-contents">Appendices</h3>
        <dl>
          <xsl:apply-templates select="spec/back/*">
            <xsl:template match="inform-div1|div1">
                <dt><xsl:eval>sectionNum(this)</xsl:eval>
                  <a><xsl:attribute name="href">#<xsl:choose>
                      <xsl:when test="@id"><xsl:value-of select="@id"/></xsl:when>
                      <xsl:otherwise>AEN<xsl:eval>uniqueID(this)</xsl:eval></xsl:otherwise>
                    </xsl:choose></xsl:attribute>
                    <xsl:value-of select="head"/>
                  </a>
                </dt>
                <xsl:if test="div2">
                  <dd><dl><xsl:apply-templates select="div2"/></dl></dd>
                </xsl:if>
            </xsl:template>
            <xsl:template match="div2">
                <dt><xsl:eval>sectionNum(this)</xsl:eval>
                  <a><xsl:attribute name="href">#<xsl:choose>
                      <xsl:when test="@id"><xsl:value-of select="@id"/></xsl:when>
                      <xsl:otherwise>AEN<xsl:eval>uniqueID(this)</xsl:eval></xsl:otherwise>
                    </xsl:choose></xsl:attribute>
                    <xsl:value-of select="head"/>
                  </a>
                </dt>
            </xsl:template>
            <xsl:template match="inform-div1">
                <dt><xsl:eval>sectionNum(this)</xsl:eval>
                  <a><xsl:attribute name="href">#<xsl:choose>
                      <xsl:when test="@id"><xsl:value-of select="@id"/></xsl:when>
                      <xsl:otherwise>AEN<xsl:eval>uniqueID(this)</xsl:eval></xsl:otherwise>
                    </xsl:choose></xsl:attribute>
                    <xsl:value-of select="head"/>
                  </a> (Non-Normative)
                </dt>
            </xsl:template>
          </xsl:apply-templates>
        </dl>

        <xsl:apply-templates select="spec/body"/>
        <xsl:apply-templates select="spec/back"/>

      </body>
    </html>
  </xsl:template>
  
  <xsl:template match="loc">
    <a class="loc"><xsl:attribute name="href"><xsl:value-of select="@href"/></xsl:attribute><xsl:value-of/></a>
  </xsl:template>

  <xsl:template match="author">
    <span class="author">
      <span class="name"><xsl:value-of select="name"/></span><xsl:if test="affiliation">, <xsl:value-of select="affiliation"/></xsl:if>
      <i> (<span class="email"><xsl:value-of select="email"/></span>)</i>
      <xsl:if test="@part">[<xsl:value-of select="@part"/>]</xsl:if>
      <br/>
    </span>
  </xsl:template>

  <xsl:template match="status | abstract | body | back"><xsl:apply-templates/></xsl:template>
  
  <xsl:template match="div1">
    <div class="div1">
      <h2><xsl:eval>sectionNum(this)</xsl:eval>
        <a><xsl:attribute name="name"><xsl:choose>
            <xsl:when test="@id"><xsl:value-of select="@id"/></xsl:when>
            <xsl:otherwise>AEN<xsl:eval>uniqueID(this)</xsl:eval></xsl:otherwise>
          </xsl:choose></xsl:attribute>
          <xsl:value-of select="head"/>
        </a>
      </h2>
      <xsl:apply-templates/>
    </div>
  </xsl:template>
  
  <xsl:template match="div2">
    <div class="div2">
      <h3><xsl:eval>sectionNum(this)</xsl:eval>
        <a><xsl:attribute name="name"><xsl:choose>
            <xsl:when test="@id"><xsl:value-of select="@id"/></xsl:when>
            <xsl:otherwise>AEN<xsl:eval>uniqueID(this)</xsl:eval></xsl:otherwise>
          </xsl:choose></xsl:attribute>
          <xsl:value-of select="head"/>
        </a>
      </h3>
      <xsl:apply-templates/>
    </div>
  </xsl:template>
  
  <xsl:template match="div3">
    <div class="div3">
      <h4><xsl:eval>sectionNum(this)</xsl:eval>
        <a><xsl:attribute name="name"><xsl:choose>
            <xsl:when test="@id"><xsl:value-of select="@id"/></xsl:when>
            <xsl:otherwise>AEN<xsl:eval>uniqueID(this)</xsl:eval></xsl:otherwise>
          </xsl:choose></xsl:attribute>
          <xsl:value-of select="head"/>
        </a>
      </h4>
      <xsl:apply-templates/>
    </div>
  </xsl:template>
  
  <xsl:template match="div4">
    <div class="div4">
      <h5><xsl:eval>sectionNum(this)</xsl:eval>
        <a><xsl:attribute name="name"><xsl:choose>
            <xsl:when test="@id"><xsl:value-of select="@id"/></xsl:when>
            <xsl:otherwise>AEN<xsl:eval>uniqueID(this)</xsl:eval></xsl:otherwise>
          </xsl:choose></xsl:attribute>
          <xsl:value-of select="head"/>
        </a>
      </h5>
      <xsl:apply-templates/>
    </div>
  </xsl:template>
  
  <xsl:template match="div5">
    <div class="div5">
      <h6><xsl:eval>sectionNum(this)</xsl:eval>
        <a><xsl:attribute name="name"><xsl:choose>
            <xsl:when test="@id"><xsl:value-of select="@id"/></xsl:when>
            <xsl:otherwise>AEN<xsl:eval>uniqueID(this)</xsl:eval></xsl:otherwise>
          </xsl:choose></xsl:attribute>
          <xsl:value-of select="head"/>
        </a>
      </h6>
      <xsl:apply-templates/>
    </div>
  </xsl:template>
  
  <xsl:template match="inform-div1">
    <div class="inform-div1">
      <h2><xsl:eval>sectionNum(this)</xsl:eval>
        <a><xsl:attribute name="name"><xsl:choose>
            <xsl:when test="@id"><xsl:value-of select="@id"/></xsl:when>
            <xsl:otherwise>AEN<xsl:eval>uniqueID(this)</xsl:eval></xsl:otherwise>
          </xsl:choose></xsl:attribute>
          <xsl:value-of select="head"/> (Non-Normative)
        </a>
      </h2>
      <xsl:apply-templates/>
    </div>
  </xsl:template>
  
  <xsl:template match="head"/>
    
  <xsl:template match="p"><p><xsl:apply-templates/></p></xsl:template>
  <xsl:template match="quote">"<xsl:apply-templates/>"</xsl:template>
  <xsl:template match="code"><code><xsl:apply-templates/></code></xsl:template>
  <xsl:template match="term"><i><xsl:apply-templates/></i></xsl:template>
  <xsl:template match="emph"><i><xsl:apply-templates/></i></xsl:template>
  <xsl:template match="eg"><pre><xsl:apply-templates/></pre></xsl:template>
  <xsl:template match="eg[@role='error']"><pre style="color:red"><xsl:apply-templates/></pre></xsl:template>
  
  <xsl:template match="bibref">
    <a><xsl:attribute name="href">#<xsl:value-of select="@ref"/></xsl:attribute>[<xsl:value-of select="id(@ref)/@key"/>]</a></xsl:template>
  
  <!-- BUGBUG  sectionNum adds the trailing ".", in this case a ":" is more appropriate -->
  <xsl:template match="specref">
    <a><xsl:attribute name="href">#<xsl:value-of select="@ref"/></xsl:attribute>
      <xsl:for-each select="id(@ref)">
        <b>Section <xsl:eval>sectionNum(this)</xsl:eval></b>
        <b><xsl:value-of select="head"/></b></xsl:for-each></a></xsl:template>

  <xsl:template match="termdef">
    <a><xsl:attribute name="name"><xsl:value-of select="@id"/></xsl:attribute></a>
    <xsl:apply-templates/></xsl:template>

  <xsl:template match="termref">
    <a><xsl:attribute name="href">#<xsl:value-of select="@def"/></xsl:attribute><xsl:apply-templates/></a></xsl:template>

  <!-- BUGBUG  strip off "issue-" from the id to turn it into the name -->
  <xsl:template match="issue">
    <div class="issue">
      <blockquote>
        <xsl:apply-templates>
          <xsl:template match="p[0]">
            <b><a><xsl:attribute name="name"><xsl:value-of select="../@id"/></xsl:attribute>
              Issue (<xsl:value-of select="../@id"/>):</a></b>
            <xsl:apply-templates/>
          </xsl:template>
        </xsl:apply-templates>
      </blockquote>
    </div>
  </xsl:template>

  <xsl:template match="ednote">
    <div class="ednote">
      <blockquote>
        <b>Ed. note:</b>
        <xsl:value-of select="edtext"/>
      </blockquote>
    </div>
  </xsl:template>

  <xsl:template match="note">
    <div class="note">
      <blockquote>
        <xsl:apply-templates>
          <xsl:template match="p[0]">
            <b>NOTE:</b>
            <xsl:apply-templates/>
          </xsl:template>
        </xsl:apply-templates>
      </blockquote>
    </div>
  </xsl:template>

  <xsl:template match="olist">
    <ol>
      <xsl:for-each select="item">
        <li><xsl:apply-templates/></li>
      </xsl:for-each>
    </ol>
  </xsl:template>

  <xsl:template match="ulist">
    <ul>
      <xsl:for-each select="item">
        <li><xsl:apply-templates/></li>
      </xsl:for-each>
    </ul>
  </xsl:template>

  <xsl:template match="slist">
    <ul class="slist">
      <xsl:for-each select="sitem">
        <li><xsl:apply-templates/></li>
      </xsl:for-each>
    </ul>
  </xsl:template>
  
  <xsl:template match="glist">
    <dl>
      <xsl:for-each select="gitem">
        <dt><xsl:apply-templates select="label"/></dt>
        <dd><xsl:apply-templates select="def"/></dd>
      </xsl:for-each>
    </dl>
  </xsl:template>
  <xsl:template match="label | def"><xsl:apply-templates/></xsl:template>

  <xsl:template match="blist">
    <dl>
      <xsl:for-each select="bibl">
        <dt><xsl:apply-templates select="@key"/></dt>
        <dd><xsl:apply-templates/></dd>
      </xsl:for-each>
    </dl>
  </xsl:template>

  <xsl:template match="scrap">
    <div class="scrap">
      <h4><xsl:value-of select="head"/></h4>
      <hr/>
      <table border="0" width="100%">
        <xsl:for-each select="prod">
          <tr>
            <th align="LEFT" valign="TOP" width="5%"><a><xsl:attribute name="name"><xsl:value-of select="@id"/></xsl:attribute>
            [<xsl:eval>prodNum()</xsl:eval>]</a></th>
            <td align="LEFT" valign="TOP" width="20%"><xsl:apply-templates select="lhs"/></td>
            <td align="LEFT" valign="TOP" width="5%">::=</td>
            <td align="LEFT" valign="TOP" width="60%" colspan="2"><xsl:apply-templates select="rhs[0]"/></td>
          </tr>
          <xsl:for-each select="rhs[index()$gt$0]">
            <tr>
              <td width="5%"></td>
              <td width="20%"></td>
              <td width="5%"></td>
              <td align="LEFT" valign="TOP" width="60%" colspan="2"><xsl:apply-templates select="."/></td>
            </tr>
          </xsl:for-each>
        </xsl:for-each>
      </table>
      <hr/>
    </div>
  </xsl:template>

  <xsl:template match="lhs | rhs"><xsl:apply-templates/></xsl:template>

  <xsl:template match="xnt">
    <a><xsl:attribute name="href"><xsl:value-of select="@href"/></xsl:attribute><i><xsl:apply-templates/></i></a></xsl:template>

  <xsl:template match="prod//xnt">
    <a><xsl:attribute name="href"><xsl:value-of select="@href"/></xsl:attribute><xsl:apply-templates/></a></xsl:template>

  <xsl:template match="nt">
    <a><xsl:attribute name="href">#<xsl:value-of select="@def"/></xsl:attribute><i><xsl:apply-templates/></i></a></xsl:template>

  <xsl:template match="prod//nt">
    <a><xsl:attribute name="href">#<xsl:value-of select="@def"/></xsl:attribute><xsl:apply-templates/></a></xsl:template>

  <!-- <xsl:script><![CDATA[
    function sectionNum(e) {
      if (e)
      {
        if (e.parentNode.nodeName == "back")
          return formatIndex(absoluteChildNumber(e), "A") + ".";
        else
          return sectionNum(e.selectSingleNode("ancestor(inform-div1|div1|div2|div3|div4|div5)")) +
               formatIndex(childNumber(e), "1") + ".";
      }
      else
      {
        return "";
      }
    }
    
    var prodCount = 1;
    function prodNum() {
      return formatIndex(prodCount++, "1");
    }

  ]]></xsl:script> -->

</xsl:stylesheet>
