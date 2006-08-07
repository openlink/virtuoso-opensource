<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2006 OpenLink Software
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

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:v="http://www.openlinksw.com/vspx/" xmlns:vm="http://www.openlinksw.com/vspx/macro">
  <xsl:template match="vm:tab">
    <ul class="menu">
      <li>
	<vm:item name="Preferences" control="settings.vspx"/>
      </li>
      <li>
	<vm:item name="Upstreams" control="upstream.vspx"/>
      </li>
    </ul>
  </xsl:template>
  <xsl:template match="vm:item">
    <v:button name="{@name}_button" value="{@name}" action="simple" style="url">
      <v:on-post>
	self.vc_redirect(sprintf ('<xsl:value-of select="@control"/>?cluster=%U', (select CLUSTERNAME from WV..CLUSTERS where self.cluster = CLUSTERID)));
      </v:on-post>
    </v:button>
  </xsl:template>
      
  <xsl:template match="vm:setting-section">
   <tr>
      <td>
	<div class="wiki-settings-templates">
	  <h2><xsl:value-of select="@name"/></h2>
	  <p>
	    <table width="100%">
	      <xsl:apply-templates/>
	    </table>
	  </p>
	</div>
      </td>
    </tr>
  </xsl:template>
  <xsl:template match="vm:setting-parameter">
    <tr>
      <th width="50%"><xsl:value-of select="@name"/></th>
      <td>
	<xsl:apply-templates/>
      </td>
    </tr>
  </xsl:template>
  <xsl:template match="vm:page">
    <v:variable name="cluster" type="int"/>
    <v:on-init>
      <![CDATA[
	       self.sid := get_keyword('sid', params);
	       self.realm := get_keyword('realm', params, 'wiki');
	       set isolation='committed';
	       if (get_keyword ('cluster', params) is not null)
	         self.cluster := (select CLUSTERID from WV..CLUSTERS where CLUSTERNAME = get_keyword ('cluster', params));
      ]]>
    </v:on-init>
    <v:variable name="vspx_user" type="varchar" default="'WikiGuest'"/>
    <html>
      <head>
	<title>oWiki | <xsl:value-of select="@title"/></title>
	<link rel="stylesheet" href="Skins/default/default.css"/>
      </head>
      <xsl:apply-templates/>
    </html>
  </xsl:template>
  <xsl:template match="vm:upstream-list">
    <v:data-set
	name="ds_tables"
	sql="select UP_NAME, UP_ID from WV..UPSTREAM where UP_CLUSTER_ID = :self.cluster"
              nrows="10"
              scrollable="1"
              cursor-type="keyset"
              edit="0"
              width="80"
              initial-enable="1">
      <v:template name="temp_ds_tables_header" type="simple" name-to-remove="table" set-to-remove="bottom">
	<table>
	</table>
      </v:template>
      <v:template name="temp_ds_tables_repeat" type="repeat" name-to-remove="" set-to-remove="">
	<v:template name="temp_ds_tables_empty" type="if-not-exists" name-to-remove="table" set-to-remove="both">
	  <table>
	    <tr>
	      <td colspan="10" class="Attention">No upstream configured</td>
	    </tr>
	  </table>
	</v:template>
	<v:template name="temp_ds_tables_browse" type="browse" set-to-remove="both">
	  <table>
	    <tr>
	      <td>
		<v:label name="l_upstream_name" value="--(control.vc_parent as vspx_row_template).te_rowset[0]" format="%s"/>
		<v:button name="edit_btn" value="Edit" action="simple">
		  <v:on-post>
		    <![CDATA[
			     self.vc_redirect(sprintf ('upstream.vspx?cluster=%U&upstream=%U', (select CLUSTERNAME from WV..CLUSTERS where self.cluster = CLUSTERID), (control.vc_parent as vspx_row_template).te_rowset[0]));
		    ]]>
		  </v:on-post>
		</v:button>
		<v:button name="delete_btn" value="Delete" action="simple">
		  <v:on-post>
		    <![CDATA[
			     --self.vc_redirect(sprintf ('delete.vspx?topic=%ld', self.topic.ti_id));
			     delete from WV..UPSTREAM where UP_ID = (control.vc_parent as vspx_row_template).te_rowset[1];
			     self.vc_data_bind(e);
		    ]]>
		  </v:on-post>
		</v:button>
	      </td>
	    </tr>
	  </table>
	</v:template>
      </v:template>
    </v:data-set>
  </xsl:template>
    
  <xsl:template match="vm:upstream-edit">
    <v:variable name="message_text" type="varchar" default="''"/>
    <v:variable name="defval" type="any"/>
    <v:variable name="upstream" type="varchar" param-name="upstream"/>
    <v:variable name="name_fixed" type="varchar"/>
    <v:on-init>
	<![CDATA[
	       self.name_fixed := '@@hidden@@';
	       if (get_keyword ('upstream', params) is not null)
	         {
	           self.defval := (select vector ('id', UP_ID, 'name', UP_NAME, 'uri', UP_URI, 'user', UP_USER, 'passwd', UP_PASSWD, 'rcluster', UP_RCLUSTER) from WV..UPSTREAM where UP_NAME=get_keyword('upstream', params));
		   --self.name_fixed := 'disabled';
		 }
	       else
	         self.defval := vector ();
	]]>
    </v:on-init>
    <v:form name="upstrem_edit_form" type="simple" method="POST">
      <v:template name="upstream_edit_simple" type="simple">
	<div class="message">
	  <v:label name="message" value="--self.message_text"/>
	</div>
	<table class="wiki-settings">
	  <tr>
	    <th>name</th>
	    <td><v:text name="upstream_name" value="--get_keyword ('name', self.defval, '')" xhtml_disabled="--self.name_fixed"/></td>
	  </tr>
	  <tr>
	    <th>URL</th>
	    <td><v:text name="upstream_url" value="--get_keyword ('uri', self.defval, '')" /></td>
	  </tr>
	  <tr>
	    <th>user</th>
	    <td><v:text name="upstream_user" value="--get_keyword ('user', self.defval, '')"/></td>
	  </tr>
	  <tr>
	    <th>password</th>
	    <td><v:text name="upstream_password" value="--get_keyword ('passwd', self.defval, '')"/></td>
	  </tr>
	  <tr>
	    <th>target cluster</th>
	    <td><v:text name="upstream_cluster" value="--get_keyword ('rcluster', self.defval, '')"/></td>
	  </tr>
	  <v:hidden name="id2" value="--get_keyword('id', self.defval)"/>
          <tr>
	    <td align="left">
	      <v:button name="add" action="submit" value="Add/Update Upstream">
		<v:on-post>
		  <![CDATA[
			   dbg_obj_print (self.defval);
--			   dbg_obj_print (self.upstream_name.ufl_value);
--			   dbg_obj_print (self.upstream_url.ufl_value);
--			   dbg_obj_print (self.upstream_user.ufl_value);
--			   dbg_obj_print (self.upstream_password.ufl_value);
		   declare upid int;
		   upid := (select UP_ID from WV..UPSTREAM where UP_CLUSTER_ID = self.cluster and UP_NAME = self.upstream_name.ufl_value);
                     if (upid is null)
		       {
		         insert into WV..UPSTREAM (UP_CLUSTER_ID, UP_NAME, UP_URI, UP_USER, UP_PASSWD, UP_RCLUSTER)
			     values (
			        self.cluster,
			        self.upstream_name.ufl_value,
				self.upstream_url.ufl_value,
				self.upstream_user.ufl_value,
				self.upstream_password.ufl_value,
				self.upstream_cluster.ufl_value);
			   self.message_text := 'upstream added';
		       }
		     else
		       {
			 update WV..UPSTREAM
			   set UP_NAME = self.upstream_name.ufl_value,
			       UP_URI = self.upstream_url.ufl_value,
			       UP_USER = self.upstream_user.ufl_value,
			       UP_PASSWD = self.upstream_password.ufl_value,
			       UP_RCLUSTER = self.upstream_cluster.ufl_value
			   where UP_ID = upid;
			   self.message_text := 'upstream updated';
			}
		     self.vc_data_bind (e);
		  ]]>
		</v:on-post>
	      </v:button>
	    </td>
	  </tr>
	</table>
      </v:template>
    </v:form>
  </xsl:template>
  
  <xsl:template match="vm:main-topic">
    <v:button name="main_topic_redirect_btn" value="Back to the topic" xhtml_title="Cancel" xhtml_alt="Cancel" style="url" action="simple">
      <v:on-post>
	<![CDATA[
		 self.vc_redirect(sprintf('../main/%U/', (select CLUSTERNAME from WV..CLUSTERS where CLUSTERID = self.cluster)));
		 return;
	]]></v:on-post>
    </v:button>
  </xsl:template>
	<xsl:template match="vm:wiki-login">
		<v:template name="login" type="simple">
			<v:before-data-bind><![CDATA[
			  self.vspx_user := coalesce((select vs_uid from
                 			VSPX_SESSION where vs_sid = self.sid and vs_realm = self.realm), 'WikiGuest');
        ]]></v:before-data-bind>
			<v:form name="login_form" method="POST" type="simple">
				<div class="login">
					<?vsp if (not exists (select * from
                 			VSPX_SESSION where vs_sid = self.sid and vs_realm = self.realm))                 
            {
			  ?>
					<img src="images/lock_16.png" alt="User is not authenticated" title="User is not authenticated"/>
			    User is not authenticated
			    <v:button action="submit" name="login_button" value="Login">
						<v:on-post><![CDATA[
			          http_request_status ('HTTP/1.1 302 Found');
			          http_header (sprintf ('Location: login.vsp?page=%U&command=login\r\n', self.source_page));
			        ]]></v:on-post>
					</v:button>
					<?vsp }
			  else
			    {
			  ?>
					<img src="images/user_16.png" alt="User logged in" title="User logged in"/>
                                        <v:button action="simple" name="user_home" value="--self.vspx_user" style="url">
						<v:on-post><![CDATA[
                                                  declare wa_home_link varchar;
                                                  wa_home_link := registry_get ('wa_home_link');
                                                  if (isinteger(wa_home_link))
                                                    wa_home_link :='/wa/';
                                                  self.vc_redirect (wa_home_link || '/uhome.vspx');
                                                  return;
						]]></v:on-post>
					</v:button>
					<v:button action="submit" name="logout_button" value="Logout">
						<v:on-post><![CDATA[
						  delete from VSPX_SESSION 
						    where vs_sid = self.sid 
						    and vs_realm = self.realm;
						  http_request_status ('HTTP/1.1 302 Found');
                                                  http_header (sprintf ('Location: ../main/%U/\r\n', self.cluster));
						]]></v:on-post>
					</v:button>
					<?vsp }
          ?>
				</div>
			</v:form>
		</v:template>
	</xsl:template>
	<xsl:template match="vm:virtuoso-info">
          <div id="virtuoso-info">
            <ul class="left_nav">
              <li class="xtern"><a href="http://www.openlinksw.com">OpenLink Software</a></li>
              <li class="xtern"><a href="http://www.openlinksw.com/virtuoso">Virtuoso Web Site</a></li>
              <li class="xtern"><img src="images/PoweredByVirtuoso.gif"/></li>
            </ul>
            <div style="font-size: 50%">
              Server version: <?vsp http (sys_stat('st_dbms_ver')); ?>
              <br/>
              Server build date: <?vsp http(sys_stat('st_build_date')); ?>
              <br/>
            </div>
          </div>
        </xsl:template>
        <xsl:template match="vm:empty-body">
          <body>             
           <div id="page">
            <div class="login-area">
              <vm:wiki-login/>
            </div>
            <xsl:apply-templates/>
          </div>
          </body>
        </xsl:template>
        <xsl:template match="vm:body">
          <body>            
           <div id="page">
            <vm:logo/>
            <div class="login-area">
              <vm:wiki-login/>
            </div>
              <xsl:apply-templates/>
            <vm:virtuoso-info/>
           <!-- 
             <div class="aux-info-area">
            </div> -->
            </div>
          </body>
        </xsl:template>
        <xsl:template match="vm:dialog-body">
          <body>            
            <div class="working-area">
              <xsl:apply-templates/>
            </div>
          </body>
        </xsl:template>
        <xsl:template match="vm:logo">
          <img src="images/wikibanner_sml.jpg"></img>
        </xsl:template>
        <xsl:template match="vm:back-button">
          <v:button xhtml_class="real_button" action="simple" name="cancel" value="Back to the topic" xhtml_title="Cancel" xhtml_alt="Cancel">
            <v:on-post><![CDATA[   
              self.vc_redirect('../main/' || self.source_page);
            ]]></v:on-post>
          </v:button>
        </xsl:template>
        <xsl:template match="vm:no-button">
          <v:button name="no" value="No" action="simple">
            <v:on-post><![CDATA[
              self.vc_redirect ('../main/' || self.source_page);
              return;
            ]]>
          </v:on-post>
        </v:button>
      </xsl:template>

</xsl:stylesheet>
