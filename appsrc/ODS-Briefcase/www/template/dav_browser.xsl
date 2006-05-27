<!--
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
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:v="http://www.openlinksw.com/vspx/" xmlns:xhtml="http://www.w3.org/1999/xhtml" xmlns:vm="http://www.openlinksw.com/vspx/macro">
  <xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>
  <!--=========================================================================-->
  <xsl:template match="vm:dav_browser">
    <v:template name="template_main" type="simple">
      <v:variable name="tbLabels" persist="0" type="integer" default="0" />
      <v:variable name="command" persist="0" type="integer" default="0" />
      <v:variable name="command_mode" persist="0" type="integer" default="0" />
      <v:variable name="command_save" persist="0" type="integer" default="0" />
      <v:variable name="command_acl" persist="0" type="integer" default="0"/>
      <v:variable name="source" persist="0" type="varchar" default="''" />
      <v:variable name="item_array" persist="0" type="any" default="null" />
      <v:variable name="need_overwrite" persist="0" type="integer" default="0" />
      <v:variable name="dir_path" persist="1" type="varchar" default="'__root__'" />
      <v:variable name="dir_right" persist="0" type="varchar" default="''"/>
      <v:variable name="dir_select" persist="0" type="integer" default="0" />
      <v:variable name="dir_details" persist="1" type="integer" default="0" />
      <v:variable name="dir_order" persist="1" type="varchar" default="'column_#1'" />
      <v:variable name="dir_direction" persist="1" type="varchar" default="'asc'" />
      <v:variable name="dir_grouping" type="varchar" default="''" />
      <v:variable name="dir_groupName" type="varchar" default="''" />
      <v:variable name="dir_cloud" type="integer" default="0" />
      <v:variable name="dir_tags" type="any" default="null" />
      <v:variable name="dir_columns" type="any" default="null" />
      <v:variable name="search_filter" persist="0" type="varchar" default="''" />
      <v:variable name="search_simple" persist="0" param-name="keywords" type="any" default="null" />
      <v:variable name="search_advanced" persist="0" type="any" default="null" />
      <v:variable name="search_dc" persist="0" type="any" default="null" />
      <v:variable name="vmdType" persist="0" type="varchar" default="null"/>
      <v:variable name="vmdSchema" persist="0" type="varchar" default="null"/>
      <v:variable name="dav_vector" persist="0" type="any" default="null" />
      <v:variable name="tabNo" param-name="tabNo" type="varchar" default="'1'"/>
      <v:variable name="ace" persist="0" type="any"/>
      <v:variable name="dav_id"   type="integer" default="-1" />
      <v:variable name="dav_path" type="varchar" default="''" />
      <v:variable name="dav_type" type="varchar" default="''" />
      <v:variable name="dav_detType" type="varchar" default="''" />
      <v:variable name="dav_item" type="any" default="null" />
      <v:variable name="dav_enable" type="integer" default="1"/>
      <v:variable name="dav_propEnable" type="integer" default="1"/>
      <v:variable name="dav_acl" persist="0" type="varbinary"/>
      <v:variable name="dav_tags" persist="0" type="varchar"/>
      <v:variable name="dav_tags2" persist="0" type="varchar"/>
      <v:variable name="dav_metadata" persist="0" type="varchar" default="null"/>
      <v:variable name="dav_content" type="varchar" default="'Can not find file'" />

      <v:on-init>
        <![CDATA[
          declare settings any;

          settings := ODRIVE.WA.odrive_settings(self.vc_page.vc_event.ve_params);

          self.tbLabels := cast(get_keyword('tbLabels', settings, '1') as integer);

          self.dir_columns := vector();
          self.dir_columns := vector_concat(self.dir_columns, vector(vector('column_#1', 'c0', 'Name',          1, 0, vector(cast(get_keyword('column_#1', settings, '1') as integer), 1), 'width="50%"')));
          self.dir_columns := vector_concat(self.dir_columns, vector(vector('column_#2',   '', 'Tags',          0, 0, vector(cast(get_keyword('column_#2', settings, '1') as integer), 0), '')));
          self.dir_columns := vector_concat(self.dir_columns, vector(vector('column_#3', 'c2', 'Size',          1, 1, vector(cast(get_keyword('column_#3', settings, '1') as integer), 0), '')));
          self.dir_columns := vector_concat(self.dir_columns, vector(vector('column_#4', 'c3', 'Date Modified', 1, 1, vector(cast(get_keyword('column_#4', settings, '1') as integer), 0), '')));
          self.dir_columns := vector_concat(self.dir_columns, vector(vector('column_#5', 'c4', 'Mime Type',     1, 1, vector(cast(get_keyword('column_#5', settings, '1') as integer), 0), '')));
          self.dir_columns := vector_concat(self.dir_columns, vector(vector('column_#6', 'c9', 'Kind',          1, 1, vector(cast(get_keyword('column_#6', settings, '1') as integer), 0), '')));
          self.dir_columns := vector_concat(self.dir_columns, vector(vector('column_#7', 'c5', 'Owner',         1, 1, vector(cast(get_keyword('column_#7', settings, '1') as integer), 0), '')));
          self.dir_columns := vector_concat(self.dir_columns, vector(vector('column_#8', 'c6', 'Group',         1, 1, vector(cast(get_keyword('column_#8', settings, '1') as integer), 0), '')));
          self.dir_columns := vector_concat(self.dir_columns, vector(vector('column_#9', 'c7', 'Permissions',   0, 0, vector(cast(get_keyword('column_#9', settings, '1') as integer), 0), '')));
        ]]>
      </v:on-init>
      <v:before-data-bind>
        <![CDATA[
          self.dir_path := get_keyword ('dir', self.vc_page.vc_event.ve_params, self.dir_path);
          if (self.dir_path = '__root__')
            self.dir_path := ODRIVE.WA.odrive_dav_home();
          self.dir_details := cast(get_keyword('list_type', self.vc_page.vc_event.ve_params, self.dir_details) as integer);

          if ((self.command = 0) and (self.command_mode = 2))
            self.search_simple := trim(get_keyword('simple', self.vc_page.vc_event.ve_params, self.search_simple));

          if (get_keyword('mode', self.vc_page.vc_event.ve_params) = 'simple') {
            self.command_set(0, 2);
            if (self.dir_path = '')
              self.dir_path := ODRIVE.WA.odrive_dav_home();
            self.search_simple := trim(get_keyword('keywords', self.vc_page.vc_event.ve_params));
          }

          if (get_keyword('mode', self.vc_page.vc_event.ve_params) = 'advanced') {
            self.command_set(0, 3);
            if (self.dir_path = '')
              self.dir_path := ODRIVE.WA.odrive_dav_home();
            ODRIVE.WA.dav_dc_set_base(self.search_dc, 'path', ODRIVE.WA.odrive_real_path(self.dir_path));
            ODRIVE.WA.dav_dc_set_base(self.search_dc, 'name', trim(get_keyword('keywords', self.vc_page.vc_event.ve_params)));
          }
          self.dir_right := ODRIVE.WA.odrive_permission(concat(ODRIVE.WA.path_show(self.dir_path), '/'));
        ]]>
      </v:before-data-bind>

      <v:method name="dc_prepare" arglist="">
        <![CDATA[
          ODRIVE.WA.dav_dc_set_base(self.search_dc, 'path', get_keyword('ts_path', self.vc_page.vc_event.ve_params, ODRIVE.WA.path_show(self.dir_path)));
          ODRIVE.WA.dav_dc_set_base(self.search_dc, 'name', get_keyword('ts_name', self.vc_page.vc_event.ve_params, ''));
          ODRIVE.WA.dav_dc_set_base(self.search_dc, 'content', get_keyword('ts_content', self.vc_page.vc_event.ve_params, ''));

          ODRIVE.WA.dav_dc_set_advanced(self.search_dc, 'mime', get_keyword('ts_mime', self.vc_page.vc_event.ve_params, ''));
          ODRIVE.WA.dav_dc_set_advanced(self.search_dc, 'owner', ODRIVE.WA.odrive_user_id(trim(get_keyword('ts_owner', self.vc_page.vc_event.ve_params, ''))));
          ODRIVE.WA.dav_dc_set_advanced(self.search_dc, 'group', ODRIVE.WA.odrive_user_id(trim(get_keyword('ts_group', self.vc_page.vc_event.ve_params, ''))));
          ODRIVE.WA.dav_dc_set_advanced(self.search_dc, 'createDate11', get_keyword('ts_createDate11', self.vc_page.vc_event.ve_params, ''));
          ODRIVE.WA.dav_dc_set_advanced(self.search_dc, 'createDate12', get_keyword('ts_createDate12', self.vc_page.vc_event.ve_params, ''));
          ODRIVE.WA.dav_dc_set_advanced(self.search_dc, 'createDate21', get_keyword('ts_createDate21', self.vc_page.vc_event.ve_params, ''));
          ODRIVE.WA.dav_dc_set_advanced(self.search_dc, 'createDate22', get_keyword('ts_createDate22', self.vc_page.vc_event.ve_params, ''));
          ODRIVE.WA.dav_dc_set_advanced(self.search_dc, 'modifyDate11', get_keyword('ts_modifyDate11', self.vc_page.vc_event.ve_params, ''));
          ODRIVE.WA.dav_dc_set_advanced(self.search_dc, 'modifyDate12', get_keyword('ts_modifyDate12', self.vc_page.vc_event.ve_params, ''));
          ODRIVE.WA.dav_dc_set_advanced(self.search_dc, 'modifyDate21', get_keyword('ts_modifyDate21', self.vc_page.vc_event.ve_params, ''));
          ODRIVE.WA.dav_dc_set_advanced(self.search_dc, 'modifyDate22', get_keyword('ts_modifyDate22', self.vc_page.vc_event.ve_params, ''));
          ODRIVE.WA.dav_dc_set_advanced(self.search_dc, 'publicTags11', get_keyword('ts_publicTags11', self.vc_page.vc_event.ve_params, ''));
          ODRIVE.WA.dav_dc_set_advanced(self.search_dc, 'publicTags12', get_keyword('ts_publicTags12', self.vc_page.vc_event.ve_params, ''));
          ODRIVE.WA.dav_dc_set_advanced(self.search_dc, 'privateTags11', get_keyword('ts_privateTags11', self.vc_page.vc_event.ve_params, ''));
          ODRIVE.WA.dav_dc_set_advanced(self.search_dc, 'privateTags12', get_keyword('ts_privateTags12', self.vc_page.vc_event.ve_params, ''));
        ]]>
      </v:method>

      <v:method name="option_prepare" arglist="in value any, in name any, in selected any">
        <![CDATA[
          if (cast(value as varchar) = ODRIVE.WA.xml2string(selected))
            selected := 'selected="selected"';
          else
            selected := '';
          return sprintf('<option value="%s" %s>%s</option>', cast(value as varchar), selected, cast(name as varchar));
        ]]>
      </v:method>

      <v:method name="search_condition" arglist="in name any, in aValues any, in aValue any, in class any">
        <![CDATA[
          declare anOptions any;
          declare N integer;
          anOptions := vector (
            '=', 'equal to',
            '&lt;', 'less than',
            '&lt;=', 'less than or equal to',
            '&gt;', 'greater than',
            '&gt;=', 'greater than or equal to',
            'starts_with', 'starts with',
            'contains_substring', 'contains',
            'contains_text', 'contains words/phrases',
            'may_contain_text', 'may contain words/phrases',
            'contains_tags', 'contains keywords',
            'may_contain_tags', 'may contain keywords');
          http(sprintf('<select name="%s" class="%s" disabled="disabled">', name, class));
          http(self.option_prepare('', '', aValue));
          if (isnull(aValues)) {
            for (N := 0; N < length(anOptions); N := N + 2)
              http(self.option_prepare(anOptions[N], anOptions[N+1], aValue));
          } else {
            for (N := 0; N < length(aValues); N := N + 1)
              http(self.option_prepare(aValues[N], get_keyword(aValues[N], anOptions), aValue));
          }
          http('</select>');
        ]]>
      </v:method>

      <v:method name="ace_checkbox" arglist="in itemName varchar, in itemSufix varchar, in itemValue integer">
        <![CDATA[
         declare secondSufix, itemChecked varchar;

         if (itemValue)
           itemChecked := 'checked="checked"';
         else
           itemChecked := '';

         if (itemSufix = 'grant')
           secondSufix := 'revoke';
         else
           secondSufix := 'grant';

         http(sprintf('<input type="checkbox" value="1" name="%s_%s" %s onClick="javascript: uncheck(\'%s_%s\')"/>', itemName, itemSufix, itemChecked, itemName, secondSufix));
        ]]>
      </v:method>

      <v:method name="property_right" arglist="in property any">
        <![CDATA[
          if (ODRIVE.WA.check_admin(ODRIVE.WA.session_user_id(self.vc_page.vc_event.ve_params)))
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

      <v:method name="command_set" arglist="in command integer, in command_mode integer">
        <![CDATA[
          self.tabNo := '1';
          self.command := command;
          self.command_mode := command_mode;
          if (self.command = 0) {
            self.need_overwrite := 0;
            self.item_array := vector();
            self.dir_select := 0;
            if (self.command_mode <> 1)
              self.search_filter := null;
            if (self.command_mode <> 2)
              self.search_simple := null;
            if (self.command_mode <> 3) {
              self.search_advanced := null;
              self.dir_grouping := '';
              self.dir_cloud := 0;
            }
            self.search_dc := null;
          }
        ]]>
      </v:method>

      <v:method name="command_push" arglist="in command integer, in command_mode integer">
        <![CDATA[
          self.command_save := vector(self.command, self.command_mode, self.dir_path);
          self.command_set(command, command_mode);
        ]]>
      </v:method>

      <v:method name="command_pop" arglist="in path varchar">
        <![CDATA[
          if (is_empty_or_null(self.command_save)) {
            self.command_set(0, 0);
          } else {
            self.command_set(self.command_save[0], self.command_save[1]);
            if (isnull(path)) {
              self.dir_path := self.command_save[2];
            } else {
              self.dir_path := path;
            }
            self.command_save := null;
          }
        ]]>
      </v:method>

      <v:method name="prepare_command" arglist="inout params any, in command any, in dir_select any">
        <![CDATA[
          declare item varchar;
          declare i integer;
          self.source := ODRIVE.WA.odrive_refine_path(self.dir_path);

          self.item_array := vector();
          i := 0;
          while (item := adm_next_checkbox('CB_', params, i)) {
            if (((command = 20) and ODRIVE.WA.odrive_read_permission(item)) or
                ((command = 21) and ODRIVE.WA.odrive_read_permission(item)) or
                ((command = 22) and ODRIVE.WA.det_action_enable(item, 'edit')) or
                ((command = 23) and ODRIVE.WA.det_action_enable(item, 'edit')) or
                ((command = 24) and ODRIVE.WA.det_action_enable(item, 'edit')  and (not ODRIVE.WA.DAV_ERROR(DB.DBA.DAV_SEARCH_ID(item, 'R')))) or
                ((command = 25) and ODRIVE.WA.det_action_enable(item, 'edit')  and (not ODRIVE.WA.DAV_ERROR(DB.DBA.DAV_SEARCH_ID(item, 'R')))) or
                ((command = 26) and ODRIVE.WA.odrive_read_permission(item)     and (not ODRIVE.WA.DAV_ERROR(DB.DBA.DAV_SEARCH_ID(item, 'R'))))
               )
              self.item_array := vector_concat(self.item_array, vector(item, null));
          }

          if (length(self.item_array) > 0) {
            self.command_push(command, 0);
            self.dir_select := dir_select;
            self.need_overwrite := 0;
          } else {
            self.vc_error_message := 'Operation can not be executed on selected resources.';
            self.vc_is_valid := 0;
          }
        ]]>
      </v:method>

      <v:method name="execute_command" arglist="in need_overwrite any">
        <![CDATA[
          declare retValue, i integer;
          declare _target varchar;
          declare tmp_vec, _item any;

          self.need_overwrite := 0;
          tmp_vec := vector();
          i := 0;
          while (i < length(self.item_array)) {
            if (self.command = 23) {
              retValue := ODRIVE.WA.DAV_DELETE(self.item_array[i]);
            } else {
              _item := ODRIVE.WA.DAV_INIT(self.item_array[i]);
              if (ODRIVE.WA.DAV_ERROR(_item)) {
                retValue := _item;
              } else {
                _target := concat(ODRIVE.WA.odrive_real_path(self.t_dest.ufl_value), ODRIVE.WA.DAV_GET(_item, 'name'));
                if (ODRIVE.WA.DAV_GET(_item, 'type') = 'C')
                  _target := concat(_target, '/');
                if (self.command = 20)
                  retValue := ODRIVE.WA.DAV_COPY(self.item_array[i], _target, need_overwrite, ODRIVE.WA.DAV_GET(_item, 'permissions'));
                else if (self.command = 21)
                  retValue := ODRIVE.WA.DAV_MOVE(self.item_array[i], _target, need_overwrite);
              }
            }

            if (retValue < 0) {
              self.need_overwrite := 1;
              tmp_vec := vector_concat(tmp_vec, vector(self.item_array[i], ODRIVE.WA.DAV_PERROR(retValue)));
            }
            i := i + 2;
          }
          self.item_array := tmp_vec;
          if (length(self.item_array) = 0)
            self.command_pop(self.dir_path);
        ]]>
      </v:method>

      <v:method name="toolbarEnable" arglist="in cmd varchar">
        <![CDATA[
          if (is_empty_or_null(self.dir_path))
            return 0;
          if (self.dir_path = ODRIVE.WA.shared_name())
            return 0;
          if (not (((self.command = 0) and (self.command_mode <> 3)) or ((self.command = 0) and (self.command_mode = 3) and (not isnull(self.search_advanced)))))
            return 0;
          if (cmd = 'new') {
            if (not (self.command_mode in (0,1)))
              return 0;
            if (not ODRIVE.WA.det_action_enable(ODRIVE.WA.odrive_real_path(self.dir_path), 'createContent'))
              return 0;
          }
          if (cmd = 'upload') {
            if (not (self.command_mode in (0,1)))
              return 0;
            if (not ODRIVE.WA.det_action_enable(ODRIVE.WA.odrive_real_path(self.dir_path), 'createContent'))
              return 0;
          }
          if (cmd = 'mail') {
            return 0;
          }
          return 1;
        ]]>
      </v:method>

      <v:method name="toolbarLabel" arglist="in cmd varchar">
        <![CDATA[
          if (self.tbLabels = 0)
            return '';
          return sprintf('<br /><span class="toolbarLabel">%s</span>', cmd);
        ]]>
      </v:method>

      <v:method name="getColumn" arglist="in columnId varchar">
        <![CDATA[
          declare N integer;

          for (N := 0; N < length(self.dir_columns); N := N + 1)
            if (self.dir_columns[N][0] = columnId)
              return self.dir_columns[N];
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

          declare dir_column any;

          dir_column := self.getColumn(columnId);
          http(sprintf('<th nowrap="nowrap" %s>', dir_column[6]));
          if ((dir_column[3] = 1) and (self.dir_path <> '')) {
            self.sortColumn(dir_column[2], dir_column[0]);
          } else {
            http(dir_column[2]);
          }
          http('</th>');
        ]]>
      </v:method>

      <v:method name="sortColumn" arglist="in titleName varchar, in columnName varchar">
        <![CDATA[
          declare altStr, directionStr, imageStr varchar;

          if (self.dir_order = columnName and self.dir_direction = 'desc') {
            directionStr := 'Ascending';
            imageStr := '&nbsp;<img src="image/d.gif" border="0" alt="Down"/>';
          } else if (self.dir_order = columnName and self.dir_direction = 'asc') {
            directionStr := 'Descending';
            imageStr := '&nbsp;<img src="image/u.gif" border="0" alt="Up"/>';
          } else {
            directionStr := 'Ascending';
            imageStr := '&nbsp;&nbsp;';
          }
          altStr := sprintf('Sort Rows on %s in %s Order', titleName, directionStr);
          http(sprintf('<a href="#" onClick="javascript: myPost(''F1'', ''sortColumn'', ''%s''); return false;" alt="%s" title="%s">%s%s</a>', columnName, altStr, altStr, titleName, imageStr));
        ]]>
      </v:method>

      <v:method name="sortChange" arglist="in columnName varchar">
        <![CDATA[
          if (columnName = '')
            return;
          self.ds_items.vc_reset();
          if (self.dir_order = columnName) {
            self.dir_direction := either(equ(self.dir_direction, 'asc'), 'desc', 'asc');
          } else {
            self.dir_direction := 'asc';
          }
          self.dir_order := columnName;
        ]]>
      </v:method>

      <v:method name="ui_image" arglist="in itemPath varchar, in itemType varchar, in itemMimeType varchar">
        <![CDATA[
          if (itemType = 'C') {
            --if (ODRIVE.WA.det_category(itemPath) = 'ResFilter')
            --  return 'image/dav/sfolder_16.png';
            if (ODRIVE.WA.det_category(itemPath) = 'CatFilter')
              return 'image/dav/category_16.png';
            if (ODRIVE.WA.det_category(itemPath) = 'PropFilter')
              return 'image/dav/property_16.png';
            if (ODRIVE.WA.det_category(itemPath) = 'HostFs')
              return 'image/dav/hostfs_16.png';
            if (ODRIVE.WA.det_category(itemPath) = 'Versioning')
              return 'image/dav/versions_16.png';
            if (ODRIVE.WA.det_category(itemPath) = 'News3')
              return 'image/dav/enews_16.png';
            if (ODRIVE.WA.det_category(itemPath) = 'Blog')
              return 'image/dav/blog_16.png';
            if (ODRIVE.WA.det_category(itemPath) = 'oMail')
              return 'image/dav/omail_16.png';
            return 'image/dav/foldr_16.png';
          }
          if (itemPath like '%.txt')
            return 'image/dav/text.gif';
          if (itemPath like '%.pdf')
            return 'image/dav/pdf.gif';
          if (itemPath like '%.html')
            return 'image/dav/html.gif';
          if (itemPath like '%.htm')
            return 'image/dav/html.gif';
          if (itemPath like '%.wav')
            return 'image/dav/wave.gif';
          if (itemPath like '%.mp3')
            return 'image/dav/wave.gif';
          if (itemPath like '%.wma')
            return 'image/dav/wave.gif';
          if (itemPath like '%.wmv')
            return 'image/dav/video.gif';
          if (itemPath like '%.doc')
            return 'image/dav/msword.gif';
          if (itemPath like '%.dot')
            return 'image/dav/msword.gif';
          if (itemPath like '%.xls')
            return 'image/dav/xls.gif';
          if (itemPath like '%.zip')
            return 'image/dav/zip.gif';
          if (itemMimeType like 'audio/%')
            return 'image/dav/wave.gif';
          if (itemMimeType like 'video/%')
            return 'image/dav/video.gif';
          if (itemMimeType like 'image/%')
            return 'image/dav/image.gif';
          return 'image/dav/generic_file.png';
        ]]>
      </v:method>

      <v:method name="ui_alt" arglist="in itemPath varchar, in itemType varchar">
        <![CDATA[
          if (itemType = 'C')
            return 'Folder: ' || itemPath;
          return 'File: ' || itemPath;
        ]]>
      </v:method>

      <v:method name="ui_name" arglist="in name varchar">
        <![CDATA[
          declare chars integer;

          chars := ODRIVE.WA.odrive_settings_chars(self.vc_page.vc_event.ve_params);
          if (chars and (length(name) > chars))
            return concat(subseq(name, 0, chars-3), '...');
          return name;
        ]]>
      </v:method>

      <v:method name="ui_size" arglist="in itemSize integer, in itemType varchar">
        <![CDATA[
          declare S varchar;

          if ((itemSize = 0) and (itemType = 'C'))
            return '';

          S := '%d<span style="font-family: Monospace;">&nbsp;%s</span>';
          if (itemSize < 1024)
            return sprintf(S, itemSize, 'B&nbsp;');
          if (itemSize < (1024 * 1024))
            return sprintf(S, floor(itemSize / 1024), 'KB');
          if (itemSize < (1024 * 1024 * 1024))
            return sprintf(S, floor(itemSize / (1024 * 1024)), 'MB');
          if (itemSize < (1024 * 1024 * 1024 * 1024))
            return sprintf(S, floor(itemSize / (1024 * 1024 * 1024)), 'GB');
          return sprintf(S, floor(itemSize / (1024 * 1024 * 1024 * 1024)), 'TB');
        ]]>
      </v:method>

      <v:method name="ui_date" arglist="in itemDate datetime">
        <![CDATA[
          itemDate := left(cast(itemDate as varchar), 19);
          return sprintf('%s <font size="1">%s</font>', left(itemDate, 10), right(itemDate, 8));
        ]]>
      </v:method>

      <v:method name="do_url_int" arglist="in param varchar, in section varchar, in path varchar">
        <![CDATA[
          declare T varchar;

          T := ODRIVE.WA.dav_dc_get(self.search_dc, section, path, '');
          if (T = '')
            return '';

          return sprintf('&%s=%U', param, T);
        ]]>
      </v:method>

      <v:method name="do_url" arglist="">
        <![CDATA[
          declare N integer;
          declare tmp, T varchar;

          tmp := '';
          if (self.command_mode = 2) {
            tmp := concat(tmp, '&mode=s');
            tmp := concat(tmp, sprintf('&b1=%U', ODRIVE.WA.odrive_real_path(self.dir_path)));
            tmp := concat(tmp, sprintf('&b2=%U', trim(self.search_simple)));
          }
          if (self.command_mode = 3) {
            tmp := concat(tmp, self.do_url_int('b1',  'base',     'path'));
            tmp := concat(tmp, self.do_url_int('b2',  'base',     'name'));
            tmp := concat(tmp, self.do_url_int('b3',  'base',     'content'));

            tmp := concat(tmp, self.do_url_int('a1',  'advanced', 'mime'));
            tmp := concat(tmp, self.do_url_int('a2',  'advanced', 'owner'));
            tmp := concat(tmp, self.do_url_int('a3',  'advanced', 'group'));
            tmp := concat(tmp, self.do_url_int('a4',  'advanced', 'createDate11'));
            tmp := concat(tmp, self.do_url_int('a5',  'advanced', 'createDate12'));
            tmp := concat(tmp, self.do_url_int('a6',  'advanced', 'createDate21'));
            tmp := concat(tmp, self.do_url_int('a7',  'advanced', 'createDate22'));
            tmp := concat(tmp, self.do_url_int('a8',  'advanced', 'modifyDate11'));
            tmp := concat(tmp, self.do_url_int('a9',  'advanced', 'modifyDate12'));
            tmp := concat(tmp, self.do_url_int('a10', 'advanced', 'modifyDate21'));
            tmp := concat(tmp, self.do_url_int('a11', 'advanced', 'modifyDate22'));
            tmp := concat(tmp, self.do_url_int('a12', 'advanced', 'publicTags11'));
            tmp := concat(tmp, self.do_url_int('a13', 'advanced', 'publicTags12'));
            tmp := concat(tmp, self.do_url_int('a14', 'advanced', 'privateTags11'));
            tmp := concat(tmp, self.do_url_int('a15', 'advanced', 'privateTags12'));

            N := 1;
            for (select rs.* from ODRIVE.WA.dav_dc_metadata_rs(rs0)(c0 integer, c1 varchar, c2 varchar, c3 varchar, c4 varchar, c5 varchar) rs where rs0 = self.search_dc) do {
              tmp := concat(tmp, sprintf('&mt%d=%U', N, c1));
              tmp := concat(tmp, sprintf('&ms%d=%U', N, c2));
              tmp := concat(tmp, sprintf('&mn%d=%U', N, c3));
              tmp := concat(tmp, sprintf('&mc%d=%U', N, c4));
              tmp := concat(tmp, sprintf('&mv%d=%U', N, c5));
              N := N + 1;
            }
          }

          T := self.getColumn(self.dir_order);
          if (not is_empty_or_null(T) and (T[1] <> 'c0'))
            tmp := concat(tmp, sprintf('&order=%U', T[1]));
          if (not is_empty_or_null(self.dir_direction) and self.dir_direction <> 'desc')
            tmp := concat(tmp, sprintf('&direction=%U', self.dir_direction));

          return tmp;
        ]]>
      </v:method>

      <v:form name="F1" type="simple" method="POST" xhtml_enctype="multipart/form-data">
        <?vsp http(sprintf('<input type="hidden" name="tabNo" id="tabNo" value="%s"/>', self.tabNo)); ?>
        <?vsp http('<input type="hidden" name="f_tag_hidden" value=""/>'); ?>
        <?vsp http('<input type="hidden" name="f_tag2_hidden" value=""/>'); ?>

        <xsl:call-template name="toolBar"/>

        <?vsp
          if (0)
          {
        ?>
            <v:button name="f_tag2_search" action="simple" style="url" value="Submit">
              <v:on-post>
                <![CDATA[
                  self.command_set(0, 3);
                  ODRIVE.WA.dav_dc_set_base(self.search_dc, 'path', ODRIVE.WA.odrive_real_path(self.dir_path));
                  ODRIVE.WA.dav_dc_set_base(self.search_dc, 'name', trim(self.simple.ufl_value));
                  ODRIVE.WA.dav_dc_set_advanced(self.search_dc, 'publicTags11', 'contains_tags');
                  ODRIVE.WA.dav_dc_set_advanced(self.search_dc, 'publicTags12', get_keyword ('f_tag2_hidden', e.ve_params, ''));
                  self.search_advanced := self.search_dc;
                  self.vc_data_bind(e);
                 ]]>
               </v:on-post>
            </v:button>
            <v:button name="f_tag2_delete" action="simple" style="url" value="Submit">
              <v:on-post>
                <![CDATA[
                  self.dav_tags2 := ODRIVE.WA.tag_delete(self.dav_tags2, get_keyword ('f_tag2_hidden', e.ve_params, ''));
                  self.vc_data_bind(e);
                 ]]>
               </v:on-post>
            </v:button>
        <?vsp
          }
          if (0)
          {
        ?>
            <v:button name="f_tag_search" action="simple" style="url" value="Submit">
              <v:on-post>
                <![CDATA[
                  self.command_set(0, 3);
                  ODRIVE.WA.dav_dc_set_base(self.search_dc, 'path', ODRIVE.WA.odrive_real_path(self.dir_path));
                  ODRIVE.WA.dav_dc_set_base(self.search_dc, 'name', trim(self.simple.ufl_value));
                  ODRIVE.WA.dav_dc_set_advanced(self.search_dc, 'privateTags11', 'contains_tags');
                  ODRIVE.WA.dav_dc_set_advanced(self.search_dc, 'privateTags12', get_keyword ('f_tag_hidden', e.ve_params, ''));
                  self.search_advanced := self.search_dc;
                  self.vc_data_bind(e);
                 ]]>
               </v:on-post>
            </v:button>
            <v:button name="f_tag_delete" action="simple" style="url" value="Submit">
              <v:on-post>
                <![CDATA[
                  self.dav_tags := ODRIVE.WA.tag_delete(self.dav_tags, get_keyword ('f_tag_hidden', e.ve_params, ''));
                  self.vc_data_bind(e);
                 ]]>
               </v:on-post>
            </v:button>
        <?vsp
          }
        ?>

        <!-- Simple search -->
        <v:template type="simple" enabled="-- case when ((self.command = 0) and (self.command_mode = 2)) then 1 else 0 end">
          <div class="boxHeader" style="text-align: center;">
            <b>Search </b>
            <v:text name="simple" value="--self.search_simple" xhtml_onkeypress="return submitEnter(\'F1\', '', event)" xhtml_class="textbox" xhtml_size="70%"/>
            <xsl:call-template name="nbsp"/>
            |
            <v:button action="simple" style="url" value="Advanced" xhtml_class="form-button">
              <v:on-post>
                <![CDATA[
                  self.command_set(0, 3);
                  ODRIVE.WA.dav_dc_set_base(self.search_dc, 'path', ODRIVE.WA.odrive_real_path(self.dir_path));
                  ODRIVE.WA.dav_dc_set_base(self.search_dc, 'name', trim(self.simple.ufl_value));
                  self.vc_data_bind(e);
                ]]>
              </v:on-post>
            </v:button>
            |
            <v:button action="simple" style="url" value="Cancel" xhtml_class="form-button">
              <v:on-post>
                <![CDATA[
                  self.vc_is_valid := 1;
                  self.command_set(0, 0);
                  self.vc_data_bind(e);
                ]]>
              </v:on-post>
            </v:button>
          </div>
        </v:template>

        <!-- Advanced Search -->
        <v:template type="simple" enabled="-- case when ((self.command = 0) and (self.command_mode = 3)) then 1 else 0 end">
          <div id="c1">
            <div class="tabs">
              <vm:tabCaption tab="7" tabs="11" caption="Base"/>
              <vm:tabCaption tab="8" tabs="11" caption="Extended"/>
              <vm:tabCaption tab="9" tabs="11" caption="Metadata"/>
              <vm:tabCaption tab="11" tabs="11" caption="Options"/>
            </div>
            <div class="contents">
              <xsl:call-template name="search-dc-template7"/>
              <xsl:call-template name="search-dc-template8"/>
              <xsl:call-template name="search-dc-template9"/>
              <xsl:call-template name="search-dc-template11"/>
            </div>
            <div class="new-form-footer">
              <v:button action="simple" value="Search" xhtml_class="button">
                <v:on-post>
                  <![CDATA[
                    self.dc_prepare();
                    self.search_advanced := self.search_dc;
                    self.dir_order := get_keyword('ts_order', e.ve_params, '');
                    self.dir_direction := get_keyword('ts_direction', e.ve_params, '');
                    self.dir_grouping := get_keyword('ts_grouping', e.ve_params, '');
                    self.dir_cloud := cast(get_keyword('ts_cloud', e.ve_params, '0') as integer);
                    self.vc_data_bind(e);
                  ]]>
                </v:on-post>
              </v:button>
              <v:button action="simple" value="Save" enabled="--either(equ(self.dir_right, 'W'), 1, 0)" xhtml_class="button">
                <v:on-post>
                  <![CDATA[
                    self.dc_prepare();
                    self.command_push(10, 1);
                    self.vc_data_bind(e);
                  ]]>
                </v:on-post>
              </v:button>
              <v:button action="simple" value="Cancel" xhtml_class="button">
                <v:on-post>
                  <![CDATA[
                    self.vc_is_valid := 1;
                    self.command_set(0, 0);
                    self.vc_data_bind(e);
                  ]]>
                </v:on-post>
              </v:button>
            </div>
            <div style="margin: 0 0 6px 0;"/>
          </div>
          <script>
            coloriseTable('properties');
            coloriseTable('metaProperties');
            initEnabled();
            initTab(12, 7);
          </script>
        </v:template>

        <!-- Confirm replace -->
        <v:template type="simple" enabled="-- equ(self.command, 14)">
          <div class="new-form-header">
            Confirm replace
          </div>
          <div class="form-confirm">
            <v:label>
              <v:before-data-bind>
                <![CDATA[
                  declare res_cr_date varchar;
                  declare res_size integer;
                  res_size := self.ui_size(ODRIVE.WA.DAV_PROP_GET(self.dav_vector[0], ':getcontentlength'), 'R');
                  res_cr_date := self.ui_date(ODRIVE.WA.DAV_PROP_GET(self.dav_vector[0], ':creationdate'));
                  control.ufl_value := sprintf('Do you want to replace <b>%s</b> with size <b>%s</b> and created on <b>%s</b><br/> with file with size <b>%s</b>?', self.dav_vector[0], res_size, res_cr_date, self.ui_size(length(self.dav_vector[1]), 'R'));
                ]]>
              </v:before-data-bind>
            </v:label>
          </div>
          <div class="new-form-footer">
            <v:button action="simple" value="Replace">
              <v:on-post>
                <![CDATA[
                  declare retValue integer;
                  retValue := ODRIVE.WA.DAV_RES_UPLOAD(self.dav_vector[0], self.dav_vector[1], self.dav_vector[2], self.dav_vector[3], self.dav_vector[4], self.dav_vector[5]);
                  if (ODRIVE.WA.DAV_ERROR(retValue)) {
                    self.vc_error_message := ODRIVE.WA.DAV_PERROR(retValue);
                    self.vc_is_valid := 0;
                    self.vc_data_bind(e);
                    return;
                  }
                  self.command_pop(null);
                  self.vc_data_bind(e);
                ]]>
              </v:on-post>
            </v:button>
            <v:button action="simple" value="Cancel">
              <v:on-post>
                <![CDATA[
                  self.command_pop(null);
                  self.vc_data_bind(e);
                ]]>
              </v:on-post>
            </v:button>
          </div>
        </v:template>

        <!-- Create/update folder/file -->
        <v:template type="simple" enabled="-- equ(self.command, 10)">
          <v:before-data-bind>
            <![CDATA[
              self.dav_path := ODRIVE.WA.odrive_real_resource(self.source);
              self.dav_enable := 1;
              self.dav_propEnable := self.dav_enable;
              if (isnull(get_keyword('dav_group', self.vc_page.vc_event.ve_params)) and (self.command_mode <> 1))
                self.search_dc := ODRIVE.WA.dav_dc_xml();
              if (self.command_mode = 10) {
                self.dav_enable := ODRIVE.WA.det_action_enable(self.dav_path, 'edit');
                self.dav_item := ODRIVE.WA.DAV_INIT(self.dav_path);
                if (ODRIVE.WA.DAV_ERROR(self.dav_item)) {
                  self.command_pop(null);
                  self.vc_data_bind(e);
                  return;
                }
                self.dav_propEnable := self.dav_enable;
                if (self.dav_propEnable)
                  if (not isnull(DB.DBA.DAV_HIDE_ERROR(DB.DBA.DAV_PROP_GET_INT (ODRIVE.WA.DAV_GET (self.dav_item, 'id'), 'R', 'DAV:checked-in', 0))))
                    self.dav_propEnable := 0;
              } else if (self.command_mode = 5) {
                self.dav_item := ODRIVE.WA.DAV_INIT_RESOURCE();
              } else {
                self.dav_item := ODRIVE.WA.DAV_INIT_COLLECTION();
                if (self.command_mode = 1)
                  self.vc_page.vc_event.ve_params := vector_concat(self.vc_page.vc_event.ve_params, vector('dav_det', 'ResFilter', 'attr_dav_det', ''));
              }
              self.dav_type := ODRIVE.WA.DAV_GET(self.dav_item, 'type');
              self.dav_detType := get_keyword('dav_det', self.vc_page.vc_event.ve_params, ODRIVE.WA.DAV_GET(self.dav_item, 'detType'));
              if (isnull(get_keyword('dav_group', self.vc_page.vc_event.ve_params)))
                self.dav_acl := ODRIVE.WA.DAV_GET(self.dav_item, 'acl');
              if (self.command_mode = 10) {
                if (isnull(get_keyword('dav_group', self.vc_page.vc_event.ve_params))) {
                  self.dav_tags := '';
                  self.dav_tags2 := '';
                  if (self.dav_type = 'R') {
                    self.dav_tags := ODRIVE.WA.DAV_GET(self.dav_item, 'privatetags');
                    self.dav_tags2 := ODRIVE.WA.DAV_GET(self.dav_item, 'publictags');
                  }
                  self.dav_metadata := null;
                  if (self.dav_type = 'R')
                    self.dav_metadata := ODRIVE.WA.dav_rdf_get_metadata(self.dav_path);
                  self.search_dc := ODRIVE.WA.DAV_PROP_GET(self.dav_path, 'virt:Filter-Params');
                }
              }
              if (not isnull(get_keyword('dav_group', self.vc_page.vc_event.ve_params)))
                self.dc_prepare();
            ]]>
          </v:before-data-bind>
          <v:text name="formRight" type="hidden" value="--self.dav_enable"/>
          <div class="new-form-header">
            <v:label format="%s">:
              <v:before-data-bind>
                <![CDATA[
                  if (self.command_mode = 10) {
                    control.ufl_value := concat('Properties of ', self.source);
                  } else {
                    if (self.command_mode = 5)
                      control.ufl_value := 'Upload file into ';
                    else
                      control.ufl_value := 'Create folder in ';
                    control.ufl_value := concat(control.ufl_value, ODRIVE.WA.path_show(self.dir_path));
                  }
                ]]>
              </v:before-data-bind>
            </v:label>
          </div>
           <div id="c1">
            <div class="tabs">
              <vm:tabCaption tab="1" tabs="11" caption="Main"/>
              <v:template type="simple" enabled="-- gte(self.command_mode, 10)">
              <vm:tabCaption tab="2" tabs="11" caption="Sharing"/>
              </v:template>
              <v:template type="simple" enabled="-- case when (gte(self.command_mode, 10) and ODRIVE.WA.dav_rdf_has_metadata(self.dav_path)) then 1 else 0 end">
              <vm:tabCaption tab="3" tabs="11" caption="Metadata"/>
              </v:template>
              <v:template type="simple" enabled="-- case when (equ(self.command_mode, 10) and equ(self.dav_type, 'R') and ODRIVE.WA.det_action_enable(self.dav_path, 'version')) then 1 else 0 end">
              <vm:tabCaption tab="11" tabs="11" caption="Versions"/>
              </v:template>
              <v:template type="simple" enabled="-- equ(self.dav_type, 'C')">
              <!-- <vm:tabCaption tab="4" tabs="10" caption="oMail"/> -->
              <vm:tabCaption tab="5" tabs="11" caption="Filter"/>
              <vm:tabCaption tab="6" tabs="11" caption="FS link"/>
              <vm:tabCaption tab="7" tabs="11" caption="Base"/>
              <vm:tabCaption tab="8" tabs="11" caption="Extended"/>
              <vm:tabCaption tab="9" tabs="11" caption="Metadata"/>
              </v:template>
            </div>
            <div class="contents">
              <div id="1" class="tabContent">
                <table class="form-body" cellspacing="0">
                  <v:template type="simple" enabled="-- equ(self.command_mode, 5)">
                    <tr>
                      <th>
                        <v:label for="dav_file" value="--'Source path - File'" format="%s"/>
                      </th>
                      <td>
                        <input type="radio" name="dav_source" value="0" checked="checked" /><xsl:call-template name="nbsp"/>
                        <input type="file" name="dav_file" onChange="javascript: F1.dav_source[0].checked=true; getFileName(this);" onBlur="javascript: getFileName(this);" onFocus="javascript: F1.dav_source[0].checked=true;" size="40"/>
                      </td>
                    </tr>
                    <tr>
                      <th>
                        <v:label for="dav_url" value="--'- URL'" format="%s"/>
                      </th>
                      <td>
                        <input type="radio" name="dav_source" value="1" /><xsl:call-template name="nbsp"/>
                        <input type="text" name="dav_url" onBlur="javascript: getFileName(this);" onFocus="javascript: F1.dav_source[1].checked=true;" size="40"/>
                      </td>
                    </tr>
                  </v:template>
                  <tr>
                    <th>
                      <v:label for="dav_name" value="--either(equ(self.dav_type, 'R'), 'File name (*)', 'Folder name (*)')" format="%s"/>
                    </th>
                    <td>
                      <v:text name="dav_name" value="--get_keyword('dav_name', self.vc_page.vc_event.ve_params, ODRIVE.WA.utf2wide(ODRIVE.WA.DAV_GET(self.dav_item, 'name')))" format="%s" xhtml_disabled="disabled" xhtml_class="field-text"/>
                    </td>
                  </tr>
                  <v:template type="simple" enabled="-- equ(self.dav_type, 'R')">
                    <tr>
                      <th>
                        <v:label for="dav_mime" value="--'File Mime Type'" format="%s"/>
                      </th>
                      <td>
                        <v:text name="dav_mime" value="--get_keyword('dav_mime', self.vc_page.vc_event.ve_params, ODRIVE.WA.DAV_GET(self.dav_item, 'mimeType'))" format="%s" xhtml_disabled="disabled" xhtml_class="field-text"/>
                        <v:template type="simple" enabled="--self.dav_enable">
                          <input type="button" value="Select" onClick="javascript:windowShow('mimes_select.vspx?params=dav_mime:s1;')" disabled="disabled" class="button"/>
                        </v:template>
                      </td>
                    </tr>
                  </v:template>
                  <v:template type="simple" enabled="-- case when ((self.dav_type = 'C') or (self.command_mode <> 10)) then 1 else 0 end">
                    <xsl:call-template name="autoVersion"/>
                  </v:template>
                  <v:template type="simple" enabled="-- equ(self.dav_type, 'C')">
                    <tr>
                      <th>
                        <v:label for="dav_det" value="--'Folder type'" format="%s"/>
                      </th>
                      <td>
                        <select name="dav_det" onchange="javascript:updateLabel(this.options[this.selectedIndex].value);" disabled="disabled">
                          <?vsp
                            if (self.command_mode = 1) {
                              http(self.option_prepare('ResFilter',  'Smart Folder',                  'ResFilter'));
                            } else {
                              http(self.option_prepare('',           'Normal',                        self.dav_detType));
                              http(self.option_prepare('ResFilter',  'Smart Folder',                  self.dav_detType));
                              http(self.option_prepare('CatFilter',  'Category Folder',               self.dav_detType));
                              http(self.option_prepare('PropFilter', 'Property Filter Folder',        self.dav_detType));
                              http(self.option_prepare('HostFs',     'Host File System Folder Link',  self.dav_detType));
                              http(self.option_prepare('oMail',      'Mail Folders Link',             self.dav_detType));
                              http(self.option_prepare('News3',      'OFM Subscriptions',             self.dav_detType));
                              http(self.option_prepare('Versioning', 'Version Control Folder',        self.dav_detType));
                            }
                          ?>
                        </select>
                      </td>
                    </tr>
                  </v:template>
                  <tr>
                    <th>
                      <v:label for="dav_owner" value="--'Owner'" format="%s"/>
                    </th>
                    <td>
                      <v:text name="dav_owner" value="--get_keyword('dav_owner', self.vc_page.vc_event.ve_params, ODRIVE.WA.DAV_GET(self.dav_item, 'ownerName'))" format="%s" xhtml_disabled="disabled" xhtml_class="field-short">
                        <v:after-data-bind>
                          <![CDATA[
                            if (not ODRIVE.WA.check_admin(ODRIVE.WA.session_user_id(self.vc_page.vc_event.ve_params)))
                              control.tf_style := 3;
                          ]]>
                        </v:after-data-bind>
                      </v:text>
                      <v:template type="simple" enabled="-- case when (ODRIVE.WA.check_admin(ODRIVE.WA.session_user_id(self.vc_page.vc_event.ve_params)) and (self.dav_enable = 1)) then 1 else 0 end;">
                        <input type="button" value="Select" onClick="javascript:windowShow('users_select.vspx?mode=u&amp;params=dav_owner:s1;')" disabled="disabled" class="button"/>
                      </v:template>
                    </td>
                  </tr>
                  <tr>
                    <th>
                      <v:label for="dav_group" value="--'Group'" format="%s"/>
                    </th>
                    <td>
                      <v:text name="dav_group" value="--get_keyword('dav_group', self.vc_page.vc_event.ve_params, ODRIVE.WA.DAV_GET(self.dav_item, 'groupName'))" format="%s" xhtml_disabled="disabled" xhtml_class="field-short"/>
                      <v:template type="simple" enabled="--self.dav_enable">
                        <input type="button" value="Select" onClick="javascript:windowShow('users_select.vspx?mode=g&amp;params=dav_group:s1;')" disabled="disabled" class="button"/>
                      </v:template>
                    </td>
                  </tr>
                  <tr>
                    <th>
                      <v:label for="dav_group" value="--'Permissions'" format="%s"/>
                    </th>
                    <td>
                      <table class="form-list" style="width: 1%;" cellspacing="0">
                        <xsl:call-template name="permissions-header1"/>
                        <xsl:call-template name="permissions-header2"/>
                        <tr>
                          <?vsp
                            declare i integer;
                            declare perms, checked, c varchar;
                            perms := ODRIVE.WA.DAV_GET(self.dav_item, 'permissions');
                            for (i := 0; i < 9; i := i + 1) {
                              if (isnull(get_keyword('dav_group', self.vc_page.vc_event.ve_params)))
                                c := subseq(perms, i, i+1);
                              else
                                c := get_keyword(sprintf('dav_perm%i', i), self.vc_page.vc_event.ve_params, '0');
                              if (c <> '0')
                                checked := 'checked';
                              else
                                checked := '';
                              http(sprintf('<td align="center"><input type="checkbox" name="dav_perm%i" %s disabled="disabled"/></td>', i,  checked));
                            }
                          ?>
                        </tr>
                      </table>
                    </td>
                  </tr>
                  <tr>
                    <th>
                      <v:label for="dav_index" value="--'Full Text Search'" format="%s"/>
                    </th>
                    <td>
                      <v:select-list name="dav_index" value="-- get_keyword('dav_index', self.vc_page.vc_event.ve_params, ODRIVE.WA.DAV_GET(self.dav_item, 'freeText'))" xhtml_disabled="disabled">
                        <v:item name="Off" value="N"/>
                        <v:item name="Direct members" value="T"/>
                        <v:item name="Recursively" value="R"/>
                      </v:select-list>
                    </td>
                  </tr>
                  <tr>
                    <th>
                      <v:label for="dav_metagrab" value="--'Metadata Retrieval'" format="%s"/>
                    </th>
                    <td>
                      <v:select-list name="dav_metagrab" value="-- get_keyword('dav_metagrab', self.vc_page.vc_event.ve_params, ODRIVE.WA.DAV_GET(self.dav_item, 'metaGrab'))" xhtml_disabled="disabled">
                        <v:item name="Off" value="N"/>
                        <v:item name="Direct members" value="M"/>
                        <v:item name="Recursively" value="R"/>
                      </v:select-list>
                    </td>
                  </tr>
                  <v:template type="simple" enabled="-- case when ((self.dav_type = 'C') and (self.command_mode = 10)) then 1 else 0 end">
                    <tr>
                      <th />
                      <td valign="center">
                        <input type="checkbox" name="dav_recursive" disabled="disabled"/>
                        <b><v:label for="dav_recursive" value="--'Recursive'" format="%s"/></b>
                      </td>
                    </tr>
                  </v:template>
                  <v:template type="simple" enabled="-- gte(self.command_mode, 10)">
                    <v:template type="simple" enabled="-- equ(self.dav_type, 'R')">
                      <tr>
                        <th>
                          <v:label for="f_tag2" value="Public tags"/>
                        </th>
                        <td>
                          <v:template type="simple" enabled="--self.dav_enable">
                            <v:text name="f_tag2" null-value="''" value="-- get_keyword('f_tag2', self.vc_page.vc_event.ve_params, '')" xhtml_class="textbox" xhtml_size="20%"/>
                            <v:button action="simple" style="image" value="image/add_16.png" xhtml_alt="Add Public Tag">
                              <v:on-post>
                                <![CDATA[
                                  declare tag varchar;

                                  tag := ODRIVE.WA.tag_prepare(self.f_tag2.ufl_value);
                                  if (not ODRIVE.WA.validate_tags(tag)) {
                                    self.vc_is_valid := 0;
                                    self.vc_error_message := 'The expression is not valid tag.';
                                    return;
                                  }
                                  self.dav_tags2 := ODRIVE.WA.tags_join(self.dav_tags2, tag);
                                  self.vc_data_bind(e);
                                  self.f_tag2.ufl_value := '';
                                 ]]>
                               </v:on-post>
                            </v:button>
                          </v:template>
                          <?vsp
                            declare tmp any;
                            declare tags any;

                            tmp := 1;
                            if (isstring(self.dav_tags2)) {
                              tags := split_and_decode (self.dav_tags2, 0, '\0\0,');
                              foreach (any tag in tags) do {
                                tmp := 0;
                                http(sprintf(', <a href="#" onclick="javascript: document.forms[''F1''].f_tag2_hidden.value = ''%s''; doPost (''F1'', ''f_tag2_search''); return false;" alt="Search Public Tag" title="Search Public Tag"><b>%s</b></a>', tag, tag));
                                http(sprintf(' <a href="#" onclick="javascript: document.forms[''F1''].f_tag2_hidden.value = ''%s''; doPost (''F1'', ''f_tag2_delete''); return false;"><img src="image/del_16.png" border="0" alt="Delete Public Tag" title="Delete Public Tag" /></a>', tag));
                              }
                            }
                            if (tmp and not self.dav_enable)
                              http('None');
                          ?>
                        </td>
                      </tr>
                      <tr>
                        <th>
                          <v:label for="f_tag" value="Private tags"/>
                        </th>
                        <td>
                          <v:template type="simple" enabled="--self.dav_enable">
                            <v:text name="f_tag" null-value="''" value="-- get_keyword('f_tag', self.vc_page.vc_event.ve_params, '')" xhtml_class="textbox" xhtml_size="20%"/>
                            <v:button action="simple" style="image" value="image/add_16.png" xhtml_alt="Add Private Tag">
                              <v:on-post>
                                <![CDATA[
                                  declare tag varchar;

                                  tag := ODRIVE.WA.tag_prepare(self.f_tag.ufl_value);
                                  if (not ODRIVE.WA.validate_tags(tag)) {
                                    self.vc_is_valid := 0;
                                    self.vc_error_message := 'The expression is not valid tag.';
                                    return;
                                  }
                                  self.dav_tags := ODRIVE.WA.tags_join(self.dav_tags, tag);
                                  self.vc_data_bind(e);
                                  self.f_tag.ufl_value := '';
                                 ]]>
                               </v:on-post>
                            </v:button>
                          </v:template>
                          <?vsp
                            declare tmp any;
                            declare tags any;

                            tmp := 1;
                            if (isstring(self.dav_tags)) {
                              tags := split_and_decode (self.dav_tags, 0, '\0\0,');
                              foreach (any tag in tags) do {
                                tmp := 0;
                                http(sprintf(', <a href="#" onclick="javascript: document.forms[''F1''].f_tag_hidden.value = ''%s''; doPost (''F1'', ''f_tag_search''); return false;" alt="Search Private Tag" title="Search Private Tag"><b>%s</b></a>', tag, tag));
                                http(sprintf(' <a href="#" onclick="javascript: document.forms[''F1''].f_tag_hidden.value = ''%s''; doPost (''F1'', ''f_tag_delete''); return false;"><img src="image/del_16.png" border="0" alt="Delete Private Tag" title="Delete Private Tag" /></a>', tag));
                              }
                            }
                            if (tmp and not self.dav_enable)
                              http('None');
                          ?>
                        </td>
                      </tr>
                    </v:template>
                    <tr>
                      <th>WebDAV Properties</th>
                      <td>
                        <v:data-set name="ds_props" data="--ODRIVE.WA.DAV_PROP_LIST(self.dav_path, '%', vector('virt:%', 'http://www.openlinksw.com/schemas/%', 'http://local.virt/DAV-RDF%'))" meta="--vector('c0', 'c1')" nrows="10" scrollable="1" >

                          <v:template name="ds_props_header" type="simple" name-to-remove="table" set-to-remove="bottom">
                            <table class="form-list" style="width: 70%;" id="davProperties" cellspacing="0">
                              <tr>
                                <th>Name</th>
                                <th>Value</th>
                                <v:template type="simple" enabled="--self.dav_propEnable">
                                  <th>Action</th>
                                </v:template>
                              </tr>
                              <v:template type="simple" enabled="--self.dav_propEnable">
                                <tr>
                                  <td nowrap="nowarap">
                                    <v:select-list name="xml_name" enabled="--ODRIVE.WA.check_admin(ODRIVE.WA.session_user_id(self.vc_page.vc_event.ve_params))" xhtml_size="1" xhtml_disabled="disabled">
                                      <v:item name="xml-sql" value="xml-sql"/>
                                      <v:item name="xml-sql-root" value="xml-sql-root"/>
                                      <v:item name="xml-sql-dtd" value="xml-sql-dtd"/>
                                      <v:item name="xml-sql-schema" value="xml-sql-schema"/>
                                      <v:item name="xml-sql-description" value="xml-sql-description"/>
                                      <v:item name="xml-sql-encoding" value="xml-sql-encoding"/>
                                      <v:item name="xml-stylesheet" value="xml-stylesheet"/>
                                      <v:item name="xml-template" value="xml-template"/>
                                      <v:item name="xper" value="xper"/>
                                    </v:select-list>
                                    <v:text name="custom_name" value="--''" xhtml_disabled="disabled" xhtml_class="field-short" />
                                  </td>
                                  <td>
                                    <v:text name="xml_value"  value="--''" xhtml_disabled="disabled" xhtml_class="field-short" />
                                  </td>
                                  <td align="center">
                                    <v:button action="simple" name="add" style="image" value="image/add_16.png" xhtml_alt="Add WebDAV Property">
                                      <v:on-post>
                                        <![CDATA[
                                          declare pname, pvalue varchar;
                                          declare retValue any;

                                          pname := trim(get_keyword('custom_name', params, ''));
                                          if (pname = '')
                                            pname := get_keyword('xml_name', e.ve_params, '');
                                          if ((pname = '') or (not self.property_right(pname))) {
                                            self.vc_error_message := 'Property name is empty or prefix is not allowed!';
                                            self.vc_is_valid := 0;
                                            return;
                                          }
                                          if (not isinteger(ODRIVE.WA.DAV_PROP_GET(self.dav_path, pname))) {
                                            self.vc_error_message := sprintf('The property "%s" of "%s" already exists.\nYou may first delete existing and next add new property with same name.', pname, self.source);
                                            self.vc_is_valid := 0;
                                            return;
                                          }
                                          {
                                            declare exit handler for sqlstate '*' { goto endser; };
                                            pvalue := get_keyword('xml_value', e.ve_params, '');
                                            if (isarray (xml_tree (pvalue, 0)))
                                              pvalue := serialize(xml_tree(pvalue, 0));
                                            endser:;
                                          }
                                          retValue := ODRIVE.WA.DAV_PROP_SET(self.dav_path, pname, pvalue);
                                          if (ODRIVE.WA.DAV_ERROR(retValue)) {
                                            self.vc_error_message := ODRIVE.WA.DAV_PERROR(retValue);
                                            self.vc_is_valid := 0;
                                            return;
                                          }
                                          self.vc_data_bind(e);
                                        ]]>
                                      </v:on-post>
                                    </v:button>
                                  </td>
                                </tr>
                              </v:template>
                            </table>
                          </v:template>

                          <v:template name="ds_props_repeat" type="repeat">

                            <v:template name="ds_props_empty" type="if-not-exists" name-to-remove="table" set-to-remove="both">
                              <table>
                                <v:template type="simple" enabled="--either(equ(self.dav_propEnable,1),0,1)">
                                  <tr align="center">
                                    <td colspan="2">No properties</td>
                                  </tr>
                                </v:template>
                              </table>
                            </v:template>

                            <v:template name="ds_props_browse" type="browse" name-to-remove="table" set-to-remove="both">
                              <table>
                                <tr>
                                  <td nowrap="nowrap">
                                    <v:label value="--(control.vc_parent as vspx_row_template).te_column_value('c0')"/>
                                  </td>
                                  <td>
                                    <v:label value="--''">
                                      <v:after-data-bind>
                                        <![CDATA[
                                          control.ufl_value := (control.vc_parent as vspx_row_template).te_column_value('c1');
                                          if (length(control.ufl_value) > 60)
                                            control.ufl_value := concat(subseq(control.ufl_value, 0, 57), '...');
                                        ]]>
                                      </v:after-data-bind>
                                    </v:label>
                                  </td>
                                  <v:template type="simple" enabled="--self.dav_propEnable">
                                    <td align="center">
                                      <v:button action="simple" style="image" value="image/del_16.png" enabled="--case when self.property_right(((control.vc_parent).vc_parent as vspx_row_template).te_column_value('c0')) then 1 else 0 end"  xhtml_alt="Delete WebDAV Property">
                                        <v:on-post>
                                          <![CDATA[
                                            ODRIVE.WA.DAV_PROP_REMOVE(self.dav_path, ((control.vc_parent).vc_parent as vspx_row_template).te_column_value('c0'));
                                            self.vc_data_bind(e);
                                          ]]>
                                        </v:on-post>
                                      </v:button>
                                    </td>
                                  </v:template>
                                </tr>
                              </table>
                            </v:template>

                          </v:template>

                          <v:template type="simple" name-to-remove="table" set-to-remove="top">
                            <table>
                            </table>
                          </v:template>

                        </v:data-set>
                      </td>
                    </tr>
                  </v:template>
                </table>
              </div>

              <v:template type="simple" enabled="-- gte(self.command_mode, 10)">
                <xsl:call-template name="security-template2">
                  <xsl:with-param name="sufix" select="''"/>
                </xsl:call-template>
              </v:template>

              <v:template type="simple" enabled="-- case when (gte(self.command_mode, 10) and ODRIVE.WA.dav_rdf_has_metadata(self.dav_path)) then 1 else 0 end">
                <div id="3" class="tabContent" style="display: none;">
                  <table id="schema" class="grid" cellspacing="0">
                    <thead class="sortHeader">
                      <tr>
                        <th>
                          Schema
                        </th>
                        <th>
                          Property
                        </th>
                        <th>
                          Value
                        </th>
                      </tr>
                    </thead>
                    <?vsp
                      declare N integer;

                      for (select distinct s.* from ODRIVE.WA.dav_rdf_schema_rs(p0, p1)(MR_RDF_URI varchar) s where p0 = ODRIVE.WA.DAV_GET(self.dav_item, 'mimeType') and p1 = self.dav_metadata order by MR_RDF_URI) do {
                        N := (select count(*) from ODRIVE.WA.dav_rdf_schema_properties_rs(property0)(pID varchar, pLabel varchar, pType varchar, pDefault varchar, pOrder varchar, pAccess varchar) p where property0 = DB.DBA.DAV_GET_RDF_SCHEMA_N3(MR_RDF_URI));
                        for (select p.* from ODRIVE.WA.dav_rdf_schema_properties_rs(property0)(pID varchar, pLabel varchar, pType varchar, pDefault varchar, pOrder varchar, pAccess varchar) p where property0 = DB.DBA.DAV_GET_RDF_SCHEMA_N3(MR_RDF_URI) order by pOrder, pLabel) do {
                          http('<tr>');
                             http('<td nowrap="nowrap">');
                            if (N) {
                              http(ODRIVE.WA.rdf_schema_get_property(DB.DBA.DAV_GET_RDF_SCHEMA_N3(MR_RDF_URI), MR_RDF_URI, 'label'));
                              N := 0;
                            } else {
                              http('&nbsp;');
                            }
                            http('</td>');
                            http('<td nowrap="nowrap">');
                              http(pLabel);
                            http('</td>');
                            http('<td width="50%">');
                            declare pValue any;
                            pValue := ODRIVE.WA.dav_rdf_get_property(self.dav_metadata, pID, pDefault);
                            if (pAccess = 'read-only') {
                              http(sprintf('<input type="text" name="vmd_edit_property$0%s$0%s" value="%s"class="field-max" readonly="readonly" />', MR_RDF_URI, pID, pValue));
                            } else {
                              pType := ODRIVE.WA.rdf_n3_base_remove(pType);
                              if (pType = 'boolean')
                                http(sprintf('<select name="vmd_edit_property$0%s$0%s" disabled="disabled"><option value="No" %s>No</option><option value="Yes" %s>Yes</option></select>', MR_RDF_URI, pID, either(equ(pValue, 'No'), 'selected="selected"', ''), either(equ(pValue, 'Yes'), 'selected="selected"', '')));
                              else if (pType = 'integer')
                                http(sprintf('<input type="text" name="vmd_edit_property$0%s$0%s" value="%s"class="field-short" disabled="disabled" /> (Ex. 123)', MR_RDF_URI, pID, pValue));
                              else if (pType = 'float')
                                http(sprintf('<input type="text" name="vmd_edit_property$0%s$0%s" value="%s"class="field-short" disabled="disabled" /> (Ex. 123.45)', MR_RDF_URI, pID, pValue));
                              else if (pType = 'dateTime')
                                http(sprintf('<input type="text" name="vmd_edit_property$0%s$0%s" value="%s"class="field-short" disabled="disabled" /> (Ex. yyyy-mm-dd hh:mm)', MR_RDF_URI, pID, pValue));
                              else if (pType = 'date')
                                http(sprintf('<input type="text" name="vmd_edit_property$0%s$0%s" value="%s"class="field-short" disabled="disabled" /> (Ex. yyyy-mm-dd)', MR_RDF_URI, pID, pValue));
                              else if (pType = 'time')
                                http(sprintf('<input type="text" name="vmd_edit_property$0%s$0%s" value="%s"class="field-short" disabled="disabled" /> (Ex. hh:mm)', MR_RDF_URI, pID, pValue));
                              else
                                http(sprintf('<input type="text" name="vmd_edit_property$0%s$0%s" value="%s"class="field-max" disabled="disabled" />', MR_RDF_URI, pID, pValue));
                            }
                            http('</td>');
                           http('</tr>');
                        }
                      }
                    ?>
                  </table>
                </div>
              </v:template>

              <v:template type="simple" enabled="-- equ(self.dav_type, 'C')">
                <xsl:call-template name="search-dc-template4"/>
                <xsl:call-template name="search-dc-template5"/>
                <xsl:call-template name="search-dc-template7"/>
                <xsl:call-template name="search-dc-template8"/>
                <xsl:call-template name="search-dc-template9"/>
              </v:template>
              <v:template type="simple" enabled="-- equ(self.dav_type, 'R')">
                <xsl:call-template name="search-dc-template10"/>
              </v:template>

            </div>
          </div>
          <div class="new-form-footer">
            <v:button action="simple" name="Create" value="Create" enabled="--self.dav_enable">
              <v:before-render>
                <![CDATA[
                  if (self.command_mode >= 10)
                    control.ufl_value := 'Update';
                  else if (self.command_mode = 5)
                    control.ufl_value := 'Upload';
                  else
                    control.ufl_value := 'Create';
                ]]>
              </v:before-render>
            </v:button>
            <v:button action="simple" value="Cancel" >
              <v:on-post>
                <![CDATA[
                  self.command_pop(null);
                  self.command_acl := 0;
                  self.vc_data_bind(e);
                ]]>
              </v:on-post>
            </v:button>
          </div>
          <script>
            <![CDATA[
              if (document.F1.elements['dav_det'])
                updateLabel(document.F1.dav_det.options[document.F1.dav_det.selectedIndex].value);
              coloriseTable('davProperties');
              coloriseTable('sharings');
              coloriseTable('versions');
              coloriseTable('properties');
              coloriseTable('metaProperties');
              initDisabled();
              initTab(11, 1);
            ]]>
          </script>
        </v:template>

        <!-- Edit file -->
        <v:template type="simple" enabled="-- equ(self.command, 11)">
          <v:before-data-bind>
            <![CDATA[
              self.dav_path := ODRIVE.WA.odrive_real_resource(self.source);
              if (ODRIVE.WA.odrive_read_permission(self.dav_path))
                self.dav_content := ODRIVE.WA.DAV_RES_CONTENT(self.dav_path);
            ]]>
          </v:before-data-bind>
          <div class="new-form-header">
            <v:label value="-- concat('Edit file ', self.source)"/>
          </div>
          <v:textarea name="file_content" value="-- self.dav_content" xhtml_cols="80" xhtml_rows="28"/>
          <div class="new-form-footer">
            <v:button action="simple" value="Save" enabled="--ODRIVE.WA.odrive_write_permission(self.dav_path)">
              <v:on-post>
                <![CDATA[
                  declare retValue integer;

                  self.dav_item := ODRIVE.WA.DAV_INIT(self.dav_path);
                  retValue := ODRIVE.WA.DAV_RES_UPLOAD(self.dav_path, self.file_content.ufl_value, ODRIVE.WA.DAV_GET(self.dav_item, 'mimeType'), ODRIVE.WA.DAV_GET(self.dav_item, 'permissions'), ODRIVE.WA.DAV_GET(self.dav_item, 'ownerID'), ODRIVE.WA.DAV_GET(self.dav_item, 'groupID'));
                  if (ODRIVE.WA.DAV_ERROR(retValue)) {
                    self.vc_error_message := ODRIVE.WA.DAV_PERROR(retValue);
                    self.vc_is_valid := 0;
                    return;
                  }
                  self.command_pop(null);
                  self.vc_data_bind(e);
                ]]>
              </v:on-post>
            </v:button>
            <v:button action="simple" value="Cancel">
              <v:on-post>
                <![CDATA[
                  self.command_pop(null);
                  self.vc_data_bind(e);
                ]]>
              </v:on-post>
            </v:button>
          </div>
        </v:template>

        <!-- List files for copy, move, .... -->
        <v:template type="simple" enabled="-- case when (self.command in (20, 21, 22, 23, 24, 25)) then 1 else 0 end">
          <div class="new-form-header">
            <?vsp
              if (self.command = 20) {
                http('Operation - Copy');
              } else if (self.command = 21) {
                http('Operation - Move');
              } else if (self.command = 22) {
                http('Operation - Properties'' modification');
              } else if (self.command = 23) {
                http('Operation - Delete');
              } else if (self.command = 24) {
                http('Operation - Tagging');
              } else if (self.command = 25) {
                http('Operation - Mailing');
              }
            ?>
          </div>
          <div>
            <span class="form-info">Source</span>
          </div>
          <div class="box">
            <table id="source" class="grid" cellspacing="0">
              <thead class="sortHeader">
                <tr>
                  <th width="50%">Name</th>
                  <th>Size</th>
                  <th>Date Modified</th>
                  <th>Mime Type</th>
                  <th>Kind</th>
                  <th>Owner</th>
                  <th>Group</th>
                  <th>Permissions</th>
                  <th/>
                </tr>
              </thead>
              <?vsp
                declare i integer;
                declare item any;
                i := 0;
                while (i < length(self.item_array)) {
                  item := ODRIVE.WA.DAV_INIT(self.item_array[i]);
                  if (not ODRIVE.WA.DAV_ERROR(item)) {
              ?>
              <tr>
                <td><?vsp http(sprintf('<img src="%s" alt="%s"/>', self.ui_image(ODRIVE.WA.DAV_GET(item, 'fullPath'), ODRIVE.WA.DAV_GET(item, 'type'), ODRIVE.WA.DAV_GET(item, 'mimeType')), self.ui_alt(ODRIVE.WA.DAV_GET(item, 'name'), ODRIVE.WA.DAV_GET(item, 'type'))));
                          http('&nbsp;&nbsp;');
                          http(self.ui_name(self.item_array[i])); ?>
                </td>
                <td class="td_number"><?vsp http(self.ui_size(ODRIVE.WA.DAV_GET(item, 'length'), ODRIVE.WA.DAV_GET(item, 'type'))); ?></td>
                <td><?vsp http(self.ui_date(ODRIVE.WA.DAV_GET(item, 'modificationTime'))); ?></td>
                <td><?vsp http(either(equ(ODRIVE.WA.DAV_GET(item, 'type'), 'R'), ODRIVE.WA.DAV_GET(item, 'mimeType'), '&nbsp;')); ?></td>
                <td><?V ODRIVE.WA.DAV_GET(item, 'ownerName') ?></td>
                <td><?V ODRIVE.WA.DAV_GET(item, 'groupName') ?></td>
                <td><?V ODRIVE.WA.DAV_GET(item, 'permissionsName') ?></td>
                <td>
                  <?vsp
                    if (not is_empty_or_null(self.item_array[i+1]))
                      http(self.item_array[i+1]);
                  ?>
                </td>
              </tr>
              <?vsp
                  }
                  i := i + 2;
                }
              ?>
            </table>
          </div>

          <!-- Mass properties form -->
          <v:template type="simple" enabled="-- equ(self.command, 22)">
             <div id="c1">
              <div class="tabs">
                <vm:tabCaption tab="1" tabs="2" caption="Main"/>
                <vm:tabCaption tab="2" tabs="2" caption="Sharing"/>
              </div>
              <div class="contents">
                <div id="1" class="tabContent">
                  <table class="form-body" cellspacing="0">
                    <tr>
                      <th>
                        <v:label for="prop_mime" value="--'File Mime Type'" format="%s"/>
                      </th>
                      <td>
                        <input type="text" name="prop_mime" class="field-text"/>
                        <v:template type="simple">
                          <input type="button" value="Select" onClick="javascript:windowShow('mimes_select.vspx?params=prop_mime:s1;')" disabled="disabled" class="button"/>
                        </v:template>
                      </td>
                    </tr>
                    <tr>
                      <th>
                        <v:label for="prop_owner" value="--'Owner'" format="%s"/>
                      </th>
                      <td>
                        <v:text name="prop_owner" value="--'Do not change'" format="%s" xhtml_disabled="disabled" xhtml_class="field-short">
                          <v:after-data-bind>
                            <![CDATA[
                              if (not ODRIVE.WA.check_admin(ODRIVE.WA.session_user_id(self.vc_page.vc_event.ve_params)))
                                control.tf_style := 3;
                            ]]>
                          </v:after-data-bind>
                        </v:text>
                        <v:template type="simple" enabled="-- equ(ODRIVE.WA.check_admin(ODRIVE.WA.session_user_id(self.vc_page.vc_event.ve_params)), 1)">
                          <input type="button" value="Select" onClick="javascript:windowShow('users_select.vspx?mode=u&amp;params=prop_owner:s1;')" disabled="disabled" class="button"/>
                        </v:template>
                      </td>
                    </tr>
                    <tr>
                      <th>
                        <v:label for="prop_group" value="--'Group'" format="%s"/>
                      </th>
                      <td>
                        <v:text name="prop_group" value="--'Do not change'" format="%s" xhtml_disabled="disabled" xhtml_class="field-short"/>
                        <v:template type="simple">
                          <input type="button" value="Select" onClick="javascript:windowShow('users_select.vspx?mode=g&amp;params=prop_group:s1;')" disabled="disabled" class="button"/>
                        </v:template>
                      </td>
                    </tr>
                    <tr>
                      <th>
                        <v:label value="--'Add Permissions'" format="%s"/>
                      </th>
                      <td>
                        <table class="form-list" style="width: 1%;" cellspacing="0">
                          <xsl:call-template name="permissions-header1"/>
                          <xsl:call-template name="permissions-header2"/>
                          <tr>
                            <?vsp
                              declare i integer;
                              for (i := 0; i < 9; i := i + 1)
                                http(sprintf('<td align="center"><input type="checkbox" name="prop_add_perm%i" onClick="chkbx(this,prop_rem_perm%i);"/></td>', i, i));
                            ?>
                          </tr>
                        </table>
                      </td>
                    </tr>
                    <tr>
                      <th>
                        <v:label value="--'Remove Permissions'" format="%s"/>
                      </th>
                      <td>
                        <table class="form-list" style="width: 1%;" cellspacing="0">
                          <xsl:call-template name="permissions-header1"/>
                          <xsl:call-template name="permissions-header2"/>
                          <tr>
                            <?vsp
                              declare i integer;
                              for (i := 0; i < 9; i := i + 1)
                                http(sprintf('<td align="center"><input type="checkbox" name="prop_rem_perm%i" onClick="chkbx(this,prop_add_perm%i);"/></td>', i, i));
                            ?>
                          </tr>
                        </table>
                      </td>
                    </tr>
                    <tr>
                      <th>
                        <v:label for="prop_index" value="--'Full Text Search'" format="%s"/>
                      </th>
                      <td>
                        <v:select-list name="prop_index">
                          <v:item name="Do not change" value="*"/>
                          <v:item name="Off" value="N"/>
                          <v:item name="Direct members" value="T"/>
                          <v:item name="Recurcively" value="R"/>
                        </v:select-list>
                      </td>
                    </tr>
                    <tr>
                      <th>
                        <v:label for="prop_metagrab" value="--'Metadata Retrieval'" format="%s"/>
                      </th>
                      <td>
                        <v:select-list name="prop_metagrab">
                          <v:item name="Do not change" value="*"/>
                          <v:item name="Off" value="N"/>
                          <v:item name="Direct members" value="M"/>
                          <v:item name="Recursively" value="R"/>
                        </v:select-list>
                      </td>
                    </tr>
                    <tr>
                      <th />
                      <td valign="center">
                        <input type="checkbox" name="prop_recursive"/>
                        <v:label for="prop_recursive" value="--'Recursive'" format="%s"/>
                      </td>
                    </tr>
                    <tr>
                      <th>WebDAV Properties</th>
                      <td>
                        <table class="form-list" style="width: auto;" cellspacing="0">
                          <tr>
                            <th>Name</th>
                            <th>Value</th>
                            <th>Action</th>
                          </tr>
                          <tr>
                            <td>
                              <v:select-list name="ch_prop" enabled="--ODRIVE.WA.check_admin(ODRIVE.WA.session_user_id(self.vc_page.vc_event.ve_params))" xhtml_size="1">
                                <v:item name="---" value=""/>
                                <v:item name="xml-sql" value="xml-sql"/>
                                <v:item name="xml-sql-root" value="xml-sql-root"/>
                                <v:item name="xml-sql-dtd" value="xml-sql-dtd"/>
                                <v:item name="xml-sql-schema" value="xml-sql-schema"/>
                                <v:item name="xml-sql-description" value="xml-sql-description"/>
                                <v:item name="xml-sql-encoding" value="xml-sql-encoding"/>
                                <v:item name="xml-stylesheet" value="xml-stylesheet"/>
                                <v:item name="xml-template" value="xml-template"/>
                                <v:item name="xper" value="xper"/>
                              </v:select-list>
                              <input type="text" name="ch_prop_name"/>
                            </td>
                            <td>
                              <input type="text" name="ch_prop_value" value="" class="field-short"/>
                            </td>
                            <td>
                              <v:select-list name="ch_prop_action">
                                <v:item name="Update" value="U"/>
                                <v:item name="Remove" value="R"/>
                              </v:select-list>
                            </td>
                          </tr>
                        </table>
                      </td>
                    </tr>
                  </table>
                </div>

                <xsl:call-template name="security-template2">
                  <xsl:with-param name="sufix" select="'_properties'"/>
                </xsl:call-template>
              </div>
            </div>
            <div class="new-form-footer">
              <v:button action="simple" value="Update">
                <v:on-post>
                  <![CDATA[
                    declare I, N integer;
                    declare prop_owner, prop_group integer;
                    declare prop_mime varchar;
                    declare prop_add_perms, prop_rem_perms, prop_perms, one, zero varchar;
                    declare ch_prop, ch_prop_value, ch_prop_action varchar;
                    declare prop_acl, dav_acl any;
                    declare item, itemList any;

                    if (not ODRIVE.WA.check_admin(ODRIVE.WA.session_user_id(e.ve_params)))
                      if (get_keyword('prop_group', e.ve_params, '') <> 'Do not change')
                        if (not ODRIVE.WA.odrive_group_own(trim(get_keyword('prop_group', e.ve_params, '')))) {
                          self.vc_error_message := 'Only own groups or ''dba'' group are allowed!';
                          self.vc_is_valid := 0;
                          return;
                        }
                    prop_mime := trim(get_keyword ('prop_mime', control.vc_page.vc_event.ve_params, ''));
                    prop_owner := ODRIVE.WA.odrive_user_id(trim(get_keyword('prop_owner', e.ve_params, '')));
                    prop_group := ODRIVE.WA.odrive_user_id(trim(get_keyword('prop_group', e.ve_params, '')));

                    one := ascii('1');
                    zero := ascii('0');
                    prop_add_perms := '000000000N';
                    for (N := 0; N < 9; N := N + 1)
                      if (get_keyword(sprintf('prop_add_perm%i', N), e.ve_params, '') <> '')
                        aset(prop_add_perms, N, one);
                    prop_rem_perms := '000000000N';
                    for (N := 0; N < 9; N := N + 1)
                      if (get_keyword(sprintf('prop_rem_perm%i', N), e.ve_params, '') <> '')
                        aset(prop_rem_perms, N, one);

                    -- Changing or adding properties
                    ch_prop := trim(get_keyword ('ch_prop_name', e.ve_params, ''));
                    if (ch_prop = '')
                      ch_prop := get_keyword ('ch_prop', params, '');
                    if ((ch_prop <> '') and (not self.property_right(ch_prop))) {
                      self.vc_error_message := 'Property name is empty or prefix is not allowed!';
                      self.vc_is_valid := 0;
                      return;
                    }
                    ch_prop_value  := trim(get_keyword ('ch_prop_value', control.vc_page.vc_event.ve_params, ''));
                    {
                      declare exit handler for sqlstate '*' { goto _error; };
                      if (isarray (xml_tree (ch_prop_value, 0)))
                        ch_prop_value := serialize (xml_tree (ch_prop_value));
                    }
                  _error:
                    ch_prop_action := get_keyword ('ch_prop_action', control.vc_page.vc_event.ve_params, '');

                    prop_acl := WS.WS.ACL_PARSE(self.dav_acl);

                    I := 0;
                    while (I < length(self.item_array)) {
                      item := ODRIVE.WA.DAV_INIT(self.item_array[I]);
                      if (not ODRIVE.WA.DAV_ERROR(item)) {
                        if (prop_owner <> -1)
                          if (ODRIVE.WA.DAV_GET(item, 'ownerID') <> prop_owner)
                            ODRIVE.WA.DAV_SET(self.item_array[I], 'ownerID', prop_owner);

                        if (prop_group <> -1)
                          if (ODRIVE.WA.DAV_GET(item, 'groupID') <> prop_group)
                            ODRIVE.WA.DAV_SET(self.item_array[I], 'groupID', prop_group);

                        prop_perms := ODRIVE.WA.DAV_GET(item, 'permissions');
                        for (N := 0; N < 10; N := N + 1) {
                          if (prop_add_perms[N] = one)
                            aset(prop_perms, N, one);
                          if (prop_rem_perms[N] = one)
                            aset (prop_perms, N, zero);
                        }
                        if (get_keyword ('prop_index', params, '*') <> '*')
                          aset (prop_perms, 9, ascii (get_keyword ('prop_index', params)));
                        if (get_keyword ('prop_metagrab', params, '*') <> '*') {
                          if (length(prop_perms) < 11)
                            prop_perms := concat(prop_perms, ' ');
                          aset (prop_perms, 10, ascii (get_keyword ('prop_metagrab', params)));
                        }
                        ODRIVE.WA.DAV_SET(self.item_array[I], 'permissions', prop_perms);

                        if (ODRIVE.WA.DAV_GET(item, 'type') = 'R')
                          if ('' <> prop_mime)
                            if (ODRIVE.WA.DAV_GET(item, 'mimeType') <> prop_mime)
                              ODRIVE.WA.DAV_SET(self.item_array[I], 'mimeType', prop_mime);

                        if (ODRIVE.WA.DAV_GET(item, 'type') = 'C') {
                          if ('' <> get_keyword('prop_recursive', control.vc_page.vc_event.ve_params, '')) {
                            itemList := ODRIVE.WA.DAV_DIR_LIST(self.item_array[I], 1);
                            for (N := 0; N < length(itemList); N := N + 1)
                              if (itemList[N][1] = 'R') {
                                ODRIVE.WA.DAV_SET(itemList[N][0], 'permissions', prop_perms);
                                ODRIVE.WA.DAV_SET(itemList[N][0], 'ownerID', prop_owner);
                                ODRIVE.WA.DAV_SET(itemList[N][0], 'groupID', prop_owner);
                              }
                          }
                        }

                        -- properties
                        if (ch_prop <> '')
                          if (ch_prop_action = 'U')
                            ODRIVE.WA.DAV_PROP_SET(self.item_array[I], ch_prop, ch_prop_value);

                          else if (ch_prop_action = 'R')
                            ODRIVE.WA.DAV_PROP_REMOVE(self.item_array[I], ch_prop);

                        -- acl
                        if (length(prop_acl)) {
                          dav_acl := ODRIVE.WA.DAV_GET(item, 'acl');
                          foreach(any acl in prop_acl) do {
                            if ((ODRIVE.WA.DAV_GET(item, 'type') = 'C') or (acl[2] = 0))
                              WS.WS.ACL_ADD_ENTRY(dav_acl, acl[0], acl[3], acl[1], acl[2]);
                          }
                          ODRIVE.WA.DAV_SET(self.item_array[I], 'acl', dav_acl);
                        }
                      }
                      I := I + 2;
                    }

                    self.command_pop(null);
                    self.vc_data_bind(e);
                  ]]>
                </v:on-post>
              </v:button>
              <v:button action="simple" value="Cancel">
                <v:on-post>
                  <![CDATA[
                    self.command_pop(null);
                    self.vc_data_bind(e);
                  ]]>
                </v:on-post>
              </v:button>
            </div>
            <script>
              coloriseTable('source');
              coloriseTable('sharings');
              initEnabled();
              initTab(2, 1);
            </script>
          </v:template>

          <!-- Mass properties form -->
          <v:template type="simple" enabled="-- equ(self.command, 24)">
            <div class="contents" style="margin-top: 6px;">
              <table class="form-body" cellspacing="0">
                <tr>
                  <th>
                    <v:label for="f_tag2" value="Public tags"/>
                  </th>
                  <td>
                    <v:template type="simple" enabled="--self.dav_enable">
                      <v:text name="x_tag2" null-value="''" value="-- get_keyword('x_tag2', self.vc_page.vc_event.ve_params, '')" xhtml_class="textbox" xhtml_size="20%"/>
                      <v:button action="simple" style="image" value="image/add_16.png" xhtml_alt="Add Public Tag">
                        <v:on-post>
                          <![CDATA[
                            declare tag varchar;

                            tag := ODRIVE.WA.tag_prepare(self.x_tag2.ufl_value);
                            if (not ODRIVE.WA.validate_tags(tag)) {
                              self.vc_is_valid := 0;
                              self.vc_error_message := 'The expression is not valid tag.';
                              return;
                            }
                            self.dav_tags2 := ODRIVE.WA.tags_join(self.dav_tags2, tag);
                            self.vc_data_bind(e);
                            self.x_tag2.ufl_value := '';
                           ]]>
                         </v:on-post>
                      </v:button>
                    </v:template>
                    <?vsp
                      declare tmp any;
                      declare tags any;

                      tmp := 1;
                      if (isstring(self.dav_tags2)) {
                        tags := split_and_decode (self.dav_tags2, 0, '\0\0,');
                        foreach (any tag in tags) do {
                          tmp := 0;
                          http(sprintf(', <a href="#" onclick="javascript: document.forms[''F1''].f_tag2_hidden.value = ''%s''; doPost (''F1'', ''f_tag2_search''); return false;" alt="Search Public Tag" title="Search Public Tag"><b>%s</b></a>', tag, tag));
                          http(sprintf(' <a href="#" onclick="javascript: document.forms[''F1''].f_tag2_hidden.value = ''%s''; doPost (''F1'', ''f_tag2_delete''); return false;"><img src="image/del_16.png" border="0" alt="Delete Public Tag" title="Delete Public Tag" /></a>', tag));
                        }
                      }
                    ?>
                  </td>
                </tr>
                <tr>
                  <th>
                    <v:label for="f_tag" value="Private tags"/>
                  </th>
                  <td>
                    <v:template type="simple" enabled="--self.dav_enable">
                      <v:text name="x_tag" null-value="''" value="-- get_keyword('x_tag', self.vc_page.vc_event.ve_params, '')" xhtml_class="textbox" xhtml_size="20%"/>
                      <v:button action="simple" style="image" value="image/add_16.png" xhtml_alt="Add Private Tag">
                        <v:on-post>
                          <![CDATA[
                            declare tag varchar;

                            tag := ODRIVE.WA.tag_prepare(self.x_tag.ufl_value);
                            if (not ODRIVE.WA.validate_tags(tag)) {
                              self.vc_is_valid := 0;
                              self.vc_error_message := 'The expression is not valid tag.';
                              return;
                            }
                            self.dav_tags := ODRIVE.WA.tags_join(self.dav_tags, tag);
                            self.vc_data_bind(e);
                            self.x_tag.ufl_value := '';
                           ]]>
                         </v:on-post>
                      </v:button>
                    </v:template>
                    <?vsp
                      declare tmp any;
                      declare tags any;

                      tmp := 1;
                      if (isstring(self.dav_tags)) {
                        tags := split_and_decode (self.dav_tags, 0, '\0\0,');
                        foreach (any tag in tags) do {
                          tmp := 0;
                          http(sprintf(', <a href="#" onclick="javascript: document.forms[''F1''].f_tag_hidden.value = ''%s''; doPost (''F1'', ''f_tag_search''); return false;" alt="Search Private Tag" title="Search Private Tag"><b>%s</b></a>', tag, tag));
                          http(sprintf(' <a href="#" onclick="javascript: document.forms[''F1''].f_tag_hidden.value = ''%s''; doPost (''F1'', ''f_tag_delete''); return false;"><img src="image/del_16.png" border="0" alt="Delete Private Tag" title="Delete Private Tag" /></a>', tag));
                        }
                      }
                      if (tmp and not self.dav_enable)
                        http('None');
                    ?>
                  </td>
                </tr>
              </table>
            </div>
            <div class="new-form-footer">
              <v:button action="simple" value="Tag">
                <v:on-post>
                  <![CDATA[
                    declare I, N integer;
                    declare tags any;

                    while (I < length(self.item_array)) {
                      if (self.dav_tags <> '') {
                        tags := ODRIVE.WA.DAV_PROP_GET(self.item_array[I], ':virtprivatetags');
                        ODRIVE.WA.DAV_SET(self.item_array[I], 'privatetags', ODRIVE.WA.tags_join(tags, self.dav_tags));
                      }
                      if (self.dav_tags2 <> '') {
                        tags := ODRIVE.WA.DAV_PROP_GET(self.item_array[I], ':virtpublictags');
                        ODRIVE.WA.DAV_SET(self.item_array[I], 'publictags', ODRIVE.WA.tags_join(tags, self.dav_tags2));
                      }
                      I := I + 2;
                    }

                    self.command_pop(null);
                    self.vc_data_bind(e);
                  ]]>
                </v:on-post>
              </v:button>
              <v:button action="simple" value="Cancel">
                <v:on-post>
                  <![CDATA[
                    self.command_pop(null);
                    self.vc_data_bind(e);
                  ]]>
                </v:on-post>
              </v:button>
            </div>
          </v:template>

          <!-- Mass properties form -->
          <v:template type="simple" enabled="-- equ(self.command, 25)">
            <div class="contents" style="margin-top: 6px;">
              <table class="form-body" cellspacing="0">
                <tr>
                  <th>
                    <v:label for="f_tag2" value="Public tags"/>
                  </th>
                  <td>ffff
                  </td>
                </tr>
                <tr>
                  <th>
                    <v:label for="f_tag" value="Private tags"/>
                  </th>
                  <td>fff
                  </td>
                </tr>
              </table>
            </div>
            <div class="new-form-footer">
              <v:button action="simple" value="Mail">
                <v:on-post>
                  <![CDATA[
                    declare I, N integer;
                    declare tags any;

                    while (I < length(self.item_array)) {
                      if (self.dav_tags <> '') {
                        tags := ODRIVE.WA.DAV_PROP_GET(self.item_array[I], ':virtprivatetags');
                        ODRIVE.WA.DAV_SET(self.item_array[I], 'privatetags', ODRIVE.WA.tags_join(tags, self.dav_tags));
                      }
                      if (self.dav_tags2 <> '') {
                        tags := ODRIVE.WA.DAV_PROP_GET(self.item_array[I], ':virtpublictags');
                        ODRIVE.WA.DAV_SET(self.item_array[I], 'publictags', ODRIVE.WA.tags_join(tags, self.dav_tags2));
                      }
                      I := I + 2;
                    }

                    self.command_pop(null);
                    self.vc_data_bind(e);
                  ]]>
                </v:on-post>
              </v:button>
              <v:button action="simple" value="Cancel">
                <v:on-post>
                  <![CDATA[
                    self.command_pop(null);
                    self.vc_data_bind(e);
                  ]]>
                </v:on-post>
              </v:button>
            </div>
          </v:template>

          <!-- Confirm operation - delete or override -->
          <v:template type="simple" enabled="-- case when (self.need_overwrite = 1 and (length(self.item_array) > 0) or self.command = 23) then 1 else 0 end">
            <v:template type="simple" enabled="-- case when (self.need_overwrite = 1 and (length(self.item_array) > 0)) then 1 else 0 end">
              <div class="form-info" style="border-bottom-width: 1px;">
                <?vsp
                  if (self.command = 20 or self.command = 21)
                    http('Some folder(s)/file(s) could not to be written or have to overwrite existing ones. Do you want to try to overwrite?');
                  if (self.command = 23)
                    http('The selected folder(s)/file(s) can not be removed. Do you want to try again?');
                ?>
              </div>
            </v:template>
            <div class="new-form-footer">
              <v:button value="OK" action="simple">
                <v:on-post>
                  <![CDATA[
                    self.execute_command(1);
                    self.vc_data_bind(e);
                  ]]>
                </v:on-post>
              </v:button>
              <v:button value="Cancel" action="simple">
                <v:on-post>
                  <![CDATA[
                    self.command_pop(null);
                    self.vc_data_bind(e);
                  ]]>
                </v:on-post>
              </v:button>
            </div>
          </v:template>

          <v:template type="simple" enabled="-- case when (self.command in (20, 21)) then 1 else 0 end">
            <div style="margin-top: 0.5em;">
              <span class="form-info">Target</span>
            </div>
          </v:template>
        </v:template>

        <!-- Header -->
        <v:template type="simple" enabled="-- case when ((self.dir_select = 1) or ((self.command in (0)) and (self.command_mode in (0, 1)))) then 1 else 0 end">
          <div class="boxHeader">
            <b><v:label for="path" value="' Path '" /></b>
            <v:text name="path" value="--ODRIVE.WA.utf2wide(ODRIVE.WA.path_show(self.dir_path))" xhtml_onkeypress="return submitEnter(\'F1\', \'GO_Path\', event)" xhtml_id="path" xhtml_size="60"/>
            <v:button name="GO_Path" action="simple" style="image" value="image/go_16.png" xhtml_alt="Go">
              <v:on-post>
                <![CDATA[
                  self.path.ufl_value := ODRIVE.WA.path_show(self.path.ufl_value);
                  if (not ODRIVE.WA.path_is_shortcut(self.path.ufl_value)) {
                    declare tmp any;

                    tmp := ODRIVE.WA.odrive_real_path(self.path.ufl_value);
                    if (ODRIVE.WA.DAV_ERROR(DB.DBA.DAV_SEARCH_ID(tmp, 'C'))) {
                      self.vc_error_message := concat('Can not find the folder with name ', ODRIVE.WA.odrive_refine_path(self.path.ufl_value));
                      self.vc_is_valid := 0;
                      return;
                    }
                    if ((not ODRIVE.WA.check_admin(ODRIVE.WA.session_user_id(e.ve_params))) and isnull(strstr(tmp, ODRIVE.WA.odrive_dav_home()))) {
                      self.vc_error_message := 'The path must be part of your home directory';
                      self.vc_is_valid := 0;
                      return;
                    }
                  }

                  self.dir_path := self.path.ufl_value;
                  self.ds_items.vc_reset();
                  self.vc_data_bind(e);
                ]]>
              </v:on-post>
            </v:button>
            <b><v:label for="list_type" value="' View '" /></b>
            <v:select-list name="list_type" value="--self.dir_details" xhtml_onchange="javascript:doPost(\'F1\', \'reload\'); return false">
              <v:item name="Details" value="0"/>
              <v:item name="List" value="1"/>
            </v:select-list>
            <v:template type="simple" enabled="-- case when ((self.command in (0)) and (self.command_mode in (0,1))) then 1 else 0 end">
              <b><v:label for="filter" value="--' Display Filter Pattern '" format="%s"/></b>
              <v:text name="filter" xhtml_id="filter" value="--self.search_filter" type="simple"/>
              <v:button action="simple" style="image" value="image/filter_16.png" xhtml_alt="Filter">
                <v:on-post>
                  <![CDATA[
                    self.command_set(0, 1);
                    self.search_filter := self.filter.ufl_value;
                    self.vc_data_bind(e);
                  ]]>
                </v:on-post>
              </v:button>
              <v:button action="simple" style="image" value="image/cancl_16.png" xhtml_alt="Cancel Filter">
                <v:on-post>
                  <![CDATA[
                    self.command_set(0, 1);
                    self.search_filter := '';
                    self.vc_data_bind(e);
                  ]]>
                </v:on-post>
              </v:button>
            </v:template>
          </div>
        </v:template>

        <!-- Browser -->
        <v:template type="simple" enabled="-- case when (self.command in (20, 21) or (((self.command = 0) and (self.command_mode <> 3)) or ((self.command = 0) and (self.command_mode = 3) and (not isnull(self.search_advanced))))) then 1 else 0 end">

          <v:text name="tag_hidden" type="hidden" value="" />
          <?vsp
            if (0)
            {
          ?>
              <v:button name="tag_search" action="simple" style="url" value="Submit">
                <v:on-post>
                  <![CDATA[
                    declare tag, tags, tagType any;

                    tag := get_keyword ('tag_hidden', e.ve_params, '');
                    tagType := 'public';
                    if (not isnull(strstr(tag, '#_'))) {
                      tag := replace(tag,  '#_', '');
                      tagType := 'private';
                    }
                    if (self.command_mode < 2) {
                      self.command_set(0, 3);
                      ODRIVE.WA.dav_dc_set_base(self.search_dc, 'path', ODRIVE.WA.odrive_real_path(self.dir_path));
                      ODRIVE.WA.dav_dc_set_base(self.search_dc, 'name', trim(self.simple.ufl_value));
                    } else {
                      self.command_mode := 3;
                    }
                    tags := ODRIVE.WA.dav_dc_get(self.search_dc, 'advanced', concat(tagType, 'Tags12'), '');
                    if (is_empty_or_null(tags)) {
                      tags := tag;
                    } else if (isnull(strstr(tags, tag))) {
                      tags := concat(tags, ', ', tag);
                    }
                    ODRIVE.WA.dav_dc_set_advanced(self.search_dc, concat(tagType, 'Tags11'), 'contains_tags');
                    ODRIVE.WA.dav_dc_set_advanced(self.search_dc, concat(tagType, 'Tags12'), tags);
                    self.search_advanced := self.search_dc;
                    self.vc_data_bind(e);
                  ]]>
                </v:on-post>
              </v:button>
          <?vsp
            }
          ?>

          <v:data-source name="dsrc_items" expression-type="sql" nrows="--ODRIVE.WA.odrive_settings_rows(self.vc_page.vc_event.ve_params)" initial-offset="0">
            <v:before-data-bind>
              <![CDATA[
                self.sortChange(get_keyword('sortColumn', self.vc_page.vc_event.ve_params, ''));
                control.ds_parameters := null;
                control.add_parameter(self.dir_path);
                control.add_parameter(self.dir_select);
                control.add_parameter(self.command_mode);
                if (self.command_mode = 1) {
                  control.add_parameter(self.search_filter);
                } if (self.command_mode = 2) {
                  control.add_parameter(self.search_simple);
                } if (self.command_mode = 3) {
                  control.add_parameter(self.search_advanced);
                } else {
                  control.add_parameter(null);
                }
                control.ds_sql := 'select rs.* from ODRIVE.WA.odrive_proc(rs0, rs1, rs2, rs3)(c0 varchar, c1 varchar, c2 integer, c3 varchar, c4 varchar, c5 varchar, c6 varchar, c7 varchar, c8 varchar, c9 varchar) rs where rs0 = ? and rs1 = ? and rs2 = ? and rs3 = ?';
                control.ds_sql := concat(control.ds_sql, ' order by c1');
                if (self.dir_details = 0) {
                  declare dir_order, dir_grouping any;

                  dir_order := self.getColumn(self.dir_order);
                  dir_grouping := self.getColumn(self.dir_grouping);
                  if (not is_empty_or_null(dir_grouping))
                    control.ds_sql := concat(control.ds_sql, ', ', dir_grouping[1]);
                  if (not is_empty_or_null(dir_order))
                    control.ds_sql := concat(control.ds_sql, ', ', dir_order[1], ' ', self.dir_direction);
                } else {
                  control.ds_sql := concat(control.ds_sql, ', c0');
                }
                self.dir_tags := vector();
                if (self.dir_cloud = 1) {
                  declare state, msg, meta, result any;

                  state := '00000';
                  exec(control.ds_sql, state, msg, control.ds_parameters, 0, meta, result);
                  if (state = '00000') {
                    declare I, N integer;
                    declare tag_object, tags, tags_dict any;

                    tags_dict := dict_new();
                    for (N := 0; N < length(result); N := N + 1) {
                      tags := ODRIVE.WA.DAV_PROP_GET(result[N][8], ':virtpublictags', '');
                      tags := split_and_decode (tags, 0, '\0\0,');
                      foreach (any tag in tags) do {
                        tag_object := dict_get(tags_dict, lcase(tag), vector(lcase(tag), 0, ''));
                        tag_object[1] := tag_object[1] + 1;
                        dict_put(tags_dict, lcase(tag), tag_object);
                      }
                      tags := ODRIVE.WA.DAV_PROP_GET(result[N][8], ':virtprivatetags', '');
                      tags := split_and_decode (tags, 0, '\0\0,');
                      foreach (any tag in tags) do {
                        tag_object := dict_get(tags_dict, lcase(tag), vector(lcase(tag), 0, '#_'));
                        tag_object[1] := tag_object[1] + 1;
                        dict_put(tags_dict, lcase(tag), tag_object);
                      }
                    }
                    for (select p.* from ODRIVE.WA.tagsDictionary2rs(p0)(c0 varchar, c1 integer, c2 varchar) p where p0 = tags_dict order by c0) do
                      self.dir_tags := vector_concat(self.dir_tags, vector(vector(c0, c1, c2)));
                  }
                }
              ]]>
            </v:before-data-bind>
            <v:after-data-bind>
              <![CDATA[
                declare row_data any;

                row_data := control.ds_row_data;
                if ((length(row_data) = 1) and (row_data[0][1] <> 'R') and (row_data[0][1] <> 'C')) {
                  if (row_data[0][0] = '37000') {
                    self.vc_error_message := 'Text search expression syntax error!';
                  } else {
                    self.vc_error_message := sprintf('Search error: %s!', row_data[0][0]);
                  }
                  self.vc_is_valid := 0;
                }
              ]]>
            </v:after-data-bind>
          </v:data-source>

          <v:template type="simple" enabled="-- case when ((self.command = 0) and ((self.command_mode = 2) or ((self.command_mode = 3) and (not isnull(self.search_advanced)))) and length(self.dsrc_items.ds_row_data)) then 1 else 0 end;">
            <div style="padding-bottom: 5px;">
              <?vsp
        			  http(sprintf('<a href="export.vspx?sid=%s&realm=%s&output=rss%s"><img src="image/rss-icon-16.gif" border="0" title="RSS 2.0" alt="RSS 2.0"/> RSS</a>&nbsp;&nbsp;', self.sid, self.realm, self.do_url()));
                if (ODRIVE.WA.odrive_settings_atomVersion(self.vc_page.vc_event.ve_params) = '1.0') {
        			    http(sprintf('<a href="export.vspx?sid=%s&realm=%s&output=atom10%s"><img src="image/blue-icon-16.gif" border="0" title="Atom 1.0" alt="Atom 1.0"/> Atom</a>&nbsp;&nbsp;', self.sid, self.realm, self.do_url()));
        			  } else {
        			    http(sprintf('<a href="export.vspx?sid=%s&realm=%s&output=atom03%s"><img src="image/blue-icon-16.gif" border="0" title="Atom 0.3" alt="Atom 0.3"/> Atom</a>&nbsp;&nbsp;', self.sid, self.realm, self.do_url()));
        			  }
        			  http(sprintf('<a href="export.vspx?sid=%s&realm=%s&output=rdf%s"><img src="image/rdf-icon-16.gif" border="0" title="RDF 1.0" alt="RDF 1.0"/> RDF</a>&nbsp;&nbsp;', self.sid, self.realm, self.do_url()));
        			  http(sprintf('<a href="export.vspx?sid=%s&realm=%s&output=xbel%s"><img src="image/blue-icon-16.gif" border="0" title="XBEL" alt="XBEL"/> XBEL</a>&nbsp;&nbsp;', self.sid, self.realm, self.do_url()));
        			?>
            </div>
          </v:template>

          <table class="box" cellspacing="0">
            <tr>
              <td width="80%" valign="top" style="border: solid #7F94A5;  border-width: 1px 1px 1px 1px;">
                <div style="overflow: auto; height: 360px;">
                  <v:data-set name="ds_items" data-source="self.dsrc_items" scrollable="1">
                    <v:after-data-bind>
                      <![CDATA[
                        if (self.vc_is_valid = 0) {
                          control.ds_row_data := vector();
                          control.ds_rows_fetched := 0;
                          control.ds_rows_total := 0;
                        }
                      ]]>
                    </v:after-data-bind>
                    <v:template name="ds_items_header" type="simple" name-to-remove="table" set-to-remove="bottom">
                      <table id="dir" class="grid no-border" cellspacing="0">
                        <thead class="sortHeader">

                          <v:template type="simple" enabled="-- equ(self.dir_details, 0)">
                            <tr>
                              <?vsp
                                if ((self.dir_select = 0) and (self.dir_path <> '')) {
                                  http('<th style="text-align: left; padding-top: 0; padding-bottom: 0">');
                                  if (self.command_mode in (2,3))
                                    http('<input type="checkbox" name="selectall" value="Select All" onClick="selectAllCheckboxes(this.form, this)"/>');
                                  http('</th>');
                                }
                              ?>
                              <?vsp self.showColumnHeader('column_#1'); ?>
                              <?vsp self.showColumnHeader('column_#2'); ?>
                              <?vsp self.showColumnHeader('column_#3'); ?>
                              <?vsp self.showColumnHeader('column_#4'); ?>
                              <?vsp self.showColumnHeader('column_#5'); ?>
                              <?vsp self.showColumnHeader('column_#6'); ?>
                              <?vsp self.showColumnHeader('column_#7'); ?>
                              <?vsp self.showColumnHeader('column_#8'); ?>
                              <?vsp self.showColumnHeader('column_#9'); ?>
                              <th nowrap="nowrap">
                                Actions
                              </th>
                            </tr>
                          </v:template>
                        </thead>

                        <v:template type="simple" enabled="-- case when ((ODRIVE.WA.path_compare(self.dir_path, ODRIVE.WA.shared_name()) = 0) and (ODRIVE.WA.path_compare(self.dir_path, ODRIVE.WA.odrive_dav_home()) = 0) and (((self.command in (0)) and (self.command_mode in (0,1))) or (self.command in (20, 21)))) then 1 else 0 end">
                          <tr>
                            <v:template type="simple" enabled="-- equ(self.dir_select, 0)">
                              <td class="td_image">
                                <input type="checkbox" name="selectall" value="Select All" onClick="selectAllCheckboxes(this.form, this)"/>
                              </td>
                            </v:template>
                            <td>
                              <v:button action="simple" style="image" value="image/dav/up_16.png" text="&nbsp;&nbsp;.." format="%s" xhtml_title="Up one level">
                                <v:on-post>
                                  <![CDATA[
                                    if (trim(self.dir_path, '/') = trim(ODRIVE.WA.odrive_dav_home(), '/')) {
                                      self.dir_path := '';
                                    } else {
                                      declare pos integer;

                                      pos := strrchr(self.dir_path, '/');
                                      if (isnull(pos))
                                        pos := 0;
                                      self.dir_path := left(self.dir_path, pos);
                                    }
                                    self.ds_items.vc_reset();
                                    self.vc_data_bind(e);
                                  ]]>
                                </v:on-post>
                              </v:button>
                            </td>
                            <v:template type="simple" enabled="-- equ(self.dir_details, 0)">
                              <td colspan="8">&nbsp;</td>
                            </v:template>
                            <v:template type="simple" enabled="-- equ(self.dir_details, 1)">
                              <td>&nbsp;</td>
                            </v:template>
                          </tr>
                        </v:template>
                      </table>
                    </v:template>

                    <v:template name="ds_items_repeat" type="repeat">

                      <v:template name="ds_empty" type="if-not-exists" name-to-remove="table" set-to-remove="both">
                        <?vsp
                          if ((self.command = 0) and ((self.command_mode = 2) or (self.command_mode = 3)))
                            http('<tr align="center"><td colspan="11" valign="middle" height="100px"><b>No resources were found in ODS Briefcase that matched your search.<br />Please refine your search or enter new search criteria.</b></td></tr>');
                        ?>
                      </v:template>

                      <v:template name="ds_items_browse" type="browse" name-to-remove="table" set-to-remove="both">
                        <table>
                          <v:template type="simple" enabled="-- case when (self.dir_grouping <> '') then 1 else 0 end;">
                            <?vsp
                              declare tmp, dir_column any;

                              dir_column := self.getColumn(self.dir_grouping);
                              tmp := (control.vc_parent as vspx_row_template).te_column_value(dir_column[1]);

                              if (is_empty_or_null(self.dir_groupName) or (self.dir_groupName <> tmp)) {
                            ?>
                            <tr>
                              <td colspan="11">
                                <?vsp http(sprintf('<b> %s: %s</b>', dir_column[2], cast(tmp as varchar))); ?>
                              </td>
                            </tr>
                            <?vsp
                              }
                              self.dir_groupName := tmp;
                            ?>
                          </v:template>
                          <tr>
                            <?vsp
                              declare rowset any;
                              rowset := (control as vspx_row_template).te_rowset;

                              if ((self.dir_select = 0) and (self.dir_path <> ''))
                                http(sprintf('<td class="td_image"><input type="checkbox" name="CB_%s"/></td>', rowset[8]));
                            ?>
                            <td nowrap="nowrap">
                              <v:button action="simple" style="image" value="''" text="''" format="%s" xhtml_title="--ODRIVE.WA.utf2wide((control.vc_parent as vspx_row_template).te_rowset[0])">
                                <v:before-data-bind>
                                  <![CDATA[
                                    declare rowset any;
                                    rowset := ((control.vc_parent) as vspx_row_template).te_rowset;
                                    control.ufl_value := self.ui_image(rowset[8], rowset[1], rowset[4]);
                                    control.bt_text := concat('&nbsp;&nbsp;', self.ui_name(rowset[0]));
                                  ]]>
                                </v:before-data-bind>
                                <v:on-post>
                                  <![CDATA[
                                    if (ODRIVE.WA.odrive_permission((control.vc_parent as vspx_row_template).te_rowset[8]) = '') {
                                      self.vc_error_message := 'You have not rights to read this folder/file!';
                                      self.vc_is_valid := 0;
                                      self.vc_data_bind(e);
                                      return;
                                    }

                                    if ((control.vc_parent as vspx_row_template).te_rowset[1] = 'C') {
                                      if (self.dir_path <> '')
                                        self.dir_path := concat(self.dir_path, '/');
                                      self.dir_path := concat(self.dir_path, (control.vc_parent as vspx_row_template).te_rowset[0]);
                                    } else {
                                      http_request_status ('HTTP/1.1 302 Found');
                                      http_header (sprintf('Location: view_file.vsp?sid=%s&realm=%s&file=%U\r\n', self.sid , self.realm, (control.vc_parent as vspx_row_template).te_rowset[8]));
                                    }
                                    self.ds_items.vc_reset();
                                    self.vc_data_bind(e);
                                  ]]>
                                </v:on-post>
                              </v:button>
                              <v:template type="simple" enabled="-- case when (self.command_mode <> 3 or is_empty_or_null(ODRIVE.WA.dav_dc_get(self.search_dc, 'base', 'content'))) then 0 else 1 end">
                                <br /><i><v:label value="--ODRIVE.WA.content_excerpt((((control.vc_parent).vc_parent as vspx_row_template).te_rowset[8]), ODRIVE.WA.dav_dc_get(self.search_dc, 'base', 'content'))" format="%s"/></i>
                              </v:template>
                            </td>
                            <v:template type="simple" enabled="-- case when (self.enabledColumn('column_#2')) then 1 else 0 end;">
                              <td nowrap="nowrap">
                                <?vsp
                                  declare N integer;
                                  declare tags any;

                                  N := 0;
                                  tags := ODRIVE.WA.DAV_PROP_GET((control.vc_parent as vspx_row_template).te_rowset[8], ':virtpublictags');
                                  if (isstring(tags)) {
                                    tags := split_and_decode (tags, 0, '\0\0,');
                                    foreach (any tag in tags) do {
                                      N := N + length(tag);
                                      if (N < 20)
                                        http(sprintf('<a href="#" onclick="javascript: document.forms[''F1''].tag_hidden.value = ''%s''; doPost (''F1'', ''tag_search''); return false;" alt="Search Public Tag" title="Search Public Tag">%s</a> ', tag, tag));
                                      N := N + 1;
                                    }
                                  }
                                  tags := coalesce(ODRIVE.WA.DAV_PROP_GET((control.vc_parent as vspx_row_template).te_rowset[8], ':virtprivatetags'), '');
                                  if (isstring(tags)) {
                                    tags := split_and_decode (tags, 0, '\0\0,');
                                    foreach (any tag in tags) do {
                                      N := N + length(tag);
                                      if (N < 20)
                                        http(sprintf('<a href="#" onclick="javascript: document.forms[''F1''].tag_hidden.value = ''#_%s''; doPost (''F1'', ''tag_search''); return false;" alt="Search Private Tag" title="Search Private Tag">%s</a> ', tag, tag));
                                      N := N + 1;
                                    }
                                  }
                                ?>
                              </td>
                            </v:template>
                            <v:template type="simple" enabled="-- case when (self.enabledColumn('column_#3')) then 1 else 0 end;">
                              <td class="td_number" nowrap="nowrap">
                                <v:label>
                                  <v:before-data-bind>
                                    <![CDATA[
                                      control.ufl_value := self.ui_size((((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[2], (((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[1]);
                                    ]]>
                                  </v:before-data-bind>
                                </v:label>
                              </td>
                            </v:template>
                            <v:template type="simple" enabled="-- case when (self.enabledColumn('column_#4')) then 1 else 0 end;">
                              <td nowrap="nowrap">
                                <v:label value="--left((((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[3], 10)" format="%s"/>
                                <font size="1">
                                  <v:label value="--right((((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[3], 8)" format="%s"/>
                                </font>
                              </td>
                            </v:template>
                            <v:template type="simple" enabled="-- case when (self.enabledColumn('column_#5')) then 1 else 0 end;">
                              <td nowrap="nowrap">
                                <v:label value="--either(equ((((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[1], 'R'), (((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[4], ' ')" format="%s"/>
                              </td>
                            </v:template>
                            <v:template type="simple" enabled="-- case when (self.enabledColumn('column_#6')) then 1 else 0 end;">
                              <td nowrap="nowrap">
                                <v:label value="--either(equ((((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[1], 'R'), (((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[9], ' ')" format="%s"/>
                              </td>
                            </v:template>
                            <v:template type="simple" enabled="-- case when (self.enabledColumn('column_#7')) then 1 else 0 end;">
                              <td nowrap="nowrap">
                                <v:label value="--(((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[5]" format="%s"/>
                              </td>
                            </v:template>
                            <v:template type="simple" enabled="-- case when (self.enabledColumn('column_#8')) then 1 else 0 end;">
                              <td nowrap="nowrap">
                                <v:label value="--(((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[6]" format="%s"/>
                              </td>
                            </v:template>
                            <v:template type="simple" enabled="-- case when (self.enabledColumn('column_#9')) then 1 else 0 end;">
                              <td nowrap="nowrap">
                                <v:label value="--(((control.vc_parent).vc_parent) as vspx_row_template).te_rowset[7]" format="%s"/>
                              </td>
                            </v:template>
                            <td nowrap="nowrap">
                              <v:button style="image" action="simple" value="image/dav/item_prop.png" enabled="--ODRIVE.WA.odrive_read_permission((control.vc_parent as vspx_row_template).te_rowset[8])" xhtml_title="Properties">
                                <v:on-post>
                                  <![CDATA[
                                    self.source := (control.vc_parent as vspx_row_template).te_rowset[8];
                                    self.command_push(10, 10);
                                    self.vc_data_bind(e);
                                  ]]>
                                </v:on-post>
                              </v:button>
                              <xsl:if test="@view = 'popup'">
                                <v:button style="url" action="simple" value="view" format="%s" enabled="--ODRIVE.WA.odrive_read_permission((control.vc_parent as vspx_row_template).te_rowset[8])" xhtml_title="View">
                                  <v:on-post>
                                    <![CDATA[
                                      http_request_status('HTTP/1.1 302 Found');
                                      http_header(sprintf('Location: view_file.vsp?sid=%s&realm=%s&path=%s&file=%s\r\n', self.sid ,self.realm, ODRIVE.WA.odrive_real_path(self.dir_path), (control.vc_parent as vspx_row_template).te_rowset[1]));
                                    ]]>
                                  </v:on-post>
                                </v:button>
                              </xsl:if>
                              <?vsp
                                if  ((control as vspx_row_template).te_rowset[0] like '%.vsp'
                                  or (control as vspx_row_template).te_rowset[0] like '%.vspx'
                                  or (control as vspx_row_template).te_rowset[0] like '%.rdf'
                                  or (control as vspx_row_template).te_rowset[0] like '%.xml'
                                  or (control as vspx_row_template).te_rowset[0] like '%.xsl'
                                  or (control as vspx_row_template).te_rowset[0] like '%.js'
                                  or (control as vspx_row_template).te_rowset[0] like '%.txt'
                                  or (control as vspx_row_template).te_rowset[0] like '%.html'
                                  or (control as vspx_row_template).te_rowset[0] like '%.htm'
                                  or (control as vspx_row_template).te_rowset[0] like '%.sql'
                                  or (control as vspx_row_template).te_rowset[0] like '%.ini'
                                  or (control as vspx_row_template).te_rowset[4] like 'text/%')
                                {
                              ?>
                              <v:button style="image" action="simple" value="image/dav/item_edit.png" enabled="--ODRIVE.WA.det_action_enable((control.vc_parent as vspx_row_template).te_rowset[8], 'edit')" xhtml_title="Edit">
                                <v:on-post>
                                  <![CDATA[
                                    self.source := (control.vc_parent as vspx_row_template).te_rowset[8];
                                    self.command_push(11, 0);
                                    self.vc_data_bind(e);
                                  ]]>
                                </v:on-post>
                              </v:button>
                              <?vsp
                                }
                              ?>
                          </td>
                        </tr>
                      </table>
                      </v:template>

                    </v:template>

                    <v:template type="simple" name-to-remove="table" set-to-remove="top">
                      <table>
                        <tr class="nocolor" align="center">
                          <td colspan="11">
                            <vm:ds-navigation data-set="ds_items"/>
                          </td>
                        </tr>
                      </table>
                    </v:template>

                  </v:data-set>
                  <script>
                    <![CDATA[
                      coloriseTable('dir');
                    ]]>
                  </script>
                </div>
              </td>
              <v:template type="simple" enabled="-- case when ((self.command = 0) and (self.command_mode = 3) and (self.dir_cloud = 1)) then 1 else 0 end;">
                <td width="20%" valign="top" style="border: solid #7F94A5;  border-width: 1px 1px 1px 0px;">
                  <div style="margin-left:3px; margin-top:3px; overflow: auto; height: 360px;">
                    <?vsp
                      declare N, ts_max, ts_size integer;

                      ts_max := length(self.dir_tags);
                      for (N := 0; N < ts_max; N := N + 1) {
                        ts_size := (250.00 / ts_max) * self.dir_tags[N][1];
                        if (ts_size < 100)
                          ts_size := 100;
                        http (sprintf ('<a href="#" onclick="javascript: document.forms[''F1''].tag_hidden.value = ''%s%s''; doPost (''F1'', ''tag_search''); return false;" name="btn_%s"><span class="nolink_b" style="font-size: %d%s;">%s</span></a> ', self.dir_tags[N][2], self.dir_tags[N][0], self.dir_tags[N][0], ts_size, '%', self.dir_tags[N][0]));
                      }
                      if (ts_max = 0)
                        http ('no tags');
                    ?>
                    &nbsp;
                  </div>
                </td>
              </v:template>
            </tr>
          </table>
        </v:template>

        <v:template type="simple" enabled="-- case when (self.command in (20, 21)) then 1 else 0 end">
          <div class="boxHeader">
            <v:label for="t_dest" value="--'Destination folder '" format="%s"/>
            <v:text name="t_dest" value="--ODRIVE.WA.path_show(self.dir_path)" xhtml_id="t_dest" format="%s" xhtml_size="60"/>
            <v:button value="--(case self.command when 20 then 'Copy' when 21 then 'Move' end)" action="simple" xhtml_class="button">
              <v:on-post>
                <![CDATA[
                  self.execute_command(0);
                  self.vc_data_bind(e);
                ]]>
              </v:on-post>
            </v:button>
            <v:button value="Cancel" action="simple" xhtml_class="button">
              <v:on-post>
                <![CDATA[
                  self.command_pop(null);
                  self.vc_data_bind(e);
                ]]>
              </v:on-post>
            </v:button>
          </div>
        </v:template>
      </v:form>
    </v:template>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="permissions-header1">
    <tr>
      <th colspan="3" align="center">User</th>
      <th colspan="3" align="center">Group</th>
      <th class="last" colspan="3" align="center">Other</th>
    </tr>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="permissions-header2">
    <tr>
      <td style="border-width: 0px 1px 1px 0px;" align="center">r</td>
      <td style="border-width: 0px 1px 1px 0px;" align="center">w</td>
      <td style="border-width: 0px 1px 1px 0px;" align="center">x</td>
      <td style="border-width: 0px 1px 1px 0px;" align="center">r</td>
      <td style="border-width: 0px 1px 1px 0px;" align="center">w</td>
      <td style="border-width: 0px 1px 1px 0px;" align="center">x</td>
      <td style="border-width: 0px 1px 1px 0px;" align="center">r</td>
      <td style="border-width: 0px 1px 1px 0px;" align="center">w</td>
      <td style="border-width: 0px 0px 1px 0px;" align="center">x</td>
    </tr>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="security-template2">
    <xsl:param name="sufix"/>
    <div id="2" class="tabContent" style="display: none;">
      <v:template type="simple" enabled="-- equ(self.command_acl, 0)">
        <v:template type="simple" enabled="--self.dav_enable">
          <div style="padding: 0 0 0.5em 0;">
            <v:button action="simple" value="Add sharing(s)" xhtml_disabled="disabled" xhtml_class="button">
              <v:on-post>
                <![CDATA[
                  self.ace := vector(-2, 0, 6, 0);
                  self.command_acl := 1;
                  self.vc_data_bind(e);
                ]]>
              </v:on-post>
            </v:button>
          </div>
        </v:template>
        <v:data-set nrows="10" scrollable="1">
          <xsl:attribute name="sql"><xsl:value-of select="concat('select rs.* from ODRIVE.WA.odrive_acl_proc(rs0)(c0 integer, c1 integer, c2 integer, c3 integer) rs where rs0 = :param_acl', $sufix)"/></xsl:attribute>
          <xsl:attribute name="name"><xsl:value-of select="concat('ds_acl', $sufix)"/></xsl:attribute>
          <v:param value="self.dav_acl">
            <xsl:attribute name="name"><xsl:value-of select="concat('param_acl', $sufix)"/></xsl:attribute>
          </v:param>
          <v:template type="simple" name-to-remove="table" set-to-remove="bottom">
            <table class="form-list" id="sharings" cellspacing="0">
              <tr>
                <th>
                  User/Group
                </th>
                <th>
                  Inheritance
                </th>
                <th>
                  Allow/Deny
                </th>
                <v:template type="simple" enabled="--self.dav_enable">
                  <th align="center" width="1%">
                    Actions
                  </th>
                </v:template>
              </tr>
            </table>
          </v:template>
          <v:template type="repeat" name-to-remove="" set-to-remove="">
            <v:template type="if-not-exists" name-to-remove="table" set-to-remove="both">
              <table>
                <tr align="center">
                  <td colspan="4">No sharings</td>
                </tr>
              </table>
            </v:template>
            <v:template type="browse" name-to-remove="table" set-to-remove="both">
              <table>
                <tr>
                  <td>
                    <v:label value="--ODRIVE.WA.odrive_ace_grantee((control.vc_parent as vspx_row_template).te_rowset[0])" format="%s"/>
                  </td>
                  <td>
                    <v:label value="--ODRIVE.WA.odrive_ace_inheritance((control.vc_parent as vspx_row_template).te_rowset[1])" format="%s"/>
                  </td>
                  <td>
                    <v:label value="--ODRIVE.WA.odrive_ace_permissions((control.vc_parent as vspx_row_template).te_rowset[2])" format="%s"/>
                    /
                    <v:label value="--ODRIVE.WA.odrive_ace_permissions((control.vc_parent as vspx_row_template).te_rowset[3])" format="%s"/>
                  </td>
                  <v:template type="simple" enabled="--self.dav_enable">
                    <td nowrap="nowrap">
                      <v:template type="simple" enabled="-- case when (((control.vc_parent).vc_parent as vspx_row_template).te_rowset[1] = 3) then 0 else 1 end">
                        <v:button action="simple" value="Edit" xhtml_disabled="disabled" xhtml_class="button">
                          <v:on-post>
                            <![CDATA[
                              self.ace := vector((((control.vc_parent).vc_parent).vc_parent as vspx_row_template).te_rowset[0],
                                                 (((control.vc_parent).vc_parent).vc_parent as vspx_row_template).te_rowset[1],
                                                 (((control.vc_parent).vc_parent).vc_parent as vspx_row_template).te_rowset[2],
                                                 (((control.vc_parent).vc_parent).vc_parent as vspx_row_template).te_rowset[3]
                                                );
                              self.command_acl := 2;
                              self.vc_data_bind(e);
                            ]]>
                          </v:on-post>
                        </v:button>
                        <v:button action="simple" value="Delete" xhtml_onClick="javascript: return deleteConfirm();" xhtml_disabled="disabled" xhtml_class="button">
                          <v:on-post>
                            <![CDATA[
                              WS.WS.ACL_REMOVE_ENTRY(self.dav_acl,
                                                     (((control.vc_parent).vc_parent).vc_parent as vspx_row_template).te_rowset[0],
                                                     (((control.vc_parent).vc_parent).vc_parent as vspx_row_template).te_rowset[2],
                                                     (((control.vc_parent).vc_parent).vc_parent as vspx_row_template).te_rowset[1]
                                                    );
                              WS.WS.ACL_REMOVE_ENTRY(self.dav_acl,
                                                     (((control.vc_parent).vc_parent).vc_parent as vspx_row_template).te_rowset[0],
                                                     (((control.vc_parent).vc_parent).vc_parent as vspx_row_template).te_rowset[3],
                                                     (((control.vc_parent).vc_parent).vc_parent as vspx_row_template).te_rowset[1]
                                                    );
                              self.vc_data_bind(e);
                            ]]>
                          </v:on-post>
                        </v:button>
                      </v:template>
                    </td>
                  </v:template>
                </tr>
              </table>
            </v:template>
          </v:template>

          <v:template type="simple" name-to-remove="table" set-to-remove="top">
            <table>
            </table>
          </v:template>

        </v:data-set>
      </v:template>
      <v:template type="simple" enabled="-- case when (self.command_acl = 1 or self.command_acl = 2) then 1 else 0 end">
        <div class="new-form-header">
          Share resource
        </div>
        <div class="new-form-body no-border">
          <table cellspacing="0">
            <tr>
              <th>
                <v:label for="ace_user" value="User(s)/Group(s)"/>
              </th>
              <td>
                <?vsp
                  http(sprintf('<input type="text" name="ace_user" value="%s" disabled="disabled" class="field-short" title="Users/groups must be comma separated!"/>', ODRIVE.WA.odrive_user_name(self.ace[0], '')));
                ?>
                <v:template type="simple">
                  <input type="button" value="Select" onClick="javascript:windowShow('users_select.vspx?dst=m&amp;params=ace_user:s1;',520)" class="button"/>
                </v:template>
              </td>
            </tr>
            <tr>
              <th>
                <v:label for="ace_inheritance" value="Inheritance"/>
              </th>
              <td>
                <select name="ace_inheritance" disabled="disabled">
                  <?vsp
                    http(self.option_prepare('0', concat('This object only', either(equ(self.command, 4), ' (Folders and files)' ,'')), self.ace[1]));
                    if (equ(self.dav_type, 'C') or (self.command = 4)) {
                      http(self.option_prepare('1', concat('This object, subfolders and files', either(equ(self.command, 4), ' (Folders only)' ,'')), self.ace[1]));
                      http(self.option_prepare('2', concat('Subfolders and files', either(equ(self.command, 4), ' (Folders only)' ,'')), self.ace[1]));
                    }
                  ?>
                </select>
              </td>
            </tr>
            <tr>
              <th valign="top">
                <v:label value="Permissions"/>
              </th>
              <td>
                <table class="form-list" style="width: 1%;" cellspacing="0">
                  <tr>
                    <th />
                    <th align="center">Allow</th>
                    <th class="last" align="center">Deny</th>
                  </tr>
                  <tr>
                    <th align="center">Read</th>
                    <td style="border-width: 0px 1px 1px 0px;" align="center">
                      <?vsp
                        self.ace_checkbox('ace_read', 'grant', bit_and(self.ace[2], 4));
                      ?>
                    </td>
                    <td style="border-width: 0px 0px 1px 0px;" align="center">
                      <?vsp
                        self.ace_checkbox('ace_read', 'revoke', bit_and(self.ace[3], 4));
                      ?>
                    </td>
                  </tr>
                  <tr>
                    <th align="center">Write</th>
                    <td style="border-width: 0px 1px 1px 0px;" align="center">
                      <?vsp
                        self.ace_checkbox('ace_write', 'grant', bit_and(self.ace[2], 2));
                      ?>
                    </td>
                    <td style="border-width: 0px 0px 1px 0px;" align="center">
                      <?vsp
                        self.ace_checkbox('ace_write', 'revoke', bit_and(self.ace[3], 2));
                      ?>
                    </td>
                  </tr>
                  <tr>
                    <th align="center">Execute</th>
                    <td style="border-width: 0px 1px 0px 0px;" align="center">
                      <?vsp
                        self.ace_checkbox('ace_execute', 'grant', bit_and(self.ace[2], 1));
                      ?>
                    </td>
                    <td align="center">
                      <?vsp
                        self.ace_checkbox('ace_execute', 'revoke', bit_and(self.ace[3], 1));
                      ?>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
          </table>
        </div>
        <div class="new-form-footer">
          <v:button action="simple" value="OK">
            <v:on-post>
              <![CDATA[
                -- remove
                --
                if (self.ace[2])
                  WS.WS.ACL_REMOVE_ENTRY(self.dav_acl, self.ace[0], self.ace[2], self.ace[1]);
                if (self.ace[3])
                  WS.WS.ACL_REMOVE_ENTRY(self.dav_acl, self.ace[0], self.ace[3], self.ace[1]);

                -- add
                --
                declare N, ace_user integer;
                declare ace_users any;

                ace_users := split_and_decode (trim(get_keyword('ace_user', e.ve_params, '')), 0, '\0\0,');
                for (N := 0; N < length(ace_users); N := N + 1) {
                  ace_user := ODRIVE.WA.odrive_user_id(trim(ace_users[N]));
                  if (ace_user <> -1) {
                    declare I integer;

                    I := atoi(get_keyword('ace_inheritance', params));
                    WS.WS.ACL_ADD_ENTRY(self.dav_acl,
                                        ace_user,
                                        bit_shift(atoi(get_keyword('ace_read_grant', params, '0')), 2) +
                                        bit_shift(atoi(get_keyword('ace_write_grant', params, '0')), 1) +
                                        atoi(get_keyword('ace_execute_grant', params, '0')),
                                        1,
                                        I);
                    WS.WS.ACL_ADD_ENTRY(self.dav_acl,
                                        ace_user,
                                        bit_shift(atoi(get_keyword('ace_read_revoke', params, '0')), 2) +
                                        bit_shift(atoi(get_keyword('ace_write_revoke', params, '0')), 1) +
                                        atoi(get_keyword('ace_execute_revoke', params, '0')),
                                        0,
                                        I);
                  }
                }
                self.command_acl := 0;
                self.vc_data_bind(e);
              ]]>
            </v:on-post>
          </v:button>
          <v:button action="simple" value="Cancel">
            <v:on-post>
              <![CDATA[
                self.command_acl := 0;
                self.vc_data_bind(e);
              ]]>
            </v:on-post>
          </v:button>
        </div>
      </v:template>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="search-dc-template4">
    <div id="4" class="tabContent" style="display: none;">
      <table class="form-body" cellspacing="0">
        <tr>
          <th>
            <v:label for="dav_oMail_DomainId" value="--'oMail domain'" format="%s"/>
          </th>
          <td>
            <v:text name="dav_oMail_DomainId" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:validator test="regexp" regexp="^[0-9]+$" message="Number is expected" runat="client"/>
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := get_keyword('dav_oMail_DomainId', self.vc_page.vc_event.ve_params, ODRIVE.WA.DAV_PROP_GET(self.dav_path, 'virt:oMail-DomainId', '1'));
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_oMail_FolderName" value="--'oMail folder name'" format="%s"/>
          </th>
          <td>
            <v:text name="dav_oMail_FolderName" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:validator test="length" min="1" max="255" message="The input can not be empty." runat="client"/>
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := get_keyword('dav_oMail_FolderName', self.vc_page.vc_event.ve_params, ODRIVE.WA.DAV_PROP_GET(self.dav_path, 'virt:oMail-FolderName', 'Inbox'));
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_oMail_NameFormat" value="--'oMail name format'" format="%s"/>
          </th>
          <td>
            <v:text name="dav_oMail_NameFormat" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:validator test="length" min="1" max="255" message="The input can not be empty." runat="client"/>
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := get_keyword('dav_oMail_NameFormat', self.vc_page.vc_event.ve_params, ODRIVE.WA.DAV_PROP_GET(self.dav_path, 'virt:oMail-NameFormat', '^from^ ^subject^'));
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
      </table>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="search-dc-template5">
    <div id="5" class="tabContent" style="display: none;">
      <table class="form-body" cellspacing="0">
        <tr>
          <th>
            <v:label for="dav_PropFilter_SearchPath" value="--'Search path'" format="%s"/>
          </th>
          <td>
            <v:text name="dav_PropFilter_SearchPath" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:validator test="length" min="1" max="255" message="The input can not be empty." runat="client"/>
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := get_keyword('dav_oMail_SearchPath', self.vc_page.vc_event.ve_params, ODRIVE.WA.DAV_PROP_GET(self.dav_path, 'virt:PropFilter-SearchPath', ODRIVE.WA.path_show(self.dir_path)));
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_PropFilter_PropName" value="--'Property name'" format="%s"/>
          </th>
          <td>
            <v:text name="dav_PropFilter_PropName" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:validator test="length" min="1" max="255" message="The input can not be empty." runat="client"/>
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := get_keyword('dav_PropFilter_PropName', self.vc_page.vc_event.ve_params, ODRIVE.WA.DAV_PROP_GET(self.dav_path, 'virt:PropFilter-PropName', ''));
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="dav_PropFilter_PropValue" value="--'Property value'" format="%s"/>
          </th>
          <td>
            <v:text name="dav_PropFilter_PropValue" format="%s" xhtml_disabled="disabled" xhtml_class="field-text">
              <v:before-data-bind>
                <![CDATA[
                  control.ufl_value := get_keyword('dav_PropFilter_PropValue', self.vc_page.vc_event.ve_params, ODRIVE.WA.DAV_PROP_GET(self.dav_path, 'virt:PropFilter-PropValue', ''));
                ]]>
              </v:before-data-bind>
            </v:text>
          </td>
        </tr>
      </table>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="search-dc-template7">
    <div id="7" class="tabContent" style="display: none;">
      <table class="form-body" cellspacing="0">
        <tr>
          <th>
            <v:label for="ts_path" value="--'Search path'" format="%s"/>
          </th>
          <td>
            <?vsp http(sprintf('<input type="text" name="ts_path" value="%V" disabled="disabled" class="field-text"/>', ODRIVE.WA.dav_dc_get(self.search_dc, 'base', 'path', ODRIVE.WA.path_show(self.dir_path)))); ?>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="ts_name" value="--'Search by file name'" format="%s"/>
          </th>
          <td>
            <?vsp http(sprintf('<input type="text" name="ts_name" value="%V" disabled="disabled" class="field-text"/>', ODRIVE.WA.dav_dc_get(self.search_dc, 'base', 'name'))); ?>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="ts_content" value="--'Search by content'" format="%s"/>
          </th>
          <td>
            <?vsp http(sprintf('<input type="text" name="ts_content" value="%V" disabled="disabled" class="field-text"/>', ODRIVE.WA.dav_dc_get(self.search_dc, 'base', 'content'))); ?>
          </td>
        </tr>
        <tr>
          <th />
          <td>
            <br />
            <span class="helpText">
              Search path - Path starting with "/", no wildcards<br />
              Search by file name - Use "*" or "%" as wildcard<br />
              Search by content - Words separated by spaces. Only files with a "text/*" content type will be matched.
            </span>
          </td>
        </tr>
      </table>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="search-dc-template8">
    <div id="8" class="tabContent" style="display: none;">
      <table class="form-body" cellspacing="0">
        <tr>
          <th>
            <v:label for="ts_mime" value="--'Mime Type'" format="%s"/>
          </th>
          <td>
            <?vsp http(sprintf('<input type="text" name="ts_mime" value="%s" disabled="disabled" class="field-short"/>', ODRIVE.WA.dav_dc_get(self.search_dc, 'advanced', 'mime'))); ?>
            <v:template type="simple">
              <input type="button" value="Select" onClick="javascript:windowShow('mimes_select.vspx?params=ts_mime:s1;')" disabled="disabled" class="button"/>
            </v:template>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="ts_owner" value="--'Owner ID'" format="%s"/>
          </th>
          <td>
            <?vsp http(sprintf('<input type="text" name="ts_owner" value="%s" disabled="disabled" class="field-short"/>', ODRIVE.WA.odrive_user_name(ODRIVE.WA.dav_dc_get(self.search_dc, 'advanced', 'owner', -1)))); ?>
            <v:template type="simple">
              <input type="button" value="Select" onClick="javascript:windowShow('users_select.vspx?mode=u&amp;params=ts_owner:s1;')" disabled="disabled" class="button"/>
            </v:template>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="ts_group" value="--'Group ID'" format="%s"/>
          </th>
          <td>
            <?vsp http(sprintf('<input type="text" name="ts_group" value="%s" disabled="disabled" class="field-short"/>', ODRIVE.WA.odrive_user_name(ODRIVE.WA.dav_dc_get(self.search_dc, 'advanced', 'group', -1)))); ?>
            <v:template type="simple">
              <input type="button" value="Select" onClick="javascript:windowShow('users_select.vspx?mode=g&amp;params=ts_group:s1;')" disabled="disabled" class="button"/>
            </v:template>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="ts_createDate11" value="--'Creation date'" format="%s"/>
          </th>
          <td>
            <?vsp
              self.search_condition('ts_createDate11', vector('=', '&lt;', '&lt;=', '&gt;', '&gt;='), ODRIVE.WA.dav_dc_get(self.search_dc, 'advanced', 'createDate11'), '');
              http(sprintf('<input type="text" name="ts_createDate12" value="%s" disabled="disabled"/>', ODRIVE.WA.dav_dc_get(self.search_dc, 'advanced', 'createDate12')));
            ?> and
            <?vsp
              self.search_condition('ts_createDate21', vector('&gt;', '&gt;='), ODRIVE.WA.dav_dc_get(self.search_dc, 'advanced', 'createDate21'), '');
              http(sprintf('<input type="text" name="ts_createDate22" value="%s" disabled="disabled"/>', ODRIVE.WA.dav_dc_get(self.search_dc, 'advanced', 'createDate22')));
            ?> (yyyy-mm-dd)
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="ts_modifyDate11" value="--'Modification date'" format="%s"/>
          </th>
          <td>
            <?vsp
              self.search_condition('ts_modifyDate11', vector('=', '&lt;', '&lt;=', '&gt;', '&gt;='), ODRIVE.WA.dav_dc_get(self.search_dc, 'advanced', 'modifyDate11'), '');
              http(sprintf('<input type="text" name="ts_modifyDate12" value="%s" disabled="disabled"/>', ODRIVE.WA.dav_dc_get(self.search_dc, 'advanced', 'modifyDate12')));
            ?> and
            <?vsp
              self.search_condition('ts_modifyDate21', vector('&gt;', '&gt;='), ODRIVE.WA.dav_dc_get(self.search_dc, 'advanced', 'modifyDate21'), '');
              http(sprintf('<input type="text" name="ts_modifyDate22" value="%s" disabled="disabled"/>', ODRIVE.WA.dav_dc_get(self.search_dc, 'advanced', 'modifyDate22')));
            ?> (yyyy-mm-dd)
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="ts_publicTags11" value="--'Comma separated public tags'" format="%s"/>
          </th>
          <td>
            <?vsp
              http('<input name="ts_publicTags11" type="hidden" value="contains_tags" />');
              --self.search_condition('ts_publicTags11', vector('contains_tags', 'may_contain_tags', 'contains_text', 'may_contain_text'), ODRIVE.WA.dav_dc_get(self.search_dc, 'advanced', 'publicTags11'), '');
              http(sprintf('<input type="text" name="ts_publicTags12" value="%s" disabled="disabled" class="field-short"/>', ODRIVE.WA.dav_dc_get(self.search_dc, 'advanced', 'publicTags12')));
            ?>
          </td>
        </tr>
        <tr>
          <th>
            <v:label for="ts_privateTags11" value="--'Comma separated private tags'" format="%s"/>
          </th>
          <td>
            <?vsp
              http('<input name="ts_privateTags11" type="hidden" value="contains_tags" />');
              --self.search_condition('ts_privateTags11', vector('contains_tags', 'may_contain_tags', 'contains_text', 'may_contain_text'), ODRIVE.WA.dav_dc_get(self.search_dc, 'advanced', 'privateTags11'), '');
              http(sprintf('<input type="text" name="ts_privateTags12" value="%s" disabled="disabled" class="field-short"/>', ODRIVE.WA.dav_dc_get(self.search_dc, 'advanced', 'privateTags12')));
            ?>
          </td>
        </tr>
      </table>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="search-dc-template9">
    <div id="9" class="tabContent" style="display: none;">
      <v:template type="simple">
        <v:before-data-bind>
          <![CDATA[
            declare N integer;
            declare aParams any;

            N := 0;
            while (N < length(self.vc_page.vc_event.ve_params)) {
              if (self.vc_page.vc_event.ve_params[N] like 'ts_vmd_btn_%') {
                self.dc_prepare();
                aParams := split_and_decode(self.vc_page.vc_event.ve_params[N], 0, '\0$0');
                if (trim(aParams[0]) = 'ts_vmd_btn_update') {
                  if (is_empty_or_null(get_keyword(sprintf('ts_vmd_condition$0%s$0', trim(aParams[1])), self.vc_page.vc_event.ve_params, '')))
                    return;
                  if (not ODRIVE.WA.rdf_validate_property2(get_keyword(sprintf('ts_vmd_type$0%s$0', trim(aParams[1])), self.vc_page.vc_event.ve_params, ''),
                                                           get_keyword(sprintf('ts_vmd_schema$0%s$0', trim(aParams[1])), self.vc_page.vc_event.ve_params, ''),
                                                           get_keyword(sprintf('ts_vmd_property$0%s$0', trim(aParams[1])), self.vc_page.vc_event.ve_params, ''),
                                                           get_keyword(sprintf('ts_vmd_value$0%s$0', trim(aParams[1])), self.vc_page.vc_event.ve_params, ''))) {
                    self.vc_error_message := 'Bad metadata value';
                    self.vc_is_valid := 0;
                    return;
                  }
                  ODRIVE.WA.dav_dc_set_metadata(self.search_dc,
                                                trim(aParams[1]),
                                                get_keyword(sprintf('ts_vmd_type$0%s$0', trim(aParams[1])), self.vc_page.vc_event.ve_params, ''),
                                                get_keyword(sprintf('ts_vmd_schema$0%s$0', trim(aParams[1])), self.vc_page.vc_event.ve_params, ''),
                                                get_keyword(sprintf('ts_vmd_property$0%s$0', trim(aParams[1])), self.vc_page.vc_event.ve_params, ''),
                                                get_keyword(sprintf('ts_vmd_condition$0%s$0', trim(aParams[1])), self.vc_page.vc_event.ve_params, ''),
                                                get_keyword(sprintf('ts_vmd_value$0%s$0', trim(aParams[1])), self.vc_page.vc_event.ve_params, '')
                                               );
                } else if (trim(aParams[0]) = 'ts_vmd_btn_add') {
                  if (is_empty_or_null(get_keyword('ts_vmd_schema_add', self.vc_page.vc_event.ve_params, '')))
                    return;
                  if (is_empty_or_null(get_keyword('ts_vmd_property_add', self.vc_page.vc_event.ve_params, '')))
                    return;
                  if (is_empty_or_null(get_keyword('ts_vmd_condition_add', self.vc_page.vc_event.ve_params, '')))
                    return;
                  if (not ODRIVE.WA.rdf_validate_property2(get_keyword('ts_vmd_type_add', self.vc_page.vc_event.ve_params, ''),
                                                           get_keyword('ts_vmd_schema_add', self.vc_page.vc_event.ve_params, ''),
                                                           get_keyword('ts_vmd_property_add', self.vc_page.vc_event.ve_params, ''),
                                                           get_keyword('ts_vmd_value_add', self.vc_page.vc_event.ve_params, ''))) {
                    self.vc_error_message := 'Bad metadata value';
                    self.vc_is_valid := 0;
                    return;
                  }
                  ODRIVE.WA.dav_dc_set_metadata(self.search_dc,
                                                trim(aParams[1]),
                                                get_keyword('ts_vmd_type_add', self.vc_page.vc_event.ve_params, ''),
                                                get_keyword('ts_vmd_schema_add', self.vc_page.vc_event.ve_params, ''),
                                                get_keyword('ts_vmd_property_add', self.vc_page.vc_event.ve_params, ''),
                                                get_keyword('ts_vmd_condition_add', self.vc_page.vc_event.ve_params, ''),
                                                get_keyword('ts_vmd_value_add', self.vc_page.vc_event.ve_params, '')
                                               );
                } else if (trim(aParams[0]) = 'ts_vmd_btn_delete')
                  ODRIVE.WA.dav_dc_cut(self.search_dc, 'metadata', trim(aParams[1]));
              }
              N := N + 4;
            }
            if (self.vmdType <> get_keyword('ts_vmd_type_add', self.vc_page.vc_event.ve_params)) {
              self.vmdSchema := null;
            } else {
              self.vmdSchema := get_keyword('ts_vmd_schema_add', self.vc_page.vc_event.ve_params);
            }
            self.vmdType := get_keyword('ts_vmd_type_add', self.vc_page.vc_event.ve_params);
            if (isnull(self.vmdType))
              self.vmdType := 'RDF';
            if (isnull(self.vmdSchema))
              self.vmdSchema := (select TOP 1 RS_URI from WS.WS.SYS_RDF_SCHEMAS order by RS_CATNAME);
          ]]>
        </v:before-data-bind>
        <table class="form-list" id="metaProperties" cellspacing="0">
          <tr>
            <th>
              Type
            </th>
            <th>
              Schema
            </th>
            <th>
              Property
            </th>
            <th>
              Condition
            </th>
            <th>
              Value
            </th>
            <th align="center" width="1%">
              Actions
            </th>
          </tr>
          <?vsp
            declare N integer;

            N := 0;
            for (select rs.* from ODRIVE.WA.dav_dc_metadata_rs(rs0)(c0 integer, c1 varchar, c2 varchar, c3 varchar, c4 varchar, c5 varchar, c6 varchar) rs where rs0 = self.search_dc order by c0) do {
              if (N < c0)
                N := c0;

              http('<tr>');
                 http('<td>');
                  http(sprintf('<input type="hidden" name="ts_vmd_type$0%d$0" value="%s"/>', c0, c1));
                  http(sprintf('<input type="text" value="%s" onfocus="javascript:this.blur()" disabled="disabled" class="field-max"/>', c1));
                http('</td>');
                 http('<td>');
                  http(sprintf('<input type="hidden" name="ts_vmd_schema$0%d$0" value="%s"/>', c0, c2));
                  http(sprintf('<input type="text" value="%s" onfocus="javascript:this.blur()" disabled="disabled" class="field-max"/>', c6));
                http('</td>');
                 http('<td>');
                  http(sprintf('<input type="hidden" name="ts_vmd_property$0%d$0" value="%s"/>', c0, c3));
                  if (c1 = 'RDF') {
                    http(sprintf('<input type="text" value="%s" onfocus="javascript:this.blur()" disabled="disabled" class="field-max"/>', ODRIVE.WA.rdf_get_property_title(c2, c3)));
                  } else {
                    http(sprintf('<input type="text" value="%s" onfocus="javascript:this.blur()" disabled="disabled" class="field-max"/>', c3));
                  }
                http('</td>');
                http('<td>');
                  self.search_condition(sprintf('ts_vmd_condition$0%d$0', c0), vector('=', '&lt;', '&lt;=', '&gt;', '&gt;=', 'starts_with', 'contains_substring', 'contains_text', 'may_contain_text'), c4, 'field-max');
                http('</td>');
                http('<td>');
                  http(sprintf('<input type="text" name="ts_vmd_value$0%d$0" value="%V" disabled="disabled" class="field-max"/>', c0, c5));
                http('</td>');
                http('<td nowrap="nowrap">');
                  http(sprintf('<input type="submit" name="ts_vmd_btn_update$0%d$0" value="Update" disabled="disabled" class="button" />', c0));
                  http('&nbsp;');
                  http(sprintf('<input type="submit" name="ts_vmd_btn_delete$0%d$0" value="Delete" disabled="disabled" class="button" />', c0));
                http('</td>');
              http('</tr>');
            }
            N := N + 1;
            http('<tr>');
               http('<td>');
                 http('<select name="ts_vmd_type_add" onchange="javascript:doPost(\'F1\', \'reload\'); return false" disabled="disabled" class="field-max">');
                http(self.option_prepare('RDF', 'RDF', self.vmdType));
                http(self.option_prepare('WebDAV', 'WebDAV', self.vmdType));
                 http('</select>');
              http('</td>');
               http('<td>');
                 http('<select name="ts_vmd_schema_add" onchange="javascript:doPost(\'F1\', \'reload\'); return false" disabled="disabled" class="field-max">');
                 if (self.vmdType = 'RDF') {
                  declare exit handler for sqlstate '*' { goto _skip; };
                  for (select RS_URI, RS_CATNAME from WS.WS.SYS_RDF_SCHEMAS order by RS_CATNAME) do
                    http(self.option_prepare(RS_URI, RS_CATNAME, self.vmdSchema));
                 } else {
                  http(self.option_prepare('WebDAV Properties', 'WebDAV Properties', 'WebDAV Properties'));
                 }
              _skip:
                 http('</select>');
              http('</td>');
               http('<td>');
                 if (self.vmdType = 'RDF') {
                   http('<select name="ts_vmd_property_add" disabled="disabled" class="field-max">');
                   for (select c0, c1 from ODRIVE.WA.dav_rdf_schema_properties_short_rs(rs0)(c0 varchar, c1 varchar) rs where rs0 = self.vmdSchema order by c1) do
                     http(self.option_prepare(c0, c1, ''));
                   http('</select>');
                 } else {
                  http('<input type="text" name="ts_vmd_property_add" disabled="disabled" class="field-max"/>');
                 }
              http('</td>');
              http('<td>');
                self.search_condition('ts_vmd_condition_add', vector('=', '&lt;', '&lt;=', '&gt;', '&gt;=', 'starts_with', 'contains_substring', 'contains_text', 'may_contain_text'), '', 'field-max');
              http('</td>');
              http('<td>');
                http('<input type="text" name="ts_vmd_value_add" disabled="disabled" class="field-max"/>');
              http('</td>');
              http('<td>');
                http(sprintf('<input type="submit" name="ts_vmd_btn_add$0%d$0" value="Add" disabled="disabled" class="button" />', N));
              http('</td>');
            http('</tr>');
          ?>
        </table>
        <table>
          <tr>
            <td>
              <br />
              <span class="helpText">
                "Condition" determines how the "Value" is compared with the value of the property.<br />
                Starts with is a match of the leading characters, case sensitive.<br />
                Contains matches a substring, case sensitively, also in the middle of words.<br />
                Contains words/phrases expects a full text search expression.<br />
                The May contain word/phrase choice is like the Contains word/phrase choice except that contents of virtual collections that do not support full text search will be considered hits, whereas contents of actual DAV and supporting virtual collections will be properly filtered.<br/>
                The test is case insensitive and words can be connected with AND and OR. Words enclosed in double quotes (") will match the same exact phrase.
              </span>
            </td>
          </tr>
        </table>
      </v:template>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="search-dc-template10">
    <div id="10" class="tabContent" style="display: none;">
      <table class="form-body" cellspacing="0">
        <tr>
          <th >
            <v:label value="File State" format="%s"/>
          </th>
          <td>
            <?vsp
              http(sprintf('Lock is <b>%s</b>, ', ODRIVE.WA.DAV_GET_INFO (ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'), 'lockState')));
              http(sprintf('Version Conrol is <b>%s</b>, ', ODRIVE.WA.DAV_GET_INFO (ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'), 'vc')));
              http(sprintf('Auto Versioning is <b>%s</b>, ', ODRIVE.WA.DAV_GET_INFO (ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'), 'avcState')));
              http(sprintf('Version State is <b>%s</b>', ODRIVE.WA.DAV_GET_INFO (ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'), 'vcState')));
            ?>
          </td>
        </tr>
        <v:template type="simple" enabled="-- case when (equ(self.command_mode, 10)) then 1 else 0 end">
          <tr>
            <th >
              <v:label value="--sprintf('Content is %s in Version Conrol', either(equ(ODRIVE.WA.DAV_GET (self.dav_item, 'versionControl'),1), '', 'not'))" format="%s"/>
            </th>
            <td valign="center">
              <v:button action="simple" value="--sprintf('%s VC', either(equ(ODRIVE.WA.DAV_GET (self.dav_item, 'versionControl'),1), 'Disable', 'Enable'))" xhtml_class="button">
                <v:on-post>
                  <![CDATA[
                    declare retValue any;

                    if (ODRIVE.WA.DAV_GET (self.dav_item, 'versionControl')) {
                      retValue := ODRIVE.WA.DAV_REMOVE_VERSION_CONTROL (ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'));
                    } else {
                      retValue := ODRIVE.WA.DAV_VERSION_CONTROL (ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'));
                    }
                    if (ODRIVE.WA.DAV_ERROR(retValue)) {
                      self.vc_error_message := ODRIVE.WA.DAV_PERROR(retValue);
                      self.vc_is_valid := 0;
                      return;
                    }
                    self.vc_data_bind(e);
                  ]]>
                </v:on-post>
              </v:button>
            </td>
          </tr>
        </v:template>
        <xsl:call-template name="autoVersion"/>
        <v:template type="simple" enabled="-- case when (equ(ODRIVE.WA.DAV_GET (self.dav_item, 'versionControl'),1)) then 1 else 0 end">
          <tr>
            <th >
              File commands
            </th>
            <td valign="center">
              <v:button action="simple" value="Lock" enabled="-- case when (ODRIVE.WA.DAV_IS_LOCKED(ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'))) then 0 else 1 end" xhtml_class="button">
                <v:on-post>
                  <![CDATA[
                    declare retValue any;

                    retValue := ODRIVE.WA.DAV_LOCK (ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'));
                    if (ODRIVE.WA.DAV_ERROR(retValue)) {
                      self.vc_error_message := ODRIVE.WA.DAV_PERROR(retValue);
                      self.vc_is_valid := 0;
                      return;
                    }
                    self.vc_data_bind(e);
                  ]]>
                </v:on-post>
              </v:button>
              <v:button action="simple" value="Unlock" enabled="-- case when (ODRIVE.WA.DAV_IS_LOCKED(ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'))) then 1 else 0 end" xhtml_class="button">
                <v:on-post>
                  <![CDATA[
                    declare retValue any;

                    retValue := ODRIVE.WA.DAV_UNLOCK (ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'));
                    if (ODRIVE.WA.DAV_ERROR(retValue)) {
                      self.vc_error_message := ODRIVE.WA.DAV_PERROR(retValue);
                      self.vc_is_valid := 0;
                      return;
                    }
                    self.vc_data_bind(e);
                  ]]>
                </v:on-post>
              </v:button>
            </td>
          </tr>
          <tr>
            <th >
              Versioning commands
            </th>
            <td valign="center">
              <v:button action="simple" value="Check-In" enabled="-- case when (is_empty_or_null(ODRIVE.WA.DAV_GET (self.dav_item, 'checked-in'))) then 1 else 0 end" xhtml_class="button">
                <v:on-post>
                  <![CDATA[
                    declare retValue any;

                    retValue := ODRIVE.WA.DAV_CHECKIN (ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'));
                    if (ODRIVE.WA.DAV_ERROR(retValue)) {
                      self.vc_error_message := ODRIVE.WA.DAV_PERROR(retValue);
                      self.vc_is_valid := 0;
                      return;
                    }
                    self.vc_data_bind(e);
                  ]]>
                </v:on-post>
              </v:button>
              <v:button action="simple" value="Check-Out" enabled="-- case when (is_empty_or_null(ODRIVE.WA.DAV_GET (self.dav_item, 'checked-out'))) then 1 else 0 end" xhtml_class="button">
                <v:on-post>
                  <![CDATA[
                    declare retValue any;

                    retValue := ODRIVE.WA.DAV_CHECKOUT (ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'));
                    if (ODRIVE.WA.DAV_ERROR(retValue)) {
                      self.vc_error_message := ODRIVE.WA.DAV_PERROR(retValue);
                      self.vc_is_valid := 0;
                      return;
                    }
                    self.vc_data_bind(e);
                  ]]>
                </v:on-post>
              </v:button>
              <v:button action="simple" value="Uncheck-Out" enabled="-- case when (is_empty_or_null(ODRIVE.WA.DAV_GET (self.dav_item, 'checked-in'))) then 1 else 0 end" xhtml_class="button">
                <v:on-post>
                  <![CDATA[
                    declare retValue any;

                    retValue := ODRIVE.WA.DAV_UNCHECKOUT (ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'));
                    if (ODRIVE.WA.DAV_ERROR(retValue)) {
                      self.vc_error_message := ODRIVE.WA.DAV_PERROR(retValue);
                      self.vc_is_valid := 0;
                      return;
                    }
                    self.vc_data_bind(e);
                  ]]>
                </v:on-post>
              </v:button>
            </td>
          </tr>
          <tr>
            <th >
              Number of Versions in History
            </th>
            <td valign="center">
              <v:label value="--ODRIVE.WA.DAV_GET_VERSION_COUNT(ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'))" format="%d"/>
            </td>
          </tr>
          <tr>
            <th >
              Root version
            </th>
            <td valign="center">
              <v:button style="url" action="simple" value="--ODRIVE.WA.DAV_GET_VERSION_ROOT(ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'))" format="%s">
                <v:on-post>
                  <![CDATA[
                    declare path varchar;

                    path := ODRIVE.WA.DAV_GET_VERSION_ROOT(ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath'));
                    if (ODRIVE.WA.odrive_permission(path) = '') {
                      self.vc_error_message := 'You have not rights to read this folder/file!';
                      self.vc_is_valid := 0;
                      self.vc_data_bind(e);
                      return;
                    }

                    http_request_status ('HTTP/1.1 302 Found');
                    http_header (sprintf('Location: view_file.vsp?sid=%s&realm=%s&file=%U\r\n', self.sid , self.realm, path));
                    self.vc_data_bind(e);
                  ]]>
                </v:on-post>
              </v:button>
            </td>
          </tr>
          <tr>
            <th>Versions</th>
            <td>
              <v:data-set name="ds_versions" sql="select rs.* from ODRIVE.WA.DAV_GET_VERSION_SET(rs0)(c0 varchar, c1 integer) rs where rs0 = :p0" nrows="0" scrollable="1">
                <v:param name="p0" value="--ODRIVE.WA.DAV_GET (self.dav_item, 'fullPath')"/>

                <v:template name="ds_versions_header" type="simple" name-to-remove="table" set-to-remove="bottom">
                  <table class="form-list" style="width: auto;" id="versions" cellspacing="0">
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

                  <v:template type="if-not-exists" name-to-remove="table" set-to-remove="both">
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
                          <v:button style="url" action="simple" value="--(control.vc_parent as vspx_row_template).te_column_value('c0')" format="%s">
                            <v:on-post>
                              <![CDATA[
                                declare path varchar;

                                path := (control.vc_parent as vspx_row_template).te_column_value('c0');
                                if (ODRIVE.WA.odrive_permission(path) = '') {
                                  self.vc_error_message := 'You have not rights to read this folder/file!';
                                  self.vc_is_valid := 0;
                                  self.vc_data_bind(e);
                                  return;
                                }

                                http_request_status ('HTTP/1.1 302 Found');
                                http_header (sprintf('Location: view_file.vsp?sid=%s&realm=%s&file=%U\r\n', self.sid , self.realm, path));
                                self.vc_data_bind(e);
                              ]]>
                            </v:on-post>
                          </v:button>
                        </td>
                        <td nowrap="nowrap" align="right">
                          <v:label value="--ODRIVE.WA.path_name((control.vc_parent as vspx_row_template).te_column_value('c0'))" format="%s"/>
                        </td>
                        <td nowrap="nowrap" align="right">
                          <v:label>
                            <v:after-data-bind>
                              <![CDATA[
                                control.ufl_value := self.ui_size(ODRIVE.WA.DAV_PROP_GET((control.vc_parent as vspx_row_template).te_column_value('c0'), ':getcontentlength'), 'R');
                              ]]>
                            </v:after-data-bind>
                          </v:label>
                        </td>
                        <td nowrap="nowrap" align="right">
                          <v:label>
                            <v:after-data-bind>
                              <![CDATA[
                                control.ufl_value := self.ui_date(ODRIVE.WA.DAV_PROP_GET((control.vc_parent as vspx_row_template).te_column_value('c0'), ':getlastmodified'));
                              ]]>
                            </v:after-data-bind>
                          </v:label>
                        </td>
                        <td nowrap="nowrap">
                          <v:button action="simple" style="image" value="image/del_16.png" enabled="-- (control.vc_parent as vspx_row_template).te_column_value('c1')" xhtml_onClick="javascript: return confirm(\'Are you sure you want to delete the chosen version and all previous versions?\');">
                            <v:on-post>
                              <![CDATA[
                                declare retValue any;

                                retValue := ODRIVE.WA.DAV_DELETE((control.vc_parent as vspx_row_template).te_column_value('c0'));
                                if (ODRIVE.WA.DAV_ERROR(retValue)) {
                                  self.vc_error_message := ODRIVE.WA.DAV_PERROR(retValue);
                                  self.vc_is_valid := 0;
                                  return;
                                }
                                self.vc_data_bind(e);
                              ]]>
                            </v:on-post>
                          </v:button>
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
            </td>
          </tr>
        </v:template>
      </table>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <xsl:template name="search-dc-template11">
    <div id="11" class="tabContent" style="display: none;">
      <table class="form-body" cellspacing="0">
        <tr>
          <th>
            <v:label for="ts_max" value="Max Results" />
          </th>
          <td>
            <?vsp http(sprintf('<input type="text" name="ts_max" value="%s" size="5"/>', ODRIVE.WA.dav_dc_get(self.search_dc, 'options', 'max', '100'))); ?>
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
                    http(self.option_prepare(self.dir_columns[N][0], self.dir_columns[N][2], self.dir_order));
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
                http(self.option_prepare('asc',  'Asc',  self.dir_direction));
                http(self.option_prepare('desc', 'Desc', self.dir_direction));
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

                http(self.option_prepare('', '', self.dir_grouping));
                for (N := 0; N < length(self.dir_columns); N := N + 1)
                  if (self.dir_columns[N][4] = 1)
                    http(self.option_prepare(self.dir_columns[N][0], self.dir_columns[N][2], self.dir_grouping));
              ?>
            </select>
          </td>
        </tr>
        <tr>
          <th/>
          <td>
            <v:check-box name="ts_cloud" xhtml_id="ts_cloud" value="1"/>
            <vm:label for="ts_cloud" value="Show tag''s cloud"/>
          </td>
        </tr>
      </table>
    </div>
  </xsl:template>

  <!--=========================================================================-->
  <!-- Auto Versioning -->
  <xsl:template name="autoVersion">
    <tr>
      <th >
        <v:label for="dav_autoversion" value="--'Auto Versioning Content'" format="%s"/>
      </th>
      <td valign="center">
        <?vsp
          declare tmp any;

          tmp := '';
          if ((self.dav_type = 'R') and (self.command_mode = 10))
            tmp := 'onchange="javascript: window.document.F1.submit();"';
          http(sprintf('<select name="dav_autoversion" %s disabled="disabled">', tmp));

          tmp := ODRIVE.WA.DAV_GET (self.dav_item, 'autoversion');
          if (isnull(tmp) and (self.dav_type = 'R'))
            tmp := ODRIVE.WA.DAV_GET_AUTOVERSION (ODRIVE.WA.odrive_real_path(self.dir_path));
          http(self.option_prepare('',   'No',   tmp));
          http(self.option_prepare('A',  'Checkout -> Checkin', tmp));
          http(self.option_prepare('B',  'Checkout -> Unlocked -> Checkin', tmp));
          http(self.option_prepare('C',  'Checkout', tmp));
          http(self.option_prepare('D',  'Locked -> Checkout', tmp));

          http('</select>');
        ?>
      </td>
    </tr>
  </xsl:template>

  <!--=========================================================================-->
  <!-- Toolbar -->
  <xsl:template name="toolBar">
    <?vsp http('<input type="hidden" name="toolbar_hidden" value=""/>'); ?>
    <?vsp
      if (0)
      {
    ?>
        <v:button name="toolbar" action="simple" style="url" value="Submit">
          <v:on-post>
            <![CDATA[
              declare cmd any;
              cmd := get_keyword ('toolbar_hidden', e.ve_params, '');
              if (cmd = 'home') {
                self.dir_path := ODRIVE.WA.odrive_dav_home();
                self.command_set(0, 0);
              }
              if (cmd = 'shared') {
                self.dir_path := ODRIVE.WA.shared_name();
                self.command_set(0, 0);
              }
              if (cmd = 'up') {
                if (trim(self.dir_path, '/') = trim(ODRIVE.WA.odrive_dav_home(), '/')) {
                  self.dir_path := '';
                } else {
                  declare pos integer;

                  pos := strrchr(self.dir_path, '/');
                  if (isnull(pos))
                    pos := 0;
                  self.dir_path := left(self.dir_path, pos);
                }
                self.ds_items.vc_reset();
              }
              if (cmd = 'new') {
                self.command_push(10, 0);
              }
              if (cmd = 'upload') {
                self.command_push(10, 5);
              }
              if (cmd = 'download') {
                self.prepare_command(control.vc_page.vc_event.ve_params, 26, 1);
                if (self.vc_is_valid)
                  self.vc_redirect(sprintf('view.vsp?file=%U&mode=download', self.item_array[0]));
              }
              if (cmd = 'copy') {
                self.prepare_command(control.vc_page.vc_event.ve_params, 20, 1);
              }
              if (cmd = 'move') {
                self.prepare_command(control.vc_page.vc_event.ve_params, 21, 1);
              }
              if (cmd = 'properties') {
                self.prepare_command(control.vc_page.vc_event.ve_params, 22, 0);
              }
              if (cmd = 'delete') {
                self.prepare_command(control.vc_page.vc_event.ve_params, 23, 0);
              }
              if (cmd = 'tag') {
                self.dav_tags := '';
                self.dav_tags2 := '';
                self.prepare_command(control.vc_page.vc_event.ve_params, 24, 0);
              }
              if (cmd = 'mail') {
                self.prepare_command(control.vc_page.vc_event.ve_params, 25, 0);
              }
              self.vc_data_bind(e);
             ]]>
           </v:on-post>
        </v:button>
    <?vsp
      }
    ?>
    <div class="toolbar">
      <v:url value="--''" format="%s" url="--'javascript: document.F1.submit()'" xhtml_title="Refresh" xhtml_class="toolbar">
        <v:before-render>
          <![CDATA[
            control.ufl_value := '<img src="image/ref_32.png" border="0" />' || self.toolbarLabel('Refresh');
          ]]>
        </v:before-render>
      </v:url>
      <v:url value="--''" format="%s" url="--'javascript: toolbarPost(''home'');'" xhtml_title="Home" xhtml_class="toolbar">
        <v:before-render>
          <![CDATA[
            control.ufl_value := '<img src="image/home_32.png" border="0"/>' || self.toolbarLabel('Home');
          ]]>
        </v:before-render>
      </v:url>
      <v:url value="--''" format="%s" url="--'javascript: toolbarPost(''shared'');'" xhtml_title="Shared Folders" xhtml_class="toolbar">
        <v:before-render>
          <![CDATA[
            control.ufl_value := '<img src="image/folder_violet.png" border="0"/>' || self.toolbarLabel('Shared Folders');
          ]]>
        </v:before-render>
      </v:url>
      <v:url value="--''" format="%s" url="--'javascript: toolbarPost(''up'');'" enabled="--self.toolbarEnable('up')" xhtml_title="Up" xhtml_class="toolbar">
        <v:before-render>
          <![CDATA[
            control.ufl_value := '<img src="image/up_32.png" border="0"/>' || self.toolbarLabel('Up');
          ]]>
        </v:before-render>
      </v:url>
      <v:template type="simple" enabled="--case when self.toolbarEnable('up') then 0 else 1 end">
        <span class="toolbar">
          <img src="image/grey_up_32.png" border="0" alt="Up"/><?vsp http(self.toolbarLabel('Up'));?>
        </span>
      </v:template>
      <img src="image/c.gif" height="32" width="2" border="0" class="toolbar"/>
      <v:url value="--''" format="%s" url="--'javascript: toolbarPost(''new'');'" enabled="--self.toolbarEnable('new')" xhtml_title="New Folder" xhtml_class="toolbar">
        <v:before-render>
          <![CDATA[
            control.ufl_value := '<img src="image/new_fldr_32.png" border="0"/>' || self.toolbarLabel('New Folder');
          ]]>
        </v:before-render>
      </v:url>
      <v:template type="simple" enabled="--case when self.toolbarEnable('new') then 0 else 1 end">
        <span class="toolbar">
          <img src="image/grey_new_fldr_32.png" border="0" alt="New Folder"/><?vsp http(self.toolbarLabel('New Folder'));?>
        </span>
      </v:template>
      <v:url value="--''" format="%s" url="--'javascript: toolbarPost(''upload'');'" enabled="--self.toolbarEnable('upload')" xhtml_title="Upload" xhtml_class="toolbar">
        <v:before-render>
          <![CDATA[
            control.ufl_value := '<img src="image/upld_32.png" border="0"/>' || self.toolbarLabel('Upload');
          ]]>
        </v:before-render>
      </v:url>
      <v:template type="simple" enabled="--case when self.toolbarEnable('upload') then 0 else 1 end">
        <span class="toolbar">
          <img src="image/grey_upld_32.png" border="0" alt="Upload"/><?vsp http(self.toolbarLabel('Upload'));?>
        </span>
      </v:template>

      <v:url value="--''" format="%s" url="--'javascript: if (anySelected(document.F1, ''CB_'', ''No resources were selected for download.'')) toolbarPost(''download'');'" enabled="--self.toolbarEnable('download')" xhtml_title="Download" xhtml_class="toolbar">
        <v:before-render>
          <![CDATA[
            control.ufl_value := '<img src="image/dwnld_32.png" border="0"/>' || self.toolbarLabel('Download');
          ]]>
        </v:before-render>
      </v:url>
      <v:template type="simple" enabled="--case when self.toolbarEnable('download') then 0 else 1 end">
        <span class="toolbar">
          <img src="image/grey_dwnld_32.png" border="0" alt="Download"/><?vsp http(self.toolbarLabel('Download'));?>
        </span>
      </v:template>

      <img src="image/c.gif" height="32" width="2" border="0" class="toolbar"/>

      <v:url value="--''" format="%s" url="--'javascript: if (anySelected(document.F1, ''CB_'', ''No resources were selected to be tagged.'')) toolbarPost(''tag'');'" enabled="--self.toolbarEnable('tag')" xhtml_title="Tag" xhtml_class="toolbar">
        <v:before-render>
          <![CDATA[
            control.ufl_value := '<img src="image/tag_32.png" border="0"/>' || self.toolbarLabel('Tag');
          ]]>
        </v:before-render>
      </v:url>
      <v:template type="simple" enabled="--case when self.toolbarEnable('tag') then 0 else 1 end">
        <span class="toolbar">
          <img src="image/grey_tag_32.png" border="0" alt="Tag"/><?vsp http(self.toolbarLabel('Tag'));?>
        </span>
      </v:template>

      <v:url value="--''" format="%s" url="--'javascript: if (anySelected(document.F1, ''CB_'', ''No resources were selected to be copied.'')) toolbarPost(''copy'');'" enabled="--self.toolbarEnable('copy')" xhtml_title="Copy" xhtml_class="toolbar">
        <v:before-render>
          <![CDATA[
            control.ufl_value := '<img src="image/copy_32.png" border="0"/>' || self.toolbarLabel('Copy');
          ]]>
        </v:before-render>
      </v:url>
      <v:template type="simple" enabled="--case when self.toolbarEnable('copy') then 0 else 1 end">
        <span class="toolbar">
          <img src="image/grey_copy_32.png" border="0" alt="Copy"/><?vsp http(self.toolbarLabel('Copy'));?>
        </span>
      </v:template>

      <v:url value="--''" format="%s" url="--'javascript: if (anySelected(document.F1, ''CB_'', ''No resources were selected to be moved.'')) toolbarPost(''move'');'" enabled="--self.toolbarEnable('move')" xhtml_title="Move" xhtml_class="toolbar">
        <v:before-render>
          <![CDATA[
            control.ufl_value := '<img src="image/move_32.png" border="0"/>' || self.toolbarLabel('Move');
          ]]>
        </v:before-render>
      </v:url>
      <v:template type="simple" enabled="--case when self.toolbarEnable('move') then 0 else 1 end">
        <span class="toolbar">
          <img src="image/grey_move_32.png" border="0" alt="Move"/><?vsp http(self.toolbarLabel('Move'));?>
        </span>
      </v:template>

      <v:url value="--''" format="%s" url="--'javascript: if (singleSelected(document.F1, ''CB_'', ''No items were selected to be renamed. Please select an item before you click the Rename button.'', ''You can only rename one item at a time. Please deselect all but one.'')) renameShow(document.F1, ''CB_'', ''rename.vspx?src=s'');'" enabled="--self.toolbarEnable('rename')" xhtml_titile="Rename" xhtml_class="toolbar" >
        <v:before-render>
          <![CDATA[
            control.ufl_value := '<img src="image/renm_32.png" border="0"/>' || self.toolbarLabel('Rename');
          ]]>
        </v:before-render>
      </v:url>
      <v:template type="simple" enabled="--case when self.toolbarEnable('rename') then 0 else 1 end">
        <span class="toolbar">
          <img src="image/grey_renm_32.png" border="0" alt="Rename"/><?vsp http(self.toolbarLabel('Rename'));?>
        </span>
      </v:template>

      <v:url value="--''" format="%s" url="--'javascript: if (anySelected(document.F1, ''CB_'', ''No resources were selected for property changes.'')) toolbarPost(''properties'');'" enabled="--self.toolbarEnable('properties')" xhtml_title="Properties" xhtml_class="toolbar">
        <v:before-render>
          <![CDATA[
            control.ufl_value := '<img src="image/prop_32.png" border="0"/>' || self.toolbarLabel('Properties');
          ]]>
        </v:before-render>
      </v:url>
      <v:template type="simple" enabled="--case when self.toolbarEnable('properties') then 0 else 1 end">
        <span class="toolbar">
          <img src="image/grey_prop_32.png" border="0" alt="Properties"/><?vsp http(self.toolbarLabel('Properties'));?>
        </span>
      </v:template>
      <v:url value="--''" format="%s" url="--'javascript: if (anySelected(document.F1, ''CB_'', ''No resources were selected for deletion.'')) toolbarPost(''delete'');'" enabled="--self.toolbarEnable('delete')" xhtml_title="Delete" xhtml_class="toolbar" >
        <v:before-render>
          <![CDATA[
            control.ufl_value := '<img src="image/del_32.png" border="0"/>' || self.toolbarLabel('Delete');
          ]]>
        </v:before-render>
      </v:url>
      <v:template type="simple" enabled="--case when self.toolbarEnable('delete') then 0 else 1 end">
        <span class="toolbar">
          <img src="image/grey_del_32.png" border="0" alt="Delete"/><?vsp http(self.toolbarLabel('Delete'));?>
        </span>
      </v:template>
      <img src="image/c.gif" height="32" width="2" border="0" class="toolbar"/>
      <v:url value="--''" format="%s" url="--'javascript: if (anySelected(document.F1, ''CB_'', ''No resources were selected for mailing.'')) toolbarPost(''mail'');'" enabled="--self.toolbarEnable('mail')" xhtml_title="Mail" xhtml_class="toolbar">
        <v:before-render>
          <![CDATA[
            control.ufl_value := '<img src="image/mail_32.png" border="0"/>' || self.toolbarLabel('Mail');
          ]]>
        </v:before-render>
      </v:url>
      <v:template type="simple" enabled="--case when self.toolbarEnable('mail') then 0 else 1 end">
        <span class="toolbar">
          <img src="image/grey_mail_32.png" border="0" alt="Mail"/><?vsp http(self.toolbarLabel('Mail'));?>
        </span>
      </v:template>
    </div>
    <div style="clear: both;"/>
  </xsl:template>
  <!--=========================================================================-->

</xsl:stylesheet>
