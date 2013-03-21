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
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
  xmlns:v="http://www.openlinksw.com/vspx/"
  xmlns:vm="http://www.openlinksw.com/vspx/ods/">

  <xsl:template match="vm:services">
    <v:data-source name="dss" expression-type="sql" nrows="-1" initial-offset="0">
      <xsl:choose>
        <xsl:when test="@mode='private'">
          <v:expression>
            <![CDATA[
              select WAI_ID, WAI_DESCRIPTION, WAI_INST, WAI_NAME, WAI_TYPE_NAME from WA_INSTANCE
              where (not WAI_MEMBER_MODEL = 1 and WAI_IS_PUBLIC = 1) or (? = http_dav_uid())
              order by lower (WAI_DESCRIPTION)
            ]]>
          </v:expression>
          <v:param name="bid" value="--self.u_id"/>
        </xsl:when>
        <xsl:otherwise>
          <v:expression>
            <![CDATA[
              select WAI_ID, WAI_DESCRIPTION, WAI_INST, WAI_NAME, WAI_TYPE_NAME from WA_INSTANCE where WAI_IS_PUBLIC
              order by lower (WAI_DESCRIPTION)
            ]]>
          </v:expression>
        </xsl:otherwise>
      </xsl:choose>
      <v:column name="WAI_ID" label="Id" />
      <v:column name="WAI_DESCRIPTION" label="Description" />
      <v:column name="WAI_INST" label="Instance" />
      <v:column name="WAI_NAME" label="Name" />
    </v:data-source>
    <?vsp
      if (length(self.serv.ds_rows_cache) = 0)
        http('<br/>');
    ?>
    <table class="listing">
      <tr class="listing_header_row">
        <th>Application Name</th>
        <th>Application Description</th>
        <th>Action</th>
      </tr>
      <v:data-set name="serv" scrollable="1" edit="1" data-source="self.dss">
        <vm:template type="repeat">
          <vm:template type="browse">
             <tr class="<?V case when mod(control.te_ctr, 2) = 0 then 'listing_row_odd' else 'listing_row_even' end ?>">
              <td>
                <v:url name="ddd" value="--''" format="%s" url="#">
                   <v:after-data-bind>
                    <![CDATA[
                      control.vu_url := SIOC..forum_iri ((control.vc_parent as vspx_row_template).te_rowset[4], (control.vc_parent as vspx_row_template).te_rowset[3]) || sprintf ('?sid=%s&realm=%s', self.sid, self.realm);
                      control.ufl_value := (control.vc_parent as vspx_row_template).te_rowset[3];
                    ]]>
                   </v:after-data-bind>
                </v:url>
              </td>
              <td>
                <v:label name="service_description" value="--(control.vc_parent as vspx_row_template).te_rowset[1]" format="%s"/>
              </td>
              <td>
                <xsl:if test="@mode='private'">
                  <vm:url value="Join" url="--sprintf ('join.vspx?wai_id=%d',(control.vc_parent as vspx_row_template).te_rowset[0])">
                    <v:after-data-bind>
                      <![CDATA[
                        control.ufl_value := '<img src="images/icons/add_16.png" border="0" alt="Join" title="Join"/>&#160;Join';
                  			control.vc_enabled := DB.DBA.WA_USER_CAN_JOIN_INSTANCE (self.u_id, (control.vc_parent as vspx_row_template).te_rowset[3]);
                      ]]>
                    </v:after-data-bind>
                  </vm:url>
                  <v:label name="service_description2" value="Already joined" format="%s">
                    <v:after-data-bind>
                      <![CDATA[
                        control.ufl_value := 'Already joined';
                        control.vc_enabled := 0;
                        declare _member_type any;
                        _member_type := (select WAI_MEMBER_MODEL from WA_INSTANCE where WAI_NAME = (control.vc_parent as vspx_row_template).te_rowset[3]);
                        if(_member_type = 1)
                        {
                          control.ufl_value := 'Membership is closed';
                          control.vc_enabled := 1;
                          return;
                        }
                        if(_member_type = 2)
                        {
                          control.ufl_value := 'Only owner can invite a new member';
                          control.vc_enabled := 1;
                        }
                        declare _member int;
                        _member := (select WAM_MEMBER_TYPE from WA_MEMBER where WAM_USER = self.u_id and WAM_INST = (control.vc_parent as vspx_row_template).te_rowset[3]);
                        if (_member = 1)
                        {
                          control.ufl_value := 'Already owned';
                          control.vc_enabled := 1;
                        }
                        else if (_member is not null)
                        {
                          control.ufl_value := 'Already joined';
                          control.vc_enabled := 1;
                        }
                      ]]>
                    </v:after-data-bind>
                  </v:label>
                </xsl:if>
              </td>
            </tr>
          </vm:template>
        </vm:template>
      </v:data-set>
    </table>
  </xsl:template>

  <xsl:template match="vm:dashboard">
    <v:variable name="dashboard_content" type="varchar" default="''" persist="temp"/>
    <v:template type="simple" name="dashboard_template">
      <v:before-render>
        <v:script>
        -- get external parameters
        declare _nrows, _style any;
        _nrows := <xsl:value-of select="@nrows"/>;
        _style := '<xsl:value-of select="@style"/>';
        <![CDATA[
        -- create xml entity
        declare _xml_entity any;
        declare _str any;
        _str := string_output();
        http('<dashboard>', _str);
            for select inst.WAI_INST.wa_dashboard() as r
                  from WA_INSTANCE inst
                  where inst.WAI_IS_PUBLIC >= 1
                     or exists (select 1
                                  from WA_MEMBER
                                 where WAM_INST = inst.WAI_NAME
                                   and WAM_STATUS <= 2
                                   and WAM_USER = self.u_id)
            do
            {
          http_value(r, null, _str);
        }
        http('</dashboard>', _str);
        _xml_entity := xtree_doc(string_output_string(_str));
        -- create absolute path to xsl resource
        declare _request_path, _request_dir, _real_dir any;
        _request_path := http_physical_path();
        _request_dir := substring(_request_path, 1, strrchr(_request_path, '/'));
        _real_dir := concat(http_root(), _request_dir);
        -- create xsl model
        declare _is_dav, _xsl_fullname, _xsl_string, _xsl_uri any;
        declare _dav_path, _dav_fullpath any;
        _is_dav := http_map_get('is_dav');
            if (not _is_dav)
            {
          -- file system
          _xsl_fullname := concat(_real_dir, '/', _style, '.xsl');
          _xsl_string := file_to_string(_xsl_fullname);
          _xsl_uri := concat('file://', _request_dir, '/', _style, '.xsl');
        }
            else
            {
          -- dav collection
          declare _position any;
          _dav_path := http_physical_path();
          _position := strrchr(_dav_path, '/');
          _dav_path := substring(_dav_path, 1, _position + 1);
          _dav_fullpath := sprintf('%s%s%s', _dav_path, _style, '.xsl');
          select blob_to_string(RES_CONTENT) into _xsl_string from WS.WS.SYS_DAV_RES where RES_FULL_PATH = _dav_fullpath;
          _xsl_uri := concat('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:', _dav_fullpath);
        }
        -- make xsl transformation
        declare _result, _params any;
        _params := vector('nrows', _nrows);
        xslt_sheet(_xsl_uri, xtree_doc(_xsl_string, 0, _xsl_uri));
        _result := xslt(_xsl_uri, _xml_entity, _params);
        declare _stream, _string any;
        _stream := string_output();
        http_value(_result, 0, _stream);
        _string := string_output_string(_stream);
        self.dashboard_content := trim(_string);
        ]]>
        </v:script>
      </v:before-render>
    </v:template>
    <?vsp
      if (length(self.dashboard_content) = 0)
      {
        http('<br/>');
      }
      else {
    ?>
    <table width="99%">
      <tr>
        <td width="100%" valign="top" align="right">
          <?vsp http(self.dashboard_content); ?>
        </td>
      </tr>
    </table>
    <?vsp } ?>
  </xsl:template>

  <xsl:template match="vm:security-list">
      <script type="text/javascript">
  <![CDATA[
function selectAllCheckboxes (form, btn, txt)
{
        for (var i =0; i < form.elements.length; i++) {
      var contr = form.elements[i];
          if (contr != null && contr.type == "checkbox" && contr.name.indexOf (txt) != -1) {
    contr.focus();
    if (btn.value == 'Select All')
      contr.checked = true;
    else
            contr.checked = false;
  }
    }
  if (btn.value == 'Select All')
    btn.value = 'Unselect All';
  else
    btn.value = 'Select All';
  btn.focus();
}


]]>
</script>
    <?vsp
      if (wa_user_is_dba (self.u_name, self.u_group))
      {
    ?>
    <v:data-source name="dss1" expression-type="sql" nrows="-1" initial-offset="0">
      <v:expression>
        <![CDATA[
          select WAI_ID, WAI_DESCRIPTION, WAI_INST, WAI_NAME, WAI_TYPE_NAME from WA_INSTANCE order by lower (WAI_DESCRIPTION)
        ]]>
      </v:expression>
      <v:column name="WAI_ID" label="Id"/>
      <v:column name="WAI_DESCRIPTION" label="Description"/>
      <v:column name="WAI_INST" label="Instance"/>
      <v:column name="WAI_NAME" label="Name" />
      <v:column name="WAI_TYPE_NAME" label="Type"/>
    </v:data-source>
    <?vsp if(length(self.serv2.ds_rows_cache) = 0) http('<br/>'); ?>
    <div class="scroll_area">
    <table class="listing">
      <tr class="listing_header_row">
	  <th>
	       <input type="checkbox" value="Select All" onclick="selectAllCheckboxes(this.form, this, 'inst_cb')"/>
	      Application Name
	  </th>
        <th>Application Type</th>
        <th>Owner User</th>
        <th>Action</th>
      </tr>
      <v:data-set name="serv2" scrollable="1" edit="1" data-source="self.dss1">
        <vm:template type="repeat" name="sec_rpt">
          <vm:template type="browse" name="sec_brws">
	      <tr class="<?V case when mod(control.te_ctr,2) = 0 then 'listing_row_odd' else 'listing_row_even' end ?>">
              <td nowrap="1">
		  <input type="checkbox" name="inst_cb" value="<?V control.te_rowset[0] ?>" />
                <v:label name="instance_name" value="--(control.vc_parent as vspx_row_template).te_rowset[3]" format="%s"/>
              </td>
              <td>
                <v:label name="instance_type" value="--WA_GET_APP_NAME ((control.vc_parent as vspx_row_template).te_rowset[4])" format="%s"/>
              </td>
              <td>
                <v:button style="url" value="" action="simple" name="owner_name">
                  <v:after-data-bind>
                    <v:script>
                      <![CDATA[
                        declare _owner_id int;
                        declare _owner_name varchar;
                        _owner_id := (select WAM_USER from WA_MEMBER where WAM_MEMBER_TYPE = 1 and WAM_INST = (control.vc_parent as vspx_row_template).te_rowset[3]);
                        _owner_name := (select U_NAME from DB.DBA.SYS_USERS where U_ID = _owner_id);
                        if (_owner_name is not null)
                          control.ufl_value := _owner_name;
                        else
                          control.ufl_value := 'unknown user';
                      ]]>
                    </v:script>
                  </v:after-data-bind>
                  <v:on-post>
                    <v:script>
                      <![CDATA[
                        declare h, id, ss any;
                        declare inst web_app;
                        declare _owner_id int;
                        declare _owner_name, sid varchar;
                        _owner_id := (select WAM_USER from WA_MEMBER where WAM_MEMBER_TYPE = 1 and WAM_INST = (control.vc_parent as vspx_row_template).te_rowset[3]);
                        _owner_name := (select U_NAME from DB.DBA.SYS_USERS where U_ID = _owner_id);
                        sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
                        insert into DB.DBA.VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
                          values ('wa', sid, _owner_name,
                          serialize (
                            vector (
                              'vspx_user', _owner_name)
                            ), now());
                        http_request_status ('HTTP/1.1 302 Found');
                        http_header(sprintf('Location: services.vspx?sid=%s&realm=wa\r\n', sid));
                      ]]>
                    </v:script>
                  </v:on-post>
                </v:button>
              </td>
              <td>
                <v:button style="url" value="Enter as owner" action="simple" name="enter_as_owner">
                  <v:after-data-bind>
                    <![CDATA[
                      control.ufl_value := '<img src="images/icons/user_16.png" border="0" alt="Enter as owner" title="Enter as owner"/>&#160;Enter as owner';
                    ]]>
                  </v:after-data-bind>
                  <v:on-post>
                    <v:script>
                    <![CDATA[
                      declare _owner_id int;
                      declare _owner_name varchar;
                      _owner_id := (select WAM_USER from WA_MEMBER where WAM_MEMBER_TYPE = 1 and WAM_INST = (control.vc_parent as vspx_row_template).te_rowset[3]);
                      _owner_name := (select U_NAME from DB.DBA.SYS_USERS where U_ID = _owner_id);
                      if (_owner_name is not null)
                      {
                        declare h, id, ss any;
                        declare inst web_app;
                        inst := (control.vc_parent as vspx_row_template).te_rowset[2];
                        --connection_set('vspx_user', _owner_name);
                        ss := null;
                        h := udt_implements_method(inst, 'wa_front_page_as_user');
                        id := call (h) (inst, ss, self.u_name);
                      }
                    ]]>
                    </v:script>
                  </v:on-post>
                </v:button>
                <v:button style="url" value="Freeze" action="simple" name="freeze_instance">
                  <v:after-data-bind>
                    <![CDATA[
                      declare freeze varchar;
                      freeze := (select WAI_IS_FROZEN from WA_INSTANCE where WAI_NAME = (control.vc_parent as vspx_row_template).te_rowset[3]);
                      if (freeze = 1)
                        control.ufl_value := '<img src="images/icons/confg_16.png" border="0" alt="Freeze options" title="Freeze options"/>&#160;Freeze options';
                      else
                        control.ufl_value := '<img src="images/icons/stop_16.png" border="0" alt="Freeze" title="Freeze"/>&#160;Freeze';
                    ]]>
                  </v:after-data-bind>
                  <v:on-post>
                    <![CDATA[
		                  self.vc_redirect (sprintf('freeze.vspx?app=%s', (control.vc_parent as vspx_row_template).te_rowset[3]));
                    ]]>
                  </v:on-post>
                </v:button>
                <v:button style="url" value="Unfreeze" action="simple" name="unfreeze_instance">
                  <v:after-data-bind>
                    <![CDATA[
                      control.ufl_value := '<img src="images/icons/go_16.png" border="0" alt="Unfreeze" title="Unfreeze"/>&#160;Unfreeze';
                    ]]>
                  </v:after-data-bind>
                  <v:before-data-bind>
                      <![CDATA[
                        declare freeze varchar;
                        freeze := (select WAI_IS_FROZEN from WA_INSTANCE where WAI_NAME = (control.vc_parent as vspx_row_template).te_rowset[3]);
                        if (freeze = 1)
                          control.vc_enabled := 1;
                        else
                          control.vc_enabled := 0;
                      ]]>
                  </v:before-data-bind>
                  <v:on-post>
                    <![CDATA[
                      update WA_INSTANCE set WAI_IS_FROZEN = 0 where WAI_NAME = (control.vc_parent as vspx_row_template).te_rowset[3];
                      self.vc_redirect ('security.vspx');
                    ]]>
                  </v:on-post>
                </v:button>
                <vm:url value="Delete"
                        url="--sprintf('delete_inst.vspx?wai_id=%d&redir=security', (control.vc_parent as vspx_row_template).te_rowset[0])">
                  <v:after-data-bind>
                    <![CDATA[
                      control.ufl_value := '<img src="images/icons/trash_16.png" border="0" alt="Delete the application" title="Delete the application"/>&#160;Delete';
                    ]]>
                  </v:after-data-bind>
                  <v:before-data-bind>
                      <![CDATA[
                        if (wa_user_is_dba (self.u_name, self.u_group))
                          control.vc_enabled := 1;
                        else
                          control.vc_enabled := 0;
                      ]]>
                  </v:before-data-bind>
                </vm:url>
              </td>
            </tr>
          </vm:template>
        </vm:template>
    </v:data-set>
   </table>
   <div class="fm_ctl_btn">
       <v:button name="freeze_btn" value="Freeze Selected" action="simple">
	   <v:on-post><![CDATA[
	       declare i, v, pars any;
	       pars := e.ve_params;
               v := '';
	       for (i := 0; i < length (pars); i := i + 2)
	         {
		   if (pars[i] = 'inst_cb')
                     v := v || pars[i+1] || ',' ;
	         }
	       v := rtrim (v, ',');
	       if (length (v))
	         self.vc_redirect ('freeze.vspx?apps='||v);
	       ]]>
	     </v:on-post>
       </v:button>
       <v:button name="remove_btn" value="Delete Selected" action="simple" >
	   <v:on-post><![CDATA[
	       declare i, v, pars any;
	       pars := e.ve_params;
               v := '';
	       for (i := 0; i < length (pars); i := i + 2)
	         {
		   if (pars[i] = 'inst_cb')
                     v := v || pars[i+1] || ',' ;
	         }
	       v := rtrim (v, ',');
	       if (length (v))
	         self.vc_redirect ('delete_inst.vspx?apps='||v||'&redir=security');
	       ]]></v:on-post>
       </v:button>
   </div>
</div>
    <?vsp
      }
    ?>
  </xsl:template>

  <xsl:template match="vm:freeze-options">
    <v:variable name="apps_ids" type="varchar" default="null" param-name="apps"/>
    <v:variable name="apps" type="any" default="null" />
    <v:after-data-bind>
	<![CDATA[
	  declare apps, v, i any;
	  v := null;
	  if (self.apps_ids is not null)
	    {
	      apps := split_and_decode (self.apps_ids, 0, '\0\0,');
	      v := make_array (length (apps), 'any');
	      i := 0;
              foreach (any id in apps) do
	        {
                  v[i] := atoi (id);
		  i := i + 1;
		}
	    }
          self.inst_name := get_keyword('app', e.ve_params, self.inst_name);
          if (length (self.inst_name) = 0 and self.apps_ids is null)
            control.vc_enabled := 0;
          else
	    control.vc_enabled := 1;
          self.apps := v;
        ]]>
    </v:after-data-bind>
    <?vsp
    if (self.apps is not null)
      {
        declare wai_nam varchar;
	foreach (any v in self.apps) do
	  {
	    wai_nam := (select WAI_NAME from WA_INSTANCE where WAI_ID = v);
	    http (wai_nam); http ('<br />');
	  }
      }
    ?>
    <table>
      <tr>
        <th valign="top">Freeze redirect page</th>
        <td>
          <v:radio-group xhtml_id="selector" name="radio1">
            <table>
              <tr>
                <td>
                  <v:radio-button xhtml_id="srch_where19" name="srch_where19" value="default" initial-checked="1">
                    <v:before-render>
                      <![CDATA[
                        declare banner varchar;
                        banner := (select WAI_FREEZE_REDIRECT from WA_INSTANCE where WAI_NAME = self.inst_name);
                        if (banner is null or banner = '' or banner = 'default')
                          control.ufl_selected := 1;
                        else
                          control.ufl_selected := 0;
                      ]]>
                    </v:before-render>
                  </v:radio-button>
                </td>
                <td>
                  <label for="srch_where19">404 - Not found</label>
                </td>
              </tr>
              <tr>
                <td>
                  <v:radio-button xhtml_id="srch_where29" name="srch_where29" value="user">
                    <v:before-render>
                      <![CDATA[
                        declare banner varchar;
                        banner := (select WAI_FREEZE_REDIRECT from WA_INSTANCE where WAI_NAME = self.inst_name);
                        if (banner is null or banner = '' or banner = 'default')
                          control.ufl_selected := 0;
                        else
                          control.ufl_selected := 1;
                      ]]>
                    </v:before-render>
                  </v:radio-button>
                </td>
                <td>
                  <label for="srch_where29">Custom URL</label>
                  <v:text name="freeze_redirect">
                    <v:before-render>
                      <![CDATA[
                        declare banner varchar;
                        banner := (select WAI_FREEZE_REDIRECT from WA_INSTANCE where WAI_NAME = self.inst_name);
                        if (banner is null or banner = '' or banner = 'default')
                          control.ufl_value := '';
                        else
                          control.ufl_value := banner;
                      ]]>
                    </v:before-render>
                    <v:validator test="length" min="1" max="500"/>
                  </v:text>
                </td>
              </tr>
              <tr>
                <td colspan="2">
                  User will be redirected to this page when the application is frozen.
                </td>
              </tr>
            </table>
          </v:radio-group>
        </td>
      </tr>
      <tr>
        <td colspan="2">
          <v:button name="sset22" action="simple" value="Set">
            <v:on-post>
              <v:script>
                <![CDATA[
		  declare wai_ids any;
                  if (not wa_user_is_dba (self.u_name, self.u_group))
                  {
                    self.vc_is_valid := 0;
                    control.vc_parent.vc_error_message := 'Only administrators can change global settings';
                    return;
                  }
                  declare banner, title varchar;
                  if (get_keyword('radio1', e.ve_params) = 'user')
                  {
                    banner := trim(get_keyword('freeze_redirect', e.ve_params));
                    if (banner is null or banner = '')
                    {
                      self.vc_is_valid := 0;
                      control.vc_parent.vc_error_message := 'Please enter custom URL';
                      return;
                    }
                    if (left(banner, 7) <> 'http://' and left(banner, 8) <> 'https://')
                      banner := 'http://' || banner;
                  }
                  else
                    banner := 'default';

		  if (length (self.inst_name))
                    {
		      update DB.DBA.WA_INSTANCE set
			WAI_IS_FROZEN = 1,
			WAI_FREEZE_REDIRECT = banner
			where WAI_NAME = self.inst_name;
		    }
		  else if (length (self.apps))
		    {
			foreach (any v in self.apps) do
			  {
                            update DB.DBA.WA_INSTANCE set WAI_IS_FROZEN = 1, WAI_FREEZE_REDIRECT = banner where WAI_ID = v;
			  }
		    }
                  http_request_status ('HTTP/1.1 302 Found');
                  http_header(sprintf('Location: security.vspx?sid=%s&realm=%s\r\n', self.sid, self.realm));
                ]]>
              </v:script>
            </v:on-post>
          </v:button>
          <v:button name="scancel22" action="simple" value="Cancel">
            <v:on-post>
              <v:script>
                <![CDATA[
                  http_request_status ('HTTP/1.1 302 Found');
                  http_header(sprintf('Location: security.vspx?sid=%s&realm=%s\r\n', self.sid, self.realm));
                ]]>
              </v:script>
            </v:on-post>
          </v:button>
        </td>
      </tr>
    </table>
  </xsl:template>

</xsl:stylesheet>
