<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <!-- ====================================================================================== -->
  <xsl:template name="folder_tree">
    <xsl:param name="$url_cl"/>
    <xsl:param name="$url_op"/>
    <div id="tree">
      <table cellpadding="0" cellspacing="0" border="0">
        <xsl:apply-templates select="page/folders" mode="list"/>
      </table>
    </div>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="folders" mode="list">
    <xsl:for-each select="folder">
      <tr>
        <td>
          <xsl:call-template name="nbsp"/>
        </td>
        <td>
          <table border="0" cellpadding="0" cellspacing="0">
            <tr>
              <td>
                <xsl:apply-templates select="ftree/fnode"/>
                <xsl:call-template name="nbsp"/>
              </td>
              <td>
                <xsl:call-template name="make_href">
                  <xsl:with-param name="url">box.vsp</xsl:with-param>
                  <xsl:with-param name="label"><xsl:value-of select="substring(name,1,10)"/><xsl:if test="string-length(name) > 10">...</xsl:if></xsl:with-param>
                  <xsl:with-param name="params">bp=<xsl:value-of select="folder_id"/>,0,<xsl:value-of select="/page/messages/order"/>,<xsl:value-of select="/page/messages/direction"/><xsl:value-of select="/page/eparams"/></xsl:with-param>
                  <xsl:with-param name="class">
                    <xsl:if test="folder_id = /page/folder_id">bc</xsl:if>
                  </xsl:with-param>
                </xsl:call-template>
                <xsl:if test="new_cnt + all_cnt != 0">
                  <font class="n"> (<xsl:value-of select="new_cnt"/>/<xsl:value-of select="all_cnt"/>)</font>
                </xsl:if>
              </td>
            </tr>
          </table>
        </td>
      </tr>
      <xsl:apply-templates select="m_list" mode="mlist"/>
      <xsl:apply-templates select="folders" mode="list"/>
    </xsl:for-each>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="ftree/fnode">
    <xsl:choose>
      <xsl:when test="parent::ftree/parent::folder/folder_id = $fid">
        <xsl:variable name="fol">op</xsl:variable>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="fol">cl</xsl:variable>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:choose>
      <xsl:when test=". = 'F'">
        <img align="top">
          <xsl:attribute name="src">/oMail/i/re_t_<xsl:value-of select="$fol"/>.gif</xsl:attribute>
        </img>
      </xsl:when>
      <xsl:when test=". = '-'">
        <img align="top">
          <xsl:attribute name="src">/oMail/i/re_g_<xsl:value-of select="$fol"/>.gif</xsl:attribute>
        </img>
      </xsl:when>
      <xsl:when test=". = 'I'">
        <img align="top" src="/oMail/i/re_l.gif"/>
        <img src="/oMail/i/c.gif" height="1" width="5"/>
      </xsl:when>
      <xsl:otherwise>
        <img src="/oMail/i/c.gif" height="1" width="10"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="m_list" mode="mlist">
    <xsl:if test="/page/list_pos - show_res > 0">
      <tr>
        <td/>
        <td>
          <xsl:for-each select="../ftree/fnode">
            <xsl:choose>
              <xsl:when test=". = 'I'">
                <img align="top" src="/oMail/i/re_l.gif"/>
                <img src="/oMail/i/c.gif" height="1" width="5"/>
              </xsl:when>
              <xsl:when test=". = '.'">
                <img src="/oMail/i/c.gif" height="1" width="5"/>
              </xsl:when>
              <xsl:when test=". = 'F'">
                <img align="top" src="/oMail/i/re_l.gif"/>
                <img src="/oMail/i/c.gif" height="1" width="5"/>
              </xsl:when>
              <xsl:when test=". = '-'">
                <img src="/oMail/i/c.gif" height="1" width="5"/>
              </xsl:when>
            </xsl:choose>
          </xsl:for-each>
          <img align="top" src="/oMail/i/re_l.gif"/>
          <img src="/oMail/i/c.gif" height="1" width="10"/>
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">open.vsp</xsl:with-param>
            <xsl:with-param name="label">prev group</xsl:with-param>
            <xsl:with-param name="title">Previous group</xsl:with-param>
            <xsl:with-param name="params">op=<xsl:value-of select="prev_msg"/>,<xsl:value-of select="message[1]/position - 1"/></xsl:with-param>
            <xsl:with-param name="img">/oMail/i/arrow_up.gif</xsl:with-param>
          </xsl:call-template>
        </td>
      </tr>
    </xsl:if>
    <xsl:apply-templates select="message" mode="mlist"/>
    <xsl:if test="message[last()]/position != all_res">
      <tr>
        <td/>
        <td>
          <xsl:for-each select="../ftree/fnode">
            <xsl:choose>
              <xsl:when test=". = 'I'">
                <img align="top" src="/oMail/i/re_l.gif"/>
              </xsl:when>
              <xsl:when test=". = 'F'">
                <img align="top" src="/oMail/i/re_l.gif"/>
              </xsl:when>
            </xsl:choose>
            <img src="/oMail/i/c.gif" height="1" width="10"/>
          </xsl:for-each>
          <xsl:choose>
            <xsl:when test="count(../folders/folder) > 0">
              <img align="top" src="/oMail/i/re_l.gif"/>
              <img src="/oMail/i/c.gif" height="1" width="10"/>
            </xsl:when>
          </xsl:choose>
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">open.vsp</xsl:with-param>
            <xsl:with-param name="label">next group</xsl:with-param>
            <xsl:with-param name="title">Next group</xsl:with-param>
            <xsl:with-param name="params">op=<xsl:value-of select="next_msg"/>,<xsl:value-of select="message[last()]/position + 1"/></xsl:with-param>
            <xsl:with-param name="img">/oMail/i/arrow_down.gif</xsl:with-param>
          </xsl:call-template>
        </td>
      </tr>
    </xsl:if>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="message" mode="mlist">
    <xsl:choose>
      <xsl:when test="mstatus = 0">
        <xsl:variable name="op">_cl</xsl:variable>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="op">_o</xsl:variable>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:choose>
      <xsl:when test="position() != last()">
        <xsl:variable name="lm">_f</xsl:variable>
      </xsl:when>
      <xsl:otherwise>
        <xsl:choose>
          <xsl:when test="count(../../folders/folder) > 0">
            <xsl:variable name="lm">_f</xsl:variable>
          </xsl:when>
          <xsl:otherwise>
            <xsl:variable name="lm"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:variable name="last" select="last()"/>
    <xsl:variable name="position" select="position()"/>
    <xsl:variable name="subject_len" select="15 - ((../../level/@num) * 2)"/>
    <xsl:choose>
      <xsl:when test="string-length(subject) > 15">
        <xsl:variable name="subject" select="substring(subject,1,$subject_len)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="subject" select="subject"/>
      </xsl:otherwise>
    </xsl:choose>
    <tr>
      <td/>
      <td>
        <table border="0" cellpadding="0" cellspacing="0">
          <tr>
            <td>
              <xsl:apply-templates select="../../ftree/fnode" mode="msg">
                <xsl:with-param name="lm" select="concat($op,$lm)"/>
              </xsl:apply-templates>
            </td>
            <td>
              <xsl:choose>
                <xsl:when test="/page/message/msg_id != msg_id">
                  <xsl:call-template name="make_href">
                    <xsl:with-param name="url">open.vsp</xsl:with-param>
                    <xsl:with-param name="label"><xsl:value-of select="substring(subject,1,$subject_len)"/>...</xsl:with-param>
                    <xsl:with-param name="title">From: <xsl:value-of select="address/addres_list/from"/>/Subject: <xsl:value-of select="subject"/></xsl:with-param>
                    <xsl:with-param name="params">op=<xsl:value-of select="msg_id"/>,<xsl:value-of select="position"/></xsl:with-param>
                    <xsl:with-param name="class">n</xsl:with-param>
                  </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>
                  <font class="bc">
                    <font style="font-size:10px; background-color:#B0CDE4">
                      <u>
                        <xsl:value-of select="$subject"/>
                      </u>...</font>
                  </font>
                </xsl:otherwise>
              </xsl:choose>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </xsl:template>
  <!-- ====================================================================================== -->
  <xsl:template match="ftree/fnode" mode="msg">
    <xsl:param name="lm"/>
    <xsl:choose>
      <xsl:when test=". = 'F'">
        <img align="top" src="/oMail/i/re_l.gif" hspace="0" vspace="0"/>
        <img src="/oMail/i/c.gif" height="1" width="5" hspace="0" vspace="0"/>
        <img align="top" hspace="0" vspace="0">
          <xsl:attribute name="src">/oMail/i/msg_fld<xsl:value-of select="$lm"/>.gif</xsl:attribute>
        </img>
      </xsl:when>
      <xsl:when test=". = '-'">
        <img src="/oMail/i/c.gif" height="1" width="5"/>
        <img align="top">
          <xsl:attribute name="src">/oMail/i/msg_fld<xsl:value-of select="$lm"/>.gif</xsl:attribute>
        </img>
      </xsl:when>
      <xsl:when test=". = 'I'">
        <img align="top" src="/oMail/i/re_l.gif"/>
        <img src="/oMail/i/c.gif" height="1" width="5"/>
      </xsl:when>
      <xsl:otherwise>
        <img src="/oMail/i/c.gif" height="1" width="5"/>
      </xsl:otherwise>
    </xsl:choose>
    &nbsp;
  </xsl:template>
</xsl:stylesheet>
