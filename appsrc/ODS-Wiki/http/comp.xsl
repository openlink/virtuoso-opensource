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
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:v="http://www.openlinksw.com/vspx/" xmlns:vm="http://www.openlinksw.com/vspx/macro">
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
        <xsl:template match="vm:body">
          <body>            
            <vm:logo/>
            <div class="login-area">
              <vm:wiki-login/>
            </div>
            <div class="aux-info-area">
              <vm:virtuoso-info/>
            </div>
            <div class="working-area">
              <xsl:apply-templates/>
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
