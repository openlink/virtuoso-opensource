<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id: dav_browser.xsl,v 1.32 2013/06/25 17:09:56 ddimitrov Exp $
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2014 OpenLink Software
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
<xsl:stylesheet
  version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xhtml="http://www.w3.org/1999/xhtml"
  xmlns:v="http://www.openlinksw.com/vspx/"
  xmlns:vm="http://www.openlinksw.com/vspx/macro"
  >
  <xsl:output
    method="xml"
    version="1.0"
    encoding="UTF-8"
    indent="yes"
  />
  <xsl:template match="vm:dav_browser">
    <xsl:choose>
      <xsl:when test="@browse_type='standalone' and @render='popup'">
        <v:browse-button
          style="url"
          value="WebDAV Browser"
          selector="popup_browser.vspx"
          child-window-options="scrollbars=yes,resizable=yes,status=no,menubar=no,height=600,width=800"
          browser-options="ses_type={@ses_type}&amp;list_type={@list_type}&amp;flt={@flt}&amp;flt_pat={@flt_pat}&amp;dir={@path}&amp;browse_type={@browse_type}&amp;style_css={@style_css}&amp;w_title={@w_title}&amp;title={@title}&amp;advisory={@advisory}&amp;lang={@lang}&amp;view={@view}"
        />
      </xsl:when>
      <xsl:when test="not @browse_type='standalone' and @render='popup' and @return_box">
        <v:browse-button
          value="Browse..."
          selector="popup_browser.vspx"
          child-window-options="scrollbars=yes,resizable=yes,status=no,menubar=no,height=600,width=800 " browser-options="ses_type={@ses_type}&amp;list_type={@list_type}&amp;flt={@flt}&amp;flt_pat={@flt_pat}&amp;dir={@path}&amp;browse_type={@browse_type}&amp;style_css={@style_css}&amp;w_title={@w_title}&amp;title={@title}&amp;advisory={@advisory}&amp;lang={@lang}&amp;retname={@return_box}&amp;view={@view}"
          >
          <v:field name="{@return_box}" />
        </v:browse-button>
      </xsl:when>
      <xsl:otherwise>
        <v:template type="simple">
          <v:variable name="mode" persist="1" type="varchar">
            <xsl:attribute name="default"><xsl:choose><xsl:when test="@mode='briefcase'">'briefcase'</xsl:when><xsl:when test="@mode='webdav'">'webdav'</xsl:when><xsl:otherwise>'conductor'</xsl:otherwise></xsl:choose></xsl:attribute>
          </v:variable>
          <script type="text/javascript">
            <![CDATA[
              OAT.Preferences.stylePath = '';
              OAT.Style.include ("<?V case when self.mode = 'briefcase' then 'dav/dav_browser.css' else '/conductor/dav/dav_browser.css' end ?>");
              OAT.Preferences.imagePath = "<?V case when self.mode = 'briefcase' then '/ods/images/oat/' else '/conductor/toolkit/images/' end ?>";
              OAT.Preferences.stylePath = "<?V case when self.mode = 'briefcase' then '/ods/oat/styles/' else '/conductor/toolkit/styles/' end ?>";
              OAT.Preferences.showAjax = false;
              OAT.Loader.load(["ajax", "json", "drag", "dialog", "tab", "combolist"]);
              var davOptions = {
                imagePath: OAT.Preferences.imagePath,
                path: "/DAV",
                user: "<?V connection_get ('vspx_user') ?>",
                connectionHeaders: {Authorization: "<?V WEBDAV.DBA.account_basicAuthorization (connection_get ('vspx_user')) ?>"}
              };
            ]]>
          </script>
          <script type="text/javascript" src="<?V case when self.mode = 'briefcase' then '/ods/tbl.js' else '/conductor/tbl.js' end ?>"><xsl:text> </xsl:text></script>
          <script type="text/javascript" src="<?V case when self.mode = 'briefcase' then 'dav/dav_tbl.js' else '/conductor/dav/dav_tbl.js' end ?>"><xsl:text> </xsl:text></script>
          <script type="text/javascript" src="<?V case when self.mode = 'briefcase' then 'dav/dav_browser.js' else '/conductor/dav/dav_browser.js' end ?>"><xsl:text> </xsl:text></script>
          <script type="text/javascript">
            <![CDATA[
              WEBDAV.Preferences.imagePath = "<?V case when self.mode = 'briefcase' then 'dav/image/' else '/conductor/dav/image/' end ?>";
              WEBDAV.Preferences.restPath = "<?V case when self.mode = 'webdav' then '/conductor/dav/' else 'dav/' end ?>";
            ]]>
          </script>
          <script type="text/javascript" src="<?V case when self.mode = 'briefcase' then 'dav/dav_state.js' else '/conductor/dav/dav_state.js' end ?>"><xsl:text> </xsl:text></script>
          <vm:if test="WEBDAV.DBA.VAD_CHECK ('Framework') and self.mode &lt;&gt; 'briefcase'">
            <link rel="stylesheet" href="/ods/typeahead.css" type="text/css" />
            <script type="text/javascript" src="/ods/typeahead.js"><xsl:text> </xsl:text></script>
          </vm:if>

          <v:variable name="command" persist="0" type="integer" default="0" />
          <v:variable name="command_mode" persist="0" type="integer" default="0" />
          <v:variable name="command_save" persist="0" type="integer" default="0" />
          <v:variable name="source" persist="0" type="varchar" default="''" />
          <v:variable name="items" persist="0" type="any" default="null" />
          <v:variable name="need_overwrite" persist="0" type="integer" default="0" />
          <v:variable name="dir_spath" persist="1" type="varchar" default="'__root__'" />
          <v:variable name="dir_path" persist="0" type="varchar" default="'__root__'" />
          <v:variable name="dir_right" persist="0" type="varchar" default="''" />
          <v:variable name="dir_details" persist="1" type="integer" default="0" />
          <v:variable name="dir_order" persist="0" type="varchar" default="'column_#4'" />
          <v:variable name="dir_direction" persist="0" type="varchar" default="'desc'" />
          <v:variable name="dir_grouping" type="varchar" default="''" />
          <v:variable name="dir_groupName" type="varchar" default="''" />
          <v:variable name="dir_cloud" type="integer" default="0" />
          <v:variable name="dir_tags" type="any" default="null" />
          <v:variable name="dir_columns" type="any" default="null" />
          <v:variable name="returnName" persist="0" type="varchar" default="''" />
          <v:variable name="search_filter" persist="0" type="varchar" default="''" />
          <v:variable name="search_simple" persist="0" type="any" default="null" />
          <v:variable name="search_advanced" persist="0" type="any" default="null" />
          <v:variable name="search_dc" persist="0" type="any" default="null" />
          <v:variable name="noPrepare" persist="temp" type="integer" default="0" />
          <v:variable name="dav_vector" persist="0" type="any" default="null" />
          <v:variable name="tabNo" param-name="tabNo" type="varchar" default="'1'" />
          <v:variable name="dav_action" persist="0" type="varchar" param-name="a" default="''" />
          <v:variable name="dav_id" type="integer" default="-1" />
          <v:variable name="dav_destination" type="integer" default="0" />
          <v:variable name="dav_source" type="integer" default="0" />
          <v:variable name="dav_path" type="varchar" default="''" />
          <v:variable name="dav_category" type="varchar" default="''" />
          <v:variable name="dav_type" type="varchar" default="''" />
          <v:variable name="dav_detType" type="varchar" default="''" />
          <v:variable name="dav_detClass" type="varchar" default="''" />
          <v:variable name="dav_ownClass" type="varchar" default="''" />
          <v:variable name="dav_subClass" type="varchar" default="''" />
          <v:variable name="dav_actions" type="any" default="null" />
          <v:variable name="dav_viewFields" type="any" default="null" />
          <v:variable name="dav_editFields" type="any" default="null" />
          <v:variable name="dav_item" type="any" default="null" />
          <v:variable name="dav_enable" type="integer" default="1" />
          <v:variable name="dav_enable_versioning" type="integer" default="1" />
          <v:variable name="dav_acl" persist="0" type="varbinary" />
          <v:variable name="dav_tags_private" persist="0" type="varchar" />
          <v:variable name="dav_tags_public" persist="0" type="varchar" />
          <v:variable name="dav_encryption" type="varchar" default="'None'" />
          <v:variable name="dav_encryption_pwd" type="varchar" default="'None'" />
          <v:variable name="dav_redirect" type="varchar" default="''" />
          <v:variable name="dav_is_redirect" type="integer" default="0" />
          <v:variable name="chars" type="integer" default="60" />

          <v:variable name="v_step" type="varchar" default="''" persist="0" />
          <v:variable name="v_source" type="varchar" persist="0"/>
          <v:variable name="v_target" type="varchar" persist="0"/>
          <v:variable name="v_path" type="varchar" persist="0"/>
          <v:variable name="v_parent" type="varchar" persist="0"/>
          <v:variable name="v_old" type="varchar" persist="0"/>
          <v:variable name="v_new" type="varchar" persist="0"/>
          <v:variable name="overwriteFlag" type="integer" value="0" persist="0"/>
          <v:variable name="mimeType" type="any" />

          <v:method name="webdav_redirect" arglist="in path varchar, in parts varchar">
            <![CDATA[
              declare params any;

              params := self.vc_page.vc_event.ve_params;
              if (get_keyword ('sid', params, '') <> '')
                parts := parts || '&sid=' || get_keyword ('sid', params);

              if (parts <> '')
                path := path || '?' || parts;

              self.vc_redirect (path);
              return;
            ]]>
          </v:method>

          <v:method name="image_src" arglist="in path varchar">
            <![CDATA[
              return case when self.mode = 'briefcase' then '' else '/conductor/' end || path;
            ]]>
          </v:method>

          <v:method name="tag_style" arglist="in tagCount integer, in tagMinCount integer, in tagMaxCount integer, in fontMinSize integer, in fontMaxSize integer">
            <![CDATA[
              declare fontSize, fontPercent float;
              declare tagStyle any;

              if (tagMaxCount = tagMinCount)
              {
                fontPercent := 0;
              } else {
                fontPercent := (1.0 * tagCount - tagMinCount) / (tagMaxCount - tagMinCount);
              }
              fontSize := fontMinSize + ((fontMaxSize - fontMinSize) * fontPercent);
              tagStyle := sprintf ('font-size: %dpx;', fontSize);
              if (fontPercent > 0.6)
                tagStyle := tagStyle || ' font-weight: bold;';

              if (fontPercent > 0.8)
                tagStyle := tagStyle || ' color: #9900CC;';
              else if (fontPercent > 0.6)
                tagStyle := tagStyle || ' color: #339933;';
              else if (fontPercent > 0.4)
                tagStyle := tagStyle || ' color: #CC3333;';
              else if (fontPercent > 0.2)
                tagStyle := tagStyle || ' color: #66CC99;';
              return tagStyle;
            ]]>
          </v:method>

          <v:method name="dc_prepare" arglist="">
            <![CDATA[
              if (self.noPrepare)
                return;

              declare params any;

              params := self.vc_page.vc_event.ve_params;
              self.search_dc := null;
              WEBDAV.DBA.dc_set_base (self.search_dc, 'path', get_keyword ('ts_path', params));

              declare N, seqNo integer;
              declare f1, f2, f3, f4, f5 any;

              seqNo := cast (get_keyword ('srt_no', params, '1') as integer);
              for (N := 0; N < seqNo; N := N + 1)
              {
                f1 := get_keyword (sprintf ('srt_fld_1_%d', N), params);
                if (not isnull (f1))
                {
                  f2 := get_keyword (sprintf ('srt_fld_2_%d', N), params);
                  f3 := get_keyword (sprintf ('srt_fld_3_%d', N), params);
                  f4 := get_keyword (sprintf ('srt_fld_4_%d', N), params);
                  f5 := get_keyword (sprintf ('srt_fld_5_%d', N), params);
                  WEBDAV.DBA.dc_set_criteria (self.search_dc, cast (N as varchar), f1, f4, f5, f2, f3);
                }
              }
              return WEBDAV.DBA.dc_filter_check (self.search_dc, self.account_id);
            ]]>
          </v:method>

          <v:method name="dc_varchar" arglist="in f varchar">
            <![CDATA[
              if (isnull (f))
                return 'null';

              return sprintf('"%s"', f);
            ]]>
          </v:method>

          <v:method name="option_prepare" arglist="in value any, in name any, in selectedValue any">
            <![CDATA[
              return sprintf ('<option value="%s" %s>%s</option>', cast (value as varchar), case when (value = selectedValue) then 'selected="selected"' else '' end, cast(name as varchar));
            ]]>
          </v:method>

          <v:method name="command_set" arglist="in command integer, in command_mode integer">
            <![CDATA[
              self.command_restore (command, command_mode, 1);
            ]]>
          </v:method>

          <v:method name="command_restore" arglist="in command integer, in command_mode integer, in restore_mode integer">
            <![CDATA[
              self.tabNo := '1';
              self.command := command;
              self.command_mode := command_mode;
              if (self.command = 0)
              {
                self.need_overwrite := 0;
                self.items := vector ();
                if (self.command_mode <> 1)
                {
                  self.search_filter := null;
                }
                if (self.command_mode <> 2)
                {
                  self.search_simple := null;
                }
                if (self.command_mode <> 3)
                {
                  self.search_advanced := null;
                  self.dir_grouping := '';
                  self.dir_cloud := 0;
                }
                else
                {
                  self.search_dc := self.search_advanced;
                }
                if (restore_mode)
                {
                  self.search_dc := null;
                }
              }
            ]]>
          </v:method>

          <v:method name="command_push" arglist="in command integer, in command_mode integer">
            <![CDATA[
              self.command_save := vector (self.command, self.command_mode, self.dir_path);
              self.command_set (command, command_mode);
            ]]>
          </v:method>

          <v:method name="command_pop" arglist="in path varchar">
            <![CDATA[
              if (is_empty_or_null (self.command_save))
              {
                self.command_set (0, 0);
              }
              else
              {
                self.command_restore (self.command_save[0], self.command_save[1], 0);
                if (isnull (path))
                {
                  self.dir_path := self.command_save[2];
                }
                else
                {
                  self.dir_path := path;
                }
                self.command_save := null;
              }
            ]]>
          </v:method>

          <v:method name="toolbarEnable" arglist="in writePermission integer, in cmd varchar">
            <![CDATA[
              if (cmd in ('refresh', 'bookmarklet', 'home'))
                return 1;

             if (is_empty_or_null (self.dir_path))
                return 0;

              if (not (((self.command = 0) and (self.command_mode <> 3)) or ((self.command = 0) and (self.command_mode = 3) and (not isnull (self.search_advanced)))))
                return 0;

              if (cmd = 'new')
              {
                if (not (self.command_mode in (0, 1)))
                  return 0;
              }

              if (cmd = 'up')
              {
                if (WEBDAV.DBA.check_admin (self.account_id))
                  return 1;

                if (trim (self.dir_path, '/') = trim (WEBDAV.DBA.dav_home2 (self.owner_id, self.account_role), '/'))
                  return 0;

                return 1;
              }

              if (cmd in ('upload', 'create', 'link'))
              {
                if (not (self.command_mode in (0, 1)))
                  return 0;

                if (not writePermission)
                  return 0;
              }

              if (not self.checkAction (cmd))
                return 0;

              if ((cmd = 'new') and not writePermission)
                return 0;

              return 1;
            ]]>
          </v:method>

          <v:method name="toolbarShow" arglist="in writePermission integer, in cmd varchar, in cmdLabel varchar, in cmdEvent varchar, in cmdImage varchar, in cmdImageGray varchar, in cmdImageAlternate integer">
            <![CDATA[
              declare hasLabels varchar;
              declare toolbarLabel varchar;
              declare toolbarEnable integer;

              hasLabels := WEBDAV.DBA.settings_tbLabels (self.settings);
              toolbarLabel := case when (hasLabels = 0) then '' else sprintf ('<br /><span class="toolbarLabel">%s</span>', cmdLabel) end;
              toolbarEnable := self.toolbarEnable (writePermission, cmd);
              if (toolbarEnable)
              {
                http (sprintf ('<span id="tb_%s" class="toolbar" style="cursor: pointer; %s" %s>', cmd, case when (cmdImageGray <> '') and cmdImageAlternate then 'display: none;' else '' end, cmdEvent));
                http (sprintf ('  <img src="%s" border="0" alt="%s" />%s', self.image_src ('dav/image/' || cmdImage), cmdLabel, toolbarLabel));
                http (         '</span>');
              }
              if ((cmdImageGray <> '') and (not toolbarEnable or cmdImageAlternate))
              {
                http (sprintf ('<span id="tb_%s_gray" class="toolbar" style="display: inline;">', cmd));
                http (sprintf ('  <img src="%s" border="0" alt="%s"/>%s', self.image_src ('dav/image/' || cmdImageGray), cmdLabel, toolbarLabel));
                http (         '</span>');
              }
            ]]>
          </v:method>

          <v:method name="getColumn" arglist="in columnId varchar">
            <![CDATA[
              declare N integer;
              declare columns any;

              columns := self.dir_columns;
              for (N := 0; N < length (columns); N := N + 1)
              {
                if (columns[N][0] = columnId)
                  return columns[N];
              }
              return null;
            ]]>
          </v:method>

          <v:method name="enabledColumn" arglist="in columnId varchar">
            <![CDATA[
              declare dir_column any;

              dir_column := self.getColumn(columnId);
              if (is_empty_or_null(dir_column))
                return 0;
              if (dir_column[0] = self.dir_grouping)
                return 0;
              if (dir_column[5][self.dir_details] <> 1)
                return 0;
              return 1;
            ]]>
          </v:method>

          <v:method name="showColumnHeader" arglist="in columnId varchar">
            <![CDATA[
              if (not self.enabledColumn(columnId))
                return;

              declare dir_column, image, onclick any;

              image := '';
              onclick := '';
              dir_column := self.getColumn(columnId);
              if ((dir_column[3] = 1) and (self.dir_path <> ''))
              {
                onclick := sprintf ('onclick="javascript: sortPost(this, \'sortColumn\', \'%s\');"', dir_column[0]);
                if ((self.dir_order = dir_column[0]) and (self.dir_direction = 'desc'))
                {
                  image := sprintf ('&nbsp;<img src="%s" border="0" alt="Down"/>', self.image_src ('dav/image/orderdown_16.png'));
                }
                else if ((self.dir_order = dir_column[0]) and (self.dir_direction = 'asc'))
                {
                  image := sprintf ('&nbsp;<img src="%s" border="0" alt="Up"/>', self.image_src ('dav/image/orderup_16.png'));
                }
              }
              http (sprintf ('<th %s %s>%s%s</th>', case when (self.dir_details) then '' else dir_column[6] end, onclick, dir_column[2], image));
            ]]>
          </v:method>

          <v:method name="sortChange" arglist="in columnName varchar">
            <![CDATA[
              if (columnName = '')
              {
                -- check if we have a session cookie for sort state
                --
                declare cookies, state any;
                declare exit handler for SQLSTATE '*' { return; };

                cookies := DB.DBA.vsp_ua_get_cookie_vec (self.vc_event.ve_lines);
                state := get_keyword ('DAVSTATE_State', cookies);
                if (not isnull (state))
                {
                  state := split_and_decode (state);
                  if (WEBDAV.DBA.isVector (state) and length(state))
                  {
                    state := WEBDAV.DBA.json2obj (state[0]);
                    columnName := get_keyword ('column', state, 'column_#4');
                    self.dir_direction := get_keyword ('direction', state, case when (columnName = 'column_#4') then 'desc' else 'asc' end);
                  }
                }
                columnName := self.dir_order;
              }
              else
              {
                if (self.dir_order = columnName)
                {
                  self.dir_direction := either (equ (self.dir_direction, 'asc'), 'desc', 'asc');
                } else {
                  self.dir_direction := 'asc';
                }
              }
              if (not self.enabledColumn(columnName))
                columnName := 'column_#1';

              self.dir_order := columnName;
              self.settings := WEBDAV.DBA.set_keyword ('orderBy', self.settings, self.dir_order);
              self.settings := WEBDAV.DBA.set_keyword ('orderDirection', self.settings, self.dir_direction);
              WEBDAV.DBA.settings_save (self.account_id, self.settings);
              self.ds_items.vc_reset();
            ]]>
          </v:method>

          <v:method name="do_url" arglist="">
            <![CDATA[
              declare I, N integer;
              declare tmp, T varchar;
              declare aCriteria, criteria any;

              tmp := sprintf ('&did=%d&aid=%d', self.domain_id, self.account_id);
              if (self.command_mode = 2)
              {
                tmp := tmp || sprintf ('&path=%U', WEBDAV.DBA.real_path (self.dir_path));
                tmp := tmp || sprintf ('&f0_0=RES_NAME&f0_3=like&f0_4=%U', trim (self.search_simple));
              }
              else if (self.command_mode = 3)
              {
                tmp := tmp || sprintf ('&path=%U', WEBDAV.DBA.dc_get (self.search_dc, 'base', 'path'));
                aCriteria := WEBDAV.DBA.dc_xml_doc (self.search_dc);
                I := xpath_eval('count(/dc/criteria/entry)', aCriteria);
                for (N := 1; N <= I; N := N + 1)
                {
                  criteria := xpath_eval('/dc/criteria/entry', aCriteria, N);
                  T := cast (xpath_eval ('@field', criteria) as varchar);
                  if (not isnull (T))
                    tmp := tmp || sprintf ('&f%d_0=%U', I, T);
                  T := cast (xpath_eval ('@schema', criteria) as varchar);
                  if (not isnull (T))
                    tmp := tmp || sprintf ('&f%d_1=%U', I, T);
                  T := cast (xpath_eval ('@property', criteria) as varchar);
                  if (not isnull (T))
                    tmp := tmp || sprintf ('&f%d_2=%U', I, T);
                  T := cast (xpath_eval ('@criteria', criteria) as varchar);
                  if (not isnull (T))
                    tmp := tmp || sprintf ('&f%d_3=%U', I, T);
                  T := cast (xpath_eval ('.', criteria) as varchar);
                  if (not isnull (T))
                    tmp := tmp || sprintf ('&f%d_4=%U', I, T);
                }
              }
              T := self.getColumn(self.dir_order);
              if (not is_empty_or_null (T) and (T[1] <> 'c0'))
                tmp := concat(tmp, sprintf ('&order=%U', T[1]));

              if (not is_empty_or_null (self.dir_direction) and self.dir_direction <> 'asc')
                tmp := concat(tmp, sprintf ('&direction=%U', self.dir_direction));

              return tmp;
            ]]>
          </v:method>

          <v:method name="get_fieldProperty" arglist="in formFieldName varchar, in path varchar, in davPropertyName varchar, in defaultValue varchar">
            <![CDATA[
              declare tmp, params varchar;

              params := self.vc_page.vc_event.ve_params;
              tmp := get_keyword (formFieldName, params);
              if (not isnull (tmp))
                return tmp;

              if (get_keyword ('formRight', params, '') <> '')
                return case when formFieldName = '===' then coalesce (tmp, '') else tmp end;

              if ((self.command = 10) and (self.command_mode in (0, 5, 6)))
                return defaultValue;

              return WEBDAV.DBA.DAV_PROP_GET (path, davPropertyName, defaultValue);
            ]]>
          </v:method>

          <v:method name="actions" arglist="in detClass varchar">
            <![CDATA[
              declare retValue any;

              if      (detClass in ('', 'UnderVersioning'))
                retValue := vector ('new', 'upload', 'create', 'link', 'edit', 'view', 'delete', 'rename', 'copy', 'move', 'tag', 'properties');

              else if (detClass = 'rdfSink')
                retValue := vector ('upload', 'create', 'edit', 'view', 'delete', 'rename', 'copy', 'move', 'tag', 'properties');

              else if (detClass = 'HostFS')
                retValue := vector ('new', 'upload', 'create', 'link', 'edit', 'view', 'delete', 'rename', 'copy', 'move', 'properties');

              else if (detClass = 'IMAP')
                retValue := vector ('new', 'delete', 'copy', 'move', 'properties');

              else if (detClass = 'Share')
                retValue := vector ('edit', 'view', 'delete', 'rename', 'tag', 'properties');

              else if (detClass in ('DynaRes', 'Share', 'S3', 'GDrive', 'Dropbox', 'SkyDrive', 'Box', 'WebDAV', 'RACKSPACE'))
                retValue := vector ('new', 'upload', 'create', 'edit', 'view', 'delete', 'rename', 'properties');

              else if (detClass in ('CalDAV', 'CardDAV'))
                retValue := vector ('upload', 'view', 'delete', 'tag', 'properties');

              else
                retValue := vector ();

              -- dbg_obj_print ('actions', detClass, retValue);
              return retValue;
            ]]>
          </v:method>

          <v:method name="checkAction" arglist="in action varchar">
            <![CDATA[
              if (not isarray (self.dav_actions))
                return 0;

              return WEBDAV.DBA.vector_contains (self.dav_actions, action);
            ]]>
          </v:method>

          <v:method name="viewFields" arglist="in detClass varchar, in what varchar, in mode varchar">
            <![CDATA[
              declare retValue any;

              if      (detClass in ('', 'UnderVersioning'))
                retValue := vector ('destination', 'source', 'name', 'mime', 'link', 'folderType', 'owner', 'group', 'permissions', 'sse', 'textSearch', 'inheritancePermissions', 'metadata', 'recursive', 'publicTags', 'privateTags', 'properties', 'acl', 'aci', 'version');

              else if      (detClass = 'Versioning')
                retValue := vector ('name', 'mime', 'folderType', 'owner', 'group', 'permissions', 'properties');

              else if (detClass = 'rdfSink')
                retValue := vector ('source', 'name', 'mime', 'folderType', 'owner', 'group', 'permissions', 'sse', 'textSearch', 'inheritancePermissions', 'metadata', 'recursive', 'publicTags', 'privateTags', 'properties', 'acl', 'aci', 'version');

              else if (detClass = 'HostFS')
                retValue := vector ('source', 'name', 'mime', 'owner', 'group', 'permissions', 'textSearch', 'metadata', 'acl');

              else if (detClass = 'IMAP')
                retValue := vector ('name', 'mime', 'owner', 'group', 'permissions', 'publicTags', 'aci');

              else if (detClass = 'S3')
                retValue := vector ('source', 'name', 'mime', 'folderType', 'owner', 'group', 'permissions', 'sse', 'textSearch', 'inheritancePermissions', 'metadata', 'publicTags', 'privateTags', 'properties', 'acl', 'aci');

              else if (detClass in ('DynaRes', 'Share', 'GDrive', 'Dropbox', 'SkyDrive', 'Box', 'WebDAV', 'RACKSPACE'))
                retValue := vector ('source', 'name', 'mime', 'folderType', 'owner', 'group', 'permissions', 'textSearch', 'inheritancePermissions', 'metadata', 'acl', 'aci');

              else if (detClass in ('CalDAV', 'CardDAV'))
                retValue := vector ('source', 'name', 'mime', 'owner', 'group', 'permissions', 'publicTags', 'aci');

              else if (detClass in ('Blog', 'News3', 'bookmark', 'calendar'))
                retValue := vector ('name', 'mime', 'owner', 'group', 'permissions', 'publicTags', 'acl', 'aci');

              else if (detClass in ('oMail'))
                retValue := vector ('name', 'mime', 'owner', 'group', 'permissions', 'publicTags');

              else
                retValue := vector ();

              -- dbg_obj_print ('viewFields', detClass, retValue);
              return retValue;
            ]]>
          </v:method>

          <v:method name="viewField" arglist="in field varchar">
            <![CDATA[
              if (not isarray (self.dav_viewFields))
                return 0;

              return WEBDAV.DBA.vector_contains (self.dav_viewFields, field);
            ]]>
          </v:method>

          <v:method name="editFields" arglist="in detClass varchar, in what varchar, in mode varchar">
            <![CDATA[
              declare retValue any;

              if      (detClass in ('', 'UnderVersioning'))
                retValue := self.viewFields (detClass, what, mode);

              else if      (detClass = 'Versioning')
                retValue := vector ();

              else if (detClass = 'rdfSink')
                retValue := self.viewFields (detClass, what, mode);

              else if (detClass = 'HostFS')
                retValue := self.viewFields (detClass, what, mode);

              else if (detClass = 'IMAP')
                retValue := vector ('aci');

              else if (detClass = 'S3')
                retValue := self.viewFields (detClass, what, mode);

              else if (detClass in ('DynaRes', 'Share', 'S3', 'GDrive', 'Dropbox', 'SkyDrive', 'Box', 'WebDAV', 'RACKSPACE'))
                retValue := self.viewFields (detClass, what, mode);

              else if (detClass in ('CalDAV', 'CardDAV'))
              {
                if (mode = 'create')
                  retValue := vector ('source', 'name', 'publicTags', 'aci');
                else
                  retValue := vector ('publicTags', 'aci');
              }
              else
                retValue := vector ();

              -- dbg_obj_print ('editFields', what, mode, detClass, retValue);
              return retValue;
            ]]>
          </v:method>

          <v:method name="editField" arglist="in field varchar">
            <![CDATA[
              if (not isarray (self.dav_editFields))
                return 0;

              return WEBDAV.DBA.vector_contains (self.dav_editFields, field);
            ]]>
          </v:method>

          <v:method name="detGraphUI" arglist="in det varchar">
            <![CDATA[
              declare retValue varchar;

              retValue := self.get_fieldProperty (sprintf ('dav_%s_graph', det), self.dav_path, sprintf ('virt:%s-graph', det), '');
              if ((retValue = '') and (self.command = 10) and (self.command_mode = 0))
                retValue := 'urn:dav:' || replace (WEBDAV.DBA.path_escape (subseq (WS.WS.FIXPATH (WEBDAV.DBA.real_path (self.dav_path)), 5)), '/', ':');

              return retValue;
            ]]>
          </v:method>

          <v:method name="detGraphUI2" arglist="">
            <![CDATA[
              return 'urn:dav:' || replace (WEBDAV.DBA.path_escape (subseq (WS.WS.FIXPATH (WEBDAV.DBA.real_path (self.dir_path)), 5)), '/', ':');
            ]]>
          </v:method>

          <v:method name="detGraph" arglist="in params any, in det varchar">
            <![CDATA[
              declare oldGraph, newGraph, prop varchar;

              prop := sprintf ('virt:%s-graph', det);
              oldGraph := WEBDAV.DBA.DAV_PROP_GET (self.dav_path, prop, '');
              newGraph := get_keyword (sprintf ('dav_%s_graph', det), params, '');
              WEBDAV.DBA.DAV_PROP_SET (self.dav_path, prop, newGraph);
              WEBDAV.DBA.graph_update (DB.DBA.DAV_SEARCH_ID (self.dav_path, 'C'), det, oldGraph, newGraph);
            ]]>
          </v:method>

          <v:method name="detSpongerPrepare" arglist="in params any, in det varchar, in ndx integer, inout sponger varchar, inout cartridges varchar, inout metaCartridges varchar">
            <![CDATA[
              declare N integer;
              declare ca_item, mca_item varchar;

              cartridges := '';
              metaCartridges := '';
              sponger := get_keyword ('dav_' || det || '_sponger', params, 'off');
              if (sponger = 'on')
              {
                ca_item := sprintf ('ca%d_item', ndx);
                mca_item := sprintf ('mca%d_item', ndx);
                for (N := 0; N < length (params); N := N + 2)
                {
                  if (params[N] = ca_item)
                    cartridges := cartridges || ',' || trim (params[N+1]);
                  else if (params[N] = mca_item)
                    metaCartridges := metaCartridges || ',' || trim (params[N+1]);
                }
                cartridges := ltrim (cartridges, ',');
                metaCartridges := ltrim (metaCartridges, ',');
              }
            ]]>
          </v:method>

          <v:method name="detSponger" arglist="in params any, in det varchar, in ndx integer">
            <![CDATA[
              declare sponger, cartridges, metaCartridges varchar;

              self.detSpongerPrepare (params, det, ndx, sponger, cartridges, metaCartridges);
              WEBDAV.DBA.DAV_PROP_SET (self.dav_path, sprintf ('virt:%s-sponger', det), sponger);
              WEBDAV.DBA.DAV_PROP_SET (self.dav_path, sprintf ('virt:%s-cartridges', det), cartridges);
              WEBDAV.DBA.DAV_PROP_SET (self.dav_path, sprintf ('virt:%s-metaCartridges', det), metaCartridges);
            ]]>
          </v:method>

          <v:method name="detSpongerUI" arglist="in det varchar, in ndx integer">
            <![CDATA[
              declare S, T varchar;
              declare N integer;
              declare cartridges, selectedCartridges any;

              S := self.get_fieldProperty (sprintf ('dav_%s_sponger', det), self.dav_path, sprintf ('virt:%s-sponger', det), 'off');
              http (sprintf (
                '<tr>\n' ||
                '  <th>\n' ||
                '    <label for="dav_%s_sponger">Sponger (on/off)</label>\n' ||
                '  </th>\n' ||
                '  <td>\n' ||
                '    <input type="checkbox" name="dav_%s_sponger" id="dav_%s_sponger" %s disabled="disabled" onchange="javascript: destinationChange(this, {checked: {show: [''dav%d_cartridge'', ''dav%d_metaCartridge'']}, unchecked: {hide: [''dav%d_cartridge'', ''dav%d_metaCartridge'']}});" value="on" />\n' ||
                '  </td>\n' ||
                '</tr>\n',
                det,
                det,
                det,
                case when S = 'on' then 'checked="checked"' else '' end,
                ndx,
                ndx,
                ndx,
                ndx
              ));

              selectedCartridges := self.get_fieldProperty (sprintf ('dav_%s_cartridges', det), self.dav_path, sprintf ('virt:%s-cartridges', det), '');
              selectedCartridges := split_and_decode (selectedCartridges, 0, '\0\0,');
              cartridges := WEBDAV.DBA.cartridges_get ();

              http (sprintf (
                '<tr id="dav%d_cartridge" style="display: none;">\n' ||
                '  <th valign="top">Sponger Extractor Cartridges</th>\n' ||
                '  <td>\n' ||
                '    <div style="margin-bottom: 6px; max-height: 200px; overflow: auto;">\n' ||
                '      <table id="ca%d_tbl" class="WEBDAV_grid" cellspacing="0">\n' ||
                '        <thead>\n' ||
                '          <tr>\n' ||
                '            <th><input type="checkbox" name="ca%d_select" value="Select All" onclick="selectAllCheckboxes (this, ''ca%d_item'', true)" title="Select All" /></th>\n' ||
                '            <th width="100%%">Cartridge</th>\n' ||
                '          </tr>\n' ||
                '        </thead>',
                ndx,
                ndx,
                ndx,
                ndx
              ));
              for (N := 0; N < length (cartridges); N := N + 1)
              {
                if (S = 'on')
                {
                  T := case when WEBDAV.DBA.vector_contains (selectedCartridges, cast (cartridges[N][0] as varchar)) then 'checked="checked"' else '' end;
                }
                else if (det = 'IMAP')
                {
                  T := case when cartridges[N][2] = 2 then 'checked="checked"' else '' end;
                }
                else
                {
                  T := case when cartridges[N][2] = 1 then 'checked="checked"' else '' end;
                }
                http (sprintf (
                  '        <tr>\n' ||
                  '          <td class="checkbox"><input type="checkbox" name="ca%d_item" value="%d" disabled="disabled" %s /></td>\n' ||
                  '          <td>%V</td>\n' ||
                  '        </tr>',
                  ndx,
                  cartridges[N][0],
                  T,
                  cartridges[N][1]
                ));
              }
              if (length (cartridges) = 0)
                http (
                '        <tr><td colspan="2"><b>No available cartridges</b></td></tr>'
                );

              http (
                '      </table>\n' ||
                '    </div>\n' ||
                '  </td>\n' ||
                '</tr>'
              );

              if (not WEBDAV.DBA.VAD_CHECK ('cartridges'))
                return;

              selectedCartridges := self.get_fieldProperty (sprintf ('dav_%s_metaCartridges', det), self.dav_path, sprintf ('virt:%s-metaCartridges', det), '');
              selectedCartridges := split_and_decode (selectedCartridges, 0, '\0\0,');
              cartridges := WEBDAV.DBA.metaCartridges_get ();

              http (sprintf (
                '<tr id="dav%d_metaCartridge" style="display: none;">\n' ||
                '  <th valign="top">Sponger Meta Cartridges</th>\n' ||
                '  <td>\n' ||
                '    <div style="margin-bottom: 6px; max-height: 200px; overflow: auto;">\n' ||
                '      <table id="mca%d_tbl" class="WEBDAV_grid" cellspacing="0">\n' ||
                '        <thead>\n' ||
                '          <tr>\n' ||
                '            <th><input type="checkbox" name="mca%d_select" value="Select All" onclick="selectAllCheckboxes (this, ''mca%d_item'', true)" title="Select All" /></th>\n' ||
                '            <th width="100%%">Meta Cartridge</th>\n' ||
                '          </tr>\n' ||
                '        </thead>',
                ndx,
                ndx,
                ndx,
                ndx
              ));
              for (N := 0; N < length (cartridges); N := N + 1)
              {
                if (S = 'on')
                {
                  T := case when WEBDAV.DBA.vector_contains (selectedCartridges, cast (cartridges[N][0] as varchar)) then 'checked="checked"' else '' end;
                } else {
                  T := case when cartridges[N][2] then 'checked="checked"' else '' end;
                }
                http (sprintf (
                  '        <tr>\n' ||
                  '          <td class="checkbox"><input type="checkbox" name="mca%d_item" value="%d" disabled="disabled" %s /></td>\n' ||
                  '          <td>%V</td>\n' ||
                  '        </tr>',
                  ndx,
                  cartridges[N][0],
                  T,
                  cartridges[N][1]
                ));
              }
              if (length (cartridges) = 0)
                http (
                '        <tr><td colspan="2"><b>No available meta cartridges</b></td></tr>'
                );

              http (
                '      </table>\n' ||
                '    </div>\n' ||
                '  </td>\n' ||
                '</tr>'
              );
            ]]>
          </v:method>

          <v:method name="detAccessTimestamp" arglist="in params any">
            <![CDATA[
              declare gmt any;
              declare exit handler for SQLSTATE '*' {goto _exit;};

              gmt := get_keyword ('access_timestamp', params);
              if (not isnull (gmt))
                return datestring (dateadd ('minute', timezone (now()), stringdate (gmt)));

            _exit:;
              return datestring (now ());
            ]]>
          </v:method>

          <v:method name="detParamsPrepare" arglist="in det varchar, in labels any, in ndx integer">
            <![CDATA[
              declare retValue, val any;
              declare params any;

              params := self.vc_page.vc_event.ve_params;
              retValue := vector ();
              foreach (any label in labels) do
              {
                val := trim (get_keyword ('dav_' || det || '_' || label, params));
                if (not isnull (val))
                {
                  if (label = 'path')
                  {
                    if (chr (val[0]) <> '/')
                      val := '/' || val;

                    if (chr (val[length (val)-1]) <> '/')
                      val := val || '/';
                  }
                  retValue := vector_concat (retValue, vector (label, val));
              }
              }
              if (ndx is not null)
              {
                declare sponger, cartridges, metaCartridges varchar;

                self.detSpongerPrepare (params, det, ndx, sponger, cartridges, metaCartridges);
                retValue := vector_concat (retValue, vector ('sponger', sponger, 'cartridges', cartridges, 'metaCartridges', metaCartridges));
              }
              return retValue;
            ]]>
          </v:method>

          <v:method name="detOAuthParamsPrepare" arglist="in det varchar, in properties any, in labels any, in ndx integer">
            <![CDATA[
              declare json varchar;
              declare retValue, params any;

              params := self.vc_page.vc_event.ve_params;

              retValue := self.detParamsPrepare (det, labels, ndx);
              json := trim (get_keyword ('dav_' || det || '_JSON', params, ''));
              if (json <> '')
              {
                retValue := vector_concat (retValue, subseq (WEBDAV.DBA.json2obj (json), 2));
                retValue := WEBDAV.DBA.set_keyword ('Authentication', retValue, 'Yes');
              retValue := WEBDAV.DBA.set_keyword ('access_timestamp', retValue, self.detAccessTimestamp(retValue));
              retValue := WEBDAV.DBA.set_keyword ('display_name', retValue, get_keyword ('dav_' || det || '_display_name', params, ''));
              retValue := WEBDAV.DBA.set_keyword ('email', retValue, get_keyword ('dav_' || det || '_email', params, ''));
              }
              else if (not isnull (properties))
              {
                self.virtPropertiesRestore (properties, 'virt:' || det || '-%');
              }
              return retValue;
            ]]>
          </v:method>

          <v:method name="virtPropertiesRestore" arglist="in _properties any, in _pattern varchar">
            <![CDATA[
              foreach (any _property in _properties) do
              {
                if (_property[0] like _pattern)
                  WEBDAV.DBA.DAV_PROP_SET (self.dav_path, _property[0], _property[1]);
              }
            ]]>
          </v:method>

          <v:method name="showSelected" arglist="">
            <![CDATA[
              declare i integer;
              declare item any;

              http ('<div id="dav_list" style="max-height: 200px; min-height: 200px;">');
              http ('  <table class="WEBDAV_grid" style="border: 0px;">');
              http ('    <thead>');
              http ('      <tr>');
              http ('        <th width="50%">Name</th>');
              http ('        <th>Size</th>');
              http ('        <th>Date Modified</th>');
              http ('        <th>Owner</th>');
              http ('        <th>Group</th>');
              http ('        <th>Permissions</th>');
              if (self.v_step <> 'start')
              {
              http ('        <th>&nbsp;</th>');
              }
              http ('      </tr>');
              http ('    </thead>');

              for (i := 0; i < length (self.items); i := i + 2)
              {
                item := WEBDAV.DBA.DAV_INIT (self.items[i]);
                if (not WEBDAV.DBA.DAV_ERROR (item))
                {
                  http ('    <tr>');
                  http (sprintf ('<td nowrap="nowrap" valign="top"><img src="%s" alt="%s">&nbsp;&nbsp;%s</td>', WEBDAV.DBA.ui_image (WEBDAV.DBA.DAV_GET (item, 'fullPath'), WEBDAV.DBA.DAV_GET (item, 'type'), WEBDAV.DBA.DAV_GET (item, 'mimeType')), WEBDAV.DBA.ui_alt (WEBDAV.DBA.DAV_GET (item, 'name'), WEBDAV.DBA.DAV_GET (item, 'type')), self.items[i]));
                  http (sprintf ('<td class="number" nowrap="nowrap" valign="top">%s</td>', WEBDAV.DBA.ui_size (WEBDAV.DBA.DAV_GET (item, 'length'), WEBDAV.DBA.DAV_GET (item, 'type'))));
                  http (sprintf ('<td nowrap="nowrap" valign="top">%s</td>', WEBDAV.DBA.ui_date (WEBDAV.DBA.DAV_GET (item, 'modificationTime'))));
                  http (sprintf ('<td valign="top">%s</td>', WEBDAV.DBA.DAV_GET (item, 'ownerName')));
                  http (sprintf ('<td valign="top">%s</td>', WEBDAV.DBA.DAV_GET (item, 'groupName')));
                  http (sprintf ('<td valign="top">%s</td>', WEBDAV.DBA.DAV_GET (item, 'permissionsName')));
                  if (self.v_step <> 'start')
                  {
                  http (sprintf ('<td style="color: red;">%s</td>', self.items[i+1]));
                  }
                  http ('    </tr>');
                }
              }
              http ('  </table>');
              http ('</div>');
              http ('<br />');
            ]]>
          </v:method>

          <v:method name="property_right" arglist="in property any">
            <![CDATA[
              if (WEBDAV.DBA.check_admin (self.account_id))
                return 1;
              if (property like 'DAV:%')
                return 0;
              if (property like 'xml-%')
                return 0;
              if (property like 'xper-%')
                return 0;
              return 1;
            ]]>
          </v:method>

          <v:method name="sse_enabled" arglist="">
            <![CDATA[
              if (__proc_exists ('WS.WS.SSE_ENABLED'))
                return WS.WS.SSE_ENABLED ();

              return 0;
            ]]>
          </v:method>

          <v:method name="getItems" arglist="inout params any">
            <![CDATA[
              declare I integer;
              declare retValue any;

              retValue := vector ();
              for (i := 0; i < length (params); i := i + 2)
              {
                if (params[i] = 'cb_item')
                  retValue := vector_concat (retValue, vector (params[i+1], null));
              }

              return retValue;
            ]]>
          </v:method>

          <v:method name="retItems" arglist="inout items any, inout itemPath any, in retValue any, in message varchar">
            <![CDATA[
              if (WEBDAV.DBA.DAV_ERROR (retValue))
              {
                if (message <> '')
                  message := message || ' - ';
                items := vector_concat (items, vector (itemPath, message || WEBDAV.DBA.DAV_PERROR (retValue)));
              }
            ]]>
          </v:method>

          <v:before-data-bind>
            <![CDATA[
              declare _params, tmp any;

              _params := self.vc_page.vc_event.ve_params;

              self.chars := WEBDAV.DBA.settings_chars (self.settings);
              self.dir_columns := vector (
                vector ('column_#1', 'c0', 'Name',          1, 0, vector (WEBDAV.DBA.settings_column (self.settings, 1), 1), 'width="50%"'),
                vector ('column_#2',   '', 'Tags',          0, 0, vector (WEBDAV.DBA.settings_column (self.settings, 2), 0), ''),
                vector ('column_#3', 'c2', 'Size',          1, 1, vector (WEBDAV.DBA.settings_column (self.settings, 3), 0), ''),
                vector ('column_#4', 'c3', 'Date Modified', 1, 1, vector (WEBDAV.DBA.settings_column (self.settings, 4), 0), ''),
                vector ('column_#5', 'c4', 'Content Type',  1, 1, vector (WEBDAV.DBA.settings_column (self.settings, 5), 0), ''),
                vector ('column_#6', 'c9', 'Kind',          1, 1, vector (WEBDAV.DBA.settings_column (self.settings, 6), 0), ''),
                vector ('column_#7', 'c5', 'Owner',         1, 1, vector (WEBDAV.DBA.settings_column (self.settings, 7), 0), ''),
                vector ('column_#8', 'c6', 'Group',         1, 1, vector (WEBDAV.DBA.settings_column (self.settings, 8), 0), ''),
                vector ('column_#9', 'c7', 'Permissions',   0, 0, vector (WEBDAV.DBA.settings_column (self.settings, 9), 0), ''),
                vector ('column_#10','c10','Date Created',  1, 1, vector (WEBDAV.DBA.settings_column (self.settings,10), 0), ''),
                vector ('column_#11','c11','Date Added',    1, 1, vector (WEBDAV.DBA.settings_column (self.settings,11), 0), '')
              );
              self.dir_order := get_keyword ('ts_order', params, WEBDAV.DBA.settings_orderBy (self.settings));
              self.dir_direction := get_keyword ('ts_direction', params, WEBDAV.DBA.settings_orderDirection (self.settings));

              self.dir_path := get_keyword ('dir', _params, self.dir_path);
              if (self.dir_path = '__root__')
                self.dir_path := self.dir_spath;

              if (self.dir_path = '__root__')
                self.dir_path := WEBDAV.DBA.dav_home2 (self.owner_id, self.account_role);

              if ((self.owner_id <> self.account_id) and (not WEBDAV.DBA.check_admin (self.account_id)))
                if (isnull (strstr (WEBDAV.DBA.dav_home2 (self.owner_id, self.account_role), self.dir_path)))
                  self.dir_path := WEBDAV.DBA.dav_home2 (self.owner_id, self.account_role);

              self.dir_spath := self.dir_path;
              self.dir_details := cast (get_keyword ('list_type_internal', _params, self.dir_details) as integer);
              tmp := get_keyword ('list_type', _params);
              if (not isnull (tmp))
                self.dir_details := case when (tmp = 'details') then 0 else 1 end;

              if ((self.command = 0) and (self.command_mode = 2))
                self.search_simple := trim (get_keyword ('simple', _params, self.search_simple));

              if (get_keyword ('mode', _params) = 'simple')
              {
                self.command_set (0, 2);
                if (self.dir_path = '')
                  self.dir_path := '/DAV/';

                self.search_simple := trim (get_keyword ('keywords', _params));
              }
              else if (get_keyword ('mode', _params) = 'advanced')
              {
                self.command_set (0, 3);
                if (self.dir_path = '')
                  self.dir_path := '/DAV/';
                WEBDAV.DBA.dc_set_base (self.search_dc, 'path', WEBDAV.DBA.real_path (self.dir_path));
                tmp := trim (get_keyword ('keywords', _params));
                if (tmp = '')
                  tmp := trim (self.simple.ufl_value);
                if (tmp <> '')
                  WEBDAV.DBA.dc_set_criteria (self.search_dc, '0', 'RES_NAME', 'like', tmp);
                self.simple.ufl_value := '';
              }
              else if (get_keyword ('URI', _params, '') <> '')
              {
                self.dir_path := WEBDAV.DBA.dav_home2 (self.owner_id, 'public');
                self.command_push (10, 5);
                self.dav_source := 1;
              }
              else if (self.dav_action <> '')
              {
                if (self.dav_action in ('new', 'upload', 'create', 'link', 'update', 'edit'))
                {
                  if (not WEBDAV.DBA.write_permission (self.dir_path))
                  {
                    self.vc_error_message := 'You have not permissions for this action!';
                    self.vc_is_valid := 0;
                  }
                  else if (self.command not in (10, 14))
                  {
                    if (self.dav_action = 'new')
                    {
                      self.source := self.dir_path;
                      self.command_push (10, 0);
                    }
                    else if (self.dav_action = 'upload')
                    {
                      self.source := self.dir_path;
                      self.dav_destination := 0;
                      self.dav_source := 0;
                      self.command_push (10, 5);
                    }
                    else if (self.dav_action = 'create')
                    {
                      self.source := self.dir_path;
                      self.dav_source := 0;
                      self.command_push (10, 6);
                    }
                    else if (self.dav_action = 'link')
                    {
                      self.source := self.dir_path;
                      self.dav_source := 0;
                      self.command_push (10, 7);
                    }
                    else if (self.dav_action = 'update')
                    {
                      self.source := self.dir_path;
                      self.command_push (10, 10);
                    }
                    else if (self.dav_action = 'edit')
                    {
                      self.source := get_keyword ('_path', params, self.dir_path);
                      self.command_push (20, 0);
                    }
                  }
                }
              }
              self.dir_right := WEBDAV.DBA.permission(concat(WEBDAV.DBA.path_show (self.dir_path), '/'));
              self.returnName := get_keyword ('retname', self.vc_page.vc_event.ve_params, self.returnName);
            ]]>
          </v:before-data-bind>

          <?vsp
            http (sprintf ('<input type="hidden" name="tabNo" id="tabNo" value="%s" />', self.tabNo));
            http (sprintf ('<input type="hidden" name="retname" id="retname" value="%s" />', self.returnName));
            if ((self.mode = 'webdav') and (self.command in (10, 14)) and (self.dav_action in ('new', 'upload', 'create', 'link', 'update', 'edit')))
              http (sprintf ('<input type="hidden" name="a" id="a" value="%s" />', self.dav_action));
          ?>
          <div class="toolbar">
            <?vsp
              -- The DAV system makes optional use of VAL for authentication. Session cookies can be shared with other pages such as
              -- /sparql or even ODS. The following code adds a logout button to the dav browser toolbar if logged in.
              if (__proc_exists ('VAL.DBA.session_id_for_connection') is not null)
              {
                declare val_sid, val_serviceId, val_realm varchar;
                if (self.mode = 'webdav' and VAL.DBA.session_id_for_connection (val_sid, val_serviceId, val_realm))
                {
                  http ('<div style="float:right;">');
                  http (sprintf ('<span class="toolbar" style="width:auto;text-align:right;padding:10px;"><b>Logged in as</b><br/><span style="font-weight:normal;">%V</span></span>', val_serviceId));
                  http (sprintf ('<img src="%s" height="32" width="2" border="0" class="toolbar" />', self.image_src ('dav/image/c.gif')));
                  http ('<span id="tb_logout" class="toolbar" style="cursor: pointer;">');
                  http (sprintf ('  <a href="/val/logout.vsp?returnto=%U">', HTTP_REQUESTED_URL()));
                  http (sprintf ('    <img src="%s" border="0" alt="Logout" /><br /><span class="toolbarLabel">Logout</span>', self.image_src ('dav/image/logout_32.png')));
                  http ('  </a>');
                  http ('</span>');
                  http('</div>');
                }
              }
            ?>
            <?vsp
              declare writePermission integer;
              declare path varchar;

              path := WEBDAV.DBA.real_path (self.dir_path);
              writePermission := case when self.dir_right = 'W' then 1 else 0 end;
              self.dav_actions := self.actions (WEBDAV.DBA.det_subClass (path, 'C'));
              self.toolbarShow (writePermission, 'refresh', 'Refresh', 'onclick="javascript: vspxPost(\'action\', \'_cmd\', \'refresh\');"', 'ref_32.png', '', 0);
              self.toolbarShow (writePermission, 'up', 'Up', 'onclick="javascript: vspxPost(\'action\', \'_cmd\', \'up\');"', 'up_32.png', 'grey_up_32.png', 0);

              http (sprintf ('<img src="%s" height="32" width="2" border="0" class="toolbar" />', self.image_src ('dav/image/c.gif')));

              if (self.mode <> 'webdav')
              {
              self.toolbarShow (writePermission, 'home', 'Home', 'onclick="javascript: vspxPost(\'action\', \'_cmd\', \'home\');"', 'home_32.png', '', 0);
              }
              self.toolbarShow (case when (self.mode <> 'webdav') then writePermission else 'W' end, 'new', 'New Folder', 'onclick="javascript: vspxPost(\'action\', \'_cmd\', \'new\');"', 'new_fldr_32.png', 'grey_new_fldr_32.png', 0);

              http (sprintf ('<img src="%s" height="32" width="2" border="0" class="toolbar" />', self.image_src ('dav/image/c.gif')));

              if (self.mode = 'briefcase')
              {
              self.toolbarShow (writePermission, 'rename', 'Rename', 'onclick="javascript: vspxPost(\'action\', \'_cmd\', \'rename\');"', 'renm_32.png', 'grey_renm_32.png', 1);
              }
              self.toolbarShow (writePermission, 'copy', 'Copy', 'onclick="javascript: vspxPost(\'action\', \'_cmd\', \'copy\');"', 'copy_32.png', 'grey_copy_32.png', 1);
              self.toolbarShow (writePermission, 'move', 'Move', 'onclick="javascript: vspxPost(\'action\', \'_cmd\', \'move\');"', 'move_32.png', 'grey_move_32.png', 1);
              self.toolbarShow (writePermission, 'delete', 'Delete', 'onclick="javascript: vspxPost(\'action\', \'_cmd\', \'delete\');"', 'del_32.png', 'grey_del_32.png', 1);

              http (sprintf ('<img src="%s" height="32" width="2" border="0" class="toolbar" />', self.image_src ('dav/image/c.gif')));

              self.toolbarShow (writePermission, 'properties', 'Edit Properties', 'onclick="javascript: vspxPost(\'action\', \'_cmd\', \'properties\');"', 'prop_32.png', 'grey_prop_32.png', 1);
              if (self.mode = 'briefcase')
              {
              self.toolbarShow (writePermission, 'tag', 'Tag', 'onclick="javascript: vspxPost(\'action\', \'_cmd\', \'tags\');"', 'tag_32.png', 'grey_tag_32.png', 1);
              }

              http (sprintf ('<img src="%s" height="32" width="2" border="0" class="toolbar" />', self.image_src ('dav/image/c.gif')));

              self.toolbarShow (case when (self.mode <> 'webdav') then writePermission else 'W' end, 'upload', 'Upload', 'onclick="javascript: vspxPost(\'action\', \'_cmd\', \'upload\');"', 'upld_32.png', 'grey_upld_32.png', 0);
              self.toolbarShow (case when (self.mode <> 'webdav') then writePermission else 'W' end, 'create', 'Create', 'onclick="javascript: vspxPost(\'action\', \'_cmd\', \'create\');"', 'filenew_32.png', 'gray_filenew_32.png', 0);
              self.toolbarShow (case when (self.mode <> 'webdav') then writePermission else 'W' end, 'link', 'Create Link', 'onclick="javascript: vspxPost(\'action\', \'_cmd\', \'link\');"', 'filenew_32.png', 'gray_filenew_32.png', 0);
              if ((self.mode = 'briefcase') and (self.account_role <> 'public'))
              {
              http (sprintf ('<img src="%s" height="32" width="2" border="0" class="toolbar" />', self.image_src ('dav/image/c.gif')));

              self.toolbarShow (writePermission, 'bookmarklet', 'Bookmarklet', 'onclick="javascript: vspxPost(\'action\', \'_cmd\', \'bookmarklet\');"', 'bmklet_32.png', '', 0);
              }
            ?>
          </div>
          <br style="clear: both;" />
          <?vsp
            if (0)
            {
          ?>
              <v:button name="action" action="simple" style="url" value="Submit">
                <v:on-post>
                  <![CDATA[
                    declare i integer;
                    declare _tmp, _action, _path, _item, _det, params any;

                    params := self.vc_page.vc_event.ve_params;
                    _action := get_keyword ('_cmd', params, '');

                    if (_action = 'refresh')
                    {
                      _det := cast (WEBDAV.DBA.DAV_PROP_GET (WEBDAV.DBA.real_path (self.dir_path), ':virtdet') as varchar);
                      if (__proc_exists (sprintf ('DB.DBA.%s__refresh', _det)) is not null)
                        call ('DB.DBA.' || _det || '__refresh') (WEBDAV.DBA.real_path (self.dir_path));
                    }
                    else if (_action = 'home')
                    {
                    _home:
                      if (self.mode = 'conductor')
                      {
                        self.dir_path := '/DAV/';
                      } else {
                        self.dir_path := WEBDAV.DBA.dav_home2 (self.owner_id, self.account_role);
                      }
                      self.command_set (0, 0);
                    }
                    else if (_action = 'up')
                    {
                      self.dir_path := trim (self.dir_path, '/');
                      if (self.dir_path <> 'DAV')
                      {
                        declare pos integer;

                        pos := strrchr (self.dir_path, '/');
                        if (not isnull (pos))
                          self.dir_path := left (self.dir_path, pos);
                      }
                      if (self.mode = 'webdav')
                      {
                        self.webdav_redirect (WEBDAV.DBA.dav_lpath ('/' || self.dir_path || '/'), '');
                        return;
                      }
                      self.vc_is_valid := 1;
                      self.ds_items.vc_reset();
                    }
                    else if (_action = 'go')
                    {
                      self.path.ufl_value := trim (self.path.ufl_value, '/');
                      _tmp := WEBDAV.DBA.real_path (self.path.ufl_value);
                      if (WEBDAV.DBA.DAV_ERROR (DB.DBA.DAV_SEARCH_ID(_tmp, 'C')))
                      {
                        self.vc_error_message := concat('Can not find the folder with name ', WEBDAV.DBA.refine_path(self.path.ufl_value));
                        self.vc_is_valid := 0;
                        return;
                      }
                      if ((not WEBDAV.DBA.check_admin (self.account_id)) and isnull (strstr (_tmp, '/DAV/')))
                      {
                        self.vc_error_message := 'The path must be part of your home directory or another public directory';
                        self.vc_is_valid := 0;
                        return;
                      }
                      self.dir_path := self.path.ufl_value;
                      if (self.mode = 'webdav')
                      {
                        self.webdav_redirect ('/' || trim (self.dir_path, '/') || '/', '');
                        return;
                      }
                      self.ds_items.vc_reset();
                    }
                    else if (_action = 'filter')
                    {
                      self.command_set (0, 1);
                      self.search_filter := self.filter.ufl_value;
                    }
                    else if (_action = 'cancelFilter')
                    {
                      self.command_set (0, 1);
                      self.search_filter := '';
                    }
                    else if (_action = 'new')
                    {
                      self.source := WEBDAV.DBA.real_path (get_keyword ('path', params, ''));
                      if (not WEBDAV.DBA.write_permission (self.source) and (self.mode = 'webdav'))
                      {
                        self.webdav_redirect (self.source, 'a=new');
                        return;
                      }
                      self.command_push (10, 0);
                    }
                    else if (_action = 'upload')
                    {
                      self.source := WEBDAV.DBA.real_path (get_keyword ('path', params, ''));
                      if (not WEBDAV.DBA.write_permission (self.source) and (self.mode = 'webdav'))
                      {
                        self.webdav_redirect (self.source, 'a=upload');
                        return;
                      }
                      self.command_push (10, 5);
                      self.dav_destination := 0;
                      self.dav_source := 0;
                    }
                    else if (_action = 'create')
                    {
                      self.source := WEBDAV.DBA.real_path (get_keyword ('path', params, ''));
                      if (not WEBDAV.DBA.write_permission (self.source) and (self.mode = 'webdav'))
                      {
                        self.webdav_redirect (self.source, 'a=create');
                        return;
                      }
                      self.command_push (10, 6);
                      self.dav_source := 0;
                    }
                    else if (_action = 'link')
                    {
                      self.source := WEBDAV.DBA.real_path (get_keyword ('path', params, ''));
                      if (not WEBDAV.DBA.write_permission (self.source) and (self.mode = 'webdav'))
                      {
                        self.webdav_redirect (self.source, 'a=link');
                        return;
                      }
                      self.command_push (10, 7);
                      self.dav_source := 0;
                    }
                    else if (_action = 'update')
                    {
                      self.source := get_keyword ('_path', params, '');
                      if (not WEBDAV.DBA.write_permission (self.source) and (self.mode = 'webdav'))
                      {
                        self.webdav_redirect (self.source, 'a=update');
                        return;
                      }
                      self.command_push (10, 10);
                    }
                    else if (_action = 'edit')
                    {
                      self.source := get_keyword ('_path', params, '');
                      if (not (WEBDAV.DBA.write_permission (self.source) and WEBDAV.DBA.version_permission (self.source)))
                      {
                        if (self.mode = 'webdav')
                        {
                          self.webdav_redirect (self.source, 'a=edit');
                          return;
                        }
                        self.vc_error_message := 'You have not permissions to edit this file!';
                        self.vc_is_valid := 0;
                        return;
                      }
                      self.command_push (20, 0);
                    }
                    else if (_action = 'view')
                    {
                      if (not WEBDAV.DBA.read_permission (get_keyword ('_path', params, '')))
                      {
                        self.vc_error_message := 'You have not permissions to view this file!';
                        self.vc_is_valid := 0;
                        return;
                      }
                      self.source := get_keyword ('_path', params, '');
                      self.command_push (30, 0);
                    }
                    else if (_action = 'move')
                    {
                      self.command_push (40, 0);
                      self.v_step := 'start';
                      self.v_source := WEBDAV.DBA.real_path (self.dir_path);
                      self.items := self.getItems (params);
                    }
                    else if (_action = 'copy')
                    {
                      self.command_push (50, 0);
                      self.v_step := 'start';
                      self.v_source := WEBDAV.DBA.real_path (self.dir_path);
                      self.items := self.getItems (params);
                    }
                    else if (_action = 'delete')
                    {
                      self.command_push (60, 0);
                      self.v_step := 'start';
                      self.items := self.getItems (params);
                    }
                    else if (_action = 'properties')
                    {
                      self.command_push (70, 0);
                      self.v_step := 'start';
                      self.items := self.getItems (params);
                    }
                    else if (_action = 'rename')
                    {
                      self.command_push (80, 0);
                      self.v_step := 'start';
                      self.items := self.getItems (params);
                    }
                    else if (_action = 'tags')
                    {
                      self.command_push (90, 0);
                      self.v_step := 'start';
                      self.items := self.getItems (params);
                    }
                    else if (_action = 'select')
                    {
                      _path := get_keyword ('_path', params, '');
                      if (self.mode = 'webdav')
                      {
                        self.webdav_redirect (_path, '');
                        return;
                      }
                      _tmp := WEBDAV.DBA.read_permission (_path);
                      if (not _tmp)
                      {
                        self.vc_error_message := 'You have not rights to read this folder/file!';
                        self.vc_is_valid := 0;
                        self.vc_data_bind (self.vc_page.vc_event);
                        return;
                      }
                      _item := WEBDAV.DBA.dav_init (_path);
                      if (not WEBDAV.DBA.DAV_ERROR (_item))
                      {
                        if (WEBDAV.DBA.dav_get (_item, 'type') = 'R')
                        {
                          http_request_status ('HTTP/1.1 302 Found');
                          http_header (sprintf ('Location: %s\r\n', WEBDAV.DBA.url_fix (_path, self.sid , self.realm)));
                          return;
                        }

                        self.dir_path := trim (_path, '/');
                      }
                      self.ds_items.vc_reset();
                    }
                    else if (_action = 'tag_search')
                    {
                      declare _mode, tag, tags, tagType, tagsID any;

                      tag := get_keyword ('tag_hidden', params, '');
                      tagType := 'RES_PUBLIC_TAGS';
                      if (not isnull (strstr(tag, '#_')))
                      {
                        tag := replace(tag,  '#_', '');
                        tagType := 'RES_PRIVATE_TAGS';
                      }
                      if (self.command_mode < 3)
                      {
                        _mode := self.command_mode;
                        self.command_set (0, 3);
                        WEBDAV.DBA.dc_set_base (self.search_dc, 'path', WEBDAV.DBA.real_path (self.dir_path));
                        if ((_mode = 2) and (trim (self.simple.ufl_value) <> ''))
                          WEBDAV.DBA.dc_set_criteria (self.search_dc, '0', 'RES_NAME', 'like', trim (self.simple.ufl_value));
                      }
                      else
                      {
                        self.command_mode := 3;
                      }
                      tags := WEBDAV.DBA.dc_get_criteria (self.search_dc, null, tagType, 'contains_tags');
                      tagsID := WEBDAV.DBA.dc_get_criteria (self.search_dc, null, tagType, 'contains_tags', '@ID');
                      if (is_empty_or_null (tags))
                      {
                        tags := tag;
                      }
                      else if (isnull (strstr (tags, tag)))
                      {
                        tags := concat (tags, ', ', tag);
                      }
                      WEBDAV.DBA.dc_set_criteria (self.search_dc, tagsID, tagType, 'contains_tags', tags);
                      self.search_advanced := self.search_dc;
                    }
                    else if (_action = 'bookmarklet')
                    {
                      self.vc_redirect (sprintf ('%s/settings.vspx?sa=bookmarklet', ODRIVE.WA.odrive_url (self.domain_id)));
                      return;
                    }
                    self.vc_data_bind (self.vc_page.vc_event);
                   ]]>
                 </v:on-post>
              </v:button>
          <?vsp
            }
          ?>

          <!-- Simple search -->
          <v:template name="template_02" type="simple" enabled="-- case when ((self.command = 0) and (self.command_mode = 2)) then 1 else 0 end">
            <div class="boxHeader" style="text-align: center;">
              <b>Search </b>
              <v:text name="simple" value="--self.search_simple" fmt-function="WEBDAV.DBA.utf2wide" xhtml_onkeypress="return submitEnter(event, \'F1\')" xhtml_class="textbox" xhtml_size="70%" />
              &amp;nbsp;
              |
              <v:url url="home.vspx?mode=advanced" xhtml_onclick="javascript: vspxPost(\'action\', \'_cmd\', \'search\', \'mode\', \'advanced\'); return false;" value="Advanced" xhtml_title="Advanced Search"/>
              |
              <v:url url="home.vspx" value="Cancel" xhtml_title="Cancel" />
            </div>
          </v:template>

          <!-- Advanced Search -->
          <v:template name="template_03" type="simple" enabled="-- case when ((self.command = 0) and (self.command_mode = 3)) then 1 else 0 end">
            <div id="c1">
              <div class="tabs">
                <vm:tabCaption tab="7" tabs="10" caption="Criteria" />
                <span>
                <vm:tabCaption tab="10" tabs="10" caption="Options" />
                </span>
              </div>
              <div class="contents">
                <vm:search-dc-template7 />
                <vm:search-dc-template10 />
              </div>
              <div class="WEBDAV_formFooter">
                <v:button action="simple" name="ssSearch" value="Search" xhtml_onclick="javascript: cleanPost();">
                  <v:on-post>
                    <![CDATA[
                      -- save & validate metadata
                      declare rValue, params any;

                      params := self.vc_page.vc_event.ve_params;
                      self.search_advanced := self.search_dc;
                      self.search_dc := null;
                      rValue := self.dc_prepare ();
                      if (not isnull (rValue))
                      {
                        self.vc_error_message := rValue;
                        self.vc_is_valid := 0;
                        self.search_dc := self.search_advanced;
                        return;
                      }
                      self.search_advanced := self.search_dc;
                      self.dir_order := get_keyword ('ts_order', params, self.dir_order);
                      self.dir_direction := get_keyword ('ts_direction', params, self.dir_direction);
                      self.dir_grouping := get_keyword ('ts_grouping', params, '');
                      self.dir_cloud := cast(get_keyword ('ts_cloud', params, '0') as integer);
                      self.vc_data_bind (self.vc_page.vc_event);
                    ]]>
                  </v:on-post>
                </v:button>
                <v:button action="simple" name="ssClear" value="Clear" xhtml_title="Clear Criteria" xhtml_onclick="javascript: cleanPost();">
                  <v:on-post>
                    <![CDATA[
                      self.search_dc := null;
                      self.search_advanced := null;
                      self.noPrepare := 1;
                      self.vc_data_bind (self.vc_page.vc_event);
                    ]]>
                  </v:on-post>
                </v:button>
                <v:button action="simple" name="ssSave" value="Save" xhtml_title="Save as Smart Folder" enabled="--either (equ (self.dir_right, 'W'), 1, 0)" xhtml_onclick="javascript: cleanPost();">
                  <v:on-post>
                    <![CDATA[
                      -- save & validate metadata
                      declare rValue any;
                      rValue := self.dc_prepare ();
                      if (not isnull (rValue))
                      {
                        self.vc_error_message := rValue;
                        self.vc_is_valid := 0;
                        return;
                      }
                      self.command_push (10, 1);
                      self.vc_data_bind (self.vc_page.vc_event);
                    ]]>
                  </v:on-post>
                </v:button>
                <v:button action="simple" name="ssCancel" value="Cancel" xhtml_onclick="javascript: cleanPost();">
                  <v:on-post>
                    <![CDATA[
                      self.vc_is_valid := 1;
                      self.command_set (0, 0);
                      self.vc_data_bind (self.vc_page.vc_event);
                    ]]>
                  </v:on-post>
                </v:button>
              </div>
              <div style="margin: 0 0 6px 0;" />
            </div>
            <script>
              initDisabled();
              initTab(10, 7);
            </script>
          </v:template>

          <!-- Confirm replace -->
          <v:template name="tform_3" type="simple" enabled="-- equ (self.command, 14)">
            <div class="WEBDAV_formHeader">
              Confirm replace
            </div>
            <div class="form-confirm">
              <?vsp
                declare old_vector any;

                old_vector := WEBDAV.DBA.DAV_INIT (self.dav_vector[0]);
              ?>
              <table cellspacing="4">
                <tr>
                  <td colspan="7"><b>Replace confirmation for file: <?V self.dav_vector[0] ?></b><hr /></td>
                </tr>
                <tr>
                  <th>Name</th>
                  <th>Size</th>
                  <th>Modified</th>
                  <th>Type</th>
                  <th>Owner</th>
                  <th>Group</th>
                  <th>Perms</th>
                </tr>
                <tr>
                  <td colspan="7"><br /><b><i>Original file attributes:</i></b></td>
                </tr>
                <tr>
                  <td><?V WEBDAV.DBA.dav_get (old_vector, 'name') ?></td>
                  <td><?vsp http (WEBDAV.DBA.ui_size (WEBDAV.DBA.dav_get (old_vector, 'length'))); ?></td>
                  <td><?vsp http (WEBDAV.DBA.ui_date (WEBDAV.DBA.dav_get (old_vector, 'modificationTime'))); ?></td>
                  <td><?V WEBDAV.DBA.dav_get (old_vector, 'mimeType') ?></td>
                  <td><?V WEBDAV.DBA.dav_get (old_vector, 'ownerName') ?></td>
                  <td><?V WEBDAV.DBA.dav_get (old_vector, 'groupName') ?></td>
                  <td><?V DB.DBA.DAV_PERM_D2U (WEBDAV.DBA.dav_get (old_vector, 'permissions')) ?></td>
                </tr>
                <tr>
                  <td colspan="7"><br /><b><i>New file attributes:</i></b></td>
                </tr>
                <tr>
                  <td><?V WEBDAV.DBA.dav_get (old_vector, 'name') ?></td>
                  <td><?vsp http (WEBDAV.DBA.ui_size (length (self.dav_vector [1]))); ?></td>
                  <td><?vsp http (WEBDAV.DBA.ui_date (now())); ?></td>
                  <td><?V self.dav_vector [2] ?></td>
                  <td><?V WEBDAV.DBA.user_name (self.dav_vector [4]) ?></td>
                  <td><?V WEBDAV.DBA.user_name (self.dav_vector [5]) ?></td>
                  <td><?V DB.DBA.DAV_PERM_D2U (self.dav_vector [3]) ?></td>
                </tr>
                <tr>
                  <td colspan="7">
                    <br /><input type="checkbox" name="save_perms" id="save_perms" value="1" checked="checked"><label for="save_perms">Keep original owner/permissions</label></input>
                  </td>
                </tr>
              </table>
            </div>
            <div class="WEBDAV_formFooter">
              <v:button action="simple" name="rReplace" value="Replace">
                <v:on-post>
                  <![CDATA[
                    declare retValue integer;

                    WEBDAV.DBA.DAV_PROP_REMOVE (self.dav_vector[0], 'redirectref');
                    if (get_keyword('save_perms', self.vc_page.vc_event.ve_params) = '1')
                    {
                      declare old_vector any;

                      old_vector := WEBDAV.DBA.DAV_INIT (self.dav_vector[0]);
                      retValue := WEBDAV.DBA.DAV_RES_UPLOAD (self.dav_vector[0], self.dav_vector[1], WEBDAV.DBA.dav_get (old_vector, 'mimeType'), WEBDAV.DBA.dav_get (old_vector, 'permissions'), WEBDAV.DBA.dav_get (old_vector, 'ownerID'), WEBDAV.DBA.dav_get (old_vector, 'groupID'));
                    }
                    else
                    {
                      retValue := WEBDAV.DBA.DAV_RES_UPLOAD (self.dav_vector[0], self.dav_vector[1], self.dav_vector[2], self.dav_vector[3], self.dav_vector[4], self.dav_vector[5]);
                    }
                    if (WEBDAV.DBA.DAV_ERROR(retValue))
                    {
                      self.vc_error_message := WEBDAV.DBA.DAV_PERROR(retValue);
                      self.vc_is_valid := 0;
                      self.vc_data_bind (self.vc_page.vc_event);
                      return;
                    }
                    if (not isnull (self.dav_vector[6]))
                      WEBDAV.DBA.DAV_PROP_SET (self.dav_vector[0], 'redirectref', self.dav_vector[6]);

                    if (self.mode = 'webdav')
                    {
                      self.webdav_redirect (WEBDAV.DBA.path_parent (self.dav_vector[0], 1), '');
                      return;
                    }
                    self.command_pop (null);
                    self.vc_data_bind (self.vc_page.vc_event);
                  ]]>
                </v:on-post>
              </v:button>
              <v:button action="simple" name="rCancel" value="Cancel">
                <v:on-post>
                  <![CDATA[
                    self.command_pop (null);
                    self.vc_data_bind (self.vc_page.vc_event);
                  ]]>
                </v:on-post>
              </v:button>
            </div>
          </v:template>

          <!-- Create/update folder/file -->
          <v:template name="template_10" type="simple" enabled="-- equ (self.command, 10)">
            <v:before-data-bind>
              <![CDATA[
                declare parent_path, mode varchar;
                declare params any;

                params := self.vc_page.vc_event.ve_params;
                if (self.command_mode <> 1)
                  self.search_dc := null;

                mode := 'create';
                self.dav_path := WEBDAV.DBA.real_resource (self.source);
                self.dav_redirect := '';
                self.dav_is_redirect := 0;
                parent_path := WEBDAV.DBA.real_path_int (self.dir_path, 1, 'C');
                self.dav_enable := 1;
                if (self.command_mode = 10)
                {
                  mode := 'edit';
                  self.dav_item := WEBDAV.DBA.DAV_INIT (self.dav_path);
                  if (WEBDAV.DBA.DAV_ERROR (self.dav_item))
                  {
                    self.command_pop (null);
                    self.vc_data_bind (self.vc_page.vc_event);
                    return;
                  }
                  self.dav_type := WEBDAV.DBA.DAV_GET (self.dav_item, 'type');
                  self.dav_detClass := WEBDAV.DBA.det_class (self.dav_path, self.dav_type);
                  self.dav_ownClass := WEBDAV.DBA.det_ownClass (self.dav_path, self.dav_type);
                  self.dav_subClass := WEBDAV.DBA.det_subClass (self.dav_path, self.dav_type);
                  self.dav_redirect := self.dav_path;
                  self.dav_is_redirect := DB.DBA.IS_REDIRECT_REF (self.dav_redirect);
                }
                else if (self.command_mode in (5, 6, 7))
                {
                  declare V any;

                  V := WEBDAV.DBA.DAV_INIT_RESOURCE (self.dir_path);
                  if (self.command_mode = 6)
                    aset (V, 9, 'text/plain');

                  self.dav_item := V;
                  self.dav_type := 'R';
                  self.dav_detClass := WEBDAV.DBA.det_class (parent_path, 'C');
                  if (self.dav_detClass = '')
                    self.dav_detClass := WEBDAV.DBA.det_type (parent_path, 'C');

                  self.dav_ownClass := WEBDAV.DBA.det_subClass (parent_path, 'C');
                  self.dav_subClass := WEBDAV.DBA.det_subClass (parent_path, 'C');;
                  if (self.command_mode = 7)
                    self.dav_is_redirect := 1;
                }
                else
                {
                  self.dav_item := WEBDAV.DBA.DAV_INIT_COLLECTION (self.dir_path);
                  if (self.command_mode = 1)
                    params := vector_concat (params, vector ('dav_det', 'ResFilter', 'attr_dav_det', ''));

                  self.dav_type := 'C';
                  self.dav_detClass := WEBDAV.DBA.det_class (parent_path, 'C');
                  if (self.dav_detClass = '')
                    self.dav_detClass := WEBDAV.DBA.det_type (parent_path, 'C');

                  self.dav_ownClass := WEBDAV.DBA.det_subClass (parent_path, 'C');
                  self.dav_subClass := WEBDAV.DBA.det_subClass (parent_path, 'C');;
                }
                self.dav_detType := get_keyword ('dav_det', params, self.dav_subClass);
                self.dav_viewFields := self.viewFields (self.dav_ownClass, self.dav_type, mode);
                self.dav_editFields := self.editFields (self.dav_ownClass, self.dav_type, mode);
                if (not length (self.dav_editFields))
                  self.dav_enable := 0;

                -- dbg_obj_princ (self.dav_detType, self.dav_ownClass, self.dav_subClass);
                if (self.command_mode = 10)
                {
                  if (self.dav_enable)
                  {
                    if ((self.dav_type = 'R') and ((self.dav_path like '%,acl') or (self.dav_path like '%,meta')))
                    {
                      self.dav_enable := 0;
                    } else {
                      self.dav_enable := WEBDAV.DBA.write_permission (self.dav_path);
                    }
                  }

                  self.dav_enable_versioning := self.dav_enable;
                  if (self.dav_enable and WEBDAV.DBA.DAV_IS_LOCKED (self.dav_path, self.dav_type))
                    self.dav_enable := 0;

                  if (self.dav_enable and not WEBDAV.DBA.version_permission (self.dav_path))
                    self.dav_enable := 0;
                }
                if (isnull (get_keyword ('dav_group', params)))
                  self.dav_acl := WEBDAV.DBA.DAV_GET (self.dav_item, 'acl');

                if (self.command_mode = 10)
                {
                  if (isnull (get_keyword ('dav_group', params)))
                  {
                    self.dav_tags_private := '';
                    self.dav_tags_public := '';
                    if (self.dav_type = 'R')
                    {
                      self.dav_tags_private := WEBDAV.DBA.DAV_GET (self.dav_item, 'privatetags');
                      self.dav_tags_public := WEBDAV.DBA.DAV_GET (self.dav_item, 'publictags');
                    }
                    self.search_dc := WEBDAV.DBA.DAV_PROP_GET (self.dav_path, 'virt:Filter-Params');
                  }
                }
                if (not isnull (get_keyword ('dav_group', params)))
                  self.dc_prepare();
              ]]>
            </v:before-data-bind>
            <v:text name="formRight" xhtml_id="formRight" type="hidden" value="--self.dav_enable" />
            <vm:if test="self.command_mode = 10">
              <v:text name="item_path" xhtml_id="item_path" type="hidden" value="--WEBDAV.DBA.utf2wide (self.source)" />
            </vm:if>
            <div class="WEBDAV_formHeader">
              <v:label format="%V">:
                <v:before-data-bind>
                  <![CDATA[
                    if (self.command_mode = 10)
                    {
                      control.ufl_value := 'Properties of ' || WEBDAV.DBA.utf2wide (self.source);
                    } else {
                      control.ufl_value := case when (self.command_mode = 5) then 'Upload file into ' when (self.command_mode = 6) then 'Create file into ' when (self.command_mode = 7) then 'Create link into ' else 'Create folder in ' end || WEBDAV.DBA.path_show (self.dir_path);
                    }
                  ]]>
                </v:before-data-bind>
              </v:label>
            </div>
             <div id="c1">
              <div class="tabs">
                <vm:tabCaption tab="1"   tabs="18" caption="Main" />
                <v:template name="tform_5" type="simple" enabled="-- case when (self.viewField ('acl') or self.viewField ('aci')) and (self.command_mode = 10) then 1 else 0 end">
                <vm:tabCaption tab="2"   tabs="18" caption="Sharing" />
                </v:template>
                <v:template name="tform_7" type="simple" enabled="-- case when self.viewField ('version') and (self.command_mode = 10) and (self.dav_type = 'R') and not self.dav_is_redirect and (WEBDAV.DBA.DAV_GET (self.dav_item, 'name') not like '%,acl') and (WEBDAV.DBA.DAV_GET (self.dav_item, 'name') not like '%,meta') then 1 else 0 end">
                <vm:tabCaption tab="9"   tabs="18" caption="Versions" />
                </v:template>
                <v:template name="tform_8" type="simple" enabled="-- equ (self.dav_type, 'C')">
                <vm:tabCaption tab="4"   tabs="18" caption="WebMail" hide="1" />
                <vm:tabCaption tab="5"   tabs="18" caption="Filter" hide="1" />
                <vm:tabCaption tab="6"   tabs="18" caption="S3 Properties" hide="1" />
                <vm:tabCaption tab="7"   tabs="18" caption="Criteria" hide="1" />
                <vm:tabCaption tab="8"   tabs="18" caption="Linked Data Import" hide="1" />
                <v:template name="tform_17" type="simple" enabled="-- case when (isstring (DB.DBA.vad_check_version ('SyncML'))) then 1 else 0 end">
                <vm:tabCaption tab="10"  tabs="18" caption="SyncML" hide="1" />
                </v:template>
                <vm:tabCaption tab="11"  tabs="18" caption="IMAP Account" hide="1" />
                <v:template name="tform_171" type="simple" enabled="-- case when (self.dav_detClass = '') then 1 else 0 end">
                <vm:tabCaption tab="12"  tabs="18" caption="Google Drive" hide="1" />
                <vm:tabCaption tab="13"  tabs="18" caption="Dropbox" hide="1" />
                <vm:tabCaption tab="14"  tabs="18" caption="OneDrive" hide="1" />
                <vm:tabCaption tab="15"  tabs="18" caption="Box Net" hide="1" />
                <vm:tabCaption tab="16"  tabs="18" caption="WebDAV" hide="1" />
                <vm:tabCaption tab="17"  tabs="18" caption="Rackspace" hide="1" />
                </v:template>
                </v:template>
              </div>
              <div class="contents">
                <div id="1" class="tabContent">
                  <table class="WEBDAV_formBody WEBDAV_noBorder" cellspacing="0">
                    <v:template name="tf_1" type="simple" enabled="--case when self.viewField ('destination') and (self.command_mode in (5, 6)) then 1 else 0 end">
                      <tr>
                        <th width="30%" valign="top">
                          <vm:label value="--'Destination'" />
                        </th>
                        <td>
                          <label><?vsp http (sprintf ('<input type="radio" name="dav_destination" id="dav_destination_0" value="0" %s onchange="javascript: WEBDAV.toggleDavRows();" title="WebDAV" />', case when self.dav_destination = 0 then 'checked="checked"' else '' end)); ?> <b>WebDAV</b></label><br />
                          <label><?vsp http (sprintf ('<input type="radio" name="dav_destination" id="dav_destination_1" value="1" %s onchange="javascript: WEBDAV.toggleDavRows();" title="WebDAV" />', case when self.dav_destination = 1 then 'checked="checked"' else '' end)); ?> <b>Quad Store</b></label>
                          <![CDATA[
                            <script type="text/javascript">
                              OAT.MSG.attach(OAT, "PAGE_LOADED", function(){WEBDAV.toggleDavRows();});
                            </script>
                          ]]>
                        </td>
                      </tr>
                    </v:template>
                    <v:template name="tf_2" type="simple" enabled="--case when self.viewField ('source') and (self.command_mode = 5) then 1 else 0 end">
                      <tr>
                        <th width="30%" valign="top">
                          <v:label value="--'Source'" />
                        </th>
                        <td>
                          <label id="dav_source_0"><?vsp http (sprintf ('<input type="radio" name="dav_source" value="0" %s onchange="javascript: WEBDAV.toggleDavSource();" title="File" />', case when self.dav_source = 0 then 'checked="checked"' else '' end)); ?> <b>File</b></label><br />
                          <label id="dav_source_1"><?vsp http(sprintf ('<input type="radio" name="dav_source" value="1" %s onchange="javascript: WEBDAV.toggleDavSource();" title="URL" />', case when self.dav_source = 1 then 'checked="checked"' else '' end)); ?> <b>URL</b></label><br />
                          <label id="dav_source_2"><?vsp http (sprintf ('<input type="radio" name="dav_source" value="2" %s onchange="javascript: WEBDAV.toggleDavSource();" title="Quad Store Named Graph IRI" />', case when self.dav_source = 2 then 'checked="checked"' else '' end)); ?> <b>Quad Store Named Graph IRI</b></label>
                        </td>
                      </tr>
                      <tr>
                        <th valign="top">
                          <label id="dav_file_label">File</label>
                        </th>
                        <td>
                          <input type="file" name="dav_file" id="dav_file" onchange="javascript: F1.dav_source[0].checked=true; getFileName(this);" onblur="javascript: getFileName(this);" onfocus="javascript: F1.dav_source[0].checked=true;" size="60" />
                          <input type="text" name="dav_url"  id="dav_url"  value="<?V get_keyword ('dav_url', self.vc_page.vc_event.ve_params, get_keyword ('URI', self.vc_page.vc_event.ve_params, '')) ?>" onblur="javascript: getFileName(this);" onfocus="javascript: F1.dav_source[1].checked=true;" size="60" style="display: none;"/>
                          <input type="text" name="dav_rdf"  id="dav_rdf"  value="<?V get_keyword ('dav_rdf', self.vc_page.vc_event.ve_params, '') ?>" onblur="javascript: getFileName(this);" onfocus="javascript: F1.dav_source[2].checked=true;" size="60" style="display: none;"/>
                        </td>
                      </tr>
                    </v:template>
                    <v:template name="tf_3" type="simple" enabled="-- self.viewField ('name')">
                      <tr id="davRow_name">
                        <th width="30%">
                          <span id="label_dav"><vm:label for="dav_name" value="--either (equ (self.dav_type, 'R'), 'File name (*)', 'Folder name (*)')" /></span>
                          <span id="label_dav_rdf" style="display: none;"><vm:label for="label_dav_rdf" value="--'RDF graph name'" /></span>
                        </th>
                        <td>
                          <v:text name="rdfGraph_prefix" xhtml_id="rdfGraph_prefix" type="hidden" value="--self.detGraphUI2 ()" />
                          <v:text name="rdfBase_prefix"  xhtml_id="rdfBase_prefix" type="hidden" value="--WEBDAV.DBA.host_url () || WS.WS.FIXPATH (WEBDAV.DBA.real_path (self.dir_path))" />
                          <v:text name="dav_name"        xhtml_id="dav_name" value="--get_keyword ('dav_name', self.vc_page.vc_event.ve_params, get_keyword ('TITLE', self.vc_page.vc_event.ve_params, WEBDAV.DBA.DAV_GET (self.dav_item, 'name')))" format="%s" fmt-function="WEBDAV.DBA.utf2wide" xhtml_disabled="disabled" xhtml_onkeyup="javascript: WEBDAV.updateRdfGraph();">
                            <v:before-render>
                              <![CDATA[
                                control.vc_add_attribute ('class', 'field-short' || case when self.dav_enable and not self.editField ('name') then ' disabled' else '' end);
                              ]]>
                            </v:before-render>
                          </v:text>
                          <v:text name="dav_name_save"   xhtml_id="dav_name_save" type="hidden" value="--get_keyword ('dav_name', self.vc_page.vc_event.ve_params, get_keyword ('TITLE', self.vc_page.vc_event.ve_params, WEBDAV.DBA.DAV_GET (self.dav_item, 'name')))" />
                          <v:text name="dav_name_rdf"    xhtml_id="dav_name_rdf" value="--get_keyword ('dav_name', self.vc_page.vc_event.ve_params, WEBDAV.DBA.host_url() || WS.WS.FIXPATH(WEBDAV.DBA.real_path(self.dir_path)))" format="%s" fmt-function="WEBDAV.DBA.utf2wide" xhtml_disabled="disabled" xhtml_class="field-text" xhtml_style="display: none;" />
                        </td>
                      </tr>
                    </v:template>
                    <v:template name="tf_4" type="simple" enabled="--case when self.viewField ('mime') and (self.dav_type = 'R') and not self.dav_is_redirect then 1 else 0 end">
                      <tr id="davRow_mime">
                        <th width="30%">
                          <vm:label for="dav_mime" value="--'Content Type'" />
                        </th>
                        <td>
                          <vm:if test="WEBDAV.DBA.VAD_CHECK ('Framework')">
                            <v:text name="dav_mime" xhtml_id="dav_mime" value="--get_keyword ('dav_mime', self.vc_page.vc_event.ve_params, WEBDAV.DBA.DAV_GET (self.dav_item, 'mimeType'))" format="%s" xhtml_disabled="disabled">
                              <v:before-render>
                                <![CDATA[
                                  control.vc_add_attribute ('class', 'field-short' || case when self.dav_enable and not self.editField ('mime') then ' disabled' else '' end);
                                ]]>
                              </v:before-render>
                            </v:text>
                            <![CDATA[
                              <script type="text/javascript">
                                setInterval(WEBDAV.toggleEditor, 100);
                              </script>
                            ]]>
                            <vm:if test="self.editField ('mime') and self.dav_enable">
                              <input type="button" value="Select" onclick="javascript: windowShow('<?V WEBDAV.DBA.url_fix ('/ods/mimes_select.vspx?params=dav_mime:s1;') ?>');" disabled="disabled" class="button" />
                            </vm:if>
                          </vm:if>
                          <vm:if test="not WEBDAV.DBA.VAD_CHECK ('Framework')">
                            <v:data-list name="dav_mime2" xhtml_id="dav_mime2" sql="select '' as T_TYPE from WS.WS.SYS_DAV_USER where U_NAME = 'dav' union all select distinct T_TYPE from WS.WS.SYS_DAV_RES_TYPES order by T_TYPE" key-column="T_TYPE" value-column="T_TYPE">
                              <v:before-render>
                                <![CDATA[
                                  control.vc_add_attribute ('class', 'field-short' || case when self.dav_enable and not self.editField ('mime') then ' disabled' else '' end);
                                ]]>
                              </v:before-render>
                              <v:before-data-bind>
                                <![CDATA[
                                  control.ufl_value := get_keyword ('dav_mime2', self.vc_page.vc_event.ve_params, WEBDAV.DBA.DAV_GET (self.dav_item, 'mimeType'));
                                ]]>
                              </v:before-data-bind>
                            </v:data-list>
                          </vm:if>
                        </td>
                      </tr>
                    </v:template>
                    <v:template name="tf_5" type="simple" enabled="--case when self.viewField ('link') and self.dav_is_redirect then 1 else 0 end">
                      <tr id="davRow_link">
                        <th width="30%">
                          <vm:label for="dav_link" value="--'Link To'" />
                        </th>
                        <td>
                          <v:text name="dav_link" xhtml_id="dav_link" value="--self.dav_redirect" format="%s" xhtml_disabled="disabled">
                            <v:before-render>
                              <![CDATA[
                                control.vc_add_attribute ('class', 'field-short' || case when self.dav_enable and not self.editField ('link') then ' disabled' else '' end);
                              ]]>
                            </v:before-render>
                          </v:text>
                          <vm:if test="self.editField ('link') and self.dav_enable">
                            <input type="button" onclick="javascript: WEBDAV.davFileSelect ('dav_link');" value="Select"  disabled="disabled" class="button"/>
                          </vm:if>
                          <![CDATA[
                            <script type="text/javascript">
                              OAT.Loader.load(['dav'], function(){OAT.WebDav.init(davOptions);});
                            </script>
                          ]]>
                        </td>
                      </tr>
                    </v:template>
                    <v:template name="tf_6" type="simple" enabled="--case when self.viewField ('source') and (self.command_mode = 6) then 1 else 0 end">
                      <tr>
                        <th width="30%" valign="top">
                          File Content
                        </th>
                        <td>
                          <div id="dav_plain" style="display: <?V case when WEBDAV.DBA.VAD_CHECK ('Framework') and get_keyword ('dav_mime', self.vc_page.vc_event.ve_params, WEBDAV.DBA.DAV_GET (self.dav_item, 'mimeType')) = 'text/html' then 'none' else '' end ?>;">
                            <?vsp
                              http (sprintf ('<textarea id="dav_content_plain" name="dav_content_plain" style="width: 100%%; height: 170px">%V</textarea>', get_keyword ('dav_content_plain', self.vc_page.vc_event.ve_params, '')));
                            ?>
                          </div>
                          <vm:if test="WEBDAV.DBA.VAD_CHECK ('Framework')">
                            <div id="dav_html" style="display: <?V case when get_keyword ('dav_mime', self.vc_page.vc_event.ve_params, WEBDAV.DBA.DAV_GET (self.dav_item, 'mimeType')) = 'text/html' then '' else 'none' end ?>;">
                              <?vsp
                                http (sprintf ('<textarea id="dav_content_html" name="dav_content_html" style="width: 400px; height: 170px;">%V</textarea>', get_keyword ('dav_content_html', self.vc_page.vc_event.ve_params, '')));
                              ?>
                              <![CDATA[
                                <script type="text/javascript" src="/ods/ckeditor/ckeditor.js"></script>
                                <script type="text/javascript">
                                  CKEDITOR.config.startupMode = 'source';
                                  var oEditor = CKEDITOR.replace('dav_content_html');
                                </script>
                              ]]>
                            </div>
                          </vm:if>
                        </td>
                      </tr>
                    </v:template>
                    <v:template name="tf_7" type="simple" enabled="-- case when (self.dav_ownClass in ('', 'UnderVersioning')) and (self.dav_subClass in ('', 'UnderVersioning')) and (self.command_mode = 10) and (self.dav_type = 'C') then 1 else 0 end">
                      <vm:autoVersion />
                    </v:template>
                    <v:template name="tf_8" type="simple" enabled="-- case when self.viewField ('folderType') and (self.dav_type = 'C') then 1 else 0 end">
                      <tr>
                        <th width="30%">
                          <vm:label for="dav_det" value="--'Folder type'" />
                        </th>
                        <td>
                          <select name="dav_det" id="dav_det" onchange="javascript: updateLabel (this.options[this.selectedIndex].value);" disabled="disabled" class="<?V case when self.dav_enable and not self.editField ('owner') then ' disabled' else '' end ?>">
                            <?vsp
                              if    (self.command_mode = 1)
                              {
                                http (self.option_prepare('ResFilter', 'Smart Folder', 'ResFilter'));
                              }
                              else if ((self.dav_ownClass <> '') and (self.dav_ownClass <> 'UnderVersioning'))
                              {
                                http (self.option_prepare('', 'Normal', ''));
                              }
                              else
                              {
                                declare N, M, V any;

                                V := vector (
                                              0, '',           'Normal',
                                              1, 'Share',      'Shared Items',
                                              1, 'ResFilter',  'Smart Folder',
                                              1, 'CatFilter',  'Category Folder',
                                              1, 'PropFilter', 'Property Filter',
                                              1, 'HostFs',     'Host FS',
                                              0, 'rdfSink',    'Linked Data Import',
                                              1, 'RDFData',    'RDF Data',
                                              1, 'DynaRes',    'Dynamic Resources',
                                              2, 'SyncML',     'SyncML',
                                              1, 'Versioning', 'Version Control',
                                              1, 'S3',         'Amazon S3',
                                              1, 'GDrive',     'Google Drive',
                                              1, 'Dropbox',    'Dropbox',
                                              1, 'SkyDrive',   'OneDrive',
                                              1, 'Box',        'Box Net',
                                              1, 'WebDAV',     'WebDAV',
                                              1, 'RACKSPACE',  'Rackspace Cloud Files',
                                              1, 'nntp',       'Discussion',
                                              1, 'CardDAV',    'CardDAV',
                                              1, 'Blog',       'Blog',
                                              1, 'Bookmark',   'Bookmark',
                                              1, 'calendar',   'Calendar',
                                              1, 'CalDAV',     'CalDAV',
                                              1, 'News3',      'Feed Subscriptions',
                                              1, 'oMail',      'WebMail',
                                              1, 'IMAP',       'IMAP Mail Account');

                                M := 0;
                                for (N := 0; N < length (V); N := N + 3)
                                {
                                  if ((V[N] = 1) and (__proc_exists (sprintf ('DB.DBA.%s_DAV_AUTHENTICATE', V[N+1])) is null))
                                    goto _0;

                                  if ((V[N] = 2) and not isstring (DB.DBA.vad_check_version ('SyncML')))
                                    goto _0;

                                  if ((V[N+1] = 'GDrive') and isnull (WEBDAV.DBA.det_api_key ('Google API')))
                                    goto _0;

                                  if ((V[N+1] = 'Dropbox') and isnull (WEBDAV.DBA.det_api_key ('Dropbox API')))
                                    goto _0;

                                  if ((V[N+1] = 'SkyDrive') and isnull (WEBDAV.DBA.det_api_key ('Windows Live API')))
                                    goto _0;

                                  if ((V[N+1] = 'Box') and isnull (WEBDAV.DBA.det_api_key ('Box Net API')))
                                    goto _0;

                                  if (self.command_mode = 10)
                                  {
                                    if (self.dav_detType = V[N+1])
                                    {
                                      M := 1;
                                      http (self.option_prepare(V[N+1], V[N+2], self.dav_detType));
                                    }
                                  }
                                  else
                                  {
                                    M := 1;
                                    http (self.option_prepare(V[N+1], V[N+2], self.dav_detType));
                                  }
                                _0:;
                                }
                                if (not M)
                                  http (self.option_prepare(V[1], V[2], self.dav_detType));
                              }
                            ?>
                          </select>
                        </td>
                      </tr>
                    </v:template>
                    <v:template name="tf_9" type="simple" enabled="-- self.viewField ('owner')">
                      <tr id="davRow_owner">
                        <th width="30%">
                          <vm:label for="dav_owner" value="--'Owner'" />
                        </th>
                        <td>
                          <vm:if test="WEBDAV.DBA.VAD_CHECK ('Framework')">
                            <v:text name="dav_owner" xhtml_id="dav_owner" value="--get_keyword ('dav_owner', self.vc_page.vc_event.ve_params, WEBDAV.DBA.DAV_GET (self.dav_item, 'ownerName'))" format="%s" xhtml_disabled="disabled">
                              <v:before-render>
                                <![CDATA[
                                  control.vc_add_attribute ('class', 'field-short' || case when self.dav_enable and not self.editField ('owner') then ' disabled' else '' end);
                                ]]>
                              </v:before-render>
                              <v:after-data-bind>
                                <![CDATA[
                                  if (not WEBDAV.DBA.check_admin (self.account_id))
                                    control.tf_style := 3;
                                ]]>
                              </v:after-data-bind>
                            </v:text>
                            <vm:if test="self.editField ('owner') and self.dav_enable and WEBDAV.DBA.check_admin (self.account_id)">
                              <input type="button" value="Select" onclick="javascript: windowShow('/ods/users_select.vspx?mode=u_set&amp;params=dav_owner:s1;&nrows=<?V WEBDAV.DBA.settings_rows (self.settings) ?>')" disabled="disabled" class="button" />
                            </vm:if>
                          </vm:if>
                          <vm:if test="not WEBDAV.DBA.VAD_CHECK ('Framework')">
                            <v:data-list name="dav_owner2" xhtml_id="dav_owner2" sql="select -1 as U_ID, '&amp;lt;none&amp;gt;' as U_NAME from WS.WS.SYS_DAV_USER where U_NAME = 'dav' union all select TOP 100 U_ID, U_NAME from WS.WS.SYS_DAV_USER" key-column="U_NAME" value-column="U_NAME" instantiate="--case when WEBDAV.DBA.VAD_CHECK ('Framework') then 0 else 1 end">
                              <v:before-render>
                                <![CDATA[
                                  control.vc_add_attribute ('class', 'field-short' || case when self.dav_enable and not self.editField ('owner') then ' disabled' else '' end);
                                ]]>
                              </v:before-render>
                              <v:before-data-bind>
                                <v:script>
                                  <![CDATA[
                                    declare cur_user varchar;

                                    cur_user := connection_get('vspx_user');
                                    if (cur_user is null)
                                      return;

                                    control.ufl_value := get_keyword ('dav_owner2', self.vc_page.vc_event.ve_params, WEBDAV.DBA.DAV_GET (self.dav_item, 'ownerName'));
                                    if (control.ufl_value = '')
                                      control.ufl_value := cur_user;
                                  ]]>
                                </v:script>
                              </v:before-data-bind>
                            </v:data-list>
                          </vm:if>
                        </td>
                      </tr>
                    </v:template>
                    <v:template name="tf_10" type="simple" enabled="-- self.viewField ('group')">
                      <tr id="davRow_group">
                        <th width="30%">
                          <vm:label for="dav_group" value="--'Group'" />
                        </th>
                        <td>
                          <vm:if test="WEBDAV.DBA.VAD_CHECK ('Framework')">
                            <v:text name="dav_group" xhtml_id="dav_group" value="--get_keyword ('dav_group', self.vc_page.vc_event.ve_params, WEBDAV.DBA.DAV_GET (self.dav_item, 'groupName'))" format="%s" xhtml_disabled="disabled">
                              <v:before-render>
                                <![CDATA[
                                  control.vc_add_attribute ('class', 'field-short' || case when self.dav_enable and not self.editField ('group') then ' disabled' else '' end);
                                ]]>
                              </v:before-render>
                            </v:text>
                            <vm:if test="self.editField ('group') and self.dav_enable">
                              <input type="button" value="Select" onclick="javascript: windowShow('/ods/users_select.vspx?mode=g_set&amp;params=dav_group:s1;&nrows=<?V WEBDAV.DBA.settings_rows (self.settings) ?>')" disabled="disabled" class="button" />
                            </vm:if>
                          </vm:if>
                          <vm:if test="not WEBDAV.DBA.VAD_CHECK ('Framework')">
                            <v:data-list name="dav_group2" xhtml_id="dav_group2" sql="select -1 as G_ID, '&amp;lt;none&amp;gt;' as G_NAME from WS.WS.SYS_DAV_GROUP where G_NAME = 'administrators' union all select G_ID, G_NAME from WS.WS.SYS_DAV_GROUP" key-column="G_NAME" value-column="G_NAME" xhtml_class="field-short">
                              <v:before-render>
                                <![CDATA[
                                  control.vc_add_attribute ('class', 'field-short' || case when self.dav_enable and not self.editField ('group') then ' disabled' else '' end);
                                ]]>
                              </v:before-render>
                              <v:before-data-bind>
                                <v:script>
                                  <![CDATA[
                                    declare cur_user varchar;

                                    cur_user := connection_get('vspx_user');
                                    if (cur_user is null)
                                      return;

                                    control.ufl_value := get_keyword ('dav_group2', self.vc_page.vc_event.ve_params, WEBDAV.DBA.DAV_GET (self.dav_item, 'groupName'));
                                    if (control.ufl_value = '')
                                      control.ufl_value := cur_user;
                                  ]]>
                                </v:script>
                              </v:before-data-bind>
                            </v:data-list>
                          </vm:if>
                        </td>
                      </tr>
                    </v:template>
                    <v:template name="tf_11" type="simple" enabled="-- self.viewField ('permissions')">
                      <tr id="davRow_perms">
                        <th width="30%" valign="top">
                          <vm:label value="--'Permissions'" />
                        </th>
                        <td>
                          <table class="WEBDAV_permissionList" cellspacing="0" style="width: 250px;">
                            <vm:permissions-header1 />
                            <vm:permissions-header2 />
                            <tr>
                              <?vsp
                                declare i integer;
                                declare perms, checked, c, tdClass, cbClass varchar;

                                perms := WEBDAV.DBA.DAV_GET (self.dav_item, 'permissions');
                                for (i := 0; i < 9; i := i + 1)
                                {
                                  if (isnull (get_keyword ('dav_group', self.vc_page.vc_event.ve_params)))
                                  {
                                    c := subseq(perms, i, i+1);
                                  } else {
                                    c := get_keyword (sprintf ('dav_perm%i', i), self.vc_page.vc_event.ve_params, '0');
                                  }
                                  checked := case when (c <> '0') then 'checked' else '' end;
                                  tdClass :=
                                    'class="' ||
                                    case when (i = 8) then 'bottom right' else 'bottom' end ||
                                    '"';
                                  cbClass :=
                                    'class="' ||
                                    case when (self.dav_enable and not self.editField ('permissions')) or ((mod (i+1, 3) = 0) and not WEBDAV.DBA.check_admin (self.account_id)) then 'disabled' else '' end ||
                                    '"';
                                  http (sprintf ('<td %s><input type="checkbox" name="dav_perm%i" %s %s disabled="disabled" /></td>', tdClass, i, cbClass, checked));
                                }
                              ?>
                            </tr>
                          </table>
                        </td>
                      </tr>
                    </v:template>
                    <v:template name="tf_12" type="simple" enabled="-- case when self.viewField ('sse') and (self.dav_type = 'R') and ((self.dav_ownClass = 'S3') or ((self.dav_ownClass in ('', 'UnderVersioning')) and self.sse_enabled ())) and not self.dav_is_redirect then 1 else 0 end">
                      <v:before-data-bind>
                        <![CDATA[
                          self.dav_encryption := self.get_fieldProperty ('dav_encryption', self.dav_path, 'virt:server-side-encryption', 'None');
                          if (self.dav_encryption = 'UserAES256')
                          {
                            if (self.command_mode = 10)
                              self.dav_encryption_pwd := '**********';
                            else
                              self.dav_encryption_pwd := self.get_fieldProperty ('dav_encryption_password', self.dav_path, 'virt:server-side-encryption-password', '');
                          }
                          else
                          {
                            self.dav_encryption_pwd := '';
                          }
                        ]]>
                      </v:before-data-bind>
                      <tr id="davRow_encryption" width="30%">
                        <th>
                          <vm:label for="dav_encryption" value="--'Server Side Encryption'" />
                        </th>
                        <td>
                          <?vsp
                            http (sprintf ('<label><input type="radio" name="dav_encryption" id="dav_encryption_0" value="None" disabled="disabled" %s %s onchange="javascript: destinationChange(this, {checked: {hide: [''davRow_encryption_password'']}})"/><b>None</b></label>', case when not strcontains (self.dav_encryption, 'AES256') then 'checked="checked"' else '' end, case when self.dav_enable and not self.editField ('sse') then 'class="disabled"' else '' end));
                            http (sprintf ('<label><input type="radio" name="dav_encryption" id="dav_encryption_1" value="AES256" disabled="disabled" %s %s onchange="javascript: destinationChange(this, {checked: {hide: [''davRow_encryption_password'']}})"/><b>AES-256</b></label>', case when self.dav_encryption = 'AES256' then 'checked="checked"' else '' end, case when self.dav_enable and not self.editField ('sse') then 'class="disabled"' else '' end));
                            http (sprintf ('<label><input type="radio" name="dav_encryption" id="dav_encryption_2" value="UserAES256" disabled="disabled" %s %s onchange="javascript: destinationChange(this, {checked: {show: [''davRow_encryption_password'']}})"/><b>AES-256 (User''s Password)</b></label>', case when self.dav_encryption = 'UserAES256' then 'checked="checked"' else '' end, case when self.dav_enable and not self.editField ('sse') then 'class="disabled"' else '' end));
                          ?>
                        </td>
                      </tr>
                      <tr id="davRow_encryption_password" width="30%" style="display: none;">
                        <th>
                          <vm:label for="dav_encryption_password" value="--'SSE Password'" />
                        </th>
                        <td>
                          <v:text name="dav_encryption_password" type="password" xhtml_id="dav_encryption_password" value="--self.dav_encryption_pwd"  xhtml_size="20" xhtml_disabled="disabled" >
                            <v:before-render>
                              <![CDATA[
                                control.vc_add_attribute ('class', case when self.dav_enable and not self.editField ('sse') then ' disabled' else '' end);
                              ]]>
                            </v:before-render>
                          </v:text>
                          &amp;nbsp;<b>Retype</b>&amp;nbsp;
                          <v:text name="dav_encryption_password2" type="password" xhtml_id="dav_encryption_password2" value="--''"  xhtml_size="20" xhtml_disabled="disabled" >
                            <v:before-render>
                              <![CDATA[
                                control.vc_add_attribute ('class', case when self.dav_enable and not self.editField ('sse') then ' disabled' else '' end);
                              ]]>
                            </v:before-render>
                          </v:text>
                        </td>
                      </tr>
                      <![CDATA[
                        <script type="text/javascript">
                          OAT.MSG.attach(OAT, "PAGE_LOADED", function(){destinationChange($('dav_encryption_2'), {checked: {show: ['davRow_encryption_password']}, unchecked: {hide: ['davRow_encryption_password']}})});
                        </script>
                      ]]>
                    </v:template>
                    <v:template name="tf_13" type="simple" enabled="--case when self.viewField ('textSearch') and not self.dav_is_redirect then 1 else 0 end">
                      <tr id="davRow_text" width="30%">
                        <th>
                          <vm:label for="dav_index" value="--'Full Text Search'" />
                        </th>
                        <td>
                          <v:select-list name="dav_index" xhtml_id="dav_index" value="-- get_keyword ('dav_index', self.vc_page.vc_event.ve_params, WEBDAV.DBA.DAV_GET (self.dav_item, 'freeText'))" xhtml_disabled="disabled">
                            <v:before-render>
                              <![CDATA[
                                control.vc_add_attribute ('class', case when self.dav_enable and not self.editField ('textSearch') then 'disabled' else '' end);
                              ]]>
                            </v:before-render>
                            <v:item name="Off" value="N" />
                            <v:item name="Direct members" value="T" />
                            <v:item name="Recursively" value="R" />
                          </v:select-list>
                        </td>
                      </tr>
                    </v:template>
                    <v:template name="tf_14" type="simple" enabled="-- case when self.viewField ('inheritancePermissions') and (self.dav_type = 'C') then 1 else 0 end">
                      <tr id="davRow_permissions_inheritance" width="30%">
                        <th>
                          <vm:label for="dav_permissions_inheritance" value="--'Permissions Inheritance'" />
                        </th>
                        <td>
                          <v:select-list name="dav_permissions_inheritance" xhtml_id="dav_permissions_inheritance" value="-- get_keyword ('dav_permissions_inheritance', self.vc_page.vc_event.ve_params, WEBDAV.DBA.DAV_GET (self.dav_item, 'permissions-inheritance'))" xhtml_disabled="disabled">
                            <v:before-render>
                              <![CDATA[
                                control.vc_add_attribute ('class', case when self.dav_enable and not self.editField ('inheritancePermissions') then 'disabled' else '' end);
                              ]]>
                            </v:before-render>
                            <v:item name="Off" value="N" />
                            <v:item name="Direct members" value="M" />
                            <v:item name="Recursively" value="R" />
                          </v:select-list>
                        </td>
                      </tr>
                    </v:template>
                    <v:template name="tf_15" type="simple" enabled="-- case when self.viewField ('metadata') and not self.dav_is_redirect then 1 else 0 end">
                      <tr id="davRow_metadata" width="30%">
                        <th>
                          <vm:label for="dav_metagrab" value="--'Metadata Retrieval'" />
                        </th>
                        <td>
                          <v:select-list name="dav_metagrab" xhtml_id="dav_metagrab" value="--get_keyword ('dav_metagrab', self.vc_page.vc_event.ve_params, WEBDAV.DBA.DAV_GET (self.dav_item, 'metaGrab'))" xhtml_disabled="disabled">
                            <v:before-render>
                              <![CDATA[
                                control.vc_add_attribute ('class', case when self.dav_enable and not self.editField ('metadata') then 'disabled' else '' end);
                              ]]>
                            </v:before-render>
                            <v:item name="Off" value="N" />
                            <v:item name="Direct members" value="M" />
                            <v:item name="Recursively" value="R" />
                          </v:select-list>
                        </td>
                      </tr>
                    </v:template>
                    <v:template name="tf_16" type="simple" enabled="--case when self.viewField ('recursive') and (self.dav_type = 'C') and (self.command_mode = 10) then 1 else 0 end">
                      <tr>
                        <th width="30%"> </th>
                        <td>
                          <label>
                            <input type="checkbox" name="dav_recursive" id="dav_recursive" disabled="disabled" title="Recursive" class="<?V case when self.dav_enable and not self.editField ('recursive') then 'disabled' else '' end ?>" />
                            <b> Apply changes to all subfolders and resources</b>
                          </label>
                        </td>
                      </tr>
                    </v:template>
                    <v:template name="tf_17" type="simple" enabled="--case when self.viewField ('publicTags') and (self.dav_type = 'R') and (self.command_mode = 10) and not self.dav_is_redirect then 1 else 0 end">
                      <tr id="davRow_tagsPublic">
                        <th width="30%">
                          <vm:label for="f_tags_public" value="--'Public tags (comma-separated)'" />
                        </th>
                        <td>
                          <v:text name="f_tags_public" xhtml_id="f_tags_public" value="--self.dav_tags_public" xhtml_disabled="disabled">
                            <v:before-render>
                              <![CDATA[
                                control.vc_add_attribute ('class', 'field-short' || case when self.dav_enable and not self.editField ('publicTags') then ' disabled' else '' end);
                              ]]>
                            </v:before-render>
                          </v:text>
                          <v:template name="tform_18_1" type="simple" enabled="--case when self.dav_enable and self.editField ('publicTags') then 1 else 0 end">
                            <input type="button" value="Clear" onclick="javascript: $('f_tags_public').value = ''" class="button" />
                          </v:template>
                        </td>
                      </tr>
                    </v:template>
                    <v:template name="tf_18" type="simple" enabled="--case when self.viewField ('privateTags') and (self.dav_type = 'R') and (self.command_mode = 10) and not self.dav_is_redirect then 1 else 0 end">
                      <tr id="davRow_tagsPrivate">
                        <th width="30%">
                          <vm:label for="f_tags_private" value="--'Private tags (comma-separated)'"/>
                        </th>
                        <td>
                          <v:text name="f_tags_private" xhtml_id="f_tags_private" value="--self.dav_tags_private" xhtml_disabled="disabled">
                            <v:before-render>
                              <![CDATA[
                                control.vc_add_attribute ('class', 'field-short' || case when self.dav_enable and not self.editField ('privateTags') then ' disabled' else '' end);
                              ]]>
                            </v:before-render>
                          </v:text>
                          <v:template name="tform_18_2" type="simple" enabled="--case when self.dav_enable and self.editField ('privateTags') then 1 else 0 end">
                            <input type="button" value="Clear" onclick="javascript: $('f_tags_private').value = ''" class="button" />
                          </v:template>
                        </td>
                      </tr>
                    </v:template>
                    <v:template name="tf_19" type="simple" enabled="--case when self.viewField ('properties') and (self.command_mode = 10) and not self.dav_is_redirect then 1 else 0 end">
                      <tr>
                        <th valign="top" width="30%">
                          WebDAV Properties
                        </th>
                        <td>
                          <table>
                            <tr>
                              <td width="600px">
                                <?vsp
                                  declare N integer;
                                  declare properties any;

                                  properties := WEBDAV.DBA.DAV_PROP_LIST (self.dav_path, '%', vector ('virt:%', 'http://www.openlinksw.com/schemas/%', 'http://local.virt/DAV-RDF%'));
                                ?>
                                <table id="c_tbl" class="WEBDAV_formList" cellspacing="0">
                                  <tr>
                                    <th width="50%">Property</th>
                                    <th width="50%">Value</th>
                                    <vm:if test="self.viewField ('properties')">
                                      <th>Action</th>
                                    </vm:if>
                                  </tr>
                                  <tbody id="c_tbody">
                                    <![CDATA[
                                      <script type="text/javascript">
                                      <?vsp
                                        declare M integer;

                                        M := 0;
                                        for (N := 0; N < length (properties); N := N + 1)
                                        {
                                          M := M + 1;
                                          if (self.dav_enable and self.editField ('properties') and (properties[N][0] not like 'DAV:%'))
                                          {
                                            http (sprintf ('OAT.MSG.attach(OAT, "PAGE_LOADED", function(){TBL.createRow("c", null, {fld_1: {mode: 40, value: "%s", className: "_validate_", onbBlur: function(){validateField(this);}}, fld_2: {mode: 0, value: "%s"}});});', properties[N][0], properties[N][1]));
                                          } else {
                                            http (sprintf ('OAT.MSG.attach(OAT, "PAGE_LOADED", function(){TBL.createViewRow("c", {fld_1: {value: "%s", tdCssText: "white-space: nowrap;"}, fld_2: {value: "%s", tdCssText: "white-space: nowrap;"}});});', properties[N][0], properties[N][1]));
                                          }
                                        }
                                      ?>
                                      </script>
                                    ]]>
                                    <tr id="c_tr_no" style="display: <?V case when M=0 then '' else 'none' end ?>;"><td colspan="<?V (2 + self.viewField ('properties')) ?>"><b>No Properties</b></td></tr>
                                  </tbody>
                                </table>
                              </td>
                              <vm:if test="self.dav_enable and self.editField ('properties')">
                                <td valign="top" nowrap="nowrap">
                                  <span class="button pointer">
                                    <xsl:attribute name="onclick">javascript: TBL.createRow('c', null, {fld_1: {mode: 40, className: '_validate_', onblur: function(){validateField(this);}}, fld_2: {mode: 0}});</xsl:attribute>
                                  <img src="<?V self.image_src ('dav/image/add_16.png') ?>" border="0" class="button" alt="Add Property" title="Add Property" /> Add</span><br /><br />
                                </td>
                              </vm:if>
                            </tr>
                          </table>
                        </td>
                      </tr>
                    </v:template>
                  </table>
                </div>

                <v:template name="tform_20" type="simple" enabled="-- gte(self.command_mode, 10)">
                  <div id="2" class="tabContent">
                    <vm:if test='self.viewField (&apos;acl&apos;)'>
                      <fieldset>
                        <legend><b>ODS users/groups</b></legend>
                        <table width="100%">
                          <tr>
                            <td width="100%">
                              <table id="f_tbl" class="WEBDAV_formList" style="width: 100%;" cellspacing="0">
                                <tr>
                                  <th nowrap="nowrap">User/Group (WebID)</th>
                                  <th width="1%">Inheritance</th>
                                  <th width="1%" align="center" nowrap="nowrap">Allow<br />(R)ead, (W)rite, e(X)ecute</th>
                                  <th width="1%" align="center" nowrap="nowrap">Deny<br />(R)ead, (W)rite, e(X)ecute</th>
                                  <th width="1%">Action</th>
                                </tr>
                                <tbody id="f_tbody">
                                  <tr id="f_tr_no"><td colspan="5"><b>No Security</b></td></tr>
                                  <![CDATA[
                                    <script type="text/javascript">
                                    <?vsp
                                      declare M, N integer;
                                      declare acl, acl_values, V any;

                                      M := 0;
                                      V := vector (0, 'This object only', 1, 'This object, subfolders and files', 2, 'Subfolders and files', 3, 'Inherited');
                                      acl_values := WEBDAV.DBA.acl_vector (self.dav_acl);
                                      for (N := 0; N < length (acl_values); N := N + 1)
                                      {
                                        M := M + 1;
                                        acl := acl_values[N];
                                        if (self.dav_enable and self.editField ('acl') and (acl[1] <> 3))
                                        {
                                          http (sprintf ('OAT.MSG.attach(OAT, "PAGE_LOADED", function(){TBL.createRow("f", null, {fld_1: {mode: 51, value: "%s", formMode: "u", nrows: %d, tdCssText: "white-space: nowrap;", className: "_validate_"}, fld_2: {mode: 43, value: %d, tdCssText: "white-space: nowrap;", objectType: "%s"}, fld_3: {mode: 42, value: [%d, %d, %d], suffix: "_grant", onclick: function(){TBL.clickCell42(this);}, tdCssText: "width: 1%%; text-align: center;"}, fld_4: {mode: 42, value: [%d, %d, %d], suffix: "_deny", onclick: function(){TBL.clickCell42(this);}, tdCssText: "width: 1%%; text-align: center;"}});});', WEBDAV.DBA.account_iri (acl[0]), WEBDAV.DBA.settings_rows (self.settings), acl[1], self.dav_type, bit_and (acl[2], 4), bit_and (acl[2], 2), bit_and (acl[2], 1), bit_and (acl[3], 4), bit_and (acl[3], 2), bit_and (acl[3], 1)));
                                        } else {
                                          http (sprintf ('OAT.MSG.attach(OAT, "PAGE_LOADED", function(){TBL.createViewRow("f", {fld_1: {value: "%s"}, fld_2: {value: "%s", tdCssText: "white-space: nowrap;"}, fld_3: {mode: 42, value: [%d, %d, %d], tdCssText: "width: 1%%; text-align: center;"}, fld_4: {mode: 42, value: [%d, %d, %d], tdCssText: "width: 1%%; text-align: center;"}});});', WEBDAV.DBA.account_iri (acl[0]), get_keyword (acl[1], V, ''), bit_and (acl[2], 4), bit_and (acl[2], 2), bit_and (acl[2], 1), bit_and (acl[3], 4), bit_and (acl[3], 2), bit_and (acl[3], 1)));
                                        }
                                      }
                                    ?>
                                    </script>
                                  ]]>
                                </tbody>
                              </table>
                            </td>
                            <td valign="top" nowrap="nowrap">
                              <vm:if test="self.dav_enable and self.editField ('acl') and self.dav_type = 'C'">
                                <span class="button pointer">
                                  <xsl:attribute name="onclick">javascript: TBL.createRow('f', null, {fld_1: {mode: 51, formMode: 'u', tdCssText: 'white-space: nowrap;', className: '_validate_'}, fld_2: {mode: 43, value: 1, objectType: 'C'}, fld_3: {mode: 42, value: [1, 1, 0], suffix: '_grant', onclick: function(){TBL.clickCell42(this);}, tdCssText: 'width: 1%; text-align: center;'}, fld_4: {mode: 42,  suffix: '_deny', onclick: function(){TBL.clickCell42(this);}, tdCssText: 'width: 1%; text-align: center;'}});</xsl:attribute>
                                <img src="<?V self.image_src ('dav/image/add_16.png') ?>" border="0" class="button" alt="Add Security" title="Add Security" /> Add</span><br /><br />
                              </vm:if>
                              <vm:if test="self.dav_enable and self.viewField ('acl') and self.dav_type = 'R'">
                                <span class="button pointer">
                                  <xsl:attribute name="onclick">javascript: TBL.createRow('f', null, {fld_1: {mode: 51, formMode: 'u', tdCssText: 'white-space: nowrap;', className: '_validate_'}, fld_2: {mode: 43, value: 1, objectType: 'R'}, fld_3: {mode: 42, value: [1, 1, 0], suffix: '_grant', onclick: function(){TBL.clickCell42(this);}, tdCssText: 'width: 1%; text-align: center;'}, fld_4: {mode: 42,  suffix: '_deny', onclick: function(){TBL.clickCell42(this);}, tdCssText: 'width: 1%; text-align: center;'}});</xsl:attribute>
                                <img src="<?V self.image_src ('dav/image/add_16.png') ?>" border="0" class="button" alt="Add Security" title="Add Security" /> Add</span><br /><br />
                              </vm:if>
                            </td>
                          </tr>
                        </table>
                      </fieldset>
                    </vm:if>
                    <vm:if test="self.viewField ('aci')">
                      <fieldset>
                        <legend><b>WebID users</b></legend>
                        <table width="100%">
                          <tr>
                            <td width="100%">
                              <table id="s_tbl" class="WEBDAV_formList" style="width: 100%;" cellspacing="0">
                                <thead>
                                  <tr>
                                    <th width="1%" nowrap="nowrap">Access Type</th>
                                    <th nowrap="nowrap">WebID</th>
                                    <th width="1%" align="center" nowrap="nowrap">Allow<br />(R)ead, (W)rite, e(X)ecute</th>
                                    <th width="1%">Action</th>
                                  </tr>
                                </thead>
                                <tbody id="s_tbody">
                                  <tr id="s_tr_no"><td colspan="4"><b>No WebID Security</b></td></tr>
                                  <![CDATA[
                                    <script type="text/javascript">
                                    <?vsp
                                      declare L integer;
                                      declare aci_values, aci_parents any;

                                      aci_parents := WEBDAV.DBA.aci_parents (self.dav_path);
                                      for (L := 0; L < length (aci_parents); L := L + 1)
                                      {
                                        aci_values := WEBDAV.DBA.aci_load (aci_parents[L]);
                                        WEBDAV.DBA.aci_lines (aci_values);
                                      }
                                      aci_values := WEBDAV.DBA.aci_load (self.dav_path);
                                      if (self.dav_enable and self.editField ('aci') and (self.dav_path not like '%,acl') and (self.dav_path not like '%,meta'))
                                      {
                                        WEBDAV.DBA.aci_lines (aci_values, '', 'true');
                                      }
                                      else
                                      {
                                        WEBDAV.DBA.aci_lines (aci_values, 'disabled');
                                      }
                                    ?>
                                    </script>
                                  ]]>
                                </tbody>
                              </table>
                            </td>
                            <vm:if test="self.dav_enable and self.editField ('aci') and (self.dav_path not like '%,acl')and (self.dav_path not like '%,meta')">
                              <td valign="top" nowrap="nowrap">
                                <vm:if test="WEBDAV.DBA.VAD_CHECK ('Framework') and (sys_stat('st_has_vdb') = 1)">
                                  <span class="button pointer">
                                    <xsl:attribute name="onclick">javascript: TBL.createRow('s', null, {fld_1: {mode: 50, onchange: function(){TBL.changeCell50(this);}}, fld_2: {mode: 51, tdCssText: 'white-space: nowrap;', className: '_validate2_ _webid2_'}, fld_3: {mode: 52, value: [1, 0, 0], execute: true, execute: true, tdCssText: 'width: 1%; text-align: center;'}});</xsl:attribute>
                                  <img src="<?V self.image_src ('dav/image/add_16.png') ?>" border="0" class="button" alt="Add Security" title="Add Security" /> Add</span><br /><br />
                                </vm:if>
                                <vm:if test="not (WEBDAV.DBA.VAD_CHECK ('Framework') and (sys_stat('st_has_vdb') = 1))">
                                  <span class="button pointer">
                                    <xsl:attribute name="onclick">javascript: TBL.createRow('s', null, {fld_1: {mode: 50, noAdvanced: true, onchange: function(){TBL.changeCell50(this);}}, fld_2: {mode: 51, tdCssText: 'white-space: nowrap;', className: '_validate2_ _webid2_'}, fld_3: {mode: 52, value: [1, 0, 0], execute: true, execute: true, tdCssText: 'width: 1%; text-align: center;'}});</xsl:attribute>
                                  <img src="<?V self.image_src ('dav/image/add_16.png') ?>" border="0" class="button" alt="Add Security" title="Add Security" /> Add</span><br /><br />
                                </vm:if>
                              </td>
                            </vm:if>
                          </tr>
                        </table>
                      </fieldset>
                    </vm:if>
                  </div>
                </v:template>
                <v:template type="simple" enabled="-- equ (self.dav_type, 'C')">
                  <v:template name="src_4" type="simple" enabled="--case when (self.command_mode <> 10) or (self.dav_detType = 'oMail') then 1 else 0 end">
                    <vm:search-dc-template4 />
                  </v:template>
                  <v:template name="src_5" type="simple" enabled="--case when (self.command_mode <> 10) or (self.dav_detType = 'PropFilter') then 1 else 0 end">
                    <vm:search-dc-template5 />
                  </v:template>
                  <v:template name="src_6" type="simple" enabled="--case when (self.command_mode <> 10) or (self.dav_detType = 'S3') then 1 else 0 end">
                    <vm:search-dc-template6 />
                  </v:template>
                  <vm:search-dc-template7 />
                  <v:template name="src_7" type="simple" enabled="--case when (self.command_mode <> 10) or (self.dav_detType = 'rdfSink') then 1 else 0 end">
                    <vm:search-dc-template8 />
                  </v:template>
                  <vm:search-dc-template11 />
                  <v:template name="src_12" type="simple" enabled="--case when (self.command_mode <> 10) or (self.dav_detType = 'IMAP') then 1 else 0 end">
                    <vm:search-dc-template12 />
                  </v:template>
                  <v:template name="src_13" type="simple" enabled="--case when (self.command_mode <> 10) or (self.dav_detType = 'GDrive') then 1 else 0 end">
                    <vm:search-dc-template13 />
                  </v:template>
                  <v:template name="src_14" type="simple" enabled="--case when (self.command_mode <> 10) or (self.dav_detType = 'Dropbox') then 1 else 0 end">
                    <vm:search-dc-template14 />
                  </v:template>
                  <v:template name="src_15" type="simple" enabled="--case when (self.command_mode <> 10) or (self.dav_detType = 'SkyDrive') then 1 else 0 end">
                    <vm:search-dc-template15 />
                  </v:template>
                  <v:template name="src_16" type="simple" enabled="--case when (self.command_mode <> 10) or (self.dav_detType = 'Box') then 1 else 0 end">
                    <vm:search-dc-template16 />
                  </v:template>
                  <v:template name="src_17" type="simple" enabled="--case when (self.command_mode <> 10) or (self.dav_detType = 'WebDAV') then 1 else 0 end">
                    <vm:search-dc-template17 />
                  </v:template>
                  <v:template name="src_18" type="simple" enabled="--case when (self.command_mode <> 10) or (self.dav_detType = 'RACKSPACE') then 1 else 0 end">
                    <vm:search-dc-template18 />
                  </v:template>
                </v:template>
                <v:template type="simple" enabled="-- equ (self.dav_type, 'R')">
                  <vm:search-dc-template9 />
                </v:template>
              </div>
            </div>
            <div class="WEBDAV_formFooter">
              <v:button action="simple" name="cCreate" value="--case when (self.command_mode >= 10) then 'Update' else case when (self.command_mode = 5) then 'Upload' else 'Create' end end" enabled="--case when (self.dav_enable or (self.viewField ('sharing') and (self.mode <> 'webdav'))) then 1 else 0 end" xhtml_onclick="return WEBDAV.validateInputs(this);">
                <v:on-post>
                  <![CDATA[
                    declare N, M, retValue, dav_owner, dav_group, dav_encryption_state integer;
                    declare mode, dav_detType, dav_mime, dav_name, dav_link, dav_fullPath, dav_perms, msg, _p varchar;
                    declare properties, c_properties, v_properties any;
                    declare dav_acl, dav_aci, old_dav_aci, dav_filename, dav_file, rdf_content any;
                    declare params, detParams, itemList any;
                    declare tmp any;

                    msg := '';
                    declare exit handler for SQLSTATE '*'
                    {
                      if (__SQL_STATE = 'TEST')
                      {
                        self.vc_error_message := concat (msg, WEBDAV.DBA.test_clear (__SQL_MESSAGE));
                        self.vc_is_valid := 0;
                        return;
                      }
                      resignal;
                    };

                    params := e.ve_params;
                    if (self.command_mode = 0)
                    {
                      msg := 'Can not create folder. ';
                    }
                    else if (self.command_mode = 1)
                    {
                      msg := 'Can not create dynamic folder. ';
                    }
                    else if (self.command_mode = 5)
                    {
                      msg := 'Can not upload file. ';
                    }
                    else if (self.command_mode = 6)
                    {
                      msg := 'Can not create file. ';
                    }
                    else if (self.command_mode = 10)
                    {
                      msg := 'Can not update resource. ';
                    }
                    self.dav_destination := cast (get_keyword ('dav_destination', params, '0') as integer);
                    self.dav_source := cast (get_keyword ('dav_source', params, '-1') as integer);
                    if ((self.command_mode in (5, 6)) and (get_keyword ('dav_destination', params, '') = '1'))
                    {
                      -- RDF Triple Store
                      declare rdf_data, rdf_type, rdf_graph any;

                      if (self.command_mode = 6)
                      {
                        rdf_type := trim (get_keyword ('dav_mime', params, get_keyword ('dav_mime2', params, '')));
                        rdf_data := get_keyword (case when WEBDAV.DBA.VAD_CHECK ('Framework') and (rdf_type = 'text/html') then 'dav_content_html' else 'dav_content_plain' end, params, '');
                      }
                      else
                      {
                        if (self.dav_source = 0)
                        {
                          dav_filename := get_keyword ('filename', get_keyword_ucase('attr-dav_file', params));
                        }
                        else if (self.dav_source = 1)
                        {
                          dav_filename := get_keyword ('dav_url', params, '');
                        }
                        WEBDAV.DBA.test (dav_filename, vector ('name', 'Source', 'class', 'varchar', 'canEmpty', 0));
                        if (self.dav_source = 0)
                        {
                          if ((dav_filename like 'http://%') or (dav_filename like 'ftp://%'))
                          {
                            rdf_data := http_get (dav_filename);
                          }
                          else
                          {
                            declare pos integer;

                            pos := position ('dav_file', params);
                            rdf_data := aref_set_0 (params, pos);
                          }
                        }
                        else if (self.dav_source = 1)
                        {
                          rdf_data := http_get (dav_filename);
                        }
                        rdf_type := http_mime_type (dav_filename);
                      }
                      rdf_graph := trim (get_keyword ('dav_name_rdf', params));
                      WEBDAV.DBA.test (rdf_graph, vector ('name', 'Graph', 'class', 'varchar', 'canEmpty', 0));
                      retValue := WEBDAV.DBA.DAV_RDF_UPLOAD (rdf_data, rdf_type, rdf_graph);
                      if (not retValue)
                      {
                        self.vc_error_message := 'You have attempted to upload invalid data to the RDF Data Store.';
                        self.vc_is_valid := 0;
                        return;
                      }
                    }
                    else
                    {
                      -- WebDAV
                      -- Action test
                      v_properties := vector ();
                      if (self.command_mode = 10)
                      {
                        mode := 'edit';
                        dav_fullPath := WEBDAV.DBA.DAV_GET (self.dav_item, 'fullPath');
                        self.dav_id := WEBDAV.DBA.DAV_GET (self.dav_item, 'id');
                        if (WEBDAV.DBA.DAV_ERROR (self.dav_id))
                          signal('TEST', 'Folder/File could not be found!<>');

                        self.dav_type := WEBDAV.DBA.DAV_GET (self.dav_item, 'type');
                        self.dav_detClass := coalesce (WEBDAV.DBA.det_class (self.dav_path, self.dav_type) , '');
                        self.dav_ownClass := WEBDAV.DBA.det_ownClass (self.dav_path, self.dav_type);
                      }
                      else
                      {
                        declare parent_path varchar;

                        mode := 'create';
                        parent_path := WEBDAV.DBA.real_path_int (self.dir_path, 1, 'C');
                        self.dav_ownClass := WEBDAV.DBA.det_subClass (parent_path, 'C');
                      }
                      dav_encryption_state := 0;
                      self.dav_editFields := self.editFields (self.dav_ownClass, self.dav_type, mode);

                      if ((self.command_mode = 10) and not self.editField ('name'))
                        goto _test_1;

                      -- file/folde name
                      dav_name := trim (get_keyword ('dav_name', params));
                      if (is_empty_or_null (dav_name))
                        signal('TEST', 'Folder/File name can not be empty!<>');

                      if (strchr (dav_name, '/') is not null or strchr (dav_name, '\\') is not null)
                        signal('TEST', 'The folder/file name should not contain slash or back-slash symbols!<>');

                      if ((self.command_mode in (5, 6)) and (self.dav_type = 'R') and (dav_name like '%,acl'))
                        signal('TEST', 'The file names like ''*,acl'' are used for system purposes!<>');

                      if ((self.command_mode in (5, 6)) and (self.dav_type = 'R') and (dav_name like '%,meta'))
                        signal('TEST', 'The file names like ''*,meta'' are used for system purposes!<>');

                      if ((self.command_mode in (5, 6)) and (self.dav_type = 'R') and (self.dav_detClass = 'SkyDrive') and not DB.DBA.SkyDrive__validateName (dav_name))
                        signal('TEST', 'The SkyDrive file names must have an extension. The extension must be one of: .3g2, .3gp, .ai, .bmp, .chm, .doc, .docm, .docx, .dot, .dotx, .epub, .gif, .jpeg, .jpg, .mp4, .one, .pdf, .png, .pot, .potm, .potx, .pps, .ppsm, .ppsx, .ppt, .pptm, .pptx, .psd, .tif, .tiff, .txt, .xls, .xlsb, .xlsm, .xlsx, .wav, .webp, .wmv!');

                      if (self.command_mode = 10)
                      {
                        if (not self.editField ('name'))
                          goto _test_5;

                        dav_fullPath := WEBDAV.DBA.path_parent (dav_fullPath, 1) || dav_name;
                      }
                      else
                      {
                        dav_fullPath := rtrim (self.dir_path, '/') || '/' || dav_name;
                      }
                      if (self.dav_type = 'C')
                        dav_fullPath := dav_fullPath || '/';

                      dav_fullPath := WEBDAV.DBA.real_path (dav_fullPath, 1, self.dav_type);
                      if ((isnull (WEBDAV.DBA.DAV_GET (self.dav_item, 'fullPath')) or (WEBDAV.DBA.DAV_GET (self.dav_item, 'fullPath') <> dav_fullPath)) and ((self.dav_type = 'C') or (self.command_mode = 10)))
                      {
                        retValue := DB.DBA.DAV_SEARCH_ID (dav_fullPath, self.dav_type);
                        if (not WEBDAV.DBA.DAV_ERROR (retValue))
                          signal('TEST', 'Folder/File with such name already exists!<>');
                      }

                    _test_1:;
                      -- link
                      if (((self.command_mode = 10) and not self.editField ('link')) or not self.dav_is_redirect)
                        goto _test_2;

                      dav_link := trim (get_keyword ('dav_link', params));
                      WEBDAV.DBA.test (dav_link, vector ('name', 'Link To', 'class', 'varchar', 'minLength', 1));
                      tmp := DB.DBA.DAV_SEARCH_ID (dav_link, 'R');
                      if (WEBDAV.DBA.DAV_ERROR (tmp))
                        signal('TEST', 'File with such name does not exist!<>');

                    _test_2:;
                      -- validate public tags
                      if ((self.command_mode = 10) and not self.editField ('publicTag'))
                        goto _test_3;

                      self.dav_tags_public := trim (get_keyword ('f_tags_public', params, ''));
                      if (not WEBDAV.DBA.validate_tags (self.dav_tags_public))
                        signal('TEST', 'The expression contains no valid tag(s)!<>');

                    _test_3:;
                      -- validate private tags
                      if ((self.command_mode = 10) and not self.editField ('privateTag'))
                        goto _test_4;

                      self.dav_tags_private := trim (get_keyword ('f_tags_private', params, ''));
                      if (not WEBDAV.DBA.validate_tags (self.dav_tags_private))
                        signal('TEST', 'The expression contains no valid tag(s)!<>');

                    _test_4:;
                      if ((self.command_mode = 10) and not self.editField ('source'))
                        goto _test_5;

                      if (self.dav_type = 'C')
                      {
                        dav_detType := get_keyword ('dav_det', params);
                        if (dav_detType in ('IMAP', 'S3', 'GDrive', 'Dropbox', 'SkyDrive', 'Box', 'WebDAV', 'RACKSPACE'))
                        {
                          tmp := get_keyword (sprintf ('dav_%s_checkInterval', dav_detType), params);
                          WEBDAV.DBA.test (tmp, vector ('name', 'Check Interval', 'class', 'integer', 'minValue', 1));
                          if (dav_detType in ('Box', 'Dropbox', 'GDrive', 'SkyDrive', 'RACKSPACE', 'S3'))
                          {
                            if      (dav_detType = 'RACKSPACE')
                            {
                              detParams := self.detParamsPrepare (dav_detType, vector ('path', 'Type', 'User', 'Container', 'API_Key'), null);
                            }
                            else if (dav_detType = 'S3')
                            {
                              detParams := self.detParamsPrepare (dav_detType, vector ('path', 'BucketName', 'AccessKeyID', 'SecretKey'), null);
                            }
                            else
                            {
                              detParams := self.detOAuthParamsPrepare (dav_detType, null, vector ('path'), null);
                            }
                            tmp := call ('DB.DBA.' || dav_detType || '_VERIFY') (dav_fullPath, detParams);;
                            if (not isnull (tmp))
                              signal('TEST', tmp);
                          }
                        }
                        else if ((dav_detType = 'ResFilter') or (dav_detType = 'CatFilter'))
                        {
                          declare search_path varchar;

                          search_path := WEBDAV.DBA.real_path(WEBDAV.DBA.dc_get(self.search_dc, 'base', 'path', '/DAV/'));
                          if (search_path between dav_fullPath and (dav_fullPath || '\255\255\255\255'))
                            signal('TEST', sprintf('Search path (%s) can not contains in folder full path (%s)!<>', search_path, dav_fullPath));
                        }
                        else if (dav_detType = 'PropFilter')
                        {
                          declare search_path varchar;

                          search_path := WEBDAV.DBA.real_path (get_keyword ('dav_PropFilter_SearchPath', params, '/DAV/'));
                          retValue := DB.DBA.DAV_SEARCH_ID(search_path, 'C');
                          if (WEBDAV.DBA.DAV_ERROR (retValue))
                            signal('TEST', 'Search path does not exists!<>');
                        }
                        else if (dav_detType = 'rdfSink')
                        {
                          WEBDAV.DBA.test (get_keyword ('dav_rdfSink_graph', params), vector ('name', 'RDF Graph', 'class', 'varchar', 'minLength', 1, 'maxLength', 255));
                          WEBDAV.DBA.test (get_keyword ('dav_rdfSink_base', params), vector ('name', 'RDF Base URI', 'class', 'varchar', 'minLength', 0, 'maxLength', 255));
                        }
                        else if (dav_detType = 'IMAP')
                        {
                          WEBDAV.DBA.test (get_keyword ('dav_IMAP_server', params), vector ('name', 'IMAP Server', 'class', 'varchar', 'minLength', 1, 'maxLength', 255));
                          WEBDAV.DBA.test (get_keyword ('dav_IMAP_port', params), vector ('name', 'IMAP Port', 'class', 'integer', 'minLength', 1, 'maxLength', 4));
                          WEBDAV.DBA.test (get_keyword ('dav_IMAP_user', params), vector ('name', 'IMAP User', 'class', 'varchar', 'minLength', 1, 'maxLength', 255));
                          tmp := get_keyword ('dav_IMAP_password', params, '');
                          if ((tmp = '**********') and (self.command_mode = 10))
                            tmp := DB.DBA.IMAP__paramGet (self.dav_id, 'C', 'password', 0);

                          tmp := DB.DBA.IMAP__verify (
                            get_keyword ('dav_IMAP_connection', params),
                            get_keyword ('dav_IMAP_server', params),
                            get_keyword ('dav_IMAP_port', params),
                            get_keyword ('dav_IMAP_user', params),
                            tmp
                          );
                          if (tmp <> '')
                            signal('TEST', tmp);
                        }
                        else if (dav_detType = 'WebDAV')
                        {
                          WEBDAV.DBA.test (get_keyword ('dav_WebDAV_path', params), vector ('name', 'WebDAV Path', 'class', 'varchar', 'minLength', 1, 'maxLength', 255));
                          if (get_keyword ('dav_WebDAV_authenticationType', params, 'Digest') = 'Digest')
                          {
                            WEBDAV.DBA.test (get_keyword ('dav_WebDAV_user', params), vector ('name', 'WebDAV user', 'class', 'varchar', 'minLength', 1, 'maxLength', 255));
                            tmp := get_keyword ('dav_WebDAV_password', params, '');
                            if ((tmp = '**********') and (self.command_mode = 10))
                              tmp := DB.DBA.WebDAV__paramGet (self.dav_id, 'C', 'password', 0, 1, 1);

                            tmp := DB.DBA.WebDAV__verify (
                              get_keyword ('dav_WebDAV_path', params),
                              vector ('authenticationType', 'Digest', 'user', get_keyword ('dav_WebDAV_user', params), 'password', tmp)
                            );
                          }
                          else
                          {
                            WEBDAV.DBA.test (get_keyword ('dav_WebDAV_key', params), vector ('name', 'WebDAV Access Key', 'class', 'varchar', 'minLength', 1, 'maxLength', 255));
                            tmp := DB.DBA.WebDAV__verify (
                              get_keyword ('dav_WebDAV_path', params),
                              vector ('authenticationType', 'WebID', 'key', get_keyword ('dav_WebDAV_key', params), 'keyOwner', WEBDAV.DBA.account_name (self.account_id))
                            );
                            commit work;
                          }
                          if (tmp <> '')
                            signal('TEST', tmp);
                        }
                      }
                      if (self.command_mode = 5)
                      {
                        if (self.dav_source = 0)
                        {
                          dav_filename := get_keyword ('filename', get_keyword_ucase ('attr-dav_file', params));
                        }
                        else if (self.dav_source = 1)
                        {
                          dav_filename := get_keyword ('dav_url', params);
                        }
                        else if (self.dav_source = 2)
                        {
                          dav_filename := get_keyword ('dav_rdf', params);
                        }
                        WEBDAV.DBA.test (dav_filename, vector ('name', 'Source', 'class', 'varchar', 'canEmpty', 0));
                        if (self.dav_source = 0)
                        {
                          dav_file := get_keyword ('dav_file', params);
                        }
                        else if (self.dav_source = 1)
                        {
                          dav_file := http_get (dav_filename);
                        }
                        else if (self.dav_source = 2)
                        {
                          dav_file := WEBDAV.DBA.get_rdf (dav_filename);
                        }
                      }

                    _test_5:;
                      if ((self.command_mode = 10) and not self.editField ('mime'))
                        goto _test_6;

                      if (self.dav_type = 'R')
                      {
                        dav_mime := trim (get_keyword ('dav_mime', params, get_keyword ('dav_mime2', params, '')));
                        if (not (dav_mime like '%/%' or dav_mime like 'link:%'))
                          dav_mime := http_mime_type(dav_name);
                      }
                      if (self.command_mode = 6)
                      {
                        dav_file := get_keyword (case when WEBDAV.DBA.VAD_CHECK ('Framework') and (dav_mime = 'text/html') then 'dav_content_html' else 'dav_content_plain' end, params, '');
                      }

                    _test_6:;
                      if ((self.command_mode = 10) and not self.editField ('owner'))
                        goto _test_7;

                      dav_owner := WEBDAV.DBA.user_id (trim (get_keyword ('dav_owner', params, get_keyword ('dav_owner2', params, ''))));
                      if (dav_owner < 0)
                        dav_owner := null;

                    _test_7:;
                      if ((self.command_mode = 10) and not self.editField ('group'))
                        goto _test_8;

                      dav_group := WEBDAV.DBA.user_id (trim (get_keyword ('dav_group', params, get_keyword ('dav_group2', params, ''))));
                      if (dav_group < 0)
                        dav_group := null;

                      if (not WEBDAV.DBA.check_admin (self.account_id) and not WEBDAV.DBA.group_own (dav_group) and (coalesce (WEBDAV.DBA.DAV_GET (self.dav_item, 'groupID'), -1) <> coalesce (dav_group, -1)))
                        signal('TEST', 'Only own groups or ''dba'' group are allowed!<>');

                    _test_8:;
                      if ((self.command_mode = 10) and not self.editField ('permissions'))
                        goto _test_9;

                      dav_perms := '';
                      tmp := WEBDAV.DBA.DAV_GET (self.dav_item, 'permissions');
                      for (N := 0; N < 9; N := N + 1)
                      {
                        if ((mod (N+1, 3) = 0) and not WEBDAV.DBA.check_admin (self.account_id))
                        {
                          dav_perms := dav_perms || chr (tmp[N]);
                        }
                        else
                      {
                        dav_perms := dav_perms || case when get_keyword (sprintf ('dav_perm%i', N), params, '') = '' then '0' else '1' end;
                      }
                      }
                      if (dav_perms = '000000000')
                      {
                        declare own_id integer;

                        own_id := coalesce (dav_owner, (select min(U_ID) from WS.WS.SYS_DAV_USER));
                        dav_perms := (select U_DEF_PERMS from WS.WS.SYS_DAV_USER where U_ID = own_id);
                      }
                      dav_perms := concat (dav_perms, get_keyword ('dav_index', params, 'N'), get_keyword ('dav_metagrab', params, 'N'));

                    _test_9:;
                      if ((self.dav_type = 'C') or ((self.command_mode = 10) and not self.editField ('sse')))
                        goto _test_10;

                      self.dav_encryption := get_keyword ('dav_encryption', params, 'None');
                      if (self.dav_encryption <> 'UserAES256')
                        goto _test_10;

                      dav_encryption_state := 1;
                      self.dav_encryption_pwd := get_keyword ('dav_encryption_password', params);
                      WEBDAV.DBA.test (self.dav_encryption_pwd, vector ('name', 'SSE Password', 'class', 'varchar', 'minLength', 1, 'maxLength', 32));
                      if ((self.command_mode = 10) and (self.dav_encryption_pwd = '**********') and (get_keyword ('dav_encryption_password2', params) = ''))
                        goto _test_10;

                      if (self.dav_encryption_pwd <> get_keyword ('dav_encryption_password2', params))
                        signal('TEST', 'Bad SSE password. Please retype!<>');

                      if (coalesce (WS.WS.SSE_PASSWORD_GET (DB.DBA.DAV_SEARCH_ID (dav_fullPath, 'R'), 'R'), '') <> self.dav_encryption_pwd)
                        dav_encryption_state := 2;

                    _test_10:;
                      if ((self.command_mode = 10) and not self.editField ('properties'))
                        goto _test_11;

                      c_properties := WEBDAV.DBA.prop_params (params, self.account_id);

                    _test_11:;
                      if ((self.command_mode = 10) and not self.editField ('publicTags'))
                        goto _test_12;

                      -- validate tags
                      self.dav_tags_public := trim (get_keyword ('f_tags_public', params, ''));
                      if (not WEBDAV.DBA.validate_tags (self.dav_tags_public))
                        signal('TEST', 'The expression contains no valid tag(s)!<>');

                    _test_12:;
                      if ((self.command_mode = 10) and not self.editField ('privateTags'))
                        goto _test_13;

                      self.dav_tags_private := trim (get_keyword ('f_tags_private', params, ''));
                      if (not WEBDAV.DBA.validate_tags (self.dav_tags_private))
                        signal('TEST', 'The expression contains no valid tag(s)!<>');

                    _test_13:;
                      if ((self.command_mode = 10) and not self.editField ('aci'))
                        goto _test_14;

                        -- ACI (Web Access)
                      dav_aci := WEBDAV.DBA.aci_params (params);
                      DB.DBA.ACL_VALIDATE (dav_aci);

                    _test_14:;

                      -- Action execute
                      -- Update
                      if (self.command_mode = 10)
                      {
                        if (not self.editField ('name'))
                          goto _exec_1;

                        if (WEBDAV.DBA.DAV_GET (self.dav_item, 'fullPath') <> dav_fullPath)
                        {
                          WEBDAV.DBA.DAV_SET (WEBDAV.DBA.DAV_GET (self.dav_item, 'fullPath'), 'name', dav_name);
                          self.dav_path := dav_fullPath;
                        }

                      _exec_1:;
                        if (not self.editField ('mime'))
                          goto _exec_2;

                        if ((self.dav_type = 'R') and (WEBDAV.DBA.DAV_GET (self.dav_item, 'mimeType') <> dav_mime))
                          WEBDAV.DBA.DAV_SET (self.dav_path, 'mimeType', dav_mime);

                      _exec_2:;

                        if (not self.editField ('permissions'))
                          goto _exec_3;

                        if (WEBDAV.DBA.DAV_GET (self.dav_item, 'permissions') <> dav_perms)
                          WEBDAV.DBA.DAV_SET (self.dav_path, 'permissions', dav_perms);

                      _exec_3:;
                        if (not self.editField ('owner'))
                          goto _exec_4;

                        if ((WEBDAV.DBA.DAV_GET (self.dav_item, 'ownerID') <> dav_owner) or isnull (dav_owner))
                          WEBDAV.DBA.DAV_SET (self.dav_path, 'ownerID', dav_owner);

                      _exec_4:;
                        if (not self.editField ('group'))
                          goto _exec_5;

                        if ((WEBDAV.DBA.DAV_GET (self.dav_item, 'groupID') <> dav_group) or isnull (dav_group))
                          WEBDAV.DBA.DAV_SET (self.dav_path, 'groupID', dav_group);

                      _exec_5:;
                        if (not self.editField ('acl'))
                          goto _exec_6;

                        -- ACL
                        dav_acl := WEBDAV.DBA.DAV_GET (self.dav_item, 'acl');
                        self.dav_acl := WEBDAV.DBA.acl_params (params, dav_acl);
                        if ((dav_acl <> self.dav_acl) or dav_encryption_state)
                        {
                          if (not WEBDAV.DBA.DAV_ERROR (WEBDAV.DBA.DAV_SET (self.dav_path, 'acl', self.dav_acl)))
                            WEBDAV.DBA.acl_send_mail (self.account_id, self.dav_path, dav_acl, self.dav_acl, dav_encryption_state);
                        }

                      _exec_6:;
                        if (not self.editField ('aci'))
                          goto _exec_7;

                        -- ACI (Web Access)
                        old_dav_aci := WEBDAV.DBA.aci_load (self.dav_path);
                        if ((not WEBDAV.DBA.aci_compare (old_dav_aci, dav_aci)) or dav_encryption_state)
                        {
                          WEBDAV.DBA.aci_save (self.dav_path, dav_aci);
                          WEBDAV.DBA.aci_send_mail (self.account_id, self.dav_path, old_dav_aci, dav_aci, dav_encryption_state);
                        }

                      _exec_7:;
                      }

                      -- Folder
                      if (self.dav_type = 'C')
                      {
                        if (self.command_mode in (0, 1))
                        {
                          retValue := WEBDAV.DBA.DAV_COL_CREATE (dav_fullPath, dav_perms, dav_owner, dav_group);
                          if (WEBDAV.DBA.DAV_ERROR (retValue))
                            signal('TEST', concat(WEBDAV.DBA.DAV_PERROR (retValue), '<>'));

                          self.dav_path := dav_fullPath;
                          self.dav_id := retValue;
                        }
                        else
                        {
                          if (get_keyword ('dav_recursive', params, '') <> '')
                            WEBDAV.DBA.DAV_SET_RECURSIVE (self.dav_path, dav_perms, dav_owner, dav_group);

                          if ((dav_detType <> 'Versioning') and isinteger (self.dav_id))
                            {
                              -- clear old properties
                              itemList := DB.DBA.DAV_PROP_LIST_INT (DB.DBA.DAV_SEARCH_ID (dav_fullPath, 'C'), 'C', 'virt:%', 0);
                              foreach (any item in itemList) do
                              {
                                if (item[0] not like ('virt:aci_meta%'))
                                {
                                  v_properties := vector_concat (v_properties, vector (item));
                                  DB.DBA.DAV_PROP_REMOVE_INT (dav_fullPath, item[0], null, null, 0, 0, 0);
                                }
                              }
                              WEBDAV.DBA.exec ('delete from DB.DBA.SYNC_COLS_TYPES where CT_COL_ID = ?', vector (DB.DBA.DAV_SEARCH_ID (self.dav_path, 'C')));
                            }
                          }
                        WEBDAV.DBA.DAV_SET (dav_fullPath, 'permissions-inheritance', get_keyword ('dav_permissions_inheritance', params, 'N'));

                        if (not self.editField ('name'))
                          goto _exec_8;

                        -- set new properties
                        if (dav_detType in ('ResFilter', 'CatFilter'))
                        {
                          -- save & validate metadata
                          tmp := self.dc_prepare ();
                          if (not isnull (tmp))
                          {
                            self.vc_error_message := tmp;
                            self.vc_is_valid := 0;
                            return;
                          }
                          retValue := call ('WEBDAV.DBA.' || dav_detType || '_CONFIGURE') (self.dav_id, self.search_dc);
                          if (WEBDAV.DBA.DAV_ERROR (retValue))
                            signal('TEST', concat(WEBDAV.DBA.DAV_PERROR (retValue), '<>'));
                        }
                        else if (dav_detType = 'rdfSink')
                        {
                          detParams := self.detOAuthParamsPrepare (dav_detType, v_properties, vector ('graph', 'base'), 8);
                          WEBDAV.DBA.rdfSink_CONFIGURE (self.dav_id, detParams);
                        }
                        else if (dav_detType = 'SyncML')
                        {
                          if (__proc_exists ('DB.DBA.SYNC_MAKE_DAV_DIR'))
                          {
                            declare sync_version, sync_type any;

                            sync_version := get_keyword ('syncml_version', params, 'N');
                            sync_type := get_keyword ('syncml_type', params, 'N');
                            DB.DBA.SYNC_MAKE_DAV_DIR (sync_type, DB.DBA.DAV_SEARCH_ID (dav_fullPath, 'C'), dav_name, dav_fullPath, sync_version);
                          }
                        }
                        else if (dav_detType <> 'Versioning')
                        {
                          retValue := WEBDAV.DBA.DAV_SET (self.dav_path, 'detType', either (equ (dav_detType, ''), null, dav_detType));
                          if (dav_detType = 'oMail')
                          {
                            detParams := self.detParamsPrepare (dav_detType, vector ('FolderName', 'NameFormat'), null);
                            detParams := vector_concat (detParams, vector ('UserName', WEBDAV.DBA.account_name (self.account_id)));
                            DB.DBA.oMail_CONFIGURE (self.dav_id, detParams);
                          }
                          else if (dav_detType = 'IMAP')
                          {
                            self.virtPropertiesRestore (v_properties, 'virt:IMAP-%');

                            detParams := self.detParamsPrepare (dav_detType, vector ('activity', 'checkInterval', 'graph', 'connection', 'server', 'port', 'user', 'password', 'folder'), 11);
                            DB.DBA.IMAP_CONFIGURE (self.dav_id, detParams);
                          }
                          else if (dav_detType = 'PropFilter')
                          {
                            detParams := self.detParamsPrepare (dav_detType, vector ('SearchPath', 'PropName', 'PropValue'), null);
                            detParams := WEBDAV.DBA.set_keyword ('SearchPath', detParams, WEBDAV.DBA.real_path (get_keyword ('SearchPath', detParams, '')));
                            DB.DBA.PropFilter_CONFIGURE (self.dav_id, detParams);
                          }
                          else if (dav_detType = 'S3')
                          {
                            self.virtPropertiesRestore (v_properties, 'virt:S3-%');

                            detParams := self.detParamsPrepare (dav_detType, vector ('activity', 'checkInterval', 'path', 'graph', 'BucketName', 'AccessKeyID', 'SecretKey'), 6);
                            DB.DBA.S3_CONFIGURE (self.dav_id, detParams);
                          }
                          else if (dav_detType = 'GDrive')
                          {
                            detParams := self.detOAuthParamsPrepare (dav_detType, v_properties, vector ('activity', 'checkInterval', 'path', 'graph'), 12);
                              DB.DBA.GDrive_CONFIGURE (self.dav_id, detParams);
                            }
                          else if (dav_detType = 'Dropbox')
                          {
                            detParams := self.detOAuthParamsPrepare (dav_detType, v_properties, vector ('activity', 'checkInterval', 'path', 'graph'), 13);
                              DB.DBA.Dropbox_CONFIGURE (self.dav_id, detParams);
                            }
                          else if (dav_detType = 'SkyDrive')
                          {
                            detParams := self.detOAuthParamsPrepare (dav_detType, v_properties, vector ('activity', 'checkInterval', 'path', 'graph'), 14);
                              DB.DBA.SkyDrive_CONFIGURE (self.dav_id, detParams);
                            }
                          else if (dav_detType = 'Box')
                          {
                            detParams := self.detOAuthParamsPrepare (dav_detType, v_properties, vector ('activity', 'checkInterval', 'path', 'graph'), 15);
                              DB.DBA.Box_CONFIGURE (self.dav_id, detParams);

                          }
                          else if (dav_detType = 'WebDAV')
                          {
                            self.virtPropertiesRestore (v_properties, 'virt:WebDAV-%');

                            detParams := self.detParamsPrepare (dav_detType, vector ('activity', 'checkInterval', 'graph', 'path', 'authenticationType', 'user', 'password', 'key'), 16);
                            detParams := vector_concat (detParams, vector ('keyOwner', WEBDAV.DBA.account_name (self.account_id)));
                            DB.DBA.WebDAV_CONFIGURE (self.dav_id, detParams);
                          }
                          else if (dav_detType = 'RACKSPACE')
                          {
                            self.virtPropertiesRestore (v_properties, 'virt:RACKSPACE-%');

                            detParams := self.detParamsPrepare (dav_detType, vector ('activity', 'checkInterval', 'path', 'graph', 'Type', 'User', 'Container', 'API_Key'), 17);
                            DB.DBA.RACKSPACE_CONFIGURE (self.dav_id, detParams);
                          }
                        }
                      _exec_8:;
                      }

                      -- File
                      if (self.dav_type = 'R')
                      {
                        if (strcontains (self.dav_encryption, 'AES256'))
                          connection_set ('server-side-encryption', self.dav_encryption);

                        if (self.command_mode in (5, 6, 7))
                        {
                          if (self.dav_is_redirect)
                          {
                            dav_file := '';
                            dav_mime := 'application/octet-stream';
                          }

                          retValue := DB.DBA.DAV_SEARCH_ID (dav_fullPath, self.dav_type);
                          if (not WEBDAV.DBA.DAV_ERROR (retValue))
                          {
                            self.dav_vector := vector (dav_fullPath, dav_file, dav_mime, dav_perms, dav_owner, dav_group, case when (self.dav_is_redirect) then dav_link else null end);
                            self.command := 14;
                            self.vc_data_bind(e);
                            return;
                          }

                          rdf_content := dav_file;
                          retValue := WEBDAV.DBA.DAV_RES_UPLOAD (dav_fullPath, dav_file, dav_mime, dav_perms, dav_owner, dav_group);
                          if (WEBDAV.DBA.DAV_ERROR (retValue))
                            signal('TEST', concat (WEBDAV.DBA.DAV_PERROR (retValue), '<>'));

                          if ((self.mode = 'briefcase') and (dav_fullPath like (WEBDAV.DBA.dav_home2 (self.account_id, 'owner') || 'Public%')))
                            ODRIVE.WA.domain_ping (self.domain_id);
                        }

                        -- store server side encryption value
                        if (self.dav_encryption is not null)
                        {
                          if ((self.dav_encryption = 'UserAES256') and (self.dav_encryption_pwd <> '**********'))
                            WEBDAV.DBA.DAV_PROP_SET (dav_fullPath, 'virt:server-side-encryption-password', self.dav_encryption_pwd);

                            WEBDAV.DBA.DAV_PROP_SET (dav_fullPath, 'virt:server-side-encryption', self.dav_encryption);
                        }

                        if (not self.editField ('publicTags'))
                          goto _exec_9;

                        WEBDAV.DBA.DAV_SET (dav_fullPath, 'publictags', self.dav_tags_public);

                      _exec_9:;
                        if (not self.editField ('privateTags'))
                          goto _exec_10;

                        WEBDAV.DBA.DAV_SET (dav_fullPath, 'privatetags', self.dav_tags_private);

                      _exec_10:;
                      }

                      -- properties
                      if (not self.editField ('properties'))
                        goto _exec_11;

                      properties := WEBDAV.DBA.DAV_PROP_LIST (dav_fullPath, '%', vector ('redirectref', 'virt:%', 'DAV:%', 'http://www.openlinksw.com/schemas/%', 'http://local.virt/DAV-RDF%'));
                      for (N := 0; N < length (properties); N := N + 1)
                      {
                        WEBDAV.DBA.DAV_PROP_REMOVE (dav_fullPath, properties[N][0]);
                      }
                      for (N := 0; N < length (c_properties); N := N + 1)
                      {
                        WEBDAV.DBA.DAV_PROP_SET (dav_fullPath, c_properties[N][0], c_properties[N][1]);
                      }

                    _exec_11:;
                      -- symbolic link
                      if (not self.editField ('link') or not self.dav_is_redirect)
                        goto _exec_12;

                      WEBDAV.DBA.DAV_PROP_SET (dav_fullPath, 'redirectref', dav_link);

                    _exec_12:;
                      -- Auto versioning
                      if ((self.dav_type = 'C') or (self.command_mode <> 10))
                      {
                        if (WEBDAV.DBA.DAV_GET_AUTOVERSION (dav_fullPath) <> get_keyword ('dav_autoversion', params, ''))
                        {
                          retValue := WEBDAV.DBA.DAV_SET (dav_fullPath, 'autoversion', get_keyword ('dav_autoversion', params, ''));
                          if (WEBDAV.DBA.DAV_ERROR (retValue))
                            signal ('TEST', concat(WEBDAV.DBA.DAV_PERROR (retValue), '<>'));
                          if ((self.dav_type = 'R') and (WEBDAV.DBA.DAV_GET_AUTOVERSION (dav_fullPath) = ''))
                            WEBDAV.DBA.DAV_REMOVE_VERSION_CONTROL (dav_fullPath);
                        }
                      }
                    }
                    if ((self.mode = 'webdav') and (self.command_mode = 10))
                    {
                      self.webdav_redirect (WEBDAV.DBA.path_parent (self.dav_path, 1), '');
                      return;
                    }
                    self.dav_action := '';
                    self.command_pop (null);
                    self.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
              <v:button action="simple" name="cVerify" xhtml_id="cVerify" value="Verify" xhtml_onclick="WEBDAV.verifyDialog(); return false;" xhtml_style="display: none;"/>
              <v:button action="simple" name="cCancel" value="Cancel" >
                <v:on-post>
                  <![CDATA[
                    if ((self.mode = 'webdav') and (self.command_mode = 10))
                    {
                      self.webdav_redirect (WEBDAV.DBA.path_parent (self.dav_path, 1), '');
                      return;
                    }
                    self.command_pop (null);
                    self.dav_action := '';
                    self.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
            </div>
            <script>
              <![CDATA[
                updateLabel($v('dav_det'));
                initDisabled();
                initTab(17, 1);
              ]]>
            </script>
          </v:template>

          <v:template type="simple" name="template_20" enabled="--case when (self.command in (20, 30)) then 1 else 0 end">
            <v:before-data-bind>
              <![CDATA[
                declare item any;

                item := WEBDAV.DBA.DAV_INIT (self.source);
                self.mimeType := WEBDAV.DBA.DAV_GET (item, 'mimeType');
              ]]>
            </v:before-data-bind>
            <?vsp
              if (self.mode = 'webdav')
              {
            ?>
            <input type="hidden" name="a" id="a" value="<?V case when self.command = 20 then 'edit' else 'view' end ?>" />
            <input type="hidden" name="_path" id="_path" value="<?V self.source ?>" />
            <?vsp
              }
            ?>
            <div class="WEBDAV_formHeader">
              <?V case when self.command = 20 then 'Edit' else 'View' end ?> resource <?V WEBDAV.DBA.utf2wide (self.source) ?>
            </div>
            <div style="padding-right: 6px;">
              <div id="f_plain">
                <?vsp
                  http (sprintf ('<textarea id="f_content_plain" name="f_content_plain" style="width: 100%%; height: 360px" %s>%V</textarea>', case when self.command = 30 then 'disabled="disabled"' else '' end, WEBDAV.DBA.utf2wide (cast (WEBDAV.DBA.DAV_RES_CONTENT (self.source) as varchar))));
                ?>
              </div>
            </div>
            <div class="WEBDAV_formFooter">
              <v:button action="simple" name="Save_20" value="Save" enabled="--case when (self.command = 20) then 1 else 0 end">
                <v:on-post>
                  <![CDATA[
                    declare retValue, content, item any;
                    declare exit handler for SQLSTATE '*'
                    {
                      if (__SQL_STATE = 'TEST')
                      {
                        self.vc_error_message := WEBDAV.DBA.test_clear (__SQL_MESSAGE);
                        self.vc_is_valid := 0;
                        return;
                      }
                      resignal;
                    };

                    item := WEBDAV.DBA.DAV_INIT (self.source);
                    if (not WEBDAV.DBA.DAV_ERROR (item))
                    {
                      content := get_keyword ('f_content_plain', params, '');
                      retValue := WEBDAV.DBA.DAV_RES_UPLOAD (self.source, content, WEBDAV.DBA.DAV_GET (item, 'mimeType'), WEBDAV.DBA.DAV_GET (item, 'permissions'), WEBDAV.DBA.DAV_GET (item, 'ownerID'), WEBDAV.DBA.DAV_GET (item, 'groupID'));
                      if (WEBDAV.DBA.DAV_ERROR (retValue))
                        signal ('TEST', WEBDAV.DBA.DAV_PERROR (retValue) || '<>');
                    }
                    if (self.mode = 'webdav')
                    {
                      self.webdav_redirect (WEBDAV.DBA.path_parent (self.source, 1), '');
                      return;
                    }
                    self.command_pop (null);
                    self.vc_data_bind (self.vc_page.vc_event);
                  ]]>
                </v:on-post>
              </v:button>
              <v:button action="simple" name="Cancel_20" value="Cancel">
                <v:on-post>
                  <![CDATA[
                    if (self.mode = 'webdav')
                    {
                      self.webdav_redirect (WEBDAV.DBA.path_parent (self.source, 1), '');
                      return;
                    }
                    self.command_pop (null);
                    self.vc_data_bind (self.vc_page.vc_event);
                  ]]>
                </v:on-post>
              </v:button>
            </div>
          </v:template>

          <v:template type="simple" name="template_40" enabled="--case when (self.command in (40, 50, 60)) then 1 else 0 end">
            <div class="WEBDAV_formHeader">
              <?V case when (self.command = 40) then 'Move' else case when (self.command = 50) then 'Copy' else 'Delete' end end ?> listed items
            </div>
            <?vsp self.showSelected(); ?>
            <v:template type="simple" condition="((self.command <> 60) and (self.v_step <> 'error'))">
              <div class="WEBDAV_formBody">
                <table cellspacing="0">
                  <v:template type="simple" condition="(self.v_step = 'start')">
                    <th width="30%">
                      Destination folder
                    </th>
                    <td>
                      <input name="f_folder" id="f_folder" value="<?V self.v_source ?>" class="field-short" />&amp;nbsp;
                      <input type="button" class="button" onclick="javascript: WEBDAV.davFolderSelect ('f_folder');" value="Select" />
                      <![CDATA[
                        <script type="text/javascript">
                          OAT.Loader.load(["drag", "dav"], function(){OAT.WebDav.init(davOptions);});
                        </script>
                      ]]>
                    </td>
                  </v:template>
                  <v:template type="simple" condition="(self.v_step = 'overwrite')">
                    <th colspan="2">
                      Some folder(s)/file(s) could not to be written or have to overwrite existing ones. Do you want to try to overwrite?
                    </th>
                  </v:template>
                </table>
              </div>
            </v:template>
            <div class="WEBDAV_formFooter">
              <v:button action="simple" name="Move_40" value="--case when (self.command = 40) then 'Move' else case when (self.command = 50) then 'Copy' else 'Delete' end end" enabled="-- case when self.v_step <> 'error' then 1 else 0 end">
                <v:on-post>
                  <![CDATA[
                    declare I integer;
                    declare retValue, item, itemPath, itemList any;
                    declare targetPath varchar;

                    if (self.v_step = 'start')
                    {
                      self.v_target := '/' || get_keyword ('f_folder', e.ve_params, '') || '/';
                      self.v_target := replace (self.v_target, '//', '/');
                    }
                    if (self.v_step = 'overwrite')
                      self.overwriteFlag := 1;

                    itemList := vector();
                    for (i := 0; i < length (self.items); i := i+ 2)
                    {
                      itemPath := self.items[i];
                      item := WEBDAV.DBA.DAV_INIT (itemPath);
                      if (WEBDAV.DBA.DAV_ERROR (item))
                      {
                        retValue := item;
                        self.retItems (itemList, itemPath, item, '');
                      }
                      else
                      {
                        if (self.command = 60)
                        {
                          retValue := WEBDAV.DBA.DAV_DELETE (itemPath);
                          self.retItems (itemList, itemPath, retValue, 'Delete');
                        }
                        else
                        {
                          targetPath := WEBDAV.DBA.real_path (self.v_target) || WEBDAV.DBA.DAV_GET (item, 'name');
                          if (WEBDAV.DBA.DAV_GET (item, 'type') = 'C')
                          {
                            targetPath := targetPath || '/';
                          }
                          if (self.command = 50)
                          {
                            retValue := WEBDAV.DBA.DAV_COPY (itemPath, targetPath, self.overwriteFlag, WEBDAV.DBA.DAV_GET (item, 'permissions'));
                            self.retItems (itemList, itemPath, retValue, 'Copy');
                          }
                          else if (self.command = 40)
                          {
                            retValue := WEBDAV.DBA.DAV_MOVE (itemPath, targetPath, self.overwriteFlag);
                            self.retItems (itemList, itemPath, retValue, 'Move');
                          }
                        }
                      }
                    }
                    self.items := itemList;
                    if (length (self.items) = 0)
                    {
                      self.v_step := 'end';
                      self.command_pop (null);
                    }
                    else
                    {
                      if ((self.v_step = 'start') and (self.command <> 60))
                      {
                        self.v_step := 'overwrite';
                      }
                      else
                      {
                        self.v_step := 'error';
                      }
                    }
                    self.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
              <v:button action="simple" name="Cancel_40" value="Cancel">
                <v:on-post>
                  <![CDATA[
                    self.command_pop (null);
                    self.vc_data_bind (self.vc_page.vc_event);
                  ]]>
                </v:on-post>
              </v:button>
            </div>
          </v:template>

          <v:template name="template_70" type="simple" enabled="-- equ (self.command, 70)">
            <div class="WEBDAV_formHeader">
              Update properties for listed items
            </div>
            <?vsp self.showSelected(); ?>
            <v:template name="template_71" type="simple" enabled="-- case when self.v_step <> 'error' then 1 else 0 end">
              <div id="c1">
                <div class="tabs">
                  <vm:tabCaption tab="1" tabs="2" caption="Main" />
                  <vm:tabCaption tab="2" tabs="2" caption="Sharing" />
                </div>
                <div class="contents">
                  <div id="1" class="tabContent">
                    <table class="WEBDAV_formBody WEBDAV_noBorder" cellspacing="0">
                      <tr>
                        <th>
                          <vm:label for="prop_mime" value="--'Content Type'" />
                        </th>
                        <td>
                          <vm:if test="WEBDAV.DBA.VAD_CHECK ('Framework')">
                            <v:text name="prop_mime" xhtml_id="prop_mime" value="--'Do not change'" format="%s" xhtml_class="field-short" />&amp;nbsp;
                            <input type="button" value="Select" onclick="javascript: windowShow('<?V WEBDAV.DBA.url_fix ('/ods/mimes_select.vspx?params=prop_mime:s1;') ?>');" class="button" />
                          </vm:if>
                          <vm:if test="not WEBDAV.DBA.VAD_CHECK ('Framework')">
                            <v:data-list name="prop_mime2" xhtml_id="prop_mime2" sql="select 'Do not change' as T_TYPE from WS.WS.SYS_DAV_USER where U_NAME = 'dav' union all select distinct T_TYPE from WS.WS.SYS_DAV_RES_TYPES order by T_TYPE" key-column="T_TYPE" value-column="T_TYPE" xhtml_class="field-short">
                              <v:before-data-bind>
                                <v:script>
                                  <![CDATA[
                                    control.ufl_value := get_keyword ('prop_mime2', self.vc_page.vc_event.ve_params, 'Do not change');
                                  ]]>
                                </v:script>
                              </v:before-data-bind>
                            </v:data-list>
                          </vm:if>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <vm:label for="prop_owner" value="--'Owner'" />
                        </th>
                        <td>
                          <vm:if test="WEBDAV.DBA.VAD_CHECK ('Framework')">
                            <v:text name="prop_owner" xhtml_id="prop_owner" value="--'Do not change'" format="%s" xhtml_class="field-short" />&amp;nbsp;
                            <input type="button" value="Select" onclick="javascript: windowShow('/ods/users_select.vspx?mode=u_set&amp;params=prop_owner:s1;&nrows=<?V WEBDAV.DBA.settings_rows (self.settings) ?>')" class="button" />
                          </vm:if>
                          <vm:if test="not WEBDAV.DBA.VAD_CHECK ('Framework')">
                            <v:data-list name="prop_owner2" xhtml_id="prop_owner2" sql="select -1 as U_ID, 'Do not change' as U_NAME from WS.WS.SYS_DAV_USER where U_NAME = 'dav' union all select TOP 100 U_ID, U_NAME from WS.WS.SYS_DAV_USER" key-column="U_NAME" value-column="U_NAME" xhtml_class="field-short" instantiate="--case when WEBDAV.DBA.VAD_CHECK ('Framework') then 0 else 1 end">
                              <v:before-data-bind>
                                <v:script>
                                  <![CDATA[
                                    control.ufl_value := get_keyword ('prop_owner2', self.vc_page.vc_event.ve_params, 'Do not change');
                                  ]]>
                                </v:script>
                              </v:before-data-bind>
                            </v:data-list>
                          </vm:if>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <vm:label for="prop_group" value="--'Group'" />
                        </th>
                        <td>
                          <vm:if test="WEBDAV.DBA.VAD_CHECK ('Framework')">
                            <v:text name="prop_group" xhtml_id="prop_group" value="--'Do not change'" format="%s" xhtml_class="field-short" />&amp;nbsp;
                            <input type="button" value="Select" onclick="javascript: windowShow('/ods/users_select.vspx?mode=g_set&amp;params=prop_group:s1;')" class="button" />
                          </vm:if>
                          <vm:if test="not WEBDAV.DBA.VAD_CHECK ('Framework')">
                            <v:data-list name="prop_group2" xhtml_id="prop_group2" sql="select -1 as G_ID, 'Do not change' as G_NAME from WS.WS.SYS_DAV_GROUP where G_NAME = 'administrators' union all select G_ID, G_NAME from WS.WS.SYS_DAV_GROUP" key-column="G_NAME" value-column="G_NAME" xhtml_class="field-short">
                              <v:before-data-bind>
                                <v:script>
                                  <![CDATA[
                                    control.ufl_value := get_keyword ('prop_group2', self.vc_page.vc_event.ve_params, 'Do not change');
                                  ]]>
                                </v:script>
                              </v:before-data-bind>
                            </v:data-list>
                          </vm:if>
                        </td>
                      </tr>
                      <tr>
                        <th valign="top">
                          <vm:label value="--'Permissions'" />
                        </th>
                        <td>
                          <table class="WEBDAV_permissionList" cellspacing="0">
                            <vm:permissions-header1 text="Add"/>
                            <vm:permissions-header2 />
                            <tr>
                              <td>Add</td>
                              <?vsp
                                declare i integer;
                                declare S, D varchar;
                                for (i := 0; i < 9; i := i + 1)
                                {
                                  S := case when (i = 8) then 'class="right"' else '' end;
                                  D := case when (mod (i+1, 3) = 0) and not WEBDAV.DBA.check_admin (self.account_id) then 'disabled="disabled"' else '' end;
                                  http (sprintf ('<td %s><input type="checkbox" name="prop_add_perm%i" onclick="chkbx(this,prop_rem_perm%i);" %s /></td>', S, i, i, D));
                                }
                              ?>
                            </tr>
                            <tr>
                              <td class="bottom">Remove</td>
                              <?vsp
                                for (i := 0; i < 9; i := i + 1)
                                {
                                  S := case when (i = 8) then 'class="right bottom"' else 'class="bottom"' end;
                                  D := case when (mod (i+1, 3) = 0) and not WEBDAV.DBA.check_admin (self.account_id) then 'disabled="disabled"' else '' end;
                                  http (sprintf ('<td %s><input type="checkbox" name="prop_rem_perm%i" onclick="chkbx(this,prop_add_perm%i);" %s /></td>', S, i, i, D));
                                }
                              ?>
                            </tr>
                          </table>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <vm:label for="prop_index" value="--'Full Text Search'" />
                        </th>
                        <td>
                          <v:select-list name="prop_index" xhtml_id="prop_index" >
                            <v:item name="Do not change" value="*" />
                            <v:item name="Off" value="N" />
                            <v:item name="Direct members" value="T" />
                            <v:item name="Recursively" value="R" />
                          </v:select-list>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <vm:label for="prop_metagrab" value="--'Metadata Retrieval'" />
                        </th>
                        <td>
                          <v:select-list name="prop_metagrab" xhtml_id="prop_metagrab" >
                            <v:item name="Do not change" value="*" />
                            <v:item name="Off" value="N" />
                            <v:item name="Direct members" value="M" />
                            <v:item name="Recursively" value="R" />
                          </v:select-list>
                        </td>
                      </tr>
                      <tr>
                        <th />
                        <td valign="center">
                          <input type="checkbox" name="prop_recursive" id="prop_recursive" title="Recursive" />
                          <vm:label for="prop_recursive" value="--'Recursive'" />
                        </td>
                      </tr>
                      <tr>
                        <th valign="top">WebDAV Properties</th>
                        <td>
                          <table>
                            <tr>
                              <td width="600px">
                                <table id="c_tbl" class="WEBDAV_formList" cellspacing="0">
                                  <tr>
                                    <th width="50%">Property</th>
                                    <th width="50%">Value</th>
                                    <th>Action</th>
                                    <th>&amp;nbsp;</th>
                                  </tr>
                                  <tr id="c_tr_no"><td colspan="4"><b>No Properties</b></td></tr>
                                </table>
                              </td>
                              <td valign="top" nowrap="nowrap">
                                <span class="button pointer">
                                  <xsl:attribute name="onclick">javascript: TBL.createRow('c', null, {fld_1: {mode: 40, className: '_validate_', onblur: function(){validateField(this);}}, fld_2: {mode: 0}, fld_3: {mode: 41}});</xsl:attribute>
                                <img src="<?V self.image_src ('dav/image/add_16.png') ?>" class="button" alt="Add Property" title="Add Property" /> Add</span><br /><br />
                              </td>
                            </tr>
                          </table>
                        </td>
                      </tr>
                    </table>
                  </div>

                  <div id="2" class="tabContent">
                    <fieldset>
                      <legend><b>ODS users/groups</b></legend>
                      <table>
                        <tr>
                          <td width="100%">
                            <table id="f_tbl" class="WEBDAV_formList" style="width: 100%;"  cellspacing="0">
                              <thead>
                                <tr>
                                  <th nowrap="nowrap">User/Group</th>
                                  <th>Inheritance</th>
                                  <th width="1%" align="center" nowrap="nowrap">Allow<br />(R)ead, (W)rite, e(X)ecute</th>
                                  <th width="1%" align="center" nowrap="nowrap">Deny<br />(R)ead, (W)rite, e(X)ecute</th>
                                  <th width="1%">Action</th>
                                </tr>
                              </thead>
                              <tbody id="f_tbody">
                                <tr id="f_tr_no"><td colspan="5"><b>No Security Properties</b></td></tr>
                              </tbody>
                          </table>
                          </td>
                          <td valign="top" nowrap="nowrap">
                            <span class="button pointer">
                              <xsl:attribute name="onclick">javascript: TBL.createRow('f', null, {fld_1: {mode: 51, formMode: 'u', tdCssText: 'white-space: nowrap;', className: '_validate_'}, fld_2: {mode: 43, value: 1}, fld_3: {mode: 42, value: [1, 1, 0], suffix: '_grant', onclick: function(){TBL.clickCell42(this);}, tdCssText: 'width: 1%; text-align: center;'}, fld_4: {mode: 42,  suffix: '_deny', onclick: function(){TBL.clickCell42(this);}, tdCssText: 'width: 1%; text-align: center;'}});</xsl:attribute>
                            <img src="<?V self.image_src ('dav/image/add_16.png') ?>" class="button" alt="Add Security" title="Add Security" /> Add</span><br /><br />
                          </td>
                        </tr>
                      </table>
                    </fieldset>
                    <fieldset>
                      <legend><b>WebID users</b></legend>
                      <table>
                        <tr>
                          <td width="100%">
                            <table id="s_tbl" class="WEBDAV_formList" style="width: 100%;"  cellspacing="0">
                              <thead>
                                <tr>
                                  <th width="1%" align="center" nowrap="nowrap">Acces Type</th>
                                  <th nowrap="nowrap">WebID</th>
                                  <th width="1%" align="center" nowrap="nowrap">Allow<br />(R)ead, (W)rite, e(X)ecute</th>
                                  <th width="1%" >Action</th>
                                </tr>
                              </thead>
                              <tbody id="s_tbody" >
                                <tr id="s_tr_no"><td colspan="4"><b>No Security Properties</b></td></tr>
                              </tbody>
                            </table>
                          </td>
                          <td valign="top" nowrap="nowrap">
                            <vm:if test="WEBDAV.DBA.VAD_CHECK ('Framework') and (sys_stat('st_has_vdb') = 1)">
                              <span class="button pointer">
                                <xsl:attribute name="onclick">javascript: TBL.createRow('s', null, {fld_1: {mode: 50, onchange: function(){TBL.changeCell50(this);}}, fld_2: {mode: 51, form: 'F1', tdCssText: 'white-space: nowrap;', className: '_validate_ _uri_'}, fld_3: {mode: 52, value: [1, 0, 0], execute: true, tdCssText: 'width: 1%; text-align: center;'}});</xsl:attribute>
                              <img src="<?V self.image_src ('dav/image/add_16.png') ?>" class="button" alt="Add Security" title="Add Security" /> Add</span><br /><br />
                            </vm:if>
                            <vm:if test="not (WEBDAV.DBA.VAD_CHECK ('Framework') and (sys_stat('st_has_vdb') = 1))">
                              <span class="button pointer">
                                <xsl:attribute name="onclick">javascript: TBL.createRow('s', null, {fld_1: {mode: 50, noAdvanced: true, onchange: function(){TBL.changeCell50(this);}}, fld_2: {mode: 51, form: 'F1', tdCssText: 'white-space: nowrap;', className: '_validate_ _uri_'}, fld_3: {mode: 52, value: [1, 0, 0], execute: true, tdCssText: 'width: 1%; text-align: center;'}});</xsl:attribute>
                              <img src="<?V self.image_src ('dav/image/add_16.png') ?>" class="button" alt="Add Security" title="Add Security" /> Add</span><br /><br />
                            </vm:if>
                          </td>
                        </tr>
                      </table>
                    </fieldset>
                  </div>
                </div>
              </div>
            </v:template>
            <div class="WEBDAV_formFooter">
              <v:button action="simple" name="Update_70" value="Update" enabled="--case when self.v_step <> 'error' then 1 else 0 end">
                <v:on-post>
                  <![CDATA[
                    declare I, N integer;
                    declare retValue, item, itemPath, itemList, params any;
                    declare prop_owner, prop_group integer;
                    declare prop_mime, prop_add_perms, prop_rem_perms, prop_perms, one, zero varchar;
                    declare c_properties, c_property, c_value, c_action any;
                    declare old_dav_acl, dav_acl, acl_value, aci_value any;
                    declare exit handler for SQLSTATE '*'
                    {
                      if (__SQL_STATE = 'TEST')
                      {
                        self.vc_error_message := WEBDAV.DBA.test_clear (__SQL_MESSAGE);
                        self.vc_is_valid := 0;
                        return;
                      }
                      resignal;
                    };

                    params := e.ve_params;
                    prop_mime  := trim (get_keyword ('prop_mime', params, get_keyword ('prop_mime2', params, '')));
                    prop_owner := WEBDAV.DBA.user_id (trim (get_keyword ('prop_owner', params, get_keyword ('prop_owner2', params, ''))));
                    prop_group := WEBDAV.DBA.user_id (trim (get_keyword ('prop_group', params, get_keyword ('prop_group2', params, ''))));

                    -- validate group
                    if (not WEBDAV.DBA.check_admin (self.account_id) and not WEBDAV.DBA.group_own (prop_group))
                    {
                      self.vc_error_message := 'Only own groups or ''dba'' group are allowed!';
                      self.vc_is_valid := 0;
                      return;
                    }
                    -- validate ACL rules
                    DB.DBA.ACL_VALIDATE (WEBDAV.DBA.aci_params (params));

                    one := ascii('1');
                    zero := ascii('0');
                    prop_add_perms := '000000000N';
                    for (N := 0; N < 9; N := N + 1)
                    {
                      if (get_keyword (sprintf ('prop_add_perm%i', N), params, '') <> '')
                        aset(prop_add_perms, N, one);
                    }
                    prop_rem_perms := '000000000N';
                    for (N := 0; N < 9; N := N + 1)
                    {
                      if (get_keyword (sprintf ('prop_rem_perm%i', N), params, '') <> '')
                        aset(prop_rem_perms, N, one);
                    }

                    -- changing or adding properties
                    c_properties := WEBDAV.DBA.prop_params (params, self.account_id);

                    -- acl properties
                    acl_value := WS.WS.ACL_PARSE (WEBDAV.DBA.acl_params (params));

                    -- aci properties
                    aci_value := WEBDAV.DBA.aci_n3 (WEBDAV.DBA.aci_params (params));

                    itemList := vector ();
                    for (I := 0; I < length (self.items); I := I + 2)
                    {
                      itemPath := self.items[I];
                      item := WEBDAV.DBA.DAV_INIT (itemPath);
                      if (WEBDAV.DBA.DAV_ERROR (item))
                      {
                        self.retItems (itemList, itemPath, item, '');
                      }
                      else
                      {
                        if (('' <> prop_mime) and ('Do not change' <> prop_mime) and (WEBDAV.DBA.DAV_GET (item, 'type') = 'R') and (WEBDAV.DBA.DAV_GET (item, 'mimeType') <> prop_mime))
                        {
                          retValue := WEBDAV.DBA.DAV_SET (itemPath, 'mimeType', prop_mime);
                          self.retItems (itemList, itemPath, retValue, 'Type update');
                        }
                        if ((prop_owner <> -1) and (isnull (WEBDAV.DBA.DAV_GET (item, 'ownerID')) or (WEBDAV.DBA.DAV_GET (item, 'ownerID') <> prop_owner)))
                        {
                          retValue := WEBDAV.DBA.DAV_SET (itemPath, 'ownerID', prop_owner);
                          self.retItems (itemList, itemPath, retValue, 'Owner update');
                        }
                        if ((prop_group <> -1) and (isnull (WEBDAV.DBA.DAV_GET (item, 'groupID')) or (WEBDAV.DBA.DAV_GET (item, 'groupID') <> prop_group)))
                        {
                          retValue := WEBDAV.DBA.DAV_SET (itemPath, 'groupID', prop_group);
                          self.retItems (itemList, itemPath, retValue, 'Group update');
                        }
                        -- permissions
                        prop_perms := WEBDAV.DBA.DAV_GET (item, 'permissions');
                        for (N := 0; N < 10; N := N + 1)
                        {
                          if (prop_add_perms[N] = one)
                            aset(prop_perms, N, one);
                          if (prop_rem_perms[N] = one)
                            aset (prop_perms, N, zero);
                        }
                        if (get_keyword ('prop_index', params, '*') <> '*')
                        {
                          aset (prop_perms, 9, ascii (get_keyword ('prop_index', params)));
                        }
                        if (get_keyword ('prop_metagrab', params, '*') <> '*')
                        {
                          if (length(prop_perms) < 11)
                            prop_perms := concat(prop_perms, ' ');
                          aset (prop_perms, 10, ascii (get_keyword ('prop_metagrab', params)));
                        }
                        retValue := WEBDAV.DBA.DAV_SET (itemPath, 'permissions', prop_perms);
                        self.retItems (itemList, itemPath, retValue, 'Permissons update');

                        -- recursive
                        if ((WEBDAV.DBA.DAV_GET (item, 'type') = 'C') and ('' <> get_keyword ('prop_recursive', params, '')))
                        {
                          WEBDAV.DBA.DAV_SET_RECURSIVE (itemPath, prop_perms, prop_owner, prop_group);
                        }

                        -- properties
                        for (N := 0; N < length (c_properties); N := N + 1)
                        {
                          if (c_properties[N][0] <> '')
                          {
                            if (c_properties[N][2] = 'U')
                            {
                              retValue := WEBDAV.DBA.DAV_PROP_SET (itemPath, c_properties[N][0], c_properties[N][1]);
                              self.retItems (itemList, itemPath, retValue, 'Property update');
                            }
                            else if (c_properties[N][2] = 'R')
                            {
                              retValue := WEBDAV.DBA.DAV_PROP_REMOVE (itemPath, c_properties[N][0]);
                              self.retItems (itemList, itemPath, retValue, 'Property delete');
                            }
                          }
                        }

                        -- acl
                        if (length (acl_value))
                        {
                          dav_acl := WEBDAV.DBA.DAV_GET (item, 'acl');
                          old_dav_acl := dav_acl;
                          foreach (any acl in acl_value) do
                          {
                            if ((WEBDAV.DBA.DAV_GET (item, 'type') = 'C') or (acl[2] = 0))
                            {
                              WS.WS.ACL_ADD_ENTRY (dav_acl, acl[0], acl[3], acl[1], acl[2]);
                            }
                          }
                          if (old_dav_acl <> dav_acl)
                          {
                            if (not WEBDAV.DBA.DAV_ERROR (WEBDAV.DBA.DAV_SET (itemPath, 'acl', dav_acl)))
                            {
                              WEBDAV.DBA.acl_send_mail (self.domain_id, self.account_id, itemPath, old_dav_acl, dav_acl);
                            }
                          }
                        }

                        -- aci - WebAccess
                        if (length (aci_value))
                        {
                          retValue := WEBDAV.DBA.DAV_PROP_SET (itemPath, 'virt:aci_meta_n3', aci_value);
                          self.retItems (itemList, itemPath, retValue, 'ACL update');
                        }
                      }
                    }
                    self.items := itemList;
                    if (length (self.items) = 0)
                    {
                      self.v_step := 'end';
                      self.command_pop (null);
                    }
                    else
                    {
                      self.v_step := 'error';
                    }
                    self.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
              <v:button action="simple" name="Cancel_70" value="Cancel">
                <v:on-post>
                  <![CDATA[
                    self.command_pop (null);
                    self.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
            </div>
            <script>
              initTab(2, 1);
            </script>
          </v:template>

          <v:template name="template_80" type="simple" enabled="-- equ (self.command, 80)">
            <v:before-data-bind>
              <![CDATA[
                if (self.v_step = 'start')
                {
                  declare N integer;
                  declare tmp any;

                  self.v_path := self.items[0];
                  tmp := rtrim (self.items[0], '/');
                  N := strrchr (tmp, '/');
                  if (isnull(N))
                    N := 0;
                  self.v_parent := left (tmp, N);
                  self.v_old := trim (subseq(tmp, N, length(tmp)), '/');
                  self.v_new := self.v_old;
                }
              ]]>
            </v:before-data-bind>
            <div class="WEBDAV_formHeader">
              Rename resource
            </div>
            <div >
              <table class="WEBDAV_formBody" cellspacing="0">
                <tr>
                  <th width="30%">
                    Parent Folder
                  </th>
                  <td>
                    <span class="text"><v:label value="--self.v_parent" /></span>
                  </td>
                </tr>
                <tr>
                  <th>
                    Old Name
                  </th>
                  <td>
                    <v:text name="f_old" value="--self.v_old" xhtml_disabled="disabled" xhtml_size="65%" />
                  </td>
                </tr>
                <tr>
                  <th>
                    <vm:label for="f_new" value="New Name" />
                  </th>
                  <td>
                    <v:text name="f_new" value="--self.v_new" xhtml_size="65%" />
                  </td>
                </tr>
              </table>
            </div>
            <div class="WEBDAV_formFooter">
              <v:button action="simple" value="Rename">
                <v:on-post>
                  <![CDATA[
                    declare retValue, oldName, newName any;

                    oldName := trim (self.f_old.ufl_value);
                    newName := trim (self.f_new.ufl_value);
                    if (oldName <> newName)
                    {
                      WEBDAV.DBA.test (newName, vector('name', 'New Name', 'class', 'varchar', 'type', 'varchar', 'canEmpty', 0));
                      retValue := WEBDAV.DBA.DAV_SET (self.v_path, 'name', newName);
                      if (WEBDAV.DBA.DAV_ERROR (retValue))
                        signal('TEST', WEBDAV.DBA.DAV_PERROR (retValue) || '<>');
                    }
                    self.v_step := 'end';
                    self.command_pop (null);
                    self.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
              <v:button action="simple" name="Cancel_80" value="Cancel">
                <v:on-post>
                  <![CDATA[
                    self.command_pop (null);
                    self.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
            </div>
          </v:template>

          <v:template name="template_90" type="simple" enabled="-- equ (self.command, 90)">
            <div class="WEBDAV_formHeader">
              Tag listed items
            </div>
            <?vsp self.showSelected(); ?>
            <div>
              <table class="WEBDAV_formBody" cellspacing="0">
                <tr>
                  <th>
                    <v:label for="f90_tags_public" value="Public tags (comma-separated)"/>
                  </th>
                  <td>
                    <v:text name="f90_tags_public" xhtml_id="f90_tags_public" xhtml_class="textbox" xhtml_size="60"/>
                    <v:template name="template_901" type="simple">
                    <input type="button" value="Clear" onclick="javascript: $('f90_tags_public').value = ''" class="button" />
                    </v:template>
                  </td>
                </tr>
                <tr>
                  <th>
                    <v:label for="f90_tags_private" value="Private tags (comma-separated)"/>
                  </th>
                  <td>
                    <v:text name="f90_tags_private" xhtml_id="f90_tags_private" xhtml_class="textbox" xhtml_size="60"/>
                    <v:template name="template_902" type="simple">
                    <input type="button" value="Clear" onclick="javascript: $('f90_tags_private').value = ''" class="button" />
                    </v:template>
                  </td>
                </tr>
              </table>
            </div>
            <div class="WEBDAV_formFooter">
              <v:button action="simple" value="Tag">
                <v:on-post>
                  <![CDATA[
                    declare N integer;
                    declare itemPath, tags, tagsPublic, tagsPrivate any;

                    tagsPublic := trim (self.f90_tags_public.ufl_value);
                    if (not WEBDAV.DBA.validate_tags (tagsPublic))
                    {
                      signal ('TEST', 'The expression contains no valid tag(s)!<>');
                    }
                    tagsPrivate := trim (self.f90_tags_private.ufl_value);
                    if (not WEBDAV.DBA.validate_tags (tagsPrivate))
                    {
                      signal ('TEST', 'The expression contains no valid tag(s)!<>');
                    }
                    if ((tagsPublic <> '') or (tagsPrivate <> ''))
                    {
                      for (N := 0; N < length (self.items); N := N + 2)
                      {
                        itemPath := self.items[N];
                        if (tagsPublic <> '')
                        {
                          tags := WEBDAV.DBA.DAV_PROP_GET (itemPath, ':virtpublictags', '');
                          WEBDAV.DBA.DAV_PROP_SET (itemPath, ':virtpublictags', WEBDAV.DBA.tags_join (tags, tagsPublic));
                        }
                        if (tagsPrivate <> '')
                        {
                          tags := WEBDAV.DBA.DAV_PROP_GET (itemPath, ':virtprivatetags', '');
                          WEBDAV.DBA.DAV_PROP_SET (itemPath, ':virtprivatetags', WEBDAV.DBA.tags_join (tags, tagsPrivate));
                        }
                      }
                    }
                    self.v_step := 'end';
                    self.command_pop (null);
                    self.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
              <v:button action="simple" name="Cancel_90" value="Cancel">
                <v:on-post>
                  <![CDATA[
                    self.command_pop (null);
                    self.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
            </div>
          </v:template>

          <!-- Header -->
          <v:template type="simple" name="Brouse_Header" enabled="-- case when (((self.command in (0)) and (self.command_mode in (0, 1)))) then 1 else 0 end">
            <div class="boxHeader">
              <b><vm:label for="path" value="' Path '" /></b>
              <v:text name="path" xhtml_id="path" value="--WEBDAV.DBA.utf2wide(WEBDAV.DBA.path_show (self.dir_path))" xhtml_onkeypress="return submitEnter(event, \'F1\', \'action\', \'go\')" xhtml_size="60" />
              <img class="pointer" border="0" alt="Browse Path" title="Browse Path" src="<?V self.image_src ('dav/image/go_16.png') ?>" onclick="javascript: vspxPost('action', '_cmd', 'go');" />
              <b><v:label for="list_type_internal" value="' View '" /></b>
              <v:select-list name="list_type_internal" xhtml_id="list_type_internal" value="--self.dir_details" xhtml_onchange="javascript: doPost(\'F1\', \'reload\'); return false">
                <v:item name="Details" value="0" />
                <v:item name="List" value="1" />
              </v:select-list>
              <v:template type="simple" enabled="-- case when ((self.command in (0)) and (self.command_mode in (0,1))) then 1 else 0 end">
                <b><v:label for="filter" value="--' Filter Pattern '" /></b>
                <v:text name="filter" xhtml_id="filter" value="--self.search_filter" type="simple" />
                <img class="pointer" border="0" alt="Filter" title="Filter" src="<?V self.image_src ('dav/image/filter_16.png') ?>" onclick="javascript: vspxPost('action', '_cmd', 'filter');" />
                <img class="pointer" border="0" alt="Cancel Filter" title="Cancel Filter" src="<?V self.image_src ('dav/image/close_16.png') ?>" onclick="javascript: vspxPost('action', '_cmd', 'cancelFilter');" />
              </v:template>
            </div>
          </v:template>

          <!-- Browser -->
          <v:template type="simple" name="Brouse_Body" enabled="-- case when ((((self.command = 0) and (self.command_mode <> 3)) or ((self.command = 0) and (self.command_mode = 3) and (not isnull (self.search_advanced))))) then 1 else 0 end">

            <div id="dav_data" style="width: 100%; margin: 0; padding: 0;">
              <v:data-source name="dsrc_items" expression-type="sql" nrows="0" initial-offset="0">
                <v:before-data-bind>
                  <![CDATA[
                    self.sortChange (get_keyword ('sortColumn', self.vc_page.vc_event.ve_params, ''));
                    control.ds_parameters := null;
                    control.add_parameter(self.dir_path);
                    control.add_parameter(self.command_mode);
                    if (self.command_mode = 1)
                    {
                      control.add_parameter (self.search_filter);
                    }
                    else if (self.command_mode = 2)
                    {
                      control.add_parameter (self.search_simple);
                    }
                    else if (self.command_mode = 3)
                    {
                      control.add_parameter (self.search_advanced);
                    }
                    else
                    {
                      control.add_parameter (null);
                    }
                    control.add_parameter (WEBDAV.DBA.settings_hiddens (self.settings));

                    control.ds_sql := 'select rs.* from WEBDAV.DBA.proc (rs0, rs1, rs2, rs3)(c0 varchar, c1 varchar, c2 integer, c3 varchar, c4 varchar, c5 varchar, c6 varchar, c7 varchar, c8 varchar, c9 varchar, c10 varchar, c11 varchar) rs where rs0 = ? and rs1 = ? and rs2 = ? and rs3 = ?';
                    control.ds_sql := concat(control.ds_sql, ' order by c1');

                    if (self.dir_details = 0)
                    {
                      declare dir_order, dir_grouping any;

                      dir_order := self.getColumn(self.dir_order);
                      dir_grouping := self.getColumn(self.dir_grouping);
                      if (not is_empty_or_null(dir_grouping))
                        control.ds_sql := concat(control.ds_sql, ', ', dir_grouping[1]);
                      if (not is_empty_or_null(dir_order))
                        control.ds_sql := concat(control.ds_sql, ', ', dir_order[1], ' ', self.dir_direction);
                    }
                    else
                    {
                      control.ds_sql := control.ds_sql || ', c0';
                    }
                    self.dir_tags := vector ();
                    if (self.dir_cloud = 1)
                    {
                      declare state, msg, meta, result any;

                      state := '00000';
                      exec(control.ds_sql, state, msg, control.ds_parameters, 0, meta, result);
                      if (state = '00000')
                      {
                        declare I, N, minCnt, maxCnt integer;
                        declare tag_object, tags, tags_dict any;

                        tags_dict := dict_new();
                        for (N := 0; N < length(result); N := N + 1)
                        {
                          tags := WEBDAV.DBA.DAV_PROP_GET(result[N][8], ':virtpublictags', '');
                          tags := split_and_decode (tags, 0, '\0\0,');
                          foreach (any tag in tags) do
                          {
                            tag_object := dict_get(tags_dict, lcase(tag), vector (lcase(tag), 0, ''));
                            tag_object[1] := tag_object[1] + 1;
                            dict_put(tags_dict, lcase(tag), tag_object);
                          }
                          tags := WEBDAV.DBA.DAV_PROP_GET(result[N][8], ':virtprivatetags', '');
                          tags := split_and_decode (tags, 0, '\0\0,');
                          foreach (any tag in tags) do
                          {
                            tag_object := dict_get(tags_dict, lcase(tag), vector (lcase(tag), 0, '#_'));
                            tag_object[1] := tag_object[1] + 1;
                            dict_put(tags_dict, lcase(tag), tag_object);
                          }
                        }
                        maxCnt := 1;
                        minCnt := 1000000;
                        for (select p.* from WEBDAV.DBA.tagsDictionary2rs(p0)(c0 varchar, c1 integer, c2 varchar) p where p0 = tags_dict order by c0) do
                        {
                          self.dir_tags := vector_concat(self.dir_tags, vector (vector (c0, c1, c2)));
                          if (c1 < minCnt)
                            minCnt := c1;
                          if (c1 > maxCnt)
                            maxCnt := c1;
                        }
                        self.dir_tags := vector_concat (vector (vector ('__max', maxCnt)), self.dir_tags);
                        self.dir_tags := vector_concat (vector (vector ('__min', minCnt)), self.dir_tags);
                      }
                    }
                  ]]>
                </v:before-data-bind>
                <v:after-data-bind>
                  <![CDATA[
                    declare row_data any;

                    row_data := control.ds_row_data;
                    if ((length(row_data) = 1) and (row_data[0][1] <> 'R') and (row_data[0][1] <> 'C'))
                    {
                      if (row_data[0][0] = '37000')
                      {
                        self.vc_error_message := 'Text search expression syntax error!';
                      } else {
                        self.vc_error_message := sprintf ('Search error: %s!', row_data[0][0]);
                      }
                      self.vc_is_valid := 0;
                    }
                  ]]>
                </v:after-data-bind>
              </v:data-source>

              <v:template type="simple" enabled="-- case when (self.vc_is_valid and (self.command = 0) and ((self.command_mode = 2) or ((self.command_mode = 3) and not isnull (self.search_advanced)))) then 1 else 0 end;">
                <div class="WEBDAV_formHeader" style="margin-top: 6px;">
                  <i><?V either (equ (self.command_mode, 2), 'Simple', 'Advanced') ?> search found <?V length(self.dsrc_items.ds_row_data) ?> resource(s) in last search</i>
                </div>
              </v:template>

              <table class="box" cellspacing="0">
                <tr>
                  <td width="80%" valign="top" style="border: solid #7F94A5;  border-width: 1px 1px 1px 1px;">
                    <div id="dav_list">
                      <v:data-set name="ds_items" data-source="self.dsrc_items" scrollable="1">
                        <v:after-data-bind>
                          <![CDATA[
                            if (self.vc_is_valid = 0)
                            {
                              control.ds_row_data := vector ();
                              control.ds_rows_fetched := 0;
                              control.ds_rows_total := 0;
                            }
                          ]]>
                        </v:after-data-bind>
                        <v:template name="ds_items_header" type="simple" name-to-remove="table" set-to-remove="bottom">
                          <table id="dir" class="WEBDAV_grid" style="border: 0px;">
                            <thead>
                              <tr>
                                <?vsp
                                  if (self.dir_path <> '')
                                  {
                                    http ('<th class="checkbox">');
                                      http ('<input type="checkbox" name="selectall" value="Select All" onclick="selectAllCheckboxes (this, \'cb_item\', true)" title="Select All" />');
                                    http ('</th>');
                                  }
                                ?>
                                <?vsp self.showColumnHeader('column_#1'); ?>
                                <vm:if test="self.dir_details = 0">
                                  <?vsp self.showColumnHeader('column_#2'); ?>
                                  <?vsp self.showColumnHeader('column_#3'); ?>
                                  <?vsp self.showColumnHeader('column_#10'); ?>
                                  <?vsp self.showColumnHeader('column_#4'); ?>
                                  <?vsp self.showColumnHeader('column_#11'); ?>
                                  <?vsp self.showColumnHeader('column_#5'); ?>
                                  <?vsp self.showColumnHeader('column_#6'); ?>
                                  <?vsp self.showColumnHeader('column_#7'); ?>
                                  <?vsp self.showColumnHeader('column_#8'); ?>
                                  <?vsp self.showColumnHeader('column_#9'); ?>
                                </vm:if>
                                <th class="action">Action</th>
                              </tr>
                            </thead>
                          </table>
                        </v:template>

                        <v:template name="ds_items_repeat" type="repeat">

                          <v:template name="ds_empty" type="if-not-exists" name-to-remove="table" set-to-remove="both">
                            <?vsp
                              if ((self.command = 0) and ((self.command_mode = 2) or (self.command_mode = 3)))
                                http ('<tr align="center"><td colspan="11" valign="middle" height="100px"><b>No resources were found that matched your search.<br />Please refine your search or enter new search criteria.</b></td></tr>');
                            ?>
                          </v:template>

                          <v:template name="ds_items_browse" type="browse" name-to-remove="table" set-to-remove="both">
                            <table>
                              <?vsp
                                declare rowset any;
                                declare path varchar;
                                declare permission varchar;

                                rowset := (control as vspx_row_template).te_rowset;
                                path := rowset[8];
                                permission := WEBDAV.DBA.permission (path);
                              ?>
                              <v:template type="simple" enabled="-- neq (self.dir_grouping, '')">
                                <?vsp
                                  declare tmp, dir_column any;

                                  dir_column := self.getColumn(self.dir_grouping);
                                  tmp := (control.vc_parent as vspx_row_template).te_column_value(dir_column[1]);

                                  if (is_empty_or_null(self.dir_groupName) or (self.dir_groupName <> tmp))
                                  {
                                ?>
                                <tr>
                                  <td colspan="11">
                                    <?vsp http (sprintf ('<b> %s: %s</b>', dir_column[2], cast(tmp as varchar))); ?>
                                  </td>
                                </tr>
                                <?vsp
                                  }
                                  self.dir_groupName := tmp;
                                ?>
                              </v:template>
                              <tr>
                                <?vsp
                                  if (self.dir_path <> '')
                                  {
                                    http (         '<td class="checkbox">');
                                    if ((path not like '%,acl') and (path not like '%,meta'))
                                      http (sprintf ('  <input type="checkbox" name="cb_item" value="%V" onclick="selectCheck (this, \'cb_item\')"/>', WEBDAV.DBA.utf2wide (path)));
                                    http (         '</td>');
                                  }
                                ?>
                                <td nowrap="nowrap">
                                  <?vsp
                                    declare id, click any;

                                    id := case when (rowset[1] = 'R') then sprintf ('id="%V"', path) else '' end;
                                    if ((self.returnName <> '') and (rowset[1] = 'R'))
                                    {
                                      http (sprintf ('<a %s href="%s" onclick="javascript: $(\'item_name\').value = \'%s\'; return false;" title="%s"><img src="%s" border="0" /> %V</a>', id, WEBDAV.DBA.dav_url (path), replace (WEBDAV.DBA.dav_lpath (path), '\'', '\\\''), WEBDAV.DBA.utf2wide (rowset[0]), self.image_src (WEBDAV.DBA.ui_image(path, rowset[1], rowset[4])), WEBDAV.DBA.utf2wide (WEBDAV.DBA.stringCut (rowset[0], self.chars))));
                                    }
                                    else
                                    {
                                      click := case when (permission <> '') then sprintf ('ondblclick="javascript: vspxUpdate(\'%V\');" ', WEBDAV.DBA.utf2wide (replace (path, '\'', '\\\''))) else '' end
                                            || sprintf ('onclick="javascript: vspxSelect(\'%V\'); return false;"', WEBDAV.DBA.utf2wide (replace (WEBDAV.DBA.dav_lpath (path), '\'', '\\\'')));
                                      http (sprintf ('<a %s href="%s" %s title="%V" class="WEBDAV_a"><img src="%s" border="0" /> %V</a>', id, WEBDAV.DBA.utf2wide (WEBDAV.DBA.dav_url (path)), click, WEBDAV.DBA.utf2wide (rowset[0]), self.image_src (WEBDAV.DBA.ui_image (path, rowset[1], rowset[4])), WEBDAV.DBA.utf2wide (WEBDAV.DBA.stringCut (rowset[0], self.chars))));
                                    }
                                  ?>
                                  <v:template type="simple" enabled="-- case when (self.command_mode <> 3 or is_empty_or_null(WEBDAV.DBA.dc_get (self.search_dc, 'base', 'content'))) then 0 else 1 end">
                                    <br /><i><v:label value="--WEBDAV.DBA.content_excerpt((((control.vc_parent).vc_parent as vspx_row_template).te_rowset[8]), WEBDAV.DBA.dc_get(self.search_dc, 'base', 'content'))" format="%s" /></i>
                                  </v:template>
                                </td>
                                <v:template type="simple" enabled="-- self.enabledColumn('column_#2')">
                                  <td nowrap="nowrap">
                                    <?vsp
                                      declare N integer;
                                      declare tags any;

                                      N := 0;
                                      tags := WEBDAV.DBA.DAV_PROP_GET ((control.vc_parent as vspx_row_template).te_rowset[8], ':virtpublictags', '');
                                      if (isstring (tags))
                                      {
                                        tags := split_and_decode (tags, 0, '\0\0,');
                                        foreach (any tag in tags) do
                                        {
                                          N := N + length(tag);
                                          if (N < 20)
                                            http (sprintf ('<a id="public_t_%s" href="#" onclick="javascript: vspxPost(\'action\', \'_cmd\', \'tag_search\', \'tag_hidden\', \'%s\'); return false;" alt="Search Public Tag" title="Search Public Tag">%s</a> ', tag, tag, tag));
                                          N := N + 1;
                                        }
                                      }
                                      tags := WEBDAV.DBA.DAV_PROP_GET((control.vc_parent as vspx_row_template).te_rowset[8], ':virtprivatetags', '');
                                      if (isstring (tags))
                                      {
                                        tags := split_and_decode (tags, 0, '\0\0,');
                                        foreach (any tag in tags) do
                                        {
                                          N := N + length(tag);
                                          if (N < 20)
                                            http (sprintf ('<a id="private_t_%s" href="#" onclick="javascript: vspxPost(\'action\', \'_cmd\', \'tag_search\', \'tag_hidden\', \'#_%s\'); return false;" alt="Search Private Tag" title="Search Private Tag">%s</a> ', tag, tag, tag));
                                          N := N + 1;
                                        }
                                      }
                                    ?>
                                  </td>
                                </v:template>
                                <v:template type="simple" enabled="-- self.enabledColumn('column_#3')">
                                  <td class="number" nowrap="nowrap">
                                    <v:label>
                                      <v:before-data-bind>
                                        <![CDATA[
                                          control.ufl_value := WEBDAV.DBA.ui_size((((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[2], (((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[1]);
                                        ]]>
                                      </v:before-data-bind>
                                    </v:label>
                                  </td>
                                </v:template>
                                <v:template type="simple" enabled="-- self.enabledColumn('column_#10')">
                                  <td nowrap="nowrap">
                                    <v:label value="--left ((((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[10], 10)" format="%s" />
                                    <font size="1">
                                      <v:label value="--right ((((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[10], 8)" />
                                    </font>
                                  </td>
                                </v:template>
                                <v:template type="simple" enabled="-- self.enabledColumn('column_#4')">
                                  <td nowrap="nowrap">
                                    <v:label value="--left ((((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[3], 10)" format="%s" />
                                    <font size="1">
                                      <v:label value="--right ((((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[3], 8)" />
                                    </font>
                                  </td>
                                </v:template>
                                <v:template type="simple" enabled="-- self.enabledColumn('column_#11')">
                                  <td nowrap="nowrap">
                                    <v:label value="--left ((((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[11], 10)" format="%s" />
                                    <font size="1">
                                      <v:label value="--right ((((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[11], 8)" />
                                    </font>
                                  </td>
                                </v:template>
                                <v:template type="simple" enabled="-- self.enabledColumn('column_#5')">
                                  <td nowrap="nowrap">
                                    <v:label value="--either (equ ((((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[1], 'R'), (((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[4], ' ')" />
                                  </td>
                                </v:template>
                                <v:template type="simple" enabled="-- self.enabledColumn('column_#6')">
                                  <td nowrap="nowrap">
                                    <v:label value="--(((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[9]" />
                                  </td>
                                </v:template>
                                <v:template type="simple" enabled="-- self.enabledColumn('column_#7')">
                                  <td nowrap="nowrap">
                                    <v:label value="--(((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[5]" />
                                  </td>
                                </v:template>
                                <v:template type="simple" enabled="-- self.enabledColumn('column_#8')">
                                  <td nowrap="nowrap">
                                    <v:label value="--(((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[6]" />
                                  </td>
                                </v:template>
                                <v:template type="simple" enabled="-- self.enabledColumn('column_#9')">
                                  <td nowrap="nowrap">
                                    <v:label value="--(((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[7]" />
                                  </td>
                                </v:template>
                                <td class="action">
                                  <?vsp
                                    declare id any;

                                    id := DB.DBA.DAV_SEARCH_ID (path, rowset[1]);
                                    if (permission <> '')
                                      http (sprintf( ' <img class="pointer" border="0" alt="Update Properties" title="Update Properties"" src="%s" onclick="javascript: vspxUpdate(\'%V\');" />', self.image_src ('dav/image/dav/item_prop.png'), WEBDAV.DBA.utf2wide (replace (path, '\'', '\\\''))));

                                    if (
                                         (
                                           (__tag (id) <> 193)
                                           or
                                           (cast (id[0] as varchar) in ('Share', 'S3', 'GDrive', 'Dropbox', 'SkyDrive', 'Box', 'WebDAV', 'RACKSPACE'))
                                           or
                                           (rowset[0] like '%,acl')
                                           or
                                           (rowset[0] like '%,meta')
                                         )
                                         and
                                         (
                                           rowset[0] like '%.vsp'
                                           or rowset[0] like '%.vspx'
                                           or rowset[0] like '%.rdf'
                                           or rowset[0] like '%.xml'
                                           or rowset[0] like '%.xsl'
                                           or rowset[0] like '%.js'
                                           or rowset[0] like '%.txt'
                                           or rowset[0] like '%.html'
                                           or rowset[0] like '%.htm'
                                           or rowset[0] like '%.sql'
                                           or rowset[0] like '%.ini'
                                           or rowset[4] like 'text/%'
                                         )
                                         and
                                         not DB.DBA.IS_REDIRECT_REF (path)
                                       )
                                    {
                                      declare S varchar;
                                      if ((rowset[0] like '%,acl') or (rowset[0] like '%,meta') or ((permission = 'R') and (self.mode <> 'webdav')))
                                      {
                                        http (sprintf( ' <img class="pointer" border="0" alt="View Content" title="View Content" src="%s" onclick="javascript: vspxView(\'%V\');" />', self.image_src ('dav/image/docs_16.png'), WEBDAV.DBA.utf2wide (replace (path, '\'', '\\\''))));
                                      }
                                      else if ((permission = 'W') or (self.mode = 'webdav'))
                                      {
                                        http (sprintf( ' <img class="pointer" border="0" alt="Edit Content" title="Edit Content" src="%s" onclick="javascript: vspxEdit(\'%V\');" />', self.image_src ('dav/image/edit_16.png'), WEBDAV.DBA.utf2wide (replace (path, '\'', '\\\''))));
                                      }
                                    }
                                  ?>
                              </td>
                            </tr>
                          </table>
                        </v:template>

                        </v:template>

                        <v:template type="simple" name-to-remove="table" set-to-remove="top">
                          <table>
                          </table>
                        </v:template>

                      </v:data-set>
                      <script>
                        <![CDATA[
                          WEBDAV.enableToolbars (document.forms['F1'], 'cb_item');
                        ]]>
                      </script>
                    </div>
                  </td>

                  <v:template type="simple" name="Brouse_Tags" enabled="-- case when ((self.command = 0) and (self.command_mode = 3) and (self.dir_cloud = 1)) then 1 else 0 end;">
                    <td width="20%" valign="top" style="border: solid #7F94A5;  border-width: 1px 1px 1px 0px;">
                      <div style="margin-left:3px; margin-top:3px; overflow: auto; height: 360px;">
                        <?vsp
                          declare N, tLength, tMax, tMin integer;
                          declare tStyle varchar;

                          tLength := length(self.dir_tags);
                          if (tLength > 2)
                          {
                            tMin := self.dir_tags[0][1];
                            tMax := self.dir_tags[1][1];
                            for (N := 2; N < tLength; N := N + 1)
                            {
                              tStyle := self.tag_style(self.dir_tags[N][1], tMin, tMax, 12, 30);
                              http (sprintf ('<a href="#" onclick="javascript: vspxPost(\'action\', \'_cmd\', \'tag_search\', \'tag_hidden\', \'%s%s\');" name="btn_%s"><span class="nolink_b" style="%s;">%s</span></a> ', self.dir_tags[N][2], self.dir_tags[N][0], self.dir_tags[N][0], tStyle, self.dir_tags[N][0]));
                            }
                          } else {
                            http ('no tags');
                          }
                        ?>
                        &amp;nbsp;
                      </div>
                    </td>
                  </v:template>
                </tr>
              </table>
            </div>
            <v:template type="simple" name="Brouse_Footer" enabled="-- case when (self.returnName <> '') then 1 else 0 end">
              <div style="margin-bottom: 0.5em;">
                <b> Resource Name </b>
                <v:text type="simple" name="item_name" xhtml_id="item_name" value="--WEBDAV.DBA.utf2wide (WEBDAV.DBA.real_path (self.dir_path))" xhtml_size="60" />
                <input type="button" name="b_return" value="Select" onClick="javascript:  WEBDAV.selectRow ('F1')" />
                <v:button name="b_cancel" action="simple" value="Cancel" xhtml_onClick="javascript: if (opener != null) opener.focus(); window.close()"/>
              </div>
            </v:template>
          </v:template>
        </v:template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!--=========================================================================-->
  <xsl:template match="vm:search-dc-template4">
    <div id="4" class="tabContent" style="display: none;">
      <table class="WEBDAV_formBody WEBDAV_noBorder" cellspacing="0">
        <tr>
          <th width="30%">
            <v:label for="dav_oMail_FolderName" value="--'WebMail folder name'" />
          </th>
          <td>
            <v:text name="dav_oMail_FolderName" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_oMail_FolderName', self.dav_path, 'virt:oMail-FolderName', 'NULL');
                  if (control.ufl_value = 'NULL')
                    control.ufl_value := '';
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_oMail_NameFormat" value="--'WebMail name format'" />
          </th>
          <td>
            <v:text name="dav_oMail_NameFormat" format="%s" xhtml_disabled="disabled" xhtml_class="field-text _validate_">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_oMail_NameFormat', self.dav_path, 'virt:oMail-NameFormat', '^from^ ^subject^');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
      </table>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:search-dc-template5">
    <div id="5" class="tabContent" style="display: none;">
      <table class="WEBDAV_formBody WEBDAV_noBorder" cellspacing="0">
        <tr>
          <th>
            <v:label for="dav_PropFilter_SearchPath" value="--'Search path'" />
          </th>
          <td>
            <v:text name="dav_PropFilter_SearchPath" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:validator test="length" min="1" max="255" message="The input can not be empty." runat="client" />
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_PropFilter_SearchPath', self.dav_path, 'virt:PropFilter-SearchPath', WEBDAV.DBA.path_show (self.dir_path));
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_PropFilter_PropName" value="--'Property name'" />
          </th>
          <td>
            <v:text name="dav_PropFilter_PropName" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:validator test="length" min="1" max="255" message="The input can not be empty." runat="client" />
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_PropFilter_PropName', self.dav_path, 'virt:PropFilter-PropName', '');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_PropFilter_PropValue" value="--'Property value'" />
          </th>
          <td>
            <v:text name="dav_PropFilter_PropValue" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_PropFilter_PropValue', self.dav_path, 'virt:PropFilter-PropValue', '');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
      </table>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:search-dc-template6">
    <div id="6" class="tabContent" style="display: none;">
      <table class="WEBDAV_formBody WEBDAV_noBorder" cellspacing="0">
        <tr>
          <th width="30%">
            <v:label for="dav_S3_activity" value="--'Activity manager (on/off)'" />
          </th>
          <td>
            <?vsp
              declare S varchar;

              S := self.get_fieldProperty ('dav_S3_activity', self.dav_path, 'virt:S3-activity', 'off');
              http (sprintf ('<input type="checkbox" name="dav_S3_activity" id="dav_S3_activity" %s disabled="disabled" value="on" />', case when S = 'on' then 'checked="checked"' else '' end));
            ?>
          </td>
        </tr>
        <tr>
          <th>
            <vm:label for="dav_S3_checkInterval" value="Check for updates every" />
          </th>
          <td>
            <v:text name="dav_S3_checkInterval" xhtml_id="dav_S3_checkInterval" format="%s" xhtml_disabled="disabled" xhtml_size="3">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_S3_checkInterval', self.dav_path, 'virt:S3-checkInterval', '15');
                ]]>
              </v:before-data-bind>
            </v:text> minutes
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_S3_BucketName" value="Bucket Name" />
          </th>
          <td>
            <v:text name="dav_S3_BucketName" xhtml_id="dav_S3_BucketName" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_S3_BucketName', self.dav_path, 'virt:S3-BucketName', '');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr id="tr_dav_S3_path">
          <th>Root Path</th>
          <td id="td_dav_S3_path">
            <v:text name="dav_S3_path" xhtml_id="dav_S3_path" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_S3_path', self.dav_path, 'virt:S3-path', '/');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_S3_AccessKey" value="Access Key ID (*)" />
          </th>
          <td>
            <v:text name="dav_S3_AccessKeyID" xhtml_id="dav_S3_AccessKeyID" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_S3_AccessKeyID', self.dav_path, 'virt:S3-AccessKeyID', '');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_S3_SecretKey" value="Secret Key (*)" />
          </th>
          <td>
            <v:text name="dav_S3_SecretKey" xhtml_id="dav_S3_SecretKey" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_S3_SecretKey', self.dav_path, 'virt:S3-SecretKey', '');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_S3_graph" value="--'Graph name'" />
          </th>
          <td>
            <v:text name="dav_S3_graph" xhtml_id="dav_S3_graph" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.detGraphUI ('S3');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <?vsp
          self.detSpongerUI ('S3', 6);
        ?>
      </table>
      <![CDATA[
        <script type="text/javascript">
          OAT.MSG.attach(OAT, "PAGE_LOADED", function(){destinationChange($('dav_S3_sponger'), {checked: {show: ['dav6_cartridge', 'dav6_metaCartridge']}})});
        </script>
      ]]>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:search-dc-template7">
    <div id="7" class="tabContent" style="display: none;">
      <table class="WEBDAV_formBody WEBDAV_noBorder" cellspacing="0">
        <tr>
          <th width="30%">
            <v:label for="ts_path" value="--'Search path'" />
          </th>
          <td>
            <?vsp http (sprintf ('<input type="text" name="ts_path" value="%V" disabled="disabled" class="field-text" />', WEBDAV.DBA.dc_get(self.search_dc, 'base', 'path', WEBDAV.DBA.path_show(self.dir_path)))); ?>
          </td>
        </tr>
      </table>
      <br />
      <table style="width: 100%;">
        <tr>
          <td width="100%">
            <table id="srt_tbl" class="WEBDAV_formList" style="width: 100%;" cellspacing="0">
              <thead>
                <tr>
                  <th               width="20%">Field</th>
                  <th id="srt_th_2" width="20%" style="display: none;">Schema</th>
                  <th id="srt_th_3" width="20%" style="display: none;">Property</th>
                  <th               width="20%">Condition</th>
                  <th               width="20%">Value</th>
                  <th               width="1%" nowrap="nowrap">Action</th>
                </tr>
              </thead>
              <tbody id="srt_tbody">
                <![CDATA[
                  <script type="text/javascript">
                    OAT.MSG.attach(OAT, "PAGE_LOADED", TBL.searchFilter);
                  <?vsp
                    declare I, N integer;
                    declare aCriteria, criteria any;
                    declare V, f1, f2, f3, f4, f5 any;

                    aCriteria := WEBDAV.DBA.dc_xml_doc (self.search_dc);
                    I := xpath_eval('count(/dc/criteria/entry)', aCriteria);
                    for (N := 1; N <= I; N := N + 1)
                    {
                      criteria := xpath_eval('/dc/criteria/entry', aCriteria, N);
                      f1 := cast (xpath_eval ('@field', criteria) as varchar);
                      f2 := cast (xpath_eval ('@schema', criteria) as varchar);
                      f3 := cast (xpath_eval ('@property', criteria) as varchar);
                      f4 := cast (xpath_eval ('@criteria', criteria) as varchar);
                      f5 := cast (xpath_eval ('.', criteria) as varchar);

                      http (sprintf ('OAT.MSG.attach(OAT, "PAGE_LOADED", function(){TBL.createRow("srt", null, {fld_1: {mode: 61, value: %s, cssText: "width: 95%%;"}, fld_2: {mode: 62, value: %s, cssText: "width: 95%%;"}, fld_3: {mode: 63, value: %s, cssText: "width: 95%%;"}, fld_4: {mode: 64, value: %s, cssText: "width: 95%%;"}, fld_5: {mode: 65, value: %s, cssText: "width: 95%%;"}, btn_1: {mode: 61}});});', self.dc_varchar (f1), self.dc_varchar (f2), self.dc_varchar (f3), self.dc_varchar (f4), self.dc_varchar (f5)));
                    }
                  ?>
                  </script>
                ]]>
                <tr id="srt_tr_no"><td colspan="6"><b>No Criteria</b></td></tr>
              </tbody>
            </table>
          </td>
          <td valign="top" nowrap="nowrap">
            <span class="button pointer">
              <xsl:attribute name="onclick">javascript: TBL.createRow('srt', null, {fld_1: {mode: 61, cssText: 'width: 95%;'}, fld_2: {mode: 62, cssText: 'width: 95%;'}, fld_3: {mode: 63, cssText: 'width: 95%;'}, fld_4: {mode: 64, cssText: 'width: 95%;'}, fld_5: {mode: 65, cssText: 'width: 95%;'}, btn_1: {mode: 61}});</xsl:attribute>
            <img src="<?V self.image_src ('dav/image/add_16.png') ?>" border="0" class="button" alt="Add Security" title="Add Security" /> Add</span><br /><br />
          </td>
        </tr>
      </table>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:search-dc-template8">
    <div id="8" class="tabContent" style="display: none;">
      <table class="WEBDAV_formBody WEBDAV_noBorder" cellspacing="0">
        <tr>
          <th width="30%">
            <v:label for="dav_rdfSink_graph" value="--'Graph name'" />
          </th>
          <td>
            <v:text name="dav_rdfSink_graph" xhtml_id="dav_rdfSink_graph" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.detGraphUI ('rdfSink');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th width="30%">
            <v:label for="dav_rdfSink_base" value="--'Base URI'" />
          </th>
          <td>
            <v:text name="dav_rdfSink_base" xhtml_id="dav_rdfSink_base" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_rdfSink_base', self.dav_path, 'virt:rdfSink-base', '');
                  if ((control.ufl_value = '') and (self.command = 10))
                    control.ufl_value := WEBDAV.DBA.host_url () || WEBDAV.DBA.path_escape (WS.WS.FIXPATH (WEBDAV.DBA.real_path (self.dav_path)));
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <?vsp
          self.detSpongerUI ('rdfSink', 8);
        ?>
      </table>
      <![CDATA[
        <script type="text/javascript">
          OAT.MSG.attach(OAT, "PAGE_LOADED", function(){destinationChange($('dav_rdfSink_sponger'), {checked: {show: ['dav8_cartridge', 'dav8_metaCartridge']}})});
        </script>
      ]]>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:search-dc-template9">
    <div id="9" class="tabContent" style="display: none;">
      <table class="WEBDAV_formBody WEBDAV_noBorder" cellspacing="0">
        <tr>
          <th >
            <v:label value="File State" />
          </th>
          <td>
            <?vsp
              http (sprintf ('Lock is <b>%s</b>, ', WEBDAV.DBA.DAV_GET_INFO (self.dav_path, 'lockState')));
              http (sprintf ('Version Control is <b>%s</b>, ', WEBDAV.DBA.DAV_GET_INFO (self.dav_path, 'vc')));
              http (sprintf ('Auto Versioning is <b>%s</b>, ', WEBDAV.DBA.DAV_GET_INFO (self.dav_path, 'avcState')));
              http (sprintf ('Version State is <b>%s</b>', WEBDAV.DBA.DAV_GET_INFO (self.dav_path, 'vcState')));
            ?>
          </td>
        </tr>
        <v:template name="t3" type="simple" enabled="-- case when (equ(self.command_mode, 10)) then 1 else 0 end">
          <tr>
            <th>
              <v:label value="--sprintf ('Content is %s in Version Control', either(equ(WEBDAV.DBA.DAV_GET (self.dav_item, 'versionControl'),1), '', 'not'))" format="%s" />
            </th>
            <td>
              <v:button name="template_vc" action="simple" value="--sprintf ('%s VC', either(equ(WEBDAV.DBA.DAV_GET (self.dav_item, 'versionControl'),1), 'Disable', 'Enable'))" xhtml_class="button">
                <v:before-render>
                  <![CDATA[
                    if (not self.dav_enable_versioning)
                      control.vc_add_attribute ('disabled', 'disabled');
                  ]]>
                </v:before-render>
                <v:on-post>
                  <![CDATA[
                    declare retValue any;

                    if (WEBDAV.DBA.DAV_GET (self.dav_item, 'versionControl'))
                    {
                      retValue := WEBDAV.DBA.DAV_REMOVE_VERSION_CONTROL (self.dav_path);
                    } else {
                      retValue := WEBDAV.DBA.DAV_VERSION_CONTROL (self.dav_path);
                    }

                    if (WEBDAV.DBA.DAV_ERROR(retValue))
                    {
                      self.vc_error_message := WEBDAV.DBA.DAV_PERROR (retValue);
                      self.vc_is_valid := 0;
                      return;
                    }
                    self.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
            </td>
          </tr>
        </v:template>
        <vm:autoVersion />
        <v:template name="t4" type="simple" enabled="-- case when (equ(WEBDAV.DBA.DAV_GET (self.dav_item, 'versionControl'),1)) then 1 else 0 end">
          <tr>
            <th>
              File commands
            </th>
            <td>
              <v:button name="tepmpate_lock" action="simple" value="Lock" enabled="-- case when (WEBDAV.DBA.DAV_IS_LOCKED (self.dav_path)) then 0 else 1 end" xhtml_class="button">
                <v:before-render>
                  <![CDATA[
                    if (not self.dav_enable_versioning)
                      control.vc_add_attribute ('disabled', 'disabled');
                  ]]>
                </v:before-render>
                <v:on-post>
                  <![CDATA[
                    declare retValue any;

                    retValue := WEBDAV.DBA.DAV_LOCK (self.dav_path);
                    if (WEBDAV.DBA.DAV_ERROR(retValue))
                    {
                      self.vc_error_message := WEBDAV.DBA.DAV_PERROR (retValue);
                      self.vc_is_valid := 0;
                      return;
                    }
                    self.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
              <v:button name="tepmpate_unlock" action="simple" value="Unlock" enabled="-- case when (WEBDAV.DBA.DAV_IS_LOCKED (self.dav_path)) then 1 else 0 end" xhtml_class="button">
                <v:before-render>
                  <![CDATA[
                    if (not self.dav_enable_versioning)
                      control.vc_add_attribute ('disabled', 'disabled');
                  ]]>
                </v:before-render>
                <v:on-post>
                  <![CDATA[
                    declare retValue any;

                    retValue := WEBDAV.DBA.DAV_UNLOCK (self.dav_path);
                    if (WEBDAV.DBA.DAV_ERROR(retValue))
                    {
                      self.vc_error_message := WEBDAV.DBA.DAV_PERROR(retValue);
                      self.vc_is_valid := 0;
                      return;
                    }
                    self.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
            </td>
          </tr>
          <tr>
            <th>
              Versioning commands
            </th>
            <td>
              <v:button name="tepmpate_checkIn" action="simple" value="Check-In" enabled="-- case when (is_empty_or_null (WEBDAV.DBA.DAV_GET (self.dav_item, 'checked-in'))) then 1 else 0 end" xhtml_class="button">
                <v:before-render>
                  <![CDATA[
                    if (not self.dav_enable_versioning)
                      control.vc_add_attribute ('disabled', 'disabled');
                  ]]>
                </v:before-render>
                <v:on-post>
                  <![CDATA[
                    declare retValue any;

                    retValue := WEBDAV.DBA.DAV_CHECKIN (self.dav_path);
                    if (WEBDAV.DBA.DAV_ERROR (retValue))
                    {
                      self.vc_error_message := WEBDAV.DBA.DAV_PERROR (retValue);
                      self.vc_is_valid := 0;
                      return;
                    }
                    self.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
              <v:button name="tepmpate_checkOut" action="simple" value="Check-Out" enabled="-- case when (is_empty_or_null(WEBDAV.DBA.DAV_GET (self.dav_item, 'checked-out'))) then 1 else 0 end" xhtml_class="button">
                <v:before-render>
                  <![CDATA[
                    if (not self.dav_enable_versioning)
                      control.vc_add_attribute ('disabled', 'disabled');
                  ]]>
                </v:before-render>
                <v:on-post>
                  <![CDATA[
                    declare retValue any;

                    retValue := WEBDAV.DBA.DAV_CHECKOUT (self.dav_path);
                    if (WEBDAV.DBA.DAV_ERROR(retValue))
                    {
                      self.vc_error_message := WEBDAV.DBA.DAV_PERROR(retValue);
                      self.vc_is_valid := 0;
                      return;
                    }
                    self.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
              <v:button name="tepmpate_uncheckOut" action="simple" value="Uncheck-Out" enabled="-- case when (is_empty_or_null(WEBDAV.DBA.DAV_GET (self.dav_item, 'checked-in'))) then 1 else 0 end" xhtml_class="button">
                <v:before-render>
                  <![CDATA[
                    if (not self.dav_enable_versioning)
                      control.vc_add_attribute ('disabled', 'disabled');
                  ]]>
                </v:before-render>
                <v:on-post>
                  <![CDATA[
                    declare retValue any;

                    retValue := WEBDAV.DBA.DAV_UNCHECKOUT (self.dav_path);
                    if (WEBDAV.DBA.DAV_ERROR(retValue))
                    {
                      self.vc_error_message := WEBDAV.DBA.DAV_PERROR(retValue);
                      self.vc_is_valid := 0;
                      return;
                    }
                    self.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
            </td>
          </tr>
          <tr>
            <th>
              Number of Versions in History
            </th>
            <td>
              <v:label value="--WEBDAV.DBA.DAV_GET_VERSION_COUNT (self.dav_path)" format="%d" />
            </td>
          </tr>
          <tr>
            <th>
              Root version
            </th>
            <td>
              <v:button style="url" action="simple" value="--WEBDAV.DBA.DAV_GET_VERSION_ROOT (self.dav_path)" format="%s" xhtml_disabled="disabled">
                <v:on-post>
                  <![CDATA[
                    declare path varchar;

                    path := WEBDAV.DBA.DAV_GET_VERSION_ROOT (self.dav_path);
                    if (WEBDAV.DBA.permission(path) = '')
                    {
                      self.vc_error_message := 'You have not rights to read this folder/file!';
                      self.vc_is_valid := 0;
                      self.vc_data_bind (e);
                      return;
                    }

                    http_request_status ('HTTP/1.1 302 Found');
                    http_header (sprintf ('Location: view.vsp?sid=%s&realm=%s&file=%U&mode=download\r\n', self.sid , self.realm, path));
                    self.vc_data_bind (e);
                  ]]>
                </v:on-post>
              </v:button>
            </td>
          </tr>
          <tr>
            <th valign="top">Versions</th>
            <td>
              <v:data-set name="ds_versions" sql="select rs.* from WEBDAV.DBA.DAV_GET_VERSION_SET(rs0)(c0 varchar, c1 integer) rs where rs0 = :p0" nrows="0" scrollable="1">
                <v:param name="p0" value="--WEBDAV.DBA.DAV_GET (self.dav_item, 'fullPath')" />

                <v:template name="ds_versions_header" type="simple" name-to-remove="table" set-to-remove="bottom">
                  <table class="WEBDAV_formList" style="width: auto;" id="versions" cellspacing="0">
                    <tr>
                      <th>Path</th>
                      <th>Number</th>
                      <th>Size</th>
                      <th>Modified</th>
                      <th>Action</th>
                    </tr>
                  </table>
                </v:template>

                <v:template name="ds_versions_repeat" type="repeat">

                  <v:template name="ds_versions_empty" type="if-not-exists" name-to-remove="table" set-to-remove="both">
                    <table>
                      <tr align="center">
                        <td colspan="5">No versions</td>
                      </tr>
                    </table>
                  </v:template>

                  <v:template name="ds_versions_browse" type="browse" name-to-remove="table" set-to-remove="both">
                    <table>
                      <tr>
                        <td nowrap="nowrap">
                          <v:button name="button_versions_show" style="url" action="simple" value="--(control.vc_parent as vspx_row_template).te_column_value('c0')" format="%s" xhtml_disabled="disabled">
                            <v:on-post>
                              <![CDATA[
                                declare path varchar;

                                path := (control.vc_parent as vspx_row_template).te_column_value('c0');
                                if (WEBDAV.DBA.permission(path) = '')
                                {
                                  self.vc_error_message := 'You have not rights to read this folder/file!';
                                  self.vc_is_valid := 0;
                                  self.vc_data_bind (e);
                                  return;
                                }

                                http_request_status ('HTTP/1.1 302 Found');
                                http_header (sprintf ('Location: %s&mode=download&file=%U\r\n', WEBDAV.DBA.url_fix ('view.vsp', self.sid , self.realm), path));
                                self.vc_data_bind (e);
                              ]]>
                            </v:on-post>
                          </v:button>
                        </td>
                        <td nowrap="nowrap" align="right">
                          <v:label value="--WEBDAV.DBA.path_name((control.vc_parent as vspx_row_template).te_column_value('c0'))" />
                        </td>
                        <td nowrap="nowrap" align="right">
                          <v:label>
                            <v:after-data-bind>
                              <![CDATA[
                                control.ufl_value := WEBDAV.DBA.ui_size(WEBDAV.DBA.DAV_PROP_GET((control.vc_parent as vspx_row_template).te_column_value('c0'), ':getcontentlength'), 'R');
                              ]]>
                            </v:after-data-bind>
                          </v:label>
                        </td>
                        <td nowrap="nowrap" align="right">
                          <v:label>
                            <v:after-data-bind>
                              <![CDATA[
                                control.ufl_value := WEBDAV.DBA.ui_date(WEBDAV.DBA.DAV_PROP_GET((control.vc_parent as vspx_row_template).te_column_value('c0'), ':getlastmodified'));
                              ]]>
                            </v:after-data-bind>
                          </v:label>
                        </td>
                        <td nowrap="nowrap">
                          <v:button name="button_versions_delete" action="simple" style="url" value="Version Delete" enabled="--(control.vc_parent as vspx_row_template).te_column_value('c1')" xhtml_disabled="disabled">
                            <v:after-data-bind>
                              <![CDATA[
                                control.ufl_value := '<img src="dav/image/trash_16.png" border="0" alt="Version Delete" title="Version Delete" onclick="javascript: if (!confirm(\'Are you sure you want to delete the chosen version and all previous versions?\')) { event.cancelBubble = true;};" />';
                              ]]>
                            </v:after-data-bind>
                            <v:on-post>
                              <![CDATA[
                                declare retValue any;

                                retValue := WEBDAV.DBA.DAV_DELETE((control.vc_parent as vspx_row_template).te_column_value('c0'));
                                if (WEBDAV.DBA.DAV_ERROR(retValue))
                                {
                                  self.vc_error_message := WEBDAV.DBA.DAV_PERROR(retValue);
                                  self.vc_is_valid := 0;
                                  return;
                                }
                                self.vc_data_bind (e);
                              ]]>
                            </v:on-post>
                          </v:button>
                        </td>
                      </tr>
                    </table>
                  </v:template>

                </v:template>

                <v:template name="ds_versions_footer" type="simple" name-to-remove="table" set-to-remove="top">
                  <table>
                  </table>
                </v:template>

              </v:data-set>
            </td>
          </tr>
        </v:template>
      </table>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:search-dc-template10">
    <div id="10" class="tabContent" style="display: none;">
      <table class="WEBDAV_formBody WEBDAV_noBorder" cellspacing="0">
        <tr>
          <th>
            <v:label for="ts_max" value="Max Results" />
          </th>
          <td>
            <?vsp http (sprintf ('<input type="text" name="ts_max" value="%s" size="5" />', WEBDAV.DBA.dc_get (self.search_dc, 'options', 'max', '100'))); ?>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="ts_order" value="Order by" />
          </th>
          <td>
            <select name="ts_order">
              <?vsp
                declare N integer;

                for (N := 0; N < length(self.dir_columns); N := N + 1)
                  if (self.dir_columns[N][3] = 1)
                    http (self.option_prepare(self.dir_columns[N][0], self.dir_columns[N][2], self.dir_order));
              ?>
            </select>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="ts_direction" value="Direction" />
          </th>
          <td>
            <select name="ts_direction">
              <?vsp
                http (self.option_prepare('asc',  'Asc',  self.dir_direction));
                http (self.option_prepare('desc', 'Desc', self.dir_direction));
              ?>
            </select>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="ts_grouping" value="Group by" />
          </th>
          <td>
            <select name="ts_grouping">
              <?vsp
                declare N integer;

                http (self.option_prepare('', '', self.dir_grouping));
                for (N := 0; N < length(self.dir_columns); N := N + 1)
                  if (self.dir_columns[N][4] = 1)
                    http (self.option_prepare(self.dir_columns[N][0], self.dir_columns[N][2], self.dir_grouping));
              ?>
            </select>
          </td>
        </tr>
        <tr>
          <th/>
          <td>
            <v:check-box name="ts_cloud" xhtml_id="ts_cloud" value="1" />
            <vm:label for="ts_cloud" value="Show tag cloud" />
          </td>
        </tr>
      </table>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:search-dc-template11">
    <div id="10" class="tabContent" style="display: none;">
      <table class="WEBDAV_formBody WEBDAV_noBorder" cellspacing="0">
        <tr>
          <th width="30%">SyncML version</th>
          <td>
            <select name="syncml_version">
              <?vsp
                declare aValues, aValue any;
                declare N integer;

                aValue := case when (self.command_mode = 0) then 'N' else WEBDAV.DBA.syncml_version (self.dav_path) end;
                aValues := WEBDAV.DBA.syncml_versions ();
                for (N := 2; N < length (aValues); N := N + 2)
                {
                  http(sprintf('<option value="%s" %s>%s</option>', aValues[N], select_if(aValue, aValues[N]), aValues[N+1]));
                }
              ?>
            </select>
          </td>
        </tr>
        <tr>
          <th>SyncML type</th>
          <td>
            <select name="syncml_type">
              <?vsp
                declare aValues, aValue any;
                declare N integer;

                aValue := case when (self.command_mode = 0) then 'N' else WEBDAV.DBA.syncml_type (self.dav_path) end;
                aValues := WEBDAV.DBA.syncml_types ();
                for (N := 2; N < length (aValues); N := N + 2)
                {
                  http(sprintf('<option value="%s" %s>%s</option>', aValues[N], select_if (aValue, aValues[N]), aValues[N+1]));
                }
              ?>
            </select>
          </td>
        </tr>
      </table>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:search-dc-template12">
    <div id="11" class="tabContent" style="display: none;">
      <table class="WEBDAV_formBody WEBDAV_noBorder" cellspacing="0">
        <tr id="tr_ssl" style="display: none;">
          <th style="text-align: center; font-size: 1.2em; background-color: #EAEAEE; color: red;" colspan="2">
            Use SSL connection to secure your personal data
          </th>
        </tr>
        <tr>
          <th width="30%">
            <v:label for="dav_IMAP_activity" value="--'Activity manager (on/off)'" />
          </th>
          <td>
            <?vsp
              declare S varchar;

              S := self.get_fieldProperty ('dav_IMAP_activity', self.dav_path, 'virt:IMAP-activity', 'off');
              http (sprintf ('<input type="checkbox" name="dav_IMAP_activity" id="dav_IMAP_activity" %s disabled="disabled" value="on" />', case when S = 'on' then 'checked="checked"' else '' end));
            ?>
          </td>
        </tr>
        <tr>
          <th>
            <vm:label for="dav_IMAP_checkInterval" value="Check for updates every" />
          </th>
          <td>
            <v:text name="dav_IMAP_checkInterval" xhtml_id="dav_IMAP_checkInterval" format="%s" xhtml_disabled="disabled" xhtml_size="3">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_IMAP_checkInterval', self.dav_path, 'virt:IMAP-checkInterval', '15');
                ]]>
              </v:before-data-bind>
            </v:text> minutes
          </td>
        </tr>
        <tr>
          <th>
            <vm:label for="dav_IMAP_connection" value="Connection Type" />
          </th>
          <td>
            <select name="dav_IMAP_connection" id="dav_IMAP_connection" onblur="javascript: WEBDAV.loadIMAPFolders();" onchange="javascript: $('dav_IMAP_port').value = (this.value == 'ssl')? '993': '143';">
              <?vsp
                declare aValues, aValue any;
                declare N integer;

                aValue := self.get_fieldProperty ('dav_IMAP_connection', self.dav_path, 'virt:IMAP-connection', '');
                aValues := vector ('none', 'None', 'ssl', 'SSL/TLS');
                for (N := 0; N < length (aValues); N := N + 2)
                  http (sprintf ('<option value="%s" %s>%s</option>', aValues[N], select_if(aValue, aValues[N]), aValues[N+1]));
              ?>
            </select>
          </td>
        </tr>
        <tr>
          <th>
            <vm:label for="dav_IMAP_server" value="Server Address" />
          </th>
          <td>
            <v:text name="dav_IMAP_server" xhtml_id="dav_IMAP_server" format="%s" xhtml_disabled="disabled" xhtml_class="field-text" xhtml_onblur="javascript: WEBDAV.loadIMAPFolders();" >
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_IMAP_server', self.dav_path, 'virt:IMAP-server', '');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <vm:label for="dav_IMAP_port" value="Server Port" />
          </th>
          <td>
            <v:text name="dav_IMAP_port" xhtml_id="dav_IMAP_port" format="%s" xhtml_disabled="disabled" xhtml_class="field-short" xhtml_onblur="javascript: WEBDAV.loadIMAPFolders();">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_IMAP_port', self.dav_path, 'virt:IMAP-port', '143');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <vm:label for="dav_IMAP_user" value="User Name" />
          </th>
          <td>
            <v:text name="dav_IMAP_user" xhtml_id="dav_IMAP_user" format="%s" xhtml_disabled="disabled" xhtml_class="field-short" xhtml_onblur="javascript: WEBDAV.loadIMAPFolders();">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_IMAP_user', self.dav_path, 'virt:IMAP-user', '');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <vm:label for="dav_IMAP_password" value="User Password" />
          </th>
          <td>
            <v:text type="password" name="dav_IMAP_password" xhtml_id="dav_IMAP_password" format="%s" xhtml_disabled="disabled" xhtml_class="field-short" xhtml_onblur="javascript: WEBDAV.loadIMAPFolders();">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := '**********';
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <vm:label for="dav_IMAP_folder" value="Folder Path" />
          </th>
          <td id="td_dav_IMAP_folder">
            <script type="text/javascript">
              <![CDATA[
                function dav_IMAP_folderInit ()
                {
                  var fld = new OAT.Combolist([], "<?V self.get_fieldProperty ('dav_IMAP_folder', self.dav_path, 'virt:IMAP-folder', '') ?>");
                  fld.input.name = 'dav_IMAP_folder';
                  fld.input.id = 'dav_IMAP_folder';
                  fld.input.className = 'field-short';
                  fld.input.comboList = fld;
                  fld.list.style.width = '250px';
                  $("td_dav_IMAP_folder").appendChild(fld.div);
                  WEBDAV.loadIMAPFolders();
                }
                OAT.Loader.load(["ajax", "json", "drag", "combolist"], dav_IMAP_folderInit);
              ]]>
            </script>
          </td>
        </tr>
        <tr>
          <th>
            <vm:label for="dav_IMAP_graph" value="--'Graph name'" />
          </th>
          <td>
            <v:text name="dav_IMAP_graph" xhtml_id="dav_IMAP_graph" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.detGraphUI ('IMAP');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <?vsp
          self.detSpongerUI ('IMAP', 11);
        ?>
      </table>
      <![CDATA[
        <script type="text/javascript">
          if (document.location.protocol != 'https:')
            OAT.Dom.show('tr_ssl');

          OAT.MSG.attach(OAT, "PAGE_LOADED", function(){destinationChange($('dav_IMAP_sponger'), {checked: {show: ['dav11_cartridge', 'dav11_metaCartridge']}})});
        </script>
      ]]>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:search-dc-template13">
    <div id="12" class="tabContent" style="display: none;">
      <?vsp
        declare _value any;

        _value := WEBDAV.DBA.DAV_PROP_GET (self.dav_path, 'virt:GDrive-Authentication', 'No');
      ?>
      <table class="WEBDAV_formBody WEBDAV_noBorder" cellspacing="0">
        <tr>
          <th width="30%">
            <v:label for="dav_GDrive_activity" value="--'Activity manager (on/off)'" />
          </th>
          <td>
            <?vsp
              declare S varchar;

              S := self.get_fieldProperty ('dav_GDrive_activity', self.dav_path, 'virt:GDrive-activity', 'off');
              http (sprintf ('<input type="checkbox" name="dav_GDrive_activity" id="dav_GDrive_activity" %s disabled="disabled" value="on" />', case when S = 'on' then 'checked="checked"' else '' end));
            ?>
          </td>
        </tr>
        <tr>
          <th>
            <vm:label for="dav_GDrive_checkInterval" value="Check for updates every" />
          </th>
          <td>
            <v:text name="dav_GDrive_checkInterval" xhtml_id="dav_GDrive_checkInterval" format="%s" xhtml_disabled="disabled" xhtml_size="3">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_GDrive_checkInterval', self.dav_path, 'virt:GDrive-checkInterval', '15');
                ]]>
              </v:before-data-bind>
            </v:text> minutes
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_GDrive_graph" value="--'Graph name'" />
          </th>
          <td>
            <v:text name="dav_GDrive_graph" xhtml_id="dav_GDrive_graph" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.detGraphUI ('GDrive');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <?vsp
          self.detSpongerUI ('GDrive', 12);
        ?>
        <tr id="tr_dav_GDrive_display_name" style="display: <?V case when _value = 'Yes' then '' else 'none' end ?>">
          <th>User name</th>
          <td id="td_dav_GDrive_display_name">
            <?vsp
              http (WEBDAV.DBA.DAV_PROP_GET (self.dav_path, 'virt:GDrive-display_name', ''));
            ?>
          </td>
        </tr>
        <tr id="tr_dav_GDrive_email" style="display: <?V case when _value = 'Yes' then '' else 'none' end ?>">
          <th>User email</th>
          <td id="td_dav_GDrive_email">
            <?vsp
              http (WEBDAV.DBA.DAV_PROP_GET (self.dav_path, 'virt:GDrive-email', ''));
            ?>
          </td>
        </tr>
        <tr>
          <th></th>
          <td>
            <?vsp
              declare _name, _url any;

              _name := case when (_value = 'Yes') then 'Re-Authenticate' else 'Authenticate' end;
              _url := '/ods/access_service.vsp?m=webdav&p=GDrive&service=google';
              http (sprintf ('<input type="button" id="dav_GDrive_authenticate" value="%s" onclick="javascript: windowShowInternal(\'%s\');" disabled="disabled" class="button" />', _name, _url));
            ?>
          </td>
        </tr>
        <tr id="tr_dav_GDrive_path" style="display: <?V case when _value = 'Yes' then '' else 'none' end ?>">
          <th>Root Path</th>
          <td id="td_dav_GDrive_path">
            <v:text name="dav_GDrive_path" xhtml_id="dav_GDrive_path" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_GDrive_path', self.dav_path, 'virt:GDrive-path', '/');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
      </table>
      <![CDATA[
        <script type="text/javascript">
          OAT.MSG.attach(OAT, "PAGE_LOADED", function(){destinationChange($('dav_GDrive_sponger'), {checked: {show: ['dav12_cartridge', 'dav12_metaCartridge']}})});
        </script>
      ]]>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:search-dc-template14">
    <div id="13" class="tabContent" style="display: none;">
      <?vsp
        declare _value any;

        _value := WEBDAV.DBA.DAV_PROP_GET (self.dav_path, 'virt:Dropbox-Authentication', 'No');
      ?>
      <table class="WEBDAV_formBody WEBDAV_noBorder" cellspacing="0">
        <tr>
          <th width="30%">
            <v:label for="dav_Dropbox_activity" value="--'Activity manager (on/off)'" />
          </th>
          <td>
            <?vsp
              declare S varchar;

              S := self.get_fieldProperty ('dav_Dropbox_activity', self.dav_path, 'virt:Dropbox-activity', 'off');
              http (sprintf ('<input type="checkbox" name="dav_Dropbox_activity" id="dav_Dropbox_activity" %s disabled="disabled" value="on" />', case when S = 'on' then 'checked="checked"' else '' end));
            ?>
          </td>
        </tr>
        <tr>
          <th>
            <vm:label for="dav_Dropbox_checkInterval" value="Check for updates every" />
          </th>
          <td>
            <v:text name="dav_Dropbox_checkInterval" xhtml_id="dav_Dropbox_checkInterval" format="%s" xhtml_disabled="disabled" xhtml_size="3">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_Dropbox_checkInterval', self.dav_path, 'virt:Dropbox-checkInterval', '15');
                ]]>
              </v:before-data-bind>
            </v:text> minutes
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_Dropbox_graph" value="--'Graph name'" />
          </th>
          <td>
            <v:text name="dav_Dropbox_graph" xhtml_id="dav_Dropbox_graph" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.detGraphUI ('Dropbox');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <?vsp
          self.detSpongerUI ('Dropbox', 13);
        ?>
        <tr id="tr_dav_Dropbox_display_name" style="display: <?V case when _value = 'Yes' then '' else 'none' end ?>">
          <th>User name</th>
          <td id="td_dav_Dropbox_display_name">
            <?vsp
              http (WEBDAV.DBA.DAV_PROP_GET (self.dav_path, 'virt:Dropbox-display_name', ''));
            ?>
          </td>
        </tr>
        <tr id="tr_dav_Dropbox_email" style="display: <?V case when _value = 'Yes' then '' else 'none' end ?>">
          <th>User email</th>
          <td id="td_dav_Dropbox_email">
            <?vsp
              http (WEBDAV.DBA.DAV_PROP_GET (self.dav_path, 'virt:Dropbox-email', ''));
            ?>
          </td>
        </tr>
        <tr>
          <th></th>
          <td>
            <?vsp
              declare _name, _url any;

              _name := case when (_value = 'Yes') then 'Re-Authenticate' else 'Authenticate' end;
              _url := '/ods/access_service.vsp?m=webdav&p=Dropbox&service=dropbox';
              http (sprintf ('<input type="button" id="dav_Dropbox_authenticate" value="%s" onclick="javascript: windowShowInternal(\'%s\', \'Dropbox DAV authenticate\', 1100);" disabled="disabled" class="button" />', _name, _url));
            ?>
          </td>
        </tr>
        <tr id="tr_dav_Dropbox_path" style="display: <?V case when _value = 'Yes' then '' else 'none' end ?>">
          <th>Root Path</th>
          <td id="td_dav_Dropbox_path">
            <v:text name="dav_Dropbox_path" xhtml_id="dav_Dropbox_path" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_Dropbox_path', self.dav_path, 'virt:Dropbox-path', '/');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
      </table>
      <![CDATA[
        <script type="text/javascript">
          OAT.MSG.attach(OAT, "PAGE_LOADED", function(){destinationChange($('dav_Dropbox_sponger'), {checked: {show: ['dav13_cartridge', 'dav13_metaCartridge']}})});
        </script>
      ]]>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:search-dc-template15">
    <div id="14" class="tabContent" style="display: none;">
      <?vsp
        declare _value any;

        _value := WEBDAV.DBA.DAV_PROP_GET (self.dav_path, 'virt:SkyDrive-Authentication', 'No');
      ?>
      <table class="WEBDAV_formBody WEBDAV_noBorder" cellspacing="0">
        <tr>
          <th width="30%">
            <v:label for="dav_SkyDrive_activity" value="--'Activity manager (on/off)'" />
          </th>
          <td>
            <?vsp
              declare S varchar;

              S := self.get_fieldProperty ('dav_SkyDrive_activity', self.dav_path, 'virt:SkyDrive-activity', 'off');
              http (sprintf ('<input type="checkbox" name="dav_SkyDrive_activity" id="dav_SkyDrive_activity" %s disabled="disabled" value="on" />', case when S = 'on' then 'checked="checked"' else '' end));
            ?>
          </td>
        </tr>
        <tr>
          <th>
            <vm:label for="dav_SkyDrive_checkInterval" value="Check for updates every" />
          </th>
          <td>
            <v:text name="dav_SkyDrive_checkInterval" xhtml_id="dav_SkyDrive_checkInterval" format="%s" xhtml_disabled="disabled" xhtml_size="3">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_SkyDrive_checkInterval', self.dav_path, 'virt:SkyDrive-checkInterval', '15');
                ]]>
              </v:before-data-bind>
            </v:text> minutes
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_SkyDrive_graph" value="--'Graph name'" />
          </th>
          <td>
            <v:text name="dav_SkyDrive_graph" xhtml_id="dav_SkyDrive_graph" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.detGraphUI ('SkyDrive');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <?vsp
          self.detSpongerUI ('SkyDrive', 14);
        ?>
        <tr id="tr_dav_SkyDrive_display_name" style="display: <?V case when _value = 'Yes' then '' else 'none' end ?>">
          <th>User name</th>
          <td id="td_dav_SkyDrive_display_name">
            <?vsp
              http (WEBDAV.DBA.DAV_PROP_GET (self.dav_path, 'virt:SkyDrive-display_name', ''));
            ?>
          </td>
        </tr>
        <tr id="tr_dav_SkyDrive_email" style="display: <?V case when _value = 'Yes' then '' else 'none' end ?>">
          <th>User email</th>
          <td id="td_dav_SkyDrive_email">
            <?vsp
              http (WEBDAV.DBA.DAV_PROP_GET (self.dav_path, 'virt:SkyDrive-email', ''));
            ?>
          </td>
        </tr>
        <tr>
          <th></th>
          <td>
            <?vsp
              declare _name, _url any;

              _name := case when (_value = 'Yes') then 'Re-Authenticate' else 'Authenticate' end;
              _url := '/ods/access_service.vsp?m=webdav&p=SkyDrive&service=windowslive';
              http (sprintf ('<input type="button" id="dav_SkyDrive_authenticate" value="%s" onclick="javascript: windowShowInternal(\'%s\');" disabled="disabled" class="button" />', _name, _url));
            ?>
          </td>
        </tr>
        <tr id="tr_dav_SkyDrive_path" style="display: <?V case when _value = 'Yes' then '' else 'none' end ?>">
          <th>Root Path</th>
          <td id="td_dav_SkyDrive_path">
            <v:text name="dav_SkyDrive_path" xhtml_id="dav_SkyDrive_path" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_SkyDrive_path', self.dav_path, 'virt:SkyDrive-path', '/');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
      </table>
      <![CDATA[
        <script type="text/javascript">
          OAT.MSG.attach(OAT, "PAGE_LOADED", function(){destinationChange($('dav_SkyDrive_sponger'), {checked: {show: ['dav14_cartridge', 'dav14_metaCartridge']}})});
        </script>
      ]]>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:search-dc-template16">
    <div id="15" class="tabContent" style="display: none;">
      <?vsp
        declare _value any;

        _value := WEBDAV.DBA.DAV_PROP_GET (self.dav_path, 'virt:Box-Authentication', 'No');
      ?>
      <table class="WEBDAV_formBody WEBDAV_noBorder" cellspacing="0">
        <tr>
          <th width="30%">
            <v:label for="dav_Box_activity" value="--'Activity manager (on/off)'" />
          </th>
          <td>
            <?vsp
              declare S varchar;

              S := self.get_fieldProperty ('dav_Box_activity', self.dav_path, 'virt:Box-activity', 'off');
              http (sprintf ('<input type="checkbox" name="dav_Box_activity" id="dav_Box_activity" %s disabled="disabled" value="on" />', case when S = 'on' then 'checked="checked"' else '' end));
            ?>
          </td>
        </tr>
        <tr>
          <th>
            <vm:label for="dav_Box_checkInterval" value="Check for updates every" />
          </th>
          <td>
            <v:text name="dav_Box_checkInterval" xhtml_id="dav_Box_checkInterval" format="%s" xhtml_disabled="disabled" xhtml_size="3">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_Box_checkInterval', self.dav_path, 'virt:Box-checkInterval', '15');
                ]]>
              </v:before-data-bind>
            </v:text> minutes
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_Box_graph" value="--'Graph name'" />
          </th>
          <td>
            <v:text name="dav_Box_graph" xhtml_id="dav_Box_graph" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.detGraphUI ('Box');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <?vsp
          self.detSpongerUI ('Box', 15);
        ?>
        <tr id="tr_dav_Box_display_name" style="display: <?V case when _value = 'Yes' then '' else 'none' end ?>">
          <th>User name</th>
          <td id="td_dav_Box_display_name">
            <?vsp
              http (WEBDAV.DBA.DAV_PROP_GET (self.dav_path, 'virt:Box-display_name', ''));
            ?>
          </td>
        </tr>
        <tr id="tr_dav_Box_email" style="display: <?V case when _value = 'Yes' then '' else 'none' end ?>">
          <th>User email</th>
          <td id="td_dav_Box_email">
            <?vsp
              http (WEBDAV.DBA.DAV_PROP_GET (self.dav_path, 'virt:Box-email', ''));
            ?>
          </td>
        </tr>
        <tr>
          <th></th>
          <td>
            <?vsp
              declare _name, _url any;

              _name := case when (_value = 'Yes') then 'Re-Authenticate' else 'Authenticate' end;
              _url := '/ods/access_service.vsp?m=webdav&p=Box&service=boxnet';
              http (sprintf ('<input type="button" id="dav_Box_authenticate" value="%s" onclick="javascript: windowShowInternal(\'%s\', \'Box.Net access\', 1024);" disabled="disabled" class="button" />', _name, _url));
            ?>
          </td>
        </tr>
        <tr id="tr_dav_Box_path" style="display: <?V case when _value = 'Yes' then '' else 'none' end ?>">
          <th>Root Path</th>
          <td id="td_dav_Box_path">
            <v:text name="dav_Box_path" xhtml_id="dav_Box_path" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_Box_path', self.dav_path, 'virt:Box-path', '/');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
      </table>
      <![CDATA[
        <script type="text/javascript">
          OAT.MSG.attach(OAT, "PAGE_LOADED", function(){destinationChange($('dav_Box_sponger'), {checked: {show: ['dav15_cartridge', 'dav15_metaCartridge']}})});
        </script>
      ]]>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:search-dc-template17">
    <div id="16" class="tabContent" style="display: none;">
      <?vsp
        declare _value any;

        _value := WEBDAV.DBA.DAV_PROP_GET (self.dav_path, 'virt:WebDAV-authenticationType', 'No');
      ?>
      <table class="WEBDAV_formBody WEBDAV_noBorder" cellspacing="0">
        <tr>
          <th width="30%">
            <v:label for="dav_WebDAV_activity" value="--'Activity manager (on/off)'" />
          </th>
          <td>
            <?vsp
              declare S varchar;

              S := self.get_fieldProperty ('dav_WebDAV_activity', self.dav_path, 'virt:WebDAV-activity', 'off');
              http (sprintf ('<input type="checkbox" name="dav_WebDAV_activity" id="dav_WebDAV_activity" %s disabled="disabled" value="on" />', case when S = 'on' then 'checked="checked"' else '' end));
            ?>
          </td>
        </tr>
        <tr>
          <th>
            <vm:label for="dav_WebDAV_checkInterval" value="Check for updates every" />
          </th>
          <td>
            <v:text name="dav_WebDAV_checkInterval" xhtml_id="dav_WebDAV_checkInterval" format="%s" xhtml_disabled="disabled" xhtml_size="3">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_WebDAV_checkInterval', self.dav_path, 'virt:WebDAV-checkInterval', '15');
                ]]>
              </v:before-data-bind>
            </v:text> minutes
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_WebDAV_path" value="--'WebDAV path'" />
          </th>
          <td>
            <v:text name="dav_WebDAV_path" xhtml_id="dav_WebDAV_path" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_WebDAV_path', self.dav_path, 'virt:WebDAV-path', '');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_WebDAV_authenticationType" value="--'Authentication Type'" />
          </th>
          <td>
            <?vsp
              if (WEBDAV.DBA.keys_exist (WEBDAV.DBA.account_name (self.account_id)))
              {
                http (sprintf ('<label><input type="radio" name="dav_WebDAV_authenticationType" id="dav_WebDAV_authenticationType_0" value="Digest" %s onchange="javascript: destinationChange(this, {checked: {show: [''tr_dav_WebDAV_user'', ''tr_dav_WebDAV_password''], hide: [''tr_dav_WebDAV_key'']}});" title="Digest" /> <b>Digest</b></label>', case when _value = 'Digest' then 'checked="checked"' else '' end));
                http (sprintf ('<label><input type="radio" name="dav_WebDAV_authenticationType" id="dav_WebDAV_authenticationType_1" value="WebID" %s onchange="javascript: destinationChange(this, {checked: {hide: [''tr_dav_WebDAV_user'', ''tr_dav_WebDAV_password''], show: [''tr_dav_WebDAV_key'']}});" title="WebID" /> <b>WebID</b></label>', case when _value <> 'Digest' then 'checked="checked"' else '' end));
              }
              else
              {
                http ('<b>Digest</b>');
              }
            ?>
          </td>
        </tr>
        <tr id="tr_dav_WebDAV_key" style="display: none;">
          <th>
            <v:label for="dav_WebDAV_key" value="--'User''s Key '" />
          </th>
          <td>
            <select name="dav_WebDAV_key" id="dav_WebDAV_key">
              <?vsp
                declare _key varchar;
                declare _keys any;

                _key := self.get_fieldProperty ('dav_WebDAV_key', self.dav_path, 'virt:WebDAV-key', '');
                _keys := WEBDAV.DBA.keys_list (WEBDAV.DBA.account_name (self.account_id));
                foreach (any _k in _keys) do
                {
                  http (self.option_prepare(_k, _k, _key));
                }
              ?>
            </select>
          </td>
        </tr>
        <tr id="tr_dav_WebDAV_user">
          <th>
            <v:label for="dav_WebDAV_user" value="--'User Name'" />
          </th>
          <td>
            <v:text name="dav_WebDAV_user" xhtml_id="dav_WebDAV_user" format="%s" xhtml_disabled="disabled" xhtml_class="field-short">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_WebDAV_user', self.dav_path, 'virt:WebDAV-user', '');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr id="tr_dav_WebDAV_password">
          <th>
            <v:label for="dav_WebDAV_password" value="--'User Password'" />
          </th>
          <td>
            <v:text type="password" name="dav_WebDAV_password" xhtml_id="dav_WebDAV_password" format="%s" xhtml_disabled="disabled" xhtml_class="field-short">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := '**********';
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_WebDAV_graph" value="--'Graph name'" />
          </th>
          <td>
            <v:text name="dav_WebDAV_graph" xhtml_id="dav_WebDAV_graph" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.detGraphUI ('WebDAV');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <?vsp
          self.detSpongerUI ('WebDAV', 16);
        ?>
      </table>
      <![CDATA[
        <script type="text/javascript">
          OAT.MSG.attach(OAT, "PAGE_LOADED", function(){destinationChange($('dav_WebDAV_sponger'), {checked: {show: ['dav16_cartridge', 'dav16_metaCartridge']}})});
          OAT.MSG.attach(OAT, "PAGE_LOADED", function(){destinationChange($('dav_WebDAV_authenticationType_0'), {checked: {show: ['tr_dav_WebDAV_user', 'tr_dav_WebDAV_password'], hide: ['tr_dav_WebDAV_key']}, unchecked: {hide: ['tr_dav_WebDAV_user', 'tr_dav_WebDAV_password'], show: ['tr_dav_WebDAV_key']}})});
        </script>
      ]]>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:search-dc-template18">
    <div id="17" class="tabContent" style="display: none;">
      <table class="WEBDAV_formBody WEBDAV_noBorder" cellspacing="0">
        <tr>
          <th width="30%">
            <v:label for="dav_RACKSPACE_activity" value="--'Activity manager (on/off)'" />
          </th>
          <td>
            <?vsp
              declare S varchar;

              S := self.get_fieldProperty ('dav_RACKSPACE_activity', self.dav_path, 'virt:RACKSPACE-activity', 'off');
              http (sprintf ('<input type="checkbox" name="dav_RACKSPACE_activity" id="dav_RACKSPACE_activity" %s disabled="disabled" value="on" />', case when S = 'on' then 'checked="checked"' else '' end));
            ?>
          </td>
        </tr>
        <tr>
          <th>
            <vm:label for="dav_RACKSPACE_checkInterval" value="Check for updates every" />
          </th>
          <td>
            <v:text name="dav_RACKSPACE_checkInterval" xhtml_id="dav_RACKSPACE_checkInterval" format="%s" xhtml_disabled="disabled" xhtml_size="3">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_RACKSPACE_checkInterval', self.dav_path, 'virt:RACKSPACE-checkInterval', '15');
                ]]>
              </v:before-data-bind>
            </v:text> minutes
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_RACKSPACE_Type" value="Account type" />
          </th>
          <td>
            <v:select-list name="dav_RACKSPACE_Type" xhtml_id="dav_RACKSPACE_Type" xhtml_disabled="disabled">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_RACKSPACE_Type', self.dav_path, 'virt:RACKSPACE-Type', '');
                ]]>
              </v:before-data-bind>
              <v:item name="US Account" value="USA" />
              <v:item name="UK Account" value="UK" />
            </v:select-list>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_RACKSPACE_User" value="Account name (*)" />
          </th>
          <td>
            <v:text name="dav_RACKSPACE_User" xhtml_id="dav_RACKSPACE_User" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_RACKSPACE_User', self.dav_path, 'virt:RACKSPACE-User', '');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_RACKSPACE_API_Key" value="API Key (*)" />
          </th>
          <td>
            <v:text name="dav_RACKSPACE_API_Key" xhtml_id="dav_RACKSPACE_API_Key" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_RACKSPACE_API_Key', self.dav_path, 'virt:RACKSPACE-API_Key', '');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_RACKSPACE_Container" value="Container Name" />
          </th>
          <td>
            <v:text name="dav_RACKSPACE_Container" xhtml_id="dav_RACKSPACE_Container" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_RACKSPACE_Container', self.dav_path, 'virt:RACKSPACE-Container', '');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr id="tr_dav_RACKSPACE_path">
          <th>Root Path</th>
          <td id="td_dav_RACKSPACE_path">
            <v:text name="dav_RACKSPACE_path" xhtml_id="dav_RACKSPACE_path" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.get_fieldProperty ('dav_RACKSPACE_path', self.dav_path, 'virt:RACKSPACE-path', '/');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_RACKSPACE_graph" value="Graph name" />
          </th>
          <td>
            <v:text name="dav_RACKSPACE_graph" xhtml_id="dav_RACKSPACE_graph" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := self.detGraphUI ('RACKSPACE');
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <?vsp
          self.detSpongerUI ('RACKSPACE', 17);
        ?>
      </table>
      <![CDATA[
        <script type="text/javascript">
          OAT.MSG.attach(OAT, "PAGE_LOADED", function(){destinationChange($('dav_RACKSPACE_sponger'), {checked: {show: ['dav17_cartridge', 'dav17_metaCartridge']}})});
        </script>
      ]]>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <!-- Auto Versioning -->
  <xsl:template match="vm:autoVersion">
    <tr id="davRow_version">
      <th>
        <vm:label for="dav_autoversion" value="--'Auto Versioning Content'" />
      </th>
      <td>
        <?vsp
          declare tmp, tmp2 any;

          tmp := case when (self.dav_type = 'R') and (self.command_mode = 10) then 'onchange="javascript: window.document.F1.submit();"' else '' end;
          tmp2 := case when self.dav_enable_versioning then '' else 'disabled="disabled' end;
          http (sprintf ('<select name="dav_autoversion" id="dav_autoversion" %s %s class="field-short">', tmp, tmp2));

          tmp := WEBDAV.DBA.DAV_GET (self.dav_item, 'autoversion');
          if (isnull(tmp) and (self.dav_type = 'R'))
            tmp := WEBDAV.DBA.DAV_GET_AUTOVERSION (WEBDAV.DBA.real_path(self.dir_path));

          http (self.option_prepare('',   'No',   tmp));
          http (self.option_prepare('A',  'Checkout -> Checkin', tmp));
          http (self.option_prepare('B',  'Checkout -> Unlocked -> Checkin', tmp));
          http (self.option_prepare('C',  'Checkout', tmp));
          http (self.option_prepare('D',  'Locked -> Checkout', tmp));

          http ('</select>');
        ?>
      </td>
    </tr>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:permissions-header1">
    <tr>
      <xsl:if test="@text">
        <th rowspan="2" style="background-color: #EFEFEF; border-width: 0px;" />
      </xsl:if>
      <th colspan="3">Owner</th>
      <th colspan="3">Group</th>
      <th class="right" colspan="3">Other</th>
    </tr>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template match="vm:permissions-header2">
    <tr>
      <td>r</td>
      <td>w</td>
      <td>x</td>
      <td>r</td>
      <td>w</td>
      <td>x</td>
      <td>r</td>
      <td>w</td>
      <td class="right">x</td>
    </tr>
  </xsl:template>

</xsl:stylesheet>
