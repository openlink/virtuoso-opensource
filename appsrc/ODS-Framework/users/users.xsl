<?xml version="1.0" encoding="utf-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2017 OpenLink Software
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
-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:mail="http://www.openlinksw.com/mail/">
  <xsl:output method="html" indent="yes" omit-xml-declaration="no" encoding="utf-8"/>

  <!-- ========================================================================== -->
  <xsl:template match="/">
    <div class="vcard">
      <xsl:call-template name="personal"/>
      <xsl:call-template name="rsa"/>
      <xsl:call-template name="address"/>
      <xsl:call-template name="contact"/>
      <xsl:call-template name="sameAs"/>
      <xsl:call-template name="interest"/>
      <xsl:call-template name="topicInterest"/>
      <xsl:call-template name="made"/>
      <xsl:call-template name="knows"/>
    </div>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="personal">
    <div>
      <div class="PF_header">Personal Data</div>
      <table class="PF_form">
        <xsl:apply-templates select="user/nick"/>
        <xsl:apply-templates select="user/depiction"/>
        <xsl:apply-templates select="user/title"/>
        <xsl:apply-templates select="user/gender"/>
        <xsl:apply-templates select="user/name"/>
        <xsl:apply-templates select="user/firstName"/>
        <xsl:apply-templates select="user/family_name"/>
        <xsl:apply-templates select="user/birthday"/>
      </table>
    </div>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="rsa">
    <xsl:if test="user/rsaPublicKey">
    <div>
      <div class="PF_header">RSA Public Key</div>
      <table class="PF_form">
        <xsl:apply-templates select="user/iri"/>
          <xsl:apply-templates select="user/rsaPublicKey"/>
      </table>
    </div>
    </xsl:if>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="address">
    <div class="adr">
      <div class="PF_header">Address Info</div>
      <table class="PF_form">
        <xsl:apply-templates select="user/country"/>
        <xsl:apply-templates select="user/region"/>
        <xsl:apply-templates select="user/locality"/>
        <xsl:apply-templates select="user/pobox"/>
        <xsl:apply-templates select="user/street"/>
        <xsl:apply-templates select="user/extadd"/>
      </table>
    </div>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="contact">
    <div>
      <div class="PF_header">Contact Info</div>
      <table class="PF_form">
        <xsl:apply-templates select="user/homepage"/>
        <xsl:apply-templates select="user/qrcode"/>
        <xsl:apply-templates select="user/phone"/>
        <xsl:apply-templates select="user/mbox"/>
        <xsl:apply-templates select="user/icqChatID"/>
        <xsl:apply-templates select="user/msnChatID"/>
        <xsl:apply-templates select="user/aimChatID"/>
        <xsl:apply-templates select="user/yahooChatID"/>
        <xsl:apply-templates select="user/skypeChatID"/>
        <xsl:apply-templates select="user/onlineAccount"/>
      </table>
    </div>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="sameAs">
    <xsl:if test="user/sameAs">
      <div>
        <div class="PF_header">Other WebIDs</div>
        <table class="PF_form">
          <xsl:apply-templates select="user/sameAs"/>
        </table>
      </div>
    </xsl:if>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="interest">
    <xsl:if test="user/interest">
      <div>
        <div class="PF_header">Interests</div>
        <table class="PF_form">
          <xsl:apply-templates select="user/interest"/>
        </table>
      </div>
    </xsl:if>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="topicInterest">
    <xsl:if test="user/topicInterest">
      <div>
        <div class="PF_header">Topic of Interests</div>
        <table class="PF_form">
          <xsl:apply-templates select="user/topicInterest"/>
        </table>
      </div>
    </xsl:if>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="made">
    <xsl:if test="user/made">
      <div>
        <div class="PF_header">Made</div>
        <table class="PF_form">
          <xsl:apply-templates select="user/made"/>
        </table>
      </div>
    </xsl:if>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="knows">
    <xsl:if test="user/knows">
      <div>
        <div class="PF_header">Knows</div>
        <table class="PF_form">
          <xsl:apply-templates select="user/knows"/>
        </table>
      </div>
    </xsl:if>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="profileLine">
    <xsl:param name="label"/>
    <xsl:param name="value"/>
    <xsl:param name="RDFa"/>
    <xsl:if test="$value != ''">
    <tr>
        <th>
          <xsl:value-of select="$label"/>
        </th>
        <td>
          <xsl:choose>
            <xsl:when test="$RDFa">
              <span>
                <xsl:attribute name="class">
                  <xsl:value-of select="$RDFa"/>
                </xsl:attribute>
                <xsl:value-of select="$value"/>
              </span>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="$value"/>
            </xsl:otherwise>
          </xsl:choose>
        </td>
    </tr>
    </xsl:if>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="profileLinePhoto">
    <xsl:param name="label"/>
    <xsl:param name="value"/>
    <tr>
      <th><xsl:value-of select="$label"/></th>
      <td>
        <img border="0" width="64" class="resize">
          <xsl:attribute name="src">
            <xsl:value-of select="$value"/>
          </xsl:attribute>
        </img>
      </td>
    </tr>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="name">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label">Name</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
      <xsl:with-param name="RDFa">fn</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="depiction">
    <xsl:call-template name="profileLinePhoto">
      <xsl:with-param name="label">Photo</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="title">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label">Title</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
      <xsl:with-param name="RDFa">honorific-prefix</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="gender">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label">Gender</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="nick">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label">Nick</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="firstName">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label">First Name</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
       <xsl:with-param name="RDFa">given-name</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="family_name">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label">Family Name</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
      <xsl:with-param name="RDFa">family-name</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="birthday">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label">Birthday</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
      <xsl:with-param name="RDFa">bday</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="iri">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label">WebID</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="rsaModulus">
    <tr>
      <th>Modulus (hexadecimal)</th>
      <td style="font-family: monospace;">
        <xsl:call-template name="showHex">
          <xsl:with-param name="offset" select="1" />
          <xsl:with-param name="value" select="." />
        </xsl:call-template>
      </td>
    </tr>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="rsaPublicExponent">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label">Modulus (decimal)</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="country">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label">Country</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
      <xsl:with-param name="RDFa">country-name</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="region">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label">Region</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
      <xsl:with-param name="RDFa">region</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="locality">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label">City</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
      <xsl:with-param name="RDFa">locality</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="pobox">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label">PO Box</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
      <xsl:with-param name="RDFa">postal-code</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="street">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label">Address</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
      <xsl:with-param name="RDFa">street-address</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="extadd">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label">Address</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="homepage">
    <tr>
      <th>Homepage</th>
      <td>
        <a>
          <xsl:attribute name="href">
            <xsl:value-of select="."/>
          </xsl:attribute>
          <xsl:value-of select="."/>
        </a>
      </td>
    </tr>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="qrcode">
    <tr>
      <th></th>
      <td>
        <img>
          <xsl:attribute name="src">data:image/jpg;base64,<xsl:value-of select="."/></xsl:attribute>
        </img>
      </td>
    </tr>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="phone">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label">Phone</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
      <xsl:with-param name="RDFa">tel</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="mbox">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label">Mail</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
      <xsl:with-param name="RDFa">email</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="icqChatID">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label">ICQ</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="msnChatID">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label">MSN</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="aimChatID">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label">AIM</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="yahooChatID">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label">Yahoo</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="skypeChatID">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label">Skype</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="onlineAccount">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label"><xsl:value-of select="label"/></xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="url"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="rsaPublicKey">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label">Key No</xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="rsaNo+1"/></xsl:with-param>
    </xsl:call-template>
    <xsl:apply-templates select="rsaPublicExponent"/>
    <xsl:apply-templates select="rsaModulus"/>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="interest|topicInterest">
    <tr>
      <th></th>
      <td>
        <xsl:choose>
          <xsl:when test="url">
            <a>
              <xsl:attribute name="href">
                <xsl:value-of select="url"/>
              </xsl:attribute>
              <xsl:choose>
                <xsl:when test="label">
                  <xsl:value-of select="label"/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:value-of select="url"/>
                </xsl:otherwise>
              </xsl:choose>
            </a>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="label"/>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="knows">
    <tr>
      <th>Person</th>
      <td>
        <xsl:if test="nick">
          <b>Name</b>: <xsl:value-of select="nick"/><div></div>
        </xsl:if>
        <xsl:if test="iri">
          <b>WebID</b>: <a>
            <xsl:attribute name="href">
              <xsl:value-of select="iri"/>
            </xsl:attribute>
            <xsl:value-of select="iri"/>
          </a><div></div>
        </xsl:if>
        <xsl:if test="seeAlso">
          <b>SeeAlso</b>:  <a>
            <xsl:attribute name="href">
              <xsl:value-of select="seeAlso"/>
            </xsl:attribute>
            <xsl:value-of select="seeAlso"/>
          </a>
        </xsl:if>
      </td>
    </tr>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="sameAs|made">
    <tr>
      <th></th>
      <td>
        <a>
          <xsl:attribute name="href">
            <xsl:value-of select="."/>
          </xsl:attribute>
          <xsl:value-of select="."/>
        </a>
      </td>
    </tr>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template match="*">
    <xsl:call-template name="profileLine">
      <xsl:with-param name="label"><xsl:value-of select ="local-name()"/></xsl:with-param>
      <xsl:with-param name="value"><xsl:value-of select="."/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- ========================================================================== -->
  <xsl:template name="showHex">
    <xsl:param name="offset" />
    <xsl:param name="value" />
    <xsl:if test="$offset &lt; string-length($value)">
      <xsl:if test="(($offset mod 32) = 1) and ($offset &gt; 1)">
        <div></div>
      </xsl:if>
      <xsl:value-of select="substring($value, $offset, 2)"/><xsl:text> </xsl:text>
      <xsl:call-template name="showHex">
        <xsl:with-param name="offset" select="$offset+2" />
        <xsl:with-param name="value"  select="$value" />
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <!--========================================================================-->
</xsl:stylesheet>
