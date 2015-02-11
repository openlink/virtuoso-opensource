<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2015 OpenLink Software
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
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
  xmlns:v="http://www.openlinksw.com/vspx/"
  xmlns:vm="http://www.openlinksw.com/vspx/ods/">

  <xsl:template match="vm:body[not vm:login]">
    <vm:home-init />
    <vm:login redirect="uhome.vspx"/>
    <xsl:apply-templates />
  </xsl:template>

  <xsl:template match="vm:home-init">
    <v:variable name="ufid" type="integer" default="0"/>
    <v:variable name="isowner" type="integer" default="0"/>
    <v:variable name="is_org" type="integer" default="0"/>
    <v:variable name="visb" type="any" default="null"/>
    <v:variable name="arr" type="any" default="null" persist="temp"/>
    <v:variable name="friends_name" type="varchar" default="''"/>
    <v:variable name="sne_id" type="int" default="0" />
    <v:variable name="notags" type="integer" default="0"/>
    <v:local-variable name="lvsn">
      <v:before-data-bind>
        <![CDATA[

          if (self.fname is null)
            self.fname := self.u_name;

	  {
	    whenever not found goto nf_user;
	    select U_ID into self.ufid from SYS_USERS where U_NAME = self.fname;
	  }

	  if (0)
	    {
              declare tmp_uid varchar;
	      declare exit handler for not found
	      {
	        signal ('22023', sprintf ('The user "%s" does not exist.', self.fname));
	      };
	      nf_user:
	      select U_NAME, U_ID into tmp_uid, self.ufid
              from SYS_USERS, WA_USER_INFO
             where WAUI_U_ID = U_ID and WAUI_NICK = self.fname;
	      self.fname := tmp_uid;
	    }
	  if (not exists (select 1 from WA_USER_INFO where WAUI_U_ID = self.ufid))
	    {
	      insert into WA_USER_INFO (WAUI_U_ID) values (self.ufid);
	    }

          self.visb := WA_USER_VISIBILITY(self.fname);

          if (self.ufid = self.u_id)
            self.isowner := 1; --user is the owner of the page.

	  self.arr := WA_GET_USER_INFO (self.u_id, self.ufid, self.visb, self.isowner);
          self.is_org := self.arr[49];
        ]]>
      </v:before-data-bind>
      <v:after-data-bind>
        <![CDATA[

          declare id any;
          if (self.isowner)
            id := self.u_name;
          else
            id := self.fname;

          self.friends_name := (select coalesce (u_full_name, u_name) from sys_users where u_name = id);
          if (not length (self.friends_name))
            self.friends_name := id;

          select sne_id into self.sne_id from sn_entity where sne_name = id;
        ]]>
      </v:after-data-bind>
    </v:local-variable>
  </xsl:template>

  <xsl:template match="vm:user-dashboard">
    <v:template name="userdashboard" type="simple" condition="self.isowner">
      <tr><th><v:label value="--self.friends_name" />'s Dashboard</th></tr>
      <tr>
	<td id="mainarea">
	  <table width="100%"  border="0" cellpadding="0" cellspacing="0" id="infoarea1">
	    <tr>
	      <td width="50%" align="right" valign="top">
		<vm:dash-blog-summary />
	      </td>
	      <td width="50%" valign="top">
		<vm:dash-enews-summary/>
	      </td>
	    </tr>
	  </table>
	</td>
      </tr>
    </v:template>
  </xsl:template>

  <xsl:template match="vm:page-hd">
    <h1 class="page_hd">
      <xsl:apply-templates/>
    </h1>
  </xsl:template>

  <xsl:template match="vm:friends-name">
    <v:label value="--self.friends_name" render-only="1" format="%s" />
  </xsl:template>

  <!-- url="-#-sprintf ('ufoaf.xml?:sne=%d', self.sne_id)" -->
  <xsl:template match="vm:foaf-link">
    <v:url name="u2"
           value='<img src="images/foaf.gif" border="0" alt="FOAF" />'
           format="%s"
	url="--WA_LINK (1, sprintf ('/dataspace/%s/%s/foaf.rdf', wa_identity_dstype(case when self.isowner then self.u_name else self.fname end), case when self.isowner then self.u_name else self.fname end))"
	/>
  </xsl:template>

  <xsl:template match="vm:vcard-link">
    <v:url name="u1"
           value='<img src="images/vcard.gif" border="0" alt="vCard" />'
           format="%s"
           url="--sprintf ('sn_user_export.vspx?ufid=%d&amp;ufname=%s', self.ufid, self.fname)"
    />
  </xsl:template>

  <xsl:template match="vm:sioc-link">
    <v:url name="u1"
           value='<img src="images/sioc_button.png" border="0" alt="SIOC" />'
           format="%s"
           url="--WA_LINK (1, sprintf ('/dataspace/%s/sioc.rdf', self.fname))" xhtml_target="_blank"
    />
  </xsl:template>

  <xsl:template match="vm:geo-link">
    <?vsp if (1=0 and self.e_lat is not null and self.e_lng is not null) { ?>
      <v:url name="u1"
             value='<img src="http://i.geourl.org/80x15/simple.png" border="0" alt="GeoURL" />'
             format="%s"
             url="--sprintf ('http://geourl.org/near?p=%U', WA_LINK (1, sprintf ('/dataspace/%s', self.fname)))" xhtml_target="_blank"
      />
    <?vsp } ?>
  </xsl:template>

  <xsl:template match="vm:add-to-friends">
      <?vsp if (not (self.isowner = 1) and
                not exists (select 1
                              from SN_FRENDS
                              where FROM_U_NAME = self.u_name and
                                    TO_U_NAME = self.fname) and
                not exists (select 1 from SN_FRENDS
                              where FROM_U_NAME = self.fname and
                                    TO_U_NAME = self.u_name)) {
      ?>
      <v:label value="Do you know this person?" render-only="1" />
	&amp;nbsp;
      <v:url name="addtof"
             value="--'Add to friends.'" format="%s"
             url="--sprintf('sn_make_inv.vspx?fmail=%s',coalesce(self.arr[4],''))"
             xhtml_class="profile_tab"
      />
      <?vsp
      } else {
      ?>
       You are already connected to <?V self.fname ?>
      <?vsp
       }
      ?>
  </xsl:template>

  <xsl:template match="vm:user-apps">
    <div class="widget w_user_apps">
      User applications
    </div>
  </xsl:template>

  <xsl:template match="vm:user-details">
    <v:template name="user_details" type="simple" enabled="1">
<?vsp
    {
      declare pg any;
      pg := atoi(get_keyword('page', control.vc_page.vc_event.ve_params, '1'));
?>
            <div id="p" class="c1 vcard" style="margin: 7px;">
              <div class="tabs">
                <div onclick="javascript: showTab('p', 5, 0);" class="tab activeTab" id="p_tab_0"><?V case when self.is_org then 'Organization' else 'Personal' end ?></div>
                <div onclick="javascript: showTab('p', 5, 1);" class="tab" id="p_tab_1">Contact</div>
                <div onclick="javascript: showTab('p', 5, 2);" class="tab" id="p_tab_2">Home</div>
                <div onclick="javascript: showTab('p', 5, 3);" class="tab" id="p_tab_3">Business</div>
                <div onclick="javascript: showTab('p', 5, 4);" class="tab" id="p_tab_4">Data Explorer</div>
              </div>
              <div class="contents">
                <div id="p_content_0" class="tabContent">
                          <table>
                            <tr>
                      <th><v:label value="Account:" /></th>
                      <td><span class="nickname"><v:label value="--coalesce(self.fname,'')" /></span></td>
                            </tr>
			    <?vsp if (length (self.arr[37])) { ?>
                            <tr>
                      <th><v:label value="Photo:" /></th>
                      <td><img class="photo" src="<?V self.arr[37] ?>" width="64" border="0" /></td>
			    </tr>
			    <?vsp } ?>
                            <tr>
                      <th><v:label value="Title:" enabled="--case when coalesce(self.arr[0],'') <> '' then 1 else 0 end" /></th>
                      <td><span class="honorific-prefix"><v:label value="--coalesce(self.arr[0],'')" /></span></td>
                            </tr>
                            <tr>
                      <th><v:label value="First Name:" enabled="--case when coalesce(self.arr[1],'') <> '' then 1 else 0 end" /></th>
                      <td><span class="given-name"><v:label value="--coalesce(self.arr[1],'')" /></span></td>
                            </tr>
                            <tr>
                      <th><v:label value="Last Name:" enabled="--case when coalesce(self.arr[2],'') <> '' then 1 else 0 end" /></th>
                      <td><span class="family-name"><v:label value="--coalesce(self.arr[2],'')" /></span></td>
                            </tr>
                            <tr>
                      <th><v:label value="Full Name:" enabled="--case when coalesce(self.arr[3],'') <> '' then 1 else 0 end" /></th>
                      <td><span class="fn"><v:label value="--coalesce(self.arr[3],'')" /></span></td>
                            </tr>
                    <?vsp if (length (self.arr[4])) { ?>
                            <tr>
                      <th><v:label value="E-mail:" /></th>
                      <td><span class="email"><v:url name="lemail1" value="--coalesce(self.arr[4],'')" url="--concat ('mailto:', self.arr[4])" /></span></td>
			    </tr>
			    <?vsp } ?>
                            <tr>
                      <th><v:label value="Gender:" enabled="--case when coalesce(self.arr[5],'') <> '' and equ (self.is_org, 0) then 1 else 0 end" /></th>
                      <td><v:label value="--coalesce(self.arr[5],'')" /></td>
                            </tr>
                            <tr>
                      <th><v:label value="Birthday:" enabled="--case when coalesce(self.arr[6],'') <> '' then 1 else 0 end" /></th>
                      <td><span class="bday"><v:label value="--coalesce(self.arr[6],'')" /></span></td>
                            </tr>
			    <?vsp
                      if (length (self.arr[7])) {
			    ?>
                            <tr>
                      <th valign="top"><v:label value="Personal Webpage:" /></th>
                      <td>
                        <v:url name="lwpage1" value="--coalesce(self.arr[7],'')" url="--self.arr[7]" xhtml_target="_blank" xhtml_class="url"/>
                        <br />
                        <img src="data:image/jpg;base64,<?V ODS.ODS_API.qrcode(self.arr[7]) ?>"/>
                      </td>
                            </tr>
                    <?vsp
                      }
			    if (length (self.arr[8])) {
			    ?>
                            <tr>
                      <th valign="top"><v:label value="Other Identity URIs (synonyms):" /></th>
			      <td>
				  <?vsp
                        for select Y from DB.DBA.ODS_USER_IDENTIY_URLS (uname) (Y varchar) sub where uname = self.fname do
				      {
					  ?>
                          <a href="<?V Y ?>" target="_blank"><?V Y ?></a><br />
					  <?vsp
				       }
				  ?>
			      </td>
                            </tr>
			    <?vsp } ?>
                            <v:template name="umsign" type="simple" enabled="--case when coalesce(self.arr[9],'') <> '' then 1 else 0 end">
                            <tr>
                        <th><v:label value="Mail Signature:" /></th>
                        <td><pre><v:label value="--coalesce(self.arr[9],'')" /></pre></td>
                            </tr>
                            </v:template>
                            <v:template name="usummary" type="simple" enabled="--case when coalesce(self.arr[33],'') <> '' then 1 else 0 end">
                            <tr>
                        <th><v:label value="Summary:" /></th>
                        <td><pre><v:label value="--coalesce(self.arr[33],'')" /></pre></td>
                            </tr>
                            </v:template>
			    <?vsp
			      if (coalesce(self.arr[44],'') <> '')
			        {
		 	    ?>
                            <tr>
                        <th><v:label value="" />Favorite Books:</th>
                        <td><v:label value="--coalesce(self.arr[44],'')" /></td>
                            </tr>
			    <?vsp
			        }
			      if (coalesce(self.arr[45],'') <> '')
			        {
		 	    ?>
                            <tr>
                        <th><v:label value="" />Favorite Music:</th>
                        <td><v:label value="--coalesce(self.arr[45],'')" /></td>
                            </tr>
			    <?vsp
			        }
			      if (coalesce(self.arr[46],'') <> '')
			        {
		 	    ?>
                            <tr>
                        <th><v:label value="" />Favorite Movies:</th>
                        <td><v:label value="--coalesce(self.arr[46],'')" /></td>
                            </tr>
			    <?vsp
			        }
			      if (coalesce(self.arr[43],'') <> '')
			        {
			    ?>
			    <tr>
                      <th>Audio:</th>
                      <td><a href="<?V self.arr[43] ?>"><img border="0" alt="Owner audio" src="images/icons/audio_16.gif" /></a></td>
			    </tr>
			    <?vsp
			        }
		            ?>

                            <v:form name="upl" type="simple" method="POST" action="uhome.vspx">
                            <v:template name="UserAssignedTags" type="simple" enabled="--case when (self.isowner = 1 or isnull(self.u_id)) then 0 else 1 end">
                              <tr>
                          <th><v:label value="Tags:" enabled="--case when coalesce(WA_USER_TAG_GET(self.fname),'') <> '' then 1 else 0 end" /></th>
                          <td><span class="tags"><v:label value="--coalesce(WA_USER_TAG_GET(self.fname),'')" /></span></td>
                              </tr>
                              <tr>
                          <th nowrap="nowrap">
                            <v:label value="--sprintf('My tags for %s', self.fname)" />
				      <span class="explain"> (comma separated list of keywords)</span>
				</th>
                                <td>
                                  <v:button value="Tag" action="simple" name="bt_tag1" enabled="--case when( WA_USER_IS_TAGGED(self.u_id, self.ufid) = 1 or self.notags = 1) then 0 else 1 end">
                                    <v:on-post>
                                      if (not self.vc_is_valid)
                                        return;
                                      self.notags := 1;
                                      self.upl.vc_data_bind(e);
                                    </v:on-post>
                                  </v:button>
                                  <v:template name="AssignedTags" type="simple" enabled="--case when( WA_USER_IS_TAGGED(self.u_id, self.ufid) = 1 or self.notags = 1) then 1 else 0 end">
                                    <v:textarea name="s_tags"
                                            value="--WA_USER_TAGS_GET(self.u_id,self.ufid)"
                                            xhtml_cols="50"
                                            xhtml_rows="5"
                                            xhtml_tabindex="12"/>
                                    <v:button value="Change Tags" action="simple" name="bt_tags_ch1">
                                      <v:on-post>
                                        if (not self.vc_is_valid)
                                          return;
                                        self.notags := 0;

                                        declare tag varchar;
                                        declare tid integer;

                                        tag := WA_TAG_PREPARE(self.s_tags.ufl_value);
                                        if (not WA_VALIDATE_TAGS(tag))
                                        {
          		                  self.vc_is_valid := 0;
          		                  self.vc_error_message := 'The Tags expression is not valid.';
          		                  return;
          		                };
                                        WA_USER_TAG_SET(self.u_id, self.ufid, tag);
                                        self.upl.vc_data_bind(e);
                                      </v:on-post>
                                    </v:button>
                                  </v:template>
                                </td>
                              </tr>
                            </v:template>
                            </v:form>
                            <v:template name="UserOwnTags" type="simple" enabled="--case when self.isowner = 1 then 1 else 0 end">
                              <tr>
                        <th><v:label value="Tags:" enabled="--case when coalesce(WA_USER_TAG_GET(self.u_name),'') <> '' then 1 else 0 end" /></th>
                        <td><v:label value="--coalesce(WA_USER_TAG_GET(self.u_name),'')" /></td>
                              </tr>
                            </v:template>
			         <?vsp
			          -- uncomment this for old behaviour
				  if (0)
				  {
				  declare sneid, for_user any;
				  for_user := coalesce (self.fname, self.u_name);
				  declare exit handler for not found { signal ('22023', 'Internal error, no such user'); };
				  select sne_id into sneid from sn_entity where sne_name = for_user;
				  if (exists (select 1 from sn_related where (snr_from = sneid or snr_to = sneid)))
				  {
				  ?>
                            <tr>
                      <th valign="top"><v:label value="--concat(coalesce(self.fname,''),'''s friends')" /></th>
                              <td>
				<table cellpadding="0" cellspacing="0">
				  <?vsp
				  declare i int;
				  i := 0;
				  for select top 6 sne_name, U_FULL_NAME from
				  (
				    select top 6 sne_name, U_FULL_NAME from sn_related, sn_entity, SYS_USERS where snr_to = sne_id and snr_from = sneid and U_NAME = sne_name
				    union all
				    select top 6 sne_name, U_FULL_NAME from sn_related, sn_entity, SYS_USERS where snr_from = sne_id and snr_to = sneid and U_NAME = sne_name
                            ) sub do
				    {
					   if (i >= 5)
					     goto next;
				  ?>
		                    	  <tr>
		                    	    <td>
						<a href="&lt;?V wa_expand_url('/dataspace/'|| wa_identity_dstype(sne_name)||'/'|| sne_name ||'#this', self.login_pars)?&gt;"><?V wa_utf8_to_wide (coalesce (U_FULL_NAME, sne_name)) ?></a>
		                    	    </td>
					  </tr>
				  <?vsp
					  next:;
				            i := i + 1;
					  }
				  if (i > 5)
				    {
				  ?>
                                  <tr>
                                    <td>
                                      <v:url name="viewall" value="--sprintf('View All of %s''s friends ', coalesce(self.fname,'') )" format="%s" url="--sprintf('sn_connections.vspx?ufname=%U', self.fname)" xhtml_class="profile_tab"/>
                                    </td>
				  </tr>
				  <?vsp
				    }
				  ?>
                                </table>
                              </td>
                            </tr>
				  <?vsp
				  }
				  }
				  ?>
                          </table>
                </div>
                <div id="p_content_1" class="tabContent" style="display: none;">
                          <table>
                           <tr>
                      <th><v:label value="ICQ Number:" enabled="--case when coalesce(self.arr[10],'') <> '' then 1 else 0 end" /></th>
                      <td><v:label value="--coalesce(self.arr[10],'')" /></td>
                            </tr>
			    <?vsp if (length (self.arr[11])) { ?>
                            <tr>
                      <th><v:label value="Skype ID:" /></th>
                      <td><v:url name="1skype1" value="--coalesce(self.arr[11],'')" url="--concat ('callto:', self.arr[11])" /></td>
                            </tr>
			    <?vsp } ?>
                            <tr>
                      <th><v:label value="AIM Name:" enabled="--case when coalesce(self.arr[12],'') <> '' then 1 else 0 end" /></th>
                      <td><v:label value="--coalesce(self.arr[12],'')" /></td>
                            </tr>
                            <tr>
                      <th><v:label value="Yahoo! ID:" enabled="--case when coalesce(self.arr[13],'') <> '' then 1 else 0 end" /></th>
                      <td><v:label value="--coalesce(self.arr[13],'')" /></td>
                            </tr>
                            <tr>
                      <th><v:label value="MSN Messenger:" enabled="--case when coalesce(self.arr[14],'') <> '' then 1 else 0 end" /></th>
                      <td><v:label value="--coalesce(self.arr[14],'')" /></td>
                            </tr>
                          </table>
                </div>
                <div id="p_content_2" class="tabContent adr" style="display: none;">
                  <span class="type" style="display: none;">home</span>
                          <table>
                            <tr>
                      <th><v:label value="Country:" enabled="--case when coalesce(self.arr[16][2],'') <> '' then 1 else 0 end" /></th>
                      <td><span class="country-name"><v:label value="--coalesce(self.arr[16][2],'')" /></span></td>
                            </tr>
                            <tr>
                      <th><v:label value="State/Province:" enabled="--case when coalesce(self.arr[16][1],'') <> '' then 1 else 0 end" /></th>
                      <td><span class="region"><v:label value="--coalesce(self.arr[16][1],'')" /></span></td>
                            </tr>
                            <tr>
                      <th><v:label value="City/Town:" enabled="--case when coalesce(self.arr[16][0],'') <> '' then 1 else 0 end" /></th>
                      <td><span class="locality"><v:label value="--coalesce(self.arr[16][0],'')" /></span></td>
                            </tr>
                            <tr>
                      <th><v:label value="Zip/Postal Code:" enabled="--case when coalesce(self.arr[15][2],'') <> '' then 1 else 0 end" /></th>
                      <td><span class="postal-code"><v:label value="--coalesce(self.arr[15][2],'')" /></span></td>
                            </tr>
                            <tr>
                      <th><v:label value="Address1:" enabled="--case when coalesce(self.arr[15][0],'') <> '' then 1 else 0 end" /></th>
                      <td><span class="street-address"><v:label value="--coalesce(self.arr[15][0],'')" /></span></td>
                            </tr>
                            <tr>
                      <th><v:label value="Address2:" enabled="--case when coalesce(self.arr[15][1],'') <> '' then 1 else 0 end" /></th>
                      <td><span class="extended-address"><v:label value="--coalesce(self.arr[15][1],'')" /></span></td>
                            </tr>
                            <tr>
                      <th><v:label value="Time-Zone:" enabled="--case when coalesce(self.arr[17],'') <> '' then 1 else 0 end" /></th>
                      <td><span class="tz"><v:label value="--coalesce(self.arr[17],'')" /></span></td>
			    </tr>
                    <?vsp if (self.arr[39] is not null) { ?>
                            <tr>
                      <th><v:label value="Location:" /></th>
			      <td>
				<v:url name="wa_map"
                               value="--sprintf('latitude: %.6f, longitude: %.6f', coalesce(self.arr[39],0), coalesce(self.arr[40],0))"
                               format="%s"
			         url="--sprintf ('wa_maps.vspx?ufname=%U', self.fname)" />
			      </td>
			    </tr>
                    <?vsp } ?>
                            <tr>
                      <th><v:label value="Phone:" enabled="--case when coalesce(self.arr[18][0],'') <> '' then 1 else 0 end" /></th>
                      <td><span class="tel"><v:label value="--coalesce(self.arr[18][0],'')" /></span></td>
                            </tr>
                            <tr>
                      <th><v:label value="Mobile:" enabled="--case when coalesce(self.arr[18][1],'') <> '' then 1 else 0 end" /></th>
                      <td><span class="tel"><span class="type" style="display: none;">CELL</span><v:label value="--coalesce(self.arr[18][1],'')" /></span></td>
                            </tr>
                          </table>
                </div>
                <div id="p_content_3" class="tabContent adr" style="display: none;">
                  <span class="type" style="display: none;">WORK</span>
                          <table>
                            <tr>
                      <th><v:label value="Industry:" enabled="--case when coalesce(self.arr[19],'') <> '' then 1 else 0 end" /></th>
                      <td><v:label value="--coalesce(self.arr[19],'')" /></td>
                            </tr>
                            <tr>
                      <th><v:label value="Organization:" enabled="--case when coalesce(self.arr[20],'') <> '' then 1 else 0 end" /></th>
                      <td><span class="org"><v:label value="--coalesce(self.arr[20],'')" /></span></td>
                            </tr>
                            <tr>
                      <th><v:label value="Job Title:" enabled="--case when coalesce(self.arr[21],'') <> '' then 1 else 0 end" /></th>
                      <td><v:label value="--coalesce(self.arr[21],'')" /></td>
                            </tr>
                            <tr>
                      <th><v:label value="Country:" enabled="--case when coalesce(self.arr[23][2],'') <> '' then 1 else 0 end" /></th>
                      <td><span class="country-name"><v:label value="--coalesce(self.arr[23][2],'')" /></span></td>
                            </tr>
                            <tr>
                      <th><v:label value="State/Province:" enabled="--case when coalesce(self.arr[23][1],'') <> '' then 1 else 0 end" /></th>
                      <td><span class="region"><v:label value="--coalesce(self.arr[23][1],'')" /></span></td>
                            </tr>
                            <tr>
                      <th><v:label value="City/Town:" enabled="--case when coalesce(self.arr[23][0],'') <> '' then 1 else 0 end" /></th>
                      <td><span class="locality"><v:label value="--coalesce(self.arr[23][0],'')" /></span></td>
                            </tr>
                            <tr>
                      <th><v:label value="Zip/Postal Code:" enabled="--case when coalesce(self.arr[22][2],'') <> '' then 1 else 0 end" /></th>
                      <td><span class="postal-code"><v:label value="--coalesce(self.arr[22][2],'')" /></span></td>
                            </tr>
                            <tr>
                      <th><v:label value="Address1:" enabled="--case when coalesce(self.arr[22][0],'') <> '' then 1 else 0 end" /></th>
                      <td><span class="street-address"><v:label value="--coalesce(self.arr[22][0],'')" /></span></td>
                            </tr>
                            <tr>
                      <th><v:label value="Address2:" enabled="--case when coalesce(self.arr[22][1],'') <> '' then 1 else 0 end" /></th>
                      <td><span class="extended-address"><v:label value="--coalesce(self.arr[22][1],'')" /></span></td>
                            </tr>
                            <tr>
                      <th><v:label value="Time-Zone:" enabled="--case when coalesce(self.arr[24],'') <> '' then 1 else 0 end" /></th>
                      <td><v:label value="--coalesce(self.arr[24],'')" /></td>
                            </tr>
                            <tr>
                      <th><v:label value="Phone:" enabled="--case when coalesce(self.arr[25][0],'') <> '' then 1 else 0 end" /></th>
                      <td><span class="tel"><span class="type" style="display: none;">WORK</span><v:label value="--coalesce(self.arr[25][0],'')" /></span></td>
                            </tr>
                            <tr>
                      <th><v:label value="Mobile:" enabled="--case when coalesce(self.arr[25][1],'') <> '' then 1 else 0 end" /></th>
                      <td><span class="tel"><span class="type" style="display: none;">WORK</span><span class="type" style="display: none;">CELL</span><v:label value="--coalesce(self.arr[25][1],'')" /></span></td>
                            </tr>
                            <tr>
                      <th><v:label value="VAT Reg number (EU only) or Tax ID:" enabled="--case when coalesce(self.arr[26],'') <> '' then 1 else 0 end" /></th>
                      <td><v:label value="--coalesce(self.arr[26],'')" /></td>
                            </tr>
                            <tr>
                      <th><v:label value="Career / Organization Status:" enabled="--case when coalesce(self.arr[27],'') <> '' then 1 else 0 end" /></th>
                      <td><v:label value="--coalesce(self.arr[27],'')" /></td>
                            </tr>
                            <tr>
                      <th><v:label value="No. of Employees:" enabled="--case when coalesce(self.arr[28],'') <> '' then 1 else 0 end" /></th>
                      <td><v:label value="--coalesce(self.arr[28],'')" /></td>
                            </tr>
                            <tr>
                      <th><v:label value="Are you a technology vendor:" enabled="--case when coalesce(self.arr[29],'') <> '' then 1 else 0 end" /></th>
                      <td><v:label value="--coalesce(self.arr[29],'')" /></td>
                            </tr>
                            <tr>
                      <th><v:label value="If so, what technology service do you provide:" enabled="--case when coalesce(self.arr[30],'') <> '' then 1 else 0 end" /></th>
                      <td><v:label value="--coalesce(self.arr[30],'')" /></td>
                            </tr>
                            <tr>
                      <th><v:label value="Other Technology service:" enabled="--case when coalesce(self.arr[31],'') <> '' then 1 else 0 end" /></th>
                      <td><v:label value="--coalesce(self.arr[31],'')" /></td>
                            </tr>
                            <tr>
                      <th><v:label value="Importance of OpenLink Network for you:" enabled="--case when coalesce(self.arr[32],'') <> '' then 1 else 0 end" /></th>
                      <td><v:label value="--coalesce(self.arr[32],'')" /></td>
                            </tr>
                            <tr>
                      <th><v:label value="Resume:" enabled="--case when coalesce(self.arr[34],'') <> '' then 1 else 0 end" /></th>
                      <td><pre><v:label value="--coalesce(self.arr[34],'')" render-only="1" /></pre></td>
                            </tr>
                          </table>
                </div>
                <div id="p_content_4" class="tabContent" style="display: none;">
                  <![CDATA[
                    <script type="text/javascript" src="rdfm.js"></script>
                  ]]>
                  <script type="text/javascript">
                    <![CDATA[
                      var graphIRI = "<?V WA_LINK (1, WA_USER_DATASPACE(self.fname)) ?>";
                      var fList = ["rdfmini","dimmer","grid","graphsvg","map","timeline","tagcloud","anchor","dock"];
                      ODSInitArray.push ( function () { OAT.Loader.load(fList, RDFMInit); } );
                    ]]>
                  </script>
					<div id="dock_content">
                    &nbsp;
					</div>
                </div>
              </div>
            </div>
      <?vsp } ?>
    </v:template>
  </xsl:template>


  <xsl:template match="vm:condition">
    <xsl:choose>
      <xsl:when test="@test='owner'">
          <xsl:variable name="condition" select="'self.isowner'"/>
      </xsl:when>
      <xsl:when test="@test='not-owner'">
          <xsl:variable name="condition" select="'not self.isowner'"/>
      </xsl:when>
      <xsl:when test="@test='login'">
          <xsl:variable name="condition" select="'length (self.sid)'"/>
      </xsl:when>
      <xsl:otherwise>
	<xsl:message terminate="yes">Invalid condition</xsl:message>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:processing-instruction name="vsp"> if (<xsl:value-of select="$condition"/>) { </xsl:processing-instruction>
         <xsl:apply-templates />
    <xsl:processing-instruction name="vsp"> } </xsl:processing-instruction>
  </xsl:template>


  <xsl:template match="vm:invite-link">
    <v:url name="inv_link" url="sn_make_inv.vspx">
      <xsl:attribute name="value">'<xsl:value-of select="@title"/>'</xsl:attribute>
    </v:url>
  </xsl:template>

  <xsl:template match="vm:contacts-link">
    <v:url name="inv_link" url="sn_connections.vspx?l=1">
      <xsl:attribute name="value">'<xsl:value-of select="@title"/>'</xsl:attribute>
    </v:url>
  </xsl:template>

  <xsl:template match="vm:addressbook-link">
    <?vsp
      for (select top 1 WAI_ID from DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER where WAI_TYPE_NAME = 'AddressBook' and WAI_NAME = WAM_INST and WAM_MEMBER_TYPE = 1 and WAM_USER = self.u_id) do
        http (sprintf ('<li><img src="images/icons/ods_ab_16.png" alt="Your AddressBook" /><a href="%s?sid=%s&realm=%s"> %V</a></li>', SIOC..addressbook_iri (AB.WA.domain_name (WAI_ID)), self.sid, self.realm, 'Your AddressBook'));
    ?>
  </xsl:template>

  <xsl:template match="v:template[@condition]">
      <xsl:processing-instruction name="vsp"> if (<xsl:value-of select="@condition"/>) { </xsl:processing-instruction>
         <xsl:apply-templates />
      <xsl:processing-instruction name="vsp"> } </xsl:processing-instruction>
  </xsl:template>

  <xsl:template match="v:label[@enabled][ancestor::table[@id='user_details']]">
    <xsl:processing-instruction name="vsp"> if (<xsl:value-of select="substring-after(@enabled, '--')"/>) { </xsl:processing-instruction>
      <v:label name="{@name}" value="{@value}" render-only="1">
	  <xsl:if test="@format">
	      <xsl:copy-of select="@format"/>
	  </xsl:if>
      </v:label>
    <xsl:processing-instruction name="vsp"> } </xsl:processing-instruction>
  </xsl:template>

  <xsl:template match="v:template[@enabled][ancestor::table[@id='user_details']]">
    <xsl:processing-instruction name="vsp"> if (<xsl:value-of select="substring-after(@enabled, '--')"/>) { </xsl:processing-instruction>
      <xsl:apply-templates />
    <xsl:processing-instruction name="vsp"> } </xsl:processing-instruction>
  </xsl:template>

  <xsl:template match="v:label[ not(@enabled) and not(@render-only) ]">
      <v:label name="{@name}" value="{@value}" render-only="1">
	  <xsl:if test="@format">
	      <xsl:copy-of select="@format"/>
	  </xsl:if>
      </v:label>
  </xsl:template>

  <xsl:template match="vm:user-friends">
    <div class="contacts_ctr">
      <h2>Contacts</h2>
	<ul>
<?vsp
	  {
	  declare sneid, for_user any;
	  sneid := self.sne_id;
	  {
	  declare i int;
	  i := 0;
	  for select top 100 sne_name, U_FULL_NAME, WAUI_PHOTO_URL, WAUI_HCOUNTRY, WAUI_HSTATE, WAUI_HCITY from
	  (
	    select sne_name, U_FULL_NAME, WAUI_PHOTO_URL, WAUI_HCOUNTRY, WAUI_HSTATE, WAUI_HCITY
	    from sn_related, sn_entity, SYS_USERS, WA_USER_INFO where snr_from = sneid and snr_to = sne_id and U_NAME = sne_name and U_ID = WAUI_U_ID
	    union all
	    select sne_name, U_FULL_NAME, WAUI_PHOTO_URL, WAUI_HCOUNTRY, WAUI_HSTATE, WAUI_HCITY
	    from sn_related, sn_entity, SYS_USERS, WA_USER_INFO where snr_to = sneid and snr_from = sne_id and U_NAME = sne_name and U_ID = WAUI_U_ID option (order)
            ) sub do
	    {
	      declare addr any;
	      addr := '';
	      if (length (WAUI_HCITY))
	        addr := addr || WAUI_HCITY;
              if (length (WAUI_HSTATE))
	        addr := addr || ', ' || WAUI_HSTATE;
              if (length (WAUI_HCOUNTRY))
	        addr := addr || '(' || WAUI_HCOUNTRY || ')';

	      if (not length (WAUI_PHOTO_URL))
                WAUI_PHOTO_URL := 'images/icons/user_32.png';

	  ?>
	  <li>
	      <a href="&lt;?V wa_expand_url('/dataspace/'||wa_identity_dstype(sne_name)||'/'|| sne_name ||'#this', self.login_pars)?&gt;"><?vsp if (length (WAUI_PHOTO_URL)) {  ?>
	      <img src="<?V WAUI_PHOTO_URL ?>" border="0" alt="Photo" width="32" hspace="3"/>
            <?vsp } ?><?V wa_utf8_to_wide (coalesce (U_FULL_NAME, sne_name)) ?>
          </a>
	      <span class="home_addr"><?V wa_utf8_to_wide (addr) ?></span>
	</li>
	  <?vsp
		    i := i + 1;
	    }
	   if (i = 0)
	     {
	       if (self.isowner)
	         {
		   ?>
		   You have no connections yet. <br />
		   <v:url name="search_users_fr" value="Search for Contacts" url="search.vspx?page=2&amp;l=1" render-only="1"/>
		   <?vsp
		 }
	       else
                 {
	       ?>
	       <li>This user has no contacts.</li>
	       <?vsp
	         }
	     }
	  }
	  }
	  ?>
	</ul>
    </div>
  </xsl:template>

  <xsl:template match="vm:user-home-map">
      <v:template type="simple" name="user_home_map" enabled="--case when isstring (self.maps_key) and length (self.maps_key) > 0 then 1 else 0 end">

    <vm:oatmap-control
	sql="sprintf ('\n' ||
	   'select _LAT,_LNG,_KEY_VAL,EXCERPT \n' ||
	   'from ( \n' ||
	   '      select \n' ||
     '        case when WAUI_LATLNG_HBDEF=0 THEN WAUI_LAT ELSE WAUI_BLAT end as _LAT, \n' ||
     '        case when WAUI_LATLNG_HBDEF=0 THEN WAUI_LNG ELSE WAUI_BLNG end as _LNG, \n' ||
	   '        WAUI_U_ID as _KEY_VAL, \n' ||
	   '        WA_SEARCH_USER_GET_EXCERPT_HTML (\n' ||
	   '          %d, \n' ||
	   '          vector (), \n' ||
	   '          WAUI_U_ID, \n' ||
	   '          '''', \n' ||
	   '          WAUI_FULL_NAME, \n' ||
	   '          U_NAME, \n' ||
	   '          WAUI_PHOTO_URL, \n' ||
	   '          U_E_MAIL) as EXCERPT \n' ||
	   '      from DB.DBA.WA_USER_INFO, DB.DBA.SYS_USERS \n' ||
	   '      where \n' ||
	   '         WAUI_LAT is not null and WAUI_LNG is not null and WAUI_U_ID = U_ID ' ||
     '         and (exists (select 1 from (\n' ||
     '              select 1 as x from DB.DBA.sn_related, DB.DBA.sn_entity sne_from, DB.DBA.sn_entity sne_to \n' ||
     '                where \n' ||
     '                  snr_to = sne_to.sne_id and snr_from = sne_from.sne_id and \n' ||
     '                  sne_from.sne_name = U_NAME and sne_to.sne_name = ''%S'' \n' ||
     '              union all \n' ||
     '              select 1 as x from DB.DBA.sn_related, DB.DBA.sn_entity sne_from, DB.DBA.sn_entity sne_to \n' ||
     '                where \n' ||
     '                  snr_to = sne_to.sne_id and snr_from = sne_from.sne_id and \n' ||
     '                  sne_to.sne_name = U_NAME and sne_from.sne_name = ''%S'' \n' ||
     '                  and sne_to.sne_name <> sne_from.sne_name\n' ||
     '              union all \n' ||
     '              select 1 as x from WA_USER_TAG where contains (\n' ||
     '                 WAUTG_TAGS, \n' ||
     '                 sprintf (''[__lang &quot;x-any&quot; __enc &quot;UTF-8&quot;] (%S) AND (&quot;^UID%%d&quot;) AND (&quot;^TID%%d&quot;)'', \n' ||
     '                     http_nobody_uid (), U_ID) \n' ||
     '                 ) \n' ||
     '             ) x) or WAUI_U_ID = %d)\n' ||
     '     ) _tmp_tbl\n' ||
     '     where _LAT is not null and _LNG is not null \n',
            coalesce (self.u_id, self.ufid), self.fname, self.fname, WA_GET_USER_TAGS_OR_QRY (self.ufid), self.ufid)"
        baloon-inx="4"
        lat-inx="1"
        lng-inx="2"
        key-name-inx="3"
        key-val="self.ufid"
        div_id="user_map"
        zoom="0"
        base_url="HTTP_REQUESTED_URL ()" />

   </v:template>
  </xsl:template>

  <xsl:template match="vm:header-wrapper">
    <?vsp
      wa_template_header_render (self);
    ?>
  </xsl:template>

  <xsl:template match="vm:body-wrapper">
    <?vsp
      wa_template_body_render (self);
    ?>
    <xsl:apply-templates select="vm:home-init|vm:login"/>
  </xsl:template>

</xsl:stylesheet>
