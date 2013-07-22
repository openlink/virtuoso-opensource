<?xml version="1.0"?>
<!--
 -  
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2013 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:bpel="http://schemas.xmlsoap.org/ws/2003/03/business-process/" xmlns:virt="http://www.openlinksw.com/virtuoso/xslt" xmlns:bpelv="http://www.openlinksw.com/virtuoso/bpel">
  <xsl:output method="text" omit-xml-declaration="yes" indent="yes"/>
  <xsl:include href="common.xsl"/>
  <xsl:variable name="script_id" select="$id"/>
  <xsl:variable name="inst_id" select="$nid"/>
  <xsl:variable name="activs" select="$activs"/>
  <xsl:variable name="links" select="$links"/>
  <xsl:param name="is_step"/>
  <!-- all elements making a node -->
  <xsl:variable name="nodes" select="
    //bpel:receive|
    //bpel:reply|
    //bpel:invoke|
    //bpel:assign/copy|
    //bpel:throw|
    //bpel:terminate|
    //bpel:wait|
    //bpel:empty|
    //bpel:sequence|
    //bpel:switch|
    //bpel:case|
    //bpel:otherwise|
    //bpel:while|
    //bpel:pick|
    //bpel:scope|
    //bpel:flow|
    //bpel:link|
    //bpel:compensate|
    //bpel:compensationHandler|
    //bpel:faultHandlers|
    //bpel:catch|
    //bpel:catchAll|
    //bpel:onMessage|
    //bpel:onAlarm|
    //bpelv:exec"/>
  <xsl:variable name="act_id" select="0"/>
<!-- ================================================================================================================= -->
  <xsl:template match="/">
    <table width="100%" border="0" cellpadding="0" cellspacing="0" id="content">
      <tr>
       <th class="info">Status for process
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">process.vspx</xsl:with-param>
          <xsl:with-param name="label"><xsl:value-of select="$nam"/></xsl:with-param>
          <xsl:with-param name="class">m_y</xsl:with-param>
          <xsl:with-param name="params">id=<xsl:value-of select="$script_id"/></xsl:with-param>
        </xsl:call-template>
        with instance id=<xsl:value-of select="$nid"/></th>
      </tr>
      <tr>
        <td>
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">help.vspx</xsl:with-param>
            <xsl:with-param name="label">Help</xsl:with-param>
            <xsl:with-param name="img">i/help_24.gif</xsl:with-param>
            <xsl:with-param name="params">id=process_status</xsl:with-param>
            <xsl:with-param name="target">'help-popup'</xsl:with-param>
          </xsl:call-template>
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">help.vspx</xsl:with-param>
            <xsl:with-param name="label"> Help</xsl:with-param>
            <xsl:with-param name="params">id=process_status</xsl:with-param>
            <xsl:with-param name="target">'help-popup'</xsl:with-param>
          </xsl:call-template>
        </td>
      </tr>
      <xsl:choose>
        <xsl:when test="string-length($error)>0"><tr><td><font color="Red">Error: <xsl:value-of select="$error"/></font></td></tr></xsl:when>
      </xsl:choose>
      <xsl:if test="$is_step = 1">
      <form name="form2" method="post" action="status.vspx?sid={$sid}&amp;realm={$realm}&amp;id={$id}&amp;nid={$nid}">
        <tr>
          <td>
            <input type="submit" value="Step" class="m_e" name="step"/>
          </td>
        </tr>
      </form>
      </xsl:if>
      <xsl:apply-templates select="*"/>
      <form name="form1" method="post">
        <tr>
          <td>
            <xsl:call-template name="make_href">
              <xsl:with-param name="url">process.vspx</xsl:with-param>
              <xsl:with-param name="label">Back</xsl:with-param>
              <xsl:with-param name="params">id=<xsl:value-of select="$script_id"/></xsl:with-param>
              <xsl:with-param name="img">i/back_16.png</xsl:with-param>
            </xsl:call-template>
            <xsl:call-template name="make_href">
              <xsl:with-param name="url">process.vspx</xsl:with-param>
              <xsl:with-param name="label">Back</xsl:with-param>
              <xsl:with-param name="params">id=<xsl:value-of select="$script_id"/></xsl:with-param>
            </xsl:call-template>
            &nbsp;<input type="submit" value="Delete Instance" class="m_e" name="delinst"/>
          </td>
        </tr>
      </form>
    </table>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:source">
    <xsl:param name="cnt"/>
    <xsl:variable name="bl1" select="virt:get_link(@linkName)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl1='1'">known 'true'</xsl:when>
        <xsl:otherwise>known 'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="$cnt"/>
          </xsl:with-param>
        </xsl:call-template>
       <font color="Green">Source</font>
       <i>&nbsp;<xsl:value-of select="$blt"/>&nbsp;</i>name='<xsl:value-of select="@linkName"/>'
      </td>
   </tr>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:target">
    <xsl:param name="cnt"/>
    <xsl:variable name="bl1" select="virt:get_link(@linkName)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl1='1'">known 'true'</xsl:when>
        <xsl:otherwise>known 'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="$cnt"/>
          </xsl:with-param>
        </xsl:call-template>
       <font color="Green">Target</font>
       <i>&nbsp;<xsl:value-of select="$blt"/>&nbsp;</i>name='<xsl:value-of select="@linkName"/>'
      </td>
    </tr>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:sequence">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'sequence')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'">
            <font color="Green"><xsl:value-of select="virt:xpath_eval1('type',$xml)"/></font>
            <i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/>
            </i>
          </xsl:when>
          <xsl:otherwise>
            <font color="Red">Sequence</font>
            <i>&nbsp;unknown</i>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
    <xsl:if test="$bl='1' and $vl= '1'">
      <xsl:apply-templates select="*">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml) + 5"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:invoke">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'invoke')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td nowrap="nowrap"><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'">
            <font color="Green"><xsl:value-of select="virt:xpath_eval1('type',$xml)"/></font>
            <i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/></i> |
            partnerlink='<xsl:value-of select="virt:xpath_eval1('plink',$xml)"/>' |
            port=<xsl:value-of select="virt:xpath_eval1('port',$xml)"/> |
            operation='<xsl:value-of select="virt:xpath_eval1('oper',$xml)"/>' |
            inputVar=<xsl:call-template name="make_href">
              <xsl:with-param name="url">view.vspx</xsl:with-param>
              <xsl:with-param name="label"><xsl:value-of select="virt:xpath_eval1('input',$xml)"/></xsl:with-param>
              <xsl:with-param name="target">'help-popup'</xsl:with-param>
              <xsl:with-param name="params">mode=show&amp;id=<xsl:value-of select="$inst_id"/>&amp;v=<xsl:value-of select="virt:xpath_eval1('input',$xml)"/></xsl:with-param>
            </xsl:call-template>
            <xsl:choose>
              <xsl:when test="self::node()/@outputVariable">|
                outputVar=<xsl:call-template name="make_href">
                  <xsl:with-param name="url">view.vspx</xsl:with-param>
                  <xsl:with-param name="label"><xsl:value-of select="virt:xpath_eval1('output',$xml)"/></xsl:with-param>
                  <xsl:with-param name="target">'help-popup'</xsl:with-param>
                  <xsl:with-param name="params">mode=show&amp;id=<xsl:value-of select="$inst_id"/>&amp;v=<xsl:value-of select="virt:xpath_eval1('output',$xml)"/></xsl:with-param>
                </xsl:call-template>
              </xsl:when>
            </xsl:choose>
            <!--<xsl:for-each select="bpel:correlations/bpel:correlation[string-length(@set) != 0 and string-length(@initiate) != 0]">
              | correlation: set='<xsl:value-of select="@set"/>' initiate='<xsl:value-of select="@initiate"/>'
            </xsl:for-each>|-->
          </xsl:when>
          <xsl:otherwise>
            <font color="Red">Invoke</font>
            <i>&nbsp;unknown</i>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
    <xsl:if test="$bl='1' and $vl= '1'">
      <xsl:apply-templates select="*">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml) + 5"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:receive">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'receive')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td nowrap="nowrap"><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'">
            <font color="Green"><xsl:value-of select="virt:xpath_eval1('type',$xml)"/></font>
            <i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/></i> |
            name='<xsl:value-of select="virt:xpath_eval1('name',$xml)"/>'
            partnerLink='<xsl:value-of select="virt:xpath_eval1('plink',$xml)"/>'
            portType=<xsl:value-of select="virt:xpath_eval1('port',$xml)"/>
            operation='<xsl:value-of select="virt:xpath_eval1('oper',$xml)"/>'
            variable=
            <xsl:call-template name="make_href">
              <xsl:with-param name="url">view.vspx</xsl:with-param>
              <xsl:with-param name="label"><xsl:value-of select="virt:xpath_eval1('var',$xml)"/></xsl:with-param>
              <xsl:with-param name="target">'help-popup'</xsl:with-param>
              <xsl:with-param name="params">mode=show&amp;id=<xsl:value-of select="$inst_id"/>&amp;v=<xsl:value-of select="virt:xpath_eval1('var',$xml)"/></xsl:with-param>
            </xsl:call-template>
            createIntance=<xsl:value-of select="virt:xpath_eval1('ins',$xml)"/>
            oneWay=<xsl:value-of select="virt:xpath_eval1('way',$xml)"/>
            <!--<xsl:for-each select="bpel:correlations/bpel:correlation[string-length(@set) != 0 and string-length(@initiate) != 0]">
                | correlation:
	        set='<xsl:value-of select="@set"/>'
	        initiate='<xsl:value-of select="@initiate"/>'
            </xsl:for-each>
            |-->
          </xsl:when>
          <xsl:otherwise>
            <font color="Red">Receive</font>
            <i>&nbsp;unknown</i>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
    <xsl:if test="$bl='1' and $vl= '1'">
      <xsl:apply-templates select="*">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml) + 5"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:reply">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'reply')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'">
            <font color="Green"><xsl:value-of select="virt:xpath_eval1('type',$xml)"/></font>
            <i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/></i> |
            name='<xsl:value-of select="virt:xpath_eval1('name',$xml)"/>'
            partnerLink=<xsl:value-of select="virt:xpath_eval1('plink',$xml)"/>
            portType=<xsl:value-of select="virt:xpath_eval1('port',$xml)"/>
            operation=<xsl:value-of select="virt:xpath_eval1('oper',$xml)"/>
            variable=
            <xsl:call-template name="make_href">
              <xsl:with-param name="url">view.vspx</xsl:with-param>
              <xsl:with-param name="label"><xsl:value-of select="virt:xpath_eval1('var',$xml)"/></xsl:with-param>
              <xsl:with-param name="target">'help-popup'</xsl:with-param>
              <xsl:with-param name="params">mode=show&amp;id=<xsl:value-of select="$inst_id"/>&amp;v=<xsl:value-of select="virt:xpath_eval1('var',$xml)"/></xsl:with-param>
            </xsl:call-template>
            <!--<xsl:for-each select="bpel:correlations/bpel:correlation[string-length(@set) != 0 and string-length(@initiate) != 0]">
              | correlation:
	      set='<xsl:value-of select="@set"/>'
	      initiate='<xsl:value-of select="@initiate"/>'
            </xsl:for-each>
            |-->
          </xsl:when>
          <xsl:otherwise>
            <font color="Red">Reply</font>
            <i>&nbsp;unknown</i>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
    <xsl:if test="$bl='1' and $vl= '1'">
      <xsl:apply-templates select="*">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml) + 5"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:link">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'link')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'"><font color="Green"><xsl:value-of select="virt:xpath_eval1('type',$xml)"/></font><i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/></i></xsl:when>
          <xsl:otherwise>
            <font color="Red">Link</font>
            <i>&nbsp;unknown</i>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
    <xsl:if test="$bl='1' and $vl= '1'">
      <xsl:apply-templates select="*">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml) + 5"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:empty">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'empty')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'">
            <font color="Green"><xsl:value-of select="virt:xpath_eval1('type',$xml)"/></font>
            <i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/></i>
          </xsl:when>
          <xsl:otherwise>
            <font color="Red">Empty</font>
            <i>&nbsp;unknown</i>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:throw">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'throw')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'"><font color="Green"><xsl:value-of select="virt:xpath_eval1('type',$xml)"/></font><i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/>&nbsp;</i>
            <xsl:value-of select="virt:xpath_eval1('fault',$xml)"/>
          </xsl:when>
          <xsl:otherwise>
            <font color="Red">Throw</font>
            <i>&nbsp;unknown</i>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
    <xsl:if test="$bl='1' and $vl= '1'">
      <xsl:apply-templates select="*">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml) + 5"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="@*" mode="escape">
    <xsl:value-of select="translate (., &quot;&apos;&quot;, '&quot;')"/>
  </xsl:template>
  <xsl:template match="bpel:assign">
    <xsl:for-each select="bpel:copy">
      <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'copy')"/>
      <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
      <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
      <xsl:variable name="blt">
        <xsl:choose>
          <xsl:when test="$bl='1'">'true'</xsl:when>
          <xsl:otherwise>'false'</xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <tr>
        <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
          <xsl:call-template name="nbsp">
            <xsl:with-param name="count">
              <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
            </xsl:with-param>
          </xsl:call-template>
          <xsl:choose>
            <xsl:when test="$vl = '1'"><font color="Green">Assign</font><i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/>
              </i> | from:
              <xsl:choose>
                <xsl:when test="from/@variable and from/@part">
                  <xsl:variable name="data" select="virt:get_assign($script_id,@internal_id,1)"/>
                  <xsl:call-template name="make_href">
                    <xsl:with-param name="url">view.vspx</xsl:with-param>
                    <xsl:with-param name="label"><xsl:value-of select="virt:xpath_eval1('var',$data)"/></xsl:with-param>
                    <xsl:with-param name="target">'help-popup'</xsl:with-param>
                    <xsl:with-param name="params">mode=show&amp;id=<xsl:value-of select="$inst_id"/>&amp;v=<xsl:value-of select="virt:xpath_eval1('var',$data)"/></xsl:with-param>
                  </xsl:call-template>
                  part='<xsl:value-of select="virt:xpath_eval1('part',$data)"/>'
                  <xsl:choose>
                    <xsl:when test="(virt:xpath_eval1('query',$data))!=''">query="<xsl:value-of select="virt:xpath_eval1('query',$data)"/>"</xsl:when>
                  </xsl:choose>
                </xsl:when>
                <xsl:when test="from/@variable and from/@property">
                  <xsl:variable name="data" select="virt:get_assign($script_id,@internal_id,1)"/>
                  <xsl:call-template name="make_href">
                    <xsl:with-param name="url">view.vspx</xsl:with-param>
                    <xsl:with-param name="label"><xsl:value-of select="virt:xpath_eval1('var',$data)"/></xsl:with-param>
                    <xsl:with-param name="target">'help-popup'</xsl:with-param>
                    <xsl:with-param name="params">mode=show&amp;id=<xsl:value-of select="$inst_id"/>&amp;v=<xsl:value-of select="virt:xpath_eval1('var',$data)"/></xsl:with-param>
                  </xsl:call-template>
                  property=<xsl:value-of select="virt:xpath_eval1('property',$data)"/>
                </xsl:when>
                <xsl:when test="from/@partnerLink and from/@endpointReference">
                  <xsl:variable name="data" select="virt:get_assign($script_id,@internal_id,1)"/>
                  plink=<xsl:value-of select="virt:xpath_eval1('pl',$data)"/>
                  endpoint=<xsl:value-of select="virt:xpath_eval1('ep',$data)"/>
                </xsl:when>
                <xsl:when test="from/@expression">
                  <xsl:variable name="data" select="virt:get_assign($script_id,@internal_id,1)"/>
                  expression=<xsl:value-of select="virt:xpath_eval1('expr',$data)"/>
                </xsl:when>
                <xsl:when test="from">
                  <!-- !!!here to be shown the text as xml!!! -->
                  <xsl:variable name="data" select="virt:get_assign($script_id,@internal_id,1)"/>
                  <xsl:call-template name="make_href">
                    <xsl:with-param name="url">view.vspx</xsl:with-param>
                    <xsl:with-param name="label">text</xsl:with-param>
                    <xsl:with-param name="target">'help-popup'</xsl:with-param>
                    <xsl:with-param name="params">mode=show&amp;txt=1&amp;id=<xsl:value-of select="$script_id"/>&amp;in=<xsl:value-of select="@internal_id"/></xsl:with-param>
                  </xsl:call-template>
                </xsl:when>
              </xsl:choose>
              | to:
              <xsl:choose>
                <xsl:when test="to/@variable and to/@part">
                  <xsl:variable name="data" select="virt:get_assign($script_id,@internal_id,2)"/>
                  <xsl:call-template name="make_href">
                    <xsl:with-param name="url">view.vspx</xsl:with-param>
                    <xsl:with-param name="label"><xsl:value-of select="virt:xpath_eval1('var',$data)"/></xsl:with-param>
                    <xsl:with-param name="target">'help-popup'</xsl:with-param>
                    <xsl:with-param name="params">mode=show&amp;id=<xsl:value-of select="$inst_id"/>&amp;v=<xsl:value-of select="virt:xpath_eval1('var',$data)"/></xsl:with-param>
                  </xsl:call-template>
                  part='<xsl:value-of select="virt:xpath_eval1('part',$data)"/>'
                  <xsl:choose>
                    <xsl:when test="(virt:xpath_eval1('query',$data))!=''">query="<xsl:value-of select="virt:xpath_eval1('query',$data)"/>"</xsl:when>
                  </xsl:choose>
                </xsl:when>
                <xsl:when test="to/@variable and to/@property">
                  <xsl:variable name="data" select="virt:get_assign($script_id,@internal_id,2)"/>
                  <xsl:call-template name="make_href">
                    <xsl:with-param name="url">view.vspx</xsl:with-param>
                    <xsl:with-param name="label"><xsl:value-of select="virt:xpath_eval1('var',$data)"/></xsl:with-param>
                    <xsl:with-param name="target">'help-popup'</xsl:with-param>
                    <xsl:with-param name="params">mode=show&amp;id=<xsl:value-of select="$inst_id"/>&amp;v=<xsl:value-of select="virt:xpath_eval1('var',$data)"/></xsl:with-param>
                  </xsl:call-template>
                  property=<xsl:value-of select="virt:xpath_eval1('property',$data)"/>
                </xsl:when>
                <xsl:when test="to/@partnerLink">
                  <xsl:variable name="data" select="virt:get_assign($script_id,@internal_id,2)"/>
                  plink=<xsl:value-of select="virt:xpath_eval1('pl',$data)"/>
                </xsl:when>
                <xsl:when test="to/@variable">
                  <xsl:variable name="data" select="virt:get_assign($script_id,@internal_id,2)"/>
                  variable=<xsl:value-of select="virt:xpath_eval1('var',$data)"/>
                  <xsl:choose>
                    <xsl:when test="(virt:xpath_eval1('query',$data))!=''">query=<xsl:value-of select="virt:xpath_eval1('query',$data)"/></xsl:when>
                  </xsl:choose>
                </xsl:when>
              </xsl:choose>
              |
            </xsl:when>
            <xsl:otherwise>
              <font color="Red">Assign</font>
              <i>&nbsp;unknown</i>
            </xsl:otherwise>
          </xsl:choose>
        </td>
      </tr>
    </xsl:for-each>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:compensationHandler">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'comphandler')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'">
            <font color="Green"><xsl:value-of select="virt:xpath_eval1('type',$xml)"/></font>
            <i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/>
            </i>
          </xsl:when>
          <xsl:otherwise>
            <font color="Red">compensationHandler </font>
            <i>&nbsp;unknown</i>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
    <xsl:if test="$bl='1' and $vl= '1'">
      <xsl:apply-templates select="*">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml) + 5"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:faultHandlers">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'fault')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'">
            <font color="Green"><xsl:value-of select="virt:xpath_eval1('type',$xml)"/></font>
            <i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/></i>
          </xsl:when>
          <xsl:otherwise>
            <font color="Red">faultHandlers</font><i>&nbsp;unknown</i>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
    <xsl:if test="$bl='1' and $vl= '1'">
      <xsl:apply-templates select="bpel:catch"/>
        <xsl:apply-templates select="bpel:catchAll"/>
      <xsl:if test="not (bpel:catchAll)">
        <xsl:call-template name="catchAllImplicit"/>
      </xsl:if>
      <xsl:apply-templates select="bpel:source">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml)"/>
      </xsl:apply-templates>
       <xsl:apply-templates select="bpel:target">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml)"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:catch">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'catch')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
   <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'">
            <font color="Green"><xsl:value-of select="virt:xpath_eval1('type',$xml)"/></font>
            <i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/></i>
            inputVar=<xsl:call-template name="make_href">
              <xsl:with-param name="url">view.vspx</xsl:with-param>
              <xsl:with-param name="label"><xsl:value-of select="virt:xpath_eval1('input',$xml)"/></xsl:with-param>
              <xsl:with-param name="target">'help-popup'</xsl:with-param>
              <xsl:with-param name="params">mode=show&amp;id=<xsl:value-of select="$inst_id"/>&amp;v=<xsl:value-of select="virt:xpath_eval1('input',$xml)"/></xsl:with-param>
            </xsl:call-template>
            fault=<xsl:value-of select="virt:xpath_eval1('fault',$xml)"/>
          </xsl:when>
          <xsl:otherwise>
            <font color="Red">Catch</font><i>&nbsp;unknown</i>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
    <xsl:if test="$bl='1' and $vl= '1'">
      <xsl:apply-templates select="*">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml) + 5"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:catchAll">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'catch')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'">
            <font color="Green">CatchAll</font>
            <i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/></i>
            <xsl:choose>
              <xsl:when test="$bl='1'">
                 inputVar=<xsl:call-template name="make_href">
                   <xsl:with-param name="url">view.vspx</xsl:with-param>
                   <xsl:with-param name="label"><xsl:value-of select="virt:xpath_eval1('input',$xml)"/></xsl:with-param>
                   <xsl:with-param name="target">'help-popup'</xsl:with-param>
                   <xsl:with-param name="params">mode=show&amp;id=<xsl:value-of select="$inst_id"/>&amp;v=<xsl:value-of select="virt:xpath_eval1('input',$xml)"/></xsl:with-param>
                 </xsl:call-template>
                 fault=<xsl:value-of select="virt:xpath_eval1('fault',$xml)"/>
              </xsl:when>
            </xsl:choose>
          </xsl:when>
          <xsl:otherwise>
            <font color="Red">CatchAll</font><i>&nbsp;unknown</i>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
    <xsl:if test="$bl='1' and $vl= '1'">
      <xsl:apply-templates select="*">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml) + 5"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template name="catchAllImplicit">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'catch')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'">
            <font color="Green">catchAllImplicit</font>
            <i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/></i>
            <xsl:choose>
              <xsl:when test="$bl='1'">
                 inputVar=<xsl:call-template name="make_href">
                   <xsl:with-param name="url">view.vspx</xsl:with-param>
                   <xsl:with-param name="label"><xsl:value-of select="virt:xpath_eval1('input',$xml)"/></xsl:with-param>
                   <xsl:with-param name="target">'help-popup'</xsl:with-param>
                   <xsl:with-param name="params">mode=show&amp;id=<xsl:value-of select="$inst_id"/>&amp;v=<xsl:value-of select="virt:xpath_eval1('input',$xml)"/></xsl:with-param>
                 </xsl:call-template>
                 fault=<xsl:value-of select="virt:xpath_eval1('fault',$xml)"/>
              </xsl:when>
            </xsl:choose>
          </xsl:when>
          <xsl:otherwise>
            <font color="Red">catchAllImplicit</font><i>&nbsp;unknown</i>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
    <xsl:if test="$bl='1' and $vl= '1'">
      <xsl:apply-templates select="*">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml) + 5"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:scope">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'scope')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="comp" select="count(//bpel:compensationHandler)"/>
    <tr>
      <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'"><font color="Green"><xsl:value-of select="virt:xpath_eval1('type',$xml)"/></font>
            <i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/></i>
            CompensationHandlers=<xsl:value-of select="$comp"/>
            <xsl:choose>
              <xsl:when test="@name">
	        name='<xsl:value-of select="virt:xpath_eval1('name',$xml)"/>'
              </xsl:when>
            </xsl:choose>
          </xsl:when>
          <xsl:otherwise>
            <font color="Red">Scope</font>
            <i>&nbsp;unknown</i>
            CompensationHandlers=<xsl:value-of select="$comp"/>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
    <xsl:if test="$bl='1' and $vl= '1'">
      <xsl:apply-templates select="bpel:faultHandlers"/>
      <xsl:apply-templates select="* [ name() != 'http://schemas.xmlsoap.org/ws/2003/03/business-process/:faultHandlers' and name() != 'http://schemas.xmlsoap.org/ws/2003/03/business-process/:compensationHandler' ] "/>
      <xsl:apply-templates select="bpel:compensationHandler"/>
      <xsl:apply-templates select="bpel:source">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml)"/>
      </xsl:apply-templates>
       <xsl:apply-templates select="bpel:target">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml)"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:correlations"/>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:correlation"/>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:flow">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'flow')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'"><font color="Green"><xsl:value-of select="virt:xpath_eval1('type',$xml)"/></font><i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/>
            </i>
          </xsl:when>
          <xsl:otherwise>
            <font color="Red">Flow</font>
            <i>&nbsp;unknown</i>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
    <xsl:if test="$bl='1' and $vl= '1'">
      <xsl:apply-templates select="*">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml) + 5"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:pick">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'pick')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'"><font color="Green"><xsl:value-of select="virt:xpath_eval1('type',$xml)"/></font><i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/></i></xsl:when>
          <xsl:otherwise>
            <font color="Red">Pick</font>
            <i>&nbsp;unknown</i>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
    <xsl:if test="$bl='1' and $vl= '1'">
      <xsl:apply-templates select="*">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml) + 5"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:onMessage">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'onmessage')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'"><font color="Green"><xsl:value-of select="virt:xpath_eval1('type',$xml)"/></font><i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/></i>
            partnerlink='<xsl:value-of select="virt:xpath_eval1('plink',$xml)"/>' |
            port=<xsl:value-of select="virt:xpath_eval1('port',$xml)"/> |
            operation='<xsl:value-of select="virt:xpath_eval1('oper',$xml)"/>' |
            variable=<xsl:call-template name="make_href">
              <xsl:with-param name="url">view.vspx</xsl:with-param>
              <xsl:with-param name="label"><xsl:value-of select="virt:xpath_eval1('input',$xml)"/></xsl:with-param>
              <xsl:with-param name="target">'help-popup'</xsl:with-param>
              <xsl:with-param name="params">mode=show&amp;id=<xsl:value-of select="$inst_id"/>&amp;v=<xsl:value-of select="virt:xpath_eval1('input',$xml)"/></xsl:with-param>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <font color="Red">onMessage</font>
            <i>&nbsp;unknown</i>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
    <xsl:if test="$bl='1' and $vl= '1'">
      <xsl:apply-templates select="*">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml) + 5"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:onAlarm">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'onalarm')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'"><font color="Green"><xsl:value-of select="virt:xpath_eval1('type',$xml)"/></font><i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/></i>
           | for='<xsl:value-of select="virt:xpath_eval1('for',$xml)"/>'
           | until='<xsl:value-of select="virt:xpath_eval1('until',$xml)"/>'
          </xsl:when>
          <xsl:otherwise>
            <font color="Red">onAlarm</font>
            <i>&nbsp;unknown</i>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
    <xsl:if test="$bl='1' and $vl= '1'">
      <xsl:apply-templates select="*">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml) + 5"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:terminate">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'terminate')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'"><font color="Green"><xsl:value-of select="virt:xpath_eval1('type',$xml)"/></font><i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/></i></xsl:when>
          <xsl:otherwise>
            <font color="Red">terminate</font>
            <i>&nbsp;unknown</i>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
    <xsl:if test="$bl='1' and $vl= '1'">
      <xsl:apply-templates select="*">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml) + 5"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:compensate">
    <!--<tr><td>compensate</td></tr>-->
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'compensate')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'">
            <font color="Green"><xsl:value-of select="virt:xpath_eval1('type',$xml)"/></font>
            <i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/></i>
            scope='<xsl:value-of select="virt:xpath_eval1('name',$xml)"/>'
          </xsl:when>
          <xsl:otherwise>
            <font color="Red">Compensate</font>
            <i>&nbsp;unknown</i>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
    <xsl:if test="$bl='1' and $vl= '1'">
      <xsl:apply-templates select="*">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml) + 5"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:switch">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'switch')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'"><font color="Green"><xsl:value-of select="virt:xpath_eval1('type',$xml)"/></font><i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/></i></xsl:when>
          <xsl:otherwise>
            <font color="Red">Switch</font>
            <i>&nbsp;unknown</i>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
    <xsl:if test="$bl='1' and $vl= '1'">
      <xsl:apply-templates select="*">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml) + 5"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:case">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'case')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'"><font color="Green"><xsl:value-of select="virt:xpath_eval1('type',$xml)"/></font><i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/></i> condition=<xsl:value-of select="virt:xpath_eval1('cond',$xml)"/></xsl:when>
          <xsl:otherwise>
            <font color="Red">Case</font>
            <i>&nbsp;unknown</i>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
    <xsl:if test="$bl='1' and $vl= '1'">
      <xsl:apply-templates select="*">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml) + 5"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:otherwise">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'otherwise')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'"><font color="Green"><xsl:value-of select="virt:xpath_eval1('type',$xml)"/></font><i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/></i></xsl:when>
          <xsl:otherwise>
            <font color="Red">Otherwise</font>
            <i>&nbsp;unknown</i>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
    <xsl:if test="$bl='1' and $vl= '1'">
      <xsl:apply-templates select="*">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml) + 5"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:wait">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'wait')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'"><font color="Green"><xsl:value-of select="virt:xpath_eval1('type',$xml)"/></font><i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/></i>
          for='<xsl:value-of select="virt:xpath_eval1('value',$xml)"/>'
          </xsl:when>
          <xsl:otherwise>
            <font color="Red">wait</font>
            <i>&nbsp;unknown</i>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
    <xsl:if test="$bl='1' and $vl= '1'">
      <xsl:apply-templates select="*">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml) + 5"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpelv:exec">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'exec')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <!-- added for not showing ns2:exec as uknown -->
    <xsl:if test="$bl !=0">
      <tr>
        <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
          <xsl:call-template name="nbsp">
            <xsl:with-param name="count">
              <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
            </xsl:with-param>
          </xsl:call-template>
          <xsl:choose>
            <xsl:when test="$vl = '1'"><font color="Green"><xsl:value-of select="virt:xpath_eval1('type',$xml)"/></font><i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/></i>
            name='<xsl:value-of select="virt:xpath_eval1('name',$xml)"/>'
            sql_text='<xsl:value-of select="virt:xpath_eval1('stext',$xml)"/>'
            </xsl:when>
            <xsl:otherwise>
              <font color="Red">exec</font>
              <i>&nbsp;unknown</i>
            </xsl:otherwise>
          </xsl:choose>
        </td>
      </tr>
      <xsl:if test="$bl='1' and $vl= '1'">
        <xsl:apply-templates select="*">
          <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml) + 5"/>
        </xsl:apply-templates>
      </xsl:if>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template match="bpel:while">
    <xsl:variable name="xml" select="virt:get_node($script_id,$inst_id,@internal_id,$activs,$links,'while')"/>
    <xsl:variable name="bl" select="virt:xpath_eval1('bl',$xml)"/>
    <xsl:variable name="vl" select="virt:xpath_eval1('valid',$xml)"/>
    <xsl:variable name="blt">
      <xsl:choose>
        <xsl:when test="$bl='1'">'true'</xsl:when>
        <xsl:otherwise>'false'</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <tr>
      <td><xsl:value-of select="virt:xpath_eval2('aid',$xml,$act_id)"/>
        <xsl:call-template name="nbsp">
          <xsl:with-param name="count">
            <xsl:value-of select="virt:xpath_eval1('len',$xml)"/>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:choose>
          <xsl:when test="$vl = '1'"><font color="Green"><xsl:value-of select="virt:xpath_eval1('type',$xml)"/></font><i>&nbsp;known&nbsp;<xsl:value-of select="$blt"/>
            </i> condition="<xsl:value-of select="virt:xpath_eval1('cond',$xml)"/>"
          </xsl:when>
          <xsl:otherwise>
            <font color="Red">While</font>
            <i>&nbsp;unknown</i>
          </xsl:otherwise>
        </xsl:choose>
      </td>
    </tr>
    <xsl:if test="$bl='1' and $vl= '1'">
      <xsl:apply-templates select="*">
        <xsl:with-param name="cnt" select="virt:xpath_eval1('len',$xml) + 5"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
<!-- ================================================================================================================= -->
  <xsl:template name="fst">
    <xsl:param name="xml"/>
    <td width="5%">
      <xsl:value-of select="(virt:xpath_eval1('len',$xml))"/>
    </td>
  </xsl:template>
<!-- ================================================================================================================= -->
</xsl:stylesheet>
