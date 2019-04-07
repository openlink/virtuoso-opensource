<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2019 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:include href="common.xsl"/>
  <xsl:include href="common_folders.xsl"/>

  <!-- ====================================================================================== -->
  <xsl:template match="page">
    <form method="post" name="f1">
      <xsl:attribute name="action"><xsl:value-of select="$iri" />/filters.vsp</xsl:attribute>
      <xsl:call-template name="hid_sid"/>
      <xsl:apply-templates select="filters"/>
      <xsl:apply-templates select="filter[@type='edit']"/>
    </form>
  </xsl:template>

  <!-- ====================================================================================== -->
  <xsl:template match="filters">
	  <div>
	    <xsl:call-template name="make_href">
	      <xsl:with-param name="url">filters.vsp</xsl:with-param>
	      <xsl:with-param name="params">filter_id=-1</xsl:with-param>
	      <xsl:with-param name="label">Create Filter</xsl:with-param>
	      <xsl:with-param name="img">/oMail/i/add_16.png</xsl:with-param>
	      <xsl:with-param name="img_label"> Create Filter</xsl:with-param>
	      <xsl:with-param name="class">button2</xsl:with-param>
	    </xsl:call-template>
	    &nbsp;
      <xsl:call-template name="make_href">
        <xsl:with-param name="url">javascript: if (confirmAction('Are you sure that you want to delete selected filter(s)?')) formSubmit('fa_delete.x'); </xsl:with-param>
        <xsl:with-param name="label">Delete Filter</xsl:with-param>
        <xsl:with-param name="img">/oMail/i/del_16.png</xsl:with-param>
        <xsl:with-param name="img_label"> Delete</xsl:with-param>
        <xsl:with-param name="class">button2</xsl:with-param>
      </xsl:call-template>
	  </div>
    <br />
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="content">
      <thead>
        <tr>
          <th class="checkbox">
            <input type="checkbox" onclick="selectAllCheckboxes(this, 'cb_item')" value="Select All" name="cb_all"/>
          </th>
          <th>Filter</th>
          <th width="5%">Action</th>
        </tr>
      </thead>
      <xsl:apply-templates select="filter[@type='list']"/>
      <xsl:call-template name="empty_row">
        <xsl:with-param name="count" select="count(filter[@type='list'])"/>
        <xsl:with-param name="colspan" select="3"/>
      </xsl:call-template>
    </table>
    <hr />
    <div style="width: 99.5%; background-color: #B0CDE4; padding: 3px;">
      <b>Run selected filter(s) on:</b>
      &nbsp;
      <xsl:apply-templates select="../folders" mode="combo">
        <xsl:with-param name="ID" select="'folder_id'" />
        <xsl:with-param name="scope" select="'*'" />
      </xsl:apply-templates>
      &nbsp;
      <xsl:call-template name="make_submit">
        <xsl:with-param name="name">fa_run</xsl:with-param>
        <xsl:with-param name="value">Run</xsl:with-param>
        <xsl:with-param name="alt">Run</xsl:with-param>
      </xsl:call-template>
    </div>
  </xsl:template>

  <!-- ====================================================================================== -->
  <xsl:template match="filter[@type='list']">
    <tr class="msgRow">
      <td width="1%">
        <input type="checkbox" onclick="selectCheck(this, 'cb_item')" name="cb_item">
          <xsl:attribute name="value"><xsl:value-of select="id"/></xsl:attribute>
        </input>
      </td>
      <td>
        <b><xsl:value-of select="name"/></b>
      </td>
      <td nowrap="nowrap">
        <xsl:call-template name="make_href">
          <xsl:with-param name="url">filters.vsp</xsl:with-param>
          <xsl:with-param name="params">filter_id=<xsl:value-of select="id"/></xsl:with-param>
          <xsl:with-param name="label">Edit Filter</xsl:with-param>
          <xsl:with-param name="img">/oMail/i/edit_16.png</xsl:with-param>
          <xsl:with-param name="img_label"> Edit</xsl:with-param>
          <xsl:with-param name="class">button2</xsl:with-param>
        </xsl:call-template>
      </td>
    </tr>
  </xsl:template>

  <!-- ====================================================================================== -->
  <xsl:template match="filter[@type='edit']">
    <script type="text/javascript">
      OAT.MSG.attach(OAT, "PAGE_LOADED", function(){OMAIL.initFilter();});
    </script>
    <input type="hidden" name="filter_id">
      <xsl:attribute name="value"><xsl:value-of select="id"/></xsl:attribute>
    </input>
    <table width="100%" cellpadding="0" cellspacing="0" class="content">
      <caption>
        <span>Manage Filter</span>
      </caption>
	    <tr>
	      <th width="30%">
	        <label for="filter_name">Name</label>
	      </th>
	      <td>
	        <input type="text" name="filter_name" id="filter_name" size="60">
	          <xsl:attribute name="value"><xsl:value-of select="name"/></xsl:attribute>
	        </input>
	      </td>
	    </tr>
	    <tr>
	      <th>Active</th>
	      <td>
	        <xsl:call-template name="make_checkbox">
	          <xsl:with-param name="name">filter_active</xsl:with-param>
	          <xsl:with-param name="id">filter_active</xsl:with-param>
	          <xsl:with-param name="value">1</xsl:with-param>
	          <xsl:with-param name="checked"><xsl:if test="active = 1">1</xsl:if></xsl:with-param>
	        </xsl:call-template>
	      </td>
	    </tr>
	    <tr>
	      <th valign="top">Apply filter actions when</th>
	      <td>
          <label>
            <input type="radio" name="filter_mode" id="filter_mode_0" value="0">
              <xsl:if test="mode = '0'">
                <xsl:attribute name="checked">checked</xsl:attribute>
              </xsl:if>
            </input>
    			  all criteria are matched
    	    </label>
    	    <br />
          <label>
            <input type="radio" name="filter_mode" id="filter_mode_1" value="1">
              <xsl:if test="mode = '1'">
                <xsl:attribute name="checked">checked</xsl:attribute>
              </xsl:if>
            </input>
    			  any of criteria is matched
    	    </label>
	      </td>
	    </tr>
	    <tr>
        <th colspan="2" style="background-color: #EAEAEE; text-align: center;">Criteria</th>
	    </tr>
	    <tr>
	      <td colspan="2">
		      <table style="width: 100%;" cellspacing="0">
		        <tr>
		          <td width="100%">
      		      <table id="search_tbl" class="form-list" style="width: 100%;" cellspacing="0">
		        <thead>
		          <tr>
		            <th id="search_th_0" width="33%">Field</th>
		            <th id="search_th_1" width="33%">Condition</th>
		            <th id="search_th_2" width="33%">Value</th>
		            <th id="search_th_3" width="1%"><xsl:call-template name="nbsp"/></th>
		          </tr>
		        </thead>
		        <tbody id="search_tbody">
      		          <tr id="search_tr_no">
      		            <td colspan="3">No Criteria</td>
		          </tr>
		    		    <script type="text/javascript">
						      <xsl:for-each select="criteria/entry">
      					        OAT.MSG.attach(OAT, "PAGE_LOADED", function(){TBL.createRow("search", null, {fld_1: {mode: 40, value: "<xsl:value-of select="@field" />"}, fld_2: {mode: 41, value: "<xsl:value-of select="@criteria" />"}, fld_3: {mode: 42, value: "<xsl:value-of select="." />"}});});
		    		      </xsl:for-each>
		    		    </script>
		        </tbody>
		      </table>
	      </td>
      	      <td nowrap="nowrap" valign="top">
    	          <span class="button pointer">
    	            <xsl:attribute name="onclick">javascript: TBL.createRow('search', null, {fld_1: {mode: 40}, fld_2: {mode: 41}, fld_3: {mode: 42}});</xsl:attribute>
                  <img border="0" title="Add Criteria" alt="Add Criteria" class="button" src="/ods/images/icons/add_16.png" /> Add
    	          </span>
      	      </td>
     	      </tr>
     	    </table>
     	  </td>
	    </tr>
	    <tr>
        <th colspan="2" style="background-color: #EAEAEE; text-align: center;">Actions</th>
	    </tr>
	    <tr>
	      <td colspan="2">
		      <table style="width: 100%;" cellspacing="0">
		        <tr>
		          <td width="100%">
      		      <table id="action_tbl" class="form-list" style="width: 100%;" cellspacing="0">
		        <thead>
		          <tr>
		            <th id="action_th_0" width="50%">Action</th>
		            <th id="action_th_1" width="50%">Value</th>
		            <th id="action_th_2" width="1%"><xsl:call-template name="nbsp"/></th>
		          </tr>
		        </thead>
		        <tbody id="action_tbody">
      		          <tr id="action_tr_no">
      		            <td colspan="3">No Actions</td>
		          </tr>
		    		    <script type="text/javascript">
						      <xsl:for-each select="actions/entry">
      	                OAT.MSG.attach(OAT, "PAGE_LOADED", function(){TBL.createRow('action', null, {fld_1: {mode: 45, value: '<xsl:value-of select="@action" />'}, fld_2: {mode:46, value: '<xsl:value-of select="." />'}});});
		    		      </xsl:for-each>
		    		    </script>
		        </tbody>
		      </table>
	      </td>
      	      <td nowrap="nowrap" valign="top">
    	          <span class="button pointer">
    	            <xsl:attribute name="onclick">javascript: TBL.createRow('action', null, {fld_1: {mode: 45}, fld_2: {mode: 46}});</xsl:attribute>
                  <img border="0" title="Add Action" alt="Add Action" class="button" src="/ods/images/icons/add_16.png" /> Add
    	          </span>
      	      </td>
     	      </tr>
     	    </table>
     	  </td>
	    </tr>
      <tfoot>
        <tr>
          <th colspan="2">
            <xsl:call-template name="make_submit">
              <xsl:with-param name="name">fa_save</xsl:with-param>
              <xsl:with-param name="value">Save</xsl:with-param>
              <xsl:with-param name="alt">Save</xsl:with-param>
            </xsl:call-template>
            <xsl:call-template name="make_submit">
              <xsl:with-param name="name">fa_cancel</xsl:with-param>
              <xsl:with-param name="value">Cancel</xsl:with-param>
              <xsl:with-param name="alt">Cancel</xsl:with-param>
            </xsl:call-template>
          </th>
        </tr>
      </tfoot>
    </table>
  </xsl:template>

</xsl:stylesheet>
