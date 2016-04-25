<?xml version='1.0'?>
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:virt="http://www.openlinksw.com/virtuoso/xslt">
<xsl:output method="html" omit-xml-declaration="yes" indent="yes"/>
<!-- ===================================================================================================================================== -->
<xsl:include href="common.xsl"/>
<!-- ===================================================================================================================================== -->
<xsl:template match="/">
  <table width="100%" border="0" cellpadding="0" cellspacing="0" id="content">
    <xsl:call-template name="MainNav"/>
    <xsl:choose>
      <xsl:when test="$action = 'audit'">
         <xsl:call-template name="Audit-action"/>
      </xsl:when>
      <xsl:when test="$action = 'process'">
         <xsl:call-template name="Process-action"/>
      </xsl:when>
      <xsl:when test="$action = 'processes'">
         <xsl:call-template name="Processes-action"/>
      </xsl:when>
    </xsl:choose>
  </table>
</xsl:template>
<!--===================================================================================================================================== -->
<xsl:template name="Audit-action">
  <tr>
    <th align="left" class="info" colspan="4">Audit for process <font color="Red">
      <xsl:call-template name="make_href">
        <xsl:with-param name="url">process.vspx</xsl:with-param>
        <xsl:with-param name="label"><xsl:value-of select="$script_name"/></xsl:with-param>
        <xsl:with-param name="params">id=<xsl:value-of select="$script_id"/></xsl:with-param>
        <xsl:with-param name="class">m_y</xsl:with-param>
      </xsl:call-template>
       </font>
    </th>
  </tr>
  <tr>
    <td colspan="4">
      <xsl:call-template name="make_href">
        <xsl:with-param name="url">help.vspx</xsl:with-param>
        <xsl:with-param name="label">Help</xsl:with-param>
        <xsl:with-param name="img">i/help_24.gif</xsl:with-param>
        <xsl:with-param name="params">id=process_audit</xsl:with-param>
        <xsl:with-param name="target">'help-popup'</xsl:with-param>
      </xsl:call-template>
      <xsl:call-template name="make_href">
        <xsl:with-param name="url">help.vspx</xsl:with-param>
        <xsl:with-param name="label">Help</xsl:with-param>
        <xsl:with-param name="params">id=process_audit</xsl:with-param>
        <xsl:with-param name="target">'help-popup'</xsl:with-param>
      </xsl:call-template>
    </td>
  </tr>
  <xsl:apply-templates select="Inst" />
</xsl:template>
<!--===================================================================================================================================== -->
<xsl:template name="Processes-action">
    <tr><th class="info" colspan="9">Processes: <xsl:value-of select="count(Script)"/></th></tr>
    <tr>
      <td colspan="9">
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">help.vspx</xsl:with-param>
          <xsl:with-param name="label">Help</xsl:with-param>
          <xsl:with-param name="params">id=processes_list</xsl:with-param>
          <xsl:with-param name="img">i/help_24.gif</xsl:with-param>
          <xsl:with-param name="target">'help-popup'</xsl:with-param>
        </xsl:call-template>
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">help.vspx</xsl:with-param>
          <xsl:with-param name="label">Help</xsl:with-param>
          <xsl:with-param name="params">id=processes_list</xsl:with-param>
          <xsl:with-param name="target">'help-popup'</xsl:with-param>
        </xsl:call-template>
      </td>
    </tr>
    <tr>
      <td colspan="5">
        <table cellpadding="0" cellspacing="0" border="1" id="subcontent">
          <form name="FilterProcess" method="post">
            <input type="hidden" name="i" value="filter"/>
            <tr>
              <th colspan="2">Process filter criteria</th>
            </tr>
            <tr>
              <td width="20%" align="right">
                <xsl:call-template name="make_href">
                  <xsl:with-param name="url">help.vspx</xsl:with-param>
                  <xsl:with-param name="label">Name contains</xsl:with-param>
                  <xsl:with-param name="params">id=processes_list&amp;name=f_name</xsl:with-param>
                  <xsl:with-param name="target">'help-popup'</xsl:with-param>
                </xsl:call-template>
              </td>
              <td>&nbsp;<input type="text" name="bname" size="50">
                  <xsl:attribute name="value"><xsl:value-of select="$bname"/></xsl:attribute>
                   <xsl:attribute name="tabindex">1</xsl:attribute>
                 </input>
                 &nbsp;
               <xsl:call-template name="make_submit">
                 <xsl:with-param name="name">submit</xsl:with-param>
                 <xsl:with-param name="value">Filter</xsl:with-param>
                 <xsl:with-param name="alt">Filter</xsl:with-param>
                 <xsl:with-param name="src">i/find_16.png</xsl:with-param>
               </xsl:call-template>&nbsp;
               <xsl:call-template name="make_href">
                 <xsl:with-param name="url">javascript:document.FilterProcess.submit();</xsl:with-param>
                 <xsl:with-param name="label">Filter</xsl:with-param>
                 <xsl:with-param name="class">link_filter</xsl:with-param>
               </xsl:call-template>&nbsp;
               <xsl:call-template name="make_href">
                 <xsl:with-param name="url">process.vspx</xsl:with-param>
                 <xsl:with-param name="label">Clear</xsl:with-param>
                 <xsl:with-param name="img">i/cancl_16.png</xsl:with-param>
               </xsl:call-template>
               <xsl:call-template name="make_href">
                 <xsl:with-param name="url">process.vspx</xsl:with-param>
                 <xsl:with-param name="label">Clear</xsl:with-param>
                 <xsl:with-param name="class">link_filter</xsl:with-param>
                </xsl:call-template>
              </td>
            </tr>
            <tr>
              <td align="right">
                &nbsp;
              </td>
              <td><xsl:choose>
                 <xsl:when test="$ch">
	           <input type="checkbox" name="ch" checked="yes"><xsl:attribute name="tabindex">2</xsl:attribute></input>
                 </xsl:when>
                 <xsl:otherwise>
	           <input type="checkbox" name="ch"><xsl:attribute name="tabindex">2</xsl:attribute></input>
                 </xsl:otherwise>
               </xsl:choose>
               <xsl:call-template name="make_href">
                  <xsl:with-param name="url">help.vspx</xsl:with-param>
                  <xsl:with-param name="label">Current version only</xsl:with-param>
                  <xsl:with-param name="params">id=processes_list&amp;name=f_version</xsl:with-param>
                  <xsl:with-param name="target">'help-popup'</xsl:with-param>
                </xsl:call-template>
               </td>
             </tr>
          </form>
        </table>
      </td>
    </tr>
    <tr>
      <td colspan="6"> Processes List</td>
    </tr>
    <tr><td colspan="6">
    <table width="100%" id="contentlist" cellpadding="0" cellspacing="0">
    <tr>
      <th>
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">process.vspx</xsl:with-param>
          <xsl:with-param name="label">Name</xsl:with-param>
          <xsl:with-param name="params">sort=<xsl:value-of select="$s1"/>&amp;base=<xsl:value-of select="$base"/></xsl:with-param>
        </xsl:call-template>
      </th>
      <th>
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">process.vspx</xsl:with-param>
          <xsl:with-param name="label">State</xsl:with-param>
          <xsl:with-param name="params">sort=<xsl:value-of select="$s3"/>&amp;base=<xsl:value-of select="$base"/></xsl:with-param>
        </xsl:call-template>
      </th>
      <th>
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">process.vspx</xsl:with-param>
          <xsl:with-param name="label">Upload Date</xsl:with-param>
          <xsl:with-param name="params">sort=<xsl:value-of select="$s4"/>&amp;base=<xsl:value-of select="$base"/></xsl:with-param>
        </xsl:call-template>
      </th>
      <th>
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">process.vspx</xsl:with-param>
          <xsl:with-param name="label">Audit</xsl:with-param>
          <xsl:with-param name="params">sort=<xsl:value-of select="$s5"/>&amp;base=<xsl:value-of select="$base"/></xsl:with-param>
        </xsl:call-template>
      </th>
      <th>Debug</th>
      <th>Properties</th>
      <th width="10%">Action</th>
    </tr>
    <xsl:choose>
      <xsl:when test="$sort = 'a'">
        <xsl:apply-templates select="Script  [ (position() &lt;= ($base + 10)) and (position() > $base)] " mode="list">
	  <xsl:sort select="@Name"/>
	</xsl:apply-templates>
      </xsl:when>
      <xsl:when test="$sort = 'c'">
        <xsl:apply-templates select="Script  [ (position() &lt;= ($base + 10)) and (position() > $base)] " mode="list">
          <xsl:sort select="@State"/>
	</xsl:apply-templates>
      </xsl:when>
      <xsl:when test="$sort = 'd'">
        <xsl:apply-templates select="Script  [ (position() &lt;= ($base + 10)) and (position() > $base)] " mode="list">
          <xsl:sort select="@UploadDate"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:when test="$sort = 'e'">
        <xsl:apply-templates select="Script  [ (position() &lt;= ($base + 10)) and (position() > $base)] " mode="list">
          <xsl:sort select="@Audit"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:when test="$sort = 'a2'">
        <xsl:apply-templates select="Script  [ (position() &lt;= (last() - $base)) and (position() > (last() - $base - 10)) ] " mode="list">
          <xsl:sort select="@Name" order="descending"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:when test="$sort = 'c2'">
        <xsl:apply-templates select="Script  [ (position() &lt;= (last() - $base)) and (position() > (last() - $base - 10)) ] " mode="list">
          <xsl:sort select="@State" order="descending"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:when test="$sort = 'd2'">
        <xsl:apply-templates select="Script  [ (position() &lt;= (last() - $base)) and (position() > (last() - $base - 10)) ] " mode="list">
          <xsl:sort select="@UploadDate" order="descending"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:when test="$sort = 'e2'">
        <xsl:apply-templates select="Script  [ (position() &lt;= (last() - $base)) and (position() > (last() - $base - 10)) ] " mode="list">
          <xsl:sort select="@Audit" order="descending"/>
        </xsl:apply-templates>
      </xsl:when>
     </xsl:choose>
     <xsl:choose>
       <xsl:when test="count(Script) =0">
         <tr><td colspan="9">No processes found.</td></tr>
       </xsl:when>
     </xsl:choose>
     <form method="POST" name="F2">
       <input type="hidden" name="base"><xsl:attribute name="value"><xsl:value-of select="$base"/></xsl:attribute></input>
       <input type="hidden" name="sort"><xsl:attribute name="value"><xsl:value-of select="$sort"/></xsl:attribute></input>
       <!--<input type="hidden" name="prcl"/>-->
       <tr>
         <td align="center" colspan="9">
           <xsl:choose>
             <xsl:when test="$base &gt;= 10">
               <!--<input type="submit" class="m_e" value="&lt;&lt;First" name="frs"/>&nbsp;-->
               <xsl:call-template name="make_href">
                 <xsl:with-param name="url">process.vspx</xsl:with-param>
                 <xsl:with-param name="img">i/first_16.png</xsl:with-param>
                 <xsl:with-param name="params">frs=1&amp;sort=<xsl:value-of select="$sort"/>&amp;base=<xsl:value-of select="$base"/></xsl:with-param>
                 <xsl:with-param name="label">First</xsl:with-param>
               </xsl:call-template>
               <xsl:call-template name="make_href">
                 <xsl:with-param name="url">process.vspx</xsl:with-param>
                 <xsl:with-param name="params">frs=1&amp;sort=<xsl:value-of select="$sort"/>&amp;base=<xsl:value-of select="$base"/></xsl:with-param>
                 <xsl:with-param name="label">First</xsl:with-param>
               </xsl:call-template>
             </xsl:when>
             <xsl:otherwise>
               <img src="i/first_16.png" alt="First" title="First" border="0" />&#160;First
             </xsl:otherwise>
           </xsl:choose>
           <xsl:choose>
             <xsl:when test="$base &gt; 0">
               <!--<input type="submit" class="m_e" value="&lt;&lt;Prev" name="prf"/>&nbsp;-->
               <xsl:call-template name="make_href">
                 <xsl:with-param name="url">process.vspx</xsl:with-param>
                 <xsl:with-param name="img">i/previous_16.png</xsl:with-param>
                 <xsl:with-param name="params">prf=1&amp;sort=<xsl:value-of select="$sort"/>&amp;base=<xsl:value-of select="$base"/></xsl:with-param>
                 <xsl:with-param name="label">Previous</xsl:with-param>
               </xsl:call-template>
               <xsl:call-template name="make_href">
                 <xsl:with-param name="url">process.vspx</xsl:with-param>
                 <xsl:with-param name="params">prf=1&amp;sort=<xsl:value-of select="$sort"/>&amp;base=<xsl:value-of select="$base"/></xsl:with-param>
                 <xsl:with-param name="label">Previous</xsl:with-param>
               </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
              <img src="i/previous_16.png" alt="Previous" title="Previous" border="0" />&#160;Previous
             </xsl:otherwise>
           </xsl:choose>
           <xsl:choose>
             <xsl:when test="$base + 10 &lt; count (Script)">
               <!--<input type="submit" class="m_e" value="Next&gt;&gt;" name="nxt"/>&nbsp;-->
               <xsl:call-template name="make_href">
                 <xsl:with-param name="url">process.vspx</xsl:with-param>
                 <xsl:with-param name="img">i/next_16.png</xsl:with-param>
                 <xsl:with-param name="params">nxt=1&amp;sort=<xsl:value-of select="$sort"/>&amp;base=<xsl:value-of select="$base"/></xsl:with-param>
                 <xsl:with-param name="label">Next</xsl:with-param>
               </xsl:call-template>
               <xsl:call-template name="make_href">
                 <xsl:with-param name="url">process.vspx</xsl:with-param>
                 <xsl:with-param name="params">nxt=1&amp;sort=<xsl:value-of select="$sort"/>&amp;base=<xsl:value-of select="$base"/></xsl:with-param>
                 <xsl:with-param name="label">Next</xsl:with-param>
               </xsl:call-template>
             </xsl:when>
             <xsl:otherwise>
               <img src="i/next_16.png" alt="Next" title="Next" border="0" />&#160;Next
             </xsl:otherwise>
           </xsl:choose>
           <xsl:choose>
             <xsl:when test="(count (Script) - $base) &gt; 10">
               <xsl:variable name = "param">
                 <xsl:choose>
                   <xsl:when test=" (ceiling(count(Script) div 10) * 10)  =  count (Script) ">
                     <xsl:value-of select = " (count (Script) div 10) * 10  - 10 "/>
                   </xsl:when>
                   <xsl:otherwise><xsl:value-of select=" (ceiling(count(Script) div 10 ) * 10) - 10 "/></xsl:otherwise>
                 </xsl:choose>
               </xsl:variable>
               <!--<input type="hidden" name="lstp"><xsl:attribute name="value"><xsl:value-of select="$param"/></xsl:attribute></input>
               <input type="submit" class="m_e" value="Last&gt;&gt;" name="lst"/>&nbsp;-->
               <xsl:call-template name="make_href">
                 <xsl:with-param name="url">process.vspx</xsl:with-param>
                 <xsl:with-param name="img">i/last_16.png</xsl:with-param>
                 <xsl:with-param name="params">lst=1&amp;lstp=<xsl:value-of select="$param"/>&amp;sort=<xsl:value-of select="$sort"/>&amp;base=<xsl:value-of select="$base"/></xsl:with-param>
                 <xsl:with-param name="label">Last</xsl:with-param>
               </xsl:call-template>
               <xsl:call-template name="make_href">
                 <xsl:with-param name="url">process.vspx</xsl:with-param>
                 <xsl:with-param name="params">lst=1&amp;lstp=<xsl:value-of select="$param"/>&amp;sort=<xsl:value-of select="$sort"/>&amp;base=<xsl:value-of select="$base"/></xsl:with-param>
                 <xsl:with-param name="label">Last</xsl:with-param>
               </xsl:call-template>
             </xsl:when>
             <xsl:otherwise>
               <img src="i/last_16.png" alt="Last" title="Last" border="0" />&#160;Last
             </xsl:otherwise>
           </xsl:choose>
         </td>
       </tr>
     </form>
    </table>
   </td>
  </tr>
</xsl:template>
<!--===================================================================================================================================== -->
<xsl:template name="Process-action">
  <tr>
    <th colspan="7" class="info">Process
    <xsl:call-template name="make_href">
        <xsl:with-param name="url">process.vspx</xsl:with-param>
        <xsl:with-param name="label"><xsl:value-of select="Script/@Name"/></xsl:with-param>
        <xsl:with-param name="class">m_y</xsl:with-param>
        <xsl:with-param name="params">id=<xsl:value-of select="Script/@Id"/></xsl:with-param>
      </xsl:call-template>
     </th>
  </tr>
  <xsl:apply-templates select="Script" mode="process"/>
</xsl:template>
<!-- ===================================================================================================================================== -->
<xsl:template match="Inst">
  <tr>
    <th>Id</th>
    <th>Node</th>
    <th>Additional Info</th>
    <th>Date</th>
  </tr>
  <xsl:apply-templates select="AuditEntry">
    <xsl:sort data-type= "number" select="@AuditId" />
  </xsl:apply-templates>
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
    </td>
  </tr>
</xsl:template>
<!-- ===================================================================================================================================== -->
<xsl:template match="AuditEntry">
  <tr>
    <td align="center">
      <xsl:value-of select="@Id"/>&nbsp;
    </td>
    <td align="left">
      <xsl:value-of select="@Node"/>&nbsp;
    </td>
    <td width="70%" align="left"><code><xsl:value-of select="text()"/></code>&nbsp;</td>
    <td align="left">
      <xsl:value-of select="@DateT"/>&nbsp;
    </td>
  </tr>
</xsl:template>
<!-- ===================================================================================================================================== -->
<xsl:template match="Script" mode="process">
  <tr>
      <td colspan="7">
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">help.vspx</xsl:with-param>
          <xsl:with-param name="label">Help</xsl:with-param>
          <xsl:with-param name="img">i/help_24.gif</xsl:with-param>
          <xsl:with-param name="params">id=process_list</xsl:with-param>
          <xsl:with-param name="target">'help-popup'</xsl:with-param>
        </xsl:call-template>
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">help.vspx</xsl:with-param>
          <xsl:with-param name="label">Help</xsl:with-param>
          <xsl:with-param name="params">id=process_list</xsl:with-param>
          <xsl:with-param name="target">'help-popup'</xsl:with-param>
        </xsl:call-template>
      </td>
    </tr>
  <tr>
    <td colspan="7"><b>Details</b></td>
  </tr>
  <tr>
    <td width="5%">&nbsp;</td>
    <td width="5%"><b>Name:</b></td>
    <td colspan="5" align="left"><xsl:value-of select="@Name"/></td>
  </tr>
  <form method="POST">
    <input type="hidden" name="id" value="{@Id}"/>
    <input type="hidden" name="state" value="{@State}"/>
    <input type="hidden" name="dlt" value=""/>
    <tr>
      <td width="5%">&nbsp;</td>
      <td width="5%"><b>State:</b></td>
      <td colspan="5" align="left">
      <xsl:choose>
        <xsl:when test="@State &lt; 2">
          <xsl:choose>
            <xsl:when test="@State = 0">current: <input type="submit" class="m_e" value="Mark as Retired" name="mark"></input></xsl:when>
            <xsl:when test="@State = 1">obsolete:</xsl:when>
          </xsl:choose>
          <input name="chg" type="checkbox" value="1" onclick="javascript: this.form.dlt.value='Delall';this.form.submit()"/>
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">help.vspx</xsl:with-param>
            <xsl:with-param name="label">Delete Instances</xsl:with-param>
            <xsl:with-param name="params">id=process_list&amp;name=f_del</xsl:with-param>
            <xsl:with-param name="target">'help-popup'</xsl:with-param>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="@State = 2">edit</xsl:when>
      </xsl:choose>
      </td>
    </tr>
  </form>
  <tr>
    <td>&nbsp;</td>
    <td><b>Action:</b></td>
    <td colspan="5" align="left" nowrap="nowrap">
      <xsl:call-template name="links">
         <xsl:with-param name="mode" select="'process'"/>
      </xsl:call-template>
    </td>
  </tr>
  <tr>
    <td>&nbsp;</td>
    <td><b>Instances:</b></td>
    <td colspan="5" align="left" nowrap="nowrap">
      <xsl:value-of select="count(Instance)"/>
    </td>
  </tr>
  <tr>
    <td><br/></td>
  </tr>
  <tr>
    <td colspan="7"><b>Instances List</b></td>
  </tr>
  <tr>
    <td colspan="7">
      <table width="100%" id="contentlist" cellpadding="0" cellspacing="0">
        <form method="POST" name="F1">
          <input type="hidden" name="id" value="@Id"/>
          <tr>
            <!-- xsl:choose>
              <xsl:when test="count(Instance/@Id) > 0">
                <th>
                  Action
                </th>
              </xsl:when>
            </xsl:choose -->
            <xsl:choose>
              <xsl:when test="count(Instance/@Id) > 1">
                <th nowrap="nowrap" align="right">
                  Select All&nbsp;<input onclick="javascript:ch_msg();" type="checkbox" value="1" name="ch_all"/>
                </th>
              </xsl:when>
              <xsl:otherwise>
                <th>
                  Action
                </th>
              </xsl:otherwise>
            </xsl:choose>
            <th>
              <xsl:call-template name="make_href">
                <xsl:with-param name="url">process.vspx</xsl:with-param>
                <xsl:with-param name="label">RUN ID</xsl:with-param>
                <xsl:with-param name="params">sort=<xsl:value-of select="$s1"/>&amp;id=<xsl:value-of select="$inst_id"/>&amp;base=<xsl:value-of select="$base"/></xsl:with-param>
              </xsl:call-template>
            </th>
            <th>
              <xsl:call-template name="make_href">
                <xsl:with-param name="url">process.vspx</xsl:with-param>
                <xsl:with-param name="label">State</xsl:with-param>
                <xsl:with-param name="params">sort=<xsl:value-of select="$s2"/>&amp;id=<xsl:value-of select="$inst_id"/></xsl:with-param>
              </xsl:call-template>
            </th>
            <th>View</th>
            <th>Started Time</th>
            <th>Inactive Since</th>
            <th>
              <xsl:call-template name="make_href">
                <xsl:with-param name="url">process.vspx</xsl:with-param>
                <xsl:with-param name="label">Error</xsl:with-param>
                <xsl:with-param name="params">sort=<xsl:value-of select="$s3"/>&amp;id=<xsl:value-of select="$inst_id"/></xsl:with-param>
              </xsl:call-template>
            </th>
          </tr>
          <xsl:choose>
            <xsl:when test="$sort = 'a'">
              <xsl:apply-templates select="Instance  [ (position() &lt;= ($base + 10)) and (position() > $base)] ">
	        <xsl:sort select="@Id" data-type= "number"/>
	      </xsl:apply-templates>
            </xsl:when>
            <xsl:when test="$sort = 'b'">
              <xsl:apply-templates select="Instance  [ (position() &lt;= ($base + 10)) and (position() > $base)] ">
	        <xsl:sort select="@State"/>
              </xsl:apply-templates>
            </xsl:when>
            <xsl:when test="$sort = 'c'">
              <xsl:apply-templates select="Instance  [ (position() &lt;= ($base + 10)) and (position() > $base)] ">
                <xsl:sort select="@error"/>
	      </xsl:apply-templates>
            </xsl:when>
            <xsl:when test="$sort = 'a2'">
              <xsl:apply-templates select="Instance  [ (position() &lt;= ($base + 10)) and (position() > $base) ] ">
                <xsl:sort select="@Id" order="descending"/>
              </xsl:apply-templates>
            </xsl:when>
            <xsl:when test="$sort = 'b2'">
              <xsl:apply-templates select="Instance  [ (position() &lt;= (last() - $base)) and (position() > (last() - $base - 10)) ] ">
                <xsl:sort select="@State" order="descending"/>
              </xsl:apply-templates>
            </xsl:when>
            <xsl:when test="$sort = 'c2'">
              <xsl:apply-templates select="Instance  [ (position() &lt;= (last() - $base)) and (position() > (last() - $base - 10)) ] ">
                <xsl:sort select="@error" order="descending"/>
              </xsl:apply-templates>
            </xsl:when>
          </xsl:choose>
          <!-- xsl:choose>
            <xsl:when test="count(Instance/@Id) > 1">
              <tr>
                <td nowrap="nowrap" align="right">
                  Select All&nbsp;<input onclick="javascript:ch_msg();" type="checkbox" value="1" name="ch_all"/>
                </td>
                <td colspan="6">&nbsp;</td>
              </tr>
            </xsl:when>
          </xsl:choose -->
          <xsl:choose>
            <xsl:when test="count(Instance/@Id) > 0">
              <tr>
                <td align="right">
                  <input type="submit" class="m_e" value="Delete" name="delinst"/>&nbsp;
                  <input type="submit" class="m_e" value="Restart" name="restinst"/>
                </td>
                <td colspan="6">&nbsp;</td>
              </tr>
            </xsl:when>
          </xsl:choose>
        </form>
        <form method="POST" name="F2">
          <input type="hidden" name="id"><xsl:attribute name="value"><xsl:value-of select="$inst_id"/></xsl:attribute></input>
          <input type="hidden" name="sort"><xsl:attribute name="value"><xsl:value-of select="$sort"/></xsl:attribute></input>
          <input type="hidden" name="base"><xsl:attribute name="value"><xsl:value-of select="$base"/></xsl:attribute></input>
          <input type="hidden" name="prcs"/>
          <tr>
            <td align="center" colspan="9">
              <xsl:choose>
                <xsl:when test="$base &gt;= 10">
                   <!--<input type="submit" class="m_e" value="&lt;&lt;First" name="frs"/>&nbsp;-->
                   <xsl:call-template name="make_href">
                     <xsl:with-param name="url">process.vspx</xsl:with-param>
                     <xsl:with-param name="img">i/first_16.png</xsl:with-param>
                     <xsl:with-param name="params">frs=1&amp;id=<xsl:value-of select="$inst_id"/>&amp;sort=<xsl:value-of select="$sort"/>&amp;base=<xsl:value-of select="$base"/>&amp;prcs=1</xsl:with-param>
                      <xsl:with-param name="label">First</xsl:with-param>
                   </xsl:call-template>
                   <xsl:call-template name="make_href">
                     <xsl:with-param name="url">process.vspx</xsl:with-param>
                     <xsl:with-param name="params">frs=1&amp;id=<xsl:value-of select="$inst_id"/>&amp;sort=<xsl:value-of select="$sort"/>&amp;base=<xsl:value-of select="$base"/>&amp;prcs=1</xsl:with-param>
                      <xsl:with-param name="label">First</xsl:with-param>
                   </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>
                  <img src="i/first_16.png" alt="First" title="First" border="0" />&#160;First
                </xsl:otherwise>
              </xsl:choose>
              <xsl:choose>
                <xsl:when test="$base &gt; 0">
                   <!--<input type="submit" class="m_e" value="&lt;&lt;Prev" name="prf"/>&nbsp;--->
                   <xsl:call-template name="make_href">
                     <xsl:with-param name="url">process.vspx</xsl:with-param>
                     <xsl:with-param name="img">i/previous_16.png</xsl:with-param>
                     <xsl:with-param name="params">prf=1&amp;id=<xsl:value-of select="$inst_id"/>&amp;sort=<xsl:value-of select="$sort"/>&amp;base=<xsl:value-of select="$base"/>&amp;prcs=1</xsl:with-param>
                      <xsl:with-param name="label">Previous</xsl:with-param>
                   </xsl:call-template>
                   <xsl:call-template name="make_href">
                     <xsl:with-param name="url">process.vspx</xsl:with-param>
                     <xsl:with-param name="params">prf=1&amp;id=<xsl:value-of select="$inst_id"/>&amp;sort=<xsl:value-of select="$sort"/>&amp;base=<xsl:value-of select="$base"/>&amp;prcs=1</xsl:with-param>
                      <xsl:with-param name="label">Previous</xsl:with-param>
                   </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>
                  <img src="i/previous_16.png" alt="Previous" title="Previous" border="0" />&#160;Previous
                </xsl:otherwise>
              </xsl:choose>
              <xsl:choose>
                <xsl:when test="$base + 10 &lt; count (Instance) ">
                   <!--<input type="submit" class="m_e" value="Next&gt;&gt;" name="nxt"/>&nbsp;-->
                   <xsl:call-template name="make_href">
                     <xsl:with-param name="url">process.vspx</xsl:with-param>
                     <xsl:with-param name="img">i/next_16.png</xsl:with-param>
                     <xsl:with-param name="params">nxt=1&amp;id=<xsl:value-of select="$inst_id"/>&amp;sort=<xsl:value-of select="$sort"/>&amp;base=<xsl:value-of select="$base"/>&amp;prcs=1</xsl:with-param>
                     <xsl:with-param name="label">Next</xsl:with-param>
                   </xsl:call-template>
                   <xsl:call-template name="make_href">
                     <xsl:with-param name="url">process.vspx</xsl:with-param>
                     <xsl:with-param name="params">nxt=1&amp;id=<xsl:value-of select="$inst_id"/>&amp;sort=<xsl:value-of select="$sort"/>&amp;base=<xsl:value-of select="$base"/>&amp;prcs=1</xsl:with-param>
                     <xsl:with-param name="label">Next</xsl:with-param>
                   </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>
                  <img src="i/next_16.png" alt="Next" title="Next" border="0" />&#160;Next
                </xsl:otherwise>
              </xsl:choose>
              <xsl:choose>
                <xsl:when test="(count (Instance) - $base) &gt; 10">
                   <xsl:variable name = "param">
                     <xsl:choose>
                       <xsl:when test=" (ceiling(count(Instance) div 10) * 10)  =  count (Instance) ">
                         <xsl:value-of select = " (count (Instance) div 10) * 10  - 10 "/>
                       </xsl:when>
                       <xsl:otherwise><xsl:value-of select=" (ceiling(count(Instance) div 10 ) * 10) - 10 "/></xsl:otherwise>
                     </xsl:choose>
                   </xsl:variable>
                   <!--<input type="hidden" name="lstp"><xsl:attribute name="value"><xsl:value-of select="$param"/></xsl:attribute></input>
                   <input type="submit" class="m_e" value="Last&gt;&gt;" name="lst"/>&nbsp;--->
                   <xsl:call-template name="make_href">
                      <xsl:with-param name="url">process.vspx</xsl:with-param>
                      <xsl:with-param name="img">i/last_16.png</xsl:with-param>
                      <xsl:with-param name="params">lst=1&amp;lstp=<xsl:value-of select="$param"/>&amp;id=<xsl:value-of select="$inst_id"/>&amp;sort=<xsl:value-of select="$sort"/>&amp;base=<xsl:value-of select="$base"/>&amp;prcs=1</xsl:with-param>
                      <xsl:with-param name="label">Last</xsl:with-param>
                   </xsl:call-template>
                   <xsl:call-template name="make_href">
                      <xsl:with-param name="url">process.vspx</xsl:with-param>
                      <xsl:with-param name="params">lst=1&amp;lstp=<xsl:value-of select="$param"/>&amp;id=<xsl:value-of select="$inst_id"/>&amp;sort=<xsl:value-of select="$sort"/>&amp;base=<xsl:value-of select="$base"/>&amp;prcs=1</xsl:with-param>
                      <xsl:with-param name="label">Last</xsl:with-param>
                   </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>
                  <img src="i/last_16.png" alt="Last" title="Last" border="0" />&#160;Last
                </xsl:otherwise>
              </xsl:choose>
            </td>
          </tr>
        </form>
        <xsl:choose>
          <xsl:when test="count(Instance) =0">
            <tr><td colspan="9">No instances</td></tr>
          </xsl:when>
        </xsl:choose>
      </table>
    </td>
  </tr>
</xsl:template>
<!-- ===================================================================================================================================== -->
<xsl:template match="Instance">
  <xsl:variable name="check_audit" select="virt:check_audit_report(@Id)"/>
  <tr>
    <xsl:attribute name="bgcolor"><xsl:choose><xsl:when test="(position() mod 2) = 0">#efefef</xsl:when><xsl:otherwise>#fefefe</xsl:otherwise></xsl:choose></xsl:attribute>
    <td align="right" width="15%">
      <input type="checkbox">
        <xsl:attribute name="value"><xsl:value-of select="@Id"/></xsl:attribute>
        <xsl:attribute name="name">cid_<xsl:value-of select="@Id"/></xsl:attribute>
      </input>
    </td>
    <td align="center"><xsl:value-of select="@Id"/></td>
    <td align="center">
      <b>
        <xsl:choose>
          <xsl:when test="@State = 0">
            Started
          </xsl:when>
          <xsl:when test="@State = 1">
            Suspended
          </xsl:when>
          <xsl:when test="@State = 2">
            Finished
          </xsl:when>
          <xsl:when test="@State = 3">
            Aborted
          </xsl:when>
          <xsl:when test="@State = 4">
            Wait for retry
          </xsl:when>
	  </xsl:choose>
      </b>
    </td>
    <td  align="center" nowrap="nowrap">
      <xsl:choose>
        <xsl:when test="$check_audit = '1'">
         <xsl:call-template name="make_href">
            <xsl:with-param name="url">process.vspx</xsl:with-param>
            <xsl:with-param name="label">Audit</xsl:with-param>
            <xsl:with-param name="params">id=<xsl:value-of select="@Id"/>&amp;i=audit</xsl:with-param>
          </xsl:call-template>
        </xsl:when>
      </xsl:choose>
      &nbsp;
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">status.vspx</xsl:with-param>
            <xsl:with-param name="label">Status</xsl:with-param>
            <xsl:with-param name="params">id=<xsl:value-of select="//Script/@Id"/>&amp;nid=<xsl:value-of select="@Id"/></xsl:with-param>
          </xsl:call-template>
    </td>
    <td nowrap="nowrap" align="right">&nbsp;
       <xsl:if test="@StartedTime != ''">
         <xsl:value-of select="virt:date_interval(@StartedTime)"/>
       </xsl:if>
    </td>
    <td nowrap="nowrap" align="right">&nbsp;
       <xsl:if test="@InactiveSince != ''">
         <xsl:value-of select="virt:date_interval(@InactiveSince)"/>
       </xsl:if>
    </td>
    <td align="right">
      <xsl:attribute name="bgcolor">
        <xsl:choose>
          <xsl:when test="(@error != '') and (@error_handled != 1)">#FFBBBB</xsl:when>
          <xsl:when test="(@error != '') and (@error_handled = 1)">#FFFFBB</xsl:when>
        </xsl:choose>
      </xsl:attribute>
      <xsl:value-of select="@error"/>&nbsp;
    </td>
  </tr>
</xsl:template>
<!-- ===================================================================================================================================== -->
<xsl:template match="Script" mode="list">
  <xsl:variable name="EndPoint" select="concat($EPoint,virt:get_endpoint(@Id))"/>
  <tr>
    <xsl:attribute name="bgcolor"><xsl:choose><xsl:when test="(position() mod 2) = 0">#efefef</xsl:when><xsl:otherwise>#fefefe</xsl:otherwise></xsl:choose></xsl:attribute>
    <td align="right">
      <xsl:call-template name="make_href">
        <xsl:with-param name="url">process.vspx</xsl:with-param>
        <xsl:with-param name="label"><xsl:value-of select="@Name"/></xsl:with-param>
        <xsl:with-param name="params">id=<xsl:value-of select="@Id"/></xsl:with-param>
      </xsl:call-template>
    </td>
    <!--<td align="right">
      <xsl:value-of select="@URI"/>
    </td>-->
    <td align="right">
      <xsl:choose>
        <xsl:when test="@State = 0">
            <b>current</b>
        </xsl:when>
        <xsl:when test="@State = 1">
            <b>obsolete</b>
        </xsl:when>
        <xsl:when test="@State = 2">
            <b>edit</b>
        </xsl:when>
        <xsl:otherwise>
            <b>Unknown State</b>
        </xsl:otherwise>
      </xsl:choose>
    </td>
    <td align="right">
      <xsl:if test="@UploadDate != ''">
        <xsl:value-of select="virt:date_interval(@UploadDate)"/>
      </xsl:if>
    </td>
    <form name="F1" method="post">
      <input type="hidden" name="upd" value=""/>
    <td align="center">
      <input type="hidden" name="id" value="{@Id}"/>
      <input name="audit" type="checkbox" value="1" onclick="javascript: this.form.upd.value='Commit';this.form.submit()">
        <xsl:if test="@Audit = 1">
          <xsl:attribute name="checked">checked</xsl:attribute>
        </xsl:if>
      </input>
    </td>
    <td align="center">
      <input name="debug" type="checkbox" value="1" onclick="javascript: this.form.upd.value='Commit';this.form.submit()">
        <xsl:if test="@Debug = 1">
          <xsl:attribute name="checked">checked</xsl:attribute>
        </xsl:if>
      </input>
    </td>
    </form>
    <td align="center">
      <xsl:choose>
        <xsl:when test="@State = 2">Graph </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">script.vspx</xsl:with-param>
            <xsl:with-param name="label">Graph</xsl:with-param>
            <xsl:with-param name="params">id=<xsl:value-of select="@Id"/></xsl:with-param>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:choose>
        <xsl:when test="@State = 0">
          <a>
            <xsl:attribute name="target">'help-popup'</xsl:attribute>
            <xsl:attribute name="href"><xsl:value-of select="$EndPoint"/></xsl:attribute> WSDL
          </a>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="make_href">
            <xsl:with-param name="url">view.vspx</xsl:with-param>
            <xsl:with-param name="label">WSDL</xsl:with-param>
            <xsl:with-param name="target">'help-popup'</xsl:with-param>
            <xsl:with-param name="params">role=wsdl&amp;id=<xsl:value-of select="@Id"/></xsl:with-param>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:call-template name="make_href">
        <xsl:with-param name="url">view.vspx</xsl:with-param>
        <xsl:with-param name="label">Source</xsl:with-param>
        <xsl:with-param name="target">'help-popup'</xsl:with-param>
        <xsl:with-param name="params">role=bpel&amp;id=<xsl:value-of select="@Id"/></xsl:with-param>
      </xsl:call-template>
    </td>
      <td align="center" nowrap="nowrap">
        <xsl:call-template name="links"/>
      </td>
  </tr>
</xsl:template>
<!-- ===================================================================================================================================== -->
<xsl:template name="links">
  <xsl:param name="mode"/>
  <xsl:choose>
    <xsl:when test="$mode = 'process'">
      <xsl:call-template name="make_href">
        <xsl:with-param name="url">upload_new.vspx</xsl:with-param>
        <xsl:with-param name="label">Redefine </xsl:with-param>
        <xsl:with-param name="params">id=<xsl:value-of select="@Id"/>&amp;rf=<xsl:value-of select="@Id"/></xsl:with-param>
      </xsl:call-template>|
      <xsl:choose>
        <xsl:when test="@State = 0"><xsl:call-template name="make_href">
            <xsl:with-param name="url">message.vspx</xsl:with-param>
            <xsl:with-param name="label">Test </xsl:with-param>
            <xsl:with-param name="params">id=<xsl:value-of select="@Id"/>&amp;uri=<xsl:value-of select="@Name"/></xsl:with-param>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>Test </xsl:otherwise>
      </xsl:choose>|
      <xsl:choose>
        <xsl:when test="@State = 2">Partner Links </xsl:when>
        <xsl:otherwise><xsl:call-template name="make_href">
            <xsl:with-param name="url">plinks.vspx</xsl:with-param>
            <xsl:with-param name="label">Partner Links </xsl:with-param>
            <xsl:with-param name="params">id=<xsl:value-of select="@Id"/></xsl:with-param>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
      |<xsl:call-template name="make_href">
        <xsl:with-param name="url">bpel_confirm.vspx</xsl:with-param>
        <xsl:with-param name="label"> Delete all versions and instances</xsl:with-param>
        <xsl:with-param name="params">op=delall&amp;id=<xsl:value-of select="@Id"/>&amp;nam=<xsl:value-of select="@Name"/></xsl:with-param>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="make_href">
        <xsl:with-param name="url">upload_new.vspx</xsl:with-param>
        <xsl:with-param name="label">Redefine </xsl:with-param>
        <xsl:with-param name="params">id=<xsl:value-of select="@Id"/></xsl:with-param>
      </xsl:call-template>|
      <xsl:choose>
        <xsl:when test="@State = 0"><xsl:call-template name="make_href">
            <xsl:with-param name="url">message.vspx</xsl:with-param>
            <xsl:with-param name="label">Test </xsl:with-param>
            <xsl:with-param name="params">id=<xsl:value-of select="@Id"/>&amp;uri=<xsl:value-of select="@Name"/></xsl:with-param>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>Test </xsl:otherwise>
      </xsl:choose>|
      <xsl:choose>
        <xsl:when test="@State = 2">Partner Links </xsl:when>
        <xsl:otherwise><xsl:call-template name="make_href">
            <xsl:with-param name="url">plinks.vspx</xsl:with-param>
            <xsl:with-param name="label">Partner Links </xsl:with-param>
            <xsl:with-param name="params">id=<xsl:value-of select="@Id"/></xsl:with-param>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>
<!-- ===================================================================================================================================== -->
</xsl:stylesheet>
